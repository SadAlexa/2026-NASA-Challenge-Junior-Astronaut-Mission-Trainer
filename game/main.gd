extends Node
## Main — boot scene, loads Game.

func _ready() -> void:
	_install_emoji_fallback()
	var game_scene = preload("res://game/game.tscn")
	get_tree().root.call_deferred("add_child", game_scene.instantiate())
	queue_free()


func _install_emoji_fallback() -> void:
	# The Web export has no system emoji font, so emoji would render as tofu
	# boxes. Bundle a monochrome emoji font as a fallback for the default font.
	var emoji_font: Font = load("res://assets/fonts/NotoEmoji.ttf")
	if emoji_font == null:
		push_warning("Main: emoji fallback font is missing")
		return
	var base: Font = ThemeDB.fallback_font
	var fallbacks: Array[Font] = base.fallbacks.duplicate()
	if not fallbacks.has(emoji_font):
		fallbacks.append(emoji_font)
		base.fallbacks = fallbacks
