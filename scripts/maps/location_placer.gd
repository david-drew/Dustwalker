# location_placer.gd
# Places towns, forts, caves, and other locations on the hex map.
# Each location type has specific placement constraints (terrain, elevation,
# distance from other locations, water adjacency, etc.).
#
# PLACEMENT ORDER (important for constraint checking):
# 1. Towns (need water access)
# 2. Forts (need towns for proximity, strategic positions)
# 3. Trading Posts (between towns, prefer rivers)
# 4. Missions (near towns but not in them)
# 5. Roadhouses (between settlements)
# 6. Caves (in mountains/badlands)
# 7. Caravan Camps (desert/plains)

class_name LocationPlacer
extends RefCounted

# =============================================================================
# SIGNALS
# =============================================================================

signal location_placed(location_type: String, coords: Vector2i, name: String)
signal locations_complete(type: String, count: int)
signal placement_failed(type: String, reason: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Location type configurations loaded from JSON
var location_configs: Dictionary = {}

## Name lists for generating location names
var name_lists: Dictionary = {}

# =============================================================================
# STATE
# =============================================================================

## All placed locations: { coords: Vector2i -> location_data: Dictionary }
var locations: Dictionary = {}

## Locations grouped by type: { type: String -> Array[Dictionary] }
var locations_by_type: Dictionary = {}

## Reference to hex grid
var _hex_grid: HexGrid = null

## Reference to river generator (for water adjacency checks)
var _river_generator: RiverGenerator = null

## Random number generator
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Used names tracker (to reduce duplicates when possible)
var _used_names: Dictionary = {}

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	pass


## Loads configuration from the locations config file.
func load_config(config: Dictionary) -> void:
	location_configs = config.get("location_types", {})
	name_lists = config.get("name_lists", {})


## Sets the river generator reference for water adjacency checks.
func set_river_generator(river_gen: RiverGenerator) -> void:
	_river_generator = river_gen

# =============================================================================
# MAIN PLACEMENT
# =============================================================================

## Places all location types on the map.
## @param hex_grid: HexGrid - The grid to place locations on.
## @param generation_seed: int - Seed for reproducible placement.
## @return bool - True if placement was successful.
func place_all_locations(hex_grid: HexGrid, generation_seed: int) -> bool:
	_hex_grid = hex_grid
	_rng.seed = generation_seed + 77777  # Offset from terrain/river seeds
	
	# Clear previous locations
	locations.clear()
	locations_by_type.clear()
	_used_names.clear()
	_clear_location_data()
	
	# Place in order (order matters for constraints!)
	var success := true
	
	# 1. Towns first (need water access)
	if not _place_location_type("town"):
		success = false
	
	# 2. Forts (need towns for proximity checks)
	if not _place_location_type("fort"):
		success = false
	
	# 3. Trading posts (between towns, prefer rivers)
	if not _place_location_type("trading_post"):
		success = false
	
	# 4. Missions (near towns)
	if not _place_location_type("mission"):
		success = false
	
	# 5. Roadhouses (between settlements)
	if not _place_location_type("roadhouse"):
		success = false
	
	# 6. Caves (mountains/badlands)
	if not _place_location_type("cave"):
		success = false
	
	# 7. Caravan camps (desert/plains)
	if not _place_location_type("caravan_camp"):
		success = false
	
	print("LocationPlacer: Placed %d total locations" % locations.size())
	return success


func _clear_location_data() -> void:
	if _hex_grid == null:
		return
	
	for cell in _hex_grid.cells.values():
		cell.location = null

# =============================================================================
# LOCATION TYPE PLACEMENT
# =============================================================================

func _place_location_type(location_type: String) -> bool:
	if not location_configs.has(location_type):
		push_warning("LocationPlacer: Unknown location type: %s" % location_type)
		return false
	
	var config: Dictionary = location_configs[location_type]
	var min_count: int = config.get("min_count", 1)
	var max_count: int = config.get("max_count", min_count)
	
	# Determine target count
	var target_count := _rng.randi_range(min_count, max_count)
	
	# Find valid candidates
	var candidates := _find_valid_candidates(location_type, config)
	
	if candidates.size() < min_count:
		placement_failed.emit(location_type, "Not enough valid hexes (found %d, need %d)" % [candidates.size(), min_count])
		# Still try to place what we can
		target_count = mini(target_count, candidates.size())
	
	# Shuffle candidates
	candidates.shuffle()
	
	# Place locations
	var placed := 0
	var attempts := 0
	var max_attempts := candidates.size() * 2
	var candidate_index := 0
	
	while placed < target_count and attempts < max_attempts and candidate_index < candidates.size():
		attempts += 1
		
		var coords: Vector2i = candidates[candidate_index]
		candidate_index += 1
		
		# Double-check constraints (other locations may have been placed since candidate list was built)
		if not _check_distance_constraints(coords, location_type, config):
			continue
		
		# Place the location
		var location_data := _create_location(location_type, coords, config)
		_apply_location_to_grid(coords, location_data)
		
		placed += 1
		location_placed.emit(location_type, coords, location_data["name"])
	
	# Initialize locations_by_type if needed
	if not locations_by_type.has(location_type):
		locations_by_type[location_type] = []
	
	locations_complete.emit(location_type, placed)
	_emit_to_event_bus("locations_placed", [location_type, placed])
	
	print("LocationPlacer: Placed %d/%d %s locations" % [placed, target_count, location_type])
	
	return placed >= min_count

# =============================================================================
# CANDIDATE FINDING
# =============================================================================

func _find_valid_candidates(location_type: String, config: Dictionary) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	
	var required_terrain: Array = config.get("required_terrain", [])
	var elevation_range: Array = config.get("elevation_range", [0.0, 1.0])
	var requires_water: bool = config.get("requires_water_adjacent", false)
	var strategic: bool = config.get("strategic_placement", false)
	var along_routes: bool = config.get("along_routes", false)
	var prefer_rivers: bool = config.get("prefer_rivers", false)
	var near_settlements: bool = config.get("near_settlements", false)
	var between_settlements: bool = config.get("between_settlements", false)
	var distance_from_towns: Array = config.get("distance_from_towns", [])
	var min_distance_from_towns: Array = config.get("min_distance_from_towns", [])
	
	for coords in _hex_grid.cells:
		var cell: HexCell = _hex_grid.cells[coords]
		
		# Skip if already has a location
		if locations.has(coords):
			continue
		
		# Check terrain type
		if required_terrain.size() > 0 and not cell.terrain_type in required_terrain:
			continue
		
		# Check elevation range
		var elev_min: float = elevation_range[0] if elevation_range.size() > 0 else 0.0
		var elev_max: float = elevation_range[1] if elevation_range.size() > 1 else 1.0
		if cell.elevation < elev_min or cell.elevation > elev_max:
			continue
		
		# Check water adjacency
		if requires_water and not _is_adjacent_to_water(coords):
			continue
		
		# Check distance constraints
		if not _check_distance_constraints(coords, location_type, config):
			continue
		
		# Check strategic placement for forts
		if strategic and not _is_strategic_position(coords):
			# Still allow non-strategic positions, just with lower priority
			pass
		
		# Check near settlements for missions
		if near_settlements and not _is_near_settlement(coords, min_distance_from_towns):
			continue
		
		# Check between settlements for roadhouses
		if between_settlements and not _is_between_settlements(coords, distance_from_towns):
			continue
		
		# Check along routes for trading posts
		if along_routes and not _is_along_route(coords, prefer_rivers):
			continue
		
		candidates.append(coords)
	
	# Precompute priority for each candidate (avoids issues with randomness in sort comparison)
	var priorities := {}
	for coords in candidates:
		priorities[coords] = _get_candidate_priority(coords, location_type, config)
	
	# Sort candidates by priority using cached values
	candidates.sort_custom(func(a, b):
		return priorities[a] > priorities[b]
	)
	
	return candidates


func _get_candidate_priority(coords: Vector2i, location_type: String, config: Dictionary) -> float:
	var priority := 0.0
	var cell: HexCell = _hex_grid.get_cell(coords)
	
	if cell == null:
		return -1000.0
	
	# Prefer river adjacency for towns and trading posts
	if config.get("requires_water_adjacent", false) or config.get("prefer_rivers", false):
		if _river_generator and _river_generator.is_adjacent_to_river(coords):
			priority += 10.0
	
	# Prefer strategic positions for forts
	if config.get("strategic_placement", false):
		if _is_strategic_position(coords):
			priority += 15.0
	
	# For locations that should be between settlements
	if config.get("between_settlements", false):
		var town_distances := _get_distances_to_towns(coords)
		if town_distances.size() >= 2:
			# Prefer roughly equidistant from multiple towns
			var variance := _calculate_variance(town_distances)
			priority += 10.0 - variance  # Lower variance = higher priority
	
	# Add some randomness to avoid clustering
	priority += _rng.randf() * 2.0
	
	return priority

# =============================================================================
# CONSTRAINT CHECKING
# =============================================================================

func _is_adjacent_to_water(coords: Vector2i) -> bool:
	# Check for water terrain
	var neighbors := HexUtils.get_neighbors(coords)
	for n_coords in neighbors:
		var neighbor: HexCell = _hex_grid.get_cell(n_coords)
		if neighbor and neighbor.terrain_type in ["water", "deep_water"]:
			return true
	
	# Check for river
	if _river_generator and _river_generator.is_adjacent_to_river(coords):
		return true
	
	# Check if this hex has a river
	var cell: HexCell = _hex_grid.get_cell(coords)
	if cell and cell.has_river:
		return true
	
	return false


func _check_distance_constraints(coords: Vector2i, location_type: String, config: Dictionary) -> bool:
	var min_dist_same: int = config.get("min_distance_same_type", 1)
	var min_dist_any: int = config.get("min_distance_any_location", 1)
	
	# Check distance to same type
	if locations_by_type.has(location_type):
		for loc in locations_by_type[location_type]:
			var dist := HexUtils.distance(coords, loc["coords"])
			if dist < min_dist_same:
				return false
	
	# Check distance to any location
	for loc_coords in locations:
		var dist := HexUtils.distance(coords, loc_coords)
		if dist < min_dist_any:
			return false
	
	# Check specific distance from towns (for forts, missions, etc.)
	var min_dist_towns: Array = config.get("min_distance_from_towns", [])
	if min_dist_towns.size() >= 2:
		var min_d: int = min_dist_towns[0]
		var max_d: int = min_dist_towns[1]
		
		var towns: Array = locations_by_type.get("town", [])
		if towns.size() > 0:
			var closest_town_dist := 9999
			for town in towns:
				var dist := HexUtils.distance(coords, town["coords"])
				closest_town_dist = mini(closest_town_dist, dist)
			
			if closest_town_dist < min_d or closest_town_dist > max_d:
				return false
	
	return true


func _is_strategic_position(coords: Vector2i) -> bool:
	var cell: HexCell = _hex_grid.get_cell(coords)
	if cell == null:
		return false
	
	# Check for mountain pass: hex with mountains on opposite sides
	var neighbors := HexUtils.get_neighbors(coords)
	var mountain_directions: Array[int] = []
	
	for i in range(neighbors.size()):
		var n_coords: Vector2i = neighbors[i]
		var neighbor: HexCell = _hex_grid.get_cell(n_coords)
		if neighbor and neighbor.elevation > 0.8:
			mountain_directions.append(i)
	
	# Check for opposite directions (0-3, 1-4, 2-5)
	for dir in mountain_directions:
		var opposite := (dir + 3) % 6
		if opposite in mountain_directions:
			return true  # Mountain pass!
	
	# Check for river crossing
	if _river_generator and _river_generator.hex_has_river(coords):
		# Extra strategic if also has high ground nearby
		if cell.elevation > 0.5:
			return true
	
	# Check for overlooking position (higher than most neighbors)
	var higher_count := 0
	for n_coords in neighbors:
		var neighbor: HexCell = _hex_grid.get_cell(n_coords)
		if neighbor and cell.elevation > neighbor.elevation + 0.1:
			higher_count += 1
	
	if higher_count >= 4:
		return true  # Commanding view
	
	return false


func _is_near_settlement(coords: Vector2i, distance_range: Array) -> bool:
	if distance_range.size() < 2:
		distance_range = [3, 8]  # Default
	
	var min_dist: int = distance_range[0]
	var max_dist: int = distance_range[1]
	
	var towns: Array = locations_by_type.get("town", [])
	
	for town in towns:
		var dist := HexUtils.distance(coords, town["coords"])
		if dist >= min_dist and dist <= max_dist:
			return true
	
	return towns.is_empty()  # Allow if no towns yet


func _is_between_settlements(coords: Vector2i, distance_range: Array) -> bool:
	if distance_range.size() < 2:
		distance_range = [6, 14]  # Default
	
	var min_dist: int = distance_range[0]
	var max_dist: int = distance_range[1]
	
	var towns: Array = locations_by_type.get("town", [])
	var forts: Array = locations_by_type.get("fort", [])
	var settlements: Array = towns + forts
	
	if settlements.size() < 2:
		return true  # Can't check between if not enough settlements
	
	# Find settlements within the distance range
	var nearby_settlements := 0
	for settlement in settlements:
		var dist := HexUtils.distance(coords, settlement["coords"])
		if dist >= min_dist and dist <= max_dist:
			nearby_settlements += 1
	
	return nearby_settlements >= 1  # At least one settlement in range


func _is_along_route(coords: Vector2i, prefer_rivers: bool) -> bool:
	var cell: HexCell = _hex_grid.get_cell(coords)
	
	# Prefer river locations
	if prefer_rivers:
		if cell and cell.has_river:
			return true
		if _river_generator and _river_generator.is_adjacent_to_river(coords):
			return true
	
	# Check if roughly between two towns
	var towns: Array = locations_by_type.get("town", [])
	if towns.size() < 2:
		return true  # Can't determine routes without towns
	
	# Check if this hex lies roughly on a line between any two towns
	for i in range(towns.size()):
		for j in range(i + 1, towns.size()):
			var town_a: Vector2i = towns[i]["coords"]
			var town_b: Vector2i = towns[j]["coords"]
			
			var dist_a := HexUtils.distance(coords, town_a)
			var dist_b := HexUtils.distance(coords, town_b)
			var dist_ab := HexUtils.distance(town_a, town_b)
			
			# Check if roughly on the path (within 30% detour)
			if dist_a + dist_b <= dist_ab * 1.3:
				return true
	
	return false


func _get_distances_to_towns(coords: Vector2i) -> Array[int]:
	var distances: Array[int] = []
	var towns: Array = locations_by_type.get("town", [])
	
	for town in towns:
		distances.append(HexUtils.distance(coords, town["coords"]))
	
	return distances


func _calculate_variance(values: Array[int]) -> float:
	if values.size() < 2:
		return 0.0
	
	var sum := 0.0
	for v in values:
		sum += v
	var mean := sum / values.size()
	
	var variance_sum := 0.0
	for v in values:
		variance_sum += (v - mean) * (v - mean)
	
	return variance_sum / values.size()

# =============================================================================
# LOCATION CREATION
# =============================================================================

func _create_location(location_type: String, coords: Vector2i, config: Dictionary) -> Dictionary:
	var location_name := _generate_name(location_type)
	
	var location_data := {
		"type": location_type,
		"name": location_name,
		"coords": coords,
		"display_name": config.get("display_name", location_type.capitalize()),
		"properties": _generate_properties(location_type, coords)
	}
	
	# Store in locations dictionary
	locations[coords] = location_data
	
	# Store in type-grouped dictionary
	if not locations_by_type.has(location_type):
		locations_by_type[location_type] = []
	locations_by_type[location_type].append(location_data)
	
	return location_data


func _generate_name(location_type: String) -> String:
	var name := ""
	
	match location_type:
		"town":
			var names: Array = name_lists.get("town_names", ["Unnamed Town"])
			name = _pick_unique_name(names, "town")
		
		"fort":
			var prefixes: Array = name_lists.get("fort_prefixes", ["Fort"])
			var fort_names: Array = name_lists.get("fort_names", ["Unknown"])
			var suffixes: Array = name_lists.get("fort_suffixes", [""])
			
			var prefix: String = prefixes[_rng.randi() % prefixes.size()]
			var fort_name: String = fort_names[_rng.randi() % fort_names.size()]
			
			if _rng.randf() < 0.3 and suffixes.size() > 0:
				var suffix: String = suffixes[_rng.randi() % suffixes.size()]
				name = "%s %s" % [fort_name, suffix]
			else:
				name = "%s %s" % [prefix, fort_name]
		
		"cave":
			var names: Array = name_lists.get("cave_names", ["Unknown Cave"])
			name = _pick_unique_name(names, "cave")
		
		"trading_post":
			var names: Array = name_lists.get("trading_post_names", ["Trading Post"])
			name = _pick_unique_name(names, "trading_post")
		
		"mission":
			var names: Array = name_lists.get("mission_names", ["Mission"])
			name = _pick_unique_name(names, "mission")
		
		"caravan_camp":
			var names: Array = name_lists.get("caravan_names", ["Caravan Camp"])
			name = _pick_unique_name(names, "caravan_camp")
		
		"roadhouse":
			var names: Array = name_lists.get("roadhouse_names", ["Roadhouse"])
			name = _pick_unique_name(names, "roadhouse")
		
		_:
			name = "%s #%d" % [location_type.capitalize(), locations.size() + 1]
	
	return name


func _pick_unique_name(names: Array, category: String) -> String:
	if names.is_empty():
		return "Unknown"
	
	# Try to find unused name
	var available: Array = []
	for n in names:
		var key := "%s:%s" % [category, n]
		if not _used_names.has(key):
			available.append(n)
	
	var chosen: String
	if available.is_empty():
		# All names used, allow duplicates
		chosen = names[_rng.randi() % names.size()]
	else:
		chosen = available[_rng.randi() % available.size()]
	
	_used_names["%s:%s" % [category, chosen]] = true
	return chosen


func _generate_properties(location_type: String, coords: Vector2i) -> Dictionary:
	var props := {}
	var cell: HexCell = _hex_grid.get_cell(coords)
	
	match location_type:
		"town":
			props["population"] = _rng.randi_range(200, 800)
			props["specialization"] = ["farming", "mining", "trading", "fishing"][_rng.randi() % 4]
			if cell and cell.has_river:
				props["has_river_access"] = true
		
		"fort":
			props["garrison"] = _rng.randi_range(20, 100)
			props["condition"] = ["good", "fair", "poor"][_rng.randi() % 3]
		
		"cave":
			props["depth"] = ["shallow", "medium", "deep"][_rng.randi() % 3]
			props["explored"] = false
		
		"trading_post":
			props["goods"] = ["general", "weapons", "provisions", "horses"][_rng.randi() % 4]
		
		"mission":
			props["denomination"] = "Catholic"
			props["established"] = 1700 + _rng.randi_range(0, 150)
		
		"caravan_camp":
			props["temporary"] = _rng.randf() < 0.5
			props["capacity"] = _rng.randi_range(5, 20)
		
		"roadhouse":
			props["beds"] = _rng.randi_range(4, 12)
			props["has_stable"] = _rng.randf() < 0.7
	
	return props


func _apply_location_to_grid(coords: Vector2i, location_data: Dictionary) -> void:
	var cell: HexCell = _hex_grid.get_cell(coords)
	if cell:
		cell.location = location_data
		cell.update_location_visuals()

# =============================================================================
# QUERIES
# =============================================================================

## Gets all locations of a specific type.
func get_locations_by_type(location_type: String) -> Array:
	return locations_by_type.get(location_type, [])


## Gets the location at specific coordinates, if any.
func get_location_at(coords: Vector2i) -> Dictionary:
	return locations.get(coords, {})


## Gets all locations.
func get_all_locations() -> Dictionary:
	return locations


## Gets count of a specific location type.
func get_location_count(location_type: String) -> int:
	return locations_by_type.get(location_type, []).size()


## Checks if a hex has a location.
func has_location(coords: Vector2i) -> bool:
	return locations.has(coords)

# =============================================================================
# SERIALIZATION
# =============================================================================

## Converts all location data to an array for saving.
func to_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for coords in locations:
		var loc: Dictionary = locations[coords]
		result.append({
			"type": loc["type"],
			"name": loc["name"],
			"coords": {"q": coords.x, "r": coords.y},
			"properties": loc["properties"]
		})
	
	return result


## Loads location data from an array (for loading saves).
func from_array(data: Array, hex_grid: HexGrid) -> void:
	_hex_grid = hex_grid
	locations.clear()
	locations_by_type.clear()
	_clear_location_data()
	
	for loc_dict in data:
		var coords := Vector2i(loc_dict["coords"]["q"], loc_dict["coords"]["r"])
		var location_type: String = loc_dict["type"]
		
		var config: Dictionary = location_configs.get(location_type, {})
		
		var location_data := {
			"type": location_type,
			"name": loc_dict["name"],
			"coords": coords,
			"display_name": config.get("display_name", location_type.capitalize()),
			"properties": loc_dict.get("properties", {})
		}
		
		locations[coords] = location_data
		
		if not locations_by_type.has(location_type):
			locations_by_type[location_type] = []
		locations_by_type[location_type].append(location_data)
		
		_apply_location_to_grid(coords, location_data)

# =============================================================================
# UTILITY
# =============================================================================

func _emit_to_event_bus(signal_name: String, args: Array) -> void:
	var event_bus = Engine.get_main_loop().root.get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal(signal_name):
		match args.size():
			0: event_bus.emit_signal(signal_name)
			1: event_bus.emit_signal(signal_name, args[0])
			2: event_bus.emit_signal(signal_name, args[0], args[1])
