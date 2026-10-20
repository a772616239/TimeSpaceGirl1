# 奖励重复发放 / 账号存档消失 —— 事故根因报告

> 日期：2026-10-20
> 触发：玩家反馈「重启服务器后奖励重复发放」「昨天收到两个相同红箱（装备/竞技场水晶）」「很多东西都能直接买」「后来你们删了服务器，我们账号也没了」
> 结论：**重启不是原因**。真正原因是「一个被删掉的角色存档 + 好友列表残留引用」把**每日刷新事务**打断，
> 导致 `loginTime` 永不回写 → 每次登录都重跑一遍每日刷新 → 公会捐献进度奖励每次补发一份。

---

## 0. TL;DR

| 玩家说法 | 实际机制 | 证据 |
|---|---|---|
| 重启后奖励重复发 | 与重启无关；**每次登录**都在重发（重启只是把内存里未落库的邮件清掉，所以「感觉」是重启后变化） | uid=10000017 一天触发 9 次 `dailyRefresh`，8 次伴随同一封邮件 |
| 收到两个一样的红箱子 | 同一封「**捐献进度奖励**」（title `25010100`）被发了 **11 次**，每封 `公会贡献×350 + 金币×45000` | DB 中该角色 `mailMap` 里 head=25010100 共 11 封，其中 3 封已领取(state=3) |
| 所有东西都能买、角色也能用游戏币买 | 重复到账的金币直接抬高了购买力 | 每封 45000 金币 × 11 |
| 账号没了 | 登录库 248 个账号，游戏库只有 208 个角色 → **40 个账号的角色存档已不存在** | `x1_cn_test_login.user_info`=248 / `m5_x1_game_10001.user`=208 |

---

## 1. 现场证据（生产服 gs / 10001 区）

### 1.1 日志：每日刷新 → 发奖 → 立刻抛异常（同一毫秒级序列）

```
2026-10-20 13:03:32.209 [h-17] GlobalDataManaager#348  dailyRefresh. UserId=10000017
2026-10-20 13:03:32.213 [h-17] STableManager#201      initMap:SGuildSacrificeRewardConfig
2026-10-20 13:03:32.214 [h-17] MailLogic#343          sendMail==>uid=10000017,title=25010100,reward:65#350|14#45000
2026-10-20 13:03:32.235 [h-17] HandlerLogicThread#219  java.lang.Exception: 1-UserManager::getUser null exception：10000013
        at UserManager.getUser(UserManager.java:292)
        at FriendLogic.refreshState(FriendLogic.java:709)
        at GlobalDataManaager.checkNeedReFlush(GlobalDataManaager.java:359)
        at GetPlayerInfoHandler.process(GetPlayerInfoHandler.java:79)
2026-10-20 13:03:32.304 [h-17] MessageUtil#311        send error msg, msgId=10601   ← 客户端拿到错误包
```

- 今天 10 次、10-19~10-20 累计 44 次同类异常，**全部指向同一个 uid：10000013**。
- uid=10000017 的 `dailyRefresh` 时间点：10-19 13:36:03 / 13:37:27 / 14:58:53、10-20 00:18 / 00:23 / 02:23 / 02:34 / 02:41 / 04:25 / 13:03（≈9 次/24h）。

### 1.2 数据：`loginTime` 卡死，`offLineTime` 正常

```
10000017  loginTime = 2026-10-18T09:15:16Z   ← 两天没动过
          loginTimeTody = 2026-10-18T09:15:16Z
          offLineTime   = 2026-10-20T05:03:52Z  ← 正常（13:03 下线）
```

`checkNeedToFlush` 的判断是 `TimeUtils.isOverTime(0, loginTime)`。`loginTime` 停在 10-18 ⇒ **每次登录都判定「跨天了」⇒ 每日刷新整段重跑**。

### 1.3 数据：重复邮件实体

```
uid=10000017  mailMap 共 16 封，其中 head=25010100 共 11 封
  10000017010217914803320000  state=3  65#350|14#45000   (已领取)
  10000017010217922566210000  state=3  65#350|14#45000   (已领取)
  10000017010217923882470000  state=0  65#350|14#45000   (未领，仍可领)
  …… 共 11 封
uid=10000084  同类 1 封
```

`25010100` = 语言表「**捐献进度奖励 / Donation Progress Reward**」（`ErrorCodeEerverConfig.txt:151 guildsacrifice_reward_title 25010100`）；
`65` = 公会贡献，`14` = 金币。

### 1.4 数据：被删存档 + 残留引用

```
user(10000013) 不存在          ← 角色存档被删
friendManager.giveMap 里仍引用 10000013 的玩家：10000001、10000017、10000069、10000084、10000131（5 人）
```

这 5 人每次登录都会在 `FriendLogic.refreshState` 抛异常。

### 1.5 时间起点对上了：10-18 删号 = 毒种子诞生日

```
快照 /root/incident_20261018/m13_user.json → uid=10000013, nick=Mozart（10-18 02:29 备份，原档已删）
uid=10000017 的 loginTime 冻结在 2026-10-18T09:15:16Z  ← 与删号是同一天
```

即：**10-18 删掉 Mozart(10000013) 的存档，从那天起这 5 个玩家的每日刷新就再没成功过一次**，
`loginTime` 自此再未推进，重复发奖从 10-18 一直持续到现在。

### 1.6 今天重启次数（证明与重启无关）

```
12:17:13 / 13:28:40 / 14:25:59 / 16:11:25  ← 4 次重启
```
而 04:25、02:23、02:34、02:41 这几次重复发奖都发生在**重启之前**，说明与重启无因果，只是登录刷新反复失败。

---

## 2. 因果链

```
① 角色 10000013 被删（user 文档不存在，账号仍在登录库）
        ↓
② 5 个玩家的 friendManager.giveMap 仍留着 10000013
        ↓
③ 登录 GET_PLAYERINFO → GlobalDataManaager.checkNeedReFlush()
        ├─ 先跑：活动刷新 / 公会每日刷新 → GuildLogic.takeAllReward() 发「捐献进度奖励」邮件
        └─ 第 359 行：FriendLogic.refreshState() → UserManager.getUser(10000013) ← 无 canNull，直接 throw
        ↓
④ 异常冒泡到 HandlerLogicThread 的 catch
        ├─ transaction 不 commit（本次邮件的 Mongo 写入未落库）
        ├─ 第 443 行 setLoginTime(now) 根本没执行 → 库里的 loginTime 永远是旧日期
        ├─ 该线程 ThreadLocal 写缓存【不清理】→ 残留的邮件写入会被下一次成功请求一起提交（半提交）
        └─ removeUser + 从库重载 → 内存里的进度被回滚
        ↓
⑤ 下次登录：loginTime 仍是 10-18 → isOverTime=true → ③ 再来一遍 → 又一封同样的奖励邮件
        ↓
⑥ 玩家侧表现：邮箱里堆着多封一样的可领邮件 → 领一次得一份 → 金币/贡献翻倍 → 「什么都能买」
   进程重启 → 内存态清空、半提交的邮件复活/消失 → 「重启后奖励重复 / 东西不见了」
```

---

## 3. 四个缺陷（按修复优先级）

| # | 级别 | 位置 | 缺陷 |
|---|---|---|---|
| **D1** | **P0** | `logic/family/GuildLogic.java:77-123` `takeAllReward()` | 「补发前日未领取的祭祀奖」只按 `hadTakeReward` **过滤**，**发完不写回** `hadTakeReward`（只有手动领取 handler `FamilyGetFeteRewardRequestHandler` 才 add）。⇒ 每次每日刷新都把已达标的档位再发一遍。**这是重复发奖的直接来源。** |
| **D2** | **P0** | `logic/GlobalDataManaager.java:443` | `setLoginTime(now)` 写在 `checkNeedReFlush` **最后一行**，前面任一子步骤抛异常 → loginTime 永不推进 → 每日刷新退化为「每次登录都刷新」。同函数 431/434 行后还挂了 DefTraining/Blitz 重置，同样被跳过。 |
| **D3** | **P0** | `logic/friend/FriendLogic.java:709` | `UserManager.getUser(friendId)` 未用 `canNull=true` + 判空（`UserManager.java:292` 直接 throw）。删号后残留引用 = 定时炸弹。同类「跨玩家 getUser 不判空」应全量排查。 |
| **D4** | **P1** | `core/HandlerLogicThread.java:207-240` + `common/.../MongoBase.java:26` | 异常分支只做 `callback()`，**不清 ThreadLocal 写缓存**（`MongoUpdateCacheThreadLocal`）。失败请求已产生的 `$set` 会残留，被同线程下一次成功请求的 `lastUpdate()` 一起提交 = **半提交**。这解释了「事务失败的登录却真发了邮件」。 |
| **D5** | **P2** | `logic/player/PlayerLogic.java:1184-1208` `sendTimingMail()` | 去重靠 `playerManager.sysMailIds`，而它在同一失败事务里被回滚（实测该字段全服都是空数组）⇒ 定时福利邮件无实际幂等。 |

---

## 4. 影响面

| 项目 | 数值 |
|---|---|
| 直接受害（每次登录必报错） | 5 个账号：10000001 / 10000017 / 10000069 / 10000084 / 10000131 |
| 已确认重复（uid=10000017） | 11 封 ×（公会贡献 350 + 金币 45000），其中 3 份已领取 |
| 潜在可继续刷 | 剩余 8 封未领取，且每次登录还会再发 → **属活跃漏洞，需优先堵** |
| 角色存档缺失 | 40 个（248 账号 / 208 角色），明细前 15：10000013,15,34,46,102,103,144,145,153,156,168,169,178,179,185 |
| 日志可回溯窗口 | `/data/srvlog/` 约 3 天；`assets/log/jl_item|jl_logs|jl_blogs` ≥30 天（事后算金币差额要走这里） |

---

## 5. 修复方案

### P0-a　`GuildLogic.takeAllReward` 补发后必须落标记

在发邮件成功之后（或随邮件一起）把本次补发的档位写进 `hadTakeReward`：

```java
// logic/family/GuildLogic.java takeAllReward()
Set<Integer> objects = new HashSet<>(config.keySet());
objects.removeAll(user.getGuildMyInfo().getHadTakeReward());
List<Integer> granted = new ArrayList<>();
for (Integer missionId : objects) {
    ...
    if (sGuildSacrificeRewardConfig.getScore() > fete) continue;
    itemArrs.add(reward);
    granted.add(missionId);                 // ★ 新增
}
if (itemArrs.size() == 0) return;
... sendMail(...);
for (Integer id : granted) user.getGuildMyInfo().addHadTakeReward(id);   // ★ 新增
```

> 注意：`addHadTakeReward` 走 `updateString`，与发邮件同一次 commit，天然原子。

### P0-b　`checkNeedReFlush`：先推进 loginTime，再做事；子步骤互不连坐

```java
// 建议改成「先占位、后执行、单个子步骤 try/catch」
long prevLoginTime = user.getPlayerInfoManager().getLoginTime();
if (!TimeUtils.isOverTime(0, prevLoginTime)) { /* 仍需跑 DefTraining/Blitz 的日检查 */ }
else {
    user.getPlayerInfoManager().setLoginTime(TimeUtils.now());   // ★ 第一步就落库
    each(step -> { try { step.run(); } catch (Exception e) { LOGGER.error("dailyRefresh step fail", e); } });
}
```
核心原则：**幂等标记必须先于副作用**。哪怕后续某步失败，也不会把整天的奖励重发。

### P0-c　`FriendLogic.refreshState` 判空 + 清理脏引用

```java
User friendUser = UserManager.getUser(friendId, true);   // canNull=true
if (friendUser == null) {                                // 好友已被删号
    friendManager.removeGiveMap(friendId);               // 顺手清脏数据
    continue;
}
```
并把「跨玩家 `getUser(x)` 不判空」的调用点做一次全量扫描（删号脚本只删 `user`，ranks/giveMap/guild 都留残引）。

### P1-a　异常分支清理写缓存（消除半提交）

```java
// HandlerLogicThread catch 分支，在最前面加：
MongoUpdateCacheThreadLocal.clearCurrentThread();   // 需新增：requestMap/updateDataMap 全部丢弃
```
否则「失败请求的写入」会被下一次成功请求带上库，审计永远对不上账。

### P1-b　重启/停机时优雅 flush

`GameApplication.close()` 里补 `MongoUtil.getInstence().lastUpdate()`，并把 `MongoDataHandlerTask` 的队列排空，避免停机丢内存写入。

### P2　定时福利邮件改为服务端幂等键

`sendTimingMail` 用 `(uid, welfareId, 当日)` 作唯一键写 Redis `SETNX`（或独立集合），不依赖 `sysMailIds` 这种会被回滚的字段。

---

## 6. 数据修复（**需确认后执行**，当前未动）

```javascript
// ① 清掉 5 个玩家好友列表里对已删角色的引用（消除每次登录的异常）
db.user.updateMany({"friendManager.giveMap.10000013":{$exists:true}},
                   {$unset:{"friendManager.giveMap.10000013":""}});
db.user.updateMany({"friendManager.friends":10000013},
                   {$pull:{"friendManager.friends":10000013}});

// ② 回收重复的捐献奖励邮件（先查数再删；已领取的 3 封要按 jl_item 流水核账）
db.user.find({_id:10000017}).forEach(()=>{});
// 建议：保留最早 1 封未领取，其余 state!=3 的直接 $unset mailMap.<id>
//       已领取部分用扣减 itemManager 金币/公会贡献的方式回滚（金额需人工确认）

// ③ 修复 loginTime（可选：随 P0-b 上线后自然修复）
```

> ⚠️ 建议顺序：先上 P0 代码修复 → 再清脏引用 → 再核账回收 → 最后全量 `rank-audit` 体检。

---

## 7. 验证清单

1. 修后登录同一账号：日志应出现 1 次 `dailyRefresh`，之后同一自然日不再出现；`playerManager.loginTime` 每次登录刷新。
2. `grep -c "getUser null exception"` 应为 0（现每天 10+）。
3. `db.user.find({"mailManager.mailMap":{$exists:true}})` 里 head=25010100 的封数不再增长。
4. 手工制造「好友被删」场景：登录应正常返回 10600，不再回 10601 错误包。
5. 上线后 24h 复查：`jl_item` 流水里捐献奖励的发放次数 == 达标档位数（每人每天 ≤ 1 次）。

---

## 8. 与「账号消失」的关系

- 登录库 `x1_cn_test_login.user_info` **248 个账号全部还在**（含 10000013）。
- 游戏库 `m5_x1_game_10001.user` **只有 208 个角色**，缺 40 个。
- 即：**账号没丢，角色存档丢了**（玩家视角=「账号没了」，因为登录进去没有角色）。
- 10000013 正是这 40 个之一，且它的好友引用没清 → 变成全服 5 个人的「每日刷新毒种子」。
  这也和之前删号脚本的已知缺陷一致：**只删 `user`，不清 ranks / 好友 / 公会残引**。
- **10000013 = Mozart**（快照 `/root/incident_20261018/m13_user.json`，nickName=Mozart）。
  这次重复发奖就是 10-18 那次删号的**直接后遗症**：删号脚本没清 `friendManager.giveMap`。
  换言之，只要再删一个号而不清引用，同样的事故会立刻复现。
