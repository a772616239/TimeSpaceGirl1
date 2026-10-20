# 案例一：OperatingPanel page_3 领奖红点不消失 + 能重复领奖

报障原话：「OperatingPanel page_3 领奖红点没有消失，而且能重复领奖」。

`page_3` = 运营面板第 4 个页签（`TabToContent[4] = 3`）= 成长礼金
（`Modules/Operating/GrowthGiftPage.lua`）。

## 现象拆解

同一句报障里其实是**两个独立 bug**，修一个不会好：

1. 点「领取」后奖励弹窗出来了，但按钮还是可点状态、红点还在；
2. 关掉运营面板再打开，整个 page_3 的页签红点**永远不刷新**。

## 根因一：档位错配（B 类）

`GrowthGiftPage:RefreshShowData` 原来这么写：

```lua
-- 旧代码（GrowthGiftPage.lua:154 附近）
local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GrowthReward)
local singleRewardData = ActivityGiftManager.GetActivityInfo(activityId, data.Id)
local state = singleRewardData.state          -- ← 这里炸
```

- 页面有 5 个礼包档：`giftList[101..105]` → `GlobalActivity` 里 Type=6 的行
  （Id `6 / 601 / 602 / 603 / 604`，`OnShow` 里按 Id 排序后填进 `giftList`）；
- 列表按 `configInfo.ActivityId == giftList[curGiftsId]` 过滤，也就是说**当前页签的
  行属于哪一档是确定的**；
- 但 `IsActivityTypeOpen(type)` 返回的是「该 Type 下**最后开启**的那一档」
  （这里是 604），拿它去查第 101 档（活动 6）的任务 → `GetActivityInfo` 返回 nil →
  第 154 行索引 nil 直接抛错。

后果链：抛错 → `RefreshShowData` 中断 → 这一行永远渲染不出「已领取」态、按钮不置灰、
红点不隐藏；同时 `GetActivityRewardRequest(data.Id, 604)` 发上去，服务器
`AbstractActivity.takeReward` 校验 `sActivityRewardConfig.getActivityId() != id` →
抛 `CFG_NULL` → **奖励没发、状态没变**，于是可以一直点。

修法：

```lua
local activityId = data.ActivityId or ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GrowthReward)
```

行自带的 `ActivityId` 优先，`IsActivityTypeOpen` 只当兜底。这是 B 类的标准修法。

## 根因二：绑定生命周期断裂（A 类）

`Modules/Operating/OperatingPanel.lua` 原来：

```lua
function OperatingPanel:BindEvent()      -- 一辈子只跑一次
    this:BindRedPoint()                  -- 里面 BindRedPointObject(...)
end

function OperatingPanel:OnClose()        -- 每次关闭都跑
    this:ClearRedPoint()                 -- 里面 ClearRedPointObject(type) 不带 obj
end
```

关闭一次 → `BindObjs[203]` 被清空；再打开只走 `AddListener → OnShow`，**不会补绑** →
`BindObjs[203]` 是空表 → 值再怎么变，`RefreshRedObjectStatus` 一条 `SetActive` 都打不出来。

日志铁证（真机）：

```
[RedPoint] CheckRedPoint node=203 func_result=true value=1 oldValue=1 skip refresh
[RedPoint] RefreshRedObjectStatus type=203 state=0
（之后既没有 SetActive= 也没有 No BindObjs —— 空表）
```

修法（`OperatingPanel.lua`）：

- `BindEvent` 里删掉 `this:BindRedPoint()`；
- `OnShow` 里补 `this:BindRedPoint()`（在 `this:CheckRedPoint()` 之前）；
- `BindRedPoint` 加幂等守卫 `if self._redPointBound then return end`，
  `ClearRedPoint` 里把 `_redPointBound` 置回 false。

## 顺手修的两处

- `RefreshGiftData` 的排序比较器：`info_a and info_a.state or 0`，避免任何一行缺数据
  就整列表刷新中断（原来一个 nil 就能让「领完奖红点还在、按钮还能点」）；
- 领取按钮：闭包级 `claimed` + 5 秒 `claiming` 冷却，双击不会发两笔请求；
  回调里主动 `ActivityGiftManager.SetActivityInfo(activityId, data.Id, 1)` +
  `redPoint:SetActive(false)` + `CheckRedPointStatus(RedPointType.GrowthGift)`，
  再判断是否本档全领完（全领完才 `RefreshData`，否则只 `RefreshGiftData`）。

## 回归

`scripts/lua-tests/test_operating_growth_claim.lua`（23 条断言）用桩驱动真实源码，覆盖：

| 段 | 覆盖点 |
|---|---|
| [1] | activityId 取行自带的档位，不再用 `IsActivityTypeOpen` 的返回值 |
| [2] | 双击只发一笔请求 |
| [2b] | 5 秒冷却后允许重试 |
| [3] | 缺任务数据时列表刷新不崩 |
| [4] | 面板关闭后重开能重新绑红点 |

旧源码跑这个用例会在 `GrowthGiftPage:154: attempt to index local 'singleRewardData' (a nil value)` 挂掉，
新源码 23/23 通过 —— 这就是「先红后绿」的证据。

## 提交

- `7a0584178` fix(client): 运营面板成长礼金领奖 + 红点
- `ab1e8b78a` test(lua): 成长礼金领奖回归用例
- 字节码：`Modules_Operating_GrowthGiftPage_64.bytes`、`Modules_Operating_OperatingPanel_64.bytes`
