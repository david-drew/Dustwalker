
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
