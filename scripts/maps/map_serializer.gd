# map_serializer.gd
# Handles saving and loading complete map state to/from JSON files.
# Includes all hex data, rivers, locations, and generation parameters.
#
# Save location: user://saves/maps/
# File format: JSON with version header for future compatibility

class_name MapSerializer
extends RefCounted

# =============================================================================
# CONSTANTS
# =============================================================================

const SAVE_VERSION := "1.0"
const SAVE_DIRECTORY := "user://saves/maps/"

# =============================================================================
# SIGNALS
# =============================================================================

signal map_saved(file_path: String)
signal map_loaded(file_path: String, generation_seed: int)
signal save_error(message: String)
signal load_error(message: String)

# =============================================================================
# SAVE FUNCTIONALITY
# =============================================================================

## Saves the complete map state to a JSON file.
## @param hex_grid: HexGrid - The grid to save.
## @param river_generator: RiverGenerator - River data.
## @param location_placer: LocationPlacer - Location data.
## @param generation_seed: int - The seed used to generate this map.
## @param filename: String - Optional custom filename (without extension).
## @return String - Full path to saved file, or empty string on failure.
func save_map(
	hex_grid: HexGrid,
	river_generator: RiverGenerator,
	location_placer: LocationPlacer,
	generation_seed: int,
	filename: String = ""
) -> String:
	# Ensure save directory exists
	_ensure_save_directory()
	
	# Generate filename if not provided
	if filename.is_empty():
		var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
		filename = "map_%d_%s" % [generation_seed, timestamp]
	
	# Remove extension if provided
	if filename.ends_with(".json"):
		filename = filename.substr(0, filename.length() - 5)
	
	var file_path := SAVE_DIRECTORY + filename + ".json"
	
	# Build save data
	var save_data := _build_save_data(hex_grid, river_generator, location_placer, generation_seed)
	
	# Write to file
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var error_msg := "Failed to open file for writing: %s (Error: %s)" % [file_path, FileAccess.get_open_error()]
		push_error("MapSerializer: " + error_msg)
		save_error.emit(error_msg)
		_emit_to_event_bus("map_save_failed", [error_msg])
		return ""
	
	var json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("MapSerializer: Saved map to %s" % file_path)
	map_saved.emit(file_path)
	_emit_to_event_bus("map_saved", [file_path])
	
	return file_path


func _build_save_data(
	hex_grid: HexGrid,
	river_generator: RiverGenerator,
	location_placer: LocationPlacer,
	generation_seed: int
) -> Dictionary:
	var save_data := {
		"version": SAVE_VERSION,
		"generation_seed": generation_seed,
		"timestamp": Time.get_datetime_string_from_system(),
		"map_size": {
			"width": hex_grid.map_width,
			"height": hex_grid.map_height
		},
		"hex_size": hex_grid.hex_size,
		"generation_params": _get_generation_params(hex_grid),
		"hexes": _serialize_hexes(hex_grid),
		"rivers": river_generator.to_dict() if river_generator else [],
		"locations": location_placer.to_array() if location_placer else [],
		"time_data": _serialize_time_data(),
		"player_data": _serialize_player_data(hex_grid),
		"fog_of_war": _serialize_fog_data(),
		"survival": _serialize_survival_data(),
		"inventory": _serialize_inventory_data()
	}
	
	return save_data


func _serialize_time_data() -> Dictionary:
	var time_manager = Engine.get_main_loop().root.get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("to_dict"):
		return time_manager.to_dict()
	return {
		"current_turn": 3,
		"current_day": 1,
		"total_turns_elapsed": 0
	}


func _serialize_fog_data() -> Dictionary:
	var main_loop = Engine.get_main_loop()
	if main_loop:
		var tree: SceneTree = main_loop as SceneTree
		if tree:
			var fog_manager = tree.get_first_node_in_group("fog_manager")
			if fog_manager and fog_manager.has_method("to_dict"):
				return fog_manager.to_dict()
	
	return {"explored_hexes": []}


func _serialize_survival_data() -> Dictionary:
	var main_loop = Engine.get_main_loop()
	if main_loop:
		var tree: SceneTree = main_loop as SceneTree
		if tree:
			var survival_manager = tree.get_first_node_in_group("survival_manager")
			if survival_manager and survival_manager.has_method("to_dict"):
				return survival_manager.to_dict()
	
	return {}


func _serialize_inventory_data() -> Dictionary:
	var main_loop = Engine.get_main_loop()
	if main_loop:
		var tree: SceneTree = main_loop as SceneTree
		if tree:
			var inventory_manager = tree.get_first_node_in_group("inventory_manager")
			if inventory_manager and inventory_manager.has_method("to_dict"):
				return inventory_manager.to_dict()
	
	return {}


func _serialize_player_data(hex_grid: HexGrid) -> Dictionary:
	# Find player in scene tree
	var player: Player = null
	var main_loop = Engine.get_main_loop()
	if main_loop:
		var tree: SceneTree = main_loop as SceneTree
		if tree and tree.root:
			# Look for player in the scene
			var spawner = tree.get_first_node_in_group("player_spawner")
			if spawner and spawner.has_method("get_player"):
				player = spawner.get_player()
	
	if player and player.has_method("to_dict"):
		return player.to_dict()
	
	# Default player data
	return {
		"name": "Wanderer",
		"current_hex": {"q": 0, "r": 0},
		"stats": {},
		"inventory": [],
		"status_effects": []
	}


func _get_generation_params(hex_grid: HexGrid) -> Dictionary:
	# Get generation parameters from the terrain generator if available
	var generator := hex_grid.get_terrain_generator()
	if generator == null:
		return {}
	
	return generator.generation_params


func _serialize_hexes(hex_grid: HexGrid) -> Array[Dictionary]:
	var hexes: Array[Dictionary] = []
	
	for coords in hex_grid.cells:
		var cell: HexCell = hex_grid.cells[coords]
		
		var hex_data := {
			"coords": {"q": coords.x, "r": coords.y},
			"elevation": snappedf(cell.elevation, 0.001),  # Reduce precision for smaller files
			"moisture": snappedf(cell.moisture, 0.001),
			"terrain_type": cell.terrain_type,
			"has_river": cell.has_river
		}
		
		# Only include river direction if there's a river
		if cell.has_river and cell.river_flow_direction != Vector2i.ZERO:
			hex_data["river_flow"] = {
				"q": cell.river_flow_direction.x,
				"r": cell.river_flow_direction.y
			}
		
		hexes.append(hex_data)
	
	return hexes

# =============================================================================
# LOAD FUNCTIONALITY
# =============================================================================

## Loads a map from a JSON file.
## @param file_path: String - Full path to the save file.
## @param hex_grid: HexGrid - The grid to load into.
## @param river_generator: RiverGenerator - River generator to populate.
## @param location_placer: LocationPlacer - Location placer to populate.
## @return int - The generation seed of the loaded map, or -1 on failure.
func load_map(
	file_path: String,
	hex_grid: HexGrid,
	river_generator: RiverGenerator,
	location_placer: LocationPlacer
) -> int:
	# Add directory prefix if not present
	if not file_path.begins_with("user://") and not file_path.begins_with("res://"):
		file_path = SAVE_DIRECTORY + file_path
	
	# Add extension if not present
	if not file_path.ends_with(".json"):
		file_path += ".json"
	
	# Check file exists
	if not FileAccess.file_exists(file_path):
		var error_msg := "Save file not found: %s" % file_path
		push_error("MapSerializer: " + error_msg)
		load_error.emit(error_msg)
		_emit_to_event_bus("map_load_failed", [error_msg])
		return -1
	
	# Read file
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var error_msg := "Failed to open file: %s (Error: %s)" % [file_path, FileAccess.get_open_error()]
		push_error("MapSerializer: " + error_msg)
		load_error.emit(error_msg)
		return -1
	
	var json_string := file.get_as_text()
	file.close()
	
	# Parse JSON
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		var error_msg := "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		push_error("MapSerializer: " + error_msg)
		load_error.emit(error_msg)
		return -1
	
	var save_data: Dictionary = json.data
	
	# Validate version
	var version: String = save_data.get("version", "0.0")
	if not _is_compatible_version(version):
		var error_msg := "Incompatible save version: %s (current: %s)" % [version, SAVE_VERSION]
		push_error("MapSerializer: " + error_msg)
		load_error.emit(error_msg)
		return -1
	
	# Load data
	var generation_seed: int = save_data.get("generation_seed", 0)
	
	_load_hex_grid(save_data, hex_grid)
	
	if river_generator:
		river_generator.from_dict(save_data.get("rivers", []), hex_grid)
	
	if location_placer:
		location_placer.from_array(save_data.get("locations", []), hex_grid)
	
	# Load time data
	_load_time_data(save_data.get("time_data", {}))
	
	# Load player data (done by GameManager using returned save_data)
	# Store player data for retrieval
	_last_loaded_player_data = save_data.get("player_data", {})
	
	# Store fog data for retrieval (loaded after fog manager is ready)
	_last_loaded_fog_data = save_data.get("fog_of_war", {})
	
	# Store survival and inventory data
	_last_loaded_survival_data = save_data.get("survival", {})
	_last_loaded_inventory_data = save_data.get("inventory", {})
	
	# Load survival and inventory immediately if managers exist
	_load_survival_data(_last_loaded_survival_data)
	_load_inventory_data(_last_loaded_inventory_data)
	
	print("MapSerializer: Loaded map from %s (seed: %d)" % [file_path, generation_seed])
	map_loaded.emit(file_path, generation_seed)
	_emit_to_event_bus("map_loaded", [file_path, generation_seed])
	
	return generation_seed


## Last loaded player data (for GameManager to retrieve).
var _last_loaded_player_data: Dictionary = {}

## Last loaded survival data.
var _last_loaded_survival_data: Dictionary = {}

## Last loaded inventory data.
var _last_loaded_inventory_data: Dictionary = {}


## Gets the player data from the last loaded save.
func get_loaded_player_data() -> Dictionary:
	return _last_loaded_player_data


func _load_time_data(time_data: Dictionary) -> void:
	if time_data.is_empty():
		return
	
	var time_manager = Engine.get_main_loop().root.get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("from_dict"):
		time_manager.from_dict(time_data)


func _load_fog_data(fog_data: Dictionary) -> void:
	if fog_data.is_empty():
		return
	
	var main_loop = Engine.get_main_loop()
	if main_loop:
		var tree: SceneTree = main_loop as SceneTree
		if tree:
			var fog_manager = tree.get_first_node_in_group("fog_manager")
			if fog_manager and fog_manager.has_method("from_dict"):
				fog_manager.from_dict(fog_data)


func _load_survival_data(survival_data: Dictionary) -> void:
	if survival_data.is_empty():
		return
	
	var main_loop = Engine.get_main_loop()
	if main_loop:
		var tree: SceneTree = main_loop as SceneTree
		if tree:
			var survival_manager = tree.get_first_node_in_group("survival_manager")
			if survival_manager and survival_manager.has_method("from_dict"):
				survival_manager.from_dict(survival_data)


func _load_inventory_data(inventory_data: Dictionary) -> void:
	if inventory_data.is_empty():
		return
	
	var main_loop = Engine.get_main_loop()
	if main_loop:
		var tree: SceneTree = main_loop as SceneTree
		if tree:
			var inventory_manager = tree.get_first_node_in_group("inventory_manager")
			if inventory_manager and inventory_manager.has_method("from_dict"):
				inventory_manager.from_dict(inventory_data)


## Last loaded fog data (for deferred loading).
var _last_loaded_fog_data: Dictionary = {}


## Gets the fog data from the last loaded save.
func get_loaded_fog_data() -> Dictionary:
	return _last_loaded_fog_data


func _is_compatible_version(version: String) -> bool:
	# For now, only accept exact match
	# In the future, implement version migration
	var parts := version.split(".")
	var current_parts := SAVE_VERSION.split(".")
	
	# Major version must match
	if parts[0] != current_parts[0]:
		return false
	
	return true


func _load_hex_grid(save_data: Dictionary, hex_grid: HexGrid) -> void:
	var map_size: Dictionary = save_data.get("map_size", {"width": 30, "height": 30})
	
	# Update grid dimensions if different
	hex_grid.map_width = map_size.get("width", 30)
	hex_grid.map_height = map_size.get("height", 30)
	hex_grid.hex_size = save_data.get("hex_size", 64.0)
	
	# Regenerate grid structure (creates cells with default terrain)
	hex_grid.generate_grid()
	
	# Apply saved hex data
	var hexes: Array = save_data.get("hexes", [])
	
	for hex_data in hexes:
		var coords_dict: Dictionary = hex_data.get("coords", {"q": 0, "r": 0})
		var coords := Vector2i(coords_dict["q"], coords_dict["r"])
		
		var cell: HexCell = hex_grid.get_cell(coords)
		if cell == null:
			continue
		
		cell.elevation = hex_data.get("elevation", 0.5)
		cell.moisture = hex_data.get("moisture", 0.5)
		cell.terrain_type = hex_data.get("terrain_type", "plains")
		cell.has_river = hex_data.get("has_river", false)
		
		if hex_data.has("river_flow"):
			var flow: Dictionary = hex_data["river_flow"]
			cell.river_flow_direction = Vector2i(flow.get("q", 0), flow.get("r", 0))
		
		# Recalculate terrain color based on elevation/moisture
		# (This will be done by the terrain generator's color variation logic)

# =============================================================================
# FILE MANAGEMENT
# =============================================================================

## Gets a list of available save files.
## @return Array[Dictionary] - Array of {filename, path, timestamp, seed} for each save.
func get_save_list() -> Array[Dictionary]:
	_ensure_save_directory()
	
	var saves: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIRECTORY)
	
	if dir == null:
		push_warning("MapSerializer: Could not open save directory")
		return saves
	
	dir.list_dir_begin()
	var filename := dir.get_next()
	
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			var file_path := SAVE_DIRECTORY + filename
			var save_info := _get_save_info(file_path)
			if not save_info.is_empty():
				saves.append(save_info)
		filename = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort by timestamp (newest first)
	saves.sort_custom(func(a, b):
		return a.get("timestamp", "") > b.get("timestamp", "")
	)
	
	return saves


func _get_save_info(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	
	# Read just enough to get metadata
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var data: Dictionary = json.data
	
	var filename := file_path.get_file()
	
	return {
		"filename": filename.replace(".json", ""),
		"path": file_path,
		"timestamp": data.get("timestamp", "Unknown"),
		"generation_seed": data.get("generation_seed", 0),
		"map_size": data.get("map_size", {"width": 0, "height": 0}),
		"version": data.get("version", "0.0")
	}


## Deletes a save file.
## @param filename: String - The filename (with or without .json extension).
## @return bool - True if deleted successfully.
func delete_save(filename: String) -> bool:
	if not filename.ends_with(".json"):
		filename += ".json"
	
	var file_path := SAVE_DIRECTORY + filename
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var dir := DirAccess.open(SAVE_DIRECTORY)
	if dir == null:
		return false
	
	var result := dir.remove(filename)
	return result == OK


func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIRECTORY):
		var result := DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
		if result != OK:
			push_error("MapSerializer: Failed to create save directory: %s" % SAVE_DIRECTORY)

# =============================================================================
# UTILITY
# =============================================================================

func _emit_to_event_bus(signal_name: String, args: Array) -> void:
	var event_bus = Engine.get_main_loop().root.get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal(signal_name):
		match args.size():
			0: event_bus.emit_signal(signal_name)
			1: event_bus.emit_signal(signal_name, args[0])
			2: event_bus.emit_signal(signal_name, args[0], args[1])
