extends Node
## Headless test runner for the game rules and the embedded NASA archive.
##
## Run with:
##     godot --headless --path game res://tests/test_runner.tscn
##
## Exits with code 1 if any test fails, so it can be used in CI.

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("== Mission Selene tests ==")

	_test_constants()
	_test_night_baseline()
	_test_exercise_oxygen()
	_test_night_clamps()
	_test_radiation_units()
	_test_o2_malfunction()
	_test_science_downlink()
	_test_storm_shelter()
	_test_deck_determinism()
	_test_played_cards_go_to_discard()
	_test_crisis_determinism()
	_test_donki_archive()
	_test_full_mission_smoke()

	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- helpers ---------------------------------------------------------------

func _ok(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label, ("  -> " + detail) if detail != "" else "")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_ok(actual == expected, label, "got %s, expected %s" % [str(actual), str(expected)])


func _near(actual: float, expected: float, label: String, epsilon: float = 0.001) -> void:
	_ok(absf(actual - expected) <= epsilon, label, "got %f, expected %f" % [actual, expected])


func _fresh_state(seed_text: String = "TEST") -> void:
	GameState.reset()
	GameState.mission_seed = seed_text


func _make_event_system(seed_text: String) -> Node:
	var system: Node = preload("res://game/event_system.gd").new()
	add_child(system)
	system.set_seed(seed_text)
	return system


func _make_card_system(seed_text: String) -> Node:
	var system: Node = preload("res://game/card_system.gd").new()
	add_child(system)
	system.build_deck(seed_text)
	return system


# --- tests -----------------------------------------------------------------

func _test_constants() -> void:
	_eq(Constants.TOTAL_SOLS, 10, "mission length is 10 sels")
	_eq(int(Constants.RADIATION_BASE), 20, "radiation base is 20 game units")
	_near(Constants.RADIATION_GAME_TO_MSV_DAY, 0.07, "1 game unit = 0.07 mSv/day")


func _test_night_baseline() -> void:
	_fresh_state()
	GameState.panels = 75.0
	GameState.battery = 50.0
	var night: Node = preload("res://game/night_phase.gd").new()
	var deltas: Dictionary = night.run_night()
	night.free()

	_near(GameState.panels, 67.0, "panels decay by 8 per sel")
	# round(30 * 0.67) = 20 generation, 20 consumption: battery is stable.
	_near(GameState.battery, 50.0, "75% panels balance base consumption")
	_near(GameState.oxygen, 72.0, "oxygen: +10 production -8 consumption")
	_near(GameState.food, 36.0, "food: -6 consumption")
	_near(GameState.water, 66.0, "water: +6 production -5 consumption")
	# Radiation 20 -> 1 damage, gravity -1, stability +3.
	_near(GameState.health, 91.0, "health: radiation + gravity + stability")
	_ok(not bool(deltas.get("blackout", true)), "no blackout with charged battery")


func _test_exercise_oxygen() -> void:
	_fresh_state()
	var card: Dictionary = {
		"id": "exercise_test",
		"name": "Gym Exercise",
		"cost_battery": 0,
		"effects": {"oxygen": -6},
		"cancel_gravity_penalty": true,
	}
	var before := GameState.oxygen
	var cards: Node = preload("res://game/card_system.gd").new()
	add_child(cards)
	cards.play_card(card)
	_near(GameState.oxygen, before - 6.0, "exercise card costs 6 O2")

	GameState.panels = 75.0
	GameState.battery = 50.0
	var night: Node = preload("res://game/night_phase.gd").new()
	night.run_night()
	night.free()
	cards.queue_free()
	# Night adds +2 (10 production - 8 consumption), not -8.
	_near(GameState.oxygen, before - 4.0, "exercise totals -14 O2, not -20")
	_ok(GameState.exercise_played, "exercise cancels the gravity penalty")


func _test_night_clamps() -> void:
	_fresh_state()
	GameState.panels = 10.0
	GameState.battery = 0.0
	GameState.oxygen = 0.0
	GameState.food = 0.0
	GameState.water = 0.0
	var night: Node = preload("res://game/night_phase.gd").new()
	night.run_night()
	night.free()
	_ok(GameState.oxygen >= 0.0 and GameState.food >= 0.0 and GameState.water >= 0.0,
		"resources never go below zero")
	_ok(GameState.health < 90.0, "vital crises damage health")


func _test_radiation_units() -> void:
	_fresh_state()
	GameState.radiation_mSv_day = Constants.LUNAR_SURFACE_MSV_DAY
	_near(GameState.get_radiation_mSv_day(), 1.4, "base 20 units = 1.4 mSv/day")
	_eq(GameState.get_health_damage_from_radiation(), 1, "base radiation costs 1 health")
	GameState.eva_count = 2
	_near(GameState.get_effective_radiation(), 50.0, "two EVAs add +30 units")
	_eq(GameState.get_health_damage_from_radiation(), 2, "50 units cost 2 health")


func _test_o2_malfunction() -> void:
	_fresh_state()
	GameState.panels = 75.0
	GameState.battery = 50.0
	GameState.o2_malfunction = true
	var night: Node = preload("res://game/night_phase.gd").new()
	var deltas: Dictionary = night.run_night()
	_near(GameState.oxygen, 62.0, "clogged O2 filter stops production for one sel")
	_ok(bool(deltas.get("o2_malfunction", false)), "report flags the clogged filter")
	night.free()

	_fresh_state()
	GameState.panels = 75.0
	GameState.battery = 50.0
	GameState.o2_malfunction = true
	GameState.o2_shield_sels = 1
	night = preload("res://game/night_phase.gd").new()
	deltas = night.run_night()
	_near(GameState.oxygen, 72.0, "preventive Check O2 protects against the failure")
	_ok(not bool(deltas.get("o2_malfunction", false)), "protected failure is not reported")
	night.free()


func _test_science_downlink() -> void:
	_fresh_state()
	GameState.pending_science = 5
	GameState.pending_science_age = 3
	_eq(GameState.science, 0, "pending science is not scored before downlink")
	var banked: int = GameState.bank_pending_science()
	_eq(banked, 5, "downlink banks the pending points")
	_eq(GameState.science, 5, "science total increases after downlink")
	_eq(GameState.pending_science, 0, "pending queue is emptied")


func _test_storm_shelter() -> void:
	_fresh_state()
	GameState.active_storm = {
		"class": "X",
		"radiation_bonus": Constants.STORM_X_RADIATION,
		"sels_left": 2,
	}
	_near(GameState.get_effective_radiation(), 80.0, "X storm adds +60 radiation")
	_eq(GameState.get_health_damage_from_radiation(), 4, "X storm costs 4 health")

	GameState.sheltered_this_sel = true
	_near(GameState.get_effective_radiation(), 50.0, "shelter halves the storm bonus")
	_eq(GameState.get_health_damage_from_radiation(), 2, "shelter halves storm health damage")


func _test_deck_determinism() -> void:
	_fresh_state()
	var a: Node = _make_card_system("SEED-A")
	var order_a: Array = GameState.deck.map(func(c): return str(c.get("id", "")))

	_fresh_state()
	var b: Node = _make_card_system("SEED-A")
	var order_b: Array = GameState.deck.map(func(c): return str(c.get("id", "")))

	_fresh_state()
	var c: Node = _make_card_system("SEED-B")
	var order_c: Array = GameState.deck.map(func(card): return str(card.get("id", "")))

	_eq(order_a, order_b, "same mission seed builds the same deck order")
	_ok(order_a != order_c, "different seeds build a different deck order")
	_ok(order_a.size() > 0, "deck is not empty")
	for node in [a, b, c]:
		node.free()


func _test_played_cards_go_to_discard() -> void:
	_fresh_state()
	var system: Node = _make_card_system("DISCARD")
	_eq(GameState.discard.size(), 0, "discard starts empty")

	var card: Dictionary = GameState.deck.pop_back()
	var hand_size_before: int = GameState.hand.size()
	GameState.hand.append(card)
	system.play_card(card)

	_eq(GameState.hand.size(), hand_size_before, "played card leaves the hand")
	_ok(GameState.discard.has(card), "played card goes to the discard pile")

	var still_in_deck := false
	for entry in GameState.deck:
		if is_same(entry, card):
			still_in_deck = true
			break
	_ok(not still_in_deck, "played card is not duplicated in the deck")
	system.free()


func _test_crisis_determinism() -> void:
	_fresh_state()
	GameState.sel = 5
	var first: Node = _make_event_system("CRISIS-SEED")
	var sequence_a: Array = []
	for i in range(8):
		GameState.active_storm = {}
		GameState.o2_shield_sels = 0
		var ev: Dictionary = first.roll_crisis()
		sequence_a.append("%s:%s:%s" % [
			ev.get("type", "clear"),
			ev.get("class", ""),
			ev.get("event_id", ""),
		])

	_fresh_state()
	GameState.sel = 5
	var second: Node = _make_event_system("CRISIS-SEED")
	var sequence_b: Array = []
	for i in range(8):
		GameState.active_storm = {}
		GameState.o2_shield_sels = 0
		var ev2: Dictionary = second.roll_crisis()
		sequence_b.append("%s:%s:%s" % [
			ev2.get("type", "clear"),
			ev2.get("class", ""),
			ev2.get("event_id", ""),
		])

	_eq(sequence_a, sequence_b, "same mission seed rolls the same crises")
	first.free()
	second.free()


func _test_donki_archive() -> void:
	_fresh_state()
	var system: Node = _make_event_system("ARCHIVE")
	_ok(system.donki_events.size() > 0, "DONKI archive has real events")

	var dataset: Dictionary = system.get_dataset_info()
	_ok(str(dataset.get("retrieved", "")) != "", "DONKI archive records a retrieval date")
	_ok(dataset.has("counts"), "DONKI archive records raw event counts")

	var classes := {}
	var missing_fields: Array[String] = []
	for ev in system.donki_events:
		var cls := str(ev.get("class", ""))
		classes[cls] = true
		for field in ["id", "class", "peak_class", "begin_time"]:
			if str(ev.get(field, "")) == "":
				missing_fields.append("%s.%s" % [ev.get("id", "?"), field])
	_ok(classes.has("X") and classes.has("M") and classes.has("C"),
		"archive contains C, M and X class flares", str(classes.keys()))
	_ok(missing_fields.is_empty(), "every archived event has its identity fields",
		", ".join(missing_fields))
	system.free()


func _test_full_mission_smoke() -> void:
	# Boot the real scene and play a whole mission through the phase machine.
	_fresh_state()
	var game: Node = preload("res://game/game.tscn").instantiate()
	add_child(game)

	_eq(GameState.hand.size(), Constants.HAND_SIZE, "mission starts with a full hand")

	var ended := false
	for i in range(Constants.TOTAL_SOLS + 1):
		if GameState.game_over:
			ended = true
			break
		game._on_end_day()
		if GameState.game_over or game.phase == 1:  # still DAY means the run ended early
			ended = GameState.game_over
			break
		game._on_next_sel()

	_ok(ended, "the mission reaches an end state after %d sels" % Constants.TOTAL_SOLS)
	_ok(game.end_screen.visible, "end screen is shown when the mission ends")
	_eq(GameState.sel, Constants.TOTAL_SOLS, "the mission stops at the last sel")

	var seed_before: String = GameState.mission_seed
	game._on_retry_seed()
	_eq(GameState.mission_seed, seed_before, "retry keeps the same mission seed")
	_eq(GameState.sel, 1, "retry restarts at sel 1")
	_eq(GameState.hand.size(), Constants.HAND_SIZE, "retry deals a new hand")

	game.free()
