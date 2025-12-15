
# NPC JSON Files: Changes, Notes, and TODOs


This document summarizes the current NPC JSON file split, schema conventions, and the remaining work required to fully integrate persistent NPCs (traders + general) into Dustwalker.


## 1. File Split and Purpose

### `res://data/npcs/npc_traders.json`
Holds NPCs that are directly coupled to the economy system:
- Must include: `services` containing `"trade"`
- Must include: `shop_id` (references `shops.json`)
- May include: `trade_dialogue_id`
- Typically have standardized schedules by shop type

### `res://data/npcs/npc_general.json`
Holds non-shop persistent NPCs used for:
- world texture (common and unusual characters)
- rumor sourcing
- quest initiation / quest progression

These NPCs do **not** reference `shop_id`.

---

## 2. Location Targeting: Type vs Instance

### Current approach
NPCs target **location types** via:
- `location_id`: one of: `town`, `fort`, `cave`, `trading_post`, `mission`, `caravan_camp`, `roadhouse`
- `placement.location_type`: duplicates type targeting explicitly (used by procgen)

### Future approach (procgen assignment)
At world generation time, NPCs will be assigned to **specific instances**, e.g.:
- Town instances: 3 named towns drawn from `town_names`
- Fort instances: names built from `fort_prefixes` + `fort_names`

**TODO:** Add an assignment output field (not authored by hand), e.g.:
- `assigned_location_instance_id` (or `assigned_location_ref`) generated at start-of-run and saved

---

## 3. Core NPC Schema Fields (v1)

### Common required fields (recommended)
- `display_name`: player-facing name
- `title`: short role label
- `description`: 1–2 sentence flavor
- `location_id`: location type (for now)
- `services`: array of strings (see below)
- `dialogue_id`: placeholder dialogue entry point
- `schedule`: availability gating by TimeManager

### Optional fields
- `rumor_dialogue_id`: placeholder dialogue entry for rumor interaction
- `trade_dialogue_id`: placeholder dialogue entry for trade interaction (trader NPCs)
- `quest_tags`: tags for quest matching/routing (quest NPCs)
- `rumor_topics`: topics for rumor matching/routing (rumor NPCs)

---

## 4. Services Convention

### Canonical service keys (current)
- `dialogue`: NPC can be spoken to
- `trade`: NPC exposes Shop UI (must have `shop_id`)
- `rumor`: NPC can provide rumors (topic-driven, see below)
- `quest`: NPC can offer/advance quests
- (future) `trainer`: NPC provides training (ties into `talents_config.json` trainers)

**Rule of thumb**
- Services tell the UI *what buttons to show*.
- Tags/topics tell systems *what content to surface*.

---

## 5. `quest_tags`: What They Are For

`quest_tags` are **metadata** that provide functionality beyond `services: ["quest"]` by enabling:
- Matching NPCs to quest templates (e.g., “escort”, “bounty”, “relics”)
- Controlling quest variety per location (avoid repeats)
- Applying gating (faction, difficulty, progression) later without rewriting NPC data
- Allowing content authoring to be declarative rather than hardcoded

### Recommended initial `quest_tags` vocabulary (seed set)
- `escort`, `delivery`, `investigation`, `bounty`, `retrieval`, `rescue`
- `relics`, `cave`, `omens`, `occult`, `smuggling`, `debt`
- `law`, `justice`, `politics`, `community_help`, `training_run`, `tracking`

**TODO:** Define canonical tag list (single source of truth) to prevent drift.

---

## 6. `rumor_topics`: What They Are For

`rumor_topics` enable a rumor system that:
- selects rumors from a pool by category
- varies rumors across NPC archetypes and locations
- supports later gating (reputation, time-of-day, discovered locations)

### Recommended initial `rumor_topics` vocabulary (seed set)
- `routes`, `safe_routes`, `ambushes`, `tracks`, `predators`, `prices`
- `outlaws`, `bounties`, `crime`, `missing_people`
- `relics`, `caves`, `omens`, `whispers`, `strange_lights`
- `town_politics`, `local_drama`, `secrets`, `black_market`, `rival_caravans`

**TODO:** Implement RumorManager or dialogue-side lookup keyed by `rumor_topics`.

---

## 7. Placement: `placement.weight` and Procgen

### Current fields
- `placement.location_type`: the location type to place into (mirrors `location_id`)
- `placement.weight`: relative selection weight for procgen assignment

### Intended behavior
For each generated location instance:
1. Determine desired NPC count for the instance (by type)
2. Sample from all NPCs matching `placement.location_type`
3. Use `placement.weight` as weighted probability
4. Apply constraints:
   - avoid duplicates of the same `npc_id` in one location instance
   - enforce minimum coverage rules where desired (see TODOs)

**TODO:** Define per-location-type NPC density (see section 10).

---

## 8. Schedules and TimeManager Integration

NPC schedules use time-of-day strings, intended to align with TimeManager outputs:
- `"Late Night"`, `"Dawn"`, `"Morning"`, `"Afternoon"`, `"Evening"`, `"Night"`

**Important:** Current NPC JSON uses lowercase tokens like `"late night"`.
**TODO:** Standardize schedule tokens to exactly match the TimeManager API:
- Option A (preferred): store canonical `TimeManager.get_time_of_day()` values exactly
- Option B: store normalized lowercase and normalize in code

**Recommended default schedules**
- Town / Trading Post: `Morning`, `Afternoon`, `Evening`
- Fort: `Morning`, `Afternoon`
- Mission: `Dawn`, `Morning`, `Afternoon`
- Roadhouse: `Evening`, `Night`, `Late Night`
- Cave (rare): `Night`, `Late Night`

---

## 9. Dialogue Hook Conventions (Placeholders)

Current placeholders follow:
- `dialogue_id`: `npc_<npc_id>_intro`
- `rumor_dialogue_id`: `npc_<npc_id>_rumors`
- `trade_dialogue_id`: `npc_<npc_id>_trade`

**TODO:** Confirm dialogue system’s ID schema and update generation rules if needed.

---

## 10. TODOs (Implementation + Content)

### Data / schema TODOs
- [ ] Rename prior trader NPC file to `npc_traders.json` and store in `res://data/npcs/`
- [ ] Save `npc_general.json` alongside it
- [ ] Standardize schedule token casing/format to match TimeManager
- [ ] Define canonical lists for `quest_tags` and `rumor_topics` to avoid drift
- [ ] Decide whether to add `rarity` (or rely purely on `placement.weight`)

### Procgen TODOs
- [ ] Implement NPC assignment step at world generation:
  - Assign NPCs to specific location instances
  - Persist assignments in SaveSystem
- [ ] Define NPC density targets per instance (initial medium map):
  - Town: 6–10 general + relevant traders
  - Fort: 4–7 general + quartermaster/doctor traders
  - Trading post: 4–7 general + traders
  - Roadhouse: 4–6 general + traders/fence
  - Mission: 3–6 general + mission supply trader
  - Caravan camp: 3–6 general + trader/wagon
  - Cave: 0–2 general (rare) + occult trader (very rare)

### Systems TODOs
- [ ] NPCManager: load and merge multiple NPC JSON sources
- [ ] NPCManager: filter by assigned instance OR (until then) by type + procgen assignment map
- [ ] NPC UI: show service buttons based on `services`
- [ ] Rumor pipeline:
  - either implement RumorManager keyed by `rumor_topics`
  - or implement dialogue-side rumor pools keyed by `rumor_topics`
- [ ] Quest pipeline:
  - implement QuestManager template selection using `quest_tags`
  - track per-NPC quest state in NPC persistence (`to_dict`/`from_dict`)

---

## 11. Recommended Guardrails

- Treat `services` as UI/interaction flags, not content routing.
- Treat `quest_tags` and `rumor_topics` as routing metadata (optional now, powerful later).
- Keep `npc_traders.json` and `npc_general.json` separate to avoid accidental coupling.
- Keep IDs stable; only add fields, do not rename keys casually (procgen + save compatibility).

---
