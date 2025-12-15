# main.gd
# Top-level game controller and scene state machine.
# Loads UI scenes from res://scenes/ui/ rather than creating them dynamically.

extends Node2D
class_name Main

# =============================================================================
# CONSTANTS
# =============================================================================

enum GameState { NONE, LAUNCH_MENU, CHARACTER_CREATION, GAMEPLAY, SETTINGS, LOADING }

const STATE_NAMES := {
	GameState.NONE: "none",
	GameState.LAUNCH_MENU: "launch_menu",
	GameState.CHARACTER_CREATION: "character_creation",
	GameState.GAMEPLAY: "gameplay",
	GameState.SETTINGS: "settings",
	GameState.LOADING: "loading"
}

const LAUNCH_MENU_SCENE := "res://scenes/ui/launch_menu.tscn"
const CHARACTER_CREATION_SCENE := "res://scenes/ui/character_creation_screen.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_screen.tscn"

# =============================================================================
# SIGNALS
# =============================================================================

signal state_changed(old_state: int, new_state: int)
signal new_game_started()
signal game_loaded(save_name: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var skip_menu_debug: bool = false

# =============================================================================
# STATE
# =============================================================================

var current_state: GameState = GameState.NONE
var previous_state: GameState = GameState.NONE
var gameplay_initialized: bool = false
var pending_character_data: Dictionary = {}

# =============================================================================
# NODE REFERENCES
# =============================================================================

var launch_menu: Control = null
var character_creation_screen: Control = null
var settings_screen: Control = null
var save_load_dialog: Control = null
var menu_layer: CanvasLayer = null
var game_manager: Node = null
var save_manager: Node = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("main")

	save_manager = get_node_or_null("/root/SaveManager")

	game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		for child in get_children():
			if child.name == "GameManager":
				game_manager = child
				break

	if game_manager:
		print("Main: Found GameManager")
		_hide_gameplay()
	else:
		push_warning("Main: GameManager not found")

	_create_menu_layer()
	_connect_event_bus()

	if skip_menu_debug:
		print("Main: Debug mode - skipping to gameplay")
		call_deferred("_start_gameplay_direct")
	else:
		call_deferred("_change_state", GameState.LAUNCH_MENU)

	print("Main: Initialized")

	#var text := get_tree().get_root().get_tree_string_pretty()
	#var file := FileAccess.open("res://scene_tree.txt", FileAccess.WRITE)
	#file.store_string(text)
	#file.close()


func _hide_gameplay() -> void:
	for child in get_children():
		if child.name == "MenuLayer":
			continue
		if child is CanvasItem:
			child.visible = false


func _show_gameplay() -> void:
	for child in get_children():
		if child.name == "MenuLayer":
			continue
		if child is CanvasItem:
			child.visible = true


func _create_menu_layer() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	menu_layer.layer = 100
	add_child(menu_layer)
	
	# Load scenes
	if ResourceLoader.exists(LAUNCH_MENU_SCENE):
		launch_menu = load(LAUNCH_MENU_SCENE).instantiate()
		launch_menu.visible = false
		menu_layer.add_child(launch_menu)
		_connect_launch_menu()
		print("Main: Loaded LaunchMenu")
	else:
		push_error("Main: %s not found" % LAUNCH_MENU_SCENE)
	
	if ResourceLoader.exists(CHARACTER_CREATION_SCENE):
		character_creation_screen = load(CHARACTER_CREATION_SCENE).instantiate()
		character_creation_screen.visible = false
		menu_layer.add_child(character_creation_screen)
		_connect_character_creation()
		print("Main: Loaded CharacterCreationScreen")
	
	if ResourceLoader.exists(SETTINGS_SCENE):
		settings_screen = load(SETTINGS_SCENE).instantiate()
		settings_screen.visible = false
		menu_layer.add_child(settings_screen)
		_connect_settings()
		print("Main: Loaded SettingsScreen")

	# Create save/load dialog dynamically
	save_load_dialog = SaveLoadDialog.new()
	save_load_dialog.visible = false
	menu_layer.add_child(save_load_dialog)
	_connect_save_load_dialog()
	print("Main: Created SaveLoadDialog")


func _connect_launch_menu() -> void:
	if launch_menu.has_signal("new_game_pressed"):
		launch_menu.new_game_pressed.connect(_on_new_game_requested)
	if launch_menu.has_signal("continue_pressed"):
		launch_menu.continue_pressed.connect(_on_continue_requested)
	if launch_menu.has_signal("load_game_pressed"):
		launch_menu.load_game_pressed.connect(_on_load_game_dialog_requested)
	if launch_menu.has_signal("settings_requested"):
		launch_menu.settings_requested.connect(_on_settings_requested)
	if launch_menu.has_signal("quit_pressed"):
		launch_menu.quit_pressed.connect(_on_quit_requested)


func _connect_character_creation() -> void:
	if character_creation_screen.has_signal("creation_complete"):
		character_creation_screen.creation_complete.connect(_on_character_creation_complete)
	if character_creation_screen.has_signal("creation_cancelled"):
		character_creation_screen.creation_cancelled.connect(_on_character_creation_cancelled)


func _connect_settings() -> void:
	if settings_screen.has_signal("settings_closed"):
		settings_screen.settings_closed.connect(_on_settings_closed)
	if settings_screen.has_signal("save_game_requested"):
		settings_screen.save_game_requested.connect(_on_pause_save_requested)
	if settings_screen.has_signal("load_game_requested"):
		settings_screen.load_game_requested.connect(_on_pause_load_requested)
	if settings_screen.has_signal("main_menu_requested"):
		settings_screen.main_menu_requested.connect(_on_pause_main_menu_requested)


func _connect_save_load_dialog() -> void:
	if save_load_dialog.has_signal("save_selected"):
		save_load_dialog.save_selected.connect(_on_save_selected)
	if save_load_dialog.has_signal("save_requested"):
		save_load_dialog.save_requested.connect(_on_save_requested)
	if save_load_dialog.has_signal("canceled"):
		save_load_dialog.canceled.connect(_on_save_load_canceled)
	if save_load_dialog.has_signal("profile_deleted"):
		save_load_dialog.profile_deleted.connect(_on_profile_deleted)
	if save_load_dialog.has_signal("save_deleted"):
		save_load_dialog.save_deleted.connect(_on_save_deleted)


func _connect_event_bus() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if not eb:
		return
	if eb.has_signal("player_died"):
		eb.player_died.connect(_on_player_died)

# =============================================================================
# STATE MACHINE
# =============================================================================

func _change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	
	var old_state := current_state
	_exit_state(current_state)
	previous_state = current_state
	current_state = new_state
	_enter_state(new_state)
	
	state_changed.emit(old_state, new_state)
	print("Main: State %s -> %s" % [STATE_NAMES[old_state], STATE_NAMES[new_state]])


func _exit_state(state: GameState) -> void:
	match state:
		GameState.LAUNCH_MENU:
			if launch_menu: launch_menu.visible = false
		GameState.CHARACTER_CREATION:
			if character_creation_screen: character_creation_screen.visible = false
		GameState.GAMEPLAY:
			_hide_gameplay()
		GameState.SETTINGS:
			if settings_screen: settings_screen.visible = false


func _enter_state(state: GameState) -> void:
	match state:
		GameState.LAUNCH_MENU:
			if launch_menu:
				launch_menu.visible = true
				if launch_menu.has_method("refresh"): launch_menu.refresh()
		GameState.CHARACTER_CREATION:
			if character_creation_screen:
				character_creation_screen.visible = true
				if character_creation_screen.has_method("reset"): character_creation_screen.reset()
		GameState.GAMEPLAY:
			_show_gameplay()
			if not gameplay_initialized:
				_initialize_gameplay()
		GameState.SETTINGS:
			if settings_screen:
				# Set gameplay mode before showing (shows/hides game buttons)
				var from_gameplay := previous_state == GameState.GAMEPLAY
				if settings_screen.has_method("set_in_gameplay"):
					settings_screen.set_in_gameplay(from_gameplay)
				settings_screen.visible = true
				if settings_screen.has_method("refresh"): settings_screen.refresh()


func _initialize_gameplay() -> void:
	if not game_manager:
		push_error("Main: No GameManager for gameplay")
		return

	print("Main: Initializing gameplay...")

	# Await the game manager initialization so all systems are ready
	# before applying character data
	if game_manager.has_method("initialize_game"):
		await game_manager.initialize_game()
	elif game_manager.has_method("_initialize_game"):
		await game_manager._initialize_game()

	gameplay_initialized = true

	# Apply character data now that player and all systems exist
	if not pending_character_data.is_empty():
		_apply_character_data(pending_character_data)


func _start_gameplay_direct() -> void:
	_show_gameplay()
	if game_manager and game_manager.has_method("initialize_game"):
		await game_manager.initialize_game()
	gameplay_initialized = true
	current_state = GameState.GAMEPLAY

# =============================================================================
# HANDLERS
# =============================================================================

func _on_new_game_requested() -> void:
	print("Main: New game requested")
	_change_state(GameState.CHARACTER_CREATION)


func _on_continue_requested() -> void:
	print("Main: Continue requested")
	if save_manager and save_manager.has_continue_data():
		_load_game_from_save_manager()


func _on_load_game_dialog_requested() -> void:
	print("Main: Load game dialog requested")
	if save_load_dialog:
		save_load_dialog.open_load()


func _on_save_selected(profile_name: String, save_name: String) -> void:
	print("Main: Save selected - profile: %s, save: %s" % [profile_name, save_name])
	if save_manager:
		save_manager.set_current_profile(profile_name)
		_load_game_from_profile(profile_name, save_name)


func _on_save_requested(save_name: String) -> void:
	print("Main: Save requested - name: %s" % save_name)
	if save_manager:
		save_manager.save_game(save_name)
	# Return to gameplay after saving from pause menu
	if previous_state == GameState.GAMEPLAY:
		_change_state(GameState.GAMEPLAY)


func _on_save_load_canceled() -> void:
	print("Main: Save/Load dialog canceled")
	# If we were in gameplay (opened from pause menu), return to gameplay
	if current_state == GameState.SETTINGS or previous_state == GameState.GAMEPLAY:
		_change_state(GameState.GAMEPLAY)


func _on_profile_deleted(profile_name: String) -> void:
	print("Main: Profile deleted - %s" % profile_name)
	if save_manager:
		save_manager.delete_profile(profile_name)
	if launch_menu and launch_menu.has_method("refresh"):
		launch_menu.refresh()


func _on_save_deleted(profile_name: String, save_name: String) -> void:
	print("Main: Save deleted - profile: %s, save: %s" % [profile_name, save_name])
	if save_manager:
		save_manager.delete_save(save_name, profile_name)


func _on_settings_requested() -> void:
	print("Main: Settings requested")
	_change_state(GameState.SETTINGS)


func _on_quit_requested() -> void:
	print("Main: Quit requested")
	get_tree().quit()


func _on_character_creation_complete(character_data: Dictionary) -> void:
	print("Main: Character creation complete")

	# Create a profile for this new character
	if save_manager:
		var char_name: String = character_data.get("name", "Unknown")
		var background: String = character_data.get("background_id", "drifter")
		save_manager.create_profile(char_name, background)

	pending_character_data = character_data
	_change_state(GameState.GAMEPLAY)
	new_game_started.emit()


func _on_character_creation_cancelled() -> void:
	print("Main: Character creation cancelled")
	_change_state(GameState.LAUNCH_MENU)


func _on_settings_closed() -> void:
	print("Main: Settings closed")
	if previous_state == GameState.GAMEPLAY:
		_change_state(GameState.GAMEPLAY)
	else:
		_change_state(GameState.LAUNCH_MENU)


func _on_pause_save_requested() -> void:
	print("Main: Save requested from pause menu")
	if settings_screen:
		settings_screen.visible = false
	if save_load_dialog:
		save_load_dialog.open_save()


func _on_pause_load_requested() -> void:
	print("Main: Load requested from pause menu")
	if settings_screen:
		settings_screen.visible = false
	if save_load_dialog:
		save_load_dialog.open_load()


func _on_pause_main_menu_requested() -> void:
	print("Main: Main menu requested from pause menu")
	return_to_launch_menu()


func _on_player_died(cause: String) -> void:
	print("Main: Player died - %s" % cause)


# =============================================================================
# SAVE/LOAD HELPERS
# =============================================================================

func _load_game_from_save_manager() -> void:
	_change_state(GameState.LOADING)
	await get_tree().create_timer(0.1).timeout

	_show_gameplay()
	if not gameplay_initialized and game_manager:
		if game_manager.has_method("initialize_game"):
			await game_manager.initialize_game()
		gameplay_initialized = true

	# Load via SaveManager
	if save_manager:
		save_manager.continue_game()

	_change_state(GameState.GAMEPLAY)
	game_loaded.emit("continue")


func _load_game_from_profile(profile_name: String, save_name: String) -> void:
	_change_state(GameState.LOADING)
	await get_tree().create_timer(0.1).timeout

	_show_gameplay()
	if not gameplay_initialized and game_manager:
		if game_manager.has_method("initialize_game"):
			await game_manager.initialize_game()
		gameplay_initialized = true

	# Load via SaveManager
	if save_manager:
		save_manager.load_game(save_name, profile_name)

	_change_state(GameState.GAMEPLAY)
	game_loaded.emit(save_name)


## Open save dialog (called from gameplay, e.g., camp menu)
func open_save_dialog() -> void:
	if save_load_dialog and current_state == GameState.GAMEPLAY:
		save_load_dialog.open_save()


## Quick save the current game
func quick_save() -> void:
	if save_manager and current_state == GameState.GAMEPLAY:
		save_manager.save_game("quicksave")
		print("Main: Quick saved")

# =============================================================================
# CHARACTER APPLICATION
# =============================================================================

func _apply_character_data(character_data: Dictionary) -> void:
	print("Main: ========================================")
	print("Main: _apply_character_data() called")
	print("Main: Full character_data: %s" % str(character_data))

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Main: Player not found - cannot apply character data")
		return

	print("Main: Applying character data: %s" % character_data.get("name", "Unknown"))

	# Name
	if character_data.has("name"):
		player.player_name = character_data.name

	# Background ID (store as metadata for UI display)
	if character_data.has("background_id"):
		player.set_meta("background_id", character_data.background_id)

	# Stats
	if character_data.has("stats"):
		if player.player_stats and player.player_stats.has_method("set_base_stat"):
			for stat_name in character_data.stats:
				player.player_stats.set_base_stat(stat_name, character_data.stats[stat_name])
			print("Main: Applied %d stats" % character_data.stats.size())
		else:
			push_warning("Main: player.player_stats not available")

	# Skills
	if character_data.has("skills"):
		if player.skill_manager and player.skill_manager.has_method("set_skill_level"):
			for skill_name in character_data.skills:
				player.skill_manager.set_skill_level(skill_name, character_data.skills[skill_name])
			print("Main: Applied %d skills" % character_data.skills.size())
		else:
			push_warning("Main: player.skill_manager not available")

	# Starting talent
	print("Main: About to apply starting talent...")
	if character_data.has("starting_talent"):
		var talent_id: String = character_data.starting_talent
		print("Main: Talent ID: %s" % talent_id)
		if not talent_id.is_empty():
			if player.talent_manager and player.talent_manager.has_method("acquire_starting_talent"):
				print("Main: Calling acquire_starting_talent()...")
				player.talent_manager.acquire_starting_talent(talent_id)
				print("Main: Applied starting talent: %s" % talent_id)
			else:
				push_warning("Main: player.talent_manager not available")
	else:
		print("Main: No starting_talent in character_data")

	print("Main: Finished talent section, moving to equipment...")

	# Equipment (money, weapons, items, clothing)
	if character_data.has("equipment"):
		var inventory_manager = get_tree().get_first_node_in_group("inventory_manager")
		if inventory_manager:
			inventory_manager.apply_starting_equipment(character_data.equipment)
		else:
			push_warning("Main: InventoryManager not available")
	else:
		push_warning("Main: No equipment data in character_data")

	# Emit signal for UI to update
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("character_data_applied"):
		event_bus.emit_signal("character_data_applied", character_data)

# =============================================================================
# PUBLIC API
# =============================================================================

func get_state_name() -> String:
	return STATE_NAMES.get(current_state, "unknown")

func is_in_gameplay() -> bool:
	return current_state == GameState.GAMEPLAY

func is_in_menu() -> bool:
	return current_state in [GameState.LAUNCH_MENU, GameState.CHARACTER_CREATION, GameState.SETTINGS]

func return_to_launch_menu() -> void:
	gameplay_initialized = false
	pending_character_data = {}
	_change_state(GameState.LAUNCH_MENU)

# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	if event.keycode == KEY_ESCAPE:
		match current_state:
			GameState.GAMEPLAY:
				_on_settings_requested()
			GameState.SETTINGS:
				_on_settings_closed()
			GameState.CHARACTER_CREATION:
				_on_character_creation_cancelled()

	# Quick save (F5) - only during gameplay
	if event.keycode == KEY_F5 and current_state == GameState.GAMEPLAY:
		quick_save()

	# Quick load (F9) - only during gameplay if there's a save
	if event.keycode == KEY_F9 and current_state == GameState.GAMEPLAY:
		if save_manager and save_manager.current_profile and save_manager.save_exists("quicksave"):
			print("Main: Quick loading...")
			save_manager.load_game("quicksave")

	# Open save dialog (F6) - during gameplay
	if event.keycode == KEY_F6 and current_state == GameState.GAMEPLAY:
		open_save_dialog()
