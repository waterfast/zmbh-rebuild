class_name SkillCutInPresenter
extends RefCounted
## 技能特写是表现层服务，技能定义只提供 ID；所有角色技能共用同一生命周期。

static func present(actor: Node2D, definition: AbilityDefinition) -> void:
	if actor == null or definition == null:
		return
	var color := _color_for(definition.character_id)
	var ring := Line2D.new()
	ring.name = "SkillVfx_%s" % definition.id
	ring.width = 3.0
	ring.default_color = color
	ring.position = Vector2(actor.facing * 34.0, -24.0)
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * 12.0)
	actor.add_child(ring)
	var ring_tween := actor.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.24).from(Vector2(0.35, 0.35))
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.24)
	ring_tween.set_parallel(false)
	ring_tween.tween_callback(ring.queue_free)
	var icon_id := definition.legacy_id if not definition.legacy_id.is_empty() else definition.id
	var path := "res://assets/Art/Skill/SkillIcon/%s.png" % icon_id
	if not ResourceLoader.exists(path):
		path = "res://assets/Art/Skill/LittleSkillIcon/%s.png" % icon_id
	if not ResourceLoader.exists(path):
		return
	var sprite := Sprite2D.new()
	sprite.name = "SkillCutIn_%s" % definition.id
	sprite.texture = load(path)
	sprite.position = Vector2(actor.facing * 36.0, -92.0)
	sprite.scale = Vector2(0.7, 0.7)
	sprite.modulate = _color_for(definition.character_id, 0.0)
	actor.add_child(sprite)
	var tween := actor.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.06)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.1).from(Vector2(0.45, 0.45))
	tween.set_parallel(false)
	tween.tween_interval(0.18)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.tween_callback(sprite.queue_free)

static func _color_for(character_id: int, alpha: float = 1.0) -> Color:
	var colors := {
		1: Color(0.42, 0.78, 1.0, alpha),
		2: Color(1.0, 0.86, 0.38, alpha),
		3: Color(1.0, 0.5, 0.28, alpha),
		4: Color(0.62, 1.0, 0.48, alpha),
		5: Color(0.82, 0.52, 1.0, alpha),
	}
	return colors.get(character_id, Color(1, 1, 1, alpha))
