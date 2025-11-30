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

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_cells_container = Node2D.new()
	_cells_container.name = "Cells"
	add_child(_cells_container)
	
	_load_config()
	generate_grid()


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
