extends Node
## Game — phase state machine orchestrator.

const _CONSTANTS := preload("res://data/constants.gd")

enum Phase { START, GAME, END_SEL, REPORT }

var phase: Phase = Phase.START
var card_system: Node
var event_system: Node
var end_sel_phase: Node
var hud: CanvasLayer
var hand_container: HBoxContainer
var end_sel_button: Button
var shelter_button: Button
var downlink_button: Button
var lumi_box: Panel
var sel_label: Label
var report_overlay: Control
var end_screen: Control
var real_data_panel: Control
var nasa_manager: Node
var real_data_btn: Button

var _crisis_event: Dictionary = {}
var _science_note: String = ""
var _animating_hand := false


func _ready() -> void:
	card_system = $CardSystem
	event_system = $EventSystem
	end_sel_phase = $EndSelPhase
	hud = $HUD
	hand_container = $Hand/CardRow
	end_sel_button = $EndSelButton
	shelter_button = $ShelterButton
	downlink_button = $DownlinkButton
	lumi_box = $HUD/LumiBox
	sel_label = $HUD/Panel/TopBar/SolCounter
	report_overlay = $ReportOverlay
	end_screen = $EndScreen
	real_data_panel = $HUD/RealDataPanel
	real_data_btn = $HUD/Button

	# Build-time NASA snapshot.
	nasa_manager = preload("res://space_weather_manager.gd").new()
	nasa_manager.name = "SpaceWeatherManager"
	nasa_manager.weather_loaded.connect(_on_weather_loaded)
	add_child(nasa_manager)
	real_data_btn.pressed.connect(_on_real_data_pressed)

	GameState.state_changed.connect(_on_state_changed)
	end_sel_button.pressed.connect(_on_end_sel)
	shelter_button.toggled.connect(_on_shelter_toggled)
	downlink_button.pressed.connect(_on_downlink_pressed)
	$ReportOverlay/NextSelButton.pressed.connect(_on_next_sel)
	$EndScreen/VBox/Buttons/NewMissionButton.pressed.connect(_on_new_mission)
	$EndScreen/VBox/Buttons/RetrySeedButton.pressed.connect(_on_retry_seed)

	start_new_game()


func start_new_game(seed_override: String = "") -> void:
	GameState.reset()
	GameState.mission_seed = seed_override if seed_override != "" else _generate_seed()
	card_system.build_deck(GameState.mission_seed)
	event_system.set_seed(GameState.mission_seed)

	report_overlay.visible = false
	end_screen.visible = false
	$HUD.visible = true
	end_sel_button.disabled = false
	_shelter_reset_ui()
	phase = Phase.START
	_start_dawn()


func _generate_seed() -> String:
	var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := ""
	for i in range(4):
		s += letters[rng.randi_range(0, letters.length() - 1)]
	return s


func _start_dawn() -> void:
	phase = Phase.START
	GameState.reset_per_sel()
	_shelter_reset_ui()
	end_sel_button.disabled = false

	# Expire the previous storm, then deliver any waiting science.
	event_system.tick_storm()
	_deliver_science_at_dawn()

	# Roll the crisis for this sel.
	_crisis_event = event_system.roll_crisis()
	event_system.apply_crisis(_crisis_event)
	event_system.tick_o2_shield()

	# Draw the hand.
	card_system.draw_cards(Constants.HAND_SIZE)

	_announce_dawn()
	_update_action_buttons()

	phase = Phase.GAME
	_refresh_hand()
	GameState.emit_changed()


func _deliver_science_at_dawn() -> void:
	_science_note = ""
	if GameState.pending_science <= 0:
		return

	# Data needs one sel to be packaged, then a clear radio window to be sent.
	GameState.pending_science_age += 1
	if not GameState.active_storm.is_empty():
		_science_note = "📡 Radio blackout %s: %d science point(s) are stuck at the outpost." % [
			str(GameState.active_storm.get("rbe_scale", "R1")),
			GameState.pending_science,
		]
	elif GameState.pending_science_age >= Constants.DOWNLINK_DELAY_SELS:
		_science_note = "📡 %d science point(s) are ready to downlink." % GameState.pending_science


func _announce_dawn() -> void:
	if _crisis_event.is_empty():
		if GameState.sel == 1:
			lumi_box.say(
				"Welcome, Commander! Pick up to 3 cards, then press End Sel. Keep LIFE, ENERGY and RAYS in mind!",
				"happy"
			)
		elif GameState.sel == 2:
			lumi_box.say(
				"Tip: solar panels lose efficiency every sel. Clean them before the batteries drain!",
				"curious"
			)
		else:
			lumi_box.visible = false

	match _crisis_event.get("type", ""):
		"solar_storm":
			var cls := str(_crisis_event.get("class", "C"))
			match cls:
				"C":
					lumi_box.say("A small C-class solar flare! Let's stay inside the base until it passes.", "alert")
				"M":
					lumi_box.say("Orange alert! An M-class solar storm is hitting the Moon with charged particles.", "alert")
				_:
					lumi_box.say("Red alert! An X-class flare with a coronal mass ejection (CME) has struck the outpost!", "alert")
			var event_id := str(_crisis_event.get("event_id", ""))
			if event_id != "":
				lumi_box.add_line(
					"Real NASA DONKI event: %s %s (%s)." % [
						str(_crisis_event.get("peak", cls)),
						event_id,
						str(_crisis_event.get("date", "")),
					]
				)
			lumi_box.add_line(
				"Radio blackout %s: science downlinks are blocked until the storm passes."
				% str(_crisis_event.get("rbe_scale", "R1"))
			)
			lumi_box.add_line(
				"Tap 🛡️ Shelter to power the shielded module for %.0f ⚡: the storm radiation bonus is halved soon."
				% Constants.SHELTER_COST
			)
		"micrometeoroid":
			lumi_box.say("There's no air on the Moon to burn up meteors: a tiny space pebble dented our panels!", "alert")
		"o2_malfunction":
			lumi_box.say("An oxygen filter got clogged! Play Check O₂ to fix it.", "alert")

	if _science_note != "":
		lumi_box.visible = true
		lumi_box.add_line(_science_note)


func _on_card_pressed(card: Dictionary, card_node: Node = null) -> void:
	if phase != Phase.GAME or _animating_hand:
		return

	var reasons: Array = card_system.can_play(card)
	if reasons.is_empty():
		card_system.play_card(card)
		_update_action_buttons()
		say_lumi(str(card.get("lumi_text", "Done!")), "happy")
		# Animate the played card out before rebuilding the hand.
		_animating_hand = true
		if card_node != null and card_node.has_method("animate_played"):
			await card_node.animate_played()
		_refresh_hand()
		_animating_hand = false
	else:
		say_lumi(str(reasons[0]), "curious")


func _on_end_sel() -> void:
	if phase != Phase.GAME:
		return

	card_system.discard_hand()

	phase = Phase.END_SEL
	var deltas: Dictionary = end_sel_phase.run_end_sel()
	event_system.end_sel()
	_update_action_buttons()

	if _check_game_over():
		_show_end_screen()
		return

	phase = Phase.REPORT
	_show_report(deltas)


func _check_game_over() -> bool:
	if GameState.health <= 0.0:
		GameState.game_over = true
		GameState.victory = false
		return true

	if GameState.sel >= Constants.TOTAL_SOLS:
		GameState.game_over = true
		GameState.victory = GameState.oxygen > 0.0 \
			and GameState.food > 0.0 \
			and GameState.water > 0.0
		return true

	return false


func _show_report(deltas: Dictionary) -> void:
	report_overlay.visible = true
	end_sel_button.disabled = true
	lumi_box.visible = false

	var lines: Array[String] = []
	lines.append("— Sel %d Report —" % GameState.sel)
	lines.append("")

	var panel_d := float(deltas.get("panels", 0.0))
	if panel_d != 0.0:
		lines.append("☀️ Panels: %+.0f%% (now %d%%)" % [panel_d, int(GameState.panels)])

	lines.append("🔋 Battery: %+.0f (now %d)" % [float(deltas.get("battery", 0.0)), int(GameState.battery)])
	lines.append("🫁 O₂: %+.0f (now %d)" % [float(deltas.get("oxygen", 0.0)), int(GameState.oxygen)])
	lines.append("🌱 Food: %+.0f (now %d)" % [float(deltas.get("food", 0.0)), int(GameState.food)])
	lines.append("💧 Water: %+.0f (now %d)" % [float(deltas.get("water", 0.0)), int(GameState.water)])
	lines.append("❤️ Health: %+.0f (now %d)" % [float(deltas.get("health", 0.0)), int(GameState.health)])

	if bool(deltas.get("blackout", false)):
		lines.append("")
		lines.append("⚡ BLACKOUT! The outpost ran out of power.")
	if bool(deltas.get("o2_malfunction", false)):
		lines.append("")
		lines.append("🫁 The oxygen filter stayed clogged: production was 0. Play Check O₂ next time!")
	if bool(deltas.get("sheltered", false)):
		lines.append("🛡️ Storm shelter powered: storm radiation halved (-%.0f ⚡)." % Constants.SHELTER_COST)

	if not GameState.active_storm.is_empty():
		lines.append("")
		lines.append("☀️ Real DONKI event: %s %s (%s)" % [
			str(GameState.active_storm.get("peak", GameState.active_storm.get("class", ""))),
			str(GameState.active_storm.get("event_id", "")),
			str(GameState.active_storm.get("date", "")),
		])
		lines.append("📻 Radio blackout %s: HF communications are degraded while the storm lasts." % str(
			GameState.active_storm.get("rbe_scale", "R1")
		))

	if _science_note != "":
		lines.append(_science_note)
	if GameState.pending_science > 0:
		lines.append("📡 Waiting to downlink: %d science point(s)." % GameState.pending_science)

	lines.append("")
	lines.append("🤖 LUMI: " + _get_trivia())

	$ReportOverlay/ReportText.text = "\n".join(lines)


func _get_trivia() -> String:
	var trivia_list: Array[String] = [
		"Did you know? The Moon has no atmosphere, so meteors hit the surface at full speed!",
		"Did you know? Light takes about 1.3 seconds to travel from the Moon to Earth. That's our downlink delay!",
		"Did you know? A 'Sel' is used here for one Moon revolution. It's Sel from Selene, the ancient Greek Goddes",
		"Did you know? Lunar dust (regolith) is electrostatic and sticks to everything, like magnetic sand!",
		"Did you know? The Sun appears about 30% larger in the lunar sky than from Earth!",
		"Did you know? NASA's CRaTER instrument on LRO measured about 5 µGy/h of radiation in lunar orbit.",
		"Did you know? Without gravity, astronauts can lose 1-1.5% of bone mass per month in space!",
		"Did you know? The lunar south pole has 'peaks of eternal light' where the Sun almost never sets!",
	]
	# Derived from the mission seed so "retry this seed" replays the same texts.
	var index := _CONSTANTS.hash_seed(GameState.mission_seed + ":trivia:" + str(GameState.sel))
	return trivia_list[index % trivia_list.size()]


func _on_next_sel() -> void:
	report_overlay.visible = false
	if GameState.game_over:
		return
	GameState.sel += 1
	_start_dawn()


func _show_end_screen() -> void:
	end_sel_button.disabled = true
	# The HUD is a CanvasLayer and would draw on top of the end screen.
	$HUD.visible = false
	end_screen.show_end()


func _refresh_hand() -> void:
	for child in hand_container.get_children():
		hand_container.remove_child(child)
		child.queue_free()

	for card in GameState.hand:
		var btn = preload("res://ui/card_button.tscn").instantiate()
		hand_container.add_child(btn)
		btn.setup(card, self)


func _on_state_changed() -> void:
	_update_action_buttons()
	_refresh_card_locks()


func _refresh_card_locks() -> void:
	if hand_container == null:
		return
	for child in hand_container.get_children():
		if child.has_method("_update_lock"):
			child._update_lock()


func _update_action_buttons() -> void:
	if shelter_button == null or downlink_button == null:
		return

	var storm_active := not GameState.active_storm.is_empty()
	if GameState.sheltered_this_sel:
		shelter_button.disabled = phase != Phase.GAME
		shelter_button.text = "🛡️ Shelter ON (%.0f⚡)" % Constants.SHELTER_COST
	else:
		shelter_button.disabled = phase != Phase.GAME \
			or not storm_active \
			or GameState.battery < Constants.SHELTER_COST
		shelter_button.text = "🛡️ Shelter (%.0f⚡)" % Constants.SHELTER_COST
	shelter_button.set_pressed_no_signal(GameState.sheltered_this_sel)

	var pending := GameState.pending_science
	downlink_button.disabled = phase != Phase.GAME or pending <= 0
	if pending > 0 and GameState.pending_science_age < Constants.DOWNLINK_DELAY_SELS:
		downlink_button.text = "📡 Packaging %d…" % pending
	elif pending > 0 and not GameState.active_storm.is_empty():
		downlink_button.text = "📡 Lost signal (%d)" % pending
	else:
		downlink_button.text = "📡 Downlink %d (%.0f⚡)" % [pending, Constants.DOWNLINK_COST]


func _shelter_reset_ui() -> void:
	if shelter_button != null:
		shelter_button.set_pressed_no_signal(false)


func _on_shelter_toggled(pressed: bool) -> void:
	if phase != Phase.GAME:
		shelter_button.set_pressed_no_signal(GameState.sheltered_this_sel)
		return

	if pressed:
		if GameState.active_storm.is_empty():
			shelter_button.set_pressed_no_signal(false)
			say_lumi("No solar storm right now — the shelter is only needed during a storm.", "curious")
			return
		if GameState.battery < Constants.SHELTER_COST:
			shelter_button.set_pressed_no_signal(false)
			say_lumi(
				"We need %.0f Battery to power the storm shelter!" % Constants.SHELTER_COST,
				"curious"
			)
			return
		GameState.battery = clampf(GameState.battery - Constants.SHELTER_COST, 0.0, 100.0)
		GameState.sheltered_this_sel = true
		say_lumi(
			"Storm shelter powered! Radiation exposure is halved for now, but we spent %.0f Battery."
			% Constants.SHELTER_COST,
			"happy"
		)
	else:
		if GameState.sheltered_this_sel:
			GameState.battery = clampf(GameState.battery + Constants.SHELTER_COST, 0.0, 100.0)
			GameState.sheltered_this_sel = false
			say_lumi("Storm shelter off — battery refunded, but the crew takes full radiation.", "curious")

	_update_action_buttons()
	GameState.emit_changed()


func _on_downlink_pressed() -> void:
	if phase != Phase.GAME:
		return

	if GameState.pending_science <= 0:
		say_lumi("No new science data to send right now.", "curious")
		return
	if GameState.pending_science_age < Constants.DOWNLINK_DELAY_SELS:
		say_lumi(
			"The data is still being packaged. The next comm window opens tomorrow!",
			"curious"
		)
		return
	if not GameState.active_storm.is_empty():
		say_lumi(
			"Radio blackout %s! A solar storm is disrupting communications. Wait for it to pass."
			% str(GameState.active_storm.get("rbe_scale", "R1")),
			"alert"
		)
		return
	if GameState.battery < Constants.DOWNLINK_COST:
		say_lumi(
			"We need %.0f Battery to power the transmitter!" % Constants.DOWNLINK_COST,
			"curious"
		)
		return

	GameState.battery = clampf(GameState.battery - Constants.DOWNLINK_COST, 0.0, 100.0)
	var amount := GameState.bank_pending_science()
	say_lumi(
		"Data downlinked: %d science point(s)! One-way light time to Earth is about 1.3 seconds."
		% amount,
		"happy"
	)
	_update_action_buttons()
	GameState.emit_changed()


func say_lumi(text: String, mood: String = "happy") -> void:
	lumi_box.visible = true
	lumi_box.say(text, mood)


func is_sel() -> bool:
	return phase == Phase.GAME


func _on_new_mission() -> void:
	end_screen.visible = false
	start_new_game()


func _on_retry_seed() -> void:
	var game_seed := GameState.mission_seed
	end_screen.visible = false
	start_new_game(game_seed)


func _on_weather_loaded(data: Dictionary) -> void:
	GameState.nasa_reference = data
	GameState.apod_data = data.get("apod", {})
	GameState.radiation_mSv_day = nasa_manager.get_radiation_msv_day()
	if real_data_panel and real_data_panel.visible:
		real_data_panel.update_data()


func _on_real_data_pressed() -> void:
	if real_data_panel.visible:
		real_data_panel.visible = false
	else:
		real_data_panel.show_panel()
