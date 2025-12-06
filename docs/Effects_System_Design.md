# Unified Effects System

## Overview

The Effects System provides a unified way to apply temporary and permanent modifiers to characters from any source: talents, diseases, poisons, weather, equipment, buffs, and status conditions.

## Core Concepts

### Effect
A named bundle of modifiers and triggers that can be applied to a character. Effects are defined in JSON and applied/removed through the EffectManager.

### Modifier
A numerical change to a stat, skill, or derived value. Can be flat (+2) or percentage (+20%).

### Trigger
An action that occurs when a specific game event happens while the effect is active.

### Stack
How multiple instances of the same effect combine (or don't).

---

## Effect Definition Schema

```json
{
  "id": "string",
  "name": "string",
  "description": "string",
  "type": "talent|disease|poison|environmental|buff|debuff|equipment|status",
  "category": "string (optional grouping)",
  
  "duration": {
    "type": "permanent|turns|days|instant",
    "value": 0
  },
  
  "stacking": {
    "mode": "none|replace|stack|refresh",
    "max_stacks": 1
  },
  
  "modifiers": [
    {
      "target": "stat|skill|derived|multiplier",
      "name": "grit|pistol|max_hp|thirst_rate",
      "type": "flat|percentage",
      "value": 0,
      "context": "optional situational limit"
    }
  ],
  
  "triggers": [
    {
      "event": "turn_start|combat_start|take_damage|etc",
      "action": "damage|heal|apply_effect|remove_effect|custom",
      "value": 0,
      "chance": 1.0
    }
  ],
  
  "conditions": {
    "requires": ["effect_id"],
    "blocks": ["effect_id"],
    "immunities": ["effect_id"]
  },
  
  "tags": ["supernatural", "physical", "mental", "removable"],
  
  "visuals": {
    "icon": "emoji or path",
    "color": "#RRGGBB",
    "priority": 0
  }
}
```

---

## Effect Types

### Talents (Permanent)
Special abilities that define character playstyle. Always active once acquired.

```json
{
  "id": "quick_draw",
  "name": "Quick Draw",
  "type": "talent",
  "duration": {"type": "permanent"},
  "modifiers": [
    {"target": "derived", "name": "draw_speed", "type": "flat", "value": 2}
  ],
  "triggers": [
    {"event": "duel_start", "action": "bonus_initiative", "value": 3}
  ]
}
```

### Diseases (Duration with Stages)
Progressive conditions with worsening effects over time.

```json
{
  "id": "swamp_fever_moderate",
  "name": "Swamp Fever (Moderate)",
  "type": "disease",
  "duration": {"type": "turns", "value": 12},
  "modifiers": [
    {"target": "stat", "name": "fortitude", "type": "flat", "value": -2},
    {"target": "stat", "name": "reflex", "type": "flat", "value": -1}
  ],
  "triggers": [
    {"event": "turn_start", "action": "damage", "value": 1, "chance": 0.25}
  ],
  "conditions": {
    "blocks": ["swamp_fever_mild", "swamp_fever_severe"]
  }
}
```

### Environmental (Context-Based)
Applied by weather, terrain, or location. Removed when conditions change.

```json
{
  "id": "cold_exposure",
  "name": "Cold Exposure",
  "type": "environmental",
  "duration": {"type": "permanent"},
  "modifiers": [
    {"target": "multiplier", "name": "fatigue_rate", "type": "flat", "value": 0.25}
  ],
  "triggers": [
    {"event": "turn_start", "action": "damage", "value": 1, "chance": 0.1}
  ],
  "tags": ["removable", "physical"]
}
```

### Buffs/Debuffs (Temporary)
Short-term effects from items, abilities, or actions.

```json
{
  "id": "stimulant_boost",
  "name": "Stimulant",
  "type": "buff",
  "duration": {"type": "turns", "value": 6},
  "modifiers": [
    {"target": "stat", "name": "reflex", "type": "flat", "value": 2},
    {"target": "stat", "name": "wit", "type": "flat", "value": 1}
  ],
  "conditions": {
    "blocks": ["stimulant_crash"]
  }
}

{
  "id": "stimulant_crash",
  "name": "Stimulant Crash",
  "type": "debuff",
  "duration": {"type": "turns", "value": 4},
  "modifiers": [
    {"target": "stat", "name": "reflex", "type": "flat", "value": -3},
    {"target": "derived", "name": "fatigue", "type": "flat", "value": 30}
  ]
}
```

### Equipment (While Equipped)
Bonuses from gear, removed when unequipped.

```json
{
  "id": "quality_revolver",
  "name": "Quality Revolver",
  "type": "equipment",
  "duration": {"type": "permanent"},
  "modifiers": [
    {"target": "skill", "name": "pistol", "type": "flat", "value": 1, "context": "equipped"}
  ]
}
```

---

## Modifier Targets

| Target | Examples | Description |
|--------|----------|-------------|
| `stat` | grit, reflex, charm | Core 8 stats |
| `skill` | pistol, tracking, persuasion | 18 skills |
| `derived` | max_hp, initiative, draw_speed | Calculated values |
| `multiplier` | thirst_rate, fatigue_rate, xp_rate | Rate modifiers |

---

## Trigger Events

| Event | When Fired |
|-------|------------|
| `turn_start` | Beginning of each turn |
| `turn_end` | End of each turn |
| `day_start` | Beginning of each day |
| `combat_start` | When combat begins |
| `combat_end` | When combat ends |
| `take_damage` | When character takes damage |
| `deal_damage` | When character deals damage |
| `kill` | When character kills an enemy |
| `rest` | When character rests |
| `eat` | When character eats |
| `drink` | When character drinks |
| `skill_use` | When a skill is used |
| `stat_check` | When a stat check is made |

---

## Trigger Actions

| Action | Effect |
|--------|--------|
| `damage` | Deal damage to character |
| `heal` | Restore HP |
| `apply_effect` | Apply another effect |
| `remove_effect` | Remove an effect |
| `add_fatigue` | Add fatigue points |
| `remove_fatigue` | Remove fatigue points |
| `grant_xp` | Grant skill XP |
| `bonus_initiative` | Add to initiative roll |
| `reroll` | Allow reroll of check |
| `custom` | Fire custom signal |

---

## Stacking Modes

| Mode | Behavior |
|------|----------|
| `none` | Cannot apply if already active |
| `replace` | Removes old, applies new |
| `stack` | Multiple instances stack (up to max) |
| `refresh` | Resets duration, keeps one instance |

---

## EffectManager API

```gdscript
# Core operations
apply_effect(target, effect_id, source: String = "") -> bool
remove_effect(target, effect_id) -> bool
remove_effects_by_source(target, source: String) -> int
remove_effects_by_type(target, type: String) -> int
has_effect(target, effect_id) -> bool

# Queries
get_active_effects(target) -> Array[Dictionary]
get_effects_by_type(target, type: String) -> Array[Dictionary]
get_total_modifier(target, modifier_target: String, modifier_name: String) -> float

# Duration management
tick_effects(target) -> void  # Called each turn
expire_effects(target) -> Array[String]  # Returns expired effect IDs

# Triggers
process_trigger(target, event: String, context: Dictionary = {}) -> void
```

---

## Integration Points

### PlayerStats
EffectManager pushes modifier totals to PlayerStats. PlayerStats no longer needs to track individual sources—it just receives the aggregated values.

### SurvivalManager
Instead of directly applying stat penalties, SurvivalManager applies named effects:
- `apply_effect(player, "fatigue_tired")` instead of manual modifier management
- Weather/temperature effects become standard effects

### DiseaseManager
Disease stages become effects:
- `apply_effect(player, "swamp_fever_mild")`
- Stage progression = remove old effect, apply new one

### WeatherManager
Weather conditions apply environmental effects:
- `apply_effect(player, "dust_storm_exposure")`
- Removed when weather clears

### Combat
Talents with combat triggers fire automatically:
- "Quick Draw" adds initiative on `combat_start`
- "Berserk Charge" activates on specific conditions

### Status Effect Display
Reads directly from EffectManager:
- `get_active_effects(player)` returns everything to display
- Consistent icons, colors, tooltips from effect definitions

---

## File Structure

```
data/
  effects/
    talents.json       # All talent definitions
    diseases.json      # Disease effects (replaces current diseases.json)
    environmental.json # Weather, terrain, exposure effects
    buffs.json         # Consumables, temporary boosts
    equipment.json     # Gear bonuses
    status.json        # Hunger, thirst, fatigue effects

scripts/
  systems/
    effect_manager.gd  # Core effect system
```

---

## Migration Path

### Phase 1: Build EffectManager
- Create EffectManager with core API
- Define effect JSON schema
- Load and validate effects

### Phase 2: Integrate with PlayerStats
- EffectManager calculates modifier totals
- PlayerStats receives aggregated modifiers
- Existing modifier system still works alongside

### Phase 3: Migrate SurvivalManager
- Convert fatigue levels to effects
- Convert hunger/thirst stages to effects
- SurvivalManager becomes thinner, delegates to EffectManager

### Phase 4: Migrate DiseaseManager
- Disease stages become effects
- DiseaseManager handles contraction/progression logic
- Effects handle the actual stat modifications

### Phase 5: Implement Talents
- Define talents as effects
- Add talent acquisition system
- Connect triggers to game events

---

## Example: Full Effect Lifecycle

1. Player enters swamp, contracts disease
2. DiseaseManager calls `effect_manager.apply_effect(player, "swamp_fever_mild")`
3. EffectManager loads effect definition, validates, stores
4. EffectManager recalculates modifiers, pushes to PlayerStats
5. StatusEffectDisplay reads from EffectManager, shows icon
6. Each turn, EffectManager calls `tick_effects()`, processes triggers
7. After duration, disease progresses to moderate stage
8. DiseaseManager calls `remove_effect("swamp_fever_mild")`, `apply_effect("swamp_fever_moderate")`
9. Player uses medicine
10. Medicine applies treatment, DiseaseManager calls `remove_effect("swamp_fever_moderate")`
11. EffectManager recalculates, pushes clean stats to PlayerStats
