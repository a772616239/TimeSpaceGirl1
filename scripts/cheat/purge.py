#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""处置层（写操作，默认 dry-run）。

一键做四件事，顺序不可换：
    备份 → 删作弊产物（英雄/物品）→ 清排行榜引用 → 封号（可选）→ 校验

🔴 三条硬规则：
  1. **先备份**：user 文档 + 榜单快照落到 `/root/incident_<tag>_<uid>/`，同时在本地
     `scripts/cheat/reports/` 写 manifest.json（含回滚命令）。
  2. **排行榜必须在删数据「之前或同时」清**：只删 Redis 成员，别整榜清空
     （db0 约 6750 个 key、近 5000 个是排行，清空不可恢复）。
  3. **删号 ≠ 封号**：本服「查不到 user 就自动建档」，删号只是重置。要真正拦住必须写
     `10001:FORBID_LOGIN:`（Redis，重启不丢）。
"""
import json
import os

from .remote import Remote, RemoteError, js_int

HERO_LEVEL_FLOOR = 100      # 「异常英雄」默认下界（正常 6 级号最高 30 级）


class Purger(object):
    def __init__(self, remote, uid, apply=False, report_dir=None):
        self.r = remote
        self.uid = int(uid)
        self.apply = bool(apply)
        self.tag = None
        self.bdir = None
        self.manifest = {'uid': self.uid, 'apply': self.apply, 'actions': [], 'backup': {}}
        here = os.path.dirname(os.path.abspath(__file__))
        self.report_dir = report_dir or os.path.join(here, 'reports')

    # -------------------------------------------------------------- 工具
    def _log(self, msg):
        print(('  [APPLY] ' if self.apply else '  [dry-run] ') + msg)

    def _record(self, kind, detail):
        self.manifest['actions'].append({'kind': kind, 'detail': detail,
                                         'applied': self.apply})

    # -------------------------------------------------------------- 备份
    def backup(self):
        self.tag = self.r.out('date +%Y%m%d-%H%M%S') or 'now'
        self.bdir = '/root/incident_%s_%d' % (self.tag.replace('-', ''), self.uid)
        self.r.mkdir(self.bdir)
        user_json = '%s/user_%d_%s.json' % (self.bdir, self.uid, self.tag)
        ok, err = self.r.export('user', {'_id': self.uid}, user_json)
        self.manifest['backup']['user'] = {'path': user_json, 'ok': ok}
        if not ok:
            raise RemoteError('备份失败，已中止：%s' % err)

        # 榜单快照（只快照命中的 key）
        snaps = []
        for hit in self.rank_hits():
            name = hit['key'].replace(':', '_')
            path = '%s/rank_%s_%s.txt' % (self.bdir, name, self.tag)
            self.r.sh('redis-cli -n %s ZREVRANGE "%s" 0 -1 WITHSCORES > "%s"'
                      % (self.r.redis_db, hit['key'], path))
            snaps.append(path)
        self.manifest['backup']['ranks'] = snaps
        self._log('备份目录 %s（user 文档 %s，榜单快照 %d 份）'
                  % (self.bdir, 'ok' if ok else 'FAIL', len(snaps)))
        return self.bdir

    def write_manifest(self):
        os.makedirs(self.report_dir, exist_ok=True)
        path = os.path.join(self.report_dir, '%d_%s.json' % (self.uid, self.tag or 'dry'))
        self.manifest['rollback'] = self.rollback_commands()
        with open(path, 'w') as f:
            json.dump(self.manifest, f, ensure_ascii=False, indent=2)
        return path

    def rollback_commands(self):
        m = self.manifest['backup']
        cmds = []
        if m.get('user', {}).get('path'):
            cmds.append('mongoimport -d %s -c user --file %s --mode=upsert'
                        % (self.r.game_db, m['user']['path']))
        if self.manifest.get('removed_heroes'):
            cmds.append('# 英雄回滚：从上面的 user 文档快照恢复，或按 manifest.removed_heroes 的 id 重建')
        if self.manifest.get('banned'):
            cmds.append('redis-cli -n %s HDEL "%sFORBID_LOGIN:" %d'
                        % (self.r.redis_db, self.r.key_prefix, self.uid))
        if self.manifest.get('deleted_account'):
            cmds.append('# 账号已删除：mongoimport --mode=upsert 上面那份 user 文档即可复活（数据回到删前）')
        return cmds

    # -------------------------------------------------------------- 选英雄
    def select_heroes(self, min_level=HERO_LEVEL_FLOOR, min_star=None):
        js = """
var u=db.user.findOne({_id:%d});
if(!u) return {exists:false};
var hm=(u.heroManager&&u.heroManager.heroMap)||{};
var del=[],keep=[],tids={};
for(var k in hm){
  var h=hm[k]||{}, lv=Number(h.level||0), st=Number(h.star||0);
  var hit = lv >= %d%s;
  (hit?del:keep).push({id:k, tid:Number(h.templateId||0), lv:lv, star:st,
                       ct:Number(h.createTime||0)});
  if(hit) tids[String(h.templateId)]=1;
}
// 同一模板若还有合法英雄保留，则不动图鉴
keep.forEach(function(h){ delete tids[String(h.tid)]; });
return {exists:true, del:del, keep:keep, tids:Object.keys(tids)};
""" % (self.uid, int(min_level),
       (' && st >= %d' % int(min_star)) if min_star is not None else '')
        return self.r.mongo(js) or {}

    # -------------------------------------------------------------- 选榜
    def rank_hits(self):
        """该 uid 出现在哪些榜单：普通成员 + `uid:heroId` 复合成员 + 奖励快照 JSON。"""
        hits = []
        for key, members in (self.r.rank_members(self.uid) or {}).items():
            hits.append({'key': key, 'type': 'zset', 'members': members})
        for key in self.r.scan('%s*:RANKING_DATA' % self.r.key_prefix):
            for field, val in self.r.hgetall(key).items():
                if str(self.uid) in (val or ''):
                    hits.append({'key': key, 'type': 'hash', 'field': field, 'value': val})
        return hits

    # -------------------------------------------------------------- 动作
    def purge_heroes(self, min_level=HERO_LEVEL_FLOOR, min_star=None):
        plan = self.select_heroes(min_level, min_star)
        if not plan.get('exists'):
            raise RemoteError('user %d 不存在' % self.uid)
        del_heroes = plan.get('del') or []
        if not del_heroes:
            self._log('无符合条件的英雄（level>=%d），跳过' % min_level)
            return 0

        self._log('删除 %d 个英雄（模板 %d 个），保留 %d 个'
                  % (len(del_heroes), len(plan.get('tids') or []), len(plan.get('keep') or [])))
        for h in del_heroes[:6]:
            self._log('  - %s  tid=%s  %s★ / %s 级' % (h['id'], h['tid'], h['star'], h['lv']))
        if len(del_heroes) > 6:
            self._log('  ... 其余 %d 个' % (len(del_heroes) - 6))

        if not self.apply:
            self.manifest['removed_heroes'] = [h['id'] for h in del_heroes]
            self._record('heroes.delete', {'n': len(del_heroes), 'tids': plan['tids']})
            return len(del_heroes)

        js = ['var u = db.user.findOne({_id:%d});' % self.uid]
        js.append('var del = %s;' % json.dumps([h['id'] for h in del_heroes]))
        js.append('var tids = %s;' % json.dumps(plan['tids']))
        js.append("""
var un={}; del.forEach(function(id){ un["heroManager.heroMap."+id]=""; });
db.user.updateOne({_id:%d}, {$unset: un});
db.user.updateOne({_id:%d}, {$set: {"heroManager.heroForceSort": {}}});
var u1={}, u2={};
tids.forEach(function(t){
  u1["heroManager.heroStarMap."+t]="";
  u2["heroManager.heroHandBook."+t]="";
});
if(Object.keys(u1).length) db.user.updateOne({_id:%d}, {$unset: u1});
if(Object.keys(u2).length) db.user.updateOne({_id:%d}, {$unset: u2});
var after=db.user.findOne({_id:%d});
return {heroN:Object.keys((after.heroManager&&after.heroManager.heroMap)||{}).length};
""" % (self.uid, self.uid, self.uid, self.uid, self.uid))
        res = self.r.mongo('\n'.join(js), required=True) or {}
        self.manifest['removed_heroes'] = [h['id'] for h in del_heroes]
        self._record('heroes.delete', {'n': len(del_heroes), 'tids': plan['tids'],
                                       'heroN_after': res.get('heroN')})
        self._log('删除完成，剩余英雄 %s 个' % res.get('heroN'))
        return len(del_heroes)

    def clean_ranks(self):
        hits = self.rank_hits()
        if not hits:
            self._log('排行榜无该 uid 的条目')
            return 0
        n = 0
        for hit in hits:
            if hit['type'] == 'zset':
                self._log('%s ← 删除 %d 个成员: %s' % (
                    hit['key'], len(hit['members']), ', '.join(hit['members'][:5])))
                if self.apply:
                    for m in hit['members']:
                        self.r.redis('ZREM', '"%s"' % hit['key'], '"%s"' % m)
                        n += 1
                else:
                    n += len(hit['members'])
            else:
                self._log('%s[%s] ← 奖励快照里含 %d（需剔除后写回）'
                          % (hit['key'], hit['field'], self.uid))
                if self.apply:
                    n += self._rewrite_ranking_data(hit)
        self._record('ranks.clean', {'hits': hits, 'n': n})
        return n

    def _rewrite_ranking_data(self, hit):
        """RANKING_DATA 的 value 是 {"时间戳": uid, ...}，必须解析后剔除再写回（禁止 sed）。"""
        raw = self.r.redis('HGET', '"%s"' % hit['key'], '"%s"' % hit['field'])
        try:
            data = json.loads(raw)
        except ValueError:
            return 0
        keep = {k: v for k, v in data.items() if str(v) != str(self.uid)}
        if len(keep) == len(data):
            return 0
        self.r.redis('HSET', '"%s"' % hit['key'], '"%s"' % hit['field'],
                     "'%s'" % json.dumps(keep, separators=(',', ':')))
        return len(data) - len(keep)

    def clean_mongo_refs(self):
        """supremacyInfo（最容易漏）+ guildInfo（会长位空了会崩排行榜）。"""
        js = """
var U=%d, out={sup:0, guild:[]};
db.supremacyInfo.find({uid:U}).forEach(function(d){ out.sup++; });
db.guildInfo.find().forEach(function(g){
  if(!g.members) return;
  var hit=false;
  Object.keys(g.members).forEach(function(pos){
    if((g.members[pos]||[]).indexOf(U)>=0) hit=true;
  });
  if(hit) out.guild.push(g._id);
});
return out;
""" % self.uid
        refs = self.r.mongo(js) or {}
        self._log('supremacyInfo 命中 %s 处，guildInfo 命中 %s 个'
                  % (refs.get('sup', 0), len(refs.get('guild') or [])))
        if self.apply and refs.get('sup'):
            self.r.mongo_eval('db.supremacyInfo.updateMany({uid:%d},{$set:{uid:0}});' % self.uid)
        if self.apply and refs.get('guild'):
            self.r.mongo_eval(
                'db.guildInfo.find().forEach(function(g){'
                'if(!g.members) return;'
                'Object.keys(g.members).forEach(function(p){'
                'db.guildInfo.updateOne({_id:g._id},{$pull:{"members."+p:%d}});});});' % self.uid)
            self._check_guild_leaders()
        self._record('mongo.refs', refs)
        return refs

    def clean_player_refs(self):
        """删号前清「玩家间引用」：好友 / 黑名单 / 申请列表 / 体力互赠表。

        2026-10-20 教训（同一根因家族第二次复发）：只删 `user`、不清别人家的
        `friendManager`，对方下次登录走 `GET_FRIEND_INFO` 时
        `CBean2Proto.getFriendInfo → UserManager.getUser` 会抛
        「1-UserManager::getUser null exception」，整包好友信息失败，
        登录链停在第 26/57 步 ⇒ 客户端进度条永远卡 45%（Sakuya 10000017 实测）。
        所以删号三步曲必须是 clean_ranks → clean_player_refs → clean_mongo_refs → delete_account。
        """
        js = """
var U=%d, out={friends:0, black:0, apply:0, myApply:0, give:0, haveReward:0};
db.user.find({"friendManager":{$exists:true}}).forEach(function(d){
  var fm=d.friendManager||{};
  if((fm.friends||[]).indexOf(U)>=0) out.friends++;
  if((fm.blackFriends||[]).indexOf(U)>=0) out.black++;
  if((fm.applyFriends||[]).indexOf(U)>=0) out.apply++;
  if((fm.myApplyFriends||[]).indexOf(U)>=0) out.myApply++;
  if(fm.giveMap && fm.giveMap[String(U)]!==undefined) out.give++;
  if(fm.haveRewardMap && fm.haveRewardMap[String(U)]!==undefined) out.haveReward++;
});
return out;
""" % self.uid
        refs = self.r.mongo(js) or {}
        total = sum(int(refs.get(k) or 0) for k in
                    ('friends', 'black', 'apply', 'myApply', 'give', 'haveReward'))
        self._log('玩家间引用：friends=%s black=%s apply=%s myApply=%s giveMap=%s haveReward=%s'
                  % (refs.get('friends', 0), refs.get('black', 0), refs.get('apply', 0),
                     refs.get('myApply', 0), refs.get('give', 0), refs.get('haveReward', 0)))
        if self.apply and total:
            self.r.mongo_eval("""
var U=%d;
db.user.find({"friendManager":{$exists:true}}).forEach(function(d){
  db.user.updateOne({_id:d._id},{
    $pull:{"friendManager.friends":U,"friendManager.blackFriends":U,
           "friendManager.applyFriends":U,"friendManager.myApplyFriends":U},
    $unset:{"friendManager.giveMap."+U:"","friendManager.haveRewardMap."+U:""}
  });
});
""" % self.uid)
        self._record('player.refs', refs)
        return total

    def _check_guild_leaders(self):
        js = """
var bad=[];
db.guildInfo.find().forEach(function(g){
  var m1=g.members?g.members["1"]:null;
  var first=(m1&&m1.length)?m1[0]:null;
  var ok=first?db.user.count({_id:first}):-1;
  if(ok!==1) bad.push({gid:g._id, leaders:m1});
});
return bad;
"""
        bad = self.r.mongo(js) or []
        for b in bad:
            print('  🔴 [会长位] 公会 %s 的职位 1 = %s —— 必须手工补一个存活会长，否则 '
                  'GuildForceRank.getFirst 的 iterator().next() 会抛异常'
                  % (b.get('gid'), b.get('leaders')))

    def ban(self, reason='GM 指令作弊'):
        key = '"%sFORBID_LOGIN:"' % self.r.key_prefix
        if self.apply:
            self.r.redis('HSET', key, str(self.uid), '0')
        cur = self.r.redis('HGET', key, str(self.uid)).strip()
        self.manifest['banned'] = True
        self.manifest['ban_reason'] = reason
        self._record('ban', {'uid': self.uid, 'reason': reason, 'verify': cur})
        self._log('写入封禁名单（当前值 %s，1 分钟内 MinuteTask 生效）' % (cur or '0'))

    def delete_account(self):
        """⚠️ 只重置，不拦人；必须配合 ban()。"""
        self._log('删除 user 文档 + 各日志集合 + 会话 key')
        if not self.apply:
            self.manifest['deleted_account'] = True
            self._record('account.delete', {'uid': self.uid})
            return
        self.r.mongo_eval("""
db.user.deleteOne({_id:%d});
db.itemLog.deleteMany({uid:%d});
db.heroLog.deleteMany({uid:%d});
db.fightLog.deleteMany({uid:%d});
db.storeLog.deleteMany({uid:%d});
""" % (self.uid, self.uid, self.uid, self.uid, self.uid))
        for k in ['JL_TOKEN:%d' % self.uid, 'USER_LOGIN_URL:%d' % self.uid,
                  'PIDGIDTEMP:%d' % self.uid,
                  'null:INDICATION_OFFLINE_INDEX:%d' % self.uid,
                  'null:LEVE_DIFFICULTY_INFO:%d' % self.uid,
                  'null:RESPONSE_OFFLINE:%d' % self.uid]:
            self.r.redis('DEL', '"%s"' % k)
        self.manifest['deleted_account'] = True
        self._record('account.delete', {'uid': self.uid})

    # -------------------------------------------------------------- 校验
    def verify(self):
        js = """
var u=db.user.findOne({_id:%d});
if(!u) return {exists:false};
var hm=(u.heroManager&&u.heroManager.heroMap)||{};
var mx=0,n100=0,n=0;
for(var k in hm){var h=hm[k]||{};n++;var l=Number(h.level||0);
  if(l>mx)mx=l; if(l>=100)n100++;}
return {exists:true, heroN:n, maxLv:mx, n100:n100,
        heroForceSortN:Object.keys((u.heroManager&&u.heroManager.heroForceSort)||{}).length,
        starMapN:Object.keys((u.heroManager&&u.heroManager.heroStarMap)||{}).length,
        handBookN:Object.keys((u.heroManager&&u.heroManager.heroHandBook)||{}).length,
        maxForce:Number((u.playerManager||{}).maxForce||0)};
""" % self.uid
        state = self.r.mongo(js) or {}
        ranks = self.rank_hits()
        banned = self.r.redis('HEXISTS', '"%sFORBID_LOGIN:"' % self.r.key_prefix,
                              str(self.uid)).strip().endswith('1')
        state['rank_residue'] = len(ranks)
        state['banned'] = banned
        ri = self.manifest.get('rank_integrity') or {}
        state['ghost_rank_members'] = ri.get('ghosts')
        state['ghost_rank_repaired'] = ri.get('repaired')
        self.manifest['verify'] = state
        print('  校验: 英雄 %s 个 / 最高 %s 级 / ≥100 级 %s 个 / heroForceSort %s 条 / '
              '榜残留 %s / 封禁 %s / 全榜失效成员 %s（已清 %s）' % (
                  state.get('heroN', '-'), state.get('maxLv', '-'), state.get('n100', '-'),
                  state.get('heroForceSortN', '-'), state.get('rank_residue'), state.get('banned'),
                  state.get('ghost_rank_members', '-'), state.get('ghost_rank_repaired', '-')))
        return state

    # -------------------------------------------------------------- 编排
    def run(self, what=('heroes', 'ranks', 'refs'), ban=False, delete_account=False,
            min_level=HERO_LEVEL_FLOOR, min_star=None, rank_integrity=True):
        self.backup()
        if delete_account:
            # 🔴 顺序不能反：必须先清榜再删号。
            #    删号后再清，rank_members 仍能按 uid 前缀捞到成员，但「英雄是否还在」
            #    已经无从判定；更重要的是早期版本在 --account 分支里**根本没调 clean_ranks**，
            #    于是 `uid:heroId` 复合成员永远留在 zset 里，成为幽灵榜一，
            #    下一次某个玩家打开排行榜就 getFirst NPE（2026-10-20 复现）。
            self.clean_ranks()
            self.clean_player_refs()
            self.clean_mongo_refs()
            self.delete_account()
        else:
            if 'heroes' in what:
                self.purge_heroes(min_level=min_level, min_star=min_star)
            if 'ranks' in what:
                self.clean_ranks()
            if 'refs' in what:
                self.clean_mongo_refs()
        if ban:
            self.ban()
        # 🔴 兜底体检：删英雄/删号都会在榜单留下指向已消失实体的成员，
        #    而 HeroForceRank.getFirst 缺判空 ⇒ 一条脏数据 = 整个排行榜打不开。
        if rank_integrity:
            self.check_rank_integrity()
        self.verify()
        path = self.write_manifest()
        print('  manifest: %s' % path)
        if not self.apply:
            print('  ⚠️ 以上为 dry-run，确认无误后加 --apply')
        return self.manifest

    def check_rank_integrity(self):
        """全榜体检：清掉「账号已消失」或「英雄已消失」的失效成员。"""
        from .rankint import RankIntegrity
        ri = RankIntegrity(self.r, apply=self.apply, on_log=self._log)
        rep = ri.run(repair=True)
        self.manifest['rank_integrity'] = {
            'keys': rep['keys'], 'members': rep['members'],
            'ghosts': len(rep['ghosts']), 'repaired': rep['repaired'],
            'detail': rep['ghosts'][:50],
        }
        self._record('ranks.integrity', {'ghosts': len(rep['ghosts']),
                                         'repaired': rep['repaired']})
        return rep

