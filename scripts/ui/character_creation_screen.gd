# character_creation_screen.gd
# UI screen for creating a new character.
# Integrates with CharacterCreator for data management.
#
# FLOW:
# 1. Select background (shows preview)
# 2. Optionally customize stats
# 3. Enter name
# 4. Confirm and start game

extends Control
class_name CharacterCreationScreen

# =============================================================================
# SIGNALS
# =============================================================================

signal creation_complete(character_data: Dictionary)
signal creation_cancelled()

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var bg_color: Color = Color(0.12, 0.10, 0.08)
@export var panel_color: Color = Color(0.18, 0.15, 0.12, 0.95)
@export var title_color: Color = Color(0.85, 0.75, 0.55)
@export var text_color: Color = Color(0.9, 0.85, 0.7)
@export var muted_color: Color = Color(0.6, 0.55, 0.45)

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _background: ColorRect
var _main_container: HBoxContainer
var _left_panel: VBoxContainer  # Background selection
var _right_panel: VBoxContainer  # Preview and customization
var _background_list: VBoxContainer
var _preview_panel: PanelContainer
var _name_input: LineEdit
var _stat_container: GridContainer
var _skill_container: VBoxContainer
var _talent_label: Label
var _confirm_button: Button
var _back_button: Button
var _stat_buttons: Dictionary = {}  # {stat_name: {up: Button, down: Button, label: Label}}

# =============================================================================
# STATE
# =============================================================================

var _character_creator: Node = null
var _selected_background_button: Button = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_find_character_creator()
	_create_ui()
	_connect_signals()
	_populate_backgrounds()


func _find_character_creator() -> void:
	# First try to find existing
	_character_creator = get_tree().get_first_node_in_group("character_creator")
	
	# If not found, create one
	if not _character_creator:
		var CreatorClass = load("res://scripts/player/character_creator.gd")
		if CreatorClass:
			_character_creator = CreatorClass.new()
			_character_creator.name = "CharacterCreator"
			add_child(_character_creator)
			print("CharacterCreationScreen: Created CharacterCreator")


func _create_ui() -> void:
	# Background
	_background = ColorRect.new()
	_background.color = bg_color
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	
	# Main margin container
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	
	# Main vertical layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "CREATE YOUR CHARACTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", title_color)
	vbox.add_child(title)
	
	# Main content (two columns)
	_main_container = HBoxContainer.new()
	_main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_container.add_theme_constant_override("separation", 30)
	vbox.add_child(_main_container)
	
	# Left panel - Background selection
	_create_left_panel()
	
	# Right panel - Preview and customization
	_create_right_panel()
	
	# Bottom buttons
	_create_bottom_buttons(vbox)


func _create_left_panel() -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.4
	_main_container.add_child(panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.set_corner_radius_all(8)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	
	_left_panel = VBoxContainer.new()
	_left_panel.add_theme_constant_override("separation", 8)
	scroll.add_child(_left_panel)
	
	# Section title
	var section_title := Label.new()
	section_title.text = "Choose Your Background"
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", title_color)
	_left_panel.add_child(section_title)
	
	# Background list container
	_background_list = VBoxContainer.new()
	_background_list.add_theme_constant_override("separation", 6)
	_left_panel.add_child(_background_list)


func _create_right_panel() -> void:
	_right_panel = VBoxContainer.new()
	_right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel.size_flags_stretch_ratio = 0.6
	_right_panel.add_theme_constant_override("separation", 15)
	_main_container.add_child(_right_panel)
	
	# Name input row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	_right_panel.add_child(name_row)
	
	var name_label := Label.new()
	name_label.text = "Name:"
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", text_color)
	name_row.add_child(name_label)
	
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter character name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.add_theme_font_size_override("font_size", 18)
	name_row.add_child(_name_input)
	
	# Preview panel
	_preview_panel = PanelContainer.new()
	_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_panel.add_child(_preview_panel)
	
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = panel_color
	preview_style.set_corner_radius_all(8)
	preview_style.content_margin_left = 20
	preview_style.content_margin_right = 20
	preview_style.content_margin_top = 15
	preview_style.content_margin_bottom = 15
	_preview_panel.add_theme_stylebox_override("panel", preview_style)
	
	var preview_scroll := ScrollContainer.new()
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_preview_panel.add_child(preview_scroll)
	
	var preview_vbox := VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 12)
	preview_scroll.add_child(preview_vbox)
	
	# Stats section
	var stats_title := Label.new()
	stats_title.text = "Stats (Click +/- to adjust)"
	stats_title.add_theme_font_size_override("font_size", 18)
	stats_title.add_theme_color_override("font_color", title_color)
	preview_vbox.add_child(stats_title)
	
	_stat_container = GridContainer.new()
	_stat_container.columns = 4  # Name, -, Value, +
	_stat_container.add_theme_constant_override("h_separation", 8)
	_stat_container.add_theme_constant_override("v_separation", 4)
	preview_vbox.add_child(_stat_container)
	
	# Remaining points label
	var points_label := Label.new()
	points_label.name = "PointsLabel"
	points_label.text = "Remaining Points: 0"
	points_label.add_theme_font_size_override("font_size", 14)
	points_label.add_theme_color_override("font_color", muted_color)
	preview_vbox.add_child(points_label)
	
	# Skills section
	var skills_title := Label.new()
	skills_title.text = "Starting Skills"
	skills_title.add_theme_font_size_override("font_size", 18)
	skills_title.add_theme_color_override("font_color", title_color)
	preview_vbox.add_child(skills_title)
	
	_skill_container = VBoxContainer.new()
	_skill_container.add_theme_constant_override("separation", 4)
	preview_vbox.add_child(_skill_container)
	
	# Talent section
	var talent_title := Label.new()
	talent_title.text = "Starting Talent"
	talent_title.add_theme_font_size_override("font_size", 18)
	talent_title.add_theme_color_override("font_color", title_color)
	preview_vbox.add_child(talent_title)
	
	_talent_label = Label.new()
	_talent_label.text = "(Select a background)"
	_talent_label.add_theme_font_size_override("font_size", 16)
	_talent_label.add_theme_color_override("font_color", text_color)
	_talent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_vbox.add_child(_talent_label)


func _create_bottom_buttons(parent: VBoxContainer) -> void:
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 20)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(button_row)
	
	_back_button = _create_button("Back", Color(0.5, 0.4, 0.35))
	button_row.add_child(_back_button)
	
	_confirm_button = _create_button("Begin Journey", title_color.darkened(0.3))
	_confirm_button.disabled = true
	button_row.add_child(_confirm_button)


func _create_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 45)
	
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(2)
	style.border_color = color.lightened(0.2)
	style.set_corner_radius_all(4)
	
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.1)
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", text_color)
	
	return button


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_name_input.text_changed.connect(_on_name_changed)
	
	if _character_creator:
		if _character_creator.has_signal("background_selected"):
			_character_creator.background_selected.connect(_on_background_selected)
		if _character_creator.has_signal("stats_customized"):
			_character_creator.stats_customized.connect(_on_stats_customized)

# =============================================================================
# BACKGROUND POPULATION
# =============================================================================

func _populate_backgrounds() -> void:
	# Clear existing
	for child in _background_list.get_children():
		if child is Button:
			child.queue_free()
	
	if not _character_creator:
		return
	
	var backgrounds: Array = []
	if _character_creator.has_method("get_all_backgrounds"):
		backgrounds = _character_creator.get_all_backgrounds()
	
	for bg in backgrounds:
		var button := _create_background_button(bg)
		_background_list.add_child(button)


func _create_background_button(bg: Dictionary) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [bg.get("name", "Unknown"), _get_difficulty_text(bg.get("difficulty", "normal"))]
	button.custom_minimum_size = Vector2(0, 60)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.18, 0.15)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.28, 0.22)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	
	var hover := style.duplicate()
	hover.bg_color = Color(0.28, 0.25, 0.2)
	hover.border_color = title_color.darkened(0.2)
	
	var selected := style.duplicate()
	selected.bg_color = title_color.darkened(0.6)
	selected.border_color = title_color
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", text_color)
	
	# Store background ID
	button.set_meta("background_id", bg.get("id", ""))
	button.pressed.connect(_on_background_button_pressed.bind(button))
	
	return button


func _get_difficulty_text(difficulty: String) -> String:
	match difficulty:
		"easy": return "★ Easy"
		"normal": return "★★ Normal"
		"hard": return "★★★ Hard"
		_: return "★★ Normal"

# =============================================================================
# UI UPDATES
# =============================================================================

func _on_background_button_pressed(button: Button) -> void:
	var bg_id: String = button.get_meta("background_id", "")
	if bg_id.is_empty():
		return
	
	# Update selection visual
	if _selected_background_button:
		# Reset previous
		var old_style: StyleBox = _selected_background_button.get_theme_stylebox("normal")
		_selected_background_button.add_theme_stylebox_override("normal", old_style)
	
	_selected_background_button = button
	
	# Apply selected style
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = title_color.darkened(0.6)
	selected_style.set_border_width_all(2)
	selected_style.border_color = title_color
	selected_style.set_corner_radius_all(4)
	selected_style.content_margin_left = 10
	selected_style.content_margin_right = 10
	button.add_theme_stylebox_override("normal", selected_style)
	
	# Tell CharacterCreator
	if _character_creator and _character_creator.has_method("select_background"):
		_character_creator.select_background(bg_id)


func _on_background_selected(background_id: String, background_data: Dictionary) -> void:
	_update_preview(background_data)
	_update_confirm_button()


func _on_stats_customized(stats: Dictionary) -> void:
	_update_stat_display(stats)
	_update_points_label()


func _on_name_changed(new_name: String) -> void:
	if _character_creator and _character_creator.has_method("set_character_name"):
		_character_creator.set_character_name(new_name)
	_update_confirm_button()


func _update_preview(bg_data: Dictionary) -> void:
	# Update stats
	var stats: Dictionary = bg_data.get("stats", {})
	_populate_stat_controls(stats)
	_update_stat_display(stats)
	_update_points_label()
	
	# Update skills
	_update_skill_display(bg_data.get("skills", {}))
	
	# Update talent
	_update_talent_display(bg_data.get("starting_talent", ""))


func _populate_stat_controls(stats: Dictionary) -> void:
	# Clear existing
	for child in _stat_container.get_children():
		child.queue_free()
	_stat_buttons.clear()
	
	var stat_order := ["grit", "reflex", "aim", "wit", "charm", "fortitude", "stealth", "spirit"]
	
	for stat_name in stat_order:
		if not stats.has(stat_name):
			continue
		
		# Stat name label
		var name_label := Label.new()
		name_label.text = stat_name.capitalize()
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", text_color)
		name_label.custom_minimum_size.x = 80
		_stat_container.add_child(name_label)
		
		# Decrease button
		var down_btn := Button.new()
		down_btn.text = "-"
		down_btn.custom_minimum_size = Vector2(30, 30)
		down_btn.pressed.connect(_on_stat_decrease.bind(stat_name))
		_stat_container.add_child(down_btn)
		
		# Value label
		var value_label := Label.new()
		value_label.text = str(stats[stat_name])
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.custom_minimum_size.x = 30
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", title_color)
		_stat_container.add_child(value_label)
		
		# Increase button
		var up_btn := Button.new()
		up_btn.text = "+"
		up_btn.custom_minimum_size = Vector2(30, 30)
		up_btn.pressed.connect(_on_stat_increase.bind(stat_name))
		_stat_container.add_child(up_btn)
		
		_stat_buttons[stat_name] = {
			"up": up_btn,
			"down": down_btn,
			"label": value_label
		}


func _update_stat_display(stats: Dictionary) -> void:
	for stat_name in _stat_buttons:
		if stats.has(stat_name):
			_stat_buttons[stat_name]["label"].text = str(stats[stat_name])


func _update_points_label() -> void:
	var points_label = _preview_panel.find_child("PointsLabel", true, false)
	if points_label and _character_creator and _character_creator.has_method("get_remaining_stat_points"):
		var remaining: int = _character_creator.get_remaining_stat_points()
		points_label.text = "Remaining Points: %d" % remaining
		points_label.add_theme_color_override("font_color", title_color if remaining > 0 else muted_color)


func _update_skill_display(skills: Dictionary) -> void:
	for child in _skill_container.get_children():
		child.queue_free()
	
	if skills.is_empty():
		var none_label := Label.new()
		none_label.text = "(None)"
		none_label.add_theme_color_override("font_color", muted_color)
		_skill_container.add_child(none_label)
		return
	
	for skill_name in skills:
		var label := Label.new()
		label.text = "• %s: Level %d" % [skill_name.capitalize(), skills[skill_name]]
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", text_color)
		_skill_container.add_child(label)


func _update_talent_display(talent_id: String) -> void:
	if talent_id.is_empty():
		_talent_label.text = "(None)"
		return
	
	# Try to get talent info from EffectManager
	var effect_manager = get_tree().get_first_node_in_group("effect_manager")
	if effect_manager and effect_manager.has_method("get_effect_definition"):
		var talent_def: Dictionary = effect_manager.get_effect_definition(talent_id)
		if not talent_def.is_empty():
			_talent_label.text = "%s: %s" % [
				talent_def.get("name", talent_id),
				talent_def.get("description", "")
			]
			return
	
	# Fallback
	_talent_label.text = talent_id.capitalize().replace("_", " ")


func _update_confirm_button() -> void:
	var can_confirm := false
	
	if _character_creator:
		# Check if background is selected
		var selected := {}
		if _character_creator.has_method("get_selected_background"):
			selected = _character_creator.get_selected_background()
		
		# Check if name is entered
		var char_name := ""
		if _character_creator.has_method("get_character_name"):
			char_name = _character_creator.get_character_name()
		
		can_confirm = not selected.is_empty() and not char_name.strip_edges().is_empty()
	
	_confirm_button.disabled = not can_confirm

# =============================================================================
# STAT MODIFICATION
# =============================================================================

func _on_stat_increase(stat_name: String) -> void:
	if _character_creator and _character_creator.has_method("increase_stat"):
		_character_creator.increase_stat(stat_name)


func _on_stat_decrease(stat_name: String) -> void:
	if _character_creator and _character_creator.has_method("decrease_stat"):
		_character_creator.decrease_stat(stat_name)

# =============================================================================
# ACTIONS
# =============================================================================

func _on_back_pressed() -> void:
	print("CharacterCreationScreen: Back pressed")
	creation_cancelled.emit()
	_emit_to_event_bus("character_creation_cancelled", [])


func _on_confirm_pressed() -> void:
	if not _character_creator:
		return
	
	# Validate
	if _character_creator.has_method("validate_character"):
		var validation: Dictionary = _character_creator.validate_character()
		if not validation.get("valid", false):
			print("CharacterCreationScreen: Validation failed - %s" % validation.get("errors", []))
			return
	
	# Create character
	if _character_creator.has_method("create_character"):
		if _character_creator.create_character():
			var char_data := {}
			if _character_creator.has_method("get_character_preview"):
				char_data = _character_creator.get_character_preview()
			
			print("CharacterCreationScreen: Character created")
			creation_complete.emit(char_data)
			_emit_to_event_bus("character_creation_complete", [char_data])


## Reset the screen for a new creation session.
func reset() -> void:
	_name_input.text = ""
	_selected_background_button = null
	
	if _character_creator:
		# Reset creator state
		pass
	
	_populate_backgrounds()
	
	# Clear preview
	for child in _stat_container.get_children():
		child.queue_free()
	for child in _skill_container.get_children():
		child.queue_free()
	_talent_label.text = "(Select a background)"
	_confirm_button.disabled = true

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
