"""Extract shared original projectile timelines, including visual sublayers and collision."""
import re,json
from migrate_visual_content import sections, attribute, clean, copy_asset, resource_closure, write

def extract(name):
    original=sections('Scene/Hero/RoleBullet.tscn')
    library = next(p for p in original if p.startswith('[sub_resource type="AnimationLibrary"'))
    resource_id = re.search(r'"'+name+r'": SubResource\(\s*"([^"]+)"',library).group(1)
    source=next(p for p in original if p.startswith('[sub_resource type="Animation"') and attribute(p,'id') == resource_id)
    head=re.split(r'^tracks/0/type',source,flags=re.M)[0]
    head=re.sub(r'^loop_mode = .*\n?', '', head,flags=re.M)
    identifier=attribute(head,'id')
    tracks=[]; windows=[]; names={'BulletPlayer':set(),'SpecialEffect':set()}
    for track in re.split(r'(?=^tracks/\d+/type =)',source,flags=re.M)[1:]:
        m=re.search(r'path = NodePath\("([^\"]+)"\)',track)
        if not m:continue
        path=m.group(1)
        if '/type = "value"' not in track or path.split(':')[0] not in ['BulletPlayer','SpecialEffect','HitBox/Collion']:continue
        if path.endswith(':animation'):
            names[path.split(':')[0]].update(re.findall(r'&"([^\"]+)"',track))
        if path.endswith(':disabled'):
            times=re.search(r'"times": PackedFloat32Array\(([^)]+)\)',track).group(1).split(',')
            values=re.search(r'"values": \[([^]]+)\]',track).group(1).split(',')
            windows += [float(t) for t,v in zip(times,values) if v.strip()=='false']
        tracks.append(re.sub(r'tracks/\d+/',f'tracks/{len(tracks)}/',track))
    frames=[]
    for node, frame_id in [('BulletPlayer','675'),('SpecialEffect','978')]:
        section=next(p for p in original if p.startswith(f'[sub_resource type="SpriteFrames" id="{frame_id}"]'))
        entries=re.findall(r'\{\s*"frames": \[.*?\],\s*"loop": .*?\n\}',section,re.S)
        chosen=[e for e in entries if any(f'"name": &"{n}"' in e for n in names[node])]
        if not chosen: chosen=[e for e in entries if '"name": &"Empty"' in e or '"name": &"empty"' in e][:1]
        frames.append(f'[sub_resource type="SpriteFrames" id="frames_{node}"]\nanimations = ['+','.join(chosen)+']')
    if windows:
        i=len(tracks)
        tracks.append(f'tracks/{i}/type = "method"\ntracks/{i}/path = NodePath("HitBox")\ntracks/{i}/keys = {{"times": PackedFloat32Array('+','.join(map(str,windows))+'), "transitions": PackedFloat32Array('+','.join('1' for _ in windows)+'), "values": ['+','.join('{"args": [], "method": &"begin_hit_window"}' for _ in windows)+']}')
    animation=head+'\n'+'\n'.join(tracks)
    roots=re.findall(r'SubResource\(\s*"([^\"]+)"\s*\)','\n'.join(frames+[animation]))
    resources=resource_closure(original,roots)
    ext_ids=set(re.findall(r'ExtResource\(\s*"([^\"]+)"\s*\)','\n'.join(resources)))
    externals=[]
    for part in original:
        if part.startswith('[ext_resource') and attribute(part,'id') in ext_ids:
            path=attribute(part,'path');externals.append(clean(part).replace(path,copy_asset(path)))
    nodes=f'''[node name="{name}" type="Node2D"]
script = ExtResource("runtime")
animation_name = &"{name}"
[node name="Middle" type="Node2D" parent="."]
[node name="BulletPlayer" type="AnimatedSprite2D" parent="Middle"]
sprite_frames = SubResource("frames_BulletPlayer")
[node name="SpecialEffect" type="AnimatedSprite2D" parent="Middle"]
sprite_frames = SubResource("frames_SpecialEffect")
offset = Vector2(0, -40)
[node name="HitBox" type="Area2D" parent="Middle"]
script = ExtResource("hitbox")
collision_layer = 0
collision_mask = 2
[node name="Collion" type="CollisionShape2D" parent="Middle/HitBox"]
disabled = true
[node name="BulletPlayers" type="AnimationPlayer" parent="Middle"]
callback_mode_process = 0
callback_mode_method = 1
libraries = {{"": SubResource("library")}}
'''
    library=f'[sub_resource type="AnimationLibrary" id="library"]\n_data = {{"{name}": SubResource("{identifier}")}}'
    write(f'Scene/Combat/Spells/{name}.tscn','\n\n'.join(['[gd_scene format=3]','[ext_resource type="Script" path="res://Script/actors/timeline_attack.gd" id="runtime"]','[ext_resource type="Script" path="res://Script/actors/animated_attack_hitbox.gd" id="hitbox"]',*externals,*resources,*frames,animation,library,nodes]))

if __name__=='__main__':
    for name in ['Role2Bullet3','Role2Bullet4','Role2Bullet5','Role2Bullet6','Role3Bullet1','Role3Bullet2','Role3Bullet3','Role4Bullet3','Role4Bullet6','Role5Bullet1','Role5Bullet2','Role5Bullet3','Role5Bullet4','Role5Bullet5']:
        extract(name)
