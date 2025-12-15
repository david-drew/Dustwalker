
# Dustwalker NPC System – Design Document (v1)

## Status
Design-complete, implementation-ready  
Aligned with existing Dustwalker architecture (SaveManager provider pattern, TimeManager semantics, EventBus conventions)

---

## 1. Scope and Goals

### 1.1 Purpose
This document defines the **persistent NPC system** for Dustwalker. The system introduces **location-bound, data-driven NPCs** that persist across visits and saves, integrate with time-of-day logic, and expose services (dialogue, training, quests, trade) through UI rather than world-space actors.

### 1.2 Design Goals
- Single, authoritative NPC system consistent with existing Encounter and UI flows
- Deterministic behavior driven by data, time, and player state
- Clean persistence via the SaveManager provider pattern
- Clear separation of concerns between NPC identity, NPC state, and service logic
- Compatibility with existing TalentManager trainer functionality (Option 1)

### 1.3 Explicit Non-Goals (v1)
- Physical NPC actors on the map
- NPC pathfinding, roaming, or AI schedules
- NPC death or destruction
- Full economy simulation (vendors are placeholders/hooks)

---

## 2. Core Concepts and Terminology

### 2.1 NPC Definition (Static)
A **static JSON-defined identity** describing who an NPC is, where they belong, and what services they provide.

Examples:
- Name, title, portrait
- Location binding
- Available services (trainer, dialogue, trade, quest)
- Schedule constraints

### 2.2 NPC State (Persistent)
A **per-save mutable state** tracked by NPCManager and serialized through SaveManager.

Examples:
- Disposition / relationship
- Dialogue or quest flags
- Last interaction day
- Custom per-NPC flags

### 2.3 NPC Availability (Runtime)
A computed result that determines whether an NPC is currently interactable based on:
- TimeManager (time of day)
- NPC schedule rules
- Quest or reputation gates (future expansion)

---

## 3. High-Level Architecture

### 3.1 Primary System: NPCManager

**Responsibilities**
- Load NPC definitions from `data/npcs/npcs.json`
- Track and persist NPC state
- Resolve NPC availability
- Detect location entry
- Serve UI queries for NPC lists
- Emit NPC-related EventBus signals
- Route service interactions to other systems

**Godot Integration**
- Script: `scripts/systems/npc_manager.gd`
- Node group: `npc_manager`
- Implements `to_dict()` / `from_dict()` for SaveManager

---

## 4. Data Model

### 4.1 NPC Definition Schema (`data/npcs/npcs.json`)

```json
{
  "npcs": {
    "pete_gunsmith": {
      "display_name": "Old Pete",
      "title": "Master Gunsmith",
      "location_id": "tombstone",
      "services": ["trainer", "dialogue"],
      "portrait_id": "npc_pete",
      "trainer_id": "gunsmith_tombstone",
      "dialogue_id": "old_pete_intro",
      "schedule": {
        "available_times": ["morning", "afternoon", "evening"],
        "unavailable_reason": "Pete is working the forge."
      }
    }
  }
}
````

#### Field Ownership Rules

* `location_id` is canonical and must match location placement IDs
* NPC definitions own **display identity and placement**
* NPC definitions reference trainers via `trainer_id` (see 4.3)

---

### 4.2 NPC Persistent State Schema (Save Data)

Saved under a top-level NPCManager provider entry:

```json
{
  "npcs": {
    "pete_gunsmith": {
      "disposition": 50,
      "last_interaction_day": 5,
      "dialogue_state": {
        "intro_seen": true
      },
      "custom_flags": {}
    }
  }
}
```

#### Notes

* NPCs are assumed to exist unless otherwise specified
* No `alive` flag (NPC death not supported in v1)
* Schema is forward-extensible

---

### 4.3 Trainer Data (Option 1 – Selected)

Trainer definitions **remain in `talents_config.json`** and are owned by **TalentManager**.

Example:

```json
"trainers": {
  "gunsmith_tombstone": {
    "teaches": ["deadeye", "trick_shot", "quick_reload", "quick_draw"],
    "stat_requirements": {},
    "reputation_required": "neutral"
  }
}
```

#### Source-of-Truth Rules

* **NPC system owns**: identity, location, availability, UI presentation
* **TalentManager owns**: teachable talents, requirements, costs, training progress
* Fields like `name`, `title`, `location` inside trainer definitions are **non-authoritative**
* NPC definitions must reference trainers explicitly via `trainer_id`

---

## 5. Time and Availability

### 5.1 Time Integration

NPC availability is evaluated using `TimeManager.get_time_of_day()`.

Canonical time tokens (lowercase):

* late night
* dawn
* morning
* afternoon
* evening
* night

### 5.2 Availability Resolution Rules

1. If no schedule exists → NPC is always available
2. If current time is not in `available_times` → unavailable
3. Future gates may include:

   * Quest state
   * Reputation thresholds
   * Cooldowns

### 5.3 UI Behavior

Unavailable NPCs may:

* Be hidden entirely, or
* Appear disabled with `unavailable_reason` shown as tooltip/text

(Decision left to UI implementation; NPCManager exposes both states.)

---

## 6. Runtime Flow

### 6.1 Location Entry Detection

NPCManager listens to:

```gdscript
signal player_moved_to_hex(hex_coords: Vector2i)
```

Resolution flow:

1. Lookup HexCell
2. If `cell.location` exists:

   * Emit `location_entered(location_data)`
   * Cache current `location_id`

### 6.2 EventBus Signals (Additions)

```gdscript
signal location_entered(location_data: Dictionary)
signal location_exited(location_id: String)

signal npc_interaction_started(npc_id: String, npc_data: Dictionary)
signal npc_interaction_ended(npc_id: String)
```

### 6.3 NPC List Query

UI calls:

```gdscript
get_npcs_at_location(location_id: String) -> Array[Dictionary]
```

Returned entries include:

* display_name
* title
* portrait_id
* available (bool)
* unavailable_reason
* services (filtered by availability)

---

## 7. Services and Integration

### 7.1 Dialogue Service

* Routed to DialogueManager using `dialogue_id`
* NPC state tracks dialogue progress flags

### 7.2 Trainer Service

Flow:

1. NPC interaction → Trainer selected
2. TrainerPanel opens
3. TrainerPanel queries TalentManager via `trainer_id`
4. TalentManager handles:

   * Talent availability
   * Cost deduction
   * Training progress via TimeManager signals

NPC system does **not** track training state.

### 7.3 Quest Service

* NPC interaction triggers QuestManager hooks
* NPC state may store quest-related flags

### 7.4 Trade / Economy (Placeholder)

* NPC may expose `vendor_id`
* Routed to EconomyManager in future iterations

---

## 8. UI Integration

### 8.1 NPCPanel

* Spawned in `Main.gd` under MenuLayer
* Shown on `location_entered`
* Populated via NPCManager query

### 8.2 NPC Interaction Contract

NPCManager provides UI-safe data:

```json
{
  "npc_id": "pete_gunsmith",
  "display_name": "Old Pete",
  "title": "Master Gunsmith",
  "available": true,
  "services": [
    { "id": "trainer", "enabled": true },
    { "id": "dialogue", "enabled": true }
  ]
}
```

UI does not read raw JSON definitions directly.

---

## 9. Persistence and SaveManager Integration

### 9.1 Provider Requirements

NPCManager must:

* Add itself to group `npc_manager`
* Implement `to_dict()` returning NPC state
* Implement `from_dict(data)`

### 9.2 SaveManager Changes

* Include NPCManager in `_gather_save_data()`
* Restore NPC state in `_apply_save_data()`

NPC definitions are **not saved**, only NPC state.

---

## 10. Implementation Plan

### Phase 1 – Core System

* Implement NPCManager
* Load `npcs.json`
* Availability resolution
* Location entry detection
* Save/load integration

### Phase 2 – UI

* NPCPanel
* Interaction routing
* TrainerPanel hookup

### Phase 3 – Polish / Debug

* Optional NPC debug overlay (why unavailable)
* Validation checks (invalid location_id, missing trainer_id)

---

## 11. Future Extensions (Out of Scope)

* NPC roaming / multi-location schedules
* NPC death and replacement logic
* Dynamic vendor inventories
* Faction-based NPC behavior modifiers

---

## 12. Summary

This design introduces persistent, location-bound NPCs that:

* Respect Dustwalker’s existing systems
* Avoid duplication with TalentManager
* Use deterministic, data-driven logic
* Scale cleanly as services expand

The system is intentionally conservative in scope while laying the groundwork for future complexity without architectural rework.


