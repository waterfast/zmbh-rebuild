"""Extract the two Tang Sanzang attack timelines and only their reachable textures."""
import re

from migrate_visual_content import attribute, clean, copy_asset, resource_closure, sections, write


def extract_attack(animation_name, animation_id, scene_name, window_times):
    original = sections("Scene/Hero/RoleBullet.tscn")
    frames = next(part for part in original if part.startswith('[sub_resource type="SpriteFrames" id="675"]'))
    entries = re.findall(r'\{\s*"frames": \[.*?\],\s*"loop": .*?\n\}', frames, re.S)
    entry = next(value for value in entries if f'"name": &"{animation_name}"' in value)
    selected_frames = '[sub_resource type="SpriteFrames" id="frames"]\nanimations = [' + entry + ']'
    animation = next(part for part in original if part.startswith(f'[sub_resource type="Animation" id="{animation_id}"]'))
    animation = clean(animation)
    animation = re.sub(r'tracks/11/type = .*', '', animation, flags=re.S)
    animation = animation.replace('"method": &"free"', '"method": &"finish"')
    next_track = 11
    times = ', '.join(str(value) for value in window_times)
    transitions = ', '.join('1' for _ in window_times)
    values = ', '.join('{"args": [], "method": &"begin_hit_window"}' for _ in window_times)
    animation += f'''\ntracks/{next_track}/type = "method"
tracks/{next_track}/path = NodePath("HitBox")
tracks/{next_track}/keys = {{
"times": PackedFloat32Array({times}),
"transitions": PackedFloat32Array({transitions}),
"values": [{values}]
}}
'''
    reachable_ids = re.findall(r'SubResource\(\s*"([^"]+)"\s*\)', selected_frames + animation)
    resources = resource_closure(original, reachable_ids)
    external_ids = set(re.findall(r'ExtResource\(\s*"([^"]+)"\s*\)', '\n'.join(resources)))
    external = []
    for part in original:
        if part.startswith('[ext_resource') and attribute(part, 'id') in external_ids:
            path = attribute(part, 'path')
            external.append(clean(part).replace(path, copy_asset(path)))
    script_resources = [
        '[ext_resource type="Script" path="res://Script/actors/timeline_attack.gd" id="runtime"]',
        '[ext_resource type="Script" path="res://Script/actors/animated_attack_hitbox.gd" id="hitbox"]',
    ]
    library = f'''[sub_resource type="AnimationLibrary" id="library"]
_data = {{
"{animation_name}": SubResource("{animation_id}")
}}'''
    nodes = f'''[node name="{scene_name}" type="Node2D"]
script = ExtResource("runtime")
animation_name = &"{animation_name}"

[node name="Middle" type="Node2D" parent="."]

[node name="BulletPlayer" type="AnimatedSprite2D" parent="Middle"]
sprite_frames = SubResource("frames")
animation = &"{animation_name}"

[node name="HitBox" type="Area2D" parent="Middle"]
script = ExtResource("hitbox")
collision_layer = 0
collision_mask = 2
monitorable = false

[node name="Collion" type="CollisionShape2D" parent="Middle/HitBox"]
disabled = true

[node name="BulletPlayers" type="AnimationPlayer" parent="Middle"]
callback_mode_process = 0
callback_mode_method = 1
libraries = {{
"": SubResource("library")
}}'''
    output = ['[gd_scene format=3]', *script_resources, *external, *resources, selected_frames, animation, library, nodes]
    write(f'Scene/Combat/{scene_name}.tscn', '\n\n'.join(output) + '\n')


if __name__ == '__main__':
    extract_attack('Role2Bullet1', '989', 'TangSanzangNormal', [0.0])
    extract_attack('Role2Bullet2', '991', 'IceDragonWave', [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2])
