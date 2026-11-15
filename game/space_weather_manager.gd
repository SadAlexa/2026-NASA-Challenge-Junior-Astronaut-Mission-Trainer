extends Node
## SpaceWeatherManager — fetches REAL space weather data from NOAA SWPC + NASA APOD.
## Maps real measurements to game radiation values.
## Falls back to archived data if APIs are unreachable.

signal weather_loaded(data: Dictionary)

const KP_URL := "https://services.swpc.noaa.gov/json/planetary_k_index_1m.json"
const FLUX_URL := "https://services.swpc.noaa.gov/json/solar-radio-flux.json"
const F107_URL := "https://services.swpc.noaa.gov/json/f107_cm_flux.json"
const OSDR_BASE := "https://visualization.osdr.nasa.gov/radlab/api/"
# CRaTER-D1D2 on LRO (lunar orbit) — used as proxy for surface dose
# Values ~5.0 mSv/hr baseline, spikes to 7-8+ during SPE
var _apod_url: String = "https://science.nasa.gov/wp-json/wp/v2/apod-basic?count=1&api_key="

func _load_env() -> void:
	if FileAccess.file_exists("res://.env"):
		var f := FileAccess.open("res://.env", FileAccess.READ)
		while not f.eof_reached():
			var line: String = f.get_line()
			if line.begins_with("NASA_APOD_API_KEY="):
				var key: String = line.trim_prefix("NASA_APOD_API_KEY=").strip_edges()
				_apod_url += key
				break

# Radiation values in mSv/hr — real CRaTER-D1D2 measurements (LRO lunar orbit)
# Baseline ~5.0, spikes to 7-8+ during solar particle events
const RAD_BASE_MSv := 5.0       # CRaTER baseline (solar minimum)
const RAD_KP3_MSv := 5.5        # Kp 3-4 fallback: minor increase
const RAD_KP5_MSv := 6.5        # Kp 5-6 fallback: significant SEP
const RAD_KP7_MSv := 8.0        # Kp 7-9 fallback: intense SEP

# Fallback archived data (when APIs unreachable)
const FALLBACK := {
	"kp_index": 2,
	"kp_label": "2N",
	"solar_flux_245": 65,
	"solar_flux_410": 120,
	"f107_cm": 140.0,
	"radiation_msV": 5.0,
	"radiation_source": "CRaTER-D1D2 / LRO (orbital proxy)",
	"apod_title": "",
	"apod_explanation": "",
	"apod_date": "",
}


var _current_data: Dictionary = {}


func _ready() -> void:
	_load_env()
	print("[SpaceWeather] Starting fetch...")
	_fetch_all()


func get_data() -> Dictionary:
	return _current_data


func get_radiation_msV() -> float:
	return _current_data.get("radiation_msV", RAD_BASE_MSv)


func get_kp_index() -> int:
	return _current_data.get("kp_index", 2)


func _fetch_all() -> void:
	var kp_http = _make_request(KP_URL)
	kp_http.request_completed.connect(_on_kp_response.bind("kp"))
	
	var flux_http = _make_request(FLUX_URL)
	flux_http.request_completed.connect(_on_flux_response.bind("flux"))
	
	var f107_http = _make_request(F107_URL)
	f107_http.request_completed.connect(_on_f107_response.bind("f107"))
	
	var apod_http = _make_request(_apod_url)
	apod_http.request_completed.connect(_on_apod_response.bind("apod"))
	
	# CRaTER radiation — fixed date range (no live updates available)
	var crater_url := OSDR_BASE + "?instrument=CRaTER-D1D2&timestamp%3E=2023-12-01T23%3A00&timestamp%3C2024-01-01T01%3A05&absorbed_dose_rate&format=json"
	var crater_http = _make_request(crater_url)
	crater_http.request_completed.connect(_on_crater_response)
	
	# Timeout fallback after 4 seconds — fill any missing fields
	await get_tree().create_timer(4.0).timeout
	print("[SpaceWeather] Timeout. Data so far: ", _current_data)
	var fb = FALLBACK.duplicate()
	for key in fb:
		if not _current_data.has(key):
			_current_data[key] = fb[key]
		elif _current_data[key] is String and _current_data[key] == "":
			_current_data[key] = fb[key]
	if not _current_data.has("radiation_msV"):
		_current_data["radiation_msV"] = RAD_BASE_MSv
	if not _current_data.has("radiation_source"):
		_current_data["radiation_source"] = "Archived (RadLab/OSDR baseline)"
	weather_loaded.emit(_current_data)


func _make_request(url: String) -> HTTPRequest:
	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = 5.0
	http.request(url)
	return http


func _on_kp_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, _source: String) -> void:
	print("[SpaceWeather] Kp response: result=%d code=%d" % [result, code])
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var arr = json.data
			if arr is Array and arr.size() > 0:
				var latest = arr[arr.size() - 1]
				var kp: int = int(latest.get("kp_index", 2))
				_current_data["kp_index"] = kp
				_current_data["kp_label"] = str(latest.get("kp", "%dN" % kp))
				# Kp-based radiation fallback (only used if CRaTER data unavailable)
				if not _current_data.has("radiation_msV"):
					if kp >= 7:
						_current_data["radiation_msV"] = RAD_KP7_MSv
					elif kp >= 5:
						_current_data["radiation_msV"] = RAD_KP5_MSv
					elif kp >= 3:
						_current_data["radiation_msV"] = RAD_KP3_MSv + RAD_BASE_MSv
					else:
						_current_data["radiation_msV"] = RAD_BASE_MSv
					_current_data["radiation_source"] = "NOAA SWPC Live (Kp%d)" % kp
	_weather_check()


func _on_crater_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, _source: String) -> void:
	print("[SpaceWeather] CRaTER response: result=%d code=%d" % [result, code])
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data: Array = json.data.get("data", [])
			if data.size() > 0:
				# Calculate average dose rate from all entries
				var total: float = 0.0
				for row in data:
					total += float(row[2])  # dose_rate is index 2
				var avg_msV_hr: float = total / data.size()
				_current_data["radiation_msV"] = roundf(avg_msV_hr * 10.0) / 10.0
				_current_data["radiation_source"] = "CRaTER-D1D2 / LRO (avg %.1f mSv/hr)" % avg_msV_hr
				print("[SpaceWeather] CRaTER avg: %.2f mSv/hr (%d samples)" % [avg_msV_hr, data.size()])
	_weather_check()


func _on_flux_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, _source: String) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var arr = json.data
			if arr is Array and arr.size() > 0:
				var latest = arr[0]  # Most recent first
				var details = latest.get("details", [])
				for d in details:
					if int(d.get("frequency", 0)) == 245:
						_current_data["solar_flux_245"] = int(d.get("flux", 65))
					elif int(d.get("frequency", 0)) == 410:
						_current_data["solar_flux_410"] = int(d.get("flux", 120))
	_weather_check()


func _on_f107_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, _source: String) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var arr = json.data
			if arr is Array and arr.size() > 0:
				var latest = arr[arr.size() - 1]
				_current_data["f107_cm"] = float(latest.get("flux", 140.0))
	_weather_check()


func _on_apod_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, _source: String) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var arr = json.data
			if typeof(arr) == TYPE_ARRAY and arr.size() > 0:
				var data = arr[0]
				_current_data["apod_title"] = str(data.get("title", ""))
				_current_data["apod_explanation"] = str(data.get("explanation", ""))
				_current_data["apod_date"] = str(data.get("date", ""))
				# hdurl is the actual image, url is the article page
				_current_data["apod_url"] = str(data.get("hdurl", data.get("url", "")))
	_weather_check()


func _weather_check() -> void:
	# Emit when we have at least Kp + radiation
	if _current_data.has("kp_index") and _current_data.has("radiation_msV"):
		if not _current_data.has("solar_flux_245"):
			_current_data["solar_flux_245"] = 65
		if not _current_data.has("solar_flux_410"):
			_current_data["solar_flux_410"] = 120
		if not _current_data.has("f107_cm"):
			_current_data["f107_cm"] = 140.0
		weather_loaded.emit(_current_data)
