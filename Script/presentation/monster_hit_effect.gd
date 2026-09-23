class_name MonsterHitEffect
extends Node2D
## 原怪物受击场景的两种闪光，动画结束后自行释放。

@onready var _player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_player.play(&"hurt_1" if randi_range(0, 100) < 50 else &"hurt_2")
	_player.animation_finished.connect(func(_name: StringName) -> void: queue_free())
