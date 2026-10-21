# 列表项入场：从一侧「滑入 + 淡入」

> 来源：`Assets/Art/UIAni/cn2-X1_UI_TreasureStorePopup.anim`（`dump_clip.py` 反解）
> 落地：`Modules/BattlePass/BattlePassPanel_Mission.lua`（任务卡，反向从右侧滑入）
> 姊妹文档：`ui_item_pop_in_skill.md`（逐格放大缩小）、`ui_anim_reproduce_skill.md`（复刻 `.anim` 的方法论）

---

## 0. 一句话总则

**列表项/卡片从屏幕一侧滑回原位，同时底板 alpha 从 0.3647 淡到 1。**
所有位移一律写在 **item 的可视子节点**上，绝不写 item 根节点 —— 根节点的 `anchoredPosition`
在两种情况下会被系统重写：父级 `LayoutGroup` 重建、或列表组件自己算位置（`ScrollCycleView`）。
写子节点一次都不会被覆盖，因此也不需要「延迟一帧再播」这种补丁。

---

## 1. 参考 clip 的实际内容

`dump_clip.py` 文件头：`m_EditorCurves` 12 条 = `m_PositionCurves/ScaleCurves/EulerCurves` 3 条（空壳）
+ `m_FloatCurves` 9 条。**能用的只有 `m_FloatCurves` 里这 9 条**，总长 0.3667s。

| 路径 | 属性 | 起 → 止 | 时间 | 归类 |
|---|---|---|---|---|
| `Panel` | `m_AnchoredPosition.y` | -125 → 0 | 0 → 0.3667 | 弹窗本体 |
| `Panel` | `m_SizeDelta.y` | -250 → 0 | 0 → 0.3667 | 弹窗本体（底边钉死） |
| `Panel/Bg` | `m_LocalScale` | 1.1 → 1 | 0 → 0.3667 | 弹窗本体（回弹） |
| `Panel/Bg` | `m_Color.a` | 0.7765 → 1 | 0 → 0.3667 | 弹窗本体 |
| `grid/item1` | `m_AnchoredPosition.x` | -200 → 0 | 0 → 0.05 | **列表项** |
| `grid/item2` | `m_AnchoredPosition.x` | -150 → 0 | 0.05 → 0.1667 | **列表项** |
| `grid/item3` | `m_AnchoredPosition.x` | -100 → 0 | 0.1833 → 0.2833 | **列表项** |
| `grid/item1/Bg` | `m_Color.a` | 0.3647 → 1 | 0 → 0.2833 | **列表项底板** |
| `grid/item2/Bg` | `m_Color.a` | 0.3647 → 1 | 0.1333 → 0.25 | **列表项底板** |
| `grid/item3/Bg` | `m_Color.a` | 0.3647 → 1 | 0.2333 → 0.3333 | **列表项底板** |

三条读出来的规律：

1. **位移与淡入是两个独立通道**，淡入比位移长（0 → 0.2833 vs 0 → 0.05），所以视觉上「先到位、底色再追上」。
2. **逐格错开 ~0.05s**（item1 结束于 0.05，item2 起于 0.05），不是等间隔的整段均分。
3. **位移起点与格子宽度成比例**：item1 -200 / item2 -150 / item3 -100，宽 203 ⇒ 98% / 74% / 49%。
   越靠右的格子起点越近，读起来像「整排从左边涌进来」而不是「每格各自平移」。

前 4 条是弹窗本体的进出场。**如果目标面板是某个大面板的子页，这 4 条不要照搬** ——
子页没有独立底板，整页位移会和父面板的打开动画打架。

---

## 2. 配方（缺省值，改这两个数就够）

| 项 | 缺省 | 说明 |
|---|---|---|
| `kSlideFrom` | 260px | 起点位移。**按承载节点宽度换算**：参考是 203 宽的 73%~98%，取中间偏上 |
| `kSlideDuration` | 0.22s | 单卡时长。参考单格 0.05~0.12s 偏快，卡片大、要多给一点 |
| `kSlideStep` | 0.05s | 相邻 item 错开；一屏只有 1 张时不起作用 |
| `kFadeFrom` | 0.3647 | 底板 alpha 起点，直接抄参考 |
| `kFadeNode` | `"bg"` | 淡入节点：只有整卡大小的那张底板 Image，参考也只淡底板 |

位移量换算：`目标宽 × 0.30` 起步。太小学不出来（870 宽的卡给 140px 只有 16%，肉眼几乎看不出），
太大又会被 ScrollRect 的 viewport 裁掉一截。

**一套节奏不够用：打开和切页签要分开配。** 打开是一次性入场，0.22s 刚好；但玩家反复触发切页签时，
0.22s 会读成「一点就到位了，没看见动」，而且每帧位移大（260px / 0.22s ≈ 1180px/s），帧率一抖就明显跳格。
所以第二个落地起用两套：

| 场景 | 起点 | 单卡时长 | 错开 | 整批延时 |
|---|---|---|---|---|
| 打开面板 | 260px | 0.26s | 0.055s | 0 |
| 切页签 | 170px | 0.30s | 0.05s | **0.05s** |

切页签那 0.05s 不只是节奏 —— 它让「列表重建那一帧」的图标加载/文本排版先结束，动画第一帧不顶着卡顿跑
（现象：动画起手跳一下再走）。判断走哪套用现成的标记即可，别新加状态：`tabAnimReady`
（页签翻入是否播过）为 false 就是首次打开。

---

## 3. 方向（一行切换）

```lua
-- 从右侧滑入（起点在右，向左归位）
rect.anchoredPosition = Vector2.New(pos.x + kSlideFrom, pos.y)
-- 从左侧滑入（参考 clip 的原方向）
rect.anchoredPosition = Vector2.New(pos.x - kSlideFrom, pos.y)
```

`y` 一律不动。竖向列表不要改成上下滑 —— 会和滚动方向混淆，用户会读成「列表在跳」。

---

## 4. 承载节点怎么选（这张表决定要不要动这个面板）

| 容器 | 谁在重写 item 根位置 | 位移写哪 |
|---|---|---|
| `VerticalLayoutGroup` / `HorizontalLayoutGroup` | 布局重建（`SetActive`、`SetData`、改数据都会触发） | item 的子节点 |
| `ScrollCycleView` | `SetData` 与 `SetItemIndex` 里 **直接赋值** `item.tran.anchoredPosition` | item 的子节点 |
| `TabBox` 的 `box` | 布局组 + `TabBox:Init` 的 `Util.ClearChild` | tab 的子节点 |
| 手工 `newObjToParent` 的固定几格 | 无人重写 | 根节点或子节点都行，建议统一写子节点 |

⚠️ `ScrollCycleView` 这一条容易误判：它不是布局组，位置是**自己算的**
（`dragType==1` 时 `item.tran.anchoredPosition = Vector2.New(itemWidth*(j-1), (0.5-i)*itemHeight)`）。
所以「没有布局组 ⇒ 可以写根节点」是错的。

---

## 5. 什么时候播、什么时候不播

| 时机 | 播 | 理由 |
|---|---|---|
| 面板 `OnShow` | ✅ | 玩家主动打开 |
| 点页签 / 切页（`ChangeTab` 回调） | ✅ | 玩家主动换屏 |
| 领奖后 `RefreshAllTaskBtn` 重建列表 | ❌ | 数据回调刷新，重播会闪一下 |
| 战斗结算 / 扫荡 / 5 点刷新（`DailyCarbonPanel`） | ❌ | 同上，玩家没换屏 |
| 滚动（`SetItemIndex`） | ❌ | 列表自己重写位置，播了会卡顿 |

做法：模块级 `this.suppressTaskAnim` 标记，刷新路径里置 true 包一层，`SwitchView` 里判：

```lua
if this.suppressTaskAnim then
    this.StopSlideIn()      -- 🔴 抑制时也要 Stop，否则上一轮的 tween 会继续跑
else
    this.PlaySlideIn()
end
```

---

## 6. 代码骨架（复制改路径即可）

```lua
local kSlideFrom, kSlideDuration, kSlideStep, kFadeFrom = 260, 0.22, 0.05, 0.3647
local kSlideNodes = { "bg", "title", "reward", "mission", "Slider", "receiveOrGo" }  -- 卡的**可视子节点**
local slideItems = {}

function this.StopSlideIn()
    for i = #slideItems, 1, -1 do
        local it = slideItems[i]
        if Alive(it.tween) then it.tween:Kill(false) end
        if it.rect and it.x and Alive(it.rect) then
            it.rect.anchoredPosition = Vector2.New(it.x, it.y)     -- 🔴 必须复位
        end
        if it.graphic and it.color and Alive(it.graphic) then
            it.graphic.color = it.color
        end
        slideItems[i] = nil
    end
end

function this.PlaySlideIn()
    this.StopSlideIn()                       -- 🔴 重播先复位，否则从半截起
    local cards = CollectCards()             -- 列表组件给可见 item
    if #cards <= 0 then return 0 end
    local ok, err = pcall(function()
        for ci = 1, #cards do
            local card, delay = cards[ci], (ci - 1) * kSlideStep
            for _, name in ipairs(kSlideNodes) do
                local go = Util.GetGameObject(card, name)
                if Alive(go) and go.activeSelf then
                    local rect = go:GetComponent("RectTransform")
                    if Alive(rect) then
                        local pos = rect.anchoredPosition
                        rect.anchoredPosition = Vector2.New(pos.x + kSlideFrom, pos.y)
                        local t = rect:DOAnchorPosX(pos.x, kSlideDuration)
                        t:SetDelay(delay)
                        SetEaseSafe(t, "OutQuad")             -- 🔴 见下面的枚举坑
                        t:OnComplete(function()
                            if Alive(rect) then rect.anchoredPosition = Vector2.New(pos.x, pos.y) end
                        end)
                        slideItems[#slideItems + 1] = { rect = rect, x = pos.x, y = pos.y, tween = t }
                    end
                end
            end
            -- 底板淡入
            local bg = Util.GetGameObject(card, "bg")
            if Alive(bg) then
                local img = bg:GetComponent("Image")
                if Alive(img) then
                    local color = img.color
                    img.color = WithAlpha(color, kFadeFrom)
                    local t = img:DOFade(color.a, kSlideDuration)
                    t:SetDelay(delay); SetEaseSafe(t, "OutQuad")
                    t:OnComplete(function() if Alive(img) then img.color = color end end)
                    slideItems[#slideItems + 1] = { graphic = img, color = color, tween = t }
                end
            end
        end
    end)
    if not ok then
        LogError("SlideIn: 入场失败 " .. tostring(err))
        this.StopSlideIn()
        return 0
    end
    return #cards
end
```

`CollectCards` 两种取法（看容器是谁）：

```lua
-- ScrollCycleView：只给可见项，顺序即列表顺序
sv:ForeachItemGO(function(_, go)
    if Alive(go) and go.activeSelf then cards[#cards + 1] = go end
end)
-- TabBox：读 box 的子节点（不要用 GetTabList()，见 §7）
local box = Util.GetGameObject(this.tabBox, "box").transform
for i = 0, box.childCount - 1 do ...
```

---

## 7. 十一个坑（都在这套代码里踩过）

1. **写 item 根节点 ⇒ 被抹回**。这是本配方的第一号坑，两种触发源（布局组 / 列表自己算位置）。写子节点根治。
2. **`ScrollCycleView` 不是布局组也不能写根**。见 §4。
3. **一屏只有 1 张卡时「逐格错开」无意义**。`Open` 传 `fixedCount=1 / itemCount=1` 时，item 池就 1 个、反复复用，
   `kStep` 设多少都看不出差别；别以为错开没生效是 bug。
4. **重播必须先 Stop**。item 池复用，上一轮的终值就是这一轮的基准；不复位会从半截位置开始，且基准会逐轮漂移。
5. **`Stop` 必须连 alpha 一起复位**。只复位位置 = 卡片永久半透明（0.3647 的底色在白色列表上非常显眼）。
6. **`Alive` 判定要用 `IsNull`**。tolua 的 fake-null：`Destroy` 之后既不是 `nil`、直接取字段还会抛错。
   `type(obj) == "userdata"` 才走 `IsNull`，纯 table（离线 harness 的替身）直接返回 true。
7. **`Ease` 枚举是运行期注册的**。`tween:SetEase(Ease.OutQuad)` 在某些启动顺序下 `Ease` 还是 nil，
   整段被 `pcall` 吃掉 ⇒ 静默不播。一律走 `SetEaseSafe`：取不到就跳过（用 DOTween 默认缓动）。
8. **`local type = {...}` 会遮住 `type()`**。`BattlePassPanel_Mission.lua` 里就有一张叫 `type` 的按钮样式表，
   `Alive` 一写就报 `attempt to call upvalue 'type' (a table value)`。表名不要用 `type`。
9. **`GetTabList()` 可能是空实例**。`TabBox:Init(tabBox, tabBoxData)` 第二次传 nil 时 `Init` 提前 return，
   但 `this.TabCtrl` 已经被换成了新实例 ⇒ `GetTabList()` 恒为空、照它拿列表会静默不播。**TabBox 一律读 `box` 子节点。**
10. **`Util.GetGameObject` 是按名字深度优先找第一个同名节点**（C# `FindChild`：先 `root.Find(name)`，
    再递归所有子节点），不是"只找直接子节点"。所以子节点重名就会拿错 —— `DailyCarbonPanel` 的卡里
    `GoBtn/sweep` 和 `Tip/sweep` 同名，若把 `"sweep"` 写进 `kSlideNodes`，第二张卡的 `Tip/sweep` 就会被当成
    `GoBtn/sweep` 一起移走。**`kSlideNodes` 里的名字必须在整棵子树里唯一。**
11. **连点会叠播，必须挡住**。上一轮没播完又来一次（连点页签、快速换页），现在的 `Play` 开头只
    `Stop` 再重播 = 列表刚重建完又堆一批 tween，body 会明显一顿。加个 `slidePlaying` 标记：播中再请求就
    **只复位、不重播** —— 复位到终值本来就是「立刻到位」，观感不比重播差。
    🔴 `Kill` 不会回调 `OnComplete`，所以播中标记只能在 `Stop` 里清 + 每条 `OnComplete` 计数减到 0 时清，
    两处都要有；漏一处会让后续所有入场被「当成播中」永久跳过。

---

## 8. 自证（离线 harness，不用等打包）

`scripts/lua-tests/test_battlepass_cardslide.lua`（8 case，可直接改路径复用）：

```bash
cd LuaEncoder/luajit_mac/64
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_battlepass_cardslide.lua
```

第二个落地有独立一份，改名字/节点即可（`DailyCarbonPanel`，一屏多卡、含未激活子节点跳过、外加
切页签节奏与连点保护，共 11 case）：

```bash
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_dailycarbon_cardslide.lua
```

必测的 8 条：

| # | 断言 |
|---|---|
| 1 | 起点：每个子节点 `x == 基准 + 260`，`y` 不动；底板 `alpha == 0.3647`；item 根不动 |
| 2 | 完成：位置与 alpha **精确**回到基准（`==` 而不是约等于） |
| 3 | 中途 `Stop`：存活 tween 为 0，位置/颜色全复位 |
| 4 | 多卡：相邻 `delay` 差 0.05 |
| 5 | 未激活 item 不参与（不白占一轮、不动它） |
| 6 | 空列表 / 无列表组件：返回 0，不抛错 |
| 7 | `OnClose` / `OnDestroy` 都回收（DestroyPanel 不走 OnClose，面板还会被 openedList 复用） |
| 8 | 抑制标记：`suppressTaskAnim = true` 时 0 条 tween，放开后正常 |
| 9 | 切页签那套：起点 `x + 170`、时长 0.30、整批 `delay = 0.05` |
| 10 | 连点：上一轮播中再请求，返回 0、0 条新 tween、位置已回终值 |
| 11 | `Stop` 之后 / 自然播完之后都能再次触发（证明播中标记没卡在 true） |

⚠️ 离线 harness 只能证明**逻辑**对。`DOAnchorPosX` / `DOFade` 在 tolua 的绑定要另外确认：

```bash
grep -rhno '"DO[A-Za-z]*"' Assets/Source/Generate/*.cs | sed 's/.*://' | sort -u
```

`DOAnchorPosX` 在 `UnityEngine_RectTransformWrap`、`DOFade` 在 Graphic 系、`DOScale` 在 `UnityEngine_TransformWrap`
—— 都有绑定才敢用。

---

## 9. 已落地

| 面板 | 对象 | 方向 | 起点 / 时长 |
|---|---|---|---|
| `TreasureStorePopup`（参考） | `grid/item1..3` | 左 → 右 | -200/-150/-100 / 0.05~0.10s |
| `BattlePassPanel_Mission` | 任务卡 `itempre`（一屏 1 张） | **右 → 左**（按要求反向） | +260 / 0.22s |
| `DailyCarbonPanel` | 副本卡 `Pre` → `item1..itemN`（一屏 ~5 张） | **右 → 左** | 打开 +260 / 0.26s / 错开 0.055；切页签 +170 / 0.30s / 错开 0.05 / 整批 +0.05 |
| `MapPanel` | HUD 贴边容器 9 个（见 §10） | **各自就近的那条边** | 56~96px / 0.26s / 错开 0.05（总 0.61s） |

---

## 10. HUD 环绕入场（2026-10-21，`MapPanel`）

**场景不同**：这份配方前三个落地都是「列表项从一侧进来」，`MapPanel` 是**进图后的 HUD**——
没有列表，只有贴四条边的容器。所以方向不能统一，**每个容器从它自己最近的那条边走**，
读起来才是「屏幕四周的东西一起收拢回来」，而不是「整块屏往左飞」。

`MapPanel` 的根节点原本**没有任何动画组件**（prefab 里只有 29 个按钮的 `CommonButton` Animator），
且容器数量/显隐随副本类型变，所以走 **Lua 驱动**（`MapPanel.lua` 顶部 `PlayHudSlideIn` / `StopHudSlideIn`），
prefab 一行没动。

**层级与方向**（`dump_prefab_tree.py --rect` 读出来的锚点决定方向，别照抄）：

| 节点 | 锚点 | 基准 pos | 方向 | 位移 | 读作 |
|---|---|---|---|---|---|
| `leftUp` | (0.5,1) 顶中 | (0,-190) | up | +64 | 关卡名从上方落下 |
| `endLessTitle` | (0.5,1) 顶中 | (0,-50) | up | +56 | 无尽标题（**只有无尽模式激活**） |
| `rightUp` | (1,1) 右上 | (446,-213) | right | +96 | 返回/背包/队伍从右边进 |
| `leftCenter` | (1,0) | (-80,638) | left | -88 | 排行/奖励从左边进 |
| `helpBtn` | (1,1) 右上 | (-109.5,-255) | right | +88 | 自带 Animator ⇒ 只写位置 |
| `rightDown` | (1,1) 右上 | (-28,-1242) | right | +96 | 技能/道具 |
| `centerDown` | 底边拉伸 | (0,0) | down | -88 | 时间/buff/返回从下方升起 |
| `btnJump` / `btnAutoJian` | (0.5,0) 底中 | (265,420/520) | down | -56 | 自带 Animator ⇒ 只写位置 |

**四个必须做对的地方**：

1. **方向由锚点定，不由「看起来在哪」定**。`leftCenter` 锚在 `(1,0)`（右下角）但 pos 是 `(-80,638)`
   —— 它在屏幕左侧竖直居中，所以走 `left`。按「锚点 x==0 才是左边」判断会把它写反。
2. **自带 Animator 的节点只写位置**。`helpBtn` / `btnJump` / `btnAutoJian` 都挂着 `CommonButton.controller`，
   它的 Normal 是单帧 `m_LocalScale = 1`；Animator 在 `Update` 之后求值 ⇒ 给它们写 scale 每帧被盖回去。
   代码里用 `HudHasOwnAnimator(go)` 自动判（`GetComponent("Animator")` 非空就跳过 scale 通道），不再手维护名单。
3. **未激活容器**（`endLessTitle` 在 prefab 里就是 `m_IsActive: 0`，由 `OnShow` 按副本类型 `SetActive`）
   **不能占错开位**：延迟按「可见序号」算，不是按表下标，否则会白空一格。
4. **闸门放 `OnOpen`，播放在 `OnShow` 末尾**。`OnShow` 在「从弹窗返回地图」时也会走（`BasePanel:OpenUI(IsBackOpen)`），
   直接在 `OnShow` 里播会让玩家每关一次背包就重看一遍入场；而 `OnOpen` 只在「进图/换层」走。
   做法：`OnOpen` 置 `needHudAnim = true`，`OnShow` 末尾判 `if needHudAnim then 清标记 + 播 end`。

**参数自证**：`0.26s` 单组、`0.05s` 错开、8 组可见时末组收在 `0.61s` —— 正好压在
`SetRoleShow` 那 1s 的地图镜头缩放里结束，不会拖到玩家开始走格子之后。

**验收**：`scripts/lua-tests/test_mappanel_hudslide.lua`（7 case 全过：起点方向 / 错开顺序 /
完成精确复位 / 中途 Stop 双复位 / 重播不叠加 / OnShow 闸门 / 缺节点不抛错）；
`LuaBytes/Modules_Map_MapPanel_64.bytes` 重编 `--check` 已同步。**AB 未重打**（Lua 改动走 LuaBytes，仍建议进包后真机复验一次）。

`DailyCarbonPanel` 是这套配方的**第二个落地**，也是第一个"一屏多卡"的场景，可以直接对照看：

- 6 个可视子节点 = `Bg` / `Title` / `Reward` / `GoBtn` / `Consume` / `Tip`（`Tip` 与 `Consume`、`GoBtn` 按
  "未解锁 / 可挑战 / 可扫荡"三态互斥显隐，所以每条 tween 都要先判 `activeSelf`）。
- 播放点在 `SetScroll` 里 `SetData` 之后 —— 一处覆盖 `OnShow`（`TabBox:Init_SetTabAndBox` 末尾会回调
  `ChangeTabCallBack`）与换页签两条路径，**不放**进每张卡的 `SetData`（滚动会逐张触发）。
- 数据刷新（战斗结算 / 一键扫荡 / 5 点刷新）也走 `SetScroll`，所以包了个
  `RefreshScrollSilently()`：置 `suppressCardAnim` → `pcall(SetScroll)` → **复位标记**。
  用 `pcall` 只为保证复位 —— 标记卡在 `true` 会让后面所有入场动画永久失效。

---

## 11. 变更记录

- 2026-10-21 首版。从 `ui_anim_reproduce_skill.md` 的「第四次复用」抽出成独立配方：
  第一版误把曲线落在 TabBox 的 13 个小页签上（曲线对、对象错），返工到任务卡后才定型；
  方向按要求改为从右侧滑入。
- 2026-10-21 第二个落地：`DailyCarbonPanel`（副本卡，一屏多卡、错开真正生效）。
  新增 §5 的数据刷新一行、§7 第 10 条（`Util.GetGameObject` 按名字 DFS，重名会拿错节点）、
  §9 的落地说明与 `RefreshScrollSilently` 写法（`pcall` 只为复位标记）。
- 2026-10-21 第三个落地：`MapPanel`（HUD，非列表）。新增 §10：方向由锚点定、
  自带 Animator 的节点只写位置（`HudHasOwnAnimator` 自动判）、未激活容器不占错开位、
  闸门放 `OnOpen` 而播放在 `OnShow` 末尾（否则每次关弹窗返回地图都重播）。
- 2026-10-21 复盘「切换太快 + 有点卡」：拆出**打开 / 切页签两套节奏**（§2）、切页签整批延 0.05s 起播
  躲开重建帧、加连点保护（§7 第 11 条）。同时把 `DailyCarbonPanel` 的页签翻入从参考的 0.167/0.033
  放慢到 0.21/0.045、切页高亮板单独给 0.26 —— 参考值适合一次性入场，放在玩家反复点的操作上偏快。

