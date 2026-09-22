# 新版 Scene 入口

这里是新版可编辑场景入口，保留旧工程 `Scene/` 的组织习惯。场景只负责节点树、布局和资源引用；战斗规则、装备、存档、波次和输入仍由 `core/`、`systems/`、`app/` 负责。

- `UI/MainMenu.tscn`：搬运旧主菜单节点树、背景、字体和按钮，挂载新的入口脚本。
- `UI/GameHUD.tscn`：复用旧角色信息栏坐标和精选血蓝经验资源。
- `UI/Inventory.tscn`：严格迁移旧 BackPack 原节点、角色/数字等级动画与两栏布局，引用 `InventoryGrid.tscn` 的原 35 格、分类和分页；`InventoryDetails.tscn`、`InventoryActions.tscn` 分别保留旧属性详情和装备/出售弹窗，脚本位于 `Script/ui/`。
- `UI/QuestJournal.tscn`：从旧 `Scene/Task/BasicTask.tscn` 迁移原任务窗口节点，脚本只绑定新任务数据；完整旧任务内容和物品奖励仍未迁移。
- `Main_menu/Map_1.tscn` … `Map_5.tscn`：迁移原选关地图节点、动画、按钮坐标和路由，脚本位于 `Script/ui/map_screen.gd`。
- `Shop/SHOP.tscn`、`Shop/Shop_item.tscn`：迁移原商店窗口、九宫格商品节点和购买确认依赖，脚本位于 `Script/ui/shop_screen.gd`；商品数据独立于 `content/shops/general.json`。
- `Level/Level_*.tscn`：从旧 `Scene/Level/Level_*.tscn` 提取并清理旧运行时脚本后的正式场景，可直接在编辑器中打开和继续编辑。
- `Combat/TangSanzangNormal.tscn`、`Combat/IceDragonWave.tscn`：保留旧法术图集、动画与碰撞轨道，挂载新版 TimelineAttack 和 Hitbox；不再使用调试矩形代替。

旧工程的原始场景仍在仓库根目录 `Scene/`。新版不直接实例化带旧 Autoload 的脚本场景，避免旧全局状态污染；迁移后的场景保留原坐标、碰撞和视觉资源，并把行为脚本换成新版 `WorldSession`、`Actor` 和 `StageEncounter`。
