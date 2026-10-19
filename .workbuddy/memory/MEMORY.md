# TimeSpaceGirl1 长期记忆（索引型）

> 细节见同目录 `REF-*.md`（server-ops / local-server / android-release / config-tables / server-name-i18n / jenkins-ci）与当日 `YYYY-MM-DD.md`；服务端/发版/GM 的完整口径都在那里，本文件只留红线。

## 环境速查
- 客户端 Unity `6000.6.5f1 (3ff58d469c8a)`：🔴 `ProjectVersion.txt` 必须国际版号；batchmode 必须显式 `-buildTarget Android`；Unity 6 就地改写源目录（追加 `serializedVersion`）属正常噪声。
- 远端 `a772616239/TimeSpaceGirl1`（~3.3GB，PUBLIC）；🔴 服务端代码在 `TimeSpaceServer/Server_x1tag1.2.2/`（独立 repo，分支 `x1-tag-1.2.2`），该仓有并行会话自动 commit ⇒ 提交必须显式列路径。
- SSH `gs` 129.226.213.65（CentOS7，内网 10.3.0.15，`.secrets/tencent-gameserver.pem`）；2vCPU/3.6GB 已榨干，不能再起第二个 gameserver。`/home/java/{gameserver,loginserver,chatserver,xxljob}`，重启 `RESTART-GAMESERVER.sh`，日志 `/data/srvlog/`；🔴 Mongo 串必须含 `authSource=admin`。
- 🔴 热补丁已转正（`77402068`）别重复注入；编译需联网、用 `sh gradlew`。

## 🔴 协议 protobuf 2.5.0
- 运行时 2.5.0，protoc 33 出 `GeneratedMessageV3` 编不过；先按 HEAD proto 生成并与在库 `CommonProto.java` 逐字节 diff 再改。
- `protocols.*` 在 `lib/gamecommon-1.0.0-SNAPSHOT.jar`（主 jar 靠 MANIFEST Class-Path 引 47 lib）⇒ 换协议两 jar 一起动，否则 `NoSuchMethodError`（如 `ChatInfo.getCountry`）⇒ 登录卡死；重建会丢 `util/SysUtil.class` 补丁 ⇒ `zip -u` 只注差异类（先 `touch`）。
- 客户端 `~Lua/Message/*_pb.lua` 手工补字段后重编 LuaBytes。已加 country：Player=25、UserRank=17、TeamOneInfo=21、ArenaPersonInfo=16、ChatInfo=28。

## 🔴 Lua / LuaBytes
- 真机跑字节码 `LuaBytes/<路径下划线化>_64.bytes` ⇒ **源码+字节码成对提交**；`scripts/lua-bytes-sync.sh`（`--check` 自查），不加 `-g`。
- LuaJIT 必须与编码器同版本；`libtolua.so` 出自 `topameng/tolua_runtime` 2.1.0-beta3，重编走 `scripts/libtolua16k/`。`require` 名＝`module()` 名。
- 长跑协程（`while true`）必须 OnClose+OnDestroy 双停（`DestroyPanel` 不走 OnClose、面板缓存复用）；代次 token+先停后起，节点用 `IsNull()`。样例 `FirstRechargePanel:StartHeroLoop`。
- 面板对象被 `openedList` 缓存复用（`noDestory=false` ⇒ Close 只 `SetActive(false)`）；`OnClose` 清 lua 表 ≠ 清克隆节点 ⇒ 动态子节点 Build 前按名清一次；`#map` 对字符串键恒 0（`fcfb62121`，回归 `test_country_flag_select_popup.lua`）。
- 🔴 tolua fake-null：`GameObject` 被 Destroy 后 lua 侧 userdata **仍非 nil** ⇒ `if not obj` 无效，判活只能 `IsNull()`/`tolua.isnull`（同类崩溃已三次：`b40b73ca4` 首充/绑定手机、`bbdb49452` 公告面板）。销毁判据＝`UIConfig.noDestory==0`（nil/false 只 `SetActive(false)` 缓存）；为 0 时 Close 走 `DelayDestroyPanel`（`DELAY_TIME=15s×openNum`）⇒ 异步回调有 15s+ 的「已销毁」窗口（`UIConfig[177]` 公告就是 0）。异步回调写 UI 一律「判活 + pcall + OnDestroy 清引用」。
- `Timer.New` 第 4 参缺省 ⇒ 受战斗倍速影响，UI 停留传 `true`；同一元素隐藏定时器先 Stop 再 New（`test_skill_bar_timer.lua`）。

## 挂机气泡（→ `.workbuddy/skills/afk-dialogue-authoring/SKILL.md`）
- 唯一消费点 `Modules/Fight/View/FightPointMapOnHook.lua`；池看 `AfkSpeak.Type`：0 通用 / 英雄id / 9900+n 地图 / **40000+英雄id 大招** / **9998 通用大招**。台词本体在 `Language`（D 列是语言 id）。
- 🔴 气泡 280×78、28 号字 ⇒ 最多两行（中≤16 字 / 英≤34 字符 / 日≤20）。不要数字符，用 Unity `TextGenerator.GetPreferredHeight` 实测（h≤74.5）。
- 🔴 加行只能 XML 层追加（`append_afk_ult_talk.py` 模板），**禁止 openpyxl 存盘**（空串变空单元格、整表重写）；导出必须走官方 `DataToOptimizeLuaExporter`；配置 lua 也要 `lua-bytes-sync.sh`。
- 大招＝槽位最高 `SkillType==2`；🔴 挂机演出**不卡 UnlockSkill**（槽位 3 要 Rank≥3，卡了全退化成槽位 1）；每场 55% 抽 1 人、多段压到 3 段；`ShowTalk` 是唯一冒泡入口（同位置定时器先 Stop）。

## 国家旗帜（→ docs/CountryFlag_FeatureDesign.md）
- 🔴 国家表已补齐 **250 国（ISO 3166-1 全量）**、旗 132×88：新增 png 必须补 `.meta`（textureType 8/spriteMode 1/spritePackingTag）+ `ResourcePathConfig.asset` resInfoList 登记，否则 `Util.LoadSprite` 空白。工具 `gen_country_rank_*`/`sync_guoqi_resinfo.py --check`（应为「250 条一致」）。
- `CountryConfig.GetName` 回落链＝当前语言→**en**→zh→code（lan 0=中/1=英/2=日/3=韩）；日韩缺译名不得露简体中文。
- 🔴 改旗刷新唯一收口 `CountryRankManager.SetPlayerCountry`→`OnCountryChanged`+`RefreshSelfFlags()`；自己必须走 `Apply/ApplySelf`（弱键登记）；节点名 `countryFlag`；点击弹名 `MakeClickable`（`m_RaycastTarget`=1）。
- 🔴 前三名唯一写入点 `SetHeadFlag(index,data)`：缺名次→隐藏；公会榜按会长 country，无则隐藏。
- 🔴 「我的排名」行走 `RefreshMyRankFlag`：判定顺序＝**空榜 → 未上榜 → 分会榜**（`noneImage.activeSelf` / `myRankValid`/`HasValidRank`），Unranked 必须隐藏；公会战力榜这一行＝**我的公会** ⇒ 旗取会长国籍（`ResolveMyGuildFlag`：从已加载 `GuildData` 按会长 uid/公会名反查，查不到退回自己；会长空 → 隐藏）；公会庆典榜仍走 `ApplySelf`（这行填的是昵称）；循环复用行的残留旗由 `UpdateCountryFlag(data==nil)`/`HideRowCountryFlag` 收（`ea1d25fec`）。
- 🔴 测试陷阱：`test_country_rank` 里 `SetPlayerCountry` 会写 `PlayerManager.country`，而 `GetPlayerCountry()` **优先服务端值** ⇒ 分段断言前必须 `PlayerManager.country = nil`，否则「本国榜/我的国家」错位（`72e892c4c`）。
- 已挂：通用/竞技排行 ItemPre·Record·前三名、公会战力榜 ItemPre·Record·前三名（会长 `country`，服务端 `GuildForceRank`/`GuildSheJiScoreRank` 已下发）、玩家信息、设置页、竞技场 enemy_1..3、聊天气泡（三处 `content/chat` 模板，后两者是独立副本；老消息走 `ChatManager.PlayerCountryCache`）。

## 区服/语言（→ REF-server-ops）
- 列表动态（`server_info`→登录服 HTTP）：新增区服只插记录，`channel=pc/plat=android/sub_channel=1` 要对齐。🔴 `tk/getServerList` 的 server_version 传真版本 `1.26001`（传 `0` → 空列表）。隐藏区服只能服务端不下发（`add-shard-10002.sh`）。
- 🔴 lanid=floor(id/100)%100：10001 中文CNY / 10101 英文USD / 10002 中文USD / 10201 日文 / 10301 韩文；真机首启用设备语言覆盖（`GameSettings.cs:110-114`）。
- 🔴 本地服性能基线（2026-10-19 两批已落地，别改回去）：`threadNum=8`、`redis.timeout=2000`、`mongo maxConnectionIdleTime=60000`、`run-gs.sh` 的 `MaxMetaspaceSize=256m`（**堆别动**）；日志稳态 13 行/分钟（原 44MB/天双写）。netty 通道选项必须 `childOption`。`timeLimitMap` 504 条**不可删**（446 条带 refreshTime，重建函数是死代码）。细节 → REF-local-server「性能基线」。

## UI 布局 / Unity 桥（→ docs/unity_mcp_control.md）
- 🔴 `StdioBridgeHost` 127.0.0.1:6400（未配 mcp），`.workbuddy/tools/unity_bridge.py` 直连；新连接踢旧；端口没监听＝没起来；探测端口不能先开试探连接再关。`execute_code` 结尾必须 `return <expr>;`；UI 实拍开临时 additive 场景。
- 🔴 `CanvasScalerAdapter` 宽高比<16:9 时 match=0 ⇒ 画布宽恒 1080、高随屏；网格用 `(0.5,1)`+`-(row*H+H/2)`；图元跟不跟画布中心按需求定（`BattleUltCard` 在画面中部，`a0408226a`）——改位置前先问口径。
- 🔴 战场相机根高度唯一收口 `BattleManager.SetCameraRootY`：战斗 `-1.57`、挂机 `0`；`BattleScene.prefab` 的 `CameraRoot` 留 0。

## 发版/Jenkins/GM（→ REF-android-release、REF-jenkins-ci、docs/gm_fullserver_mail_skill.md）
- 🔴🔴 versionCode 只增不减、同号只能上一次：**10-19 仓内 ProjectSettings=74（1.2.51），最近产物 `apks/2026-10-17/CLIBuild/1.2.51_vc74_232358.apk`，下一个 ≥75**（`scripts/bump_version.py`）；失败别重跑 `aab_release.sh` ⇒ `--skip-build`/`play_upload.py`。
- 🔴 送审闸门：默认不上传；默认 internal（⇒completed），`--status draft` 是 production 不送审的唯一姿势。16KB 以包内产物为准（`verify_aab_native_16kb.py`，Unity 报 `libtolua.so` 是误报）。
- 🔴 GM 唯一通道＝服务端 thrift `idipGm`（`127.0.0.1:7916`，`scripts/gm_client.py`）；`sendmailall` 首 token 被丢弃、`resultCode=0`≠成功 ⇒ 查 `systemMailMap`+`itemLog reason=16`；文案默认英文、有效期 30 天。
- 🔴 服务端发正式服＝Jenkins `TS-Server-Release`（`.jenkins/lib/server_release.{sh,py}`，`4097b8c32`）：**基线是线上 jar + 逐条目 CRC + `zip -u`**，绝不用 `package.sh` 全量包（会回退线上未上线改动）；`META-INF/*.properties/*.xml` 永不注入；**打包成功就 `git push --atomic` 推分支+tag（演练也推，`PUSH_BRANCH=false` 可关）**；**`DEPLOY=true` 首次需授权**。→ REF-jenkins-ci

## 配置表 / 本地服（→ REF-config-tables、REF-local-server）
- 🔴 真源 `data_execl/base_data/*.xlsx`；改后同步 `DataConfigMD5Record.asset` CRC32 + 客户端 lua + LuaBytes + 服务端 `conf/server/*.txt`；多数改动必须 restart。
- 🔴 **要新增表行/列，别手改 packed lua**（`__indexs`+`__values` 是 LZ 压缩）：走 Unity 侧官方导表器——bridge 里 `DataHelper.GetSheet(path)` + `new DataToOptimizeLuaExporter(sheet, new DataConfigSetting()).Export()`，只写 `~Lua/Config/Data` 不碰服务端 conf；改前先用「未改动表重跑一次、输出与原文件字节相同」自证（2026-10-19 已验证 Language 17619 行字节一致）。
- 🔴 配置语义验证别读 lua 表本身：`GameDataBase.SheetBase.Init` 是纯 Lua，可在 luajit 里 dofile 后 `GetKeys(t)`/`t[id]`；Language 字段是 `id/Chinese/English/Japanese`，AfkSpeak 的 `AfkDialogue` 是 string（查语言表要 tonumber）。
- 本地服：launchd `com.ts.localserver.*`、`~/home/java/start-local.sh`；🔴 agent shell 里 `launchctl bootstrap` 恒 EIO 5 ⇒ `install` 必须用户 Terminal 跑。客户端连本地改 `AssetBundles/version.txt`（跟踪文件勿提交），测试号 `localtest/123456`、`10000004`(cn)/`10000005`(it)。

## 内购 / IAP
- 🔴 购买入口唯一收口 `Assets/Scripts/IAP/IAPManager.cs`（`BuyItem1`/`BuyItem`）：单飞锁（120s 兜底）+ 全套空判 + `IDetailedStoreListener`；Lua 侧 `PayManager.Pay` 只调 `iapMgr:BuyItem1`。
- 🔴 `ProcessPurchase` 分「本次在途（pid 匹配）」与「Google 重投历史单」：后者落盘 `PlayerPrefs["iap_pending_purchases_v1"]`（`\u001E`/`\u001F` 分隔）再 `Complete`，用 `TakePendingPurchases()` 取补发（格式 `productId#transactionId#receipt`）。真正的补发必须等服务端按 receipt 幂等校验，客户端直接发 `RequestBuyGiftGoods` 会重复发。
- 🔴 `ProxyBillingActivity getIntentSender() NPE` 是 Google 侧缺陷（billing 9.0.0/9.1.0 同款），升级无效、app 侧改不了 ⇒ 只做 Crashlytics 静音，勿重复排查。

## 🔴 约定（红线）
- 巡检默认只读、报告量化证据分级；发版/上线先取得明确同意（打包/校验/commit/push 可自行做；送审、重启生产服必须问）。
- 改动逐条 commit **且必须 push**；中文 `type(scope): 摘要`；严禁 `git add -A`；Lua 源码+LuaBytes 成对。
- 两个仓库都要管（`release` + `x1-tag-1.2.2`），判「都推了」= 两边 `rev-list --count origin/<branch>..<branch>` 为 0；push 前看有没有混进并行会话的提交。
- 凭据一律 `.secrets/`（700/600）；远端 PUBLIC、4 个 keystore 在库（决定不处置）。
- 后台长任务不能 `nohup &`/`disown` ⇒ `Popen(..., start_new_session=True, DEVNULL)`；shell 坑：`pipefail` 下 `| head` 造 SIGPIPE 假失败、BSD `find` 无 `-newermt`/`timeout`、沙箱 `ps` 不可用（`pgrep -fl`）、`grep` 不认 `\|`（用 `-E`）。
- 改系统级状态必须当场验证并标注重启后是否有效；`BattlePanel.prefab` 工作区副本会被 Unity 重写成 13.8 万行 ⇒ 打补丁先 `git show HEAD:path`。

## 诱导评分（→ daily log 2026-10-19）
- 底层＝`Assets/Scripts/Review/ReviewMgr.cs`（Google Play 内评价），Lua 唯一入口 `ReviewMgr:AllInOneFlowClick()`；`BattleBestPopup` 那套 PassTimes1 计数不要动。
- 🔴 新入口唯一闸门 `AppReview_TryShowOnKeyLevel(key)`（`Common/functions.lua` 末尾）：同 key 只弹一次 + 24h 冷却（取 `PlayerManager.serverTime`）+ 账号 3 次，计数 `AppReview_<uid>_*`。
- 口径：爬塔＝`VirtualTargetReward.Condition` 里程碑层（领奖在 `ClimbTowerRewardPopup`，`ClimbTowerPanel` 本身没有领奖动作）；日常副本＝该 Type `Id` 最大的末关**首通**，判首通必须在 `AddDailyChallengeInfo` 之前。
