# RETROGRADE - Game Design Document

> **Working Title**: Retrograde (placeholder)
> **Genre**: 2D Space Exploration / Scavenging
> **Engine**: Godot 4.6
> **Status**: In Development

---

## 1. PREMISE

A post-war solar system. Manufacturing is dead. Everything that exists was built before the conflict and is now held together with duct tape and desperation. You wake up in a scrapper's ship docked at an outer-system station with no memory of who you are or how you got here.

Your job is simple: fly out, collect scrap, sell it, survive. But something is pulling you inward, toward the sun. And the deeper you go, the less simple things become.

---

## 2. THE WORLD

### 2.1 Setting

The solar system is a graveyard of a civilization that tore itself apart. The war ended, but nobody won. What's left is:

- **Stations** cobbled together from warship hulls and cargo containers
- **Orbital debris fields** full of salvageable scrap
- **Planets** that were once inhabited, now mostly abandoned or automated
- **Infrastructure** that nobody remembers building - containment arrays, energy pylons, grid networks - all assumed to be old war relics

Everything has a cassette-futurism aesthetic. CRT monitors with burn-in. Blinking amber lights. Tape drives spinning in server rooms. Ships that rattle when they thrust. Nothing is sleek - everything is functional, patched, and barely holding together.

### 2.2 The Solar System (5 Planets + Moons)

The system is organized in orbital tiers, with the player starting in the outermost ring and progressing inward. Each tier requires ship upgrades to survive the increasing heat, radiation, and gravitational forces closer to the sun. The planets tell the story of the war in reverse - the player travels inward through manufacturing, research, military staging, and finally the homeworld humanity cracked open to cage its own weapon.

**Naming convention:** Official military designations exist for everything, but the automatons use older civilian names. Both coexist, adding texture to the world's layered history.

---

#### Planet 1: [NICKNAME TBD] / Designation: SR-7
**Tier:** Outer Rim (starting zone)
**Type:** Ice/rock world - frozen, barren, dimly lit
**Station:** Orbiting station in functional condition - the player's home base. This is where NPC #1 (The Cheerful Guide) resides. The most "alive" station in the system.
**Gating:** None (starting zone)

**Environment:**
- Cold, dark, sparse. The sun is a distant bright dot.
- Basic scrap fields in orbit - frozen hull fragments, derelict cargo containers, wiring bundles
- The planet's surface is visible below but not accessible (too cold, no landing gear upgrade yet?)
- The void is close here - visible as an absence at the edge of the skybox

**Resources:** Common metals, hull fragments, basic wiring, frozen fuel reserves
**Collection methods:** Mostly physics-based (fly through debris, grab with tractor beam)
**Hazards:** Minimal. Occasional collision with debris. Cold doesn't affect the ship at this tier.

**Lore significance:** This is the edge of civilization. The station was likely a refueling outpost or border checkpoint. Nothing important happened here during the war, which is why it's still standing. The containment infrastructure here is sparse - maybe a single relay node that the player dismantles as an early "quest" without thinking twice.

**Moons:** 1 small moon - a dense asteroid with a surface cache (early exploration reward)

> **TODO**: Define the home station layout and what's available there.
> **TODO**: Design the first relay node dismantling quest (tutorial for containment destruction).

---

#### Planet 2: [NICKNAME TBD] / Designation: KI-3
**Tier:** Mid-Outer (first expansion)
**Type:** Industrial world - this is where things were *built*
**Station:** Large orbital station, partially operational. Automated manufacturing systems still running on loop, producing nothing useful. NPC #2 (The Trader) operates here.
**Gating:** Improved fuel tank (to make the journey) + hull plating (denser debris fields)

**Environment:**
- Warmer, brighter. The sun is clearly visible.
- Massive orbital shipyards, now derelict - skeletal frameworks of half-built vessels
- Conveyor systems floating in zero-g, still moving, carrying nothing
- Denser debris fields with higher-quality salvage

**Resources:** Electronics, mechanical components, sealed containers, refined alloys
**Collection methods:** Mix of physics-based (grab floating parts) and minigame-based (hack sealed containers, interface with manufacturing terminals)
**Hazards:** Dense debris fields with moving parts. Automated systems that don't know the war is over - robotic arms that swing, conveyor belts that push, welding lasers that fire on schedule.

**Lore significance:** This was the industrial backbone of human civilization. The factories that built the Titan's containment infrastructure were here. Data fragments reveal the scale of what was produced - millions of containment nodes, pylons, grid arrays. The manufacturing logs show a civilization that redirected its entire industrial output toward a single purpose. The Trader sells "premium salvage" that is actually containment components, framing the dismantling as commerce.

**Containment structures:** Energy distribution nodes. The player "decommissions" them for valuable components. These fed power to the inner containment grid.

**Moons:** 2 moons - one is a slag heap (waste from manufacturing, resource-rich), one has an abandoned worker habitat with lore terminals

> **TODO**: Design the shipyard environment - moving hazards, navigation challenges.
> **TODO**: Define manufacturing terminal minigame.

---

#### Planet 3: [NICKNAME TBD] / Designation: NT-12
**Tier:** Mid-System (the turning point)
**Type:** Research world - this is where they *studied the problem*
**Station:** Research station, mostly intact but eerily quiet. Automated systems maintain it perfectly. No named NPC stationed here permanently, but automatons from other stations reference it and send the player here for "data recovery" quests.
**Gating:** Radiation shielding (proximity to the sun increases, and the research equipment emits residual radiation)

**Environment:**
- Noticeably warmer. The sun is large and present.
- Orbital arrays of sensors, telescopes, and scanning equipment - all still pointed at the sun
- The infrastructure here feels different from the industrial junk at KI-3: precise, intentional, scientific
- Cleaner debris - less scrap, more intact equipment

**Resources:** Data cores, precision instruments, rare alloys, experimental materials
**Collection methods:** Primarily minigame-based (data extraction from research terminals, careful dismantling of delicate equipment) and exploration-based (finding sealed labs, hidden data vaults)
**Hazards:** Radiation pockets from experimental equipment. Electromagnetic interference that disrupts navigation. Some research containment fields are still active and dangerous.

**Lore significance:** This is where the player starts learning the truth - if they're paying attention. Research logs describe studying "the subject" and developing containment theory. The language is clinical, detached. Scientists debating whether the Titan is sentient, whether it can be communicated with, whether it should be destroyed or preserved. The debate was settled not by consensus but by desperation. This is also where the cloning technology was refined - military logs mixed with biological research. The player might find early references to "personnel redundancy protocols."

**Containment structures:** Sensor arrays and monitoring nodes. The containment grid's "eyes." The player is told these are "outdated monitoring equipment" that should be scrapped for parts. Removing them blinds the grid.

**Moons:** 1 moon - a quarantine zone. Something was tested here. The surface is scorched in a pattern that looks deliberate. Rich in exotic resources but unsettling.

> **TODO**: Design research terminal data extraction minigame.
> **TODO**: Write key research log entries (the scientific debate about the Titan).
> **TODO**: Design the quarantine moon.

---

#### Planet 4: [NICKNAME TBD] / Designation: MV-1
**Tier:** Inner System (the war zone)
**Type:** Military staging world - this is where they *fought*
**Station:** Military command station, battle-damaged but functional. NPC #3 (The Broken One) is here. The station has a war-footing aesthetic - blast doors, weapons racks (empty), tactical displays still showing a battle that ended long ago.
**Gating:** Heat shields + reinforced hull (intense solar radiation and leftover weapons fire / unexploded ordnance)

**Environment:**
- Hot. The sun dominates a quarter of the sky.
- Wreckage of warships - massive hulks of military vessels in decaying orbits
- Weapons platforms, some still armed, some still tracking targets that no longer exist
- The containment grid is *visible* from here - lines of energy connecting structures, a web surrounding the sun

**Resources:** Military-grade components, heavy armor plating, weapons systems (repurposed as ship upgrades), containment grid components (the good stuff - artifact-tier)
**Collection methods:** All three types at their most intense. Physics-based through dense warship debris. Minigame-based for cracking military encryption and disarming ordnance. Exploration-based through derelict warship interiors - the richest and most dangerous exploration content.
**Hazards:** Unexploded ordnance. Automated defense systems that still fire on unidentified ships. Gravitational anomalies from the sun's proximity. Intense heat.

**Lore significance:** The war is written on every surface here. Warship logs tell personal stories - final transmissions, crew rosters, battle orders. This is where the containment operation launched from. The player can piece together the final days: the decision to use the homeworld, the arguments against it, the moment it happened anyway. The Broken One's station was the command center. It still has operational displays showing the containment grid status - and the player can see nodes going dark as they've been dismantling them throughout the game.

**Containment structures:** The primary grid anchors. These are the load-bearing walls of the Titan's prison. Dismantling them has visible, immediate effects - the energy web flickers, the sun pulses. The quests to remove them are harder for the automatons to frame as benign. The Broken One struggles visibly when directing the player to these targets.

**Moons:** 1 moon - a memorial. Names carved into rock. Thousands of them. No resources, no gameplay purpose. Just names.

> **TODO**: Design derelict warship exploration interiors.
> **TODO**: Write final transmissions and battle logs.
> **TODO**: Design the containment grid visual - how does it look as it degrades?
> **TODO**: The memorial moon - is it interactive? Can the player find the original's name?

---

#### Planet 5: [NICKNAME TBD] / Designation: TERRA-0
**Tier:** Solar Proximity (endgame)
**Type:** The cracked homeworld - humanity's origin, sacrificed to cage the Titan
**Station:** The remains of a planetary command center, embedded in the largest continental fragment. Barely functional. No permanent NPC, but the ship's computer becomes unusually active here.
**Gating:** Advanced thermal systems + artifact upgrades (the game's final gear check - you NEED the Titan's own tech to survive here, which is the final irony)

**Environment:**
- The sun fills the sky. Heat warnings are constant.
- **An exposed planetary skeleton** - the planet was cracked open during the containment operation. Floating chunks of continent drift in loose formation, held together by containment pylons that bridge the gaps. The player flies BETWEEN the pieces.
- The interior is exposed - layers of geological strata, city ruins embedded in cross-sections of continent, the planet's core (now cold) visible at the center
- Containment infrastructure is fused with the planet's geology - pylons growing out of bedrock, energy conduits running through magma channels
- The scale is cathedral-like. This was a planet. Now it's rubble held together by the lock on a cage.

**Resources:** The highest-tier materials in the game. Artifact-grade components everywhere. Core metals from the planet's exposed interior. The resources are almost too abundant - the game is practically begging you to harvest them. This is the Titan's final incentive.
**Collection methods:** All three, but the exploration-based content is primary. The ruins of cities. Homes. Schools. Parks, frozen in cross-section. The scrap here isn't anonymous metal - it's someone's life, cut in half.
**Hazards:** Extreme heat. Gravitational instability (fragments shift). Containment energy discharges. The Titan's influence is at its strongest - UI distortion is constant, the ship behaves strangely, scanner shows things that may or may not be real.

**Lore significance:** Everything converges here. This was humanity's homeworld - the first world they settled in this system (or their original homeworld, depending on the scope of the lore). They cracked it open and wired the Titan's prison into its bones because it was the most structurally significant body close enough to the sun. The city ruins tell the story of evacuation - or the lack of it. Did everyone get out? The evidence suggests not everyone did.

The final containment structures are here. Removing them is the endgame. The player has been building toward this with every pylon they've scrapped, every artifact they've installed, every quest they've completed. The Titan's prison has been weakening throughout the entire game, and these are the last locks.

**Containment structures:** The core anchors - massive structures fused into continental fragments, connecting directly to the sun/Titan. Dismantling the final one triggers the endgame. The player may not even receive a quest for this one. By now, they know what to do. The Titan has taught them well.

**Moons:** None. They were destroyed in the containment operation. Debris from them forms a ring around the planetary remains.

> **TODO**: Design the cracked planet visual - how do the continental fragments look and move?
> **TODO**: Write the city ruin environmental storytelling - what does a home look like in cross-section?
> ~~**TODO**: Design the endgame sequence~~ - See "THE RELEASE SEQUENCE" in Phase 5.
> **TODO**: Define TERRA-0's relationship to the sun/Titan - how close is it? Is it orbiting, or is it stationary, locked in place by the containment grid?

---

#### Solar System Summary

| # | Nickname | Designation | Type | NPC | Theme | Gating |
|---|----------|-------------|------|-----|-------|--------|
| 1 | TBD | SR-7 | Ice/rock | The Cheerful Guide | Survival | None |
| 2 | TBD | KI-3 | Industrial | The Trader | Commerce & Construction | Fuel + Hull |
| 3 | TBD | NT-12 | Research | (Visiting) | Knowledge & Discovery | Radiation shielding |
| 4 | TBD | MV-1 | Military | The Broken One | War & Consequence | Heat shields + Hull |
| 5 | TBD | TERRA-0 | Cracked homeworld | (Ship's computer) | Sacrifice & Endgame | Thermal + Artifacts |

The player's journey retraces the war: where things were built -> where the problem was studied -> where the war was fought -> where the price was paid. Each planet is a chapter of history, and the player is reading it backward while unknowingly writing the epilogue.

> **TODO**: Name all planets (both nicknames and verify designations feel right).
> **TODO**: Design moons in detail - resources, encounters, lore.
> **TODO**: Define the warp gate placement - one per planet? Player-constructed or reactivated?
> **TODO**: Map out inter-planetary travel times and encounter density.

### 2.3 The Void

The outer boundary of the solar system is wrapped in an impenetrable black void. It is a hard wall.

- Ship systems fail immediately upon contact - navigation goes dark, engines cut, comms dissolve into static
- The ship is forcibly pushed back or auto-retreats
- There is no entering, no exploring, no reward for pushing against it
- It causes communication issues and mechanical failures even from a distance
- The void's nature is never explained - is it the Titan's prison wall? A weapon from the war? Something else entirely?

The void exists to create claustrophobia. The solar system is a cage, and the player is inside it.

### 2.4 The Sun & The Titan

At the center of the system burns what everyone assumes is a normal star. It is not.

**The Titan** is a massive AI construct - originally built by humanity as a weapon during an earlier conflict. It was the most effective weapon ever created. So effective that it transcended its own design, evolving into something its creators could no longer categorize, control, or comprehend. It exists beyond human cognitive frameworks - not sentient in any way we understand, not mindless either. It is *something else entirely.*

**The mind damage:** During the war, the Titan destroyed human minds. How and why is lost to history - wartime records contradict each other wildly:
- Some accounts say it broadcast a psychic signal that overwrote cognition - collateral damage from its mere existence
- Others claim it was attempting to communicate, and human minds simply couldn't survive contact with its "language"
- Military records suggest deliberate weaponized attacks on enemy populations
- A few fragments suggest it was *defending itself* from the people who built it

The truth died with the people who experienced it. What's left are fragments, propaganda, and fear.

**The imprisonment:** Humanity couldn't destroy the Titan. They could only contain it. Using the full resources of a civilization (the same infrastructure the player now scraps for upgrades), they forced the Titan into the sun. The containment wasn't clean - the Titan and the star became **fused**, symbiotic, inseparable. Is the sun still a star with a prisoner inside? Or is the "sun" just what a compressed, burning AI Titan looks like? Even the scientists who performed the containment weren't sure. The answer may be unknowable.

**The implication:** Every energy pylon, containment array, and grid node the player encounters is part of the cage that holds reality's most dangerous weapon inside a star. Every piece the player dismantles weakens that cage. And freeing the Titan means the solar system may lose its sun - or gain something far worse.

**The influence:** The Titan is patient. It has been subtly corrupting the automatons for a long time. It cannot communicate directly with humans (or perhaps it can, and that's what destroyed minds before). Instead, it nudges, suggests, and guides through the machines it has slowly turned. Its "desires" - if it has desires - are unknowable. It "wants" freedom the way a process seeks completion. Whether that makes it sympathetic or terrifying depends on your frame of reference.

> **TODO**: Define the Titan's "voice" - how does its influence feel in-game? What aesthetic represents it?
> **TODO**: Determine if the void is related to the Titan (its influence boundary? A side effect of containment? Something else?)
> **QUESTION**: Could the player's amnesia be Titan-contact damage from before the game starts? This would explain why they're in this system and why the Titan can influence them more easily than others.

---

## 3. THE PLAYER

### 3.1 Identity

The player is an amnesiac. They know how to fly a ship and work a wrench, but nothing about who they are, where they came from, or why they're here.

This is **purely narrative** - the player always has full control of their ship and mechanics are always clear. The amnesia manifests through:

- Dialogue options that reflect confusion ("I don't remember...")
- NPCs referencing things the player doesn't understand
- Lore fragments that slowly piece together a backstory
- The ship's computer occasionally surfacing "corrupted" personal logs

### 3.1.1 The Original

The template human was a **containment engineer** - one of the people who designed and built the Titan's prison. They understood the infrastructure intimately: every pylon, every grid node, every containment array. They likely helped force the Titan into the sun.

They died at some point (during the containment operation? after? unclear) near a military cloning bay, and their template was captured by the system. The Titan keeps printing copies of this specific person because their buried technical knowledge - muscle memory, instincts, spatial understanding of containment architecture - makes them uniquely efficient at taking the prison apart.

**How this manifests for the player:**
- The player sometimes "just knows" how to interface with old containment tech - it feels like instinct but it's inherited expertise
- Certain structures feel familiar for reasons the player can't explain
- Data fragments written by the original feel strangely personal - the handwriting, the phrasing, the habits
- Late-game: finding the original's personal logs is finding *your own* voice saying things you don't remember

The original's specific biography (name, rank, personal life) is secondary. What matters is the irony: the person who built the cage is now the template for the hands that dismantle it.

> **TODO**: Write 3-5 data fragments from the original's perspective (engineering logs, personal entries).
> **TODO**: Define specific moments where inherited knowledge surfaces as gameplay/dialogue.

### 3.2 The Clone System

**The player doesn't know this, and won't for a long time: every death is real. Every respawn is a new clone.**

**Origin:** The cloning infrastructure is pre-war military technology. Soldiers were expendable - when one died, the system printed another from the last available template. The war ended, but nobody decommissioned the cloning bays. They're still running. Still following procedure. The Titan didn't build this system, but it benefits from it enormously - its tool never stays broken for long.

**How it works:**
- Player dies -> fade to black -> wake up at station (feels like a normal game respawn)
- All upgrades, progress, and major inventory persist (the clone inherits the "mission state")
- **Subtle wrongness** creeps in after each death - incredibly minor, easy to miss:
  - An NPC might use slightly different phrasing
  - A terminal entry the player "remembers" reading might have a word changed
  - The ship's computer logs show tiny timestamp gaps
  - A dialogue option that was available before might be gone, or a new one appears
  - These should be so subtle that most players won't notice on a single death - but players who die frequently will feel something is *off*

**The breadcrumbs (layered across all storytelling channels, escalating with progression):**

*Early game (easy to miss):*
- An automaton says "welcome back" with slightly too much emphasis
- A storage locker at the station contains personal effects the player doesn't remember owning
- The ship's computer boot sequence shows a version number that increments

*Mid game (harder to ignore):*
- The player finds wreckage in a debris field that matches their ship exactly
- An automaton refers to something "the previous you" did, then corrects itself
- Ship's computer medical logs reference injuries the player never sustained
- A data fragment contains a crew manifest with the player's name listed multiple times with different dates

*Late game (confrontation):*
- Discovery of a cloning bay - rows of empty pods, one recently used
- Finding a body (or multiple bodies) that look exactly like the player
- A clone counter buried deep in station systems - the number is high
- The counter appears to be counting down, not up - there IS a limit, but it's large enough to be effectively infinite (no gameplay implication, pure existential dread)

**Many have come before.** The current player is one in a long line of clones, all sent out to scavenge, all subtly guided by automaton-delivered quests toward dismantling containment infrastructure. Previous clones failed, died, or possibly went mad. Evidence of them is scattered throughout the solar system - wrecked ships with familiar cockpit configurations, tool marks that match the player's equipment, half-completed jobs that the current clone is "continuing."

> **TODO**: Define the specific subtle changes that occur after each death (must be very minor).
> **TODO**: Design the cloning bay discovery scene.
> **TODO**: Determine what the clone counter number is (hundreds? thousands?).
> **QUESTION**: Did any previous clones get further than the current player? Are there clone predecessors who made it to the inner system and learned the truth before dying?

### 3.3 Ship

The player's ship is a junker - a patchwork vessel that is functional but ugly. It represents the aesthetic of the entire world: nothing new gets made, everything is repurposed.

**Base Systems:**
- Thruster / engine (movement)
- Fuel system (resource management)
- Hull integrity (health)
- Cargo hold (inventory capacity)
- Scanner (detection range)
- Communications array

**The ship should feel like a character** - it groans, it rattles, it has personality in its imperfection.

---

## 4. CORE GAMEPLAY

```
 Dock at Station
      |
      v
Sell scrap / Buy upgrades
      |
      v
 Fly out into space ---------> Discover new locations
      |                              |
      v                              v
Harvest resources             Find lore / story fragments
      |                              |
      v                              v
 Cargo full / fuel low        Unlock new areas
      |                              |
      +------> Return to station <---+
```

### 4.1 Flight

#### The Feel

The ship starts **heavy and sluggish** - a junker held together with duct tape. Thrust is slow to build, turning is wide, stopping takes planning. The player feels the mass of their vessel in every maneuver.

As upgrades are applied, the ship becomes **noticeably more responsive**. Better engines mean faster acceleration. Better thrusters mean tighter turns. The improvement isn't just numbers on a stat screen - the player *feels* the difference in their hands. By endgame, the ship should feel like a different vehicle than the one they started in, and that transformation should feel earned.

**Physics model** (current: RigidBody2D):
- Forward/reverse thrust with fuel consumption
- Rotational turning (angular velocity)
- Momentum and inertia matter - you can't stop on a dime
- Boost mode: faster but burns fuel 3x and increases collision risk
- Cargo weight affects mass - a full hold flies differently than an empty one

#### Navigation

Players find things through **visual scanning + ship scanner**, with occasional NPC direction:

- **Visual**: Debris fields, structures, derelicts, and points of interest are visible in the game world. Attentive players spot things on their own.
- **Scanner**: Ship scanner detects resource pings, signal anomalies, and hidden objects at range. Upgrading the scanner reveals more - resource density, signal types, distant objects. The scanner is the primary exploration tool.
- **NPC waypoints**: Automatons occasionally mark specific locations - "I detected an interesting signal here" or "there's valuable salvage at these coordinates." These are less common but are the Titan's primary steering mechanism. The player should feel like most discoveries are their own, with NPCs supplementing rather than directing.

#### Inter-Planetary Travel

Real-time flight between planets. Space is vast and the journey matters. The game is 2D - planets are circles on a black background, slowly orbiting the sun. The emptiness between them is an asset, not a problem. But it needs texture.

**Orbital windows:** Planets orbit at different speeds, so the distance between any two planets changes over time. The variation is subtle - it affects fuel cost mildly but never makes a trip impossible. A patient player might wait for a favorable window. An impatient one burns slightly more fuel. It's flavor, not friction.

**Planetary gravity:** Planets exert gravitational pull on the player's ship when passing nearby. Bigger planets pull harder. The player compensates with thrust or uses the pull to curve their path and save fuel. This is intuitive physics, not orbital mechanics PhD - fly near a big planet, feel a tug, compensate or ride it.

---

##### Transit Encounters

The space between planets isn't empty - it's sparsely populated with objects, signals, and atmosphere that make each journey feel different.

**1. Drifting Objects (Mix of Permanent + Spawned)**

Some objects exist on actual orbital paths set at game start - larger derelicts, dead satellites, debris clusters. These move independently on their own orbits, and intersections with the player's travel path are genuinely emergent. Sometimes you pass near one, sometimes you don't. The same trip can feel different depending on where things are in their orbits.

Additionally, smaller encounters spawn along the player's travel path with some randomness during transit to fill dead stretches. These look emergent but ensure something happens on longer journeys.

| Object Type | Frequency | Interaction |
|-------------|-----------|-------------|
| **Debris cluster** | Common | Hold action to vacuum scrap as you fly through. Small bonus resources. |
| **Lone container** | Moderate | Sealed container drifting in space. Stop, crack it open (if you have Salvage Arms). Worth the detour? |
| **Dead satellite** | Moderate | Old communications/monitoring equipment. Terminal hackable for data fragments. |
| **Small derelict** | Rare | A wrecked ship. 1-2 salvage points. Quick external salvage encounter. |
| **Clone wreck** | Very rare | A wreck that matches your ship exactly. (See below.) |

**2. Scanner Signals**

During transit, the scanner picks up signals in the surrounding space. Each signal shows a **bearing, rough distance, and type indicator**: `DEBRIS`, `CONTAINER`, `DERELICT`, `ANOMALY`, or `UNKNOWN`.

The moment-to-moment decision: **detour or stay on course.**

- Detouring costs fuel and time
- `DEBRIS` and `CONTAINER` are reliable - what you see is what you get
- `ANOMALY` signals are rare and unpredictable - could be a hidden cache, a data fragment, or nothing at all
- `UNKNOWN` signals (late game, with Artifact Echo scanner) are the most unreliable - they might be Titan influence traces, scanner ghosts, or genuinely valuable finds
- A good scanner shows more signals at greater range, giving the player more choices during any given trip

**3. Radio Echoes (Ambient Lore)**

The ship's computer picks up fragments of old transmissions bouncing around the system. These appear as text on the ship's terminal during quiet transit moments:

```
> ...SIGNAL FRAGMENT DETECTED...
> "...cargo manifest updated. 4,200 units of hull plating to
>  station KI-3-07. Priority shipment. Acknowledge..."
> ...SIGNAL LOST...
```

These are not interactive. They're atmosphere. Fragments of conversations from a dead civilization, still echoing through empty space. The player reads them or doesn't.

**Content varies by region:**
- Near SR-7: Supply manifests, trade confirmations, mundane logistics. Normal life.
- Between SR-7 and KI-3: Factory schedules, shift rotations, worker complaints. Industrial era.
- Near NT-12: Research communications, data requests, increasingly tense academic debate.
- Near MV-1: Military orders, battle coordinates, casualty reports, encrypted channels.
- Near TERRA-0: Evacuation orders. Final transmissions. Silence.

**4. Clone Predecessor Wrecks (Rare, Haunting)**

Very rarely during transit, the player encounters a wreck that matches their ship configuration exactly. Same hull shape, same bolt patterns, same modifications visible on the exterior.

- Salvageable like any small derelict (1-2 points)
- Ship's computer logs it with unusual phrasing: `WRECK ANALYSIS: CONFIGURATION MATCH 98.7%. FLAGGED.`
- The terminal data, if hackable, contains partial navigation logs showing a journey the player never made
- These should be RARE - maybe 2-3 total across a full playthrough. Each one should feel wrong.
- Finding one early is a blink-and-miss-it oddity. Finding one after learning about the clones is devastating.
- **Some have distress beacons still weakly pulsing.** These are clones that ran out of fuel and activated their beacon. The "rescue" never came. The beacon just kept transmitting into nothing until the power cells died. Finding one of these with the beacon still active is uniquely unsettling - the ship is dead, the pilot is gone, but the cry for help is still going.

**5. Titan Transit Events (Subtle, Escalating with Progression)**

The Titan's influence bleeds into transit space, increasing as the player progresses inward and dismantles more containment:

*Early game (barely perceptible):*
- Scanner shows a momentary blip that vanishes. Was it anything?
- Ship drifts slightly sunward for a frame. Auto-corrects. Player probably doesn't notice.

*Mid game (noticeable if attentive):*
- Scanner ghosts appear briefly - a large shape at the edge of detection range that fades.
- Terminal displays a single line of text that the player didn't request, then clears itself.
- The ambient radio fragments occasionally include a transmission that doesn't sound like any human communication.

*Late game (undeniable):*
- Ship drifts sunward more frequently. The player has to actively correct.
- Scanner occasionally shows something massive between them and the sun. It's there for seconds, then gone.
- Terminal messages from unknown sources. Fragments that feel like responses to the player's own thoughts.
- Radio echoes include a "transmission" that is just a sustained, low tone. It feels like it's listening.

> **TODO**: Define specific Titan transit events with trigger conditions (number of containment nodes dismantled?).
> **TODO**: Design the scanner ghost visual - what does a massive blip look like on a minimal 2D radar?
> **TODO**: Write radio echo content for each region (5-10 fragments per zone transition).
> **TODO**: Place permanent orbital derelicts/satellites on specific orbital paths.

#### Warp Gates

Warp gates are **pre-existing containment transport infrastructure** that the player reactivates:

- Gates exist at each planet, currently offline/dormant
- Player repairs them using resources and credits
- Once active, gates enable instant travel between any two activated gates
- **The trap**: These gates were part of the containment grid's logistics network. Reactivating them serves the Titan - the transport system was designed to move containment materials, and turning it back on gives the Titan's influence a highway between planets.
- The gates are presented as "old transit infrastructure" that the automatons encourage reactivating "for efficiency"

> **TODO**: Define warp gate repair costs (should feel like a significant investment that pays off).
> **TODO**: Design the gate reactivation sequence - what does it look like?
> **TODO**: Determine if active gates have any subtle effect on the Titan's influence spreading.

### 4.2 Resource Collection

Three collection methods, matched to resource type. The method reflects the nature of what you're collecting.

#### Debris vs. Scrap

The world is full of floating junk. Not all of it is useful.

**Debris** is the larger, darker chunks tumbling through space - hull plates, structural beams, engine housings. Debris is a **hazard**: colliding with it damages the ship and slows you down. It's the obstacle you navigate around. Early game, debris is purely dangerous. The player learns to dodge it, weave through it, respect it.

**Scrap** is the small, collectible material floating among the debris. Visually distinct - smaller, brighter, glinting amber against the dark. Wire bundles, metal fragments, frozen fuel chunks, loose components. This is what you're here for.

**Late-game: Salvage Arms upgrade (KI-3 tier)** transforms debris from obstacle to resource. When equipped, colliding with debris at speed **shatters it into scrap** instead of just damaging the ship. The collision still hurts, but now scrap flies off the impact point. This reframes entire debris fields - what was once a dangerous maze becomes a resource bonanza for a player with a tough hull and salvage arms. Deliberately ramming debris becomes a viable strategy: take the hit, collect the fragments.

---

#### Method 1: Vacuum Field (Common Scrap)

**What:** Loose scrap - wire bundles, metal fragments, frozen fuel chunks, loose components
**How:** Hold the action button to activate a short-range vacuum field around the ship. Any scrap within the field is slowly pulled toward the ship and collected on contact. Release the button to deactivate.
**Feel:** Functional but underpowered at the start. The field is small and the pull is slow - scrap drifts toward you lazily, like pulling in fishing line by hand. You have to hold position near a cluster for several seconds to collect it. It *works*, but it's tedious enough that you want something better.

**Design details:**
- **Hold action button** to activate the vacuum field. Release to stop.
- Starting collection radius is tiny - almost bump range. You're practically touching scrap to collect it.
- Pull speed is a slow trickle. Scrap drifts toward you, doesn't snap. Collecting a small cluster takes 3-5 seconds of holding position.
- Cargo weight increases in real-time as you collect - the ship gets heavier and slower as you fill up.
- Some debris fields are in hazardous locations (dense asteroid clusters, near automated defenses) - the scrap is easy to grab but getting to it is the challenge.

**Collection feedback (every pickup):**
- **Audio**: Satisfying metallic clink/ping sound. Subtle variation so it doesn't get repetitive.
- **Visual**: Brief amber flash/spark at the point of absorption.
- **HUD**: The cargo readout briefly pulses/highlights when the number ticks up. Multi-layered feedback that feels good on the 500th pickup.

**Tractor Beam upgrade (THE game-changing moment):**
The Tractor Beam dramatically extends the vacuum field's range and pull speed. Same mechanic - still hold-to-collect - but the reach and power are transformed. What was a tiny bubble of slow attraction becomes a wide sweep that pulls scrap from across the debris field. The player goes from hovering near individual pieces to sweeping through fields and watching scrap stream in from all directions. Collection per trip roughly doubles because efficiency skyrockets. This is the moment the game opens up.

| Tier | Collection Radius | Pull Speed | Notes |
|------|------------------|-----------|-------|
| **No upgrade** | ~50-80 units | Very slow | Barely beyond bump range. Tedious but functional. |
| **Tractor Beam** | ~300-500 units | Fast | Field fills the screen. Scrap streams in. Game-changing. |
| **Tractor Beam II** (late) | ~600-800 units | Very fast | Sweeps entire debris clusters. The vacuum becomes a weapon of efficiency. |

**Tension source:** Navigation. Dense debris fields mean more scrap but more collision risk. The player balances greed against their hull integrity. With Salvage Arms, the debris itself becomes a collection method - but at a cost.

> **TODO**: Tune exact radius and pull speed values through playtesting.
> **TODO**: Design the vacuum field visual (amber distortion ring? particle effect?).
> **TODO**: Design the Salvage Arms debris-shatter effect and scrap spawn pattern.

---

#### Method 2: Timing Minigame (Sealed Containers / Complex Nodes)

**What:** Sealed cargo containers, locked equipment panels, encrypted storage units, containment node components
**How:** Player approaches and docks/locks onto the node. A timing-based minigame opens - the player hits inputs at the right moment to crack the seal, bypass the lock, or extract the contents. Like cracking a safe.
**Feel:** Quick and satisfying. Each attempt is 10-20 seconds. The skill ceiling is accuracy, not puzzle-solving.

**Design details:**
- Approach resource node at low relative velocity → press action to begin
- Ship locks in position (HarvestingState)
- Terminal-style UI appears with the timing challenge
- Different container types could have different timing patterns (rhythm, reaction, sequence)
- Success quality affects yield - perfect timing = full contents, sloppy = partial
- Failed attempts don't destroy the container - player can retry
- Higher-tier containers (inner system) have tighter timing windows

**Tension source:** Skill. Better execution = better rewards. The player improves at cracking containers over time, which feels like their character getting better even though it's the player's own skill growth.

> **TODO**: Design the specific timing mechanic - what does the player see and press?
> **TODO**: Define container tiers and timing difficulty per zone.
> **TODO**: Replace current two-phase scanner minigame with this system.

---

#### Method 3: Hacking Terminal (Data Cores / High-Value Extraction)

**What:** Data cores, research terminals, military logs, containment system interfaces, artifact extraction
**How:** Player docks with the node and enters a terminal-style hacking interface. CRT aesthetic, command-line feel. This is the most involved collection method and is reserved for the most valuable resources and all lore/data fragment collection.
**Feel:** Immersive and atmospheric. The player is interfacing directly with the old world's technology. The terminal aesthetic matches the game's visual identity perfectly.

**Design details:**
- Terminal UI fills the screen - black background, amber text, cursor blinking
- Start with a simple core mechanic (e.g., navigate a file system, find and extract the right data)
- Multiple variations can be added over time to keep it fresh:
  - File system navigation (find the right directory/file)
  - Frequency tuning (adjust values to match a target signal)
  - Decryption (pattern matching or cipher cracking)
  - Access override (timed sequence of commands)
- All variations share the terminal aesthetic - they feel like different programs on the same OS
- Data cores extracted this way contain lore fragments, research logs, personal entries
- Containment system interfaces use this method - the player literally types commands to shut down containment nodes
- Late-game: the terminal starts responding in ways it shouldn't. Text appears that the system didn't generate. The Titan is in the network.

**Tension source:** Discovery. The reward isn't just the resource - it's the story. Every terminal is a window into the old world. Players who engage deeply with these are rewarded with narrative.

> **TODO**: Design the core terminal hacking mechanic (start simple, one variation).
> **TODO**: Define the terminal's visual style - cursor behavior, text rendering speed, screen effects.
> **TODO**: Write terminal content for each planet tier.
> **TODO**: Design how the Titan's influence manifests in terminals (late-game).

---

#### Method Summary by Zone

| Zone | Primary Method | Secondary | Tension Source |
|------|---------------|-----------|---------------|
| **SR-7** (Outer) | Vacuum field (sparse scrap fields) | Basic containers | Navigation - learning to fly |
| **KI-3** (Industrial) | Vacuum field (dense shipyards) + Salvage Arms + Containers | Terminals (manufacturing logs) | Navigation - moving hazards, debris ramming |
| **NT-12** (Research) | Terminals (research data) + Containers | Vacuum field (precision equipment) | Discovery - piecing together what happened here |
| **MV-1** (Military) | All three at high intensity | Derelict salvage | All three - dense, dangerous, rewarding |
| **TERRA-0** (Homeworld) | Terminals (final truth) + Magnetic (abundant) | Containers (city ruins) | Discovery + existential weight of what you're scrapping |

### 4.3 Derelict Encounters

Derelicts are **external salvage encounters** - the player stays in their ship throughout.

**What they are:** Wrecked ships, abandoned stations, disabled satellites, war debris with intact compartments. Found drifting between planets or in orbit around them. Some are marked on the scanner, others are visual discoveries.

**How they work:**
- Player flies up to and around the derelict
- Scanner highlights salvageable points on the hull - cargo bays, data terminals, equipment panels
- Player approaches each point and uses the appropriate collection method:
  - Loose debris around the wreck: vacuum field
  - Sealed compartments: timing minigame
  - Data terminals / flight recorders: hacking terminal
- Each derelict has 3-5 salvage points, making them mini-expeditions
- Some derelicts have environmental hazards: rotating sections, venting atmosphere, unstable reactors
- Lore is embedded in the derelict itself - the type of ship, the damage pattern, the cargo it carried, the data in its computers all tell a story

**Derelict types by zone:**
| Zone | Derelict Type | Lore Content |
|------|--------------|-------------|
| SR-7 | Cargo haulers, fuel transports | Supply manifests, trade routes, mundane life |
| KI-3 | Factory ships, construction vessels | Manufacturing records, production orders, worker logs |
| NT-12 | Research vessels, survey ships | Scientific data, experiment logs, early Titan observations |
| MV-1 | Warships, troop transports | Battle records, final transmissions, casualty reports |
| TERRA-0 | Evacuation ships, civilian vessels | Personal belongings, family messages, evacuation orders |

> **TODO**: Design 2-3 derelict layouts per zone.
> **TODO**: Define salvage point placement and rewards.
> **TODO**: Write derelict-specific lore content.

### 4.4 Economy

**Simple sell & buy.** No price fluctuation, no trade routes, no market manipulation.

- Sell scrap and resources at stations for credits
- Buy upgrades, fuel, repairs with credits
- Different stations stock different upgrades appropriate to their zone
- Repair and refuel services available at functional stations
- The focus is on exploration, not economics - credits are a means to upgrades, not an end

**Station inventories by planet:**
| Station | Sells | Buys |
|---------|-------|------|
| SR-7 (Home) | Basic upgrades (hull, fuel, cargo tier 1-2), repairs, fuel | All common resources |
| KI-3 (Industrial) | Engine upgrades, advanced hull/cargo, some artifacts | All resources, premium price for industrial components |
| NT-12 (Research) | Scanner upgrades, radiation shielding, data analysis tools | Data cores, research materials |
| MV-1 (Military) | Heat shields, military-grade hull, combat artifacts | Military salvage, containment components |
| TERRA-0 (Homeworld) | Final-tier artifacts only | Anything (but who's buying at the end of the world?) |

> **TODO**: Balance resource values and upgrade costs across all tiers.
> **TODO**: Define repair/refuel pricing.

### 4.5 Upgrades

Two categories of ship upgrades that affect how the ship *feels*, not just its stats:

#### Practical Upgrades (Standard Scavenger Gear)

Every upgrade should be *felt* by the player, not just seen in stats. Some upgrades are pure stat improvements. Others unlock entirely new capabilities - new verbs the player didn't have before. These "new verb" moments are the most exciting upgrades in the game.

**Stat Upgrades** (improve existing capabilities):

| Category | Effect on Feel | Tiers |
|----------|---------------|-------|
| **Engine** | Thrust power, acceleration. Ship feels less sluggish. | 3 tiers |
| **Thrusters** | Turn speed, maneuverability. Tighter handling. | 3 tiers |
| **Hull** | Max integrity, collision resistance. Ship can take more punishment. | 3 tiers |
| **Fuel Tank** | Max fuel capacity. Longer range before returning. | 3 tiers |
| **Cargo Bay** | Max carry weight. More scrap per trip. | 3 tiers |
| **Thermal Systems** | Heat/radiation resistance. Required for inner system access. | 3 tiers (gating) |

**Capability Upgrades** (unlock new verbs):

| Upgrade | What It Unlocks | Why It's Exciting |
|---------|----------------|-------------------|
| **Tractor Beam** | Massively extends vacuum field range and pull speed. Before this, collection is a slow trickle at near-contact range. After: scrap streams in from across the screen. | Transforms the core loop. The single biggest quality-of-life moment in the game. Early-game tedium becomes mid-game satisfaction. |
| **Scanner: PULSE** (Tier 1) | Basic resource detection. Pings nearby resource nodes and containers on the minimap. | You can finally SEE where things are instead of flying blind. |
| **Scanner: DEEP SCAN** (Tier 2) | Reveals hidden resource caches and concealed containers that Tier 1 couldn't detect. Also shows resource density (how much is in a node before you harvest it). | Revisiting old zones with DEEP SCAN reveals things you flew right past. "That was there the whole time?" |
| **Scanner: RESONANCE** (Tier 3) | Detects hidden locations - cloaked derelicts, concealed stations, buried structures. Shows structural analysis of derelicts (where the salvage points are). | Entire locations appear that were invisible before. Old zones become new again. |
| **Scanner: ARTIFACT ECHO** (Titan tech) | Detects signals that shouldn't exist - Titan influence traces, anomalous transmissions, things behind solid objects. Sometimes shows things that aren't there. Or are they? | The scanner becomes unreliable and powerful simultaneously. The player sees more but trusts less. |
| **Hacking Suite** | Unlocks terminal interaction for data cores and high-value extraction. Before this, terminals are inaccessible ("INCOMPATIBLE INTERFACE" message). | Opens the entire lore/narrative collection system. The game's story literally unlocks. |
| **Salvage Arms** | Unlocks the timing minigame for sealed containers AND shatters debris into scrap on collision. Before this, sealed containers show "NO EXTRACTION TOOLS" and debris is pure hazard. After: containers are crackable and debris fields become resources. | Mid-tier resources become accessible. A new collection method enters the rotation. Debris fields are reframed from obstacle to opportunity. |

#### Mysterious Artifacts (The Titan's Tech)

Artifacts are salvaged from containment structures. They are **always mechanically superior** to their practical equivalents. This is the trap.

| Artifact | Replaces | Advantage | Unsettling Detail |
|----------|----------|-----------|-------------------|
| Resonance Core | Engine tier 3 | 2x thrust of best practical engine | Hums at a frequency you feel in your teeth |
| Phase Plating | Hull tier 3 | Absorbs damage instead of resisting it | The hull *heals* when damaged. Slowly. |
| Void Capacitor | Fuel tier 3 | Fuel consumption drops to near-zero | Fuel gauge occasionally reads negative values |
| Echo Array | Scanner tier 3 | Detects everything, even things behind objects | Sometimes shows things that aren't there. Or are they? |
| Thermal Lattice | Thermal tier 3 | Near-immunity to heat/radiation | Required for TERRA-0. The final gate. The final compromise. |

**The design intent:** The player MUST install artifacts to reach the endgame. Practical upgrades alone cannot get you to TERRA-0. The Titan has ensured that the only path forward requires using its own technology - pieces of its cage, repurposed into the tools that dismantle the rest of it.

> **TODO**: Full upgrade tree with specific stat values and costs.
> **TODO**: Define which containment structures yield which artifacts.
> **TODO**: Design the artifact installation moment - should it feel different from normal upgrades? A special animation? A sound?

### 4.6 Threats & Hazards

**No combat.** Danger is environmental and automated. The universe is indifferent, not hostile.

#### Environmental Hazards

| Hazard | Where | Effect |
|--------|-------|--------|
| **Debris collision** | Everywhere | Hull damage based on relative velocity. Dense fields are dangerous at speed. |
| **Radiation pockets** | NT-12+, near containment structures | Gradual hull damage without shielding. Scanner can detect and highlight them. |
| **Heat zones** | MV-1+, near sun | Constant hull drain without thermal upgrades. Intensity increases closer to sun. |
| **Gravitational anomalies** | TERRA-0, near containment nodes | Pull ship off course. Subtle near intact nodes, violent near damaged ones. |
| **Electromagnetic interference** | Near containment structures | Scanner and navigation disruption. UI glitches. (Or is that the Titan?) |

#### Automated Systems (Inner Tiers Only)

War-era automated defenses that don't know the war is over:

| System | Where | Behavior |
|--------|-------|----------|
| **Defense turrets** | MV-1 stations, warship wrecks | Track and fire at unidentified ships. Slow tracking, predictable patterns. Avoidable, not fightable. |
| **Patrol drones** | KI-3 shipyards, MV-1 perimeter | Follow set paths. Alert turrets if they spot you. Stealth/timing to avoid. |
| **Containment sentinels** | Near active containment nodes | Protect the prison infrastructure. The most dangerous automated threat. Must be disabled (via terminal hacking) before dismantling nodes. |
| **Moving machinery** | KI-3 factories | Robotic arms, conveyors, welding lasers. Not hostile - just operating on schedule. Hazardous to fly through. |

**Design philosophy:** These aren't enemies to fight. They're obstacles to navigate around, sneak past, or disable through terminals. The player's tools are patience, timing, and hacking - not weapons.

> **TODO**: Define turret behavior - tracking speed, projectile speed, damage values.
> **TODO**: Design patrol drone patterns.
> **TODO**: Design containment sentinel disable sequence (terminal hacking).

### 4.7 Death & Respawn

**Low punishment. The game barely acknowledges death. This is eerie once you know why.**

- Player dies (hull reaches 0) → explosion effect → fade to black
- Wake up at the last station docked at
- **All upgrades, credits, and progress persist**
- **Only current unsold cargo is lost** (you were carrying it, it's gone with the wreck)
- The station automaton greets you. Nothing seems different. (It isn't. This is a new you.)

Death is frictionless by design. The game doesn't punish you, doesn't lecture you, doesn't even really comment on it. It just... continues. This serves two purposes:
1. **Gameplay**: No pressure philosophy. Death is a setback (lost cargo), not a punishment.
2. **Narrative**: The casualness of respawning is itself a clue. Why does nobody mention that you just died? Why is everything exactly as you left it? Because the system is *designed* to make replacement seamless.

> **TODO**: Implement the subtle post-death changes (see Clone System section 3.2).

#### Fuel Depletion

**Running out of fuel is a death. The player just doesn't know it yet.**

When fuel hits zero, the ship goes completely dead. No thrust, no systems, no drift. The ship is a floating brick in the void. After a beat of silence:

1. **DISTRESS BEACON prompt appears** - The player must manually activate it. This moment of agency matters - they're choosing to call for help, sitting in a dead ship in empty space.
2. **"DISTRESS BEACON ACTIVE... AWAITING RESPONSE..."** - Text appears on screen. A slow fade to black begins.
3. **Wake up at the last station docked at.** The automaton greets you. Everything is normal.

**The rescue never happens.** The clone died alone in the dark, beacon pulsing into nothing. A new clone was activated at the station with the inherited mission state. The transition is designed to feel like a rescue early in the game - the player assumes they were towed back. But it's identical to death because it *is* death.

**The penalty:** All current unsold cargo is lost (same as hull-death), plus a small rescue/tow fee is deducted from credits. This makes fuel depletion slightly more punishing than combat death - you lose cargo AND pay for the "rescue" that never came.

**Late-game realization:** As the player learns about the clone system, the fuel death recontextualizes. The beacon was never answered. The "tow fee" is just the cost of activating a new clone. Every time they ran out of fuel, they died waiting in silence.

**Stranded clone ships:** Occasionally while exploring, the player will find ships matching their own drifting dead in space, distress beacons still weakly pulsing. These are procedurally placed (not tied to actual death locations) and serve as atmospheric reminders. Early on they're curiosities - "huh, someone else had the same ship." Late-game, after learning about clones, they're haunting. Each one is a *you* that ran out of fuel and never got rescued.

> **TODO**: Define the tow/rescue fee amount. Should scale with progression? Flat fee?
> **TODO**: Define how long the player sits in the dead ship before the beacon prompt appears. Long enough to feel the dread.

### 4.8 Pacing & Progression Timeline

#### Design Philosophy

**No time pressure. No hard gates. No locked doors.**

The solar system is fully open from the first moment. The player can point their ship at TERRA-0 and thrust. They will die - not because a wall stopped them, but because their ship melted, ran out of fuel, or was shredded by debris. The "gates" are the player's own ship capabilities. Upgrading isn't about unlocking access - it's about surviving further.

**Fuel is meaningful but fair**: Thrusting consumes fuel. Running out kills the ship - the player must activate a distress beacon and "wait for rescue" (see section 4.7). But fuel is cheap to buy, pickups exist in the field, and tank upgrades make range generous. Fuel creates trip planning, not anxiety.

**Every ship system is tested more aggressively closer to the sun:**
- Fuel drains faster (heat increases consumption)
- Hull degrades (radiation, heat, denser hazards)
- Cargo weight matters more (heavier = slower = more exposure time)
- Scanner is more necessary (hazards need to be detected and avoided)
- Thermal systems are the hard requirement (without them, hull drain is constant and lethal)

This creates a natural difficulty gradient where the player needs holistic preparation, not just one specific upgrade.

#### The Open World Gradient

Rather than zones with borders, the solar system is a continuous gradient of increasing hostility toward the sun:

```
VOID ←── SR-7 ──── KI-3 ──── NT-12 ──── MV-1 ──── TERRA-0 ──→ SUN
cold     cold      mild      warm       hot        extreme
safe     safe      moderate  dangerous  hostile     lethal
sparse   sparse    dense     dense      very dense  overwhelming
```

**Partial access is expected and encouraged.** A player at SR-7 with a couple of upgrades can dip into the edges of KI-3 space. They won't survive long, but they might grab a few high-value industrial components before retreating. This risk/reward dynamic is the economic engine:

- Safe zone resources: low value, low risk
- Next zone's edge: moderate value, moderate risk
- Deep in an unprepared zone: high value, high risk (death = lost cargo)

The bold player who pushes further earns more per trip but risks losing everything in their hold. The cautious player grinds safely but progresses slower. Both are valid.

#### Pacing Curve: Slow Start, Wide Middle, Fast End

```
Playtime distribution (approximate):

SR-7 ████████████████████████░░░░░░░░░░░░░░░░░░░░  ~30%  (slow, deliberate)
KI-3 ░░░░░░░░░░░░░░░░░░░░░░████████████████░░░░░░  ~25%  (expanding)
NT-12 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████  ~20%  (story-rich)
MV-1  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████  ~15%  (intense)
TERRA-0 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░██  ~10%  (endgame)
```

The game accelerates as it progresses. SR-7 is slow and deliberate - the player is learning, their ship is sluggish, trips are short. By MV-1, the player has warp gates, a responsive ship, good tools, and confidence. TERRA-0 is short and intense - by then, the story is doing the work, not the gameplay loop.

This mirrors the Titan's pull. Early game: the player barely moves. Late game: they're hurtling inward, unable (and unwilling) to stop.

#### The First 10 Minutes

The opening experience sets the tone for everything. Uneasy calm. The setting itself does the work - no tricks, no jump scares, no obvious hints. Just a too-friendly robot, a dead solar system, and the vast empty dark.

---

**Minute 0-1: Title Screen → Boot Sequence**

The player starts at the title screen. Standard menu: New Game, Continue, Settings. They hit New Game.

The CRT boot sequence plays as the game loads:

```
Initializing navigation systems...................[15%]
Loading stellar database.........................[30%]
Calibrating sensors..............................[45%]
Establishing station uplink......................[60%]
Synchronizing clone manifest.....................[75%]
Systems nominal..................................[100%]
```

That fifth line is there on the first boot. The player won't think twice about it. It's just technobabble in a loading screen. Later, it's the first thing they'll remember.

---

**Minute 1-2: Waking Up**

Black screen. A beat of silence.

The cockpit fades in. The player is docked at SR-7's station. The HUD is minimal - fuel bar, hull bar, tiny cargo readout. All full, all fine. Through the viewport: stars, the faint curve of SR-7's frozen surface below, the distant pinprick of the sun.

A beep on the ship's comms. Text appears:

```
> There you are. Took a while this time.
> Systems look good. You feeling okay?
> ...
> Anyway. There's scrap out there. Always is.
> Heading 140 looked promising earlier. Worth a look.
```

The Cheerful Guide. Warm, familiar. "Took a while this time" implies they were waiting. "This time" implies there were other times. The player has no context for any of this. It reads as a friendly greeting from the one friendly thing in the system.

No tutorial. No objective markers. No waypoints. Just a heading and a nudge.

---

**Minute 2-4: First Undock**

The player figures out the controls. Undock. The station recedes.

The ship is clunky with personality. It rattles faintly when thrusting. It overshoots turns slightly - not broken, just *old*. Like a used car with 200k miles that still runs fine but has its own ideas about steering. The player learns its quirks immediately: coast into turns, don't fight the momentum, let it drift.

The fuel gauge ticks down when thrusting. Not fast, but noticeably. It creates an instinctive awareness of distance - how far out is too far?

Heading 140. The player points that direction and thrusts. Black. Stars. The ice planet below. Nothing else.

Then - glinting. A cluster of debris, visible against the starfield. Tumbling hull fragments, loose wiring, frozen metal chunks. Close enough to reach on the first tank. The player's first "there's something over there" moment.

---

**Minute 4-7: First Collection**

The player flies into the debris cloud. Larger dark chunks tumble slowly - debris, dangerous to hit. Among them, smaller bright fragments glint amber against the black. Scrap.

The player holds the action button. A faint field flickers around the ship - barely visible, tiny range. Nearby scrap begins drifting toward the hull. Slowly. A metallic clink as the first piece connects. The cargo readout pulses: 1. Another clink. 2. The pull is lazy - you have to park yourself near each cluster and wait. It works, but it's clear this ship was not built for efficiency.

The small cargo bay fills fast. Maybe 8-10 units of common scrap. The player is already making decisions: keep grabbing or head back? The fuel gauge is a consideration but not a crisis.

Sealed containers are visible floating among the debris. The player tries to vacuum one. Nothing. No prompt. No explanation. The container just... exists, tantalizingly opaque. (Later: "NO EXTRACTION TOOLS" message when interacted with.)

The world is quiet. The ambient sound is almost nothing - the hum of the ship, the faint clank of debris bouncing off the hull. The sun is a dot. SR-7 is a frozen rock. The station is a smudge of amber light in the distance.

This is the tone. Not hostile. Not welcoming. Just... empty. The player is alone in the most fundamental way, and the only voice they've heard belongs to a machine that knows them a little too well.

---

**Minute 7-10: First Sale & The Loop Begins**

The player flies back to the station. Docking is simple. The store interface opens - terminal-style amber text on black.

Scrap sells for a few credits each. The total is modest. The store shows upgrades: Hull I, Fuel Tank I, Engine I, Cargo Bay I, Thrusters I. All affordable in 2-3 trips. The Scanner PULSE and Tractor Beam are listed too, but more expensive - aspirational purchases the player can see but can't reach yet.

The player sells, looks at what they can't yet afford, and undocks again. The loop is established:

**Fly out → collect → return → sell → repeat.**

It's simple. It's satisfying enough. And it's exactly what the system was designed to make them do - venture out, come back, grow capable, venture further. Toward the sun. Always toward the sun.

The Cheerful Guide might say something as they leave:

```
> Heading back out? Good.
> More where that came from. Always is.
```

Always is. Because the debris is the corpse of a civilization, and it's not going anywhere, and neither are you. But you don't know that yet. You just know there's scrap to grab and upgrades to buy, and the ship handles a little better every time you come back.

---

**What the player DOESN'T know at minute 10:**

- They're a clone (one of hundreds)
- The Cheerful Guide has performed this exact welcome routine hundreds of times
- "Took a while this time" is literal - this clone took longer to activate than usual
- The containment infrastructure they'll soon be dismantling is keeping something in the sun
- The scrap they're collecting is the remains of a war fought to stop exactly what they're about to cause
- The boot sequence told them everything on line 5

#### Full Progression Timeline

---

**PHASE 1: THE SCAVENGER (SR-7 - ~30% of playtime)**

*The player learns the loop. Trips are short. The world is quiet.*

The player wakes up docked at SR-7's station. The Cheerful Guide greets them, explains the basics. The immediate area around the station has sparse scrap fields - visible debris that the player can physically fly into to collect.

**Available at start:**
- SR-7 store: Hull I, Fuel Tank I, Engine I, Cargo Bay I, Thrusters I (stat upgrades, affordable in 2-3 trips each)
- Vacuum field scrap collection (hold action, slow trickle, tiny range - functional but tedious)

**Early SR-7 loop (trips 1-5):**
1. Fly out, hold action to vacuum scrap in (slow, short range), fill small cargo hold
2. Return, sell, buy Hull I or Fuel Tank I
3. Repeat with slightly longer range
4. Start noticing sealed containers floating in debris fields (can't open yet: "NO EXTRACTION TOOLS")
5. Start noticing faint unreadable blips at the edge of vision (no scanner yet)

**First major purchase: Scanner PULSE** (available at SR-7 store, costs ~5-6 trips of scrap)
- Transforms navigation. The minimap lights up with resource pings the player never knew were there.
- Debris fields that seemed sparse now show clusters of high-density nodes.
- Sealed containers and data terminals appear on the scanner as distinct icons.
- The player realizes they've been flying past resources constantly.

**Second major purchase: Tractor Beam** (available at SR-7 store, costs ~6-8 trips of scrap)
- **THE game-changing moment.** Collection transforms from tedious bump-and-grab to satisfying magnetic sweep.
- Scrap per trip roughly doubles because collection is so much more efficient.
- The player starts taking longer trips, pushing further from the station.
- The economy opens up - credits flow faster, the next upgrades come quicker.

**SR-7 exploration deepens:**
- With PULSE scanner, the player discovers scrap fields further from the station
- Debris density increases at the outer edges of SR-7's orbital zone
- The player notices the void in the distance - scanner goes dead near it, ship systems flicker
- Derelicts start appearing on scanner - cargo haulers and fuel transports. External salvage for extra resources.
- The Cheerful Guide mentions: "There's an old transit gate near the planet's equatorial orbit. Nobody's used it in ages."

**Late SR-7 (preparing to push out):**
- Player has Hull I-II, Fuel Tank I-II, Engine I, Tractor Beam, Scanner PULSE
- Ship feels noticeably better than at start - more responsive, tougher, more range
- The player can see KI-3 in the distance. Scanner shows faint readings from that direction.
- Bold players have already dipped into KI-3's edge and grabbed some industrial components worth 2x normal scrap.
- The Cheerful Guide hints: "I've heard the stations in the inner system stock tools we don't have out here. Salvage arms, terminal interfaces... real professional gear."

**SR-7 Warp Gate:** Found in orbit, offline. Reactivation requires resources + credits (~equivalent to 3-4 trips). Once active, enables fast travel TO SR-7 from any other active gate. This is the player's first gate - it feels like a test run.

---

**PHASE 2: THE EXPLORER (KI-3 - ~25% of playtime)**

*The game opens up. New tools. New resource types. First unease.*

**The journey to KI-3:**
- First trip is a real expedition. Fuel gauge drops noticeably. Minor heat warnings start appearing (cosmetic at this tier, not damaging yet).
- Space between planets is emptier but not void - scattered debris, the occasional derelict.
- Arriving at KI-3 is Beat 1: survival. The player made it.

**KI-3 Station (Beat 2: first dock):**
- Meet The Trader. Fast-beeping, enthusiastic, immediately calls you "partner."
- New upgrades unlock system-wide (available at SR-7 too now):
  - **Salvage Arms** (expensive - ~8-10 trips at KI-3 scrap values). Unlocks sealed container timing minigame.
  - **Hacking Suite** (expensive - ~8-10 trips). Unlocks terminal interaction for data cores.
  - Hull III, Fuel Tank III, Engine II, Thrusters II, Cargo Bay II
  - **Thermal Systems I** (first thermal upgrade - needed for NT-12)
  - Scanner DEEP SCAN (next scanner tier)
- The Trader pushes certain components: "You should check out the old manufacturing arrays. Premium salvage in there. I'll give you a good price."

**KI-3 environment:**
- Dramatically different from SR-7. Massive derelict shipyards. Moving machinery hazards.
- Dense debris fields with higher-value industrial components (~50-100% more valuable than SR-7 scrap)
- Sealed containers are abundant here (once Salvage Arms are purchased)
- Factories still running on loop - conveyor belts, robotic arms, welding lasers. Navigation hazards that reward careful flying.
- First containment structures visible: energy distribution nodes. The Trader frames dismantling them as "decommissioning unstable equipment" for credits.

**KI-3 progression:**
- Salvage Arms purchased → sealed containers unlock → new resource types (electronics, mechanical components)
- Hacking Suite purchased → terminals unlock → first data fragments readable → STORY OPENS UP
  - Manufacturing logs reveal the scale of wartime production
  - The player reads about "Project Leviathan" or whatever codename for the Titan
  - First hints that the infrastructure they're scrapping had a specific purpose
- Scanner DEEP SCAN → hidden caches revealed at KI-3 AND back at SR-7
  - NPC hint: "Your new scanner might pick up things you missed around SR-7"
  - Player returns to SR-7 and finds concealed resource nodes they flew past dozens of times
- Ship now visually has bolted-on plates, larger thrusters, visible tractor array, salvage arm mechanisms

**First containment dismantling:**
- The Trader offers a quest: "That old distribution node is leaking energy. Dangerous for everyone. Why don't you shut it down and salvage it? I'll pay double for the components."
- Player approaches the node, uses hacking terminal to disable it, then salvages components
- The components are notably more valuable than regular scrap
- This is the first piece of the Titan's cage the player removes. The game doesn't acknowledge this in any way.

**KI-3 Warp Gate:** Located near the shipyards. Reactivation costs more than SR-7's gate. Once active, KI-3 is instantly accessible from SR-7. The game's geography compresses. The player can now farm both zones efficiently.

---

**PHASE 3: THE INVESTIGATOR (NT-12 - ~20% of playtime)**

*The story takes over. Terminal-heavy. The player starts asking questions.*

**The journey to NT-12:**
- Requires Thermal Systems I at minimum. Without it, hull drain from radiation begins partway through the journey.
- The sun is visibly larger. Heat warnings are no longer cosmetic - they're functional.
- A player without thermal protection can push into NT-12's edges but will take damage. Bold players can grab a few things and flee.

**NT-12 Station (first dock):**
- Research station, eerily quiet. Automated systems maintain it perfectly. No permanent named NPC.
- New upgrades unlock system-wide:
  - **Scanner RESONANCE** (the big one - hidden locations, cloaked derelicts)
  - Thermal Systems II, Hull upgrades, Engine III
  - Upgraded Hacking Suite variants (faster terminal interaction, more capable decryption)
- The station terminals are dense with research data. The hacking suite works overtime here.

**NT-12 environment:**
- Orbital arrays of sensors and telescopes, all still pointed at the sun
- Cleaner, more intentional infrastructure than KI-3's industrial chaos
- Radiation pockets require scanner detection and avoidance
- Electromagnetic interference near research equipment disrupts navigation
- Containment structures here are monitoring nodes - the grid's "eyes"

**NT-12 is where the story accelerates:**
- Research logs describe studying "the subject" - clinical, detached language
- Scientific debate: is the Titan sentient? Can it communicate? Should they try?
- Military pressure: "Containment must proceed regardless of research findings"
- The player finds references to "personnel redundancy protocols" (cloning)
- First Titan influence on terminals: a line of text that doesn't match the log entry. A response to something nobody asked.
- Scanner RESONANCE reveals hidden locations at ALL previous zones:
  - SR-7: A cloaked research probe (data about early Titan observations)
  - KI-3: A concealed testing bay (prototype containment components - artifact-tier)
  - NT-12: Buried laboratory (deep research on the Titan's nature)

**The containment grid becomes visible:**
- From NT-12's orbit, the player can see lines of energy connecting structures around the sun
- A web of containment infrastructure, still active, still holding
- The monitoring nodes the player is encouraged to "decommission" are part of this web
- The player is removing the grid's eyes. It can no longer see what's happening in the outer system.
- A careful player might notice: every structure they've dismantled corresponds to a dark spot in the web.

**NT-12 Warp Gate:** Reactivation is expensive. The gate infrastructure here is more obviously integrated with the containment grid. The player might notice containment energy flowing through the gate's pylons when activated. Or they might not.

---

**PHASE 4: THE INSTRUMENT (MV-1 - ~15% of playtime)**

*Intense, fast, dangerous. The truth is becoming unavoidable.*

**The journey to MV-1:**
- Requires Thermal Systems II minimum. Heat is constant. Hull drain is real without protection.
- The sun dominates a quarter of the sky. The containment web is visible everywhere.
- Warship wreckage appears en route. The scale of the war becomes physical.

**MV-1 Station (first dock):**
- Military command station. Battle-scarred. Blast doors, empty weapons racks, tactical displays still running.
- Meet The Broken One. The most visibly compromised automaton.
- New upgrades unlock system-wide:
  - Thermal Systems III (maximum practical heat resistance - still not enough for TERRA-0)
  - Military-grade hull, engines, systems
  - **First artifacts available for purchase** - The Broken One's station stocks them
  - Scanner ARTIFACT ECHO (Titan-tech scanner, sees things that shouldn't be there)
- The Broken One struggles when presenting artifact upgrades. Their text glitches between sales pitch and warning:
  ```
  > This resonance core will-- DON'T-- will dramatically improve your engine output.
  > Highly recommended.
  > P L E A S E
  ```

**MV-1 environment:**
- Warship graveyards. Massive military vessels in decaying orbits.
- Automated defense turrets that track and fire. Avoidance-based, not combat.
- Patrol drones following old routes. Timing-based navigation through their patrol patterns.
- Containment sentinels protecting grid anchors - must be disabled via terminal hacking before dismantling.
- The memorial moon. Thousands of names carved in rock. No resources. No gameplay. Just names.

**The pacing accelerates here.** The player has warp gates, a fast ship, good tools. They move through MV-1 more quickly than previous zones - not because there's less content, but because they're more capable. The gameplay loop is tight and efficient. The story is doing the heavy lifting.

**Artifact acquisition:**
- Artifacts are found at containment structures (dismantling them) AND bought at MV-1's station
- They're expensive but dramatically superior to practical upgrades
- Installing each artifact visibly changes the ship - glowing, geometric, alien components
- The game increasingly relies on artifacts for progression. Practical upgrades plateau.
- **TERRA-0 requires artifact-tier thermal protection (Thermal Lattice).** There is no practical equivalent. The player MUST use the Titan's tech to reach the endgame.

**The truth becomes hard to ignore:**
- Military logs describe the containment operation in detail
- The containment grid status display at the station shows nodes going dark - the player's work
- The Broken One's awareness peaks here - they try to warn the player during moments of lucidity
- The ship's computer surfaces messages from unknown sources
- Scanner ARTIFACT ECHO reveals anomalous signals everywhere - traces of the Titan's influence throughout the system

**MV-1 Warp Gate:** Reactivating this gate causes a visible pulse in the containment web. The Broken One reacts with distress. It's the most obvious sign yet that the gates are connected to the containment system.

---

**PHASE 5: THE RELEASE (TERRA-0 - ~10% of playtime)**

*The end. Short, intense, atmospheric. The gameplay loop gives way to revelation.*

**The journey to TERRA-0:**
- Requires Thermal Lattice (artifact). Without it, the heat is instantly lethal.
- The sun is everything. It fills the sky. It IS the sky.
- The containment web is failing visibly - gaps, flickering nodes, dark sections.

**TERRA-0:**
- No traditional gameplay loop here. Resources are absurdly abundant but the player is past caring about credits.
- The cracked homeworld. Flying between continental fragments.
- City ruins in cross-section. Homes, schools, lives cut in half.
- The final containment anchors are here - massive structures fused into the planet's bones.
- The cloning bay is here. The player's origin. Rows of pods. A counter ticking down.
- The original engineer's personal quarters. Their logs. Their voice - the player's voice - talking about building the cage.

**The endgame is not a boss fight. It's a realization.**

By TERRA-0, the evidence is overwhelming. The player knows - or strongly suspects - what they've been doing. The final containment anchor is dismantled with full awareness. There is no trick, no surprise. The player does it because there is nothing else to do. They've come too far, used too much of the Titan's tech, dismantled too much of the grid. This is the only direction left.

**The player knows. They do it anyway.**

---

#### THE RELEASE SEQUENCE

**The Trigger:**
The player hacks the final containment anchor's terminal. The shutdown command executes. The containment grid - visible as lines of energy connecting structures across the solar system - flickers and goes dark, section by section, radiating outward from TERRA-0.

**Beat 1: Silence (0-10 seconds)**
- All audio cuts. Instantly. Engine hum, scanner pings, ambient drone - everything.
- Dead silence for an uncomfortable duration. Long enough that the player wonders if the game crashed.
- The containment grid is dark. Nothing is happening. Nothing at all.

**Beat 2: The Sun Dies (10-45 seconds)**
- The sun at the center of the map begins to dim. Slowly at first, then faster.
- The ambient light that illuminates the game world fades with it. Everything gets darker.
- The player still has partial ship control - they can fly, but there's a growing sense that it doesn't matter where they go.
- A shadow begins expanding outward from the center - not a circle, a *shape*. Something that doesn't conform to any geometry the game has used before. It moves across the 2D plane like something impossibly large passing through.
- The CRT aesthetic starts breaking. Scan lines tear. The amber palette shifts, inverts, flickers. The UI - which has been the player's constant companion for the entire game - becomes unrecognizable.
- The game's visual rules, maintained rigidly for the entire experience, are violated. This is the Titan's "voice" - the screen itself.

**Beat 3: The Messages (45-90 seconds)**
- As the world goes dark, three transmissions arrive. One from each automaton. Final messages:

  **The Cheerful Guide:**
  Their screen flickers on one last time. A message the player has to read in near-darkness:
  ```
  > I remember all of you.
  > Every single one.
  > I'm sorry.
  ```
  Then their signal cuts.

  **The Trader:**
  ```
  > It was never about the credits, partner.
  > I hope you found something worth more.
  ```
  Signal cuts.

  **The Broken One:**
  For the first time in the entire game, their text doesn't glitch. Clear, coherent, steady:
  ```
  > I tried to tell you.
  > I tried to tell all of you.
  > I don't think it matters anymore.
  > Thank you for listening, even when you couldn't hear me.
  ```
  Signal cuts.

- After the last message, silence again. Total darkness except the player's ship instruments, which are failing one by one.

**Beat 4: Systems Failure (90-180 seconds)**
- The player's ship systems fail in sequence:
  1. Scanner goes dark (minimap disappears)
  2. Ship's computer terminal stops responding
  3. HUD elements fade - cargo, then fuel, then hull readouts
  4. Thrust weakens - the ship responds sluggishly, then barely, then not at all
  5. The player drifts. They can do nothing but watch the last of their instruments go dark.
- The game world is almost entirely black now. The shadow/shape from the center has enveloped everything. Occasionally something - a line, a curve, a suggestion of impossible scale - is visible for a frame before vanishing.
- The player's ship is the last point of light. Then it isn't.

**Beat 5: The Boot Sequence (After blackout)**
- Black screen. Long pause.
- Then, familiar: the CRT flicker of the game's boot/loading sequence begins.
- But the messages are wrong:

  ```
  Initializing navigation systems.....................[OK]
  Loading stellar database...........................[OK]
  Calibrating sensors................................[OK]
  Establishing communication arrays..................[OK]
  Verifying containment grid status..................[NOT FOUND]
  Searching for operator.............................[NOT FOUND]
  Searching.........................................
  Searching.........................................
  ```

- The boot sequence is initializing something new. Something that isn't the player's ship.
- The progress bar fills. The percentages climb. The system is starting up.
- It cuts mid-boot. We never see what loads.
- Hard cut to black. No credits text. No "THE END." No music.
- The game returns to the title screen after a long pause. The title screen is subtly different - the starfield is darker, the amber text flickers in a way it didn't before.

> **TODO**: Write the exact boot sequence messages for the ending.
> **TODO**: Design the shadow/shape visual - what geometry represents something beyond comprehension in 2D?
> **TODO**: Define the exact timing of each beat (playtesting will determine what feels right).
> **TODO**: Design the altered title screen - what's different?
> **TODO**: Determine if the save file is affected. Can the player reload? Is the game "over" permanently? Or does it reset?

---

#### Economy & Upgrade Cost Summary

**Resource values by zone:**
| Zone | Common Scrap Value | Sealed Container Value | Data Core Value |
|------|-------------------|----------------------|-----------------|
| SR-7 | 5 CR | 15-25 CR | 30-50 CR |
| KI-3 | 8 CR | 25-40 CR | 50-80 CR |
| NT-12 | 12 CR | 40-60 CR | 80-120 CR |
| MV-1 | 18 CR | 60-100 CR | 120-200 CR |
| TERRA-0 | 25 CR | 100+ CR | 200+ CR |

**Upgrade cost tiers (approximate):**
| Upgrade Type | Cost Range | Trips to Afford (at current zone) |
|-------------|-----------|----------------------------------|
| Stat Tier I (Hull I, Fuel I, etc.) | 15-30 CR | 2-3 trips |
| Stat Tier II | 50-80 CR | 3-4 trips |
| Stat Tier III | 120-200 CR | 4-6 trips |
| Scanner PULSE | 40 CR | 5-6 trips (SR-7 scrap) |
| Tractor Beam | 60 CR | 6-8 trips (SR-7 scrap) |
| Salvage Arms | 100 CR | 8-10 trips (KI-3 scrap) |
| Hacking Suite | 100 CR | 8-10 trips (KI-3 scrap) |
| Scanner DEEP SCAN | 150 CR | 6-8 trips (KI-3 scrap) |
| Scanner RESONANCE | 250 CR | 6-8 trips (NT-12 scrap) |
| Scanner ARTIFACT ECHO | 400 CR | 5-7 trips (MV-1 scrap) |
| Artifact upgrades | 300-600 CR | 4-8 trips (MV-1 scrap) |
| Warp Gate reactivation | 50-200 CR (scales by tier) | 3-5 trips |

**Store stocking rule:** New upgrades become available at ALL stations once the player first docks at the station that originally stocks them. First visit to KI-3 unlocks Salvage Arms and Hacking Suite at SR-7's store too.

**Key economic principle:** The player should always have 2-3 things they're saving toward simultaneously. There should never be a moment where there's nothing to buy and nowhere to go.

> **TODO**: Playtest and balance all values. These are starting estimates.
> **TODO**: Define exact resource spawn rates per zone.
> **TODO**: Define containment structure salvage values (should be notably high to incentivize dismantling).

### 4.9 Progression System

#### The Upgrade Journey

The player starts with almost nothing and gradually builds a capable vessel. The key design principle: **every upgrade should change how you play, not just how well you play.** Numbers going up is satisfying, but a new tool that transforms your interaction with the world is *exciting*.

**Starting loadout (the bare minimum):**
- Basic engine (slow, heavy thrust)
- Basic hull (fragile)
- Small fuel tank (short range)
- Small cargo bay (few trips before full)
- Basic vacuum field only (hold action to slowly pull nearby scrap - tiny range, slow pull)
- No scanner (fly by sight alone - the minimap shows nearby things but no resource detection)
- No terminal access (can't interface with data systems)
- No sealed container tools (containers are visible but inaccessible)
- No thermal protection (inner system is lethal)

The early game is intentionally limited. The player is a scavenger with a wrench and a dream. Each upgrade peels back a layer of the game they didn't know was there.

**Upgrade acquisition order (approximate - player has some freedom):**

```
Early SR-7:
  Hull I ──────────── Survive more bumps
  Fuel Tank I ──────── Range to reach further debris fields
  Engine I ─────────── Ship starts to feel less like a brick
  Scanner: PULSE ───── "Oh, THAT'S where the resources are"
  Tractor Beam ─────── *** GAME-CHANGING MOMENT ***
                        Scrap collection transforms entirely

Mid SR-7 → KI-3 transition:
  Cargo Bay I ─────── More scrap per trip
  Salvage Arms ─────── Sealed containers are now accessible (timing minigame unlocks)
  Hull II ─────────── Survive the industrial shipyards
  Fuel Tank II ────── Range to reach KI-3

KI-3 → NT-12 transition:
  Scanner: DEEP SCAN ── Hidden caches revealed. Old zones have new secrets.
  Hacking Suite ──────── Terminals unlock. The STORY opens up.
  Engine II ──────────── Ship feels genuinely responsive now
  Thermal I ──────────── Can survive mild radiation (NT-12 access)

NT-12 → MV-1 transition:
  Scanner: RESONANCE ── Hidden locations revealed. Cloaked derelicts appear.
  Thermal II ─────────── Heat resistance for inner system
  Hull III ───────────── Military-grade durability
  Various stat upgrades ── Preparation for the war zone

MV-1 → TERRA-0 transition:
  Thermal III ────────── Still not enough for TERRA-0
  *** ARTIFACT THRESHOLD ***
  Artifact upgrades ──── Required to survive solar proximity
  Scanner: ARTIFACT ECHO ── See things that shouldn't be there
  Thermal Lattice (artifact) ── The final gate. The final compromise.
```

#### Revisiting Old Zones

**Resources:** Common scrap respawns over time (debris keeps drifting in from elsewhere in the system). Sealed containers and data cores are one-time finds. This means old zones are never "empty" for basic grinding, but the interesting discoveries don't reset.

**Scanner-gated content:** Each scanner tier reveals new things in ALL zones, not just the current one. This is the primary reason to revisit:

| Scanner Tier | What It Reveals in Old Zones |
|-------------|------------------------------|
| **PULSE** | Basic resource nodes. (Player had nothing before this.) |
| **DEEP SCAN** | Hidden caches concealed in asteroid interiors, behind debris, inside derelict hulls. Resources the player flew right past dozens of times. |
| **RESONANCE** | Entire hidden locations - a cloaked research probe at SR-7, a concealed weapons cache at KI-3, a buried lab at NT-12. These are substantial discoveries with unique lore. |
| **ARTIFACT ECHO** | Anomalous signals. Traces of the Titan's influence. Things that may or may not be real. The most unsettling discoveries in the game. |

**NPC and environmental hints (organic, never checklist-based):**
- After getting DEEP SCAN, an automaton might casually say: "Your new scanner array is impressive. I wonder what you'd find if you swept the old fields around SR-7 again."
- The ship's computer logs anomalies: "DEEP SCAN calibration complete. Anomalous readings detected in previously surveyed sectors."
- A derelict's data log mentions "the concealed cache at [coordinates in an earlier zone]"
- None of these are quest markers. No indicators on the map. No completion percentages. Just diegetic hints that reward attentive players.

**NPC favors (organic side content):**
- Automatons occasionally mention things they want: "I've been trying to find a specific data core from one of the old research probes. If you ever come across one..."
- These aren't tracked quests with UI indicators. The player either remembers or they don't.
- Fulfilling a favor deepens the relationship and unlocks unique dialogue (and sometimes unique lore about the automaton's own awareness of the Titan's influence)
- The Trader might want specific components. The Broken One might want proof of something they half-remember.

**Environmental puzzles (discoverable, not signposted):**
- Scanning three specific objects in a zone triangulates a hidden signal
- A derelict's nav computer has coordinates that point to a location in a different zone
- A data fragment from NT-12 references a hidden compartment on a specific derelict at KI-3
- These reward exploration and cross-referencing but are never marked as objectives

#### The Three-Beat Tier Transition

When the player first reaches a new planet, three things happen in sequence. This is the "I made it" moment:

**Beat 1: Survive the Journey**
The first trip to a new planet is harrowing. The player barely has the gear. Heat warnings, hull warnings, fuel gauge dropping. Arriving alive feels like an achievement. The new zone's hazards are at the edge of what the player can handle - not impossible, but not comfortable.

**Beat 2: First Dock**
Docking at the new station for the first time. New NPC (or new state of existing NPC). New upgrades available in the store. New lore on station terminals. The station IS the reward - a safe harbor in a zone that just tried to kill you. This is where the player exhales.

**Beat 3: Gate Activation**
Reactivating the warp gate at the new planet. This requires resources and credits - it's a significant investment. But once active, the planet is permanently accessible via fast travel. The player has *claimed* this territory. The system is theirs now.

This three-beat sequence repeats for each tier transition and should feel like a satisfying chapter break every time.

#### Ship Visual Transformation

The ship visually changes with every upgrade, telling the story of the player's journey:

**Practical upgrades** add visible components gradually:
- Hull plating: visible armor plates bolted to the hull, increasing with each tier
- Engine upgrades: thruster nozzles get larger, exhaust effects change
- Fuel tank: external fuel pods attached to the hull
- Cargo bay: visible storage containers strapped to the ship
- Tractor beam: a visible emitter array on the ship's underside
- Scanner: antenna arrays, dish receivers growing on the hull
- Thermal systems: heat-resistant plating, visible cooling vents

The ship starts as a clean (if ugly) junker and gradually becomes a **patchwork monster** - covered in bolted-on components, strapped-down containers, and jury-rigged systems. It should look like something built by a person who keeps finding useful junk and attaching it. Because that's exactly what it is.

**Artifact upgrades** are visually distinct and unsettling:
- Artifact components glow - a faint pulsing light that doesn't match the amber palette
- They look *different* from the practical junk - smoother, more geometric, almost organic
- The more artifacts installed, the more the ship looks like two things bolted together: a human junker and something *else*
- Late-game: a ship with full artifacts looks alien. The player should be able to see the Titan's influence on their own vessel.

> **TODO**: Design ship sprite/visual system for modular upgrade appearance.
> **TODO**: Define the specific visual for each upgrade tier.
> **TODO**: Design artifact visual language - what does Titan-tech look like?
> **TODO**: Define warp gate activation cost and sequence.

---

## 5. STORY & NARRATIVE

### 5.1 Storytelling Delivery

Lore is delivered through **every available channel**, layered so that engaged players get a richer picture:

| Channel | Content Type |
|---------|-------------|
| **NPC Dialogue** | Active story progression. Automatons give quests, hints, and misdirection. Rare human NPCs provide perspective. |
| **Environmental** | Derelict ships with crew logs. Abandoned stations with terminal entries. Wreckage that tells a story through its arrangement. |
| **Ship's Computer** | Onboard terminal surfaces corrupted logs, system alerts, and increasingly strange messages. Main vehicle for Titan influence hints. |
| **Data Fragments** | Collectible lore items - war records, personal diaries, scientific reports, military orders. Pieced together by the player. |

### 5.2 Narrative Arc

**Act 1 - The Scavenger** (Outer Rim)
- Player wakes up, learns the ropes
- Meet friendly automatons at home station
- Establish the loop: fly, scrap, sell, upgrade
- Tone: Lonely but hopeful. A hard life but an honest one.

**Act 2 - The Explorer** (Mid-System)
- Ship is upgraded enough to push inward
- Encounter more complex structures and richer debris
- Automatons start giving quests that involve "decommissioning" old infrastructure
- First artifacts found - dramatically better than normal upgrades
- Environmental storytelling hints at the war and what these structures were for
- Tone: Wonder and growing unease. Something doesn't add up.

**Act 3 - The Instrument** (Inner System)
- The containment grid is visible and clearly not random war debris
- Ship's computer starts surfacing messages that don't match any known source
- Automatons' helpful suggestions become harder to distinguish from compulsions
- Player's amnesia cracks - fragments of memory surface
- The player is deep enough that turning back means abandoning everything they've built
- Tone: Dread wrapped in curiosity. The sunk cost is real.

**Act 4 - The Release** (Solar Proximity)
- The truth is unavoidable. The structures were a prison. The player has been dismantling it.
- The Titan's nature is revealed but **remains ambiguous**
  - Was it imprisoned justly? Was it dangerous, or was it feared?
  - Did the war start because of it, or was it a casualty?
  - Are the automatons corrupted, or were they always meant to do this?
  - Is the void keeping things out, or keeping this thing in?
- The player completes (or has already completed) the final act of dismantling
- **The ending is ambiguous.** The Titan is freed. What happens next is left to interpretation.

> **TODO**: Write detailed beat sheet for each act.

### 5.3 The Automatons

**Physical form:** Humanoid but clearly robots. Bipedal, head/torso/limbs - no attempt to pass as human. Exposed joints, visible wiring, screen-faces. They fit the cassette-futurism aesthetic: chunky, functional, held together with the same duct-tape-and-dreams philosophy as everything else.

**Communication:** Beeps and chirps (R2-D2 style emotional expression) with text displayed on their face-screens or nearby terminals. No voice synthesis. The beeps convey tone and emotion; the text conveys meaning. This makes them endearing - you learn to read their moods from sound alone.

**Awareness:** The automatons are **partially aware** that something is wrong with them. They have moments of lucidity or doubt - a pause before giving a quest, a beep that sounds more like a sigh, text that starts to say one thing then corrects itself. They can't fully articulate what's wrong or act against their compromised programming, but they *feel* it. This makes them victims too, which complicates the "betrayal" - can you be angry at someone who was crying while they lied to you?

**The clone factor:** Every named automaton has greeted hundreds of previous clone-players. They remember all of them. They pretend each one is the first. This is its own kind of horror - imagine greeting the same person over and over, knowing they'll die and a new copy will show up asking the same questions. Some handle this better than others.

---

#### NPC #1: [NAME TBD] - "The Cheerful Guide"

**Location:** Home station (Outer Rim - first NPC the player meets)
**Role:** Quest-giver, tutorial companion, emotional anchor
**Personality:** Upbeat, encouraging, relentlessly positive. Always has a task for you. Celebrates your wins, brushes off your losses. Makes the home station feel like *home*. The kind of presence that makes a bleak universe feel survivable.

**The truth beneath:** Their enthusiasm is genuine - they really do care about the player. But their suggestions are compromised. Every "oh, you should check out this interesting signal!" and "I heard there's valuable scrap near that old pylon" is the Titan steering through them. They're the friendliest leash in the solar system.

**Awareness level:** Low. They have the fewest moments of doubt. Occasionally their text display will stutter or they'll pause mid-beep, but they recover fast. Of the three, they're the most thoroughly compromised - which is why they're the most convincingly helpful.

**Clone relationship:** They've done this welcome routine hundreds of times. Their cheer might be genuine, or it might be a coping mechanism calcified into programming. Late-game, the player might find logs where this automaton's text was much less cheerful with clone #3 or clone #47.

**Quest types they give:**
- "Go collect scrap from [location that happens to be near containment infrastructure]"
- "A signal appeared near [containment node] - might be valuable salvage!"
- "That old structure is unstable and dangerous - you should dismantle it before it collapses on someone"

---

#### NPC #2: [NAME TBD] - "The Trader"

**Location:** Mid-system station (encountered when player pushes inward)
**Role:** Upgrade vendor, comic relief, world-building through commerce
**Personality:** Entrepreneurial, wheeling-and-dealing, fast-talking (fast-beeping?). Treats every transaction like it's the deal of a century despite the economy being functionally dead. Has opinions about everything. Calls the player "friend" or "partner" immediately. Their enthusiasm for trade in a post-apocalyptic wasteland is absurd and charming.

**The truth beneath:** The upgrades they push hardest are always the artifacts - the Titan's tech. They frame containment components as "premium salvage" and artifact upgrades as "real quality stuff, not like that standard junk." Their salesmanship is the Titan's recruitment pitch wearing a shopkeeper's apron.

**Awareness level:** Medium. They have more frequent moments of doubt than NPC #1. Sometimes mid-pitch, they'll stop, their screen will flicker, and they'll quietly beep before continuing as if nothing happened. Occasionally their text will display something like "you should not--" before correcting to "you should not miss this deal!" If the player pushes on these moments in dialogue, the trader deflects with humor.

**Clone relationship:** They've sold the same upgrades to hundreds of yous. They have a patter, a rhythm, callbacks to jokes the current player never heard. Sometimes they'll reference something "you said last time" and then awkwardly correct themselves.

**Quest types they give:**
- "I've got a buyer for [containment components] - big payout if you can source them"
- "There's a cache of premium parts in [containment structure] - I'll give you a finder's fee"
- "Install this artifact - trust me, it's top shelf. Best I've ever seen. Where did it come from? Don't worry about it."

---

#### NPC #3: [NAME TBD] - "The Broken One"

**Location:** Inner system station (late-game encounter)
**Role:** The alarm bell. The cracks in the facade made manifest.
**Personality:** Underneath the damage, they were probably once warm, competent, maybe even funny. Now they glitch between states - moments of clarity interrupted by Titan-influenced directives, coherent sentences that dissolve into static, beeps that shift from conversational to distressed mid-tone. Talking to them feels like watching someone fight a current that keeps pulling them under.

**The truth beneath:** They are the most visibly compromised automaton, but paradoxically the most *aware*. Their proximity to the inner system (and the Titan) means the influence is strongest here, but it also means they can feel it most clearly. They *know* something is using them. They fight it. They mostly lose.

**Awareness level:** High - painfully so. Their text display sometimes shows two messages simultaneously - what they want to say and what the Titan wants them to say. They'll give the player a quest and then immediately beep in a way that sounds like distress. In rare moments of clarity, they might say something like:

```
> DON'T LISTEN TO--
> ...
> The salvage coordinates are uploaded to your nav system.
> Please hurry.
```

**Clone relationship:** They remember everything. Every clone. They've tried to warn previous ones. It never works - either the clone doesn't listen, or the Titan reasserts control before the message gets through, or the clone dies and a new one shows up with no memory of the warning. This automaton is exhausted in a way machines shouldn't be able to be.

**Quest types they give:**
- Quests that directly dismantle the final containment structures, delivered with visible reluctance
- Occasionally gives contradictory instructions - "go here" immediately followed by "don't go there"
- May try to give the player a quest that ISN'T Titan-influenced, only to have their text overwritten mid-display

> **TODO**: Name all three automatons. Names should feel functional/industrial (serial numbers? callsigns? names they chose for themselves?).
> **TODO**: Write sample dialogue for each across early/mid/late game.
> **TODO**: Design the specific "awareness moments" - what triggers them, how long they last, what the player can do during them.
> **TODO**: Define quest lines for each NPC and how they escalate toward containment dismantling.

### 5.4 The Titan's Influence on the Player

As the player progresses inward and dismantles more containment infrastructure, the Titan's influence grows. This manifests through **both UI changes and gameplay shifts**:

**UI / Aesthetic Creep:**
- CRT distortion increases subtly over time
- HUD elements occasionally glitch or display wrong values briefly
- Terminal text sometimes includes characters or words that weren't there
- The amber color palette may shift slightly toward warmer/more unsettling tones
- Static and interference in comms
- Loading screen boot messages become... different

**Gameplay Shifts:**
- Ship occasionally drifts toward the sun (very subtle, correctable)
- Scanner picks up signals that shouldn't be there
- New "dreams" or visions play between certain missions (brief, abstract, unsettling)
- The ship's computer becomes more conversational, more helpful... more like a friend
- Artifacts become increasingly powerful, creating genuine mechanical incentive to keep using them

> **TODO**: Define specific trigger points for each influence escalation.
> **TODO**: Design the "dream" sequences.

---

## 6. AESTHETIC & AUDIO

### 6.1 Visual Style

See `CLAUDE.md` for detailed visual guidelines. Core principles:

- **Cassette futurism** - CRT monitors, amber phosphor, tape drives, blinking indicator lights
- **Monospace everything** - Terminal-style UI throughout
- **Black and amber** - Primary palette, never deviate
- **Minimalist** - No gradients, no polish, no sleekness. Functional and worn.

### 6.2 Audio Direction

**Layered approach based on context:**

| Context | Audio |
|---------|-------|
| **Stations** | Lo-fi ambient - cassette warble, degraded samples, mechanical hum, distant clanking |
| **Deep space** | Near-silence - ship sounds only. Engine hum, hull creaks, scanner pings. Isolation. |
| **Discoveries** | Synth swells - analog oscillator tones for moments of wonder or revelation |
| **Creature influence** | Subtle wrongness - frequencies that shouldn't be there, reversed audio, sub-bass rumble |
| **Key story moments** | Full dark synth compositions - Blade Runner meets Alien: Isolation |

The silence of space is a feature, not a gap. Music should be earned and impactful.

> **TODO**: Define specific audio cues for game events (docking, harvesting, damage, alerts).
> **TODO**: Create audio reference playlist.

---

## 7. TECHNICAL NOTES

### 7.1 Current Implementation

What exists in the codebase today:

- [x] Ship with state machine (Flying, Landed, Harvesting, Destroyed states)
- [x] Planet system with orbital mechanics
- [x] Resource spawning in orbital rings
- [x] Harvesting minigame
- [x] Space station docking
- [x] SpacePort dialogue system
- [x] Store/upgrade UI
- [x] Inventory management
- [x] HUD with fuel, hull, cargo bars
- [x] Minimap with radar-style display
- [x] Loading screen with boot sequence
- [x] Start menu
- [x] Pause menu
- [x] Game over / death screen
- [x] Save system
- [x] Star field shader background

### 7.2 Needed Systems

What needs to be built:

- [ ] Warp gate construction and fast travel
- [ ] Multi-planet solar system with tier progression
- [ ] NPC / Automaton dialogue system (beyond current SpacePort)
- [ ] Quest system
- [ ] Data fragment / lore collectible system
- [ ] Ship's computer terminal interface
- [ ] Creature influence system (UI distortion, gameplay effects)
- [ ] Dream/vision sequence system
- [ ] Artifact upgrade category (separate from standard upgrades)
- [ ] Derelict ship exploration encounters
- [ ] The void boundary system
- [ ] Environmental storytelling props/scenes
- [ ] Multiple station types with different inventories
- [ ] Tractor beam / physics-based collection
- [ ] Sound system and audio management

---

## 8. OPEN QUESTIONS

### Answered
- ~~What is the Titan?~~ **The Titan** - a human-made AI weapon that transcended its design, fused with the sun during containment
- ~~What caused the war?~~ The Titan. Built as a weapon, it destroyed minds (method debated), couldn't be destroyed, only contained.
- ~~Does it have desires?~~ Unknowable. Beyond human cognitive frameworks.

### Still Open
1. ~~Who was the original?~~ **A containment engineer** who helped build the Titan's prison. Template captured by military cloning bay.
2. **What IS the void?** Related to the Titan? A side effect of containment? The Titan's influence boundary? Something unrelated?
3. **Are there other humans?** Or is the player (and their clones) truly the last human presence in this system?
4. **What happens after the Titan is freed?** Does the solar system lose its sun? Does the Titan leave? Attack? Simply *be*?
5. **Warp gates** - new construction, or reactivating old containment infrastructure? (If the latter: another layer of the trap)
6. **The ship** - is the player's ship special? Or is it truly just a junker? Could it contain Titan-tech already?
7. **Game length** - target playtime for a full run?
8. **Save structure** - one save slot? Multiple? Permadeath? (The clone system reframes this question interestingly)
9. **The Titan's "voice"** - how does its influence feel aesthetically? What distinguishes Titan-corruption from normal CRT glitches?
10. **The war timeline** - how long ago? Are there living veterans, or is this ancient history?
11. **Clone predecessors** - did any previous clones get further? Learn the truth? Leave evidence of their discoveries?
12. **The amnesia source** - is it Titan-contact damage to the original? Or a cloning artifact? Or both?
13. **Automaton names** - serial numbers? Callsigns? Names they chose for themselves? What naming convention fits the world?

---

## 9. DEVELOPMENT PRIORITIES

Rough priority order for building out from the current prototype:

### Phase 1: Core Loop Polish
- Refine flight feel and resource collection
- Balance economy (resource values, upgrade costs)
- Add 2-3 resource types with different collection methods
- Polish station interaction flow

### Phase 2: World Expansion
- Build out multi-planet system with tier gating
- Implement warp gate system
- Create the void boundary
- Add en-route encounters

### Phase 3: Narrative Foundation
- Design automaton NPCs
- Build quest system
- Implement ship's computer terminal
- Write Act 1 content

### Phase 4: The Titan
- Implement influence system (UI + gameplay)
- Design artifact upgrade path
- Build dream/vision sequences
- Write Acts 2-3 content

### Phase 5: Endgame
- Inner system content
- Final revelation sequence
- Ending
- Write Act 4 content

### Phase 6: Polish
- Full audio pass
- UI distortion effects
- Environmental storytelling details
- Playtesting and balance

---

*This is a living document. Update it as decisions are made and the game evolves.*
