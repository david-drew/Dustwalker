# weather_manager.gd
# Manages random weather events that affect gameplay and visuals.
# Works with EnvironmentManager for visual overlays.
#
# FEATURES:
# - Random weather generation based on terrain/season
# - Weather duration and transitions
# - Temperature modifiers from weather
# - Gameplay effects (visibility, encounter rates, etc.)
#
# DEPENDENCIES:
# - TimeManager (autoload): For turn/day signals
# - EnvironmentManager: For visual overlays
# - SurvivalManager: For temperature effects

extends Node
class_name WeatherManager

# =============================================================================
# SIGNALS
# =============================================================================

signal weather_started(weather_type: String, duration: int)
signal weather_ended(weather_type: String)
signal weather_intensity_changed(weather_type: String, intensity: float)

# =============================================================================
# CONSTANTS
# =============================================================================

const CONFIG_PATH := "res://data/survival/weather_config.json"

## Default weather definitions if no config file
const DEFAULT_WEATHER := {
	"clear": {
		"name": "Clear",
		"description": "Clear skies",
		"temperature_modifier": 0,
		"visibility_modifier": 1.0,
		"encounter_modifier": 1.0,
		"travel_modifier": 1.0,
		"base_weight": 50
	},
	"overcast": {
		"name": "Overcast",
		"description": "Gray, cloudy skies",
		"temperature_modifier": -5,
		"visibility_modifier": 0.9,
		"encounter_modifier": 1.0,
		"travel_modifier": 1.0,
		"base_weight": 25,
		"duration_min": 4,
		"duration_max": 12
	},
	"rain": {
		"name": "Rain",
		"description": "Steady rainfall",
		"temperature_modifier": -10,
		"visibility_modifier": 0.7,
		"encounter_modifier": 0.8,
		"travel_modifier": 0.85,
		"fatigue_modifier": 1.25,
		"base_weight": 15,
		"duration_min": 2,
		"duration_max": 8,
		"blocked_terrains": ["desert"]
	},
	"dust_storm": {
		"name": "Dust Storm",
		"description": "Blinding dust and sand",
		"temperature_modifier": 5,
		"visibility_modifier": 0.3,
		"encounter_modifier": 0.5,
		"travel_modifier": 0.6,
		"fatigue_modifier": 1.5,
		"damage_per_turn": 1,
		"base_weight": 8,
		"duration_min": 1,
		"duration_max": 4,
		"allowed_terrains": ["desert", "badlands", "scrubland"]
	},
	"fog": {
		"name": "Fog",
		"description": "Thick, obscuring fog",
		"temperature_modifier": -5,
		"visibility_modifier": 0.4,
		"encounter_modifier": 1.2,
		"travel_modifier": 0.75,
		"base_weight": 10,
		"duration_min": 2,
		"duration_max": 6,
		"time_restriction": ["dawn", "night", "late_night"]
	},
	"heat_wave": {
		"name": "Heat Wave",
		"description": "Oppressive, dangerous heat",
		"temperature_modifier": 20,
		"visibility_modifier": 0.95,
		"encounter_modifier": 0.7,
		"travel_modifier": 0.8,
		"thirst_modifier": 1.5,
		"base_weight": 5,
		"duration_min": 4,
		"duration_max": 12,
		"allowed_terrains": ["desert", "badlands", "plains", "scrubland"]
	},
	"cold_snap": {
		"name": "Cold Snap",
		"description": "Bitter, dangerous cold",
		"temperature_modifier": -25,
		"visibility_modifier": 1.0,
		"encounter_modifier": 0.6,
		"travel_modifier": 0.85,
		"fatigue_modifier": 1.25,
		"base_weight": 5,
		"duration_min": 4,
		"duration_max": 12,
		"allowed_terrains": ["mountains", "plains", "forest"]
	}
}

## Terrain weather weight modifiers (can be overridden by config)
var TERRAIN_MODIFIERS := {
	"desert": {
		"dust_storm": 3.0,
		"heat_wave": 2.0,
		"rain": 0.0,
		"fog": 0.2
	},
	"swamp": {
		"fog": 2.5,
		"rain": 1.5,
		"dust_storm": 0.0
	},
	"mountains": {
		"cold_snap": 2.0,
		"fog": 1.5,
		"dust_storm": 0.0,
		"heat_wave": 0.3
	},
	"forest": {
		"fog": 1.3,
		"rain": 1.2
	},
	"plains": {
		"dust_storm": 0.5
	},
	"badlands": {
		"dust_storm": 2.0,
		"heat_wave": 1.5,
		"rain": 0.3
	}
}

# =============================================================================
# CONFIGURATION
# =============================================================================

## Chance to check for new weather each turn (when clear)
@export var weather_check_chance: float = 0.15

## Chance for weather to end early each turn
@export var weather_end_chance: float = 0.1

# =============================================================================
# STATE
# =============================================================================

var weather_definitions: Dictionary = {}
var current_weather: String = "clear"
var weather_turns_remaining: int = 0
var weather_intensity: float = 1.0  # For future gradual weather

## Cached references
var _environment_manager: EnvironmentManager = null
var _survival_manager: SurvivalManager = null
var _current_terrain: String = "plains"
var _current_period: String = "day"

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("weather_manager")
	_load_config()
	_connect_signals()
	print("WeatherManager: Initialized with %d weather types" % weather_definitions.size())


func _load_config() -> void:
	var config: Dictionary = {}
	
	# Try to load from DataLoader first
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
	
	# Apply config if loaded successfully
	if not config.is_empty() and config.has("weather"):
		weather_definitions = config["weather"]
		
		# Load terrain modifiers if present
		if config.has("terrain_modifiers"):
			# Override the constant with loaded data
			for terrain in config["terrain_modifiers"]:
				TERRAIN_MODIFIERS[terrain] = config["terrain_modifiers"][terrain]
		
		# Load settings if present
		if config.has("settings"):
			var settings: Dictionary = config["settings"]
			if settings.has("weather_check_chance"):
				weather_check_chance = settings["weather_check_chance"]
			if settings.has("weather_end_chance"):
				weather_end_chance = settings["weather_end_chance"]
		
		print("WeatherManager: Loaded config from file")
		return
	
	# Use defaults
	weather_definitions = DEFAULT_WEATHER.duplicate(true)
	print("WeatherManager: Using default weather definitions")


func _connect_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if time_manager.has_signal("turn_started"):
			time_manager.turn_started.connect(_on_turn_started)
	
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("player_moved_to_hex"):
			event_bus.player_moved_to_hex.connect(_on_player_moved)
		if event_bus.has_signal("time_period_changed"):
			event_bus.time_period_changed.connect(_on_time_period_changed)
	
	# Find references after a frame
	await get_tree().process_frame
	_find_references()


func _find_references() -> void:
	_environment_manager = get_tree().get_first_node_in_group("environment_manager")
	_survival_manager = get_tree().get_first_node_in_group("survival_manager")
	
	if _survival_manager:
		_current_terrain = _survival_manager.current_terrain

# =============================================================================
# TIME CALLBACKS
# =============================================================================

func _on_turn_started(_turn: int, _day: int, _time_name: String) -> void:
	if current_weather != "clear":
		_process_active_weather()
	else:
		_check_for_new_weather()


func _on_player_moved(hex_coords: Vector2i) -> void:
	# Update terrain for weather calculations
	var hex_grid = get_tree().get_first_node_in_group("hex_grid")
	if hex_grid and hex_grid.has_method("get_cell"):
		var cell = hex_grid.get_cell(hex_coords)
		if cell:
			_current_terrain = cell.terrain_type


func _on_time_period_changed(_old_period: String, new_period: String) -> void:
	_current_period = new_period
	
	# Some weather might end at certain times
	if current_weather == "fog" and new_period == "day":
		# Fog often clears during the day
		if randf() < 0.5:
			_end_weather()

# =============================================================================
# WEATHER LOGIC
# =============================================================================

func _check_for_new_weather() -> void:
	if randf() > weather_check_chance:
		return
	
	# Roll for weather type
	var weather_type := _roll_weather_type()
	if weather_type != "clear":
		_start_weather(weather_type)


func _roll_weather_type() -> String:
	var weights: Dictionary = {}
	var total_weight: float = 0.0
	
	for weather_id in weather_definitions:
		var weather_data: Dictionary = weather_definitions[weather_id]
		var weight: float = weather_data.get("base_weight", 10)
		
		# Check terrain restrictions
		var allowed_terrains: Array = weather_data.get("allowed_terrains", [])
		if not allowed_terrains.is_empty() and _current_terrain not in allowed_terrains:
			continue
		
		var blocked_terrains: Array = weather_data.get("blocked_terrains", [])
		if _current_terrain in blocked_terrains:
			continue
		
		# Check time restrictions
		var time_restriction: Array = weather_data.get("time_restriction", [])
		if not time_restriction.is_empty() and _current_period not in time_restriction:
			weight *= 0.3  # Reduce weight but don't block entirely
		
		# Apply terrain modifier
		if TERRAIN_MODIFIERS.has(_current_terrain):
			var terrain_mods: Dictionary = TERRAIN_MODIFIERS[_current_terrain]
			if terrain_mods.has(weather_id):
				weight *= terrain_mods[weather_id]
		
		if weight > 0:
			weights[weather_id] = weight
			total_weight += weight
	
	if total_weight <= 0:
		return "clear"
	
	# Weighted random selection
	var roll := randf() * total_weight
	var cumulative: float = 0.0
	
	for weather_id in weights:
		cumulative += weights[weather_id]
		if roll <= cumulative:
			return weather_id
	
	return "clear"


func _start_weather(weather_type: String) -> void:
	if not weather_definitions.has(weather_type):
		return
	
	var weather_data: Dictionary = weather_definitions[weather_type]
	
	# Calculate duration
	var min_duration: int = weather_data.get("duration_min", 2)
	var max_duration: int = weather_data.get("duration_max", 6)
	weather_turns_remaining = randi_range(min_duration, max_duration)
	
	current_weather = weather_type
	weather_intensity = 1.0
	
	print("WeatherManager: %s started (duration: %d turns)" % [weather_data.get("name", weather_type), weather_turns_remaining])
	
	# Update visual overlay
	_update_visual_overlay()
	
	# Emit signals
	weather_started.emit(weather_type, weather_turns_remaining)
	_emit_to_event_bus("weather_started", [weather_type, weather_turns_remaining])


func _process_active_weather() -> void:
	weather_turns_remaining -= 1
	
	# Apply per-turn effects
	_apply_weather_effects()
	
	# Check for early end
	if weather_turns_remaining <= 0 or randf() < weather_end_chance:
		_end_weather()
		return
	
	print("WeatherManager: %s continues (%d turns remaining)" % [current_weather, weather_turns_remaining])


func _end_weather() -> void:
	var ended_weather := current_weather
	current_weather = "clear"
	weather_turns_remaining = 0
	weather_intensity = 1.0
	
	print("WeatherManager: %s ended" % ended_weather)
	
	# Update visual overlay
	_update_visual_overlay()
	
	# Emit signals
	weather_ended.emit(ended_weather)
	_emit_to_event_bus("weather_ended", [ended_weather])


func _apply_weather_effects() -> void:
	if not weather_definitions.has(current_weather):
		return
	
	var weather_data: Dictionary = weather_definitions[current_weather]
	
	# Damage per turn (dust storm, etc.)
	var damage: int = weather_data.get("damage_per_turn", 0)
	if damage > 0 and _survival_manager:
		_survival_manager.modify_health(-damage, "weather_%s" % current_weather)
		print("WeatherManager: %s deals %d damage" % [current_weather, damage])


func _update_visual_overlay() -> void:
	if _environment_manager == null:
		_environment_manager = get_tree().get_first_node_in_group("environment_manager")
	
	if _environment_manager and _environment_manager.has_method("set_weather"):
		# Map weather types to overlay types
		var overlay_weather := current_weather
		
		# Some weather types might not have direct visual equivalents
		match current_weather:
			"heat_wave":
				overlay_weather = "clear"  # Heat wave is temperature, not visual
			"cold_snap":
				overlay_weather = "clear"  # Cold snap is temperature, not visual
		
		_environment_manager.set_weather(overlay_weather)

# =============================================================================
# QUERIES
# =============================================================================

## Get current weather type.
func get_current_weather() -> String:
	return current_weather


## Get current weather data.
func get_current_weather_data() -> Dictionary:
	if weather_definitions.has(current_weather):
		return weather_definitions[current_weather]
	return {}


## Get temperature modifier from current weather.
func get_temperature_modifier() -> int:
	var data := get_current_weather_data()
	return data.get("temperature_modifier", 0)


## Get visibility modifier from current weather.
func get_visibility_modifier() -> float:
	var data := get_current_weather_data()
	return data.get("visibility_modifier", 1.0)


## Get encounter rate modifier from current weather.
func get_encounter_modifier() -> float:
	var data := get_current_weather_data()
	return data.get("encounter_modifier", 1.0)


## Get travel speed modifier from current weather.
func get_travel_modifier() -> float:
	var data := get_current_weather_data()
	return data.get("travel_modifier", 1.0)


## Get fatigue modifier from current weather.
func get_fatigue_modifier() -> float:
	var data := get_current_weather_data()
	return data.get("fatigue_modifier", 1.0)


## Get thirst modifier from current weather.
func get_thirst_modifier() -> float:
	var data := get_current_weather_data()
	return data.get("thirst_modifier", 1.0)


## Check if there's active weather (not clear).
func has_active_weather() -> bool:
	return current_weather != "clear"


## Check if current weather is dangerous.
func is_dangerous_weather() -> bool:
	var data := get_current_weather_data()
	return data.get("damage_per_turn", 0) > 0


## Get turns remaining for current weather.
func get_turns_remaining() -> int:
	return weather_turns_remaining

# =============================================================================
# PUBLIC API
# =============================================================================

## Force start a specific weather type (for events/encounters).
func force_weather(weather_type: String, duration: int = -1) -> void:
	if not weather_definitions.has(weather_type):
		push_warning("WeatherManager: Unknown weather type '%s'" % weather_type)
		return
	
	# End current weather first
	if current_weather != "clear":
		_end_weather()
	
	if weather_type == "clear":
		return
	
	var weather_data: Dictionary = weather_definitions[weather_type]
	
	if duration < 0:
		var min_d: int = weather_data.get("duration_min", 2)
		var max_d: int = weather_data.get("duration_max", 6)
		duration = randi_range(min_d, max_d)
	
	current_weather = weather_type
	weather_turns_remaining = duration
	weather_intensity = 1.0
	
	_update_visual_overlay()
	
	weather_started.emit(weather_type, duration)
	_emit_to_event_bus("weather_started", [weather_type, duration])
	
	print("WeatherManager: Forced %s for %d turns" % [weather_type, duration])


## Force clear weather.
func force_clear() -> void:
	if current_weather != "clear":
		_end_weather()

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"current_weather": current_weather,
		"weather_turns_remaining": weather_turns_remaining,
		"weather_intensity": weather_intensity,
		"current_terrain": _current_terrain
	}


func from_dict(data: Dictionary) -> void:
	current_weather = data.get("current_weather", "clear")
	weather_turns_remaining = data.get("weather_turns_remaining", 0)
	weather_intensity = data.get("weather_intensity", 1.0)
	_current_terrain = data.get("current_terrain", "plains")
	
	# Update visual
	_update_visual_overlay()
	
	print("WeatherManager: Loaded from save - %s (%d turns remaining)" % [current_weather, weather_turns_remaining])

# =============================================================================
# DEBUG
# =============================================================================

func debug_set_weather(weather_type: String, duration: int = 4) -> void:
	force_weather(weather_type, duration)


func debug_clear_weather() -> void:
	force_clear()


func debug_list_weather() -> void:
	print("=== Weather Types ===")
	for weather_id in weather_definitions:
		var data: Dictionary = weather_definitions[weather_id]
		print("  %s: temp %+d, vis %.1f, weight %d" % [
			data.get("name", weather_id),
			data.get("temperature_modifier", 0),
			data.get("visibility_modifier", 1.0),
			data.get("base_weight", 0)
		])
	print("=== Current ===")
	print("  Weather: %s (%d turns remaining)" % [current_weather, weather_turns_remaining])
	print("  Terrain: %s" % _current_terrain)


func debug_roll_weather() -> void:
	var rolled := _roll_weather_type()
	print("Weather roll (terrain: %s): %s" % [_current_terrain, rolled])

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
