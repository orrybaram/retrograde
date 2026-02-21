# RETROGRADE - Ideas & Exploration

> Working notes for ideas being explored. Not yet committed to the design.

---

## The Three Curiosities

Three concrete, physical mysteries that pull the player deeper into the system. Inspired by Outer Wilds - each curiosity is something you can **point at** in the world, with lore breadcrumbs scattered across multiple locations. Progress is gated by **knowledge** (learning how something works), not by obtaining items.

The three curiosities interlock: The Heartbeat shows you the cage. The Predecessor Trail shows you the pattern of manipulation. The Spire is the destination both paths converge on.

---

### Curiosity 1: The Heartbeat

The sun pulses. Not like a star should. There's a rhythm - slow, deep, structured. The player's scanner picks it up in the first hour of gameplay as a strange repeating waveform they can't decode. It's always there, like tinnitus. As you get closer to the sun, it gets louder, more complex.

**What the player sees:** A waveform on their scanner that doesn't match any known signal. It's persistent, rhythmic, and clearly not random noise.

**Breadcrumbs:**

| Location | What you find |
|----------|---------------|
| SR-7 (Outer Rim) | Scanner picks up the signal. Faint, ignorable, but present. |
| KI-3 (Industrial) | Manufacturing logs show the containment grid was *tuned* to this pulse. Nodes respond to it, light up in sequence. |
| NT-12 (Research) | Scientists tried to decode the pattern. Research logs describe the work. Some researchers went mad. Partial frequency data available. |
| MV-1 (Military) | Military logs reveal the pulse started *after* the Titan was imprisoned, not before. This reframes everything - the pulse isn't the Titan's heartbeat. It's the Titan *knocking*. |

**Knowledge gate:** Piecing together frequency data from research terminals teaches you how to retune your scanner to the Heartbeat's wavelength. This isn't a key item - it's understanding the frequency pattern well enough to adjust your equipment.

**What it unlocks:** The containment grid lights up on your map. Every node, every connection, including the ones you've already destroyed. You can now *see* the cage. And you can see how much of it you've taken apart.

---

### Curiosity 2: The Predecessor Trail

While scrapping in the outer rim, the player finds a wrecked ship. It's their exact model. Same configuration, same patches, same cockpit layout. Unsettling, but easy to dismiss - lots of junkers out there.

Then you find another. Deeper in. Then another. A trail of identical wrecks stretching inward through the system, each one further than the last.

**What the player sees:** Wrecked ships identical to theirs, scattered through the system like a breadcrumb trail leading sunward. Each one got a little further than the last. Each wreck has visible details - damage patterns, cargo remnants, tool marks on nearby structures, nav coordinates scratched into bulkheads. Early on, this all reads as flavor. Set dressing.

**Design pattern: Decoration-as-Data** (inspired by Tunic's tapestries, Animal Well's environmental pillars). The physical evidence on each wreck *is* the story. The player doesn't need to unlock anything - they need to learn to **read crime scenes**.

**Breadcrumbs:**

| Location | What you find |
|----------|---------------|
| SR-7 (Outer Rim) | First wreck. Destroyed by debris collision - standard outer rim hazard. Cargo hold has basic scrap. Easy to dismiss as coincidence. |
| SR-7 (Moon) | Second wreck, tucked behind the moon. Same ship. Same patches on the hull. Cargo hold has the same scrap *plus* a containment relay component. Tool marks on a nearby dismantled relay match your equipment. |
| KI-3 (Industrial) | More wrecks in the shipyard debris. One has tool marks on a half-dismantled containment node nearby - it was mid-job when it died. Cargo holds show escalating upgrade tiers. These ships were getting better equipped over time. |
| NT-12 (Research) | A wreck near the research station. Cargo contains data cores. Nav coordinates scratched into the cockpit panel point toward MV-1. This one knew where it was going. |
| MV-1 (Military) | Wreck with blast damage consistent with automated defense systems. It got too close, too fast. Cargo is full of military-grade components and containment grid pieces. Nav scratches point to TERRA-0. |
| TERRA-0 (Homeworld) | The final wreck. Landed, not crashed. Whoever flew this made it. They parked, got out, and walked toward the Spire. They didn't come back. |

**Knowledge gate: Forensics.** The gate isn't a lock - it's literacy. Early in the game, a wreck is just a wreck. The player doesn't have the context to read the evidence. But as they learn about ship systems (from upgrading their own), containment architecture (from dismantling it), weapon signatures (from encountering military hazards), and the cloning system (from NT-12 research), each wreck becomes legible.

The aha moment isn't a single trigger. It's cumulative. At some point, the player looks at a wreck and realizes: *the damage pattern matches the hazards in this zone. The cargo matches the upgrades I have at this stage. The tool marks match my tools. The nav coordinates point to where I'm going next.* Every predecessor followed the exact same path. Because they were all the same person, doing the same jobs, guided by the same hands.

**What it unlocks:** Not a door or a decryption. A **reading** of the world. Every wreck the player revisits now tells a chapter of the story. The trail maps the Titan's manipulation across dozens of attempts - each clone got a little further, learned a little more, died a little deeper in. The player can now trace the full arc: from first clone (barely survived the outer rim) to the final predecessor (made it to TERRA-0 and walked toward the Spire).

The player-level realization: "These aren't random wrecks. They're all *me*. And I'm further along than any of them." The game never tells you this. You figure it out by reading the evidence.

---

### Curiosity 3: The Spire

From mid-system, long-range scanners can detect a structure on TERRA-0 that doesn't match anything else. It's not containment grid. It's not military. It's not industrial. It's a needle rising from the largest continental fragment, pointed directly at the sun. It predates everything in the system.

**What the player sees:** A massive anomalous structure on the cracked homeworld, visible on scanners from mid-system. It looks wrong - too old, too intentional, too different from everything else.

**Design pattern: Lore-as-Instruction + Decoration-as-Data** (inspired by Outer Wilds' Ash Twin warp tower, Tunic's Trunic language). The Spire's interface uses a notation system - containment engineering notation - that the player has been encountering the entire game without realizing it's functional.

**The notation system:**

Containment engineering notation appears everywhere in the game as what looks like technical flavor text:
- **Stamped on pylons** the player scraps for parts - manufacturing labels, serial numbers, spec codes
- **Etched into grid nodes** they dismantle - warning symbols, capacity ratings, connection identifiers
- **Displayed on terminals** at NT-12 - research papers full of diagrams and formulae
- **Printed on military equipment** at MV-1 - operational manuals, maintenance procedures

The player sees this notation constantly and treats it as set dressing. It looks like the kind of dense technical labeling you'd find on real industrial equipment - meaningful to someone, but not to you. You're a scrapper. You don't need to read the serial number to sell the pylon.

**Breadcrumbs (the rosetta stone, in pieces):**

| Location | What you find |
|----------|---------------|
| KI-3 (Industrial) | Manufacturing records reference building *around* a pre-existing structure. Containment notation appears on assembly instructions - players see it but don't read it. |
| NT-12 (Research) | A researcher's paper attempts to formalize containment theory. It's a **partial rosetta stone** - it explains what some of the notation symbols mean as part of the scientific analysis. Not framed as "here's how to read the language." Framed as "here's the math behind the containment grid." Symbols for grid sector, energy state, connection type, and capacity are defined in context. |
| MV-1 (Military) | Military training manuals for containment engineers. A different **partial rosetta stone** - operational rather than theoretical. Symbols for activation sequence, release protocol, safety lockout, and emergency procedures. Written as dry military documentation, not as a puzzle key. |
| Home Station | The Cheerful Guide's oldest logs (from clone #1) mention being told to "never direct the subject toward the central artifact." |
| The Trader | Has a data fragment about "something that was there before we built anything." |

**Knowledge gate: Literacy.** The Spire isn't locked by a door or a code. It's physically accessible the moment you can survive TERRA-0. But its interface is covered in containment engineering notation - the same notation the player has been scrapping off pylons for the entire game.

A player who read the research at NT-12 can recognize some symbols: "this means grid sector, this means energy state." A player who also read the military manuals at MV-1 can recognize more: "this means release sequence, this means safety lockout." Put them together and the Spire's interface becomes **readable**. Not because the game flips a flag. Because the player actually learned what the symbols mean.

A player who skipped the research and rushed to TERRA-0 sees an interface covered in the same "technical junk" they've been ignoring the whole game. They can poke at it, but they don't know what anything means. They might accidentally activate something. They might leave and come back after finding the research. The game doesn't stop them either way - it just means less.

**The aha moment:** The player looks at the Spire's interface and recognizes symbols from a pylon they scrapped ten hours ago. "Wait - I've been looking at this language the entire game." The notation that was manufacturing labels on junk equipment is *engineering controls* on the Spire. Same language, different context. The decoration was always data.

The deeper aha (for players who connect it to the Predecessor Trail): the Original - the template for every clone - was a containment engineer. The reason the notation feels learnable is because the player is a copy of someone who *wrote* it. The research didn't teach them a foreign language. It reminded them of their native one.

**What it unlocks:** The Spire is the master switch. The original engineers built it as the off-switch for the cage, because they weren't sure the imprisonment was right. The Titan has been guiding every clone toward this moment, but the engineers left it here on purpose too. Both sides want you to pull the lever, for very different reasons.

**What the interface actually looks like:**

The Spire's controls show a schematic of the containment grid using the notation system. The player can see:
- Which grid sectors are active (the ones they haven't dismantled)
- Which are dark (the ones they have)
- The energy state of the whole system
- A release sequence - a specific order of operations to fully drop the cage

If the player has also completed the Heartbeat curiosity (scanner shows the grid), the Spire's schematic maps directly onto what their scanner displays. The two curiosities confirm each other - same cage, seen from two angles.

---

### How They Interlock

```
The Heartbeat          The Predecessor Trail         The Spire
(What is the cage?)    (What am I?)                  (What do I do?)
     |                       |                            |
     v                       v                            v
Shows you the grid     Shows you the manipulation    The convergence point
     |                       |                            |
     +-----------> All three paths lead to <--------------+
                    the same question:
              Do you pull the lever?
```

- The Heartbeat teaches you the *scale* of what you've been dismantling
- The Predecessor Trail teaches you the *pattern* of how you've been used
- The Spire gives you the *choice* - with full knowledge of what it means
- A player who reaches the Spire without the other two curiosities can still act, but they won't fully understand what they're doing (mirroring the previous clones)

---

### Knowledge Gates vs. Upgrade Gates

These curiosities exist alongside the existing upgrade-gating system (fuel tanks, hull plating, heat shields, etc.), not as replacements. The upgrade gates control *physical access* to deeper tiers. The knowledge gates control *understanding* of what you find there.

A player could theoretically reach TERRA-0 with full upgrades but zero curiosity knowledge. They'd survive the environment but the Spire would be incomprehensible. The game doesn't block you - it just means less. This is the Outer Wilds principle: the real gate is always knowledge.

### Design Patterns at Play

These curiosities draw on specific knowledge-gate patterns from games that do this well:

| Pattern | Source | How it's used here |
|---------|--------|--------------------|
| **Decoration-as-Data** | Tunic (tapestries encode D-pad inputs, Trunic language hides in plain sight) | Containment notation on scrapped pylons is the same language as the Spire's interface. Wreck damage patterns are readable narratives, not flavor. |
| **Tool Recontextualization** | Outer Wilds (scout as ghost matter detector) | The scanner, used for finding resources, becomes a containment grid visualizer when retuned to the Heartbeat frequency. Same tool, new understanding. |
| **Retroactive Map** | Animal Well (UV lantern reveals invisible ink on already-visited walls) | Retuning the scanner doesn't reveal new space - it reveals a new *layer* of space you've already been through. The grid was always there. |
| **Lore-as-Instruction** | Outer Wilds (Ash Twin warp tower timing buried in Nomai text) | Research papers and military manuals at NT-12 and MV-1 contain the rosetta stone for the Spire's interface, but they're formatted as lore, not as puzzle keys. |
| **Cumulative Literacy** | Tunic (Trunic language decoded gradually) | No single moment "unlocks" understanding. The player accumulates context until things click. The game never announces "you now understand." |

The critical principle: **the player is the one making the connection, not the character.** The game never tells you "you've unlocked understanding." You just look at something you've seen before and realize you can read it now.

---

### Open TODOs

> ~~**TODO:** Define specific "aha moment" triggers for each knowledge gate~~ - Defined above: Heartbeat = echolocation reframe, Predecessor Trail = cumulative forensic literacy, Spire = notation recognition.
> **TODO:** Design the scanner retuning interaction for the Heartbeat - how does the player actually "learn" the frequency? What's the UI for this?
> **TODO:** Write the final predecessor's message at TERRA-0 - what did the last clone who reached the Spire leave behind?
> ~~**TODO:** Design the Spire's interface~~ - Defined above: containment engineering notation system, partial rosetta stones at NT-12 and MV-1.
> **TODO:** Map out which breadcrumbs are missable vs. required - can a player solve a curiosity with partial information?
> **TODO:** Design the containment engineering notation system - what do the symbols actually look like? How many symbols, how complex?
> **TODO:** Define the specific wreck locations and what forensic evidence each one contains.
> **TODO:** Write the NT-12 research paper (partial rosetta stone) and the MV-1 military manual (second partial rosetta stone).

---

## Anomalies

Rare, unexplained events that inject light horror into the routine gameplay loop. These should be **infrequent, brief, and never acknowledged by the game.** No quest log entry. No NPC dialogue about them. No confirmation that what the player saw was real. They exist to make the familiar feel slightly unsafe.

The tone is *wrongness*, not jump scares. The player should think "...did that just happen?" and have no one to ask.

These serve the larger design in two ways:
1. They seed unease about the clone system and the Titan's influence long before either is revealed
2. They make the player distrust their own perception, which mirrors the character's situation

### Design Rules

- **Rare.** These should not happen every run. Some players might go hours without seeing one. Frequency can increase subtly as the player progresses inward / dismantles more containment.
- **Brief.** A few seconds at most. Blink and you miss it. Never lingering long enough to study.
- **Deniable.** Always accompanied by a CRT glitch, static burst, or scanner flicker - something that lets the player rationalize it as a display error. The game gives you an out. Whether you take it is up to you.
- **Silent.** No sound cue that says "something spooky happened." At most, a brief crackle of static or a subtle tone shift in the ambient hum.
- **Escalating.** Early anomalies are easy to dismiss. Later ones are harder to ignore. The progression should mirror the Titan's growing influence.
- **Never explained.** Some anomalies connect to the clone system. Some connect to the Titan. Some connect to neither, or to things the player will never fully understand. Not everything has an answer.

### Anomaly Ideas

**The Ghost Ship**
Returning from a routine harvesting run, the player approaches the station and sees a ship already docked - identical to theirs. Same hull, same patches, same configuration. CRT glitch. It's gone. The docking bay is empty. Was it a reflection? A scanner echo? A previous clone's ship that hasn't been cleaned up yet?

**The Extra Log**
The ship's computer shows a flight log entry the player didn't make. A route they didn't fly. A docking timestamp from when they were out in the field. It's in their handwriting - their log format, their shorthand. Brief static flicker, and the entry is gone. The log count doesn't change.

**The Wrong Reflection**
Passing a reflective surface on the station (a polished hull panel, a dark monitor), the player's ship is reflected - but the reflection is slightly wrong. A different arrangement of patches. An antenna that isn't there. A cargo pod they don't have. It only lasts a frame or two.

**The Watcher**
Deep in a debris field, the player's scanner pings something nearby. Close. Very close. They look around - nothing. The ping disappears. A moment later, at the edge of their vision, something moves away. It was the size and shape of a ship. By the time they turn, it's gone. The scanner shows nothing.

**The Station Voice**
Docking at the station, the comms channel briefly picks up a voice. Not an automaton's beeps-and-text. A human voice. It says something the player can almost but not quite make out - their name? A warning? A greeting? Static eats it. The automatons show no sign of having heard anything.

**The Familiar Wreck**
The player finds a wreck they're certain they've already looted. Same location, same orientation. But the cargo hold has items in it. Items the player currently has in *their* cargo. Screen tear. The wreck is empty again, as expected. Cargo is normal.

**The Heartbeat Pause**
After the player learns to hear the Heartbeat on their scanner, it occasionally stops. Complete silence from the sun. A held breath. Then it resumes. During the pause, the ship's instruments all read normal. Nothing changed. But the silence felt *aware*. Like something noticed you listening.

**The Doppelganger Signal**
The scanner picks up a ship transponder broadcasting the player's own ID. It's heading sunward, deeper into the system, at a speed the player's ship can't match. If the player follows, they never close the distance. It fades from scanner range. It was never on a trajectory that intersected any known location.

**The Boot Sequence**
On a routine startup (after docking, after loading), the ship's boot sequence displays normally - except for one line buried in the scroll that reads differently. Maybe it says `CREW: 2` instead of `CREW: 1`. Maybe it says `WELCOME BACK (AGAIN)`. Maybe it displays a clone iteration number. It scrolls past at normal speed and is not repeated.

### Escalation Tiers

| Tier | When | Examples | Frequency |
|------|------|----------|-----------|
| **Ambient** | Outer rim, early game | The Boot Sequence, The Extra Log | Very rare - once every few hours of play |
| **Unsettling** | Mid-system, after first containment dismantling | The Ghost Ship, The Wrong Reflection, The Familiar Wreck | Occasional - the player starts to notice a pattern |
| **Intrusive** | Inner system, significant containment damage | The Watcher, The Station Voice, The Doppelganger Signal | More frequent, harder to dismiss |
| **Resonant** | Near TERRA-0, grid nearly collapsed | The Heartbeat Pause, combinations of the above | The anomalies start *responding* to the player's actions |

> **TODO:** Define exact trigger conditions and probability curves for each anomaly.
> **TODO:** Determine which anomalies are clone-related vs. Titan-related vs. ambiguous.
> **TODO:** Design the CRT glitch/static visual treatment that accompanies anomalies - needs to be distinct enough to become a Pavlovian dread trigger but subtle enough to be deniable.

---

## The Locked Door (The Dead Object)

Near the home station - close enough that the player flies past it on every single harvesting run - there's a physical object in space. A structure. Not debris, not scrap. Something built with intention. It's just... there.

The player can see it. Fly up to it. Bump into it. Their scanner registers it as a blip, but labels it `UNKNOWN`. No resource type. No interaction prompt. It's not harvestable. It's not dockable. It doesn't respond to anything the player can do. It's inert. A dead object.

The player shrugs and moves on. They've got scrap to collect.

### The Experience Over Time

**First few hours:** The player notices the blip, investigates, finds nothing useful. Files it away as background scenery. Maybe it's decorative. Maybe it's a future content thing. They stop thinking about it.

**Ongoing:** It's always there. Every time they leave the station, every time they come back. It becomes part of the landscape - as familiar and ignorable as the station itself. The scanner still shows the `UNKNOWN` blip. The player's eye learns to skip past it.

**After the Heartbeat:** The player retunes their scanner to the Heartbeat frequency. The containment grid appears on their map. And the dead object *lights up*. Not because it changed - because the scanner can finally read it correctly. It's a containment relay node. Energy is flowing through it. It's connected to the grid. Lines of energy stretch from it toward the sun, linking it to other nodes across the system.

It was always active. It was always part of the cage. The player flew past it hundreds of times. Their scanner was always detecting it. They just didn't have the context to understand what they were looking at.

### Why This Works

- **It's not hidden.** The player sees it from session one. There's no reveal where a secret door opens. The object was always visible, always tangible, always on the scanner.
- **It's not locked.** There's no key, no upgrade, no quest flag. The "lock" is the player's own understanding. The scanner said `UNKNOWN` because the scanner didn't have the right frequency mode, not because the game was withholding access.
- **It recontextualizes the familiar.** The most powerful moment isn't finding something new - it's realizing something old was never what you thought it was. The player's home turf, the route they've flown a hundred times, had a piece of the Titan's cage in it the whole time.
- **It creates a choice.** Now the player knows what this object is. The automatons have been sending them to scrap pylons just like this one. Every other node has been framed as "old junk, tear it down for parts." But this one is *right next to home*. This one they've lived beside. Do they scrap it like all the others? Or does knowing what the grid is change how they feel about dismantling it?

### Connection to The Three Curiosities

The Dead Object is a physical anchor for the Heartbeat curiosity. It gives the Heartbeat's knowledge gate a **tangible payoff** near home rather than only in distant, late-game locations. The moment the scanner retunes and the dead object resolves, the player understands - viscerally, not just intellectually - what the Heartbeat frequency reveals. And they immediately wonder: *what else have I been flying past?*

> **TODO:** Design the Dead Object's visual - what does a containment relay node look like? It should read as "intentional structure" without reading as "important game object" on first encounter. Industrial, mundane, forgettable.
> **TODO:** Determine its exact placement relative to the home station and the common flight path to the first harvesting zone - it needs to be in the player's peripheral vision constantly.
> **TODO:** Define what happens if the player scraps it after the Heartbeat reveal - does it affect the station? Does the grid visually change? Do the automatons react?

---

## The Boot Terminal

When the player dies, there's a boot sequence - text scrolling, system initialization, then a prompt: `PRESS ENTER TO CONTINUE`. The player presses enter, they respawn, the game continues.

But what if that terminal is *real*? What if the player could type into it?

### The Idea

The boot screen isn't a game over screen. It's the cloning bay's actual terminal, running its actual boot sequence, printing its actual system output. The `PRESS ENTER TO CONTINUE` isn't a game UI prompt - it's the cloning system asking for confirmation to deploy the next clone. The player has been interacting with a real in-world computer every time they die. They just never tried typing anything other than enter.

If the player types something - anything - the terminal responds. It's a command line. It accepts input.

### What's There (not figured out yet, but possibilities)

This is deliberately unresolved. Some directions it could go:

- **Clone deployment logs.** `history` or `log` commands showing previous clone activations - timestamps, durations (how long each clone survived), cause of termination. The numbers are high.
- **System diagnostics.** The cloning bay's own status - template integrity, remaining deployments, hardware condition. Maybe the counter that's counting down.
- **The Original's credentials.** The terminal recognizes the neural pattern and grants engineering-level access. What that access reveals depends on how this connects to the Spire / containment notation system.
- **Messages between clones.** Previous clones who figured out the terminal left notes for the next one. A secret message board written by versions of yourself, hidden inside the machine that makes you.
- **The Titan's back door.** The cloning system is compromised. Poking around in the terminal reveals processes that shouldn't be running - something else is in this system, watching, nudging, making sure the next clone deploys correctly and heads in the right direction.

### Why This Could Work

- **It rewards curiosity about the game itself.** The player who thinks "what if I type something?" instead of pressing enter is the player this game is built for.
- **It's the most intimate locked door.** It's not out in the world - it's in the moment of death. The player's most vulnerable point is also their most powerful access point.
- **It ties directly to the clone system.** The boot terminal IS the cloning bay. Every death has been a real event happening on real hardware. The respawn screen was never a game abstraction.
- **Knowledge gate potential.** Early on, the player might find the terminal but not know what commands to use. Learning about cloning infrastructure at NT-12 could teach them command syntax. The containment notation rosetta stones could unlock deeper access levels. The terminal grows with the player's knowledge.

> **TODO:** This is a seed idea. Don't design the full terminal yet. Let it sit and see how it connects to the curiosities and the clone system as those solidify.
> **TODO:** Determine if this is a secret the player discovers on their own or if breadcrumbs elsewhere hint that the boot terminal accepts input.
> **TODO:** Consider: does the terminal persist between deaths? Can clone #N read what clone #N-1 typed?
