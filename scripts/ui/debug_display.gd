# debug_display.gd
# Toggleable debug overlay showing hex coordinates, FPS, camera info, and selected hex data.
# Press F3 to toggle visibility.
extends CanvasLayer
class_name DebugDisplay

# =============================================================================
# CONFIGURATION
# =============================================================================

## Key to toggle debug display.
@export var toggle_key: Key = KEY_F3

## Key to toggle coordinate labels on hexes.
@export var coord_labels_key: Key = KEY_F4

## Update interval for FPS counter (seconds).
@export var fps_update_interval: float = 0.5

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _container: PanelContainer
var _vbox: VBoxContainer
var _fps_label: Label
var _camera_label: Label
var _hover_label: Label
var _selection_label: Label
var _terrain_label: Label
var _help_label: Label

# =============================================================================
# STATE
# =============================================================================

var _visible: bool = true
var _fps_timer: float = 0.0
var _frame_count: int = 0
var _current_fps: float = 0.0

var _camera: MapCamera = null
var _hex_grid: HexGrid = null

var _hovered_coords: Variant = null
var _selected_coords: Variant = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_signals()
	_find_references()
	
	# Initial state
	_update_visibility()


func _create_ui() -> void:
	# Create container panel
	_container = PanelContainer.new()
	_container.name = "DebugPanel"
	
	# Style the panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_container.add_theme_stylebox_override("panel", style)
	
	# Position in top-left
	_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_container.position = Vector2(10, 10)
	
	# Create vertical layout
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_container.add_child(_vbox)
	
	# Create labels
	_fps_label = _create_label("FPS: --")
	_camera_label = _create_label("Camera: (0, 0) Zoom: 1.0x")
	_hover_label = _create_label("Hover: None")
	_selection_label = _create_label("Selected: None")
	_terrain_label = _create_label("Terrain: --")
	
	# Separator
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	_vbox.add_child(separator)
	
	# Help text
	_help_label = _create_label("F3: Debug | F4: Coords | G: Generate")
	_help_label.add_theme_font_size_override("font_size", 10)
	_help_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	add_child(_container)


func _create_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_vbox.add_child(label)
	return label


func _connect_signals() -> void:
	# Connect to EventBus
	if has_node("/root/EventBus"):
		var event_bus = get_node("/root/EventBus")
		event_bus.hex_selected.connect(_on_hex_selected)
		event_bus.hex_deselected.connect(_on_hex_deselected)
		event_bus.hex_hovered.connect(_on_hex_hovered)
		event_bus.hex_hover_exited.connect(_on_hex_hover_exited)
		event_bus.camera_moved.connect(_on_camera_moved)
		event_bus.camera_zoomed.connect(_on_camera_zoomed)


func _find_references() -> void:
	# Delay to allow scene to fully initialize
	await get_tree().process_frame
	
	# Find camera
	var cameras = get_tree().get_nodes_in_group("map_camera")
	if cameras.size() > 0:
		_camera = cameras[0]
	else:
		# Search for MapCamera type
		for node in get_tree().get_nodes_in_group(""):
			if node is MapCamera:
				_camera = node
				break
		# Try parent's children
		if _camera == null:
			var root = get_tree().current_scene
			if root:
				for child in root.get_children():
					if child is MapCamera:
						_camera = child
						break
	
	# Find hex grid
	var grids = get_tree().get_nodes_in_group("hex_grid")
	if grids.size() > 0:
		_hex_grid = grids[0]
	else:
		# Search by type
		var root = get_tree().current_scene
		if root:
			for child in root.get_children():
				if child is HexGrid:
					_hex_grid = child
					break

# =============================================================================
# PROCESS
# =============================================================================

func _process(delta: float) -> void:
	if not _visible:
		return
	
	# Update FPS counter
	_fps_timer += delta
	_frame_count += 1
	
	if _fps_timer >= fps_update_interval:
		_current_fps = _frame_count / _fps_timer
		_fps_label.text = "FPS: %.1f" % _current_fps
		_fps_timer = 0.0
		_frame_count = 0
	
	# Update camera info if we have a reference
	if _camera:
		_camera_label.text = "Camera: (%.0f, %.0f) Zoom: %.2fx" % [
			_camera.position.x,
			_camera.position.y,
			_camera.get_zoom_level()
		]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			toggle_key:
				_visible = not _visible
				_update_visibility()
				
				if has_node("/root/EventBus"):
					get_node("/root/EventBus").debug_display_toggled.emit(_visible)
			
			coord_labels_key:
				if _hex_grid:
					_hex_grid.set_debug_labels_visible(not _hex_grid.debug_labels_visible)


func _update_visibility() -> void:
	_container.visible = _visible

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_hex_selected(coords: Vector2i) -> void:
	_selected_coords = coords
	_update_selection_label()


func _on_hex_deselected() -> void:
	_selected_coords = null
	_update_selection_label()


func _on_hex_hovered(coords: Vector2i) -> void:
	_hovered_coords = coords
	_update_hover_label()


func _on_hex_hover_exited() -> void:
	_hovered_coords = null
	_update_hover_label()


func _on_camera_moved(new_pos: Vector2) -> void:
	if _camera:
		_camera_label.text = "Camera: (%.0f, %.0f) Zoom: %.2fx" % [
			new_pos.x,
			new_pos.y,
			_camera.get_zoom_level()
		]


func _on_camera_zoomed(new_zoom: float) -> void:
	if _camera:
		_camera_label.text = "Camera: (%.0f, %.0f) Zoom: %.2fx" % [
			_camera.position.x,
			_camera.position.y,
			new_zoom
		]


func _update_selection_label() -> void:
	if _selected_coords == null:
		_selection_label.text = "Selected: None"
		_terrain_label.text = "Terrain: --"
	else:
		var offset := HexUtils.axial_to_offset(_selected_coords)
		_selection_label.text = "Selected: Axial(%d, %d) Offset(%d, %d)" % [
			_selected_coords.x, _selected_coords.y,
			offset.x, offset.y
		]
		
		# Get terrain info including elevation, moisture, river, location, and movement cost
		if _hex_grid:
			var cell := _hex_grid.get_cell(_selected_coords)
			if cell:
				var info_lines: Array[String] = []
				info_lines.append("Terrain: %s" % cell.terrain_type)
				info_lines.append("Elev: %.2f | Moist: %.2f" % [cell.elevation, cell.moisture])
				
				# Get movement cost
				var move_cost := cell.get_movement_cost()
				if move_cost < 0:
					info_lines.append("Movement: Impassable")
				elif move_cost == 1:
					info_lines.append("Movement: 1 turn")
				else:
					info_lines.append("Movement: %d turns" % int(move_cost))
				
				if cell.has_river:
					info_lines.append("River: Yes")
				
				if cell.location != null:
					var loc: Dictionary = cell.location
					info_lines.append("Location: %s" % loc.get("name", "Unknown"))
					info_lines.append("  Type: %s" % loc.get("type", "unknown"))
				
				_terrain_label.text = "\n".join(info_lines)
			else:
				_terrain_label.text = "Terrain: --"


func _update_hover_label() -> void:
	if _hovered_coords == null:
		_hover_label.text = "Hover: None"
	else:
		var offset := HexUtils.axial_to_offset(_hovered_coords)
		_hover_label.text = "Hover: Axial(%d, %d) Offset(%d, %d)" % [
			_hovered_coords.x, _hovered_coords.y,
			offset.x, offset.y
		]

# =============================================================================
# PUBLIC API
# =============================================================================

## Shows the debug display.
func show_debug() -> void:
	_visible = true
	_update_visibility()


## Hides the debug display.
func hide_debug() -> void:
	_visible = false
	_update_visibility()


## Toggles debug display visibility.
func toggle() -> void:
	_visible = not _visible
	_update_visibility()


## Returns whether debug display is currently visible.
func is_debug_visible() -> bool:
	return _visible


## Gets the current FPS reading.
func get_fps() -> float:
	return _current_fps
