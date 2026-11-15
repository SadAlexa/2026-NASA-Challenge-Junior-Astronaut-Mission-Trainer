extends CanvasLayer
## HUD — binds bars to GameState.

@onready var sel_label: Label = $TopBar/SolCounter
@onready var energy_bar: ProgressBar = $TopBar/EnergyContainer/EnergyBar
@onready var energy_label: Label = $TopBar/EnergyContainer/EnergyLabel
@onready var panels_label: Label = $TopBar/PanelsLabel
@onready var life_bar: ProgressBar = $TopBar/HealthContainer/LifeBar
@onready var health_label: Label = $TopBar/HealthContainer/HealthLabel
@onready var o2_mini: Label = $TopBar/O2Mini
@onready var food_mini: Label = $TopBar/FoodMini
@onready var water_mini: Label = $TopBar/WaterMini
@onready var rays_bar: ProgressBar = $TopBar/RaysContainer/RaysBar
@onready var rays_label: Label = $TopBar/RaysContainer/RaysLabel
@onready var science_badge: Label = $TopBar/ScienceBadge


func _ready() -> void:
	# The top bar holds many values: keep it readable on a 1280x720 canvas.
	for child in $TopBar.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", 14)
	GameState.state_changed.connect(_update)
	_update()


func _update() -> void:
	var seed_text := GameState.mission_seed
	if seed_text == "":
		sel_label.text = "Sel %d/%d" % [GameState.sel, Constants.TOTAL_SOLS]
	else:
		sel_label.text = "Sel %d/%d · %s" % [GameState.sel, Constants.TOTAL_SOLS, seed_text]

	# Energy
	energy_bar.value = GameState.battery
	energy_label.text = "🔋%d" % int(GameState.battery)
	panels_label.text = "☀️%d%%" % int(GameState.panels)
	energy_bar.modulate = _bar_color(GameState.battery)

	# Life (show health as main bar)
	life_bar.value = GameState.health
	health_label.text = "❤️%d" % int(GameState.health)
	o2_mini.text = "O₂:%d" % int(GameState.oxygen)
	food_mini.text = "🌱%d" % int(GameState.food)
	water_mini.text = "💧%d" % int(GameState.water)
	life_bar.modulate = _bar_color(GameState.health)

	# Rays: game units + the real lunar-surface equivalent.
	var rad := GameState.get_effective_radiation()
	rays_bar.value = minf(rad, 100.0)
	var per_unit := Constants.RADIATION_GAME_TO_MSV_DAY
	if GameState.radiation_mSv_day > 0.0:
		per_unit = GameState.radiation_mSv_day / Constants.RADIATION_BASE
	rays_label.text = "☢ %d · %.1f mSv/d" % [int(rad), rad * per_unit]
	if GameState.sheltered_this_sel:
		rays_label.text += " 🛡️"
	rays_bar.modulate = Color(0.7, 0.3, 0.9) if rad > 35 else Color(0.6, 0.5, 0.8)

	# Science (banked + waiting for a downlink)
	if GameState.pending_science > 0:
		science_badge.text = "🔬 %d (+%d📡)" % [GameState.science, GameState.pending_science]
	else:
		science_badge.text = "🔬 %d" % GameState.science


func _bar_color(val: float) -> Color:
	if val > 50:
		return Color(0.3, 0.9, 0.3)
	elif val > 25:
		return Color(0.9, 0.8, 0.2)
	else:
		return Color(0.9, 0.3, 0.3)
