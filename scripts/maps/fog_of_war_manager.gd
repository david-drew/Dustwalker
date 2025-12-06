# fog_of_war_manager.gd
# Manages the fog of war system including vision calculation,
# exploration tracking, and fog state updates.
#
# THREE FOG STATES:
# - UNEXPLORED: Never seen, completely black
# - EXPLORED: Previously visited, dimmed (remembers terrain)
# - VISIBLE: Currently within vision range, full color
#
# Vision is recalculated when:
# - Player moves to a new hex
# - Time of day changes (affects vision range)
# - Game is loaded

extends Node
class_name FogOfWarManager

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when fog system is initialized.
signal fog_initialized(total_hexes: int)

## Emitted when a hex is explored for the first time.
signal hex_first_explored(coords: Vector2i, day: int, turn: int)

## Emitted when a hex becomes visible.
signal hex_became_visible(coords: Vector2i)

## Emitted when a hex leaves vision (becomes explored).
signal hex_became_explored(coords: Vector2i)

## Emitted when vision range changes.
signal vision_range_changed(old_range: int, new_range: int)

## Emitted when exploration stats update.
signal exploration_stats_updated(explored_count: int, total_count: int, percentage: float)

## Emitted when entire map is revealed (debug).
signal map_revealed_debug()

## Emitted when fog rendering is toggled.
signal fog_debug_toggled(enabled: bool)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Base vision range in hexes.
var base_vision_range: int = 2

## Minimum vision range (even at night).
var min_vision_range: int = 1

## Maximum vision range.
var max_vision_range: int = 5

## Time of day modifiers to vision range.
var time_modifiers: Dictionary = {}

## Terrain modifiers to vision range (future use).
var terrain_modifiers: Dictionary = {}

## Bonus radius revealed at spawn location.
var spawn_bonus_radius: int = 1

## Fog overlay colors.
var fog_colors: Dictionary = {
	"unexplored": Color(0, 0, 0, 0.95),
	"explored": Color(0, 0, 0, 0.38),
	"visible": Color(0, 0, 0, 0.0)
}

## Duration of fog transitions.
var fog_transition_duration: float = 0.25

## Whether to reveal hexes during movement animation.
var reveal_during_movement: bool = true

# =============================================================================
# STATE
# =============================================================================

## Reference to hex grid.
var hex_grid: HexGrid = null

## Reference to player.
var player: Player = null

## Current calculated vision range.
var current_vision_range: int = 2

## Set of currently visible hex coordinates.
var currently_visible_hexes: Dictionary = {}  # Vector2i -> true

## Set of previously visible hexes (for detecting changes).
var previously_visible_hexes: Dictionary = {}

## Whether fog rendering is enabled (debug toggle).
var fog_enabled: bool = true

## Whether the system has been initialized.
var _initialized: bool = false

## Exploration statistics.
var _explored_count: int = 0
var _explored_today: int = 0
var _current_day: int = 1
var _locations_discovered: int = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_config()
	_connect_signals()


func _load_config() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_map_config("fog_config")
		
		var vision_config: Dictionary = config.get("vision", {})
		base_vision_range = vision_config.get("base_range", 2)
		min_vision_range = vision_config.get("min_range", 1)
		max_vision_range = vision_config.get("max_range", 5)
		time_modifiers = vision_config.get("time_of_day_modifiers", {})
		terrain_modifiers = vision_config.get("terrain_modifiers", {})
		spawn_bonus_radius = vision_config.get("spawn_bonus_radius", 1)
		
		var colors_config: Dictionary = config.get("fog_colors", {})
		for state in colors_config:
			var c: Dictionary = colors_config[state]
			fog_colors[state] = Color(c.get("r", 0), c.get("g", 0), c.get("b", 0), c.get("a", 1))
		
		fog_transition_duration = config.get("fog_transition_duration", 0.25)
		reveal_during_movement = config.get("reveal_during_movement", true)
	
	current_vision_range = base_vision_range


func _connect_signals() -> void:
	# Connect to TimeManager for time of day changes
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if time_manager.has_signal("turn_started"):
			time_manager.turn_started.connect(_on_turn_started)
		if time_manager.has_signal("day_started"):
			time_manager.day_started.connect(_on_day_started)
	
	# Connect to EventBus for player movement and weather
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("player_moved_to_hex"):
			event_bus.player_moved_to_hex.connect(_on_player_moved_to_hex)
		if event_bus.has_signal("player_spawned"):
			event_bus.player_spawned.connect(_on_player_spawned)
		if event_bus.has_signal("weather_started"):
			event_bus.weather_started.connect(_on_weather_changed)
		if event_bus.has_signal("weather_ended"):
			event_bus.weather_ended.connect(_on_weather_ended)


## Initializes the fog system with grid and player references.
func initialize(grid: HexGrid, player_ref: Player) -> void:
	hex_grid = grid
	player = player_ref
	
	if hex_grid == null:
		push_error("FogOfWarManager: HexGrid is null")
		return
	
	# Initialize all hexes as unexplored
	for coords in hex_grid.cells:
		var cell: HexCell = hex_grid.cells[coords]
		cell.set_exploration_state(HexCell.ExplorationState.UNEXPLORED, false)  # No transition on init
	
	_initialized = true
	_explored_count = 0
	_explored_today = 0
	_locations_discovered = 0
	
	var total_hexes := hex_grid.cells.size()
	fog_initialized.emit(total_hexes)
	_emit_to_event_bus("fog_initialized", [total_hexes])
	
	print("FogOfWarManager: Initialized with %d hexes" % total_hexes)


## Called after player spawns to reveal starting area.
func reveal_spawn_area(spawn_coords: Vector2i) -> void:
	if not _initialized:
		return
	
	# Calculate vision range
	_update_vision_range()
	
	# Reveal hexes within vision range + spawn bonus
	var reveal_radius := current_vision_range + spawn_bonus_radius
	var hexes_to_reveal := _get_hexes_in_radius(spawn_coords, reveal_radius)
	
	for coords in hexes_to_reveal:
		var cell: HexCell = hex_grid.get_cell(coords)
		if cell:
			var is_within_vision := HexUtils.distance(spawn_coords, coords) <= current_vision_range
			if is_within_vision:
				_set_hex_visible(cell, false)  # No transition on spawn
			else:
				_set_hex_explored(cell, false)  # Bonus area is explored but not visible
	
	_update_exploration_stats()
	print("FogOfWarManager: Revealed spawn area (radius %d, vision %d)" % [reveal_radius, current_vision_range])

# =============================================================================
# VISION CALCULATION
# =============================================================================

## Updates the current vision range based on time of day and weather.
func _update_vision_range() -> void:
	var old_range := current_vision_range
	var new_range := base_vision_range
	
	# Apply time of day modifier
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		var time_name: String = time_manager.get_time_of_day()
		var modifier: int = time_modifiers.get(time_name, 0)
		new_range += modifier
	
	# Apply weather visibility modifier
	var weather_manager = get_tree().get_first_node_in_group("weather_manager")
	if weather_manager and weather_manager.has_method("get_visibility_modifier"):
		var visibility: float = weather_manager.get_visibility_modifier()
		# visibility 1.0 = full range, 0.3 = 30% range
		new_range = int(round(float(new_range) * visibility))
	
	# Clamp to valid range
	new_range = clampi(new_range, min_vision_range, max_vision_range)
	
	if new_range != old_range:
		current_vision_range = new_range
		vision_range_changed.emit(old_range, new_range)
		_emit_to_event_bus("vision_range_changed", [old_range, new_range])
		print("FogOfWarManager: Vision range changed %d → %d" % [old_range, new_range])


## Gets the current vision range.
func get_vision_range() -> int:
	return current_vision_range


## Recalculates visible hexes from player position.
func update_vision() -> void:
	if not _initialized or player == null:
		return
	
	_update_vision_range()
	
	var player_pos := player.current_hex
	var new_visible := _get_hexes_in_radius(player_pos, current_vision_range)
	
	# Store previous visible for comparison
	previously_visible_hexes = currently_visible_hexes.duplicate()
	currently_visible_hexes.clear()
	
	# Mark new visible hexes
	for coords in new_visible:
		currently_visible_hexes[coords] = true
		var cell: HexCell = hex_grid.get_cell(coords)
		if cell:
			_set_hex_visible(cell, true)
	
	# Mark hexes that left vision as explored
	for coords in previously_visible_hexes:
		if not currently_visible_hexes.has(coords):
			var cell: HexCell = hex_grid.get_cell(coords)
			if cell and cell.exploration_state == HexCell.ExplorationState.VISIBLE:
				_set_hex_explored(cell, true)
	
	_update_exploration_stats()


## Gets all hexes within a radius of a center point.
func _get_hexes_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	
	for q in range(-radius, radius + 1):
		var r1 := maxi(-radius, -q - radius)
		var r2 := mini(radius, -q + radius)
		for r in range(r1, r2 + 1):
			var coords := Vector2i(center.x + q, center.y + r)
			if hex_grid.get_cell(coords) != null:
				hexes.append(coords)
	
	return hexes

# =============================================================================
# FOG STATE MANAGEMENT
# =============================================================================

## Sets a hex to visible state.
func _set_hex_visible(cell: HexCell, use_transition: bool) -> void:
	var was_unexplored := cell.exploration_state == HexCell.ExplorationState.UNEXPLORED
	
	cell.set_exploration_state(HexCell.ExplorationState.VISIBLE, use_transition and fog_enabled)
	
	if was_unexplored:
		_on_hex_first_explored(cell)
	
	hex_became_visible.emit(cell.axial_coords)
	_emit_to_event_bus("hex_became_visible", [cell.axial_coords])


## Sets a hex to explored state.
func _set_hex_explored(cell: HexCell, use_transition: bool) -> void:
	var was_unexplored := cell.exploration_state == HexCell.ExplorationState.UNEXPLORED
	
	cell.set_exploration_state(HexCell.ExplorationState.EXPLORED, use_transition and fog_enabled)
	
	if was_unexplored:
		_on_hex_first_explored(cell)
	
	hex_became_explored.emit(cell.axial_coords)
	_emit_to_event_bus("hex_became_explored", [cell.axial_coords])


## Called when a hex is explored for the first time.
func _on_hex_first_explored(cell: HexCell) -> void:
	_explored_count += 1
	_explored_today += 1
	
	# Check if hex has a location
	if cell.location != null:
		_locations_discovered += 1
	
	var time_manager = get_node_or_null("/root/TimeManager")
	var day := 1
	var turn := 1
	if time_manager:
		day = time_manager.current_day
		turn = time_manager.current_turn
	
	hex_first_explored.emit(cell.axial_coords, day, turn)
	_emit_to_event_bus("hex_first_explored", [cell.axial_coords, day, turn])

# =============================================================================
# EXPLORATION STATISTICS
# =============================================================================

## Updates and emits exploration statistics.
func _update_exploration_stats() -> void:
	var total := hex_grid.cells.size() if hex_grid else 0
	var percentage := float(_explored_count) / float(total) if total > 0 else 0.0
	
	exploration_stats_updated.emit(_explored_count, total, percentage)
	_emit_to_event_bus("exploration_stats_updated", [_explored_count, total, percentage])


## Gets the number of explored hexes.
func get_explored_count() -> int:
	return _explored_count


## Gets the total number of hexes.
func get_total_hexes() -> int:
	return hex_grid.cells.size() if hex_grid else 0


## Gets the exploration percentage (0.0 to 1.0).
func get_exploration_percentage() -> float:
	var total := get_total_hexes()
	return float(_explored_count) / float(total) if total > 0 else 0.0


## Gets hexes explored today.
func get_explored_today() -> int:
	return _explored_today


## Gets locations discovered count.
func get_locations_discovered() -> int:
	return _locations_discovered


## Gets full exploration stats as dictionary.
func get_exploration_stats() -> Dictionary:
	return {
		"explored": _explored_count,
		"total": get_total_hexes(),
		"percentage": get_exploration_percentage(),
		"explored_today": _explored_today,
		"locations_discovered": _locations_discovered
	}

# =============================================================================
# QUERY FUNCTIONS
# =============================================================================

## Checks if a hex is currently visible.
func is_hex_visible(coords: Vector2i) -> bool:
	var cell: HexCell = hex_grid.get_cell(coords) if hex_grid else null
	return cell != null and cell.exploration_state == HexCell.ExplorationState.VISIBLE


## Checks if a hex has been explored (visible or explored state).
func is_hex_explored(coords: Vector2i) -> bool:
	var cell: HexCell = hex_grid.get_cell(coords) if hex_grid else null
	return cell != null and cell.exploration_state != HexCell.ExplorationState.UNEXPLORED


## Checks if a hex is unexplored.
func is_hex_unexplored(coords: Vector2i) -> bool:
	var cell: HexCell = hex_grid.get_cell(coords) if hex_grid else null
	return cell == null or cell.exploration_state == HexCell.ExplorationState.UNEXPLORED

# =============================================================================
# DEBUG FUNCTIONS
# =============================================================================

## Reveals the entire map (debug).
func reveal_entire_map() -> void:
	if not _initialized:
		return
	
	for coords in hex_grid.cells:
		var cell: HexCell = hex_grid.cells[coords]
		if cell.exploration_state == HexCell.ExplorationState.UNEXPLORED:
			_set_hex_explored(cell, false)
	
	# Update vision to mark current area as visible
	update_vision()
	
	map_revealed_debug.emit()
	_emit_to_event_bus("map_revealed_debug", [])
	print("FogOfWarManager: Entire map revealed (debug)")


## Reveals hexes in a radius around a point (debug).
func reveal_radius(center: Vector2i, radius: int) -> void:
	if not _initialized:
		return
	
	var hexes := _get_hexes_in_radius(center, radius)
	for coords in hexes:
		var cell: HexCell = hex_grid.get_cell(coords)
		if cell and cell.exploration_state == HexCell.ExplorationState.UNEXPLORED:
			_set_hex_explored(cell, true)
	
	update_vision()
	print("FogOfWarManager: Revealed radius %d around %s" % [radius, center])


## Toggles fog rendering on/off (debug).
func toggle_fog(enabled: bool) -> void:
	fog_enabled = enabled
	
	# Update all hex fog overlays
	for coords in hex_grid.cells:
		var cell: HexCell = hex_grid.cells[coords]
		cell.set_fog_visible(enabled)
	
	fog_debug_toggled.emit(enabled)
	_emit_to_event_bus("fog_debug_toggled", [enabled])
	print("FogOfWarManager: Fog %s" % ("enabled" if enabled else "disabled"))


## Resets all hexes to unexplored (debug).
func reset_fog() -> void:
	if not _initialized:
		return
	
	for coords in hex_grid.cells:
		var cell: HexCell = hex_grid.cells[coords]
		cell.set_exploration_state(HexCell.ExplorationState.UNEXPLORED, false)
		cell.first_discovered_day = -1
		cell.first_discovered_turn = -1
	
	currently_visible_hexes.clear()
	previously_visible_hexes.clear()
	_explored_count = 0
	_explored_today = 0
	_locations_discovered = 0
	
	# Re-reveal area around player
	if player:
		reveal_spawn_area(player.current_hex)
	
	_update_exploration_stats()
	print("FogOfWarManager: Fog reset")

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_turn_started(turn: int, day: int, time_name: String) -> void:
	# Vision range may have changed with time of day
	var old_range := current_vision_range
	_update_vision_range()
	
	if current_vision_range != old_range:
		update_vision()


func _on_day_started(day: int) -> void:
	_current_day = day
	_explored_today = 0
	_update_exploration_stats()


func _on_player_moved_to_hex(coords: Vector2i) -> void:
	if reveal_during_movement:
		update_vision()


func _on_player_spawned(coords: Vector2i) -> void:
	reveal_spawn_area(coords)


func _on_weather_changed(_weather_type: String, _duration: int) -> void:
	# Weather started - recalculate vision range
	var old_range := current_vision_range
	_update_vision_range()
	
	if current_vision_range != old_range:
		update_vision()


func _on_weather_ended(_weather_type: String) -> void:
	# Weather ended - recalculate vision range
	var old_range := current_vision_range
	_update_vision_range()
	
	if current_vision_range != old_range:
		update_vision()

# =============================================================================
# SERIALIZATION
# =============================================================================

## Converts fog state to dictionary for saving.
func to_dict() -> Dictionary:
	var explored_hexes: Array[Dictionary] = []
	
	for coords in hex_grid.cells:
		var cell: HexCell = hex_grid.cells[coords]
		if cell.exploration_state != HexCell.ExplorationState.UNEXPLORED:
			explored_hexes.append({
				"q": coords.x,
				"r": coords.y,
				"discovered_day": cell.first_discovered_day,
				"discovered_turn": cell.first_discovered_turn
			})
	
	return {
		"explored_hexes": explored_hexes,
		"explored_today": _explored_today,
		"current_day": _current_day,
		"locations_discovered": _locations_discovered
	}


## Loads fog state from dictionary.
func from_dict(data: Dictionary) -> void:
	if not _initialized:
		push_warning("FogOfWarManager: Cannot load fog state before initialization")
		return
	
	# Reset all hexes to unexplored first
	for coords in hex_grid.cells:
		var cell: HexCell = hex_grid.cells[coords]
		cell.set_exploration_state(HexCell.ExplorationState.UNEXPLORED, false)
		cell.first_discovered_day = -1
		cell.first_discovered_turn = -1
	
	_explored_count = 0
	currently_visible_hexes.clear()
	
	# Load explored hexes
	var explored_hexes: Array = data.get("explored_hexes", [])
	for hex_data in explored_hexes:
		var coords := Vector2i(hex_data.get("q", 0), hex_data.get("r", 0))
		var cell: HexCell = hex_grid.get_cell(coords)
		if cell:
			cell.set_exploration_state(HexCell.ExplorationState.EXPLORED, false)
			cell.first_discovered_day = hex_data.get("discovered_day", -1)
			cell.first_discovered_turn = hex_data.get("discovered_turn", -1)
			_explored_count += 1
			
			if cell.location != null:
				_locations_discovered += 1
	
	_explored_today = data.get("explored_today", 0)
	_current_day = data.get("current_day", 1)
	
	# Recalculate visible from player position
	if player:
		update_vision()
	
	_update_exploration_stats()
	print("FogOfWarManager: Loaded fog state (%d explored hexes)" % _explored_count)

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
