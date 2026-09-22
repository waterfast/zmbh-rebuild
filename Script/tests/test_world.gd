extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var world := WorldSession.new()
	root.add_child(world)
	for number in range(1, 33):
		check(world.load_level(StringName("level_%d" % number)), "Map loads independently: %d" % number)
		check(world.geometry.get_node_or_null("wall") != null, "Original collision wall is present")
		check(world.geometry.get_node_or_null("BackGround") != null, "Original scenery is present")
		var old_geometry: WeakRef = weakref(world.geometry)
		var actor := Node2D.new()
		world.add_actor(actor, world.definition.spawn_position)
		var old_actor: WeakRef = weakref(actor)
		world.unload_level()
		check(old_geometry.get_ref() == null and old_actor.get_ref() == null, "Leaving releases geometry and actors")
	check(not world.load_level(&"../invalid"), "Rejects paths outside the level catalog")
	var view := ActorView.new()
	root.add_child(view)
	check(view.set_skin(&"tang_sanzang"), "Original hero skin loads")
	view.present(ActionState.State.ATTACK, LocomotionState.State.IDLE, 1.0)
	check(view.body.animation == &"hit1", "Attack is presented without gameplay callbacks")
	check(view.set_skin(&"monkey"), "Original monster skin loads")
	view.present(ActionState.State.FREE, LocomotionState.State.RUN, -1.0)
	check(view.body.animation == &"walk", "Monster movement uses original animation")
	view.free()
	world.free()
	print("WORLD TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
