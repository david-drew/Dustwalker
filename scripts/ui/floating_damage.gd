# floating_damage.gd
# Floating damage number that appears over combatants when they take damage.
# Floats upward and fades out over time.

extends Node2D
class_name FloatingDamage

# =============================================================================
# CONFIGURATION
# =============================================================================

## How long the number displays before fully fading.
const LIFETIME: float = 1.0

## How far the number floats upward.
const FLOAT_DISTANCE: float = 50.0

## Starting scale (pops in).
const START_SCALE: float = 0.5

## Maximum scale (during pop).
const POP_SCALE: float = 1.3

## Final scale.
const END_SCALE: float = 0.8

# =============================================================================
# NODES
# =============================================================================

var _label: Label
var _tween: Tween

# =============================================================================
# STATE
# =============================================================================

var _damage_amount: int = 0
var _is_player_damage: bool = false
var _is_miss: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_label()
	_animate()


func _create_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Set text based on damage or miss
	if _is_miss:
		_label.text = "MISS"
		_label.add_theme_font_size_override("font_size", 18)
		_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		_label.text = str(_damage_amount)
		_label.add_theme_font_size_override("font_size", 24)
		
		if _is_player_damage:
			# Player took damage - red
			_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			# Enemy took damage - yellow/white
			_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	
	# Add shadow for readability
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Center the label
	_label.position = Vector2(-50, -15)
	_label.custom_minimum_size = Vector2(100, 30)
	
	add_child(_label)


func _animate() -> void:
	# Start small
	scale = Vector2(START_SCALE, START_SCALE)
	modulate.a = 1.0
	
	_tween = create_tween()
	_tween.set_parallel(true)
	
	# Pop in effect
	_tween.tween_property(self, "scale", Vector2(POP_SCALE, POP_SCALE), 0.1).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(self, "scale", Vector2(END_SCALE, END_SCALE), 0.15).set_ease(Tween.EASE_IN)
	
	# Float upward
	var end_pos := position + Vector2(0, -FLOAT_DISTANCE)
	_tween.tween_property(self, "position", end_pos, LIFETIME).set_ease(Tween.EASE_OUT)
	
	# Fade out (start fading halfway through)
	_tween.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	
	# Queue free when done
	_tween.chain().tween_callback(queue_free)

# =============================================================================
# FACTORY METHOD
# =============================================================================

## Create and spawn a floating damage number.
## @param parent: Node to add as child of.
## @param world_position: Position in world coordinates.
## @param damage: Damage amount to display.
## @param is_player_damage: True if player took this damage.
static func spawn(parent: Node, world_position: Vector2, damage: int, is_player_damage: bool) -> FloatingDamage:
	var instance := FloatingDamage.new()
	instance._damage_amount = damage
	instance._is_player_damage = is_player_damage
	instance._is_miss = false
	instance.position = world_position
	
	# Add some random horizontal offset so multiple hits don't stack perfectly
	instance.position.x += randf_range(-15, 15)
	
	parent.add_child(instance)
	return instance


## Create and spawn a miss indicator.
## @param parent: Node to add as child of.
## @param world_position: Position in world coordinates.
static func spawn_miss(parent: Node, world_position: Vector2) -> FloatingDamage:
	var instance := FloatingDamage.new()
	instance._damage_amount = 0
	instance._is_player_damage = false
	instance._is_miss = true
	instance.position = world_position
	instance.position.x += randf_range(-10, 10)
	
	parent.add_child(instance)
	return instance
