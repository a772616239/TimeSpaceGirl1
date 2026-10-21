#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""表1 —— 换皮大图台账（registry）。

定位
----
一张持续维护的清单：凡是**改过的大图（非标题/文字类）**都在这里有一行，
记录它已经换过哪些主题（themes_done）、还欠哪些（对照 planned_themes）。
后续批量换风格（普罗旺斯/冲浪/赛博…）直接从表 1 导出 batch 清单跑 batch_restyle。

三条进入路径
------------
1. 种子数据：`scan --since "3 days"` 从 git 历史收集候选（需人工定 kind 后 --add 落库）。
2. **自动登记（主路径）**：restyle_pipeline.py publish 写回成功后调 record_publish()，
   Jenkins TS-Art-Restyle 与 batch_restyle 都走这个子命令 ⇒ 两链路自动进表。
3. 手工：`add --asset ... --kind ...`。

子命令
------
  list     看台账（--pending 只看还没换过的 / --theme X 看谁欠主题 X）
  add      手工加一行
  scan     从 git log 扫近 N 天改动的 png 候选（过滤标题/图标/CV，打印人工确认）
  export   导出 batch_restyle 清单：--theme provence --out xxx.json
  check    自检（资产还在不在、themes_done 里的主题认不认识）

表文件：scripts/image/table1.json（可用环境变量 TSG_TABLE1 覆盖，测试用）。
条目结构见该文件；字段解释：
  kind        diban/banner/peitu/panel（人工定，决定出图口径）
  themes_done {主题: 最近写回日期}——由 publish 钩子自动维护
  status      active=在换皮轮换里 / retired=不再换（如资源下线）
  overrides   可选，导出批量清单时合进该条目（composition/watermark/pose…）
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
TABLE1 = Path(os.environ.get("TSG_TABLE1") or (HERE / "table1.json"))

# 扫描时直接排除的路径/名字规律（标题、文字图、图标、备份、CV）
EXCLUDE_PATH_PARTS = (
    "/CV_/", "CV_En_Full", "GameIcon/", "_png_backup", "/_backup", "/备份/", "/tab/",
    "ChannelBackup", "BuildABs", "AssetBundles",
)
EXCLUDE_NAME_PARTS = (
    "biaoti", "title", "yeqian", "yeqianxuanzhong", "_lingqu_",
    "xianquhuodong_duihuanxianqu", "xianquhuodong_huoqudaoju",
    "xianquhuodong_yiduihuan", "xianquhuodong_benqixianqu",
    "xianquhuodong_xianqulibao", "xianquhuodong_shenyutiaozhan",
    "zhanling_mota_bg", "zhanling_miwu_bg", "zhanling_yiduan_bg",
    "liutianmowang",
)
DEFAULT_MIN_BYTES = 200_000  # 比这小的基本是按钮/小件，不是"大图"

# kind 猜测：从资源名。猜不出就 unknown，人工补。
KIND_RULES = (
    ("diban", "diban"),
    ("_bg_", "panel"),
    ("banner", "banner"),
    ("peitu", "peitu"),
    ("shengxing", "panel"),
)


def load() -> dict:
    data = json.loads(TABLE1.read_text(encoding="utf-8"))
    data.setdefault("planned_themes", [])
    data.setdefault("defaults", {})
    data.setdefault("items", [])
    data.setdefault("excluded", [])
    return data


def save(data: dict) -> None:
    TABLE1.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def find(data: dict, asset: str) -> dict | None:
    for it in data["items"]:
        if it.get("asset") == asset:
            return it
    return None


def guess_kind(asset: str) -> str:
    name = Path(asset).name.lower()
    for pat, kind in KIND_RULES:
        if pat in name:
            return kind
    return "unknown"


# ----------------------------------------------------------------------------- 登记
def record_touch(published: dict, op: str | None = None) -> str:
    """非主题类像素加工的登记入口（如底部虚化）：只更新 last_publish / post_ops，不碰 themes_done。

    🔴 为什么不能复用 record_publish：它往 themes_done 里写 `published["theme"]`，
       而底部虚化的 theme 是 "fade" —— 不是计划主题，check 会立刻报「未知主题 fade」，
       而且 list 的「已换主题」列会多出一个假主题。
    """
    asset = published["asset"]
    today = datetime.now().strftime("%Y-%m-%d")
    data = load()
    it = find(data, asset)
    if it is None:
        it = {
            "asset": asset,
            "kind": guess_kind(asset),
            "size": published.get("size") or [0, 0],
            "mode": published.get("mode", ""),
            "added_at": today,
            "added_by": "record_touch",
            "themes_done": {},
            "status": "active",
            "note": "record_touch 自动建档",
        }
        data["items"].append(it)
    it["last_publish"] = {
        "at": published.get("at") or datetime.now().isoformat(timespec="seconds"),
        "variant": published.get("variant"),
        "sha256": published.get("after_sha256"),
        "work": published.get("work"),
    }
    it["size"] = published.get("size") or it.get("size")
    it["mode"] = published.get("mode") or it.get("mode")
    it["updated_at"] = today
    ops = it.setdefault("post_ops", [])
    ops.append({
        "at": today,
        "op": op or published.get("theme") or "touch",
        "note": published.get("note") or "",
        "sha256": (published.get("after_sha256") or "")[:16],
    })
    save(data)
    return f"touched: {Path(asset).name} post_ops += {ops[-1]['op']}"


def record_publish(published: dict, note_prefix: str = "publish") -> str:
    """publish 写回成功后的登记入口（restyle_pipeline.cmd_publish 调用）。

    published 至少含：asset / theme / variant / after_sha256 / size / mode。
    幂等：同主题重复登记只刷新日期与哈希；条目不存在则自动建档（kind 先猜）。
    返回动作：created / updated。
    """
    asset = published["asset"]
    theme = published["theme"]
    today = datetime.now().strftime("%Y-%m-%d")
    data = load()
    it = find(data, asset)
    action = "updated"
    if it is None:
        im_size = published.get("size") or [0, 0]
        it = {
            "asset": asset,
            "kind": guess_kind(asset),
            "size": im_size,
            "mode": published.get("mode", ""),
            "added_at": today,
            "added_by": note_prefix,
            "themes_done": {},
            "status": "active",
            "note": f"publish 钩子自动建档（{note_prefix}）",
        }
        data["items"].append(it)
        action = "created"
    done = it.setdefault("themes_done", {})
    done[theme] = today
    it["last_publish"] = {
        "at": published.get("at") or datetime.now().isoformat(timespec="seconds"),
        "variant": published.get("variant"),
        "sha256": published.get("after_sha256"),
        "work": published.get("work"),
    }
    it["size"] = published.get("size") or it.get("size")
    it["mode"] = published.get("mode") or it.get("mode")
    it["updated_at"] = today
    save(data)
    return f"{action}: {Path(asset).name} += {theme}"


# ----------------------------------------------------------------------------- 扫描
def git_pngs_since(since: str) -> list[str]:
    out = subprocess.run(
        ["git", "-C", str(ROOT), "log", f"--since={since}",
         "--name-status", "--pretty=format:", "--diff-filter=AM", "--", "*.png"],
        capture_output=True, text=True).stdout
    return sorted({ln.split("\t", 1)[1].strip() for ln in out.splitlines()
                   if ln.startswith(("A\t", "M\t"))})


def is_excluded(rel: str, min_bytes: int) -> str | None:
    """返回排除原因；None = 保留为候选。"""
    p = rel.replace("\\", "/")
    for part in EXCLUDE_PATH_PARTS:
        if part in p:
            return f"path:{part}"
    name = Path(p).name.lower()
    for part in EXCLUDE_NAME_PARTS:
        if part in name:
            return f"name:{part}"
    f = ROOT / rel
    if not f.is_file():
        return "missing"
    if f.stat().st_size < min_bytes:
        return f"<{min_bytes}B"
    return None


# ----------------------------------------------------------------------------- 子命令
def cmd_list(args) -> int:
    data = load()
    planned = data["planned_themes"]
    rows = []
    for it in data["items"]:
        if args.theme and args.theme in (it.get("themes_done") or {}):
            continue
        if args.pending and it.get("status") != "active":
            continue
        rows.append(it)
    print(f"表1 {TABLE1.name}：共 {len(data['items'])} 条，显示 {len(rows)} 条；"
          f"计划主题：{', '.join(planned)}")
    print(f"{'资产':<74} {'kind':<8} {'已换主题':<22} 欠")
    flagged = []
    for it in rows:
        done = it.get("themes_done") or {}
        owes = [t for t in planned if t not in done] if planned else []
        name = Path(it["asset"]).name
        # 画面自带缺陷（如底部虚化）挂在条目上，list 里打 ~ 标记，提醒换主题时避开
        if it.get("soft_bottom"):
            name += "~"
            flagged.append((Path(it["asset"]).name, it["soft_bottom"]))
        print(f"{name:<74} {it.get('kind', '?'):<8} "
              f"{','.join(done.keys()) or '-':<22} {','.join(owes) or '-'}")
    for name, sb in flagged:
        print(f"  ~ {name}：底部 {sb.get('soft_px', '?')}px 偏虚"
              f"（{sb.get('mid_band_mean', '?')} → {sb.get('band_mean', '?')} 高频能量），"
              f"底边不要放必须看清的元素")
    return 0


def cmd_add(args) -> int:
    data = load()
    if find(data, args.asset):
        print(f"已在表中：{args.asset}（要补主题用 publish 钩子或手工编辑）")
        return 1
    from PIL import Image
    im = Image.open(ROOT / args.asset)
    it = {
        "asset": args.asset,
        "kind": args.kind or guess_kind(args.asset),
        "size": list(im.size),
        "mode": im.mode,
        "added_at": datetime.now().strftime("%Y-%m-%d"),
        "added_by": "manual",
        "themes_done": {args.theme: datetime.now().strftime("%Y-%m-%d")} if args.theme else {},
        "status": args.status or "active",
        "note": args.note or "",
    }
    if args.override:
        it["overrides"] = json.loads(args.override)
    data["items"].append(it)
    save(data)
    print(f"✅ 已加入表1：{args.asset}（kind={it['kind']}）")
    return 0


def cmd_scan(args) -> int:
    rels = git_pngs_since(args.since)
    kept, dropped = [], []
    for r in rels:
        why = is_excluded(r, args.min_bytes)
        (dropped if why else kept).append((r, why))
    data = load()
    print(f"git {args.since} 以来改动 png {len(rels)} 个 → 大图候选 {len(kept)}，排除 {len(dropped)}")
    if dropped:
        print("\n排除（原因 | 路径）：")
        for r, why in dropped:
            print(f"  {why:<14} {r}")
    print("\n候选（确认后 add --asset 落库）：")
    for r, _ in kept:
        mark = "✔已在表" if find(data, r) else "未登记"
        print(f"  [{mark}] kind={guess_kind(r):<8} {r}")
    return 0


def cmd_export(args) -> int:
    data = load()
    if args.theme not in (data["planned_themes"] or []) and not args.force:
        print(f"🔴 {args.theme} 不在 planned_themes 里（{data['planned_themes']}）；"
              f"确认无误加 --force")
        return 1
    items = []
    for it in data["items"]:
        if it.get("status") != "active":
            continue
        if args.theme in (it.get("themes_done") or {}):
            continue
        entry = {"asset": it["asset"], "theme": args.theme}
        if it.get("overrides"):
            entry.update(it["overrides"])
        items.append(entry)
    if not items:
        print(f"表1 里没有欠 {args.theme} 的活跃条目")
        return 1
    manifest = {
        "_comment": f"由 table1.py export 生成于 {datetime.now():%Y-%m-%d %H:%M}；主题 {args.theme}",
        "defaults": data.get("defaults") or {},
        "items": items,
    }
    out = Path(args.out) if args.out else (
        ROOT / "_output/art_restyle/_batch" / f"table1_{args.theme}.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✅ 批量清单 → {out}（{len(items)} 项）")
    print(f"   试跑：python scripts/image/batch_restyle.py {out} --dry-run")
    return 0


def cmd_check(args) -> int:
    data = load()
    errs = []
    presets_file = HERE / "theme_presets.json"
    known = set(json.loads(presets_file.read_text(encoding="utf-8"))["themes"].keys())
    for it in data["items"]:
        full = ROOT / it["asset"]
        if not full.is_file():
            errs.append(f"资产不存在：{it['asset']}")
        for t in (it.get("themes_done") or {}):
            if t not in known:
                errs.append(f"未知主题 {t!r}（{it['asset']}）")
        if it.get("kind") in (None, "unknown"):
            errs.append(f"kind 未定（{it['asset']}）——出图口径依赖它，人工补一下")
    for e in errs:
        print("  -", e)
    print(f"✅ check 完成：{len(data['items'])} 条，问题 {len(errs)}" if not errs
          else f"🔴 check 发现 {len(errs)} 个问题")
    return 0 if not errs else 1


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="表1：换皮大图台账")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("list", help="看台账")
    p.add_argument("--pending", action="store_true", help="只看 active 且还欠计划主题的")
    p.add_argument("--theme", help="只看还没换过该主题的")
    p.set_defaults(fn=cmd_list)
    p = sub.add_parser("add", help="手工加一行")
    p.add_argument("--asset", required=True)
    p.add_argument("--kind")
    p.add_argument("--theme", help="若该图已换过某主题（手工补登记）")
    p.add_argument("--status", help="默认 active")
    p.add_argument("--note")
    p.add_argument("--override", help='JSON，导出批量清单时合入，如 {"composition":"free"}')
    p.set_defaults(fn=cmd_add)
    p = sub.add_parser("scan", help="从 git log 扫近 N 天改动的大图候选")
    p.add_argument("--since", default="3 days ago")
    p.add_argument("--min-bytes", type=int, default=DEFAULT_MIN_BYTES)
    p.set_defaults(fn=cmd_scan)
    p = sub.add_parser("export", help="导出 batch_restyle 清单")
    p.add_argument("--theme", required=True)
    p.add_argument("--out")
    p.add_argument("--force", action="store_true")
    p.set_defaults(fn=cmd_export)
    p = sub.add_parser("check", help="自检")
    p.set_defaults(fn=cmd_check)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
