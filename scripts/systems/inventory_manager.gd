# inventory_manager.gd
# Manages player inventory for consumable items.
# Simple dictionary-based storage for Stage 5 (rations and water).
#
# FUTURE EXPANSION:
# - Item definitions with properties
# - Equipment slots
# - Weight/capacity limits
# - Quest items

extends Node
class_name InventoryManager

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when inventory contents change.
signal inventory_changed()

## Emitted when an item is added.
signal item_added(item_id: String, quantity: int, new_total: int)

## Emitted when an item is removed.
signal item_removed(item_id: String, quantity: int, new_total: int)

## Emitted when an item is consumed (used).
signal item_consumed(item_id: String, effect: String)

## Emitted when item use fails.
signal cannot_consume_item(item_id: String, reason: String)

## Emitted when money changes.
signal money_changed(new_amount: int, old_amount: int)

# =============================================================================
# STATE
# =============================================================================

## Item counts stored as dictionary.
var items: Dictionary = {}

## Money (currency in dollars).
var money: int = 20

## Reference to survival manager (for consuming food/water).
var _survival_manager: SurvivalManager = null

## Whether the system has been initialized.
var _initialized: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("inventory_manager")
	# Don't load starting inventory here - wait for initialize() or apply_starting_equipment()
	# _load_starting_inventory()
	# _initialized = true


func _load_starting_inventory() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_json("res://data/survival/survival_config.json")
		var starting: Dictionary = config.get("starting_inventory", {})
		items = starting.duplicate()
		money = config.get("starting_money", 20)
	else:
		# Default starting inventory
		items = {
			"rations": 5,
			"water": 5
		}
		money = 20

	print("InventoryManager: Starting inventory loaded - %s, money: %d" % [str(items), money])


## Initialize with reference to survival manager.
func initialize(survival_mgr: SurvivalManager) -> void:
	_survival_manager = survival_mgr
	# Only load starting inventory if equipment hasn't been applied yet
	if not _initialized:
		_load_starting_inventory()
		_initialized = true
	inventory_changed.emit()
	_emit_to_event_bus("inventory_changed", [])
	print("InventoryManager: Initialized (has %d items)" % items.size())


## Apply starting equipment from character creation.
## @param equipment: Dictionary - Equipment data from character background.
func apply_starting_equipment(equipment: Dictionary) -> void:
	if equipment.is_empty():
		push_warning("InventoryManager: No equipment data provided")
		return

	print("InventoryManager: ========================================")
	print("InventoryManager: apply_starting_equipment() called")
	print("InventoryManager: Equipment data: %s" % str(equipment))
	print("InventoryManager: Current items BEFORE clear: %s" % str(items))

	# Clear current inventory to start fresh
	items.clear()
	money = 0

	print("InventoryManager: Items after clear: %s" % str(items))

	# Apply money
	if equipment.has("money"):
		money = equipment.get("money", 0)
		print("  Money: $%d" % money)

	# Apply weapons and equip the first one
	if equipment.has("weapons"):
		var weapons: Array = equipment.get("weapons", [])
		print("  Applying %d weapons..." % weapons.size())
		for i in range(weapons.size()):
			var weapon_id: String = weapons[i]
			add_item(weapon_id, 1)
			print("  Weapon: %s" % weapon_id)

			# Auto-equip first weapon to slot 1
			if i == 0:
				var player = get_tree().get_first_node_in_group("player")
				if player:
					if player.has_method("equip_weapon"):
						var success: bool = player.equip_weapon(weapon_id, 0)
						if success:
							print("  ✓ Auto-equipped %s to slot 1" % weapon_id)
						else:
							push_error("  ✗ Failed to equip %s - weapon not found in weapons.json?" % weapon_id)
					else:
						push_error("  ✗ Player doesn't have equip_weapon method")
				else:
					push_error("  ✗ Player not found in 'player' group")

	# Apply items
	if equipment.has("items"):
		var item_list: Array = equipment.get("items", [])
		for item_id in item_list:
			add_item(item_id, 1)
			print("  Item: %s" % item_id)

	# Apply clothing (stored as items for now)
	if equipment.has("clothing"):
		var clothing: Array = equipment.get("clothing", [])
		for clothing_id in clothing:
			add_item(clothing_id, 1)
			print("  Clothing: %s" % clothing_id)

	# Apply ammo (format: "ammo_type:quantity")
	if equipment.has("ammo"):
		var ammo_list: Array = equipment.get("ammo", [])
		for ammo_entry in ammo_list:
			var parts: PackedStringArray = ammo_entry.split(":")
			if parts.size() == 2:
				var ammo_type: String = parts[0]
				var quantity: int = parts[1].to_int()
				add_item(ammo_type, quantity)
				print("  Ammo: %s x%d" % [ammo_type, quantity])

	# Mount is stored but not yet implemented
	if equipment.has("mount"):
		var mount_id: String = equipment.get("mount", "")
		if not mount_id.is_empty():
			# Store as metadata for future mount system
			print("  Mount: %s (not yet implemented)" % mount_id)

	# Always ensure we have at least some rations and water
	if not items.has("rations") or items.get("rations", 0) == 0:
		items["rations"] = 5
		print("  Default rations: 5")

	if not items.has("water") or items.get("water", 0) == 0:
		items["water"] = 5
		print("  Default water: 5")

	# Mark as initialized so initialize() won't overwrite
	_initialized = true

	print("InventoryManager: FINAL items after apply_starting_equipment: %s" % str(items))
	print("InventoryManager: FINAL money: %d" % money)
	print("InventoryManager: ========================================")

	# Emit changes
	inventory_changed.emit()
	money_changed.emit(money, 0)
	_emit_to_event_bus("inventory_changed", [])
	_emit_to_event_bus("money_changed", [money, 0])

	print("InventoryManager: Starting equipment applied")

# =============================================================================
# ITEM MANAGEMENT
# =============================================================================

## Add items to inventory.
func add_item(item_id: String, quantity: int = 1) -> void:
	print("InventoryManager.add_item() called: item_id='%s', quantity=%d" % [item_id, quantity])
	print("  Items BEFORE add: %s" % str(items))

	if quantity <= 0:
		print("  Quantity <= 0, returning without adding")
		return

	if items.has(item_id):
		items[item_id] += quantity
	else:
		items[item_id] = quantity

	print("  Items AFTER add: %s" % str(items))

	item_added.emit(item_id, quantity, items[item_id])
	inventory_changed.emit()
	_emit_to_event_bus("item_added", [item_id, quantity, items[item_id]])
	_emit_to_event_bus("inventory_changed", [])


## Remove items from inventory.
## @return bool - True if removed, false if insufficient quantity.
func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return true
	
	if not has_item(item_id, quantity):
		return false
	
	items[item_id] -= quantity
	var new_total: int = items[item_id]
	
	# Clean up if quantity reaches 0
	if items[item_id] <= 0:
		items.erase(item_id)
		new_total = 0
	
	item_removed.emit(item_id, quantity, new_total)
	inventory_changed.emit()
	_emit_to_event_bus("item_removed", [item_id, quantity, new_total])
	_emit_to_event_bus("inventory_changed", [])
	
	return true


## Check if inventory has at least the specified quantity of an item.
func has_item(item_id: String, quantity: int = 1) -> bool:
	return items.get(item_id, 0) >= quantity


## Get the count of a specific item.
func get_item_count(item_id: String) -> int:
	return items.get(item_id, 0)


## Get all items as a dictionary.
func get_all_items() -> Dictionary:
	return items.duplicate()

# =============================================================================
# MONEY MANAGEMENT
# =============================================================================

## Add money to inventory.
func add_money(amount: int) -> void:
	if amount <= 0:
		return

	var old_amount := money
	money += amount

	money_changed.emit(money, old_amount)
	_emit_to_event_bus("money_changed", [money, old_amount])
	print("InventoryManager: Added $%d (total: $%d)" % [amount, money])


## Remove money from inventory.
## @return bool - True if removed, false if insufficient funds.
func remove_money(amount: int) -> bool:
	if amount <= 0:
		return true

	if money < amount:
		return false

	var old_amount := money
	money -= amount

	money_changed.emit(money, old_amount)
	_emit_to_event_bus("money_changed", [money, old_amount])
	print("InventoryManager: Removed $%d (total: $%d)" % [amount, money])

	return true


## Get current money amount.
func get_money() -> int:
	return money


## Check if player has at least the specified amount of money.
func has_money(amount: int) -> bool:
	return money >= amount

# =============================================================================
# CONSUMABLES
# =============================================================================

## Use a ration to restore hunger.
## @return bool - True if successfully consumed.
func use_ration() -> bool:
	if not has_item("rations"):
		cannot_consume_item.emit("rations", "none_available")
		_emit_to_event_bus("cannot_consume_item", ["rations", "none_available"])
		return false
	
	if _survival_manager == null:
		push_error("InventoryManager: SurvivalManager not set")
		return false
	
	if not _survival_manager.can_eat():
		cannot_consume_item.emit("rations", "already_full")
		_emit_to_event_bus("cannot_consume_item", ["rations", "already_full"])
		return false
	
	# Consume the ration
	remove_item("rations")
	_survival_manager.eat_ration()
	
	item_consumed.emit("rations", "hunger_restored")
	_emit_to_event_bus("item_consumed", ["rations", "hunger_restored"])
	
	return true


## Use water to restore thirst.
## @return bool - True if successfully consumed.
func use_water() -> bool:
	if not has_item("water"):
		cannot_consume_item.emit("water", "none_available")
		_emit_to_event_bus("cannot_consume_item", ["water", "none_available"])
		return false
	
	if _survival_manager == null:
		push_error("InventoryManager: SurvivalManager not set")
		return false
	
	if not _survival_manager.can_drink():
		cannot_consume_item.emit("water", "already_full")
		_emit_to_event_bus("cannot_consume_item", ["water", "already_full"])
		return false
	
	# Consume the water
	remove_item("water")
	_survival_manager.drink_water()
	
	item_consumed.emit("water", "thirst_restored")
	_emit_to_event_bus("item_consumed", ["water", "thirst_restored"])
	
	return true


## Check if rations can be consumed.
func can_use_ration() -> bool:
	if not has_item("rations"):
		return false
	if _survival_manager and not _survival_manager.can_eat():
		return false
	return true


## Check if water can be consumed.
func can_use_water() -> bool:
	if not has_item("water"):
		return false
	if _survival_manager and not _survival_manager.can_drink():
		return false
	return true

# =============================================================================
# ENCOUNTER EFFECTS
# =============================================================================

## Apply item effects from an encounter.
## @param effects: Dictionary - Effect dictionary from encounter choice.
## @return Dictionary - Applied effects summary.
func apply_encounter_effects(effects: Dictionary) -> Dictionary:
	var applied := {}
	
	# Rations
	if effects.has("rations"):
		var amount: int = effects["rations"]
		if amount > 0:
			add_item("rations", amount)
			applied["rations"] = amount
		elif amount < 0:
			var removed := mini(-amount, get_item_count("rations"))
			remove_item("rations", removed)
			applied["rations"] = -removed
	
	# Water
	if effects.has("water"):
		var amount: int = effects["water"]
		if amount > 0:
			add_item("water", amount)
			applied["water"] = amount
		elif amount < 0:
			var removed := mini(-amount, get_item_count("water"))
			remove_item("water", removed)
			applied["water"] = -removed
	
	return applied


## Check if player can afford the requirements for a choice.
func can_afford_requirements(requirements: Dictionary) -> bool:
	for item_id in requirements:
		var required: int = requirements[item_id]
		if get_item_count(item_id) < required:
			return false
	return true

# =============================================================================
# SERIALIZATION
# =============================================================================

## Convert inventory to dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"items": items.duplicate(),
		"money": money
	}


## Load inventory from dictionary.
func from_dict(data: Dictionary) -> void:
	items = data.get("items", {}).duplicate()
	money = data.get("money", 20)
	inventory_changed.emit()
	_emit_to_event_bus("inventory_changed", [])
	print("InventoryManager: Loaded inventory - %s, money: %d" % [str(items), money])

# =============================================================================
# DEBUG
# =============================================================================

## Add items for testing (debug).
func debug_add_items(item_id: String, quantity: int) -> void:
	add_item(item_id, quantity)
	print("InventoryManager: Debug added %d %s" % [quantity, item_id])


## Clear all items (debug).
func debug_clear_inventory() -> void:
	items.clear()
	inventory_changed.emit()
	_emit_to_event_bus("inventory_changed", [])
	print("InventoryManager: Debug cleared inventory")

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
