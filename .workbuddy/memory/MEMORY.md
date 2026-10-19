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
- `Timer.New` 第 4 参缺省 ⇒ 受战斗倍速影响，UI 停留传 `true`；同一元素隐藏定时器先 Stop 再 New（`test_skill_bar_timer.lua`）。

## 国家旗帜（→ docs/CountryFlag_FeatureDesign.md）
- 🔴 国家表已补齐 **250 国（ISO 3166-1 全量）**、旗 132×88：新增 png 必须补 `.meta`（textureType 8/spriteMode 1/spritePackingTag）+ `ResourcePathConfig.asset` resInfoList 登记，否则 `Util.LoadSprite` 空白。工具 `gen_country_rank_*`/`sync_guoqi_resinfo.py --check`（应为「250 条一致」）。
- `CountryConfig.GetName` 回落链＝当前语言→**en**→zh→code（lan 0=中/1=英/2=日/3=韩）；日韩缺译名不得露简体中文。
- 🔴 改旗刷新唯一收口 `CountryRankManager.SetPlayerCountry`→`OnCountryChanged`+`RefreshSelfFlags()`；自己必须走 `Apply/ApplySelf`（弱键登记）；节点名 `countryFlag`；点击弹名 `MakeClickable`（`m_RaycastTarget`=1）。
- 🔴 前三名唯一写入点 `SetHeadFlag(index,data)`：缺名次→隐藏；公会榜按会长 country，无则隐藏。
- 🔴 「我的排名」行走 `RefreshMyRankFlag`：显示＝非公会榜 且 非空榜 且 名次≥1（`myRankValid`/`HasValidRank`），Unranked 必须隐藏；循环复用行的残留旗由 `UpdateCountryFlag(data==nil)`/`HideRowCountryFlag` 收（`ea1d25fec`）。
- 🔴 测试陷阱：`test_country_rank` 里 `SetPlayerCountry` 会写 `PlayerManager.country`，而 `GetPlayerCountry()` **优先服务端值** ⇒ 分段断言前必须 `PlayerManager.country = nil`，否则「本国榜/我的国家」错位（`72e892c4c`）。
- 已挂：通用/竞技排行 ItemPre·Record·前三名、玩家信息、设置页、竞技场 enemy_1..3、聊天气泡（三处 `content/chat` 模板，后两者是独立副本；老消息走 `ChatManager.PlayerCountryCache`）。

## 区服/语言（→ REF-server-ops）
- 列表动态（`server_info`→登录服 HTTP）：新增区服只插记录，`channel=pc/plat=android/sub_channel=1` 要对齐。🔴 `tk/getServerList` 的 server_version 传真版本 `1.26001`（传 `0` → 空列表）。隐藏区服只能服务端不下发（`add-shard-10002.sh`）。
- 🔴 lanid=floor(id/100)%100：10001 中文CNY / 10101 英文USD / 10002 中文USD / 10201 日文 / 10301 韩文；真机首启用设备语言覆盖（`GameSettings.cs:110-114`）。

## UI 布局 / Unity 桥（→ docs/unity_mcp_control.md）
- 🔴 `StdioBridgeHost` 127.0.0.1:6400（未配 mcp），`.workbuddy/tools/unity_bridge.py` 直连；新连接踢旧；端口没监听＝没起来；探测端口不能先开试探连接再关。`execute_code` 结尾必须 `return <expr>;`；UI 实拍开临时 additive 场景。
- 🔴 `CanvasScalerAdapter` 宽高比<16:9 时 match=0 ⇒ 画布宽恒 1080、高随屏；网格用 `(0.5,1)`+`-(row*H+H/2)`；图元跟不跟画布中心按需求定（`BattleUltCard` 在画面中部，`a0408226a`）——改位置前先问口径。
- 🔴 战场相机根高度唯一收口 `BattleManager.SetCameraRootY`：战斗 `-1.57`、挂机 `0`；`BattleScene.prefab` 的 `CameraRoot` 留 0。

## 发版/Jenkins/GM（→ REF-android-release、REF-jenkins-ci、docs/gm_fullserver_mail_skill.md）
- 🔴🔴 versionCode 只增不减、同号只能上一次：当前 **69**，下一个 ≥70（`scripts/bump_version.py`）；失败别重跑 `aab_release.sh` ⇒ `--skip-build`/`play_upload.py`。
- 🔴 送审闸门：默认不上传；默认 internal（⇒completed），`--status draft` 是 production 不送审的唯一姿势。16KB 以包内产物为准（`verify_aab_native_16kb.py`，Unity 报 `libtolua.so` 是误报）。
- 🔴 GM 唯一通道＝服务端 thrift `idipGm`（`127.0.0.1:7916`，`scripts/gm_client.py`）；`sendmailall` 首 token 被丢弃、`resultCode=0`≠成功 ⇒ 查 `systemMailMap`+`itemLog reason=16`；文案默认英文、有效期 30 天。

## 配置表 / 本地服（→ REF-config-tables、REF-local-server）
- 🔴 真源 `data_execl/base_data/*.xlsx`；改后同步 `DataConfigMD5Record.asset` CRC32 + 客户端 lua + LuaBytes + 服务端 `conf/server/*.txt`；多数改动必须 restart。
- 本地服：launchd `com.ts.localserver.*`、`~/home/java/start-local.sh`；🔴 agent shell 里 `launchctl bootstrap` 恒 EIO 5 ⇒ `install` 必须用户 Terminal 跑。客户端连本地改 `AssetBundles/version.txt`（跟踪文件勿提交），测试号 `localtest/123456`、`10000004`(cn)/`10000005`(it)。

## 🔴 约定（红线）
- 巡检默认只读、报告量化证据分级；发版/上线先取得明确同意（打包/校验/commit/push 可自行做；送审、重启生产服必须问）。
- 改动逐条 commit **且必须 push**；中文 `type(scope): 摘要`；严禁 `git add -A`；Lua 源码+LuaBytes 成对。
- 两个仓库都要管（`release` + `x1-tag-1.2.2`），判「都推了」= 两边 `rev-list --count origin/<branch>..<branch>` 为 0；push 前看有没有混进并行会话的提交。
- 凭据一律 `.secrets/`（700/600）；远端 PUBLIC、4 个 keystore 在库（决定不处置）。
- 后台长任务不能 `nohup &`/`disown` ⇒ `Popen(..., start_new_session=True, DEVNULL)`；shell 坑：`pipefail` 下 `| head` 造 SIGPIPE 假失败、BSD `find` 无 `-newermt`/`timeout`、沙箱 `ps` 不可用（`pgrep -fl`）、`grep` 不认 `\|`（用 `-E`）。
- 改系统级状态必须当场验证并标注重启后是否有效；`BattlePanel.prefab` 工作区副本会被 Unity 重写成 13.8 万行 ⇒ 打补丁先 `git show HEAD:path`。
