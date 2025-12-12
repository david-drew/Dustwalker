# inventory_panel.gd
# UI panel for displaying and using inventory items and actions.
# Toggle-able panel with item counts and action buttons.
# Press [I] to toggle visibility.
#
# CURRENT ITEMS:
# - Money (display only)
# - Equipment (2 weapon slots, switch button)
# - Rations (Eat button)
# - Water (Drink button)
#
# ACTIONS:
# - Rest (reduces fatigue, consumes 1 turn)
# - Camp (opens camp menu)

extends Control
class_name InventoryPanel

# =============================================================================
# CONFIGURATION
# =============================================================================

## Panel background color.
@export var panel_color: Color = Color(0.1, 0.1, 0.12, 0.9)

## Panel border color.
@export var border_color: Color = Color(0.3, 0.3, 0.35)

## Toggle key for showing/hiding inventory panel.
@export var toggle_key: Key = KEY_I

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _toggle_button: Button
var _panel: PanelContainer
var _vbox: VBoxContainer

var _money_label: Label

var _weapon_slot_1_label: Label
var _weapon_slot_1_equip_button: Button
var _weapon_slot_2_label: Label
var _weapon_slot_2_equip_button: Button
var _switch_weapon_button: Button
var _available_weapons_container: VBoxContainer

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
var _is_visible: bool = true

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_signals()


func _create_ui() -> void:
	# Position below survival panel (bottom-right) using proper anchoring
	#position = Vector2(10, 900)
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

	# Money row (display-only, no button)
	_create_money_row()

	# Equipment section
	_create_equipment_section()

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


func _create_money_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_vbox.add_child(row)

	# Money icon (yellow/gold colored box)
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.color = Color(0.8, 0.7, 0.2)  # Gold/yellow color
	row.add_child(icon)

	# Money label
	_money_label = Label.new()
	_money_label.name = "money_label"
	_money_label.text = "Money: $20"
	_money_label.add_theme_font_size_override("font_size", 24)
	_money_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_money_label)


func _create_equipment_section() -> void:
	# Separator before equipment
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	_vbox.add_child(separator)

	# Equipment header
	var header := Label.new()
	header.text = "Equipment"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_vbox.add_child(header)

	# Weapon Slot 1
	var slot1_row := HBoxContainer.new()
	slot1_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(slot1_row)

	var icon1 := ColorRect.new()
	icon1.custom_minimum_size = Vector2(28, 28)
	icon1.color = Color(0.5, 0.5, 0.6)
	slot1_row.add_child(icon1)

	_weapon_slot_1_label = Label.new()
	_weapon_slot_1_label.text = "Slot 1: Empty"
	_weapon_slot_1_label.add_theme_font_size_override("font_size", 20)
	_weapon_slot_1_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_weapon_slot_1_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot1_row.add_child(_weapon_slot_1_label)

	_weapon_slot_1_equip_button = Button.new()
	_weapon_slot_1_equip_button.text = "Change"
	_weapon_slot_1_equip_button.custom_minimum_size = Vector2(80, 28)
	_weapon_slot_1_equip_button.add_theme_font_size_override("font_size", 16)
	_weapon_slot_1_equip_button.pressed.connect(_on_equip_slot_1_pressed)
	slot1_row.add_child(_weapon_slot_1_equip_button)

	# Weapon Slot 2
	var slot2_row := HBoxContainer.new()
	slot2_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(slot2_row)

	var icon2 := ColorRect.new()
	icon2.custom_minimum_size = Vector2(28, 28)
	icon2.color = Color(0.5, 0.5, 0.6)
	slot2_row.add_child(icon2)

	_weapon_slot_2_label = Label.new()
	_weapon_slot_2_label.text = "Slot 2: Empty"
	_weapon_slot_2_label.add_theme_font_size_override("font_size", 20)
	_weapon_slot_2_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_weapon_slot_2_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot2_row.add_child(_weapon_slot_2_label)

	_weapon_slot_2_equip_button = Button.new()
	_weapon_slot_2_equip_button.text = "Change"
	_weapon_slot_2_equip_button.custom_minimum_size = Vector2(80, 28)
	_weapon_slot_2_equip_button.add_theme_font_size_override("font_size", 16)
	_weapon_slot_2_equip_button.pressed.connect(_on_equip_slot_2_pressed)
	slot2_row.add_child(_weapon_slot_2_equip_button)

	# Switch weapon button
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	_vbox.add_child(button_row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(28, 0)
	button_row.add_child(spacer)

	_switch_weapon_button = Button.new()
	_switch_weapon_button.text = "Switch Active Weapon"
	_switch_weapon_button.custom_minimum_size = Vector2(0, 36)
	_switch_weapon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.3, 0.4)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	_switch_weapon_button.add_theme_stylebox_override("normal", btn_style)
	_switch_weapon_button.add_theme_font_size_override("font_size", 20)

	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.4, 0.4, 0.5)
	_switch_weapon_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled := btn_style.duplicate()
	btn_disabled.bg_color = Color(0.2, 0.2, 0.2)
	_switch_weapon_button.add_theme_stylebox_override("disabled", btn_disabled)

	_switch_weapon_button.pressed.connect(_on_switch_weapon_pressed)
	button_row.add_child(_switch_weapon_button)

	# Available weapons list (initially hidden)
	_available_weapons_container = VBoxContainer.new()
	_available_weapons_container.name = "AvailableWeapons"
	_available_weapons_container.add_theme_constant_override("separation", 4)
	_available_weapons_container.visible = false
	_vbox.add_child(_available_weapons_container)

	# Separator after equipment
	var separator2 := HSeparator.new()
	separator2.add_theme_constant_override("separation", 4)
	_vbox.add_child(separator2)


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
		if event_bus.has_signal("money_changed"):
			event_bus.money_changed.connect(_on_money_changed)
		if event_bus.has_signal("weapon_equipped"):
			event_bus.weapon_equipped.connect(_on_weapon_equipped)
		if event_bus.has_signal("weapon_unequipped"):
			event_bus.weapon_unequipped.connect(_on_weapon_unequipped)
		if event_bus.has_signal("active_slot_changed"):
			event_bus.active_slot_changed.connect(_on_active_slot_changed)
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
	if _switch_weapon_button:
		_switch_weapon_button.disabled = false

# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_display() -> void:
	if _inventory_manager == null:
		return

	# Update money
	var money_amount := _inventory_manager.get_money()
	_money_label.text = "Money: $%d" % money_amount

	# Update equipment
	_update_equipment_display()

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


func _update_equipment_display() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_weapon_slot_1_label.text = "Slot 1: Empty"
		_weapon_slot_2_label.text = "Slot 2: Empty"
		_switch_weapon_button.disabled = true
		return

	# Get weapon data
	var loader = get_node_or_null("/root/DataLoader")
	if not loader:
		return

	var weapons_data: Dictionary = loader.load_json("res://data/combat/weapons.json")
	var weapons: Dictionary = weapons_data.get("weapons", {})

	var active:int = 0
	var slot_1_id: String = ""
	var slot_2_id: String = ""
	
	# Get player's equipped weapons and active slot
	if "equipped_slot_1" in player:
		slot_1_id = player.equipped_slot_1
	else:
		slot_1_id = ""
	
	if "equipped_slot_2" in player:
		slot_2_id = player.equipped_slot_2
	else:
		slot_1_id = ""
	
	if "active_slot"  in player:
		active = player.active_slot
	else:
		active = 0
	
	# Update slot 1
	if slot_1_id.is_empty():
		_weapon_slot_1_label.text = "Slot 1: Empty"
		_weapon_slot_1_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		var weapon: Dictionary = weapons.get(slot_1_id, {})
		var weapon_name: String = weapon.get("name", slot_1_id.capitalize())

		var active_marker: String = ""
		if active == 0:
			active_marker = " ●"

		# Get ammo info for ranged weapons
		var ammo_text := ""
		if weapon.get("weapon_type") == "ranged" and _inventory_manager:
			var ammo_type: String = weapon.get("ammo_type", "")
			if not ammo_type.is_empty():
				var ammo_count: int = _inventory_manager.get_item_count(ammo_type)
				ammo_text = " [%d]" % ammo_count

		_weapon_slot_1_label.text = "Slot 1: %s%s%s" % [weapon_name, ammo_text, active_marker]

		if active == 0:
			_weapon_slot_1_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		else:
			_weapon_slot_1_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	# Update slot 2
	if slot_2_id.is_empty():
		_weapon_slot_2_label.text = "Slot 2: Empty"
		_weapon_slot_2_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		var weapon: Dictionary = weapons.get(slot_2_id, {})
		var weapon_name: String = weapon.get("name", slot_2_id.capitalize())

		var active_marker: String = ""
		if active == 1:
			active_marker = " ●"

		# Get ammo info for ranged weapons
		var ammo_text := ""
		if weapon.get("weapon_type") == "ranged" and _inventory_manager:
			var ammo_type: String = weapon.get("ammo_type", "")
			if not ammo_type.is_empty():
				var ammo_count: int = _inventory_manager.get_item_count(ammo_type)
				ammo_text = " [%d]" % ammo_count

		_weapon_slot_2_label.text = "Slot 2: %s%s%s" % [weapon_name, ammo_text, active_marker]

		if active == 1:
			_weapon_slot_2_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		else:
			_weapon_slot_2_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	# Enable switch button only if at least one weapon is equipped
	_switch_weapon_button.disabled = slot_1_id.is_empty() and slot_2_id.is_empty()


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


func _on_money_changed(_new_amount: int, _old_amount: int) -> void:
	if _money_label and _inventory_manager:
		var money_amount := _inventory_manager.get_money()
		_money_label.text = "Money: $%d" % money_amount


func _on_weapon_equipped(_slot: int, _weapon_id: String) -> void:
	_update_equipment_display()


func _on_weapon_unequipped(_slot: int) -> void:
	_update_equipment_display()


func _on_active_slot_changed(_new_slot: int) -> void:
	_update_equipment_display()


func _on_switch_weapon_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("switch_active_slot"):
		player.switch_active_slot()
		_update_equipment_display()


var _equipping_slot: int = -1  # Track which slot we're equipping to


func _on_equip_slot_1_pressed() -> void:
	_equipping_slot = 0
	_show_available_weapons()


func _on_equip_slot_2_pressed() -> void:
	_equipping_slot = 1
	_show_available_weapons()


func _show_available_weapons() -> void:
	# Clear existing list
	for child in _available_weapons_container.get_children():
		child.queue_free()

	if not _inventory_manager:
		return

	# Get all items from inventory
	var all_items: Dictionary = _inventory_manager.get_all_items()

	# Load weapon data to check which items are weapons
	var loader = get_node_or_null("/root/DataLoader")
	if not loader:
		print("InventoryPanel: No DataLoader")
		return

	var weapons_data: Dictionary = loader.load_json("res://data/combat/weapons.json")
	var weapons: Dictionary = weapons_data.get("weapons", {})
	print("InventoryPanel: Loaded %d weapon definitions" % weapons.size())

	# Header
	var header := Label.new()
	if _equipping_slot == 0:
		header.text = "Select weapon for Slot 1:"
	else:
		header.text = "Select weapon for Slot 2:"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_available_weapons_container.add_child(header)

	var has_weapons := false
	var listed_weapons: Array = []

	# List weapons in inventory
	for item_id in all_items:
		print("  Checking item: %s" % item_id)
		if weapons.has(item_id):
			print("    -> Is a weapon!")
			has_weapons = true
			listed_weapons.append(item_id)
			var weapon: Dictionary = weapons[item_id]
			var weapon_name: String = weapon.get("name", item_id.capitalize())
			var weapon_type: String = weapon.get("weapon_type", "unknown")

			var weapon_row := HBoxContainer.new()
			weapon_row.add_theme_constant_override("separation", 8)
			_available_weapons_container.add_child(weapon_row)

			# Indent
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(28, 0)
			weapon_row.add_child(spacer)

			# Weapon name label
			var name_label := Label.new()
			name_label.text = "%s (%s)" % [weapon_name, weapon_type]
			name_label.add_theme_font_size_override("font_size", 16)
			name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			weapon_row.add_child(name_label)

			# Equip button
			var equip_btn := Button.new()
			equip_btn.text = "Equip"
			equip_btn.custom_minimum_size = Vector2(70, 24)
			equip_btn.add_theme_font_size_override("font_size", 14)
			equip_btn.pressed.connect(_on_equip_weapon.bind(item_id))
			weapon_row.add_child(equip_btn)

	# Also list currently equipped weapons (if not already listed)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var slot_1_id: String = ""
		var slot_2_id: String = ""

		if "equipped_slot_1" in player:
			slot_1_id = player.equipped_slot_1
		if "equipped_slot_2" in player:
			slot_2_id = player.equipped_slot_2

		# Add slot 1 weapon if not in inventory list
		if not slot_1_id.is_empty() and not listed_weapons.has(slot_1_id) and weapons.has(slot_1_id):
			print("  Adding equipped weapon from slot 1: %s" % slot_1_id)
			has_weapons = true
			var weapon: Dictionary = weapons[slot_1_id]
			var weapon_name: String = weapon.get("name", slot_1_id.capitalize())
			var weapon_type: String = weapon.get("weapon_type", "unknown")

			var weapon_row := HBoxContainer.new()
			weapon_row.add_theme_constant_override("separation", 8)
			_available_weapons_container.add_child(weapon_row)

			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(28, 0)
			weapon_row.add_child(spacer)

			var name_label := Label.new()
			name_label.text = "%s (%s) [equipped]" % [weapon_name, weapon_type]
			name_label.add_theme_font_size_override("font_size", 16)
			name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			weapon_row.add_child(name_label)

			var equip_btn := Button.new()
			equip_btn.text = "Equip"
			equip_btn.custom_minimum_size = Vector2(70, 24)
			equip_btn.add_theme_font_size_override("font_size", 14)
			equip_btn.pressed.connect(_on_equip_weapon.bind(slot_1_id))
			weapon_row.add_child(equip_btn)

		# Add slot 2 weapon if not in inventory list
		if not slot_2_id.is_empty() and not listed_weapons.has(slot_2_id) and weapons.has(slot_2_id):
			print("  Adding equipped weapon from slot 2: %s" % slot_2_id)
			has_weapons = true
			var weapon: Dictionary = weapons[slot_2_id]
			var weapon_name: String = weapon.get("name", slot_2_id.capitalize())
			var weapon_type: String = weapon.get("weapon_type", "unknown")

			var weapon_row := HBoxContainer.new()
			weapon_row.add_theme_constant_override("separation", 8)
			_available_weapons_container.add_child(weapon_row)

			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(28, 0)
			weapon_row.add_child(spacer)

			var name_label := Label.new()
			name_label.text = "%s (%s) [equipped]" % [weapon_name, weapon_type]
			name_label.add_theme_font_size_override("font_size", 16)
			name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			weapon_row.add_child(name_label)

			var equip_btn := Button.new()
			equip_btn.text = "Equip"
			equip_btn.custom_minimum_size = Vector2(70, 24)
			equip_btn.add_theme_font_size_override("font_size", 14)
			equip_btn.pressed.connect(_on_equip_weapon.bind(slot_2_id))
			weapon_row.add_child(equip_btn)

	# Add "Unequip" option
	var unequip_row := HBoxContainer.new()
	unequip_row.add_theme_constant_override("separation", 8)
	_available_weapons_container.add_child(unequip_row)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(28, 0)
	unequip_row.add_child(spacer2)

	var unequip_label := Label.new()
	unequip_label.text = "(Empty slot)"
	unequip_label.add_theme_font_size_override("font_size", 16)
	unequip_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	unequip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unequip_row.add_child(unequip_label)

	var unequip_btn := Button.new()
	unequip_btn.text = "Unequip"
	unequip_btn.custom_minimum_size = Vector2(70, 24)
	unequip_btn.add_theme_font_size_override("font_size", 14)
	unequip_btn.pressed.connect(_on_unequip_weapon)
	unequip_row.add_child(unequip_btn)

	# Cancel button
	var cancel_row := HBoxContainer.new()
	cancel_row.add_theme_constant_override("separation", 8)
	_available_weapons_container.add_child(cancel_row)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(28, 0)
	cancel_row.add_child(spacer3)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, 28)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.pressed.connect(_on_cancel_equip)
	cancel_row.add_child(cancel_btn)

	if not has_weapons:
		var no_weapons := Label.new()
		no_weapons.text = "  (No weapons in inventory)"
		no_weapons.add_theme_font_size_override("font_size", 14)
		no_weapons.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
		_available_weapons_container.add_child(no_weapons)

	_available_weapons_container.visible = true


func _on_equip_weapon(weapon_id: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("equip_weapon"):
		player.equip_weapon(weapon_id, _equipping_slot)
		_available_weapons_container.visible = false
		_update_equipment_display()


func _on_unequip_weapon() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("unequip_weapon"):
		player.unequip_weapon(_equipping_slot)
		_available_weapons_container.visible = false
		_update_equipment_display()


func _on_cancel_equip() -> void:
	_available_weapons_container.visible = false


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
	if _switch_weapon_button:
		_switch_weapon_button.disabled = true


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
	_update_equipment_display()


func _on_combat_started() -> void:
	# Disable buttons during combat
	_rations_button.disabled = true
	_water_button.disabled = true
	if _rest_button:
		_rest_button.disabled = true
	if _camp_button:
		_camp_button.disabled = true
	if _switch_weapon_button:
		_switch_weapon_button.disabled = true


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
	_update_equipment_display()

# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			toggle()
			get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

## Toggle panel visibility.
func toggle() -> void:
	_is_visible = not _is_visible
	visible = _is_visible

	if _is_visible:
		_update_display()


## Show the panel.
func show_panel() -> void:
	_is_visible = true
	visible = true
	_update_display()


## Hide the panel.
func hide_panel() -> void:
	_is_visible = false
	visible = false


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
