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

## 客户端 / Lua / UI
- 真机读 `LuaBytes/<路径>_64.bytes` ⇒ 源码+字节码成对提交（`scripts/lua-bytes-sync.sh`，不加 `-g`）。
- `~Lua/*.lua` 是 **CRLF**（`docs/`、`scripts/` 是 LF）：改完必须转回 CRLF，否则 diff 变「全文件重写」。
- `tolua` fake-null 只能 `IsNull()`；红点 `BindObjs[rpType]` 不幂等；`Timer.New` 第 4 参 UI 传 `true`。
- 红点树：**父红点值 = 子红点按位或**，父节点不能再 `AddCheckFunc`（静默丢弃、永不刷新）。入口红点必须与「面板里看得见的红点」同口径，否则「外面亮、点进去全灭」（10-21 契约 page2 / 神眷者 page4）。研发等级红点落点只在研发面板 ⇒ 不许挂 `Lead`。
- 🔴 `BasePanel:OpenUI` **只有首次打开才调 `OnOpen(...)`**（面板缓存，重开 `IsBackOpen=true` ⇒ 只调 `OnShow`）：面板间交接参数不能走 `OnOpen` 形参，必须读 manager 级字段（如 `AircraftCarrierManager.pendingAssemblySelect`）；靠 `OnOpen` 初始化的成员第二次打开全是上一轮旧值。装配红点/入口 10-22 按此改（`GetEquippableSkillList` 单口径 + `SetScroll` 结尾反算）。
- 🔴 红点排障先看项目内 `Logs/Editor.log` 的 `[RedPoint]` 行（不是 `~/Library/Logs`）；`RedPointType` **会撞号**（Lead_UpLv/SpeedLvUp ↔ 扭蛋已修），改父子关系后**必须重启客户端**（`RedPointData` 树是模块级局部变量，`SetParent` 对已有父节点直接 return；已加 `RedPointData:Reset()`，旧 session 仍要重启）。
- `ActivityRewardConfig.Values` 是 `{{参数},{阈值}}` 两组，但 1216 行里 617 行只有一组 ⇒ 一律走 `ActivityGiftManager.GetMissionNeedValue(conFigData, 组号)`，**禁止 `Values[2][1]`**（nil 索引会打断 `MainPanel.OnShow` 整链）。达人活动自己的行都是两组，报错＝missionId 落到别的活动的行（老号残留 / 服务端配置与外网不一致）。
- 🔴 **点号定义 / 冒号调用是隐形参数错位**：`function this.X(index)` + `this:X(index)` ⇒ self 顶进第一形参、实参整体右移（10-22 `CardActivityPanel:109` 崩在这：`contents[面板表]=nil` ⇒ LuaJIT `attempt to index field '?'`，**'?' = 动态 key 取到 nil 再取字段**，先查 key）。加 helper 后跑 `scripts/lua-tests/` 的 `badCallStyles`。
- 新增地图三步：prefab `.meta assetBundleName`（复制来的会继承 mapN-1）+ `ResourcePathConfig.asset` 三处**末尾追加**（resAbNameList / resInfoList / assetBundleList 条数必须相等，插中间会平移几千个 resAbNameIndex）+ `MainLevelConfig.BG`。漏登记 ⇒ `resMgr:LoadAsset` 返 nil，挂机战斗起不来。
- 🔴 `GetPictureFont` 只对「名字带 `_zh` 后缀」的资源成立（按 `GetLan()` 拼 `_zh/_en/_jp`）。图集里中文原图大量无后缀（`Atlas/LaddersTypePanelAtlas` 9 张只有 1 张带 `_zh`）⇒ 中文/日文拼出不存在的名字 ⇒ 整块白图。这类改用条目显式字段（`bgEn = "<名>_en"`，`GetLan()==1` 才换），且要在刷新时求值、别写进 require 期表构造。
- UI「列表项逐格放大缩小」入场统一 `Modules/Common/ItemPopIn`（配方/坑见 `docs/ui_item_pop_in_skill.md`），禁止各面板复写；只在玩家主动换屏播，数据回调刷新不播。「从一侧滑入 + 底板淡入」走 `docs/ui_item_slide_in_skill.md`（已落地 BattlePass 任务卡 / DailyCarbon 副本卡）。🔴 参考 clip 节奏（0.167/0.033）是**弹窗一次性入场**，落在切页签上必然太快 ⇒ 打开 / 切页签两套 preset，切页签另加 0.05s 整批延后起播躲 `SetData` 那帧并挡连点叠播。`Util.GetGameObject` 按名字 **DFS** 找第一个同名节点 ⇒ 目标名必须整棵子树唯一。
- 复刻 `.anim` 走 `docs/ui_anim_reproduce_skill.md` 五阶段（S0 反解出分镜表，`dump_clip.py` 读全 `m_*Curves`）。**TabBox 页签取列表必须读 `box` 子节点**（`this.TabCtrl:GetTabList()` 常为空实例 ⇒ 静默不播）；例外：`Init_SetTabAndBox` 显式传 tab/box 的面板（DailyCarbon 已落）可放心用。布局组占位时位移改写到子节点；`ScrollCycleView` item 根 `anchoredPosition` 由 `SetData`/`SetItemIndex` 直接重写（同理写子节点）。`dump_clip.py` 只给节点名（`grid/item1`）、给不出业务语义 ⇒ 动手前先确认是哪张列表。

## 资源构建
- 🔴 导表/资源构建一律走 Jenkins `TS-Resource-Build`（独立 clone `TimeSpaceGirl1-build` 里跑），**不要让用户关 Unity 编辑器**（10-21 用户纠正：开发工程开着也能导）。本地 `resource_build.sh` 才会被同 `-projectpath` 进程拒绝。打包目录从 origin 无条件 reset ⇒ **先 commit+push 再触发**（`EXPORT_TABLES=true SYNC_BYTES=true REBUILD_AB=true SERVER_ENV=正式服`），产物再手工 copy 回开发目录。`REBUILD_AB=false` 时 ⑤ 新鲜度闸门必红（正常）。
- 🔴 重建 AB = `BuildGameAssetBundles()` = `MarkGame(true)`，末尾 `ResourcesPathEditor.CreateResourcePathConfig(true)` **整体重写 ResourcePathConfig**（索引重排）⇒ 手工追加的登记必须能在重扫中复现（目录进 `resPathList`、文件真存在），否则被静默删掉。子目录一目录一包靠 `BuildConfigs.asset` 的 `SubFloderOneBundle`（`ArtFont_en`/`ArtFont_zh`/`Atlas` 都在里面）⇒ 新子目录不用改 BuildConfigs；AB 名 = `压缩类型小写/相对 ManagedResources 的路径`。
- 🔴 克隆 Unity `.meta` 时 **guid 和 `spriteID` 都要换**：只换 guid 会让两份资源共享 spriteID，SpriteAtlas 变体互相顶掉（早期 tab 01/02 已留隐患）。
- 🔴 **覆盖 job 配置会打断正在跑的构建**：`disableConcurrentBuilds(abortPrevious=false)` 只排队，但 `create-job`/apply 覆盖会中断在跑的构建且**不留 `Aborted by` 行**（#28 连 post-actions 都跑完才标 ABORTED）⇒ 改 job 前先看有没有 RUNNING；被打断时 `publish` 已覆盖的坏图会留在磁盘（#27）。
- 新增资源写回后补登记：`ArtFont_en/<族目录>/<名>_en.png` 目录必须在 `resPathList` 白名单里，否则重扫整目录跳过 ⇒ resName 不登记 ⇒ 真机白图。客户端 `_en` 加载不到会**静默回退 `_zh`**（`Util.cs:1182-1224`，日志仅一行「回退加载精灵图」）⇒ 「图没生效」看起来像「根本没写入」，要用 resName 是否进 `resInfoList` 判断。

## 美术管线 → 详见 `REF-art-translate.md`（翻译）/ `REF-art-restyle.md`（换皮）
- 四族按源图特征自动分派（尺寸带互不重叠）：`ArtFont_zh/**` 884x544→artfont（锚点写死）；`Atlas/**`→atlas；≤700x500 且 ≤8 色→glyph；≥800x700→poster。**glyph / poster / 512x256 texie 只能 provider=chatgpt_web**（local 会 rc=3）。884x336 彩带满幅（`ExpertPanelAtlas/banner/`）落在 artfont 尺寸带但版面不同 ⇒ 显式 `--family poster`。
- `MODE=one` 传 `--asset` 必指**真实存在的源文件名**（多数带 `_zh`，Atlas 图无后缀；口述名字常漏 `_zh`，先 `ls` 核）；用 `--only` 会让 ②③④「目标 0 张」全绿＝假绿球。
- 出图串行（一份登录态 + 一份包月额度）：`disableConcurrentBuilds()` 别去。复用已登录浏览器用 `find_browser_cdp.py` 反查端口（常 62081）传 `CDP_PORT`；额度看 `banner_translate.py quota`。
- 🔴 `gpt_layout` 开头必写 `TARGET TEXT IS FIXED — copy it verbatim, do NOT translate anything yourself` + IDENTITY LOCK（禁止新增人物/插画/装饰，底板与 HERO-SKILL 小标不动）——模型会自造译名（mozhate 要 Ave Verum Corpus 出图是 DIVINE JUDGMENT；zhende #16 整幅画成角色插画）。硬参数（行数/字数/字面/宽度像素区间）它听，**行距/内缩不听**。
- 🔴 字被切只有一个修法：**lock 之前 refit**（`putalpha` 才啃笔画）；判定量 `ink & (alpha<=8)`，只压有笔画越界的那几行字带，腾出列填底板背景中位数。别拿「越界比例」当闸门（零判别力）。详见 REF。
- 🔴 透明图统计一律走 alpha 掩膜（`_visible_mask`），异形卡四边不是背景（`POSTER_EDGE_MIN_OPAQUE=0.50` 量边圈占比，低于判不适用）；OCR 闸门 `text_fit.py`（tesseract 三坑见 REF），**跑不起来降黄 + 说明原因，不许静默算 0**（本机未装 tesseract，当前必跳过）。
- 🔴 en 图**平铺族目录根**（`ArtFont_en/<族目录>/<名>_en.png`，zh 侧 `tab/`/`banner/` 压平）；目录不在 `resPathList` 白名单 ⇒ 重扫跳过 ⇒ 真机白图。写回 ≠ 进包（要重打 AB）；`_en` 缺失客户端**静默回退 `_zh`**，判断写没写看 resName 是否进 `resInfoList`。
- 🔴 换皮 = 换色不是换结构；重装/机械角色必须 `--outfit` 逐件点名装备（「保留分节与铆钉只换色，不许变 gift box / 丝带 / 包裹，双手原姿势可见」）。换风格出图**禁用内置 ImageGen**（10-21 用户明确），只走 AdsPower；号池 6 个但换号链默认只试 3 个 ⇒ 显式 `ADSPOWER_PROFILES` + 看过期台账 `_output/art_restyle/provider_state.json`。
- 🔴 异形透明 + 要套框 ⇒ `--alpha-mode keep --frame card --frame-rim violet`（源 alpha 按老构图抠的，套到重画图上会硬斜切）。

## 约定
- 巡检只读、量化分级；打包/校验/commit/push 可自行做，**送审/重启生产服/改线上部署先问**。
- 逐条 commit 且必须 push；中文 `type(scope): 摘要`；严禁 `git add -A`。
- 「都推了」= 两仓 `rev-list --count origin/<b>..<b>` 都为 0；push 前看有没有混进并行会话的提交。凭据一律 `.secrets/`（700/600）。
- 后台长任务 `Popen(..., start_new_session=True)`；zsh 下 `--include` 报 no matches（用 Grep）；GBK 源码 `grep -a`，`.jenkins/*.groovy`、`BuildConfigs.asset` 也被判 binary ⇒ 同样要 `-a`，否则静默返回空、白查。
- 🔴 并行会话共享工作区：**暂存完立刻 commit**（只 `git update-index` 不 commit，另一会话提交会连带带走）。要隔离对方未提交的改动：`git show HEAD:path` + 只套自己的改动造 blob → `git hash-object -w` → `git update-index --cacheinfo`，工作区保留对方改动。
- 改系统级状态须当场验证并标注「重启后是否有效」；打补丁先用 `git show HEAD:path`。
