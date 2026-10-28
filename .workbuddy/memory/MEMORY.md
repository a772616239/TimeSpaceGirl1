# TimeSpaceGirl1 长期记忆（索引·红线）

> 细节在同目录 `REF-*.md`（server-ops / local-server / shard10002 / android-release / config-tables / server-name-i18n / jenkins-ci / monetization / art-pipeline / art-restyle / art-translate / **promo-shots** / client-ui / client-misc / ops-redlines / game-domain）与 `YYYY-MM-DD.md`。这里只留「不知道就会踩坑」的条目。

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
- 🟢 **数值迭代优化 = Jenkins `TS-Numeric-Optimize`**（10-28 建，默认全程只读；引擎 `scripts/numeric_optimize.py`，文档 `docs/numeric_optimize_skill.md`）。四条别凭印象：**通胀是硬约束不是权重**（软权重会把「陡度+20% 换通胀+9%」判成优＝R7 那类错觉）；**跨轮累计上限 25% 且锚点粘住**（`state.json` 的 `anchor_rate` 只写一次，要重置只能人显式 `--reanchor`/勾 `REANCHOR`）；`best/` 必须按 `changes` **确定性重建**（草稿目录是所有候选共用的）；`TRIGGER_SYNC` 必须同时勾 `PUSH`（导表 clone 先 reset 到 origin，否则导出旧表且零报错）。首轮结论：+4.6% 通胀换 +10.0% 陡度、**147 SKU 只动券**、8/8 PASS，**表未落**（仍 0.3178）。
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
- 🔴 **一套管线多包靠 `ASO_SITE`**（10-24 建，第二个包 Capybara Merge `com.cocos2d.piggie`）：数据根切 `data_aso/sites/<名>/`，`site.json` 用 `locales_mode=replace`（默认 merge 会把主项目 ja/zh-TW 带进没开通的包，`listings.get` 直接 404）；Jenkins 两 job 加 `SITE` 参数、路径走 `${ASO_DATA:-data_aso}`、发布闸门从 `C.PACKAGE` 读包名；`SKIP_ASSETS` 用于无素材站点跳过 ③⑤。`_get_listing` 把 404 视为「该语言未开通 ⇒ push 可新建」。
- 🔴 **Play 能力边界别按印象说**：`edits.listings`（title/short/full/video）与 `edits.images`（phoneScreenshots/featureGraphic/icon…）都能 API 改；**A/B 实验无公开 API**（建/看结论只能网页）。`com.warera.timespace` 是**「提交即自动送审」**：`edits.commit` 带 `changesNotSentForReview` 直接 400，不带就进审核队列 ⇒ **传图=上线，必须先问用户**；`aso_play.py` 加 `--auto-review` 才真提交。核对生效看 **sha1**（list 导出 vs `derived/`），日志「已传 1 张」只是 upload 不含 commit。只换置顶图写 `--image-types featureGraphic`，否则连带覆盖 16 张截图。
- 入口 Jenkins `TS-Store-Iteration`；脚本 `scripts/aso/`；文案真源 `data_aso/variants/<变体>/<locale>.json`，**A = 线上快照禁改**；runbook `docs/play_store_iteration_aso.md`。
- 🔴 **商店文案里的人名必须从 `Language.xlsx` 的 English/Japanese 列取，不许按自己熟的写法写**（10-24 栽过）：我写过 `King Arthur / Li Bai / Napoleon / Qin Shi Huang`，游戏内实际是 `Arthur / Li Taipo / Napoleone / Ying Zheng`；日文同批错 4 个（`チンギス・ハン`→`カン`、`ジャンヌ・ダルク`→`ジャンヌ`、`キュリー夫人`→`マリ・キュリー`、`アテナ`→`アテーナー`）。用户下游戏搜不到人＝虚假宣传。已加 `scripts/aso/check_hero_names.py`（消解法，不切分，避开日文名自带 `・`）并挂进 `aso_lint.py` 闸门（基线 A 跳过）。**`zh-TW` 无独立列**，走 opencc `s2t` + 台湾异译白名单（`亞森羅蘋/唐吉訶德/莫札特/蕭邦`），只警告不阻断。
- 🔴 **短描述别用「名人 A 和名人 B 同队」这个模板**（10-24 用户两次纠正：先「关羽老外听不懂」，再「怎么老执着于关羽」）：我一个句式套了四语（`关羽和凯撒同队` / `關羽和凱撒同隊` / `関羽とカエサルが同じ隊に` / `Guan Yu and Caesar on one team`）—— 换个人名不算重写。定稿改「阵容 + 机制」：en `90 legends from history. Nine squares, five fighters. Misplace one, run ends.`、zh `90 位跨时代角色，历史神话小说混编。九格五席，站错一格就团灭。`、ja `歴史・神話・小説の英雄90人が同じ名簿に。9マス5枠、配置で生死が決まる放置カードRPG。`。**具体人名只放长描述的名单段**，首屏不靠认人；名单顺序按当地认知度排（en 第一行跨文化共识名、亚洲末行；中日文反之）。
- 🔴 **关键词周期 `TS-ASO-Cycle`（每 3 日，10-24 建）**：补原三件套缺的「设计」环。`aso_keyword_cycle.py`（gate 未到期 rc=3 / plan 无变更 rc=4 / lint-gate **增量口径** / record+ledger）；词表 `data_aso/keywords/{seed_terms,rewrite_rules}.json`（规则默认 `enabled=false` 人审关口）。cron 每 6h 探针 + 72h 闸门（**别用日字段 `*/3`，跨月会抖成 1~3 天**）。派生父本默认最新 treatment 而非 A。发布双确认 `PUBLISH=review` + `CONFIRM_PACKAGE`=包名。
- 分词红线：**片假名整段当一个词**（切了就出 `クター`/`ラク`）；汉字段才 n-gram + 词表最长优先遮蔽；来源分按**种类**不按份数（快照越攒越多会让所有词都变「来源 10」）。`repeat_warning` 只跟「真动过」的轮次比。
- 🔴 **长描述走「成品整体替换」不走替换对**：`data_aso/keywords/fulltext/<locale>.txt` + `--with-fulltext`（Jenkins 参数 `FULLTEXT`，默认 false）。替换对撑不起缺口，成段补内容必须语义连贯。落盘前强检 ≤4000 字 + 字符集。`audit` 体检「字数/首屏80/品类词覆盖/字符集」，`probe` 字段在 seed_terms.json。
- 🔴 **线上与变体的长描述不是同一份**：`audit` 查**线上**，`plan` 查**父本**。10-24 线上 zh-TW 曾简体混排（29 字，繁体品类词 3/15 ⇒ 搜「放置/陣容/聲優」匹配不到，属**搜索可见性故障**，不参与 A/B 只能直修），已随 L 修好。另「利用率低」**≠** 该加字：中文 900 字已装完卖点，堆到 3000 是注水降转化，收益只在「缺的品类词补上」。
- 🔴 传图张数：`phoneScreenshots` ≤**8/语**、`featureGraphic` ≤**1**；`shots.json` 8 条派生 9 张，全推必 400 ⇒ `--shots 0,1,...,7` 挑。`deleteall+upload` 是替换语义，推几张剩几张。
- 🔴 **用户偏好横版截图**（10-24 否决竖版）⇒ 走 `fusion_shots.py`：置顶图 1024×500 比例 2.048 只超 0.048，**补边到 1024×520（1.969）即可**，画面不动、补边用首末行高斯模糊。**定稿 6 组序 `0102,2019,1013,0922,0715,1821`**；`0823`/`1624` 素材不合格已 `_retired`，`1125`/`1426` 没上。
- 🟢 **10-24 09:41 变体 N 已送审：游戏改名为《群星列阵》/`Starhost`**（四语 title+short+full 全量重写，`data_aso/variants/N/`，
  lint 红 0 黄 0，edit 已 commit ⇒ 进审核队列）。旧名 时空群英／超时空美少女／Neon Valkyries／時空を旅する美少女 **全部作废**。
  实验 `aso-20261024-rename-N`（A→N，14 天）；L 与 M 均标 `superseded`（M 的中文窗口只活 16 分钟）。
  ⚠️ 改名不可 A/B 且与文案纠错同批 ⇒ 只能回答「N 整体是否优于 A」，不能归因到名字。
  命名依据：现名是不可独占的通用词堆叠，且「时空/裂隙/赛博霓虹」整条赛道已被《时隙之旅/时之裂隙》逐项占满。
- 🔴 **文案事实口径（写商店文案前必查）**：90 个可玩角色（`HeroConfig` 110 行 − 20 个克隆体）、**9 格 5 席**（`FormationConfig.pos` 只到 9、6 套预设）、
  全角色独立 Live2D、4 种职业。**禁止再写** 7x7 战棋（不存在）、纯赛博少女（关羽/凯撒/爱因斯坦男角混编）、零付费墙（不可核）、100+（现为 90）。
- 🟢 **10-24 02:12 中文标题曾换为「时空群英：放置阵型RPG」**（变体 `M`，已被 N 取代）。
- ✅ **com.warera.timespace 四语各 6 张截图 + 1 张置顶图**（`aso_play list` 实测，`phoneScreenshots:6/featureGraphic:1`）。「0 截图 0 置顶图」是 **capybara 包**的状态，别串包（10-24 曾因此误判成阻塞项）。
- 🟢 **10-24 已上线变体 L（四语全量文案）**：title/short 沿用 B，长描述换成 `fulltext` 成品。实验 `aso-20261024-copy-L`（已被 N 取代）；旧 B 窗口标 `superseded`（从未上线，别用 `close`——它强制填 winner）。
- 🟢 **10-24 02:12 中文标题换为「时空群英：放置阵型RPG」**（变体 `M` = L + 只换 zh 标题，用户拍板；线上已核验）。实验 `aso-20261024-title-zh-M`（L→M，14 天）。⚠️ L 的中文窗口只活了 16 分钟 ⇒ `aso-20261024-copy-L` 的 locales 已收窄为 en-US/ja-JP。**中文短描述仍是旧口径（赛博少女/7x7战棋/零付费墙）与标题打架，未改。**
- 硬上限：标题 30 / 短描述 80 / 长描述 4000（码位）。截图最短边 ≥320、最长 ≤3840、**长宽比 ≤2:1**、单张 ≤8MB；置顶图固定 1024×500。
- 🔴 这游戏**纯竖版**（`defaultScreenOrientation=0`）但线上 4 张手机截图是 1920×1080 横版 ⇒ 两条黑边、首图浪费一半面积。竖版源图在 `时空美少女物料/`（597~720px 宽，要放大 1.8×）。
- 🔴 截图底部 1/3 常挂**中文世界聊天**，必须按图配 `crop_bottom` 裁；卖点条**预留**在画布下方，不能叠画面（会被聊天行糊穿）。
- A/B 读数：单窗口 ≥7 天且 ≥1000 访问才读，否则直接报「数据不足」；是顺序窗口对比，非随机分流。
- 换皮：`aso_art.py plan/seed/trigger/ingest`；`TS-Art-Restyle` 的 `ASSET` 是相对工程根路径，`WRITE_BACK` 必须 false；并行靠浏览器租约 `TSG_LEASE_OWNER=$JOB_NAME-$BUILD_NUMBER`。
- 🎨 截图/置顶图/店面图全流程 → **详见 `REF-promo-shots.md`**（可复用链路、③ 阶段顺序、选角色、三层拼装、`band` 取景、店面图三坑、合规、验收页）。只记两条在此：**两侧角色禁止直接贴立绘**（按特征卡重绘）；**特征卡禁写 `bare legs/bare feet`**（会画高开叉露胯，Play 必拒）。
- ⚠️ Jenkins META 布尔参数**必须写 `type:"bool"`**，写 `"boolean"` 会变字符串参数 ⇒ `when { expression { params.X } }` 恒真。

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
