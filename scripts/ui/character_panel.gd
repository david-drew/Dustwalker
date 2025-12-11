# character_panel.gd
# UI panel displaying character stats, skills, and talents.
# Toggle-able with hotkey (default: C).
#
# Listens for player data and updates display accordingly.

extends Control
class_name CharacterPanel

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var panel_color: Color = Color(0.1, 0.1, 0.12, 0.95)
@export var border_color: Color = Color(0.4, 0.35, 0.28)
@export var title_color: Color = Color(0.85, 0.75, 0.55)
@export var text_color: Color = Color(0.9, 0.85, 0.7)
@export var muted_color: Color = Color(0.6, 0.55, 0.45)
@export var toggle_key: Key = KEY_C

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _panel: PanelContainer
var _vbox: VBoxContainer
var _name_label: Label
var _background_label: Label

# Stats section
var _stats_grid: GridContainer
var _stat_labels: Dictionary = {}  # stat_name -> Label

# Skills section
var _skills_vbox: VBoxContainer
var _skill_labels: Dictionary = {}  # skill_name -> Label

# Talents section
var _talents_vbox: VBoxContainer

# =============================================================================
# STATE
# =============================================================================

var _is_visible: bool = false
var _player: Node = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_signals()
	visible = false


func _create_ui() -> void:
	# Position on left side of screen
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(10, 10)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 0)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel_color
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel_style.set_border_width_all(2)
	panel_style.border_color = border_color
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	
	# Main layout
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(_vbox)
	
	# Header
	_create_header()
	
	# Stats section
	_create_stats_section()
	
	# Skills section
	_create_skills_section()
	
	# Talents section
	_create_talents_section()
	
	# Close hint
	var hint := Label.new()
	hint.text = "Press [C] to close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", muted_color)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(hint)


func _create_header() -> void:
	# Character name
	_name_label = Label.new()
	_name_label.text = "Unknown"
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", title_color)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_name_label)
	
	# Background
	_background_label = Label.new()
	_background_label.text = "Wanderer"
	_background_label.add_theme_font_size_override("font_size", 16)
	_background_label.add_theme_color_override("font_color", muted_color)
	_background_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_background_label)
	
	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_vbox.add_child(sep)


func _create_stats_section() -> void:
	var header := Label.new()
	header.text = "Stats"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", title_color)
	_vbox.add_child(header)
	
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4  # Name, Value, Name, Value (2 columns of stats)
	_stats_grid.add_theme_constant_override("h_separation", 12)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	_vbox.add_child(_stats_grid)
	
	# Create stat labels (8 stats, 2 columns)
	var stat_order := ["grit", "reflex", "aim", "wit", "charm", "fortitude", "stealth", "spirit"]
	
	for stat_name in stat_order:
		# Stat name
		var name_label := Label.new()
		name_label.text = stat_name.capitalize() + ":"
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", text_color)
		name_label.custom_minimum_size.x = 70
		_stats_grid.add_child(name_label)
		
		# Stat value
		var value_label := Label.new()
		value_label.text = "0"
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", title_color)
		value_label.custom_minimum_size.x = 30
		_stats_grid.add_child(value_label)
		
		_stat_labels[stat_name] = value_label


func _create_skills_section() -> void:
	var sep := HSeparator.new()
	_vbox.add_child(sep)
	
	var header := Label.new()
	header.text = "Skills"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", title_color)
	_vbox.add_child(header)
	
	_skills_vbox = VBoxContainer.new()
	_skills_vbox.add_theme_constant_override("separation", 2)
	_vbox.add_child(_skills_vbox)
	
	# Placeholder - will be populated dynamically
	var placeholder := Label.new()
	placeholder.text = "(No skills)"
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", muted_color)
	_skills_vbox.add_child(placeholder)


func _create_talents_section() -> void:
	var sep := HSeparator.new()
	_vbox.add_child(sep)
	
	var header := Label.new()
	header.text = "Talents"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", title_color)
	_vbox.add_child(header)
	
	_talents_vbox = VBoxContainer.new()
	_talents_vbox.add_theme_constant_override("separation", 4)
	_vbox.add_child(_talents_vbox)
	
	# Placeholder
	var placeholder := Label.new()
	placeholder.text = "(No talents)"
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", muted_color)
	_talents_vbox.add_child(placeholder)


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("player_spawned"):
			event_bus.player_spawned.connect(_on_player_spawned)
		if event_bus.has_signal("stat_changed"):
			event_bus.stat_changed.connect(_on_stat_changed)
		if event_bus.has_signal("skill_level_changed"):
			event_bus.skill_level_changed.connect(_on_skill_changed)
		if event_bus.has_signal("talent_acquired"):
			event_bus.talent_acquired.connect(_on_talent_acquired)

# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			toggle()
			get_viewport().set_input_as_handled()

# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_all() -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	
	if not _player:
		return
	
	_update_header()
	_update_stats()
	_update_skills()
	_update_talents()


func _update_header() -> void:
	if not _player:
		return
	
	_name_label.text = _player.player_name if _player.player_name else "Unknown"
	
	# Try to get background from player or character data
	var bg_name := "Wanderer"
	if _player.has_meta("background_id"):
		bg_name = _player.get_meta("background_id").capitalize().replace("_", " ")
	_background_label.text = bg_name


func _update_stats() -> void:
	if not _player or not _player.player_stats:
		return
	
	var stats_node = _player.player_stats
	
	for stat_name in _stat_labels:
		var value := 0
		if stats_node.has_method("get_stat"):
			value = stats_node.get_stat(stat_name)
		elif stats_node.has_method("get_effective_stat"):
			value = stats_node.get_effective_stat(stat_name)
		
		_stat_labels[stat_name].text = str(value)
		
		# Color code: highlight high/low stats
		var color := text_color
		if value >= 4:
			color = Color(0.4, 0.8, 0.4)  # Green for high
		elif value <= 1:
			color = Color(0.8, 0.4, 0.4)  # Red for low
		_stat_labels[stat_name].add_theme_color_override("font_color", color)


func _update_skills() -> void:
	# Clear existing
	for child in _skills_vbox.get_children():
		child.queue_free()
	_skill_labels.clear()
	
	if not _player or not _player.skill_manager:
		var placeholder := Label.new()
		placeholder.text = "(No skills)"
		placeholder.add_theme_font_size_override("font_size", 14)
		placeholder.add_theme_color_override("font_color", muted_color)
		_skills_vbox.add_child(placeholder)
		return
	
	var skill_mgr = _player.skill_manager
	var skills: Dictionary = {}
	
	if skill_mgr.has_method("get_all_skills"):
		skills = skill_mgr.get_all_skills()
	elif skill_mgr.has_method("get_skills"):
		skills = skill_mgr.get_skills()
	
	# Filter to only show skills with level > 0
	var has_skills := false
	for skill_name in skills:
		var level: int = skills[skill_name].get("level", 0) if skills[skill_name] is Dictionary else skills[skill_name]
		if level > 0:
			has_skills = true
			var label := Label.new()
			var display_name: String = skill_name.capitalize().replace("_", " ")
			label.text = "• %s: %d" % [display_name, level]
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", text_color)
			_skills_vbox.add_child(label)
			_skill_labels[skill_name] = label
	
	if not has_skills:
		var placeholder := Label.new()
		placeholder.text = "(No skills learned)"
		placeholder.add_theme_font_size_override("font_size", 14)
		placeholder.add_theme_color_override("font_color", muted_color)
		_skills_vbox.add_child(placeholder)


func _update_talents() -> void:
	# Clear existing
	for child in _talents_vbox.get_children():
		child.queue_free()
	
	if not _player or not _player.talent_manager:
		var placeholder := Label.new()
		placeholder.text = "(No talents)"
		placeholder.add_theme_font_size_override("font_size", 14)
		placeholder.add_theme_color_override("font_color", muted_color)
		_talents_vbox.add_child(placeholder)
		return
	
	var talent_mgr = _player.talent_manager
	var talents: Array = []
	
	if talent_mgr.has_method("get_acquired_talents"):
		talents = talent_mgr.get_acquired_talents()
	elif talent_mgr.has_method("get_talents"):
		talents = talent_mgr.get_talents()
	
	if talents.is_empty():
		var placeholder := Label.new()
		placeholder.text = "(No talents)"
		placeholder.add_theme_font_size_override("font_size", 14)
		placeholder.add_theme_color_override("font_color", muted_color)
		_talents_vbox.add_child(placeholder)
		return
	
	for talent_id in talents:
		var talent_name: String = _get_talent_display_name(talent_id)
		var label := Label.new()
		label.text = "★ " + talent_name
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", title_color)
		_talents_vbox.add_child(label)


func _get_talent_display_name(talent_id: String) -> String:
	# Try EffectManager first
	var effect_mgr = get_tree().get_first_node_in_group("effect_manager")
	if effect_mgr and effect_mgr.has_method("get_effect_definition"):
		var def: Dictionary = effect_mgr.get_effect_definition(talent_id)
		if not def.is_empty():
			return def.get("name", talent_id.capitalize().replace("_", " "))
	
	# Fallback
	return talent_id.capitalize().replace("_", " ")

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_player_spawned(hex_coords: Vector2i) -> void:
	# Defer to let player initialize
	call_deferred("_update_all")


func _on_stat_changed(stat_name: String, new_value: int, old_value: int) -> void:
	if _stat_labels.has(stat_name):
		_stat_labels[stat_name].text = str(new_value)


func _on_skill_changed(skill_name: String, new_level: int, old_level: int) -> void:
	_update_skills()


func _on_talent_acquired(talent_id: String) -> void:
	_update_talents()

# =============================================================================
# PUBLIC API
# =============================================================================

## Toggle panel visibility.
func toggle() -> void:
	_is_visible = not _is_visible
	visible = _is_visible
	
	if _is_visible:
		_update_all()


## Show the panel.
func show_panel() -> void:
	_is_visible = true
	visible = true
	_update_all()


## Hide the panel.
func hide_panel() -> void:
	_is_visible = false
	visible = false


## Force refresh all data.
func refresh() -> void:
	_update_all()
