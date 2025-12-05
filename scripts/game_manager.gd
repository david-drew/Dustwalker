# game_manager.gd
# Orchestrates game initialization and connects all systems.
# Handles the startup sequence: Map → Player spawn → Camera focus.
#
# Attach to a node in the Main scene, or use as a script component.

extends Node
class_name GameManager

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when game initialization is complete.
signal game_ready()

## Emitted when a new game starts.
signal new_game_started()

## Emitted when a game is loaded.
signal game_loaded()

# =============================================================================
# REFERENCES
# =============================================================================

## Reference to the hex grid.
var hex_grid: HexGrid = null

## Reference to the movement controller.
var movement_controller: MovementController = null

## Reference to the player spawner.
var player_spawner: PlayerSpawner = null

## Reference to the player.
var player: Player = null

## Reference to the map camera.
var map_camera: Camera2D = null

## Reference to the turn panel.
var turn_panel: TurnPanel = null

## Reference to the fog of war manager.
var fog_manager: FogOfWarManager = null

## Reference to the survival manager.
var survival_manager: SurvivalManager = null

## Reference to the inventory manager.
var inventory_manager: InventoryManager = null

## Reference to the encounter manager.
var encounter_manager: EncounterManager = null

## Reference to UI panels.
var survival_panel: SurvivalPanel = null
var inventory_panel: InventoryPanel = null
var encounter_window: EncounterWindow = null
var game_over_screen: GameOverScreen = null

# =============================================================================
# STATE
# =============================================================================

## Whether the game has been initialized.
var is_initialized: bool = false

## Whether the player is ready.
var player_ready: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	_find_references()
	_connect_signals()
	_initialize_game()


func _find_references() -> void:
	# Find hex grid
	hex_grid = get_tree().get_first_node_in_group("hex_grid") as HexGrid
	if hex_grid == null:
		hex_grid = get_node_or_null("../HexGrid") as HexGrid
	
	# Find movement controller
	movement_controller = get_tree().get_first_node_in_group("movement_controller") as MovementController
	if movement_controller == null:
		movement_controller = get_node_or_null("../../MovementController") as MovementController
	
	# Find player spawner
	player_spawner = get_tree().get_first_node_in_group("player_spawner") as PlayerSpawner
	if player_spawner == null:
		player_spawner = get_node_or_null("../../PlayerSpawner") as PlayerSpawner
	
	# Find fog of war manager
	fog_manager = get_tree().get_first_node_in_group("fog_manager") as FogOfWarManager
	if fog_manager == null:
		fog_manager = get_node_or_null("../../FogOfWarManager") as FogOfWarManager
	
	# Find survival manager
	survival_manager = get_tree().get_first_node_in_group("survival_manager") as SurvivalManager
	if survival_manager == null:
		survival_manager = get_node_or_null("../../SurvivalManager") as SurvivalManager
	
	# Find inventory manager
	inventory_manager = get_tree().get_first_node_in_group("inventory_manager") as InventoryManager
	if inventory_manager == null:
		inventory_manager = get_node_or_null("../../InventoryManager") as InventoryManager
	
	# Find encounter manager
	encounter_manager = get_tree().get_first_node_in_group("encounter_manager") as EncounterManager
	if encounter_manager == null:
		encounter_manager = get_node_or_null("../../EncounterManager") as EncounterManager
	
	# Find camera
	map_camera = get_tree().get_first_node_in_group("map_camera") as Camera2D
	if map_camera == null:
		map_camera = get_node_or_null("../MapCamera") as Camera2D
	
	# Find UI panels
	turn_panel = get_node_or_null("../../UI/TurnPanel") as TurnPanel
	survival_panel = get_node_or_null("../../UI/SurvivalPanel") as SurvivalPanel
	inventory_panel = get_node_or_null("../../UI/InventoryPanel") as InventoryPanel
	encounter_window = get_node_or_null("../../UI/EncounterWindow") as EncounterWindow
	game_over_screen = get_node_or_null("../../UI/GameOverScreen") as GameOverScreen


func _connect_signals() -> void:
	# Connect hex cell clicks for movement
	if hex_grid:
		hex_grid.hex_clicked.connect(_on_hex_clicked)
	
	# Connect player movement events
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("player_movement_completed"):
			event_bus.player_movement_completed.connect(_on_player_movement_completed)
		if event_bus.has_signal("encounter_ui_opened"):
			event_bus.encounter_ui_opened.connect(_on_encounter_opened)
		if event_bus.has_signal("encounter_ui_closed"):
			event_bus.encounter_ui_closed.connect(_on_encounter_closed)
		# Combat signals
		if event_bus.has_signal("combat_started"):
			event_bus.combat_started.connect(_on_combat_started)
		if event_bus.has_signal("combat_ended"):
			event_bus.combat_ended.connect(_on_combat_ended)
	
	# Connect game over screen
	if game_over_screen:
		game_over_screen.load_save_requested.connect(_on_load_save_requested)
		game_over_screen.restart_requested.connect(_on_restart_requested)


func _initialize_game() -> void:
	print("GameManager: Initializing game...")
	
	if hex_grid == null:
		push_error("GameManager: HexGrid not found!")
		return
	
	if movement_controller == null:
		push_error("GameManager: MovementController not found!")
		return
	
	if player_spawner == null:
		push_error("GameManager: PlayerSpawner not found!")
		return
	
	# Wait for map generation to complete if needed
	await get_tree().process_frame
	
	# Initialize fog of war (before player spawn so fog is in place)
	if fog_manager:
		fog_manager.initialize(hex_grid, null)  # Player ref added after spawn
	
	# Initialize survival and inventory systems
	#if survival_manager:		survival_manager.initialize()
	
	if inventory_manager and survival_manager:
		inventory_manager.initialize(survival_manager)
	
	# Initialize encounter manager
	if encounter_manager:
		encounter_manager.initialize(hex_grid, survival_manager, inventory_manager)
		if encounter_window:
			encounter_manager.set_encounter_window(encounter_window)
	
	# Initialize UI panels
	if survival_panel and survival_manager:
		survival_panel.initialize(survival_manager)
	
	if inventory_panel and inventory_manager and survival_manager:
		inventory_panel.initialize(inventory_manager, survival_manager)
	
	# Spawn the player
	player = player_spawner.spawn_player(hex_grid, movement_controller)
	
	if player:
		player_ready = true
		
		# Update fog manager with player reference
		if fog_manager:
			fog_manager.player = player
			fog_manager.reveal_spawn_area(player.current_hex)
		
		# Focus camera on player
		if map_camera:
			_center_camera_on_player()
		
		# Connect player signals
		player.movement_completed.connect(_on_player_local_movement_completed)
	
	is_initialized = true
	game_ready.emit()
	new_game_started.emit()
	
	print("GameManager: Game ready!")

# =============================================================================
# MOVEMENT HANDLING
# =============================================================================

func _on_hex_clicked(coords: Vector2i) -> void:
	if not is_initialized or not player_ready:
		return
	
	# Block during encounters or combat
	if _encounter_active or _combat_active:
		return
	
	if player and player.is_moving:
		return
	
	# Request movement to clicked hex
	var result := movement_controller.request_movement(coords)
	
	match result["action"]:
		"moved":
			print("GameManager: Movement confirmed")
		"preview":
			print("GameManager: Path preview - %d hexes, %d turns" % [
				result["path"].size() - 1,
				result["cost"]
			])
		"invalid":
			print("GameManager: Invalid destination - %s" % result["reason"])


func _on_player_movement_completed(total_hexes: int, total_turns: int) -> void:
	# Camera follow after movement
	if map_camera and player:
		_smooth_camera_to_player()


func _on_player_local_movement_completed(total_hexes: int, total_turns: int) -> void:
	pass  # Handled by event bus version

# =============================================================================
# CAMERA CONTROL
# =============================================================================

func _center_camera_on_player() -> void:
	if map_camera == null or player == null:
		return
	
	map_camera.position = player.position


func _smooth_camera_to_player() -> void:
	if map_camera == null or player == null:
		return
	
	# Check if camera follow is enabled
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_map_config("movement_config")
		if not config.get("camera_follow_player", true):
			return
	
	# Smooth tween to player position
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(map_camera, "position", player.position, 0.3)

# =============================================================================
# GAME STATE
# =============================================================================

## Starts a new game with a new map.
func start_new_game(map_seed: int = 0) -> void:
	print("GameManager: Starting new game...")
	
	# Reset time
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.reset_time()
	
	# Generate new map
	if hex_grid:
		hex_grid.generate_complete_map(map_seed)
	
	# Respawn player
	if player_spawner:
		if player_spawner.has_player():
			player_spawner.respawn_player()
		else:
			player = player_spawner.spawn_player(hex_grid, movement_controller)
	
	# Center camera
	if player and map_camera:
		_center_camera_on_player()
	
	player_ready = true
	new_game_started.emit()


## Loads a game from a save file.
func load_game(file_path: String) -> bool:
	print("GameManager: Loading game from %s..." % file_path)
	
	if hex_grid == null:
		return false
	
	# Load map (this also loads player data if present)
	var loaded_seed := hex_grid.load_map(file_path)
	
	if loaded_seed < 0:
		push_error("GameManager: Failed to load map")
		return false
	
	# TODO: Load player position from save data
	# For now, respawn player
	if player_spawner and player_spawner.has_player():
		player_spawner.respawn_player()
	
	# Center camera
	if player and map_camera:
		_center_camera_on_player()
	
	game_loaded.emit()
	return true


## Saves the current game.
func save_game(filename: String = "") -> String:
	if hex_grid == null:
		return ""
	
	# TODO: Include player data in save
	return hex_grid.save_map(filename)

# =============================================================================
# ENCOUNTER HANDLING
# =============================================================================

var _encounter_active: bool = false

func _on_encounter_opened() -> void:
	_encounter_active = true


func _on_encounter_closed() -> void:
	_encounter_active = false

# =============================================================================
# COMBAT HANDLING
# =============================================================================

var _combat_active: bool = false

func _on_combat_started() -> void:
	_combat_active = true


func _on_combat_ended(_victory: bool, _loot: Dictionary) -> void:
	_combat_active = false

# =============================================================================
# GAME OVER HANDLING
# =============================================================================

func _on_load_save_requested() -> void:
	# Find most recent save and load it
	var dir := DirAccess.open("user://saves/maps/")
	if dir == null:
		return
	
	var newest_file := ""
	var newest_time := 0
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path := "user://saves/maps/" + file_name
			var mod_time := FileAccess.get_modified_time(full_path)
			if mod_time > newest_time:
				newest_time = mod_time
				newest_file = full_path
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if newest_file != "":
		load_game(newest_file)


func _on_restart_requested() -> void:
	# Reload current scene
	get_tree().reload_current_scene()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	
	# Block input during encounters or combat
	if _encounter_active or _combat_active:
		return
	
	# Cancel movement preview on right-click or Escape
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			movement_controller.cancel_pending_movement()
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			movement_controller.cancel_pending_movement()
		
		# Confirm movement with Enter/Space
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if movement_controller.pending_movement:
				movement_controller.confirm_movement()

# =============================================================================
# QUERIES
# =============================================================================

## Gets the current player instance.
func get_player() -> Player:
	return player


## Checks if the game is fully initialized.
func is_game_ready() -> bool:
	return is_initialized and player_ready


## Checks if an encounter is currently active.
func is_encounter_active() -> bool:
	return _encounter_active


## Checks if tactical combat is currently active.
func is_combat_active() -> bool:
	return _combat_active


## Checks if any blocking UI (encounter or combat) is active.
func is_input_blocked() -> bool:
	return _encounter_active or _combat_active
