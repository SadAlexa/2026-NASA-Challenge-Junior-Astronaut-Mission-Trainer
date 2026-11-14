extends Node
## NightPhase — automatic production/consumption math for the Night phase.


func run_night() -> Dictionary:
	"""Runs the night phase and returns a dict of deltas for the report."""
	var deltas: Dictionary = {
		"panels": 0.0,
		"battery": 0.0,
		"oxygen": 0.0,
		"food": 0.0,
		"water": 0.0,
		"health": 0.0,
	}
	
	# --- Panel decay ---
	var panel_decay = Constants.PANEL_DECAY_PER_SOL
	GameState.panels = clampf(GameState.panels + panel_decay, Constants.PANEL_MIN, Constants.PANEL_MAX)
	deltas["panels"] = panel_decay
	
	# --- Energy: generation vs consumption ---
	var generation = round(Constants.PANEL_GENERATION_FACTOR * (GameState.panels / 100.0))
	var base_consumption = Constants.BASE_CONSUMPTION - GameState.reduce_base_consumption
	var net = generation - base_consumption
	GameState.battery = clampf(GameState.battery + net, 0.0, 100.0)
	deltas["battery"] = net
	
	# Blackout check
	var blackout = GameState.battery <= 0.0 and net < 0
	
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
	
	var o2_cons = Constants.O2_CONSUMPTION
	if GameState.exercise_played:
		o2_cons += 6.0  # extra O2 from exercise already applied in card, this is baseline only
	
	var o2_delta = o2_prod - o2_cons
	GameState.oxygen = clampf(GameState.oxygen + o2_delta, 0.0, 100.0)
	deltas["oxygen"] = o2_delta
	
	# --- Food ---
	var food_cons = Constants.FOOD_CONSUMPTION
	if GameState.extra_sleep_played:
		food_cons -= 2.0
	var food_prod = 0.0
	if GameState.greenhouse_expanded:
		food_prod = float(GameState.passive_food_bonus)
	
	var food_delta = food_prod - food_cons
	GameState.food = clampf(GameState.food + food_delta, 0.0, 100.0)
	deltas["food"] = food_delta
	
	# --- Water ---
	var water_prod: float
	if blackout:
		water_prod = 0.0
	elif GameState.reduce_water_production_to >= 0:
		water_prod = GameState.reduce_water_production_to
	else:
		water_prod = Constants.WATER_PRODUCTION
	
	var water_delta = water_prod - Constants.WATER_CONSUMPTION
	GameState.water = clampf(GameState.water + water_delta, 0.0, 100.0)
	deltas["water"] = water_delta
	
	# --- Health ---
	var health_delta: float = 0.0
	
	# Radiation damage
	health_delta -= float(GameState.get_health_damage_from_radiation())
	
	# Gravity penalty (if no exercise)
	if not GameState.exercise_played:
		health_delta += Constants.GRAVITY_PENALTY
	
	# Stability bonus
	if GameState.oxygen > 25 and GameState.food > 25 and GameState.water > 25:
		health_delta += Constants.STABILITY_BONUS
	
	# Vital crisis penalty
	var crisis_count = 0
	if GameState.oxygen <= 0: crisis_count += 1
	if GameState.food <= 0: crisis_count += 1
	if GameState.water <= 0: crisis_count += 1
	health_delta += Constants.CRISIS_PENALTY_PER_RESOURCE * crisis_count
	
	GameState.health = clampf(GameState.health + health_delta, 0.0, 100.0)
	deltas["health"] = health_delta
	
	# --- Store deltas ---
	GameState.night_deltas = deltas
	
	# --- Record history ---
	GameState.history_log.append({
		"sel": GameState.sel,
		"health": GameState.health,
		"oxygen": GameState.oxygen,
		"food": GameState.food,
		"water": GameState.water,
		"battery": GameState.battery,
		"panels": GameState.panels,
		"radiation": GameState.get_effective_radiation(),
		"storm": not GameState.active_storm.is_empty(),
	})
	
	GameState.emit_changed()
	return deltas
