#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
local_jar_diff.py —— 本地测试服部署用的 jar 逐条目差异分析

比较「gradle 编译产物（serverlogic-1.0.0.jar）」与「本地服正在跑的 gameSrv-1.0.0.jar」，
把条目分成四类，决定「哪些要注入 / 哪些必须保留」：

  changed     同名但 CRC 不同                → 注入
  new         编译产物有、本地 jar 没有        → 注入（新增类）
  local_only  本地 jar 有、编译产物没有        → **保留**（overlay 资源 / 历史热补丁类）
  excluded    命中排除规则                    → 永不注入

为什么是「注入差异」而不是「整包替换」：
  1. 编译产物里的 `application.properties` 是 src/main/resources 的**开发配置**
     （server.id=70001 / 远程 Mongo），本地服那份是对着 127.0.0.1 改过的；
     `logback-boot.xml` 同理。
  2. `META-INF/MANIFEST.MF` 里的 `Class-Path` 是本地 82 个 lib 的引用表，
     覆盖它等于把整条依赖链换掉。
  3. 本地 jar 里可能存在源码中已不存在的**补丁类**（历史上 SysUtil 就丢过一次），
     整包替换会静默丢掉它们。
  ⇒ 只动 CRC 真的变了的类，其余一律不碰。

用法：
  local_jar_diff.py --src <编译产物 jar> --dst <本地 jar> \
      [--json out.json] [--list inject.list] [--staging DIR] [--exclude REGEX] [--quiet]

退出码：
  0  正常（结论可能为「无变化」）
  1  文件缺失 / 不是合法 zip
  2  参数错误
"""

import argparse
import json
import os
import re
import shutil
import sys
import zipfile

# 永不注入的前缀 / 后缀（与 .jenkins/lib/server_release.sh 的注入边界保持一致）
DEFAULT_EXCLUDE_PREFIXES = ("META-INF/",)
DEFAULT_EXCLUDE_SUFFIXES = (".properties", ".xml")


def load_entries(path):
    """返回 {条目名: CRC}，目录条目与 zip 元数据不算。"""
    if not os.path.isfile(path):
        raise FileNotFoundError(path)
    if not zipfile.is_zipfile(path):
        raise ValueError("不是合法 zip：%s" % path)
    out = {}
    with zipfile.ZipFile(path) as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
            out[info.filename] = info.CRC
    return out


def is_excluded(name, extra):
    if name.startswith(DEFAULT_EXCLUDE_PREFIXES):
        return True
    if name.lower().endswith(DEFAULT_EXCLUDE_SUFFIXES):
        return True
    for rx in extra:
        if rx.search(name):
            return True
    return False


def main():
    ap = argparse.ArgumentParser(description="jar 逐条目差异分析（本地测试服部署用）")
    ap.add_argument("--src", required=True, help="编译产物 jar")
    ap.add_argument("--dst", required=True, help="本地服 gameSrv jar")
    ap.add_argument("--json", default="", help="结论 JSON 输出路径")
    ap.add_argument("--list", default="", help="注入清单（每行一个条目名）")
    ap.add_argument("--staging", default="", help="把要注入的条目解压到此目录并 touch")
    ap.add_argument("--exclude", action="append", default=[], help="追加排除正则（可多次）")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    extra = []
    for raw in args.exclude:
        try:
            extra.append(re.compile(raw))
        except re.error as exc:
            print("排除正则非法：%s (%s)" % (raw, exc), file=sys.stderr)
            return 2

    try:
        src = load_entries(args.src)
        dst = load_entries(args.dst)
    except FileNotFoundError as exc:
        print("找不到文件：%s" % exc, file=sys.stderr)
        return 1
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    changed, new, excluded, local_only = [], [], [], []
    for name, crc in src.items():
        if is_excluded(name, extra):
            excluded.append(name)
        elif name not in dst:
            new.append(name)
        elif dst[name] != crc:
            changed.append(name)
    for name in dst:
        if name not in src:
            local_only.append(name)

    changed.sort()
    new.sort()
    excluded.sort()
    local_only.sort()
    inject = changed + new

    result = {
        "src_jar": os.path.abspath(args.src),
        "dst_jar": os.path.abspath(args.dst),
        "counts": {
            "src": len(src),
            "dst": len(dst),
            "changed": len(changed),
            "new": len(new),
            "inject": len(inject),
            "excluded": len(excluded),
            "local_only": len(local_only),
        },
        "changed": changed,
        "new": new,
        "excluded": excluded,
        "local_only": local_only,
    }

    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)) or ".", exist_ok=True)
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(result, fh, ensure_ascii=False, indent=2)

    if args.list:
        with open(args.list, "w", encoding="utf-8") as fh:
            fh.write("\n".join(inject) + ("\n" if inject else ""))

    if args.staging and inject:
        os.makedirs(args.staging, exist_ok=True)
        with zipfile.ZipFile(args.src) as zf:
            for name in inject:
                dest = os.path.join(args.staging, name)
                os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
                with zf.open(name) as fin, open(dest, "wb") as fout:
                    shutil.copyfileobj(fin, fout)
                # 🔴 zip -u 按 mtime（2 秒粒度）判断是否更新；不 touch 会出现
                #    「类明明解压出来了，zip 却静默跳过」——复核时才发现的假成功。
                os.utime(dest, None)

    if not args.quiet:
        c = result["counts"]
        print("编译产物：%s 条   本地 jar：%s 条" % (c["src"], c["dst"]))
        print("变更 %d / 新增 %d / 排除 %d / 仅本地保留 %d  ⇒ 待注入 %d 条"
              % (c["changed"], c["new"], c["excluded"], c["local_only"], c["inject"]))
        for label, items in (("变更", changed), ("新增", new)):
            if items:
                print("  [%s] %s" % (label, ", ".join(items[:12])
                                     + (" …等 %d 条" % len(items) if len(items) > 12 else "")))
        if excluded:
            print("  [排除] %s" % ", ".join(excluded[:8])
                  + (" …等 %d 条" % len(excluded) if len(excluded) > 8 else ""))
        if all(len(v) == 0 for v in (changed, new, excluded)):
            print("  ✓ 本地服代码已是最新，无需注入")
    return 0


if __name__ == "__main__":
    sys.exit(main())
