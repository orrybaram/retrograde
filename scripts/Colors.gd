extends Node
## Global color palette for consistent theming across the project.
## Access colors as Colors.PRIMARY, Colors.UI_BACKGROUND, etc.

# =============================================================================
# BASE COLOR DEFINITIONS
# =============================================================================
const AMBER = Color(1.0, 0.75, 0.0, 1.0)
const AMBER_FADED = Color(1.0, 0.75, 0.0, 0.4)
const AMBER_MEDIUM = Color(1.0, 0.75, 0.0, 0.3)
const AMBER_SUBTLE = Color(1.0, 0.75, 0.0, 0.15)

const BLACK = Color(0.0, 0.0, 0.0, 1.0)
const BLACK_90 = Color(0.0, 0.0, 0.0, 0.9)
const BLACK_80 = Color(0.0, 0.0, 0.0, 0.8)

const YELLOW = Color(1.0, 0.9, 0.5, 1.0)
const CYAN = Color(0.5, 0.8, 1.0, 1.0)
const SKY_BLUE = Color(0.5, 0.75, 1.0, 0.5)
const BLUE = Color(0.15, 0.6, 0.9, 1.0)
const WHITE_FADED = Color(1.0, 1.0, 1.0, 0.25)

# =============================================================================
# SEMANTIC COLOR ASSIGNMENTS
# =============================================================================

# --- UI Theme Colors ---
const PRIMARY = AMBER
const PRIMARY_FADED = AMBER_FADED
const PRIMARY_MEDIUM = AMBER_MEDIUM
const PRIMARY_SUBTLE = AMBER_SUBTLE

const UI_BACKGROUND = BLACK_90
const UI_BACKGROUND_LIGHT = BLACK_80
const UI_BACKGROUND_SOLID = BLACK
const UI_BORDER = AMBER

# --- Game Entity Colors ---
const SUN = YELLOW
const MOON_ORBIT = SKY_BLUE
const INDICATOR = CYAN

# --- Defaults ---
const PLANET_DEFAULT = BLUE
const OUTLINE = WHITE_FADED

