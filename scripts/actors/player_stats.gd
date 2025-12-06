# player_stats.gd
# Manages the 8 core player stats, temporary modifiers, and stat checks.
# Should be a child of the Player node.
#
# STATS (1-8 range, 3 = trained, 7-8 = heroic):
# - grit: Health pool, resistance, intimidation
# - reflex: Combat speed, dodging, initiative
# - aim: Ranged accuracy, perception
# - wit: Problem-solving, learning speed
# - charm: Persuasion, trading, social
# - fortitude: Disease/poison/fatigue resistance
# - stealth: Avoiding detection, ambush
# - spirit: Willpower, fear resistance, supernatural
#
# MODIFIER SYSTEM:
# Modifiers are temporary stat adjustments keyed by source.
# Example: sleep deprivation adds a modifier, removing it restores stats.
# Modifiers can be percentage-based or flat values.
#
# ROLL SYSTEM:
# d10 + effective_stat vs difficulty (or d10 + stat + skill for skill checks)
# Difficulties: trivial(5), easy(8), medium(12), hard(15), very_hard(18), legendary(21)

extends Node
class_name PlayerStats

# =============================================================================
# CONSTANTS
# =============================================================================

const CONFIG_PATH := "res://data/character/stats_config.json"

## Fallback values if config fails to load
const FALLBACK_STAT_MIN: int = 1
const FALLBACK_STAT_MAX: int = 8
const FALLBACK_ROLL_DIE: int = 10

const FALLBACK_STAT_NAMES: Array[String] = [
	"grit", "reflex", "aim", "wit", "charm", "fortitude", "stealth", "spirit"
]

const FALLBACK_DEFAULT_STATS: Dictionary = {
	"grit": 3,
	"reflex": 3,
	"aim": 3,
	"wit": 3,
	"charm": 3,
	"fortitude": 3,
	"stealth": 3,
	"spirit": 3
}

const FALLBACK_DIFFICULTIES: Dictionary = {
	"trivial": 5,
	"easy": 8,
	"medium": 12,
	"hard": 15,
	"very_hard": 18,
	"legendary": 21
}

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a base stat changes.
signal stat_changed(stat: String, old_value: int, new_value: int)

## Emitted when a modifier is added.
signal modifier_added(source: String, stat: String, value: int)

## Emitted when a modifier is removed.
signal modifier_removed(source: String)

## Emitted after a stat check is rolled.
signal stat_check_rolled(stat: String, result: Dictionary)

## Emitted when max HP changes (due to grit change).
signal max_hp_changed(old_max: int, new_max: int)

# =============================================================================
# CONFIGURATION (loaded from JSON)
# =============================================================================

var stat_min: int = FALLBACK_STAT_MIN
var stat_max: int = FALLBACK_STAT_MAX
var roll_die_size: int = FALLBACK_ROLL_DIE
var stat_names: Array[String] = []
var stat_config: Dictionary = {}
var difficulty_levels: Dictionary = {}
var stat_descriptions: Dictionary = {}

# =============================================================================
# STATE
# =============================================================================

## Base stat values (before modifiers).
var base_stats: Dictionary = {}

## Active temporary modifiers.
## Each modifier: {source: String, stat: String, type: String, value: int}
## type is "percentage" or "flat"
## stat can be a stat name or "all" for all stats
var modifiers: Array[Dictionary] = []

## Cached max HP (recalculated when grit changes)
var _cached_max_hp: int = 16

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()
	_initialize_stats()
	add_to_group("player_stats")
	print("PlayerStats: Initialized with %d stats" % stat_names.size())


func _load_config() -> void:
	var config: Dictionary = {}
	
	# Try DataLoader first
	var data_loader = get_node_or_null("/root/DataLoader")
	if data_loader and data_loader.has_method("load_json"):
		config = data_loader.load_json(CONFIG_PATH)
	
	# Fallback to direct file loading
	if config.is_empty() and FileAccess.file_exists(CONFIG_PATH):
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			var error := json.parse(file.get_as_text())
			file.close()
			if error == OK:
				config = json.data
	
	# Apply config or use fallbacks
	if not config.is_empty():
		_apply_config(config)
		print("PlayerStats: Loaded config from %s" % CONFIG_PATH)
	else:
		_use_fallback_config()
		print("PlayerStats: Using fallback configuration")


func _apply_config(config: Dictionary) -> void:
	# Load stat rules
	var rules: Dictionary = config.get("stat_rules", {})
	stat_min = rules.get("min_value", FALLBACK_STAT_MIN)
	stat_max = rules.get("max_value", FALLBACK_STAT_MAX)
	roll_die_size = rules.get("roll_die_size", FALLBACK_ROLL_DIE)
	
	# Load difficulty levels
	difficulty_levels = config.get("difficulty_levels", FALLBACK_DIFFICULTIES)
	
	# Load stat descriptions
	stat_descriptions = config.get("stat_descriptions", {})
	
	# Load stat definitions
	stat_config = config.get("stats", {})
	stat_names.clear()
	for stat_name in stat_config:
		stat_names.append(stat_name)
	
	# Sort stat names for consistent ordering
	stat_names.sort()


func _use_fallback_config() -> void:
	stat_min = FALLBACK_STAT_MIN
	stat_max = FALLBACK_STAT_MAX
	roll_die_size = FALLBACK_ROLL_DIE
	stat_names = FALLBACK_STAT_NAMES.duplicate()
	difficulty_levels = FALLBACK_DIFFICULTIES.duplicate()
	stat_config = {}


func _initialize_stats() -> void:
	base_stats.clear()
	
	if not stat_config.is_empty():
		# Initialize from config
		for stat_name in stat_names:
			base_stats[stat_name] = stat_config.get(stat_name, {}).get("default", 3)
	else:
		# Use fallback defaults
		base_stats = FALLBACK_DEFAULT_STATS.duplicate()
	
	_update_cached_max_hp()


## Initialize stats from a dictionary (for character creation or loading).
func initialize_from_dict(stats_dict: Dictionary) -> void:
	for stat_name in stat_names:
		if stats_dict.has(stat_name):
			var value: int = clampi(stats_dict[stat_name], stat_min, stat_max)
			base_stats[stat_name] = value
	
	_update_cached_max_hp()
	print("PlayerStats: Initialized from dictionary")

# =============================================================================
# STAT QUERIES
# =============================================================================

## Get the base (unmodified) value of a stat.
func get_base_stat(stat: String) -> int:
	var stat_lower := stat.to_lower()
	return base_stats.get(stat_lower, 0)


## Get the effective (modified) value of a stat.
func get_effective_stat(stat: String) -> int:
	var stat_lower := stat.to_lower()
	var base_value: int = get_base_stat(stat_lower)
	
	if base_value == 0:
		push_warning("PlayerStats: Unknown stat '%s'" % stat)
		return 0
	
	var flat_total: int = 0
	var percentage_total: float = 0.0
	
	for modifier in modifiers:
		var mod_stat: String = modifier.get("stat", "")
		if mod_stat == stat_lower or mod_stat == "all":
			var mod_type: String = modifier.get("type", "flat")
			var mod_value: int = modifier.get("value", 0)
			
			if mod_type == "percentage":
				percentage_total += mod_value
			else:
				flat_total += mod_value
	
	# Apply percentage first, then flat
	var modified: float = base_value * (1.0 + percentage_total / 100.0)
	modified += flat_total
	
	# Clamp to valid range (allow going below 1 for severe penalties, but not below 0)
	return maxi(0, roundi(modified))


## Get all base stats as a dictionary.
func get_all_base_stats() -> Dictionary:
	return base_stats.duplicate()


## Get all effective stats as a dictionary.
func get_all_effective_stats() -> Dictionary:
	var effective := {}
	for stat_name in stat_names:
		effective[stat_name] = get_effective_stat(stat_name)
	return effective


## Check if a stat name is valid.
func is_valid_stat(stat: String) -> bool:
	return stat.to_lower() in stat_names


## Get stat info from config.
func get_stat_info(stat: String) -> Dictionary:
	var stat_lower := stat.to_lower()
	return stat_config.get(stat_lower, {})


## Get human-readable description of a stat value.
func get_stat_value_description(value: int) -> String:
	return stat_descriptions.get(str(value), "Unknown")


## Get list of all stat names.
func get_stat_names() -> Array[String]:
	return stat_names.duplicate()

# =============================================================================
# STAT MODIFICATION
# =============================================================================

## Set a base stat value (for leveling, permanent changes).
func set_base_stat(stat: String, value: int) -> void:
	var stat_lower := stat.to_lower()
	if not is_valid_stat(stat_lower):
		push_warning("PlayerStats: Cannot set unknown stat '%s'" % stat)
		return
	
	var old_value: int = base_stats.get(stat_lower, 0)
	var new_value: int = clampi(value, stat_min, stat_max)
	
	if old_value != new_value:
		base_stats[stat_lower] = new_value
		stat_changed.emit(stat_lower, old_value, new_value)
		_emit_to_event_bus("player_stat_changed", [stat_lower, old_value, new_value])
		print("PlayerStats: %s changed from %d to %d" % [stat_lower, old_value, new_value])
		
		# Update max HP if grit changed
		if stat_lower == "grit":
			_update_cached_max_hp()


## Increase a base stat by amount (for leveling).
func increase_base_stat(stat: String, amount: int = 1) -> void:
	var current := get_base_stat(stat)
	set_base_stat(stat, current + amount)


## Decrease a base stat by amount (for permanent penalties).
func decrease_base_stat(stat: String, amount: int = 1) -> void:
	var current := get_base_stat(stat)
	set_base_stat(stat, current - amount)

# =============================================================================
# MODIFIER SYSTEM
# =============================================================================

## Add a temporary modifier.
## @param source: Unique identifier for this modifier (for removal).
## @param stat: Stat to modify ("grit", "reflex", etc.) or "all".
## @param type: "percentage" or "flat".
## @param value: Modifier value (negative for penalties).
func add_modifier(source: String, stat: String, type: String, value: int) -> void:
	var stat_lower := stat.to_lower()
	
	# Validate stat (allow "all")
	if stat_lower != "all" and not is_valid_stat(stat_lower):
		push_warning("PlayerStats: Cannot add modifier for unknown stat '%s'" % stat)
		return
	
	# Validate type
	if type != "percentage" and type != "flat":
		push_warning("PlayerStats: Invalid modifier type '%s', using 'flat'" % type)
		type = "flat"
	
	var modifier := {
		"source": source,
		"stat": stat_lower,
		"type": type,
		"value": value
	}
	
	modifiers.append(modifier)
	modifier_added.emit(source, stat_lower, value)
	_emit_to_event_bus("player_modifier_added", [source, stat_lower, value])
	
	print("PlayerStats: Added modifier '%s' (%s %+d%s to %s)" % [
		source, type, value, "%" if type == "percentage" else "", stat_lower
	])
	
	# Update max HP if grit modifier
	if stat_lower == "grit" or stat_lower == "all":
		_update_cached_max_hp()


## Remove all modifiers from a specific source.
func remove_modifier(source: String) -> void:
	var removed := false
	var affected_grit := false
	var i := modifiers.size() - 1
	
	while i >= 0:
		if modifiers[i].get("source", "") == source:
			var mod_stat: String = modifiers[i].get("stat", "")
			if mod_stat == "grit" or mod_stat == "all":
				affected_grit = true
			modifiers.remove_at(i)
			removed = true
		i -= 1
	
	if removed:
		modifier_removed.emit(source)
		_emit_to_event_bus("player_modifier_removed", [source])
		print("PlayerStats: Removed modifier '%s'" % source)
		
		if affected_grit:
			_update_cached_max_hp()


## Remove all modifiers whose source starts with a prefix.
## Useful for removing all modifiers from a system (e.g., "fatigue_").
func remove_modifiers_by_prefix(prefix: String) -> void:
	var sources_to_remove: Array[String] = []
	
	for modifier in modifiers:
		var source: String = modifier.get("source", "")
		if source.begins_with(prefix):
			if source not in sources_to_remove:
				sources_to_remove.append(source)
	
	for source in sources_to_remove:
		remove_modifier(source)


## Check if a modifier from a source exists.
func has_modifier(source: String) -> bool:
	for modifier in modifiers:
		if modifier.get("source", "") == source:
			return true
	return false


## Get all modifiers affecting a specific stat.
func get_modifiers_for_stat(stat: String) -> Array[Dictionary]:
	var stat_lower := stat.to_lower()
	var result: Array[Dictionary] = []
	
	for modifier in modifiers:
		var mod_stat: String = modifier.get("stat", "")
		if mod_stat == stat_lower or mod_stat == "all":
			result.append(modifier.duplicate())
	
	return result


## Get all active modifiers.
func get_all_modifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for modifier in modifiers:
		result.append(modifier.duplicate())
	return result


## Clear all temporary modifiers.
func clear_all_modifiers() -> void:
	var sources: Array[String] = []
	for modifier in modifiers:
		var source: String = modifier.get("source", "")
		if source not in sources:
			sources.append(source)
	
	modifiers.clear()
	
	for source in sources:
		modifier_removed.emit(source)
		_emit_to_event_bus("player_modifier_removed", [source])
	
	_update_cached_max_hp()
	print("PlayerStats: Cleared all modifiers")

# =============================================================================
# ROLL SYSTEM
# =============================================================================

## Perform a stat check: d10 + effective_stat vs difficulty.
## @param stat: The stat to use for the check.
## @param difficulty: Target number to meet or exceed (or difficulty name).
## @param skill_bonus: Optional skill bonus to add (default 0).
## @return Dictionary with roll details.
func roll_check(stat: String, difficulty, skill_bonus: int = 0) -> Dictionary:
	var stat_lower := stat.to_lower()
	var effective_value := get_effective_stat(stat_lower)
	
	# Handle difficulty as string or int
	var dc: int
	if difficulty is String:
		dc = difficulty_levels.get(difficulty.to_lower(), 12)
	else:
		dc = int(difficulty)
	
	# Roll d10 (1-10)
	var roll: int = randi_range(1, roll_die_size)
	var total: int = roll + effective_value + skill_bonus
	var success: bool = total >= dc
	var margin: int = total - dc
	
	var result := {
		"success": success,
		"roll": roll,
		"stat_name": stat_lower,
		"stat_value": effective_value,
		"skill_bonus": skill_bonus,
		"total": total,
		"difficulty": dc,
		"margin": margin,
		"critical": roll == roll_die_size,  # Natural 10
		"fumble": roll == 1  # Natural 1
	}
	
	stat_check_rolled.emit(stat_lower, result)
	_emit_to_event_bus("player_stat_check_rolled", [stat_lower, result])
	
	var skill_str := " + %d skill" % skill_bonus if skill_bonus > 0 else ""
	print("PlayerStats: %s check - rolled %d + %d%s = %d vs DC %d → %s (margin %+d)" % [
		stat_lower, roll, effective_value, skill_str, total, dc,
		"SUCCESS" if success else "FAILURE", margin
	])
	
	return result


## Roll a check with advantage (roll twice, take better).
func roll_check_advantage(stat: String, difficulty, skill_bonus: int = 0) -> Dictionary:
	var roll1 := roll_check(stat, difficulty, skill_bonus)
	var roll2 := roll_check(stat, difficulty, skill_bonus)
	
	# Take the better result
	if roll2["total"] > roll1["total"]:
		roll2["had_advantage"] = true
		return roll2
	else:
		roll1["had_advantage"] = true
		return roll1


## Roll a check with disadvantage (roll twice, take worse).
func roll_check_disadvantage(stat: String, difficulty, skill_bonus: int = 0) -> Dictionary:
	var roll1 := roll_check(stat, difficulty, skill_bonus)
	var roll2 := roll_check(stat, difficulty, skill_bonus)
	
	# Take the worse result
	if roll2["total"] < roll1["total"]:
		roll2["had_disadvantage"] = true
		return roll2
	else:
		roll1["had_disadvantage"] = true
		return roll1


## Get the difficulty value for a named difficulty.
func get_difficulty(df_name: String) -> int:
	return difficulty_levels.get(df_name.to_lower(), 12)

# =============================================================================
# DERIVED STATS
# =============================================================================

## Calculate max HP based on Grit (10 + Grit × 2).
func get_max_hp() -> int:
	return _cached_max_hp


func _update_cached_max_hp() -> void:
	var old_max := _cached_max_hp
	_cached_max_hp = 10 + get_effective_stat("grit") * 2
	
	if old_max != _cached_max_hp:
		max_hp_changed.emit(old_max, _cached_max_hp)
		_emit_to_event_bus("player_max_hp_changed", [old_max, _cached_max_hp])


## Calculate initiative bonus based on Reflex.
func get_initiative_bonus() -> int:
	return get_effective_stat("reflex")


## Calculate fear threshold based on Spirit.
func get_fear_threshold() -> int:
	return 5 + get_effective_stat("spirit")


## Calculate skill XP multiplier based on Wit.
func get_skill_xp_multiplier() -> float:
	var wit := get_effective_stat("wit")
	return 1.0 + (wit - 3) * 0.05


## Calculate price modifier based on Charm.
func get_price_modifier() -> float:
	var charm := get_effective_stat("charm")
	return 1.0 - (charm - 3) * 0.05


## Get all derived stats as a dictionary.
func get_derived_stats() -> Dictionary:
	return {
		"max_hp": get_max_hp(),
		"initiative_bonus": get_initiative_bonus(),
		"fear_threshold": get_fear_threshold(),
		"skill_xp_multiplier": get_skill_xp_multiplier(),
		"price_modifier": get_price_modifier()
	}

# =============================================================================
# SERIALIZATION
# =============================================================================

## Convert stats to dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"base_stats": base_stats.duplicate(),
		"modifiers": get_all_modifiers()
	}


## Load stats from dictionary.
func from_dict(data: Dictionary) -> void:
	# Load base stats
	if data.has("base_stats"):
		for stat_name in stat_names:
			if data["base_stats"].has(stat_name):
				base_stats[stat_name] = clampi(
					data["base_stats"][stat_name], 
					stat_min, 
					stat_max
				)
	
	# Load modifiers
	modifiers.clear()
	if data.has("modifiers"):
		for mod_data in data["modifiers"]:
			modifiers.append({
				"source": mod_data.get("source", "unknown"),
				"stat": mod_data.get("stat", "all"),
				"type": mod_data.get("type", "flat"),
				"value": mod_data.get("value", 0)
			})
	
	_update_cached_max_hp()
	print("PlayerStats: Loaded from save data")

# =============================================================================
# DEBUG
# =============================================================================

## Print current stats to console (debug).
func debug_print_stats() -> void:
	print("=== Player Stats ===")
	for stat_name in stat_names:
		var base := get_base_stat(stat_name)
		var effective := get_effective_stat(stat_name)
		var info: Dictionary = get_stat_info(stat_name)
		var display_name: String = info.get("name", stat_name.capitalize())
		
		if base != effective:
			print("  %s: %d (base %d)" % [display_name, effective, base])
		else:
			print("  %s: %d" % [display_name, base])
	
	if modifiers.size() > 0:
		print("--- Active Modifiers ---")
		for mod in modifiers:
			print("  [%s] %s %+d%s to %s" % [
				mod["source"],
				mod["type"],
				mod["value"],
				"%" if mod["type"] == "percentage" else "",
				mod["stat"]
			])
	
	print("--- Derived ---")
	var derived := get_derived_stats()
	for key in derived:
		print("  %s: %s" % [key, derived[key]])


## Set a stat directly (debug only).
func debug_set_stat(stat: String, value: int) -> void:
	set_base_stat(stat, value)

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
