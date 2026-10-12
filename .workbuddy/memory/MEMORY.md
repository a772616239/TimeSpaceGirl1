# TimeSpaceGirl1 项目长期记忆

> 细节已拆到同目录参考文件，按需再读：
> - **`REF-server-ops.md`** —— 服务端打包 / 热补丁 / 部署·热更
> - **`REF-shard10002.md`** —— 本地新区服 10002「庇护所九号」全部运维细节
> - **`REF-android-release.md`** —— Android AAB 打包上传管线 + AssetBundle 链路 + 发版 shell 坑
> - **`REF-config-tables.md`** —— 客户端配置表 xlsx→lua→TSV 链路与 CRC32 门控

## 项目 / 生产环境
- Unity 手游「时空美少女/时空战场」客户端 + 同仓 `TimeSpaceServer/` 服务端；远端 `a772616239/TimeSpaceGirl1`（约 3.3GB）。
- SSH 别名 `gs` → 129.226.213.65（腾讯云 CentOS7，内网 10.3.0.15），私钥 `~/.ssh/tencent-gameserver.pem`；上传助手 `~/server-push.sh`。
- **2vCPU / 3.6GB RAM（avail ~670MB）/ 59G 盘（余 34G）→ 已榨干，不能再起第二个 gameserver。**
- `/home/java/{gameserver,loginserver,chatserver,xxljob}`；Mongo/Redis/Nginx 由宝塔管。进程：`gameSrv-1.0.0.jar`（netty 16081，`-Xms1280m -Xmx1280m` ParallelGC，xxl.job 关）、Tomcat 8.5.95 登录服 8080、mongod 27017、redis 6379（**无密码**、`bind 127.0.0.1`）。
- 重启 `/home/java/gameserver/RESTART-GAMESERVER.sh`（幂等）。日志 `/data/srvlog/{gameserver,chatserver}.log`。🔴 Mongo 连接串**必须含 `authSource=admin`**。

## 区服寻址（开新服必读）
- 区服列表**动态**：登录库 `x1_cn_test_login.server_info`（`_id/ip/port/server_id/name/state/isnew/plat/channel/sub_channel/server_version`）→ 登录服 HTTP 下发 → 客户端 `~Lua/Modules/Login/ServerListSelectPanel.lua` 渲染。⇒ **新增区服＝插一条记录，客户端不用重新出包**。10001 占 `_id:1`，10002 占 `_id:2`。
- 🔴 **`tk/getServerList` 的 server_version 门控**（`GetServerListController:104`）：传 `server_version=0` 会被自己数进 shenheNum 而跳过 → 空列表；调接口必须用真实版本 `1.26001`，记录里照抄 `"0"`。列表每请求重查、无缓存 → **登记即生效，不用重启登录服**。
- **隐藏/显示区服**：Java 主循环 `state == -1 || state == 0 → continue`（官方「隐藏」语义）；`state == 5` 才走 `getState()` 动态算 2/3/4（**永不返回 1/ Maintenance**）。客户端逐条渲染、不过滤 state ⇒ 只能靠服务端不下发。`add-shard-10002.sh {hide|show}` 幂等。
- 客户端硬编码 `channel=pc / plat=android / sub_channel=1`，记录必须对齐。登录/热更地址**硬编码在二进制**（Android `assets/bin/Data/c903ed81…` + `assets/Android/Resources/version.txt`）。
- 登录服 `isTestLan=1` ⇒ `GetUserController.vertify` 只比对 `JL_LOGIN_TOKEN`、**完全不校验 sign** ⇒ 可取生产 Redis 的 `JL_LOGIN_TOKEN:<openId>` 调 `tk/getUserInfo` 造真实登录做端到端自测，无需客户端。
- 🔴 **区服名多语言**：`server_info.name` 只存中文；`Language.xlsx` 表 17626 行**从来没有区服名条目** ⇒ 英文包回落中文并刷红字。新增/改名要在 `~Lua/Common/LanguageManager.lua` 末尾 `AddManualTranslation("中文","English")` 登记（⚠️ 真机吃字节码，须重编 `LuaBytes/Common_LanguageManager_64.bytes` 成对提交）。已登记 `庇护所九号` → `Shelter No. 9`（`d9059467d`）。
- 骨架搭建原文档 `docs/serverbuild.md`。

## 巡检
- `scripts/server_health_check.py`：本机 SSH 采集 → QQ SMTP 发信 → 留档 `scripts/logs/`。定时任务「游戏服每日巡检（10:00 邮件）」id `fb2c3e4c-7290-4cfa-9606-83cd5144f03c`。
- SMTP `smtp.qq.com:465` SSL（回退 587），收发 `772616239@qq.com`。授权码优先级：`~/.gs_health.env` → `/Volumes/S/TD/.env`（**当前有效**）→ `~/TD-recovery/.env` → `~/TD-salvage-20260911/.env`（失效）；脚本逐个试登录自动跳过失效口令。

## 🔴 客户端 Lua：改完必须重生成 LuaBytes 字节码
- 真机跑**预编译字节码**（`!isEditor` 时 `GameSettings.cs:112-117` 强制 `luaBundleMode=true` → 读 `Assets/ManagedResources/LuaBytes/<路径下划线化>_64.bytes`）；只有 Editor 才回落 `~Lua/*.lua`。命名 `Logic/Network.lua` → `Logic_Network_64.bytes`（`/`→`_`，Android `_64` / iOS `%64`）。
- ⇒ **只改 `~Lua` 源码 = Editor 有效、真机无效**，两文件必须成对提交。仓库有「只提交源码没重编字节码」的系统性问题（`Logic_SocketManager` 崩溃修复整整一年没上线）。
- 重编码：`cd LuaEncoder/luajit_mac/64 && LUA_PATH="./?.lua;;" ./luajit -b <abs>/X.lua <abs>/X_64.bytes`。🔴 必须带 `LUA_PATH` 且在本目录执行；🔴 **不要加 `-g`**（写入源码绝对路径且不剥离）——实测纯 `-b` 编 HEAD 源码 md5 与已提交产物相同（`648c8b797f8454bd1f61e84fe6c5322c`）。
- 验证：改动前后各用 `-b -g` 编码 → `luajit -bl` 反汇编 → 归一化文件名后 diff，只应剩目标函数一处差异。

## 配置表链路（改表必读）
→ 细节见 **`REF-config-tables.md`**。要点：`data_execl/base_data/*.xlsx` 是唯一真源，改后**必须同步 `DataConfigMD5Record.asset` 里的 CRC32**（否则导表重导出覆盖手改 lua），且客户端 lua + LuaBytes 字节码 + 服务端 `conf/server/*.txt` 三处。

## 聊天持久化 Redis 兜底（2026-10-10 上线）
- 原版 `MessageCache` 的 sys/world/cross 通道是 static `LoopQueue`，重启即清空。兜底 = Redis list `serverId:CHAT_QUEUE:<sys|world|cross>`（元素 `mid#ts#Base64(ChatInfo)`，`rightPush + trim(-200,-1)`，`ensureLoaded()` 幂等恢复），策略「每通道最近 5 条永久保底 + 其余 7 天」。🔴 部署必须 `PERSIST <key>` 清旧 TTL。
- **不伪造消息**（用户要求）。补丁 `~/ts-chat-patch-20261010/deploy-chat-patch.sh {verify|patch|restart|rollback}`，备份 `gameSrv-1.0.0.jar.bak.20261010`。客户端链路 `Modules/Net/NetManager.lua` → `Modules/Chat/ChatManager.lua`（通道 0/1/16，2s 轮询）。

## 英雄升星「氪金点」（2026-10-10 恢复）
- `05ad5ba3` 把祭品放宽为「同系任意」→ 抹掉 23 个英雄（`HeroRankupGroup` Id **31–53**）的氪金点。恢复 = `IsSameClan`→0、`IsId`→10011…10015。改动 6 个文件（**只改 lua 会漏源表**），已提交：客户端 `5d8b336b5`、源表+CRC `6d0304f84`。
- 服务端权威表 3 副本：`skzc/home/java/gameserver/{conf,assets/conf}/server/`、`Server_x1tag1.2.2/server_game/conf/server/`。部署 `~/ts-upstar-restore-20261010/deploy.sh`。⚠️ 表启动时载入内存 → **必须 restart**（会踢线）。

## 本地新区服 10002「庇护所九号」
→ 全部细节见 **`REF-shard10002.md`**。一句话：**已上线可登录，属内测级**（家宽无兜底、跨服聊天不可用）。2026-10-11 由「霓虹都市」改名，当前在区服列表中被隐藏（`state=0`），服务本体未停。

## Android 发版管线（AAB → Google Play）
→ 全部细节见 **`REF-android-release.md`**。一句话：`scripts/aab_release.sh` 一键「提号 → 打包 → 校验 → 上传」；线上 **production v64**（2026-10-12，Firebase 12.10.1）；**v65（2026-10-12 09:00）已上传 production 但为 `draft`、未送审**（`apks/2026-10-12/CLIBuild/085541.aab`，421MB，`versionCode 65` / `versionName 1.2.46`；Play API 实测 `draft v65; completed v64`）。🔴 **production 轨道「不送审」的唯一姿势 = `--status draft`**（`--changes-not-sent-for-review` 只对 internal/alpha/beta 有效，脚本内会 die）；`aab_release.sh` 末尾「会进入审核」是 `track==production` 的固定文案，**对 draft 不成立**。🔴 versionName 长期没动过会让 Play 告警的「发布版本名称」无法区分包，发版时记得同步提。
- **APK 打包**：入口 `Assets/Editor/CLIBuilder.cs:81 BuildAndroidAPK()`（universal，`buildAppBundle=false`）；Unity batchmode `-executeMethod CLIBuilder.BuildAndroidAPK -logFile build_log_apk_main.txt`。产物 `apks/<date>/CLIBuild/<HHmmss>.apk`（v65 实测 454MB / 2m9s，`apksigner verify` 通过、仅 v2 scheme）。⚠️ APK 用 **upload key**（`beauty.keystore` / alias `xing`，证书 DN `O=EMI`，SHA-256 `8ed07291…94b0`）签名，与 Play 的 **app signing key 不同** ⇒ 侧载须先卸载 Play 版。`apks/` 已在 `.gitignore:38`。
- **16KB 两层门槛**（`scripts/play_16kb_watch.py`）：门槛1 = 每个 .so `PT_LOAD p_align ≥ 16384`（硬性，本工程**已全绿 12/12**）；门槛2 = Play「旧版 NDK 编译」告警。🔴 **点名是按【库文件名】、不看 NDK 版本阈值** ⇒ 文件名含版本号的库换版本就等于换名字（Firebase 12.8.0→12.10.1 就是这么把 5 个告警降到 2 个的，实测仍 r21e）。原被点名的 2 个已于 2026-10-12 修复：`libnative-googlesignin.so` 移除依赖（`72502790b`）、`libtolua.so` 用 NDK r28 重编（`2f4e7310f`/`291ee8644`，工具链 `scripts/libtolua16k/`）。🔴 **升 Unity 引擎解决不了 16KB**（引擎只管 libunity/libil2cpp/libmain/burst，这些已合规）；`2023.2.22f1` **不在**官方 16KB 清单（`2021.3.48f1+ / 2022.3.56f1+ / 6000.0.38f1+ / 6000.1+`），本工程 2022.3.62f2c1 已在支持线内。取证工具在跨仓 `main_android/Release/tools/{verify_16k,so_meta}.py`。

## 🔴 约定（红线）
- 巡检默认**只读**：不重启服务、不改服务器配置。报告要有量化证据（错误数/阈值），区分「严重🔴 / 关注⚠️」。
- 🔴 **发版 / 上线前必须先给用户看过并取得明确同意，绝不自行提交审核。** 打包、构建、校验可以做；**「上传到 production 轨道 + status=completed」= 提交审核，必须先问**。2026-10-12 未经确认直发 production，用户明确纠正：「下次不要直接提交审核，我要自己看一下」。
- 🔴 重启生产游戏服（会踢线）**必须先取得用户确认**。
- 🔴 代码改动逐条 commit，中文 `type(scope): 摘要`，**严禁 `git add -A`**；每个改动分项提交、变更可追溯。
- 🔴 本项目 skill 与记忆**一律写在工程目录下**：记忆 → `.workbuddy/memory/`；Skill → `.workbuddy/skills/<name>/SKILL.md`。
- 🔴 **shell 脚本含中文标点时变量必须写 `${VAR}` 花括号**：`set -u` 下 `"…$STATUS）"` 会因全角括号 UTF-8 字节并入变量名而报 `unbound variable`，报错位置极迷惑。
- 🔴 **`set -o pipefail` 下 `cmd | head -1` 必须加 `|| true`**：head 读完即退并关管道，cmd 收 **SIGPIPE（141）** → pipefail 视为失败 → `set -e` 中止。同理 `| tail -1`、`| grep -q`。
- 本机 `find` 是 BSD 版：**不支持 `-newermt`**（报 `bad date` 且静默返回空），要用 `-mmin`。
