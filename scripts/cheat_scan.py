#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""作弊快速排查（cheat triage / hunt）—— 判「这个号是不是挂」。

分层判定，先硬信号后软信号，最后给结论。**只读**，不封号、不改数据。
判据来源与误判清单 → docs/cheat_detection_skill.md
封禁处置动作 → docs/gm_abuse_incident_playbook.md

用法:
  python3 scripts/cheat_scan.py --uid 10000017          # 单号裁决（~30s）
  python3 scripts/cheat_scan.py --uid 10000017 --json   # 机器可读
  python3 scripts/cheat_scan.py --uid 10000017 --full   # 追加 IP / 同伙 / 收支对账
  python3 scripts/cheat_scan.py --hunt                  # 全服扫可疑号（~90s）
  python3 scripts/cheat_scan.py --ban-list              # 看当前封禁名单

依赖: 本机 ssh 已配置 Host gs 别名；远端有 mongo / redis-cli。
      本地 read MainLevelConfig.xlsx 需要 openpyxl。
"""
import argparse
import json
import os
import shlex
import subprocess
import sys
from datetime import datetime, timezone

# ----------------------------------------------------------------------------
# 配置
# ----------------------------------------------------------------------------
SSH_HOST = os.environ.get('GS_SSH_HOST', 'gs')
GAME_DB = os.environ.get('GS_GAME_DB', 'm5_x1_game_10001')
LOGIN_DB = os.environ.get('GS_LOGIN_DB', 'x1_cn_test_login')
GAME_LOG = os.environ.get('GS_GAME_LOG', '/data/srvlog/gameserver.log')
LOGIN_LOG_GLOB = os.environ.get(
    'GS_LOGIN_LOG_GLOB',
    '/home/java/loginserver/apache-tomcat-8.5.95/logs/localhost_access_log.*.txt')
REDIS_KEY_PREFIX = os.environ.get('GS_REDIS_PREFIX', '10001:')

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
MAIN_LEVEL_XLSX = os.path.join(
    PROJECT_ROOT, 'data_execl', 'base_data', 'MainLevelConfig.xlsx')

SSH_TIMEOUT = 180

# 判据阈值（改这里就是改标准，文档与本文件必须同步）
TH = {
    'gm_reward_huge': 10 ** 6,        # GM_REWARD 单笔 ≥ 100 万 → 硬信号
    'grant_absurd': 10 ** 8,          # 任意单笔发放 ≥ 1 亿 → 硬信号
    'gm_normal_max': 12,              # GM_REQUEST 次数上限（新手引导约 3~12 条）
    'progress_delta': 1,              # 正常 delta ∈ [0,1]，超范围即不一致
    'gold_outlier_x': 3.0,            # 金币 > 活跃号 P90 × 3 → 软信号
    'burst_gap_sec': 1.0,             # 相邻战斗 < 1s → 软信号（脚本特征）
}

VERDICT_ORDER = {'CLEAN': 0, 'SUSPECT': 1, 'CHEAT': 2}


# ----------------------------------------------------------------------------
# SSH / Mongo 基础
# ----------------------------------------------------------------------------
def ssh_run(cmd, timeout=SSH_TIMEOUT):
    """在 gs 上跑一条 shell 命令，返回 stdout（失败返回空串并写 stderr）。"""
    try:
        p = subprocess.run(
            ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', SSH_HOST, cmd],
            capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        sys.stderr.write('[warn] ssh timeout: %s\n' % cmd[:80])
        return ''
    except Exception as e:                                    # noqa: BLE001
        sys.stderr.write('[warn] ssh error: %s\n' % e)
        return ''
    if p.returncode != 0 and p.stderr.strip():
        sys.stderr.write('[warn] ssh rc=%d: %s\n' % (p.returncode, p.stderr.strip()[:200]))
    return p.stdout


def mongo_json(js, db=GAME_DB, timeout=SSH_TIMEOUT):
    """把一段 mongo JS 送到账服务器执行，函数体需 return 一个可 JSON 化的值。

    走「stdin 写临时文件 → mongo 读文件」避开所有 shell / JSON 转义地狱。
    """
    wrapped = ('var __out=(function(){\n%s\n})();\n'
               'print(JSON.stringify(__out));\n') % js
    cmd = 'cat > /tmp/_dsh_cheat_scan.js && mongo --quiet %s /tmp/_dsh_cheat_scan.js' % db
    try:
        p = subprocess.run(
            ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', SSH_HOST, cmd],
            input=wrapped, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        sys.stderr.write('[warn] mongo timeout (%s)\n' % db)
        return None
    out = (p.stdout or '').strip().splitlines()
    for line in reversed(out):
        line = line.strip()
        if line.startswith('{') or line.startswith('['):
            try:
                return json.loads(line)
            except ValueError:
                continue
    if p.returncode != 0:
        sys.stderr.write('[warn] mongo rc=%d: %s\n' % (p.returncode, (p.stderr or '')[:300]))
    return None


# ----------------------------------------------------------------------------
# 通关表 Id → 逻辑关序 Name
# ----------------------------------------------------------------------------
_cached_id2name = None


def load_id2name():
    """MainLevelConfig.xlsx 的 Id → Name（Name 是 1..2550 的逻辑关序，= 行号）。

    fightLog.fightLevel 存的是 **Name**，mainLevelManager.fightId 存的是 **Id**，
    两者必须换算后才能比较。换算表缺失时返回 None，调用方跳过该项并注明。
    """
    global _cached_id2name
    if _cached_id2name is not None:
        return _cached_id2name or None
    try:
        import openpyxl
    except ImportError:
        sys.stderr.write('[warn] 缺 openpyxl，跳过主线进度换算\n')
        _cached_id2name = {}
        return None
    if not os.path.exists(MAIN_LEVEL_XLSX):
        sys.stderr.write('[warn] 缺 %s，跳过主线进度换算\n' % MAIN_LEVEL_XLSX)
        _cached_id2name = {}
        return None
    wb = openpyxl.load_workbook(MAIN_LEVEL_XLSX, read_only=True)
    ws = wb['MainLevelConfig']
    mapping = {}
    for row in ws.iter_rows(min_row=8, values_only=True):
        # 列序: A=None, B=Id, C=Difficulty, D=Name ...
        if row[1] is None or row[3] is None:
            continue
        try:
            mapping[int(row[1])] = int(row[3])
        except (TypeError, ValueError):
            continue
    wb.close()
    _cached_id2name = mapping
    return mapping or None


# mongo JS 里取「主线」fightType 的通用前缀（该字段在库中被存成 GBK 错编码的 UTF-8，
# 首字符恒为 U+6D93「涓」，用 charCode 定位最稳）。
JS_MAIN_TYPE = (
    'var __types=db.fightLog.distinct("fightType"),__MAIN="";\n'
    'for(var i=0;i<__types.length;i++){'
    'var t=__types[i];if(t&&t.length===3&&t.charCodeAt(0)===0x6d93){__MAIN=t;break;}}\n')


# ----------------------------------------------------------------------------
# 采集：基础画像
# ----------------------------------------------------------------------------
def collect_basic(uid):
    js = """
var U=%d;
var u=db.user.findOne({_id:U});
if(!u){ return {exists:false, uid:U}; }
var pm=u.playerManager||{}, mlm=u.mainLevelManager||{};
var im=(u.itemManager&&u.itemManager.itemMap)||{};
var hm=(u.heroManager&&u.heroManager.heroMap)||{};
var stars=[],hlv=[];
Object.keys(hm).forEach(function(k){
  var h=hm[k]||{}; if(h.star!=null) stars.push(h.star); if(h.level!=null) hlv.push(h.level);
});
var am=u.arenaManager||{};
return {
  exists:true, uid:U,
  nick: pm.nickName||"", openId: pm.openId||"",
  level: pm.level||0, force: Number(pm.maxForce||0),
  createTime: Number(pm.createTime||0),
  loginTime: Number(pm.loginTime||0), offLineTime: Number(pm.offLineTime||0),
  fightId: Number(mlm.fightId||0), fightState: Number(mlm.state||0),
  gold: Number((im["14"]||{}).itemNum||0),
  diamond: Number((im["3"]||{}).itemNum||0),
  heroCount: Object.keys(hm).length,
  heroMaxStar: stars.length?Math.max.apply(null,stars):0,
  heroMaxLevel: hlv.length?Math.max.apply(null,hlv):0,
  heroLevelSum: hlv.reduce(function(a,b){return a+b;},0),
  arenaSeason: Number(am.season||0), arenaTopRank: Number(am.topMaxRank||0),
  itemLogCount: db.itemLog.count({uid:U}),
  heroLogCount: db.heroLog.count({uid:U}),
  fightLogCount: db.fightLog.count({uid:U}),
  storeLogCount: db.storeLog.count({uid:U})
};""" % uid
    return mongo_json(js) or {'exists': False, 'uid': uid}


def collect_hard(uid):
    """硬信号：GM 指令 / GM_REWARD / 单笔巨额。"""
    js = """
var U=%d;
var agg=db.itemLog.aggregate([
  {$match:{uid:U}},
  {$group:{_id:null,
     maxGrant:{$max:"$itemNum"},
     gmRewardN:{$sum:{$cond:[{$eq:["$reason",28]},1,0]}},
     gmRewardMax:{$max:{$cond:[{$eq:["$reason",28]},"$itemNum",0]}}}}
]).toArray();
var top=db.itemLog.find({uid:U}).sort({itemNum:-1}).limit(5).toArray();
return {
  maxGrant: agg.length?Number(agg[0].maxGrant||0):0,
  gmRewardN: agg.length?Number(agg[0].gmRewardN||0):0,
  gmRewardMax: agg.length?Number(agg[0].gmRewardMax||0):0,
  topGrants: top.map(function(d){
    return {itemId:d.itemId, num:Number(d.itemNum), reason:d.reason,
            time:Number(d.time||0)};
  })
};""" % uid
    return mongo_json(js) or {}


def collect_progress(uid):
    """主线进度自洽：fightLog 最高关 vs fightId 换算出的 Name。"""
    js = JS_MAIN_TYPE + """
var U=%d;
var rows=db.fightLog.find({uid:U,fightType:__MAIN}).toArray();
var maxLvl=0, winLevels={}, n=rows.length, fails=0;
rows.forEach(function(r){
  var l=Number(r.fightLevel||0);
  if(l>maxLvl) maxLvl=l;
  // 失败 = U+6FB6「澶」（"澶辫触" 的首字，库中 GBK 错编码后的 UTF-8）
  if(String(r.fightResult).charCodeAt(0)===0x6fb6) fails++;
  else winLevels[l]=1;
});
var winKeys=Object.keys(winLevels).map(Number).sort(function(a,b){return a-b;});
// 只查「已通关的最高关」以下的缺口：最高关可能只是刚打输，不算跳关
var maxClear = winKeys.length ? winKeys[winKeys.length-1] : 0;
var gaps=[];
for(var i=1;i<=maxClear;i++){ if(!winLevels[i]) gaps.push(i); }
return {mainType:__MAIN||null, entries:n, fails:fails, maxLevel:maxLvl,
        maxClear:maxClear, clears:winKeys.length,
        gaps:gaps.slice(0,20), gapCount:gaps.length};""" % uid
    return mongo_json(js) or {}


def collect_pace(uid):
    """节奏：相邻战斗最小间隔、竞技场场次与挑战券消耗。"""
    js = JS_MAIN_TYPE + """
var U=%d;
var types=db.fightLog.distinct("fightType");
var ARENA="";
for(var i=0;i<types.length;i++){var t=types[i];
  if(t&&t.charCodeAt(0)===0x7ed4){ARENA=t;break;}}
function pace(type){
  var a=db.fightLog.find({uid:U,fightType:type}).sort({addTime:1}).toArray();
  if(a.length<2) return {n:a.length,minGap:null,medGap:null,fast:0};
  var gaps=[];
  for(var i=1;i<a.length;i++){
    var g=(Number(a[i].addTime)-Number(a[i-1].addTime))/1000;
    if(g>=0&&g<3600) gaps.push(g);
  }
  if(!gaps.length) return {n:a.length,minGap:null,medGap:null,fast:0};
  gaps.sort(function(x,y){return x-y;});
  return {n:a.length, minGap:gaps[0], medGap:gaps[Math.floor(gaps.length/2)],
          fast:gaps.filter(function(g){return g<1;}).length};
}
var ticketUse=db.itemLog.count({uid:U,reason:1022});
var arenaPace=pace(ARENA);
return {mainPace:pace(__MAIN), arenaPace:arenaPace,
        arenaType:ARENA||null, ticketUse:ticketUse};""" % uid
    return mongo_json(js) or {}


def collect_reconcile(uid):
    """核心货币对账：itemLog 末条的 itemTotalNum 应等于当前库存。

    🔴 只查核心货币（14 金币 / 3 钻石 / 16 / 4）。其余物品的 itemTotalNum
    语义不同（周期道具会重置、券类恒写 0/1），全量对账会稳定报假差异。
    实测 Sakuya 这 4 项全部闭合；猫神/希维琳达同样。
    """
    js = """
var U=%d;
var CORE=[14,3,16,4];
var u=db.user.findOne({_id:U});
if(!u) return {};
var im=(u.itemManager&&u.itemManager.itemMap)||{};
var out={}, mismatch=0;
CORE.forEach(function(id){
  var arr=db.itemLog.find({uid:U,itemId:id}).toArray();
  if(!arr.length){ out[id]={logged:null,cur:Number((im[String(id)]||{}).itemNum||0),ok:true}; return; }
  arr.sort(function(a,b){ return Number(a.time)-Number(b.time); });   // time 是字符串！
  var logged=Number(arr[arr.length-1].itemTotalNum);
  var cur=Number((im[String(id)]||{}).itemNum||0);
  var ok=(logged===cur);
  if(!ok) mismatch++;
  out[id]={logged:logged,cur:cur,ok:ok};
});
return {items:out, mismatch:mismatch, checked:CORE.length};""" % uid
    return mongo_json(js) or {}


def collect_peers(uid):
    """全服分位对照：金币分位、战力排名、单笔发放排名。

    ⚠️ 金币基线必须用**活跃号**（itemLog ≥ 500 条）：211 个 user 文档里有大量
    空壳号，混进去会把 P50 拉到几十万，反而让真异常看起来"正常"。
    """
    js = """
var U=%d;
var golds=[], activeGolds=[], forces=[], maxGrants=[];
db.user.find({},{_id:1,"playerManager.maxForce":1,"itemManager.itemMap.14":1})
  .forEach(function(u){
    var g=Number((u.itemManager&&u.itemManager.itemMap&&u.itemManager.itemMap["14"]||{}).itemNum||0);
    golds.push(g);
    if(db.itemLog.count({uid:u._id})>=500) activeGolds.push(g);
    forces.push([u._id, Number((u.playerManager||{}).maxForce||0)]);
  });
db.itemLog.aggregate([{$group:{_id:"$uid",mx:{$max:"$itemNum"}}}]).forEach(function(d){
  maxGrants.push([d._id, Number(d.mx||0)]);
});
function asc(a,b){return a-b;}
golds.sort(asc);
activeGolds.sort(asc);
forces.sort(function(a,b){return b[1]-a[1];});
maxGrants.sort(function(a,b){return b[1]-a[1];});
function pct(arr,p){ return arr.length?arr[Math.floor(arr.length*p)]:0; }
function rankOf(arr,uid){ for(var i=0;i<arr.length;i++){ if(arr[i][0]===uid) return i+1; } return 0; }
var uidGolds=0;
for(var i=0;i<maxGrants.length;i++){ if(maxGrants[i][0]===U){uidGolds=maxGrants[i][1];break;} }
return {
  players: golds.length,
  activePlayers: activeGolds.length,
  goldMedian: pct(activeGolds,0.5),
  goldP90: pct(activeGolds,0.9),
  goldAllMedian: pct(golds,0.5),
  forceRank: rankOf(forces,U), forceTotal: forces.length,
  grantRank: rankOf(maxGrants,U), grantTotal: maxGrants.length,
  myMaxGrant: uidGolds,
  topForce: forces.slice(0,5).map(function(x){return {uid:x[0], force:x[1]};})
};""" % uid
    return mongo_json(js) or {}


def collect_ban_state(uid):
    cmd = 'redis-cli -n 0 HEXISTS "%sFORBID_LOGIN:" %d' % (REDIS_KEY_PREFIX, uid)
    out = ssh_run(cmd, timeout=60).strip()
    return out.endswith('1')


def collect_ban_list():
    cmd = 'redis-cli -n 0 HKEYS "%sFORBID_LOGIN:"' % REDIS_KEY_PREFIX
    return [x.strip() for x in ssh_run(cmd, timeout=60).splitlines() if x.strip()]


def collect_ips(uid):
    """登录服访问日志 → 该号登录过的 IP 及次数（游戏库 playerManager.ip 恒为空）。"""
    js = """
var U=%d;
var u=db.user.findOne({_id:U});
if(!u) return {openId:null};
return {openId:u.playerManager.openId||"", gameOpenId:u.playerManager.openId||""};""" % uid
    info = mongo_json(js) or {}
    login = mongo_json("""
var U=%d;
var d=db.getSiblingDB("%s").user_info.findOne({_id:U});
return {loginOpenId: d? d.openId : null};""" % (uid, LOGIN_DB)) or {}
    open_ids = [x for x in (info.get('openId'), login.get('loginOpenId')) if x]
    ips = {}
    for oid in open_ids:
        cmd = ('grep -hF %s %s 2>/dev/null | grep -oE "^[0-9.]+" | sort | uniq -c '
               '| sort -rn | head -20') % (shlex.quote('openId=' + oid), LOGIN_LOG_GLOB)
        for line in ssh_run(cmd, timeout=120).splitlines():
            parts = line.split()
            if len(parts) == 2:
                ips[parts[1]] = ips.get(parts[1], 0) + int(parts[0])
    return {'openIds': open_ids, 'ips': ips}


def collect_gm_requests_exact(uid):
    """精确数该 uid 的 GM_REQUEST 行数。

    ⚠️ 两层 grep 顺序不能反：先按 "type GM_REQUEST" 过滤（日志里每行都带
    `request=<uid> commond =X` 和 `doWork->uid=N,mType=X`，直接 grep uid 会
    把普通协议行也算进来），再在这个子集里数 uid。
    """
    cmd = 'test -r %s && grep -F "type GM_REQUEST" %s | grep -cF %s || echo 0' % (
        GAME_LOG, GAME_LOG, shlex.quote('uid %d' % uid))
    out = ssh_run(cmd, timeout=180).strip()
    try:
        return int(out.splitlines()[-1])
    except (ValueError, IndexError):
        return 0


# ----------------------------------------------------------------------------
# 判定
# ----------------------------------------------------------------------------
def fmt_ts(ms):
    if not ms:
        return '-'
    return datetime.fromtimestamp(ms / 1000.0, tz=timezone.utc).strftime('%Y-%m-%d %H:%M')


def fmt_money(v):
    if v >= 10 ** 8:
        return '%.2f亿' % (v / 10 ** 8)
    if v >= 10 ** 4:
        return '%.1f万' % (v / 10 ** 4)
    return '%d' % v


def assess(basic, hard, prog, pace, peers, gm_req, banned, id2name,
           reconcile=None):
    """返回 (verdict, findings)。findings 每项: (level, 标题, 证据)。"""
    f = []
    verdict = 'CLEAN'

    def hit(level, title, evidence):
        nonlocal verdict
        f.append((level, title, evidence))
        if level == 'CHEAT':
            verdict = 'CHEAT'
        elif level == 'SUSPECT' and VERDICT_ORDER[verdict] < VERDICT_ORDER['SUSPECT']:
            verdict = 'SUSPECT'

    # ---- 硬信号 1: GM_REQUEST ----
    if gm_req > TH['gm_normal_max']:
        hit('CHEAT', 'GM 指令滥用',
            'GM_REQUEST %d 次（正常玩家 ≤%d，新手引导约 3~12 条）'
            % (gm_req, TH['gm_normal_max']))
    elif gm_req:
        f.append(('INFO', 'GM 指令', '%d 次（新手引导区间，正常）' % gm_req))
    else:
        f.append(('INFO', 'GM 指令', '0 次（日志窗口内）'))

    # ---- 硬信号 2: GM_REWARD ----
    gm_n = hard.get('gmRewardN', 0)
    gm_max = hard.get('gmRewardMax', 0)
    if gm_n and gm_max >= TH['gm_reward_huge']:
        hit('CHEAT', 'GM_REWARD 巨额发放',
            'reason=28 共 %d 笔，单笔最大 %s —— GM 刷资源的确证'
            % (gm_n, fmt_money(gm_max)))
    elif gm_n:
        f.append(('INFO', 'GM_REWARD',
                  '%d 笔，单笔最大 %s（少量，可能是测试补偿）' % (gm_n, fmt_money(gm_max))))
    else:
        f.append(('OK', 'GM_REWARD', '0 笔（全生命周期 itemLog 无 GM 刷资源痕迹）'))

    # ---- 硬信号 3: 任意单笔巨额（GM_REWARD 已判过就不再重复计）----
    mx = hard.get('maxGrant', 0)
    if mx >= TH['grant_absurd']:
        if gm_max >= TH['gm_reward_huge']:
            f.append(('INFO', '单笔发放',
                      '最大 %s，就是上面那笔 GM_REWARD（同一回事，不重复计）'
                      % fmt_money(mx)))
        else:
            hit('CHEAT', '单笔发放越界',
                'itemLog 单笔最大 %s，超阈值 %s 且非 GM_REWARD，'
                '疑似业务接口无频次/上限校验'
                % (fmt_money(mx), fmt_money(TH['grant_absurd'])))
    else:
        f.append(('OK', '单笔发放', '最大 %s（阈值 %s）'
                  % (fmt_money(mx), fmt_money(TH['grant_absurd']))))

    # ---- 硬信号 4: 主线进度自洽 ----
    # delta = fightLog最高关 - (fightId换算的关序 - 1)
    #   正常玩家 delta ∈ {0, +1}：fightId 指向「当前要打的关」，fightLog 记的是
    #   「最近打过的关」，所以最多比已通关数多 1。
    #   delta < -1  → fightId 冲到 fightLog 前面 = **跳关 / 直接改库**（作弊特征）
    #   delta > +1  → 反而 fightLog 更靠前 = **回档 / 重置 / 删号重建**（不是作弊）
    fid = basic.get('fightId', 0)
    maxlvl = prog.get('maxLevel', 0)
    if id2name and fid in id2name:
        name = id2name[fid]
        delta = maxlvl - (name - 1)
        if delta < -TH['progress_delta']:
            hit('CHEAT', '主线进度不一致（跳关）',
                'fightId=%d 换算关 %d，但 fightLog 最高只打到 %d（差 %+d）'
                ' —— 进度跑到实际战斗记录前面，典型的直接改库/跳关'
                % (fid, name, maxlvl, delta))
        elif delta > TH['progress_delta']:
            hit('SUSPECT', '主线进度回退',
                'fightLog 最高 %d 比当前 fightId（关 %d）更靠前（差 %+d）'
                ' —— 多为回档/重置/删号重建，**不是跳关**；需结合建号时间确认'
                % (maxlvl, name, delta))
        else:
            f.append(('OK', '主线进度',
                      'fightId=%d → 关 %d，fightLog 最高 %d（差 %+d，自洽）'
                      % (fid, name, maxlvl, delta)))
    else:
        f.append(('SKIP', '主线进度', 'fightId=%s 不在配置表内或换算表缺失，跳过' % fid))

    if prog.get('gapCount'):
        hit('SUSPECT', '主线关卡有缺口',
            '1..%d 之间有 %d 关没有胜利记录（跳关特征）'
            % (prog.get('maxClear', 0), prog['gapCount']))
    elif prog.get('maxClear'):
        f.append(('OK', '主线连续性',
                  '1..%d 连续无缺口，共 %d 次尝试 / %d 次失败'
                  % (prog['maxClear'], prog.get('entries', 0), prog.get('fails', 0))))

    # ---- 软信号: 资源离群（基线用活跃号 P90，不是全服中位数）----
    gold = basic.get('gold', 0)
    base = peers.get('goldP90', 0) or peers.get('goldMedian', 0)
    if base and gold > base * TH['gold_outlier_x']:
        hit('SUSPECT', '金币离群',
            '金币 %s，活跃号 P90 为 %s（%.1f 倍，阈值 %.1f 倍）—— 核对收支是否自洽'
            % (fmt_money(gold), fmt_money(base),
               gold / float(base), TH['gold_outlier_x']))
    elif base:
        f.append(('OK', '金币',
                  '%s（活跃号 P50 %s / P90 %s）'
                  % (fmt_money(gold), fmt_money(peers.get('goldMedian', 0)),
                     fmt_money(base))))

    # ---- 核心货币对账（说明"这个数字能不能被账本解释"）----
    if reconcile and reconcile.get('checked'):
        mm = reconcile.get('mismatch', 0)
        if mm:
            detail = '; '.join(
                'item%s 日志%s/库存%s' % (k, v.get('logged'), v.get('cur'))
                for k, v in (reconcile.get('items') or {}).items() if not v.get('ok'))
            hit('SUSPECT', '核心货币对账不平',
                '%d/%d 项不符（%s）—— 疑似凭空增发'
                % (mm, reconcile['checked'], detail))
        else:
            f.append(('OK', '核心货币对账',
                      'item14/3/16/4 全部闭合（日志末值 = 当前库存）'))

    # ---- 软信号: 战力离群 ----
    fr = peers.get('forceRank', 0)
    if fr and fr <= 3 and peers.get('forceTotal', 0) > 20:
        f.append(('INFO', '战力排名',
                  '全服第 %d / %d（%s）—— 头部玩家需重点核对成长曲线'
                  % (fr, peers['forceTotal'], fmt_money(basic.get('force', 0)))))
    else:
        f.append(('OK', '战力排名',
                  '全服第 %d / %d' % (fr, peers.get('forceTotal', 0))))

    # ---- 软信号: 战斗节奏 ----
    ap = pace.get('arenaPace') or {}
    mp = pace.get('mainPace') or {}
    if ap.get('fast'):
        hit('SUSPECT', '竞技场节奏异常',
            '竞技场 %d 场中有 %d 次相邻战斗间隔 <1s（脚本特征）'
            % (ap.get('n', 0), ap['fast']))
    elif ap.get('n'):
        # 场次 vs 挑战券消耗对账：skipFight 秒扫允许高频，但每场必须扣券
        used = pace.get('ticketUse', 0)
        diff = ap['n'] - used
        if used and abs(diff) > used * 0.5:
            hit('SUSPECT', '竞技场场次与挑战券不符',
                '%d 场但只扣了 %d 张券（reason=1022），差 %d'
                % (ap['n'], used, diff))
        else:
            f.append(('OK', '竞技场',
                      '%d 场，消耗挑战券 %d 张，间隔中位 %.1fs（机制内秒扫）'
                      % (ap['n'], used, ap.get('medGap') or 0)))
    if mp.get('medGap') is not None:
        f.append(('INFO', '主线节奏', '相邻战斗间隔中位 %.1fs / 最短 %.1fs'
                  % (mp.get('medGap') or 0, mp.get('minGap') or 0)))

    # ---- 软信号: 英雄养成 ----
    hc = basic.get('heroCount', 0)
    if hc >= 5:
        good = sum(1 for _ in range(0))  # 占位，具体分级在报告里展示
        f.append(('INFO', '英雄养成',
                  '%d 个英雄，最高 %d 星 / %d 级，等级总和 %d'
                  % (hc, basic.get('heroMaxStar', 0),
                     basic.get('heroMaxLevel', 0), basic.get('heroLevelSum', 0))))

    # ---- 状态 ----
    if banned:
        f.append(('INFO', '封禁状态', '已在 FORBID_LOGIN 名单内'))

    return verdict, f


# ----------------------------------------------------------------------------
# 单号报告
# ----------------------------------------------------------------------------
def scan_one(uid, full=False, as_json=False):
    basic = collect_basic(uid)
    if not basic.get('exists'):
        if as_json:
            print(json.dumps({'uid': uid, 'exists': False, 'verdict': 'NO_SUCH_PLAYER'},
                             ensure_ascii=False, indent=2))
        else:
            print('UID %d：游戏库中不存在该玩家（可能已删档，或被删号后未再登录）' % uid)
        return {'uid': uid, 'exists': False, 'verdict': 'NO_SUCH_PLAYER'}

    hard = collect_hard(uid)
    prog = collect_progress(uid)
    pace = collect_pace(uid)
    peers = collect_peers(uid)
    reconcile = collect_reconcile(uid)
    gm_req = collect_gm_requests_exact(uid)
    banned = collect_ban_state(uid)
    id2name = load_id2name()

    verdict, findings = assess(basic, hard, prog, pace, peers, gm_req, banned,
                               id2name, reconcile)

    extra = {}
    if full:
        extra['ips'] = collect_ips(uid)

    if as_json:
        payload = {
            'uid': uid, 'exists': True, 'verdict': verdict,
            'basic': basic, 'hard': hard, 'progress': prog,
            'pace': pace, 'peers': peers, 'reconcile': reconcile,
            'gmRequests': gm_req, 'banned': banned,
            'findings': [{'level': l, 'title': t, 'evidence': e}
                         for l, t, e in findings],
            'extra': extra,
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return payload

    icon = {'CHEAT': '🔴', 'SUSPECT': '⚠️', 'CLEAN': '✅'}[verdict]
    label = {'CHEAT': '确证作弊', 'SUSPECT': '可疑（需人工复核）',
             'CLEAN': '未发现作弊证据'}[verdict]

    print('=' * 74)
    print('  UID %d  %s   %s %s' % (uid, basic.get('nick', ''), icon, label))
    print('=' * 74)
    print('  等级 %d   战力 %s   主线 fightId=%d   建号 %s'
          % (basic.get('level', 0), fmt_money(basic.get('force', 0)),
             basic.get('fightId', 0), fmt_ts(basic.get('createTime'))))
    print('  openId %s   itemLog %d 条 / fightLog %d 条 / heroLog %d 条'
          % (basic.get('openId', '-'), basic.get('itemLogCount', 0),
             basic.get('fightLogCount', 0), basic.get('heroLogCount', 0)))
    print('-' * 74)

    for lv, title, ev in findings:
        mark = {'OK': '✅', 'INFO': '  ', 'SKIP': '  ', 'SUSPECT': '⚠️',
                'CHEAT': '🔴'}.get(lv, '  ')
        print('%s %-10s %s' % (mark, title, ev))

    # 单笔发放明细
    tops = hard.get('topGrants') or []
    if tops:
        print('-' * 74)
        print('  单笔发放 TOP%d：' % len(tops))
        for t in tops:
            print('     item%-8s %-12s reason=%-5s %s'
                  % (t['itemId'], fmt_money(t['num']), t['reason'], fmt_ts(t['time'])))

    if full and extra.get('ips'):
        print('-' * 74)
        print('  登录 IP（按次数）：')
        for ip, c in sorted(extra['ips']['ips'].items(), key=lambda x: -x[1])[:8]:
            print('     %-18s %d 次' % (ip, c))
        print('  （归属地/代理检测：curl -s "http://ip-api.com/json/<IP>?fields='
              'country,regionName,isp,proxy,hosting&lang=zh-CN"）')

    if banned:
        print('-' * 74)
        print('  ⚠️ 该号已在 FORBID_LOGIN 封禁名单内')

    print('-' * 74)
    print('  结论：%s %s' % (icon, label))
    if verdict == 'CHEAT':
        print('  下一步：docs/gm_abuse_incident_playbook.md §3（封禁）/ §5（数据清理）')
    elif verdict == 'SUSPECT':
        print('  下一步：--full 看 IP/同伙；再逐项核对成长曲线（见 skill 文档 §5）')
    print('=' * 74)
    return {'uid': uid, 'exists': True, 'verdict': verdict, 'findings': findings}


# ----------------------------------------------------------------------------
# 全服扫（hunt）
# ----------------------------------------------------------------------------
def hunt():
    """全服扫可疑：GM_REWARD、巨额发放、进度不一致、榜单脏数据。"""
    print('全服扫描中（%s）...\n' % GAME_DB)
    id2name = load_id2name()

    js = JS_MAIN_TYPE + """
var out={players:0, gmReward:[], hugeGrant:[], progress:[], orphans:[]};
var forces=[];
db.user.find({}).forEach(function(u){
  out.players++;
  var uid=u._id, pm=u.playerManager||{}, mlm=u.mainLevelManager||{};
  forces.push([uid, Number(pm.maxForce||0)]);
  if(!mlm.fightId) return;
  var rows=db.fightLog.find({uid:uid,fightType:__MAIN},{fightLevel:1}).toArray();
  var mx=0; rows.forEach(function(r){ var l=Number(r.fightLevel||0); if(l>mx) mx=l; });
  out.progress.push([uid, pm.nickName||"", Number(mlm.fightId), mx]);
});
db.itemLog.aggregate([
  {$match:{reason:28}},
  {$group:{_id:"$uid", n:{$sum:1}, mx:{$max:"$itemNum"}}},
  {$sort:{mx:-1}}
]).forEach(function(d){ out.gmReward.push([d._id, Number(d.n), Number(d.mx)]); });
db.itemLog.aggregate([
  {$group:{_id:"$uid", mx:{$max:"$itemNum"}}},
  {$sort:{mx:-1}}, {$limit:15}
]).forEach(function(d){ out.hugeGrant.push([d._id, Number(d.mx)]); });
return out;"""
    data = mongo_json(js, timeout=300)
    if not data:
        print('扫描失败（mongo 无响应）')
        return []

    suspects = []

    # 1) GM_REWARD
    print('【1】GM_REWARD（reason=28）持有者：')
    for uid, n, mx in data.get('gmReward', []):
        flag = '🔴' if mx >= TH['gm_reward_huge'] else '⚠️'
        print('   %s uid=%-10s %d 笔，单笔最大 %s' % (flag, uid, n, fmt_money(mx)))
        if mx >= TH['gm_reward_huge']:
            suspects.append({'uid': uid, 'reason': 'GM_REWARD %s' % fmt_money(mx)})
    if not data.get('gmReward'):
        print('   （无）')

    # 2) 巨额发放
    print('\n【2】单笔发放 TOP15（阈值 %s）：' % fmt_money(TH['grant_absurd']))
    for uid, mx in data.get('hugeGrant', [])[:15]:
        flag = '🔴' if mx >= TH['grant_absurd'] else '  '
        print('   %s uid=%-10s %s' % (flag, uid, fmt_money(mx)))
    for uid, mx in data.get('hugeGrant', []):
        if mx >= TH['grant_absurd'] and not any(s['uid'] == uid for s in suspects):
            suspects.append({'uid': uid, 'reason': '单笔发放 %s' % fmt_money(mx)})

    # 3) 进度不一致（只把 delta < -1 当跳关；delta > +1 是回档，不算作弊）
    print('\n【3】主线进度不一致（fightId 换算关序 vs fightLog 最高关）：')
    if not id2name:
        print('   （换算表缺失，跳过）')
    else:
        bad = 0
        for uid, nick, fid, mx in data.get('progress', []):
            name = id2name.get(int(fid))
            if name is None:
                continue
            delta = mx - (name - 1)
            if delta < -TH['progress_delta']:
                bad += 1
                print('   🔴 uid=%-10s %-12s fightId=%d→关%d  fightLog最高=%d  '
                      '差 %+d  ← 跳关' % (uid, nick, fid, name, mx, delta))
                suspects.append({'uid': uid, 'reason': '跳关，差 %+d' % delta})
            elif delta > TH['progress_delta']:
                bad += 1
                print('   ⚠️  uid=%-10s %-12s fightId=%d→关%d  fightLog最高=%d  '
                      '差 %+d  ← 回档/重置，非作弊' % (uid, nick, fid, name, mx, delta))
        if not bad:
            print('   （无）')

    # 4) 榜单脏数据（排行榜在 Redis，不在 Mongo）
    print('\n【4】排行榜脏数据（有名次但 user 文档已不存在）：')
    cmd = ('redis-cli -n 0 ZREVRANGE "%scommon_force_rank:" 0 19 2>/dev/null'
           % REDIS_KEY_PREFIX)
    members = [x.strip() for x in ssh_run(cmd, timeout=60).splitlines() if x.strip()]
    dirty = 0
    if members:
        ids = ','.join(members)
        exist_js = 'var ids=[%s],out={};ids.forEach(function(i){' \
                   'out[i]=db.user.count({_id:i});});return out;' % ids
        exist = mongo_json(exist_js) or {}
        for m in members:
            if exist.get(m, 0) == 0:
                dirty += 1
                print('   ⚠️  force_rank 第 %d 名 uid=%s 但 user 文档不存在'
                      % (members.index(m) + 1, m))
    if not dirty:
        print('   （无）')

    # 汇总
    print('\n' + '=' * 74)
    uniq = {}
    for s in suspects:
        uniq.setdefault(s['uid'], []).append(s['reason'])
    if uniq:
        print('  可疑账号 %d 个：' % len(uniq))
        for uid, reasons in uniq.items():
            b = mongo_json('var u=db.user.findOne({_id:%d});'
                           'return u?{nick:u.playerManager.nickName||"",'
                           'lv:u.playerManager.level||0,'
                           'force:Number(u.playerManager.maxForce||0)}:null;' % int(uid)) or {}
            print('   uid=%-10s %-14s lv%-4s 战力%-10s  %s'
                  % (uid, b.get('nick', '(已删)'), b.get('lv', '-'),
                     fmt_money(b.get('force', 0)), '; '.join(reasons)))
    else:
        print('   ✅ 未发现可疑账号')
    print('=' * 74)
    return suspects


# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(
        description='作弊快速排查（只读）：单号裁决 / 全服扫可疑 / 查封禁名单')
    ap.add_argument('--uid', type=int, help='要排查的玩家 UID')
    ap.add_argument('--hunt', action='store_true', help='全服扫可疑账号')
    ap.add_argument('--ban-list', action='store_true', help='打印当前封禁名单')
    ap.add_argument('--full', action='store_true', help='追加 IP / 同伙 / 登录轨迹')
    ap.add_argument('--json', action='store_true', help='输出 JSON')
    args = ap.parse_args()

    if args.ban_list:
        lst = collect_ban_list()
        if args.json:
            print(json.dumps(lst, ensure_ascii=False, indent=2))
        else:
            print('FORBID_LOGIN（%s）共 %d 个：' % (REDIS_KEY_PREFIX, len(lst)))
            for u in lst:
                print('   uid=%s' % u)
        return 0

    if args.hunt:
        hunt()
        return 0

    if not args.uid:
        ap.print_help()
        return 2

    r = scan_one(args.uid, full=args.full, as_json=args.json)
    if r.get('verdict') == 'CHEAT':
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
