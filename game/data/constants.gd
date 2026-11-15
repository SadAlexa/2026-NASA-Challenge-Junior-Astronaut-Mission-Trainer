extends Node
## Constants — all tuning numbers in one place (autoload).

# Resources
const HEALTH_START := 90.0
const OXYGEN_START := 70.0
const FOOD_START   := 42.0
const WATER_START  := 65.0
const BATTERY_START:= 50.0
const PANELS_START := 75.0
const RADIATION_BASE:= 20.0

# Per-sel flows
const PANEL_DECAY_PER_SOL     := -8.0
const PANEL_MIN               := 10.0
const PANEL_MAX               := 100.0
const BASE_CONSUMPTION        := 20.0
const O2_PRODUCTION           := 10.0
const O2_CONSUMPTION          := 8.0
const FOOD_CONSUMPTION        := 6.0
const WATER_PRODUCTION        := 6.0
const WATER_CONSUMPTION       := 5.0
const GRAVITY_PENALTY         := -1.0
const STABILITY_BONUS         := 3.0
const CRISIS_PENALTY_PER_RESOURCE := -5.0

# Panel generation
const PANEL_GENERATION_FACTOR := 30.0

# Crises (game units, not physical units)
const STORM_C_RADIATION := 15
const STORM_M_RADIATION := 35
const STORM_X_RADIATION := 60
const STORM_DURATION    := 2
const STORM_X_PANEL_DAMAGE := -10.0
const MICROMETEOROID_PANEL_DAMAGE := -30.0

# EVA
const EVA_RADIATION_BONUS := 15

# Storm shelter (real trade-off: power vs. radiation exposure)
const SHELTER_COST := 8.0
const SHELTER_RADIATION_REDUCTION := 0.5

# Communications / science downlink
const DOWNLINK_COST := 4.0
const DOWNLINK_DELAY_SELS := 1

# Real radiation reference (RadLab/OSDR, lunar surface)
# 20 game units are anchored to ~1.4 mSv/day equivalent dose.
const LUNAR_SURFACE_MSV_DAY := 1.4
const RADIATION_GAME_TO_MSV_DAY := 0.07  # 1.4 / 20

# Scoring
const SCORE_WEIGHT_O2   := 0.5
const SCORE_WEIGHT_FOOD := 0.5
const SCORE_WEIGHT_WATER:= 0.5
const SCORE_WEIGHT_BATT := 0.5
const SCORE_WEIGHT_SCIENCE := 10.0

# Medals
const MEDAL_GOLD    := 180
const MEDAL_SILVER  := 130

# Card limits
const HAND_SIZE     := 5
const MAX_PLAY_PER_SOL := 3
const TOTAL_SOLS    := 10

# Crisis roll
const CRISIS_CHANCE := 0.65

# Storm class selection weights (storms are drawn from the real DONKI archive)
const STORM_CLASS_WEIGHTS := { "C": 0.50, "M": 0.35, "X": 0.15 }

# Stable seed hash (FNV-1a) so a mission seed reproduces the same mission.
const SEED_FNV_OFFSET := 2166136261
const SEED_FNV_PRIME := 16777619


static func hash_seed(text: String) -> int:
	var h: int = SEED_FNV_OFFSET
	for i in text.length():
		h = (h ^ text.unicode_at(i)) * SEED_FNV_PRIME
		h &= 0xFFFFFFFF
	return h
