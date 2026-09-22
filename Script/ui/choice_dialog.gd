class_name GameChoiceDialog
extends Control

signal confirmed
signal cancelled

var message_text: String = ""
var confirmation_delay: float = 4.0

func _ready() -> void:
	$TextureRect/bg/ScrollContainer/Text.text = message_text
	if confirmation_delay > 0.0:
		$think_time.start(confirmation_delay)
	else:
		_on_think_time_timeout()

func _process(_delta: float) -> void:
	$TextureRect/bg/qx/calm.text = str(ceili($think_time.time_left)) if not $think_time.is_stopped() else ""

func _on_think_time_timeout() -> void:
	$TextureRect/bg/qd.disabled = false
	$TextureRect/bg/qx/calm.text = ""
	set_process(false)

func _on_qx_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_qd_pressed() -> void:
	if $TextureRect/bg/qd.disabled:
		return
	confirmed.emit()
	queue_free()
