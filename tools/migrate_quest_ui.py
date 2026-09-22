"""Preserve the legacy task window and reusable rows, replacing runtime bindings."""
from migrate_visual_content import attribute, clean, copy_asset, sections, write


def migrate(source, destination, scene_mapping=None, script_path=""):
    output = ['[gd_scene format=3]']
    for part in sections(source):
        if part.startswith('[gd_scene') or part.startswith('[connection'):
            continue
        if part.startswith('[ext_resource'):
            resource_type = attribute(part, 'type')
            if resource_type == 'Script':
                continue
            original_path = attribute(part, 'path')
            path = scene_mapping[original_path] if resource_type == 'PackedScene' else copy_asset(original_path)
            part = clean(part).replace(original_path, path)
        else:
            part = clean(part)
        if part.startswith('[node') and ' parent=' not in part.splitlines()[0]:
            if script_path:
                part = part.replace('name="BasicTask" type="Node2D"', 'name="QuestJournal" type="Control"')
                part += '\nprocess_mode = 3\nlayout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nscript = ExtResource("runtime")'
            if source.endswith('TaskTitle.tscn'):
                part += '\ntoggle_mode = true'
        output.append(part)
    if script_path:
        output.insert(1, f'[ext_resource type="Script" path="{script_path}" id="runtime"]')
    write(destination, '\n\n'.join(output) + '\n')


if __name__ == '__main__':
    migrate('Scene/BackPack/Box_1.tscn', 'Scene/UI/QuestRewardIcon.tscn')
    migrate('Scene/Task/TaskReward.tscn', 'Scene/UI/QuestReward.tscn', {'res://Scene/BackPack/Box_1.tscn': 'res://Scene/UI/QuestRewardIcon.tscn'})
    migrate('Scene/Task/TaskTitle.tscn', 'Scene/UI/QuestTitle.tscn')
    migrate('Scene/Task/BasicTask.tscn', 'Scene/UI/QuestJournal.tscn', script_path='res://Script/ui/quest_screen.gd')
