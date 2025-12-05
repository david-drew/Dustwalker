# inventory_panel.gd
# UI panel for displaying and using inventory items and actions.
# Toggle-able panel with item counts and action buttons.
#
# CURRENT ITEMS:
# - Rations (Eat button)
# - Water (Drink button)
#
# ACTIONS:
# - Rest (reduces fatigue, consumes 1 turn)

extends Control
class_name InventoryPanel

# =============================================================================
# CONFIGURATION
# =============================================================================

## Panel background color.
@export var panel_color: Color = Color(0.1, 0.1, 0.12, 0.9)

## Panel border color.
@export var border_color: Color = Color(0.3, 0.3, 0.35)

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _toggle_button: Button
var _panel: PanelContainer
var _vbox: VBoxContainer

var _rations_label: Label
var _rations_button: Button
var _water_label: Label
var _water_button: Button

var _fatigue_label: Label
var _rest_button: Button
var _camp_button: Button

# =============================================================================
# STATE
# =============================================================================

var _inventory_manager: InventoryManager = null
var _survival_manager: SurvivalManager = null
var _is_expanded: bool = true

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_signals()


func _create_ui() -> void:
	# Position below survival panel (bottom-right) using proper anchoring
	position = Vector2(10, 900)
	'''
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -340
	offset_right = -10
	offset_top = -110
	offset_bottom = -10
	'''
	
	# Container for toggle + panel
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	add_child(container)
	
	# Toggle button
	_toggle_button = Button.new()
	_toggle_button.text = "▼ Inventory"
	_toggle_button.flat = true
	_toggle_button.add_theme_font_size_override("font_size", 24)
	_toggle_button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_toggle_button.pressed.connect(_on_toggle_pressed)
	container.add_child(_toggle_button)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel_color
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = border_color
	_panel.add_theme_stylebox_override("panel", panel_style)
	container.add_child(_panel)
	
	# Panel content
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(_vbox)
	
	# Rations row
	_create_item_row("Rations", "rations", "Eat")
	
	# Water row
	_create_item_row("Water", "water", "Drink")
	
	# Separator before actions
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	_vbox.add_child(separator)
	
	# Rest action row
	_create_action_row()


func _create_item_row(item_name: String, item_id: String, action_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_vbox.add_child(row)
	
	# Item icon (placeholder colored box)
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.color = Color(0.6, 0.5, 0.3) if item_id == "rations" else Color(0.3, 0.5, 0.8)
	row.add_child(icon)
	
	# Item name and count
	var label := Label.new()
	label.name = item_id + "_label"
	label.text = "%s: 5" % item_name
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	
	# Action button
	var button := Button.new()
	button.name = item_id + "_button"
	button.text = action_text
	button.custom_minimum_size = Vector2(80, 36)
	
	# Style button
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.3, 0.25)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", btn_style)
	button.add_theme_font_size_override("font_size", 24)
	
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.3, 0.4, 0.3)
	button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_disabled := btn_style.duplicate()
	btn_disabled.bg_color = Color(0.2, 0.2, 0.2)
	button.add_theme_stylebox_override("disabled", btn_disabled)
	
	row.add_child(button)
	
	# Store references and connect
	match item_id:
		"rations":
			_rations_label = label
			_rations_button = button
			button.pressed.connect(_on_eat_pressed)
		"water":
			_water_label = label
			_water_button = button
			button.pressed.connect(_on_drink_pressed)


func _create_action_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_vbox.add_child(row)
	
	# Fatigue icon (yellow/orange for tiredness)
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.color = Color(0.8, 0.6, 0.2)
	row.add_child(icon)
	
	# Fatigue label
	_fatigue_label = Label.new()
	_fatigue_label.name = "fatigue_label"
	_fatigue_label.text = "Fatigue: 0%"
	_fatigue_label.add_theme_font_size_override("font_size", 24)
	_fatigue_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_fatigue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_fatigue_label)
	
	# Rest button
	_rest_button = Button.new()
	_rest_button.name = "rest_button"
	_rest_button.text = "Rest"
	_rest_button.custom_minimum_size = Vector2(80, 36)
	
	# Style button (slightly different color for action vs item use)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.25, 0.35)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	_rest_button.add_theme_stylebox_override("normal", btn_style)
	_rest_button.add_theme_font_size_override("font_size", 24)
	
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.3, 0.3, 0.45)
	_rest_button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_disabled := btn_style.duplicate()
	btn_disabled.bg_color = Color(0.2, 0.2, 0.2)
	_rest_button.add_theme_stylebox_override("disabled", btn_disabled)
	
	_rest_button.pressed.connect(_on_rest_pressed)
	row.add_child(_rest_button)
	
	# Camp button
	_camp_button = Button.new()
	_camp_button.name = "camp_button"
	_camp_button.text = "Camp"
	_camp_button.custom_minimum_size = Vector2(80, 36)
	
	var camp_style := StyleBoxFlat.new()
	camp_style.bg_color = Color(0.3, 0.25, 0.2)
	camp_style.set_corner_radius_all(6)
	camp_style.set_content_margin_all(8)
	_camp_button.add_theme_stylebox_override("normal", camp_style)
	_camp_button.add_theme_font_size_override("font_size", 24)
	
	var camp_hover := camp_style.duplicate()
	camp_hover.bg_color = Color(0.4, 0.35, 0.25)
	_camp_button.add_theme_stylebox_override("hover", camp_hover)
	
	var camp_disabled := camp_style.duplicate()
	camp_disabled.bg_color = Color(0.2, 0.2, 0.2)
	_camp_button.add_theme_stylebox_override("disabled", camp_disabled)
	
	_camp_button.pressed.connect(_on_camp_pressed)
	row.add_child(_camp_button)


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("inventory_changed"):
			event_bus.inventory_changed.connect(_on_inventory_changed)
		if event_bus.has_signal("hunger_changed"):
			event_bus.hunger_changed.connect(_on_survival_changed)
		if event_bus.has_signal("thirst_changed"):
			event_bus.thirst_changed.connect(_on_survival_changed)
		if event_bus.has_signal("fatigue_changed"):
			event_bus.fatigue_changed.connect(_on_fatigue_changed)
		if event_bus.has_signal("encounter_ui_opened"):
			event_bus.encounter_ui_opened.connect(_on_encounter_opened)
		if event_bus.has_signal("encounter_ui_closed"):
			event_bus.encounter_ui_closed.connect(_on_encounter_closed)
		if event_bus.has_signal("combat_started"):
			event_bus.combat_started.connect(_on_combat_started)
		if event_bus.has_signal("combat_ended"):
			event_bus.combat_ended.connect(_on_combat_ended)


## Initialize with references to managers.
func initialize(inventory_mgr: InventoryManager, survival_mgr: SurvivalManager) -> void:
	_inventory_manager = inventory_mgr
	_survival_manager = survival_mgr
	
	# Reset all button states to enabled first
	_reset_button_states()
	
	_update_display()


## Reset all buttons to default enabled state.
## Called on initialize and can be called on new game.
func _reset_button_states() -> void:
	if _rations_button:
		_rations_button.disabled = false
	if _water_button:
		_water_button.disabled = false
	if _rest_button:
		_rest_button.disabled = false
	if _camp_button:
		_camp_button.disabled = false

# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_display() -> void:
	if _inventory_manager == null:
		return
	
	# Update rations
	var rations_count := _inventory_manager.get_item_count("rations")
	_rations_label.text = "Rations: %d" % rations_count
	
	# Update water
	var water_count := _inventory_manager.get_item_count("water")
	_water_label.text = "Water: %d" % water_count
	
	# Update fatigue display
	_update_fatigue_display()
	
	# Update button states
	_update_button_states()


func _update_fatigue_display() -> void:
	if _survival_manager == null or _fatigue_label == null:
		return
	
	var fatigue_info := _survival_manager.get_fatigue_info()
	var fatigue_percent: int = fatigue_info.get("fatigue", 0)
	var fatigue_level: String = fatigue_info.get("level", "rested")
	
	# Show percentage and level
	_fatigue_label.text = "Fatigue: %d%%" % fatigue_percent
	
	# Color based on fatigue level
	var color := Color(0.8, 0.8, 0.8)  # Default
	match fatigue_level:
		"rested":
			color = Color(0.5, 0.8, 0.5)  # Green
		"tired":
			color = Color(0.8, 0.8, 0.4)  # Yellow
		"exhausted":
			color = Color(0.9, 0.6, 0.3)  # Orange
		"collapsing":
			color = Color(0.9, 0.3, 0.3)  # Red
	
	_fatigue_label.add_theme_color_override("font_color", color)


func _update_button_states() -> void:
	if _inventory_manager == null:
		return
	
	# Rations button
	_rations_button.disabled = not _inventory_manager.can_use_ration()
	_rations_button.tooltip_text = _get_ration_tooltip()
	
	# Water button
	_water_button.disabled = not _inventory_manager.can_use_water()
	_water_button.tooltip_text = _get_water_tooltip()
	
	# Rest button
	if _survival_manager and _rest_button:
		_rest_button.disabled = not _survival_manager.can_rest()
		_rest_button.tooltip_text = _get_rest_tooltip()
	
	# Camp button (always enabled unless in encounter/combat)
	if _camp_button:
		_camp_button.disabled = false
		_camp_button.tooltip_text = "Make camp and sleep to fully recover"


func _get_ration_tooltip() -> String:
	if _inventory_manager == null:
		return ""
	
	if not _inventory_manager.has_item("rations"):
		return "No rations available"
	
	if _survival_manager and not _survival_manager.can_eat():
		return "Already well-fed"
	
	return "Eat a ration to restore hunger"


func _get_water_tooltip() -> String:
	if _inventory_manager == null:
		return ""
	
	if not _inventory_manager.has_item("water"):
		return "No water available"
	
	if _survival_manager and not _survival_manager.can_drink():
		return "Already hydrated"
	
	return "Drink water to restore thirst"


func _get_rest_tooltip() -> String:
	if _survival_manager == null:
		return ""
	
	if _survival_manager.is_sleeping:
		return "Already resting"
	
	if _survival_manager.fatigue <= 0:
		return "Not fatigued"
	
	return "Rest for 1 turn to reduce fatigue"

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_toggle_pressed() -> void:
	_is_expanded = not _is_expanded
	_panel.visible = _is_expanded
	_toggle_button.text = "▼ Inventory" if _is_expanded else "▶ Inventory"


func _on_eat_pressed() -> void:
	if _inventory_manager:
		_inventory_manager.use_ration()


func _on_drink_pressed() -> void:
	if _inventory_manager:
		_inventory_manager.use_water()


func _on_rest_pressed() -> void:
	if _survival_manager and _survival_manager.can_rest():
		var recovery := _survival_manager.rest()
		
		# Advance time by 1 turn
		var time_manager = get_node_or_null("/root/TimeManager")
		if time_manager and time_manager.has_method("advance_turn"):
			time_manager.advance_turn()
		
		print("InventoryPanel: Rested - recovered %d fatigue" % recovery)


func _on_camp_pressed() -> void:
	# Find or create the camp panel
	var camp_panel = get_tree().get_first_node_in_group("camp_panel")
	if camp_panel == null:
		# Try to find it as sibling in UI
		camp_panel = get_parent().get_node_or_null("CampPanel")
	
	if camp_panel and camp_panel.has_method("open"):
		# Gather context from current location
		var context := _gather_camp_context()
		camp_panel.open(context)
	else:
		push_warning("InventoryPanel: CampPanel not found - add CampPanel to UI")


func _gather_camp_context() -> Dictionary:
	var context := {
		"dangerous_area": false,
		"in_shelter": false,
		"bad_weather": false
	}
	
	# Check with game manager or hex map for location info
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		# Check if current hex is dangerous
		if game_manager.has_method("is_current_hex_dangerous"):
			context["dangerous_area"] = game_manager.is_current_hex_dangerous()
		
		# Check if current hex has shelter
		if game_manager.has_method("current_hex_has_shelter"):
			context["in_shelter"] = game_manager.current_hex_has_shelter()
	
	# Check weather from TimeManager or WeatherManager
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("is_bad_weather"):
		context["bad_weather"] = time_manager.is_bad_weather()
	
	return context


func _on_inventory_changed() -> void:
	_update_display()


func _on_survival_changed(_new_value: int, _old_value: int) -> void:
	# Button states might have changed
	_update_button_states()


func _on_fatigue_changed(_fatigue: int, _level: String) -> void:
	_update_fatigue_display()
	_update_button_states()


func _on_encounter_opened() -> void:
	# Disable buttons during encounters
	_rations_button.disabled = true
	_water_button.disabled = true
	if _rest_button:
		_rest_button.disabled = true
	if _camp_button:
		_camp_button.disabled = true


func _on_encounter_closed() -> void:
	# Re-enable buttons directly, then update states
	_rations_button.disabled = false
	_water_button.disabled = false
	if _rest_button:
		_rest_button.disabled = false
	if _camp_button:
		_camp_button.disabled = false
	
	# Now apply proper disabled states based on game logic
	_update_button_states()


func _on_combat_started() -> void:
	# Disable buttons during combat
	_rations_button.disabled = true
	_water_button.disabled = true
	if _rest_button:
		_rest_button.disabled = true
	if _camp_button:
		_camp_button.disabled = true


func _on_combat_ended(_victory: bool, _loot: Dictionary) -> void:
	# Re-enable buttons directly, then update states
	_rations_button.disabled = false
	_water_button.disabled = false
	if _rest_button:
		_rest_button.disabled = false
	if _camp_button:
		_camp_button.disabled = false
	
	# Now apply proper disabled states based on game logic
	_update_button_states()

# =============================================================================
# PUBLIC API
# =============================================================================

## Show or hide the inventory panel content.
func set_expanded(expanded: bool) -> void:
	_is_expanded = expanded
	_panel.visible = expanded
	_toggle_button.text = "▼ Inventory" if expanded else "▶ Inventory"


## Force refresh display.
func refresh() -> void:
	_update_display()


## Reset panel state (call on new game).
func reset() -> void:
	_reset_button_states()
	_update_display()
