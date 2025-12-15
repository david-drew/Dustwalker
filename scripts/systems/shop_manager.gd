# shop_manager.gd
# Manages the shop/economy system for buying and selling items.
# Loads shop and item definitions from JSON, handles transactions,
# tracks inventory state, and performs weekly restocking.
#
# Implements to_dict()/from_dict() for SaveManager integration.

extends Node
class_name ShopManager

# =============================================================================
# SIGNALS
# =============================================================================

signal shop_opened(shop_id: String)
signal shop_closed(shop_id: String)
signal item_purchased(item_id: String, quantity: int, total_cost: int)
signal item_sold(item_id: String, quantity: int, total_value: int)
signal shop_restocked(shop_id: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const ITEMS_PATH := "res://data/economy/items.json"
const SHOPS_PATH := "res://data/economy/shops.json"

## Standard failure reasons
const FAIL_SHOP_NOT_FOUND := "shop_not_found"
const FAIL_ITEM_NOT_SOLD_HERE := "item_not_sold_here"
const FAIL_OUT_OF_STOCK := "out_of_stock"
const FAIL_INSUFFICIENT_FUNDS := "insufficient_funds"
const FAIL_INSUFFICIENT_ITEMS := "insufficient_items"
const FAIL_INVALID_QUANTITY := "invalid_quantity"
const FAIL_ITEM_NOT_BOUGHT_HERE := "item_not_bought_here"

# =============================================================================
# STATE
# =============================================================================

## Canonical item definitions (immutable).
var _items: Dictionary = {}

## Shop definitions (immutable base data).
var _shop_definitions: Dictionary = {}

## Current shop inventory state (mutable, persisted).
## Structure: { shop_id: { "inventory": { item_id: { "stock": int } }, "last_restock_day": int } }
var _shop_state: Dictionary = {}

## Currently open shop ID.
var _current_shop_id: String = ""

## Reference to InventoryManager.
var _inventory_manager: Node = null

## Whether system is initialized.
var _initialized: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("shop_manager")
	_load_data()
	_connect_signals()


func _load_data() -> void:
	var loader = get_node_or_null("/root/DataLoader")
	if not loader:
		push_error("ShopManager: DataLoader not found")
		return

	# Load item definitions
	var items_data: Dictionary = loader.load_json(ITEMS_PATH)
	_items = items_data.get("items", {})
	print("ShopManager: Loaded %d item definitions" % _items.size())

	# Load shop definitions
	var shops_data: Dictionary = loader.load_json(SHOPS_PATH)
	_shop_definitions = shops_data.get("shops", {})
	print("ShopManager: Loaded %d shop definitions" % _shop_definitions.size())

	# Initialize shop state from definitions
	_initialize_shop_state()
	_initialized = true


func _initialize_shop_state() -> void:
	for shop_id in _shop_definitions:
		if not _shop_state.has(shop_id):
			var shop_def: Dictionary = _shop_definitions[shop_id]
			var inventory_state: Dictionary = {}

			for item_id in shop_def.get("inventory", {}):
				var item_def: Dictionary = shop_def["inventory"][item_id]
				inventory_state[item_id] = {
					"stock": item_def.get("stock", 0)
				}

			_shop_state[shop_id] = {
				"inventory": inventory_state,
				"last_restock_day": 0
			}


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("day_started"):
			event_bus.day_started.connect(_on_day_started)


func initialize() -> void:
	_inventory_manager = get_tree().get_first_node_in_group("inventory_manager")
	if not _inventory_manager:
		push_warning("ShopManager: InventoryManager not found")
	print("ShopManager: Initialized")

# =============================================================================
# SHOP ACCESS
# =============================================================================

## Open a shop by ID.
## @return bool - True if shop was successfully opened.
func open_shop(shop_id: String) -> bool:
	if not _shop_definitions.has(shop_id):
		push_warning("ShopManager: Shop '%s' not found" % shop_id)
		return false

	_current_shop_id = shop_id
	shop_opened.emit(shop_id)
	_emit_to_event_bus("shop_opened", [shop_id])
	print("ShopManager: Opened shop '%s'" % shop_id)
	return true


## Close the current shop.
func close_shop() -> void:
	if _current_shop_id.is_empty():
		return

	var shop_id := _current_shop_id
	_current_shop_id = ""
	shop_closed.emit(shop_id)
	_emit_to_event_bus("shop_closed", [shop_id])
	print("ShopManager: Closed shop '%s'" % shop_id)


## Get the currently open shop ID.
func get_current_shop_id() -> String:
	return _current_shop_id


## Check if a shop is currently open.
func is_shop_open() -> bool:
	return not _current_shop_id.is_empty()


## Get shop definition by ID.
func get_shop_definition(shop_id: String) -> Dictionary:
	return _shop_definitions.get(shop_id, {})


## Get shop display name.
func get_shop_name(shop_id: String) -> String:
	return _shop_definitions.get(shop_id, {}).get("display_name", "Unknown Shop")

# =============================================================================
# ITEM DEFINITIONS
# =============================================================================

## Get item definition by ID.
func get_item_definition(item_id: String) -> Dictionary:
	return _items.get(item_id, {})


## Get item display name.
func get_item_name(item_id: String) -> String:
	return _items.get(item_id, {}).get("display_name", item_id.capitalize())


## Get item base price.
func get_item_base_price(item_id: String) -> int:
	return _items.get(item_id, {}).get("base_price", 1)

# =============================================================================
# PRICING
# =============================================================================

## Calculate buy price (player buys from shop).
## @param shop_id: Shop to check.
## @param item_id: Item to price.
## @return int - The buy price, or -1 if item not sold.
func get_buy_price(shop_id: String, item_id: String) -> int:
	if not _shop_definitions.has(shop_id):
		return -1

	var shop_def: Dictionary = _shop_definitions[shop_id]
	if not shop_def.get("inventory", {}).has(item_id):
		return -1

	var base_price: int = get_item_base_price(item_id)
	var buy_modifier: float = shop_def.get("buy_modifier", 1.0)
	var buy_price: int = ceili(base_price * buy_modifier)
	return maxi(buy_price, 1)


## Calculate sell price (player sells to shop).
## @param shop_id: Shop to check.
## @param item_id: Item to price.
## @return int - The sell price, or -1 if item not bought.
func get_sell_price(shop_id: String, item_id: String) -> int:
	if not _shop_definitions.has(shop_id):
		return -1

	var shop_def: Dictionary = _shop_definitions[shop_id]
	var buys_list: Array = shop_def.get("buys", [])
	if not buys_list.has(item_id):
		return -1

	var base_price: int = get_item_base_price(item_id)
	var sell_modifier: float = shop_def.get("sell_modifier", 0.5)
	var sell_price: int = floori(base_price * sell_modifier)
	return maxi(sell_price, 1)

# =============================================================================
# STOCK
# =============================================================================

## Get current stock of an item at a shop.
func get_stock(shop_id: String, item_id: String) -> int:
	if not _shop_state.has(shop_id):
		return 0
	return _shop_state[shop_id].get("inventory", {}).get(item_id, {}).get("stock", 0)


## Get max stock of an item at a shop.
func get_max_stock(shop_id: String, item_id: String) -> int:
	if not _shop_definitions.has(shop_id):
		return 0
	return _shop_definitions[shop_id].get("inventory", {}).get(item_id, {}).get("max_stock", 0)


## Check if shop has item in stock.
func has_stock(shop_id: String, item_id: String, quantity: int = 1) -> bool:
	return get_stock(shop_id, item_id) >= quantity

# =============================================================================
# TRANSACTIONS
# =============================================================================

## Buy items from a shop.
## @return Dictionary - { "success": bool, "reason": String, "total": int }
func buy_item(shop_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	var result := { "success": false, "reason": "", "total": 0 }

	# Validate quantity
	if quantity <= 0:
		result["reason"] = FAIL_INVALID_QUANTITY
		return result

	# Validate shop exists
	if not _shop_definitions.has(shop_id):
		result["reason"] = FAIL_SHOP_NOT_FOUND
		return result

	# Validate item is sold here
	var shop_def: Dictionary = _shop_definitions[shop_id]
	if not shop_def.get("inventory", {}).has(item_id):
		result["reason"] = FAIL_ITEM_NOT_SOLD_HERE
		return result

	# Validate sufficient stock
	var current_stock := get_stock(shop_id, item_id)
	if current_stock < quantity:
		result["reason"] = FAIL_OUT_OF_STOCK
		return result

	# Calculate total cost
	var unit_price := get_buy_price(shop_id, item_id)
	var total_cost: int = unit_price * quantity
	result["total"] = total_cost

	# Validate player has money
	if not _inventory_manager:
		_inventory_manager = get_tree().get_first_node_in_group("inventory_manager")

	if not _inventory_manager or not _inventory_manager.has_money(total_cost):
		result["reason"] = FAIL_INSUFFICIENT_FUNDS
		return result

	# Execute transaction
	_inventory_manager.spend_money(total_cost)
	_inventory_manager.add_item(item_id, quantity)
	_shop_state[shop_id]["inventory"][item_id]["stock"] -= quantity

	result["success"] = true
	item_purchased.emit(item_id, quantity, total_cost)

	var transaction := {
		"type": "buy",
		"item_id": item_id,
		"quantity": quantity,
		"total": total_cost,
		"success": true
	}
	_emit_to_event_bus("shop_transaction_completed", [shop_id, transaction])

	print("ShopManager: Player bought %dx %s for $%d" % [quantity, item_id, total_cost])
	return result


## Sell items to a shop.
## @return Dictionary - { "success": bool, "reason": String, "total": int }
func sell_item(shop_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	var result := { "success": false, "reason": "", "total": 0 }

	# Validate quantity
	if quantity <= 0:
		result["reason"] = FAIL_INVALID_QUANTITY
		return result

	# Validate shop exists
	if not _shop_definitions.has(shop_id):
		result["reason"] = FAIL_SHOP_NOT_FOUND
		return result

	# Validate item is bought here
	var shop_def: Dictionary = _shop_definitions[shop_id]
	var buys_list: Array = shop_def.get("buys", [])
	if not buys_list.has(item_id):
		result["reason"] = FAIL_ITEM_NOT_BOUGHT_HERE
		return result

	# Validate player has items
	if not _inventory_manager:
		_inventory_manager = get_tree().get_first_node_in_group("inventory_manager")

	if not _inventory_manager or _inventory_manager.get_item_count(item_id) < quantity:
		result["reason"] = FAIL_INSUFFICIENT_ITEMS
		return result

	# Calculate total value
	var unit_price := get_sell_price(shop_id, item_id)
	var total_value: int = unit_price * quantity
	result["total"] = total_value

	# Execute transaction
	_inventory_manager.remove_item(item_id, quantity)
	_inventory_manager.add_money(total_value)

	# Optionally increase shop stock if shop sells this item
	if _shop_state.has(shop_id) and _shop_state[shop_id].get("inventory", {}).has(item_id):
		var max_stock := get_max_stock(shop_id, item_id)
		var new_stock: int = mini(_shop_state[shop_id]["inventory"][item_id]["stock"] + quantity, max_stock)
		_shop_state[shop_id]["inventory"][item_id]["stock"] = new_stock

	result["success"] = true
	item_sold.emit(item_id, quantity, total_value)

	var transaction := {
		"type": "sell",
		"item_id": item_id,
		"quantity": quantity,
		"total": total_value,
		"success": true
	}
	_emit_to_event_bus("shop_transaction_completed", [shop_id, transaction])

	print("ShopManager: Player sold %dx %s for $%d" % [quantity, item_id, total_value])
	return result


## Check if player can buy an item.
## @return Dictionary - { "can_buy": bool, "reason": String, "unit_price": int, "max_quantity": int }
func can_buy_item(shop_id: String, item_id: String) -> Dictionary:
	var result := { "can_buy": false, "reason": "", "unit_price": 0, "max_quantity": 0 }

	if not _shop_definitions.has(shop_id):
		result["reason"] = FAIL_SHOP_NOT_FOUND
		return result

	var shop_def: Dictionary = _shop_definitions[shop_id]
	if not shop_def.get("inventory", {}).has(item_id):
		result["reason"] = FAIL_ITEM_NOT_SOLD_HERE
		return result

	var stock := get_stock(shop_id, item_id)
	if stock <= 0:
		result["reason"] = FAIL_OUT_OF_STOCK
		return result

	var unit_price := get_buy_price(shop_id, item_id)
	result["unit_price"] = unit_price

	if not _inventory_manager:
		_inventory_manager = get_tree().get_first_node_in_group("inventory_manager")

	if not _inventory_manager:
		result["reason"] = FAIL_INSUFFICIENT_FUNDS
		return result

	var player_money: int = _inventory_manager.get_money()
	if player_money < unit_price:
		result["reason"] = FAIL_INSUFFICIENT_FUNDS
		return result

	result["can_buy"] = true
	result["max_quantity"] = mini(stock, player_money / unit_price)
	return result


## Check if player can sell an item.
## @return Dictionary - { "can_sell": bool, "reason": String, "unit_price": int, "max_quantity": int }
func can_sell_item(shop_id: String, item_id: String) -> Dictionary:
	var result := { "can_sell": false, "reason": "", "unit_price": 0, "max_quantity": 0 }

	if not _shop_definitions.has(shop_id):
		result["reason"] = FAIL_SHOP_NOT_FOUND
		return result

	var shop_def: Dictionary = _shop_definitions[shop_id]
	var buys_list: Array = shop_def.get("buys", [])
	if not buys_list.has(item_id):
		result["reason"] = FAIL_ITEM_NOT_BOUGHT_HERE
		return result

	var unit_price := get_sell_price(shop_id, item_id)
	result["unit_price"] = unit_price

	if not _inventory_manager:
		_inventory_manager = get_tree().get_first_node_in_group("inventory_manager")

	if not _inventory_manager:
		result["reason"] = FAIL_INSUFFICIENT_ITEMS
		return result

	var player_count: int = _inventory_manager.get_item_count(item_id)
	if player_count <= 0:
		result["reason"] = FAIL_INSUFFICIENT_ITEMS
		return result

	result["can_sell"] = true
	result["max_quantity"] = player_count
	return result

# =============================================================================
# UI DATA
# =============================================================================

## Get UI-ready shop inventory data.
## @return Array of item dictionaries with prices and stock.
func get_shop_inventory_for_ui(shop_id: String) -> Array[Dictionary]:
	var items_list: Array[Dictionary] = []

	if not _shop_definitions.has(shop_id):
		return items_list

	var shop_def: Dictionary = _shop_definitions[shop_id]

	for item_id in shop_def.get("inventory", {}):
		var item_def: Dictionary = _items.get(item_id, {})
		var stock := get_stock(shop_id, item_id)
		var buy_price := get_buy_price(shop_id, item_id)
		var can_buy := can_buy_item(shop_id, item_id)

		items_list.append({
			"item_id": item_id,
			"display_name": item_def.get("display_name", item_id.capitalize()),
			"stock": stock,
			"price": buy_price,
			"can_buy": can_buy["can_buy"],
			"reason": can_buy["reason"],
			"max_quantity": can_buy["max_quantity"],
			"tags": item_def.get("tags", [])
		})

	return items_list


## Get UI-ready player inventory data for selling.
## @return Array of item dictionaries with sell prices.
func get_sellable_inventory_for_ui(shop_id: String) -> Array[Dictionary]:
	var items_list: Array[Dictionary] = []

	if not _shop_definitions.has(shop_id):
		return items_list

	if not _inventory_manager:
		_inventory_manager = get_tree().get_first_node_in_group("inventory_manager")

	if not _inventory_manager:
		return items_list

	var player_items: Dictionary = _inventory_manager.get_all_items()
	var shop_def: Dictionary = _shop_definitions[shop_id]
	var buys_list: Array = shop_def.get("buys", [])

	for item_id in player_items:
		var item_def: Dictionary = _items.get(item_id, {})
		var quantity: int = player_items[item_id]
		var can_sell := can_sell_item(shop_id, item_id)
		var sell_price := get_sell_price(shop_id, item_id) if buys_list.has(item_id) else -1

		items_list.append({
			"item_id": item_id,
			"display_name": item_def.get("display_name", item_id.capitalize()),
			"quantity": quantity,
			"price": sell_price,
			"can_sell": can_sell["can_sell"],
			"reason": can_sell["reason"] if not can_sell["can_sell"] else "",
			"tags": item_def.get("tags", [])
		})

	return items_list

# =============================================================================
# WEEKLY RESTOCKING
# =============================================================================

func _on_day_started(day: int) -> void:
	# Check if it's a restock day (days 1, 8, 15, 22, ...)
	if (day - 1) % 7 == 0:
		_perform_weekly_restock(day)


func _perform_weekly_restock(day: int) -> void:
	print("ShopManager: Performing weekly restock on day %d" % day)

	for shop_id in _shop_definitions:
		var shop_def: Dictionary = _shop_definitions[shop_id]

		# Check if already restocked
		if _shop_state.has(shop_id):
			var last_restock: int = _shop_state[shop_id].get("last_restock_day", 0)
			if last_restock >= day:
				continue

		# Restock each item
		for item_id in shop_def.get("inventory", {}):
			var item_def: Dictionary = shop_def["inventory"][item_id]
			var restock_amount: int = item_def.get("restock_per_week", 0)
			var max_stock: int = item_def.get("max_stock", 0)

			if _shop_state.has(shop_id) and _shop_state[shop_id].get("inventory", {}).has(item_id):
				var current_stock: int = _shop_state[shop_id]["inventory"][item_id]["stock"]
				var new_stock: int = mini(max_stock, current_stock + restock_amount)
				_shop_state[shop_id]["inventory"][item_id]["stock"] = new_stock

		# Update last restock day
		if _shop_state.has(shop_id):
			_shop_state[shop_id]["last_restock_day"] = day

		shop_restocked.emit(shop_id)

	print("ShopManager: Weekly restock complete")

# =============================================================================
# SERIALIZATION
# =============================================================================

## Convert shop state to dictionary for saving.
func to_dict() -> Dictionary:
	var save_data: Dictionary = {}

	for shop_id in _shop_state:
		var shop_data: Dictionary = _shop_state[shop_id]
		var inventory_save: Dictionary = {}

		for item_id in shop_data.get("inventory", {}):
			inventory_save[item_id] = {
				"stock": shop_data["inventory"][item_id].get("stock", 0)
			}

		save_data[shop_id] = {
			"inventory": inventory_save,
			"last_restock_day": shop_data.get("last_restock_day", 0)
		}

	return { "shops": save_data }


## Load shop state from dictionary.
func from_dict(data: Dictionary) -> void:
	var shops_data: Dictionary = data.get("shops", {})

	# Reinitialize state from definitions first
	_initialize_shop_state()

	# Apply saved state
	for shop_id in shops_data:
		if _shop_state.has(shop_id):
			var saved_shop: Dictionary = shops_data[shop_id]

			# Apply saved inventory
			for item_id in saved_shop.get("inventory", {}):
				if _shop_state[shop_id]["inventory"].has(item_id):
					_shop_state[shop_id]["inventory"][item_id]["stock"] = saved_shop["inventory"][item_id].get("stock", 0)

			# Apply last restock day
			_shop_state[shop_id]["last_restock_day"] = saved_shop.get("last_restock_day", 0)

	print("ShopManager: Loaded shop state from save")

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
