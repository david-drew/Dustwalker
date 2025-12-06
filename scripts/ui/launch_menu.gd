# launch_menu.gd
# Main menu screen shown at game start.
# Provides options for New Game, Load Game, Settings, and Quit.
#
# Styled as a Western-themed title screen with dusty, weathered aesthetic.

extends Control
class_name LaunchMenu

# =============================================================================
# SIGNALS
# =============================================================================

signal new_game_pressed()
signal load_game_pressed(save_path: String)
signal settings_requested()
signal quit_pressed()

# =============================================================================
# CONFIGURATION
# =============================================================================

## Game title.
@export var game_title: String = "DUSTWALKER"

## Subtitle/tagline.
@export var subtitle: String = "A Weird West Journey"

## Background color.
@export var bg_color: Color = Color(0.12, 0.10, 0.08)

## Title color.
@export var title_color: Color = Color(0.85, 0.75, 0.55)

## Button normal color.
@export var button_color: Color = Color(0.25, 0.22, 0.18)

## Button hover color.
@export var button_hover_color: Color = Color(0.35, 0.30, 0.22)

## Button text color.
@export var button_text_color: Color = Color(0.9, 0.85, 0.7)

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _background: ColorRect
var _title_label: Label
var _subtitle_label: Label
var _button_container: VBoxContainer
var _new_game_button: Button
var _load_game_button: Button
var _settings_button: Button
var _quit_button: Button
var _version_label: Label

# =============================================================================
# STATE
# =============================================================================

## Whether there are save files to load.
var has_saves: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_buttons()
	_check_for_saves()
	
	# Ensure full rect
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _create_ui() -> void:
	# Background
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = bg_color
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	
	# Main container (centered)
	var main_container := VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_CENTER)
	main_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# Title
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = game_title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 72)
	_title_label.add_theme_color_override("font_color", title_color)
	main_container.add_child(_title_label)
	
	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.name = "Subtitle"
	_subtitle_label.text = subtitle
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 24)
	_subtitle_label.add_theme_color_override("font_color", title_color.darkened(0.3))
	main_container.add_child(_subtitle_label)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	main_container.add_child(spacer)
	
	# Button container
	_button_container = VBoxContainer.new()
	_button_container.name = "ButtonContainer"
	_button_container.add_theme_constant_override("separation", 12)
	_button_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_container.add_child(_button_container)
	
	# Create buttons
	_new_game_button = _create_menu_button("New Game")
	_button_container.add_child(_new_game_button)
	
	_load_game_button = _create_menu_button("Continue")
	_button_container.add_child(_load_game_button)
	
	_settings_button = _create_menu_button("Settings")
	_button_container.add_child(_settings_button)
	
	_quit_button = _create_menu_button("Quit")
	_button_container.add_child(_quit_button)
	
	# Version label (bottom right)
	_version_label = Label.new()
	_version_label.name = "Version"
	_version_label.text = "v0.1.0 - Early Development"
	_version_label.add_theme_font_size_override("font_size", 14)
	_version_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	_version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_version_label.offset_left = -200
	_version_label.offset_top = -30
	_version_label.offset_right = -10
	_version_label.offset_bottom = -10
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_version_label)


func _create_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250, 50)
	
	# Style the button
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = button_color
	style_normal.border_color = title_color.darkened(0.2)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(4)
	style_normal.content_margin_left = 20
	style_normal.content_margin_right = 20
	style_normal.content_margin_top = 10
	style_normal.content_margin_bottom = 10
	
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = button_hover_color
	style_hover.border_color = title_color
	
	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = button_hover_color.darkened(0.2)
	
	var style_disabled := style_normal.duplicate()
	style_disabled.bg_color = button_color.darkened(0.3)
	style_disabled.border_color = title_color.darkened(0.5)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)
	
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", button_text_color)
	button.add_theme_color_override("font_hover_color", button_text_color)
	button.add_theme_color_override("font_pressed_color", button_text_color.darkened(0.2))
	button.add_theme_color_override("font_disabled_color", button_text_color.darkened(0.5))
	
	return button


func _connect_buttons() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_game_button.pressed.connect(_on_load_game_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

# =============================================================================
# SAVE DETECTION
# =============================================================================

func _check_for_saves() -> void:
	has_saves = false
	
	var save_dir := DirAccess.open("user://saves/")
	if save_dir:
		save_dir.list_dir_begin()
		var file_name := save_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") or file_name.ends_with(".save"):
				has_saves = true
				break
			file_name = save_dir.get_next()
		save_dir.list_dir_end()
	
	# Update continue button state
	_load_game_button.disabled = not has_saves
	_load_game_button.text = "Continue" if has_saves else "Continue (No Saves)"


## Refresh the menu (e.g., after returning from settings).
func refresh() -> void:
	_check_for_saves()

# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_new_game_pressed() -> void:
	print("LaunchMenu: New Game pressed")
	new_game_pressed.emit()
	_emit_to_event_bus("new_game_requested", [])


func _on_load_game_pressed() -> void:
	if not has_saves:
		return
	
	print("LaunchMenu: Load Game pressed")
	
	# Find most recent save
	var most_recent := _find_most_recent_save()
	load_game_pressed.emit(most_recent)
	_emit_to_event_bus("load_game_requested", [most_recent])


func _on_settings_pressed() -> void:
	print("LaunchMenu: Settings pressed")
	settings_requested.emit()
	_emit_to_event_bus("settings_requested", [])


func _on_quit_pressed() -> void:
	print("LaunchMenu: Quit pressed")
	quit_pressed.emit()
	_emit_to_event_bus("quit_requested", [])


func _find_most_recent_save() -> String:
	var most_recent_path := ""
	var most_recent_time := 0
	
	var save_dir := DirAccess.open("user://saves/")
	if save_dir:
		save_dir.list_dir_begin()
		var file_name := save_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") or file_name.ends_with(".save"):
				var full_path := "user://saves/" + file_name
				var mod_time := FileAccess.get_modified_time(full_path)
				if mod_time > most_recent_time:
					most_recent_time = mod_time
					most_recent_path = full_path
			file_name = save_dir.get_next()
		save_dir.list_dir_end()
	
	return most_recent_path

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
