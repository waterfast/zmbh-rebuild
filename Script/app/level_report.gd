class_name LevelReport
extends RefCounted
## 关卡结算数据：由 GameApp 采集，交给 VictoryScreen 显示，双方不互相依赖场景树。

var begin_time: String = ""
var end_time: String = ""
var elapsed_seconds: int = 0
var hp_percent: float = 100.0
var maximum_combo: int = 0
var received_hits: int = 0
var total_damage_received: float = 0.0
var total_damage_dealt: float = 0.0
var landed_hits: int = 0
var star_rating: int = 1

func elapsed_text() -> String:
	var hours := elapsed_seconds / 3600
	var minutes := elapsed_seconds % 3600 / 60
	var seconds := elapsed_seconds - hours * 3600 - minutes * 60
	return "%d 小时 %d 分钟 %d 秒" % [hours, minutes, seconds]
