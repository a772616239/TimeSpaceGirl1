# 生命周期：三个管理器到底什么时候调谁

所有红点 bug 的根都在这里。改审计脚本或改业务代码前先对齐这张表。

## 1. UIManager.OpenPanel —— 面板会被缓存复用

`Framework/Manager/UIManager.lua`

```
L419  local action = function(panel)
L422      if not panel then panel = this.openedList[uiConfig.id] end   -- 缓存
L425      if not panel then
L426          panel = reimport("Modules/"..uiConfig.script)
L427          this.openedList[uiConfig.id] = panel
L428          needTrans = true
L433          panel:CreateUI(gameObject)        -- 只有这里才走 CreateUI
```

⇒ 同一个面板第二次打开，**不会再 CreateUI**，也就不会再跑 `Awake/InitComponent/BindEvent`。

## 2. BasePanel —— CloseUI 不销毁

`Base/BasePanel.lua` 顶部注释就是结论：

```
L1  --- 初次打开流程 Awake->InitComponent->BindEvent->AddListener->OnOpen->OnShow
L2  --- 再次打开流程 AddListener->OnShow
```

| 方法 | 行 | 做什么 | 频率 |
|---|---|---|---|
| `CreateUI` | L14 | Awake → InitComponent → BindEvent | **一辈子一次**（除非 DestroyUI） |
| `OpenUI` | L40 | AddListener（仅首次）→ OnOpen → OnShow | 每次打开 |
| `CloseUI` | L73 | RemoveListener → OnClose | 每次关闭，**对象留在 openedList** |
| `DestroyUI` | L94 | OnDestroy | 只有销毁时 |

关键结论：**`OnClose` 是可重复发生的，`InitComponent/BindEvent` 不是。**

## 3. SubUIManager —— 每次 Open 都是新对象

`Framework/Manager/SubUIManager.lua`

```
L23  function this.Open(config,parent,...)
L24      local view = reimport(config.script)
L25      local gameObject = createPanel(config,parent)   -- Instantiate 新的
L29      local sub = view:New(gameObject)
L34      sub:Awake() / L37 InitComponent / L40 BindEvent / L43 AddListener / L49 OnOpen
L56  function this.Close(sub)
L62      sub:RemoveListener()  L68 sub:OnClose()      -- **不销毁 GameObject**
```

⇒ 子视图（`View/BtView`、`SubUIConfig.*`）每次 `SubUIManager.Open` 都会重跑
`InitComponent/BindEvent`，所以「绑在 BindEvent + 清在 OnClose」对它们**是安全的**——
前提是宿主每次都 Open 一次。宿主只在 `InitComponent` 里 Open、却在 `OnClose` 里 Close 的，
就退化成 A 类。

**另一类子视图（contents 表驱动）不走 SubUIManager**：

```lua
-- Modules/Arena/ArenaTypePanel.lua
L15  this.contents = { [1] = {view = require(...), panelName = ...}, ... }
L36  this.contents[i].view:InitComponent(...)   -- 在宿主 InitComponent 里，一辈子一次
L134 this.contents[oldSelect].view:OnClose()    -- 在 SwitchView 里，每次切页都调
L237 this.contents[i].view:OnClose()            -- 在宿主 OnClose 里，每次关面板都调
```

⇒ 这类子视图的 `InitComponent` 是「一次性」的，`OnClose` 是「可重复」的，
**和 BasePanel 的 A 类完全同构**。`ArenaTypePanel_TopMatch` 就是踩了这个。

## 4. TabBox —— 适配器的执行频率取决于 `Init` 写在哪

`Modules/Common/TabBox.lua`

- `L131 Init` 末尾 `L212-214` 会调一次 `ChangeTabCallBack(SelectIndex)`
- `L165-205` 每次 Init 都 `Util.ClearChild(box.transform)` 然后重建所有 tab 节点，
  并对每个 tab 调一次 `TabAdapter(newTab, index, status)`

所以：

| 宿主写法 | 适配器频率 | 红点能不能绑在适配器里 |
|---|---|---|
| `TabCtrl:Init(...)` 在 `OnShow` | 每次打开都重跑 | ✅ 安全（ArenaTypePanel、ActivityMainPanel） |
| `TabCtrl:Init(...)` 在 `BindEvent` | 一辈子一次 | ❌ 关一次就死（ArenaTopMatchPanel 原状） |

审计脚本的 `tabbox_scope()` 就是按这个判的，别改成看 `SetTabAdapter` 的位置——
注册常在 BindEvent、Init 却在 OnShow，看注册点会误判。

## 5. 红点刷新链路

```
业务代码 CheckRedPointStatus(type)              Common/functions.lua L1587
  → RedpotManager.CheckRedPointStatus           Modules/Player/RedpotManager.lua L755
      → RPData:CheckRedPoint(type)              Modules/Player/RedPointData.lua L126
          值没变 → return false（L155-158，直接跳过刷新）
      → RefreshRedObjectStatus(type)            L784
          → 遍历 BindObjs[type]，逐个 SetActive(L793-795)
          → 递归父节点(L805-808)
```

`RefreshRedObjectStatus` 里三种日志对应三种状态：

| 日志 | 含义 |
|---|---|
| `[RedPoint] SetActive=true/false for type=N` | 绑定存在且对象有效，正常刷新 |
| `[RedPoint] bindObj is null` / `bindObj invalid` | 绑过，但 GameObject 已销毁（没解绑的残留） |
| `[RedPoint] No BindObjs for type=N` | **从来没有绑过** |
| （三者都没有，只有上一行 `RefreshRedObjectStatus type=N state=X`） | `BindObjs[N]` 是**空表** ⇒ A 类 |

最后一行是排 A 类的铁证：空表能进 `table.walk` 但一次回调都不会触发，所以一条日志都不打。
