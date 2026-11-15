extends Panel
## LumiBox — LUMI mascot speech bubble.

@onready var avatar: ColorRect = $Avatar
@onready var face_label: Label = $Avatar/FaceLabel
@onready var helmet: TextureRect = $Avatar/Helmet
@onready var speech: RichTextLabel = $Speech

var close_btn: Button

var mood_colors: Dictionary = {
	"happy": Color(0.4, 0.9, 0.4),
	"curious": Color(0.4, 0.7, 1.0),
	"alert": Color(1.0, 0.6, 0.2),
	"sad": Color(0.5, 0.5, 0.7),
}

var mood_faces: Dictionary = {
	"happy": "^_^",
	"curious": "o_O",
	"alert": "!_!",
	"sad": ";_;",
}


func _ready() -> void:
	_create_close_button()


func _create_close_button() -> void:
	close_btn = Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Top-right corner
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.offset_left = -32.0
	close_btn.offset_top = 2.0
	close_btn.offset_right = -4.0
	close_btn.offset_bottom = 30.0
	close_btn.pressed.connect(_on_close)
	add_child(close_btn)


func say(text: String, mood: String = "happy") -> void:
	visible = true
	avatar.color = mood_colors.get(mood, mood_colors["happy"])
	face_label.text = mood_faces.get(mood, "^_^")
	speech.text = text
	speech.visible = true


func add_line(text: String) -> void:
	speech.text += "\n\n" + text


func _on_close() -> void:
	visible = false
