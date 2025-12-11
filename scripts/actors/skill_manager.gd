# skill_manager.gd
# Manages the 18 player skills with learn-by-doing XP progression.
# Should be a child of the Player node alongside PlayerStats.
#
# SKILLS (0-5 range):
# - 0: Untrained
# - 1: Novice
# - 2: Competent
# - 3: Skilled (trainer required for 4+)
# - 4: Expert
# - 5: Master
#
# XP SYSTEM:
# - Each skill use grants 1-5 XP based on difficulty
# - 100 XP per level
# - Diminishing returns for repeated trivial tasks
# - Levels 4-5 require finding a trainer
#
# ROLL FORMULA:
# d10 + linked_stat + skill_level vs difficulty

extends Node
class_name SkillManager

# =============================================================================
# CONSTANTS
# =============================================================================

const CONFIG_PATH := "res://data/character/skills_config.json"

const FALLBACK_SKILL_NAMES: Array[String] = [
	"pistol", "rifle", "shotgun", "blades", "axes", "brawling",
	"tracking", "foraging", "hunting", "medicine", "horsemanship",
	"persuasion", "intimidation", "deception", "gambling",
	"lockpicking", "crafting", "appraisal", "lore"
]

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a skill gains XP.
signal skill_xp_gained(skill: String, xp_amount: int, new_total: int)

## Emitted when a skill levels up.
signal skill_level_up(skill: String, old_level: int, new_level: int)

## Emitted when level up is blocked by trainer requirement.
signal skill_level_blocked(skill: String, current_level: int, reason: String)

## Emitted after a skill check is rolled.
signal skill_check_rolled(skill: String, result: Dictionary)

# =============================================================================
# CONFIGURATION (loaded from JSON)
# =============================================================================

var skill_config: Dictionary = {}
var category_config: Dictionary = {}
var skill_rules: Dictionary = {}
var xp_values: Dictionary = {}
var diminishing_config: Dictionary = {}

var skill_names: Array[String] = []
var min_level: int = 0
var max_level: int = 5
var xp_per_level: int = 100
var trainer_required_above: int = 3

# =============================================================================
# STATE
# =============================================================================

## Current skill levels (0-5).
var skill_levels: Dictionary = {}

## Current XP for each skill (resets to 0 on level up).
var skill_xp: Dictionary = {}

## Tracks recent actions for diminishing returns.
## Format: {skill: {action: {count: int, last_turn: int}}}
var recent_actions: Dictionary = {}

## Skills that have met XP requirement but need trainer.
var pending_level_ups: Dictionary = {}

## Reference to PlayerStats for linked stat bonuses.
var _player_stats: PlayerStats = null

## Current turn number for diminishing returns tracking.
var _current_turn: int = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()
	_initialize_skills()
	_connect_signals()
	add_to_group("skill_manager")
	print("SkillManager: Initialized with %d skills" % skill_names.size())


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
	
	if not config.is_empty():
		_apply_config(config)
		print("SkillManager: Loaded config from %s" % CONFIG_PATH)
	else:
		_use_fallback_config()
		print("SkillManager: Using fallback configuration")


func _apply_config(config: Dictionary) -> void:
	skill_config = config.get("skills", {})
	category_config = config.get("categories", {})
	skill_rules = config.get("skill_rules", {})
	xp_values = config.get("xp_values", {})
	diminishing_config = config.get("diminishing_returns", {})
	
	# Extract skill names
	skill_names.clear()
	for skill_name in skill_config:
		skill_names.append(skill_name)
	skill_names.sort()
	
	# Apply rules
	min_level = skill_rules.get("min_level", 0)
	max_level = skill_rules.get("max_level", 5)
	xp_per_level = skill_rules.get("xp_per_level", 100)
	trainer_required_above = skill_rules.get("trainer_required_above", 3)


func _use_fallback_config() -> void:
	skill_names = FALLBACK_SKILL_NAMES.duplicate()
	min_level = 0
	max_level = 5
	xp_per_level = 100
	trainer_required_above = 3
	xp_values = {"trivial": 1, "easy": 2, "moderate": 3, "difficult": 4, "extreme": 5}
	diminishing_config = {"enabled": true, "same_action_threshold": 3, "same_action_penalty": 0.5, "reset_after_turns": 6}


func _initialize_skills() -> void:
	skill_levels.clear()
	skill_xp.clear()
	recent_actions.clear()
	pending_level_ups.clear()
	
	for skill_name in skill_names:
		skill_levels[skill_name] = 0
		skill_xp[skill_name] = 0
		recent_actions[skill_name] = {}


func _connect_signals() -> void:
	# Connect to TimeManager for turn tracking
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_signal("turn_started"):
		time_manager.turn_started.connect(_on_turn_started)
	
	# Find PlayerStats reference after a frame
	await get_tree().process_frame
	_player_stats = get_tree().get_first_node_in_group("player_stats")


## Initialize skills from a dictionary (for character creation or loading).
func initialize_from_dict(data: Dictionary) -> void:
	if data.has("levels"):
		for skill_name in skill_names:
			if data["levels"].has(skill_name):
				skill_levels[skill_name] = clampi(data["levels"][skill_name], min_level, max_level)
	
	if data.has("xp"):
		for skill_name in skill_names:
			if data["xp"].has(skill_name):
				skill_xp[skill_name] = maxi(0, data["xp"][skill_name])
	
	if data.has("pending_level_ups"):
		pending_level_ups = data["pending_level_ups"].duplicate()
	
	print("SkillManager: Initialized from dictionary")

# =============================================================================
# SKILL QUERIES
# =============================================================================

## Get the current level of a skill.
func get_skill_level(skill: String) -> int:
	var skill_lower := skill.to_lower()
	return skill_levels.get(skill_lower, 0)


## Get the current XP of a skill.
func get_skill_xp(skill: String) -> int:
	var skill_lower := skill.to_lower()
	return skill_xp.get(skill_lower, 0)


## Get XP progress as percentage (0.0 - 1.0).
func get_skill_xp_progress(skill: String) -> float:
	var xp := get_skill_xp(skill)
	return float(xp) / float(xp_per_level)


## Check if a skill name is valid.
func is_valid_skill(skill: String) -> bool:
	return skill.to_lower() in skill_names


## Get skill info from config.
func get_skill_info(skill: String) -> Dictionary:
	var skill_lower := skill.to_lower()
	return skill_config.get(skill_lower, {})


## Get the linked stat for a skill.
func get_linked_stat(skill: String) -> String:
	var info := get_skill_info(skill)
	return info.get("linked_stat", "wit")


## Get the category for a skill.
func get_skill_category(skill: String) -> String:
	var info := get_skill_info(skill)
	return info.get("category", "utility")


## Get all skills in a category.
func get_skills_in_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for skill_name in skill_names:
		if get_skill_category(skill_name) == category:
			result.append(skill_name)
	return result


## Get all skill names.
func get_skill_names() -> Array[String]:
	return skill_names.duplicate()


## Get all category names.
func get_category_names() -> Array[String]:
	var result: Array[String] = []
	for cat in category_config:
		result.append(cat)
	return result


## Check if skill can level up (has pending XP but needs trainer).
func has_pending_level_up(skill: String) -> bool:
	var skill_lower := skill.to_lower()
	return pending_level_ups.has(skill_lower)


## Get human-readable description of a skill level.
func get_level_description(level: int) -> String:
	var descriptions: Dictionary = skill_rules.get("level_descriptions", {})
	return descriptions.get(str(level), "Unknown")

# =============================================================================
# XP AND LEVELING
# =============================================================================

## Grant XP to a skill.
## @param skill: The skill to grant XP to.
## @param action: The action that generated XP (for diminishing returns).
## @param difficulty: XP amount or difficulty name ("trivial", "easy", etc.).
## @return The actual XP gained after modifiers.
func grant_xp(skill: String, action: String, difficulty = "moderate") -> int:
	var skill_lower := skill.to_lower()
	
	if not is_valid_skill(skill_lower):
		push_warning("SkillManager: Unknown skill '%s'" % skill)
		return 0
	
	# Already at max level
	if skill_levels[skill_lower] >= max_level:
		return 0
	
	# Calculate base XP
	var base_xp: int
	if difficulty is String:
		base_xp = xp_values.get(difficulty.to_lower(), 3)
	else:
		base_xp = int(difficulty)
	
	# Apply Wit multiplier from PlayerStats
	var xp_multiplier: float = 1.0
	if _player_stats and _player_stats.has_method("get_skill_xp_multiplier"):
		xp_multiplier = _player_stats.get_skill_xp_multiplier()
	
	# Apply diminishing returns
	var diminishing_mult := _calculate_diminishing_returns(skill_lower, action)
	
	# Calculate final XP
	var final_xp := roundi(base_xp * xp_multiplier * diminishing_mult)
	final_xp = maxi(1, final_xp)  # Always grant at least 1 XP
	
	# Track action for diminishing returns
	_track_action(skill_lower, action)
	
	# Add XP
	skill_xp[skill_lower] += final_xp
	
	skill_xp_gained.emit(skill_lower, final_xp, skill_xp[skill_lower])
	_emit_to_event_bus("player_skill_xp_gained", [skill_lower, final_xp, skill_xp[skill_lower]])
	
	print("SkillManager: %s gained %d XP (%d/%d)" % [
		skill_lower, final_xp, skill_xp[skill_lower], xp_per_level
	])
	
	# Check for level up
	_check_level_up(skill_lower)
	
	return final_xp


## Force a skill to level up (trainer interaction).
func train_skill(skill: String) -> bool:
	var skill_lower := skill.to_lower()
	
	if not is_valid_skill(skill_lower):
		push_warning("SkillManager: Unknown skill '%s'" % skill)
		return false
	
	var current_level:int = skill_levels[skill_lower]
	
	# Check if there's a pending level up
	if pending_level_ups.has(skill_lower):
		var old_level := current_level
		skill_levels[skill_lower] = current_level + 1
		skill_xp[skill_lower] = pending_level_ups[skill_lower]
		pending_level_ups.erase(skill_lower)
		
		skill_level_up.emit(skill_lower, old_level, skill_levels[skill_lower])
		_emit_to_event_bus("player_skill_level_up", [skill_lower, old_level, skill_levels[skill_lower]])
		
		print("SkillManager: %s trained to level %d" % [skill_lower, skill_levels[skill_lower]])
		return true
	
	# Can also be used to train without pending XP (paid training)
	if current_level < max_level:
		var old_level := current_level
		skill_levels[skill_lower] = current_level + 1
		skill_xp[skill_lower] = 0
		
		skill_level_up.emit(skill_lower, old_level, skill_levels[skill_lower])
		_emit_to_event_bus("player_skill_level_up", [skill_lower, old_level, skill_levels[skill_lower]])
		
		print("SkillManager: %s trained to level %d (paid)" % [skill_lower, skill_levels[skill_lower]])
		return true
	
	return false


## Set a skill level directly (for character creation).
func set_skill_level(skill: String, level: int) -> void:
	var skill_lower := skill.to_lower()
	
	if not is_valid_skill(skill_lower):
		push_warning("SkillManager: Unknown skill '%s'" % skill)
		return
	
	var old_level:int = skill_levels[skill_lower]
	skill_levels[skill_lower] = clampi(level, min_level, max_level)
	skill_xp[skill_lower] = 0
	
	if old_level != skill_levels[skill_lower]:
		print("SkillManager: %s set to level %d" % [skill_lower, skill_levels[skill_lower]])


func _check_level_up(skill: String) -> void:
	var current_level:int = skill_levels[skill]
	var current_xp:int = skill_xp[skill]
	
	if current_level >= max_level:
		return
	
	if current_xp < xp_per_level:
		return
	
	# Check if trainer is required
	if current_level >= trainer_required_above:
		# Store excess XP and mark as pending
		var excess_xp := current_xp - xp_per_level
		pending_level_ups[skill] = excess_xp
		skill_xp[skill] = xp_per_level  # Cap at max for display
		
		skill_level_blocked.emit(skill, current_level, "trainer_required")
		_emit_to_event_bus("player_skill_level_blocked", [skill, current_level, "trainer_required"])
		
		print("SkillManager: %s ready for level %d but needs trainer" % [skill, current_level + 1])
	else:
		# Auto level up
		var old_level := current_level
		skill_levels[skill] = current_level + 1
		skill_xp[skill] = current_xp - xp_per_level  # Carry over excess
		
		skill_level_up.emit(skill, old_level, skill_levels[skill])
		_emit_to_event_bus("player_skill_level_up", [skill, old_level, skill_levels[skill]])
		
		print("SkillManager: %s leveled up to %d" % [skill, skill_levels[skill]])
		
		# Check for another level up with excess XP
		_check_level_up(skill)

# =============================================================================
# DIMINISHING RETURNS
# =============================================================================

func _calculate_diminishing_returns(skill: String, action: String) -> float:
	if not diminishing_config.get("enabled", true):
		return 1.0
	
	var threshold: int = diminishing_config.get("same_action_threshold", 3)
	var penalty: float = diminishing_config.get("same_action_penalty", 0.5)
	
	if not recent_actions.has(skill):
		return 1.0
	
	var actions: Dictionary = recent_actions[skill]
	if not actions.has(action):
		return 1.0
	
	var action_data: Dictionary = actions[action]
	var count: int = action_data.get("count", 0)
	
	if count < threshold:
		return 1.0
	
	# Apply penalty for each use beyond threshold
	var penalties := count - threshold + 1
	return maxf(0.1, pow(penalty, penalties))


func _track_action(skill: String, action: String) -> void:
	if not recent_actions.has(skill):
		recent_actions[skill] = {}
	
	if not recent_actions[skill].has(action):
		recent_actions[skill][action] = {"count": 0, "last_turn": _current_turn}
	
	recent_actions[skill][action]["count"] += 1
	recent_actions[skill][action]["last_turn"] = _current_turn


func _on_turn_started(turn_number: int, _day: int, _period: String) -> void:
	_current_turn = turn_number
	_decay_recent_actions()


func _decay_recent_actions() -> void:
	var reset_turns: int = diminishing_config.get("reset_after_turns", 6)
	
	for skill in recent_actions:
		var to_remove: Array[String] = []
		
		for action in recent_actions[skill]:
			var action_data: Dictionary = recent_actions[skill][action]
			var last_turn: int = action_data.get("last_turn", 0)
			
			if _current_turn - last_turn >= reset_turns:
				to_remove.append(action)
		
		for action in to_remove:
			recent_actions[skill].erase(action)

# =============================================================================
# SKILL CHECKS
# =============================================================================

## Perform a skill check: d10 + linked_stat + skill_level vs difficulty.
## @param skill: The skill to use.
## @param difficulty: Target number or difficulty name.
## @param grant_xp_on_success: Whether to grant XP for successful use.
## @return Dictionary with roll details.
func roll_skill_check(skill: String, difficulty, grant_xp_on_success: bool = true) -> Dictionary:
	var skill_lower := skill.to_lower()
	
	if not is_valid_skill(skill_lower):
		push_warning("SkillManager: Unknown skill '%s'" % skill)
		return {"success": false, "error": "unknown_skill"}
	
	var skill_level := get_skill_level(skill_lower)
	var linked_stat := get_linked_stat(skill_lower)
	
	# Get stat value from PlayerStats
	var stat_value := 0
	if _player_stats:
		stat_value = _player_stats.get_effective_stat(linked_stat)
	
	# Use PlayerStats roll system if available
	var result: Dictionary
	if _player_stats:
		result = _player_stats.roll_check(linked_stat, difficulty, skill_level)
	else:
		# Fallback roll
		result = _fallback_roll(skill_level, stat_value, difficulty)
	
	# Add skill info to result
	result["skill_name"] = skill_lower
	result["skill_level"] = skill_level
	result["linked_stat"] = linked_stat
	
	skill_check_rolled.emit(skill_lower, result)
	_emit_to_event_bus("player_skill_check_rolled", [skill_lower, result])
	
	# Grant XP on success
	if grant_xp_on_success and result["success"]:
		var xp_difficulty := _difficulty_to_xp_category(result["difficulty"])
		grant_xp(skill_lower, "skill_check", xp_difficulty)
	
	return result


func _fallback_roll(skill_level: int, stat_value: int, difficulty) -> Dictionary:
	var dc: int
	if difficulty is String:
		var difficulties := {"trivial": 5, "easy": 8, "medium": 12, "hard": 15, "very_hard": 18, "legendary": 21}
		dc = difficulties.get(difficulty.to_lower(), 12)
	else:
		dc = int(difficulty)
	
	var roll := randi_range(1, 10)
	var total := roll + stat_value + skill_level
	var success := total >= dc
	
	return {
		"success": success,
		"roll": roll,
		"stat_value": stat_value,
		"skill_bonus": skill_level,
		"total": total,
		"difficulty": dc,
		"margin": total - dc,
		"critical": roll == 10,
		"fumble": roll == 1
	}


func _difficulty_to_xp_category(dc: int) -> String:
	if dc <= 5:
		return "trivial"
	elif dc <= 8:
		return "easy"
	elif dc <= 12:
		return "moderate"
	elif dc <= 15:
		return "difficult"
	else:
		return "extreme"

# =============================================================================
# SERIALIZATION
# =============================================================================

## Convert skills to dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"levels": skill_levels.duplicate(),
		"xp": skill_xp.duplicate(),
		"pending_level_ups": pending_level_ups.duplicate(),
		"recent_actions": recent_actions.duplicate(true)
	}


## Load skills from dictionary.
func from_dict(data: Dictionary) -> void:
	if data.has("levels"):
		for skill_name in skill_names:
			if data["levels"].has(skill_name):
				skill_levels[skill_name] = clampi(data["levels"][skill_name], min_level, max_level)
	
	if data.has("xp"):
		for skill_name in skill_names:
			if data["xp"].has(skill_name):
				skill_xp[skill_name] = maxi(0, data["xp"][skill_name])
	
	if data.has("pending_level_ups"):
		pending_level_ups = data["pending_level_ups"].duplicate()
	
	if data.has("recent_actions"):
		recent_actions = data["recent_actions"].duplicate(true)
	
	print("SkillManager: Loaded from save data")

# =============================================================================
# DEBUG
# =============================================================================

## Print current skills to console.
func debug_print_skills() -> void:
	print("=== Player Skills ===")
	
	for category in get_category_names():
		var cat_info: Dictionary = category_config.get(category, {})
		print("--- %s ---" % cat_info.get("name", category.capitalize()))
		
		for skill_name in get_skills_in_category(category):
			var level:int = skill_levels[skill_name]
			var xp:int = skill_xp[skill_name]
			var linked := get_linked_stat(skill_name)
			var pending := " [NEEDS TRAINER]" if pending_level_ups.has(skill_name) else ""
			
			print("  %s: %d (%d/%d XP) [%s]%s" % [
				skill_name.capitalize(), level, xp, xp_per_level, linked, pending
			])


## Grant XP to a skill (debug).
func debug_grant_xp(skill: String, amount: int) -> void:
	var skill_lower := skill.to_lower()
	if is_valid_skill(skill_lower):
		skill_xp[skill_lower] += amount
		print("SkillManager: Debug granted %d XP to %s" % [amount, skill_lower])
		_check_level_up(skill_lower)


## Set a skill level (debug).
func debug_set_level(skill: String, level: int) -> void:
	set_skill_level(skill, level)

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
