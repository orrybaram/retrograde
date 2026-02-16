# Retrograde - Detailed Patterns Reference

## Color Palette

Primary colors defined in `scripts/Colors.gd`:

| Color | Hex | Usage |
|-------|-----|-------|
| AMBER | `#FFBF00` | Primary UI color, text, borders |
| AMBER_FADED | `#FFBF0066` | Secondary elements |
| AMBER_MEDIUM | `#FFBF004D` | Backgrounds, overlays |
| AMBER_SUBTLE | `#FFBF0026` | Subtle accents |
| BLACK | `#000000` | Backgrounds |

Status bar colors: Full=Amber, Warning=`#FF9900`-`#FF6600`, Critical=`#FF4D00`

## State Machine Pattern

Structure:
```
StateMachine (scripts/StateMachine.gd)
  -> Entity base state (e.g. entities/Ship/states/ShipState.gd)
    -> Concrete states (FlyingState, LandedState, HarvestingState, DestroyedState)
```

Each state implements: `enter()`, `exit()`, `physics_process(delta)`, `integrate_forces(state)`

### State Ownership
- **Camera Zoom**: States control zoom (LandedState zooms in/out). UI should NOT control zoom.
- **UI Blocking**: States check for blocking UI before transitions.
- **Resources**: Each state manages its own particles/sounds, cleans up in `exit()`.

### Ship States
- FlyingState: flight controls, collision damage, camera zoomed out
- LandedState: docked, no flight controls, camera zoomed in
- HarvestingState: locked to resource ring, minigame active
- DestroyedState: terminal state, explosion effects

### When NOT to use state machines
- Simple booleans (`is_boosting`)
- Linear sequences (use await)
- Pure data (use resources/dictionaries)

## Terminal UI Patterns

### Panel Structure
```
StyleBoxFlat: draw_center=false, border_width=2, border_color=Amber
```

### Panel Titles
Format: `/ S P A C E D  T I T L E /` - top-right corner, black background behind text

### Action Rows
```
>  ACTION NAME                    COST/VALUE    (selected, bright amber)
   ACTION NAME                    COST/VALUE    (unselected)
```
- Selected: `>` prefix, full amber `#ffbf00`
- Unavailable/Owned: Dark amber `#5f4700`

### Loading Screen
Boot sequence style:
```
Initializing navigation systems...................[15%]
Loading stellar database.........................[30%]
```
Amber text, green `[XX%]` percentages.

## File Structure
```
ui/          HUD, menus, minimap, store, inventory, indicators
entities/    Ship, planets, stations, resources
scripts/     Core systems (Colors, StateMachine, etc.)
scenes/      Game scenes
minigames/   Harvesting minigames
```
