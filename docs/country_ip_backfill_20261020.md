# 玩家国籍按 IP 批量回填（2026-10-20）

> 一句话：线上 205/208 个玩家没有 `country`，用访问日志里的 IP + GeoLite2 反推，
> **已写入 36 个**，5 个纯机场 IP 待人工确认，164 个无 IP 证据（保留窗口外）。
> 脚本：`scripts/backfill_player_country.py`（默认 dry-run）。

---

## 1. 为什么"没有国籍"

| 事实 | 数值 | 说明 |
|---|---|---|
| 玩家文档总数 | 208 | `m5_x1_game_10001.user` |
| 有 `playerManager.country` | 3 | `ad` / `hk` / `cn`，都是玩家在面板里手选过 |
| 缺 `country` | 205 | 字段**整个不存在**（不是空串） |
| `playerManager.ip` 非空 | **0** | 208 个全是 `""` |

🔴 **根因**：`PlayerManager.setIp()` 只在 `UserManager.initPlayer()`（建号）时调用一次，
而登录链路传进来的 `ip` 参数本来就是空串 ⇒ 服务端从来没记过 IP。
所以国籍不是"丢了"，是**从来没有过**。

`country` 的写入路径只有一条：客户端 `SetPlayerCountryRequest` → `SetPlayerCountryHandler`
→ `playerManager.setCountry()`（两位小写 ISO，`xx` 为其他地区）。玩家不点面板就一直是空。

---

## 2. IP 从哪来（旁路日志）

服务端库和 Redis 都没有 IP，只能从两份日志反推：

| 源 | 路径 | 保留 | 能给什么 |
|---|---|---|---|
| Tomcat 访问日志 | `/home/java/loginserver/.../localhost_access_log.*.txt` | **31 天**（09-20 起） | `openId` + 客户端 IP + 时间 |
| 游戏服日志 | `/data/srvlog/gameserver.log*` | ~3 天 | `uid` + 直连 IP（`channelInactive` 行） |

`openId → uid` 走登录库 `user_info`，**必须按 `serverId=10001` 过滤**——
同一个 openId 会同时挂在 10001/10002 两条记录上（实测 4 个重复），不过滤会串号。

访问日志样例：

```
91.235.225.35 - - [20/Oct/2026:13:03:31 +0800] "GET /tk/getUserInfo?openId=2f7a...&serverId=10001..." 200 52
```

---

## 3. 判定方法

1. 每个玩家的全部 IP 按**出现次数加权投票**，票最多的国家即归属国；
2. 私网 / 回环 / 保留地址直接丢弃；
3. **机房 / 机场 ASN 降权**：有住宅 IP 时**只用住宅 IP 投票**；全是机房 IP 的玩家
   默认跳过（`--include-vpn` 可强写）；
4. 查不到国家的 IP 不猜，直接跳过（客户端有 `xx` 兜底，宁可留空不写假数据）。

IP 库：`GeoLite2-Country.mmdb` + `GeoLite2-ASN.mmdb`（P3TERX 免 key 镜像），
首次运行自动下到 `~/.cache/ts-geo/`。

### 为什么必须做机房判定

线上大量 IP 落在 **AS134972 IKUUU NETWORK LTD**（知名机场）：

```
103.151.172.28  → HK   AS134972 IKUUU NETWORK LTD
103.151.173.208 → JP   AS134972 IKUUU NETWORK LTD
```

这类玩家的"IP 归属国"是**节点落地国**，不是人在哪。直接写 `hk`/`jp` 会让中国玩家挂日本旗，
比留空更糟。实测 41 个有证据的玩家里只有 5 个是纯机房 IP，其余都是真实运营商
（KDDI、Taiwan Mobile、Viettel、Claro、Saudi Telecom、Kyivstar…），所以这个过滤代价很小。

---

## 4. 本次结果

| 项 | 数量 |
|---|---|
| 缺国籍 | 205 |
| 有 IP 证据 | 41 |
| **已写入** | **36** |
| 跳过：纯机房/机场 IP | 5 |
| 跳过：无任何 IP 证据 | 164 |

写后校验：`有国籍 39 / 总 208`（3 个原有 + 36 个新写）。

国家分布（36 个）：`jp:5, br:5, tw:4, us:4, vn:3`，其余 `ua/sa/kr/iq/fr/la/bg/ca/de/dk/id/ch/lk/cn/sg` 各 1。

### 待人工确认（VPN 落地国）

| uid | 昵称 | lv | IP 判定 | ASN |
|---|---|---|---|---|
| 10000001 | RandyFan | 24 | jp | IKUUU NETWORK LTD |
| 10000049 | 罗伊安德烈 | 2 | hk | IKUUU NETWORK LTD |
| 10000199 | Dyuun | 2 | us | Datacamp Limited（PIA VPN） |
| 10000232 | 所罗门莱恩 | 10 | hk | IKUUU NETWORK LTD |
| 10000234 | FinnBowen | 1 | ph | Google LLC（云主机） |

要一并写入：`python3 scripts/backfill_player_country.py --apply --include-vpn`。

### 164 个无证据的为什么补不了

访问日志只保留 31 天（09-20 起），这 164 个玩家最后一次登录早于这个窗口，
游戏服日志也只留 3 天。**没有任何 IP 痕迹可查**，不是脚本漏了。

其中 58 个是 11 级以上老号——他们下次登录时会重新落进访问日志，届时重跑脚本即可补上。

---

## 5. 用法

```bash
# 只分析，打印 + 出 CSV（默认）
python3 scripts/backfill_player_country.py

# 单号排查
python3 scripts/backfill_player_country.py --uid 10000017

# 真写：mongodump 备份 → bulkWrite → 写审计集合
python3 scripts/backfill_player_country.py --apply

# 连机场 IP 的也写
python3 scripts/backfill_player_country.py --apply --include-vpn
```

依赖：本机 ssh 已配 `Host gs`；`pip install geoip2`。

- 报告 CSV：`scripts/logs/country_backfill_<时间戳>.csv`（含每个玩家的 IP、票数、ASN、是否机房）
- 审计集合：`m5_x1_game_10001.gm_country_backfill`（uid/country/share/ips/asn/evidence/ts）
- 幂等：filter 带 `"playerManager.country":{$in:["",null]}`，**已有国籍的绝不覆盖**

### 回滚

```bash
# 方式一：整集合回滚（备份是写入前的快照）
mongorestore --uri "$URI" --drop --collection user \
  /root/ts-country-backup-<时间戳>/m5_x1_game_10001/user.bson

# 方式二：只清掉本次写的（审计集合里有 uid 清单）
db.user.updateMany({_id:{$in:[...]}},{$unset:{"playerManager.country":""}})
```

本次备份：`/root/ts-country-backup-20261020-131519`（111M）。

---

## 6. 注意 / 后续

| 项 | 说明 |
|---|---|
| **在线玩家看不到旗** | 写的是库，服务端内存里的 `PlayerManager.country` 还是空 ⇒ 该玩家**重登后**才生效（其他人看到的是排行榜下发的实时值，重登后也正常） |
| **IP 口径 ≠ 真实国籍** | 跨境、出差、VPN 都会偏；这是 IP 归属地的固有误差，报告里保留了每个 IP 供复核 |
| **建议补登录 IP 落库** | 在 `LoginRequestHandler` 里加一行 `playerManager.setIp(session远端地址)`，以后就不用靠访问日志考古了；**要重启游戏服（会踢线），需单独确认** |
| **可做成每日任务** | 脚本幂等，挂 cron 每天跑一次即可自动补新玩家；属于系统变更，未擅自安装 |
