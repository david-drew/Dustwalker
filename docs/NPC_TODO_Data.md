# NPC System - Architecture Reference

Temporary document for implementing NPCs. Delete after implementation.

---

## 1. SaveSystem Provider Pattern

Dustwalker uses a **centralized SaveManager** that queries individual systems for their state. Each system implements `to_dict()` and `from_dict()` methods.

### Example: InventoryManager as Provider
```gdscript
# scripts/systems/inventory_manager.gd

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
```

### How SaveManager Uses Providers
```gdscript
# In save_manager.gd _gather_save_data():

# Find system by group
var inventory_manager := get_tree().get_first_node_in_group("inventory_manager")

# Call to_dict() if it exists
if inventory_manager and inventory_manager.has_method("to_dict"):
    save_data["inventory"] = inventory_manager.to_dict()
```

### For NPCManager
```gdscript
# NPCManager must:
# 1. Add itself to group: add_to_group("npc_manager")
# 2. Implement to_dict() returning NPC state
# 3. Implement from_dict() to restore state
# 4. SaveManager will need updating to include NPC data
```

---

## 2. TimeManager API

### Time-of-Day Constants
```gdscript
const TURNS_PER_DAY: int = 6
const HOURS_PER_TURN: int = 4

const TIME_NAMES: Dictionary = {
    1: "Late Night",   # Midnight-4am
    2: "Dawn",         # 4am-8am
    3: "Morning",      # 8am-Noon
    4: "Afternoon",    # Noon-4pm
    5: "Evening",      # 4pm-8pm
    6: "Night"         # 8pm-Midnight
}
```

### Key Query Methods
```gdscript
func get_time_of_day() -> String      # Returns "Morning", "Afternoon", etc.
func get_current_day() -> int         # Returns day number (1-based)
func is_daytime() -> bool             # Turn 2-5 (Dawn through Evening)
func is_nighttime() -> bool           # Turn 1 or 6
func get_hour_of_day() -> int         # 0-23
```

### Relevant Signals
```gdscript
signal turn_started(turn: int, day: int, time_name: String)
signal day_started(day: int)
signal time_of_day_changed(old_name: String, new_name: String)
signal night_started(day: int)
signal dawn_started(day: int)
```

### NPC Availability Check Example
```gdscript
func is_npc_available(npc_id: String) -> bool:
    var time_manager = get_node_or_null("/root/TimeManager")
    if not time_manager:
        return true

    var npc_data := get_npc(npc_id)
    var schedule: Dictionary = npc_data.get("schedule", {})
    var available_times: Array = schedule.get("available_times", [])

    if available_times.is_empty():
        return true  # Always available

    var current_time: String = time_manager.get_time_of_day().to_lower()
    return current_time in available_times
```

---

## 3. Location Entry Flow

### Current Architecture
- **Locations stored in**: `HexCell.location` (Dictionary or null)
- **Location placement**: `LocationPlacer` assigns locations to cells during map generation
- **No explicit "entered location" event exists yet**

### Player Movement Chain
```
Player clicks hex
    → MovementController.request_movement()
    → Player.move_along_path()
    → Player._on_waypoint_reached() emits:
        player_moved_to_hex(hex_coords)
    → EncounterManager listens and may trigger encounter
```

### Where Location Entry Should Be Detected
The **EncounterManager** or a new system should listen to `player_moved_to_hex` and check for locations:

```gdscript
# Proposed: in NPCManager or EncounterManager
func _on_player_moved_to_hex(hex_coords: Vector2i) -> void:
    var hex_grid := get_tree().get_first_node_in_group("hex_grid")
    if not hex_grid:
        return

    var cell: HexCell = hex_grid.get_cell(hex_coords)
    if cell and cell.location:
        _on_player_entered_location(cell.location)

func _on_player_entered_location(location_data: Dictionary) -> void:
    var location_type: String = location_data.get("type", "")
    var location_name: String = location_data.get("name", "")

    # Emit signal for UI to show location panel
    location_entered.emit(location_data)
    _emit_to_event_bus("location_entered", [location_data])
```

### UI Spawning
UI panels are spawned in `Main.gd` and added to `MenuLayer` (CanvasLayer 100):

```gdscript
# In main.gd _create_menu_layer():
menu_layer = CanvasLayer.new()
menu_layer.layer = 100
add_child(menu_layer)

# Add UI scenes:
npc_panel = load("res://scenes/ui/npc_panel.tscn").instantiate()
npc_panel.visible = false
menu_layer.add_child(npc_panel)
```

---

## 4. EventBus Conventions

### Signal Naming
- **Past tense verbs** for events that occurred: `player_spawned`, `combat_ended`, `item_consumed`
- **Present tense** for state changes: `health_changed`, `turn_started`
- **Underscore separated**: `player_moved_to_hex`, `weapon_equipped`

### Typical Payload Patterns
```gdscript
# Entity + ID pattern:
signal weapon_equipped(slot: int, weapon_id: String)
signal item_added(item_id: String, quantity: int, new_total: int)

# State change pattern (new, old):
signal health_changed(new_value: int, old_value: int, source: String)
signal stat_changed(stat_name: String, new_value: int, old_value: int)

# Event data pattern:
signal encounter_triggered(encounter_id: String, hex_coords: Vector2i)
signal location_discovered(location_data: Dictionary)

# Simple notification:
signal combat_started()
signal inventory_changed()
```

### Emit Helper Pattern
All systems use this helper to emit to EventBus:
```gdscript
func _emit_to_event_bus(signal_name: String, args: Array) -> void:
    var event_bus = get_node_or_null("/root/EventBus")
    if event_bus and event_bus.has_signal(signal_name):
        match args.size():
            0: event_bus.emit_signal(signal_name)
            1: event_bus.emit_signal(signal_name, args[0])
            2: event_bus.emit_signal(signal_name, args[0], args[1])
            3: event_bus.emit_signal(signal_name, args[0], args[1], args[2])
```

### Proposed NPC Signals
```gdscript
# Add to EventBus:
signal location_entered(location_data: Dictionary)
signal location_exited(location_id: String)
signal npc_interaction_started(npc_id: String, npc_data: Dictionary)
signal npc_interaction_ended(npc_id: String)
signal shop_transaction_completed(shop_id: String, transaction: Dictionary)
```

---

## 5. NPC Death/Removal

### World Rules Assessment
Based on current design documents and code:

1. **No NPC death system exists** - NPCs are data, not entities with health
2. **Locations persist** - Towns, forts, etc. don't get destroyed
3. **Focus is on player survival** - Not NPC lifecycle

### Recommendation: NPCs Are Persistent
For simplicity, NPCs should be:
- **Static**: Always exist at their assigned location
- **Available or Unavailable**: Based on time, quest state, or disposition
- **Not killable**: No combat with named NPCs (for now)

### Persistence Schema
```json
{
  "npcs": {
    "sheriff_miller": {
      "disposition": 50,
      "quest_state": "intro_complete",
      "last_interaction_day": 5,
      "custom_flags": {}
    }
  }
}
```

### Future Considerations
If NPC death becomes a feature:
- Add `alive: bool` to NPC state
- Add `death_day: int` for when they died
- Add replacement NPC logic (new sheriff takes over)
- This would require significant design work

---

## Summary: Implementation Checklist

1. **NPCManager** (`scripts/systems/npc_manager.gd`)
   - Load NPC data from `data/npcs/npcs.json`
   - Query NPCs by location
   - Check availability via TimeManager
   - Implement `to_dict()`/`from_dict()` for persistence

2. **Location Entry Detection**
   - Listen to `player_moved_to_hex` in EncounterManager or NPCManager
   - Check `HexCell.location` for location data
   - Emit `location_entered` signal

3. **EventBus Updates**
   - Add `location_entered`, `location_exited`
   - Add `npc_interaction_started`, `npc_interaction_ended`

4. **SaveManager Updates**
   - Add NPCManager to `_gather_save_data()`
   - Add NPCManager to `_apply_save_data()`

5. **UI Integration**
   - Create NPCPanel, spawn in Main.gd MenuLayer
   - Show on `location_entered` for locations with NPCs
