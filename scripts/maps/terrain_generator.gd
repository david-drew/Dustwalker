# terrain_generator.gd
# Procedural terrain generation using FastNoiseLite for elevation and moisture maps.
# Assigns terrain types based on configurable elevation/moisture ranges.
#
# ALGORITHM OVERVIEW:
# 1. Generate elevation map using layered Perlin noise (multiple octaves)
# 2. Generate moisture map using separate noise with different parameters
# 3. For each hex, determine terrain type based on elevation + moisture
# 4. Apply smoothing pass to reduce single-hex terrain fragments
# 5. Apply color variation for visual distinction
#
# NOISE PARAMETERS EXPLAINED:
# - Scale: How "zoomed in" the noise is. Smaller = larger features.
# - Octaves: Number of noise layers. More = more detail.
# - Persistence: How much each octave contributes. Higher = rougher terrain.
# - Lacunarity: Frequency multiplier between octaves. Higher = more fine detail.

class_name TerrainGenerator
extends RefCounted

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when generation starts.
signal generation_started(seed_value: int)

## Emitted periodically during generation with progress (0.0 to 1.0).
signal generation_progress(progress: float)

## Emitted when generation completes.
signal generation_complete(seed_value: int)

## Emitted for each hex terrain assignment (debug mode only).
signal terrain_assigned(coords: Vector2i, terrain_type: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Whether to emit per-hex terrain_assigned signals (performance impact).
var verbose_signals: bool = false

## The configuration dictionary loaded from JSON.
var config: Dictionary = {}

## Terrain type definitions from config.
var terrain_types: Dictionary = {}

## Color variation settings.
var color_variation: Dictionary = {}

## Generation parameters.
var generation_params: Dictionary = {}

## Smoothing parameters.
var smoothing_params: Dictionary = {}

# =============================================================================
# NOISE GENERATORS
# =============================================================================

var _elevation_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite

## Current generation seed.
var current_seed: int = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	_elevation_noise = FastNoiseLite.new()
	_moisture_noise = FastNoiseLite.new()
	
	# Set noise type to OpenSimplex2 for smooth, natural-looking terrain
	_elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


## Loads configuration from the terrain config JSON file.
## @param config_path: String - Path to the config file (relative to data/maps/).
func load_config(config_path: String = "terrain_config") -> void:
	# Try to use DataLoader autoload if available
	if Engine.has_singleton("DataLoader"):
		var loader = Engine.get_singleton("DataLoader")
		config = loader.load_map_config(config_path)
	else:
		# Fallback: load directly
		var full_path := "res://data/maps/%s.json" % config_path
		if FileAccess.file_exists(full_path):
			var file := FileAccess.open(full_path, FileAccess.READ)
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				config = json.data
			file.close()
	
	if config.is_empty():
		config = _get_default_config()
	
	# Extract sub-configurations
	terrain_types = config.get("terrain_types", {})
	color_variation = config.get("color_variation", {})
	generation_params = config.get("generation", {})
	smoothing_params = generation_params.get("smoothing", {})
	
	_configure_noise()


## Loads config using an existing DataLoader reference.
func load_config_with_loader(loader: Node, config_path: String = "terrain_config") -> void:
	if loader and loader.has_method("load_map_config"):
		config = loader.load_map_config(config_path)
	
	if config.is_empty():
		config = _get_default_config()
	
	terrain_types = config.get("terrain_types", {})
	color_variation = config.get("color_variation", {})
	generation_params = config.get("generation", {})
	smoothing_params = generation_params.get("smoothing", {})
	
	_configure_noise()


func _configure_noise() -> void:
	var elevation_config: Dictionary = generation_params.get("elevation", {})
	var moisture_config: Dictionary = generation_params.get("moisture", {})
	
	# Configure elevation noise
	_elevation_noise.frequency = elevation_config.get("scale", 0.045)
	_elevation_noise.fractal_octaves = elevation_config.get("octaves", 4)
	_elevation_noise.fractal_gain = elevation_config.get("persistence", 0.5)
	_elevation_noise.fractal_lacunarity = elevation_config.get("lacunarity", 2.0)
	_elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	
	# Configure moisture noise
	_moisture_noise.frequency = moisture_config.get("scale", 0.06)
	_moisture_noise.fractal_octaves = moisture_config.get("octaves", 3)
	_moisture_noise.fractal_gain = moisture_config.get("persistence", 0.5)
	_moisture_noise.fractal_lacunarity = moisture_config.get("lacunarity", 2.0)
	_moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM


func _get_default_config() -> Dictionary:
	return {
		"generation": {
			"seed": 0,
			"auto_seed": true,
			"elevation": {"scale": 0.045, "octaves": 4, "persistence": 0.5, "lacunarity": 2.0},
			"moisture": {"scale": 0.06, "octaves": 3, "persistence": 0.5, "lacunarity": 2.0},
			"smoothing": {"enabled": true, "neighbor_threshold": 4, "iterations": 1}
		},
		"terrain_types": {
			"water": {"color": "#2b6f8f", "elevation_min": 0.0, "elevation_max": 0.3, "moisture_min": 0.0, "moisture_max": 1.0},
			"plains": {"color": "#7bae5a", "elevation_min": 0.3, "elevation_max": 0.6, "moisture_min": 0.0, "moisture_max": 1.0},
			"mountains": {"color": "#5b5b4f", "elevation_min": 0.6, "elevation_max": 1.0, "moisture_min": 0.0, "moisture_max": 1.0}
		},
		"color_variation": {"enabled": true, "brightness_range": 0.12, "saturation_range": 0.08, "hue_range": 0.02}
	}

# =============================================================================
# SEED MANAGEMENT
# =============================================================================

## Sets the generation seed and updates noise generators.
## @param seed_value: int - The seed to use (0 = generate random seed).
func set_seed(seed_value: int) -> void:
	if seed_value == 0 or generation_params.get("auto_seed", true):
		current_seed = randi()
	else:
		current_seed = seed_value
	
	_elevation_noise.seed = current_seed
	# Offset moisture seed so it's not correlated with elevation
	_moisture_noise.seed = current_seed + 12345


## Gets the current seed.
func get_seed() -> int:
	return current_seed


## Generates a new random seed.
func randomize_seed() -> int:
	current_seed = randi()
	_elevation_noise.seed = current_seed
	_moisture_noise.seed = current_seed + 12345
	return current_seed

# =============================================================================
# TERRAIN GENERATION
# =============================================================================

## Generates terrain for an entire hex grid.
## @param hex_grid: HexGrid - The grid to generate terrain for.
## @param seed_value: int - Seed to use (0 = random).
func generate_terrain(hex_grid: HexGrid, seed_value: int = 0) -> void:
	set_seed(seed_value)
	
	generation_started.emit(current_seed)
	_emit_to_event_bus("map_generation_started", [current_seed])
	
	var cells := hex_grid.cells
	var total_cells := cells.size()
	var processed := 0
	
	# Phase 1: Generate elevation and moisture values
	for coords in cells:
		var cell: HexCell = cells[coords]
		_generate_cell_values(cell, coords)
		
		processed += 1
		if processed % 100 == 0:
			var progress := float(processed) / float(total_cells) * 0.5  # 0-50%
			generation_progress.emit(progress)
			_emit_to_event_bus("map_generation_progress", [progress])
	
	# Phase 2: Assign terrain types
	processed = 0
	for coords in cells:
		var cell: HexCell = cells[coords]
		_assign_terrain_type(cell)
		
		processed += 1
		if processed % 100 == 0:
			var progress := 0.5 + float(processed) / float(total_cells) * 0.3  # 50-80%
			generation_progress.emit(progress)
			_emit_to_event_bus("map_generation_progress", [progress])
	
	# Phase 3: Smoothing pass
	if smoothing_params.get("enabled", true):
		var iterations: int = smoothing_params.get("iterations", 1)
		for i in range(iterations):
			_smooth_terrain(hex_grid)
			var progress := 0.8 + float(i + 1) / float(iterations) * 0.15  # 80-95%
			generation_progress.emit(progress)
			_emit_to_event_bus("map_generation_progress", [progress])
	
	# Phase 4: Apply color variations
	for coords in cells:
		var cell: HexCell = cells[coords]
		_apply_color_variation(cell)
	
	generation_progress.emit(1.0)
	_emit_to_event_bus("map_generation_progress", [1.0])
	
	generation_complete.emit(current_seed)
	_emit_to_event_bus("map_generation_complete", [current_seed])


func _generate_cell_values(cell: HexCell, coords: Vector2i) -> void:
	# Get pixel position for noise sampling (use axial coords for consistency)
	var sample_x := float(coords.x)
	var sample_y := float(coords.y)
	
	# Apply offsets from config
	var elev_offset: Dictionary  = generation_params.get("elevation", {}).get("offset", {})
	var moist_offset: Dictionary = generation_params.get("moisture", {}).get("offset", {})
	
	var elev_x:float  = sample_x + elev_offset.get("x", 0.0)
	var elev_y:float  = sample_y + elev_offset.get("y", 0.0)
	var moist_x:float = sample_x + moist_offset.get("x", 1000.0)
	var moist_y:float = sample_y + moist_offset.get("y", 1000.0)
	
	# Generate noise values (-1 to 1) and normalize to (0 to 1)
	var raw_elevation := _elevation_noise.get_noise_2d(elev_x, elev_y)
	var raw_moisture  := _moisture_noise.get_noise_2d(moist_x, moist_y)
	
	cell.elevation = (raw_elevation + 1.0) * 0.5
	cell.moisture = (raw_moisture + 1.0) * 0.5


func _assign_terrain_type(cell: HexCell) -> void:
	var best_terrain := "plains"  # Default fallback
	var best_priority := -1
	
	for terrain_name in terrain_types:
		var terrain_data: Dictionary = terrain_types[terrain_name]
		
		var elev_min: float = terrain_data.get("elevation_min", 0.0)
		var elev_max: float = terrain_data.get("elevation_max", 1.0)
		var moist_min: float = terrain_data.get("moisture_min", 0.0)
		var moist_max: float = terrain_data.get("moisture_max", 1.0)
		var priority: int = terrain_data.get("priority", 0)
		
		# Check if cell values fall within this terrain's range
		if cell.elevation >= elev_min and cell.elevation < elev_max:
			if cell.moisture >= moist_min and cell.moisture < moist_max:
				# Use priority to resolve any remaining overlaps
				if priority > best_priority:
					best_terrain = terrain_name
					best_priority = priority
	
	cell.terrain_type = best_terrain
	
	if verbose_signals:
		terrain_assigned.emit(cell.axial_coords, best_terrain)


func _smooth_terrain(hex_grid: HexGrid) -> void:
	var threshold: int = smoothing_params.get("neighbor_threshold", 4)
	var protect_water: bool = smoothing_params.get("protect_water", true)
	var protect_mountains: bool = smoothing_params.get("protect_mountains", true)
	
	# Build a map of changes to apply (don't modify during iteration)
	var changes: Dictionary = {}
	
	for coords in hex_grid.cells:
		var cell: HexCell = hex_grid.cells[coords]
		
		# Skip protected terrain types
		if protect_water and (cell.terrain_type == "water" or cell.terrain_type == "deep_water"):
			continue
		if protect_mountains and (cell.terrain_type == "mountains" or cell.terrain_type == "mountain_peak"):
			continue
		
		# Count neighboring terrain types
		var neighbor_counts: Dictionary = {}
		var neighbors := HexUtils.get_neighbors(coords)
		
		for neighbor_coords in neighbors:
			var neighbor: HexCell = hex_grid.get_cell(neighbor_coords)
			if neighbor:
				var n_terrain := neighbor.terrain_type
				neighbor_counts[n_terrain] = neighbor_counts.get(n_terrain, 0) + 1
		
		# Find the most common neighbor terrain
		var max_count := 0
		var dominant_terrain := cell.terrain_type
		
		for terrain_name in neighbor_counts:
			if neighbor_counts[terrain_name] > max_count:
				max_count = neighbor_counts[terrain_name]
				dominant_terrain = terrain_name
		
		# If this cell is "isolated" (surrounded by different terrain), change it
		if max_count >= threshold and dominant_terrain != cell.terrain_type:
			# Only change to similar elevation-appropriate terrain
			if _is_terrain_transition_valid(cell, dominant_terrain):
				changes[coords] = dominant_terrain
	
	# Apply changes
	for coords in changes:
		var cell: HexCell = hex_grid.cells[coords]
		cell.terrain_type = changes[coords]
		
		if verbose_signals:
			terrain_assigned.emit(coords, changes[coords])


func _is_terrain_transition_valid(cell: HexCell, new_terrain: String) -> bool:
	# Check if the new terrain is reasonable for this cell's elevation/moisture
	if not terrain_types.has(new_terrain):
		return false
	
	var terrain_data: Dictionary = terrain_types[new_terrain]
	var elev_min: float = terrain_data.get("elevation_min", 0.0)
	var elev_max: float = terrain_data.get("elevation_max", 1.0)
	
	# Allow some flexibility (±0.1) for smoothing
	var tolerance := 0.1
	if cell.elevation >= elev_min - tolerance and cell.elevation <= elev_max + tolerance:
		return true
	
	return false


func _apply_color_variation(cell: HexCell) -> void:
	if not color_variation.get("enabled", true):
		return
	
	if not terrain_types.has(cell.terrain_type):
		return
	
	var terrain_data: Dictionary = terrain_types[cell.terrain_type]
	var base_color_str: String = terrain_data.get("color", "#ff00ff")
	var base_color := Color.from_string(base_color_str, Color.MAGENTA)
	
	# Get variation ranges
	var brightness_range: float = color_variation.get("brightness_range", 0.12)
	var saturation_range: float = color_variation.get("saturation_range", 0.08)
	var hue_range: float = color_variation.get("hue_range", 0.02)
	
	# Calculate variation factors based on elevation and moisture
	# Elevation affects brightness (higher = slightly brighter for non-water)
	# Moisture affects saturation (wetter = more saturated)
	
	var terrain_elev_min: float = terrain_data.get("elevation_min", 0.0)
	var terrain_elev_max: float = terrain_data.get("elevation_max", 1.0)
	var terrain_moist_min: float = terrain_data.get("moisture_min", 0.0)
	var terrain_moist_max: float = terrain_data.get("moisture_max", 1.0)
	
	# Normalize elevation/moisture within this terrain's range
	var elev_range := terrain_elev_max - terrain_elev_min
	var moist_range := terrain_moist_max - terrain_moist_min
	
	var normalized_elev := 0.5
	var normalized_moist := 0.5
	
	if elev_range > 0.001:
		normalized_elev = clampf((cell.elevation - terrain_elev_min) / elev_range, 0.0, 1.0)
	if moist_range > 0.001:
		normalized_moist = clampf((cell.moisture - terrain_moist_min) / moist_range, 0.0, 1.0)
	
	# Convert to HSV for easier manipulation
	var h := base_color.h
	var s := base_color.s
	var v := base_color.v
	
	# Apply brightness variation based on elevation
	# Higher elevation = slightly brighter (except for water)
	var brightness_offset := (normalized_elev - 0.5) * brightness_range
	if cell.terrain_type in ["water", "deep_water"]:
		# For water, higher elevation (shallower) = lighter
		brightness_offset = (normalized_elev - 0.5) * brightness_range * 1.5
	
	# Apply saturation variation based on moisture
	# Higher moisture = more saturated
	var saturation_offset := (normalized_moist - 0.5) * saturation_range
	
	# Apply subtle hue shift based on combined factors
	# This creates micro-variation without changing the overall feel
	var hue_offset := ((normalized_elev + normalized_moist) * 0.5 - 0.5) * hue_range
	
	# Apply variations
	h = fposmod(h + hue_offset, 1.0)
	s = clampf(s + saturation_offset, 0.0, 1.0)
	v = clampf(v + brightness_offset, 0.0, 1.0)
	
	# Set the varied color on the cell
	cell.terrain_color = Color.from_hsv(h, s, v)

# =============================================================================
# SINGLE HEX GENERATION (for future use)
# =============================================================================

## Generates terrain data for a single hex without applying to a cell.
## @param coords: Vector2i - Axial coordinates.
## @return Dictionary - Contains elevation, moisture, terrain_type, color.
func generate_hex_data(coords: Vector2i) -> Dictionary:
	var sample_x := float(coords.x)
	var sample_y := float(coords.y)
	
	var raw_elevation := _elevation_noise.get_noise_2d(sample_x, sample_y)
	var raw_moisture := _moisture_noise.get_noise_2d(sample_x + 1000.0, sample_y + 1000.0)
	
	var elevation := (raw_elevation + 1.0) * 0.5
	var moisture := (raw_moisture + 1.0) * 0.5
	
	var terrain_type := _determine_terrain_type(elevation, moisture)
	
	return {
		"elevation": elevation,
		"moisture": moisture,
		"terrain_type": terrain_type
	}


func _determine_terrain_type(elevation: float, moisture: float) -> String:
	var best_terrain := "plains"
	var best_priority := -1
	
	for terrain_name in terrain_types:
		var terrain_data: Dictionary = terrain_types[terrain_name]
		
		var elev_min: float = terrain_data.get("elevation_min", 0.0)
		var elev_max: float = terrain_data.get("elevation_max", 1.0)
		var moist_min: float = terrain_data.get("moisture_min", 0.0)
		var moist_max: float = terrain_data.get("moisture_max", 1.0)
		var priority: int = terrain_data.get("priority", 0)
		
		if elevation >= elev_min and elevation < elev_max:
			if moisture >= moist_min and moisture < moist_max:
				if priority > best_priority:
					best_terrain = terrain_name
					best_priority = priority
	
	return best_terrain

# =============================================================================
# UTILITY
# =============================================================================

func _emit_to_event_bus(signal_name: String, args: Array) -> void:
	var event_bus:Node = Engine.get_main_loop().root.get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal(signal_name):
		match args.size():
			0: event_bus.emit_signal(signal_name)
			1: event_bus.emit_signal(signal_name, args[0])
			2: event_bus.emit_signal(signal_name, args[0], args[1])
			3: event_bus.emit_signal(signal_name, args[0], args[1], args[2])


## Gets terrain data for a specific terrain type.
## @param terrain_name: String - Name of the terrain type.
## @return Dictionary - Terrain configuration data.
func get_terrain_data(terrain_name: String) -> Dictionary:
	return terrain_types.get(terrain_name, {})


## Gets all terrain type names.
## @return Array[String] - List of terrain type names.
func get_terrain_names() -> Array[String]:
	var names: Array[String] = []
	for key in terrain_types.keys():
		names.append(key)
	return names
