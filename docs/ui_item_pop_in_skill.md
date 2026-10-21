# 列表项入场：逐格「放大缩小」（Coin Master 式）

> 适用：TimeSpaceGirl1（Unity 6000.6.5f1）。礼包墙、奖励档位、任务列表这类
> 「ScrollCycleView + 卡片」的入场——卡片按版面顺序一张接一张弹一下。
> 唯一实现：`Assets/ManagedResources/~Lua/Modules/Common/ItemPopIn.lua`。
> 已接入：`ValuePackPanel`（礼包墙）、`GrowthManual_RewardPreview`、`GrowthManual_TaskPreview`；
> 页签多的三个面板走「页面级接入」：`ExpertPanel`、`OperatingPanel`、`AdjutantActivityPanel`
> （覆盖限定珍藏 / 积天豪礼 / 周月礼包 / **成长礼金 page_3** / **终身限购 page_9** / 战令 /
> 副官挑战 / 副官赠礼）；
> 固定版面（不是列表）走关键帧模式：`ThousandDrawPanel`（三张卡 + 剩余抽数四位，`phases`）。
> 更新时间 2026-10-21。流程/反解方法见 `ui_anim_reproduce_skill.md`，本文只讲这个配方的落地。

---

## 0. 一句话总则

**一个公共模块 + 三处接线，不许复制第二份。** 配方（缩放/时长/错开）只写在
`ItemPopIn.defaultCfg` 里；面板只负责「什么时候播、什么时候停」。
复制一份到新面板 = 下次调手感要改 N 处，且必然漂移（本项目已经吃过这种亏）。

---

## 1. 配方（缺省值）

| 项 | 值 | 说明 |
|---|---|---|
| `from` | 0.82 | 起始缩放。弹跳感主要来自这个落差，而不是峰值 |
| `peak` | 1.02 | 峰值，**受几何约束**（见第 4 节），不是手感参数 |
| `riseDuration` | 0.14s | 放大段，`OutQuad`（快起慢收，冲峰值） |
| `fallDuration` | 0.12s | 回落段，`InOutQuad`（两端切线为 0，落位不顿） |
| `step` | 0.055s | 相邻项错开 |
| `maxSpan` | 0.55s | 整体跨度上限，项多时自动压缩 step |

单张时间线：`t=delay` 起跳 → `+0.14s` 到峰值 → `+0.12s` 落回基准。5 张时总跨度 0.22+0.26 ≈ 0.50s。

- `step` 取 0.055：参考七日狂欢 clip 的页签节奏是「0.167s/格、错开 0.033s」，
  卡片比页签体量大一倍，节奏也放慢一倍，否则像抽搐。
- `maxSpan` 必须有：列表 20 项时按 0.055 会飘到 1.1s，玩家早滑走了还在弹。
  压缩后末项仍落在 0.55s 内（`step = maxSpan / (count-1)`）。

### 1.1 第二种手感：`duang`（弹性回弹）

列表墙要的是「逐格放大缩小」（两段、有明确峰值）；抽卡/开箱要的是「duang 一下」——
一次冲过头再抖回来。两者别混：

| 项 | `mode = "surge"`（缺省） | `mode = "duang"` |
|---|---|---|
| 曲线 | 基准 → `from` → `peak` → 基准（两段 tween） | 基准 → `from` → 基准（**一条** tween） |
| 缓动 | 放大 `OutQuad` / 回落 `InOutQuad` | `ease`（缺省 `OutElastic`，过冲由缓动自带） |
| 时长 | `riseDuration` 0.14 + `fallDuration` 0.12 | `duangDuration` 0.5 |
| 每格 tween 数 | 2 | 1 |
| 典型 | 礼包墙、奖励档位、任务列表 | 小图标、数字格、开箱 |

```lua
-- 小图标 duang 一下
local cfg = { mode = "duang", from = 0.6, duangDuration = 0.45, ease = "OutElastic" }
```

- `from = 0.5` 比 `surge` 的 0.82 更狠：`duang` 没有中间峰值，落差全靠起点。
- 过冲幅度由缓动决定（`OutElastic` 约冲过 1 的 5%~10%），**不需要也不该再设 `peak`**。
  想要「一冲到顶就停」就换 `ease = "OutBack"`（单次过冲，没有回抖）。
- `delay` 是**整批**延后：第二批比第一批晚 0.26s 起，同一个模块两份实例即可，不用手写 Timer。
- ⚠️ 大块头（卡面 ≥250px）别用 `OutElastic`：它的抖动周期是按比例给的，0.5~0.55s 内
  抖 3 个来回，观感是「闪一下」；拉到 0.8s 又变成软塌塌的果冻。**大块头改用 `phases`。**

### 1.2 第三种手感：`phases`（多段关键帧，慢速「浮起—按回—落定」）

`duang` 只有一个时长旋钮，越拉越拖沓；`phases` 把曲线拆成显式关键帧，段数、峰值、
每段时长、每段缓动都由调用方给——这是「想按设计稿调手感」时唯一该用的模式。

```lua
-- 千抽：三张卡（大块头）浮起—按回—落定
local kCardPhases = {
    { scale = 1.05,  duration = 0.38, ease = "OutCubic" },   -- 浮起（减速上升）
    { scale = 0.985, duration = 0.24, ease = "InOutQuad" },  -- 按回（两端切线为 0）
    { scale = 1,     duration = 0.18, ease = "OutQuad" },    -- 落定
}
local kCardInCfg = { mode = "phases", from = 0.78, phases = kCardPhases, step = 0.11, maxSpan = 0.44 }

-- 数字格比卡片小，同配方压一档，整批晚 0.34s 起
local kNumberInCfg = { mode = "phases", from = 0.82, delay = 0.34, step = 0.06, maxSpan = 0.36,
    phases = { { scale = 1.04, duration = 0.24, ease = "OutCubic" },
               { scale = 0.99, duration = 0.14, ease = "InOutQuad" },
               { scale = 1,    duration = 0.10, ease = "OutQuad" } } }
```

| 约定 | 说明 |
|---|---|
| `scale` | **相对基准的倍数**（1 = 原大小），不是绝对缩放；`ScrollCycleView` 的 `itemGoScale≠1` 也对 |
| 首段延迟 | 只有第一段吃 `cfg.delay + order * step`，后段是链式的，不要再加 `SetDelay`（否则每段都卡一下） |
| 链的建立 | 每段在上一段的 `OnComplete` 里建 ⇒ 被 `Stop`/`Kill` 时链自动断，不会在已关闭的面板上补建 tween |
| 收尾 | 末段结束时把 `localScale` 吸附到基准，避免浮点残差（表现是「差一点点」的缩放） |
| 时长节奏 | **先长后短**（0.38 / 0.24 / 0.18）：浮起要看清、按回要能察觉、落定要干脆；反过来会像卡顿 |
| 峰值 | 受版面约束：卡 280 宽、相邻 −18 重叠时 1.05 已是上限（礼包墙 1.04 会直接顶出屏） |
| 缺 `phases` | 退回 `surge` 配方（不报错），所以 `mode` 和 `phases` 可以分开配 |

- `phases` 单卡总时长 0.8s 是**刻意比 `duang` 长**的：卡面有立绘，0.5s 内看不清；
  0.8s 刚好在「能看清」和「不催人」之间，玩家点开面板不会觉得在等动画。
- 想更慢就等比放大 `duration`（如 ×1.2），**不要**加段数——第 4 段开始就成了果冻。


---

## 2. 三处接线（照抄清单）

| # | 位置 | 代码 |
|---|---|---|
| ① | `InitComponent`（ScrollView 建好之后） | `this.popIn = ItemPopIn.New(function() return this.ScrollView end)` |
| ② | 列表数据灌完之后 | `this.popIn:Play()` |
| ③ | `OnClose` + `OnDestroy` | `this.popIn:Stop()` |

数据源（`getScrollView` 的返回值）认四种，都交给 `_Collect` 自己分流：

| 形态 | 场景 | 收集方式 |
|---|---|---|
| `ScrollCycleView` | 绝大多数列表 | `ForeachItemGO`，顺序 = 数据下标 |
| 容器 `GameObject/RectTransform` | 手工 `newObject` 克隆的列表 | 取 active 子节点（模板自己 `SetActive(false)` 天然跳过） |
| **Lua 数组 `{ go1, go2, ... }`** | 固定几格（千抽的 `card1..3`、终身限购的 `preList`） | 按数组顺序，元素 GO / transform 都收 |
| 空 / nil | 这页没列表 | no-op |

- 数组形态是给「容器里还挂着别的装饰/模板」的场景用的：**顺序自己定，模板天然不在里面**。
- `Play(only)` 只弹第 `only` 格（下标 = 收集顺序）：抽中一张牌就 `Play(number)`，
  别整墙重弹。

- ①传**函数**而不是实例：面板/子模块的 `ScrollView` 可能晚于本对象创建、也可能销毁重建。
- ②**必须在 `SetData` 之后**：`ForeachItemGO` 只认得已克隆出来的 item；提前调一格都不会动。
- ③🔴 **漏 `Stop` = 那一项永久停在 0.82 / 1.02 上**，下次进面板看起来像卡图。
  `Play` 内部也会先 `Stop`，所以重播不会叠加。

### 2.1 B 方案：页面级接入（页签多的面板用这个）

一个面板有十几个页签、每个页签一个内容页时，A 方案的「每页 3 行」就是几十行样板，
而且「哪些页签有列表」这份名单一定会过期。B 方案把找列表也交给工具：

| # | 位置 | 代码 |
|---|---|---|
| ① | 面板：`OnShow`（页内容 `OnShow` 之后） | `ItemPopIn.PlayPage(内容页)` |
| ② | 面板：页签点击回调（`OnTabChanged` / `ActivityRewardShow` 之后） | `ItemPopIn.PlayPage(内容页)` |
| ③ | 面板：`OnClose` + `OnDestroy` | `ItemPopIn.StopPage(内容页)`（多页就循环全停） |

`PlayPage` 会到页面对象里自己找长列表，**找不到就 no-op**（返回 0），所以：

- 不用维护「哪些页签有列表」的名单 —— 面板可以对每个页签无脑调用；
- 首次打开就停在这类页签时会播（`OnShow` 那条路径），满足「首发也要弹」；
- 扫描认三种挂法：实例字段（`self.scrollView`）、类表字段（`quick_class` 的 `local this = Class`）、
  `metatable.__index`；一页多个列表（周/月礼包两个 `ScrollView`）会全部接上；
- 手工克隆、不是 `ScrollCycleView` 的列表，页面实现 `GetPopInSource()` 返回**数据源**即可，
  三种形态都认（按这个顺序判定，别乱）：

  | 返回什么 | 收集方式 | 典型页 |
  |---|---|---|
  | 容器（`GameObject` / `Transform`，如 `taskList/viewPort/content`） | 取容器下 active 子节点，模板项自己 `SetActive(false)` 着天然跳过 | 积天豪礼 `ContinuityRechargePage` |
  | 数组（`{go1, go2}` / `{ItemView1, ItemView2}`） | 按数组顺序，只收 active 的；元素可以是 GO、Transform、ItemView | 达人活动 `Expert`、升级豪礼 `Expert_UpLv`、开服双倍 `OpenService`、限时兑换 `ExChange`、扭蛋池 `BoxPool` |
  | `ScrollCycleView` | 同自动扫描 | —— |

- **列表是异步建的也没关系**：`PlayPage` 这一轮扫到 0 个 item 时会按
  `kRetryDelays = {0.1, 0.25, 0.5}` 再扫三轮，扫到就播、一直扫不到就静默收工
  （`Expert_UpLv` / `BoxPool` 的 `OnShow` 要等数据回调才造 item，切页签是同步调 `PlayPage` 的）。
  `StopPage` 会让待跑的重试作废，不会在隐藏页上补弹一次。
- 绑定按页面缓存（弱表 key），第二次 `PlayPage` 复用第一次建的 popIn，`cfg` 只在首次生效。

---

## 3. 什么时候播、什么时候不播（本次三个面板）

| 面板 | 播的时机 | 不播的时机 |
|---|---|---|
| `ValuePackPanel` | `OnShow`（`SetDataList()` 之后） | 购买后 `SetDataList` 刷新——它不经过 `OnShow`，所以天然不重播 |
| `GrowthManual_RewardPreview` | `refresh(isTop, isAni)` 里 `isAni=true` | 领取奖励 / 余额变化等事件回调（`refresh(false,false)`） |
| `GrowthManual_TaskPreview` | 同上；切日/周/月 toggle 也是 `refresh(true,true)` | 同上 |
| `ExpertPanel` | `OnShow`、页签点击（`ActivityRewardShow` 之后） | `RefreshActivity`（活动开关 / 进度 / 5 点刷新 / 支付成功回调） |
| `OperatingPanel` | `OnShow`、页签点击（`OnTabChanged` 之后） | `RefreshActivity`（月卡 / 活动开关 / 战令解锁） |
| `AdjutantActivityPanel` | `PageTabCtrl:ChangeTab` 的回调（首开也走这条） | 无独立的事件刷新路径 |
| `ThousandDrawPanel`（phases） | `Init` 的网络回调末尾（数据到位、卡面填好之后） | 领奖后的整表刷新会重播——那是**新一局**，可以接受 |
| 抽中单张卡（phases） | 抽卡回调里 `SetCard` 之后 `PlayCardIn(msg.number)` | —— |

**TabBox 点击为什么自动就有动画**：`GrowthManualPanel.SwitchView` 里本来就会调
`contentScripts[index].view:OnShow(this)`，而两个子模块的 `OnShow` 都走 `refresh(true,true)`
⇒ 切页 = 重新灌列表 = 重新弹一轮，不需要在面板侧加任何代码。

🔴 判据只有一个：**「玩家主动换了一屏内容」才播；「数据回来了」不播**。
把 `Play` 挂到 `SetData` 或事件回调上，会让每次领奖、每次金币变动都重整列弹一遍。

> 首开时会连播两次：`OnOpen` 调了一次 `view:OnShow`，`OnShow → TabCtrl:Init` 的回调又调一次。
> 两次在同一帧里（`OnOpen`/`OnShow` 由 `UIManager.OpenPanel` 同步调用），中间没有渲染间隙，
> 所以视觉上只有一次。**跨帧连播才需要去抖**，这里不需要。

---

## 4. 峰值上限怎么算（先量几何，再定手感）

`peak` 不是纯手感参数。卡片围绕自身中心缩放，峰值时左右各外扩：

```
每侧外扩 = (item宽 × peak - 视口宽) / 2
```

再确认**链路上有没有 Mask**——有 Mask 就随便 overshoot，没有就是直接画到屏幕边上。

| 面板 | item 宽 | 视口宽 | 每侧余量 | peak=1.04 时 | 结论 |
|---|---|---|---|---|---|
| `ValuePackPanel` | 1062 | 1080 | 9px | 越界 12.2px/侧 | 峰值只能 1.02（严格不越界是 1.016） |

`ValuePackPanel` 的实测取证（别靠猜，打开 prefab 看组件列表）：

- `Bg`：`anchorMin(0,0)-anchorMax(1,1)`、`sizeDelta(0,0)`、纯色 Image ⇒ **铺满全屏**，画布宽即 1080。
- `Bg/scroll`：**只有** `RectTransform + CanvasRenderer`，没有 Image/Mask。
- `ScrollCycleView` 根：Image（材质+颜色）+ 一个自定义脚本，**没有 Mask**。
- `ScrollCycleView/grid`：挂的是 **`GridLayoutGroup`（`m_Enabled: 0`，禁用）**。
  🔴 它有 `m_Padding/m_CellSize/m_Spacing` 字段，容易被误读成 `RectMask2D`（后者序列化也有 `m_Padding`）——
  判断依据是 `m_Script` 的 fileID 和有没有 `m_CellSize`，不是看有没有 `m_Padding`。

⇒ 结论：这套列表**全程无裁剪**，峰值必须按上面的公式卡死；item 越窄的面板（如 GrowthManual 的档位行）
允许把 `peak` 提到 1.04~1.06，用 `ItemPopIn.New(getter, { peak = 1.05 })` 覆盖即可。

---

## 5. 十四个坑（都在这套代码里踩过或躲过）

1. **Animator 抢缩放**：目标节点若挂 CommonButton 的 Animator（Normal 态是 1.1→1 的 pop），
   Animator 在 Update 之后求值，会把 DOTween 的缩放每帧盖回去——现象是「代码跑完了但没动」。
   本次的卡片根节点只有 `RectTransform + CanvasRenderer + Image`，没有 Animator，所以安全；
   换到别的节点前先 `GetComponent("Animator")` 看一眼，有就 `anim.enabled = false`（并在 Stop/OnComplete 恢复）。
2. **未激活节点不参与求值**：滚出可视区的 item 是 `SetActive(false)` 的，不跳过就会白占错开时间
   （表现为「前几张先弹、后几张要等半秒才弹」）。
3. **循环列表复用**：`ScrollCycleView` 回收 item，切页时是同一个 GO 重新绑定数据。
   每次都从基准缩放重新算，**不能累乘**（0.82² = 0.67，连点两次就缩成小图）。
4. **`Kill(false)` 不会回调 `OnComplete`**：回落段是建在放大段的 `OnComplete` 里的，
   中途 Stop 后不会补建——这是刻意的；但也意味着**别把复位以外的逻辑放进 `OnComplete`**。
5. **`Ease` 枚举取不到就被 pcall 吞掉**：tolua 的枚举是运行期注册的，统一走 `SetEaseSafe`，
   取不到就不设，绝不让整段动画因为一个枚举名失败。
6. **异常必须兜底**：`Play` 外层 `pcall`，失败就 `LogError` + `Stop()` 复位，
   绝不能把 item 留在半截缩放上（这类问题在真机上只能靠玩家截图发现）。
7. **`ForeachItemGO` 的顺序 = 版面顺序**，前提是 `fixedCount = 1`（单列）。多列时
   `index = j + (i-1)*fixedCount` 是按行优先填的，错开方向会变成「先竖后横」，需要自己按位置重排。
8. **`DelayCreation` 会把可收集项清零**：`GrowthGiftPage`（OperatingPanel 的 page_3）首开时
   调了 `DelayCreation(itemList)`，它先把刚 `SetData` 出来的 item 全部 `SetActive(false)`
   再每 10ms 开一个 ⇒ 面板随后调 `PlayPage` 时**一格都收不到**，表现就是「这页永远没动画」。
   两条路：删掉它（本项目的做法——逐格放大缩小本身就是逐行冒出来），或等它跑完再播（会叠两套）。
9. **容器模式会连模板一起弹**：`LifelongLimitBuy`（page_9）的 `rewardPre` 模板就挂在 `grid` 下，
   按容器扫会把模板算进去、在多出来的那一格上弹一下。这种页面让 `GetPopInSource()`
   **返回数组**（`preList`），不要返回容器。
10. **同一 key 的 item 复用 `ItemList` 缓存**：`ValuePackPanel` 用 `this.ItemList[go]` 存内层 ItemView，
    本模块只动 item 根节点的 `localScale`，不碰内层，两者互不影响——换面板时别把两者混在一起改。
11. **🔴 别在 tolua 的 userdata 上「探字段」**：GameObject 没有 `childCount` / `GetChild`，
    而 tolua 对**不存在**的字段是**抛错**（`field or property 'childCount' does not exist`），
    不是返回 `nil`。旧代码 `if container.childCount == nil then container = src.transform end`
    在真机上直接抛错 ⇒ 整段 `pcall` 失败 ⇒ **积天豪礼那页永远没动画**，日志每次切页刷一条错误。
    正确姿势：先 `SafeTransform(src)` 落到 `Transform` 再取子节点。
    ⚠️ 离线测试要么用 `newproxy` 造「探不存在字段就抛错」的替身（`test_itempopin_page.lua` case6b），
    要么这个坑在单测里根本复现不出来。
12. **异步建列表 ⇒ 必须重试**：`Expert_UpLv` / `BoxPool` 的 `OnShow` 在数据回调里才造 item，
    切页签那一刻 `_Collect` 必然 0 个。不要改成「在页面里回调时自己播」（会散成一堆样板），
    交给 `PlayPage` 的重试；重试必须带「轮次号」作废机制，否则关面板后还会在隐藏页上补弹。
13. **pivot 不在中心 ⇒ 缩放方向不对**：`DOScale` 是绕 `pivot` 缩放的。手工搭的模板 pivot 常是
    `(0,1)`（美术按左上角摆位），放大时就往**右下长**，看着像「左对齐 / 没居中」——
    OperatingPanel page_9（终身限购 `rewardPre`，pivot (0,1)、871×265）和 ExpertPanel 的
    `rewardPre1..10`、`ItemPre`（限定珍藏）都是这样。模块已内置 `CenterPivotOf`：播放时把 pivot
    临时挪到 `(0.5,0.5)` 并给 `anchoredPosition` 反向补偿 ½ 尺寸（视觉位置不动），**动画一结束
    （`Settle`）就还原**，打断时 `Stop` 也还原。
    - 补偿量 = `(0.5 - pivot) * rect.size`，用 `rect.width/height` 而不是 `sizeDelta`
      （拉伸态 rect 的 `sizeDelta` 不是真实尺寸）。
    - 父级是 `LayoutGroup` 也不会错位：Unity 的 `SetChildAlongAxis` 把 pivot 算进位置，
      重心挪过之后重建出来覆盖同一片区域。
    - 想保留模板原点（比如设计上就要「从底部长出来」）就传 `centerPivot = false`。
14. **pivot 补偿必须「动画结束就还原」，而且只能「相对撤」**（限定珍藏页签 25 踩过）：
    `ScrollCycleView` 的 `SetData` 是**按模板 pivot 写绝对值**
    （`anchoredPosition = (0.5-i)*itemHeight`），`ItemListOffset` 换格是**加偏移**。
    所以：
    - 留着居中 pivot 不管 ⇒ 下一次 `SetData`（买礼包 → `OnShowData`、切走再切回）写出来的位置
      少了那 ½ 尺寸补偿，整排卡片「啪」地跳半个卡宽，而且**回不来**（没人再帮你居中）。
    - 还原时写回开播那一刻记录的老位置 ⇒ 期间滚动换过格的 item 被拽回上一格；必须
      `anchoredPosition = 当前值 - 补偿量`，只撤自己加的那部分。
    - 动画结束 scale 已经回 1，此时还原 pivot 视觉上零变化，是最安全的时机；`Stop` 只兜打断的情况。


---

## 6. 自证（离线 → Editor → 真机）

**离线（不依赖 Unity，秒级）**

```bash
cd LuaEncoder/luajit_mac/64
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_itempopin.lua
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_valuepack_openanim.lua
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_growthmanual_openanim.lua
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_itempopin_page.lua
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_panel_listpopin_wiring.lua
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_thousanddraw_cardin.lua
```

| 用例 | 覆盖 |
|---|---|
| `test_itempopin.lua` | 公共模块 14 组：逐格时序 / 回落段 / 跳过隐藏 / 压缩错开 / Stop 复位 / 重播不叠加 / `itemGoScale≠1` 基准 / 异常兜底 / 自定义配方 / **数组源** / **duang 模式 + `Play(n)`** / **整批 `delay`** / **phases 关键帧链** / **偏心 pivot 居中 + 位置补偿** / **播完即还原（相对撤补偿、换格不拽回）** |
| `test_valuepack_openanim.lua` | 礼包墙：OnShow 顺序、跳过隐藏卡、购买刷新不重播、生命周期、`Play` 只有 1 处调用 |
| `test_growthmanual_openanim.lua` | 两个列表页：OnShow 播、`isAni=false` 不播、切页重播、OnClose/OnDestroy 回收、面板 `SwitchView` 仍走 `view:OnShow` |

| `test_itempopin_page.lua` | 页面级接入 10 组：实例/类表字段扫描、一页两列表、无列表 no-op、`StopPage` 复位、容器模式（`GetPopInSource`）、**userdata 容器（探字段会抛错的替身）**、绑定缓存、重播不叠加、**异步列表自动重试 + 重试作废** |
| `test_panel_listpopin_wiring.lua` | 三个面板接线：`OnShow` 有播（首开即列表页也会播）、切页签有播、`RefreshActivity` 不播、`OnClose`/`OnDestroy` 回收、积天豪礼声明 `GetPopInSource`；**成长礼金不再调 `DelayCreation`**、**终身限购返回 `preList` 数组**、**ExpertPanel 五个活动页各自的数据源（达人 / 升级豪礼 / 开服双倍 / 限时兑换 / 扭蛋池）** |
| `test_thousanddraw_cardin.lua` | 千抽：卡/数字数据源与顺序、整版入场（3+4 条、卡片错开 0.11、数字 0.34 起）、**三段关键帧链 0.78→1.05→0.985→1**、`PlayCardIn(n)` 只弹一张、`StopCardsIn` 复位、`OnClose`/`OnDestroy` 回收、数据到位才播、不再退回 `duang` |

六个用例都被 Jenkins `TS-Test-Lua` 自动发现（`tests/tests.json` 的 `tests_dir + pattern`），不用改配置。

**Editor**：打开面板看是否逐格；点 TabBox 切页看是否重播；**动画播到一半关面板再打开**（验证 Stop 复位）；
买一次礼包看是否整墙重播（应该不重播）。

**真机**：`scripts/lua-bytes-sync.sh` 已把源码同步成 `LuaBytes/*_64.bytes`，
但 LuaBytes 是打进 Lua AB 的 ⇒ 要么重打客户端资源（`TS-Client-Resources` / `TS-Resource-Build`），
要么走热更，否则真机还是旧行为。Editor 读 `~Lua/*.lua`，不受影响。

---

## 7. 接入新面板的最小 diff（复制这段改路径）

```lua
local ItemPopIn = require("Modules/Common/ItemPopIn")

function XxxView:InitComponent(go)
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, ...)
    this.popIn = ItemPopIn.New(function() return this.ScrollView end)
end

function XxxView:OnShow()
    this:RefreshList()          -- 内部会 ScrollView:SetData
    this.popIn:Play()           -- 🔴 必须在 SetData 之后
end

function XxxView:OnClose()   this.popIn:Stop() end
function XxxView:OnDestroy() this.popIn:Stop() end
```

---

## 7.1 页签多的面板（用 B 方案，示例）

```lua
local ItemPopIn = require("Modules/Common/ItemPopIn")

function Panel:GetContentPage()            -- 当前页签的内容页
    return self.contents[curIndex]
end

function Panel:PlayContentPopIn()          -- 找不到列表就 no-op，不用判断页签
    ItemPopIn.PlayPage(self:GetContentPage())
end

function Panel:StopContentPopIn()          -- 一个内容页可能被多个页签共用，全停
    for i = 1, #self.contents do
        ItemPopIn.StopPage(self.contents[i])
    end
end

function Panel:OnShow()
    this:OnTabChanged()                    -- 内部 OnShow 页内容 → SetData
    this:PlayContentPopIn()                -- 🔴 必须在页内容 OnShow 之后
end

-- 页签点击回调里也加一行 this:PlayContentPopIn()
-- OnClose / OnDestroy 里加 this:StopContentPopIn()
-- RefreshActivity（数据事件刷新）里**不要**加
```

---

## 8. 变更记录

- **2026-10-21** `c337ea8e7`：`ValuePackPanel` 首版（动画逻辑内联在面板里，`0.82→1.02→1`、错开 0.055s）。
- **2026-10-21**：抽出 `Modules/Common/ItemPopIn.lua`（每实例独立状态 + 可覆盖配方 + 异常兜底），
  `ValuePackPanel` 改为薄封装；`GrowthManual_RewardPreview` / `GrowthManual_TaskPreview` 接入，
  打开与 TabBox 切页都播；新增 3 个离线用例。
- **2026-10-21**：新增页面级接入 `ItemPopIn.PlayPage` / `StopPage`（自动扫页面里的长列表，
  认实例字段 / 类表字段 / `__index`，并支持容器模式 `GetPopInSource`）；`ExpertPanel` /
  `OperatingPanel` / `AdjutantActivityPanel` 三个面板接入，打开与切页签都播、数据事件刷新不播；
  `ContinuityRechargePage`（积天豪礼，手工克隆列表）补 `GetPopInSource`；新增 2 个离线用例。
- **2026-10-21**（本次）：补上 OperatingPanel 漏掉的两页（page_3 成长礼金去掉 `DelayCreation`、
  page_9 终身限购返回 `preList` 数组）；新增 `mode = "duang"`（单段 + `OutElastic`）、
  数组数据源、`Play(only)` 单格播放、`cfg.delay` 整批延后；`ThousandDrawPanel` 三张卡 + 剩余抽数
  接入 duang；新增 `test_thousanddraw_duang`，`test_itempopin` 扩到 12 组。
- **2026-10-21**（ExpertPanel 全页签收官）：`SafeTransform` 修掉「在 userdata 上探 `childCount`
  抛错」——这正是积天豪礼（页签 24）一直没动画的真因（`pcall` 把错误吞了，日志里只有一条
  `field or property 'childCount' does not exist`）；`PlayPage` 增加**异步重试**（`kRetryDelays` +
  轮次号作废）；五个活动页补 `GetPopInSource`：`Expert`（页签 7/9/10/11/12/13/14/15/16/17/19/20/21/22/26/27
  这些「达人」活动共用）、`Expert_UpLv`(23)、`OpenService`(31)、`ExChange`(8)、`BoxPool`(32)；
  至此 ExpertPanel 每个页签都有数据源（限定珍藏 25 靠 `ScrollCycleView` 自动扫描）。
  新增 `test_itempopin_page` case6b / case9，`test_panel_listpopin_wiring` 增加五页数据源断言。
- **2026-10-21**（千抽换手感）：`ThousandDrawPanel` 的卡片从 `duang`（0.5 → 1 + `OutElastic`，0.55s）
  改为 `phases` 三段关键帧 `0.78 → 1.05 → 0.985 → 1`（0.38 / 0.24 / 0.18 ≈ 0.8s，错开 0.11），
  数字格同步压一档并后移 0.34s；`ItemPopIn` 新增 `mode = "phases"`（`RunPhases`：链式建段、
  被 Kill 自动断链、末段吸附基准、`phases` 缺失退回 `surge`）；接口改名
  `PlayDuang/PlayCardDuang/StopDuang → PlayCardsIn/PlayCardIn/StopCardsIn`；
  `test_thousanddraw_duang` → `test_thousanddraw_cardin`，`test_itempopin` 扩到 13 组。
- **2026-10-21**（pivot 还原时机）：ExpertPanel 页签 25（限定珍藏）位置会跑偏。`CenterPivotOf` 原来
  一直留到 `Stop` 才还原，而 `ScrollCycleView.SetData` 按模板 pivot 写绝对值 ⇒ 买礼包 / 切走再切回
  时整排卡片跳半个卡宽；`Stop` 写回老位置还会把滚动换过格的 item 拽回上一格。改为 `Settle`
  （动画结束即还原）+ 相对撤补偿（`当前值 - 补偿量`），`Stop` 只兜打断。`test_itempopin` 加
  case14b/14c/14d（播完还原、滚动量保住、换格重播不拽回），仍为 14 组。
- **2026-10-21**（偏心 pivot）：OperatingPanel 页签 10（终身限购 page_9）的格子往右下长、像没居中——
  `rewardPre` 的 pivot 是 `(0,1)`，`DOScale` 绕 pivot 缩放。模块加 `CenterPivotOf`（临时居中 +
  `anchoredPosition` 补偿 ½ 尺寸、`Stop` 还原，`centerPivot = false` 可关），顺带修掉
  ExpertPanel `rewardPre1..10` 同样的偏心；`test_itempopin` 加 case14，扩到 14 组。
