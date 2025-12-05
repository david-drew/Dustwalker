# combat_ai.gd
# Simple tactical AI for enemy combatants.
# Provides static methods for executing enemy turns.
#
# AI Behaviors:
# - aggressive: Moves toward player, shoots when in range
# - defensive: Prefers cover, shoots from range
# - cautious: Keeps distance, retreats if hurt

class_name CombatAI

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

## Execute an enemy's turn and return array of actions taken.
## @param enemy: The enemy combatant taking the turn.
## @param player: The player combatant (target).
## @param tactical_map: The tactical map for pathfinding/LOS.
## @param all_enemies: All enemy combatants (for coordination, unused for now).
## @return Array of action dictionaries.
static func execute_turn(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap,
	all_enemies: Array[Combatant]
) -> Array:
	var actions: Array = []
	
	if not enemy.is_alive or not player.is_alive:
		return actions
	
	# Get behavior type
	var behavior: String = enemy.ai_behavior if enemy.ai_behavior else "aggressive"
	
	# Execute based on behavior
	match behavior:
		"defensive":
			actions = _execute_defensive_turn(enemy, player, tactical_map)
		"cautious":
			actions = _execute_cautious_turn(enemy, player, tactical_map)
		_:  # Default to aggressive
			actions = _execute_aggressive_turn(enemy, player, tactical_map)
	
	return actions

# =============================================================================
# AGGRESSIVE BEHAVIOR
# =============================================================================
# Priority: Get in range, shoot as much as possible

static func _execute_aggressive_turn(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap
) -> Array:
	var actions: Array = []
	
	var distance := _hex_distance(enemy.current_hex, player.current_hex)
	var weapon_range: int = enemy.get_weapon_range()
	var has_los := tactical_map.has_line_of_sight(enemy.current_hex, player.current_hex)
	
	# Loop until out of AP or no useful action
	var max_iterations := 10  # Safety limit
	var iterations := 0
	
	while enemy.current_ap > 0 and iterations < max_iterations:
		iterations += 1
		distance = _hex_distance(enemy.current_hex, player.current_hex)
		has_los = tactical_map.has_line_of_sight(enemy.current_hex, player.current_hex)
		
		# Priority 1: Reload if out of ammo and have AP
		if enemy.needs_reload():
			if enemy.has_ap(1):
				var reload_action := _do_reload(enemy)
				if reload_action:
					actions.append(reload_action)
					continue
			else:
				break  # Can't reload, can't shoot, done
		
		# Priority 2: Shoot if in range with LOS
		if distance <= weapon_range and has_los and enemy.can_shoot():
			var attack_action := _do_attack(enemy, player, tactical_map)
			if attack_action:
				actions.append(attack_action)
				continue
		
		# Priority 3: Move closer if not in range or no LOS
		if distance > weapon_range or not has_los:
			var move_action := _do_move_toward(enemy, player, tactical_map)
			if move_action:
				actions.append(move_action)
				continue
			else:
				break  # Can't move, done
		
		# If in range but can't shoot (out of AP for shot), we're done
		break
	
	return actions

# =============================================================================
# DEFENSIVE BEHAVIOR
# =============================================================================
# Priority: Find cover, shoot from safety

static func _execute_defensive_turn(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap
) -> Array:
	var actions: Array = []
	
	var distance := _hex_distance(enemy.current_hex, player.current_hex)
	var weapon_range: int = enemy.get_weapon_range()
	var has_los := tactical_map.has_line_of_sight(enemy.current_hex, player.current_hex)
	
	var max_iterations := 10
	var iterations := 0
	
	while enemy.current_ap > 0 and iterations < max_iterations:
		iterations += 1
		distance = _hex_distance(enemy.current_hex, player.current_hex)
		has_los = tactical_map.has_line_of_sight(enemy.current_hex, player.current_hex)
		
		# Priority 1: Reload if needed
		if enemy.needs_reload() and enemy.has_ap(1):
			var reload_action := _do_reload(enemy)
			if reload_action:
				actions.append(reload_action)
				continue
		
		# Priority 2: Shoot if in range with LOS
		if distance <= weapon_range and has_los and enemy.can_shoot():
			var attack_action := _do_attack(enemy, player, tactical_map)
			if attack_action:
				actions.append(attack_action)
				continue
		
		# Priority 3: Move to cover position in range (or just move closer)
		if distance > weapon_range or not has_los:
			# For now, same as aggressive - could enhance to seek cover
			var move_action := _do_move_toward(enemy, player, tactical_map)
			if move_action:
				actions.append(move_action)
				continue
			else:
				break
		
		break
	
	return actions

# =============================================================================
# CAUTIOUS BEHAVIOR
# =============================================================================
# Priority: Keep distance, retreat if hurt

static func _execute_cautious_turn(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap
) -> Array:
	var actions: Array = []
	
	var distance := _hex_distance(enemy.current_hex, player.current_hex)
	var weapon_range: int = enemy.get_weapon_range()
	var has_los := tactical_map.has_line_of_sight(enemy.current_hex, player.current_hex)
	var hp_percent := float(enemy.current_hp) / float(enemy.max_hp)
	
	var max_iterations := 10
	var iterations := 0
	
	while enemy.current_ap > 0 and iterations < max_iterations:
		iterations += 1
		distance = _hex_distance(enemy.current_hex, player.current_hex)
		has_los = tactical_map.has_line_of_sight(enemy.current_hex, player.current_hex)
		
		# Priority 1: Reload if needed
		if enemy.needs_reload() and enemy.has_ap(1):
			var reload_action := _do_reload(enemy)
			if reload_action:
				actions.append(reload_action)
				continue
		
		# Priority 2: Retreat if badly hurt and player is close
		if hp_percent < 0.3 and distance <= 2:
			var retreat_action := _do_move_away(enemy, player, tactical_map)
			if retreat_action:
				actions.append(retreat_action)
				continue
		
		# Priority 3: Shoot if in range with LOS
		if distance <= weapon_range and has_los and enemy.can_shoot():
			var attack_action := _do_attack(enemy, player, tactical_map)
			if attack_action:
				actions.append(attack_action)
				continue
		
		# Priority 4: Move closer if too far
		if distance > weapon_range or not has_los:
			var move_action := _do_move_toward(enemy, player, tactical_map)
			if move_action:
				actions.append(move_action)
				continue
			else:
				break
		
		break
	
	return actions

# =============================================================================
# ACTIONS
# =============================================================================

static func _do_reload(enemy: Combatant) -> Dictionary:
	if enemy.reload_weapon():
		return {
			"type": "reload",
			"actor": enemy.combatant_name,
			"message": "%s reloads." % enemy.combatant_name
		}
	return {}


static func _do_attack(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap
) -> Dictionary:
	# Get cover modifier
	var cover_mod := tactical_map.get_cover_modifier_for_attack(
		player.current_hex,
		enemy.current_hex
	)
	
	var result := enemy.shoot(player, cover_mod)
	
	return {
		"type": "attack",
		"actor": enemy.combatant_name,
		"target": player.combatant_name,
		"hit": result.get("hit", false),
		"damage": result.get("damage", 0),
		"message": result.get("message", "")
	}


static func _do_move_toward(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap
) -> Dictionary:
	# Get reachable hexes with current AP
	var reachable := tactical_map.get_reachable_hexes(enemy.current_hex, enemy.current_ap)
	
	if reachable.is_empty():
		return {}
	
	# Find the reachable hex that gets us closest to the player
	var best_hex: Vector2i = enemy.current_hex
	var best_distance: int = _hex_distance(enemy.current_hex, player.current_hex)
	var best_cost: int = 0
	
	for hex in reachable.keys():
		# Skip our current position
		if hex == enemy.current_hex:
			continue
		
		# Skip the player's hex (can't move onto it)
		if hex == player.current_hex:
			continue
		
		var dist := _hex_distance(hex, player.current_hex)
		
		# Prefer closer hexes, or same distance but cheaper cost
		if dist < best_distance or (dist == best_distance and reachable[hex] < best_cost):
			best_distance = dist
			best_hex = hex
			best_cost = reachable[hex]
	
	if best_hex == enemy.current_hex:
		return {}  # Can't move anywhere useful
	
	# Execute the move
	var old_hex := enemy.current_hex
	tactical_map.move_combatant(enemy, old_hex, best_hex)
	enemy.move_to_hex(best_hex, best_cost)
	
	return {
		"type": "move",
		"actor": enemy.combatant_name,
		"from": old_hex,
		"to": best_hex,
		"ap_cost": best_cost,
		"message": "%s moves closer." % enemy.combatant_name
	}


static func _do_move_away(
	enemy: Combatant,
	player: Combatant,
	tactical_map: TacticalMap
) -> Dictionary:
	# Get reachable hexes
	var reachable := tactical_map.get_reachable_hexes(enemy.current_hex, enemy.current_ap)
	
	# Find hex that maximizes distance from player
	var best_hex: Vector2i = enemy.current_hex
	var best_distance: int = _hex_distance(enemy.current_hex, player.current_hex)
	var best_cost: int = 0
	
	for hex in reachable.keys():
		var dist := _hex_distance(hex, player.current_hex)
		if dist > best_distance:
			best_distance = dist
			best_hex = hex
			best_cost = reachable[hex]
	
	if best_hex == enemy.current_hex:
		return {}  # Can't retreat
	
	# Execute the move
	var old_hex := enemy.current_hex
	tactical_map.move_combatant(enemy, old_hex, best_hex)
	enemy.move_to_hex(best_hex, best_cost)
	
	return {
		"type": "move",
		"actor": enemy.combatant_name,
		"from": old_hex,
		"to": best_hex,
		"ap_cost": best_cost,
		"message": "%s retreats." % enemy.combatant_name
	}

# =============================================================================
# UTILITY
# =============================================================================

static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2
