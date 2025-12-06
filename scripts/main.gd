# main.gd
# Top-level game controller and scene state machine.
# Manages transitions between Launch Menu, Character Creation, Gameplay, and Settings.
#
# GAME STATES:
# - launch_menu: Initial menu with New Game, Load Game, Settings, Quit
# - character_creation: New game character creation flow
# - gameplay: Main game (hex map, exploration, encounters)
# - settings: Settings menu (accessible from launch or gameplay)
# - loading: Transition state while loading
#
# STRUCTURE:
# Main (this script, Node2D)
# ├── GameContent (Node2D) - Holds gameplay nodes (HexGrid, Player, etc.)
# ├── UILayer (CanvasLayer) - Holds all UI
# │   ├── GameUI (Control) - Gameplay UI (SurvivalPanel, etc.)
# │   ├── MenuUI (Control) - Menu screens (LaunchMenu, CharacterCreation, Settings)
# │   └── OverlayUI (Control) - Overlays (GameOver, Pause)
# └── Managers (Node) - System managers

extends Node2D
class_name Main

# =============================================================================
# CONSTANTS
# =============================================================================

enum GameState {
	NONE,
	LAUNCH_MENU,
	CHARACTER_CREATION,
	GAMEPLAY,
	SETTINGS,
	LOADING
}

const STATE_NAMES := {
	GameState.NONE: "none",
	GameState.LAUNCH_MENU: "launch_menu",
	GameState.CHARACTER_CREATION: "character_creation",
	GameState.GAMEPLAY: "gameplay",
	GameState.SETTINGS: "settings",
	GameState.LOADING: "loading"
}

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when game state changes.
signal state_changed(old_state: int, new_state: int)

## Emitted when a new game is fully started.
signal new_game_started()

## Emitted when a game is loaded.
signal game_loaded(save_name: String)

# =============================================================================
# STATE
# =============================================================================

## Current game state.
var current_state: GameState = GameState.NONE

## Previous state (for returning from settings).
var previous_state: GameState = GameState.NONE

## Whether gameplay has been initialized this session.
var gameplay_initialized: bool = false

## Character data from creation (passed to gameplay).
var pending_character_data: Dictionary = {}

# =============================================================================
# NODE REFERENCES
# =============================================================================

## Container for gameplay nodes.
var game_content: Node2D

## Container for UI.
var ui_layer: CanvasLayer

## Gameplay UI container.
var game_ui: Control

## Menu UI container.
var menu_ui: Control

## Overlay UI container.
var overlay_ui: Control

## Launch menu screen.
var launch_menu: Control

## Character creation screen.
var character_creation_screen: Control

## Settings screen.
var settings_screen: Control

## Reference to GameManager (created during gameplay).
var game_manager: Node

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("main")
	_setup_structure()
	_connect_signals()
	
	# Start at launch menu
	call_deferred("_change_state", GameState.LAUNCH_MENU)
	
	print("Main: Initialized")


func _setup_structure() -> void:
	# Create or find GameContent
	game_content = get_node_or_null("GameContent")
	if not game_content:
		game_content = Node2D.new()
		game_content.name = "GameContent"
		add_child(game_content)
	
	# Create or find UILayer
	ui_layer = get_node_or_null("UILayer")
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		ui_layer.layer = 10
		add_child(ui_layer)
	
	# Create UI containers
	_setup_ui_containers()
	
	# Create menu screens
	_setup_menu_screens()


func _setup_ui_containers() -> void:
	# Game UI (hidden initially)
	game_ui = ui_layer.get_node_or_null("GameUI")
	if not game_ui:
		game_ui = Control.new()
		game_ui.name = "GameUI"
		game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(game_ui)
	game_ui.visible = false
	
	# Menu UI
	menu_ui = ui_layer.get_node_or_null("MenuUI")
	if not menu_ui:
		menu_ui = Control.new()
		menu_ui.name = "MenuUI"
		menu_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(menu_ui)
	
	# Overlay UI
	overlay_ui = ui_layer.get_node_or_null("OverlayUI")
	if not overlay_ui:
		overlay_ui = Control.new()
		overlay_ui.name = "OverlayUI"
		overlay_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(overlay_ui)
	overlay_ui.visible = false


func _setup_menu_screens() -> void:
	# Check if screens already exist (added in editor)
	launch_menu = menu_ui.get_node_or_null("LaunchMenu")
	character_creation_screen = menu_ui.get_node_or_null("CharacterCreationScreen")
	settings_screen = menu_ui.get_node_or_null("SettingsScreen")
	
	# Create LaunchMenu if not present
	if not launch_menu:
		var LaunchMenuClass = load("res://scripts/ui/launch_menu.gd")
		if LaunchMenuClass:
			launch_menu = LaunchMenuClass.new()
			launch_menu.name = "LaunchMenu"
			menu_ui.add_child(launch_menu)
			print("Main: Created LaunchMenu")
	
	# Create CharacterCreationScreen if not present
	if not character_creation_screen:
		var CharCreationClass = load("res://scripts/ui/character_creation_screen.gd")
		if CharCreationClass:
			character_creation_screen = CharCreationClass.new()
			character_creation_screen.name = "CharacterCreationScreen"
			menu_ui.add_child(character_creation_screen)
			print("Main: Created CharacterCreationScreen")
	
	# Create SettingsScreen if not present
	if not settings_screen:
		var SettingsClass = load("res://scripts/ui/settings_screen.gd")
		if SettingsClass:
			settings_screen = SettingsClass.new()
			settings_screen.name = "SettingsScreen"
			menu_ui.add_child(settings_screen)
			print("Main: Created SettingsScreen")
	
	# Hide all initially
	if launch_menu:
		launch_menu.visible = false
	if character_creation_screen:
		character_creation_screen.visible = false
	if settings_screen:
		settings_screen.visible = false


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	
	# Connect to EventBus signals
	if event_bus:
		# Menu navigation signals
		if event_bus.has_signal("new_game_requested"):
			event_bus.new_game_requested.connect(_on_new_game_requested)
		if event_bus.has_signal("load_game_requested"):
			event_bus.load_game_requested.connect(_on_load_game_requested)
		if event_bus.has_signal("settings_requested"):
			event_bus.settings_requested.connect(_on_settings_requested)
		if event_bus.has_signal("quit_requested"):
			event_bus.quit_requested.connect(_on_quit_requested)
		if event_bus.has_signal("back_to_menu_requested"):
			event_bus.back_to_menu_requested.connect(_on_back_to_menu_requested)
		if event_bus.has_signal("character_creation_complete"):
			event_bus.character_creation_complete.connect(_on_character_creation_complete)
		if event_bus.has_signal("character_creation_cancelled"):
			event_bus.character_creation_cancelled.connect(_on_character_creation_cancelled)
		if event_bus.has_signal("settings_closed"):
			event_bus.settings_closed.connect(_on_settings_closed)
		
		# Gameplay signals
		if event_bus.has_signal("player_died"):
			event_bus.player_died.connect(_on_player_died)
	
	# Connect to menu screen signals directly if EventBus signals don't exist yet
	_connect_menu_signals()


func _connect_menu_signals() -> void:
	# LaunchMenu signals
	if launch_menu:
		if launch_menu.has_signal("new_game_pressed"):
			launch_menu.new_game_pressed.connect(_on_new_game_requested)
		if launch_menu.has_signal("load_game_pressed"):
			launch_menu.load_game_pressed.connect(_on_load_game_requested)
		if launch_menu.has_signal("settings_pressed"):
			launch_menu.settings_requested.connect(_on_settings_requested)
		if launch_menu.has_signal("quit_pressed"):
			launch_menu.quit_pressed.connect(_on_quit_requested)
	
	# CharacterCreationScreen signals
	if character_creation_screen:
		if character_creation_screen.has_signal("creation_complete"):
			character_creation_screen.creation_complete.connect(_on_character_creation_complete)
		if character_creation_screen.has_signal("creation_cancelled"):
			character_creation_screen.creation_cancelled.connect(_on_character_creation_cancelled)
	
	# SettingsScreen signals
	if settings_screen:
		if settings_screen.has_signal("settings_closed"):
			settings_screen.settings_closed.connect(_on_settings_closed)

# =============================================================================
# STATE MACHINE
# =============================================================================

func _change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	
	var old_state := current_state
	
	# Exit current state
	_exit_state(current_state)
	
	# Update state
	previous_state = current_state
	current_state = new_state
	
	# Enter new state
	_enter_state(new_state)
	
	# Emit signals
	state_changed.emit(old_state, new_state)
	_emit_to_event_bus("game_state_changed", [STATE_NAMES[old_state], STATE_NAMES[new_state]])
	
	print("Main: State changed from %s to %s" % [STATE_NAMES[old_state], STATE_NAMES[new_state]])


func _exit_state(state: GameState) -> void:
	match state:
		GameState.LAUNCH_MENU:
			if launch_menu:
				launch_menu.visible = false
		
		GameState.CHARACTER_CREATION:
			if character_creation_screen:
				character_creation_screen.visible = false
		
		GameState.GAMEPLAY:
			# Don't destroy gameplay, just hide UI
			game_ui.visible = false
			game_content.visible = false
		
		GameState.SETTINGS:
			if settings_screen:
				settings_screen.visible = false


func _enter_state(state: GameState) -> void:
	match state:
		GameState.LAUNCH_MENU:
			_show_launch_menu()
		
		GameState.CHARACTER_CREATION:
			_show_character_creation()
		
		GameState.GAMEPLAY:
			_show_gameplay()
		
		GameState.SETTINGS:
			_show_settings()
		
		GameState.LOADING:
			_show_loading()


func _show_launch_menu() -> void:
	menu_ui.visible = true
	if launch_menu:
		launch_menu.visible = true
		if launch_menu.has_method("refresh"):
			launch_menu.refresh()


func _show_character_creation() -> void:
	menu_ui.visible = true
	if character_creation_screen:
		character_creation_screen.visible = true
		if character_creation_screen.has_method("reset"):
			character_creation_screen.reset()


func _show_settings() -> void:
	menu_ui.visible = true
	if settings_screen:
		settings_screen.visible = true
		if settings_screen.has_method("refresh"):
			settings_screen.refresh()


func _show_loading() -> void:
	# Could show a loading screen here
	menu_ui.visible = true


func _show_gameplay() -> void:
	menu_ui.visible = false
	game_content.visible = true
	game_ui.visible = true
	
	if not gameplay_initialized:
		_initialize_gameplay()


func _initialize_gameplay() -> void:
	# Find or create GameManager
	game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if not game_manager:
		var GameManagerClass = load("res://scripts/game_manager.gd")
		if GameManagerClass:
			game_manager = GameManagerClass.new()
			game_manager.name = "GameManager"
			game_content.add_child(game_manager)
			print("Main: Created GameManager")
	
	gameplay_initialized = true

# =============================================================================
# MENU HANDLERS
# =============================================================================

func _on_new_game_requested() -> void:
	print("Main: New game requested")
	_change_state(GameState.CHARACTER_CREATION)


func _on_load_game_requested(save_path: String = "") -> void:
	print("Main: Load game requested - %s" % save_path)
	_change_state(GameState.LOADING)
	
	# TODO: Actual loading logic
	# For now, just go to gameplay
	await get_tree().create_timer(0.5).timeout
	
	if not save_path.is_empty():
		# Load the save
		pass
	
	_change_state(GameState.GAMEPLAY)
	game_loaded.emit(save_path)


func _on_settings_requested() -> void:
	print("Main: Settings requested")
	_change_state(GameState.SETTINGS)


func _on_quit_requested() -> void:
	print("Main: Quit requested")
	get_tree().quit()


func _on_back_to_menu_requested() -> void:
	print("Main: Back to menu requested")
	
	# Reset gameplay state if returning from gameplay
	if previous_state == GameState.GAMEPLAY:
		gameplay_initialized = false
		# Clear game content
		for child in game_content.get_children():
			child.queue_free()
	
	_change_state(GameState.LAUNCH_MENU)


func _on_character_creation_complete(character_data: Dictionary) -> void:
	print("Main: Character creation complete")
	pending_character_data = character_data
	
	# Initialize gameplay with character data
	_change_state(GameState.GAMEPLAY)
	
	# Apply character data after gameplay initializes
	await get_tree().process_frame
	_apply_character_to_game(character_data)
	
	new_game_started.emit()
	_emit_to_event_bus("new_game_started", [])


func _on_character_creation_cancelled() -> void:
	print("Main: Character creation cancelled")
	_change_state(GameState.LAUNCH_MENU)


func _on_settings_closed() -> void:
	print("Main: Settings closed")
	# Return to previous state
	if previous_state == GameState.GAMEPLAY:
		_change_state(GameState.GAMEPLAY)
	else:
		_change_state(GameState.LAUNCH_MENU)


func _on_player_died(cause: String) -> void:
	print("Main: Player died - %s" % cause)
	# Game over is handled by GameOverScreen in overlay_ui
	# Could transition to a game over state here if needed

# =============================================================================
# CHARACTER APPLICATION
# =============================================================================

func _apply_character_to_game(character_data: Dictionary) -> void:
	# Find CharacterCreator and apply
	var character_creator = get_tree().get_first_node_in_group("character_creator")
	
	if character_creator:
		# CharacterCreator.create_character() was already called
		# Just need to trigger any post-creation setup
		pass
	else:
		# Manual application if no CharacterCreator
		_apply_character_manual(character_data)
	
	# Notify game manager to start
	if game_manager and game_manager.has_method("start_new_game"):
		var seed_value:Variant = character_data.get("seed", randi())
		game_manager.start_new_game(seed_value)


func _apply_character_manual(character_data: Dictionary) -> void:
	# Find player and apply stats/skills/talents
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Main: Player not found for character application")
		return
	
	# Apply name
	player.player_name = character_data.get("name", "Wanderer")
	
	# Apply stats
	var stats: Dictionary = character_data.get("stats", {})
	if player.player_stats and player.player_stats.has_method("initialize_from_dict"):
		player.player_stats.initialize_from_dict(stats)
	
	# Apply skills
	var skills: Dictionary = character_data.get("skills", {})
	if player.skill_manager:
		for skill_name in skills:
			if player.skill_manager.has_method("set_skill_level"):
				player.skill_manager.set_skill_level(skill_name, skills[skill_name])
	
	# Apply starting talent
	var starting_talent: String = character_data.get("starting_talent", "")
	if not starting_talent.is_empty() and player.talent_manager:
		if player.talent_manager.has_method("acquire_starting_talent"):
			player.talent_manager.acquire_starting_talent(starting_talent)
	
	print("Main: Applied character data to player")

# =============================================================================
# PUBLIC API
# =============================================================================

## Get current state name.
func get_state_name() -> String:
	return STATE_NAMES.get(current_state, "unknown")


## Check if in gameplay.
func is_in_gameplay() -> bool:
	return current_state == GameState.GAMEPLAY


## Check if in menu.
func is_in_menu() -> bool:
	return current_state in [GameState.LAUNCH_MENU, GameState.CHARACTER_CREATION, GameState.SETTINGS]


## Force return to launch menu (e.g., from game over).
func return_to_launch_menu() -> void:
	gameplay_initialized = false
	for child in game_content.get_children():
		child.queue_free()
	_change_state(GameState.LAUNCH_MENU)

# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Escape to pause/settings during gameplay
		if event.keycode == KEY_ESCAPE:
			if current_state == GameState.GAMEPLAY:
				_on_settings_requested()
			elif current_state == GameState.SETTINGS:
				_on_settings_closed()
			elif current_state == GameState.CHARACTER_CREATION:
				_on_character_creation_cancelled()

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
