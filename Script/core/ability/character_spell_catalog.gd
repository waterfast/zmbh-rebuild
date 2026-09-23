class_name CharacterSpellCatalog
extends RefCounted
## 外放法术与角色局部动作分开：释放时刻来自原 Animation 方法轨道。
const SPELLS := {
	"xbz": ["Role2Bullet3", "AddXBZ", [Vector2(80,-15), Vector2(175,-20), Vector2(275,-25)], [1.0,1.3,1.5]],
	"sgq": ["Role2Bullet5", "Addsgq", [Vector2(35,-20)], [2.0]],
	"jhsj": ["Role2Bullet6", "AddJHSJ2", [Vector2(0,-10)], [1.0]],
	"ssp": ["Role3Bullet2", "AddSSP", [Vector2(70,15),Vector2(145,5),Vector2(235,5),Vector2(345,5)], [1.0,1.6,2.0,2.5]],
	"syzq": ["Role3Bullet1", "CallSYZQ", [Vector2(64,-44)], [1.0]],
	"mmw": ["Role4Bullet3", "AddShovelEffect1", [Vector2(35,0)], [1.0]],
	"jdz": ["Role4Bullet6", "CallJDZ", [Vector2(0,30)], [1.0]],
	"slq": ["Role5Bullet1", "SlqFly", [Vector2(100,-150)], [Vector2(1.4,1.6)]],
	"llrd": ["Role5Bullet2", "CallBullet2", [Vector2(260,180)], [1.5]],
	"lljy": ["Role5Bullet3", "CallBullet3", [Vector2.ZERO], [1.0]],
	"tllz": ["Role5Bullet4", "CallBullet4", [Vector2(0,-20)], [1.4]],
	"ygth": ["Role5Bullet5", "CallBullet5", [Vector2.ZERO], [1.0]],
}
static func configure(definition: AbilityDefinition, metadata: Dictionary) -> void:
	if definition.id == &"hyjj":
		definition.release_delay = float(metadata.get("events", {}).get("call_hyjj", [0.0])[0])
		definition.effects = [HolyScriptureEffect.new()]
		definition.migration_status = "timeline_migrated"
		return
	var row: Array = SPELLS.get(String(definition.id), [])
	if row.is_empty():
		return
	var effect := SpellBurstEffect.new()
	effect.scene_path = "res://Scene/Combat/Spells/%s.tscn" % row[0]
	effect.offsets = row[2]
	effect.scales = row[3]
	effect.reverse_visual = String(definition.id) in ["mmw", "ygth"]
	effect.fixed_visual_facing = -1.0 if String(definition.id) in ["jdz", "llrd", "tllz"] else 0.0
	var times: Array = metadata.get("events", {}).get(row[1], [])
	if not times.is_empty():
		definition.release_delay = float(times[0])
	definition.effects = [effect]
	definition.migration_status = "timeline_migrated"
