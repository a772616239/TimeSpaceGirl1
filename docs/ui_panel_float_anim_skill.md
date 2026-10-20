# UI 面板浮动 / 呼吸动画（弹入 + 循环呼吸）

> 适用范围：TimeSpaceGirl1 项目（Unity 6000.6.5f1）
> 更新时间：2026-10-20
> 生成器脚本：`.workbuddy-ai/skills/ui-panel-float-anim/scripts/`（C# 模板 + Python 生成器 + prefab 树打印）
> 现成实现：`Assets/Editor/FirstRechargeFloatAnimBuilder.cs`、`Assets/Art/UIAni/cn2-X1_UI_FirstRechargePanel_float.*`

给任意 UI 面板加「弹入 + 循环浮动/呼吸」动画（每日首充 `DailyRechargePanel` / `UI_effect_DailyRechargePanel` 那套观感）。

结构就一句话：**根节点挂一个 Animator，两个状态** —— `start`（一次性弹入）→ `normal`（循环呼吸）。

关键不是"整体上下平移"，而是**各部件相位错开**：标题类往上、内容类往下、按钮高频脉冲，看起来才像整块在浮动。

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
| 黑底遮罩 | Image alpha `0 → 0.588`（有遮罩才做） |

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

按顺序问四个问题，任一命中就按"规避"列处理：

| # | 情况 | 怎么判断 | 规避 |
|---|---|---|---|
| 1 | 根节点有旧版 legacy `Animation` | prefab 根节点 `!u!111` | 删掉换 `Animator`（同一 GameObject 上二者不能共存） |
| 2 | 有 `PlayFlyAnim`(DOTween) 在写某个节点的位置 | 节点上有 `PlayFlyAnim.cs`，看 `tweenSequeue[].targetObj` | **不要写那个节点的 anchoredPosition**，只写 scale |
| 3 | 目标节点是布局组的子节点 | 父节点挂 `HorizontalLayoutGroup`（guid `30649d3a…`）/ `VerticalLayoutGroup` | **只能写 scale，不能写位置**（位置每帧被布局组重算） |
| 4 | 目标节点自己挂着 Animator（按钮常见：`CommonButton`） | 该节点 `!u!95` 且 `m_Enabled: 1` | **不要写它 clip 里已有的属性**：父子两级写同一属性时结果不可靠（首充实测按钮的缩放脉冲不生效），优先只写它没写的通道 |

拿不准就先打印层级：

```bash
python3 .workbuddy-ai/skills/ui-panel-float-anim/scripts/dump_prefab_tree.py <prefab> --depth 2
python3 .../dump_prefab_tree.py <prefab> --name frame --depth 3   # 只看某个子树
```

输出每节点的 `pos / size / 组件（含脚本名、Animator 的控制器名）`，`pos` 的 y 就是曲线里的 `baseY`（曲线写的是绝对值，必须和 prefab 一致）。首跑约 15s 建 guid 索引，之后 6 小时命中 `/tmp` 缓存，约 0.3s。

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

```bash
python3 .workbuddy-ai/skills/ui-panel-float-anim/scripts/gen_float_anim_yaml.py \
    --prefab <prefab 路径> --base <资源名前缀> [--out-dir /tmp/x] [--no-prefab]
```

直接写 `.anim` / `.controller` 并改 prefab，**不需要 Unity 参与**。已 diff 验证：输出与 Unity 生成的 clip **逐字节一致**。

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

## 5. 六个坑

| 坑 | 现象 | 原因 |
|---|---|---|
| 手写 `.anim` 哈希算错 | 不报错，但完全不播 | 见上一节；改 path 必须同步改 `m_ClipBindingConstant` |
| 复用别的面板的 controller | 不报错，也不播 | 曲线按**层级路径**绑定，`frame/bg` ≠ `frame/BG`（大小写敏感） |
| 在 `OnEnable` 里手写 `Animator.Play` | 重复打开时弹入不重播 | 面板是缓存复用的；`KeepAnimatorStateOnDisable = 0` 才会在禁用后重置到默认状态 |
| 写了 `sizeDelta` | 每帧 LayoutGroup 重建，掉帧 | 只写 `m_AnchoredPosition.*` / `m_LocalScale.*` / `m_Color.a` |
| 曲线首尾不等 | 循环处"跳一下" | normal 的第一个 key 和最后一个 key 必须同值 |
| 忘了 AB | 编辑器里好看，真机没变化 | prefab + 新 clip/controller 都要进包 |

---

## 6. 验收清单

- [ ] Console 有 `loop=True`（或 clip 里 `m_LoopTime: 1`）
- [ ] 第一次打开有弹入；关掉再开**不会**再弹（缓存复用，符合预期）
- [ ] 静止 3 秒以上，各部件在轻微呼吸，循环处无跳变
- [ ] 按钮点击态正常（没被子级 Animator 抢掉）
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
