# TODO: NPC, Trainer, and Economy Systems

## Overview

This document outlines the design for NPCs, trainers, and a basic economy system that integrates with the existing Dustwalker architecture.

---

## 1. NPC System

### Concept
NPCs are **data-driven entities tied to locations**, not physical map objects. When the player enters a location (town, fort, outpost), available NPCs are queried and presented through UI.

### Data Structure (`data/npcs/npcs.json`)
```json
{
  "npcs": {
    "sheriff_miller": {
      "name": "Sheriff Miller",
      "title": "Town Sheriff",
      "location": "dusty_gulch",
      "services": ["dialogue", "quest"],
      "dialogue_id": "sheriff_miller_intro",
      "schedule": {
        "available_times": ["morning", "afternoon", "evening"],
        "unavailable_reason": "The sheriff is out on patrol."
      }
    },
    "old_pete": {
      "name": "Old Pete",
      "title": "Retired Gunslinger",
      "location": "dusty_gulch",
      "services": ["trainer", "dialogue"],
      "trainer_id": "trainer_pete",
      "dialogue_id": "old_pete_intro"
    }
  }
}
```

### NPCManager (`scripts/systems/npc_manager.gd`)
```gdscript
class_name NPCManager extends Node

signal npc_interaction_started(npc_id: String, npc_data: Dictionary)
signal npc_interaction_ended(npc_id: String)

var _npc_data: Dictionary = {}

func get_npcs_at_location(location_id: String) -> Array[Dictionary]
func get_npc(npc_id: String) -> Dictionary
func is_npc_available(npc_id: String) -> bool  # Check schedule vs TimeManager
func start_interaction(npc_id: String) -> void
```

### Integration Points
- **LocationPlacer**: Locations already exist; NPCs reference location IDs
- **TimeManager**: NPC availability based on time of day
- **EncounterManager**: Some NPCs may trigger encounters or quests
- **EventBus**: `npc_interaction_started`, `npc_interaction_ended`

### UI Component (`scripts/ui/npc_panel.gd`)
- Shows list of NPCs at current location
- Displays NPC portrait, name, title, available services
- Buttons for each service (Talk, Trade, Train, etc.)

---

## 2. Trainer NPCs

### Concept
Trainers are NPCs with `"trainer"` in their services array. They teach talents from the existing TalentManager system.

### Data Structure (`data/character/talents_config.json` - existing)
```json
{
  "trainers": {
    "trainer_pete": {
      "name": "Old Pete",
      "specialty": "Combat",
      "teaches": ["quick_draw", "steady_aim", "fan_the_hammer"],
      "cost_modifier": 1.0,
      "requirements": {
        "min_reputation": 0
      }
    }
  }
}
```

### Training Flow
1. Player interacts with trainer NPC
2. UI shows talents trainer can teach (via `TalentManager.get_trainer_talents()`)
3. Each talent shows: name, description, cost, training days, prerequisites
4. Player selects talent → money deducted → training starts
5. Training progresses via `TimeManager.day_started` signal
6. After N days, talent is acquired

### UI Component (`scripts/ui/trainer_panel.gd`)
```gdscript
signal talent_purchase_requested(talent_id: String, trainer_id: String)

func show_trainer(trainer_id: String) -> void
func _populate_talent_list() -> void
func _on_talent_selected(talent_id: String) -> void
func _on_purchase_pressed() -> void
```

### Already Implemented in TalentManager
- `get_trainer_talents(trainer_id)` - returns teachable talents
- `purchase_talent(talent_id, trainer_id)` - handles cost, starts training
- `get_training_status()` - shows ongoing training
- `_on_day_started()` - processes training progress

### TODO Tasks
- [ ] Create `trainer_panel.gd` and `trainer_panel.tscn`
- [ ] Add trainer data to `talents_config.json`
- [ ] Connect trainer panel to NPC interaction flow
- [ ] Add training status display to character panel

---

## 3. Economy System

### Concept
A lightweight trading system for buying/selling goods at shops. Shops are NPCs with `"shop"` service.

### Data Structure (`data/economy/shops.json`)
```json
{
  "shops": {
    "general_store_dusty": {
      "name": "Dusty Gulch General Store",
      "npc_id": "shopkeeper_martha",
      "location": "dusty_gulch",
      "buy_modifier": 1.0,
      "sell_modifier": 0.5,
      "inventory": {
        "rations": { "stock": 20, "base_price": 2 },
        "water": { "stock": 15, "base_price": 1 },
        "bandages": { "stock": 10, "base_price": 5 },
        "ammo_revolver": { "stock": 50, "base_price": 1 }
      },
      "buys": ["pelts", "scrap", "herbs"]
    }
  },
  "item_base_prices": {
    "rations": 2,
    "water": 1,
    "bandages": 5,
    "pelts": 3,
    "scrap": 1
  }
}
```

### ShopManager (`scripts/systems/shop_manager.gd`)
```gdscript
class_name ShopManager extends Node

signal item_purchased(item_id: String, quantity: int, total_cost: int)
signal item_sold(item_id: String, quantity: int, total_value: int)
signal shop_opened(shop_id: String)
signal shop_closed()

func get_shop_inventory(shop_id: String) -> Array[Dictionary]
func get_buy_price(shop_id: String, item_id: String) -> int
func get_sell_price(shop_id: String, item_id: String) -> int
func purchase_item(shop_id: String, item_id: String, quantity: int) -> Dictionary
func sell_item(shop_id: String, item_id: String, quantity: int) -> Dictionary
```

### Integration with InventoryManager
```gdscript
# In ShopManager
func purchase_item(shop_id: String, item_id: String, quantity: int) -> Dictionary:
    var price := get_buy_price(shop_id, item_id) * quantity
    var inv := get_tree().get_first_node_in_group("inventory_manager")

    if not inv.has_money(price):
        return {"success": false, "reason": "insufficient_funds"}

    inv.spend_money(price)
    inv.add_item(item_id, quantity)
    _reduce_shop_stock(shop_id, item_id, quantity)

    item_purchased.emit(item_id, quantity, price)
    return {"success": true, "cost": price}
```

### UI Component (`scripts/ui/shop_panel.gd`)
- Two columns: Shop inventory (buy) | Player inventory (sell)
- Shows prices, stock levels, player money
- Quantity selector for bulk transactions
- Total cost preview before confirming

### Price Modifiers (Future)
- Reputation with faction/town affects prices
- Supply/demand (low stock = higher prices)
- Charisma/charm skill check for discounts
- Special events (drought = water prices spike)

### TODO Tasks
- [ ] Create `data/economy/shops.json`
- [ ] Create `shop_manager.gd`
- [ ] Create `shop_panel.gd` and `shop_panel.tscn`
- [ ] Add item definitions with base prices
- [ ] Connect to NPC interaction flow

---

## 4. Implementation Order

### Phase 1: NPC Foundation
1. Create `npcs.json` with 2-3 test NPCs
2. Create `NPCManager` with basic queries
3. Create simple `NPCPanel` UI
4. Hook into location entry (when player enters town hex)

### Phase 2: Trainers
1. Add trainer data to `talents_config.json`
2. Create `TrainerPanel` UI
3. Connect to existing `TalentManager.purchase_talent()`
4. Add training status to character panel

### Phase 3: Economy
1. Create `shops.json` with one test shop
2. Create `ShopManager`
3. Create `ShopPanel` UI
4. Test buy/sell flow

### Phase 4: Polish
1. NPC portraits and dialogue
2. Price modifiers (reputation, skills)
3. Shop restocking over time
4. Quest-giver NPCs

---

## 5. File Summary

### New Files
```
data/
├── npcs/
│   └── npcs.json
└── economy/
    └── shops.json

scripts/
├── systems/
│   ├── npc_manager.gd
│   └── shop_manager.gd
└── ui/
    ├── npc_panel.gd
    ├── trainer_panel.gd
    └── shop_panel.gd

scenes/ui/
├── npc_panel.tscn
├── trainer_panel.tscn
└── shop_panel.tscn
```

### Modified Files
- `data/character/talents_config.json` - Add trainer definitions
- `scripts/autoloads/event_bus.gd` - Add NPC/shop signals
- `scripts/ui/character_panel.gd` - Show training status
