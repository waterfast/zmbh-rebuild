class_name CharacterMotor
extends RefCounted
## 不读取输入、全局对象或战斗状态。每个物理帧仅由 Actor 调用一次。

var gravity: float = 980.0
var jump_speed: float = 540.0
var floor_angle: float = deg_to_rad(55.0)
var floor_snap: float = 12.0
var _dash_speed: float = 0.0
var _dash_remaining: float = 0.0

func dash(speed: float, duration: float) -> void:
	_dash_speed = speed
	_dash_remaining = maxf(0.0, duration)

func stop_impulses() -> void:
	_dash_remaining = 0.0

func step(body: CharacterBody2D, direction: float, jump: bool, speed: float, delta: float) -> void:
	# 原地图用旋转 45 度的胶囊拼坡；默认 45 度边界会把接缝判为墙。
	body.floor_max_angle = floor_angle
	body.floor_snap_length = floor_snap
	body.floor_constant_speed = true
	body.velocity.x = clampf(direction, -1.0, 1.0) * speed
	if _dash_remaining > 0.0:
		body.velocity.x = _dash_speed
		_dash_remaining = maxf(0.0, _dash_remaining - delta)
	if jump and body.is_on_floor():
		body.velocity.y = -jump_speed
	elif not body.is_on_floor():
		body.velocity.y += gravity * delta
	if body.is_on_floor() and not jump and not is_zero_approx(body.velocity.x):
		_step_over_seam(body, body.velocity.x * delta)
	body.move_and_slide()

func _step_over_seam(body: CharacterBody2D, distance: float) -> void:
	# 旧关卡的胶囊与填充矩形有亚像素台阶。仅在接地、有顶空且能落到地面时跨缝。
	# 限高 12 像素，不能借此穿墙或越过悬崖。
	var collision := KinematicCollision2D.new()
	if not body.test_move(body.global_transform, Vector2(distance, 0), collision):
		return
	if collision.get_normal().dot(Vector2.UP) >= cos(floor_angle):
		return
	var raised := body.global_transform
	if body.test_move(raised, Vector2(0, -floor_snap)):
		return
	raised.origin.y -= floor_snap
	if body.test_move(raised, Vector2(distance, 0)):
		return
	raised.origin.x += distance
	var landing := KinematicCollision2D.new()
	if not body.test_move(raised, Vector2(0, floor_snap * 2), landing):
		return
	if landing.get_normal().dot(Vector2.UP) < cos(floor_angle):
		return
	var rise := floor_snap - landing.get_travel().y
	if rise > 0 and rise <= floor_snap:
		body.global_position.y -= rise + body.safe_margin
