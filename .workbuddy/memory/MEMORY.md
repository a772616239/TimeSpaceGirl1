# TimeSpaceGirl1 长期记忆（索引型·红线）

> 细节在同目录 `REF-*.md`（server-ops / local-server / android-release / config-tables / server-name-i18n / jenkins-ci）与当日 `YYYY-MM-DD.md`。本文件只留「不知道就会踩坑」的红线。

## 环境
- Unity `6000.6.5f1`：`ProjectVersion.txt` 必须国际版号；batchmode 显式 `-buildTarget Android`；Unity 6 就地改写源目录（追加 serializedVersion）属正常噪声。
- 客户端仓 `a772616239/TimeSpaceGirl1`（PUBLIC，~3.3GB）；服务端在 `TimeSpaceServer/Server_x1tag1.2.2/`（独立 repo，分支 `x1-tag-1.2.2`），**有并行会话自动 commit ⇒ 提交必须显式列路径**。
- SSH `gs` 129.226.213.65（CentOS7，内网 10.3.0.15，`.secrets/tencent-gameserver.pem`）；2vCPU/3.6GB 榨干，不能再起第二个 gameserver。`/home/java/{gameserver,loginserver,chatserver,xxljob}`，重启 `RESTART-GAMESERVER.sh`；Mongo 串必须含 `authSource=admin`；编译用 `sh gradlew`。
- 日志保留：`/data/srvlog/` 仅 ~3 天；**`assets/log/jl_item|jl_logs|jl_blogs` 保留 ≥30 天**，事后审计只能走这里。

## 🔴 protobuf 2.5.0
- 运行时 2.5.0；protoc 33 生成的 `GeneratedMessageV3` 编不过 ⇒ 按 HEAD proto 生成并与在库 `CommonProto.java` 逐字节 diff。
- `protocols.*` 在 `lib/gamecommon-1.0.0-SNAPSHOT.jar`（主 jar 靠 MANIFEST Class-Path 引 47 lib）⇒ 换协议两 jar 同动，否则 `NoSuchMethodError` 卡登录；重建会丢 `util/SysUtil.class` 补丁 ⇒ `zip -u` 只注差异类（先 touch）。
- 客户端 `~Lua/Message/*_pb.lua` 手补字段后重编 LuaBytes。已加 country：Player=25、UserRank=17、TeamOneInfo=21、ArenaPersonInfo=16、ChatInfo=28。

## 🔴 Lua / LuaBytes
- 真机跑 `LuaBytes/<路径下划线化>_64.bytes` ⇒ **源码+字节码成对提交**；`scripts/lua-bytes-sync.sh`（`--check`），不加 `-g`。
- LuaJIT 必须与编码器同版本；`libtolua.so` 出自 `topameng/tolua_runtime` 2.1.0-beta3，重编走 `scripts/libtolua16k/`；`require` 名＝`module()` 名。
- 长跑协程必须 OnClose+OnDestroy 双停（`DestroyPanel` 不走 OnClose）；代次 token+先停后起；样例 `FirstRechargePanel:StartHeroLoop`。
- 面板被 `openedList` 缓存复用（`noDestory=false` ⇒ Close 只 SetActive(false)）；OnClose 清 lua 表 ≠ 清克隆节点 ⇒ 动态子节点 Build 前按名清一次；`#map` 对字符串键恒 0。
- 🔴 tolua fake-null：GameObject Destroy 后 lua userdata 仍非 nil ⇒ `if not obj` 无效，判活只能 `IsNull()`/`tolua.isnull`（已三次崩溃）。销毁判据＝`UIConfig.noDestory==0`；为 0 时 Close 走 `DelayDestroyPanel`（15s×openNum）⇒ 异步回调有「已销毁」窗口。异步写 UI 一律「判活+pcall+OnDestroy 清引用」。
- `Timer.New` 第 4 参缺省受战斗倍速影响，UI 停留传 `true`；同一元素隐藏定时器先 Stop 再 New。
- 🔴 红点绑定是**面板级**全局表 `BindObjs[rpType]`：把「先 Clear 再 Bind」当幂等写法用之前，必须确认被调方本身幂等——`RedpotManager.ClearObject` 早期只判 `rpObj`、不判 `BindObjs[rpType]`，首次进页签 / `Initialize` 重置后必 `pairs(nil)` 崩（`c7575f8c3` 收口：Clear 判空 return、Bind 去重 + 跳 tolua fake-null）。
- 🔴 UI 动画：复刻别人的动画走 `docs/ui_anim_reproduce_skill.md`（S0 反解→S1 定阵营→S2 落地→三层验收）；
  浮空/呼吸配方与 11 坑在 `ui_panel_float_anim_skill.md`。两条铁律：读参考 clip 要遍历**所有** `m_*Curves`
  （`sizeDelta`/`anchoredPosition`/`color.a` 都在 `m_FloatCurves`）；DOTween 与节点自带 `CommonButton` Animator
  抢同一通道时必须临时 `enabled=false`（Animator 在 Update 之后求值）。
  已落地：`ExpertPanel`、`OperatingPanel`（两者都是纯 Lua 开启动画，prefab 未改）；页签顺序一律取
  `tabsContent` 的**子节点顺序**（OperatingPanel 的 `tabs_N` 在 prefab 里是乱序 12,5,11,1…）。

## 挂机气泡 / UI 布局 / IAP / 诱导评分
- 细节已拆到 `REF-client-misc.md`（气泡 280×78 两行上限、CanvasScaler match=0、IAP 入口收口、AppReview 闸门）。

## 美术资源换节日风格（→ **skill `.workbuddy/skills/art-restyle/SKILL.md`**、docs/art_restyle_pipeline.md、Jenkins `TS-Art-Restyle`）
- 🔴 边框类改动**必须按真机显示宽验**（1080 资源进游戏只有 567px，1:1 看清的线缩完全是 1px）：
  `python3 scripts/image/preview_ingame.py old.png new.png --cards 2x4`（贴回面板底+叠卡占位）、
  `--zoom 3` 看切角/亮边毛刺。给用户看必须配「改前」，且**改前文件不能按文件名猜**（备份存的是被替换掉的上一版）。
- 🔴 **provider 默认 `chatgpt_web`**（用本机 Chrome 登录态走订阅额度，不读 API key）。坑：cookie 导出再
  `addCookies` 重建**无效**（Chrome 155 的 `session-token.0/.1` 分片不被认）⇒ 必须整份 profile 交 Chrome 自解密；
  Chrome 要 `--no-sandbox --disable-gpu`；生成图是 **blob + alt「已生成图像 N」**（上传图 alt「用户附件」），
  只能靠 alt 认、同源 fetch 取；driver 连 localhost 必须 `NO_PROXY`；`playwright-core` 是 CJS 取 `.default`。
  出口侧封 OpenAI 时直连 403/超时、`cdn.oaistatic.com` 却通（别被误导），rc=3 标黄不阻断。
- 🔴 提示词**不许写死文案**（初版写死 8-DAY，换图就串文案）；文案由 `LAYOUT` 构图锁「逐字保持、只改材质」，主题预设只描述风格。
- 🔴 超长条底板（856×2048）**不能整幅 cover**（横切 37%）：走 `HERO_BAND`（量到点阵带底边，如 930）+ `BODY_MODE=source`（半截卡体按原资源明暗结构重上色，几何逐像素对齐）。带的高度必须量（`row_std` 掉到 25 以下即纯渐变区），猜必废图。
- 🔴 接缝**绝不能把最后一行往下广播**（那就是角色身体，会变竖光条）；要渐隐就原位逐行混合。
- 🔴 `WRITE_BACK=true` = 验收闸门 → 原图搬出工程到 `ResBackpack/备份/<资源相对路径>`（gitignore）→ 校验哈希 → 覆盖 → `_manifest.jsonl` 记台账；回滚 `restyle_pipeline.py restore --asset …`。`.meta` 永不改动（曾出现 guid 被换：`3b0b0d5e`→`042a30ad`，Unity 引用全断）。
- 🔴 写回 ≠ 进包，必须重打该资源所在 AssetBundle。
- 🔴 卡框（`--frame card`）**最外圈必须有亮边**（`--frame-rim warm|ivory|violet`，默认暖金）：面板底 `(17,17,25)` 与墨带 `(18,16,24)` 同亮度，只画墨带在黑底上等于没框（用户原话「遇到黑色的时候不明显」）。这是游戏道具槽自己的剖面（`tongyong_daojukuang_01/04/05`：暗带 3px + 亮边 5px），判据＝亮边与底的亮度差 ≥100。
- 🔴 框线**不能用 `ImageDraw.line(width=…)`**：以路径为中线、round join 把 45° 切角磨圆，相邻两条线还会互相盖住（亮边只剩半宽）⇒ 用多边形掩膜 `_ring_paste`。内细线默认关（`--frame-hairline` 才开），否则是相框式双线。

## 国家旗帜（→ docs/CountryFlag_FeatureDesign.md）
- 🔴 250 国（ISO 3166-1）、旗 132×88：新增 png 必须补 `.meta`（textureType 8/spriteMode 1/spritePackingTag）+ `ResourcePathConfig.asset` 登记，否则 `Util.LoadSprite` 空白。
- 🔴 服务端下发收口 `AbstractRank.getOneUserRank` 的 `.setCountry(...)`；**关卡榜例外**：`getRank` 同分重排重建 `UserRank` 是逐字段复制，改行字段必须同步这段。
- 🔴 改旗收口 `CountryRankManager.SetPlayerCountry`→`OnCountryChanged`+`RefreshSelfFlags()`；前三名只在 `SetHeadFlag` 写；「我的排名」走 `RefreshMyRankFlag`（空榜→未上榜→分会榜，Unranked 必须隐藏；公会战力榜取会长国籍）。
- 🔴 测试陷阱：`GetPlayerCountry()` 优先服务端值 ⇒ 断言前先 `PlayerManager.country = nil`。
- 🔴 「没旗」= 库没数据（209 号曾仅 44 有 country），无 country 画问号。10-20 已落地运行时 IP→国家（`9ed2c1f3`）：唯一入口 `PlayerCountryBootstrap.onLogin`（`LoginRequestHandler` 调一次）→ 取 `InetSocketAddress` 对端 IP（**别用** `NettyGameSession.getIp()`，`substring(1,len-6)` 遇 4 位端口截坏）→ `setIp` → country 空时查离线表 `server_game/conf/ipcountry.dat`（380k 条 12B/条，`tools/gen_ipcountry_table.py` 生成，零第三方 jar）。机房/VPN（IKUUU ASN 134972）与无证据 ⇒ 随机国籍（池＝客户端 249 国，主要市场 3 倍权重，`COMMON_RAW` 与脚本 `COMMON_CODES` 必须一致）。
- 🔴 离线表**必须带 endIp**（空隙不建记录；只用 start 当上界会把空隙 IP 判成前一条，实测 `127.0.0.1→jp`）。IP 串归一化顺序＝剥 `/` → `::ffff:` → 最后 `:port`。`countrySource`：0 老/1 手选/2 IP/3 随机，手选永不覆盖、随机遇可信 IP 升级。
- 🔴 榜单读 `UserManager.getUser(uid,true)` 实时 ⇒ **改库立即生效**（不用重启）；setter 走 `updateString`+`SimpleTransaction.commit` 刷盘，无需显式 save。

## 区服/语言（→ REF-server-ops）
- 列表动态（`server_info`→登录服 HTTP）：新区服只插记录，`channel=pc/plat=android/sub_channel=1` 要对齐；`tk/getServerList` 的 server_version 传真版本 `1.26001`（传 0 ⇒ 空列表）；隐藏区服只能服务端不下发。
- 🔴 lanid=floor(id/100)%100：10001 中文CNY / 10101 英文USD / 10002 中文USD / 10201 日文 / 10301 韩文；真机首启用设备语言覆盖（`GameSettings.cs:110-114`）。
- 🔴 本地服性能基线（10-19 已落地，别改回去）：`threadNum=8`、`redis.timeout=2000`、`mongo maxConnectionIdleTime=60000`、`run-gs.sh` 的 `MaxMetaspaceSize=256m`（堆别动）；`timeLimitMap` 504 条不可删；netty 通道选项必须 `childOption`。

## 发版/Jenkins/GM（→ REF-android-release、REF-jenkins-ci）
- 🔴🔴 versionCode 只增不减、同号只能上一次：10-19 仓内 74（1.2.51），下一个 ≥75（`scripts/bump_version.py`）；失败别重跑 `aab_release.sh` ⇒ `--skip-build`/`play_upload.py`。
- 🔴 送审闸门：默认不上传；默认 internal（⇒completed），`--status draft` 是 production 不送审的唯一姿势；16KB 以包内产物为准（`verify_aab_native_16kb.py`）。
- 🔴 GM 唯一通道＝服务端 thrift `idipGm`（`127.0.0.1:7916`，`scripts/gm_client.py`）；`sendmailall` 首 token 被丢弃、`resultCode=0`≠成功 ⇒ 查 `systemMailMap`+`itemLog reason=16`；文案默认英文、有效期 30 天。
- 🔴 **正式服 `server.debug` 必须 false**：`GMRequestHandler` 绑公网协议 `GM_REQUEST`(10606)，唯一闸门 `isDebug()`；10-10 事故就是 jar 内置 true（→ docs/cheat_incident_*）。只改 `config/application.properties`（`logicSrv.properties` 是死文件），必须用 `ServerProperties ->` 运行时日志验证。
- 🔴 服务端发正式服＝Jenkins `TS-Server-Release`（`.jenkins/lib/server_release.{sh,py}`）：基线是线上 jar + 逐条目 CRC + `zip -u`，绝不用 `package.sh` 全量包；`META-INF/*.properties/*.xml` 永不注入；打包成功就 `git push --atomic`。
- 🔴 Jenkins 凭据 `~/.jenkins/.qclaw-creds`（600）；`curl` 调 API 必须 `-sg`；审批放行 `POST /job/<job>/<n>/input/<32hex>/submit`，`proceed=<按钮文案>` 且必须带 `json={}`。
- 🔴 注入前风险分类：对 changed 类做「常量池可打印串差集」，分清「线上只是旧版」与「线上有本地未有的热补丁」；`zip -u` 只加不删。job 复用 `server_game/.gradle_home` ⇒ 留 30 个未跟踪 `scripts-remapped/`（`.gitignore` 已收，改按字节追加）。

## 🔴 榜单 / 作弊处置（→ docs/cheat_detection_skill.md、scripts/cheat/）
- `RankFirstHandler`(11756) → `RankLogic.getRankFirstInfo` **遍历全部 rankTypes**，任一榜 `getFirst` 抛错 ⇒ 整包响应失败 ⇒ **排行榜打不开**。
- 🔴 `HeroForceRank.getFirst/getOptional` 原直接 `getHero(heroId).getTemplateId()`（无判空）；`AbstractRank.getOneUserRank` 有判空，所以**只有英雄战力榜会崩**。代码已判空（`54d36e83`，未发版）。
- 🔴 崩榜根因＝**删号只删 `user`，没清 `HERO_FORCE_RANK` 的 `uid:heroId` 复合成员**；旧 `Purger.run` 的 `--account` 分支 `what=[]` ⇒ 完全没调 `clean_ranks`。已修为「clean_ranks→clean_mongo_refs→delete_account」+ 结尾自动体检（`06b47bde6`）。
- 🔴 删号可逆一半：`/root/incident_*` 有 `mongoexport` 快照 ⇒ 回灌 `db.user` 即整档复活（10-20 已实操 10000013）。
  三坑：`{"$date":{"$numberLong":..}}` 要还原成 `new Date(-28800000)`；`guildInfo` 只抽 members 不减 `totalMembers`；
  该 uid 的 `itemLog/heroLog/fightLog/storeLog` 是物理删，事后无流水可查。`FORCE_CURR_RANK` 注 `maxForce` 即可，
  `MAIN_LEVEL_RANK`=`virtureId+force/1e8`、`HERO_FORCE_RANK`=英雄单体战力，靠 `addRank` 自愈。
- 🔴 排行榜打不开先跑 `python3 scripts/cheatctl.py rank-audit [--repair]`（应为 0 条失效）。判据＝成员 uid 不在 `user`（user_gone）/ heroId 不在 heroMap（hero_gone）；**只对 `^1\d{7}$` 处理，公会榜 guildId 不能碰**。
- 🔴 好友残留引用（删号没清 `friendManager`）⇒ 引用方登录 `GET_FRIEND_INFO` 撞 `getUser null`，卡进度 45%：
  体检 `cheatctl.py refs-audit [--repair]`（默认只读）；字段含 `friends/blackFriends/applyFriends/myApplyFriends/giveMap/haveRewardMap`，
  手扫最容易漏 `myApplyFriends`。`Purger` 已有 `clean_player_refs`，顺序 `clean_ranks→clean_player_refs→clean_mongo_refs→delete_account`。
- 🔴 删英雄必须同步 `heroForceSort` 置空（`refreshHeroForceSort` 结果为空时不回写）；`maxForce` 是当前阵容战力（`PlayerLogic:369`），删英雄别重算。`itemLog` 会整段断档（10000221–225 全 0），真账本是 BI 文件流水 `reason=28 = GM_REWARD`。`cheat_scan.py` 对 GM 改英雄是**假阴性**。
- 活体风险：改包客户端仍在发 `GM_REQUEST`（`10#1#0` TIME_INFO 探测），说明洞在外面流通；`GM_LOGIN_BY_UID=40` 可顶号。

## 配置表 / 本地服（→ REF-config-tables、REF-local-server）
- 🔴 真源 `data_execl/base_data/*.xlsx`；改后同步 `DataConfigMD5Record.asset` CRC32 + 客户端 lua + LuaBytes + 服务端 `conf/server/*.txt`；多数改动必须 restart。
- 🔴 新增表行/列别手改 packed lua（`__indexs`+`__values` 是 LZ 压缩）：走 `DataHelper.GetSheet(path)` + `new DataToOptimizeLuaExporter(sheet, new DataConfigSetting()).Export()`，只写 `~Lua/Config/Data`；改前用「未改动表重跑输出字节相同」自证。
- 🔴 配置语义验证别读 lua 表：luajit 里 dofile 后 `GetKeys(t)`/`t[id]`；Language 字段 `id/Chinese/English/Japanese`，AfkDialogue 是 string。
- 本地服：launchd `com.ts.localserver.*`、`~/home/java/start-local.sh`；agent shell 里 `launchctl bootstrap` 恒 EIO 5 ⇒ install 必须用户 Terminal 跑；客户端连本地改 `AssetBundles/version.txt`（勿提交）；测试号 `localtest/123456`、`10000004`(cn)/`10000005`(it)。

## 🔴 约定
- 巡检默认只读、量化证据分级；发版/上线先取得明确同意（打包/校验/commit/push 可自行做；送审、重启生产服必须问）。
- 改动逐条 commit 且必须 push；中文 `type(scope): 摘要`；严禁 `git add -A`；Lua 源码+LuaBytes 成对。
- 两仓都管，「都推了」= 两边 `rev-list --count origin/<branch>..<branch>` 为 0；push 前看有没有混进并行会话的提交。
- 凭据一律 `.secrets/`（700/600）；远端 PUBLIC、4 个 keystore 在库（决定不处置）。
- 后台长任务不能 `nohup &`/`disown` ⇒ `Popen(..., start_new_session=True, DEVNULL)`；shell 坑：`pipefail`+`|head` 假失败、BSD `find` 无 `-newermt`/`timeout`、沙箱 `ps` 不可用（用 `pgrep -fl`）、`grep` 不认 `\|`（用 `-E`）、源码常为 GBK 需 `grep -a`。
- 改系统级状态必须当场验证并标注重启后是否有效；`BattlePanel.prefab` 工作区副本会被 Unity 重写成 13.8 万行 ⇒ 打补丁先 `git show HEAD:path`。

## 🔴 登录加载链（卡百分比必看）
- **现已 20 格**（f79243431 并行分组后）：15 个串行步 + 4 个并行分组 + 1 个末步，`maxValue=19`；
  百分比＝`int(curIndex/19*100)`，**已经没有 45% 这一格**（8→42%、9→47%）。
  分组前的旧口径：43 步 / `maxValue=42` / 45%=第 19 步好友聊天（对照历史日志时用）。
  改 `LoginPanel.ExecuteLoading` 增删步骤会让所有"卡 x%"口径平移。
- `ExecuteLoading` 现在是 `addStep(name, fire)` / `addGroup(name, {member(name, fire)})` 的 DSL。
  **加分组必须满足三条**（写在函数头）：组内无数据依赖；**回包协议号互不相同**
  （C# `callbacks` 以回包 msgId 为 key，同号并发会让后注册的回调被丢弃 ⇒ 该成员永不回调，
  这也是 `RequestGetFriendInfo(1)/(3)` 只能串行的原因）；只放纯展示数据。
  已知会内部再发一次的：`GetActivityAllRewardRequest`（→BoxPoolList）、`GetWorldArenaInfoRequest`
  （UNLOCK→取数据）——靠 `parallelBatch` 粘性标志，回调里再发的请求也走并发通道。
- 并发通道：`Network.parallelBatch>0` ⇒ `SendMessageWithCallBack` 转 `SendParallelMessage`
  （不进 `sendFuncQueue`、不动 `sendFlag`、不重发）；批次内报错只算该成员失败
  （`LoadingPanel.GroupMemberFailed`），**不能**推进整条链。
- 链只靠回调推进 ⇒ 任一回调不来/抛错就永久停住，且 `Network.sendFlag` 卡死会把后续请求全堵在队列里，
  但心跳照走（日志上看着"连接正常"）。已加 8s/格看门狗（分组按"最慢成员"计时）+ `Network:AbortPending`。
- 服务端 `ProtocolsManager.addEntry` 按 `userId % HANDLER_THREAD_NUM` 路由 ⇒ 同一玩家的包始终同一个
  `HandlerLogicThread` 串行按序处理，所以并发分组只折 RTT，不会引入服务端并发写。
- 反证别用 `grep msgId=>16637`：`MessageUtil.wrappedBuffer` 对聊天包是故意不打日志的。
- 每步耗时≈一个 RTT：国内号实测 102ms/步，欧洲号 288ms/步（Asia 服），整链 ~12s vs ~4.5s
  ⇒ 分组后理论 ~6s vs ~2s（待真机确认）。再想快只能继续减少串行跳数。
