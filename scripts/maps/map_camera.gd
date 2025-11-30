# map_camera.gd
# 2D camera with smooth panning and zooming for hex map navigation.
# Supports click-and-drag panning, mouse wheel zoom, and bounded movement.
extends Camera2D
class_name MapCamera

# =============================================================================
# CONFIGURATION
# =============================================================================

## Minimum zoom level (zoomed out - sees more).
@export var min_zoom: float = 0.25

## Maximum zoom level (zoomed in - sees less).
@export var max_zoom: float = 2.0

## How fast the zoom changes with scroll wheel.
@export var zoom_speed: float = 0.1

## Smoothing factor for zoom transitions (lower = slower).
@export var zoom_smoothing: float = 10.0

## Smoothing factor for camera movement (lower = slower).
@export var pan_smoothing: float = 15.0

## Whether to constrain camera to map bounds.
@export var use_bounds: bool = true

## Extra padding around map bounds (in pixels).
@export var bounds_padding: float = 100.0

## Enable edge panning when mouse is near screen edges.
@export var edge_pan_enabled: bool = false

## Distance from screen edge to trigger edge panning.
@export var edge_pan_margin: float = 50.0

## Speed of edge panning (pixels per second at zoom level 1).
@export var edge_pan_speed: float = 500.0

# =============================================================================
# RUNTIME STATE
# =============================================================================

## The map bounds (set by HexGrid).
var map_bounds: Rect2 = Rect2()

## Target zoom level (smoothly interpolated to).
var target_zoom: float = 1.0

## Target position (smoothly interpolated to).
var target_position: Vector2 = Vector2.ZERO

## Whether the user is currently panning with the mouse.
var is_panning: bool = false

## Last mouse position during pan operation.
var _pan_start_mouse: Vector2 = Vector2.ZERO

## Last camera position when pan started.
var _pan_start_camera: Vector2 = Vector2.ZERO

## Reference to the HexGrid for bounds calculation.
var _hex_grid: HexGrid = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	# Set initial zoom
	zoom = Vector2(target_zoom, target_zoom)
	target_position = position
	
	# Find the HexGrid if not set
	await get_tree().process_frame  # Wait for scene to be ready
	_find_hex_grid()
	
	# Connect to EventBus if available
	if has_node("/root/EventBus"):
		var event_bus = get_node("/root/EventBus")
		event_bus.map_generated.connect(_on_map_generated)


func _find_hex_grid() -> void:
	# Look for HexGrid in parent or siblings
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is HexGrid:
				_hex_grid = child
				_update_bounds()
				return
	
	# Try to find it anywhere in the scene
	var grids = get_tree().get_nodes_in_group("hex_grid")
	if grids.size() > 0:
		_hex_grid = grids[0]
		_update_bounds()


func _update_bounds() -> void:
	if _hex_grid:
		map_bounds = _hex_grid.get_map_bounds()
	else:
		# Default bounds if no grid found
		map_bounds = Rect2(-1000, -1000, 3000, 3000)

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	# Handle zoom with mouse wheel
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	
	# Handle pan with mouse motion
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_at_point(zoom_speed, get_global_mouse_position())
		
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_at_point(-zoom_speed, get_global_mouse_position())
		
		MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
			# Start or stop panning
			if event.pressed:
				is_panning = true
				_pan_start_mouse = get_viewport().get_mouse_position()
				_pan_start_camera = position
			else:
				is_panning = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if is_panning:
		# Calculate how much the mouse has moved in screen space
		var mouse_delta = get_viewport().get_mouse_position() - _pan_start_mouse
		
		# Convert to world space (account for zoom)
		var world_delta = mouse_delta / zoom.x
		
		# Update target position (inverted because dragging moves the view)
		target_position = _pan_start_camera - world_delta
		
		# Emit signal
		_emit_camera_moved()


func _zoom_at_point(zoom_delta: float, world_point: Vector2) -> void:
	# Calculate new zoom level
	var new_zoom := clampf(target_zoom + zoom_delta, min_zoom, max_zoom)
	
	if new_zoom == target_zoom:
		return
	
	# Calculate position adjustment to zoom towards the mouse point
	# This keeps the point under the cursor stationary
	var zoom_ratio := new_zoom / target_zoom
	var offset := world_point - target_position
	target_position = world_point - offset * (1.0 / zoom_ratio)
	
	target_zoom = new_zoom
	
	# Emit signal
	_emit_camera_zoomed()

# =============================================================================
# PROCESS
# =============================================================================

func _process(delta: float) -> void:
	# Handle edge panning
	if edge_pan_enabled and not is_panning:
		_handle_edge_panning(delta)
	
	# Smoothly interpolate to target zoom
	var current_zoom := zoom.x
	if not is_equal_approx(current_zoom, target_zoom):
		var new_zoom := lerpf(current_zoom, target_zoom, zoom_smoothing * delta)
		zoom = Vector2(new_zoom, new_zoom)
	
	# Smoothly interpolate to target position
	if position.distance_to(target_position) > 0.5:
		var clamped_target := _clamp_position(target_position)
		position = position.lerp(clamped_target, pan_smoothing * delta)
	else:
		position = _clamp_position(target_position)


func _handle_edge_panning(delta: float) -> void:
	var viewport := get_viewport()
	if not viewport:
		return
	
	var mouse_pos := viewport.get_mouse_position()
	var viewport_size := viewport.get_visible_rect().size
	
	var pan_direction := Vector2.ZERO
	
	# Check each edge
	if mouse_pos.x < edge_pan_margin:
		pan_direction.x = -1
	elif mouse_pos.x > viewport_size.x - edge_pan_margin:
		pan_direction.x = 1
	
	if mouse_pos.y < edge_pan_margin:
		pan_direction.y = -1
	elif mouse_pos.y > viewport_size.y - edge_pan_margin:
		pan_direction.y = 1
	
	if pan_direction != Vector2.ZERO:
		# Scale speed by zoom level (slower when zoomed in)
		var adjusted_speed := edge_pan_speed / zoom.x
		target_position += pan_direction.normalized() * adjusted_speed * delta
		_emit_camera_moved()


func _clamp_position(pos: Vector2) -> Vector2:
	if not use_bounds or map_bounds.size == Vector2.ZERO:
		return pos
	
	# Get viewport size in world coordinates
	var viewport_size := get_viewport_rect().size / zoom.x
	var half_viewport := viewport_size / 2.0
	
	# Calculate allowed camera position range
	var min_pos := Vector2(
		map_bounds.position.x - bounds_padding + half_viewport.x,
		map_bounds.position.y - bounds_padding + half_viewport.y
	)
	var max_pos := Vector2(
		map_bounds.end.x + bounds_padding - half_viewport.x,
		map_bounds.end.y + bounds_padding - half_viewport.y
	)
	
	# If map is smaller than viewport, center it
	if min_pos.x > max_pos.x:
		pos.x = map_bounds.get_center().x
	else:
		pos.x = clampf(pos.x, min_pos.x, max_pos.x)
	
	if min_pos.y > max_pos.y:
		pos.y = map_bounds.get_center().y
	else:
		pos.y = clampf(pos.y, min_pos.y, max_pos.y)
	
	return pos

# =============================================================================
# PUBLIC API
# =============================================================================

## Sets the map bounds for the camera.
## @param bounds: Rect2 - The bounding rectangle of the map.
func set_map_bounds(bounds: Rect2) -> void:
	map_bounds = bounds


## Centers the camera on a specific position.
## @param world_pos: Vector2 - World position to center on.
## @param instant: bool - If true, move instantly without smoothing.
func center_on(world_pos: Vector2, instant: bool = false) -> void:
	target_position = world_pos
	if instant:
		position = _clamp_position(target_position)
	_emit_camera_moved()


## Centers the camera on a hex coordinate.
## @param coords: Vector2i - Axial coordinates of the hex.
## @param hex_size: float - Size of hexes in the grid.
## @param instant: bool - If true, move instantly without smoothing.
func center_on_hex(coords: Vector2i, hex_size: float, instant: bool = false) -> void:
	var pixel_pos := HexUtils.axial_to_pixel(coords, hex_size)
	center_on(pixel_pos, instant)


## Sets the zoom level.
## @param zoom_level: float - Target zoom level.
## @param instant: bool - If true, change instantly without smoothing.
func set_zoom_level(zoom_level: float, instant: bool = false) -> void:
	target_zoom = clampf(zoom_level, min_zoom, max_zoom)
	if instant:
		zoom = Vector2(target_zoom, target_zoom)
	_emit_camera_zoomed()


## Gets the current zoom level.
## @return float - Current zoom level.
func get_zoom_level() -> float:
	return zoom.x


## Gets the world position at the center of the viewport.
## @return Vector2 - World position at viewport center.
func get_center_world_position() -> Vector2:
	return position


## Converts a screen position to world coordinates.
## @param screen_pos: Vector2 - Position in screen/viewport coordinates.
## @return Vector2 - Position in world coordinates.
func screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport_center := get_viewport_rect().size / 2.0
	var offset := (screen_pos - viewport_center) / zoom.x
	return position + offset


## Resets camera to default position and zoom.
## @param instant: bool - If true, reset instantly without smoothing.
func reset(instant: bool = false) -> void:
	target_zoom = 1.0
	if map_bounds.size != Vector2.ZERO:
		target_position = map_bounds.get_center()
	else:
		target_position = Vector2.ZERO
	
	if instant:
		zoom = Vector2(target_zoom, target_zoom)
		position = target_position

# =============================================================================
# SIGNAL EMISSION
# =============================================================================

func _emit_camera_moved() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").camera_moved.emit(position)


func _emit_camera_zoomed() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").camera_zoomed.emit(target_zoom)

# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_map_generated(map_size: Vector2i) -> void:
	# Recalculate bounds when map is generated
	_update_bounds()
	
	# Center on the map
	if map_bounds.size != Vector2.ZERO:
		center_on(map_bounds.get_center(), true)
