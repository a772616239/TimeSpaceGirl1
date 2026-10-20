# 作弊快速排查 Skill（判「这个号是不是挂」）

> 更新时间：2026-10-20
> 一句话定位：**拿到一个 UID / 昵称，30 秒内给出「确证作弊 / 可疑 / 干净」三分结论，并附完整证据链。**
>
> **操作入口（2026-10-20 起）**：`.workbuddy/skills/cheat-forensics/SKILL.md`（流程卡）+ `scripts/cheatctl.py`（工具）
> —— `scan` 判号、`hunt` 全服粗筛、`purge` 一键处置（备份→删产物→清榜→封号→校验）。
> 本文降级为**判据原理与逐条复盘**（阈值出处、误判清单、手工命令），工具实现见 `scripts/cheat/`。
> 老脚本 `scripts/cheat_scan.py` 仍可用，但缺 BI 流水与 heroForceSort 两条判据（见 §5 补充）。
>
> 配套：`gm_abuse_incident_playbook.md`（确认后怎么封/怎么清榜）、`cheat_incident_10000224_20261020.md`
> （2026-10-10 GM 通道全开事故）、`server_ops_runbook.md`（生产环境事实）。
>
> 本文的判据全部来自 2026-10-18 / 10-20 的真实排查（Sieg / Mozart / оня / Sakuya / 朗曼梅西 五个号、五种手法），
> **每个阈值都有实测依据，不是拍脑袋**。

---

## 0. 🔴 三条最容易踩的坑（先看完再动手）

这三条会让你的结论**完全反掉**，比不会查更危险：

### 坑 1：`fightId` 不是「通关数」，直接比大小必错

```
fightId 存的是「当前要打的关卡 Id」（如 4122）
fightLog.fightLevel 存的是「逻辑关序 Name」（如 402）
```

这是**两套编号**，必须用 `MainLevelConfig.xlsx` 的 `Id → Name` 换算。
换算表存在 `data_execl/base_data/MainLevelConfig.xlsx`，`Name` 恰好等于行号（1..2550）。

> 上一次（10000153）就是拿 `fightId=15405` 去比 `fightLog` 的 45 关，
> 得出「标称 15405 关实际只打 45 关」——看似铁证，其实是拿 Id 比 Name。
> 15405 换算过来是第 2550 关，那才是真正的异常幅度（仍然异常，但差了两个数量级）。

### 坑 2：GM 指令为 0 / GM_REWARD 为 0 **不等于**没作弊

2026-10-18 抓到三种完全不同的手法：

| 玩家 | 手法 | GM 指令 | GM_REWARD | 破绽在哪 |
|---|---|---|---|---|
| Sieg（10000240） | 发 GM 指令刷资源 | **114 次** | 有 | 指令计数 |
| Mozart（10000013） | 打无频次校验的业务接口 | 3 次（正常引导） | 无 | 1 分钟 35 次领奖、单笔 77.76 万钻石 |
| 10000153 | 直接改库 | **0 次** | 无 | fightId 与 fightLog 对不上 |
| **Sakuya（10000017）** | **无（正常玩家）** | **0 次** | **无** | —— 但资源/场次全服前二，最容易被误判 |

**所以必须三层都查：GM 通道 → 业务接口 → 数据自洽。**

### 坑 3：日志只有最近一次启动之后的

`/data/srvlog/gameserver.log` **没有轮转**（`gameserver.log.1` 不存在），
重启即截断。当前窗口从 **2026-10-10 17:14** 开始。

⇒ **`GM_REQUEST` 计数只能证明「日志窗口内」没发过**。
要证明「全生命周期」，只能靠 **MongoDB 的 `itemLog`**——它是永久账本，且带 `reason` 字段。
这就是为什么下面把 `itemLog.reason=28` 当作最高优先级硬证据。

---

## 1. 快速开始

```bash
cd /Users/wangxufeng/Documents/TimeSpaceGirl1

# 单号裁决（约 30 秒）
python3 scripts/cheat_scan.py --uid 10000017

# 追加 IP / 同伙 / 登录轨迹
python3 scripts/cheat_scan.py --uid 10000017 --full

# 全服扫可疑号（约 90 秒）
python3 scripts/cheat_scan.py --hunt

# 看当前封禁名单
python3 scripts/cheat_scan.py --ban-list

# 机器可读
python3 scripts/cheat_scan.py --uid 10000017 --json
```

退出码：`0` = 干净或可疑，`1` = **确证作弊**（可以直接接到告警/CI 里）。

### 1.1 只拿到昵称怎么办

```bash
# 游戏库里按昵称精确查（昵称不入 user 的独立索引，但 211 个文档全扫很快）
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
db.user.find({\"playerManager.nickName\": \"Sakuya\"},{_id:1,
  \"playerManager.nickName\":1,\"playerManager.level\":1,
  \"playerManager.maxForce\":1}).forEach(function(d){printjson(d);});"'

# 支持正则 / 部分匹配
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
db.user.find({\"playerManager.nickName\": /sakuya/i}).forEach(function(d){
  print(d._id + \" \" + d.playerManager.nickName);});"'
```

⚠️ 中文昵称在 `mongo --eval` 里会被 GBK/UTF-8 双重编码搞坏（见 §7 坑 2），
**用 ASCII 昵称或直接按 UID 查**最省事。

---

## 2. 判据总表（按优先级）

`scripts/cheat_scan.py` 就是这张表的实现，阈值集中在文件顶部 `TH = {...}`，
**改阈值必须同步改这一节**。

### 2.1 硬信号：命中即「确证作弊」

| # | 判据 | 阈值 | 为什么可信 |
|---|---|---|---|
| H1 | `GM_REQUEST` 次数 | `> 12` | 全服正常玩家 3~12 次，全是新手引导 `10#1#0`~`10#3#0` |
| H2 | `itemLog.reason=28` 单笔 | `≥ 100 万` | `reason=28` = `BIReason.GM_REWARD`，只有走 GM 通道才产生；正常玩家该 reason 恒为 0 |
| H3 | 任意单笔发放 | `≥ 1 亿` 且非 H2 | 业务接口无上限校验的典型特征（Mozart 是 77.76 万×35 次，单笔没超阈值，但笔数异常） |
| H4 | 主线 `delta < -1` | `fightLog最高关 < fightId换算关 - 1 - 1` | 进度跑到战斗记录前面 ⇒ 跳关 / 直接改库 |

`reason` 枚举（反编译 `com/ljsd/jieling/globals/BIReason.class` 确认）：

| reason | 常量名 | 含义 |
|---|---|---|
| 11 | `TAKE_MISSION_REWARD` | 任务奖励 |
| **28** | **`GM_REWARD`** | **GM 发放 —— 作弊铁证** |
| 55 | `LUCK_WHEEl_ADVANCE_REWARD` | 轮盘高级奖励 |
| 57 | `HERO_BACK_REWARD` | 英雄回收返还 |
| 1012 | `UP_HERO_LEVEL_CONSUME` | 英雄升级消耗 |
| 1022 | `ARENA_CHALLENGE_CONSUME` | **竞技场挑战券消耗**（用于场次对账） |
| 11301 | `BOX_POOL_RANDOM_REWARD` | 宝箱池随机奖励 |

### 2.2 软信号：需要人工复核

| # | 判据 | 阈值 | 误报来源（务必先排除） |
|---|---|---|---|
| S1 | 金币离群 | `> 活跃号 P90 × 3` | **必须用活跃号基线**：211 个 user 文档里大量空壳号，混进去 P50 会被拉到几十万 |
| S2 | 竞技场节奏 | 相邻战斗 `< 1s` | `skipFight=1` 秒扫本来就 1~3 秒一场，**2 秒是正常的**；只有 <1s 才可疑 |
| S3 | 场次 vs 券不符 | `场次 - 券消耗 > 券 × 50%` | 挑战券 `reason=1022`，每场必扣一张 |
| S4 | 主线有缺口 | 已通关范围内有空洞 | 只查 `1..最高胜利关`；最高关打输了不算缺口 |
| S5 | 进度回退 | `delta > +1` | **这是回档/重置/删号重建，不是作弊**（`ベ` 10000029 就是这种） |

### 2.3 参考信号：只打印不判定

| 项 | 怎么看 |
|---|---|
| 战力排名 | 前 3 名重点核对成长曲线，但不构成作弊 |
| 英雄分布 | оня 是「190 个 1 级毛坯 + 5 个满级」，Sakuya 是「渐进养成」——形状比数字更重要 |
| 战斗节奏中位数 | 主线 5~6 秒/关是扫荡机制下的正常值，不是脚本 |
| 登录 IP | 家宽 `proxy=false` 正常；`proxy=true, hosting=true` 是机房/代理（оня 的瑞典 Qwins LTD） |

---

## 3. 六项核心检查（手工版，想搞清原理时看这节）

`cheat_scan.py` 封装的都是下面这些原始命令。

### 3.1 GM 通道（Sieg 类）

```bash
# 按 UID 数 GM_REQUEST（⚠️ 两层 grep 顺序不能反）
ssh gs 'grep -F "type GM_REQUEST" /data/srvlog/gameserver.log \
  | grep -cF "uid 10000240"'

# 全服排行，一眼看出谁在刷
ssh gs 'grep "type GM_REQUEST" /data/srvlog/gameserver.log \
  | sed -E "s/.*uid ([0-9]+).*/\1/" | sort | uniq -c | sort -rn | head -20'

# 看他用了哪些指令
ssh gs 'grep "type GM_REQUEST" /data/srvlog/gameserver.log | grep "uid 10000240" \
  | sed -E "s/.*command\": \"([^\"]*)\".*/\1/" | sort | uniq -c | sort -rn'
```

指令格式 `项目#参数#数量`：`1#` 货币、`4#` 加道具、`7#8#9#28#` 解锁/等级、`10#1#0~10#3#0` 新手引导。

> **别把 `uid N` 直接 grep 全日志**：日志里每行都带 `request=<uid> commond =X` 和
> `doWork->uid=N,mType=X`，普通协议也会命中。必须先过滤 `type GM_REQUEST`。

### 3.2 GM_REWARD 账本（唯一能覆盖全生命周期的证据）

```bash
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
print(\"GM_REWARD 笔数=\" + db.itemLog.count({uid:10000240, reason:28}));
db.itemLog.find({uid:10000240, reason:28}).sort({itemNum:-1}).limit(5).forEach(function(d){
  print(new Date(Number(d.time)).toISOString() + \" item\" + d.itemId + \" x\" + d.itemNum);});"'
```

`itemLog` 是**只增不改的永久账本**，`reason=28` 只由 GM 通道产生。
⇒ **这是判「历史上是否 GM 刷过」的唯一可靠手段**（日志会被重启截断）。

全服一次扫出所有 GM 刷过的号：

```bash
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
db.itemLog.aggregate([
  {\$match:{reason:28}},
  {\$group:{_id:\"\$uid\", n:{\$sum:1}, mx:{\$max:\"\$itemNum\"}}},
  {\$sort:{mx:-1}}
]).forEach(function(d){
  var u=db.user.findOne({_id:d._id});
  print(d._id + \" \" + (u?u.playerManager.nickName:\"(已删)\") + \" \" + d.n + \" 笔, 单笔最大 \" + d.mx);});"'
```

### 3.3 业务接口滥用（Mozart 类，GM 关了也防不住）

**没有通用命令，要看「同一 reason 的发放笔数 + 时间密度 + 单笔量级」。**

```bash
# 该号各 reason 的发放分布（先找异常的 reason）
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
db.itemLog.aggregate([
  {\$match:{uid:10000013}},
  {\$group:{_id:\"\$reason\", n:{\$sum:1}, mx:{\$max:\"\$itemNum\"}, sum:{\$sum:\"\$itemNum\"}}},
  {\$sort:{n:-1}}
]).forEach(function(d){print(\"reason=\"+d._id+\" 次数=\"+d.n+\" 单笔最大=\"+d.mx+\" 合计=\"+d.sum);});"'

# 该 reason 按天/按分钟的密度（Mozart 是 1 分钟 35 笔）
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
db.itemLog.find({uid:10000013, reason:1}).sort({time:1}).limit(40).forEach(function(d){
  print(new Date(Number(d.time)).toISOString() + \" +\" + d.itemNum);});"'
```

判据：
- **单笔数值的独有性**：`777600` 这个数全服只有他一个人有，且重复 6 次
- **笔数离群**：当日奖励笔数 33 vs 第二名 6（5.5 倍）
- **时间密度**：1 分钟 35 笔、最短间隔 0.3 秒

### 3.4 数据自洽（改库类）

三个必须同时成立的恒等式：

**① 主线进度 = 战斗记录**

```bash
# 1) 玩家当前 fightId
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
var u=db.user.findOne({_id:10000017});
print(\"fightId=\" + u.mainLevelManager.fightId);"'

# 2) 他 fightLog 里主线的最高关（fightType 是 GBK 错编码，用 charCode 定位）
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
var ts=db.fightLog.distinct(\"fightType\"), M=\"\";
ts.forEach(function(t){ if(t.charCodeAt(0)===0x6d93) M=t; });
var mx=0, n=0;
db.fightLog.find({uid:10000017, fightType:M}).forEach(function(r){
  n++; if(r.fightLevel>mx) mx=r.fightLevel; });
print(\"主线战斗=\" + n + \" 最高关=\" + mx);"'
```

**3) 换算**（本机执行，需要 openpyxl）：

```bash
cd /Users/wangxufeng/Documents/TimeSpaceGirl1/data_execl/base_data
python3 - <<'EOF'
import openpyxl
wb = openpyxl.load_workbook('MainLevelConfig.xlsx', read_only=True)
ws = wb['MainLevelConfig']
id2name = {int(r[1]): int(r[3]) for r in ws.iter_rows(min_row=8, values_only=True)
           if r[1] is not None and r[3] is not None}
for fid in (4122, 3202, 12111, 15405):
    print(f'Id {fid} -> 关 {id2name.get(fid)}')
EOF
```

**判定**：

| delta = fightLog最高 − (Name−1) | 含义 |
|---|---|
| `0` 或 `+1` | ✅ 自洽（fightId 指向「当前要打的关」，fightLog 记「最近打过的关」） |
| `> +1` | ⚠️ fightLog 更靠前 = 回档/重置/删号重建，**不是作弊** |
| `< -1` | 🔴 fightId 冲到战斗记录前面 = **跳关 / 直接改库** |

**② 库存 = 日志末值（只对核心货币成立）**

`itemLog` 每条记录带 `itemTotalNum`（发放后的累计值）。
**只有「核心货币 / 不占背包的道具」这一条链是闭合的**，其余物品的 `itemTotalNum` 语义不同（见下方"已知差异"）。

```bash
# 只查核心货币：item14 金币 / item3 钻石 / item16 / item4
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
var U=10000017, u=db.user.findOne({_id:U});
[14,3,16,4].forEach(function(id){
  var arr=db.itemLog.find({uid:U, itemId:id}).toArray();
  arr.sort(function(a,b){ return Number(a.time)-Number(b.time); });   // ⚠️ time 是字符串
  var logged=arr.length?Number(arr[arr.length-1].itemTotalNum):null;
  var cur=Number((u.itemManager.itemMap[String(id)]||{}).itemNum||0);
  print(\"item\"+id+\" 日志末=\"+logged+\" 库存=\"+cur+\" \"+(logged===cur?\"OK\":\"MISMATCH\"));
});"'
```

实测（Sakuya）：`item14/3/16/4` **全部 OK** —— 核心货币链闭合，说明没有凭空增发。

**已知的四类正常差异**（都别当 bug，更别当作弊证据）：

| 现象 | 原因 |
|---|---|
| `itemLog` **没有消耗记录** | 全服 `itemNum < 0` 条数 = 0，消耗不写账本；只能比对"最后一次发放后的累计值" |
| 周期道具（如 `item24`）`itemTotalNum` 回退 | 赛季重置，实测 Sakuya 回退 **22 次**、峰值 21555 → 重置到 160 |
| `item62/63/83` 这类 `BackpackOrNot=False` 的券类 | 发放时 `itemTotalNum` 写 0/1（不累计），与库存数字无对应关系。**猫神、希维琳达、Painajainen 全都如此，是普遍现象** |
| 道具被消耗过 | 库存 < 日志末值很正常（日志不含消耗） |

> ⚠️ 所以「全量逐物品对账」会稳定报出 3~4 条假差异（`item24` + 几张券）。
> 判作弊只看**核心货币是否闭合**；道具异常要看 `reason` 分布和单笔量级（§3.3），不要指望对账。

**③ 竞技场场次 = 挑战券消耗**

```bash
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
var U=10000017;
var ts=db.fightLog.distinct(\"fightType\"), A=\"\";
ts.forEach(function(t){ if(t.charCodeAt(0)===0x7ed4) A=t; });
print(\"竞技场场次=\" + db.fightLog.count({uid:U, fightType:A}));
print(\"挑战券消耗=\" + db.itemLog.count({uid:U, reason:1022}));"'
```

每场必扣一张券。场次远超券消耗 ⇒ 白嫖场次。

### 3.5 账号关联（同伙 / 马甲）

```bash
# 1) 拿 openId（游戏库和登录库是两套 openId，都要查）
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
print(db.user.findOne({_id:10000017}).playerManager.openId);"'
ssh gs 'mongo --quiet x1_cn_test_login --eval "
print(db.user_info.findOne({_id:10000017}).openId);"'

# 2) 登录服日志里按 openId 取 IP
ssh gs 'grep -h "gt921614b8dd" \
  /home/java/loginserver/apache-tomcat-8.5.95/logs/localhost_access_log.*.txt \
  | grep -oE "^[0-9.]+" | sort | uniq -c | sort -rn | head -20'

# 3) 同一 IP 段还有谁（找小号/同伙）
ssh gs 'grep -hE "^91\.235\.|^178\.137\." \
  /home/java/loginserver/apache-tomcat-8.5.95/logs/localhost_access_log.*.txt \
  | grep -oE "openId=[a-zA-Z0-9]+" | sort | uniq -c | sort -rn | head -10'
```

IP 归属地 / 代理检测（本机）：

```bash
curl -s "http://ip-api.com/json/31.207.7.168?fields=status,country,regionName,city,isp,org,as,proxy,hosting&lang=zh-CN"
```

判读：
- `proxy=false, hosting=false` + 家宽 ISP ⇒ 正常玩家
- `proxy=true, hosting=true` + 陌生机房 ⇒ 高度可疑（оня 的 `31.207.7.168` 是瑞典 Qwins LTD，proxy/hosting 双 true）
- ⚠️ 游戏库 `playerManager.ip` **恒为空字符串**，必须查登录服日志

### 3.6 全服扫（找还不知道的可疑号）

```bash
python3 scripts/cheat_scan.py --hunt
```

覆盖四项：
1. `GM_REWARD`（reason=28）持有者
2. 单笔发放 TOP15
3. 主线进度不一致（Id→Name 换算后逐号比对）
4. 排行榜脏数据（Redis 有名次但 `user` 文档已不存在）

**顺带能发现的两类非作弊问题**（也要处理，但不封号）：
- 榜单脏数据：`common_force_rank` 第 1 名 `10000016` 的 `user` 文档已不存在 ⇒ 需要清 Redis 条目
- 空壳号：211 个 user 文档里有很多 `fightId=1011` + `fightLog=0` 的未激活号

---

## 4. 结论怎么下

```
H1/H2/H3/H4 任一命中 ──────────────→ 🔴 确证作弊
        ↓ 都没有
S1~S5 任一命中 ────────────────────→ ⚠️ 可疑，人工复核
        ↓ 都没有
           ────────────────────────→ ✅ 未发现作弊证据
```

### 4.1 「可疑」怎么复核

按这个顺序排掉误报，**大头都在这里**：

1. **S5 进度回退** → 查建号时间 + `loginTime`。老号突然回退 = 回档，不是作弊
2. **S1 金币离群** → 跑 §3.4② 的**核心货币**对账（item14/3/16/4）；闭合且能追到 `reason` 来源 ⇒ 正常
3. **S2/S3 竞技场** → 看 `skipFight` 是否 1；券消耗（`reason=1022`）对得上 ⇒ 正常
4. **S4 主线缺口** → 确认缺口位置；如果集中在某几关且那几关有失败记录 ⇒ 正常（重打覆盖）

### 4.2 「干净」也要写清楚

干净≠没查。报告里必须列出**每一项查了什么、值是多少**，
否则下次换人复查时无法判断「是真干净还是漏查了」。

`cheat_scan.py` 的默认输出就是干这个的：每项一行 `✅/⚠️/🔴 + 判据名 + 实测值`。

---

## 5. 实战档案：四个号，四种手法，两种误判

这一节是本文的**校验集**——改判据后拿这四个号回归，结论必须一致。

### 5.1 Sieg / UID 10000240 —— GM 指令滥用（最直白）

| 项 | 值 | 判定 |
|---|---|---|
| 建号 → 满级 | 30 分钟内 100 级 | 快，但单独不构成证据 |
| `GM_REQUEST` | **114 次**（全服其他玩家 3~12） | 🔴 H1 |
| GM 指令时段 | 15:41:58 ~ 15:45:16（3 分钟） | 🔴 |
| 典型指令 | `4#11xxx#13` 刷道具 ×86、`1#3#2000000000` 单条 20 亿 ×4 | 🔴 |
| 战力 / 主线 | 378 万全服第一，主线仅 20 关 | ⚠️ 严重不符 |
| 设备指纹 | `platform=PC`、设备字段全空 | ⚠️ 自建客户端 |

根因：`server.debug=true` 让 `GMRequestHandler` 对所有人开放。**已关。**

### 5.2 Mozart / UID 10000013 —— 业务接口裸奔（GM 关了也防不住）

| 项 | 值 | 判定 |
|---|---|---|
| `GM_REQUEST` | 3 次（正常新手引导） | ✅ **假阴性陷阱** |
| 1 分钟内 `ADVENTURE_REWARD_REQUEST{type:2}` | **35 次**，最短间隔 0.3 秒 | 🔴 H3 |
| 单次产出 | **777,600 钻石** + 20 余种物品 | 🔴 |
| 当日奖励笔数 | 33 vs 第二名 6（5.5 倍） | 🔴 |
| 钻石总量 | 1.256 亿 vs 全服中位数 200（62.8 万倍） | 🔴 |
| 数值独有性 | `777600` 全服仅他一人，重复 6 次 | 🔴 |

根因：`CombatLogic.takeNewAdventureReward()` 的 `type==2` 分支**无任何次数/冷却/进度校验**。
**已打 Javassist 补丁**（`patches/adventure_reward_guard/`）。

> 💡 **这个号是本 skill 最重要的教训**：GM 指令为 0 的干净号也可能在挂。

### 5.3 Sakuya / UID 10000017 —— 长得像挂，其实干净（误判防御）

最容易被冤枉的样本：**资源第 2、战力第 3、竞技场场次第 1、日志量全服最多**。

| 项 | 值 | 判定 |
|---|---|---|
| `GM_REQUEST` | 0 次 | ✅ |
| `GM_REWARD`（reason=28） | **0 笔**（3.3 万条 itemLog 全查） | ✅ H2 未命中 |
| 单笔最大发放 | 2048 万（阈值 1 亿） | ✅ |
| 主线 | `fightId=4122` → 关 402；`fightLog` 最高 402，差 **+1** | ✅ 自洽 |
| 主线连续性 | 1..401 连续无缺口，434 次尝试 / 33 次失败 | ✅ |
| 金币 | 1680 万（活跃号 P50 198 万 / P90 1038 万） | ✅ 1.6× P90，未到 3× |
| 竞技场 | 674 场，消耗挑战券 **524** 张，间隔中位 **2.0s** | ✅ 秒扫机制内 |
| 主线节奏 | 间隔中位 5.6s / 最短 3.9s | ✅ 与猫神(3.6s)、希维琳达(4.4s)同量级 |
| 英雄养成 | 106 个，1×10星 + 4×9星，主力 190~205 级 | ✅ 渐进 |
| 登录 IP | 49 天全在乌克兰 Kyivstar/HataNet 家宽，`proxy=false` | ✅ |
| 与已封号 IP 交集 | 无 | ✅ |
| 时长 | 2026-05-21 建号，149 天 / 51 个战斗日 / 2789 场 | ✅ 长线玩家形状 |

**结论：未发现作弊证据。** 高活跃度≠作弊，判据要落到「账本能否解释这个数字」。

### 5.4 оня / UID 10000198 —— 至今未封的 GM 刷号（**当前最优先**）

| 项 | 值 | 判定 |
|---|---|---|
| 建号 | 2026-09-20 07:59 | —— |
| `GM_REWARD` | **建号后 37 分钟**收到 9 笔，其中 `item3/14/16` 各 **20 亿**、`item4` 10 亿 | 🔴 H2 |
| 登录 IP | `31.207.7.168` 瑞典斯德哥尔摩 **Qwins LTD，proxy=true, hosting=true** | 🔴 |
| 英雄分布 | 199 个里 **190 个是 1 级毛坯**，5 个 10 星 255 级，装备 0 件 | 🔴 形状异常 |
| 最后登录 | 2026-09-20 15:04（27 天前） | ⚠️ 但战力仍挂 force_rank 第 2 |
| 封禁状态 | **不在 FORBID_LOGIN** | 🔴 **漏网** |

**行动项**：按 `gm_abuse_incident_playbook.md` §3/§5 处置。
（`--hunt` 现在每次都能扫出他。）

### 5.5 两个已排除的误报

| 号 | 现象 | 真相 |
|---|---|---|
| `ベ` / 10000029 | `fightLog` 最高 180 关，但 `fightId=1161`（关 16），差 **+165** | **回档**：`2026-05-25 10:23` 打过 180 关，`13:27` 从头重来。delta 为**正**，是 fightLog 更靠前 ⇒ 不是跳关 |
| `10000153` | 标称 15405 关 vs fightLog 45 关 | 原判断拿 **Id 比 Name**（15405 换算后是第 2550 关）。真实异常幅度是 2550 vs 45，仍异常，但推理链必须写对 |

---

## 6. 与封禁处置的衔接

```
「是不是挂」→ 本文（只读，不动数据）
「确认了怎么封」→ gm_abuse_incident_playbook.md
   §3.1  FORBID_LOGIN 名单（唯一真正有效的封号）
   §3.2  IP 封禁（仅临时止血）
   §3.3  ❌ 不要删账号（查不到就自动建档）
   §4    server.debug 必须 false
   §5    数据清理 + 排行榜（⚠️ 只删作弊者条目）
   §5.4  🔴 删号后必须清全部引用，否则排行榜直接崩
   §6    验收清单
```

**本文产生的结论不要直接当成封禁授权**——封禁是不可逆动作，按 §0 红线走人工确认。

---

## 7. 踩坑清单

| # | 坑 | 表现 | 正确做法 |
|---|---|---|---|
| 1 | **`fightId` 不是通关数** | 「标称 15405 关实际 45 关」 | 用 `MainLevelConfig.xlsx` 的 `Id→Name` 换算 |
| 2 | **中文在 `mongo --eval` 里乱码** | 查 `fightType:"主线"` 返回 0 条 | 库把 GBK 字节当 UTF-8 存了：`主线`→`涓荤嚎`(首字 U+6D93)、`竞技场`→U+7ED4、`胜利`→U+9473、`失败`→U+6FB6。**用 `charCodeAt(0)` 定位，别写字面量** |
| 3 | **日志只有本次启动之后** | `GM_REQUEST` 查不到历史 | 用 `itemLog`（永久账本）兜底；日志窗口从 `2026-10-10 17:14` 起 |
| 4 | **`itemLog.time` 是字符串** | 按 `time` 排序结果错乱 | `Number(a.time) - Number(b.time)` |
| 5 | **`itemLog` 无消耗记录** | 全量库存对账必报几条假差异 | 只对核心货币（item14/3/16/4）对账；道具看 reason 分布，别对账 |
| 6 | **周期道具会重置** | `itemTotalNum` 回退 | 正常。`item24` 回退 22 次 |
| 6b | **券类物品 `itemTotalNum` 恒为 0/1** | `item62/63/83` 库存 1~2 但日志末值是 0 | 全服普遍现象（猫神/希维琳达/Painajainen 都一样），`BackpackOrNot=False` 的券不累计 |
| 7 | **金币基线要用活跃号** | 用全服 P50（25 万）会把正常玩家判成 66 倍离群 | 用 `itemLog ≥ 500` 的活跃号 P90（1038 万） |
| 8 | **`貝`/`ベ` 这类重名** | 按昵称查到多个 | 按 UID 查；昵称用正则并人工确认 |
| 9 | **`playerManager.ip` 恒为空** | 游戏库查不到 IP | 查登录服 `localhost_access_log.*.txt` |
| 10 | **两套 openId** | 游戏库 openId ≠ 登录库 openId | 两个都查，日志里也都能搜到 |
| 11 | **`grep uid N` 会误命中** | 普通协议行也带 `uid N` | 先 `grep "type GM_REQUEST"` 再数 uid |
| 12 | **`fightResDiffLog` 覆盖面极窄** | 只有 13 个 UID 有比对记录（10000002~10000140 附近） | 高 UID 改战斗结果**查不出来**，别把它当"没作弊"的证据 |
| 13 | **`--hunt` 里 delta 方向搞反** | 把回档当跳关 | delta 为**负**才是跳关；**正**是回档 |

---

## 8. 代码位置索引

| 判据 | 实现位置 |
|---|---|
| 阈值定义 | `scripts/cheat_scan.py` 顶部 `TH = {...}` |
| GM / GM_REWARD / 单笔 | `collect_hard()`、`collect_gm_requests_exact()` |
| 主线进度 | `collect_progress()` + `load_id2name()` |
| 节奏 / 竞技场 | `collect_pace()` |
| 分位对照 | `collect_peers()` |
| IP | `collect_ips()` |
| 判定逻辑 | `assess()` |
| 全服扫 | `hunt()` |
| `Id→Name` 换算表 | `data_execl/base_data/MainLevelConfig.xlsx`（`Name` = 行号） |
| `reason` 枚举 | 反编译 `com/ljsd/jieling/globals/BIReason.class` |
| GM 漏洞修复 | `TimeSpaceServer/patches/adventure_reward_guard/`（业务接口） |
| 封禁流程 | `docs/gm_abuse_incident_playbook.md` |

---

## 9. 快速参考：常用 UID

| UID | 昵称 | 情况 |
|---|---|---|
| 10000240 | Sieg | GM 刷资源，已封（第一轮） |
| 10000153 | 稀拉拉梵妮 | 直接改库，已封（第一轮） |
| 10000013 | Mozart | 业务接口刷奖，已封并删档（第一轮） |
| 10000198 | оня | GM 刷 20 亿，**已封**（第二轮 2026-10-18 02:20） |
| 10000034 | 未命名 | 12 分钟生命周期却有 372 万钻 / 548 万金，**已封**（第二轮） |
| 10000016 | —— | force_rank 脏数据（user 文档早已不存在），**已清条目并封**（第二轮） |
| 10000017 | Sakuya | 已排查，干净 |
| 10000069 | 猫神 | 正常高活跃（对照组） |
| 10000131 | Painajainen | 正常（V2 礼包对照组，证明 690 券→200 万钻是正式定价） |

> 封禁名单当前 6 个：`10000240 / 10000153 / 10000013 / 10000198 / 10000034 / 10000016`
> 查当前名单：`python3 scripts/cheat_scan.py --ban-list`

---

## 10. 2026-10-20 补充：两条旧判据抓不到的作弊（朗曼梅西案）

### 10.1 BI 文件流水才是「全生命周期账本」

Mongo `itemLog` 对 10000221–10000225 这一段**整段为空**（不是他一个人的问题，是队列 flush 断档），
任何「收支对账」在空表上都恒闭合。真正留痕的是游戏自身的文件流水：

```bash
# 目录按天分，保留期 ≥30 天（srvlog 只有 2~3 天）
ssh gs 'grep -h "10000224" /home/java/gameserver/assets/log/jl_item/*/item0.log' \
  | grep "reason=28" | wc -l        # 48
```

- `reason=28` = `BIReason.GM_REWARD`；`addHero` 有、对应 `addItem` 没有 ⇒ 直接建英雄实体，不是发卡。
- 模板 ID 从 10001 递增到 10079、间隔 1~2.4s ⇒ 脚本循环调 `GlobalGm.HERO_STAR=4`。
- 对应工具：`scan` 的 `bi_gm_reward`（hard）与 `purge --apply`。

### 10.2 `heroForceSort` 是「删英雄」的隐形地雷

`HeroManager.heroForceSort` 只存「≥100 级英雄的战力前 5」，且
`HeroForceRank.refreshHeroForceSort` 在结果为空时**不回写**（`HeroForceRank.java:168`）。
只删 `heroMap` 不清它，会留下 5 个指向已删英雄的成员：

- `getMyInfo` → `getHero(heroId)` 为 null → 打日志后 return（「我的排名」空白）；
- `getOptional` → 同一处直接 NPE（`HeroForceRank.java:88-89`），**全服点英雄战力榜都报错**。

处置口径：删英雄时同步 `$set heroManager.heroForceSort = {}`，并 `ZREM` 掉
`10001:HERO_FORCE_RANK:` 里 `uid:heroId` 的复合成员。工具已内置。

### 10.3 不要改 `maxForce`

`PlayerManager.maxForce` 是**当前阵容队伍战力**（`PlayerLogic.java:369` 写入），不是英雄战力总和。
GM 发的英雄若从未编入 `teamPosManager`，战力完全没被污染（朗曼梅西 4948，与同级 3 人完全一致）。
删英雄后去「重算 maxForce」只会造出假数据。
