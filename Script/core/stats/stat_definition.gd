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
