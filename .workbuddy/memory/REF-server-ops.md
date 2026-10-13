# 参考：TimeSpaceGirl1 服务端打包 / 热补丁 / 部署

> 从 `MEMORY.md` 拆出（2026-10-10），内容未改动，仅迁址以免主记忆文件过大。
> 涉及生产游戏服重新打包与部署时读本文件。

## 服务端打包
- `TimeSpaceServer/Server_x1tag1.2.2/server_game/package.sh`：gradle 构建 `:serverlogic`/`:chatserver` → 重写 app jar（生产资源 + Class-Path + logback-boot.xml）→ 组装 `dist/home/java/*` → tar.gz。参数 `--mode full` / `--no-build` / `--pull-skeleton` / `-o`。
- 构建**必须 JDK8**（`/usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home`）；gradle wrapper 4.8 + `GRADLE_USER_HOME=.gradle_home`；**别用根目录 `gradle build`**（worldserver 会挂）。离线验证：`JAVA_HOME=… GRADLE_USER_HOME=.gradle_home ./gradlew :serverlogic:compileJava --offline`。
- 🔴 `src/main/resources/application*.properties` 是**开发配置**（server.id=70001 / redis 120.92.119.145:6080 / mongo `…_70001`）；线上是本机版（10001、127.0.0.1）。**生产配置改 `server_game/deploy-overlay/`，不要改 src**。`dist/home/java/gameserver/config/application.properties`（外部 Mongo 凭据，优先级高于 jar 内置）由脚本产出，否则起不来。
- 运行时骨架（`conf/server`、`conf/hotswap`、`assets`…）不在源码里：默认取 `skzc/home/java`（**不完整**），要完整数据用 `--pull-skeleton` 从 `gs:/home/java` 拉。

## 热补丁 ≫ 整包重打
- 改线上优先 `jar uf` / `zip -u` 只替换改动 class；整包重编译会让线上 `GlobalDataManaager.checkNeedReFlush` 的 Camp lambda **回退**并重写 MANIFEST Class-Path。
- 服务器用 `/usr/bin/zip -u` 就地替换。⚠️ 会报 `Local Entry CRC does not match CD`（原 jar 本就如此，无害），体积可能变小。**判据 = 逐条目 CRC diff 恰好 2×改动条目数**，不是体积。
- 补丁后必查：`unzip -t`、条目数一致、`javap -p` 确认新方法在。本地产物与线上 class 同为 Java 8（major 52）可混用。

## 部署：能不能热更
- **必须停服重启**：Java `.class`、`lib/*.jar`、`config/application.properties`。工程自带热更（`lib/hotfix.jar` + HotfixUtil + `conf/hotswap`）**三处入口全被注释 → 实际停用**。
- **lua / 表热更无效**：`MinuteTask` 会跑 `luaHotFix()` / `updateTablesWithTableNames()`，但 `STableManager.jsonPath="../conf/"` → `/home/java/conf/` 下无版本 json → 永不触发。
- 线上 `com.ljsd.fight.CheckFight.getRootPath()` **硬编码 `/home/java/gameserver/`**；战斗 lua 实际 = `/home/java/gameserver/luafight/BattleMain.lua`（根目录 `/conf`、`/luafight` 是死副本）。
- 🔴 **`conf/` 绝不能整目录覆盖**（混着 hotfix.json / lua-hotfix.json / c_database_version.json / plat-configure.json + `checkout_db|mem*.txt` 玩家结算落盘）。`package.sh` 默认排除，需 `--include-conf`。
- `assets/` 会进包：线上 913MB 中 889MB 是运行期日志（`assets/log/*`），打包已剔；真实差异仅 `assets/conf/server/HeroRankupGroup.txt`。
- 部署五步（不可逆序）：备份 → 停服（`pkill -f gameSrv-1.0.0.jar`，等 30s 确认 16081 释放）→ 上传 → 解压 → `RESTART-GAMESERVER.sh`。

## 登录服（Tomcat 8.5.95）热重载 —— 与 gameserver 完全不同

> 上面的「必须停服重启」只适用于 gameserver。**登录服是 Tomcat，可以单应用热重载**。
> 2026-10-12 用本机完整 Tomcat 8.5.95 沙箱实测确认（沙箱 = 复制 `apache-tomcat-8.5.95` 到
> `/tmp`，改端口 18080，放一个 dummy.war，然后观察 `HostConfig` 行为）。

| 动作 | 结果 |
|---|---|
| 只改/上传 `webapps/<app>/WEB-INF/classes/**` | ❌ **不触发重载** |
| `touch webapps/<app>/WEB-INF/web.xml` | ✅ `HostConfig.reload` → `context.reload()`，**只重载该应用**，不重新解包 WAR ⇒ 手工放进去的 class 保留。空应用耗时 17ms |
| `touch webapps/<app>.war` | 🔴 `undeploy` + **重新解包** ⇒ 覆盖 `WEB-INF/` 下的手工改动 |

- 🔴 **重载有延迟**：后台线程按周期扫描，实测 `touch` 后约 **20~40s** 才落日志。
  ⇒ 「打接口返回 200」**不能**用来判断重载是否完成（旧 class 期间也是 200）。正确判据 =
  轮询 `logs/catalina.out` 里的 `org.apache.catalina.startup.HostConfig.reload` + `[/<app>]`
  （这串**不是本地化字符串**，中文 Tomcat 同样匹配）。
- 代码依据：`lib/catalina.jar` 的 `HostConfig.checkResources()` 分两条通路 ——
  `redeployResources`（`.war`/`context.xml`/`conf/context.xml` ⇒ 触发 undeploy+重新部署）与
  `reloadResources`（`context.findWatchedResources()` ⇒ 只 `context.reload()`）。web.xml 落在后者。
- 🔴 线上该登录服 `catalina.out` 里 `/tk` 重载次数基线 = **0**：历史上都是整机重启，从未热重载。
- 登录服整机重启代价参考：`tk` 冷部署实测 3.5~6.2s（TLD/JAR 扫描 ~2.9s + Mongo 连接池 ~0.6s），
  全站 `Server startup in 7605 ms`。
- 具体到区服名补丁的用法见 **`REF-server-name-i18n.md`** 的「部署」节。

## 区服登记与寻址（开新服必读）

> 从 `MEMORY.md` 拆出（2026-10-13）以免主记忆文件超注入上限被截断。

- 区服列表是**动态**的：登录库 `x1_cn_test_login.server_info` → 登录服 HTTP 下发 → 客户端
  `ServerListSelectPanel.lua` 渲染 ⇒ **新增区服 = 插一条记录**，客户端**不用出包**；
  列表每请求重查、无缓存 ⇒ **登记即生效，不用重启登录服**。
- 🔴 `tk/getServerList` 有 **server_version 门控**（`GetServerListController:104`）：
  必须传真实版本 `1.26001`。传 `0` 会把自己数进 `shenheNum` 从而被跳过 → 返回**空列表**；
  而记录里反而要照抄 `"0"`。（这一条踩过，最容易误判成「区服没登记上」。）
- **隐藏区服**：Java 主循环对 `state == -1 || state == 0` 直接 `continue`；
  只有 `state == 5` 才动态计算成 2/3/4（**永不返回 1**）。
  客户端是**逐条渲染不过滤**的 ⇒ 隐藏只能靠**服务端不下发**。
  `add-shard-10002.sh {hide|show}` 幂等。
- 客户端硬编码 `channel=pc / plat=android / sub_channel=1`，插入记录必须与之对齐；
  登录 / 热更地址**硬编码在二进制**里。
- 🔑 **登录服 `isTestLan=1` 时的自测技巧**：`GetUserController.vertify` 只比对
  `JL_LOGIN_TOKEN`、**完全不校验 sign** ⇒ 可直接取生产 Redis 的
  `JL_LOGIN_TOKEN:<openId>` 调 `tk/getUserInfo`，造一次真实登录做端到端自测。
- 区服名多语言（`name_en/jp/kr`）细节见 **`REF-server-name-i18n.md`**。
- 🔴 **语言 id 权威表**（`conf/server/MultiLanguage.txt`，`lanid = floor(id/100) % 100`）：
  **10001=中文CNY / 10101=English USD / 10002=中文USD / 10201=日文 / 10301=韩文**
  ⇒ 英文**不是** 10002（极易搞错）。
- 骨架搭建原文档 `docs/serverbuild.md`。
