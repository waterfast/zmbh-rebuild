class_name CharacterSelectScreen
extends Node2D
## 复用原版创建角色窗口的节点和资源，只替换全局存档依赖。

signal confirmed(profile: PlayerProfile, store: SaveStore)
signal cancelled

var profile: PlayerProfile
var store: SaveStore
var current_character: int = 1

const CHARACTER_IDS := [&"hero_1", &"tang_sanzang", &"hero_3", &"hero_4", &"hero_5"]
const CHARACTER_NAMES := ["孙悟空", "唐三藏", "猪八戒", "沙悟净", "小白龙"]
const ELEMENTS := ["火", "水", "土", "木", "金"]
const DESCRIPTIONS := [
	"齐天大圣孙悟空，机敏聪慧，胆识过人。善用棍法，灵活多变，上手简单。",
	"金蝉转世唐三藏，佛法无边，普渡众生。武器九环禅杖，爆发，回血极高。",
	"天蓬元帅猪八戒，力大无穷，坚韧不拔。武器九齿钉耙，生存能力强。",
	"卷帘大将沙悟净，为人谨慎，朴实无华。使用铲攻，善用猛毒，上限极高。",
	"玉龙三太子小白龙，智勇双全，刚正不阿。手持长枪，机制多样，操作灵活。",
]
const STAT_LEVELS := [
	[0, 3, 5, 5], [4, 3, 3, 4], [3, 5, 4, 3], [4, 2, 3, 4], [3, 4, 4, 5],
]

func _ready() -> void:
	if profile == null:
		profile = PlayerProfile.new()
		profile.start_new()
	_build_role_buttons()
	_select_role(1)

func _build_role_buttons() -> void:
	var list := get_node("Bg/ScrollContainer/PlayerList") as VBoxContainer
	for child in list.get_children():
		child.queue_free()
	for index in range(CHARACTER_IDS.size()):
		var button := TextureButton.new()
		button.name = "Role_%d" % (index + 1)
		button.custom_minimum_size = Vector2(104, 112)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_normal = load("res://assets/Art/MainGame/ChoosePlayer/%s.png" % ["swk", "tsz", "zbj", "swj", "xbl"][index]) as Texture2D
		button.tooltip_text = CHARACTER_NAMES[index]
		button.pressed.connect(_select_role.bind(index + 1))
		var label := Label.new()
		label.text = CHARACTER_NAMES[index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, 84)
		label.size = Vector2(104, 26)
		label.add_theme_font_override("font", load("res://assets/Font/Aa文徵明琴赋小楷_mianfeiziti.com.ttf") as Font)
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		list.add_child(button)

func _select_role(character: int) -> void:
	if character < 1 or character > CHARACTER_IDS.size():
		return
	current_character = character
	var index := character - 1
	$Bg/Bg/RoleName.text = CHARACTER_NAMES[index]
	$Bg/Bg/Info.text = DESCRIPTIONS[index]
	$Bg/Bg/Prop.text = ELEMENTS[index]
	$Bg/RolePic.texture = load("res://assets/Art/MainGame/ChoosePlayer/ui_juese_%s01.png" % ["wukong", "sanzang", "bajie", "wujing", "bailong"][index]) as Texture2D
	var colors := [Color.RED, Color.CYAN, Color("c16b00"), Color.GREEN, Color.YELLOW]
	$Bg/Bg/Prop.add_theme_color_override("font_color", colors[index])
	_update_stars(index)

func _update_stars(index: int) -> void:
	var rows := [$Bg/Bg/shengcun, $Bg/Bg/gongji, $Bg/Bg/minjie, $Bg/Bg/caozuo]
	for row_index in range(rows.size()):
		var row: HBoxContainer = rows[row_index]
		for child in row.get_children():
			child.queue_free()
		for star_index in range(5):
			var star := TextureRect.new()
			star.custom_minimum_size = Vector2(28, 28)
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star.texture = load("res://assets/Art/MainGame/ChoosePlayer/xx_%d.png" % (2 if star_index < STAT_LEVELS[index][row_index] else 1)) as Texture2D
			row.add_child(star)

func _on_qued_pressed() -> void:
	if profile == null or not profile.select_character(current_character):
		return
	if store != null:
		store.save_data(profile.serialize())
	confirmed.emit(profile, store)
	queue_free()

func _on_return_main_menu_pressed() -> void:
	cancelled.emit()
	queue_free()
