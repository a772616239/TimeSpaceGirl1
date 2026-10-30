# TimeSpaceGirl1 长期记忆（索引·红线）

> 细节在同目录 `REF-*.md`（server-ops / local-server / shard10002 / android-release / config-tables / server-name-i18n / jenkins-ci / monetization / art-pipeline / art-restyle / art-translate / promo-shots / **aso-store** / client-ui / client-misc / ops-redlines / game-domain）与 `YYYY-MM-DD.md`。这里只留「不知道就会踩坑」的条目。
> 2026-10-30 瘦身：ASO 那一大段搬去 `REF-aso-store.md`（本文件曾超注入上限被截断）。

## 环境
- Unity `6000.6.5f1`（国际版号）；batchmode 显式 `-buildTarget Android`。
- 客户端 `a772616239/TimeSpaceGirl1`（PUBLIC，release）；服务端 `TimeSpaceServer/Server_x1tag1.2.2/`（repo `x1-tag-1.2.2`）。**并行会话会自动 commit ⇒ 提交必须显式列路径**。
- 登录服源码 `TimeSpaceServer/skzc/home/java/loginserver/src/`（属主仓）：`verify-recommend-patch.sh`、`deploy-login-server.sh check|deploy --confirm|rollback`。
- SSH `gs` 129.226.213.65（2vCPU/3.6GB 已榨干）；Mongo 串必须 `authSource=admin`；编译 `sh gradlew`；`/data/srvlog/` 仅 ~3 天，审计走 `assets/log/jl_item|jl_logs|jl_blogs`。
- Jenkins `127.0.0.1:8080`，凭据 `~/.jenkins/.qclaw-creds`（键是 `JENKINS_USER`/`JENKINS_TOKEN`，不是 U/P）。🔴 触发只认 `POST /job/<n>/buildWithParameters` + **表单字段**（`json={"parameter":[…]}` 能起构建但参数全取默认）；`/build` 一律 400。job 真源 `.jenkins/jobs/*.groovy` → `.jenkins/apply-jobs.sh`。

## 配置 / 服务端
- 配置表真源 `data_execl/base_data/*.xlsx`，改后同步 CRC32 + lua + LuaBytes + 服务端 `conf/server/*.txt`；备份禁放 `base_data/`。
- 货币 id `16=钻石 3=英雄经验 14=金钱 17=经验 79=情报`；名字走 `scripts/cheat/currency.py` 现算，禁写死。`item17` 语义未定（不能当离群基线）；`reason=1` 永不产出钻石。
- 正式服 `server.debug=false`；versionCode 只增不减、同号只能上一次；`--status draft` 是 production 不送审的唯一姿势。
- 🟢 **数值迭代优化 = Jenkins `TS-Numeric-Optimize`**（10-28 建，默认全程只读；引擎 `scripts/numeric_optimize.py`，文档 `docs/numeric_optimize_skill.md`）。四条别凭印象：**通胀是硬约束不是权重**（软权重会把「陡度+20% 换通胀+9%」判成优＝R7 那类错觉）；**跨轮累计上限 25% 且锚点粘住**（`state.json` 的 `anchor_rate` 只写一次，要重置只能人显式 `--reanchor`/勾 `REANCHOR`）；`best/` 必须按 `changes` **确定性重建**（草稿目录是所有候选共用的）；`TRIGGER_SYNC` 必须同时勾 `PUSH`（导表 clone 先 reset 到 origin，否则导出旧表且零报错）。首轮结论：+4.6% 通胀换 +10.0% 陡度、**147 SKU 只动券**、8/8 PASS，**表未落**（仍 0.3178）。
- 删号/删英雄须清 rank 与引用（`rank-audit`/`refs-audit`），且**先归档**（`cheatctl archive`）。
- `tk/getServerList` 的 `recommend` 只许来自 `is_new=1`；否则老客户端 `serverList[i].level` 空值比较中断 → 登录报 `SocketAddress is nil`。
- 全服排行宝箱（`RankingRewardLogic.takeRankingReward`）**只判宝箱非空、不判玩家在不在榜** ⇒ 人人可领（10-21 定位，待决策）；领取后界面又变可领＝客户端不回写 `RankingRewardedList`。
- 🔴 **服务端下发给聊天/邮件/跑马灯的文案一律是客户端语言表 id（数字串），禁止中文字面量**：`GetLanguageStrById` 对非数字串原样返回（functions.lua:2091）⇒ 英/日包直接显示中文。占位补位消息（`MessageCache.SEED_TEXT_IDS` 91001612~91001621，commit `cecc70f8f`）栽过，Redis 7 天 TTL 旧中文种子要手工清。语言表 10xxx 全占，新文案挂 910016xx 尾部。

## 客户端 / Lua / UI → 详见 `REF-client-ui.md`
- 硬红线只剩三条记在这里：`~Lua/*.lua` 是 **CRLF**（改完必须转回）；`LuaBytes` 源码+字节码成对提交；`BasePanel:OpenUI` 只有首次打开才调 `OnOpen` ⇒ 交接参数走 manager 字段。
- 红点/动画/地图登记等细节全在 REF，别凭印象改。

## 美术管线 / 出图 → 详见 `REF-art-pipeline.md`（分派/并行/合规）+ `REF-art-translate.md` / `REF-art-restyle.md` / `REF-promo-shots.md`
- 出图并行靠**浏览器租约**不靠串行；`gpt_layout` 必须禁模型自译；字被切只能 **lock 之前 refit**。
- 🔴 **出图节奏闸门 + 会话保活心跳（2026-10-30 建，`scripts/image/gen_pace.py`）**：Google 号因「相邻两张 46 秒、峰值 32 张/小时」被封（269 次出图实测），现在每次生成前都过闸——按**账号**记账（flock 跨进程，并行构建自动排队，多开 job 不能多画）、默认同号 ≥180s±30% 抖动 / ≤10 张/小时 / ≤50 张/天 / 连画 8 张歇 10 分钟；撞日上限把号标进台账（冷却到零点）换号，撞小时上限只等不换号。另每 **40 分钟±15%** 在同一浏览器发一条**纯文本**请求保活（用户要求「防 GC」）：失败只在本地记 `no_google` 跳过 24h（多数 profile 只登了 GPT 没登 Google，别当号坏了），但 `account-restricted`（落在 `myaccount.google.com/restrictions`）要直接台账封 7 天。Jenkins 参数 `GEN_PACE/GEN_MIN_GAP/GEN_MAX_PER_HOUR/GEN_MAX_PER_DAY/GEN_MAX_WAIT/HEARTBEAT_MIN`，超时 75→120（Restyle）/150（Translate）分钟。详见 `docs/art_restyle_pipeline.md`。
- 🔴 `gen_gemini.py` / `gemini_web_driver.mjs` 曾是未入库的本地文件（10-26 建的第二通道，10-30 才提交）⇒ 改出图链路后先 `git status` 看有没有「用着但没入库」的兄弟文件。

## 店面 / ASO（Play 商店页）→ 详情**全在 `REF-aso-store.md`**
- 只有三条留在这里：一套管线多包靠 **`ASO_SITE`**（数据根切 `data_aso/sites/<名>/`，`locales_mode=replace`）；`com.warera.timespace` 是**提交即自动送审**（**传图=上线，先问用户**）；文案里的人名必须从 `Language.xlsx` 的 English/Japanese 列取（`check_hero_names.py` 已挂 lint 闸门）。

## 资源构建
- 🔴 导表/资源构建一律走 Jenkins `TS-Resource-Build`（独立 clone `TimeSpaceGirl1-build` 里跑），**不要让用户关 Unity 编辑器**（10-21 用户纠正：开发工程开着也能导）。本地 `resource_build.sh` 才会被同 `-projectpath` 进程拒绝。打包目录从 origin 无条件 reset ⇒ **先 commit+push 再触发**（`EXPORT_TABLES=true SYNC_BYTES=true REBUILD_AB=true SERVER_ENV=正式服`），产物再手工 copy 回开发目录。`REBUILD_AB=false` 时 ⑤ 新鲜度闸门必红（正常）。
- 🔴 重建 AB = `BuildGameAssetBundles()` = `MarkGame(true)`，末尾 `ResourcesPathEditor.CreateResourcePathConfig(true)` **整体重写 ResourcePathConfig**（索引重排）⇒ 手工追加的登记必须能在重扫中复现（目录进 `resPathList`、文件真存在），否则被静默删掉。子目录一目录一包靠 `BuildConfigs.asset` 的 `SubFloderOneBundle`（`ArtFont_en`/`ArtFont_zh`/`Atlas` 都在里面）⇒ 新子目录不用改 BuildConfigs；AB 名 = `压缩类型小写/相对 ManagedResources 的路径`。
- 🔴 克隆 Unity `.meta` 时 **guid 和 `spriteID` 都要换**：只换 guid 会让两份资源共享 spriteID，SpriteAtlas 变体互相顶掉（早期 tab 01/02 已留隐患）。
- 🔴 **覆盖 job 配置会打断正在跑的构建**：`disableConcurrentBuilds(abortPrevious=false)` 只排队，但 `create-job`/apply 覆盖会中断在跑的构建且**不留 `Aborted by` 行**（#28 连 post-actions 都跑完才标 ABORTED）⇒ 改 job 前先看有没有 RUNNING；被打断时 `publish` 已覆盖的坏图会留在磁盘（#27）。
- 新增资源写回后补登记：`ArtFont_en/<族目录>/<名>_en.png` 目录必须在 `resPathList` 白名单里，否则重扫整目录跳过 ⇒ resName 不登记 ⇒ 真机白图。客户端 `_en` 加载不到会**静默回退 `_zh`**（`Util.cs:1182-1224`，日志仅一行「回退加载精灵图」）⇒ 「图没生效」看起来像「根本没写入」，要用 resName 是否进 `resInfoList` 判断。
- 🔴 出包口径名 `minimal/full` ≠ 枚举名 `MinimalGmOff/FullTemplate`：`Enum.TryParse` 失败会**静默回落 Release**（测试包被打成关日志正式包，核验判「期望 minimal 实际 release」整轮红）。排查看 `run/<tag>/logs/unity-apk.log` 的 `[CLIBuilder] TS_RELEASE_PROFILE=… 不是合法口径`（Jenkins 与 Unity 自己也印「口径 minimal」，只有产物是 release ⇒ 光读脚本看不出）。已修 `7817c3e58`；修复**必须 push** 才生效（打包目录每轮 reset origin）。

## 约定
- 巡检只读、量化分级；打包/校验/commit/push 可自行做，**送审/重启生产服/改线上部署先问**。
- 逐条 commit 且必须 push；中文 `type(scope): 摘要`；严禁 `git add -A`。
- 「都推了」= 两仓 `rev-list --count origin/<b>..<b>` 都为 0；push 前看有没有混进并行会话的提交。凭据一律 `.secrets/`（700/600）。
- 后台长任务 `Popen(..., start_new_session=True)`；zsh 下 `--include` 报 no matches（用 Grep）；GBK 源码 `grep -a`，`.jenkins/*.groovy`、`BuildConfigs.asset` 也被判 binary ⇒ 同样要 `-a`，否则静默返回空、白查。
- 🔴 并行会话共享工作区：**暂存完立刻 commit**（只 `git update-index` 不 commit，另一会话提交会连带带走）。要隔离对方未提交的改动：`git show HEAD:path` + 只套自己的改动造 blob → `git hash-object -w` → `git update-index --cacheinfo`，工作区保留对方改动。
- 改系统级状态须当场验证并标注「重启后是否有效」；打补丁先用 `git show HEAD:path`。
