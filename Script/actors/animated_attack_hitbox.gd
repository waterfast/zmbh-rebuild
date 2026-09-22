class_name AnimatedAttackHitbox
extends Hitbox
## 由动画定义寿命和命中窗口；同一窗口去重，下一窗口允许再次命中。

func _physics_process(_delta: float) -> void:
	# 保持重叠的目标也必须在新一段窗口命中；area_entered 只在首次进入触发。
	for child in get_children():
		if child is CollisionShape2D and not child.disabled:
			for area in get_overlapping_areas():
				_on_area_entered(area)
			break

func begin_hit_window() -> void:
	_hit_targets.clear()
