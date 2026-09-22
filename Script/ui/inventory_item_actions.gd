class_name InventoryItemActions
extends Control

signal equip_requested(uid: StringName)
signal sell_requested(uid: StringName)

var uid: StringName
var page: int = 1
var cell_number: int = 1
var allow_sell: bool = false
var _remaining: float = 1.8

func _ready() -> void:
	$VBoxContainer/infor.text = "第%d页第%d格" % [page, cell_number]
	$VBoxContainer/equ.pressed.connect(_equip)
	$VBoxContainer/sell.pressed.connect(_sell)
	$VBoxContainer/sell.disabled = not allow_sell
	if not allow_sell:
		$VBoxContainer/sell.tooltip_text = "强化、法宝、镶嵌和高品质装备的出售确认尚未接入"

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()

func _equip() -> void:
	equip_requested.emit(uid)
	queue_free()

func _sell() -> void:
	if allow_sell:
		sell_requested.emit(uid)
	queue_free()
