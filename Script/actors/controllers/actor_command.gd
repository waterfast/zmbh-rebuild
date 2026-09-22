class_name ActorCommand
extends RefCounted
## 控制器复用命令对象；Actor 只复制值，不保留可变输入对象。

var movement: float = 0.0
var jump: bool = false
var attack: bool = false
var ability: StringName = &""

func clear() -> void:
	movement = 0.0
	jump = false
	attack = false
	ability = &""
