# hazard_manager.gd
# Manages environmental hazards triggered by terrain, weather, and time combinations.
# Integrates with PlayerStats for stat saves and EffectManager for status effects.
#
# FEATURES:
# - Probabilistic hazard triggering on movement
# - Terrain + weather + time combination triggers
# - Stat save system (fortitude, reflex, spirit, etc.)
# - Mix of damage and status effects
# - Integration with EffectManager for status application
#
# DEPENDENCIES:
# - PlayerStats: For stat saves
# - EffectManager: For applying status effects
# - SurvivalManager: For damage application
# - WeatherManager: For current weather context
# - TimeManager: For time of day context

extends Node
class_name HazardManager

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a hazard check is rolled.
signal hazard_check_rolled(coords: Vector2i, hazard_id: String, triggered: bool)

## Emitted when a hazard is triggered.
signal hazard_triggered(coords: Vector2i, hazard_data: Dictionary)

## Emitted when a stat save is rolled.
signal hazard_save_rolled(hazard_id: String, save_result: Dictionary)

## Emitted when hazard effects are applied.
signal hazard_effects_applied(hazard_id: String, effects: Dictionary)

## Emitted when hazard message should be displayed.
signal hazard_message(hazard_data: Dictionary, save_result: Dictionary, effects: Dictionary)

# =============================================================================
# CONSTANTS
# =============================================================================

const CONFIG_PATH := "res://data/survival/hazards.json"

# =============================================================================
# CONFIGURATION
# =============================================================================

var settings: Dictionary = {}
var hazards: Dictionary = {}

## Cached references
var _player_stats = null
var _effect_manager = null
var _survival_manager = null
var _weather_manager = null
var _time_manager = null
var _hex_grid = null

## Current context cache
var _current_weather: String = "clear"
var _current_time: String = "day"

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("hazard_manager")
	_load_config()
	_connect_signals()
	print("HazardManager: Initialized with %d hazards" % _count_hazards())


func _load_config() -> void:
	var data: Dictionary = {}

	var data_loader = get_node_or_null("/root/DataLoader")
	if data_loader and data_loader.has_method("load_json"):
		data = data_loader.load_json(CONFIG_PATH)

	if data.is_empty() and FileAccess.file_exists(CONFIG_PATH):
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			var error := json.parse(file.get_as_text())
			file.close()
			if error == OK:
				data = json.data

	if not data.is_empty():
		settings = data.get("settings", {})
		hazards = data.get("hazards", {})
		print("HazardManager: Loaded config from %s" % CONFIG_PATH)
	else:
		_use_default_config()


func _use_default_config() -> void:
	settings = {
		"hazard_check_chance": 0.15,
		"stat_save_bonus_per_skill": 2,
		"message_duration_seconds": 3.0
	}
	hazards = {}
	print("HazardManager: Using default configuration")


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("player_moved_to_hex"):
			event_bus.player_moved_to_hex.connect(_on_player_moved_to_hex)

	await get_tree().process_frame
	_find_references()


func _find_references() -> void:
	_player_stats = get_tree().get_first_node_in_group("player_stats")
	_effect_manager = get_node_or_null("/root/EffectManager")
	_survival_manager = get_tree().get_first_node_in_group("survival_manager")
	_weather_manager = get_tree().get_first_node_in_group("weather_manager")
	_time_manager = get_node_or_null("/root/TimeManager")
	_hex_grid = get_tree().get_first_node_in_group("hex_grid")

	if not _player_stats:
		push_warning("HazardManager: PlayerStats not found")
	if not _effect_manager:
		push_warning("HazardManager: EffectManager not found")
	if not _survival_manager:
		push_warning("HazardManager: SurvivalManager not found")


func _count_hazards() -> int:
	var count := 0
	for category in hazards:
		count += hazards[category].size()
	return count

# =============================================================================
# HAZARD TRIGGERING
# =============================================================================

func _on_player_moved_to_hex(coords: Vector2i) -> void:
	check_for_hazard(coords)


## Check if a hazard should trigger at the given coordinates.
func check_for_hazard(coords: Vector2i) -> bool:
	if not _hex_grid:
		return false

	var cell = _hex_grid.get_cell(coords)
	if not cell:
		return false

	var terrain: String = cell.terrain_type

	# Update context
	_update_context()

	# Find applicable hazards
	var applicable := _get_applicable_hazards(terrain, _current_weather, _current_time)

	if applicable.is_empty():
		return false

	# Weighted random selection
	var selected := _select_hazard(applicable)

	if selected.is_empty():
		return false

	# Roll probability check
	var base_chance: float = selected.get("trigger_conditions", {}).get("base_chance", 0.10)
	var roll := randf()

	hazard_check_rolled.emit(coords, selected.get("id", ""), roll < base_chance)

	if roll >= base_chance:
		return false

	# Trigger hazard!
	_trigger_hazard(coords, terrain, selected)
	return true


func _update_context() -> void:
	if _weather_manager and _weather_manager.has_method("get_current_weather"):
		_current_weather = _weather_manager.get_current_weather()

	if _time_manager and _time_manager.has_method("get_time_of_day"):
		_current_time = _time_manager.get_time_of_day()


func _get_applicable_hazards(terrain: String, weather: String, time: String) -> Array:
	var result: Array = []

	for category in hazards:
		for hazard_id in hazards[category]:
			var hazard: Dictionary = hazards[category][hazard_id]
			var conditions: Dictionary = hazard.get("trigger_conditions", {})

			# Check terrain match
			var terrains: Array = conditions.get("terrains", [])
			if not terrains.is_empty() and terrain not in terrains:
				continue

			# Check weather match (empty = any weather)
			var weathers: Array = conditions.get("weather", [])
			if not weathers.is_empty() and weather not in weathers:
				continue

			# Check time match (empty = any time)
			var times: Array = conditions.get("time_of_day", [])
			if not times.is_empty() and time not in times:
				continue

			result.append(hazard)

	return result


func _select_hazard(applicable: Array) -> Dictionary:
	if applicable.is_empty():
		return {}

	# Simple random selection for now (could add rarity weighting later)
	return applicable[randi() % applicable.size()]


func _trigger_hazard(coords: Vector2i, terrain: String, hazard_data: Dictionary) -> void:
	print("HazardManager: Triggered '%s' at %s (terrain: %s)" % [
		hazard_data.get("name", "Unknown"),
		coords,
		terrain
	])

	hazard_triggered.emit(coords, hazard_data)
	_emit_to_event_bus("hazard_triggered", [coords, hazard_data.get("id", "")])

	# Roll stat save
	var save_result := _roll_stat_save(hazard_data)

	# Apply effects based on save result
	var effects := _apply_hazard_effects(hazard_data, save_result)

	# Emit message for UI
	hazard_message.emit(hazard_data, save_result, effects)

# =============================================================================
# STAT SAVES
# =============================================================================

func _roll_stat_save(hazard_data: Dictionary) -> Dictionary:
	var save_config: Dictionary = hazard_data.get("stat_save", {})

	if save_config.is_empty() or not _player_stats:
		# No save = auto-fail
		return {
			"success": false,
			"auto_fail": true,
			"message": hazard_data.get("description", "")
		}

	var stat: String = save_config.get("stat", "fortitude")
	var dc: int = save_config.get("dc", 12)
	var skill_bonus: int = 0  # Could add skill bonus calculation here

	var result: Dictionary = _player_stats.roll_check(stat, dc, skill_bonus)

	result["success_message"] = save_config.get("success_message", "You resist the effect.")
	result["failure_message"] = save_config.get("failure_message", "You suffer the full effect.")
	result["message"] = save_config.get("success_message" if result["success"] else "failure_message", "")

	hazard_save_rolled.emit(hazard_data.get("id", ""), result)
	_emit_to_event_bus("hazard_save_rolled", [hazard_data.get("id", ""), result["success"]])

	print("HazardManager: %s save - DC %d - %s (margin %+d)" % [
		stat.capitalize(),
		dc,
		"SUCCESS" if result["success"] else "FAILURE",
		result.get("margin", 0)
	])

	return result


func _apply_hazard_effects(hazard_data: Dictionary, save_result: Dictionary) -> Dictionary:
	var success: bool = save_result.get("success", false)
	var effects_config: Dictionary = hazard_data.get("effects", {})
	var effects_key: String = "on_success" if success else "on_failure"
	var effects: Dictionary = effects_config.get(effects_key, {})

	var applied := {}

	# Apply damage
	var damage: int = effects.get("damage", 0)
	if damage > 0 and _survival_manager:
		_survival_manager.modify_health(-damage, hazard_data.get("id", "hazard"))
		applied["damage"] = damage

	# Apply status effects
	var status_effects: Array = effects.get("status_effects", [])
	if not status_effects.is_empty() and _effect_manager:
		for effect_id in status_effects:
			_effect_manager.apply_effect("player", effect_id, "hazard_" + hazard_data.get("id", ""))
		applied["status_effects"] = status_effects

	# Apply turn cost
	var turn_cost: int = effects.get("turn_cost", 0)
	if turn_cost > 0:
		var time_manager = get_node_or_null("/root/TimeManager")
		if time_manager and time_manager.has_method("advance_turn"):
			time_manager.advance_turn(turn_cost)
		applied["turn_cost"] = turn_cost

	hazard_effects_applied.emit(hazard_data.get("id", ""), applied)
	_emit_to_event_bus("hazard_effects_applied", [hazard_data.get("id", ""), applied])

	return applied

# =============================================================================
# PUBLIC API
# =============================================================================

## Force trigger a specific hazard (for testing/events).
func force_trigger_hazard(hazard_id: String, coords: Vector2i) -> void:
	var hazard_data := _find_hazard_by_id(hazard_id)

	if hazard_data.is_empty():
		push_warning("HazardManager: Unknown hazard '%s'" % hazard_id)
		return

	_trigger_hazard(coords, "forced", hazard_data)


func _find_hazard_by_id(hazard_id: String) -> Dictionary:
	for category in hazards:
		if hazards[category].has(hazard_id):
			return hazards[category][hazard_id]
	return {}

# =============================================================================
# QUERIES
# =============================================================================

## Get all hazards that could trigger in a specific terrain.
func get_hazards_for_terrain(terrain: String) -> Array:
	var result: Array = []

	for category in hazards:
		for hazard_id in hazards[category]:
			var hazard: Dictionary = hazards[category][hazard_id]
			var terrains: Array = hazard.get("trigger_conditions", {}).get("terrains", [])

			if terrains.is_empty() or terrain in terrains:
				result.append(hazard)

	return result


## Get hazard info by ID.
func get_hazard_info(hazard_id: String) -> Dictionary:
	return _find_hazard_by_id(hazard_id)

# =============================================================================
# DEBUG
# =============================================================================

func debug_list_hazards() -> void:
	print("=== Hazards ===")
	for category in hazards:
		print("--- %s ---" % category)
		for hazard_id in hazards[category]:
			var h: Dictionary = hazards[category][hazard_id]
			print("  %s: %s (DC %d %s, %.1f%% chance)" % [
				hazard_id,
				h.get("name", "?"),
				h.get("stat_save", {}).get("dc", 0),
				h.get("stat_save", {}).get("stat", "?"),
				h.get("trigger_conditions", {}).get("base_chance", 0.0) * 100.0
			])


func debug_trigger_hazard(hazard_id: String) -> void:
	force_trigger_hazard(hazard_id, Vector2i.ZERO)

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
