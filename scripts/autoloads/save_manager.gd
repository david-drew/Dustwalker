# save_manager.gd
# Manages game saves with a profile-based system.
# Each profile represents one character's playthrough with unlimited named saves.
#
# Structure:
#   user://saves/profiles/
#     {profile_name}/
#       profile.json    - Character metadata (name, background, portrait, timestamps)
#       map.json        - Map state (terrain, locations, rivers)
#       saves/
#         autosave.json - Auto-generated on camp
#         {save_name}.json - Manual saves
#
# DEPENDENCIES:
# - All game systems with to_dict()/from_dict() methods

extends Node
#class_name SaveManager

# =============================================================================
# SIGNALS
# =============================================================================

signal profile_created(profile_name: String)
signal profile_deleted(profile_name: String)
signal profile_loaded(profile_name: String)
signal save_created(profile_name: String, save_name: String)
signal save_deleted(profile_name: String, save_name: String)
signal game_saved(profile_name: String, save_name: String)
signal game_loaded(profile_name: String, save_name: String)
signal save_error(message: String)
signal load_error(message: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const SAVE_VERSION := "1.0"
const PROFILES_DIRECTORY := "user://saves/profiles/"
const PROFILE_FILE := "profile.json"
const MAP_FILE := "map.json"
const SAVES_SUBDIRECTORY := "saves/"
const AUTOSAVE_NAME := "autosave"

# =============================================================================
# STATE
# =============================================================================

## Currently active profile name
var current_profile: String = ""

## Cached profile data for the active profile
var current_profile_data: Dictionary = {}

## Last used profile (persisted across sessions)
var last_profile: String = ""

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("save_manager")
	_ensure_directories()
	_load_settings()
	print("SaveManager: Initialized")


func _ensure_directories() -> void:
	if not DirAccess.dir_exists_absolute(PROFILES_DIRECTORY):
		DirAccess.make_dir_recursive_absolute(PROFILES_DIRECTORY)

func _load_settings() -> void:
	var settings_path := "user://saves/settings.json"
	if FileAccess.file_exists(settings_path):
		var file := FileAccess.open(settings_path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data: Dictionary = json.data
				last_profile = data.get("last_profile", "")
			file.close()


func _save_settings() -> void:
	var settings_path := "user://saves/settings.json"
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		var data := {"last_profile": last_profile}
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

# =============================================================================
# PROFILE MANAGEMENT
# =============================================================================

## Get list of all profile names
func get_profiles() -> Array[String]:
	var profiles: Array[String] = []

	var dir := DirAccess.open(PROFILES_DIRECTORY)
	if dir:
		dir.list_dir_begin()
		var folder_name := dir.get_next()
		while folder_name != "":
			if dir.current_is_dir() and not folder_name.begins_with("."):
				# Verify it has a profile.json
				var profile_path := PROFILES_DIRECTORY + folder_name + "/" + PROFILE_FILE
				if FileAccess.file_exists(profile_path):
					profiles.append(folder_name)
			folder_name = dir.get_next()
		dir.list_dir_end()

	return profiles


## Get profile metadata without loading the full profile
func get_profile_info(profile_name: String) -> Dictionary:
	var profile_path := PROFILES_DIRECTORY + profile_name + "/" + PROFILE_FILE

	if not FileAccess.file_exists(profile_path):
		return {}

	var file := FileAccess.open(profile_path, FileAccess.READ)
	if not file:
		return {}

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}

	file.close()
	return json.data


## Create a new profile for a character
func create_profile(character_name: String, background: String, portrait: String = "") -> bool:
	# Sanitize profile folder name
	var folder_name := _sanitize_filename(character_name)

	# Ensure unique folder name
	var base_name := folder_name
	var counter := 1
	while DirAccess.dir_exists_absolute(PROFILES_DIRECTORY + folder_name):
		folder_name = "%s_%d" % [base_name, counter]
		counter += 1

	var profile_dir := PROFILES_DIRECTORY + folder_name + "/"
	var saves_dir := profile_dir + SAVES_SUBDIRECTORY

	# Create directories
	if DirAccess.make_dir_recursive_absolute(saves_dir) != OK:
		save_error.emit("Failed to create profile directory")
		return false

	# Create profile.json
	var profile_data := {
		"version": SAVE_VERSION,
		"character_name": character_name,
		"folder_name": folder_name,
		"background": background,
		"portrait": portrait,
		"created_at": Time.get_datetime_string_from_system(),
		"last_played": Time.get_datetime_string_from_system(),
		"total_playtime_seconds": 0
	}

	var profile_path := profile_dir + PROFILE_FILE
	var file := FileAccess.open(profile_path, FileAccess.WRITE)
	if not file:
		save_error.emit("Failed to create profile file")
		return false

	file.store_string(JSON.stringify(profile_data, "\t"))
	file.close()

	current_profile = folder_name
	current_profile_data = profile_data
	last_profile = folder_name
	_save_settings()

	profile_created.emit(folder_name)
	print("SaveManager: Created profile '%s'" % folder_name)
	return true


## Delete a profile and all its saves
func delete_profile(profile_name: String) -> bool:
	var profile_dir := PROFILES_DIRECTORY + profile_name + "/"

	if not DirAccess.dir_exists_absolute(profile_dir):
		save_error.emit("Profile does not exist")
		return false

	# Delete all files in saves subdirectory
	var saves_dir := profile_dir + SAVES_SUBDIRECTORY
	if DirAccess.dir_exists_absolute(saves_dir):
		var dir := DirAccess.open(saves_dir)
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(saves_dir)

	# Delete profile files
	var dir := DirAccess.open(profile_dir)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	# Delete profile directory
	DirAccess.remove_absolute(profile_dir)

	if current_profile == profile_name:
		current_profile = ""
		current_profile_data = {}

	if last_profile == profile_name:
		last_profile = ""
		_save_settings()

	profile_deleted.emit(profile_name)
	print("SaveManager: Deleted profile '%s'" % profile_name)
	return true


## Set the active profile
func set_current_profile(profile_name: String) -> bool:
	var profile_data := get_profile_info(profile_name)
	if profile_data.is_empty():
		load_error.emit("Profile not found: " + profile_name)
		return false

	current_profile = profile_name
	current_profile_data = profile_data
	last_profile = profile_name
	_save_settings()

	profile_loaded.emit(profile_name)
	return true

# =============================================================================
# SAVE MANAGEMENT
# =============================================================================

## Get list of saves for a profile
func get_saves(profile_name: String = "") -> Array[Dictionary]:
	if profile_name.is_empty():
		profile_name = current_profile

	if profile_name.is_empty():
		return []

	var saves: Array[Dictionary] = []
	var saves_dir := PROFILES_DIRECTORY + profile_name + "/" + SAVES_SUBDIRECTORY

	if not DirAccess.dir_exists_absolute(saves_dir):
		return saves

	var dir := DirAccess.open(saves_dir)
	if not dir:
		return saves

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var save_path := saves_dir + file_name
			var save_info := _get_save_info(save_path)
			if not save_info.is_empty():
				save_info["file_name"] = file_name.trim_suffix(".json")
				save_info["file_path"] = save_path
				saves.append(save_info)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by timestamp, newest first
	saves.sort_custom(func(a, b): return a.get("saved_at", "") > b.get("saved_at", ""))

	return saves


func _get_save_info(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}

	file.close()
	var data: Dictionary = json.data

	# Return just metadata, not full save data
	return {
		"save_name": data.get("save_name", "Unknown"),
		"saved_at": data.get("saved_at", ""),
		"day": data.get("time", {}).get("day", 1),
		"turn": data.get("time", {}).get("turn", 1),
		"location": data.get("player", {}).get("current_location", "Unknown"),
		"playtime_seconds": data.get("playtime_seconds", 0)
	}


## Get the most recent save for a profile
func get_latest_save(profile_name: String = "") -> Dictionary:
	var saves := get_saves(profile_name)
	if saves.is_empty():
		return {}
	return saves[0]


## Check if a save name already exists
func save_exists(save_name: String, profile_name: String = "") -> bool:
	if profile_name.is_empty():
		profile_name = current_profile

	var save_path := PROFILES_DIRECTORY + profile_name + "/" + SAVES_SUBDIRECTORY + save_name + ".json"
	return FileAccess.file_exists(save_path)


## Delete a save
func delete_save(save_name: String, profile_name: String = "") -> bool:
	if profile_name.is_empty():
		profile_name = current_profile

	var save_path := PROFILES_DIRECTORY + profile_name + "/" + SAVES_SUBDIRECTORY + save_name + ".json"

	if not FileAccess.file_exists(save_path):
		save_error.emit("Save not found: " + save_name)
		return false

	var dir := DirAccess.open(PROFILES_DIRECTORY + profile_name + "/" + SAVES_SUBDIRECTORY)
	if dir:
		dir.remove(save_name + ".json")
		save_deleted.emit(profile_name, save_name)
		print("SaveManager: Deleted save '%s' from profile '%s'" % [save_name, profile_name])
		return true

	return false

# =============================================================================
# SAVE GAME
# =============================================================================

## Save the current game state
func save_game(save_name: String, is_autosave: bool = false) -> bool:
	if current_profile.is_empty():
		save_error.emit("No active profile")
		return false

	var sanitized_name := _sanitize_filename(save_name) if not is_autosave else AUTOSAVE_NAME
	var save_path := PROFILES_DIRECTORY + current_profile + "/" + SAVES_SUBDIRECTORY + sanitized_name + ".json"

	# Gather all game state
	var save_data := _gather_save_data(save_name)
	if save_data.is_empty():
		save_error.emit("Failed to gather save data")
		return false

	# Write save file
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		save_error.emit("Failed to write save file")
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	# Update profile last played
	_update_profile_timestamp()

	# Save map if it hasn't been saved yet
	_save_map_if_needed()

	game_saved.emit(current_profile, sanitized_name)
	save_created.emit(current_profile, sanitized_name)
	print("SaveManager: Saved game '%s' to profile '%s'" % [sanitized_name, current_profile])
	return true


## Autosave (called when entering camp)
func autosave() -> bool:
	return save_game(AUTOSAVE_NAME, true)


func _gather_save_data(save_name: String) -> Dictionary:
	var save_data := {
		"version": SAVE_VERSION,
		"save_name": save_name,
		"saved_at": Time.get_datetime_string_from_system(),
		"playtime_seconds": current_profile_data.get("total_playtime_seconds", 0)
	}

	# Time Manager
	var time_manager := get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("to_dict"):
		save_data["time"] = time_manager.to_dict()

	# Effect Manager
	var effect_manager := get_node_or_null("/root/EffectManager")
	if effect_manager and effect_manager.has_method("to_dict"):
		save_data["effects"] = effect_manager.to_dict()

	# Player
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("to_dict"):
		save_data["player"] = player.to_dict()

	# Player Stats
	var player_stats := get_tree().get_first_node_in_group("player_stats")
	if player_stats and player_stats.has_method("to_dict"):
		save_data["player_stats"] = player_stats.to_dict()

	# Skill Manager
	var skill_manager := get_tree().get_first_node_in_group("skill_manager")
	if skill_manager and skill_manager.has_method("to_dict"):
		save_data["skills"] = skill_manager.to_dict()

	# Talent Manager
	var talent_manager := get_tree().get_first_node_in_group("talent_manager")
	if talent_manager and talent_manager.has_method("to_dict"):
		save_data["talents"] = talent_manager.to_dict()

	# Survival Manager
	var survival_manager := get_tree().get_first_node_in_group("survival_manager")
	if survival_manager and survival_manager.has_method("to_dict"):
		save_data["survival"] = survival_manager.to_dict()

	# Weather Manager
	var weather_manager := get_tree().get_first_node_in_group("weather_manager")
	if weather_manager and weather_manager.has_method("to_dict"):
		save_data["weather"] = weather_manager.to_dict()

	# Disease Manager
	var disease_manager := get_tree().get_first_node_in_group("disease_manager")
	if disease_manager and disease_manager.has_method("to_dict"):
		save_data["diseases"] = disease_manager.to_dict()

	# Inventory Manager
	var inventory_manager := get_tree().get_first_node_in_group("inventory_manager")
	if inventory_manager and inventory_manager.has_method("to_dict"):
		save_data["inventory"] = inventory_manager.to_dict()

	# Encounter Manager
	var encounter_manager := get_tree().get_first_node_in_group("encounter_manager")
	if encounter_manager and encounter_manager.has_method("to_dict"):
		save_data["encounters"] = encounter_manager.to_dict()

	# Fog of War Manager
	var fog_manager := get_tree().get_first_node_in_group("fog_of_war_manager")
	if fog_manager and fog_manager.has_method("to_dict"):
		save_data["fog_of_war"] = fog_manager.to_dict()

	# NPC Manager
	var npc_manager := get_tree().get_first_node_in_group("npc_manager")
	if npc_manager and npc_manager.has_method("to_dict"):
		save_data["npcs"] = npc_manager.to_dict()

	# Shop Manager
	var shop_manager := get_tree().get_first_node_in_group("shop_manager")
	if shop_manager and shop_manager.has_method("to_dict"):
		save_data["shops"] = shop_manager.to_dict()

	return save_data


func _save_map_if_needed() -> void:
	var map_path := PROFILES_DIRECTORY + current_profile + "/" + MAP_FILE

	# Only save map if it doesn't exist yet
	if FileAccess.file_exists(map_path):
		return

	var hex_grid := get_tree().get_first_node_in_group("hex_grid")
	var river_generator := get_tree().get_first_node_in_group("river_generator")
	var location_placer := get_tree().get_first_node_in_group("location_placer")

	if not hex_grid:
		return

	var map_data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system()
	}

	# Serialize hex grid
	if hex_grid.has_method("to_dict"):
		map_data["hex_grid"] = hex_grid.to_dict()
	else:
		# Manual hex serialization
		map_data["hex_grid"] = _serialize_hex_grid(hex_grid)

	# Serialize rivers
	if river_generator and river_generator.has_method("to_dict"):
		map_data["rivers"] = river_generator.to_dict()

	# Serialize locations
	if location_placer and location_placer.has_method("to_dict"):
		map_data["locations"] = location_placer.to_dict()

	var file := FileAccess.open(map_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(map_data, "\t"))
		file.close()
		print("SaveManager: Saved map for profile '%s'" % current_profile)


func _serialize_hex_grid(hex_grid: Node) -> Dictionary:
	var data := {
		"width": hex_grid.grid_width if "grid_width" in hex_grid else 0,
		"height": hex_grid.grid_height if "grid_height" in hex_grid else 0,
		"cells": []
	}

	if hex_grid.has_method("get_all_cells"):
		for cell in hex_grid.get_all_cells():
			data["cells"].append({
				"q": cell.hex_coords.x,
				"r": cell.hex_coords.y,
				"terrain": cell.terrain_type if "terrain_type" in cell else "plains",
				"elevation": cell.elevation if "elevation" in cell else 0
			})

	return data


func _update_profile_timestamp() -> void:
	var profile_path := PROFILES_DIRECTORY + current_profile + "/" + PROFILE_FILE
	current_profile_data["last_played"] = Time.get_datetime_string_from_system()

	var file := FileAccess.open(profile_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_profile_data, "\t"))
		file.close()

# =============================================================================
# LOAD GAME
# =============================================================================

## Load a saved game
func load_game(save_name: String, profile_name: String = "") -> bool:
	if profile_name.is_empty():
		profile_name = current_profile

	if profile_name.is_empty():
		load_error.emit("No profile specified")
		return false

	var save_path := PROFILES_DIRECTORY + profile_name + "/" + SAVES_SUBDIRECTORY + save_name + ".json"

	if not FileAccess.file_exists(save_path):
		load_error.emit("Save not found: " + save_name)
		return false

	# Load save data
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		load_error.emit("Failed to open save file")
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		load_error.emit("Failed to parse save file")
		return false

	file.close()
	var save_data: Dictionary = json.data

	# Set current profile
	if not set_current_profile(profile_name):
		return false

	# Apply save data to all systems
	if not _apply_save_data(save_data):
		load_error.emit("Failed to apply save data")
		return false

	game_loaded.emit(profile_name, save_name)
	print("SaveManager: Loaded game '%s' from profile '%s'" % [save_name, profile_name])
	return true


## Load the most recent save for a profile
func load_latest(profile_name: String = "") -> bool:
	var latest := get_latest_save(profile_name)
	if latest.is_empty():
		load_error.emit("No saves found")
		return false

	return load_game(latest["file_name"], profile_name)


## Continue from last played profile
func continue_game() -> bool:
	if last_profile.is_empty():
		load_error.emit("No previous profile found")
		return false

	return load_latest(last_profile)


func _apply_save_data(save_data: Dictionary) -> bool:
	# Load map first (if not already loaded)
	_load_map_if_needed()

	# Time Manager
	var time_manager := get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("from_dict") and save_data.has("time"):
		time_manager.from_dict(save_data["time"])

	# Effect Manager (load before other systems so modifiers are ready)
	var effect_manager := get_node_or_null("/root/EffectManager")
	if effect_manager and effect_manager.has_method("from_dict") and save_data.has("effects"):
		effect_manager.from_dict(save_data["effects"])

	# Player Stats
	var player_stats := get_tree().get_first_node_in_group("player_stats")
	if player_stats and player_stats.has_method("from_dict") and save_data.has("player_stats"):
		player_stats.from_dict(save_data["player_stats"])

	# Skill Manager
	var skill_manager := get_tree().get_first_node_in_group("skill_manager")
	if skill_manager and skill_manager.has_method("from_dict") and save_data.has("skills"):
		skill_manager.from_dict(save_data["skills"])

	# Talent Manager
	var talent_manager := get_tree().get_first_node_in_group("talent_manager")
	if talent_manager and talent_manager.has_method("from_dict") and save_data.has("talents"):
		talent_manager.from_dict(save_data["talents"])

	# Survival Manager
	var survival_manager := get_tree().get_first_node_in_group("survival_manager")
	if survival_manager and survival_manager.has_method("from_dict") and save_data.has("survival"):
		survival_manager.from_dict(save_data["survival"])

	# Weather Manager
	var weather_manager := get_tree().get_first_node_in_group("weather_manager")
	if weather_manager and weather_manager.has_method("from_dict") and save_data.has("weather"):
		weather_manager.from_dict(save_data["weather"])

	# Disease Manager
	var disease_manager := get_tree().get_first_node_in_group("disease_manager")
	if disease_manager and disease_manager.has_method("from_dict") and save_data.has("diseases"):
		disease_manager.from_dict(save_data["diseases"])

	# Inventory Manager
	var inventory_manager := get_tree().get_first_node_in_group("inventory_manager")
	if inventory_manager and inventory_manager.has_method("from_dict") and save_data.has("inventory"):
		inventory_manager.from_dict(save_data["inventory"])

	# Encounter Manager
	var encounter_manager := get_tree().get_first_node_in_group("encounter_manager")
	if encounter_manager and encounter_manager.has_method("from_dict") and save_data.has("encounters"):
		encounter_manager.from_dict(save_data["encounters"])

	# Fog of War Manager
	var fog_manager := get_tree().get_first_node_in_group("fog_of_war_manager")
	if fog_manager and fog_manager.has_method("from_dict") and save_data.has("fog_of_war"):
		fog_manager.from_dict(save_data["fog_of_war"])

	# NPC Manager
	var npc_manager := get_tree().get_first_node_in_group("npc_manager")
	if npc_manager and npc_manager.has_method("from_dict") and save_data.has("npcs"):
		npc_manager.from_dict(save_data["npcs"])

	# Shop Manager
	var shop_manager := get_tree().get_first_node_in_group("shop_manager")
	if shop_manager and shop_manager.has_method("from_dict") and save_data.has("shops"):
		shop_manager.from_dict(save_data["shops"])

	# Player (load last so position is set after map is ready)
	var player := get_tree().get_first_node_in_group("player")
	var hex_grid := get_tree().get_first_node_in_group("hex_grid")
	if player and player.has_method("from_dict") and save_data.has("player") and hex_grid:
		player.from_dict(save_data["player"], hex_grid)

	return true


func _load_map_if_needed() -> void:
	var map_path := PROFILES_DIRECTORY + current_profile + "/" + MAP_FILE

	if not FileAccess.file_exists(map_path):
		return

	var file := FileAccess.open(map_path, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return

	file.close()
	var map_data: Dictionary = json.data

	var hex_grid := get_tree().get_first_node_in_group("hex_grid")
	var river_generator := get_tree().get_first_node_in_group("river_generator")
	var location_placer := get_tree().get_first_node_in_group("location_placer")

	# Load hex grid
	if hex_grid and hex_grid.has_method("from_dict") and map_data.has("hex_grid"):
		hex_grid.from_dict(map_data["hex_grid"])

	# Load rivers
	if river_generator and river_generator.has_method("from_dict") and map_data.has("rivers"):
		river_generator.from_dict(map_data["rivers"], hex_grid)

	# Load locations
	if location_placer and location_placer.has_method("from_dict") and map_data.has("locations"):
		location_placer.from_dict(map_data["locations"])

	print("SaveManager: Loaded map for profile '%s'" % current_profile)

# =============================================================================
# UTILITY
# =============================================================================

func _sanitize_filename(name: String) -> String:
	# Remove or replace invalid filename characters
	var sanitized := name.to_lower()
	sanitized = sanitized.replace(" ", "_")
	sanitized = sanitized.replace("/", "_")
	sanitized = sanitized.replace("\\", "_")
	sanitized = sanitized.replace(":", "_")
	sanitized = sanitized.replace("*", "_")
	sanitized = sanitized.replace("?", "_")
	sanitized = sanitized.replace("\"", "_")
	sanitized = sanitized.replace("<", "_")
	sanitized = sanitized.replace(">", "_")
	sanitized = sanitized.replace("|", "_")

	# Ensure not empty
	if sanitized.is_empty():
		sanitized = "unnamed"

	# Limit length
	if sanitized.length() > 50:
		sanitized = sanitized.substr(0, 50)

	return sanitized


## Check if there's a profile that can be continued
func has_continue_data() -> bool:
	if last_profile.is_empty():
		return false

	var saves := get_saves(last_profile)
	return not saves.is_empty()


## Get info about what "Continue" would load
func get_continue_info() -> Dictionary:
	if not has_continue_data():
		return {}

	var profile_info := get_profile_info(last_profile)
	var latest_save := get_latest_save(last_profile)

	return {
		"profile_name": last_profile,
		"character_name": profile_info.get("character_name", "Unknown"),
		"background": profile_info.get("background", ""),
		"save_name": latest_save.get("save_name", ""),
		"day": latest_save.get("day", 1),
		"saved_at": latest_save.get("saved_at", "")
	}
