extends Node
## EventSystem — crisis roll at Dawn, storm tracking.

var donki_events: Array = []


func _ready() -> void:
	_load_events()


func _load_events() -> void:
	var file = FileAccess.open("res://data/donki_events.json", FileAccess.READ)
	if file:
		donki_events = JSON.parse_string(file.get_as_text())
		file.close()


func roll_crisis() -> Dictionary:
	"""Returns the crisis event dict (or empty for Clear)."""
	
	# No crises during tutorial sels 1-2
	if GameState.sel <= 2:
		return {}
	
	# If a storm is already active, no new storm
	if not GameState.active_storm.is_empty():
		# Can still get micrometeoroid or O2 malfunction
		var non_storm_events = [
			{"type": "micrometeoroid", "panel_damage": -30},
			{"type": "o2_malfunction"}
		]
		if randf() < Constants.CRISIS_CHANCE:
			return non_storm_events[randi() % non_storm_events.size()]
		return {}
	
	var roll = randf()
	if roll >= Constants.CRISIS_CHANCE:
		return {}  # Clear
	
	# Pick a random DONKI event for storms, or micrometeoroid/O2
	var event_type = randi() % 5
	match event_type:
		0, 1, 2:
			# Solar storm — pick from DONKI events
			var ev = donki_events[randi() % donki_events.size()]
			return {
				"type": "solar_storm",
				"class": ev["class"],
				"radiation_bonus": ev["radiation_bonus"],
				"duration_sels": ev["duration_sels"],
				"panel_damage": ev.get("panel_damage", 0),
				"event_id": ev["id"],
				"date": ev["date"],
			}
		3:
			return {"type": "micrometeoroid", "panel_damage": -30}
		4:
			return {"type": "o2_malfunction"}
	
	return {}


func apply_crisis(event: Dictionary) -> void:
	if event.is_empty():
		return
	
	match event.get("type", ""):
		"solar_storm":
			GameState.active_storm = {
				"class": event["class"],
				"sels_left": event["duration_sels"],
				"radiation_bonus": event["radiation_bonus"],
				"event_id": event.get("event_id", ""),
				"date": event.get("date", ""),
			}
			if event.get("panel_damage", 0) < 0:
				GameState.panels = clampf(GameState.panels + event["panel_damage"], Constants.PANEL_MIN, Constants.PANEL_MAX)
		
		"micrometeoroid":
			GameState.panels = clampf(GameState.panels + event.get("panel_damage", -30), Constants.PANEL_MIN, Constants.PANEL_MAX)
		
		"o2_malfunction":
			GameState.o2_malfunction = true


func tick_storm() -> void:
	"""Called at end of each sel to decrement storm duration."""
	if not GameState.active_storm.is_empty():
		GameState.active_storm["sels_left"] -= 1
		if GameState.active_storm["sels_left"] <= 0:
			GameState.active_storm = {}


func tick_o2_shield() -> void:
	if GameState.o2_shield_sels > 0:
		GameState.o2_shield_sels -= 1
