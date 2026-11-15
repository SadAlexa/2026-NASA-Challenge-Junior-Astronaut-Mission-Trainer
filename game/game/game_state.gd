extends Node
## GameState — autoload singleton holding all game data.
## Mutations go through methods that emit `state_changed`.

signal state_changed

var mission_seed: String = ""
var sel: int = 1
var health: float = Constants.HEALTH_START
var oxygen: float = Constants.OXYGEN_START
var food: float = Constants.FOOD_START
var water: float = Constants.WATER_START
var battery: float = Constants.BATTERY_START
var panels: float = Constants.PANELS_START
var radiation_base: float = Constants.RADIATION_BASE
var science: int = 0

# Flags
var greenhouse_expanded: bool = false
var o2_shield_sels: int = 0
var active_storm: Dictionary = {}  # { "class": "M", "sels_left": 2, "event_id": "" }
var o2_malfunction: bool = false
var strongest_storm: Dictionary = {}

# Storm shelter (chosen during the Day, paid immediately)
var sheltered_this_sel: bool = false

# Science downlink: points wait for a communications window
var pending_science: int = 0
var pending_science_age: int = 0
var science_last_delivery: int = 0

# Per-sel flags (reset each sel)
var exercise_played: bool = false
var extra_sleep_played: bool = false
var power_saving_played: bool = false
var eva_count: int = 0
var passive_food_bonus: int = 0
var reduce_base_consumption: int = 0
var reduce_o2_production_to: float = -1.0
var reduce_water_production_to: float = -1.0

# Card tracking
var deck: Array = []
var hand: Array = []
var discard: Array = []
var played_this_sel: Array = []
var used_once_cards: Array = []  # card ids already used (once_per_mission)

# History
var history_log: Array = []

# Night deltas for report
var night_deltas: Dictionary = {}

# Build-time NASA snapshot (see game/data/nasa_reference.json)
var nasa_reference: Dictionary = {}
var donki_dataset: Dictionary = {}
var apod_data: Dictionary = {}
var radiation_mSv_day: float = Constants.LUNAR_SURFACE_MSV_DAY

# Game over
var game_over: bool = false
var victory: bool = false


func reset() -> void:
	mission_seed = ""
	sel = 1
	health = Constants.HEALTH_START
	oxygen = Constants.OXYGEN_START
	food = Constants.FOOD_START
	water = Constants.WATER_START
	battery = Constants.BATTERY_START
	panels = Constants.PANELS_START
	radiation_base = Constants.RADIATION_BASE
	science = 0
	greenhouse_expanded = false
	o2_shield_sels = 0
	active_storm = {}
	o2_malfunction = false
	strongest_storm = {}
	sheltered_this_sel = false
	pending_science = 0
	pending_science_age = 0
	science_last_delivery = 0
	exercise_played = false
	extra_sleep_played = false
	power_saving_played = false
	eva_count = 0
	passive_food_bonus = 0
	reduce_base_consumption = 0
	reduce_o2_production_to = -1.0
	reduce_water_production_to = -1.0
	deck = []
	hand = []
	discard = []
	played_this_sel = []
	used_once_cards = []
	history_log = []
	night_deltas = {}
	radiation_mSv_day = Constants.LUNAR_SURFACE_MSV_DAY
	game_over = false
	victory = false


func reset_per_sel() -> void:
	exercise_played = false
	extra_sleep_played = false
	power_saving_played = false
	eva_count = 0
	passive_food_bonus = 0
	reduce_base_consumption = 0
	reduce_o2_production_to = -1.0
	reduce_water_production_to = -1.0
	sheltered_this_sel = false
	played_this_sel = []
	night_deltas = {}


func get_effective_radiation() -> float:
	var rad := radiation_base
	if not active_storm.is_empty():
		var bonus := float(active_storm.get("radiation_bonus", 0))
		if sheltered_this_sel:
			bonus *= Constants.SHELTER_RADIATION_REDUCTION
		rad += bonus
	rad += eva_count * Constants.EVA_RADIATION_BONUS
	return rad


func get_health_damage_from_radiation() -> int:
	return int(ceil(get_effective_radiation() / 25.0))


func get_radiation_mSv_day() -> float:
	var per_unit := Constants.RADIATION_GAME_TO_MSV_DAY
	if radiation_mSv_day > 0.0:
		per_unit = radiation_mSv_day / Constants.RADIATION_BASE
	return get_effective_radiation() * per_unit


func bank_pending_science() -> int:
	var amount := pending_science
	science += amount
	pending_science = 0
	pending_science_age = 0
	science_last_delivery = amount
	return amount


func emit_changed() -> void:
	state_changed.emit()
