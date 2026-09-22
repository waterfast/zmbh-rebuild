class_name BufferedInputSource
extends ActorInputSource
## UI、回放与测试提交同一套意图，按下事件只消费一次。

var movement: float = 0.0
var _jump: bool = false
var _attack: bool = false
var _ability: StringName = &""

func press_jump() -> void:
	_jump = true

func press_attack() -> void:
	_attack = true

func press_ability(id: StringName) -> void:
	_ability = id

func sample(command: ActorCommand) -> void:
	command.movement = clampf(movement, -1.0, 1.0)
	command.jump = _jump
	command.attack = _attack
	command.ability = _ability
	_jump = false
	_attack = false
	_ability = &""
