# 物品系统

`content/items/<id>.json` 是静态定义，每个物品一个文件。`tools/migrate_items.py` 从旧版 `AllEquipment.gd` 生成这些文件；`legacy` 字段不删减旧字段，随机表达式保存为 `{random,min,max}`，因此迁移不会在加载时偷偷重掷。

- `ItemCatalog` 以 LRU 缓存按需读取定义，容量由构造参数限制。
- `ItemInventory` 是实例唯一来源。`ItemInstance` 只保存定义 ID、唯一 ID、首次随机结果、强化等级、五行和宝石实例快照。
- `EquipmentLoadout` 的槽位只保存实例 ID；装备/卸下用同一个 `equipment:<owner>:<uid>` 来源更新属性、技能和被动，避免每帧重建全表。
- `ItemInventory.serialize()` 与 `restore()` 使用 schema 1。恢复会验证定义存在、随机值范围/步进、唯一 ID、嵌套宝石和元素数量，并在所有检查通过后一次替换。
- `ItemEconomy` 封装购买、出售和强化；背包操作失败会回滚金币，已装备实例因保留锁不能出售。

旧配置中的暴击、闪避、吸血、韧性、命中和减免数值按百分数保存，转换到新战斗内核比例时只在 `ItemDefinition.stats()` 边界除以 100，原始 JSON 不变。
