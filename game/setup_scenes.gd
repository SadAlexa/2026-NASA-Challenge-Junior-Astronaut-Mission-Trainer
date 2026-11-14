extends SceneTree
## Builds game.tscn entirely programmatically and saves it.

func _initialize() -> void:
	var root = Control.new()
	root.name = "root"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	
	# --- Background ---
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.05, 0.05, 0.12, 1)
	root.add_child(bg)
	
	# --- Systems ---
	var card_sys = Node.new()
	card_sys.name = "CardSystem"
	card_sys.set_script(load("res://game/card_system.gd"))
	root.add_child(card_sys)
	
	var event_sys = Node.new()
	event_sys.name = "EventSystem"
	event_sys.set_script(load("res://game/event_system.gd"))
	root.add_child(event_sys)
	
	var night_ph = Node.new()
	night_ph.name = "NightPhase"
	night_ph.set_script(load("res://game/night_phase.gd"))
	root.add_child(night_ph)
	
	# --- HUD ---
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://ui/hud.gd"))
	root.add_child(hud)
	
	# TopBar
	var top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 50.0
	top_bar.add_theme_constant_override("separation", 16)
	hud.add_child(top_bar)
	
	_add_label(top_bar, "SolCounter", "Sel 1/30")
	
	var ebar = _add_progress(top_bar, "EnergyBar")
	_add_label(top_bar, "EnergyLabel", "80")
	_add_label(top_bar, "PanelsLabel", "☀️50%")
	
	var lbar = _add_progress(top_bar, "LifeBar")
	_add_label(top_bar, "HealthLabel", "❤️100")
	_add_label(top_bar, "O2Mini", "O₂:80")
	_add_label(top_bar, "FoodMini", "🌱60")
	_add_label(top_bar, "WaterMini", "💧70")
	
	var rbar = _add_progress(top_bar, "RaysBar")
	_add_label(top_bar, "RaysLabel", "☢️0")
	_add_label(top_bar, "ScienceBadge", "🔬 0")
	
	# LumiBox
	var lumi_box = Panel.new()
	lumi_box.name = "LumiBox"
	lumi_box.visible = false
	lumi_box.anchor_left = 0.1
	lumi_box.anchor_right = 0.9
	lumi_box.anchor_top = 0.08
	lumi_box.anchor_bottom = 0.35
	lumi_box.set_script(load("res://ui/lumi_box.gd"))
	hud.add_child(lumi_box)
	
	var avatar = ColorRect.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = Vector2(60, 60)
	avatar.color = Color(0.4, 0.6, 1, 1)
	lumi_box.add_child(avatar)
	
	var face = Label.new()
	face.name = "FaceLabel"
	face.anchor_right = 1.0
	face.anchor_bottom = 1.0
	face.text = "😊"
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(face)
	
	var speech = RichTextLabel.new()
	speech.name = "Speech"
	speech.anchor_left = 0.12
	speech.anchor_right = 0.95
	speech.anchor_top = 0.1
	speech.anchor_bottom = 0.85
	speech.bbcode_enabled = true
	lumi_box.add_child(speech)
	
	# --- Hand ---
	var hand = Control.new()
	hand.name = "Hand"
	hand.anchor_left = 0.02
	hand.anchor_right = 0.98
	hand.anchor_top = 0.65
	hand.anchor_bottom = 0.95
	root.add_child(hand)
	
	var card_row = HBoxContainer.new()
	card_row.name = "CardRow"
	card_row.anchor_right = 1.0
	card_row.anchor_bottom = 1.0
	card_row.add_theme_constant_override("separation", 20)
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand.add_child(card_row)
	
	# --- Board ---
	var board = Control.new()
	board.name = "Board"
	board.anchor_left = 0.02
	board.anchor_right = 0.98
	board.anchor_top = 0.12
	board.anchor_bottom = 0.62
	root.add_child(board)
	
	var played = HBoxContainer.new()
	played.name = "PlayedCards"
	played.anchor_right = 1.0
	played.anchor_bottom = 1.0
	played.add_theme_constant_override("separation", 16)
	played.alignment = BoxContainer.ALIGNMENT_CENTER
	board.add_child(played)
	
	# --- EndDayButton ---
	var end_btn = Button.new()
	end_btn.name = "EndDayButton"
	end_btn.anchor_left = 0.82
	end_btn.anchor_right = 0.97
	end_btn.anchor_top = 0.62
	end_btn.anchor_bottom = 0.65
	end_btn.text = "☀️ End Day"
	root.add_child(end_btn)
	
	# --- ReportOverlay ---
	var report = Control.new()
	report.name = "ReportOverlay"
	report.visible = false
	report.anchor_right = 1.0
	report.anchor_bottom = 1.0
	root.add_child(report)
	
	var report_text = RichTextLabel.new()
	report_text.name = "ReportText"
	report_text.anchor_left = 0.15
	report_text.anchor_right = 0.85
	report_text.anchor_top = 0.1
	report_text.anchor_bottom = 0.75
	report_text.bbcode_enabled = true
	report.add_child(report_text)
	
	var next_btn = Button.new()
	next_btn.name = "NextSelButton"
	next_btn.anchor_left = 0.4
	next_btn.anchor_right = 0.6
	next_btn.anchor_top = 0.78
	next_btn.anchor_bottom = 0.85
	next_btn.text = "➡️ Next Sel"
	report.add_child(next_btn)
	
	# --- EndScreen ---
	var end_screen = Control.new()
	end_screen.name = "EndScreen"
	end_screen.visible = false
	end_screen.anchor_right = 1.0
	end_screen.anchor_bottom = 1.0
	end_screen.set_script(load("res://game/end_screen.gd"))
	root.add_child(end_screen)
	
	var end_bg = ColorRect.new()
	end_bg.name = "Bg"
	end_bg.anchor_right = 1.0
	end_bg.anchor_bottom = 1.0
	end_bg.color = Color(0, 0, 0, 0.85)
	end_screen.add_child(end_bg)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_left = 0.2
	vbox.anchor_right = 0.8
	vbox.anchor_top = 0.1
	vbox.anchor_bottom = 0.9
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	end_screen.add_child(vbox)
	
	var title = Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 36)
	title.text = "Mission Complete!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var score = Label.new()
	score.name = "ScoreLabel"
	score.add_theme_font_size_override("font_size", 24)
	score.text = "Score: 0"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score)
	
	var medal = Label.new()
	medal.name = "MedalLabel"
	medal.add_theme_font_size_override("font_size", 28)
	medal.text = "🥉 Bronze"
	medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(medal)
	
	var tips = RichTextLabel.new()
	tips.name = "TipsLabel"
	tips.custom_minimum_size = Vector2(0, 150)
	tips.bbcode_enabled = true
	vbox.add_child(tips)
	
	var data = Label.new()
	data.name = "DataLabel"
	data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(data)
	
	# --- Attach root script ---
	root.set_script(load("res://game/game.gd"))
	
	# --- Connect signals ---
	end_btn.pressed.connect(root._on_end_day)
	next_btn.pressed.connect(root._on_next_sel)
	
	# --- Set owner (required for pack) ---
	root.owner = root
	_set_owner_children(root, root)
	
	# --- Save ---
	var packed = PackedScene.new()
	var err = packed.pack(root)
	if err != OK:
		push_error("Pack failed: %d" % err)
		quit(1)
		return
	
	var path = "res://game/game.tscn"
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Save failed: %d" % err)
		quit(1)
		return
	
	print("✅ game.tscn saved!")
	quit(0)


func _add_label(parent: Control, node_name: String, text: String) -> Label:
	var l = Label.new()
	l.name = node_name
	l.text = text
	parent.add_child(l)
	return l


func _add_progress(parent: Control, node_name: String) -> ProgressBar:
	var p = ProgressBar.new()
	p.name = node_name
	p.custom_minimum_size = Vector2(100, 20)
	parent.add_child(p)
	return p


func _set_owner_children(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owner_children(child, root)
