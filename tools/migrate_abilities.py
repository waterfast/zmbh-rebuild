"""Extract original skill metadata without executing or changing legacy scripts."""

import ast
import json
import re
from pathlib import Path


def dictionary(source: str, name: str) -> dict:
    match = re.search(r"var " + re.escape(name) + r"\s*=\s*(\{.*?\})", source, re.S)
    if match is None:
        raise ValueError(f"Missing original dictionary: {name}")
    return ast.literal_eval(match.group(1))


def effects_for(skill_id: str) -> list[dict]:
    if skill_id == "blb":
        return [{"kind": "projectile", "power_scale": 0.55, "damage_type": 1}]
    if skill_id == "tjgl":
        return [{"kind": "heal", "maximum_ratio": 0.18, "missing_ratio": 0.20}]
    if skill_id == "myhc":
        return [{"kind": "self_buff", "buff": {"id": "regeneration", "duration": 5.0, "tick_interval": 1.0, "tick_heal_maximum_ratio": 0.04}}]
    if skill_id == "sd":
        return [{"kind": "self_buff", "buff": {"id": "holy_shield", "tag": "super_armor", "duration": 4.0, "tick_interval": 1.0, "tick_heal_maximum_ratio": 0.03}}]
    if skill_id == "wdzt":
        return [{"kind": "self_buff", "buff": {"id": "poison_ward", "tag": "super_armor", "duration": 4.0, "flat_modifiers": {"damage_reduction": 0.15}}}]
    if skill_id in {"lys", "fhf"}:
        return [{"kind": "self_buff", "buff": {"id": "dash_invulnerable", "tag": "invulnerable", "duration": 0.18}}, {"kind": "dash", "speed": 650.0, "duration": 0.18}]
    if skill_id in {"hytj", "blq"}:
        return [{"kind": "self_buff", "buff": {"id": "dash_armor", "tag": "super_armor", "duration": 0.22}}, {"kind": "dash", "speed": 560.0, "duration": 0.22}, {"kind": "melee", "power_scale": 1.2, "lifetime": 0.22}]
    if skill_id in {"zz", "qlj", "slz", "slq"}:
        return [{"kind": "melee", "power_scale": 1.35, "size_scale": [1.35, 1.1]}]
    if skill_id == "zq":
        return [{"kind": "projectile", "power_scale": 0.7, "damage_type": 1, "buff": {"id": "poison", "tag": "poison", "duration": 5.0, "tick_interval": 1.0, "tick_damage": 4.0}}]
    return []


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    legacy = project.parent
    source = (legacy / "Script/Skill/zd_skill.gd").read_text(encoding="utf-8-sig")
    ids = dictionary(source, "Skill_list")
    names = dictionary(source, "Skill_Name")
    descriptions = dictionary(source, "Skill_Infor")
    hero = (legacy / "Script/Base/BaseHero.gd").read_text(encoding="utf-8-sig")
    mana_section = hero.split("func get_need_mp", 1)[1].split("\n\telse:", 1)[0]
    mana_costs = dict(re.findall(r'"([a-z0-9]+)":\s*return\s+(\d+)', mana_section))
    output = project / "content/abilities/legacy"
    output.mkdir(parents=True, exist_ok=True)
    index = {}
    for character, skill_ids in ids.items():
        for slot, skill_id in enumerate(skill_ids):
            effects = effects_for(skill_id)
            data = {
                "id": skill_id,
                "legacy_id": skill_id,
                "display_name": names[character][slot],
                "description": descriptions[character][slot],
                "character_id": int(character.removeprefix("角色")),
                "slot": slot + 1,
                "passive": slot == 9,
                "mp_cost": int(mana_costs.get(skill_id, 0)),
                "cooldown": 2.4,
                "cast_duration": 0.3,
                "migration_status": "prototype" if effects else "metadata_only",
                "migration_note": "名称、描述、槽位和一级消耗来自原版；效果组合为可运行原型，尚未逐帧还原位移/多段/特殊机制；冷却使用原型值。" if effects else "已迁移原版元数据；此技能独有行为尚未实现，不能施放。",
                "effects": effects,
            }
            (output / f"{skill_id}.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            index[skill_id] = f"res://content/abilities/legacy/{skill_id}.json"
    (project / "content/abilities/index.json").write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Migrated {len(index)} skill records; {sum(bool(effects_for(skill)) for skill in index)} executable prototypes.")


if __name__ == "__main__":
    main()
