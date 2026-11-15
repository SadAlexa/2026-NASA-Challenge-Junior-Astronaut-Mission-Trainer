extends Panel
## Real Data Panel — child-friendly attribution of the build-time NASA snapshot.
## All values are archived data embedded in the build; nothing is presented as live.

@onready var content: RichTextLabel = $Content
@onready var close_btn: Button = $CloseButton
@onready var apod_image: TextureRect = $ApodImage

var _apod_texture: Texture2D = null


func _ready() -> void:
	# The HUD is a CanvasLayer: give the panel its own opaque card so the
	# game board cannot show through the text.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.085, 0.99)
	style.border_color = Color(0.35, 0.55, 0.9, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	content.bbcode_enabled = true
	content.meta_clicked.connect(_on_meta_clicked)
	close_btn.pressed.connect(_on_close)


func show_panel() -> void:
	visible = true
	update_data()


func update_data() -> void:
	if not visible:
		return
	content.text = _build_content()
	_load_apod_image()


func _on_close() -> void:
	visible = false


func _on_meta_clicked(meta: Variant) -> void:
	var url := str(meta).strip_edges()
	if url.begins_with("http"):
		OS.shell_open(url)


func _load_apod_image() -> void:
	if _apod_texture != null:
		apod_image.texture = _apod_texture
		return

	var apod: Dictionary = GameState.nasa_reference.get("apod", {})
	var path := str(apod.get("image_path", ""))
	if path == "":
		apod_image.visible = false
		return

	if ResourceLoader.exists(path):
		_apod_texture = load(path) as Texture2D
	else:
		# Fallback for a fresh checkout before the editor imports the JPG.
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(path)) == OK:
			_apod_texture = ImageTexture.create_from_image(img)

	if _apod_texture != null:
		apod_image.texture = _apod_texture
		apod_image.visible = true
	else:
		apod_image.visible = false


func _build_content() -> String:
	var ref: Dictionary = GameState.nasa_reference
	if ref.is_empty():
		return "[center]Loading NASA data snapshot…[/center]"

	var rad: Dictionary = ref.get("radiation", {})
	var apod: Dictionary = ref.get("apod", {})
	var swpc: Dictionary = ref.get("space_weather", {})
	var donki: Dictionary = GameState.donki_dataset
	var counts: Dictionary = donki.get("counts", {})
	var selected: Dictionary = donki.get("selected", {})

	var retrieved := str(ref.get("retrieved", donki.get("retrieved", "?")))
	var archive_badge := "[color=#ffd166][b]ARCHIVED NASA DATA[/b][/color] — retrieved %s" % retrieved

	# --- DONKI ---
	var donki_lines := ""
	if not counts.is_empty():
		donki_lines += "%d flares · %d SEP events · %d CMEs (%s)\n" % [
			int(counts.get("flr", 0)),
			int(counts.get("sep", 0)),
			int(counts.get("cme", 0)),
			str(donki.get("range", "")),
		]
	donki_lines += (
		"In game: C/M/X flares add +%d/+%d/+%d radiation units for %d sels; "
		+ "X flares also damage panels by 10%%. Selected: %d X, %d M, %d C.\n"
	) % [
		Constants.STORM_C_RADIATION,
		Constants.STORM_M_RADIATION,
		Constants.STORM_X_RADIATION,
		Constants.STORM_DURATION,
		int(selected.get("X", 0)),
		int(selected.get("M", 0)),
		int(selected.get("C", 0)),
	]
	var sample = donki.get("events", [])
	if typeof(sample) == TYPE_ARRAY and not sample.is_empty():
		var ev: Dictionary = sample[sample.size() - 1]
		var link := str(ev.get("link", ""))
		if link != "":
			donki_lines += "Example: [url=%s]%s flare on %s[/url]\n" % [
				link,
				str(ev.get("peak_class", ev.get("class", ""))),
				str(ev.get("begin_time", "")).left(10),
			]

	# --- RadLab / OSDR ---
	var median := str(rad.get("median_uGy_h", "?"))
	var absorbed := str(rad.get("absorbed_mGy_day", "?"))
	var period := str(rad.get("period", ""))
	var ref_msv := float(rad.get("lunar_surface_reference_mSv_day", Constants.LUNAR_SURFACE_MSV_DAY))
	var base_units := int(rad.get("game_base_units", Constants.RADIATION_BASE))
	var radlink := str(rad.get("citation", ""))
	var radlab_lines := (
		"Median %s µGy/h in silicon (%s) ≈ %s mGy/day absorbed.\n"
		+ "Detector dose is not a human equivalent dose; the game anchors %d/100 units to ≈ %.1f mSv/day.\n"
	) % [median, period, absorbed, base_units, ref_msv]
	if radlink != "":
		radlab_lines += "[url=%s]RadLab instrument page[/url]\n" % radlink

	# --- APOD ---
	var apod_lines := ""
	var apod_date := str(apod.get("date", ""))
	var apod_title := str(apod.get("title", ""))
	var credit := str(apod.get("credit", ""))
	var apod_url := str(apod.get("page_url", "https://apod.nasa.gov/"))
	if apod_title != "":
		apod_lines = "[i]%s[/i]" % apod_title
		if apod_date != "":
			apod_lines = "%s — %s" % [apod_date, apod_lines]
		if credit != "":
			apod_lines += " (credit: %s)" % credit
		apod_lines += "\n[url=%s]APOD page[/url]\n" % apod_url
	else:
		apod_lines = "APOD unavailable in this build.\n"

	# --- NOAA SWPC ---
	var kp := int(swpc.get("kp_index", 0))
	var kp_time := str(swpc.get("time_tag", ""))
	var swpc_lines := "Kp = %d (%s) at %s.\n" % [kp, _kp_description(kp), kp_time]
	var swpc_url := str(swpc.get("url", ""))
	if swpc_url != "":
		swpc_lines += "[url=%s]NOAA SWPC data[/url]\n" % swpc_url

	return """[center][b]🛰️ Real NASA Data Used[/b][/center]
%s

[b]☀️ DONKI space weather[/b] (NASA CCMC)
%s
[b]☢️ RadLab / OSDR — CRaTER-D1D2 (LRO)[/b]
%s
[b]📷 APOD — Astronomy Picture of the Day[/b]
%s
[b]🌤️ Space weather at build time[/b] (NOAA SWPC, not NASA)
%s
[color=#9fd3ff][i]Numbers are simplified to a 0–100 scale to keep the game fun and intuitive; proportions are preserved. Game storms are drawn from real DONKI events, and no archived value is presented as live.[/i][/color]""" % [
		archive_badge,
		donki_lines,
		radlab_lines,
		apod_lines,
		swpc_lines,
	]


func _kp_description(kp: int) -> String:
	if kp >= 7:
		return "severe storm"
	elif kp >= 5:
		return "geomagnetic storm"
	elif kp == 4:
		return "unsettled"
	return "quiet"
