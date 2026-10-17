# GM 指令滥用 / 玩家作弊 处置手册

> 更新时间：2026-10-18
> 配套：`server_ops_runbook.md`（生产环境事实）、`scripts_reference.md`（脚本清单）
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

配置文件 `config/logicSrv.properties` 第 14 行长期为 `true`（随包发布，非被入侵篡改）。
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

### 1.4 附带发现（非作弊，是产品 bug）

`HeroLogic.upHeroLevel()` **不读取请求里的 `targetLevel`**，只把当前等级 +1。
玩家连续发送 `targetLevel: 6/11/16/21/26`，服务端每次都写回 `level 4`，
再叠加 `if (hero.getStar() < config.getLimitStar()) throw HERO_LEVE_MAX` 的星级门槛，
导致英雄永久卡在 4 级。改 GM 阈值时**不要**把这个正常玩家的升级请求一并当作作弊行为。

---

## 2. 排查步骤（可复制）

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

```bash
# 1. 备份
ssh gs 'cp -a /home/java/gameserver/config/logicSrv.properties \
  /root/incident_$(date +%Y%m%d)/logicSrv.properties.bak.$(date +%H%M%S)'

# 2. 改
ssh gs 'sed -i "s/^server\.debug = true/server.debug = false/" \
  /home/java/gameserver/config/logicSrv.properties && \
  grep -n "^server.debug" /home/java/gameserver/config/logicSrv.properties'

# 3. 重启（幂等脚本，自带自检：实例数/认证/端口/OOM）
ssh gs 'cd /home/java/gameserver && sh RESTART-GAMESERVER.sh'
```

重启后自检应全部通过：

| 检查项 | 期望 |
|---|---|
| gameserver 实例数 | 1 |
| Authentication failed | 0 |
| Address already in use | 0 |
| OutOfMemoryError | 0 |
| 16081 端口 | 正常监听 |

**代价**：关闭后**内部人员也无法使用 GM 功能**。
后续若要恢复 GM 能力，正确做法是给 `GMRequestHandler` 加**账号白名单鉴权**
（而不是把 `debug` 再打开）。

🔴 **本地仓库同步**：`TimeSpaceServer/skzc/home/java/gameserver/config/logicSrv.properties`
必须一并改成 `false` 并提交，否则重新部署会把漏洞配置推回线上。

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
echo "--- 6. debug 已关 ---";   grep "^server.debug" /home/java/gameserver/config/logicSrv.properties
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
| `HeroLogic.upHeroLevel` 忽略 `targetLevel` | 所有玩家英雄卡 4 级 | 按目标等级循环升级或直接计算消耗 |
| `fightResDiffLog` 只覆盖 UID ≤10000140 | 高 UID 改战斗结果检测不到 | 扩大到全部 UID |
| `playerManager.ip` 恒为空 | 游戏库查不到登录 IP | 在游戏服侧记录 `session.getIp()` |

---

## 8. 附：本次事件处置记录（2026-10-18）

| 项目 | 值 |
|---|---|
| 作弊账号 | UID `10000240`「Sieg」，openId `go1060321172` / `6d748af4bce0432c97a6142181a370fc` |
| 封禁手段 | `FORBID_LOGIN` 名单 + IP 封禁（2 个）+ 数据删除 + 排行榜移除 |
| 漏洞修复 | `server.debug: true → false`，重启自检全通过 |
| 备份位置 | 服务器 `/root/incident_20261018/` |
| 误伤检查 | 通过（Mozart 等玩家 itemLog 完整） |
