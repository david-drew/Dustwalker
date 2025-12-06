# talent_manager.gd
# Manages talent acquisition, prerequisites, and talent-specific functionality.
# Works with EffectManager for the actual effect application.
#
# ACQUISITION TYPES:
# - starting: Selected at character creation (1 per character)
# - purchased: Bought from trainers with money and time
# - story: Awarded through quest completion
# - supernatural: Gained through supernatural encounters
#
# TALENT LIMITS:
# - 1 starting talent
# - 2-3 purchased talents (trainer dependent)
# - 1-2 story talents (quest dependent)
# - 0-2 supernatural talents (optional, may have drawbacks)
# - Total: 3-6 talents per playthrough

extends Node
class_name TalentManager

# =============================================================================
# CONSTANTS
# =============================================================================

const CONFIG_PATH := "res://data/character/talents_config.json"

## Default costs for purchased talents
const DEFAULT_PURCHASE_COST := 200
const DEFAULT_TRAINING_DAYS := 10

## Talent slot limits
const MAX_STARTING_TALENTS := 1
const MAX_PURCHASED_TALENTS := 3
const MAX_STORY_TALENTS := 2
const MAX_SUPERNATURAL_TALENTS := 2

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a talent is acquired.
signal talent_acquired(talent_id: String, acquisition_type: String)

## Emitted when talent acquisition fails.
signal talent_acquisition_failed(talent_id: String, reason: String, details: Dictionary)

## Emitted when a talent is removed (rare, usually story-driven).
signal talent_removed(talent_id: String, reason: String)

## Emitted when talent slots change.
signal talent_slots_changed(slot_type: String, used: int, max_slots: int)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Custom talent costs and training times (loaded from config)
var talent_costs: Dictionary = {}
var talent_training_days: Dictionary = {}

## Trainer locations and what they can teach
var trainer_data: Dictionary = {}

# =============================================================================
# STATE
# =============================================================================

## Acquired talents by acquisition type
var acquired_talents: Dictionary = {
	"starting": [],
	"purchased": [],
	"story": [],
	"supernatural": []
}

## Talents currently being trained (trainer interaction)
var training_in_progress: Dictionary = {}  # {talent_id: {days_remaining: int, trainer_id: String}}

## Reference to EffectManager
var _effect_manager: EffectManager = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()
	_connect_signals()
	add_to_group("talent_manager")
	print("TalentManager: Initialized")


func _load_config() -> void:
	var config: Dictionary = {}
	
	# Try DataLoader first
	var data_loader = get_node_or_null("/root/DataLoader")
	if data_loader and data_loader.has_method("load_json"):
		config = data_loader.load_json(CONFIG_PATH)
	
	# Fallback to direct loading
	if config.is_empty() and FileAccess.file_exists(CONFIG_PATH):
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			var error := json.parse(file.get_as_text())
			file.close()
			if error == OK:
				config = json.data
	
	if not config.is_empty():
		talent_costs = config.get("costs", {})
		talent_training_days = config.get("training_days", {})
		trainer_data = config.get("trainers", {})
		print("TalentManager: Loaded config")


func _connect_signals() -> void:
	# Connect to TimeManager for training progress
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_signal("day_started"):
		time_manager.day_started.connect(_on_day_started)
	
	# Find EffectManager after a frame
	await get_tree().process_frame
	_effect_manager = get_tree().get_first_node_in_group("effect_manager")

# =============================================================================
# TALENT QUERIES
# =============================================================================

## Get all acquired talents.
func get_all_talents() -> Array[String]:
	var result: Array[String] = []
	for type in acquired_talents:
		for talent_id in acquired_talents[type]:
			result.append(talent_id)
	return result


## Get talents by acquisition type.
func get_talents_by_type(acquisition_type: String) -> Array[String]:
	var result: Array[String] = []
	if acquired_talents.has(acquisition_type):
		for talent_id in acquired_talents[acquisition_type]:
			result.append(talent_id)
	return result


## Check if player has a specific talent.
func has_talent(talent_id: String) -> bool:
	for type in acquired_talents:
		if talent_id in acquired_talents[type]:
			return true
	return false


## Get remaining slots for an acquisition type.
func get_remaining_slots(acquisition_type: String) -> int:
	var max_slots := _get_max_slots(acquisition_type)
	var used:int = acquired_talents.get(acquisition_type, []).size()
	return maxi(0, max_slots - used)


## Get talent count by type.
func get_talent_count(acquisition_type: String) -> int:
	return acquired_talents.get(acquisition_type, []).size()


## Get total talent count.
func get_total_talent_count() -> int:
	var total := 0
	for type in acquired_talents:
		total += acquired_talents[type].size()
	return total


func _get_max_slots(acquisition_type: String) -> int:
	match acquisition_type:
		"starting":
			return MAX_STARTING_TALENTS
		"purchased":
			return MAX_PURCHASED_TALENTS
		"story":
			return MAX_STORY_TALENTS
		"supernatural":
			return MAX_SUPERNATURAL_TALENTS
		_:
			return 0

# =============================================================================
# TALENT INFORMATION
# =============================================================================

## Get detailed info about a talent.
func get_talent_info(talent_id: String) -> Dictionary:
	if not _effect_manager:
		return {}
	
	var definition := _effect_manager.get_effect_definition(talent_id)
	if definition.is_empty():
		return {}
	
	return {
		"id": talent_id,
		"name": definition.get("name", talent_id),
		"description": definition.get("description", ""),
		"category": definition.get("category", ""),
		"acquisition": definition.get("acquisition", "purchased"),
		"prerequisites": definition.get("prerequisites", {}),
		"modifiers": definition.get("modifiers", []),
		"triggers": definition.get("triggers", []),
		"visuals": definition.get("visuals", {}),
		"cost": get_talent_cost(talent_id),
		"training_days": get_talent_training_days(talent_id),
		"owned": has_talent(talent_id)
	}


## Get all available talents for selection/purchase.
func get_available_talents(acquisition_type: String = "") -> Array[Dictionary]:
	if not _effect_manager:
		return []
	
	var all_talents := _effect_manager.get_all_talents()
	var result: Array[Dictionary] = []
	
	for talent in all_talents:
		# Filter by acquisition type if specified
		if not acquisition_type.is_empty():
			if talent.get("acquisition", "") != acquisition_type:
				continue
		
		# Skip already owned
		if has_talent(talent["id"]):
			continue
		
		# Add acquisition info
		var info := get_talent_info(talent["id"])
		var can_acquire := can_acquire_talent(talent["id"])
		info["can_acquire"] = can_acquire["can_acquire"]
		info["acquire_reason"] = can_acquire.get("reason", "")
		info["missing_stats"] = can_acquire.get("missing_stats", [])
		info["missing_skills"] = can_acquire.get("missing_skills", [])
		
		result.append(info)
	
	return result


## Get starting talents for character creation.
func get_starting_talent_options() -> Array[Dictionary]:
	return get_available_talents("starting")


## Get talents a specific trainer can teach.
func get_trainer_talents(trainer_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	if not trainer_data.has(trainer_id):
		return result
	
	var trainer := trainer_data[trainer_id] as Dictionary
	var teaches: Array = trainer.get("teaches", [])
	
	for talent_id in teaches:
		var info := get_talent_info(talent_id)
		if not info.is_empty() and not has_talent(talent_id):
			var can_acquire := can_acquire_talent(talent_id)
			info["can_acquire"] = can_acquire["can_acquire"]
			info["acquire_reason"] = can_acquire.get("reason", "")
			result.append(info)
	
	return result

# =============================================================================
# TALENT COSTS
# =============================================================================

## Get the cost to purchase a talent.
func get_talent_cost(talent_id: String) -> int:
	return talent_costs.get(talent_id, DEFAULT_PURCHASE_COST)


## Get the training time for a talent.
func get_talent_training_days(talent_id: String) -> int:
	return talent_training_days.get(talent_id, DEFAULT_TRAINING_DAYS)

# =============================================================================
# TALENT ACQUISITION
# =============================================================================

## Check if a talent can be acquired.
func can_acquire_talent(talent_id: String) -> Dictionary:
	if not _effect_manager:
		return {"can_acquire": false, "reason": "no_effect_manager"}
	
	# Check if already owned
	if has_talent(talent_id):
		return {"can_acquire": false, "reason": "already_owned"}
	
	# Get talent definition
	var definition := _effect_manager.get_effect_definition(talent_id)
	if definition.is_empty():
		return {"can_acquire": false, "reason": "unknown_talent"}
	
	# Check slot availability
	var acquisition_type: String = definition.get("acquisition", "purchased")
	if get_remaining_slots(acquisition_type) <= 0:
		return {"can_acquire": false, "reason": "no_slots", "slot_type": acquisition_type}
	
	# Check prerequisites via EffectManager
	return _effect_manager.can_acquire_talent("player", talent_id)


## Acquire a starting talent (character creation).
func acquire_starting_talent(talent_id: String) -> bool:
	var can_acquire := can_acquire_talent(talent_id)
	
	if not can_acquire["can_acquire"]:
		talent_acquisition_failed.emit(talent_id, can_acquire.get("reason", "unknown"), can_acquire)
		return false
	
	# Verify it's a starting talent
	var definition := _effect_manager.get_effect_definition(talent_id)
	if definition.get("acquisition", "") != "starting":
		talent_acquisition_failed.emit(talent_id, "not_starting_talent", {})
		return false
	
	return _acquire_talent_internal(talent_id, "starting")


## Purchase a talent from a trainer.
## Returns true if purchase started (may require training time).
func purchase_talent(talent_id: String, trainer_id: String = "", instant: bool = false) -> Dictionary:
	var can_acquire := can_acquire_talent(talent_id)
	
	if not can_acquire["can_acquire"]:
		talent_acquisition_failed.emit(talent_id, can_acquire.get("reason", "unknown"), can_acquire)
		return {"success": false, "reason": can_acquire.get("reason", "unknown")}
	
	# Verify it's a purchasable talent
	var definition := _effect_manager.get_effect_definition(talent_id)
	var acquisition_type: String = definition.get("acquisition", "purchased")
	if acquisition_type != "purchased":
		talent_acquisition_failed.emit(talent_id, "not_purchasable", {})
		return {"success": false, "reason": "not_purchasable"}
	
	# Check if trainer can teach this talent
	if not trainer_id.is_empty() and trainer_data.has(trainer_id):
		var trainer := trainer_data[trainer_id] as Dictionary
		var teaches: Array = trainer.get("teaches", [])
		if talent_id not in teaches:
			talent_acquisition_failed.emit(talent_id, "trainer_cannot_teach", {"trainer_id": trainer_id})
			return {"success": false, "reason": "trainer_cannot_teach"}
	
	var cost := get_talent_cost(talent_id)
	var training_days := get_talent_training_days(talent_id)
	
	# Check if player can afford
	var inventory_manager = get_tree().get_first_node_in_group("inventory_manager")
	if inventory_manager and inventory_manager.has_method("get_money"):
		var money: int = inventory_manager.get_money()
		if money < cost:
			talent_acquisition_failed.emit(talent_id, "insufficient_funds", {"cost": cost, "have": money})
			return {"success": false, "reason": "insufficient_funds", "cost": cost, "have": money}
		
		# Deduct cost
		if inventory_manager.has_method("spend_money"):
			inventory_manager.spend_money(cost)
	
	# Instant acquisition (for testing or special cases)
	if instant or training_days <= 0:
		_acquire_talent_internal(talent_id, "purchased")
		return {"success": true, "instant": true}
	
	# Start training
	training_in_progress[talent_id] = {
		"days_remaining": training_days,
		"trainer_id": trainer_id,
		"started_day": _get_current_day()
	}
	
	print("TalentManager: Started training '%s', %d days remaining" % [talent_id, training_days])
	
	return {
		"success": true,
		"training": true,
		"days_remaining": training_days,
		"cost": cost
	}


## Award a story talent (from quest completion).
func award_story_talent(talent_id: String, source: String = "quest") -> bool:
	var can_acquire := can_acquire_talent(talent_id)
	
	if not can_acquire["can_acquire"]:
		# Story talents might bypass some prerequisites
		if can_acquire.get("reason") == "prerequisites_not_met":
			# Allow anyway for story purposes, but log it
			print("TalentManager: Awarding story talent '%s' despite unmet prerequisites" % talent_id)
		elif can_acquire.get("reason") != "prerequisites_not_met":
			talent_acquisition_failed.emit(talent_id, can_acquire.get("reason", "unknown"), can_acquire)
			return false
	
	return _acquire_talent_internal(talent_id, "story", source)


## Grant a supernatural talent (from supernatural encounter).
func grant_supernatural_talent(talent_id: String, source: String = "supernatural") -> bool:
	var can_acquire := can_acquire_talent(talent_id)
	
	if not can_acquire["can_acquire"]:
		talent_acquisition_failed.emit(talent_id, can_acquire.get("reason", "unknown"), can_acquire)
		return false
	
	# Verify it's a supernatural talent
	var definition := _effect_manager.get_effect_definition(talent_id)
	if definition.get("acquisition", "") != "supernatural":
		talent_acquisition_failed.emit(talent_id, "not_supernatural_talent", {})
		return false
	
	return _acquire_talent_internal(talent_id, "supernatural", source)


func _acquire_talent_internal(talent_id: String, acquisition_type: String, source: String = "") -> bool:
	if not _effect_manager:
		return false
	
	# Apply the effect
	var effect_source := source if not source.is_empty() else acquisition_type
	if not _effect_manager.apply_effect("player", talent_id, effect_source):
		talent_acquisition_failed.emit(talent_id, "effect_application_failed", {})
		return false
	
	# Track acquisition
	if not acquired_talents.has(acquisition_type):
		acquired_talents[acquisition_type] = []
	acquired_talents[acquisition_type].append(talent_id)
	
	# Remove from training if it was there
	if training_in_progress.has(talent_id):
		training_in_progress.erase(talent_id)
	
	talent_acquired.emit(talent_id, acquisition_type)
	_emit_to_event_bus("player_talent_acquired", [talent_id, acquisition_type])
	
	var used:int = acquired_talents[acquisition_type].size()
	var max_slots := _get_max_slots(acquisition_type)
	talent_slots_changed.emit(acquisition_type, used, max_slots)
	
	print("TalentManager: Acquired '%s' (%s)" % [talent_id, acquisition_type])
	return true

# =============================================================================
# TALENT REMOVAL (RARE)
# =============================================================================

## Remove a talent (usually story-driven, like losing supernatural powers).
func remove_talent(talent_id: String, reason: String = "removed") -> bool:
	if not has_talent(talent_id):
		return false
	
	if not _effect_manager:
		return false
	
	# Remove the effect
	_effect_manager.remove_effect("player", talent_id)
	
	# Remove from tracking
	for type in acquired_talents:
		var index:int = acquired_talents[type].find(talent_id)
		if index >= 0:
			acquired_talents[type].remove_at(index)
			
			talent_removed.emit(talent_id, reason)
			_emit_to_event_bus("player_talent_removed", [talent_id, reason])
			
			var used:int = acquired_talents[type].size()
			var max_slots := _get_max_slots(type)
			talent_slots_changed.emit(type, used, max_slots)
			
			print("TalentManager: Removed '%s' (%s)" % [talent_id, reason])
			return true
	
	return false

# =============================================================================
# TRAINING PROGRESS
# =============================================================================

func _on_day_started(day: int) -> void:
	_process_training()


func _process_training() -> void:
	var completed: Array[String] = []
	
	for talent_id in training_in_progress:
		var training: Dictionary = training_in_progress[talent_id]
		training["days_remaining"] -= 1
		
		if training["days_remaining"] <= 0:
			completed.append(talent_id)
		else:
			print("TalentManager: Training '%s', %d days remaining" % [talent_id, training["days_remaining"]])
	
	for talent_id in completed:
		_acquire_talent_internal(talent_id, "purchased", training_in_progress[talent_id].get("trainer_id", ""))


## Get current training status.
func get_training_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for talent_id in training_in_progress:
		var training: Dictionary = training_in_progress[talent_id]
		var info := get_talent_info(talent_id)
		
		result.append({
			"talent_id": talent_id,
			"name": info.get("name", talent_id),
			"days_remaining": training.get("days_remaining", 0),
			"trainer_id": training.get("trainer_id", ""),
			"started_day": training.get("started_day", 0)
		})
	
	return result


## Check if currently training.
func is_training() -> bool:
	return not training_in_progress.is_empty()


## Cancel training (lose money, no refund).
func cancel_training(talent_id: String) -> bool:
	if not training_in_progress.has(talent_id):
		return false
	
	training_in_progress.erase(talent_id)
	print("TalentManager: Cancelled training for '%s'" % talent_id)
	return true


func _get_current_day() -> int:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("get_current_day"):
		return time_manager.get_current_day()
	return 0

# =============================================================================
# TALENT ACTIVATION (FOR ACTIVE TALENTS)
# =============================================================================

## Activate a talent's special ability (for talents with limited uses).
func activate_talent(talent_id: String, context: Dictionary = {}) -> Dictionary:
	if not has_talent(talent_id):
		return {"success": false, "reason": "not_owned"}
	
	if not _effect_manager:
		return {"success": false, "reason": "no_effect_manager"}
	
	# Process the activation trigger
	_effect_manager.process_trigger("player", "activate", {"talent_id": talent_id, "context": context})
	
	return {"success": true, "talent_id": talent_id}

# =============================================================================
# SERIALIZATION
# =============================================================================

## Convert to dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"acquired_talents": acquired_talents.duplicate(true),
		"training_in_progress": training_in_progress.duplicate(true)
	}


## Load from dictionary.
func from_dict(data: Dictionary) -> void:
	if data.has("acquired_talents"):
		acquired_talents = data["acquired_talents"].duplicate(true)
		
		# Re-apply effects for all acquired talents
		if _effect_manager:
			for type in acquired_talents:
				for talent_id in acquired_talents[type]:
					_effect_manager.apply_effect("player", talent_id, type)
	
	if data.has("training_in_progress"):
		training_in_progress = data["training_in_progress"].duplicate(true)
	
	print("TalentManager: Loaded from save data")

# =============================================================================
# DEBUG
# =============================================================================

## Print all talents.
func debug_print_talents() -> void:
	print("=== Acquired Talents ===")
	for type in acquired_talents:
		var count:int = acquired_talents[type].size()
		var max_slots := _get_max_slots(type)
		print("--- %s (%d/%d) ---" % [type.capitalize(), count, max_slots])
		
		for talent_id in acquired_talents[type]:
			var info := get_talent_info(talent_id)
			print("  %s: %s" % [info.get("name", talent_id), info.get("description", "")])
	
	if not training_in_progress.is_empty():
		print("--- Training In Progress ---")
		for talent_id in training_in_progress:
			var training: Dictionary = training_in_progress[talent_id]
			print("  %s: %d days remaining" % [talent_id, training.get("days_remaining", 0)])


## Grant a talent instantly (debug).
func debug_grant_talent(talent_id: String) -> void:
	var definition := _effect_manager.get_effect_definition(talent_id)
	var acquisition_type: String = definition.get("acquisition", "purchased")
	_acquire_talent_internal(talent_id, acquisition_type, "debug")


## List available talents (debug).
func debug_list_available() -> void:
	print("=== Available Talents ===")
	var available := get_available_talents()
	for talent in available:
		var status := "✓" if talent["can_acquire"] else "✗ (%s)" % talent["acquire_reason"]
		print("  [%s] %s - %s %s" % [
			talent["acquisition"],
			talent["name"],
			talent["description"].substr(0, 40) + "...",
			status
		])

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
