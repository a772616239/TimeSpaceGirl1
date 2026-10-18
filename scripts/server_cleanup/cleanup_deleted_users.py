#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
删号后全量清理已删 UID 的残留引用（TimeSpaceServer / gameSrv）

背景见 docs/gm_abuse_incident_playbook.md §5.4。删号只删 user 文档是不够的，
残留引用会让 getUser 返回 null，进而各处 NPE。2026-10-18 两轮实测已踩到 5 类：

  1) Redis zset 排行成员（*RANK*，成员可能是 <uid> 或 <uid>:<heroId>）
  2) Mongo supremacyInfo 的 uid
  3) Redis hash {1,2,3,4}:RANKING_DATA —— value 是 JSON {"时间戳":uid,...}
  4) Mongo guildInfo.members —— {职位: [uid...]}，职位 1 = 会长
  5) 其他业务引用（好友/任务/邮件/竞技场记录等）

用法：
  python3 cleanup_deleted_users.py --dead 10000013,10000016 --dry-run
  python3 cleanup_deleted_users.py --dead 10000013,10000016 --apply

🔴 铁律：
  - 默认 --dry-run，只打印不写入。确认无误再加 --apply。
  - 改完 Redis/Mongo 后**必须重启游戏服**才生效，因为
    RankingRewardLogic.rankingDataMap / GuilidManager.guildInfoMap
    都是启动时一次性加载。
  - 从公会会长位移除账号后，若职位变空，**必须补一个存活会长**，
    否则 GuildForceRank.getFirst 的 iterator().next() 会抛异常。
"""

import argparse
import json
import subprocess
import sys

# 线上 CentOS7 的 python3.6 在非 UTF-8 locale 下 print 中文会 UnicodeEncodeError。
# python3.7+ 用 sys.stdout.reconfigure；3.6 没有该方法，改包一层 utf-8 writer。
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    else:
        import io
        sys.stdout = io.TextIOWrapper(
            sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)
except Exception:
    pass

DBS = "m5_x1_game_10001"
REDIS_DB = "0"


def rc(*args):
    """redis-cli 封装"""
    out = subprocess.check_output(["redis-cli", "-n", REDIS_DB] + list(args))
    return out.decode("utf-8", "replace").strip()


def mongo(js):
    """mongo shell 封装"""
    out = subprocess.check_output(["mongo", "--quiet", DBS, "--eval", js])
    return out.decode("utf-8", "replace")


def alive_uids():
    out = mongo("db.user.find({},{_id:1}).forEach(function(d){print(d._id)})")
    return set(x.strip() for x in out.split() if x.strip().isdigit())


# ---------------------------------------------------------------- 3) RANKING_DATA
def repair_json(raw):
    """把可能已损坏的 JSON 尽力修复成 dict（防历史 sed 误伤）"""
    s = (raw or "").strip()
    if not s:
        return {}
    try:
        return json.loads(s)
    except Exception:
        pass
    import re
    s2 = re.sub(r",\s*,", ",", s)
    s2 = re.sub(r",\s*}", "}", s2)
    s2 = re.sub(r"\{\s*,", "{", s2)
    try:
        return json.loads(s2)
    except Exception:
        pairs = re.findall(r'"(\d+)"\s*:\s*(\d+)', s)
        return {k: int(v) for k, v in pairs} if pairs else {}


def clean_ranking_data(alive, dead, apply):
    keys = [k for k in rc("--scan", "--pattern", "*:RANKING_DATA").split("\n") if k]
    changed = removed = scanned = 0
    for k in keys:
        for f in [x for x in rc("HKEYS", k).split("\n") if x]:
            raw = rc("HGET", k, f)
            scanned += 1
            d = repair_json(raw)
            nd = {ts: uid for ts, uid in d.items() if str(uid) in alive}
            removed += len(d) - len(nd)
            new = json.dumps(nd, separators=(",", ":"))
            if new != raw:
                changed += 1
                print("  [RANKING_DATA] %s[%s] %d -> %d 条" % (k, f, len(d), len(nd)))
                if apply:
                    rc("HSET", k, f, new)
    print("[3] RANKING_DATA 扫描字段=%d 需重写=%d 剔除条目=%d%s"
          % (scanned, changed, removed, "" if apply else "  (dry-run)"))


# ---------------------------------------------------------------- 4) guildInfo
def clean_guilds(alive, dead, apply):
    js = """
    var dead = %s;
    db.guildInfo.find().forEach(function(g){
      if (!g.members) return;
      Object.keys(g.members).forEach(function(pos){
        (g.members[pos]||[]).forEach(function(u){
          if (dead.indexOf(u) >= 0) print("HIT " + g._id + " " + pos + " " + u);
        });
      });
    });
    """ % json.dumps([int(x) for x in dead])
    lines = [l for l in mongo(js).split("\n") if l.startswith("HIT ")]
    if not lines:
        print("[4] guildInfo 无残留")
        return
    for l in lines:
        _, gid, pos, uid = l.split()
        print("  [guildInfo] guild=%s 职位%s 残留 uid=%s" % (gid, pos, uid))
        if apply:
            mongo('db.guildInfo.updateOne({_id:%s}, {$pull: {"members.%s": %s}})' % (gid, pos, uid))
    if apply:
        check_guild_leaders()


def check_guild_leaders():
    """会长位必须指向存活账号，否则 GuildForceRank.getFirst 抛异常"""
    js = """
    db.guildInfo.find().forEach(function(g){
      var m1 = g.members ? g.members["1"] : null;
      var first = (m1 && m1.length) ? m1[0] : null;
      var ok = first ? db.user.count({_id:first}) : -1;
      if (ok !== 1) print("BADGUILD " + g._id + " " + JSON.stringify(m1));
    });
    """
    bad = [l for l in mongo(js).split("\n") if l.startswith("BADGUILD")]
    if not bad:
        print("  [会长位] 全部有效")
        return
    for l in bad:
        print("  🔴 [会长位] %s  ← 必须手工补一个存活会长！" % l)


# ---------------------------------------------------------------- 1) zset 排行
def clean_rank_zsets(alive, dead, apply):
    keys = [k for k in rc("--scan", "--pattern", "*RANK*").split("\n") if k]
    n = 0
    for k in keys:
        if rc("TYPE", k) != "zset":
            continue
        for d in dead:
            if rc("ZSCORE", k, d):
                n += 1
                print("  [zset] %s -> %s" % (k, d))
                if apply:
                    rc("ZREM", k, d)
    print("[1] zset 残留 %d 处%s" % (n, "" if apply else "  (dry-run)"))


# ---------------------------------------------------------------- 2) supremacyInfo
def clean_supremacy(alive, dead, apply):
    deadlist = ",".join(dead)
    js = """
    db.supremacyInfo.find({uid:{$in:[%s]}}).forEach(function(d){
      print("HIT " + d._id + " " + d.uid);
    });
    """ % deadlist
    hits = [l for l in mongo(js).split("\n") if l.startswith("HIT ")]
    for l in hits:
        _, rid, uid = l.split()
        print("  [supremacy] _id=%s uid=%s" % (rid, uid))
        if apply:
            mongo('db.supremacyInfo.updateOne({_id:%s}, {$set:{uid:0}})' % rid)
    print("[2] supremacyInfo 残留 %d 处%s" % (len(hits), "" if apply else "  (dry-run)"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dead", required=True, help="逗号分隔的已删 uid")
    ap.add_argument("--apply", action="store_true", help="真正写入（默认 dry-run）")
    a = ap.parse_args()
    dead = [x.strip() for x in a.dead.split(",") if x.strip()]

    alive = alive_uids()
    print("存活用户 %d | 待清理 uid: %s | 模式: %s\n"
          % (len(alive), ",".join(dead), "APPLY" if a.apply else "DRY-RUN"))

    clean_rank_zsets(alive, dead, a.apply)
    clean_supremacy(alive, dead, a.apply)
    clean_ranking_data(alive, dead, a.apply)
    clean_guilds(alive, dead, a.apply)
    if a.apply:
        check_guild_leaders()
        print("\n🔴 改完必须重启游戏服才生效（RankingRewardLogic/GuilidManager 是启动加载）")
    else:
        print("\n(dry-run 结束，确认无误后加 --apply)")


if __name__ == "__main__":
    main()
