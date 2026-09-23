#!/usr/bin/env python3
"""为待迁移的老场景补齐缺失的贴图源文件。

老项目只保留了 .import 元数据，PNG 本体需要从导出缓存 ctex 还原：
先把 ctex 拷进 assets/.ctex_tmp，再交给 tools/extract_ctex.gd 转成 PNG。

用法：python3 tools/extract_missing_textures.py <old_scene> [<old_scene> ...]
"""
import json
import os
import re
import shutil
import sys

OLD = "oldproject/zaomeng-bahuang"
TMP = "assets/.ctex_tmp"
MANIFEST = "tools/ctex_manifest.json"


def ctex_index() -> dict:
    """ctex 文件名 -> 绝对路径。"""
    index = {}
    for base, _dirs, files in os.walk(os.path.join(OLD, "godot", "imported")):
        for name in files:
            if name.endswith(".ctex"):
                index[name] = os.path.join(base, name)
    return index


def source_index() -> dict:
    """老 res:// 源路径 -> ctex 文件名（由 .import 位置反推）。"""
    index = {}
    for base, _dirs, files in os.walk(OLD):
        if os.path.join("godot", "imported") in base:
            continue
        for name in files:
            if not name.endswith(".import"):
                continue
            path = os.path.join(base, name)
            try:
                text = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            source = "res://" + os.path.relpath(path[:-len(".import")], OLD).replace(os.sep, "/")
            for dest in re.findall(r'"(res://godot/imported/[^"]+\.ctex)"', text):
                index[source] = os.path.basename(dest)
    return index


def main() -> int:
    scenes = sys.argv[1:]
    if not scenes:
        print("用法：python3 tools/extract_missing_textures.py <old_scene> ...")
        return 1
    ctexs = ctex_index()
    sources = source_index()
    entries = []
    seen = set()
    for scene in scenes:
        try:
            text = open(scene, encoding="utf-8", errors="replace").read()
        except OSError:
            print("读不到场景：%s" % scene)
            continue
        for res in re.findall(r'path="(res://[^"]+)"', text):
            if res.startswith("res://godot/") or res in seen:
                continue
            sub = res[len("res://"):]
            if os.path.isfile(os.path.join("assets", sub)) or os.path.isfile(sub) \
                    or os.path.isfile(os.path.join(OLD, sub)):
                continue
            ctex = sources.get(res)
            if ctex is None or ctex not in ctexs:
                print("无法定位缓存：%s" % res)
                continue
            seen.add(res)
            entries.append((ctexs[ctex], os.path.join("assets", sub)))
    if not entries:
        print("贴图齐全，无需还原")
        return 0
    if os.path.isdir(TMP):
        shutil.rmtree(TMP)
    os.makedirs(TMP, exist_ok=True)
    manifest = []
    for position, (ctex, out) in enumerate(entries):
        tmp = "%s/%d.ctex" % (TMP, position)
        shutil.copyfile(ctex, tmp)
        manifest.append({"ctex": "res://" + tmp, "out": out.replace(os.sep, "/")})
    json.dump(manifest, open(MANIFEST, "w"))
    print("待还原贴图 %d 张，manifest 已生成：%s" % (len(manifest), MANIFEST))
    return 0


if __name__ == "__main__":
    sys.exit(main())
