extends Node
## Global color palette ("Violet Signal") for consistent theming across the project.
## Access colors as Colors.PRIMARY, Colors.SPACE_BG, etc. Never hardcode color values.
##
## Palette rules:
## - Faded mustard (PRIMARY) is the one UI color. Dim mustard marks unavailable rows.
## - The world is warm: olive-black space, khaki/umber hulls, dusty orange planets.
## - BLUE is navigation (minimap, waypoints, orbits, Mil-Spec loot).
## - PURPLE is reserved for the Titan and Artifacts. Don't use it as decoration.

# =============================================================================
# BASE COLOR DEFINITIONS
# =============================================================================
const MUSTARD = Color(0.910, 0.757, 0.439, 1.0)          # #E8C170
const MUSTARD_FADED = Color(0.910, 0.757, 0.439, 0.4)
const MUSTARD_MEDIUM = Color(0.910, 0.757, 0.439, 0.3)
const MUSTARD_SUBTLE = Color(0.910, 0.757, 0.439, 0.15)
const MUSTARD_DIM = Color(0.910, 0.757, 0.439, 0.1)
const MUSTARD_DARK = Color(0.420, 0.353, 0.204, 1.0)     # #6B5A34
const MUSTARD_PALE = Color(0.722, 0.647, 0.478, 1.0)     # #B8A57A

const SPACE = Color(0.078, 0.075, 0.059, 1.0)            # #14130F olive-black
const SPACE_90 = Color(0.078, 0.075, 0.059, 0.9)
const SPACE_80 = Color(0.078, 0.075, 0.059, 0.8)
const NEBULA_HAZE = Color(0.180, 0.165, 0.125, 1.0)      # #2E2A20
const CREAM = Color(0.949, 0.910, 0.824, 1.0)            # #F2E8D2
const CREAM_SOFT = Color(0.800, 0.765, 0.690, 1.0)       # #CCC3B0

const HULL_DARK = Color(0.184, 0.173, 0.145, 1.0)        # #2F2C25
const HULL_MID = Color(0.290, 0.275, 0.231, 1.0)         # #4A463B
const HULL_LIGHT = Color(0.580, 0.545, 0.451, 1.0)       # #948B73

const ORANGE = Color(0.788, 0.455, 0.227, 1.0)           # #C9743A dusty orange
const SAGE = Color(0.604, 0.682, 0.478, 1.0)             # #9AAE7A
const RUST_RED = Color(0.859, 0.353, 0.235, 1.0)         # #DB5A3C
const BLUE = Color(0.435, 0.722, 0.824, 1.0)             # #6FB8D2
const PURPLE = Color(0.710, 0.541, 0.878, 1.0)           # #B58AE0

# Legacy names kept so older code keeps working. Prefer semantic names below.
const BLACK = SPACE
const BLACK_90 = SPACE_90
const BLACK_80 = SPACE_80
const YELLOW = Color(0.960, 0.867, 0.620, 1.0)           # #F5DD9E warm sun
const CYAN = BLUE
const SKY_BLUE = Color(0.435, 0.722, 0.824, 0.5)
const WHITE_FADED = Color(0.949, 0.910, 0.824, 0.25)

# =============================================================================
# SEMANTIC COLOR ASSIGNMENTS
# =============================================================================

# --- UI Theme Colors ---
const PRIMARY = MUSTARD
const PRIMARY_FADED = MUSTARD_FADED
const PRIMARY_MEDIUM = MUSTARD_MEDIUM
const PRIMARY_SUBTLE = MUSTARD_SUBTLE
const PRIMARY_DIM = MUSTARD_DARK       # Unavailable rows, empty bar segments
const PRIMARY_GHOST = MUSTARD_DIM

const UI_BACKGROUND = SPACE_90
const UI_BACKGROUND_LIGHT = SPACE_80
const UI_BACKGROUND_SOLID = SPACE
const UI_BORDER = MUSTARD

const TEXT = CREAM
const TEXT_SECONDARY = CREAM_SOFT
const TEXT_MUTED = HULL_LIGHT

const SUCCESS = SAGE
const DANGER = RUST_RED
const NAV = BLUE
const TITAN = PURPLE

# --- World Colors ---
const SPACE_BG = SPACE
const NEBULA = NEBULA_HAZE
const STAR = CREAM
const SUN = YELLOW
const MOON_ORBIT = MUSTARD_SUBTLE
const ORBIT = Color(0.435, 0.722, 0.824, 0.3)
const INDICATOR = BLUE
const PLANET_DEFAULT = ORANGE
const OUTLINE = WHITE_FADED
const EXPLOSION = ORANGE
const DEBRIS = HULL_MID

# --- Resource tiers ---
const TIER_SLAG = HULL_LIGHT
const TIER_SCRAP = MUSTARD_PALE
const TIER_SALVAGE = MUSTARD
const TIER_COMPONENT = ORANGE
const TIER_MIL_SPEC = BLUE
const TIER_ARTIFACT = PURPLE

# Fuel bar colors (quarter thresholds)
const FUEL_EMPTY = RUST_RED                                   # (0%)
const FUEL_EIGHTH = RUST_RED                                  # (0-12.5%)
const FUEL_QUARTER = Color(0.824, 0.404, 0.231, 1.0)          # (12.5-25%)
const FUEL_HALF = ORANGE                                      # (25-50%)
const FUEL_THREE_QUARTERS = Color(0.859, 0.608, 0.333, 1.0)   # (50-75%)
const FUEL_FULL = MUSTARD                                     # (75-100%)

# Cargo bar colors (fill level thresholds)
const CARGO_EMPTY = SAGE          # (0-50%)
const CARGO_HALF = MUSTARD        # (50-75%)
const CARGO_THREE_QUARTERS = ORANGE  # (75-90%)
const CARGO_FULL = RUST_RED       # (90-100%)


## Hex string for BBCode, e.g. "[color=#%s]" % Colors.hex(Colors.PRIMARY)
static func hex(c: Color) -> String:
	return c.to_html(false)


## Wraps text in a BBCode color tag.
static func bb(text: String, c: Color) -> String:
	return "[color=#%s]%s[/color]" % [c.to_html(false), text]
