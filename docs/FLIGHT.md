# RETROGRADE - Flight

The ship: how it flies, what it burns, what breaks it, where it sets down, and what
happens when it is lost.

The *system*. ADR 0010 is the two-drive decision; ADR 0004 is how hard the Bodies pull.
Freight - clamping, the Lug, carrying, the SHIP screen and Stores - is `docs/FREIGHT.md`.
The Sweep and harvesting are `docs/SWEEP.md`. Act 1 is `docs/OPENING.md`.

---

## 1. The Ship

A `RigidBody2D` (`entities/Ship/Ship.tscn`, `entities/Ship/Ship.gd`) with no physics
gravity and no linear damping: nothing slows it but the player. It is a junker, and every
limit it has is fixed - nothing is bought (ADR 0007).

The scene instance in `scenes/Main.tscn` overrides `Ship.tscn`'s own values: **mass 3.0**
and `fuel_consumption_rate` 2.0. Those are the numbers the game runs on; the base scene's
mass of 50000 is never seen in play.

Mass is the ship plus whatever it is carrying, and every force on the ship divides by it:

| Adds mass | How much | Owner |
|---|---|---|
| Gems in the hold | `cargo_mass_multiplier` 0.01 per weight unit | `Ship.update_mass_from_cargo()` |
| Fitted Components | each part's own mass, offset from the hull | `Ship._combined()`, `docs/FREIGHT.md` |
| Clamped Freight | the piece's mass, at the nose | `Ship._clamp_freight()`, `docs/FREIGHT.md` |

Components and Freight also add inertia, which slows turning (`Ship.turn_ratio()`). The
bare, empty ship is exactly mass 3 with its centre of mass at the origin.

### States

`StateMachine` under the ship; each state owns its camera zoom, particles and cleanup.

| State | When | `action` does |
|---|---|---|
| `FlyingState` | open flight, the default | Sweep; dock; magnet a piece of Freight |
| `CarryingState` | exactly while Freight is clamped | hold 0.8s to let go |
| `HarvestingState` | focused on one scrap | the harvest sweep (`docs/SWEEP.md`) |
| `LandedState` | docked at a port | open the port, or SR-7's core terminal |
| `GateDockedState` | docked in a Gate's berth | the Gate terminal (`docs/WORLD.md`) |
| `PlanetLandedState` | sitting on a Body over a seam | harvest the seam |
| `DestroyedState` | hull reached 0 | nothing |
| `ConsumedState` | the Void took the ship | nothing |

The engines run only in `FlyingState`, `CarryingState` (which extends it) and
`HarvestingState`; everywhere else `Drive.rest()` is called each step.

## 2. Controls

Every input is declared in `scripts/Controls.gd`, registered into the InputMap at boot and
rebindable from the CONTROLS screen (start menu and pause menu,
`playtests/controls.play`). Flight defaults:

| Action | Keyboard | Pad |
|---|---|---|
| `thrust` | UP, W | RT, left stick up |
| `reverse_thrust` | DOWN, S | LT, left stick down |
| `turn_left` / `turn_right` | LEFT/RIGHT, A/D | left stick, D-pad |
| `strafe_left` / `strafe_right` | Q / E | LB / RB |
| `boost` (the Burn) | SHIFT | B |
| `action` (Sweep, dock, clamp) | SPACE | A |
| `radio_next` | TAB | Y |
| `open_log` / `open_map` | I / M | BACK / R3 |
| `pause` (fixed) | ESC | START |

Flight input is ignored while the Chart, the Log, a port dialogue, the start menu or the
pause menu is open (`FlyingState._is_ui_blocking_input()`). During a new game's manual
diagnostic, `ControlLock` holds individual controls off and caps thrust at 50 px/s in
SR-7's frame (`docs/OPENING.md`).

## 3. The Two Drives

The ship has two engines, not one throttle with a gauge attached (ADR 0010). Both are
modelled by `entities/Ship/Drive.gd` and applied in `FlyingState._apply_thrust()`.

- **Aux** - ordinary thrust. Solar-electric, scavenging reaction mass from the dust it
  flies through. **Free, always available, never out.** There is no Aux fuel, meter or
  cough anywhere in the code.
- **Burn** - the `boost`, held with thrust on. Chemical, on volatiles. The only thing fuel
  is ever spent on.

| Tuning | Value | Effect at mass 3 |
|---|---|---|
| `thrust_power` | 262.5 | Aux: 87.5 px/s² |
| `cruise_speed` | 300 px/s | Aux stops adding speed here |
| `boost_power_multiplier` | 2.667 | Burn: force ~700, 233 px/s² |
| `fuel_consumption_rate` x `boost_fuel_multiplier` | 2.0 x 3.0 | Burn spends 6 fuel/s |
| `Drive.CAPACITY` | 150 | 25s of Burn from full |
| `turn_speed` | 5 rad/s | unladen |
| `FlyingState.STRAFE_POWER` | 0.6 | strafe at 60% of Aux |

### The cruise cap

Aux thrust is held to `cruise_speed` (`FlyingState.cruise_velocity`). It can speed the
ship up to 300 px/s, never past it, and never faster than the ship already is once over
it - but it always steers and always brakes. Only the Burn and gravity take the ship past
the cap, and Aux thrust never drags a boosted ship back down. Short hops around a debris
field are untouched by it (1s of thrust from rest is well under); the long haul between
planets becomes a slow cruise unless the player spends fuel. `playtests/cruise.play`,
`test/CruiseSpeedTest.gd`.

So in the game as built the Aux is low-speed as well as low-thrust, and the Burn is both
authority over momentum *and* speed: a full tank is ~5,800 px/s of delta-v against a 300
px/s cruise.

### Turning and strafing

Unladen, turning is instant: the ship spins at exactly `turn_speed` while the key is held
and stops the moment it is let go. With Freight or Components on, it turns slower and
winds up and down (`FlyingState.turned_spin`, `TURN_LAG` 0.3s).

Strafe (Q/E) slides the ship sideways without turning it. It is side thrust on the Aux,
held to the cruise cap, and the boost never touches it - strafing never burns fuel.
`playtests/strafe.play`.

### Why two drives

Fuel used to be the thing keeping the ship alive, which made the gauge the most anxious
object on screen in a game with no combat, and running dry a hard stop. Splitting the
drives means **an empty tank does not strand the player - it makes them clumsy.** They can
still go anywhere; they just cannot react. That never takes control away.

The physics is honest. Real electric propulsion is 25-250 mN at 2,000-5,000 s specific
impulse; chemical is millions of newtons at 300-450 s. NASA's NEXT ion thruster fired for
over 48,000 hours across five and a half years on about 870 kg of xenon: on any human
timescale an ion drive is free. The ~10x specific-impulse gap is the real reason the Burn
drains a gauge and the Aux does not. The Burn/Aux thrust ratio is a feel number (2.667),
not the real 1000:1.

Aux thrust is **flat**: it does not vary with distance from the sun. Real arrays are sized
for the worst case, so a craft built to work across the system sizes for the outer rim. A
distance gradient was rejected - it would be a third tuning value multiplying against
thrust and cargo mass, and it would make the outer system, where the game opens, the most
sluggish place in it. What survives is fiction: **the Aux runs on sunlight, and the sun is
the Core.**

## 4. Fuel

The tank is `Drive.fuel`, 0..150, clamped; every write emits `Drive.changed`.

**Where it comes from.** Docking at a port on a running SR-7. Once the core has
cold-started (`Progress.CORE_STARTED`), every dock and every relaunch tops the tank up to
half (`Drive.FREE_FRACTION`, 75) for nothing, never higher and never draining a fuller tank
(`Drive.free_floor`, `test/FreeFuelTest.gd`). Past half, the port spends Stores on it
(§7). A new game wakes with the tank dry (`Ship.reset_to_initial_state`). Gates give no
fuel. Nothing else refuels the ship.

**Levels and the cough.** `Drive.level()`:

| Level | Tank | In flight |
|---|---|---|
| OK | above 25% | nothing |
| LOW | 25% and under | vapor; a Burn coughs every 1.2-2.8s |
| CRITICAL | 10% and under, or empty | heavy vapor; a Burn coughs every 0.25-0.8s |

A cough cuts the Burn for 0.2-0.4s with a backfire and a hull jolt (`LowFuelEffect`).
Only a Burn being tried can cough - including one tried on an empty tank, where there is
nothing to burn and the engine says so. Aux thrust never coughs. Docked or landed, the
warning reads OK (`Drive.warning`). The cough uses its own `RandomNumberGenerator`, never
the shared gameplay RNG. `playtests/alerts.play`, `test/DriveTest.gd`, `test/FuelTest.gd`.

**Running dry** emits `Drive.depleted`, which nothing acts on (`Main._on_fuel_depleted` is
empty). The ship flies on, on Aux.

**The gauge** is `ui/BoostGauge.gd`, wrapped around the minimap's rim: the tank as blocks
(one per 10 fuel), and outside it a bar showing the engine's output right now - 1x on Aux
(labelled AUX), the boost multiplier on a lit Burn. It reads output, not a resource.

## 5. Gravity

Each Body's `PlanetGravityField` pulls the ship inside `radius x gravity_radius_multiplier`
(3.0, 5.0 at the sun) with a force through its centre of mass. Mass and the rule behind it
are ADR 0004. Gravity, Aux and Burn are all forces divided by the same ship mass, so a full
hold or a heavy Component changes how fast the ship climbs but never whether it can.

ADR 0004's "% of thrust" table was measured against a `thrust_power` of 350. Against
today's Aux (262.5) every row is a third heavier:

| Body | Surface pull vs Aux | vs Burn |
|---|---|---|
| Sun | ~380% | ~145% |
| TERRA-0 | ~99% | ~37% |
| Sonder | ~96% | ~36% |
| Crom | ~81% | ~31% |
| Veld | ~64% | ~24% |
| Rook | ~57% | ~21% |

## 6. Hull and Damage

`max_hull` 100, held by a `HealthComponent` with a 0.1s damage cooldown, so a graze that
rubs for several frames is one wound. Repair is only at a port (§7).

| Source | Hurts above | Damage |
|---|---|---|
| Hitting any rigid body (`FlyingState.integrate_forces`) | 50 px/s along the normal | (speed - 50) x 0.5 |
| Loose Freight (`Freight.KNOCK_DAMAGE_SPEED`) | 250 px/s | same rule |
| Scrap and debris on its orbit (`OrbitalNode`) | 150 px/s relative | (speed - 150) x 0.5; the ship bounces off at 30% |
| A hard touchdown (`Touchdown`) | 40 px/s into the ground | max(6, (speed - 40) x 0.5) |

A clamped load collides, but its knocks do not reach the hull (ADR 0012).

**What a hit looks like.** A camera kick scaled by the hit (full at 20 damage), the HUD's
readouts scramble, and `HullAlarm` tears the picture. Being merely low never scrambles the
readouts - the player has to be able to read the hull bar exactly when it matters.

| Level | Hull | Shows |
|---|---|---|
| LOW | 35% and under | venting smoke and arcs, blinking bar, banner, rust vignette |
| CRITICAL | 15% and under | faster and heavier, three breaches, a strobe on the hull |

`entities/Ship/LowHullEffect.gd`, `scenes/HullAlarm.gd`, `playtests/hull.play`,
`test/LowHullWarningTest.gd`. The dev panel's invulnerable toggle (`dev_invulnerable`)
blocks all damage.

## 7. Docking

Anything in group `dockable` that implements `Dockable`'s methods: a `SpacePort` or a
Gate's berth. `Ship.dock_at()` is the only way in; it hands the berth to `LandedState`
(port) or `GateDockedState` (Gate).

- **The approach.** Within the berth's reach (60 px for both), under 50 px/s relative to
  it, and within 30° of its heading (`Dockable.approach_ok`). The DOCK prompt shows when
  all three hold; `action` docks. A port only takes ships while `deployed` - SR-7's dock
  is retracted until Act 1 brings it out (`DockArm`, `docs/OPENING.md`).
- **Locking on.** The ship eases onto the berth over 0.5s, lies across its surface, then
  rides it rigidly, matching its velocity. Camera zoom 2.5 at a port, 2.0 at a Gate.
- **Leaving.** Thrust or reverse undocks, unless a menu is open. The dock prompt is
  suppressed for 2s after leaving so the ship does not re-dock as it backs off.
- **At a port** (`LandedState`): the free half fills (a full tank takes `REFUEL_TIME` 5s,
  so the free half ~2.5s); if the port is open the hold is flown in as Stores (the
  Deposit), then the port dialogue opens and Stores are spent with no menu - hull first
  at 3 Stores a point over `REPAIR_TIME` 3s, then fuel past half at 2 Stores a point,
  until the Stores run out (`docs/FREIGHT.md`, `playtests/dock.play`,
  `test/DockServiceTest.gd`). A port nobody runs takes no delivery and opens nothing.
- **Autosave** on docking, when the free fill finishes, after the Deposit and after
  service.

A ship carrying Freight cannot dock.

## 8. Touchdown and Liftoff

There are no landing pads on Bodies. The ship sets down on plain ground within reach of a
revealed ore seam (`entities/Ship/Touchdown.gd`, `PlanetLandedState`). Away from a seam,
ground is ground: an ordinary collision with the ordinary damage.

| Rule | Value |
|---|---|
| Touchdown speed, relative to the Body | under 40 px/s |
| Nose from straight up | within 0.61 rad (~35°) |
| Reach | the seam's reach angle x 1.15 |
| Hard landing | 40 px/s or more, moving into the ground: damage and a bounce |
| Bounce | 60% of the impact thrown back out, sideways drift halved |

Fast but not moving into the ground, or nose too far over, simply does not land. Each
bounce keeps only a share of the impact, so a ship left to fall back settles into a
touchdown rather than bouncing forever.

**Landed**, the ship settles onto the surface over 0.35s, then locks to the Body and rides
its orbit. Engines are off and the camera zooms to 1.5. `action` harvests the seam
(`docs/SWEEP.md`).

**Liftoff** is thrust. Nothing is thrown and nothing is charged: the ship is released
where it stands at the Body's velocity and climbs out on its own engines. Ground rules are
held off for 0.9s (`FlyingState.LIFTOFF_GRACE`) so it is not judged as landing again on the
way up. Let go early and it settles back down. `playtests/landing.play`,
`test/TouchdownTest.gd`.

A ship carrying Freight cannot touch down.

## 9. Losing the Ship

The ship is lost two ways. Either way the game counts it and brings the next clone up
with nothing to confirm.

**Destroyed.** Hull at 0 -> `Ship.explode()` -> `DestroyedState`. The hull is hidden and
pinned at the point of impact so the camera stays on a 7s `ShipExplosion` (flash, fireball,
debris carrying the ship's momentum, cook-offs). **70% of the hold** (`GemData.WRECK_SHARE`)
spills out as wreck gems that never expire, survive the relaunch and are saved; the rest is
gone. `Main` waits 3.2s for the blast to play. `playtests/wreck.play`.

**Consumed.** Reaching `VoidZone.DEEP_RADIUS` (360,000 px) emits `VoidZone.consumed`
(`docs/WORLD.md`). `Ship.surrender_to_void()` first puts any clamped load back 1 km inside
the edge, then `ConsumedState` hides the hull: no blast, no wreck, nothing left. `Main`
holds 2.4s of silence.

**Then** (`Main.show_game_over`): `GameState.death_count` + 1, the radio is silenced, and
`Session.relaunch()` runs. Once the clone is up, UNIT-7 radios what happened
(`ship_destroyed` / `void_consumed`) - dropped unless the guide is awake.

| Kept | Lost |
|---|---|
| Fitted Components (the cloning bay prints the ship's spec) | The hold (`GameState.clear_cargo`) |
| Stores | Where the ship was, and its momentum |
| Every Record, powered Gate and seated Section | |
| Wreck gems, where the ship blew up | |
| A clamped load, let go where the ship was lost | |
| Fuel (topped up to half, never drained) | |

The relaunched hull is whole and the tank is topped to the free half if SR-7's core runs.
Nothing about a relaunch costs Stores. It comes up at home: the saved dock, or adrift
beside SR-7 (without the wake debris) while its dock arm is still in. A clone lost
mid-diagnostic comes back locked where it left off (`BootLog`).

The game barely acknowledges death, and that is the point: the casualness of coming back
is itself the clue. Nobody mentions that you just died because the system is built to make
replacement seamless.

There is no way to abandon the ship. Hulls in group `derelicts` are deep-space wrecks
(`docs/ENCOUNTERS.md`) or abandoned hulls carried in saves from before abandoning was
removed.

## 10. Sessions and Saves

`scripts/Session.gd` is the one pipeline behind every way a clone comes up - `new_game()`,
`resume()` and `relaunch()` - always in this order:

    reset -> cover -> unpause, a frame -> world restored -> ship placed -> uncover
      -> live (Main: PLAYING) -> EventBus.ship_respawned -> save -> wake from black

The world is restored before the ship is placed (a resumed save has to put the orbits
back before any dock on them can be found), and the save comes last, so no save ever holds
a clone the game has not announced. `test/SessionTest.gd`.

| Launch | Ship placed | Cover |
|---|---|---|
| New game | adrift beside SR-7, tumbling at 0.32 rad/s until the stick is touched (`ShipSpawner.spawn_adrift`) | the dark |
| Resume | at the saved dock; in flight where saved if Freight was clamped | boot terminal if SR-7 is powered, else the dark |
| Relaunch | home (§9) | boot terminal if SR-7 is powered, else the dark |

Waking holds the dark 0.8s and fades in over 1.8s (`Main._wake_from_black`; the playtest
driver skips it unless `force_wake_sequence`, `playtests/intro.play`). A new game also
resets every orbit to the scene's start (`playtests/new_game.play`).

**Saves** (`scripts/Save.gd`, `user://save.cfg`): Stores, death count, fuel, hull, the
hold, the dock the ship sits at, its position and velocity, wreck gems, derelicts,
Freight, planet angles, spent seams, radio flags, the Cradle, the encounter field and the
`Progress` ledger. A full save is written on docking at a port (§7), when a Gate's Module comes online, after a
Gate transit, and
at the end of every Session launch. There is no save in open flight; Records, the Cradle,
spent seams and radio flags are written into the existing save the moment they change.
On load, fuel is restored quietly (no `changed`, so the radio does not take a loaded low
tank for a fresh warning) and hull and fuel are clamped to the fixed limits.

## Known gaps

- `PlanetLandedState.gd` and `Touchdown.gd` docstrings say the climb out "burns thruster
  fuel" and that running dry "strands the ship"; the Aux is free and nothing strands.
  The `playtests/landing.play` header says the same.
- `Main.gd`'s `_on_void_consumed` docstring says "Thirty seconds past the last orbit";
  `VoidZone` has no clock - depth alone decides.
- The dev panel's STRAND SHIP row (`ui/DevPanel.gd`) says emptying the tank "puts the
  abandon-ship call on the radio"; that call and abandoning no longer exist.
- `Ship.hand_over()` (give a clamped load to an abandoned hull) is called only from
  `test/ShipVerbsTest.gd`; nothing in the game abandons a hull any more.
  `DerelictShip.gd`'s class docstring still says "A ship abandoned after running out of
  fuel."
- `Ship.landing_lock_distance` is declared and never read.
- TERRA-0's surface pull is ~99% of Aux thrust (§5): hovering to land there on Aux alone
  is all but impossible, so the "heaviest landable Body" ceiling in ADR 0004 now needs the
  Burn.
