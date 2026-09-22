class_name GameNotification
extends Node2D

var message_text: String = ""
var duration: float = 1.5
var _remaining: float = 0.0

static func show_message(parent: Node, text: String, seconds: float = 1.5, at: Vector2 = Vector2(470, 300)) -> GameNotification:
	var notice := load("res://Scene/show_text/Message_show.tscn").instantiate() as GameNotification
	notice.message_text = text
	notice.duration = seconds
	notice.position = at
	parent.add_child(notice)
	return notice

func _ready() -> void:
	$Message.text = message_text
	$Message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remaining = maxf(0.0, duration)

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		$MessagePlayer.play("MessageShow")
		set_process(false)
