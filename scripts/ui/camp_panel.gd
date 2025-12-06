# camp_panel.gd
# UI panel for making camp and sleeping.
# Shows sleep quality factors and allows player to rest for multiple turns.
#
# FEATURES:
# - Quality factor checkboxes (bedroll, campfire, shelter, etc.)
# - Estimated sleep quality display
# - Sleep duration selection (1-2 turns)
# - Random encounter chance during sleep
# - Results display after sleeping

extends Control
class_name CampPanel

# =============================================================================
# SIGNALS
# =============================================================================

signal camp_started(duration: int, quality_factors: Dictionary)
signal camp_completed(result: Dictionary)
signal camp_interrupted(reason: String)
signal panel_closed()

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var panel_color: Color = Color(0.1, 0.1, 0.12, 0.95)
@export var border_color: Color = Color(0.4, 0.35, 0.25)

## Chance of encounter per turn of sleep (0.0 - 1.0).
@export var encounter_chance_per_turn: float = 0.15

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _quality_container: VBoxContainer
var _quality_label: Label
var _quality_bar: ProgressBar
var _duration_container: HBoxContainer
var _duration_label: Label
var _duration_buttons: Array[Button] = []
var _warning_label: Label
var _sleep_button: Button
var _cancel_button: Button
var _results_container: VBoxContainer
var _results_label: Label
var _continue_button: Button

# Quality factor checkboxes
var _check_bedroll: CheckBox
var _check_campfire: CheckBox
var _check_shelter: CheckBox
var _check_safe_location: CheckBox

# =============================================================================
# STATE
# =============================================================================

var _survival_manager: SurvivalManager = null
var _inventory_manager: InventoryManager = null
var _selected_duration: int = 2
var _is_sleeping: bool = false
var _sleep_turns_remaining: int = 0
var _accumulated_quality: float = 0.0
var _current_factors: Dictionary = {}

# Location/context flags (set by game when opening panel)
var _in_dangerous_area: bool = false
var _in_shelter: bool = false
var _bad_weather: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	visible = false
	_create_ui()
	_connect_signals()
	_survival_manager = get_node_or_null("/root/Main/Systems/SurvivalManager")
	

func _create_ui() -> void:
	# Full screen overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	
	# Center panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(450, 500)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel_color
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	panel_style.border_width_bottom = 3
	panel_style.border_width_top = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = border_color
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	
	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(main_vbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "Make Camp"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)
	
	# Quality factors section
	_create_quality_factors_section(main_vbox)
	
	# Estimated quality display
	_create_quality_display(main_vbox)
	
	# Duration selection
	_create_duration_section(main_vbox)
	
	# Warning label
	_warning_label = Label.new()
	_warning_label.text = ""
	_warning_label.add_theme_font_size_override("font_size", 20)
	_warning_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_label.visible = false
	main_vbox.add_child(_warning_label)
	
	# Buttons
	_create_buttons(main_vbox)
	
	# Results section (hidden initially)
	_create_results_section(main_vbox)


func _create_quality_factors_section(parent: VBoxContainer) -> void:
	var section_label := Label.new()
	section_label.text = "Camp Setup:"
	section_label.add_theme_font_size_override("font_size", 24)
	section_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	parent.add_child(section_label)
	
	_quality_container = VBoxContainer.new()
	_quality_container.add_theme_constant_override("separation", 8)
	parent.add_child(_quality_container)
	
	# Bedroll checkbox
	_check_bedroll = _create_checkbox("Use Bedroll (+25%)", "bedroll")
	_quality_container.add_child(_check_bedroll)
	
	# Campfire checkbox
	_check_campfire = _create_checkbox("Make Campfire (+10%)", "campfire")
	_quality_container.add_child(_check_campfire)
	
	# Shelter checkbox (auto-checked if in shelter)
	_check_shelter = _create_checkbox("Use Shelter (+25%)", "shelter")
	_quality_container.add_child(_check_shelter)
	
	# Safe location checkbox (auto-checked if safe)
	_check_safe_location = _create_checkbox("Safe Location (+50%)", "safe_location")
	_quality_container.add_child(_check_safe_location)


func _create_checkbox(text: String, factor_id: String) -> CheckBox:
	var checkbox := CheckBox.new()
	checkbox.text = text
	checkbox.add_theme_font_size_override("font_size", 22)
	checkbox.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	checkbox.set_meta("factor_id", factor_id)
	checkbox.toggled.connect(_on_factor_toggled.bind(factor_id))
	return checkbox


func _create_quality_display(parent: VBoxContainer) -> void:
	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 12)
	parent.add_child(quality_row)
	
	var label := Label.new()
	label.text = "Sleep Quality:"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	quality_row.add_child(label)
	
	_quality_bar = ProgressBar.new()
	_quality_bar.min_value = 0
	_quality_bar.max_value = 200
	_quality_bar.value = 100
	_quality_bar.show_percentage = false
	_quality_bar.custom_minimum_size = Vector2(150, 20)
	_quality_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.18)
	bar_bg.set_corner_radius_all(4)
	_quality_bar.add_theme_stylebox_override("background", bar_bg)
	
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.3, 0.7, 0.3)
	bar_fill.set_corner_radius_all(4)
	_quality_bar.add_theme_stylebox_override("fill", bar_fill)
	
	quality_row.add_child(_quality_bar)
	
	_quality_label = Label.new()
	_quality_label.text = "100%"
	_quality_label.add_theme_font_size_override("font_size", 24)
	_quality_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_quality_label.custom_minimum_size = Vector2(60, 0)
	quality_row.add_child(_quality_label)


func _create_duration_section(parent: VBoxContainer) -> void:
	_duration_container = HBoxContainer.new()
	_duration_container.add_theme_constant_override("separation", 12)
	parent.add_child(_duration_container)
	
	_duration_label = Label.new()
	_duration_label.text = "Sleep Duration:"
	_duration_label.add_theme_font_size_override("font_size", 24)
	_duration_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_duration_container.add_child(_duration_label)
	
	# Duration buttons
	for turns in [1, 2]:
		var btn := Button.new()
		btn.text = "%d turn%s" % [turns, "s" if turns > 1 else ""]
		btn.toggle_mode = true
		btn.button_pressed = (turns == _selected_duration)
		btn.custom_minimum_size = Vector2(100, 36)
		btn.add_theme_font_size_override("font_size", 22)
		
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.25, 0.25, 0.3)
		btn_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", btn_style)
		
		var btn_pressed := btn_style.duplicate()
		btn_pressed.bg_color = Color(0.3, 0.4, 0.35)
		btn_pressed.border_width_bottom = 2
		btn_pressed.border_color = Color(0.5, 0.7, 0.5)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		
		btn.pressed.connect(_on_duration_selected.bind(turns))
		_duration_container.add_child(btn)
		_duration_buttons.append(btn)


func _create_buttons(parent: VBoxContainer) -> void:
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 16)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(button_row)
	
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(120, 44)
	_cancel_button.add_theme_font_size_override("font_size", 24)
	
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.35, 0.25, 0.25)
	cancel_style.set_corner_radius_all(8)
	_cancel_button.add_theme_stylebox_override("normal", cancel_style)
	
	var cancel_hover := cancel_style.duplicate()
	cancel_hover.bg_color = Color(0.45, 0.3, 0.3)
	_cancel_button.add_theme_stylebox_override("hover", cancel_hover)
	
	_cancel_button.pressed.connect(_on_cancel_pressed)
	button_row.add_child(_cancel_button)
	
	_sleep_button = Button.new()
	_sleep_button.text = "Sleep"
	_sleep_button.custom_minimum_size = Vector2(120, 44)
	_sleep_button.add_theme_font_size_override("font_size", 24)
	
	var sleep_style := StyleBoxFlat.new()
	sleep_style.bg_color = Color(0.25, 0.35, 0.25)
	sleep_style.set_corner_radius_all(8)
	_sleep_button.add_theme_stylebox_override("normal", sleep_style)
	
	var sleep_hover := sleep_style.duplicate()
	sleep_hover.bg_color = Color(0.3, 0.45, 0.3)
	_sleep_button.add_theme_stylebox_override("hover", sleep_hover)
	
	_sleep_button.pressed.connect(_on_sleep_pressed)
	button_row.add_child(_sleep_button)


func _create_results_section(parent: VBoxContainer) -> void:
	_results_container = VBoxContainer.new()
	_results_container.add_theme_constant_override("separation", 12)
	_results_container.visible = false
	parent.add_child(_results_container)
	
	_results_label = Label.new()
	_results_label.text = ""
	_results_label.add_theme_font_size_override("font_size", 24)
	_results_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results_container.add_child(_results_label)
	
	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(140, 44)
	_continue_button.add_theme_font_size_override("font_size", 24)
	
	var continue_style := StyleBoxFlat.new()
	continue_style.bg_color = Color(0.25, 0.35, 0.25)
	continue_style.set_corner_radius_all(8)
	_continue_button.add_theme_stylebox_override("normal", continue_style)
	
	_continue_button.pressed.connect(_on_continue_pressed)
	_results_container.add_child(_continue_button)
	_results_container.alignment = BoxContainer.ALIGNMENT_CENTER


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("sleep_completed"):
			event_bus.sleep_completed.connect(_on_sleep_completed)
		if event_bus.has_signal("sleep_interrupted"):
			event_bus.sleep_interrupted.connect(_on_sleep_interrupted)

# =============================================================================
# PUBLIC API
# =============================================================================

## Initialize with manager references.
func initialize(survival_mgr: SurvivalManager, inventory_mgr: InventoryManager) -> void:
	_survival_manager = survival_mgr
	_inventory_manager = inventory_mgr


## Open the camp panel.
## @param context: Dictionary with location info (dangerous_area, in_shelter, bad_weather)
func open(context: Dictionary = {}) -> void:
	_in_dangerous_area = context.get("dangerous_area", false)
	_in_shelter = context.get("in_shelter", false)
	_bad_weather = context.get("bad_weather", false)
	
	_reset_ui()
	_update_available_factors()
	_update_quality_display()
	_update_warnings()
	
	visible = true
	
	# Emit to block other input
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("encounter_ui_opened"):
		event_bus.emit_signal("encounter_ui_opened")


## Close the camp panel.
func close() -> void:
	visible = false
	panel_closed.emit()
	
	# Re-enable input
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("encounter_ui_closed"):
		event_bus.emit_signal("encounter_ui_closed")


## Check if player has a bedroll in inventory.
func has_bedroll() -> bool:
	if _inventory_manager:
		return _inventory_manager.has_item("bedroll")
	return false

# =============================================================================
# UI UPDATES
# =============================================================================

func _reset_ui() -> void:
	_is_sleeping = false
	_selected_duration = 2
	_current_factors = {}
	
	# Reset checkboxes
	_check_bedroll.button_pressed = false
	_check_campfire.button_pressed = false
	_check_shelter.button_pressed = false
	_check_safe_location.button_pressed = false
	
	# Reset duration buttons
	for i in _duration_buttons.size():
		_duration_buttons[i].button_pressed = (i == 1)  # Default to 2 turns
	
	# Show setup, hide results
	_quality_container.visible = true
	_duration_container.visible = true
	_sleep_button.visible = true
	_cancel_button.visible = true
	_results_container.visible = false
	_warning_label.visible = false
	
	_title_label.text = "Make Camp"


func _update_available_factors() -> void:
	# Bedroll - requires item
	var has_bedroll_item := has_bedroll()
	_check_bedroll.disabled = not has_bedroll_item
	_check_bedroll.button_pressed = has_bedroll_item
	if not has_bedroll_item:
		_check_bedroll.text = "Use Bedroll (+25%) - None"
	else:
		_check_bedroll.text = "Use Bedroll (+25%)"
	
	# Campfire - always available (assume player can make fire)
	_check_campfire.disabled = false
	_check_campfire.button_pressed = true
	
	# Shelter - based on location
	_check_shelter.disabled = not _in_shelter
	_check_shelter.button_pressed = _in_shelter
	if not _in_shelter:
		_check_shelter.text = "Use Shelter (+25%) - None Available"
	else:
		_check_shelter.text = "Use Shelter (+25%)"
	
	# Safe location - based on area
	_check_safe_location.disabled = _in_dangerous_area
	_check_safe_location.button_pressed = not _in_dangerous_area
	if _in_dangerous_area:
		_check_safe_location.text = "Safe Location (+50%) - Dangerous Area!"
	else:
		_check_safe_location.text = "Safe Location (+50%)"


func _update_quality_display() -> void:
	_current_factors = _gather_quality_factors()
	var quality := _calculate_estimated_quality()
	
	_quality_bar.value = quality
	_quality_label.text = "%d%%" % int(quality)
	
	# Color based on quality
	var color := Color(0.3, 0.7, 0.3)  # Green
	if quality < 50:
		color = Color(0.8, 0.3, 0.3)  # Red
	elif quality < 100:
		color = Color(0.8, 0.7, 0.3)  # Yellow
	
	var fill_style := _quality_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill_style.bg_color = color
	_quality_bar.add_theme_stylebox_override("fill", fill_style)


func _update_warnings() -> void:
	var warnings: Array[String] = []
	
	if _in_dangerous_area:
		warnings.append("⚠ Dangerous area - higher encounter chance!")
	
	if _bad_weather:
		warnings.append("⚠ Bad weather reduces sleep quality")
	
	if _survival_manager and _survival_manager.current_hp < _survival_manager.max_hp * 0.3:
		warnings.append("⚠ Injuries will reduce sleep quality")
	
	if warnings.is_empty():
		_warning_label.visible = false
	else:
		_warning_label.text = "\n".join(warnings)
		_warning_label.visible = true


func _gather_quality_factors() -> Dictionary:
	var factors := {}
	
	if _check_bedroll.button_pressed and not _check_bedroll.disabled:
		factors["bedroll"] = true
	
	if _check_campfire.button_pressed:
		factors["campfire"] = true
	
	if _check_shelter.button_pressed and not _check_shelter.disabled:
		factors["shelter"] = true
	
	if _check_safe_location.button_pressed and not _check_safe_location.disabled:
		factors["safe_location"] = true
	
	# Negative factors (automatic)
	if _in_dangerous_area:
		factors["dangerous_area"] = true
	
	if _bad_weather:
		factors["bad_weather"] = true
	
	if _survival_manager and _survival_manager.current_hp < _survival_manager.max_hp * 0.3:
		factors["injured"] = true
	
	return factors


func _calculate_estimated_quality() -> float:
	if _survival_manager == null:
		return 100.0
	
	# Use survival manager's calculation if available
	if _survival_manager.has_method("_calculate_sleep_quality"):
		return _survival_manager._calculate_sleep_quality(_current_factors)
	
	# Fallback calculation
	var quality := 100.0
	var quality_mods := {
		"safe_location": 50,
		"shelter": 25,
		"bedroll": 25,
		"campfire": 10,
		"dangerous_area": -50,
		"bad_weather": -25,
		"injured": -15
	}
	
	for factor in _current_factors:
		if _current_factors[factor] and quality_mods.has(factor):
			quality += quality_mods[factor]
	
	return maxf(0.0, quality)

# =============================================================================
# SLEEP EXECUTION
# =============================================================================

func _start_sleep() -> void:
	if _survival_manager == null:
		push_error("CampPanel: SurvivalManager not set")
		return
	
	_is_sleeping = true
	_sleep_turns_remaining = _selected_duration
	_accumulated_quality = _calculate_estimated_quality()
	
	# Update UI to show sleeping state
	_title_label.text = "Sleeping..."
	_quality_container.visible = false
	_duration_container.visible = false
	_sleep_button.visible = false
	_cancel_button.text = "Wake Up"
	_warning_label.text = "Turn %d of %d..." % [_selected_duration - _sleep_turns_remaining + 1, _selected_duration]
	_warning_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	_warning_label.visible = true
	
	# Start sleep in survival manager
	_survival_manager.start_sleep(_selected_duration, _current_factors)
	
	camp_started.emit(_selected_duration, _current_factors)
	
	# Process first turn
	_process_sleep_turn()


func _process_sleep_turn() -> void:
	# Check for random encounter
	var encounter_roll := randf()
	var effective_chance := encounter_chance_per_turn
	if _in_dangerous_area:
		effective_chance *= 2.0  # Double chance in dangerous areas
	
	if encounter_roll < effective_chance:
		_trigger_sleep_encounter()
		return
	
	# Advance time
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("advance_turn"):
		time_manager.advance_turn()
	
	# Process sleep turn in survival manager
	if _survival_manager:
		_survival_manager.process_sleep_turn()
	
	_sleep_turns_remaining -= 1
	
	if _sleep_turns_remaining > 0:
		# Update progress display
		_warning_label.text = "Turn %d of %d..." % [_selected_duration - _sleep_turns_remaining + 1, _selected_duration]
		
		# Continue sleeping (with delay for visual feedback)
		var timer := get_tree().create_timer(0.5)
		timer.timeout.connect(_process_sleep_turn)
	# Sleep completion is handled by signal from survival_manager


func _trigger_sleep_encounter() -> void:
	_is_sleeping = false
	
	# Interrupt sleep in survival manager
	if _survival_manager:
		_survival_manager.interrupt_sleep("encounter")
	
	# Hide panel and trigger encounter
	close()
	camp_interrupted.emit("encounter")
	
	# Trigger encounter through EncounterManager
	var encounter_manager = get_tree().get_first_node_in_group("encounter_manager")
	if encounter_manager and encounter_manager.has_method("trigger_random_encounter"):
		encounter_manager.trigger_random_encounter()
	else:
		# Fallback: emit event bus signal
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus and event_bus.has_signal("random_encounter_triggered"):
			event_bus.emit_signal("random_encounter_triggered")


func _show_results(result: Dictionary) -> void:
	_title_label.text = "Rested"
	
	var hp_recovered: int = result.get("hp_recovered", 0)
	var fatigue_percent: int = result.get("fatigue_percent_recovered", 0)
	var tier: String = result.get("tier", "adequate")
	var interrupted: bool = result.get("interrupted", false)
	
	var result_text := ""
	if interrupted:
		result_text = "Sleep interrupted!\n\n"
	
	result_text += "Sleep Quality: %s\n" % tier.capitalize()
	result_text += "HP Recovered: +%d\n" % hp_recovered
	result_text += "Fatigue Recovered: %d%%" % fatigue_percent
	
	_results_label.text = result_text
	
	# Show results, hide setup
	_quality_container.visible = false
	_duration_container.visible = false
	_sleep_button.visible = false
	_cancel_button.visible = false
	_warning_label.visible = false
	_results_container.visible = true
	
	camp_completed.emit(result)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_factor_toggled(_pressed: bool, _factor_id: String) -> void:
	_update_quality_display()


func _on_duration_selected(turns: int) -> void:
	_selected_duration = turns
	
	# Update button states
	for i in _duration_buttons.size():
		_duration_buttons[i].button_pressed = (i + 1 == turns)


func _on_sleep_pressed() -> void:
	_start_sleep()


func _on_cancel_pressed() -> void:
	if _is_sleeping:
		# Wake up early
		if _survival_manager:
			_survival_manager.interrupt_sleep("voluntary")
		_is_sleeping = false
	else:
		close()


func _on_continue_pressed() -> void:
	close()


func _on_sleep_completed(result: Dictionary) -> void:
	if not visible or not _is_sleeping:
		return
	
	_is_sleeping = false
	_show_results(result)


func _on_sleep_interrupted(reason: String) -> void:
	if not visible or not _is_sleeping:
		return
	
	_is_sleeping = false
	
	if reason == "encounter":
		# Panel will be closed by _trigger_sleep_encounter
		pass
	else:
		# Show partial results
		_show_results({
			"interrupted": true,
			"interruption_reason": reason,
			"hp_recovered": 0,
			"fatigue_percent_recovered": 25,
			"tier": "poor"
		})


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Close on Escape
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _is_sleeping:
				_on_cancel_pressed()
			else:
				close()
			get_viewport().set_input_as_handled()
