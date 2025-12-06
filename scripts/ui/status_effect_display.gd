# status_effect_display.gd
# UI component that displays active status effects as icons with tooltips.
# Shows survival states, weather effects, diseases, and other conditions.
#
# FEATURES:
# - Compact icon bar for active effects
# - Color-coded severity (green/yellow/red)
# - Tooltips with details
# - Auto-updates when conditions change
#
# DEPENDENCIES:
# - SurvivalManager: For survival states
# - WeatherManager: For weather effects
# - DiseaseManager: For diseases (optional)

extends Control
class_name StatusEffectDisplay

# =============================================================================
# CONFIGURATION
# =============================================================================

## Background color for the status bar.
@export var background_color: Color = Color(0.08, 0.08, 0.1, 0.85)

## Icon size in pixels.
@export var icon_size: int = 28

## Spacing between icons.
@export var icon_spacing: int = 4

## Show labels under icons.
@export var show_labels: bool = false

# =============================================================================
# CONSTANTS
# =============================================================================

## Status effect definitions with icons and colors
var STATUS_DEFINITIONS := {
	# Fatigue levels
	"rested": {
		"icon": "💤",
		"label": "Rested",
		"color": Color(0.4, 0.8, 0.4),
		"category": "fatigue",
		"priority": 0
	},
	"tired": {
		"icon": "😐",
		"label": "Tired",
		"color": Color(0.9, 0.9, 0.4),
		"category": "fatigue",
		"priority": 1
	},
	"weary": {
		"icon": "😩",
		"label": "Weary",
		"color": Color(0.9, 0.6, 0.3),
		"category": "fatigue",
		"priority": 2
	},
	"exhausted": {
		"icon": "😫",
		"label": "Exhausted",
		"color": Color(0.9, 0.4, 0.3),
		"category": "fatigue",
		"priority": 3
	},
	"collapsing": {
		"icon": "💀",
		"label": "Collapsing",
		"color": Color(0.9, 0.2, 0.2),
		"category": "fatigue",
		"priority": 4
	},
	
	# Hunger levels
	"well_fed": {
		"icon": "🍖",
		"label": "Well Fed",
		"color": Color(0.4, 0.8, 0.4),
		"category": "hunger",
		"priority": 0
	},
	"satisfied": {
		"icon": "🍞",
		"label": "Satisfied",
		"color": Color(0.6, 0.8, 0.5),
		"category": "hunger",
		"priority": 0
	},
	"hungry": {
		"icon": "🍽️",
		"label": "Hungry",
		"color": Color(0.9, 0.7, 0.3),
		"category": "hunger",
		"priority": 2
	},
	"starving": {
		"icon": "💀",
		"label": "Starving",
		"color": Color(0.9, 0.3, 0.3),
		"category": "hunger",
		"priority": 4
	},
	
	# Thirst levels
	"hydrated": {
		"icon": "💧",
		"label": "Hydrated",
		"color": Color(0.4, 0.7, 0.9),
		"category": "thirst",
		"priority": 0
	},
	"thirsty": {
		"icon": "🏜️",
		"label": "Thirsty",
		"color": Color(0.9, 0.7, 0.3),
		"category": "thirst",
		"priority": 2
	},
	"dehydrated": {
		"icon": "🔥",
		"label": "Dehydrated",
		"color": Color(0.9, 0.3, 0.3),
		"category": "thirst",
		"priority": 4
	},
	
	# Temperature zones
	"comfortable": {
		"icon": "😊",
		"label": "Comfortable",
		"color": Color(0.4, 0.8, 0.4),
		"category": "temperature",
		"priority": 0
	},
	"warm": {
		"icon": "🌡️",
		"label": "Warm",
		"color": Color(0.9, 0.7, 0.4),
		"category": "temperature",
		"priority": 1
	},
	"hot": {
		"icon": "🥵",
		"label": "Hot",
		"color": Color(0.9, 0.5, 0.3),
		"category": "temperature",
		"priority": 2
	},
	"extreme_heat": {
		"icon": "☀️",
		"label": "Extreme Heat",
		"color": Color(0.9, 0.2, 0.2),
		"category": "temperature",
		"priority": 4
	},
	"cool": {
		"icon": "❄️",
		"label": "Cool",
		"color": Color(0.5, 0.7, 0.9),
		"category": "temperature",
		"priority": 1
	},
	"cold": {
		"icon": "🥶",
		"label": "Cold",
		"color": Color(0.4, 0.5, 0.9),
		"category": "temperature",
		"priority": 2
	},
	"extreme_cold": {
		"icon": "🧊",
		"label": "Extreme Cold",
		"color": Color(0.3, 0.3, 0.9),
		"category": "temperature",
		"priority": 4
	},
	
	# Weather effects
	"weather_clear": {
		"icon": "☀️",
		"label": "Clear",
		"color": Color(0.9, 0.9, 0.5),
		"category": "weather",
		"priority": 0
	},
	"weather_overcast": {
		"icon": "☁️",
		"label": "Overcast",
		"color": Color(0.6, 0.6, 0.7),
		"category": "weather",
		"priority": 1
	},
	"weather_rain": {
		"icon": "🌧️",
		"label": "Rain",
		"color": Color(0.4, 0.5, 0.8),
		"category": "weather",
		"priority": 2
	},
	"weather_dust_storm": {
		"icon": "🌪️",
		"label": "Dust Storm",
		"color": Color(0.8, 0.6, 0.3),
		"category": "weather",
		"priority": 3
	},
	"weather_fog": {
		"icon": "🌫️",
		"label": "Fog",
		"color": Color(0.7, 0.7, 0.8),
		"category": "weather",
		"priority": 2
	},
	"weather_heat_wave": {
		"icon": "🔥",
		"label": "Heat Wave",
		"color": Color(0.9, 0.4, 0.2),
		"category": "weather",
		"priority": 3
	},
	"weather_cold_snap": {
		"icon": "❄️",
		"label": "Cold Snap",
		"color": Color(0.3, 0.5, 0.9),
		"category": "weather",
		"priority": 3
	},
	
	# Time of day
	"time_dawn": {
		"icon": "🌅",
		"label": "Dawn",
		"color": Color(0.9, 0.7, 0.5),
		"category": "time",
		"priority": 0
	},
	"time_day": {
		"icon": "☀️",
		"label": "Day",
		"color": Color(0.9, 0.9, 0.5),
		"category": "time",
		"priority": 0
	},
	"time_dusk": {
		"icon": "🌇",
		"label": "Dusk",
		"color": Color(0.9, 0.5, 0.4),
		"category": "time",
		"priority": 0
	},
	"time_night": {
		"icon": "🌙",
		"label": "Night",
		"color": Color(0.4, 0.4, 0.7),
		"category": "time",
		"priority": 1
	},
	"time_late_night": {
		"icon": "🌑",
		"label": "Late Night",
		"color": Color(0.3, 0.3, 0.5),
		"category": "time",
		"priority": 2
	},
	
	# Diseases (generic - will be populated from DiseaseManager)
	"disease_mild": {
		"icon": "🤒",
		"label": "Ill (Mild)",
		"color": Color(0.8, 0.8, 0.4),
		"category": "disease",
		"priority": 2
	},
	"disease_moderate": {
		"icon": "🤢",
		"label": "Ill (Moderate)",
		"color": Color(0.9, 0.6, 0.3),
		"category": "disease",
		"priority": 3
	},
	"disease_severe": {
		"icon": "🤮",
		"label": "Ill (Severe)",
		"color": Color(0.9, 0.3, 0.3),
		"category": "disease",
		"priority": 4
	},
	
	# Combat/special states
	"in_combat": {
		"icon": "⚔️",
		"label": "In Combat",
		"color": Color(0.9, 0.3, 0.3),
		"category": "special",
		"priority": 5
	},
	"wounded": {
		"icon": "🩸",
		"label": "Wounded",
		"color": Color(0.9, 0.3, 0.3),
		"category": "health",
		"priority": 3
	},
	"healthy": {
		"icon": "❤️",
		"label": "Healthy",
		"color": Color(0.4, 0.8, 0.4),
		"category": "health",
		"priority": 0
	}
}

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _background: ColorRect
var _icon_container: HBoxContainer
var _status_icons: Dictionary = {}  # status_id -> Control

# =============================================================================
# STATE
# =============================================================================

var _survival_manager: SurvivalManager = null
var _weather_manager = null
var _disease_manager = null
var _active_statuses: Dictionary = {}  # status_id -> tooltip_text

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("status_effect_display")
	_create_ui()
	_connect_signals()
	
	# Initial update after a frame
	await get_tree().process_frame
	_find_references()
	_update_all_statuses()


func _create_ui() -> void:
	# Main container
	custom_minimum_size = Vector2(200, icon_size + 8)
	
	# Background
	_background = ColorRect.new()
	_background.color = background_color
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	
	# Margin container for padding
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)
	
	# Icon container
	_icon_container = HBoxContainer.new()
	_icon_container.add_theme_constant_override("separation", icon_spacing)
	_icon_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(_icon_container)


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		# Survival signals
		if event_bus.has_signal("fatigue_level_changed"):
			event_bus.fatigue_level_changed.connect(_on_fatigue_changed)
		if event_bus.has_signal("hunger_stage_changed"):
			event_bus.hunger_stage_changed.connect(_on_hunger_changed)
		if event_bus.has_signal("thirst_stage_changed"):
			event_bus.thirst_stage_changed.connect(_on_thirst_changed)
		if event_bus.has_signal("temperature_changed"):
			event_bus.temperature_changed.connect(_on_temperature_changed)
		
		# Weather signals
		if event_bus.has_signal("weather_started"):
			event_bus.weather_started.connect(_on_weather_started)
		if event_bus.has_signal("weather_ended"):
			event_bus.weather_ended.connect(_on_weather_ended)
		
		# Time signals
		if event_bus.has_signal("time_period_changed"):
			event_bus.time_period_changed.connect(_on_time_period_changed)
		
		# Disease signals
		if event_bus.has_signal("disease_contracted"):
			event_bus.disease_contracted.connect(_on_disease_contracted)
		if event_bus.has_signal("disease_cured"):
			event_bus.disease_cured.connect(_on_disease_cured)
		if event_bus.has_signal("disease_stage_changed"):
			event_bus.disease_stage_changed.connect(_on_disease_stage_changed)
		
		# Health signals
		if event_bus.has_signal("player_health_changed"):
			event_bus.player_health_changed.connect(_on_health_changed)


func _find_references() -> void:
	_survival_manager = get_tree().get_first_node_in_group("survival_manager")
	_weather_manager = get_tree().get_first_node_in_group("weather_manager")
	_disease_manager = get_tree().get_first_node_in_group("disease_manager")

# =============================================================================
# STATUS MANAGEMENT
# =============================================================================

func _update_all_statuses() -> void:
	_clear_all_icons()
	
	# Update from SurvivalManager
	if _survival_manager:
		_update_fatigue_status()
		_update_hunger_status()
		_update_thirst_status()
		_update_temperature_status()
		_update_health_status()
	
	# Update from WeatherManager
	if _weather_manager:
		_update_weather_status()
	
	# Update time of day
	_update_time_status()
	
	# Update diseases
	if _disease_manager:
		_update_disease_statuses()


func _update_fatigue_status() -> void:
	if not _survival_manager:
		return
	
	var level: String = _survival_manager.fatigue_level
	var fatigue: int = _survival_manager.fatigue
	var max_fatigue: int = _survival_manager.max_fatigue
	
	# Only show if not rested (to reduce clutter)
	if level != "rested":
		var tooltip := "Fatigue: %d/%d\nLevel: %s" % [fatigue, max_fatigue, level.capitalize()]
		_set_status(level, tooltip)
	else:
		_remove_status("rested")
		_remove_status("tired")
		_remove_status("weary")
		_remove_status("exhausted")
		_remove_status("collapsing")


func _update_hunger_status() -> void:
	if not _survival_manager:
		return
	
	var stage: String = _survival_manager.hunger_stage
	var days: int = _survival_manager.days_without_food
	
	# Only show if hungry or worse
	if stage in ["hungry", "starving"]:
		var tooltip := "Hunger: %s\nDays without food: %d" % [stage.capitalize(), days]
		_set_status(stage, tooltip)
	else:
		_remove_status("hungry")
		_remove_status("starving")


func _update_thirst_status() -> void:
	if not _survival_manager:
		return
	
	var stage: String = _survival_manager.thirst_stage
	
	# Only show if thirsty or worse
	if stage in ["thirsty", "dehydrated"]:
		var tooltip := "Thirst: %s" % stage.capitalize()
		_set_status(stage, tooltip)
	else:
		_remove_status("thirsty")
		_remove_status("dehydrated")


func _update_temperature_status() -> void:
	if not _survival_manager:
		return
	
	var zone: String = _survival_manager.current_temperature_zone
	var temp: float = _survival_manager.feels_like_temperature
	
	# Only show if not comfortable
	if zone != "comfortable":
		var tooltip := "Temperature: %d°F\nZone: %s" % [int(temp), zone.replace("_", " ").capitalize()]
		_set_status(zone, tooltip)
	else:
		for z in ["warm", "hot", "extreme_heat", "cool", "cold", "extreme_cold"]:
			_remove_status(z)


func _update_health_status() -> void:
	if not _survival_manager:
		return
	
	var hp: int = _survival_manager.current_hp
	var max_hp: int = _survival_manager.max_hp
	var percent: float = float(hp) / float(max_hp) if max_hp > 0 else 1.0
	
	if percent < 0.5:
		var tooltip := "Health: %d/%d (%d%%)" % [hp, max_hp, int(percent * 100)]
		_set_status("wounded", tooltip)
	else:
		_remove_status("wounded")


func _update_weather_status() -> void:
	if not _weather_manager:
		return
	
	var weather: String = _weather_manager.get_current_weather()
	
	# Clear old weather statuses
	for w in ["clear", "overcast", "rain", "dust_storm", "fog", "heat_wave", "cold_snap"]:
		_remove_status("weather_" + w)
	
	# Only show active weather (not clear)
	if weather != "clear":
		var status_id := "weather_" + weather
		var data: Dictionary = _weather_manager.get_current_weather_data()
		var turns: int = _weather_manager.get_turns_remaining()
		var tooltip := "%s\n%s\nTurns remaining: %d" % [
			data.get("name", weather.capitalize()),
			data.get("description", ""),
			turns
		]
		_set_status(status_id, tooltip)


func _update_time_status() -> void:
	var env_manager = get_tree().get_first_node_in_group("environment_manager")
	
	# Clear old time statuses
	for t in ["dawn", "day", "dusk", "night", "late_night"]:
		_remove_status("time_" + t)
	
	var period := "day"
	if env_manager and env_manager.has_method("get_current_period"):
		period = env_manager.get_current_period()
	
	# Always show time of day
	var status_id := "time_" + period
	var tooltip := "Time: %s" % period.replace("_", " ").capitalize()
	_set_status(status_id, tooltip)


func _update_disease_statuses() -> void:
	if not _disease_manager:
		return
	
	# Clear old disease statuses
	_remove_status("disease_mild")
	_remove_status("disease_moderate")
	_remove_status("disease_severe")
	
	if not _disease_manager.has_method("get_active_diseases"):
		return
	
	var diseases: Array = _disease_manager.get_active_diseases()
	if diseases.is_empty():
		return
	
	# Find worst disease stage
	var worst_stage := "mild"
	var disease_names: Array[String] = []
	
	for disease in diseases:
		disease_names.append(disease.get("name", "Unknown"))
		var stage: String = disease.get("stage", "mild")
		if stage == "severe":
			worst_stage = "severe"
		elif stage == "moderate" and worst_stage != "severe":
			worst_stage = "moderate"
	
	var status_id := "disease_" + worst_stage
	var tooltip := "Diseases: %s\nStage: %s" % [", ".join(disease_names), worst_stage.capitalize()]
	_set_status(status_id, tooltip)

# =============================================================================
# ICON MANAGEMENT
# =============================================================================

func _set_status(status_id: String, tooltip: String) -> void:
	if not STATUS_DEFINITIONS.has(status_id):
		push_warning("StatusEffectDisplay: Unknown status '%s'" % status_id)
		return
	
	_active_statuses[status_id] = tooltip
	
	if _status_icons.has(status_id):
		# Update existing icon tooltip
		_status_icons[status_id].tooltip_text = tooltip
	else:
		# Create new icon
		_create_status_icon(status_id, tooltip)
	
	_reorder_icons()


func _remove_status(status_id: String) -> void:
	if not _active_statuses.has(status_id):
		return
	
	_active_statuses.erase(status_id)
	
	if _status_icons.has(status_id):
		_status_icons[status_id].queue_free()
		_status_icons.erase(status_id)


func _clear_all_icons() -> void:
	for child in _icon_container.get_children():
		child.queue_free()
	_status_icons.clear()
	_active_statuses.clear()


func _create_status_icon(status_id: String, tooltip: String) -> void:
	var def: Dictionary = STATUS_DEFINITIONS[status_id]
	
	# Container for icon (and optional label)
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Icon label (using emoji)
	var icon_label := Label.new()
	icon_label.text = def.get("icon", "?")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", icon_size)
	icon_label.custom_minimum_size = Vector2(icon_size + 4, icon_size + 4)
	container.add_child(icon_label)
	
	# Optional text label
	if show_labels:
		var text_label := Label.new()
		text_label.text = def.get("label", status_id)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.add_theme_font_size_override("font_size", 10)
		text_label.add_theme_color_override("font_color", def.get("color", Color.WHITE))
		container.add_child(text_label)
	
	# Tooltip
	container.tooltip_text = tooltip
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Color tint using modulate on the icon
	icon_label.modulate = def.get("color", Color.WHITE)
	
	# Store reference
	_status_icons[status_id] = container
	_icon_container.add_child(container)


func _reorder_icons() -> void:
	# Sort icons by category and priority
	var sorted_statuses: Array = _active_statuses.keys()
	sorted_statuses.sort_custom(_compare_status_priority)
	
	# Reorder children
	for i in range(sorted_statuses.size()):
		var status_id: String = sorted_statuses[i]
		if _status_icons.has(status_id):
			_icon_container.move_child(_status_icons[status_id], i)


func _compare_status_priority(a: String, b: String) -> bool:
	var def_a: Dictionary = STATUS_DEFINITIONS.get(a, {})
	var def_b: Dictionary = STATUS_DEFINITIONS.get(b, {})
	
	# Category sort order (lower = first)
	var category_order := {
		"time": 0,
		"weather": 1,
		"health": 2,
		"fatigue": 3,
		"hunger": 4,
		"thirst": 5,
		"temperature": 6,
		"disease": 7,
		"special": 8,
		"custom": 9
	}
	
	var cat_a: String = def_a.get("category", "custom")
	var cat_b: String = def_b.get("category", "custom")
	
	var order_a: int = category_order.get(cat_a, 99)
	var order_b: int = category_order.get(cat_b, 99)
	
	if order_a != order_b:
		return order_a < order_b
	
	# Within same category, higher priority first
	var pri_a: int = def_a.get("priority", 0)
	var pri_b: int = def_b.get("priority", 0)
	
	return pri_a > pri_b

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_fatigue_changed(_old_level: String, _new_level: String) -> void:
	_update_fatigue_status()


func _on_hunger_changed(_old_stage: String, _new_stage: String) -> void:
	_update_hunger_status()


func _on_thirst_changed(_old_stage: String, _new_stage: String) -> void:
	_update_thirst_status()


func _on_temperature_changed(_temperature: float, _zone: String) -> void:
	_update_temperature_status()


func _on_weather_started(_weather_type: String, _duration: int) -> void:
	_update_weather_status()


func _on_weather_ended(_weather_type: String) -> void:
	_update_weather_status()


func _on_time_period_changed(_old_period: String, _new_period: String) -> void:
	_update_time_status()


func _on_disease_contracted(_disease_id: String, _source: String) -> void:
	_update_disease_statuses()


func _on_disease_cured(_disease_id: String) -> void:
	_update_disease_statuses()


func _on_disease_stage_changed(_disease_id: String, _old_stage: String, _new_stage: String) -> void:
	_update_disease_statuses()


func _on_health_changed(_old_hp: int, _new_hp: int, _max_hp: int) -> void:
	_update_health_status()

# =============================================================================
# PUBLIC API
# =============================================================================

## Force refresh all status displays.
func refresh() -> void:
	_update_all_statuses()


## Add a custom status effect.
func add_custom_status(status_id: String, icon: String, label: String, color: Color, tooltip: String) -> void:
	# Add to definitions if not exists
	if not STATUS_DEFINITIONS.has(status_id):
		STATUS_DEFINITIONS[status_id] = {
			"icon": icon,
			"label": label,
			"color": color,
			"category": "custom",
			"priority": 1
		}
	
	_set_status(status_id, tooltip)


## Remove a custom status effect.
func remove_custom_status(status_id: String) -> void:
	_remove_status(status_id)


## Check if a status is currently displayed.
func has_status(status_id: String) -> bool:
	return _active_statuses.has(status_id)


## Get all active status IDs.
func get_active_statuses() -> Array:
	return _active_statuses.keys()
