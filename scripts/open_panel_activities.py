#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把测试服 GlobalActivity 表里「活动页签」需要的活动改成永久开启。

背景（2026-10-21）：
    OperatingPanel / AdjutantActivityPanel / ExpertPanel 的页签可见性由两段决定：
      ExpertPanel            → ActivityGiftManager.IsActivityTypeOpen(type)
                               = 客户端 GlobalActivity 配置里同 Type 的行 ∩ 服务端已下发的 mission
      OperatingPanel / 副官   → 同上，再叠加 IsQualifiled(type)（OpenRules 里的等级/关卡门槛）
    而服务端是否下发某个活动，只看 ActivityLogic.openActivityIds —— 它由 GlobalActivity 的
    StartTime/Endtime/Time/IfOpen 算出来。本表里绝大多数行的时间是 2029 年（未来）或
    IfOpen=2#21（开服 21 天后才开），所以本地测试服只有 18 个活动是开的，页签基本都不显示。

本脚本做的事（只动 GlobalActivity 表，不碰客户端、不碰代码）：
    每个需要的 Type 挑一行（Id 最小的那行＝基准期），改成
        Time=1（绝对时间）、StartTime=昨天 00:00、Endtime=2030-12-31、GapTime=0
        IfOpen=null（清掉「开服 N 天后才开」的门槛）、IsOpen=1
    同 Type 的其它行保持原样（避免同一活动 30 多期同时开着）。

生效方式：不重启游戏服 —— 往 ~/home/java/conf/ 写 c_database_version.json，
    MinuteTask 每分钟调 STableManager.updateTablesWithTableNames(true) 热更该表，
    下一次 checkActiviyStatus 就会把活动加进 openActivityIds（1~2 分钟）。
    客户端需要重新登录（或重进面板）才会拿到新的 activityInfo。

用法：
    python3 scripts/open_panel_activities.py --dry-run     # 只打印计划
    python3 scripts/open_panel_activities.py --apply       # 备份 + 改表 + 写热更 json
    python3 scripts/open_panel_activities.py --restore     # 从备份还原
"""

import argparse
import csv
import json
import os
import shutil
import sys
from datetime import datetime, timedelta

GS_ROOT = os.path.expanduser("~/home/java/gameserver")
TABLE_REL = "conf/server/GlobalActivity.txt"
ASSETS_REL = "assets/conf/server/GlobalActivity.txt"
HOTFIX_JSON = os.path.expanduser("~/home/java/conf/c_database_version.json")

# Type → (中文名, 出现在哪个面板/页签)
# 只放「靠 GlobalActivity 表就能开」的类型；goods / 战令 / 基金 不在这张表，见 docs。
TARGETS = {
    6:    ("成长礼金", "运营-福利 tab4"),
    14:   ("连续充值", "专家-累充礼盒"),
    15:   ("腐化侵袭-限时兑换", "专家 tab8"),
    16:   ("训练精英/快速作战", "专家 tab10"),
    17:   ("竞技达人", "专家 tab11"),
    18:   ("进阶达人", "专家 tab9"),
    19:   ("装备达人", "专家 tab12"),
    20:   ("点金达人", "专家 tab13"),
    21:   ("副本达人", "专家 tab14"),
    22:   ("体力达人", "专家 tab15"),
    24:   ("每日累充", "专家 tab7"),
    26:   ("天宫达人", "专家 tab26"),
    37:   ("法宝达人", "专家 tab16"),
    38:   ("魂印达人", "专家 tab17"),
    46:   ("寻宝达人", "专家 tab19"),
    47:   ("探宝达人", "专家 tab20"),
    48:   ("征募达人", "专家 tab21"),
    49:   ("秘宝达人", "专家 tab22"),
    52:   ("升级礼包", "专家 tab23"),
    70:   ("异端克星", "专家 tab27"),
    2000: ("周末福利", "运营-福利 tab11"),
    3000: ("终身特权", "运营-激励 tab12"),
    3001: ("超级终身特权", "运营-激励 tab14"),
    7000: ("豪华周卡", "运营-福利 tab13"),
    9000: ("扭蛋", "专家 tab32"),
    10020: ("开服双倍", "专家 tab31"),
    10021: ("终身限购", "运营-福利 tab10"),
    21000: ("先驱活动", "副官 tab1"),
    21001: ("先驱挑战", "副官 tab2"),
    21002: ("先驱招募", "副官 tab3"),
    21003: ("先驱礼包", "副官 tab4"),
}


def read_table(path):
    with open(path, "r", encoding="utf-8", newline="") as f:
        raw = f.read()
    crlf = "\r\n" in raw
    lines = raw.replace("\r\n", "\n").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    header = lines[0].split("\t")
    types = lines[1].split("\t")
    rows = []
    for ln in lines[2:]:
        if ln.strip() == "":
            continue
        rows.append(ln.split("\t"))
    return header, types, rows, crlf


def write_table(path, header, types, rows, crlf):
    eol = "\r\n" if crlf else "\n"
    body = [("\t".join(header)), ("\t".join(types))]
    body += ["\t".join(r) for r in rows]
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(eol.join(body) + eol)


def parse_dt(s):
    try:
        return datetime.strptime(s, "%Y%m%d %H%M%S")
    except Exception:
        return None


def already_open(row, idx, now):
    """按 ActivityLogic.checkActiviyStatus 的口径判断这行当前是不是开着。
    IfOpen 里的「2#N」= 开服 N 天后才开，本地服开服时间不明，一律当作门槛未过。"""
    if row[idx["Time"]] != "1":
        return False
    if row[idx["IfOpen"]] not in ("null", "", "0"):
        return False
    st = row[idx["StartTime"]]
    et = row[idx["Endtime"]]
    s = datetime(1970, 1, 1) if st == "0" else parse_dt(st)
    e = None if et == "0" else parse_dt(et)
    if s is None or (e is None and et != "0"):
        return False
    return s <= now and (e is None or now <= e)


def plan(rows, header):
    idx = {name: i for i, name in enumerate(header)}
    now = datetime.now()
    start = (now - timedelta(days=1)).strftime("%Y%m%d 000000")
    end = "20301231 235900"

    by_type = {}
    for r in rows:
        by_type.setdefault(int(r[idx["Type"]]), []).append(r)

    changes = []
    for t, (cn, where) in TARGETS.items():
        candidates = by_type.get(t, [])
        if not candidates:
            changes.append({"type": t, "name": cn, "where": where, "id": None,
                            "reason": "表里没有这个 Type 的行"})
            continue
        target = min(candidates, key=lambda r: int(r[idx["Id"]]))
        if already_open(target, idx, now):
            changes.append({"type": t, "name": cn, "where": where, "id": target[idx["Id"]],
                            "skip": True, "rows_of_type": len(candidates)})
            continue
        before = {k: target[idx[k]] for k in ("Id", "Time", "StartTime", "Endtime", "IfOpen", "IsOpen")}
        target[idx["Time"]] = "1"
        target[idx["StartTime"]] = start
        target[idx["Endtime"]] = end
        target[idx["GapTime"]] = "0"
        target[idx["IfOpen"]] = "null"
        target[idx["IsOpen"]] = "1"
        after = {k: target[idx[k]] for k in ("Id", "Time", "StartTime", "Endtime", "IfOpen", "IsOpen")}
        changes.append({"type": t, "name": cn, "where": where, "id": after["Id"],
                        "before": before, "after": after, "rows_of_type": len(candidates)})
    return changes


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--dry-run", action="store_true")
    g.add_argument("--apply", action="store_true")
    g.add_argument("--restore", action="store_true")
    args = ap.parse_args()

    conf_path = os.path.join(GS_ROOT, TABLE_REL)
    assets_path = os.path.join(GS_ROOT, ASSETS_REL)
    if not os.path.exists(conf_path):
        sys.exit("找不到服务端表：%s" % conf_path)

    if args.restore:
        backups = sorted([p for p in os.listdir(os.path.dirname(conf_path))
                          if p.startswith("GlobalActivity.txt.bak-")])
        if not backups:
            sys.exit("没有备份可还原")
        # 取最早的一份＝脚本改动之前的原表（后续备份可能已是改过的状态）
        src = os.path.join(os.path.dirname(conf_path), backups[0])
        shutil.copy2(src, conf_path)
        if os.path.exists(assets_path):
            shutil.copy2(src, assets_path)
        if os.path.exists(HOTFIX_JSON):
            os.remove(HOTFIX_JSON)
        print("已还原自 %s" % os.path.basename(src))
        print("还原同样要靠热更才生效：重新 --apply 会再次打开；只想关掉请重启游戏服。")
        return

    header, types, rows, crlf = read_table(conf_path)
    changes = plan(rows, header)

    print("%-6s %-16s %-14s %-8s %s" % ("Type", "活动", "面板", "Id", "动作"))
    print("-" * 88)
    for c in changes:
        if c.get("skip"):
            print("%-6s %-16s %-14s %-8s 已开启，跳过" % (c["type"], c["name"], c["where"], c["id"]))
        elif c["id"] is None:
            print("%-6s %-16s %-14s %-8s ⚠ %s" % (c["type"], c["name"], c["where"], "-", c["reason"]))
        else:
            print("%-6s %-16s %-14s %-8s %s/%s → %s/%s" % (
                c["type"], c["name"], c["where"], c["id"],
                c["before"]["Time"], c["before"]["StartTime"],
                c["after"]["Time"], c["after"]["StartTime"]))
    ok = [c for c in changes if c["id"] and not c.get("skip")]
    print("-" * 88)
    print("共 %d 个类型，需改动 %d 个，已开启 %d 个" % (
        len(changes), len(ok), len([c for c in changes if c.get("skip")])))

    if args.dry_run:
        print("\n[dry-run] 未写任何文件。加 --apply 执行。")
        return

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    bak = conf_path + ".bak-" + stamp
    shutil.copy2(conf_path, bak)
    write_table(conf_path, header, types, rows, crlf)
    if os.path.exists(assets_path):
        shutil.copy2(conf_path, assets_path)
    print("\n备份：%s" % bak)

    os.makedirs(os.path.dirname(HOTFIX_JSON), exist_ok=True)
    with open(HOTFIX_JSON, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "tables": "GlobalActivity"}, f)
    print("热更标记：%s" % HOTFIX_JSON)
    print("约 1~2 分钟生效（MinuteTask 热更表 → 下一次 checkActiviyStatus 开活动）。")


if __name__ == "__main__":
    main()
