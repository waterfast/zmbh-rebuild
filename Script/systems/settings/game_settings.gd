class_name GameSettings
extends RefCounted
## 设置是独立数据，不依赖旧 MainSet/Global；场景只读写这个字典。

const DEFAULTS := {
	"background_music": true,
	"sound_effects": true,
	"music_volume": 0.8,
	"sound_volume": 0.8,
	"show_damage_text": true,
	"show_monster_health": true,
	"show_small_health": true,
	"show_role_body": true,
	"show_role_equipment": true,
	"delayed_health_bar": true,
	"auto_pickup": true,
	"pickup_sound": true,
	"show_level_info": true,
	"music_track": 1,
	"menu_background": 1,
}

var values: Dictionary = DEFAULTS.duplicate(true)

func set_value(key: StringName, value: Variant) -> void:
	if not values.has(String(key)):
		return
	values[String(key)] = value

func get_value(key: StringName) -> Variant:
	return values.get(String(key), DEFAULTS.get(String(key)))

func serialize() -> Dictionary:
	return values.duplicate(true)

func restore(data: Dictionary) -> void:
	for key: String in DEFAULTS:
		if data.has(key):
			values[key] = data[key]

