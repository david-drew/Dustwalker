# map_validator.gd
# Validates generated maps to ensure they meet all constraints.
# Checks location counts, placement rules, river validity, etc.
#
# Returns a validation result with:
# - valid: bool - Whether the map passes all critical checks
# - errors: Array[String] - Critical failures that make map invalid
# - warnings: Array[String] - Non-critical issues
# - stats: Dictionary - Statistics about the generated map

class_name MapValidator
extends RefCounted

# =============================================================================
# VALIDATION RESULT
# =============================================================================

class ValidationResult:
	var valid: bool = true
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var stats: Dictionary = {}
	
	func add_error(message: String) -> void:
		errors.append(message)
		valid = false
	
	func add_warning(message: String) -> void:
		warnings.append(message)
	
	func to_dict() -> Dictionary:
		return {
			"valid": valid,
			"errors": errors,
			"warnings": warnings,
			"stats": stats
		}

# =============================================================================
# CONFIGURATION
# =============================================================================

## Location type configurations for constraint checking
var location_configs: Dictionary = {}

## River configuration
var river_config: Dictionary = {}

# =============================================================================
# STATE
# =============================================================================

var _hex_grid: HexGrid = null
var _river_generator: RiverGenerator = null
var _location_placer: LocationPlacer = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func load_config(config: Dictionary) -> void:
	location_configs = config.get("location_types", {})
	river_config = config.get("river_config", {})

# =============================================================================
# MAIN VALIDATION
# =============================================================================

## Validates a complete map.
## @param hex_grid: HexGrid - The grid to validate.
## @param river_generator: RiverGenerator - River data.
## @param location_placer: LocationPlacer - Location data.
## @return ValidationResult - Detailed validation results.
func validate_map(hex_grid: HexGrid, river_generator: RiverGenerator, location_placer: LocationPlacer) -> ValidationResult:
	_hex_grid = hex_grid
	_river_generator = river_generator
	_location_placer = location_placer
	
	var result := ValidationResult.new()
	
	# Collect statistics
	_collect_stats(result)
	
	# Run all validation checks
	_validate_terrain(result)
	_validate_rivers(result)
	_validate_location_counts(result)
	_validate_location_constraints(result)
	_validate_map_connectivity(result)
	
	return result


func _collect_stats(result: ValidationResult) -> void:
	var stats := {}
	
	# Map size
	stats["map_width"] = _hex_grid.map_width
	stats["map_height"] = _hex_grid.map_height
	stats["total_hexes"] = _hex_grid.cells.size()
	
	# Terrain distribution
	var terrain_counts := _hex_grid.get_terrain_statistics()
	stats["terrain_distribution"] = terrain_counts
	
	# River stats
	if _river_generator:
		var rivers := _river_generator.get_all_rivers()
		stats["river_count"] = rivers.size()
		stats["river_hexes"] = _river_generator.get_river_hexes().size()
		
		var total_length := 0
		var rivers_reaching_water := 0
		for river in rivers:
			total_length += river["length"]
			if river["reaches_water"]:
				rivers_reaching_water += 1
		stats["total_river_length"] = total_length
		stats["rivers_reaching_water"] = rivers_reaching_water
	
	# Location stats
	if _location_placer:
		var location_counts := {}
		for loc_type in location_configs:
			location_counts[loc_type] = _location_placer.get_location_count(loc_type)
		stats["location_counts"] = location_counts
		stats["total_locations"] = _location_placer.get_all_locations().size()
	
	# Elevation stats
	stats["avg_elevation"] = _hex_grid.get_average_elevation()
	stats["avg_moisture"] = _hex_grid.get_average_moisture()
	
	result.stats = stats

# =============================================================================
# TERRAIN VALIDATION
# =============================================================================

func _validate_terrain(result: ValidationResult) -> void:
	var terrain_counts: Dictionary = result.stats.get("terrain_distribution", {})
	var total:int = result.stats.get("total_hexes", 1)
	
	# Check for reasonable terrain distribution
	var water_count:int = terrain_counts.get("water", 0) + terrain_counts.get("deep_water", 0)
	var water_percent := float(water_count) / float(total) * 100.0
	
	if water_percent < 5.0:
		result.add_warning("Very little water (%.1f%%) - may affect town placement" % water_percent)
	elif water_percent > 50.0:
		result.add_warning("Excessive water (%.1f%%) - limited land for locations" % water_percent)
	
	# Check for mountain presence (needed for river sources and caves)
	var mountain_count:int = terrain_counts.get("mountains", 0) + terrain_counts.get("mountain_peak", 0) + terrain_counts.get("highlands", 0)
	if mountain_count < 10:
		result.add_warning("Very few high elevation hexes (%d) - may affect river generation and cave placement" % mountain_count)
	
	# Check for plains/grassland (needed for towns)
	var plains_count:int = terrain_counts.get("plains", 0) + terrain_counts.get("grassland", 0)
	if plains_count < 20:
		result.add_warning("Limited plains/grassland (%d) - may affect town placement" % plains_count)

# =============================================================================
# RIVER VALIDATION
# =============================================================================

func _validate_rivers(result: ValidationResult) -> void:
	if _river_generator == null:
		result.add_warning("No river generator - skipping river validation")
		return
	
	var rivers := _river_generator.get_all_rivers()
	var min_rivers: int = river_config.get("min_rivers", 2)
	var min_length: int = river_config.get("min_length", 5)
	
	# Check river count
	if rivers.size() < min_rivers:
		result.add_error("Too few rivers: %d (minimum: %d)" % [rivers.size(), min_rivers])
	
	# Validate each river
	for river in rivers:
		var river_id: int = river["id"]
		var path: Array = river["path"]
		var length: int = river["length"]
		
		# Check minimum length
		if length < min_length:
			result.add_warning("River %d is short (%d hexes, minimum: %d)" % [river_id, length, min_length])
		
		# Check if river reaches water
		if not river["reaches_water"]:
			result.add_warning("River %d does not reach water/ocean" % river_id)
		
		# Validate flow direction (should always go downhill or flat)
		if not _validate_river_flow(path):
			result.add_warning("River %d has invalid flow (goes uphill)" % river_id)


func _validate_river_flow(path: Array) -> bool:
	if path.size() < 2:
		return true
	
	for i in range(path.size() - 1):
		var current_coords: Vector2i = path[i]
		var next_coords: Vector2i = path[i + 1]
		
		var current_cell: HexCell = _hex_grid.get_cell(current_coords)
		var next_cell: HexCell = _hex_grid.get_cell(next_coords)
		
		if current_cell == null or next_cell == null:
			continue
		
		# Allow small uphill tolerance for noise in elevation data
		if next_cell.elevation > current_cell.elevation + 0.05:
			return false
	
	return true

# =============================================================================
# LOCATION COUNT VALIDATION
# =============================================================================

func _validate_location_counts(result: ValidationResult) -> void:
	if _location_placer == null:
		result.add_warning("No location placer - skipping location validation")
		return
	
	for loc_type in location_configs:
		var config: Dictionary = location_configs[loc_type]
		var min_count: int = config.get("min_count", 0)
		var max_count: int = config.get("max_count", 99)
		var actual_count: int = _location_placer.get_location_count(loc_type)
		
		if actual_count < min_count:
			result.add_error("%s count too low: %d (minimum: %d)" % [
				loc_type.capitalize(), actual_count, min_count
			])
		elif actual_count > max_count:
			result.add_warning("%s count too high: %d (maximum: %d)" % [
				loc_type.capitalize(), actual_count, max_count
			])

# =============================================================================
# LOCATION CONSTRAINT VALIDATION
# =============================================================================

func _validate_location_constraints(result: ValidationResult) -> void:
	if _location_placer == null:
		return
	
	var all_locations := _location_placer.get_all_locations()
	
	for coords in all_locations:
		var location: Dictionary = all_locations[coords]
		var loc_type: String = location["type"]
		var config: Dictionary = location_configs.get(loc_type, {})
		
		var cell: HexCell = _hex_grid.get_cell(coords)
		if cell == null:
			result.add_error("Location '%s' at invalid coordinates %s" % [location["name"], coords])
			continue
		
		# Validate terrain
		var required_terrain: Array = config.get("required_terrain", [])
		if required_terrain.size() > 0 and not cell.terrain_type in required_terrain:
			result.add_error("Location '%s' (%s) on invalid terrain: %s (requires: %s)" % [
				location["name"], loc_type, cell.terrain_type, required_terrain
			])
		
		# Validate elevation
		var elevation_range: Array = config.get("elevation_range", [0.0, 1.0])
		var elev_min: float = elevation_range[0] if elevation_range.size() > 0 else 0.0
		var elev_max: float = elevation_range[1] if elevation_range.size() > 1 else 1.0
		
		if cell.elevation < elev_min or cell.elevation > elev_max:
			result.add_warning("Location '%s' (%s) at unusual elevation: %.2f (expected: %.2f-%.2f)" % [
				location["name"], loc_type, cell.elevation, elev_min, elev_max
			])
		
		# Validate water adjacency for towns
		if config.get("requires_water_adjacent", false):
			if not _is_adjacent_to_water(coords):
				result.add_error("Town '%s' is not adjacent to water" % location["name"])
		
		# Validate distance constraints
		_validate_location_distances(coords, location, config, result)


func _validate_location_distances(coords: Vector2i, location: Dictionary, config: Dictionary, result: ValidationResult) -> void:
	var loc_type: String = location["type"]
	var min_dist_same: int = config.get("min_distance_same_type", 1)
	
	# Check distance to same type
	var same_type_locations := _location_placer.get_locations_by_type(loc_type)
	for other in same_type_locations:
		if other["coords"] == coords:
			continue
		
		var dist := HexUtils.distance(coords, other["coords"])
		if dist < min_dist_same:
			result.add_warning("%s '%s' too close to '%s' (%d hexes, minimum: %d)" % [
				loc_type.capitalize(), location["name"], other["name"], dist, min_dist_same
			])


func _is_adjacent_to_water(coords: Vector2i) -> bool:
	var neighbors := HexUtils.get_neighbors(coords)
	for n_coords in neighbors:
		var neighbor: HexCell = _hex_grid.get_cell(n_coords)
		if neighbor and neighbor.terrain_type in ["water", "deep_water"]:
			return true
	
	if _river_generator and _river_generator.is_adjacent_to_river(coords):
		return true
	
	var cell: HexCell = _hex_grid.get_cell(coords)
	if cell and cell.has_river:
		return true
	
	return false

# =============================================================================
# CONNECTIVITY VALIDATION
# =============================================================================

func _validate_map_connectivity(result: ValidationResult) -> void:
	# Check that settlements are not isolated
	# (This is a simplified check - full pathfinding would be more thorough)
	
	var towns := _location_placer.get_locations_by_type("town") if _location_placer else []
	
	if towns.size() < 2:
		return
	
	# Check that each town can theoretically reach another town
	# by traversing passable terrain
	for i in range(towns.size()):
		var town: Dictionary = towns[i]
		var town_coords: Vector2i = town["coords"]
		
		var can_reach_another := false
		
		for j in range(towns.size()):
			if i == j:
				continue
			
			var other: Dictionary = towns[j]
			var other_coords: Vector2i = other["coords"]
			
			# Simple check: is there a passable path between them?
			# (Using straight-line hex distance and checking terrain along the way)
			var path := HexUtils.get_line(town_coords, other_coords)
			var blocked := false
			
			for coords in path:
				var cell: HexCell = _hex_grid.get_cell(coords)
				if cell and not cell.is_passable():
					blocked = true
					break
			
			if not blocked:
				can_reach_another = true
				break
		
		if not can_reach_another:
			result.add_warning("Town '%s' may be isolated (no direct passable path to other towns)" % town["name"])

# =============================================================================
# UTILITY
# =============================================================================

## Generates a human-readable validation report.
func generate_report(result: ValidationResult) -> String:
	var lines: Array[String] = []
	
	lines.append("=" .repeat(50))
	lines.append("MAP VALIDATION REPORT")
	lines.append("=" .repeat(50))
	lines.append("")
	
	# Overall status
	if result.valid:
		lines.append("STATUS: VALID ✓")
	else:
		lines.append("STATUS: INVALID ✗")
	lines.append("")
	
	# Statistics
	lines.append("-" .repeat(30))
	lines.append("STATISTICS")
	lines.append("-" .repeat(30))
	
	var stats := result.stats
	lines.append("Map Size: %dx%d (%d hexes)" % [
		stats.get("map_width", 0),
		stats.get("map_height", 0),
		stats.get("total_hexes", 0)
	])
	lines.append("Rivers: %d (total length: %d hexes)" % [
		stats.get("river_count", 0),
		stats.get("total_river_length", 0)
	])
	lines.append("Total Locations: %d" % stats.get("total_locations", 0))
	
	var loc_counts: Dictionary = stats.get("location_counts", {})
	for loc_type in loc_counts:
		lines.append("  - %s: %d" % [loc_type.capitalize(), loc_counts[loc_type]])
	
	lines.append("Avg Elevation: %.2f" % stats.get("avg_elevation", 0))
	lines.append("Avg Moisture: %.2f" % stats.get("avg_moisture", 0))
	lines.append("")
	
	# Errors
	if result.errors.size() > 0:
		lines.append("-" .repeat(30))
		lines.append("ERRORS (%d)" % result.errors.size())
		lines.append("-" .repeat(30))
		for error in result.errors:
			lines.append("✗ " + error)
		lines.append("")
	
	# Warnings
	if result.warnings.size() > 0:
		lines.append("-" .repeat(30))
		lines.append("WARNINGS (%d)" % result.warnings.size())
		lines.append("-" .repeat(30))
		for warning in result.warnings:
			lines.append("! " + warning)
		lines.append("")
	
	lines.append("=" .repeat(50))
	
	return "\n".join(lines)
