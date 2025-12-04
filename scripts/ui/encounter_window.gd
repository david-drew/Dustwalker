# encounter_window.gd
# Modal popup window for displaying encounters and handling player choices.
# Blocks game interaction while open.
#
# VISUAL STRUCTURE:
# - Darkened background overlay
# - Centered panel with title, description, choices
# - Outcome display after choice made
# - Continue button to close

extends Control
class_name EncounterWindow

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when player selects a choice.
signal choice_selected(choice_index: int)

## Emitted when player clicks continue after outcome.
signal encounter_continued()

# =============================================================================
# CONFIGURATION
# =============================================================================

## Background overlay color.
@export var overlay_color: Color = Color(0, 0, 0, 0.75)

## Panel background color.
@export var panel_color: Color = Color(0.12, 0.12, 0.15, 0.98)

## Title text color.
@export var title_color: Color = Color(0.95, 0.85, 0.5)

## Description text color.
@export var description_color: Color = Color(0.85, 0.85, 0.85)

## Outcome text color.
@export var outcome_color: Color = Color(0.7, 0.9, 0.7)

## Category colors.
var category_colors: Dictionary = {
	"hostile": Color(0.9, 0.4, 0.4),
	"neutral": Color(0.5, 0.7, 0.9),
	"discovery": Color(0.9, 0.8, 0.4),
	"environmental": Color(0.6, 0.8, 0.6)
}

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _overlay: ColorRect
var _panel: PanelContainer
var _vbox: VBoxContainer
var _category_label: Label
var _title_label: Label
var _description_label: RichTextLabel
var _choices_container: VBoxContainer
var _outcome_container: VBoxContainer
var _outcome_label: RichTextLabel
var _effects_label: Label
var _continue_button: Button

var _choice_buttons: Array[Button] = []

# =============================================================================
# STATE
# =============================================================================

## Current encounter data.
var _current_encounter: Dictionary = {}

## Currently available choices.
var _available_choices: Array = []

## Whether showing outcome (vs choices).
var _showing_outcome: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	hide()


func _create_ui() -> void:
	# Ensure full screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks
	
	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = overlay_color
	add_child(_overlay)
	
	# Center container for panel
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(800, 450)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel_color
	panel_style.set_corner_radius_all(16)
	panel_style.set_content_margin_all(36)
	panel_style.border_width_bottom = 3
	panel_style.border_width_top = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = Color(0.4, 0.35, 0.25)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)
	
	# Main vertical layout
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(_vbox)
	
	# Category label
	_category_label = Label.new()
	_category_label.name = "CategoryLabel"
	_category_label.text = "HOSTILE ENCOUNTER"
	_category_label.add_theme_font_size_override("font_size", 24)
	_category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_category_label)
	
	# Title
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "Encounter Title"
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.add_theme_color_override("font_color", title_color)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_label)
	
	# Separator
	var sep := HSeparator.new()
	_vbox.add_child(sep)
	
	# Description (RichTextLabel for better text wrapping)
	_description_label = RichTextLabel.new()
	_description_label.name = "DescriptionLabel"
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.scroll_active = false
	_description_label.custom_minimum_size = Vector2(720, 80)
	_description_label.add_theme_font_size_override("normal_font_size", 26)
	_description_label.add_theme_color_override("default_color", description_color)
	_vbox.add_child(_description_label)
	
	# Choices container
	_choices_container = VBoxContainer.new()
	_choices_container.name = "ChoicesContainer"
	_choices_container.add_theme_constant_override("separation", 12)
	_vbox.add_child(_choices_container)
	
	# Outcome container (hidden initially)
	_outcome_container = VBoxContainer.new()
	_outcome_container.name = "OutcomeContainer"
	_outcome_container.add_theme_constant_override("separation", 16)
	_outcome_container.visible = false
	_vbox.add_child(_outcome_container)
	
	# Outcome separator
	var out_sep := HSeparator.new()
	_outcome_container.add_child(out_sep)
	
	# Outcome label
	_outcome_label = RichTextLabel.new()
	_outcome_label.name = "OutcomeLabel"
	_outcome_label.bbcode_enabled = true
	_outcome_label.fit_content = true
	_outcome_label.scroll_active = false
	_outcome_label.custom_minimum_size = Vector2(720, 60)
	_outcome_label.add_theme_font_size_override("normal_font_size", 26)
	_outcome_label.add_theme_color_override("default_color", outcome_color)
	_outcome_container.add_child(_outcome_label)
	
	# Effects label
	_effects_label = Label.new()
	_effects_label.name = "EffectsLabel"
	_effects_label.text = ""
	_effects_label.add_theme_font_size_override("font_size", 24)
	_effects_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_container.add_child(_effects_label)
	
	# Continue button
	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(280, 56)
	_continue_button.add_theme_font_size_override("font_size", 24)
	_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.visible = false
	_outcome_container.add_child(_continue_button)
	
	# Center the continue button
	var btn_container := CenterContainer.new()
	_outcome_container.remove_child(_continue_button)
	btn_container.add_child(_continue_button)
	_outcome_container.add_child(btn_container)
	
	# Style continue button
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.35, 0.25)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(12)
	_continue_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.3, 0.45, 0.3)
	_continue_button.add_theme_stylebox_override("hover", btn_hover)

# =============================================================================
# PUBLIC API
# =============================================================================

## Show an encounter with available choices.
func show_encounter(encounter: Dictionary, available_choices: Array) -> void:
	_current_encounter = encounter
	_available_choices = available_choices
	_showing_outcome = false
	
	# Set category label
	var category: String = encounter.get("category", "unknown")
	_category_label.text = category.to_upper() + " ENCOUNTER"
	_category_label.add_theme_color_override("font_color", category_colors.get(category, Color.WHITE))
	
	# Set title
	_title_label.text = encounter.get("title", "Unknown Encounter")
	
	# Set description
	_description_label.text = encounter.get("description", "")
	
	# Create choice buttons
	_create_choice_buttons(available_choices)
	
	# Show choices, hide outcome
	_choices_container.visible = true
	_outcome_container.visible = false
	_continue_button.visible = false
	
	# Show window
	show()
	
	# Animate in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


## Show the outcome after a choice was made.
func show_outcome(outcome_text: String, effects: Dictionary) -> void:
	_showing_outcome = true
	
	# Hide choices
	_choices_container.visible = false
	
	# Show outcome
	_outcome_label.text = outcome_text
	
	# Format effects
	_effects_label.text = _format_effects(effects)
	
	# Show outcome container and continue button
	_outcome_container.visible = true
	_continue_button.visible = true
	
	# Focus continue button
	_continue_button.grab_focus()


## Hide the encounter window.
func hide_encounter() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(hide)
	
	_current_encounter = {}
	_available_choices = []
	_clear_choice_buttons()

# =============================================================================
# CHOICE BUTTONS
# =============================================================================

func _create_choice_buttons(choices: Array) -> void:
	_clear_choice_buttons()
	
	for choice_data in choices:
		var button := Button.new()
		button.text = choice_data.get("text", "...")
		button.custom_minimum_size = Vector2(600, 52)
		button.add_theme_font_size_override("font_size", 24)
		
		var index: int = choice_data.get("index", 0)
		button.pressed.connect(_on_choice_button_pressed.bind(index))
		
		# Style button
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.2, 0.25)
		btn_style.set_corner_radius_all(6)
		btn_style.set_content_margin_all(12)
		button.add_theme_stylebox_override("normal", btn_style)
		
		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = Color(0.3, 0.3, 0.4)
		button.add_theme_stylebox_override("hover", btn_hover)
		
		var btn_pressed := btn_style.duplicate()
		btn_pressed.bg_color = Color(0.15, 0.15, 0.2)
		button.add_theme_stylebox_override("pressed", btn_pressed)
		
		_choices_container.add_child(button)
		_choice_buttons.append(button)
	
	# Focus first button
	if _choice_buttons.size() > 0:
		_choice_buttons[0].grab_focus()


func _clear_choice_buttons() -> void:
	for button in _choice_buttons:
		button.queue_free()
	_choice_buttons.clear()

# =============================================================================
# EFFECTS FORMATTING
# =============================================================================

func _format_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return ""
	
	var parts: Array[String] = []
	
	for key in effects:
		var value: int = effects[key]
		var text := ""
		
		match key:
			"health":
				text = "%+d Health" % value
			"hunger":
				text = "%+d Hunger" % value
			"thirst":
				text = "%+d Thirst" % value
			"rations":
				text = "%+d Rations" % value
			"water":
				text = "%+d Water" % value
			"turn_cost":
				text = "-%d Turn%s" % [value, "s" if value != 1 else ""]
		
		if text != "":
			parts.append(text)
	
	return " | ".join(parts)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_choice_button_pressed(choice_index: int) -> void:
	if _showing_outcome:
		return
	
	# Disable all buttons to prevent double-clicks
	for button in _choice_buttons:
		button.disabled = true
	
	choice_selected.emit(choice_index)


func _on_continue_pressed() -> void:
	encounter_continued.emit()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE:
			if _showing_outcome and _continue_button.visible:
				_on_continue_pressed()
				get_viewport().set_input_as_handled()
				return
		
		# Block escape and other keys from reaching game
		get_viewport().set_input_as_handled()
