
# Dustwalker - NPC Addendum


Splitting into **multiple NPC files is the correct move**.

### Recommendation (strong)

* Rename the existing file to **`npc_traders.json`**
* Create a new file: **`npc_general.json`**

This separation is not just organizational; it prevents future logic bleed:

* **Trader NPCs** are tightly coupled to `shop_id`, economy balance, and schedules
* **General NPCs** are about *world texture*: rumors, quests, social friction, strange encounters

Keeping them separate will make:

* Procgen placement simpler
* Quest authoring safer
* UI filtering easier (e.g., “Talk” vs “Trade”)

---

## Proposed structure for `npc_general.json`

These NPCs:

* Do **not** reference `shop_id`
* Use services like: `dialogue`, `rumor`, `quest`, `trainer` (later), `flavor`
* Are attached to **location types** (with weighted procgen placement), same as traders
* Can be common, unusual, or rare

### Core NPC archetype categories (v1)

For **each location type**, we’ll aim for:

1. **Common locals**

   * Present in most instances
   * Ground the location socially
   * Often rumor sources

2. **Unusual / interesting characters**

   * Memorable, slightly strange, or morally ambiguous
   * Often quest hooks or long-term NPCs

3. **Rumor-focused NPCs**

   * Explicitly tagged or serviced as rumor sources
   * Can gate information by time, reputation, or quest state later

4. **Quest-givers**

   * May overlap with unusual NPCs
   * Provide structured hooks into content systems

We do **not** need all four in every location instance—procgen weighting will handle density.

---

## Location-by-location NPC design plan

Below is the plan I recommend. If this looks right, I will generate the full `npc_general.json` next.

---

### 1. **Towns**

**Common**

* Laborer / ranch hand
* Town gossip
* Stablehand or courier
* Retired prospector

**Unusual**

* Failed preacher
* One-eyed surveyor obsessed with maps
* Widow who refuses to leave a burned house
* Former outlaw living quietly

**Rumor NPCs**

* Barber
* Laundress
* Bartender (non-trader version, if desired)

**Quest NPCs**

* Sheriff’s deputy (even if sheriff exists elsewhere)
* Land agent
* Desperate parent
* Town council member

Tone: lived-in, socially dense, morally mixed.

---

### 2. **Forts**

**Common**

* Guard on break
* Drill instructor
* Supply runner (non-trader)

**Unusual**

* Court-martialed officer
* Veteran with missing unit records
* Chaplain with doubts

**Rumor NPCs**

* Bored sentry
* Card-playing soldiers

**Quest NPCs**

* Intelligence officer
* Scout captain
* Prisoner liaison

Tone: rigid structure cracking under pressure.

---

### 3. **Trading Posts**

**Common**

* Caravan guard
* Freight clerk
* Drover

**Unusual**

* Disgraced merchant
* Interpreter who speaks too many languages
* Trader who refuses coin

**Rumor NPCs**

* Caravan gossip
* Route-planner

**Quest NPCs**

* Missing shipment agent
* Escort contractor
* Smuggling investigator

Tone: transient, transactional, information-heavy.

---

### 4. **Missions**

**Common**

* Caretaker
* Convert / penitent
* Groundskeeper

**Unusual**

* Visionary mystic
* Former outlaw seeking absolution
* Archivist guarding forbidden texts

**Rumor NPCs**

* Confessor
* Choir member

**Quest NPCs**

* Abbot / Abbess
* Pilgrimage guide
* Relic seeker

Tone: quiet tension, spiritual ambiguity.

---

### 5. **Caravan Camps**

**Common**

* Wagon driver
* Camp cook
* Animal handler

**Unusual**

* Star-reader
* Chronicler carving symbols into wheels
* Merchant who never speaks

**Rumor NPCs**

* Campfire storyteller
* Night watch

**Quest NPCs**

* Caravan leader
* Lost route seeker
* Rival caravan envoy

Tone: liminal, nomadic, fragile safety.

---

### 6. **Roadhouses**

**Common**

* Gambler
* Drifter
* Musician

**Unusual**

* Silent cardsharp
* Ex-lawman hiding in plain sight
* Performer with supernatural rumors

**Rumor NPCs**

* Bartender’s confidant
* Dice runner

**Quest NPCs**

* Fixer
* Debt collector
* Fugitive contact

Tone: volatile, information-rich, dangerous.

---

### 7. **Caves (rare NPCs)**

**Common**

* (Usually none)

**Unusual**

* Hermit
* Exile
* Relic guardian

**Rumor NPCs**

* Whispering presence
* Prisoner survivor

**Quest NPCs**

* Bound spirit
* Trapped explorer
* Cult remnant

Tone: uncanny, risky, memorable.

---

## Services to use in `npc_general.json`

Standardize on:

```json
"services": ["dialogue"]
```

Optional additions:

* `"rumor"` – NPC can surface rumor UI or dialogue pool
* `"quest"` – NPC can offer or advance quests
* `"trainer"` – future hook (no shop)
* `"flavor"` – no mechanics, pure narrative

NPCs may have multiple services.

---

## Next step (confirm before generation)

Before I generate `npc_general.json`, please confirm:

1. **Target size**

   * Small (~20 NPCs)
   * Medium (~35–40 NPCs) ← recommended
   * Large (60+)

2. **Dialogue IDs**

   * Placeholder IDs only (e.g., `npc_town_gossip_intro`)
   * Or omit dialogue IDs entirely for general NPCs

3. **Quest hooks**

   * Placeholder `quest_tags` / `quest_stub_id` fields allowed?
   * Or keep quests implicit via `"services": ["quest"]` only?

Once you answer those three, I will generate a **complete `npc_general.json`** that:

* Complements `npc_traders.json`
* Covers every location type
* Is immediately usable by NPCManager + procgen
* Is rich in tone without locking you into specific quest content too early
