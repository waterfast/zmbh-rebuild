class_name AlchemyService
extends RefCounted

enum Result { SUCCESS, INVALID_RECIPE, MISSING_MATERIAL, INSUFFICIENT_GOLD, INVENTORY_FULL, FAILED }

var inventory: ItemInventory
var progression: PlayerProgression
var recipes: RecipeCatalog
var _rng := RandomNumberGenerator.new()

func _init(item_inventory: ItemInventory, player_progression: PlayerProgression, recipe_catalog: RecipeCatalog = null, rng: RandomNumberGenerator = null) -> void:
	inventory = item_inventory
	progression = player_progression
	recipes = recipe_catalog if recipe_catalog != null else RecipeCatalog.new()
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()

func craft(input_uids: Array[StringName]) -> Dictionary:
	if input_uids.size() != 3 or input_uids[0] == input_uids[1] or input_uids[0] == input_uids[2] or input_uids[1] == input_uids[2]:
		return _result(Result.INVALID_RECIPE)
	var definitions: Array[StringName] = []
	for uid: StringName in input_uids:
		var item := inventory.get_item(uid)
		if item == null:
			return _result(Result.MISSING_MATERIAL)
		definitions.append(item.definition_id)
	var recipe := recipes.find(definitions, inventory.catalog)
	if recipe == null:
		return _result(Result.INVALID_RECIPE)
	if progression.gold < recipe.cost:
		return _result(Result.INSUFFICIENT_GOLD, recipe)
	if inventory.item_ids().size() - 3 + 1 > inventory.capacity:
		return _result(Result.INVENTORY_FULL, recipe)
	var snapshot := inventory.serialize()
	for uid: StringName in input_uids:
		if not inventory.remove(uid):
			inventory.restore(snapshot)
			return _result(Result.FAILED, recipe)
	var output := inventory.create_item_with_context(recipe.output, ItemRollContext.new(_rng, &"alchemy"))
	if output == null:
		inventory.restore(snapshot)
		return _result(Result.FAILED, recipe)
	if not progression.spend(recipe.cost):
		inventory.restore(snapshot)
		return _result(Result.FAILED, recipe)
	return {"result": Result.SUCCESS, "recipe": recipe, "item": output}

func _result(result: int, recipe: RecipeDefinition = null) -> Dictionary:
	return {"result": result, "recipe": recipe}
