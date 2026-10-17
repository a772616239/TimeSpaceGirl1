# GM 指令滥用 / 玩家作弊 处置手册

> 更新时间：2026-10-18
> 配套：`cheat_detection_skill.md`（**判定**：这号是不是挂）、`server_ops_runbook.md`（生产环境事实）、`scripts_reference.md`（脚本清单）
> 分工：**`cheat_detection_skill.md` 判「是不是挂」，本文管「确认了之后怎么封」。**
> 一键排查：`python3 scripts/cheat_scan.py --uid <UID>` / `--hunt`（全服扫）
> 一句话定位：**发现玩家数据异常 → 怎么确认是作弊 → 怎么封 → 怎么修漏洞 → 怎么验。**

---

## 0. 🔴 红线

1. **`server.debug` 在正式服必须为 `false`。** 这是本文档存在的根本原因（见 §1 事故复盘）。
2. **删账号不等于封号。** 本服登录逻辑是「查不到 user 就自动建档」，删数据他下次登录会重建。
   真正的封禁是 **`FORBID_LOGIN` 名单**（§3.1）。
3. **动手前先备份**：账号文档、日志、Redis 相关 key、排行榜快照、iptables 规则。
   本仓约定备份目录 `/root/incident_<日期>/`。
4. **封 IP 只是临时止血**，动态公网 IP 会重新分配，不能当长期手段（§3.2）。
5. **改完必须两边同步**：服务器改了配置，本地仓库 `TimeSpaceServer/` 同步改并提交，
   否则下次重装/重部署会把漏洞配置再推上去。

---

## 1. 事故复盘：2026-10-18 Sieg 事件

### 1.1 现象

玩家「Sieg」（UID `10000240`）账号创建 30 分钟内达到 100 级、战力 378 万（全服第一），
但**主线只推到 20 关**，与其战力严重不符。

### 1.2 定位证据链

| 证据 | 数据 |
|---|---|
| 账号创建 | `2026-10-12 15:08:30` |
| GM_REQUEST 次数 | **114 次**（全服其他玩家仅 3~12 次且为新手引导） |
| GM 指令时段 | `15:41:58 ~ 15:45:16`（约 3 分钟） |
| 典型指令 | `4#11xxx#13`（刷道具）×86、`1#3#2000000000`（单条 20 亿资源）×4 |
| 资源现状 | `item 14 = 2,000,648,040`（正常玩家为千级） |
| 登录 IP | `180.254.113.1`（印尼电信）、`103.210.35.108`（日惹政府机构出口） |
| 平台 | `platform=PC`，但走安卓登录链路（`plat=android`），设备字段**全为空** |

> 设备指纹全空 + `platform_s: PC` + 能发 GM 指令 ⇒ **自建/改版客户端在直接构造协议**。

### 1.3 根本原因（两个，缺一不可）

**根因 A：正式服 `server.debug = true`**

配置文件 **`jar 内置 application.properties`** 第 14 行长期为 `true`（随包发布，非被入侵篡改），
而线上的 `config/logicSrv.properties` 虽然也是 `true`，但**它根本没被加载**（见 §4 顶部说明）。
真正生效的就是 jar 内置那份 ⇒ 运行时 `debug=true`。
而 `GMRequestHandler.processWithProto()` 的**唯一**校验是：

```java
if (!GameApplication.serverProperties.isDebug()) {
    throw new ErrorCodeException("In a formal setting");
}
// 之后直接执行 command，无 GM 账号白名单、无 IP 限制、无签名校验
```

**结论：`debug=true` 等于对所有玩家开放 GM 控制台。**

**根因 B：作弊检测存在盲区**

`fightResDiffLog`（服务器结果 vs 客户端结果比对）只覆盖 UID `10000002 ~ 10000140`，
高 UID 玩家（如 `10000240`）**完全没有比对日志**，改战斗结果查不出来。

### 1.4 第二类作弊：业务接口缺少频次校验（同日发现）

**这与 §1.3 的 GM 漏洞是两种完全不同的手法，GM 关了也防不住。**

玩家 Mozart（UID `10000013`）在 `2026-10-18 00:07` 的 **1 分钟内连发 35 次**
`ADVENTURE_REWARD_REQUEST{type:2, position:-1}`，最短间隔 **0.3 秒**。

| 判据 | 数据 |
|---|---|
| 单次产出 | **777,600 钻石** + item3/14/79 等 20 余种物品 |
| 当日奖励笔数 vs 第二名 | **33 vs 6**（5.5 倍） |
| 钻石总量 vs 全服中位数 | **125,634,740 vs 200**（约 62.8 万倍） |
| `777600` 这个数值 | **全服仅他一人**，重复出现 6 次 |

根因在 `CombatLogic.takeNewAdventureReward()`：
- `type != 2` 分支会走 `PlayerLogic.checkAndUpdate(user, 4, 1)`，**有次数校验**
- `type == 2` 分支只调 `getNewAdventureReward()` 算奖励后**直接下发，无任何次数/冷却/进度校验**

修复见 `TimeSpaceServer/patches/adventure_reward_guard/`（Javassist 注入频次护栏）。

> 💡 **排查启示**：GM 指令计数为 0 **不等于**没作弊。
> Mozart 的 GM_REQUEST 只有 3 次（正常新手引导），作弊走的是普通业务接口。
> 必须同时看：奖励发放笔数（`itemLog.reason=1`）、单笔数量级、同数值的独有性。

### 1.5 附带发现（非作弊，是产品 bug）

`HeroLogic.upHeroLevel()` **不读取请求里的 `targetLevel`**，只把当前等级 +1。
玩家连续发送 `targetLevel: 6/11/16/21/26`，服务端每次都写回 `level 4`，
再叠加 `if (hero.getStar() < config.getLimitStar()) throw HERO_LEVE_MAX` 的星级门槛，
导致英雄永久卡在 4 级。改 GM 阈值时**不要**把这个正常玩家的升级请求一并当作作弊行为。

---

## 2. 排查步骤（可复制）

> 🔴 **本节是「确认到账号」的最短路径。想要完整的三层判定（GM 通道 / 业务接口 / 数据自洽）、
> 阈值、误判陷阱与四个真实样本的回归集 → 看 `cheat_detection_skill.md`。**
>
> 一键版：
> ```bash
> python3 scripts/cheat_scan.py --uid 10000240     # 单号裁决
> python3 scripts/cheat_scan.py --hunt             # 全服扫可疑
> ```

### 2.1 从现象到账号

```bash
# 日志里按昵称找改名记录 → 拿到 UID
ssh gs 'grep "Sieg" /data/srvlog/gameserver.log | grep RENAME_REQUEST'

# 确认账号基础信息
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
var u = db.user.findOne({_id: 10000240});
printjson(u.playerManager);"'

# 全服战力排名对照（判断是否离群）
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
db.user.find({},{_id:1,\"playerManager.nickName\":1,\"playerManager.level\":1,\"playerManager.maxForce\":1,
  \"playerManager.createTime\":1}).sort({\"playerManager.maxForce\":-1}).limit(12).forEach(function(d){
  print(d._id + \" \" + d.playerManager.nickName + \" lvl\" + d.playerManager.level +
        \" force=\" + d.playerManager.maxForce + \" created=\" +
        new Date(Number(d.playerManager.createTime)).toISOString());});"'
```

### 2.2 🔴 关键一步：统计 GM_REQUEST

**这是最直接、最不会误判的作弊信号。**

```bash
# 按 UID 统计 GM 指令次数
ssh gs 'grep "type GM_REQUEST" /data/srvlog/gameserver.log \
  | sed -E "s/.*uid ([0-9]+).*/\1/" | sort | uniq -c | sort -rn | head -20'

# 看某玩家用了哪些指令（正常玩家只会有 10#1#0 / 10#2#0 / 10#3#0 这组新手引导）
ssh gs 'grep "type GM_REQUEST" /data/srvlog/gameserver.log | grep "uid 10000240" \
  | sed -E "s/.*command\": \"([^\"]*)\".*/\1/" | sort | uniq -c | sort -rn'
```

指令格式为 `项目#参数#数量`：

| 前缀 | 含义 |
|---|---|
| `1#` | 货币/资源（`1#3#2000000000` = 单个资源给 20 亿） |
| `4#` | 加道具/装备（`4#<itemId>#<num>`） |
| `7#` `8#` `9#` `28#` | 解锁 / 等级 / 功能类 |
| `10#1#0` ~ `10#3#0` | **正常新手引导**，大量玩家都有，不要误判 |

### 2.3 取 IP 与平台（游戏库拿不到，必须查登录服日志）

```bash
# 游戏库的 playerManager.ip 是空字符串，不可用！
ssh gs 'grep -h "go1060321172" \
  /home/java/loginserver/apache-tomcat-8.5.95/logs/localhost_access_log.*.txt \
  | sed -E "s/^([0-9.]+) - - \[([^]]*)\] \"([A-Z]+) ([^ ?]+)[^\"]*\".*/\1 | \2 | \4/"'
```

关联账号时按 `userName=` / `openId=` 反查，确认**没有同伙账号**：

```bash
ssh gs 'for f in /home/java/loginserver/apache-tomcat-8.5.95/logs/localhost_access_log.*.txt; do
  grep -hE "180\.254\.113\.1|103\.210\.35\.108" "$f"; done \
  | grep -oE "userName=[a-zA-Z0-9]+|openId=[a-zA-Z0-9]+" | sort | uniq -c'
```

IP 归属地查询（本机执行）：

```bash
curl -s "http://ip-api.com/json/180.254.113.1?fields=status,country,regionName,city,isp,as,proxy,hosting&lang=zh-CN"
```

---

## 3. 封禁处置

### 3.1 ✅ 正确方式：`FORBID_LOGIN` 名单（唯一真正有效的封号）

服务端自带封号机制，**不需要改任何代码**：

```
客服 GM 指令 Cmd_addblack
    → 写 Redis Hash「10001:FORBID_LOGIN:」（key = serverId + ":" + name + ":"）
    → thread.task.MinuteTask 每分钟调 ProtocolsManager.minuteCheckForbidUser()
    → 加载进 Blocker.forbidLogin（内存集合）
    → network.server.AuthManager 在 token 校验通过后调 Blocker.checkForbidUser()
    → 命中：踢下线 + 拒绝登录
```

手动写入（等价于 `Cmd_addblack <uid>`）：

```bash
ssh gs 'redis-cli -n 0 HSET "10001:FORBID_LOGIN:" 10000240 0'
ssh gs 'redis-cli -n 0 HGETALL "10001:FORBID_LOGIN:"'    # 校验
```

> ⚠️ **易踩的坑**：`handler.LoginRequestHandler` 里**没有**调用 `checkForbidUser`，
> 别照着它判断「封号无效」。真正的拦截点在 `network.server.AuthManager`，
> 全 jar 里只有 `AuthManager` 和 `Blocker` 引用该方法。

> ✅ 该名单存 Redis，**重启游戏服不丢**（`MinuteTask` 会重新加载）。

**用完后如需解除封禁**：`redis-cli -n 0 HDEL "10001:FORBID_LOGIN:" 10000240`

### 3.2 ⚠️ IP 封禁（临时止血，非长期方案）

```bash
# 先备份规则，可回滚
ssh gs 'mkdir -p /root/incident_$(date +%Y%m%d) && \
  iptables-save > /root/incident_$(date +%Y%m%d)/iptables.backup.$(date +%H%M%S)'

# 入站 + 出站都封
ssh gs 'for ip in 180.254.113.1 103.210.35.108; do
  iptables -I INPUT -s $ip -j DROP; iptables -I OUTPUT -d $ip -j DROP; done'

# 校验
ssh gs 'iptables -L INPUT -n --line-numbers | head -8'
```

**局限（必须知道）**：
- 家庭宽带是**动态 IP**，重新分配后他换个 IP 就能进，且可能误伤后续被分配到该 IP 的无辜玩家。
- 机构/共享出口 IP（如 `103.210.35.108` 是日惹政府通信局的 NAT 出口）封了会**误伤该机构所有人**。
- 本机防火墙是 `policy ACCEPT` 全开、`firewalld`/`ufw` 均未启用，`iptables` 规则**重启后会丢**，
  需要 `iptables-save > /etc/sysconfig/iptables` 或 `service iptables save` 才能持久化。

### 3.3 ❌ 不要用：删账号

本服登录逻辑「查不到就自动建档」：

```
[ERROR] MongoUtil#279 - the user=10000240 not exists
[INFO]  AbstractActivity - [青龍秘宝初始化] [uid:10000240,id:805]     ← 立刻开始建号
```

登录库 `x1_cn_test_login` 有 246 条账号、游戏库 `user` 只有 214 条，
**32 个「登录库有、游戏库没有」的账号，一登录就会重建**。

删了 `user` 文档他下次登录会拿到一个空白账号继续玩，**等于没封**。

---

## 4. 关掉漏洞源头：`server.debug`

> 🔴 **必须先读：改 `config/logicSrv.properties` 是无效操作。**
>
> `RESTART-GAMESERVER.sh` 启动时**不带** `--spring.config.location`，
> 所以 Spring Boot 只按默认顺序找 `./config/application.properties` → `./application.properties`，
> **`logicSrv.properties` 从头到尾没有被加载过**（`serverbuild.md` 里那条带
> `--spring.config.location=config/logicSrv.properties` 的启动命令是历史写法，与现网脚本不符）。
>
> 实证：2026-10-18 00:34 那次重启前已把 `logicSrv.properties` 改成 `false`，
> 但启动日志仍是 `debug=true`；01:10 改的是 `config/application.properties` 才变成 `debug=false`。
>
> 正确做法只有一条：**在 `config/application.properties` 里覆盖**（外部配置优先级高于 jar 内置）。

```bash
# 1. 备份
ssh gs 'cp -a /home/java/gameserver/config/application.properties \
  /root/incident_$(date +%Y%m%d)/application.properties.bak.$(date +%H%M%S)'

# 2. 改（追加，不覆盖已有的 Mongo 凭据行）
ssh gs 'cd /home/java/gameserver && \
  grep -q "^server.debug" config/application.properties \
    && sed -i "s/^server\.debug *=.*/server.debug=false/" config/application.properties \
    || printf "\n# 关闭 GM 调试通道（覆盖 jar 内置 true）\nserver.debug=false\n" >> config/application.properties
  grep -n "^server.debug" config/application.properties'

# 3. 重启（幂等脚本，自带自检：实例数/认证/端口/OOM）
ssh gs 'cd /home/java/gameserver && sh RESTART-GAMESERVER.sh'
```

**第 4 步（不可省）：用运行时真值验证，不能只 grep 配置文件**

```bash
ssh gs 'grep -a "ServerProperties ->" /data/srvlog/gameserver.log | tail -1' \
  | grep -o 'debug=[a-z]*'
# 期望输出：debug=false
```

`ServerProperties` 是 Spring 把配置真正绑定到 Bean 后由 `GameApplication` 打出来的，
它才是「服务实际认为的 debug 值」。**只 grep 配置文件等于没验证**——
上一轮就是栽在「文件改了、实际没生效」上。

重启后自检应全部通过：

| 检查项 | 期望 |
|---|---|
| gameserver 实例数 | 1 |
| `ServerProperties` 里 `debug=` | **false**（关键） |
| Authentication failed | 0 |
| Address already in use | 0 |
| OutOfMemoryError | 0 |
| 16081 端口 | 正常监听 |

**代价**：关闭后**内部人员也无法使用 GM 功能**。
后续若要恢复 GM 能力，正确做法是给 `GMRequestHandler` 加**账号白名单鉴权**
（而不是把 `debug` 再打开）。

🔴 **本地仓库同步**：线上改的是 `config/application.properties`，所以入库的也必须是它。
⚠️ 该文件含 Mongo 明文口令，而本仓是 **PUBLIC** 仓库 —— 入库前先脱敏，
真实口令只留在线上和 `docs/secrets_setup.md` 描述的 `.secrets/` 链路里。
（`logicSrv.properties` 也改 `false` 仍然值得做：无害且能防止将来有人恢复带
`--spring.config.location` 的旧启动命令时漏掉。）

---

## 5. 数据清理与排行榜

### 5.1 备份（改动前必做）

```bash
ssh gs 'mkdir -p /root/incident_20261018 && cd /root/incident_20261018
# 注意：mongoexport 要严格 JSON，用 queryFile 避免 shell 转义问题
printf "%s" "{\"_id\": 10000240}" > q_user.json
printf "%s" "{\"uid\": 10000240}" > q_uid.json
mongoexport -d m5_x1_game_10001 -c user    --queryFile q_user.json -o sieg_user.json
mongoexport -d m5_x1_game_10001 -c itemLog --queryFile q_uid.json  -o sieg_itemLog.json
mongoexport -d m5_x1_game_10001 -c heroLog --queryFile q_uid.json  -o sieg_heroLog.json
# 排行榜快照（含作弊者原始名次，便于还原）
redis-cli -n 0 ZREVRANGE "10001:common_force_rank:" 0 -1 WITHSCORES > backup_common_force_rank.txt
redis-cli -n 0 ZREVRANGE "10001:MAIN_LEVEL_RANK:"   0 -1 WITHSCORES > backup_main_level_rank.txt'
```

> 💡 `mongoexport` 100.9.0 不接受 `{_id: 10000240}` 这种宽松语法，
> 也容易被 SSH 转义破坏，**务必用 `--queryFile` + 严格 JSON**。

### 5.2 清理范围

```bash
# Redis：撤登录令牌 + 清会话 key
ssh gs 'redis-cli -n 0 DEL "JL_TOKEN:10000240" "JL_USER_SERVER_INFO:go1060321172" \
  "USER_LOGIN_URL:10000240" \
  "null:INDICATION_OFFLINE_INDEX:10000240" "null:LEVE_DIFFICULTY_INFO:10000240" \
  "PIDGIDTEMP:10000240" "null:RESPONSE_OFFLINE:10000240"'

# MongoDB：删游戏数据（保留登录库记录，别删，删了会重新注册）
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
db.user.deleteOne({_id:10000240});
db.itemLog.deleteMany({uid:10000240});
db.heroLog.deleteMany({uid:10000240});
db.storeLog.deleteMany({uid:10000240});
db.fightLog.deleteMany({uid:10000240});"'

# 登录库：标记封禁但保留记录
ssh gs 'mongo --quiet x1_cn_test_login --eval "
db.user_info.updateOne({uid:10000240}, {\$set:{banned:true,
  banReason:\"GM指令作弊\", banTime:new Date(), bannedOpenId:\"go1060321172\"}});"'
```

### 5.3 🔴 排行榜：只删作弊者条目，不要清空整榜

Redis db0 共约 6753 个 key，其中**约 4900 个是排行相关**，绝大多数是**正常玩家的历史成绩**
（`VirtualBattle_SELF_RECORD` 1647、`GAMELEVEL_*_RECORD` 各 524、`ARENA_TODAYLIKE` 221 …）。
**全清会让全服玩家排行归零，且部分数据 Mongo 里没有备份、不可恢复。**

只移除作弊者的名次：

```bash
ssh gs 'redis-cli -n 0 ZREM "10001:common_force_rank:" 10000240
        redis-cli -n 0 ZREM "10001:MAIN_LEVEL_RANK:"   10000240'
```

> ⚠️ **只删 Redis 不够**：`user.playerManager.maxForce` 里还存着他的战力，
> 重启或回填后会重新上榜。因此必须先删 `user` 文档（§5.2），再清 Redis。

### 5.4 🔴🔴 删号后必须清理全部引用，否则排行榜直接崩

**这是 2026-10-18 实际踩到的坑，删号后排行榜打不开。**

症状：玩家点排行榜报错，服务端日志出现
```
java.lang.Exception: 1-UserManager::getUser null exception：10000013
    at ...HeroForceRank.getFirst(HeroForceRank.java:69)
    at ...RankLogic.getRankFirstInfo(RankLogic.java:113)
    at ...RankFirstHandler.processWithProto(RankFirstHandler.java:23)
```

原因：删了 `user` 文档，但**排行榜里还留着他的条目**。`getFirst()` 取到第 1 名后
调 `UserManager.getUser(uid)` 拿到 null，紧接着 `everyUser.getHeroManager()` 空指针。

`HeroForceRank.getFirst()` 的关键逻辑（反编译）：
```java
Set<...> rankByKey = this.getRankByKey(...);
if (rankByKey.size() != 1) return builder;      // 只有恰好 1 条时才继续
ZSetOperations.TypedTuple<String> data = rankByKey.iterator().next();
String[] arr = StringUtil.getStringList(data.getValue(), ":");
int uid = Integer.parseInt(arr[0]);
User everyUser = UserManager.getUser(uid, true);   // ← 已删账号在这里返回 null
Hero hero = everyUser.getHeroManager().getHero(heroId);  // ← NPE
```

**注意成员是 `<uid>:<heroId>` 复合格式**，用 `ZREM key <uid>` 删不掉，
必须按成员全串删：

```bash
# 正确做法：先扫出所有匹配成员再删
redis-cli -n 0 ZRANGE "10001:HERO_FORCE_RANK:" 0 -1 | grep "^10000240:"
redis-cli -n 0 ZREM "10001:HERO_FORCE_RANK:" "10000240:10000240010017917911100000"
```

**删号后必须清理的三类引用**（缺一个就 NPE）：

| 类型 | 位置 | 清理方式 |
|---|---|---|
| ZSET 排行成员 | Redis 全部 `*RANK*` 等 zset，成员可能为 `<uid>` 或 `<uid>:<heroId>` | 扫 `ZRANGE` 后逐个 `ZREM` |
| **Mongo 排行表** | `supremacyInfo` 的 `uid` 字段（**最容易漏！**） | 置为 `uid: 0` 保留空位，或删整条 |
| 其他业务引用 | `guildInfo`/`supremacyInfo`/任务/邮件等 `uid`/`targetUid`/`rootId` | 全库扫描确认 |

**一键清理脚本**（本仓已用于本次事故，清了 74 个残留成员）：

```bash
ssh gs 'cat > /tmp/cleanrank.sh <<"SHEOF"
#!/bin/bash
DEL="10000240 10000153 10000013"      # ← 换成要清的 uid
total=0
for key in $(redis-cli -n 0 --scan --pattern "*" 2>/dev/null); do
  [ "$(redis-cli -n 0 TYPE "$key" 2>/dev/null)" = "zset" ] || continue
  [ "$(redis-cli -n 0 ZCARD "$key" 2>/dev/null)" = "0" ] && continue
  for d in $DEL; do
    redis-cli -n 0 ZRANGE "$key" 0 -1 2>/dev/null | grep "^${d}:" | while IFS= read -r m; do
      redis-cli -n 0 ZREM "$key" "$m" >/dev/null 2>&1; total=$((total+1))
    done
    redis-cli -n 0 ZSCORE "$key" "$d" >/dev/null 2>&1 && redis-cli -n 0 ZREM "$key" "$d" >/dev/null 2>&1
  done
done
echo "清理成员数: $total"
SHEOF
sh /tmp/cleanrank.sh'
```

Mongo 侧：

```bash
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
// 把指向已删账号的排行条目置为空位（保留 rank/pos 结构）
db.supremacyInfo.find().forEach(function(d){
  if (d.uid && d.uid !== 0 && db.user.count({_id: d.uid}) === 0) {
    db.supremacyInfo.updateOne({_id: d._id}, {\$set: {uid: 0}});
    print(\"清零 _id=\" + d._id + \" 原 uid=\" + d.uid);
  }
});"'
```

**验证顺序**：改完后先 `ZRANGE`/`supremacyInfo` 确认无已删 uid，
再让玩家点一次排行榜，看日志有无 `UserManager::getUser null exception`。

> 💡 **教训**：删号不是删 `user` 表就完了。这个游戏有大量反范式冗余
> （排行、supremacy、公会、邮件都存 uid），**删号前应先扫全库+全 Redis 找出所有引用**。

---

## 6. 验收清单

```bash
ssh gs '
echo "--- 1. 封号名单 ---";     redis-cli -n 0 HGETALL "10001:FORBID_LOGIN:"
echo "--- 2. IP 封禁 ---";      iptables -L INPUT -n | grep DROP
echo "--- 3. 数据已删 ---";     mongo --quiet m5_x1_game_10001 --eval "
  print(\"user: \"+db.user.count({_id:10000240}));
  print(\"itemLog: \"+db.itemLog.count({uid:10000240}));"
echo "--- 4. 排行榜已清 ---";   redis-cli -n 0 ZSCORE "10001:common_force_rank:" 10000240
echo "--- 5. Redis 无残留 ---"; redis-cli -n 0 --scan --pattern "*10000240*" | wc -l
echo "--- 6. debug 已关（运行时真值）---"
grep -a "ServerProperties ->" /data/srvlog/gameserver.log | tail -1 | grep -o "debug=[a-z]*"
echo "--- 6b. 外部配置落盘 ---"; grep "^server.debug" /home/java/gameserver/config/application.properties
echo "--- 7. 服务健康 ---";     redis-cli -n 0 GET "ONLINE_NUM:10001"
'
```

全部符合预期才算收工。**另外别忘了检查有没有误伤**：

```bash
# 确认其他玩家数据完好（对比清理前）
ssh gs 'mongo --quiet m5_x1_game_10001 --eval "
print(\"Mozart itemLog: \"+db.itemLog.count({uid:10000013}));"'
```

---

## 7. 遗留问题（待排期）

| 问题 | 影响 | 建议 |
|---|---|---|
| `GMRequestHandler` 无身份鉴权 | 一旦 `debug` 被误开，任何玩家可刷 | 加 GM 账号 UID 白名单 + IP 白名单双条件 |
| **`server.debug` 定义在 3 处，jar 内置那份优先级最高** | 只改 `config/logicSrv.properties` **无效** | 必须在 `config/application.properties` 覆盖，并按 §4 用 `ServerProperties` 日志验证 |
| `ADVENTURE_REWARD type=2` 无频次校验 | 可无限连领远征奖励 | 已打补丁（`patches/adventure_reward_guard/`），但需转正到源码 |
| `HeroLogic.upHeroLevel` 忽略 `targetLevel` | 所有玩家英雄卡 4 级 | 按目标等级循环升级或直接计算消耗 |
| `fightResDiffLog` 只覆盖 UID ≤10000140 | 高 UID 改战斗结果检测不到 | 扩大到全部 UID |
| `playerManager.ip` 恒为空 | 游戏库查不到登录 IP | 在游戏服侧记录 `session.getIp()` |
| 其他 `type` 分支是否同样缺校验 | 未知，可能还有同类洞 | 建议对全部 `take*Reward` 类接口做一次频次审计 |

---

## 8. 附：本次事件处置记录（2026-10-18）

本轮共处置 **3 个作弊账号**，分属 **3 种不同作弊手法**：

| 账号 | 手法 | 关键证据 | 处置 |
|---|---|---|---|
| `10000240` Sieg | **GM 指令刷资源** | 114 条 `GM_REQUEST`（`4#`/`1#`），20 亿资源 | 封号 + IP 封禁 ×2 + 删数据 + 移出排行 |
| `10000153` 稀拉拉梵妮 | **直改库伪造关卡进度** | `fightId=15405` 但真实只 45 关，`fightStateInfo` 仅 1 个非零；**GM 指令 0 次** | 封号 + 删数据 + 移出排行 |
| `10000013` Mozart | **业务接口无频次校验** | 1 分钟连领 `type=2` 35 次，每次 77 万钻石；**GM 指令仅 3 次（正常）** | 封号 + 删数据 + 移出 4 个排行 + **打补丁** |

### 漏洞修复

| 漏洞 | 修复 |
|---|---|
| `server.debug=true`（GM 无鉴权） | 在 `config/application.properties` 覆盖为 `false`，**用 `ServerProperties` 日志验证 `debug=false`** |
| `ADVENTURE_REWARD type=2` 无频次校验 | Javassist 注入 `AdventureRewardGuard`（3 秒间隔 / 每日 5 次） |

### 备份位置

服务器 `/root/incident_20261018/`：
- `sieg_*.json`、`p153_*.json`、`m13_*.json`（三个账号完整快照）
- `gameSrv-1.0.0.jar.bak.*`（打补丁前的原始 jar）
- `logicSrv.properties.bak.*`、`application.properties.bak.*`
- `iptables.backup.*`、`mozart_adventure_abuse.log`（作弊原始日志）

### 误伤检查

通过。清理后确认其他玩家数据完整（如 `itemLog` 计数正常），在线人数未受影响。
