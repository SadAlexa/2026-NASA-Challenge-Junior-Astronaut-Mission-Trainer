extends Control
## EndScreen — victory/defeat, score, medal, real DONKI event and LUMI tips.

@onready var title: Label = $VBox/Title
@onready var score_label: Label = $VBox/ScoreLabel
@onready var medal_label: Label = $VBox/MedalLabel
@onready var tips_label: RichTextLabel = $VBox/TipsLabel
@onready var data_label: RichTextLabel = $VBox/DataLabel
@onready var seed_label: Label = $VBox/SeedLabel


func _ready() -> void:
	tips_label.bbcode_enabled = true
	data_label.bbcode_enabled = true
	tips_label.meta_clicked.connect(_on_meta_clicked)
	data_label.meta_clicked.connect(_on_meta_clicked)


func _on_meta_clicked(meta: Variant) -> void:
	var url := str(meta).strip_edges()
	if url.begins_with("http"):
		OS.shell_open(url)


func show_end() -> void:
	visible = true

	if GameState.victory:
		title.text = "🎉 MISSION COMPLETE!"
	else:
		title.text = "💔 Mission Ended"

	var score := _calc_score()
	score_label.text = "Score: %d" % score

	if GameState.victory:
		if score >= Constants.MEDAL_GOLD:
			medal_label.text = "🥇 GOLD MEDAL"
		elif score >= Constants.MEDAL_SILVER:
			medal_label.text = "🥈 SILVER MEDAL"
		else:
			medal_label.text = "🥉 BRONZE MEDAL"
	else:
		medal_label.text = "No medal — try again!"

	seed_label.text = "Mission seed: %s" % GameState.mission_seed
	tips_label.text = _generate_tips()
	data_label.text = _data_sources()


func _calc_score() -> int:
	if not GameState.victory:
		return 0
	var score := GameState.health
	score += floor(GameState.oxygen * Constants.SCORE_WEIGHT_O2)
	score += floor(GameState.food * Constants.SCORE_WEIGHT_FOOD)
	score += floor(GameState.water * Constants.SCORE_WEIGHT_WATER)
	score += floor(GameState.battery * Constants.SCORE_WEIGHT_BATT)
	score += GameState.science * Constants.SCORE_WEIGHT_SCIENCE
	return int(score)


func _generate_tips() -> String:
	var tips: Array[String] = []

	var min_panels := 100.0
	var low_food_sels: Array[int] = []
	var storm_sels: Array[int] = []

	for entry in GameState.history_log:
		if float(entry["panels"]) < min_panels:
			min_panels = float(entry["panels"])
		if float(entry["food"]) < 15.0:
			low_food_sels.append(int(entry["sel"]))
		var storm = entry.get("storm", {})
		if typeof(storm) == TYPE_DICTIONARY and not storm.is_empty():
			storm_sels.append(int(entry["sel"]))

	if min_panels < 40.0:
		tips.append("🤖 Your panels dropped to %d%%. Try 'Clean Panels' before the batteries drain!" % int(min_panels))

	if low_food_sels.size() > 2:
		tips.append("🤖 Food ran low on %d sels. Play 'Grow Crops' more often or expand the greenhouse early!" % low_food_sels.size())

	# The strongest real DONKI event faced during this mission.
	if not GameState.strongest_storm.is_empty():
		var storm := GameState.strongest_storm
		var event_line := "☀️ Strongest real event faced: %s flare on %s (Sel %d, NASA DONKI)." % [
			str(storm.get("peak", storm.get("class", ""))),
			str(storm.get("date", "")),
			int(storm.get("sel", 0)),
		]
		var link := str(storm.get("link", ""))
		if link != "":
			event_line += " [url=%s]Event details[/url]" % link
		tips.append(event_line)
	elif storm_sels.size() > 0:
		tips.append("☀️ Solar storms hit on sel(s) %s. Keep batteries charged before storms!" % _join_ints(storm_sels))
	else:
		tips.append("☀️ Calm space weather: no solar storms during this mission.")

	if GameState.pending_science > 0:
		tips.append("📡 %d science point(s) were still waiting for a downlink window and were not scored." % GameState.pending_science)

	if tips.size() < 2:
		tips.append("🤖 Next time, try to maximize Science Points and downlink them before the mission ends!")

	if GameState.victory:
		tips.append("❤️ Crew health: %d · O₂: %d · Food: %d · Water: %d" % [
			int(GameState.health), int(GameState.oxygen), int(GameState.food), int(GameState.water)
		])
	else:
		var reason := "The crew ran out of health."
		if GameState.oxygen <= 0.0:
			reason = "Oxygen reached 0."
		elif GameState.food <= 0.0:
			reason = "Food reached 0 at the end of the mission."
		elif GameState.water <= 0.0:
			reason = "Water reached 0 at the end of the mission."
		tips.append("🤖 %s Try again: keep LIFE above 25 and downlink science when the radio is clear." % reason)

	return "\n".join(tips)


func _data_sources() -> String:
	var ref := GameState.nasa_reference
	var rad: Dictionary = ref.get("radiation", {})
	var apod: Dictionary = ref.get("apod", {})
	var retrieved := str(ref.get("retrieved", "?"))
	var radlink := str(rad.get("citation", "https://visualization.osdr.nasa.gov/radlab/gui/knowledgebase/CRaTER-D1D2"))

	var lines: Array[String] = []
	lines.append("[b]Data used[/b] (archived, retrieved %s):" % retrieved)
	lines.append(
		"[url=https://ccmc.gsfc.nasa.gov/tools/DONKI/]NASA DONKI[/url] (real solar flares/SEP/CME) · "
		+ "[url=%s]NASA RadLab/OSDR CRaTER-D1D2 (LRO)[/url] · " % radlink
		+ "[url=https://apod.nasa.gov/]APOD[/url]"
	)
	if not apod.is_empty() and str(apod.get("date", "")) != "":
		lines.append("APOD: %s — %s" % [str(apod.get("date", "")), str(apod.get("title", ""))])
	lines.append("[i]Game values are simplified to a 0–100 scale; archived data is never presented as live.[/i]")
	return "\n".join(lines)


func _join_ints(values: Array[int]) -> String:
	var parts: Array[String] = []
	for v in values:
		parts.append(str(v))
	return ", ".join(parts)
