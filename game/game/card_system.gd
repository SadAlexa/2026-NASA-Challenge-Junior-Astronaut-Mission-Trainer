extends Node
## CardSystem — builds the deck, draws, plays, discards and reshuffles.
## The deck is rebuilt deterministically from the mission seed.

const _CONSTANTS := preload("res://data/constants.gd")

var cards_data: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_load_cards()


func _load_cards() -> void:
	var file := FileAccess.open("res://data/cards.json", FileAccess.READ)
	if file == null:
		push_error("CardSystem: cannot open res://data/cards.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY or parsed.is_empty():
		push_error("CardSystem: cards.json is not a non-empty array")
		return
	cards_data = parsed
	print("[CardSystem] Loaded %d unique cards" % cards_data.size())


func build_deck(seed_str: String) -> void:
	_rng.seed = _CONSTANTS.hash_seed(seed_str + ":deck")

	var deck_arr: Array = []
	for card in cards_data:
		for i in range(int(card.get("copies", 1))):
			deck_arr.append(card.duplicate(true))

	_shuffle(deck_arr)
	GameState.deck = deck_arr


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func draw_cards(count: int) -> void:
	for i in range(count):
		if GameState.deck.is_empty():
			_reshuffle()
		if not GameState.deck.is_empty():
			GameState.hand.append(GameState.deck.pop_back())
	GameState.emit_changed()


func _reshuffle() -> void:
	if GameState.discard.is_empty():
		return
	GameState.deck = GameState.discard.duplicate(true)
	GameState.discard = []
	_shuffle(GameState.deck)


func can_play(card: Dictionary) -> Array:
	"""Returns an array of lock reasons. Empty = playable."""
	var reasons: Array = []

	if GameState.played_this_sel.size() >= Constants.MAX_PLAY_PER_SOL:
		reasons.append("You already played 3 cards this sel!")
		return reasons

	if GameState.battery < float(card.get("cost_battery", 0)):
		reasons.append("Need at least %d Battery points!" % int(card.get("cost_battery", 0)))

	if (card.get("requires_no_storm", false) or card.get("is_eva", false)) \
		and not GameState.active_storm.is_empty():
		reasons.append("Solar storm active — no EVA outings today!")

	var panels_req := int(card.get("requires_panels_below", -1))
	if panels_req >= 0 and GameState.panels > panels_req:
		reasons.append("Panels are above %d%% — no repair needed!" % panels_req)

	if card.get("once_per_mission", false) and GameState.used_once_cards.has(str(card.get("id", ""))):
		reasons.append("Already used this mission!")

	return reasons


func play_card(card: Dictionary) -> void:
	# Pay the battery cost.
	GameState.battery = clampf(
		GameState.battery - float(card.get("cost_battery", 0)),
		0.0,
		100.0
	)

	# Apply immediate effects.
	var effects: Dictionary = card.get("effects", {})
	for key in effects:
		var value := float(effects[key])
		match key:
			"health":
				GameState.health = clampf(GameState.health + value, 0.0, 100.0)
			"oxygen":
				GameState.oxygen = clampf(GameState.oxygen + value, 0.0, 100.0)
			"food":
				GameState.food = clampf(GameState.food + value, 0.0, 100.0)
			"water":
				GameState.water = clampf(GameState.water + value, 0.0, 100.0)
			"panels":
				GameState.panels = clampf(
					GameState.panels + value,
					Constants.PANEL_MIN,
					Constants.PANEL_MAX
				)
			"radiation":
				# EVA exposure is modeled through is_eva + EVA_RADIATION_BONUS.
				pass
			"science":
				# Data waits for the next downlink window (communication delay).
				if GameState.pending_science <= 0:
					GameState.pending_science_age = 0
				GameState.pending_science += int(value)

	# Special flags.
	if card.get("cancel_gravity_penalty", false):
		GameState.exercise_played = true
	if int(card.get("reduce_food_consumption", 0)) > 0:
		GameState.extra_sleep_played = true
	if int(card.get("reduce_base_consumption", 0)) > 0:
		GameState.power_saving_played = true
		GameState.reduce_base_consumption = int(card["reduce_base_consumption"])
		GameState.reduce_o2_production_to = float(card.get("reduce_o2_production_to", -1.0))
		GameState.reduce_water_production_to = float(card.get("reduce_water_production_to", -1.0))
	if card.get("fixes_o2_malfunction", false):
		GameState.o2_malfunction = false
		GameState.o2_shield_sels = int(card.get("o2_shield_sels", 2))
	if int(card.get("passive_food_per_sol", 0)) > 0:
		GameState.greenhouse_expanded = true
		GameState.passive_food_bonus = int(card["passive_food_per_sol"])

	if card.get("is_eva", false):
		GameState.eva_count += 1

	# Track / remove from hand.
	GameState.played_this_sel.append(str(card.get("id", "")))
	var idx := GameState.hand.find(card)
	if idx >= 0:
		GameState.hand.remove_at(idx)

	# Played cards cycle back into the deck, except "1x per mission" cards.
	if card.get("once_per_mission", false):
		GameState.used_once_cards.append(str(card.get("id", "")))
	else:
		GameState.discard.append(card)

	GameState.emit_changed()


func discard_hand() -> void:
	for card in GameState.hand:
		GameState.discard.append(card)
	GameState.hand = []
	GameState.emit_changed()
