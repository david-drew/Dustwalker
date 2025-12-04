# combat_ai.gd
# Simple AI for enemy combatants in tactical combat.
# Handles movement and attack decisions.

extends RefCounted
class_name CombatAI

# =============================================================================
# AI BEHAVIORS
# =============================================================================

## Execute a turn for an enemy combatant.
## @return Array[Dictionary] - List of actions taken.
static func execute_turn(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap,
	all_enemies: Array
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	
	if not enemy.is_alive or not player.is_alive:
		return actions
	
	var behavior: String = enemy.ai_behavior
	
	match behavior:
		"aggressive":
			actions = _aggressive_turn(enemy, player, tactical_map)
		"ranged":
			actions = _ranged_turn(enemy, player, tactical_map)
		_:
			actions = _aggressive_turn(enemy, player, tactical_map)
	
	return actions


## Aggressive AI: Move toward player, shoot when in range.
static func _aggressive_turn(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	
	while enemy.current_ap > 0:
		var distance := _hex_distance(enemy.current_hex, player.current_hex)
		var weapon_range: int = enemy.get_weapon_range()
		var can_see := tactical_map.has_line_of_sight(enemy.current_hex, player.current_hex)
		
		# Check if we need to reload
		if enemy.needs_reload() and enemy.has_ap(1):
			enemy.reload_weapon()
			actions.append({
				"type": "reload",
				"actor": enemy.combatant_name,
				"message": "%s reloads" % enemy.combatant_name
			})
			continue
		
		# If in range and can see player, shoot
		if distance <= weapon_range and can_see and enemy.can_shoot():
			var cover_mod := tactical_map.get_cover_modifier_for_attack(player.current_hex, enemy.current_hex)
			var result := enemy.shoot(player, cover_mod)
			actions.append({
				"type": "attack",
				"actor": enemy.combatant_name,
				"target": player.combatant_name,
				"hit": result.get("hit", false),
				"damage": result.get("damage", 0),
				"message": result.get("message", "")
			})
			continue
		
		# Not in range or can't see - try to move closer
		var move_action := _move_toward_target(enemy, player.current_hex, tactical_map)
		if move_action.is_empty():
			break  # Can't move, end turn
		
		actions.append(move_action)
	
	return actions


## Ranged AI: Stay at preferred range, retreat if too close.
static func _ranged_turn(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var preferred_range := 6
	
	while enemy.current_ap > 0:
		var distance := _hex_distance(enemy.current_hex, player.current_hex)
		var weapon_range: int = enemy.get_weapon_range()
		var can_see := tactical_map.has_line_of_sight(enemy.current_hex, player.current_hex)
		
		# Check if we need to reload
		if enemy.needs_reload() and enemy.has_ap(1):
			enemy.reload_weapon()
			actions.append({
				"type": "reload",
				"actor": enemy.combatant_name,
				"message": "%s reloads" % enemy.combatant_name
			})
			continue
		
		# If at good range and can see, shoot
		if distance >= 3 and distance <= weapon_range and can_see and enemy.can_shoot():
			var cover_mod := tactical_map.get_cover_modifier_for_attack(player.current_hex, enemy.current_hex)
			var result := enemy.shoot(player, cover_mod)
			actions.append({
				"type": "attack",
				"actor": enemy.combatant_name,
				"target": player.combatant_name,
				"hit": result.get("hit", false),
				"damage": result.get("damage", 0),
				"message": result.get("message", "")
			})
			continue
		
		# Too close - try to retreat
		if distance < 3:
			var retreat_action := _move_away_from_target(enemy, player.current_hex, tactical_map)
			if not retreat_action.is_empty():
				actions.append(retreat_action)
				continue
		
		# Too far - move closer (but not too close)
		if distance > weapon_range:
			var move_action := _move_toward_target(enemy, player.current_hex, tactical_map)
			if not move_action.is_empty():
				actions.append(move_action)
				continue
		
		# Can't do anything useful, end turn
		break
	
	return actions


## Move one step toward a target hex.
static func _move_toward_target(
	enemy: Combatant,
	target_hex: Vector2i,
	tactical_map: TacticalMap
) -> Dictionary:
	var path := tactical_map.find_path(enemy.current_hex, target_hex)
	
	if path.size() < 2:
		return {}
	
	var next_hex: Vector2i = path[1]
	var cell := tactical_map.get_cell(next_hex)
	
	if cell == null or not cell.can_enter():
		return {}
	
	var move_cost: int = cell.get_movement_cost()
	if move_cost < 0 or not enemy.has_ap(move_cost):
		return {}
	
	var old_hex := enemy.current_hex
	tactical_map.move_combatant(enemy, old_hex, next_hex)
	enemy.spend_ap(move_cost)
	
	return {
		"type": "move",
		"actor": enemy.combatant_name,
		"from": old_hex,
		"to": next_hex,
		"ap_cost": move_cost,
		"message": "%s moves" % enemy.combatant_name
	}


## Move one step away from a target hex.
static func _move_away_from_target(
	enemy: Combatant,
	target_hex: Vector2i,
	tactical_map: TacticalMap
) -> Dictionary:
	var neighbors := _get_neighbors(enemy.current_hex)
	var best_hex: Vector2i = enemy.current_hex
	var best_distance: int = _hex_distance(enemy.current_hex, target_hex)
	
	for neighbor in neighbors:
		var cell := tactical_map.get_cell(neighbor)
		if cell == null or not cell.can_enter():
			continue
		
		var dist := _hex_distance(neighbor, target_hex)
		if dist > best_distance:
			best_distance = dist
			best_hex = neighbor
	
	if best_hex == enemy.current_hex:
		return {}
	
	var cell := tactical_map.get_cell(best_hex)
	var move_cost: int = cell.get_movement_cost()
	
	if move_cost < 0 or not enemy.has_ap(move_cost):
		return {}
	
	var old_hex := enemy.current_hex
	tactical_map.move_combatant(enemy, old_hex, best_hex)
	enemy.spend_ap(move_cost)
	
	return {
		"type": "move",
		"actor": enemy.combatant_name,
		"from": old_hex,
		"to": best_hex,
		"ap_cost": move_cost,
		"message": "%s retreats" % enemy.combatant_name
	}


## Get neighboring hex coordinates.
static func _get_neighbors(coords: Vector2i) -> Array[Vector2i]:
	var directions := [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	var neighbors: Array[Vector2i] = []
	for dir in directions:
		neighbors.append(coords + dir)
	return neighbors


## Calculate hex distance.
static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2
