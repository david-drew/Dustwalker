# tactical_hex_cell.gd
# A hex cell for tactical combat maps.
# Simplified version of HexCell focused on combat-specific features.

extends Node2D
class_name TacticalHexCell

# =============================================================================
# SIGNALS
# =============================================================================

signal cell_clicked(coords: Vector2i)
signal cell_hovered(coords: Vector2i)
signal cell_unhovered(coords: Vector2i)

# =============================================================================
# ENUMS
# =============================================================================

enum CoverType { NONE, LIGHT, HEAVY }
enum TerrainCost { OPEN = 1, ROUGH = 2, IMPASSABLE = -1 }
enum HighlightType { NONE, MOVEMENT, ATTACK, SELECTED, ENEMY_RANGE }

# =============================================================================
# PROPERTIES
# =============================================================================

## Axial coordinates of this cell.
var coords: Vector2i = Vector2i.ZERO

## Hex size (center to corner).
var hex_size: float = 64.0

## Cover type at this cell.
var cover_type: CoverType = CoverType.NONE

## Movement cost to enter this cell.
var terrain_cost: TerrainCost = TerrainCost.OPEN

## Whether this cell is passable.
var is_passable: bool = true

## Combatant occupying this cell (null if empty).
var occupant: Combatant = null

## Current highlight state.
var highlight_type: HighlightType = HighlightType.NONE

# =============================================================================
# VISUAL NODES
# =============================================================================

var _polygon: Polygon2D
var _outline: Line2D
var _cover_indicator: Polygon2D
var _highlight_overlay: Polygon2D
var _collision_area: Area2D

# =============================================================================
# COLORS
# =============================================================================

var _base_color: Color = Color(0.25, 0.22, 0.18)
var _outline_color: Color = Color(0.4, 0.35, 0.3)
var _cover_colors: Dictionary = {
	CoverType.NONE: Color(0, 0, 0, 0),
	CoverType.LIGHT: Color(0.4, 0.5, 0.3, 0.4),
	CoverType.HEAVY: Color(0.3, 0.35, 0.25, 0.6)
}
var _highlight_colors: Dictionary = {
	HighlightType.NONE: Color(0, 0, 0, 0),
	HighlightType.MOVEMENT: Color(0.2, 0.5, 0.8, 0.4),
	HighlightType.ATTACK: Color(0.8, 0.3, 0.2, 0.4),
	HighlightType.SELECTED: Color(0.9, 0.8, 0.2, 0.5),
	HighlightType.ENEMY_RANGE: Color(0.8, 0.2, 0.2, 0.25)
}

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_nodes()


## Initialize the cell with coordinates and hex size.
func initialize(cell_coords: Vector2i, size: float, terrain: String = "open") -> void:
	coords = cell_coords
	hex_size = size
	
	# Set position
	position = _axial_to_pixel(coords)
	
	# Set terrain
	match terrain:
		"open":
			terrain_cost = TerrainCost.OPEN
			is_passable = true
			_base_color = Color(0.25, 0.22, 0.18)
		"rough":
			terrain_cost = TerrainCost.ROUGH
			is_passable = true
			_base_color = Color(0.3, 0.25, 0.2)
		"impassable":
			terrain_cost = TerrainCost.IMPASSABLE
			is_passable = false
			_base_color = Color(0.15, 0.12, 0.1)
	
	_create_nodes()


func _create_nodes() -> void:
	# Clear existing nodes
	for child in get_children():
		child.queue_free()
	
	var corners := _get_hex_corners()
	
	# Base polygon
	_polygon = Polygon2D.new()
	_polygon.name = "Polygon"
	_polygon.polygon = corners
	_polygon.color = _base_color
	add_child(_polygon)
	
	# Outline
	_outline = Line2D.new()
	_outline.name = "Outline"
	_outline.points = corners
	_outline.points.append(corners[0])  # Close the loop
	_outline.width = 2.0
	_outline.default_color = _outline_color
	add_child(_outline)
	
	# Cover indicator (drawn on top of base)
	_cover_indicator = Polygon2D.new()
	_cover_indicator.name = "CoverIndicator"
	_cover_indicator.polygon = _get_cover_shape()
	_cover_indicator.color = _cover_colors[cover_type]
	_cover_indicator.z_index = 1
	add_child(_cover_indicator)
	
	# Highlight overlay
	_highlight_overlay = Polygon2D.new()
	_highlight_overlay.name = "Highlight"
	_highlight_overlay.polygon = corners
	_highlight_overlay.color = Color(0, 0, 0, 0)
	_highlight_overlay.z_index = 2
	add_child(_highlight_overlay)
	
	# Collision area for input
	_collision_area = Area2D.new()
	_collision_area.name = "CollisionArea"
	_collision_area.input_pickable = true
	add_child(_collision_area)
	
	var collision_shape := CollisionPolygon2D.new()
	collision_shape.polygon = corners
	_collision_area.add_child(collision_shape)
	
	# Connect signals
	_collision_area.input_event.connect(_on_input_event)
	_collision_area.mouse_entered.connect(_on_mouse_entered)
	_collision_area.mouse_exited.connect(_on_mouse_exited)


func _get_hex_corners() -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i in range(6):
		var angle := PI / 6.0 + float(i) * PI / 3.0
		corners.append(Vector2(cos(angle), sin(angle)) * hex_size)
	return corners


func _get_cover_shape() -> PackedVector2Array:
	# Smaller hexagon for cover indicator
	var corners := PackedVector2Array()
	var cover_size := hex_size * 0.6
	for i in range(6):
		var angle := PI / 6.0 + float(i) * PI / 3.0
		corners.append(Vector2(cos(angle), sin(angle)) * cover_size)
	return corners


func _axial_to_pixel(axial: Vector2i) -> Vector2:
	var x := hex_size * (sqrt(3.0) * axial.x + sqrt(3.0) / 2.0 * axial.y)
	var y := hex_size * (3.0 / 2.0 * axial.y)
	return Vector2(x, y)

# =============================================================================
# COVER
# =============================================================================

## Set the cover type for this cell.
func set_cover(new_cover: CoverType) -> void:
	cover_type = new_cover
	if _cover_indicator:
		_cover_indicator.color = _cover_colors[cover_type]
		
		# Also add visual cover object indicator
		if cover_type != CoverType.NONE:
			_cover_indicator.visible = true
		else:
			_cover_indicator.visible = false


## Get cover defense modifier (0.0 for none, -0.2 for light, -0.4 for heavy).
func get_cover_modifier() -> float:
	match cover_type:
		CoverType.NONE:
			return 0.0
		CoverType.LIGHT:
			return -0.20
		CoverType.HEAVY:
			return -0.40
	return 0.0

# =============================================================================
# OCCUPANCY
# =============================================================================

## Set the occupant of this cell.
func set_occupant(combatant: Combatant) -> void:
	occupant = combatant


## Clear the occupant.
func clear_occupant() -> void:
	occupant = null


## Check if cell is occupied.
func is_occupied() -> bool:
	return occupant != null

# =============================================================================
# HIGHLIGHTING
# =============================================================================

## Set highlight type.
func set_highlight(highlight: HighlightType) -> void:
	highlight_type = highlight
	if _highlight_overlay:
		_highlight_overlay.color = _highlight_colors[highlight]


## Clear highlight.
func clear_highlight() -> void:
	set_highlight(HighlightType.NONE)

# =============================================================================
# QUERIES
# =============================================================================

## Get movement AP cost to enter this cell.
func get_movement_cost() -> int:
	match terrain_cost:
		TerrainCost.OPEN:
			return 1
		TerrainCost.ROUGH:
			return 2
		TerrainCost.IMPASSABLE:
			return -1
	return 1


## Check if a combatant can enter this cell.
func can_enter() -> bool:
	return is_passable and not is_occupied()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			cell_clicked.emit(coords)


func _on_mouse_entered() -> void:
	cell_hovered.emit(coords)
	
	# Subtle hover effect
	if _outline:
		_outline.default_color = Color(0.6, 0.55, 0.5)


func _on_mouse_exited() -> void:
	cell_unhovered.emit(coords)
	
	if _outline:
		_outline.default_color = _outline_color

# =============================================================================
# VISUALS
# =============================================================================

## Update base terrain color.
func set_terrain_color(color: Color) -> void:
	_base_color = color
	if _polygon:
		_polygon.color = color
