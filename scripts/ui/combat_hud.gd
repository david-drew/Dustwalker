# combat_hud.gd
# Combat UI overlay showing turn indicator, AP, health, ammo, action buttons, and combat log.
# Displays during tactical combat and handles player input for actions.

extends Control
class_name CombatHUD

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when player clicks End Turn button.
signal end_turn_pressed()

## Emitted when player clicks Reload button.
signal reload_pressed()

# =============================================================================
# CONFIGURATION
# =============================================================================

const LOG_MAX_LINES: int = 12
const LOG_FADE_DELAY: float = 5.0

# =============================================================================
# NODE REFERENCES
# =============================================================================

# Top bar
var _top_bar: PanelContainer
var _turn_indicator: Label
var _round_label: Label

# Player stats panel (left side)
var _stats_panel: PanelContainer
var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect
var _hp_label: Label
var _ap_container: HBoxContainer
var _ap_pips: Array[ColorRect] = []
var _ammo_label: Label
var _weapon_label: Label

# Action buttons (bottom center)
var _action_panel: PanelContainer
var _end_turn_button: Button
var _reload_button: Button

# Combat log (bottom left, collapsible)
var _log_panel: PanelContainer
var _log_container: VBoxContainer
var _log_scroll: ScrollContainer
var _log_content: RichTextLabel
var _log_toggle_button: Button
var _log_collapsed: bool = false

# Enemy info (shown when targeting)
var _enemy_info_panel: PanelContainer
var _enemy_name_label: Label
var _enemy_hp_bar_bg: ColorRect
var _enemy_hp_bar_fill: ColorRect
var _enemy_hp_label: Label
var _attack_preview_label: Label

# =============================================================================
# STATE
# =============================================================================

var _combat_manager: Node = null
var _is_player_turn: bool = false
var _current_ap: int = 0
var _max_ap: int = 4
var _current_hp: int = 20
var _max_hp: int = 20
var _current_ammo: int = 6
var _max_ammo: int = 6
var _log_messages: Array[String] = []

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_signals()
	hide()


func _create_ui() -> void:
	# Full screen container
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2(3100, 900)
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_create_top_bar()
	_create_stats_panel()
	_create_action_panel()
	_create_combat_log()
	_create_enemy_info_panel()


func _create_top_bar() -> void:
	_top_bar = PanelContainer.new()
	_top_bar.name = "TopBar"
	
	# Position at top center
	_top_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_top_bar.position = Vector2(-150, 10)
	_top_bar.custom_minimum_size = Vector2(300, 50)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.9)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.5, 0.3)
	_top_bar.add_theme_stylebox_override("panel", style)
	add_child(_top_bar)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_bar.add_child(hbox)
	
	# Round label
	_round_label = Label.new()
	_round_label.text = "Round 1"
	_round_label.add_theme_font_size_override("font_size", 20)
	_round_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	hbox.add_child(_round_label)
	
	# Separator
	var sep := VSeparator.new()
	hbox.add_child(sep)
	
	# Turn indicator
	_turn_indicator = Label.new()
	_turn_indicator.text = "YOUR TURN"
	_turn_indicator.add_theme_font_size_override("font_size", 24)
	_turn_indicator.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	hbox.add_child(_turn_indicator)


func _create_stats_panel() -> void:
	_stats_panel = PanelContainer.new()
	_stats_panel.name = "StatsPanel"
	
	# Position at top left
	_stats_panel.position = Vector2(10, 70)
	_stats_panel.custom_minimum_size = Vector2(200, 140)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.9)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	style.border_width_left = 3
	style.border_color = Color(0.3, 0.5, 0.8)
	_stats_panel.add_theme_stylebox_override("panel", style)
	add_child(_stats_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_stats_panel.add_child(vbox)
	
	# Health section
	var hp_section := VBoxContainer.new()
	hp_section.add_theme_constant_override("separation", 4)
	vbox.add_child(hp_section)
	
	var hp_header := Label.new()
	hp_header.text = "HEALTH"
	hp_header.add_theme_font_size_override("font_size", 14)
	hp_header.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
	hp_section.add_child(hp_header)
	
	# HP bar container
	var hp_bar_container := Control.new()
	hp_bar_container.custom_minimum_size = Vector2(176, 20)
	hp_section.add_child(hp_bar_container)
	
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.2, 0.15, 0.15)
	_hp_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_bar_container.add_child(_hp_bar_bg)
	
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.2, 0.7, 0.2)
	_hp_bar_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_bar_container.add_child(_hp_bar_fill)
	
	_hp_label = Label.new()
	_hp_label.text = "20/20"
	_hp_label.add_theme_font_size_override("font_size", 14)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.set_anchors_preset(Control.PRESET_CENTER)
	_hp_label.position = Vector2(-20, -8)
	hp_bar_container.add_child(_hp_label)
	
	# AP section
	var ap_section := VBoxContainer.new()
	ap_section.add_theme_constant_override("separation", 4)
	vbox.add_child(ap_section)
	
	var ap_header := Label.new()
	ap_header.text = "ACTION POINTS"
	ap_header.add_theme_font_size_override("font_size", 14)
	ap_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	ap_section.add_child(ap_header)
	
	_ap_container = HBoxContainer.new()
	_ap_container.add_theme_constant_override("separation", 6)
	ap_section.add_child(_ap_container)
	
	# Create AP pips
	for i in range(4):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(36, 16)
		pip.color = Color(0.3, 0.5, 0.8)
		_ap_container.add_child(pip)
		_ap_pips.append(pip)
	
	# Weapon/Ammo section
	var weapon_section := VBoxContainer.new()
	weapon_section.add_theme_constant_override("separation", 2)
	vbox.add_child(weapon_section)
	
	_weapon_label = Label.new()
	_weapon_label.text = "Revolver"
	_weapon_label.add_theme_font_size_override("font_size", 16)
	_weapon_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
	weapon_section.add_child(_weapon_label)
	
	_ammo_label = Label.new()
	_ammo_label.text = "Ammo: 6/6"
	_ammo_label.add_theme_font_size_override("font_size", 14)
	_ammo_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	weapon_section.add_child(_ammo_label)


func _create_action_panel() -> void:
	_action_panel = PanelContainer.new()
	_action_panel.name = "ActionPanel"
	
	# Position at bottom center
	_action_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_action_panel.position = Vector2(-120, -70)
	_action_panel.custom_minimum_size = Vector2(240, 60)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.9)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.border_width_top = 2
	style.border_color = Color(0.5, 0.4, 0.3)
	_action_panel.add_theme_stylebox_override("panel", style)
	add_child(_action_panel)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_panel.add_child(hbox)
	
	# Reload button
	_reload_button = _create_action_button("Reload [R]", hbox)
	_reload_button.pressed.connect(_on_reload_pressed)
	
	# End Turn button
	_end_turn_button = _create_action_button("End Turn [E]", hbox)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)


func _create_action_button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 40)
	button.add_theme_font_size_override("font_size", 16)
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.22, 0.20)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.35, 0.30, 0.25)
	button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed := btn_style.duplicate()
	btn_pressed.bg_color = Color(0.2, 0.18, 0.15)
	button.add_theme_stylebox_override("pressed", btn_pressed)
	
	var btn_disabled := btn_style.duplicate()
	btn_disabled.bg_color = Color(0.15, 0.13, 0.12)
	button.add_theme_stylebox_override("disabled", btn_disabled)
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
	
	parent.add_child(button)
	return button


func _create_combat_log() -> void:
	_log_panel = PanelContainer.new()
	_log_panel.name = "CombatLog"
	
	# Position at bottom left
	_log_panel.position = Vector2(10, 450)
	_log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_log_panel.custom_minimum_size = Vector2(320, 180)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	style.border_width_right = 2
	style.border_color = Color(0.4, 0.35, 0.3)
	_log_panel.add_theme_stylebox_override("panel", style)
	add_child(_log_panel)
	
	_log_container = VBoxContainer.new()
	_log_container.add_theme_constant_override("separation", 4)
	_log_panel.add_child(_log_container)
	
	# Header with toggle
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_log_container.add_child(header)
	
	var log_title := Label.new()
	log_title.text = "Combat Log"
	log_title.add_theme_font_size_override("font_size", 14)
	log_title.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(log_title)
	
	_log_toggle_button = Button.new()
	_log_toggle_button.text = "▼"
	_log_toggle_button.custom_minimum_size = Vector2(24, 24)
	_log_toggle_button.add_theme_font_size_override("font_size", 12)
	_log_toggle_button.flat = true
	_log_toggle_button.pressed.connect(_on_log_toggle_pressed)
	header.add_child(_log_toggle_button)
	
	# Scroll container for log
	_log_scroll = ScrollContainer.new()
	_log_scroll.custom_minimum_size = Vector2(304, 140)
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_container.add_child(_log_scroll)
	
	# Log content
	_log_content = RichTextLabel.new()
	_log_content.bbcode_enabled = true
	_log_content.fit_content = true
	_log_content.custom_minimum_size = Vector2(290, 0)
	_log_content.add_theme_font_size_override("normal_font_size", 14)
	_log_content.add_theme_color_override("default_color", Color(0.75, 0.7, 0.65))
	_log_scroll.add_child(_log_content)


func _create_enemy_info_panel() -> void:
	_enemy_info_panel = PanelContainer.new()
	_enemy_info_panel.name = "EnemyInfo"
	
	# Position at top right
	_enemy_info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_enemy_info_panel.position = Vector2(-220, 70)
	_enemy_info_panel.custom_minimum_size = Vector2(210, 120)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.9)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	style.border_width_right = 3
	style.border_color = Color(0.7, 0.3, 0.3)
	_enemy_info_panel.add_theme_stylebox_override("panel", style)
	add_child(_enemy_info_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_enemy_info_panel.add_child(vbox)
	
	# Enemy name
	_enemy_name_label = Label.new()
	_enemy_name_label.text = "Bandit"
	_enemy_name_label.add_theme_font_size_override("font_size", 20)
	_enemy_name_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.6))
	vbox.add_child(_enemy_name_label)
	
	# Enemy HP bar container
	var hp_bar_container := Control.new()
	hp_bar_container.custom_minimum_size = Vector2(186, 16)
	vbox.add_child(hp_bar_container)
	
	_enemy_hp_bar_bg = ColorRect.new()
	_enemy_hp_bar_bg.color = Color(0.2, 0.15, 0.15)
	_enemy_hp_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_bar_container.add_child(_enemy_hp_bar_bg)
	
	_enemy_hp_bar_fill = ColorRect.new()
	_enemy_hp_bar_fill.color = Color(0.7, 0.2, 0.2)
	_enemy_hp_bar_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_bar_container.add_child(_enemy_hp_bar_fill)
	
	_enemy_hp_label = Label.new()
	_enemy_hp_label.text = "8/8"
	_enemy_hp_label.add_theme_font_size_override("font_size", 12)
	_enemy_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_enemy_hp_label.set_anchors_preset(Control.PRESET_CENTER)
	_enemy_hp_label.position = Vector2(-15, -7)
	hp_bar_container.add_child(_enemy_hp_label)
	
	# Attack preview
	_attack_preview_label = Label.new()
	_attack_preview_label.text = "Hit: 65%  |  Dmg: 2-3"
	_attack_preview_label.add_theme_font_size_override("font_size", 14)
	_attack_preview_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	vbox.add_child(_attack_preview_label)
	
	# Hide by default
	_enemy_info_panel.hide()


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("combat_started"):
			event_bus.combat_started.connect(_on_combat_started)
		if event_bus.has_signal("combat_ended"):
			event_bus.combat_ended.connect(_on_combat_ended)
		if event_bus.has_signal("player_combat_turn_started"):
			event_bus.player_combat_turn_started.connect(_on_player_turn_started)
		if event_bus.has_signal("enemy_combat_turn_started"):
			event_bus.enemy_combat_turn_started.connect(_on_enemy_turn_started)
		if event_bus.has_signal("combat_ap_changed"):
			event_bus.combat_ap_changed.connect(_on_ap_changed)
		if event_bus.has_signal("combat_ammo_changed"):
			event_bus.combat_ammo_changed.connect(_on_ammo_changed)
		if event_bus.has_signal("combat_hp_changed"):
			event_bus.combat_hp_changed.connect(_on_hp_changed)
		if event_bus.has_signal("combat_round_started"):
			event_bus.combat_round_started.connect(_on_round_started)
		if event_bus.has_signal("combat_log_message"):
			event_bus.combat_log_message.connect(_on_log_message)

# =============================================================================
# INPUT
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible or not _is_player_turn:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_E:
				if not _end_turn_button.disabled:
					_on_end_turn_pressed()
				get_viewport().set_input_as_handled()
			KEY_R:
				if not _reload_button.disabled:
					_on_reload_pressed()
				get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

## Initialize HUD with combat manager reference.
func initialize(combat_manager: Node) -> void:
	_combat_manager = combat_manager
	
	# Connect to combat manager signals
	if _combat_manager:
		if _combat_manager.has_signal("combat_log_message"):
			_combat_manager.combat_log_message.connect(_on_log_message)
		if _combat_manager.has_signal("player_turn_started"):
			_combat_manager.player_turn_started.connect(_on_player_turn_from_manager)
		if _combat_manager.has_signal("enemy_turn_started"):
			_combat_manager.enemy_turn_started.connect(_on_enemy_turn_from_manager)


## Show the combat HUD.
func show_hud() -> void:
	_log_messages.clear()
	_log_content.clear()
	_enemy_info_panel.hide()
	show()
	_update_button_states()


## Hide the combat HUD.
func hide_hud() -> void:
	hide()


## Update player stats display.
func update_player_stats(hp: int, max_hp: int, ap: int, max_ap: int, ammo: int, max_ammo: int) -> void:
	_current_hp = hp
	_max_hp = max_hp
	_current_ap = ap
	_max_ap = max_ap
	_current_ammo = ammo
	_max_ammo = max_ammo
	
	_update_hp_display()
	_update_ap_display()
	_update_ammo_display()
	_update_button_states()


## Set weapon name.
func set_weapon_name(weapon_name: String) -> void:
	_weapon_label.text = weapon_name


## Show enemy info panel with target data.
func show_enemy_info(enemy_name: String, hp: int, max_hp: int, hit_chance: float, damage_min: int, damage_max: int) -> void:
	_enemy_name_label.text = enemy_name
	_enemy_hp_label.text = "%d/%d" % [hp, max_hp]
	
	var hp_percent := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	_enemy_hp_bar_fill.scale.x = hp_percent
	
	# Color based on HP
	if hp_percent > 0.6:
		_enemy_hp_bar_fill.color = Color(0.7, 0.2, 0.2)
	elif hp_percent > 0.3:
		_enemy_hp_bar_fill.color = Color(0.7, 0.5, 0.2)
	else:
		_enemy_hp_bar_fill.color = Color(0.8, 0.2, 0.2)
	
	_attack_preview_label.text = "Hit: %d%%  |  Dmg: %d-%d" % [int(hit_chance * 100), damage_min, damage_max]
	
	_enemy_info_panel.show()


## Hide enemy info panel.
func hide_enemy_info() -> void:
	_enemy_info_panel.hide()


## Add message to combat log.
func add_log_message(message: String) -> void:
	_log_messages.append(message)
	
	# Trim old messages
	while _log_messages.size() > LOG_MAX_LINES:
		_log_messages.pop_front()
	
	_rebuild_log_display()
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_content.get_content_height())


## Set turn indicator text and color.
func set_turn_indicator(text: String, is_player: bool) -> void:
	_turn_indicator.text = text
	if is_player:
		_turn_indicator.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	else:
		_turn_indicator.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))


## Set round number.
func set_round(round_num: int) -> void:
	_round_label.text = "Round %d" % round_num

# =============================================================================
# INTERNAL UPDATES
# =============================================================================

func _update_hp_display() -> void:
	_hp_label.text = "%d/%d" % [_current_hp, _max_hp]
	
	var hp_percent := float(_current_hp) / float(_max_hp) if _max_hp > 0 else 0.0
	_hp_bar_fill.scale.x = hp_percent
	
	# Color based on HP percentage
	if hp_percent > 0.6:
		_hp_bar_fill.color = Color(0.2, 0.7, 0.2)
	elif hp_percent > 0.3:
		_hp_bar_fill.color = Color(0.7, 0.7, 0.2)
	else:
		_hp_bar_fill.color = Color(0.7, 0.2, 0.2)


func _update_ap_display() -> void:
	for i in range(_ap_pips.size()):
		if i < _current_ap:
			_ap_pips[i].color = Color(0.3, 0.5, 0.8)
		else:
			_ap_pips[i].color = Color(0.2, 0.2, 0.25)


func _update_ammo_display() -> void:
	_ammo_label.text = "Ammo: %d/%d" % [_current_ammo, _max_ammo]
	
	if _current_ammo == 0:
		_ammo_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	elif _current_ammo <= 2:
		_ammo_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	else:
		_ammo_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))


func _update_button_states() -> void:
	# End Turn always available during player turn
	_end_turn_button.disabled = not _is_player_turn
	
	# Reload available if not full ammo, has AP, and is player turn
	var can_reload := _is_player_turn and _current_ammo < _max_ammo and _current_ap >= 1
	_reload_button.disabled = not can_reload


func _rebuild_log_display() -> void:
	var text := ""
	for i in range(_log_messages.size()):
		var msg: String = _log_messages[i]
		
		# Color code certain messages
		if "hit" in msg.to_lower() and "damage" in msg.to_lower():
			if "Player" in msg or "You" in msg:
				msg = "[color=#88cc88]%s[/color]" % msg
			else:
				msg = "[color=#cc8888]%s[/color]" % msg
		elif "missed" in msg.to_lower():
			msg = "[color=#888888]%s[/color]" % msg
		elif "defeated" in msg.to_lower():
			msg = "[color=#cccc88]%s[/color]" % msg
		elif "Round" in msg:
			msg = "[color=#aaaaaa]%s[/color]" % msg
		
		text += msg + "\n"
	
	_log_content.clear()
	_log_content.append_text(text)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_combat_started() -> void:
	show_hud()


func _on_combat_ended(_victory: bool, _loot: Dictionary) -> void:
	hide_hud()


func _on_player_turn_started() -> void:
	_is_player_turn = true
	set_turn_indicator("YOUR TURN", true)
	_update_button_states()
	
	# Fetch current stats from combat manager
	if _combat_manager:
		var player = _combat_manager.player_combatant
		if player:
			update_player_stats(
				player.current_hp, player.max_hp,
				player.current_ap, player.max_ap,
				player.current_ammo, player.max_ammo
			)


func _on_player_turn_from_manager() -> void:
	_on_player_turn_started()


func _on_enemy_turn_started(enemy_name: String) -> void:
	_is_player_turn = false
	set_turn_indicator(enemy_name + "'s Turn", false)
	_update_button_states()
	hide_enemy_info()


func _on_enemy_turn_from_manager(enemy: Node) -> void:
	if enemy:
		_on_enemy_turn_started(enemy.combatant_name)


func _on_ap_changed(current: int, max_ap: int) -> void:
	_current_ap = current
	_max_ap = max_ap
	_update_ap_display()
	_update_button_states()


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_current_ammo = current
	_max_ammo = max_ammo
	_update_ammo_display()
	_update_button_states()


func _on_hp_changed(current: int, max_hp: int) -> void:
	_current_hp = current
	_max_hp = max_hp
	_update_hp_display()


func _on_round_started(round_num: int) -> void:
	set_round(round_num)


func _on_log_message(message: String) -> void:
	add_log_message(message)


func _on_end_turn_pressed() -> void:
	if _combat_manager and _combat_manager.has_method("player_end_turn"):
		_combat_manager.player_end_turn()
	end_turn_pressed.emit()


func _on_reload_pressed() -> void:
	if _combat_manager and _combat_manager.has_method("player_reload"):
		_combat_manager.player_reload()
	reload_pressed.emit()


func _on_log_toggle_pressed() -> void:
	_log_collapsed = not _log_collapsed
	
	if _log_collapsed:
		_log_scroll.hide()
		_log_toggle_button.text = "▲"
		_log_panel.custom_minimum_size = Vector2(320, 30)
	else:
		_log_scroll.show()
		_log_toggle_button.text = "▼"
		_log_panel.custom_minimum_size = Vector2(320, 180)
