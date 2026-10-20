#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""取证与判定层（只读）。

判据分三档，来自 2026-10-10「朗曼梅西」与 2026-10-18「Sieg / Mozart」两轮实战：
  hard —— 命中即 CHEAT（正常玩法不可能产生）
  soft —— 需要两条以上同时成立才判 SUSPECT
  info —— 只打印，不参与判定

🔴 三条血泪教训（改判据前必读）：
  1. **Mongo `itemLog` 会整段断档**（10000221–10000225 全为 0），空表上的「收支对账」恒闭合；
     真正的账在 BI 文件流水 `assets/log/jl_item/<date>/item0.log`，保留期远长于
     `/data/srvlog/gameserver.log`（后者只有 2~3 天）。
  2. **GM 改星级/等级不写 `heroLog`**（只有 `upHeroLevel`/`upHeroStar` 写），所以
     「heroLog 干净」证明不了什么；`Hero_Star` 造出来的英雄是 `level=openLevel(star)`、
     `star=maxRank`，且**创建即该属性**。
  3. **「英雄等级高」本身不是证据**：要有同级分位对照 + 创建时间突发（脚本按模板 ID 顺序发）。
  4. 🔴 **货币 id 不许写死**：2026-10-18 的误封源于 `itemMap["3"]`（英雄经验）被当成钻石。
     现在 id→名字一律走 `currency.load_names()`（读 `conf/server/ItemConfig.txt`+`Language.txt`），
     字段常量见 `currency.DIAMOND/GOLD/HERO_EXP/PLAYER_EXP`（16/14/3/17）。
"""
import datetime
import re
import time

from . import currency
from .remote import js_int

# ------------------------------------------------------------------ 阈值
TH = {
    'hero_level_hard': 200,        # 单英雄等级 ≥200 → 硬信号（openLevel 上限 340）
    'hero_level_floor': 100,       # 处置默认下界：删除等级 ≥100 的英雄
    'hero_count_maxlevel': 5,      # ≥100 级英雄数量超过此值 → 需对照同级
    'hero_burst_sec': 120,         # N 个英雄在此窗口内创建 → 脚本化发放
    'hero_burst_n': 8,
    'gm_request_max': 12,          # 新手引导约 3~12 条 GM_REQUEST
    'gm_reward_max': 0,            # reason=28（GM_REWARD）出现即硬信号
    'gold_outlier_x': 3.0,         # 金币 > 活跃号 P90 × 3
    'peer_band': 5,                # 同级对照：等级 ±5
    'bi_days': 30,                 # BI 流水回溯天数
}

HARD = 'hard'
SOFT = 'soft'
INFO = 'info'


class Finding(object):
    def __init__(self, level, code, title, detail='', evidence=None):
        self.level = level
        self.code = code
        self.title = title
        self.detail = detail
        self.evidence = evidence or {}

    def as_dict(self):
        return {'level': self.level, 'code': self.code, 'title': self.title,
                'detail': self.detail, 'evidence': self.evidence}


class Report(object):
    def __init__(self, uid):
        self.uid = uid
        self.profile = {}
        self.findings = []
        self.errors = []

    def add(self, *a, **kw):
        self.findings.append(Finding(*a, **kw))

    @property
    def verdict(self):
        if any(f.level == HARD for f in self.findings):
            return 'CHEAT'
        if len([f for f in self.findings if f.level == SOFT]) >= 2:
            return 'SUSPECT'
        return 'CLEAN'

    @property
    def residue(self):
        """「还能删什么」：历史作弊证据（BI 流水）会永久保留，不能当处置未完成的标志。"""
        p = self.profile or {}
        heroes = p.get('heroes') or []
        return {
            'heroes_to_delete': len([h for h in heroes if h['lv'] >= TH['hero_level_floor']]),
            'rank_entries': sum(len(h.get('members') or [1]) for h in (p.get('rank_hits') or [])),
            'account_exists': bool(p.get('exists')),
        }

    def as_dict(self):
        return {'uid': self.uid, 'verdict': self.verdict, 'residue': self.residue,
                'profile': self.profile,
                'findings': [f.as_dict() for f in self.findings],
                'errors': self.errors}


# ------------------------------------------------------------------ 采集
PROFILE_JS = """
var U=%(uid)d;
var u=db.user.findOne({_id:U});
if(!u) return {exists:false,uid:U};
// itemLog 13 万条且 uid 无索引：把 4 次 count/find 合并成一次聚合（否则单号扫描要 30s+）
var __log=db.itemLog.aggregate([{$match:{uid:U}},{$group:{_id:null,
  n:{$sum:1}, gm:{$sum:{$cond:[{$eq:["$reason",28]},1,0]}},
  mx:{$max:{$cond:[{$eq:["$reason",28]},"$itemNum",0]}}}}]).toArray()[0]||{};
var pm=u.playerManager||{}, hm=(u.heroManager&&u.heroManager.heroMap)||{};
var im=(u.itemManager&&u.itemManager.itemMap)||{};
var heroes=[],lv=[],st=[];
Object.keys(hm).forEach(function(k){
  var h=hm[k]||{};
  heroes.push({id:k, tid:Number(h.templateId||0), lv:Number(h.level||0),
               star:Number(h.star||0), ct:Number(h.createTime||0)});
  lv.push(Number(h.level||0)); st.push(Number(h.star||0));
});
heroes.sort(function(a,b){return a.ct-b.ct;});
return {exists:true, uid:U, nick:pm.nickName||"", openId:pm.openId||"",
  level:Number(pm.level||0), force:Number(pm.maxForce||0), vip:Number(pm.vipLevel||0),
  createTime:Number(pm.createTime||0), loginTime:Number(pm.loginTime||0),
  guildId:Number(pm.guildId||0),
  gold:Number((im["14"]||{}).itemNum||0), diamond:Number((im["16"]||{}).itemNum||0),
  heroExp:Number((im["3"]||{}).itemNum||0), exp:Number((im["17"]||{}).itemNum||0),
  items:(function(){var c={},ids=[3,4,7,8,14,16,17,19,20,79];
    for(var i=0;i<ids.length;i++){var k=""+ids[i];c[k]=Number(((im[k]||{}).itemNum)||0);}return c;})(),
  heroes:heroes, heroN:heroes.length,
  heroMaxLv: lv.length?Math.max.apply(null,lv):0,
  heroMaxStar: st.length?Math.max.apply(null,st):0,
  heroSumLv: lv.reduce(function(a,b){return a+b;},0),
  heroForceSortN: Object.keys((u.heroManager&&u.heroManager.heroForceSort)||{}).length,
  itemLogN: Number((__log||{}).n||0), heroLogN: db.heroLog.count({uid:U}),
  fightLogN: db.fightLog.count({uid:U}), storeLogN: db.storeLog.count({uid:U}),
  gmRewardN: Number((__log||{}).gm||0),
  gmRewardMax: Number((__log||{}).mx||0)
};
"""

PEER_JS = """
var U=%(uid)d, BAND=%(band)d;
var me=db.user.findOne({_id:U});
if(!me) return {};
var lv0=Number((me.playerManager||{}).level||0);
var arr=[];
db.user.find({_id:{$ne:U}}).forEach(function(u){
  var lv=Number((u.playerManager||{}).level||0);
  if(Math.abs(lv-lv0)>BAND) return;
  var hm=(u.heroManager&&u.heroManager.heroMap)||{};
  var mx=0,n100=0;
  for(var k in hm){var h=hm[k]||{};var l=Number(h.level||0);
    if(l>mx)mx=l; if(l>=100)n100++;}
  arr.push([mx,n100]);
});
arr.sort(function(a,b){return a[0]-b[0];});
function pct(p){ if(!arr.length) return 0; return arr[Math.min(arr.length-1,Math.floor(arr.length*p))][0]; }
var n100s=arr.map(function(x){return x[1];}).sort(function(a,b){return a-b;});
return {peerN:arr.length, lvBand:[Math.max(0,lv0-BAND),lv0+BAND],
        maxLvP50:pct(0.5), maxLvP90:pct(0.9), maxLvP99:pct(0.99),
        n100Max:n100s.length?n100s[n100s.length-1]:0};
"""

GOLD_JS = """
var cnt={};
db.itemLog.aggregate([{$group:{_id:"$uid", n:{$sum:1}}}]).forEach(function(d){ cnt[d._id]=d.n; });
var gold=[], dia=[];
db.user.find({}).forEach(function(u){
  if((cnt[u._id]||0)<500) return;            // 只取活跃号（itemLog ≥500 条）
  var im=(u.itemManager&&u.itemManager.itemMap)||{};
  gold.push(Number((im["14"]||{}).itemNum||0));
  dia.push(Number((im["16"]||{}).itemNum||0));   // 16=钻石（3 是英雄经验，别再用错）
});
function pct(a,p){
  var b=a.slice().sort(function(x,y){return x-y;});
  return b.length?b[Math.min(b.length-1,Math.floor(b.length*p))]:0;
}
function mx(a){var b=a.slice().sort(function(x,y){return x-y;});return b.length?b[b.length-1]:0;}
return {activePlayers:gold.length,
        goldP50:pct(gold,0.5), goldP90:pct(gold,0.9),
        diaP50:pct(dia,0.5), diaP90:pct(dia,0.9), diaP99:pct(dia,0.99), diaMax:mx(dia)};
"""


class Detector(object):
    def __init__(self, remote, uid=None):
        self.r = remote
        self.uid = uid
        # id→名字只在启动时读一次配置表（本地 conf 优先，其次远端）
        self.currency_names, self.currency_src = currency.load_names(remote)

    # ------------------------------------------------------------ 单号
    def scan(self, uid=None, deep=True):
        uid = int(uid or self.uid)
        rep = Report(uid)
        prof = self.r.mongo(PROFILE_JS % {'uid': uid}) or {}
        if not prof.get('exists'):
            rep.profile = {'exists': False}
            rep.errors.append('user %d 不存在' % uid)
            return rep
        rep.profile = prof

        self._check_heroes(rep, prof)
        self._check_gm_reward_db(rep, prof)
        self._check_peers(rep, prof)
        self._check_gold(rep, prof)
        self._check_ranks(rep, uid)
        self._check_gm_requests(rep, uid)
        if deep:
            self._check_bi_log(rep, uid)
            self._check_ban(rep, uid)
        else:
            rep.add(INFO, 'fast_mode',
                    '--fast：已跳过 BI 文件流水，结论可能假阴性',
                    'itemLog 断档时（如 10000224）唯一证据只在 BI 流水里，正式裁决请去掉 --fast')
        return rep

    # ------------------------------------------------------------ 单项判据
    def _check_heroes(self, rep, prof):
        heroes = prof.get('heroes') or []
        max_lv = prof.get('heroMaxLv', 0)
        max_star = prof.get('heroMaxStar', 0)
        if max_lv >= TH['hero_level_hard']:
            top = sorted([h for h in heroes if h['lv'] >= TH['hero_level_floor']],
                         key=lambda h: -h['lv'])[:5]
            # ⚠️ 只有等级高不算证据：满配大佬的 340 级是合法养成。真正的硬信号是
            #    它与「同级玩家分位」的比值（见 _check_peers）+ 创建突发。
            rep.add(INFO, 'hero_high_level',
                    '有英雄达到 %d 级（%d 星）' % (max_lv, max_star),
                    '%d 个英雄 ≥%d 级；需与同级分位对照后才可判定' % (
                        len([h for h in heroes if h['lv'] >= TH['hero_level_floor']]),
                        TH['hero_level_floor']),
                    {'top': top, 'heroN': prof.get('heroN')})

        # 创建突发：脚本按模板顺序逐个人发，间隔 1~2s。
        # 🔴 只看「异常英雄」（level>=floor 或 star>=10）——正常十连抽也是 10 个英雄
        # 在同一秒创建，但那些是 1 级新号，不能算证据（10000248 就是这么误报的）。
        abnormal = [h for h in heroes
                    if h['lv'] >= TH['hero_level_floor'] or h['star'] >= 10]
        times = sorted(h['ct'] for h in abnormal if h['ct'])
        burst = []
        for i, t in enumerate(times):
            win = [x for x in times[i:] if x - t <= TH['hero_burst_sec']]
            if len(win) > len(burst):
                burst = win
        if len(burst) >= TH['hero_burst_n']:
            rep.add(HARD, 'hero_burst',
                    '%d 秒内创建了 %d 个英雄' % (TH['hero_burst_sec'], len(burst)),
                    '正常抽卡/任务不会在这个密度内连续获得英雄，是脚本按模板 ID 顺序发放的特征',
                    {'first': burst[0], 'last': burst[-1], 'n': len(burst)})

        # 等级总和 vs 账号等级：6 级账号不可能有几十万级总养成
        lv, sum_lv = prof.get('level', 0), prof.get('heroSumLv', 0)
        if lv and sum_lv and sum_lv > lv * 60 and sum_lv > 2000:
            rep.add(SOFT, 'hero_progress_skew',
                    '英雄养成总量与账号等级严重不匹配',
                    '账号 %d 级，英雄等级总和 %d（均值 %.1f 级/个）' % (
                        lv, sum_lv, sum_lv / max(1, prof.get('heroN', 1))),
                    {'level': lv, 'sumLevel': sum_lv, 'heroN': prof.get('heroN')})

    def _check_peers(self, rep, prof):
        peers = self.r.mongo(PEER_JS % {'uid': rep.uid, 'band': TH['peer_band']}) or {}
        if not peers or not peers.get('peerN'):
            return
        mine = prof.get('heroMaxLv', 0)
        p99 = peers.get('maxLvP99', 0)
        rep.profile['peers'] = peers
        if p99 and mine > max(p99 * 3, 100):
            rep.add(HARD, 'hero_peer_outlier',
                    '英雄最高等级是同级 P99 的 %.1f 倍' % (mine / float(p99)),
                    '同级(±%d 级) %d 人，最高英雄等级 P50=%d / P90=%d / P99=%d，本人 %d' % (
                        TH['peer_band'], peers['peerN'], peers.get('maxLvP50', 0),
                        peers.get('maxLvP90', 0), p99, mine),
                    {'mine': mine, 'peers': peers})

    def _check_gm_reward_db(self, rep, prof):
        n = prof.get('gmRewardN', 0)
        if n > TH['gm_reward_max']:
            rep.add(HARD, 'gm_reward_db',
                    'itemLog 里有 %d 条 reason=28（GM_REWARD）' % n,
                    'GM_REWARD 只由 GM 指令产生；单笔最大 %s' % prof.get('gmRewardMax'),
                    {'count': n, 'max': prof.get('gmRewardMax')})

    def _check_gold(self, rep, prof):
        gold = prof.get('gold', 0)
        if not gold and not prof.get('diamond'):
            return
        base = self.r.mongo(GOLD_JS) or {}
        rep.profile['gold_base'] = base
        p90 = base.get('goldP90', 0)
        if gold and p90 and gold > p90 * TH['gold_outlier_x']:
            rep.add(SOFT, 'gold_outlier',
                    '金币 %d 是活跃号 P90(%d) 的 %.1f 倍' % (gold, p90, gold / float(p90)),
                    '注意：GM 只发英雄时金币可能完全正常（本次事故就是），此项只作辅助',
                    {'gold': gold, 'p90': p90})
        # 钻石只报 INFO：真钻石靠 GM_REWARD(reason=28) 注入，本项只用来一眼看出量级。
        dia = prof.get('diamond', 0)
        d99 = base.get('diaP99', 0)
        if dia and d99 and dia > d99:
            rep.add(INFO, 'diamond_outlier',
                    '钻石 %d 高于活跃号 P99(%d)' % (dia, d99),
                    '只作线索、不参与裁决：请先查 reason=28(GM_REWARD)、reason=16/52(邮件/直购)。'
                    '全服活跃号 P50=%s / P90=%s / P99=%s / max=%s' % (
                        base.get('diaP50'), base.get('diaP90'), d99, base.get('diaMax')),
                    {'diamond': dia, 'base': base})

    def _check_ranks(self, rep, uid):
        hits = []
        for key, members in (self.r.rank_members(uid) or {}).items():
            hits.append({'key': key, 'members': members})
        for key in self.r.scan('%s*:RANKING_DATA' % self.r.key_prefix):
            for field, val in self.r.hgetall(key).items():
                if str(uid) in (val or ''):
                    hits.append({'key': key, 'field': field})
        rep.profile['rank_hits'] = hits
        if hits:
            rep.add(INFO, 'rank_presence',
                    '仍在 %d 个榜单里' % len(hits),
                    '处置时必须同步清理，否则删数据后排行榜会 NPE（getUser null）',
                    {'hits': hits})

    def _check_gm_requests(self, rep, uid):
        log = '/data/srvlog/gameserver.log'
        _, out, _ = self.r.sh(
            'grep -ac "type GM_REQUEST" %s 2>/dev/null; '
            'grep -ac "uid %d type GM_REQUEST" %s 2>/dev/null; '
            'grep -ac "In a formal setting" %s 2>/dev/null' % (log, uid, log, log))
        nums = [int(x) for x in out.split() if x.strip().isdigit()]
        total_req = nums[0] if len(nums) > 0 else 0
        mine = nums[1] if len(nums) > 1 else 0
        rejected = nums[2] if len(nums) > 2 else 0
        rep.profile['gm'] = {'log_total': total_req, 'mine': mine, 'rejected_all': rejected}
        if mine > TH['gm_request_max']:
            rep.add(SOFT, 'gm_request_burst',
                    '当前日志里有 %d 条该 uid 的 GM_REQUEST' % mine,
                    '新手引导约 3~12 条；更多说明客户端在主动发包（日志只留 2~3 天，属活体证据）',
                    {'mine': mine})
        if rejected:
            # 有拒绝记录 = 有人正在打 GM 通道，但无法归属到具体 uid（日志换行）
            rep.add(INFO, 'gm_rejected_seen',
                    '服务端有 %d 次 GM 拒绝（In a formal setting）' % rejected,
                    '说明改包客户端在外流通；按 `grep -B3` 的上下文可定位 uid',
                    {'rejected': rejected})

    def _check_bi_log(self, rep, uid):
        """BI 文件流水：Mongo itemLog 断档时唯一可信账本。"""
        base = '/home/java/gameserver/assets/log/jl_item'
        days = self.r.list_files(base, limit=200)
        days = sorted([d for d in days if re.match(r'^\d{4}-\d{2}-\d{2}$', d)])[-TH['bi_days']:]
        if not days:
            rep.errors.append('BI 流水目录为空或不可读：%s' % base)
            return
        # 一次性 grep（一天一个文件，最多 30 天）
        cmd = '; '.join(
            'grep -h "%d" %s/%s/item0.log 2>/dev/null' % (uid, base, d) for d in days)
        _, out, _ = self.r.sh(cmd, timeout=240)
        lines = [l for l in out.splitlines() if l.strip()]
        gm_reward = [l for l in lines if 'reason=28' in l]
        add_hero = [l for l in lines if 'addHero' in l]
        add_item = [l for l in lines if 'addItem' in l]
        rep.profile['bi'] = {
            'days': [days[0], days[-1]], 'lines': len(lines),
            'gmReward': len(gm_reward), 'addHero': len(add_hero), 'addItem': len(add_item),
        }
        if gm_reward:
            tids = re.findall(r'herotemid=(\d+)', '\n'.join(gm_reward))
            rep.add(HARD, 'bi_gm_reward',
                    'BI 流水里有 %d 条 reason=28（GM_REWARD）' % len(gm_reward),
                    '时间窗 %s ~ %s；其中 addHero %d 条、addItem %d 条（只发英雄不发卡 = 直接建实体）' % (
                        gm_reward[0][:23], gm_reward[-1][:23], len(add_hero), len(add_item)),
                    {'tids': tids[:60], 'sample': gm_reward[:3]})

    def _check_ban(self, rep, uid):
        banned = self.r.redis('HEXISTS', '"%sFORBID_LOGIN:"' % self.r.key_prefix,
                              str(uid)).strip()
        rep.profile['banned'] = banned.endswith('1')

    # ------------------------------------------------------------ 全服
    def hunt(self, limit=None):
        """全服扫「英雄异常」候选，返回 [{uid, nick, level, heroN, maxLv, maxStar, n100}]。"""
        js = """
var out=[], total=0;
db.user.find({}).forEach(function(u){
  total++;
  var pm=u.playerManager||{}, hm=(u.heroManager&&u.heroManager.heroMap)||{};
  var mx=0, ms=0, n100=0, n=0;
  for(var k in hm){var h=hm[k]||{}; var l=Number(h.level||0), s=Number(h.star||0);
    n++; if(l>mx)mx=l; if(s>ms)ms=s; if(l>=100)n100++;}
  if(n100>0 || mx>=%(th)d){
    out.push({uid:u._id, nick:pm.nickName||"", level:Number(pm.level||0),
              heroN:n, maxLv:mx, maxStar:ms, n100:n100,
              force:Number(pm.maxForce||0)});
  }
});
out.sort(function(a,b){return b.maxLv-a.maxLv;});
return {total:total, suspects:out};
""" % {'th': TH['hero_level_hard']}
        res = self.r.mongo(js) or {}
        rows = res.get('suspects') or []
        return rows[:limit] if limit else rows


def fmt_report(rep, remote=None):
    """终端可读输出。"""
    L = []
    p = rep.profile or {}
    L.append('=' * 72)
    L.append('uid %s  %s  Lv%s  VIP%s  战力%s' % (
        rep.uid, p.get('nick', '-'), p.get('level', '-'), p.get('vip', '-'), p.get('force', '-')))
    L.append('英雄 %s 个 / 最高 %s 级 / 最高 %s 星 / heroForceSort %s 条' % (
        p.get('heroN', '-'), p.get('heroMaxLv', '-'), p.get('heroMaxStar', '-'),
        p.get('heroForceSortN', '-')))
    if p.get('exists'):
        names, src = currency.load_names(remote=remote)
        L.append('货币: %s   [id 名取自配置表:%s]' % (currency.describe(p, names), src))
    L.append('日志: itemLog %s / heroLog %s / fightLog %s   GM_REWARD %s 条' % (
        p.get('itemLogN', '-'), p.get('heroLogN', '-'), p.get('fightLogN', '-'),
        p.get('gmRewardN', '-')))
    if p.get('bi'):
        b = p['bi']
        L.append('BI 流水 %s~%s: %d 行（reason=28: %d / addHero: %d / addItem: %d）' % (
            b['days'][0], b['days'][1], b['lines'], b['gmReward'], b['addHero'], b['addItem']))
    if p.get('banned'):
        L.append('封禁状态: 已在 FORBID_LOGIN 名单')
    L.append('-' * 72)
    icon = {HARD: '🔴', SOFT: '🟡', INFO: 'ℹ️ '}
    for f in rep.findings:
        L.append('%s [%s] %s' % (icon.get(f.level, '·'), f.code, f.title))
        if f.detail:
            L.append('     %s' % f.detail)
    if not rep.findings:
        L.append('（无命中判据）')
    L.append('-' * 72)
    res = rep.residue
    if res['heroes_to_delete'] or (res['rank_entries'] and rep.verdict != 'CLEAN'):
        L.append('待处置: 英雄 %d 个（≥%d 级）/ 榜单条目 %d 条 → '
                 '`python3 scripts/cheatctl.py purge --uid %d`'
                 % (res['heroes_to_delete'], TH['hero_level_floor'],
                    res['rank_entries'], rep.uid))
    elif rep.verdict != 'CLEAN':
        L.append('待处置: 无残留（历史证据仍在 BI/日志里，属正常）')
    L.append('裁决: %s' % rep.verdict)
    if rep.errors:
        L.append('警告: %s' % '; '.join(rep.errors))
    L.append('=' * 72)
    return '\n'.join(L)


def now_tag():
    return datetime.datetime.now().strftime('%Y%m%d-%H%M%S')


def ts2str(ts):
    if not ts:
        return '-'
    return time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(ts / 1000.0 if ts > 1e12 else ts))
