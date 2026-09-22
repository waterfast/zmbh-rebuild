class_name CharacterMotor
extends RefCounted
## 不读取输入、全局对象或战斗状态。每个物理帧仅由 Actor 调用一次。

var gravity: float = 980.0
var jump_speed: float = 540.0
var _dash_speed: float = 0.0
var _dash_remaining: float = 0.0

func dash(speed: float, duration: float) -> void:
	_dash_speed = speed
	_dash_remaining = maxf(0.0, duration)

func stop_impulses() -> void:
	_dash_remaining = 0.0

func step(body: CharacterBody2D, direction: float, jump: bool, speed: float, delta: float) -> void:
	body.velocity.x = clampf(direction, -1.0, 1.0) * speed
	if _dash_remaining > 0.0:
		body.velocity.x = _dash_speed
		_dash_remaining = maxf(0.0, _dash_remaining - delta)
	if jump and body.is_on_floor():
		body.velocity.y = -jump_speed
	elif not body.is_on_floor():
		body.velocity.y += gravity * delta
	body.move_and_slide()
