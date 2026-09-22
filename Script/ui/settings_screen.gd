class_name SettingsScreen
extends Node2D
## 原版 GameSet 场景的新版数据适配器；按钮路径与视觉节点保持原样。

signal closed

var store: SettingsStore

@onready var _music_toggle: Button = $Bg/BGColor/VBoxContainer/GameMusicTitle/GMOpenOrClose
@onready var _sound_toggle: Button = $Bg/BGColor/VBoxContainer/GameMusicTitle2/GM2OpenOrClose
@onready var _music_slider: HSlider = $Bg/BGColor/VBoxContainer/GameMusicFB/HSlider
@onready var _sound_slider: HSlider = $Bg/BGColor/VBoxContainer/GameMusicFB2/GM2Slider
@onready var _damage_toggle: Button = $Bg/BGColor/VBoxContainer/MonsterBloodText/MBTOpenOrClose
@onready var _health_toggle: Button = $Bg/BGColor/VBoxContainer/MonsterBloodShow/MBSOpenOrClose
@onready var _small_health_toggle: Button = $Bg/BGColor/VBoxContainer/MonsterBloodShow2/MBS2OpenOrClose
@onready var _equipment_toggle: Button = $Bg/BGColor/VBoxContainer/RoleEQ/ShowClose2
@onready var _body_toggle: Button = $Bg/BGColor/VBoxContainer2/RoleBody/ShowClose
@onready var _delay_toggle: Button = $Bg/BGColor/VBoxContainer2/HpBloodDelay/YesORNot
@onready var _pickup_toggle: Button = $Bg/BGColor/VBoxContainer2/AutomaticallyPickUpItems/YesOrNots
@onready var _pickup_sound_toggle: Button = $Bg/BGColor/VBoxContainer2/AutomaticallyPickUpItems2/Ornot
@onready var _level_toggle: Button = $Bg/BGColor/VBoxContainer2/LevelInfo/openClose

func setup(settings_store: SettingsStore) -> void:
	store = settings_store
	_refresh()

func _ready() -> void:
	if store == null:
		store = SettingsStore.new()
	_refresh()

func _refresh() -> void:
	if not is_node_ready() or store == null:
		return
	var data := store.settings
	_music_toggle.text = _state(data.get_value(&"background_music"))
	_sound_toggle.text = _state(data.get_value(&"sound_effects"))
	_music_slider.value = float(data.get_value(&"music_volume"))
	_sound_slider.value = float(data.get_value(&"sound_volume"))
	_damage_toggle.text = _state(data.get_value(&"show_damage_text"))
	_health_toggle.text = _state(data.get_value(&"show_monster_health"))
	_small_health_toggle.text = _state(data.get_value(&"show_small_health"))
	_equipment_toggle.text = _state(data.get_value(&"show_role_equipment"))
	_body_toggle.text = _state(data.get_value(&"show_role_body"))
	_delay_toggle.text = _state(data.get_value(&"delayed_health_bar"))
	_pickup_toggle.text = _state(data.get_value(&"auto_pickup"))
	_pickup_sound_toggle.text = _state(data.get_value(&"pickup_sound"))
	_level_toggle.text = _state(data.get_value(&"show_level_info"))

func _state(value: Variant) -> String:
	return "开启中" if bool(value) else "关闭中"

func _toggle(key: StringName) -> void:
	store.settings.set_value(key, not bool(store.settings.get_value(key)))
	store.save_data()
	_refresh()

func _on_gm_open_or_close_pressed() -> void: _toggle(&"background_music")
func _on_gm_2_open_or_close_pressed() -> void: _toggle(&"sound_effects")
func _on_h_slider_value_changed(value: float) -> void:
	store.settings.set_value(&"music_volume", value)
	store.save_data()
func _on_gm_2_slider_value_changed(value: float) -> void:
	store.settings.set_value(&"sound_volume", value)
	store.save_data()
func _on_mbt_open_or_close_pressed() -> void: _toggle(&"show_damage_text")
func _on_mbs_open_or_close_pressed() -> void: _toggle(&"show_monster_health")
func _on_mbs_2_open_or_close_pressed() -> void: _toggle(&"show_small_health")
func _on_show_close_2_pressed() -> void: _toggle(&"show_role_equipment")
func _on_show_close_pressed() -> void: _toggle(&"show_role_body")
func _on_yes_or_not_pressed() -> void: _toggle(&"delayed_health_bar")
func _on_yes_or_nots_pressed() -> void: _toggle(&"auto_pickup")
func _on_ornot_pressed() -> void: _toggle(&"pickup_sound")
func _on_open_close_pressed() -> void: _toggle(&"show_level_info")

func _on_g_mzm_1_pressed() -> void: _set_number(&"music_track", 1)
func _on_g_mzm_2_pressed() -> void: _set_number(&"music_track", 2)
func _on_g_mzm_3_pressed() -> void: _set_number(&"music_track", 3)
func _on_g_mzm_4_pressed() -> void: _set_number(&"music_track", 4)
func _on_gm_2_zm_1_pressed() -> void: _set_number(&"menu_background", 1)
func _on_gm_2_zm_2_pressed() -> void: _set_number(&"menu_background", 2)
func _on_gm_2_zm_3_pressed() -> void: _set_number(&"menu_background", 3)

func _set_number(key: StringName, value: int) -> void:
	store.settings.set_value(key, value)
	store.save_data()

func _on_return_pressed() -> void:
	closed.emit()
	queue_free()
