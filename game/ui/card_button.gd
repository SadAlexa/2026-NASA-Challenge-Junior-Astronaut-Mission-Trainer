extends Panel
## CardButton — one card in the player's hand.

var card_data: Dictionary = {}
var game_ref: Node = null

@onready var icon_label: Label = $VBox/IconLabel
@onready var name_label: Label = $VBox/NameLabel
@onready var cost_label: Label = $VBox/CostLabel
@onready var lock_overlay: ColorRect = $LockOverlay

var info_btn: Button
var effects_box: VBoxContainer
var _effect_labels: Array = []
var cost_label_top: Label


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
	_create_info_button()
	_create_effects_area()
	_create_cost_label()


func _create_info_button() -> void:
	info_btn = Button.new()
	info_btn.name = "InfoBtn"
	info_btn.text = "ℹ️"
	info_btn.flat = true
	info_btn.custom_minimum_size = Vector2(28, 28)
	info_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	info_btn.anchor_left = 1.0
	info_btn.anchor_right = 1.0
	info_btn.offset_left = -30.0
	info_btn.offset_top = 2.0
	info_btn.offset_right = -2.0
	info_btn.offset_bottom = 30.0
	info_btn.pressed.connect(_on_info_pressed)
	add_child(info_btn)


func _create_cost_label() -> void:
	cost_label_top = Label.new()
	cost_label_top.name = "CostLabelTop"
	cost_label_top.add_theme_font_size_override("font_size", 14)
	cost_label_top.offset_left = 4.0
	cost_label_top.offset_top = 2.0
	cost_label_top.offset_right = 50.0
	cost_label_top.offset_bottom = 22.0
	add_child(cost_label_top)
	# Hide the original in VBox
	cost_label.visible = false


func _create_effects_area() -> void:
	effects_box = VBoxContainer.new()
	effects_box.name = "EffectsBox"
	effects_box.anchor_top = 1.0
	effects_box.anchor_bottom = 1.0
	effects_box.offset_top = -80.0
	effects_box.offset_left = 4.0
	effects_box.offset_right = -4.0
	effects_box.offset_bottom = -4.0
	effects_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(effects_box)


func setup(card: Dictionary, game: Node) -> void:
	card_data = card
	game_ref = game
	icon_label.text = card.get("icon", "❓")
	name_label.text = card.get("name", "?")
	
	var cost = card.get("cost_battery", 0)
	cost_label_top.text = "⚡%d" % cost
	
	_update_effects()
	_update_lock()


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
	lock_overlay.visible = not reasons.is_empty()
	modulate = Color(0.6, 0.6, 0.6) if lock_overlay.visible else Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_ref and game_ref.is_day():
			game_ref._on_card_pressed(card_data)


func _on_info_pressed() -> void:
	if game_ref == null:
		return
	var desc = card_data.get("lumi_text", "No description available.")
	var card_name = card_data.get("name", "?")
	var icon = card_data.get("icon", "❓")
	game_ref.say_lumi("%s %s\n\n%s" % [icon, card_name, desc], "curious")
