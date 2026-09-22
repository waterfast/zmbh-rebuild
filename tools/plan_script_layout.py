"""Print an apply_patch patch for the project-owned GDScript layout migration."""

from pathlib import Path
import difflib
import sys


ROOT = Path(__file__).resolve().parents[1]
EXTENSIONS = {".gd", ".uid", ".tscn", ".tres", ".json", ".godot", ".md", ".py"}


def main():
    scripts = sorted(
        path for path in ROOT.rglob("*.gd")
        if not any(part in {".godot", "addons", "assets", "Script"} for part in path.relative_to(ROOT).parts)
    )
    moves = {path: ROOT / "Script" / path.relative_to(ROOT) for path in scripts}
    for path in scripts:
        uid = path.with_suffix(".gd.uid")
        if uid.exists():
            moves[uid] = ROOT / "Script" / uid.relative_to(ROOT)
    replacements = {
        path.relative_to(ROOT).as_posix(): destination.relative_to(ROOT).as_posix()
        for path, destination in moves.items()
    }
    patch = ["*** Begin Patch"]
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or path.suffix not in EXTENSIONS or path == Path(__file__).resolve():
            continue
        if any(part in {".godot", "addons", "assets"} for part in path.relative_to(ROOT).parts):
            continue
        previous = path.read_text(encoding="utf-8-sig")
        updated = previous
        for source, destination in sorted(replacements.items(), key=lambda pair: -len(pair[0])):
            updated = updated.replace(source, destination)
        if previous == updated and path not in moves:
            continue
        patch.append("*** Update File: " + path.as_posix())
        if path in moves:
            patch.append("*** Move to: " + moves[path].as_posix())
        if previous == updated:
            first_line = previous.splitlines()[0]
            patch.extend(["@@", "-" + first_line, "+" + first_line])
        else:
            differences = list(difflib.unified_diff(previous.splitlines(), updated.splitlines(), n=3))
            patch.extend("@@" if line.startswith("@@") else line for line in differences[2:])
    patch.append("*** End Patch")
    sys.stdout.reconfigure(encoding="utf-8")
    print("\n".join(patch))


if __name__ == "__main__":
    main()
