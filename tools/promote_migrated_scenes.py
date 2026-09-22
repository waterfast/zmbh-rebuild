"""Promote script-free scenes extracted from legacy Scene/Level into canonical Scene paths."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
source_dir = ROOT / "content" / "world" / "geometry"
target_dir = ROOT / "Scene" / "Level"
for number in range(1, 33):
    source = source_dir / f"level_{number}.tscn"
    target = target_dir / f"Level_{number}.tscn"
    shutil.copyfile(source, target)
    definition = ROOT / "content" / "world" / f"level_{number}.tres"
    text = definition.read_text(encoding="utf-8")
    text = text.replace(
        f'res://content/world/geometry/level_{number}.tscn',
        f'res://Scene/Level/Level_{number}.tscn',
    )
    definition.write_text(text, encoding="utf-8")
print("Promoted 32 script-free migrated scenes into refactor/Scene/Level")
