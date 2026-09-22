class_name RecipeCatalog
extends RefCounted

var _path: String
var _recipes: Array[RecipeDefinition] = []
var _loaded := false

func _init(path: String = "res://content/recipes/index.json") -> void:
	_path = path

func all() -> Array[RecipeDefinition]:
	_ensure_loaded()
	return _recipes.duplicate()

func find(definition_ids: Array[StringName], catalog: ItemCatalog) -> RecipeDefinition:
	_ensure_loaded()
	for recipe: RecipeDefinition in _recipes:
		if recipe.matches(definition_ids, catalog):
			return recipe
	return null

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if not parsed is Dictionary or parsed.get("schema_version") != 1 or not parsed.get("recipes") is Array:
		return
	for row: Variant in parsed.recipes:
		if row is Dictionary:
			var recipe := RecipeDefinition.new(row)
			if not recipe.id.is_empty() and not recipe.output.is_empty():
				_recipes.append(recipe)
