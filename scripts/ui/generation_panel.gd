# generation_panel.gd
# Modal popup panel for controlling procedural terrain generation.
# Provides seed input, generate buttons, and displays current seed.
extends Control
class_name GenerationPanel

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the panel is closed.
signal panel_closed()

## Emitted when generation is requested.
signal generation_requested(seed_value: int)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Key to toggle the generation panel visibility.
@export var toggle_key: Key = KEY_G

## Whether pressing the toggle key requires Ctrl modifier.
@export var require_ctrl: bool = false

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _panel: PanelContainer
var _vbox: VBoxContainer
var _title_label: Label
var _seed_input: LineEdit
var _current_seed_label: Label
var _generate_button: Button
var _random_button: Button
var _regenerate_button: Button
var _close_button: Button
var _progress_bar: ProgressBar
var _stats_label: Label

# Save/Load UI
var _save_section: VBoxContainer
var _save_name_input: LineEdit
var _save_button: Button
var _load_dropdown: OptionButton
var _load_button: Button
var _delete_save_button: Button

# Testing UI
var _test_button: Button
var _test_results_label: Label

# Fog Debug UI
var _fog_section: VBoxContainer
var _fog_toggle_button: Button
var _fog_reveal_button: Button
var _fog_reset_button: Button

# =============================================================================
# STATE
# =============================================================================

var _hex_grid: HexGrid = null
var _is_generating: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_signals()
	_find_hex_grid()
	
	# Start hidden
	visible = false


func _create_ui() -> void:
	# Make this control fill the screen for modal backdrop
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Semi-transparent backdrop
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	
	# Center container for the panel
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(320, 0)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(0.3, 0.3, 0.35)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)
	
	# Vertical layout
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(_vbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "Terrain Generation"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_vbox.add_child(_title_label)
	
	# Separator
	_vbox.add_child(_create_separator())
	
	# Current seed display
	_current_seed_label = Label.new()
	_current_seed_label.text = "Current Seed: --"
	_current_seed_label.add_theme_font_size_override("font_size", 12)
	_current_seed_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_vbox.add_child(_current_seed_label)
	
	# Seed input section
	var seed_hbox := HBoxContainer.new()
	seed_hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(seed_hbox)
	
	var seed_label := Label.new()
	seed_label.text = "Seed:"
	seed_label.add_theme_font_size_override("font_size", 14)
	seed_hbox.add_child(seed_label)
	
	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "Enter seed or leave empty"
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_input.add_theme_font_size_override("font_size", 14)
	seed_hbox.add_child(_seed_input)
	
	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = true
	_progress_bar.visible = false
	_progress_bar.custom_minimum_size.y = 20
	_vbox.add_child(_progress_bar)
	
	# Buttons
	_vbox.add_child(_create_separator())
	
	var button_vbox := VBoxContainer.new()
	button_vbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(button_vbox)
	
	_generate_button = _create_button("Generate with Seed", button_vbox)
	_generate_button.pressed.connect(_on_generate_pressed)
	
	_random_button = _create_button("Generate Random", button_vbox)
	_random_button.pressed.connect(_on_random_pressed)
	
	_regenerate_button = _create_button("Regenerate (Same Seed)", button_vbox)
	_regenerate_button.pressed.connect(_on_regenerate_pressed)
	
	# Separator before stats
	_vbox.add_child(_create_separator())
	
	# Statistics display
	_stats_label = Label.new()
	_stats_label.text = "Statistics: --"
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.custom_minimum_size.x = 280
	_vbox.add_child(_stats_label)
	
	# Save/Load Section
	_vbox.add_child(_create_separator())
	_create_save_load_section()
	
	# Testing Section
	_vbox.add_child(_create_separator())
	_create_testing_section()
	
	# Close button
	_vbox.add_child(_create_separator())
	
	_close_button = _create_button("Close", _vbox)
	_close_button.pressed.connect(_on_close_pressed)


func _create_save_load_section() -> void:
	var section_label := Label.new()
	section_label.text = "Save / Load"
	section_label.add_theme_font_size_override("font_size", 14)
	section_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_vbox.add_child(section_label)
	
	_save_section = VBoxContainer.new()
	_save_section.add_theme_constant_override("separation", 6)
	_vbox.add_child(_save_section)
	
	# Save name input
	var save_hbox := HBoxContainer.new()
	save_hbox.add_theme_constant_override("separation", 8)
	_save_section.add_child(save_hbox)
	
	_save_name_input = LineEdit.new()
	_save_name_input.placeholder_text = "Save name (optional)"
	_save_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_name_input.add_theme_font_size_override("font_size", 12)
	save_hbox.add_child(_save_name_input)
	
	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.custom_minimum_size = Vector2(60, 28)
	_save_button.pressed.connect(_on_save_pressed)
	save_hbox.add_child(_save_button)
	
	# Load dropdown and button
	var load_hbox := HBoxContainer.new()
	load_hbox.add_theme_constant_override("separation", 8)
	_save_section.add_child(load_hbox)
	
	_load_dropdown = OptionButton.new()
	_load_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_dropdown.add_theme_font_size_override("font_size", 12)
	_load_dropdown.item_selected.connect(_on_load_selection_changed)
	load_hbox.add_child(_load_dropdown)
	
	_load_button = Button.new()
	_load_button.text = "Load"
	_load_button.custom_minimum_size = Vector2(60, 28)
	_load_button.pressed.connect(_on_load_pressed)
	_load_button.disabled = true
	load_hbox.add_child(_load_button)
	
	_delete_save_button = Button.new()
	_delete_save_button.text = "Del"
	_delete_save_button.custom_minimum_size = Vector2(40, 28)
	_delete_save_button.pressed.connect(_on_delete_save_pressed)
	_delete_save_button.disabled = true
	load_hbox.add_child(_delete_save_button)


func _create_testing_section() -> void:
	var section_label := Label.new()
	section_label.text = "Testing"
	section_label.add_theme_font_size_override("font_size", 14)
	section_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_vbox.add_child(section_label)
	
	_test_button = _create_button("Run 10 Map Tests", _vbox)
	_test_button.pressed.connect(_on_test_pressed)
	
	_test_results_label = Label.new()
	_test_results_label.text = ""
	_test_results_label.add_theme_font_size_override("font_size", 10)
	_test_results_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	_test_results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_test_results_label.visible = false
	_vbox.add_child(_test_results_label)
	
	# Fog Debug Section
	_vbox.add_child(_create_separator())
	
	var fog_label := Label.new()
	fog_label.text = "Fog of War Debug"
	fog_label.add_theme_font_size_override("font_size", 14)
	fog_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_vbox.add_child(fog_label)
	
	_fog_section = VBoxContainer.new()
	_fog_section.add_theme_constant_override("separation", 4)
	_vbox.add_child(_fog_section)
	
	# Fog toggle button
	_fog_toggle_button = Button.new()
	_fog_toggle_button.text = "Hide Fog (Debug)"
	_fog_toggle_button.toggle_mode = true
	_fog_toggle_button.custom_minimum_size.y = 28
	_fog_toggle_button.toggled.connect(_on_fog_toggle)
	_fog_section.add_child(_fog_toggle_button)
	
	# Reveal all button
	_fog_reveal_button = Button.new()
	_fog_reveal_button.text = "Reveal Entire Map"
	_fog_reveal_button.custom_minimum_size.y = 28
	_fog_reveal_button.pressed.connect(_on_fog_reveal_pressed)
	_fog_section.add_child(_fog_reveal_button)
	
	# Reset fog button
	_fog_reset_button = Button.new()
	_fog_reset_button.text = "Reset Fog"
	_fog_reset_button.custom_minimum_size.y = 28
	_fog_reset_button.pressed.connect(_on_fog_reset_pressed)
	_fog_section.add_child(_fog_reset_button)


func _create_button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	
	# Style the button
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.25, 0.3)
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.3, 0.4)
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(8)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.2, 0.2, 0.25)
	pressed_style.set_corner_radius_all(4)
	pressed_style.set_content_margin_all(8)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	parent.add_child(button)
	return button


func _create_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	return sep


func _connect_signals() -> void:
	# Connect to EventBus for generation progress
	if has_node("/root/EventBus"):
		var event_bus = get_node("/root/EventBus")
		event_bus.map_generation_started.connect(_on_generation_started)
		event_bus.map_generation_progress.connect(_on_generation_progress)
		event_bus.map_generation_complete.connect(_on_generation_complete)


func _find_hex_grid() -> void:
	# Delay to allow scene to initialize
	await get_tree().process_frame
	
	# Find HexGrid in the scene
	var grids = get_tree().get_nodes_in_group("hex_grid")
	if grids.size() > 0:
		_hex_grid = grids[0]
		_update_current_seed_display()
	else:
		# Search by type
		var root = get_tree().current_scene
		if root:
			_hex_grid = _find_node_by_type(root, "HexGrid")
			if _hex_grid:
				_update_current_seed_display()


func _find_node_by_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		return node
	for child in node.get_children():
		var found = _find_node_by_type(child, type_name)
		if found:
			return found
	return null

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Check for toggle key
		if event.keycode == toggle_key:
			if require_ctrl and not event.ctrl_pressed:
				return
			toggle_panel()
			get_viewport().set_input_as_handled()
		
		# Close on Escape when visible
		elif event.keycode == KEY_ESCAPE and visible:
			hide_panel()
			get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	# Close panel when clicking the backdrop
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			hide_panel()

# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_generate_pressed() -> void:
	if _is_generating:
		return
	
	var seed_text := _seed_input.text.strip_edges()
	var seed_value := 0
	
	if seed_text.is_valid_int():
		seed_value = seed_text.to_int()
	elif not seed_text.is_empty():
		# Use string hash as seed
		seed_value = seed_text.hash()
	
	_generate_terrain(seed_value)


func _on_random_pressed() -> void:
	if _is_generating:
		return
	
	_seed_input.text = ""
	_generate_terrain(0)


func _on_regenerate_pressed() -> void:
	if _is_generating or _hex_grid == null:
		return
	
	var current_seed := _hex_grid.current_generation_seed
	if current_seed != 0:
		_generate_terrain(current_seed)


func _on_close_pressed() -> void:
	hide_panel()

# =============================================================================
# GENERATION
# =============================================================================

func _generate_terrain(seed_value: int) -> void:
	if _hex_grid == null:
		push_error("GenerationPanel: No HexGrid found!")
		return
	
	_hex_grid.generate_complete_map(seed_value)
	generation_requested.emit(seed_value)
	_update_statistics()
	_refresh_save_list()


func _on_generation_started(seed_value: int) -> void:
	_is_generating = true
	_progress_bar.visible = true
	_progress_bar.value = 0.0
	_set_buttons_enabled(false)
	_current_seed_label.text = "Generating with seed: %d" % seed_value


func _on_generation_progress(progress: float) -> void:
	_progress_bar.value = progress


func _on_generation_complete(seed_value: int) -> void:
	_is_generating = false
	_progress_bar.visible = false
	_set_buttons_enabled(true)
	_update_current_seed_display()
	_update_statistics()


func _set_buttons_enabled(enabled: bool) -> void:
	_generate_button.disabled = not enabled
	_random_button.disabled = not enabled
	_regenerate_button.disabled = not enabled
	if _save_button:
		_save_button.disabled = not enabled
	if _test_button:
		_test_button.disabled = not enabled

# =============================================================================
# SAVE/LOAD HANDLERS
# =============================================================================

func _on_save_pressed() -> void:
	if _hex_grid == null:
		return
	
	var save_name := _save_name_input.text.strip_edges()
	var file_path := _hex_grid.save_map(save_name)
	
	if not file_path.is_empty():
		_save_name_input.text = ""
		_refresh_save_list()
		print("Map saved to: %s" % file_path)


func _on_load_pressed() -> void:
	if _hex_grid == null or _load_dropdown.selected < 0:
		return
	
	var selected_id := _load_dropdown.selected
	var file_path: String = _load_dropdown.get_item_metadata(selected_id)
	
	if file_path.is_empty():
		return
	
	var loaded_seed := _hex_grid.load_map(file_path)
	if loaded_seed >= 0:
		_update_current_seed_display()
		_update_statistics()
		print("Map loaded with seed: %d" % loaded_seed)


func _on_delete_save_pressed() -> void:
	if _hex_grid == null or _load_dropdown.selected < 0:
		return
	
	var selected_id := _load_dropdown.selected
	var filename: String = _load_dropdown.get_item_text(selected_id)
	
	if _hex_grid.delete_save(filename):
		_refresh_save_list()
		print("Deleted save: %s" % filename)


func _on_load_selection_changed(index: int) -> void:
	var has_selection := index >= 0 and _load_dropdown.item_count > 0
	_load_button.disabled = not has_selection
	_delete_save_button.disabled = not has_selection


func _refresh_save_list() -> void:
	if _load_dropdown == null:
		return
	
	_load_dropdown.clear()
	
	if _hex_grid == null:
		return
	
	var saves := _hex_grid.get_save_list()
	
	for save_info in saves:
		var display_text := "%s (seed: %d)" % [save_info["filename"], save_info["generation_seed"]]
		_load_dropdown.add_item(display_text)
		var idx := _load_dropdown.item_count - 1
		_load_dropdown.set_item_metadata(idx, save_info["path"])
	
	_load_button.disabled = saves.is_empty()
	_delete_save_button.disabled = saves.is_empty()

# =============================================================================
# TESTING HANDLERS
# =============================================================================

func _on_test_pressed() -> void:
	if _hex_grid == null or _is_generating:
		return
	
	_test_button.disabled = true
	_test_results_label.text = "Running tests..."
	_test_results_label.visible = true
	
	# Run tests in next frame to allow UI to update
	await get_tree().process_frame
	
	var tester := MapTester.new()
	var results := tester.run_tests(_hex_grid, 10)
	
	# Display results
	_test_results_label.text = "Passed: %d/10 (%.0f%%)\nReport: %s" % [
		results["passed"],
		results["pass_rate"],
		results["report_path"].get_file()
	]
	
	if results["pass_rate"] >= 80.0:
		_test_results_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	else:
		_test_results_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	
	_test_button.disabled = false
	
	# Regenerate a new map after testing
	_generate_terrain(0)

# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_current_seed_display() -> void:
	if _hex_grid:
		var seed_val := _hex_grid.current_generation_seed
		if seed_val != 0:
			_current_seed_label.text = "Current Seed: %d" % seed_val
		else:
			_current_seed_label.text = "Current Seed: --"
	else:
		_current_seed_label.text = "Current Seed: (no grid)"


func _update_statistics() -> void:
	if _hex_grid == null:
		_stats_label.text = "Statistics: --"
		return
	
	var lines: Array[String] = []
	
	# Terrain distribution (top 5 only to save space)
	var stats := _hex_grid.get_terrain_statistics()
	var sorted_terrains: Array = []
	for terrain in stats:
		sorted_terrains.append({"name": terrain, "count": stats[terrain]})
	sorted_terrains.sort_custom(func(a, b): return a["count"] > b["count"])
	
	lines.append("Terrain (top 5):")
	for i in range(mini(5, sorted_terrains.size())):
		var item = sorted_terrains[i]
		lines.append("  %s: %d" % [item["name"], item["count"]])
	
	# Rivers
	var rivers := _hex_grid.get_rivers()
	lines.append("")
	lines.append("Rivers: %d" % rivers.size())
	
	# Locations
	var locations := _hex_grid.get_all_locations()
	lines.append("Locations: %d" % locations.size())
	
	var loc_types := {}
	for loc in locations.values():
		var t: String = loc["type"]
		loc_types[t] = loc_types.get(t, 0) + 1
	
	for loc_type in loc_types:
		lines.append("  %s: %d" % [loc_type, loc_types[loc_type]])
	
	_stats_label.text = "\n".join(lines)

# =============================================================================
# PUBLIC API
# =============================================================================

## Shows the generation panel.
func show_panel() -> void:
	_find_hex_grid_sync()
	_update_current_seed_display()
	_update_statistics()
	_refresh_save_list()
	visible = true
	_seed_input.grab_focus()


## Hides the generation panel.
func hide_panel() -> void:
	visible = false
	panel_closed.emit()


## Toggles panel visibility.
func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


## Sets the hex grid reference manually.
func set_hex_grid(grid: HexGrid) -> void:
	_hex_grid = grid
	_update_current_seed_display()
	_update_statistics()


func _find_hex_grid_sync() -> void:
	if _hex_grid != null:
		return
	
	var grids = get_tree().get_nodes_in_group("hex_grid")
	if grids.size() > 0:
		_hex_grid = grids[0]
	else:
		var root = get_tree().current_scene
		if root:
			_hex_grid = _find_node_by_type(root, "HexGrid")


# =============================================================================
# FOG DEBUG HANDLERS
# =============================================================================

func _on_fog_toggle(button_pressed: bool) -> void:
	var fog_manager = get_tree().get_first_node_in_group("fog_manager") as FogOfWarManager
	if fog_manager:
		fog_manager.toggle_fog(not button_pressed)
		_fog_toggle_button.text = "Show Fog" if button_pressed else "Hide Fog (Debug)"


func _on_fog_reveal_pressed() -> void:
	var fog_manager = get_tree().get_first_node_in_group("fog_manager") as FogOfWarManager
	if fog_manager:
		fog_manager.reveal_entire_map()


func _on_fog_reset_pressed() -> void:
	var fog_manager = get_tree().get_first_node_in_group("fog_manager") as FogOfWarManager
	if fog_manager:
		fog_manager.reset_fog()
