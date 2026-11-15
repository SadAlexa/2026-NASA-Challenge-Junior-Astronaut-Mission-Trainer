extends Node
## SpaceWeatherManager — loads the build-time NASA snapshot.
##
## No network access: tools/fetch_nasa_data.py embeds real DONKI/RadLab/APOD
## data in game/data/ before export. This node only reads it.

signal weather_loaded(data: Dictionary)

const REFERENCE_PATH := "res://data/nasa_reference.json"

var _data: Dictionary = {}


func _ready() -> void:
	load_snapshot()


func load_snapshot() -> void:
	_data = _fallback_data()

	var file := FileAccess.open(REFERENCE_PATH, FileAccess.READ)
	if file == null:
		push_error("SpaceWeatherManager: cannot open %s" % REFERENCE_PATH)
	else:
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) == TYPE_DICTIONARY:
			# Merge so a partial snapshot still has safe defaults.
			for key in parsed:
				_data[key] = parsed[key]
		else:
			push_error("SpaceWeatherManager: unexpected snapshot schema")

	print("[SpaceWeatherManager] Snapshot: %s | RadLab %s uGy/h | APOD %s" % [
		_data.get("retrieved", "?"),
		str(_data.get("radiation", {}).get("median_uGy_h", "?")),
		_data.get("apod", {}).get("date", "?"),
	])

	weather_loaded.emit(_data)


func _fallback_data() -> Dictionary:
	return {
		"retrieved": "",
		"archived": true,
		"radiation": {
			"source": "NASA RadLab / OSDR - CRaTER-D1D2 (LRO)",
			"instrument": "CRaTER-D1D2",
			"raw_unit": "uGy/h",
			"median_uGy_h": 5.26,
			"mean_uGy_h": 7.64,
			"max_uGy_h": 92.0,
			"status": "fallback",
			"lunar_surface_reference_mSv_day": Constants.LUNAR_SURFACE_MSV_DAY,
			"game_base_units": Constants.RADIATION_BASE,
			"game_unit_mSv_day": Constants.RADIATION_GAME_TO_MSV_DAY,
			"citation": "https://visualization.osdr.nasa.gov/radlab/gui/knowledgebase/CRaTER-D1D2",
		},
		"apod": {
			"status": "missing",
			"date": "",
			"title": "NASA APOD unavailable",
			"credit": "",
			"image_path": "",
			"page_url": "https://apod.nasa.gov/",
		},
		"space_weather": {
			"source": "NOAA SWPC (not NASA)",
			"kp_index": 0,
			"kp_label": "",
			"time_tag": "",
			"url": "https://services.swpc.noaa.gov/",
		},
	}


func get_data() -> Dictionary:
	return _data


func get_radiation_reference() -> Dictionary:
	return _data.get("radiation", {})


func get_apod() -> Dictionary:
	return _data.get("apod", {})


func get_space_weather() -> Dictionary:
	return _data.get("space_weather", {})


func get_radiation_msv_day() -> float:
	return float(get_radiation_reference().get(
		"lunar_surface_reference_mSv_day",
		Constants.LUNAR_SURFACE_MSV_DAY
	))


func get_kp_description(kp: int) -> String:
	if kp >= 7:
		return "severe storm (G3+)"
	elif kp >= 5:
		return "geomagnetic storm (G1-G2)"
	elif kp == 4:
		return "unsettled"
	return "quiet"
