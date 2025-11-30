# hex_cell.gd
# Represents a single hex cell in the grid.
# Handles its own rendering (polygon or sprite) and visual state.
extends Node2D
class_name HexCell

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when this cell is clicked.
signal clicked(hex_cell: HexCell)

## Emitted when mouse enters this cell.
signal mouse_entered_cell(hex_cell: HexCell)

## Emitted when mouse exits this cell.
signal mouse_exited_cell(hex_cell: HexCell)

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

## The axial coordinates of this hex.
@export var axial_coords: Vector2i = Vector2i.ZERO:
	set(value):
		axial_coords = value
		_update_debug_label()

## The terrain type of this hex.
@export var terrain_type: String = "grass":
	set(value):
		terrain_type = value
		_update_visuals()

## Size of the hex (distance from center to corner).
@export var hex_size: float = 64.0:
	set(value):
		hex_size = value
		_rebuild_polygon()

# =============================================================================
# VISUAL STATE
# =============================================================================

## Whether this hex is currently selected.
var is_selected: bool = false:
	set(value):
		is_selected = value
		_update_highlight()

## Whether this hex is currently hovered.
var is_hovered: bool = false:
	set(value):
		is_hovered = value
		_update_highlight()

## Custom data that can be attached to this hex (for encounters, items, etc).
var custom_data: Dictionary = {}

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _polygon: Polygon2D
var _outline: Line2D
var _highlight: Polygon2D
var _sprite: Sprite2D
var _collision_polygon: CollisionPolygon2D
var _area: Area2D
var _debug_label: Label

# Color definitions loaded from config
var _terrain_colors: Dictionary = {}

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_nodes()
	_rebuild_polygon()
	_update_visuals()


## Initializes the hex cell with coordinates and configuration.
## @param coords: Vector2i - Axial coordinates.
## @param size: float - Hex size.
## @param terrain: String - Terrain type.
## @param colors: Dictionary - Terrain color definitions.
func initialize(coords: Vector2i, size: float, terrain: String, colors: Dictionary) -> void:
	axial_coords = coords
	hex_size = size
	_terrain_colors = colors
	terrain_type = terrain  # Set last to trigger visual update


func _create_nodes() -> void:
	# Create the main polygon for terrain display
	_polygon = Polygon2D.new()
	_polygon.name = "TerrainPolygon"
	add_child(_polygon)
	
	# Create highlight polygon (rendered above terrain)
	_highlight = Polygon2D.new()
	_highlight.name = "Highlight"
	_highlight.visible = false
	add_child(_highlight)
	
	# Create outline
	_outline = Line2D.new()
	_outline.name = "Outline"
	_outline.width = 1.5
	_outline.default_color = Color(0.2, 0.2, 0.2, 0.5)
	_outline.closed = true
	add_child(_outline)
	
	# Create sprite for texture-based rendering (optional)
	_sprite = Sprite2D.new()
	_sprite.name = "TerrainSprite"
	_sprite.visible = false  # Hidden by default, use polygon
	add_child(_sprite)
	
	# Create collision detection
	_area = Area2D.new()
	_area.name = "ClickArea"
	_collision_polygon = CollisionPolygon2D.new()
	_collision_polygon.name = "CollisionShape"
	_area.add_child(_collision_polygon)
	add_child(_area)
	
	# Connect area signals
	_area.input_event.connect(_on_area_input_event)
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)
	
	# Create debug label
	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_debug_label.visible = false
	_debug_label.add_theme_font_size_override("font_size", 10)
	_debug_label.add_theme_color_override("font_color", Color.BLACK)
	add_child(_debug_label)


func _rebuild_polygon() -> void:
	if not is_inside_tree():
		return
	
	# Get hex corner points
	var corners := HexUtils.get_hex_corners(Vector2.ZERO, hex_size)
	
	# Update polygon shape
	_polygon.polygon = corners
	_highlight.polygon = corners
	_collision_polygon.polygon = corners
	
	# Update outline (Line2D needs the points including closing segment)
	var outline_points := PackedVector2Array(corners)
	outline_points.append(corners[0])  # Close the loop
	_outline.points = outline_points
	
	# Position debug label at center
	_debug_label.position = Vector2(-20, -8)  # Offset to center text roughly


func _update_visuals() -> void:
	if not is_inside_tree() or _polygon == null:
		return
	
	# Get color from terrain type
	var color := _get_terrain_color()
	_polygon.color = color
	
	# Try to load terrain sprite
	_load_terrain_sprite()


func _get_terrain_color() -> Color:
	# Check loaded terrain colors first
	if _terrain_colors.has(terrain_type):
		var terrain_data = _terrain_colors[terrain_type]
		if terrain_data is Dictionary and terrain_data.has("color"):
			return Color.from_string(terrain_data["color"], Color.MAGENTA)
		elif terrain_data is String:
			return Color.from_string(terrain_data, Color.MAGENTA)
	
	# Fallback defaults
	match terrain_type:
		"grass": return Color("#4a7c59")
		"water": return Color("#4a7c9d")
		"deep_water": return Color("#2a5c7d")
		"mountain": return Color("#6b5b4f")
		"mountain_peak": return Color("#8b7b6f")
		"desert": return Color("#d4a76a")
		"forest": return Color("#2d5a3d")
		"snow": return Color("#e8e8e8")
		_: return Color.MAGENTA  # Error color


func _load_terrain_sprite() -> void:
	# Attempt to load sprite texture from assets
	var sprite_path := "res://assets/images/maps/%s.png" % terrain_type
	
	if ResourceLoader.exists(sprite_path):
		var texture := load(sprite_path) as Texture2D
		if texture:
			_sprite.texture = texture
			_sprite.visible = true
			_polygon.visible = false
			return
	
	# Fallback to polygon rendering
	_sprite.visible = false
	_polygon.visible = true


func _update_highlight() -> void:
	if _highlight == null:
		return
	
	if is_selected:
		_highlight.color = Color(1.0, 1.0, 0.0, 0.4)  # Yellow selection
		_highlight.visible = true
		_outline.default_color = Color(1.0, 1.0, 0.0, 0.8)
		_outline.width = 3.0
	elif is_hovered:
		_highlight.color = Color(1.0, 1.0, 1.0, 0.2)  # White hover
		_highlight.visible = true
		_outline.default_color = Color(1.0, 1.0, 1.0, 0.6)
		_outline.width = 2.0
	else:
		_highlight.visible = false
		_outline.default_color = Color(0.2, 0.2, 0.2, 0.5)
		_outline.width = 1.5


func _update_debug_label() -> void:
	if _debug_label == null:
		return
	_debug_label.text = "%d,%d" % [axial_coords.x, axial_coords.y]

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit(self)


func _on_mouse_entered() -> void:
	mouse_entered_cell.emit(self)


func _on_mouse_exited() -> void:
	mouse_exited_cell.emit(self)

# =============================================================================
# PUBLIC API
# =============================================================================

## Shows or hides the coordinate debug label.
func set_debug_visible(visible: bool) -> void:
	if _debug_label:
		_debug_label.visible = visible


## Sets a custom texture for this hex.
func set_custom_texture(texture: Texture2D) -> void:
	if texture:
		_sprite.texture = texture
		_sprite.visible = true
		_polygon.visible = false
	else:
		_sprite.visible = false
		_polygon.visible = true


## Gets the pixel position of this hex's center.
func get_center_position() -> Vector2:
	return global_position


## Gets the offset coordinates for this hex.
func get_offset_coords() -> Vector2i:
	return HexUtils.axial_to_offset(axial_coords)
