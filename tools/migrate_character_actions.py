"""Extract original actor-local animation, effects and hit windows without legacy scripts."""
import re, json
from migrate_visual_content import sections, attribute, clean, resource_closure, copy_asset, write
SOURCES = {1:'Role_1/Role1',2:'Role_2/Role_2',3:'Role_3/Role_3',4:'Role_4/Role_4',5:'Role_5/Role_5'}

def migrate(number, source):
    original = sections(f'Scene/Hero/{source}.tscn')
    nodes = ['[node name="ActionTimeline" type="Node2D"]\nscript = ExtResource("runtime")']
    allowed = set()
    for part in original:
        if not part.startswith('[node'): continue
        name, parent = attribute(part,'name'), attribute(part,'parent')
        if name == 'Action' and parent == '.':
            nodes.append('[node name="Action" type="Node2D" parent="."]\n'+ '\n'.join(clean(part).splitlines()[1:]));allowed.add('Action')
        elif parent == 'Action' and (name in ('RoleBody','RoleEquipment') or name.startswith('SpecialEffect')):
            kind = 'Sprite2D' if name in ('RoleBody','RoleEquipment') else attribute(part,'type','AnimatedSprite2D')
            nodes.append(f'[node name="{name}" type="{kind}" parent="Action"]\n'+'\n'.join(clean(part).splitlines()[1:]));allowed.add('Action/'+name)
    if 'Action' not in allowed:
        nodes.insert(1,'[node name="Action" type="Node2D" parent="."]\nposition = Vector2(0, -30)');allowed.add('Action')
    base = next((p for p in original if p.startswith('[node name="base_damagebox"')), '')
    pos = re.search(r'^position = (.*)',base,re.M)
    nodes += ['[node name="base_damagebox" type="Node2D" parent="."]\nposition = '+(pos.group(1) if pos else 'Vector2(0, -30)'), '[node name="HitBox" type="Area2D" parent="base_damagebox"]\nscript = ExtResource("hitbox")\ncollision_layer = 0\ncollision_mask = 2', '[node name="HitBox" type="CollisionShape2D" parent="base_damagebox/HitBox"]\ndisabled = true']
    initial_hit = next((p for p in original if p.startswith('[node name="HitBox" parent="base_damagebox/HitBox"')), '')
    if initial_hit:
        nodes[-1] = '[node name="HitBox" type="CollisionShape2D" parent="base_damagebox/HitBox"]\n' + '\n'.join(clean(initial_hit).splitlines()[1:])
    allowed.add('base_damagebox/HitBox/HitBox')
    animations, entries, manifest = [],[],{}
    for part in original:
        if not part.startswith('[sub_resource type="Animation"'):continue
        match = re.search(r'^resource_name = "([^"]+)"',part,re.M)
        if not match:continue
        name = match.group(1)
        length_match = re.search(r'^length = ([\d.]+)',part,re.M)
        length = float(length_match.group(1)) if length_match else 1.0
        speed = 1.0
        tracks = re.split(r'(?=^tracks/\d+/type =)',part,flags=re.M)[1:]
        kept=[]; has_hit=False; windows=[]
        for track in tracks:
            path_match = re.search(r'path = NodePath\("([^\"]+)"\)',track)
            if not path_match:continue
            path=path_match.group(1)
            if path == 'RolePlayer:speed_scale':
                v=re.search(r'"values": \[([\d.]+)',track)
                if v:speed=float(v.group(1))
            if path.split(':')[0] not in allowed:continue
            if '/type = "method"' in track and not all(m in ('play','stop') for m in re.findall(r'"method": &"([^"]+)"',track)):continue
            if ':disabled' in path:
                values = re.search(r'"values": \[([^]]+)\]',track).group(1).split(',')
                times = re.search(r'"times": PackedFloat32Array\(([^)]+)\)',track).group(1).split(',')
                windows += [float(t) for t,v in zip(times,values) if v.strip()=='false']
                has_hit = bool(windows)
            kept.append(re.sub(r'tracks/\d+/',f'tracks/{len(kept)}/',track))
        if not kept: continue
        if windows:
            i=len(kept)
            kept.append(f'tracks/{i}/type = "method"\ntracks/{i}/path = NodePath("base_damagebox/HitBox")\ntracks/{i}/keys = {{"times": PackedFloat32Array('+','.join(map(str, windows))+'), "transitions": PackedFloat32Array('+','.join('1' for _ in windows)+'), "values": ['+','.join('{"args": [], "method": &"begin_hit_window"}' for _ in windows)+']}')
        identifier='action_'+str(len(animations))
        animations.append(f'[sub_resource type="Animation" id="{identifier}"]\nresource_name = "{name}"\nlength = {length}\n'+'\n'.join(kept))
        entries.append(f'"{name}": SubResource("{identifier}")')
        events = {}
        for track in tracks:
            if '/type = "method"' not in track:continue
            times = re.search(r'"times": PackedFloat32Array\(([^)]+)\)',track)
            if not times:continue
            methods = re.findall(r'"method": &"([^"]+)"',track)
            for time, method in zip(times.group(1).split(','), methods):
                events.setdefault(method, []).append(float(time) / max(.01,speed))
        manifest[name]={'duration':length/max(.01,speed),'speed':speed,'hitbox':has_hit,'events':events}
    roots = re.findall(r'SubResource\(\s*"([^\"]+)"\s*\)', '\n'.join(nodes+animations))
    resources=resource_closure(original,roots)
    ext_ids=set(re.findall(r'ExtResource\(\s*"([^\"]+)"\s*\)','\n'.join(resources+nodes)))
    externals=[]
    for part in original:
        if part.startswith('[ext_resource') and attribute(part,'id') in ext_ids:
            path=attribute(part,'path');externals.append(clean(part).replace(path,copy_asset(path)))
    library='[sub_resource type="AnimationLibrary" id="actions"]\n_data = {'+',\n'.join(entries)+'}'
    nodes.append('[node name="Player" type="AnimationPlayer" parent="."]\ncallback_mode_process = 0\ncallback_mode_method = 0\nlibraries = {"": SubResource("actions")}')
    write(f'Scene/Combat/Character{number}Actions.tscn','\n\n'.join(['[gd_scene format=3]','[ext_resource type="Script" path="res://Script/presentation/character_action_timeline.gd" id="runtime"]','[ext_resource type="Script" path="res://Script/actors/animated_attack_hitbox.gd" id="hitbox"]',*externals,*resources,*animations,library,*nodes])+'\n')
    return manifest

if __name__ == '__main__':
    write('content/abilities/action_timelines.json',json.dumps({str(n):migrate(n,s) for n,s in SOURCES.items()},ensure_ascii=False,indent=2))
