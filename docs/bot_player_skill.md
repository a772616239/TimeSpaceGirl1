# 虚拟玩家（机器人）：在线数 / 世界喊话 / 英雄公告 / AI 回话

> 更新时间：2026-10-23（新增 §4.4 晒卡换人 / §4.5 醒来重试与 per-bot 抖动 / §4.6 冷清补话）
> 关联：`server_ops_runbook.md`（线上热补丁口径）、`scripts/bot/dsh_bridge.py`（DSH 桥接）、
> `scripts/bot/start_bridge.sh`（桥接启停）、`scripts/bot/bot_console.py` + `console.html`（可视化后台）、
> `scripts/bot/testserver.sh`（测试服隧道+控制台）、
> `TimeSpaceServer/Server_x1tag1.2.2/server_game/conf/bot_config.json`（配置）
> 一句话：**服务端内存里养 1~2 个虚拟玩家，撑起后台在线数、世界频道人气和英雄公告；
> 它们是「躺平挂机」的玩家 —— 随机 20~240 分钟醒一次，醒来只做一件事（回话 / 公告 / 闲聊 / 纯挂机）；
> 玩家说话不会立刻被回，只是记进账本，等下次有人醒来才可能被回一句 40 字符以内的真人味儿短句。
> 有一个网页控制台能看实时流水线、指标和事件，并直接点按钮操作。**

---

## 0. 它解决什么

| 现象 | 机器人做的事 |
|---|---|
| 测试服/新服 `ONLINE_NUM=0`，后台看板上一个活人都没有 | 把在线机器人叠加进 `ONLINE_NUM`（后台、登录服 `recommend` 都读这个 key） |
| 世界频道 7 天没人说话，像鬼服 | 机器人**随机 20~240 分钟醒一次**，醒来才可能说句话 |
| 抽卡没有「别人也在抽」的氛围 | 醒来时 40% 概率发一条吉运公告（复用真实玩家公告链路，名字换成机器人） |
| 玩家在世界上说话没人接 | 醒来时若还有没回过的消息，8~25 秒后由 DSH 生成一句短回复 |

> 🔴 **核心口径（2026-10-22 起）：机器人是「躺平挂机」的玩家，不是客服。**
> 所有行为（回话 / 公告 / 闲聊）都挂在同一个总闸上 —— 每个机器人**独立随机 20~240 分钟醒来一次**，
> 醒来按 `回话 > 公告 > 闲聊 > 挂机` 的优先级**只做一件事**，然后继续躺。
> 玩家说话**不会**立刻触发回复，只是被记进账本，等下一次有人醒来才可能被回。

---

## 1. 数据流（为什么不需要改客户端）

```
玩家发世界(chatType=1)
   └─ ChatLogic.sendChatMessage
        ├─ MessageCache.addWordMsg(chatInfo, mid)      ← 客户端拉取式聊天，读这里
        └─ BotManager.onWorldChat(chatInfo, mid, "world")   ← 新增钩子
              └─ 只记账：lastHumanMsgId / lastHumanText / lastHumanAt（**不排回复**）

chatserver 跨服回包(chatType=16)
   └─ ChatLogic.sendChatMessage(chatInfo, mid)
        ├─ MessageCache.addCrossMsg(...)
        └─ BotManager.onWorldChat(..., "cross")

BotTask（15s 一拍）
   ├─ maybeFlipOnline→ 随机上下线，让在线数看起来是活的
   ├─ maybeWake     → 每个机器人各自的 nextActiveAt 到了就「醒来」，只做一件事：
   │                    ├─ schedulePendingReply  有欠账 → 排 8~25s 后回话
   │                    ├─ announceHero          roll<40% → 吉运公告
   │                    ├─ sayChatter            roll<80% → 世界闲聊
   │                    └─ 什么都不做 → 继续挂机
   ├─ maybeReply    → 拼 3 天上下文 → POST DSH 桥接 → 洗文案 → addWordMsg
   └─ publishStatus → 推控制台快照（含每个机器人的 wake 倒计时）
```

**关键点：世界频道本来就是「客户端按 messageId 拉取」，不是服务端 push。**
机器人只是往同一个 `LoopQueue` + `Redis 10001:CHAT_QUEUE:world` 里塞了一条格式完全一致的
`ChatInfo`（`msg="0|正文"`、`senderId=9xxxxxxx`、带 level/head/frame/country/serverId），
所以客户端解析路径和真人发言**一模一样**，不需要动协议、不用重出包。

---

## 2. 部署（本地测试服，已验证）

```bash
# 1) 编译（只编改动的类，秒级；不用整包 gradle）
export JAVA_HOME=/usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home
cd TimeSpaceServer/Server_x1tag1.2.2/server_game/serverlogic/src/main/java
$JAVA_HOME/bin/javac -encoding UTF-8 -source 8 -target 8 -nowarn \
  -cp "$HOME/home/java/gameserver/gameSrv-1.0.0.jar:$HOME/home/java/gameserver/lib/*" \
  -d /tmp/bot_patch/classes \
  com/ljsd/jieling/bot/*.java com/ljsd/jieling/kefu/Cmd_bot.java \
  com/ljsd/jieling/chat/logic/ChatLogic.java \
  com/ljsd/jieling/thread/ThreadManager.java \
  com/ljsd/jieling/thread/task/MinuteTask.java

# 2) 热补丁进 jar（先备份）
cd /tmp/bot_patch/classes
cp -a $HOME/home/java/gameserver/gameSrv-1.0.0.jar $HOME/home/java/gameserver/gameSrv-1.0.0.jar.bak-bot-$(date +%Y%m%d)
$JAVA_HOME/bin/jar uf $HOME/home/java/gameserver/gameSrv-1.0.0.jar \
  com/ljsd/jieling/bot com/ljsd/jieling/kefu/Cmd_bot.class \
  com/ljsd/jieling/chat/logic/ChatLogic.class \
  com/ljsd/jieling/thread/ThreadManager.class \
  com/ljsd/jieling/thread/task/MinuteTask.class

# 3) 配置
cp server_game/conf/bot_config.json $HOME/home/java/gameserver/conf/

# 4) 起 DSH 桥接（游戏服侧只是个 HTTP 客户端，桥接挂了会走本地语料兜底）
scripts/bot/start_bridge.sh start

# 5) 重启本地服
$HOME/home/java/start-local.sh restart gs
grep "\[bot\]" $HOME/home/java/logs/gameserver.log | tail
```

启动日志应出现：

```
[bot] 已加载配置 .../conf/bot_config.json，bots=2
[bot] 初始化完成 enabled=true reply=true bots=2 virtualOnline=true
```

---

## 3. GM 命令（thrift 7916，`scripts/gm_client.py`）

| 命令 | 作用 |
|---|---|
| `bot status` | 开关 / 在线数 / 两个频道的 lastHuman·lastBot / inFlight |
| `bot on` / `bot off` | 总开关（关掉后在线数归零、不再说话） |
| `bot reload` | 重读 `conf/bot_config.json`，**不用重启** |
| `bot say <文本>` | 让在线机器人在世界频道说一句 |
| `bot announce [heroId]` | 触发一次英雄公告（不填随机挑 5 星） |
| `bot fake <名字> <文本>` | **造一条玩家发言**，没有客户端也能验证 AI 回话链路。uid 走 `fakeSenderUid`（默认 99990001），**不占用任何真实玩家身份** |
| `bot reply` | 跳过等待立刻回一次 |
| `bot act <uid>` | 跳过等待立刻做一次真实游戏操作（升级英雄 / 抽卡） |
| `bot arena <uid>` | 跳过 4~10 小时排期、不掷概率，立刻去竞技场打一场（额度/封顶/名次判定照旧，打完顺延下次排期） |
| `bot team <uid>` | 复刻客户端个人面板的服务端路径，打印 `name/level/vip/head/force/heroes/...`，用来查「面板空白」 |

```bash
PY=/Users/wangxufeng/.workbuddy-ai/binaries/python/envs/default/bin/python   # 需要 thrift 包
$PY scripts/gm_client.py 'bot fake Mia do u know where to farm gold'
sleep 30; grep "\[bot\]" ~/home/java/logs/gameserver.log | tail -3
```

⚠️ `bot fake` 以前硬编码 `senderId = 10000004`，那是个真实账号 —— 注入后客户端看到的是「那个号在说话」，
机器人再回复就像在替玩家回答。现在改成独立的 99990001，配置项 `fakeSenderUid` 可改，
但**不能填真实号段**（< 90000000），`normalize()` 会强制回退。

如果不想让机器人回某个号（比如你自己的 GM 号），把它加进 `ignoreUids`。

### 清掉测试注入的垃圾消息

`bot fake` 的发言会真的进世界队列，客户端里能看到。测完想收拾干净：

```bash
# 走隧道连测试服，先看要删什么
TS_REDIS_PORT=16379 TS_SERVER_ID=10001 python3 scripts/bot/clean_fake_chat.py --dry-run
TS_REDIS_PORT=16379 TS_SERVER_ID=10001 python3 scripts/bot/clean_fake_chat.py
```

默认清 `99990001`（假玩家号）和 `10000004`（旧版冒用的真实号），
并把假消息之后 180 秒内的机器人回话一起删掉（否则清完假消息会留下机器人自言自语）。
**只改 Redis**，服务端内存 MessageCache 要重启游戏服才刷新。

---

## 4. 配置（`conf/bot_config.json`）

改完 `bot reload` 生效。**任何字段缺失都会回落到内置默认值**，写错一个键不会把机器人搞挂。

| 字段 | 默认 | 说明 |
|---|---|---|
| `enabled` | true | 总开关 |
| `chatterEnabled` / `announceEnabled` / `replyEnabled` | true | 三个功能独立开关 |
| `virtualOnline` | true | 是否把机器人算进 `ONLINE_NUM` |
| `dshUrl` | `http://127.0.0.1:18765/reply` | 桥接地址；改成本机/内网均可 |
| `replyDelaySecMin/Max` | 8 / 25 | 「思考」延迟，**真人不会秒回** |
| `replyCooldownSec` | 25 | 同一频道两次回复最小间隔 |
| `replyMinGapSec` | 1200 | **两次 AI 回复之间的硬间隔**（20 分钟），防两个机器人前后脚各回一条 |
| `minSpeakGapSec` | 45 | **任意两条机器人发言**的最小间隔（喊话/回复/手动/晒卡互相避让），防刷屏 |
| `replyFreshSec` | 14400 | 只回 4 小时内的消息（= 醒来间隔上限，否则醒来时全过期，永远回不了） |
| `activeMinSec` / `activeMaxSec` | 1200 / 14400 | 🔴 **节奏总闸**：每个机器人独立随机「醒来」间隔 = 20~240 分钟 |
| `announceChancePct` | 40（线上 15） | 醒来时抽到「发英雄公告」的概率（%） |
| `chatterChancePct` | 40（线上 30） | 醒来时抽到「世界闲聊」的概率（%）；剩下的就是纯挂机 |
| `maxReplyChars` | 40 | 回复硬上限（按 code point 截断，尽量切在空格） |
| `contextHours` | 72 | 喂给 AI 的上下文时间窗 = **3 天** |
| `contextMaxLines` | 40 | 上下文最多带多少条 |
| `chatterMin/MaxSec` | 180 / 720 | 闲聊的额外下限（醒来还要再过这道闸才发） |
| `announceMin/MaxSec` | 1500 / 4500 | 公告的额外下限（同上） |
| `onlineFlipMin/MaxSec` | 600 / 1800 | 上下线抖动间隔，**每个机器人各自独立翻**（见 §4.5） |
| `wakeRetryMin/MaxSec` / `wakeRetryMaxTimes` | 180 / 480 / 3 | 🔴 醒来撞离线时 3~8 分钟重试，连试 3 次才认命（见 §4.5） |
| `idleTalkEnabled` / `idleTalkAfterSec` | true / 345600 | 🔴 真人 4 天没说话就算冷清：改由**另一个**机器人接话（见 §4.6） |
| `announceReactDelayMin/MaxSec` / `announceReactChancePct` | 60 / 180 / 40 | 公告后由**另一个在线机器人**接一句的延迟与概率（见 §4.4） |
| `chatterLines` / `idleReactLines` / `announceReactLines` | 15 / 10 / 6 句 | 三个语料池**共用同一条去重记忆**（最近说过的不再抽） |
| `realActionEnabled` / `realActionChancePct` | true / 50（线上 30） | 醒来时「真的升一级英雄 / 抽一个没有的英雄」的概率（改库，面板看得见） |
| `arenaEnabled` | true | 醒来时会不会顺路去打一场竞技场（**只打系统机器人**，见 §4.3） |
| `arenaChancePct` | 70 | 竞技场到期后真的开打的概率（%） |
| `arenaMin/MaxGapSec` | 14400 / 36000 | 同一个机器人两次竞技场的间隔 = **4~10 小时** |
| `arenaDailyMax` | 2 | 每个机器人每天最多打几场 |
| `arenaStopRank` | 2 | **不占前 N 名**（判的是打完之后的预计分数，榜上人少时放宽到「绝不第一」） |
| `arenaChaseTopPct` | 85 | 分数不许超过榜首的 85%，留明显距离 |
| `arenaMinGain` | 6 | 赢一场至少涨这么多分才值得打（Elo 打弱队几乎不涨分） |
| `bots[]` | Nova / Kai | uid、name、level、vip、head、frame、country、soulVal、persona |
| `fakeSenderUid` | 99990001 | `bot fake` 注入假玩家用的 uid，**不能落真实号段** |
| `ignoreUids` | `[10000004]` | 这些 uid 发言只进上下文、不触发回复（GM 号/测试号） |

机器人 uid 固定落在 **9xxxxxxx** 段（默认 90000001/90000002），与真实号段（1xxxxxxxx）天然隔开，
`isBotUid()` 靠这个判断「这条消息是不是自己人发的」，避免自问自答。

### 节奏：一个「醒来」总闸，管住所有行为

早期版本是三个独立定时器（喊话 3~12 分钟、公告 25~75 分钟、回复秒级），
结果是机器人比玩家还勤快，一眼假。现在改成**单闸**：

```java
// BotManager
private final Map<Integer, Long> nextActiveAt;   // 每个机器人各自的醒来时刻
private int nextActiveGapSec() {                 // 1200 ~ 14400 秒
    return config.activeMinSec + rnd.nextInt(
            Math.max(1, config.activeMaxSec - config.activeMinSec + 1));
}

private void maybeWake() {          // 每 15s tick 一次
    for (BotProfile p : bots.values()) {
        if (now < nextActiveAt.get(p.uid)) continue;
        nextActiveAt.put(p.uid, now + sec(nextActiveGapSec()));   // 先排下一次
        if (!online.contains(p.uid)) continue;                    // 不在线就跳过
        onActive(p);                                              // 醒来，做一件事
    }
}
```

`onActive()` 的优先级与概率：

| 顺序 | 条件 | 动作 |
|---|---|---|
| 1 | `replyEnabled` 且存在「没回过、且不超过 4 小时」的玩家消息，且过了 `replyMinGapSec` | 排一次 8~25 秒后的 AI 回话 |
| 2 | `arenaEnabled` 且**竞技场到期**（4~10 小时）且掷到 `arenaChancePct`（70%） | 去打一场竞技场（§4.3） |
| 3 | `roll < realActionChancePct`（50%） | 真的升一级英雄 / 抽一个还没有的英雄（改库） |
| 4 | `roll < realPct + announceChancePct` 且过了 `announceMinSec` | 抽个高星英雄发吉运公告 |
| 5 | `roll < realPct + announcePct + chatterChancePct` 且过了 `chatterMinSec` | 世界频道闲聊一句（本地语料） |
| 6 | 其余 | 纯挂机，什么都不发 |

首启给一次「1~5 分钟后」的预热活动，避免新服开起来半小时没人说话；之后才进入 20~240 分钟的正态节奏。
竞技场另有一条独立排期：**首启 3~25 分钟内错峰去一次**（方便部署后当场验证），之后进入 4~10 小时节奏。

**玩家说话不会立刻触发回复**：`onWorldChat` 只更新 `lastHumanMsgId/lastHumanText/lastHumanAt/lastHumanCountry`，
`schedulePendingReply()` 在醒来那一刻才检查「这条真人消息有没有被认领过」（见下面 §4.2 的账本）。

### 4.1 提示词里带了什么（2026-10-22 加）

模型只看得到「你叫 Nova」，就会问「这游戏怎么玩」或者吹「我全英雄满级」——玩家点开面板立刻穿帮。
现在 `BotManager.buildPrompt()` 固定喂四块：

| 块 | 内容 | 解决什么 |
|---|---|---|
| 人设 | `bots[].persona` / `config.persona` | 说话像谁 |
| **自己的账号** | `level / VIP / power / heroCount / cleared story stage X-Y / playing from 国家` | 回复里的进度和自己的面板对得上，不会一会儿萌新一会儿大佬 |
| **对方国籍 + 说话风格** | `The LAST MESSAGE is from Sakuya, a player from Japan (jp). Match how players from there usually text: ...` | 各国玩家的语气不同（日本人客气、巴西人外放、美国人懒散），不再全体「lol fr」 |
| **`(you)` 标注** | 上下文里自己之前发过的消息前缀 `(you)`，规则明令「不许回自己」 | 杜绝顺着自己的话往下接（自问自答） |

- 账号数据来自 `refreshProfiles()`：每 10 分钟在调度线程读一次 Mongo（走 GM 同一条 `AyyncWorker` 通道，不占 15s tick），
  读回 `playerManager.level/vipLevel/maxForce/country` + `alameinBattleManager.curFightId` + 英雄数。
  跑完 `UserManager.removeUser()`，不会让 3MB 的号一直挂在内存里。
- 关卡 id → `章-关` 的换算在 `BotText.formatStage()`（10101 → 1-1）。
- 国籍文案表在 `BotText.COUNTRY_STYLE`（45 国），查不到就用 ISO 码 + 中性兜底。
- 🔴 **语言永远跟随对方那条消息**，国籍只改语气/口癖。否则会出现「日本人用日语回英文玩家」的鸡同鸭讲。

### 4.2 「自己回复自己」是怎么修的（2026-10-22）

现象：世界频道里机器人连着刷 4 条，看着像它在自问自答，还白烧 token。根因是判重账本不对：

| 洞 | 后果 |
|---|---|
| 判据是 `lastHumanMsgId > lastBotMsgId` | 跨服频道 `sendBotChat` 返回 0（消息号由 chatserver 分配）⇒ `lastBotMsgId` 推不上去 ⇒ **同一条玩家消息每醒来一次就回一遍**（4 小时新鲜期内最多十几次） |
| 闲聊 / 晒卡 / 手动发言从不 push `lastBotMsgId` | 账面永远「有欠账」 |
| 只按 `bots.containsKey(uid)` 判机器人 | 别的服的机器人 uid 也是 9xxxxxxx 但不在本服名单 ⇒ 被当真人 |
| 上下文不区分「自己说的」 | 模型顺着自己的话接 |

修法（`ChannelState.repliedHumanMsgId` 认领账本）：

```java
// 接单那一刻就记账，不等发送成功 —— DSH 超时 / 发送失败 / 跨服没回包都不会再回同一条
st.repliedHumanMsgId.set(claimed);
// 发送后即使 msgId==0（跨服）也把 lastBotMsgId 推到位，看板不再显示「没回过」
st.lastBotMsgId.set(Math.max(msgId, claimed));
```

另外三道硬防护：`isBotUid()` 按号段兜底（9xxxxxxx，`fakeSenderUid` 例外）、
`isBotName()` 认名字（跨服 uid 被改写时兜底）、`fireReply()` 开头再判一次名字，是机器人就直接记账不发。

### 4.3 偶尔打一场竞技场（2026-10-22）

需求原话：**「被激活的时候要学会自己挑战符合能竞升规则的竞技场排行榜，次数不要太频繁，不要尝试登顶，低调一点。」**

实现落点：`BotManager.applyArenaAction()`（走 `AyyncWorker` → 玩家逻辑线程 → 落库，和 `doRealAction` 同一条通道）。
分数、次数、奖励、对手列表全是**真实数据**，玩家点开竞技场面板能看到这个号在榜上挪位置。

**四条硬规则（都不是给机器人开的后门，是复刻真人的）**

| 规则 | 代码 | 说明 |
|---|---|---|
| 用最强阵容 | `pickArenaTeam()` | 在「竞技场进攻 / 竞技场防御 / 主力」三套编队里按 `HeroLogic.calTeamTotalForce` 挑**战力最高**的那套。⚠️ 不能「存在即用」：克隆号经常只有防御编队填了 1 个英雄，Kai 就这么拿 1 人队去打机器人输了一场，换成主力编队后同一个对手就赢了 |
| 打得过才打 | `arenaRankBeatable()` | 对手总战力（`SArenaRobotConfig.totalForce`）超过己方编队战力的 **120%** 就跳过。所有机器人防守分都是默认值，只按积分筛等于没筛 |
| 能竞升才打 | `ArenaLogic.calScore(my, def, 1) >= arenaMinGain` | Elo：打比自己分低很多的赢了只涨 2~3 分，那种局跳过。机器人对手固定按默认分 1000 算（和 `ArenaChallengeHandler` 同口径） |
| 不登顶 | `arenaRankSafe()` | 用**打完之后的预计分数**反推：预计分数之上至少还要有 `arenaStopRank`（默认 2）个别人，且比较用**严格大于**（追平也算挤进同一档）。榜上人少时放宽到 1 ⇒ 永远不抢第一名 |
| 离榜首远 | `arenaCeiling()` = `max(默认分+50, 榜首 × arenaChaseTopPct%)` | 默认 85%。`myScore >= 封顶` 直接收手，日志写「已经够高，不往上爬了」 |
| 不频繁 | `arenaMin/MaxGapSec`（4~10h）+ `arenaDailyMax`（2/天）+ `arenaChancePct`（70%） | 三道叠起来：一天最多两场，且每场之间至少 4 小时 |

**额度与排期必须落盘**（`BOT_ARENA_STATE`）

「今日已打几场」和「下次什么时候」早先只在内存里，踩了一个很实的坑：**每发一次热补丁重启，
额度就归零、排期又回到 3~25 分钟的预热档** —— 一晚重启三次，机器人能打七八场，
跟「次数不要太频繁」正好相反。

现在写进 Redis：hash，key = `serverId:BOT_ARENA_STATE`，field = uid，
value = `"yyyyMMdd,count,nextAtMs"`。`init()` 里 `restoreArenaState()` 读回：
当天场次原样接着算，排期只在「还没到点」时才接管（过点的保持预热，别让重启立刻开打）。

```
[bot] Nova 竞技场状态恢复：今日已打 1 场，下次 15 分钟后
[bot] Kai  竞技场状态恢复：今日已打 1 场，下次 2 分钟后
```

**只打系统机器人，不碰真人。** 原因不是省事，是风险：打真人要同步改对方的
`ARENA_RRECORD`（被挑战战报）、扣对方分数、给对方发红点，还要在**别人的逻辑线程**里改别人的 `User`。
一旦哪一步写错，影响的是真人玩家的榜单和战报。机器人列表里通常是「真人 + 机器人补位」，
现在只从机器人里挑；整张列表都是真人就跳过（日志写「列表里只有真人」）。
以后要开 PVP，得先把防守方的战报/扣分/红点三段一起补齐再动开关。

**实测数据（测试服 10001，season 20）**

```
# 机器人榜上的对手列表（全是机器人，enemyType=0）
mongosh ... --eval 'db.user.findOne({_id:90000001},{arenaManager:1}).arenaManager.arenaEnemies'
→ [{291,0,0},{286,0,0},{290,0,0},{287,0,0},{289,0,0}]
# 挑战券够用：90000001 有 38 张、90000002 有 21 张（item 23）
```

按真实榜单（1311 / 1098 / 1016）跑一遍 Elo 推演，机器人从默认 1000 分起：

| 场次 | 分数 | 涨分 | 打完预计 | 名次安全 |
|---|---|---|---|---|
| 1 | 1000 | +16 | 1016 | ✅（头顶 3 人） |
| 2 | 1016 | +15 | 1031 | ✅ |
| … | … | … | … | … |
| 7 | 1086 | +12 | 1098 | ❌ 会追平榜二 ⇒ **收手** |

也就是：**两三天爬到榜三、停在榜二下面一格，之后不再动**，直到真人把分数往上抬（封顶跟着涨）。
这正是「低调」想要的效果 —— 榜上有活人味儿，又不会有人被机器人抢了名次。

> 2026-10-22 20:28 线上实测（部署后 GM 强制触发）：Nova 胜 robot#290 `1000 → 1016` 第 3 名、
> Kai 胜 robot#288 `1000 → 1016` 第 3 名；榜单 `1311 / 1098 / 1016(90000002) / 1016(90000001) / 1016(真人)`，
> 两个号都压在 1098 下面。⚠️ 注意同分时的排序：zset 同分按成员串反序，`9xxxxxxx` 排在 `1xxxxxxxx` 前面，
> 所以同分会把真人挤下去一名。如果介意，得再加一条「不许和真人同分」的判定（目前没加）。

**日志/看板**

```
[bot] Nova 竞技场 -> 胜 vs robot#290，1000 分 -> 1016 分，当前第 3 名
[bot] Kai  竞技场 -> 胜 vs robot#288，1000 分 -> 1016 分，当前第 3 名   # 换主力编队前同一对手是「负」
[bot] Nova 竞技场：1180 分已经够高（封顶 1114，榜首 1311），不往上爬了
[bot] Nova 竞技场：没有合适的对手（榜上 3 人，己方战力 115517；能涨分的会顶到封顶/名次，或对手都打不过/只有真人），跳过
```

调试用 GM 命令：`bot arena <uid>` —— 跳过排期和概率立刻打一场（额度/封顶/名次判定照旧），
打完会把下一次排期往后推 4~10 小时，免得手动测完十几分钟后又自然打一场。

`BOT_STATUS` 快照里新增：`bots[].arenaScore` / `arenaRank` / `nextArenaAt` / `nextArenaInSec` /
`arenaToday`，`stats.arenaFight` / `arenaWin`，`config.arena*`。
分数名次同时进 AI 提示词的「Your account: ... arena rank #N on this server」，
并明确要求**不许吹自己是第一**。

### 4.4 「自己接自己」的第二次修：晒卡换人 + 延迟（2026-10-23）

§4.2 修的是「AI 回复自己」，但线上玩家看到的「自问自答」其实是**另一条路**：公告后的晒卡。

老代码（`announceHero()` 尾部）：

```java
if (rnd.nextInt(100) < 40 && 过了 minSpeakGapSec) {
    String[] lines = { "finally got her lol", "took me forever", "worth it ngl",
                       "lucky pull fr", "gg rng", "back to grinding i guess" };
    sendBotChat(bot, CH_WORLD, lines[rnd.nextInt(lines.length)], false, "say");  // 同一个 bot
}
```

三个毛病叠在一起，玩家看到的就是「Nova 说自己抽到了 → Nova 又说终于到手了」：

| 毛病 | 后果 |
|---|---|
| 同一个 `bot` 发 | 公告是「我抽到卡」，下一句是「我 finally got her」= 字面自问自答 |
| **同一毫秒**发 | 中间没有任何「别人可能插话」的窗口，连成一串 |
| 6 句硬编码数组、**完全没去重** | 线上连着两天各说一次 `gg rng` |

现在的写法：**公告的人不许自己接话**，改成 60~180 秒后由「另一个在线机器人」说一句旁观者口吻的话
（`grats` / `gz` / `nice pull fr` / `lucky lol` / `wtf nice` / `gg rng lol`），两人都不在线就不说。

- 队列是 `pendingSays`（tick 里 `drainPendingSays()` 发），带 `excludeUid`，`pickOtherOnlineBot()` 挑人；
- 语料走 `announceReactLines`，和闲聊共用同一条 `recentChatter` 去重记忆；
- 日志：`[bot] 公告后 137 秒由另一个机器人接话 "grats"（不是 Nova 自己说）`
  → `[bot] 世界发言 bot=Kai mid=97 reply=false text="grats"`。

> 为什么保留「晒卡」这个动作而不是直接删掉：世界上「我抽到卡 → 队友一句 grats」是有互动感的；
> 「我抽到卡 → 我自己补一句」才是自问自答。差别只在**换人 + 延迟**。

### 4.5 醒来撞离线不再作废 + 上下线抖动改成 per-bot（2026-10-23）

```java
// 老写法：不在线就把下一次醒来推满 20~240 分钟 —— 一整次醒来全废
if (!online.contains(p.uid)) { nextActiveAt.put(p.uid, now + sec(gapSec)); continue; }
```

线上实测（10-22 06:35 → 10-23 11:07）：**Kai 21 次醒来里 13 次撞上自己离线（62%），Nova 只有 5/17（29%）**。
两人在线时长其实差不多（62% / 70%），所以不是谁被永久关掉，而是**空窗成块出现**：

`maybeFlipOnline()` 原来是「全局一个排期 + 随机挑一个号翻牌」，它是个**有记忆的随机游走**：

- 在线集合只剩一个人时，抽到他自己什么都不会发生（`size()>1` 才允许删），抽到另一个才会变两个；
- 要从「只有 A 在线」变成「只有 B 在线」，得**连续两次抽到指定的人**；
- 结果独苗身份非常黏 —— 日志里出现过连续 6 次都停在 `[90000001]`，另一个号被压离线 2.5 小时。

现在两道改：

1. `nextFlipAt` 改成**每个机器人各自的排期**（10~30 分钟独立翻），只额外保证「至少一个在线」；
2. 醒来撞离线 → `now + 3~8 分钟` 重试，连试 `wakeRetryMaxTimes`（3）次才回到正常节奏。
   日志：`[bot] Kai 醒来 -> 不在线，357 秒后重试（第 1/3 次）`。

### 4.6 冷清补话：四天没真人说话，让另一个机器人接话（2026-10-23，P2-8）

需求原话：**「如果四天没人说话，这个时候应该让另一个机器人说话。不要自问自答。」**

实现（`sayChatterOrContinue()` / `idleTalkTarget()`）：

| 条件 | 谁开口 | 说什么 |
|---|---|---|
| 不是冷清（真人最近说过话） | 醒来的那个 | `chatterLines` 随机一句 |
| 冷清 + 醒来的**不是**最后发言者 | 醒来的那个 | `idleReactLines`（接上一句） |
| 冷清 + 醒来的**正好是**最后发言者 | 另一个在线机器人 | `idleReactLines`；另一个不在线就**不说** |
| 世界上一条消息都没有 | 醒来的那个 | `chatterLines`（没有可接的话，正常开场） |

- 「冷清」= `now - lastHumanWorldAt >= idleTalkAfterSec`（默认 4 天）；历史里一个真人都没有也算冷清。
- 🔴 `lastHumanWorldAt` / `lastWorldSpeakerUid` **从 `CHAT_QUEUE:world` 还原**（`seedWorldLedger()`，init 时跑一次），
  否则每次重启都把冷清计时清零，四天阈值永远达不到。
  日志：`[bot] 世界频道账本还原：真人 32 小时前 | 机器人 Nova（3 小时前）`。
- `BOT_STATUS` 新增 `world` 块：`lastSpeakerName / humanIdleSec / idleTalk / pendingSays`，排查「怎么一直是同一个号」直接看这里。

### 防刷屏的五道闸

各来源（喊话 / AI 回复 / GM 手动 / 公告后换人接话 / 冷清补话）各自有间隔，但**不互相避让**时会挤在几秒内连发，
玩家看到的就是「机器人自说自话」。现在五道闸：

1. **醒来总闸**（`activeMin/MaxSec`）：一个机器人 20~240 分钟才醒一次，一次只做一件事。
   这是最粗也是最有效的一道 —— 频率根本高不起来。
2. `minSpeakGapSec`（45s）：`sendBotChat` 统一更新 `lastSpeakAt`，喊话和晒卡在动手前先看这个值，
   不够就顺延；`replyCooldownSec`（25s）管同一频道两次回复，`replyMinGapSec`（20 分钟）管全局。
3. `isBotUid()` / `isBotName()`：机器人自己的消息进 `onWorldChat` 只 bump `lastBotMsgId`，
   不更新 `lastHumanMsgId`，不触发回复。号段兜底是为了**别的服**的机器人（uid 同样是 9xxxxxxx）。
4. **认领账本 + 回调二次校验**：接单立刻写 `repliedHumanMsgId`，DSH 回来时若这个值已经不是自己认领的那个
   （期间被别的机器人重新认领过），这次回复直接丢弃 —— 不会对着自己的话再说一遍，也不会为同一条消息二次付费。
5. **换人 + 不自接**（10-23 加）：公告后的接话**必须换人**（`excludeUid`），冷清补话时醒来的是最后发言者
   就改让另一个在线号说、只剩自己在线就闭嘴。这条不是节流，是「不许自己跟自己聊」。

实测（临时把醒来间隔压到 60~120 秒验证链路）：

```
[bot] Kai 醒来 -> 不在线，继续挂机（下次 1 分钟后）
[bot] Nova 醒来 -> 回话
[bot] #1 请求 AI 回复 channel=world bot=Nova last="yo nova u still playin today"
[bot] 世界发言 bot=Nova mid=55 reply=true text="yeah lol just idlin rn"
```

`bot status` 会显示每个机器人的醒来倒计时，例如 `90000001:Nova(on),wake=43s | 90000002:Kai(off),wake=57s`；
控制台快照里也有 `nextWakeAt` / `nextWakeInSec`。

### 机器人账号数据（个人面板不空的关键）

**只配 uid/level 是不够的**：`user` 集合里没有这条文档，客户端点开机器人头像查不到玩家，
个人面板全空。要让面板有等级、战力、英雄、道具，必须往 `user` 集合里放一份真实玩家数据。

`scripts/bot/clone_bot_user.js` 做这件事：整份文档复制，把「指向自己的引用」全改掉
（`rootId`、`roleUid`、`_id`，`<uid><type><timestamp>` 形式的合成 map key，**以及同样形式的字符串值**），
再换掉 `nickName` / `openId`。

脚本里 `SPECS` 现在三条：`90000001/Nova`、`90000002/Kai`、**`99990001/Tester`**
（第三条是控制台「模拟玩家发言」用的假玩家，模板特意取 Kai 而不是 Nova，数据明显不同）。

```bash
scp scripts/bot/clone_bot_user.js gs:/tmp/
ssh gs 'cd /tmp && mongosh "mongodb://<user>:<pwd>@127.0.0.1:27017/m5_x1_game_10001?authSource=admin" \
  --quiet --file clone_bot_user.js'
# CLONE_DRY=1 只打印不落库；CLONE_FORCE=1 覆盖已存在的文档
```

🔴 **坑 1：`Date` / `NumberLong` 字段**。递归改写时如果把 BSON 特殊类型当普通对象遍历，
会被 `for...in` 拆坏，写回后服务端 `getUser` 直接抛 `MappingException`，整个玩家读不出来
（日志只有一行 `2-UserManager::getUser null exception<uid>`，不带堆栈时完全看不出原因）。
所以改写函数里 **`o instanceof Date` 必须最先返回**，再判断 `_bsontype`。

坑的第二个变种（2026-10-22 踩到）：**本地 `mongo` 4.0 shell 里的 `NumberLong` 没有 `_bsontype`**，
`isBson()` 判定失败 → 被 `for...in` 拆成
`{floatApprox, top, bottom, exactValueString, tojson}` 写回库，服务端报
`No mapping metadata found for long`，面板 500。判定：`$type` 看 `playerManager.createTime`
是不是 `object`（正常是 `long`）。修法：`isBson()` 里补
`v.floatApprox !== undefined || v.exactValueString !== undefined`，并加 `repairShellNumbers()`
把已经拆坏的对象还原成 `NumberLong`。

> 症状连带：坏文档体积会**翻倍**（每个 NumberLong 变 5 字段对象）。实测同一份 Kai 数据
> 正常 1.4MB、被拆坏 3.3MB —— 看到文档大小异常变大就该怀疑这个。

🔴 **坑 2：只改 map key、不改字符串值 → 面板「有头像有等级，编队 0 人、战力 0」**。
游戏里所有实例 id 都是 `uid + 类型 + 时间戳` 拼出来的字符串
（英雄 `10000002010017798801320000` = uid `10000002` + `010` + `017798801320000`）。
第一版只把 `heroManager.heroMap` 的**键**改成了 `90000001…`，而编队
`teamPosManager.teamPosForHero["1"].listTeamPosHeroInfo[].heroId` 是**值**，仍是 `10000002…`；
服务端 `getUserTeamOneInfo` 里 `user.getHeroManager().getHero(heroId)` 查不到 → 编队英雄全部被跳过。
现象：`name/level/vip/head` 都对，`force=0 heroes=0`。
修法：字符串值只要**以模板 uid 开头**就替换前缀，和 map key 用同一条规则。

验证（GM 端口，`bot team` 复刻客户端个人面板的服务端路径
`GET_PLAYER_ONE_TEAM_INFO(16650) → PlayerLogic.getOneTeamInfo(uid, FORMATION_NORMAL=1, 0)`）：

```bash
gm_client.py --port 17916 'oneuserinfo 90000001'
# 服务端日志应出现：cmd____uid 90000001_____level:50 nick:Nova

gm_client.py --port 17916 'bot team 90000001'
# 正常应出现（force/heroes 不能是 0）：
# [bot] team uid=90000001 name=Nova level=50 vip=1 head=71041 frame=80000 force=115517 heroes=5 support=2 country=ad
```

`bot team <uid>` 会**先 `UserManager.removeUser(uid)` 踢掉内存缓存**再读 Mongo，
所以改完库直接执行就能看到新数据，不用重启服务器。

配置里的 `level` / `vip` / `head` / `soulVal` **必须和 `playerManager` 里的一致**，
否则聊天条显示 lv62、点开面板 lv50，一眼假。改完 clone 记得把 `conf/bot_config.json`
的这四个值一起对齐（两个服各有一份，见坑 4）。

🔴 **坑 3：面板「打不开 / 整页空白 / 显示成上一个玩家」= 服务端 `getUser` 抛异常**。
`user` 集合里没有这条文档时，`getUserTeamOneInfo → UserManager.getUser(uid)` 抛
`1-UserManager::getUser null exception：<uid>`，`BaseHandler` 打一行 ERROR 后**不回包**。
客户端 `PlayerInfoPopup` 只在**收到回包的回调里**才刷新，收不到就表现为两种：

| 现象 | 触发条件 |
|---|---|
| 面板打不开 / 整页空白 | 第一次打开这个面板（prefab 还是空的） |
| **显示成上一个玩家的数据** | 之前点过别人，面板实例复用了旧数据（实测：点 Tester 弹出 Nova 的面板） |

第二种最容易被误判成「数据串号」，其实是**客户端残留**。**诊断口径**：在对应服的日志里搜
`protoID=16650`，有这行就是没数据，不是客户端问题：

```
ERROR BaseHandler - processWithProto Exception protoID=16650,uid=10000005,proto=>playerId: 99990001
 exception=java.lang.Exception: 1-UserManager::getUser null exception：99990001
	at com.ljsd.jieling.logic.dao.UserManager.getUser(UserManager.java:297)
	at com.ljsd.jieling.logic.player.PlayerLogic.getUserTeamOneInfo(PlayerLogic.java:812)
```

**两道修法（2026-10-22 都已落地）**：

1. **服务端兜底**（`handler/player/GetPlayerOneTeamInfo`）：`getOneTeamInfo` 外面包 try-catch，
   查不到就回一个**合法但空**的面板（uid + `name=uid 字符串` + level 1 + head 71000/frame 80000 +
   `team.totalForce=0`），把客户端旧数据覆盖掉。
   ⚠️ 兜底包的字段必须齐 —— 客户端 `FormationAdapter(teamInfo, allteaminfo)` 第一行就读
   `teamInfo.totalForce`，`team` 为 nil 会直接报错。
2. **给假玩家也建一份 user 文档**：`clone_bot_user.js` 的 SPECS 里第三条把 Kai(90000002)
   克隆成 `99990001 / Tester`，这样控制台「模拟玩家发言」点开是有内容的面板
   （lv40 / force 14678 / 5 个编队英雄），和 Nova 数据明显不同，不会看着像串号。

> `bot fake <任意名>` 的面板昵称固定是文档里的 `Tester`（聊天条显示的是消息里的 senderName），
> 调试用可以接受；要改就重跑 clone 并把 `name` 换掉。

🔴 **坑 4：本地服和测试服是两套库、两份 jar，只改一边等于没改**。
| | 本地自测服 | 测试服 |
|---|---|---|
| Mongo | `127.0.0.1:27017`（**4.0，wire version 7**） | 129.226.213.65（新版） |
| jar | `~/home/java/gameserver/gameSrv-1.0.0.jar`（launchd `com.ts.localserver.gameserver`） | `/home/java/gameserver/gameSrv-1.0.0.jar` |
| 重启 | `~/home/java/start-local.sh restart gs` | `bash RESTART-GAMESERVER.sh` |

- 本地 Mongo 4.0 太老，**mongosh 和 pymongo 4.19 都连不上**（一个要 wire 8、一个要 wire 9），
  `pymongo<4` 又没有 py3.13 的 wheel。所以本地灌数据走 **`mongodump` → scp → `mongorestore`**：
  ```bash
  ssh gs 'mongodump --uri="mongodb://…/m5_x1_game_10001?authSource=admin" -c user \
            -q "{\"_id\":{\"\$in\":[90000001,90000002]}}" -o /tmp/botdump'
  scp gs:/tmp/botdump/m5_x1_game_10001/user.bson /tmp/bot_user.bson
  mongorestore -h 127.0.0.1:27017 -u <user> -p <pwd> --authenticationDatabase admin \
               -d m5_x1_game_10001 -c user /tmp/bot_user.bson   # 本地 4.0 没有 --mode，_id 不冲突直接灌
  ```
- 本地 jar 是**另一份构建**，不能直接拿测试服的补丁 jar 覆盖。用 `compile_local.sh`
  （`BASE=~/home/java/gameserver/gameSrv-1.0.0.jar`）编译后 `zip -qr` 打回本地 jar，
  再 `start-local.sh restart gs`。否则本地还在跑老逻辑：`bot fake` 仍硬编码 10000004、
  没有 `minSpeakGapSec` 节流、没有 `pickChatterLine` 去重、也没有 `bot team` 命令。

---

## 5. DSH 桥接（`scripts/bot/dsh_bridge.py`）

```
POST /reply  {"prompt": "...", "maxChars": 40}
  -> {"text": "ya im on, bored af lol", "source": "dsh", "elapsedMs": 13644}
GET  /health -> provider/model/queue/busy/okCount/failCount
```

- **串行排队**（单 worker，队列上限 4）：绝不并发拉起多个 dsh 进程。
- 单次实测 **10~15 秒**（冷启动 + 推理），所以游戏服侧是异步的，不占 netty/逻辑线程。
- 失败/超时/队列满 → 立刻返回本地口语语料（`source=fallback-*`），**机器人永远有话说**。

### 🔴 模型坑位（2026-10-21 实测，改之前必读）

headless profile 默认 `provider=workbuddy / model=hy3`，从命令行调用**恒定 400**：

```
workbuddy upstream client (http 400): 请求被拦截，请重新发送
```

换 `provider=workbuddy-ai` + **屏蔽 CN 变体**（`WORKBUDDY_AUTH_FILE` 指到不存在的路径）后
同一句话立刻成功。根因和 TD 仓库 `utils/agent_channels/channels/deepseek_harness.py` 记的一致：
两个变体共用顺序 `syncAll()`，headless 跑完即退，排在后面的 AI 变体还没同步完就被查询。

桥接已经默认这么做了（`DSH_PROVIDER=workbuddy-ai`、`DSH_SUPPRESS_CN=1`），
通过 `--patch` 把模型写进叠加层，**不改 profile 文件**，不影响你日常用 DSH 桌面端。

```bash
# 自检
scripts/bot/start_bridge.sh status
DSH_TIMEOUT=60 python3 scripts/bot/dsh_bridge.py --once "say hi"   # 单次直跑
```

---

## 6. 文案规则（`BotText` / `sanitize`）

1. 只取第一行；剥 `"reply:"` / 引号 / `<color>` 标签；
2. 英文做整词口语化：`you→u`、`your/you're→ur`、`thanks→thx`、`because→cuz`、`people→ppl`、
   `right now→rn`、`to be honest→tbh`、`i don't know→idk`……（**只按整词替换**，不会把 `young` 改成 `ung`）；
3. 按 code point 截到 40，优先切在空格上；
4. 中文消息 → 中文短句，英文消息 → 英文短句（语言跟随最后一条）。

---

## 7. 验证清单（本地服已全绿）

| 项 | 证据 |
|---|---|
| 初始化 | `[bot] 初始化完成 enabled=true reply=true bots=2` |
| 世界发言 | `[bot] 世界发言 bot=Nova mid=15 ... text="hello world from nova"`，Redis `10001:CHAT_QUEUE:world` 里能解出 `Nova / 0|hello world from nova` |
| AI 回话 | 注入 `any1 on? need help with boss` → 14.4s 后回 `on me lol wut boss` |
| AI 回话（第二次） | 注入 `do u know where to farm gold` → 14.5s 后回 `daily quests ngl or gold dungeon lol`（36 字符） |
| 英雄公告 | `[bot] 英雄公告 bot=Nova hero=10059 star=5`，sys 队列解出 `25010009 / Nova / 5 / \|02010057` |
| 在线数 | 无真人时 `redis-cli get ONLINE_NUM:10001` = `1` |
| 自动喊话 | 启动后 180s 自动出一条 `who got the new hero alrdy` |

---

## 8. 坑位 / 已知限制

1. **虚拟机器人没有 Mongo user 文档**：点它头像查资料 / 加好友会查不到（这是「虚拟」的代价）。
   要「点得开」就得改真账号 + 无头客户端，本机 2C/3.6G 吃不下，别轻易换方案。
2. **不要给世界频道补占位消息**（`MessageCache.fillMinKeep` 的注释已经写过）：世界频道客户端按
   `"<type>|..."` 解析，纯文本占位会让主界面 `string.format(...,nil)` 抛异常。机器人发的是
   `"0|正文"`，格式正确，别图省事直接塞纯文本。
3. **`ONLINE_NUM` 会影响登录服 `recommend`**：`GetServerListController` 在 `state==2 且 ONLINE_NUM>0`
   时会把「在线最多的服」放进推荐位。测试服开机器人后这个条件会成立 —— 老客户端有
   `level > levelLs` 的 nil 比较崩溃史（见 `.workbuddy/memory/2026-10-21.md`），上线上前先在测试服验登录面板。
4. **DSH 必须和游戏服同机**（或改 `dshUrl` 指到能跑 dsh 的机器）：线上 CentOS 只有 2C/3.6G，
   再跑 node 版 dsh 不现实 —— 上线前要么把 `dshUrl` 指向你本机（需要反代/内网），要么只开
   `chatter/announce/virtualOnline`，`replyEnabled=false` 让它走本地语料。
5. **回复有 8~25 秒「思考」延迟 + 10~15 秒模型耗时**，一条回复最坏 ~40 秒才出现在世界频道。
   这是刻意做的（真人也要看消息、打字），不是卡了。再加上「20~240 分钟才醒一次」，
   所以玩家说话后可能几十分钟才被回 —— **这是设计，不是 bug**，别拿「秒回」当验收标准。
6. **机器人不会追着旧消息回**：超过 `replyFreshSec`（默认 4 小时）就放弃。
   这个值必须 ≥ `activeMaxSec`，否则醒来时消息全过期，会表现为「怎么永远不回话」。
7. **跨服频道（chatType=16）需要 `isOpenCross`**；没开跨服时机器人只在本服世界频道活动。
8. **别把 `activeMin/MaxSec` 调太小当压测**：临时调 60~120 秒验链路可以，验完必须改回
   `1200/14400` 重新部署，否则测试服会变成刷屏现场。
9. **账号快照是 10 分钟一刷的**：`refreshProfiles()` 读一次是 3MB 的库文档，不能跟着 15s tick 跑。
   机器人刚升完级、聊天里还按旧等级说话是正常现象。当前快照看 `BOT_STATUS.bots[]` 的
   `stageText / power / heroCount / profileAt`（`profileAt=0` = 还没读到，提示词里会省略这几项）。

---

## 9. 可视化控制台（推荐日常用它，别啃日志）

```bash
scripts/bot/start_console.sh start     # 起服务
open http://127.0.0.1:18766/           # 看板
scripts/bot/start_console.sh status    # 探活：serverId/在线/机器人数/聊天条数/bridge/gm
```

页面四块，2 秒轮询一次：

| 区域 | 看什么 |
|---|---|
| 顶栏 | serverId、在线数（`真实 + 虚拟`，hover 看拆分）、DSH 成功/失败、provider/model、总开关、快照新鲜度（>60s 变黄） |
| 左列 | 机器人卡片：在线点、uid/等级/VIP/国旗、人设、`说一句` / `公告` 按钮 |
| 中列 | 世界频道实时流：`BOT`/`玩家` 标签、等级国旗、**字符数**（一眼看出有没有超 40） |
| 右列 | 回复流水线（世界/跨服两条：玩家最后一句 → 待回复/思考中/已回复 → 机器人 mid）、指标（AI 回复数/兜底率/平均·最大耗时/喊话/公告）、DSH 耗时曲线、事件流 |
| 底栏 | `模拟玩家发言`（等价 `bot fake`）、`机器人说话`、`英雄公告`、`强制回复`、`重载配置` |

数据来源（都是只读，不改游戏服状态）：

```
Redis  serverId:BOT_STATUS      ← 游戏服 BotTask 每 15s 写的快照（开关/在线/指标/事件，TTL 300s）
Redis  serverId:CHAT_QUEUE:world ← 世界频道消息（protobuf，控制台自己解，不依赖 proto 工具）
HTTP   127.0.0.1:18765/health    ← 桥接的 provider/model/排队/成功失败
GM     thrift 7916               ← 只有「操作按钮」才走这条
```

- 依赖只有 `thrift`（走 GM 用）；`start_console.sh` 会自动挑
  `~/.workbuddy-ai/binaries/python/envs/default` 这个带 thrift 的隔离环境，找不到就退回 `python3`。
  没 thrift 时看板照常能看，只有按钮会报错。
- Redis 走裸 RESP、protobuf 手写 varint 解码 —— **不需要装 redis-py / protobuf**，拷到测试服也能直接跑。
- 事件流 40 条环形缓冲，类型：`回复/喊话/说话/公告/玩家/开关/手动`；回复事件带 `source`（dsh/fallback）和耗时。

---

## 10. 测试服（129.226.213.65）部署流程

测试服的 **7916(GM) / 6379(Redis) 只监听 127.0.0.1**，而 DSH 必须跑在本机 Mac 上。
所以是「三条转发 + 本地控制台」的结构：

```
本机 17916 ──正向──▶ 测试服 127.0.0.1:7916   GM 命令
本机 16379 ──正向──▶ 测试服 127.0.0.1:6379   在线数/聊天队列/BOT_STATUS
测试服 18765 ◀─反向── 本机 127.0.0.1:18765   游戏服回连 DSH 桥接
```

三条转发**放在一个 ssh 连接里**（`ExitOnForwardFailure=yes` 保证一条失败就整体退出，
状态可判）。别拆成三个后台 ssh —— 拆开时进程会被父 shell 回收，出现「pid 还在但端口不通」的假活。

```bash
# ① 本机起桥接（游戏服侧只是 HTTP 客户端，桥接挂了会走本地语料兜底）
scripts/bot/start_bridge.sh start
curl -s --noproxy '*' http://127.0.0.1:18765/health     # ok:true, provider=workbuddy-ai

# ② 隧道：另开一个终端窗口前台挂着（最可靠）
scripts/bot/testserver.sh fg

#    想放后台用 up，但它可能被拉起它的 shell 回收；up 现在会探端口而不是只看 pid，
#    被回收会直接报「失败或被父 shell 回收」并提示改用 fg。
scripts/bot/testserver.sh up
scripts/bot/testserver.sh status      # gm/redis up + PONG + 反向回连 JSON + 控制台
```

`status` 里的「反向回连」是**问测试服自己** `curl 127.0.0.1:18765/health`，
不能探本机 18765 —— 那是桥接本体，探了永远是 up，说明不了隧道通不通。

### 打补丁（本地编译 → 上传 → 重启）

```bash
cd TimeSpaceServer/Server_x1tag1.2.2/server_game/serverlogic/src/main/java

# 关键：用【测试服那份 jar】当 classpath 基准 + -implicit:none
#   不加 -implicit:none 会把 sourcepath 里的 thrift 等依赖一起编出来（几十个类，容易和线上版本不一致）
#   不用测试服 jar 而用本地 jar 当基准，可能带上本地独有的差异
scp gs:/home/java/gameserver/gameSrv-1.0.0.jar /tmp/bot_patch/gameSrv-ts.jar
javac -nowarn -encoding UTF-8 -source 8 -target 8 \
  -cp "$HOME/home/java/gameserver/lib/*:/tmp/bot_patch/gameSrv-ts.jar" -implicit:none \
  -d /tmp/bot_patch/classes \
  com/ljsd/jieling/bot/{BotProfile,BotConfig,BotText,DshClient,BotManager,BotTask}.java \
  com/ljsd/jieling/kefu/Cmd_bot.java \
  com/ljsd/jieling/chat/logic/ChatLogic.java \
  com/ljsd/jieling/thread/ThreadManager.java \
  com/ljsd/jieling/thread/task/MinuteTask.java
# 应为 19 个 class（含内部类）。字节码版本校验：xxd -l 8 <class> → cafe babe 0000 0034（0x34=52=Java8）

cd /tmp/bot_patch/classes && cp ../gameSrv-ts.jar ../gameSrv-patched.jar
find . -name '*.class' | sed 's|^\./||' | zip -q -u ../gameSrv-patched.jar -@

# 备份 + 上传 + 配置 + 重启
ssh gs 'cd /home/java/gameserver && cp gameSrv-1.0.0.jar gameSrv-1.0.0.jar.bak-<日期>-bot'
scp /tmp/bot_patch/gameSrv-patched.jar gs:/home/java/gameserver/gameSrv-1.0.0.jar
scp TimeSpaceServer/Server_x1tag1.2.2/server_game/conf/bot_config.json gs:/home/java/gameserver/conf/
ssh gs 'md5sum /home/java/gameserver/gameSrv-1.0.0.jar'      # 与本机 md5 对齐再重启
ssh gs 'cd /home/java/gameserver && bash RESTART-GAMESERVER.sh'   # 约 40s，自带自检
```

重启脚本自检判据：**实例数=1 / Authentication failed=0 / Address already in use=0**。
`WorldChat (rPCClient is null) > 0` 属正常（测试服 chatserver 没起，不影响登录）。
重启前先确认在线人数：`redis-cli keys 'ONLINE_NUM:*'`。

### 控制台

```bash
scripts/bot/testserver.sh console      # 带隧道端口起控制台
open http://127.0.0.1:18766/
```

### 验证顺序（2026-10-21 实测通过）

| 步骤 | 命令 / 动作 | 期望 |
|---|---|---|
| 1 | `redis-cli -p 16379 get 10001:BOT_STATUS` | JSON，`virtualOnline:1`，`bots[0].online:true` |
| 2 | `redis-cli -p 16379 get ONLINE_NUM:10001` | `1`（真人 0 + 虚拟 1） |
| 3 | `gm_client.py --port 17916 'bot fake any1 on? need help with boss'` | 世界频道出现 `any1: on? need help with boss` |
| 4 | 等 20~40s | Nova 回 `on, wut boss u stuck on lol`（15.5s，27 字符，走 dsh） |
| 5 | `bot say test from nova` | 事件流 `manual`，世界频道出现该条 |
| 6 | `bot announce` | 事件流 `announce`，`channel=sys`，`hero#<id> star=<n>` |
| 7 | `bot status` 看 `wake=xx` | 每个机器人都有醒来倒计时；到点日志出现 `醒来 -> 回话/公告/闲聊/挂机` |

> 第 4 步的「等 20~40s」只在**临时把醒来间隔调小**时成立。默认配置下机器人 20~240 分钟才醒，
> 要验回复链路请用 `bot fake` 之后**把 `activeMin/MaxSec` 临时改成 60/120** + `bot reload`，
> 验完立刻改回 `1200/14400`（`bot reload` 即可，不用重启）。

实测数据（测试服 10001，首轮）：AI 回复 15.5s，兜底率 0%，世界队列 8 条历史恢复，
`bot fake` 注入 → 回复全链路一次成功；反向隧道 `curl /health` 返回 `okCount` 递增。
节奏重构后本地复验：`Nova 醒来 -> 回话` → 世界发言 `yeah lol just idlin rn`（DSH 重复句已被
`BotText.collapseRepeat()` 吃掉）。

**回滚**：`cp gameSrv-1.0.0.jar.bak-<日期>-bot gameSrv-1.0.0.jar` + 重启；
或配置里 `enabled:false` + `bot reload`（不用重启，立即哑火）。

---

## 11. 线上注意（同一台机，先灰度）

1. 线上只有 **127.0.0.1:7916** 的 GM 端口，验证要开隧道：`ssh -N -L 17916:127.0.0.1:7916 gs`。
2. 热补丁沿用 runbook：`zip -u` 就地替换 class，**不要整包重打**；重启会踢线，先确认在线人数。
3. 线上 2C/3.6G，`dsh_bridge` 不要跑在服务器上（node + 模型推理扛不住），
   建议 `replyEnabled=false` 先只上「在线数 + 喊话 + 公告」，或者把 `dshUrl` 指向内网的另一台机器。
   🔴 **2026-10-23 实测过这个坑**：线上 `replyEnabled` 一直是 true，但 `127.0.0.1:18765` 根本没监听
   （`ss -lntp` 只有 7916），于是每条「AI 回复」都在 20ms 内退化成 `BotText.EN_FALLBACK` 那 26 句固定短句
   （日志 `source=fallback`）。已经改成 `replyEnabled=false`；要开 AI 回话，**先把桥接起起来再改回去**。
   关掉后 §4.6 的冷清补话照常工作，不依赖 DSH。
4. 首次上线保持 `activeMinSec/activeMaxSec = 1200/14400`（20~240 分钟）的躺平节奏，
   先观察一天日志里有没有重复文案、有没有玩家抱怨；觉得太冷清就把 `activeMaxSec` 往下调，
   **不要**去动 `chatterMinSec`（那只是醒来后的第二道闸，改它治不了冷清）。
5. 排查「怎么一直是同一个号在说话」：先看 `BOT_STATUS` 的 `world` 块（`lastSpeakerName` / `idleTalk` /
   `pendingSays`）和每个 bot 的 `nextWakeInSec`，再对日志 `醒来 ->` 那一行 ——
   `醒来 -> 不在线，N 秒后重试` 说明撞了离线（§4.5），不是被代码锁死。
