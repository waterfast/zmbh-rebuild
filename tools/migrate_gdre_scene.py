#!/usr/bin/env python3
"""把 gdre 反编译的老项目场景迁移进重构项目。

功能：
1. fix     —— 就地修复新项目场景里失效的 CompressedTexture2D.load_path
              （老 hash 基于老 res:// 路径，需换成新路径的 md5）。
2. migrate —— 拷贝老场景到新路径，同时修复 load_path / ext_resource 路径 /
              替换脚本 / 去掉 uid。

用法：
  python3 tools/migrate_gdre_scene.py fix Scene/Combat/Character1Actions.tscn ...
  python3 tools/migrate_gdre_scene.py migrate <old.tscn> <new.tscn> \
      [--script res://old.gd=res://new.gd ...] [--drop-node NAME ...]
"""
import argparse
import hashlib
import os
import re
import shutil
import sys

OLD_ROOT = "oldproject/zaomeng-bahuang"
NEW_ROOT = "."

IMPORT_RE = re.compile(r'load_path = "(res://godot/imported/[^"]+)"')
EXT_RE = re.compile(r'(\[ext_resource type="[^"]+"(?: uid="[^"]*")? path=")(res://[^"]+)(")')
UID_RE = re.compile(r' uid="[^"]*"')


def build_import_map() -> dict:
    """老项目 .import 文件 → {ctex 文件名: 老 source res:// 路径}。"""
    mapping = {}
    for base, _dirs, files in os.walk(OLD_ROOT):
        for name in files:
            if not name.endswith(".import"):
                continue
            path = os.path.join(base, name)
            # 老 .import 没有 source_file 键，但 .import 就在源文件旁边，按位置反推。
            source = "res://" + os.path.relpath(path[:-len(".import")], OLD_ROOT).replace(os.sep, "/")
            try:
                text = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            for dest in re.findall(r'"(res://godot/imported/[^"]+\.ctex)"', text) + \
                    re.findall(r'path="(res://godot/imported/[^"]+\.ctex)"', text):
                mapping[os.path.basename(dest)] = source
    return mapping


def find_in_new_project(source_res: str) -> "str | None":
    """老 source res:// 路径 → 新项目里已存在的 res:// 路径（找不到返回 None）。"""
    sub = source_res[len("res://"):]
    for candidate in (os.path.join("assets", sub), sub, os.path.join("content", sub)):
        if os.path.isfile(candidate):
            return "res://" + candidate.replace(os.sep, "/")
    return None


def copy_into_assets(source_res: str) -> str:
    """把老文件拷到 assets/ 下保持子路径，返回新 res:// 路径。"""
    sub = source_res[len("res://"):]
    dest = os.path.join("assets", sub)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    src = os.path.join(OLD_ROOT, sub)
    if os.path.isfile(src):
        shutil.copyfile(src, dest)
    else:
        raise FileNotFoundError("老项目里也找不到资源：%s" % source_res)
    return "res://" + dest.replace(os.sep, "/")


class SceneMigrator:
    def __init__(self) -> None:
        self.import_map = build_import_map()
        self.copied = []
        self.missing = []

    def new_load_path(self, old_ctex: str) -> "str | None":
        base = os.path.basename(old_ctex)
        source = self.import_map.get(base)
        if source is None:
            # 没有对应 .import：按文件名在老项目里搜一次
            hits = []
            for base_dir, _dirs, files in os.walk(OLD_ROOT):
                if "godot/imported" in base_dir:
                    continue
                if base.rsplit("-", 1)[0] in files:
                    hits.append("res://" + os.path.relpath(os.path.join(base_dir, base.rsplit("-", 1)[0]), OLD_ROOT).replace(os.sep, "/"))
            if len(hits) == 1:
                source = hits[0]
            else:
                self.missing.append(old_ctex)
                return None
        new_res = find_in_new_project(source)
        if new_res is None:
            new_res = copy_into_assets(source)
            self.copied.append(new_res)
        digest = hashlib.md5(new_res.encode()).hexdigest()
        return "res://.godot/imported/%s-%s.ctex" % (os.path.basename(new_res), digest)

    def new_ext_path(self, res_path: str) -> str:
        if res_path.startswith("res://godot/"):
            return res_path
        new_res = find_in_new_project(res_path)
        if new_res is None:
            new_res = copy_into_assets(res_path)
            self.copied.append(new_res)
        return new_res

    def fix_text(self, text: str, script_map: "dict[str, str] | None" = None,
                 drop_nodes: "list[str] | None" = None) -> str:
        def repl_load(match: "re.Match") -> str:
            fixed = self.new_load_path(match.group(1))
            return 'load_path = "%s"' % fixed if fixed else match.group(0)

        text = IMPORT_RE.sub(repl_load, text)

        def repl_ext(match: "re.Match") -> str:
            path = match.group(2)
            if script_map and path in script_map:
                path = script_map[path]
            else:
                path = self.new_ext_path(path)
            return match.group(1) + path + match.group(3)

        text = EXT_RE.sub(repl_ext, text)
        text = UID_RE.sub("", text)
        if drop_nodes:
            text = drop_node_blocks(text, drop_nodes)
        return text


def drop_node_blocks(text: str, names: "list[str]") -> str:
    """删除 [node name="X" ...] 块及其子节点块和相关 connection。"""

    def dropped(header_name: str, parent: str) -> bool:
        if header_name in names:
            return True
        return any(part in names for part in parent.split("/") if part)

    blocks = re.split(r"(?=\[node |\[connection |\[editable)", text)
    kept = []
    for block in blocks:
        header = re.match(r'\[node name="([^"]+)"[\s\S]*?parent="([^"]*)"', block)
        if header:
            if dropped(header.group(1), header.group(2)):
                continue
        elif block.startswith("[connection"):
            targets = re.findall(r'(?:from|to)="([^"]+)"', block)
            if any(any(part in names for part in target.split("/") if part) for target in targets):
                continue
        kept.append(block)
    return "".join(kept)


def cmd_fix(paths: "list[str]") -> int:
    migrator = SceneMigrator()
    for path in paths:
        text = open(path, encoding="utf-8").read()
        fixed = migrator.fix_text(text)
        open(path, "w", encoding="utf-8").write(fixed)
        print("fixed %s" % path)
    report(migrator)
    return 0


def cmd_migrate(args: argparse.Namespace) -> int:
    migrator = SceneMigrator()
    script_map = dict(item.split("=") for item in args.script or [])
    text = open(args.source, encoding="utf-8").read()
    fixed = migrator.fix_text(text, script_map, args.drop_node)
    os.makedirs(os.path.dirname(args.target), exist_ok=True)
    open(args.target, "w", encoding="utf-8").write(fixed)
    print("migrated %s -> %s" % (args.source, args.target))
    report(migrator)
    return 0 if not migrator.missing else 1


def report(migrator: SceneMigrator) -> None:
    if migrator.copied:
        print("拷贝资源 %d 个：", len(migrator.copied))
        for item in sorted(set(migrator.copied)):
            print("  +", item)
    if migrator.missing:
        print("警告：以下导入缓存找不到源文件，保留原样：")
        for item in sorted(set(migrator.missing)):
            print("  ?", item)


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    fix = sub.add_parser("fix")
    fix.add_argument("paths", nargs="+")
    migrate = sub.add_parser("migrate")
    migrate.add_argument("source")
    migrate.add_argument("target")
    migrate.add_argument("--script", action="append")
    migrate.add_argument("--drop-node", action="append", default=[])
    args = parser.parse_args()
    if args.command == "fix":
        return cmd_fix(args.paths)
    return cmd_migrate(args)


if __name__ == "__main__":
    sys.exit(main())
