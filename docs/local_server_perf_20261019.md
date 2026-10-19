# 本地测试服性能巡检（2026-10-19 18:10）

> 口径：只读巡检，未改任何配置/代码。样本 = 今日 `~/home/java/logs/gameserver.log`（21.2MB / 53,657 行）
> + `~/home/java/gameserver/assets/log/jl_logs/2026-10-19/`（22.9MB）+ jstat/jstack 实时快照。
> 测试规模：单机、2 个测试号（10000004/10000005）、当日重启 18 次。

## 一、结论速览

| # | 问题 | 量化证据 | 影响 | 等级 |
|---|---|---|---|---|
| P1 | GM 查一次用户就写 7MB 单行日志 | `Cmd_userinfo#23` 2 条 = **14.16MB = 全日志 67%** | 磁盘/编辑器卡死、排障不可读 | 🔴 高 |
| P2 | 每发一个包写 2 条 INFO | `MessageUtil#46+#81` = **14,244 行 = 26.7% 行数** | IO 线程同步写盘 | 🔴 高 |
| P3 | 控制台 + 文件**双写同一份日志** | stdout 21.2MB + corelog 22.9MB = **44MB/天**（1 个测试号） | 写放大 ×2，且 `%line` 每事件抓一次栈 | 🟠 中高 |
| P4 | User 文档 506KB，登录全量反序列化 | 单 doc **506,290B**；`playerManager.rechargeInfo.timeLimitMap` 一表 **504 条/149KB** | 冷登录 **473–1069ms**（热登录 2–7ms） | 🟠 中高 |
| P5 | 50 个 `h-*` 逻辑线程只用了 2 个 | jstack：**148 线程**，`h`×50，实际只 `h-4/h-5` 有请求 | ≈48MB 栈 + 调度器开销 | 🟡 中 |
| P6 | Metaspace 用满 97% | `MU/MC = 77595/79832KB(97.2%)`，日 FGC **3 次/0.373s** | 全 GC 抖动；无 `-XX:MetaspaceSize` | 🟡 中 |
| P7 | Mongo 连接池 idle 只有 1 秒 | `maxConnectionIdleTime = 1000`；8.4h 内 **193 次新建连接** | 每条空闲后首个请求带握手延迟 | 🟡 中 |
| P8 | `[ERROR]` 里塞 INFO 内容 | 359 条 ERROR 中 74+74 是 `HeroLogic#203/211 INFO:`、43 条 GM 回显 | error-log.log 失效，真错误被淹 | 🟡 中 |
| P9 | 商店权重表配成 0 | `StoreLogic#591 totalWeight can not 0` **462 次/天** | 商店刷不出货（数据问题，非性能） | 🟡 中 |

## 二、日志体积拆解（21.2MB 去哪了）

| logger | 字节 | 占比 | 说明 |
|---|---|---|---|
| `GmAbstract#23` / `Cmd_userinfo#23` | 14.16MB | **67%** | `gson.toJson(整个 User)`，单行 7.09MB × 2 |
| `MessageUtil#46` | 1.16MB | 5.5% | 每包一条 `wrappedBuffer uid=>…generatedMessage=>…` |
| `MessageUtil#81` | 0.93MB | 4.4% | 同一包的第二条 `sendbyte=>…megId=>…` |
| `SessionManager#97` | 0.90MB | 4.3% | 每收一包一条 `request=… commond =X` |
| `HandlerLogicThread#195` | 0.85MB | 4.0% | 每请求一条 `doWork->…useTime=` |
| `STableManager#201/#262/#406` | 0.57MB | 2.7% | 280 张表 × 18 次启动 + 每分钟 2 条缺文件检查 |
| `BaseHandler#59` | 0.24MB | 1.1% | 每请求 `JsonFormat.printToString(proto)` 全量入参 |

- 行数分布：`MessageUtil` 14,244 / `SessionManager#97` 7,269 / `HandlerLogicThread` 6,125 / `STableManager` 5,274。
- 峰值 **266 事件/秒**（全部出现在启动瞬间）；活跃 3,386 秒里均值 ≈ 15.7 事件/秒。
- 已做过的优化：`HandlerLogicThread` 的 `doWork … start` 已降为 DEBUG（源码注释留痕），本次复查只剩 `useTime` 那条 INFO。

## 三、启动 / 登录耗时拆解

**启动（18 次，均值）：** Spring `Started GameApplication` ≈ **5.0–5.8s** + 表加载 ≈ **2.2–2.9s**（280 表）→ **约 8s 可用**。

**首次登录（每次重启后第一条 LOGIN_REQUEST）：**

| 启动时刻 | 09:51 | 11:48 | 12:12 | 13:28 | 13:34 | 14:04 | 14:46 | 15:12 | 16:59 |
|---|---|---|---|---|---|---|---|---|---|
| useTime | 665ms | 701ms | 639ms | 913ms | 730ms | 781ms | **1069ms** | 899ms | 1036ms |

对照组：`12:36` 那次是 **7ms**（用户已在内存，非冷加载）⇒ 800ms 全部落在「Mongo 取 doc + 构对象」。

**User 文档构成（uid 10000004，506,290B / 35 个 manager）：**

| 字段 | 体积 | 明细 |
|---|---|---|
| `playerManager` | 206.4KB | 其中 `rechargeInfo` 201.4KB → `timeLimitMap` **149.2KB（504 条，全量不清理）** + `perpetualMap` 36KB |
| `userMissionManager` | 170.1KB | 4 个 ×191 项的累计容器（各 6–8KB） |
| `activityManager` | 71.6KB | `activityMissionMap` 45 个活动 = 69.1KB |
| `storeManager` / `heroManager` | 15.3 / 11.8KB | — |

## 四、JVM / 运行时

- 启动参数：`-Xms256m -Xmx1280m`，**无任何 GC / Metaspace 参数**。
- `jstat -gc`（运行 79min）：`YGC 55 / 0.735s`、`FGC 3 / 0.373s`、`OU 165MB / OC 314MB`、`MU 77.6MB / MC 78MB (97.2%)`。
- 堆committed 453MB / 1280MB上限 ⇒ 堆不是瓶颈，**Metaspace 才是**（3 次 FGC 与扩容同源）。
- 线程 148：`h`×50（仅 2 个在用）、`netty`×15、`ScheduleThreadPool-test-thread`×8、`logback`×8、`pool-*`。
- Mongo 实际只 10 个集合；`itemLog` 1210 条 / 166KB。

## 五、建议动作（按性价比排序）

### A. 零风险、立刻见效（改配置/改 1 行日志）

1. **删掉 GM 全量 dump**：`kefu/Cmd_userinfo.java:23`、`kefu/Cmd_oneuserinfo.java:23` 的 `gson.toJson(user)` 改为只打 `id/level/nickName`，或改 `LOGGER.debug`。→ 日志 **-67%**。
2. **MessageUtil 双条改一条 + 降 DEBUG**：`util/MessageUtil.java:46`、`:85`。→ 行数 **-27%**。
3. **日志双写改单写**：`logback-boot.xml` 的 `<root>` 里去掉 `console`（stdout 那份由 launchd 再落盘 = 完全重复），同时把重复挂载的第二个 `<appender-ref ref="ERROR"/>` 删掉。→ 写放大 **减半**。
4. **去掉 `%line`**：pattern 里 `%logger{0}#%line` 的 `%line` 每个事件都要抓一次调用栈（logback `LineOfCallerConverter`）。保留 `%logger{0}` 足够定位类。
5. **`SessionManager#97` / `HandlerLogicThread#195(useTime)` / `BaseHandler#59(JsonFormat)` 降 DEBUG**，保留 ERROR/WARN。

### B. 低成本、针对冷登录（P4）

6. **启动后异步预热测试号**：boot 完成起一个线程预先 `findById` 把 `10000004/10000005` 载入内存，首次真人登录就从 800ms 降到个位数毫秒。
7. **清理 `timeLimitMap`**：限购记录只保留本期仍有 `endTime` 或 `lastBuyTime` 的记录，504 条可压到个位数。文档 506KB → 约 350KB。
8. **jvm 参数**加 `-XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m`（顺带 `-XX:+UseG1GC -XX:MaxGCPauseMillis=100`），消掉 metaspace 触发的 FGC。

### C. 配置修正（P5/P7）

9. `server.threadNum = 50` → **4**（本机只 2 个号，按 uid 取模永远只落 2 个线程）。
10. `mongodb.options.maxConnectionIdleTime = 1000` → **60000**；`spring.redis.timeout = 0` → **2000**（0 = 永不超时，Redis 挂时会挂住调用线程——今天 error-log 里 11 次 `JedisConnectionException` 就是这么来的）。
11. `netty` 的 `TCP_NODELAY`/`SO_LINGER` 报警（30 条 WARN）说明这两个 option 设在了 **ServerBootstrap（父通道）** 上，应设到 `childOption`。

### D. 数据/正确性（顺手记一下）

12. `StoreLogic#591 totalWeight=0` ×462：`SStoreConfig` 里该 `storeId+sort` 在当前等级区间无权重，需查表。
13. `11:41`、`11:47` 两次启动丢了 4 张表（`TrialSetting / InvestigateConfig / GuildSetting / GeneralLevelConfig`）——即 `SysUtil.class` 补丁丢失的老坑，已记录在 `REF-local-server.md`。
14. `error-log.log` 里混入 `重新登录 new = …`、`getAllTodayLike strings:[]` 等 INFO 级内容，建议这批 logger 降级，让 ERROR 文件只留真错误。

## 六、不做的事

- 堆/GC 不是瓶颈（FGC 0.37s/79min），**不要**动 `-Xmx`。
- 日志绝对吞吐也不是瓶颈（峰值 266/s、均值 15/s）；优化日志的目的是**降排障成本 + 消掉双写/栈抓取的全链路开销**，别指望它能拉低请求耗时。

---

# 第一批执行记录（2026-10-19 18:45 完成）

提交：`d95748c7 perf(log): 日志降噪第一批，单机日增 44MB -> 目标 <2MB`（已 push 到 `origin/x1-tag-1.2.2`）
部署：`javac` 单类编译 → `zip -u` 热补丁进 `gameSrv-1.0.0.jar`（未整包重建，`lib/` 与 `SysUtil` 补丁未动）
备份：`~/home/java/gameserver/gameSrv-1.0.0.jar.bak-20261019-logperf`
重启：`start-local.sh restart gs`，端口 9s 起来，280 张表 + 敏感词 385374 全部加载正常

## 改了 9 个文件

| 文件 | 改动 |
|---|---|
| `kefu/Cmd_userinfo.java` / `Cmd_oneuserinfo.java` | 默认只打 `uid/level/nick`；全量 JSON 降 DEBUG 且不再预生成 |
| `util/MessageUtil.java` | 每包 2 条 INFO → 1 条 DEBUG（`isDebugEnabled` 前置） |
| `handler/BaseHandler.java` | 每请求 `JsonFormat.printToString(proto)` 降 DEBUG |
| `core/HandlerLogicThread.java` | `useTime` 的 INFO 降 DEBUG |
| `network/server/SessionManager.java` | 收包/心跳/ack 接收检查降 DEBUG；`重新登录`/`offLine` ERROR→INFO；收不到心跳 ERROR→WARN |
| `logic/championship/ChampionshipLogic.java` | `getLogger(HeroLogic.class)` 误用修正；两条打正常返回值的 `error` 降 DEBUG |
| `handler/GameGM/GMRequestHandler.java` | GM 命令回显 ERROR→INFO |
| `deploy-overlay/.../logback-boot.xml` | root 去掉 `file_console`、`ERROR` 去重；pattern 去掉 `%line` |

## 实测对比

| 指标 | 改造前 | 改造后 |
|---|---|---|
| `wrappedBuffer` / `doWork` / `getmessage` / `request=..commond` / `ackIndication` / 心跳检查 | 30,913 行/天 | **0** |
| 一次 GM `oneuserinfo` 的日志量 | 7,090,000 B | **119 B** |
| `corelog0.log`（双写副本） | 23.2MB，持续增长 | **停止增长**（23,227,346B 冻结） |
| 重启后 8 分钟 ERROR | — | **0**（原来 `重新登录`/`offLine`/`getAllTodayLike` 打 ERROR） |
| 日志格式 | `Logger#123 - INFO:` | `Logger - INFO:`（不再每次抓栈） |

## 还剩的（第二批候选）

- `RankingRewardLogic#153 updateDataTask`、`MinuteTask start/end`、`Poster bbb`、`MapLogic OnlineUserReportTask`、`GuildFightLogic progress`：纯脚手架，约 2,500 行/天。
- `netty` 的 `TCP_NODELAY`/`SO_LINGER` 告警：option 设在父通道，应移到 `childOption`。
- 冷登录 800ms / `timeLimitMap` 504 条 / Metaspace 97% / `threadNum=50` / mongo idle 1s：见第一节 P4–P7，属第二批。

---

# 第二批执行记录（2026-10-19 19:25 完成）

提交：`a2398d93 perf(server): 日志脚手架清零 + 线程/连接/通道三项运行时参数纠偏`
　　　`132eb035 perf(reconnect): 重连刷新四段耗时埋点`（均已 push，领先 0）

## 1. 日志脚手架：8 类全部归零

| 日志 | 位置 | 频率 | 处理 |
|---|---|---|---|
| `MinuteTask start/end/003/004/005` | `thread/task/MinuteTask` | 5 行/分钟 | INFO→DEBUG |
| `------bbb/ccc 进入00x------` | `logic/activity/event/Poster` | 每事件分发 | 整段删除 |
| `updateDataTask uid..type..value` | `RankingRewardLogic#153` | 每次排行变更 | INFO→DEBUG |
| `OnlineUserReportTask start !!!` | `thread/task/OnlineUserReportTask#30` | 1 行/分钟 | INFO→DEBUG |
| `车迟斗法progress=` | `GuildFightLogic#1239` | 1 行/分钟 | INFO→DEBUG |

顺带修掉一个真缺陷：`MinuteTask` 里 **19 处** `LOGGER.error("Exception::N=>{}", e.toString())`
把异常对象转成字符串塞进 `{}`，堆栈全丢；改成 `LOGGER.error("Exception::N", e)`。

稳态实测（重启后 60s 窗口）：**13 行 / 1.4 KB**，其中已无任何上述模式。

## 2. 运行时参数

| 项 | 前 | 后 | 依据 |
|---|---|---|---|
| `server.threadNum` | 50 | **8** | 实测 `h` 线程族 50 个只用了 2 个；改后线程总数 **148 → 72** |
| `spring.redis.timeout` | 0（永不超时） | **2000** | 今日 error-log 11 次 `JedisConnectionException`，业务线程硬挂 |
| `maxConnectionIdleTime` | 1000（1s 回收） | **60000** | 8.4 小时重建 193 次连接 |
| `-XX:MaxMetaspaceSize` | 未设（committed 78MB 打到 97.2%） | **256m**（`MetaspaceSize=128m`） | `jinfo` 复核已生效 |
| netty 通道选项 | `.option()`（父通道） | **`.childOption()`** | 每次启动刷 2 条 `Unknown channel option 'TCP_NODELAY'/'SO_LINGER'`，历史 36 条 ⇒ 配置一直没生效 |
| netty bossGroup | 0（默认 CPU×2） | **1** | accept 单线程足够 |

netty 那组里 `SO_LINGER=0` **没有跟着搬**：在服务端子通道上会让 close 直接发 RST、可能丢最后一包，
改为默认优雅关闭；另补 `SO_KEEPALIVE`、父通道 `SO_BACKLOG=1024`。

## 3. 登录链路

**修掉重复调用**：`LoginRequestHandler` 里 `if (split>=2) userLogin(...)`、`else {}` 空实现，
紧接着 127 行又**无条件**调一次 `userLogin` ⇒ 每次登录执行两遍。补成 if/else 各一次。

**冷登录 800ms 重新定位**（原结论「506KB 文档」需要修正）：

| 测量 | 结果 |
|---|---|
| mongo shell `findOne({_id:10000004})` | **1ms**（506,078B） |
| 冷路径埋点 `login-userLoad` | 已加，等下一次真正冷登录 |

即 Mongo 读不是瓶颈，慢在 Java 侧反序列化或登录后的刷新链。新增常驻埋点
`login-userLoad uid= cost=` 用于长期盯住文档膨胀。

**重连 800ms 已锁定区间**：19:18:38.680 `reconnect,the maxid=27` → 19:18:39.454
第一条 indication，中间 **774ms 全静默**。该区间只有四步（activityMissionProgress /
`StoreLogic.checkStoreRefresh` / `GlobalDataManaager.checkNeedReFlush` / `ItemUtil.getAllItem`），
已加 `reconnect-flush uid= heart= activity= store= globalFlush= pack=` 分段埋点。

## 4. timeLimitMap 504 条：判定「不能删」

一开始按「过期未购记录可清」设想，dry-run 后 **del=0**，重新核对分布：

| 状态 | 条数 | 说明 |
|---|---|---|
| closed + endTime=0 + **refreshTime 已设** | **446** | 周期性礼包，refreshTime 是刷新锚点 |
| closed + 全零 | 32 | 真正空白 |
| open + endTime=0 + refreshTime 已设 | 20 | 已开启的周期礼包 |
| open + endTime 在未来 | 5 | 正常有效 |
| 其他 | 1 | — |

关键证据：`refreshWelfareState` / `checkchargeType` 在**整个 serverlogic 没有调用点**（死代码），
而它们才是唯一的重建路径 ⇒ 删掉记录不会被任何逻辑重建，礼包永久消失、刷新周期丢失。

`timeLimitMap` 平均 306B/条、共 149KB，是「每个限时礼包一条状态」的设计必然，第二批不动。
真要缩，得把 `rechargeInfo` 从 User 主文档拆出去做懒加载，属架构级改动，另立评估。

## 5. 复盘：两处当初的判断被数据推翻

1. 「冷登录慢 = 506KB 文档」→ Mongo findOne 实测 1ms，文档大小不是 IO 瓶颈。
2. 「504 条限购记录是垃圾数据」→ 446 条带 refreshTime 的有效状态，且无重建路径，不能删。

第二批真正的收益落在「线程数、Metaspace、日志、通道选项」四项，而非数据裁剪。

---

# 第三批：在线期日志 + 冷登录/重连 800ms 定因（2026-10-19 20:05）

提交：`867902c7 perf(log): 在线期日志降噪第三批`（已 push，领先 0）

## 1. 在线期热路径日志（前两批只覆盖空载）

实测一次主线战斗（19:31–20:00 窗口 257 行/31KB）的构成，前七名全是脚手架：

| 日志 | 频率 | 处理 |
|---|---|---|
| `ForceCurrRank` onEvent / transport / eventList.add / changeId | 每次排行事件 4 条 | INFO→DEBUG |
| `RankingRewardLogic#120 updateRankingData uid..type..value` | 一次战斗 ~30 条 | INFO→DEBUG |
| `MessageUtil#199 ----indicationIndex值` | 每个 indication 1 条 | INFO→DEBUG |
| `BuyGoodsLogic#2051 sendGiftGooodsIndication` | 每次礼包变更 1 条 | INFO→DEBUG |
| `GlobleSystemLogic#329/#344 serverId=` | 每次查全局配置 1 条 | INFO→DEBUG |
| `ArenaWorldLogic#147 跨服天梯解锁参数` | 每次进界面 1 条 | INFO→DEBUG |
| `AdjutantFightMissionType#84` | 每次任务累计 1 条 | INFO→DEBUG + 修 `{0}/{1}/{2}` 占位符 |

⚠️ 注意 `RankingRewardLogic` 有两个不同的日志点：`#153 updateDataTask`（第二批已改）和
`#120 updateRankingData`（本次才改）。别以为改过就没了。

## 2. 重连/冷登录 800ms —— 已定到 `getUserInMem`

重启后客户端自动重连，新埋点直接给出分段：

```
reconnect-flush uid=10000004 heart=748ms activity=8ms store=1ms globalFlush=20ms pack=40ms
```

合计 ≈ 817ms，和之前观测到的「774ms 静默」完全吻合。而 `heart` 段 = `sendHeartBeat` +
`UserManager.getUserInMem(uid)`，后者在内存没命中时会走 `getUser(uid, true)` **从 Mongo 整份加载**。
即：**慢的一直是「冷加载」，不是刷新链，也不是背包组装**（后四段合计 69ms）。

冷加载本身的构成（实测）：

| 环节 | 耗时 | 证据 |
|---|---|---|
| Mongo 裸读 + BSON 解码（同一份 506KB 文档，warm） | **11–17ms** | 独立程序 4 次采样 |
| Spring Data 把文档映射成 User（35 个 manager） | **≈570ms** | `login-userLoad cost=583ms` − 裸读 |
| 648 个礼包的 `MongoRechargeConverter` | **10ms** | 648 条实测（3 次预热后） |

## 3. 两次判断被数据推翻（记录在此，避免以后再走一遍）

1. **「礼包转换是 583ms 的主因」——错。**
   `MongoRechargeConverter` 每个礼包都做 `new Gson().toJson()` → `JSON.parseObject()` 两轮反射，
   看着很像瓶颈；实测 648 个礼包合计只要 **10ms**。改成直接字段装载（`loadFromDb`）后字段 0 差异，
   但反而 31ms（fastjson 用 ASM 生成 codec，本来就快），**已整份回滚**，不进主干。

2. **「读库时 setter 会把脏字段记进更新缓存」——未证实。**
   `AbstractWelfareBag` 每个 setter 都调 `updateString` → `MongoUpdateCacheThreadLocal`，
   理论上读 648 个礼包会写近万条假更新；但库里查 `_id=0` 文档 0 条、含 `null.modId` 字段 0 条，
   说明 flush 前被过滤/清空了。**没有脏写，不构成线上问题。**

## 4. 结论与下一步

- 冷加载 583ms 里 **570ms 是 Spring Data 的 POJO 映射**（35 个 manager、506KB 文档、数千个嵌套对象），
  不是 IO、不是礼包、不是业务逻辑。想再降只能：
  - (a) 把 `rechargeInfo` / `userMissionManager` / `activityManager`（合计 ~450KB）拆成独立集合懒加载
        —— 架构级改动，所有访问点都要改，回归风险最高；
  - (b) 启动后后台预热最近活跃玩家 —— 只能缓解「重启后首次」，且 User 对象常驻内存，
        玩家一多就会把 1.28GB 堆吃满，**不适合放开**；
  - (c) 不动，接受「每次重启后每人首次 0.6~0.8s」。
- 现网建议：先按 (c) 保留，等有真实并发诉求再评估 (a)。
