# river_generator.gd
# Generates rivers that flow from high elevation to low elevation.
# Rivers start in mountains/highlands and flow downhill to water bodies.
#
# ALGORITHM:
# 1. Find candidate source hexes (high elevation, not water)
# 2. For each source, trace path downhill using greedy descent
# 3. Continue until reaching water or getting stuck
# 4. Validate river length and discard short rivers
# 5. Handle river confluences when paths meet
#
# Rivers are stored as paths (arrays of coordinates) and each hex
# along the path is marked with has_river = true.

class_name RiverGenerator
extends RefCounted

# =============================================================================
# SIGNALS
# =============================================================================

signal rivers_generated(river_count: int)
signal river_created(river_id: int, length: int)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Minimum elevation for river sources
var source_elevation_min: float = 0.7

## Maximum elevation for river targets (water level)
var target_elevation_max: float = 0.3

## Minimum river length (in hexes) to be valid
var min_river_length: int = 5

## Target number of rivers to generate
var min_rivers: int = 2
var max_rivers: int = 4

## Maximum attempts to find valid source for each river
var max_attempts_per_river: int = 50

# =============================================================================
# STATE
# =============================================================================

## All generated rivers, each as an array of Vector2i coordinates
var rivers: Array[Dictionary] = []

## Map of coordinates to river IDs (for confluence tracking)
var _river_hex_map: Dictionary = {}

## Reference to the hex grid
var _hex_grid: HexGrid = null

## Random number generator with controlled seed
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	pass


## Loads configuration from the locations config file.
func load_config(config: Dictionary) -> void:
	var river_config: Dictionary = config.get("river_config", {})
	
	min_rivers = river_config.get("min_rivers", 2)
	max_rivers = river_config.get("max_rivers", 4)
	min_river_length = river_config.get("min_length", 5)
	source_elevation_min = river_config.get("source_elevation_min", 0.7)
	target_elevation_max = river_config.get("target_elevation_max", 0.3)
	max_attempts_per_river = river_config.get("max_attempts_per_river", 50)

# =============================================================================
# MAIN GENERATION
# =============================================================================

## Generates rivers for the given hex grid.
## @param hex_grid: HexGrid - The grid to generate rivers for.
## @param generation_seed: int - Seed for reproducible generation.
## @return int - Number of rivers generated.
func generate_rivers(hex_grid: HexGrid, generation_seed: int) -> int:
	_hex_grid = hex_grid
	_rng.seed = generation_seed + 99999  # Offset to differ from terrain seed
	
	# Clear previous rivers
	rivers.clear()
	_river_hex_map.clear()
	_clear_river_data()
	
	# Find all valid source hexes (high elevation)
	var source_candidates := _find_source_candidates()
	if source_candidates.is_empty():
		push_warning("RiverGenerator: No valid source hexes found for rivers")
		return 0
	
	# Shuffle candidates for variety
	source_candidates.shuffle()
	
	# Determine target river count
	var target_count := _rng.randi_range(min_rivers, max_rivers)
	var rivers_created := 0
	var attempts := 0
	var candidate_index := 0
	
	while rivers_created < target_count and attempts < max_attempts_per_river * target_count:
		attempts += 1
		
		# Get next candidate source
		if candidate_index >= source_candidates.size():
			candidate_index = 0
			source_candidates.shuffle()
		
		var source: Vector2i = source_candidates[candidate_index]
		candidate_index += 1
		
		# Skip if this hex already has a river
		if _river_hex_map.has(source):
			continue
		
		# Try to create a river from this source
		var river_path := _trace_river_path(source)
		
		if river_path.size() >= min_river_length:
			var river_id := rivers.size()
			var river_data := {
				"id": river_id,
				"source": source,
				"path": river_path,
				"length": river_path.size(),
				"reaches_water": _reaches_water(river_path),
				"merged_with": []  # Track confluences
			}
			
			rivers.append(river_data)
			_apply_river_to_grid(river_data)
			rivers_created += 1
			
			river_created.emit(river_id, river_path.size())
	
	rivers_generated.emit(rivers_created)
	_emit_to_event_bus("rivers_generated", [rivers_created])
	
	print("RiverGenerator: Created %d rivers" % rivers_created)
	return rivers_created


func _clear_river_data() -> void:
	if _hex_grid == null:
		return
	
	for cell in _hex_grid.cells.values():
		cell.has_river = false
		cell.river_flow_direction = Vector2i.ZERO


func _find_source_candidates() -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	
	for coords in _hex_grid.cells:
		var cell: HexCell = _hex_grid.cells[coords]
		
		# Must be high elevation
		if cell.elevation < source_elevation_min:
			continue
		
		# Must not be water
		if cell.terrain_type in ["water", "deep_water"]:
			continue
		
		# Prefer hexes that have lower neighbors (actual peaks might not flow anywhere)
		var has_lower_neighbor := false
		var neighbors := HexUtils.get_neighbors(coords)
		for n_coords in neighbors:
			var neighbor: HexCell = _hex_grid.get_cell(n_coords)
			if neighbor and neighbor.elevation < cell.elevation:
				has_lower_neighbor = true
				break
		
		if has_lower_neighbor:
			candidates.append(coords)
	
	return candidates

# =============================================================================
# RIVER PATH TRACING
# =============================================================================

## Traces a river path from source to water using greedy descent.
## @param source: Vector2i - Starting coordinates.
## @return Array[Vector2i] - Path of coordinates from source to end.
func _trace_river_path(source: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [source]
	var current := source
	var visited: Dictionary = {source: true}
	
	var max_steps := 200  # Safety limit
	var steps := 0
	
	while steps < max_steps:
		steps += 1
		
		var cell: HexCell = _hex_grid.get_cell(current)
		if cell == null:
			break
		
		# Check if we've reached water
		if cell.elevation < target_elevation_max or cell.terrain_type in ["water", "deep_water"]:
			break
		
		# Check if we've hit an existing river (confluence)
		if _river_hex_map.has(current) and current != source:
			# Merge with existing river
			break
		
		# Find the lowest neighbor
		var next_hex := _find_lowest_neighbor(current, visited)
		
		if next_hex == Vector2i(-9999, -9999):  # No valid neighbor found
			break
		
		# Record flow direction
		cell.river_flow_direction = next_hex - current
		
		visited[next_hex] = true
		path.append(next_hex)
		current = next_hex
	
	return path


## Finds the lowest elevation neighbor that hasn't been visited.
## Uses slight randomization when multiple neighbors have similar elevation.
func _find_lowest_neighbor(coords: Vector2i, visited: Dictionary) -> Vector2i:
	var neighbors := HexUtils.get_neighbors(coords)
	var current_cell: HexCell = _hex_grid.get_cell(coords)
	
	if current_cell == null:
		return Vector2i(-9999, -9999)
	
	var candidates: Array[Dictionary] = []
	
	for n_coords in neighbors:
		if visited.has(n_coords):
			continue
		
		var neighbor: HexCell = _hex_grid.get_cell(n_coords)
		if neighbor == null:
			continue
		
		# Must be lower or equal (rivers don't flow uphill)
		if neighbor.elevation <= current_cell.elevation:
			candidates.append({
				"coords": n_coords,
				"elevation": neighbor.elevation,
				"is_water": neighbor.terrain_type in ["water", "deep_water"],
				"has_river": _river_hex_map.has(n_coords)
			})
	
	if candidates.is_empty():
		return Vector2i(-9999, -9999)
	
	# Sort by elevation (lowest first), prefer water, then existing rivers
	candidates.sort_custom(func(a, b):
		# Strongly prefer water destinations
		if a["is_water"] and not b["is_water"]:
			return true
		if b["is_water"] and not a["is_water"]:
			return false
		# Then prefer joining existing rivers (confluences)
		if a["has_river"] and not b["has_river"]:
			return true
		if b["has_river"] and not a["has_river"]:
			return false
		# Finally, prefer lower elevation
		return a["elevation"] < b["elevation"]
	)
	
	# Add slight randomization among top candidates with similar elevation
	var best_elevation: float = candidates[0]["elevation"]
	var similar_candidates: Array[Dictionary] = []
	
	for c in candidates:
		if c["elevation"] <= best_elevation + 0.05:  # Within 5% elevation
			similar_candidates.append(c)
	
	# Pick randomly from similar candidates
	var choice: Dictionary = similar_candidates[_rng.randi() % similar_candidates.size()]
	return choice["coords"]


func _reaches_water(path: Array[Vector2i]) -> bool:
	if path.is_empty():
		return false
	
	var end_coords: Vector2i = path[path.size() - 1]
	var end_cell: HexCell = _hex_grid.get_cell(end_coords)
	
	if end_cell == null:
		return false
	
	return end_cell.terrain_type in ["water", "deep_water"] or end_cell.elevation < target_elevation_max

# =============================================================================
# APPLY RIVERS TO GRID
# =============================================================================

func _apply_river_to_grid(river_data: Dictionary) -> void:
	var path: Array = river_data["path"]
	var river_id: int = river_data["id"]
	
	for i in range(path.size()):
		var coords: Vector2i = path[i]
		var cell: HexCell = _hex_grid.get_cell(coords)
		
		if cell == null:
			continue
		
		# Check for confluence
		if _river_hex_map.has(coords):
			var existing_river_id: int = _river_hex_map[coords]
			if existing_river_id != river_id:
				river_data["merged_with"].append(existing_river_id)
		
		cell.has_river = true
		
		# Set flow direction (to next hex in path)
		if i < path.size() - 1:
			var next_coords: Vector2i = path[i + 1]
			cell.river_flow_direction = next_coords - coords
		else:
			cell.river_flow_direction = Vector2i.ZERO  # End of river
		
		# Track which river(s) pass through this hex
		if not _river_hex_map.has(coords):
			_river_hex_map[coords] = river_id
		
		# Update cell visuals
		cell.update_river_visuals()

# =============================================================================
# QUERIES
# =============================================================================

## Returns all hexes that have rivers.
func get_river_hexes() -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for coords in _river_hex_map:
		hexes.append(coords)
	return hexes


## Checks if a hex is adjacent to a river.
func is_adjacent_to_river(coords: Vector2i) -> bool:
	var neighbors := HexUtils.get_neighbors(coords)
	for n_coords in neighbors:
		if _river_hex_map.has(n_coords):
			return true
	return false


## Gets river data by ID.
func get_river(river_id: int) -> Dictionary:
	if river_id >= 0 and river_id < rivers.size():
		return rivers[river_id]
	return {}


## Gets all rivers.
func get_all_rivers() -> Array[Dictionary]:
	return rivers


## Checks if a specific hex has a river.
func hex_has_river(coords: Vector2i) -> bool:
	return _river_hex_map.has(coords)

# =============================================================================
# SERIALIZATION
# =============================================================================

## Converts river data to a dictionary for saving.
func to_dict() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for river in rivers:
		var path_array: Array[Dictionary] = []
		for coords in river["path"]:
			path_array.append({"q": coords.x, "r": coords.y})
		
		result.append({
			"id": river["id"],
			"source": {"q": river["source"].x, "r": river["source"].y},
			"path": path_array,
			"length": river["length"],
			"reaches_water": river["reaches_water"],
			"merged_with": river["merged_with"]
		})
	
	return result


## Loads river data from a dictionary (for loading saves).
func from_dict(data: Array, hex_grid: HexGrid) -> void:
	_hex_grid = hex_grid
	rivers.clear()
	_river_hex_map.clear()
	_clear_river_data()
	
	for river_dict in data:
		var path: Array[Vector2i] = []
		for coords_dict in river_dict["path"]:
			path.append(Vector2i(coords_dict["q"], coords_dict["r"]))
		
		var river_data := {
			"id": river_dict["id"],
			"source": Vector2i(river_dict["source"]["q"], river_dict["source"]["r"]),
			"path": path,
			"length": river_dict["length"],
			"reaches_water": river_dict["reaches_water"],
			"merged_with": river_dict.get("merged_with", [])
		}
		
		rivers.append(river_data)
		_apply_river_to_grid(river_data)

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
