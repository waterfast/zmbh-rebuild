class_name ShopScreen
extends Node2D

signal closed

const ITEM_SCENE := preload("res://Scene/Shop/Shop_item.tscn")
const CONFIRM_SCENE := preload("res://Scene/show_text/choose_scene.tscn")
const PAGE_SIZE := 9
const CHARACTER_IDS := {&"hero_1": 1, &"tang_sanzang": 2, &"hero_3": 3, &"hero_4": 4, &"hero_5": 5}

var profile: PlayerProfile
var current_page: int = 1
var maximum_page: int = 1
var category: String = "全部"
var search: String = ""
var _catalog: ShopCatalog
var _economy: ItemEconomy
var _rows: Array[ShopItemView] = []
var _rng := RandomNumberGenerator.new()
var _confirmation: Control

func _ready() -> void:
	_catalog = ShopCatalog.new(profile.catalog)
	_economy = ItemEconomy.new(profile.inventory, profile.progression)
	_rng.randomize()
	var names := {1: "悟空", 2: "唐僧", 3: "八戒", 4: "沙僧", 5: "白龙"}
	$BG/BG2/bg_3/Role.text = "角色： " + names[_character_id()]
	profile.progression.changed.connect(_refresh_gold)
	_refresh_gold()
	_refresh()

func _character_id() -> int:
	return CHARACTER_IDS.get(profile.selected_skin, 2)

func _refresh() -> void:
	for row: ShopItemView in _rows:
		row.get_parent().remove_child(row)
		row.queue_free()
	_rows.clear()
	var offers := _catalog.offers(_character_id(), profile.progression.level, category, search)
	maximum_page = maxi(1, ceili(float(offers.size()) / PAGE_SIZE))
	current_page = clampi(current_page, 1, maximum_page)
	$BG/BG2/HBoxContainer/page.text = "%d/%d" % [current_page, maximum_page]
	var start := (current_page - 1) * PAGE_SIZE
	for index in range(mini(PAGE_SIZE, offers.size() - start)):
		var row := ITEM_SCENE.instantiate() as ShopItemView
		row.profile = profile
		row.offer = offers[start + index]
		row.screen = self
		row.position = Vector2(-220 + (index % 3) * 220, -120 + (index / 3) * 100)
		row.purchase_requested.connect(_request_purchase)
		$BG/BG2.add_child(row)
		_rows.append(row)

func _refresh_gold() -> void:
	$BG/lh_bg/lh_.text = str(profile.progression.gold)

func _request_purchase(id: StringName, quantity: int) -> void:
	if is_instance_valid(_confirmation):
		return
	var offer := _catalog.find_offer(_character_id(), profile.progression.level, id)
	if offer.is_empty():
		return
	var display_name: String = profile.catalog.get_definition(id).metadata().get("名字", String(id))
	_confirmation = CONFIRM_SCENE.instantiate()
	_confirmation.message_text = "确定花费%d灵魂购买%d个%s吗？" % [int(offer.price) * quantity, quantity, display_name]
	_confirmation.confirmation_delay = 0.0
	_confirmation.confirmed.connect(_purchase.bind(id, quantity))
	add_child(_confirmation)

func _purchase(id: StringName, quantity: int) -> void:
	var offer := _catalog.find_offer(_character_id(), profile.progression.level, id)
	if offer.is_empty():
		GameNotification.show_message(self, "当前角色无法购买此商品")
		return
	var price := int(offer.price)
	if profile.progression.gold < price * quantity:
		GameNotification.show_message(self, "灵魂不足！")
	elif _economy.buy_many(id, quantity, _rng, price):
		GameNotification.show_message(self, "购买成功！")
	else:
		GameNotification.show_message(self, "背包已满！")

func _change_category(value: String) -> void:
	category = value
	search = ""
	$BG/BG2/HBoxContainer2/LineEdit.text = ""
	current_page = 1
	_refresh()

func _on_total_pressed() -> void:
	_change_category("全部")

func _on_zb_pressed() -> void:
	_change_category("装备")

func _on_dj_pressed() -> void:
	_change_category("道具")

func _on_sz_pressed() -> void:
	_change_category("时装")

func _on_cb_pressed() -> void:
	_change_category("翅膀")

func _on_line_edit_text_changed(value: String) -> void:
	search = value

func _on_qd_pressed() -> void:
	current_page = 1
	_refresh()

func _on_last_pressed() -> void:
	current_page = maxi(1, current_page - 1)
	_refresh()

func _on_next_pressed() -> void:
	current_page = mini(maximum_page, current_page + 1)
	_refresh()

func _on_charge_pressed() -> void:
	GameNotification.show_message(self, "充值渠道已关闭，无法充值，请用灵魂购买商品！")

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _exit_tree() -> void:
	if profile != null and profile.progression.changed.is_connected(_refresh_gold):
		profile.progression.changed.disconnect(_refresh_gold)
