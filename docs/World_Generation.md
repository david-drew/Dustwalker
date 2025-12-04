
## WORLD GENERATION

### Map Generation Process

**Step 1: Terrain Generation**
- Create 30x30 to 40x40 hex grid
- Use Perlin/Simplex noise for elevation map
- Assign moisture levels (secondary noise layer)

**Terrain Assignment:**
```
High elevation + low moisture = Mountains
High elevation + high moisture = Forest Hills
Low elevation + low moisture = Desert
Low elevation + high moisture = Swamp
Medium elevation + medium moisture = Plains/Grassland
Medium elevation + low moisture = Badlands
Medium elevation + high moisture = Forest
```

**Step 2: Water Features**
- Generate 2-4 major rivers (flow from mountains to map edges)
- Create 3-6 lakes/ponds in appropriate locations (low elevation, high moisture)
- Mark water sources (springs in mountains, oases in desert)

**Step 3: Roads**
- Connect major locations with "main roads" (easier, faster travel)
- Generate trails between some minor locations
- Roads follow easier terrain when possible

**Step 4: Major Location Placement**

**Towns (3-5):**
- **Constraints:**
  - Must be near water source
  - Prefer flat terrain or gentle hills
  - At least 8-12 hexes apart from each other
  - Not in extreme terrain (not in mountains, swamps, or deep desert)
- **Generation:**
  - Name (procedural name generator with Western flavor)
  - Size (small: 200, medium: 500, large: 1000+)
  - Specialization (mining, farming, trade, garrison)
  - Starting faction alignment (Law, Corporate, Neutral)
  
**Forts (2-4):**
- **Constraints:**
  - Prefer high elevation (defensive)
  - Near strategic points (passes, river crossings, borders)
  - 10+ hexes apart
  - Not in swamps or extreme desert
- **Generation:**
  - Name (military naming: Fort [Name], [Name] Watch)
  - Size (outpost, fort, garrison)
  - Army faction alignment

**Settlements (8-12):**
- **Constraints:**
  - More flexible placement
  - Can be faction-specific (tribal village, mining camp, outlaw town)
  - Smaller population (20-200)
  - Some near resources (mines, forests, water)
- **Generation:**
  - Name
  - Type (farming, prospecting, tribal, outlaw)
  - Faction leaning

**Step 5: Special Locations**

**Mines (4-8):**
- Near mountains
- Types: Gold, silver, coal, gems
- States: Active (work available), Abandoned (danger + loot), Played out

**Ruins (3-6):**
- Ancient structures (pre-frontier)
- Hidden (require discovery)
- Supernatural elements possible
- Dangerous (traps, guardians, curses)

**Landmarks (5-10):**
- Natural formations (rock arches, peaks, canyons)
- Named features (Eagle's Peak, Devil's Throat)
- Navigation aids
- Possible secrets (caves, hidden paths)

**Hidden Locations (5-8):**
- Only discoverable through exploration or rumors
- Caches, hideouts, sacred sites, treasure vaults
- High-value content

**Step 6: Faction Territory Assignment**
- Create influence zones around major locations
- Army controls forts and surrounding hexes
- Gangs control certain badlands/forest regions
- Tribes control traditional territories
- Corporations control mining areas
- Territories can overlap (contested zones)

**Step 7: Initial Population**
- Place NPCs in locations
- Generate faction leaders, specialists, quest-givers
- Assign guards, merchants, doctors, etc.

### Narrative Generation

**Step 1: World Problem Selection**

Choose 1-2 major conflicts that define this playthrough:

**Possible Conflicts:**
- **Range War** - Cattle barons vs homesteaders (land dispute)
- **Gold Rush** - Mining boom brings chaos (lawlessness, claim jumping)
- **Tribal Conflict** - Encroachment on sacred lands (Army vs Tribe)
- **Railroad Expansion** - Progress vs tradition (Corporate vs Settlers/Tribe)
- **Supernatural Awakening** - Ancient evil stirring (Occult threat)
- **Outlaw Uprising** - Criminal gangs growing bold (Gang vs Law)
- **Political Corruption** - Lawmen on the take (Law + Corporate vs Settlers)
- **Plague/Disaster** - Natural catastrophe (disease, drought, locusts)

**Selected conflicts influence:**
- Encounter types
- Quest availability
- Faction relationships
- Random events

**Example:** "Railroad Expansion" selected
- Corporate faction aggressive, expanding
- Tribal faction hostile to Corporate, neutral to player at start
- Settlers divided (some support jobs, some oppose land-taking)
- Quests involve protecting/sabotaging railroad
- Encounters include corporate mercenaries, displaced tribes
- Dynamic: Railroad advances each week unless player intervenes

**Step 2: Key NPC Generation**

**For each major faction, create:**

**Leader:**
- Name, appearance, personality
- Goals (tied to world problem)
- Location (where they can be found)
- Quest-giver (main faction quests)
- Can become ally or enemy
- Examples: Sheriff Martinez, Chief Ironhawk, Crimson King

**Lieutenant:**
- Second-in-command
- Alternate contact if leader unavailable/dead
- Different personality than leader (conflict potential)
- Can betray leader or remain loyal

**Specialist:**
- Unique services (trainer, fence, informant, doctor)
- High skill in specific area
- Can teach talents or rare skills
- May be morally gray

**For world problem, create:**

**Antagonist (if applicable):**
- Drives the conflict
- Boss-level encounter possible
- Can be defeated, negotiated with, or joined
- Example: Railroad Baron Cyrus Kane

**Victim/Innocent:**
- Humanizes the conflict
- Quest-giver for moral side
- Can be saved or fail to save
- Example: Tribal elder whose village was destroyed

**Wildcard:**
- Unpredictable element
- May help or hinder
- Can change allegiances
- Example: Mysterious gunslinger with own agenda

**Each NPC gets:**
- Name
- Physical description
- Personality traits (3-4, e.g. brave, greedy, honest, cruel)
- Motivation (what do they want?)
- Relationships (allies, enemies, family)
- Location (town, fort, hideout)
- Schedule (moves between locations based on time/events)

**Step 3: Quest Chain Generation**

**Primary Objective (based on player choice):**

**Example - Revenge:**

**Act 1: Investigation (3-5 objectives)**
- Objective 1: Find witness in [Town A] (social encounter)
- Objective 2: Track gang to [Hideout 1] (exploration + combat)
- Objective 3: Interrogate captured gang member (social or intimidation)
- Objective 4: Discover gang's main hideout location (investigation)

**Act 2: Confrontation (4-6 objectives)**
- Objective 1: Hunt down gang lieutenant in [Location B] (combat)
- Objective 2: Infiltrate gang hideout OR turn gang against each other (player choice)
  - Path A: Stealth infiltration (stealth + combat)
  - Path B: Manipulation (social, plant evidence, divide gang)
- Objective 3: Defeat/recruit remaining gang members
- Objective 4: Locate gang leader's fortress

**Act 3: Resolution (climax)**
- Objective 1: Assault fortress or draw leader out
- Objective 2: Boss fight with gang leader
- **Endings:**
  - Kill leader (revenge complete, but hollow?)
  - Arrest leader (justice, but leader may escape/be rescued)
  - Spare leader (mercy, leader owes debt)
  - Join leader (betrayal, become outlaw yourself)

**Branching:** Player choices in Act 2 determine Act 3 approach

**Step 4: Dynamic Event Seeds**

Place 15-20 "event seeds" that trigger under certain conditions:

**Event Seed Example:**
```
SEED: "Town Siege"
LOCATION: Dustwater
TRIGGER: 30+ days passed AND player reputation with Settlers >25 AND Crimson Gang unchecked
DESCRIPTION: Crimson Gang attacks Dustwater
PLAYER OPTIONS:
  - Defend town (major combat, high reward)
  - Ignore (town may fall, reputation loss)
  - Negotiate (social, possible peace)
CONSEQUENCES:
  - Success: Town saved, hero status, Crimson Gang weakened
  - Failure: Town destroyed, survivors flee, new refugee camp created
  - Ignore: Town falls, Crimson Gang controls it, prices increase, lawlessness spreads
```

**Event Types:**
- Faction attacks
- Natural disasters
- NPC deaths (assassination, accident, old age)
- Economic booms/busts
- Disease outbreaks
- Supernatural manifestations
- Political shifts

**Seeds wait in background, activate when conditions met, world feels alive.**

**Step 5: Rumor Generation**

Create 30-50 rumors (mix of true, partially true, false):

**True Rumors (70%):**
- "Gold strike near Eagle Peak" (leads to active mine)
- "Crimson Gang hideout in Black Mesa" (accurate location)
- "Sacred spring in Whispering Canyon heals wounds" (true, supernatural)

**Partially True (20%):**
- "Treasure buried at Old Fort" (true, but location slightly wrong)
- "Five gang members at hideout" (true hideout, wrong number - actually 7)
- "Vampire in Deadwood" (true supernatural presence, but not vampire - werewolf)

**False (10%):**
- "Easy gold at Hangman's Gulch" (trap, ambush)
- "Sheriff Martinez is corrupt" (false, he's honest)
- "Rainbow Falls grants wishes" (myth, no supernatural effect)

**Rumor Distribution:**
- NPCs know 3-5 rumors each
- Rumors spread between NPCs over time
- Some rumors lead to quests
- Players must evaluate credibility

---

### Procedural vs Hand-Crafted Balance

**Procedural Elements:**
- Map layout
- Location placement
- NPC names and basic traits
- Quest objectives and locations
- Encounter types and timing
- Event triggers

**Hand-Crafted Templates:**
- Encounter archetypes (structure of bandit ambush, traveling merchant, etc.)
- Quest frameworks (delivery, bounty, escort patterns)
- NPC personality types
- Faction goals and conflicts
- Dialogue trees and options
- Combat scenarios

**Goal:** Procedural content that feels hand-crafted through smart templates and variation.

**Quality Control:**
- Test for impossible quests (generated objective in unreachable location)
- Ensure faction logic (don't generate Lawman quests for player with -75 Law reputation)
- Balance difficulty (early-game player doesn't get late-game threats)
- Narrative coherence (events should make sense given world state)

---

### Procedural Generation Concerns

**Seed System:**
- Each new game gets unique seed (or player-entered seed for sharing)
- Seed determines all procedural content
- Same seed = same world (for testing, sharing, challenges)

**Testing Procedural Content:**
- Test framework to generate 100s of worlds quickly
- Check for impossible quests, unreachable locations
- Balance passes (difficulty curves, resource availability)

**Iteration:**
- Allow designers to tweak templates without breaking saves
- Version procedural algorithms (save which version generated world)

**Quality Control:**
- Hand-test sample of generated worlds
- Automated tests for common failures
- Player feedback loop for edge cases
