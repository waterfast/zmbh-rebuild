class_name AfterLevelEnd
extends Node2D
## 原版结算详情窗。仅显示关卡报告中已有的统计，未记录的细分项用横线表示。

var report: LevelReport

func _ready() -> void:
	if report == null:
		return
	_set_label("HBoxContainer/VBoxContainer/TotalHitCount", "累计攻击次数：", report.landed_hits)
	_set_label("HBoxContainer/VBoxContainer/TotalHit", "累计造成伤害：", roundi(report.total_damage_dealt))
	_set_label("HBoxContainer/VBoxContainer/Totalphyhit", "累计造成物伤：", "—")
	_set_label("HBoxContainer/VBoxContainer/Totalmaghit", "累计造成魔伤：", "—")
	_set_label("HBoxContainer/VBoxContainer/TotalRealHit", "累计造成真伤：", "—")
	_set_label("HBoxContainer/VBoxContainer/TotalCritCount", "累计暴击次数：", "—")
	_set_label("HBoxContainer/VBoxContainer2/TotalHurtCount", "累计受伤次数：", report.received_hits)
	_set_label("HBoxContainer/VBoxContainer2/TotalHurt", "累计受到伤害：", roundi(report.total_damage_received))
	_set_label("HBoxContainer/VBoxContainer2/TotalPhyHurt", "累计受到物伤：", "—")
	_set_label("HBoxContainer/VBoxContainer2/TotalMagHurt", "累计受到魔伤：", "—")
	_set_label("HBoxContainer/VBoxContainer2/TotalRealHurt", "累计受到真伤：", "—")
	_set_label("HBoxContainer/VBoxContainer2/TotalMissCount", "累计闪避次数：", "—")
	_set_label("HBoxContainer/VBoxContainer3/TotalCure", "累计治疗数值：", "—")

func _set_label(path: String, prefix: String, value: Variant) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = prefix + str(value)

func _on_glose_pressed() -> void:
	queue_free()
