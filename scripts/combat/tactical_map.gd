# tactical_map.gd
# Generates and manages the tactical combat hex grid.
# Handles terrain generation, cover placement, pathfinding, and line of sight.

extends Node2D
class_name TacticalMap

# =============================================================================
# SIGNALS
# =============================================================================

signal map_generated(size: Vector2i)
signal cell_clicked(coords: Vector2i)
signal cell_hovered(coords: Vector2i)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Size of the tactical grid.
var grid_size: Vector2i = Vector2i(15, 12)

## Hex size for tactical map (smaller than exploration).
var hex_size: float = 48.0

## Terrain type for this combat.
var terrain_type: String = "plains"

# =============================================================================
# STATE
# =============================================================================

## All hex cells indexed by coordinates.
var cells: Dictionary = {}  # Vector2i -> TacticalHexCell

## Terrain template data.
var _terrain_template: Dictionary = {}

## Combat settings.
var _combat_settings: Dictionary = {}

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()


func _load_config() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_json("res://data/combat/weapons.json")
		_combat_settings = config.get("combat_settings", {})


## Generate a tactical map for the given terrain type.
func generate(terrain: String, size: Vector2i = Vector2i(15, 12)) -> void:
	terrain_type = terrain
	grid_size = size
	
	# Load terrain template
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_json("res://data/combat/weapons.json")
		var templates: Dictionary = config.get("terrain_templates", {})
		_terrain_template = templates.get(terrain, templates.get("plains", {}))
	
	# Clear existing cells
	_clear_cells()
	
	# Generate cells
	_generate_cells()
	
	# Place cover
	_place_cover()
	
	# Center the map
	_center_map()
	
	map_generated.emit(grid_size)


func _clear_cells() -> void:
	for cell in cells.values():
		cell.queue_free()
	cells.clear()


func _generate_cells() -> void:
	var base_terrain: String = _terrain_template.get("base_terrain", "open")
	
	for q in range(grid_size.x):
		for r in range(grid_size.y):
			var coords := Vector2i(q, r)
			var cell := TacticalHexCell.new()
			cell.initialize(coords, hex_size, base_terrain)
			
			# Connect signals
			cell.cell_clicked.connect(_on_cell_clicked)
			cell.cell_hovered.connect(_on_cell_hovered)
			
			add_child(cell)
			cells[coords] = cell


func _place_cover() -> void:
	var cover_density: float = _terrain_template.get("cover_density", 0.15)
	var cover_types: Dictionary = _terrain_template.get("cover_types", {"light": 0.7, "heavy": 0.3})
	var obstacle_density: float = _terrain_template.get("obstacle_density", 0.05)
	
	# Calculate spawn zones (player at bottom, enemies at top)
	var player_zone_rows := 2
	var enemy_zone_rows := 2
	
	for coords in cells:
		var cell: TacticalHexCell = cells[coords]
		
		# Skip spawn zones
		if coords.y < player_zone_rows or coords.y >= grid_size.y - enemy_zone_rows:
			continue
		
		# Roll for obstacle (impassable)
		if randf() < obstacle_density:
			cell.is_passable = false
			cell.terrain_cost = TacticalHexCell.TerrainCost.IMPASSABLE
			cell.set_terrain_color(Color(0.12, 0.1, 0.08))
			continue
		
		# Roll for cover
		if randf() < cover_density:
			# Determine cover type
			var light_chance: float = cover_types.get("light", 0.7)
			if randf() < light_chance:
				cell.set_cover(TacticalHexCell.CoverType.LIGHT)
			else:
				cell.set_cover(TacticalHexCell.CoverType.HEAVY)


func _center_map() -> void:
	# Calculate map bounds
	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF
	
	for cell in cells.values():
		min_pos = min_pos.min(cell.position)
		max_pos = max_pos.max(cell.position)
	
	var center := (min_pos + max_pos) / 2.0
	position = -center

# =============================================================================
# CELL ACCESS
# =============================================================================

## Get cell at coordinates.
func get_cell(coords: Vector2i) -> TacticalHexCell:
	return cells.get(coords, null)


## Check if coordinates are valid.
func is_valid_coords(coords: Vector2i) -> bool:
	return cells.has(coords)


## Check if cell is passable and unoccupied.
func can_enter_cell(coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	if cell == null:
		return false
	return cell.can_enter()

# =============================================================================
# COMBATANT PLACEMENT
# =============================================================================

## Get spawn position for player (bottom center).
func get_player_spawn_hex() -> Vector2i:
	var center_q := grid_size.x / 2
	return Vector2i(center_q, 1)


## Get spawn positions for enemies (top area).
func get_enemy_spawn_hexes(count: int) -> Array[Vector2i]:
	var spawns: Array[Vector2i] = []
	var enemy_row := grid_size.y - 2
	var start_q := (grid_size.x - count) / 2
	
	for i in range(count):
		var coords := Vector2i(start_q + i, enemy_row)
		if is_valid_coords(coords):
			spawns.append(coords)
	
	return spawns


## Place a combatant at a hex.
func place_combatant(combatant: Combatant, coords: Vector2i) -> bool:
	var cell := get_cell(coords)
	if cell == null or not cell.can_enter():
		return false
	
	cell.set_occupant(combatant)
	combatant.current_hex = coords
	combatant.position = cell.position
	
	return true


## Move a combatant from one hex to another.
func move_combatant(combatant: Combatant, from_coords: Vector2i, to_coords: Vector2i) -> void:
	var from_cell := get_cell(from_coords)
	var to_cell := get_cell(to_coords)
	
	if from_cell:
		from_cell.clear_occupant()
	
	if to_cell:
		to_cell.set_occupant(combatant)
		combatant.current_hex = to_coords


## Remove a combatant from the map.
func remove_combatant(combatant: Combatant) -> void:
	var cell := get_cell(combatant.current_hex)
	if cell:
		cell.clear_occupant()

# =============================================================================
# PATHFINDING
# =============================================================================

## Get all hexes reachable within AP budget.
func get_reachable_hexes(start: Vector2i, max_ap: int) -> Dictionary:
	# Returns Dictionary of Vector2i -> int (coords -> AP cost to reach)
	var reachable: Dictionary = {}
	var frontier: Array = [[start, 0]]
	reachable[start] = 0
	
	while frontier.size() > 0:
		var current = frontier.pop_front()
		var current_coords: Vector2i = current[0]
		var current_cost: int = current[1]
		
		for neighbor in _get_neighbors(current_coords):
			var cell := get_cell(neighbor)
			if cell == null or not cell.can_enter():
				continue
			
			var move_cost: int = cell.get_movement_cost()
			if move_cost < 0:
				continue
			
			var total_cost: int = current_cost + move_cost
			if total_cost > max_ap:
				continue
			
			if not reachable.has(neighbor) or reachable[neighbor] > total_cost:
				reachable[neighbor] = total_cost
				frontier.append([neighbor, total_cost])
	
	return reachable


## Find path between two hexes.
## @return Array[Vector2i] - Path from start to end, or empty if no path.
func find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	if start == end:
		return [start]
	
	var open_set: Array = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: _hex_distance(start, end)}
	
	while open_set.size() > 0:
		# Find node with lowest f_score
		var current: Vector2i = open_set[0]
		var lowest_f: int = f_score.get(current, 9999)
		for node in open_set:
			var f: int = f_score.get(node, 9999)
			if f < lowest_f:
				lowest_f = f
				current = node
		
		if current == end:
			return _reconstruct_path(came_from, current)
		
		open_set.erase(current)
		
		for neighbor in _get_neighbors(current):
			var cell := get_cell(neighbor)
			if cell == null or not cell.can_enter():
				continue
			
			var move_cost: int = cell.get_movement_cost()
			if move_cost < 0:
				continue
			
			var tentative_g: int = g_score.get(current, 9999) + move_cost
			
			if tentative_g < g_score.get(neighbor, 9999):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _hex_distance(neighbor, end)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	return []  # No path found


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.insert(0, current)
	return path


func _get_neighbors(coords: Vector2i) -> Array[Vector2i]:
	var directions := [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	var neighbors: Array[Vector2i] = []
	for dir in directions:
		var neighbor:Vector2i = coords + dir
		if is_valid_coords(neighbor):
			neighbors.append(neighbor)
	return neighbors


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2

# =============================================================================
# LINE OF SIGHT
# =============================================================================

## Check if there's line of sight between two hexes.
func has_line_of_sight(from_coords: Vector2i, to_coords: Vector2i) -> bool:
	var hexes_between := _get_hexes_on_line(from_coords, to_coords)
	
	# Check each hex between (excluding start and end)
	for i in range(1, hexes_between.size() - 1):
		var coords: Vector2i = hexes_between[i]
		var cell := get_cell(coords)
		
		if cell == null:
			return false
		
		# Blocked by impassable terrain
		if not cell.is_passable:
			return false
		
		# Blocked by other combatants
		if cell.is_occupied():
			return false
	
	return true


func _get_hexes_on_line(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var n := _hex_distance(start, end)
	
	if n == 0:
		return [start]
	
	# Convert to cube coordinates for lerping
	var start_cube := _axial_to_cube(start)
	var end_cube := _axial_to_cube(end)
	
	for i in range(n + 1):
		var t := float(i) / float(n)
		var cube := _cube_lerp(start_cube, end_cube, t)
		var rounded := _cube_round(cube)
		result.append(_cube_to_axial(rounded))
	
	return result


func _axial_to_cube(axial: Vector2i) -> Vector3:
	return Vector3(axial.x, axial.y, -axial.x - axial.y)


func _cube_to_axial(cube: Vector3) -> Vector2i:
	return Vector2i(int(cube.x), int(cube.y))


func _cube_lerp(a: Vector3, b: Vector3, t: float) -> Vector3:
	return Vector3(
		lerpf(a.x, b.x, t),
		lerpf(a.y, b.y, t),
		lerpf(a.z, b.z, t)
	)


func _cube_round(cube: Vector3) -> Vector3:
	var rx:float = round(cube.x)
	var ry:float = round(cube.y)
	var rz:float = round(cube.z)
	
	var x_diff:float = abs(rx - cube.x)
	var y_diff:float = abs(ry - cube.y)
	var z_diff:float = abs(rz - cube.z)
	
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	
	return Vector3(rx, ry, rz)

# =============================================================================
# RANGE QUERIES
# =============================================================================

## Get all hexes within range.
func get_hexes_in_range(center: Vector2i, range_val: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	for q in range(-range_val, range_val + 1):
		for r in range(max(-range_val, -q - range_val), min(range_val, -q + range_val) + 1):
			var coords := center + Vector2i(q, r)
			if is_valid_coords(coords) and coords != center:
				result.append(coords)
	
	return result


## Get valid attack targets from a position.
func get_valid_targets(attacker_coords: Vector2i, weapon_range: int, enemies: Array) -> Array:
	var valid: Array = []
	
	for enemy in enemies:
		if not enemy.is_alive:
			continue
		
		var distance := _hex_distance(attacker_coords, enemy.current_hex)
		if distance <= weapon_range:
			if has_line_of_sight(attacker_coords, enemy.current_hex):
				valid.append(enemy)
	
	return valid

# =============================================================================
# HIGHLIGHTING
# =============================================================================

## Highlight all reachable hexes.
func highlight_reachable(start: Vector2i, max_ap: int) -> void:
	clear_highlights()
	var reachable := get_reachable_hexes(start, max_ap)
	for coords in reachable:
		if coords != start:
			var cell := get_cell(coords)
			if cell:
				cell.set_highlight(TacticalHexCell.HighlightType.MOVEMENT)


## Highlight hexes in attack range.
func highlight_attack_range(center: Vector2i, range_val: int) -> void:
	clear_highlights()
	var in_range := get_hexes_in_range(center, range_val)
	for coords in in_range:
		var cell := get_cell(coords)
		if cell and has_line_of_sight(center, coords):
			cell.set_highlight(TacticalHexCell.HighlightType.ATTACK)


## Highlight a single cell as selected.
func highlight_selected(coords: Vector2i) -> void:
	var cell := get_cell(coords)
	if cell:
		cell.set_highlight(TacticalHexCell.HighlightType.SELECTED)


## Clear all highlights.
func clear_highlights() -> void:
	for cell in cells.values():
		cell.clear_highlight()

# =============================================================================
# COVER QUERIES
# =============================================================================

## Get cover modifier for a target when attacked from a direction.
func get_cover_modifier_for_attack(target_coords: Vector2i, attacker_coords: Vector2i) -> float:
	var target_cell := get_cell(target_coords)
	if target_cell == null:
		return 0.0
	
	# Basic implementation: just use target cell's cover
	# Future: Consider direction and adjacent cover
	return target_cell.get_cover_modifier()

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_cell_clicked(coords: Vector2i) -> void:
	cell_clicked.emit(coords)


func _on_cell_hovered(coords: Vector2i) -> void:
	cell_hovered.emit(coords)

# =============================================================================
# UTILITY
# =============================================================================

## Get pixel position for hex coordinates.
func get_pixel_position(coords: Vector2i) -> Vector2:
	var cell := get_cell(coords)
	if cell:
		return cell.position + position
	
	# Calculate manually
	var x := hex_size * (sqrt(3.0) * coords.x + sqrt(3.0) / 2.0 * coords.y)
	var y := hex_size * (3.0 / 2.0 * coords.y)
	return Vector2(x, y) + position


## Get map bounds for camera.
func get_bounds() -> Rect2:
	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF
	
	for cell in cells.values():
		var cell_pos: Vector2 = cell.position + position
		min_pos = min_pos.min(cell_pos - Vector2(hex_size, hex_size))
		max_pos = max_pos.max(cell_pos + Vector2(hex_size, hex_size))
	
	return Rect2(min_pos, max_pos - min_pos)

## Get map size in pixels (for camera framing).
func get_map_pixel_size() -> Vector2:
	var bounds := get_bounds()
	return bounds.size
