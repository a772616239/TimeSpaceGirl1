# 案例：首充面板（FirstRechargePanel）

需求原话：「FirstRechargePanel 可以把界面改成这种 DailyRechargePanel 浮动动画 UI_effect_DailyRechargePanel 的形式吗」。
结论：**不能直接复用那个 controller**，只能照着做一套。

## 一、每日首充的原始数据（照着抄的源头）

`Assets/Art/EffectsOld/Animation/UI_effect_DailyRechargePanel.controller`
→ 根节点 `DailyRechargePanel` 上的 Animator（guid `fb0b5c1491552e94dafbcf3a29989765`）

两个状态：`_start`（默认，1s，exitTime 0.75 + 0.25s 过渡）→ `_normal`（3s，`m_LoopTime: 1`）。

### _start（1s，不循环）

| 路径 | 属性 | 曲线 |
|---|---|---|
| `frame/bg` | scale | 0 / .13 / .27 / .37 / .5 → 0, 1.8, 0.8, 1.1, 1 |
| `frame/bg/title` | scale | .37 / .5 / .67 → 3, 0.8, 1 |
| `frame/bg/title` | alpha | .37 / .5 → 0, 1 |
| `frame/bg/descbg` | scaleX | .27 / .4 / .57 / .7 → 0, 1.15, 0.9, 1 |
| `frame/bg/rewardContent/itemPos_1..4` | scale | 从 .4 起每个错开 .067s：0 → 1.2 → 1 |
| `frame/bg/dealBtn` | scale | .7 / .83 / 1 → 0, 1.5, 1 |
| `frame`（黑底遮罩 Image） | m_Color.a | 0 / .27 / 1 → 0, 0.588, 0.588 |

### _normal（3s，循环）

| 路径 | 属性 | 曲线 | 观感 |
|---|---|---|---|
| `frame/bg` | scale | 0 / 1.5 / 3 → 1, 1.02, 1 | 主体呼吸 |
| `frame/bg/title` | y | 90 / 95 / 90 | 标题**上**飘 |
| `frame/bg/descbg` | y | 0 / -10 / 0 | 说明区**下**沉 |
| `frame/bg/rewardContent` | y | -458 / -468 / -458 | 奖励区下沉 |
| `frame/bg/rewardContent` | scale | 1 / 0.99 / 1 | 轻微收缩 |
| `frame/bg/dealBtn` | y | -702 / -700 / -702 / -700 / -702 | 两次脉冲 |
| `frame/bg/dealBtn` | scale | 1 / 1.1 / 1 / 1.1 / 1 | 两次脉冲 |

> 手感的关键：**标题往上、内容往下、按钮高频**，三者相位不同。整体平移是"飘"，这样才是"呼吸 + 浮动"。

## 二、首充的层级对不上（为什么不能复用）

| 每日首充 | 首充 | 差异 |
|---|---|---|
| `frame/bg`（面板主体） | `frame/BG` | 大小写不同（**路径区分大小写**） |
| `frame/bg/title` | `frame/tabsContent` | 名字不同 |
| `frame/bg/descbg` | `frame/rewardBg` | 名字不同 |
| `frame/bg/rewardContent` + `itemPos_1..4` | `frame/rewardBg` + `rewardDay1..3` | 层级与数量都不同 |
| `frame/bg/dealBtn` | `frame/rechargeBtn` | 名字不同 |
| `frame`（黑底遮罩 Image） | `frame`（只有 CanvasRenderer + PlayFlyAnim） | 首充没有遮罩 |

曲线按路径绑定，路径错一条就静默不播。所以必须按首充自己的层级重新生成 clip。

## 三、首充原有的两套开场动画（互相打架）

| 来源 | 干了什么 |
|---|---|
| 根节点 legacy `Animation`（`cn2-X1_UI_FirstRechargePanel.anim`） | `frame` y -724→-215（0.18s）、`frame` scale 1→1.2→0.95→1、`hero` scale 1→1.3→0.95→1；**播完就静止** |
| `frame` 上的 `PlayFlyAnim`(DOTween) | `frame.anchoredPosition3D` (0,-1000,0)→(0,0,0)，1s；`FadeChild` 所有子 Graphic alpha 0→1，0.8s |

两者**同时写 `frame.anchoredPosition`** ⇒ 开场前 0.18s 互相抢，本来就有抖动。
把 legacy `Animation` 摘掉换成 `Animator`（且新 clip 不写 `frame` 位置）顺手修掉了这个抖动。

## 四、三个冲突点与决策

| 冲突 | 证据 | 决策 |
|---|---|---|
| `frame` 位置被 PlayFlyAnim 占用 | `frame` 上 `PlayFlyAnim.tweenSequeue[0].targetObj` = frame 自己的 RectTransform，`changeType: 0 (Move)`，走 `anchoredPosition3D` | 新 clip **不写** `frame` 的 anchoredPosition，只写 scale（PlayFlyAnim 不碰 scale） |
| `rewardDay1..3` 位置由布局组接管 | 父节点 `rewardBg` 挂 `HorizontalLayoutGroup`（guid `30649d3a…`），卡片自身 `anchoredPosition` 都是 (0,0) | 只写 scale，**不写位置** |
| `rechargeBtn` 自带 Animator | `rechargeBtn` 上 `Animator(CommonButton.controller)`，其 `Normal` 状态 clip 单帧写自身 `m_LocalScale = 1` | 只写位置（y 脉冲），**不写缩放** |

> 顺带发现：每日首充的 `dealBtn` 自己也挂着 `CommonButton`，它 normal 里的 scale 脉冲曲线**很可能同样是条死曲线**（被子级覆盖），真机上看起来有效果多半是因为 y 脉冲。要确认得在真机/编辑器里把 CommonButton 临时禁用对比。

## 五、首充实际生成的参数

`Assets/Editor/FirstRechargeFloatAnimBuilder.cs`（配置驱动模板见 `scripts/UIPanelFloatAnimBuilder.template.cs`）

| 节点 | baseY | start | normal |
|---|---|---|---|
| `frame` | — | scale 1→1.2→0.95→1（0/.13/.22/.32s） | — |
| `hero` | — | scale 1→1.3→0.95→1（0/.07/.27/.37s） | — |
| `frame/tabsContent` | 156.64 | scale .85→1.06→1，y 上移 20 落位（.30s 起） | y +5 |
| `frame/rewardBg` | -226.18 | scale .88→1.05→1，y 上移 18 落位（.40s 起） | y -10，scale 1→1.015→1 |
| `frame/rewardBg/rewardDay1..3` | — | scale 0→1.12→1，分别 .50/.58/.66s | — |
| `frame/rechargeBtn` | -600 | y 上移 18 落位（.72s 起） | y +3 双脉冲 |
| `frame/tips` | -462 | y 上移 18 落位（.78s 起） | y -3 |
| `frame/BG` | — | — | scale 1→**1.02**→1（主体呼吸） |

## 六、验收时注意

- 面板是缓存复用的（`UIManager.openedList`），第二次打开**不会**重播 start，这是预期
- `Animator.m_KeepAnimatorStateOnDisable` 保持 0，禁用后再启用才会重置回默认状态
- 新 clip / controller 是 prefab 的依赖，**不打 AB 真机不变**
