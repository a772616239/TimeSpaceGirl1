# 存量清单（2026-10-20 审计结果）

基线：`A=0，A2=0，B=0，C=0，D=19`。A/A2/B/C 已清零，改代码时**不要让它再涨**。

## D 类：`ClearRedPointObject(type)` 不传 obj（19 处，待评估）

判断标准：该 `rpType` 有 ≥2 个文件在绑，其中一个用「不传 obj」的方式清空，
就会顺手把别人的绑定清死。**不一定都是 bug**——如果那几个文件永远不会同时活着，
或者清空方就是唯一所有者，那没问题。逐条确认「是否可能同时存活」。

| 文件 | 行 | rpType | 同时绑定方 |
|---|---|---|---|
| `Modules/Mission/MissionDailyPanel.lua` | 144 | `Achievement_Main` | 2 |
| `Modules/Arena/View/ArenaMainPanel_ArenaView.lua` | 169 | `Arena_Record` | 2 |
| `Modules/Arena/View/ArenaView.lua` | 150 | `Arena_Record` | 2 |
| `Modules/Expert/ExpertPanel.lua` | 328 | `BoxPool` | 2 |
| `Modules/Expert/ExpertPanel.lua` | 326 | `ContinuityRecharge` | 2 |
| `Modules/ActivityGift/CourtesyDressPanel.lua` | 529 | `CourtesyDress_Chapter` | 2 |
| `Modules/ActivityGift/View/SevenDayGift.lua` | 438 | `CourtesyDress_Chapter` | 2 |
| `Modules/ActivityGift/CourtesyDressPanel.lua` | 527 | `CourtesyDress_Online` | 2 |
| `Modules/ActivityGift/View/SevenDayGift.lua` | 436 | `CourtesyDress_Online` | 2 |
| `Modules/ActivityGift/CourtesyDressPanel.lua` | 528 | `CourtesyDress_SevenDay` | **3** |
| `Modules/ActivityGift/View/SevenDayGift.lua` | 437 | `CourtesyDress_SevenDay` | **3** |
| `Modules/Expert/ExpertPanel.lua` | 305 | `CourtesyDress_SevenDay` | **3** |
| `Modules/AlameinWar/AlameinWarPanel.lua` | 156 | `Culturalrelics` | 2 |
| `Modules/Operating/OperatingPanel.lua` | 307 | `EveryWeekPreference` | 2 |
| `Modules/Operating/OperatingPanel.lua` | 308 | `EveryMonthPreference` | 2 |
| `Modules/Operating/WeekMonthGiftPackPage.lua` | 356 | `EveryWeekPreference` | 2 |
| `Modules/Operating/WeekMonthGiftPackPage.lua` | 357 | `EveryMonthPreference` | 2 |
| `Modules/Compound/CompoundPanel.lua` | 204 | `ResearchInstitute_RingCompound` | 2 |
| `Modules/Compound/view/CompoundPanel_CombatPlan.lua` | 475 | `ResearchInstitute_RingCompound` | 2 |

优先看「3 个绑定方」的三条：`CourtesyDressPanel` / `SevenDayGift` / `ExpertPanel` 共用
`CourtesyDress_SevenDay`，任一界面关闭都会把另外两个的绑定清掉。

已修的一条（不在上表里）：`Modules/ArenaTopMatch/ArenaTopMatchPanel.lua` L124，
改成只解绑自己记下的 `_rankRpObj`。详见 `case-arena-topmatch.md`。

## B 类残留缺口：红点只覆盖「最后一档」

`Modules/Operating/OperatingManager.lua` L250-271 `GetGrowthRedPointState`：

```lua
local openId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GrowthReward)
if openId then
    for _, configInfo in ConfigPairs(actRewardConfig) do
        if configInfo.ActivityId == openId then          -- 只遍历最后一档
            local activityInfo = ActivityGiftManager.GetActivityInfo(openId, configInfo.Id)
            ...
```

内部是自洽的（过滤和查询用同一个 `openId`），所以审计脚本不报 B。
但页面 `GrowthGiftPage` 能翻到 101~105 五档并从任意一档领奖
（领奖用行自带的 `data.ActivityId`），所以：

- 若运营同时开多档（`GlobalActivity` 的 `OpenRules` 允许），更早档位有奖可领时**红点不亮**；
- 若永远只有一档同时开着，则无影响。

改之前先确认 `GlobalActivity` 里 Type=6 各行的 `OpenRules`
（`2#10#999`、`3#6`、`3#601`、`3#602`、`3#603`）的语义是否保证「一档一开」。
确认是「一档一开」的话，这条可以标注为「设计如此」并在此归档。

## 已知非问题（不要误改）

- **`View/BtView.lua`**：`BindEvent` 绑、`OnClose` 清，看着像 A 类。但所有会关它的宿主
  都是「`InitComponent` 里 `SubUIManager.Open` 一次、`OnDestroy` 里 `Close` 一次」，
  绑和清都是实例级，配平。审计脚本已按宿主配对自动豁免。
  （例外：`Modules/Map/TrialMapPanel.lua` L85 只 Open 不 Close，属于对象泄漏，与红点无关。）
- **`Modules/Chat/BattleChatPanel.lua`、`ChatSelectChannelPopup.lua`、
  `FightView/FightPointMapChatPanel.lua`**：`TabAdapter` 里绑、从不清理。
  它们的 `TabBox:Init` 在 `BindEvent` 里（一辈子一次），tab 节点重建时旧节点被
  `Util.ClearChild` 销毁，`RefreshRedObjectStatus` 会跳过 `IsNull` 的残留，
  `ClearNullReference` 也会定期清。属于轻微累积，不是「红点不亮」。
