# 虚拟玩家（机器人）：在线数 / 世界喊话 / 英雄公告 / AI 回话

> 更新时间：2026-10-21
> 关联：`server_ops_runbook.md`（线上热补丁口径）、`scripts/bot/dsh_bridge.py`（DSH 桥接）、
> `scripts/bot/start_bridge.sh`（启停）、`TimeSpaceServer/Server_x1tag1.2.2/server_game/conf/bot_config.json`（配置）
> 一句话：**服务端内存里养 1~2 个虚拟玩家，撑起后台在线数、世界频道人气和英雄公告；
> 世界频道出现玩家发言时，把近 3 天上下文丢给本机 DSH，回一句 40 字符以内的真人味儿短句。**

---

## 0. 它解决什么

| 现象 | 机器人做的事 |
|---|---|
| 测试服/新服 `ONLINE_NUM=0`，后台看板上一个活人都没有 | 把在线机器人叠加进 `ONLINE_NUM`（后台、登录服 `recommend` 都读这个 key） |
| 世界频道 7 天没人说话，像鬼服 | 每 3~12 分钟让一个机器人在世界频道说句话 |
| 抽卡没有「别人也在抽」的氛围 | 每 25~75 分钟发一条吉运公告（复用真实玩家公告链路，名字换成机器人） |
| 玩家在世界上说话没人接 | 最新一条玩家消息**如果机器人没回过**，8~25 秒后由 DSH 生成一句短回复 |

---

## 1. 数据流（为什么不需要改客户端）

```
玩家发世界(chatType=1)
   └─ ChatLogic.sendChatMessage
        ├─ MessageCache.addWordMsg(chatInfo, mid)      ← 客户端拉取式聊天，读这里
        └─ BotManager.onWorldChat(chatInfo, mid, "world")   ← 新增钩子
              └─ 记 lastHumanMsgId / 排一条 replyDueAt

chatserver 跨服回包(chatType=16)
   └─ ChatLogic.sendChatMessage(chatInfo, mid)
        ├─ MessageCache.addCrossMsg(...)
        └─ BotManager.onWorldChat(..., "cross")

BotTask（15s 一拍）
   ├─ maybeChatter   → 造 ChatInfo("0|文案") → addWordMsg → 客户端下一次拉取就能看到
   ├─ maybeAnnounce  → ChatLogic.sendSysChatMessage(lamp_lottery_content, LUCKY_LUCK, heroId)
   ├─ maybeReply     → 拼 3 天上下文 → POST DSH 桥接 → 洗文案 → 同上发世界
   └─ maybeFlipOnline→ 随机上下线，让在线数看起来是活的
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
| `bot fake <名字> <文本>` | **造一条真人发言**，没有客户端也能验证 AI 回话链路 |
| `bot reply` | 跳过等待立刻回一次 |

```bash
PY=/Users/wangxufeng/.workbuddy-ai/binaries/python/envs/default/bin/python   # 需要 thrift 包
$PY scripts/gm_client.py 'bot fake Mia do u know where to farm gold'
sleep 30; grep "\[bot\]" ~/home/java/logs/gameserver.log | tail -3
```

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
| `replyCooldownSec` | 25 | 两次回复最小间隔，防刷屏 |
| `replyFreshSec` | 600 | 超过 10 分钟的旧消息不再追着回 |
| `maxReplyChars` | 40 | 回复硬上限（按 code point 截断，尽量切在空格） |
| `contextHours` | 72 | 喂给 AI 的上下文时间窗 = **3 天** |
| `contextMaxLines` | 40 | 上下文最多带多少条 |
| `chatterMin/MaxSec` | 180 / 720 | 日常喊话间隔 |
| `announceMin/MaxSec` | 1500 / 4500 | 英雄公告间隔 |
| `onlineFlipMin/MaxSec` | 600 / 1800 | 上下线抖动间隔（至少保留 1 个在线） |
| `bots[]` | Nova / Kai | uid、name、level、vip、head、frame、country、soulVal、persona |

机器人 uid 固定落在 **9xxxxxxx** 段（默认 90000001/90000002），与真实号段（1xxxxxxxx）天然隔开，
`isBotUid()` 靠这个判断「这条消息是不是自己人发的」，避免自问自答。

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
5. **回复有 8~25 秒延迟 + 10~15 秒模型耗时**，一条回复最坏 ~40 秒才出现在世界频道。
   这是刻意做的（真人也要看消息、打字），不是卡了。
6. **机器人不会追着旧消息回**：超过 `replyFreshSec`（默认 10 分钟）就放弃，避免半夜没人时堆一堆延迟回复。
7. **跨服频道（chatType=16）需要 `isOpenCross`**；没开跨服时机器人只在本服世界频道活动。

---

## 9. 上线（129.226.213.65）注意事项

1. 线上只有 **127.0.0.1:7916** 的 GM 端口，验证要开隧道：`ssh -N -L 17916:127.0.0.1:7916 gs`。
2. 热补丁沿用 runbook：`zip -u` 就地替换 class，**不要整包重打**；重启会踢线，先确认在线人数。
3. 线上 2C/3.6G，`dsh_bridge` 不要跑在服务器上（node + 模型推理扛不住），
   建议 `replyEnabled=false` 先只上「在线数 + 喊话 + 公告」，或者把 `dshUrl` 指向内网的另一台机器。
4. 首次上线把 `chatterMinSec` 调大（比如 600~1800），先观察一天日志里有没有重复文案、有没有玩家抱怨。
