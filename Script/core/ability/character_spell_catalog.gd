class_name CharacterSpellCatalog
extends RefCounted
## 外放法术与角色局部动作分开：释放时刻来自原 Animation 方法轨道。
const SPELLS := {
	"xbz": ["Role2Bullet3", "AddXBZ", [Vector2(80,-50), Vector2(175,-55), Vector2(275,-60)], [1.0,1.3,1.5]],
	"ssp": ["Role3Bullet2", "AddSSP", [Vector2(70,-20),Vector2(145,-30),Vector2(235,-30),Vector2(345,-30)], [1.0,1.6,2.0,2.5]],
	"mmw": ["Role4Bullet3", "AddShovelEffect1", [Vector2(35,-35)], [1.0]],
	"slq": ["Role5Bullet1", "SlqFly", [Vector2(100,-185)], [1.4]],
	"llrd": ["Role5Bullet2", "CallBullet2", [Vector2(0,-35)], [1.0]],
	"lljy": ["Role5Bullet3", "CallBullet3", [Vector2(0,-35)], [1.0]],
	"tllz": ["Role5Bullet4", "CallBullet4", [Vector2(0,-55)], [1.0]],
	"ygth": ["Role5Bullet5", "CallBullet5", [Vector2(0,-35)], [1.0]],
}
static func configure(definition: AbilityDefinition, metadata: Dictionary) -> void:
	var row: Array = SPELLS.get(String(definition.id), [])
	if row.is_empty():
		return
	var effect := SpellBurstEffect.new()
	effect.scene_path = "res://Scene/Combat/Spells/%s.tscn" % row[0]
	effect.offsets = row[2]
	effect.scales = row[3]
	var times: Array = metadata.get("events", {}).get(row[1], [])
	if not times.is_empty():
		definition.release_delay = float(times[0])
	definition.effects = [effect]
	definition.migration_status = "timeline_migrated"
