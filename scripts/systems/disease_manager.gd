# disease_manager.gd
# Manages disease contraction, progression, treatment, and recovery.
# Separate from SurvivalManager for modularity.
#
# FEATURES:
# - Data-driven diseases from diseases.json
# - Stage-based progression (mild → moderate → severe)
# - Immunity system affected by survival status
# - Multiple treatment options with varying effectiveness
# - Temporary immunity after recovery
#
# DEPENDENCIES:
# - EventBus (autoload): For emitting disease events
# - DataLoader (autoload): For loading diseases.json
# - SurvivalManager: For immunity checks and stat modifiers
# - TimeManager (autoload): For turn-based progression

extends Node
class_name DiseaseManager

# =============================================================================
# SIGNALS
# =============================================================================

signal disease_contracted(disease_id: String, source: String)
signal disease_stage_changed(disease_id: String, old_stage: String, new_stage: String)
signal disease_symptom(disease_id: String, symptom: String)
signal disease_cured(disease_id: String, method: String)
signal disease_progressed(disease_id: String, stage: String)
signal treatment_applied(disease_id: String, treatment: String, success: bool)
signal immunity_gained(disease_id: String, duration_days: int)
signal immunity_expired(disease_id: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const CONFIG_PATH := "res://data/survival/diseases.json"
const MODIFIER_PREFIX := "disease_"

# =============================================================================
# CONFIGURATION
# =============================================================================

var config: Dictionary = {}
var disease_definitions: Dictionary = {}
var immunity_modifiers: Dictionary = {}
var treatment_items: Dictionary = {}

# =============================================================================
# STATE
# =============================================================================

## Active diseases: disease_id -> {stage_index, turns_in_stage, incubating, incubation_turns}
var active_diseases: Dictionary = {}

## Immunities: disease_id -> days_remaining
var immunities: Dictionary = {}

## Reference to survival manager
var _survival_manager: SurvivalManager = null

## Reference to player stats (for applying modifiers)
var _player_stats: Node = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("disease_manager")
	_load_config()
	_connect_signals()
	print("DiseaseManager: Initialized with %d disease definitions" % disease_definitions.size())


func _load_config() -> void:
	var data_loader = get_node_or_null("/root/DataLoader")
	if data_loader and data_loader.has_method("load_json"):
		config = data_loader.load_json(CONFIG_PATH)
	else:
		if FileAccess.file_exists(CONFIG_PATH):
			var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
			if file:
				var json := JSON.new()
				var error := json.parse(file.get_as_text())
				file.close()
				if error == OK:
					config = json.data
				else:
					push_error("DiseaseManager: Failed to parse config JSON")
					config = {}
		else:
			push_warning("DiseaseManager: Config file not found at %s" % CONFIG_PATH)
			config = {}
	
	disease_definitions = config.get("diseases", {})
	immunity_modifiers = config.get("immunity_modifiers", {})
	treatment_items = config.get("treatment_items", {})


func _connect_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if time_manager.has_signal("turn_started"):
			time_manager.turn_started.connect(_on_turn_started)
		if time_manager.has_signal("day_started"):
			time_manager.day_started.connect(_on_day_started)
	
	# Wait a frame to find other managers
	await get_tree().process_frame
	_find_references()


func _find_references() -> void:
	_survival_manager = get_tree().get_first_node_in_group("survival_manager")
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_stats"):
		_player_stats = player.get_stats()
	else:
		_player_stats = get_tree().get_first_node_in_group("player_stats")


# =============================================================================
# TIME CALLBACKS
# =============================================================================

func _on_turn_started(_turn: int, _day: int, _time_name: String) -> void:
	_process_diseases()


func _on_day_started(_day: int) -> void:
	_process_immunities()

# =============================================================================
# DISEASE CONTRACTION
# =============================================================================

## Attempt to contract a disease with chance modified by immunity.
## @param disease_id: The disease to potentially contract.
## @param chance: Base chance (0.0 - 1.0), or -1 to use disease default.
## @param source: What caused the exposure (for logging/events).
## @return bool: True if disease was contracted.
func try_contract_disease(disease_id: String, chance: float = -1.0, source: String = "unknown") -> bool:
	var disease_def := _get_disease_definition(disease_id)
	if disease_def.is_empty():
		push_warning("DiseaseManager: Unknown disease '%s'" % disease_id)
		return false
	
	# Already have this disease
	if has_disease(disease_id):
		return false
	
	# Check immunity
	if is_immune(disease_id):
		print("DiseaseManager: Immune to %s" % disease_id)
		return false
	
	# Calculate effective chance
	var base_chance: float = chance if chance >= 0 else disease_def.get("base_contraction_chance", 0.15)
	var immunity_mod := get_immunity_modifier()
	var effective_chance := base_chance * (1.0 - immunity_mod)
	effective_chance = clampf(effective_chance, 0.01, 0.95)
	
	# Roll
	var roll := randf()
	if roll >= effective_chance:
		print("DiseaseManager: Resisted %s (rolled %.2f vs %.2f)" % [disease_id, roll, effective_chance])
		return false
	
	# Contract the disease
	return contract_disease(disease_id, source)


## Directly contract a disease (bypasses chance roll).
## @param disease_id: The disease to contract.
## @param source: What caused the contraction.
## @return bool: True if disease was contracted.
func contract_disease(disease_id: String, source: String = "unknown") -> bool:
	var disease_def := _get_disease_definition(disease_id)
	if disease_def.is_empty():
		push_warning("DiseaseManager: Unknown disease '%s'" % disease_id)
		return false
	
	if has_disease(disease_id):
		return false
	
	if is_immune(disease_id):
		return false
	
	var incubation: int = disease_def.get("incubation_turns", 0)
	
	active_diseases[disease_id] = {
		"stage_index": 0,
		"turns_in_stage": 0,
		"incubating": incubation > 0,
		"incubation_turns_remaining": incubation,
		"source": source
	}
	
	print("DiseaseManager: Contracted %s from %s (incubation: %d turns)" % [disease_id, source, incubation])
	
	disease_contracted.emit(disease_id, source)
	_emit_to_event_bus("disease_contracted", [disease_id, source])
	
	# Apply modifiers immediately if no incubation
	if incubation <= 0:
		_apply_disease_modifiers(disease_id)
	
	return true

# =============================================================================
# DISEASE PROGRESSION
# =============================================================================

func _process_diseases() -> void:
	var diseases_to_remove: Array[String] = []
	
	for disease_id in active_diseases.keys():
		var disease_state: Dictionary = active_diseases[disease_id]
		var disease_def := _get_disease_definition(disease_id)
		
		if disease_def.is_empty():
			diseases_to_remove.append(disease_id)
			continue
		
		# Handle incubation
		if disease_state["incubating"]:
			disease_state["incubation_turns_remaining"] -= 1
			if disease_state["incubation_turns_remaining"] <= 0:
				disease_state["incubating"] = false
				_apply_disease_modifiers(disease_id)
				_emit_symptoms(disease_id)
				print("DiseaseManager: %s incubation complete, symptoms begin" % disease_id)
			continue
		
		# Progress turn counter
		disease_state["turns_in_stage"] += 1
		
		# Apply per-turn effects
		_apply_turn_effects(disease_id, disease_def, disease_state)
		
		# Check for natural recovery
		if _check_natural_recovery(disease_id, disease_def):
			diseases_to_remove.append(disease_id)
			continue
		
		# Check for stage progression
		var stages: Array = disease_def.get("stages", [])
		if disease_state["stage_index"] < stages.size():
			var current_stage: Dictionary = stages[disease_state["stage_index"]]
			var stage_duration: int = current_stage.get("duration_turns", 10)
			
			if disease_state["turns_in_stage"] >= stage_duration:
				_progress_disease_stage(disease_id, disease_def, disease_state)
	
	# Remove cured diseases
	for disease_id in diseases_to_remove:
		_cure_disease(disease_id, "natural_recovery")


func _apply_turn_effects(disease_id: String, disease_def: Dictionary, disease_state: Dictionary) -> void:
	var stages: Array = disease_def.get("stages", [])
	if disease_state["stage_index"] >= stages.size():
		return
	
	var current_stage: Dictionary = stages[disease_state["stage_index"]]
	
	# HP loss
	var hp_loss: int = current_stage.get("hp_loss_per_turn", 0)
	if hp_loss > 0 and _survival_manager:
		_survival_manager.modify_health(-hp_loss, "disease_%s" % disease_id)
	
	# Thirst multiplier is handled by SurvivalManager querying us
	# Fatigue multiplier is handled by SurvivalManager querying us


func _progress_disease_stage(disease_id: String, disease_def: Dictionary, disease_state: Dictionary) -> void:
	var stages: Array = disease_def.get("stages", [])
	var old_stage_index: int = disease_state["stage_index"]
	var new_stage_index: int = old_stage_index + 1
	
	if new_stage_index >= stages.size():
		# Already at max stage, stay there
		return
	
	var old_stage_name: String = stages[old_stage_index].get("name", "unknown")
	var new_stage_name: String = stages[new_stage_index].get("name", "unknown")
	
	# Remove old modifiers
	_remove_disease_modifiers(disease_id)
	
	# Update state
	disease_state["stage_index"] = new_stage_index
	disease_state["turns_in_stage"] = 0
	
	# Apply new modifiers
	_apply_disease_modifiers(disease_id)
	
	print("DiseaseManager: %s progressed from %s to %s" % [disease_id, old_stage_name, new_stage_name])
	
	disease_stage_changed.emit(disease_id, old_stage_name, new_stage_name)
	disease_progressed.emit(disease_id, new_stage_name)
	_emit_to_event_bus("disease_stage_changed", [disease_id, old_stage_name, new_stage_name])
	
	_emit_symptoms(disease_id)


func _check_natural_recovery(disease_id: String, disease_def: Dictionary) -> bool:
	var base_chance: float = disease_def.get("natural_recovery_chance", 0.05)
	var rest_bonus: float = disease_def.get("rest_recovery_bonus", 0.10)
	
	var effective_chance := base_chance
	
	# Bonus if resting/sleeping
	if _survival_manager and _survival_manager.is_sleeping:
		effective_chance += rest_bonus
	
	# Bonus from good health
	var immunity_mod := get_immunity_modifier()
	if immunity_mod > 0:
		effective_chance += immunity_mod * 0.1
	
	return randf() < effective_chance

# =============================================================================
# TREATMENT
# =============================================================================

## Apply a treatment to a disease.
## @param disease_id: The disease to treat.
## @param treatment_id: The treatment method (must be in disease's treatments).
## @return bool: True if treatment was successful.
func treat_disease(disease_id: String, treatment_id: String) -> bool:
	if not has_disease(disease_id):
		return false
	
	var disease_def := _get_disease_definition(disease_id)
	var treatments: Dictionary = disease_def.get("treatments", {})
	
	if not treatments.has(treatment_id):
		push_warning("DiseaseManager: Treatment '%s' not valid for '%s'" % [treatment_id, disease_id])
		return false
	
	var treatment: Dictionary = treatments[treatment_id]
	var cure_chance: float = treatment.get("cure_chance", 0.5)
	var stage_reduction: int = treatment.get("stage_reduction", 0)
	
	# Apply immunity bonus to cure chance
	var immunity_mod := get_immunity_modifier()
	cure_chance = clampf(cure_chance + immunity_mod * 0.2, 0.1, 0.99)
	
	var roll := randf()
	var success := roll < cure_chance
	
	print("DiseaseManager: Treatment %s on %s - rolled %.2f vs %.2f = %s" % [
		treatment_id, disease_id, roll, cure_chance, "SUCCESS" if success else "FAILED"
	])
	
	treatment_applied.emit(disease_id, treatment_id, success)
	_emit_to_event_bus("treatment_applied", [disease_id, treatment_id, success])
	
	if success:
		_cure_disease(disease_id, treatment_id)
		return true
	elif stage_reduction > 0:
		# Partial success - reduce stage
		_reduce_disease_stage(disease_id, stage_reduction)
	
	return false


func _reduce_disease_stage(disease_id: String, reduction: int) -> void:
	if not active_diseases.has(disease_id):
		return
	
	var disease_state: Dictionary = active_diseases[disease_id]
	var disease_def := _get_disease_definition(disease_id)
	var stages: Array = disease_def.get("stages", [])
	
	var old_stage_index: int = disease_state["stage_index"]
	var new_stage_index: int = maxi(0, old_stage_index - reduction)
	
	if new_stage_index == old_stage_index:
		return
	
	var old_stage_name: String = stages[old_stage_index].get("name", "unknown") if old_stage_index < stages.size() else "unknown"
	var new_stage_name: String = stages[new_stage_index].get("name", "unknown") if new_stage_index < stages.size() else "unknown"
	
	_remove_disease_modifiers(disease_id)
	
	disease_state["stage_index"] = new_stage_index
	disease_state["turns_in_stage"] = 0
	
	_apply_disease_modifiers(disease_id)
	
	print("DiseaseManager: %s reduced from %s to %s" % [disease_id, old_stage_name, new_stage_name])
	disease_stage_changed.emit(disease_id, old_stage_name, new_stage_name)

# =============================================================================
# CURE / REMOVAL
# =============================================================================

func _cure_disease(disease_id: String, method: String) -> void:
	if not active_diseases.has(disease_id):
		return
	
	_remove_disease_modifiers(disease_id)
	active_diseases.erase(disease_id)
	
	# Grant immunity
	var disease_def := _get_disease_definition(disease_id)
	var immunity_days: int = disease_def.get("immunity_duration_days", 0)
	if immunity_days > 0:
		immunities[disease_id] = immunity_days
		immunity_gained.emit(disease_id, immunity_days)
		_emit_to_event_bus("immunity_gained", [disease_id, immunity_days])
	
	print("DiseaseManager: %s cured via %s" % [disease_id, method])
	disease_cured.emit(disease_id, method)
	_emit_to_event_bus("disease_cured", [disease_id, method])


## Force cure a disease (debug/cheat).
func force_cure(disease_id: String) -> void:
	_cure_disease(disease_id, "force_cure")

# =============================================================================
# IMMUNITY
# =============================================================================

func _process_immunities() -> void:
	var expired: Array[String] = []
	
	for disease_id in immunities.keys():
		immunities[disease_id] -= 1
		if immunities[disease_id] <= 0:
			expired.append(disease_id)
	
	for disease_id in expired:
		immunities.erase(disease_id)
		immunity_expired.emit(disease_id)
		_emit_to_event_bus("immunity_expired", [disease_id])
		print("DiseaseManager: Immunity to %s expired" % disease_id)


## Check if player is immune to a disease.
func is_immune(disease_id: String) -> bool:
	return immunities.has(disease_id) and immunities[disease_id] > 0


## Get overall immunity modifier based on survival status.
## Positive = better immunity, negative = worse.
func get_immunity_modifier() -> float:
	if _survival_manager == null:
		return 0.0
	
	var modifier := 0.0
	
	# Hunger
	var hunger_stage: String = _survival_manager.hunger_stage
	match hunger_stage:
		"well_fed":
			modifier += immunity_modifiers.get("well_fed", 0.15)
		"hungry":
			modifier += immunity_modifiers.get("hungry", -0.10)
		"starving", "near_death":
			modifier += immunity_modifiers.get("starving", -0.25)
	
	# Fatigue
	var fatigue_level: String = _survival_manager.fatigue_level
	match fatigue_level:
		"rested":
			modifier += immunity_modifiers.get("rested", 0.10)
		"exhausted":
			modifier += immunity_modifiers.get("exhausted", -0.15)
		"collapsing":
			modifier += immunity_modifiers.get("collapsing", -0.30)
	
	# Thirst
	var thirst_stage: String = _survival_manager.thirst_stage
	match thirst_stage:
		"hydrated":
			modifier += immunity_modifiers.get("hydrated", 0.05)
		"parched", "severe_dehydration":
			modifier += immunity_modifiers.get("dehydrated", -0.20)
	
	return modifier

# =============================================================================
# STAT MODIFIERS
# =============================================================================

func _apply_disease_modifiers(disease_id: String) -> void:
	if _player_stats == null or not _player_stats.has_method("add_modifier"):
		return
	
	var disease_state: Dictionary = active_diseases.get(disease_id, {})
	var disease_def := _get_disease_definition(disease_id)
	var stages: Array = disease_def.get("stages", [])
	
	var stage_index: int = disease_state.get("stage_index", 0)
	if stage_index >= stages.size():
		return
	
	var current_stage: Dictionary = stages[stage_index]
	var modifiers: Array = current_stage.get("modifiers", [])
	
	var source_id := MODIFIER_PREFIX + disease_id
	
	for mod in modifiers:
		var stat: String = mod.get("stat", "")
		var mod_type: String = mod.get("type", "flat")
		var value: int = mod.get("value", 0)
		
		if stat == "all":
			# Apply to all stats
			for stat_name in ["grit", "reflex", "wit", "charm", "aim", "frontier", "shadow", "spirit"]:
				_player_stats.add_modifier(stat_name, value, source_id)
		else:
			_player_stats.add_modifier(stat, value, source_id)


func _remove_disease_modifiers(disease_id: String) -> void:
	if _player_stats == null or not _player_stats.has_method("remove_modifiers_by_source"):
		return
	
	var source_id := MODIFIER_PREFIX + disease_id
	_player_stats.remove_modifiers_by_source(source_id)


func _emit_symptoms(disease_id: String) -> void:
	var disease_state: Dictionary = active_diseases.get(disease_id, {})
	var disease_def := _get_disease_definition(disease_id)
	var stages: Array = disease_def.get("stages", [])
	
	var stage_index: int = disease_state.get("stage_index", 0)
	if stage_index >= stages.size():
		return
	
	var current_stage: Dictionary = stages[stage_index]
	var symptoms: Array = current_stage.get("symptoms", [])
	
	for symptom in symptoms:
		disease_symptom.emit(disease_id, symptom)
		_emit_to_event_bus("disease_symptom", [disease_id, symptom])

# =============================================================================
# QUERIES
# =============================================================================

## Check if player has a specific disease.
func has_disease(disease_id: String) -> bool:
	return active_diseases.has(disease_id)


## Check if player has any active disease.
func has_any_disease() -> bool:
	return not active_diseases.is_empty()


## Get all active diseases as array of dictionaries.
func get_active_diseases() -> Array:
	var result: Array = []
	
	for disease_id in active_diseases.keys():
		var disease_state: Dictionary = active_diseases[disease_id]
		var disease_def := _get_disease_definition(disease_id)
		var stages: Array = disease_def.get("stages", [])
		
		var stage_index: int = disease_state.get("stage_index", 0)
		var stage_name: String = "incubating"
		var stage_description: String = "The disease is incubating."
		
		if not disease_state.get("incubating", false) and stage_index < stages.size():
			stage_name = stages[stage_index].get("name", "unknown")
			stage_description = stages[stage_index].get("description", "")
		
		result.append({
			"id": disease_id,
			"name": disease_def.get("name", disease_id),
			"stage": stage_name,
			"stage_index": stage_index,
			"description": stage_description,
			"incubating": disease_state.get("incubating", false),
			"turns_in_stage": disease_state.get("turns_in_stage", 0)
		})
	
	return result


## Get the current stage name of a disease.
func get_disease_stage(disease_id: String) -> String:
	if not has_disease(disease_id):
		return ""
	
	var disease_state: Dictionary = active_diseases[disease_id]
	if disease_state.get("incubating", false):
		return "incubating"
	
	var disease_def := _get_disease_definition(disease_id)
	var stages: Array = disease_def.get("stages", [])
	var stage_index: int = disease_state.get("stage_index", 0)
	
	if stage_index < stages.size():
		return stages[stage_index].get("name", "unknown")
	
	return "unknown"


## Get the thirst multiplier from all active diseases.
func get_thirst_multiplier() -> float:
	var multiplier := 1.0
	
	for disease_id in active_diseases.keys():
		var disease_state: Dictionary = active_diseases[disease_id]
		if disease_state.get("incubating", false):
			continue
		
		var disease_def := _get_disease_definition(disease_id)
		var stages: Array = disease_def.get("stages", [])
		var stage_index: int = disease_state.get("stage_index", 0)
		
		if stage_index < stages.size():
			var stage_mult: float = stages[stage_index].get("thirst_multiplier", 1.0)
			multiplier = maxf(multiplier, stage_mult)
	
	return multiplier


## Get the fatigue multiplier from all active diseases.
func get_fatigue_multiplier() -> float:
	var multiplier := 1.0
	
	for disease_id in active_diseases.keys():
		var disease_state: Dictionary = active_diseases[disease_id]
		if disease_state.get("incubating", false):
			continue
		
		var disease_def := _get_disease_definition(disease_id)
		var stages: Array = disease_def.get("stages", [])
		var stage_index: int = disease_state.get("stage_index", 0)
		
		if stage_index < stages.size():
			var stage_mult: float = stages[stage_index].get("fatigue_multiplier", 1.0)
			multiplier = maxf(multiplier, stage_mult)
	
	return multiplier


## Get list of all disease IDs the player can potentially contract.
func get_all_disease_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in disease_definitions.keys():
		ids.append(id)
	return ids

# =============================================================================
# HELPERS
# =============================================================================

func _get_disease_definition(disease_id: String) -> Dictionary:
	return disease_definitions.get(disease_id, {})

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"active_diseases": active_diseases.duplicate(true),
		"immunities": immunities.duplicate()
	}


func from_dict(data: Dictionary) -> void:
	active_diseases = data.get("active_diseases", {}).duplicate(true)
	immunities = data.get("immunities", {}).duplicate()
	
	# Re-apply modifiers for active diseases
	for disease_id in active_diseases.keys():
		var disease_state: Dictionary = active_diseases[disease_id]
		if not disease_state.get("incubating", false):
			_apply_disease_modifiers(disease_id)
	
	print("DiseaseManager: Loaded from save - %d active diseases" % active_diseases.size())

# =============================================================================
# DEBUG
# =============================================================================

func debug_contract_disease(disease_id: String) -> void:
	contract_disease(disease_id, "debug")


func debug_cure_all() -> void:
	var to_cure: Array = active_diseases.keys().duplicate()
	for disease_id in to_cure:
		force_cure(disease_id)


func debug_list_diseases() -> void:
	print("=== Disease Status ===")
	if active_diseases.is_empty():
		print("  No active diseases")
	else:
		for disease_id in active_diseases.keys():
			var info := get_active_diseases().filter(func(d): return d["id"] == disease_id)
			if info.size() > 0:
				var d: Dictionary = info[0]
				print("  %s: %s (stage %d, %d turns)" % [d["name"], d["stage"], d["stage_index"], d["turns_in_stage"]])
	
	print("=== Immunities ===")
	if immunities.is_empty():
		print("  No immunities")
	else:
		for disease_id in immunities.keys():
			print("  %s: %d days remaining" % [disease_id, immunities[disease_id]])


func debug_print_immunity() -> void:
	var mod := get_immunity_modifier()
	print("Immunity modifier: %.2f" % mod)

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
