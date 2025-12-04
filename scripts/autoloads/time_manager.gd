# time_manager.gd
# Global time management system for turn-based gameplay.
# Tracks turns (1-6 per day), days, seasons, and total elapsed time.
# Add as autoload named "TimeManager" in Project Settings.
#
# TIME STRUCTURE:
# - 6 turns per day, each representing 4 hours
# - Turn 1: Midnight-4am (Late Night)
# - Turn 2: 4am-8am (Dawn)
# - Turn 3: 8am-Noon (Morning)
# - Turn 4: Noon-4pm (Afternoon)
# - Turn 5: 4pm-8pm (Evening)
# - Turn 6: 8pm-Midnight (Night)
#
# SEASON STRUCTURE:
# - 360 days per year (4 seasons of 90 days each)
# - Spring: Days 1-90
# - Summer: Days 91-180
# - Fall: Days 181-270
# - Winter: Days 271-360

extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

const TURNS_PER_DAY: int = 6
const HOURS_PER_TURN: int = 4
const DAYS_PER_SEASON: int = 90
const DAYS_PER_YEAR: int = 360

const TIME_NAMES: Dictionary = {
	1: "Late Night",
	2: "Dawn",
	3: "Morning",
	4: "Afternoon",
	5: "Evening",
	6: "Night"
}

const TIME_ICONS: Dictionary = {
	1: "🌙",  # Late Night - moon
	2: "🌅",  # Dawn - sunrise
	3: "☀️",  # Morning - sun
	4: "🌤️",  # Afternoon - sun with cloud
	5: "🌇",  # Evening - sunset
	6: "🌙"   # Night - moon
}

const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Fall", "Winter"]

const SEASON_ICONS: Dictionary = {
	"Spring": "🌱",
	"Summer": "☀️",
	"Fall": "🍂",
	"Winter": "❄️"
}

## Temperature modifier per time of day (applied to base season temperature)
## Represents deviation from daily average in degrees Fahrenheit
const TIME_TEMPERATURE_MODIFIERS: Dictionary = {
	1: -15,  # Late Night - coldest
	2: -10,  # Dawn - cold
	3: 0,    # Morning - average
	4: 10,   # Afternoon - warmest
	5: 5,    # Evening - cooling
	6: -5    # Night - cold
}

## Base temperatures by season (in Fahrenheit, represents daily average)
const SEASON_BASE_TEMPERATURES: Dictionary = {
	"Spring": 55,
	"Summer": 80,
	"Fall": 55,
	"Winter": 30
}

## Temperature variance by season (random daily fluctuation)
const SEASON_TEMPERATURE_VARIANCE: Dictionary = {
	"Spring": 15,
	"Summer": 20,
	"Fall": 15,
	"Winter": 20
}

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a new turn starts.
signal turn_started(turn: int, day: int, time_name: String)

## Emitted when turns are advanced (before new turn starts).
signal turn_advanced(old_turn: int, new_turn: int, turns_consumed: int)

## Emitted when a turn ends.
signal turn_ended(turn: int, day: int)

## Emitted when a new day starts.
signal day_started(day: int)

## Emitted when time of day changes (e.g., Morning to Afternoon).
signal time_of_day_changed(old_name: String, new_name: String)

## Emitted when season changes.
signal season_changed(old_season: String, new_season: String)

## Emitted when a new year starts.
signal year_started(year: int)

## Emitted when night begins (for sleep tracking).
signal night_started(day: int)

## Emitted when dawn begins (for sleep tracking).
signal dawn_started(day: int)

# =============================================================================
# STATE
# =============================================================================

## Current turn within the day (1-6).
var current_turn: int = 3:  # Start at Morning
	set(value):
		current_turn = clampi(value, 1, TURNS_PER_DAY)

## Current day number (starts at 1).
var current_day: int = 1

## Total turns elapsed since game start.
var total_turns_elapsed: int = 0

## Whether time is currently paused (for cutscenes, menus, etc.).
var time_paused: bool = false

## Daily temperature variance (randomized each day).
var _daily_temp_variance: float = 0.0

## Turn event hooks - arrays of callables to invoke at specific times.
var _turn_start_hooks: Array[Callable] = []
var _turn_end_hooks: Array[Callable] = []
var _day_start_hooks: Array[Callable] = []
var _season_change_hooks: Array[Callable] = []

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_randomize_daily_temperature()
	print("TimeManager: Initialized (Day %d, Turn %d - %s, %s)" % [
		current_day, current_turn, get_time_of_day(), get_season()
	])


## Resets time to initial state (for new game).
func reset_time() -> void:
	current_turn = 3  # Start at Morning
	current_day = 1
	total_turns_elapsed = 0
	time_paused = false
	_randomize_daily_temperature()
	print("TimeManager: Reset to Day 1, Turn 3 (Morning, Spring)")

# =============================================================================
# TIME QUERIES
# =============================================================================

## Gets the name of the current time of day.
func get_time_of_day() -> String:
	return TIME_NAMES.get(current_turn, "Unknown")


## Gets the icon for the current time of day.
func get_time_icon() -> String:
	return TIME_ICONS.get(current_turn, "⏰")


## Gets the number of turns remaining in the current day.
func get_turns_remaining_today() -> int:
	return TURNS_PER_DAY - current_turn


## Checks if the player can afford a certain number of turns.
## Always returns true since multi-day actions are allowed.
func can_afford_turns(cost: int) -> bool:
	return cost > 0


## Gets the hour of day (0-23) for the current turn.
func get_hour_of_day() -> int:
	# Turn 1 starts at midnight (0), each turn is 4 hours
	return ((current_turn - 1) * HOURS_PER_TURN) % 24


## Checks if it's currently daytime (Dawn through Evening).
func is_daytime() -> bool:
	return current_turn >= 2 and current_turn <= 5


## Checks if it's currently nighttime (Night or Late Night).
func is_nighttime() -> bool:
	return current_turn == 1 or current_turn == 6


## Gets the total game time as a formatted string.
func get_time_string() -> String:
	return "Day %d, %s" % [current_day, get_time_of_day()]


## Gets detailed time info as a dictionary.
func get_time_data() -> Dictionary:
	return {
		"turn": current_turn,
		"day": current_day,
		"total_turns": total_turns_elapsed,
		"time_name": get_time_of_day(),
		"time_icon": get_time_icon(),
		"is_daytime": is_daytime(),
		"hour": get_hour_of_day(),
		"turns_remaining_today": get_turns_remaining_today(),
		"season": get_season(),
		"season_icon": get_season_icon(),
		"year": get_year(),
		"day_of_season": get_day_of_season(),
		"season_progress": get_season_progress()
	}

# =============================================================================
# SEASON QUERIES
# =============================================================================

## Gets the current season name.
func get_season() -> String:
	var day_of_year := get_day_of_year()
	var season_index := (day_of_year - 1) / DAYS_PER_SEASON
	return SEASON_NAMES[clampi(season_index, 0, 3)]


## Gets the icon for the current season.
func get_season_icon() -> String:
	return SEASON_ICONS.get(get_season(), "📅")


## Gets the current year (1-based).
func get_year() -> int:
	return ((current_day - 1) / DAYS_PER_YEAR) + 1


## Gets the day within the current year (1-360).
func get_day_of_year() -> int:
	return ((current_day - 1) % DAYS_PER_YEAR) + 1


## Gets the day within the current season (1-90).
func get_day_of_season() -> int:
	return ((get_day_of_year() - 1) % DAYS_PER_SEASON) + 1


## Gets progress through the current season (0.0 to 1.0).
func get_season_progress() -> float:
	return float(get_day_of_season() - 1) / float(DAYS_PER_SEASON)


## Checks if it's currently a specific season.
func is_season(season_name: String) -> bool:
	return get_season().to_lower() == season_name.to_lower()


## Gets the season for a specific day.
func get_season_for_day(day: int) -> String:
	var day_of_year := ((day - 1) % DAYS_PER_YEAR) + 1
	var season_index := (day_of_year - 1) / DAYS_PER_SEASON
	return SEASON_NAMES[clampi(season_index, 0, 3)]

# =============================================================================
# TEMPERATURE QUERIES
# =============================================================================

## Gets the base temperature for the current time (before terrain modifiers).
## Returns temperature in Fahrenheit.
func get_base_temperature() -> float:
	var season := get_season()
	var base: float = SEASON_BASE_TEMPERATURES.get(season, 60)
	var time_mod: float = TIME_TEMPERATURE_MODIFIERS.get(current_turn, 0)
	return base + time_mod + _daily_temp_variance


## Gets the temperature modifier for the current time of day.
func get_time_temperature_modifier() -> float:
	return TIME_TEMPERATURE_MODIFIERS.get(current_turn, 0)


## Gets temperature data as a dictionary.
func get_temperature_data() -> Dictionary:
	var season := get_season()
	return {
		"base_temperature": get_base_temperature(),
		"season_base": SEASON_BASE_TEMPERATURES.get(season, 60),
		"time_modifier": get_time_temperature_modifier(),
		"daily_variance": _daily_temp_variance,
		"season": season
	}


func _randomize_daily_temperature() -> void:
	var season := get_season()
	var variance: float = SEASON_TEMPERATURE_VARIANCE.get(season, 15)
	_daily_temp_variance = randf_range(-variance, variance)

# =============================================================================
# TIME ADVANCEMENT
# =============================================================================

## Advances time by the specified number of turns.
## Handles day rollover automatically.
## @param turns: int - Number of turns to advance (default 1).
## @return Dictionary - Info about what changed {days_passed, old_turn, new_turn, old_day, new_day}.
func advance_turn(turns: int = 1) -> Dictionary:
	if time_paused:
		push_warning("TimeManager: Cannot advance turn while paused")
		return {}
	
	if turns <= 0:
		return {}
	
	var old_turn := current_turn
	var old_day := current_day
	var old_time_name := get_time_of_day()
	var old_season := get_season()
	var old_year := get_year()
	var days_passed := 0
	
	# Emit turn end for current turn
	_invoke_hooks(_turn_end_hooks)
	turn_ended.emit(current_turn, current_day)
	_emit_to_event_bus("turn_ended", [current_turn, current_day])
	
	# Calculate new turn and day
	var total_new_turns := current_turn + turns
	
	while total_new_turns > TURNS_PER_DAY:
		total_new_turns -= TURNS_PER_DAY
		current_day += 1
		days_passed += 1
		
		# Randomize temperature for new day
		_randomize_daily_temperature()
		
		# Check for season change
		var new_season := get_season()
		if old_season != new_season:
			_invoke_hooks(_season_change_hooks)
			season_changed.emit(old_season, new_season)
			_emit_to_event_bus("season_changed", [old_season, new_season])
			print("TimeManager: Season changed to %s" % new_season)
			old_season = new_season
		
		# Check for year change
		var new_year := get_year()
		if old_year != new_year:
			year_started.emit(new_year)
			_emit_to_event_bus("year_started", [new_year])
			print("TimeManager: Year %d begins" % new_year)
			old_year = new_year
		
		# Emit day started
		_invoke_hooks(_day_start_hooks)
		day_started.emit(current_day)
		_emit_to_event_bus("day_started", [current_day])
		print("TimeManager: Day %d begins" % current_day)
	
	current_turn = total_new_turns
	total_turns_elapsed += turns
	
	# Check for time of day change
	var new_time_name := get_time_of_day()
	if old_time_name != new_time_name:
		time_of_day_changed.emit(old_time_name, new_time_name)
		_emit_to_event_bus("time_of_day_changed", [old_time_name, new_time_name])
		
		# Check for night/dawn transitions
		if new_time_name == "Night":
			night_started.emit(current_day)
			_emit_to_event_bus("night_started", [current_day])
		elif new_time_name == "Dawn":
			dawn_started.emit(current_day)
			_emit_to_event_bus("dawn_started", [current_day])
	
	# Emit turn advanced
	turn_advanced.emit(old_turn, current_turn, turns)
	_emit_to_event_bus("turn_advanced", [old_turn, current_turn, turns])
	
	# Emit turn started for new turn
	_invoke_hooks(_turn_start_hooks)
	turn_started.emit(current_turn, current_day, new_time_name)
	_emit_to_event_bus("turn_started", [current_turn, current_day, new_time_name])
	
	print("TimeManager: Advanced %d turn(s) → Day %d, Turn %d (%s)" % [
		turns, current_day, current_turn, new_time_name
	])
	
	return {
		"days_passed": days_passed,
		"old_turn": old_turn,
		"new_turn": current_turn,
		"old_day": old_day,
		"new_day": current_day,
		"turns_consumed": turns
	}


## Manually ends the current turn (advances by 1).
func end_turn() -> Dictionary:
	return advance_turn(1)


## Sets the time to a specific turn and day (for loading saves).
func set_time(turn: int, day: int, total_elapsed: int = -1) -> void:
	current_turn = clampi(turn, 1, TURNS_PER_DAY)
	current_day = maxi(day, 1)
	
	if total_elapsed >= 0:
		total_turns_elapsed = total_elapsed
	else:
		# Calculate from day and turn
		total_turns_elapsed = (current_day - 1) * TURNS_PER_DAY + current_turn - 1
	
	_randomize_daily_temperature()
	print("TimeManager: Set to Day %d, Turn %d (%s, %s)" % [
		current_day, current_turn, get_time_of_day(), get_season()
	])

# =============================================================================
# EVENT HOOKS
# =============================================================================

## Registers a callback to be called when a new turn starts.
func register_turn_start_hook(callback: Callable) -> void:
	if not callback in _turn_start_hooks:
		_turn_start_hooks.append(callback)


## Registers a callback to be called when a turn ends.
func register_turn_end_hook(callback: Callable) -> void:
	if not callback in _turn_end_hooks:
		_turn_end_hooks.append(callback)


## Registers a callback to be called when a new day starts.
func register_day_start_hook(callback: Callable) -> void:
	if not callback in _day_start_hooks:
		_day_start_hooks.append(callback)


## Registers a callback to be called when season changes.
func register_season_change_hook(callback: Callable) -> void:
	if not callback in _season_change_hooks:
		_season_change_hooks.append(callback)


## Unregisters a turn start hook.
func unregister_turn_start_hook(callback: Callable) -> void:
	_turn_start_hooks.erase(callback)


## Unregisters a turn end hook.
func unregister_turn_end_hook(callback: Callable) -> void:
	_turn_end_hooks.erase(callback)


## Unregisters a day start hook.
func unregister_day_start_hook(callback: Callable) -> void:
	_day_start_hooks.erase(callback)


## Unregisters a season change hook.
func unregister_season_change_hook(callback: Callable) -> void:
	_season_change_hooks.erase(callback)


func _invoke_hooks(hooks: Array[Callable]) -> void:
	for hook in hooks:
		if hook.is_valid():
			hook.call()

# =============================================================================
# PAUSE/RESUME
# =============================================================================

## Pauses time advancement.
func pause_time() -> void:
	time_paused = true
	print("TimeManager: Time paused")


## Resumes time advancement.
func resume_time() -> void:
	time_paused = false
	print("TimeManager: Time resumed")

# =============================================================================
# SERIALIZATION
# =============================================================================

## Converts time state to a dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"current_turn": current_turn,
		"current_day": current_day,
		"total_turns_elapsed": total_turns_elapsed,
		"daily_temp_variance": _daily_temp_variance
	}


## Loads time state from a dictionary.
func from_dict(data: Dictionary) -> void:
	set_time(
		data.get("current_turn", 3),
		data.get("current_day", 1),
		data.get("total_turns_elapsed", -1)
	)
	_daily_temp_variance = data.get("daily_temp_variance", 0.0)

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
