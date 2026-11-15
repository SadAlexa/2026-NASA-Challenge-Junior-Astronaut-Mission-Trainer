extends Node
## EventSystem — loads the build-time NASA DONKI archive and rolls crises.
## No network access: DONKI data is embedded by tools/fetch_nasa_data.py.

const _CONSTANTS := preload("res://data/constants.gd")
const ARCHIVE_PATH := "res://data/donki_events.json"

var donki_events: Array = []
var dataset: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	load_archive()


func set_seed(seed_text: String) -> void:
	_rng.seed = _CONSTANTS.hash_seed(seed_text + ":crisis")


func load_archive() -> void:
	donki_events = []
	dataset = {}

	var file := FileAccess.open(ARCHIVE_PATH, FileAccess.READ)
	if file == null:
		push_error("EventSystem: cannot open %s" % ARCHIVE_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("events"):
		dataset = parsed.get("dataset", {})
		donki_events = parsed.get("events", [])
	else:
		push_error("EventSystem: unexpected DONKI JSON schema")
		return

	_validate_archive()
	print("[EventSystem] DONKI archive: %d events (%s)" % [
		donki_events.size(), dataset.get("retrieved", "date unknown")
	])


func _validate_archive() -> void:
	var valid: Array = []
	for ev in donki_events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var cls := str(ev.get("class", ""))
		if cls not in ["C", "M", "X"]:
			continue
		if str(ev.get("id", "")) == "":
			continue
		valid.append(ev)
	donki_events = valid
	if donki_events.is_empty():
		push_error("EventSystem: no valid DONKI events in archive")
	GameState.donki_dataset = dataset


func get_dataset_info() -> Dictionary:
	return dataset


# Crisis pool

func roll_crisis() -> Dictionary:
	"""Returns the crisis event dict, or {} for a clear sel."""
	# No crises during the first two sels.
	if GameState.sel <= 2:
		return {}

	# A storm is already active: only non-storm crises can happen.
	if not GameState.active_storm.is_empty():
		var pool: Array[String] = ["micrometeoroid"]
		if GameState.o2_shield_sels <= 0:
			pool.append("o2_malfunction")
		if _rng.randf() < Constants.CRISIS_CHANCE:
			return _make_non_storm(pool[_rng.randi_range(0, pool.size() - 1)])
		return {}

	if _rng.randf() >= Constants.CRISIS_CHANCE:
		return {}  # Clear

	var roll := _rng.randf()
	if roll < 0.60:
		return _make_storm()
	if roll < 0.80:
		return _make_non_storm("micrometeoroid")
	if GameState.o2_shield_sels > 0:
		return _make_non_storm("micrometeoroid")
	return _make_non_storm("o2_malfunction")


func _make_storm() -> Dictionary:
	var cls := _pick_storm_class()
	var ev := _pick_event(cls)
	if ev.is_empty():
		ev = _pick_event("")
	if ev.is_empty():
		return {}

	return {
		"type": "solar_storm",
		"class": cls,
		"radiation_bonus": _class_radiation(cls),
		"duration_sels": Constants.STORM_DURATION,
		"panel_damage": _class_panel_damage(cls),
		"rbe_scale": _class_rbe_scale(cls),
		"event_id": str(ev.get("id", "")),
		"date": _event_date(ev),
		"peak": str(ev.get("peak_class", "")),
		"link": str(ev.get("link", "")),
	}


func _pick_storm_class() -> String:
	var roll := _rng.randf()
	var cumulative := 0.0
	# Fixed order so the RNG stream is identical across runs.
	for cls in ["C", "M", "X"]:
		cumulative += float(Constants.STORM_CLASS_WEIGHTS.get(cls, 0.0))
		if roll <= cumulative:
			return cls
	return "C"


func _pick_event(cls: String) -> Dictionary:
	var candidates: Array = []
	for ev in donki_events:
		if cls == "" or str(ev.get("class", "")) == cls:
			candidates.append(ev)
	if candidates.is_empty():
		return {}
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _make_non_storm(kind: String) -> Dictionary:
	if kind == "o2_malfunction":
		return {"type": "o2_malfunction"}
	return {
		"type": "micrometeoroid",
		"panel_damage": Constants.MICROMETEOROID_PANEL_DAMAGE,
	}


func _event_date(ev: Dictionary) -> String:
	var begin := str(ev.get("begin_time", ""))
	if begin.length() >= 10:
		return begin.left(10)
	return begin


func _class_radiation(cls: String) -> int:
	match cls:
		"C": return Constants.STORM_C_RADIATION
		"M": return Constants.STORM_M_RADIATION
		"X": return Constants.STORM_X_RADIATION
	return Constants.STORM_C_RADIATION


func _class_panel_damage(cls: String) -> float:
	if cls == "X":
		return Constants.STORM_X_PANEL_DAMAGE
	return 0.0


func _class_rbe_scale(cls: String) -> String:
	# NOAA radio-blackout scale: X flares reach R3-R5, M flares R2, C flares R1.
	match cls:
		"X": return "R3"
		"M": return "R2"
	return "R1"


# Apply / tick

func apply_crisis(event: Dictionary) -> void:
	if event.is_empty():
		return

	match event.get("type", ""):
		"solar_storm":
			var radiation := int(event.get("radiation_bonus", Constants.STORM_C_RADIATION))
			GameState.active_storm = {
				"class": str(event.get("class", "C")),
				"sels_left": int(event.get("duration_sels", Constants.STORM_DURATION)),
				"radiation_bonus": radiation,
				"rbe_scale": str(event.get("rbe_scale", "R1")),
				"event_id": event.get("event_id", ""),
				"date": event.get("date", ""),
				"peak": event.get("peak", ""),
				"link": event.get("link", ""),
			}
			if float(event.get("panel_damage", 0)) < 0.0:
				GameState.panels = clampf(
					GameState.panels + float(event.get("panel_damage", 0)),
					Constants.PANEL_MIN,
					Constants.PANEL_MAX
				)
			if GameState.strongest_storm.is_empty() \
				or radiation > int(GameState.strongest_storm.get("radiation_bonus", 0)):
				GameState.strongest_storm = {
					"class": str(event.get("class", "C")),
					"rbe_scale": str(event.get("rbe_scale", "R1")),
					"peak": event.get("peak", ""),
					"date": event.get("date", ""),
					"event_id": event.get("event_id", ""),
					"link": event.get("link", ""),
					"radiation_bonus": radiation,
					"sel": GameState.sel,
				}

		"micrometeoroid":
			GameState.panels = clampf(
				GameState.panels + float(event.get("panel_damage", Constants.MICROMETEOROID_PANEL_DAMAGE)),
				Constants.PANEL_MIN,
				Constants.PANEL_MAX
			)

		"o2_malfunction":
			GameState.o2_malfunction = true

	GameState.emit_changed()


func tick_storm() -> void:
	"""Called at START: decrement the remaining storm duration."""
	if GameState.active_storm.is_empty():
		return
	GameState.active_storm["sels_left"] = int(GameState.active_storm["sels_left"]) - 1
	if int(GameState.active_storm["sels_left"]) <= 0:
		GameState.active_storm = {}


func tick_o2_shield() -> void:
	"""Called after the START crisis roll, so the shield protects that START."""
	if GameState.o2_shield_sels > 0:
		GameState.o2_shield_sels -= 1


func end_sel() -> void:
	"""Called at the end of the END_SEL phase."""
	# An O2 machine malfunction affects exactly one sel unless repaired.
	GameState.o2_malfunction = false
