# TimeSpaceGirl1 项目长期记忆（索引型）

> 细节见同目录 REF / 当日 `YYYY-MM-DD.md`：`REF-server-ops.md`（打包/热补丁/区服）· `REF-local-server.md` · `REF-android-release.md` · `REF-config-tables.md` · `REF-server-name-i18n.md` · `REF-jenkins-ci.md`。

## 客户端 Unity 6000.6.5f1
- `ProjectVersion.txt` = `6000.6.5f1 (3ff58d469c8a)`；🔴 必须写**国际版号**（中国版串被 UPM 拒）。batchmode 必须显式 `-buildTarget Android`，否则 `com.google.play.games` 编成空程序集连带报错。
- 🔴 Unity 6 **就地改写源目录**：动过 prefab 后导入会追加 `serializedVersion`、删 `m_MaskInteraction`，属正常噪声，别回滚。

## 生产环境
- 客户端 + 同仓 `TimeSpaceServer/`；远端 `a772616239/TimeSpaceGirl1`（~3.3GB，**PUBLIC**）。
- 🔴 **服务端代码 = `TimeSpaceServer/Server_x1tag1.2.2/`**（独立仓库，分支 `x1-tag-1.2.2`；`server_game/` 多模块 + `deploy/` + `deploy-overlay/`）。服务端逻辑/配置/脚本一律写这里；该仓有并行会话自动 commit ⇒ **提交只能显式列路径**。
- SSH `gs` → 129.226.213.65（CentOS7，内网 10.3.0.15，私钥 `.secrets/tencent-gameserver.pem`）。**2vCPU/3.6GB 已榨干，不能再起第二个 gameserver。**
- `/home/java/{gameserver,loginserver,chatserver,xxljob}`：`gameSrv-1.0.0.jar`（16081，`-Xmx1280m`）、登录服 8080、mongod 27017、redis 6379（**无密码**、bind 127.0.0.1）。重启 `RESTART-GAMESERVER.sh`（幂等）；日志 `/data/srvlog/*.log`；🔴 Mongo 串**必须含 `authSource=admin`**。
- 🔴 热补丁已转正源码（`77402068`）：`patch/AdventureRewardGuard` + `patch/PayGateGuard`，javap 验过 ⇒ **别重复注入**。编译必须联网（缺 `spring-boot-starter-data-mongodb:1.5.9`）、`gradlew` 用 `sh gradlew`。

## 协议（protobuf 2.5.0）
- 🔴 运行时 protobuf-java **2.5.0**；protoc 33 生成 `GeneratedMessageV3` ⇒ **编不过**。仓库只有 win32 protoc，mac 版手搓流程见 `2026-10-19.md`（产物 `/tmp/pb25b/protoc`，重启即失）。
- 姿势：先用 HEAD proto 生成到临时目录，与在库 `CommonProto.java` **逐字节 diff 一致**，再改 proto 重新生成。
- 🔴 协议类不在主 jar：`protocols.*` 在 `lib/gamecommon-1.0.0-SNAPSHOT.jar`（主 jar 用 MANIFEST Class-Path 引 47 个 lib）⇒ 换协议**两个 jar 一起动**。**只更新主 jar 不更新 gamecommon ⇒ `NoSuchMethodError`（如 `ChatInfo.getCountry`）⇒ 登录卡死**（10-19 事故）。
- 🔴 重建 gamecommon 会丢 `util/SysUtil.class` 热补丁（读 `-Dgameserver.root`）⇒ 用 `zip -u` 只注入**差异类**（`diff -rq` 解包目录 vs `build/classes/java/main`，先 `touch` 否则 mtime 相同静默跳过）。
- 客户端 lua 侧**手工补字段**（`~Lua/Message/*_pb.lua`：`XXX_FIELD` 声明 + 描述 + 加进 `.fields`）后重编 LuaBytes；`proto/protos/*.proto` 同步。已加：`Player.country=25`、`UserRank.country=17`、`TeamOneInfo.country=21`、`ArenaPersonInfo.country=16`、`ChatInfo.country=28`。

## 区服寻址 / 语言（→ `REF-server-ops.md`）
- 列表**动态**：`x1_cn_test_login.server_info` → 登录服 HTTP → `ServerListSelectPanel.lua` ⇒ 新增区服＝插一条记录，客户端不出包、不重启登录服（硬编码 `channel=pc/plat=android/sub_channel=1` 要对齐）。
- 🔴 `tk/getServerList` 的 server_version 必须传真版本 **`1.26001`**（传 `0` 会把自己数进 `shenheNum` → 空列表）；记录里照抄 `"0"`。
- 🔴 隐藏区服只能靠服务端不下发（`state` 门控）；`add-shard-10002.sh {hide|show}` 幂等。
- 🔴 语言 id（`lanid=floor(id/100)%100`）：**10001=中文CNY / 10101=英文USD / 10002=中文USD / 10201=日文 / 10301=韩文** ⇒ 英文**不是** 10002。`GameSettings.originLan` 不是发行口径：真机首启用**设备系统语言**覆盖（`GameSettings.cs:110-114`）。

## 日志 / 巡检
- `scripts/server_health_check.py`：SSH 采集 → QQ SMTP → 留档 `scripts/logs/`；定时任务 `fb2c3e4c-…`（每日 10:00），口令 `.secrets/health.env`。
- 🔴 日志清理＝logback 主力（**jar 内** `deploy-overlay/gameserver-jar/logback-boot.xml` 的 `maxHistory`，改服上 `assets/conf/` 副本无效）+ 脚本兜底（`deploy/log_cleanup.py`，cron 04:17）。环境 **logback 1.1.11** 无 `totalSizeCap`/`cleanHistoryOnStart`。

## 🔴 Lua 改动必须重编 LuaBytes
- 真机跑字节码（`!isEditor` 强制 `luaBundleMode=true`，读 `LuaBytes/<路径下划线化>_64.bytes`）⇒ **源码+字节码成对提交**；`scripts/lua-bytes-sync.sh <lua>`（`--check` 自查），**不加 `-g`**，魔数 `1b4c4a02`。
- 🔴 运行时 LuaJIT 必须与编码器**严格同版本**；`libtolua.so` 出自 **`topameng/tolua_runtime`**（2.1.0-beta3），重编走 `scripts/libtolua16k/`。
- 🔴 `require` 名必须与 `module()` 名一致（否则 `package.loaded` 填 `true` 一索引就崩）；Editor 热验清缓存键是**点号**。

## 图集 / 国家旗帜
- 新增 `Atlas/*/xxx.png` 必须：① `.meta`（textureType 8、spriteMode 1、`spritePackingTag`）；② 在 **`ResConfigs/ResourcePathConfig.asset` resInfoList 登记**，否则 `Util.LoadSprite` 取不到＝空白。工具：`gen_country_rank_art.py` / `gen_country_rank_meta.py` / `sync_guoqi_resinfo.py --check`。
- 🔴 改旗刷新**唯一收口** `CountryRankManager.SetPlayerCountry` → `OnCountryChanged` + `CountryFlagUtil.RefreshSelfFlags()`。「自己」的节点必须走 `CountryFlagUtil.Apply/ApplySelf`（弱键登记才能就地重画）；直接 `img.sprite=...` 不刷新。节点名 `countryFlag`。
- 已挂：通用排行榜 ItemPre/Record/前三名、玩家信息、设置页、竞技场 enemy_1..3、竞技排行 ItemPre/Record（`patch_arena_rank_flag.py`）、聊天气泡（`patch_chat_flag.py`）。点击弹英文名用 `MakeClickable`（`m_RaycastTarget` 必须 1；`Util.AddClick` 遇无 Button 节点静默 return）。
- 🔴 前三名小旗**唯一写入点** `SetHeadFlag(index, data)`：缺名次/公会榜 → **隐藏**（不是跳过）；`SetHeadsInfo`/`SetHeadsHeroInfo` 都走它；英雄榜不走 `SetNotRollingInfo` ⇒ 需补 `RefreshMyRankFlag`。回归 `scripts/lua-tests/test_rank_head_flag.lua`。
- 聊天国旗三处模板分别打：`ChatPanel`、`BattlePanel`、`FightPointPassMainPanel` 的 `content/chat`（`patch_chat_flag.py --prefab --chat`）。🔴 BattlePanel/FightPoint 是**独立副本不是嵌套 prefab**。
- 聊天气泡旗：`ChatInfo.country=28`（服务端 `ChatLogic.fillSenderCountry` 填、客户端 `ChatProto_pb.lua` 手工补）；系统消息隐藏、`senderId>0` 才画，未下发走问号占位；老消息无 country ⇒ `ChatManager.PlayerCountryCache`（`GetPlayerCountry`）兜底。

## Unity MCP / UI 布局
- 🔴 未配 `mcp__unity__*`；`StdioBridgeHost` 在 **127.0.0.1:6400**，`.workbuddy/tools/unity_bridge.py` 直连（握手 `WELCOME UNITY-MCP 1 FRAMING=1`，帧＝8 字节大端长度+JSON）。新连接踢旧客户端；**端口没监听就是没起来**。
- 🔴 探测端口**不能先开试探连接再关**（被判 stale client 连带关掉新连接，现象=发帧后 0.00s 断）；握手后 sleep 0.3s。偶发 `no StdioBridgeHost reachable` 多是 Editor 主线程忙，等 3s 重试。
- `execute_code` 结尾必须 `return <expr>;`；UI 实拍要开**临时 additive 场景**（prefab 根 inactive、`NewPreviewScene` 的 Canvas 都不更新 ⇒ 全黑）。
- 🔴 `CanvasScalerAdapter` 宽高比 <16:9 时 match=0 ⇒ 画布宽恒 1080、高随屏幕变 ⇒ 中心锚点 `(x,0.5)` 的兄弟整体下移；贴屏幕角就锚顶角。摆网格别混用中心锚点与「从顶部算」，用 `(0.5,1)` + `-(row*H+H/2)`。
- 🔴 但「该不该跟画布中心走」**按需求定**：`BattleUltCard` 定稿是「跟随技能栏、落在画面中部」，10-19 擅自改锚顶角被否（`a0408226a` 已回退）。**改位置前先问口径**（曾混用「顶边占屏%」与「中心占屏%」误判 8%，实测差 0.8%）。
- 🔴 `Timer.New(f, 秒)` 第 4 参不给 ⇒ `unscaled=false` 走 `Time.deltaTime`，**受战斗倍速影响**（`SetTimeScale` 直改 `Time.timeScale`，3 倍速「3 秒」只剩 1 秒）；UI 停留时长一律传 `true`。
- 🔴 同一元素的**隐藏定时器必须先 Stop 旧的再 New**，否则旧定时器到点把刚显示的关掉（`myRect_Skill` 闪一下就没 ⇒ 连带 `HelpHeroMiniCard_Mine` 消失；10-19 修：`ShowSkillBar` 收口 + `CARD_MIN_LIVE_TIME`/miss 防抖）。回归 `scripts/lua-tests/test_skill_bar_timer.lua`。
- 🔴 战场相机根高度**唯一收口** `BattleManager.SetCameraRootY(scene, y)`：战斗 `-1.57`（`BattleView:InitComponent`）、挂机 `0`（`FightPointMapOnHook:InitComponent`）。`BattleScene.prefab` 的 `CameraRoot` 默认留 **0**；`CreateBattleScene` 每次 `Instantiate`，别改 prefab 做战斗偏移。

## 配置表 / 历史改动
- 🔴 配置表唯一真源 `data_execl/base_data/*.xlsx`，改后同步 `DataConfigMD5Record.asset` 的 CRC32 + 客户端 lua + LuaBytes + 服务端 `conf/server/*.txt`。
- 聊天 Redis 兜底（10-10）：`serverId:CHAT_QUEUE:<sys|world|cross>`「最近 5 条永久 + 其余 7 天」，部署必须 `PERSIST`，**不伪造消息**；重启时 `MessageCache` 从 redis 还原。
- 英雄升星氪金点（10-10）：`HeroRankupGroup` 31–53 `IsSameClan`→0、`IsId`→10011…10015；表启动载入内存 ⇒ **必须 restart**。
- 敏感词 DFA 瘦身（10-18）：`SensitiveWordInit` 静态 map 撑到 497MB（活堆 74%）⇒ 已改 CSR `SensitiveWordTrie`（444.3→26.6MB，API 不变），**只在源码，需重打 jar**；扫描 `scripts/verify/HprofRefScan.java`。
- 本地自测服 → `REF-local-server.md`；🔴 **launchd 自启** `com.ts.localserver.{gameserver,loginserver}`，`~/home/java/start-local.sh {status|start|stop|restart|install|logs} [gs|login]`。**agent shell 里 `launchctl bootstrap` 恒 EIO 5 ⇒ `install` 必须用户 Terminal 跑**；`restart gs` 可用（刚重启 status 会短暂 DOWN，等 10s）。
- 客户端连本地：`<工程>/AssetBundles/version.txt` 改 `serverUrl=http://127.0.0.1:8081/`（**跟踪文件，勿提交**）；测试号 `localtest/123456`、`10000004`(cn) / `10000005`(it)。

## Android 发版 / Jenkins（→ 两个 REF）
- 🔴🔴 **versionCode 只增不减，同号只能上一次（app 级全局、各轨道共享）**：当前 **69**，下个 **≥70**（GUI 自增、CLI 只读 ⇒ `scripts/bump_version.py`）。失败推送别重跑 `aab_release.sh`（号段跳空），用 `--skip-build`/`play_upload.py`；撞车退出码 5；复用号 `--reuse-version-code N`。
- 🔴 送审闸门：默认不上传，`--upload`/`--production`/`--publish` 放行；默认轨道 `internal`（⇒completed，其余⇒draft），`--status draft` 是 production 不送审的唯一姿势。
- 🔴 16KB 以**包内产物**为准（`verify_aab_native_16kb.py`）；Unity 报 `libtolua.so is not 16KB-aligned` 是**误报**。自检 `scripts/verify_apk_delivery.py`；上传期间禁止并发 Play API。体积基准 421.3(2022.3)/437.5 MiB(Unity6)；⚠️ AB 原始体积未决。
- 🔴 账号名 = f(登录 SDK 的 id)；Android `platformId==1` **必须 Google Sign-In**（`f74ffb436`）。出包真源 `Assets/Editor/ReleaseBuildSettings.cs`，凭据 `.secrets/service-account.json`。
- Jenkins 本机 **2.551** `127.0.0.1:8080`，7 job；🔴 cron `H` 是**分钟**。真源 `.jenkins/jobs/*.groovy`（`lint.sh`→`apply-jobs.sh`，warn⇒UNSTABLE）；静态检查挡不住：Content-Type 要 `charset=UTF-8`、`<sandbox>` true、`junit` 相对路径、ANSI 进 XML 会 failed-to-read。
- 🔴 `POST /job/<n>/build` 在 2.551 恒 400 ⇒ `/buildWithParameters` + `--data-urlencode 'json={"parameter":[]}'`。`~/.jenkins/jobs/` 改完必须 commit+push。

## 🔴 约定（红线）
- 巡检默认**只读**，报告要量化证据并分级 🔴/⚠️。
- 发版/上线**先取得明确同意**；打包/构建/校验/commit/push 可自行做；上传 production+completed（=送审）与重启生产服（踢线）**先问**。
- 🔴 改动逐条 commit **并且必须 push**（不推＝没交付）；中文 `type(scope): 摘要`，**严禁 `git add -A`**；Lua 源码+LuaBytes 成对；skill/记忆写工程内。
- 🔴 **两个仓库都要管**：`TimeSpaceGirl1`（`release`）+ `Server_x1tag1.2.2`（`x1-tag-1.2.2`）。判定「都推了」= 两边 `rev-list --count origin/<branch>..<branch>` 都为 0；push 前看有没有混进并行会话的提交。
- 🔴 结构：**`TimeSpaceServer/` 本身不是仓库**（回主仓）；其 `patches/`、`skzc/` 约 1970 文件由主仓跟踪 ⇒ 只有 `Server_x1tag1.2.2/` 是独立 repo（`.gitignore:40`）。
- 凭据一律 `.secrets/`（700/600）。⚠️ 远端 PUBLIC，4 个 keystore 已在库，10-13 决定**不处置**。
- 🔴 后台长任务（>1 分钟）**不能 `nohup &`/`disown`** ⇒ `Popen(..., start_new_session=True, DEVNULL)`，判活放下一次 `pgrep`/`lsof`。
- 🔴 shell 含中文标点时变量写 `${VAR}`；`set -o pipefail` 下 `| head -1`/`| grep -q` 会造 **SIGPIPE 假失败** ⇒ 加 `|| true` 或用 Grep 工具。
- 本机 BSD 坑：`find` 无 `-newermt`（用 `-mmin`）、无 `timeout`、沙箱 `ps`/`ps -p` 不可用（用 `pgrep -fl`）、**`grep` 不认 `\|`（用 `grep -E`）**；大仓库 fetch 用 `git -c http.proxy=`。
- 🔴 改系统级状态（`/home`、挂载点、`synthetic.conf`、launchd、`/etc/*`）必须当场验证并标注**重启后是否有效**。
- 🔴 `BattlePanel.prefab` 工作区副本会被 Unity 重写成 13.8 万行（HEAD 19.5 万）⇒ 打补丁前先 `git show HEAD:path` 到临时文件，别在脏副本上改。
