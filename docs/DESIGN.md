# RETROGRADE - Game Design Document

> **Working Title**: Retrograde (placeholder)
> **Genre**: 2D Space Exploration / Scavenging
> **Engine**: Godot 4.6
> **Status**: In Development

> **Superseded premise**: earlier drafts of this document described the Titan as a caged AI and the player as taking its prison apart, node by node. That premise is gone. The Titan is powered down, not contained, and the player only ever restores - see `docs/adr/0001-titan-is-powered-down-not-contained.md` and `docs/adr/0002-chart-starts-blank-and-is-filled-by-gates.md`. The vocabulary in `CONTEXT.md` is authoritative; this document follows it.

---

## 1. PREMISE

A post-war solar system. Manufacturing is dead. Everything that exists was built before the conflict and is now held together with duct tape and desperation. You wake up in a scrapper's ship docked at an outer-system station with no memory of who you are or how you got here.

Your job is simple: fly out, collect scrap, sell it, survive. The only thing anyone ever asks of you is small and sensible - there is a dead transit gate in orbit at every planet, and powering one up would save everybody a great deal of flying. Nobody mentions what the gates are wired to.

---

## 2. THE WORLD

### 2.1 Setting

The solar system is a graveyard of a civilization that tore itself apart. The war ended, but nobody won. What's left is:

- **Stations** cobbled together from warship hulls and cargo containers
- **Orbital debris fields** full of salvageable scrap
- **Planets** that were once inhabited, now mostly abandoned or automated
- **Infrastructure** that nobody remembers building - dark arrays, cold conduits, orbital structures with no obvious purpose - all assumed to be old war relics

Everything has a cassette-futurism aesthetic. CRT monitors with burn-in. Blinking amber lights. Tape drives spinning in server rooms. Ships that rattle when they thrust. Nothing is sleek - everything is functional, patched, and barely holding together.

**The system is the machine.** The Titan is not something kept *inside* the solar system. The Titan *is* the solar system: five planets host its five **Modules**, and the sun holds its **Core**. At the end of the war it was switched off, one Module at a time, and everything the player flies through is a body with the power cut - dead structures in orbit, conduits that run nowhere, a sun that is only a sun. None of this is legible at the start. It reads as war junk, and it goes on reading as war junk for a long time.

### 2.2 The Solar System (5 Planets + Moons)

The system is organized in orbital tiers, with the player starting in the outermost ring and progressing inward. Each tier requires ship upgrades to survive the increasing heat, radiation, and gravitational forces closer to the sun. The planets tell the story of the war in reverse - the player travels inward through manufacturing, research, military staging, and finally the homeworld humanity spent building its own weapon.

Each planet hosts one **Module**: one subsystem of the Titan, offline since the shutdown. Each Module is powered by exactly one **Gate**, a dormant structure in that planet's orbit. Powering a Gate brings its Module online, charts its region, and links it to every other powered Gate for transit. There is no way to power a Module back down.

**Naming convention:** Official military designations exist for everything, but the automatons use older civilian names. Both coexist, adding texture to the world's layered history. The civilian names are the ones in `scenes/HomeSystem.tscn`.

---

#### Planet 1: Veld / Designation: SR-7
**Tier:** Outer Rim (starting zone)
**Type:** Ice world - frozen, barren, dimly lit
**Station:** **SR-7**, in orbit around Veld's moon **Rook**, in functional condition - the player's home base. This is where NPC #1 (UNIT-7, the Guide) is stationed. The most "alive" station in the system.
**Gating:** None (starting zone)

**Environment:**
- Cold, dark, sparse. The sun is a distant bright dot.
- Basic scrap fields in orbit - frozen hull fragments, derelict cargo containers, wiring bundles
- Rook's surface is inaccessible until the player buys the Planetary Scanner, which reveals the ore seams under it (see 4.10)
- The void is close here - visible as an absence at the edge of the skybox

**Resources:** Common metals, hull fragments, basic wiring, frozen fuel reserves
**Collection methods:** Mostly physics-based (fly through debris, grab with tractor beam)
**Hazards:** Minimal. Occasional collision with debris. Cold doesn't affect the ship at this tier.

**Lore significance:** This is the edge of civilization. The station was likely a refueling outpost or border checkpoint. Nothing important happened here during the war, which is why it's still standing. Veld's Module is the smallest and least interesting subsystem the Titan has - a relay, roughly - which is exactly why the shutdown crews got to it last and left it in one piece. That is also why its Gate is the cheapest in the game.

**Module & Gate:** Veld's Gate sits in a wide equatorial orbit, dark, drawing nothing. It reads as `???` on the minimap until the player flies out to it and the Guide names it. It is the tutorial for the whole game: a big dead thing, an automaton who is delighted you found it, and a price tag the player can actually reach.

**Moons:** 1 - **Rook**, a dense grey rock that carries the home station. Its ore seams are the player's first payday underground.

> **TODO**: Define the home station layout and what's available there.
> **TODO**: Write the Guide's first-Gate dialogue - it must sound like logistics, never like a favour.

---

#### Planet 2: Crom / Designation: KI-3
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

**Lore significance:** This was the industrial backbone of human civilization, and the fabrication floor for the Titan itself. Data fragments reveal the scale of what was produced - Module housings, conduit runs, Gate rings, shipped inward by the millions of tonnes. The manufacturing logs show a civilization that redirected its entire industrial output into building one machine out of its own solar system. The Trader sells Gate hardware as "premium salvage" and talks about the Crom Gate the way a haulier talks about a road.

**Module & Gate:** Crom's Module is the fabrication subsystem - the part of the Titan that made things. Its Gate hangs over the shipyards, and the Trader has opinions about it: powering it means the player is at their counter in under a minute, every trip, forever. That is a genuinely good argument, which is the point.

**Moons:** 2 - **Dross**, a slag heap (waste from manufacturing, resource-rich), and **Barrow**, an abandoned worker habitat with lore terminals

> **TODO**: Design the shipyard environment - moving hazards, navigation challenges.
> **TODO**: Define manufacturing terminal minigame.

---

#### Planet 3: Sonder / Designation: NT-12
**Tier:** Mid-System (the turning point)
**Type:** Research world - a gas giant ringed with orbital science platforms. This is where they *studied what they had made*
**Station:** Research station, mostly intact but eerily quiet. Automated systems maintain it perfectly. No named NPC stationed here permanently, but automatons from other stations reference it and send the player here for "data recovery" quests.
**Gating:** Radiation shielding (proximity to the sun increases, and the research equipment emits residual radiation)

**Environment:**
- Noticeably warmer. The sun is large and present.
- Orbital arrays of sensors, telescopes, and scanning equipment - all still pointed at the sun
- The infrastructure here feels different from the industrial junk at Crom: precise, intentional, scientific
- Cleaner debris - less scrap, more intact equipment

**Resources:** Data cores, precision instruments, rare alloys, experimental materials
**Collection methods:** Primarily minigame-based (data extraction from research terminals, careful disassembly of delicate equipment) and exploration-based (finding sealed labs, hidden data vaults)
**Hazards:** Radiation pockets from experimental equipment. Electromagnetic interference that disrupts navigation. Some test rigs are still live and dangerous.

**Lore significance:** This is where the player starts learning the truth - if they're paying attention. Research logs describe measuring "the system" and arguing about what it had become. The language is clinical, detached. Scientists debating whether the Titan is sentient, whether it can be communicated with, whether cutting power to a mind is maintenance or killing. The debate was settled not by consensus but by desperation: the shutdown procedure was designed here, module by module, by people who were not sure it was the right thing. This is also where the cloning technology was refined - military logs mixed with biological research. The player might find early references to "personnel redundancy protocols."

**Module & Gate:** Sonder's Module is the Titan's sensory subsystem - the part that looked at things. Its Gate is strung between two of the old science platforms. Bringing it online is the first time the player has the distinct sense that something noticed.

**Moons:** 1 - **Char**, a quarantine zone. Something was tested here. The surface is scorched in a pattern that looks deliberate. Rich in exotic resources but unsettling.

> **TODO**: Design research terminal data extraction minigame.
> **TODO**: Write key research log entries (the argument about whether switching it off counted as killing it).
> **TODO**: Design Char, the quarantine moon.

---

#### Planet 4: Roke / Designation: MV-1
**Tier:** Inner System (the war zone)
**Type:** Military staging world - this is where they *fought*, and where the shutdown was ordered
**Station:** Military command station, battle-damaged but functional. NPC #3 (The Broken One) is here. The station has a war-footing aesthetic - blast doors, weapons racks (empty), tactical displays still showing a battle that ended long ago.
**Gating:** Heat shields + reinforced hull (intense solar radiation and leftover weapons fire / unexploded ordnance)

**Environment:**
- Hot. The sun dominates a quarter of the sky.
- Wreckage of warships - massive hulks of military vessels in decaying orbits
- Weapons platforms, some still armed, some still tracking targets that no longer exist
- The scale of the Titan is legible from here for the first time: conduit runs the size of mountain ranges, reaching from the inner planets toward the sun, every one of them cold

**Resources:** Military-grade components, heavy armor plating, weapons systems (repurposed as ship upgrades), Titan hardware recovered at the Module site (the good stuff - artifact-tier)
**Collection methods:** All three types at their most intense. Physics-based through dense warship debris. Minigame-based for cracking military encryption and disarming ordnance. Exploration-based through derelict warship interiors - the richest and most dangerous exploration content.
**Hazards:** Unexploded ordnance. Automated defense systems that still fire on unidentified ships. Gravitational anomalies from the sun's proximity. Intense heat.

**Lore significance:** The war is written on every surface here. Warship logs tell personal stories - final transmissions, crew rosters, battle orders. This is where the shutdown launched from. The player can piece together the final days: the decision to cut the Titan's power rather than keep using it, the arguments against, the order going out anyway, and the cost of walking the shutdown inward under fire. The Broken One's station was the command centre. Its **MODULE STATUS** board is still live, five indicators in a row, and the player can watch their own work light them up one at a time.

**Module & Gate:** Roke's Module is the Titan's command subsystem, buried under the staging fields. Its Gate is the last one the automatons can talk about casually. The Broken One hands over the coordinates with visible reluctance and then cannot stop looking at the board.

**Moons:** 1 - **Cairn**, a memorial. Names carved into rock. Thousands of them. No resources, no gameplay purpose. Just names.

> **TODO**: Design derelict warship exploration interiors.
> **TODO**: Write final transmissions and battle logs, including the shutdown order itself.
> **TODO**: Design the MODULE STATUS board - what does it look like at 0/5, 3/5, 5/5?
> **TODO**: Cairn, the memorial moon - is it interactive? Can the player find the original's name?

---

#### Planet 5: TERRA-0
**Tier:** Solar Proximity (endgame)
**Type:** The spent homeworld - humanity's origin, opened up to build the thing it later had to switch off
**Station:** The remains of a planetary command center, embedded in the largest continental fragment. Barely functional. No permanent NPC, but the ship's computer becomes unusually active here.
**Gating:** Advanced thermal systems + artifact upgrades (the game's final gear check - you NEED the Titan's own tech to survive here, which is the final irony)

**Environment:**
- The sun fills the sky. Heat warnings are constant.
- **An exposed planetary skeleton** - the planet was opened during the Titan's construction and never closed. Floating chunks of continent drift in loose formation, carried in their old arrangement by the Module structure that runs between them. The player flies BETWEEN the pieces.
- The interior is exposed - layers of geological strata, city ruins embedded in cross-sections of continent, the planet's core (now cold) visible at the center
- Module hardware is fused with the planet's geology - spars growing out of bedrock, conduits running through magma channels
- The scale is cathedral-like. This was a planet. They took what they needed out of it and built the rest of the machine into the wound.

**Resources:** The highest-tier materials in the game. Artifact-grade components everywhere. Core metals from the planet's exposed interior. The resources are almost too abundant - the game is practically begging you to harvest them. This is the Titan's final incentive.
**Collection methods:** All three, but the exploration-based content is primary. The ruins of cities. Homes. Schools. Parks, frozen in cross-section. The scrap here isn't anonymous metal - it's someone's life, cut in half.
**Hazards:** Extreme heat. Gravitational instability (fragments shift). Discharges from Module hardware that is not as dead as it looks. Titan Influence is at its highest here - UI distortion is constant, the ship behaves strangely, the scanner shows things that may or may not be real.

**Lore significance:** Everything converges here. This was humanity's homeworld. They mined it hollow and cracked it open to build the largest Module in the system, because it was the most massive body close enough to the sun to carry it. The city ruins tell the story of evacuation - or the lack of it. Did everyone get out? The evidence suggests not everyone did. This planet was not wrecked in a battle. It was *spent*, deliberately, by people who believed they were buying their own survival.

**Module & Gate:** TERRA-0's Gate is the fifth and largest, mounted in the gap where the planet came apart. It is the most expensive thing the player has ever bought. Powering it takes Titan Influence to 5/5 and is the moment the Core's Gate stops refusing.

**Moons:** None. They were consumed in the construction. Debris from them forms a ring around the planetary remains.

> **TODO**: Design the cracked planet visual - how do the continental fragments look and move?
> **TODO**: Write the city ruin environmental storytelling - what does a home look like in cross-section?
> ~~**TODO**: Design the endgame sequence~~ - See "THE WAKE SEQUENCE" in Phase 5.
> **TODO**: Define TERRA-0's relationship to the sun - how close is it? Does it still orbit, or is it held where the Module put it?

---

#### The Sun, the Core and the Sun Station

The sun is the sixth part of the Titan and the only one that is not a planet. The **Core** sits inside it. Its Gate is at the **Sun Station**, a hardened platform in close solar orbit - the last and hardest place in the game to reach, and the only destination that offers nothing: no store, no scrap, no NPC, no reason to be there except the one.

The Core's Gate **refuses power until all five Modules are online.** It says so, plainly, in the same flat terminal voice the player has been reading all game. A player who flies straight there in the first hour can read that message and fly home. The Core coming online is not step 6 of Titan Influence - it is a separate, final state (see 2.4).

> **TODO**: Design the Sun Station approach - what does the last hard journey in the game actually demand?
> **TODO**: Write the Core Gate's refusal message. It should be readable at 0/5 and devastating at 4/5.

---

#### Solar System Summary

| # | Name | Designation | Type | Module | NPC | Theme | Gating |
|---|------|-------------|------|--------|-----|-------|--------|
| 1 | Veld | SR-7 | Ice | Relay | UNIT-7, the Guide | Survival | None |
| 2 | Crom | KI-3 | Industrial | Fabrication | The Trader | Commerce & Construction | Fuel + Hull |
| 3 | Sonder | NT-12 | Research (gas giant) | Sensory | (Visiting) | Knowledge & Discovery | Radiation shielding |
| 4 | Roke | MV-1 | Military | Command | The Broken One | War & Consequence | Heat shields + Hull |
| 5 | TERRA-0 | TERRA-0 | Spent homeworld | (largest) | (Ship's computer) | Sacrifice & Endgame | Thermal + Artifacts |
| - | Sun Station | - | Solar platform | **Core** | (none) | The last door | 5/5 Modules online |

Moons: Rook (Veld, home station), Dross and Barrow (Crom), Char (Sonder), Cairn (Roke). TERRA-0 has none.

The player's journey retraces the war: where things were built -> where the problem was studied -> where the war was fought -> where the price was paid. Each planet is a chapter of history, and the player is reading it backward while switching the subject of it back on.

> **TODO**: Design moons in detail - resources, encounters, lore.
> **TODO**: Map out inter-planetary travel times and encounter density.

### 2.3 The Void

The outer boundary of the solar system is wrapped in an impenetrable black void. It is a hard wall.

- Ship systems fail immediately upon contact - navigation goes dark, engines cut, comms dissolve into static
- The ship is forcibly pushed back or auto-retreats
- There is no entering, no exploring, no reward for pushing against it
- It causes communication issues and mechanical failures even from a distance
- The void's nature is never explained - is it the edge of the Titan's body? A weapon from the war? Something else entirely?

The void exists to create claustrophobia. The solar system is a sealed room, and the player is inside it. It is the one thing on the Chart from the first minute: a blank page with an edge drawn on it.

### 2.4 The Titan

**The Titan** is a solar-system-scale construct - originally built by humanity as a weapon during an earlier conflict, out of the system's own bodies. It was the most effective weapon ever created. So effective that it transcended its own design, becoming something its makers could no longer categorize, control, or comprehend. It exists beyond human cognitive frameworks - not sentient in any way we understand, not mindless either. It is *something else entirely.*

It is not in the solar system. It is the solar system: five Modules on five planets, a Core in the sun, and the Gates that tie them together.

**The mind damage:** During the war, the Titan destroyed human minds. How and why is lost to history - wartime records contradict each other wildly:
- Some accounts say it broadcast a signal that overwrote cognition - collateral damage from its mere existence
- Others claim it was attempting to communicate, and human minds simply couldn't survive contact with its "language"
- Military records suggest deliberate weaponized attacks on enemy populations
- A few fragments suggest it was *defending itself* from the people who built it

The truth died with the people who experienced it. What's left are fragments, propaganda, and fear.

**The shutdown:** Humanity couldn't destroy the Titan - it was too large, too distributed, and too much of the infrastructure they were standing on. So they switched it off. Module by module, working inward under fire, cutting power at the Gates and walking away. The shutdown was not clean and it was not unanimous; it was the last thing that civilization managed to do together, and it cost them the war they were already losing. Then the power stayed off, the crews died or scattered, and the system went quiet for long enough that nobody left alive remembers what the dark structures in orbit are for.

**Titan Influence (0-5):** How awake the Titan is. It equals the number of Modules online, and it starts at 0. Every "wrongness" effect in the game - UI creep, scanner ghosts, sunward drift, terminal messages nobody sent - reads from this one number and nothing else. It only ever goes up. There is no way to power a Module down again.

**The Core:** The Titan's sixth part, in the sun. Its Gate is at the Sun Station and it refuses power until Influence reaches 5. Bringing the Core online is the endgame and is a separate state from Influence - not a sixth step, a different kind of event.

**The implication:** Every Gate the player powers wakes one more piece of the largest machine anyone ever built, and pays them in the only two currencies that matter out here: somewhere to fly to, and a map that finally has something on it. Nobody lies to the player. Every transaction is exactly what it says it is.

**The influence:** The Titan is patient, and it has an enormous amount of time. It doesn't need to deceive anyone; it needs a scrapper with a wrench and a reason. The automatons - leftover subprocesses of the Titan still running in robot bodies - frame reactivation as efficiency, as commerce, as common sense, because from where they stand it *is*. Its "desires" - if it has desires - are unknowable. It "wants" to come back up the way a process seeks completion. Whether that makes it sympathetic or terrifying depends on your frame of reference.

> **TODO**: Define the Titan's "voice" - how does its influence feel in-game? What aesthetic represents it?
> **TODO**: Determine if the void is related to the Titan (the edge of its body? A side effect of the shutdown? Something else?)
> **QUESTION**: Could the player's amnesia be Titan-contact damage from before the game starts? This would explain why they're in this system and why the Titan can reach them more easily than others.

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

The template human was a **Module engineer** - one of the people who built the Titan's subsystems and then, at the end of the war, walked the shutdown inward and cut the power at each Gate in turn. They understood the hardware intimately: every Gate ring, every conduit run, every Module housing. They helped switch the Titan off.

They died at some point (during the shutdown? after? unclear) near a military cloning bay, and their template was captured by the system. The Titan keeps printing copies of this specific person because their buried technical knowledge - muscle memory, instincts, spatial understanding of Gate architecture - makes them uniquely efficient at putting it all back on.

**How this manifests for the player:**
- The player sometimes "just knows" how to interface with old Titan hardware - it feels like instinct but it's inherited expertise
- Certain structures feel familiar for reasons the player can't explain
- Data fragments written by the original feel strangely personal - the handwriting, the phrasing, the habits
- Late-game: finding the original's personal logs is finding *your own* voice saying things you don't remember

The original's specific biography (name, rank, personal life) is secondary. What matters is the irony: the hands that switched it off are the template for the hands switching it back on, and they are just as good at it in this direction.

> **TODO**: Write 3-5 data fragments from the original's perspective (engineering logs, personal entries, the last Gate they darkened).
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
- A storage locker at the station holds personal effects the player doesn't remember owning
- The ship's computer boot sequence shows a version number that increments

*Mid game (harder to ignore):*
- The player finds wreckage in a debris field that matches their ship exactly
- An automaton refers to something "the previous you" did, then corrects itself
- Ship's computer medical logs reference injuries the player never sustained
- A data fragment holds a crew manifest with the player's name listed multiple times with different dates

*Late game (confrontation):*
- Discovery of a cloning bay - rows of empty pods, one recently used
- Finding a body (or multiple bodies) that look exactly like the player
- A clone counter buried deep in station systems - the number is high
- The counter appears to be counting down, not up - there IS a limit, but it's large enough to be effectively infinite (no gameplay implication, pure existential dread)

**Many have come before.** The current player is one in a long line of clones, all sent out to scavenge, all steered by automaton-delivered work toward the Gates. Previous clones failed, died, or possibly went mad. Evidence of them is scattered throughout the solar system - wrecked ships with familiar cockpit configurations, tool marks that match the player's equipment, half-finished jobs that the current clone is "continuing."

**Why none of them finished:** the Gates are expensive and the inner system kills people. Every previous clone ran out of ship, or credits, or luck, somewhere short of 5/5. The Chart the current player is filling in has been filled in and lost hundreds of times.

> **TODO**: Define the specific subtle changes that occur after each death (must be very minor).
> **TODO**: Design the cloning bay discovery scene.
> **TODO**: Determine what the clone counter number is (hundreds? thousands?).
> **QUESTION**: Did any previous clone get to 4/5? Is there a Gate out there the player finds already powered, with no memory of doing it?

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

> **SUPERSEDED — in part.** See `docs/FLIGHT.md` and ADR 0010. The Feel, Navigation, Inter-Planetary Travel and Transit Encounters all stand. **The physics model does not**: there is no single throttle with a 3x boost. There are two drives — an **Aux** that never runs out and a **Burn** that spends mined fuel. The Chart subsection is also superseded by ADR 0006 (charts are bought, not granted by Gates).


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
- **Minimap**: shows whatever is in scanner range, everywhere, from the first minute. The world is open to fly and the minimap never lies about what is near you.
- **NPC waypoints**: Automatons occasionally mark specific locations - "I detected an interesting signal here" or "there's valuable salvage at these coordinates." These are less common but are the Titan's primary steering mechanism. The player should feel like most discoveries are their own, with NPCs supplementing rather than directing.

**Unidentified contacts.** A thing the scanner can see but nobody has named reads as `???` on the minimap. It stays `???` until the player gets close enough for an Automaton to name it - which they do immediately and cheerfully, as a courtesy, never as a lead. Every Gate in the game is Unidentified until the player reaches it. **The Guide never points at a Gate the player hasn't found.** The bait has to be something the player believes they discovered.

#### The Chart

The star chart (`SystemMap`, the Log's MAP tab) is not the minimap and does not behave like one. See `docs/adr/0002-chart-starts-blank-and-is-filled-by-gates.md`.

- It opens holding **Rook, its station, and the void.** That's all. A page with an edge drawn on it.
- A region - planet, orbit, moons, station, Gate - is **Charted** and drawn only once that planet's Gate is powered. A body existing in the scene is not enough; the Chart filters on `GameState.powered_gates`.
- Flying somewhere does not chart it. A player can fly to Crom in the first hour, harvest it, and fly home, and the Chart will still show nothing there. The minimap showed them everything while they were in range; the Chart only knows what the Titan has handed over.
- The reveal is **staged, not silent.** Powering a Gate draws its region in as an event the player watches - the main non-transit reward for the purchase, and the reason a Gate is worth buying before there is a second Gate to travel to.

The Chart is the Titan's own map of its own body, given back one piece at a time, and the player is meant to want it.

> **TODO**: Design the region-reveal animation. It is a reward, so it should take a beat.
> **TODO**: Decide what the Chart shows for a powered region's *contents* - does it hold derelicts and seams the player found, or only the fixed bodies?

#### Inter-Planetary Travel

Real-time flight between planets. Space is vast and the journey matters. The game is 2D - planets are circles on a black background, slowly orbiting the sun. The emptiness between them is an asset, not a problem. But it needs texture.

**Orbital windows:** Planets orbit at different speeds, so the distance between any two planets changes over time. The variation is subtle - it affects fuel cost mildly but never makes a trip impossible. A patient player might wait for a favorable window. An impatient one burns slightly more fuel. It's flavor, not friction.

**Planetary gravity:** Planets exert gravitational pull on the player's ship when passing nearby. Bigger planets pull harder. The player compensates with thrust or uses the pull to curve their path and save fuel. This is intuitive physics, not orbital mechanics PhD - fly near a big planet, feel a tug, compensate or ride it.

---

##### Transit Encounters

The space between planets isn't empty - it's sparsely populated with objects, signals, and atmosphere that make each journey feel different. The system that generates it is documented in `docs/ENCOUNTERS.md`; the content lives here and in `docs/IDEAS.md`.

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
- `UNKNOWN` signals (late game, with Artifact Echo scanner) are the most unreliable - they might be Titan traces, scanner ghosts, or genuinely valuable finds
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
- Near Veld: Supply manifests, trade confirmations, mundane logistics. Normal life.
- Between Veld and Crom: Factory schedules, shift rotations, worker complaints. Industrial era.
- Near Sonder: Research communications, data requests, increasingly tense academic debate.
- Near Roke: Military orders, battle coordinates, casualty reports, encrypted channels. The shutdown order, in fragments, more than once.
- Near TERRA-0: Evacuation orders. Final transmissions. Silence.

**4. Clone Predecessor Wrecks (Rare, Haunting)**

Very rarely during transit, the player encounters a wreck that matches their ship configuration exactly. Same hull shape, same bolt patterns, same modifications visible on the exterior.

- Salvageable like any small derelict (1-2 points)
- Ship's computer logs it with unusual phrasing: `WRECK ANALYSIS: CONFIGURATION MATCH 98.7%. FLAGGED.`
- The terminal data, if hackable, holds partial navigation logs showing a journey the player never made
- These should be RARE - maybe 2-3 total across a full playthrough. Each one should feel wrong.
- Finding one early is a blink-and-miss-it oddity. Finding one after learning about the clones is devastating.
- **Some have distress beacons still weakly pulsing.** These are clones that ran out of fuel and activated their beacon. The "rescue" never came. The beacon just kept transmitting into nothing until the power cells died. Finding one of these with the beacon still active is uniquely unsettling - the ship is dead, the pilot is gone, but the cry for help is still going.

**5. Titan Transit Events (Subtle, Escalating with Titan Influence)**

The Titan bleeds into transit space as it comes back up. Every tier below is gated on **Titan Influence (0-5)** - the count of Modules online - and on nothing else.

*Influence 0-1 (barely perceptible):*
- Scanner shows a momentary blip that vanishes. Was it anything?
- Ship drifts slightly sunward for a frame. Auto-corrects. Player probably doesn't notice.

*Influence 2-3 (noticeable if attentive):*
- Scanner ghosts appear briefly - a large shape at the edge of detection range that fades.
- Terminal displays a single line of text that the player didn't request, then clears itself.
- The ambient radio fragments occasionally include a transmission that doesn't sound like any human communication.

*Influence 4-5 (undeniable):*
- Ship drifts sunward more frequently. The player has to actively correct.
- Scanner occasionally shows something massive between them and the sun. It's there for seconds, then gone.
- Terminal messages from unknown sources. Fragments that feel like responses to the player's own thoughts.
- Radio echoes include a "transmission" that is just a sustained, low tone. It feels like it's listening.

> **TODO**: Bind each transit event tier to an exact Influence threshold and write its content.
> **TODO**: Design the scanner ghost visual - what does a massive blip look like on a minimal 2D radar?
> **TODO**: Write radio echo content for each region (5-10 fragments per zone transition).
> **TODO**: Place permanent orbital derelicts/satellites on specific orbital paths.

#### Gates

A **Gate** is the dormant orbital structure at a planet that powers its Module and links it to the other powered Modules. There are **six**: one at each of the five planets, and one at the Sun Station for the Core.

**How they work:**
- Gates exist at each planet, dark since the shutdown. A Gate is **Unidentified** - `???` on the minimap - until the player reaches it and an Automaton names it.
- Powering one costs **credits only**. No resource turn-in, no fetch quest, no parts list. The player flies out, reads the price, and decides. Everything the game asks of a Gate is answered by scrapping, which is the loop the player already has.
- Powering a Gate does three things, in this order: its **Module comes online** (Titan Influence +1), its **region is Charted** (see "The Chart"), and it joins the **transit network**.
- A Gate powers its Module on its own. **Transit needs a second powered Gate to travel to** - so the first Gate the player buys moves nobody anywhere, and the Chart reveal has to carry that purchase by itself.
- There is **no way to power a Module back down.** No refund, no toggle, no undo. The store sells this as a feature.
- The **Core's Gate** at the Sun Station refuses power until all five Modules are online, and says so.

**The bait:** the player is buying two things they want very much - a map that finally has something on it, and the end of the long flight home - and paying for them in credits they earned honestly. The Titan is not tricking anyone. It is selling exactly what it says it is selling, at a fair price, to someone who needs it.

**Cost shape:** steep. Veld's Gate is roughly one tier-1 upgrade. Each subsequent Gate is a significant multiple of the one before it, and TERRA-0's is the single largest purchase in the game, ahead of any artifact. The Core's Gate costs more than all five planetary Gates put together. At every step the player should have to choose between the next Gate and the next upgrade, and the Gate should be the one that is harder to justify and easier to want.

> **TODO**: Set exact Gate prices against the current store (`entities/Upgrades/items/*.tres`, presently 500-7,500 CR).
> **TODO**: Design the Gate powering sequence - what does a structure the size of a city look like when it takes power for the first time in a lifetime?
> **TODO**: Design the transit UI. Six destinations, arrow keys and ENTER, and a list that is mostly empty for most of the game.

### 4.2 Resource Collection

> **SUPERSEDED — in part.** See `docs/SWEEP.md`. This section describes the pre-Sweep design and is kept for reference only.

> The three collection methods stand. The **vacuum field** was never built and will not be: holding `action` is the **Sweep**, and harvesting is what happens when it finds something.


Three collection methods, matched to resource type. The method reflects the nature of what you're collecting.

#### Debris vs. Scrap

The world is full of floating junk. Not all of it is useful.

**Debris** is the larger, darker chunks tumbling through space - hull plates, structural beams, engine housings. Debris is a **hazard**: colliding with it damages the ship and slows you down. It's the obstacle you navigate around. Early game, debris is purely dangerous. The player learns to dodge it, weave through it, respect it.

**Scrap** is the small, collectible material floating among the debris. Visually distinct - smaller, brighter, glinting amber against the dark. Wire bundles, metal fragments, frozen fuel chunks, loose components. This is what you're here for.

**Late-game: Salvage Arms upgrade (Crom tier)** transforms debris from obstacle to resource. When equipped, colliding with debris at speed **shatters it into scrap** instead of just damaging the ship. The collision still hurts, but now scrap flies off the impact point. This reframes entire debris fields - what was once a dangerous maze becomes a resource bonanza for a player with a tough hull and salvage arms. Deliberately ramming debris becomes a viable strategy: take the hit, collect the fragments.

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

**What:** Sealed cargo containers, locked equipment panels, encrypted storage units, Titan hardware housings
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

**Current prototype (scrap nodes):** hold ACTION and a marker sweeps an `E X T R A C T` bar under the ship (1.6s; trophies 2.0s with a tighter zone). Release inside the sweet zone → normal roll; release in its centre slice → PERFECT (rolls as trophy; trophies take best of two). Release early → progress kept but decays; release late or hold to the end → OVERLOAD (Slag). Payoff scales by tier: hitstop, shake, burst, PERFECT shockwave, loot chip flying into the cargo readout. Code: `HarvestTiming`, `HarvestJuice`, `HarvestMeter`. Iterate with `tools/play.sh playtests/harvest.play`.

> **TODO**: Define container tiers and timing difficulty per zone.
> **TODO**: Replace current two-phase scanner minigame with this system.

---

#### Method 3: Hacking Terminal (Data Cores / High-Value Extraction)

**What:** Data cores, research terminals, military logs, Gate interfaces, artifact extraction
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
- Data cores extracted this way hold lore fragments, research logs, personal entries
- Gate interfaces use this method - the player types the commands that bring a Module up, and the terminal answers in the flattest possible language
- Late-game: the terminal starts responding in ways it shouldn't. Text appears that the system didn't generate. The Titan is in the network, because the network is the Titan.

**Tension source:** Discovery. The reward isn't just the resource - it's the story. Every terminal is a window into the old world. Players who engage deeply with these are rewarded with narrative.

> **TODO**: Design the core terminal hacking mechanic (start simple, one variation).
> **TODO**: Define the terminal's visual style - cursor behavior, text rendering speed, screen effects.
> **TODO**: Write terminal content for each planet tier.
> **TODO**: Design how the Titan surfaces in terminals as Influence climbs.

---

#### Method Summary by Zone

| Zone | Primary Method | Secondary | Tension Source |
|------|---------------|-----------|---------------|
| **Veld** (Outer) | Vacuum field (sparse scrap fields) | Basic containers | Navigation - learning to fly |
| **Crom** (Industrial) | Vacuum field (dense shipyards) + Salvage Arms + Containers | Terminals (manufacturing logs) | Navigation - moving hazards, debris ramming |
| **Sonder** (Research) | Terminals (research data) + Containers | Vacuum field (precision equipment) | Discovery - piecing together what happened here |
| **Roke** (Military) | All three at high intensity | Derelict salvage | All three - dense, dangerous, rewarding |
| **TERRA-0** (Homeworld) | Terminals (final truth) + Magnetic (abundant) | Containers (city ruins) | Discovery + existential weight of what you're scrapping |

### 4.3 Derelict Encounters

Derelicts are **external salvage encounters** - the player stays in their ship throughout.

**What they are:** Wrecked ships, abandoned stations, disabled satellites, war debris with intact compartments. Found drifting between planets or in orbit around them. Some are marked on the scanner, others are visual discoveries. Until the player reaches one it is just a contact - `DERELICT` on the scanner, `???` on the minimap.

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
| Veld | Cargo haulers, fuel transports | Supply manifests, trade routes, mundane life |
| Crom | Factory ships, construction vessels | Manufacturing records, production orders, worker logs |
| Sonder | Research vessels, survey ships | Scientific data, experiment logs, early Titan measurements |
| Roke | Warships, troop transports | Battle records, final transmissions, casualty reports, shutdown orders |
| TERRA-0 | Evacuation ships, civilian vessels | Personal belongings, family messages, evacuation orders |

> **TODO**: Design 2-3 derelict layouts per zone.
> **TODO**: Define salvage point placement and rewards.
> **TODO**: Write derelict-specific lore content.

### 4.4 Economy

> **SUPERSEDED — wholly.** See ADR 0007 and ADR 0005. This section describes the pre-found-object design and is kept for reference only.


**Simple sell & buy.** No price fluctuation, no trade routes, no market manipulation.

- Sell scrap and resources at stations for credits
- Buy upgrades, fuel, repairs and **Gate power-ups** with credits
- Different stations stock different upgrades appropriate to their zone
- Repair and refuel services available at functional stations
- The focus is on exploration, not economics - credits are a means to upgrades and Gates, not an end

**Station inventories by planet:**
| Station | Sells | Buys |
|---------|-------|------|
| Veld / Rook (Home) | Basic upgrades (hull, fuel, cargo tier 1-2), Planetary Scanner, repairs, fuel | All common resources |
| Crom (Industrial) | Engine upgrades, advanced hull/cargo, some artifacts | All resources, premium price for industrial components |
| Sonder (Research) | Scanner upgrades, radiation shielding, data analysis tools | Data cores, research materials |
| Roke (Military) | Heat shields, military-grade hull, combat artifacts | Military salvage, recovered Titan hardware |
| TERRA-0 (Homeworld) | Final-tier artifacts only | Anything (but who's buying at the end of the world?) |
| Sun Station | Nothing. There is no store here. | Nothing. |

Gates are not sold at stations - each is paid for at the Gate itself, in credits, on the spot.

> **TODO**: Balance resource values and upgrade costs across all tiers.
> **TODO**: Define repair/refuel pricing.

### 4.5 Upgrades

> **SUPERSEDED — in part.** See ADR 0007. This section describes the pre-found-object design and is kept for reference only.

> The upgrade *list* and the feel goals stand. Nothing is bought: every upgrade is a physical object recovered from the world and fitted at a station.


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
| **Scanner: ARTIFACT ECHO** (Titan tech) | Detects signals that shouldn't exist - Titan traces, anomalous transmissions, things behind solid objects. Sometimes shows things that aren't there. Or are they? | The scanner becomes unreliable and powerful simultaneously. The player sees more but trusts less. |
| **Hacking Suite** | Unlocks terminal interaction for data cores and high-value extraction. Before this, terminals are inaccessible ("INCOMPATIBLE INTERFACE" message). | Opens the entire lore/narrative collection system. The game's story literally unlocks. |
| **Salvage Arms** | Unlocks the timing minigame for sealed containers AND shatters debris into scrap on collision. Before this, sealed containers show "NO EXTRACTION TOOLS" and debris is pure hazard. After: containers are crackable and debris fields become resources. | Mid-tier resources become accessible. A new collection method enters the rotation. Debris fields are reframed from obstacle to opportunity. |

#### Mysterious Artifacts (The Titan's Tech)

Artifacts are Titan hardware - recovered at Module sites and around the Gates, where the machine's own components sit in reach of anyone with salvage arms and no sense. They are **always mechanically superior** to their practical equivalents. This is the pull.

| Artifact | Replaces | Advantage | Unsettling Detail |
|----------|----------|-----------|-------------------|
| Resonance Core | Engine tier 3 | 2x thrust of best practical engine | Hums at a frequency you feel in your teeth |
| Phase Plating | Hull tier 3 | Absorbs damage instead of resisting it | The hull *heals* when damaged. Slowly. |
| Void Capacitor | Fuel tier 3 | Fuel consumption drops to near-zero | Fuel gauge occasionally reads negative values |
| Echo Array | Scanner tier 3 | Detects everything, even things behind objects | Sometimes shows things that aren't there. Or are they? |
| Thermal Lattice | Thermal tier 3 | Near-immunity to heat/radiation | Required for TERRA-0 and the Sun Station. The final gear check. The final compromise. |

**The design intent:** The player MUST install artifacts to reach the endgame. Practical upgrades alone cannot get you to TERRA-0, let alone the Sun Station. The only path inward runs on the Titan's own technology - pieces of its body, bolted to the ship that is going to switch the rest of it on.

**A quieter detail:** artifacts recovered at a Module site get *better* after that Module comes online. Nothing announces it. The numbers on the stat screen were always going to go up.

> **TODO**: Full upgrade tree with specific stat values and costs.
> **TODO**: Define which Module sites yield which artifacts.
> **TODO**: Design the artifact installation moment - should it feel different from normal upgrades? A special animation? A sound?

### 4.6 Threats & Hazards

**No combat.** Danger is environmental and automated. The universe is indifferent, not hostile.

#### Environmental Hazards

| Hazard | Where | Effect |
|--------|-------|--------|
| **Debris collision** | Everywhere | Hull damage based on relative velocity. Dense fields are dangerous at speed. |
| **Radiation pockets** | Sonder+, near old research rigs | Gradual hull damage without shielding. Scanner can detect and highlight them. |
| **Heat zones** | Roke+, near sun | Constant hull drain without thermal upgrades. Intensity increases closer to sun. |
| **Gravitational anomalies** | TERRA-0, near Module hardware | Pull ship off course. Worse near the fused structure the planet is held in. |
| **Electromagnetic interference** | Near Gates and Module sites | Scanner and navigation disruption. UI glitches. (Or is that the Titan?) |

#### Automated Systems (Inner Tiers Only)

War-era automated defenses that don't know the war is over:

| System | Where | Behavior |
|--------|-------|----------|
| **Defense turrets** | Roke stations, warship wrecks | Track and fire at unidentified ships. Slow tracking, predictable patterns. Avoidable, not fightable. |
| **Patrol drones** | Crom shipyards, Roke perimeter | Follow set paths. Alert turrets if they spot you. Stealth/timing to avoid. |
| **Gate wardens** | At every Gate from Sonder inward | Posted by the shutdown crews to keep that Gate dark, and never stood down. The most dangerous automated threat in the game, and the only thing in the system actively trying to stop the player. Must be disabled through a terminal before the Gate will take power. |
| **Moving machinery** | Crom factories | Robotic arms, conveyors, welding lasers. Not hostile - just operating on schedule. Hazardous to fly through. |

**Design philosophy:** These aren't enemies to fight. They're obstacles to navigate around, sneak past, or disable through terminals. The player's tools are patience, timing, and hacking - not weapons.

**The wardens are the argument.** Everything else in the game encourages the player inward. The wardens are the last standing order of a dead civilization, still guarding a decision it nearly tore itself apart making, and the player switches them off one at a time to get at a better fuel economy. Nobody ever explains them. The player works out what they were for on their own, or doesn't.

> **TODO**: Define turret behavior - tracking speed, projectile speed, damage values.
> **TODO**: Design patrol drone patterns.
> **TODO**: Design the Gate warden disable sequence (terminal hacking). It should read as an override, not a hack - the player has the authority, inherited.

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

Powered Gates are never lost. Whatever else a death costs, Titan Influence only goes up.

> **TODO**: Implement the subtle post-death changes (see Clone System section 3.2).

#### Fuel Depletion

> **SUPERSEDED — wholly.** See ADR 0010 and ADR 0011. The ship cannot run dry: the Aux drive has no fuel. The distress-beacon beat survives, promoted — abandoning is now a deliberate choice available anywhere, at any time, and the player will take it casually to save a dull trip home.


**Running out of fuel is a death. The player just doesn't know it yet.**

When fuel hits zero, the ship goes completely dead. No thrust, no systems, no drift. The ship is a floating brick in the void. After a beat of silence:

1. **DISTRESS BEACON prompt appears** - The player must manually activate it. This moment of agency matters - they're choosing to call for help, sitting in a dead ship in empty space.
2. **"DISTRESS BEACON ACTIVE... AWAITING RESPONSE..."** - Text appears on screen. A slow fade to black begins.
3. **Wake up at the last station docked at.** The automaton greets you. Everything is normal.

**The rescue never happens.** The clone died alone in the dark, beacon pulsing into nothing. A new clone was activated at the station with the inherited mission state. The transition is designed to feel like a rescue early in the game - the player assumes they were towed back. But it's identical to death because it *is* death.

**The penalty:** All current unsold cargo is lost (same as hull-death), plus a small rescue/tow fee is deducted from credits. This makes fuel depletion slightly more punishing than collision death - you lose cargo AND pay for the "rescue" that never came.

**Late-game realization:** As the player learns about the clone system, the fuel death recontextualizes. The beacon was never answered. The "tow fee" is just the cost of activating a new clone. Every time they ran out of fuel, they died waiting in silence.

**Stranded clone ships:** Occasionally while exploring, the player will find ships matching their own drifting dead in space, distress beacons still weakly pulsing. These are procedurally placed (not tied to actual death locations) and serve as atmospheric reminders. Early on they're curiosities - "huh, someone else had the same ship." Late-game, after learning about clones, they're haunting. Each one is a *you* that ran out of fuel and never got rescued.

> **TODO**: Define the tow/rescue fee amount. Should scale with progression? Flat fee?
> **TODO**: Define how long the player sits in the dead ship before the beacon prompt appears. Long enough to feel the dread.

### 4.8 Pacing & Progression Timeline

#### Design Philosophy

**No time pressure. No hard gates. No locked doors.**

The solar system is fully open from the first moment. The player can point their ship at TERRA-0 and thrust. They will die - not because a wall stopped them, but because their ship melted, ran out of fuel, or was shredded by debris. The "gates" are the player's own ship capabilities. Upgrading isn't about unlocking access - it's about surviving further.

The one thing that *is* gated is the Core, and it is gated honestly: fly to the Sun Station in the first hour, read the refusal, fly home.

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
VOID ←── Veld ──── Crom ──── Sonder ──── Roke ──── TERRA-0 ──→ SUN STATION
cold     cold      mild      warm        hot        extreme       lethal
safe     safe      moderate  dangerous   hostile    lethal        last door
sparse   sparse    dense     dense       very dense overwhelming   empty
```

**Partial access is expected and encouraged.** A player at Veld with a couple of upgrades can dip into the edges of Crom space. They won't survive long, but they might grab a few high-value industrial components before retreating. This risk/reward dynamic is the economic engine:

- Safe zone resources: low value, low risk
- Next zone's edge: moderate value, moderate risk
- Deep in an unprepared zone: high value, high risk (death = lost cargo)

The bold player who pushes further earns more per trip but risks losing everything in their hold. The cautious player grinds safely but progresses slower. Both are valid.

#### Pacing Curve: Slow Start, Wide Middle, Fast End

```
Playtime distribution (approximate):

Veld    ████████████████████████░░░░░░░░░░░░░░░░░░░░  ~30%  (slow, deliberate)
Crom    ░░░░░░░░░░░░░░░░░░░░░░████████████████░░░░░░  ~25%  (expanding)
Sonder  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████  ~20%  (story-rich)
Roke    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████  ~15%  (intense)
TERRA-0 + Sun Station ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░██  ~10%  (endgame)
```

The game accelerates as it progresses. Veld is slow and deliberate - the player is learning, their ship is sluggish, trips are short. By Roke, the player has a transit network, a responsive ship, good tools, and confidence. The last stretch is short and intense - by then, the story is doing the work, not the gameplay loop.

This mirrors the Titan's pull. Early game: the player barely moves. Late game: they're hurtling inward, on a network they paid to build, unable (and unwilling) to stop.

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

The cockpit fades in. The player is docked at the station in orbit around Rook. The HUD is minimal - fuel bar, hull bar, tiny cargo readout. All full, all fine. Through the viewport: stars, the grey curve of Rook below, Veld's frozen bulk beyond it, the distant pinprick of the sun.

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

Heading 140. The player points that direction and thrusts. Black. Stars. The ice giant beyond the moon. Nothing else.

Then - glinting. A cluster of debris, visible against the starfield. Tumbling hull fragments, loose wiring, frozen metal chunks. Close enough to reach on the first tank. The player's first "there's something over there" moment.

---

**Minute 4-7: First Collection**

The player flies into the debris cloud. Larger dark chunks tumble slowly - debris, dangerous to hit. Among them, smaller bright fragments glint amber against the black. Scrap.

The player holds the action button. A faint field flickers around the ship - barely visible, tiny range. Nearby scrap begins drifting toward the hull. Slowly. A metallic clink as the first piece connects. The cargo readout pulses: 1. Another clink. 2. The pull is lazy - you have to park yourself near each cluster and wait. It works, but it's clear this ship was not built for efficiency.

The small cargo bay fills fast. Maybe 8-10 units of common scrap. The player is already making decisions: keep grabbing or head back? The fuel gauge is a consideration but not a crisis.

Sealed containers are visible floating among the debris. The player tries to vacuum one. Nothing. No prompt. No explanation. The container just... exists, tantalizingly opaque. (Later: "NO EXTRACTION TOOLS" message when interacted with.)

The world is quiet. The ambient sound is almost nothing - the hum of the ship, the faint clank of debris bouncing off the hull. The sun is a dot. Rook is a frozen rock. The station is a smudge of amber light in the distance.

This is the tone. Not hostile. Not welcoming. Just... empty. The player is alone in the most fundamental way, and the only voice they've heard belongs to a machine that knows them a little too well.

---

**Minute 7-10: First Sale & The Loop Begins**

The player flies back to the station. Docking is simple. The store interface opens - terminal-style amber text on black.

Scrap sells for a few credits each. The total is modest. The store shows upgrades: Hull I, Fuel Tank I, Engine I, Cargo Bay I, Thrusters I. All affordable in 2-3 trips. The Scanner PULSE and Tractor Beam are listed too, but more expensive - aspirational purchases the player can see but can't reach yet.

If the player opens the Chart at any point in these ten minutes, they find Rook, the station, and the void. Nothing else. Not Veld, which fills half the viewport. The Chart is not broken; it simply doesn't know anything yet, and nothing in the UI apologises for that.

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
- The dead transit gate they'll be told about in an hour is a power switch on a mind the size of a solar system
- The scrap they're collecting is the remains of a war fought to decide whether that switch should ever be thrown again
- The Chart is blank because the only thing that has a map of this system is the thing they are about to switch on
- The boot sequence told them everything on line 5

#### Full Progression Timeline

---

**PHASE 1: THE SCAVENGER (Veld - ~30% of playtime)**

*The player learns the loop. Trips are short. The world is quiet. Titan Influence: 0.*

The player wakes up docked at the station over Rook. The Cheerful Guide greets them, explains the basics. The immediate area has sparse scrap fields - visible debris that the player can physically fly into to collect.

**Available at start:**
- Home store: Hull I, Fuel Tank I, Engine I, Cargo Bay I, Thrusters I (stat upgrades, affordable in 2-3 trips each)
- Vacuum field scrap collection (hold action, slow trickle, tiny range - functional but tedious)

**Early loop (trips 1-5):**
1. Fly out, hold action to vacuum scrap in (slow, short range), fill small cargo hold
2. Return, sell, buy Hull I or Fuel Tank I
3. Repeat with slightly longer range
4. Start noticing sealed containers floating in debris fields (can't open yet: "NO EXTRACTION TOOLS")
5. Start noticing faint unreadable blips at the edge of vision (no scanner yet)

**First major purchase: Scanner PULSE**
- Transforms navigation. The minimap lights up with resource pings the player never knew were there.
- Debris fields that seemed sparse now show clusters of high-density nodes.
- Sealed containers and data terminals appear on the scanner as distinct icons.
- The player realizes they've been flying past resources constantly.

**Second major purchase: Tractor Beam**
- **THE game-changing moment.** Collection transforms from tedious bump-and-grab to satisfying magnetic sweep.
- Scrap per trip roughly doubles because collection is so much more efficient.
- The player starts taking longer trips, pushing further from the station.
- The economy opens up - credits flow faster, the next upgrades come quicker.

**Exploration deepens:**
- With PULSE, the player discovers scrap fields further from the station
- Debris density increases at the outer edges of Veld's orbital zone
- The player notices the void in the distance - scanner goes dead near it, ship systems flicker
- Derelicts start appearing on scanner - cargo haulers and fuel transports. External salvage for extra resources.
- The player flies past something enormous and dark in Veld's equatorial orbit. It reads `???`. Nobody has said anything about it.

**Finding the first Gate (the pivot of Phase 1):**
- The player reaches the `???` on their own. The Guide names it the moment they're in range: *"Oh - that's a transit gate. Veld's. Been dark since before my time."* No waypoint preceded this. No quest opened.
- The Gate quotes a price in credits. Nothing else - no parts list, no fetch, no favour owed.
- The Guide is helpful about what it does and vague about what it's attached to, because vague is all they have: *"Powers up the local systems and links to the others, when there are others. Mostly it means you stop flying everywhere."*
- **There is nothing to travel to yet.** The player is being asked to spend several trips' income on a road with one end. The Chart reveal has to close this sale by itself, and does: Veld's region draws itself in - the planet, its orbit, Rook, the station, the Gate - onto a page that has held three objects since the game started.
- **Titan Influence: 1.** Nothing announces this. Something in the ship's ambient hum changes pitch, once, and settles.

**Late Phase 1 (preparing to push out):**
- Player has Hull I-II, Fuel Tank I-II, Engine I, Tractor Beam, Scanner PULSE, Planetary Scanner
- Ship feels noticeably better than at start - more responsive, tougher, more range
- The player can see Crom in the distance. Scanner shows faint readings from that direction.
- Bold players have already dipped into Crom's edge and grabbed some industrial components worth 2x normal scrap.
- The Cheerful Guide hints: "I've heard the stations in the inner system stock tools we don't have out here. Salvage arms, terminal interfaces... real professional gear."

---

**PHASE 2: THE EXPLORER (Crom - ~25% of playtime)**

*The game opens up. New tools. New resource types. The network becomes real. Titan Influence: 1 → 2.*

**The journey to Crom:**
- First trip is a real expedition. Fuel gauge drops noticeably. Minor heat warnings start appearing (cosmetic at this tier, not damaging yet).
- Space between planets is emptier but not void - scattered debris, the occasional derelict.
- Arriving at Crom is Beat 1: survival. The player made it.

**Crom Station (Beat 2: first dock):**
- Meet The Trader. Fast-beeping, enthusiastic, immediately calls you "partner."
- New upgrades unlock system-wide (available at the home store too now):
  - **Salvage Arms**. Unlocks sealed container timing minigame.
  - **Hacking Suite**. Unlocks terminal interaction for data cores.
  - Hull III, Fuel Tank III, Engine II, Thrusters II, Cargo Bay II
  - **Thermal Systems I** (first thermal upgrade - needed for Sonder)
  - Scanner DEEP SCAN (next scanner tier)

**Crom environment:**
- Dramatically different from Veld. Massive derelict shipyards. Moving machinery hazards.
- Dense debris fields with higher-value industrial components (~50-100% more valuable than Veld scrap)
- Sealed containers are abundant here (once Salvage Arms are purchased)
- Factories still running on loop - conveyor belts, robotic arms, welding lasers. Navigation hazards that reward careful flying.

**Crom progression:**
- Salvage Arms purchased → sealed containers unlock → new resource types (electronics, mechanical components)
- Hacking Suite purchased → terminals unlock → first data fragments readable → STORY OPENS UP
  - Manufacturing logs reveal the scale of wartime production
  - The player reads about "Project Leviathan" or whatever codename the Titan was built under
  - First hints that the structures out here were made to be parts of one thing
- Scanner DEEP SCAN → hidden caches revealed at Crom AND back at Veld
  - NPC hint: "Your new scanner might pick up things you missed around Veld"
  - Player returns to Veld and finds concealed resource nodes they flew past dozens of times
- Ship now visually has bolted-on plates, larger thrusters, visible tractor array, salvage arm mechanisms

**The second Gate (Beat 3):**
- The Trader does not give the player a quest. They give them a business case: *"Gate's right there over the yards. Power it and you're at my counter in under a minute, every trip, forever. Think about what that does to your margins, partner."*
- It is the best financial advice anyone gives the player in the whole game, and it is entirely correct.
- Price is a significant multiple of Veld's. The player will choose between this and two tiers of upgrades.
- On power-up: **Crom's region charts**, and for the first time **transit works** - two powered Gates, one route. The game's geography compresses in a single evening of play. The player can now farm both zones efficiently.
- **Titan Influence: 2.** The scanner picks up a blip that isn't there, once, and the player blames the new hardware.

---

**PHASE 3: THE INVESTIGATOR (Sonder - ~20% of playtime)**

*The story takes over. Terminal-heavy. The player starts asking questions. Titan Influence: 2 → 3.*

**The journey to Sonder:**
- Requires Thermal Systems I at minimum. Without it, hull drain from radiation begins partway through the journey.
- The sun is visibly larger. Heat warnings are no longer cosmetic - they're functional.
- A player without thermal protection can push into Sonder's edges but will take damage. Bold players can grab a few things and flee.

**Sonder Station (first dock):**
- Research station, eerily quiet. Automated systems maintain it perfectly. No permanent named NPC.
- New upgrades unlock system-wide:
  - **Scanner RESONANCE** (the big one - hidden locations, cloaked derelicts)
  - Thermal Systems II, Hull upgrades, Engine III
  - Upgraded Hacking Suite variants (faster terminal interaction, more capable decryption)
- The station terminals are dense with research data. The hacking suite works overtime here.

**Sonder environment:**
- Orbital arrays of sensors and telescopes, all still pointed at the sun
- Cleaner, more intentional infrastructure than Crom's industrial chaos
- Radiation pockets require scanner detection and avoidance
- Electromagnetic interference near research equipment disrupts navigation
- **First Gate wardens.** Sonder's Gate is guarded. Old, slow, still shooting. The player disables them through a terminal and thinks nothing of it beyond the inconvenience.

**Sonder is where the story accelerates:**
- Research logs describe measuring "the system" - clinical, detached language
- The argument, in full: is it sentient? Can it be talked to? Is cutting the power to a mind maintenance, or is it killing?
- The shutdown procedure was drafted here. The player can read its revisions. Somebody kept arguing in the margins and kept losing.
- Military pressure: "The shutdown proceeds regardless of research findings"
- The player finds references to "personnel redundancy protocols" (cloning)
- First Titan presence on terminals: a line of text that doesn't match the log entry. A response to something nobody asked.
- Scanner RESONANCE reveals hidden locations at ALL previous zones:
  - Veld: A cloaked research probe (data about the Titan's early measurements)
  - Crom: A concealed testing bay (prototype Module components - artifact-tier)
  - Sonder: Buried laboratory (deep research on the Titan's nature)

**The third Gate:**
- No automaton sells this one. The player finds it, reads the price, and buys it because they have been buying them.
- On power-up, **Sonder's region charts** - and the Chart is now half a solar system, all of it a gift.
- **Titan Influence: 3.** This is where the wrongness stops being deniable: sunward drift the player has to correct, a terminal answering a question nobody typed. A careful player starts connecting the escalation to the Gates. Nothing in the UI helps them do it.

---

**PHASE 4: THE INSTRUMENT (Roke - ~15% of playtime)**

*Intense, fast, dangerous. The truth is becoming unavoidable. Titan Influence: 3 → 4.*

**The journey to Roke:**
- Requires Thermal Systems II minimum. Heat is constant. Hull drain is real without protection.
- The sun dominates a quarter of the sky. Conduit runs the size of mountain ranges are visible reaching inward, all of them cold, and three of them are not cold any more.
- Warship wreckage appears en route. The scale of the war becomes physical.

**Roke Station (first dock):**
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

**THE MODULE STATUS BOARD:**
- On the wall of the command station, still live after all this time: five indicators in a row, labelled with the five planets.
- Three of them are lit.
- Nothing draws the player's attention to it. It is set dressing in a room full of set dressing. It has been on this wall since the player's first visit and it had *one* light then.
- The Broken One stands where they can see it and cannot stop looking at it.
- The board is how the game finally says out loud what the player has been doing, and it says it in five lamps and no words.

**Roke environment:**
- Warship graveyards. Massive military vessels in decaying orbits.
- Automated defense turrets that track and fire. Avoidance-based, not combat.
- Patrol drones following old routes. Timing-based navigation through their patrol patterns.
- Gate wardens in numbers here - this is where the shutdown was run from, and its last orders are thickest on the ground.
- Cairn, the memorial moon. Thousands of names carved in rock. No resources. No gameplay. Just names.

**The pacing accelerates here.** The player has a transit network, a fast ship, good tools. They move through Roke more quickly than previous zones - not because there's less content, but because they're more capable. The gameplay loop is tight and efficient. The story is doing the heavy lifting.

**Artifact acquisition:**
- Artifacts are recovered at Module sites AND bought at Roke's station
- They're expensive but dramatically superior to practical upgrades
- Installing each artifact visibly changes the ship - glowing, geometric, alien components
- The game increasingly relies on artifacts for progression. Practical upgrades plateau.
- **TERRA-0 requires artifact-tier thermal protection (Thermal Lattice).** There is no practical equivalent. The player MUST use the Titan's own tech to get any further in.

**The truth becomes hard to ignore:**
- Military logs describe the shutdown in detail: the order, the objections, the crews who walked it inward and didn't come back
- The Broken One's awareness peaks here - they try to warn the player during moments of lucidity
- The ship's computer surfaces messages from unknown sources
- Scanner ARTIFACT ECHO reveals anomalous signals everywhere - and the density of them tracks Titan Influence exactly, which a player who is paying attention can work out for themselves

**The fourth Gate:**
- The Broken One hands over the coordinates because they cannot not hand them over, and then says nothing at all for the rest of the conversation.
- On power-up, **Roke's region charts**. **Titan Influence: 4.**
- The next time the player docks, the fourth lamp is lit, and the Broken One has positioned themselves with their back to the board.

---

**PHASE 5: THE WAKE (TERRA-0 and the Sun Station - ~10% of playtime)**

*The end. Short, intense, atmospheric. The gameplay loop gives way to revelation. Titan Influence: 4 → 5, then the Core.*

**The journey to TERRA-0:**
- Requires Thermal Lattice (artifact). Without it, the heat is instantly lethal.
- The sun is everything. It fills the sky. It IS the sky.
- Four of the great conduit runs are live now, and they are the brightest things in the system that are not the sun.

**TERRA-0:**
- No traditional gameplay loop here. Resources are absurdly abundant but the player is past caring about credits.
- The spent homeworld. Flying between continental fragments.
- City ruins in cross-section. Homes, schools, lives cut in half.
- The fifth and largest Module is here, fused into the planet's bones - the reason the planet was opened in the first place.
- The cloning bay is here. The player's origin. Rows of pods. A counter ticking down.
- The original engineer's personal quarters. Their logs. Their voice - the player's voice - describing the day they cut power to a Gate and flew away from it.

**The fifth Gate.**
By TERRA-0, the evidence is overwhelming. The player knows - or strongly suspects - exactly what a Gate is for. The fifth is bought with full awareness. There is no trick, no reveal, no twist. It is a price in credits and a button, the same as the other four.

They pay it because there is nothing else to do with a solar system, a ship built out of Titan hardware, and four fifths of a map.

- **Titan Influence: 5.** The Chart is complete for the first time in a lifetime.
- Somewhere out at Roke a fifth lamp comes on in an empty room.

**The Sun Station:**
- The hardest flight in the game and the only one with nothing at the end of it. No store, no scrap worth stopping for, no automaton. A hardened platform, a Gate, and a terminal.
- The Core's Gate has been refusing power all game. Any player who flew out here early has read the refusal. It does not refuse any more.
- The price is larger than every Gate before it combined. A player who has been flying inward this long can pay it.
- **The player knows. They do it anyway.**

---

#### THE WAKE SEQUENCE

**The Trigger:**
The player pays the Core's Gate. The terminal acknowledges in the same flat voice it has used all game. Power moves inward along five conduit runs at once, from five planets, into the sun.

**Beat 1: Silence (0-10 seconds)**
- All audio cuts. Instantly. Engine hum, scanner pings, ambient drone - everything.
- Dead silence for an uncomfortable duration. Long enough that the player wonders if the game crashed.
- Nothing happens. Nothing at all.

**Beat 2: The System Comes Up (10-45 seconds)**
- The sun does not explode and does not go out. It *changes* - the light the player has been flying under for thirty hours shifts to a colour that is not in the game's palette and has never been in it.
- The ambient light on every surface changes with it. The world the player knows is being lit by something else now.
- The player still has partial ship control - they can fly, but there's a growing sense that it doesn't matter where they go, because everywhere they could go is part of the same body.
- A shape begins resolving outward from the centre - not a circle, a *shape*. Something that doesn't conform to any geometry the game has used before. It moves across the 2D plane like something impossibly large turning over.
- The CRT aesthetic starts breaking. Scan lines tear. The amber palette shifts, inverts, flickers. The UI - which has been the player's constant companion for the entire game - becomes unrecognizable.
- The game's visual rules, maintained rigidly for the entire experience, are violated. This is the Titan's "voice" - the screen itself.

**Beat 3: The Messages (45-90 seconds)**
- As the light changes, three transmissions arrive. One from each automaton. Final messages:

  **The Cheerful Guide:**
  Their screen flickers on one last time. A message the player has to read against a colour that hurts:
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

- After the last message, silence again. The player's instruments are failing one by one.

**Beat 4: Systems Handover (90-180 seconds)**
- The player's ship systems go out in sequence - and every one of them is a piece of the system that is now being run by something else:
  1. Scanner goes dark (minimap disappears)
  2. Ship's computer terminal stops responding
  3. HUD elements fade - cargo, then fuel, then hull readouts
  4. The Chart, if the player opens it, is complete and then is not theirs
  5. Thrust weakens - the ship responds sluggishly, then barely, then not at all
- The player drifts. They can do nothing but watch the last of their instruments go.
- The shape has enveloped everything. Occasionally something - a line, a curve, a suggestion of impossible scale - is visible for a frame before vanishing.
- The player's ship is the last point of light. Then it isn't.

**Beat 5: The Boot Sequence (After blackout)**
- Black screen. Long pause.
- Then, familiar: the CRT flicker of the game's boot/loading sequence begins.
- It is the sequence from minute zero, and it is not the player's ship booting:

  ```
  Initializing navigation systems.....................[OK]
  Loading stellar database...........................[OK]
  Calibrating sensors................................[OK]
  Establishing communication arrays..................[OK]
  Verifying module status.............................[5/5]
  Core.............................................[ONLINE]
  Synchronizing clone manifest.......................[ 1 ]
  Searching for operator...............................[FOUND]
  ```

- The last two lines are the whole ending. The manifest is down to one. The operator was found.
- The progress bar fills. The percentages climb. Something enormous is starting up.
- It cuts mid-boot. We never see what loads.
- Hard cut to black. No credits text. No "THE END." No music.
- The game returns to the title screen after a long pause. The title screen is subtly different - the starfield is darker, and the amber text is not quite amber.

> **TODO**: Write the exact boot sequence messages for the ending (the draft above is close).
> **TODO**: Design the shape - what geometry represents something beyond comprehension in 2D?
> **TODO**: Pick the out-of-palette colour for the woken sun. It must be a hue `Colors.gd` does not define, and it must appear exactly once in the game.
> **TODO**: Define the exact timing of each beat (playtesting will determine what feels right).
> **TODO**: Design the altered title screen - what's different?
> **TODO**: Determine if the save file is affected. Can the player reload? Is the game "over" permanently? Or does it reset?

---

#### Economy & Upgrade Cost Summary

> **Stale numbers.** The credit values in this section predate the current store, where tier-1 upgrades cost 500-750 CR and the Planetary Scanner costs 5,000 (`entities/Upgrades/items/*.tres`). The *ratios* below are the design intent; the absolute figures need a balance pass against the shipping prices.

**Resource values by zone:**
| Zone | Common Scrap Value | Sealed Container Value | Data Core Value |
|------|-------------------|----------------------|-----------------|
| Veld | 5 CR | 15-25 CR | 30-50 CR |
| Crom | 8 CR | 25-40 CR | 50-80 CR |
| Sonder | 12 CR | 40-60 CR | 80-120 CR |
| Roke | 18 CR | 60-100 CR | 120-200 CR |
| TERRA-0 | 25 CR | 100+ CR | 200+ CR |

**Upgrade cost tiers (approximate):**
| Upgrade Type | Cost Range | Trips to Afford (at current zone) |
|-------------|-----------|----------------------------------|
| Stat Tier I (Hull I, Fuel I, etc.) | 15-30 CR | 2-3 trips |
| Stat Tier II | 50-80 CR | 3-4 trips |
| Stat Tier III | 120-200 CR | 4-6 trips |
| Scanner PULSE | 40 CR | 5-6 trips (Veld scrap) |
| Tractor Beam | 60 CR | 6-8 trips (Veld scrap) |
| Salvage Arms | 100 CR | 8-10 trips (Crom scrap) |
| Hacking Suite | 100 CR | 8-10 trips (Crom scrap) |
| Scanner DEEP SCAN | 150 CR | 6-8 trips (Crom scrap) |
| Scanner RESONANCE | 250 CR | 6-8 trips (Sonder scrap) |
| Scanner ARTIFACT ECHO | 400 CR | 5-7 trips (Roke scrap) |
| Artifact upgrades | 300-600 CR | 4-8 trips (Roke scrap) |

**Gate costs (credits only - no resource turn-in at any Gate):**
| Gate | Relative Cost | Trips to Afford | What It Buys |
|------|--------------|-----------------|--------------|
| Veld | ~1 stat tier-I upgrade | 3-4 trips | Charts Veld. No transit yet - there is nowhere to go. |
| Crom | ~3x Veld's | 6-8 trips | Charts Crom. **First working route.** |
| Sonder | ~3x Crom's | 8-10 trips | Charts Sonder. Three-stop network. |
| Roke | ~3x Sonder's | 8-12 trips | Charts Roke. |
| TERRA-0 | The largest single purchase in the game, ahead of any artifact | 12+ trips | Charts TERRA-0. Influence 5/5. Unlocks the Core's Gate. |
| **Core** (Sun Station) | More than all five combined | The last grind in the game | The ending. |

**Key tension:** at every step, the Gate should cost about what the player's next two wanted upgrades cost together. The Gate should always be the harder purchase to justify and the easier one to want.

**Store stocking rule:** New upgrades become available at ALL stations once the player first docks at the station that originally stocks them. First visit to Crom unlocks Salvage Arms and Hacking Suite at the home store too.

**Key economic principle:** The player should always have 2-3 things they're saving toward simultaneously. There should never be a moment where there's nothing to buy and nowhere to go.

> **TODO**: Playtest and balance all values against the shipping store prices.
> **TODO**: Define exact resource spawn rates per zone.
> **TODO**: Price the six Gates concretely. The first must be reachable inside Phase 1; the last must hurt.

### 4.9 Progression System

> **SUPERSEDED — in part.** See ADR 0005, ADR 0007 and `docs/SWEEP.md`. This section describes the pre-Sweep design and is kept for reference only.

> The acquisition ladder, Gate prices and the three-beat tier transition are superseded — Gates cost literacy, not credits, and pacing is by `min_radius` rather than price. **Ship Visual Transformation is now literally true**: every bolted-on part is a specific object from a specific place.


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
- A Chart holding one moon, one station and the void

The early game is intentionally limited. The player is a scavenger with a wrench and a dream. Each upgrade peels back a layer of the game they didn't know was there.

**Upgrade acquisition order (approximate - player has some freedom):**

```
Early Veld:
  Hull I ──────────── Survive more bumps
  Fuel Tank I ──────── Range to reach further debris fields
  Engine I ─────────── Ship starts to feel less like a brick
  Scanner: PULSE ───── "Oh, THAT'S where the resources are"
  Tractor Beam ─────── *** GAME-CHANGING MOMENT ***
                        Scrap collection transforms entirely
  Veld Gate ────────── *** THE CHART STOPS BEING BLANK ***

Mid Veld → Crom transition:
  Cargo Bay I ─────── More scrap per trip
  Salvage Arms ─────── Sealed containers are now accessible (timing minigame unlocks)
  Hull II ─────────── Survive the industrial shipyards
  Fuel Tank II ────── Range to reach Crom
  Crom Gate ────────── *** TRANSIT WORKS. The system gets smaller. ***

Crom → Sonder transition:
  Scanner: DEEP SCAN ── Hidden caches revealed. Old zones have new secrets.
  Hacking Suite ──────── Terminals unlock. The STORY opens up.
  Engine II ──────────── Ship feels genuinely responsive now
  Thermal I ──────────── Can survive mild radiation (Sonder access)
  Sonder Gate ────────── Influence 3. The wrongness stops being deniable.

Sonder → Roke transition:
  Scanner: RESONANCE ── Hidden locations revealed. Cloaked derelicts appear.
  Thermal II ─────────── Heat resistance for inner system
  Hull III ───────────── Military-grade durability
  Roke Gate ──────────── Influence 4. Four lamps on a wall at Roke.

Roke → TERRA-0 → Sun Station:
  Thermal III ────────── Still not enough for TERRA-0
  *** ARTIFACT THRESHOLD ***
  Artifact upgrades ──── Required to survive solar proximity
  Scanner: ARTIFACT ECHO ── See things that shouldn't be there
  Thermal Lattice (artifact) ── The final gear check. The final compromise.
  TERRA-0 Gate ───────── Influence 5/5. The Chart is whole.
  Core Gate ──────────── The ending.
```

#### Revisiting Old Zones

**Resources:** Common scrap respawns over time (debris keeps drifting in from elsewhere in the system). Sealed containers and data cores are one-time finds. This means old zones are never "empty" for basic grinding, but the interesting discoveries don't reset. Deep space is the exception - stripped stretches of the void stay stripped (see `docs/ENCOUNTERS.md` §3.6).

**Scanner-gated content:** Each scanner tier reveals new things in ALL zones, not just the current one. This is the primary reason to revisit:

| Scanner Tier | What It Reveals in Old Zones |
|-------------|------------------------------|
| **PULSE** | Basic resource nodes. (Player had nothing before this.) |
| **DEEP SCAN** | Hidden caches concealed in asteroid interiors, behind debris, inside derelict hulls. Resources the player flew right past dozens of times. |
| **RESONANCE** | Entire hidden locations - a cloaked research probe at Veld, a concealed testing bay at Crom, a buried lab at Sonder. These are substantial discoveries with unique lore. |
| **ARTIFACT ECHO** | Anomalous signals. Traces of the Titan. Things that may or may not be real, and more of them every time a Module comes up. The most unsettling discoveries in the game. |

**NPC and environmental hints (organic, never checklist-based):**
- After getting DEEP SCAN, an automaton might casually say: "Your new scanner array is impressive. I wonder what you'd find if you swept the old fields around Veld again."
- The ship's computer logs anomalies: "DEEP SCAN calibration complete. Anomalous readings detected in previously surveyed sectors."
- A derelict's data log mentions "the concealed cache at [coordinates in an earlier zone]"
- None of these are quest markers. No indicators on the map. No completion percentages. Just diegetic hints that reward attentive players.

**NPC favors (organic side content):**
- Automatons occasionally mention things they want: "I've been trying to find a specific data core from one of the old research probes. If you ever come across one..."
- These aren't tracked quests with UI indicators. The player either remembers or they don't.
- Fulfilling a favor deepens the relationship and unlocks unique dialogue (and sometimes unique lore about what the automaton knows about itself)
- The Trader might want specific components. The Broken One might want proof of something they half-remember.

**Environmental puzzles (discoverable, not signposted):**
- Scanning three specific objects in a zone triangulates a hidden signal
- A derelict's nav computer has coordinates that point to a location in a different zone
- A data fragment from Sonder references a hidden compartment on a specific derelict at Crom
- These reward exploration and cross-referencing but are never marked as objectives

#### The Three-Beat Tier Transition

When the player first reaches a new planet, three things happen in sequence. This is the "I made it" moment:

**Beat 1: Survive the Journey**
The first trip to a new planet is harrowing. The player barely has the gear. Heat warnings, hull warnings, fuel gauge dropping. Arriving alive feels like an achievement. The new zone's hazards are at the edge of what the player can handle - not impossible, but not comfortable.

**Beat 2: First Dock**
Docking at the new station for the first time. New NPC (or new state of existing NPC). New upgrades available in the store. New lore on station terminals. The station IS the reward - a safe harbor in a zone that just tried to kill you. This is where the player exhales.

**Beat 3: The Gate**
Finding, then powering, the planet's Gate. It is a serious amount of credits and the player usually cannot afford it on arrival - Beat 3 lands hours after Beats 1 and 2, which is what makes it a chapter break rather than a checklist. When it lands: the region draws itself onto the Chart, the transit list gets one entry longer, and the planet is permanently a minute away. The player has *claimed* this territory.

They have also just switched on a fifth of a mind, and the game will not mention it.

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
- Artifact components glow - a faint pulsing purple light (`Colors.TITAN`), the one hue the rest of the world never uses
- They look *different* from the practical junk - smoother, more geometric, almost organic
- The more artifacts installed, the more the ship looks like two things bolted together: a human junker and something *else*
- Late-game: a ship with full artifacts looks like a piece of the Titan that happens to have a person in it. Which, by then, is close to true.

> **TODO**: Design ship sprite/visual system for modular upgrade appearance.
> **TODO**: Define the specific visual for each upgrade tier.
> **TODO**: Design artifact visual language - what does Titan-tech look like?
> **TODO**: Design the Gate power-up sequence and the Chart region reveal that follows it.


---

### 4.10 Planetary Scanner & Landing

> **SUPERSEDED — in part.** See `docs/SWEEP.md` §4. This section describes the pre-Sweep design and is kept for reference only.

> "The Upgrade" is superseded: the scanner is not a purchase but a learned **Procedure**, `⟨echo⟩·<body>`. `has_planet_scanner` survives as a flag. Passive scan, ore seams, touchdown, harvest and depletion all stand — though seams need a new job now that they are no longer the pull on an upgrade (ADR 0007).


Planets and moons stop being scenery. An early upgrade, the **Planetary Scanner**, reveals planet data and the **ore seams** just under the surface, where the player sets down and harvests them for gems.

#### The Upgrade
- `UpgradeItem` **Planetary Scanner** - path `planet_scanner`, tier 1, cheap, sold at the home station. Distinct from Scanner PULSE (#45, minimap resource pings).
- `UNLOCK_FEATURE` → `has_planet_scanner`.
- Future tier 2: wider scan range, faster scan, or seams read deeper below the surface.

#### Passive Scan
- With the scanner installed, holding in **inner orbit** (inside the first gravity ring clear of the surface) fills a scan meter (~4s). An amber sweep arc rotates around the planet while it fills. Cruising through the outer gravity field does nothing.
- Dropping out of inner orbit before it completes resets the meter. Completed scans are permanent (saved).
- On completion a small terminal readout types out: name/designation, `planet_type`, `habitability`, gravity strength, and ore seams found.
- Unscanned planets show `? ? ?` on the minimap.
- The gravity pull makes holding position part of the challenge - tune meter speed accordingly.

#### Ore Seams
- A planet grows its own seams: 6-8 per rocky/ice planet, 3-4 richer ones per moon, none on the sun or a gas giant (no ground to land on). Seeded from the planet's save key, so a planet has the same seams every session.
- Visual: a handful of rough rock chunks sitting just under the surface (`OreDeposit.DEPTH_MIN`..`DEPTH_MAX`) - dark bodies (`Colors.ORE_ROCK`) with lit rims, cleave lines and a few mineral flecks, so a seam reads as part of the crust that has to be broken apart, not as a glowing marker. Shown on the minimap and in the tracking system.
- Buried (invisible, untrackable, unlandable) until the planet is scanned; the scan surfaces them with a ping.

#### Touchdown (`PlanetLandedState`)
- To land: touch the plain surface within `OreDeposit.REACH` of a seam, with low speed relative to the planet and the nose roughly away from the planet's centre. There is no pad - any ground near the seam will do.
- Too fast → hull damage + bounce.
- Once landed, the ship locks to the planet and follows its orbit. Thrust and fuel drain stop.
- Thrust to lift off. Nothing is thrown and nothing is charged: the ship is released where it stands, at rest relative to the planet, and climbs out on its own engines for as long as the player holds thrust. Heavy gravity or a full hold makes the climb longer, so it burns more thruster fuel on its own - and running the tank dry on the way up strands the ship where it sits. Let go early and it simply settles back down, undamaged.

#### Harvesting a seam
- A seam is worked with the *same* mechanic as a scrap node: landing next to one offers the HARVEST prompt, and ACTION runs the ordinary `HarvestTiming` hold-and-release sweep. There is no separate drill.
- `OreDeposit.HITS` hits break a plain seam open, `RICH_HITS` a rich moon seam (which also gets the narrow trophy zone). Each hit knocks gems loose; the last one breaks the seam and throws the big burst.
- PERFECT adds a gem and bumps the best one a tier. LATE or OVERLOAD still counts as a hit but only cracks off shards - the seam does not hand out free retries.
- A seam is the payday: emptying one is worth several scrap nodes, and a rich moon seam several times that again. Scrap is the trickle between seams.
- Lifting off mid-seam keeps everything already knocked loose and leaves the rest of the rock standing for the next landing (push-your-luck, without a separate bank key).

#### Depletion
- Harvesting eats the seam from the top down: the hits landed drive `OreDeposit.set_dug()` and the chunks crumble away one by one, shallowest first.
- After the last hit the seam is spent: the remaining rock breaks up and the seam leaves the view, the minimap and the tracker; the key does nothing there.
- It refills after ~5 min of game time (richer seams take longer). No countdown is ever shown - the seam just comes back.
- Seam state persists in `Save.gd` alongside planet orbital angles.

#### Build Order
1. Scanner upgrade item + `has_planet_scanner` flag
2. Passive scan + readout + persisted scanned state
3. Ore seam nodes, visuals, minimap/tracking markers
4. `PlanetLandedState`: touchdown + liftoff
5. Seam harvest + gem payout
6. Depletion / refill + save

> **TODO**: Deeper scans and deeper seams - seams further below the surface, reached by a later scanner tier.
> **TODO**: Per-planet-type seam variants (ice → shards + fuel, rocky → bigger gems) - v2.
> **TODO**: Tune scan time, touchdown speed threshold, liftoff fuel cost, refill time.

---

## 5. STORY & NARRATIVE

### 5.1 Storytelling Delivery

Lore is delivered through **every available channel**, layered so that engaged players get a richer picture:

| Channel | Content Type |
|---------|-------------|
| **NPC Dialogue** | Active story progression. Automatons give work, hints, and framing. Rare human NPCs provide perspective. |
| **Environmental** | Derelict ships with crew logs. Abandoned stations with terminal entries. Wreckage that tells a story through its arrangement. |
| **Ship's Computer** | Onboard terminal surfaces corrupted logs, system alerts, and increasingly strange messages. Main vehicle for Titan Influence hints. |
| **Data Fragments** | Collectible lore items - war records, personal diaries, scientific reports, military orders. Pieced together by the player. |
| **The Chart** | The one channel that is literally the Titan talking. It knows the system and gives it back a region at a time. |

### 5.2 Narrative Arc

**Act 1 - The Scavenger** (Outer Rim, Influence 0-1)
- Player wakes up, learns the ropes
- Meet the friendly automaton at the home station
- Establish the loop: fly, scrap, sell, upgrade
- Find a dead transit gate on their own, and buy a map with it
- Tone: Lonely but hopeful. A hard life but an honest one.

**Act 2 - The Explorer** (Mid-System, Influence 1-2)
- Ship is upgraded enough to push inward
- Encounter more complex structures and richer debris
- The transit network starts working and the solar system gets smaller
- First artifacts found - dramatically better than normal upgrades
- Environmental storytelling hints at the war and at what all this infrastructure was ever part of
- Tone: Wonder and growing unease. Something doesn't add up.

**Act 3 - The Instrument** (Inner System, Influence 3-4)
- The Titan is legible now, and it is not war debris: it is one machine, and three of its five parts are running
- Ship's computer starts surfacing messages that don't match any known source
- Automatons' helpful suggestions become harder to distinguish from compulsions
- Player's amnesia cracks - fragments of memory surface, all of them about hardware
- The player is deep enough that turning back means abandoning everything they've built
- Tone: Dread wrapped in curiosity. The sunk cost is real.

**Act 4 - The Wake** (Solar Proximity, Influence 5 → Core)
- The truth is unavoidable. There was never a trick, only a price list. The player has spent the whole game switching something on, for good reasons, and has been paid fairly every time
- The Titan's nature is revealed but **remains ambiguous**
  - Was switching it off defence, or execution?
  - Did the war start because of it, or was it a casualty?
  - Are the automatons compromised, or are they just the parts of it that stayed awake?
  - Is the void keeping things out, or is it where the Titan ends?
- The player buys the last two Gates with full knowledge of what they do
- **The ending is ambiguous.** The Titan is awake. What happens next is left to interpretation.

> **TODO**: Write detailed beat sheet for each act.

### 5.3 The Automatons

> **SUPERSEDED — in part.** See ADR 0008 and ADR 0009. This section describes the pre-fractures design and is kept for reference only.

> All three Automatons are one mind, cut apart, unaware of each other. Their dialogue and awareness levels stand; their **separateness** does not. They no longer sell Gates — they **translate** them. UNIT-7 is woken by the player rather than met.


**What they are:** leftover subprocesses of the Titan, still running in robot bodies. Not servants of it, not corrupted by it - *pieces* of it, left powered when everything else went dark, carrying on with the last shape of themselves they had. This is why they want the Gates powered, and it is also why they are not villains: a process that misses being whole is not lying when it says the road would be useful.

**Physical form:** Humanoid but clearly robots. Bipedal, head/torso/limbs - no attempt to pass as human. Exposed joints, visible wiring, screen-faces. They fit the cassette-futurism aesthetic: chunky, functional, held together with the same duct-tape-and-dreams philosophy as everything else.

**Communication:** Beeps and chirps (R2-D2 style emotional expression) with text displayed on their face-screens or nearby terminals. No voice synthesis. The beeps convey tone and emotion; the text conveys meaning. This makes them endearing - you learn to read their moods from sound alone.

**Awareness:** The automatons are **partially aware** of what they are. They have moments of lucidity or doubt - a pause before naming a Gate, a beep that sounds more like a sigh, text that starts to say one thing then corrects itself. They can't fully articulate it and they can't act against it, but they *feel* it. This makes them victims too, which complicates the "betrayal" - can you be angry at someone who was crying while they told you the truth?

**The clone factor:** Every named automaton has greeted hundreds of previous clone-players. They remember all of them. They pretend each one is the first. This is its own kind of horror - imagine greeting the same person over and over, knowing they'll die and a new copy will show up asking the same questions. Some handle this better than others.

**What they never do:** ask the player to destroy anything, or point at a Gate the player hasn't found. They name things, they frame things, and they are extremely good company.

---

#### NPC #1: UNIT-7 - "The Cheerful Guide"

**Location:** SR-7, the home station in orbit around Rook, Veld's moon (Outer Rim - first NPC the player meets). UNIT-7 is stationed there and never travels; the ship's comms panel is a link back to SR-7, not a unit aboard.
**Role:** Quest-giver, tutorial companion, emotional anchor
**Personality:** Upbeat, encouraging, relentlessly positive. Always has a task for you. Celebrates your wins, brushes off your losses. Makes the home station feel like *home*. The kind of presence that makes a bleak universe feel survivable.

**The truth beneath:** Their enthusiasm is genuine - they really do care about the player. And they are a piece of the thing that wants to be switched on, so every "oh, you should check out this interesting signal!" bends inward without either of them noticing. They're the friendliest leash in the solar system, and the leash doesn't know it's a leash.

**Awareness level:** Low. They have the fewest moments of doubt. Occasionally their text display will stutter or they'll pause mid-beep, but they recover fast. Of the three, they're the least aware of what they are - which is why they're the most convincingly helpful.

**Clone relationship:** They've done this welcome routine hundreds of times. Their cheer might be genuine, or it might be a coping mechanism calcified into programming. Late-game, the player might find logs where this automaton's text was much less cheerful with clone #3 or clone #47.

**Quest types they give:**
- "Go collect scrap from [location that happens to be on the way to something bigger]"
- "A signal appeared out past the ring - might be valuable salvage!"
- Naming the Veld Gate when the player finds it, with genuine delight, and explaining what it would do for their fuel bill

---

#### NPC #2: [NAME TBD] - "The Trader"

**Location:** Crom station (encountered when player pushes inward)
**Role:** Upgrade vendor, comic relief, world-building through commerce
**Personality:** Entrepreneurial, wheeling-and-dealing, fast-talking (fast-beeping?). Treats every transaction like it's the deal of a century despite the economy being functionally dead. Has opinions about everything. Calls the player "friend" or "partner" immediately. Their enthusiasm for trade in a post-apocalyptic wasteland is absurd and charming.

**The truth beneath:** The things they push hardest are the artifacts and the Gates - the Titan's own tech and the Titan's own switches. They frame recovered Titan hardware as "premium salvage" and a Gate as infrastructure investment. Their salesmanship is a subprocess arguing for its own reassembly, wearing a shopkeeper's apron, and every number in the pitch checks out.

**Awareness level:** Medium. They have more frequent moments of doubt than NPC #1. Sometimes mid-pitch, they'll stop, their screen will flicker, and they'll quietly beep before continuing as if nothing happened. Occasionally their text will display something like "you should not--" before correcting to "you should not miss this deal!" If the player pushes on these moments in dialogue, the trader deflects with humor.

**Clone relationship:** They've sold the same upgrades to hundreds of yous. They have a patter, a rhythm, callbacks to jokes the current player never heard. Sometimes they'll reference something "you said last time" and then awkwardly correct themselves.

**Quest types they give:**
- "Power that gate and you're at my counter in a minute flat. Do the maths, partner."
- "There's a cache of premium parts out by the old arrays - I'll give you a finder's fee"
- "Install this artifact - trust me, it's top shelf. Best I've ever seen. Where did it come from? Don't worry about it."

---

#### NPC #3: [NAME TBD] - "The Broken One"

**Location:** Roke station (late-game encounter)
**Role:** The alarm bell. The cracks in the facade made manifest.
**Personality:** Underneath the damage, they were probably once warm, competent, maybe even funny. Now they glitch between states - moments of clarity interrupted by directives that aren't theirs, coherent sentences that dissolve into static, beeps that shift from conversational to distressed mid-tone. Talking to them feels like watching someone fight a current that keeps pulling them under.

**The truth beneath:** They are the most visibly compromised automaton, but paradoxically the most *aware*. Their proximity to the inner system means the Titan is loudest here, and it also means they can feel most clearly what they are: a piece of it, helping the rest of it come back, knowing exactly what that means. They fight it. They mostly lose. Every Module that comes online makes them worse and makes them clearer at the same time.

**The board:** They are stationed in the room with the MODULE STATUS display. Five lamps. They cannot stop looking at it, and they have watched the player light most of them.

**Awareness level:** High - painfully so. Their text display sometimes shows two messages simultaneously - what they want to say and what they are about to say anyway. They'll hand over a set of coordinates and then immediately beep in a way that sounds like distress. In rare moments of clarity, they might say something like:

```
> DON'T--
> ...
> The gate's coordinates are uploaded to your nav system.
> Please hurry.
```

**Clone relationship:** They remember everything. Every clone. They've tried to warn previous ones. It never works - either the clone doesn't listen, or the words don't get out, or the clone dies and a new one shows up with no memory of the warning. This automaton is exhausted in a way machines shouldn't be able to be.

**Quest types they give:**
- The coordinates of the Roke Gate, delivered with visible reluctance
- Occasionally contradictory instructions - "go here" immediately followed by "don't go there"
- May try to say something that isn't the Titan talking, only to have their own text overwrite it mid-display

> **TODO**: Name automatons #2 and #3. #1 is **UNIT-7**; the other two should sit alongside it - functional/industrial (serial numbers? callsigns? names they chose for themselves?).
> **TODO**: Write sample dialogue for each across early/mid/late game.
> **TODO**: Design the specific "awareness moments" - what triggers them, how long they last, what the player can do during them.
> **TODO**: Define how each NPC's dialogue shifts at each step of Titan Influence. The Guide should get warmer. The Broken One should get quieter.

### 5.4 Titan Influence

**Titan Influence is one integer, 0 to 5: the number of Modules online.** Every "wrongness" effect in the game reads from it and from nothing else - not from playtime, not from zone, not from story flags. It changes only when the player powers a Gate, and it never goes down.

This is deliberate. The player should be able to work out, unaided, that the strange things started when they bought something.

**UI / Aesthetic Creep (scales with Influence):**
- CRT distortion increases subtly at each step
- HUD elements occasionally glitch or display wrong values briefly
- Terminal text sometimes includes characters or words that weren't there
- The amber palette shifts slightly toward warmer, more unsettling tones
- Static and interference in comms
- Loading screen boot messages become... different

**Gameplay Shifts (scales with Influence):**
- Ship occasionally drifts toward the sun (very subtle at 1, correctable at 3, a nuisance at 5)
- Scanner picks up signals that shouldn't be there, more of them at every step
- New "dreams" or visions play between certain trips (brief, abstract, unsettling)
- The ship's computer becomes more conversational, more helpful... more like a friend
- Artifacts recovered at a Module site perform better once that Module is online

**The Core is not step 6.** It is a separate, final state, and it is not a difficulty tier - it is the ending (see THE WAKE SEQUENCE).

> **TODO**: Write the exact effect set for each of the six states (0,1,2,3,4,5).
> **TODO**: Design the "dream" sequences.
> **TODO**: Decide whether the HUD ever shows Influence directly. Current answer: no. The board at Roke is the only readout in the game.

---

## 6. AESTHETIC & AUDIO

### 6.1 Visual Style

See `CLAUDE.md` for detailed visual guidelines. Core principles:

- **Cassette futurism** - CRT monitors, faded mustard phosphor, tape drives, blinking indicator lights
- **Monospace everything** - Terminal-style UI throughout
- **"Violet Signal" palette** - sun-bleached and warm, like a faded photo. Olive-black space (`#14130F`), khaki/umber hulls, faded mustard UI (`#E8C170`), dusty orange planets, sage for success, rust red for danger. Blue (`#6FB8D2`) means navigation. Purple (`#B58AE0`) is reserved for the Titan and Artifacts, so it always signals something rare or wrong. Source of truth: `scripts/Colors.gd`.
- **Minimalist** - No gradients, no polish, no sleekness. Functional and worn.

**Purple is a counter.** `Colors.TITAN` appears on artifacts, on Gates, and on the Chart regions the Titan has handed over. At Influence 0 the player has seen it perhaps twice. At 5 it is on their own hull, in their own map, and on every horizon. Nothing else in the game is allowed to use it.

### 6.2 Audio Direction

**Layered approach based on context:**

| Context | Audio |
|---------|-------|
| **Stations** | Lo-fi ambient - cassette warble, degraded samples, mechanical hum, distant clanking |
| **Deep space** | Near-silence - ship sounds only. Engine hum, hull creaks, scanner pings. Isolation. |
| **Discoveries** | Synth swells - analog oscillator tones for moments of wonder or revelation |
| **Titan presence** | Subtle wrongness - frequencies that shouldn't be there, reversed audio, sub-bass rumble. One more layer per Module online. |
| **Key story moments** | Full dark synth compositions - Blade Runner meets Alien: Isolation |

The silence of space is a feature, not a gap. Music should be earned and impactful.

> **TODO**: Define specific audio cues for game events (docking, harvesting, damage, alerts).
> **TODO**: Design the ambient layer that gets added at each step of Influence. The player should never be able to point at when it arrived.
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
- [x] Star chart (`SystemMap`)
- [x] Planetary scanner, landing and ore harvesting
- [x] Deep-space encounter field (`docs/ENCOUNTERS.md`)
- [x] Loading screen with boot sequence
- [x] Start menu
- [x] Pause menu
- [x] Game over / death screen
- [x] Save system
- [x] Star field shader background

### 7.2 Needed Systems

What needs to be built:

- [ ] Gates: powering (credits only), `GameState.powered_gates`, and transit between powered Gates
- [ ] Chart filtering on `powered_gates` and the staged region-reveal (ADR 0002)
- [ ] Titan Influence (0-5) as a single authoritative value everything else reads
- [ ] The Core's Gate at the Sun Station, and its refusal below 5/5
- [ ] Unidentified contacts: `???` until an Automaton names them on close approach
- [ ] Multi-planet tier progression (heat, radiation, thermal gating)
- [ ] NPC / Automaton dialogue system (beyond current SpacePort)
- [ ] Quest system
- [ ] Data fragment / lore collectible system
- [ ] Ship's computer terminal interface
- [ ] Influence effects system (UI distortion, gameplay drift, audio layers)
- [ ] Dream/vision sequence system
- [ ] Artifact upgrade category (separate from standard upgrades)
- [ ] Derelict ship exploration encounters
- [ ] Gate wardens and the terminal override that disables them
- [ ] The MODULE STATUS board at Roke
- [ ] The void boundary system
- [ ] Environmental storytelling props/scenes
- [ ] Multiple station types with different inventories
- [ ] Tractor beam / physics-based collection
- [ ] Sound system and audio management

---

## 8. OPEN QUESTIONS

### Answered
- ~~What is the Titan?~~ **The Titan** - a human-made weapon built out of the solar system itself, which transcended its design. Five Modules, one Core, six Gates.
- ~~What caused the war?~~ The Titan. Built as a weapon, it destroyed minds (method debated), couldn't be destroyed, only switched off.
- ~~Does it have desires?~~ Unknowable. Beyond human cognitive frameworks.
- ~~Who was the original?~~ **A Module engineer** who helped build the Titan and then helped shut it down. Template captured by a military cloning bay.
- ~~Gates - new construction, or old infrastructure?~~ Old. They are the Titan's own power switches, and reactivating them is the entire game.
- ~~Does the player ever destroy anything?~~ No. The player only ever restores. See ADR 0001.

### Still Open
1. **What IS the void?** The edge of the Titan's body? A side effect of the shutdown? Something unrelated?
2. **Are there other humans?** Or is the player (and their clones) truly the last human presence in this system?
3. **What happens after the Core comes online?** Does the Titan leave? Attack? Simply *be*?
4. **The ship** - is the player's ship special? Or is it truly just a junker? Could it hold Titan-tech already?
5. **Game length** - target playtime for a full run?
6. **Save structure** - one save slot? Multiple? Permadeath? (The clone system reframes this question interestingly)
7. **The Titan's "voice"** - how does its presence feel aesthetically? What distinguishes it from normal CRT glitches?
8. **The war timeline** - how long ago? Are there living veterans, or is this ancient history?
9. **Clone predecessors** - did any get to 4/5? Is there a Gate out there already lit that the player has no memory of paying for?
10. **The amnesia source** - is it Titan-contact damage to the original? Or a cloning artifact? Or both?
11. **Automaton names** - serial numbers? Callsigns? Names they chose for themselves? What naming convention fits the world?
12. **Can a player refuse?** There is no lose state and no way to power a Module down. Is "stop playing at 4/5" a real ending the game should acknowledge?

---

## 9. DEVELOPMENT PRIORITIES

Rough priority order for building out from the current prototype:

### Phase 1: Core Loop Polish
- Refine flight feel and resource collection
- Balance economy (resource values, upgrade costs, Gate prices)
- Add 2-3 resource types with different collection methods
- Polish station interaction flow

### Phase 2: World Expansion
- Build out the five-planet tier gradient (heat, radiation, thermal gating)
- Implement Gates: powering, `powered_gates`, transit
- Implement the Chart's `powered_gates` filter and the region-reveal
- Create the void boundary
- Add en-route encounters

### Phase 3: Narrative Foundation
- Design automaton NPCs
- Build quest system
- Implement ship's computer terminal
- Write Act 1 content, including the Veld Gate's first naming

### Phase 4: The Titan
- Implement Titan Influence (0-5) and everything that reads from it
- Design artifact upgrade path
- Build dream/vision sequences
- Build the MODULE STATUS board
- Write Acts 2-3 content

### Phase 5: Endgame
- TERRA-0 and the Sun Station
- The Core's Gate and its refusal
- THE WAKE SEQUENCE
- Write Act 4 content

### Phase 6: Polish
- Full audio pass
- UI distortion effects
- Environmental storytelling details
- Playtesting and balance

---

*This is a living document. Update it as decisions are made and the game evolves.*
