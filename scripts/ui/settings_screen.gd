# settings_screen.gd
# Settings menu for audio, display, and gameplay options.
# Accessible from launch menu or during gameplay (pause).

extends Control
class_name SettingsScreen

# =============================================================================
# SIGNALS
# =============================================================================

signal settings_closed()
signal settings_changed(setting_name: String, value: Variant)

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var bg_color: Color = Color(0.12, 0.10, 0.08, 0.95)
@export var panel_color: Color = Color(0.18, 0.15, 0.12)
@export var title_color: Color = Color(0.85, 0.75, 0.55)
@export var text_color: Color = Color(0.9, 0.85, 0.7)

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _background: ColorRect
var _panel: PanelContainer
var _close_button: Button

# Settings controls
var _master_volume_slider: HSlider
var _music_volume_slider: HSlider
var _sfx_volume_slider: HSlider
var _fullscreen_check: CheckButton
var _vsync_check: CheckButton
var _camera_follow_check: CheckButton

# =============================================================================
# SETTINGS STATE
# =============================================================================

var settings: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"vsync": true,
	"camera_follow": true
}

const SETTINGS_PATH := "user://settings.json"

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_load_settings()
	_create_ui()
	_apply_settings()


func _create_ui() -> void:
	# Semi-transparent background
	_background = ColorRect.new()
	_background.color = bg_color
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	
	# Center panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(500, 450)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = title_color.darkened(0.3)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	_panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", title_color)
	vbox.add_child(title)
	
	# Audio section
	_create_section_label(vbox, "Audio")
	_master_volume_slider = _create_slider_row(vbox, "Master Volume", settings.master_volume)
	_music_volume_slider = _create_slider_row(vbox, "Music Volume", settings.music_volume)
	_sfx_volume_slider = _create_slider_row(vbox, "Sound Effects", settings.sfx_volume)
	
	# Display section
	_create_section_label(vbox, "Display")
	_fullscreen_check = _create_check_row(vbox, "Fullscreen", settings.fullscreen)
	_vsync_check = _create_check_row(vbox, "VSync", settings.vsync)
	
	# Gameplay section
	_create_section_label(vbox, "Gameplay")
	_camera_follow_check = _create_check_row(vbox, "Camera Follow Player", settings.camera_follow)
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Close button
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(150, 40)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.add_theme_font_size_override("font_size", 18)
	_close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_button)
	
	# Style close button
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = title_color.darkened(0.5)
	btn_style.set_corner_radius_all(4)
	btn_style.set_border_width_all(2)
	btn_style.border_color = title_color.darkened(0.2)
	_close_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = title_color.darkened(0.3)
	_close_button.add_theme_stylebox_override("hover", btn_hover)
	_close_button.add_theme_color_override("font_color", text_color)


func _create_section_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", title_color.darkened(0.2))
	parent.add_child(label)


func _create_slider_row(parent: VBoxContainer, label_text: String, initial_value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	parent.add_child(row)
	
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", text_color)
	row.add_child(label)
	
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(label_text))
	row.add_child(slider)
	
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "%d%%" % int(initial_value * 100)
	value_label.custom_minimum_size.x = 50
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", text_color.darkened(0.2))
	row.add_child(value_label)
	
	return slider


func _create_check_row(parent: VBoxContainer, label_text: String, initial_value: bool) -> CheckButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	parent.add_child(row)
	
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", text_color)
	row.add_child(label)
	
	var check := CheckButton.new()
	check.button_pressed = initial_value
	check.toggled.connect(_on_check_toggled.bind(label_text))
	row.add_child(check)
	
	return check

# =============================================================================
# SETTINGS HANDLERS
# =============================================================================

func _on_slider_changed(value: float, label_text: String) -> void:
	# Update value label
	var slider: HSlider
	match label_text:
		"Master Volume":
			slider = _master_volume_slider
			settings.master_volume = value
		"Music Volume":
			slider = _music_volume_slider
			settings.music_volume = value
		"Sound Effects":
			slider = _sfx_volume_slider
			settings.sfx_volume = value
	
	if slider:
		var row := slider.get_parent()
		var value_label := row.get_node_or_null("ValueLabel")
		if value_label:
			value_label.text = "%d%%" % int(value * 100)
	
	_apply_audio_settings()
	settings_changed.emit(label_text, value)


func _on_check_toggled(pressed: bool, label_text: String) -> void:
	match label_text:
		"Fullscreen":
			settings.fullscreen = pressed
			_apply_display_settings()
		"VSync":
			settings.vsync = pressed
			_apply_display_settings()
		"Camera Follow Player":
			settings.camera_follow = pressed
	
	settings_changed.emit(label_text, pressed)


func _on_close_pressed() -> void:
	_save_settings()
	settings_closed.emit()
	_emit_to_event_bus("settings_closed", [])

# =============================================================================
# SETTINGS APPLICATION
# =============================================================================

func _apply_settings() -> void:
	_apply_audio_settings()
	_apply_display_settings()


func _apply_audio_settings() -> void:
	# Apply to AudioServer
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(settings.master_volume))
	
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(settings.music_volume))
	
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(settings.sfx_volume))


func _apply_display_settings() -> void:
	# Fullscreen
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# VSync
	if settings.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

# =============================================================================
# PERSISTENCE
# =============================================================================

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "  "))
		file.close()
		print("SettingsScreen: Settings saved")


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		
		if error == OK and json.data is Dictionary:
			for key in json.data:
				if settings.has(key):
					settings[key] = json.data[key]
			print("SettingsScreen: Settings loaded")


## Refresh UI to match current settings.
func refresh() -> void:
	if _master_volume_slider:
		_master_volume_slider.value = settings.master_volume
	if _music_volume_slider:
		_music_volume_slider.value = settings.music_volume
	if _sfx_volume_slider:
		_sfx_volume_slider.value = settings.sfx_volume
	if _fullscreen_check:
		_fullscreen_check.button_pressed = settings.fullscreen
	if _vsync_check:
		_vsync_check.button_pressed = settings.vsync
	if _camera_follow_check:
		_camera_follow_check.button_pressed = settings.camera_follow

# =============================================================================
# UTILITY
# =============================================================================

func _emit_to_event_bus(signal_name: String, args: Array) -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal(signal_name):
		match args.size():
			0: event_bus.emit_signal(signal_name)
			1: event_bus.emit_signal(signal_name, args[0])
