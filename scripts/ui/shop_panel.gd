# shop_panel.gd
# UI panel for shopping - buying and selling items.
# Two-column layout: shop inventory (left) and player inventory (right).
#
# STRUCTURE:
# ShopPanel (this Control)
# └── PanelContainer
#     └── MarginContainer
#         └── MainVBox
#             ├── HeaderRow (shop name + money + close button)
#             ├── ContentHBox
#             │   ├── ShopColumn (items to buy)
#             │   └── PlayerColumn (items to sell)
#             └── TransactionRow (quantity + confirm)

extends Control
class_name ShopPanel

# =============================================================================
# SIGNALS
# =============================================================================

signal closed()
signal transaction_completed(transaction: Dictionary)

# =============================================================================
# CONSTANTS
# =============================================================================

const COLUMN_WIDTH := 320
const ITEM_HEIGHT := 36

# =============================================================================
# STATE
# =============================================================================

var _current_shop_id: String = ""
var _shop_manager: ShopManager = null
var _inventory_manager: Node = null
var _selected_item_id: String = ""
var _selected_mode: String = ""  # "buy" or "sell"
var _quantity: int = 1

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _panel: PanelContainer
var _shop_name_label: Label
var _money_label: Label
var _close_button: Button
var _shop_list: VBoxContainer
var _player_list: VBoxContainer
var _transaction_panel: PanelContainer
var _item_preview_label: Label
var _quantity_label: Label
var _quantity_minus: Button
var _quantity_plus: Button
var _total_label: Label
var _confirm_button: Button

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	add_to_group("shop_panel")
	visible = false
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	# Main panel container
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(720, 550)
	add_child(_panel)

	# Apply panel style
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.11, 0.09, 0.98)
	panel_style.set_corner_radius_all(8)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.55, 0.5, 0.4)
	_panel.add_theme_stylebox_override("panel", panel_style)

	# Center the panel
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# Margin container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	# Main VBox
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# Header row
	_build_header(main_vbox)

	# Content columns
	_build_content(main_vbox)

	# Transaction row
	_build_transaction_row(main_vbox)


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	parent.add_child(header)

	_shop_name_label = Label.new()
	_shop_name_label.add_theme_font_size_override("font_size", 22)
	_shop_name_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	_shop_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_shop_name_label)

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 18)
	_money_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.5))
	header.add_child(_money_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(32, 32)
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)


func _build_content(parent: VBoxContainer) -> void:
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(content)

	# Shop column (buy)
	var shop_column := _build_column("Shop Inventory", true)
	content.add_child(shop_column)

	# Player column (sell)
	var player_column := _build_column("Your Items", false)
	content.add_child(player_column)


func _build_column(title: String, is_shop: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Column header
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
	column.add_child(header)

	# List container
	var list_container := PanelContainer.new()
	list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_container.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_child(list_container)

	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color(0.08, 0.07, 0.06)
	list_style.set_corner_radius_all(4)
	list_container.add_theme_stylebox_override("panel", list_style)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	if is_shop:
		_shop_list = list
	else:
		_player_list = list

	return column


func _build_transaction_row(parent: VBoxContainer) -> void:
	_transaction_panel = PanelContainer.new()
	_transaction_panel.visible = false
	parent.add_child(_transaction_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.14, 0.12)
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.35, 0.3)
	_transaction_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_transaction_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	# Item preview
	_item_preview_label = Label.new()
	_item_preview_label.add_theme_font_size_override("font_size", 14)
	_item_preview_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	row.add_child(_item_preview_label)

	# Quantity controls
	_quantity_minus = Button.new()
	_quantity_minus.text = "-"
	_quantity_minus.custom_minimum_size = Vector2(32, 28)
	_quantity_minus.pressed.connect(_on_quantity_minus)
	row.add_child(_quantity_minus)

	_quantity_label = Label.new()
	_quantity_label.add_theme_font_size_override("font_size", 16)
	_quantity_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantity_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(_quantity_label)

	_quantity_plus = Button.new()
	_quantity_plus.text = "+"
	_quantity_plus.custom_minimum_size = Vector2(32, 28)
	_quantity_plus.pressed.connect(_on_quantity_plus)
	row.add_child(_quantity_plus)

	# Total
	_total_label = Label.new()
	_total_label.add_theme_font_size_override("font_size", 16)
	_total_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.5))
	_total_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(_total_label)

	# Confirm button
	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(80, 32)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	row.add_child(_confirm_button)


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("money_changed"):
			event_bus.money_changed.connect(_on_money_changed)
		if event_bus.has_signal("inventory_changed"):
			event_bus.inventory_changed.connect(_on_inventory_changed)

# =============================================================================
# PUBLIC API
# =============================================================================

## Open the shop panel for a specific shop.
func open(shop_id: String) -> void:
	_shop_manager = get_tree().get_first_node_in_group("shop_manager") as ShopManager
	_inventory_manager = get_tree().get_first_node_in_group("inventory_manager")

	if not _shop_manager:
		push_warning("ShopPanel: ShopManager not found")
		return

	if not _shop_manager.open_shop(shop_id):
		push_warning("ShopPanel: Failed to open shop '%s'" % shop_id)
		return

	_current_shop_id = shop_id
	_selected_item_id = ""
	_selected_mode = ""
	_quantity = 1

	var shop_def: Dictionary = _shop_manager.get_shop_definition(shop_id)
	_shop_name_label.text = shop_def.get("display_name", "Shop")

	_update_money_display()
	_populate_shop_list()
	_populate_player_list()
	_update_transaction_panel()

	visible = true


## Close the panel.
func close() -> void:
	if _shop_manager and not _current_shop_id.is_empty():
		_shop_manager.close_shop()

	visible = false
	_current_shop_id = ""
	_selected_item_id = ""
	_selected_mode = ""
	closed.emit()


## Refresh the panel contents.
func refresh() -> void:
	if not visible or _current_shop_id.is_empty():
		return

	_update_money_display()
	_populate_shop_list()
	_populate_player_list()
	_update_transaction_panel()

# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func _update_money_display() -> void:
	if _inventory_manager:
		var money: int = _inventory_manager.get_money()
		_money_label.text = "$%d" % money
	else:
		_money_label.text = "$0"


func _populate_shop_list() -> void:
	# Clear existing items
	for child in _shop_list.get_children():
		child.queue_free()

	if not _shop_manager:
		return

	var items: Array[Dictionary] = _shop_manager.get_shop_inventory_for_ui(_current_shop_id)

	for item in items:
		var row := _create_item_row(item, "buy")
		_shop_list.add_child(row)


func _populate_player_list() -> void:
	# Clear existing items
	for child in _player_list.get_children():
		child.queue_free()

	if not _shop_manager:
		return

	var items: Array[Dictionary] = _shop_manager.get_sellable_inventory_for_ui(_current_shop_id)

	for item in items:
		var row := _create_item_row(item, "sell")
		_player_list.add_child(row)


func _create_item_row(item: Dictionary, mode: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(COLUMN_WIDTH - 20, ITEM_HEIGHT)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var item_id: String = item["item_id"]
	var name: String = item["display_name"]
	var price: int = item["price"]

	if mode == "buy":
		var stock: int = item["stock"]
		btn.text = "%s  ($%d)  [%d]" % [name, price, stock]

		if not item["can_buy"]:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
			btn.tooltip_text = _get_reason_text(item["reason"])
	else:  # sell
		var quantity: int = item["quantity"]
		if price > 0:
			btn.text = "%s  ($%d)  x%d" % [name, price, quantity]
		else:
			btn.text = "%s  (---)  x%d" % [name, quantity]

		if not item["can_sell"]:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
			if price < 0:
				btn.tooltip_text = "Shop doesn't buy this item"
			else:
				btn.tooltip_text = _get_reason_text(item["reason"])

	btn.pressed.connect(_on_item_selected.bind(item_id, mode, item))
	return btn


func _get_reason_text(reason: String) -> String:
	match reason:
		ShopManager.FAIL_INSUFFICIENT_FUNDS:
			return "Not enough money"
		ShopManager.FAIL_OUT_OF_STOCK:
			return "Out of stock"
		ShopManager.FAIL_ITEM_NOT_BOUGHT_HERE:
			return "Shop doesn't buy this"
		ShopManager.FAIL_INSUFFICIENT_ITEMS:
			return "You don't have any"
		_:
			return reason


func _update_transaction_panel() -> void:
	if _selected_item_id.is_empty() or _selected_mode.is_empty():
		_transaction_panel.visible = false
		return

	_transaction_panel.visible = true

	var item_name: String = _shop_manager.get_item_name(_selected_item_id)
	var unit_price: int

	if _selected_mode == "buy":
		unit_price = _shop_manager.get_buy_price(_current_shop_id, _selected_item_id)
		_confirm_button.text = "Buy"
		_confirm_button.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
	else:
		unit_price = _shop_manager.get_sell_price(_current_shop_id, _selected_item_id)
		_confirm_button.text = "Sell"
		_confirm_button.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))

	_item_preview_label.text = item_name
	_quantity_label.text = str(_quantity)

	var total: int = unit_price * _quantity
	_total_label.text = "$%d" % total

	# Check if transaction is valid
	var valid: bool = false
	if _selected_mode == "buy":
		var can_buy := _shop_manager.can_buy_item(_current_shop_id, _selected_item_id)
		valid = can_buy["can_buy"] and _quantity <= can_buy["max_quantity"]
	else:
		var can_sell := _shop_manager.can_sell_item(_current_shop_id, _selected_item_id)
		valid = can_sell["can_sell"] and _quantity <= can_sell["max_quantity"]

	_confirm_button.disabled = not valid

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_item_selected(item_id: String, mode: String, item: Dictionary) -> void:
	_selected_item_id = item_id
	_selected_mode = mode
	_quantity = 1

	_update_transaction_panel()


func _on_quantity_minus() -> void:
	if _quantity > 1:
		_quantity -= 1
		_update_transaction_panel()


func _on_quantity_plus() -> void:
	var max_qty: int = 1

	if _selected_mode == "buy":
		var can_buy := _shop_manager.can_buy_item(_current_shop_id, _selected_item_id)
		max_qty = can_buy["max_quantity"]
	else:
		var can_sell := _shop_manager.can_sell_item(_current_shop_id, _selected_item_id)
		max_qty = can_sell["max_quantity"]

	if _quantity < max_qty:
		_quantity += 1
		_update_transaction_panel()


func _on_confirm_pressed() -> void:
	if _selected_item_id.is_empty() or _selected_mode.is_empty():
		return

	var result: Dictionary

	if _selected_mode == "buy":
		result = _shop_manager.buy_item(_current_shop_id, _selected_item_id, _quantity)
	else:
		result = _shop_manager.sell_item(_current_shop_id, _selected_item_id, _quantity)

	if result["success"]:
		transaction_completed.emit({
			"type": _selected_mode,
			"item_id": _selected_item_id,
			"quantity": _quantity,
			"total": result["total"]
		})

		# Reset selection
		_selected_item_id = ""
		_selected_mode = ""
		_quantity = 1

		# Refresh displays
		refresh()
	else:
		push_warning("ShopPanel: Transaction failed - %s" % result["reason"])


func _on_close_pressed() -> void:
	close()


func _on_money_changed(_new_amount: int, _old_amount: int) -> void:
	if visible:
		_update_money_display()
		_update_transaction_panel()


func _on_inventory_changed() -> void:
	if visible:
		_populate_player_list()
		_update_transaction_panel()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
