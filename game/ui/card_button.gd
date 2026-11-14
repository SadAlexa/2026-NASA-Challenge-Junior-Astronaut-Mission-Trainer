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
	gui_input.connect(_on_gui_input)
	_create_info_button()
	_create_effects_area()


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
	if cost > 0:
		cost_label.text = "⚡%d" % cost
	else:
		cost_label.text = "Free"
	
	_update_effects()
	_update_lock()


func _update_effects() -> void:
	# Clear old labels
	for lbl in _effect_labels:
		lbl.queue_free()
	_effect_labels.clear()
	
	var effects: Dictionary = card_data.get("effects", {})
	
	# Add battery cost as an effect if > 0
	var cost = card_data.get("cost_battery", 0)
	if cost > 0:
		_add_effect_label("⚡", -cost)
	
	for key in effects:
		var val = effects[key]
		var icon = EFFECT_ICONS.get(key, "•")
		_add_effect_label(icon, val)


func _add_effect_label(icon: String, value: int) -> void:
	var lbl := Label.new()
	var sign = "+" if value > 0 else ""
	lbl.text = "%s %s%d" % [icon, sign, value]
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
		if game_ref and game_ref.phase == 1:  # Phase.DAY
			game_ref._on_card_pressed(card_data)


func _on_info_pressed() -> void:
	if game_ref == null:
		return
	var lumi = game_ref.get_node("HUD/LumiBox")
	lumi.visible = true
	var desc = card_data.get("lumi_text", "No description available.")
	var card_name = card_data.get("name", "?")
	var icon = card_data.get("icon", "❓")
	lumi.say("%s %s\n\n%s" % [icon, card_name, desc], "curious")
