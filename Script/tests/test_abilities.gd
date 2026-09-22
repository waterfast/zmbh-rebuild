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
	_test_attributes()
	_test_damage()
	_test_passives_and_buffs()
	_test_catalog()
	await _test_effects()
	print("ABILITY TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_attributes() -> void:
	var definition := StatDefinition.new()
	var combatant := Combatant.new(definition, 1)
	var mana := AbilityController.new(100.0)
	mana.bind_stats(combatant.stats)
	check(combatant.stats.value(&"attack") == 20.0, "Base stat lookup")
	combatant.stats.set_modifier(&"weapon", &"attack", 10.0, 0.2)
	check(is_equal_approx(combatant.stats.value(&"attack"), 36.0), "Cached stat invalidates when changed")
	combatant.stats.set_modifier(&"armor", &"max_hp", 50.0)
	check(combatant.health.maximum == 150.0 and combatant.health.current == 100.0, "Increasing maximum does not heal for free")
	combatant.health.heal(50.0)
	combatant.stats.remove_source(&"armor")
	check(combatant.health.maximum == 100.0 and combatant.health.current == 100.0, "Removing health gear clamps current health")
	combatant.stats.set_modifier(&"mana", &"max_mp", -70.0)
	check(mana.mp == 30.0 and mana.maximum_mp == 30.0, "MP maximum tracks stat modifiers")
	combatant.stats.remove_source(&"mana")
	check(mana.mp == 30.0 and mana.maximum_mp == 100.0, "Increasing MP maximum does not restore mana")
	combatant.stats.set_modifier(&"regen", &"mp_regen", 10.0)
	mana.tick(2.0)
	check(mana.mp == 50.0, "MP regeneration follows elapsed time")
	combatant.stats.remove_source(&"weapon")
	check(combatant.stats.value(&"attack") == 20.0 and definition.attack == 20.0, "Removing modifiers restores cached base without changing shared definition")
	combatant.health.damage(1000.0)
	combatant.stats.set_modifier(&"armor", &"max_hp", 50.0)
	check(not combatant.health.is_alive(), "Changing maximum health cannot revive dead actors")

func _test_damage() -> void:
	var definition := StatDefinition.new()
	var attacker := Combatant.new(definition, 1)
	var target := Combatant.new(definition, 2)
	var hit := HitData.from_attacker(attacker, 20.0)
	check(CombatResolver.resolve(hit, target) == 19.0, "Original monster defense uses a ratio and integer truncation")
	target.stats.set_modifier(&"magic", &"magic_defense", 8.0)
	hit.damage_type = HitData.DamageType.MAGIC
	hit.magic_penetration = 3.0
	check(CombatResolver.resolve(hit, target) == 19.0, "Magic defense and penetration")
	target.stats.set_modifier(&"mitigation", &"damage_reduction", 0.5)
	hit.damage_type = HitData.DamageType.TRUE
	check(CombatResolver.resolve(hit, target) == 10.0, "True damage bypasses defense but preserves final modifiers")
	hit.damage_type = HitData.DamageType.PHYSICAL
	hit.critical_chance = 1000000000.0
	hit.critical_multiplier = 2.0
	check(CombatResolver.resolve(hit, target) == 19.0, "Critical damage applies before defense and reduction")
	target.stats.set_modifier(&"dodge", &"dodge_chance", 1000000000.0)
	check(CombatResolver.resolve(hit, target) == 0.0, "Guaranteed dodge avoids damage")
	hit.accuracy = 1000000000.0
	check(CombatResolver.resolve(hit, target) == 19.0, "Accuracy offsets dodge")
	target.health.heal(100.0)
	hit.critical_chance = 0.0
	hit.ignores_defense = true
	check(CombatResolver.resolve(hit, target) == 10.0, "Ignore defense still obeys final reduction")
	check(CombatResolver.resolve(hit, attacker) == 0.0, "Damage prevents friendly fire")

func _test_passives_and_buffs() -> void:
	var definition := StatDefinition.new()
	var attacker := Combatant.new(definition, 1)
	var target := Combatant.new(definition, 2)
	attacker.health.damage(50.0)
	var passive := PassiveDefinition.new()
	passive.id = &"leech"
	passive.lifesteal = 0.5
	passive.cooldown = 1.0
	attacker.passives.grant(passive, &"weapon")
	var hit := HitData.from_attacker(attacker, 13.0)
	CombatResolver.resolve(hit, target)
	check(attacker.health.current == 56.0, "Passive receives actual damage for lifesteal")
	CombatResolver.resolve(hit, target)
	check(attacker.health.current == 56.0, "Passive cooldown prevents repeated triggers")
	attacker.tick(1.0)
	CombatResolver.resolve(hit, target)
	check(attacker.health.current == 62.0, "Passive cooldown expires through combatant tick")
	attacker.passives.grant(passive, &"ring")
	attacker.passives.remove_source(&"weapon")
	CombatResolver.resolve(hit, target)
	check(attacker.health.current == 68.0, "Passive removal preserves another equipment source")
	attacker.passives.remove_source(&"ring")
	CombatResolver.resolve(hit, target)
	check(attacker.health.current == 68.0, "Removed passives stop triggering")
	var armor := BuffDefinition.new()
	armor.id = &"armor"
	armor.duration = 1.0
	armor.flat_modifiers = {"defense": 10.0}
	target.buffs.add(armor, &"spell")
	check(target.stats.value(&"defense") == 13.0, "Buff applies scoped stat modifiers")
	target.buffs.add(armor, &"spell")
	check(target.stats.value(&"defense") == 13.0, "Refreshing buff does not duplicate modifiers")
	target.tick(1.0)
	check(target.stats.value(&"defense") == 3.0, "Buff expiry removes its stat modifiers")
	var regen := BuffDefinition.new()
	regen.id = &"regen"
	regen.duration = 3.0
	regen.tick_interval = 1.0
	regen.tick_heal = 2.0
	target.buffs.add(regen, &"spell")
	var before := target.health.current
	target.tick(5.0)
	check(target.health.current == before + 6.0, "Long frame catches up regeneration only through expiry")
	var vulnerable := Combatant.new(definition, 2)
	vulnerable.health.damage(99.0)
	vulnerable.buffs.add(PoisonBuff.new(), &"poison", hit)
	vulnerable.tick(5.0)
	check(not vulnerable.health.is_alive() and not vulnerable.buffs.has_tag(&"poison"), "DOT death safely clears active buffs while settling pulses")
	var weak_attacker: WeakRef = weakref(attacker)
	attacker = null
	check(weak_attacker.get_ref() == null, "Passive owner and hit payload do not retain combatants")

func _test_catalog() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.ids().size() == 50, "Legacy metadata contains all five characters and 50 skills")
	var ability := catalog.resolve(&"tjgl")
	check(ability.display_name == "天降甘露" and ability.mp_cost == 35.0, "Legacy identity and first-level mana cost preserved")
	check(ability == catalog.resolve(&"tjgl"), "Catalog reuses a live definition")
	var weak_ability: WeakRef = weakref(ability)
	ability = null
	check(weak_ability.get_ref() == null, "Catalog weak cache releases unused ability definitions")
	var controller := AbilityController.new(100.0)
	controller.grant(catalog.resolve(&"shy"), &"character")
	var action := ActionState.new()
	check(not controller.try_cast(&"shy", action) and controller.mp == 100.0, "Metadata-only abilities cannot consume mana or start actions")
	var magic := RelicAbilityRegistry.definition_for(&"dshl")
	controller.grant(magic, &"relic:item_1", &"magic_weapon", &"magic_weapon")
	var magic_action := ActionState.new()
	var magic_request := SkillTriggerRequest.new(magic.id, &"magic_weapon", &"relic:item_1", magic_action)
	check(controller.try_trigger(magic_request) and magic_action.current == ActionState.State.SKILL, "角色、法宝和装备共享统一技能触发请求")
	check(controller.has_category(magic.id, &"magic_weapon"), "技能授予保留法宝来源类别")
	controller.remove_source(&"relic:item_1")
	check(not controller.has_ability(magic.id), "卸下法宝只移除法宝来源")
	var prototypes := 0
	for id: String in catalog.ids():
		var entry := catalog.resolve(StringName(id))
		if not entry.effects.is_empty():
			prototypes += 1
	check(prototypes == 14, "Migrated effect compositions load for all executable prototypes")
	check(catalog.resolve(&"missing") == null, "Unknown skill IDs return no definition")
	var content := ContentRegistry.new()
	var registered_relic := content.resolve_ability(&"relic_dshl_flame", &"magic_weapon")
	check(registered_relic != null and registered_relic.category == &"magic_weapon", "会话内容注册层可解析独立法宝技能")

func _test_effects() -> void:
	var baseline_nodes := get_node_count()
	var scene := Node2D.new()
	root.add_child(scene)
	var actor: CombatActor = load("res://actors/actor.tscn").instantiate()
	actor.definition = StatDefinition.new()
	scene.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	actor.combatant.health.damage(50.0)
	check(AbilityExecutor.execute(HealSelfAbility.new(), actor), "Heal effect executes through common ability entry")
	check(actor.combatant.health.current == 78.0, "Heal effect combines max and missing health fractions")
	var catalog := AbilityCatalog.new()
	AbilityExecutor.execute(catalog.resolve(&"sd"), actor)
	check(actor.combatant.buffs.has_tag(&"super_armor"), "Self buff effect applies armor")
	actor.combatant.tick(1.0)
	check(actor.combatant.health.current == 81.0, "Self buff healing runs through combatant tick")
	AbilityExecutor.execute(HeavyStrikeAbility.new(), actor)
	var melee_found := false
	for child in actor.get_children():
		if child is Hitbox:
			melee_found = true
	check(melee_found, "Melee effect creates a real actor-owned collision node")
	AbilityExecutor.execute(IceDragonWaveAbility.new(), actor)
	var projectile_found := false
	for child in scene.get_children():
		if child is CombatProjectile:
			projectile_found = true
	check(projectile_found, "Projectile effect creates a level-owned projectile")
	AbilityExecutor.execute(QuickDashAbility.new(), actor)
	check(actor.has_method("request_dash"), "Dash effect uses actor movement interface")
	scene.queue_free()
	await process_frame
	await process_frame
	check(get_node_count() == baseline_nodes, "All spawned effect nodes release with the owning scene")
