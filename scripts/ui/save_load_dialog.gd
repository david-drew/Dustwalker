# save_load_dialog.gd
# Modal dialog for loading games and managing saves.
# Shows profiles on the left, saves for selected profile on the right.
#
# Can operate in two modes:
# - Load mode: Select a profile and save to load
# - Save mode: Select a profile and enter a name for a new save

extends Control
class_name SaveLoadDialog

# =============================================================================
# SIGNALS
# =============================================================================

signal save_selected(profile_name: String, save_name: String)
signal save_requested(save_name: String)
signal canceled()
signal profile_deleted(profile_name: String)
signal save_deleted(profile_name: String, save_name: String)

# =============================================================================
# ENUMS
# =============================================================================

enum Mode { LOAD, SAVE }

# =============================================================================
# STATE
# =============================================================================

var _save_manager: Node = null
var _mode: Mode = Mode.LOAD
var _selected_profile: String = ""
var _selected_save: String = ""

# =============================================================================
# UI REFERENCES (created dynamically)
# =============================================================================

var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _profile_list: ItemList
var _save_list: ItemList
var _profile_info_label: Label
var _save_info_label: Label
var _save_name_input: LineEdit
var _load_button: Button
var _save_button: Button
var _delete_profile_button: Button
var _delete_save_button: Button
var _cancel_button: Button

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
	_create_ui()
	hide()


func _create_ui() -> void:
	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(900, 600)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_panel)

	# Style the panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.08)
	panel_style.border_color = Color(0.595, 0.525, 0.385)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", panel_style)

	# Main vertical layout
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	_panel.add_child(main_vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "Load Game"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	# Content area (horizontal split)
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 20)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# Left side - Profiles
	var profile_vbox := VBoxContainer.new()
	profile_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_vbox.add_theme_constant_override("separation", 8)
	content_hbox.add_child(profile_vbox)

	var profile_header := Label.new()
	profile_header.text = "Characters"
	profile_header.add_theme_font_size_override("font_size", 20)
	profile_header.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	profile_vbox.add_child(profile_header)

	_profile_list = ItemList.new()
	_profile_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_profile_list.add_theme_font_size_override("font_size", 18)
	_profile_list.item_selected.connect(_on_profile_selected)
	profile_vbox.add_child(_profile_list)
	_style_item_list(_profile_list)

	_profile_info_label = Label.new()
	_profile_info_label.add_theme_font_size_override("font_size", 14)
	_profile_info_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	_profile_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_profile_info_label.custom_minimum_size.y = 60
	profile_vbox.add_child(_profile_info_label)

	_delete_profile_button = Button.new()
	_delete_profile_button.text = "Delete Character"
	_delete_profile_button.disabled = true
	_delete_profile_button.pressed.connect(_on_delete_profile_pressed)
	profile_vbox.add_child(_delete_profile_button)
	_style_button(_delete_profile_button, true)

	# Right side - Saves
	var save_vbox := VBoxContainer.new()
	save_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_vbox.add_theme_constant_override("separation", 8)
	content_hbox.add_child(save_vbox)

	var save_header := Label.new()
	save_header.text = "Saves"
	save_header.add_theme_font_size_override("font_size", 20)
	save_header.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	save_vbox.add_child(save_header)

	_save_list = ItemList.new()
	_save_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_save_list.add_theme_font_size_override("font_size", 18)
	_save_list.item_selected.connect(_on_save_selected)
	save_vbox.add_child(_save_list)
	_style_item_list(_save_list)

	_save_info_label = Label.new()
	_save_info_label.add_theme_font_size_override("font_size", 14)
	_save_info_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	_save_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_save_info_label.custom_minimum_size.y = 60
	save_vbox.add_child(_save_info_label)

	# Save name input (only visible in save mode)
	_save_name_input = LineEdit.new()
	_save_name_input.placeholder_text = "Enter save name..."
	_save_name_input.add_theme_font_size_override("font_size", 18)
	_save_name_input.visible = false
	save_vbox.add_child(_save_name_input)
	_style_line_edit(_save_name_input)

	_delete_save_button = Button.new()
	_delete_save_button.text = "Delete Save"
	_delete_save_button.disabled = true
	_delete_save_button.pressed.connect(_on_delete_save_pressed)
	save_vbox.add_child(_delete_save_button)
	_style_button(_delete_save_button, true)

	# Bottom buttons
	var button_hbox := HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 15)
	button_hbox.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(button_hbox)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(120, 40)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(_cancel_button)
	_style_button(_cancel_button)

	_load_button = Button.new()
	_load_button.text = "Load"
	_load_button.custom_minimum_size = Vector2(120, 40)
	_load_button.disabled = true
	_load_button.pressed.connect(_on_load_pressed)
	button_hbox.add_child(_load_button)
	_style_button(_load_button)

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.custom_minimum_size = Vector2(120, 40)
	_save_button.disabled = true
	_save_button.visible = false
	_save_button.pressed.connect(_on_save_pressed)
	button_hbox.add_child(_save_button)
	_style_button(_save_button)


func _style_item_list(list: ItemList) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06)
	style.border_color = Color(0.4, 0.36, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	list.add_theme_stylebox_override("panel", style)
	list.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	list.add_theme_color_override("font_selected_color", Color(0.95, 0.9, 0.75))


func _style_button(button: Button, danger: bool = false) -> void:
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.25, 0.22, 0.18) if not danger else Color(0.35, 0.18, 0.15)
	style_normal.border_color = Color(0.595, 0.525, 0.385) if not danger else Color(0.6, 0.35, 0.3)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(4)
	style_normal.content_margin_left = 15
	style_normal.content_margin_right = 15
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8

	var style_hover := style_normal.duplicate()
	style_hover.bg_color = Color(0.35, 0.30, 0.22) if not danger else Color(0.45, 0.22, 0.18)
	style_hover.border_color = Color(0.85, 0.75, 0.55) if not danger else Color(0.8, 0.4, 0.35)

	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = Color(0.2, 0.18, 0.14) if not danger else Color(0.25, 0.12, 0.1)

	var style_disabled := style_normal.duplicate()
	style_disabled.bg_color = Color(0.18, 0.16, 0.13)
	style_disabled.border_color = Color(0.4, 0.36, 0.28)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)
	button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.38))


func _style_line_edit(line_edit: LineEdit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06)
	style.border_color = Color(0.4, 0.36, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	line_edit.add_theme_stylebox_override("normal", style)
	line_edit.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.5, 0.45, 0.4))

# =============================================================================
# PUBLIC API
# =============================================================================

## Open in load mode
func open_load() -> void:
	_mode = Mode.LOAD
	_title_label.text = "Load Game"
	_load_button.visible = true
	_save_button.visible = false
	_save_name_input.visible = false
	_refresh_profiles()
	show()


## Open in save mode (for in-game saving)
func open_save() -> void:
	_mode = Mode.SAVE
	_title_label.text = "Save Game"
	_load_button.visible = false
	_save_button.visible = true
	_save_name_input.visible = true
	_save_name_input.text = ""

	# Auto-select current profile if one is active
	if _save_manager and not _save_manager.current_profile.is_empty():
		_selected_profile = _save_manager.current_profile

	_refresh_profiles()
	show()


## Close the dialog
func close() -> void:
	hide()
	_selected_profile = ""
	_selected_save = ""

# =============================================================================
# DATA REFRESH
# =============================================================================

func _refresh_profiles() -> void:
	_profile_list.clear()
	_selected_profile = ""
	_selected_save = ""
	_profile_info_label.text = ""
	_save_list.clear()
	_save_info_label.text = ""
	_update_button_states()

	if not _save_manager:
		return

	var profiles: Array = _save_manager.get_profiles()

	for profile_name in profiles:
		var info: Dictionary = _save_manager.get_profile_info(profile_name)
		var char_name: String = info.get("character_name", profile_name)
		var background: String = info.get("background", "Unknown")
		_profile_list.add_item("%s (%s)" % [char_name, background.capitalize()])
		_profile_list.set_item_metadata(_profile_list.item_count - 1, profile_name)

	# Auto-select current profile in save mode
	if _mode == Mode.SAVE and _save_manager and not _save_manager.current_profile.is_empty():
		for i in range(_profile_list.item_count):
			if _profile_list.get_item_metadata(i) == _save_manager.current_profile:
				_profile_list.select(i)
				_on_profile_selected(i)
				break


func _refresh_saves() -> void:
	_save_list.clear()
	_selected_save = ""
	_save_info_label.text = ""
	_update_button_states()

	if not _save_manager or _selected_profile.is_empty():
		return

	var saves: Array = _save_manager.get_saves(_selected_profile)

	for save_data in saves:
		var save_name: String = save_data.get("save_name", "Unknown")
		var day: int = save_data.get("day", 1)
		var display := "%s (Day %d)" % [save_name, day]
		_save_list.add_item(display)
		_save_list.set_item_metadata(_save_list.item_count - 1, save_data)

# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_profile_selected(index: int) -> void:
	_selected_profile = _profile_list.get_item_metadata(index)
	_selected_save = ""

	# Update profile info
	if _save_manager:
		var info: Dictionary = _save_manager.get_profile_info(_selected_profile)
		var char_name: String = info.get("character_name", "Unknown")
		var background: String = info.get("background", "Unknown")
		var last_played: String = info.get("last_played", "Never")
		_profile_info_label.text = "%s\nBackground: %s\nLast played: %s" % [
			char_name, background.capitalize(), _format_datetime(last_played)
		]

	_refresh_saves()
	_update_button_states()


func _on_save_selected(index: int) -> void:
	var save_data: Dictionary = _save_list.get_item_metadata(index)
	_selected_save = save_data.get("file_name", "")

	# Update save info
	var save_name: String = save_data.get("save_name", "Unknown")
	var day: int = save_data.get("day", 1)
	var turn: int = save_data.get("turn", 1)
	var saved_at: String = save_data.get("saved_at", "")
	_save_info_label.text = "%s\nDay %d, Turn %d\nSaved: %s" % [
		save_name, day, turn, _format_datetime(saved_at)
	]

	_update_button_states()


func _on_load_pressed() -> void:
	if _selected_profile.is_empty() or _selected_save.is_empty():
		return

	save_selected.emit(_selected_profile, _selected_save)
	close()


func _on_save_pressed() -> void:
	var save_name := _save_name_input.text.strip_edges()
	if save_name.is_empty():
		save_name = "Save %s" % Time.get_datetime_string_from_system().replace(":", "-")

	save_requested.emit(save_name)
	close()


func _on_delete_profile_pressed() -> void:
	if _selected_profile.is_empty():
		return

	# TODO: Add confirmation dialog
	profile_deleted.emit(_selected_profile)
	_refresh_profiles()


func _on_delete_save_pressed() -> void:
	if _selected_profile.is_empty() or _selected_save.is_empty():
		return

	# TODO: Add confirmation dialog
	save_deleted.emit(_selected_profile, _selected_save)
	_refresh_saves()


func _on_cancel_pressed() -> void:
	canceled.emit()
	close()


func _update_button_states() -> void:
	_delete_profile_button.disabled = _selected_profile.is_empty()
	_delete_save_button.disabled = _selected_save.is_empty()

	if _mode == Mode.LOAD:
		_load_button.disabled = _selected_save.is_empty()
	else:
		# In save mode, can save if profile is selected
		_save_button.disabled = _selected_profile.is_empty()

# =============================================================================
# UTILITY
# =============================================================================

func _format_datetime(datetime_str: String) -> String:
	if datetime_str.is_empty():
		return "Unknown"

	# datetime_str is like "2025-12-13T10:30:45"
	# Format it more readably
	var parts := datetime_str.split("T")
	if parts.size() == 2:
		return "%s %s" % [parts[0], parts[1].substr(0, 5)]

	return datetime_str


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
