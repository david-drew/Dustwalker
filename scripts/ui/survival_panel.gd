# survival_panel.gd
# UI panel displaying player survival stats (hunger, thirst, health).
# Shows colored bars with gradients based on current levels.
#
# VISUAL DESIGN:
# - Three horizontal bars with labels
# - Color gradient from green (safe) to red (critical)
# - Flash/pulse animation for warnings

extends Control
class_name SurvivalPanel

# =============================================================================
# CONFIGURATION
# =============================================================================

## Panel background color.
@export var panel_color: Color = Color(0.1, 0.1, 0.12, 0.9)

## Panel border color.
@export var border_color: Color = Color(0.3, 0.3, 0.35)

# Color thresholds (percentages)
var color_safe: Color = Color(0.3, 0.8, 0.3)       # Green (80-100%)
var color_warning: Color = Color(0.9, 0.8, 0.2)    # Yellow (50-80%)
var color_danger: Color = Color(0.9, 0.5, 0.2)     # Orange (30-50%)
var color_critical: Color = Color(0.9, 0.2, 0.2)   # Red (0-30%)

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _panel: PanelContainer
var _vbox: VBoxContainer

var _health_bar: ProgressBar
var _health_label: Label
var _hunger_bar: ProgressBar
var _hunger_label: Label
var _thirst_bar: ProgressBar
var _thirst_label: Label

var _warning_label: Label

# =============================================================================
# STATE
# =============================================================================

var _survival_manager: SurvivalManager = null
var _flash_tween: Tween = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	_connect_signals()


func _create_ui() -> void:
	# Position in bottom-right using proper anchoring
	#position = Vector2(10,500)
	#anchor_left = 1.0
	#anchor_right = 1.0
	#anchor_top = 1.0
	#anchor_bottom = 1.0
	#offset_left = -340
	#offset_right = -10
	#offset_top = -290
	#offset_bottom = -115  # Leave room for inventory panel below
	
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
	_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(_vbox)
	
	# Title
	var title := Label.new()
	title.text = "Survival"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title)
	
	# Health bar
	_create_stat_bar("Health", "health")
	
	# Hunger bar
	_create_stat_bar("Hunger", "hunger")
	
	# Thirst bar
	_create_stat_bar("Thirst", "thirst")
	
	# Warning label (hidden by default)
	_warning_label = Label.new()
	_warning_label.name = "WarningLabel"
	_warning_label.text = ""
	_warning_label.add_theme_font_size_override("font_size", 24)
	_warning_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_label.visible = false
	_vbox.add_child(_warning_label)


func _create_stat_bar(label_text: String, stat_name: String) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	_vbox.add_child(container)
	
	# Row with label and value
	var row := HBoxContainer.new()
	container.add_child(row)
	
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	
	var value_label := Label.new()
	value_label.name = stat_name + "_value"
	value_label.text = "10/10"
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	row.add_child(value_label)
	
	# Progress bar
	var bar := ProgressBar.new()
	bar.name = stat_name + "_bar"
	bar.min_value = 0
	bar.max_value = 10
	bar.value = 10
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(280, 18)
	
	# Style the bar
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.18)
	bg_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color_safe
	fill_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_style)
	
	container.add_child(bar)
	
	# Store references
	match stat_name:
		"health":
			_health_bar = bar
			_health_label = value_label
		"hunger":
			_hunger_bar = bar
			_hunger_label = value_label
		"thirst":
			_thirst_bar = bar
			_thirst_label = value_label


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("hunger_changed"):
			event_bus.hunger_changed.connect(_on_hunger_changed)
		if event_bus.has_signal("thirst_changed"):
			event_bus.thirst_changed.connect(_on_thirst_changed)
		if event_bus.has_signal("health_changed"):
			event_bus.health_changed.connect(_on_health_changed)
		if event_bus.has_signal("survival_warning"):
			event_bus.survival_warning.connect(_on_survival_warning)


## Initialize with reference to survival manager.
func initialize(survival_mgr: SurvivalManager) -> void:
	_survival_manager = survival_mgr
	
	if _survival_manager:
		# Set max values
		_health_bar.max_value = _survival_manager.max_health
		_hunger_bar.max_value = _survival_manager.max_hunger
		_thirst_bar.max_value = _survival_manager.max_thirst
		
		# Initial update
		_update_all_bars()

# =============================================================================
# BAR UPDATES
# =============================================================================

func _update_all_bars() -> void:
	if _survival_manager == null:
		return
	
	_update_bar(_health_bar, _health_label, _survival_manager.health, _survival_manager.max_health)
	_update_bar(_hunger_bar, _hunger_label, _survival_manager.hunger, _survival_manager.max_hunger)
	_update_bar(_thirst_bar, _thirst_label, _survival_manager.thirst, _survival_manager.max_thirst)


func _update_bar(bar: ProgressBar, label: Label, value: int, max_value: int) -> void:
	bar.value = value
	label.text = "%d/%d" % [value, max_value]
	
	# Update color based on percentage
	var percent := float(value) / float(max_value) if max_value > 0 else 0.0
	var color := _get_bar_color(percent)
	
	var fill_style := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill_style.bg_color = color
	bar.add_theme_stylebox_override("fill", fill_style)


func _get_bar_color(percent: float) -> Color:
	if percent >= 0.8:
		return color_safe
	elif percent >= 0.5:
		# Interpolate between warning and safe
		var t := (percent - 0.5) / 0.3
		return color_warning.lerp(color_safe, t)
	elif percent >= 0.3:
		# Interpolate between danger and warning
		var t := (percent - 0.3) / 0.2
		return color_danger.lerp(color_warning, t)
	else:
		# Interpolate between critical and danger
		var t := percent / 0.3
		return color_critical.lerp(color_danger, t)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_hunger_changed(new_value: int, old_value: int) -> void:
	if _survival_manager:
		_update_bar(_hunger_bar, _hunger_label, new_value, _survival_manager.max_hunger)
		
		# Flash if decreased
		if new_value < old_value:
			_flash_bar(_hunger_bar)


func _on_thirst_changed(new_value: int, old_value: int) -> void:
	if _survival_manager:
		_update_bar(_thirst_bar, _thirst_label, new_value, _survival_manager.max_thirst)
		
		# Flash if decreased
		if new_value < old_value:
			_flash_bar(_thirst_bar)


func _on_health_changed(new_value: int, old_value: int, source: String) -> void:
	if _survival_manager:
		_update_bar(_health_bar, _health_label, new_value, _survival_manager.max_health)
		
		# Flash if damaged
		if new_value < old_value:
			_flash_bar(_health_bar)


func _on_survival_warning(warning_type: String, level: int) -> void:
	var message := ""
	
	match warning_type:
		"hunger_warning":
			message = "You're getting hungry..."
		"hunger_critical":
			message = "You're starving!"
		"thirst_warning":
			message = "You need water..."
		"thirst_critical":
			message = "You're dehydrated!"
		"health_warning":
			message = "Your health is low"
		"health_critical":
			message = "You're badly injured!"
	
	if message != "":
		_show_warning(message)

# =============================================================================
# VISUAL EFFECTS
# =============================================================================

func _flash_bar(bar: ProgressBar) -> void:
	# Flash the bar white briefly
	var original_color := (bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color
	
	var flash_style := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	flash_style.bg_color = Color.WHITE
	bar.add_theme_stylebox_override("fill", flash_style)
	
	# Restore after delay
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func():
		var restore_style := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		restore_style.bg_color = original_color
		bar.add_theme_stylebox_override("fill", restore_style)
	)


func _show_warning(message: String) -> void:
	_warning_label.text = message
	_warning_label.visible = true
	_warning_label.modulate.a = 1.0
	
	# Pulse the panel
	_flash_panel()
	
	# Fade out warning after delay
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	
	_flash_tween = create_tween()
	_flash_tween.tween_interval(2.0)
	_flash_tween.tween_property(_warning_label, "modulate:a", 0.0, 0.5)
	_flash_tween.tween_callback(func(): _warning_label.visible = false)


func _flash_panel() -> void:
	var flash := ColorRect.new()
	flash.color = Color(0.9, 0.3, 0.2, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(flash)
	
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)

# =============================================================================
# PUBLIC API
# =============================================================================

## Force refresh all bars.
func refresh() -> void:
	_update_all_bars()
