
# Dustwalker RPG

## Technical Considerations & Appendices


## TABLE OF CONTENTS


1. [Technical Considerations](#technical-considerations)
2. [Appendices](#appendices)

---

## TECHNICAL CONSIDERATIONS

### Engine & Platform

**Engine:**
- **Godot** (version 4.5)

**Platform Targets:**
- **Primary:** PC (Windows, Mac, Linux via Steam)
- **Secondary:** Consoles (if successful, requires UI adaptation)
- **Mobile:** Not recommended (too complex for mobile UI)

### Performance Targets

**Map Size:**
- 30x30 (900 hexes) to 40x40 (1600 hexes)
- Keep in memory: Revealed map, fog of war, location data
- Stream content as needed (encounter details, NPC dialogue)

**Load Times:**
- World generation: <30 seconds (acceptable on new game)
- Save/load: <5 seconds
- Location transitions: <2 seconds
- Combat start: <3 seconds

**Memory:**
- Target: 2-4 GB RAM
- Procedural content = less asset storage needed
- Cache frequently used assets (common enemy types, terrain tiles)

### Save System

**Save Data Includes:**
- World state (map, locations, NPCs, factions)
- Player state (stats, skills, inventory, position, quests)
- Time and date
- Event flags (what's happened, what's available)
- Reputation values
- NPC states (alive/dead, location, relationships)

**Save File Size:**
- Estimated 5-20 MB per save (compressed)
- Text-based data (JSON or similar)
- Minimal binary (terrain maps)

**Cloud Saves:**
- Optional Steam Cloud integration
- Manual export/import for backup

**Corruption Prevention:**
- Write to temp file, then rename (atomic save)
- Keep 1-2 backup auto-saves
- Version checking (warn if save from different version)

### Mod Support (Future)

**Potential Modding:**
- Custom character backgrounds (JSON files)
- Custom encounters (template-based)
- Custom quests (scripting)
- Custom items/weapons (stats in config files)
- Cosmetic mods (portraits, terrain tiles)

**Tools:**
- Documentation for mod creators
- Example mods
- Steam Workshop integration (if on Steam)

---

## APPENDICES

### A. Glossary of Terms

- **AP (Action Points):** Points spent per turn to perform actions
- **Hex:** Hexagonal tile on map, unit of movement and area
- **Turn:** 4-hour in-game time block, 6 per day
- **Reputation:** Standing with a faction, -100 to +100 scale
- **Talent:** Rare special ability, 3-6 per playthrough
- **Fog of War:** Unexplored map areas, hidden until discovered
- **World Seed:** Number that determines procedural generation

### B. Weapon & Equipment Tables

(Detailed tables would go here showing all weapons with stats, all armor types, all consumables, etc. - For brevity, summarized earlier in document)

### C. Faction Summary Table

| Faction | Goals | Conflicts | Benefits | Starting Rep |
|---------|-------|-----------|----------|--------------|
| Law | Order, Justice | Outlaws, Corruption | Bounties, Protection | Neutral (0) |
| Army | Territory, Security | Tribes, Threats | Training, Contracts | Neutral (0) |
| Outlaws | Wealth, Freedom | Law, Army | Fence, Hideouts | Neutral (0) |
| Corporations | Profit, Expansion | Natives, Settlers | Jobs, Equipment | Neutral (0) |
| Tribes | Land, Autonomy | Army, Corporations | Wilderness Lore | Neutral (0) |
| Settlers | Safety, Prosperity | Bandits, Hardship | Trade, Shelter | Friendly (+10) |
| Church | Faith, Combat Evil | Supernatural, Vice | Healing, Sanctuary | Friendly (+10) |
| Occult | Power, Knowledge | Church, Fear | Magic, Rituals | Unknown (hidden) |

---

## CLOSING NOTES

This design document represents a comprehensive vision for a fantasy Wild West hex-crawl RPG. The game aims to blend:

- **Classic board game depth** (Barbarian Prince, Magic Realm, Mage Knight)
- **Modern procedural generation** (infinite replayability)
- **Survival tension** (resource management, environmental threats)
- **Tactical combat** (meaningful choices, multiple approaches)
- **Emergent storytelling** (player-driven narratives in reactive world)

**Core Philosophy:**
Every system should offer meaningful choices. Combat has multiple approaches (social, stealth, tactical, dueling). Quests have multiple solutions. Character builds enable different playstyles. The world reacts dynamically to player actions.

**Success Metrics:**
- High replayability (procedural generation + build diversity)
- Player stories (emergent narratives players share)
- Deep engagement (complex systems that reward mastery)
- Accessibility (tutorials, difficulty settings, clear feedback)

**Next Steps:**
1. Prototype core systems (movement, combat, survival)
2. Test procedural generation (ensure quality, balance)
3. Playtest vertical slice (gather feedback on feel and pacing)
4. Iterate based on feedback
5. Build toward alpha/beta/release

