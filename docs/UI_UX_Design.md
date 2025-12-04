
## UI/UX DESIGN

### Main Screen (Exploration View)

**Top Bar:**
- Time of day indicator (visual + text: "Turn 3 - Afternoon")
- Date (Day 45, Summer)
- Weather icon + condition (Sunny, Rainy, Storm Warning)

**Left Panel (Character Status):**
- **Portrait** (character image)
- **Health Bar** (HP: 15/18, color-coded)
- **Needs Indicators:**
  - Hunger (icon, bar, turns until penalty)
  - Thirst (icon, bar, turns until penalty)
  - Fatigue (icon, bar, sleep needed)
  - Temperature (icon if too hot/cold)
- **Status Effects:** (wounded, diseased, blessed, cursed, etc.)

**Right Panel (Quick Info):**
- Current location name
- Current hex terrain type
- Movement remaining this turn
- Quick inventory (weapon equipped, ammo count, rations, water)

**Center:**
- **Hex Map** (main view)
- Revealed areas visible
- Fog of war on unexplored
- Player token
- Location markers (towns, forts, quests)
- Encounter indicators (if detected via Stealth hint)

**Bottom Bar (Actions):**
- Action buttons (Move, Hunt, Forage, Camp, Search, etc.)
- Quick access to Menu, Inventory, Journal, Map

**Notifications:**
- Pop-up for events (encounter, discovery, quest update)
- Log of recent events (scrollable)

---

### Map Screen (Detailed)

**Full Map View:**
- Entire hex grid
- Toggle: Terrain, Locations, Factions, Quests
- **Zoom levels:** Full map, regional, local
- Player position marked
- **Markers:**
  - Towns (icon + name)
  - Forts (military icon)
  - Quest objectives (exclamation mark)
  - Discovered locations (various icons)
  - Player notes (custom markers)

**Legend:**
- Terrain types (color-coded)
- Location types (icon legend)
- Faction territories (shaded regions)

**Filters:**
- Show/hide specific markers
- Highlight roads
- Highlight water sources
- Highlight danger zones (high encounter rate)

**Distance Calculator:**
- Click two hexes → shows distance, estimated travel time
- Accounts for terrain, mounted status

**Notes System:**
- Right-click hex → add custom note
- "Water source here," "Ambushed by bandits," "Good hunting"
- Notes visible on map as icons

**Route Planning:**
- Click path → highlights route, shows total time
- Can save routes for reuse

---

### Inventory Screen

**Left Panel (Equipped):**
- Weapon slots (primary, secondary, melee)
- Armor/clothing
- Accessories (hat, boots, trinkets)

**Center (Backpack):**
- Grid or list view
- Items sorted by category (Weapons, Ammo, Food, Medicine, Misc)
- **Weight/Capacity:** Bar showing current load vs max
  - Overweight = movement penalties

**Right Panel (Details):**
- Selected item details
- Stats, effects, value
- Options: Use, Equip, Drop, Examine

**Filters:**
- Show: All, Weapons, Consumables, Quest Items, Valuables
- Sort: Name, Weight, Value, Type

**Horse Inventory:**
- Separate tab (if mounted)
- Additional capacity
- Can quick-swap items between player and horse

**Quick Slots:**
- 4-6 slots for fast access items (medicine, ammo, tools)
- Hotkeys assigned

---

### Journal Screen

**Quest Tab:**
- **Active Quests:**
  - Quest name
  - Objectives (checklist)
  - Time remaining (if applicable)
  - Reward listed
  - Notes
- **Completed Quests:** Archive
- **Failed Quests:** Archive (shows why failed)

**Rumors Tab:**
- Heard rumors (source, credibility, content)
- Can mark as "investigating" or "dismissed"
- Cross-reference with map (rumor location noted)

**NPC Relationships:**
- List of known NPCs
- Name, location, faction, relationship (friendly/neutral/hostile)
- Notes on interactions

**Lore/Discoveries:**
- Locations found
- Creatures encountered
- Historical information learned
- Supernatural knowledge

**Personal Notes:**
- Freeform text entry
- Player can write anything
- "Remember to buy ammo in Dustwater," "Avoid Crimson Gang territory"

---

### Character Sheet

**Stats Panel:**
- 8 core stats with current values
- Progress bars if training
- Hover for detailed info (what each stat affects)

**Skills Panel:**
- All skills listed
- Current level (0-5)
- XP progress to next level
- Hover for detailed info

**Talents Panel:**
- Unlocked talents
- Descriptions and effects
- Slots for future talents (grayed out)

**Faction Reputation:**
- List of factions
- Current reputation value + tier
- Visual bar (-100 to +100)
- Benefits at current tier listed

**Achievements/Milestones:**
- Combat stats (enemies killed, duels won)
- Exploration (hexes discovered, locations found)
- Social (quests completed, NPCs befriended)
- Survival (days survived, environmental challenges overcome)

**Biography:**
- Background chosen
- Major story events (auto-logged)
- Player-written notes

---

### Dialogue System

**Display:**
- NPC portrait (left or right)
- NPC name + faction affiliation
- Dialogue text (speech bubble or box)
- Player response options (numbered)

**Response Options:**
- **Standard dialogue:** 2-5 options
- **Skill checks visible:** "[Charm 3] Convince him..."
  - Green = likely success
  - Yellow = 50/50
  - Red = unlikely
- **Reputation-locked:** "[Liked with Settlers] Ask for favor" (grayed if not met)
- **Tone indicators:** (Friendly, Aggressive, Deceptive, Sarcastic)

**Branching:**
- Choices lead to different conversation paths
- Some choices close off others (can't be aggressive then friendly)
- Major choices highlighted (Warning: This may have consequences)

**Information Tracking:**
- Dialogue you've seen marked (grayed option: "Already asked about this")
- New dialogue highlighted (New!)

**Voice Acting (Optional):**
- Full voice, partial voice, or text-only (player setting)
- Important lines voiced, minor NPCs text

**Skip/Fast-Forward:**
- Can skip dialogue you've read
- Can fast-forward (hold button)

---

### Combat UI

**Tactical Mode:**

**Hex Grid:**
- Hex tiles with terrain
- Units (player, allies, enemies) clearly marked
- Cover indicators (shield icon)
- Line of sight (shading)

**Turn Order:**
- Initiative bar at top showing order
- Current actor highlighted

**Action Panel:**
- Available actions (Move, Shoot, Reload, etc.)
- AP cost listed for each
- Grayed out if can't afford

**Selected Enemy Info:**
- Hover over enemy → see HP, status, weapon
- Click → detailed panel (stats, abilities)

**Movement Range:**
- Click "Move" → hexes within range highlighted
- Different colors for normal (blue) vs difficult (yellow) terrain

**Attack Prediction:**
- Hover over enemy after selecting attack → shows hit chance, damage range
- Accounts for all modifiers

**Combat Log:**
- Scrolling text of actions ("You hit Bandit for 4 damage," "Bandit missed")

**Duel Mode:**

**Minimalist UI:**
- Crosshair
- Opponent visible
- Small indicators: Round counter, HP

**Draw Phase:**
- Visual cue (tumble weed, hand twitch)
- Timing indicator (bar or flash)

**Aim Phase:**
- Crosshair stability visual (shake, steadiness)
- No explicit hit chance (skill-based aiming)

**Result:**
- Hit/miss indicator
- Damage dealt
