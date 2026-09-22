class_name ItemCatalog
extends RefCounted

var _capacity: int
var _directory: String
var _cache: Dictionary = {}
var _registered: Dictionary = {}
var _recent: Array[StringName] = []
var disk_reads: int = 0

func _init(capacity: int = 32, directory: String = "res://content/items") -> void:
	_capacity = maxi(1, capacity)
	_directory = directory

func get_definition(id: StringName) -> ItemDefinition:
	if _registered.has(id):
		return _registered[id]
	if _cache.has(id):
		_recent.erase(id)
		_recent.append(id)
		return _cache[id]
	# 禁止存档中的标识逃出定义目录；物品 ID 不是可执行资源路径。
	if not _valid_id(String(id)):
		return null
	var path := _directory.path_join(String(id) + ".json")
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	disk_reads += 1
	if not parsed is Dictionary or parsed.get("id", "") != String(id) or not parsed.get("legacy") is Dictionary:
		return null
	var definition := ItemDefinition.new(parsed)
	while _cache.size() >= _capacity:
		_cache.erase(_recent.pop_front())
	_cache[id] = definition
	_recent.append(id)
	return definition

func register_definition(definition: ItemDefinition) -> bool:
	if definition == null or definition.id.is_empty():
		return false
	_registered[definition.id] = definition
	return true

func registered_ids() -> Array:
	return _registered.keys()

func cached_count() -> int:
	return _cache.size()

func clear() -> void:
	_cache.clear()
	_recent.clear()

func _valid_id(id: String) -> bool:
	if id.is_empty():
		return false
	for character in id:
		if not (character >= "a" and character <= "z" or character >= "A" and character <= "Z" or character >= "0" and character <= "9" or character == "_"):
			return false
	return true
