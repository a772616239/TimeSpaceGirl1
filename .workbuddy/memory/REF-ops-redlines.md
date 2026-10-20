# REF-ops-redlines —— 发版 / Jenkins / GM / 榜单作弊 / 配置表 / 本地服

> 从 `MEMORY.md` 迁出（2026-10-20），内容为原文。配套 REF-android-release、REF-jenkins-ci、REF-config-tables、REF-local-server、docs/cheat_detection_skill.md。

## 发版 / Jenkins / GM（→ REF-android-release、REF-jenkins-ci）
- 🔴🔴 versionCode 只增不减、同号只能上一次：10-19 仓内 74（1.2.51），下一个 ≥75（`scripts/bump_version.py`）；失败别重跑 `aab_release.sh` ⇒ `--skip-build`/`play_upload.py`。
- 🔴 送审闸门：默认不上传；默认 internal（⇒completed），`--status draft` 是 production 不送审唯一姿势；16KB 以包内产物为准。
- 🔴 GM 唯一通道＝服务端 thrift `idipGm`（`127.0.0.1:7916`，`scripts/gm_client.py`）；`sendmailall` 首 token 被丢弃、`resultCode=0`≠成功 ⇒ 查 `systemMailMap`+`itemLog reason=16`。
- 🔴 正式服 `server.debug` 必须 false：`GMRequestHandler` 绑公网 `GM_REQUEST`(10606)，唯一闸门 `isDebug()`（10-10 事故）。只改 `config/application.properties`，用 `ServerProperties ->` 运行时日志验证。
- 🔴 服务端发正式服＝Jenkins `TS-Server-Release`：基线是线上 jar + 逐条目 CRC + `zip -u`，绝不用 `package.sh`；`META-INF/*.properties/*.xml` 永不注入；成功即 `git push --atomic`。
- 🔴 本地测试服部署＝Jenkins `TS-Local-Deploy`（`dc28698fa`，`local_deploy.sh`）：只注入 CRC 变了的条目、**副本 `zip -u` + 原子 `mv`**（绝不在运行的 jar 上就地写）；`launchctl bootstrap` 在 Jenkins shell 恒 rc=5 ⇒ 全程不 bootout，托管中 `kickstart -k`、未托管用 `spawn_detached`；**拉起常驻进程必须从 env 摘掉 `HUDSON_COOKIE/JENKINS_SERVER_COOKIE/BUILD_*/WORKSPACE`**，否则构建结束被 ProcessTreeKiller 杀掉（自检全绿但进程已死）。
- 🔴 Jenkins 凭据 `~/.jenkins/.qclaw-creds`（600）；`curl` 用 `-sg`；放行 `POST /job/<job>/<n>/input/<32hex>/submit`，`proceed=<按钮文案>` 且带 `json={}`。
- 🔴 注入前对 changed 类做常量池可打印串差集，分清「线上只是旧版」与「线上有热补丁」；`zip -u` 只加不删。

## 榜单 / 作弊处置（→ docs/cheat_detection_skill.md、scripts/cheat/）
- `RankFirstHandler`(11756) 遍历全部 rankTypes，任一 `getFirst` 抛错 ⇒ 排行榜整包失败。`HeroForceRank` 原无判空（已修 `54d36e83`，未发版）⇒ 只有英雄战力榜会崩。
- 🔴 崩榜根因＝删号只删 `user`、没清 `HERO_FORCE_RANK` 的 `uid:heroId`；`Purger` 已修为 `clean_ranks→clean_player_refs→clean_mongo_refs→delete_account` + 结尾体检（`06b47bde6`）。
- 🔴🔴 **删号前必须先归档**（用户 10-20 明令）：`cheatctl.py archive --uid X` 导 `user` + `itemLog/heroLog/fightLog/storeLog` + 榜单 + 货币快照；`purge --account` 已把"四集合导出成功"当硬闸门（fail-closed）。反例：10000015/10000016 只导了 user 没导日志 ⇒ 连"当时有多少钻石"都答不出，永久失去判据。
- 🔴 删号可逆一半：`/root/incident_*` 有 `mongoexport` 快照 ⇒ 回灌 `db.user` 可复活（10-20 实操 10000013）。坑：`{"$date":...}` 还原 `new Date(-28800000)`；`guildInfo` 只抽 members 不减 `totalMembers`；该 uid 的 `itemLog/heroLog/fightLog/storeLog` 物理删，事后无流水。
- 🔴 排行榜打不开先 `python3 scripts/cheatctl.py rank-audit [--repair]`（应 0 条失效）；**只对 `^1\d{7}$` 处理，公会榜 guildId 不能碰**。
- 🔴 好友残留引用（删号没清 `friendManager`）⇒ 引用方登录撞 `getUser null`，登录链卡死：`cheatctl.py refs-audit [--repair]`；字段含 `friends/blackFriends/applyFriends/myApplyFriends/giveMap/haveRewardMap`（最易漏 `myApplyFriends`）。
- 🔴 删英雄必须同步 `heroForceSort` 置空；`maxForce` 是当前阵容战力，删英雄别重算。`itemLog` 会整段断档，真账本＝BI 流水；`cheat_scan.py` 对 GM 改英雄是假阴性。
- 活体风险：改包客户端仍发 `GM_REQUEST`（`10#1#0` TIME_INFO 探测）；`GM_LOGIN_BY_UID=40` 可顶号。

## 配置表 / 本地服（→ REF-config-tables、REF-local-server）
- 🔴 真源 `data_execl/base_data/*.xlsx`；改后同步 `DataConfigMD5Record.asset` CRC32 + 客户端 lua + LuaBytes + 服务端 `conf/server/*.txt`；多数改动必须 restart。
- 🔴 新增行/列别手改 packed lua（`__indexs`+`__values` 是 LZ）：走 `DataHelper.GetSheet` + `DataToOptimizeLuaExporter.Export()`，只写 `~Lua/Config/Data`；用「未改动表重跑字节相同」自证。
- 🔴 配置语义验证别读 lua 表：luajit 里 dofile 后 `GetKeys(t)`/`t[id]`（packed 表直接 `t[id]` 是 nil，需 GameDataBase 解码）；UI 表字段 `id/name/assetName/type/sortingOrder`，`type` 1全屏 2弹窗 3固定。
- 本地服：launchd `com.ts.localserver.*`、`~/home/java/start-local.sh`；agent shell 里 `launchctl bootstrap` 恒 EIO 5 ⇒ install 必须用户 Terminal 跑；客户端连本地改 `AssetBundles/version.txt`（勿提交）；测试号 `localtest/123456`、`10000004`(cn)/`10000005`(it)。
