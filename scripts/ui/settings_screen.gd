# settings_screen.gd
# Settings menu for audio, display, and gameplay options.
# Accessible from launch menu or during gameplay (pause).
#
# REQUIRED SCENE STRUCTURE (settings_screen.tscn):
# SettingsScreen (Control) - this script
# ├── Background (ColorRect)
# └── PanelContainer (PanelContainer)
#     └── MarginContainer (MarginContainer)
#         └── MainVBox (VBoxContainer)
#             ├── Title (Label)
#             ├── AudioSection (Label)
#             ├── MasterVolumeRow (HBoxContainer)
#             │   ├── Label
#             │   ├── MasterVolumeSlider (HSlider)
#             │   └── MasterVolumeValue (Label)
#             ├── MusicVolumeRow (HBoxContainer)
#             │   ├── Label
#             │   ├── MusicVolumeSlider (HSlider)
#             │   └── MusicVolumeValue (Label)
#             ├── SFXVolumeRow (HBoxContainer)
#             │   ├── Label
#             │   ├── SFXVolumeSlider (HSlider)
#             │   └── SFXVolumeValue (Label)
#             ├── DisplaySection (Label)
#             ├── FullscreenRow (HBoxContainer)
#             │   ├── Label
#             │   └── FullscreenCheck (CheckButton)
#             ├── VSyncRow (HBoxContainer)
#             │   ├── Label
#             │   └── VSyncCheck (CheckButton)
#             ├── GameplaySection (Label)
#             ├── CameraFollowRow (HBoxContainer)
#             │   ├── Label
#             │   └── CameraFollowCheck (CheckButton)
#             ├── Spacer (Control)
#             └── CloseButton (Button)

extends Control
class_name SettingsScreen

# =============================================================================
# SIGNALS
# =============================================================================

signal settings_closed()
signal settings_changed(setting_name: String, value: Variant)

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _panel: PanelContainer = $PanelContainer
@onready var _master_slider: HSlider = $PanelContainer/MarginContainer/MainVBox/MasterVolumeRow/MasterVolumeSlider
@onready var _master_value: Label = $PanelContainer/MarginContainer/MainVBox/MasterVolumeRow/MasterVolumeValue
@onready var _music_slider: HSlider = $PanelContainer/MarginContainer/MainVBox/MusicVolumeRow/MusicVolumeSlider
@onready var _music_value: Label = $PanelContainer/MarginContainer/MainVBox/MusicVolumeRow/MusicVolumeValue
@onready var _sfx_slider: HSlider = $PanelContainer/MarginContainer/MainVBox/SFXVolumeRow/SFXVolumeSlider
@onready var _sfx_value: Label = $PanelContainer/MarginContainer/MainVBox/SFXVolumeRow/SFXVolumeValue
@onready var _fullscreen_check: CheckButton = $PanelContainer/MarginContainer/MainVBox/FullscreenRow/FullscreenCheck
@onready var _vsync_check: CheckButton = $PanelContainer/MarginContainer/MainVBox/VSyncRow/VSyncCheck
@onready var _camera_follow_check: CheckButton = $PanelContainer/MarginContainer/MainVBox/CameraFollowRow/CameraFollowCheck
@onready var _close_button: Button = $PanelContainer/MarginContainer/MainVBox/CloseButton

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
	_load_settings()
	_connect_controls()
	_apply_settings_to_ui()
	_apply_settings_to_game()
	_style_panel()
	_style_close_button()


func _connect_controls() -> void:
	if _master_slider:
		_master_slider.value_changed.connect(_on_master_volume_changed)
	if _music_slider:
		_music_slider.value_changed.connect(_on_music_volume_changed)
	if _sfx_slider:
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if _fullscreen_check:
		_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if _vsync_check:
		_vsync_check.toggled.connect(_on_vsync_toggled)
	if _camera_follow_check:
		_camera_follow_check.toggled.connect(_on_camera_follow_toggled)
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)


func _style_panel() -> void:
	if not _panel:
		return
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.12)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.595, 0.525, 0.385)
	_panel.add_theme_stylebox_override("panel", style)


func _style_close_button() -> void:
	if not _close_button:
		return
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.425, 0.375, 0.275)
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	style.border_color = Color(0.595, 0.525, 0.385)
	
	var hover := style.duplicate()
	hover.bg_color = Color(0.525, 0.475, 0.375)
	
	_close_button.add_theme_stylebox_override("normal", style)
	_close_button.add_theme_stylebox_override("hover", hover)
	_close_button.add_theme_stylebox_override("pressed", style)
	_close_button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))

# =============================================================================
# SETTINGS HANDLERS
# =============================================================================

func _on_master_volume_changed(value: float) -> void:
	settings.master_volume = value
	if _master_value:
		_master_value.text = "%d%%" % int(value * 100)
	_apply_audio_settings()
	settings_changed.emit("master_volume", value)


func _on_music_volume_changed(value: float) -> void:
	settings.music_volume = value
	if _music_value:
		_music_value.text = "%d%%" % int(value * 100)
	_apply_audio_settings()
	settings_changed.emit("music_volume", value)


func _on_sfx_volume_changed(value: float) -> void:
	settings.sfx_volume = value
	if _sfx_value:
		_sfx_value.text = "%d%%" % int(value * 100)
	_apply_audio_settings()
	settings_changed.emit("sfx_volume", value)


func _on_fullscreen_toggled(pressed: bool) -> void:
	settings.fullscreen = pressed
	_apply_display_settings()
	settings_changed.emit("fullscreen", pressed)


func _on_vsync_toggled(pressed: bool) -> void:
	settings.vsync = pressed
	_apply_display_settings()
	settings_changed.emit("vsync", pressed)


func _on_camera_follow_toggled(pressed: bool) -> void:
	settings.camera_follow = pressed
	settings_changed.emit("camera_follow", pressed)


func _on_close_pressed() -> void:
	_save_settings()
	settings_closed.emit()
	_emit_to_event_bus("settings_closed", [])

# =============================================================================
# SETTINGS APPLICATION
# =============================================================================

func _apply_settings_to_ui() -> void:
	if _master_slider:
		_master_slider.value = settings.master_volume
	if _master_value:
		_master_value.text = "%d%%" % int(settings.master_volume * 100)
	
	if _music_slider:
		_music_slider.value = settings.music_volume
	if _music_value:
		_music_value.text = "%d%%" % int(settings.music_volume * 100)
	
	if _sfx_slider:
		_sfx_slider.value = settings.sfx_volume
	if _sfx_value:
		_sfx_value.text = "%d%%" % int(settings.sfx_volume * 100)
	
	if _fullscreen_check:
		_fullscreen_check.button_pressed = settings.fullscreen
	if _vsync_check:
		_vsync_check.button_pressed = settings.vsync
	if _camera_follow_check:
		_camera_follow_check.button_pressed = settings.camera_follow


func _apply_settings_to_game() -> void:
	_apply_audio_settings()
	_apply_display_settings()


func _apply_audio_settings() -> void:
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
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
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
	_apply_settings_to_ui()

# =============================================================================
# UTILITY
# =============================================================================

func _emit_to_event_bus(signal_name: String, args: Array) -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal(signal_name):
		match args.size():
			0: event_bus.emit_signal(signal_name)
			1: event_bus.emit_signal(signal_name, args[0])
