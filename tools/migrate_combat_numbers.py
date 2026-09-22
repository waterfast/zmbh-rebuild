"""Convert original combat constants and arithmetic to data, without executing old scripts."""
import ast,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];TARGET=ROOT/'refactor'
def expression(text):
    text=text.replace('RoleProp.roleprop.power','attack').replace('RoleProp.roleprop.SHp','max_hp')
    text=text.replace('RoleProp.baseroleprop.Level','hero_level').replace('RoleProp.roleprop.Def','hero_defense').replace('RoleProp.roleprop.Mdef','hero_magic_defense').replace('BeHitCount','received_hits')
    text=re.sub(r'get_SkillLevel\(\d+\)', 'skill_level', text)
    text=re.sub(r'level_10\b','passive_level',text)
    text=re.sub(r'level_\d+\b','skill_level',text)
    def convert(node):
        if isinstance(node,ast.Constant) and isinstance(node.value,(float,int)):return node.value
        if isinstance(node,ast.Name) and node.id in ['attack','max_hp','skill_level','passive_level','hero_level','hero_defense','hero_magic_defense','received_hits','up_power']:return {'variable':node.id}
        if isinstance(node,ast.BinOp) and type(node.op) in (ast.Add,ast.Sub,ast.Mult,ast.Div):return {'operation':type(node.op).__name__,'left':convert(node.left),'right':convert(node.right)}
        if isinstance(node,ast.UnaryOp) and isinstance(node.op,ast.USub):return {'operation':'Mult','left':-1,'right':convert(node.operand)}
        if isinstance(node,ast.Call) and isinstance(node.func,ast.Name) and node.func.id == 'int': return {'integer':convert(node.args[0])}
        if isinstance(node,ast.Call) and isinstance(node.func,ast.Name) and node.func.id in ['randf_range','randi_range']:
            return {'random':node.func.id,'min':convert(node.args[0]),'max':convert(node.args[1])}
        raise ValueError(text)
    return convert(ast.parse(text.strip(),mode='eval').body)

def main():
    skills={}; skipped=[]
    for role in range(1,6):
        path=ROOT/f'Script/Hero/{"Role1" if role==1 else "Role_"+str(role)}.gd'
        text=path.read_text(encoding='utf-8-sig');rows={}
        for match in re.finditer(r'(?:self\.)?objattackDic\["([^"]+)"\]\s*=\s*\{(.*?)(?=\n\t\})',text,re.S):
            name,body=match.groups()
            power=re.search(r'"power":\s*(.+),\s*$',body,re.M)
            kind=re.search(r'"attackKind":\s*"([^"]*)"',body)
            knock=re.search(r'"hurtBack":\s*\[([^]]+)\]',body)
            if not power:continue
            try:tree=expression(power.group(1))
            except ValueError:skipped.append([role,name,power.group(1)]);continue
            rows[name]={'power':tree,'damage_type':{'physics':0,'magic':1,'real':2,'':2}[kind.group(1)] if kind else 0}
            if knock:
                try:rows[name]['knockback']=[float(n) for n in knock.group(1).split(',')]
                except ValueError:pass
        skills[str(role)]=rows
    monsters={}
    fields={'level':'level','SHp':'max_hp','def':'defense','mdef':'magic_defense','crit':'critical_chance','miss':'dodge_chance','lucky':'luck','Htarget':'accuracy','Toughness':'toughness','ar':'armor_penetration','sp':'magic_penetration','Critreduce':'critical_reduction','self_rhp':'hp_regen'}
    ratings={'crit','miss','Htarget','Toughness','Critreduce'}
    for path in (ROOT/'Script/Monster').glob('Monster_*.gd'):
        if not re.fullmatch('Monster_\d+',path.stem):continue
        text='\n'.join(line.split('#')[0] for line in path.read_text(encoding='utf-8-sig').splitlines());row={}
        for old,new in fields.items():
            m=re.search(r'^\s*self\.'+old+r'\s*=\s*(.+)$',text,re.M)
            if not m:continue
            try: value=expression(m.group(1))
            except (ValueError,SyntaxError): continue
            if old in ratings:
                value={'operation':'Div','left':{'integer':value},'right':100}
            elif old != 'Toughness':value={'integer':value}
            row[new]=value
        first=re.search(r'objattackDic\["hit1"\]\s*=\s*\{\s*"power":\s*([^\n]+)',text)
        if not first:first=re.search(r'"power":\s*([^\n]+)',text)
        if first:
            try:row['attack']=expression(first.group(1).rstrip(', '))
            except (ValueError,SyntaxError):pass
        speed=re.search(r'^\s*self.speed\s*=\s*([\d.]+)\s*$',text,re.M)
        if speed:row['move_speed']=float(speed.group(1))*10
        if row:monsters[path.stem.split('_')[1]]=row
    folder=TARGET/'content/combat';folder.mkdir(parents=True,exist_ok=True)
    (folder/'character_hits.json').write_text(json.dumps(skills,ensure_ascii=False,indent=2),encoding='utf-8')
    (folder/'monsters.json').write_text(json.dumps(monsters,ensure_ascii=False,indent=2),encoding='utf-8')
    # Read the primary cast's cooldown, not secondary follow-up or shared cooldown writes.
    mana_source=(ROOT/'Script/Base/BaseHero.gd').read_text(encoding='utf-8-sig').split('func get_need_mp',1)[1].split('\n\telse:',1)[0]
    mana={key:expression(body) for key,body in re.findall(r'"([^"\n]+)":\s*return ([^\n]+)',mana_source)}
    for role in range(1,6):
        source=(ROOT/f'Script/Hero/{"Role1" if role==1 else "Role_"+str(role)}.gd').read_text(encoding='utf-8-sig')
        functions={m.group(1):m.group(2) for m in re.finditer(r'^func do_([^(]+)\([^\n]*\):([^\n]*(?:\n(?!func ).*)*)',source,re.M)}
        for path in (TARGET/'content/abilities/legacy').glob('*.json'):
            data=json.loads(path.read_text(encoding='utf-8'))
            if data.get('character_id')!=role or data.get('passive'):continue
            key=data['legacy_id'];body=functions.get(key,'')
            cd=re.search(r'Role1SkillInter\["'+key+r'"\]\s*=\s*([\d.]+)',body)
            if cd:data['cooldown']=float(cd.group(1))
            if key in mana:data['mp_expression']=mana[key]
            data['icon_path']=f'res://assets/Art/Skill/SkillIcon/{key}.png'
            data['migration_note']='场景、伤害表达式、耗蓝和主施放冷却来自原项目；特殊状态及派生攻击需逐项验收，不能据此认定整个技能等价。'
            path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Extracted hits:' ,sum(map(len,skills.values())),'monsters:',len(monsters),'unsupported expressions:',skipped)
if __name__=='__main__':main()
