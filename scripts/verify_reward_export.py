# -*- coding: utf-8 -*-
"""校验挂机奖励改动是否已经落到导出产物（客户端 Lua + 服务端 txt）。

用法：
    python scripts/verify_reward_export.py

检查项：
  1. 客户端 RewardGroup.lua 的 __count 是否等于 xlsx 组数（新增 3 组后应为 5010）
  2. 客户端 RewardGroup.lua 是否比 xlsx 新（导表时间）
  3. 服务端 RewardGroup.txt 是否包含 20101/20102/20103，且 RewardItem 与 xlsx 一致
  4. 服务端 RewardItemConfig.txt 是否包含 990000~990102，且 ItemId/Chance/数量一致
  5. 服务端 MainLevelConfig.txt 每个关卡的 RandomReward 是否与 xlsx 完全一致
"""
from __future__ import annotations

import os
import re
import sys

import openpyxl

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "data_execl", "base_data")
CLIENT = os.path.join(ROOT, "Assets", "ManagedResources", "~Lua", "Config", "Data")
SERVER = os.path.join(ROOT, "TimeSpaceServer", "skzc", "home", "java", "gameserver", "conf", "server")

HEADER_ROWS = 6
NEW_GROUPS = (20101, 20102, 20103)
NEW_ITEM_RANGE = range(990000, 990103)


def _num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def read_xlsx(name):
    ws = openpyxl.load_workbook(os.path.join(BASE, name)).worksheets[0]
    return ws


def read_tsv(path):
    """服务端表：第一行表头，第二行类型，之后是数据。返回 list[dict]。"""
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = [ln.rstrip("\n").rstrip("\r") for ln in f if ln.strip()]
    if len(lines) < 2:
        return [], []
    header = lines[0].split("\t")
    rows = []
    for ln in lines[2:]:
        cells = ln.split("\t")
        if len(cells) < len(header):
            cells += [""] * (len(header) - len(cells))
        rows.append(dict(zip(header, cells)))
    return header, rows


class Result:
    def __init__(self):
        self.items = []

    def add(self, ok, name, detail=""):
        self.items.append((ok, name, detail))

    def report(self):
        bad = 0
        for ok, name, detail in self.items:
            print(f"[{'PASS' if ok else 'FAIL'}] {name}")
            if detail:
                print(f"       {detail}")
            if not ok:
                bad += 1
        print()
        if bad:
            print(f"共 {len(self.items)} 项，{bad} 项未通过 —— 说明还没导表，或导表结果不对。")
        else:
            print(f"全部 {len(self.items)} 项通过：客户端 Lua + 服务端 txt 均已同步。")
        return bad


def check_client_groups(r: Result, xlsx_group_count):
    path = os.path.join(CLIENT, "RewardGroup.lua")
    if not os.path.exists(path):
        r.add(False, "客户端 RewardGroup.lua 存在", path)
        return
    head = open(path, encoding="utf-8", errors="replace").read(400)
    m = re.search(r"__count\s*=\s*(\d+)", head)
    got = int(m.group(1)) if m else -1
    r.add(got == xlsx_group_count, "客户端 RewardGroup.lua __count",
          f"lua={got}  xlsx={xlsx_group_count}")

    xlsx = os.path.join(BASE, "RewardGroup.xlsx")
    fresh = os.path.getmtime(path) >= os.path.getmtime(xlsx)
    r.add(fresh, "客户端 RewardGroup.lua 是否比 xlsx 新",
          f"lua={_ts(path)}  xlsx={_ts(xlsx)}")


def _ts(p):
    import datetime
    return datetime.datetime.fromtimestamp(os.path.getmtime(p)).strftime("%m-%d %H:%M:%S")


def check_server_groups(r: Result):
    path = os.path.join(SERVER, "RewardGroup.txt")
    if not os.path.exists(path):
        r.add(False, "服务端 RewardGroup.txt 存在", path)
        return
    _, rows = read_tsv(path)
    by_id = {int(_num(x["Id"])): x for x in rows if _num(x["Id"]) is not None}

    ws = read_xlsx("RewardGroup.xlsx")
    xlsx = {}
    for rw in range(HEADER_ROWS + 1, ws.max_row + 1):
        gid = _num(ws.cell(rw, 2).value)
        if gid is None:
            continue
        xlsx[int(gid)] = {
            "items": str(ws.cell(rw, 5).value or "").replace(" ", ""),
            "max": int(_num(ws.cell(rw, 6).value) or 0),
        }

    for gid in NEW_GROUPS:
        row = by_id.get(gid)
        if not row:
            r.add(False, f"服务端含新组 {gid}", "未找到该行")
            continue
        items_txt = row["RewardItem"].replace(" ", "")
        ok = items_txt == xlsx[gid]["items"] and int(_num(row["RewardMaxNum"]) or 0) == xlsx[gid]["max"]
        r.add(ok, f"服务端新组 {gid} 的 RewardItem/RewardMaxNum",
              f"txt {len(items_txt.split('#'))} 项 / max={row['RewardMaxNum']}，"
              f"xlsx {len(xlsx[gid]['items'].split('#'))} 项 / max={xlsx[gid]['max']}")

    # 组 1 的行本身保留（其它表可能引用），但 RandomReward 里不应再有它
    lv_path = os.path.join(SERVER, "MainLevelConfig.txt")
    if os.path.exists(lv_path):
        _, lv_rows = read_tsv(lv_path)
        users = [x["Id"] for x in lv_rows
                 if "1" in x["RandomReward"].replace(" ", "").split("#")]
        r.add(not users, "RandomReward 里是否还有空转组 1",
              f"{len(users)} 关仍在引用" + (f"：{users[:5]}" if users else ""))


def check_server_items(r: Result):
    path = os.path.join(SERVER, "RewardItemConfig.txt")
    if not os.path.exists(path):
        r.add(False, "服务端 RewardItemConfig.txt 存在", path)
        return
    _, rows = read_tsv(path)
    by_id = {int(_num(x["Id"])): x for x in rows if _num(x["Id"]) is not None}

    ws = read_xlsx("RewardItemConfig.xlsx")
    missing, mismatch = [], []
    for rw in range(HEADER_ROWS + 1, ws.max_row + 1):
        rid = _num(ws.cell(rw, 2).value)
        if rid is None or int(rid) not in NEW_ITEM_RANGE:
            continue
        rid = int(rid)
        row = by_id.get(rid)
        if not row:
            missing.append(rid)
            continue
        want = (int(_num(ws.cell(rw, 3).value) or 0),
                int(_num(ws.cell(rw, 4).value) or 0),
                int(_num(ws.cell(rw, 6).value) or 0),
                int(_num(ws.cell(rw, 7).value) or 0))
        got = (int(_num(row["ItemId"]) or 0),
               int(_num(row["Chance"]) or 0),
               int(_num(row["RandomMin"]) or 0),
               int(_num(row["RandomMax"]) or 0))
        if want != got:
            mismatch.append((rid, want, got))

    r.add(not missing, "服务端 RewardItemConfig 含全部新增条目",
          f"缺 {len(missing)} 条" + (f"：{missing[:5]}..." if missing else ""))
    r.add(not mismatch, "新增条目的 ItemId/Chance/数量与服务端一致",
          f"不一致 {len(mismatch)} 条" + (f"：{mismatch[:3]}" if mismatch else ""))


def check_server_levels(r: Result):
    path = os.path.join(SERVER, "MainLevelConfig.txt")
    if not os.path.exists(path):
        r.add(False, "服务端 MainLevelConfig.txt 存在", path)
        return
    _, rows = read_tsv(path)
    srv = {int(_num(x["Id"])): x["RandomReward"].replace(" ", "")
           for x in rows if _num(x["Id"]) is not None}

    ws = read_xlsx("MainLevelConfig.xlsx")
    hdr = [c.value for c in ws[1]]
    c_id, c_rr = hdr.index("Id") + 1, hdr.index("RandomReward") + 1
    diff = []
    total = 0
    for rw in range(HEADER_ROWS + 1, ws.max_row + 1):
        lid = _num(ws.cell(rw, c_id).value)
        if lid is None:
            continue
        lid = int(lid)
        total += 1
        want = str(ws.cell(rw, c_rr).value or "").replace(" ", "")
        if srv.get(lid, "") != want:
            diff.append(lid)

    r.add(not diff, "服务端 MainLevelConfig.RandomReward 与 xlsx 一致",
          f"{len(diff)}/{total} 关不一致" + (f"：{diff[:8]}..." if diff else ""))


def main():
    r = Result()
    ws = read_xlsx("RewardGroup.xlsx")
    count = sum(1 for rw in range(HEADER_ROWS + 1, ws.max_row + 1)
                if ws.cell(rw, 2).value is not None)

    check_client_groups(r, count)
    check_server_groups(r)
    check_server_items(r)
    check_server_levels(r)
    return 1 if r.report() else 0


if __name__ == "__main__":
    sys.exit(main())
