class_name RoleSpecialEffectView
extends Node2D
## 角色专属特效（紧箍咒/九环圣经/沐浴回春等）的表现层：
## 按名字播放一段动画，播完自动回收；翻转由朝向决定。
## 老脚本里的治疗、吸怪等玩法逻辑由能力系统接管，不在表现层重复。

var effect_name: StringName = &""
var effect_flip: bool = false

@onready var _middle: Node2D = $Middle
@onready var _player: AnimationPlayer = $Middle/SpecialPlayer

func _ready() -> void:
	if effect_name.is_empty():
		queue_free()
		return
	var old_area := get_node_or_null("Middle/Area2D") as Area2D
	if old_area != null:
		old_area.monitoring = false
		old_area.monitorable = false
		old_area.collision_layer = 0
		old_area.collision_mask = 0
	_middle.scale.x = -1.0 if effect_flip else 1.0
	_player.play(effect_name)
	_player.animation_finished.connect(_on_finished)

func _on_finished(_animation: StringName) -> void:
	queue_free()
