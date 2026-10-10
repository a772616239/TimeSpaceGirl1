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
