# UI 面板浮动 / 呼吸动画（弹入 + 循环呼吸）

> 适用范围：TimeSpaceGirl1 项目（Unity 6000.6.5f1）
> 更新时间：2026-10-20（第 4/5 次落地后重整：体检脚本 + 十坑 + 三层验收 + 附录 E 页签翻入）
> 工具：`.workbuddy-ai/skills/ui-panel-float-anim/scripts/`
> （`audit_panel.py` 体检 / `dump_clip.py` 把 .anim 读成分镜表 / `gen_float_anim_yaml.py` 生成 /
> `dump_prefab_tree.py` 看层级（`--rect` 看锚点 pivot）/ `UIPanelFloatAnimBuilder.template.cs` Unity 版）
> 现成实现：`FirstRechargePanel`、`SupremeHeroPopup`、`ExpertPanel`、`DailyRechargePanel(原版)`
>
> 📎 本篇是**配方 + 逐面板落地记录**。要"拿别人的动画来复刻"，先看流程篇 **`ui_anim_reproduce_skill.md`**
> （反解 → 定阵营 → 落地 → 三层验收，含"只读 `m_ScaleCurves` 导致漏曲线"那类事故的完整因果链）。

给任意 UI 面板加「弹入 + 循环浮动/呼吸」动画（每日首充 `DailyRechargePanel` / `UI_effect_DailyRechargePanel` 那套观感）。

结构就一句话：**根节点挂一个 Animator，两个状态** —— `start`（一次性弹入）→ `normal`（循环呼吸）。

关键不是"整体上下平移"，而是**各部件相位错开**：标题类往上、内容类往下、按钮高频脉冲，看起来才像整块在浮动。

**流水线**（顺序别换，跳过第 1 步就是唯一那类"白干"事故的来源）：

```
①体检 → ②挑配方 → ③dry-run 生成到 /tmp 并解析 → ④落盘 + 回读校验 → ⑤打 AB
```

---

## 0. 开工前体检（60 秒，必做）

```bash
S=.workbuddy-ai/skills/ui-panel-float-anim/scripts
python3 $S/audit_panel.py <prefab> --depth 3 --lua <面板>.lua          # ① 风险标记 + 锚点结论
python3 $S/dump_prefab_tree.py <prefab> --depth 2                       # ② baseY（pos 的 y）
```

`audit_panel.py` 把 `m_IsActive`、Image 有无 sprite、锚点是否四边拉伸、LayoutGroup/ScrollRect、
自带 Animator/legacy Animation、`PlayFlyAnim` 全从 prefab 里读出来，直接给结论。标记含义：

| 标记 | 判据（prefab 内） | 结论 |
|---|---|---|
| `INACTIVE` | `GameObject.m_IsActive: 0` | **不写 start 曲线**；写了 `0→1` 的弹入，运行时被 `SetActive` 打开会卡在 0 |
| `MASK` | Image `m_Sprite: {fileID: 0}` + 锚点四边拉伸 | 实色铺满块（多数是整屏遮罩）⇒ **只写 `m_Color.a`**，缩放会连边缘一起缩、露出场景底 |
| `OWN_ANIM` | 该节点自带 `!u!95`（按钮几乎都是 `CommonButton`） | 只写它 clip **没写**的通道；父子两级写同一属性结果不可靠 |
| `LEGACY` | 该节点自带 `!u!111` | 同上，且**绝不能选它当锚点** |
| `LAYOUT` / `LAYOUT_CHILD` | 自身/父级挂 H/V/GridLayoutGroup | 位置每帧被重算 ⇒ **只写 scale** |
| `SCROLL_DESC` | 严格祖先里有 `ScrollRect` | 位置归滚动/布局 ⇒ 不写位置 |
| `PLAYFLY` | 挂 `PlayFlyAnim`（DOTween） | 同上，**不写位置**，只写 scale/alpha |
| `CODE_POS` | `--lua` 里出现 `<名字>.localPosition =` 等赋值 | 插一个空容器承接位移（见附录 C「通用套路」） |

它同时给出**锚点结论**与「其它节点上的 Animator / legacy Animation」清单（ExpertPanel 有 49 + 1 个）
——那张清单就是"绝不取文件里第一个组件"的理由。

> 已跟前三次落地的人工结论对过：`FirstRechargePanel` 命中 `PLAYFLY`(frame) + `LAYOUT`×2(rewardBg/tabsContent) + `OWN_ANIM`×2(按钮)；
> `SupremeHeroPopup` 命中 `MASK`(Panel 遮罩) + `OWN_ANIM`(三个按钮/特效)；`ExpertPanel` 命中 `MASK`(bg) + `INACTIVE`×12(子活动页) + `OWN_ANIM`。
> 三个都对得上，可以直接当开工依据。

> 只想知道某个子树：`--name <关键字>`；刚生成过 controller 结果却显示 `Animator(?)`/`MB:xxxx`，
> 是 guid 索引缓存旧了，加 `--refresh`（不是 guid 写错）。
>
> 🔴 **文档与 `scripts/` 必须同改**：判据（标记集、缓存 TTL、生成器默认行为）改了却不同步这里，
> 下一轮就会照着过期的判据做——本次踩的「6 小时缓存」「四问里没有 MASK/INACTIVE」都是这么来的。

---

## 1. 两套配方（直接抄数字）

### start：弹入（1.0s，不循环，0.9s 处 0.1s 混合进 normal）

| 部件 | 曲线 |
|---|---|
| 主体 | scale `0 → 1.8 → 0.8 → 1.1 → 1`（0 / .13 / .27 / .37 / .5s）——"啪"一下弹出来 |
| 标题条 | scale `3 → 0.8 → 1`，alpha `0 → 1`（.37s 起） |
| 说明区 | scaleX `0 → 1.15 → 0.9 → 1`（横向挤压回弹） |
| 奖励格 | 逐个 scale `0 → 1.2 → 1`，彼此错开 0.06~0.1s |
| 按钮 | scale `0 → 1.5 → 1`，位置从下方 18px 落位 |
| 黑底遮罩 | Image alpha `0 → 0.588`（有遮罩才做）；**只写 `m_Color.a`，不写缩放** |

### normal：循环呼吸（3.0s，`m_LoopTime = 1`）

| 部件 | 曲线 | 相位 |
|---|---|---|
| 主体底板 | scale `1 → 1.02 → 1` | 0 / 1.5 / 3 |
| 标题条 | y `+5` | 与内容区**反相** |
| 说明区 | y `-10` | 向下 |
| 奖励区 | y `-10`，scale `1 → 0.99 → 1` | 向下 |
| 底部按钮 | scale `1 → 1.1 → 1` + y `+2`，**一个循环两次脉冲**（0 / .73 / 1.5 / 2.33 / 3） | 高频 |
| 其他小字 | y `-3` | 跟随内容区 |

> 只放大不缩小（1.02 而不是 0.98）——缩下去会露边/穿帮。
> 奖励区那条「0.99」是每日首充的格子容器；如果目标面板是一整块卡片，用 1.015 往上呼吸更自然（首充就是这么改的）。

---

## 2. 30 秒判断：这个面板能不能照搬

按顺序问七个问题，任一命中就按"规避"列处理（除第 1、7 条，其余 `audit_panel.py` 都会直接打标记）：

| # | 情况 | 怎么判断 | 规避 |
|---|---|---|---|
| 1 | 根节点有旧版 legacy `Animation` | prefab 根节点 `!u!111` | 删掉换 `Animator`（同一 GameObject 上二者不能共存） |
| 2 | 目标节点是**整屏实色遮罩**（Image 无 sprite） | `m_Sprite: {fileID: 0}` + 锚点四边拉伸 | **只写 `m_Color.a`**。写缩放不会"呼吸"，是四周露底/露场景 |
| 3 | 节点在 prefab 里就是**未激活**的 | `m_IsActive: 0`（`audit_panel.py` 的 `INACTIVE`） | **一条 start 曲线都别写**（含 `0→1` 弹入，否则被 `SetActive` 打开时卡在 0） |
| 4 | 有 `PlayFlyAnim`(DOTween) 在写某个节点的位置 | 节点上有 `PlayFlyAnim.cs`，看 `tweenSequeue[].targetObj` | **不要写那个节点的 anchoredPosition**，只写 scale |
| 5 | 目标节点是布局组的子节点 | 父节点挂 `HorizontalLayoutGroup`（guid `30649d3a…`）/ `VerticalLayoutGroup` | **只能写 scale，不能写位置**（位置每帧被布局组重算） |
| 6 | 目标节点自己挂着 Animator（按钮常见：`CommonButton`） | 该节点 `!u!95` 且 `m_Enabled: 1` | **不要写它 clip 里已有的属性**：父子两级写同一属性时结果不可靠（首充实测按钮的缩放脉冲不生效），优先只写它没写的通道 |
| 7 | 目标节点是 **Lua 运行时克隆**的列表项（数量不固定） | prefab 里只有一个模板（如 `tabsContent/btn`），源码里 `newObjToParent` + `name = "tab"..i` | **别写静态曲线**（数量/命名/激活态都不固定，绑定不上且会卡值）⇒ 走 Lua 驱动，见附录 E |

> 第 2、3 条是 2026-10-20 落地 ExpertPanel 才暴露的：前三个面板都没有"整屏纯色遮罩"和"十几个未激活子页"。
> 第 3 条尤其隐蔽——曲线写对了、`missing=0`、Unity 也不报错，只是**那个页面切过去时是 scale 0**。


要连 `baseY` 一起取，就直接看层级：`dump_prefab_tree.py <prefab> --depth 2`（`--name` 只看子树）。
输出的 `pos` 的 y 就是曲线里的 `baseY`——**曲线写的是绝对值**，必须和 prefab 一致。

---

## 3. 落地：两条路

### 路 A：Unity 可用（能点菜单 / 能 batchmode）

复制 `.workbuddy-ai/skills/ui-panel-float-anim/scripts/UIPanelFloatAnimBuilder.template.cs`
→ `Assets/Editor/XxxFloatAnimBuilder.cs`，**改类名（必须与文件名一致）**，只填配置区
（`PrefabPath` / `AssetDir` / `BaseName` / `Nodes`），然后点菜单 `Tools/UI/<面板名>/生成并挂载浮动动画`。

Console 会打 `状态机 start(1.00s, loop=False) → normal(3.00s, loop=True)`，直接确认循环有没有生效。

配置表写法（`N(path, baseY, 呼吸峰值, normal位移, start起始缩放, start峰值, start延迟, 写位置, 写缩放, 双脉冲)`）：

```csharp
N("frame/BG",        0f,       1.02f,  0f,   1f,   1.2f,  0f),       // 主体：弹一下 + 呼吸
N("frame/tabsContent", 156.64f, 1f,    5f,   0.85f, 1.06f, 0.30f),   // 标题：往上飘
N("frame/rewardBg", -226.18f,  1.015f, -10f, 0f,    1.12f, 0.40f),   // 内容：往下沉
N("frame/btn",      -600f,     1f,     3f,   1f,    1f,    0.72f, true, false, true), // 只写位置 + 双脉冲
```

- `start起始缩放 = 1 且 start峰值 = 1` → 这个节点不做弹入
- `start起始缩放 = 0` → 从无到有弹出来；`= 1` → 原地"顶一下"

### 路 B：Unity 被占用（`lsof Temp/UnityLockfile` 有进程）

**先 dry-run，再落盘。** 第一次跑几乎总会在 dry-run 阶段发现路径/锚点问题：

```bash
S=.workbuddy-ai/skills/ui-panel-float-anim/scripts
# ① 干跑：只产出 clip 到 /tmp，不碰 prefab
python3 $S/gen_float_anim_yaml.py --prefab <prefab> --base cn2-X1_UI_<面板>_float \
    --config $S/configs/<面板>.json --out-dir /tmp/x --no-prefab
# ② 解析 /tmp 里的 clip：曲线条数、首尾是否同值、path/attribute 哈希是否对得上
# ③ 确认无误后再落盘（生成 clip/controller.meta + 改 prefab）
python3 $S/gen_float_anim_yaml.py --prefab <prefab> --base cn2-X1_UI_<面板>_float \
    --config $S/configs/<面板>.json
```

直接写 `.anim` / `.controller` 并改 prefab，**不需要 Unity 参与**。已 diff 验证：输出与 Unity 生成的 clip **逐字节一致**。

生成器现在会自己保证三件事（都是踩过坑才加的，别绕过）：

| 行为 | 为什么 |
|---|---|
| 锚点**只由层级决定**（默认根节点，`--animator-go` 可指定） | prefab 里 `!u!111`/`!u!95` 的**文件顺序与层级无关**；ExpertPanel 第一个 `!u!111` 在 `downLayout/ContinuityRecharge` 上，"取第一个"会挂到子页 |
| 根节点**没有**动画组件时**新建** Animator（`m_Component` 追一条 + 文件尾追 `!u!95`） | 老版只认 legacy `!u!111`，遇到"什么都没挂"的面板直接失败 |
| 写盘前 `check_paths`：每条曲线路径 = 锚点路径 + `path`，`Find` 不到就 `SystemExit`、**不落盘** | Unity 对绑不上的曲线**不报错**，只在 Animation 窗口标 Missing |

### 两条路都要做的

**重打 AB** —— 新 clip/controller 是 prefab 的依赖，不打资源包真机还是旧包。

---

## 4. 为什么能直接手写 clip（路 B 的原理）

`AnimationClip` 的 `m_ClipBindingConstant.genericBindings[].path` 是**层级路径的 `zlib.crc32`**，
`attribute` 是属性名的 crc32：

| 项 | 值 |
|---|---|
| `frame/bg` 的 path 哈希 | `296690534`（= `zlib.crc32("frame/bg")`） |
| `m_AnchoredPosition.y` 的 attribute | `538195251` |
| 缩放曲线绑定 | `attribute: 3` + `typeID: 4` + `customType: 0` |
| RectTransform 属性绑定 | `typeID: 224` + `customType: 28` |
| 编辑器曲线里的缩放 | `attribute: m_LocalScale.x/y/z` + `classID: 224` |

用现有 `UI_effect_DailyRechargePanel_normal.anim` 的 5 个样本验证过 5/5 命中。
**算对了和 Unity 写的完全等价；算错了 Unity 不报错，就是不播。**

---

## 5. 十一个坑（前四个是"做完了但白干"类）

| 坑 | 现象 | 原因 / 规避 |
|---|---|---|
| ① 锚点取"文件里第一个 `!u!111`/`!u!95`" | Inspector 里曲线一片 Missing，根节点反而没动画；某个按钮自己的弹动也没了 | prefab 里组件块顺序与层级**无关**。必须按 `m_Father`/层级选锚点（已固化进生成器） |
| ② 校验用**根节点** `Find(path)` | `missing=0` 却是假阳性，动画照样不播 | 曲线 `path` 是相对 **Animator 所在节点**解析的 ⇒ 必须 `animator.transform.Find(path)` |
| ③ 给 `m_IsActive: 0` 的节点写 start 曲线 | 当时看不出来；切到那个页签/活动时**卡在 scale 0 或位置错** | 未激活节点不参与求值；`SetActive(true)` 只是打开，不会补播完的弹入 ⇒ 只写 normal，或先让页面常驻 |
| ④ 给无 sprite 的整屏遮罩写缩放 | 弹入瞬间四周出现一圈场景/底板（实拍才看得见） | 它是 `Image.color` 铺满 rect，缩放就是缩这块实色 ⇒ 只写 `m_Color.a` |
| ⑤ 手写 `.anim` 哈希算错 | 不报错，也完全不播 | `path`/`attribute` 都是 `zlib.crc32`，见第 4 节；改 path 必须同步改 `m_ClipBindingConstant` |
| ⑥ 复用别的面板的 controller | 不报错，也不播 | 路径**大小写敏感**：`frame/bg` ≠ `frame/BG` |
| ⑦ 在 `OnEnable` 里手写 `Animator.Play` | 重复打开时弹入不重播 | 面板缓存复用；`KeepAnimatorStateOnDisable: 0` 才会在禁用后重置默认状态 |
| ⑧ 写了 `sizeDelta` | 掉帧 / 被布局组每帧改回去 | 只写 `m_AnchoredPosition.*` / `m_LocalScale.*` / `m_Color.a` |
| ⑨ 曲线首尾不等 | 循环处"跳一下" | normal 第一个 key 与最后一个 key 必须同值（实拍对 n=0/n=1 取值） |
| ⑩ 忘了 AB | 编辑器里好看，真机没变化 | 新 clip/controller 是 prefab 的依赖，必须重打 |
| ⑪ 读参考 clip 时只看 `m_ScaleCurves` | 交付后被指出「还有一条曲线没复刻」 | `m_SizeDelta.*` / `m_AnchoredPosition.*` / `m_Color.a` 都在 **`m_FloatCurves`** 段里，`m_PositionCurves` / `m_EulerCurves` 同理。解析脚本要把所有 `m_*Curves` 段都遍历一遍（`m_EditorCurves` 是它们的镜像，可用来交叉核对条数） |

---

## 6. 验收（三层，缺一层就有看不见的坑）

**① 离线（不需要 Unity，落盘后立刻做）**

| 检查 | 通过标准 |
|---|---|
| clip 长度/条数/循环 | `start` 1.000s、`normal` 3.000s，`m_LoopTime` 0/1 |
| path/attribute 哈希 | 每条曲线与 `genericBindings` 一一对应（自写脚本按 `zlib.crc32` 复核） |
| normal 首尾 | 每条曲线第一个 key == 最后一个 key |
| guid 链 | prefab `m_Controller` → controller.meta → 两个 clip.meta 闭合 |
| prefab diff | 只有预期的那几处（新增 Animator 时对象数 **+1**，换 controller 时不变） |

**② Unity 回读（有 bridge 就做，能戳穿假阳性）**

```csharp
// 关键：missing 必须相对 animator.transform 算，不是 prefab 根
foreach (var b in AnimationUtility.GetCurveBindings(clip))
    if (anim.transform.Find(b.path) == null) miss++;
```

另外读一次状态的**默认值**（`bg` 的 alpha、各节点的 scale）——`start` 末值必须与 `normal` 的
WriteDefaultValues 一致，否则 `start → normal` 切态会跳一下。

**③ 实拍（唯一能发现"方向错了"的一层）**

临时 additive 场景 + `ScreenSpaceCamera` + `RenderTexture`，按时间点截帧：

- [ ] `t=0` 能看到场景色（遮罩还没盖上）→ `t≈0.25` 已盖住 ⇒ 遮罩淡入生效
- [ ] 每一帧边缘**没有**一圈露底（露了 = 给无 sprite 的整屏块写了缩放）
- [ ] `normal` 的 `n=0` 与 `n=1` 逐项取值完全相同（循环不跳）
- [ ] 第一次打开有弹入；关掉再开**不会**再弹（面板缓存复用，符合预期）
- [ ] 点按钮有正常点击态（没被子级 `CommonButton` 抢掉）
- [ ] 切页签 / 反复开关 10 次，没有节点卡在 scale 0 或位置错乱
- [ ] AB 重打后真机复验

---

## 附录 A：每日首充的原始曲线数据（调参基准）

`Assets/Art/EffectsOld/Animation/UI_effect_DailyRechargePanel.controller`
→ 根节点 `DailyRechargePanel` 上的 Animator（guid `fb0b5c1491552e94dafbcf3a29989765`）

`_start`（1s，默认状态，exitTime 0.75 + 0.25s 过渡）：

| 路径 | 属性 | 曲线 |
|---|---|---|
| `frame/bg` | scale | 0 / .13 / .27 / .37 / .5 → 0, 1.8, 0.8, 1.1, 1 |
| `frame/bg/title` | scale | .37 / .5 / .67 → 3, 0.8, 1 |
| `frame/bg/title` | alpha | .37 / .5 → 0, 1 |
| `frame/bg/descbg` | scaleX | .27 / .4 / .57 / .7 → 0, 1.15, 0.9, 1 |
| `frame/bg/rewardContent/itemPos_1..4` | scale | 从 .4 起每个错开 .067s：0 → 1.2 → 1 |
| `frame/bg/dealBtn` | scale | .7 / .83 / 1 → 0, 1.5, 1 |
| `frame`（黑底遮罩 Image） | m_Color.a | 0 / .27 / 1 → 0, 0.588, 0.588 |

`_normal`（3s，`m_LoopTime: 1`）：

| 路径 | 属性 | 曲线 |
|---|---|---|
| `frame/bg` | scale | 1 / 1.02 / 1 |
| `frame/bg/title` | y | 90 / 95 / 90 |
| `frame/bg/descbg` | y | 0 / -10 / 0 |
| `frame/bg/rewardContent` | y | -458 / -468 / -458 |
| `frame/bg/rewardContent` | scale | 1 / 0.99 / 1 |
| `frame/bg/dealBtn` | y | -702 / -700 / -702 / -700 / -702 |
| `frame/bg/dealBtn` | scale | 1 / 1.1 / 1 / 1.1 / 1 |

---

## 附录 B：首充面板落地记录（2026-10-20）

**层级差异**（这就是为什么不能复用同一个 controller）：

| 每日首充 | 首充 |
|---|---|
| `frame/bg`（面板主体） | `frame/BG`（大小写不同） |
| `frame/bg/title` | `frame/tabsContent` |
| `frame/bg/descbg` | `frame/rewardBg` |
| `frame/bg/rewardContent` + `itemPos_1..4` | `frame/rewardBg` + `rewardDay1..3` |
| `frame/bg/dealBtn` | `frame/rechargeBtn` |
| `frame`（黑底遮罩 Image） | `frame`（只有 CanvasRenderer + PlayFlyAnim，无遮罩） |

**首充原有的两套开场动画互相打架**：

| 来源 | 干了什么 |
|---|---|
| 根节点 legacy `Animation`（`cn2-X1_UI_FirstRechargePanel.anim`） | `frame` y -724→-215（0.18s）、`frame` scale 1→1.2→0.95→1、`hero` scale 1→1.3→0.95→1；播完静止 |
| `frame` 上的 `PlayFlyAnim`(DOTween) | `frame.anchoredPosition3D` (0,-1000,0)→(0,0,0)，1s；`FadeChild` 子 Graphic alpha 0→1，0.8s |

两者**同时写 `frame.anchoredPosition`** ⇒ 开场前 0.18s 互相抢，本来就有抖动。
摘掉 legacy `Animation` 换 `Animator`（且新 clip 不写 `frame` 位置）顺手修掉了这个抖动。

**三个冲突点与决策**：

| 冲突 | 证据 | 决策 |
|---|---|---|
| `frame` 位置被 PlayFlyAnim 占用 | `PlayFlyAnim.tweenSequeue[0].targetObj` = frame 自己，`changeType: 0 (Move)` | 不写 `frame` 的 anchoredPosition，只写 scale |
| `rewardDay1..3` 位置由布局组接管 | 父节点 `rewardBg` 挂 `HorizontalLayoutGroup`，卡片自身 pos 都是 (0,0) | 只写 scale |
| `rechargeBtn` 自带 Animator | `Animator(CommonButton.controller)`，`Normal` 状态 clip 单帧写自身 `m_LocalScale = 1` | 只写位置（y 脉冲） |

> 顺带发现：每日首充的 `dealBtn` 自己也挂着 `CommonButton`，它 normal 里的 scale 脉冲**很可能同样是死曲线**（被子级覆盖），真机看着有效果多半是 y 脉冲的功劳。要确认得把 CommonButton 临时禁用对比。

**最终产物**：

| 产物 | 路径 |
|---|---|
| clip | `Assets/Art/UIAni/cn2-X1_UI_FirstRechargePanel_float_start.anim`（1s，loop=0，11 条曲线） |
| clip | `Assets/Art/UIAni/cn2-X1_UI_FirstRechargePanel_float_normal.anim`（3s，loop=1，6 条曲线） |
| controller | `Assets/Art/UIAni/cn2-X1_UI_FirstRechargePanel_float.controller`（start → normal） |
| prefab | `Assets/ManagedResources/Prefabs/UI/FirstRecharge/FirstRechargePanel.prefab` 根节点 `!u!111 Animation` → `!u!95 Animator` |

prefab 的 diff 只有两处（根节点 `m_Component` 里那条 fileID + 组件块本身），对象总数 340 → 340。

**离线校验手段**（没有 Unity 也能做）：

- 路径/属性哈希 = `zlib.crc32`，用现有 clip 的 5 个样本 5/5 命中
- 与 Unity 写出的 `UI_effect_DailyRechargePanel_normal.anim` 逐块比对：文件头、`m_AnimationClipSettings` 一致
- 每条 normal 曲线首尾同值（循环处不跳）
- guid 链闭合：prefab → controller.meta → 两个 clip.meta
- Python 生成器复跑，`diff` 出来的 clip 与已提交版本**逐字节一致**

---

## 附录 C：剑影迷踪弹窗落地（2026-10-20，SupremeHeroPopup）

**先纠正一个误判**：这个面板根节点**早就有** `Animator` + `UI_effect_SupremeHeroPopup.controller`（start + normal 两状态），
但那套曲线是按**老层级**绑的——`Panel/role`、`Panel/Middle/sword`、`Panel/Middle/PreviewBtn`、
`Panel/Middle/di/TaskProgress` 在现在的 prefab 里**全都不存在**（改版成了 `Panel/hero`、`Panel/Middle/Reward/Panel1~3`…）。
路径绑不上 Unity 不报错，所以那两个状态其实一直是空转。判断"有没有动画"不能看组件在不在，要看**路径能不能 Find 到**。

**层级映射**（基准 y 都是 prefab 实测值，曲线写绝对值）：

| 部件 | 路径 | baseY | start | normal |
|---|---|---|---|---|
| 黑底遮罩 | `Panel`（Image 0,0,0,0.706） | — | alpha 0 → 0.706（0→0.27s） | 不动 |
| 主体（整块） | `Panel/Middle` | 47（只写缩放） | scale 0.92 → 1.04 → 0.99 → 1 | 不动 |
| 底板 | `Panel/Middle/Image` | 106 | — | scale 1 → 1.02 → 1 |
| 立绘容器 | `Panel/Middle/Image/heroRoot`（空节点，位移专用） | −153 | y 由 −199 升到 −153（0→0.42s） | y −145（呼吸，与底板同相位） |
| 立绘本体 | `Panel/Middle/Image/heroRoot/hero` | —（位置归 Lua） | scale 1 → 1.20 → 0.97 → 1 | 不动（跟随底板 1.02 一起呼吸） |
| 标题 | `Panel/Middle/Text` | −248 | scale 1 → 1.12 → 1（0.30 起） | y +5 |
| 奖励区 | `Panel/Middle/Reward` | −395 | scale 0.86 → 1.04 → 1 + y 由 −413 落位 | y −10，scale 1.015 |
| 奖励三格 | `Panel/Middle/Reward/Panel1..3` | 0 | scale 0 → 1.12 → 1，错开 0.08s | 不动 |
| 按钮 | `Panel/Middle/DoneBtn` | −805 | y 由 −823 落位（**只写位置**） | y 双脉冲 +3 |
| 进度 | `Panel/Middle/progress` | −715 | y 落位 18px | y −3 |
| 活动时间 | `Panel/Middle/textTime`、`freshTime` | −907 | y 落位 18px | y −3 |

**这个面板特有的三个坑**：

| 坑 | 证据 | 处理 |
|---|---|---|
| `hero` 的位置归 Lua | `SupremeHeroPopup.lua:75` 非中文语言会把 `hero.transform.localPosition` 改成 `(338,266)` | **不要直接给 `hero` 写 `anchoredPosition.y`**（会被语言偏移冲突：动画每帧写回就把它按回 0）。在父节点与 `hero` 之间插一个空节点 `heroRoot`，位移写 `heroRoot`、缩放写 `hero`；`heroRoot` 挂在哪，基准就是那个父节点中心的**负偏移**（本面板挂在 `Middle/Image` 下，父级累计 +47+106=+153 ⇒ 基准 −153，世界位置与挂在 `Panel` 下时完全一致）。这样 hero 跟着底板一起呼吸/弹入，Lua 的语言偏移也不会被动画覆盖 |
| `DoneBtn` / `Button_Go` / `Button_Get` 自带 `CommonButton` 控制器 | 三个按钮都是 `Animator(CommonButton.controller)` | 只写位置，不写缩放 |
| 黑底遮罩就是 `Panel` 自己的 Image（不是独立节点） | `Panel` 的 Image `m_Color = (0,0,0,0.7058824)`，`btnBack` 只是 a=0.004 的点击层 | start 里给 `Panel` 写 `m_Color.a` 0 → 0.7058824（与 prefab 默认同值，切 normal 不跳） |

**生成器这次补的两个能力**（`gen_float_anim_yaml.py`）：

- `--config <json>`：换面板只加一个 JSON 配方（`scripts/configs/supreme_hero_popup.json`），不再改脚本里的 `CURVES`
- `m_Color.a` 曲线（`attribute: 304273561`、`typeID: 114`、script 取组件自己的 `m_Script`）+ **prefab 已是 Animator 时只换 controller guid**（不再要求 legacy `!u!111`）
- 重跑**沿用已有 `.meta` 的 guid**（之前每次 `uuid4()`，重跑一次 clip/controller 的 guid 全换、prefab 的 `m_Controller` 跟着搬，一次配方微调变成一次引用搬家）

### 通用套路：节点位置已经被代码写死时，怎么加位移动画

判据：面板 Lua/C# 里有 `xxx.transform.localPosition = ...` 或 `anchoredPosition = ...`。
**直接给同一个节点写位置曲线会被覆盖**（哪怕代码只写一次，动画每帧都会盖掉它），所以：

1. 在该节点外插一个空容器（只挂 RectTransform，中心锚点、pivot 0.5、尺寸取同值）；
2. 位移曲线写给容器（基准 = 负的父级累计偏移 ⇒ 纯偏移），缩放/透明度仍写原节点；
3. 原节点的**名字和查找路径**要么保持不动、要么同步改所有引用（本面板因为 `Util.GetGameObject` 是 `Transform.Find` 路径查找，改过两次：`Panel/hero` → `Panel/heroRoot/hero` → `Panel/Middle/Image/heroRoot/hero`，每次源码与 `LuaBytes` 成对重编）；
4. 容器插进父节点 `m_Children` 时**替换原节点的位置**（同一个 sibling index），否则会改变渲染顺序（UI 是按 sibling 顺序画的）；换父节点时插到新父的末尾即可（会盖住新父原有的图元，符合"立绘在底板上"）；
5. 空容器不需要 `CanvasRenderer`，`m_Layer` 跟同级一致即可；
6. **换父节点会让子节点继承新父的缩放位移**（本面板 `Middle` start 会 0.92→1.04、`Image` normal 会 1→1.02）⇒ 原节点自带的缩放曲线要按"净效果"折一下（hero start 峰值 1.25 → 1.20，净峰值 ≈1.20×1.04≈1.25）。

**为什么这次走路 B**：Unity 停在 Play mode，脚本编译被阻塞 ⇒ 新写的 C# builder 编译不出来、菜单也点不了；
而手写 clip 不依赖 Unity 编译。产出的 prefab diff 只有 **1 行**（`m_Controller` 的 guid），对象总数 296 → 296。

**验收记录**：

- Unity 回读：`start` 1.000s / 28 条曲线、`normal` 3.000s / 13 条曲线、`loopTime` 分别 False/True、
  `missingPaths=0`（⚠️ 这条第一次是**假阳性**，锚点按根节点算的；见下方事故复盘，修复后按 `Animator.transform` 复验仍为 0）
- 结构：`Panel` 子节点 `btnBack, fanhuiBtn, Middle`；`Middle/Image` 子节点 `Image, heroRoot`（`heroRoot` anchoredPosition `(0,-153)`、`hero` localPosition 仍是 `(335,0)` ⇒ 世界坐标与改造前同为 `(335,0)`）、对象数 298 不变
- 离线：14/14 与 9/9 条曲线的 `path`/`attribute` 哈希与 `genericBindings` 一一对应；normal 每条曲线首尾同值
- 旧 `UI_effect_SupremeHeroPopup.controller`（+ `_start.anim` / `_normal.anim`）**原样留在** `Assets/Art/EffectsOld/Animation/`，只是不再被 prefab 引用（`_praticle_controller` 仍在用，别一起删）

> Play mode 里 Unity 不会重导 prefab ⇒ `AssetDatabase.LoadAssetAtPath` 仍返回旧 controller（内存缓存），
> 退出 Play mode（或重启编辑器）后才会看到新引用。别在 Play mode 里按 Ctrl+S 保存这个 prefab，会把内存里的旧数据写回去。

### 事故复盘：controller 挂错节点（同日后修，必读）

第一次落地时 `m_Controller` 改到了 **`Panel/Middle/Reward/Panel3/Button_Get`** 上，根节点仍指向旧 controller。
表现是"动画里好多节点都丢了"——那颗按钮播着一份路径全错的动画，根节点反而还是空转。

| 环节 | 错在哪 |
|---|---|
| 补丁 | `re.search(r'^--- !u!95 &', ...)` 取**文件里第一个** Animator 块。prefab 文件里 `!u!95` 的排列顺序与层级**无关**，这个 prefab 第一个是 Panel3/Button_Get 那颗 CommonButton 按钮（10 个 Animator 里排在文件最前） |
| 校验 | 用 `prefabGo.transform.Find(path)` 从**根节点**查路径 ⇒ 恒为 true。曲线 `path` 是相对 **Animator 所在节点** 解析的，正确口径是 `animator.transform.Find(path)`；锚点错了，0 missing 也只是假阳性 |
| 连带损伤 | 那颗按钮的 `CommonButton` 控制器被覆盖，按钮自身的弹动也一起没了 |

**已固化到生成器**（`gen_float_anim_yaml.py`）：

- `pick_animator(prefab, animator_go=None)`：按 `m_Father == 0` 找**根节点上**的 Animator；根上有多个或都不在根上时直接报错，要求 `--animator-go <路径>` 显式指定——绝不"取第一个"
- `check_paths(prefab, anim_go, paths)`：打完补丁把每条曲线路径拼成 `锚点路径 + '/' + path`，校验它真的存在；解析不到就 `SystemExit`，**不落盘**
- 落盘后自检：`start` 27 条 / `normal` 12 条曲线，`missing(相对 Animator 节点)=0`；`Panel3/Button_Get` 回到 `CommonButton`

> 教训：Unity 对绑不上的曲线**不报错**，只在 Inspector / Animation 窗口标 Missing。所以"动画有没有生效"只能靠
> `animator.transform.Find(path)` 逐条验，肉眼看面板"没动"分不清是没挂上、挂错节点、还是曲线本身没写。


---

## 附录 D：经营面板落地（2026-10-20，ExpertPanel）

**这个面板和前面两个都不一样**：根节点上**什么动画组件都没有**，而文件里已经躺着 **50 个别的节点的动画组件**
（46 个 `CommonButton` 的 `Animator` + `LuckyCatPanel` 等面板自带控制器 + `downLayout/ContinuityRecharge` 的 legacy `Animation`）。
所以"取第一个 `!u!111`/`!u!95`"会直接挂到子页面上——第一次跑就撞上了（`check_paths` 报
曲线解析不到，锚点变成了 `ExpertPanel/downLayout/ContinuityRecharge`）。**校验拦住了，prefab 没落盘。**
（现在 `audit_panel.py` 开工前就把这张清单打出来，不用再拿事故当发现手段。）

**层级实况**（根子节点只有 4 个）：

| 部件 | 路径 | 实际是什么 | 处理 |
|---|---|---|---|
| 黑底遮罩 | `bg` | Image **无 sprite**、color 黑、alpha=1 | 只写 `m_Color.a`（0 → 1，0→0.12s）。**不能写缩放**：它铺满全屏，缩下去四周露边 |
| 内容区 | `downLayout` | 无 sprite 的透明容器，承载全部活动页 | 呼吸/落位都写它（y + scale），子页**不写** |
| 页签列 | `tabs` | ScrollRect，底板 `cn2-X1_yingxiongxiangqing_yeqiandiban` | 只写 `tabs` 容器本身；`viewPort/tabsContent` 归 VerticalLayoutGroup，页签按钮是 Lua 克隆的 `tab1..32`（静态曲线绑不到） |
| 返回 | `btnBack` | 自带 `CommonButton` 控制器 | 只写位置 |

**为什么子页不写曲线**：`ExpertPanel.lua:ActivityRewardShow` 用 `SetActive` 切换十来个活动页
（`exChangeGrid`/`UpLvRewardGrid`/`GiftBuy`/`BoxPool`…）。未激活的节点不参与动画求值，曲线等于白写；
更糟的是先写 `0 → 1` 的弹入，页面在弹入之后才被激活时会**卡在 scale 0**。只给默认页的
`downLayout/expertRewardGrid/banner` 留了一条弹入（它是默认展示页，打开时就在）。

**曲线**（基准 y：`downLayout`/`tabs` = 0，`btnBack` = 73.5）：

| 阶段 | 部件 | 曲线 |
|---|---|---|
| start 1.0s | `bg` alpha | 0 / .12 → 0, 1 |
| | `downLayout` | y -22 → 0（.10–.44）；scale .94 / 1.02 / .99 / 1（.10/.26/.38/.46） |
| | `tabs` | y -16 → 0（.18–.50）；scale .88 / 1.06 / .99 / 1（.18/.32/.44/.54） |
| | `expertRewardGrid/banner` | scale .94 / 1.02 / 1（.22/.36/.48） |
| | `btnBack` | y 55.5 → 73.5（.30–.52，只写位置） |
| normal 3.0s | `downLayout` | y 0 / -9 / 0；scale 1 / 1.006 / 1（只放大） |
| | `tabs` | y 0 / +5 / 0（与内容反相） |
| | `btnBack` | y 73.5 / 75.5 / 73.5 |

> 全屏 hub 不做 1.8 那种爆弹、也不缩到 1 以下——`start` 幅度整体压到 ±6%，靠**相位错开**（遮罩 0 →
> 内容 .10 → 页签 .18 → banner .22 → 按钮 .30）出层次感。

**生成器这次补了两个能力**（已写进 §3 的「生成器保证」表）：

| 能力 | 说明 |
|---|---|
| 目标节点既没 `Animation` 也没 `Animator` ⇒ **新增** | `m_Component` 追一条 + 文件尾追 `!u!95`（对象数 3070 → 3071） |
| 锚点**只由层级决定** | 删掉 `pick_animator`（`!u!111` 文件顺序 ≠ 层级，本次第一个是 `downLayout/ContinuityRecharge`），改 `resolve_target_go` + `_component_on(prefab, go, cls)`（只找挂在**这个** GO 上的组件） |

**验收记录**（Unity 回读 + 临时 additive 场景实拍）：

- `start` 1.000s / 16 条曲线、`normal` 3.000s / 6 条曲线，`loopTime` False/True
- `missing(相对 Animator 节点)=0`；`bg` 默认 alpha=1（`start` 末值与 `normal` 的 WriteDefaultValues 一致，切态不跳）
- `normal` 首尾同值：n=0 与 n=1 实测 `dlY 0 / dlS 1 / tabsY 0 / maskA 1` 完全相同
- prefab diff 只有 2 处（`m_Component` 多一条 + 文件尾 `!u!95`），对象总数 3070 → 3071
- 实拍：t=0 四周还是场景色，t=0.26 遮罩已盖住 ⇒ 遮罩淡入生效
- **待做**：重打 AB（新 clip/controller 是 prefab 的依赖，不打资源包真机还是旧包）

---

## 附录 E：升级礼包面板落地（2026-10-20，UpGradePackagePanel）

**这次的新情况：目标面板上已有一个「还在播」的 legacy clip**。`show` 节点带 `Animation`（`m_Enabled: 1`、
`m_PlayAutomatically: 1`），引 `cn2-X1_UI_UpGradePackagePanel_show_1.anim`（0.767s、`m_LoopTime: 1`）。
它已经在写：

| 路径 | 属性 | 干了什么 |
|---|---|---|
| `Button` | `m_LocalScale.x/y/z` | 按钮弹入 0 → 1.3 → 1.1 → 1.2（prefab 基准是 1.2，不是 1） |
| `Image` / `tabBox` | `m_SizeDelta.y` | 分割线、页签条 0 → 124.7 展开 |
| `tabBox/box/tab(Clone)/select` | `m_SizeDelta.y` + `m_Color.a` | 页签选中态脉冲 |
| `arrows` / `tabBox` | `m_IsActive` | 箭头闪烁 |
| `rewards/Grid` | `m_LocalScale` | **死曲线**（改版后节点叫 `rewards1/Grid`，路径绑不上） |

⇒ 这些通道一律不写；新 Animator 挂**根节点**，只写 `m_AnchoredPosition.y`、`m_Color.a` 和没人碰的
`show/bg`、`show/rewards1` 的 `m_LocalScale`。**不要为了"挂 Animator"去删这个 legacy Animation**：它承担着
按钮弹入与页签展开，删了这些动效就没了。

**层级与基准 y**：`bg` 0（1080 宽 = 画布宽 ⇒ 缩放**只放大不缩小**，缩了左右露边）/ `rewards1` −220 /
`tabBox` −560 / `endTime` −660 / `Button` −765（scale 1.2）。`btnBack` 是全屏无 sprite 黑底（alpha 0.5882353）⇒ 只写 alpha。

| 阶段 | 部件 | 曲线 |
|---|---|---|
| start 1.0s | `show/btnBack` alpha | 0 / .12 → 0, 0.5882353 |
| | `show/bg` | scale 1 / 1.06 / 1（.14/.26，只放大） |
| | `show/rewards1` | scale .92 / 1.04 / 1（.16/.30/.40）；y −240 → −220 |
| | `show/tabBox` | y −578 → −560（.15–.37，与 legacy 展开同窗口） |
| | `show/endTime` | y −678 → −660（.30–.52） |
| | `show/Button` | y −783 → −765（.43–.63，**只写位置**） |
| normal 3.0s | `show/bg` | scale 1 / 1.015 / 1 |
| | `show/rewards1` | y −220 / −229 / −220；scale 1 / 0.996 / 1 |
| | `show/tabBox` | y −560 / −555 / −560（与内容反相） |
| | `show/endTime` | y −660 / −663 / −660 |
| | `show/Button` | y −765 / −762 / −765 / −762 / −765（双脉冲） |

**产物**：`Assets/Art/UIAni/cn2-X1_UI_UpGradePackagePanel_float_{start,normal}.anim` +
`.controller`；配方 `.workbuddy-ai/skills/ui-panel-float-anim/scripts/configs/upgrade_package_panel.json`。
prefab diff 只有 2 处（`m_Component` +1 条、文件尾 `!u!95`），对象总数 141 → 142，3 个 legacy `!u!111` 原样保留。

**离线验收**：start 1.000s / 11 条编辑器曲线（7 条绑定）、normal 3.000s / 10 条（6 条绑定），`m_LoopTime` 0/1；
11/11 与 10/10 条曲线 `path` 哈希与 `genericBindings` 一一对应；normal 每条首尾同值；guid 链
prefab → controller(`9c44e0eb`) → 两个 clip 闭合；`m_WriteDefaultValues: 1` 且 `start` 末值 = prefab 默认值（切态不跳）。

**待做**：重打 AB（Unity 当前停在 Play mode 占着 `Temp/UnityLockfile`，batchmode 跑不了）。

---

## 附录 F：经营面板开启动画（2026-10-20，ExpertPanel，**Lua 驱动**）

**参考素材**：`Assets/Art/UIAni/cn2-X1_UI_SevenDayCarnivalPanelV2.anim`（挂在 `SevenDayCarnivalPanelV2`
根节点的 **legacy Animation** 上，prefab 里 `daysTabBg/tabsGroup` 是 `VerticalLayoutGroup`）：

| 项 | 值 |
|---|---|
| 曲线 | **9 条**：`m_ScaleCurves` 7 条（path = `bg/daysTabBg/tabsGroup/day_1..7`）+ `m_FloatCurves` 2 条（path = `bg`） |
| 单格 | scaleX `0 → 1`，0.1667s（10 帧 @60fps） |
| 错开 | 相邻两格 0.0333s，整体 0.3667s |
| 落位 | `bg` 的 `m_SizeDelta.y` 110→0、`m_AnchoredPosition.y` 55→0，0 → 0.3667s（见下节） |
| 循环 | `m_LoopTime: 1`（常驻循环） |

> 🔴 **上一轮踩的坑**：只 grep `m_ScaleCurves` 就这么读，结果漏掉了 `m_FloatCurves` 里那两条落位曲线，
> 交付后被指出「还有一个从上往下的前摇没复刻」。**读参考 clip 必须把所有 `m_*Curves` 段都过一遍**
> （`m_PositionCurves` / `m_EulerCurves` / `m_ScaleCurves` / `m_FloatCurves`），尤其 `m_FloatCurves`——
> `m_SizeDelta.y` / `m_AnchoredPosition.*` / `m_Color.a` 这些「不在 Transform 上的通道」全在这个段里。

> 只写 **scaleX**——`tabsGroup` 是 VerticalLayoutGroup，写位置每帧会被重算。这条和 §2 第 5 条一致。

**为什么不能照抄成 clip**（三个障碍，任一就够否掉静态曲线）：

| 障碍 | 证据 |
|---|---|
| 页签是 Lua 克隆 | `ExpertPanel.lua` 里 `newObjToParent(pre)` 克隆 `tabsContent/btn` 再 `name = "tab"..i`，数量随活动开关在 8~22 之间变 |
| 显示顺序 ≠ tab 下标 | `TabSort()` 按 `ActivityGroups.Sort` 调 `SetSiblingIndex` |
| 每格自带 Animator | `Animator(CommonButton.controller)`，Normal 状态是**单帧 clip**，照样每帧写 `m_LocalScale = 1` |

**做法**（全部在 `ExpertPanel.lua`，prefab 一行没动）：

| 函数 | 干什么 |
|---|---|
| `PlayTabFlipIn()` | 遍历 `tabs/viewPort/tabsContent` 的**子节点**（不是 tab 下标），跳过模板 `btn` 与 `activeSelf == false`，按顺序 `DOScale(one, 0.167):SetDelay(order * step)` |
| `PlayTabSelectFlip(index)` | 切换页签时只翻 `selected` 高亮板（该节点没有 Animator，不抢通道） |
| `StopOpenAnims()` | Kill 全部 tween + `localScale = one` + **恢复 `Animator.enabled`** + 落位复位；重播 / `OnClose` / `OnDestroy` / 异常回滚都走它（原名 `StopTabAnims`，加了落位后语义扩了） |

**🔴 必须先把该格的 `Animator.enabled` 置 false**：Unity 每帧顺序是 `Update → Animator 求值 → LateUpdate`，
DOTween 默认在 `Update`。Animator 后写 ⇒ tween 被每帧盖回去，现象是「代码跑了、页签没动」。
所以：翻入前 `anim.enabled = false`，`OnComplete` 里恢复（恢复后 Normal 写回 scale=1，与末值一致，不跳）。

**参数与自适应**：`0.167s/格`、`0.033s` 错开；可见数多时压缩错开，保证整段 ≤ `0.5s`
（20 格时实测错开 0.026，整体 0.66s 含单格时长）。**只播一次**——参考那边 loop=1 常驻循环，
但 20+ 格一直翻很吵。

**离线验证**（不启动 Unity，`/tmp` 里用假 `Util/Vector3/DOTween` 跑真源码）：

| case | 断言 | 结果 |
|---|---|---|
| 顺序与错开 | 6 个子节点（1 个模板、1 个 inactive）⇒ 只起 4 条 tween，延迟 0/0.033/0.066/0.099 | ✅ |
| 完成恢复 | 全部 `Complete()` 后 scale=1、`Animator.enabled=true` | ✅ |
| 中途 Stop | 全部 Kill，scale 与 Animator 全部复位 | ✅ |
| 数量自适应 | 24 格 ⇒ 末格延迟压到 0.5 | ✅ |
| 高亮板 | 从 0 起、重播前 Kill 上一个 | ✅ |

### 附带的「从上往下落」前摇（同一份参考 clip 的另两条曲线）

参考 clip 里 `bg` 上还有两条 `m_FloatCurves`，两者同时写 = **底边钉死、顶边从屏幕外上方往下落 110px**：

| 通道 | 曲线 | 时间 |
|---|---|---|
| `m_SizeDelta.y` | 110 → 0 | 0 → 0.3667s（两端切线都是 0 ⇒ 缓入缓出） |
| `m_AnchoredPosition.y` | 55 → 0 | 0 → 0.3667s |

四边拉满时 `sizeDelta.y` 就是「比父级高多少」：底边不动、顶边高 110；再配 `anchoredPosition.y +55`
让中心上移。合起来顶边落 110、中心落 55。

**为什么不能照抄到 `bg`**：参考里 `bg` 自己是个 `m_Sprite: {fileID: 0}` 的**全屏纯色遮罩**（黑色 alpha 0.7059），
它的矩形变化被屏幕裁掉、肉眼看不见；真正看得见的是**挂在 `bg` 下面的内容**（`finalTarget` 进度条、
`curProgress`）跟着下移 55px。本面板 `bg` 同样是全屏黑遮罩 ⇒ 所以把「落 110px」落到**承内容的 `downLayout`**：
它也是四边拉满、pivot 0.5、`anchoredPosition` 基准 `(0,0)`，几何等价、看得见。

| 函数 | 干什么 |
|---|---|
| `PlayDropIn()` | `anchoredPosition = (0, 110)` → `DOAnchorPos((0,0), 0.3667)`，`Ease.InOutQuad`，只播一次 |
| `StopDropIn()` | Kill + 复位 `(0,0)`；由 `StopOpenAnims()` 统一调用 |

`OnShow` 里两个动画**同时起**（和参考一致）：`PlayTabFlipIn()` 再 `PlayDropIn()`。顺序不能反——
`PlayTabFlipIn` 开头会 `StopOpenAnims()` 把一切复位。

**两个运行期 API 陷阱**（这次新踩）：

| 陷阱 | 说明 |
|---|---|
| `DOAnchorPos` 是 `RectTransform` 的扩展 | 直接 `go.transform` 得到的是 `Transform` 类型 userdata，**那种 userdata 上没有这个方法**；必须 `GetComponent("RectTransform")` |
| `Ease` 枚举是运行期注册的 | 取不到 `Ease.InOutQuad` 时不要硬索引，否则异常被 `pcall` 吃掉 ⇒ 整段动画静默不播。统一走 `SetEaseSafe(tween, "InOutQuad")`（`_G.Ease` 有值才 `SetEase`） |

**离线验证**（`/tmp/test_expert_openanim.lua`，假 `Util/Vector3/Vector2/DOTween` 跑真源码，7 个 case 全过）：

| case | 断言 | 结果 |
|---|---|---|
| 顺序与错开 | 6 个子节点（1 模板 + 1 inactive）⇒ 只起 4 条，延迟 0/0.033/0.066/0.099 | ✅ |
| 完成恢复 | 全部 `Complete()` 后 scale=1、`Animator.enabled=true` | ✅ |
| 中途 Stop | 全部 Kill，scale / Animator / 落位全部复位 | ✅ |
| 数量自适应 | 24 格 ⇒ 末格延迟压到 0.5 | ✅ |
| 高亮板 | 从 0 起、重播前 Kill 上一个 | ✅ |
| 落位 | 起点 +110、终点 (0,0)、0.3667s、`InOutQuad`、完成后精确落 0 | ✅ |
| 落位重播 | 上轮停在 +45 也**从 110 重起**，同一时刻只有 1 条存活 | ✅ |

**收尾**：`bash scripts/lua-bytes-sync.sh <lua 路径>` 重编 `LuaBytes/Modules_Expert_ExpertPanel_64.bytes`
（13403 → 15505 → 16608 B），`--check` 复验「已同步」。**只改源码不改字节码 = 真机不生效**。

> 同轮把根节点上那份「整面板 start 弹入 + normal 呼吸」的 Animator 撤了（方向搞错的那一版）：
> prefab 回滚到加 Animator 之前（对象数 3071 → 3070，`m_Component` 少一条 + 文件尾 `!u!95` 整块删除），
> clip/controller 资源留在库里不引用。现在这个面板的开启动画只有：**内容区落位 + 页签逐格翻入 + 高亮板翻入**。

---

## 附录 G：经营面板 OperatingPanel（2026-10-20，**Lua 驱动**，复用附录 F 的流程）

按 `ui_anim_reproduce_skill.md` 的流程走第二遍，参考仍是 `cn2-X1_UI_SevenDayCarnivalPanelV2.anim`
（9 条曲线：7 条 `m_LocalScale.x` + 2 条 `bg` 的 `m_FloatCurves`）。

**S0 体检（`audit_panel.py` + `dump_prefab_tree.py --rect` + `dump_clip.py`）**

| 节点 | 实况 | 处理 |
|---|---|---|
| `bg/Image` | 四边拉满、**有 sprite**、黑 alpha 0.502 | **不动**（不是纯色遮罩，参考那套"遮罩淡入"在本面板没有对应物） |
| `bg/pageContent` | 透明容器，四边拉满 / pivot 0.5 / 基准 `(0,0)`，挂 14 个子页 | 落位写它（几何与参考的 `bg` 等价，且看得见） |
| `bg/tabList` | ScrollRect，`viewPort` 有 RectMask2D，`tabsContent` 挂 VerticalLayoutGroup + ContentSizeFitter | 不写位置 |
| `tabsContent/tabs_1..19` | **静态节点**（不是运行时克隆），每个挂 `CommonButton` 的 Animator | 只写 scaleX，翻入期间临时 `enabled=false` |
| `bg/btnBack` | 自带 `CommonButton` 控制器 | 本次不写 |

**面板已自带的动画（必须通道互斥，一律不碰）**：

| clip | 挂了谁 | 写了什么 |
|---|---|---|
| `cn2-X1_UI_OperatingPanel_page_2` / `_page_8` | `page_2` / `page_8` 上的 legacy `Animation` | `smallImg/Image` 旋转（0→0.1667s）+ `m_Color.a` 0.56→1，loop=1（装饰循环） |
| `cn2-X1_UI_OperatingPanel_Page_7` | `page_7` | 页面内入场：`Panel/buyPart` scale 0→1、`Panel/reward`/`Panel/Bg` 的 y、`Panel/Bg` alpha |
| `cn2-X1_UI_Operatingpanel_pageContent_page_12` | `page_12` | 页面内入场：`btnBuy` scale、`title`/`itemGrid`/`Image1` 的 y |
| `cn2-X1_UI_Operatingpanel_pageContent_page_10` | `page_10` | **空 clip**（0 条曲线，死组件） |
| `UI_effect_OperatingPanel_normal` | 未被引用 | `fire01..05` 的 `material._MainTex_ST` UV 滚动（火光） |

**为什么仍走 Lua 而不是静态 clip**（页签明明是静态节点）：

| 判据 | 本面板 |
|---|---|
| 激活态由代码切换 | `RefreshTabStatus` 按活动开放状态 `SetActive`（福利 9 个 / 激励计划 5 个，且随活动开关变化）⇒ 未激活节点不参与求值 |
| 面板缓存复用 | 第二次打开不重播 ⇒ 静态 clip 还得 `Animator.Play`，那不如直接 Lua |
| 事件驱动 | 切页签要单独翻 `selected` 高亮板 |
| 数量自适应 | 可见页签 5~9 个，错开间隔要压缩 |

**实现**（`OperatingPanel.lua`，prefab 一行没动）：

| 函数 | 干什么 |
|---|---|
| `PlayTabFlipIn()` | 遍历 `tabsContent` 的**子节点顺序**（VerticalLayoutGroup 按 sibling 排版，prefab 里就是 12,5,11,1,9,4,13,10,2,3,…，**不是** 1..19），跳过 `activeSelf == false`，逐格 `scaleX 0→1` |
| `PlayTabSelectFlip(index)` | 切页签时只翻 `selected`（该节点没有 Animator，不抢通道） |
| `PlayPageDropIn()` | `bg/pageContent` 的 `anchoredPosition (0,110) → (0,0)`，0.3667s，`InOutQuad` |
| `StopOpenAnims()` | Kill 全部 tween + `scale=one` + 恢复 `Animator.enabled` + 落位复位（`OnShow` 首行 / `OnClose` / `OnDestroy`） |

参数沿用参考：`0.167s/格`、`0.033s` 错开、可见数多时压缩到 ≤ `0.5s` 跨度；落位 `110px / 0.3667s`。
`OnShow` 顺序：`OnTabChanged()`（确定可见页签与选中页）→ `PlayTabFlipIn()` → `PlayPageDropIn()`。
**顺序不能反**：`PlayTabFlipIn` 第一行 `StopOpenAnims()` 会把先起的落位杀掉（harness case8 已钉成断言）。

**离线验收**：`scripts/lua-tests/test_operating_openanim.lua`，8 个 case 全过
（顺序与跳过 / 完成恢复 / 中途 Stop / 压缩错开 / 高亮板重播 / 落位 / 重播不叠加 / 顺序约束）。
`bash scripts/lua-bytes-sync.sh` 重编 `LuaBytes/Modules_Operating_OperatingPanel_64.bytes`（9850 → 13329 B），`--check` 已同步。

**偏离参考之处**（显式记录，避免被当成漏做）：

- 参考 `day_2..7` 的关键帧是 `[1 @0, 0 @delay, 1 @delay+0.1667]`——**先保持原样、到延迟点才归零再长出来**（前 2 帧还看得见）。
  这里统一改成"从 t=0 就全隐藏，按顺序长出来"，与附录 F 的 ExpertPanel 一致，观感更干净。
- 参考 `m_LoopTime: 1` 常驻循环；这里只播一次（20 个页签一直翻太吵）。
- 参考的"落 110px"作用在不可见的全屏遮罩上；这里作用在承内容的 `pageContent`，位移量仍取 110（与 ExpertPanel 一致）。

**待做**：AB 重打；真机/实拍未做（需要登录态，纯 Lua 改动只能跑起来看）。
