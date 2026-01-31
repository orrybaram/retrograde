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
