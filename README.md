# 八荒重构运行版

`refactor/` 是后续开发的新项目目录，当前处于迁移中，尚未完成原游戏全部功能。使用 Godot 4.7.2 导入本目录的 `project.godot`，按 F6 运行打开的场景，或按 F5 从原版主菜单 `Scene/UI/MainMenu.tscn` 启动。在菜单点“读取存档”，选择新游戏或继续；战斗入口是 `app/game_app.tscn`。新版按需加载迁移资源，不依赖父目录旧工程的 Autoload 和玩家存档。

- A / D 移动，K 跳跃，J 普攻，Y/U/I/O/L 释放当前角色技能；B 背包，Q 任务，E 前进，F5 保存，Esc 暂停。
- B 背包，Q 任务，E 通关后进入下一关，F5 保存，Esc 暂停。

主流程复用了旧项目的 32 个关卡布局、碰撞和 5 个角色/63 个怪物动作资源，但旧版脚本和全局对象不会被新版引用。旧技能元数据保留在 `AbilityCatalog.resolve()`，进入角色战斗时由 `CharacterAbilityRegistry` 为五个角色注册统一效果接口。

UI 迁移遵循旧版 Scene 优先：主菜单、档位、五页选关地图、HUD、背包、任务和商店保留原节点、坐标、字体、贴图和操作路径；新版只替换脚本绑定、数据来源和信号。`refactor/docs/00-重构要求与验收标准.md` 是本项目的 UI 保真和脚本目录验收标准。

装备定义已从 `AllEquipment.gd` 拆为 515 个 JSON。`ItemCatalog` 使用有界 LRU，`ItemInventory` 只存实例状态，随机属性由创建上下文生成，`EquipmentLoadout` 按来源增删属性、技能和被动。角色技能、法宝技能和装备技能统一注册到会话级 `ContentRegistry`，通过 `SkillTriggerRequest → AbilityController.try_trigger()` 触发，并保留来源类别。角色输入通过 `ActorController` 提交 `ActorCommand`，攻击统一经过 `Hitbox → Hurtbox → CombatResolver → Health`。

在仓库根目录执行下列命令（若终端已位于 `refactor/`，把 `--path refactor` 换成 `--path .`；`godot` 不在 PATH 时使用 Godot 可执行文件绝对路径）：

```text
godot --headless --path refactor --editor --import --quit
godot --headless --path refactor --script res://Script/tests/run_tests.gd
godot --headless --path refactor --script res://Script/tests/test_items.gd
godot --headless --path refactor --script res://Script/tests/test_abilities.gd
godot --headless --path refactor --script res://Script/tests/test_world.gd
godot --headless --path refactor --script res://Script/tests/test_app.gd
godot --headless --path refactor --script res://Script/tests/test_animation.gd
godot --headless --path refactor --script res://Script/tests/test_timeline_attacks.gd
godot --headless --path refactor --script res://Script/tests/test_player_attacks.gd
godot --headless --path refactor --script res://Script/tests/test_menu.gd
godot --headless --path refactor --script res://Script/tests/test_map.gd
godot --headless --path refactor --script res://Script/tests/test_map_ui.gd
godot --headless --path refactor --script res://Script/tests/test_shop.gd
```

架构和当前完成度见 [架构总览](docs/05-架构总览.md)、[系统实现逻辑](docs/06-系统实现逻辑.md)、[原版功能对比与完成度](docs/07-原版功能对比与完成度.md)。测试覆盖逻辑、节点回收、资源路径和关卡装配，不等价于完整旧游戏的画面验收或新旧整机进程内存差值。
