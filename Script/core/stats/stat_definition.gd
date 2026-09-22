class_name StatDefinition
extends Resource
## 只读的初始配置。运行时 HP、MP 和修正值不写回共享 Resource。

@export var max_hp: float = 100.0
@export var max_mp: float = 100.0
@export var attack: float = 20.0
@export var defense: float = 3.0
@export var move_speed: float = 240.0
@export var magic_defense: float = 0.0
@export var critical_chance: float = 0.0
@export var critical_multiplier: float = 1.5
@export var dodge_chance: float = 0.0
@export var hp_regen: float = 0.0
@export var mp_regen: float = 0.0
@export var lifesteal: float = 0.0
@export var luck: float = 0.0
@export var toughness: float = 0.0
@export var accuracy: float = 0.0
@export var critical_reduction: float = 0.0
@export var armor_penetration: float = 0.0
@export var magic_penetration: float = 0.0
@export var spell_power: float = 0.0
@export var damage_reduction: float = 0.0

# 原版评级点数在装备边界按 /100 保存，公式边界统一还原；此值不是直接概率。
@export var level: float = 1.0
@export var defense_reduction: float = 0.0
@export var critical_damage_reduction: float = 0.0
@export var critical_damage_bonus: float = 0.0
@export var weakness_multiplier: float = 1.0
@export var damage_dealt_multiplier: float = 1.0
@export var damage_taken_multiplier: float = 1.0
