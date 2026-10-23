# TimeSpaceGirl1 长期记忆（索引·红线）

> 细节在同目录 `REF-*.md`（server-ops / local-server / shard10002 / android-release / config-tables / server-name-i18n / jenkins-ci / monetization / art-restyle / client-ui / client-misc / ops-redlines / game-domain）与 `YYYY-MM-DD.md`。这里只留「不知道就会踩坑」的条目。

## 环境
- Unity `6000.6.5f1`（国际版号）；batchmode 显式 `-buildTarget Android`。
- 客户端 `a772616239/TimeSpaceGirl1`（PUBLIC，release）；服务端 `TimeSpaceServer/Server_x1tag1.2.2/`（repo `x1-tag-1.2.2`）。**并行会话会自动 commit ⇒ 提交必须显式列路径**。
- 登录服源码 `TimeSpaceServer/skzc/home/java/loginserver/src/`（属主仓）：`verify-recommend-patch.sh`、`deploy-login-server.sh check|deploy --confirm|rollback`。
- SSH `gs` 129.226.213.65（2vCPU/3.6GB 已榨干）；Mongo 串必须 `authSource=admin`；编译 `sh gradlew`；`/data/srvlog/` 仅 ~3 天，审计走 `assets/log/jl_item|jl_logs|jl_blogs`。
- Jenkins `127.0.0.1:8080`，凭据 `~/.jenkins/.qclaw-creds`（`U=a772616239`）。🔴 触发只认 `POST /job/<n>/buildWithParameters` + **表单字段**（`json={"parameter":[…]}` 能起构建但参数全取默认）；`/build` 一律 400。job 真源 `.jenkins/jobs/*.groovy` → `.jenkins/apply-jobs.sh`。

## 配置 / 服务端
- 配置表真源 `data_execl/base_data/*.xlsx`，改后同步 CRC32 + lua + LuaBytes + 服务端 `conf/server/*.txt`；备份禁放 `base_data/`。
- 货币 id `16=钻石 3=英雄经验 14=金钱 17=经验 79=情报`；名字走 `scripts/cheat/currency.py` 现算，禁写死。`item17` 语义未定（不能当离群基线）；`reason=1` 永不产出钻石。
- 正式服 `server.debug=false`；versionCode 只增不减、同号只能上一次；`--status draft` 是 production 不送审的唯一姿势。
- 删号/删英雄须清 rank 与引用（`rank-audit`/`refs-audit`），且**先归档**（`cheatctl archive`）。
- `tk/getServerList` 的 `recommend` 只许来自 `is_new=1`；否则老客户端 `serverList[i].level` 空值比较中断 → 登录报 `SocketAddress is nil`。
- 全服排行宝箱（`RankingRewardLogic.takeRankingReward`）**只判宝箱非空、不判玩家在不在榜** ⇒ 人人可领（10-21 定位，待决策）；领取后界面又变可领＝客户端不回写 `RankingRewardedList`。
- 🔴 **服务端下发给聊天/邮件/跑马灯的文案一律是客户端语言表 id（数字串），禁止中文字面量**：`GetLanguageStrById` 对非数字串原样返回（functions.lua:2091）⇒ 英/日包直接显示中文。占位补位消息（`MessageCache.SEED_TEXT_IDS` 91001612~91001621，commit `cecc70f8f`）栽过，Redis 7 天 TTL 旧中文种子要手工清。语言表 10xxx 全占，新文案挂 910016xx 尾部。

## 客户端 / Lua / UI → 详见 `REF-client-ui.md`
- 硬红线只剩三条记在这里：`~Lua/*.lua` 是 **CRLF**（改完必须转回）；`LuaBytes` 源码+字节码成对提交；`BasePanel:OpenUI` 只有首次打开才调 `OnOpen` ⇒ 交接参数走 manager 字段。
- 红点/动画/地图登记等细节全在 REF，别凭印象改。

## 美术管线 → 详见 `REF-art-pipeline.md`（分派/并行/合规）+ `REF-art-translate.md` / `REF-art-restyle.md`
- 三条必记：出图并行靠**浏览器租约**不靠串行；`gpt_layout` 必须禁模型自译；字被切只能 **lock 之前 refit**。

## 店面 / ASO（Play 商店页）
- 🔴 **Play 的能力边界别按印象说**：`edits.listings`（标题/短描述/长描述/video）与 `edits.images`（imageType: phoneScreenshots/featureGraphic/icon…）都能 API 改；但**商店页 A/B 实验没有公开 API**（建实验/看结论只能网页）。**送审模式实测更正（10-23）**：`com.warera.timespace` 是**「提交即自动送审」**，`edits.commit` 带 `changesNotSentForReview` 直接 400（"Changes are sent for review automatically…"），不带就会自动进审核队列 ⇒ 传图=上线，必须先问用户；`aso_play.py` 要加 `--auto-review` 才会真提交。核对是否生效**看 sha1**（`aso_play.py list` 导出 vs `derived/<变体>/<locale>/feature_01.png`），日志「已传 1 张」只是 upload、不含 commit。只换置顶图要 `--image-types featureGraphic`，否则连带覆盖 16 张截图。
- 入口 Jenkins `TS-Store-Iteration`；脚本 `scripts/aso/`（common/play/lint/assets/art/experiment）；文案真源 `data_aso/variants/{A,B}/<locale>.json`，A = 线上快照**禁改**；runbook `docs/play_store_iteration_aso.md`。
- 🔴 传图张数：`phoneScreenshots` ≤**8 张/语**、`featureGraphic` ≤**1 张**；`shots.json` 8 条会派生 9 张，全推必 400 ⇒ `aso_play.py --shots 0,1,2,5` 挑（`MAX_IMAGES` 兜底会告警）。`deleteall+upload` 是替换语义，推几张剩几张。核验看 **sha1**，不看张数。
- 🔴 **置顶图不能兼作手机截图**：1024×500 比例 **2.048 > 2.0** 硬拒；转竖前景仅 27.5%。置顶图讲「长什么样」，截图讲「能玩几种玩法」，内容不该重复。锐度分层：`shot_01`(1.5×)/`05`(1.1×) 最好，`00`/`02`(1.8×) 可用，`03`/`04`(2.6×) 偏糊，`06`/`07`/`08`(3.2×) 别上。
- 🔴 `aso_assets.py build` 会连带覆盖 `feature_01.png`，且 `aso_fusion.py --locales` 默认**只有 en-US** ⇒ 恢复置顶图必须显式写 `--locales en-US,ja-JP,zh-CN,zh-TW`，否则只 promote 一个语言。
- 硬上限：标题 30 / 短描述 80 / 长描述 4000（码位）。Play 截图最短边 ≥320、最长边 ≤3840、**长宽比 ≤2:1**（9:19.5 的原始竖截会被拒）、单张 ≤8MB；置顶图固定 1024×500。
- 🔴 这游戏是**纯竖版**（`defaultScreenOrientation=0`，只允许 Portrait），而线上 4 张 phoneScreenshots 全是 1920×1080 横版 ⇒ 手机商店页两条黑边、首图面积浪费一半。竖版源图在 `时空美少女物料/`（uuid 命名的 597~720px 宽），放大 1.8× 才到 1080。
- 🔴 截图底部 1/3 常挂**中文世界聊天**，上商店页必须按图配 `crop_bottom` 裁掉；卖点条要**预留**在画布下方，不能叠在画面上（叠加会被聊天行糊穿）。
- A/B 读数纪律：单窗口 ≥7 天且 ≥1000 访问才读，否则脚本直接报「数据不足」，不输出 uplift；且是顺序窗口对比，非随机分流。
- 换皮链路：`aso_art.py plan/seed/trigger/ingest`；`TS-Art-Restyle` 的 `ASSET` 是相对工程根路径，`WRITE_BACK` 必须 false；并行靠浏览器租约，`TSG_LEASE_OWNER=$JOB_NAME-$BUILD_NUMBER`。
- 🔴 **从立绘池选角色必须逐张放大看图**：立绘 123 张基础图（156 含表情差分），光看名字会挑错——`韩信/尼禄/霍恩海姆/亚瑟/帕里斯/西巴达/法姆贡/海明威/荣芙/运动员` 在游戏里都是**男性**。选人后配色走 `hero_features.py extract --art` 现算，原图暴露的改写成不透明覆盖版。多组候选：`fusion_pairs.json`（**tag 必须是 left+right 拼的四位数**，否则底图收不到）+ `hero_keyart.py batch`（串行/断点续跑/`--force`）+ `aso_fusion.py --bg`（覆盖底图，别反复改 fusion.json）+ `fusion_page.py` 验收页；候选目录**禁 `--promote`**（会把 feature_01 覆盖成一张并清掉其它）。一组 89~126s，卡到 8 分钟是踩坏号（`cdp:xxxxx 不可用 → 换下一个号`），**别 kill**。
- 🔴 **置顶图拼装链路（定版，2026-10-23）**：三层拆分——两侧角色 `hero_keyart.py duo --pair 01,02 --wait`（管线按**特征卡**重绘，立绘只抽特征、**禁止贴立绘**）→ 中间压实机截图框 → 底部本地压字；`aso_fusion.py build --promote` 把成品写成 `derived/<变体>/<语言>/feature_01.png`（同 `aso_assets build` 文件名）并清掉其它 `feature_*`、刷 `index.json` 哈希 ⇒ preview/push 不用改、不会出现两张置顶图。**无需抠图**的取巧点：底图中段 60% 留空后被画面框整块盖住。Jenkins `TS-Store-Iteration` ③b 阶段，参数 `FUSION` / `FUSION_PAIR` / `FUSION_RENDER`（只有 RENDER 才耗额度）。换图后必须 `aso_assets.py preview` 刷验收页数字。skill `aso-store-iteration`。
- 🔴 店面图口径：**AI 只画画面，标题一律本地真字体压**（`aso_assets.py headline`）——中/日/繁字形模型会画错、四语排版要统一、改文案不该重出图。宣传图真源 `时空美少女物料/新版本宣传图/*_{1920,1024}/`（专业排版，远超 `1024*500/` 那张拼贴）；配方 `data_aso/assets/promo.json`，AI 底图 `data_aso/assets/gen/`（进库），`seeds/` 不进库。
- 🔴 画店面图三坑：`LAYOUT` 必须写死「NO text + 底部 N% 留空」（否则面板压到底、标题没处放）；主题 `outfit` 句会把角色原服装换掉 ⇒ `OUTFIT` 逐件点名保留；design 构图自动套金卡框 ⇒ `postprocess --frame none --alpha-mode keep` 复用生成图重跑。实测出图 ~90s。
- 🔴 **置顶图左右角色不许贴现成立绘**（用户否决：不同光源/画风，一眼剪贴画）⇒ `hero_keyart.py duo --pair 01,02` 按特征卡重绘双人底图（两人都被左右边缘裁切、中间 60%+底部 26% 留空）。中间那块之后被实机截图整块盖掉 ⇒ 不需要抠图（管线不出透明角色，chroma key 抠不干净）。版面 `aso_fusion.py` + `data_aso/assets/fusion.json`；框内取景 `band` 必须避开截图底部按钮行（取 `[0.40,0.80]`，否则中文「禁止」会挂到英文商店页）。
- 🔴 **立绘特征卡里的 `bare legs/bare feet` 会画出高开叉露胯**（Play 必拒）⇒ 一律写及踝长裙/高腰不透明衬裙；`hero_prompt.py` 有 `DRESS CODE` 硬约束段（groin/buttocks 必须覆盖、开叉不过膝、列 forbidden 词），单人/双人模板都带。
- ⚠️ Jenkins job META 里布尔参数 **必须写 `type:"bool"`**，写 `"boolean"` 会渲染成字符串参数 ⇒ `when { expression { params.X } }` 恒真（TS-Store-Iteration #1 踩到）。
- 🔴 置顶图 10 组候选**不能共用同一段画面**：`fusion.json` 的 `screen.shot/band` 是全局值，所有组都读它 ⇒ 缩略图「同一画面重复十遍」（10-23 用户指出）。每组在 `fusion_pairs.json` 里带 `screen{shot,band,focus_x,zoom}`，`aso_fusion.py --pair <tag>` 一次出齐。干净合规真机截图只有 3 张 ⇒ 只能做「3 场战斗的 10 种景别」，要 10 场不同必须补真机截图；`band` 0.30 起（更低吃空景）、0.90 封顶（再往上是中文按钮行）。
- 🔴 验收页 `data_aso/derived/<变体>/preview.html` 是**验收台**（真机模拟+合规检查+文案计数+灯箱），不是缩略图墙；**改任何前端都要先无头截图自己看一眼**再交付（Chrome `--headless=new --user-data-dir=/tmp/x --screenshot`，不带 user-data-dir 会静默不出图）。⑤ 归档必须 `cp -R` 整目录，只 cp 那个 html 就是满屏 404。

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
