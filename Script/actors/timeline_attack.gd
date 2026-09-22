class_name TimelineAttack
extends Node2D
## 长条图集内已有位移；根节点固定在释放点，碰撞随原动画轨道移动。

@export var animation_name: StringName
var payload: HitData
var facing: float = 1.0

@onready var hitbox: AnimatedAttackHitbox = $Middle/HitBox
@onready var animation_player: AnimationPlayer = $Middle/BulletPlayers

func _ready() -> void:
	hitbox.payload = payload
	$Middle.scale.x = -1.0 if facing > 0.0 else 1.0
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play(animation_name)
	animation_player.advance(0.0)

func finish() -> void:
	hitbox.cancel()
	queue_free()

func _on_animation_finished(_animation: StringName) -> void:
	finish()
