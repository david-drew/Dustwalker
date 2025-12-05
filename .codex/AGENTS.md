# AGENTS.md (project root)

## Project overview

This repository is for the **Dustwalker** game.

Use these when making design-heavy changes:

- `Character_System.md` — attributes, advancement, build rules.
- `Combat_Systems.md` and `Combat_Social.md` — combat loops, action economy, and non-lethal/social conflict.
- `Quest_System.md` — quest structure, states, failure conditions.
- `Reputation_and_Factions.md` — faction standing, reputation math and effects.
- `World_Generation.md` and `Map_and_Exploration.md` — overworld generation, region types, hex-crawl rules.
- `Procedural_Event_Generation.md` — event tables, weighting, triggers.
- `Game_Loop.md` and `Time_Management.md` — core loop, turn/clock structure.
- `Survival_Systems.md` — hunger/thirst, weather, exhaustion, etc.
- `UI_UX_Design.md` and `Settings_and_Accessibility.md` — UI layout, flows, accessibility requirements.
- `Mini-Game_Designs.md` — mini-games used by encounters and events.
- `Progression_System.md` and `Sample_Character_Builds.md` — XP, unlocks, build examples.
- `Encounter_Design.md` — encounter templates & balancing.
- `Technical_Considerations_and_Appendices.md` — implementation notes, edge cases.

### How to use this folder

- Before changing **mechanics**, read the relevant system doc(s).
- Before changing **worldgen or map code**, read `World_Generation.md` and `Map_and_Exploration.md`.
- Before changing **UI**, read `UI_UX_Design.md` and `Settings_and_Accessibility.md`.

If code and docs disagree, prefer the docs and propose updates to code and/or docs.

### Coding preferences (project-specific)

- This project targets Godot 4.5 with GDScript.
- Don’t introduce ternary operators.
- Prefer small, well-named helper functions over long monoliths.
- Make scripts modular with simple, clean APIs and/or EventBus signals.
- When you’re unsure, ask and suggest options rather than guessing.
