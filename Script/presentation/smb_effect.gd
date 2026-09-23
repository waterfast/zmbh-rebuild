class_name SmbEffectView
extends Node2D
## 水魔爆弹体的表现层：横向飞行并播放爆炸动画，出屏或被调用方回收。
## 老脚本里的命中与伤害由能力系统接管。

const FLIGHT_SPEED: float = 7.0
var effect_flip: bool = false
var flight_lifespan: float = 3.0

@onready var _player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_player.play("smb")
	_player.animation_finished.connect(_on_finished)

func _physics_process(delta: float) -> void:
	position.x += FLIGHT_SPEED * delta * 60.0 * (-1.0 if effect_flip else 1.0)
	flight_lifespan -= delta
	if flight_lifespan <= 0.0:
		queue_free()

func _on_finished(_animation: StringName) -> void:
	queue_free()
