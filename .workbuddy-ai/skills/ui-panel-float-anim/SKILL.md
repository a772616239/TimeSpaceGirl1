---
name: ui-panel-float-anim
description: 给任意 UI 面板加「弹入 + 循环浮动/呼吸」动画（每日首充 DailyRechargePanel / UI_effect_DailyRechargePanel 那套观感）。当需求是「把 X 面板改成 Y 面板那种浮动动画」「面板太死板加个呼吸」「抄每日首充的动画」时使用。关键词：浮动动画、呼吸动画、弹入、start normal、Animator、AnimatorController、AnimationClip、UI_effect_DailyRechargePanel、FirstRechargePanel、DailyRechargePanel、PlayFlyAnim、CommonButton、legacy Animation、m_ClipBindingConstant。
agent_created: true
---

# UI 面板浮动 / 呼吸动画

每日首充那套观感 = **根节点一个 Animator + 两个状态**：`start`（一次性弹入）→ `normal`（循环呼吸）。
关键不是"整体上下平移"，而是**各部件相位错开**：标题类往上、内容类往下、按钮脉冲，看起来才像整块在浮动。

## 两种动画的配方（直接抄数字）

### start：弹入（1.0s，不循环，0.9s 处 0.1s 混合进 normal）

| 部件 | 曲线 |
|---|---|
| 主体 | scale `0 → 1.8 → 0.8 → 1.1 → 1`（0 / .13 / .27 / .37 / .5s）——"啪"一下弹出来 |
| 标题条 | scale `3 → 0.8 → 1`，alpha `0 → 1`（.37s 起） |
| 说明区 | scaleX `0 → 1.15 → 0.9 → 1`（横向挤压回弹） |
| 奖励格 | 逐个 scale `0 → 1.2 → 1`，彼此错开 0.06~0.1s |
| 按钮 | scale `0 → 1.5 → 1`，位置从下方 18px 落位 |
| 遮罩 | Image alpha `0 → 0.588`（有黑底遮罩才做） |

### normal：循环呼吸（3.0s，`m_LoopTime = 1`）

| 部件 | 曲线 | 相位 |
|---|---|---|
| 主体底板 | scale `1 → 1.02 → 1` | 0 / 1.5 / 3 |
| 标题条 | y `+5` | 与内容区反相 |
| 说明区 | y `-10` | 向下 |
| 奖励区 | y `-10`，scale `1 → 0.99 → 1` | 向下 |
| 底部按钮 | scale `1 → 1.1 → 1` + y `+2`，**一个循环两次脉冲**（0 / .73 / 1.5 / 2.33 / 3） | 高频 |
| 其他小字 | y `-3` | 跟随内容区 |

> 只放大不缩小（1.02 而不是 0.98）——缩下去会露边/穿帮。
> 奖励区那条「0.99」是每日首充的格子容器；如果目标面板是一整块卡片，用 1.015 往上呼吸更自然（首充就是这么改的）。

## 30 秒判断：这个面板能不能照搬

按顺序问四个问题，任一命中就按"规避"列处理：

| # | 情况 | 怎么判断 | 规避 |
|---|---|---|---|
| 1 | 根节点有旧版 legacy `Animation` | prefab 根节点 `!u!111` | 删掉换 `Animator`（同一 GameObject 上二者不能共存） |
| 2 | 有 `PlayFlyAnim`(DOTween) 在写某个节点的位置 | 节点上有 `PlayFlyAnim.cs`，看 `tweenSequeue[].targetObj` | **不要写那个节点的 anchoredPosition**，只写 scale |
| 3 | 目标节点是布局组的子节点 | 父节点挂 `HorizontalLayoutGroup`（guid `30649d3a…`）/ `VerticalLayoutGroup` | **只能写 scale，不能写位置**（位置每帧被布局组重算） |
| 4 | 目标节点自己挂着 Animator（按钮常见：`CommonButton`） | 该节点 `!u!95` 且 `m_Enabled: 1` | **不要写它 clip 里已有的属性**：父子两级写同一属性时结果不可靠（首充实测按钮的缩放脉冲不生效），优先只写它没写的通道 |

## 落地四步

1. **拿基准值**（曲线写的是绝对值，必须和 prefab 一致）：
   ```bash
   python3 .workbuddy-ai/skills/ui-panel-float-anim/scripts/dump_prefab_tree.py <prefab> --depth 2
   python3 .../dump_prefab_tree.py <prefab> --name frame --depth 3   # 只看某个子树
   ```
   输出每节点的 `pos / size / 组件（含脚本名、Animator 的控制器名）`，`pos` 的 y 就是 `baseY`。
   首跑约 15s（建 guid 索引），之后 6 小时内命中 `/tmp` 缓存，约 0.3s。
2. **复制模板**：`scripts/UIPanelFloatAnimBuilder.template.cs` → `Assets/Editor/XxxFloatAnimBuilder.cs`，
   **改类名（与文件名一致）**，只填配置区（`PrefabPath` / `AssetDir` / `BaseName` / `Nodes`）。
3. **点菜单**：`Tools/UI/<面板名>/生成并挂载浮动动画`。Console 会打
   `状态机 start(1.00s, loop=False) → normal(3.00s, loop=True)`，直接确认循环有没有生效。
4. **重打 AB**：新 clip/controller 是 prefab 的依赖，不打 AB 真机还是旧包。

## 配置区怎么写

```csharp
static readonly NodeCfg[] Nodes =
{
    // path, baseY, 呼吸峰值, normal位移, start起始缩放, start峰值, start延迟, 写位置, 写缩放
    N("frame/BG",        0f,       1.02f,  0f,    1f,  1.2f, 0f),      // 主体：弹一下 + 呼吸
    N("frame/title",     156.64f,  1f,     5f,    0.85f, 1.06f, 0.30f), // 标题：往上飘
    N("frame/rewardBg", -226.18f,  1.015f, -10f,  0f,  1.12f, 0.40f),  // 内容：往下沉
    N("frame/btn",      -600f,     1f,     2f,    0f,  1.5f,  0.72f, true, false), // 按钮：只写位置
};
```

- `start起始缩放 = 1 且 start峰值 = 1` → 这个节点不做弹入
- `start起始缩放 = 0` → 从无到有弹出来；`= 1` → 原地"顶一下"
- 最后一个参数 `写缩放 = false` 用于自带 Animator 的按钮
- 需要"一个循环两次脉冲"的按钮，把 `doublePulse` 打开（`N(...)` 末尾加 `pulse: true`）

## 六个坑（都踩过，别再踩）

| 坑 | 现象 | 原因 |
|---|---|---|
| 手写 `.anim` | 不报错，但完全不播 | `m_ClipBindingConstant` 里是路径的哈希值，改 path 不改哈希就绑不上。**必须让 Unity 生成 clip** |
| 复用别的面板的 controller | 不报错，也不播 | 曲线按**层级路径**绑定，`frame/bg` ≠ `frame/BG` |
| 在 `OnEnable` 里手写 `Animator.Play` | 重复打开时弹入不重播 | 面板是缓存复用的；`Animator` 的 `KeepAnimatorStateOnDisable = 0` 才会在禁用后重置到默认状态 |
| 写了 `sizeDelta` | 每帧 LayoutGroup 重建，掉帧 | 只写 `m_AnchoredPosition.*` / `m_LocalScale.*` / `m_Color.a` |
| 曲线首尾不等 | 循环处"跳一下" | normal 的第一个 key 和最后一个 key 必须同值 |
| 忘了 AB | 编辑器里好看，真机没变化 | prefab + 新 clip/controller 都要进包 |

## 验收清单

- [ ] Console 有 `loop=True`
- [ ] 第一次打开有弹入；关掉再开**不会**再弹（缓存复用，符合预期）
- [ ] 静止 3 秒以上，各部件在轻微呼吸，循环处无跳变
- [ ] 按钮点击态正常（没被子级 Animator 抢掉）
- [ ] 切页签 / 反复开关 10 次，没有节点卡在 scale 0 或位置错乱
- [ ] AB 重打后真机复验

## 参考资料

- `scripts/UIPanelFloatAnimBuilder.template.cs` — 配置驱动的生成器模板（已用 Unity 6000.6.5f1 程序集编译校验）
- `scripts/dump_prefab_tree.py` — 打印 prefab 层级 + anchoredPosition + 组件，取基准值和路径用
- `references/case-firstrecharge.md` — 案例：首充面板（含每日首充的原始曲线数据与冲突分析）
- 工程内现成实现：`Assets/Editor/FirstRechargeFloatAnimBuilder.cs`
