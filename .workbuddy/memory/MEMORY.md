# TimeSpaceGirl1 项目长期记忆

> 细节全部拆到同目录 REF 文件，**不要在本文件里堆细节**，按需再读：
> - **`REF-server-ops.md`** —— 服务端打包 / 热补丁 / 部署·热更
> - **`REF-shard10002.md`** —— 本地新区服 10002「庇护所九号」全部运维细节
> - **`REF-android-release.md`** —— Android AAB 打包上传管线 + AssetBundle + 16KB + 账号体系 + 发版 shell 坑
> - **`REF-config-tables.md`** —— 客户端配置表 xlsx→lua→TSV 链路与 CRC32 门控
> - **`REF-server-name-i18n.md`** —— 区服名多语言（server_info 的 name_en/jp/kr + 登录服 class 补丁与部署）
> - **`REF-jenkins-ci.md`** —— 本机 Jenkins 全流程 CI（`.jenkins/` 7 个 job + **7 个只有真跑才暴露的坑** + REST 触发姿势）
> - 当日细节一律进 `YYYY-MM-DD.md`（append-only）。

## 项目 / 生产环境
- Unity 手游「时空美少女/时空战场」客户端 + 同仓 `TimeSpaceServer/`；远端 `a772616239/TimeSpaceGirl1`（~3.3GB）。
- SSH 别名 `gs` → 129.226.213.65（腾讯云 CentOS7，内网 10.3.0.15），私钥 `~/.ssh/tencent-gameserver.pem`；上传助手 `~/server-push.sh`。
- **2vCPU / 3.6GB RAM / 59G 盘 → 已榨干，不能再起第二个 gameserver。**
- `/home/java/{gameserver,loginserver,chatserver,xxljob}`；Mongo/Redis/Nginx 由宝塔管。`gameSrv-1.0.0.jar`（netty 16081，`-Xms1280m -Xmx1280m`）、Tomcat 8.5.95 登录服 8080、mongod 27017、redis 6379（**无密码**、`bind 127.0.0.1`）。
- 重启 `/home/java/gameserver/RESTART-GAMESERVER.sh`（幂等）。日志 `/data/srvlog/{gameserver,chatserver}.log`。🔴 Mongo 连接串**必须含 `authSource=admin`**。

## 区服寻址（开新服必读）
- 区服列表**动态**：登录库 `x1_cn_test_login.server_info` → 登录服 HTTP 下发 → 客户端 `~Lua/Modules/Login/ServerListSelectPanel.lua` 渲染 ⇒ **新增区服＝插一条记录，客户端不用重新出包**；列表每请求重查、无缓存 ⇒ **登记即生效，不用重启登录服**。
- 🔴 `tk/getServerList` 的 server_version 门控（`GetServerListController:104`）：必须传真实版本 `1.26001`（传 0 会被自己数进 shenheNum 而跳过 → 空列表），记录里照抄 `"0"`。
- 隐藏区服：Java 主循环 `state == -1 || state == 0 → continue`；`state == 5` 才动态算 2/3/4（**永不返回 1**）。客户端逐条渲染不过滤 ⇒ 只能靠服务端不下发。`add-shard-10002.sh {hide|show}` 幂等。
- 客户端硬编码 `channel=pc / plat=android / sub_channel=1`，记录必须对齐；登录/热更地址**硬编码在二进制**。
- 登录服 `isTestLan=1` ⇒ `GetUserController.vertify` 只比对 `JL_LOGIN_TOKEN`、**完全不校验 sign** ⇒ 可取生产 Redis 的 `JL_LOGIN_TOKEN:<openId>` 调 `tk/getUserInfo` 造真实登录做端到端自测。
- 🔴 **区服名多语言（2026-10-12 起机制已换）**：`server_info` 现在支持 `name_en / name_jp / name_kr`，由登录服 `tk/getServerList` 一并下发，客户端 `GetServerName()` 按 `GetLan()` 选用 ⇒ **新增区服只需写数据，客户端零改动**。旧路径（`server_info.name` 只有中文 + `~Lua/Common/LanguageManager.lua` 的 `AddManualTranslation`）**已降级为回落链**，只对没填分语言字段的老记录生效。已登记（2026-10-12 写入生产 `x1_cn_test_login`；**登录服补丁已于当日 13:31 部署上线**，接口已实测下发分语言字段；客户端仍需出一次包才真机生效）：10001 霓虹序曲 → `Neon Overture` / `ネオン序曲`；10002 庇护所九号 → `Shelter No. 9` / `シェルター9号`（`name_kr` 未填，韩文包回落）。→ 细节见 **`REF-server-name-i18n.md`**。
- 🔴 **语言 id 权威表**（`conf/server/MultiLanguage.txt`，解析式 `lanid=floor(id/100)%100`）：**10001=中文CNY / 10101=English USD / 10002=中文USD / 10201=日文 / 10301=韩文** ⇒ 英文**不是** 10002。Editor 切语言测试 = 改 `Logo.unity` GameSettings`originLan`（Editor 分支已尊重 Inspector）+ 确认 PlayerPrefs `multi_language` 键**不存在**（存在则优先，`defaults delete "unity.Warera.Neon Valkyries" multi_language`）。详见 2026-10-12 日志。
- 骨架搭建原文档 `docs/serverbuild.md`。

## 巡检
- `scripts/server_health_check.py`：本机 SSH 采集 → QQ SMTP 发信 → 留档 `scripts/logs/`。定时任务「游戏服每日巡检（10:00 邮件）」id `fb2c3e4c-7290-4cfa-9606-83cd5144f03c`。
- SMTP `smtp.qq.com:465` SSL（回退 587），收发 `772616239@qq.com`。授权码优先级：`~/.gs_health.env` → `/Volumes/S/TD/.env`（**当前有效**）→ `~/TD-recovery/.env` → `~/TD-salvage-20260911/.env`（失效）；脚本逐个试登录自动跳过失效口令。

## 🔴 客户端 Lua：改完必须重生成 LuaBytes 字节码
- 真机跑**预编译字节码**（`!isEditor` 时 `GameSettings.cs:112-117` 强制 `luaBundleMode=true` → 读 `Assets/ManagedResources/LuaBytes/<路径下划线化>_64.bytes`）；只有 Editor 回落 `~Lua/*.lua`。命名 `Logic/Network.lua` → `Logic_Network_64.bytes`。
- ⇒ **只改 `~Lua` 源码 = Editor 有效、真机无效**，两文件必须成对提交。
- 重编码：`cd LuaEncoder/luajit_mac/64 && LUA_PATH="./?.lua;;" ./luajit -b <abs>/X.lua <abs>/X_64.bytes`。🔴 必须带 `LUA_PATH` 且在本目录执行；🔴 **不要加 `-g`**。
- 验证：`./luajit -bl X_64.bytes` 反汇编核对；魔数应为 `1b4c4a02`。
- 🔴 **运行时 LuaJIT 必须与字节码编码器严格同版本**（同 2.1 线也不行，opcode 表有增删 ⇒ **启动即卡死**）。`libtolua.so` 出自 **`topameng/tolua_runtime`**（LuaJIT **2.1.0-beta3**），重编走 **`scripts/libtolua16k/`**；**别用 `alex4814/tolua_runtime`**（2.1.ROLLING ⇒ 卡死）。
- 🔴 **`require` 名必须与 `module()` 名严格一致**：`module("a.b")` 只写 `package.loaded["a.b"]`。require 执行完 chunk 后若 `package.loaded[require名]` 仍是哨兵，Lua 会把它填成 **`true`** ⇒ **require 返回 boolean**，调用方一索引即崩（`attempt to index a boolean value`）。LuaJIT 会把 `/` 归一化成 `.`，所以这是**环境相关的脆弱耦合**（详见 2026-10-12 记录）。

## 配置表链路（改表必读）
→ 细节见 **`REF-config-tables.md`**。要点：`data_execl/base_data/*.xlsx` 是唯一真源，改后**必须同步 `DataConfigMD5Record.asset` 里的 CRC32**，且客户端 lua + LuaBytes 字节码 + 服务端 `conf/server/*.txt` 三处。

## 其它已上线改动
- **聊天持久化 Redis 兜底**（2026-10-10）：Redis list `serverId:CHAT_QUEUE:<sys|world|cross>`（`mid#ts#Base64(ChatInfo)`，`rightPush + trim(-200,-1)`），「最近 5 条永久保底 + 其余 7 天」；🔴 部署必须 `PERSIST <key>` 清旧 TTL；**不伪造消息**。补丁 `~/ts-chat-patch-20261010/deploy-chat-patch.sh {verify|patch|restart|rollback}`。
- **英雄升星氪金点恢复**（2026-10-10）：`HeroRankupGroup` Id 31–53 的 `IsSameClan`→0、`IsId`→10011…10015。客户端 `5d8b336b5`、源表+CRC `6d0304f84`；部署 `~/ts-upstar-restore-20261010/deploy.sh`。⚠️ 表启动载入内存 → **必须 restart**（会踢线）。
- **本地新区服 10002** → 见 `REF-shard10002.md`。一句话：**已上线可登录，属内测级**。

## Android 发版 / 账号体系 → 细节见 `REF-android-release.md`
- 轨道现状（2026-10-12 11:43 后）：`production draft v68; completed v67`（beta/alpha 空）。⚠️ **v67（未修 16KB）已被提升为 completed**；修好的 v68 仍是草稿，**待用户决定是否送审**。最新可测包 `apks/2026-10-12/CLIBuild/121249.apk`（v68 / 1.2.49 / isOpenGM=0 / googlesignin r28c）。
- 🔴 **送审闸门**：默认拒绝 + 三旗标显式放行（`--upload` / `--production` / `--publish`），默认 `status=draft`、默认不上传。🔴 `--status draft` 是 production 轨道「不送审」的**唯一**姿势。
- 🔴 **交付自检 `scripts/verify_apk_delivery.py`** 答「这包能不能测」；16KB 以**包内产物**为准（`scripts/verify_aab_native_16kb.py`），Unity 打印的 `libtolua.so is not 16KB-aligned` 是**误报**；🔴 **升 Unity 引擎解决不了 16KB**。
- 🔴 **上传期间禁止并发调用任何 Play API**（多进程开 edit 会互删，实测 85% 处 `HTTP 400 FAILED_PRECONDITION`）。
- 🔴 **账号名 = f(登录 SDK 给的 id)**，换 SDK 就等于换号；Android `platformId==1` **必须走 Google Sign-In（`f74ffb436`），勿改回 PlayGames**。
- 出包配置真源 `Assets/Editor/ReleaseBuildSettings.cs`（`297b9ba9f`）；线上渠道值就是 `None`、`isSDK=false` 是**正常**的。

## 全流程 CI（Jenkins）→ 细节见 `REF-jenkins-ci.md`
- 三条链已收口成 **7 个 Jenkins job**（本机 2.568，`http://127.0.0.1:8080/`，视图「时空美少女 · 全流程」）：
  `TS-Pipeline-Overview`（只读总览）/ `TS-Android-Release` / `TS-Android-TestPackage` / `TS-Client-Resources` /
  `TS-Server-Health`(H 10) / `TS-Server-Ops` / `TS-Play-Watch`(H 9)。
- 🔴 **单一真源在仓库**：job 定义 `.jenkins/jobs/*.groovy`，改 job **不用点界面、不用重启**
  ⇒ 改完跑 `.jenkins/lint.sh`（四道静态检查）→ `.jenkins/apply-jobs.sh` 同步。权威文档 `docs/jenkins_ci.md`。
- 🔴 **`.jenkins/run/` 是运行态产物，不入库**（`.gitignore`）。
- **可视化四件套**：stage 图（嵌套分组）/ JUnit 表格+趋势（warn→`<skipped message="[WARN] …">`）/
  `currentBuild.description` 单行结论 / `evidence/**` 归档。**有 warn 无 fail ⇒ UNSTABLE（黄球）**，这是有信息量的。
- 🔴 **静态检查挡不住的三类坑**（真跑才炸）：`config.xml` 的 Content-Type **必须带 `charset=UTF-8`**（否则中文→500，
  且 `createItem` 正常 ⇒「首次成功、二次全 500」的假象会骗人）；`<sandbox>` **必须 `true`**（写 false 要逐份批准脚本文本，
  改一个字就 `UnapprovedUsageException`）；`junit testResults` **必须相对 workspace**（绝对路径 ⇒ 表格静默空白）；
  ANSI 码进 XML ⇒ 整份报告 `[failed-to-read]`（`ESC` 是 XML 1.0 非法字符）。
- 🔴 **`POST /job/<n>/build` 在 2.568 上恒 400**；正确姿势 `POST /buildWithParameters` + `--data-urlencode 'json={"parameter":[]}'` → 201。

## 🔴 约定（红线）
- 巡检默认**只读**：不重启服务、不改服务器配置。报告要有量化证据（错误数/阈值），区分「严重🔴 / 关注⚠️」。
- 🔴 **发版 / 上线前必须先给用户看过并取得明确同意，绝不自行提交审核。** 打包、构建、校验、提交 git 可以做；**「上传到 production 轨道 + status=completed」= 提交审核，必须先问**。
- 🔴 重启生产游戏服（会踢线）**必须先取得用户确认**。
- 🔴 代码改动逐条 commit，中文 `type(scope): 摘要`，**严禁 `git add -A`**；客户端 Lua 改动须源码 + LuaBytes 成对提交。
- 🔴 本项目 skill 与记忆**一律写在工程目录下**：记忆 → `.workbuddy/memory/`；Skill → `.workbuddy/skills/<name>/SKILL.md`。
- 🔴 **shell 脚本含中文标点时变量必须写 `${VAR}` 花括号**：`set -u` 下 `"…$STATUS）"` 会因全角括号字节并入变量名而报 `unbound variable`。
- 🔴 **`set -o pipefail` 下 `cmd | head -1` 必须加 `|| true`**：head 早退 → cmd 收 SIGPIPE(141) → pipefail 视为失败 → `set -e` 中止。
- 本机 `find` 是 BSD 版：**不支持 `-newermt`**，要用 `-mmin`；本机 `ps` 在沙箱里 operation not permitted，用 `pgrep -fl` 代替。
- 🔴 **本机 grep 是 BSD 版：BRE 下不认 `\|`**（那是 GNU 扩展）⇒ `grep -o 'a\|b'` 被当**字面量**、匹配不到、退出 1；叠上 `set -o pipefail` 会让整条管道失败，把「有值」误报成「无值」。**一律用 `grep -E` / `-oE` / `-qE`**（BSD/GNU 通用），无匹配可能的地方再补 `|| true`。同理 `sed` 的 BRE 也别用 `\|`。（云服是 GNU grep，所以这个坑只在本地脚本上出现 —— 更容易漏。）
- 🔴 **凡改动系统级状态（`/home`、挂载点、`synthetic.conf`、launchd 域、`/etc/*`），记忆里必须显式标注「重启后是否仍有效」**，并当场验证一次。
