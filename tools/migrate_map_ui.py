"""Migrate original map nodes and derive routes from legacy button handlers."""
import json
from pathlib import Path
import re
import shutil

from migrate_visual_content import ROOT, TARGET, attribute, clean, sections, write


def copy_exact(path):
    relative = path.removeprefix('res://')
    source = ROOT / relative
    if not source.is_file():
        raise FileNotFoundError(source)
    destination = TARGET / 'assets' / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    return 'res://assets/' + relative


def scene(source, script='', properties=''):
    output = ['[gd_scene format=3]']
    if script:
        output.append(f'[ext_resource type="Script" path="{script}" id="runtime"]')
    for part in sections(source):
        if part.startswith('[gd_scene') or part.startswith('[connection'):
            continue
        if part.startswith('[ext_resource'):
            if attribute(part, 'type') == 'Script':
                continue
            old_path = attribute(part, 'path')
            part = clean(part).replace(old_path, copy_exact(old_path))
        else:
            part = clean(part)
        if part.startswith('[node') and ' parent=' not in part.splitlines()[0] and script:
            part += '\nscript = ExtResource("runtime")' + properties
        output.append(part)
    write(source, '\n\n'.join(output) + '\n')


def dictionary(source, name):
    text = (ROOT / source).read_text(encoding='utf-8-sig')
    body = re.search(r'^var ' + name + r' = (\{.*?^\})', text, re.S | re.M).group(1)
    body = re.sub(r',(?=\s*[}\]])', '', body)
    return json.loads(body)


def map_routes(page):
    source = f'Scene/Main_menu/Map_{page}.tscn'
    script = (ROOT / f'Script/Main_menu/Map_{page}.gd').read_text(encoding='utf-8-sig')
    script = re.sub(r'^\s*#.*$', '', script, flags=re.M)
    functions = {match.group(1): match.group(2) for match in re.finditer(r'^func (\w+)\([^\n]*\n(.*?)(?=^func |\Z)', script, re.S | re.M)}
    routes = {}
    for part in sections(source):
        if not part.startswith('[connection') or attribute(part, 'signal') != 'pressed':
            continue
        path = attribute(part, 'from')
        handler = attribute(part, 'method')
        body = functions.get(handler, '')
        level = re.search(r'Global.AddLevelInfo\(self,"([^"]+)".*?"res://Scene/Level/Level_(\d+)\.tscn"', body)
        destination = re.search(r'change_scene_to_file\("res://Scene/Main_menu/Map_(\d)\.tscn"', body)
        if level:
            routes[path] = {'kind': 'level', 'id': 'level_' + level.group(2), 'name': level.group(1)}
        elif destination:
            routes[path] = {'kind': 'map', 'page': int(destination.group(1))}
        elif 'mainmenu' in handler or 'return' in handler or 'changetomain' in handler:
            routes[path] = {'kind': 'menu'}
        elif 'shop' in handler and 'smdp' not in handler:
            routes[path] = {'kind': 'shop'}
        elif 'task' in handler or 'AddBasicTask_' in body:
            routes[path] = {'kind': 'quest'}
        elif 'memory' in handler or 'bc_game' in handler:
            routes[path] = {'kind': 'save'}
        else:
            routes[path] = {'kind': 'unavailable'}
    scene(source, 'res://Script/ui/map_screen.gd', f'\npage = {page}')
    return routes


if __name__ == '__main__':
    maps = {str(page): map_routes(page) for page in range(1, 6)}
    write('content/maps/routes.json', json.dumps(maps, ensure_ascii=False, indent=2) + '\n')
    levels = dictionary('Scene/OtherScene/LevelInfo.gd', 'LevelInfo')
    names = dictionary('Scene/OtherScene/MonsterHeadInfo.gd', 'MonsterNameList')
    selected = {}
    for routes in maps.values():
        for route in routes.values():
            if route['kind'] != 'level':
                continue
            data = levels[route['name']]
            data['background_path'] = copy_exact(f"res://Art/LevelInfoBg/{data['SelfBg']}.png")
            for monster in data['MonsterList']:
                monster['display_name'] = names[monster['Name']]
                monster['icon_path'] = copy_exact(f"res://Art/Monster/MonsterHead/{monster['Name']}.png")
            for item in data['LevelFall']:
                copy_exact(f'res://Art/BackPack/AllItems/{item}.png')
            selected[route['id']] = data
    write('content/maps/level_previews.json', json.dumps(selected, ensure_ascii=False, indent=2) + '\n')
    scene('Scene/OtherScene/LevelInfo.tscn', 'res://Script/ui/level_preview.gd')
    scene('Scene/OtherScene/MonsterHeadInfo.tscn')
    print(f'Migrated 5 original maps and {len(selected)} original level previews')
