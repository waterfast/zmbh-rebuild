# 炼丹炉数据模型

炼丹炉配方现在由 `content/recipes/index.json` 驱动，原版 `Synthesis.gd` 中的 142 条规则已经迁移：134 条固定材料配方和 8 条按法宝 `FBTYPE` 组合匹配的配方。新增配方只需添加一个对象，不需要修改服务代码。

`RecipeCatalog` 负责读取和匹配配方，`AlchemyService` 只负责校验材料、灵魂和容量，并以事务方式扣除材料、创建产物。产物使用 `ItemRollContext(source="alchemy")` 在实例创建时生成随机属性，定义缓存不会持有随机值。

合成成功后仍由 `ItemInventory.serialize()` 保存实例随机值，因此读档不会重新随机。任意校验或创建失败都会恢复合成前的背包快照，材料和灵魂不会被部分扣除。

```gdscript
var result := profile.alchemy.craft([material_uid_a, material_uid_b, material_uid_c])
if result.result == AlchemyService.Result.SUCCESS:
    var created: ItemInstance = result.item
```
