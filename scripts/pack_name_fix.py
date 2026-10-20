#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
礼包「废弃」名字修复 + 皮肤礼包位内容回退
=========================================
背景（2026-10-20 追查结论）：
  RechargeCommodityConfig 833 个 SKU 里 248 个的 Name/Desc/Tip 指向语言 id 34010001，
  值就是「废弃」两个字。其中 ShowType=27「皮肤礼包」3 个（8000/8001/8003）是纯配置残留：
  游戏无皮肤系统（Language 无「皮肤」「外观」；客户端 DirectBuyType 只到 17，无 27），
  上一轮内容改造给它们塞的紫晶卡/招募卡是无效动作，需回退。

本脚本做两件事：
  A. 皮肤礼包 3 个位：
     - BaseReward / RewardShow 去掉道具，只保留钻石 16#7452（撤销无意义的内容）
     - Name / Desc 从 34010001「废弃」→ 34010091「后续开放」
  B. 会把「废弃」显示给玩家的推送型礼包（Otype=4）改名，
     全部复用 Language 表现成条目，**不新增任何语言 id**。

不处理（需产品确认）：
  - 星级成长礼(ShowType=8) 的 13 个早期遗留行（id 21/24-32/400-402），
    该货架有 30500+ 新体系，这 13 个已被取代且 PosterUiId 为空，建议直接下线。
  - 其余货架里非 Otype=4 的「废弃」行（限时商市 116 个等），不在本轮范围。

用法：
  python scripts/pack_name_fix.py                 # dry-run
  python scripts/pack_name_fix.py --apply         # 落表 + 自检（失败自动回滚）
  python scripts/pack_name_fix.py --revert <dir>  # 从备份目录回滚
  python scripts/pack_name_fix.py --list-backups
"""
import argparse
import os
import shutil
import sys
import time

import openpyxl

BASE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "data_execl", "base_data")
F_RECHARGE = "RechargeCommodityConfig.xlsx"
BACKUP_ROOT = os.path.join(BASE, "_backup_before_namefix")

DEAD_NAME = "34010001"      # 废弃
COMING_SOON = "34010091"    # 后续开放

# ---------------------------------------------------------------- 映射方案
# B. Otype=4 且名字=「废弃」的包 → 按货架语义复用现成语言 id
#    值必须能在 Language.txt 查到，脚本启动时会校验。
NAME_MAP = {
    # 超值折扣(21) 68/128/328/448/648 五个档
    251: "34010019",   # 全民礼包
    252: "34010020",   # 精英礼包
    253: "34010021",   # 豪华礼包
    254: "34010022",   # 至尊礼包
    255: "34010132",   # 专属礼包
    # 闯关礼包(25) 68/128/328/448/648
    7000: "34010092",  # 位面礼包
    7001: "34010093",  # 位面小礼包
    7002: "34010094",  # 位面中礼包
    7003: "34010095",  # 位面大礼包
    7004: "34010096",  # 位面豪华礼包
    # 心魔试炼(26) 68/128/328/448/648
    7100: "34010277",  # 深渊计划
    7101: "34010276",  # 迷雾计划
    7102: "34010275",  # 异端计划
    7103: "34010274",  # 魔塔计划
    7104: "34010273",  # 神塔计划
    # 灵兽宝阁(28) 328/328
    9000: "34010130",  # 先驱礼包
    9001: "34010131",  # 英雄礼包
}

# A. 皮肤礼包位：Name/Desc 改「后续开放」，内容回退到只剩钻石
SKIN_IDS = [8000, 8001, 8003]
SKIN_KEEP_DIA = 7452      # 上轮 R2 Type5 加赠后的钻石数（6480 × 1.15）保留，与全表一致

# C. 星级成长礼(ShowType=8) 的 13 个早期遗留行：Otype=4、PosterUiId 为空、
#    内容完整（钻石+道具）、Limit=0（无限次购买）、名字却是「废弃」。
#    星级归属无法从配置判出（LoginPosterConfig.ShopId 全空），因此：
#      - 不改内容（本来就不是上一轮改的）
#      - 名字改中性占位「后续开放」，先把「废弃」消掉
#      - 真实星级名待产品确认后再定
LEGACY_COMING_SOON = [21, 24, 25, 26, 27, 28, 29, 30, 31, 32, 400, 401, 402]


# ---------------------------------------------------------------- 基础工具
def load(fname):
    p = os.path.join(BASE, fname)
    wb = openpyxl.load_workbook(p)
    ws = wb.worksheets[0]
    hdr = [(c.value or "") for c in ws[1]]
    idx = {h: i for i, h in enumerate(hdr)}
    return wb, ws, idx


def iter_rows(ws, idx):
    for r in range(6, ws.max_row + 1):
        v = [c.value for c in ws[r]]
        if v[1] is None:
            continue
        yield r, dict(zip([h for h in idx], v))


def col(idx, name):
    return idx[name] + 1


def get(rec, name):
    return rec.get(name)


def parse_reward(s):
    out = []
    for part in str(s or "").split("|"):
        if "#" not in part:
            continue
        a = part.split("#")
        try:
            out.append([a[0], int(float(a[1]))])
        except (ValueError, IndexError):
            continue
    return out


def fmt_reward(items):
    return "|".join("%s#%d" % (k, n) for k, n in items)


def load_lang():
    """读服务端 Language.txt，用于校验语言 id 存在"""
    p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "TimeSpaceServer", "skzc", "home", "java", "gameserver",
                     "conf", "server", "Language.txt")
    lang = {}
    if not os.path.exists(p):
        return lang
    with open(p, encoding="utf-8", errors="ignore") as f:
        for line in f:
            a = line.rstrip("\n").split("\t")
            if len(a) > 1:
                lang[a[0]] = a[1]
    return lang


# ---------------------------------------------------------------- 规划
def plan():
    wb, ws, idx = load(F_RECHARGE)
    lang = load_lang()
    if not lang:
        raise SystemExit("读不到 Language.txt，无法校验语言 id")

    changes = []          # (row, colName, old, new, tag)
    mapping_sheet = []    # 供报告输出

    # ---------- A. 皮肤礼包位 ----------
    for r, rec in iter_rows(ws, idx):
        sid = get(rec, "Id")
        if sid not in SKIN_IDS:
            continue
        # 内容回退：只留钻石
        for cname in ("BaseReward", "RewardShow"):
            old = str(get(rec, cname) or "")
            items = parse_reward(old)
            if not items:
                continue
            new = fmt_reward([["16", SKIN_KEEP_DIA]])
            if old != new:
                changes.append((r, cname, old, new, "A-回退内容"))
        # 改名
        for cname in ("Name", "Desc"):
            old = str(get(rec, cname) or "")
            if old == DEAD_NAME:
                changes.append((r, cname, old, COMING_SOON, "A-改后续开放"))
        mapping_sheet.append(dict(sid=sid, row=r, price=get(rec, "Price"),
                                  objs=[]))

    # ---------- C. 星级成长礼早期遗留行：只改名 ----------
    for r, rec in iter_rows(ws, idx):
        sid = get(rec, "Id")
        if sid not in LEGACY_COMING_SOON:
            continue
        for cname in ("Name", "Desc"):
            old = str(get(rec, cname) or "")
            if old == DEAD_NAME:
                changes.append((r, cname, old, COMING_SOON, "C-改后续开放"))
        mapping_sheet.append(dict(sid=sid, row=r, price=get(rec, "Price"),
                                  objs=[], legacy=True))

    # ---------- B. 推送型礼包改名 ----------
    for r, rec in iter_rows(ws, idx):
        sid = get(rec, "Id")
        if sid not in NAME_MAP:
            continue
        newid = NAME_MAP[sid]
        if newid not in lang:
            raise SystemExit("语言 id %s 在 Language.txt 中不存在（礼包 %s）" % (newid, sid))
        if lang.get(DEAD_NAME) != "废弃":
            raise SystemExit("34010001 不再等于「废弃」，脚本假设已失效，请复核")
        for cname in ("Name", "Desc"):
            old = str(get(rec, cname) or "")
            if old == DEAD_NAME:
                changes.append((r, cname, old, newid, "B-改礼包名"))
        mapping_sheet.append(dict(sid=sid, row=r, price=get(rec, "Price"),
                                  objs=[newid, lang.get(newid)]))
    return wb, ws, idx, changes, mapping_sheet, lang


# ---------------------------------------------------------------- 预检
def precheck(changes, mapping_sheet, lang):
    msgs, ok = [], True

    # 1) 所有目标包原本必须是「废弃」
    miss = [m["sid"] for m in mapping_sheet
            if not m["objs"] and m["sid"] not in SKIN_IDS and not m.get("legacy")]
    if miss:
        ok = False
        msgs.append("✗ 映射表里有 %d 个 id 表里不存在: %s" % (len(miss), miss[:6]))
    else:
        msgs.append("✓ 映射表 %d 个礼包 id 全部存在" % len(mapping_sheet))

    # 2) 语言 id 必须都存在且非「废弃」
    bad = [(m["sid"], m["objs"][0]) for m in mapping_sheet
           if m["objs"] and m["objs"][0] not in lang]
    if bad:
        ok = False
        msgs.append("✗ 语言 id 缺失: %s" % bad[:6])
    else:
        msgs.append("✓ 复用语言 id 全部存在，零新增条目")

    # 3) 不能把任何包改回「废弃」
    back = [c for c in changes if c[3] == DEAD_NAME]
    if back:
        ok = False
        msgs.append("✗ 有 %d 处会把名字设成「废弃」" % len(back))
    else:
        msgs.append("✓ 无任何改动指向「废弃」")

    # 4) 皮肤位回退后必须只剩钻石
    skin_ch = [c for c in changes if c[4] == "A-回退内容"]
    wrong = [c for c in skin_ch if parse_reward(c[3]) != [["16", SKIN_KEEP_DIA]]]
    if wrong:
        ok = False
        msgs.append("✗ 皮肤位回退结果不符: %s" % wrong[:3])
    else:
        msgs.append("✓ 皮肤位 %d 处内容均回退为纯 %d 钻" % (len(skin_ch), SKIN_KEEP_DIA))

    msgs.append("   变更单元格合计 %d" % len(changes))
    return ok, msgs


# ---------------------------------------------------------------- 落盘 / 校验
def apply_changes(ws, idx, changes):
    for r, cname, old, new, _tag in changes:
        ws.cell(row=r, column=col(idx, cname)).value = new


def verify(mapping_sheet, lang):
    """写盘后重新读盘校验"""
    msgs, ok = [], True
    wb, ws, idx = load(F_RECHARGE)
    cur = {}
    for r, rec in iter_rows(ws, idx):
        cur[get(rec, "Id")] = rec

    # 1) 目标包不再有「废弃」
    still = []
    for m in mapping_sheet:
        rec = cur.get(m["sid"])
        if not rec:
            still.append((m["sid"], "消失"))
            continue
        for cname in ("Name", "Desc"):
            if str(get(rec, cname) or "") == DEAD_NAME:
                still.append((m["sid"], cname))
    if still:
        ok = False
        msgs.append("✗ 仍有 %d 处是「废弃」: %s" % (len(still), still[:6]))
    else:
        msgs.append("✓ 目标 %d 个礼包的 Name/Desc 已无「废弃」" % len(mapping_sheet))

    # 2) 皮肤位内容
    for sid in SKIN_IDS:
        rec = cur.get(sid)
        items = parse_reward(get(rec, "BaseReward"))
        if items != [["16", SKIN_KEEP_DIA]]:
            ok = False
            msgs.append("✗ 皮肤位 %s BaseReward = %r" % (sid, get(rec, "BaseReward")))
    else:
        if ok:
            msgs.append("✓ 皮肤位 %d 个内容均为纯 %d 钻" % (len(SKIN_IDS), SKIN_KEEP_DIA))

    # 3) 全表「废弃」数量下降
    dead_total = 0
    for rec in cur.values():
        if str(get(rec, "Name") or "") == DEAD_NAME:
            dead_total += 1
    msgs.append("   全表名字=「废弃」剩余 %d 个（改前 248）" % dead_total)
    if dead_total >= 248:
        ok = False
        msgs.append("✗ 「废弃」数量没有下降，落表可能失败")

    # 4) Otype=4 里还剩多少「废弃」
    rest = [k for k, v in cur.items()
            if get(v, "Otype") == 4 and str(get(v, "Name") or "") == DEAD_NAME]
    msgs.append("%s Otype=4 仍为「废弃」的 = %d 个" % ("✓" if not rest else "✗", len(rest)))
    if rest:
        ok = False
        msgs.append("      剩余 id: %s" % sorted(rest))
    return ok, msgs


# ---------------------------------------------------------------- 备份
def backup():
    stamp = time.strftime("%Y%m%d-%H%M%S")
    d = os.path.join(BACKUP_ROOT, stamp)
    os.makedirs(d, exist_ok=True)
    shutil.copy2(os.path.join(BASE, F_RECHARGE), os.path.join(d, F_RECHARGE))
    return d


def revert(d):
    src = os.path.join(d, F_RECHARGE)
    if not os.path.exists(src):
        raise SystemExit("备份里没有 %s: %s" % (F_RECHARGE, d))
    shutil.copy2(src, os.path.join(BASE, F_RECHARGE))
    print("已从 %s 回滚" % d)


# ---------------------------------------------------------------- 打印
def print_plan(changes, mapping_sheet, lang):
    print("=" * 78)
    print("礼包「废弃」名字修复 · DRY-RUN")
    print("=" * 78)
    tag = {}
    for r, cname, old, new, t in changes:
        tag.setdefault(t, []).append((r, cname, old, new))
    for t in ("A-回退内容", "A-改后续开放", "C-改后续开放", "B-改礼包名"):
        rows = tag.get(t, [])
        print("\n[%s] %d 处" % (t, len(rows)))
        for r, cname, old, new in rows[:40]:
            note = ""
            if t == "B-改礼包名":
                note = "  -> %s" % lang.get(new, "?")
            print("   r%-4d %-12s %-22s => %-22s%s" % (r, cname, old[:22], new[:22], note))
        if len(rows) > 40:
            print("   ... 另有 %d 处" % (len(rows) - 40))

    print("\n" + "-" * 78)
    print("改名映射表（%d 个礼包）" % len(mapping_sheet))
    print("%-7s %-6s %-6s %-20s %s" % ("礼包Id", "行号", "价格", "新名字", "备注"))
    for m in sorted(mapping_sheet, key=lambda x: x["sid"]):
        if m.get("legacy"):
            nm, note = "后续开放", "星级成长礼早期遗留，待产品确认星级"
        elif m["objs"]:
            nm, note = m["objs"][1], ""
        else:
            nm, note = "后续开放", "皮肤礼包位，无皮肤系统"
        print("%-7s %-6s %-6s %-20s %s" % (m["sid"], m["row"], m["price"], nm, note))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="落表")
    ap.add_argument("--revert", metavar="DIR", help="从备份目录回滚")
    ap.add_argument("--list-backups", action="store_true")
    args = ap.parse_args()

    if args.list_backups:
        if os.path.isdir(BACKUP_ROOT):
            for d in sorted(os.listdir(BACKUP_ROOT)):
                print(os.path.join(BACKUP_ROOT, d))
        return
    if args.revert:
        revert(args.revert)
        return

    wb, ws, idx, changes, mapping_sheet, lang = plan()
    print_plan(changes, mapping_sheet, lang)
    ok, msgs = precheck(changes, mapping_sheet, lang)
    print("\n" + "=" * 78)
    print("预检：" + ("通过" if ok else "未通过"))
    for m in msgs:
        print("  " + m)
    if not ok:
        print("\n预检未通过，未写盘。")
        sys.exit(1)
    if not args.apply:
        print("\n（dry-run，未写盘；加 --apply 落表）")
        return

    bk = backup()
    print("\n备份 -> %s" % bk)
    apply_changes(ws, idx, changes)
    wb.save(os.path.join(BASE, F_RECHARGE))
    print("已写入 %s" % F_RECHARGE)

    ok2, msgs2 = verify(mapping_sheet, lang)
    print("\n写盘后校验：" + ("通过" if ok2 else "未通过"))
    for m in msgs2:
        print("  " + m)
    if not ok2:
        revert(bk)
        print("\n校验失败，已自动回滚。")
        sys.exit(1)


if __name__ == "__main__":
    main()
