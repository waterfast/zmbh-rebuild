class_name ArchiveStore
extends RefCounted
## 档位一沿用已有新项目存档路径，其他档位独立保存，UI 不拼接文件路径。

const MINIMUM_SLOTS: int = 6
var slot_count: int = MINIMUM_SLOTS
var last_error: String = ""
var _base_path: String
var _index: SaveStore

func _init(base_path: String = "user://zaomeng_profile.json") -> void:
	_base_path = base_path
	_index = SaveStore.new(base_path.get_basename() + "_slots.json")
	if _index.exists():
		var data := _index.load_data()
		if data.get("slot_count") is float or data.get("slot_count") is int:
			slot_count = maxi(MINIMUM_SLOTS, int(data.slot_count))

func store_for(slot: int) -> SaveStore:
	if slot < 1 or slot > slot_count:
		return null
	return SaveStore.new(_base_path if slot == 1 else _base_path.get_basename() + "_slot_%d.json" % slot)

func add_slot() -> bool:
	return _set_slot_count(slot_count + 1)

func remove_last_slot() -> bool:
	if slot_count <= MINIMUM_SLOTS:
		last_error = "最少保留 6 个存档格子！"
		return false
	if store_for(slot_count).exists():
		last_error = "最后一个档位有存档，请先删除该存档。"
		return false
	return _set_slot_count(slot_count - 1)

func _set_slot_count(count: int) -> bool:
	if not _index.save_data({"slot_count": count}):
		last_error = _index.last_error
		return false
	slot_count = count
	last_error = ""
	return true

func delete_slot(slot: int) -> bool:
	var store := store_for(slot)
	if store == null:
		last_error = "找不到该存档号。"
		return false
	for suffix: String in ["", ".bak"]:
		var path := store.path + suffix
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			last_error = "删除存档失败，请检查文件权限。"
			return false
	last_error = ""
	return true
