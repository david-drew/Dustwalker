
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
