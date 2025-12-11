# CLAUDE.md - Dustwalker Project Guide

## Project Overview

**Dustwalker** is a Weird West hex-based exploration/survival game built in Godot 4.5 using GDScript. The player travels across a procedurally-generated hex map, managing survival needs while encountering events, combat, and supernatural elements.

## Tech Stack

- **Engine:** Godot 4.5
- **Language:** GDScript (strictly typed where possible)
- **Data:** JSON for configs and definitions
- **Architecture:** Signal-based decoupled systems with EventBus autoload

## Project Structure

```






res://
│   project.godot
│   README.md
│   
├───.codex
│       AGENTS.md
│       config.toml
│       
├───assets
│   └───images
│       ├───actors
│       │       
│       ├───maps
│       │   │   
│       │   ├───locations
│       │   │       
│       │   └───terrain
│       │           
│       └───ui
│               
├───data
│   ├───character
│   │       backgrounds.json            # 8 playable backgrounds
│   │       skills_config.json
│   │       stats_config.json
│   │       talents_config.json
│   │       talent_effects.json
│   │       
│   ├───combat
│   │       enemies.json
│   │       weapons.json
│   │       
│   ├───effects                         # Effect definitions
│   │       status.json
│   │       talents.json
│   │       
│   ├───encounters
│   │       encounters.json
│   │       
│   ├───maps
│   │       default.json
│   │       fog_config.json
│   │       locations_config.json
│   │       movement_config.json
│   │       terrain_config.json
│   │       test_small.json
│   │       
│   ├───regions
│   │       
│   └───survival
│           diseases.json
│           survival_config.json
│           weather_config.json
│           
├───docs
│       Character_Progression_System.md
│       Character_System.md
│       Character_System_Addendum.md
│       Combat_Social.md
│       Combat_Systems.md
│       Concept_and_Game_Overview.md
│       Dustwalker_Overview.md
│       Effects_System_Design.md
│       Encounter_Design.md
│       Game_Loop.md
│       Map_and_Exploration.md
│       Mini-Game_Designs.md
│       Procedural_Event_Generation.md
│       Quest_System.md
│       Reputation_and_Factions.md
│       Sample_Character_Builds.md
│       Settings_and_Accessibility.md
│       Survival_Systems.md
│       Technical_Considerations_and_Appendices.md
│       Time_Management.md
│       UI_UX_Design.md
│       World_Generation.md
│       _docs_list.txt
│       
├───scenes
│   ├───actors
│   │       player.tscn
│   │       
│   ├───maps
│   │       main.tscn
│   │       
│   └───ui
│           character_creation_screen.tscn
│           launch_menu.tscn
│           settings_screen.tscn
│           
└───scripts
    │   game_manager.gd
    │   main.gd
    │   
    ├───actors
    │       character_creator.gd
    │       movement_controller.gd
    │       player.gd
    │       player_spawner.gd
    │       player_stats.gd                         # 8 core stats + modifiers
    │       skill_manager.gd                        # 18 skills, learn-by-doing XP
    │       talent_manager.gd                       # Talent acquisition
    │       
    ├───autoloads
    │       data_loader.gd
    │       effect_manager.gd                       # Unified effects (talents/status/diseases)
    │       event_bus.gd
    │       time_manager.gd
    │       
    ├───combat
    │       combatant.gd
    │       combat_ai.gd
    │       combat_camera.gd
    │       combat_manager.gd
    │       tactical_hex_cell.gd
    │       tactical_map.gd
    │       
    ├───maps
    │       fog_of_war_manager.gd
    │       hex_cell.gd
    │       hex_grid.gd
    │       hex_utils.gd
    │       location_placer.gd
    │       map_camera.gd
    │       map_serializer.gd
    │       map_tester.gd
    │       map_validator.gd
    │       river_generator.gd
    │       terrain_generator.gd
    │       
    ├───systems
    │       disease_manager.gd
    │       encounter_manager.gd
    │       environment_manager.gd
    │       inventory_manager.gd
    │       survival_manager.gd
    │       weather_manager.gd
    │       
    └───ui
            camp_panel.gd
            character_creation_screen.gd
            character_panel.gd
            combat_defeat_screen.gd
            combat_hud.gd
            combat_victory_screen.gd
            debug_display.gd
            encounter_window.gd
            floating_damage.gd
            game_over_screen.gd
            generation_panel.gd
            inventory_panel.gd
            launch_menu.gd
            settings_screen.gd
            status_effect_display.gd
            survival_panel.gd
            turn_panel.gd
 
```

## Core Systems

### Main.gd State Machine
Controls game flow: `LAUNCH_MENU → CHARACTER_CREATION → GAMEPLAY → SETTINGS`

### EventBus (Autoload)
Central signal hub. Systems communicate via EventBus signals rather than direct references.

Key signals:
- `turn_started(turn: int, day: int, time_name: String)`
- `player_spawned(hex_coords: Vector2i)`
- `stat_changed(stat_name: String, new_value: int, old_value: int)`
- `skill_level_changed(skill_name: String, new_level: int, old_level: int)`
- `encounter_triggered(encounter_data: Dictionary)`

### Player Structure
```
Player (Node2D)
├── PlayerStats (Node)      # Stats, modifiers
├── SkillManager (Node)     # Skills, XP
└── TalentManager (Node)    # Talents
```

### Character Stats (8 total)
grit, reflex, aim, wit, charm, fortitude, stealth, spirit

### GameManager
Orchestrates gameplay systems. Located at `/root/Main/System/GameManager`.
Key method: `initialize_game()` - called by Main when entering GAMEPLAY state.

### TimeManager
Tracks turns, days, time periods (dawn/morning/midday/afternoon/dusk/night).
Signal: `turn_started(turn: int, day: int, time_name: String)` - note third param is String, not int.

### SurvivalManager
Manages hunger, thirst, health, fatigue, temperature effects.

### EncounterManager
Handles random encounters, choice-based events, combat triggers.
Requires `encounter_window` to be set via `set_encounter_window()`.

### CombatManager
Turn-based tactical combat on hex grid with Combatant entities.

## Coding Conventions

### GDScript Style
```gdscript
# File header comment explaining purpose
# filename.gd
# Brief description of what this script does.
# Additional context if needed.

extends Node
class_name MyClass

# =============================================================================
# SIGNALS
# =============================================================================

signal something_happened(param: Type)

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var config_value: int = 10

# =============================================================================
# STATE
# =============================================================================

var _private_var: String = ""

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
    pass
```

### Naming
- Classes: `PascalCase`
- Functions/variables: `snake_case`
- Private members: `_prefixed`
- Constants: `UPPER_SNAKE_CASE`
- Signals: `past_tense_verb` (e.g., `moved_to_hex`, `damage_dealt`)

### Common Patterns

**Finding nodes by group:**
```gdscript
var player = get_tree().get_first_node_in_group("player")
```

**Emitting to EventBus:**
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

**Safe method calls:**
```gdscript
if node and node.has_method("some_method"):
    node.some_method()
```

## Scene Tree Structure

```
  /root 
    ┠╴EventBus
    ┠╴DataLoader
    ┠╴TimeManager
    ┠╴EffectManager
    ┃   
    ┖╴Main (Node2D, main.gd)
       ┠╴WorldEnvironment
       ┠╴HexGrid
       ┠╴Player (instanced, attached and spawned at runtime)
       ┠╴Systems
       ┃  ┠╴MovementController
       ┃  ┠╴PlayerSpawner
       ┃  ┠╴FogOfWarManager
       ┃  ┠╴SurvivalManager
       ┃  ┠╴InventoryManager
       ┃  ┠╴EncounterManager
       ┃  ┠╴GameManager
       ┃  ┠╴CombatManager
       ┃  ┠╴DiseaseManager
       ┃  ┖╴WeatherManager
       ┠╴MapCamera
       ┠╴EnvironmentManager
       ┃  ┠╴TimeOfDayOverlay
       ┃  ┖╴WeatherOverlay
       ┠╴UI
       ┃  ┠╴TurnPanel
       ┃  ┃  ┖╴Panel
       ┃  ┠╴SurvivalPanel
       ┃  ┃  ┖╴Panel
       ┃  ┠╴InventoryPanel
       ┃  ┠╴GenerationPanel
       ┃  ┃  ┠╴Backdrop
       ┃  ┃  ┖╴CenterContainer
       ┃  ┃     ┖╴Panel
       ┃  ┠╴EncounterWindow
       ┃  ┃  ┠╴Overlay
       ┃  ┃  ┖╴CenterContainer
       ┃  ┃     ┖╴Panel
       ┃  ┠╴GameOverScreen
       ┃  ┃  ┖╴RootControl
       ┃  ┃     ┠╴Overlay
       ┃  ┠╴CampPanel
       ┃  ┖╴StatusEffectDisplay
       ┠╴DebugDisplay
       ┃  ┖╴DebugPanel
       ┖╴MenuLayer (CanvasLayer, layer 100)
          ┠╴LaunchMenu
          ┠╴CharacterCreationScreen
          ┃  ┖╴CharacterCreator
          ┖╴SettingsScreen
```

## Common Issues & Solutions

### Signal type mismatches
Check that signal handlers match the signal's parameter types exactly. TimeManager's `turn_started` uses `String` for the third parameter (time_name), not `int`.

### Nodes not found
- Check paths are correct relative to the calling node
- Use groups and `get_first_node_in_group()` for flexibility
- Consider initialization order - use `call_deferred()` if needed

### UI not responding to clicks
- Check `mouse_filter` property on Control nodes
- Ensure CanvasLayer ordering is correct
- Verify `_input()` handlers call `get_viewport().set_input_as_handled()` appropriately

## Current Development Status

### Implemented
- Hex grid map with terrain, fog of war
- Player movement with turn costs
- Time system (turns, days, seasons)
- Survival (hunger, thirst, health, fatigue)
- Weather system
- Encounter system with choices
- Turn-based tactical combat
- Character stats (8 stats)
- Skill system (18 skills, learn-by-doing)
- Talent system
- Disease system
- Character creation with 8 backgrounds
- Launch menu, settings screen

### Next Steps
- Environmental hazards
- Melee and thrown weapons
- Save/load system integration
- Economy/trading

## Testing

Run the game and verify:
1. Launch menu appears on start
2. New Game → Character creation works
3. Character data applies (check with C key to open character panel)
4. Movement, encounters, combat function
5. Survival stats drain over time
6. ESC opens settings from gameplay
