"""Retain original UI geometry; replace only scripts, connections and asset paths."""
import re
from migrate_visual_content import ROOT, TARGET, copy_asset

def migrate(source, target, script=None, connections=False):
    text = (ROOT / source).read_text(encoding='utf-8-sig')
    text = re.sub(r' uid="[^"]+"', '', text)
    for path in set(re.findall(r'path="(res://[^"]+)"', text)):
        if path.endswith('.gd'):
            if script:
                text = text.replace(path, 'res://Script/ui/' + script)
            else:
                text = re.sub(r'^\[ext_resource type="Script".*\n', '', text, flags=re.M)
                text = re.sub(r'^script = ExtResource.*\n', '', text, flags=re.M)
        else:
            text = text.replace(path, copy_asset(path))
    if not connections:
        text = re.sub(r'^\[connection.*\n?', '', text, flags=re.M)
    (TARGET / target).parent.mkdir(parents=True, exist_ok=True)
    (TARGET / target).write_text(text, encoding='utf-8')

if __name__ == '__main__':
    migrate('Scene/BackPack/Magic_weapon_infor.tscn', 'Scene/UI/MagicWeaponUpgrade.tscn', 'magic_weapon_upgrade.gd', True)
    migrate('Scene/MagicWeapon/Magic_help.tscn', 'Scene/UI/MagicWeaponHelp.tscn')
    migrate('Scene/Skill/zd_skill.tscn', 'Scene/UI/Skill/ActiveSkills.tscn')
    migrate('Scene/Skill/bd_skill.tscn', 'Scene/UI/Skill/PassiveSkills.tscn')
    migrate('Scene/Skill/SkillKeySet.tscn', 'Scene/UI/Skill/SkillKeySet.tscn')

    for icon in (ROOT / "Art/Skill/SkillIcon").glob("*.png"):
        copy_asset("res://" + icon.relative_to(ROOT).as_posix())

    migrate('Scene/BackPack/skill_select.tscn', 'Scene/UI/MagicWeaponChoice.tscn')
    import json
    source = (ROOT / 'Script/BackPack/skill_select.gd').read_text(encoding='utf-8-sig')
    rows = {}
    for match in re.finditer(r'\t\t"([^"]+)":(.*?)(?=\n\t\t"|\nfunc |\Z)', source, re.S):
        item_id, body = match.groups()
        row = {}
        for key, variable in [('name', 'Wp_name'), ('skill', 'Skill_name'), ('description', 'Skill_Infor')]:
            value = re.search(variable+r'.text = "([^"]*)"', body)
            if value: row[key] = value.group(1)
        icon = re.search(r'Skill_Icon.texture = load\("([^"]+)"',body)
        if icon:row['icon'] = copy_asset(icon.group(1))
        if row:rows[item_id] = row
    (TARGET / 'content/combat/relic_presentation.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
