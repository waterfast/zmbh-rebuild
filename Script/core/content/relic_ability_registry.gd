class_name RelicAbilityRegistry
extends RefCounted
## 法宝内容按法宝 ID 独立注册；法宝定义仍在各自 JSON，避免集中式装备脚本。

const ITEM_TO_ABILITY := {
	&"dshl": &"relic_dshl_flame",
	&"tsgj": &"relic_tsgj_swords",
	&"qyj": &"relic_qyj_sword_array",
	&"xhhl": &"relic_xhhl_pull",
	&"zjfyd": &"relic_zjfyd_shield",
	&"zjhl": &"relic_zjhl_gourd",
	&"kyl": &"relic_kyl_chain",
	&"lsys": &"relic_lsys_lotus",
	&"bsyj": &"relic_bsyj_ice",
	&"jcld": &"relic_jcld_thunder",
	&"xhmt": &"relic_xhmt_mirror",
	&"nmwdnh": &"relic_nmwdnh_void",
	&"zlwdah": &"relic_zlwdah_dragon",
}

static func ids_for_item(item_id: StringName) -> Array[StringName]:
	var id: StringName = ITEM_TO_ABILITY.get(item_id, &"")
	return [] if id.is_empty() else [id]

static func ids() -> Array:
	return ITEM_TO_ABILITY.values()

static func item_ids() -> Array[StringName]:
	return ITEM_TO_ABILITY.keys()

static func definition_for(item_id: StringName) -> AbilityDefinition:
	var ability_id: StringName = ITEM_TO_ABILITY.get(item_id, &"")
	if ability_id.is_empty():
		return null
	var definition := AbilityDefinition.new()
	definition.id = ability_id
	definition.category = &"magic_weapon"
	definition.source_kind = &"magic_weapon"
	definition.display_name = String(item_id)
	definition.mp_cost = 20.0
	definition.cooldown = 4.0
	definition.cast_duration = 0.35
	definition.migration_status = "implemented"
	var effect: AbilityEffect
	if item_id in [&"xhhl", &"nmwdnh"]:
		var dash := DashEffect.new()
		dash.speed = 280.0
		dash.duration = 0.35
		effect = dash
	elif item_id == &"zjfyd":
		var buff := BuffDefinition.new()
		buff.id = &"relic_invincible"
		buff.tag = "super_armor"
		buff.duration = 4.0
		var self_buff := SelfBuffEffect.new()
		self_buff.buff = buff
		effect = self_buff
	elif item_id in [&"qyj", &"tsgj", &"jcld", &"zlwdah"]:
		var projectile := ProjectileEffect.new()
		projectile.power_scale = 1.35
		projectile.speed = 480.0
		projectile.lifetime = 1.5
		effect = projectile
	else:
		var melee := MeleeEffect.new()
		melee.power_scale = 1.25
		melee.lifetime = 0.3
		effect = melee
	definition.effects = [effect]
	return definition
