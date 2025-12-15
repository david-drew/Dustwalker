# npc_panel.gd
# UI panel for displaying NPCs at a location.
# Shows NPC list, details, and service buttons.
#
# STRUCTURE:
# NPCPanel (this Control)
# └── PanelContainer
#     └── MarginContainer
#         └── MainVBox
#             ├── HeaderRow (location name + close button)
#             ├── ContentHBox
#             │   ├── NPCList (VBoxContainer with NPC buttons)
#             │   └── DetailsPanel (selected NPC info)
#             └── ServiceButtonsRow

extends Control
class_name NPCPanel

# =============================================================================
# SIGNALS
# =============================================================================

signal closed()
signal npc_selected(npc_id: String)
signal service_selected(npc_id: String, service: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const SERVICE_LABELS: Dictionary = {
	"dialogue": "Talk",
	"trade": "Trade",
	"trainer": "Train",
	"rumor": "Rumors",
	"quest": "Quests"
}

const SERVICE_COLORS: Dictionary = {
	"dialogue": Color(0.7, 0.7, 0.6),
	"trade": Color(0.6, 0.7, 0.5),
	"trainer": Color(0.5, 0.6, 0.8),
	"rumor": Color(0.7, 0.6, 0.5),
	"quest": Color(0.8, 0.6, 0.4)
}

# =============================================================================
# STATE
# =============================================================================

var _current_location: Dictionary = {}
var _npcs: Array[Dictionary] = []
var _selected_npc_id: String = ""
var _npc_manager: Node = null

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _panel: PanelContainer
var _location_label: Label
var _close_button: Button
var _npc_list: VBoxContainer
var _details_panel: PanelContainer
var _npc_name_label: Label
var _npc_title_label: Label
var _npc_description_label: Label
var _availability_label: Label
var _service_buttons: HBoxContainer

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	visible = false
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	# Main panel container
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700, 500)
	add_child(_panel)

	# Apply panel style
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.13, 0.11, 0.98)
	panel_style.set_corner_radius_all(8)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.5, 0.45, 0.35)
	_panel.add_theme_stylebox_override("panel", panel_style)

	# Center the panel
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# Margin container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 15)
	_panel.add_child(margin)

	# Main VBox
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)

	# Header row
	var header := HBoxContainer.new()
	main_vbox.add_child(header)

	_location_label = Label.new()
	_location_label.add_theme_font_size_override("font_size", 24)
	_location_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	_location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_location_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(32, 32)
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)

	# Content HBox
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content)

	# NPC List (left side)
	var list_container := PanelContainer.new()
	list_container.custom_minimum_size = Vector2(200, 0)
	content.add_child(list_container)

	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color(0.12, 0.1, 0.08)
	list_style.set_corner_radius_all(4)
	list_container.add_theme_stylebox_override("panel", list_style)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_container.add_child(list_scroll)

	_npc_list = VBoxContainer.new()
	_npc_list.add_theme_constant_override("separation", 5)
	list_scroll.add_child(_npc_list)

	# Details panel (right side)
	_details_panel = PanelContainer.new()
	_details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_details_panel)

	var details_style := StyleBoxFlat.new()
	details_style.bg_color = Color(0.1, 0.09, 0.07)
	details_style.set_corner_radius_all(4)
	_details_panel.add_theme_stylebox_override("panel", details_style)

	var details_margin := MarginContainer.new()
	details_margin.add_theme_constant_override("margin_left", 15)
	details_margin.add_theme_constant_override("margin_top", 10)
	details_margin.add_theme_constant_override("margin_right", 15)
	details_margin.add_theme_constant_override("margin_bottom", 10)
	_details_panel.add_child(details_margin)

	var details_vbox := VBoxContainer.new()
	details_vbox.add_theme_constant_override("separation", 8)
	details_margin.add_child(details_vbox)

	_npc_name_label = Label.new()
	_npc_name_label.add_theme_font_size_override("font_size", 20)
	_npc_name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	details_vbox.add_child(_npc_name_label)

	_npc_title_label = Label.new()
	_npc_title_label.add_theme_font_size_override("font_size", 14)
	_npc_title_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	details_vbox.add_child(_npc_title_label)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 5)
	details_vbox.add_child(spacer1)

	_npc_description_label = Label.new()
	_npc_description_label.add_theme_font_size_override("font_size", 14)
	_npc_description_label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
	_npc_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_npc_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_vbox.add_child(_npc_description_label)

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_vbox.add_child(spacer2)

	_availability_label = Label.new()
	_availability_label.add_theme_font_size_override("font_size", 13)
	_availability_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
	details_vbox.add_child(_availability_label)

	# Service buttons row
	_service_buttons = HBoxContainer.new()
	_service_buttons.add_theme_constant_override("separation", 10)
	_service_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	details_vbox.add_child(_service_buttons)


func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("location_entered"):
			event_bus.location_entered.connect(_on_location_entered)
		if event_bus.has_signal("location_exited"):
			event_bus.location_exited.connect(_on_location_exited)

# =============================================================================
# PUBLIC API
# =============================================================================

## Open the NPC panel for a location.
func open(location_data: Dictionary) -> void:
	_current_location = location_data
	_npc_manager = get_tree().get_first_node_in_group("npc_manager")

	if not _npc_manager:
		push_warning("NPCPanel: NPCManager not found")
		return

	_npcs = _npc_manager.get_npcs_at_current_location()

	if _npcs.is_empty():
		# No NPCs at this location
		return

	_location_label.text = location_data.get("name", "Unknown Location")
	_populate_npc_list()

	# Select first NPC
	if not _npcs.is_empty():
		_select_npc(_npcs[0]["npc_id"])

	visible = true


## Close the panel.
func close() -> void:
	visible = false
	_selected_npc_id = ""
	_current_location = {}
	_npcs.clear()
	closed.emit()


## Refresh the panel (e.g., after time change).
func refresh() -> void:
	if not visible or _current_location.is_empty():
		return

	if _npc_manager:
		_npcs = _npc_manager.get_npcs_at_current_location()
		_populate_npc_list()

		if not _selected_npc_id.is_empty():
			_update_details(_selected_npc_id)

# =============================================================================
# NPC LIST
# =============================================================================

func _populate_npc_list() -> void:
	# Clear existing buttons
	for child in _npc_list.get_children():
		child.queue_free()

	for npc in _npcs:
		var btn := Button.new()
		btn.text = npc.get("display_name", "Unknown")
		btn.custom_minimum_size = Vector2(180, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Style based on availability
		var available: bool = npc.get("available", true)
		if not available:
			btn.modulate = Color(0.6, 0.6, 0.6)

		btn.pressed.connect(_on_npc_button_pressed.bind(npc["npc_id"]))
		_npc_list.add_child(btn)


func _select_npc(npc_id: String) -> void:
	_selected_npc_id = npc_id
	_update_details(npc_id)
	npc_selected.emit(npc_id)


func _update_details(npc_id: String) -> void:
	var npc: Dictionary = {}
	for n in _npcs:
		if n["npc_id"] == npc_id:
			npc = n
			break

	if npc.is_empty():
		return

	_npc_name_label.text = npc.get("display_name", "Unknown")
	_npc_title_label.text = npc.get("title", "")
	_npc_description_label.text = npc.get("description", "")

	var available: bool = npc.get("available", true)
	if available:
		_availability_label.text = ""
		_availability_label.visible = false
	else:
		_availability_label.text = npc.get("unavailable_reason", "Not available")
		_availability_label.visible = true

	_update_service_buttons(npc)


func _update_service_buttons(npc: Dictionary) -> void:
	# Clear existing buttons
	for child in _service_buttons.get_children():
		child.queue_free()

	var services: Array = npc.get("services", [])
	var available: bool = npc.get("available", true)

	for service_data in services:
		var service_id: String = service_data.get("id", "") if service_data is Dictionary else str(service_data)
		var service_enabled: bool = service_data.get("enabled", true) if service_data is Dictionary else available

		var label: String = SERVICE_LABELS.get(service_id, service_id.capitalize())

		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(80, 32)
		btn.disabled = not service_enabled

		if service_enabled:
			var color: Color = SERVICE_COLORS.get(service_id, Color(0.6, 0.6, 0.6))
			btn.add_theme_color_override("font_color", color)

		btn.pressed.connect(_on_service_button_pressed.bind(npc["npc_id"], service_id))
		_service_buttons.add_child(btn)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_location_entered(location_data: Dictionary) -> void:
	# Small delay to let NPCManager process
	await get_tree().process_frame
	open(location_data)


func _on_location_exited(_location_id: String) -> void:
	close()


func _on_close_pressed() -> void:
	close()


func _on_npc_button_pressed(npc_id: String) -> void:
	_select_npc(npc_id)


func _on_service_button_pressed(npc_id: String, service: String) -> void:
	service_selected.emit(npc_id, service)

	# Start NPC interaction in manager
	if _npc_manager and _npc_manager.has_method("start_interaction"):
		_npc_manager.start_interaction(npc_id)

	# Route to appropriate system
	match service:
		"trade":
			_open_trade(npc_id)
		"trainer":
			_open_trainer(npc_id)
		"dialogue":
			_open_dialogue(npc_id)
		"rumor":
			_open_rumor(npc_id)
		"quest":
			_open_quest(npc_id)


func _open_trade(npc_id: String) -> void:
	var npc := _get_npc_by_id(npc_id)
	var shop_id: String = npc.get("shop_id", "")
	if shop_id.is_empty():
		print("NPCPanel: No shop_id for NPC %s" % npc_id)
		return

	# Find and open ShopPanel
	var shop_panel = get_tree().get_first_node_in_group("shop_panel")
	if not shop_panel:
		# Try finding by path in UI layer
		shop_panel = get_node_or_null("../ShopPanel")

	if shop_panel and shop_panel.has_method("open"):
		close()  # Close NPC panel before opening shop
		shop_panel.open(shop_id)
		print("NPCPanel: Opened shop '%s'" % shop_id)
	else:
		push_warning("NPCPanel: ShopPanel not found")


func _open_trainer(npc_id: String) -> void:
	var npc := _get_npc_by_id(npc_id)
	var trainer_id: String = npc.get("trainer_id", "")
	if trainer_id.is_empty():
		print("NPCPanel: No trainer_id for NPC %s" % npc_id)
		return

	# TODO: Open trainer UI
	print("NPCPanel: Would open trainer '%s'" % trainer_id)


func _open_dialogue(npc_id: String) -> void:
	var npc := _get_npc_by_id(npc_id)
	var dialogue_id: String = npc.get("dialogue_id", "")

	# TODO: Open dialogue UI
	print("NPCPanel: Would open dialogue '%s'" % dialogue_id)


func _open_rumor(npc_id: String) -> void:
	var npc := _get_npc_by_id(npc_id)
	var rumor_id: String = npc.get("rumor_dialogue_id", "")

	# TODO: Open rumor UI
	print("NPCPanel: Would open rumors for '%s'" % npc_id)


func _open_quest(npc_id: String) -> void:
	# TODO: Open quest UI
	print("NPCPanel: Would open quests for '%s'" % npc_id)


func _get_npc_by_id(npc_id: String) -> Dictionary:
	for npc in _npcs:
		if npc["npc_id"] == npc_id:
			return npc
	return {}

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
