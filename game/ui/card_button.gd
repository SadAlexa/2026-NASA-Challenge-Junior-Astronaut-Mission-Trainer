extends Panel
## CardButton — one card in the player's hand.

var card_data: Dictionary = {}
var game_ref: Node = null

@onready var icon_label: Label = $VBox/MarginContainer2/VBoxContainer/IconLabel
@onready var name_label: Label = $VBox/MarginContainer2/VBoxContainer/NameLabel
@onready var lock_overlay: ColorRect = $LockOverlay
@onready var info_button: Button = $TopBar/Row/InfoButton
@onready var energy_label: Label = $TopBar/Row/EnergyLabel
@onready var card_border: Panel = $BorderContainer/Border
@onready var effects_box: VBoxContainer = $VBox/MarginContainer/CostLabel
@onready var separator: Separator = $VBox/MarginContainer/SeparatorContainer/Separator

var info_btn: Button
var _effect_labels: Array = []
var _hovered := false
var _playing := false
var _hover_tween: Tween
var _shake_tween: Tween
var _lock_tween: Tween
var _base_position := Vector2.ZERO
var _base_captured := false
var _locked := false

const HOVER_LIFT := 30.0
const SHAKE_OFFSET := 6.0


const EFFECT_ICONS: Dictionary = {
	"health": "❤️",
	"oxygen": "💨",
	"food": "🥫",
	"water": "💧",
	"panels": "☀️",
	"radiation": "☢️",
	"science": "🔬",
}


func _ready() -> void:
	lock_overlay.color = Color(0, 0, 0, 0.5)
	# Let clicks through so a locked card can still explain why it is locked.
	lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_gui_input)


func setup(card: Dictionary, game: Node) -> void:
	card_data = card
	game_ref = game
	icon_label.text = card.get("icon", "❓")
	name_label.text = card.get("name", "?")
	var cost = card.get("cost_battery", 0)

	energy_label.text = "%d" % -cost
	_update_colors()
	_update_effects()
	_update_lock()


func _update_colors() -> void:
	var accent
	var background
	var category = card_data.get("category", "body")

	match category:
		"body":
			accent = "#eac3c4"
			background = "#342e35"
		"energy":
			accent = "#f2b800"
			background = "#352c18"
		"science":
			accent = "#a47dc9"
			background = "#292436"
		"production":
			accent = "#00b8ff"
			background = "#112c3e"
		"maintenance":
			accent = "#b3b3b3"
			background = "#2c2c33"

	# Card background color
	var background_theme := get_theme_stylebox("panel").duplicate()
	background_theme.bg_color = background
	add_theme_stylebox_override("panel", background_theme)

	# Card Border color
	var border_theme := card_border.get_theme_stylebox("panel").duplicate()
	border_theme.border_color = accent
	card_border.add_theme_stylebox_override("panel", border_theme)

	# separator color
	var separator_theme = separator.get_theme_stylebox("separator").duplicate()
	separator_theme.border_color = accent
	separator.add_theme_stylebox_override("separator", separator_theme)


func _update_effects() -> void:
	# Clear old labels
	for lbl in _effect_labels:
		lbl.queue_free()
	_effect_labels.clear()

	var effects: Dictionary = card_data.get("effects", {})

	for key in effects:
		var val: int = int(effects[key])
		var icon: String = EFFECT_ICONS.get(key, "•")
		_add_effect_label(icon, val)

	# EVA outings add radiation even when the card itself has no radiation effect.
	if bool(card_data.get("is_eva", false)):
		_add_effect_label("☢", Constants.EVA_RADIATION_BONUS)


func _add_effect_label(icon: String, value: int) -> void:
	var lbl := Label.new()
	var prefix = "+" if value > 0 else ""
	lbl.text = "%s %s%d" % [icon, prefix, value]
	lbl.horizontal_alignment = 1
	lbl.add_theme_font_size_override("font_size", 13)
	if value > 0:
		lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	elif value < 0:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		lbl.add_theme_color_override("font_color", Color.WHITE)
	effects_box.add_child(lbl)
	_effect_labels.append(lbl)


func _update_lock() -> void:
	if game_ref == null:
		return
	var reasons = game_ref.card_system.can_play(card_data)
	_set_locked(not reasons.is_empty())


func _set_locked(is_locked: bool) -> void:
	# Skip re-animating when the lock state didn't change, so a single state update
	# only animates the card(s) that actually transition.
	if is_locked == _locked:
		return
	_locked = is_locked
	if _lock_tween != null and _lock_tween.is_valid():
		_lock_tween.kill()

	lock_overlay.visible = true
	var target_modulate := Color(0.6, 0.6, 0.6) if is_locked else Color.WHITE
	var overlay_alpha := 0.5 if is_locked else 0.0

	_lock_tween = create_tween()
	_lock_tween.set_parallel(true)
	_lock_tween.tween_property(self, "modulate", target_modulate, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lock_tween.tween_property(lock_overlay, "color:a", overlay_alpha, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not is_locked:
		_lock_tween.chain().tween_callback(func(): lock_overlay.visible = false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_ref and game_ref.is_day():
			game_ref._on_card_pressed(card_data, self)


func _on_info_pressed() -> void:
	if game_ref == null:
		return
	var desc = card_data.get("lumi_text", "No description available.")
	var card_name = card_data.get("name", "?")
	var icon = card_data.get("icon", "❓")
	game_ref.say_lumi("%s %s\n\n%s" % [icon, card_name, desc], "curious")


func _process(_delta: float) -> void:
	if _playing:
		return
	# Pointer polling is more reliable than mouse_entered/mouse_exited here:
	# Godot emits a one-shot exit when the pointer moves onto a child (e.g.
	# the info button) and never re-fires it, so signals alone can't both
	# keep the lift over children and lower it on a real departure.
	var pointer_over := get_global_rect().has_point(get_global_mouse_position())
	if pointer_over and not _hovered:
		_hovered = true
		_capture_base()
		if _locked:
			_shake()
		else:
			_lift(_base_position.y - HOVER_LIFT)
	elif not pointer_over and _hovered:
		_hovered = false
		if not _locked:
			_lift(_base_position.y)


func _lift(target_y: float) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_BACK)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "position:y", target_y, 0.15)


func _capture_base() -> void:
	if not _base_captured:
		_base_position = position
		_base_captured = true


func _shake() -> void:
	_capture_base()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var x := _base_position.x
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position:x", x + SHAKE_OFFSET, 0.04)
	_shake_tween.tween_property(self, "position:x", x - SHAKE_OFFSET, 0.04)
	_shake_tween.tween_property(self, "position:x", x + SHAKE_OFFSET * 0.5, 0.04)
	_shake_tween.tween_property(self, "position:x", x - SHAKE_OFFSET * 0.5, 0.04)
	_shake_tween.tween_property(self, "position:x", x, 0.04)


func animate_played() -> void:
	# Fade + shrink toward the center so the card visibly leaves the hand.
	_playing = true
	_hovered = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.6, 0.6), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
