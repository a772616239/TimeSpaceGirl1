# 远征快速领奖（type=2）频次护栏补丁

> 创建：2026-10-18
> 关联事故：玩家 Mozart（UID `10000013`）利用该漏洞 1 分钟连领 35 次，钻石刷到 1.25 亿
> 关联手册：`../../docs/gm_abuse_incident_playbook.md`
>
> 🔴 **状态（2026-10-18 15:00）：已转正到源码，本文档仅留作事故存档。**
> 逻辑已合入 `Server_x1tag1.2.2` 源码（提交 `77402068`）：
> - `serverlogic/.../com/ljsd/jieling/patch/AdventureRewardGuard.java`（新类）
> - `serverlogic/.../com/ljsd/jieling/logic/fight/CombatLogic.java`（`type == 2` 分支入口调用）
>
> 重新打包 jar 后依然生效，**不要再重复注入**。字节码注入版与源码版已用 javap
> 逐条比对（行集合完全一致，仅方法声明顺序不同）。下方 §3/§4 的注入流程仅在
> 「手头只有 jar、没有源码」时作为应急手段保留。

---

## 1. 漏洞

`CombatLogic.takeNewAdventureReward(ISession, int type, int position)` 中：

- **`type != 2`（普通领奖）**：会走 `PlayerLogic.checkAndUpdate(user, 4, 1)`，有次数/消耗校验。
- **`type == 2`（快速领奖）**：只调用 `getNewAdventureReward(user, true, now)` 算出奖励，
  **随后直接下发，全程没有每日次数上限、没有最小间隔冷却、也不校验是否有可领的远征进度。**

结果：客户端可无限制连发 `ADVENTURE_REWARD_REQUEST{type:2, position:-1}`，
每次产出 20+ 种物品与 777,600 钻石。

### 事故量化证据

| 判据 | 数据 |
|---|---|
| 1 分钟内 `ADVENTURE_REWARD_REQUEST` 次数 | **35 次**（最短间隔 0.3 秒） |
| 单次产出 | 777,600 钻石 + item3/14/79 等 20 余种 |
| 当日奖励发放笔数 vs 第二名 | 33 笔 vs 6 笔 |
| 钻石总量 vs 全服中位数 | 125,634,740 vs 200（**约 62.8 万倍**） |
| `777600` 这一数值 | **全服仅他一人**，重复出现 6 次 |

---

## 2. 补丁方案

**不改业务逻辑，只在 `type == 2` 分支入口插入频次护栏。**

新增类 `com.ljsd.jieling.patch.AdventureRewardGuard`：
- 最小间隔 `MIN_INTERVAL_MS = 3000`（两次快速领奖至少间隔 3 秒）
- 每日上限 `MAX_PER_DAY = 5`（每玩家每日最多 5 次）
- 计数落 Redis（`ADV_FAST_REWARD:<yyyyMMdd>:<uid>`），首次 `incr` 时设 25h 过期，跨日自动清理
- 超限抛 `ErrorCode.REWARD_COLLECTING`，客户端表现为"领取中不可重复领"，不新增错误码定义

### 注入位置

用 Javassist 对 `CombatLogic.takeNewAdventureReward` **方法开头**插入：

```java
int _t = $2;
if (_t == 2) {
    AdventureRewardGuard.checkAndMark($1.getUid(), GameApplication.serverId);
}
```

- 只影响 `type == 2`，其它 type 完全不受影响
- 原始 184 条字节码指令**逐条保留**，仅新增 9 条（已用指令序列 diff 验证）

---

## 3. 构建与部署

### 3.1 编译护栏类

```bash
JAR=/path/to/gameSrv-1.0.0.jar
LIB=/path/to/gameserver/lib
CP=$(ls $LIB/*.jar | tr '\n' ':')
javac -source 1.8 -target 1.8 -encoding UTF-8 -cp "$JAR:$CP" \
      -d out AdventureRewardGuard.java
```

### 3.2 注入字节码

```bash
javac -encoding UTF-8 -cp "$LIB/javassist-3.18.2-GA.jar:$JAR:$CP" -d inject/out Inject.java
java -cp "inject/out:$LIB/javassist-3.18.2-GA.jar:$JAR:$CP" \
     Inject "$JAR" patched "$CP:out"
```

### 3.3 部署到服务器

```bash
# 1) 备份
cp -a /home/java/gameserver/gameSrv-1.0.0.jar /root/incident_YYYYMMDD/gameSrv-1.0.0.jar.bak.$(date +%H%M%S)

# 2) 注入（jar uf 覆盖同名 class）
mkdir -p /tmp/inject_dir/com/ljsd/jieling/patch \
         /tmp/inject_dir/com/ljsd/jieling/logic/fight
cp AdventureRewardGuard.class /tmp/inject_dir/com/ljsd/jieling/patch/
cp CombatLogic.class         /tmp/inject_dir/com/ljsd/jieling/logic/fight/
cd /tmp/inject_dir && jar uf /home/java/gameserver/gameSrv-1.0.0.jar \
   com/ljsd/jieling/patch/AdventureRewardGuard.class \
   com/ljsd/jieling/logic/fight/CombatLogic.class

# 3) 完整性校验
unzip -t /home/java/gameserver/gameSrv-1.0.0.jar | tail -2

# 4) 重启
cd /home/java/gameserver && sh RESTART-GAMESERVER.sh
```

### 3.4 验证

```bash
# 补丁类已进 jar
unzip -p /home/java/gameserver/gameSrv-1.0.0.jar \
  com/ljsd/jieling/logic/fight/CombatLogic.class > /tmp/cl.class
javap -c /tmp/cl.class | grep -c "AdventureRewardGuard.checkAndMark"   # 应为 1
```

---

## 4. 注意事项

1. **本补丁已转正到源码**（见文首状态）。源码版与这里的字节码注入版逻辑等价，
   重新编译 jar 不会再丢；若某天又只拿到 jar（无源码），才回到本文流程。
   长期方案仍是把 `type=2` 迁移到带次数的配置表。
2. **重启会丢补丁吗？** 不会——补丁已进 jar 文件，重启只是重新加载。
   **但重新打包/替换 jar 会丢。**
3. **`server.debug` 与本补丁独立。** 前者管 GM 指令通道，后者管领奖频次，两个都要管。
4. 若后续要放宽阈值，改 `AdventureRewardGuard.MAX_PER_DAY` / `MIN_INTERVAL_MS` 后重新编译注入。
