import re
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[2]
LEGACY = PROJECT.parent
SCENES = {
    "BackPack.tscn": ("Inventory.tscn", "inventory_screen.gd"),
    "Main_Backpack.tscn": ("InventoryGrid.tscn", None),
    "Box_1.tscn": ("InventoryCell.tscn", None),
    "zb.tscn": ("EquipmentSlot.tscn", None),
    "equipment_properies.tscn": ("InventoryDetails.tscn", "inventory_item_details.gd"),
    "sell_or_equ.tscn": ("InventoryActions.tscn", "inventory_item_actions.gd"),
}


def expected_migration(source, script):
    script_match = re.search(r'\[ext_resource type="Script" path="[^"]+" id="([^"]+)"\]', source)
    if script_match:
        resource_id = script_match[1]
        if script:
            source = source.replace(script_match[0], f'[ext_resource type="Script" path="res://Script/ui/{script}" id="{resource_id}"]')
        else:
            source = source.replace(script_match[0] + "\n", "")
            source = source.replace(f'\nscript = ExtResource( "{resource_id}" )', "")
    source = re.sub(r'^\[connection[^\n]+\]\n?', "", source, flags=re.MULTILINE)
    source = re.sub(r' uid="[^"]+"', "", source)
    source = source.replace("res://Art/", "res://assets/Art/")
    source = source.replace("res://Font/", "res://assets/Font/")
    for original, (replacement, _) in SCENES.items():
        source = source.replace(f"res://Scene/BackPack/{original}", f"res://Scene/UI/{replacement}")
    return re.sub(r'^\[gd_scene[^\n]+\]', "[gd_scene format=3]", source).rstrip()


def main():
    for original, (replacement, script) in SCENES.items():
        old_path = LEGACY / "Scene" / "BackPack" / original
        new_path = PROJECT / "Scene" / "UI" / replacement
        expected = expected_migration(old_path.read_text(encoding="utf-8-sig"), script)
        actual = new_path.read_text(encoding="utf-8-sig").rstrip()
        assert actual == expected, f"Visual scene properties changed: {replacement}"
    print(f"INVENTORY SCENE PARITY: {len(SCENES)} original scenes retain all visual node/resource properties")


if __name__ == "__main__":
    main()
