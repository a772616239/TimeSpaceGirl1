#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""排行榜完整性体检 / 修复。

## 为什么需要它

服务端的 `RankFirstHandler`（"每个榜第一名"）会遍历**所有**榜逐个调 `getFirst()`，
而 `HeroForceRank.getFirst()` / `getOptional()` 直接解引用 `getHero(heroId)`：

    Hero hero = everyUser.getHeroManager().getHero(heroId);
    builder.setHeroTemplateId(hero.getTemplateId());   // ← hero==null 时 NPE

只要**任意一个榜**的第 1 名指向失效数据，整个 `RankFirstResponse` 就失败，
客户端表现为「排行榜打不开」（2026-10-20 实测：`HeroForceRank.java:69` NPE）。

失效数据有两种，来源不同：

| 类型 | 成因 | 谁负责清 |
|---|---|---|
| `user_gone` | 账号被删（`purge --account` / 手工删号），`uid:heroId` 复合成员留在 zset | **本模块** |
| `hero_gone` | 账号还在，但英雄被删（作弊处置），`heroForceSort` 或 zset 残留 | `purge` 的 `clean_ranks` + 本模块兜底 |

🔴 其它榜不会崩是因为 `AbstractRank.getOneUserRank()` 对 `everyUser == null` 做了判空，
返回一个空 builder；只有 `HeroForceRank` 多做了一步英雄解引用，才把空值放大成异常。

## 判定口径

- 成员形如 `uid` 或 `uid:heroId`；取第一个冒号前的 token。
- 只有匹配 `^1\\d{7}$`（本服 uid 段 10000001~10000249）才当 uid 处理
  —— 公会榜成员是 `3`/`4` 这样的 guildId，**绝不能被误删**。
- uid 不在 `user` 集合 → `user_gone`；uid 在但英雄不在 heroMap → `hero_gone`。
"""
import re

UID_RE = re.compile(r'^1\d{7}$')


class RankIntegrity(object):
    def __init__(self, remote, apply=False, on_log=None):
        self.r = remote
        self.apply = apply
        self._log_cb = on_log
        self.alive = None       # {'uids': set, 'heroes': {uid: set}}

    # ------------------------------------------------------------ 工具
    def _log(self, msg):
        if self._log_cb:
            self._log_cb(msg)
        else:
            print(('  [APPLY] ' if self.apply else '  [dry-run] ') + msg)

    # ------------------------------------------------------------ 取数
    def load_alive(self):
        """一次 mongo 往返拿到全部 uid 与其英雄 id（本服 209 个账号，量很小）。"""
        js = """
var out={uids:[],heroes:{}};
db.user.find({}, {_id:1,"heroManager.heroMap":1}).forEach(function(u){
  var id=String(u._id);
  out.uids.push(id);
  out.heroes[id]=Object.keys((u.heroManager&&u.heroManager.heroMap)||{});
});
return out;
"""
        data = self.r.mongo(js, required=True) or {}
        self.alive = {
            'uids': set(data.get('uids') or []),
            'heroes': {k: set(v or []) for k, v in (data.get('heroes') or {}).items()},
        }
        return self.alive

    def load_members(self):
        """一次 SSH 往返把全部榜单成员抓回来（key → [member,...]）。

        逐 key 调 redis-cli 会有 ~90 次进程启动，这里整段塞进远端一个 shell。
        """
        members = self.r.all_rank_members()
        return members

    # ------------------------------------------------------------ 审计
    def audit(self):
        """返回 {'keys': n, 'members': n, 'ghosts': [{key,member,uid,reason}]}"""
        if self.alive is None:
            self.load_alive()
        members = self.load_members()
        ghosts, total = [], 0
        for key, ms in sorted(members.items()):
            for m in ms:
                total += 1
                g = self.classify(key, m)
                if g:
                    ghosts.append(g)
        return {'keys': len(members), 'members': total, 'ghosts': ghosts}

    def classify(self, key, member):
        """判断单个成员是否失效；失效返回 dict，正常返回 None。"""
        token = member.split(':', 1)[0]
        if not UID_RE.match(token):
            return None                      # 公会 id 等非玩家成员，跳过
        uid = token
        if uid not in self.alive['uids']:
            return {'key': key, 'member': member, 'uid': uid, 'reason': 'user_gone'}
        if ':' in member:
            hero_id = member.split(':', 1)[1]
            if hero_id not in self.alive['heroes'].get(uid, set()):
                return {'key': key, 'member': member, 'uid': uid, 'reason': 'hero_gone'}
        return None

    # ------------------------------------------------------------ 修复
    def repair(self, ghosts):
        if not ghosts:
            return 0
        if not self.apply:
            return len(ghosts)
        pairs = [(g['key'], g['member']) for g in ghosts]
        self.r.zrem_batch(pairs)
        return len(pairs)

    # ------------------------------------------------------------ 一步到位
    def run(self, repair=True):
        rep = self.audit()
        ghosts = rep['ghosts']
        self._log('榜单体检: %d 个榜 / %d 个成员 / 失效 %d 条'
                  % (rep['keys'], rep['members'], len(ghosts)))
        by_reason = {}
        for g in ghosts:
            by_reason.setdefault(g['reason'], []).append(g)
        for reason, items in sorted(by_reason.items()):
            self._log('  %s: %d 条' % (reason, len(items)))
            for g in items[:6]:
                self._log('    - %s  ←  %s' % (g['member'], g['key']))
            if len(items) > 6:
                self._log('    ... 其余 %d 条' % (len(items) - 6))
        if repair and ghosts:
            n = self.repair(ghosts)
            self._log('已清理 %d 条失效成员%s' % (n, '' if self.apply else '（dry-run 未写入）'))
        rep['repaired'] = (len(ghosts) if self.apply else 0)
        return rep
