# player.gd
# Represents the player character on the hex map.
# Handles position, movement animation, state tracking, and stats.
#
# The player is visualized as a simple meeple/pawn shape.
# Movement is animated smoothly between hexes.
#
# STRUCTURE:
# Player (this script, Node2D)
# ├── PlayerStats (player_stats.gd)
# ├── SkillManager (skill_manager.gd)
# └── TalentManager (talent_manager.gd)

extends Node2D
class_name Player

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when movement animation starts.
signal movement_started(path: Array[Vector2i])

## Emitted when player moves to a new hex during animation.
signal moved_to_hex(hex_coords: Vector2i)

## Emitted when movement animation completes.
signal movement_completed(total_hexes: int, total_turns: int)

## Emitted when movement is cancelled or fails.
signal movement_failed(reason: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Player display name.
@export var player_name: String = "Wanderer"

## Color of the player token.
@export var token_color: Color = Color(0.2, 0.6, 0.9)

## Outline color for visibility.
@export var outline_color: Color = Color(0.1, 0.1, 0.15)

## Size of the player token relative to hex size.
@export var token_scale: float = 0.5

# =============================================================================
# STATE
# =============================================================================

## Current hex position in axial coordinates.
var current_hex: Vector2i = Vector2i.ZERO:
	set(value):
		current_hex = value
		_update_pixel_position()

## Whether the player is currently moving.
var is_moving: bool = false

## Current movement path (array of Vector2i).
var _current_path: Array[Vector2i] = []

## Current index in movement path.
var _path_index: int = 0

## Total turn cost of current movement.
var _movement_turn_cost: int = 0

## Reference to hex grid for coordinate conversion.
var _hex_grid: HexGrid = null

## Reference to hex size for rendering.
var _hex_size: float = 64.0

# =============================================================================
# CHILD REFERENCES
# =============================================================================

## Reference to PlayerStats child node.
@onready var player_stats: Node = $PlayerStats

## Reference to SkillManager child node.
@onready var skill_manager: Node = $SkillManager

## Reference to TalentManager child node.
@onready var talent_manager: Node = $TalentManager

# =============================================================================
# EQUIPMENT SYSTEM
# =============================================================================

## Weapon ID equipped in slot 1 (empty string if none).
var equipped_slot_1: String = ""

## Weapon ID equipped in slot 2 (empty string if none).
var equipped_slot_2: String = ""

## Active equipment slot (0 for slot 1, 1 for slot 2).
var active_slot: int = 0

## Emitted when a weapon is equipped to a slot.
signal weapon_equipped(slot: int, weapon_id: String)

## Emitted when a weapon is unequipped from a slot.
signal weapon_unequipped(slot: int)

## Emitted when the active slot changes.
signal active_slot_changed(new_slot: int)

# =============================================================================
# STUB DATA (for future systems)
# =============================================================================

## Player inventory (stub for future).
var inventory: Array = []

## Active status effects (stub for future).
var status_effects: Array = []

## Current action state.
var current_action: String = "idle"

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _token: Node2D
var _token_body: Polygon2D
var _token_outline: Line2D
var _token_head: Polygon2D
var _shadow: Polygon2D
var _tween: Tween

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("player")
	_create_token()
	_setup_child_systems()
	z_index = 10  # Above terrain and locations


func _setup_child_systems() -> void:
	# PlayerStats
	if not player_stats:
		player_stats = _create_child_system("res://scripts/player/player_stats.gd", "PlayerStats")
	if player_stats:
		print("Player: PlayerStats ready")
	
	# SkillManager
	if not skill_manager:
		skill_manager = _create_child_system("res://scripts/player/skill_manager.gd", "SkillManager")
	if skill_manager:
		print("Player: SkillManager ready")
	
	# TalentManager
	if not talent_manager:
		talent_manager = _create_child_system("res://scripts/player/talent_manager.gd", "TalentManager")
	if talent_manager:
		print("Player: TalentManager ready")


## Helper to dynamically create a child system if not present in scene.
func _create_child_system(script_path: String, node_name: String) -> Node:
	var script = load(script_path)
	if script:
		var instance = script.new()
		instance.name = node_name
		add_child(instance)
		print("Player: Created %s dynamically" % node_name)
		return instance
	else:
		push_warning("Player: Could not load %s" % script_path)
		return null


## Initializes the player with grid reference and starting position.
func initialize(hex_grid: HexGrid, start_hex: Vector2i) -> void:
	_hex_grid = hex_grid
	_hex_size = hex_grid.hex_size
	
	# Rebuild token at correct size
	_rebuild_token()
	
	# Set initial position
	teleport_to_hex(start_hex)
	
	print("Player: Initialized at hex %s" % start_hex)


func _create_token() -> void:
	# Container for all token parts
	_token = Node2D.new()
	_token.name = "Token"
	add_child(_token)
	
	# Shadow (slightly offset, semi-transparent)
	_shadow = Polygon2D.new()
	_shadow.name = "Shadow"
	_shadow.color = Color(0, 0, 0, 0.3)
	_shadow.position = Vector2(3, 3)
	_token.add_child(_shadow)
	
	# Main body (meeple shape)
	_token_body = Polygon2D.new()
	_token_body.name = "Body"
	_token_body.color = token_color
	_token.add_child(_token_body)
	
	# Outline
	_token_outline = Line2D.new()
	_token_outline.name = "Outline"
	_token_outline.default_color = outline_color
	_token_outline.width = 2.0
	_token_outline.closed = true
	_token.add_child(_token_outline)
	
	# Head (circle on top)
	_token_head = Polygon2D.new()
	_token_head.name = "Head"
	_token_head.color = token_color.lightened(0.2)
	_token.add_child(_token_head)
	
	_rebuild_token()


func _rebuild_token() -> void:
	var size := _hex_size * token_scale
	var half_size := size * 0.5
	
	# Meeple body shape (wider at bottom, narrower at top)
	var body_points := PackedVector2Array([
		Vector2(-half_size * 0.8, half_size),      # Bottom left
		Vector2(-half_size * 0.5, 0),              # Left middle
		Vector2(-half_size * 0.3, -half_size * 0.3), # Left shoulder
		Vector2(0, -half_size * 0.5),              # Top center (neck)
		Vector2(half_size * 0.3, -half_size * 0.3),  # Right shoulder
		Vector2(half_size * 0.5, 0),               # Right middle
		Vector2(half_size * 0.8, half_size)        # Bottom right
	])
	
	_token_body.polygon = body_points
	_shadow.polygon = body_points
	
	# Outline points (same as body, closed)
	var outline_points := PackedVector2Array(body_points)
	outline_points.append(body_points[0])
	_token_outline.points = outline_points
	
	# Head (circle at top)
	var head_radius := half_size * 0.35
	var head_center := Vector2(0, -half_size * 0.7)
	var head_points := PackedVector2Array()
	var segments := 12
	for i in range(segments):
		var angle := float(i) / float(segments) * TAU
		head_points.append(head_center + Vector2(cos(angle), sin(angle)) * head_radius)
	_token_head.polygon = head_points

# =============================================================================
# STATS ACCESS (convenience methods)
# =============================================================================

## Get the PlayerStats node.
func get_stats() -> Node:
	return player_stats


## Get an effective stat value by name.
func get_stat(stat_name: String) -> int:
	if player_stats and player_stats.has_method("get_effective_stat"):
		return player_stats.get_effective_stat(stat_name)
	return 0


## Get a base stat value by name.
func get_base_stat(stat_name: String) -> int:
	if player_stats and player_stats.has_method("get_base_stat"):
		return player_stats.get_base_stat(stat_name)
	return 0


## Perform a stat check (d10 + stat vs difficulty).
func roll_check(stat_name: String, difficulty) -> Dictionary:
	if player_stats and player_stats.has_method("roll_check"):
		return player_stats.roll_check(stat_name, difficulty)
	return {
		"success": false,
		"roll": 0,
		"stat_name": stat_name,
		"stat_value": 0,
		"total": 0,
		"difficulty": difficulty if difficulty is int else 12,
		"margin": -(difficulty if difficulty is int else 12)
	}


## Get max HP (derived from Grit).
func get_max_hp() -> int:
	if player_stats and player_stats.has_method("get_max_hp"):
		return player_stats.get_max_hp()
	return 20  # Default fallback


## Add a stat modifier.
func add_stat_modifier(source: String, stat: String, type: String, value: int) -> void:
	if player_stats and player_stats.has_method("add_modifier"):
		player_stats.add_modifier(source, stat, type, value)


## Remove a stat modifier by source.
func remove_stat_modifier(source: String) -> void:
	if player_stats and player_stats.has_method("remove_modifier"):
		player_stats.remove_modifier(source)

# =============================================================================
# SKILLS ACCESS (convenience methods)
# =============================================================================

## Get the SkillManager node.
func get_skill_manager() -> Node:
	return skill_manager


## Get a skill level by name.
func get_skill_level(skill_name: String) -> int:
	if skill_manager and skill_manager.has_method("get_skill_level"):
		return skill_manager.get_skill_level(skill_name)
	return 0


## Grant XP to a skill.
func grant_skill_xp(skill_name: String, action: String, difficulty: String = "moderate") -> int:
	if skill_manager and skill_manager.has_method("grant_xp"):
		return skill_manager.grant_xp(skill_name, action, difficulty)
	return 0


## Perform a skill check (d10 + linked_stat + skill_level vs difficulty).
func roll_skill_check(skill_name: String, difficulty, grant_xp_on_success: bool = true) -> Dictionary:
	if skill_manager and skill_manager.has_method("roll_skill_check"):
		return skill_manager.roll_skill_check(skill_name, difficulty, grant_xp_on_success)
	# Fallback to plain stat check if no skill manager
	return roll_check("wit", difficulty)


## Check if a skill has a pending level up (needs trainer).
func has_pending_skill_level_up(skill_name: String) -> bool:
	if skill_manager and skill_manager.has_method("has_pending_level_up"):
		return skill_manager.has_pending_level_up(skill_name)
	return false

# =============================================================================
# TALENTS ACCESS (convenience methods)
# =============================================================================

## Get the TalentManager node.
func get_talent_manager() -> Node:
	return talent_manager


## Check if player has a specific talent.
func has_talent(talent_id: String) -> bool:
	if talent_manager and talent_manager.has_method("has_talent"):
		return talent_manager.has_talent(talent_id)
	return false


## Get all acquired talents.
func get_talents() -> Array[String]:
	if talent_manager and talent_manager.has_method("get_all_talents"):
		return talent_manager.get_all_talents()
	return []


## Activate a talent's special ability.
func activate_talent(talent_id: String, context: Dictionary = {}) -> Dictionary:
	if talent_manager and talent_manager.has_method("activate_talent"):
		return talent_manager.activate_talent(talent_id, context)
	return {"success": false, "reason": "no_talent_manager"}

# =============================================================================
# EQUIPMENT MANAGEMENT
# =============================================================================

## Equips a weapon to the specified slot (0 or 1).
## @param weapon_id: String - ID of weapon from weapons.json
## @param slot: int - Equipment slot (0 = slot 1, 1 = slot 2)
## @return bool - True if equipped successfully
func equip_weapon(weapon_id: String, slot: int) -> bool:
	if slot < 0 or slot > 1:
		push_warning("Player: Invalid equipment slot: %d" % slot)
		return false

	# Validate weapon exists in weapons.json
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var weapons_data: Dictionary = loader.load_json("res://data/combat/weapons.json")
		if not weapons_data.get("weapons", {}).has(weapon_id):
			push_warning("Player: Unknown weapon ID: %s" % weapon_id)
			return false

	# Equip the weapon
	if slot == 0:
		equipped_slot_1 = weapon_id
	else:
		equipped_slot_2 = weapon_id

	weapon_equipped.emit(slot, weapon_id)
	_emit_to_event_bus("weapon_equipped", [slot, weapon_id])

	print("Player: Equipped %s to slot %d" % [weapon_id, slot + 1])
	return true


## Unequips a weapon from the specified slot.
## @param slot: int - Equipment slot (0 = slot 1, 1 = slot 2)
func unequip_weapon(slot: int) -> void:
	if slot < 0 or slot > 1:
		push_warning("Player: Invalid equipment slot: %d" % slot)
		return

	if slot == 0:
		equipped_slot_1 = ""
	else:
		equipped_slot_2 = ""

	weapon_unequipped.emit(slot)
	_emit_to_event_bus("weapon_unequipped", [slot])

	print("Player: Unequipped slot %d" % (slot + 1))


## Gets the weapon ID equipped in the specified slot.
## @param slot: int - Equipment slot (0 = slot 1, 1 = slot 2)
## @return String - Weapon ID or empty string if none equipped
func get_equipped_weapon(slot: int) -> String:
	if slot == 0:
		return equipped_slot_1
	elif slot == 1:
		return equipped_slot_2
	return ""


## Gets the weapon ID of the currently active equipment slot.
## @return String - Weapon ID or empty string if none equipped
func get_active_weapon() -> String:
	return get_equipped_weapon(active_slot)


## Gets the full weapon data for the currently active weapon.
## @return Dictionary - Weapon data from weapons.json, or unarmed data if none equipped
func get_active_weapon_data() -> Dictionary:
	var weapon_id: String = get_active_weapon()

	print("Player.get_active_weapon_data(): slot %d = '%s'" % [active_slot, weapon_id])
	print("  equipped_slot_1 = '%s'" % equipped_slot_1)
	print("  equipped_slot_2 = '%s'" % equipped_slot_2)

	# If no weapon equipped, return unarmed combat data
	if weapon_id.is_empty():
		weapon_id = "unarmed"
		print("  -> Using unarmed (no weapon equipped)")

	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var weapons_data: Dictionary = loader.load_json("res://data/combat/weapons.json")
		var weapons: Dictionary = weapons_data.get("weapons", {})
		if weapons.has(weapon_id):
			print("  -> Loaded weapon data for: %s" % weapon_id)
			return weapons[weapon_id]
		else:
			push_warning("Player: Weapon '%s' not found in weapons.json" % weapon_id)

	# Fallback unarmed data if loading fails
	print("  -> Using fallback unarmed data")
	return {
		"id": "unarmed",
		"name": "Unarmed",
		"weapon_type": "melee",
		"stat_used": "grit",
		"skill_used": "brawling",
		"damage_min": 1,
		"damage_max": 2,
		"range": 1,
		"ap_cost": 1,
		"hands_required": 1
	}


## Switches the active equipment slot (free action, no AP cost).
func switch_active_slot() -> void:
	# Toggle between 0 and 1
	active_slot = 1 - active_slot

	active_slot_changed.emit(active_slot)
	_emit_to_event_bus("active_slot_changed", [active_slot])

	var weapon_name: String = "None"
	var weapon_id: String = get_active_weapon()
	if not weapon_id.is_empty():
		var weapon_data: Dictionary = get_active_weapon_data()
		weapon_name = weapon_data.get("name", weapon_id)

	print("Player: Switched to slot %d (%s)" % [active_slot + 1, weapon_name])


## Checks if the player has any weapon equipped in either slot.
## @return bool - True if at least one slot has a weapon
func has_weapon_equipped() -> bool:
	return not equipped_slot_1.is_empty() or not equipped_slot_2.is_empty()


## Gets the number of equipped weapons.
## @return int - Number of weapons equipped (0-2)
func get_equipped_weapon_count() -> int:
	var count: int = 0
	if not equipped_slot_1.is_empty():
		count += 1
	if not equipped_slot_2.is_empty():
		count += 1
	return count

# =============================================================================
# POSITION MANAGEMENT
# =============================================================================

## Instantly moves the player to a hex without animation.
func teleport_to_hex(target_hex: Vector2i) -> void:
	current_hex = target_hex
	is_moving = false
	_current_path.clear()
	_path_index = 0
	
	_emit_to_event_bus("player_position_changed", [current_hex])


## Updates the visual position based on current hex.
func _update_pixel_position() -> void:
	if _hex_grid:
		position = HexUtils.axial_to_pixel(current_hex, _hex_size)
	else:
		position = HexUtils.axial_to_pixel(current_hex, _hex_size)


## Gets the pixel position for a hex coordinate.
func get_pixel_position_for_hex(hex_coords: Vector2i) -> Vector2:
	return HexUtils.axial_to_pixel(hex_coords, _hex_size)

# =============================================================================
# MOVEMENT
# =============================================================================

## Starts movement along a path.
## @param path: Array[Vector2i] - Hexes to move through (including start).
## @param turn_cost: int - Total turn cost of the movement.
func move_along_path(path: Array[Vector2i], turn_cost: int) -> void:
	if path.size() < 2:
		movement_failed.emit("Path too short")
		return
	
	if is_moving:
		movement_failed.emit("Already moving")
		return
	
	is_moving = true
	current_action = "moving"
	_current_path = path
	_path_index = 0
	_movement_turn_cost = turn_cost
	
	movement_started.emit(path)
	_emit_to_event_bus("player_movement_started", [path[0], path[path.size() - 1]])
	
	# Start moving to first waypoint (skip index 0 which is current position)
	_move_to_next_waypoint()


## Moves to the next hex in the current path.
func _move_to_next_waypoint() -> void:
	_path_index += 1
	
	if _path_index >= _current_path.size():
		_complete_movement()
		return
	
	var next_hex: Vector2i = _current_path[_path_index]
	var next_pixel := get_pixel_position_for_hex(next_hex)
	
	# Get animation speed from config or use default
	var anim_speed := 0.25
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_map_config("movement_config")
		anim_speed = config.get("movement_animation_speed", 0.25)
	
	# Cancel any existing tween
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Create movement tween
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "position", next_pixel, anim_speed)
	_tween.tween_callback(_on_waypoint_reached.bind(next_hex))


## Called when player reaches a waypoint.
func _on_waypoint_reached(hex_coords: Vector2i) -> void:
	current_hex = hex_coords
	
	moved_to_hex.emit(hex_coords)
	_emit_to_event_bus("player_moved_to_hex", [hex_coords])
	
	# Check if encounter was triggered (it listens to player_moved_to_hex)
	# If so, pause movement until encounter resolves
	var encounter_manager = get_tree().get_first_node_in_group("encounter_manager")
	if encounter_manager and encounter_manager.is_encounter_active():
		_pause_movement_for_encounter()
		return
	
	# Continue to next waypoint
	_move_to_next_waypoint()


## Pauses movement during an encounter.
func _pause_movement_for_encounter() -> void:
	# Connect to encounter close to resume
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and not event_bus.encounter_ui_closed.is_connected(_on_encounter_closed_resume):
		event_bus.encounter_ui_closed.connect(_on_encounter_closed_resume, CONNECT_ONE_SHOT)


## Resume movement after encounter closes.
func _on_encounter_closed_resume() -> void:
	# Check if we still have path to complete
	if is_moving and _path_index < _current_path.size():
		# Small delay before resuming
		await get_tree().create_timer(0.2).timeout
		_move_to_next_waypoint()
	else:
		_complete_movement()


## Completes the movement and emits signals.
func _complete_movement() -> void:
	var hexes_moved := _current_path.size() - 1
	var turn_cost := _movement_turn_cost
	
	is_moving = false
	current_action = "idle"
	
	# Advance time
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and turn_cost > 0:
		time_manager.advance_turn(turn_cost)
	
	movement_completed.emit(hexes_moved, turn_cost)
	_emit_to_event_bus("player_movement_completed", [hexes_moved, turn_cost])
	
	_current_path.clear()
	_path_index = 0
	_movement_turn_cost = 0
	
	print("Player: Movement complete (%d hexes, %d turns)" % [hexes_moved, turn_cost])


## Cancels current movement (if any).
func cancel_movement() -> void:
	if not is_moving:
		return
	
	if _tween and _tween.is_valid():
		_tween.kill()
	
	is_moving = false
	current_action = "idle"
	_current_path.clear()
	_path_index = 0
	
	movement_failed.emit("Movement cancelled")

# =============================================================================
# VISUAL UPDATES
# =============================================================================

## Sets the token color.
func set_token_color(color: Color) -> void:
	token_color = color
	if _token_body:
		_token_body.color = color
	if _token_head:
		_token_head.color = color.lightened(0.2)


## Pulses the token (for attention).
func pulse() -> void:
	if _tween and _tween.is_valid():
		return  # Don't interrupt movement
	
	var tween := create_tween()
	tween.tween_property(_token, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(_token, "scale", Vector2(1.0, 1.0), 0.15)

# =============================================================================
# SERIALIZATION
# =============================================================================

## Converts player state to a dictionary for saving.
func to_dict() -> Dictionary:
	var data := {
		"name": player_name,
		"current_hex": {"q": current_hex.x, "r": current_hex.y},
		"inventory": inventory,
		"status_effects": status_effects,
		"equipment": {
			"slot_1": equipped_slot_1,
			"slot_2": equipped_slot_2,
			"active_slot": active_slot
		}
	}

	# Include PlayerStats if available
	if player_stats and player_stats.has_method("to_dict"):
		data["stats"] = player_stats.to_dict()

	# Include SkillManager if available
	if skill_manager and skill_manager.has_method("to_dict"):
		data["skills"] = skill_manager.to_dict()

	# Include TalentManager if available
	if talent_manager and talent_manager.has_method("to_dict"):
		data["talents"] = talent_manager.to_dict()

	return data


## Loads player state from a dictionary.
func from_dict(data: Dictionary, hex_grid: HexGrid) -> void:
	_hex_grid = hex_grid
	_hex_size = hex_grid.hex_size

	player_name = data.get("name", "Wanderer")

	var hex_data: Dictionary = data.get("current_hex", {"q": 0, "r": 0})
	var loaded_hex := Vector2i(hex_data.get("q", 0), hex_data.get("r", 0))

	inventory = data.get("inventory", [])
	status_effects = data.get("status_effects", [])

	# Load equipment
	if data.has("equipment"):
		var equipment: Dictionary = data.get("equipment", {})
		equipped_slot_1 = equipment.get("slot_1", "")
		equipped_slot_2 = equipment.get("slot_2", "")
		active_slot = equipment.get("active_slot", 0)

	# Load PlayerStats if available
	if player_stats and player_stats.has_method("from_dict") and data.has("stats"):
		player_stats.from_dict(data["stats"])

	# Load SkillManager if available
	if skill_manager and skill_manager.has_method("from_dict") and data.has("skills"):
		skill_manager.from_dict(data["skills"])

	# Load TalentManager if available
	if talent_manager and talent_manager.has_method("from_dict") and data.has("talents"):
		talent_manager.from_dict(data["talents"])

	_rebuild_token()
	teleport_to_hex(loaded_hex)

	print("Player: Loaded at hex %s" % loaded_hex)

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
