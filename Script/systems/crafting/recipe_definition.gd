class_name RecipeDefinition
extends RefCounted

var id: StringName
var inputs: Array[StringName] = []
var criteria: Dictionary = {}
var output: StringName
var cost: int
var source: StringName

func _init(data: Dictionary) -> void:
	id = StringName(str(data.get("id", "")))
	for value: Variant in data.get("inputs", []):
		if value is String:
			inputs.append(StringName(value))
	criteria = data.get("criteria", {}).duplicate(true) if data.get("criteria", {}) is Dictionary else {}
	output = StringName(str(data.get("output", "")))
	cost = maxi(0, int(data.get("cost", 0)))
	source = StringName(str(data.get("source", "content")))

func matches(definition_ids: Array[StringName], catalog: ItemCatalog) -> bool:
	if definition_ids.size() != 3:
		return false
	var available := definition_ids.duplicate()
	for expected: StringName in inputs:
		var index := available.find(expected)
		if index < 0:
			return false
		available.remove_at(index)
	if not inputs.is_empty():
		return available.is_empty()
	var sequence := str(criteria.get("fbtype_sequence", ""))
	if sequence.length() != 3:
		return false
	var actual := ""
	for definition_id: StringName in definition_ids:
		var definition := catalog.get_definition(definition_id)
		if definition == null:
			return false
		actual += str(definition.metadata().get("FBTYPE", ""))
	return _same_permutation(actual, sequence)

func _same_permutation(actual: String, expected: String) -> bool:
	if actual.length() != expected.length() or actual.length() != 3:
		return false
	var counts: Dictionary = {}
	for character in actual:
		counts[character] = int(counts.get(character, 0)) + 1
	for character in expected:
		counts[character] = int(counts.get(character, 0)) - 1
	for value: int in counts.values():
		if value != 0:
			return false
	return true
