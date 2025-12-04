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
# TERRAIN DATA (set by TerrainGenerator)
# =============================================================================

## Elevation value from procedural generation (0.0 = sea level, 1.0 = peak).
var elevation: float = 0.0

## Moisture value from procedural generation (0.0 = arid, 1.0 = wet).
var moisture: float = 0.0

## Custom terrain color with variation applied (overrides base terrain color).
## If null/default, uses the base terrain type color.
var terrain_color: Color = Color(-1, -1, -1, -1):  # Invalid color as "unset" marker
	set(value):
		terrain_color = value
		_update_visuals()

# =============================================================================
# RIVER DATA (set by RiverGenerator)
# =============================================================================

## Whether this hex contains a river.
var has_river: bool = false:
	set(value):
		has_river = value
		if is_inside_tree():
			update_river_visuals()

## Direction to the next hex in the river flow (for rendering).
var river_flow_direction: Vector2i = Vector2i.ZERO

# =============================================================================
# LOCATION DATA (set by LocationPlacer)
# =============================================================================

## Location data if this hex has a location (town, fort, etc.), or null.
var location: Variant = null:  # Dictionary or null
	set(value):
		location = value
		if is_inside_tree():
			update_location_visuals()

# =============================================================================
# VISUAL STATE
# =============================================================================

## Exploration states for fog of war.
enum ExplorationState { UNEXPLORED, EXPLORED, VISIBLE }

## Current exploration state of this hex.
var exploration_state: ExplorationState = ExplorationState.UNEXPLORED

## Day when this hex was first discovered (-1 = never).
var first_discovered_day: int = -1

## Turn when this hex was first discovered (-1 = never).
var first_discovered_turn: int = -1

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

## Whether this hex is part of a movement path preview.
var is_path_preview: bool = false:
	set(value):
		is_path_preview = value
		_update_highlight()

## Whether this hex is the destination in a path preview.
var is_path_destination: bool = false:
	set(value):
		is_path_destination = value
		_update_highlight()

## Custom data that can be attached to this hex (for encounters, items, etc).
var custom_data: Dictionary = {}

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _polygon: Polygon2D
var _outline: Line2D
var _highlight: Polygon2D
var _path_highlight: Polygon2D
var _fog_overlay: Polygon2D
var _sprite: Sprite2D
var _collision_polygon: CollisionPolygon2D
var _area: Area2D
var _debug_label: Label

# River overlay nodes
var _river_overlay: Node2D
var _river_polygon: Polygon2D

# Location overlay nodes
var _location_container: Node2D
var _location_sprite: Sprite2D
var _location_marker: Polygon2D
var _location_label: Label

# Fog configuration
var _fog_colors: Dictionary = {
	"unexplored": Color(0, 0, 0, 0.95),
	"explored": Color(0, 0, 0, 0.38),
	"visible": Color(0, 0, 0, 0.0)
}
var _fog_transition_duration: float = 0.25
var _fog_tween: Tween = null

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
	
	# Create path preview highlight (rendered above terrain, below selection)
	_path_highlight = Polygon2D.new()
	_path_highlight.name = "PathHighlight"
	_path_highlight.visible = false
	_path_highlight.z_index = 1
	add_child(_path_highlight)
	
	# Create highlight polygon (rendered above terrain)
	_highlight = Polygon2D.new()
	_highlight.name = "Highlight"
	_highlight.visible = false
	_highlight.z_index = 2
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
	
	# Create river overlay (rendered above terrain, below highlight)
	_river_overlay = Node2D.new()
	_river_overlay.name = "RiverOverlay"
	_river_overlay.z_index = 1
	_river_overlay.visible = false
	add_child(_river_overlay)
	
	_river_polygon = Polygon2D.new()
	_river_polygon.name = "RiverPolygon"
	_river_polygon.color = Color(0.2, 0.5, 0.8, 0.7)  # Semi-transparent blue
	_river_overlay.add_child(_river_polygon)
	
	# Create location container (rendered above everything else)
	_location_container = Node2D.new()
	_location_container.name = "LocationContainer"
	_location_container.z_index = 5
	_location_container.visible = false
	add_child(_location_container)
	
	# Location sprite (for custom icons)
	_location_sprite = Sprite2D.new()
	_location_sprite.name = "LocationSprite"
	_location_sprite.visible = false
	_location_container.add_child(_location_sprite)
	
	# Location marker (fallback polygon marker)
	_location_marker = Polygon2D.new()
	_location_marker.name = "LocationMarker"
	_location_marker.visible = false
	_location_container.add_child(_location_marker)
	
	# Location label
	_location_label = Label.new()
	_location_label.name = "LocationLabel"
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.add_theme_font_size_override("font_size", 8)
	_location_label.add_theme_color_override("font_color", Color.WHITE)
	_location_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_location_label.add_theme_constant_override("outline_size", 2)
	_location_label.visible = false
	_location_container.add_child(_location_label)
	
	# Create fog overlay (rendered above everything except player)
	_fog_overlay = Polygon2D.new()
	_fog_overlay.name = "FogOverlay"
	_fog_overlay.z_index = 8  # Above locations (5), below player (10)
	_fog_overlay.color = _fog_colors["unexplored"]
	add_child(_fog_overlay)
	
	# Load fog config
	_load_fog_config()


func _load_fog_config() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_map_config("fog_config")
		var colors_config: Dictionary = config.get("fog_colors", {})
		for state in colors_config:
			var c: Dictionary = colors_config[state]
			_fog_colors[state] = Color(c.get("r", 0), c.get("g", 0), c.get("b", 0), c.get("a", 1))
		_fog_transition_duration = config.get("fog_transition_duration", 0.25)


func _rebuild_polygon() -> void:
	if not is_inside_tree():
		return
	
	# Get hex corner points
	var corners := HexUtils.get_hex_corners(Vector2.ZERO, hex_size)
	
	# Update polygon shape
	_polygon.polygon = corners
	_highlight.polygon = corners
	_path_highlight.polygon = corners
	_collision_polygon.polygon = corners
	
	# Update fog overlay polygon
	if _fog_overlay:
		_fog_overlay.polygon = corners
	
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
	# First check if a custom terrain_color has been set (by TerrainGenerator)
	# We use an invalid color as the "unset" marker
	if terrain_color.r >= 0.0:
		return terrain_color
	
	# Check loaded terrain colors from config
	if _terrain_colors.has(terrain_type):
		var terrain_data = _terrain_colors[terrain_type]
		if terrain_data is Dictionary and terrain_data.has("color"):
			return Color.from_string(terrain_data["color"], Color.MAGENTA)
		elif terrain_data is String:
			return Color.from_string(terrain_data, Color.MAGENTA)
	
	# Fallback defaults for all terrain types
	match terrain_type:
		"grass", "grassland": return Color("#6b9e4a")
		"plains": return Color("#7bae5a")
		"water": return Color("#2b6f8f")
		"deep_water": return Color("#1a4a6e")
		"mountains": return Color("#5b5b4f")
		"mountain_peak": return Color("#e8e8e8")
		"desert": return Color("#d4a76a")
		"forest": return Color("#2d5016")
		"forest_hills": return Color("#4a7c3f")
		"swamp": return Color("#4a6b3f")
		"badlands": return Color("#8b6f47")
		"hills": return Color("#7a8a5a")
		"highlands": return Color("#6a6a5a")
		"snow": return Color("#e8e8e8")
		_: return Color.MAGENTA  # Error color


func _load_terrain_sprite() -> void:
	# Attempt to load sprite texture from assets
	# Check both terrain/ subdirectory and root maps/ directory
	var sprite_paths := [
		"res://assets/images/maps/terrain/%s.png" % terrain_type,
		"res://assets/images/maps/%s.png" % terrain_type
	]
	
	for sprite_path in sprite_paths:
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
	
	# Handle path preview highlight
	if _path_highlight:
		if is_path_destination:
			_path_highlight.color = Color(1.0, 1.0, 0.0, 0.5)  # Yellow destination
			_path_highlight.visible = true
		elif is_path_preview:
			_path_highlight.color = Color(0.3, 0.6, 1.0, 0.4)  # Blue path
			_path_highlight.visible = true
		else:
			_path_highlight.visible = false
	
	# Handle selection/hover highlight (takes precedence visually)
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
	elif is_path_destination:
		_highlight.visible = false
		_outline.default_color = Color(1.0, 0.9, 0.2, 0.8)
		_outline.width = 2.5
	elif is_path_preview:
		_highlight.visible = false
		_outline.default_color = Color(0.4, 0.7, 1.0, 0.6)
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


## Resets terrain color to use the base terrain type color.
## Call this to clear any custom color variation.
func reset_terrain_color() -> void:
	terrain_color = Color(-1, -1, -1, -1)


## Sets whether this hex is part of a movement path preview.
## @param is_preview: bool - Whether to show path preview.
## @param is_destination: bool - Whether this is the destination hex.
func set_path_preview(is_preview: bool, is_destination: bool = false) -> void:
	is_path_preview = is_preview
	is_path_destination = is_destination


## Clears path preview state.
func clear_path_preview() -> void:
	is_path_preview = false
	is_path_destination = false


## Gets a summary of this hex's terrain data.
## @return Dictionary - Contains terrain_type, elevation, moisture.
func get_terrain_data() -> Dictionary:
	return {
		"terrain_type": terrain_type,
		"elevation": elevation,
		"moisture": moisture,
		"has_river": has_river,
		"has_location": location != null,
		"axial_coords": axial_coords,
		"offset_coords": get_offset_coords()
	}

# =============================================================================
# RIVER VISUALS
# =============================================================================

## Updates river overlay visuals based on has_river state.
func update_river_visuals() -> void:
	if _river_overlay == null:
		return
	
	_river_overlay.visible = has_river
	
	if has_river:
		_build_river_polygon()


func _build_river_polygon() -> void:
	if _river_polygon == null:
		return
	
	# Create a river shape based on flow direction
	var river_width := hex_size * 0.2
	var points: PackedVector2Array = []
	
	if river_flow_direction == Vector2i.ZERO:
		# End of river or source - draw a circle/pool
		var segments := 8
		for i in range(segments):
			var angle := float(i) / float(segments) * TAU
			points.append(Vector2(
				cos(angle) * river_width,
				sin(angle) * river_width
			))
	else:
		# Draw river flowing through hex
		# Calculate flow angle
		var flow_pixel := HexUtils.axial_to_pixel(river_flow_direction, hex_size)
		var flow_angle := flow_pixel.angle()
		
		# Create elongated shape along flow direction
		var perp_angle := flow_angle + PI / 2
		var half_length := hex_size * 0.6
		var half_width := river_width * 0.5
		
		# Four corners of the river segment
		var dir := Vector2.from_angle(flow_angle)
		var perp := Vector2.from_angle(perp_angle)
		
		points.append(-dir * half_length + perp * half_width)
		points.append(-dir * half_length - perp * half_width)
		points.append(dir * half_length - perp * half_width)
		points.append(dir * half_length + perp * half_width)
	
	_river_polygon.polygon = points
	_river_polygon.color = Color(0.2, 0.5, 0.8, 0.7)

# =============================================================================
# LOCATION VISUALS
# =============================================================================

## Updates location overlay visuals based on location data.
func update_location_visuals() -> void:
	if _location_container == null:
		return
	
	# Only show locations if hex is explored or visible
	var should_show := location != null and exploration_state != ExplorationState.UNEXPLORED
	_location_container.visible = should_show
	
	if location == null:
		return
	
	var loc_type: String = location.get("type", "unknown")
	var loc_name: String = location.get("name", "")
	
	# Try to load location sprite
	var sprite_loaded := _load_location_sprite(loc_type)
	
	if not sprite_loaded:
		# Use fallback marker
		_build_location_marker(loc_type)
	
	# Update label
	_location_label.text = _get_location_icon_char(loc_type)
	_location_label.position = Vector2(-6, -hex_size * 0.3)
	_location_label.visible = not sprite_loaded


func _load_location_sprite(loc_type: String) -> bool:
	var sprite_paths := [
		"res://assets/images/maps/locations/%s.png" % loc_type,
		"res://assets/images/maps/%s.png" % loc_type
	]
	
	for sprite_path in sprite_paths:
		if ResourceLoader.exists(sprite_path):
			var texture := load(sprite_path) as Texture2D
			if texture:
				_location_sprite.texture = texture
				_location_sprite.scale = Vector2(0.5, 0.5)  # Adjust as needed
				_location_sprite.visible = true
				_location_marker.visible = false
				return true
	
	_location_sprite.visible = false
	return false


func _build_location_marker(loc_type: String) -> void:
	var color := _get_location_color(loc_type)
	var size := hex_size * 0.35
	
	# Create a simple marker shape based on location type
	var points: PackedVector2Array = []
	
	match loc_type:
		"town":
			# House shape
			points = PackedVector2Array([
				Vector2(-size, size * 0.3),
				Vector2(-size, -size * 0.3),
				Vector2(0, -size),
				Vector2(size, -size * 0.3),
				Vector2(size, size * 0.3)
			])
		"fort":
			# Square with battlements
			var s := size * 0.8
			points = PackedVector2Array([
				Vector2(-s, s),
				Vector2(-s, -s),
				Vector2(s, -s),
				Vector2(s, s)
			])
		"cave":
			# Triangle/arch
			points = PackedVector2Array([
				Vector2(-size, size * 0.3),
				Vector2(0, -size),
				Vector2(size, size * 0.3)
			])
		_:
			# Default diamond
			points = PackedVector2Array([
				Vector2(0, -size),
				Vector2(size, 0),
				Vector2(0, size),
				Vector2(-size, 0)
			])
	
	_location_marker.polygon = points
	_location_marker.color = color
	_location_marker.visible = true


func _get_location_color(loc_type: String) -> Color:
	match loc_type:
		"town": return Color("#8b4513")
		"fort": return Color("#696969")
		"cave": return Color("#2f2f2f")
		"trading_post": return Color("#daa520")
		"mission": return Color("#f5f5dc")
		"caravan_camp": return Color("#d2691e")
		"roadhouse": return Color("#8b7355")
		_: return Color.WHITE


func _get_location_icon_char(loc_type: String) -> String:
	match loc_type:
		"town": return "T"
		"fort": return "F"
		"cave": return "C"
		"trading_post": return "$"
		"mission": return "+"
		"caravan_camp": return "~"
		"roadhouse": return "R"
		_: return "?"


## Checks if this hex is passable (for pathfinding).
## @return bool - True if the terrain allows movement.
func is_passable() -> bool:
	# Check custom_data first for overrides
	if custom_data.has("passable"):
		return custom_data["passable"]
	
	# Default passability based on terrain type
	match terrain_type:
		"deep_water", "mountain_peak":
			return false
		_:
			return true


## Gets the movement cost for this hex.
## @return float - Movement cost (-1 = impassable).
func get_movement_cost() -> float:
	# Check custom_data first for overrides
	if custom_data.has("movement_cost"):
		return custom_data["movement_cost"]
	
	# Default costs based on terrain type
	match terrain_type:
		"deep_water", "mountain_peak": return -1.0
		"road": return 0.5
		"plains", "grassland": return 1.0
		"desert", "forest", "hills", "forest_hills": return 1.5
		"water", "snow", "badlands": return 2.0
		"swamp", "highlands": return 2.5
		"mountains": return 3.0
		_: return 1.0

# =============================================================================
# FOG OF WAR
# =============================================================================

## Sets the exploration state and updates fog overlay.
## @param new_state: ExplorationState - The new state.
## @param use_transition: bool - Whether to animate the change.
func set_exploration_state(new_state: ExplorationState, use_transition: bool = true) -> void:
	if exploration_state == new_state:
		return
	
	var old_state := exploration_state
	exploration_state = new_state
	
	# Record first discovery time
	if old_state == ExplorationState.UNEXPLORED and new_state != ExplorationState.UNEXPLORED:
		var time_manager = get_node_or_null("/root/TimeManager")
		if time_manager:
			first_discovered_day = time_manager.current_day
			first_discovered_turn = time_manager.current_turn
		else:
			first_discovered_day = 1
			first_discovered_turn = 1
	
	# Update fog overlay
	_update_fog_overlay(use_transition)
	
	# Update location visibility
	_update_location_visibility()


## Updates the fog overlay based on exploration state.
func _update_fog_overlay(use_transition: bool) -> void:
	if _fog_overlay == null:
		return
	
	var target_color: Color
	match exploration_state:
		ExplorationState.UNEXPLORED:
			target_color = _fog_colors["unexplored"]
		ExplorationState.EXPLORED:
			target_color = _fog_colors["explored"]
		ExplorationState.VISIBLE:
			target_color = _fog_colors["visible"]
	
	# Cancel any existing tween
	if _fog_tween and _fog_tween.is_valid():
		_fog_tween.kill()
	
	if use_transition and _fog_transition_duration > 0:
		_fog_tween = create_tween()
		_fog_tween.set_ease(Tween.EASE_OUT)
		_fog_tween.set_trans(Tween.TRANS_CUBIC)
		_fog_tween.tween_property(_fog_overlay, "color", target_color, _fog_transition_duration)
	else:
		_fog_overlay.color = target_color


## Updates location visibility based on exploration state.
func _update_location_visibility() -> void:
	if _location_container == null:
		return
	
	# Locations are only visible if hex is explored or visible
	var should_show := location != null and exploration_state != ExplorationState.UNEXPLORED
	_location_container.visible = should_show


## Sets whether fog overlay is visible (debug toggle).
func set_fog_visible(visible: bool) -> void:
	if _fog_overlay:
		_fog_overlay.visible = visible


## Checks if this hex is currently visible.
func is_visible_state() -> bool:
	return exploration_state == ExplorationState.VISIBLE


## Checks if this hex has been explored.
func is_explored_state() -> bool:
	return exploration_state != ExplorationState.UNEXPLORED
