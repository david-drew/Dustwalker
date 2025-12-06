# character_creation_screen.gd
# UI screen for creating a new character.
# Integrates with CharacterCreator for data management.
#
# REQUIRED SCENE STRUCTURE (character_creation_screen.tscn):
# CharacterCreationScreen (Control) - this script
# ├── Background (ColorRect)
# └── MarginContainer
#     └── MainVBox (VBoxContainer)
#         ├── Title (Label)
#         ├── ContentHBox (HBoxContainer)
#         │   ├── LeftPanel (PanelContainer)
#         │   │   └── LeftMargin (MarginContainer)
#         │   │       └── LeftVBox (VBoxContainer)
#         │   │           ├── BackgroundsLabel (Label)
#         │   │           └── BackgroundScroll (ScrollContainer)
#         │   │               └── BackgroundList (VBoxContainer) <- backgrounds added here
#         │   └── RightPanel (VBoxContainer)
#         │       ├── NameRow (HBoxContainer)
#         │       │   ├── NameLabel (Label)
#         │       │   └── NameInput (LineEdit)
#         │       └── PreviewPanel (PanelContainer)
#         │           └── PreviewMargin (MarginContainer)
#         │               └── PreviewScroll (ScrollContainer)
#         │                   └── PreviewVBox (VBoxContainer)
#         │                       ├── StatsLabel (Label)
#         │                       ├── StatsGrid (GridContainer) <- stat controls here
#         │                       ├── PointsLabel (Label)
#         │                       ├── SkillsLabel (Label)
#         │                       ├── SkillsList (VBoxContainer) <- skills here
#         │                       ├── TalentLabel (Label)
#         │                       ├── TalentDescription (Label)
#         │                       ├── DescriptionLabel (Label)
#         │                       └── BackgroundDescription (Label)
#         └── ButtonRow (HBoxContainer)
#             ├── BackButton (Button)
#             └── ConfirmButton (Button)

extends Control
class_name CharacterCreationScreen

# =============================================================================
# SIGNALS
# =============================================================================

signal creation_complete(character_data: Dictionary)
signal creation_cancelled()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _left_panel: PanelContainer = $MarginContainer/MainVBox/ContentHBox/LeftPanel
@onready var _right_panel: PanelContainer = $MarginContainer/MainVBox/ContentHBox/RightPanel/PreviewPanel
@onready var _background_list: VBoxContainer = $MarginContainer/MainVBox/ContentHBox/LeftPanel/LeftMargin/LeftVBox/BackgroundScroll/BackgroundList
@onready var _name_input: LineEdit = $MarginContainer/MainVBox/ContentHBox/RightPanel/NameRow/NameInput
@onready var _stats_grid: GridContainer = $MarginContainer/MainVBox/ContentHBox/RightPanel/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/StatsGrid
@onready var _points_label: Label = $MarginContainer/MainVBox/ContentHBox/RightPanel/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/PointsLabel
@onready var _skills_list: VBoxContainer = $MarginContainer/MainVBox/ContentHBox/RightPanel/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/SkillsList
@onready var _talent_description: Label = $MarginContainer/MainVBox/ContentHBox/RightPanel/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/TalentDescription
@onready var _background_description: Label = $MarginContainer/MainVBox/ContentHBox/RightPanel/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/BackgroundDescription
@onready var _back_button: Button = $MarginContainer/MainVBox/ButtonRow/BackButton
@onready var _confirm_button: Button = $MarginContainer/MainVBox/ButtonRow/ConfirmButton

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var panel_color: Color = Color(0.18, 0.15, 0.12, 0.95)
@export var title_color: Color = Color(0.85, 0.75, 0.55)
@export var text_color: Color = Color(0.9, 0.85, 0.7)
@export var muted_color: Color = Color(0.6, 0.55, 0.45)

# =============================================================================
# STATE
# =============================================================================

var _character_creator: Node = null
var _selected_background_id: String = ""
var _selected_background_button: Button = null
var _stat_controls: Dictionary = {}  # {stat_name: {up: Button, down: Button, label: Label}}

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_find_character_creator()
	_connect_controls()
	_style_panels()
	_style_buttons()
	_populate_backgrounds()


func _find_character_creator() -> void:
	_character_creator = get_tree().get_first_node_in_group("character_creator")
	
	if not _character_creator:
		var CreatorClass = load("res://scripts/actors/character_creator.gd")
		if CreatorClass:
			_character_creator = CreatorClass.new()
			_character_creator.name = "CharacterCreator"
			add_child(_character_creator)
			print("CharacterCreationScreen: Created CharacterCreator")


func _connect_controls() -> void:
	if _name_input:
		_name_input.text_changed.connect(_on_name_changed)
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)
	if _confirm_button:
		_confirm_button.pressed.connect(_on_confirm_pressed)
	
	if _character_creator:
		if _character_creator.has_signal("background_selected"):
			_character_creator.background_selected.connect(_on_background_selected_signal)
		if _character_creator.has_signal("stats_customized"):
			_character_creator.stats_customized.connect(_on_stats_customized)


func _style_panels() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.set_corner_radius_all(8)
	
	if _left_panel:
		_left_panel.add_theme_stylebox_override("panel", style)
	if _right_panel:
		_right_panel.add_theme_stylebox_override("panel", style.duplicate())


func _style_buttons() -> void:
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.4, 0.35, 0.28)
	back_style.set_border_width_all(2)
	back_style.border_color = Color(0.5, 0.45, 0.35)
	back_style.set_corner_radius_all(4)
	
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = title_color.darkened(0.4)
	confirm_style.set_border_width_all(2)
	confirm_style.border_color = title_color.darkened(0.2)
	confirm_style.set_corner_radius_all(4)
	
	var hover := back_style.duplicate()
	hover.bg_color = Color(0.5, 0.45, 0.35)
	
	var confirm_hover := confirm_style.duplicate()
	confirm_hover.bg_color = title_color.darkened(0.25)
	
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.25, 0.22, 0.18)
	disabled_style.set_border_width_all(2)
	disabled_style.border_color = Color(0.35, 0.32, 0.25)
	disabled_style.set_corner_radius_all(4)
	
	if _back_button:
		_back_button.add_theme_stylebox_override("normal", back_style)
		_back_button.add_theme_stylebox_override("hover", hover)
		_back_button.add_theme_stylebox_override("pressed", back_style)
		_back_button.add_theme_color_override("font_color", text_color)
	
	if _confirm_button:
		_confirm_button.add_theme_stylebox_override("normal", confirm_style)
		_confirm_button.add_theme_stylebox_override("hover", confirm_hover)
		_confirm_button.add_theme_stylebox_override("pressed", confirm_style)
		_confirm_button.add_theme_stylebox_override("disabled", disabled_style)
		_confirm_button.add_theme_color_override("font_color", text_color)
		_confirm_button.add_theme_color_override("font_disabled_color", muted_color)

# =============================================================================
# BACKGROUND POPULATION
# =============================================================================

func _populate_backgrounds() -> void:
	if not _background_list:
		return
	
	# Clear existing
	for child in _background_list.get_children():
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
	var bg_name: String = bg.get("name", "Unknown")
	var difficulty: String = bg.get("difficulty", "normal")
	button.text = "%s\n%s" % [bg_name, _get_difficulty_text(difficulty)]
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
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", text_color)
	
	var bg_id: String = bg.get("id", "")
	button.set_meta("background_id", bg_id)
	button.pressed.connect(_on_background_button_pressed.bind(button, bg_id))
	
	return button


func _get_difficulty_text(difficulty: String) -> String:
	match difficulty:
		"easy": return "★ Easy"
		"normal": return "★★ Normal"
		"hard": return "★★★ Hard"
		_: return "★★ Normal"

# =============================================================================
# BACKGROUND SELECTION
# =============================================================================

func _on_background_button_pressed(button: Button, bg_id: String) -> void:
	# Update visual selection
	if _selected_background_button:
		_reset_button_style(_selected_background_button)
	
	_selected_background_button = button
	_selected_background_id = bg_id
	
	# Apply selected style
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = title_color.darkened(0.6)
	selected_style.set_border_width_all(2)
	selected_style.border_color = title_color
	selected_style.set_corner_radius_all(4)
	selected_style.content_margin_left = 10
	selected_style.content_margin_right = 10
	button.add_theme_stylebox_override("normal", selected_style)
	button.add_theme_stylebox_override("hover", selected_style)
	
	# Tell CharacterCreator
	if _character_creator and _character_creator.has_method("select_background"):
		_character_creator.select_background(bg_id)


func _reset_button_style(button: Button) -> void:
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
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)


func _on_background_selected_signal(background_id: String, background_data: Dictionary) -> void:
	_update_preview(background_data)
	_update_confirm_button()

# =============================================================================
# PREVIEW UPDATES
# =============================================================================

func _update_preview(bg_data: Dictionary) -> void:
	var stats: Dictionary = bg_data.get("stats", {})
	_populate_stat_controls(stats)
	_update_points_label()
	_update_skill_display(bg_data.get("skills", {}))
	_update_talent_display(bg_data.get("starting_talent", ""))
	_update_background_description(bg_data.get("backstory", ""), bg_data.get("playstyle", ""))


func _populate_stat_controls(stats: Dictionary) -> void:
	if not _stats_grid:
		return
	
	# Clear existing
	for child in _stats_grid.get_children():
		child.queue_free()
	_stat_controls.clear()
	
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
		_stats_grid.add_child(name_label)
		
		# Decrease button
		var down_btn := Button.new()
		down_btn.text = "-"
		down_btn.custom_minimum_size = Vector2(30, 30)
		down_btn.pressed.connect(_on_stat_decrease.bind(stat_name))
		_stats_grid.add_child(down_btn)
		
		# Value label
		var value_label := Label.new()
		value_label.text = str(stats[stat_name])
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.custom_minimum_size.x = 30
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", title_color)
		_stats_grid.add_child(value_label)
		
		# Increase button
		var up_btn := Button.new()
		up_btn.text = "+"
		up_btn.custom_minimum_size = Vector2(30, 30)
		up_btn.pressed.connect(_on_stat_increase.bind(stat_name))
		_stats_grid.add_child(up_btn)
		
		_stat_controls[stat_name] = {
			"up": up_btn,
			"down": down_btn,
			"label": value_label
		}


func _on_stats_customized(stats: Dictionary) -> void:
	for stat_name in _stat_controls:
		if stats.has(stat_name):
			_stat_controls[stat_name]["label"].text = str(stats[stat_name])
	_update_points_label()


func _update_points_label() -> void:
	if not _points_label or not _character_creator:
		return
	
	var remaining := 0
	if _character_creator.has_method("get_remaining_stat_points"):
		remaining = _character_creator.get_remaining_stat_points()
	
	_points_label.text = "Remaining Points: %d" % remaining
	_points_label.add_theme_color_override("font_color", title_color if remaining > 0 else muted_color)


func _update_skill_display(skills: Dictionary) -> void:
	if not _skills_list:
		return
	
	for child in _skills_list.get_children():
		child.queue_free()
	
	if skills.is_empty():
		var none_label := Label.new()
		none_label.text = "(None)"
		none_label.add_theme_color_override("font_color", muted_color)
		_skills_list.add_child(none_label)
		return
	
	for skill_name in skills:
		var label := Label.new()
		label.text = "• %s: Level %d" % [skill_name.capitalize().replace("_", " "), skills[skill_name]]
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", text_color)
		_skills_list.add_child(label)


func _update_talent_display(talent_id: String) -> void:
	if not _talent_description:
		return
	
	if talent_id.is_empty():
		_talent_description.text = "(None)"
		return
	
	# Try to get talent info from EffectManager
	var effect_manager = get_tree().get_first_node_in_group("effect_manager")
	if effect_manager and effect_manager.has_method("get_effect_definition"):
		var talent_def: Dictionary = effect_manager.get_effect_definition(talent_id)
		if not talent_def.is_empty():
			_talent_description.text = "%s: %s" % [
				talent_def.get("name", talent_id),
				talent_def.get("description", "")
			]
			return
	
	# Fallback
	_talent_description.text = talent_id.capitalize().replace("_", " ")


func _update_background_description(backstory: String, playstyle: String) -> void:
	if not _background_description:
		return
	
	var text := ""
	if not backstory.is_empty():
		text = backstory
	if not playstyle.is_empty():
		if not text.is_empty():
			text += "\n\n"
		text += "Playstyle: " + playstyle
	
	if text.is_empty():
		text = "(Select a background to see description)"
	
	_background_description.text = text

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
# NAME INPUT
# =============================================================================

func _on_name_changed(new_name: String) -> void:
	print("Name changed to: ", new_name)	# TODO DEBUG DELETE
	if _character_creator and _character_creator.has_method("set_character_name"):
		_character_creator.set_character_name(new_name)
	_update_confirm_button()

# =============================================================================
# VALIDATION
# =============================================================================

func _update_confirm_button() -> void:
	if not _confirm_button:
		return
	
	var can_confirm := false
	
	if _character_creator:
		var has_background := not _selected_background_id.is_empty()
		var has_name := not _name_input.text.strip_edges().is_empty()
		can_confirm = has_background and has_name
	
	_confirm_button.disabled = not can_confirm

# =============================================================================
# ACTIONS
# =============================================================================

func _on_back_pressed() -> void:
	print("CharacterCreationScreen: Back pressed")
	creation_cancelled.emit()
	_emit_to_event_bus("character_creation_cancelled", [])


func _on_confirm_pressed() -> void:
	print("Confirm pressed!") 		# TODO DEBUG DELETE
	if not _character_creator:
		print("No character creator")
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
	_selected_background_id = ""
	_selected_background_button = null
	
	if _name_input:
		_name_input.text = ""
	
	# Clear stat controls
	if _stats_grid:
		for child in _stats_grid.get_children():
			child.queue_free()
	_stat_controls.clear()
	
	# Clear skills
	if _skills_list:
		for child in _skills_list.get_children():
			child.queue_free()
	
	# Reset labels
	if _talent_description:
		_talent_description.text = "(Select a background)"
	if _background_description:
		_background_description.text = "(Select a background to see description)"
	if _points_label:
		_points_label.text = "Remaining Points: 0"
	if _confirm_button:
		_confirm_button.disabled = true
	
	# Repopulate backgrounds
	_populate_backgrounds()

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
