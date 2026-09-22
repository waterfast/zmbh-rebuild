class_name SettingsStore
extends RefCounted

var path: String
var settings := GameSettings.new()

func _init(file_path: String = "user://zaomeng_settings.json") -> void:
	path = file_path
	load_data()

func load_data() -> GameSettings:
	if not FileAccess.file_exists(path):
		return settings
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		settings.restore(parsed)
	return settings

func save_data() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(settings.serialize()))
	file.flush()
	return true
