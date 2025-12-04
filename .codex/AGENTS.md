# AGENTS.md (project root)

## Project overview

This repository is for the **Dustwalker** game.

Key design docs (Markdown):

- `docs/Character_System.md`
- `docs/Combat_Social.md`
- `docs/Combat_Systems.md`
- `docs/Concept_and_Game_Overview.md`
- `docs/Encounter_Design.md`
- `docs/Game_Loop.md`
- `docs/Map_and_Exploration.md`
- `docs/Mini-Game_Designs.md`
- `docs/Procedural_Event_Generation.md`
- `docs/Progression_System.md`
- `docs/Quest_System.md`
- `docs/Reputation_and_Factions.md`
- `docs/Sample_Character_Builds.md`
- `docs/Settings_and_Accessibility.md`
- `docs/Survival_Systems.md`
- `docs/Technical_Considerations_and_Appendices.md`
- `docs/Time_Management.md`
- `docs/UI_UX_Design.md`
- `docs/World_Generation.md`

### How to use these docs

Before making changes, especially to mission logic, vehicle behavior, or UI flows:

1. Skim the relevant doc(s).
2. Follow any invariants, terminology, and state diagrams.
3. If code diverges from the docs, propose doc updates instead of silently changing behavior.

### Coding preferences (project-specific)

- This project targets Godot 4.5 with GDScript.
- Don’t introduce ternary operators.
- Prefer small, well-named helper functions over long monoliths.
- Make scripts modular with simple, clean APIs and/or EventBus signals.
- When you’re unsure, ask and suggest options rather than guessing.
