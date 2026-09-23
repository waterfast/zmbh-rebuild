extends SceneTree
## 从老项目导出的 ctex 缓存里批量还原 PNG 贴图。
## 用法：先由 python 生成 manifest（json 数组，每项 {ctex, out}），
## 再运行：godot --headless --path . --script res://tools/extract_ctex.gd

const MANIFEST := "res://tools/ctex_manifest.json"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var ok := 0
	var failed: Array = []
	for entry: Dictionary in entries:
		var texture := load(String(entry.ctex)) as Texture2D
		if texture == null:
			failed.append(entry.ctex)
			continue
		var image := texture.get_image()
		if image == null:
			failed.append(entry.ctex)
			continue
		if image.is_compressed():
			image.decompress()
		var out := String(entry.out)
		var dir := out.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		var err := image.save_png(out)
		if err == OK:
			ok += 1
		else:
			failed.append("%s (错误码 %d)" % [out, err])
	print("EXTRACT ok=%d failed=%d" % [ok, failed.size()])
	for item in failed:
		print("  FAIL ", item)
	DirAccess.remove_absolute("res://tools/ctex_manifest.json")
	quit(0 if failed.is_empty() else 1)
