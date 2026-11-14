extends Control
## EndScreen — victory/defeat + score + LUMI tips.

@onready var title: Label = $VBox/Title
@onready var score_label: Label = $VBox/ScoreLabel
@onready var medal_label: Label = $VBox/MedalLabel
@onready var tips_label: RichTextLabel = $VBox/TipsLabel
@onready var data_label: Label = $VBox/DataLabel


func show_end() -> void:
	visible = true
	
	if GameState.victory:
		title.text = "🎉 MISSION COMPLETE!"
	else:
		title.text = "💔 Mission Ended"
	
	# Score
	var score = _calc_score()
	score_label.text = "Score: %d" % score
	
	# Medal
	var medal: String
	if GameState.victory:
		if score >= Constants.MEDAL_GOLD:
			medal = "🥇 GOLD MEDAL"
		elif score >= Constants.MEDAL_SILVER:
			medal = "🥈 SILVER MEDAL"
		else:
			medal = "🥉 BRONZE MEDAL"
	else:
		medal = "No medal — try again!"
	medal_label.text = medal
	
	# LUMI tips from history
	tips_label.text = _generate_tips()
	
	data_label.text = "Data: NASA DONKI · RadLab/OSDR · APOD"


func _calc_score() -> int:
	if not GameState.victory:
		return 0
	var score = GameState.health
	score += floor(GameState.oxygen * Constants.SCORE_WEIGHT_O2)
	score += floor(GameState.food * Constants.SCORE_WEIGHT_FOOD)
	score += floor(GameState.water * Constants.SCORE_WEIGHT_WATER)
	score += floor(GameState.battery * Constants.SCORE_WEIGHT_BATT)
	score += GameState.science * Constants.SCORE_WEIGHT_SCIENCE
	return int(score)


func _generate_tips() -> String:
	var tips: Array[String] = []
	
	# Analyze history for patterns
	var min_panels = 100.0
	var low_food_sels: Array[int] = []
	var storm_sels: Array[int] = []
	
	for entry in GameState.history_log:
		if entry["panels"] < min_panels:
			min_panels = entry["panels"]
		if entry["food"] < 15:
			low_food_sels.append(entry["sel"])
		if entry["storm"]:
			storm_sels.append(entry["sel"])
	
	if min_panels < 40:
		tips.append("🤖 Your panels dropped to %d%%. Try playing 'Clean Panels' before batteries drain!" % int(min_panels))
	
	if low_food_sels.size() > 2:
		tips.append("🤖 Food ran low on %d sels. Play 'Grow Crops' more often or expand the greenhouse early!" % low_food_sels.size())
	
	if storm_sels.size() > 0:
		var sel_str = ""
		for s in storm_sels:
			if sel_str != "":
				sel_str += ", "
			sel_str += str(s)
		tips.append("🤖 Solar storms hit on sel(s) %s. Keep batteries charged before storms!" % sel_str)
	
	if tips.is_empty():
		tips.append("🤖 Great job, Commander! You managed the outpost well.")
		tips.append("🤖 Next time, try to maximize Science Points for a Gold Medal!")
	
	return "\n".join(tips)
