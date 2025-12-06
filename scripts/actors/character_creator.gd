# character_creator.gd
# Manages the character creation process, applying backgrounds and customization.
#
# CHARACTER CREATION FLOW:
# 1. Select background (sets base stats, skills, talent, equipment)
# 2. Optionally customize stats within limits
# 3. Confirm and apply to player systems
#
# DEPENDENCIES:
# - PlayerStats: For applying stats
# - SkillManager: For applying skills
# - TalentManager: For applying starting talent
# - InventoryManager: For applying equipment (if available)
# - SurvivalManager: For initializing HP (if available)

extends Node
class_name CharacterCreator

# =============================================================================
# CONSTANTS
# =============================================================================

const CONFIG_PATH := "res://data/character/backgrounds.json"

## Stat point limits for customization
const STAT_POINT_TOTAL := 24
const MIN_STAT := 1
const MAX_STAT := 5  # Cap at 5 during creation (6+ requires gameplay)

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a background is selected.
signal background_selected(background_id: String, background_data: Dictionary)

## Emitted when stats are customized.
signal stats_customized(stats: Dictionary)

## Emitted when character creation is complete.
signal character_created(character_data: Dictionary)

## Emitted when character creation fails.
signal creation_failed(reason: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Loaded background definitions.
var backgrounds: Dictionary = {}

## Tag and difficulty descriptions.
var tag_descriptions: Dictionary = {}
var difficulty_descriptions: Dictionary = {}

# =============================================================================
# STATE
# =============================================================================

## Currently selected background.
var selected_background: String = ""
var selected_background_data: Dictionary = {}

## Customized stats (if player modifies from background defaults).
var customized_stats: Dictionary = {}

## Whether stats have been customized.
var is_customized: bool = false

## Character name.
var character_name: String = "Stranger"

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()
	add_to_group("character_creator")
	print("CharacterCreator: Initialized with %d backgrounds" % backgrounds.size())


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
		backgrounds = config.get("backgrounds", {})
		tag_descriptions = config.get("tag_descriptions", {})
		difficulty_descriptions = config.get("difficulty_descriptions", {})
		print("CharacterCreator: Loaded config")
	else:
		push_warning("CharacterCreator: Could not load backgrounds config")

# =============================================================================
# BACKGROUND QUERIES
# =============================================================================

## Get all available backgrounds.
func get_all_backgrounds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for bg_id in backgrounds:
		var bg: Dictionary = backgrounds[bg_id].duplicate()
		bg["id"] = bg_id
		result.append(bg)
	
	return result


## Get backgrounds filtered by tag.
func get_backgrounds_by_tag(tag: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for bg_id in backgrounds:
		var bg: Dictionary = backgrounds[bg_id]
		var tags: Array = bg.get("tags", [])
		if tag in tags:
			var bg_copy: Dictionary = bg.duplicate()
			bg_copy["id"] = bg_id
			result.append(bg_copy)
	
	return result


## Get backgrounds filtered by difficulty.
func get_backgrounds_by_difficulty(difficulty: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for bg_id in backgrounds:
		var bg: Dictionary = backgrounds[bg_id]
		if bg.get("difficulty", "normal") == difficulty:
			var bg_copy: Dictionary = bg.duplicate()
			bg_copy["id"] = bg_id
			result.append(bg_copy)
	
	return result


## Get detailed info about a specific background.
func get_background_info(background_id: String) -> Dictionary:
	if not backgrounds.has(background_id):
		return {}
	
	var bg: Dictionary = backgrounds[background_id].duplicate(true)
	bg["id"] = background_id
	
	# Add tag descriptions
	var tag_descs: Array[String] = []
	for tag in bg.get("tags", []):
		if tag_descriptions.has(tag):
			tag_descs.append(tag_descriptions[tag])
	bg["tag_descriptions"] = tag_descs
	
	# Add difficulty description
	var diff: String = bg.get("difficulty", "normal")
	bg["difficulty_description"] = difficulty_descriptions.get(diff, "")
	
	return bg


## Get all available tags.
func get_all_tags() -> Array[String]:
	var tags: Array[String] = []
	for tag in tag_descriptions:
		tags.append(tag)
	return tags

# =============================================================================
# BACKGROUND SELECTION
# =============================================================================

## Select a background for the character.
func select_background(background_id: String) -> bool:
	if not backgrounds.has(background_id):
		push_warning("CharacterCreator: Unknown background '%s'" % background_id)
		return false
	
	selected_background = background_id
	selected_background_data = backgrounds[background_id].duplicate(true)
	
	# Reset customization
	customized_stats = selected_background_data.get("stats", {}).duplicate()
	is_customized = false
	
	background_selected.emit(background_id, selected_background_data)
	print("CharacterCreator: Selected background '%s'" % background_id)
	return true


## Get currently selected background.
func get_selected_background() -> Dictionary:
	if selected_background.is_empty():
		return {}
	
	var result: Dictionary = selected_background_data.duplicate(true)
	result["id"] = selected_background
	result["customized_stats"] = customized_stats.duplicate()
	result["is_customized"] = is_customized
	return result

# =============================================================================
# STAT CUSTOMIZATION
# =============================================================================

## Get current stats (customized or background defaults).
func get_current_stats() -> Dictionary:
	if is_customized:
		return customized_stats.duplicate()
	elif not selected_background_data.is_empty():
		return selected_background_data.get("stats", {}).duplicate()
	else:
		return {}


## Get remaining stat points for customization.
func get_remaining_stat_points() -> int:
	var total_used := 0
	var stats := get_current_stats()
	for stat_name in stats:
		total_used += stats[stat_name]
	return STAT_POINT_TOTAL - total_used


## Increase a stat by 1.
func increase_stat(stat_name: String) -> bool:
	if not _can_modify_stat(stat_name, 1):
		return false
	
	_ensure_customized()
	customized_stats[stat_name] = customized_stats.get(stat_name, 1) + 1
	stats_customized.emit(customized_stats)
	return true


## Decrease a stat by 1.
func decrease_stat(stat_name: String) -> bool:
	if not _can_modify_stat(stat_name, -1):
		return false
	
	_ensure_customized()
	customized_stats[stat_name] = customized_stats.get(stat_name, 1) - 1
	stats_customized.emit(customized_stats)
	return true


## Set a stat to a specific value.
func set_stat(stat_name: String, value: int) -> bool:
	var clamped := clampi(value, MIN_STAT, MAX_STAT)
	var current := get_current_stats().get(stat_name, 1)
	var diff := clamped - current
	
	# Check if we have enough points
	if diff > 0 and get_remaining_stat_points() < diff:
		return false
	
	_ensure_customized()
	customized_stats[stat_name] = clamped
	stats_customized.emit(customized_stats)
	return true


## Reset stats to background defaults.
func reset_stats() -> void:
	if not selected_background_data.is_empty():
		customized_stats = selected_background_data.get("stats", {}).duplicate()
		is_customized = false
		stats_customized.emit(customized_stats)


func _can_modify_stat(stat_name: String, delta: int) -> bool:
	var current := get_current_stats().get(stat_name, 0)
	var new_value := current + delta
	
	# Check bounds
	if new_value < MIN_STAT or new_value > MAX_STAT:
		return false
	
	# Check point budget for increases
	if delta > 0 and get_remaining_stat_points() < delta:
		return false
	
	return true


func _ensure_customized() -> void:
	if not is_customized:
		customized_stats = selected_background_data.get("stats", {}).duplicate()
		is_customized = true

# =============================================================================
# CHARACTER NAME
# =============================================================================

## Set the character's name.
func set_character_name(name: String) -> void:
	character_name = name.strip_edges()
	if character_name.is_empty():
		character_name = "Stranger"


## Get the character's name.
func get_character_name() -> String:
	return character_name

# =============================================================================
# CHARACTER CREATION
# =============================================================================

## Validate current selections before creation.
func validate_character() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Check background selected
	if selected_background.is_empty():
		errors.append("No background selected")
	
	# Check stat points
	var remaining := get_remaining_stat_points()
	if remaining < 0:
		errors.append("Too many stat points used (%d over)" % abs(remaining))
	elif remaining > 0:
		warnings.append("%d stat points unspent" % remaining)
	
	# Check stat bounds
	var stats := get_current_stats()
	for stat_name in stats:
		var value: int = stats[stat_name]
		if value < MIN_STAT:
			errors.append("Stat '%s' is below minimum (%d)" % [stat_name, value])
		elif value > MAX_STAT:
			errors.append("Stat '%s' is above creation maximum (%d)" % [stat_name, value])
	
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}


## Create the character with current selections.
func create_character() -> bool:
	var validation := validate_character()
	if not validation["valid"]:
		creation_failed.emit("Validation failed: " + ", ".join(validation["errors"]))
		return false
	
	# Gather all character data
	var character_data := _build_character_data()
	
	# Apply to game systems
	var success := _apply_to_systems(character_data)
	
	if success:
		character_created.emit(character_data)
		print("CharacterCreator: Character '%s' created successfully" % character_name)
	else:
		creation_failed.emit("Failed to apply character data to game systems")
	
	return success


func _build_character_data() -> Dictionary:
	var bg := selected_background_data
	var stats := get_current_stats()
	
	return {
		"name": character_name,
		"background_id": selected_background,
		"background_name": bg.get("name", "Unknown"),
		"backstory": bg.get("backstory", ""),
		"stats": stats,
		"skills": bg.get("skills", {}),
		"starting_talent": bg.get("starting_talent", ""),
		"equipment": bg.get("equipment", {}),
		"playstyle": bg.get("playstyle", ""),
		"difficulty": bg.get("difficulty", "normal"),
		"tags": bg.get("tags", []),
		"special_flags": bg.get("special_flags", [])
	}


func _apply_to_systems(character_data: Dictionary) -> bool:
	var success := true
	
	# Apply stats
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats:
		player_stats.initialize_from_dict(character_data["stats"])
	else:
		push_warning("CharacterCreator: PlayerStats not found")
		success = false
	
	# Apply skills
	var skill_manager = get_tree().get_first_node_in_group("skill_manager")
	if skill_manager:
		var skills: Dictionary = character_data["skills"]
		for skill_name in skills:
			skill_manager.set_skill_level(skill_name, skills[skill_name])
	else:
		push_warning("CharacterCreator: SkillManager not found")
	
	# Apply starting talent
	var talent_manager = get_tree().get_first_node_in_group("talent_manager")
	var starting_talent: String = character_data["starting_talent"]
	if talent_manager and not starting_talent.is_empty():
		talent_manager.acquire_starting_talent(starting_talent)
	else:
		if not starting_talent.is_empty():
			push_warning("CharacterCreator: TalentManager not found")
	
	# Apply equipment
	var inventory_manager = get_tree().get_first_node_in_group("inventory_manager")
	if inventory_manager:
		var equipment: Dictionary = character_data["equipment"]
		
		# Add weapons
		for weapon_id in equipment.get("weapons", []):
			if inventory_manager.has_method("add_item"):
				inventory_manager.add_item(weapon_id, 1)
		
		# Add armor
		for armor_id in equipment.get("armor", []):
			if inventory_manager.has_method("add_item"):
				inventory_manager.add_item(armor_id, 1)
		
		# Add items
		for item_id in equipment.get("items", []):
			if inventory_manager.has_method("add_item"):
				inventory_manager.add_item(item_id, 1)
		
		# Set money
		var money: int = equipment.get("money", 0)
		if inventory_manager.has_method("set_money"):
			inventory_manager.set_money(money)
		elif inventory_manager.has_method("add_money"):
			inventory_manager.add_money(money)
		
		# Add horse (if any)
		var horse: String = equipment.get("horse", "")
		if not horse.is_empty() and inventory_manager.has_method("set_horse"):
			inventory_manager.set_horse(horse)
	
	# Initialize survival (HP based on Grit)
	var survival_manager = get_tree().get_first_node_in_group("survival_manager")
	if survival_manager and survival_manager.has_method("initialize_hp"):
		survival_manager.initialize_hp()
	
	# Apply special flags
	var special_flags: Array = character_data.get("special_flags", [])
	if not special_flags.is_empty():
		_apply_special_flags(special_flags)
	
	return success


func _apply_special_flags(flags: Array) -> void:
	var effect_manager = get_tree().get_first_node_in_group("effect_manager")
	
	for flag in flags:
		match flag:
			"wanted_by_law":
				# Could apply a "wanted" status or set faction reputation
				print("CharacterCreator: Character is wanted by the law")
				# Example: effect_manager.apply_effect("player", "wanted_status", "background")
			_:
				print("CharacterCreator: Unknown special flag '%s'" % flag)

# =============================================================================
# PREVIEW
# =============================================================================

## Get a preview of what the character will look like.
func get_character_preview() -> Dictionary:
	if selected_background.is_empty():
		return {}
	
	var character_data := _build_character_data()
	
	# Add derived stats preview
	var stats: Dictionary = character_data["stats"]
	var grit: int = stats.get("grit", 3)
	var reflex: int = stats.get("reflex", 3)
	var spirit: int = stats.get("spirit", 3)
	var wit: int = stats.get("wit", 3)
	var charm: int = stats.get("charm", 3)
	
	character_data["derived"] = {
		"max_hp": 10 + grit * 2,
		"initiative_bonus": reflex,
		"fear_threshold": 5 + spirit,
		"skill_xp_multiplier": 1.0 + (wit - 3) * 0.05,
		"price_modifier": 1.0 - (charm - 3) * 0.05
	}
	
	# Get talent info
	var effect_manager = get_tree().get_first_node_in_group("effect_manager")
	if effect_manager and not character_data["starting_talent"].is_empty():
		var talent_def := effect_manager.get_effect_definition(character_data["starting_talent"])
		character_data["talent_info"] = {
			"name": talent_def.get("name", character_data["starting_talent"]),
			"description": talent_def.get("description", "")
		}
	
	return character_data

# =============================================================================
# SERIALIZATION
# =============================================================================

## Save character creation state (for multi-screen creation flow).
func to_dict() -> Dictionary:
	return {
		"selected_background": selected_background,
		"customized_stats": customized_stats.duplicate(),
		"is_customized": is_customized,
		"character_name": character_name
	}


## Load character creation state.
func from_dict(data: Dictionary) -> void:
	if data.has("selected_background") and not data["selected_background"].is_empty():
		select_background(data["selected_background"])
	
	if data.has("customized_stats"):
		customized_stats = data["customized_stats"].duplicate()
	
	if data.has("is_customized"):
		is_customized = data["is_customized"]
	
	if data.has("character_name"):
		character_name = data["character_name"]

# =============================================================================
# DEBUG
# =============================================================================

## Print all backgrounds.
func debug_list_backgrounds() -> void:
	print("=== Available Backgrounds ===")
	for bg in get_all_backgrounds():
		print("  [%s] %s - %s" % [bg["difficulty"], bg["name"], bg["description"]])


## Print current character preview.
func debug_print_preview() -> void:
	var preview := get_character_preview()
	if preview.is_empty():
		print("No background selected")
		return
	
	print("=== Character Preview ===")
	print("Name: %s" % preview.get("name", "Unknown"))
	print("Background: %s" % preview.get("background_name", "Unknown"))
	print("Difficulty: %s" % preview.get("difficulty", "normal"))
	print("")
	print("--- Stats ---")
	var stats: Dictionary = preview.get("stats", {})
	for stat_name in stats:
		print("  %s: %d" % [stat_name.capitalize(), stats[stat_name]])
	print("")
	print("--- Derived ---")
	var derived: Dictionary = preview.get("derived", {})
	for key in derived:
		print("  %s: %s" % [key, derived[key]])
	print("")
	print("--- Skills ---")
	var skills: Dictionary = preview.get("skills", {})
	for skill_name in skills:
		print("  %s: %d" % [skill_name.capitalize(), skills[skill_name]])
	print("")
	print("Starting Talent: %s" % preview.get("talent_info", {}).get("name", "None"))
	print("Money: $%d" % preview.get("equipment", {}).get("money", 0))


## Quick create with defaults (debug).
func debug_quick_create(background_id: String) -> void:
	select_background(background_id)
	set_character_name("Debug Character")
	create_character()
