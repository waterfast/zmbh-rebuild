class_name ShopItemView
extends Node2D

signal purchase_requested(id: StringName, quantity: int)

var profile: PlayerProfile
var offer: Dictionary
var screen: Node2D
var quantity: int = 1
var _details: Control

@onready var _quantity_input: LineEdit = $BG/num_/num_kj/num_

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
	_details = load("res://Scene/UI/InventoryDetails.tscn").instantiate()
	_details.set("profile", profile)
	_details.set("item_definition", profile.catalog.get_definition(StringName(offer.id)))
	_details.set("maximum_position", Vector2(925, 590))
	_details.set("horizontal_reposition", 685.0)
	screen.add_child(_details)

func _hide_details() -> void:
	if is_instance_valid(_details):
		_details.queue_free()
	_details = null

func _exit_tree() -> void:
	_hide_details()
