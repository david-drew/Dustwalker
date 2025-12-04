# turn_panel.gd
# UI panel displaying current turn, day, time of day, and turn controls.
# Located in top-left corner of the screen.

extends Control
class_name TurnPanel

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when End Turn button is pressed.
signal end_turn_requested()

## Emitted when turn summary is clicked (for details).
signal summary_clicked()

# =============================================================================
# CONFIGURATION
# =============================================================================

## Panel background color.
@export var panel_color: Color = Color(0.1, 0.1, 0.12, 0.9)

## Panel border color.
@export var border_color: Color = Color(0.3, 0.3, 0.35)

## Day text color.
@export var day_color: Color = Color(0.95, 0.85, 0.5)

## Turn text color.
@export var turn_color: Color = Color(0.7, 0.85, 0.95)

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _panel: PanelContainer
var _vbox: VBoxContainer
var _day_label: Label
var _time_row: HBoxContainer
var _time_icon_label: Label
var _time_name_label: Label
var _turn_label: Label
var _turns_remaining_label: Label
var _end_turn_button: Button
var _summary_container: VBoxContainer
var _summary_label: Label
var _history_container: VBoxContainer
var _history_scroll: ScrollContainer

# Exploration UI nodes
var _exploration_toggle: Button
var _exploration_container: VBoxContainer
var _exploration_count_label: Label
var _exploration_percent_label: Label
var _exploration_today_label: Label
var _locations_label: Label
var _vision_label: Label

# =============================================================================
# STATE
# =============================================================================

## Turn history (last N entries).
var _turn_history: Array[String] = []
var _max_history: int = 10

## Whether exploration stats are expanded.
var _exploration_expanded: bool = true

## Whether the player is currently moving.
var _player_moving: bool = false

## Current turn action summary.
var _current_summary: Array[String] = []

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_signals()
	_update_display()


func _create_ui() -> void:
	# Position in top-left
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(3100, 10)
	custom_minimum_size = Vector2(320, 0)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel_color
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = border_color
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	
	# Main layout
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(_vbox)
	
	# Day display
	_day_label = Label.new()
	_day_label.text = "Day 1"
	_day_label.add_theme_font_size_override("font_size", 36)
	_day_label.add_theme_color_override("font_color", day_color)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_day_label)
	
	# Time of day row (icon + name)
	_time_row = HBoxContainer.new()
	_time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_time_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(_time_row)
	
	_time_icon_label = Label.new()
	_time_icon_label.text = "☀️"
	_time_icon_label.add_theme_font_size_override("font_size", 28)
	_time_row.add_child(_time_icon_label)
	
	_time_name_label = Label.new()
	_time_name_label.text = "Morning"
	_time_name_label.add_theme_font_size_override("font_size", 26)
	_time_name_label.add_theme_color_override("font_color", turn_color)
	_time_row.add_child(_time_name_label)
	
	# Turn number
	_turn_label = Label.new()
	_turn_label.text = "Turn 3 of 6"
	_turn_label.add_theme_font_size_override("font_size", 24)
	_turn_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_turn_label)
	
	# Turns remaining
	_turns_remaining_label = Label.new()
	_turns_remaining_label.text = "3 turns until nightfall"
	_turns_remaining_label.add_theme_font_size_override("font_size", 24)
	_turns_remaining_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_turns_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_turns_remaining_label)
	
	# Separator
	_vbox.add_child(_create_separator())
	
	# Current turn summary
	_summary_container = VBoxContainer.new()
	_summary_container.add_theme_constant_override("separation", 4)
	_vbox.add_child(_summary_container)
	
	var summary_header := Label.new()
	summary_header.text = "This Turn:"
	summary_header.add_theme_font_size_override("font_size", 24)
	summary_header.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
	_summary_container.add_child(summary_header)
	
	_summary_label = Label.new()
	_summary_label.text = "—"
	_summary_label.add_theme_font_size_override("font_size", 24)
	_summary_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.custom_minimum_size.x = 280
	_summary_container.add_child(_summary_label)
	
	# Separator
	_vbox.add_child(_create_separator())
	
	# End Turn button
	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size.y = 48
	_end_turn_button.add_theme_font_size_override("font_size", 24)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_vbox.add_child(_end_turn_button)
	
	# Style button
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.25, 0.35, 0.25)
	button_style.set_corner_radius_all(6)
	button_style.set_content_margin_all(10)
	_end_turn_button.add_theme_stylebox_override("normal", button_style)
	
	var button_hover := button_style.duplicate()
	button_hover.bg_color = Color(0.3, 0.45, 0.3)
	_end_turn_button.add_theme_stylebox_override("hover", button_hover)
	
	var button_pressed := button_style.duplicate()
	button_pressed.bg_color = Color(0.2, 0.3, 0.2)
	_end_turn_button.add_theme_stylebox_override("pressed", button_pressed)
	
	var button_disabled := button_style.duplicate()
	button_disabled.bg_color = Color(0.2, 0.2, 0.2)
	_end_turn_button.add_theme_stylebox_override("disabled", button_disabled)
	
	# History section (collapsible, initially hidden)
	_history_container = VBoxContainer.new()
	_history_container.visible = false
	_history_container.add_theme_constant_override("separation", 4)
	_vbox.add_child(_history_container)
	
	var history_header := Label.new()
	history_header.text = "Recent:"
	history_header.add_theme_font_size_override("font_size", 24)
	history_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_history_container.add_child(history_header)
	
	_history_scroll = ScrollContainer.new()
	_history_scroll.custom_minimum_size = Vector2(280, 80)
	_history_container.add_child(_history_scroll)
	
	# Separator before exploration
	_vbox.add_child(_create_separator())
	
	# Exploration toggle button
	_exploration_toggle = Button.new()
	_exploration_toggle.text = "▼ Exploration"
	_exploration_toggle.flat = true
	_exploration_toggle.add_theme_font_size_override("font_size", 24)
	_exploration_toggle.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_exploration_toggle.pressed.connect(_on_exploration_toggle_pressed)
	_vbox.add_child(_exploration_toggle)
	
	# Exploration stats container (collapsible)
	_exploration_container = VBoxContainer.new()
	_exploration_container.add_theme_constant_override("separation", 4)
	_vbox.add_child(_exploration_container)
	
	# Explored count
	_exploration_count_label = Label.new()
	_exploration_count_label.text = "Explored: 0 / 900"
	_exploration_count_label.add_theme_font_size_override("font_size", 24)
	_exploration_count_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.65))
	_exploration_container.add_child(_exploration_count_label)
	
	# Percentage bar/label
	_exploration_percent_label = Label.new()
	_exploration_percent_label.text = "Progress: 0.0%"
	_exploration_percent_label.add_theme_font_size_override("font_size", 24)
	_exploration_percent_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
	_exploration_container.add_child(_exploration_percent_label)
	
	# Explored today
	_exploration_today_label = Label.new()
	_exploration_today_label.text = "Today: 0 new"
	_exploration_today_label.add_theme_font_size_override("font_size", 24)
	_exploration_today_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
	_exploration_container.add_child(_exploration_today_label)
	
	# Locations discovered
	_locations_label = Label.new()
	_locations_label.text = "Locations: 0"
	_locations_label.add_theme_font_size_override("font_size", 24)
	_locations_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_exploration_container.add_child(_locations_label)
	
	# Vision range
	_vision_label = Label.new()
	_vision_label.text = "Vision: 2 hexes"
	_vision_label.add_theme_font_size_override("font_size", 24)
	_vision_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	_exploration_container.add_child(_vision_label)


func _create_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	return sep


func _connect_signals() -> void:
	# Connect to TimeManager signals
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if time_manager.has_signal("turn_started"):
			time_manager.turn_started.connect(_on_turn_started)
		if time_manager.has_signal("turn_advanced"):
			time_manager.turn_advanced.connect(_on_turn_advanced)
		if time_manager.has_signal("day_started"):
			time_manager.day_started.connect(_on_day_started)
	
	# Connect to EventBus signals
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("player_movement_started"):
			event_bus.player_movement_started.connect(_on_player_movement_started)
		if event_bus.has_signal("player_movement_completed"):
			event_bus.player_movement_completed.connect(_on_player_movement_completed)
		if event_bus.has_signal("exploration_stats_updated"):
			event_bus.exploration_stats_updated.connect(_on_exploration_stats_updated)
		if event_bus.has_signal("vision_range_changed"):
			event_bus.vision_range_changed.connect(_on_vision_range_changed)

# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_display() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return
	
	var data: Dictionary = time_manager.get_time_data()
	
	# Day
	_day_label.text = "Day %d" % data["day"]
	
	# Time icon and name
	_time_icon_label.text = data["time_icon"]
	_time_name_label.text = data["time_name"]
	
	# Update time name color based on day/night
	if data["is_daytime"]:
		_time_name_label.add_theme_color_override("font_color", turn_color)
	else:
		_time_name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	
	# Turn number
	_turn_label.text = "Turn %d of 6" % data["turn"]
	
	# Turns remaining message
	var remaining: int = data["turns_remaining_today"]
	if remaining == 0:
		_turns_remaining_label.text = "Day ending soon"
		_turns_remaining_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
	elif data["turn"] <= 2:
		_turns_remaining_label.text = "%d turns until noon" % (3 - data["turn"])
	elif data["turn"] <= 5:
		_turns_remaining_label.text = "%d turns until night" % remaining
	else:
		_turns_remaining_label.text = "Night has fallen"
	
	# Update button state
	_update_button_state()


func _update_button_state() -> void:
	if _player_moving:
		_end_turn_button.text = "Moving..."
		_end_turn_button.disabled = false  # Can still click, will wait for movement
		_end_turn_button.tooltip_text = "Movement will complete first"
	else:
		_end_turn_button.text = "End Turn"
		_end_turn_button.disabled = false
		_end_turn_button.tooltip_text = "Advance to next turn"


func _update_summary() -> void:
	if _current_summary.is_empty():
		_summary_label.text = "—"
	else:
		_summary_label.text = "\n".join(_current_summary)

# =============================================================================
# TURN SUMMARY
# =============================================================================

## Adds an action to the current turn summary.
func add_summary_entry(entry: String) -> void:
	_current_summary.append(entry)
	_update_summary()


## Clears the current turn summary.
func clear_summary() -> void:
	_current_summary.clear()
	_update_summary()


## Adds an entry to turn history.
func add_history_entry(entry: String) -> void:
	_turn_history.push_front(entry)
	if _turn_history.size() > _max_history:
		_turn_history.pop_back()

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_end_turn_pressed() -> void:
	if _player_moving:
		# Movement will complete, then we'll end turn
		# For now, just let the movement finish
		return
	
	end_turn_requested.emit()
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.end_turn()


func _on_turn_started(turn: int, day: int, time_name: String) -> void:
	# Save previous summary to history
	if not _current_summary.is_empty():
		var history_entry := "Day %d, Turn %d: %s" % [day, turn - 1, ", ".join(_current_summary)]
		add_history_entry(history_entry)
	
	# Clear summary for new turn
	clear_summary()
	_update_display()
	
	# Brief visual feedback
	_flash_panel()


func _on_turn_advanced(old_turn: int, new_turn: int, turns_consumed: int) -> void:
	_update_display()


func _on_day_started(day: int) -> void:
	_update_display()
	
	# More prominent visual feedback for new day
	_flash_panel(Color(0.8, 0.7, 0.3, 0.3))


func _on_player_movement_started(from_hex: Vector2i, to_hex: Vector2i) -> void:
	_player_moving = true
	_update_button_state()


func _on_player_movement_completed(total_hexes: int, total_turns: int) -> void:
	_player_moving = false
	_update_button_state()
	
	# Add to summary
	add_summary_entry("Moved %d hex%s (%d turn%s)" % [
		total_hexes,
		"es" if total_hexes != 1 else "",
		total_turns,
		"s" if total_turns != 1 else ""
	])


func _on_exploration_stats_updated(explored_count: int, total_count: int, percentage: float) -> void:
	_update_exploration_display(explored_count, total_count, percentage)


func _on_vision_range_changed(old_range: int, new_range: int) -> void:
	if _vision_label:
		_vision_label.text = "Vision: %d hexes" % new_range


func _on_exploration_toggle_pressed() -> void:
	_exploration_expanded = not _exploration_expanded
	_exploration_container.visible = _exploration_expanded
	_exploration_toggle.text = "▼ Exploration" if _exploration_expanded else "▶ Exploration"


func _update_exploration_display(explored: int, total: int, percentage: float) -> void:
	if _exploration_count_label:
		_exploration_count_label.text = "Explored: %d / %d" % [explored, total]
	
	if _exploration_percent_label:
		_exploration_percent_label.text = "Progress: %.1f%%" % (percentage * 100.0)
	
	# Get additional stats from fog manager
	var fog_manager = get_tree().get_first_node_in_group("fog_manager") as FogOfWarManager
	if fog_manager:
		if _exploration_today_label:
			_exploration_today_label.text = "Today: %d new" % fog_manager.get_explored_today()
		if _locations_label:
			_locations_label.text = "Locations: %d" % fog_manager.get_locations_discovered()
		if _vision_label:
			_vision_label.text = "Vision: %d hexes" % fog_manager.get_vision_range()


func _flash_panel(color: Color = Color(0.3, 0.5, 0.3, 0.3)) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(flash)
	
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

# =============================================================================
# PUBLIC API
# =============================================================================

## Shows or hides the history section.
func set_history_visible(visible: bool) -> void:
	_history_container.visible = visible


## Shows or hides the exploration section.
func set_exploration_visible(visible: bool) -> void:
	_exploration_expanded = visible
	_exploration_container.visible = visible
	_exploration_toggle.text = "▼ Exploration" if visible else "▶ Exploration"


## Forces a display refresh.
func refresh() -> void:
	_update_display()
