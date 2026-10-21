# 参考动画复刻流程（反解 → 定阵营 → 落地 → 自证）

> 适用：TimeSpaceGirl1（Unity 6000.6.5f1）。场景是「看到一个已有的动画效果还不错，要在另一个面板复刻」。
> 本文是**流程**：怎么读、按什么顺序做、每步怎么自证。
> 配方数字、11 个坑的逐条展开、五个面板的落地记录在 `ui_panel_float_anim_skill.md`（下称「配方文档」）。
> 「列表项逐格放大缩小」（Coin Master 式）已抽成公共模块 `Modules/Common/ItemPopIn.lua`，
> 配方、几何约束（峰值上限）与八个坑见 `ui_item_pop_in_skill.md`。
> 更新时间 2026-10-20。来源：`ExpertPanel` 复刻 `SevenDayCarnivalPanelV2` 的开启动画（成功），以及
> 同一面板先做错方向又回滚的那一轮（失败，但教训都在第 8 节）。

---

## 0. 一句话总则

复刻只有两种失败方式，**两种都不报错**：

| 类型 | 表现 | 本次实例 |
|---|---|---|
| **A 类 · 读漏** | 交付时"看着像"，被人一眼指出少了一个元素 | 只读了 `m_ScaleCurves`，漏掉 `m_FloatCurves` 里「从上往下落 110px」的前摇 |
| **B 类 · 写空** | 曲线/代码都写了，运行时零效果，Unity 一声不吭 | 逐格缩放被 CommonButton 的 Animator 每帧盖回；未激活节点上的弹入卡在 scale 0 |

Unity 对下列情况**全部静默**，这是 B 类的土壤：

- 曲线 `path` 绑不上节点（只在 Animation 窗口标 Missing）
- 曲线写在一个未激活（`m_IsActive: 0`）的节点上（不参与求值）
- 曲线写的通道被另一层每帧覆盖（子级 Animator / 布局组 / DOTween / Lua 赋值）
- `Ease` 枚举取不到，异常被 `pcall` 吃掉（整段不播）

所以流程的每一步都要有一个**不依赖肉眼的判据**。肉眼看"没动"分不清是没挂上、挂错节点、还是被覆盖。

---

## 1. 流水线（五阶段，顺序不能换）

```
S0 反解 ──→ S1 定阵营 ──→ S2 落地 ──→ S3 离线自证 ──→ S4 三层验收 ──→ S5 收尾
```

| 阶段 | 输入 | 产物 | 跳过的后果 |
|---|---|---|---|
| S0 反解 | 参考 clip / controller / prefab / 参考面板源码 | **分镜表**（时间 × 部件 × 通道 × 起止） | A 类漏读，返工一次 |
| S1 定阵营 | 分镜表 + 目标 prefab + 目标源码 | 「静态 clip / Lua 驱动 / 混合」的判定 + 理由 | 方向错，整轮白做（本次第一版就是） |
| S2 落地 | 分镜表 + 阵营 | clip/controller/prefab 改动，或 Lua 驱动块 | — |
| S3 离线自证 | 落地产物 | 曲线条数/hash/首尾、harness 断言、字节码同步 | 只能等实拍，成本最高 |
| S4 三层验收 | — | 回读数据 + 截帧 + checklist | 遮罩露边、循环跳变、卡 scale 0 这类全漏 |
| S5 收尾 | — | commit / AB / 遗留资源决策 | 编辑器里好看、真机没变 |

**S0 没做完不要写一行代码。** 本次唯一的 A 类事故，就是"读了一半就开始写"。

---

## 2. S0 反解：把 `.anim` 读成"看得见的分镜"

### 2.1 遍历所有 `m_*Curves` 段，不是 grep 一个

以 `Assets/Art/UIAni/cn2-X1_UI_SevenDayCarnivalPanelV2.anim` 为例（9 条曲线）：

| 段 | 装什么 | 本次条数 |
|---|---|---|
| `m_PositionCurves` | 3D 局部位置 | 0 |
| `m_EulerCurves` | 旋转 | 0 |
| `m_ScaleCurves` | `m_LocalScale.x/y/z` | **7**（`day_1..7`） |
| `m_FloatCurves` | **`m_SizeDelta.*` / `m_AnchoredPosition.*` / `m_Color.a` / 任何非 Transform 浮点** | **2**（`bg`） |
| `m_EditorCurves` | 上面各段的**镜像**（Unity 序列化时两处都写） | **23**（按轴展开：7×3 + 2×1） |

```bash
S=.workbuddy-ai/skills/ui-panel-float-anim/scripts
python3 $S/dump_clip.py <clip.anim> [<clip2.anim> ...] [--keys]
# 每行一条曲线：段 / path / 通道 / 首末值 / 时长 / 关键帧数；末尾打各段条数 + 镜像条数
python3 $S/dump_clip.py <controller.controller>     # state 列表与各自绑的 clip
```

两条硬规则：

1. **`m_FloatCurves` 是主力段，不是边角料。** 所有"UI 上看得见的位移"（`anchoredPosition`）、
   "展开/收起"（`sizeDelta`）、"淡入淡出"（`m_Color.a`）都住在这里。只读 scale 等于只读了三分之一。
2. **用 `m_EditorCurves` 的条数当校验，但要按轴折算。** 向量曲线在镜像里按轴展开
   （`scale` 3 条、`rotation` 4 条、`float` 1 条），所以期望镜像数 = `Σ(轴数)`；
   对不上 ⇒ 还有段没读到，别往下走。（`m_EditorCurves` 里的属性名是 `m_LocalScale.x`，
   `m_FloatCurves` 里对应 `attribute` 是 crc32 数字，映射见配方文档 §4。）

### 2.2 三条几何推理（从数字到"哪条边在动"）

先取基准：`python3 $S/dump_prefab_tree.py <prefab> --depth 3 --rect`
（`--rect` 会打 `a(0,0)-(1,1) p(0.5,0.5)`，用来判定"四边拉满"和 pivot —— §2.3 全靠这两个值）。

| 通道 | 含义 | 判读 |
|---|---|---|
| `m_SizeDelta.y` | 四边拉满（anchorMin `(0,0)` / anchorMax `(1,1)`）时 = **比父级高多少** | 正值 = 上下某一侧溢出；配合 anchor/pivot 定是哪一侧 |
| `m_AnchoredPosition.y` | 锚点参考点相对父级中心的偏移 | pivot 0.5 时 = 中心相对父级的位移 |
| `m_LocalScale` | 自身缩放，**不等于**屏幕上的可见变化 | 父级缩放会叠乘；超出父级 rect 的部分被遮罩裁掉 |

**work through 本次那两条 `m_FloatCurves`：**

```
path=bg  m_SizeDelta.y        110 → 0    (0 → 0.3667s, 两端切线 0)
path=bg  m_AnchoredPosition.y  55 → 0    (同上)
```

- `sizeDelta.y = 110` + 四边拉满 ⇒ 上下各多出 55；`anchoredPosition.y = +55` ⇒ 中心上移 55
- 合起来：**底边不动（-55+55=0），顶边高出 110**（+55+55）
- 两条同时回 0 ⇒ 顶边落 110、中心落 55、底边钉死 = **从上方压下来的"前摇"**

这就是"一个元素从上往下启动"的全部信息。单看任一条都读不出这个结论——**必须两条一起解**。

### 2.3 「谁在动」≠「谁看得见」（最容易复刻错的一层）

参考里 `bg` 是个 **`m_Sprite: {fileID: 0}` 的全屏纯色遮罩**：它的 rect 变化被屏幕裁掉，
**它自己的位移肉眼完全不可见**。真正看得见的是挂在它下面那组内容（`finalTarget` / `curProgress`）跟着下了 55px。

> 结论：复刻时**不要照抄路径，要照抄几何**。本次目标面板 `bg` 同样是全屏黑遮罩 ⇒
> 把"落 110px"落到承内容的 `downLayout`（同样四边拉满、pivot 0.5、baseline `(0,0)`），
> 几何等价、而且看得见。抄 `bg` 会得到一个"代码在跑、屏幕上没动"的假交付。

判读顺序：① 这个节点有 sprite 吗（`m_Sprite.fileID == 0` ⇒ 纯色块）？② 锚点是四边拉满吗？
③ 它自己有可见内容吗？三个都是"否/无所谓"时，它的位移就是不可见的，要往下找承内容的子节点。

### 2.4 产出：分镜表（这就是唯一规格）

一行一个通道，行数必须等于曲线的**实际条数**（对不上说明还没读完）：

| t0–t1 | 部件（参考里的路径） | 通道 | from → to | 缓动 | 看得见吗 |
|---|---|---|---|---|---|
| 0–0.1667 | `bg/daysTabBg/tabsGroup/day_1` | `m_LocalScale.x` | 0 → 1 | 线性（切线 0） | 是 |
| 0.0333–0.2 | `day_2` | 同上 | 0 → 1 | 同上 | 是 |
| … | `day_3..7` | 同上 | 每格 +0.0333 | | |
| 0–0.3667 | `bg` | `m_SizeDelta.y` | 110 → 0 | ease-in-out | **否**（全屏遮罩） |
| 0–0.3667 | `bg` | `m_AnchoredPosition.y` | 55 → 0 | ease-in-out | 间接（子内容动） |

配套记三个全局量：**单格时长**（0.1667s = 10 帧 @60）、**错开**（0.0333s = 2 帧）、
**总长**（`0.1667 + 0.0333 × (n-1)`，n=7 时 0.3667s）、**循环**（`m_LoopTime: 1`）。

### 2.5 复刻前六问（每一行曲线都要过一遍）

| # | 问 | 命中后的动作 |
|---|---|---|
| 1 | 目标面板有同名同层级的节点吗？ | 没有 ⇒ 找等价节点（同锚点/同职责）或放弃该通道，**写进记录** |
| 2 | 这个通道归谁管？ | 布局组 / ScrollRect / `PlayFlyAnim` / 自身 Animator / 代码赋位置 ⇒ 换通道或换节点（见 §4.3） |
| 3 | 这个节点在 prefab 里是激活的吗？ | `m_IsActive: 0` ⇒ 不写 `0 → 1` 的弹入（会被 `SetActive` 打开时卡在 0） |
| 4 | 这个节点是运行时克隆的吗？ | prefab 里只有一个 `btn` 模板 ⇒ 静态曲线绑不上，走 Lua |
| 5 | 它在参考里看得见吗？在我这里看得见吗？ | 见 §2.3，必要时换承载节点 |
| 6 | 基准值是多少？ | 曲线写的是**绝对值**（不是增量）⇒ 用 `dump_prefab_tree.py` 取 prefab 实测值 |

> 第 6 条每年都有人踩：参考 `btnBack` 的 y 是 `73.5`，直接抄 `55 → 73.5` 是对的；
> 抄成 `0 → 18.5` 就变成"按钮往上跳 18.5"，因为曲线把绝对位置当成了偏移。

---

## 3. S1 定阵营：静态 clip 还是 Lua 驱动

先看**参考本身是怎么实现的**（`Animation` / `Animator` / 代码），再判断这些前提在目标面板还成不成立。

### 3.1 否掉静态曲线的五条判据（任一命中 ⇒ 走 Lua）

| # | 判据 | 证据怎么找 | 为什么静态曲线不行 |
|---|---|---|---|
| 1 | **运行时克隆，数量不固定** | prefab 里只有模板 `btn`；源码 `newObjToParent(pre)` + `name = "tab"..i` | 曲线绑的是具体路径，`tab8..tab32` 绑不上；数量变了也没法自适应 |
| 2 | **显示顺序由代码排序** | `SetSiblingIndex`（本次 `TabSort` 按 `ActivityGroups.Sort`） | 静态曲线的时序按路径硬编码，重排后"翻入顺序"和"屏幕顺序"不一致 |
| 3 | **激活态由代码切换** | `SetActive` 切十来个子页 | 未激活节点不求值；先写 `0→1` 弹入会卡在 scale 0 |
| 4 | **节点位置由代码赋值** | 源码有 `.localPosition =` / `.anchoredPosition =` | 动画每帧写回，把代码的赋值按回原位（多语言偏移、动态布局全废） |
| 5 | **时长/节奏要随数量自适应** | 参考 loop=1 常驻，目标面板"只播一次" | 静态 clip 的时长是固定的，无法按可见格数压缩 |

### 3.2 混合是常态

| 层 | 管什么 | 本次 |
|---|---|---|
| 静态 clip（Animator） | 固定骨架：遮罩 alpha、内容区弹入、呼吸循环 | 本次**撤销**（方向错，见 §9） |
| Lua 驱动 | 动态列表：逐格翻入、高亮板、内容区落位 | 最终形态全在这里 |

两者可以并存，但要**通道互斥**：静态 clip 写了 `downLayout.anchoredPosition.y`，Lua 就别再写它，
否则每帧互相抢（配方文档附录 B 记录了首充面板 `legacy Animation` 与 `PlayFlyAnim` 抢 `frame` 位置的抖动）。

### 3.3 意图差异要显式记录

参考 `m_LoopTime: 1`（常驻循环），本次只播一次——因为页签最多 32 个，一直翻很吵。
**这类偏离必须写进 commit message 与记录**，否则下一个人会以为是"没做完"。

---

## 4. S2 落地

### 4.1 静态路线：先 dry-run 再落盘

```bash
S=.workbuddy-ai/skills/ui-panel-float-anim/scripts
# ① 干跑：只产出 clip 到 /tmp，不碰 prefab
python3 $S/gen_float_anim_yaml.py --prefab <prefab> --base cn2-X1_UI_<面板>_float \
    --config $S/configs/<面板>.json --out-dir /tmp/x --no-prefab
# ② 解析 /tmp：条数、首尾同值、path/attribute 哈希、guid 链
# ③ 确认后落盘
python3 $S/gen_float_anim_yaml.py --prefab <prefab> --base cn2-X1_UI_<面板>_float \
    --config $S/configs/<面板>.json
```

第一次跑几乎总会在 dry-run 阶段暴露路径/锚点问题（`check_paths` 不通过就 `SystemExit`、不落盘）。
细节见配方文档 §3；**锚点只由层级决定**这一条是硬要求（prefab 里 `!u!95`/`!u!111` 的文件顺序与层级无关）。

### 4.2 Lua 路线：四块骨架，一块都不能省

```lua
-- ① 常量块：把分镜表的数字原样搬过来，别散落在函数里
local kTabFlipDuration = 0.167
local kTabFlipStep     = 0.033
local kTabFlipMaxSpan  = 0.5    -- 可见格多时压缩错开，整体不超过这个跨度
local kDropDuration    = 0.3667
local kDropOffsetY     = 110
local tabFlipItems     = {}     -- { tween=, tf=, anim= }
local dropTween        = nil

-- ② 判活：tolua fake-null，Destroy 之后既不是 nil 也不能取字段
local function FlipAlive(obj)
    if obj == nil then return false end
    if type(obj) == "userdata" then return not IsNull(obj) end
    return true
end

-- ③ 安全取枚举：Ease 表是运行期注册的，取不到就别设（否则异常被 pcall 吃掉、整段静默不播）
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then tween:SetEase(value) end
    return tween
end

-- ④ Play / Stop 成对，Stop 是唯一复位入口
function this.PlayTabFlipIn() ... end
function this.PlayTabSelectFlip(index) ... end
function this.PlayDropIn() ... end
function this.StopOpenAnims() ... end   -- 重播 / OnClose / OnDestroy / 出错回滚 都调它
```

四条硬规则（都是踩出来的，逐条对应一次事故）：

| 规则 | 原因 |
|---|---|
| **复位收口唯一**：`Play*` 第一行先 `StopOpenAnims()` | 重播时上一轮的 tween 还在跑 ⇒ 两个 tween 抢同一个 scale；中途关掉再打开会从半截位置起 |
| **`pcall` + 失败回滚**：异常时把已改的节点逐个复位 | DOTween 侧任何异常都不能把页签留在 `scale 0` / Animator 禁用态 |
| **临时禁用的 Animator 必须在 OnComplete 与 Stop 两处恢复** | 只恢复一处 ⇒ 那颗页签永久失去按下反馈（恢复后 Normal 写回 `scale=1`，与末值一致、不跳） |
| **`OnClose` 和 `OnDestroy` 都要调 Stop** | `DestroyPanel` 不走 `OnClose`；面板还可能被 `openedList` 缓存复用 |

### 4.3 通道归属：写之前先确认没人跟你抢

| 占用者 | 判据 | 你只能写 |
|---|---|---|
| `Horizontal/Vertical/GridLayoutGroup` | 自身或父级有 | **scale**（位置每帧重算） |
| `ScrollRect` 的严格后代 | 祖先链上有 | **scale**（位置归滚动） |
| `PlayFlyAnim`（DOTween） | 节点上有这个组件，看 `tweenSequeue[].targetObj` | **scale / alpha**（位置被它写） |
| 自身 Animator（`CommonButton`） | 该节点 `!u!95` 且 `m_Enabled: 1` | 它的 clip **没写**的通道；同一通道要么别写，要么先 `enabled = false` |
| Lua/代码赋位置 | 源码里 `.localPosition =` | 换承载节点（插空容器），或在代码里停掉赋值 |

`audit_panel.py` 会把上表前四类直接打成标记（`LAYOUT` / `SCROLL_DESC` / `PLAYFLY` / `OWN_ANIM`，
另有 `INACTIVE` / `MASK` / `LEGACY` / `CODE_POS`），开工前 60 秒跑一遍就不用靠事故来发现。

### 4.4 执行顺序：为什么必须临时禁用 Animator

Unity 每帧的顺序是 **`Update`（DOTween 默认在这里）→ Animator 求值 → `LateUpdate`**。

```
Update:   DOTween 写 localScale = 0.42
Animator: 求值 Normal 状态（单帧 clip，写 localScale = 1）   ← 覆盖
屏幕:     永远是 1
```

现象是「代码跑了、日志也有、页签没动」。所以：

```lua
if FlipAlive(anim) then anim.enabled = false end   -- 先关
tf.localScale = Vector3.New(0, 1, 1)               -- 起点
tf:DOScale(Vector3.one, kTabFlipDuration):SetDelay(order * step):SetEase(Ease.OutQuad)
    :OnComplete(function()
        if FlipAlive(tf)   then tf.localScale = Vector3.one end
        if FlipAlive(anim) then anim.enabled = true end   -- 后开
    end)
```

不推荐的替代方案：把 tween 挪到 `LateUpdate`、或改手动插值——与项目其他面板不一致，后人改不动。

### 4.5 时间轴对齐

- 网格/列表：`总长 = 单格时长 + 错开 × (可见格数 - 1)`
- 可见格数不定 ⇒ **压缩错开**而不是压缩单格时长：`step = min(kStep, kMaxSpan / (n-1))`
  （本次 24 格时 step 压到 0.0263、总长 0.667s；单格 0.167s 保持不变，观感才一致）
- 多个动画同时起时，注意谁是"先复位"的那个：本次 `PlayTabFlipIn()` 第一行 `StopOpenAnims()`，
  所以 `OnShow` 里必须 **先 flip 再 drop**，反了 drop 的 tween 会被刚起的 flip 杀掉
- 只播一次 vs 循环：参考循环、目标不循环时，Lua 用 `DOScale` 一次即可（不要用 `SetLoops`）

---

## 5. S3 离线自证（不启动 Unity 就能做的三件事）

### 5.1 静态产物解析

| 检查 | 通过标准 |
|---|---|
| 条数 / 时长 / 循环 | 与分镜表行数一致；`m_LoopTime` 0/1 与意图一致 |
| `path` / `attribute` 哈希 | 每条曲线都能在 `m_ClipBindingConstant.genericBindings` 找到对应项（`zlib.crc32`） |
| 首尾同值 | 循环 clip 的第一 key == 最后一 key |
| guid 链 | prefab → controller.meta → clip.meta 闭合 |
| prefab diff | 只有预期的那几处；新增 Animator 时对象数 **+1**，换 controller 时不变 |

### 5.2 Lua harness：假 DOTween 跑真源码

不启动 Unity 也能验"起了几条 tween、延迟序列对不对、Complete/Stop 后状态对不对、数量自适应、重播是否从起点"。

```bash
cd LuaEncoder/luajit_mac/64
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_expert_openanim.lua
```

现成样例：`scripts/lua-tests/test_expert_openanim.lua`（7 个 case，`ALL OK`）。
写法要点：

1. 假 `Util.GetGameObject` 返回一棵手搭的节点树（含 1 个模板 `btn` + 1 个 `activeSelf == false`，专门验"跳过"）
2. 假 `DOScale` / `DOAnchorPos` 返回**可手动 `Complete()` / `Kill()`** 的 tween 对象，记录 `delay` / `ease` / 归属节点
3. 断言用"节点状态 + tween 清单"，不要断言内部变量
4. 必测这 6 条：顺序与错开 / 完成恢复 / 中途 Stop 全复位 / 数量压缩 / 高亮板重播 Kill / 落位重播从起点

```lua
assert(#tweens == 4, "应只起 4 条（模板与 inactive 要跳过）")
assert(math.abs(tweens[2].delay - 0.033) < 1e-6)
for _, t in ipairs(tweens) do t:Complete() end
assert(item.tf.localScale.x == 1 and item.anim.enabled == true)
```

### 5.3 字节码同步（Lua 改动必做）

```bash
bash scripts/lua-bytes-sync.sh Assets/ManagedResources/~Lua/Modules/Expert/ExpertPanel.lua
bash scripts/lua-bytes-sync.sh --check        # 复验「已同步」
```

**必须 `bash`**（`sh` 会在脚本第 60 行失败）。真机跑的是 `LuaBytes/Modules_Expert_ExpertPanel_64.bytes`，
**只改源码不改字节码 = 真机不生效**；源码与字节码必须成对提交。

---

## 6. S4 三层验收（缺一层就有看不见的坑）

| 层 | 手段 | 能戳穿什么 | 成本 |
|---|---|---|---|
| ① 离线 | 5.1 / 5.2 | 条数不对、绑错、丢曲线、逻辑分支错 | 分钟级，落盘后立刻做 |
| ② Unity 回读 | `unity_bridge.py code '<C#>'` | 锚点错、路径缺失（假阳性）、状态默认值不一致 | 需要 editor，1~2 分钟 |
| ③ 实拍 | additive 场景 + `RenderTexture` 截帧 | **方向错、遮罩露边、循环跳变**——只有这一层能发现 | 最贵，但必须做 |

### 6.1 回读口径（第一次几乎必然假阳性）

```csharp
// 关键：missing 必须相对 animator.transform 算，不是 prefab 根节点
foreach (var b in AnimationUtility.GetCurveBindings(clip))
    if (anim.transform.Find(b.path) == null) miss++;
```

用根节点 `Find(path)` 恒为 true ⇒ `missing=0` 是假的（配方文档附录 C 的事故复盘）。
曲线 `path` 永远相对**它挂的那个 Animator 所在节点**。

还要读一次**状态默认值**：`start` 的末值必须等于 `normal` 的 WriteDefaultValues 值 / prefab 默认值，
否则 `start → normal` 切态会跳一下（本次 `bg` alpha 末值 1 = prefab 默认 1）。

### 6.2 实拍 checklist

- [ ] `t=0` 能看到场景色 → `t≈0.25` 已盖住 ⇒ 遮罩淡入生效
- [ ] 每一帧边缘**没有**一圈露底（露了 = 给无 sprite 的整屏块写了缩放）
- [ ] 「从上往下落」这类前摇，第 1 帧元素**在屏幕外/偏上**，末帧落回原位
- [ ] 循环 clip 的 `n=0` 与 `n=1` 逐项取值完全相同（不跳）
- [ ] 第一次打开有动画；关掉再开**符合预期**（面板缓存复用，可能不重播）
- [ ] 点按钮有正常按下态（没被子级 `CommonButton` 抢掉）
- [ ] 切页签 / 反复开关 10 次，没有节点卡在 `scale 0` 或位置错乱
- [ ] 中途关闭再打开，不会从半截位置起、不会残留 tween
- [ ] AB 重打后真机复验

---

## 7. S5 收尾

| 事项 | 做法 |
|---|---|
| commit 拆分 | 方向错误的回滚单独一条 `fix:`；功能一条 `feat:`；文档一条 `docs:` |
| AB 重打 | 新 clip/controller 是 prefab 的依赖，**不打资源包真机还是旧包**；做不了就显式写「待做」 |
| 遗留资源 | 不引用的 clip/controller 留在库里还是删，**问过再动**（本次留库不引用：`cn2-X1_UI_ExpertPanel_float.*`） |
| 台账 | 在配方文档补一节「附录 X：某面板落地」，含分镜表、产物路径、验收记录、偏离参考之处 |
| 本文 | 流程/判据变了就同步改这里；**文档与 `scripts/` 必须同改** |

---

## 8. 陷阱总表（按阶段分组）

| 阶段 | 坑 | 根因（一句话） |
|---|---|---|
| S0 | 只 grep `m_ScaleCurves` | `sizeDelta` / `anchoredPosition` / `m_Color.a` 都在 `m_FloatCurves` |
| S0 | 把参考路径当规格照抄 | 动效节点可能是不可见的全屏遮罩/透明容器，要照抄**几何**不是路径 |
| S0 | 把绝对坐标当偏移 | 曲线 key 是**绝对基准值**，先取 prefab 实测值 |
| S0 | 目标节点不存在就自己臆造路径 | 绑不上 Unity 不报错，只是在窗口标 Missing |
| S1 | 明明有运行时克隆还写静态曲线 | 数量/命名/激活态都不固定，绑不上且会卡值 |
| S1 | 参考是循环、目标是只播一次，却直接抄参数 | 意图差异要显式记录，不是缺陷 |
| S2 | 用例子里"文件里第一个 `!u!95`"当锚点 | prefab 组件块顺序与层级无关（ExpertPanel 第一个在子页） |
| S2 | 给 `m_IsActive: 0` 的节点写 `0→1` 弹入 | 未激活不求值，`SetActive` 打开时卡在 scale 0 |
| S2 | 给无 sprite 的整屏遮罩写缩放 | 缩的是这块实色 ⇒ 四周露底/露场景，只写 `m_Color.a` |
| S2 | 写了 `sizeDelta` 当位移动画 | 布局组每帧重算 + 触发布局重建，掉帧 |
| S2 | 曲线与子级 `CommonButton` 抢同一通道 | 父子两级写同一属性结果不可靠 |
| S2 | Lua 里用 `transform` 调 `DOAnchorPos` | 它是 `RectTransform` 扩展；`transform` 是 `Transform` userdata |
| S2 | `Ease.InOutQuad` 硬索引 | 枚举运行期注册，取不到就抛 ⇒ 被 `pcall` 吃掉 ⇒ 整段静默 |
| S2 | DOTween 与 Animator 同时写 scale | `Update` 后 Animator 求值覆盖 ⇒ 必须临时 `enabled = false` |
| S2 | 漏恢复 `Animator.enabled` | 那颗按钮永久失去按下反馈 |
| S2 | `Stop` 只写在 `OnClose` | `DestroyPanel` 不走 `OnClose`；面板还会被缓存复用 |
| S2 | 两个动画都自己 `Stop`，顺序反了 | 后起的把前一个的 tween 杀掉（本次 flip 必须先于 drop） |
| S2 | `function this.F(i)`（点式）配 `this:F(i)`（冒号）调用 | 第一个实参被 `self` 吃掉 ⇒ `i` 拿到 table、`list[i]` 为 nil ⇒ **静默不播**（无报错、无日志） |
| S2 | Kill 掉「先把节点置 0 再长回 1」的 tween 却不复位 | 那个节点永久停在半截缩放（切页后 0.17s 内关面板即触发） |
| S3 | 校验用根节点 `Find(path)` | 口径错了，`missing=0` 是假阳性 |
| S3 | 改了 Lua 没重编 Bytecode | 真机跑的是 `.bytes` |
| S3 | 用 `sh` 跑 `lua-bytes-sync.sh` | 第 60 行需要 bash 语义 |
| S4 | 只看编辑器不动手截帧 | 遮罩露边、方向错、循环跳变只有实拍能看出来 |
| S5 | 忘了重打 AB | 编辑器好看、真机没变 |
| S5 | 在 Play mode 里按 Ctrl+S 保存 prefab | 会把内存里的旧 controller 引用写回去 |

前 11 条（老面板那批）的逐条展开在配方文档 §5；本表是把它们按"流程阶段"重排，新增的是 S1/S2 后半段的 Lua 侧。

---

## 9. 实战时间线：ExpertPanel 复刻 `SevenDayCarnivalPanelV2`

留一份完整因果链，因为"先做错再纠正"这部分最有参考价值。

| 轮次 | 做了什么 | 结果 |
|---|---|---|
| 1 | 按配方文档做了**整面板浮动**（根节点 Animator：start 弹入 + normal 呼吸） | **方向错**。用户要的是"选项卡动画" |
| 2 | 改做页签逐格翻入 —— 但页签是 Lua 克隆的（8~22 个，`TabSort` 重排），静态曲线绑不上 | 转向 Lua 驱动 |
| 3 | Lua 驱动逐格 `DOScale` | 页签**不动**：每格 `CommonButton` 的 Animator 每帧写回 `scale=1` ⇒ 加 `enabled=false` |
| 4 | 交付后被打回：「还有一个元素从上往下的启动前摇没复刻」 | **A 类读漏**：只读了 `m_ScaleCurves`，漏了 `m_FloatCurves` 两条 |
| 5 | 反解那两条 = 顶边落 110 / 中心落 55；参考里 `bg` 是全屏遮罩不可见 ⇒ 落到 `downLayout` | 补齐前摇 |
| 6 | `DOAnchorPos` 不存在于 `Transform` userdata；`Ease` 硬索引被 pcall 吞 | 加 `GetComponent("RectTransform")` + `SetEaseSafe` |
| 7 | prefab 回滚到加 Animator 之前（对象数 3071 → 3070） | 只留 Lua 开启动画 |

**最终形态**（`ExpertPanel.lua`，prefab 一行没动）：

| 动画 | 实现 | 参数 |
|---|---|---|
| 页签逐格翻入 | `PlayTabFlipIn`：遍历 `tabsContent` 子节点（跳过模板 `btn` 与 inactive），按 sibling 顺序 `DOScale(one)` | 0.167s/格，错开 0.033s，总 ≤ 0.5s 跨度，只播一次 |
| 高亮板翻入 | `PlayTabSelectFlip(index)` | 同上单格时长 |
| 内容区落位 | `PlayDropIn`：`anchoredPosition (0,110) → (0,0)` | 0.3667s，`InOutQuad`，只播一次 |
| 统一回收 | `StopOpenAnims`：Kill + scale=1 + 恢复 Animator + 落位复位 | OnShow 首行 / OnClose / OnDestroy |

产物：`Assets/ManagedResources/LuaBytes/Modules_Expert_ExpertPanel_64.bytes`（13403 → 15505 → 16608 B）。

Commits：`b1b4580ed`（撤销错方向）、`2198f87da`（补落位曲线）、`277036180`（文档）。

### 第二次复用：`OperatingPanel`（同一份参考，一轮做完）

按本流程走第二遍，没有返工。值得记的只有"判据变化"和"读参考时的新发现"：

| 环节 | 这次的判断 |
|---|---|
| S0 | `dump_clip.py` 一次性读出参考 9 条曲线 + 本面板已有的 5 个 legacy clip（`page_2/8` 是 `smallImg/Image` 旋转+alpha 装饰循环、`page_7/12` 是页面内入场、`page_10` 是**空 clip 死组件**、`UI_effect_OperatingPanel_normal` 是火光 UV 滚动）⇒ 通道互斥清单直接有了 |
| S0 | 参考 `day_2..7` 的关键帧是 `[1 @0, 0 @delay, 1 @delay+0.1667]`：**先保持原样、到延迟点才归零再长出来**（前 2 帧还看得见）。这与"从 t=0 全隐藏"不是一回事，要显式记成偏离 |
| S1 | 页签**是静态节点**（`tabs_1..19`，不像 ExpertPanel 是克隆），但 `RefreshTabStatus` 用 `SetActive` 按活动开关切换、面板又被缓存复用 ⇒ 仍走 Lua（静态 clip 第二次打开不重播） |
| S2 | 页签顺序取 `tabsContent` 的 sibling 顺序——prefab 里是 `12,5,11,1,9,4,13,10,2,3,…`，**不是** `1..19`。按子节点顺序遍历，天然等于眼睛看到的顺序 |
| S2 | 落位落到 `bg/pageContent`（四边拉满 / pivot 0.5 / 基准 `(0,0)`，几何与参考的 `bg` 等价）。`bg/Image` 虽有全屏黑底但是**带 sprite** 的图，不是纯色遮罩 ⇒ 不做遮罩淡入 |
| S3 | 新增 `scripts/lua-tests/test_operating_openanim.lua`，比 ExpertPanel 那份多一个 **case8 顺序约束**：把"先 drop 再 flip 会被 Stop 杀掉"钉成断言 |

记录见配方文档附录 G。产物：`LuaBytes/Modules_Operating_OperatingPanel_64.bytes`（9850 → 13329 B）。

### 第三次复用：`MainRechargePanel`（页签由公共 `TabBox` 克隆）

第三遍，S0→S4 一轮走完，`prefab` 一行没动。与前两次的差异：

| 环节 | 这次的判断 |
|---|---|
| S0 | 面板**没有任何** `Animation` / `Animator`（除 16 个 `CommonButton`）、也**没有**任何 `cn2-X1_UI_MainRecharge*` 的 clip ⇒ 通道全空，不用做互斥清单 |
| S0 | `bg` 是**无 sprite 的纯色全屏块**（`color=(0.255,0.161,0.471,1)`，四边拉满）⇒ 只当背景，不写它；落位目标选 `content`（无组件的透明容器，四边拉满 / pivot 0.5 / 基准 `(0,0)`，与参考 `bg` 几何等价且**看得见**） |
| S1 | 页签是 `TabBox`（`Modules/Common/TabBox.lua`）**运行时克隆**的，`box` 挂 `HorizontalLayoutGroup` ⇒ 位置被布局组接管，只写 scale。**没有改 `TabBox` 本体**（十几个面板共用），动画写在面板侧，靠 `GetTabList()` 拿列表 |
| S2 | `GetTabList()` 的下标**就是版面顺序**（按 `box` 子节点顺序克隆），不需要像 OperatingPanel 那样按 sibling 遍历 |
| S2 | 每格 `CommonButton` 的 clip 是 `CommonButtonAnim.anim`：`m_LocalScale 1.1→1`（0.083s，写全三条轴）⇒ 与翻入抢同一通道，照旧临时 `enabled=false` |
| S2 | 切页回调 `OnPageTabChange` 在 `TabBox:Init`（`OnOpen` 内）就会被调一次 ⇒ 加 `animReady` 闸门，只让 `PlayDropIn` 之后起的切页翻高亮板 |
| S3 | 新增 `scripts/lua-tests/test_mainshop_openanim.lua`（9 case，**加载真 `TabBox`** 跑真克隆流程）。第一次跑就抓到 3 个问题（见下） |

**harness 这轮直接抓到 3 个 bug**（都是"能编译、能跑、但不动/半截"的静默故障）：

1. `PlayTabSelectFlip` 写成 `function this.PlayTabSelectFlip(index)`（点式）却用 `this:PlayTabSelectFlip(index)` 调 ⇒ `index` 拿到的是 `this`，`list[this]` 为 nil ⇒ **真机上高亮板永远不翻**。改成冒号定义。
2. `StopOpenAnims` Kill 高亮板 tween 后没复位 ⇒ 切页途中关面板会让那块板永久停在半截。顺手把 **OperatingPanel / ExpertPanel 同款**一并修了。
3. `animReady` 闸门缺失会让 `OnOpen` 那次初始化回调提前翻一遍高亮板（先翻后被 `StopOpenAnims` 杀掉，白跑一次 tween）。

记录见配方文档附录 H。产物：`LuaBytes/Modules_Recharge_MainRechargePanel_64.bytes`（5050 → 8363 B）。

### 第四次复用：`BattlePassPanel_Mission`（作用对象返工：页签 → 任务卡）

| 环节 | 这次的判断 |
|---|---|
| S0 | 用户指名的参考换成了 `cn2-X1_UI_TreasureStorePopup.anim`（不是七日狂欢）。`dump_clip.py` 读出 10 条（Scale=1 + Float=9，镜像 12 = 3+9）：**配方是「列表项从左侧滑入 + 底板 alpha 0.3647→1，逐格错开」**，和前三轮的 scaleX 翻入不是同一个东西 |
| S0 | 前 4 条（`Panel` 的 `anchoredPosition.y`/`sizeDelta.y`、`Panel/Bg` 的 `localScale`/`m_Color.a`）是**弹窗本体**的进出场；本页是 BattlePassPanel 的子页，没有对应节点也不该整页位移 ⇒ 只落 6 条「列表项」曲线（偏离已记在此） |
| S1 | 页签由 `TabBox` 克隆、`box` 挂 `VerticalLayoutGroup` + `ContentSizeFitter`，按 §4.3 的字面结论「布局组占位只能写 scale」就该放弃位移。**这次没放弃，而是换承载节点**：位移写到 tab 的 6 个可视子节点（`select/title/HighText/LockImage/Redpot/Text`），页签根节点一动不动 ⇒ 布局重建抹不到，也就不需要「延迟一帧再播」 |
| S2 | `select` 是 z 轴 90° 的板：屏幕横向 = **本地 y**，所以它走 `DOAnchorPosY`、起点 `+140`；其余节点走 `DOAnchorPosX`、起点 `-140` |
| S2 | 只给**激活**的子节点起 tween：未选中的 `select`/`HighText`、没红点的 `Redpot` 保持终值。写它们只会让下次 `SetActive` 打开时从半截起 |
| S2 | 文件里原有的 `local type = {...}`（领取按钮文案表）把 Lua 的 `type()` 遮住了，`TabAlive` 一写就报 `attempt to call upvalue 'type' (a table value)` ⇒ 改名 `btnStyle`（3 处） |
| S2 | 🔴 `this.TabCtrl` 在 `InitComponent` 里被覆盖成**第二个空实例**（第二次 `Init(this.tabBox, this.tabBoxData)` 传的 `tabBoxData` 是 nil，`TabBox:Init` 直接 return）⇒ `GetTabList()` 恒为空。MainRechargePanel 那套「靠 `GetTabList()` 拿列表」在这里会静默不播，改为读 `box` 的子节点 |
| S3 | `scripts/lua-tests/test_battlepass_tabslide.lua`（8 case）：13 格 × 5 激活节点 × 2 通道 = 130 条、末格延迟 0.36、24 格压到 0.4、Stop 全复位、`GetTabList` 为空时照常 |
| 遗留 | 未改：`OnShow` 里的 `this.TabCtrl:ChangeTab(tabIndex)` 打在那个空实例上 ⇒ no-op，页签高亮恒停在第一个（与本次动画无关，单独提） |

**S4 返工（作用对象搞错）**：上面那一版把曲线落在了 **TabBox 的 13 个小页签**上，用户要的是
**右侧任务列表的大任务卡**（`itempre` → `item1..itemN`）。曲线读对了、对象选错了 —— 教训是
「列表项」必须先问清是哪一张列表，`dump_clip.py` 只给节点名（`grid/item1`），给不出业务语义。

改成任务卡后的三处关键差异：

| 点 | tab 版 | 任务卡版 |
|---|---|---|
| 承载节点 | `box` 的子节点（13 个，遍历 `childCount`） | `ScrollCycleView:ForeachItemGO` 给的可见 item |
| 位移量 | 140px（页签宽 203 的 ~69%） | 260px（卡宽 870 的 ~30%） |
| 播放时机 | 只 `OnShow`（页签常驻、整局只建一次） | `SwitchView` 里 `SetData` 之后；`RefreshAllTaskBtn` 用 `suppressTaskAnim` 抑制，只在玩家主动换屏播 |

🔴 **卡片的位移必须写子节点**：`ScrollCycleView:SetData` / `SetItemIndex` 每次都直接重写
`item.tran.anchoredPosition`（换页、滚动都会），写 item 根必被抹回 —— 和 tab 版踩的是同一个坑，
但触发源不同（那边是 `VerticalLayoutGroup`，这边是列表自己算位置）。
🔴 **一屏只有 1 张卡**：本列表 `Open` 传的是 `fixedCount=1 / itemCount=1`，item 池反复复用 ⇒
每次 `SetData` 都要 `Stop` 复位后在终值上重播，"逐格错开"在这里实际不起作用（`kCardSlideStep` 保留给以后多列）。

产物：`LuaBytes/Modules_BattlePass_BattlePassPanel_Mission_64.bytes`（14784 → 17254 → 17078 B，
用例 `scripts/lua-tests/test_battlepass_cardslide.lua`，8 case）。

> 这一套（从一侧滑入 + 底板淡入）已抽成独立配方：**`ui_item_slide_in_skill.md`** ——
> 含参考曲线表、位移承载节点选择表（布局组 / `ScrollCycleView` / `TabBox`）、方向一行切换、
> 9 个坑、8 case 自证。复刻同类动画直接照那份走，本节的 S0~S3 只记录「这次怎么判断的」。

### 第五次复用：`DailyCarbonPanel`（scaleX 翻入与已有的滑入同页共存）

同一个面板里已经有第四次的「副本卡右滑入 + 底板淡入」，这次要给 **`TabBox` 的页签**加翻入。
两种入场作用对象不重叠（页签 vs 卡片列表），各自一套常量与回收函数，互不干扰。

| 环节 | 这次的判断 |
|---|---|
| S0 | 没有新参考：用的就是本配方（七日狂欢那 9 条）。本页第一版已经把「列表项滑入」按 `ui_item_slide_in_skill.md` 落在卡片上 ⇒ 这次只补页签那一条通道 |
| S0 | 参考里 2 条 `bg` 的 `m_FloatCurves`（落位 110）**没复刻**：本面板 `Panel` 下是 `Scroll` 与 `TabBox` **并列**，没有 `content` 那种整块容器；动 `Scroll` 会让卡片列表跟着抖。偏离已写入代码注释 |
| S1 | 页签由 `TabBox` 克隆（`_TabData` 5 个），且 `OnShow` 每次 `ClearChild` 重克隆 ⇒ 节点是新的、每次进面板都会重播；继续走 Lua，不动 prefab |
| S2 | `box` 挂 `VerticalLayoutGroup`（spacing 87.98）⇒ 位置归布局组，**只写 scale**，正是 §4.3 的标准情形（不需要像 BattlePass 那样换承载节点） |
| S2 | 这里可以放心用 `GetTabList()`：走的是 `Init_SetTabAndBox`（`tab` / `box` 都显式传了）⇒ `TabList` 有值。**BattlePassPanel_Mission 不是这个 shape**（`Init` 传 nil 提前 return、`TabCtrl` 被换成空实例），那次的教训不能反向套到这里 |
| S2 | `PlayTabSelectFlip` 三道闸门：`tabAnimReady`（挡 `Init_SetTabAndBox` 那次初始化回调）、`suppressOpenAnim`（挡数据刷新）、`select.activeSelf`（未选中 / 已锁定的页签没有高亮板；对隐藏节点起 tween 看不见，还会让下次 `SetActive` 打开时从半截起） |
| S2 | 数据刷新统一收口成 `RefreshTabSilently`：领奖弹窗关闭 ×2（原来是裸 `this.OnTabChange`）+ 5 点刷新。顺手把 `suppressCardAnim` 改名 `suppressOpenAnim` —— 一个标记同时管「卡片滑入」与「高亮板翻入」 |
| S3 | `scripts/lua-tests/test_dailycarbon_tabflip.lua`（8 case，**加载真 `TabBox` 跑真克隆**）：5 格延迟 0/.045/.09/.135/.18、24 格压到 0.55、Animator 开关、高亮板三道闸门、`OnTabChange` 真实调用链、生命周期回收 |
| 复盘 | 上线后反馈「切换太快 + 有点卡」：参考的 0.167/0.033 是**弹窗一次性入场**的节奏，放在玩家反复点的页签上偏快 ⇒ 放慢到 0.21/0.045，切页高亮板单独给 0.26（见下表） |

产物：`LuaBytes/Modules_Carbon_DailyCarbonPanel_64.bytes`（17197 → 19478 B）。

### 第五次复用之后的节奏返工（2026-10-21）

用户第一轮实机反馈是**「切换太快了 而且有点卡」**。分量拆清楚再动手，别拿「再放慢一点」一把糊上去：

| 症状 | 真因 | 改法 |
|---|---|---|
| 太快 | 页签翻入抄的是弹窗一次性入场的 0.167/0.033；`PlayTabSelectFlip` 也只有 0.167 ⇒ 点一下「闪」完了 | 页签 0.21/0.045（末格 0.18）；切页高亮板单独 0.26 |
| 太快 | 切页签的卡片滑入沿用打开时的 260px / 0.22s（≈1180px/s） | 拆第二套 preset：170px / 0.30s（≈570px/s），位移小、时间长 |
| 卡 | 切页签那一帧同时做：`SetScroll` → 5 张卡各 178 行 `SetData`（`GetComponent`/`SetActive` 全在里面）→ 35 条 tween 起播 | 切页签整批 `SetDelay(0.05)`：让重建那一帧先结束，动画第一帧不顶着卡顿跑 |
| 卡 | 连点页签 = 重建完又堆一批 tween | `cardSlidePlaying` 标记：播中再请求只 Stop 复位、不重播（`Kill` 不回调 `OnComplete` ⇒ `Stop` 里也要清标记） |

两套节奏靠现成标记区分，不新增状态：`tabAnimReady`（页签翻入是否播过）false ⇒ 首次打开，true ⇒ 切页签。

> 观感提示：打开面板时「5 个页签逐格翻入」与「约 5 张副本卡右滑入」仍会同时发生（不同节点、不冲突）。
> 嫌热闹就提 `kTabFlipStep`；切页签想再稳一点，`kCardSwitchFrom` 收到 120~150 或用
> `suppressOpenAnim` 把切页签的卡片滑入整个压掉（只留高亮板翻入）。

---

## 10. 交付前自查（可直接贴进 PR）

```
[ ] S0  分镜表行数 == 参考 clip 曲线条数（所有 m_*Curves 段都读过）
[ ] S0  m_EditorCurves 镜像条数对得上
[ ] S0  每行过了六问（节点存在 / 通道归属 / 激活 / 克隆 / 可见 / 绝对基准值）
[ ] S1  阵营有书面理由；偏离参考之处（循环 vs 一次）已记录
[ ] S2  通道互斥（静态 clip 与 Lua 不写同一属性）
[ ] S2  未激活节点没有 0→1 弹入；无 sprite 遮罩只写 alpha
[ ] S2  Stop 收口唯一，OnClose + OnDestroy 都调
[ ] S2  临时禁用的 Animator 在 OnComplete 与 Stop 两处都恢复
[ ] S3  离线条数/hash/首尾/guid 链全过
[ ] S2  冒号调用对应的函数必须冒号定义（点式定义 + 冒号调用会静默不播）
[ ] S2  Kill「先置 0」的 tween 时同步复位该节点
[ ] S3  lua-tests harness ALL OK；lua-bytes-sync --check 已同步
[ ] S4  回读 missing 相对 animator.transform 算；状态默认值一致
[ ] S4  实拍截帧看过（含第 1 帧与中途）、开关 10 次无残留
[ ] S5  commit 拆分清晰；AB 已打或显式记「待做」；台账已写
```
