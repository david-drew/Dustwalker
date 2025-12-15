# effect_manager.gd
# Unified system for managing all character effects: talents, diseases, buffs,
# environmental conditions, status effects, and equipment bonuses.
#
# EFFECT TYPES:
# - talent: Permanent special abilities
# - disease: Progressive conditions with stages
# - status: Survival states (fatigue, hunger, thirst, temperature)
# - environmental: Weather and terrain effects
# - buff/debuff: Temporary bonuses/penalties from items or abilities
# - equipment: Gear-based modifiers
#
# MODIFIER TARGETS:
# - stat: Core stats (grit, reflex, aim, etc.)
# - skill: Skills (pistol, tracking, etc.)
# - derived: Calculated values (max_hp, initiative, etc.)
# - multiplier: Rate modifiers (fatigue_rate, water_consumption, etc.)
#
# INTEGRATION:
# EffectManager calculates totals and pushes to PlayerStats.
# Other systems call apply_effect/remove_effect rather than managing modifiers directly.

extends Node
#class_name EffectManager

# =============================================================================
# CONSTANTS
# =============================================================================

const TALENTS_PATH := "res://data/effects/talents.json"
const STATUS_PATH := "res://data/effects/status.json"

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when an effect is applied.
signal effect_applied(target_id: String, effect_id: String, effect_data: Dictionary)

## Emitted when an effect is removed.
signal effect_removed(target_id: String, effect_id: String, reason: String)

## Emitted when an effect expires naturally.
signal effect_expired(target_id: String, effect_id: String)

## Emitted when an effect's duration ticks.
signal effect_ticked(target_id: String, effect_id: String, turns_remaining: int)

## Emitted when a trigger fires.
signal trigger_fired(target_id: String, effect_id: String, trigger: Dictionary, result: Dictionary)

## Emitted when modifiers change (for UI updates).
signal modifiers_changed(target_id: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## All loaded effect definitions keyed by effect_id.
var effect_definitions: Dictionary = {}

## Category groupings for organization.
var effect_categories: Dictionary = {}

# =============================================================================
# STATE
# =============================================================================

## Active effects per target.
## Format: {target_id: {effect_id: {definition: Dict, turns_remaining: int, stacks: int, source: String}}}
var active_effects: Dictionary = {}

## Cached modifier totals per target.
## Format: {target_id: {modifier_key: value}}
var modifier_cache: Dictionary = {}

## Reference to PlayerStats for pushing modifiers.
var _player_stats: PlayerStats = null

## Current turn for duration tracking.
var _current_turn: int = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_effect_definitions()
	_connect_signals()
	add_to_group("effect_manager")
	print("EffectManager: Initialized with %d effect definitions" % effect_definitions.size())


func _load_effect_definitions() -> void:
	_load_effects_from_file(TALENTS_PATH)
	_load_effects_from_file(STATUS_PATH)


func _load_effects_from_file(path: String) -> void:
	var data: Dictionary = {}
	
	# Try DataLoader first
	var data_loader = get_node_or_null("/root/DataLoader")
	if data_loader and data_loader.has_method("load_json"):
		data = data_loader.load_json(path)
	
	# Fallback to direct loading
	if data.is_empty() and FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json := JSON.new()
			var error := json.parse(file.get_as_text())
			file.close()
			if error == OK:
				data = json.data
	
	if data.is_empty():
		push_warning("EffectManager: Could not load %s" % path)
		return
	
	# Process each category in the file
	for category_key in data:
		var category_effects: Dictionary = data[category_key]
		
		if not effect_categories.has(category_key):
			effect_categories[category_key] = []
		
		for effect_id in category_effects:
			var effect_def: Dictionary = category_effects[effect_id].duplicate(true)
			effect_def["id"] = effect_id
			effect_definitions[effect_id] = effect_def
			effect_categories[category_key].append(effect_id)
	
	print("EffectManager: Loaded effects from %s" % path)


func _connect_signals() -> void:
	# Connect to TimeManager for turn tracking
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_signal("turn_started"):
		time_manager.turn_started.connect(_on_turn_started)
	
	# Find PlayerStats after a frame
	await get_tree().process_frame
	_player_stats = get_tree().get_first_node_in_group("player_stats")

# =============================================================================
# EFFECT APPLICATION
# =============================================================================

## Apply an effect to a target.
## @param target_id: Identifier for the target (usually "player" or entity ID).
## @param effect_id: The effect to apply.
## @param source: What applied this effect (for tracking/removal).
## @return True if successfully applied.
func apply_effect(target_id: String, effect_id: String, source: String = "") -> bool:
	if not effect_definitions.has(effect_id):
		push_warning("EffectManager: Unknown effect '%s'" % effect_id)
		return false
	
	var definition: Dictionary = effect_definitions[effect_id]
	
	# Check conditions
	if not _check_conditions(target_id, definition):
		return false
	
	# Initialize target's effect storage
	if not active_effects.has(target_id):
		active_effects[target_id] = {}
	
	# Handle stacking
	var stacking: Dictionary = definition.get("stacking", {"mode": "none"})
	var stack_mode: String = stacking.get("mode", "none")
	
	if active_effects[target_id].has(effect_id):
		match stack_mode:
			"none":
				# Cannot apply if already active
				return false
			"replace":
				# Remove old, apply new
				_remove_effect_internal(target_id, effect_id, "replaced")
			"stack":
				# Increase stack count
				var max_stacks: int = stacking.get("max_stacks", 1)
				var current: Dictionary = active_effects[target_id][effect_id]
				if current["stacks"] < max_stacks:
					current["stacks"] += 1
					_recalculate_modifiers(target_id)
					effect_applied.emit(target_id, effect_id, definition)
					return true
				else:
					return false  # Max stacks reached
			"refresh":
				# Reset duration
				var duration: Dictionary = definition.get("duration", {})
				if duration.get("type") == "turns":
					active_effects[target_id][effect_id]["turns_remaining"] = duration.get("value", 1)
				effect_applied.emit(target_id, effect_id, definition)
				return true
	
	# Remove blocked effects
	var conditions: Dictionary = definition.get("conditions", {})
	var blocks: Array = conditions.get("blocks", [])
	for blocked_id in blocks:
		if active_effects[target_id].has(blocked_id):
			_remove_effect_internal(target_id, blocked_id, "blocked_by_" + effect_id)
	
	# Calculate initial duration
	var turns_remaining: int = -1  # -1 = permanent
	var duration: Dictionary = definition.get("duration", {})
	match duration.get("type", "permanent"):
		"turns":
			turns_remaining = duration.get("value", 1)
		"instant":
			turns_remaining = 0
	
	# Store the active effect
	active_effects[target_id][effect_id] = {
		"definition": definition,
		"turns_remaining": turns_remaining,
		"stacks": 1,
		"source": source,
		"applied_turn": _current_turn
	}
	
	# Recalculate modifiers
	_recalculate_modifiers(target_id)
	
	# Handle instant effects
	if turns_remaining == 0:
		_process_instant_effect(target_id, effect_id, definition)
		_remove_effect_internal(target_id, effect_id, "instant")
	
	effect_applied.emit(target_id, effect_id, definition)
	_emit_to_event_bus("effect_applied", [target_id, effect_id])
	
	print("EffectManager: Applied '%s' to %s" % [effect_id, target_id])
	return true


## Remove an effect from a target.
func remove_effect(target_id: String, effect_id: String) -> bool:
	return _remove_effect_internal(target_id, effect_id, "removed")


func _remove_effect_internal(target_id: String, effect_id: String, reason: String) -> bool:
	if not active_effects.has(target_id):
		return false
	
	if not active_effects[target_id].has(effect_id):
		return false
	
	var effect_data: Dictionary = active_effects[target_id][effect_id]
	var definition: Dictionary = effect_data.get("definition", {})
	
	# Check for on_expire effect
	if reason == "expired":
		var conditions: Dictionary = definition.get("conditions", {})
		var on_expire: String = conditions.get("on_expire", "")
		if not on_expire.is_empty():
			# Apply the follow-up effect
			call_deferred("apply_effect", target_id, on_expire, effect_id)
	
	active_effects[target_id].erase(effect_id)
	
	# Clean up empty target
	if active_effects[target_id].is_empty():
		active_effects.erase(target_id)
	
	_recalculate_modifiers(target_id)
	
	if reason == "expired":
		effect_expired.emit(target_id, effect_id)
	else:
		effect_removed.emit(target_id, effect_id, reason)
	
	_emit_to_event_bus("effect_removed", [target_id, effect_id, reason])
	
	print("EffectManager: Removed '%s' from %s (%s)" % [effect_id, target_id, reason])
	return true


## Remove all effects from a source.
func remove_effects_by_source(target_id: String, source: String) -> int:
	if not active_effects.has(target_id):
		return 0
	
	var to_remove: Array[String] = []
	for effect_id in active_effects[target_id]:
		if active_effects[target_id][effect_id].get("source", "") == source:
			to_remove.append(effect_id)
	
	for effect_id in to_remove:
		_remove_effect_internal(target_id, effect_id, "source_removed")
	
	return to_remove.size()


## Remove all effects of a type.
func remove_effects_by_type(target_id: String, effect_type: String) -> int:
	if not active_effects.has(target_id):
		return 0
	
	var to_remove: Array[String] = []
	for effect_id in active_effects[target_id]:
		var definition: Dictionary = active_effects[target_id][effect_id].get("definition", {})
		if definition.get("type", "") == effect_type:
			to_remove.append(effect_id)
	
	for effect_id in to_remove:
		_remove_effect_internal(target_id, effect_id, "type_cleared")
	
	return to_remove.size()


## Remove all effects in a category.
func remove_effects_by_category(target_id: String, category: String) -> int:
	if not active_effects.has(target_id):
		return 0
	
	var to_remove: Array[String] = []
	for effect_id in active_effects[target_id]:
		var definition: Dictionary = active_effects[target_id][effect_id].get("definition", {})
		if definition.get("category", "") == category:
			to_remove.append(effect_id)
	
	for effect_id in to_remove:
		_remove_effect_internal(target_id, effect_id, "category_cleared")
	
	return to_remove.size()


## Clear all effects from a target.
func clear_all_effects(target_id: String) -> void:
	if not active_effects.has(target_id):
		return
	
	var effect_ids: Array = active_effects[target_id].keys()
	for effect_id in effect_ids:
		_remove_effect_internal(target_id, effect_id, "cleared")

# =============================================================================
# CONDITION CHECKING
# =============================================================================

func _check_conditions(target_id: String, definition: Dictionary) -> bool:
	var conditions: Dictionary = definition.get("conditions", {})
	
	# Check for immunities
	var immunities: Array = conditions.get("immunities", [])
	if not immunities.is_empty() and active_effects.has(target_id):
		for effect_id in active_effects[target_id]:
			var active_def: Dictionary = active_effects[target_id][effect_id].get("definition", {})
			var active_immunities: Array = active_def.get("conditions", {}).get("immunities", [])
			var effect_type: String = definition.get("type", "")
			var effect_category: String = definition.get("category", "")
			
			if definition.get("id", "") in active_immunities:
				return false
			if effect_type in active_immunities:
				return false
			if effect_category in active_immunities:
				return false
	
	# Check prerequisites (for talents)
	var prereqs: Dictionary = definition.get("prerequisites", {})
	
	if prereqs.has("stats") and _player_stats:
		var stat_reqs: Dictionary = prereqs["stats"]
		for stat_name in stat_reqs:
			if _player_stats.get_effective_stat(stat_name) < stat_reqs[stat_name]:
				return false
	
	if prereqs.has("skills"):
		var skill_manager = get_tree().get_first_node_in_group("skill_manager")
		if skill_manager:
			var skill_reqs: Dictionary = prereqs["skills"]
			for skill_name in skill_reqs:
				if skill_manager.get_skill_level(skill_name) < skill_reqs[skill_name]:
					return false
	
	# Check required effects
	var requires: Array = conditions.get("requires", [])
	for required_id in requires:
		if not has_effect(target_id, required_id):
			return false
	
	return true

# =============================================================================
# QUERIES
# =============================================================================

## Check if a target has an effect.
func has_effect(target_id: String, effect_id: String) -> bool:
	if not active_effects.has(target_id):
		return false
	return active_effects[target_id].has(effect_id)


## Get all active effects for a target.
func get_active_effects(target_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	if not active_effects.has(target_id):
		return result
	
	for effect_id in active_effects[target_id]:
		var effect_data: Dictionary = active_effects[target_id][effect_id]
		var definition: Dictionary = effect_data.get("definition", {})
		
		result.append({
			"id": effect_id,
			"name": definition.get("name", effect_id),
			"description": definition.get("description", ""),
			"type": definition.get("type", "unknown"),
			"category": definition.get("category", ""),
			"turns_remaining": effect_data.get("turns_remaining", -1),
			"stacks": effect_data.get("stacks", 1),
			"source": effect_data.get("source", ""),
			"visuals": definition.get("visuals", {})
		})
	
	return result


## Get effects of a specific type.
func get_effects_by_type(target_id: String, effect_type: String) -> Array[Dictionary]:
	var all_effects := get_active_effects(target_id)
	var result: Array[Dictionary] = []
	
	for effect in all_effects:
		if effect.get("type", "") == effect_type:
			result.append(effect)
	
	return result


## Get effect definition by ID.
func get_effect_definition(effect_id: String) -> Dictionary:
	return effect_definitions.get(effect_id, {})


## Get all effects in a category.
func get_effects_in_category(category: String) -> Array[String]:
	var result: Array[String] = []
	if effect_categories.has(category):
		for effect_id in effect_categories[category]:
			result.append(effect_id)
	return result

# =============================================================================
# MODIFIER CALCULATION
# =============================================================================

func _recalculate_modifiers(target_id: String) -> void:
	# Clear cache for this target
	modifier_cache[target_id] = {}
	
	if not active_effects.has(target_id):
		_push_modifiers_to_player_stats(target_id)
		modifiers_changed.emit(target_id)
		return
	
	# Aggregate all modifiers
	for effect_id in active_effects[target_id]:
		var effect_data: Dictionary = active_effects[target_id][effect_id]
		var definition: Dictionary = effect_data.get("definition", {})
		var stacks: int = effect_data.get("stacks", 1)
		var modifiers: Array = definition.get("modifiers", [])
		
		for modifier in modifiers:
			var target: String = modifier.get("target", "stat")
			var name: String = modifier.get("name", "")
			var mod_type: String = modifier.get("type", "flat")
			var value = modifier.get("value", 0)
			
			# Apply stacks
			if stacks > 1 and mod_type == "flat":
				value *= stacks
			
			var cache_key := "%s_%s_%s" % [target, name, mod_type]
			
			if not modifier_cache[target_id].has(cache_key):
				modifier_cache[target_id][cache_key] = {
					"target": target,
					"name": name,
					"type": mod_type,
					"value": 0
				}
			
			modifier_cache[target_id][cache_key]["value"] += value
	
	_push_modifiers_to_player_stats(target_id)
	modifiers_changed.emit(target_id)


func _push_modifiers_to_player_stats(target_id: String) -> void:
	if target_id != "player" or not _player_stats:
		return

	# Clear existing effect modifiers
	_player_stats.remove_modifiers_by_prefix("effect_")

	if not modifier_cache.has(target_id):
		return

	# Apply stat modifiers to PlayerStats
	# Use a counter to ensure unique source names for each modifier
	var modifier_index: int = 0
	for cache_key in modifier_cache[target_id]:
		var mod_data: Dictionary = modifier_cache[target_id][cache_key]

		if mod_data["target"] == "stat":
			var source: String = "effect_%s_%d" % [mod_data["name"], modifier_index]
			_player_stats.add_modifier(
				source,
				mod_data["name"],
				mod_data["type"],
				int(mod_data["value"])
			)
			modifier_index += 1


## Get the total modifier value for a specific modifier.
func get_total_modifier(target_id: String, target_type: String, name: String, mod_type: String = "flat") -> float:
	if not modifier_cache.has(target_id):
		return 0.0
	
	var cache_key := "%s_%s_%s" % [target_type, name, mod_type]
	
	if modifier_cache[target_id].has(cache_key):
		return modifier_cache[target_id][cache_key]["value"]
	
	return 0.0


## Get all modifier values of a type (e.g., all multipliers).
func get_modifiers_of_type(target_id: String, target_type: String) -> Dictionary:
	var result: Dictionary = {}

	if not modifier_cache.has(target_id):
		return result

	for cache_key in modifier_cache[target_id]:
		var mod_data: Dictionary = modifier_cache[target_id][cache_key]
		if mod_data["target"] == target_type:
			var name: String = mod_data["name"]
			if not result.has(name):
				result[name] = {"flat": 0.0, "percentage": 0.0}
			result[name][mod_data["type"]] += mod_data["value"]

	return result


## Get a specific multiplier value (e.g., "fatigue_rate", "water_consumption").
## Returns 1.0 + flat modifier (so base multiplier of 1.0 plus any adjustments).
func get_multiplier(target_id: String, multiplier_name: String) -> float:
	var flat_value := get_total_modifier(target_id, "multiplier", multiplier_name, "flat")
	return 1.0 + flat_value


## Get all active multipliers for a target.
func get_all_multipliers(target_id: String) -> Dictionary:
	var result: Dictionary = {}
	var multipliers := get_modifiers_of_type(target_id, "multiplier")

	for mult_name in multipliers:
		result[mult_name] = 1.0 + multipliers[mult_name].get("flat", 0.0)

	return result


## Update a status effect based on a state change (replaces old state effect with new one).
## Used by SurvivalManager, DiseaseManager, etc. to update their effects.
## @param target_id: Usually "player"
## @param category: Effect category (e.g., "fatigue", "hunger", "weather")
## @param new_effect_id: The new effect to apply (or empty string to just remove)
## @param source: Source identifier for tracking
func update_status_effect(target_id: String, category: String, new_effect_id: String, source: String = "") -> void:
	# Remove any existing effects in this category
	remove_effects_by_category(target_id, category)

	# Apply the new effect if provided
	if not new_effect_id.is_empty():
		apply_effect(target_id, new_effect_id, source)


## Check if a target has any effect in a category.
func has_effect_in_category(target_id: String, category: String) -> bool:
	if not active_effects.has(target_id):
		return false

	for effect_id in active_effects[target_id]:
		var effect_data: Dictionary = active_effects[target_id][effect_id]
		var definition: Dictionary = effect_data.get("definition", {})
		if definition.get("category", "") == category:
			return true

	return false


## Get all effects in a specific category for a target.
func get_effects_in_category_for_target(target_id: String, category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not active_effects.has(target_id):
		return result

	for effect_id in active_effects[target_id]:
		var effect_data: Dictionary = active_effects[target_id][effect_id]
		var definition: Dictionary = effect_data.get("definition", {})

		if definition.get("category", "") == category:
			result.append({
				"id": effect_id,
				"name": definition.get("name", effect_id),
				"description": definition.get("description", ""),
				"type": definition.get("type", "unknown"),
				"category": category,
				"turns_remaining": effect_data.get("turns_remaining", -1),
				"stacks": effect_data.get("stacks", 1),
				"source": effect_data.get("source", ""),
				"visuals": definition.get("visuals", {})
			})

	return result


## Get all active effects for a target.
func get_all_effects_for_target(target_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not active_effects.has(target_id):
		return result

	for effect_id in active_effects[target_id]:
		var effect_data: Dictionary = active_effects[target_id][effect_id]
		var definition: Dictionary = effect_data.get("definition", {})

		result.append({
			"id": effect_id,
			"name": definition.get("name", effect_id),
			"description": definition.get("description", ""),
			"type": definition.get("type", "unknown"),
			"category": definition.get("category", ""),
			"turns_remaining": effect_data.get("turns_remaining", -1),
			"stacks": effect_data.get("stacks", 1),
			"source": effect_data.get("source", ""),
			"visuals": definition.get("visuals", {})
		})

	return result

# =============================================================================
# DURATION AND TRIGGERS
# =============================================================================

func _on_turn_started(turn_number: int, _day: int, _period: String) -> void:
	_current_turn = turn_number
	_tick_all_effects()
	_process_turn_triggers()


func _tick_all_effects() -> void:
	for target_id in active_effects.keys():
		var to_expire: Array[String] = []
		
		for effect_id in active_effects[target_id]:
			var effect_data: Dictionary = active_effects[target_id][effect_id]
			var turns_remaining: int = effect_data.get("turns_remaining", -1)
			
			if turns_remaining > 0:
				turns_remaining -= 1
				effect_data["turns_remaining"] = turns_remaining
				effect_ticked.emit(target_id, effect_id, turns_remaining)
				
				if turns_remaining <= 0:
					to_expire.append(effect_id)
			
			# Check for disease progression
			var definition: Dictionary = effect_data.get("definition", {})
			var conditions: Dictionary = definition.get("conditions", {})
			var progresses_to: String = conditions.get("progresses_to", "")
			var progress_chance: float = conditions.get("progress_chance", 0.0)
			
			if not progresses_to.is_empty() and randf() < progress_chance:
				to_expire.append(effect_id)
				call_deferred("apply_effect", target_id, progresses_to, effect_id)
		
		for effect_id in to_expire:
			_remove_effect_internal(target_id, effect_id, "expired")


func _process_turn_triggers() -> void:
	process_trigger("player", "turn_start", {})


## Process a trigger event for a target.
func process_trigger(target_id: String, event: String, context: Dictionary = {}) -> void:
	if not active_effects.has(target_id):
		return
	
	for effect_id in active_effects[target_id]:
		var effect_data: Dictionary = active_effects[target_id][effect_id]
		var definition: Dictionary = effect_data.get("definition", {})
		var triggers: Array = definition.get("triggers", [])
		
		for trigger in triggers:
			if trigger.get("event", "") != event:
				continue
			
			var chance: float = trigger.get("chance", 1.0)
			if randf() > chance:
				continue
			
			var result := _execute_trigger_action(target_id, effect_id, trigger, context)
			trigger_fired.emit(target_id, effect_id, trigger, result)


func _execute_trigger_action(target_id: String, effect_id: String, trigger: Dictionary, context: Dictionary) -> Dictionary:
	var action: String = trigger.get("action", "")
	var value = trigger.get("value", 0)
	var result := {"action": action, "success": true}
	
	match action:
		"damage":
			if target_id == "player":
				var survival_manager = get_tree().get_first_node_in_group("survival_manager")
				if survival_manager and survival_manager.has_method("take_damage"):
					survival_manager.take_damage(int(value), effect_id)
					result["damage"] = value
		
		"heal":
			if target_id == "player":
				var survival_manager = get_tree().get_first_node_in_group("survival_manager")
				if survival_manager and survival_manager.has_method("heal"):
					survival_manager.heal(int(value))
					result["healed"] = value
		
		"apply_effect":
			if value is String:
				apply_effect(target_id, value, effect_id)
				result["applied"] = value
		
		"remove_effect":
			if value is String:
				remove_effect(target_id, value)
				result["removed"] = value
		
		"bonus_initiative":
			result["initiative_bonus"] = value
		
		"guarantee_hit":
			result["guaranteed_hit"] = true
		
		_:
			# Custom action - emit for external handling
			result["custom"] = true
	
	return result


func _process_instant_effect(target_id: String, effect_id: String, definition: Dictionary) -> void:
	var triggers: Array = definition.get("triggers", [])
	
	for trigger in triggers:
		if trigger.get("event", "") == "instant":
			_execute_trigger_action(target_id, effect_id, trigger, {})

# =============================================================================
# TALENT-SPECIFIC API
# =============================================================================

## Get all available talents (for character creation/trainers).
func get_all_talents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for effect_id in effect_categories.get("talents", []):
		var definition: Dictionary = effect_definitions[effect_id]
		result.append({
			"id": effect_id,
			"name": definition.get("name", effect_id),
			"description": definition.get("description", ""),
			"category": definition.get("category", ""),
			"acquisition": definition.get("acquisition", "purchased"),
			"prerequisites": definition.get("prerequisites", {}),
			"visuals": definition.get("visuals", {})
		})
	
	return result


## Get talents that can be selected at character creation.
func get_starting_talents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for talent in get_all_talents():
		if talent.get("acquisition", "") == "starting":
			result.append(talent)
	
	return result


## Check if a talent's prerequisites are met.
func can_acquire_talent(target_id: String, talent_id: String) -> Dictionary:
	if not effect_definitions.has(talent_id):
		return {"can_acquire": false, "reason": "unknown_talent"}
	
	var definition: Dictionary = effect_definitions[talent_id]
	
	if has_effect(target_id, talent_id):
		return {"can_acquire": false, "reason": "already_has"}
	
	var prereqs: Dictionary = definition.get("prerequisites", {})
	var missing_stats: Array = []
	var missing_skills: Array = []
	
	if prereqs.has("stats") and _player_stats:
		for stat_name in prereqs["stats"]:
			var required: int = prereqs["stats"][stat_name]
			var current: int = _player_stats.get_effective_stat(stat_name)
			if current < required:
				missing_stats.append({
					"stat": stat_name,
					"required": required,
					"current": current
				})
	
	if prereqs.has("skills"):
		var skill_manager = get_tree().get_first_node_in_group("skill_manager")
		if skill_manager:
			for skill_name in prereqs["skills"]:
				var required: int = prereqs["skills"][skill_name]
				var current: int = skill_manager.get_skill_level(skill_name)
				if current < required:
					missing_skills.append({
						"skill": skill_name,
						"required": required,
						"current": current
					})
	
	if not missing_stats.is_empty() or not missing_skills.is_empty():
		return {
			"can_acquire": false,
			"reason": "prerequisites_not_met",
			"missing_stats": missing_stats,
			"missing_skills": missing_skills
		}
	
	return {"can_acquire": true}

# =============================================================================
# SERIALIZATION
# =============================================================================

## Convert all active effects to dictionary for saving.
func to_dict() -> Dictionary:
	var result: Dictionary = {}
	
	for target_id in active_effects:
		result[target_id] = {}
		
		for effect_id in active_effects[target_id]:
			var effect_data: Dictionary = active_effects[target_id][effect_id]
			
			result[target_id][effect_id] = {
				"turns_remaining": effect_data.get("turns_remaining", -1),
				"stacks": effect_data.get("stacks", 1),
				"source": effect_data.get("source", ""),
				"applied_turn": effect_data.get("applied_turn", 0)
			}
	
	return result


## Load active effects from dictionary.
func from_dict(data: Dictionary) -> void:
	active_effects.clear()
	modifier_cache.clear()
	
	for target_id in data:
		for effect_id in data[target_id]:
			if not effect_definitions.has(effect_id):
				push_warning("EffectManager: Unknown effect '%s' in save data, skipping" % effect_id)
				continue
			
			var saved_data: Dictionary = data[target_id][effect_id]
			
			if not active_effects.has(target_id):
				active_effects[target_id] = {}
			
			active_effects[target_id][effect_id] = {
				"definition": effect_definitions[effect_id],
				"turns_remaining": saved_data.get("turns_remaining", -1),
				"stacks": saved_data.get("stacks", 1),
				"source": saved_data.get("source", ""),
				"applied_turn": saved_data.get("applied_turn", 0)
			}
		
		_recalculate_modifiers(target_id)
	
	print("EffectManager: Loaded from save data")

# =============================================================================
# DEBUG
# =============================================================================

## Print all active effects.
func debug_print_effects(target_id: String = "player") -> void:
	print("=== Active Effects for %s ===" % target_id)
	
	var effects := get_active_effects(target_id)
	if effects.is_empty():
		print("  (none)")
		return
	
	for effect in effects:
		var duration_str := "permanent"
		if effect["turns_remaining"] >= 0:
			duration_str = "%d turns" % effect["turns_remaining"]
		
		var stack_str := ""
		if effect["stacks"] > 1:
			stack_str = " x%d" % effect["stacks"]
		
		print("  [%s] %s%s (%s) - %s" % [
			effect["type"],
			effect["name"],
			stack_str,
			duration_str,
			effect["description"]
		])
	
	print("--- Modifier Cache ---")
	if modifier_cache.has(target_id):
		for cache_key in modifier_cache[target_id]:
			var mod: Dictionary = modifier_cache[target_id][cache_key]
			print("  %s.%s: %+.1f (%s)" % [mod["target"], mod["name"], mod["value"], mod["type"]])


## Apply an effect for testing.
func debug_apply_effect(effect_id: String, target_id: String = "player") -> void:
	apply_effect(target_id, effect_id, "debug")


## Remove an effect for testing.
func debug_remove_effect(effect_id: String, target_id: String = "player") -> void:
	remove_effect(target_id, effect_id)


## List all available effects.
func debug_list_effects() -> void:
	print("=== Available Effects ===")
	for category in effect_categories:
		print("--- %s ---" % category)
		for effect_id in effect_categories[category]:
			var def: Dictionary = effect_definitions[effect_id]
			print("  %s: %s" % [effect_id, def.get("name", effect_id)])

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
			3: event_bus.emit_signal(signal_name, args[0], args[1], args[2])
