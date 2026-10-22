# TimeSpaceGirl1 长期记忆（索引·红线）

> 细节在同目录 `REF-*.md` 与 `YYYY-MM-DD.md`；这里只留「不知道就会踩坑」的红线。
> REF：`server-ops`（打包/热补丁/区服寻址）·`local-server`（自测服 16081+8081）·`shard10002`（历史）·`android-release`（AAB/AB/16KB/账号）·`config-tables`（xlsx→lua→TSV+CRC32）·`server-name-i18n`·`jenkins-ci`·`monetization`（付费/定价/抽卡，🔴 标尺用「抽等值」不用钻/元）。

## 环境
- Unity `6000.6.5f1`：必须国际版号；batchmode 显式 `-buildTarget Android`。
- 客户端 `a772616239/TimeSpaceGirl1`（PUBLIC，release）；服务端 `TimeSpaceServer/Server_x1tag1.2.2/`（独立 repo，`x1-tag-1.2.2`）。**并行会话会自动 commit ⇒ 提交必须显式列路径**。
- 登录服源码在 `TimeSpaceServer/skzc/home/java/loginserver/src/`（属主仓）：`verify-recommend-patch.sh`、`deploy-login-server.sh check|deploy --confirm|rollback`。
- SSH `gs` 129.226.213.65（2vCPU/3.6GB 已榨干）；Mongo 串必须 `authSource=admin`；编译 `sh gradlew`。`/data/srvlog/` 仅 ~3 天，审计走 `assets/log/jl_item|jl_logs|jl_blogs`。

## 🔴 红线
- 真机读 `LuaBytes/<路径>_64.bytes` ⇒ 源码+字节码成对提交（`scripts/lua-bytes-sync.sh`，不加 `-g`）。
- `~Lua/*.lua` 是 **CRLF**（`docs/`、`scripts/` 是 LF）：脚本/Write 改完必须转回 CRLF，否则 diff 变「全文件重写」。
- 货币 id `16=钻石 3=英雄经验 14=金钱 17=经验 79=情报`；名字走 `scripts/cheat/currency.py` 现算，禁写死。`item17` 语义未定，不能当离群基线；`reason=1` 永不产出钻石。
- `tolua` fake-null 只能 `IsNull()`；红点 `BindObjs[rpType]` 不幂等；`Timer.New` 第 4 参 UI 传 `true`。
- 红点树：**父红点值 = 子红点按位或**，且父节点不能再 `AddCheckFunc`（静默丢弃、永不刷新）。入口红点必须与「面板里看得见的红点」同口径，否则必出「外面亮、点进去全灭」（10-21 契约 page2/神眷者 page4 就这毛病；研发等级红点落点只在研发面板 ⇒ 不许挂到 `Lead`）。
- 🔴 红点排障先看 `Logs/Editor.log`（项目内，不是 `~/Library/Logs`）的 `[RedPoint]` 行；`RedPointType` **会撞号**（已修 Lead_UpLv/SpeedLvUp ↔ 扭蛋），改父子关系后**必须重启客户端**——`RedPointData` 的树是模块级局部变量，`SetParent` 对已有父节点直接 return（已加 `RedPointData:Reset()`，但旧 session 仍要重启）。
- `ActivityRewardConfig.Values` 是 `{{参数...},{阈值...}}` 两组，但 **1216 行里 617 行只有一组** ⇒ 活动红点/面板里一律走 `ActivityGiftManager` 的 `GetMissionNeedValue(conFigData, 组号)`，**禁止直接 `Values[2][1]`**（nil 索引会把 `MainPanel.OnShow` 整条链打断）。达人活动自己的行全是两组，报错意味着 missionId 落到了别的活动的行（老号残留 / 服务端配置与外网不一致）。
- 配置表真源 `data_execl/base_data/*.xlsx`，改后同步 CRC32 + lua + LuaBytes + 服务端 `conf/server/*.txt`；备份禁放 `base_data/`。
- 🔴 **服务端下发给聊天/邮件/跑马灯的文案一律是客户端语言表 id（数字串），禁止中文字面量**：客户端 `GetLanguageStrById` 对非数字串原样返回（functions.lua:2091）⇒ 英文/日文包直接显示中文。占位补位消息（`MessageCache.SEED_TEXT_IDS` 91001612~91001621，commit `cecc70f8f`）就栽过：Redis 里 7 天 TTL 的旧中文种子要手工清掉才会消失。语言表 id 用尽段：10xxx 全占，新文案挂 910016xx 尾部。
- 正式服 `server.debug=false`；versionCode 只增不减、同号只能上一次；`--status draft` 是 production 不送审的唯一姿势。
- 删号/删英雄须清 rank 与引用（`rank-audit`/`refs-audit`），且**先归档**（`cheatctl archive`）。
- `tk/getServerList` 的 `recommend` 只许来自 `is_new=1`；否则老客户端 `serverList[i].level` 空值比较中断 → 登录报 `SocketAddress is nil`。
- 全服排行宝箱（`RankingRewardLogic.takeRankingReward`）**只判宝箱非空、不判玩家在不在榜** ⇒ 人人可领（10-21 已定位，待决策）。领取后界面又变可领＝客户端不回写 `RankingRewardedList`。
- 美术换风格出图**禁用内置 ImageGen**（10-21 用户明确），只走 AdsPower 换号；号池 6 个但换号链默认只试 3 个 ⇒ 必须显式 `ADSPOWER_PROFILES`，且换号要看过期台账 `_output/art_restyle/provider_state.json`。
- 新增地图 = **三步都得做**：prefab 的 `.meta assetBundleName`（复制来的会继承成 mapN-1）+ `ResourcePathConfig.asset` 三处**末尾追加**（resAbNameList / resInfoList / assetBundleList，条数必须相等，插中间会平移几千个 resAbNameIndex）+ `MainLevelConfig.BG`。漏资源登记 ⇒ `resMgr:LoadAsset` 返 nil，挂机战斗起不来。
- 🔴 **导表/资源构建一律走 Jenkins `TS-Resource-Build`（在独立 clone `TimeSpaceGirl1-build` 里跑），不要让用户关 Unity 编辑器**（10-21 用户明确纠正：开发工程开着也能导）。本地 `resource_build.sh` 才会被同 `-projectpath` 进程拒绝。打包目录从 origin 无条件 reset ⇒ **先 commit+push，再触发**（`EXPORT_TABLES=true SYNC_BYTES=true REBUILD_AB=true SERVER_ENV=正式服`），产物再手动 copy 回开发目录。`REBUILD_AB=false` 时 ⑤ 新鲜度闸门必红（正常，非导表失败）。
- 美术翻译链 `TS-Art-Translate` 有**四族**，按源图自身特征自动分派（尺寸带互不重叠）：`ArtFont_zh/**` 884x544 → artfont（版面锚点写死）、`Atlas/**` → atlas（纯色黑板自动定位）、`ArtFont_zh` 下 **≤700x500 且 ≤8 色** → glyph（页签类白字+alpha 字块）、**≥800x700**（`DynamicActivityPanelAtlas/banner/` 884x856）→ poster（插画+彩带，整幅重绘后 cover 回原尺寸）。glyph / poster **只能** provider=chatgpt_web（local 会明确 rc=3），且都走译名表白名单。`MODE=one` 推 `--only` 时命名要归一化（atlas 图**没有** `_zh` 后缀），否则 ②③④ 全绿但目标 0 张＝假绿球。
- 🔴 **en 图一律平铺在族目录根**（`ArtFont_en/<族目录>/<名>_en.png`，族目录 = `ArtFont_zh/`/`Atlas/` 后第一段），zh 侧的 `tab/`、`banner/` 子目录**必须压平**：工程既有 60+ 张 en 图全是这个布局，且 `resPathList`（`ResourcePathConfig.asset`，868 条手工白名单，**一个目录 = 一个 AB**）里根本没有 `ArtFont_en/…/tab` ⇒ 重扫整目录跳过 ⇒ resName 不登记 ⇒ 白图。`publish` 现在有 `check_target_registered`（**父目录精确匹配**，别用祖先前缀，`ArtFont_en` 这条会把任意子目录放行）与 `res_name_registered`（没登记就打印 ⏳ + 该重打哪个 AB）。🔴 **客户端 `_en` 加载不到会静默回退 `_zh`**（`Util.cs:1182-1224`，日志只有一行「回退加载精灵图」）⇒ 「图没生效」看起来就像「根本没写入」，别用图看不看得见来判断写没写，查 resName 是否进了 `resInfoList`。
- 🔴 克隆 Unity `.meta` 时 **guid 和 `spriteID` 都要换**：只换 guid 会让两份资源共用 spriteID，SpriteAtlas 打包变体会互相顶掉（早期 tab 01/02 的 meta 就是这么生成的，已留隐患）。
- 美术翻译链的 provider（2026-10-22 起）：`chatgpt_web`（job 默认，复用 `gen_chatgpt_web.py` 的 Chrome/AdsPower/额度台账，**不要**在 banner_translate.py 里再写一套换号）/ `local`（原像素工序，逐字节可回归）/ `manual`。🔴 喂模型的参考图必须**白底黑字**（透明 PNG 按白底预览＝白纸；深底白字会被交回**白底白字**废图）；出图回来只归位（抠墨迹→染纯白+alpha→等比 contain 进源 bbox），尺寸/位置/颜色别交给模型。🔴 断言量不出「这张图是不是这次的」：复用浏览器时 driver 曾把上一张交回来（按面积最大选图，同尺寸取第一个），必须靠 sha256 台账 `_output/art_translate/_gen_ledger.json`（`check_gen_reuse`）拒收。
- 🔴 **美术字写回 ≠ 生效**：`ArtFont_en/<同族>/<名>_en.png` 只让图就位；客户端真按语言切图还要求调用点走 `GetPictureFont`（`functions.lua`）＋ 该 `resName` 在 `ResourcePathConfig.asset` 有登记 ＋ 重打 AB，缺一步都白图。
- 🔴 **`GetPictureFont` 只对「名字带 `_zh` 后缀」的资源成立**：它按 `GetLan()` 拼 `_zh/_en/_jp`。图集里的中文原图大量是**无后缀**命名（`Atlas/LaddersTypePanelAtlas` 9 张里只有 1 张带 `_zh`），套上去中文/日文会拼出不存在的名字 ⇒ 图片整块变白。这类资源改用**条目上的显式字段**（如 `bgEn = "<名>_en"`，`GetLan()==1` 才换），且要在刷新时求值、别写进 require 期的表构造（`GetLan()` 依赖启动期全局）。
- 🔴 重建 AB = `BuildGameAssetBundles()` = `MarkGame(true)`，末尾会 `ResourcesPathEditor.CreateResourcePathConfig(true)` **整体重写 ResourcePathConfig**（索引重排）。所以手工追加的登记必须能在重扫中复现（目录进 `resPathList`、文件真存在），否则被静默删掉。子目录一目录一包靠 `BuildConfigs.asset` 的 `SubFloderOneBundle` 覆盖（`ArtFont_en`/`ArtFont_zh`/`Atlas` 都在里面）⇒ 新子目录不用改 BuildConfigs；AB 名 = `压缩类型小写/相对 ManagedResources 的路径`。

## 约定
- 巡检只读、量化分级；打包/校验/commit/push 可自行做，**送审/重启生产服/改线上部署先问**。
- 逐条 commit 且必须 push；中文 `type(scope): 摘要`；严禁 `git add -A`。
- 「都推了」= 两仓 `rev-list --count origin/<b>..<b>` 都为 0；push 前看有没有混进并行会话的提交。凭据一律 `.secrets/`（700/600）。
- 后台长任务 `Popen(..., start_new_session=True)`；zsh 下 `--include` 报 no matches（用 Grep）；GBK 源码 `grep -a`，`.jenkins/*.groovy`、`BuildConfigs.asset` 也被判 binary ⇒ 同样要 `-a`，否则静默返回空、白查。
- 🔴 并行会话共享工作区：**暂存完立刻 commit**（只 `git update-index` 不 commit，另一个会话提交时会连带带走你的改动）。要隔离对方未提交的改动：`git show HEAD:path` + 只套自己的改动造 blob → `git hash-object -w` → `git update-index --cacheinfo`，工作区仍保留对方改动。
- 改系统级状态须当场验证并标注「重启后是否有效」；打补丁先用 `git show HEAD:path`。
- UI「列表项逐格放大缩小」入场统一用 `Modules/Common/ItemPopIn`（配方/坑见 `docs/ui_item_pop_in_skill.md`），禁止各面板复写；只在「玩家主动换屏」播，数据回调刷新不播。列表项「从一侧滑入 + 底板淡入」走 `docs/ui_item_slide_in_skill.md`（承载节点选择表 + 11 坑 + 11 case 自证；已落地 BattlePass 任务卡 / DailyCarbon 副本卡）。🔴 参考 clip 的节奏（0.167/0.033）是**弹窗一次性入场**的，落在玩家反复触发的操作（切页签）上必然「太快」⇒ 打开 / 切页签分两套 preset，切页签另加 0.05s 整批延后起播躲开 `SetData` 那一帧，并挡连点叠播。`Util.GetGameObject` 按名字 **DFS** 找第一个同名节点，不是只找直接子节点 ⇒ 目标名必须整棵子树唯一。
- 复刻 `.anim` 走 `docs/ui_anim_reproduce_skill.md` 五阶段（S0 反解先出分镜表，`dump_clip.py` 读全 `m_*Curves`）。**TabBox 页签取列表必须读 `box` 子节点，`this.TabCtrl:GetTabList()` 常为空实例（第二次 Init 传 nil 提前 return，但 TabCtrl 已被覆盖）⇒ 静默不播**；例外：走 `Init_SetTabAndBox`（tab/box 显式传）的面板 `GetTabList()` 有值，可放心用（DailyCarbon 已落）；布局组占位时位移改写到子节点而不是放弃；`ScrollCycleView` 的 item 根 `anchoredPosition` 由 `SetData`/`SetItemIndex` 直接重写（同理写子节点）。🔴 `dump_clip.py` 只给节点名（`grid/item1`）、给不出业务语义 ⇒ **动手前先确认是哪张列表**，别拿面板里第一个像列表的东西开刀。
