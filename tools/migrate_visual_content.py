"""Extract original visual data without importing the legacy Godot runtime.

Run from any directory with Python and Pillow. Only selected reachable image files
are copied; scripts, autoloads and old imported texture caches are never copied.
"""
from pathlib import Path
import json
import re
import shutil
import ast

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "refactor"
COPIED = set()
MONSTERS = set()
LEVEL_COUNT = 32


def write(relative, text):
    destination = TARGET / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(text, encoding="utf-8")


def sections(relative):
    text = (ROOT / relative).read_text(encoding="utf-8-sig")
    return [part.strip() for part in re.split(r"(?=^\[(?:gd_scene|ext_resource|sub_resource|node|connection))", text, flags=re.M) if part.strip()]


def attribute(section, name, default=""):
    found = re.search(r'\b' + name + r'="([^"]*)"', section.splitlines()[0])
    return found.group(1) if found else default


def copy_asset(path):
    relative = path.removeprefix("res://")
    source = ROOT / relative
    if not source.exists():
        # A few old scenes refer only to an editor-imported JPG; use the matching
        # neighboring PNG when source art was not shipped in the repository.
        candidate = source.with_suffix(".png")
        if candidate.exists():
            relative = candidate.relative_to(ROOT).as_posix()
            source = candidate
        else:
            siblings = sorted(source.parent.glob("*.png"))
            if not siblings:
                return path
            source = siblings[0]
            relative = source.relative_to(ROOT).as_posix()
    destination = TARGET / "assets" / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    if relative not in COPIED:
        shutil.copyfile(source, destination)
        COPIED.add(relative)
    return "res://assets/" + relative


def clean(section):
    section = re.sub(r' uid="[^"]+"', "", section)
    section = re.sub(r'^script = .*\n?', "", section, flags=re.M)
    section = re.sub(r'^metadata/.*\n?', "", section, flags=re.M)
    return section.strip()


def resource_closure(all_sections, roots):
    subresources = {attribute(part, "id"): part for part in all_sections if part.startswith("[sub_resource")}
    needed = set()
    pending = list(roots)
    while pending:
        identifier = pending.pop()
        if identifier in needed:
            continue
        needed.add(identifier)
        pending.extend(re.findall(r'SubResource\(\s*"([^"]+)"\s*\)', subresources[identifier]))
    return [clean(part) for key, part in subresources.items() if key in needed]


def migrate_monster(number):
    if not (ROOT / f"Scene/Monster/Monster_{number}.tscn").exists():
        return
    original = sections(f"Scene/Monster/Monster_{number}.tscn")
    if not any(part.startswith('[node name="mr_ani"') for part in original):
        return
    sprite = next(part for part in original if part.startswith('[node name="mr_ani"'))
    frames_id = re.search(r'sprite_frames = SubResource\(\s*"([^"]+)"', sprite).group(1)
    resources = resource_closure(original, [frames_id])
    external_ids = set(re.findall(r'ExtResource\(\s*"([^"]+)"\s*\)', "\n".join(resources)))
    external = []
    for part in original:
        if part.startswith("[ext_resource") and attribute(part, "id") in external_ids:
            path = attribute(part, "path")
            external.append(clean(part).replace(path, copy_asset(path)))
    frames = next(part for part in resources if part.startswith('[sub_resource type="SpriteFrames"'))
    resources.remove(frames)
    frames = re.sub(r'^\[sub_resource[^\n]+', "[resource]", frames)
    wait = re.search(r'"frames": \[(.*?)\],\s*"loop":.*?"name": &"wait"', frames, re.S)
    sprite_offset = (0, -40)
    if wait and re.findall(r'SubResource\(\s*"([^"]+)"', wait.group(1)):
        texture_id = re.findall(r'SubResource\(\s*"([^"]+)"', wait.group(1))[-1]
        atlas_part = next((part for part in resources if attribute(part, "id") == texture_id), "")
        region_match = re.search(r'region = Rect2\(([^)]+)\)', atlas_part)
        if region_match:
            region = [float(value) for value in region_match.group(1).split(",")]
            sprite_offset = (0, -region[3] / 2)
    frames += f'\nmetadata/foot_offset = Vector2({sprite_offset[0]:g}, {sprite_offset[1]:g})\nmetadata/faces_left = true'
    name = "monkey" if number == 1 else f"monster_{number}"
    write(f"presentation/skins/{name}.tres", "\n\n".join(['[gd_resource type="SpriteFrames" format=3]', *external, *resources, frames]) + "\n")


def migrate_hero(number, scene_path):
    original = sections(scene_path)
    source_paths = [f"Art/HeroPicture/Role{number}AllEquipment/Role_{number}_Body_Empty.png", f"Art/HeroPicture/Role{number}AllEquipment/Role_{number}_Eq_Empty.png"]
    for layer_index, source_path in enumerate(source_paths):
        texture_path = copy_asset(source_path)
        width, height = Image.open(ROOT / source_path).size
        node_name = "RoleBody" if layer_index == 0 else "RoleEquipment"
        node = next(part for part in original if part.startswith('[node name="%s"' % node_name))
        hframes = int(re.search(r'^hframes = (\d+)', node, re.M).group(1))
        vframes = int(re.search(r'^vframes = (\d+)', node, re.M).group(1))
        frame_count = hframes * vframes
        frame_width, frame_height = width / hframes, height / vframes
        resources = []
        for frame in range(frame_count):
            resources.append(f'[sub_resource type="AtlasTexture" id="frame_{frame}"]\natlas = ExtResource("texture")\nregion = Rect2({frame % hframes * frame_width:g}, {frame // hframes * frame_height:g}, {frame_width:g}, {frame_height:g})')
        animations = []
        for part in original:
            if not part.startswith('[sub_resource type="Animation"'):
                continue
            name_match = re.search(r'^resource_name = "([^"]+)"', part, re.M)
            if not name_match:
                continue
            name = name_match.group(1)
            length_match = re.search(r'^length = ([\d.]+)', part, re.M)
            length = float(length_match.group(1)) if length_match else 1.0
            layer_name = node_name
            track_match = re.search(r'tracks/(\d+)/path = NodePath\("Action/' + layer_name + r':frame"\)', part)
            if not track_match:
                continue
            track = track_match.group(1)
            keys = re.search(r'tracks/' + track + r'/keys = \{(.*?)\}', part, re.S).group(1)
            times = [float(value) for value in re.search(r'"times": PackedFloat32Array\(([^)]*)\)', keys).group(1).split(",")]
            values = [int(value) for value in re.search(r'"values": \[([^]]*)\]', keys).group(1).split(",")]
            frames = []
            for index, value in enumerate(values):
                end = times[index + 1] if index + 1 < len(times) else length
                duration = max(0.01, end - times[index])
                frames.append(f'{{"duration": {duration:.6f}, "texture": SubResource("frame_{value}")}}')
            loop = "true" if name in ("wait", "run") else "false"
            animations.append('{"name": &"' + name + '", "speed": 1.0, "loop": ' + loop + ', "frames": [' + ", ".join(frames) + ']}')
        suffix = "body" if layer_index == 0 else "weapon"
        skin_name = "tang_sanzang" if number == 2 else f"hero_{number}"
        body_image = Image.open(ROOT / source_paths[0])
        first_frame = body_image.crop((0, 0, frame_width, frame_height))
        bounds = first_frame.getbbox() or (0, 0, frame_width, frame_height)
        offset_x = frame_width / 2 - (bounds[0] + bounds[2]) / 2
        offset_y = frame_height / 2 - bounds[3]
        metadata = f'\nmetadata/foot_offset = Vector2({offset_x:g}, {offset_y:g})\nmetadata/faces_left = true\nmetadata/hero = true'
        write(f"presentation/skins/{skin_name}_{suffix}.tres", "\n\n".join(['[gd_resource type="SpriteFrames" format=3]', f'[ext_resource type="Texture2D" path="{texture_path}" id="texture"]', *resources, '[resource]\nanimations = [\n' + ",\n".join(animations) + '\n]' + metadata]) + "\n")


def migrate_prop(name, source_path):
    original = sections(source_path)
    kept = []
    forbidden_paths = []
    allowed_types = {"Node2D", "Sprite2D", "AnimatedSprite2D", "StaticBody2D", "CollisionShape2D", "CollisionPolygon2D", "Polygon2D", "ParallaxBackground", "ParallaxLayer"}
    for part in original:
        if not part.startswith("[node"):
            continue
        parent = attribute(part, "parent")
        node_name = attribute(part, "name")
        full_path = node_name if parent == "." else parent + "/" + node_name
        if attribute(part, "type") not in allowed_types or any(parent == path or parent.startswith(path + "/") for path in forbidden_paths):
            forbidden_paths.append(full_path)
            continue
        part = clean(part)
        part = re.sub(r'^collision_layer = \d+', "collision_layer = 1", part, flags=re.M)
        part = re.sub(r'^collision_mask = \d+', "collision_mask = 0", part, flags=re.M)
        kept.append(part)
    save_scene_dependencies(original, kept, f"content/world/geometry/{name}.tscn")


def save_scene_dependencies(original, nodes, target):
    sub_ids = re.findall(r'SubResource\(\s*"([^"]+)"\s*\)', "\n".join(nodes))
    resources = resource_closure(original, sub_ids)
    external_ids = set(re.findall(r'ExtResource\(\s*"([^"]+)"\s*\)', "\n".join(nodes + resources)))
    external = []
    for part in original:
        if not part.startswith("[ext_resource") or attribute(part, "id") not in external_ids:
            continue
        path = attribute(part, "path")
        if path.endswith("BaseThroughLevel.tscn"):
            replacement = "res://content/world/geometry/base_geometry.tscn"
        elif attribute(part, "type") == "PackedScene":
            prop = Path(path).stem
            migrate_prop(prop, path.removeprefix("res://"))
            replacement = f"res://content/world/geometry/{prop}.tscn"
        else:
            replacement = copy_asset(path)
        external.append(clean(part).replace(path, replacement))
    write(target, "\n\n".join(['[gd_scene format=3]', *external, *resources, *nodes]) + "\n")


def migrate_levels():
    base = sections("Scene/Base/BaseThroughLevel.tscn")
    roots = {"BaseThoughLevel", "wall", "BackGround", "exit"}
    nodes = []
    for part in base:
        if not part.startswith("[node"):
            continue
        parent = attribute(part, "parent")
        name = attribute(part, "name")
        if name == "exit" and parent == ".":
            nodes.append('[node name="exit" type="Marker2D" parent="."]\nposition = Vector2(439, 387)')
        elif (not parent and name in roots) or (parent == "." and name in roots) or parent in ("wall", "BackGround", "BackGround/floor_2"):
            nodes.append(clean(part))
    save_scene_dependencies(base, nodes, "content/world/geometry/base_geometry.tscn")
    manifest = []
    for number in range(1, LEVEL_COUNT + 1):
        original = sections(f"Scene/Level/Level_{number}.tscn")
        nodes = []
        exit_x = 4202.0
        for part in original:
            if not part.startswith("[node"):
                continue
            parent = attribute(part, "parent")
            name = attribute(part, "name")
            if parent and not (parent == "wall" or parent.startswith("wall/") or parent == "BackGround" or parent.startswith("BackGround/") or (parent == "." and name in roots)):
                continue
            part = clean(part)
            part = re.sub(r' index="\d+"', "", part)
            if name.startswith("stop") and name != "stop4":
                part = re.sub(r'^disabled = .*\n?', "", part, flags=re.M) + "\ndisabled = true"
            if name == "exit":
                match = re.search(r'position = Vector2\(([^,]+),', part)
                if match:
                    exit_x = float(match.group(1))
            nodes.append(part)
        save_scene_dependencies(original, nodes, f"content/world/geometry/level_{number}.tscn")
        script_path = ROOT / f"Script/Level/Level_{number}.gd"
        if not script_path.exists():
            script_path = ROOT / f"Script/Level/level_{number}.gd"
        script = script_path.read_text(encoding="utf-8-sig")
        name_match = re.search(r'Global.CurrentLevel\s*=\s*"([^"]+)"', script)
        display_name = name_match.group(1) if name_match else f"关卡 {number}"
        next_id = f"level_{number + 1}" if number < LEVEL_COUNT else ""
        width = max(960, int(exit_x + 460))
        wave_lists = []
        tables = []
        for table_name in ("Monster_group", "Monster_position_x", "Monster_position_y"):
            table_match = re.search(table_name + r'\s*=\s*(\{.*?\})', script, re.S)
            tables.append(ast.literal_eval(table_match.group(1)) if table_match else {})
        for stage, monsters in tables[0].items():
            positions = []
            for index, monster in enumerate(monsters):
                MONSTERS.add(monster)
                horizontal = tables[1][stage][index]
                vertical = tables[2][stage][index] + 2
                positions.extend([horizontal, vertical])
            wave_lists.append('{"stage": ' + stage.removeprefix("stage_") + ', "monster_ids": PackedInt32Array(' + ', '.join(map(str, monsters)) + '), "positions": PackedVector2Array(' + ', '.join(map(str, positions)) + ')}')
        waves = "[\n" + ",\n".join(wave_lists) + "\n]"
        write(f"content/world/level_{number}.tres", f'''[gd_resource type="Resource" script_class="LevelDefinition" format=3]

[ext_resource type="Script" path="res://Script/world/level_definition.gd" id="definition"]

[resource]
script = ExtResource("definition")
id = &"level_{number}"
display_name = "{display_name}"
geometry_path = "res://content/world/geometry/level_{number}.tscn"
spawn_position = Vector2(180, 300)
camera_bounds = Rect2(0, 0, {width}, 590)
exit_position = Vector2({exit_x + 1:g}, 429)
next_level_id = &"{next_id}"
enemy_positions = PackedVector2Array(600, 300, 860, 300, 1080, 280, 1850, 300, 2200, 300, 2800, 300, 3200, 300, 3900, 300)
waves = Array[Dictionary]({waves})
''')
        manifest.append({"id": f"level_{number}", "display_name": display_name, "source": f"Scene/Level/Level_{number}.tscn", "geometry_only": True})
    write("content/world/migration_manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


def migrate_ui():
    catalog = {}
    scenes = ["Scene/Level/Role_information.tscn", "Scene/Main_menu/Map_1.tscn", "Scene/Main_menu/Main_Menu.tscn", "Scene/BackPack/BackPack.tscn", "Scene/BackPack/Main_Backpack.tscn"]
    for scene in scenes:
        entries = []
        for part in sections(scene):
            if not part.startswith("[ext_resource") or attribute(part, "type") != "Texture2D":
                continue
            path = attribute(part, "path")
            if any(skip in path for skip in ("/Wings/", "/Gogo/", "/Role1AllEquipment/", "/AddEffect/", "/Protect_")):
                continue
            migrated = copy_asset(path)
            width, height = Image.open(ROOT / path.removeprefix("res://")).size
            entries.append({"path": migrated, "width": width, "height": height, "legacy_resource_id": attribute(part, "id")})
        catalog[scene] = entries
    copy_asset("Font/华康宋体W3.ttc")
    for name in ("blb", "jgz", "jhsj", "myhc", "sgq", "shy", "smb", "tjgl", "xbz"):
        path = ROOT / f"Art/Skill/SkillIcon/{name}.png"
        if path.exists():
            copy_asset(path.relative_to(ROOT).as_posix())
    copy_asset("Art/head_x/tx.png")
    write("presentation/ui_assets.json", json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    for number, scene in ((1, "Scene/Hero/Role_1/Role1.tscn"), (2, "Scene/Hero/Role_2/Role_2.tscn"), (3, "Scene/Hero/Role_3/Role_3.tscn"), (4, "Scene/Hero/Role_4/Role_4.tscn"), (5, "Scene/Hero/Role_5/Role_5.tscn")):
        migrate_hero(number, scene)
    migrate_levels()
    for monster_id in sorted(MONSTERS):
        migrate_monster(monster_id)
    migrate_ui()
    write("presentation/migrated_assets.json", json.dumps(sorted(COPIED), ensure_ascii=False, indent=2) + "\n")
    print(f"Migrated {LEVEL_COUNT} level layouts, five heroes, {len(MONSTERS)} monster skins and {len(COPIED)} selected assets.")
