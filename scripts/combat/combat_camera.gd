# combat_camera.gd
# Fixed camera for tactical combat that shows the entire battlefield.
# Supports zoom and pan for future expansion.

extends Camera2D
class_name CombatCamera

# =============================================================================
# CONFIGURATION
# =============================================================================

## Minimum zoom level (zoomed out).
const ZOOM_MIN: float = 0.5

## Maximum zoom level (zoomed in).
const ZOOM_MAX: float = 2.0

## Default zoom level.
const ZOOM_DEFAULT: float = 1.0

## Zoom speed (multiplier per scroll).
const ZOOM_SPEED: float = 0.1

## Pan speed when using keyboard/edge scrolling.
const PAN_SPEED: float = 400.0

## Edge scroll margin in pixels.
const EDGE_MARGIN: float = 50.0

## Whether edge scrolling is enabled.
var edge_scroll_enabled: bool = false

# =============================================================================
# STATE
# =============================================================================

## Current zoom level.
var current_zoom: float = ZOOM_DEFAULT

## Whether the camera is currently active.
var is_active: bool = false

## Bounds for camera panning (set from tactical map).
var pan_bounds: Rect2 = Rect2()

## Whether panning is allowed.
var can_pan: bool = true

## Whether zooming is allowed.
var can_zoom: bool = true

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	# Set default properties
	zoom = Vector2(current_zoom, current_zoom)
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0


func _process(delta: float) -> void:
	if not is_active:
		return
	
	_handle_edge_scroll(delta)
	_handle_keyboard_pan(delta)

# =============================================================================
# PUBLIC API
# =============================================================================

## Activate the combat camera.
func activate() -> void:
	is_active = true
	enabled = true
	make_current()


## Deactivate the combat camera.
func deactivate() -> void:
	is_active = false
	enabled = false


## Set the camera to view the entire tactical map.
## @param map_center: Center position of the tactical map.
## @param map_size: Size of the tactical map in pixels.
func frame_map(map_center: Vector2, map_size: Vector2) -> void:
	# Calculate zoom to fit map in viewport
	var viewport_size := get_viewport_rect().size
	
	# Add some padding
	var padded_size := map_size * 1.2
	
	var zoom_x := viewport_size.x / padded_size.x
	var zoom_y := viewport_size.y / padded_size.y
	
	# Use smaller zoom to ensure entire map fits
	current_zoom = minf(zoom_x, zoom_y)
	current_zoom = clampf(current_zoom, ZOOM_MIN, ZOOM_MAX)
	
	zoom = Vector2(current_zoom, current_zoom)
	position = map_center
	
	# Set pan bounds with some margin
	var margin := Vector2(100, 100)
	pan_bounds = Rect2(
		map_center - map_size / 2 - margin,
		map_size + margin * 2
	)


## Center camera on a position.
func center_on(target_position: Vector2) -> void:
	position = target_position


## Smoothly pan to a position.
func pan_to(target_position: Vector2, duration: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", target_position, duration).set_ease(Tween.EASE_OUT)


## Set zoom level.
func set_zoom_level(zoom_level: float) -> void:
	current_zoom = clampf(zoom_level, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(current_zoom, current_zoom)


## Reset camera to default state.
func reset() -> void:
	current_zoom = ZOOM_DEFAULT
	zoom = Vector2(current_zoom, current_zoom)
	position = Vector2.ZERO

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Mouse wheel zoom
	if can_zoom and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()
			get_viewport().set_input_as_handled()
	
	# Middle mouse drag pan
	if can_pan and event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			position -= event.relative / zoom
			_clamp_position()
			get_viewport().set_input_as_handled()


func _handle_keyboard_pan(delta: float) -> void:
	if not can_pan:
		return
	
	var pan_direction := Vector2.ZERO
	
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		pan_direction.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		pan_direction.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		pan_direction.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		pan_direction.y += 1
	
	if pan_direction != Vector2.ZERO:
		position += pan_direction.normalized() * PAN_SPEED * delta / zoom.x
		_clamp_position()


func _handle_edge_scroll(delta: float) -> void:
	if not edge_scroll_enabled or not can_pan:
		return
	
	var viewport_size := get_viewport_rect().size
	var mouse_pos := get_viewport().get_mouse_position()
	var pan_direction := Vector2.ZERO
	
	if mouse_pos.x < EDGE_MARGIN:
		pan_direction.x -= 1
	elif mouse_pos.x > viewport_size.x - EDGE_MARGIN:
		pan_direction.x += 1
	
	if mouse_pos.y < EDGE_MARGIN:
		pan_direction.y -= 1
	elif mouse_pos.y > viewport_size.y - EDGE_MARGIN:
		pan_direction.y += 1
	
	if pan_direction != Vector2.ZERO:
		position += pan_direction.normalized() * PAN_SPEED * delta / zoom.x
		_clamp_position()


func _zoom_in() -> void:
	current_zoom = minf(current_zoom + ZOOM_SPEED, ZOOM_MAX)
	
	var tween := create_tween()
	tween.tween_property(self, "zoom", Vector2(current_zoom, current_zoom), 0.1)


func _zoom_out() -> void:
	current_zoom = maxf(current_zoom - ZOOM_SPEED, ZOOM_MIN)
	
	var tween := create_tween()
	tween.tween_property(self, "zoom", Vector2(current_zoom, current_zoom), 0.1)


func _clamp_position() -> void:
	if pan_bounds.size == Vector2.ZERO:
		return
	
	position.x = clampf(position.x, pan_bounds.position.x, pan_bounds.end.x)
	position.y = clampf(position.y, pan_bounds.position.y, pan_bounds.end.y)
