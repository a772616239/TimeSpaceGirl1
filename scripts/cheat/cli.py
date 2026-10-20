#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""cheatctl —— 作弊排查 / 处置命令行入口。

用法:
  # 1) 判一个号（只读，~20s；--fast 跳过 BI 流水）
  python3 scripts/cheatctl.py scan --uid 10000224
  python3 scripts/cheatctl.py scan --uid 10000224 --json > /tmp/rep.json

  # 2) 全服找可疑号（英雄维度）
  python3 scripts/cheatctl.py hunt

  # 3) 先归档再动手（user + itemLog/heroLog/fightLog/storeLog + 榜单 + 货币快照）
  python3 scripts/cheatctl.py archive --uid 10000224

  # 4) 一键处置（默认 dry-run；确认无误再加 --apply）
  python3 scripts/cheatctl.py purge --uid 10000224
  python3 scripts/cheatctl.py purge --uid 10000224 --apply
  python3 scripts/cheatctl.py purge --uid 10000224 --apply --ban
  python3 scripts/cheatctl.py purge --uid 10000224 --account --confirm 10000224 --apply

  # 5) 全榜完整性体检（删号 / 删英雄之后必跑；GHOST 成员会让排行榜打不开）
  python3 scripts/cheatctl.py rank-audit
  python3 scripts/cheatctl.py rank-audit --repair

  # 6) 封禁名单
  python3 scripts/cheatctl.py ban --uid 10000248 --reason "GM 探测"
  python3 scripts/cheatctl.py unban --uid 10000248
  python3 scripts/cheatctl.py banlist
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cheat.remote import Remote, RemoteError          # noqa: E402
from cheat.detect import Detector, fmt_report, now_tag  # noqa: E402
from cheat.purge import Purger                        # noqa: E402
from cheat.rankint import RankIntegrity               # noqa: E402


def _remote(a):
    return Remote(host=a.host, game_db=a.game_db, login_db=a.login_db,
                  redis_db=a.redis_db)


def cmd_scan(a):
    r = _remote(a)
    rep = Detector(r).scan(a.uid, deep=not a.fast)
    if a.json:
        print(json.dumps(rep.as_dict(), ensure_ascii=False, indent=2))
    else:
        print(fmt_report(rep))
    return 0 if rep.verdict == 'CLEAN' else (2 if rep.verdict == 'CHEAT' else 1)


def cmd_hunt(a):
    r = _remote(a)
    rows = Detector(r).hunt(limit=a.limit)
    if a.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return 0
    if not rows:
        print('未发现英雄维度异常账号')
        return 0
    print('%-12s %-16s %5s %6s %6s %6s %6s' % ('uid', 'nick', 'lv', 'heroes', 'maxLv', 'maxStar', 'n100'))
    for x in rows:
        print('%-12s %-16s %5s %6s %6s %6s %6s' % (
            x['uid'], x['nick'][:16], x['level'], x['heroN'], x['maxLv'], x['maxStar'], x['n100']))
    print('\n共 %d 个候选；逐个裁决: python3 scripts/cheatctl.py scan --uid <uid>' % len(rows))
    return 0


def cmd_rank_audit(a):
    """全榜完整性体检：账号已删 / 英雄已删 的残留成员都能挑出来。

    这类脏数据会让 HeroForceRank.getFirst 抛 NPE，而 RankFirstHandler 是遍历所有榜的，
    一条脏成员 = 整个排行榜打不开。删号、删英雄之后都应该跑一次。
    """
    r = _remote(a)
    ri = RankIntegrity(r, apply=a.repair)
    rep = ri.run(repair=True)
    if a.json:
        print(json.dumps(rep, ensure_ascii=False, indent=2))
    elif not rep['ghosts']:
        print('✅ %d 个榜 / %d 个成员，无失效成员' % (rep['keys'], rep['members']))
    elif not a.repair:
        print('\n共 %d 条失效成员；加 --repair 执行清理（建议先不加，确认清单）'
              % len(rep['ghosts']))
    return 0 if not rep['ghosts'] else (2 if not a.repair else 0)


def cmd_refs_audit(a):
    """好友 / 黑名单 / 申请 / 体力互赠表里指向「已不存在账号」的残留 uid。

    这类脏引用不会自己消失，而且报应落在**别人**身上：被引用方下次登录时
    GET_FRIEND_INFO → CBean2Proto.getFriendInfo → UserManager.getUser 抛
    「getUser null exception」，整包失败，登录链停在第 26/57 步，
    客户端表现就是进度条永远卡 45%（2026-10-20 Sakuya 10000017 实测）。

    判据只有一条：引用的 uid 不在 `user` 集合里。公会榜/车队榜那些 guildId
    不在此列（本命令只看 friendManager）。删号、合服之后都应该跑一次。
    """
    r = _remote(a)
    js = """
var alive={}, out={owners:0, refs:0, bad:[]};
db.user.find({},{_id:1}).forEach(function(u){ alive[String(u._id)]=1; });
db.user.find({},{_id:1,"playerManager.nickName":1,"friendManager":1}).forEach(function(d){
  var fm=d.friendManager||{}, bad=[];
  ["friends","blackFriends","applyFriends","myApplyFriends"].forEach(function(f){
    (fm[f]||[]).forEach(function(x){ if(!alive[String(x)]) bad.push(f+"="+x); });
  });
  ["giveMap","haveRewardMap"].forEach(function(m){
    Object.keys(fm[m]||{}).forEach(function(x){ if(!alive[String(x)]) bad.push(m+"."+x); });
  });
  if(bad.length){
    out.owners++; out.refs+=bad.length;
    out.bad.push({uid:d._id, nick:(d.playerManager||{}).nickName, refs:bad});
  }
});
out.alive = Object.keys(alive).length;
return out;
"""
    res = r.mongo(js) or {}
    bad = res.get('bad') or []
    if a.json:
        print(json.dumps(res, ensure_ascii=False, indent=2))
    elif not bad:
        print('✅ 无失效好友引用（%d 个账号全干净）' % (res.get('alive', 0) or 0))
    else:
        for it in bad:
            print('  %s %s -> %s' % (it['uid'], it.get('nick'), ', '.join(it['refs'])))
        print('\n共 %d 个账号 / %d 条失效引用' % (res.get('owners', 0), res.get('refs', 0)))
        if not a.repair:
            print('加 --repair 清理（数组 pull / map unset），清理后这些号才能正常登录')
            return 2
        rep = r.mongo_eval("""
var alive={}, n=0;
db.user.find({},{_id:1}).forEach(function(u){ alive[String(u._id)]=1; });
db.user.find({},{_id:1,"friendManager":1}).forEach(function(d){
  var fm=d.friendManager||{};
  ["friends","blackFriends","applyFriends","myApplyFriends"].forEach(function(f){
    (fm[f]||[]).forEach(function(x){
      if(!alive[String(x)]){
        var q={}; q["friendManager."+f]=x;
        db.user.updateOne({_id:d._id}, {$pull:q}); n++;
      }
    });
  });
  ["giveMap","haveRewardMap"].forEach(function(m){
    Object.keys(fm[m]||{}).forEach(function(x){
      if(!alive[String(x)]){
        var un={}; un["friendManager."+m+"."+x]="";
        db.user.updateOne({_id:d._id}, {$unset:un}); n++;
      }
    });
  });
});
return {cleaned:n};
""")
        print('已清理 %s 条' % (rep or {}).get('cleaned', '?'))
    return 0


def cmd_purge(a):
    if a.account and str(a.confirm) != str(a.uid):
        print('🔴 删号需要 --confirm <uid> 二次确认（当前 --confirm=%s）' % a.confirm)
        return 3
    what = []
    if not a.account:
        if not a.no_heroes:
            what.append('heroes')
        if not a.no_ranks:
            what.append('ranks')
        if not a.no_refs:
            what.append('refs')
    r = _remote(a)
    p = Purger(r, a.uid, apply=a.apply)
    print('=%s %s uid=%d  %s' % ('=' * 60, 'APPLY' if a.apply else 'DRY-RUN',
                                 a.uid, now_tag()))
    p.run(what=tuple(what), ban=a.ban, delete_account=a.account,
          min_level=a.hero_level, min_star=a.hero_star,
          rank_integrity=not a.no_rank_integrity)
    return 0


def cmd_archive(a):
    """只归档不删：删号/批量处置前先留档（user + 4 个日志集合 + 榜单 + 货币快照）。"""
    r = _remote(a)
    p = Purger(r, a.uid, apply=False)
    print('=%s ARCHIVE uid=%d  %s' % ('=' * 60, a.uid, now_tag()))
    p.archive(with_logs=not a.no_logs)
    return 0


def cmd_ban(a):
    r = _remote(a)
    key = '"%sFORBID_LOGIN:"' % r.key_prefix
    r.redis('HSET', key, str(a.uid), '0')
    print('已封禁 %d（当前值 %s；MinuteTask 1 分钟内生效）'
          % (a.uid, r.redis('HGET', key, str(a.uid)).strip()))
    return 0


def cmd_unban(a):
    r = _remote(a)
    n = r.redis('HDEL', '"%sFORBID_LOGIN:"' % r.key_prefix, str(a.uid))
    print('解封 %d（删除字段数 %s）' % (a.uid, n.strip()))
    return 0


def cmd_banlist(a):
    r = _remote(a)
    ids = r.redis_lines('HKEYS', '"%sFORBID_LOGIN:"' % r.key_prefix)
    print('封禁名单 %d 人: %s' % (len(ids), ', '.join(sorted(ids))))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description='TimeSpaceGirl1 作弊排查 / 处置')
    ap.add_argument('--host', default=None, help='SSH 别名（默认 gs）')
    ap.add_argument('--game-db', default=None)
    ap.add_argument('--login-db', default=None)
    ap.add_argument('--redis-db', default=None)
    sub = ap.add_subparsers(dest='cmd', required=True)

    s = sub.add_parser('scan', help='单号裁决（只读）')
    s.add_argument('--uid', type=int, required=True)
    s.add_argument('--json', action='store_true')
    s.add_argument('--fast', action='store_true', help='跳过 BI 流水（快，但会漏掉 itemLog 断档的情况）')
    s.set_defaults(func=cmd_scan)

    s = sub.add_parser('hunt', help='全服扫可疑号（英雄维度）')
    s.add_argument('--limit', type=int, default=0)
    s.add_argument('--json', action='store_true')
    s.set_defaults(func=cmd_hunt)

    s = sub.add_parser('purge', help='一键处置（默认 dry-run）')
    s.add_argument('--uid', type=int, required=True)
    s.add_argument('--apply', action='store_true')
    s.add_argument('--hero-level', type=int, default=100, help='删除等级 ≥ N 的英雄（默认 100）')
    s.add_argument('--hero-star', type=int, default=None, help='额外要求星级 ≥ N')
    s.add_argument('--no-heroes', action='store_true')
    s.add_argument('--no-ranks', action='store_true')
    s.add_argument('--no-refs', action='store_true')
    s.add_argument('--ban', action='store_true')
    s.add_argument('--no-rank-integrity', action='store_true',
                   help='跳过处置后的全榜失效成员体检（不建议）')
    s.add_argument('--account', action='store_true', help='删整号（必须配 --confirm <uid>）')
    s.add_argument('--confirm', default=None)
    s.set_defaults(func=cmd_purge)

    s = sub.add_parser('rank-audit', help='全榜完整性体检（GHOST 成员会让排行榜打不开）')
    s.add_argument('--repair', action='store_true', help='执行清理（默认只报清单）')
    s.add_argument('--json', action='store_true')
    s.set_defaults(func=cmd_rank_audit)

    s = sub.add_parser('refs-audit', help='好友残留引用体检（会让别人登录卡 45%%）')
    s.add_argument('--repair', action='store_true', help='执行清理（默认只报清单）')
    s.add_argument('--json', action='store_true')
    s.set_defaults(func=cmd_refs_audit)

    s = sub.add_parser('archive', help='只归档不删（user+日志4集合+榜单+货币快照）')
    s.add_argument('--uid', type=int, required=True)
    s.add_argument('--no-logs', action='store_true', help='不导出日志集合（不推荐，删号前必须导）')
    s.set_defaults(func=cmd_archive)

    s = sub.add_parser('ban', help='写 FORBID_LOGIN')
    s.add_argument('--uid', type=int, required=True)
    s.add_argument('--reason', default='GM 指令作弊')
    s.set_defaults(func=cmd_ban)

    s = sub.add_parser('unban', help='解除封禁')
    s.add_argument('--uid', type=int, required=True)
    s.set_defaults(func=cmd_unban)

    s = sub.add_parser('banlist', help='查看封禁名单')
    s.set_defaults(func=cmd_banlist)

    a = ap.parse_args(argv)
    try:
        return a.func(a)
    except RemoteError as e:
        print('🔴 %s' % e)
        return 4


if __name__ == '__main__':
    sys.exit(main())
