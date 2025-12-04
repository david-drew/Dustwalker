
# Dustwalker Hex-Crawl RPG

## COMPLETE DESIGN DOCUMENT

**Version 1.0**

---

## TABLE OF CONTENTS

1. [Core Concept & Vision](#core-concept--vision)
2. [Game Overview](#game-overview)
3. [Core Game Loop](#core-game-loop)
4. [Character System](#character-system)
5. [Time Management & Actions](#time-management--actions)
6. [Survival Systems](#survival-systems)
7. [Map & Exploration](#map--exploration)
8. [Combat Systems](#combat-systems)
9. [Encounter Design](#encounter-design)
10. [Quest System](#quest-system)
11. [Progression Systems](#progression-systems)
12. [Reputation & Factions](#reputation--factions)
13. [World Generation](#world-generation)
14. [Mini-Games](#mini-games)
15. [UI/UX Design](#uiux-design)
16. [Technical Considerations](#technical-considerations)
17. [Appendices](#appendices)

---

## CORE CONCEPT & VISION

### High Concept
A single-player, procedurally generated RPG hex-crawl set in a fantasy Wild West, blending survival mechanics, tactical combat, and emergent storytelling. Players control a lone character navigating a dangerous frontier where supernatural elements lurk beneath the dusty surface.

### Design Pillars

1. **Meaningful Choice**
   - Every decision matters: route planning, resource management, dialogue options
   - Multiple solutions to problems (combat, stealth, social, creative)
   - Branching consequences that persist throughout playthrough

2. **Emergent Narrative**
   - Procedurally generated world with hand-crafted feel
   - Dynamic faction relationships respond to player actions
   - Stories emerge from gameplay, not just scripted events

3. **Survival Tension**
   - Resource scarcity creates constant planning pressure
   - Environmental hazards and needs drive exploration
   - Balance between pursuing objectives and staying alive

4. **Heroic Progression**
   - Start vulnerable, become competent (not superhuman)
   - Skill mastery feels earned through practice
   - Character growth enables new approaches to challenges

5. **Tactical Depth**
   - Combat rewards preparation, positioning, and smart play
   - Stealth and social options provide viable alternatives to violence
   - Information and planning are valuable resources

### Inspirations

**Board Games:**
- **Barbarian Prince / Drifter:** Event-driven hex exploration, resource management, solo play focus
- **Magic Realm:** Complex systems, hidden information, character variety, time pressure
- **Mage Knight:** Deck-building-style skill progression, scaling challenges, efficiency optimization

**Video Games:**
- **Classic RPGs:** Character builds, stat-based progression, emergent gameplay
- **Caves of Qud:** Procedural generation, rich systems interaction, depth over graphics
- **Roguelikes:** Permadeath options, procedural content, high replayability

### Target Experience

Players should feel like they're:
- **A wanderer** in a vast, uncaring frontier
- **A survivor** managing scarce resources against environmental threats
- **An explorer** discovering secrets and locations
- **A gunslinger** (or other archetype) whose skills define their approach
- **A participant** in a living world that changes with or without them
- **An author** of their own Western tale through emergent gameplay

---

## GAME OVERVIEW

### Genre & Platform
- **Genre:** Single-player tactical RPG / Survival / Hex-crawl
- **Platform:** PC (Windows/Mac/Linux)
- **Perspective:** Top-down hex map for exploration, first-person for duels, tactical isometric for combat
- **Art Style:** (TBD - could range from pixel art to illustrated to 3D low-poly)

### Core Gameplay
Players explore a procedurally generated regional map, managing their character's survival needs while pursuing objectives. Each game day is divided into six 4-hour turns, during which players choose actions (movement, hunting, social interaction, combat, etc.). The world responds dynamically to player choices and time passage.

### Key Features
- Procedurally generated 30x30 to 40x40 hex maps with unique locations
- 6-8 distinct character backgrounds with different starting abilities
- Dual combat systems: tactical turn-based and first-person dueling
- Survival management: food, water, sleep, temperature, disease
- Dynamic faction reputation system (7-8 factions)
- Skill-based progression through use
- Multiple resolution paths for encounters (combat/social/stealth/creative)
- Permadeath options with flexible save systems
- Procedural narrative with player-defined goals
- Supernatural elements (optional, toggle-able)
- 4-6 month typical playthrough (180-360 game days)

### Unique Selling Points
1. **Depth without overwhelm:** Complex systems that feel intuitive through clear feedback
2. **True replayability:** Procedural generation creates genuinely different experiences
3. **Build diversity:** Multiple viable character archetypes and playstyles
4. **Consequence persistence:** Actions have lasting effects on world state
5. **Respect for player time:** Clear information, no artificial padding, meaningful encounters

---

## CORE GAME LOOP

### Macro Loop (Full Playthrough)
```
1. Character Creation → Choose background, starting stats, primary objective
2. World Generation → Procedural map, factions, NPCs, quest chains created
3. Exploration Phase → Move through world, discover locations, gather resources
4. Encounter Resolution → Combat, social, discovery events
5. Progression → Gain skills, improve stats, acquire better equipment
6. Objective Pursuit → Complete quests, build reputation, pursue goals
7. Climax → Major confrontation or achievement of primary objective
8. Conclusion → Multiple possible endings based on choices and faction standings
```

### Mid Loop (Daily Cycle)
```
Day broken into 6 turns (4 hours each):
- Turn 1-2: Travel, exploration, morning activities
- Turn 3-4: Midday activities, hunting, social encounters
- Turn 5-6: Evening activities, camp setup, sleep (2 turns for optimal rest)

Each turn:
1. Choose major action (move, hunt, forage, social, rest, etc.)
2. Resolve any encounters triggered by location/action
3. Update needs (hunger, thirst, fatigue)
4. Check for environmental/story events
5. Update world state (faction movements, time-sensitive quests)
```

### Micro Loop (Encounter)
```
1. Encounter triggered (combat, social, discovery)
2. Player assesses situation (information gathering)
3. Player chooses approach (fight/talk/sneak/flee/creative)
4. Resolution mechanics execute (combat system, skill checks, etc.)
5. Outcome applied (loot, reputation change, quest progress, wounds)
6. World state updates (bodies remain, NPCs remember, consequences)
```

### Engagement Hooks
- **Short-term:** "Can I make it to the next town with my current supplies?"
- **Mid-term:** "How do I track down the next quest objective?"
- **Long-term:** "Can I achieve my character's ultimate goal?"
- **Emergent:** "What will I discover over that ridge?" / "How will this faction war play out?"

---

## CHARACTER SYSTEM

### Core Stats (8 Attributes)

Each stat ranges from 1-8, with 3 being trained/competent and 7-8 being heroic.

1. **GRIT**
   - Health pool, resistance to hardship, intimidation presence
   - Affects: HP (10 + Grit×2), pain tolerance, intimidation checks
   - Advancement: Survive deadly situations, endure hardship

2. **REFLEX**
   - Combat speed, dodging, quick-draw ability
   - Affects: Initiative, dodge chance, action points in tactical combat
   - Advancement: Frequent combat, agility training

3. **AIM**
   - Ranged accuracy, perception of distant objects
   - Affects: Hit chance with firearms, spotting distant features
   - Advancement: Successful shots, target practice

4. **WIT**
   - Problem-solving, learning speed, spotting deception
   - Affects: Skill learning rate, puzzle solving, reading situations
   - Advancement: Solving problems, learning new skills

5. **CHARM**
   - Persuasion, trading, information gathering
   - Affects: Dialogue options, prices, NPC reactions
   - Advancement: Successful social interactions

6. **FORTITUDE**
   - Disease resistance, poison resistance, fatigue resistance, environmental hazards
   - Affects: Illness saves, environmental damage reduction
   - Advancement: Surviving disease, enduring harsh conditions

7. **STEALTH**
   - Avoiding detection, ambush setup, quiet movement
   - Affects: Encounter avoidance, surprise rounds, theft
   - Advancement: Successful sneaking, undetected actions

8. **SURVIVAL**
   - Tracking, foraging, navigation, weather prediction
   - Affects: Hunting success, finding resources, reading terrain
   - Advancement: Successful wilderness activities

### Skills (Specific Applications)

Skills range from 0-5, where 0 is untrained and 5 is master level.

**Combat Skills:**
- Pistol (revolvers, handguns)
- Rifle (long arms, carbines)
- Shotgun (scatterguns)
- Blades (knives for melee and throwing)
- Axes (tomahawks, hatchets, melee and thrown)
- Brawling (unarmed combat, grappling)

**Survival Skills:**
- Tracking (following trails, identifying signs)
- Foraging (finding edible plants, herbs)
- Hunting (stalking game, field dressing)
- Medicine (treating wounds, curing disease)
- Horsemanship (riding, care, mounted combat)

**Social Skills:**
- Persuasion (convincing, negotiating)
- Intimidation (threatening, commanding)
- Deception (lying, disguise)
- Gambling (cards, dice, reading opponents)

**Utility Skills:**
- Lockpicking (opening locks, safes)
- Crafting (cooking, ammo making, repairs)
- Appraisal (identifying value, quality assessment)
- Lore (history, supernatural knowledge, cultural understanding)

**Skill Advancement:**
- Learn-by-doing system
- Each use grants 1-5 XP based on difficulty
- 100 XP per level, but higher levels require more uses:
  - Level 0→1: ~20 successful uses
  - Level 1→2: ~30 uses
  - Level 2→3: ~40 uses
  - Level 3→4: ~60 uses
  - Level 4→5: ~80 uses

### Talents (Unique Abilities)

Players acquire 3-6 talents over a full playthrough. These are rare, powerful, and define playstyle.

**Starting Talents** (1 from background):
Examples include "Quick Draw," "Pathfinder," "Keen Eye," "Silver Tongue"

**Purchased Talents** (2-3 possible):
- Require finding rare trainers
- Massive time and money investment
- Examples: "Deadeye," "Iron Stomach," "Covered Retreat"

**Story Talents** (1-2 awarded):
- Earned through major quest completion
- Player chooses from options matching playstyle
- Examples: "Voice of Command," "Beast Whisperer," "Lucky"

**Supernatural Talents** (0-2 possible, optional):
- Require supernatural encounters/training
- May have costs or drawbacks
- Examples: "Second Sight," "Spirit Guide," "Witch's Blessing"

**Social Combat Talents:**
- "Silver Tongue" - Social attacks cost 1 AP instead of 2
- "Cutting Words" - Mockery/Confusion last +1 turn, can target 2 enemies
- "Voice of Command" - Intimidate 3 enemies at once, Rally affects all visible allies
- "Poker Face" - Immune to enemy social attacks, can Bluff
- "Preacher's Fire" - Mass Rally + Demoralize unholy enemies
- "Savage Mockery" - Failed mockery doesn't enrage, critical mockery causes surrender

### Character Backgrounds (Archetypes)

Players choose one background at creation, which determines starting stats, skills, talents, and equipment.

#### 1. GUNSLINGER
- **High Stats:** Aim 4, Reflex 4
- **Starting Skills:** Pistol 2, Intimidation 1
- **Starting Talent:** "Quick Draw" (bonus to draw speed in duels)
- **Starting Equipment:** Quality revolver, leather duster, $75
- **Background Story:** Former lawman/outlaw/duelist with a reputation
- **Playstyle:** Combat-focused, dueling specialist, intimidation

#### 2. SCOUT
- **High Stats:** Survival 4, Stealth 3, Aim 3
- **Starting Skills:** Tracking 2, Rifle 1, Foraging 1
- **Starting Talent:** "Pathfinder" (reduced movement penalties in wilderness)
- **Starting Equipment:** Rifle, basic supplies, compass, quality horse, $50
- **Background Story:** Army scout, guide, trapper
- **Playstyle:** Exploration, stealth, wilderness survival

#### 3. PROSPECTOR
- **High Stats:** Fortitude 4, Wit 3
- **Starting Skills:** Appraisal 2, Survival 1, Pickaxe (Mining) 2
- **Starting Talent:** "Keen Eye" (better at finding valuables, hidden caches)
- **Starting Equipment:** Pick, pan, mule, maps, $100
- **Background Story:** Gold rush veteran, treasure hunter
- **Playstyle:** Exploration, resource gathering, wealth accumulation

#### 4. OUTLAW
- **High Stats:** Stealth 4, Grit 3, Reflex 3
- **Starting Skills:** Pistol 1, Lockpicking 1, Gambling 1, Deception 1
- **Starting Talent:** "Wanted" (higher rewards for criminal activity, but law is hostile)
- **Starting Equipment:** Stolen horse, multiple weapons, $150 ill-gotten gains
- **Background Story:** Bandit, rustler, robber
- **Playstyle:** Criminal activities, stealth, morally gray choices

#### 5. PREACHER
- **High Stats:** Charm 4, Wit 3, Fortitude 3
- **Starting Skills:** Persuasion 2, Medicine 1, Lore 1
- **Starting Talent:** "Voice of Authority" (bonus to social checks, Rally ability)
- **Starting Equipment:** Bible, medical supplies, modest clothing, $60
- **Background Story:** Circuit preacher, missionary, reformed sinner
- **Playstyle:** Social interactions, healing, moral choices, social combat

#### 6. DRIFTER
- **High Stats:** Balanced (all stats 2-3)
- **Starting Skills:** Pistol 1, Survival 1, Persuasion 1, Brawling 1
- **Starting Talent:** "Adaptable" (learns all skills 20% faster)
- **Starting Equipment:** Mixed basic gear, $80, may start on foot
- **Background Story:** Wanderer, no ties, mysterious past
- **Playstyle:** Jack-of-all-trades, flexible development

#### 7. NATIVE SCOUT
- **High Stats:** Survival 4, Stealth 3, Fortitude 3
- **Starting Skills:** Tracking 2, Bow 2, Herbalism 1, Lore (Tribal) 1
- **Starting Talent:** "Spirit Guide" (occasional supernatural insight, bonuses vs wildlife)
- **Starting Equipment:** Bow, traditional gear, cultural items, horse, $30
- **Background Story:** Tribal warrior, guide, caught between two worlds
- **Playstyle:** Wilderness expert, cultural mediator, supernatural connection

#### 8. OCCULTIST
- **High Stats:** Wit 4, Charm 3
- **Starting Skills:** Lore 2, Herbalism 1, Persuasion 1, Deception 1
- **Starting Talent:** "Second Sight" (detect supernatural, occasional visions)
- **Starting Equipment:** Ritual items, trinkets, strange tome, $70
- **Background Story:** Hedge witch, fortune teller, cursed bloodline
- **Playstyle:** Supernatural specialist, information gathering, unique solutions

### Character Progression Philosophy

**Early Game (Days 1-60):**
- Vulnerable, most encounters are dangerous
- Learning core skills (0→2)
- Acquiring basic equipment
- Establishing faction relationships

**Mid Game (Days 60-180):**
- Competent, can handle most standard threats
- Specializing skills (2→4 in chosen areas)
- Acquiring quality equipment
- Pursuing major objectives

**Late Game (Days 180-360+):**
- Formidable, feared or respected
- Mastering key skills (4→5)
- Acquiring legendary/unique equipment
- Resolving major story arcs

**Power Ceiling:**
A fully developed character should be able to:
- Defeat 5-10 standard enemies with preparation
- Survive most environmental hazards
- Handle one "boss" level encounter
- BUT still be threatened by overwhelming numbers or exceptional enemies
- Heroic, not superheroic

---

## TIME MANAGEMENT & ACTIONS

### Time Structure

**Day Division:**
- 6 turns per day
- Each turn = 4 hours
- Turn 1: Midnight-4am (late night)
- Turn 2: 4am-8am (dawn)
- Turn 3: 8am-Noon (morning)
- Turn 4: Noon-4pm (afternoon)
- Turn 5: 4pm-8pm (evening)
- Turn 6: 8pm-Midnight (night)

**Time of Day Effects:**
- **Night turns (1, 6):** Increased encounter danger, harder navigation, supernatural more common
- **Dawn/Dusk (2, 5):** Optimal hunting, temperature shifts, unique encounters
- **Day turns (3, 4):** Safest travel, best visibility, most NPCs active

### Major Actions (One per turn)

**Movement:**
- Move 1 hex (standard terrain, on foot)
- Move 2 hexes (mounted, good terrain)
- Difficult terrain: 2 turns per hex
- Roads: +1 hex movement bonus

**Survival:**
- Hunt (requires appropriate terrain)
- Forage (gather plants, find water)
- Set up/break camp
- Cook/craft/repair
- Rest/heal (dedicated recovery)

**Social/Location:**
- Trade/shop in settlement
- Gather information/rumors
- Accept/complete quests
- Train with teacher
- Gamble/socialize

**Exploration:**
- Search current hex thoroughly (reveal hidden features)
- Scout adjacent hexes (perception check without entering)
- Study map/plan route

### Minor Actions (One per turn, in addition to major action)

- Eat ration
- Drink water
- Quick conversation
- Check equipment
- Make simple decision
- Load/unload pack animal

### Interrupting Events

Some events consume your turn without player choice:
- Ambushes
- Severe weather (forced to seek shelter)
- Random encounters (if unavoidable)
- Story triggers

### Time Pressure Mechanics

**Quest Deadlines:**
- Some quests are time-sensitive (marked clearly)
- "Deliver medicine within 10 days"
- "Find the missing child before 5 days pass"
- Failure consequences range from reduced rewards to permanent quest failure

**Seasonal Changes:**
- Winter (Days 1-90 or 270-360, depending on start): Harsh survival, blocked passes
- Spring (Days 91-180): Flooding, mud, renewal
- Summer (Days 181-270): Drought risk, optimal travel
- Fall (Days 271-360): Harvest, preparation

**Faction Activities:**
- Factions pursue objectives on their own timelines
- Ignoring threats allows them to grow stronger
- "The Crimson Gang grows in power each week you don't stop them"

### Sleep System

**Optimal Sleep:** 2 consecutive turns (8 hours)
- Full fatigue recovery
- HP recovery (1-3 HP depending on conditions)
- Removes minor status effects

**Inadequate Sleep:**
- 1 turn (4 hours): 50% recovery, penalties remain
- 0 turns: Accumulating fatigue penalties

**Sleep Deprivation:**
- 1 night missed: -10% Perception, Reflex
- 2 nights missed: -20% Perception, Reflex, Wit, hallucination risk
- 3+ nights: Severe penalties, guaranteed hallucinations, health damage

**Sleep Quality Modifiers:**
- Bedroll + shelter + safe location: Best (bonus HP recovery)
- Bedroll + exposed: Normal
- No bedroll: 75% effectiveness
- Dangerous/uncomfortable: 50% effectiveness

---

## SURVIVAL SYSTEMS

### Food System

**Daily Requirement:** 1 ration per day

**Food Types:**
All convert to rations (0.5 or 1.0) under the hood, but named differently:

- **Trail Rations** (1.0) - $2-5 each, never spoils, compact
- **Fresh Meat** (1.0) - From hunting, spoils in 2-3 days
- **Preserved Food** (1.0) - Jerky, hardtack, canned goods, $1-3, lasts weeks
- **Foraged Food** (0.5) - Free but requires foraging action
- **Cooked Meals** (1.0) - Purchased in towns, $1-2, immediate consumption

**Game Animals:**
- Rabbit: 0.5 rations
- Turkey: 1.0 ration
- Deer: 3.0 rations
- Elk: 5.0 rations
- Buffalo: 8.0 rations (requires group or preservation)

**Hunger Stages:**
- **Well-Fed:** Normal stats
- **Peckish** (1 day missed): -5% to physical stats, minor discomfort
- **Hungry** (2 days): -10% physical, -5% mental
- **Starving** (3 days): -20% all stats, 1 HP loss per day
- **Near Death** (5 days): -40% all stats, 2 HP loss per day
- **Death** (7+ days without food)

**Food Preservation:**
- Smoking meat: Extends life to 7-10 days (requires tools, time)
- Salting: Permanent preservation (requires salt, expensive)
- Canning: Permanent (requires equipment, rare)

### Water System

**Requirement:** Every 4 turns (twice per day minimum)

**Water Sources:**
- Waterskin (holds 2-4 drinks, refillable)
- Rivers, streams, springs (free, must be at location)
- Wells (in settlements, free)
- Purchased water (towns, $0.50 per drink)
- Rain collection (during storms, free)
- Cactus/plants (foraging in desert, 0.5 drinks)

**Dehydration Stages:**
- **Hydrated:** Normal
- **Thirsty** (1 period missed): -10% Reflex, Fortitude
- **Parched** (2 periods): -20% physical, -10% mental, descriptions of dry mouth
- **Severe Dehydration** (3 periods): -40% all stats, 2 HP loss per period
- **Death** (5 periods)

**Environmental Modifiers:**
- **Desert/Summer:** Water consumption doubles
- **Cool/Winter:** Normal consumption
- **Heavy activity (combat, running):** +1 drink required

**Water Quality:**
- Clean (rivers in mountains, wells): Safe
- Questionable (stagnant, downstream): Fortitude save or disease
- Contaminated (obvious pollution): Guaranteed disease unless boiled

### Temperature & Weather

**Temperature Zones:**
- **Extreme Cold** (<20°F): Frostbite risk, 1 HP per turn exposed without proper gear
- **Cold** (20-40°F): Requires warm clothing, stamina drain
- **Comfortable** (40-80°F): No penalties
- **Hot** (80-100°F): Increased water consumption
- **Extreme Heat** (>100°F): Heat exhaustion risk, 1 HP per turn without shade/water

**Clothing/Gear Protection:**
- **Winter coat:** Protects to 0°F
- **Light clothing:** Comfortable range only
- **Desert gear:** Protects from heat to 110°F

**Weather Events:**

**Clear** (60% of days): Normal conditions

**Light Rain/Wind** (20%): 
- Minor visibility reduction
- Tracking becomes harder
- No major penalties

**Severe Weather** (15%):
- **Thunderstorm:** Forced to seek shelter or take 1d6 damage, visibility zero, flash flood risk in canyons
- **Blizzard:** Vision range 1 hex, movement halved, hypothermia risk, can get lost
- **Sandstorm:** Vision zero, movement impossible, must seek shelter
- **Tornado:** Extreme danger, evacuation event

**Extreme Weather** (5%):
- **Flash Flood:** If in canyon/riverbed, Reflex save or swept away (major damage/death)
- **Wildfire:** Smoke inhalation, burns, evacuation required
- **Hailstorm:** Damage to exposed characters and horses

**Weather Prediction:**
- High Survival skill: 1 turn warning of severe weather
- Cloud reading: Hints at coming conditions
- NPCs warn of seasonal patterns

### Disease & Injury

**Wounds (from combat, falls, accidents):**
- **Light Wounds** (1-3 HP): Heal naturally in 1-2 days
- **Serious Wounds** (4-6 HP): Require Medicine skill + supplies, 5-10 days recovery
- **Critical Wounds** (7+ HP): Risk of permanent penalties, need expert treatment, 15-30 days

**Wound Complications:**
- **Untreated wounds:** Daily Fortitude save or infection sets in
- **Infection:** +1 HP loss per day, fever (-20% all stats), requires medicine or death in 5-7 days
- **Blood loss:** Immediate HP loss continues without bandaging

**Diseases:**

**Common:**
- **Dysentery** (bad water/food): -10% stats, lasts 3-5 days, Medicine check or natural recovery
- **Fever** (exposure, infection): -15% stats, hallucinogenic effects, 5-7 days
- **Food Poisoning** (spoiled food): Vomiting, -20% stats for 1-2 days

**Serious:**
- **Cholera** (contaminated water): -30% stats, rapid dehydration, death in 3-5 days without treatment
- **Typhoid** (poor sanitation): Severe fever, -40% stats, weeks to recover or death
- **Plague** (rare, rats, fleas): Extremely dangerous, spreads to others, high mortality

**Supernatural:**
- **Lycanthropy** (werewolf bite): Transform at full moon, lose control
- **Vampire's Kiss** (vampire attack): Stat drain, light sensitivity, bloodlust
- **Curse** (supernatural encounter): Variable effects, requires ritual to cure

**Treatment:**
- **Medicine skill** checks determine success
- **Medical supplies** required (bandages, herbs, medicine bag)
- **Doctors** in towns can treat for fee ($10-50)
- **Herbalists/Shamans** can cure with rare ingredients

### Fatigue System

**Fatigue Sources:**
- Insufficient sleep
- Strenuous combat
- Extended travel without rest
- Environmental stress (heat, cold, altitude)

**Fatigue Levels:**
- **Rested:** Normal performance
- **Tired:** -10% Reflex, Aim
- **Exhausted:** -20% all physical stats
- **Collapsing:** -40% all stats, risk of passing out

**Recovery:**
- Good sleep (2 turns): Full recovery
- Rest action (dedicated): Recover 1 level
- Stimulants (coffee, drugs): Temporary +1 level, crash afterward

### Resource Management Strategies

**Efficient Travel:**
- Stock up in towns (buy rations in bulk when cheap)
- Hunt/forage along the way (supplementing, not replacing)
- Plan routes through water sources
- Cache supplies at known locations for return trips

**Emergency Measures:**
- Rationing (1 ration stretches to 2 days, with penalties)
- Risky foraging (try unknown plants, disease risk)
- Desperate hunting (attract predators)
- Eat horse (last resort, lose transportation)

**Weather Preparation:**
- Carry warm clothing even in summer (mountain passes)
- Extra water in desert regions
- Tent/shelter for storms
- Know safe havens (caves, abandoned buildings)

---

## MAP & EXPLORATION

### Map Structure

**Scale:**
- 30x30 to 40x40 hex grid
- Each hex = 5-10 miles across
- Total map area: ~225-400 square miles

**Hex Movement:**
- 1 turn to cross normal hex on foot
- 2 hexes per turn if mounted on good terrain
- Difficult terrain: 2 turns per hex (mountains, swamp)
- Roads: Bonus hex of movement

### Terrain Types

**1. Plains/Grassland** (25% of map)
- Easy travel (1 hex per turn, 2 if mounted)
- Moderate hunting (deer, buffalo possible)
- Exposed to weather
- Low encounter rate (30%)
- Resources: Grass for horses, occasional water

**2. Desert** (15%)
- Normal travel speed but harsh conditions
- Water extremely scarce
- Extreme temperatures (cold nights, hot days)
- Moderate encounter rate (35%) - often environmental
- Resources: Cacti (water), rare minerals, hidden oases
- Dangers: Dehydration, heat stroke, mirages, rattlesnakes

**3. Mountains** (15%)
- Slow travel (2 turns per hex)
- Excellent vantage points (can scout 3-5 hexes away)
- Cold temperatures, altitude effects
- High encounter rate (40%) - wildlife, bandits in passes
- Resources: Mines, caves, rare herbs, springs
- Dangers: Falls, avalanches, thin air, predators

**4. Forest** (20%)
- Normal travel speed
- Excellent hunting and foraging
- Cover from weather and detection
- High encounter rate (45%) - wildlife, outlaws, tribal
- Resources: Game, timber, medicinal plants, shelter
- Dangers: Predators, getting lost, ambushes

**5. Badlands/Canyons** (10%)
- Difficult navigation (confusing terrain)
- Flash flood risk
- Defensible positions
- High encounter rate (40%) - outlaws, ambushes
- Resources: Caves, hidden camps, minerals
- Dangers: Flash floods, dead ends, hostile territory

**6. Swamp** (5%)
- Very slow travel (2 turns per hex)
- Disease risk from water/insects
- Unique resources
- Moderate encounter rate (35%) - creatures, disease
- Resources: Rare herbs, fish, alligators (leather/meat)
- Dangers: Disease, poisonous creatures, quicksand, contaminated water

**7. Scrubland/Mixed** (10%)
- Moderate everything (transition terrain)
- Variable resources
- Normal encounter rate (35%)
- Acts as buffer between biomes

### Location Types

**Major Locations (Marked on map at start):**

**Towns (3-5):**
- Population: 200-2000
- Services: All (shops, quests, trainers, doctors, lawmen, saloons)
- Safe rest (inn, $2-5 per night)
- Multiple NPCs and quest hubs
- Faction headquarters possible
- Examples: "Dustwater," "Fort Steel," "Crimson Creek"

**Forts (2-4):**
- Military installations
- Services: Limited (armory, medical, quests)
- Army faction aligned
- Excellent defense during attacks
- Training opportunities
- Examples: "Fort Harrison," "Eagle's Watch"

**Minor Locations (Some marked, some discovered):**

**Settlements (8-12):**
- Population: 20-200
- Services: Basic (general store, maybe saloon)
- Local quests and rumors
- Safer rest than wilderness
- Examples: "Miller's Crossing," "Coyote Springs"

**Mines (4-8):**
- Active: Work opportunities, trade, danger (accidents, claim jumpers)
- Abandoned: Loot, danger (collapse, creatures, ghosts)
- Types: Gold, silver, coal, gemstones

**Homesteads (Scattered):**
- Isolated families
- Trade opportunities (fresh food)
- Unique encounters (help needed, hospitality, or hostility)
- Information about local area

**Camps (Procedural, Temporary):**
- Outlaw camps (hostile or negotiable)
- Tribal camps (depends on reputation)
- Prospector camps (trade, information)
- Military patrols (quests, supplies)

**Hidden Locations (Discovered only):**

**Ruins (3-6):**
- Ancient structures (pre-frontier)
- Supernatural elements possible
- Treasure/loot
- Dangerous (traps, curses, guardians)

**Landmarks (5-10):**
- Natural formations (Old Man Rock, Eagle's Peak)
- Navigation aids
- Scenic views (morale boost)
- Sometimes hiding spots or secrets

**Caches (Procedural):**
- Hidden stashes (perception to find)
- Outlaw loot
- Prospector supplies
- Quest items

### Discovery Mechanics

**Initial Visibility:**
- Major towns and forts: Visible from start
- Roads: Visible
- Everything else: Hidden until discovered or revealed

**Discovery Methods:**

**1. Exploration (entering adjacent hex):**
- Automatically discover obvious features
- Perception check for hidden features
- Higher Perception = see from farther away

**2. Rumors (NPCs tell you):**
- Vague: "Treasure in the Badlands" (5-10 hex search area)
- Moderate: "Old mine near Red Rock" (2-3 hexes)
- Specific: "Mine at base of Eagle Peak, three stones mark entrance" (exact hex)

**3. Maps (found or purchased):**
- Treasure maps (lead to specific caches)
- Regional maps (reveal terrain and some locations)
- Outlaw maps (hideout locations)

**4. Tracking (following NPCs/trails):**
- Follow tracks to camps or locations
- Blood trails to wounded prey/enemies
- Wagon ruts to settlements

**5. High ground (scouting):**
- From mountains/hills, can see 3-5 hexes in clear weather
- Perception check reveals distant locations
- Smoke, lights visible at night

**6. Information gathering:**
- Listening to conversations
- Reading newspapers
- Studying found documents

### Stealth and Encounter Awareness

**IMPORTANT MECHANIC:**

When entering a new hex, **Stealth and Perception checks occur BEFORE encounter triggers:**

**Check Process:**
1. Player enters hex
2. Stealth check (player's Stealth vs encounter's Perception)
3. If successful:
   - Player receives **hint** about encounter (not 100% accurate)
   - "You spot tracks suggesting 3-4 people ahead"
   - "You smell smoke and hear voices - possibly a camp"
   - "Fresh blood trail leads into the canyon"
4. Player chooses:
   - **Engage encounter** (proceed as normal)
   - **Avoid encounter** (circle around, costs extra time - 1 additional turn)
   - **Prepare first** (set up ambush, position advantageously)

**Benefits:**
- Rewards high Stealth investment
- Gives player agency (choose fights)
- Doesn't remove content (can still engage)
- Adds tactical layer (ambush opportunities)

**Hint Accuracy:**
- Low Perception: Vague hint, may be wrong about numbers/type
- High Perception: Accurate details, know exactly what you're facing
- Critical success: Perfect information + positioning advantage

### Fast Travel

**Not traditional fast travel, but shortcuts:**

**Roads:**
- Increase movement speed
- Safer (lower encounter rate)
- Connect major settlements

**Horses:**
- Double overland speed on good terrain
- Can push for extra movement (stamina cost)

**Known Routes:**
- Once you've traveled a path, navigation is easier
- Can mark "safe routes" on map
- Reduced chance of getting lost

**Guides:**
- Hire NPCs to lead you (costs money)
- They know shortcuts
- May reveal hidden locations

### Environmental Storytelling

**Abandoned Locations:**
- Burned homestead (bandit attack? Wildfire?)
- Massacred wagon train (investigation reveals story)
- Ghost towns (what happened here?)

**Evidence of Events:**
- Recent battlefields (bodies, shell casings, which factions?)
- Animal kill sites (predator type, danger level)
- Campsites (who was here, when, which way did they go?)

**Dynamic World:**
- Locations change over time (prosperity or decline)
- Your actions leave traces (bodies, structures you build)
- NPCs react to what you've done nearby

---

## COMBAT SYSTEMS

### Combat Initiation

**When Combat Triggers:**
- Player encounters hostile NPC/creature
- Player initiates against neutral/friendly target
- Ambush (random or scripted)
- Quest/story requirement

**Detection & Initiative:**

**Stealth Approach:**
- Before combat, Stealth vs enemy Perception check
- **Success:** Player gets hint and can choose to avoid OR set up ambush
- **Ambush advantage:** Surprise round, advantageous positioning
- **Failure:** Enemy aware, normal initiative

**Initiative Order:**
- Reflex stat + 1d6
- Surprise grants first action before normal initiative
- Modifiers: High ground (+2), readied weapon (+1), mounted (+1)

**Player Options When Detected:**
- **Engage** - Enter combat mode (Duel or Tactical)
- **Flee** - Opposed check (your Reflex/Horsemanship vs their pursuit), may trigger chase
- **Parley** - Attempt negotiation (Charm check, may fail into combat)
- **Draw** - Challenge to duel (1v1 or small group, enters Duel Mode)

### DUEL MODE (1v1 or Small Skirmishes)

**Triggers:**
- Player explicitly challenges someone
- Story-scripted duels
- Honor-based confrontations
- Small encounters (2v2, 3v3) if player chooses

**Visual:** First-person perspective

**Phases:**

#### STANCE PHASE (2-3 seconds)
- Both combatants face each other
- Subtle positioning (slight left/right movement)
- Tension builds
- **Social combat option:** Intimidation/Mockery (2 AP if in tactical)
  - Success: Opponent's draw window reduced
  - Failure: May enrage opponent (bonus to their draw)

#### DRAW PHASE (Reflex-based)
- Visual/audio cue signals draw (tumble weed, bell, opponent's twitch)
- Player must react (button press/mouse click)

**Timing Windows:**
- Reflex 1-2: 0.5 second window
- Reflex 3-4: 0.7 second window
- Reflex 5-6: 0.9 second window
- Reflex 7-8: 1.1 second window

**Quick Draw Talent:** +0.2s to window

**Results:**
- **Too early:** Misfire/fumble, opponent shoots first with bonus
- **Perfect timing:** You shoot first
- **Late:** Opponent shoots first
- **Too late:** Automatic loss

#### AIM PHASE (If you drew successfully)
- Crosshair appears over target
- Must align on opponent

**Crosshair Stability:**
- **Aim stat:** Higher = steadier crosshair
- **Fatigue:** Tired = shaky aim
- **Wounds:** Injured = severe shake
- **Alcohol/Drugs:** Can help or hurt (steady nerves vs impaired)
- **Pistol skill:** Reduces shake significantly

**Shot Resolution:**
- Hit location matters (head/torso/limbs)
- Damage: Weapon base + Aim bonus
- **Critical hits:** Headshot (instant kill possible), heart shot (massive damage)
- Enemy may fire simultaneously if close timing

#### POST-SHOT
- If both alive: Quick reload phase
- Reposition slightly (small movement)
- Can attempt to flee, surrender, or continue
- Repeat phases until resolution

**Duel Outcomes:**
- **Clean victory:** You shot first, they're down
- **Wounded victory:** Both hit, you survived
- **Draw:** Both wounded, mutual retreat/reload
- **Defeat:** You're wounded/killed (permadeath or recovery)

**Special Duel Mechanics:**
- **Trick Shots** (Pistol 4+): Shoot weapon from hand (disarm), shoot hat off (humiliate)
- **Environmental:** Shoot chandelier, lantern for advantage
- **Feinting:** Advanced technique (Deception + Pistol check)

**Duel Rewards:**
- Reputation boost (won honorable duel)
- Fear from witnesses (Intimidation bonus)
- Loot from opponent
- Quest completion possible

---

### TACTICAL MODE (Standard Combat)

**Triggers:**
- Multi-enemy combat (3+)
- Player chooses tactical over duel
- Ambushes
- Defensive scenarios

**Visual:** Isometric/top-down hex grid

**Map Generation:**
- Uses current hex terrain as template
- 15-25 hex tactical map
- Features: Cover (rocks, trees, buildings), elevation, obstacles
- Enemies positioned based on encounter type

#### TURN STRUCTURE

**Action Points (AP) per Turn:**
- Base: 4 AP
- Reflex 5+: +1 AP
- Reflex 7+: +2 AP total
- Wounded/Exhausted: -1 to -2 AP

**Action Costs:**
| Action | AP Cost | Notes |
|--------|---------|-------|
| Move 1 hex | 1 AP | Difficult terrain: 2 AP |
| Shoot pistol | 1 AP | Fast but less accurate |
| Shoot rifle | 2 AP | Slower but powerful |
| Shoot shotgun | 1 AP | Close range only |
| Reload pistol | 1 AP | 6 rounds |
| Reload rifle | 2 AP | Slower mechanism |
| Reload shotgun | 1 AP per shell | Tactical reloading |
| Melee attack (knife, fist) | 1 AP | Must be adjacent |
| Melee attack (axe) | 2 AP | Heavy swing |
| Throw weapon | 1 AP | Knife, tomahawk, dynamite |
| Take cover | 1 AP | Duck behind object or prone |
| Aim | 1 AP | +15% next shot |
| Use item | 1 AP | Potion, bandage, etc. |
| Overwatch | 2 AP | Reaction shot when enemy moves |
| Mount/Dismount | 2 AP | Horse interaction |
| Social attack | 2 AP | (1 AP with talent) |

#### MOVEMENT & POSITIONING

**Facing:**
- Characters have facing direction
- Attacks from behind/flanking: +20% to hit, +1 damage
- Can pivot freely (no AP cost)

**Cover System:**
- **Full Cover:** Behind solid object, -40% to be hit, must expose to shoot
- **Half Cover:** Crouched, partial barrier, -20% to be hit
- **Concealment:** Bushes, smoke, darkness, -10% to be hit, blocks line of sight
- **Prone:** +20% defense vs ranged, -20% vs melee, half movement

**Elevation:**
- Higher ground: +10% to hit, +1 damage, better visibility
- Shooting upward: -10% to hit
- High ground morale bonus

**Movement Types:**
- **Normal:** 1 hex = 1 AP
- **Difficult terrain:** 1 hex = 2 AP (rubble, stairs, water)
- **Mounted:** 2 hexes = 1 AP (open terrain only)
- **Crawl (prone):** 1 hex = 2 AP, maintains cover
- **Jump/Climb:** Special movement, Athletics check

#### COMBAT RESOLUTION

**Shooting Mechanics:**

**Base Hit Chance:**
```
Base % = (Aim × 10%) + (Weapon Skill × 5%)
Example: Aim 4, Pistol 2 = 40% + 10% = 50%
```

**Range Modifiers:**
- Point Blank (adjacent): +20%
- Short (2-4 hexes): +0%
- Medium (5-8 hexes): -10%
- Long (9-15 hexes): -25%
- Extreme (16+ hexes): -40% (rifles only)

**Situational Modifiers:**
- Cover (see above): -10% to -40%
- Target moving last turn: -10%
- Aimed shot: +15%
- Firing from horseback: -15% (unless Horsemanship 3+)
- Fatigue: -5% to -20%
- Wounds: -10% to -30%
- Darkness: -20% to -40%
- Smoke/Dust: -15%
- Target prone: +10% if close, -10% if distant

**Hit Location (Roll 1d6):**
1. **Legs** - 1x damage, target movement -1 hex per turn
2-4. **Torso** - 1x damage (standard)
5. **Arms** - 0.75x damage, may drop weapon (save), reduced accuracy (-10%)
6. **Head** - 1.5x damage, possible instant kill (Fortitude save)

**Damage:**
- Pistol: 2-3 base
- Rifle: 3-5 base
- Shotgun: 1-6 per pellet (up to 3 pellets hit at point blank, 1 at short)
- Knife (melee): 2-3
- Knife (thrown): 1-2
- Tomahawk (melee): 3-4
- Tomahawk (thrown): 2-4
- Two-handed axe: 4-6
- Fists: 1-2 (+Grit modifier)

**Armor Reduction:**
- Leather duster: -1 damage
- Metal vest: -2 to -3 damage (rare, expensive, -1 Reflex)
- Cover: Doesn't reduce damage, prevents hit

**Health & Wounds:**
- Total HP: 10 + (Grit × 2)
  - Example: Grit 4 = 18 HP
- **Light wound (1-2 HP):** Minimal penalties
- **Significant wound (3-5 HP):** -10% to physical actions, bleeding
- **Severe wound (6-10 HP):** -20% all actions, major bleeding, possible shock
- **Critical hit (10+ HP in one shot):** Fortitude save or instant incapacitation

#### MELEE COMBAT

**Knife (Melee):**
- 1 AP attack
- Silent (doesn't alert distant enemies)
- **Stealth kill:** If undetected, instant kill on unaware enemy (Stealth + Blades check)
- **Grapple follow-up:** After successful hit, can attempt grapple

**Tomahawk (Melee):**
- 2 AP heavy swing
- Higher damage than knife
- Can break light cover (wooden barriers)

**Two-Handed Axe:**
- 3 AP devastating swing
- Can hit multiple adjacent enemies (cleave)
- Breaks shields, doors, light cover
- Requires both hands (can't use pistol)

**Brawling (Fists):**
- 1 AP per punch
- Low damage but always available
- **Special techniques (unlocked by Brawling skill):**
  - **Shove (1 AP):** Push enemy back 1 hex, break engagement
  - **Block (1 AP):** Defensive stance, +20% dodge next attack
  - **Trip (2 AP):** Knock prone (opposed Grit check)
  - **Disarm (2 AP):** Remove weapon (opposed Reflex check)
  - **Grapple (2 AP):** Lock opponent, both immobilized
  - **Knockout (3 AP, Brawling 4+):** Attempt to stun/unconscious (Grit save)
  - **Dirty Fighting (Brawling 3+):** Sand in eyes, groin kick = debuff
  - **Counter (Brawling 5+):** When dodging melee, strike back (free action)

**Thrown Weapons:**
- **Knife:** 1 AP, short range, 1-2 damage, silent, retrievable
- **Tomahawk:** 1 AP, short-medium range, 2-4 damage, silent, retrievable
- **Dynamite:** 2 AP, medium range, 4-8 area damage, destroys cover, risky
- **Whiskey bottle:** 1 AP, short range, 1 damage + distraction, improvised

#### MOUNTED COMBAT

**Horse in Tactical:**
- Gives +2 movement range (can move 2 hexes for 1 AP)
- **Riding by:** Move through enemy hexes with attack (3 AP total)
- **Trampling:** If enemy in path, horse can attack them (2 damage)
- **Defense:** +10% harder to hit (you're moving target), but horse is huge target

**Horse as Target:**
- Horse has own HP pool (15-25 depending on quality)
- If horse killed, you're dismounted (fall damage 1d6)
- Wounded horse has reduced movement

**Shooting from Horseback:**
- Pistol: -15% accuracy (unless Horsemanship 3+)
- Rifle: -30% accuracy, very difficult
- Shotgun: -10% (close range helps)

**Tactical Uses:**
- **Rapid repositioning** (flank, retreat, charge)
- **Escape route** (if losing, can flee faster)
- **Intimidation** (cavalry charge is scary)
- **Cover** (dismount, use horse as cover - risky for horse)

#### SPECIAL ACTIONS & TALENTS

**Overwatch:**
- Cost: 2 AP
- Set up reaction shot
- When enemy enters line of sight/moves, you shoot (interrupt)
- Hit chance -10% (snap shot)
- Good for defending positions

**Suppressing Fire:**
- Cost: 3 AP + extra ammo
- Target area (3-hex cone)
- Enemies in area make Morale check or can't move next turn
- Wastes ammunition but denies enemy movement

**Talents in Tactical Combat:**

**"Deadeye"** (Aim 5+ required):
- Once per combat, guarantee hit on aimed shot
- Still roll for location and damage
- Costs 3 AP (1 to aim, 2 to shoot)

**"Covered Retreat"** (Stealth 3+ required):
- Disengage from melee without opportunity attack
- Can move and shoot in same turn (normally can't if engaged)

**"Berserk Charge"** (Grit 5+ required):
- Move up to 3 hexes + melee attack in one action (4 AP total)
- +2 damage on hit
- -10% defense until your next turn (reckless)

**"Trick Shot"** (Pistol 4+ required):
- Shoot weapon from hand (disarm, -20% to hit)
- Shoot specific object (rope, chandelier, explosive)
- Ricochet shot around cover (-30% to hit)

**"Quick Reload"** (Any firearm 3+ required):
- Reload costs -1 AP (pistol = free, rifle = 1 AP)

**"Combat Medic"** (Medicine 3+ required):
- Use bandage/medicine as minor action (no AP cost)
- Heal ally in adjacent hex

#### ENEMY AI & MORALE

**Enemy Difficulty Tiers:**

**Novice:**
- Stats 1-2
- Poor tactics (stands in open, wastes AP)
- Flees when wounded or allies die

**Standard:**
- Stats 2-3
- Uses cover, coordinated fire
- Flees when 50% casualties

**Veteran:**
- Stats 3-5
- Flanking, focus fire, tactical retreats
- Flees when outnumbered 3:1

**Elite:**
- Stats 5-7
- Advanced tactics, uses environment, supports allies
- Fights to death or tactical withdrawal only

**Boss:**
- Stats 6-8
- Unique abilities/talents
- May have minions
- Pre-combat dialogue possible

**Morale System (NPCs only):**

Enemies check morale when:
- Leader killed
- 50%+ casualties
- Flanked/surrounded
- Intimidated by player action
- Witnessed something terrifying (supernatural, explosive)

**Morale Check:**
- Roll vs Grit stat
- Success: Continue fighting
- Failure: Flee or surrender

**Morale Modifiers:**
- Outnumbered: -2 to check
- Leader alive: +2 to check
- Fanatic: Immune to morale
- Mercenary: -1 to check (not worth dying for)

#### ENVIRONMENTAL INTERACTIONS

**Destructible Cover:**
- Wooden barriers: 10 HP, can be shot through (-20% to hit)
- Stone walls: Indestructible to firearms, blocks line of sight
- Doors: 5 HP, can be broken (melee or shooting)
- Windows: Provides cover, can be shot through glass (breaks)

**Interactive Objects:**
- **Lanterns/Oil:** Shoot to create fire (area denial, damage over time)
- **Explosives (barrels):** 6-10 area damage, destroys nearby cover
- **Chandeliers:** Drop on enemies below (4 damage + knocked prone)
- **Rope:** Cut to drop objects, collapse structures

**Lighting:**
- **Bright:** No penalties
- **Dim (dusk/dawn):** -10% to hit at range
- **Dark:** -20% to hit, Stealth bonus +20%
- **Pitch black:** -40% to hit, can shoot out lights for advantage

**Weather in Combat:**
- **Rain:** -10% to hit (wet powder), harder to see
- **Wind:** Affects thrown weapons and long-range shots
- **Fog:** Heavy concealment, -30% to hit beyond short range
- **Thunderstorm:** Lightning flashes (temporary vision), deafening

---

### SOCIAL COMBAT (Optional Advanced System)

**Requirements:**
- Wit 3+ OR Charm 3+
- Specific talent (Silver Tongue, Cutting Words, etc.)
- Must share language with target
- Costs 2 AP (1 AP with talent)

**Social Attack Types:**

#### 1. INTIMIDATION (Grit + Charm)
*"I'm the one who killed the Crimson Gang. You're next."*
- **Effect:** Target becomes **Shaken** (-10% all actions, may flee)
- **Duration:** 2-3 turns
- **Check:** Your Charm + Reputation vs Target's Grit
- **Best vs:** Low Grit, those who know your reputation
- **Fails vs:** Fearless, language barrier

#### 2. MOCKERY (Wit)
*"With aim like that, you couldn't hit a barn!"*
- **Effect:** Target becomes **Flustered** (-15% Aim, -10% Reflex)
- **Duration:** 2 turns
- **Check:** Your Wit vs Target's Wit
- **Best vs:** Proud enemies, hot-tempered
- **Risk:** Failure causes **Enraged** (+20% damage, -20% accuracy, immune to social)

#### 3. DISTRACTION (Wit + Charm)
*"Is that the law behind you?"*
- **Effect:** Target **Distracted** (next attack +20% to hit them, lose 1 AP next turn)
- **Duration:** 1 turn (immediate)
- **Check:** Your Wit + Charm vs Target's Wit
- **Tactical:** Coordinate with allies (you distract, they shoot)

#### 4. DEMORALIZATION (Charm)
*"Your friends are dead. Give up."*
- **Effect:** **Demoralized** (-20% all actions, surrender likely)
- **Duration:** Rest of combat
- **Check:** Your Charm vs Target's Grit + morale
- **Best vs:** Wounded enemies, isolated
- **Fails vs:** Fanatics, nothing to lose

#### 5. RALLY (Charm - Allies)
*"We've got them on the run, boys!"*
- **Effect:** Allies **Rallied** (+10% all actions, +1 AP next turn)
- **Duration:** 2 turns
- **No check** if you're their leader
- **Range:** 3 hexes

#### 6. CONFUSION (Wit)
*"Which one of us killed your brother?"*
- **Effect:** **Confused** (50% chance wrong target or hesitate)
- **Duration:** 1-2 turns
- **Check:** Your Wit vs Target's Wit
- **Best in:** Multi-faction fights

#### 7. BARGAINING (Charm)
*"I'll pay you double to walk away."*
- **Effect:** Attempt to **Bribe/Convince** to disengage
- **Check:** Your Charm + money vs loyalty
- **Best vs:** Mercenaries, opportunists
- **Risk:** May demand more or refuse

**Enemy Social Attacks:**
Enemies can use these too:
- "You're all alone!"
- "I've killed better than you!"
- "Your god has abandoned you!"

**In Duel Mode:**
Social attacks during Stance Phase affect draw timing.

---

### COMBAT OUTCOMES

**Victory:**
- Loot corpses (weapons, ammo, money, quest items)
- Reputation change (depends on who you killed)
- Skill experience (weapons used, tactics employed)
- Potential wounds needing treatment
- May attract attention (bounty hunters, revenge)

**Defeat:**
- **Death:** Permadeath or reload (depending on settings)
- **Unconscious:** Wake later, robbed, possibly captured
  - **Captured scenarios:** Escape mission, ransom, execution countdown, press-ganged
- **Driven off:** Retreat wounded, lose equipment, world continues

**Wound Recovery:**
- Light: 1-2 days
- Serious: 5-10 days + medicine
- Critical: 15-30 days + expert treatment
- Untreated: Infection risk (daily Fortitude save)
- Permanent injuries possible (lost eye, limp, etc.)

**Post-Combat:**
- Retrieve thrown weapons (knives, tomahawks)
- Loot ammo (recover some spent bullets from corpses)
- Hide bodies (avoid attracting scavengers/law)
- Treat wounds immediately (prevent infection)
- Morale check (killing takes toll, especially innocents)

---

## ENCOUNTER DESIGN

### Encounter Frequency

**Hex Entry:** 30-40% base chance
- Modified by terrain (forest +10%, plains -5%)
- Modified by time (night +15%)
- Modified by player Stealth (can reduce by 5-20%)

**Stealth Check Process:**
1. Player enters hex
2. **Stealth check** (player's Stealth vs encounter's Perception)
3. **If successful:**
   - Player receives **hint** about encounter (accuracy depends on Perception)
   - Low Perception: "You hear something ahead"
   - High Perception: "You spot 3-4 armed men around a campfire, 50 yards north"
4. **Player chooses:**
   - **Engage** (proceed normally, possible ambush advantage)
   - **Avoid** (circle around, +1 turn travel time, no encounter)
   - **Prepare** (set ambush, advantageous position)

**Camping/Resting:** 10-20% per rest period
- Higher if no watch set
- Lower in safe locations (towns, forts)

**Specific Locations:** Guaranteed encounters
- Quest objectives
- Marked dangerous areas
- Story triggers

### Encounter Distribution

**Combat Encounters:** 40%
**Social Encounters:** 30%
**Discovery Encounters:** 20%
**Environmental Encounters:** 10%

### COMBAT ENCOUNTERS (40%)

#### Hostile NPCs

**Bandits/Outlaws** (Most common):
- **Number:** 2-6 enemies
- **Behavior:** Demand valuables, attack if refused
- **Tactics:** Standard tier, use cover, may flee if losing
- **Loot:** Weapons, ammo, stolen goods, possible bounty
- **Variations:**
  - Ambush (hidden, surprise round)
  - Highway robbery (demand toll)
  - Camp raid (attack your camp at night)

**Wildlife** (Terrain-dependent):
- **Wolves** (pack): 3-5, coordinated, flank, moderate danger
- **Bear** (solo): Very dangerous, high HP, powerful attack, territorial
- **Mountain Lion** (ambush): Solo, surprise attack, flees if wounded
- **Rattlesnake:** Environmental hazard, poison, low HP
- **Buffalo stampede:** Non-combat emergency, Reflex save or trampled

**Hostile Natives:**
- **War party:** 4-8, tactical, mounted, use bows and rifles
- **Territorial defenders:** 3-5, defensive positions, can parley
- **Scouts:** 1-2, stealthy, may flee to warn others
- **Depends on reputation:** Can become allies if reputation high

**Rival Factions:**
- **Law Enforcement** (if wanted): Marshals, deputies, try to arrest
- **Competing Gang:** Territorial dispute, resources
- **Corporate Mercenaries:** Hired guns, professional
- **Bounty Hunters** (if infamous): Well-equipped, determined

**Supernatural** (Rare, 5% of combat):
- **Werewolf:** Solo, very dangerous, requires silver, full moon
- **Vampire:** Night only, drains stats, regenerates, needs stake/sunlight
- **Possessed individual:** Unnatural strength, immunity to pain
- **Spirit/Ghost:** Non-physical, special rules, ritual needed

#### Encounter Variations

**Ambush:**
- Enemy gets surprise round
- Player in poor position (surrounded, low ground)
- Can be avoided with Perception check before entering hex
- Common in forest, canyons, badlands

**Siege:**
- Player defending location (camp, building, wagon)
- Waves of enemies
- Can prepare defenses beforehand
- Quest-related or random

**Rescue:**
- NPCs being attacked (innocents, allies)
- Player can intervene or ignore
- Time-sensitive (victims may die)
- Reputation consequences

**Duel Challenge:**
- Named NPC challenges player
- Honor-based, may be to first blood or death
- Reputation at stake
- Can refuse (cowardice penalty)

### SOCIAL ENCOUNTERS (30%)

#### Travelers

**Merchants:**
- **Interaction:** Trade opportunity, rumors, quest hooks
- **Options:** Buy/sell, gather information, hire as guard
- **Outcomes:** Economic, information gain, quest start

**Pilgrims/Settlers:**
- **Interaction:** Need help (escort, medical, supplies)
- **Options:** Help (good reputation), ignore, exploit
- **Outcomes:** Reputation change, possible reward, quest

**Fellow Adventurers:**
- **Interaction:** Potential ally or rival
- **Options:** Share info, team up temporarily, compete
- **Outcomes:** Ally NPC, competition for objective, duel

**Drifters/Wanderers:**
- **Interaction:** Stories, warnings, cryptic advice
- **Options:** Listen, trade, move on
- **Outcomes:** Information, item trade, atmosphere

#### Authority Figures

**Lawmen (Marshals, Sheriffs):**
- **Interaction:** Check for bounties, recruitment, warnings
- **Options:** Cooperate, lie, flee, bribe
- **Outcomes:** Quest, arrest if wanted, warning, ally

**Military Patrol:**
- **Interaction:** Similar to lawmen, faction-aligned
- **Options:** Report intelligence, seek protection, avoid
- **Outcomes:** Faction reputation, escort, restricted areas

#### NPCs in Distress

**Wounded Traveler:**
- **Interaction:** Needs medical help
- **Options:** Treat (Medicine check), mercy kill, rob, ignore
- **Outcomes:** Reputation, reward if saved, loot if robbed

**Attacked Caravan:**
- **Interaction:** Bandits attacking, can intervene
- **Options:** Help defend, wait for outcome, join bandits
- **Outcomes:** Combat, reputation, loot, ally/enemy

**Lost Person:**
- **Interaction:** Child or adult lost in wilderness
- **Options:** Guide back, ignore, exploit
- **Outcomes:** Reputation, reward, quest

#### Hostile Social

**Intimidation Attempt:**
- **Interaction:** NPC tries to bully/threaten you
- **Options:** Stand ground (Grit check), back down, fight
- **Outcomes:** Reputation gain/loss, combat, loss of resources

**Scam Artist:**
- **Interaction:** Con man tries to trick you
- **Options:** See through (Wit check), fall for it, turn tables
- **Outcomes:** Lose money, gain information, combat

**Territorial Dispute:**
- **Interaction:** NPC claims land/resource you want
- **Options:** Negotiate, intimidate, fight, concede
- **Outcomes:** Access to resource, combat, reputation

### DISCOVERY ENCOUNTERS (20%)

#### Locations

**Abandoned Camp:**
- **Discovery:** Perception check reveals details
- **Contents:** Supplies, equipment, clues to what happened
- **Dangers:** Trap, disease, lingering threat, ghost
- **Investigation:** Tracking/Wit checks reveal story

**Cache/Stash:**
- **Discovery:** High Perception or rumor-led
- **Contents:** Hidden supplies, treasure, quest item
- **Protection:** May be guarded, trapped, cursed
- **Ownership:** Taking may anger faction

**Natural Feature:**
- **Cave:** Shelter, possible occupant (bear, hermit, outlaw)
- **Spring/Water:** Mark on map, critical resource
- **Vantage Point:** Scout surrounding hexes (reveal map)
- **Rare Resource:** Medicinal herbs, minerals, unique items

#### Mysterious/Supernatural

**Standing Stones:**
- **Discovery:** Ancient monument
- **Interaction:** Lore check reveals meaning
- **Effects:** Possible supernatural occurrence, quest trigger
- **Atmosphere:** Eerie, builds world lore

**Grave Markers:**
- **Discovery:** Recent or old graves
- **Investigation:** Who died, how, when
- **Loot:** May contain valuables (moral choice)
- **Haunting:** Possible ghost encounter if desecrated

**Ritual Site:**
- **Discovery:** Evidence of occult activity
- **Clues:** Tracks, symbols, leftover materials
- **Danger:** May still be active, cursed
- **Quest:** Investigate cult, stop ritual

#### Clues & Information

**Tracks:**
- **Discovery:** Tracking check reveals details
- **Information:** Type (human, animal), number, age, direction
- **Follow:** Leads to encounter/location
- **Danger:** May lead into ambush

**Warning Markers:**
- **Discovery:** Signs, skulls, messages
- **Information:** "Turn back," "Plague," "Private property"
- **Decision:** Heed warning or proceed
- **Outcomes:** Avoid danger or find treasure/quest

**Message/Note:**
- **Discovery:** On corpse, in bottle, nailed to tree
- **Information:** Clue to quest, treasure map, final words
- **Quest Start:** May initiate side quest
- **Lore:** World-building, backstory

### ENVIRONMENTAL ENCOUNTERS (10%)

#### Weather Events

**Sudden Storm:**
- **Trigger:** Random or seasonal
- **Effect:** Must seek shelter or take damage
- **Duration:** 1-3 turns
- **Consequences:** Delayed travel, potential hypothermia

**Flash Flood:**
- **Trigger:** If in canyon/riverbed during storm
- **Effect:** Reflex save or swept away (major damage/death)
- **Warning:** High Survival skill gives 1 turn warning
- **Avoidance:** Climb to high ground

**Dust Storm/Sandstorm:**
- **Trigger:** Desert regions
- **Effect:** Zero visibility, can't move, must shelter
- **Duration:** 1-4 turns
- **Consequences:** Lost time, easy to get lost after

**Blizzard:**
- **Trigger:** Mountains, winter
- **Effect:** Vision 1 hex, movement halved, hypothermia
- **Duration:** 2-6 turns
- **Danger:** Can get disoriented, freeze to death

#### Natural Hazards

**Rockslide/Avalanche:**
- **Trigger:** Mountains, unstable terrain, loud noise
- **Effect:** Reflex save or take 2d6 damage, buried
- **Escape:** Grit save to dig out
- **Avoidance:** Survival check spots unstable area

**Quicksand/Mud:**
- **Trigger:** Swamp, riverbanks
- **Effect:** Stuck, sinking, Grit save to escape
- **Help:** Rope, ally assistance needed
- **Danger:** Drowning if can't escape

**Wildfire:**
- **Trigger:** Dry season, lightning, campfire accident
- **Effect:** Smoke inhalation, burns, evacuation needed
- **Spread:** Fire grows each turn, blocks hexes
- **Survival:** Must outrun or find river/cleared area

**Contaminated Water:**
- **Trigger:** Drinking from questionable source
- **Effect:** Fortitude save or disease
- **Identification:** Survival check reveals bad water
- **Prevention:** Boil water (takes time, requires fire)

#### Resource Opportunities

**Abundant Game:**
- **Trigger:** Good hunting hex, right season
- **Effect:** Hunting guaranteed success, bonus meat
- **Duration:** 1-2 days (game scatters after hunting)
- **Benefit:** Stock up on food

**Berry Patch:**
- **Trigger:** Forest, right season
- **Effect:** Foraging bonus, gather 2-3 rations worth
- **Duration:** Single use
- **Danger:** May attract bears

**Natural Shelter:**
- **Trigger:** Discovery in bad weather or exploration
- **Effect:** Free excellent rest, weather protection
- **Types:** Cave, overhang, abandoned cabin
- **Benefit:** Saves resources (no camp setup)

---

### Encounter Resolution Framework

**Multiple Paths Philosophy:**
Most encounters should offer 2-4 resolution methods:

**Example: Bandit Roadblock**

**Setup:** 3 bandits demand "Your money or your life!"

**Option 1 - Combat:**
- Attack immediately (tactical combat)
- Challenge leader to duel
- Ambush if they haven't seen you (Stealth)

**Option 2 - Intimidation:**
- "I'm the man who killed the Crimson Gang" (Charm + Reputation)
- Success: They flee
- Failure: Combat with angry enemies

**Option 3 - Persuasion:**
- "I'm broke, not worth your time" (Charm + Deception)
- Success: They let you pass
- Failure: Combat or forced to pay

**Option 4 - Bribery:**
- Pay them off ($10-30)
- Success: Peaceful resolution
- May gain info/assistance

**Option 5 - Evasion:**
- Noticed early via Stealth hint
- Circle around (+1 turn)
- Success: Avoid entirely

**Option 6 - Creative:**
- Lure them into environmental hazard
- Use animal call to spook horses
- Plant evidence of law nearby
- Player creativity rewarded

**Consequences:**
- Kill them: Bodies remain, reputation change, full loot
- Scare them: They remember, may return with help
- Pay them: Lose resources, they spread word (future targets)
- Evade: No loot, no reputation change, safe

---

### Procedural Event Generation

**World State Tracker** maintains:

**Faction Activities:**
- Territory control (expands/contracts)
- War/peace status (relations shift)
- Resource needs (create opportunities)

**Example:** Army at war with tribe
- More patrols
- Burned villages
- Refugees
- Supply contracts available
- Danger in contested areas

**Economic Cycles:**
- Boom/bust (mining towns)
- Shortages (drought = high food prices)
- Trade disruption (bandit activity)

**Example:** Gold strike at Lucky Gulch
- Population boom
- High supply prices
- Lawlessness increase
- Claim jumping conflicts
- Guard jobs available

**Seasonal Effects:**
- Winter: Harsh survival, blocked passes
- Spring: Flooding, mud, renewed trade
- Summer: Optimal travel, drought risk
- Fall: Harvest, preparation, migration

**Story Threads (3-5 active):**
- Track ongoing plots
- Evolve with or without player

**Example Thread:** "Crimson Gang Rising"
- Day 1: Rumor of gang forming
- Day 20: Rob bank (if unchecked)
- Day 40: Control town (if still unchecked)
- OR: Player defeats early, thread closes, new one begins

**Dynamic Response:**
World reacts to player actions:
- Kill gang leader → gang weakens or splinters
- Help settlers → town prospers, expands
- Ignore plague → spreads to more locations
- Broker peace → trade routes open

---

## QUEST SYSTEM

### Quest Types

#### MAIN QUESTS (Narrative Objectives)

Generated at game start based on character background and player's chosen primary goal.

**Primary Objectives (Player chooses one):**
1. **Revenge:** Track down those who wronged you
2. **Fortune:** Accumulate wealth ($10,000+)
3. **Redemption:** Clear your name / gain honor
4. **Exploration:** Discover legendary locations (8-10 sites)
5. **Power:** Control territory / lead faction
6. **Justice:** Bring law to lawless land
7. **Supernatural:** Solve/stop supernatural threat

**Structure:** 3-Act procedurally generated chain

**Example - Revenge Objective:**
- **Act 1:** Gather information (3-5 steps)
  - Talk to witnesses
  - Find hideouts
  - Discover gang members' identities
- **Act 2:** Hunt individuals (4-6 encounters)
  - Track each member
  - Defeat or convince to betray leader
  - Uncover leader's location
- **Act 3:** Final confrontation
  - Locate stronghold
  - Boss encounter with leader
  - Multiple endings (kill, arrest, spare, recruit)

**Goal Reset Mechanic:**
- 2-3 times per playthrough, at narrative inflection points
- Player can pivot primary objective
- Framed as "Revelation" or "Change of Heart"
- Gated behind significant story beats

**Example:** Started with Fortune, but:
- Discovered murdered family (Revenge becomes available)
- Gained reputation as hero (Justice becomes available)
- Encountered supernatural evil (Supernatural becomes available)

#### FACTION QUESTS (Reputation Builders)

**Delivery Jobs:**
- Transport goods from A to B
- Risk of bandits, weather, spoilage
- Time-sensitive optional (bonus pay)
- Reward: $20-100, +10-25 reputation

**Bounty Hunting:**
- Track and eliminate/capture target
- Dead or alive (alive pays more)
- Difficulty varies (novice outlaw to veteran gunslinger)
- Reward: $50-500, +15-40 reputation

**Escort Missions:**
- Protect NPC during travel (3-10 hexes)
- Encounters guaranteed
- NPC can die (quest failure)
- Reward: $30-150, +20-35 reputation

**Investigation:**
- Gather information about threats
- Use Perception, Wit, social skills
- May lead to combat encounter
- Reward: $25-75, +15-30 reputation, information

**Sabotage:**
- Undermine rival faction
- Morally gray (may hurt innocents)
- Stealth-focused
- Reward: $40-200, +25-50 one faction, -30-60 another

**Defense:**
- Protect location from attack
- Siege combat
- Can prepare defenses
- Reward: $50-300, +30-60 reputation

**Procedural Generation Template:**
```
Quest: [Action] [Subject] from [Location A] to [Location B], threatened by [Enemy Type]
Filled: Escort merchant from Dustwater to Fort Steel, threatened by Crimson Gang
```

#### SIDE QUESTS (Organic Discoveries)

**Sources:**
- Overheard in saloon
- Note on corpse
- Plea from settler
- Mysterious map fragment
- Rumor from NPC

**Examples:**

**Treasure Hunt:**
- "Find the Lost Dutchman Mine"
- Clues scattered across map
- Multiple false leads
- Dangerous final location
- Reward: Wealth, unique item

**Pest Control:**
- "Clear wolves from Miller's Ranch"
- Combat-focused
- Time-sensitive (wolves attack livestock)
- Reward: Money, meat, grateful ally

**Humanitarian:**
- "Deliver medicine to sick child in Coyote Springs"
- Time-sensitive (child's condition worsens)
- Moral weight
- Reward: Gratitude, reputation, possible discount

**Investigation:**
- "Investigate haunting at Old Mission"
- Supernatural element
- Clue-gathering
- Combat or ritual resolution
- Reward: Loot, supernatural knowledge

#### DYNAMIC QUESTS (World-Responsive)

Generated in response to world events:

**Siege Defense:**
- Town under attack (faction war)
- Help defend or ignore
- Major combat encounter
- Reward: Hero status, loot, reputation

**Medical Emergency:**
- Disease outbreak
- Need to transport medicine
- Race against time
- Reward: Lives saved, reputation

**Evacuation:**
- Wildfire/flood threatening settlement
- Escort civilians to safety
- Environmental hazards
- Reward: Gratitude, possible new settlement location

**Assassination Plot:**
- Faction leader targeted
- Protect or allow (or assist assassins)
- Major story impact
- Reward: Varies by choice

### Quest Mechanics

**Acceptance:**
- Can have 5-10 active quests
- Journal tracks all
- Some time-sensitive (countdown visible in journal)
- Can abandon (possible reputation loss)

**Tracking:**
- **Journal:** Text description, objectives, notes
- **Map Markers:** Known locations highlighted
- **Rumor System:** Additional clues over time

**Time-Sensitive Quests:**
- Clear countdown in journal
- "Deliver medicine: 7 days remaining"
- Failure states clearly defined
- Not all quests are timed (optional pressure)

**Rewards:**

**Money:**
- Scales with difficulty
- Varies by faction wealth
- $20-500 typical range

**Equipment:**
- Unique items not in shops
- Quality gear
- Signature weapons

**Reputation:**
- +5 to +60 depending on quest
- Affects future quests, prices, dialogue

**Information:**
- Map reveals
- NPC locations
- Faction secrets
- Supernatural knowledge

**Allies:**
- NPC assistance (temporary companion)
- Faction support (call for backup)
- Safe houses

**Experience:**
- Skill advancement
- Stat training opportunity

**Failure States:**

**Time Ran Out:**
- NPC died
- Event resolved without you
- Quest marked failed
- World state changes accordingly

**Critical Objective Failed:**
- Killed wrong person
- Destroyed needed item
- Alienated quest-giver

**Reputation Too Low:**
- Quest-giver refuses service
- Faction hostile
- Quest becomes unavailable

**Branching Outcomes:**

Many quests have multiple solutions:

**Example - Bounty Target:**
- **Kill:** Full bounty, reputation with law
- **Capture:** Higher bounty, better reputation
- **Convince to surrender:** Highest reward, unlock ally
- **Let escape:** Lose quest, but target owes you favor
- **Join them:** Betray employer, become outlaw

Different outcomes → different rewards/consequences

---

## PROGRESSION SYSTEMS

### Experience & Leveling

**Learn-by-Doing System** (Elder Scrolls-style):

**Skill Experience:**
- Each skill use grants 1-5 XP
  - **Trivial task:** 1 XP (shooting stationary target)
  - **Moderate task:** 2-3 XP (hunting, standard combat)
  - **Difficult task:** 4-5 XP (long-range shot, tough opponent)
  - **Impossible task:** 0 XP (can't learn from total failure)

**Skill Level Requirements:**
- 100 XP per level
- Higher levels need more successful uses:
  - 0→1: ~20 uses
  - 1→2: ~30 uses
  - 2→3: ~40 uses
  - 3→4: ~60 uses
  - 4→5: ~80 uses

**What Grants XP:**
- **Combat Skills:** Successful hits (more XP for difficult shots)
- **Survival:** Successful hunts, foraging, tracking
- **Social:** Successful persuasion, intimidation, deception
- **Utility:** Picked lock, crafted item, appraised correctly

**No Grinding:**
- Repeated trivial tasks give diminishing returns
- Shooting same stationary target 100 times = minimal XP after first few
- Must challenge yourself to improve

### Stat Advancement

**Two Methods:**

#### 1. Training (Reliable but Expensive)
- Find a trainer with higher stat than you
- Cost: $50-200 per point
- Time: 5-10 days per point
- Limited by trainer quality (can't train beyond their level)

**Trainer Locations:**
- Towns (basic trainers, stats to 4)
- Forts (military trainers, combat stats to 5)
- Rare specialists (hidden, stats to 6-7)

#### 2. Achievements (Free but Rare)
Earn stat increases through accomplishments:

**Examples:**
- Survive 10+ deadly combats → +1 Grit
- Track prey successfully 50+ times → +1 Survival
- Win 20+ social encounters → +1 Charm
- Land 100+ long-range shots → +1 Aim
- Solve 15+ complex problems → +1 Wit
- Resist 10+ diseases/poisons → +1 Fortitude
- Avoid detection 30+ times → +1 Stealth
- Complete 20+ reflex challenges → +1 Reflex

**Stat Growth Rate:**
Expect 2-4 stat increases over full playthrough (beyond training).

### Talent Acquisition

**Very Rare** - 3-6 total over playthrough

**1. Starting Talent (1):**
From character background, defines starting playstyle.

**2. Purchased Talents (2-3 possible):**
- Find rare trainers (hidden locations, faction reputation)
- Prerequisites: High stat requirement (5+), specific achievements
- Cost: $200-500 + 10-20 days training
- Examples: "Deadeye," "Iron Stomach," "Covered Retreat"

**3. Story Talents (1-2 awarded):**
- Earned through major quest completion
- Player chooses from 2-3 options matching playstyle
- Examples: "Voice of Command," "Beast Whisperer," "Lucky"

**4. Supernatural Talents (0-2 possible):**
- Discover supernatural source (shaman, witch, cursed object)
- Complete ritual/trial (dangerous, may have costs)
- May have drawbacks (vampire powers but sunlight weakness)
- Examples: "Second Sight," "Spirit Guide," "Lycanthropy"

**Talent List (Examples):**

**Combat:**
- "Quick Draw" - Bonus to duel draw speed
- "Deadeye" - Once per combat, guarantee hit
- "Trick Shot" - Disarm, ricochet, called shots
- "Covered Retreat" - Disengage without penalty
- "Berserk Charge" - Move + attack, bonus damage

**Survival:**
- "Pathfinder" - Reduced wilderness movement penalties
- "Iron Stomach" - Immune to food poisoning, can eat raw meat
- "Desert Rat" - Reduced water consumption
- "Beast Whisperer" - Calm animals, mount wild horses

**Social:**
- "Silver Tongue" - Social attacks 1 AP
- "Voice of Command" - Intimidate multiple, Rally all
- "Poker Face" - Immune to social attacks
- "Preacher's Fire" - Mass Rally + Demoralize unholy

**Utility:**
- "Keen Eye" - Find hidden caches, appraise better
- "Lucky" - Reroll one check per day
- "Quick Reload" - Reload costs -1 AP
- "Combat Medic" - Heal as free action

**Supernatural:**
- "Second Sight" - Detect supernatural, visions
- "Spirit Guide" - Occasional supernatural help
- "Witch's Blessing" - Minor magic (curses, wards)
- "Lycanthropy" - Transform (powerful but uncontrollable)

### Equipment Progression

**Weapon Tiers:**

**Tier 1 - Common ($10-30):**
- Rusty revolver, old rifle, basic knife
- Baseline stats
- Readily available

**Tier 2 - Quality ($50-100):**
- Well-made revolver, accurate rifle
- +10-20% performance
- Available in towns

**Tier 3 - Fine ($150-300):**
- Craftsman work, precision rifle
- +30-40% performance
- Rare, quest rewards, special orders

**Tier 4 - Masterwork ($500-1000 or quest-only):**
- Legendary gunsmith, one-of-a-kind
- +50%+ performance
- Unique abilities (never jams, bonus damage)
- Often named ("Peacemaker," "Widowmaker")

**Tier 5 - Supernatural (Quest-only):**
- Blessed/cursed weapons
- Silver bullets, enchanted blades
- Unique effects (ignores armor, burns undead)
- May have drawbacks (cursed = bad luck)

**Armor/Clothing Tiers:**
Similar progression:
- Damage reduction
- Environmental protection
- Carrying capacity
- Social bonuses (fine clothing in towns)

**Horse Quality:**
- **Nag** ($20): Slow, low stamina, unreliable
- **Standard** ($50): Baseline performance
- **Quality** ($100): Faster, better stamina
- **Warhorse** ($200): Combat-trained, won't spook, high stats
- **Legendary** (Quest): Unique traits (speed, endurance, intelligence)

**Consumables:**
- **Basic:** Cheap, moderate effect (bandages heal 2 HP, $1)
- **Quality:** Better effect, pricier (doctor's kit heal 5 HP, $10)
- **Rare:** Powerful, quest rewards (miracle tonic heal 10 HP + cure disease, $50)

### Progression Pacing

**Early Game (Days 1-60):**
- **Character Power:** Vulnerable
- **Skill Levels:** 0-1 → 1-2
- **Equipment:** Tier 1-2
- **Money:** $0-200
- **Reputation:** Neutral with most factions
- **Challenges:** Any fight is dangerous, survival is primary concern

**Mid Game (Days 60-180):**
- **Character Power:** Competent
- **Skill Levels:** 2-3 in specializations
- **Equipment:** Tier 2-3, maybe one Tier 4 item
- **Money:** $200-1000
- **Reputation:** Established with 2-3 factions
- **Challenges:** Standard threats manageable, elite threats still dangerous

**Late Game (Days 180-360+):**
- **Character Power:** Formidable
- **Skill Levels:** 3-4 in main skills, maybe one at 5
- **Equipment:** Tier 3-4, possibly Tier 5
- **Money:** $1000-5000+
- **Reputation:** Honored with 1-2 factions, hated by 1-2
- **Challenges:** Can handle most threats, boss encounters still challenging

**Power Ceiling:**
- 5-10 standard enemies with preparation
- 1 boss-level enemy
- Most environmental hazards survivable
- **Still vulnerable** to overwhelming numbers, ambushes, extreme conditions
- Heroic, NOT superheroic

---

## REPUTATION & FACTIONS

### Faction List

**7-8 Major Factions:**

#### 1. THE LAW (Federal/Territorial Authority)
- **Leadership:** Marshals, sheriffs, deputies
- **Goals:** Order, justice, tax collection, civilization
- **Conflicts:** Outlaws, corrupt officials, tribal resistance
- **Benefits:** Legal protection, bounties, armory access, safe passage
- **Quests:** Bounty hunting, escort prisoners, investigate crimes
- **Locations:** Sheriff offices in towns, marshal headquarters

#### 2. THE ARMY (Military)
- **Leadership:** Officers, fort commanders
- **Goals:** Territorial control, suppress threats, expand borders
- **Conflicts:** Hostile tribes, foreign powers, bandits
- **Benefits:** Military contracts, training, fort protection, supply access
- **Quests:** Scouting, escort, combat missions, intelligence gathering
- **Locations:** Forts, patrols, outposts

#### 3. OUTLAW GANGS (Multiple Groups)
- **Leadership:** Gang leaders (Crimson King, Black Mesa Boss, etc.)
- **Goals:** Wealth, territory, freedom from law
- **Conflicts:** Law, Army, other gangs, settlers
- **Benefits:** Fence for stolen goods, hideouts, criminal contacts, outlaw quests
- **Quests:** Robberies, sabotage, protection rackets, turf wars
- **Locations:** Hidden camps, controlled towns, saloons
- **Note:** Multiple separate gangs, reputation with each tracked individually

#### 4. RAILROAD/MINING CORPORATIONS
- **Leadership:** Executives, foremen, hired guns
- **Goals:** Profit, expansion, resource extraction
- **Conflicts:** Natives, settlers, environment, regulation
- **Benefits:** High-paying jobs, transport access, equipment, investment opportunities
- **Quests:** Protection, sabotage rivals, resource acquisition, labor disputes
- **Locations:** Mining towns, railroad stations, company headquarters

#### 5. NATIVE TRIBES (Multiple Nations)
- **Leadership:** Chiefs, elders, war leaders
- **Goals:** Land preservation, autonomy, sacred site protection, survival
- **Conflicts:** Settlers, Army, corporations (not monolithic - some peaceful, some hostile)
- **Benefits:** Wilderness knowledge, supernatural access, unique trades, safe passage
- **Quests:** Diplomacy, defense, sacred site protection, cultural exchange
- **Locations:** Tribal villages, sacred sites, traditional territories
- **Note:** Multiple tribes with different attitudes toward outsiders

#### 6. SETTLERS/TOWNSFOLK (Community-Based)
- **Leadership:** Mayors, prominent citizens
- **Goals:** Safety, prosperity, community growth
- **Conflicts:** Bandits, environmental threats, external pressure
- **Benefits:** Trade, shelter, local support, community aid
- **Quests:** Protection, resource gathering, building, mediation
- **Locations:** Individual towns (each tracked separately)
- **Note:** Reputation is per-town, not unified

#### 7. THE CHURCH (Religious Orders)
- **Leadership:** Preachers, missionaries, bishops
- **Goals:** Convert, protect faithful, fight evil (especially supernatural)
- **Conflicts:** Supernatural forces, vice, corruption
- **Benefits:** Sanctuary, healing, information about supernatural, moral support
- **Quests:** Exorcism, protection, conversion, charity
- **Locations:** Churches, missions, traveling preachers

#### 8. THE OCCULT (Optional - if supernatural enabled)
- **Leadership:** Witch circles, shamans, cult leaders
- **Goals:** Hidden agendas, power, knowledge, survival
- **Conflicts:** Church, those who fear them, rival occultists
- **Benefits:** Magic items, supernatural aid, forbidden knowledge, rituals
- **Quests:** Gather reagents, perform rituals, stop rival occultists, research
- **Locations:** Hidden, must be discovered (caves, abandoned buildings, wilderness)

### Reputation Scale

**-100 to +100 per faction**

**Reputation Tiers:**

| Range | Tier | Effects |
|-------|------|---------|
| -100 to -75 | HATED | Kill on sight, bounties, permanent hostility |
| -74 to -50 | HOSTILE | Attack if opportunity, refuse all service |
| -49 to -25 | DISTRUSTED | Watchful, +50% prices, no favors, limited dialogue |
| -24 to -10 | WARY | Neutral but suspicious, +20% prices |
| -9 to +9 | NEUTRAL | Default starting, normal prices and interactions |
| +10 to +24 | KNOWN | Friendly, -10% prices, share rumors |
| +25 to +49 | LIKED | -20% prices, share information, minor favors |
| +50 to +74 | RESPECTED | -30% prices, trust you, unique quests, assistance |
| +75 to +100 | HONORED | -40% prices, faction champion, unique rewards, allied status |

### Reputation Changes

**Actions that Affect Reputation:**

**Negative:**
- Kill faction member: -5 to -20 (leader = -40 to -60)
- Steal from faction: -10 to -30
- Betray faction: -25 to -50
- Attack settlement: -30 to -60
- Complete quest against faction: -15 to -40

**Positive:**
- Help faction member: +1 to +10
- Complete quest: +5 to +25 (major quest +30 to +50)
- Donate resources: +5 to +15
- Defend settlement: +20 to +40
- Broker peace: +25 to +50 (both factions)

**Visibility:**
- Actions in remote areas may not be known immediately
- Witnesses spread information
- High-profile actions (rob bank, save town) spread to ALL factions
- Can hide identity (mask, no witnesses) to avoid reputation change

**Example:**
- Rob bank in Dustwater wearing mask, no witnesses survive
- **Result:** Money gained, no reputation loss (until/if discovered)

**Example 2:**
- Save settler from wolves in front of witnesses
- **Result:** +5 Settlers (that town), +2 Law (good deed), rumor spreads

### Conflicting Loyalties

**Mutually Exclusive Relationships:**
- **Can't be Honored with both Law and Outlaws**
  - Reaching +50 with Law auto-lowers Outlaws to -25
  - Reaching +50 with Outlaws auto-lowers Law to -25

- **Can't be Honored with both Army and certain Tribal factions**
  - Depends on which tribe (some are allied, some hostile to Army)

- **Corporate vs Settlers often conflict**
  - Helping corporations may hurt settler reputation
  - Protecting settlers from corporate expansion angers corporations

**Strategic Choices:**
Player must choose alliances, can't please everyone.

**Neutral Path:**
- Possible to maintain +25 to +49 with multiple factions
- Never reaching Honored keeps options open
- Harder to get best benefits but more flexibility

### Reputation Benefits

**High Reputation (+50 to +100):**

**Economic:**
- 30-40% discounts
- Access to rare items
- First pick of new stock
- Can sell restricted items

**Social:**
- Unique dialogue options
- Skip persuasion checks (trusted)
- NPCs volunteer information
- Romantic interests possible

**Practical:**
- Safe houses (free rest, storage)
- Fast travel between faction locations
- Call for backup (NPCs assist in combat)
- Warnings of danger
- Faction quests (high-paying, unique rewards)

**Political:**
- Influence faction decisions
- Prevent faction wars
- Unlock endings (become sheriff, gang leader, etc.)

**Low Reputation (-50 to -100):**

**Economic:**
- 50%+ markup or refusal to trade
- Banned from shops
- Bounties placed on you

**Social:**
- Attacked on sight in controlled areas
- NPCs refuse dialogue
- Cannot accept faction quests
- Informants betray your location

**Practical:**
- Ambushes and assassination attempts
- Allies won't help in faction territory
- Bounty hunters pursue you
- Denied entry to settlements

**Rehabilitation:**
- Possible to recover from -50 through major actions
- Below -75 is very difficult (near-permanent hostility)
- Some actions are unforgivable (massacre, betray trust)

### Faction Interactions

**Faction Wars:**
- Some factions are at war (Army vs Tribe,



## Response:
11/29/2025, 11:38:18 PM

Gang vs Law)
- Player can exploit (play both sides)
- Player can mediate (broker peace, high Charm required)
- Ignoring war allows it to escalate (territory changes)

**Example War Escalation:**
- Week 1: Skirmishes
- Week 4: Town sieges
- Week 8: Major faction controls shift
- Player inaction = world changes dramatically

**Faction Alliances:**
- Some factions naturally allied (Law + Army, Church + Settlers)
- Helping one helps the other (+5 to ally)
- Attacking one angers the other (-10 to ally)

**Dynamic Power:**
- Faction strength changes based on player actions and world events
- Weak faction may be absorbed or destroyed
- Strong faction expands territory
- Player can tip the balance

---

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

## MINI-GAMES

### Hunting Mini-Game

**Trigger:** Player chooses "Hunt" action in appropriate terrain (forest, plains, mountains)

**Phase 1: Tracking (30-60 seconds)**

**Display:**
- Small local map (5x5 hex area)
- Animal tracks visible (quality depends on Tracking skill)
  - **Low Tracking (0-1):** Faint tracks, hard to see
  - **Medium Tracking (2-3):** Clear tracks, direction obvious
  - **High Tracking (4-5):** Perfect tracks, animal type identified, age of tracks

**Gameplay:**
- Follow tracks hex by hex (each move costs time)
- Tracks get "warmer" (stronger/fresher) as you approach
- Wrong direction = tracks fade
- Time limit (60 seconds for low skill, 90 for high)
- Success = Spot animal, proceed to Phase 2
- Failure = Animal escapes, wasted time

**Phase 2: Approach (Stealth Check)**

**Display:**
- Visual of animal in environment (grazing, drinking, etc.)
- Player represented by crosshair or icon
- Distance indicator

**Gameplay:**
- Stealth check to approach without spooking
- Wind direction matters (scent carries)
- Can use cover (trees, rocks) for bonuses
- Animal has awareness meter (fills if you're careless)
- Success = Get into shooting range (Phase 3)
- Failure = Animal flees (can attempt to track again but harder)

**Phase 3: The Shot**

**Display:**
- Aim view (similar to duel aiming)
- Crosshair over moving animal
- Breathing indicator

**Gameplay:**
- Animal behavior varies by type:
  - **Deer:** Grazes, pauses, moves, pauses (predictable)
  - **Rabbit:** Erratic, quick movements
  - **Bear:** Slow, but dangerous if you miss
- Crosshair stability based on Aim + Rifle skill
- Breathing mechanic: Hold breath for steady aim (limited time, 3-5 seconds)
- **Shot:**
  - Perfect hit (vital organs): Instant kill, maximum meat
  - Good hit (body): Animal wounded, must follow blood trail, less meat
  - Poor hit (leg/graze): Animal escapes, minimal yield
  - Miss: Animal flees, can track but very difficult

**Results:**
- **Perfect:** Full rations (deer = 3.0, rabbit = 0.5, etc.) + hide/pelt
- **Good:** 75% rations + damaged hide
- **Poor:** 25% rations, no hide
- **Miss:** Nothing, wasted ammo and time

**Skill Advancement:**
- Perfect shot: +5 XP Tracking, +5 XP Rifle
- Good shot: +3 XP each
- Completing mini-game well grants bonus

**Auto-Hunt Option (Tracking + Rifle 4+):**
- Skip mini-game
- Automatic "average" result (good hit)
- OR play mini-game for chance at perfect/bonus

---

### Foraging Mini-Game

**Trigger:** Player chooses "Forage" action in appropriate terrain

**Display:**
- Area view (forest floor, desert, etc.)
- Plants, mushrooms, roots scattered around
- 30-60 second timer

**Plant Types:**

**Valuable (Green Highlight if Survival 3+):**
- Berries (0.5 rations)
- Edible roots (0.5 rations)
- Medicinal herbs (heal 2-3 HP)
- Rare plants (craft material, sell for $5-10)

**Worthless (No highlight):**
- Weeds, dead plants, rocks
- Collecting wastes time

**Poisonous (Red Highlight if Survival 4+):**
- Look similar to valuable plants
- Collecting causes damage or sickness if eaten
- BUT can be used for poison crafting if you know

**Gameplay:**
- Click/interact with plants to collect
- Limited time (30 seconds base, +10 seconds per Survival level)
- Limited carrying capacity (10-15 items)
- Must choose wisely (pick valuable, avoid worthless/poisonous)

**Survival Skill Effects:**
- **0-1:** No highlights, must guess, high risk
- **2-3:** Valuable plants highlighted, poisonous not highlighted
- **4-5:** Both valuable and poisonous highlighted (different colors), bonus time

**Results:**
- Collect 0.5-2.0 rations worth of food
- Possible medicinal herbs (0-3)
- Possible rare plants (0-2)
- Possible poison (if skilled enough to identify)

**Skill Advancement:**
- Successfully identifying 10+ plants: +3 XP Survival
- Finding rare plant: +5 XP Survival

**Auto-Forage Option (Survival 4+):**
- Skip mini-game
- Automatic average result (1.0 rations)
- OR play for chance at rare plants/bonus

---

### Card Game (Poker)

**Trigger:** Available in saloons, camps, some encounters

**Game:** Five-card draw poker

**Display:**
- Poker table view
- Player's hand
- 1-3 AI opponents
- Pot total
- Current bet

**Setup:**
- Buy-in ($5-50 depending on stakes)
- Blinds rotate
- AI difficulty varies (novice in small towns, expert in cities)

**Gameplay:**

**Round Structure:**
1. Deal (5 cards)
2. First betting round
3. Discard and draw (0-5 cards)
4. Second betting round
5. Showdown

**Betting Options:**
- Fold (lose bet)
- Check (if no bet)
- Call (match bet)
- Raise (increase bet)

**Gambling Skill Effects:**

**0-1:** 
- No information on opponent hands
- Can't read tells
- Basic play only

**2-3:**
- See opponent confidence level (low/medium/high)
- Occasional tells revealed
- Slight edge

**4-5:**
- See probable hand strength
- Consistent tells (AI "nervous" when bluffing, etc.)
- Card counting (know what's likely in deck)

**Charm Effects:**
- Higher Charm = opponents more willing to stay in (bigger pots)
- Can smooth over losses (avoid anger)
- Can extract information while playing

**Stakes:**
- **Low:** $5-20 per hand
- **Medium:** $20-100 per hand
- **High:** $100-500 per hand
- **Illegal/Underground:** $500+ per hand, possible violence

**Outcomes:**
- **Win big:** Money + reputation as gambler + rumors spread
- **Win steady:** Slow income, safe
- **Lose:** Money gone, possible debt
- **Caught cheating:** Combat, expelled, reputation loss

**Cheating Option (Wit 4+ or specific talent):**
- Can attempt to cheat (card marking, palming)
- Success: Massive advantage
- Caught: Violence, permanent reputation loss in location
- Risk vs reward

**Side Benefits:**
- **Information:** NPCs gossip while playing (rumors, quests)
- **Allies:** Win respect of NPCs, potential allies
- **Quests:** High-stakes game may lead to quest (winner gets map, deed, etc.)

---

### Horse Breaking/Taming

**Trigger:** Encounter wild horse OR purchase unbroken horse cheap

**Display:**
- Side view of horse and rider
- Rhythm indicators
- Bucking pattern

**Gameplay:**

**Phase 1: Approach (Stealth + Horsemanship)**
- Sneak up on wild horse
- Don't spook it
- Success = can attempt to mount

**Phase 2: Mount**
- Timed button press
- Window based on Horsemanship skill
- Success = on horse, proceed to Phase 3
- Failure = Horse bucks, try again or horse flees

**Phase 3: Breaking (Rhythm Game)**

**Mechanics:**
- Horse bucks in pattern (left, right, rear, spin)
- Player must counter (button presses/joystick at right time)
- 5-10 buck sequences
- Each success = horse calms slightly
- Miss = take damage (1-2 HP), horse gets wilder

**Horsemanship Skill Effects:**
- **0-1:** Very tight timing windows, hard
- **2-3:** Moderate windows
- **4-5:** Generous windows, additional counter moves

**Stages:**
1. Wild (bucking every second)
2. Resisting (bucking every 2 seconds)
3. Testing (occasional bucks)
4. Calming (rare bucks)
5. Broken (success)

**Results:**
- **Success:** Gain horse (may be better quality than purchasable)
  - Wild horses can be exceptional (higher stats)
  - Save money ($30-80 vs buying $50-100)
- **Failure:** Take damage, horse escapes, can retry later if you find it again

**Skill Advancement:**
- Successfully break horse: +5 XP Horsemanship
- Perfect run (no misses): +10 XP Horsemanship

**Quality Variation:**
- Some wild horses are "Mustang" quality (better stats)
- Rare horses are "legendary" (unique traits, fastest, etc.)
- Breaking difficulty scales with quality

---

### Lockpicking Mini-Game (Optional)

**Trigger:** Attempting to pick lock (safes, doors, chests)

**Display:**
- Lock mechanism (tumblers, pins)
- Tension wrench and pick

**Gameplay:**
- **Rotate pins** to correct position
- **Apply tension** to hold
- **Time limit** based on lock difficulty
- **Detection risk** if in public/guarded area

**Lockpicking Skill Effects:**
- **0-1:** Can attempt simple locks only, slow
- **2-3:** Can attempt moderate locks, faster
- **4-5:** Can attempt complex locks, very fast, can feel pins (hints)

**Results:**
- **Success:** Lock opened, access to contents
- **Failure (time):** Lock remains closed, can retry
- **Failure (break):** Lock jammed, need key or force
- **Detected:** Guards alerted, combat or flee

**Alternative:** Simplified version (just skill check, no mini-game) if player preference

---

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

---

### Settings & Accessibility

**Difficulty:**
- Casual (forgiving, frequent saves)
- Normal (balanced)
- Hardcore (limited saves, higher lethality)
- Permadeath toggle (separate from difficulty)

**Save System:**
- Manual save (anytime outside combat)
- Auto-save frequency (every turn, every day, every location, off)
- Save slots (5-10)
- Cloud saves (optional)

**Graphics:**
- Resolution, quality settings
- Color blindness modes
- High contrast mode
- Text size

**Audio:**
- Master volume, music, SFX, voice
- Subtitles (size, background)

**Controls:**
- Rebindable keys
- Controller support
- Mouse + keyboard or controller
- Hotkey customization

**Gameplay:**
- Tutorial toggles
- Hints (on/off)
- Combat speed (tactical mode)
- Animation speed
- Auto-pause options (end of turn, enemy spotted, low HP)

**Accessibility:**
- Screen reader support (if feasible)
- One-handed mode
- Reduced motion
- Colorblind-friendly icons

---

## TECHNICAL CONSIDERATIONS

### Engine & Platform

**Recommended Engine:**
- **Unity** (cross-platform, good for hex grid, asset availability)
- **Godot** (open-source, lightweight, great for 2D/isometric)
- **Unreal** (if going 3D, more demanding)

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

### D. Sample Character Builds

**The Gunslinger:**
- Background: Gunslinger
- Focus: Aim + Reflex stats, Pistol skill, duel talents
- Playstyle: Combat-focused, intimidation, duels
- Endgame: Legendary gunfighter, feared by enemies

**The Scout:**
- Background: Scout or Native Scout
- Focus: Survival + Stealth, Tracking, Rifle
- Playstyle: Exploration, stealth, wilderness survival
- Endgame: Master tracker, can survive anywhere

**The Silver Tongue:**
- Background: Preacher or Drifter
- Focus: Charm + Wit, Persuasion, social combat talents
- Playstyle: Diplomacy, avoid violence, manipulation
- Endgame: Respected mediator, controls through influence

**The Treasure Hunter:**
- Background: Prospector
- Focus: Wit + Survival, Appraisal, Keen Eye talent
- Playstyle: Exploration, discovery, wealth accumulation
- Endgame: Rich, owns business, legendary finds

**The Outlaw King:**
- Background: Outlaw
- Focus: Grit + Charm, Intimidation, gang control
- Playstyle: Criminal, building empire, tactical combat
- Endgame: Gang leader, controls territory

### E. Development Roadmap

**Phase 1: Prototype (3-6 months)**
- Core movement and map system
- Basic combat (tactical mode)
- Simple encounters
- Character stats and skills
- Placeholder art

**Phase 2: Vertical Slice (3-6 months)**
- Full character system
- Duel mode combat
- Survival systems
- Procedural map generation
- One complete quest chain
- Improved art

**Phase 3: Alpha (6-9 months)**
- All systems implemented
- Full procedural generation
- Quest system complete
- Faction system
- Mini-games
- Polish combat

**Phase 4: Beta (3-6 months)**
- Content completion (all encounters, quests, locations)
- Balance passes
- Bug fixing
- UI polish
- Playtesting and iteration

**Phase 5: Release (1-2 months)**
- Final QA
- Marketing
- Launch prep
- Community setup

**Total Estimated Dev Time: 18-30 months** (small team)

### F. Inspirational Media

**Books:**
- Blood Meridian (Cormac McCarthy)
- Lonesome Dove (Larry McMurtry)
- The Sisters Brothers (Patrick deWitt)

**Films:**
- The Good, The Bad, and The Ugly
- Unforgiven
- True Grit (2010)
- The Proposition

**Games:**
- Red Dead Redemption 1 & 2 (Western setting, emergent gameplay)
- Fallout 1 & 2 (Hex-based, skill checks, open-ended)
- Darkest Dungeon (Stress/survival management)
- FTL (Roguelike, procedural events, meaningful choices)

**Comics:**
- Preacher (Garth Ennis)
- Pretty Deadly (Kelly Sue DeConnick)
- East of West (Jonathan Hickman)

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

---

**END OF DESIGN DOCUMENT**

**Version:** 1.0  
**Date:** November 29, 2025  
**Pages:** 89





---
Powered by [Claude Exporter](https://www.claudexporter.com)