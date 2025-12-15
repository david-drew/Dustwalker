# launch_menu.gd
# Main menu screen shown at game start.
# Provides options for New Game, Continue, Load Game, Settings, and Quit.
#
# REQUIRED SCENE STRUCTURE (launch_menu.tscn):
# LaunchMenu (Control) - this script
# ├── Background (ColorRect)
# ├── CenterContainer (CenterContainer)
# │   └── MainVBox (VBoxContainer)
# │       ├── Title (Label)
# │       ├── Subtitle (Label)
# │       ├── Spacer (Control)
# │       └── ButtonContainer (VBoxContainer)
# │           ├── NewGameButton (Button)
# │           ├── ContinueButton (Button)
# │           ├── LoadGameButton (Button)
# │           ├── SettingsButton (Button)
# │           └── QuitButton (Button)
# └── VersionLabel (Label)

extends Control
class_name LaunchMenu

# =============================================================================
# SIGNALS
# =============================================================================

signal new_game_pressed()
signal continue_pressed()
signal load_game_pressed()
signal settings_requested()
signal quit_pressed()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _background: ColorRect = $Background
@onready var _title: Label = $CenterContainer/MainVBox/Title
@onready var _subtitle: Label = $CenterContainer/MainVBox/Subtitle
@onready var _new_game_button: Button = $CenterContainer/MainVBox/ButtonContainer/NewGameButton
@onready var _continue_button: Button = $CenterContainer/MainVBox/ButtonContainer/ContinueButton
@onready var _load_game_button: Button = $CenterContainer/MainVBox/ButtonContainer/LoadGameButton
@onready var _settings_button: Button = $CenterContainer/MainVBox/ButtonContainer/SettingsButton
@onready var _quit_button: Button = $CenterContainer/MainVBox/ButtonContainer/QuitButton
@onready var _version_label: Label = $VersionLabel

var _save_manager: Node = null

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var game_title: String = "DUSTWALKER"
@export var subtitle: String = "A Weird West Journey"
@export var version_text: String = "v0.1.0 - Early Development"

# =============================================================================
# STATE
# =============================================================================

var has_saves: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
	_apply_configuration()
	_connect_buttons()
	_check_for_saves()
	_style_buttons()


func _apply_configuration() -> void:
	if _title:
		_title.text = game_title
	if _subtitle:
		_subtitle.text = subtitle
	if _version_label:
		_version_label.text = version_text


func _connect_buttons() -> void:
	if _new_game_button:
		_new_game_button.pressed.connect(_on_new_game_pressed)
	if _continue_button:
		_continue_button.pressed.connect(_on_continue_pressed)
	if _load_game_button:
		_load_game_button.pressed.connect(_on_load_game_pressed)
	if _settings_button:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _quit_button:
		_quit_button.pressed.connect(_on_quit_pressed)


func _style_buttons() -> void:
	# Apply western-themed styling to all buttons
	var buttons := [_new_game_button, _continue_button, _load_game_button, _settings_button, _quit_button]
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.25, 0.22, 0.18)
	style_normal.border_color = Color(0.595, 0.525, 0.385)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(4)
	style_normal.content_margin_left = 20
	style_normal.content_margin_right = 20
	style_normal.content_margin_top = 10
	style_normal.content_margin_bottom = 10
	
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = Color(0.35, 0.30, 0.22)
	style_hover.border_color = Color(0.85, 0.75, 0.55)
	
	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = Color(0.2, 0.18, 0.14)
	
	var style_disabled := style_normal.duplicate()
	style_disabled.bg_color = Color(0.18, 0.16, 0.13)
	style_disabled.border_color = Color(0.4, 0.36, 0.28)
	
	for button in buttons:
		if button:
			button.add_theme_stylebox_override("normal", style_normal)
			button.add_theme_stylebox_override("hover", style_hover)
			button.add_theme_stylebox_override("pressed", style_pressed)
			button.add_theme_stylebox_override("disabled", style_disabled)
			button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
			button.add_theme_color_override("font_hover_color", Color(0.95, 0.9, 0.8))
			button.add_theme_color_override("font_pressed_color", Color(0.7, 0.65, 0.55))
			button.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.38))

# =============================================================================
# SAVE DETECTION
# =============================================================================

func _check_for_saves() -> void:
	has_saves = false
	var has_profiles := false

	if _save_manager:
		# Check if we can continue (has last profile with saves)
		has_saves = _save_manager.has_continue_data()
		# Check if any profiles exist (for Load Game button)
		var profiles: Array = _save_manager.get_profiles()
		has_profiles = not profiles.is_empty()

	# Update continue button state
	if _continue_button:
		_continue_button.disabled = not has_saves
		if has_saves and _save_manager:
			var info: Dictionary = _save_manager.get_continue_info()
			var char_name: String = info.get("character_name", "Unknown")
			var day: int = info.get("day", 1)
			_continue_button.text = "Continue (%s - Day %d)" % [char_name, day]
		else:
			_continue_button.text = "Continue"

	# Update load game button state
	if _load_game_button:
		_load_game_button.disabled = not has_profiles
		_load_game_button.text = "Load Game"


## Refresh the menu state.
func refresh() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
	_check_for_saves()

# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_new_game_pressed() -> void:
	print("LaunchMenu: New Game pressed")
	new_game_pressed.emit()
	_emit_to_event_bus("new_game_requested", [])


func _on_continue_pressed() -> void:
	if not has_saves:
		return

	print("LaunchMenu: Continue pressed")
	continue_pressed.emit()
	_emit_to_event_bus("continue_game_requested", [])


func _on_load_game_pressed() -> void:
	print("LaunchMenu: Load Game pressed")
	load_game_pressed.emit()
	_emit_to_event_bus("load_game_dialog_requested", [])


func _on_settings_pressed() -> void:
	print("LaunchMenu: Settings pressed")
	settings_requested.emit()
	_emit_to_event_bus("settings_requested", [])


func _on_quit_pressed() -> void:
	print("LaunchMenu: Quit pressed")
	quit_pressed.emit()
	_emit_to_event_bus("quit_requested", [])

# =============================================================================
# UTILITY
# =============================================================================

func _emit_to_event_bus(signal_name: String, args: Array) -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal(signal_name):
		match args.size():
			0: event_bus.emit_signal(signal_name)
			1: event_bus.emit_signal(signal_name, args[0])
			2: event_bus.emit_signal(signal_name, args[0], args[1])
