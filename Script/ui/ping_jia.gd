class_name PingJia
extends Node2D
## 关卡星级评价展示（对应老 Scene/OtherScene/ping_jia.tscn）。

var grade: int = 1

@onready var _texture_rect: TextureRect = $TextureRect
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	var path := "res://assets/Art/Level/Challenge/ui_beizhan_pj_%d.png" % clampi(grade, 1, 5)
	if ResourceLoader.exists(path):
		_texture_rect.texture = load(path) as Texture2D
	_animation_player.play("show")
