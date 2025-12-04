# movement_controller.gd
# Handles pathfinding, movement validation, and path preview.
# Uses A* algorithm optimized for hex grids.
#
# FEATURES:
# - A* pathfinding with terrain cost awareness
# - Path cost calculation (accounts for terrain difficulty)
# - Movement preview (shows path before confirming)
# - Multi-day movement support

extends Node
class_name MovementController

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a path is calculated.
signal path_calculated(path: Array[Vector2i], cost: int, valid: bool)

## Emitted when path preview changes.
signal path_preview_changed(path: Array[Vector2i], cost: int)

## Emitted when path preview is cleared.
signal path_preview_cleared()

## Emitted when movement is validated.
signal movement_validated(target_hex: Vector2i, valid: bool, reason: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Movement costs per terrain type.
var movement_costs: Dictionary = {}

## List of impassable terrain types.
var impassable_terrain: Array = []

## Animation speed for movement.
var movement_animation_speed: float = 0.25

## Whether camera should follow player.
var camera_follow_player: bool = true

# =============================================================================
# STATE
# =============================================================================

## Reference to the hex grid.
var hex_grid: HexGrid = null

## Reference to the player.
var player: Player = null

## Currently previewed path.
var current_preview_path: Array[Vector2i] = []

## Currently previewed destination.
var current_preview_destination: Variant = null  # Vector2i or null

## Whether a movement is pending confirmation.
var pending_movement: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()


## Initializes with references to game objects.
func initialize(grid: HexGrid, player_ref: Player) -> void:
	hex_grid = grid
	player = player_ref
	print("MovementController: Initialized")


func _load_config() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_map_config("movement_config")
		movement_costs = config.get("movement_costs", _get_default_costs())
		impassable_terrain = config.get("impassable_terrain", ["water", "deep_water", "mountain_peak"])
		movement_animation_speed = config.get("movement_animation_speed", 0.25)
		camera_follow_player = config.get("camera_follow_player", true)
	else:
		movement_costs = _get_default_costs()
		impassable_terrain = ["water", "deep_water", "mountain_peak"]


func _get_default_costs() -> Dictionary:
	return {
		"plains": 1,
		"grassland": 1,
		"forest": 1,
		"forest_hills": 1,
		"desert": 1,
		"hills": 1,
		"badlands": 2,
		"mountains": 2,
		"highlands": 2,
		"swamp": 2,
		"water": -1,
		"deep_water": -1,
		"mountain_peak": -1
	}

# =============================================================================
# PATHFINDING (A*)
# =============================================================================

## Finds the optimal path from start to end using A*.
## @param from_hex: Vector2i - Starting hex.
## @param to_hex: Vector2i - Destination hex.
## @return Array[Vector2i] - Path including start and end, or empty if no path.
func find_path(from_hex: Vector2i, to_hex: Vector2i) -> Array[Vector2i]:
	if hex_grid == null:
		return []
	
	# Quick validation
	if not is_passable(to_hex):
		return []
	
	if from_hex == to_hex:
		return [from_hex]
	
	# A* implementation
	var open_set: Array[Vector2i] = [from_hex]
	var came_from: Dictionary = {}  # Vector2i -> Vector2i
	var g_score: Dictionary = {from_hex: 0}  # Cost from start
	var f_score: Dictionary = {from_hex: _heuristic(from_hex, to_hex)}  # Estimated total cost
	
	var iterations := 0
	var max_iterations := hex_grid.cells.size() * 2  # Safety limit
	
	while not open_set.is_empty() and iterations < max_iterations:
		iterations += 1
		
		# Find node with lowest f_score
		var current: Vector2i = _get_lowest_f_score(open_set, f_score)
		
		if current == to_hex:
			return _reconstruct_path(came_from, current)
		
		open_set.erase(current)
		
		# Check all neighbors
		var neighbors := HexUtils.get_neighbors(current)
		for neighbor in neighbors:
			if not is_passable(neighbor):
				continue
			
			var move_cost := get_movement_cost_for_hex(neighbor)
			if move_cost < 0:
				continue  # Impassable
			
			var tentative_g:float = g_score.get(current, INF) + move_cost
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, to_hex)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	# No path found
	return []


func _heuristic(from_hex: Vector2i, to_hex: Vector2i) -> float:
	# Use hex distance as heuristic (admissible for A*)
	return float(HexUtils.distance(from_hex, to_hex))


func _get_lowest_f_score(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var best: Vector2i = open_set[0]
	var best_score: float = f_score.get(best, INF)
	
	for hex in open_set:
		var score: float = f_score.get(hex, INF)
		if score < best_score:
			best = hex
			best_score = score
	
	return best


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	
	return path

# =============================================================================
# MOVEMENT COSTS
# =============================================================================

## Gets the movement cost for a specific hex.
## @param hex_coords: Vector2i - Hex to check.
## @return int - Turn cost (-1 = impassable).
func get_movement_cost_for_hex(hex_coords: Vector2i) -> int:
	if hex_grid == null:
		return 1
	
	var cell: HexCell = hex_grid.get_cell(hex_coords)
	if cell == null:
		return -1
	
	return get_movement_cost(cell.terrain_type)


## Gets the movement cost for a terrain type.
## @param terrain_type: String - Terrain to check.
## @return int - Turn cost (-1 = impassable).
func get_movement_cost(terrain_type: String) -> int:
	if terrain_type in impassable_terrain:
		return -1
	
	return movement_costs.get(terrain_type, 1)


## Calculates the total turn cost for a path.
## @param path: Array[Vector2i] - Path to calculate.
## @return int - Total turn cost.
func calculate_path_cost(path: Array[Vector2i]) -> int:
	if path.size() < 2:
		return 0
	
	var total_cost := 0
	
	# Start from index 1 (skip starting hex - player is already there)
	for i in range(1, path.size()):
		var cost := get_movement_cost_for_hex(path[i])
		if cost < 0:
			return -1  # Path goes through impassable terrain
		total_cost += cost
	
	return total_cost


## Gets a breakdown of costs for each hex in a path.
## @param path: Array[Vector2i] - Path to analyze.
## @return Array[Dictionary] - Array of {hex, terrain, cost, cumulative}.
func get_path_cost_breakdown(path: Array[Vector2i]) -> Array[Dictionary]:
	var breakdown: Array[Dictionary] = []
	var cumulative := 0
	
	for i in range(path.size()):
		var hex_coords: Vector2i = path[i]
		var cell: HexCell = hex_grid.get_cell(hex_coords) if hex_grid else null
		var terrain := cell.terrain_type if cell else "unknown"
		var cost := 0 if i == 0 else get_movement_cost_for_hex(hex_coords)
		
		cumulative += cost
		
		breakdown.append({
			"hex": hex_coords,
			"terrain": terrain,
			"cost": cost,
			"cumulative": cumulative
		})
	
	return breakdown

# =============================================================================
# PASSABILITY
# =============================================================================

## Checks if a hex is passable.
## @param hex_coords: Vector2i - Hex to check.
## @return bool - True if passable.
func is_passable(hex_coords: Vector2i) -> bool:
	if hex_grid == null:
		return false
	
	var cell: HexCell = hex_grid.get_cell(hex_coords)
	if cell == null:
		return false
	
	if cell.terrain_type in impassable_terrain:
		return false
	
	return true


## Gets the reason why a hex is impassable.
func get_impassability_reason(hex_coords: Vector2i) -> String:
	if hex_grid == null:
		return "No grid"
	
	var cell: HexCell = hex_grid.get_cell(hex_coords)
	if cell == null:
		return "Out of bounds"
	
	if cell.terrain_type in impassable_terrain:
		return "Cannot traverse %s" % cell.terrain_type.replace("_", " ")
	
	return ""

# =============================================================================
# PATH PREVIEW
# =============================================================================

## Shows a preview of the path to a destination.
## @param target_hex: Vector2i - Destination hex.
## @return Dictionary - {path, cost, valid, reason}.
func preview_path(target_hex: Vector2i) -> Dictionary:
	if player == null or hex_grid == null:
		return {"path": [], "cost": 0, "valid": false, "reason": "Not initialized"}
	
	if player.is_moving:
		return {"path": [], "cost": 0, "valid": false, "reason": "Already moving"}
	
	var from_hex := player.current_hex
	
	# Check if destination is valid
	if not is_passable(target_hex):
		var reason := get_impassability_reason(target_hex)
		clear_preview()
		return {"path": [], "cost": 0, "valid": false, "reason": reason}
	
	# Same hex
	if from_hex == target_hex:
		clear_preview()
		return {"path": [], "cost": 0, "valid": false, "reason": "Already there"}
	
	# Find path
	var path := find_path(from_hex, target_hex)
	
	if path.is_empty():
		clear_preview()
		return {"path": [], "cost": 0, "valid": false, "reason": "No path available"}
	
	# Calculate cost
	var cost := calculate_path_cost(path)
	
	# Store preview state
	current_preview_path = path
	current_preview_destination = target_hex
	pending_movement = true
	
	# Apply visual preview to grid
	_apply_path_preview(path)
	
	path_preview_changed.emit(path, cost)
	path_calculated.emit(path, cost, true)
	
	return {
		"path": path,
		"cost": cost,
		"valid": true,
		"reason": "",
		"breakdown": get_path_cost_breakdown(path)
	}


## Clears the current path preview.
func clear_preview() -> void:
	if hex_grid:
		_clear_path_preview()
	
	current_preview_path.clear()
	current_preview_destination = null
	pending_movement = false
	
	path_preview_cleared.emit()


func _apply_path_preview(path: Array[Vector2i]) -> void:
	# First clear any existing preview
	_clear_path_preview()
	
	# Apply path highlight to each hex
	for i in range(path.size()):
		var hex_coords: Vector2i = path[i]
		var cell: HexCell = hex_grid.get_cell(hex_coords)
		if cell:
			cell.set_path_preview(true, i == path.size() - 1)


func _clear_path_preview() -> void:
	for coords in hex_grid.cells:
		var cell: HexCell = hex_grid.cells[coords]
		cell.set_path_preview(false, false)

# =============================================================================
# MOVEMENT EXECUTION
# =============================================================================

## Confirms and executes the currently previewed movement.
## @return bool - True if movement started successfully.
func confirm_movement() -> bool:
	if not pending_movement or current_preview_path.is_empty():
		return false
	
	if player == null or player.is_moving:
		return false
	
	var path := current_preview_path.duplicate()
	var cost := calculate_path_cost(path)
	
	# Clear preview before moving
	clear_preview()
	
	# Execute movement
	player.move_along_path(path, cost)
	
	return true


## Requests movement to a target hex.
## If already previewing this destination, confirms the move.
## Otherwise, creates a new preview.
## @param target_hex: Vector2i - Destination hex.
## @return Dictionary - Result info.
func request_movement(target_hex: Vector2i) -> Dictionary:
	# If clicking same destination that's already previewed, confirm movement
	if pending_movement and current_preview_destination == target_hex:
		if confirm_movement():
			return {"action": "moved", "success": true}
		else:
			return {"action": "move_failed", "success": false}
	
	# Otherwise, show preview for new destination
	var preview := preview_path(target_hex)
	
	if preview["valid"]:
		return {
			"action": "preview",
			"success": true,
			"path": preview["path"],
			"cost": preview["cost"]
		}
	else:
		return {
			"action": "invalid",
			"success": false,
			"reason": preview["reason"]
		}


## Cancels any pending movement.
func cancel_pending_movement() -> void:
	clear_preview()
	
	if player and player.is_moving:
		player.cancel_movement()

# =============================================================================
# QUERIES
# =============================================================================

## Gets the movement cost to reach a hex from current player position.
## @param target_hex: Vector2i - Destination hex.
## @return int - Turn cost, or -1 if unreachable.
func get_cost_to_hex(target_hex: Vector2i) -> int:
	if player == null:
		return -1
	
	var path := find_path(player.current_hex, target_hex)
	if path.is_empty():
		return -1
	
	return calculate_path_cost(path)


## Gets all hexes reachable within a certain turn budget.
## @param turn_budget: int - Maximum turns to spend.
## @return Array[Vector2i] - Reachable hexes.
func get_reachable_hexes(turn_budget: int) -> Array[Vector2i]:
	if player == null or hex_grid == null:
		return []
	
	var reachable: Array[Vector2i] = []
	var start := player.current_hex
	
	# BFS with cost tracking
	var visited: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_cost: int = visited[current]
		
		var neighbors := HexUtils.get_neighbors(current)
		for neighbor in neighbors:
			if visited.has(neighbor):
				continue
			
			if not is_passable(neighbor):
				continue
			
			var move_cost := get_movement_cost_for_hex(neighbor)
			var total_cost := current_cost + move_cost
			
			if total_cost <= turn_budget:
				visited[neighbor] = total_cost
				queue.append(neighbor)
				reachable.append(neighbor)
	
	return reachable
