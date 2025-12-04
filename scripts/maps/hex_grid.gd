# hex_grid.gd
# Manages the hex grid, including generation, storage, and lookup of hex cells.
# This is the main interface for interacting with the hex map.
extends Node2D
class_name HexGrid

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the grid has finished generating.
signal grid_generated(map_size: Vector2i)

## Emitted when a hex cell is clicked.
signal hex_clicked(coords: Vector2i)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Path to the map configuration JSON file.
@export var config_file: String = "default"

## Path to the terrain generation configuration JSON file.
@export var terrain_config_file: String = "terrain_config"

## Whether to use procedural terrain generation on startup.
@export var use_procedural_generation: bool = true

## Seed for procedural generation (0 = random).
@export var generation_seed: int = 0

## Override map dimensions (0 = use config file value).
@export var override_width: int = 0
@export var override_height: int = 0

## Override hex size (0 = use config file value).
@export var override_hex_size: float = 0.0

# =============================================================================
# RUNTIME STATE
# =============================================================================

## The loaded map configuration.
var config: Dictionary = {}

## Map dimensions in hexes.
var map_width: int = 30
var map_height: int = 30

## Hex size (distance from center to corner).
var hex_size: float = 64.0

## Storage for all hex cells, keyed by axial coordinates.
## Format: { Vector2i: HexCell }
var cells: Dictionary = {}

## Currently selected hex coordinates (null if none).
var selected_coords: Variant = null

## Currently hovered hex coordinates (null if none).
var hovered_coords: Variant = null

## Whether debug labels are visible.
var debug_labels_visible: bool = false

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _terrain_types: Dictionary = {}
var _cells_container: Node2D
var _terrain_generator: TerrainGenerator = null
var _river_generator: RiverGenerator = null
var _location_placer: LocationPlacer = null
var _map_serializer: MapSerializer = null
var _map_validator: MapValidator = null
var _locations_config: Dictionary = {}

## The seed used for the current map (for display/regeneration).
var current_generation_seed: int = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_cells_container = Node2D.new()
	_cells_container.name = "Cells"
	add_child(_cells_container)
	
	_load_config()
	_init_generators()
	generate_grid()
	
	# Apply procedural generation if enabled
	if use_procedural_generation:
		generate_complete_map(generation_seed)


func _init_generators() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	
	# Initialize terrain generator
	_terrain_generator = TerrainGenerator.new()
	if loader:
		_terrain_generator.load_config_with_loader(loader, terrain_config_file)
	else:
		_terrain_generator.load_config(terrain_config_file)
	
	# Load locations config
	if loader:
		_locations_config = loader.load_map_config("locations_config")
	
	# Initialize river generator
	_river_generator = RiverGenerator.new()
	_river_generator.load_config(_locations_config)
	
	# Initialize location placer
	_location_placer = LocationPlacer.new()
	_location_placer.load_config(_locations_config)
	_location_placer.set_river_generator(_river_generator)
	
	# Initialize map serializer
	_map_serializer = MapSerializer.new()
	
	# Initialize map validator
	_map_validator = MapValidator.new()
	_map_validator.load_config(_locations_config)


func _load_config() -> void:
	# Try to load from DataLoader autoload
	if Engine.has_singleton("DataLoader") or has_node("/root/DataLoader"):
		var loader = get_node_or_null("/root/DataLoader")
		if loader:
			config = loader.load_map_config(config_file)
			if config.is_empty():
				config = loader.get_default_map_config()
		else:
			config = _get_fallback_config()
	else:
		config = _get_fallback_config()
	
	# Apply configuration
	if override_width > 0:
		map_width = override_width
	elif config.has("map_size"):
		map_width = config["map_size"].get("width", 30)
	
	if override_height > 0:
		map_height = override_height
	elif config.has("map_size"):
		map_height = config["map_size"].get("height", 30)
	
	if override_hex_size > 0:
		hex_size = override_hex_size
	elif config.has("hex_size"):
		hex_size = float(config["hex_size"])
	
	# Load terrain types
	if config.has("terrain_types"):
		_terrain_types = config["terrain_types"]
	elif config.has("terrain_colors"):
		# Convert simple color format to full terrain format
		for terrain_name in config["terrain_colors"]:
			_terrain_types[terrain_name] = {
				"color": config["terrain_colors"][terrain_name],
				"movement_cost": 1.0,
				"passable": true
			}


func _get_fallback_config() -> Dictionary:
	return {
		"map_name": "fallback",
		"map_size": {"width": 30, "height": 30},
		"hex_size": 64,
		"default_terrain": "grass",
		"terrain_types": {
			"grass": {"color": "#4a7c59", "movement_cost": 1.0, "passable": true},
			"water": {"color": "#4a7c9d", "movement_cost": 2.0, "passable": true},
			"mountain": {"color": "#6b5b4f", "movement_cost": 3.0, "passable": true},
			"desert": {"color": "#d4a76a", "movement_cost": 1.5, "passable": true},
			"forest": {"color": "#2d5a3d", "movement_cost": 1.5, "passable": true}
		}
	}

# =============================================================================
# GRID GENERATION
# =============================================================================

## Generates the hex grid based on current configuration.
## Clears any existing grid first.
func generate_grid() -> void:
	clear_grid()
	
	var default_terrain: String = config.get("default_terrain", "grass")
	
	# Generate hexes in offset coordinate order for consistent layout
	for col in range(map_width):
		for row in range(map_height):
			var offset_coords := Vector2i(col, row)
			var axial_coords := HexUtils.offset_to_axial(offset_coords)
			
			_create_hex_cell(axial_coords, default_terrain)
	
	# Emit signals
	grid_generated.emit(Vector2i(map_width, map_height))
	
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").map_generated.emit(Vector2i(map_width, map_height))
	
	print("HexGrid: Generated %d x %d grid (%d cells)" % [map_width, map_height, cells.size()])


func _create_hex_cell(axial_coords: Vector2i, terrain: String) -> HexCell:
	var cell := HexCell.new()
	cell.name = "Hex_%d_%d" % [axial_coords.x, axial_coords.y]
	
	# Position the cell
	cell.position = HexUtils.axial_to_pixel(axial_coords, hex_size)
	
	# Initialize cell properties
	cell.initialize(axial_coords, hex_size, terrain, _terrain_types)
	
	# Connect signals
	cell.clicked.connect(_on_cell_clicked)
	cell.mouse_entered_cell.connect(_on_cell_mouse_entered)
	cell.mouse_exited_cell.connect(_on_cell_mouse_exited)
	
	# Add to scene and storage
	_cells_container.add_child(cell)
	cells[axial_coords] = cell
	
	# Apply debug visibility
	cell.set_debug_visible(debug_labels_visible)
	
	return cell


## Clears all hex cells from the grid.
func clear_grid() -> void:
	for cell in cells.values():
		cell.queue_free()
	cells.clear()
	selected_coords = null
	hovered_coords = null

# =============================================================================
# CELL ACCESS
# =============================================================================

## Gets the hex cell at the given axial coordinates.
## @param coords: Vector2i - Axial coordinates.
## @return HexCell - The cell at those coordinates, or null if none exists.
func get_cell(coords: Vector2i) -> HexCell:
	return cells.get(coords, null)


## Gets the hex cell at the given offset coordinates.
## @param offset: Vector2i - Offset coordinates (col, row).
## @return HexCell - The cell at those coordinates, or null if none exists.
func get_cell_by_offset(offset: Vector2i) -> HexCell:
	var axial := HexUtils.offset_to_axial(offset)
	return get_cell(axial)


## Gets the hex cell at a pixel position.
## @param pixel_pos: Vector2 - Position in local coordinates.
## @return HexCell - The cell at that position, or null if none exists.
func get_cell_at_pixel(pixel_pos: Vector2) -> HexCell:
	var axial := HexUtils.pixel_to_axial(pixel_pos, hex_size)
	return get_cell(axial)


## Checks if coordinates are valid (within map bounds).
## @param coords: Vector2i - Axial coordinates to check.
## @return bool - True if coordinates are within the map.
func is_valid_coord(coords: Vector2i) -> bool:
	return cells.has(coords)


## Gets all cells of a specific terrain type.
## @param terrain: String - Terrain type to find.
## @return Array[HexCell] - All cells with that terrain.
func get_cells_by_terrain(terrain: String) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for cell in cells.values():
		if cell.terrain_type == terrain:
			result.append(cell)
	return result


## Gets all neighbors of a hex that exist on the map.
## @param coords: Vector2i - Center hex coordinates.
## @return Array[HexCell] - Neighboring cells (up to 6).
func get_neighbors(coords: Vector2i) -> Array[HexCell]:
	var result: Array[HexCell] = []
	var neighbor_coords := HexUtils.get_neighbors(coords)
	for nc in neighbor_coords:
		var cell := get_cell(nc)
		if cell:
			result.append(cell)
	return result

# =============================================================================
# SELECTION
# =============================================================================

## Selects a hex by its coordinates.
## @param coords: Vector2i - Axial coordinates to select.
func select_hex(coords: Vector2i) -> void:
	# Deselect previous
	if selected_coords != null:
		var prev_cell := get_cell(selected_coords)
		if prev_cell:
			prev_cell.is_selected = false
	
	# Select new
	var cell := get_cell(coords)
	if cell:
		cell.is_selected = true
		selected_coords = coords
		
		# Emit signals
		hex_clicked.emit(coords)
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").hex_selected.emit(coords)
	else:
		selected_coords = null


## Clears the current selection.
func deselect() -> void:
	if selected_coords != null:
		var cell := get_cell(selected_coords)
		if cell:
			cell.is_selected = false
		selected_coords = null
		
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").hex_deselected.emit()


## Gets the currently selected cell.
## @return HexCell - The selected cell, or null if none.
func get_selected_cell() -> HexCell:
	if selected_coords != null:
		return get_cell(selected_coords)
	return null

# =============================================================================
# TERRAIN MODIFICATION
# =============================================================================

## Sets the terrain type of a hex.
## @param coords: Vector2i - Axial coordinates.
## @param terrain: String - New terrain type.
func set_terrain(coords: Vector2i, terrain: String) -> void:
	var cell := get_cell(coords)
	if cell:
		cell.terrain_type = terrain
		
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").terrain_changed.emit(coords, terrain)


## Fills a rectangular region with a terrain type.
## @param start_offset: Vector2i - Starting offset coordinates.
## @param end_offset: Vector2i - Ending offset coordinates.
## @param terrain: String - Terrain type to fill with.
func fill_terrain_rect(start_offset: Vector2i, end_offset: Vector2i, terrain: String) -> void:
	var min_col := mini(start_offset.x, end_offset.x)
	var max_col := maxi(start_offset.x, end_offset.x)
	var min_row := mini(start_offset.y, end_offset.y)
	var max_row := maxi(start_offset.y, end_offset.y)
	
	for col in range(min_col, max_col + 1):
		for row in range(min_row, max_row + 1):
			var axial := HexUtils.offset_to_axial(Vector2i(col, row))
			set_terrain(axial, terrain)

# =============================================================================
# DEBUG VISUALIZATION
# =============================================================================

## Toggles visibility of coordinate debug labels on all cells.
## @param visible: bool - Whether labels should be visible.
func set_debug_labels_visible(visible: bool) -> void:
	debug_labels_visible = visible
	for cell in cells.values():
		cell.set_debug_visible(visible)


## Gets the pixel bounds of the entire map.
## @return Rect2 - Bounding rectangle of the map.
func get_map_bounds() -> Rect2:
	return HexUtils.get_map_pixel_bounds(map_width, map_height, hex_size)

# =============================================================================
# COMPLETE MAP GENERATION
# =============================================================================

## Generates a complete map with terrain, rivers, and locations.
## Will retry up to max_attempts times if validation fails.
## @param seed_value: int - Seed for generation (0 = random).
## @param max_attempts: int - Maximum retry attempts.
## @return bool - True if generation succeeded.
func generate_complete_map(seed_value: int = 0, max_attempts: int = 3) -> bool:
	var attempt := 0
	var current_seed := seed_value
	
	while attempt < max_attempts:
		attempt += 1
		
		if attempt > 1:
			print("HexGrid: Retrying generation (attempt %d/%d)" % [attempt, max_attempts])
			# Modify seed for retry
			if current_seed != 0:
				current_seed = seed_value + attempt * 10000
			else:
				current_seed = 0  # Will generate new random
		
		# Generate terrain
		generate_procedural_terrain(current_seed)
		
		# Generate rivers
		generate_rivers()
		
		# Place locations
		place_locations()
		
		# Validate the map
		var result := validate_map()
		
		if result.valid:
			print("HexGrid: Complete map generation successful (seed: %d)" % current_generation_seed)
			return true
		else:
			print("HexGrid: Map validation failed with %d errors" % result.errors.size())
			for error in result.errors:
				print("  - %s" % error)
	
	print("HexGrid: Map generation failed after %d attempts" % max_attempts)
	return false

# =============================================================================
# PROCEDURAL TERRAIN GENERATION
# =============================================================================

## Generates procedural terrain for the entire map.
## @param seed_value: int - Seed for generation (0 = random).
func generate_procedural_terrain(seed_value: int = 0) -> void:
	if _terrain_generator == null:
		_init_generators()
	
	# Reset all cell data before regenerating
	for cell in cells.values():
		cell.reset_terrain_color()
		cell.has_river = false
		cell.river_flow_direction = Vector2i.ZERO
		cell.location = null
	
	_terrain_generator.generate_terrain(self, seed_value)
	current_generation_seed = _terrain_generator.get_seed()
	
	print("HexGrid: Generated procedural terrain with seed %d" % current_generation_seed)


## Regenerates the map with a new random seed.
func regenerate_with_new_seed() -> void:
	generate_complete_map(0)


## Regenerates the map with the same seed (reproduces identical terrain).
func regenerate_with_same_seed() -> void:
	generate_complete_map(current_generation_seed)


## Sets the terrain generator's verbose mode for debugging.
## @param verbose: bool - Whether to emit per-hex signals.
func set_generation_verbose(verbose: bool) -> void:
	if _terrain_generator:
		_terrain_generator.verbose_signals = verbose


## Gets the terrain generator instance (for advanced usage).
## @return TerrainGenerator - The terrain generator.
func get_terrain_generator() -> TerrainGenerator:
	if _terrain_generator == null:
		_init_generators()
	return _terrain_generator

# =============================================================================
# RIVER GENERATION
# =============================================================================

## Generates rivers on the map.
## @return int - Number of rivers generated.
func generate_rivers() -> int:
	if _river_generator == null:
		_init_generators()
	
	return _river_generator.generate_rivers(self, current_generation_seed)


## Gets the river generator instance.
func get_river_generator() -> RiverGenerator:
	return _river_generator


## Gets all river data.
func get_rivers() -> Array[Dictionary]:
	if _river_generator:
		return _river_generator.get_all_rivers()
	return []

# =============================================================================
# LOCATION PLACEMENT
# =============================================================================

## Places all locations on the map.
## @return bool - True if placement was successful.
func place_locations() -> bool:
	if _location_placer == null:
		_init_generators()
	
	return _location_placer.place_all_locations(self, current_generation_seed)


## Gets the location placer instance.
func get_location_placer() -> LocationPlacer:
	return _location_placer


## Gets all locations.
func get_all_locations() -> Dictionary:
	if _location_placer:
		return _location_placer.get_all_locations()
	return {}


## Gets locations of a specific type.
func get_locations_by_type(location_type: String) -> Array:
	if _location_placer:
		return _location_placer.get_locations_by_type(location_type)
	return []

# =============================================================================
# MAP VALIDATION
# =============================================================================

## Validates the current map state.
## @return MapValidator.ValidationResult - Validation results.
func validate_map() -> MapValidator.ValidationResult:
	if _map_validator == null:
		_init_generators()
	
	return _map_validator.validate_map(self, _river_generator, _location_placer)


## Generates a validation report string.
func get_validation_report() -> String:
	var result := validate_map()
	return _map_validator.generate_report(result)

# =============================================================================
# SAVE/LOAD
# =============================================================================

## Saves the current map to a file.
## @param filename: String - Optional filename (without .json extension).
## @return String - Path to saved file, or empty string on failure.
func save_map(filename: String = "") -> String:
	if _map_serializer == null:
		_init_generators()
	
	return _map_serializer.save_map(
		self,
		_river_generator,
		_location_placer,
		current_generation_seed,
		filename
	)


## Loads a map from a file.
## @param file_path: String - Path to the save file.
## @return int - The loaded map's seed, or -1 on failure.
func load_map(file_path: String) -> int:
	if _map_serializer == null:
		_init_generators()
	
	var loaded_seed := _map_serializer.load_map(
		file_path,
		self,
		_river_generator,
		_location_placer
	)
	
	if loaded_seed >= 0:
		current_generation_seed = loaded_seed
	
	return loaded_seed


## Gets a list of available save files.
func get_save_list() -> Array[Dictionary]:
	if _map_serializer == null:
		_init_generators()
	
	return _map_serializer.get_save_list()


## Deletes a save file.
func delete_save(filename: String) -> bool:
	if _map_serializer == null:
		return false
	
	return _map_serializer.delete_save(filename)

# =============================================================================
# STATISTICS
# =============================================================================


## Gets statistics about the current map's terrain distribution.
## @return Dictionary - Terrain type counts.
func get_terrain_statistics() -> Dictionary:
	var stats: Dictionary = {}
	for cell in cells.values():
		var terrain:String = cell.terrain_type
		stats[terrain] = stats.get(terrain, 0) + 1
	return stats


## Gets the average elevation of the map.
## @return float - Average elevation (0.0 to 1.0).
func get_average_elevation() -> float:
	if cells.is_empty():
		return 0.0
	
	var total := 0.0
	for cell in cells.values():
		total += cell.elevation
	return total / cells.size()


## Gets the average moisture of the map.
## @return float - Average moisture (0.0 to 1.0).
func get_average_moisture() -> float:
	if cells.is_empty():
		return 0.0
	
	var total := 0.0
	for cell in cells.values():
		total += cell.moisture
	return total / cells.size()


## Finds cells within an elevation range.
## @param min_elev: float - Minimum elevation.
## @param max_elev: float - Maximum elevation.
## @return Array[HexCell] - Cells within the range.
func get_cells_by_elevation(min_elev: float, max_elev: float) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for cell in cells.values():
		if cell.elevation >= min_elev and cell.elevation <= max_elev:
			result.append(cell)
	return result


## Finds cells within a moisture range.
## @param min_moist: float - Minimum moisture.
## @param max_moist: float - Maximum moisture.
## @return Array[HexCell] - Cells within the range.
func get_cells_by_moisture(min_moist: float, max_moist: float) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for cell in cells.values():
		if cell.moisture >= min_moist and cell.moisture <= max_moist:
			result.append(cell)
	return result

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_cell_clicked(cell: HexCell) -> void:
	select_hex(cell.axial_coords)


func _on_cell_mouse_entered(cell: HexCell) -> void:
	# Update hover state
	if hovered_coords != null and hovered_coords != cell.axial_coords:
		var prev_cell := get_cell(hovered_coords)
		if prev_cell:
			prev_cell.is_hovered = false
	
	cell.is_hovered = true
	hovered_coords = cell.axial_coords
	
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").hex_hovered.emit(cell.axial_coords)


func _on_cell_mouse_exited(cell: HexCell) -> void:
	cell.is_hovered = false
	if hovered_coords == cell.axial_coords:
		hovered_coords = null
		
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").hex_hover_exited.emit()
