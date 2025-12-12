# character_creator.gd
# Manages character creation data and logic.
# Loads backgrounds from JSON, handles stat customization, and produces character data.
#
# Used by CharacterCreationScreen to populate UI and validate choices.

extends Node
class_name CharacterCreator

# =============================================================================
# SIGNALS
# =============================================================================

signal background_selected(background_id: String, background_data: Dictionary)
signal stats_customized(stats: Dictionary)
signal character_created(character_data: Dictionary)

# =============================================================================
# CONSTANTS
# =============================================================================

const BACKGROUNDS_PATH := "res://data/character/backgrounds.json"
const TOTAL_STAT_POINTS := 20  # Base points each background should total
const MIN_STAT := 1
const MAX_STAT := 5

# =============================================================================
# STATE
# =============================================================================

var _backgrounds: Dictionary = {}  # id -> background data
var _selected_background_id: String = ""
var _selected_background: Dictionary = {}
var _customized_stats: Dictionary = {}
var _character_name: String = ""
var _base_stat_total: int = 0  # Original total from background

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("character_creator")
	_load_backgrounds()


func _load_backgrounds() -> void:
	if not FileAccess.file_exists(BACKGROUNDS_PATH):
		push_error("CharacterCreator: backgrounds.json not found at %s" % BACKGROUNDS_PATH)
		return
	
	var file := FileAccess.open(BACKGROUNDS_PATH, FileAccess.READ)
	if not file:
		push_error("CharacterCreator: Could not open backgrounds.json")
		return
	
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_error("CharacterCreator: JSON parse error: %s" % json.get_error_message())
		return
	
	var data: Dictionary = json.data
	if not data.has("backgrounds"):
		push_error("CharacterCreator: No 'backgrounds' array in JSON")
		return
	
	for bg in data.backgrounds:
		var bg_id: String = bg.get("id", "")
		if not bg_id.is_empty():
			_backgrounds[bg_id] = bg
	
	print("CharacterCreator: Loaded %d backgrounds" % _backgrounds.size())

# =============================================================================
# BACKGROUND SELECTION
# =============================================================================

## Returns all available backgrounds as an array.
func get_all_backgrounds() -> Array:
	var result := []
	for bg_id in _backgrounds:
		result.append(_backgrounds[bg_id])
	return result


## Returns a specific background by ID.
func get_background(bg_id: String) -> Dictionary:
	return _backgrounds.get(bg_id, {})


## Selects a background and initializes customization.
func select_background(bg_id: String) -> bool:
	if not _backgrounds.has(bg_id):
		push_warning("CharacterCreator: Unknown background '%s'" % bg_id)
		return false
	
	_selected_background_id = bg_id
	_selected_background = _backgrounds[bg_id].duplicate(true)
	
	# Initialize customized stats from background base
	_customized_stats = _selected_background.get("stats", {}).duplicate()
	
	# Calculate base total for point tracking
	_base_stat_total = 0
	for stat in _customized_stats:
		_base_stat_total += _customized_stats[stat]
	
	print("CharacterCreator: Selected background '%s' (base stats: %d)" % [bg_id, _base_stat_total])
	
	background_selected.emit(bg_id, _selected_background)
	return true


## Returns the currently selected background data.
func get_selected_background() -> Dictionary:
	return _selected_background

# =============================================================================
# STAT CUSTOMIZATION
# =============================================================================

## Increases a stat by 1 if points are available.
func increase_stat(stat_name: String) -> bool:
	if not _customized_stats.has(stat_name):
		return false
	
	if _customized_stats[stat_name] >= MAX_STAT:
		return false
	
	if get_remaining_stat_points() <= 0:
		return false
	
	_customized_stats[stat_name] += 1
	stats_customized.emit(_customized_stats)
	return true


## Decreases a stat by 1 if above minimum.
func decrease_stat(stat_name: String) -> bool:
	if not _customized_stats.has(stat_name):
		return false
	
	if _customized_stats[stat_name] <= MIN_STAT:
		return false
	
	_customized_stats[stat_name] -= 1
	stats_customized.emit(_customized_stats)
	return true


## Returns current stat value.
func get_stat(stat_name: String) -> int:
	return _customized_stats.get(stat_name, 0)


## Returns all current stats.
func get_stats() -> Dictionary:
	return _customized_stats.duplicate()


## Returns remaining points available for stat customization.
func get_remaining_stat_points() -> int:
	var current_total := 0
	for stat in _customized_stats:
		current_total += _customized_stats[stat]
	
	# Players can redistribute but not add/remove total points
	return _base_stat_total - current_total

# =============================================================================
# CHARACTER NAME
# =============================================================================

## Sets the character name.
func set_character_name(new_name: String) -> void:
	_character_name = new_name.strip_edges()


## Returns the current character name.
func get_character_name() -> String:
	return _character_name

# =============================================================================
# VALIDATION
# =============================================================================

## Validates the current character configuration.
func validate_character() -> Dictionary:
	var errors := []
	
	# Must have a background selected
	if _selected_background_id.is_empty():
		errors.append("No background selected")
	
	# Must have a name
	if _character_name.is_empty():
		errors.append("Character name is required")
	elif _character_name.length() < 2:
		errors.append("Character name must be at least 2 characters")
	elif _character_name.length() > 24:
		errors.append("Character name must be 24 characters or less")
	
	# Stats must be properly distributed
	var remaining := get_remaining_stat_points()
	if remaining != 0:
		errors.append("Stat points not fully distributed (%d remaining)" % remaining)
	
	# Check stat bounds
	for stat in _customized_stats:
		var val: int = _customized_stats[stat]
		if val < MIN_STAT or val > MAX_STAT:
			errors.append("Stat '%s' out of bounds (%d)" % [stat, val])
	
	return {
		"valid": errors.is_empty(),
		"errors": errors
	}

# =============================================================================
# CHARACTER CREATION
# =============================================================================

## Creates the character and returns the data dictionary.
func create_character() -> bool:
	var validation := validate_character()
	if not validation.valid:
		push_warning("CharacterCreator: Validation failed - %s" % str(validation.errors))
		return false
	
	print("CharacterCreator: Character created - %s (%s)" % [_character_name, _selected_background_id])
	
	var char_data := get_character_preview()
	character_created.emit(char_data)
	return true


## Returns a preview of the character data without creating.
func get_character_preview() -> Dictionary:
	if _selected_background_id.is_empty():
		return {}

	var equipment_data: Dictionary = _selected_background.get("equipment", {}).duplicate()
	print("CharacterCreator: get_character_preview() called")
	print("CharacterCreator: Background: %s" % _selected_background_id)
	print("CharacterCreator: Equipment from background: %s" % str(equipment_data))

	var result := {
		"name": _character_name,
		"background_id": _selected_background_id,
		"stats": _customized_stats.duplicate(),
		"skills": _selected_background.get("skills", {}).duplicate(),
		"starting_talent": _selected_background.get("starting_talent", ""),
		"equipment": equipment_data,
		"backstory": _selected_background.get("backstory", ""),
		"playstyle": _selected_background.get("playstyle", ""),
		"seed": randi()
	}

	print("CharacterCreator: Final character data: %s" % str(result))

	return result

# =============================================================================
# RESET
# =============================================================================

## Resets all character creation state.
func reset() -> void:
	_selected_background_id = ""
	_selected_background = {}
	_customized_stats = {}
	_character_name = ""
	_base_stat_total = 0
