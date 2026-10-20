# TimeSpaceGirl1 长期记忆（索引型·红线）

> 细节全在同目录 `REF-*.md` 与当日 `YYYY-MM-DD.md`。本文件只留「不知道就会踩坑」的红线（≤3k 字符）。

## 索引
- `REF-client-ui.md`：Lua/LuaBytes、UI 动画、**登录加载链**、**主动弹窗队列 PopupQueue**
- `REF-game-domain.md`：货币/道具 id、protobuf 2.5.0、国家旗帜、区服与语言
- `REF-ops-redlines.md`：发版/Jenkins/GM、榜单与作弊处置、配置表、本地服
- `REF-art-restyle.md`：美术换皮（配合 skill `art-restyle`）
- 其它：`REF-server-ops`、`REF-local-server`、`REF-android-release`、`REF-jenkins-ci`、`REF-config-tables`、`REF-shard10002`、`REF-client-misc`、`REF-server-name-i18n`

## 环境
- Unity `6000.6.5f1`：`ProjectVersion.txt` 必须国际版号；batchmode 显式 `-buildTarget Android`。
- 客户端仓 `a772616239/TimeSpaceGirl1`（PUBLIC，~3.3GB）；服务端 `TimeSpaceServer/Server_x1tag1.2.2/`（独立 repo，分支 `x1-tag-1.2.2`）。**有并行会话自动 commit ⇒ 提交必须显式列路径**。
- SSH `gs` 129.226.213.65（CentOS7，内网 10.3.0.15，`.secrets/tencent-gameserver.pem`）；2vCPU/3.6GB 已榨干，不能再起第二个 gameserver。Mongo 串必须含 `authSource=admin`；编译 `sh gradlew`。
- 日志 `/data/srvlog/` 仅 ~3 天，事故审计只能走 `assets/log/jl_item|jl_logs|jl_blogs`（≥30 天）。

## 🔴 通用红线（详情见对应 REF）
- 真机跑 `LuaBytes/<路径下划线化>_64.bytes` ⇒ **源码+字节码成对提交**（`scripts/lua-bytes-sync.sh`，不加 `-g`）。
- 货币 id：`16=钻石 3=英雄经验 14=金钱 17=经验 79=情报`（`detect.py` 曾把 3 当钻石 ⇒ 一批"钻石异常"全是假的）。id→名字一律走 `scripts/cheat/currency.py` 现算，**禁止写死**。
- 🔴 `item17` 语义未定：209 个号里 22 个 lv22-49 该值≈0 ⇒ 既不是稳定累计经验、也**绝不能当离群基线**（拿它比空壳号中位数会算出 62.8 万倍假离群）。
- 🔴 `reason=1`（挂机/探险）**永不产出钻石**；钻石只来自 `reason=2`（≈33 颗/次）、邮件、`reason=28`(GM_REWARD)。任何"刷钻石"结论先自证此条。
- `tolua` fake-null 只能 `IsNull()` 判活；红点 `BindObjs[rpType]` 不幂等；`Timer.New` 第 4 参 UI 传 `true`（三条各崩过一次）。
- 改配置表真源 `data_execl/base_data/*.xlsx`，改后同步 CRC32 + 客户端 lua + LuaBytes + 服务端 `conf/server/*.txt`；新增行列别手改 packed lua。
- 正式服 `server.debug` 必须 false（GM 走公网 `GM_REQUEST` 10606，唯一闸门 `isDebug()`）。
- versionCode 只增不减、同号只能上一次；送审默认不上传，`--status draft` 是 production 不送审的唯一姿势。
- 删号/删英雄必须清 rank 成员、`heroForceSort` 与玩家间引用（`cheatctl rank-audit` / `refs-audit`），否则崩榜、登录撞 `getUser null`。
- 🔴 **删号前必须先归档**（用户明令）：`cheatctl archive --uid` 导 user + `itemLog/heroLog/fightLog/storeLog` + 榜单 + 货币快照；`purge --account` 已把"四集合导出成功"当硬闸门。10000015/16 因只导 user 没导日志 ⇒ 永久失去判据。
- 弹窗队列：主动弹窗一律走 `PopupQueue.Push`，只有回到主界面（`BASE_SCREEN_NAMES`）才放行下一个，压着不丢。

## 约定
- 巡检默认只读、量化证据分级；打包/校验/commit/push 可自行做，**送审与重启生产服必须先问**。
- 逐条 commit 且必须 push；中文 `type(scope): 摘要`；严禁 `git add -A`。
- 两仓都管，「都推了」= 两边 `rev-list --count origin/<branch>..<branch>` 为 0；push 前看有没有混进并行会话的提交。
- 凭据一律 `.secrets/`（700/600）。
- 后台长任务 `Popen(..., start_new_session=True, DEVNULL)`，不能 `nohup &`/`disown`；zsh 下 `--include` 报 no matches（用 Grep 工具）、源码常 GBK 需 `grep -a`。
- 改系统级状态必须当场验证并标注重启后是否有效；`BattlePanel.prefab` 工作区副本会被 Unity 重写 ⇒ 打补丁先 `git show HEAD:path`。
