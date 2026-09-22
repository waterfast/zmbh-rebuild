class_name ActionState
extends RefCounted
## 动作状态互斥；死亡不可退出。移动状态在另一个对象中独立更新。

signal changed(state: int)
enum State { FREE, ATTACK, SKILL, HURT, DEAD }
var current: State = State.FREE
var remaining: float = 0.0
var revision: int = 0

func try_start(state: State, duration: float) -> bool:
	if current != State.FREE:
		return false
	_set_state(state, duration)
	return true

func hurt(duration: float) -> void:
	if current != State.DEAD:
		_set_state(State.HURT, duration)

func die() -> void:
	_set_state(State.DEAD, 0.0)

func tick(delta: float) -> void:
	if current == State.FREE or current == State.DEAD:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining == 0.0:
		_set_state(State.FREE, 0.0)

func can_move() -> bool:
	return current == State.FREE or current == State.ATTACK

func _set_state(state: State, duration: float) -> void:
	revision += 1
	current = state
	remaining = duration
	changed.emit(current)
