extends Node
## NightPhase — automatic production/consumption math for the Night phase.
## All formulas mirror MISSION SELENE GDD §6 and are covered by tests/.


func run_night() -> Dictionary:
	"""Runs the night phase and returns a dict of *actual* deltas for the report."""
	var deltas: Dictionary = {
		"panels": 0.0,
		"battery": 0.0,
		"oxygen": 0.0,
		"food": 0.0,
		"water": 0.0,
		"health": 0.0,
		"sheltered": GameState.sheltered_this_sel,
	}

	# --- Panel decay (night dust deposition) ---
	var panels_before := GameState.panels
	GameState.panels = clampf(
		GameState.panels + Constants.PANEL_DECAY_PER_SOL,
		Constants.PANEL_MIN,
		Constants.PANEL_MAX
	)
	deltas["panels"] = GameState.panels - panels_before

	# --- Energy: generation vs consumption ---
	var generation: float = round(Constants.PANEL_GENERATION_FACTOR * (GameState.panels / 100.0))
	var base_consumption: float = Constants.BASE_CONSUMPTION - GameState.reduce_base_consumption
	var net: float = generation - base_consumption
	var battery_before := GameState.battery
	GameState.battery = clampf(GameState.battery + net, 0.0, 100.0)
	deltas["battery"] = GameState.battery - battery_before

	var blackout: bool = GameState.battery <= 0.0 and net < 0.0
	deltas["blackout"] = blackout
	deltas["o2_malfunction"] = GameState.o2_malfunction and GameState.o2_shield_sels <= 0

	# --- Oxygen ---
	var o2_prod: float
	if GameState.o2_malfunction and GameState.o2_shield_sels <= 0:
		o2_prod = 0.0
	elif blackout:
		o2_prod = 5.0
	elif GameState.reduce_o2_production_to > 0:
		o2_prod = GameState.reduce_o2_production_to
	else:
		o2_prod = Constants.O2_PRODUCTION

	# Exercise's extra O2 cost (-6) is applied by the card itself, so the
	# baseline here stays at -8. One Exercise therefore costs 6 + 8 = 14 O2.
	var o2_cons := Constants.O2_CONSUMPTION

	var o2_before := GameState.oxygen
	GameState.oxygen = clampf(GameState.oxygen + (o2_prod - o2_cons), 0.0, 100.0)
	deltas["oxygen"] = GameState.oxygen - o2_before

	# --- Food ---
	var food_cons := Constants.FOOD_CONSUMPTION
	if GameState.extra_sleep_played:
		food_cons -= 2.0
	var food_prod := 0.0
	if GameState.greenhouse_expanded:
		food_prod = float(GameState.passive_food_bonus)

	var food_before := GameState.food
	GameState.food = clampf(GameState.food + (food_prod - food_cons), 0.0, 100.0)
	deltas["food"] = GameState.food - food_before

	# --- Water ---
	var water_prod: float
	if blackout:
		water_prod = 0.0
	elif GameState.reduce_water_production_to >= 0:
		water_prod = GameState.reduce_water_production_to
	else:
		water_prod = Constants.WATER_PRODUCTION

	var water_before := GameState.water
	GameState.water = clampf(GameState.water + (water_prod - Constants.WATER_CONSUMPTION), 0.0, 100.0)
	deltas["water"] = GameState.water - water_before

	# --- Health ---
	var health_delta := 0.0

	# Radiation damage (uses effective radiation, including shelter choice).
	health_delta -= float(GameState.get_health_damage_from_radiation())

	# Low lunar gravity, unless the crew exercised.
	if not GameState.exercise_played:
		health_delta += Constants.GRAVITY_PENALTY

	# Stability bonus when all vital resources are comfortable.
	if GameState.oxygen > 25 and GameState.food > 25 and GameState.water > 25:
		health_delta += Constants.STABILITY_BONUS

	# Vital crisis: each vital resource at 0 costs health.
	var crisis_count := 0
	if GameState.oxygen <= 0.0:
		crisis_count += 1
	if GameState.food <= 0.0:
		crisis_count += 1
	if GameState.water <= 0.0:
		crisis_count += 1
	health_delta += Constants.CRISIS_PENALTY_PER_RESOURCE * crisis_count

	var health_before := GameState.health
	GameState.health = clampf(GameState.health + health_delta, 0.0, 100.0)
	deltas["health"] = GameState.health - health_before

	# --- Store deltas ---
	GameState.night_deltas = deltas

	# --- Record history (with real DONKI identity for the end report) ---
	var storm_info: Dictionary = {}
	if not GameState.active_storm.is_empty():
		storm_info = {
			"class": str(GameState.active_storm.get("class", "")),
			"rbe_scale": str(GameState.active_storm.get("rbe_scale", "R1")),
			"peak": str(GameState.active_storm.get("peak", "")),
			"event_id": str(GameState.active_storm.get("event_id", "")),
			"date": str(GameState.active_storm.get("date", "")),
			"link": str(GameState.active_storm.get("link", "")),
		}

	GameState.history_log.append({
		"sel": GameState.sel,
		"health": GameState.health,
		"oxygen": GameState.oxygen,
		"food": GameState.food,
		"water": GameState.water,
		"battery": GameState.battery,
		"panels": GameState.panels,
		"radiation": GameState.get_effective_radiation(),
		"storm": storm_info,
		"sheltered": GameState.sheltered_this_sel,
	})

	GameState.emit_changed()
	return deltas
