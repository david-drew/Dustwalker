# encounter_manager.gd
# Manages random encounters triggered by player movement.
# Handles encounter triggering, selection, and resolution.
# Updated with tactical combat integration for hostile encounters.
#
# ENCOUNTER FLOW:
# 1. Player enters hex → Check for encounter (% chance)
# 2. If triggered → Select encounter from terrain pool
# 3. Show encounter UI → Player makes choice
# 4. If "Fight" chosen → Start tactical combat
# 5. Combat ends → Apply loot, close encounter
# 6. Resume gameplay

extends Node
class_name EncounterManager

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when encounter check starts.
signal encounter_check_started(hex_coords: Vector2i)

## Emitted when an encounter is triggered.
signal encounter_triggered(encounter_id: String, hex_coords: Vector2i)

## Emitted when player makes a choice.
signal encounter_choice_made(encounter_id: String, choice_index: int)

## Emitted when encounter is resolved (effects applied).
signal encounter_resolved(encounter_id: String, effects: Dictionary)

## Emitted when encounter UI opens.
signal encounter_ui_opened()

## Emitted when encounter UI closes.
signal encounter_ui_closed()

## Emitted when combat is triggered from an encounter.
signal combat_initiated(encounter_id: String, combat_data: Dictionary, terrain: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Base encounter rates by terrain.
var base_rates: Dictionary = {}

## Time of day modifiers.
var time_modifiers: Dictionary = {}

## Location modifiers.
var location_modifiers: Dictionary = {}

## Category weights for selection.
var category_weights: Dictionary = {}

## Rarity weights for selection.
var rarity_weights: Dictionary = {}

## All loaded encounter definitions.
var encounters: Array = []

# =============================================================================
# STATE
# =============================================================================

## Currently active encounter (null if none).
var active_encounter: Dictionary = {}

## Coordinates where active encounter was triggered.
var active_encounter_coords: Vector2i = Vector2i.ZERO

## Terrain type where active encounter was triggered.
var active_encounter_terrain: String = "plains"

## Whether an encounter is currently active.
var encounter_active: bool = false

## Whether combat is currently in progress for this encounter.
var combat_in_progress: bool = false

## Reference to hex grid.
var hex_grid: HexGrid = null

## Reference to survival manager.
var survival_manager: SurvivalManager = null

## Reference to inventory manager.
var inventory_manager: InventoryManager = null

## Reference to encounter window UI.
var encounter_window = null  # EncounterWindow

## Reference to combat manager.
var combat_manager: CombatManager = null

## Whether the system has been initialized.
var _initialized: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()
	_connect_signals()
	add_to_group("encounter_manager")


func _load_config() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader == null:
		_use_default_config()
		return
	
	var config: Dictionary = loader.load_json("res://data/encounters/encounters.json")
	if config.is_empty():
		_use_default_config()
		return
	
	# Load rates
	var rates: Dictionary = config.get("encounter_rates", {})
	base_rates = rates.get("base_by_terrain", {})
	time_modifiers = rates.get("time_of_day_modifiers", {})
	location_modifiers = rates.get("location_modifiers", {})
	
	# Load weights
	category_weights = config.get("category_weights", {
		"hostile": 0.60,
		"neutral": 0.25,
		"discovery": 0.10,
		"environmental": 0.05
	})
	rarity_weights = config.get("rarity_weights", {
		"common": 0.70,
		"uncommon": 0.25,
		"rare": 0.05
	})
	
	# Load encounters
	encounters = config.get("encounters", [])
	
	print("EncounterManager: Loaded %d encounters" % encounters.size())


func _use_default_config() -> void:
	base_rates = {
		"plains": 0.30,
		"forest": 0.45,
		"desert": 0.35,
		"badlands": 0.40,
		"mountains": 0.40
	}
	time_modifiers = {
		"Late Night": 0.15,
		"Night": 0.10
	}
	location_modifiers = {
		"town": -0.50,
		"fort": -0.40
	}
	category_weights = {
		"hostile": 0.60,
		"neutral": 0.25,
		"discovery": 0.10,
		"environmental": 0.05
	}
	rarity_weights = {
		"common": 0.70,
		"uncommon": 0.25,
		"rare": 0.05
	}
	encounters = []
	print("EncounterManager: Using default configuration")


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("player_moved_to_hex"):
			event_bus.player_moved_to_hex.connect(_on_player_moved_to_hex)


## Initialize with references to other systems.
func initialize(grid: HexGrid, survival: SurvivalManager, inventory: InventoryManager) -> void:
	hex_grid = grid
	survival_manager = survival
	inventory_manager = inventory
	_initialized = true
	print("EncounterManager: Initialized")


## Set the encounter window UI reference.
func set_encounter_window(window) -> void:
	encounter_window = window
	if encounter_window:
		encounter_window.choice_selected.connect(_on_choice_selected)
		encounter_window.encounter_continued.connect(_on_encounter_continued)


## Set the combat manager reference.
func set_combat_manager(manager: CombatManager) -> void:
	combat_manager = manager

# =============================================================================
# ENCOUNTER TRIGGERING
# =============================================================================

## Called when player moves to a new hex.
func _on_player_moved_to_hex(coords: Vector2i) -> void:
	if not _initialized or encounter_active or combat_in_progress:
		return
	
	check_for_encounter(coords)


## Check if an encounter should trigger at the given coordinates.
## @return bool - True if encounter triggered.
func check_for_encounter(coords: Vector2i) -> bool:
	if encounter_active or combat_in_progress:
		return false
	
	encounter_check_started.emit(coords)
	_emit_to_event_bus("encounter_check_started", [coords])
	
	# Get cell data
	var cell: HexCell = hex_grid.get_cell(coords) if hex_grid else null
	if cell == null:
		return false
	
	var terrain: String = cell.terrain_type
	var location = cell.location
	
	# Calculate encounter chance
	var chance := get_encounter_chance(terrain, location)
	
	# Roll for encounter
	var roll := randf()
	if roll >= chance:
		return false
	
	# Encounter triggered!
	trigger_encounter(coords, terrain, location)
	return true


## Calculate the total encounter chance for a hex.
func get_encounter_chance(terrain: String, location) -> float:
	# Base rate from terrain
	var base: float = base_rates.get(terrain, 0.30)
	
	# Time of day modifier
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		var time_name: String = time_manager.get_time_of_day()
		base += time_modifiers.get(time_name, 0.0)
	
	# Location modifier
	if location != null:
		var loc_type: String = location.get("type", "")
		base += location_modifiers.get(loc_type, 0.0)
	
	# Weather modifier (multiply by weather encounter rate)
	var weather_manager = get_tree().get_first_node_in_group("weather_manager")
	if weather_manager and weather_manager.has_method("get_encounter_modifier"):
		base *= weather_manager.get_encounter_modifier()
	
	# Clamp to valid range
	return clampf(base, 0.0, 1.0)


## Trigger an encounter at the specified location.
func trigger_encounter(coords: Vector2i, terrain: String, location) -> void:
	# Select an appropriate encounter
	var selected := select_encounter(terrain)
	
	if selected.is_empty():
		print("EncounterManager: No suitable encounter found for terrain '%s'" % terrain)
		return
	
	# Store active encounter state
	active_encounter = selected
	active_encounter_coords = coords
	active_encounter_terrain = terrain
	encounter_active = true
	
	encounter_triggered.emit(selected["id"], coords)
	_emit_to_event_bus("encounter_triggered", [selected["id"], coords])
	
	# Show encounter UI
	_show_encounter_ui(selected)

# =============================================================================
# ENCOUNTER SELECTION
# =============================================================================

## Select an encounter appropriate for the given terrain.
func select_encounter(terrain: String) -> Dictionary:
	if encounters.is_empty():
		return {}
	
	# First, select a category based on weights
	var category := _weighted_random_category()
	
	# Filter encounters by terrain and category
	var candidates: Array = []
	for enc in encounters:
		var enc_terrain: Array = enc.get("terrain", [])
		var enc_category: String = enc.get("category", "")
		
		# Check terrain match
		if enc_terrain.is_empty() or terrain in enc_terrain:
			# Check category match (prefer matching, but allow all if none match)
			if enc_category == category:
				candidates.append(enc)
	
	# If no matches for category, try any encounter for this terrain
	if candidates.is_empty():
		for enc in encounters:
			var enc_terrain: Array = enc.get("terrain", [])
			if enc_terrain.is_empty() or terrain in enc_terrain:
				candidates.append(enc)
	
	if candidates.is_empty():
		return {}
	
	# Weight by rarity
	return _weighted_random_encounter(candidates)


func _weighted_random_category() -> String:
	var total_weight := 0.0
	for cat in category_weights:
		total_weight += category_weights[cat]
	
	var roll := randf() * total_weight
	var cumulative := 0.0
	
	for cat in category_weights:
		cumulative += category_weights[cat]
		if roll <= cumulative:
			return cat
	
	return "hostile"  # Default fallback


func _weighted_random_encounter(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	
	# Build weighted list
	var weighted: Array = []
	var total_weight := 0.0
	
	for enc in candidates:
		var rarity: String = enc.get("rarity", "common")
		var weight: float = rarity_weights.get(rarity, 0.70)
		total_weight += weight
		weighted.append({"encounter": enc, "weight": weight})
	
	# Random selection
	var roll := randf() * total_weight
	var cumulative := 0.0
	
	for item in weighted:
		cumulative += item["weight"]
		if roll <= cumulative:
			return item["encounter"]
	
	# Fallback to first candidate
	return candidates[0]

# =============================================================================
# ENCOUNTER UI
# =============================================================================

func _show_encounter_ui(encounter: Dictionary) -> void:
	if encounter_window == null:
		push_error("EncounterManager: No encounter window set")
		_auto_resolve_encounter()
		return
	
	# Filter choices based on requirements
	var available_choices := _get_available_choices(encounter)
	
	encounter_window.show_encounter(encounter, available_choices)
	encounter_ui_opened.emit()
	_emit_to_event_bus("encounter_ui_opened", [])


func _get_available_choices(encounter: Dictionary) -> Array:
	var choices: Array = encounter.get("choices", [])
	var available: Array = []
	
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var requirements: Dictionary = choice.get("requires", {})
		
		# Check if player can afford requirements
		if inventory_manager and not inventory_manager.can_afford_requirements(requirements):
			continue
		
		available.append({
			"index": i,
			"text": choice.get("text", "..."),
			"choice_data": choice
		})
	
	return available


func _auto_resolve_encounter() -> void:
	# Auto-resolve if no UI available (pick first available choice)
	var choices: Array = active_encounter.get("choices", [])
	if choices.size() > 0:
		_resolve_choice(0)
	else:
		_close_encounter()

# =============================================================================
# ENCOUNTER RESOLUTION
# =============================================================================

## Called when player selects a choice.
func _on_choice_selected(choice_index: int) -> void:
	if not encounter_active:
		return
	
	encounter_choice_made.emit(active_encounter.get("id", ""), choice_index)
	_emit_to_event_bus("encounter_choice_made", [active_encounter.get("id", ""), choice_index])
	
	_resolve_choice(choice_index)


func _resolve_choice(choice_index: int) -> void:
	var choices: Array = active_encounter.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		_close_encounter()
		return
	
	var choice: Dictionary = choices[choice_index]
	var choice_text: String = choice.get("text", "").to_lower()
	
	# Check if this is a "Fight" choice that should trigger combat
	if _is_fight_choice(choice_text) and _has_combat_data():
		_initiate_combat()
		return
	
	# Regular choice resolution
	var effects: Dictionary = choice.get("effects", {})
	var outcome: String = choice.get("outcome", "")
	
	# Apply effects
	var applied_effects := _apply_effects(effects)
	
	encounter_resolved.emit(active_encounter.get("id", ""), applied_effects)
	_emit_to_event_bus("encounter_resolved", [active_encounter.get("id", ""), applied_effects])
	
	# Show outcome in UI
	if encounter_window:
		encounter_window.show_outcome(outcome, applied_effects)


## Check if a choice text represents a "fight" action.
func _is_fight_choice(text: String) -> bool:
	var fight_keywords := ["fight", "attack", "battle", "combat", "stand your ground"]
	for keyword in fight_keywords:
		if keyword in text:
			return true
	return false


## Check if the active encounter has combat data.
func _has_combat_data() -> bool:
	return active_encounter.has("combat_data") and not active_encounter["combat_data"].is_empty()

# =============================================================================
# COMBAT INTEGRATION
# =============================================================================

## Initiate tactical combat from the current encounter.
func _initiate_combat() -> void:
	if combat_manager == null:
		# Try to find combat manager
		combat_manager = get_tree().get_first_node_in_group("combat_manager")
	
	if combat_manager == null:
		push_error("EncounterManager: No combat manager available!")
		# Fall back to regular resolution
		_resolve_choice_without_combat()
		return
	
	var combat_data: Dictionary = active_encounter.get("combat_data", {})
	
	# Hide encounter UI during combat
	if encounter_window:
		encounter_window.hide_encounter()
	
	combat_in_progress = true
	
	# Emit signal for combat initiation
	combat_initiated.emit(active_encounter.get("id", ""), combat_data, active_encounter_terrain)
	_emit_to_event_bus("combat_initiated", [active_encounter.get("id", ""), active_encounter_terrain])
	
	print("EncounterManager: Initiating combat with data: ", combat_data)
	
	# Start combat with callback
	combat_manager.start_combat(
		combat_data,
		active_encounter_terrain,
		_on_combat_ended
	)


## Called when combat ends (callback from CombatManager).
func _on_combat_ended(victory: bool, loot: Dictionary) -> void:
	combat_in_progress = false
	
	if victory:
		# Combat victory - apply loot and close encounter
		print("EncounterManager: Combat victory! Loot: ", loot)
		
		# Loot is already applied by CombatManager
		# Just show a brief outcome and close
		if encounter_window:
			var outcome_text := "You emerged victorious from battle."
			if loot.get("money", 0) > 0:
				outcome_text += " Gained %d dollars." % loot["money"]
			
			encounter_window.show_outcome(outcome_text, {"combat_victory": true})
		else:
			_close_encounter()
	else:
		# Combat defeat - player died, game over is handled by CombatManager
		print("EncounterManager: Combat defeat - player died")
		_close_encounter()


## Fallback resolution if combat isn't available.
func _resolve_choice_without_combat() -> void:
	var choices: Array = active_encounter.get("choices", [])
	
	# Find the fight choice and use its regular effects
	for choice in choices:
		if _is_fight_choice(choice.get("text", "").to_lower()):
			var effects: Dictionary = choice.get("effects", {})
			var outcome: String = choice.get("outcome", "")
			
			var applied_effects := _apply_effects(effects)
			
			encounter_resolved.emit(active_encounter.get("id", ""), applied_effects)
			
			if encounter_window:
				encounter_window.show_outcome(outcome, applied_effects)
			return
	
	_close_encounter()


func _apply_effects(effects: Dictionary) -> Dictionary:
	var applied := {}
	
	# Health effects
	if effects.has("health"):
		var amount: int = effects["health"]
		if survival_manager:
			survival_manager.modify_health(amount, "encounter")
		applied["health"] = amount
	
	# Hunger effects (direct modification, not from eating)
	if effects.has("hunger"):
		var amount: int = effects["hunger"]
		if survival_manager:
			survival_manager.modify_hunger(amount)
		applied["hunger"] = amount
	
	# Thirst effects (direct modification, not from drinking)
	if effects.has("thirst"):
		var amount: int = effects["thirst"]
		if survival_manager:
			survival_manager.modify_thirst(amount)
		applied["thirst"] = amount
	
	# Item effects (rations, water)
	if inventory_manager:
		var item_effects := inventory_manager.apply_encounter_effects(effects)
		for key in item_effects:
			applied[key] = item_effects[key]
	
	# Turn cost effects
	if effects.has("turn_cost"):
		var turns: int = effects["turn_cost"]
		if turns > 0:
			var time_manager = get_node_or_null("/root/TimeManager")
			if time_manager:
				time_manager.advance_turn(turns)
			applied["turn_cost"] = turns
	
	return applied


## Called when player clicks continue after outcome.
func _on_encounter_continued() -> void:
	_close_encounter()


func _close_encounter() -> void:
	active_encounter = {}
	active_encounter_coords = Vector2i.ZERO
	active_encounter_terrain = "plains"
	encounter_active = false
	combat_in_progress = false
	
	if encounter_window:
		encounter_window.hide_encounter()
	
	encounter_ui_closed.emit()
	_emit_to_event_bus("encounter_ui_closed", [])

# =============================================================================
# QUERIES
# =============================================================================

## Check if an encounter is currently active.
func is_encounter_active() -> bool:
	return encounter_active or combat_in_progress


## Get the current active encounter (if any).
func get_active_encounter() -> Dictionary:
	return active_encounter


## Get encounter by ID.
func get_encounter_by_id(encounter_id: String) -> Dictionary:
	for enc in encounters:
		if enc.get("id", "") == encounter_id:
			return enc
	return {}

# =============================================================================
# SERIALIZATION
# =============================================================================

## Convert encounter state to dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"encounter_active": encounter_active,
		"combat_in_progress": combat_in_progress,
		"active_encounter_id": active_encounter.get("id", ""),
		"active_encounter_coords": {
			"q": active_encounter_coords.x,
			"r": active_encounter_coords.y
		},
		"active_encounter_terrain": active_encounter_terrain
	}


## Load encounter state from dictionary.
func from_dict(data: Dictionary) -> void:
	# Don't restore mid-combat state - just close any encounter
	encounter_active = false
	combat_in_progress = false
	active_encounter = {}
	active_encounter_coords = Vector2i.ZERO
	active_encounter_terrain = "plains"
	
	print("EncounterManager: Loaded state (encounters reset)")

# =============================================================================
# DEBUG
# =============================================================================

## Force trigger a specific encounter (debug).
func debug_trigger_encounter(encounter_id: String, coords: Vector2i = Vector2i.ZERO) -> void:
	var enc := get_encounter_by_id(encounter_id)
	if enc.is_empty():
		print("EncounterManager: Encounter '%s' not found" % encounter_id)
		return
	
	active_encounter = enc
	active_encounter_coords = coords
	active_encounter_terrain = "plains"
	encounter_active = true
	
	encounter_triggered.emit(enc["id"], coords)
	_emit_to_event_bus("encounter_triggered", [enc["id"], coords])
	
	_show_encounter_ui(enc)


## Force trigger combat (debug).
func debug_trigger_combat(enemy_type: String = "bandit", count: int = 2, terrain: String = "plains") -> void:
	var combat_data := {
		"enemies": [
			{"type": enemy_type, "count": count}
		]
	}
	
	active_encounter = {
		"id": "debug_combat",
		"combat_data": combat_data
	}
	active_encounter_terrain = terrain
	encounter_active = true
	
	_initiate_combat()


## List all available encounters (debug).
func debug_list_encounters() -> void:
	print("=== Available Encounters ===")
	for enc in encounters:
		var has_combat := "YES" if enc.has("combat_data") else "no"
		print("  %s (%s/%s): %s [combat: %s]" % [
			enc.get("id", "?"),
			enc.get("category", "?"),
			enc.get("rarity", "?"),
			enc.get("title", "?"),
			has_combat
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
