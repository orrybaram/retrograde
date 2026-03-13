# Retrograde - Patterns Reference

## State Machine Pattern

```
StateMachine (scripts/StateMachine.gd)
  -> Entity base state (e.g. entities/Ship/states/ShipState.gd)
    -> Concrete states (FlyingState, LandedState, HarvestingState, DestroyedState)
```

Each state implements: `enter()`, `exit()`, `physics_process(delta)`, `integrate_forces(state)`

- **Camera Zoom**: States control zoom. UI should NOT control zoom.
- **UI Blocking**: States check for blocking UI before transitions.
- **Resources**: Each state manages its own particles/sounds, cleans up in `exit()`.

Don't use state machines for: simple booleans, linear sequences (use await), pure data.

## Terminal UI Patterns

Panel: `StyleBoxFlat: draw_center=false, border_width=2, border_color=Amber`

Title format: `/ S P A C E D  T I T L E /` - top-right corner, black background behind text

Action rows:
```
>  ACTION NAME                    COST/VALUE    (selected: full amber #ffbf00)
   ACTION NAME                    COST/VALUE    (unselected)
   ACTION NAME                    COST/VALUE    (unavailable/owned: #5f4700)
```
