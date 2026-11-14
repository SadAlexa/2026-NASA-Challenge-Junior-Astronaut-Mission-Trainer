extends Node
## Game — phase state machine orchestrator.

enum Phase { DAWN, DAY, NIGHT, REPORT }

var phase: Phase = Phase.DAWN
var card_system: Node
var event_system: Node
var night_phase: Node
var hud: CanvasLayer
var hand_container: HBoxContainer
var played_cards_container: HBoxContainer
var end_day_button: Button
var lumi_box: Panel
var sel_label: Label
var report_overlay: Control

var _crisis_event: Dictionary = {}


func _ready() -> void:
	card_system = $CardSystem
	event_system = $EventSystem
	night_phase = $NightPhase
	hud = $HUD
	hand_container = $Hand/CardRow
	played_cards_container = $Board/PlayedCards
	end_day_button = $EndDayButton
	lumi_box = $HUD/LumiBox
	sel_label = $HUD/TopBar/SolCounter
	report_overlay = $ReportOverlay
	
	GameState.state_changed.connect(_on_state_changed)
	end_day_button.pressed.connect(_on_end_day)
	$ReportOverlay/NextSelButton.pressed.connect(_on_next_sel)
	
	start_new_game()


func start_new_game() -> void:
	GameState.reset()
	GameState.mission_seed = _generate_seed()
	card_system.build_deck(GameState.mission_seed)
	phase = Phase.DAWN
	sel_label.text = "Sel 1/10"
	end_day_button.disabled = false
	_start_dawn()


func _generate_seed() -> String:
	var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var s = ""
	for i in range(4):
		s += letters[randi() % letters.length()]
	return s


func _start_dawn() -> void:
	phase = Phase.DAWN
	GameState.reset_per_sel()
	
	# Tick storm/shield from previous sel
	event_system.tick_storm()
	event_system.tick_o2_shield()
	
	# Roll crisis
	_crisis_event = event_system.roll_crisis()
	event_system.apply_crisis(_crisis_event)
	
	# Draw cards
	card_system.draw_cards(Constants.HAND_SIZE)
	
	# LUMI announces
	_announce_dawn()
	
	# Transition to DAY
	phase = Phase.DAY
	_refresh_hand()
	GameState.emit_changed()


func _announce_dawn() -> void:
	var lumi = $HUD/LumiBox
	if _crisis_event.is_empty():
		if GameState.sel <= 2:
			lumi.say("Welcome, Commander! Let's learn the ropes. Play up to 3 cards, then end the day!", "happy")
		else:
			lumi.say("Calm space weather today, Commander! Great time to do some maintenance.", "happy")
	elif _crisis_event.get("type") == "solar_storm":
		var cls = _crisis_event["class"]
		match cls:
			"C": lumi.say("The Sun emitted a small solar flare (C-class)! Let's stay inside the base until it passes.", "alert")
			"M": lumi.say("Orange alert! An M-class solar storm is hitting the Moon with charged particles.", "alert")
			"X": lumi.say("Red alert! A coronal mass ejection (CME) following an X-class flare has struck the outpost!", "alert")
		# Link to DONKI
		var ev_id = _crisis_event.get("event_id", "")
		if ev_id != "":
			lumi.add_line("Based on real NASA DONKI data: %s (%s)" % [ev_id, _crisis_event.get("date", "")])
	elif _crisis_event.get("type") == "micrometeoroid":
		lumi.say("There's no air on the Moon to burn up meteors: a tiny space pebble dented our panels!", "alert")
	elif _crisis_event.get("type") == "o2_malfunction":
		lumi.say("An oxygen filter got clogged! Let's play the Check O₂ card to fix it before tonight!", "alert")


func _on_card_pressed(card: Dictionary) -> void:
	if phase != Phase.DAY:
		return
	
	var reasons = card_system.can_play(card)
	if reasons.is_empty():
		card_system.play_card(card)
		_refresh_hand()
		# LUMI feedback
		var lumi = $HUD/LumiBox
		lumi.say(card.get("lumi_text", "Done!"), "happy")
	else:
		var lumi = $HUD/LumiBox
		lumi.say(reasons[0], "curious")


func _on_end_day() -> void:
	if phase != Phase.DAY:
		return
	
	# Discard unplayed cards
	card_system.discard_hand()
	
	# Run night
	phase = Phase.NIGHT
	var deltas = night_phase.run_night()
	
	# Check game over
	if _check_game_over():
		_show_end_screen()
		return
	
	# Show report
	phase = Phase.REPORT
	_show_report(deltas)


func _check_game_over() -> bool:
	# Health at 0 = defeat
	if GameState.health <= 0:
		GameState.game_over = true
		GameState.victory = false
		return true
	
	# End of sel 10
	if GameState.sel >= Constants.TOTAL_SOLS:
		GameState.game_over = true
		# Victory: all vitals > 0
		GameState.victory = GameState.oxygen > 0 and GameState.food > 0 and GameState.water > 0
		return true
	
	return false


func _show_report(deltas: Dictionary) -> void:
	var report = $ReportOverlay
	report.visible = true
	
	# Build delta text
	var lines: Array[String] = []
	lines.append("— Sel %d Report —" % GameState.sel)
	lines.append("")
	
	var panel_d = deltas.get("panels", 0.0)
	if panel_d != 0:
		lines.append("☀️ Panels: %+.0f%%" % panel_d)
	
	var batt_d = deltas.get("battery", 0.0)
	lines.append("🔋 Battery: %+.0f (now %d)" % [batt_d, int(GameState.battery)])
	
	var o2_d = deltas.get("oxygen", 0.0)
	lines.append("🫁 O₂: %+.0f (now %d)" % [o2_d, int(GameState.oxygen)])
	
	var food_d = deltas.get("food", 0.0)
	lines.append("🌱 Food: %+.0f (now %d)" % [food_d, int(GameState.food)])
	
	var water_d = deltas.get("water", 0.0)
	lines.append("💧 Water: %+.0f (now %d)" % [water_d, int(GameState.water)])
	
	var health_d = deltas.get("health", 0.0)
	lines.append("❤️ Health: %+.0f (now %d)" % [health_d, int(GameState.health)])
	
	# Did you know?
	var trivia = _get_trivia()
	lines.append("")
	lines.append("🤖 LUMI: " + trivia)
	
	$ReportOverlay/ReportText.text = "\n".join(lines)
	
	# Update sel counter for next
	if GameState.sel < Constants.TOTAL_SOLS:
		GameState.sel += 1
		sel_label.text = "Sel %d/%d" % [GameState.sel, Constants.TOTAL_SOLS]


func _get_trivia() -> String:
	var trivia_list: Array[String] = [
		"Did you know? The Moon has no atmosphere, so meteors hit the surface at full speed!",
		"Did you know? A 'sel' is actually a Martian word — on the Moon we use it by convention for each 24h shift!",
		"Did you know? Lunar dust (regolith) is electrostatic and sticks to everything, like magnetic sand!",
		"Did you know? The Sun appears 30% larger in the lunar sky than from Earth!",
		"Did you know? Astronauts on the ISS grow vegetables using LED lights — just like our greenhouse!",
		"Did you know? Without gravity, your bones lose about 1-2% density every month in space!",
		"Did you know? The lunar south pole has 'peaks of eternal light' where the Sun never sets!",
	]
	return trivia_list[randi() % trivia_list.size()]


func _on_next_sel() -> void:
	$ReportOverlay.visible = false
	if not GameState.game_over:
		_start_dawn()


func _show_end_screen() -> void:
	var end_screen = $EndScreen
	end_screen.show_end()


func _refresh_hand() -> void:
	# Clear existing card buttons
	for child in hand_container.get_children():
		child.queue_free()
	
	for card in GameState.hand:
		var btn = preload("res://ui/card_button.tscn").instantiate()
		hand_container.add_child(btn)
		btn.setup(card, self)


func _on_state_changed() -> void:
	pass  # HUD handles its own updates via signal
