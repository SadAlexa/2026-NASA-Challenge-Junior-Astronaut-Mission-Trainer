extends Node
## CardSystem — builds deck, draws, plays, discards, reshuffles.

var cards_data: Array = []


func _ready() -> void:
	_load_cards()


func _load_cards() -> void:
	var file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if file:
		cards_data = JSON.parse_string(file.get_as_text())
		file.close()


func build_deck(seed_str: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_str)
	
	var deck_arr: Array = []
	for card in cards_data:
		for i in range(card.copies):
			deck_arr.append(card.duplicate(true))
	
	# Shuffle using seeded RNG
	for i in range(deck_arr.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = deck_arr[i]
		deck_arr[i] = deck_arr[j]
		deck_arr[j] = tmp
	
	GameState.deck = deck_arr


func draw_cards(count: int) -> void:
	for i in range(count):
		if GameState.deck.is_empty():
			_reshuffle()
		if not GameState.deck.is_empty():
			var card = GameState.deck.pop_back()
			GameState.hand.append(card)
	GameState.emit_changed()


func _reshuffle() -> void:
	GameState.deck = GameState.discard.duplicate(true)
	GameState.discard = []
	# Shuffle
	for i in range(GameState.deck.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var tmp = GameState.deck[i]
		GameState.deck[i] = GameState.deck[j]
		GameState.deck[j] = tmp


func can_play(card: Dictionary) -> Array:
	"""Returns array of lock reasons. Empty = playable."""
	var reasons: Array = []
	
	if GameState.played_this_sel.size() >= Constants.MAX_PLAY_PER_SOL:
		reasons.append("You already played 3 cards this sel!")
		return reasons
	
	if GameState.battery < card.cost_battery:
		reasons.append("Need at least %d Battery points!" % card.cost_battery)
	
	if card.get("requires_no_storm", false) and not GameState.active_storm.is_empty():
		reasons.append("Solar storm active — no EVA outings today!")
	
	if card.get("is_eva", false) and not GameState.active_storm.is_empty():
		reasons.append("Solar storm active — stay inside the base!")
	
	var panels_req = card.get("requires_panels_below", -1)
	if panels_req >= 0 and GameState.panels > panels_req:
		reasons.append("Panels are above %d%% — no repair needed!" % panels_req)
	
	if card.get("once_per_mission", false) and GameState.used_once_cards.has(card.id):
		reasons.append("Already used this mission!")
	
	return reasons


func play_card(card: Dictionary) -> void:
	# Deduct battery
	GameState.battery -= card.cost_battery
	
	# Apply effects
	var effects = card.get("effects", {})
	for key in effects:
		match key:
			"health": GameState.health += effects[key]
			"oxygen": GameState.oxygen += effects[key]
			"food": GameState.food += effects[key]
			"water": GameState.water += effects[key]
			"panels":
				GameState.panels = clampf(GameState.panels + effects[key], Constants.PANEL_MIN, Constants.PANEL_MAX)
			"radiation":
				GameState.eva_count += 1  # radiation handled via eva_count
			"science": GameState.science += effects[key]
	
	# Special flags
	if card.get("cancel_gravity_penalty", false):
		GameState.exercise_played = true
	if card.get("reduce_food_consumption", 0) > 0:
		GameState.extra_sleep_played = true
	if card.get("reduce_base_consumption", 0) > 0:
		GameState.power_saving_played = true
		GameState.reduce_base_consumption = card["reduce_base_consumption"]
		GameState.reduce_o2_production_to = card.get("reduce_o2_production_to", -1.0)
		GameState.reduce_water_production_to = card.get("reduce_water_production_to", -1.0)
	if card.get("fixes_o2_malfunction", false):
		GameState.o2_malfunction = false
		GameState.o2_shield_sels = card.get("o2_shield_sels", 2)
	if card.get("passive_food_per_sol", 0) > 0:
		GameState.greenhouse_expanded = true
		GameState.passive_food_bonus = card["passive_food_per_sol"]
	
	# Track
	GameState.played_this_sel.append(card.id)
	
	# Remove from hand
	GameState.hand.erase(card)
	
	# Once per mission tracking
	if card.get("once_per_mission", false):
		GameState.used_once_cards.append(card.id)
	
	GameState.emit_changed()


func discard_hand() -> void:
	for card in GameState.hand:
		GameState.discard.append(card)
	GameState.hand = []
	GameState.emit_changed()
