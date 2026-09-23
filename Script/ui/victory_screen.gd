class_name VictoryScreen
extends Node2D
## 通关结算界面（对应老 Scene/Level/victory.tscn）。
## 数据由 GameApp 采集进 LevelReport，界面只负责显示与按钮意图。

signal map_requested
signal retry_requested

const VICTORY_BGM := "res://assets/Music/level/13_Game_Victory.mp3"
const PING_JIA_SCENE := preload("res://Scene/Level/PingJia.tscn")
const DETAILS_SCENE := preload("res://Scene/Level/AfterLevelEnd.tscn")

var report: LevelReport
var _bgm_player: AudioStreamPlayer

@onready var _begin_time: Label = $GameUseTime/BeginTime
@onready var _end_time: Label = $GameUseTime2/EndTime
@onready var _use_time: Label = $GameUseTime3/UseTIME
@onready var _hp_text: Label = $PlayerLastHp/Hp_text
@onready var _combo_text: Label = $MostLj/MostLj_text
@onready var _grades: AnimationPlayer = $GradesSHow

func _ready() -> void:
	_bgm_player = AudioCue.play(self, VICTORY_BGM)
	_apply_report()
	_grades.play("Show")

func _exit_tree() -> void:
	if is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.stream = null

func _apply_report() -> void:
	if report == null:
		return
	_begin_time.text = "开始时间：" + report.begin_time
	_end_time.text = "结束时间：" + report.end_time
	_use_time.text = "过关用时：" + report.elapsed_text()
	_hp_text.text = "剩余状态：" + str(report.hp_percent) + "%"
	_combo_text.text = "最高连击：" + str(report.maximum_combo)

## 星级由 GradesSHow 动画的方法轨道调用（沿用老项目同名入口）。
func ADDpj() -> void:
	if report == null:
		return
	var stars := PING_JIA_SCENE.instantiate() as PingJia
	stars.position = Vector2(65, 65)
	stars.grade = report.star_rating
	add_child(stars)

func _on_return_map_pressed() -> void:
	map_requested.emit()

func _on_rechallenge_pressed() -> void:
	retry_requested.emit()

func _on_more_informaition_pressed() -> void:
	if get_node_or_null("AfterLevelEnd") != null:
		return
	var details := DETAILS_SCENE.instantiate() as AfterLevelEnd
	details.report = report
	add_child(details)
