# REF-client-ui —— 客户端 Lua / LuaBytes / UI / 登录链

> 从 `MEMORY.md` 迁出（2026-10-20），内容为原文，未删减。

## Lua / LuaBytes / UI
- 真机跑 `LuaBytes/<路径下划线化>_64.bytes` ⇒ **源码+字节码成对提交**；`scripts/lua-bytes-sync.sh`（`--check`），不加 `-g`。LuaJIT 必须与编码器同版本。
- 长跑协程必须 OnClose+OnDestroy 双停（`DestroyPanel` 不走 OnClose）；代次 token+先停后起；样例 `FirstRechargePanel:StartHeroLoop`。
- 面板被 `openedList` 缓存复用（`noDestory=false` ⇒ Close 只 SetActive(false)）；OnClose 清 lua 表 ≠ 清克隆节点 ⇒ 动态子节点 Build 前按名清一次；`#map` 对字符串键恒 0。
- 🔴 tolua fake-null：Destroy 后 userdata 仍非 nil ⇒ 判活只能 `IsNull()`/`tolua.isnull`（已三次崩溃）。`noDestory==0` 走 `DelayDestroyPanel`（15s×openNum）⇒ 异步回调有「已销毁」窗口，一律「判活+pcall+OnDestroy 清引用」。
- `Timer.New` 第 4 参缺省受战斗倍速影响，UI 停留传 `true`；同一元素定时器先 Stop 再 New。
- 🔴 红点绑定是面板级全局表 `BindObjs[rpType]`：「先 Clear 再 Bind」不幂等，首次进页签/`Initialize` 重置后 `pairs(nil)` 崩（`c7575f8c3` 收口）。
- 🔴 UI 动画：`docs/ui_anim_reproduce_skill.md`（S0 反解→S1 定阵营→S2 落地→三层验收）、浮空配方 `ui_panel_float_anim_skill.md`。铁律：读参考 clip 遍历**所有** `m_*Curves`；DOTween 与 `CommonButton` Animator 抢通道时临时 `enabled=false`。已落地 `ExpertPanel`/`OperatingPanel`（纯 Lua 动画，prefab 未改）；页签顺序取 `tabsContent` **子节点顺序**（prefab 里乱序）。

## 🔴 登录加载链（卡百分比必看）
- 现 **20 格**（`f79243431` 并行分组后）：15 串行步 + 4 并行组 + 1 末步，`maxValue=19`，百分比＝`int(curIndex/19*100)`，**已无 45% 这一格**（8→42%、9→47%）。旧口径 43 步/maxValue=42/45%=第 19 步好友聊天（对照历史日志用）。
- `addStep(name,fire)` / `addGroup(name,{member})` DSL。**加分组三条**：组内无数据依赖；**回包协议号互不相同**（C# `callbacks` 以 msgId 为 key，同号并发后注册的回调被丢）；只放纯展示数据。内部会再发一次的：`GetActivityAllRewardRequest`、`GetWorldArenaInfoRequest`（靠 `parallelBatch` 粘性）。
- 并发通道：`Network.parallelBatch>0` ⇒ `SendParallelMessage`（不进 `sendFuncQueue`、不动 `sendFlag`）；批次内报错只算该成员失败，不推进整链。
- 链只靠回调推进（无超时）⇒ 任一回调不来/抛错就永久停住；`sendFlag` 卡死会堵后续请求但心跳照走。已加 8s/格看门狗 + `Network:AbortPending`。
- 服务端 `ProtocolsManager.addEntry` 按 `userId % HANDLER_THREAD_NUM` 路由 ⇒ 同一玩家串行按序处理。
- 反证别用 `grep msgId=>16637`：聊天包故意不打日志。每步≈1 RTT（国内 102ms/欧洲 288ms），整链 ~12s vs ~4.5s，分组后理论 ~6s vs ~2s。

## 主动弹窗队列 PopupQueue（`Modules/Popup/PopupQueue.lua`）
- 四个登录弹窗（首充/拍脸/国家选择/至尊英雄）都是 `type=2`，UIManager 只递增 sortingOrder ⇒ 必须走 `PopupQueue.Push`/`PushSilent`，同一时刻只一个。
- 关闭后延迟 **0.15s** 才开下一个（还在 CloseStackPanel 收尾）；打开失败要让 `Push` 返回 false（CountryRank 靠它清占屏标记）。
- 🔴 **底屏闸门**（`d6df1fbcf`）：弹窗里点「前往」会先跳功能界面（如 OperatingPanel）再关自己，队列被这次关闭唤醒 ⇒ 只有栈顶是主界面（`BASE_SCREEN_NAMES`）或屏幕为空才放行，否则压着，等 `Recheck`（UI.OnClose/OnOpen + UIManager 收尾通知）放行。**压着不丢**：PlayerPrefs 的「已弹过」在 Push 时就写了。
- `UIManager.GetTopStackPanel()` 只认 `isOpened`（被全屏界面顶掉的旧面板不算）。
- 队列只管「主动弹出」；玩家点击触发的确认框不能入队。
- 测试：`scripts/lua-tests/test_popup_queue.lua`（30 项）；跑法见文件头（luajit + `TS_ROOT`）。

## 补充（2026-10-23 从 MEMORY.md 迁出，原文未删减）

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
