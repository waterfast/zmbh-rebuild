"""Split the legacy item literal without executing its per-frame randomization."""

import argparse
import ast
import hashlib
import json
from pathlib import Path


def decode(node):
    if isinstance(node, ast.Constant):
        return node.value
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        return -decode(node.operand)
    if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub, ast.Mult, ast.Div)):
        return {"operation": type(node.op).__name__, "left": decode(node.left), "right": decode(node.right)}
    if isinstance(node, ast.List):
        return [decode(element) for element in node.elts]
    if isinstance(node, ast.Dict):
        result = {}
        for key, value in zip(node.keys, node.values):
            name = decode(key)
            if name in result:
                raise ValueError(f"Duplicate legacy key: {name}")
            result[name] = decode(value)
        return result
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
        arguments = [decode(argument) for argument in node.args]
        if node.func.id in {"randi_range", "randf_range"} and len(arguments) == 2:
            return {"random": node.func.id, "min": arguments[0], "max": arguments[1]}
        if node.func.id == "snapped" and len(arguments) == 2:
            return {**arguments[0], "step": arguments[1]}
    raise ValueError(f"Unsupported expression: {ast.dump(node)}")


def read_legacy(source):
    text = source.read_text(encoding="utf-8-sig")
    literal = text.split("AllEquipment_ =", 2)[2].split("\nfunc get_last_equ_pro", 1)[0].strip()
    return decode(ast.parse(literal, mode="eval").body)


def migrate(source, destination, verify=False):
    items = read_legacy(source)
    generated = {}
    for item_id, legacy in items.items():
        document = {
            "schema_version": 1,
            "id": item_id,
            "legacy": legacy,
            "ability_ids": [],
            "passive_ids": [],
        }
        generated[f"{item_id}.json"] = document
    generated["_manifest.json"] = {
        "schema_version": 1,
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "item_count": len(items),
        "ids": sorted(items),
    }
    if verify:
        for filename, document in generated.items():
            actual = json.loads((destination / filename).read_text(encoding="utf-8"))
            if actual != document:
                raise ValueError(f"Migration mismatch: {filename}")
    else:
        destination.mkdir(parents=True, exist_ok=True)
        for filename, document in generated.items():
            (destination / filename).write_text(
                json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
            )
    print(f"{'Verified' if verify else 'Migrated'} {len(items)} items; all expressions and metadata preserved.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[2] / "AllEquipment.gd")
    parser.add_argument("--destination", type=Path, default=Path(__file__).resolve().parents[1] / "content/items")
    parser.add_argument("--verify", action="store_true")
    arguments = parser.parse_args()
    migrate(arguments.source, arguments.destination, arguments.verify)
