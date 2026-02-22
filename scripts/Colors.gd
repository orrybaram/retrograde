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
const AMBER_DIM = Color(1.0, 0.75, 0.0, 0.1)

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
const PRIMARY_DIM = AMBER_DIM

const UI_BACKGROUND = BLACK_90
const UI_BACKGROUND_LIGHT = BLACK_80
const UI_BACKGROUND_SOLID = BLACK
const UI_BORDER = AMBER

# --- Game Entity Colors ---
const SUN = YELLOW
const MOON_ORBIT = AMBER_SUBTLE
const INDICATOR = CYAN

# --- Defaults ---
const PLANET_DEFAULT = BLUE
const OUTLINE = WHITE_FADED

# Fuel bar colors (quarter thresholds)
const FUEL_EMPTY = Color(1.0, 0.3, 0.0, 1.0)  # Red-orange (0%)
const FUEL_EIGHTH = Color(1.0, 0.0, 0.0, 1.0)  # Red (0-12.5%)
const FUEL_QUARTER = Color(1.0, 0.4, 0.0, 1.0)  # Orange-red (12.5-25%)
const FUEL_HALF = Color(1.0, 0.6, 0.0, 1.0)  # Orange (25-50%)
const FUEL_THREE_QUARTERS = Color(1.0, 0.7, 0.0, 1.0)  # Amber-orange (50-75%)
const FUEL_FULL = Color(1.0, 0.75, 0.0, 1.0)  # Amber (75-100%)

# Cargo bar colors (fill level thresholds)
const CARGO_EMPTY = Color(0.3, 0.8, 0.4, 1.0)  # Green (0-50%)
const CARGO_HALF = Color(0.8, 0.8, 0.2, 1.0)  # Yellow (50-75%)
const CARGO_THREE_QUARTERS = Color(1.0, 0.6, 0.0, 1.0)  # Orange (75-90%)
const CARGO_FULL = Color(1.0, 0.3, 0.0, 1.0)  # Red-orange (90-100%)
