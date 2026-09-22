class_name SaveStore
extends RefCounted
## 仅接受 JSON 数据。写入完成后才替换正式档，保留上次有效版本。

const VERSION: int = 1
const MAX_BYTES: int = 4 * 1024 * 1024
var path: String
var last_error: String = ""

func _init(save_path: String = "user://profile.json") -> void:
	path = save_path

func save_data(data: Dictionary) -> bool:
	last_error = ""
	var payload := JSON.stringify(data)
	if payload.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "存档超过大小限制"
		return false
	var envelope := {"version": VERSION, "checksum": payload.sha256_text(), "payload": payload}
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "无法创建存档临时文件"
		return false
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "存档写入失败"
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var backup := absolute + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(absolute, backup) != OK:
			last_error = "无法备份原存档"
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, absolute)
		last_error = "无法替换存档"
		return false
	return true

func load_data() -> Dictionary:
	last_error = ""
	var data := _read(path)
	if not data.is_empty():
		return data
	data = _read(path + ".bak")
	if not data.is_empty():
		last_error = "已从备份恢复存档"
	return data

func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

func _read(candidate: String) -> Dictionary:
	if not FileAccess.file_exists(candidate):
		return {}
	var file := FileAccess.open(candidate, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES * 2:
		last_error = "存档不可读或大小异常"
		return {}
	var decoded: Variant = JSON.parse_string(file.get_as_text())
	if not decoded is Dictionary:
		last_error = "存档格式错误"
		return {}
	if decoded.get("version") != VERSION or not decoded.get("payload") is String:
		last_error = "不支持的存档版本"
		return {}
	var payload: String = decoded.payload
	if payload.sha256_text() != decoded.get("checksum", ""):
		last_error = "存档校验失败"
		return {}
	var state: Variant = JSON.parse_string(payload)
	if not state is Dictionary:
		last_error = "存档内容不是数据对象"
		return {}
	return state
