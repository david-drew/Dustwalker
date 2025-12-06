# environment_manager.gd
# Manages visual environmental effects: time-of-day lighting and weather overlays.
# Add as a CanvasLayer to your main scene.
#
# FEATURES:
# - Time-of-day tinting (dawn, day, dusk, night)
# - Smooth transitions between periods
# - Weather overlay support (future)
# - Stacking overlays for combined effects
#
# DEPENDENCIES:
# - TimeManager (autoload): For turn signals

extends CanvasLayer
class_name EnvironmentManager

# =============================================================================
# SIGNALS
# =============================================================================

signal time_period_changed(old_period: String, new_period: String)
signal weather_changed(old_weather: String, new_weather: String)

# =============================================================================
# CONSTANTS
# =============================================================================

## Time period definitions: color and alpha for each period
const TIME_PERIODS := {
	"dawn": {
		"color": Color(1.0, 0.85, 0.6),  # Golden
		"alpha": 0.18,
		"turns": [1]
	},
	"day": {
		"color": Color(1.0, 1.0, 1.0),  # Clear (no tint)
		"alpha": 0.0,
		"turns": [2, 3]
	},
	"dusk": {
		"color": Color(1.0, 0.6, 0.5),  # Pink/Orange
		"alpha": 0.22,
		"turns": [4]
	},
	"night": {
		"color": Color(0.15, 0.15, 0.35),  # Dark Blue
		"alpha": 0.45,
		"turns": [5]
	},
	"late_night": {
		"color": Color(0.08, 0.08, 0.25),  # Darker Blue
		"alpha": 0.55,
		"turns": [6]
	}
}

## Weather definitions (for future use)
const WEATHER_TYPES := {
	"clear": {
		"color": Color(1.0, 1.0, 1.0),
		"alpha": 0.0
	},
	"overcast": {
		"color": Color(0.5, 0.5, 0.55),
		"alpha": 0.15
	},
	"rain": {
		"color": Color(0.4, 0.45, 0.55),
		"alpha": 0.2
	},
	"dust_storm": {
		"color": Color(0.85, 0.65, 0.35),
		"alpha": 0.35
	},
	"fog": {
		"color": Color(0.75, 0.75, 0.8),
		"alpha": 0.3
	}
}

# =============================================================================
# CONFIGURATION
# =============================================================================

## Duration of transition tweens in seconds.
@export var transition_duration: float = 0.8

## CanvasLayer layer (should be above game, below UI).
@export var overlay_layer: int = 5

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _time_of_day_rect: ColorRect
var _weather_rect: ColorRect
var _tween: Tween

# =============================================================================
# STATE
# =============================================================================

var _current_period: String = "day"
var _current_weather: String = "clear"
var _initialized: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	layer = overlay_layer
	add_to_group("environment_manager")
	
	_create_overlays()
	_connect_signals()
	
	# Initialize to current time
	_initialize_to_current_time()
	
	_initialized = true
	print("EnvironmentManager: Initialized")


func _create_overlays() -> void:
	# Time of day overlay
	_time_of_day_rect = ColorRect.new()
	_time_of_day_rect.name = "TimeOfDayOverlay"
	_time_of_day_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_time_of_day_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_of_day_rect.color = Color(0, 0, 0, 0)  # Start transparent
	add_child(_time_of_day_rect)
	
	# Weather overlay (on top of time-of-day)
	_weather_rect = ColorRect.new()
	_weather_rect.name = "WeatherOverlay"
	_weather_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weather_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_rect.color = Color(0, 0, 0, 0)  # Start transparent
	add_child(_weather_rect)


func _connect_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if time_manager.has_signal("turn_started"):
			time_manager.turn_started.connect(_on_turn_started)
		if time_manager.has_signal("time_initialized"):
			time_manager.time_initialized.connect(_on_time_initialized)
	else:
		push_warning("EnvironmentManager: TimeManager not found")


func _initialize_to_current_time() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return
	
	var current_turn: int = 1
	if time_manager.has_method("get_current_turn"):
		current_turn = time_manager.get_current_turn()
	elif "current_turn" in time_manager:
		current_turn = time_manager.current_turn
	
	var period := _get_period_for_turn(current_turn)
	_set_period_immediate(period)

# =============================================================================
# TIME OF DAY
# =============================================================================

func _on_turn_started(turn: int, _day: int, _time_name: String) -> void:
	var new_period := _get_period_for_turn(turn)
	if new_period != _current_period:
		_transition_to_period(new_period)


func _on_time_initialized() -> void:
	_initialize_to_current_time()


func _get_period_for_turn(turn: int) -> String:
	for period_name in TIME_PERIODS:
		var period_data: Dictionary = TIME_PERIODS[period_name]
		if turn in period_data.get("turns", []):
			return period_name
	return "day"


func _transition_to_period(new_period: String) -> void:
	if not TIME_PERIODS.has(new_period):
		push_warning("EnvironmentManager: Unknown period '%s'" % new_period)
		return
	
	var old_period := _current_period
	_current_period = new_period
	
	var period_data: Dictionary = TIME_PERIODS[new_period]
	var target_color: Color = period_data.get("color", Color.WHITE)
	var target_alpha: float = period_data.get("alpha", 0.0)
	
	# Create final color with alpha
	var final_color := Color(target_color.r, target_color.g, target_color.b, target_alpha)
	
	# Kill any existing tween
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Create new tween
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_time_of_day_rect, "color", final_color, transition_duration)
	
	print("EnvironmentManager: Transitioning from %s to %s" % [old_period, new_period])
	
	time_period_changed.emit(old_period, new_period)
	_emit_to_event_bus("time_period_changed", [old_period, new_period])


func _set_period_immediate(period: String) -> void:
	if not TIME_PERIODS.has(period):
		return
	
	_current_period = period
	
	var period_data: Dictionary = TIME_PERIODS[period]
	var target_color: Color = period_data.get("color", Color.WHITE)
	var target_alpha: float = period_data.get("alpha", 0.0)
	
	_time_of_day_rect.color = Color(target_color.r, target_color.g, target_color.b, target_alpha)
	
	print("EnvironmentManager: Set period to %s (immediate)" % period)

# =============================================================================
# WEATHER (Future)
# =============================================================================

## Set the current weather effect.
func set_weather(weather: String) -> void:
	if not WEATHER_TYPES.has(weather):
		push_warning("EnvironmentManager: Unknown weather '%s'" % weather)
		return
	
	if weather == _current_weather:
		return
	
	var old_weather := _current_weather
	_current_weather = weather
	
	var weather_data: Dictionary = WEATHER_TYPES[weather]
	var target_color: Color = weather_data.get("color", Color.WHITE)
	var target_alpha: float = weather_data.get("alpha", 0.0)
	
	var final_color := Color(target_color.r, target_color.g, target_color.b, target_alpha)
	
	# Tween weather overlay
	var weather_tween := create_tween()
	weather_tween.set_ease(Tween.EASE_IN_OUT)
	weather_tween.set_trans(Tween.TRANS_SINE)
	weather_tween.tween_property(_weather_rect, "color", final_color, transition_duration)
	
	print("EnvironmentManager: Weather changing from %s to %s" % [old_weather, weather])
	
	weather_changed.emit(old_weather, weather)
	_emit_to_event_bus("weather_changed", [old_weather, weather])


## Clear weather (convenience method).
func clear_weather() -> void:
	set_weather("clear")

# =============================================================================
# QUERIES
# =============================================================================

## Get the current time period.
func get_current_period() -> String:
	return _current_period


## Get the current weather.
func get_current_weather() -> String:
	return _current_weather


## Check if it's currently night time.
func is_night() -> bool:
	return _current_period in ["night", "late_night"]


## Check if it's currently day time.
func is_day() -> bool:
	return _current_period in ["day", "dawn", "dusk"]


## Get visibility modifier based on time and weather.
## Returns 1.0 for full visibility, lower for reduced visibility.
func get_visibility_modifier() -> float:
	var modifier := 1.0
	
	# Time of day reduction
	match _current_period:
		"night":
			modifier *= 0.6
		"late_night":
			modifier *= 0.4
		"dawn", "dusk":
			modifier *= 0.85
	
	# Weather reduction
	match _current_weather:
		"fog":
			modifier *= 0.5
		"dust_storm":
			modifier *= 0.4
		"rain":
			modifier *= 0.8
		"overcast":
			modifier *= 0.9
	
	return modifier

# =============================================================================
# PUBLIC API
# =============================================================================

## Force set time period (for testing/debug).
func debug_set_period(period: String) -> void:
	_transition_to_period(period)


## Force set weather (for testing/debug).
func debug_set_weather(weather: String) -> void:
	set_weather(weather)


## Cycle through all periods (debug).
func debug_cycle_periods() -> void:
	var periods := TIME_PERIODS.keys()
	var current_index := periods.find(_current_period)
	var next_index := (current_index + 1) % periods.size()
	_transition_to_period(periods[next_index])


## List all available periods and weather types.
func debug_list_options() -> void:
	print("=== Time Periods ===")
	for period in TIME_PERIODS:
		var data: Dictionary = TIME_PERIODS[period]
		print("  %s: turns %s, alpha %.2f" % [period, data.get("turns", []), data.get("alpha", 0)])
	
	print("=== Weather Types ===")
	for weather in WEATHER_TYPES:
		var data: Dictionary = WEATHER_TYPES[weather]
		print("  %s: alpha %.2f" % [weather, data.get("alpha", 0)])

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
