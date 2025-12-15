
## Economy Addendum: Wandering Merchants (Design + Implementation Instructions)



### Status
Planned extension to Economy v0. Not required for initial buy/sell loop, but designed to integrate cleanly with:
- NPCManager (location-bound UI NPCs)
- ShopManager (inventory/pricing/restock/persistence)
- TimeManager (`day_started`, time-of-day)
- EventBus (`location_entered`, `location_exited`)

This addendum defines a **migration-safe path** from the current static shop model to **true roaming vendors (Option C)** without rewriting ShopManager.

---

## A1. Design Goals

1. **Roaming, not teleporting**: Wandering merchants appear at plausible location types over time (town, trading_post, caravan_camp, roadhouse).
2. **Deterministic**: Given a save + day number, results should be consistent.
3. **Non-invasive**: Economy v0 shop transactions remain unchanged; only shop *availability* changes.
4. **UI-compatible**: Merchants appear in the location NPC list like any other NPC with a `"shop"` service.
5. **Persistence first**: If a merchant was bought out yesterday, that depletion persists when they appear again.

---

## A2. Data Model Extensions

### A2.1 `shops.json` — add optional wandering fields

Add to specific shop entries:

```json
{
  "display_name": "Wayfarers' Circle Goods Wagon",
  "location_id": "caravan_camp",
  "buy_modifier": 1.2,
  "sell_modifier": 0.6,
  "inventory": { "...": {} },
  "buys": ["pelts", "scrap", "herbs"],

  "wandering": {
    "enabled": true,
    "spawn_location_types": ["town", "trading_post", "caravan_camp", "roadhouse"],
    "visit_duration_days": 2,
    "cooldown_days": 3,
    "spawn_chance_per_week": 0.75,
    "seed_key": "wayfarers_wagon"
  }
}
````

**Field semantics**

* `spawn_location_types`: allowed `location_id` values for placement (uses official location ids).
* `visit_duration_days`: how long the merchant stays once spawned.
* `cooldown_days`: minimum days before merchant can spawn again after leaving.
* `spawn_chance_per_week`: probability to appear in a given week (soft gating).
* `seed_key`: stable identifier to drive deterministic selection (defaults to shop_id if omitted).

> Note: `location_id` in the shop remains the “default/home” or “last-known” value and will not be relied on for wandering placement once enabled.

---

### A2.2 `npcs.json` — add an NPC record for the wandering merchant

The merchant is still exposed through the NPC system (UI entry point). Example:

```json
"merchant_wayfarers_wagon": {
  "display_name": "The Wayfarer",
  "title": "Wandering Merchant",
  "location_id": "caravan_camp",
  "services": ["shop", "dialogue"],
  "shop_id": "caravan_camp_wayfarer_goods",
  "schedule": { "available_times": ["morning", "afternoon", "evening"] },

  "wandering": {
    "enabled": true,
    "shop_id": "caravan_camp_wayfarer_goods"
  }
}
```

**Rule**

* The NPC’s `location_id` becomes *dynamic* (overridden by runtime placement).
* The NPC’s `shop_id` remains stable.

---

### A2.3 Save data — new wandering state (ShopManager-owned)

Extend ShopManager save state:

```json
{
  "shops": {
    "caravan_camp_wayfarer_goods": {
      "inventory": { "water": { "stock": 10 } },
      "last_restock_day": 8,

      "wandering_state": {
        "current_location_id": "town",
        "arrival_day": 15,
        "departure_day": 17,
        "last_departure_day": 17,
        "cooldown_until_day": 20,
        "active": true
      }
    }
  }
}
```

**Ownership**

* ShopManager owns wandering state because it is fundamentally about the shop’s availability/location.
* NPCManager reads wandering state to decide whether to surface the NPC at the current location.

---

## A3. Runtime Integration

### A3.1 Placement triggers

Wandering merchants are evaluated on:

* `EventBus.location_entered(location_data)`
* `EventBus.day_started(day)`

**High-level behavior**

* On `day_started`, ShopManager may spawn/move wandering shops based on week boundaries and cooldown rules.
* On `location_entered`, NPCManager queries ShopManager for wandering merchants *currently active* at that `location_id` and includes them in the NPC list.

---

## A4. Deterministic Spawn Logic (Recommended)

### A4.1 Week boundary

A “week” is 7 in-game days. Evaluate spawns on week start:

* Week start if `(day - 1) % 7 == 0`

### A4.2 Deterministic RNG

Use a deterministic PRNG seeded from:

* global world seed (if you have one) OR a stable fallback string
* `seed_key` (or shop_id)
* `current_week_index`

Example seed input:

```
seed = hash(world_seed + "|" + seed_key + "|" + str(week_index))
```

Then:

* If `randf() <= spawn_chance_per_week` and not in cooldown → spawn

### A4.3 Choose a destination

Destination selection is deterministic:

* Candidate set: `spawn_location_types`
* Pick one based on PRNG (uniform or weighted later)

---

## A5. NPCManager Changes (Implementation Instructions)

### A5.1 New query surface

Add to NPCManager:

* `get_wandering_npcs_at_location(location_id: String) -> Array[Dictionary]`
* Or integrate inside existing `get_npcs_at_location()` pipeline.

### A5.2 Location entry handling

NPCManager already detects location entry (per NPC doc v1). On `_on_player_entered_location(location_data)`:

1. Determine `location_id` from `location_data` (must be canonical).
2. Ask ShopManager for active wandering shops at that location:

   * `ShopManager.get_active_wandering_shops_at_location(location_id) -> Array[String]` returning shop_ids
3. Map each wandering shop_id to an NPC entry:

   * Either a predefined NPC id in `npcs.json` (`merchant_wayfarers_wagon`)
   * Or a “virtual NPC view model” generated by NPCManager (see A5.3)

### A5.3 Recommended approach: Virtual NPC view models (minimal schema impact)

To avoid many near-duplicate NPCs, allow NPCManager to create a **virtual NPC view model** for wandering merchants when they are present.

Virtual NPC fields:

* `npc_id`: stable (e.g., `"wandering::<shop_id>"`)
* `display_name`: from shop `display_name` or a `merchant_name` field
* `services`: `["shop"]` plus optional `dialogue`
* `shop_id`: shop_id
* `available`: true (unless time schedule gating is applied)
* `portrait_id`: optional (can be stored on shop or a merchant profile later)

This reduces authoring burden and keeps wandering merchants primarily economy-driven.

---

## A6. ShopManager Changes (Implementation Instructions)

### A6.1 New APIs

Add to ShopManager:

* `func is_shop_active_at_location(shop_id: String, location_id: String) -> bool`
* `func get_active_wandering_shops_at_location(location_id: String) -> Array[String]`
* `func advance_wandering_shops_on_day_started(day: int) -> void`

### A6.2 Day tick logic

On `day_started(day)`:

For each shop with `wandering.enabled`:

1. If currently active and `day >= departure_day`:

   * mark inactive
   * set `last_departure_day = day`
   * set `cooldown_until_day = day + cooldown_days`
2. If inactive and `day >= cooldown_until_day`:

   * if week start (or alternate cadence) → evaluate spawn chance
   * if spawn: choose destination location_id
   * set `arrival_day = day`
   * set `departure_day = day + visit_duration_days`
   * set `current_location_id = destination`
   * mark active

### A6.3 Weekly restock interaction

Weekly restock (Economy v0) should restock **all shops**, including wandering shops, regardless of active status. This keeps logic simple and predictable.

Optional rule (later):

* restock only when active (more simulation), but not required.

---

## A7. EventBus Wiring

### A7.1 Signals used (existing + economy)

* `location_entered(location_data: Dictionary)` (existing from NPC system plan)
* `day_started(day: int)` (existing)
* `shop_opened(shop_id: String)` (Economy)
* `shop_closed(shop_id: String)` (Economy)
* `shop_transaction_completed(shop_id: String, transaction: Dictionary)` (Economy)

No new EventBus signals are required for wandering merchants in v1 of this addendum, but you may add:

* `wandering_shop_spawned(shop_id: String, location_id: String, arrival_day: int, departure_day: int)`
* `wandering_shop_departed(shop_id: String, previous_location_id: String, departure_day: int)`

These are useful for debug and narrative hooks.

---

## A8. UI Behavior

### A8.1 NPC list presentation

When a wandering merchant is present:

* They appear in the NPC list with a shop button
* Optional flair tag: “Wandering” / “Caravan”
* Optional tooltip: “Here until Day X”

### A8.2 Shop panel

No changes. ShopPanel is driven purely by `shop_id`.

---

## A9. Testing Checklist

1. **Spawn determinism**

   * Same save seed + same week index → same merchant destination
2. **Cooldown enforcement**

   * Merchant does not reappear before `cooldown_until_day`
3. **Visit duration**

   * Merchant present only within `[arrival_day, departure_day)`
4. **Persistence**

   * Buy out stock, leave, advance time, return while merchant active → stock unchanged except restock rules
5. **Weekly restock**

   * On week boundary, verify stock increases by `restock_per_week` up to `max_stock`
6. **UI integration**

   * Merchant shows only at correct location_id
7. **Save/load**

   * Save mid-visit, reload, merchant remains present with correct departure day

---

## A10. Migration Notes

### From static “caravan camp wagon” to true wandering

* Mark the relevant shop as `wandering.enabled = true`
* Ensure ShopManager initializes `wandering_state` if missing
* Enable NPCManager wandering query integration

No schema breakage is required; existing shops remain valid.

---

## A11. Implementation Order

1. Add `wandering` blocks to one test shop in `shops.json`
2. Implement ShopManager wandering state + day tick
3. Add `get_active_wandering_shops_at_location(location_id)` API
4. Integrate into NPCManager `get_npcs_at_location()` results
5. Add debug logs / optional EventBus signals
6. Expand to additional wandering shops after validation


