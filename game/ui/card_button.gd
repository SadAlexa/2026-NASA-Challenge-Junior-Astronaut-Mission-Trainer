extends Panel
## CardButton — one card in the player's hand.

var card_data: Dictionary = {}
var game_ref: Node = null

@onready var icon_label: Label = $VBox/IconLabel
@onready var name_label: Label = $VBox/NameLabel
@onready var cost_label: Label = $VBox/CostLabel
@onready var lock_overlay: ColorRect = $LockOverlay

var info_btn: Button


func _ready() -> void:
	lock_overlay.color = Color(0, 0, 0, 0.5)
	gui_input.connect(_on_gui_input)
	_create_info_button()


func _create_info_button() -> void:
	info_btn = Button.new()
	info_btn.name = "InfoBtn"
	info_btn.text = "ℹ️"
	info_btn.flat = true
	info_btn.custom_minimum_size = Vector2(28, 28)
	info_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Position: top-right corner
	info_btn.anchor_left = 1.0
	info_btn.anchor_right = 1.0
	info_btn.anchor_top = 0.0
	info_btn.anchor_bottom = 0.0
	info_btn.offset_left = -30.0
	info_btn.offset_top = 2.0
	info_btn.offset_right = -2.0
	info_btn.offset_bottom = 30.0
	info_btn.pressed.connect(_on_info_pressed)
	add_child(info_btn)


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
	
	_update_lock()


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
