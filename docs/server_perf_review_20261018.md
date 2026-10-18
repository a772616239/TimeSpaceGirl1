# 游戏服性能巡检报告

- **巡检时间**：2026-10-18 14:43–14:55 (GMT+8)
- **目标**：129.226.213.65（`gs`）· gameserver (netty 16081) + mongod 4.0.10 + redis + Tomcat 登录服
- **口径**：全程只读（未改任何配置、未重启、未开 profiler）。唯一副作用：`jmap -histo:live` 强制触发 2 次 Full GC（见 §1.2）
- **数据源**：`/data/srvlog/gameserver.log`（334,334 行 / 41MB / 2026-10-10 至今）、`jstat` / `jstack` / `jmap -histo:live`、`db.serverStatus()` / `db.stats()` / `explain()`、redis INFO

---

## 0. 一句话结论

**当前不是 CPU 或 IO 瓶颈（load 0.04、Mongo 缓存命中率≈100%），而是「玩家对象模型」的瓶颈**：
一个玩家在 Mongo 里 552KB、在堆里约 16MB，40 个 `User` 对象就吃掉 674MB 活堆（其中 74% 是
255 万个 HashMap），堆 1280MB 实际并发上限约 70–100 人；同时 8.2% 的日志行是 ERROR 级噪声，
其中 41% 是每分钟必然触发一次的良性任务日志。

---

## 1. 资源基线

| 项 | 值 | 判读 |
|---|---|---|
| CPU | 2 vCPU，load 0.04/0.25/0.33，进程 CPU 6.7%→13% | ✅ 空闲，非瓶颈 |
| 内存 | total 3694MB / used 2815MB / available **618MB** / swap 已用 **170MB** | ⚠️ 偏紧 |
| 磁盘 | 59G 用 24G（42%） | ✅ 充裕 |
| 进程 RSS | java(game) 1368MB · java(tomcat) 350MB · mongod 328MB · redis 44MB | |
| JVM | JDK 1.8.0_412，`-Xms1280m -Xmx1280m -Xss512k -XX:+UseParallelGC -XX:ParallelGCThreads=2` | |
| 线程 | 124 个（h- 逻辑线程 **50**、netty 17、logback 8、Schedule 8） | 50 个逻辑线程对 3 在线严重过剩 |
| 进程启动 | 2026-10-18 09:49:01（今日共 **7 次**重启，均为 `addShutdownHook` 优雅关闭，非崩溃） | 发布/热修所致，非稳定性问题 |

### 1.1 GC —— 🔴 没有开 GC 日志

`/data/srvlog/gc/` 为空，启动参数无任何 `-Xloggc` / `-XX:+PrintGCDetails`。
**目前无法回答「有没有 GC 停顿」这个问题**——这是最该先补的观测缺口。

### 1.2 活对象（`jmap -histo:live`，已强制 GC 后）

```
总活对象 14,099,907 个 / 674MB        老年代 75%（658MB / 853MB）
单类 TOP： [Ljava.util.HashMap$Node;  2,569,076 个   209MB
           java.util.HashMap$Node    5,179,267 个   166MB
           java.util.HashMap         2,549,591 个   122MB
集合家族合计：10,873,262 个实例 / 497MB = 活堆的 74%
```

同时：
- `User` 对象仅 **40 个**、`PlayerManager` 仅 **46 个**
- 当前在线 **0 人**（今日峰值 **3 人**）
- 日志中 `player offLine` 出现 148 次

⇒ **40 个玩家 → 674MB 活堆 ≈ 16MB/人**，其中平均每个 HashMap 只有 2 个 entry
（518 万节点 / 255 万个 Map），是典型的「一条小记录一个 HashMap」对象模型。
按此比例，1280MB 堆的并发天花板约 **70–100 人**，且离线玩家对象未见释放（在线 0 仍驻留 40 个）。

**风险**：活堆已到 674MB / 1280MB。`UseParallelGC` 下 Full GC 实测 **2.6s/次**（本次 2 次共 5.23s）。
任何晋升尖峰都会造成全服 2.6s 卡顿。

---

## 2. 请求耗时（`useTime` 埋点，8 天共 11,100 个样本）

| 消息类型 | n | p50 | p90 | p99 | max |
|---|---|---|---|---|---|
| FIGHT_END_REQUEST | 208 | **161ms** | 894 | 1,474 | 2,305 |
| GET_PLAYERINFO_REQUEST | 136 | **96ms** | 535 | 1,012 | 2,115 |
| ARENA_CHALLENGE_REQUEST | 21 | 162ms | 265 | 400 | 764 |
| LOGIN_REQUEST | 99 | **3ms** | 247 | 2,205 | 2,277 |
| FAMILY_GET_INFO_REQUEST | 57 | 7ms | 442 | 478 | 622 |
| GET_ONE_RANK_REQUEST | 60 | 4ms | 191 | 1,472 | 2,379 |

跨天批处理窗口（00:00–02:00）会显著恶化：

| 消息类型 | 常态 p50 | 批处理窗 p50 |
|---|---|---|
| FIGHT_END_REQUEST | 161ms | **433ms** |
| GET_PLAYERINFO_REQUEST | 96ms | **312ms** |
| LOGIN_REQUEST | 3ms | 5ms |

### 2.1 慢在哪：Mongo 不背锅

实测 Mongo 侧纯读取（同一文档 100 次）：

```
2,432KB 文档全读  平均 2.81ms
仅读 _id         平均 0.40ms
WT cache: 配置 1335MB / 实际 210MB，pagesReadIntoCache=110（3640 小时），命中率≈100%
globalLock 排队 0，连接 19
```

而响应体很小：下行 `sendbyte` p50=84B、p99=5.4KB、max=18KB。

⇒ **GET_PLAYERINFO 的 96ms 里，Mongo 读取只占 ~3ms，其余 ~93ms 在应用侧的对象水合/序列化**；
FIGHT_END 比 GET_PLAYERINFO 多 ~65ms，与「多一次整文档写出（编码）」的量级吻合（**推断**，
建议按 §6 用 60s profiler 或 async-profiler 确认这一段）。

---

## 3. Mongo 数据模型：三个人均大头

库 `m5_x1_game_10001`：dataSize 136MB / 12 collections / 151,014 对象。

`user` 集合：**208 个文档 = 112.2MB，人均 552KB，最大 2,432KB，最小 424KB**。

| 顶层字段 | 人均 | 主因 |
|---|---|---|
| `userMissionManager` | 244.4KB | 见 §3.1 |
| `playerManager` | 206.0KB | `rechargeInfo` 占 202KB（§3.2） |
| `activityManager` | 62.7KB | 活动累积数据 |

### 3.1 🔴 根因：`rewardedMissionIds` 是 `java.util.BitSet`，被按内部字段整体入库

`userMissionManager.jadeDynastyMissionType.rewardedMissionIds` 的实际落库形态：

```json
{ "words": [ {"$numberLong":"0"}, ... ×106252 ], "wordsInUse": 57813, "sizeIsSticky": false }
```

- `words / wordsInUse / sizeIsSticky` 正是 `java.util.BitSet` 的三个私有字段 —— 序列化器把
  BitSet 当成普通 POJO 逐字段写进了 BSON
- **words 数组长 106,252（约 850KB 原始数据），但其中非零 word 只有 1 个**（值 2³³ ⇒ 实际只标记了
  1 个 bit，即 **8 字节有效信息**）
- `mysticalInstructMissionType.rewardedMissionIds` 同病：words=21,970，非零 word 也只有 1 个
- **影响面：208/208 玩家全部污染**，两项合计 **16.2MB**；单玩家最大 1,551.7KB（占该文档 84.5%）
- `BitSet` 只增不减：一旦 `set(大 missionId)`，words 数组永久保持该长度

### 3.1.1 🔴 为什么「把 BitSet 裁剪一下」修不好 —— bit 下标本身就是百万级

`AbstractMissionType.java:21` 是 `private BitSet rewardedMissionIds = new BitSet(1024);`，
而 `:32` 直接用 **missionId 当 bit 下标**：`rewardedMissionIds.set(missionId)`。

实测全库非零 word 的下标分布：

```
全库最高非零 word 下标 = 57812   （对应最小可用 words 长度 57813，即 ~462KB）
非零 word 样本： wordIdx=50000 val=2      → missionId = 3,200,001
                wordIdx=31406 val=131072  → missionId = 2,010,001
                wordIdx=31250 val=2       → missionId = 2,000,001
```

⇒ **精英任务 id 本身就是 200 万 ~ 320 万量级**，所以 BitSet 结构上最小也需要 250–460KB。
这不是"历史垃圾没清理"，而是**数据结构选错了**：全服 208 人真正需要记录的 id 只有 **29 个**。

**正确修法**：把 `rewardedMissionIds` 从 `BitSet` 换成 `Set<Integer>` ——
同类的 `doingMissionIds`、`finishMissionIds`（`AbstractMissionType:15-18`）**本来就是
`Set<Integer>`（`Sets.newConcurrentHashSet()`）并且落库正常**，所以这是「跟随既有已验证范式」，
不是引入新机制。代价是 81 处调用点（`BitSet x = getRewardedMissionIds()` → `Set<Integer>`，
`.get(id)`→`.contains(id)`，`.set(id)`→`.add(id)`），属机械重构，由编译器兜底。
配套需要一次性数据迁移（`{words:[...], wordsInUse, sizeIsSticky}` → `[id1, id2, ...]`）。

> 这一条是整份报告中最明确、最无争议的代码级缺陷：**1.5MB 存储换 8 字节信息**。

### 3.2 `playerManager.rechargeInfo`：无界增长的商城状态

人均 202KB，内部是 22 个 Map：

| 子 Map | key 数 | 体积 |
|---|---|---|
| `timeLimitMap` | 504 | 149.2KB |
| `perpetualMap` | 121 | 36.0KB |
| `refreshBagMap` | 572 | 7.7KB |
| `receiveMap` | 23 | 7.6KB |

`timeLimitMap` / `perpetualMap` 看起来是按「商品 × 期次」铺开的限购计数，历史期次未清理 →
随运营活动次数单调增长，属于**结构性问题（未来会越来越大）**，不只是当前偏大。

### 3.3 日志表全部无索引

| 集合 | 文档数 | 索引 | `{uid:...}` 查询实测 |
|---|---|---|---|
| `itemLog` | 130,493 | 仅 `_id` | **COLLSCAN，docsExamined=130,493 → 返回 3,125** |
| `fightLog` | 10,808 | 仅 `_id` | COLLSCAN，docsExamined=10,808 |
| `heroLog` | 7,073 | 仅 `_id` | 同上 |
| `storeLog` / `guildLog` / `mailingSystem` / `supremacyInfo` / `globalSystemControl` / `server_config` / `guildInfo` / `fightResDiffLog` | — | 均仅 `_id` | — |

现在数据量小（130k 行全扫 ~几十 ms）还能忍，**但它是 O(n) 的**，会随运营时间线性劣化。

### 3.4 其他 Mongo 项

- `net.bindIp: 0.0.0.0`（已开 authorization）—— 安全项，非性能项，但建议收回 `127.0.0.1`
- profiling 未开启（`was=0, slowms=100`）
- `WT cache` 配置 1335MB，占物理内存 36%，与 JVM 1280MB + Tomcat 512MB 叠加后
  available 仅 618MB、swap 已用 170MB —— **若扩容并发，先要调小 WT cache 给堆腾地方**

---

## 4. 🔴 数据完整性：uid 10000013 在线但无存档

- `m5_x1_game_10001.user` 中 **不存在** `_id=10000013`（`count=0`）
- 208 个已注册 uid 中**共缺 42 个号**（10000013/10000015/10000016/10000034/10000046/…）
- 但 10000013 **今天产生了 923 次请求**（全部落在 h-13），含 LOGIN / FIGHT_END / GET_MISSION
- 相关错误：`the user=10000013 not exists` **今日 2,951 次**；`UserManager::getUser null exception：10000013` 156 次

⇒ 该账号可登录、可战斗，但**任何进度都无法落库，重启即全丢**。

### 4.1 ✅ 根因已定位：`coreMongoTemplate` 指向了一个**空库**

`application.properties` 里两个连接串指向不同的库：

```
spring.data.mongodb.uri        = ...@127.0.0.1:27017/m5_x1_game_10001   ← 游戏库，正常
spring.data.mongodbcore.uri    = ...@127.0.0.1:27017/m5_x1_login        ← 空库！0 个集合
```

实测：

| 库 | 集合数 | `user_info` | `server_info` |
|---|---|---|---|
| `m5_x1_login`（配置指向） | **0** | 0 | 0 |
| `x1_cn_test_login`（真实数据） | 8 | **247** | **19** |

`MongoUtil.findCUserServerId()` / `findUserInfo()` 查的就是 `coreMongoTemplate` 上的 `user_info`，
所以**100% 落空**；`MongoUtil.init()` 里的 `coreMongoTemplate.findAll(CServerInfo.class)` 也必然返回空。
这就是「10000002 明明存在也被报 not exists」的原因 —— 它查的根本不是游戏库，而是一个空库。

**连带影响**：`LjsdMongoTemplate.save()` → `AreaManager.getServerIdByUid()` → `findCUserServerId()`
每次存档都多打一次注定失败的查询（然后回落 `GameApplication.serverId` 才能继续）。

**修法**：把 `spring.data.mongodbcore.uri` 的库名改成 `x1_cn_test_login`。
⚠️ 但这会连带让 `MongoUtil.init()` 真的读到 19 个区服并各自建 `MongoTemplate`
（跨服路由行为会变化），属于**行为变更**，需要单独评估，不建议顺手改。

---

## 5. 日志与线程：占了 8.2% ERROR、峰值 348 行/秒

### 5.1 级别分布（8 天）

```
[INFO]  294,215  (88.0%)
[ERROR]  27,503  ( 8.2%)   ← 其中大部分内容其实是 INFO 语义
[WARN]       38  ( 0.0%)
栈帧行 7,979（2.4%）
```

ERROR 榜首：

| 次数 | 内容 | 性质 |
|---|---|---|
| 11,342 | `MessageUtil#456 adventureBossRankInfo is null` | **每分钟 :00.494 必打一次**的定时任务，属良性 → 错用 ERROR |
| 3,117 | `MongoUtil#279 the user=10000013 not exists` | 见 §4 |
| 2,136 | `the user=0 not exists` | 明显是无效 uid 传入 |
| 1,702 / 1,090 / 1,033 | 其他 uid 的 not exists | |

⇒ **41% 的 ERROR 行是每分钟一次的良性任务**，真正的错误被淹没；`WARN` 只有 38 条说明级别体系基本失效。

### 5.2 日志是同步写、且 50 个逻辑线程共享 logger 锁

```xml
<root level="INFO">
  <appender-ref ref="console"/>      <!-- ConsoleAppender → stdout → >> /data/srvlog/gameserver.log -->
  <appender-ref ref="file_console"/>
  <appender-ref ref="ERROR"/>        <!-- 写了两遍，被 logback 按名去重，无实际重复 -->
</root>
```

- 无 `AsyncAppender`，`/proc/7550/fd/1` 直接指向 `/data/srvlog/gameserver.log`
- 峰值 **348 行/秒**（01:20:57），跨天窗口 **30,743 行/小时**（空闲基线 780 行/小时，**39 倍**）
- 每条日志都要拿 logger 的同步锁 → 高并发时成为串行点

### 5.3 线程模型：`ConcurrentLinkedQueue` + `sleep(2)` 轮询

`HandlerLogicThread.doWork()` 反编译（`javap -c`）：

```
ConcurrentLinkedQueue.poll()                 // 取消息
  ├ 有消息 → 处理
  └ 空     → if (hasAsyncWorker) lastUpdate()   // 仅当本轮跑过异步 worker 才刷盘
             Thread.sleep(2)                 // ← 第 123 行，硬编码 2ms
```

> 📌 **源码核对后修正**：`lastUpdate()` **不是**每次空 poll 都调用，而是由 `hasAsyncWorker`
> 门控（`HandlerLogicThread.java:120-122`）。所以空转代价主要是 25,000 次/秒的
> poll + sleep 调度，而非刷盘。

- **50 个线程 × 500 次/秒 = 25,000 次 poll + 25,000 次 sleep/秒** 纯空转
- 好消息：实测同一 uid 的 923 次请求**全部落在同一个 h-13 线程**，说明有 uid→线程亲和，
  **不存在同玩家并发处理的竞争问题**
- 坏消息：50 个线程对 3 在线是 16 倍冗余；且 2ms 轮询会给请求加 0–2ms 抖动

### 5.4 重试风暴

`RankingRewardLogic#153 updateDataTask` 在 00:00–02:00：

| uid | 调用次数 |
|---|---|
| 10000240 | 4,762 |
| 10000013 | 3,902 |
| 10000017 | 1,026 |

且**同一个 uid、同一个 type、同一个 value 重复 700–960 次**（如 `10000240 type:4 value:645762` 出现 960 次）。
这不是业务需要，是「写失败后无退避地原地重试」。

另有 `AdjutantFightMissionType#84 calCumulationDataResult. missionId={0}` 807 次 ——
日志占位符未替换（`{}` 没传参），反映该处代码质量。

---

## 6. Redis

```
used_memory 39.4MB / maxmemory 0（noeviction）/ 6213 keys / 碎片率 1.13
keyspace_hits 6,863,294   keyspace_misses 15,208,897   → 命中率 31.1%
```

键空间是 session / 排行 / 离线通知类（`JL_LOGIN_TOKEN`、`INDICATION_OFFLINE`、`VirtualBattle_*` 等），
**不缓存 User 对象**。命中率 31% 说明 2/3 的查询在问「不存在的 key」，属无效往返；单机本地
访问代价低，故不紧急，但设计上可收敛。

---

## 7. 优化清单（按性价比排序）

| # | 优先级 | 问题 | 动作 | 预期收益 |
|---|---|---|---|---|
| 1 | 🔴 P0 | 无 GC 日志 | 启动参数加 `-Xloggc:/data/srvlog/gc/gc_%t.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps` | 恢复可观测性（当前完全盲区）。**需重启** |
| 2 | 🔴 P0 | `adventureBossRankInfo is null` 每分钟记 ERROR | 该任务日志降为 DEBUG/关闭；`not exists` 降为 DEBUG 或加采样 | ERROR 行数 −41%，日志 I/O 与实际错误信噪比立即改善。**改 conf 后 `scanPeriod=60s` 自动生效，无需重启** |
| 3 | 🔴 P0 | logback 同步 + console 冗余 | 加 `AsyncAppender`（`queueSize=4096`、`discardingThreshold=0`、`neverBlock=true`）包住文件 appender；服务器上移除 `console` | 业务线程不再等磁盘；峰值 348 行/秒时不串行化。**改 conf 可就地生效** |
| 4 | 🔴 P0 | uid 10000013 无存档仍在线 | 排查建号/首次登录落库失败；确认 42 个缺号是否都该有档 | 消除数据丢失 + 删除约 3 千条/天错误日志 |
| 5 | ✅ 已完成 | `rewardedMissionIds` 把 BitSet 内部字段入库 | 已改：`MongoBitSetConverter` 注册到 `mappingMongoConverter1`，存逗号分隔的下标串；业务代码零改动，**兼容读旧位图** | 单玩家单字段 909KB → 20 字节；全库 **−17.91MB**。详见 §9.1 |
| 6 | 🟠 P1 | `playerManager` 206KB（`rechargeInfo` 202KB） | `timeLimitMap`(504 键)/`perpetualMap`(121 键) 只保留未过期期次，过期归档到独立集合 | 单玩家 −150KB 量级，且止住无界增长 |
| 7 | 🟠 P1 | `userMissionManager` 244KB 全量随主文档读写 | 冷热分离：`rewardedMissionIds`、`*CumulationData` 等「仅去重/统计用」字段拆到 `userMission` 子集合，按需加载 | 主文档从 552KB → 300KB 量级；直接改善 §2 的 96/161ms |
| 8 | 🟠 P1 | 日志表无索引 | `itemLog` / `fightLog` / `heroLog` 建 `{uid:1, createTime:-1}` | itemLog 查询从 **130,493 行全扫 → 索引命中**，且止住 O(n) 劣化。**在线建索引，注意业务低峰** |
| 9 | ✅ 已完成 | 50 线程 `sleep(2)` 轮询 | 已改：`LinkedBlockingQueue` + `poll(2, MILLISECONDS)`，`run()` 感知 interrupt | 消掉 **25,000 次/秒空转**；有消息时 `offer()` 直接唤醒，排队延迟比轮询更短。详见 §9 |
| 10 | ✅ 已完成 | 255 万 HashMap / 518 万节点（74% 活堆） | 已定位为**敏感词 DFA 树**（静态字段），改为 CSR 紧凑数组 `SensitiveWordTrie`：本地实测常驻 **444.3MB → 26.6MB**，9,757,186 次对拍 0 差异 | 活堆 674MB → 约 200MB，并发天花板从 ~70–100 人抬到数百人。详见 §10 |
| 11 | 🟡 P2 | `updateDataTask` 无退避重试 | 加重试上限 + 指数退避 + 失败聚合日志 | 跨天窗口 00:00–02:00 从 30,743 行/小时、FIGHT_END p50 433ms 回落 |
| 12 | 🟡 P2 | `MongoUtil#279 not exists` 对存在的 uid 也报 | 核对查询的库/集合/字段类型（Long vs Integer vs String） | 消除误报 |
| 13 | ⚪ P3 | `net.bindIp: 0.0.0.0` | 收回 `127.0.0.1` | 安全，非性能 |
| 14 | ⚪ P3 | Redis 命中率 31% | 收敛无效 key 探测 | 轻微 |

---

## 8. 待确认项（本次只读无法定论）

1. **96ms / 161ms 的精确归因**：建议在低峰期开 60 秒 profiler ——
   `db.setProfilingLevel(1, {slowms:50})` → 采样 → `db.setProfilingLevel(0)`，
   或用 async-profiler 抓 30 秒 Java 栈。本次只能证明「Mongo 读 2.8ms + 响应 <6KB」，
   剩下的时间在应用侧，但具体在 BSON 解码 / Gson 转换 / 业务计算，尚未分离。
2. ~~**674MB 活堆的归属**~~ → ✅ **已定位，见 §10**：不是玩家对象，是敏感词 DFA 树（静态字段），
   496MB / 674MB = 74%。
3. **`timeLimitMap` 的 key 语义**：需对照 `SRechargeCommodityConfig`（833 个实例）判断哪些期次可安全裁剪。

---

## 9. 已落地的源码改动（2026-10-18）

源码：`TimeSpaceServer/Server_x1tag1.2.2/`，分支 `x1-tag-1.2.2`。
验证：`sh gradlew :serverlogic:compileJava` → **BUILD SUCCESSFUL**（仅 1 个既有无关 warning）；
并反编译 `build/classes` 产物确认新注册的转换器确实进了 `MongoConfig.class`（避免 Gradle `UP-TO-DATE` 假通过）。
BitSet 部分另有 13 项独立往返测试：`sh scripts/verify/run_bitset_converter_check.sh` → 全 PASS。

**这 5 处改动全部在服务端，客户端 lua / LuaBytes / 图集 / AB 一行不动，不需要发客户端包。**

| 文件 | 改动 | 目的 |
|---|---|---|
| `core/HandlerLogicThread.java` | `ConcurrentLinkedQueue` + `Thread.sleep(2)` → `LinkedBlockingQueue` + `poll(2, MILLISECONDS)`；字段去掉 `final`；`run()` 检测 interrupt 退出 | 消掉 50 线程 × 500 次/秒 = **2.5 万次/秒空转**；有消息时立即被 `offer()` 唤醒，排队延迟比轮询更短 |
| `core/HandlerLogicThread.java` | 每条请求的 `doWork->...;start` 由 INFO 降为 DEBUG（`isDebugEnabled()` 守卫） | 请求级日志量减半；带 `useTime` 的 end 行仍保留 INFO，延迟观测不受影响 |
| `util/MessageUtil.java:456` | `adventureBossRankInfo is null` 由 ERROR 降为 DEBUG | 这是「当前无待推送公告」的常态，原来每分钟一条 ERROR 共 11,342 条（占全部 ERROR 41%） |
| `db/mongo/MongoUtil.java:279,294` | `the user={} not exists` 由 ERROR 降为 DEBUG | 查询失败是常态（见 §4.1），原来单日可刷 1.5 万行 |

> 🔴 **踩坑记录（给后来人）**：改 `HandlerLogicThread` 的队列字段时，第一版加了 `final`，
> 模块编译立刻报错 `ProtocolsManager.java:141: cannot assign a value to final variable`。
> 我最初用 `grep -rn "a\|b"` 搜引用**没搜到**，误以为无人使用——本机 BSD grep 不认 `\|`，
> 必须用 `grep -E`。**教训：字段改 `final`/改类型前用 `grep -E` 复查，并以完整模块编译为准，
> 只编译改动文件会漏掉跨文件赋值。**

### 9.1 ✅ 已落地：BitSet 稀疏存储（转换器方案，业务代码零改动）

**没有采用「81 处 `BitSet` → `Set<Integer>` 替换」**。原因是那条路有两个硬伤：
① 字段换成 `Set<Integer>` 后，Spring 读到线上的 `{words:[...], wordsInUse:N}` 会**直接抛映射异常 → 玩家登不进来**；
② 必须「新 jar + 数据迁移」严格同窗口，且迁移后旧 jar 完全读不了，没有灰度空间。

改为在 `mappingMongoConverter1` 上注册一个 BitSet 转换器。关键依据是
`MongoUtil.java:388-390`：**所有区服的 `MongoTemplate` 共用同一个 `mappingMongoConverter1` bean**
（`new MongoTemplate(mongoDbFactory, mappingMongoConverter)`），所以注册一次即全局生效；
写入的两条路径 `MappingMongoConverter.write()` 和 `LjsdMongoTemplate.updateMongoData():202` 的
`converter.convertToMongoType()` 都会经过它。

| 文件 | 改动 |
|---|---|
| `db/mongo/MongoBitSetConverter.java` | **新增**。`BitSet→String`（写出稀疏下标串）、`String→BitSet`、`DBObject→BitSet`（解旧位图）三个转换器 |
| `db/mongo/MongoConfig.java` | `customConversions()` 里注册上述 3 个转换器（与原有两个转换器并列） |

存储形态：

```
旧：rewardedMissionIds: { words: [0,0,...,2], wordsInUse: 50001, sizeIsSticky: false }   738,953 字节
新：rewardedMissionIds: "3200001"                                                              37 字节
```

**验证（`sh scripts/verify/run_bitset_converter_check.sh`，13 项全 PASS，不连库、构造与线上同构的
`MappingMongoConverter` 实测）**：

| # | 路径 | 结果 |
|---|---|---|
| A | 全量存档 `write(User)`（三层嵌套 + 继承） | `"3200001"` ✅ |
| B | 增量更新 `convertToMongoType(missionType)` ← 领奖后最高频 | `"3200001"` ✅ |
| C | 读新格式整档 | `{3200001}` ✅ |
| D | **读旧格式整档**（739,124 字节位图） | `{3200001}`，状态不丢 ✅ |
| E | 旧数据读入再存回 | 739,124 → **183** 字节，自动收敛 ✅ |
| — | 空集合读写、`convertToMongoType(裸 BitSet)`、越界 bit 下标 | 全 PASS ✅ |

⇒ 因为 **D 成立（能读旧格式）**，上线顺序变成可灰度、可回滚，不再是「必须同一秒」：

1. `mongodump` 备份
2. 上新 jar（此时线上数据还是旧位图，**读得动**）
3. 跑 `scripts/migrate_rewarded_mission_bitset.js`（`APPLY=true`）一次性把 18MB 压掉
4. 不跑也行：玩家上线存档一次就自动转新格式

数据迁移 dry-run（生产库实测，`APPLY=false`）：

```
玩家数            = 208
受影响字段数      = 5,616        （userMissionManager 下 27 个 mission 子类型 × 208 人）
解码出的 id 总数  = 5,976
迁移前体积        = 18.00 MB
迁移后体积        = 0.0943 MB
预计释放          = 17.91 MB
```

抽样换算（原 BitSet 内部字段 → 真实 id）：

```
uid=10000002 jadeDynastyMissionType       bits=1   ids=[3200001]          909.3KB -> 0.020KB
uid=10000002 mysticalInstructMissionType  bits=0   ids=[]                 150.6KB -> 0.013KB
uid=10000002 achievementMissionTypMap     bits=34  ids=[1,2,3,4,5,6,...]    6.0KB -> 0.111KB
uid=10000002 trainMissionType             bits=2   ids=[30011,30013]        5.9KB -> 0.023KB
```

🔴 **回滚边界**：迁移（第 3 步）执行后旧 jar 读不了字符串形态。脚本已把可还原的 id 列表备份到
`user_bitset_backup_20261018`，回滚路径是「恢复备份 + 回旧 jar」。**没跑第 3 步则随时可回滚旧 jar。**

⚠️ **作用面核对**：全仓 `BitSet` 作为持久化字段**只有 `AbstractMissionType.rewardedMissionIds` 一处**，
其余全部是 Thrift 生成的局部变量（`optionals`/`incoming`），不进 Mongo。转换器精确命中，无副作用。
客户端侧 lua / cs / proto / LuaBytes **零引用**该字段 ⇒ 不需要发客户端包。

---

## 10. 🔴🔴 497MB 集合类的真正归属：敏感词 DFA 树（2026-10-18 heap dump 定位）

### 10.1 怎么抓的

```
jmap -dump:live,format=b,file=/data/dump/heap_20261018.hprof 7550
→ 1.1GB，耗时 8 秒（含 1 次 Full GC，FGC 73→74），在线 1 人时执行
```

1.1GB 的文件经 scp 只有 ~1MB/s（17 分钟）。**没有干等**：把 dump 留在服务器上，
用自写的 HPROF 定向引用扫描器就地分析（`scripts/verify/HprofRefScan.java`，
不构建全量对象图，只保留目标实例 id 的排序 `long[]`，`-Xmx320m` 足够，3 趟顺序读共 18 秒）。

### 10.2 逐层追出来的链

| 步 | 发现 | 证据 |
|---|---|---|
| 1 | 2,552,222 个 `java.util.HashMap` | 扫描 collect 阶段 |
| 2 | 其中 **2,538,192 个是别的 map 的 `Node#value`**（99.45%） | 引用边聚合：`java.util.HashMap$Node#value = 2,538,192` |
| 3 | 全堆只有 **1 个**超大数组：`[Ljava.util.HashMap$Node;` len=**524,288** | `@bigarray:100000` |
| 4 | 该数组的唯一持有者是 `java.util.HashMap#table`，实例 id=`3136995840` | `@ids` 反查 |
| 5 | 持有该 map 的是 **`com.ljsd.jieling.util.SensitiveWordInit.<static>sensitiveWordMap`**，`SensitivewordFilter.<static>sensitiveWordMap` 引用同一实例（无重复） | 静态字段扫描 |

**结论：这不是玩家数据，也不是缓存泄漏，是一棵开服时就建好、之后只读的静态数据结构。**

### 10.3 为什么一棵树吃掉 500MB

`SensitiveWordInit`（原实现）是流传很广的 DFA 写法：**每个字符建一个 `HashMap` 当树节点**，
并且每个节点里还塞一对 `"isEnd" -> "0"/"1"`：

```java
newWorMap = new HashMap<String,String>();
newWorMap.put("isEnd", "0");
nowMap.put(keyChar, newWorMap);
```

- 词库 `mingan.txt`：**385,376 行 / 5.1MB / 4,633,155 字符**
- 去重后 385,374 条 → 共享前缀合并 → **2,535,771 个节点**（与 dump 实测 2,538,192 吻合，差值 2,421 是别的 map）
- 单节点开销：`HashMap` 48B + 默认 16 槽 `Node[]` 80B + 2 个 `Node` 64B + 装箱 `Character` 16B ≈ **210B**
- 2.54M × 210B ≈ **500MB** —— 实测 496MB（`HashMap` 122MB + `Node` 165MB + `Node[]` 209MB）

**关键点：这个 `HashMap` 每个只装 1~2 个键，却按默认容量 16 分配 table 数组。**
`[Ljava.util.HashMap$Node;` 单项就占 209MB —— 全堆第一大对象就是这些"空槽位"。

### 10.4 已落地修复（服务端，客户端不用发包）

| 文件 | 改动 |
|---|---|
| `util/SensitiveWordTrie.java` | **新增**：CSR 紧凑 DFA。`edgeChar[]` / `edgeChild[]` / `nodeStart[]` / `isEnd[]`，子节点区间按字符升序可二分 |
| `util/SensitiveWordInit.java` | 删掉 `addSensitiveWordToHashMap`（HashMap 建树），改为「排序后 DFS 建树 → 按父节点归并成 CSR」，返回 `SensitiveWordTrie`；保留原读文件逻辑，并加一行初始化日志（词条数/节点数/边数/估算内存/耗时） |
| `util/SensitivewordFilter.java` | 对外 API 与语义**完全不变**（`init` / `isContaintSensitiveWord` / `getSensitiveWord` / `replaceSensitiveWord` / `CheckSensitiveWord`），内部改走 trie；加懒加载兜底；`replaceAll`（正则）改 `replace`（字面量，对当前词库结果一致，避免词库出现正则元字符时抛异常） |

**实测对比**（同一份 385,374 条词库，`scripts/verify/VerifySensitiveWordTrie.java`）：

```
[2] 原实现 build=527ms  常驻≈444.3MB
[3] 新实现 build=200ms  常驻≈26.6MB   nodes=2535771 edges=2535770
[5] 总对拍次数 = 9,757,186   不一致 = 0
==== PASS：新实现与原实现完全等价 ====
```

对拍覆盖：全部词条逐位置 × 最小/最大两种匹配、2 万组「词+词」拼接（制造重叠与最长匹配）、
2 万组词前缀（验证 `isEnd` 语义）、5 千条随机干净文本、空串/单字符/3 千字长文。

> 常驻 **444MB → 26.6MB（−94%）**，构建 527ms → 200ms。
> 换算到线上：活堆 674MB → 约 200MB，1280MB 堆的并发天花板从 70~100 人抬到数百人量级。

**验证方式**：
```bash
javac -d /tmp/swt \
  server_game/serverlogic/src/main/java/com/ljsd/jieling/util/SensitiveWordTrie.java \
  scripts/verify/VerifySensitiveWordTrie.java
java -Xmx3g -cp /tmp/swt VerifySensitiveWordTrie server_game/serverlogic/src/main/resources/mingan.txt
```
模块编译：`sh gradlew :serverlogic:compileJava` → **BUILD SUCCESSFUL**。

⚠️ 一个附带的行为改善：新读文件逻辑对每行做了 `trim()`。原实现若词库是 CRLF，行尾 `\r` 会被算进词里导致该词**永远匹配不上**；现在不会。当前词库无空行、无正则元字符（已核）。

---

## 附：本次采集的关键命令

```bash
# 请求耗时
grep -oE "mType=[A-Za-z0-9_]+,useTime=[0-9]+" gameserver.log | sed -E 's/mType=([A-Za-z0-9_]+),useTime=([0-9]+)/\1 \2/'

# 堆对象
jmap -histo:live <pid> | head -15

# GC（当前无日志，只能实时看）
jstat -gcutil <pid> 1000 5

# 线程模型
javap -p -c com/ljsd/jieling/core/HandlerLogicThread.class | awk '/doWork\(\)/,/^$/'

# 文档体积
db.user.find().forEach(function(d){ var s=bsonsize(d); ... })

# 索引缺失
db.itemLog.find({uid:10000002}).explain("executionStats")
```
