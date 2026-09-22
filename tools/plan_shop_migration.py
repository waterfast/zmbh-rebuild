"""Emit exact legacy shop scenes and separated offers as an apply_patch patch."""

import ast
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "refactor"
SCENES = {
    "Scene/Shop/SHOP.tscn": "Script/ui/shop_screen.gd",
    "Scene/Shop/Shop_item.tscn": "Script/ui/shop_item.gd",
    "Scene/BackPack/Box_1.tscn": "",
}


def build():
    files = {}
    assets = set()
    for original, script in SCENES.items():
        target = original if original != "Scene/BackPack/Box_1.tscn" else "Scene/Shop/ItemIcon.tscn"
        content = (ROOT / original).read_text(encoding="utf-8-sig")
        content = re.sub(r' uid="[^"]+"', "", content)
        content = re.sub(r'load_steps=\d+ ', "", content, count=1)
        if not script:
            script_ids = re.findall(r'\[ext_resource type="Script"[^\n]*id="([^"]+)"\]', content)
            content = re.sub(r'^\[ext_resource type="Script"[^\n]*\]\n', "", content, flags=re.M)
            for identifier in script_ids:
                content = re.sub(r'^script = ExtResource\(\s*"' + identifier + r'"\s*\)\n', "", content, flags=re.M)
            content = re.sub(r'^\[connection[^\n]*\]\n?', "", content, flags=re.M)
        for path in re.findall(r'path="(res://[^"]+)"', content):
            if path.endswith(".gd"):
                replacement = "res://" + script
            elif path.endswith(".tscn"):
                replacement = "res://Scene/Shop/ItemIcon.tscn"
            else:
                relative = path.removeprefix("res://")
                if not (ROOT / relative).exists():
                    raise FileNotFoundError(relative)
                assets.add(relative)
                replacement = "res://assets/" + relative
            content = content.replace(path, replacement)
        files[target] = content
    source = (ROOT / "Script/Shop/SHOP.gd").read_text(encoding="utf-8-sig")
    offers = {}
    for name in ["WkList", "TsList", "BjList", "SsList", "BlList", "TotalItemList"]:
        literal = re.search(r'var ' + name + r'\s*=\s*(\[.*?\])', source, re.S).group(1)
        entries = ast.literal_eval(literal)
        offers[name] = [{"id": entry["名字"], "price": entry["灵魂"]} for entry in entries]
    data = {
        "common": offers["TotalItemList"],
        "characters": {str(index): offers[name] for index, name in enumerate(["WkList", "TsList", "BjList", "SsList", "BlList"], 1)},
        "level_50": {str(index): {"id": identifier, "price": 200000} for index, identifier in enumerate(["qtds", "jcz", "tpys", "jldj", "lwstz"], 1)},
        "free": [{"id": "xczg", "price": 0}, {"id": "sxyr", "price": 0}],
    }
    files["content/shops/general.json"] = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if "--assets" in sys.argv:
        print(json.dumps(sorted(assets), ensure_ascii=False))
        return
    patch = ["*** Begin Patch"]
    for relative, content in files.items():
        patch.append("*** Add File: " + (TARGET / relative).as_posix())
        patch.extend("+" + line for line in content.splitlines())
    patch.append("*** End Patch")
    print("\n".join(patch))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    build()
