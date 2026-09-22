class_name AnimatedAttackHitbox
extends Hitbox
## 由动画定义寿命和命中窗口；同一窗口去重，下一窗口允许再次命中。

func _physics_process(_delta: float) -> void:
	pass

func begin_hit_window() -> void:
	_hit_targets.clear()
