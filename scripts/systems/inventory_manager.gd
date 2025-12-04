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

# =============================================================================
# STATE
# =============================================================================

## Item counts stored as dictionary.
var items: Dictionary = {}

## Reference to survival manager (for consuming food/water).
var _survival_manager: SurvivalManager = null

## Whether the system has been initialized.
var _initialized: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_starting_inventory()
	_initialized = true


func _load_starting_inventory() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if loader:
		var config: Dictionary = loader.load_json("res://data/survival/survival_config.json")
		var starting: Dictionary = config.get("starting_inventory", {})
		items = starting.duplicate()
	else:
		# Default starting inventory
		items = {
			"rations": 5,
			"water": 5
		}
	
	print("InventoryManager: Starting inventory loaded - %s" % str(items))


## Initialize with reference to survival manager.
func initialize(survival_mgr: SurvivalManager) -> void:
	_survival_manager = survival_mgr
	_load_starting_inventory()
	inventory_changed.emit()
	_emit_to_event_bus("inventory_changed", [])
	print("InventoryManager: Initialized")

# =============================================================================
# ITEM MANAGEMENT
# =============================================================================

## Add items to inventory.
func add_item(item_id: String, quantity: int = 1) -> void:
	if quantity <= 0:
		return
	
	if items.has(item_id):
		items[item_id] += quantity
	else:
		items[item_id] = quantity
	
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
	return items.duplicate()


## Load inventory from dictionary.
func from_dict(data: Dictionary) -> void:
	items = data.duplicate()
	inventory_changed.emit()
	_emit_to_event_bus("inventory_changed", [])
	print("InventoryManager: Loaded inventory - %s" % str(items))

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
