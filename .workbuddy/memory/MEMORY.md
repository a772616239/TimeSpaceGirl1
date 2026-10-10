# TimeSpaceGirl1 项目长期记忆

> 专题细节已拆到同目录参考文件，按需再读：
> - **`REF-server-ops.md`** —— 服务端打包 / 热补丁 / 部署·热更
> - **`REF-shard10002.md`** —— 本地新区服 10002「霓虹都市」全部运维细节（含 launchd 托管）

## 项目 / 生产环境
- Unity 手游「时空美少女/时空战场」客户端 + 同仓 `TimeSpaceServer/` 服务端；远端 `a772616239/TimeSpaceGirl1`（约 3.3GB）。
- SSH 别名 `gs` → 129.226.213.65（腾讯云 CentOS7，内网 10.3.0.15），私钥 `~/.ssh/tencent-gameserver.pem`；上传助手 `~/server-push.sh`。
- **2vCPU / 3.6GB RAM（avail ~670MB）/ 59G 盘（余 34G）→ 已榨干，不能再起第二个 gameserver。**
- `/home/java/{gameserver,loginserver,chatserver,xxljob}`；Mongo/Redis/Nginx 由宝塔管。进程：`gameSrv-1.0.0.jar`（netty 16081，`-Xms1280m -Xmx1280m` ParallelGC，xxl.job 关）、Tomcat 8.5.95 登录服 8080、mongod 27017、redis 6379（**无密码**、`bind 127.0.0.1`）。
- 重启 `/home/java/gameserver/RESTART-GAMESERVER.sh`（幂等）。日志 `/data/srvlog/{gameserver,chatserver}.log`。🔴 Mongo 连接串**必须含 `authSource=admin`**。

## 区服寻址（开新服必读）
- 区服列表**动态**：登录库 `x1_cn_test_login.server_info`（`_id/ip/port/server_id/name/state/isnew/plat/channel/sub_channel/server_version`）→ 登录服 HTTP 下发 → 客户端 `~Lua/Modules/Login/ServerListSelectPanel.lua` 渲染。⇒ **新增区服＝插一条记录，客户端不用重新出包**（复用同一公网 IP，只换 port/server_id）。10001 占 `_id:1`，10002 占 `_id:2`，3~17 空占位。
- 客户端登录/热更地址**硬编码在二进制**：Android `assets/bin/Data/c903ed81…`（十六进制 IP）+ `assets/Android/Resources/version.txt`；iOS `Payload/game.app/Data/resources.assets` + `Raw/IOS/Resources/version.txt`。服务端 IP 另见 `gameserver/config/{logicSrv,application-core1}.properties`、`loginserver/apache-tomcat-8.5.95/config/x1/application.properties`、`/www/wwwroot/rg/1/{Android,IOS}/version.txt`。
- 骨架搭建原文档 `docs/serverbuild.md`。
- 🔴 **`tk/getServerList` 的 server_version 门控**（`GetServerListController:104`）：`!recVer.equals("0") ? !reqVer.equals(recVer) : shenheNum>=1` ⇒ **传 `server_version=0` 会被自己数进 shenheNum 而跳过 → 空列表**；调接口必须用客户端真实版本 `1.26001`，记录里照抄 `"0"`。列表每请求重查、无缓存 → **登记即生效，不用重启登录服**；`getState()` 只返回 2/3/4，**永不返回 1(Maintenance)** → 新服不会被拦。客户端硬编码 `channel=pc / plat=android / sub_channel=1`，记录必须对齐。
- 登录服 `isTestLan=1` ⇒ `GetUserController.vertify` 只比对 `JL_LOGIN_TOKEN`、**完全不校验 sign** ⇒ 可取生产 Redis 的 `JL_LOGIN_TOKEN:<openId>` 调 `tk/getUserInfo` 造真实登录做端到端自测，无需客户端。

## 巡检
- `scripts/server_health_check.py`：本机 SSH 采集 → QQ SMTP 发信 → 留档 `scripts/logs/`。定时任务「游戏服每日巡检（10:00 邮件）」id `fb2c3e4c-7290-4cfa-9606-83cd5144f03c`。
- SMTP `smtp.qq.com:465` SSL（回退 587），收发 `772616239@qq.com`。授权码优先级：`~/.gs_health.env` → `/Volumes/S/TD/.env`（**当前有效**）→ `~/TD-recovery/.env` → `~/TD-salvage-20260911/.env`（失效）；脚本逐个试登录自动跳过失效口令。

## 🔴 客户端 Lua：改完必须重生成 LuaBytes 字节码
- 真机跑**预编译字节码**：`GameSettings.cs:112-117` / `GameStart.cs:40-41` 在 `!Application.isEditor` 时强制 `luaBundleMode=true` → `LuaLoader.ReadFile` 走 `LoadFromAssetBundle()` 读 `Assets/ManagedResources/LuaBytes/<路径下划线化>_64.bytes`；只有 Editor 才回落 `~Lua/*.lua`。命名 `Logic/Network.lua` → `Logic_Network_64.bytes`（`/`→`_`；Android 64 位 `_64`，iOS `%64`）。
- ⇒ **只改 `~Lua` 源码 = Editor 有效、真机无效**，两文件必须成对提交（如 `f89e135c1` + `566aec9d4`）。
- 重编码：`cd LuaEncoder/luajit_mac/64 && LUA_PATH="./?.lua;;" ./luajit -b <abs>/X.lua <abs>/X_64.bytes`（LuaJIT 2.1.0-beta3）。🔴 必须带 `LUA_PATH` 且在本目录执行（否则 `jit.* modules not installed`）；🔴 **不要加 `-g`**（会写入源码绝对路径且不剥离）——实测纯 `-b` 编 HEAD 源码 md5 与已提交产物**完全相同**（`648c8b797f8454bd1f61e84fe6c5322c`）。
- 验证：改动前后各用 `-b -g` 编码 → `luajit -bl` 反汇编 → 归一化文件名后 diff，只应剩目标函数一处差异。`LuaBytes/` 约 2910 个文件。

## 配置表链路（改表必读）
`data_execl/base_data/<X>.xlsx`（**唯一真源**）→ 导表 `Assets/Scripts/Editor/ExcelTool/DataConfig/DataConfigWindow.cs`（菜单 Data Config/Window）→ `~Lua/Config/Data/<X>.lua`（压缩编码）+ `LuaBytes/Config_Data_<X>_64.bytes` → 服务端 `conf/server/<X>.txt`（TSV）。
- 🔴 `DataConfigMD5Record.asset` 存每张源表 xlsx 的 **CRC32 十进制**。改 xlsx 必须同步该值，否则导表判「已变更」重导出、覆盖手改的 lua。结构 = Unity YAML `_keys:`/`_values:` 两个平行数组（各 300），**按 key 后缀匹配定位**（不可按行号）。算：`python -c "import zlib;print(zlib.crc32(open('x.xlsx','rb').read())&0xffffffff)"`。
- 改表工具样例 `/tmp/tsfix/{restore_xlsx,update_crc}.py`：`openpyxl.load_workbook()`（**不要** data_only）+ `wb.save()`。
- ⚠️ xlsx 有两种写法（Excel 原版含 sharedStrings / openpyxl 重存版 inlineStr）。**别盲目 `git checkout` 历史 xlsx**，优先原地改；判据看逐格内容，不是哈希/体积。
- 客户端压缩表解码器：`~Lua/Framework/GameDataBase.lua decodeList`（`__indexs/__values/__refs/__refPoss` + LZ 式十进制重复 + 末位累计和）。比对前**必须归一化行尾 TAB/CR**。

## 聊天持久化 Redis 兜底（2026-10-10 已上线生产）
- 原版 `MessageCache` 的 sysMsg/worldMsg/crosssysMsg 是 static `LoopQueue`（200/单次 30/7 天），重启即清空，系统消息零存档。兜底：Redis list `serverId:CHAT_QUEUE:<sys|world|cross>`，元素 `mid#ts#Base64(ChatInfo)`，`rightPush + trim(-200,-1)`，`ensureLoaded()` 幂等恢复。策略 = 每通道**最近 5 条永久保底** + 其余 7 天，`persist()` 不设 TTL。🔴 部署必须 `PERSIST <key>` 清旧 key TTL（已写进 `deploy-chat-patch.sh`）。
- **不伪造消息**（用户要求）：无真实消息时聊天框就是空的。补丁 `~/ts-chat-patch-20261010/deploy-chat-patch.sh {verify|patch|restart|rollback}`，备份 `gameSrv-1.0.0.jar.bak.20261010`；玩家消息跨重启已在生产验证。客户端链路 `Modules/Net/NetManager.lua` → `Modules/Chat/ChatManager.lua`（通道 0/1/16，2s 轮询，msgId 严格递增）。

## 英雄升星「氪金点」（2026-10-10 恢复）
- `05ad5ba3` 把祭品从「指定英雄」放宽为「同系任意」→ 抹掉 23 个英雄（`HeroRankupGroup` Id **31–53**）的氪金点。恢复 = `IsSameClan`→0、`IsId`→10011…10015。
- 改动了 6 个文件（**只改 lua 会漏源表**）：`~Lua/Config/Data/{HeroRankupGroup,GuideConfig}.lua`、`~Lua/Modules/Hero/HeroManager.lua`、`data_execl/base_data/HeroRankupGroup.xlsx`、`DataConfigMD5Record.asset`、`data_execl/modify_xlsx.py`。已提交：客户端 `5d8b336b5`、源表+CRC `6d0304f84`。
- 服务端权威表 3 副本：`skzc/home/java/gameserver/{conf,assets/conf}/server/`、`Server_x1tag1.2.2/server_game/conf/server/`。部署 `~/ts-upstar-restore-20261010/deploy.sh {verify|backup|patch|restart|rollback}`（已上传 `gs:/root/`）。⚠️ 表启动时载入内存 → **必须 restart**（会踢线）。

## 本地新区服 10002「霓虹都市」（内网穿透，2026-10-10 上线）
→ 全部细节见 **`REF-shard10002.md`**（组件清单、lib 硬编码 `/home/java/gameserver/`、macOS autofs `/home`、配置层级、鉴权链、`JL_TOKEN` 镜像、代理变量事故、launchd 托管、遗留项）。一句话结论：**新增区服已上线可登录，属内测级**（家宽无兜底、跨服聊天不可用）。

## 约定
- 巡检默认**只读**：不重启服务、不改服务器配置。报告要有量化证据（错误数/阈值），区分「严重🔴 / 关注⚠️」。
- 🔴 重启生产游戏服（会踢线）**必须先取得用户确认**。
- 🔴 代码改动逐条 commit，中文 `type(scope): 摘要`，**严禁 `git add -A`**。
- 🔴 本项目相关 skill 与记忆**一律写在工程目录下**，不写用户级目录：记忆 → `.workbuddy/memory/{YYYY-MM-DD.md, MEMORY.md}`；Skill → `.workbuddy/skills/<name>/SKILL.md`。
