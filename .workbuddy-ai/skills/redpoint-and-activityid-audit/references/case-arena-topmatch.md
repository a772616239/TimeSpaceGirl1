# 案例二：竞技场「排行榜」红点（A + A2 + D 三合一）

用审计脚本扫出来的，症状和 page_3 同类：**红点不亮 / 关了别的界面后突然不亮**。

## 三个角色

```
ArenaTypePanel（BasePanel，UIManager 缓存）
 ├─ contents[1] = ArenaTypePanel_Arena        （无红点）
 └─ contents[2] = ArenaTypePanel_TopMatch     ← btnRank 上绑 Championships_Rank_Link
        ↓ 点 btnRank
    ArenaTopMatchPanel（BasePanel，UIManager 缓存）
        └─ tab 第 4 个（排行榜）上**也**绑 Championships_Rank_Link
```

## A2：子视图「初始化一次、关闭多次」

`Modules/Arena/ArenaTypePanel.lua`

```lua
L36  this.contents[i].view:InitComponent(...)    -- 在宿主 InitComponent 里，一辈子一次
L134 this.contents[oldSelect].view:OnClose()     -- 在 SwitchView 里，每次切页都调
L237 this.contents[i].view:OnClose()             -- 在宿主 OnClose 里，每次关面板都调
```

`Modules/Arena/View/ArenaTypePanel_TopMatch.lua`（原状）

```lua
L59  function this:BindEvent()
L71      BindRedPointObject(RedPointType.Championships_Rank_Link, this.btnRankRedpoint)  -- 一次性
L115 function this:OnClose()
L115     ClearRedPointObject(RedPointType.Championships_Rank_Link, this.btnRankRedpoint) -- 每次切页/关闭
```

⇒ 切到「竞技场」页签再切回「巅峰战」，`btnRank` 的红点就再也不刷新了；
关掉整个 ArenaTypePanel 再打开也一样（宿主 `OnShow` 里 `CheckRedPointStatus` 打了，
但 `BindObjs` 是空的）。

修法：绑定挪进 `OnShow`，先 Clear 再 Bind（`BindObject` 是 `table.insert`，不幂等）：

```lua
function this:OnShow(...)
    sortingOrder = 0
    if this.btnRankRedpoint then
        ClearRedPointObject(RedPointType.Championships_Rank_Link, this.btnRankRedpoint)
        BindRedPointObject(RedPointType.Championships_Rank_Link, this.btnRankRedpoint)
        CheckRedPointStatus(RedPointType.Championships_Rank_Link)
    end
    ...
```

## A：TabBox 适配器绑在「一次性」路径上

`Modules/ArenaTopMatch/ArenaTopMatchPanel.lua`（原状）

```lua
L61 function ArenaTopMatchPanel:BindEvent()
L64     this.TabCtrl = TabBox.New()
L65     this.TabCtrl:SetTabAdapter(this.TabAdapter)
L67     this.TabCtrl:Init(this.tabbox, _TabData)      -- ★ Init 在 BindEvent 里，只跑一次
L124 function ArenaTopMatchPanel:OnClose()
L124     ClearRedPointObject(RedPointType.Championships_Rank_Link)   -- ★ 不传 obj，清全局
L160 function this.TabAdapter(tab, index, status)
L161     if index == 4 then
L161         BindRedPointObject(RedPointType.Championships_Rank_Link, Util.GetGameObject(tab, "redpoint"))
```

`TabAdapter` 只被 `TabBox:Init` 调用，而 `Init` 在 `BindEvent` 里 ⇒ 一辈子绑一次；
`OnClose` 每次都清 ⇒ 关一次就死。`OnShow` 里的 `TabCtrl:ChangeTab()` 不会重跑 `TabAdapter`
（`ChangeTab` 只换选中态 + 回调）。

修法：记住那个页签节点，`OnShow` 里补绑。

```lua
L154 function this.TabAdapter(tab, index, status)
        ...
        if index == 4 then
            this._rankRpObj = Util.GetGameObject(tab, "redpoint")
            this:RefreshRankRedPoint()
        end

function this:RefreshRankRedPoint()
    if not this._rankRpObj or IsNull(this._rankRpObj) then return end
    ClearRedPointObject(RedPointType.Championships_Rank_Link, this._rankRpObj)
    BindRedPointObject(RedPointType.Championships_Rank_Link, this._rankRpObj)
    CheckRedPointStatus(RedPointType.Championships_Rank_Link)
end

function ArenaTopMatchPanel:OnShow()
    commonTitle:OnShow()
    this:RefreshRankRedPoint()          -- ← 补绑
    ...
```

## D：`ClearRedPointObject(type)` 不传 obj 会误伤别人

`ArenaTopMatchPanel:OnClose` 原来那句不带 obj 的 `ClearRedPointObject(type)` 会清空
**全局**该类型的绑定，包括 `ArenaTypePanel_TopMatch` 里 `btnRank` 的那一份。
所以「打开排行榜面板再关掉 → 回到竞技场，巅峰战页签的红点不亮」是这个 D 类造成的，
和 A2 是两条独立的死亡路径。

改成只解绑自己绑的那个节点：

```lua
function ArenaTopMatchPanel:OnClose()
    if this._rankRpObj and not IsNull(this._rankRpObj) then
        ClearRedPointObject(RedPointType.Championships_Rank_Link, this._rankRpObj)
    end
    commonTitle:OnClose()
    ...
```

## 验证

```bash
python3 .workbuddy-ai/skills/redpoint-and-activityid-audit/scripts/check_redpoint_binding.py
# A / A2 / B / C 应全部为「（无）」，只剩 D 类存量
```

字节码：`Modules_Arena_View_ArenaTypePanel_TopMatch_64.bytes`、
`Modules_ArenaTopMatch_ArenaTopMatchPanel_64.bytes`。

## 这类问题的通用信号

只要看到下面三个特征同时出现，基本就是本文这一类：

1. `BindRedPointObject` 出现在 `InitComponent` / `BindEvent` / `TabAdapter`；
2. `ClearRedPointObject` 出现在 `OnClose` / `OnHide` / `SwitchView`；
3. 中间没有任何「每次打开都会走」的补绑（`OnShow` / `OnOpen` / 每次 Open 的 `SubUIManager.Open`）。
