# combatant.gd
# Represents a participant in tactical combat (player or enemy).
# Handles stats, HP, AP, weapons, and combat actions.

extends Node2D
class_name Combatant

# =============================================================================
# SIGNALS
# =============================================================================

signal hp_changed(current_hp: int, max_hp: int)
signal ap_changed(current_ap: int, max_ap: int)
signal ammo_changed(current_ammo: int, max_ammo: int)
signal died()
signal moved(from_hex: Vector2i, to_hex: Vector2i)
signal attacked(target: Combatant, hit: bool, damage: int)
signal reloaded()

# =============================================================================
# IDENTITY
# =============================================================================

## Display name of this combatant.
var combatant_name: String = "Unknown"

## Whether this is the player.
var is_player: bool = false

## Enemy type ID (for enemies only).
var enemy_type: String = ""

# =============================================================================
# POSITION
# =============================================================================

## Current hex position on tactical map.
var current_hex: Vector2i = Vector2i.ZERO

# =============================================================================
# STATS
# =============================================================================

## Maximum hit points.
var max_hp: int = 20

## Current hit points.
var current_hp: int = 20

## Aim stat (affects hit chance for ranged weapons).
var aim: int = 3

## Reflex stat (affects initiative and hit chance for thrown weapons).
var reflex: int = 3

## Grit stat (affects hit chance for melee weapons).
var grit: int = 3

# =============================================================================
# COMBAT STATE
# =============================================================================

## Maximum action points per turn.
var max_ap: int = 4

## Current action points this turn.
var current_ap: int = 4

## Whether this combatant is alive.
var is_alive: bool = true

## Initiative roll for turn order.
var initiative: int = 0

# =============================================================================
# EQUIPMENT
# =============================================================================

## Currently equipped weapon data.
var weapon: Dictionary = {}

## Current ammo in weapon.
var current_ammo: int = 6

## Maximum ammo capacity.
var max_ammo: int = 6

# =============================================================================
# AI
# =============================================================================

## AI behavior type (for enemies).
var ai_behavior: String = "aggressive"

## Loot data (for enemies).
var loot_data: Dictionary = {}

# =============================================================================
# VISUALS
# =============================================================================

var _token: Node2D
var _token_body: Polygon2D
var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect
var _hp_label: Label
var _hex_size: float = 64.0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_visuals()


## Initialize as player combatant.
func initialize_as_player(player_data: Dictionary, hex_size: float) -> void:
	is_player = true
	combatant_name = "Player"
	_hex_size = hex_size

	# Load stats from player data
	max_hp = player_data.get("max_hp", 20)
	current_hp = player_data.get("current_hp", 20)
	aim = player_data.get("aim", 3)
	reflex = player_data.get("reflex", 3)
	grit = player_data.get("grit", 3)

	# Default weapon (pistol) - will be overridden by set_weapon() if called
	_load_weapon("pistol")

	# Reset AP
	max_ap = 4
	current_ap = max_ap

	is_alive = current_hp > 0

	_create_visuals()
	_update_hp_bar()


## Initialize as enemy combatant.
func initialize_as_enemy(enemy_data: Dictionary, weapons_data: Dictionary, hex_size: float) -> void:
	is_player = false
	_hex_size = hex_size

	enemy_type = enemy_data.get("id", "bandit")
	combatant_name = enemy_data.get("name", "Enemy")

	max_hp = enemy_data.get("hp", 8)
	current_hp = max_hp
	aim = enemy_data.get("aim", 2)
	reflex = enemy_data.get("reflex", 2)
	grit = enemy_data.get("grit", 2)

	ai_behavior = enemy_data.get("ai_behavior", "aggressive")
	loot_data = enemy_data.get("loot", {})

	# Load weapon
	var weapon_id: String = enemy_data.get("weapon", "pistol")
	if weapons_data.has(weapon_id):
		weapon = weapons_data[weapon_id].duplicate()
		# Handle ammo based on weapon type
		if weapon.get("weapon_type") == "ranged":
			max_ammo = weapon.get("ammo_capacity", 6)
			current_ammo = max_ammo
		else:
			max_ammo = 0
			current_ammo = 0

	# Reset AP
	max_ap = 4
	current_ap = max_ap

	is_alive = true

	# Set visual color
	var visual_data: Dictionary = enemy_data.get("visual", {})
	var color_data: Dictionary = visual_data.get("color", {"r": 0.7, "g": 0.3, "b": 0.3})

	_create_visuals()
	_set_token_color(Color(color_data.get("r", 0.7), color_data.get("g", 0.3), color_data.get("b", 0.3)))
	_update_hp_bar()


func _load_weapon(weapon_id: String) -> void:
	var loader = DataLoader
	if loader:
		var config: Dictionary = loader.load_json("res://data/combat/weapons.json")
		var weapons: Dictionary = config.get("weapons", {})
		if weapons.has(weapon_id):
			weapon = weapons[weapon_id].duplicate()
			max_ammo = weapon.get("ammo_capacity", 6)
			current_ammo = max_ammo


## Set weapon from weapon data dictionary.
func set_weapon(weapon_data: Dictionary) -> void:
	weapon = weapon_data.duplicate()

	# Handle ammo for ranged weapons
	if weapon.get("weapon_type") == "ranged":
		max_ammo = weapon.get("ammo_capacity", 6)
		current_ammo = max_ammo
	else:
		# Melee/thrown weapons don't use ammo
		max_ammo = 0
		current_ammo = 0

	ammo_changed.emit(current_ammo, max_ammo)

# =============================================================================
# VISUALS
# =============================================================================

func _create_visuals() -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()
	
	# Token container
	_token = Node2D.new()
	_token.name = "Token"
	add_child(_token)
	
	# Token body (hexagonal shape)
	_token_body = Polygon2D.new()
	_token_body.name = "Body"
	_token_body.color = Color(0.3, 0.5, 0.8) if is_player else Color(0.7, 0.3, 0.3)
	_token.add_child(_token_body)
	
	_rebuild_token()
	
	# HP bar background
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	_hp_bar_bg.size = Vector2(_hex_size * 0.8, 8)
	_hp_bar_bg.position = Vector2(-_hex_size * 0.4, -_hex_size * 0.6)
	add_child(_hp_bar_bg)
	
	# HP bar fill
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.2, 0.8, 0.2)
	_hp_bar_fill.size = Vector2(_hex_size * 0.8, 8)
	_hp_bar_fill.position = Vector2(-_hex_size * 0.4, -_hex_size * 0.6)
	add_child(_hp_bar_fill)
	
	# HP label
	_hp_label = Label.new()
	_hp_label.text = "%d/%d" % [current_hp, max_hp]
	_hp_label.add_theme_font_size_override("font_size", 16)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.position = Vector2(-_hex_size * 0.3, -_hex_size * 0.85)
	add_child(_hp_label)


func _rebuild_token() -> void:
	var size := _hex_size * 0.35
	var points := PackedVector2Array()
	
	# Hexagonal token
	for i in range(6):
		var angle := float(i) / 6.0 * TAU - PI / 6.0
		points.append(Vector2(cos(angle), sin(angle)) * size)
	
	_token_body.polygon = points


func _set_token_color(color: Color) -> void:
	if _token_body:
		_token_body.color = color


func _update_hp_bar() -> void:
	if _hp_bar_fill == null:
		return
	
	var hp_percent := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar_fill.size.x = _hex_size * 0.8 * hp_percent
	
	# Color based on HP
	if hp_percent > 0.6:
		_hp_bar_fill.color = Color(0.2, 0.8, 0.2)
	elif hp_percent > 0.3:
		_hp_bar_fill.color = Color(0.8, 0.8, 0.2)
	else:
		_hp_bar_fill.color = Color(0.8, 0.2, 0.2)
	
	if _hp_label:
		_hp_label.text = "%d/%d" % [current_hp, max_hp]

# =============================================================================
# ACTIONS
# =============================================================================

## Roll initiative for turn order.
func roll_initiative() -> int:
	initiative = reflex + randi_range(1, 6)
	return initiative


## Reset AP at start of turn.
func reset_ap() -> void:
	current_ap = max_ap
	ap_changed.emit(current_ap, max_ap)


## Spend AP for an action.
## @return bool - True if AP was available and spent.
func spend_ap(amount: int) -> bool:
	if current_ap < amount:
		return false
	
	current_ap -= amount
	ap_changed.emit(current_ap, max_ap)
	return true


## Check if combatant has enough AP.
func has_ap(amount: int) -> bool:
	return current_ap >= amount


## Move to a new hex.
func move_to_hex(target_hex: Vector2i, ap_cost: int) -> bool:
	if not spend_ap(ap_cost):
		return false
	
	var old_hex := current_hex
	current_hex = target_hex
	
	moved.emit(old_hex, target_hex)
	return true


## Attempt to shoot a target.
## @return Dictionary - {hit: bool, damage: int, message: String}
func shoot(target: Combatant, hit_chance_modifier: float = 0.0) -> Dictionary:
	var result := {
		"hit": false,
		"damage": 0,
		"message": "",
		"out_of_ammo": false
	}

	var weapon_type: String = weapon.get("weapon_type", "ranged")

	# Check ammo (only for ranged weapons)
	if weapon_type == "ranged":
		if current_ammo <= 0:
			result["out_of_ammo"] = true
			result["message"] = "%s is out of ammo!" % combatant_name
			return result

	# Check AP
	var ap_cost: int = weapon.get("ap_cost", 1)
	if not spend_ap(ap_cost):
		result["message"] = "Not enough AP to attack"
		return result

	# Consume ammo (ranged only)
	if weapon_type == "ranged":
		current_ammo -= 1
		ammo_changed.emit(current_ammo, max_ammo)

	# Get the stat used for this weapon
	var stat_used: String = weapon.get("stat_used", "aim")
	var stat_value: int = aim  # Default to aim

	# Get appropriate stat value
	match stat_used:
		"aim": stat_value = aim
		"reflex": stat_value = reflex
		"grit": stat_value = grit

	# Calculate hit chance
	var base_chance: float = 0.50
	var stat_bonus: float = stat_value * 0.05
	var total_chance: float = base_chance + stat_bonus + hit_chance_modifier
	total_chance = clampf(total_chance, 0.05, 0.95)  # 5%-95% bounds

	# Roll to hit
	var roll := randf()
	if roll <= total_chance:
		# Hit!
		var damage_min: int = weapon.get("damage_min", 2)
		var damage_max: int = weapon.get("damage_max", 3)
		var damage: int = randi_range(damage_min, damage_max)

		result["hit"] = true
		result["damage"] = damage

		# Generate message based on weapon type
		var action_verb := "hit"
		match weapon_type:
			"melee": action_verb = "struck"
			"thrown": action_verb = "hit"
			"ranged": action_verb = "shot"

		result["message"] = "%s %s %s for %d damage!" % [combatant_name, action_verb, target.combatant_name, damage]

		target.take_damage(damage)
	else:
		result["hit"] = false
		result["message"] = "%s missed %s!" % [combatant_name, target.combatant_name]

	attacked.emit(target, result["hit"], result["damage"])
	return result


## Reload the current weapon.
## For players: consumes ammo from inventory.
## For enemies: infinite ammo (refills to max).
## @return bool - True if reloaded, false if not enough AP or ammo.
func reload_weapon() -> bool:
	if not spend_ap(1):
		return false

	# Enemies get infinite ammo
	if not is_player:
		current_ammo = max_ammo
		ammo_changed.emit(current_ammo, max_ammo)
		reloaded.emit()
		return true

	# Players must consume ammo from inventory
	var ammo_type: String = weapon.get("ammo_type", "")
	if ammo_type.is_empty():
		# No ammo type (melee/thrown weapons) - shouldn't be reloading
		return false

	# Get inventory manager
	var inventory_manager = get_tree().get_first_node_in_group("inventory_manager")
	if not inventory_manager:
		push_error("Combatant: Cannot reload - InventoryManager not found")
		return false

	# Calculate how much ammo we need
	var ammo_needed: int = max_ammo - current_ammo
	if ammo_needed <= 0:
		# Already full
		return false

	# Check if player has ammo
	var available_ammo: int = inventory_manager.get_item_count(ammo_type)
	if available_ammo <= 0:
		# No ammo available
		print("Combatant: No %s available to reload" % ammo_type)
		return false

	# Consume ammo from inventory (use minimum of what we need and what we have)
	var ammo_to_use: int = mini(ammo_needed, available_ammo)
	if not inventory_manager.remove_item(ammo_type, ammo_to_use):
		push_error("Combatant: Failed to remove %s from inventory" % ammo_type)
		return false

	# Reload weapon
	current_ammo += ammo_to_use
	ammo_changed.emit(current_ammo, max_ammo)
	reloaded.emit()

	print("Combatant: Reloaded %d %s (now %d/%d)" % [ammo_to_use, ammo_type, current_ammo, max_ammo])
	return true


## Take damage from an attack.
func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	_update_hp_bar()
	
	if current_hp <= 0:
		is_alive = false
		died.emit()


## Heal HP.
func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)
	_update_hp_bar()

# =============================================================================
# QUERIES
# =============================================================================

## Get weapon range.
func get_weapon_range() -> int:
	return weapon.get("range", 4)


## Get weapon AP cost.
func get_weapon_ap_cost() -> int:
	return weapon.get("ap_cost", 1)


## Check if can shoot (has ammo and AP).
func can_shoot() -> bool:
	var weapon_type: String = weapon.get("weapon_type", "ranged")

	# Ranged weapons need ammo
	if weapon_type == "ranged":
		return current_ammo > 0 and has_ap(get_weapon_ap_cost())

	# Melee and thrown weapons only need AP
	return has_ap(get_weapon_ap_cost())


## Check if needs to reload.
func needs_reload() -> bool:
	var weapon_type: String = weapon.get("weapon_type", "ranged")

	# Only ranged weapons can reload
	if weapon_type != "ranged":
		return false

	return current_ammo <= 0


## Generate loot on death (enemies only).
func generate_loot() -> Dictionary:
	if is_player or loot_data.is_empty():
		return {}
	
	var loot := {
		"money": 0,
		"items": []
	}
	
	# Money 
	var money_min: int = loot_data.get("money_min", 0)
	var money_max: int = loot_data.get("money_max", 0)
	loot["money"] = randi_range(money_min, money_max)
	
	# Items
	var items: Array = loot_data.get("items", [])
	for item_data in items:
		var chance: float = item_data.get("chance", 0.5)
		if randf() <= chance:
			var item_min: int = item_data.get("min", 1)
			var item_max: int = item_data.get("max", 1)
			loot["items"].append({
				"id": item_data.get("id", ""),
				"quantity": randi_range(item_min, item_max)
			})
	
	return loot

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"combatant_name": combatant_name,
		"is_player": is_player,
		"enemy_type": enemy_type,
		"current_hex": {"q": current_hex.x, "r": current_hex.y},
		"max_hp": max_hp,
		"current_hp": current_hp,
		"aim": aim,
		"reflex": reflex,
		"current_ap": current_ap,
		"max_ap": max_ap,
		"current_ammo": current_ammo,
		"max_ammo": max_ammo,
		"is_alive": is_alive
	}
