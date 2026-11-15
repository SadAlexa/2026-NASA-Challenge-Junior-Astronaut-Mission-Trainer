extends Panel
## Real Data Panel — child-friendly NASA data display (English).
## Structured like LumiBox: a Panel under HUD, toggled visible.


@onready var content: RichTextLabel = $Content
@onready var close_btn: Button = $CloseButton
@onready var apod_image: TextureRect = $ApodImage

var _img_loader: HTTPRequest


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	_img_loader = HTTPRequest.new()
	add_child(_img_loader)
	_img_loader.request_completed.connect(_on_image_loaded)


func show_panel() -> void:
	visible = true
	update_data()


func update_data() -> void:
	if not visible:
		return
	content.text = _build_content()
	_load_image()


func _on_close() -> void:
	visible = false


func _load_image() -> void:
	var url: String = GameState.apod_data.get("apod_url", "")
	if url == "":
		return
	_img_loader.request(url)


func _on_image_loaded(result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(body) == OK:
		apod_image.texture = ImageTexture.create_from_image(img)
	elif img.load_png_from_buffer(body) == OK:
		apod_image.texture = ImageTexture.create_from_image(img)


func _build_content() -> String:
	var data: Dictionary = GameState.apod_data
	var msV = data.get("radiation_msV", 5.0)
	var kp = data.get("kp_index", "?")
	var apod_title = data.get("apod_title", "Loading...")
	
	return """[center]🛰️ Our Real Data! 🚀[/center]

☢️ [b]Radiation:[/b] Today on the Moon it would be [color=#ff6666]%s mSv/hr![/color]
🌤️ [b]Space Weather:[/b] The Sun is [color=#66ff66]calm[/color] today (Kp = %s).
📷 [b]NASA Picture of the Day:[/b] [i]%s[/i]""" % [msV, kp, apod_title]
