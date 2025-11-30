# data_loader.gd
# Handles loading and caching of JSON data files for game configuration.
# Add this as an autoload named "DataLoader" in Project Settings.
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

const DATA_BASE_PATH := "res://data/"
const MAPS_PATH := DATA_BASE_PATH + "maps/"
const REGIONS_PATH := DATA_BASE_PATH + "regions/"
const ACTORS_PATH := DATA_BASE_PATH + "actors/"
const COMBAT_PATH := DATA_BASE_PATH + "combat/"

# =============================================================================
# CACHED DATA
# =============================================================================

# Cache for loaded data to avoid repeated file reads.
var _cache: Dictionary = {}

# =============================================================================
# PUBLIC API
# =============================================================================

## Loads a JSON file and returns its contents as a Dictionary.
## Results are cached for subsequent calls.
## @param file_path: String - Full path to the JSON file.
## @return Dictionary - Parsed JSON data, or empty dict on failure.
func load_json(file_path: String) -> Dictionary:
	# Return cached data if available
	if _cache.has(file_path):
		return _cache[file_path]
	
	# Attempt to load the file
	if not FileAccess.file_exists(file_path):
		push_error("DataLoader: File not found: %s" % file_path)
		return {}
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: Failed to open file: %s (Error: %s)" % [file_path, FileAccess.get_open_error()])
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	# Parse the JSON
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		push_error("DataLoader: JSON parse error in %s at line %d: %s" % [
			file_path, json.get_error_line(), json.get_error_message()
		])
		return {}
	
	var data: Dictionary = json.data
	_cache[file_path] = data
	return data


## Loads map configuration data.
## @param map_name: String - Name of the map (without .json extension).
## @return Dictionary - Map configuration data.
func load_map_config(map_name: String) -> Dictionary:
	var path := MAPS_PATH + map_name + ".json"
	return load_json(path)


## Loads region data for procedural generation.
## @param region_name: String - Name of the region.
## @return Dictionary - Region configuration data.
func load_region(region_name: String) -> Dictionary:
	var path := REGIONS_PATH + region_name + ".json"
	return load_json(path)


## Loads actor data (players, enemies, NPCs).
## @param actor_name: String - Name of the actor.
## @return Dictionary - Actor configuration data.
func load_actor(actor_name: String) -> Dictionary:
	var path := ACTORS_PATH + actor_name + ".json"
	return load_json(path)


## Loads combat configuration data.
## @param config_name: String - Name of the combat config.
## @return Dictionary - Combat configuration data.
func load_combat_config(config_name: String) -> Dictionary:
	var path := COMBAT_PATH + config_name + ".json"
	return load_json(path)


## Clears the data cache. Useful for hot-reloading during development.
func clear_cache() -> void:
	_cache.clear()
	print("DataLoader: Cache cleared")


## Clears a specific file from the cache.
## @param file_path: String - Path to remove from cache.
func clear_cache_entry(file_path: String) -> void:
	_cache.erase(file_path)


## Reloads a specific file, bypassing the cache.
## @param file_path: String - Path to reload.
## @return Dictionary - Fresh data from file.
func reload_json(file_path: String) -> Dictionary:
	clear_cache_entry(file_path)
	return load_json(file_path)


## Checks if a data file exists.
## @param file_path: String - Path to check.
## @return bool - True if file exists.
func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)


## Gets default map configuration if no file is found.
## @return Dictionary - Default configuration values.
func get_default_map_config() -> Dictionary:
	return {
		"map_name": "default",
		"map_size": {"width": 30, "height": 30},
		"hex_size": 64,
		"default_terrain": "grass",
		"terrain_types": {
			"grass": {
				"color": "#4a7c59",
				"movement_cost": 1.0,
				"passable": true
			},
			"water": {
				"color": "#4a7c9d",
				"movement_cost": 2.0,
				"passable": true
			},
			"deep_water": {
				"color": "#2a5c7d",
				"movement_cost": -1.0,
				"passable": false
			},
			"mountain": {
				"color": "#6b5b4f",
				"movement_cost": 3.0,
				"passable": true
			},
			"mountain_peak": {
				"color": "#8b7b6f",
				"movement_cost": -1.0,
				"passable": false
			},
			"desert": {
				"color": "#d4a76a",
				"movement_cost": 1.5,
				"passable": true
			},
			"forest": {
				"color": "#2d5a3d",
				"movement_cost": 1.5,
				"passable": true
			},
			"snow": {
				"color": "#e8e8e8",
				"movement_cost": 2.0,
				"passable": true
			}
		}
	}
