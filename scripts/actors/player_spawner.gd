# player_spawner.gd
# Handles spawning the player at a valid starting position.
# Prefers spawning near towns, falls back to safe terrain near map center.

extends Node
class_name PlayerSpawner

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when player is successfully spawned.
signal player_spawned(player: Player, hex_coords: Vector2i)

## Emitted when spawning fails.
signal spawn_failed(reason: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Whether to prefer spawning near towns.
var spawn_near_town: bool = true

## Fallback terrain types if no town available.
var fallback_terrain: Array = ["plains", "grassland", "forest"]

# =============================================================================
# STATE
# =============================================================================

## Reference to hex grid.
var _hex_grid: HexGrid = null

## The player instance.
@onready var _player:Player = preload("res://scenes/actors/player.tscn").instantiate()

## Reference to movement controller.
var _movement_controller: MovementController = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()


func _load_config() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_map_config("movement_config")
		spawn_near_town = config.get("spawn_near_town", true)
		fallback_terrain = config.get("spawn_fallback_terrain", ["plains", "grassland", "forest"])

# =============================================================================
# SPAWNING
# =============================================================================

## Spawns the player on the map.
## @param hex_grid: HexGrid - The grid to spawn on.
## @param movement_controller: MovementController - Movement system reference.
## @return Player - The spawned player, or null if failed.
func spawn_player(hex_grid: HexGrid, movement_controller: MovementController) -> Player:
	_hex_grid = hex_grid
	_movement_controller = movement_controller
	
	# Find valid spawn position
	var spawn_hex := find_spawn_position()
	
	if spawn_hex == Vector2i(-9999, -9999):
		spawn_failed.emit("No valid spawn position found")
		push_error("PlayerSpawner: Could not find valid spawn position")
		return null
	
	# Create player instance
	#_player = Player.new()
	
	_player.name = "Player"
	
	# Load player name from config
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_map_config("movement_config")
		_player.player_name = config.get("default_player_name", "Wanderer")
	
	# Add player to scene tree (as sibling of hex_grid)
	var parent := hex_grid.get_parent()
	if parent:
		parent.add_child(_player)
	else:
		hex_grid.add_child(_player)
	
	# Initialize player
	_player.initialize(hex_grid, spawn_hex)
	
	# Initialize movement controller with player reference
	movement_controller.initialize(hex_grid, _player)
	
	player_spawned.emit(_player, spawn_hex)
	_emit_to_event_bus("player_spawned", [spawn_hex])
	
	print("PlayerSpawner: Spawned player at %s" % spawn_hex)
	return _player


## Finds a valid spawn position.
## @return Vector2i - Spawn coordinates, or (-9999, -9999) if none found.
func find_spawn_position() -> Vector2i:
	if _hex_grid == null:
		return Vector2i(-9999, -9999)
	
	# Try to spawn near a town
	if spawn_near_town:
		var town_spawn := _find_spawn_near_town()
		if town_spawn != Vector2i(-9999, -9999):
			return town_spawn
	
	# Fallback: find safe terrain near map center
	var center_spawn := _find_spawn_near_center()
	if center_spawn != Vector2i(-9999, -9999):
		return center_spawn
	
	# Last resort: any valid hex
	return _find_any_valid_hex()


func _find_spawn_near_town() -> Vector2i:
	# Get towns from location placer
	var towns: Array = _hex_grid.get_locations_by_type("town")
	
	if towns.is_empty():
		return Vector2i(-9999, -9999)
	
	# Shuffle towns for variety
	towns.shuffle()
	
	for town in towns:
		var town_coords: Vector2i = town["coords"]
		
		# Check if town hex itself is valid
		if _is_valid_spawn(town_coords):
			return town_coords
		
		# Check adjacent hexes
		var neighbors := HexUtils.get_neighbors(town_coords)
		neighbors.shuffle()
		
		for neighbor in neighbors:
			if _is_valid_spawn(neighbor):
				return neighbor
	
	return Vector2i(-9999, -9999)


func _find_spawn_near_center() -> Vector2i:
	var center_q := _hex_grid.map_width / 2
	var center_r := _hex_grid.map_height / 2
	var center := HexUtils.offset_to_axial(Vector2i(center_q, center_r))
	
	# Search in expanding rings from center
	for radius in range(0, 15):
		var ring := HexUtils.get_hex_ring(center, radius)
		ring.shuffle()
		
		for coords in ring:
			if _is_valid_spawn(coords):
				return coords
	
	return Vector2i(-9999, -9999)


func _find_any_valid_hex() -> Vector2i:
	var candidates: Array[Vector2i] = []
	
	for coords in _hex_grid.cells:
		if _is_valid_spawn(coords):
			candidates.append(coords)
	
	if candidates.is_empty():
		return Vector2i(-9999, -9999)
	
	candidates.shuffle()
	return candidates[0]


func _is_valid_spawn(coords: Vector2i) -> bool:
	var cell: HexCell = _hex_grid.get_cell(coords)
	if cell == null:
		return false
	
	var terrain := cell.terrain_type
	
	# Only call movement_controller if it's actually initialized
	if _movement_controller and _movement_controller.hex_grid != null:
		if not _movement_controller.is_passable(coords):
			return false
	else:
		# Fallback check without movement controller
		var impassable := ["water", "deep_water", "mountain_peak"]
		if terrain in impassable:
			return false
	
	# Check if terrain is in fallback list (if not near town)
	if not spawn_near_town or cell.location == null:
		if terrain not in fallback_terrain:
			# Allow it anyway if it's passable and not extreme
			if terrain in ["mountains", "swamp", "badlands"]:
				return false
	
	return true

# =============================================================================
# PLAYER ACCESS
# =============================================================================

## Gets the spawned player instance.
func get_player() -> Player:
	return _player


## Checks if a player has been spawned.
func has_player() -> bool:
	return _player != null and is_instance_valid(_player)

# =============================================================================
# RESPAWNING
# =============================================================================

## Respawns the player at a new location.
## @param hex_coords: Vector2i - New spawn position (or auto-find if null).
func respawn_player(hex_coords: Variant = null) -> void:
	if not has_player():
		push_warning("PlayerSpawner: No player to respawn")
		return
	
	var spawn_hex: Vector2i
	
	if hex_coords == null:
		spawn_hex = find_spawn_position()
	else:
		spawn_hex = hex_coords
	
	if spawn_hex == Vector2i(-9999, -9999):
		push_error("PlayerSpawner: Could not find respawn position")
		return
	
	_player.teleport_to_hex(spawn_hex)
	print("PlayerSpawner: Respawned player at %s" % spawn_hex)

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
