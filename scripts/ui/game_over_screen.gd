# game_over_screen.gd
# Full-screen game over display shown when the player dies.
# Shows cause of death and options to load save or quit.

extends Control
class_name GameOverScreen

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

var _cause_of_death: String = ""
var _has_saves: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_signals()
	hide()


func _create_ui() -> void:
	# Full screen
	#set_anchors_preset(Control.PRESET_FULL_RECT)
	set_anchors_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.05, 0.02, 0.02, 0.9)
	add_child(_overlay)
	
	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(650, 450)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.08, 0.95)
	panel_style.set_corner_radius_all(16)
	panel_style.set_content_margin_all(40)
	panel_style.border_width_bottom = 3
	panel_style.border_width_top = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = Color(0.5, 0.2, 0.2)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)
	
	# Main layout
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 24)
	_panel.add_child(_vbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "YOU HAVE FALLEN"
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_label)
	
	# Cause of death
	_cause_label = Label.new()
	_cause_label.text = "You succumbed to your injuries."
	_cause_label.add_theme_font_size_override("font_size", 28)
	_cause_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.6))
	_cause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_cause_label)
	
	# Stats summary
	_stats_label = Label.new()
	_stats_label.text = ""
	_stats_label.add_theme_font_size_override("font_size", 24)
	_stats_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_stats_label)
	
	# Separator
	var sep := HSeparator.new()
	_vbox.add_child(sep)
	
	# Button container
	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 14)
	_vbox.add_child(_button_container)
	
	# Center buttons
	var btn_center := CenterContainer.new()
	_button_container.add_child(btn_center)
	
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 14)
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
	quit_style.set_content_margin_all(14)
	_quit_button.add_theme_stylebox_override("normal", quit_style)


func _create_button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 56)
	button.add_theme_font_size_override("font_size", 24)
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.25, 0.3)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(14)
	button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.35, 0.35, 0.45)
	button.add_theme_stylebox_override("hover", btn_hover)
	
	parent.add_child(button)
	return button


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("player_died"):
			event_bus.player_died.connect(_on_player_died)

# =============================================================================
# PUBLIC API
# =============================================================================

## Show the game over screen with cause of death.
func show_game_over(cause: String, stats: Dictionary = {}) -> void:
	_cause_of_death = cause
	
	# Set cause text
	match cause:
		"starvation":
			_cause_label.text = "You succumbed to starvation.\nThe wilderness claimed another soul."
		"dehydration":
			_cause_label.text = "You died of thirst.\nWater was your greatest need."
		"injuries":
			_cause_label.text = "Your wounds proved fatal.\nThe journey has ended."
		_:
			_cause_label.text = "You have fallen.\nYour journey ends here."
	
	# Set stats
	if not stats.is_empty():
		var stats_text := "Days survived: %d | Hexes explored: %d" % [
			stats.get("days", 0),
			stats.get("explored", 0)
		]
		_stats_label.text = stats_text
		_stats_label.visible = true
	else:
		_stats_label.visible = false
	
	# Check for saves
	_check_for_saves()
	
	# Show screen
	show()
	
	# Animate in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# Focus load button if available, otherwise restart
	if _has_saves:
		_load_button.grab_focus()
	else:
		_restart_button.grab_focus()


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

func _on_player_died(cause: String) -> void:
	# Gather stats
	var stats := {}
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		stats["days"] = time_manager.current_day
	
	var fog_manager = get_tree().get_first_node_in_group("fog_manager")
	if fog_manager:
		stats["explored"] = fog_manager.get_explored_count()
	
	show_game_over(cause, stats)


func _on_load_pressed() -> void:
	hide()
	load_save_requested.emit()


func _on_restart_pressed() -> void:
	hide()
	restart_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
	get_tree().quit()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Block all input
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
