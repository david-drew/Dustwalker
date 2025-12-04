# survival_manager.gd
# Manages player survival needs: hunger, thirst, and health.
# Tracks decay over time and applies penalties/damage for neglected needs.
#
# SURVIVAL MECHANICS:
# - Hunger decreases every 6 turns (once per day)
# - Thirst decreases every 4 turns (twice per day)
# - Low hunger/thirst causes penalties and eventually health damage
# - Health reaching 0 triggers game over

extends Node
class_name SurvivalManager

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when hunger value changes.
signal hunger_changed(new_value: int, old_value: int)

## Emitted when thirst value changes.
signal thirst_changed(new_value: int, old_value: int)

## Emitted when health value changes.
signal health_changed(new_value: int, old_value: int, source: String)

## Emitted when a survival warning should be shown.
signal survival_warning(warning_type: String, level: int)

## Emitted when player is starving.
signal player_starving(hunger_level: int)

## Emitted when player is dehydrated.
signal player_dehydrated(thirst_level: int)

## Emitted when player dies.
signal player_died(cause: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Maximum hunger value.
var max_hunger: int = 10

## Maximum thirst value.
var max_thirst: int = 10

## Maximum health value.
var max_health: int = 20

## Turns between hunger decreases.
var hunger_decrease_interval: int = 6

## Turns between thirst decreases.
var thirst_decrease_interval: int = 4

## Amount of hunger restored by eating a ration.
var ration_restore_amount: int = 5

## Amount of thirst restored by drinking water.
var water_restore_amount: int = 5

## Warning thresholds.
var hunger_warning_threshold: int = 4
var hunger_critical_threshold: int = 2
var thirst_warning_threshold: int = 4
var thirst_critical_threshold: int = 2
var health_warning_threshold: int = 5
var health_critical_threshold: int = 3

# =============================================================================
# STATE
# =============================================================================

## Current hunger level (0-10).
var hunger: int = 10

## Current thirst level (0-10).
var thirst: int = 10

## Current health level (0-20).
var health: int = 20

## Turns since last hunger decrease.
var turns_since_hunger_decrease: int = 0

## Turns since last thirst decrease.
var turns_since_thirst_decrease: int = 0

## Whether the system has been initialized.
var _initialized: bool = false

## Whether survival is paused (for debugging).
var _paused: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()
	_connect_signals()
	_initialized = true


func _load_config() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader == null:
		return
	
	var config: Dictionary = loader.load_json("res://data/survival/survival_config.json")
	if config.is_empty():
		print("SurvivalManager: Using default configuration")
		return
	
	var survival: Dictionary = config.get("survival", {})
	
	# Hunger config
	var hunger_config: Dictionary = survival.get("hunger", {})
	max_hunger = hunger_config.get("max", 10)
	hunger = hunger_config.get("starting", 10)
	hunger_decrease_interval = hunger_config.get("decrease_interval_turns", 6)
	ration_restore_amount = hunger_config.get("ration_restore_amount", 5)
	
	# Thirst config
	var thirst_config: Dictionary = survival.get("thirst", {})
	max_thirst = thirst_config.get("max", 10)
	thirst = thirst_config.get("starting", 10)
	thirst_decrease_interval = thirst_config.get("decrease_interval_turns", 4)
	water_restore_amount = thirst_config.get("water_restore_amount", 5)
	
	# Health config
	var health_config: Dictionary = survival.get("health", {})
	max_health = health_config.get("max", 20)
	health = health_config.get("starting", 20)
	
	# Warning thresholds
	var thresholds: Dictionary = survival.get("warning_thresholds", {})
	hunger_warning_threshold = thresholds.get("hunger_warning", 4)
	hunger_critical_threshold = thresholds.get("hunger_critical", 2)
	thirst_warning_threshold = thresholds.get("thirst_warning", 4)
	thirst_critical_threshold = thresholds.get("thirst_critical", 2)
	health_warning_threshold = thresholds.get("health_warning", 5)
	health_critical_threshold = thresholds.get("health_critical", 3)
	
	# Starting inventory loaded by InventoryManager
	print("SurvivalManager: Configuration loaded")


func _connect_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if time_manager.has_signal("turn_advanced"):
			time_manager.turn_advanced.connect(_on_turn_advanced)


## Initializes/resets survival state for a new game.
func initialize() -> void:
	_load_config()
	turns_since_hunger_decrease = 0
	turns_since_thirst_decrease = 0
	_emit_all_stats()
	print("SurvivalManager: Initialized (Hunger: %d, Thirst: %d, Health: %d)" % [hunger, thirst, health])

# =============================================================================
# TURN PROCESSING
# =============================================================================

## Called when turns advance.
func _on_turn_advanced(old_turn: int, new_turn: int, turns_consumed: int) -> void:
	if _paused:
		return
	
	process_turns(turns_consumed)


## Process the passage of time (called for each turn that passes).
func process_turns(turns: int = 1) -> void:
	for i in range(turns):
		_process_single_turn()


func _process_single_turn() -> void:
	# Update turn counters
	turns_since_hunger_decrease += 1
	turns_since_thirst_decrease += 1
	
	# Check for hunger decrease
	if turns_since_hunger_decrease >= hunger_decrease_interval:
		_decrease_hunger(1)
		turns_since_hunger_decrease = 0
	
	# Check for thirst decrease
	if turns_since_thirst_decrease >= thirst_decrease_interval:
		_decrease_thirst(1)
		turns_since_thirst_decrease = 0
	
	# Apply survival damage
	_apply_survival_damage()
	
	# Check warnings
	_check_warnings()
	
	# Check death
	_check_death_condition()

# =============================================================================
# HUNGER MANAGEMENT
# =============================================================================

func _decrease_hunger(amount: int) -> void:
	var old_value := hunger
	hunger = maxi(0, hunger - amount)
	
	if hunger != old_value:
		hunger_changed.emit(hunger, old_value)
		_emit_to_event_bus("hunger_changed", [hunger, old_value])
		
		if hunger <= hunger_critical_threshold:
			player_starving.emit(hunger)
			_emit_to_event_bus("player_starving", [hunger])


## Eat a ration to restore hunger.
## @return bool - True if successfully ate, false if already full.
func eat_ration() -> bool:
	if hunger >= max_hunger:
		return false
	
	var old_value := hunger
	hunger = mini(max_hunger, hunger + ration_restore_amount)
	
	hunger_changed.emit(hunger, old_value)
	_emit_to_event_bus("hunger_changed", [hunger, old_value])
	
	return true


## Modify hunger directly (for encounter effects).
func modify_hunger(amount: int) -> void:
	var old_value := hunger
	hunger = clampi(hunger + amount, 0, max_hunger)
	
	if hunger != old_value:
		hunger_changed.emit(hunger, old_value)
		_emit_to_event_bus("hunger_changed", [hunger, old_value])


## Gets the current hunger stage name.
func get_hunger_stage() -> String:
	if hunger >= 8:
		return "well_fed"
	elif hunger >= 5:
		return "peckish"
	elif hunger >= 3:
		return "hungry"
	elif hunger >= 1:
		return "starving"
	else:
		return "dying"

# =============================================================================
# THIRST MANAGEMENT
# =============================================================================

func _decrease_thirst(amount: int) -> void:
	var old_value := thirst
	thirst = maxi(0, thirst - amount)
	
	if thirst != old_value:
		thirst_changed.emit(thirst, old_value)
		_emit_to_event_bus("thirst_changed", [thirst, old_value])
		
		if thirst <= thirst_critical_threshold:
			player_dehydrated.emit(thirst)
			_emit_to_event_bus("player_dehydrated", [thirst])


## Drink water to restore thirst.
## @return bool - True if successfully drank, false if already full.
func drink_water() -> bool:
	if thirst >= max_thirst:
		return false
	
	var old_value := thirst
	thirst = mini(max_thirst, thirst + water_restore_amount)
	
	thirst_changed.emit(thirst, old_value)
	_emit_to_event_bus("thirst_changed", [thirst, old_value])
	
	return true


## Modify thirst directly (for encounter effects).
func modify_thirst(amount: int) -> void:
	var old_value := thirst
	thirst = clampi(thirst + amount, 0, max_thirst)
	
	if thirst != old_value:
		thirst_changed.emit(thirst, old_value)
		_emit_to_event_bus("thirst_changed", [thirst, old_value])


## Gets the current thirst stage name.
func get_thirst_stage() -> String:
	if thirst >= 8:
		return "hydrated"
	elif thirst >= 5:
		return "thirsty"
	elif thirst >= 3:
		return "parched"
	elif thirst >= 1:
		return "dehydrated"
	else:
		return "dying"

# =============================================================================
# HEALTH MANAGEMENT
# =============================================================================

## Take damage from a source.
func take_damage(amount: int, source: String = "unknown") -> void:
	if amount <= 0:
		return
	
	var old_value := health
	health = maxi(0, health - amount)
	
	health_changed.emit(health, old_value, source)
	_emit_to_event_bus("health_changed", [health, old_value, source])
	
	_check_death_condition()


## Heal the player.
func heal(amount: int, source: String = "healing") -> void:
	if amount <= 0:
		return
	
	var old_value := health
	health = mini(max_health, health + amount)
	
	if health != old_value:
		health_changed.emit(health, old_value, source)
		_emit_to_event_bus("health_changed", [health, old_value, source])


## Modify health directly (for encounter effects, can be positive or negative).
func modify_health(amount: int, source: String = "effect") -> void:
	if amount > 0:
		heal(amount, source)
	elif amount < 0:
		take_damage(-amount, source)


## Gets the current health stage (for display purposes).
func get_health_stage() -> String:
	var percent := float(health) / float(max_health)
	if percent >= 0.8:
		return "healthy"
	elif percent >= 0.5:
		return "wounded"
	elif percent >= 0.25:
		return "injured"
	elif percent > 0:
		return "critical"
	else:
		return "dead"

# =============================================================================
# SURVIVAL DAMAGE
# =============================================================================

func _apply_survival_damage() -> void:
	# Starvation damage
	if hunger == 0:
		take_damage(2, "starvation")
	elif hunger <= 2:
		# Starving: damage once per day (every 6 turns)
		# This is handled separately via day_started if needed
		pass
	
	# Dehydration damage
	if thirst == 0:
		take_damage(3, "dehydration")
	elif thirst <= 2:
		take_damage(1, "dehydration")

# =============================================================================
# WARNINGS
# =============================================================================

func _check_warnings() -> void:
	# Hunger warnings
	if hunger <= hunger_critical_threshold and hunger > 0:
		survival_warning.emit("hunger_critical", hunger)
		_emit_to_event_bus("survival_warning", ["hunger_critical", hunger])
	elif hunger <= hunger_warning_threshold:
		survival_warning.emit("hunger_warning", hunger)
		_emit_to_event_bus("survival_warning", ["hunger_warning", hunger])
	
	# Thirst warnings
	if thirst <= thirst_critical_threshold and thirst > 0:
		survival_warning.emit("thirst_critical", thirst)
		_emit_to_event_bus("survival_warning", ["thirst_critical", thirst])
	elif thirst <= thirst_warning_threshold:
		survival_warning.emit("thirst_warning", thirst)
		_emit_to_event_bus("survival_warning", ["thirst_warning", thirst])
	
	# Health warnings
	if health <= health_critical_threshold and health > 0:
		survival_warning.emit("health_critical", health)
		_emit_to_event_bus("survival_warning", ["health_critical", health])
	elif health <= health_warning_threshold:
		survival_warning.emit("health_warning", health)
		_emit_to_event_bus("survival_warning", ["health_warning", health])

# =============================================================================
# DEATH CHECK
# =============================================================================

func _check_death_condition() -> void:
	if health <= 0:
		var cause := "unknown"
		if thirst == 0:
			cause = "dehydration"
		elif hunger == 0:
			cause = "starvation"
		else:
			cause = "injuries"
		
		player_died.emit(cause)
		_emit_to_event_bus("player_died", [cause])


## Check if player is dead.
func is_dead() -> bool:
	return health <= 0

# =============================================================================
# QUERIES
# =============================================================================

## Check if player can eat (not at max hunger).
func can_eat() -> bool:
	return hunger < max_hunger


## Check if player can drink (not at max thirst).
func can_drink() -> bool:
	return thirst < max_thirst


## Get all survival stats as a dictionary.
func get_stats() -> Dictionary:
	return {
		"hunger": hunger,
		"max_hunger": max_hunger,
		"thirst": thirst,
		"max_thirst": max_thirst,
		"health": health,
		"max_health": max_health,
		"hunger_stage": get_hunger_stage(),
		"thirst_stage": get_thirst_stage(),
		"health_stage": get_health_stage()
	}

# =============================================================================
# SERIALIZATION
# =============================================================================

## Convert survival state to dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"hunger": hunger,
		"thirst": thirst,
		"health": health,
		"turns_since_hunger": turns_since_hunger_decrease,
		"turns_since_thirst": turns_since_thirst_decrease
	}


## Load survival state from dictionary.
func from_dict(data: Dictionary) -> void:
	hunger = data.get("hunger", max_hunger)
	thirst = data.get("thirst", max_thirst)
	health = data.get("health", max_health)
	turns_since_hunger_decrease = data.get("turns_since_hunger", 0)
	turns_since_thirst_decrease = data.get("turns_since_thirst", 0)
	
	_emit_all_stats()
	print("SurvivalManager: Loaded state (H:%d T:%d HP:%d)" % [hunger, thirst, health])

# =============================================================================
# DEBUG
# =============================================================================

## Pause/unpause survival decay.
func set_paused(paused: bool) -> void:
	_paused = paused
	print("SurvivalManager: %s" % ("Paused" if paused else "Resumed"))


## Set all survival values (debug).
func debug_set_values(new_hunger: int, new_thirst: int, new_health: int) -> void:
	var old_hunger := hunger
	var old_thirst := thirst
	var old_health := health
	
	hunger = clampi(new_hunger, 0, max_hunger)
	thirst = clampi(new_thirst, 0, max_thirst)
	health = clampi(new_health, 0, max_health)
	
	hunger_changed.emit(hunger, old_hunger)
	thirst_changed.emit(thirst, old_thirst)
	health_changed.emit(health, old_health, "debug")

# =============================================================================
# UTILITY
# =============================================================================

func _emit_all_stats() -> void:
	hunger_changed.emit(hunger, hunger)
	thirst_changed.emit(thirst, thirst)
	health_changed.emit(health, health, "init")


func _emit_to_event_bus(signal_name: String, args: Array) -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal(signal_name):
		match args.size():
			0: event_bus.emit_signal(signal_name)
			1: event_bus.emit_signal(signal_name, args[0])
			2: event_bus.emit_signal(signal_name, args[0], args[1])
			3: event_bus.emit_signal(signal_name, args[0], args[1], args[2])
