class_name ArchiveSlotButton
extends TextureButton

signal selected(slot: int)

var slot_number: int = 1
var save_store: SaveStore

func _ready() -> void:
	$MyNum.text = str(slot_number)
	for node in find_children("*", "Control"):
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if save_store == null or not save_store.exists():
		$InfoBox/LevelAndRole.text = "空存档"
		return
	var data := save_store.load_data()
	if data.is_empty() or not data.get("progression") is Dictionary:
		$InfoBox/LevelAndRole.text = "存档无法读取"
		return
	var heroes := {"tang_sanzang": "唐僧", "hero_1": "悟空", "hero_2": "唐僧", "hero_3": "八戒", "hero_4": "沙僧", "hero_5": "白龙"}
	$InfoBox/LevelAndRole.text = "Lv：%d    %s" % [int(data.progression.get("level", 1)), heroes.get(data.get("selected_skin", "tang_sanzang"), "")]
	if FileAccess.file_exists(save_store.path):
		$InfoBox/Time.text = Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(save_store.path)).replace("T", " ")

func _on_pressed() -> void:
	selected.emit(slot_number)
