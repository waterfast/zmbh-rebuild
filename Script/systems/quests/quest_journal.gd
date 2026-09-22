class_name QuestJournal
extends RefCounted
## 任务只消费业务事件，不扫描节点、轮询背包或持有 UI。

signal changed
var _definitions: Dictionary = {}
var _progress: Dictionary = {}
var _claimed: Dictionary = {}

func register(definition: Dictionary) -> void:
	var id := String(definition.get("id", ""))
	if id.is_empty() or _definitions.has(id):
		return
	_definitions[id] = definition.duplicate(true)
	_progress[id] = 0

func record(event: StringName, target: StringName = &"", count: int = 1) -> void:
	var dirty := false
	for id: String in _definitions:
		var definition: Dictionary = _definitions[id]
		if definition.get("event", "") != String(event):
			continue
		if not String(definition.get("target", "")).is_empty() and definition.target != String(target):
			continue
		var next := mini(int(definition.goal), int(_progress[id]) + maxi(0, count))
		if next != _progress[id]:
			_progress[id] = next
			dirty = true
	if dirty:
		changed.emit()

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in _definitions:
		var entry: Dictionary = _definitions[id].duplicate(true)
		entry["progress"] = _progress[id]
		entry["claimed"] = _claimed.has(id)
		result.append(entry)
	return result

func claim(id: String) -> Dictionary:
	if not _definitions.has(id) or _claimed.has(id):
		return {}
	if int(_progress[id]) < int(_definitions[id].goal):
		return {}
	_claimed[id] = true
	changed.emit()
	return _definitions[id].get("reward", {}).duplicate(true)

func serialize() -> Dictionary:
	return {"progress": _progress.duplicate(), "claimed": _claimed.keys()}

func restore(data: Dictionary) -> bool:
	if not data.get("progress", {}) is Dictionary or not data.get("claimed", []) is Array:
		return false
	var progress: Dictionary = data.get("progress", {})
	for id: Variant in progress:
		if not (progress[id] is float or progress[id] is int):
			return false
	for id: String in _definitions:
		_progress[id] = clampi(int(progress.get(id, 0)), 0, int(_definitions[id].goal))
	_claimed.clear()
	for id: Variant in data.get("claimed", []):
		if id is String and _definitions.has(id) and _progress[id] == int(_definitions[id].goal):
			_claimed[id] = true
	changed.emit()
	return true
