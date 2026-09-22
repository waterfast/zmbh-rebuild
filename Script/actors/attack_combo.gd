class_name AttackCombo
extends RefCounted
## 连击只选择下一份定义，不处理输入、动画或命中。
const ANIMATIONS := {1: [&"hit1",&"hit2",&"hit3",&"hit4"],3: [&"hit1",&"hit2",&"hit3"],4: [&"hit1_1",&"hit2_1",&"hit3_1"],5: [&"hit1",&"hit2",&"hit3",&"hit4",&"hit5"]}
var index := 0
var remaining := 0.0
func tick(delta: float) -> void:
	remaining = maxf(0, remaining - delta)
	if remaining <= 0:
		index = 0
func next(base: AbilityDefinition) -> AbilityDefinition:
	var sequence: Array = ANIMATIONS.get(base.character_id, [])
	if sequence.is_empty():
		return base
	var attack := base.duplicate(true) as AbilityDefinition
	attack.animation = sequence[index % sequence.size()]
	attack = CharacterActionCatalog.configure(attack, base.character_id)
	attack.cooldown = attack.cast_duration
	return attack
func advance(duration: float) -> void:
	index += 1
	remaining = duration + 0.7
func reset() -> void:
	index = 0
	remaining = 0
