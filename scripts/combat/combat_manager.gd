# combat_manager.gd
# Orchestrates tactical combat: turn order, action execution, victory/defeat.
# Manages the combat layer overlay on exploration.
# Updated with UI integration, visual feedback, and proper combat flow.

extends Node
class_name CombatManager

# =============================================================================
# SIGNALS
# =============================================================================

signal combat_started()
signal combat_ended(victory: bool, loot: Dictionary)
signal turn_started(combatant: Combatant)
signal turn_ended(combatant: Combatant)
signal player_turn_started()
signal enemy_turn_started(enemy: Combatant)
signal action_executed(action: Dictionary)
signal combatant_died(combatant: Combatant)
signal player_victory(loot: Dictionary)
signal player_defeat()
signal combat_log_message(message: String)

# =============================================================================
# COMBAT STATE
# =============================================================================

## Whether combat is currently active.
var combat_active: bool = false

## The player combatant.
var player_combatant: Combatant = null

## All enemy combatants.
var enemy_combatants: Array[Combatant] = []

## Turn order (sorted by initiative).
var turn_order: Array[Combatant] = []

## Index of current combatant in turn order.
var current_turn_index: int = 0

## Current round number.
var round_number: int = 0

## Whether it's the player's turn.
var is_player_turn: bool = false

## Accumulated loot from defeated enemies.
var combat_loot: Dictionary = {"gold": 0, "items": []}

## Number of enemies defeated this combat.
var enemies_defeated_count: int = 0

# =============================================================================
# REFERENCES
# =============================================================================

## The tactical map.
var tactical_map: TacticalMap = null

## Combat layer container.
var combat_layer: CanvasLayer = null

## Combat camera.
var combat_camera: CombatCamera = null

## Combat HUD.
var combat_hud: CombatHUD = null

## Victory screen.
var victory_screen: CombatVictoryScreen = null

## Defeat screen.
var defeat_screen: CombatDefeatScreen = null

## Original encounter data.
var encounter_data: Dictionary = {}

## Terrain type for this combat.
var terrain_type: String = "plains"

## Weapons data cache.
var _weapons_data: Dictionary = {}

## Enemies data cache.
var _enemies_data: Dictionary = {}

## Callback for when combat ends (to return to encounter).
var _on_combat_end_callback: Callable

var disease_manager:DiseaseManager = null

# =============================================================================
# CONFIGURATION
# =============================================================================

## Movement animation speed.
var move_animation_speed: float = 0.15

## Delay before showing victory/defeat screen.
const END_COMBAT_DELAY: float = 1.0

## Delay between enemy actions for readability.
const ENEMY_ACTION_DELAY: float = 0.3

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()
	add_to_group("combat_manager")
	
	disease_manager = get_node_or_null("/root/Main/Systems/DiseaseManager")


func _load_config() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var weapons_config: Dictionary = loader.load_json("res://data/combat/weapons.json")
		_weapons_data = weapons_config.get("weapons", {})
		
		var enemies_config: Dictionary = loader.load_json("res://data/combat/enemies.json")
		_enemies_data = enemies_config.get("enemies", {})

# =============================================================================
# COMBAT INITIALIZATION
# =============================================================================

## Start combat from an encounter.
## @param combat_data: Dictionary with "enemies" array.
## @param terrain: Terrain type string for map generation.
## @param on_end_callback: Optional callback when combat ends.
func start_combat(combat_data: Dictionary, terrain: String, on_end_callback: Callable = Callable()) -> void:
	if combat_active:
		push_error("CombatManager: Combat already active!")
		return
	
	encounter_data = combat_data
	terrain_type = terrain
	combat_active = true
	combat_loot = {"gold": 0, "items": []}
	enemies_defeated_count = 0
	round_number = 0
	_on_combat_end_callback = on_end_callback
	
	_log("=== Combat Begins ===")
	
	# Create combat layer
	_create_combat_layer()
	
	# Generate tactical map
	_generate_tactical_map()
	
	# Create combat camera
	_create_combat_camera()
	
	# Create UI elements
	_create_combat_ui()
	
	# Create combatants
	_create_player_combatant()
	_create_enemy_combatants()
	
	# Place combatants on map
	_place_combatants()
	
	# Frame camera on map
	_frame_camera()
	
	# Roll initiative and set turn order
	_determine_turn_order()
	
	# Emit signal
	combat_started.emit()
	_emit_to_event_bus("combat_started", [])
	
	# Show HUD
	if combat_hud:
		combat_hud.show_hud()
		combat_hud.set_round(1)
	
	# Start first turn
	_start_next_turn()


func _create_combat_layer() -> void:
	# Create a canvas layer for combat
	combat_layer = CanvasLayer.new()
	combat_layer.name = "CombatLayer"
	combat_layer.layer = 5  # Above exploration, below UI
	get_tree().root.add_child(combat_layer)
	
	# Add background to hide exploration
	var bg := ColorRect.new()
	bg.name = "CombatBackground"
	bg.color = Color(0.1, 0.1, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input!
	combat_layer.add_child(bg)
	
	# Add container for tactical map (centered)
	var map_container := Node2D.new()
	map_container.name = "MapContainer"
	# Center in viewport
	var viewport_size := get_viewport().get_visible_rect().size
	map_container.position = viewport_size / 2
	combat_layer.add_child(map_container)


func _generate_tactical_map() -> void:
	tactical_map = TacticalMap.new()
	tactical_map.name = "TacticalMap"
	
	var map_container = combat_layer.get_node("MapContainer")
	map_container.add_child(tactical_map)
	
	# Generate based on terrain
	tactical_map.generate(terrain_type, Vector2i(15, 12))
	
	# Connect signals
	tactical_map.cell_clicked.connect(_on_cell_clicked)
	tactical_map.cell_hovered.connect(_on_cell_hovered)


func _create_combat_camera() -> void:
	combat_camera = CombatCamera.new()
	combat_camera.name = "CombatCamera"
	
	var map_container = combat_layer.get_node("MapContainer")
	map_container.add_child(combat_camera)
	
	combat_camera.activate()


func _create_combat_ui() -> void:
	# Hide exploration UI during combat
	_hide_exploration_ui()
	
	# Create UI canvas layer (above everything else)
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "CombatUILayer"
	ui_layer.layer = 100  # Very high to be above exploration UI
	combat_layer.add_child(ui_layer)
	
	# Create HUD - add to tree FIRST, then initialize
	combat_hud = CombatHUD.new()
	combat_hud.name = "CombatHUD"
	ui_layer.add_child(combat_hud)
	combat_hud.initialize(self)  # Initialize AFTER adding to tree
	
	# Create victory screen
	victory_screen = CombatVictoryScreen.new()
	victory_screen.name = "VictoryScreen"
	ui_layer.add_child(victory_screen)
	victory_screen.continue_pressed.connect(_on_victory_continue)
	
	# Create defeat screen
	defeat_screen = CombatDefeatScreen.new()
	defeat_screen.name = "DefeatScreen"
	ui_layer.add_child(defeat_screen)
	defeat_screen.load_save_requested.connect(_on_defeat_load_save)
	defeat_screen.restart_requested.connect(_on_defeat_restart)
	defeat_screen.quit_requested.connect(_on_defeat_quit)


func _hide_exploration_ui() -> void:
	# Try to find and hide the main exploration UI
	var ui_node = get_tree().root.get_node_or_null("Main/UI")
	if ui_node:
		ui_node.visible = false
	
	# Also try common UI parent names
	for ui_name in ["UI", "UILayer", "ExplorationUI", "MainUI"]:
		var node = get_tree().root.get_node_or_null("Main/" + ui_name)
		if node:
			node.visible = false


func _show_exploration_ui() -> void:
	# Restore exploration UI visibility
	var ui_node = get_tree().root.get_node_or_null("Main/UI")
	if ui_node:
		ui_node.visible = true
	
	for ui_name in ["UI", "UILayer", "ExplorationUI", "MainUI"]:
		var node = get_tree().root.get_node_or_null("Main/" + ui_name)
		if node:
			node.visible = true


func _frame_camera() -> void:
	if combat_camera and tactical_map:
		var map_size := tactical_map.get_map_pixel_size()
		combat_camera.frame_map(Vector2.ZERO, map_size)


func _create_player_combatant() -> void:
	player_combatant = Combatant.new()
	player_combatant.name = "PlayerCombatant"
	
	# Get player data from SurvivalManager
	var survival_manager = get_tree().get_first_node_in_group("survival_manager")
	var player_data := {
		"max_hp": 20,
		"current_hp": 20,
		"aim": 3,
		"reflex": 3
	}
	
	if survival_manager:
		player_data["max_hp"] = survival_manager.max_health
		player_data["current_hp"] = survival_manager.health
	
	player_combatant.initialize_as_player(player_data, tactical_map.hex_size)
	
	# Connect signals
	player_combatant.died.connect(_on_player_died)
	player_combatant.hp_changed.connect(_on_player_hp_changed)
	player_combatant.ap_changed.connect(_on_player_ap_changed)
	player_combatant.ammo_changed.connect(_on_player_ammo_changed)
	
	var map_container = combat_layer.get_node("MapContainer")
	map_container.add_child(player_combatant)


func _create_enemy_combatants() -> void:
	enemy_combatants.clear()
	
	var enemies_to_spawn: Array = encounter_data.get("enemies", [])
	
	for enemy_spawn in enemies_to_spawn:
		var enemy_type: String = enemy_spawn.get("type", "bandit")
		var count: int = enemy_spawn.get("count", 1)
		
		for i in range(count):
			_create_single_enemy(enemy_type, i)


func _create_single_enemy(enemy_type: String, index: int) -> void:
	var enemy_data: Dictionary = _enemies_data.get(enemy_type, _enemies_data.get("bandit", {}))
	
	var enemy := Combatant.new()
	enemy.name = "%s_%d" % [enemy_type, index]
	enemy.initialize_as_enemy(enemy_data, _weapons_data, tactical_map.hex_size)
	
	# Connect signals
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.hp_changed.connect(_on_enemy_hp_changed.bind(enemy))
	
	var map_container = combat_layer.get_node("MapContainer")
	map_container.add_child(enemy)
	
	enemy_combatants.append(enemy)


func _place_combatants() -> void:
	# Place player at bottom
	var player_spawn := tactical_map.get_player_spawn_hex()
	tactical_map.place_combatant(player_combatant, player_spawn)
	# Account for tactical_map's position offset (from _center_map)
	var player_cell := tactical_map.get_cell(player_spawn)
	player_combatant.position = player_cell.position + tactical_map.position
	
	# Place enemies at top
	var enemy_spawns := tactical_map.get_enemy_spawn_hexes(enemy_combatants.size())
	for i in range(enemy_combatants.size()):
		if i < enemy_spawns.size():
			var spawn_hex := enemy_spawns[i]
			tactical_map.place_combatant(enemy_combatants[i], spawn_hex)
			var enemy_cell := tactical_map.get_cell(spawn_hex)
			enemy_combatants[i].position = enemy_cell.position + tactical_map.position


func _determine_turn_order() -> void:
	turn_order.clear()
	
	# Roll initiative for all combatants
	player_combatant.roll_initiative()
	for enemy in enemy_combatants:
		enemy.roll_initiative()
	
	# Build turn order
	turn_order.append(player_combatant)
	turn_order.append_array(enemy_combatants)
	
	# Sort by initiative (descending)
	turn_order.sort_custom(func(a, b): return a.initiative > b.initiative)
	
	current_turn_index = -1

# =============================================================================
# TURN MANAGEMENT
# =============================================================================

func _start_next_turn() -> void:
	# Remove dead combatants from turn order
	turn_order = turn_order.filter(func(c): return c.is_alive)
	
	# Check victory/defeat
	if _check_victory():
		_end_combat(true)
		return
	if _check_defeat():
		_end_combat(false)
		return
	
	current_turn_index += 1
	
	# New round?
	if current_turn_index >= turn_order.size():
		current_turn_index = 0
		round_number += 1
		_log("=== Round %d ===" % round_number)
		_emit_to_event_bus("combat_round_started", [round_number])
		if combat_hud:
			combat_hud.set_round(round_number)
	
	var current_combatant: Combatant = turn_order[current_turn_index]
	current_combatant.reset_ap()
	
	turn_started.emit(current_combatant)
	
	if current_combatant.is_player:
		is_player_turn = true
		player_turn_started.emit()
		_emit_to_event_bus("player_combat_turn_started", [])
		_log("Your turn - AP: %d" % current_combatant.current_ap)
		
		# Update HUD
		_update_hud_stats()
		
		# Highlight movement options
		tactical_map.highlight_reachable(current_combatant.current_hex, current_combatant.current_ap)
	else:
		is_player_turn = false
		enemy_turn_started.emit(current_combatant)
		_emit_to_event_bus("enemy_combat_turn_started", [current_combatant.combatant_name])
		_log("%s's turn" % current_combatant.combatant_name)
		
		# Execute enemy AI
		_execute_enemy_turn(current_combatant)


func _execute_enemy_turn(enemy: Combatant) -> void:
	# Small delay before enemy acts
	await get_tree().create_timer(ENEMY_ACTION_DELAY).timeout
	
	var actions := CombatAI.execute_turn(enemy, player_combatant, tactical_map, enemy_combatants)
	
	for action in actions:
		_log(action.get("message", ""))
		action_executed.emit(action)
		
		# Animate movement
		if action.get("type") == "move":
			var to_hex: Vector2i = action.get("to", enemy.current_hex)
			var cell := tactical_map.get_cell(to_hex)
			if cell:
				# Account for tactical_map's position offset
				var target_pos := cell.position + tactical_map.position
				var tween := create_tween()
				tween.tween_property(enemy, "position", target_pos, move_animation_speed)
				await tween.finished
		
		# Show damage feedback for attacks
		if action.get("type") == "attack":
			var hit: bool = action.get("hit", false)
			var damage: int = action.get("damage", 0)
			
			if hit and damage > 0:
				_show_floating_damage(player_combatant.position, damage, true)
				if disease_manager != null:
					disease_manager.try_contract_disease("wound_infection", 0.02, "combat_wound")
				else:
					print("Error: DiseaseManager not initialized in CombatManager")
			else:
				_show_miss_indicator(player_combatant.position)
		
		# Small delay between actions
		await get_tree().create_timer(ENEMY_ACTION_DELAY).timeout
		
		# Check victory/defeat after each action
		if _check_victory():
			_end_combat(true)
			return
		if _check_defeat():
			_end_combat(false)
			return
	
	turn_ended.emit(enemy)
	
	# Small delay before next turn
	await get_tree().create_timer(ENEMY_ACTION_DELAY).timeout
	_start_next_turn()

# =============================================================================
# PLAYER ACTIONS
# =============================================================================

## Handle cell click for player actions.
func _on_cell_clicked(coords: Vector2i) -> void:
	if not combat_active or not is_player_turn:
		return
	
	var cell := tactical_map.get_cell(coords)
	if cell == null:
		return
	
	# Check if clicking on enemy (attack)
	if cell.is_occupied() and cell.occupant != player_combatant:
		_attempt_player_attack(cell.occupant)
		return
	
	# Otherwise, try to move
	if cell.can_enter():
		_attempt_player_move(coords)


func _attempt_player_move(target_coords: Vector2i) -> void:
	var path := tactical_map.find_path(player_combatant.current_hex, target_coords)
	
	if path.size() < 2:
		return
	
	# Calculate total AP cost
	var total_cost := 0
	for i in range(1, path.size()):
		var cell := tactical_map.get_cell(path[i])
		if cell:
			total_cost += cell.get_movement_cost()
	
	if not player_combatant.has_ap(total_cost):
		_log("Not enough AP to move there")
		return
	
	# Execute movement along path
	tactical_map.clear_highlights()
	
	for i in range(1, path.size()):
		var next_hex: Vector2i = path[i]
		var cell := tactical_map.get_cell(next_hex)
		var move_cost: int = cell.get_movement_cost()
		
		var old_hex := player_combatant.current_hex
		tactical_map.move_combatant(player_combatant, old_hex, next_hex)
		player_combatant.spend_ap(move_cost)
		
		# Animate - account for tactical_map's position offset
		var target_pos := cell.position + tactical_map.position
		var tween := create_tween()
		tween.tween_property(player_combatant, "position", target_pos, move_animation_speed)
		await tween.finished
	
	var total_hexes: int = path.size() - 1
	_log("Moved %d hex%s (-%d AP)" % [total_hexes, "es" if total_hexes != 1 else "", total_cost])
	
	action_executed.emit({
		"type": "move",
		"actor": "Player",
		"from": path[0],
		"to": path[path.size() - 1],
		"ap_cost": total_cost
	})
	
	# Update highlights and HUD
	tactical_map.highlight_reachable(player_combatant.current_hex, player_combatant.current_ap)
	_update_hud_stats()


func _attempt_player_attack(target: Combatant) -> void:
	if not player_combatant.can_shoot():
		if player_combatant.needs_reload():
			_log("Out of ammo! Reload first")
		else:
			_log("Not enough AP to shoot")
		return
	
	var distance := _hex_distance(player_combatant.current_hex, target.current_hex)
	var weapon_range: int = player_combatant.get_weapon_range()
	
	if distance > weapon_range:
		_log("Target out of range (%d/%d hexes)" % [distance, weapon_range])
		return
	
	if not tactical_map.has_line_of_sight(player_combatant.current_hex, target.current_hex):
		_log("No line of sight to target!")
		return
	
	# Calculate hit chance with cover
	var cover_mod := tactical_map.get_cover_modifier_for_attack(target.current_hex, player_combatant.current_hex)
	
	# Execute attack
	var result := player_combatant.shoot(target, cover_mod)
	_log(result.get("message", "Attack executed"))
	
	# Visual feedback
	if result.get("hit", false):
		var damage: int = result.get("damage", 0)
		_show_floating_damage(target.position, damage, false)
	else:
		_show_miss_indicator(target.position)
	
	action_executed.emit({
		"type": "attack",
		"actor": "Player",
		"target": target.combatant_name,
		"hit": result.get("hit", false),
		"damage": result.get("damage", 0)
	})
	
	# Update highlights and HUD
	tactical_map.highlight_reachable(player_combatant.current_hex, player_combatant.current_ap)
	_update_hud_stats()
	
	# Hide enemy info after attack
	if combat_hud:
		combat_hud.hide_enemy_info()


## Player reload action.
func player_reload() -> void:
	if not combat_active or not is_player_turn:
		return
	
	if not player_combatant.has_ap(1):
		_log("Not enough AP to reload")
		return
	
	player_combatant.reload_weapon()
	_log("Reloaded weapon")
	
	action_executed.emit({
		"type": "reload",
		"actor": "Player"
	})
	
	tactical_map.highlight_reachable(player_combatant.current_hex, player_combatant.current_ap)
	_update_hud_stats()


## Player ends their turn.
func player_end_turn() -> void:
	if not combat_active or not is_player_turn:
		return
	
	tactical_map.clear_highlights()
	turn_ended.emit(player_combatant)
	_log("Turn ended")
	
	# Hide enemy info
	if combat_hud:
		combat_hud.hide_enemy_info()
	
	# Small delay
	await get_tree().create_timer(0.2).timeout
	_start_next_turn()


func _on_cell_hovered(coords: Vector2i) -> void:
	if not combat_active or not is_player_turn:
		return
	
	var cell := tactical_map.get_cell(coords)
	if cell == null:
		if combat_hud:
			combat_hud.hide_enemy_info()
		return
	
	# Show enemy info when hovering over enemy
	if cell.is_occupied() and cell.occupant != player_combatant:
		var enemy: Combatant = cell.occupant
		if combat_hud:
			# Calculate hit chance
			var distance := _hex_distance(player_combatant.current_hex, enemy.current_hex)
			var cover_mod := tactical_map.get_cover_modifier_for_attack(enemy.current_hex, player_combatant.current_hex)
			var base_chance: float = 0.50 + player_combatant.aim * 0.05 + cover_mod
			base_chance = clampf(base_chance, 0.05, 0.95)
			
			var weapon := player_combatant.weapon
			var dmg_min: int = weapon.get("damage_min", 2)
			var dmg_max: int = weapon.get("damage_max", 3)
			
			combat_hud.show_enemy_info(
				enemy.combatant_name,
				enemy.current_hp,
				enemy.max_hp,
				base_chance,
				dmg_min,
				dmg_max
			)
	else:
		if combat_hud:
			combat_hud.hide_enemy_info()

# =============================================================================
# VISUAL FEEDBACK
# =============================================================================

func _show_floating_damage(world_pos: Vector2, damage: int, is_player_damage: bool) -> void:
	var map_container = combat_layer.get_node_or_null("MapContainer")
	if map_container:
		# Use the FloatingDamage class
		var floating := preload("res://scripts/ui/floating_damage.gd")
		if floating:
			floating.spawn(map_container, world_pos, damage, is_player_damage)
		else:
			# Fallback: create simple label
			_create_simple_damage_label(map_container, world_pos, str(damage), is_player_damage)
	
	_emit_to_event_bus("show_floating_damage", [world_pos, damage, is_player_damage])


func _show_miss_indicator(world_pos: Vector2) -> void:
	var map_container = combat_layer.get_node_or_null("MapContainer")
	if map_container:
		var floating := preload("res://scripts/ui/floating_damage.gd")
		if floating:
			floating.spawn_miss(map_container, world_pos)
		else:
			_create_simple_damage_label(map_container, world_pos, "MISS", false)
	
	_emit_to_event_bus("show_miss_indicator", [world_pos])


func _create_simple_damage_label(parent: Node, pos: Vector2, text: String, is_player_damage: bool) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	if is_player_damage:
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	label.position = pos + Vector2(-20, -30)
	parent.add_child(label)
	
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

# =============================================================================
# HUD UPDATES
# =============================================================================

func _update_hud_stats() -> void:
	if combat_hud and player_combatant:
		combat_hud.update_player_stats(
			player_combatant.current_hp,
			player_combatant.max_hp,
			player_combatant.current_ap,
			player_combatant.max_ap,
			player_combatant.current_ammo,
			player_combatant.max_ammo
		)

# =============================================================================
# VICTORY/DEFEAT
# =============================================================================

func _check_victory() -> bool:
	for enemy in enemy_combatants:
		if enemy.is_alive:
			return false
	return true


func _check_defeat() -> bool:
	return not player_combatant.is_alive


func _end_combat(victory: bool) -> void:
	combat_active = false
	is_player_turn = false
	tactical_map.clear_highlights()
	
	# Hide HUD
	if combat_hud:
		combat_hud.hide_hud()
	
	# Delay before showing result screen
	await get_tree().create_timer(END_COMBAT_DELAY).timeout
	
	if victory:
		_log("=== Victory! ===")
		_calculate_loot()
		player_victory.emit(combat_loot)
		_emit_to_event_bus("combat_victory", [combat_loot])
		
		# Show victory screen
		if victory_screen:
			victory_screen.show_screen(combat_loot, enemies_defeated_count)
	else:
		_log("=== Defeat ===")
		player_defeat.emit()
		_emit_to_event_bus("combat_defeat", [])
		
		# Show defeat screen
		if defeat_screen:
			var stats := _gather_game_stats()
			var killer_name := ""
			# Find last enemy that attacked
			for enemy in enemy_combatants:
				if enemy.is_alive:
					killer_name = enemy.combatant_name
					break
			defeat_screen.show_screen(killer_name, stats)
	
	combat_ended.emit(victory, combat_loot)
	_emit_to_event_bus("combat_ended", [victory, combat_loot])


func _calculate_loot() -> void:
	combat_loot = {"gold": 0, "items": []}
	
	for enemy in enemy_combatants:
		var loot := enemy.generate_loot()
		combat_loot["gold"] += loot.get("gold", 0)
		
		for item in loot.get("items", []):
			combat_loot["items"].append(item)
	
	_log("Loot: %d gold" % combat_loot["gold"])
	for item in combat_loot["items"]:
		_log("  + %d %s" % [item.get("quantity", 1), item.get("id", "item")])


func _gather_game_stats() -> Dictionary:
	var stats := {}
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		stats["days"] = time_manager.current_day
	
	var fog_manager = get_tree().get_first_node_in_group("fog_manager")
	if fog_manager and fog_manager.has_method("get_explored_count"):
		stats["explored"] = fog_manager.get_explored_count()
	
	stats["enemies_defeated"] = enemies_defeated_count
	
	return stats

# =============================================================================
# COMBAT END HANDLERS
# =============================================================================

func _on_victory_continue() -> void:
	# Apply loot to inventory
	_apply_loot_to_inventory()
	
	# Clean up and return to exploration
	cleanup_combat()
	
	# Call the callback if provided
	if _on_combat_end_callback.is_valid():
		_on_combat_end_callback.call(true, combat_loot)


func _on_defeat_load_save() -> void:
	cleanup_combat()
	# Signal to main game to load save
	_emit_to_event_bus("load_save_requested", [])


func _on_defeat_restart() -> void:
	cleanup_combat()
	# Signal to main game to restart
	_emit_to_event_bus("restart_requested", [])


func _on_defeat_quit() -> void:
	cleanup_combat()
	get_tree().quit()


func _apply_loot_to_inventory() -> void:
	var inventory_manager = get_tree().get_first_node_in_group("inventory_manager")
	if inventory_manager:
		# Add gold (if inventory tracks it)
		if inventory_manager.has_method("add_gold"):
			inventory_manager.add_gold(combat_loot.get("gold", 0))
		
		# Add items
		for item in combat_loot.get("items", []):
			var item_id: String = item.get("id", "")
			var quantity: int = item.get("quantity", 1)
			if item_id != "" and inventory_manager.has_method("add_item"):
				inventory_manager.add_item(item_id, quantity)

# =============================================================================
# COMBATANT EVENTS
# =============================================================================

func _on_player_died() -> void:
	_log("You have been defeated!")
	# Victory/defeat will be checked at end of current turn


func _on_enemy_died(enemy: Combatant) -> void:
	_log("%s defeated!" % enemy.combatant_name)
	enemies_defeated_count += 1
	tactical_map.remove_combatant(enemy)
	combatant_died.emit(enemy)
	_emit_to_event_bus("combatant_died", [enemy.combatant_name, false])


func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	# Sync with SurvivalManager
	var survival_manager = get_tree().get_first_node_in_group("survival_manager")
	if survival_manager:
		survival_manager.health = current_hp
	
	_emit_to_event_bus("combat_hp_changed", [current_hp, max_hp])
	_update_hud_stats()


func _on_player_ap_changed(current_ap: int, max_ap: int) -> void:
	_emit_to_event_bus("combat_ap_changed", [current_ap, max_ap])
	_update_hud_stats()


func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	_emit_to_event_bus("combat_ammo_changed", [current_ammo, max_ammo])
	_update_hud_stats()


func _on_enemy_hp_changed(_current_hp: int, _max_hp: int, _enemy: Combatant) -> void:
	# Could update enemy HP display if needed
	pass

# =============================================================================
# CLEANUP
# =============================================================================

## Clean up combat and return to exploration.
func cleanup_combat() -> void:
	# Restore exploration UI
	_show_exploration_ui()
	
	if combat_layer:
		combat_layer.queue_free()
		combat_layer = null
	
	tactical_map = null
	combat_camera = null
	combat_hud = null
	victory_screen = null
	defeat_screen = null
	player_combatant = null
	enemy_combatants.clear()
	turn_order.clear()
	
	combat_active = false
	is_player_turn = false

# =============================================================================
# QUERIES
# =============================================================================

## Get current combatant.
func get_current_combatant() -> Combatant:
	if current_turn_index >= 0 and current_turn_index < turn_order.size():
		return turn_order[current_turn_index]
	return null


## Check if combat is active.
func is_combat_active() -> bool:
	return combat_active


## Get player AP.
func get_player_ap() -> int:
	if player_combatant:
		return player_combatant.current_ap
	return 0


## Get player ammo.
func get_player_ammo() -> int:
	if player_combatant:
		return player_combatant.current_ammo
	return 0


## Get alive enemy count.
func get_alive_enemy_count() -> int:
	var count := 0
	for enemy in enemy_combatants:
		if enemy.is_alive:
			count += 1
	return count

# =============================================================================
# UTILITY
# =============================================================================

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2


func _log(message: String) -> void:
	print("Combat: %s" % message)
	combat_log_message.emit(message)
	_emit_to_event_bus("combat_log_message", [message])


func _emit_to_event_bus(signal_name: String, args: Array) -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal(signal_name):
		match args.size():
			0: event_bus.emit_signal(signal_name)
			1: event_bus.emit_signal(signal_name, args[0])
			2: event_bus.emit_signal(signal_name, args[0], args[1])
			3: event_bus.emit_signal(signal_name, args[0], args[1], args[2])
