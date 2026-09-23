class_name ShopItemView
extends Node2D

signal purchase_requested(id: StringName, quantity: int)

const DETAILS_SCENE := preload("res://Scene/UI/InventoryDetails.tscn")

var profile: PlayerProfile
var offer: Dictionary
var screen: Node2D
var quantity: int = 1
var _details: InventoryItemDetails

## 相对 TooltipAnchor 的额外偏移，可在检查器里微调。
@export var tooltip_offset: Vector2 = Vector2.ZERO

@onready var _quantity_input: LineEdit = $BG/num_/num_kj/num_
@onready var _tooltip_anchor: Node2D = $BG/TooltipAnchor

func _ready() -> void:
	var definition := profile.catalog.get_definition(StringName(offer.id))
	$BG/name_.text = definition.metadata().get("名字", offer.id)
	$BG/lh_value.text = str(offer.price)
	var icon: Button = $BG/bgg/Items
	var path := "res://assets/Art/BackPack/AllItems/%s.png" % offer.id
	if ResourceLoader.exists(path):
		icon.icon = load(path)
	icon.mouse_entered.connect(_show_details)
	icon.mouse_exited.connect(_hide_details)

func _on_cure_num_pressed() -> void:
	quantity = mini(quantity + 1, profile.inventory.capacity)
	_quantity_input.text = str(quantity)

func _on_reduce_num_pressed() -> void:
	quantity = maxi(1, quantity - 1)
	_quantity_input.text = str(quantity)

func _on_num__text_changed(value: String) -> void:
	quantity = clampi(int(value), 1, profile.inventory.capacity)

func _on_goumai_pressed() -> void:
	_quantity_input.text = str(quantity)
	purchase_requested.emit(StringName(offer.id), quantity)

func _show_details() -> void:
	if is_instance_valid(_details):
		return
	_details = DETAILS_SCENE.instantiate() as InventoryItemDetails
	_details.profile = profile
	_details.item_definition = profile.catalog.get_definition(StringName(offer.id))
	_details.follow_pointer = false
	_details.top_level = true
	_details.z_index = 200
	_details.panel_resized.connect(_place_details)
	screen.add_child(_details)

func _place_details(size: Vector2) -> void:
	if not is_instance_valid(_details):
		return
	var view_size := get_viewport().get_visible_rect().size
	var anchor := _tooltip_anchor.global_position + tooltip_offset
	_details.global_position = Vector2(
		clampf(anchor.x, 0.0, maxf(0.0, view_size.x - size.x)),
		clampf(anchor.y, 0.0, maxf(0.0, view_size.y - size.y)))

func _hide_details() -> void:
	if is_instance_valid(_details):
		_details.queue_free()
	_details = null

func _exit_tree() -> void:
	_hide_details()
