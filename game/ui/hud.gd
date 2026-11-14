extends CanvasLayer
## HUD — binds bars to GameState.

@onready var sel_label: Label = $TopBar/SolCounter
@onready var energy_bar: ProgressBar = $TopBar/EnergyBar
@onready var energy_label: Label = $TopBar/EnergyLabel
@onready var panels_label: Label = $TopBar/PanelsLabel
@onready var life_bar: ProgressBar = $TopBar/LifeBar
@onready var health_label: Label = $TopBar/HealthLabel
@onready var o2_mini: Label = $TopBar/O2Mini
@onready var food_mini: Label = $TopBar/FoodMini
@onready var water_mini: Label = $TopBar/WaterMini
@onready var rays_bar: ProgressBar = $TopBar/RaysBar
@onready var rays_label: Label = $TopBar/RaysLabel
@onready var science_badge: Label = $TopBar/ScienceBadge


func _ready() -> void:
	GameState.state_changed.connect(_update)
	_update()


func _update() -> void:
	sel_label.text = "Sel %d/%d" % [GameState.sel, Constants.TOTAL_SOLS]
	
	# Energy
	energy_bar.value = GameState.battery
	energy_label.text = "%d" % int(GameState.battery)
	panels_label.text = "☀️%d%%" % int(GameState.panels)
	
	# Life (show health as main bar)
	life_bar.value = GameState.health
	health_label.text = "❤️%d" % int(GameState.health)
	o2_mini.text = "O₂:%d" % int(GameState.oxygen)
	food_mini.text = "🌱%d" % int(GameState.food)
	water_mini.text = "💧%d" % int(GameState.water)
	
	# Color coding
	life_bar.modulate = _bar_color(GameState.health)
	
	# Rays
	var rad = GameState.get_effective_radiation()
	rays_bar.value = minf(rad, 100.0)
	rays_label.text = "☢️%d" % int(rad)
	rays_bar.modulate = Color(0.7, 0.3, 0.9) if rad > 35 else Color(0.6, 0.5, 0.8)
	
	# Science
	science_badge.text = "🔬 %d" % GameState.science


func _bar_color(val: float) -> Color:
	if val > 50:
		return Color(0.3, 0.9, 0.3)
	elif val > 25:
		return Color(0.9, 0.8, 0.2)
	else:
		return Color(0.9, 0.3, 0.3)
