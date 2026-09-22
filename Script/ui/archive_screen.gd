class_name ArchiveScreen
extends Node2D

signal profile_selected(profile: PlayerProfile, store: SaveStore)
signal new_profile_requested(profile: PlayerProfile, store: SaveStore)
signal closed

const SLOT_SCENE := preload("res://Scene/OtherScene/BacisArButton.tscn")
const CHOICE_SCENE := preload("res://Scene/show_text/choose_scene.tscn")
var archives := ArchiveStore.new()
var _confirmation: GameChoiceDialog
var require_character_selection: bool = false

func _ready() -> void:
	_refresh_slots()

func _refresh_slots() -> void:
	var grid := $ScrollContainer/AllAr
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for slot in range(1, archives.slot_count + 1):
		var button := SLOT_SCENE.instantiate() as ArchiveSlotButton
		button.slot_number = slot
		button.save_store = archives.store_for(slot)
		button.selected.connect(_select_slot)
		grid.add_child(button)

func _select_slot(slot: int) -> void:
	var store := archives.store_for(slot)
	if store == null:
		return
	var profile := PlayerProfile.new()
	var has_saved_profile := store.exists()
	if has_saved_profile:
		if not profile.restore(store.load_data()):
			GameNotification.show_message(self, "存档无法读取，原文件已保留。", 2.0)
			return
	else:
		profile.start_new()
	if not has_saved_profile and require_character_selection:
		new_profile_requested.emit(profile, store)
	else:
		profile_selected.emit(profile, store)

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _on_addcd_pressed() -> void:
	if archives.add_slot():
		_refresh_slots()
	else:
		GameNotification.show_message(self, archives.last_error)

func _on_removecd_pressed() -> void:
	if archives.remove_last_slot():
		_refresh_slots()
	else:
		GameNotification.show_message(self, archives.last_error)

func _on_delete_pressed() -> void:
	if is_instance_valid(_confirmation):
		return
	var text: String = $background/cd_number.text
	var slot := int(text)
	if not text.is_valid_int() or archives.store_for(slot) == null:
		GameNotification.show_message(self, "找不到存档信息，请正确输入存档号。")
		return
	_confirmation = CHOICE_SCENE.instantiate()
	_confirmation.message_text = "确定要删除存档 %d 吗？\n（删除后无法恢复！）" % slot
	_confirmation.confirmed.connect(_delete_confirmed.bind(slot))
	add_child(_confirmation)

func _delete_confirmed(slot: int) -> void:
	if archives.delete_slot(slot):
		_refresh_slots()
		GameNotification.show_message(self, "存档 %d 已重置为初始状态。" % slot)
	else:
		GameNotification.show_message(self, archives.last_error)
