# combat_defeat_screen.gd
# Displays defeat message after losing tactical combat.
# Shows cause of death and options to load save, restart, or quit.
# Similar to GameOverScreen but styled for combat defeat.

extends Control
class_name CombatDefeatScreen

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when player chooses to load a save.
signal load_save_requested()

## Emitted when player chooses to restart.
signal restart_requested()

## Emitted when player chooses to quit.
signal quit_requested()

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _overlay: ColorRect
var _panel: PanelContainer
var _vbox: VBoxContainer
var _title_label: Label
var _cause_label: Label
var _stats_label: Label
var _button_container: VBoxContainer
var _load_button: Button
var _restart_button: Button
var _quit_button: Button

# =============================================================================
# STATE
# =============================================================================

var _has_saves: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	hide()


func _create_ui() -> void:
	# Full screen
	#set_anchors_preset(Control.PRESET_FULL_RECT)
	set_anchors_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Dark red overlay
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.08, 0.02, 0.02, 0.9)
	add_child(_overlay)
	
	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(550, 400)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.06, 0.06, 0.95)
	panel_style.set_corner_radius_all(16)
	panel_style.set_content_margin_all(36)
	panel_style.border_width_bottom = 3
	panel_style.border_width_top = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = Color(0.5, 0.2, 0.2)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)
	
	# Main layout
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(_vbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "DEFEATED"
	_title_label.add_theme_font_size_override("font_size", 52)
	_title_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_label)
	
	# Cause of death
	_cause_label = Label.new()
	_cause_label.text = "You fell in battle."
	_cause_label.add_theme_font_size_override("font_size", 24)
	_cause_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.6))
	_cause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_cause_label)
	
	# Stats summary
	_stats_label = Label.new()
	_stats_label.text = ""
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_stats_label)
	
	# Separator
	var sep := HSeparator.new()
	_vbox.add_child(sep)
	
	# Button container
	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 12)
	_vbox.add_child(_button_container)
	
	# Center buttons
	var btn_center := CenterContainer.new()
	_button_container.add_child(btn_center)
	
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 12)
	btn_center.add_child(btn_vbox)
	
	# Load save button
	_load_button = _create_button("Load Last Save", btn_vbox)
	_load_button.pressed.connect(_on_load_pressed)
	
	# Restart button
	_restart_button = _create_button("Start New Game", btn_vbox)
	_restart_button.pressed.connect(_on_restart_pressed)
	
	# Quit button
	_quit_button = _create_button("Quit to Desktop", btn_vbox)
	_quit_button.pressed.connect(_on_quit_pressed)
	
	# Style quit button differently
	var quit_style := StyleBoxFlat.new()
	quit_style.bg_color = Color(0.3, 0.2, 0.2)
	quit_style.set_corner_radius_all(8)
	quit_style.set_content_margin_all(12)
	_quit_button.add_theme_stylebox_override("normal", quit_style)


func _create_button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 50)
	button.add_theme_font_size_override("font_size", 20)
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.22, 0.22)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(12)
	button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.35, 0.30, 0.30)
	button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed := btn_style.duplicate()
	btn_pressed.bg_color = Color(0.2, 0.18, 0.18)
	button.add_theme_stylebox_override("pressed", btn_pressed)
	
	parent.add_child(button)
	return button

# =============================================================================
# PUBLIC API
# =============================================================================

## Show the defeat screen.
## @param enemy_name: Name of enemy that killed the player (optional).
## @param stats: Dictionary with game stats like days survived, hexes explored.
func show_defeat(enemy_name: String = "", stats: Dictionary = {}) -> void:
	# Set cause text
	if enemy_name != "":
		_cause_label.text = "You were slain by %s.\nYour journey ends here." % enemy_name
	else:
		_cause_label.text = "You fell in battle.\nThe frontier claims another soul."
	
	# Set stats
	if not stats.is_empty():
		var stats_text := ""
		if stats.has("days"):
			stats_text += "Days survived: %d" % stats["days"]
		if stats.has("explored"):
			if stats_text != "":
				stats_text += "  |  "
			stats_text += "Hexes explored: %d" % stats["explored"]
		if stats.has("enemies_defeated"):
			if stats_text != "":
				stats_text += "  |  "
			stats_text += "Enemies defeated: %d" % stats["enemies_defeated"]
		
		_stats_label.text = stats_text
		_stats_label.visible = stats_text != ""
	else:
		_stats_label.visible = false
	
	# Check for saves
	_check_for_saves()
	
	# Show with animation
	show()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# Focus appropriate button
	await tween.finished
	if _has_saves:
		_load_button.grab_focus()
	else:
		_restart_button.grab_focus()


## Hide the defeat screen.
func hide_defeat() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	hide()


func _check_for_saves() -> void:
	# Check if any save files exist
	var dir := DirAccess.open("user://saves/maps/")
	_has_saves = false
	
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				_has_saves = true
				break
			file_name = dir.get_next()
		dir.list_dir_end()
	
	_load_button.visible = _has_saves
	_load_button.disabled = not _has_saves

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_load_pressed() -> void:
	load_save_requested.emit()
	hide_defeat()


func _on_restart_pressed() -> void:
	restart_requested.emit()
	hide_defeat()


func _on_quit_pressed() -> void:
	quit_requested.emit()
	get_tree().quit()

# =============================================================================
# INPUT
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Block all input while visible
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
