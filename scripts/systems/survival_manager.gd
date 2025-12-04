# survival_manager.gd
# Comprehensive survival system managing temperature, fatigue, sleep, hunger, and thirst.
# Add as a node under Main (or as an autoload).
#
# SYSTEMS:
# - Temperature: Environmental temperature effects based on terrain, time, season, clothing
# - Fatigue: Physical exhaustion from activities, recovers through rest/sleep
# - Sleep: Sleep deprivation tracking, hallucinations, recovery mechanics
# - Hunger: Food consumption and starvation effects
# - Thirst: Water consumption and dehydration effects
#
# DEPENDENCIES:
# - TimeManager (autoload): For time of day, seasons, turn signals
# - PlayerStats: For applying stat modifiers and fortitude saves
# - EventBus (autoload): For emitting survival events
# - DataLoader (autoload): For loading survival_config.json

extends Node
class_name SurvivalManager

# =============================================================================
# SIGNALS
# =============================================================================

# Temperature
signal temperature_changed(temperature: float, zone: String)
signal temperature_warning(zone: String, message: String)
signal temperature_damage(damage: int, damage_type: String)

# Fatigue
signal fatigue_changed(fatigue: int, level: String)
signal fatigue_level_changed(old_level: String, new_level: String)
signal stimulant_used(stimulant_type: String, duration: int)
signal stimulant_crash(fatigue_added: int)
signal collapse_triggered()

# Sleep
signal sleep_started(turns: int, quality: float)
signal sleep_completed(result: Dictionary)
signal sleep_interrupted(reason: String)
signal sleep_deprivation_changed(stage: String, nights_missed: int)
signal hallucination_started(hallucination_type: String, data: Dictionary)
signal hallucination_ended(hallucination_type: String)

# Hunger & Thirst
signal hunger_changed(stage: String, days_missed: int)
signal thirst_changed(stage: String, periods_missed: int)
signal consumed_food(food_id: String, rations: float)
signal consumed_water(source: String, drinks: float)

# General
signal survival_damage(damage: int, source: String)
signal survival_death(cause: String)
signal status_effect_added(effect: String, source: String)
signal status_effect_removed(effect: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const CONFIG_PATH := "res://data/survival/survival_config.json"
const MODIFIER_PREFIX_TEMP := "temperature_"
const MODIFIER_PREFIX_FATIGUE := "fatigue_"
const MODIFIER_PREFIX_SLEEP := "sleep_"
const MODIFIER_PREFIX_HUNGER := "hunger_"
const MODIFIER_PREFIX_THIRST := "thirst_"

# =============================================================================
# CONFIGURATION (loaded from JSON)
# =============================================================================

var config: Dictionary = {}

# =============================================================================
# STATE - Health
# =============================================================================

var current_hp: int = 20
var max_hp: int = 20

# =============================================================================
# STATE - Temperature
# =============================================================================

var current_temperature: float = 70.0
var feels_like_temperature: float = 70.0
var current_temperature_zone: String = "comfortable"
var current_terrain: String = "plains"
var current_clothing: String = "travel_clothes"
var cold_exposure_turns: int = 0
var heat_exposure_turns: int = 0

# =============================================================================
# STATE - Fatigue
# =============================================================================

var fatigue: int = 0
var fatigue_level: String = "rested"
var stimulant_active: bool = false
var stimulant_type: String = ""
var stimulant_turns_remaining: int = 0
var stimulant_crash_fatigue: int = 0

# =============================================================================
# STATE - Sleep
# =============================================================================

var nights_without_sleep: int = 0
var last_sleep_quality: float = 0.0
var sleep_deprivation_stage: String = "rested"
var is_sleeping: bool = false
var sleep_turns_remaining: int = 0
var current_sleep_quality: float = 0.0
var hallucinating: bool = false
var current_hallucination: String = ""
var hallucination_turns_remaining: int = 0
var slept_this_night: bool = false

# =============================================================================
# STATE - Hunger & Thirst
# =============================================================================

var days_without_food: int = 0
var hunger_stage: String = "well_fed"
var periods_without_water: int = 0
var thirst_stage: String = "hydrated"
var water_consumption_multiplier: float = 1.0

# =============================================================================
# REFERENCES
# =============================================================================

var _player_stats: Node = null
var _time_manager: Node = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("survival_manager")
	_load_config()
	_connect_signals()
	_sync_max_hp()
	print("SurvivalManager: Initialized")


## Explicit initialization (for GameManager compatibility).
## Can be called after _ready() to re-initialize or reset state.
func initialize() -> void:
	_load_config()
	_sync_max_hp()
	_calculate_temperature()
	print("SurvivalManager: initialize() called")


func _load_config() -> void:
	var data_loader = get_node_or_null("/root/DataLoader")
	if data_loader and data_loader.has_method("load_json"):
		config = data_loader.load_json(CONFIG_PATH)
	else:
		# Fallback: load directly
		if FileAccess.file_exists(CONFIG_PATH):
			var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
			if file:
				var json := JSON.new()
				var error := json.parse(file.get_as_text())
				file.close()
				if error == OK:
					config = json.data
				else:
					push_error("SurvivalManager: Failed to parse config JSON")
					config = {}
		else:
			push_warning("SurvivalManager: Config file not found at %s" % CONFIG_PATH)
			config = {}


func _connect_signals() -> void:
	# Connect to TimeManager
	_time_manager = get_node_or_null("/root/TimeManager")
	if _time_manager:
		if _time_manager.has_signal("turn_started"):
			_time_manager.turn_started.connect(_on_turn_started)
		if _time_manager.has_signal("day_started"):
			_time_manager.day_started.connect(_on_day_started)
		if _time_manager.has_signal("night_started"):
			_time_manager.night_started.connect(_on_night_started)
		if _time_manager.has_signal("dawn_started"):
			_time_manager.dawn_started.connect(_on_dawn_started)
	else:
		push_warning("SurvivalManager: TimeManager not found")
	
	# Try to find PlayerStats
	await get_tree().process_frame  # Wait one frame for other nodes to initialize
	_find_player_stats()


func _find_player_stats() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_stats"):
		_player_stats = player.get_stats()
	else:
		_player_stats = get_tree().get_first_node_in_group("player_stats")
	
	if _player_stats:
		_sync_max_hp()


func _sync_max_hp() -> void:
	if _player_stats and _player_stats.has_method("get_max_hp"):
		max_hp = _player_stats.get_max_hp()
		current_hp = mini(current_hp, max_hp)

# =============================================================================
# TIME CALLBACKS
# =============================================================================

func _on_turn_started(turn: int, day: int, time_name: String) -> void:
	# Process all survival systems each turn
	_process_temperature()
	_process_fatigue_per_turn()
	_process_stimulant()
	_process_hallucination()
	_process_sleep_deprivation_effects()
	
	# Check for thirst (every 3 turns = twice per day for 6 turns)
	if turn == 1 or turn == 4:
		_process_thirst_period()


func _on_day_started(day: int) -> void:
	# Process daily effects
	_process_hunger_daily()
	_process_sleep_deprivation_daily_damage()
	
	# Reset daily flags
	slept_this_night = false


func _on_night_started(day: int) -> void:
	# Track if player sleeps this night
	pass


func _on_dawn_started(day: int) -> void:
	# Check if player slept during the night
	if not slept_this_night:
		nights_without_sleep += 1
		_update_sleep_deprivation_stage()
		print("SurvivalManager: Missed sleep - %d nights without sleep" % nights_without_sleep)

# =============================================================================
# TEMPERATURE SYSTEM
# =============================================================================

## Set the current terrain type (affects temperature).
func set_terrain(terrain: String) -> void:
	current_terrain = terrain.to_lower()
	_calculate_temperature()


## Set the player's current clothing.
func set_clothing(clothing: String) -> void:
	current_clothing = clothing.to_lower()
	_calculate_temperature()


## Get current temperature info.
func get_temperature_info() -> Dictionary:
	return {
		"temperature": current_temperature,
		"feels_like": feels_like_temperature,
		"zone": current_temperature_zone,
		"terrain": current_terrain,
		"clothing": current_clothing,
		"cold_exposure": cold_exposure_turns,
		"heat_exposure": heat_exposure_turns
	}


func _calculate_temperature() -> void:
	if not _time_manager:
		return
	
	# Get base temperature from TimeManager
	var base_temp: float = 70.0
	if _time_manager.has_method("get_base_temperature"):
		base_temp = _time_manager.get_base_temperature()
	
	# Apply terrain modifier
	var terrain_mods: Dictionary = config.get("temperature", {}).get("terrain_modifiers", {})
	var terrain_mod: Dictionary = terrain_mods.get(current_terrain, {"day": 0, "night": 0})
	
	var is_night: bool = _time_manager.is_nighttime() if _time_manager.has_method("is_nighttime") else false
	var terrain_adjustment: float = terrain_mod.get("night" if is_night else "day", 0)
	
	current_temperature = base_temp + terrain_adjustment
	
	# Calculate feels-like with clothing
	var clothing_data: Dictionary = config.get("temperature", {}).get("clothing", {})
	var clothing: Dictionary = clothing_data.get(current_clothing, {"cold_protection": 0, "heat_protection": 0})
	
	feels_like_temperature = current_temperature
	if current_temperature < 60:  # Cold - apply cold protection
		feels_like_temperature += clothing.get("cold_protection", 0)
	elif current_temperature > 80:  # Hot - apply heat protection
		feels_like_temperature -= clothing.get("heat_protection", 0)
	
	# Determine temperature zone
	var old_zone := current_temperature_zone
	current_temperature_zone = _get_temperature_zone(feels_like_temperature)
	
	if old_zone != current_temperature_zone:
		temperature_changed.emit(feels_like_temperature, current_temperature_zone)
		_emit_to_event_bus("temperature_changed", [feels_like_temperature, current_temperature_zone])
		
		# Warn about dangerous zones
		if current_temperature_zone == "extreme_cold" or current_temperature_zone == "extreme_heat":
			var zone_data := _get_zone_data(current_temperature_zone)
			temperature_warning.emit(current_temperature_zone, zone_data.get("description", ""))
			_emit_to_event_bus("temperature_warning", [current_temperature_zone, zone_data.get("description", "")])


func _get_temperature_zone(temp: float) -> String:
	var zones: Array = config.get("temperature", {}).get("zones", [])
	for zone in zones:
		var min_t: float = zone.get("min_temp", -999)
		var max_t: float = zone.get("max_temp", 999)
		if temp >= min_t and temp < max_t:
			return zone.get("name", "comfortable")
	return "comfortable"


func _get_zone_data(zone_name: String) -> Dictionary:
	var zones: Array = config.get("temperature", {}).get("zones", [])
	for zone in zones:
		if zone.get("name", "") == zone_name:
			return zone
	return {}


func _process_temperature() -> void:
	_calculate_temperature()
	
	var zone_data := _get_zone_data(current_temperature_zone)
	
	# Track exposure
	if current_temperature_zone == "extreme_cold":
		cold_exposure_turns += 1
		heat_exposure_turns = 0
	elif current_temperature_zone == "extreme_heat":
		heat_exposure_turns += 1
		cold_exposure_turns = 0
	else:
		cold_exposure_turns = maxi(0, cold_exposure_turns - 1)
		heat_exposure_turns = maxi(0, heat_exposure_turns - 1)
	
	# Apply damage if in extreme zone
	var hp_damage: int = zone_data.get("hp_per_turn", 0)
	if hp_damage > 0:
		var requires_save: bool = zone_data.get("requires_save", false)
		var save_dc: int = zone_data.get("save_difficulty", 12)
		
		if requires_save and _player_stats:
			var result: Dictionary = _player_stats.roll_check("fortitude", save_dc)
			if result.get("success", false):
				hp_damage = 0
				print("SurvivalManager: Fortitude save success - avoided temperature damage")
		
		if hp_damage > 0:
			var damage_type := "cold" if current_temperature_zone == "extreme_cold" else "heat"
			_take_damage(hp_damage, damage_type)
			temperature_damage.emit(hp_damage, damage_type)
			_emit_to_event_bus("temperature_damage", [hp_damage, damage_type])
	
	# Apply fatigue from temperature
	var temp_fatigue: int = zone_data.get("fatigue_per_turn", 0)
	if temp_fatigue > 0:
		add_fatigue(temp_fatigue, "temperature")
	
	# Update water consumption multiplier
	water_consumption_multiplier = zone_data.get("water_multiplier", 1.0)

# =============================================================================
# FATIGUE SYSTEM
# =============================================================================

## Add fatigue from a source.
func add_fatigue(amount: int, source: String) -> void:
	var old_fatigue := fatigue
	fatigue = clampi(fatigue + amount, 0, 100)
	
	if fatigue != old_fatigue:
		var old_level := fatigue_level
		_update_fatigue_level()
		
		fatigue_changed.emit(fatigue, fatigue_level)
		_emit_to_event_bus("fatigue_changed", [fatigue, fatigue_level])
		
		print("SurvivalManager: Fatigue %+d from %s (now %d - %s)" % [amount, source, fatigue, fatigue_level])


## Reduce fatigue.
func reduce_fatigue(amount: int) -> void:
	add_fatigue(-amount, "recovery")


## Get fatigue info.
func get_fatigue_info() -> Dictionary:
	return {
		"fatigue": fatigue,
		"level": fatigue_level,
		"stimulant_active": stimulant_active,
		"stimulant_turns": stimulant_turns_remaining
	}


## Perform a rest action (1 turn, reduces fatigue).
func rest() -> int:
	var recovery: int = config.get("fatigue", {}).get("recovery", {}).get("rest_action", 20)
	reduce_fatigue(recovery)
	print("SurvivalManager: Rested - recovered %d fatigue" % recovery)
	return recovery


## Use a stimulant.
func use_stimulant(stim_type: String) -> bool:
	var stimulants: Dictionary = config.get("fatigue", {}).get("stimulants", {})
	var stim_data: Dictionary = stimulants.get(stim_type, {})
	
	if stim_data.is_empty():
		push_warning("SurvivalManager: Unknown stimulant '%s'" % stim_type)
		return false
	
	# If already on stimulants, crash first
	if stimulant_active:
		_trigger_stimulant_crash()
	
	var recovery: int = stim_data.get("recovery", 30)
	var duration: int = stim_data.get("duration", 6)
	var crash: int = stim_data.get("crash_fatigue", 40)
	
	reduce_fatigue(recovery)
	stimulant_active = true
	stimulant_type = stim_type
	stimulant_turns_remaining = duration
	stimulant_crash_fatigue = crash
	
	stimulant_used.emit(stim_type, duration)
	_emit_to_event_bus("stimulant_used", [stim_type, duration])
	
	print("SurvivalManager: Used %s - %d fatigue recovery, %d turns duration" % [stim_type, recovery, duration])
	return true


func _process_fatigue_per_turn() -> void:
	# Base fatigue gain per turn (if awake and not resting)
	if not is_sleeping:
		var base_gain: int = config.get("fatigue", {}).get("sources", {}).get("turn_base", 3)
		add_fatigue(base_gain, "time")
	
	# Check for collapse
	if fatigue_level == "collapsing":
		var level_data := _get_fatigue_level_data(fatigue_level)
		var collapse_risk: float = level_data.get("collapse_risk", 0.0)
		if collapse_risk > 0 and randf() < collapse_risk:
			_trigger_collapse()


func _process_stimulant() -> void:
	if not stimulant_active:
		return
	
	stimulant_turns_remaining -= 1
	if stimulant_turns_remaining <= 0:
		_trigger_stimulant_crash()


func _trigger_stimulant_crash() -> void:
	if not stimulant_active:
		return
	
	add_fatigue(stimulant_crash_fatigue, "stimulant_crash")
	stimulant_crash.emit(stimulant_crash_fatigue)
	_emit_to_event_bus("stimulant_crash", [stimulant_crash_fatigue])
	
	print("SurvivalManager: Stimulant crash - %d fatigue" % stimulant_crash_fatigue)
	
	stimulant_active = false
	stimulant_type = ""
	stimulant_turns_remaining = 0
	stimulant_crash_fatigue = 0


func _trigger_collapse() -> void:
	print("SurvivalManager: Collapsed from exhaustion!")
	collapse_triggered.emit()
	_emit_to_event_bus("collapse_triggered", [])
	
	# Force sleep/unconsciousness
	# The game should handle this event appropriately


func _update_fatigue_level() -> void:
	var old_level := fatigue_level
	var levels: Array = config.get("fatigue", {}).get("levels", [])
	
	for level_data in levels:
		var min_val: int = level_data.get("min", 0)
		var max_val: int = level_data.get("max", 100)
		if fatigue >= min_val and fatigue <= max_val:
			fatigue_level = level_data.get("name", "rested")
			break
	
	if old_level != fatigue_level:
		_apply_fatigue_modifiers()
		fatigue_level_changed.emit(old_level, fatigue_level)
		_emit_to_event_bus("fatigue_level_changed", [old_level, fatigue_level])


func _get_fatigue_level_data(level_name: String) -> Dictionary:
	var levels: Array = config.get("fatigue", {}).get("levels", [])
	for level_data in levels:
		if level_data.get("name", "") == level_name:
			return level_data
	return {}


func _apply_fatigue_modifiers() -> void:
	if not _player_stats:
		return
	
	# Remove old fatigue modifiers
	_player_stats.remove_modifiers_by_prefix(MODIFIER_PREFIX_FATIGUE)
	
	# Apply new modifiers
	var level_data := _get_fatigue_level_data(fatigue_level)
	var modifiers: Array = level_data.get("modifiers", [])
	
	for i in range(modifiers.size()):
		var mod: Dictionary = modifiers[i]
		var source := "%s%s_%d" % [MODIFIER_PREFIX_FATIGUE, fatigue_level, i]
		_player_stats.add_modifier(
			source,
			mod.get("stat", "all"),
			mod.get("type", "percentage"),
			mod.get("value", 0)
		)

# =============================================================================
# SLEEP SYSTEM
# =============================================================================

## Start sleeping.
func start_sleep(turns: int, quality_factors: Dictionary = {}) -> void:
	if is_sleeping:
		push_warning("SurvivalManager: Already sleeping")
		return
	
	is_sleeping = true
	sleep_turns_remaining = turns
	current_sleep_quality = _calculate_sleep_quality(quality_factors)
	
	sleep_started.emit(turns, current_sleep_quality)
	_emit_to_event_bus("sleep_started", [turns, current_sleep_quality])
	
	print("SurvivalManager: Started sleeping for %d turns (quality: %.0f%%)" % [turns, current_sleep_quality])


## Interrupt sleep.
func interrupt_sleep(reason: String) -> void:
	if not is_sleeping:
		return
	
	is_sleeping = false
	var turns_slept:int = (config.get("sleep", {}).get("optimal_turns", 2) - sleep_turns_remaining)
	
	# Partial benefits based on turns slept
	var result := _process_sleep_completion(turns_slept, current_sleep_quality * 0.5)
	result["interrupted"] = true
	result["interruption_reason"] = reason
	
	sleep_interrupted.emit(reason)
	_emit_to_event_bus("sleep_interrupted", [reason])
	
	print("SurvivalManager: Sleep interrupted - %s" % reason)


## Process a turn of sleep (called internally or by TimeManager).
func process_sleep_turn() -> void:
	if not is_sleeping:
		return
	
	sleep_turns_remaining -= 1
	
	if sleep_turns_remaining <= 0:
		_complete_sleep()


func _complete_sleep() -> void:
	is_sleeping = false
	slept_this_night = true
	
	var turns_slept:int = config.get("sleep", {}).get("optimal_turns", 2)
	var result := _process_sleep_completion(turns_slept, current_sleep_quality)
	
	sleep_completed.emit(result)
	_emit_to_event_bus("sleep_completed", [result])
	
	print("SurvivalManager: Sleep completed - HP +%d, Fatigue -%d%%" % [
		result.get("hp_recovered", 0), 
		result.get("fatigue_percent_recovered", 0)
	])


func _process_sleep_completion(turns: int, quality: float) -> Dictionary:
	var optimal_turns: int = config.get("sleep", {}).get("optimal_turns", 2)
	var effective_quality := quality * (float(turns) / float(optimal_turns))
	
	# Find recovery tier
	var recovery_tiers: Dictionary = config.get("sleep", {}).get("recovery_by_quality", {})
	var recovery_tier := "terrible"
	var tier_data: Dictionary = {}
	
	for tier_name in ["excellent", "good", "adequate", "poor", "terrible"]:
		var tier: Dictionary = recovery_tiers.get(tier_name, {})
		if effective_quality >= tier.get("min_quality", 0):
			recovery_tier = tier_name
			tier_data = tier
			break
	
	# Apply recovery
	var hp_recovered: int = tier_data.get("hp", 0)
	var fatigue_percent: int = tier_data.get("fatigue_percent", 0)
	var clears_minor: bool = tier_data.get("clears_minor", false)
	
	# Heal HP
	if hp_recovered > 0:
		heal(hp_recovered)
	
	# Reduce fatigue
	var fatigue_recovery: int = int(fatigue * fatigue_percent / 100.0)
	if fatigue_percent >= 100:
		fatigue = 0
		_update_fatigue_level()
	else:
		reduce_fatigue(fatigue_recovery)
	
	# Reset sleep deprivation if good sleep
	if effective_quality >= 100:
		nights_without_sleep = 0
		_update_sleep_deprivation_stage()
	elif effective_quality >= 50:
		nights_without_sleep = maxi(0, nights_without_sleep - 1)
		_update_sleep_deprivation_stage()
	
	last_sleep_quality = effective_quality
	
	return {
		"quality": effective_quality,
		"tier": recovery_tier,
		"hp_recovered": hp_recovered,
		"fatigue_percent_recovered": fatigue_percent,
		"effects_cleared": [] if not clears_minor else ["minor_effects"],
		"interrupted": false,
		"interruption_reason": ""
	}


func _calculate_sleep_quality(factors: Dictionary) -> float:
	var base_quality := 100.0
	var quality_mods: Dictionary = config.get("sleep", {}).get("quality_modifiers", {})
	
	for factor in factors:
		if factors[factor] and quality_mods.has(factor):
			base_quality += quality_mods[factor]
	
	return maxf(0.0, base_quality)


func _update_sleep_deprivation_stage() -> void:
	var old_stage := sleep_deprivation_stage
	var stages: Array = config.get("sleep", {}).get("deprivation_stages", [])
	
	# Find appropriate stage (highest nights_missed that we meet or exceed)
	sleep_deprivation_stage = "rested"
	for stage_data in stages:
		var nights_required: int = stage_data.get("nights_missed", 0)
		if nights_without_sleep >= nights_required:
			sleep_deprivation_stage = stage_data.get("name", "rested")
	
	if old_stage != sleep_deprivation_stage:
		_apply_sleep_modifiers()
		sleep_deprivation_changed.emit(sleep_deprivation_stage, nights_without_sleep)
		_emit_to_event_bus("sleep_deprivation_changed", [sleep_deprivation_stage, nights_without_sleep])
		print("SurvivalManager: Sleep deprivation stage: %s (%d nights)" % [sleep_deprivation_stage, nights_without_sleep])


func _get_sleep_stage_data(stage_name: String) -> Dictionary:
	var stages: Array = config.get("sleep", {}).get("deprivation_stages", [])
	for stage_data in stages:
		if stage_data.get("name", "") == stage_name:
			return stage_data
	return {}


func _apply_sleep_modifiers() -> void:
	if not _player_stats:
		return
	
	# Remove old sleep modifiers
	_player_stats.remove_modifiers_by_prefix(MODIFIER_PREFIX_SLEEP)
	
	# Apply new modifiers
	var stage_data := _get_sleep_stage_data(sleep_deprivation_stage)
	var modifiers: Array = stage_data.get("modifiers", [])
	
	for i in range(modifiers.size()):
		var mod: Dictionary = modifiers[i]
		var source := "%s%s_%d" % [MODIFIER_PREFIX_SLEEP, sleep_deprivation_stage, i]
		_player_stats.add_modifier(
			source,
			mod.get("stat", "all"),
			mod.get("type", "percentage"),
			mod.get("value", 0)
		)


func _process_sleep_deprivation_effects() -> void:
	var stage_data := _get_sleep_stage_data(sleep_deprivation_stage)
	var hallucination_risk: float = stage_data.get("hallucination_risk", 0.0)
	
	if hallucination_risk > 0 and not hallucinating:
		if randf() < hallucination_risk:
			_trigger_hallucination()


func _process_sleep_deprivation_daily_damage() -> void:
	var stage_data := _get_sleep_stage_data(sleep_deprivation_stage)
	var hp_loss: int = stage_data.get("hp_loss_per_day", 0)
	
	if hp_loss > 0:
		_take_damage(hp_loss, "sleep_deprivation")

# =============================================================================
# HALLUCINATION SYSTEM
# =============================================================================

func _trigger_hallucination() -> void:
	if hallucinating:
		return
	
	var hallucination_types: Array = config.get("hallucinations", {}).get("types", [])
	if hallucination_types.is_empty():
		return
	
	# Weighted random selection
	var total_weight: int = 0
	for h in hallucination_types:
		total_weight += h.get("weight", 1)
	
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	var selected: Dictionary = hallucination_types[0]
	
	for h in hallucination_types:
		cumulative += h.get("weight", 1)
		if roll < cumulative:
			selected = h
			break
	
	hallucinating = true
	current_hallucination = selected.get("id", "visual_distortion")
	
	var duration_config: Dictionary = config.get("hallucinations", {}).get("duration_turns", {"min": 1, "max": 3})
	hallucination_turns_remaining = randi_range(
		duration_config.get("min", 1),
		duration_config.get("max", 3)
	)
	
	var data := {
		"type": current_hallucination,
		"description": selected.get("description", ""),
		"dangerous": selected.get("dangerous", false),
		"duration": hallucination_turns_remaining
	}
	
	hallucination_started.emit(current_hallucination, data)
	_emit_to_event_bus("hallucination_started", [current_hallucination, data])
	
	print("SurvivalManager: Hallucination started - %s (%d turns)" % [current_hallucination, hallucination_turns_remaining])


func _process_hallucination() -> void:
	if not hallucinating:
		return
	
	hallucination_turns_remaining -= 1
	if hallucination_turns_remaining <= 0:
		_end_hallucination()


func _end_hallucination() -> void:
	if not hallucinating:
		return
	
	var old_type := current_hallucination
	hallucinating = false
	current_hallucination = ""
	hallucination_turns_remaining = 0
	
	hallucination_ended.emit(old_type)
	_emit_to_event_bus("hallucination_ended", [old_type])
	
	print("SurvivalManager: Hallucination ended - %s" % old_type)


## Force end a hallucination (for external systems).
func end_hallucination() -> void:
	_end_hallucination()

# =============================================================================
# HUNGER SYSTEM
# =============================================================================

## Consume food.
func eat(food_id: String, ration_value: float = 1.0) -> void:
	days_without_food = maxi(0, days_without_food - int(ration_value))
	_update_hunger_stage()
	
	consumed_food.emit(food_id, ration_value)
	_emit_to_event_bus("consumed_food", [food_id, ration_value])
	
	print("SurvivalManager: Ate %s (%.1f rations)" % [food_id, ration_value])


func _process_hunger_daily() -> void:
	days_without_food += 1
	_update_hunger_stage()
	
	# Check for starvation death
	var death_days: int = config.get("hunger", {}).get("death_days", 7)
	if days_without_food >= death_days:
		_trigger_death("starvation")
		return
	
	# Apply HP loss
	var stage_data := _get_hunger_stage_data(hunger_stage)
	var hp_loss: int = stage_data.get("hp_loss_per_day", 0)
	if hp_loss > 0:
		_take_damage(hp_loss, "starvation")


func _update_hunger_stage() -> void:
	var old_stage := hunger_stage
	var old_hunger_value := hunger  # Get UI value before change
	var stages: Array = config.get("hunger", {}).get("stages", [])
	
	hunger_stage = "well_fed"
	for stage_data in stages:
		var days_required: int = stage_data.get("days_missed", 0)
		if days_without_food >= days_required:
			hunger_stage = stage_data.get("name", "well_fed")
	
	var new_hunger_value := hunger  # Get UI value after change
	
	if old_stage != hunger_stage:
		_apply_hunger_modifiers()
		hunger_changed.emit(hunger_stage, days_without_food)
		# Emit UI-compatible signal (new_value, old_value)
		_emit_to_event_bus("hunger_changed", [new_hunger_value, old_hunger_value])
		print("SurvivalManager: Hunger stage: %s (%d days)" % [hunger_stage, days_without_food])


func _get_hunger_stage_data(stage_name: String) -> Dictionary:
	var stages: Array = config.get("hunger", {}).get("stages", [])
	for stage_data in stages:
		if stage_data.get("name", "") == stage_name:
			return stage_data
	return {}


func _apply_hunger_modifiers() -> void:
	if not _player_stats:
		return
	
	_player_stats.remove_modifiers_by_prefix(MODIFIER_PREFIX_HUNGER)
	
	var stage_data := _get_hunger_stage_data(hunger_stage)
	var modifiers: Array = stage_data.get("modifiers", [])
	
	for i in range(modifiers.size()):
		var mod: Dictionary = modifiers[i]
		var source := "%s%s_%d" % [MODIFIER_PREFIX_HUNGER, hunger_stage, i]
		_player_stats.add_modifier(
			source,
			mod.get("stat", "all"),
			mod.get("type", "percentage"),
			mod.get("value", 0)
		)

# =============================================================================
# THIRST SYSTEM
# =============================================================================

## Consume water.
func drink(source: String, drinks: float = 1.0) -> void:
	periods_without_water = maxi(0, periods_without_water - int(drinks))
	_update_thirst_stage()
	
	consumed_water.emit(source, drinks)
	_emit_to_event_bus("consumed_water", [source, drinks])
	
	print("SurvivalManager: Drank from %s (%.1f drinks)" % [source, drinks])


func _process_thirst_period() -> void:
	# Apply water consumption multiplier (from temperature)
	var consumption := int(ceil(water_consumption_multiplier))
	periods_without_water += consumption
	_update_thirst_stage()
	
	# Check for dehydration death
	var death_periods: int = config.get("thirst", {}).get("death_periods", 5)
	if periods_without_water >= death_periods:
		_trigger_death("dehydration")
		return
	
	# Apply HP loss
	var stage_data := _get_thirst_stage_data(thirst_stage)
	var hp_loss: int = stage_data.get("hp_loss_per_period", 0)
	if hp_loss > 0:
		_take_damage(hp_loss, "dehydration")


func _update_thirst_stage() -> void:
	var old_stage := thirst_stage
	var old_thirst_value := thirst  # Get UI value before change
	var stages: Array = config.get("thirst", {}).get("stages", [])
	
	thirst_stage = "hydrated"
	for stage_data in stages:
		var periods_required: int = stage_data.get("periods_missed", 0)
		if periods_without_water >= periods_required:
			thirst_stage = stage_data.get("name", "hydrated")
	
	var new_thirst_value := thirst  # Get UI value after change
	
	if old_stage != thirst_stage:
		_apply_thirst_modifiers()
		thirst_changed.emit(thirst_stage, periods_without_water)
		# Emit UI-compatible signal (new_value, old_value)
		_emit_to_event_bus("thirst_changed", [new_thirst_value, old_thirst_value])
		print("SurvivalManager: Thirst stage: %s (%d periods)" % [thirst_stage, periods_without_water])


func _get_thirst_stage_data(stage_name: String) -> Dictionary:
	var stages: Array = config.get("thirst", {}).get("stages", [])
	for stage_data in stages:
		if stage_data.get("name", "") == stage_name:
			return stage_data
	return {}


func _apply_thirst_modifiers() -> void:
	if not _player_stats:
		return
	
	_player_stats.remove_modifiers_by_prefix(MODIFIER_PREFIX_THIRST)
	
	var stage_data := _get_thirst_stage_data(thirst_stage)
	var modifiers: Array = stage_data.get("modifiers", [])
	
	for i in range(modifiers.size()):
		var mod: Dictionary = modifiers[i]
		var source := "%s%s_%d" % [MODIFIER_PREFIX_THIRST, thirst_stage, i]
		_player_stats.add_modifier(
			source,
			mod.get("stat", "all"),
			mod.get("type", "percentage"),
			mod.get("value", 0)
		)

# =============================================================================
# HEALTH MANAGEMENT
# =============================================================================

## Take damage from survival effects.
func _take_damage(amount: int, source: String) -> void:
	var old_hp := current_hp
	current_hp = maxi(0, current_hp - amount)
	
	survival_damage.emit(amount, source)
	_emit_to_event_bus("survival_damage", [amount, source])
	# Emit UI-compatible health signal (new_value, old_value, source)
	_emit_to_event_bus("health_changed", [current_hp, old_hp, source])
	
	print("SurvivalManager: Took %d damage from %s (HP: %d/%d)" % [amount, source, current_hp, max_hp])
	
	if current_hp <= 0:
		_trigger_death(source)


## Heal HP.
func heal(amount: int) -> void:
	var old_hp := current_hp
	current_hp = mini(max_hp, current_hp + amount)
	var healed := current_hp - old_hp
	
	if healed > 0:
		# Emit UI-compatible health signal
		_emit_to_event_bus("health_changed", [current_hp, old_hp, "heal"])
		print("SurvivalManager: Healed %d HP (HP: %d/%d)" % [healed, current_hp, max_hp])


## Set HP directly (for loading saves or external damage).
func set_hp(hp: int) -> void:
	current_hp = clampi(hp, 0, max_hp)


## Get current HP info.
func get_hp_info() -> Dictionary:
	return {
		"current": current_hp,
		"max": max_hp,
		"percent": float(current_hp) / float(max_hp) * 100.0
	}


func _trigger_death(cause: String) -> void:
	print("SurvivalManager: DEATH from %s" % cause)
	survival_death.emit(cause)
	_emit_to_event_bus("survival_death", [cause])

# =============================================================================
# QUERIES
# =============================================================================

## Get full survival status.
func get_survival_status() -> Dictionary:
	return {
		"hp": get_hp_info(),
		"temperature": get_temperature_info(),
		"fatigue": get_fatigue_info(),
		"sleep": {
			"nights_without_sleep": nights_without_sleep,
			"deprivation_stage": sleep_deprivation_stage,
			"is_sleeping": is_sleeping,
			"hallucinating": hallucinating,
			"current_hallucination": current_hallucination
		},
		"hunger": {
			"days_without_food": days_without_food,
			"stage": hunger_stage
		},
		"thirst": {
			"periods_without_water": periods_without_water,
			"stage": thirst_stage,
			"water_multiplier": water_consumption_multiplier
		}
	}

# =============================================================================
# COMPATIBILITY PROPERTIES (for SurvivalPanel)
# =============================================================================
# These provide a 0-10 scale for UI display, converting from the stage-based system.

## Maximum health (alias for max_hp).
var max_health: int:
	get: return max_hp

## Current health (alias for current_hp).
var health: int:
	get: return current_hp
	set(value): 
		var old_hp := current_hp
		current_hp = clampi(value, 0, max_hp)
		if current_hp != old_hp:
			_emit_to_event_bus("health_changed", [current_hp, old_hp, "direct"])

## Maximum hunger value for UI (scale 0-10).
var max_hunger: int:
	get: return 10

## Current hunger value for UI (10 = full, 0 = starving).
## Converts days_without_food to a 0-10 scale.
var hunger: int:
	get:
		# 0 days = 10 (full), 5+ days = 0 (near death)
		return clampi(10 - days_without_food * 2, 0, 10)

## Maximum thirst value for UI (scale 0-10).
var max_thirst: int:
	get: return 10

## Current thirst value for UI (10 = hydrated, 0 = severe dehydration).
## Converts periods_without_water to a 0-10 scale.
var thirst: int:
	get:
		# 0 periods = 10 (hydrated), 5 periods = 0 (death)
		return clampi(10 - periods_without_water * 2, 0, 10)

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_terrain": current_terrain,
		"current_clothing": current_clothing,
		"fatigue": fatigue,
		"stimulant_active": stimulant_active,
		"stimulant_type": stimulant_type,
		"stimulant_turns_remaining": stimulant_turns_remaining,
		"stimulant_crash_fatigue": stimulant_crash_fatigue,
		"nights_without_sleep": nights_without_sleep,
		"slept_this_night": slept_this_night,
		"hallucinating": hallucinating,
		"current_hallucination": current_hallucination,
		"hallucination_turns_remaining": hallucination_turns_remaining,
		"days_without_food": days_without_food,
		"periods_without_water": periods_without_water
	}


func from_dict(data: Dictionary) -> void:
	current_hp = data.get("current_hp", 20)
	max_hp = data.get("max_hp", 20)
	current_terrain = data.get("current_terrain", "plains")
	current_clothing = data.get("current_clothing", "travel_clothes")
	fatigue = data.get("fatigue", 0)
	stimulant_active = data.get("stimulant_active", false)
	stimulant_type = data.get("stimulant_type", "")
	stimulant_turns_remaining = data.get("stimulant_turns_remaining", 0)
	stimulant_crash_fatigue = data.get("stimulant_crash_fatigue", 0)
	nights_without_sleep = data.get("nights_without_sleep", 0)
	slept_this_night = data.get("slept_this_night", false)
	hallucinating = data.get("hallucinating", false)
	current_hallucination = data.get("current_hallucination", "")
	hallucination_turns_remaining = data.get("hallucination_turns_remaining", 0)
	days_without_food = data.get("days_without_food", 0)
	periods_without_water = data.get("periods_without_water", 0)
	
	# Update derived states
	_update_fatigue_level()
	_update_sleep_deprivation_stage()
	_update_hunger_stage()
	_update_thirst_stage()
	_calculate_temperature()
	
	print("SurvivalManager: Loaded from save")

# =============================================================================
# DEBUG
# =============================================================================

func debug_print_status() -> void:
	print("=== Survival Status ===")
	print("HP: %d/%d" % [current_hp, max_hp])
	print("Temperature: %.1f°F (feels like %.1f°F) - %s" % [current_temperature, feels_like_temperature, current_temperature_zone])
	print("Fatigue: %d/100 - %s" % [fatigue, fatigue_level])
	print("Sleep: %d nights missed - %s%s" % [nights_without_sleep, sleep_deprivation_stage, " (hallucinating)" if hallucinating else ""])
	print("Hunger: %d days - %s" % [days_without_food, hunger_stage])
	print("Thirst: %d periods - %s (water x%.1f)" % [periods_without_water, thirst_stage, water_consumption_multiplier])


func debug_set_fatigue(value: int) -> void:
	fatigue = clampi(value, 0, 100)
	_update_fatigue_level()
	print("DEBUG: Set fatigue to %d (%s)" % [fatigue, fatigue_level])


func debug_set_sleep_deprivation(nights: int) -> void:
	nights_without_sleep = maxi(0, nights)
	_update_sleep_deprivation_stage()
	print("DEBUG: Set sleep deprivation to %d nights (%s)" % [nights_without_sleep, sleep_deprivation_stage])


func debug_trigger_hallucination() -> void:
	_trigger_hallucination()

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
