class_name SpecialEffect
extends AnimatedSprite2D
## 通用特效库：实例化后按名字播放一段动画，播完自动回收。
## 只做表现；治疗、吸附等玩法逻辑由能力系统负责。

var effect_name: StringName = &""
var effect_flip: bool = false
var effect_speed: float = 1.0
var effect_scale: Vector2 = Vector2.ONE

@onready var _player: AnimationPlayer = $SpecialAffect

func _ready() -> void:
	if effect_name.is_empty():
		queue_free()
		return
	_player.speed_scale = effect_speed
	flip_h = effect_flip
	scale = effect_scale
	_player.play(effect_name)
	_player.animation_finished.connect(_on_finished)

func _on_finished(_animation: StringName) -> void:
	queue_free()

## 在 parent 下于 world_position 处播放一段通用特效。
static func spawn(parent: Node, effect: StringName, world_position: Vector2,
		flip: bool = false, speed: float = 1.0, effect_scale: Vector2 = Vector2.ONE,
		attached: bool = false) -> SpecialEffect:
	var scene := load("res://Scene/Effects/SpecialAffect.tscn") as PackedScene
	var node := scene.instantiate() as SpecialEffect
	node.effect_name = effect
	node.effect_flip = flip
	node.effect_speed = speed
	node.effect_scale = effect_scale
	node.top_level = not attached
	node.z_index = 90
	parent.add_child(node)
	if attached and parent is Node2D:
		node.position = (parent as Node2D).to_local(world_position)
	else:
		node.global_position = world_position
	return node
