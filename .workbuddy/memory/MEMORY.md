# TimeSpaceGirl1 项目长期记忆

> 本文件只做**索引**，细节一律在同目录 REF 文件里（按需再读），当日细节进 `YYYY-MM-DD.md`（append-only）：
> `REF-server-ops.md`（服务端打包/热补丁/热更）· `REF-shard10002.md`（本地区服 10002 全部细节）·
> `REF-android-release.md`（AAB 打包上传管线 + AssetBundle + 16KB + 账号体系 + 发版 shell 坑）·
> `REF-config-tables.md`（配置表 xlsx→lua→TSV + CRC32 门控）· `REF-server-name-i18n.md`（区服名多语言）·
> `REF-jenkins-ci.md`（本机 Jenkins 全流程 CI）。

## 🔴 客户端 Unity：6000.6.5f1（2026-10-13 升级，编译全绿，细节见 `2026-10-13.md`）
- `ProjectVersion.txt` = `6000.6.5f1 (3ff58d469c8a)`。🔴 **必须写国际版号**，中国版版号串会被 UPM 直接拒绝。
- 编辑器路径 `/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity`。
- 🔴 **batchmode 跑本工程必须显式 `-buildTarget Android`**：`UNITY_ANDROID` 只在 active build target 为 Android 时定义，否则 `com.google.play.games` 编译成空程序集并连带报错。
- 🔴 **批量改文件的 python 补丁脚本要自查两副作用**：① `"` 被写成 `\"`；② CRLF 被归一化成 LF。取路径必须用 `git diff --name-only -z`（`git status --short` 会给含空格路径加引号而漏改），并按扩展名白名单跳过二进制。
- 🔴 Unity 6 会**就地改写**源目录：Gradle 模板（注入 `keepUnitySymbols/common.gradle`、`ndkVersion`、`debugSymbolLevel`）、场景重序列化、`ProjectSettings/*`。不提交则每次打包都变脏（2026-10-13 已收编）。
- 已停用（`_disabled_for_unity6/`）：AssetBundles-Browser 1.x、`DefaultPackerPolicySampleToNormal.cs`。

## 项目 / 生产环境
- Unity 手游「时空美少女/时空战场」客户端 + 同仓 `TimeSpaceServer/`；远端 `a772616239/TimeSpaceGirl1`（~3.3GB，public）。
- SSH 别名 `gs` → 129.226.213.65（腾讯云 CentOS7，内网 10.3.0.15）；私钥优先取工程本地 `.secrets/tencent-gameserver.pem`，回退 `~/.ssh/tencent-gameserver.pem`；上传助手 `~/server-push.sh`。
- **2vCPU / 3.6GB RAM / 59G 盘 → 已榨干，不能再起第二个 gameserver。**
- `/home/java/{gameserver,loginserver,chatserver,xxljob}`；Mongo/Redis/Nginx 由宝塔管。`gameSrv-1.0.0.jar`（netty 16081，`-Xms1280m -Xmx1280m`）、Tomcat 8.5.95 登录服 8080、mongod 27017、redis 6379（**无密码**、`bind 127.0.0.1`）。
- 重启 `/home/java/gameserver/RESTART-GAMESERVER.sh`（幂等）。日志 `/data/srvlog/{gameserver,chatserver}.log`。🔴 Mongo 连接串**必须含 `authSource=admin`**。

## 区服寻址（开新服必读）
- 区服列表**动态**：登录库 `x1_cn_test_login.server_info` → 登录服 HTTP 下发 → 客户端 `ServerListSelectPanel.lua` 渲染 ⇒ **新增区服＝插一条记录**，客户端不用出包、**登记即生效**（不用重启登录服）。客户端硬编码 `channel=pc / plat=android / sub_channel=1`，记录必须对齐。
- 🔴 `tk/getServerList` 的 server_version 门控：必须传真实版本 **`1.26001`**（传 `0` 会被自己数进 `shenheNum` 跳过 → **空列表**），记录里照抄 `"0"`。
- 🔴 **隐藏区服只能靠服务端不下发**（`state` 门控；客户端逐条渲染**不过滤**）。`add-shard-10002.sh {hide|show}` 幂等。
- 🔴 **语言 id 权威表**（`conf/server/MultiLanguage.txt`，`lanid=floor(id/100)%100`）：**10001=中文CNY / 10101=English USD / 10002=中文USD / 10201=日文 / 10301=韩文** ⇒ 英文**不是** 10002。
- 🔴 **`GameSettings.originLan` 不是发行口径**：真机首启（`GameSettings.cs:110-114` 非 Editor 分支）用**设备系统语言**覆盖它，只有 Editor 尊重 Inspector 值。⇒ `Logo.unity` 里的 `originLan`（现 10101）别当发布开关用。
- ⇒ 细节（server_version 门控原文、隐藏状态机、`isTestLan=1` 免 sign 自测法、区服名多语言、骨架文档）全在 **`REF-server-ops.md` §区服登记与寻址**。

## 巡检
- `scripts/server_health_check.py`：本机 SSH 采集 → QQ SMTP 发信 → 留档 `scripts/logs/`。定时任务 id `fb2c3e4c-7290-4cfa-9606-83cd5144f03c`（每日 10:00）。
- SMTP `smtp.qq.com:465` SSL（回退 587），收发 `772616239@qq.com`。授权码**已收归工程本地 `.secrets/health.env`**（600、永不入库、SMTP 登录实测通过）；回退链 `~/.gs_health.env` → `/Volumes/S/TD/.env` 等，脚本逐个试登录、自动跳过失效口令，**缺失文件也安全跳过**。

## 🔴 客户端 Lua：改完必须重生成 LuaBytes 字节码
- 真机跑**预编译字节码**（`!isEditor` 时 `GameSettings.cs:112-117` 强制 `luaBundleMode=true` → 读 `Assets/ManagedResources/LuaBytes/<路径下划线化>_64.bytes`）；只有 Editor 回落 `~Lua/*.lua`。
- ⇒ **只改 `~Lua` 源码 = Editor 有效、真机无效**，两文件必须成对提交。
- 重编码：`cd LuaEncoder/luajit_mac/64 && LUA_PATH="./?.lua;;" ./luajit -b <abs>/X.lua <abs>/X_64.bytes`。🔴 必须带 `LUA_PATH` 且在本目录执行；🔴 **不要加 `-g`**。验证 `./luajit -bl X_64.bytes`，魔数应为 `1b4c4a02`。
- 🔴 **运行时 LuaJIT 必须与字节码编码器严格同版本**（同 2.1 线也不行 ⇒ **启动即卡死**）。`libtolua.so` 出自 **`topameng/tolua_runtime`**（LuaJIT **2.1.0-beta3**），重编走 `scripts/libtolua16k/`；**别用 `alex4814/tolua_runtime`**（2.1.ROLLING）。
- 🔴 **`require` 名必须与 `module()` 名严格一致**：`module("a.b")` 只写 `package.loaded["a.b"]`；require 后若仍是哨兵，Lua 会填成 **`true`** ⇒ require 返回 boolean，调用方一索引即崩（`attempt to index a boolean value`）。

## 配置表链路 / 其它已上线改动
- **配置表**：`data_execl/base_data/*.xlsx` 是唯一真源，改后**必须同步 `DataConfigMD5Record.asset` 的 CRC32**，且客户端 lua + LuaBytes + 服务端 `conf/server/*.txt` 三处。细节 `REF-config-tables.md`。
- **聊天持久化 Redis 兜底**（2026-10-10）：Redis list `serverId:CHAT_QUEUE:<sys|world|cross>`（`mid#ts#Base64(ChatInfo)`，`rightPush + trim(-200,-1)`），「最近 5 条永久保底 + 其余 7 天」；🔴 部署必须 `PERSIST <key>`；**不伪造消息**。补丁 `~/ts-chat-patch-20261010/deploy-chat-patch.sh`。
- **英雄升星氪金点恢复**（2026-10-10）：`HeroRankupGroup` Id 31–53 的 `IsSameClan`→0、`IsId`→10011…10015。部署 `~/ts-upstar-restore-20261010/deploy.sh`。⚠️ 表启动载入内存 → **必须 restart**（会踢线）。
- **本地新区服 10002** → `REF-shard10002.md`。一句话：**已上线可登录，属内测级**。

## Android 发版 / 账号体系 → 细节见 `REF-android-release.md`
- 🔴🔴 **versionCode 只增不减，同一号只能上一次（app 级全局，跨全部轨道共享）**：当前 **69**（2026-10-13 已 `completed` 上 production，并以 `--reuse-version-code` 复用挂到 internal），**下一个新号必须 ≥ 70**。
  - 根因：GUI 打包（`BuildWindow.cs:449`）**自动自增**，CLI 的 `CLIBuilder.cs` **只读不自增** ⇒ CLI 反复打包复用同一个号。补洞 `scripts/bump_version.py`。
  - ⇒ 🔴 **别用 `aab_release.sh` 重跑已失败的推送**（会再提一号 → 号段跳空）；重传用 `--skip-build` 或直接 `play_upload.py`。撞车按**全局**判定并以**退出码 5** 拦截；把已上传的号挂到别的轨道用 `--reuse-version-code N`（**不传文件**）。核对「告警/包属于哪一版」**必须以 versionCode 为准**。
- 🔴 **送审闸门**：默认不上传 + 三旗标显式放行（`--upload` / `--production` / `--publish`）。🔴 **默认轨道 = `internal`（内部测试），不是 production**（2026-10-13 改，用户要求"不要直接传正式环境，传内部测试的管线"）；`STATUS` 按轨道推导（internal⇒completed，其余⇒draft），internal 豁免 `--publish`（草稿在 internal 上等于没传）。🔴 **`--status draft` 是 production 轨道"不送审"的唯一姿势**。🔴 Play **各轨道共享 versionCode 空间**，换轨道重传同号同样被拒。
- 🔴 **交付自检 `scripts/verify_apk_delivery.py`** 答「这包能不能测」；16KB 以**包内产物**为准（`scripts/verify_aab_native_16kb.py`），Unity 打印的 `libtolua.so is not 16KB-aligned` 是**误报**；**升 Unity 引擎解决不了 16KB**。
- 🔴 **上传期间禁止并发调用任何 Play API**（多进程开 edit 会互删，实测 85% 处 `HTTP 400 FAILED_PRECONDITION`）。
- 🔴 **账号名 = f(登录 SDK 给的 id)**，换 SDK 就等于换号；Android `platformId==1` **必须走 Google Sign-In（`f74ffb436`），勿改回 PlayGames**。
- 出包配置真源 `Assets/Editor/ReleaseBuildSettings.cs`（`297b9ba9f`）；线上渠道值就是 `None`、`isSDK=false` 是**正常**的。
- 🔑 **Play 凭据**：优先**工程本地 `.secrets/service-account.json`**（700/600），回退 `~/.gplay/service-account.json`；账号 `play-publisher@platinum-loop-468100-k5.iam.gserviceaccount.com`，project `platinum-loop-468100-k5`。完整优先级链见 `REF-android-release.md`。venv `/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python` 已装 google-api-python-client。

## 全流程 CI（Jenkins）→ 细节见 `REF-jenkins-ci.md`
- **7 个 job**（本机 Jenkins **2.551**，`http://127.0.0.1:8080/`，视图「时空美少女 · 全流程」）：`TS-Pipeline-Overview` / `TS-Android-Release` / `TS-Android-TestPackage` / `TS-Client-Resources` / `TS-Server-Health`(cron `H 10`) / `TS-Server-Ops` / `TS-Play-Watch`(cron `H 9`)。🔴 cron 里 `H` 是**分钟**、`9`/`10` 是**小时** ⇒ **每天 9 点 / 10 点各一次**，**不是每小时**。
- 🔴 **单一真源在仓库**：`.jenkins/jobs/*.groovy`，改 job 不用点界面/重启 ⇒ 改完跑 `.jenkins/lint.sh` → `.jenkins/apply-jobs.sh`。权威文档 `docs/jenkins_ci.md`。`.jenkins/run/` 是运行态产物，不入库。**有 warn 无 fail ⇒ UNSTABLE（黄球）**。
- 🔴 **静态检查挡不住的三类坑**：`config.xml` 的 Content-Type **必须带 `charset=UTF-8`**；`<sandbox>` **必须 `true`**；`junit testResults` **必须相对 workspace**；ANSI 码进 XML ⇒ 整份报告 `[failed-to-read]`。
- 🔴 **`POST /job/<n>/build` 在 2.551 上恒 400**；正确姿势 `POST /buildWithParameters` + `--data-urlencode 'json={"parameter":[]}'` → 201。
- 🔴 **自检也会假红**：`play_gate.sh` 曾因判定用管道而误判（同一份代码 Jenkins 判 fail、本地 17 次全绿），已修 `930965657` —— 机理见下方「pipefail 假失败」红线。

## 🔴 约定（红线）
- 巡检默认**只读**：不重启服务、不改服务器配置。报告要有量化证据，区分「严重🔴 / 关注⚠️」。
- 🔴 **发版 / 上线前必须先给用户看过并取得明确同意，绝不自行提交审核。** 打包、构建、校验、提交 git 可以做；**「上传到 production 轨道 + status=completed」= 提交审核，必须先问**。
- 🔴 重启生产游戏服（会踢线）**必须先取得用户确认**。
- 🔴 代码改动逐条 commit，中文 `type(scope): 摘要`，**严禁 `git add -A`**；客户端 Lua 改动须源码 + LuaBytes 成对提交。
- 🔴 本项目 skill 与记忆**一律写在工程目录下**：记忆 → `.workbuddy/memory/`；Skill → `.workbuddy/skills/<name>/SKILL.md`。
- 🔴 **凭据一律放工程本地 `.secrets/`**（目录 700、文件 600，`.gitignore` 整目录排除、**永不入库**）：Play service account / 服务器 SSH pem / 巡检 SMTP 授权码，三者均已落盘并端到端实测（SSH 通 / SMTP 通过 / Play 密钥可解析）；布局与换机恢复见 `docs/secrets_setup.md`。⚠️ 远端 `a772616239/TimeSpaceGirl1` 是 **PUBLIC 仓库**，`.gitignore` 只挡未来提交、**摘不出已入库的文件** —— 仓内 4 个签名 keystore（`user` / `beauty` / `keystore/emiplay` / `userGP_for_total_war`.keystore）自 2025-07 已进公开库，**用户 2026-10-13 决定不处置**（「代码里已指定用什么 key」）⇒ **不再主动重提**；将来收口见 `docs/secrets_setup.md` §6。
- 🔴 **后台长任务（>1 分钟）不能用 `nohup cmd &` / `disown`**：几十秒内会被**父会话进程组清理**杀掉（日志只留第一行、无报错，极易误判成脚本 bug）。唯一可靠姿势 `python -c "subprocess.Popen([...], stdout/stderr/stdin=DEVNULL, start_new_session=True)"`；判活要在**下一次工具调用**里 `pgrep`/`lsof`，不能同一调用内 sleep 后查。详见 skill `background-longrun-detach-macos`。
- 🔴 **shell 脚本含中文标点时变量必须写 `${VAR}` 花括号**：`set -u` 下 `"…$STATUS）"` 会因全角括号字节并入变量名而报 `unbound variable`。
- 🔴 **`set -o pipefail` 下「早退的读端」会制造假失败**：`cmd | head -1` / `printf … | grep -q pat` 里读端命中即退 ⇒ 写端收 SIGPIPE(141) ⇒ 整条管道被判失败，把「成功 / 已命中」读成「失败 / 未命中」。
  ⇒ **判定要么加 `|| true`，要么改用内建**（`[[ "$out" == *pat* ]]`，顺带摆脱对 locale 的依赖）；失败诊断要打**完整**输出，别 `tail -3`（恰好会裁掉决定性的首行）。已修 `930965657`。
- 本机 `find` 是 BSD 版**不支持 `-newermt`**（用 `-mmin`）；**无 `timeout`**（GNU coreutils）；`ps` 在沙箱里 operation not permitted，用 `pgrep -fl` 代替。
- 🔴 **本机 grep 是 BSD 版：BRE 下不认 `\|`**（GNU 扩展）⇒ `grep 'a\|b'` 被当**字面量**、匹配不到、退出 1；叠上 `set -o pipefail` 会把「有值」误报成「无值」。**一律用 `grep -E`**。
- ⚠️ **沙箱网络**：沙箱注入的 HTTP 代理**扛不住多 GB 单次响应体**（early EOF）⇒ 大仓库 fetch 用 `git -c http.proxy=` 直连。⚠️ 曾记「ClashX Pro TUN 接管全部 IPv4 ⇒ 本机 SSH 到云服/GitHub 全断」，**2026-10-13 傍晚已证伪**：`ssh gs hostname` 与生产服只读巡检**均正常**（当天 16:59 那次 Jenkins 红是当时的瞬时状态，现已恢复）。
- 🔴 **凡改动系统级状态（`/home`、挂载点、`synthetic.conf`、launchd 域、`/etc/*`），记忆里必须显式标注「重启后是否仍有效」**，并当场验证一次。
