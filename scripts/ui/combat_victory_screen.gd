# combat_victory_screen.gd
# Displays victory message and loot after winning tactical combat.
# Shows gold gained, items collected, and a continue button.

extends Control
class_name CombatVictoryScreen

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when player clicks continue to return to exploration.
signal continue_pressed()

# =============================================================================
# NODE REFERENCES
# =============================================================================

var _overlay: ColorRect
var _panel: PanelContainer
var _vbox: VBoxContainer
var _title_label: Label
var _subtitle_label: Label
var _loot_container: VBoxContainer
var _gold_label: Label
var _items_label: Label
var _continue_button: Button

# =============================================================================
# STATE
# =============================================================================

var _loot_data: Dictionary = {}

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_create_ui()
	hide()


func _create_ui() -> void:
	# Full screen
	#set_anchors_preset(Control.PRESET_FULL_RECT)
	set_anchors_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Semi-transparent overlay
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.02, 0.05, 0.02, 0.85)
	add_child(_overlay)
	
	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(450, 350)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.08, 0.95)
	panel_style.set_corner_radius_all(16)
	panel_style.set_content_margin_all(32)
	panel_style.border_width_bottom = 3
	panel_style.border_width_top = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = Color(0.4, 0.6, 0.3)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)
	
	# Main layout
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(_vbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "VICTORY"
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.4))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_label)
	
	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = "All enemies defeated!"
	_subtitle_label.add_theme_font_size_override("font_size", 20)
	_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_subtitle_label)
	
	# Separator
	var sep := HSeparator.new()
	_vbox.add_child(sep)
	
	# Loot header
	var loot_header := Label.new()
	loot_header.text = "Spoils of Battle"
	loot_header.add_theme_font_size_override("font_size", 22)
	loot_header.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	loot_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(loot_header)
	
	# Loot container
	_loot_container = VBoxContainer.new()
	_loot_container.add_theme_constant_override("separation", 8)
	_vbox.add_child(_loot_container)
	
	# Gold label
	_gold_label = Label.new()
	_gold_label.text = "Gold: 0"
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loot_container.add_child(_gold_label)
	
	# Items label
	_items_label = Label.new()
	_items_label.text = ""
	_items_label.add_theme_font_size_override("font_size", 18)
	_items_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_items_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loot_container.add_child(_items_label)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	_vbox.add_child(spacer)
	
	# Continue button
	var btn_center := CenterContainer.new()
	_vbox.add_child(btn_center)
	
	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(200, 50)
	_continue_button.add_theme_font_size_override("font_size", 22)
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.4, 0.25)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(12)
	_continue_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.4, 0.5, 0.3)
	_continue_button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed := btn_style.duplicate()
	btn_pressed.bg_color = Color(0.25, 0.35, 0.2)
	_continue_button.add_theme_stylebox_override("pressed", btn_pressed)
	
	_continue_button.pressed.connect(_on_continue_pressed)
	btn_center.add_child(_continue_button)

# =============================================================================
# PUBLIC API
# =============================================================================

## Show the victory screen with loot data.
## @param loot: Dictionary with "gold" (int) and "items" (Array of {id, quantity}).
## @param enemies_defeated: Number of enemies defeated.
func show_victory(loot: Dictionary, enemies_defeated: int = 0) -> void:
	_loot_data = loot
	
	# Update subtitle
	if enemies_defeated > 0:
		_subtitle_label.text = "%d enem%s defeated!" % [
			enemies_defeated,
			"y" if enemies_defeated == 1 else "ies"
		]
	else:
		_subtitle_label.text = "All enemies defeated!"
	
	# Update gold display
	var gold: int = loot.get("gold", 0)
	if gold > 0:
		_gold_label.text = "+ %d Gold" % gold
		_gold_label.show()
	else:
		_gold_label.hide()
	
	# Update items display
	var items: Array = loot.get("items", [])
	if items.size() > 0:
		var items_text := ""
		for item in items:
			var item_id: String = item.get("id", "unknown")
			var quantity: int = item.get("quantity", 1)
			var display_name := _get_item_display_name(item_id)
			
			if items_text != "":
				items_text += ", "
			
			if quantity > 1:
				items_text += "%d %s" % [quantity, display_name]
			else:
				items_text += display_name
		
		_items_label.text = "+ " + items_text
		_items_label.show()
	else:
		_items_label.hide()
	
	# Show with animation
	show()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	
	# Focus button
	await tween.finished
	_continue_button.grab_focus()


## Hide the victory screen.
func hide_victory() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	hide()

# =============================================================================
# INTERNAL
# =============================================================================

func _get_item_display_name(item_id: String) -> String:
	# Convert item ID to display name
	match item_id:
		"rations":
			return "Rations"
		"water":
			return "Water"
		"bandages":
			return "Bandages"
		"medicine":
			return "Medicine"
		"pistol_rounds":
			return "Pistol Rounds"
		"rifle_rounds":
			return "Rifle Rounds"
		_:
			# Capitalize and replace underscores
			return item_id.capitalize().replace("_", " ")

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_continue_pressed() -> void:
	continue_pressed.emit()
	hide_victory()

# =============================================================================
# INPUT
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Block all input while visible
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
	
	# Allow Enter/Space to continue
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_on_continue_pressed()
