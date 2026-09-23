#!/usr/bin/env python3
"""把老角色场景里 Action/SpecialEffect* 的特效轨道合并进新版 Character<N>Actions.tscn。

老项目的普攻/技能特效不是代码 spawn 的，而是角色动作动画里的 value 轨道
直接驱动 Action/SpecialEffect（AnimatedSprite2D）播帧。新版 Actions 场景
缺少这些节点和轨道，本工具负责补上。

用法：
  python3 tools/merge_effect_tracks.py <old_role.tscn> <new_actions.tscn>
"""
import argparse
import os
import re
import sys

# 老项目各角色命名不统一：SpecialEffect / SpecialEffect2 / SpecialEffect1，
# 唐僧额外用 Action/Death 承载死亡表现。
EFFECT_NODES = ("SpecialEffect", "SpecialEffect1", "SpecialEffect2", "Death")
SUB_REF_RE = re.compile(r'SubResource\( ?"([^"]+)" ?\)')
EXT_REF_RE = re.compile(r'ExtResource\( ?"([^"]+)" ?\)')
TRACK_HEADER_RE = re.compile(r'^tracks/(\d+)/')
SUB_START_RE = re.compile(r'^\[sub_resource type="([^"]+)" id="([^"]+)"\]')
EXT_START_RE = re.compile(r'^\[ext_resource type="([^"]+)"(?: uid="[^"]*")? path="([^"]+)" id="([^"]+)"\]')
NODE_START_RE = re.compile(r'^\[node name="([^"]+)"(?: type="([^"]*)")?(?: parent="([^"]*)")?')


class Block:
    def __init__(self, kind: str, lines: "list[str]", name="", res_type="", res_id="", path=""):
        self.kind = kind
        self.lines = lines
        self.name = name
        self.res_type = res_type
        self.res_id = res_id
        self.path = path

    def text(self) -> str:
        return "".join(self.lines)


def parse(path: str) -> "list[Block]":
    blocks = []
    current = None
    for line in open(path, encoding="utf-8"):
        if line.startswith("[") and not line.startswith("[node ") or line.startswith("[node "):
            if current is not None:
                blocks.append(current)
            current = Block("section", [line])
            node = NODE_START_RE.match(line)
            sub = SUB_START_RE.match(line)
            ext = EXT_START_RE.match(line)
            if node:
                current.kind = "node"
                current.name = node.group(1)
                current.res_type = node.group(2) or ""
                current.path = node.group(3) or ""
            elif sub:
                current.kind = "sub"
                current.res_type = sub.group(1)
                current.res_id = sub.group(2)
            elif ext:
                current.kind = "ext"
                current.res_type = ext.group(1)
                current.path = ext.group(2)
                current.res_id = ext.group(3)
            elif line.startswith("[connection"):
                current.kind = "connection"
            else:
                current.kind = "header"
        else:
            if current is None:
                current = Block("header", [line])
            else:
                current.lines.append(line)
    if current is not None:
        blocks.append(current)
    return blocks


def sub_body(block: Block) -> str:
    return "".join(block.lines[1:])


def animation_name(block: Block) -> str:
    match = re.search(r'resource_name = "([^"]+)"', block.text())
    return match.group(1) if match else ""


def extract_tracks(block: Block, node_names: "list[str]") -> "dict[int, list[str]]":
    """取出某动画里所有 Action/SpecialEffect* 的轨道（按 track 序号分组）。"""
    tracks: "dict[int, list[str]]" = {}
    current_index = None
    current_lines: "list[str]" = []
    for line in block.lines:
        header = TRACK_HEADER_RE.match(line)
        if header is None:
            if current_index is not None:
                current_lines.append(line)
            continue
        index = int(header.group(1))
        if current_index is None:
            current_index = index
            current_lines = [line]
            continue
        if index == current_index:
            current_lines.append(line)
            continue
        tracks[current_index] = current_lines
        current_index = index
        current_lines = [line]
    if current_index is not None:
        tracks[current_index] = current_lines
    return {index: lines for index, lines in tracks.items()
            if any('NodePath("Action/%s' % name in "".join(lines) for name in node_names)}


def collect_sub_resources(blocks: "list[Block]", root_ids: "set[str]") -> "list[Block]":
    """按依赖闭包收集子资源（含 SpriteFrames → AtlasTexture → CompressedTexture2D）。"""
    by_id = {block.res_id: block for block in blocks if block.kind == "sub"}
    collected = []
    seen = set()
    queue = list(root_ids)
    while queue:
        res_id = queue.pop()
        if res_id in seen or res_id not in by_id:
            continue
        seen.add(res_id)
        block = by_id[res_id]
        collected.append(block)
        for reference in SUB_REF_RE.findall(block.text()):
            queue.append(reference)
    return collected


def renumber_tracks(track_blocks: "list[list[str]]", start_index: int) -> "list[str]":
    output = []
    for offset, lines in enumerate(track_blocks):
        new_index = start_index + offset
        for line in lines:
            header = TRACK_HEADER_RE.match(line)
            if header:
                output.append("tracks/%d/%s" % (new_index, line.split("/", 2)[2]))
            else:
                output.append(line)
    return output


def merge(old_path: str, new_path: str) -> int:
    old_blocks = parse(old_path)
    new_blocks = parse(new_path)

    effect_nodes = [block for block in old_blocks
                    if block.kind == "node" and block.name in EFFECT_NODES and block.path == "Action"]
    # 老场景里分身/残影等会重复挂同名特效节点，只取第一组（主角本体）。
    old_effect_nodes = list(effect_nodes)
    existing_names = {block.name for block in new_blocks
                      if block.kind == "node" and block.path == "Action"}
    # 新版场景可能已有同名特效节点（含 sprite_frames），只补轨道、不重复插入。
    effect_nodes = [node for node in old_effect_nodes if node.name not in existing_names]
    merged_names = sorted({node.name for node in effect_nodes} | {node.name for node in old_effect_nodes})
    if not merged_names:
        print("老场景里没有 Action 下的 SpecialEffect 节点：%s" % old_path)
        return 1

    frame_ids = set()
    for node in effect_nodes:
        frame_ids.update(re.findall(r'sprite_frames = SubResource\( ?"([^"]+)" ?\)', node.text()))
    if not frame_ids and effect_nodes:
        print("SpecialEffect 节点没有 sprite_frames：%s" % old_path)
        return 1

    copied_subs = collect_sub_resources(old_blocks, frame_ids)
    # 老文件里的顺序满足「被引用者先定义」，直接沿用避免前向引用。
    order = {id(block): index for index, block in enumerate(old_blocks)}
    copied_subs.sort(key=lambda block: order[id(block)])
    id_map = {"%s" % block.res_id: "fx%s" % block.res_id for block in copied_subs}
    ext_ids = set()
    for block in copied_subs:
        ext_ids.update(EXT_REF_RE.findall(block.text()))
    copied_exts = [block for block in old_blocks if block.kind == "ext" and block.res_id in ext_ids]
    for block in copied_exts:
        id_map["ext%s" % block.res_id] = "fx%s" % block.res_id

    # 收集老场景里每个动画的特效轨道
    old_animations = {animation_name(block): block for block in old_blocks
                      if block.kind == "sub" and block.res_type == "Animation" and animation_name(block)}
    effect_tracks = {name: extract_tracks(block, merged_names)
                     for name, block in old_animations.items()}
    effect_tracks = {name: tracks for name, tracks in effect_tracks.items() if tracks}

    # 合并进新场景
    merged = 0
    for block in new_blocks:
        if block.kind != "sub" or block.res_type != "Animation":
            continue
        name = animation_name(block)
        tracks = effect_tracks.get(name)
        if not tracks:
            continue
        existing = {int(index) for index in TRACK_HEADER_RE.findall(block.text())}
        start = max(existing) + 1 if existing else 0
        new_lines = renumber_tracks([tracks[key] for key in sorted(tracks)], start)
        block.lines = block.lines + new_lines
        merged += 1

    def rewrite(text: str) -> str:
        def sub_repl(match: "re.Match") -> str:
            return 'SubResource("fx%s")' % match.group(1) if match.group(1) in id_map else match.group(0)

        def ext_repl(match: "re.Match") -> str:
            return 'ExtResource("fx%s")' % match.group(1) if ("ext%s" % match.group(1)) in id_map else match.group(0)

        text = SUB_REF_RE.sub(sub_repl, text)
        text = EXT_REF_RE.sub(ext_repl, text)
        return text

    def rewrite_own(text: str) -> str:
        """复制过来的块内部引用按映射改写。"""
        def sub_repl(match: "re.Match") -> str:
            return 'SubResource("fx%s")' % match.group(1) if match.group(1) in id_map else match.group(0)

        def ext_repl(match: "re.Match") -> str:
            return 'ExtResource("fx%s")' % match.group(1) if match.group(1) in ext_ids else match.group(0)

        text = SUB_REF_RE.sub(sub_repl, text)
        text = EXT_REF_RE.sub(ext_repl, text)
        return text

    # ext_resource 必须在所有 sub_resource / node 之前，sub_resource 必须在 node 之前。
    ext_insert = next((i for i, block in enumerate(new_blocks) if block.kind in ("sub", "node")), len(new_blocks))
    sub_insert = next((i for i, block in enumerate(new_blocks) if block.kind == "node"), len(new_blocks))
    node_insert = next((i for i, block in enumerate(new_blocks)
                        if block.kind == "node" and block.name == "base_damagebox"), None)
    if node_insert is None:
        print("新场景里没有 base_damagebox 节点，无法插入特效节点：%s" % new_path)
        return 1

    ext_lines = [Block("ext", [re.sub(r'id="[^"]+"', 'id="fx%s"' % copied.res_id, copied.lines[0])],
                       res_id=copied.res_id, path=copied.path, res_type=copied.res_type)
                 for copied in copied_exts]
    sub_lines = [Block("sub", [re.sub(r'id="[^"]+"', 'id="fx%s"' % copied.res_id, copied.lines[0])]
                        + [rewrite_own(line) for line in copied.lines[1:]],
                       res_id=copied.res_id, res_type=copied.res_type)
                 for copied in copied_subs]
    node_lines = [Block("node", [re.sub(r' index="\d+"', "", node.lines[0])]
                        + [rewrite_own(line) for line in node.lines[1:]],
                        name=node.name, res_type=node.res_type)
                  for node in effect_nodes]

    def insert_at(index: int, items: "list[Block]") -> int:
        offset = index
        for item in items:
            new_blocks.insert(offset, item)
            offset += 1
        return offset

    insert_at(ext_insert, ext_lines)
    insert_at(sub_insert + len(ext_lines), sub_lines)
    insert_at(node_insert + len(ext_lines) + len(sub_lines), node_lines)
    output_blocks = new_blocks

    # 新场景原有块里的引用不会被影响（id 前缀不同），但仍统一过一遍防止误伤
    text = "".join(block.text() for block in output_blocks)
    open(new_path, "w", encoding="utf-8").write(text)
    print("merged %s -> %s：动画 %d 个，节点 %d 个，子资源 %d 个，贴图引用 %d 个"
          % (os.path.basename(old_path), os.path.basename(new_path), merged,
             len(effect_nodes), len(copied_subs), len(copied_exts)))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("old_scene")
    parser.add_argument("new_scene")
    args = parser.parse_args()
    return merge(args.old_scene, args.new_scene)


if __name__ == "__main__":
    sys.exit(main())
