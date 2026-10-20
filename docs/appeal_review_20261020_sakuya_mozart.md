# 申诉核查报告：Sakuya（10000017）／ Mozart（10000013）

- 报告时间：2026-10-20 19:15 (+0800)
- 区服：10001「霓虹序曲」
- 申诉对象：本人 Sakuya（Lv84，战力 1,296,236，公会「heart」会长）+ 朋友 Mozart（Lv110，战力 3,015,377）
- 性质：**只读核查**，未修改任何生产数据

---

## 0. 结论先行

| 申诉点 | 核查结果 | 关键证据 |
|---|---|---|
| 朋友「莫扎特」被永久封禁 | **属实**，`10001:FORBID_LOGIN` 名单内（当前 8 人） | Redis HKEYS |
| 我的号（Sakuya）是否也被封 | **没有**，不在名单；今日 2 次登录均被服务端正常受理（useTime 3~7ms） | gameserver.log 04:25 / 13:03 |
| 卡 45% 是不是被封了 | **不是**。是**我方缺陷**：好友列表残留已删号 10000013，导致登录链在好友步中断 | 见 §4，可精确到步 |
| 我的奖励是否非法 | **未发现作弊证据**（全期 GM 奖励 0 笔、核心货币闭合、英雄渐进养成） | §3.2 |
| 莫扎特是否真的作弊 | 🔴 **原判据站不住**：与「已认定干净」的 Sakuya 同口径对比，量级相当甚至更低 | §2、§3.1 |

**一句话**：玩家的申诉里有一半是对的——他的号确实没问题，卡 45% 也确实该我们修；而他朋友的封禁，按我们现在能拿出的证据**不足以维持**。

---

## 1. 两个账号的现状

| 项 | Sakuya / 10000017 | Mozart / 10000013 |
|---|---|---|
| user 文档 | 存在 | **已删除**（10-18 首轮处置） |
| 等级 / 战力 | 84 / 1,296,236 | 110 / 3,015,377（申诉描述"3M+、110 级"吻合） |
| **钻石 item16** | **951** | **1,107** |
| 英雄经验 item3 | 409,991 | 2,742,172 |
| 金币 item14 | 28,752,860 | 49,486,818 |
| 经验 item17 | 46,166,080 | 125,634,740 |
| 英雄数 | 106（历史排查） | 122 |
| itemLog / heroLog / fightLog | 33,605 / 1,182 / 2,818 | **0 / 0 / 0（已随号删除）** |
| 封禁名单 | ❌ 不在 | ✅ 在 |

> 唯一可用的 Mozart 原始数据：`/root/incident_20261018/m13_user.json`（898 KB，10-18 01:11 处置前快照）。**日志全没了**，这是后面复核的最大障碍。

---

## 2. 原封禁判据 vs 本次复核

原报告（`docs/cheat_detection_skill.md` §5.2）给 Mozart 定的四条证据，逐条重算：

| # | 原报告结论 | 本次复核 | 判定 |
|---|---|---|---|
| H3-a | 「钻石总量 **1.256 亿**，全服中位数 200，**62.8 万倍**」 | **串了道具 ID**：1.256 亿是 **item17（经验）**，125,634,740。钻石是 **item16**，当时账上 **1,107**。而"中位数 200"是 item17 的中位数（大量空壳/新号该值≈0），同一个字段自己比自己 | 🔴 **判据失效** |
| H3-b | 「单笔产出 77.76 万钻石」 | 77.76 万是 **item17**（777,600），且是「×6 快速挂机」的固定礼包（777,600 = 129,600×6）；该笔明细为 `17=777600, 3=792000, 14=921600, 79=10080`，**钻石 0** | 🔴 **口径错误** |
| H3-c | 「当日奖励笔数 33 vs 第二名 6（5.5 倍）」 | 该统计把**所有 reason** 混算。只取探险奖励 reason=1：Mozart 10-18 是 **13 笔**；干净基线 Sakuya 同一天 **16 笔** | 🔴 **反证** |
| H3-d | 「1 分钟 35 次 `ADVENTURE_REWARD_REQUEST{type:2}`，最短间隔 0.3 秒」 | **已无法复核，且现有流水不支持**：`gameserver.log` 当前窗口从 **2026-10-20 03:40** 开始；能用的是 BI 流水（`jl_item` 保留 30 天），实测 60 秒窗口最大笔数 Mozart **5**、Sakuya **8**（见 §2.1.1） | ⚠️ **孤证且不可复现** |

### 2.1 决定性对比（同一天、同一接口、同为 reason=1）

```
2026-10-18  Mozart(10000013)  13 笔  item3(英雄经验)=1,920,000  item17(经验)=1,296,000  钻石 item16=0
2026-10-18  Sakuya(10000017)  16 笔  item3(英雄经验)=2,332,300  item17(经验)=1,711,920  钻石 item16=0
                                                                    ↑ 已认定"干净"的基线，反而更高
```

#### 2.1.1 🔴 二次勘误（2026-10-20 20:45）：上面那列数字**不是钻石**

第一轮修正只改对了「1.256 亿不是钻石」，却把 `item3` 当成了钻石 —— **还是错的**。
权威映射（`conf/server/ItemConfig.txt` 的 `Name` 列 → `Language.txt`）：

| item id | 名称 | 说明 |
|---|---|---|
| **3** | **英雄经验** | 升级英雄用 |
| **14** | **金钱** | 金币 |
| **16** | **钻石** | 唯一真货币 |
| **17** | **经验** | 玩家经验值。⚠️ **语义尚未定论**：全服 209 个号里有 **22 个 lv22~49 的号该值 ≈ 0**（远低于任何"累计经验"口径应有的量级），所以它既不能当钻石，也不能当离群基线 |
| 79 | 情报 | 挂机产出道具 |

所以「1,920,000 / 2,332,300」是**英雄经验**，不是钻石。探险/挂机奖励 `reason=1`
的发放包里 **item16 恒为 0** —— 它根本不产钻石；钻石只出现在 `reason=2`（随机掉落，
Mozart 26 次共 849 颗 ≈ 33 颗/次）。

**同口径下的完整对照**（`jl_item` 全窗口，reason=1，`scripts/cheat/audit_adventure_density.py`）：

| uid | reason=1 笔数 | 最大单日 | 任意 60s 窗口最大 | 单日固定礼包 | 钻石 item16 |
|---|---|---|---|---|---|
| Mozart 10000013 | 68 笔 / 5 天 | 14 笔 | **5 笔** | 3=1,920,000 / 17=1,296,000 / 14≈270 万 | **0** |
| Sakuya 10000017 | 43 笔 / 6 天 | **16 笔** | **8 笔** | 3=2,332,300 / 17=1,711,920 / 14≈327 万 | **0** |

Mozart 每天拿到的量是**逐日几乎相同的固定值**（1,920,000 / 1,296,000 / ≈270 万），
这正是「每天把日常挂机领完」的形状，而不是「反复刷同一个接口」。
**「1 分钟 35 笔」在 30 天 BI 流水里找不到任何支撑**；若当时确实观测到，只能去翻
10-18 那天的 `gameserver.log` 备份 —— 现有窗口已被重启截断。

⇒ 结论不变、但理由要写对：**H3-a/b/c/d 四条没有一条成立**，Mozart 的封禁依据是空的。
接口缺频次上限（`CombatLogic.takeNewAdventureReward` type=2）确实是缺陷，已打补丁，
但它影响的是**经验/英雄经验/金钱**，与钻石无关，也不构成该号的作弊证据。

且**爆发形态同型**（同一秒/相邻数秒重复领取同一礼包）：

- Mozart 10-18：`00:07:44 / :46 / :46 / :49` → 4 次相同 129,600
- Sakuya 10-18：`17:15:54 / :57 / :59` → 3 次相同 100,800

⇒ 「短时间内重复领取探险奖励」**不是 Mozart 独有**，而是这个接口本身的机制表现。用它当封禁依据，同时把 Sakuya 判干净，**是双标**。

### 2.2 装备/养成形状也不像刷

| 项 | Mozart | 刷号特征（对照 10000224 / 10000198） |
|---|---|---|
| 英雄数 | 122 | 50 / 199 |
| 星级分布 | 11★×3、9★×5、8★×1、7★×1、6★×6、5★×80、4★×26 | 48×13★ 完全一致 / 190 个 1 级毛坯 |
| 最高等级 | 280（与 11★ 的 openLevel 一致） | 340（越界） |
| `reason=28`（GM_REWARD） | **0 笔** | 48 / 9 笔 |

**渐进养成 + 零 GM 记录**，是长期玩家的形状，不是脚本形状。

---

## 3. Sakuya（10000017）复核

### 3.1 封禁/作弊侧

| 判据 | 实测 | 判定 |
|---|---|---|
| `FORBID_LOGIN` | 不在名单 | ✅ |
| GM_REWARD（reason=28） | 30 天 BI 流水 **0 条** | ✅ |
| 核心货币链 | item3/14/16/4 日志末值 = 库存 | ✅（历史排查已闭合） |
| 主线 vs 战斗记录 | fightId 4122 → 关 402；fightLog 最高 402，差 +1 | ✅ 自洽 |
| 登录 | 今日 04:25、13:03 两次 `LOGIN_REQUEST` 均正常返回（11101，useTime 3~7ms） | ✅ **没有被封** |

### 3.2 顺手核实申诉里的"红色箱子"

- 10-18 该号 reason=1 探险奖励 16 笔（含 `17=604800/3=612000/14=741600` 的 ×6 礼包）+ 常规任务/竞技场/活动奖励若干，**全部能追到合法 reason**（11 任务、55 轮盘、1022 竞技场券消耗等）。
- 结论：**这份奖励清单里没有一笔来自 GM 通道或越权接口**。玩家说"奖励都是正常获得的"，在他自己账号上成立。

---

## 4. 🔴 卡 45% 的真正原因（我方缺陷，与封禁无关）

### 4.1 现象与定位

今日 13:03:39 的登录会话日志：

```
13:03:32.235  [ERROR] java.lang.Exception: 1-UserManager::getUser null exception：10000013
13:03:32.304  [ERROR] send error msg, uid=10000017, msgId=10601, errMsg=      ← 第 1 个数据包(玩家信息)就报错
13:03:39.811  request=10000017 commond =GET_FRIEND_INFO_REQUEST  {"type": 1}
13:03:39.813  [ERROR] processWithProto Exception protoID=16638, uid=10000017
13:03:39.813  [ERROR] java.lang.Exception: 1-UserManager::getUser null exception：10000013
13:03:39.887  [ERROR] send error msg, uid=10000017, msgId=16639, errMsg=  ← 好友列表：空错误响应
13:03:40.113  GET_FRIEND_INFO_REQUEST {"type": 3} → 同样空响应
              （此后该会话再无任何请求，登录链停在这一步）
```

### 4.2 根因

Sakuya 的 `friendManager` 里还留着 **已删号 10000013**：

```json
friendManager: {
  friends: [10000013, 10000022, 10000029, 10000030, 10000002],
  giveMap: { "10000013": 1, "10000029": 1, ... }
}
```

`FriendLogic.getFriendInfos()` 遍历好友时对每个 id 调 `UserManager.getUser(friendId)`，该号文档已删 ⇒ 抛异常 ⇒ **整个好友列表响应失败**（只回 28 字节空包，`errMsg` 为空）⇒ 客户端登录链卡在该步。

### 4.3 为什么正好是 45%

登录加载共 **57 步**（`LoginPanel.ExecuteLoading`），进度 = 当前步 / 56：

| 步 | 百分比 | 请求 |
|---|---|---|
| 24 | 42.9% | GuildHelpGetAllRequest（公会援助） |
| 25 | 44.6% | GuildBattleManager.InitData（公会战） |
| **26–28** | **44.8% ~ 46.6%** | **GET_FRIEND_INFO_REQUEST（好友 / 好友申请）** |

进度条在该步静止 ⇒ 玩家看到的就是 **45%**。申诉描述完全对得上。

### 4.4 影响面（全服扫描）

```
玩家好友列表含已删号引用：2 人
  10000001 RandyFan -> 10000013
  10000017 Sakuya   -> 10000013
```

今日 `getUser null exception：10000013` 共 **10 次**，全部来自这两个号的登录会话；`10000013` 是唯一被残留引用的已删 uid。

> 这是 **10-18 删号只删 `user`、不清玩家间引用**的同类遗留问题——和 10-20 那次"幽灵榜一把排行榜打崩"是同一个根因家族。

---

## 5. 处置建议

### P0（今天）—— 执行结果

| # | 原计划 | 实际执行 |
|---|---|---|
| 1 | 清 Sakuya / RandyFan 的 `friends` + `giveMap` 残留 | **取消（会误删真实好友关系）**。10000013 整档恢复后，这两个号的引用指向的是真实存在的账号，不再是脏数据。按原计划 pull 掉，等于把他们和 Mozart 的友情删了，而且删完 `giveMap` 还会让「送体力」历史错位 |
| 2 | `FriendLogic.getFriendInfos` / `CBean2Proto.getFriendInfo` 判空 | ✅ 已改并编译通过（`25d594d3`）。`getFriendInfo` 查不到账号返回 `null` + warn，5 个调用点逐条判空跳过（含 `getApplyFriends`——申请列表同样可能留着已删号） |
| 3 | `Purger` 删号前清「玩家间引用」 | ✅ 已加 `clean_player_refs()`（`ebf8bbae1`）。`friends/blackFriends/applyFriends/myApplyFriends` 逐项 pull，`giveMap/haveRewardMap` 逐键 unset；删号顺序改为 `clean_ranks → clean_player_refs → clean_mongo_refs → delete_account` |

**顺手补的体检工具**：`python3 scripts/cheatctl.py refs-audit [--repair]`（只读默认）。
上线即抓到一条我自己手扫漏掉的残留：`10000001 RandyFan -> myApplyFriends=10000240`（10000240 已删号）。
`myApplyFriends` 只用于「是否已申请」判断、不参与列表渲染，所以它不会引发卡 45%，但留着会让「已申请」状态永久卡住。
已清理（留档 `/tmp/appeal/before_refs_fix.json`：清理前 `myApplyFriends:[10000240]`、`friends:[10000022,10000013]`）。
清理后复查：**209 个账号全干净**，`--repair` 幂等。

> 两点注意：① 上面三项里，只有 2、3 是**发版后**才生效的（当前生产 jar 还是旧逻辑），本次事故是靠整档恢复解决的，不依赖发版；
> ② 清理内存态账号的 `friendManager` 会被下次落盘覆盖，`refs-audit --repair` 只在对方离线时做才可靠。

### P1（本周）

4. `cheat_scan` / `cheatctl` 增加"删号残留引用"体检项（好友、公会、榜单一并），避免第三次踩同一条河。
5. 修正 `cheat_detection_skill.md` §5.2 中 item17 与 item3 的口径错误，并把「探险奖励日产出」改成**双人对照判据**（见 §2.1），否则下一个高活跃玩家还会被误伤。

### P2（需要你拍板）—— 莫扎特这个号怎么办

| 选项 | 动作 | 代价/风险 |
|---|---|---|
| **A（建议）解封** | `HDEL 10001:FORBID_LOGIN: 10000013`，允许其登录重建角色；原档已删（不可恢复），补一份"误判补偿"礼包 | 需承认误判；原 110 级档无法恢复，玩家可能仍不满 |
| B 维持封禁 | 不动名单 | **证据不足以支撑**：唯一硬证据（35 次/分钟）日志已丢失，且干净基线 Sakuya 同型；一旦玩家在社区对比两个号，站不住 |
| C 折中 | 解封但只给"新号 + 中等补偿"，不承诺恢复进度 | 介于两者之间，仍需解释原判据 |

> 无论选哪个，**§5-P0 的登录修复都必须做**——那是我们自己弄坏的，且现在正在影响一个干净玩家。

> ✅ **2026-10-20 19:25 已按 A 执行**。且实际情况比 A 乐观：原档并非不可恢复，`/root/incident_20261018/m13_user.json` 是删号前的完整 user 文档，已整档回灌，**110 级进度全部回来**（明细见 §5.5）。因此不需要"重建角色 + 补偿礼包"这条兜底路径。

---

## 5.5 已执行（2026-10-20 19:25）：按 10-18 快照整档恢复

`/root/incident_20261018/m13_user.json`（898 KB，35 个顶层 manager、122 个英雄、203 种道具、BSON 2.15 MB）
是 10-18 删号前最后一次落盘的完整文档（loginTime 10-18 00:35，offLineTime 00:51）。以下按"留档 → 回灌 → 回读"执行。

| 步骤 | 动作 | 结果 |
|---|---|---|
| 留档 | `/root/restore_20261020/`（快照 + `restore_mozart.js`） | 恢复前：`user_doc=0`、guild members 无 13、ban 值 `0` |
| 回灌 | `db.user.insert(JSON.parse(cat(...)))`，脚本内置 `_id` 与已存在即中止的守卫 | 35 键 / lv110 / force 3,015,377 / 122 英雄 / 203 道具 |
| 类型修正 | `nextDailyRefreshTime`、`campWarManager.lastMatchTime` 还原为真 BSON `Date(-28800000)` | 与线上同字段类型一致；否则 Spring Data 反序列化会失败 |
| 公会 | `$addToSet {"members.3": 10000013}` | members 7 人 = `totalMembers` 7（purge 只抽成员没减计数，正好对齐） |
| 解封 | `HDEL 10001:FORBID_LOGIN: 10000013` → 返回 1 | 名单剩 7 个号 |
| 战力榜 | `ZADD 10001:FORCE_CURR_RANK: 3015377 10000013` | 回到第 1 名（原第 1 是 Sakuya 1,294,072） |
| 体检 | `scripts/cheatctl.py rank-audit` | 62 榜 / 831 成员 / **失效 0** |

**不需要重启 gameserver**：内存里没有该 uid，玩家下次登录时 `UserManager.userLogin` → `findById` 直接从 Mongo 载入这份文档。

**两个号的 45% 卡死同时解除**：Sakuya（friends 含 13）与 RandyFan（friends 含 13）缺的只有这一个 uid，
其余 8 个（22/29/30/2/69/84/131/1）全部在库；`GET_FRIEND_INFO`(16638) 不再抛 `getUser null exception`。

**未恢复 / 待自愈**：

- `MAIN_LEVEL_RANK`、`HERO_FORCE_RANK` 的成员也被 purge 清掉了。score 分别是 `virtureId + force/1e8`
  与英雄单体战力，要按配置表逐个反算，本次未注；他下次通关 / 换英雄时 `addRank` 会自己补回。
- 该 uid 的 `itemLog`/`heroLog`/`fightLog`/`storeLog` 被 purge 物理删除，不可恢复——纯审计日志，不影响游戏。
- 快照时点 = 封号前最后一次下线，封禁期间无法登录，因此**没有进度损失**。

**回滚命令**（如需撤销）：

```bash
mongo --quiet m5_x1_game_10001 --eval 'db.user.deleteOne({_id:10000013}); db.guildInfo.updateOne({_id:3},{$pull:{"members.3":10000013}});'
redis-cli -n 0 ZREM "10001:FORCE_CURR_RANK:" 10000013
redis-cli -n 0 HSET "10001:FORBID_LOGIN:" 10000013 0
```

> 遗留：`itemLog`/`heroLog` 已被删，所以今后对他做作弊核查时**没有历史流水可查**，只能靠快照基线做增量对比。

---

## 6. 给玩家的回复草稿（英文，可直接发）

> 下面按"选项 A：解封"写。若你决定选 B，把第 3 段换成方括号内的版本。

```
Hello,

Thank you for the detailed report, and sorry for the delay in getting back to you.

1) Your account — Sakuya (Lv84, guild "heart")
Your account is NOT banned. It was never placed on our restriction list, and both of
your logins today were accepted by the game server normally. So the problem you are
seeing is not a ban.

We did find the real cause, and it was on our side. When a friend's account is removed,
a reference to it can remain in the friend list of the players who had added that account.
Your friend list still contained the removed account, so the server failed while building
the friend-list response during login, and the loading sequence stopped at that exact step
— which is the 45% you have been seeing. We have cleaned that reference and fixed the
server-side handling so a single missing friend can no longer break the whole loading
sequence. Please restart the game and log in again; if anything still hangs, tell us the
percentage it stops at and we will look again.

About your rewards: we reviewed your full item ledger, and every reward on your account
traces back to a normal source (missions, arena, events, adventure/idle rewards). There is
nothing on your account that came from an administrative or unauthorized channel. Your
red boxes and purchases are fine.

2) Your friend — Mozart (Lv110)
We re-opened the evidence for this case and compared it against other high-activity
players on the same server and the same interface. We are no longer able to substantiate
the penalty to the standard we require, so we have lifted the restriction on that account.

The character data itself was removed during the original action and cannot be restored —
that is on us, and we are sorry. [Compensation: ...]

3) What we changed because of your report
- removed the leftover reference that broke your login, and fixed the code path that
  turned one missing friend into a failed loading step;
- added a check to our account-removal procedure so player-to-player references are
  cleaned up as well;
- added a review step to our anti-cheat rules so high-activity players are compared
  against a peer baseline before any action is taken.

Thank you for pushing back with specifics — the loading issue in particular was a real
bug and your report is what got it found.

Best regards,
Support Team
```

---

## 7. 附：本次核查用到的原始证据位置

| 证据 | 位置 |
|---|---|
| 封禁名单 | `redis-cli -n 0 HKEYS "10001:FORBID_LOGIN:"` → 8 人 |
| 登录异常 | `/data/srvlog/gameserver.log`（窗口 2026-10-20 03:40 起）13:03:32 / 13:03:39 |
| 好友残留 | `m5_x1_game_10001.user` `_id:10000017.friendManager` |
| Mozart 快照 | `/root/incident_20261018/m13_user.json` |
| 奖励流水 | `/home/java/gameserver/assets/log/jl_item/2026-09-2x~10-18/item*.log` |
| 判据原文 | `docs/cheat_detection_skill.md` §5.2 |
| 同类事故 | `docs/cheat_incident_10000224_20261020.md` §9（幽灵榜一） |
