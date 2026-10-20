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
| 立绘容器 | `Panel/heroRoot`（空节点，位移专用） | 0 | y 由 −46 升到 0（0→0.42s） | y +8（呼吸，与底板同相位） |
| 立绘本体 | `Panel/heroRoot/hero` | —（位置归 Lua） | scale 1 → 1.25 → 0.97 → 1 | 不动 |
| 标题 | `Panel/Middle/Text` | −248 | scale 1 → 1.12 → 1（0.30 起） | y +5 |
| 奖励区 | `Panel/Middle/Reward` | −395 | scale 0.86 → 1.04 → 1 + y 由 −413 落位 | y −10，scale 1.015 |
| 奖励三格 | `Panel/Middle/Reward/Panel1..3` | 0 | scale 0 → 1.12 → 1，错开 0.08s | 不动 |
| 按钮 | `Panel/Middle/DoneBtn` | −805 | y 由 −823 落位（**只写位置**） | y 双脉冲 +3 |
| 进度 | `Panel/Middle/progress` | −715 | y 落位 18px | y −3 |
| 活动时间 | `Panel/Middle/textTime`、`freshTime` | −907 | y 落位 18px | y −3 |

**这个面板特有的三个坑**：

| 坑 | 证据 | 处理 |
|---|---|---|
| `hero` 的位置归 Lua | `SupremeHeroPopup.lua:75` 非中文语言会把 `hero.transform.localPosition` 改成 `(338,266)` | **不要直接给 `hero` 写 `anchoredPosition.y`**（会被语言偏移冲突：动画每帧写回就把它按回 0）。在 `Panel` 与 `hero` 之间插一个空节点 `heroRoot`（(0,0)/中心锚点/同尺寸，`sibling index` 仍留最后一位保证渲染顺序），位移写 `heroRoot`、缩放写 `hero`。`heroRoot` 基准是 0 ⇒ 纯偏移，叠加在 Lua 写的位置之上，中文/非中文都对 |
| `DoneBtn` / `Button_Go` / `Button_Get` 自带 `CommonButton` 控制器 | 三个按钮都是 `Animator(CommonButton.controller)` | 只写位置，不写缩放 |
| 黑底遮罩就是 `Panel` 自己的 Image（不是独立节点） | `Panel` 的 Image `m_Color = (0,0,0,0.7058824)`，`btnBack` 只是 a=0.004 的点击层 | start 里给 `Panel` 写 `m_Color.a` 0 → 0.7058824（与 prefab 默认同值，切 normal 不跳） |

**生成器这次补的两个能力**（`gen_float_anim_yaml.py`）：

- `--config <json>`：换面板只加一个 JSON 配方（`scripts/configs/supreme_hero_popup.json`），不再改脚本里的 `CURVES`
- `m_Color.a` 曲线（`attribute: 304273561`、`typeID: 114`、script 取组件自己的 `m_Script`）+ **prefab 已是 Animator 时只换 controller guid**（不再要求 legacy `!u!111`）

### 通用套路：节点位置已经被代码写死时，怎么加位移动画

判据：面板 Lua/C# 里有 `xxx.transform.localPosition = ...` 或 `anchoredPosition = ...`。
**直接给同一个节点写位置曲线会被覆盖**（哪怕代码只写一次，动画每帧都会盖掉它），所以：

1. 在该节点外插一个空容器（只挂 RectTransform，中心锚点、pivot 0.5、`anchoredPosition (0,0)`、尺寸取同值）；
2. 位移曲线写给容器（基准恒 0 ⇒ 纯偏移），缩放/透明度仍写原节点；
3. 原节点的**名字和查找路径**要么保持不动、要么同步改所有引用（本面板因为 `Util.GetGameObject` 是 `Transform.Find` 路径查找，改了 Lua 的 `Panel/hero` → `Panel/heroRoot/hero`，源码与 `LuaBytes` 成对重编）；
4. 容器插进父节点 `m_Children` 时**替换原节点的位置**（同一个 sibling index），否则会改变渲染顺序（UI 是按 sibling 顺序画的）；
5. 空容器不需要 `CanvasRenderer`，`m_Layer` 跟同级一致即可。

**为什么这次走路 B**：Unity 停在 Play mode，脚本编译被阻塞 ⇒ 新写的 C# builder 编译不出来、菜单也点不了；
而手写 clip 不依赖 Unity 编译。产出的 prefab diff 只有 **1 行**（`m_Controller` 的 guid），对象总数 296 → 296。

**验收记录**：

- Unity 回读：`start` 1.000s / 28 条曲线、`normal` 3.000s / 13 条曲线、`loopTime` 分别 False/True、
  `missingPaths=0`（⚠️ 这条第一次是**假阳性**，锚点按根节点算的；见下方事故复盘，修复后按 `Animator.transform` 复验仍为 0）
- 结构：`Panel` 子节点顺序 `btnBack, fanhuiBtn, Middle, heroRoot`（`heroRoot` 占原 `hero` 的位置）、对象数 296 → 298
- 离线：13/13 与 8/8 条曲线的 `path`/`attribute` 哈希与 `genericBindings` 一一对应；normal 每条曲线首尾同值
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

