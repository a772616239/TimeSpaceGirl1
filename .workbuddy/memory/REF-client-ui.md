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
