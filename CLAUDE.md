# Retrograde - Development Guidelines

## Game Overview

Retrograde is a 2D space exploration/trading game built in Godot 4.6. The player pilots a ship through a solar system, harvesting resources from orbital rings around planets and trading at space stations.

## Visual Aesthetic

### Core Theme: Retro Terminal / CRT Monitor

The game evokes the look of classic computer terminals and early space games. Think amber phosphor monitors, ASCII art, and minimalist vector graphics.

### Color Palette

**IMPORTANT: The amber color scheme is fundamental to the game's identity and must be preserved.**

Primary colors are defined in `scripts/Colors.gd`:

| Color | Hex | RGB | Usage |
|-------|-----|-----|-------|
| **AMBER** | `#FFBF00` | `(1.0, 0.75, 0.0)` | Primary UI color, text, borders |
| AMBER_FADED | `#FFBF0066` | `(1.0, 0.75, 0.0, 0.4)` | Secondary elements |
| AMBER_MEDIUM | `#FFBF004D` | `(1.0, 0.75, 0.0, 0.3)` | Backgrounds, overlays |
| AMBER_SUBTLE | `#FFBF0026` | `(1.0, 0.75, 0.0, 0.15)` | Subtle accents |
| BLACK | `#000000` | `(0.0, 0.0, 0.0)` | Backgrounds |

Status colors (for fuel, hull, cargo bars):
- Full/healthy: Amber `#FFBF00`
- Warning: Orange `#FF9900` to `#FF6600`
- Critical: Red-orange `#FF4D00`
- Cargo uses green-to-red gradient for fill level

### Typography

- **Font**: Andale Mono (monospace)
- **Style**: All text should feel like terminal output
- **Sizes**: Generally small (8-12px for labels, 24px for buttons)

### UI Design Principles

1. **Black backgrounds** - UI panels use solid black or 80-90% opacity black
2. **Amber borders and text** - Consistent use of the primary amber color
3. **Minimal decoration** - Clean lines, no gradients or shadows (except subtle text shadows)
4. **Terminal-style feedback** - Loading screens show boot sequences with progress percentages
5. **Monospace alignment** - Text aligned in columns where appropriate

### Loading Screen Style

The loading screen simulates a computer boot sequence:
```
Initializing navigation systems...................[15%]
Loading stellar database.........................[30%]
Calibrating sensors..............................[45%]
```
- Messages are left-padded with dots
- Progress shown in green `[XX%]` format
- Amber text for messages, green for percentages

### HUD Elements

- Progress bars: Black background, amber fill, amber text centered
- Labels: Amber text on transparent background
- Minimap: Circular radar style with concentric rings

### Game Entities

- **Ship**: Cyan/blue indicator on minimap
- **Planets**: Various colors but outlined minimally
- **Resources**: Green blobs on minimap, scrap metal aesthetic in game
- **Space stations**: Diamond markers

## Code Conventions

### Color Usage

Always use the `Colors` autoload for consistency:
```gdscript
# Good
label.modulate = Colors.PRIMARY
bar.color = Colors.AMBER

# Avoid hardcoding
label.modulate = Color(1.0, 0.75, 0.0)  # Use Colors.AMBER instead
```

### UI Structure

- UI scenes use `Control` nodes with anchors for responsive layout
- Custom widgets (like `ProgressBarWidget`) encapsulate reusable UI
- HUD elements are in a `CanvasLayer` for proper layering

## Architecture Patterns

### State Machines

**IMPORTANT: Use state machines whenever an entity has multiple distinct behavioral modes.**

State machines are the preferred pattern for managing complex entity behavior. They provide:
- Clear separation of concerns between different modes
- Easier debugging and maintenance
- Predictable state transitions
- Clean handling of input and physics in each mode

#### When to Use State Machines

Use state machines for entities that have:
- Multiple behavioral modes (flying, landed, harvesting, destroyed)
- Different input handling in different situations
- Mode-specific physics or rendering logic
- State transitions that need to be controlled and validated

#### State Machine Structure

The codebase uses a reusable `StateMachine` component with individual `State` subclasses:

```gdscript
# Generic state machine (scripts/StateMachine.gd)
StateMachine
├── manages state transitions
├── delegates physics_process/integrate_forces to current state
└── validates state changes

# Entity-specific base state (e.g., entities/Ship/states/ShipState.gd)
ShipState extends State
├── provides ship reference
└── shared helper methods

# Concrete states (e.g., entities/Ship/states/)
FlyingState extends ShipState
LandedState extends ShipState
HarvestingState extends ShipState
DestroyedState extends ShipState
```

#### State Implementation Example

Each state should implement:

```gdscript
extends ShipState
class_name FlyingState

func enter() -> void:
    super.enter()
    # Initialize state (zoom camera, play animations, etc.)
    if ship.camera:
        ship.camera.zoom_camera_out()

func exit() -> void:
    super.exit()
    # Clean up state (stop particles, reset variables, etc.)

func physics_process(delta: float) -> void:
    # Handle per-frame logic (input sampling, particle updates, etc.)
    ship.want_thrust = Input.is_action_pressed("thrust")

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    # Handle physics (apply forces, set velocities, etc.)
    if ship.want_thrust:
        state.apply_central_force(force)
```

#### State Ownership Guidelines

**Camera Zoom**: States control camera zoom based on their context
- `LandedState.enter()` zooms in when docking
- `LandedState.exit()` zooms out when undocking
- UI elements (dialogues, menus) should NOT control zoom if state manages it

**UI Blocking**: States should check for blocking UI before allowing transitions
- Check if dialogues/menus are visible before allowing state changes
- Example: `LandedState` checks if SpacePortDialogue or StoreUI is open before allowing undock

**Resource Management**: Each state manages its own resources
- Particles, sounds, visual effects owned by a state
- Clean up in `exit()` to prevent leaks

#### Best Practices

1. **Single Responsibility**: Each state handles one behavioral mode
2. **Clean Transitions**: Use `enter()` and `exit()` hooks for state setup/teardown
3. **Minimal State Data**: Store only what's needed for the current state
4. **Validate Transitions**: Check conditions before changing states
5. **Avoid State Coupling**: States shouldn't directly reference each other
6. **Use Helper Methods**: Put shared logic in the base state class (e.g., `ShipState`)

#### Example: Ship State Machine

The Ship uses a state machine to manage its behavioral modes:

```
FlyingState (default)
├── Normal flight controls
├── Collision damage
├── Can transition to: LandedState, HarvestingState, DestroyedState
└── Camera zoomed out

LandedState
├── Docked to a space station
├── No flight controls (except undocking)
├── Can transition to: FlyingState
└── Camera zoomed in

HarvestingState
├── Locked to resource ring
├── Controls disabled (minigame active)
├── Can transition to: FlyingState
└── Camera focused on minigame

DestroyedState
├── Ship exploded
├── All controls disabled
├── Terminal state
└── Explosion effects
```

#### When NOT to Use State Machines

Avoid state machines for:
- Simple boolean flags (use variables: `is_boosting`, `is_damaged`)
- Linear sequences (use coroutines/await)
- Pure data containers (use resources or dictionaries)

## File Structure

```
ui/
├── HUD.gd/.tscn          # Main gameplay HUD
├── StartMenu.gd/.tscn    # Title screen with ASCII art
├── LoadingScreen.gd/.tscn # Boot sequence loading
├── ProgressBarWidget.gd/.tscn # Reusable progress bar
├── GameOverMenu.gd/.tscn
├── minimap/              # Radar-style minimap
├── indicators/           # Off-screen target indicators
├── store/                # Trading interface
└── inventory/            # Inventory management
```

## Terminal UI Patterns

### Panel Structure
Dialogue panels use a bordered style with empty center:
```
StyleBoxFlat:
  draw_center = false
  border_width = 2
  border_color = Color(1, 0.75, 0, 1)  # Amber
```

### Panel Titles
Titles are positioned in the top-right corner, overlapping the border:
- Format: `/ S P A C E D  T I T L E /`
- Black background behind text
- Amber text color

### Section Headers
Category headers use spaced letters:
- `S T A T U S`
- `A C T I O N S`
- `U P G R A D E S`

### Action Rows
Actions use a two-column HBoxContainer layout:
```
>  ACTION NAME                    COST/VALUE
   ACTION NAME                    COST/VALUE
```

- Left side: RichTextLabel with selection indicator (`>`) + action name
- Right side: RichTextLabel with right-aligned cost
- Selected item shows `>` prefix in bright amber
- Unselected items have two-space indent
- Dimmed amber `#5f4700` for unavailable/owned items

### Keyboard Navigation
All terminal UIs use arrow key navigation:
- **UP/DOWN** arrows to move selection between items
- **ENTER/SPACE** to confirm/activate selection
- **ESC** to close/go back
- Selection automatically skips disabled items

### Color States
- **Selected & Enabled**: Full amber `#ffbf00` with `>` prefix
- **Unselected & Enabled**: Full amber `#ffbf00`
- **Unavailable/Owned**: Dark amber `#5f4700`
- **Cost/Value**: Medium amber (right-aligned)

## Key Reminders

1. **Never change the amber color scheme** - It defines the game's visual identity
2. **Keep text monospace** - Preserves the terminal aesthetic
3. **Black backgrounds are intentional** - Creates contrast and CRT feel
4. **Minimalism over decoration** - Less is more for this aesthetic
5. **Arrow key navigation** - All terminal UIs use UP/DOWN arrows + ENTER to navigate
