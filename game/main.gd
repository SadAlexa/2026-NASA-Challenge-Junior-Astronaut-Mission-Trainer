extends Node
## Main — boot scene, loads Game.

func _ready() -> void:
	var game_scene = preload("res://game/game.tscn")
	get_tree().root.call_deferred("add_child", game_scene.instantiate())
	queue_free()
