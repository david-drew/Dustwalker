
# Dustwalker Economy System – Design Document v1

## Status
Design-complete, implementation-ready  
Aligned with Dustwalker NPC System, SaveManager provider pattern, TimeManager semantics, and EventBus conventions

---

## 1. Scope and Goals

### 1.1 Purpose
This document defines **Economy System v0** for Dustwalker: a lightweight, deterministic buy/sell system accessed through NPCs that provide a `"shop"` service. The system supports persistent shop inventories, consistent pricing rules, and weekly restocking driven by in-game time.

### 1.2 Design Goals
- Simple, reliable buy/sell loop that feels grounded
- Fully data-driven (items, shops, pricing)
- Persistent shop state across saves
- Clean integration with NPCManager, InventoryManager, TimeManager, and EventBus
- Extensible foundation for future economic depth (reputation, skills, events)

### 1.3 Explicit Non-Goals (v0)
- Global supply/demand simulation
- Inter-town price gradients
- Barter systems or alternate currencies
- NPC caravans or moving vendors

---

## 2. Core Concepts and Terminology

### 2.1 Item Definition
A canonical, JSON-defined item entry that includes at minimum:
- `item_id`
- display name
- base price

Items are **not owned by the Economy system** but are consumed by it.

### 2.2 Shop
A **shop definition** describes:
- What items are stocked
- What items the shop will buy from the player
- Price modifiers
- Restocking behavior

Shops do not represent characters. They are economic backends.

### 2.3 NPC Shop Service
NPCs act as the **entry point** to shops. An NPC provides a `"shop"` service and references a `shop_id`. The NPC owns identity, location, schedule, and UI presence; the shop owns inventory and pricing.

---

## 3. System Responsibilities

### 3.1 ShopManager
**Primary economy system.**

Responsibilities:
- Load shop definitions from `shops.json`
- Resolve buy/sell prices
- Validate and execute transactions
- Track and persist per-shop inventory state
- Perform weekly restocking
- Expose shop data to UI
- Emit shop-related signals

Godot integration:
- Script: `res://scripts/systems/shop_manager.gd`
- Group: `shop_manager`
- Implements `to_dict()` / `from_dict()` for SaveManager

### 3.2 InventoryManager (Dependency Contract)
ShopManager relies on InventoryManager to provide:
- `get_money() -> int`
- `has_money(amount:int) -> bool`
- `spend_money(amount:int) -> bool`
- `add_item(item_id:String, qty:int) -> void`
- `remove_item(item_id:String, qty:int) -> bool`
- `get_item_count(item_id:String) -> int`
- Signal: `inventory_changed`

### 3.3 NPCManager Integration
- NPC definitions include `services: ["shop"]` and `shop_id`
- NPC interaction routes shop access to ShopManager
- NPC system does not manage inventory or pricing

---

## 4. Data Model

### 4.1 Item Definitions (`data/economy/items.json`)

Canonical item database.

```json
{
  "items": {
    "rations": {
      "display_name": "Rations",
      "base_price": 2,
      "stackable": true,
      "tags": ["food"]
    },
    "bandages": {
      "display_name": "Bandages",
      "base_price": 5,
      "stackable": true,
      "tags": ["medical"]
    }
  }
}
````

**Rules**

* `base_price` is the authoritative reference price
* Economy system never hardcodes prices

---

### 4.2 Shop Definitions (`data/economy/shops.json`)

```json
{
  "shops": {
    "general_store_dusty": {
      "display_name": "Dusty Gulch General Store",
      "location_id": "dusty_gulch",

      "buy_modifier": 1.0,
      "sell_modifier": 0.5,

      "inventory": {
        "rations": {
          "stock": 20,
          "max_stock": 30,
          "restock_per_week": 10
        },
        "bandages": {
          "stock": 10,
          "max_stock": 10,
          "restock_per_week": 2
        }
      },

      "buys": ["pelts", "scrap", "herbs"]
    }
  }
}
```

**Field Notes**

* `location_id` is informational and used for validation/debugging
* `inventory` defines what the shop sells
* `buys` is an allowlist of items the shop will purchase from the player
* Shops do not reference NPCs

---

### 4.3 NPC Shop Reference (from NPC system)

```json
"shopkeeper_martha": {
  "display_name": "Martha",
  "title": "Shopkeeper",
  "location_id": "dusty_gulch",
  "services": ["shop", "dialogue"],
  "shop_id": "general_store_dusty"
}
```

---

## 5. Pricing Rules

### 5.1 Buy Price (Player Buys from Shop)

```
buy_price = ceil(base_price × buy_modifier)
buy_price = max(buy_price, 1)
```

### 5.2 Sell Price (Player Sells to Shop)

```
sell_price = floor(base_price × sell_modifier)
sell_price = max(sell_price, 1)
```

### 5.3 Anti-Arbitrage Guarantees

* Buy rounds **up**
* Sell rounds **down**
* Minimum price is always **1**
* No negative or zero-value trades

---

## 6. Transaction Flow

### 6.1 Purchase (Buy)

1. Validate shop exists
2. Validate item exists in shop inventory
3. Validate sufficient shop stock
4. Validate player has enough money
5. Deduct money
6. Add item to player inventory
7. Reduce shop stock
8. Persist state
9. Emit signals

### 6.2 Sale (Sell)

1. Validate shop exists
2. Validate item is in shop `buys` allowlist
3. Validate player has sufficient quantity
4. Remove item from player inventory
5. Add money to player
6. Optionally increase shop stock
7. Persist state
8. Emit signals

### 6.3 Standard Failure Reasons

* `shop_not_found`
* `item_not_sold_here`
* `out_of_stock`
* `insufficient_funds`
* `insufficient_items`
* `invalid_quantity`

---

## 7. Persistence

### 7.1 Saved Shop State Schema

```json
{
  "shops": {
    "general_store_dusty": {
      "inventory": {
        "rations": { "stock": 12 },
        "bandages": { "stock": 6 }
      },
      "last_restock_day": 8
    }
  }
}
```

### 7.2 Save Rules

* Only **mutable state** is saved
* Shop definitions are never duplicated in save files
* Missing saved entries fall back to definition defaults

---

## 8. Weekly Restocking

### 8.1 Time Integration

* ShopManager listens to:

  ```gdscript
  signal day_started(day: int)
  ```

### 8.2 Week Definition

* One week = **7 in-game days**
* Restock occurs when:

  ```
  (day - 1) % 7 == 0
  ```

  (i.e., days 1, 8, 15, 22, …)

### 8.3 Restock Algorithm

For each shop and item:

```
new_stock = min(
  max_stock,
  current_stock + restock_per_week
)
```

### 8.4 Persistence Guard

* Each shop tracks `last_restock_day`
* Restock only occurs if `last_restock_day < current_day`

---

## 9. Signals and EventBus Integration

### 9.1 ShopManager Local Signals

```gdscript
signal shop_opened(shop_id: String)
signal shop_closed(shop_id: String)
signal item_purchased(item_id: String, quantity: int, total_cost: int)
signal item_sold(item_id: String, quantity: int, total_value: int)
```

### 9.2 EventBus Signals (Additions)

```gdscript
signal shop_opened(shop_id: String)
signal shop_closed(shop_id: String)
signal shop_transaction_completed(shop_id: String, transaction: Dictionary)
```

**Transaction payload example**

```json
{
  "type": "buy",
  "item_id": "rations",
  "quantity": 5,
  "total": 10,
  "success": true
}
```

---

## 10. UI Requirements

### 10.1 ShopPanel

* Two-column layout:

  * Left: shop inventory (buy)
  * Right: player inventory (sell)
* Display:

  * Item name
  * Unit price
  * Stock or owned quantity
  * Player money
* Quantity selector
* Total cost/value preview before confirmation
* Disabled states with reason tooltips

### 10.2 UI Data Contract

ShopManager provides UI-ready data:

* Item list with prices and stock
* Sellability flags
* Failure reasons for disabled actions

UI does not compute prices.

---

## 11. Implementation Plan

### Phase 1 – Core

1. Create `items.json`
2. Create `shops.json`
3. Implement `ShopManager`
4. Implement save/load logic
5. Implement weekly restock

### Phase 2 – UI

1. Implement `ShopPanel`
2. NPC → shop routing
3. EventBus wiring

### Phase 3 – Validation & Debug

1. Schema validation (missing item IDs, bad shop IDs)
2. Debug logging for restock and transactions
3. Economy test scenarios

---

## 12. Future Extensions

* Reputation-based modifiers
* Skill-based discounts
* Dynamic stock generation
* Regional scarcity events
* Faction-controlled pricing

---

## Summary

The Economy System v0 provides a grounded, deterministic trading loop that:

* Integrates cleanly with NPCs and inventory
* Persists meaningful world state
* Uses time to create economic rhythm
* Avoids over-design while remaining extensible

This design is intentionally conservative, favoring correctness and clarity over simulation depth in early development.

