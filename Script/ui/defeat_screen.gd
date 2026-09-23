class_name DefeatScreen
extends Node2D
## 角色死亡后的战败界面（对应老 Scene/Level/defeat.tscn）。
## 只负责表现与按钮意图：返回地图、重新挑战由 GameApp 决定。

signal map_requested
signal retry_requested
signal dark_power_requested
signal permanent_refusal_requested
signal reward_requested

const DEFEAT_BGM := "res://assets/Music/level/12_over.mp3"
## 老项目战败时的挑衅台词（去掉了「接受黑暗力量」的作弊分支）。
const TAUNTS := [
	"挑战失败了？放弃吧，接受我的黑暗力量，这样你才能更强！",
	"不是吧，不是吧，这都打不过，我可以给你无穷的力量，接受我吧！",
	"坚持正义有用吗？你看，这么多人都已经接受我的黑暗力量了，你再努力可能像我一样强大吗？！",
	"接受我的力量吧，我可以让你天下无敌！！",
]
const REFUSAL_LINES := [
	"没关系的，你迟早会需要我，哈哈哈哈！",
	"哦？你可不要后悔哦！",
	"好吧好吧，我会等着你的~",
	"没有人可以拒绝我的力量，你也不可能！！马上，你就会选择我，哈哈哈哈！！！",
	"不不不，你需要的，也许下一次，你就会接受我。",
	"嗯？坚守正义吗？哈哈哈哈！！！正义给你带来了什么呢？不要搞笑了，好吗？",
	"假惺惺的，你真的是正义吗？",
	"没有我，你不可能通关的，好好想想哦！~",
	"哦吼？呵呵！~",
	"装模做样，不敢永远拒绝吗？那还装什么呢？接受我吧！",
]
const PERMANENT_LINES := [
	"好吧，好吧，看来你还是有点骨气的，祝你好运喽~",
	"？你真的敢！？下个存档再见喽！~",
	"躲得了一时，躲不了一世，你迟早会接受我，无论什么原因！",
]
const ACCEPT_LINES := [
	"没错，没错，就是这样，我们是无敌的！！",
	"明智的选择，让我们来教训一下这些弱小的东西吧！！",
	"哈哈哈哈，我就知道你会接受我，我们是一类人，不是吗？",
	"对了，太对了，我来助你平定八荒！",
	"力量是属于强者的，而你，就是强者！",
]

var permanent_refusal: bool = false
var reward_claimed: bool = false
var _bgm_player: AudioStreamPlayer

@onready var _text: Label = $text
@onready var _player: AnimationPlayer = $player

func _ready() -> void:
	_text.text = "" if permanent_refusal else TAUNTS.pick_random()
	_text.visible = not permanent_refusal
	$"text/box_1".icon = load("res://assets/Art/BackPack/AllItems/xczg.png")
	_player.play("dh_1")
	_bgm_player = AudioCue.play(self, DEFEAT_BGM)

func _exit_tree() -> void:
	if is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.stream = null

func _on_return_map_pressed() -> void:
	map_requested.emit()

func _on_re_challenge_pressed() -> void:
	retry_requested.emit()

func _on_js_pressed() -> void:
	_text.text = ACCEPT_LINES.pick_random()
	_player.play("dh_2")
	dark_power_requested.emit()

func _on_jj_pressed() -> void:
	_text.text = REFUSAL_LINES.pick_random()
	_player.play("dh_2")

func _on_yjjj_pressed() -> void:
	_text.text = PERMANENT_LINES.pick_random()
	_player.play("dh_3")
	permanent_refusal_requested.emit()

func _on_lqjl_pressed() -> void:
	if reward_claimed:
		return
	reward_claimed = true
	reward_requested.emit()
