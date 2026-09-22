"""Point level definitions at editable Scene wrappers instead of hidden geometry paths."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for number in range(1, 33):
    path = ROOT / "content" / "world" / f"level_{number}.tres"
    text = path.read_text(encoding="utf-8")
    old = f'geometry_path = "res://content/world/geometry/level_{number}.tscn"'
    new = f'geometry_path = "res://Scene/Level/Level_{number}.tscn"'
    if old not in text:
        raise SystemExit(f"missing geometry path: {path}")
    path.write_text(text.replace(old, new), encoding="utf-8")
print("Retargeted 32 level definitions to Scene wrappers")
