# TimeSpaceGirl1 项目长期记忆

> 本文件**只做索引**：细节在同目录 REF，当日细节进 `YYYY-MM-DD.md`（append-only）。
> `REF-server-ops.md`（打包/热补丁/区服寻址）· `REF-shard10002.md`（地服 10002）· `REF-android-release.md`（AAB 管线 + AB + 16KB + 账号）· `REF-config-tables.md`（xlsx→lua→TSV + CRC32）· `REF-server-name-i18n.md` · `REF-jenkins-ci.md`。

## 客户端 Unity 6000.6.5f1（2026-10-13 升级，编译全绿）
- `ProjectVersion.txt` = `6000.6.5f1 (3ff58d469c8a)`；🔴 **必须写国际版号**（中国版号串被 UPM 拒绝）。编辑器 `/Applications/Unity/Hub/Editor/6000.6.5f1/...`。
- 🔴 batchmode 跑本工程**必须显式 `-buildTarget Android`**：`UNITY_ANDROID` 只在 target=Android 时定义，否则 `com.google.play.games` 编成空程序集并连带报错。
- 🔴 Unity 6 会**就地改写**源目录（Gradle 模板注入、场景重序列化、`ProjectSettings/*`），不提交则每次打包变脏。已停用 `_disabled_for_unity6/`。

## 生产环境
- 「时空美少女/时空战场」客户端 + 同仓 `TimeSpaceServer/`；远端 `a772616239/TimeSpaceGirl1`（~3.3GB，**PUBLIC**）。
- 🔴 **服务端代码 = `TimeSpaceServer/Server_x1tag1.2.2/`**（独立仓库 `a772616239/Server_x1tag1.2.2`，分支 `x1-tag-1.2.2`）：Java 多模块在 `server_game/`，运维脚本在 `server_game/deploy/`，打包覆盖层在 `server_game/deploy-overlay/`。**凡服务端逻辑/配置/运维脚本一律写这里，不写客户端工程的 `scripts/`**；该仓有并行会话在自动 commit，提交只能显式列路径。
- SSH `gs` → 129.226.213.65（腾讯云 CentOS7，内网 10.3.0.15）；私钥优先 `.secrets/tencent-gameserver.pem`。**2vCPU/3.6GB/59G 已榨干，不能再起第二个 gameserver。**
- `/home/java/{gameserver,loginserver,chatserver,xxljob}`；`gameSrv-1.0.0.jar`（netty 16081，`-Xmx1280m`）、Tomcat 8.5.95 登录服 8080、mongod 27017、redis 6379（**无密码**、bind 127.0.0.1）。Mongo/Redis/Nginx 走宝塔。
- 重启 `RESTART-GAMESERVER.sh`（幂等）；日志 `/data/srvlog/*.log`；🔴 Mongo 串**必须含 `authSource=admin`**。
- 🔴 **两处线上热补丁已转正到源码**（`77402068`）：远征 `type==2` 频控 `patch/AdventureRewardGuard` + 内购发货门禁 `patch/PayGateGuard`（`TestBuyGiftGoodsHandler` 直接调用）。jar 注入版与源码版已 javap 逐类等价验证 ⇒ 重打包不再丢，**别再重复注入**。编译必须联网（`--offline` 缺 `spring-boot-starter-data-mongodb:1.5.9`）、`gradlew` 无执行位用 `sh gradlew`。细节 `2026-10-18.md`。

## 区服寻址（开新服必读 → `REF-server-ops.md` §区服登记与寻址）
- 列表**动态**：`x1_cn_test_login.server_info` → 登录服 HTTP → `ServerListSelectPanel.lua` ⇒ **新增区服＝插一条记录**，客户端不出包、不用重启登录服（硬编码 `channel=pc/plat=android/sub_channel=1` 要对齐）。
- 🔴 `tk/getServerList` 的 server_version 必须传真版本 **`1.26001`**（传 `0` 会把自己数进 `shenheNum` → 空列表）；记录里照抄 `"0"`。
- 🔴 隐藏区服只能靠服务端不下发（`state` 门控，客户端不过滤）；`add-shard-10002.sh {hide|show}` 幂等。
- 🔴 语言 id（`conf/server/MultiLanguage.txt`，`lanid=floor(id/100)%100`）：**10001=中文CNY / 10101=English USD / 10002=中文USD / 10201=日文 / 10301=韩文** ⇒ 英文**不是** 10002。
- 🔴 `GameSettings.originLan` 不是发行口径：真机首启用**设备系统语言**覆盖（`GameSettings.cs:110-114`），只有 Editor 尊重 Inspector。`Logo.unity` 里的值别当发布开关。

## 巡检 / 日志
- `scripts/server_health_check.py`：SSH 采集 → QQ SMTP（`smtp.qq.com:465`）→ 留档 `scripts/logs/`；定时任务 `fb2c3e4c-7290-4cfa-9606-83cd5144f03c`（每日 10:00）。口令在 `.secrets/health.env`（600），回退链缺失/失效都安全跳过。
- 🔴 **日志清理 = logback 主力 + 脚本兜底**（`c1ac21cb`）。`jl_logs` 是 logback 写的，主力是 `server_game/deploy-overlay/gameserver-jar/logback-boot.xml` 的 `maxHistory`（corelog/error/tlog/blog=7 天，`maxHistoryItem`=30 只给道具流水）。环境 **logback 1.1.11**：无 `totalSizeCap`/`cleanHistoryOnStart`（1.2.0 才有，写了静默忽略）；生效的是 **jar 内**那份（`logging.config=classpath:`），改服务器 `assets/conf/` 副本无效。1.1.11 滚动只删文件**不删空目录** ⇒ `server_game/deploy/log_cleanup.py`（服上 `/home/java/log_cleanup.py`，cron `/etc/cron.d/ts-log-cleanup` 每日 04:17）兜底扫空目录 + srvlog/tomcat/转储 + 磁盘应急。安装用 `deploy/install-log-cleanup.sh`（幂等，含 selftest）。

## 🔴 客户端 Lua 改动必须重编 LuaBytes
- 真机跑字节码（`!isEditor` 时强制 `luaBundleMode=true`，读 `LuaBytes/<路径下划线化>_64.bytes`）；只改 `~Lua` = Editor 有效、真机无效 ⇒ **源码+字节码成对提交**。
- 重编用 `scripts/lua-bytes-sync.sh <lua>`（内部 `cd LuaEncoder/luajit_mac/64 && LUA_PATH="./?.lua;;" ./luajit -b`，🔴 必须在本目录 + 带 `LUA_PATH`，**不加 `-g`**）；`--check` 自查。字节码魔数 `1b4c4a02`。
- 🔴 运行时 LuaJIT 必须与编码器**严格同版本**（同 2.1 线也启动即卡死）。`libtolua.so` 出自 **`topameng/tolua_runtime`**（2.1.0-beta3），重编走 `scripts/libtolua16k/`；别用 `alex4814`（2.1.ROLLING）。
- 🔴 `require` 名必须与 `module()` 名一致：否则 `package.loaded` 被填成 `true`，调用方一索引就崩。

## 图集 / 资源登记（国家旗帜这条链踩过）
- 新增 `Assets/ManagedResources/Atlas/*/xxx.png` 后必须：① 生成 `.meta`（textureType 8、spriteMode 1、`spritePackingTag`）；② 在 **`ResConfigs/ResourcePathConfig.asset` 的 resInfoList 登记**（`Util.LoadSprite` 按资源名查表拿 pathIdx/abIdx），否则运行时取不到＝空白。
- 国家旗帜专用：美术全由 `.workbuddy/tools/gen_country_rank_art.py` 纯 PIL 生成（`--flags-only` 只重出旗帜），meta 由 `gen_country_rank_meta.py`（guid 按文件名派生，旧 guid 不漂移），登记由 `sync_guoqi_resinfo.py [--check]` 对齐。

## Unity MCP 直连 / UI 布局验证
- 🔴 本机没配 `mcp__unity__*`，但 Editor 的 `StdioBridgeHost` 在 **127.0.0.1:6400**；`.workbuddy/tools/unity_bridge.py` 直连（握手 `WELCOME UNITY-MCP 1 FRAMING=1`，帧＝8 字节大端长度 + JSON，`{"type":tool,"params":{}}`）。🔴 新连接会踢掉旧客户端。
- `execute_code` 结尾必须 `return <expr>;`；渲染 UI 实拍要开**临时 additive 场景**（prefab 根 inactive ⇒ 全黑；`NewPreviewScene` 里 Canvas 不参与 UI 更新 ⇒ 也全黑）。
- 🔴 手动摆放的网格别混用中心锚点与「从顶部算」的起始坐标（`CountryFlagSelectPopup` 曾因此把前 36 国摆到内容区上方被裁掉）；用顶部锚点 `(0.5,1)` + `-(row*H + H/2)`，pivot 保持 (0.5,0.5)。

## 配置表链路 / 已上线改动
- **配置表**：`data_execl/base_data/*.xlsx` 唯一真源，改后必须同步 `DataConfigMD5Record.asset` 的 CRC32 + 客户端 lua + LuaBytes + 服务端 `conf/server/*.txt`。
- **聊天持久化 Redis 兜底**（10-10）：list `serverId:CHAT_QUEUE:<sys|world|cross>`，「最近 5 条永久 + 其余 7 天」；部署必须 `PERSIST`；**不伪造消息**。补丁 `~/ts-chat-patch-20261010/`。
- **英雄升星氪金点恢复**（10-10）：`HeroRankupGroup` Id 31–53 的 `IsSameClan`→0、`IsId`→10011…10015；表启动载入内存 ⇒ **必须 restart（踢线）**。
- 本地新区服 10002 → `REF-shard10002.md`（已上线可登录，内测级）。

## Android 发版 / 账号（细节 `REF-android-release.md`）
- 🔴🔴 **versionCode 只增不减，同一号只能上一次（app 级全局，各轨道共享）**：当前 **69**，下一个 **≥70**。根因：GUI 打包自增、CLI 只读 ⇒ 补洞 `scripts/bump_version.py`。
- 🔴 别用 `aab_release.sh` 重跑**失败的推送**（再提一号→号段跳空），用 `--skip-build`/`play_upload.py`；撞车全局判定、退出码 5；把已上传的号挂别的轨道用 `--reuse-version-code N`（不传文件）。核对「包属于哪版」以 versionCode 为准。
- 🔴 送审闸门：默认不上传，`--upload`/`--production`/`--publish` 放行。**默认轨道=`internal`**；STATUS 按轨道推导（internal⇒completed，其余⇒draft）。`--status draft` 是 production「不送审」的唯一姿势。
- 🔴 交付自检 `scripts/verify_apk_delivery.py` 答「能不能测」；16KB 以**包内产物**为准（`verify_aab_native_16kb.py`），Unity 打印的 `libtolua.so is not 16KB-aligned` 是**误报**，**升引擎解决不了 16KB**。
- 🔴 上传期间禁止并发调任何 Play API（多进程开 edit 互删，`FAILED_PRECONDITION`）。
- 🔴 账号名 = f(登录 SDK 的 id)；Android `platformId==1` **必须 Google Sign-In**（`f74ffb436`），别改回 PlayGames。出包配置真源 `Assets/Editor/ReleaseBuildSettings.cs`。
- 🔑 Play 凭据：优先 `.secrets/service-account.json`，回退 `~/.gplay/`；`play-publisher@platinum-loop-468100-k5`。venv `.../envs/default/bin/python` 已装 google-api-python-client。
- 基准体积 2022.3=421.3 MiB / Unity 6=437.5 MiB（差 +16.2 全是引擎开销）。⚠️ **AB 原始体积异常未决**：Unity 6 `ChunkBasedCompression` 变松（磁盘 2.58→11.54 MiB，zlib 后不变），影响装机占用与热更体量。

## Jenkins 全流程 CI（细节 `REF-jenkins-ci.md`）
- 本机 Jenkins **2.551** `http://127.0.0.1:8080/`，7 个 job（Overview/Android-Release/TestPackage/Client-Resources/Server-Health/Server-Ops/Play-Watch）。🔴 cron 的 `H` 是**分钟**、`9`/`10` 是**小时** ⇒ 每天 9/10 点各一次。
- 🔴 单一真源 `.jenkins/jobs/*.groovy`：改完 `lint.sh` → `apply-jobs.sh`；有 warn 无 fail ⇒ UNSTABLE。文档 `docs/jenkins_ci.md`。
- 🔴 静态检查挡不住：Content-Type 必须带 `charset=UTF-8`；`<sandbox>` 必须 true；`junit testResults` 必须相对 workspace；ANSI 进 XML ⇒ 报告 failed-to-read。
- 🔴 `POST /job/<n>/build` 在 2.551 恒 400；用 `/buildWithParameters` + `--data-urlencode 'json={"parameter":[]}'`。
- 🔴 任务一律走 Jenkins（用户 10-13 要求）。`~/.jenkins/jobs/` 本身是 git 仓库（`master`），`apply-jobs.sh` 后必变脏 ⇒ **commit + push**（`github.com/a772616239/JenkinJobs.git`）。

## 🔴 约定（红线）
- 巡检默认**只读**（不重启、不改配置），报告要有量化证据并分级 🔴/⚠️。
- 发版/上线**必须先给用户看并取得明确同意**；打包/构建/校验/提交 git 可自行做；「上传 production + completed」= 提交审核，**先问**。重启生产游戏服（踢线）同理。
- 🔴 代码改动逐条 commit **并且必须 push**（commit 完不推＝没交付，用户 10-18 明确要求）；中文 `type(scope): 摘要`，**严禁 `git add -A`**；Lua 源码 + LuaBytes 成对。skill/记忆一律写工程内（`.workbuddy/memory/`、`.workbuddy/skills/`）。
- 🔴 **两个仓库都要管（用户 10-18 再次强调）**：客户端 `TimeSpaceGirl1`（分支 `release`）+ 服务端 `TimeSpaceServer/Server_x1tag1.2.2`（分支 `x1-tag-1.2.2`），各自独立 remote；服务端有并行会话会自动 commit，提交只能显式列路径，push 前先看 `origin/<branch>..HEAD` 里混没混别人的提交。
  - 🔴 结构别搞错：**`TimeSpaceServer/` 本身不是仓库**（`git rev-parse` 回主仓 `TimeSpaceGirl1`）。它的 `patches/`、`skzc/` 等 **1970 个文件由主仓跟踪** ⇒ 改这些 = 提交主仓；只有 `TimeSpaceServer/Server_x1tag1.2.2/` 被 `.gitignore:40` 排除、是独立 repo。
  - ⇒ 判定「是否都推了」的正确口径：`git -C 主仓 rev-list --count origin/release..release` 与 `git -C Server_x1tag1.2.2 rev-list --count origin/x1-tag-1.2.2..x1-tag-1.2.2` 都为 0。
- 凭据一律 `.secrets/`（700/600、永不入库）。⚠️ 远端是 PUBLIC 仓，4 个 keystore 自 2025-07 已进库，用户 10-13 决定**不处置、不再重提**（`docs/secrets_setup.md` §6）。
- 🔴 后台长任务（>1 分钟）**不能 `nohup &`/`disown`** ⇒ `subprocess.Popen(..., start_new_session=True, DEVNULL)`，判活放到**下一次**工具调用里 `pgrep`/`lsof`。
- 🔴 shell 含中文标点时变量写 `${VAR}`；`set -o pipefail` 下早退读端（`| head -1`、`| grep -q`）会造 SIGPIPE 假失败 ⇒ 加 `|| true` 或改内建判定，诊断打**完整**输出。
- 本机 BSD 工具坑：`find` 无 `-newermt`（用 `-mmin`）、无 `timeout`、沙箱 `ps` 不可用（用 `pgrep -fl`）、**`grep` 不认 `\|`（一律 `grep -E`）**。沙箱代理扛不住多 GB 响应 ⇒ 大仓库 fetch 用 `git -c http.proxy=`。
- 🔴 改系统级状态（`/home`、挂载点、`synthetic.conf`、launchd、`/etc/*`）必须标注**重启后是否有效**并当场验证。
