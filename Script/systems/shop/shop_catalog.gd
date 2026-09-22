class_name ShopCatalog
extends RefCounted

const TYPES := {
	"装备": ["武器", "防具", "饰品", "法宝", "头衔"],
	"道具": ["道具", "消耗品"],
	"时装": ["时装"],
	"翅膀": ["翅膀"],
}
var _data: Dictionary = {}
var _items: ItemCatalog

func _init(items: ItemCatalog) -> void:
	_items = items
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/shops/general.json"))
	if parsed is Dictionary:
		_data = parsed

func offers(character_id: int, level: int, category: String = "全部", search: String = "") -> Array[Dictionary]:
	var candidates: Array = _data.get("common", []).duplicate()
	var character := str(character_id)
	if level >= 50 and _data.get("level_50", {}).has(character):
		candidates.append(_data.level_50[character])
	candidates.append_array(_data.get("characters", {}).get(character, []))
	candidates.append_array(_data.get("free", []))
	var result: Array[Dictionary] = []
	for offer: Dictionary in candidates:
		var definition := _items.get_definition(StringName(offer.id))
		if definition == null:
			continue
		var metadata := definition.metadata()
		if not search.is_empty():
			if String(metadata.get("名字", "")) != search:
				continue
		elif category != "全部" and metadata.get("类型", "") not in TYPES.get(category, []):
			continue
		result.append(offer.duplicate())
	return result

func find_offer(character_id: int, level: int, id: StringName) -> Dictionary:
	for offer: Dictionary in offers(character_id, level):
		if offer.id == String(id):
			return offer
	return {}
