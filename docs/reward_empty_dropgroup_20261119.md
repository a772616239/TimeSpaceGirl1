# 2026-11-19 Mozart「训练收益 / 快速训练 / 遗忘之城 领不到奖励」

## 玩家反馈

英文工单（代 Mozart 提交）：

> Good afternoon, I am writing on behalf of player Mozart. that she doesn't collect
> awards in training income and quick train and forget city. Please solve this problem.

UID 10000013 / Lv111 / 全服第一。

## 一、日志铁证

`/data/srvlog/gameserver.log-20261119-1795029961`（北京时间 2026-11-18 19:40:11）：

```
[INFO] processWithProto::FightInfoProto.TakeAventureRewardRequest. UserId=10000013 Type=2 Position=-1
[ERROR] processWithProto Exception protoID=10022,uid=10000013,proto=>type: 2
position: -1
 exception=java.lang.ArrayIndexOutOfBoundsException
[WARN]  request failed, dropped 15 pending mongo writes. uid=10000013
[ERROR] send error msg,the uid=10000013,the msgId=10023,the errMsg=
```

第一次是 `ArrayIndexOutOfBoundsException`、errMsg 为空（客户端弹不出任何提示），
紧接着每一次都变成 `[CODE: 107][奖励正在积攒中！]`。

`ArrayIndexOutOfBoundsException` 按天统计（含 type=1 快速训练）：

| 日期 | 次数 | 日期 | 次数 |
|---|---|---|---|
| 11-13 | 1 | 11-17 | 8 |
| 11-14 | 16 | 11-18 | 6 |
| 11-16 | 16 | 11-19 | 4 |

涉及 uid：10000013 (344 次)、10000275 (8)、10000049 (7)、10000017 (4)、10000272 (2)。

## 二、根因

### 2.1 直接原因：空掉落组把 `split("\\|")` 打成长度 0

`serverlogic/.../util/ItemUtil.java` 的 `selectDrop()`：

```java
String dropInfo = dropRewardMap.get(sRewardGroup.getId());
String rewardStr = dropInfo.split("\\|")[0];
String weight    = dropInfo.split("\\|")[1];
```

`initDropReward()` 遍历 `RewardGroup`，把组里**能查到的** RewardItem 拼成
`"奖励串|权重串"`。当一个都查不到时，拼出来的就是 `"|"`。

而 Java 里 `"|".split("\\|")` 返回的是**长度 0 的数组**（末尾空串被丢弃），
于是 `[0]` 直接抛 `ArrayIndexOutOfBoundsException` ⇒ 整条领奖请求失败。

### 2.2 哪些组是空的：线上 RewardItemConfig 少了 103 行

| 文件 | 线上 `/home/java/gameserver/{conf,assets/conf}/server/` | 仓库 |
|---|---|---|
| `RewardItemConfig.txt` | 800064 B，2023-11-26，21294 行，md5 `0ebb9dff…` | 803700 B，21397 行，md5 `d351aed8…` |

逐行比对：**共同 21292 行完全相同**，仓库只多 `990000~990102` 这 103 行。

这 103 行恰好是掉落组 `20101 / 20102 / 20103` 的全部内容：

```
20101  upset=2  maxn=1  loop=0   items: 990000..990016   (17)
20102  upset=2  maxn=1  loop=0   items: 990017..990053   (37)
20103  upset=2  maxn=1  loop=0   items: 990054..990102   (49)
```

而 `MainLevelConfig.RandomReward` 引用这三个组 **3590 次，覆盖 2020 个关卡**：

- 20101 → 1570 次
- 20102 → 1570 次
- 20103 → 450 次

所以线上共 **211 个掉落组**变成 `"|"`，挂机收益和快速训练的公共奖励链
必然踩中：**谁点谁失败**，不是个别玩家。

（`990xxx` 的 ItemId 全部是 `14`(金钱) 和既有的道具 id，`ItemConfig` 里都存在，
所以补齐这 103 行不会引入新道具，只是让掉落组不再为空。）

### 2.3 第二层：护栏先扣次数再判断，越点越少

`AdventureRewardGuard.checkAndMark()` 原实现：

```java
long cnt = redis.incr(kDay, 1L);   // 先加
if (cnt > maxPerDay) throw ...;    // 再判
```

由此产生两个后果：

1. 被拦下的请求也照扣 1 次；
2. 请求在 incr 之后、发奖之前抛异常（比如 2.1 的 AIOOBE），这次额度同样白吃。

Mozart 一天内点了 20+ 次，很快把 type=2 的 5 次上限和 type=1 的 3 次上限耗光，
之后无论怎么点都是 107 —— 这正是玩家描述的「收不到奖励」。

### 2.4 同批修的其它坑

| 位置 | 问题 |
|---|---|
| `CombatLogic.takeNewAdventureReward` | `(int) getCreateTime() / 1000` 先把 64 位毫秒戳窄化成 int 再除，结果随机；「建号 60 秒内不判空包」的保护形同虚设 |
| 同上 | `getNewAdventureReward` 在挂机时间不足一轮时返回 `null`，代码直接 `.get(1)` ⇒ NPE |
| 同上 | type=1 分支没有对 `getNewAdventureFastReward` 做 null 检查 |
| `ItemUtil.getSuccessivelyRandmoMap` | `loop > rewardArr.length` 时 `rewardArr[j]` 越界；权重全 0 时 `randomForStrArray` 返回 -1，`rewardArr[-1]` 越界 |
| `ItemUtil.getRandomMap` | 同样没有 `index == -1` 之外的越界保护（数组长度不一致时） |
| `BlitzLogic.getBoxAward`（遗忘之城） | `addBoxAwardedProgress2(fightId)` 写在 `for` 循环**体内** ⇒ awards 为空时永远不标记，同一宝箱可无限点、每次都是空包 |
| 同上 | `SBlitzBoxAwards` 查不到时直接 NPE |
| 同上 | 该关没配宝箱（`BoxAwards == 0`）时「不发奖、不标记、回空 drop」，客户端以为领到了 |

## 三、改动

服务端提交 `c400d423`（`x1-tag-1.2.2`）：

1. `ItemUtil.selectDrop`：`dropInfo` 为空 / `"|"` / rewards 与 weights 长度不一致时
   跳过该组并记 error，不再让整条请求 500。
2. `ItemUtil.getRandomMap` / `getSuccessivelyRandmoMap`：`index < 0 || index >= pick`
   一律 skip；`loop` 收敛到实际条数。
3. `AdventureRewardGuard`：拆成 `check`(只校验) + `mark`(成功后记账)；
   新增 `checkClaim` / `checkTrainOnly` / `markSuccess` / `markTrainSuccess`。
4. `CombatLogic.takeNewAdventureReward`：
   - `createTime` 改 long；
   - 两处 null 检查；
   - 校验 → 扣费 → 发奖 → 标记，失败不吃额度。
5. `BlitzLogic.getBoxAward`：标记移到发奖成功后；`BoxAwards==0` 与配置缺失显式报错。

编译：`:serverlogic:compileJava` 通过（JDK 8）。

## 四、线上操作（已执行部分）

- ✅ `RewardItemConfig.txt` 已推到线上两处（`conf/server`、`assets/conf/server`），
  旧件备份为 `*.bak-20261119_183153`，md5 校验 `d351aed8471b072bf4a16bfd494df60b5`，
  21397 行。
- ⏳ 新版 `gameSrv-1.0.0.jar` 需上传并重启（`RESTART-GAMESERVER.sh`，带 lib 清单自检）。

> ⚠️ 换表必须重启。两条路径不一样：
>
> - **表本体**（`*.txt`）走 `SysUtil.getPath("conf","server",...)`：
>   Linux 下 `getRootPath()` 返回 `"../../../"`，进程 cwd 是 `/home/java/gameserver`，
>   拼出来是 `/conf/server/` —— 而根上 `/conf -> /home/java/gameserver/conf`，
>   所以读的正是 `/home/java/gameserver/conf/server/RewardItemConfig.txt`（已更新）。
> - **热更版本号**走 `STableManager.initJsonPath()` 里的 `jsonPath = "../conf/"`，
>   相对 cwd 是 `/home/java/conf/` —— **该目录不存在**，日志每分钟都在打
>   `the c_database_version.json is not exist` ⇒ `updateTablesWithTableNames(true)`
>   第一句就 return，**热更从未生效**。
>
> 结论：改表 = 必须重启（或修 jsonPath 后补 c_database_version.json）。

## 五、验证口径

重启后：

1. 日志不再出现 `ArrayIndexOutOfBoundsException`；
2. `TakeAventureRewardRequest{type:2}` 有正常回包，drop 里 item14（金钱）与道具非空；
3. Mozart 当日 type=2 次数可正常用满 5 次，type=1 用满 3 次；
4. 遗忘之城任意宝箱点一次即变已领，重复点报 `HAD_TAKE_REWARD`。
