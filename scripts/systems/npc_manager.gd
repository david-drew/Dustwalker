# npc_manager.gd
# Manages persistent NPCs: loading definitions, tracking state, availability,
# and location-based NPC queries.
#
# NPCs are data-driven entities bound to location types. When the player
# enters a location, NPCs are sampled from matching types using weighted
# random selection.

extends Node
class_name NPCManager

# =============================================================================
# SIGNALS
# =============================================================================

signal npcs_loaded(count: int)
signal location_npcs_ready(location_id: String, npcs: Array)
signal npc_availability_changed(npc_id: String, available: bool)

# =============================================================================
# CONSTANTS
# =============================================================================

const NPC_FILES: Array[String] = [
	"res://data/npcs/npc_traders.json",
	"res://data/npcs/npc_general.json"
]

## Default NPC count targets per location type
const LOCATION_NPC_COUNTS: Dictionary = {
	"town": {"min": 6, "max": 10},
	"fort": {"min": 4, "max": 7},
	"trading_post": {"min": 4, "max": 7},
	"roadhouse": {"min": 4, "max": 6},
	"mission": {"min": 3, "max": 6},
	"caravan_camp": {"min": 3, "max": 6},
	"cave": {"min": 0, "max": 2}
}

# =============================================================================
# STATE
# =============================================================================

## All NPC definitions keyed by npc_id
var _npc_definitions: Dictionary = {}

## NPC persistent state keyed by npc_id
var _npc_states: Dictionary = {}

## Current location the player is in (or empty if not in a location)
var _current_location_id: String = ""
var _current_location_type: String = ""

## NPCs assigned to the current location (sampled on entry)
var _current_location_npcs: Array[String] = []

## Random number generator for weighted sampling
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("npc_manager")
	_rng.randomize()
	_load_all_npc_definitions()
	_connect_signals()
	print("NPCManager: Ready with %d NPC definitions" % _npc_definitions.size())


func _load_all_npc_definitions() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if not loader:
		push_warning("NPCManager: DataLoader not found")
		return

	for file_path in NPC_FILES:
		var data: Dictionary = loader.load_json(file_path)
		if data.has("npcs"):
			for npc_id in data["npcs"]:
				_npc_definitions[npc_id] = data["npcs"][npc_id]
				_npc_definitions[npc_id]["_id"] = npc_id
				# Initialize state if not exists
				if not _npc_states.has(npc_id):
					_npc_states[npc_id] = _create_default_state()

	npcs_loaded.emit(_npc_definitions.size())


func _create_default_state() -> Dictionary:
	return {
		"disposition": 50,
		"last_interaction_day": -1,
		"dialogue_state": {},
		"custom_flags": {}
	}


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("player_moved_to_hex"):
			event_bus.player_moved_to_hex.connect(_on_player_moved_to_hex)

# =============================================================================
# LOCATION ENTRY DETECTION
# =============================================================================

func _on_player_moved_to_hex(hex_coords: Vector2i) -> void:
	var hex_grid = get_tree().get_first_node_in_group("hex_grid")
	if not hex_grid:
		return

	var cell = hex_grid.get_cell(hex_coords)
	if not cell:
		return

	# Check if this hex has a location
	if cell.location and cell.location is Dictionary and not cell.location.is_empty():
		var location_data: Dictionary = cell.location
		var location_type: String = location_data.get("type", "")
		var location_name: String = location_data.get("name", "Unknown")
		var location_id: String = location_data.get("id", location_name.to_lower().replace(" ", "_"))

		# Only trigger if entering a new location
		if _current_location_id != location_id:
			_enter_location(location_id, location_type, location_data)
	else:
		# Left a location
		if not _current_location_id.is_empty():
			_exit_location()


func _enter_location(location_id: String, location_type: String, location_data: Dictionary) -> void:
	_current_location_id = location_id
	_current_location_type = location_type

	# Sample NPCs for this location
	_current_location_npcs = _sample_npcs_for_location(location_type)

	print("NPCManager: Entered %s (%s) with %d NPCs" % [
		location_id, location_type, _current_location_npcs.size()
	])

	# Emit signals
	location_npcs_ready.emit(location_id, get_npcs_at_current_location())
	_emit_to_event_bus("location_entered", [location_data])


func _exit_location() -> void:
	var old_location := _current_location_id
	_current_location_id = ""
	_current_location_type = ""
	_current_location_npcs.clear()

	print("NPCManager: Exited %s" % old_location)
	_emit_to_event_bus("location_exited", [old_location])

# =============================================================================
# NPC SAMPLING
# =============================================================================

## Sample NPCs for a location type using weighted random selection.
func _sample_npcs_for_location(location_type: String) -> Array[String]:
	var matching_npcs: Array[Dictionary] = []

	# Find all NPCs that can appear at this location type
	for npc_id in _npc_definitions:
		var npc: Dictionary = _npc_definitions[npc_id]
		var npc_location: String = npc.get("location_id", "")
		if npc_location == location_type:
			var weight: float = 1.0
			var placement: Dictionary = npc.get("placement", {})
			if placement.has("weight"):
				weight = placement["weight"]
			matching_npcs.append({"id": npc_id, "weight": weight})

	if matching_npcs.is_empty():
		return []

	# Determine target count
	var counts: Dictionary = LOCATION_NPC_COUNTS.get(location_type, {"min": 2, "max": 4})
	var target_count: int = _rng.randi_range(counts["min"], counts["max"])
	target_count = mini(target_count, matching_npcs.size())

	# Weighted random sampling without replacement
	var result: Array[String] = []
	var pool := matching_npcs.duplicate()

	for i in range(target_count):
		if pool.is_empty():
			break

		# Calculate total weight
		var total_weight: float = 0.0
		for entry in pool:
			total_weight += entry["weight"]

		# Pick random value
		var pick: float = _rng.randf() * total_weight
		var cumulative: float = 0.0
		var selected_index: int = 0

		for j in range(pool.size()):
			cumulative += pool[j]["weight"]
			if pick <= cumulative:
				selected_index = j
				break

		# Add selected NPC and remove from pool
		result.append(pool[selected_index]["id"])
		pool.remove_at(selected_index)

	return result

# =============================================================================
# NPC QUERIES
# =============================================================================

## Get all NPCs at the current location with full UI-ready data.
func get_npcs_at_current_location() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for npc_id in _current_location_npcs:
		var npc_data := get_npc_for_ui(npc_id)
		if not npc_data.is_empty():
			result.append(npc_data)

	return result


## Get NPC definition by ID.
func get_npc(npc_id: String) -> Dictionary:
	return _npc_definitions.get(npc_id, {})


## Get NPC state by ID.
func get_npc_state(npc_id: String) -> Dictionary:
	return _npc_states.get(npc_id, {})


## Get UI-ready NPC data including availability.
func get_npc_for_ui(npc_id: String) -> Dictionary:
	if not _npc_definitions.has(npc_id):
		return {}

	var definition: Dictionary = _npc_definitions[npc_id]
	var state: Dictionary = _npc_states.get(npc_id, _create_default_state())
	var available := is_npc_available(npc_id)
	var unavailable_reason := ""

	if not available:
		var schedule: Dictionary = definition.get("schedule", {})
		unavailable_reason = schedule.get("unavailable_reason", "Not available right now.")

	# Build services list with enabled state
	var services_raw: Array = definition.get("services", [])
	var services: Array[Dictionary] = []
	for service in services_raw:
		services.append({
			"id": service,
			"enabled": available
		})

	return {
		"npc_id": npc_id,
		"display_name": definition.get("display_name", "Unknown"),
		"title": definition.get("title", ""),
		"description": definition.get("description", ""),
		"portrait_id": definition.get("portrait_id", ""),
		"available": available,
		"unavailable_reason": unavailable_reason,
		"services": services,
		"disposition": state.get("disposition", 50),
		# Service-specific IDs
		"shop_id": definition.get("shop_id", ""),
		"trainer_id": definition.get("trainer_id", ""),
		"dialogue_id": definition.get("dialogue_id", ""),
		"rumor_dialogue_id": definition.get("rumor_dialogue_id", ""),
		"quest_tags": definition.get("quest_tags", []),
		"rumor_topics": definition.get("rumor_topics", [])
	}


## Check if NPC is currently available based on schedule.
func is_npc_available(npc_id: String) -> bool:
	if not _npc_definitions.has(npc_id):
		return false

	var definition: Dictionary = _npc_definitions[npc_id]
	var schedule: Dictionary = definition.get("schedule", {})
	var available_times: Array = schedule.get("available_times", [])

	# No schedule = always available
	if available_times.is_empty():
		return true

	# Get current time from TimeManager
	var time_manager = get_node_or_null("/root/TimeManager")
	if not time_manager:
		return true

	var current_time: String = time_manager.get_time_of_day().to_lower()

	# Check if current time is in available times (normalize to lowercase)
	for available_time in available_times:
		if available_time.to_lower() == current_time:
			return true

	return false


## Get all NPCs that provide a specific service at current location.
func get_npcs_with_service(service: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for npc_id in _current_location_npcs:
		var definition: Dictionary = _npc_definitions.get(npc_id, {})
		var services: Array = definition.get("services", [])
		if service in services:
			result.append(get_npc_for_ui(npc_id))

	return result

# =============================================================================
# NPC STATE MANAGEMENT
# =============================================================================

## Update NPC disposition.
func modify_disposition(npc_id: String, delta: int) -> int:
	if not _npc_states.has(npc_id):
		_npc_states[npc_id] = _create_default_state()

	var state: Dictionary = _npc_states[npc_id]
	state["disposition"] = clampi(state["disposition"] + delta, 0, 100)
	return state["disposition"]


## Record an interaction with an NPC.
func record_interaction(npc_id: String) -> void:
	if not _npc_states.has(npc_id):
		_npc_states[npc_id] = _create_default_state()

	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		_npc_states[npc_id]["last_interaction_day"] = time_manager.get_current_day()


## Set a dialogue state flag for an NPC.
func set_dialogue_flag(npc_id: String, flag: String, value: Variant) -> void:
	if not _npc_states.has(npc_id):
		_npc_states[npc_id] = _create_default_state()

	_npc_states[npc_id]["dialogue_state"][flag] = value


## Get a dialogue state flag for an NPC.
func get_dialogue_flag(npc_id: String, flag: String, default: Variant = null) -> Variant:
	if not _npc_states.has(npc_id):
		return default

	return _npc_states[npc_id]["dialogue_state"].get(flag, default)


## Set a custom flag for an NPC.
func set_custom_flag(npc_id: String, flag: String, value: Variant) -> void:
	if not _npc_states.has(npc_id):
		_npc_states[npc_id] = _create_default_state()

	_npc_states[npc_id]["custom_flags"][flag] = value


## Get a custom flag for an NPC.
func get_custom_flag(npc_id: String, flag: String, default: Variant = null) -> Variant:
	if not _npc_states.has(npc_id):
		return default

	return _npc_states[npc_id]["custom_flags"].get(flag, default)

# =============================================================================
# NPC INTERACTION
# =============================================================================

## Start interaction with an NPC (emits signal for UI).
func start_interaction(npc_id: String) -> void:
	if not _npc_definitions.has(npc_id):
		push_warning("NPCManager: Cannot start interaction - unknown NPC: %s" % npc_id)
		return

	var npc_data := get_npc_for_ui(npc_id)
	record_interaction(npc_id)

	_emit_to_event_bus("npc_interaction_started", [npc_id, npc_data])
	print("NPCManager: Started interaction with %s" % npc_data.get("display_name", npc_id))


## End interaction with an NPC.
func end_interaction(npc_id: String) -> void:
	_emit_to_event_bus("npc_interaction_ended", [npc_id])
	print("NPCManager: Ended interaction with %s" % npc_id)

# =============================================================================
# TRAINER INTEGRATION
# =============================================================================

## Get trainer ID for an NPC (if they have trainer service).
func get_trainer_id(npc_id: String) -> String:
	if not _npc_definitions.has(npc_id):
		return ""

	var definition: Dictionary = _npc_definitions[npc_id]
	var services: Array = definition.get("services", [])

	if "trainer" in services:
		return definition.get("trainer_id", "")

	return ""


## Check if NPC is a trainer.
func is_trainer(npc_id: String) -> bool:
	return not get_trainer_id(npc_id).is_empty()

# =============================================================================
# PERSISTENCE (SaveManager Provider Pattern)
# =============================================================================

## Convert NPC state to dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"npc_states": _npc_states.duplicate(true),
		"current_location_id": _current_location_id,
		"current_location_type": _current_location_type,
		"current_location_npcs": _current_location_npcs.duplicate()
	}


## Load NPC state from dictionary.
func from_dict(data: Dictionary) -> void:
	if data.has("npc_states"):
		_npc_states = data["npc_states"].duplicate(true)

	_current_location_id = data.get("current_location_id", "")
	_current_location_type = data.get("current_location_type", "")

	if data.has("current_location_npcs"):
		_current_location_npcs.clear()
		for npc_id in data["current_location_npcs"]:
			_current_location_npcs.append(npc_id)

	print("NPCManager: Loaded state for %d NPCs" % _npc_states.size())

# =============================================================================
# DEBUG
# =============================================================================

## Get all NPC IDs.
func get_all_npc_ids() -> Array[String]:
	var result: Array[String] = []
	for npc_id in _npc_definitions:
		result.append(npc_id)
	return result


## Get NPCs by location type (for debugging/testing).
func get_npcs_by_location_type(location_type: String) -> Array[String]:
	var result: Array[String] = []
	for npc_id in _npc_definitions:
		var npc: Dictionary = _npc_definitions[npc_id]
		if npc.get("location_id", "") == location_type:
			result.append(npc_id)
	return result

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
