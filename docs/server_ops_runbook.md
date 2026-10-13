# 服务端 & 区服运维 Runbook

> 更新时间：2026-10-12
> 配套：`scripts_reference.md`（脚本清单）、`serverbuild.md`（原始架设文档）
> 一句话定位：**生产服怎么连、区服怎么开、线上怎么改、改完怎么验。**

---

## 0. 🔴 红线

1. **巡检默认只读**：不重启服务、不改服务器配置。报告必须有量化证据（错误数/阈值），
   区分「🔴 严重 / ⚠️ 关注」。
2. **重启生产游戏服（会踢线）必须先取得用户确认。**
3. **改线上优先热补丁（`jar uf` / `zip -u`），不要整包重打重部署。**
4. **`conf/` 绝不能整目录覆盖**（混着 hotfix.json / lua-hotfix.json / c_database_version.json /
   plat-configure.json + `checkout_db|mem*.txt` 玩家结算落盘）。
5. **脚本改线上前先备份**（`~/ts-*/` 里的脚本都自带 backup 或 rollback 子命令）。

---

## 1. 生产环境事实

| 项 | 值 |
|---|---|
| 服务器 | 腾讯云 CentOS7，公网 `129.226.213.65`，内网 `10.3.0.15` |
| SSH 别名 | `gs`（`~/.ssh/config`）；私钥优先取工程本地 `.secrets/tencent-gameserver.pem`，回退 `~/.ssh/tencent-gameserver.pem` |
| 规格 | **2 vCPU / 3.6GB RAM / 59G 盘 —— 已榨干，不能再起第二个 gameserver** |
| 服务目录 | `/home/java/{gameserver,loginserver,chatserver,xxljob}` |
| 游戏服 | `gameSrv-1.0.0.jar`，netty **16081**，`-Xms1280m -Xmx1280m` |
| 登录服 | Tomcat 8.5.95，**8080** |
| Mongo | 27017（由宝塔管） |
| Redis | 6379，**无密码**，`bind 127.0.0.1` |
| Nginx | 由宝塔管 |
| 日志 | `/data/srvlog/{gameserver,chatserver}.log` |
| 重启 | `/home/java/gameserver/RESTART-GAMESERVER.sh`（**幂等**） |
| 上传助手 | `~/server-push.sh <本地路径> [远端目录,默认 /root/]` |

🔴 **Mongo 连接串必须含 `authSource=admin`**，漏了连不上。
🔴 线上是**本机版配置**（server.id=10001、redis 127.0.0.1）；
`src/main/resources/application*.properties` 是**开发配置**（70001 / 120.92.119.145:6080），**不要改 src**。

---

## 2. 区服寻址（开新服必读）

### 2.1 区服列表是**动态**的

```
登录库 x1_cn_test_login.server_info
   字段：_id / ip / port / server_id / name / state / isnew / plat / channel / sub_channel / server_version
        ↓  登录服 HTTP 下发
客户端 ~Lua/Modules/Login/ServerListSelectPanel.lua 渲染
```

⇒ **新增区服 = 往表里插一条记录，客户端不用重新出包。**

### 2.2 🔴 `tk/getServerList` 的 `server_version` 门控

`GetServerListController:104`：传 `server_version=0` 会被自己数进 `shenheNum` 而跳过 ⇒ **返回空列表**。
必须用真实版本（`1.26001`），**记录里照抄字符串 `"0"`**。

列表**每请求重查、无缓存** ⇒ **登记即生效，不用重启登录服**。

### 2.3 隐藏 / 显示区服

- Java 主循环：`state == -1 || state == 0 → continue` —— 这是官方「隐藏」语义。
- `state == 5` 才走 `getState()` 动态算 2/3/4（**永不返回 1/Maintenance**）。
- **客户端逐条渲染、不过滤 state** ⇒ 想让区服不可见**只能靠服务端不下发**。

```bash
~/ts-shard10002/add-shard-10002.sh hide     # 隐藏（幂等）
~/ts-shard10002/add-shard-10002.sh show     # 显示（幂等）
```

### 2.4 字段对齐（硬约束）

客户端**硬编码** `channel=pc` / `plat=android` / `sub_channel=1` ⇒ 记录里这三个值必须对齐。
登录/热更地址**硬编码在二进制**里，改不了。

### 2.5 区服名的多语言

`server_info.name` **只存中文**。`Language.xlsx`（17626 行）**从来没有区服名条目** ⇒
英文包会回落中文并**刷红字**。

改名要写在 `~Lua/Common/LanguageManager.lua` 末尾：

```lua
AddManualTranslation("庇护所九号", "Shelter No. 9")
```

⚠️ **真机吃字节码**，必须重编 `LuaBytes/Common_LanguageManager_64.bytes` 并**成对提交**（`d9059467d`）。
原因见 `client_build_chain.md`。

---

## 3. 端到端自测（不用客户端）

登录服 `isTestLan=1` ⇒ `GetUserController.vertify` **只比对 `JL_LOGIN_TOKEN`、完全不校验 sign**。

⇒ 可以**取生产 Redis 的 `JL_LOGIN_TOKEN:<openId>`**，直接调 `tk/getUserInfo` 造出真实登录，
无需跑客户端。用于低成本端到端验证。

```bash
~/ts-shard10002/token-sync.sh     # 同步登录令牌
```

---

## 4. 线上变更：热补丁 ≫ 整包重打

### 4.1 为什么

整包重编译会让线上 `GlobalDataManaager.checkNeedReFlush` 的 Camp lambda **回退**，
并重写 MANIFEST 的 Class-Path —— 副作用远大于收益。

### 4.2 怎么做

服务器用 `/usr/bin/zip -u` 就地替换：

```bash
zip -u gameSrv-1.0.0.jar <改动后的 class 路径>
```

- ⚠️ 会报 `Local Entry CRC does not match CD`（**原 jar 本就如此，无害**），体积可能变小。
- 🔴 **判据 = 逐条目 CRC diff 恰好 2×改动条目数**，不是看体积。
- 补丁后必查：`unzip -t`、条目数一致、`javap -p` 确认新方法在。
- 本地产物与线上 class 同为 Java 8（major 52），**可混用**。

### 4.3 能不能热更？

| 类型 | 结论 |
|---|---|
| Java `.class` / `lib/*.jar` / `config/application.properties` | **必须停服重启** |
| Lua / 配置表 | **热更无效**。`MinuteTask` 会跑 `luaHotFix()` / `updateTablesWithTableNames()`，但 `STableManager.jsonPath="../conf/"` → `/home/java/conf/` 下无版本 json ⇒ 永不触发 |

工程自带的 `lib/hotfix.jar` + `HotfixUtil` + `conf/hotswap` **三处入口全被注释 ⇒ 实际停用**。

🔴 线上 `com.ljsd.fight.CheckFight.getRootPath()` **硬编码 `/home/java/gameserver/`**；
战斗 lua 实际 = `/home/java/gameserver/luafight/BattleMain.lua`
（根目录 `/conf`、`/luafight` 是**死副本**）。

### 4.4 部署五步（不可逆序）

```
① 备份 → ② 停服（pkill -f gameSrv-1.0.0.jar，等 30s 确认 16081 释放）
      → ③ 上传 → ④ 解压 → ⑤ RESTART-GAMESERVER.sh
```

### 4.5 服务端源码构建（要重编时才用）

```bash
cd TimeSpaceServer/Server_x1tag1.2.2/server_game
JAVA_HOME=/usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home \
  ./package.sh --mode full
```

| 参数 | 说明 |
|---|---|
| `--mode full` | 全量：gradle 构建 `:serverlogic`/`:chatserver` → 重写 app jar → 组装 `dist/home/java/*` → tar.gz |
| `--no-build` | 不重新编译，只组装 |
| `--pull-skeleton` | 从 `gs:/home/java` 拉完整运行时骨架（默认取 `skzc/home/java`，**不完整**） |
| `--include-conf` | 默认排除 `conf/`；**强烈不建议打开**（见红线 4） |
| `-o <path>` | 输出路径 |

- 🔴 **构建必须 JDK8**；gradle wrapper 4.8 + `GRADLE_USER_HOME=.gradle_home`。
- 🔴 **别用根目录 `gradle build`**（worldserver 会挂）。
- 离线验证：`JAVA_HOME=… GRADLE_USER_HOME=.gradle_home ./gradlew :serverlogic:compileJava --offline`。
- `dist/home/java/gameserver/config/application.properties`（外部 Mongo 凭据，优先级高于 jar 内置）
  **由脚本产出**，缺了起不来。
- `assets/` 会进包：线上 913MB 中 889MB 是运行期日志（`assets/log/*`），打包已剔除；
  真实差异仅 `assets/conf/server/HeroRankupGroup.txt`。
- 生产配置改 **`server_game/deploy-overlay/`**，不要改 `src`。

---

## 5. 已上线/已应用的线上补丁

### 5.1 聊天持久化 Redis 兜底（2026-10-10）

**问题**：原版 `MessageCache` 的 sys/world/cross 通道是 static `LoopQueue`，**重启即清空**。

**方案**：Redis list `serverId:CHAT_QUEUE:<sys|world|cross>`，元素 `mid#ts#Base64(ChatInfo)`，
`rightPush + trim(-200,-1)`，`ensureLoaded()` 幂等。保留策略「**最近 5 条永久保底 + 其余 7 天**」。

```bash
~/ts-chat-patch-20261010/deploy-chat-patch.sh {verify|patch|restart|rollback}
```

- 🔴 部署后必须 `PERSIST <key>` 清掉旧 TTL。
- 🔴 **不伪造消息**（用户明确要求）。

### 5.2 英雄升星「氪金点」恢复（2026-10-10）

**问题**：提交 `05ad5ba3` 把祭品放宽为「同系任意」⇒ 抹掉了 23 个英雄
（`HeroRankupGroup` Id **31–53**）的氪金点。

**恢复**：`IsSameClan` → `0`、`IsId` → `10011…10015`。

- 服务端权威表有 **3 份副本**，都要改。
- 产出：客户端 `5d8b336b5`、源表 + CRC `6d0304f84`。
- 部署：`~/ts-upstar-restore-20261010/deploy.sh`（配 `restore_hrg.py`）。
- ⚠️ **表在启动时载入内存 ⇒ 必须 restart（会踢线）**。所以要先问用户。

---

## 6. 本地新区服 10002「庇护所九号」

**做法**：把本机 Mac 上的游戏服经**内网穿透（frp）**暴露，做成一个可登录的区服。

| 项 | 说明 |
|---|---|
| 状态 | **已上线可登录，属内测级** |
| 短板 | 家宽无兜底；跨服聊天不可用 |
| 脚本目录 | `~/ts-shard10002/`（见 `scripts_reference.md` §2.2） |
| 区服记录备份 | `~/ts-shard10002/server_info_id2*.json` |
| 该区的 lv24 老号 | 账号名 `r2gtB27C2057`（Editor 游客号） |

**踩过的系统级坑**（改这些之前务必读脚本注释）：

- macOS 上 `/home` 是 `synthetic.conf` 保留路径 ⇒ 需要 `setup-rootlink.sh` 建符号链接指向外置卷；
  出问题用 `revert-rootlink.sh` / `fix-home-synthetic.sh`。
- 穿透流量容易被本机代理（clash）吃掉 ⇒ `clash-direct-fix.sh` 加直连规则。
- 要常驻用 launchd（`install-launchd.sh`），别用 `nohup`（会话结束会被回收）。

---

## 7. 每日巡检

```bash
scripts/server_health_check.py              # 采集 + 发邮件
scripts/server_health_check.py --dry-run    # 只打印，不发邮件
scripts/server_health_check.py --json       # 额外输出结构化 JSON
```

- 定时任务「游戏服每日巡检（10:00 邮件）」。
- 本机 SSH 采集 → QQ SMTP 发信（`smtp.qq.com:465` SSL，回退 587）→ 留档 `scripts/logs/`。
- 状态文件 `scripts/.server_health_state.json`（幂等标记）。
- 授权码优先级：**`<工程>/.secrets/health.env`**（工程本地）→ `~/.gs_health.env` → `/Volumes/S/TD/.env`
  （**当前有效**）→ `~/TD-recovery/.env` → `~/TD-salvage-20260911/.env`（失效）；
  脚本逐个试登录自动跳过失效口令，缺失文件也安全跳过。见 `secrets_setup.md`。

**报告约定**：量化证据 + 区分「🔴 严重 / ⚠️ 关注」，不给"看起来还行"这种结论。

---

## 8. 故障速查

| 现象 | 根因 | 处理 |
|---|---|---|
| 区服列表为空 | 请求 `server_version=0`（被数进 `shenhuNum` 跳过） | 用真实版本 `1.26001` |
| 新登记的区服客户端看不到 | `state` 是 `-1`/`0`（隐藏语义） | `add-shard-10002.sh show` |
| 英文包里区服名是中文且刷红字 | `server_info.name` 只有中文，`Language.xlsx` 无区服名条目 | 在 `LanguageManager.lua` 加 `AddManualTranslation`，并**重编 `.bytes`** |
| 服务连不上 Mongo | 连接串漏 `authSource=admin` | 补上 |
| 改了表/配置不生效 | 表在启动时载入内存；lua/表热更链路实际停用 | **重启**（先问用户） |
| 重启后聊天记录全没 | 未部署 Redis 兜底补丁 | 见 §5.1 |
| `zip -u` 后报 CRC 不匹配 | 原 jar 本就如此 | 无害；按 CRC diff 条目数验证 |
| `Local Entry CRC does not match CD` + 体积变小 | 同上 | 无害 |
| 想第二台 gameserver | 2vCPU/3.6GB 已榨干 | 不要起；换机或先降配现有服务 |
