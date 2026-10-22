# 面板开关「滑动」动画（抽屉进出 + 关闭延迟）

> 落地：`Modules/Setting/SettingPanel.lua`（2026-10-22，设置面板）
> harness：`scripts/lua-tests/test_settingpanel_slide.lua`（32 assertions，纯 Lua 离线跑）
> 姊妹文档：`ui_item_slide_in_skill.md`（列表项滑入）、`ui_panel_float_anim_skill.md`（弹入+呼吸）

---

## 0. 一句话总则

**打开 = 从屏外滑到位 + 遮罩淡入；关闭 = 滑出屏外 + 遮罩淡出，播完再真正关面板。**
关闭"延迟"必须接 `UIManager` 的 `OnCloseBefore(callback)` 钩子，不要在面板里自己
`Timer` 后再 `UIManager.ClosePanel` —— 引擎侧本来就有两条路径在等这个回调。

---

## 1. 引擎侧事实（改之前先看这段）

`Framework/Manager/UIManager.lua` 里 `OnCloseBefore` 有 **两个调用点**，语义不同：

| 调用点 | 传进来的 callback 是什么 | 面板要不要关 |
|---|---|---|
| `CloseStackPanel` / `CloseFixedPanel`（L725/839） | `closeAction`（真正 `SetActive(false)` + `CloseUI`） | 要关：callback 就是"关掉" |
| `GetPanel`（L630-653，**开新全屏面板时**） | "动画播完了，继续开新面板" | **不关**：只播动画，播完继续 |

⇒ `OnCloseBefore` 只能做「播动画 → 调 callback」，**绝不能自己动 `SetActive`/`CloseUI`**。
第二条路径下，面板会停在"滑出屏外 + 遮罩 0"的状态、仍在 `stackList` 里；下次它被
`OpenUI(true)` 唤回时收到的是 `OnShow`（**不走 `OnOpen`**）——所以"从屏外滑回来"必须
在 `OnShow` 里按**状态**判断，不能只看 `OnOpen` 的标记。

两条路径都会在动画期间 `eventSystem:SetActive(false)`，所以这 0.2s 内玩家点不到任何东西。

---

## 2. 配方（直接抄数字）

| 项 | 值 | 说明 |
|---|---|---|
| 滑入 | 0.28s `OutQuad` | 起点 = 基准 x − travel |
| 滑出 | 0.22s `InQuad` | 终点 = 基准 x − travel |
| 遮罩 | 0.20s 淡入/淡出 | 比位移略快，收尾干净 |
| travel | **现场量**：内容最右边缘 + 30 | 不写死。设置面板实测 874 + 30 = 904（屏宽 1080） |

**位移写哪**：所有要一起走的**兄弟节点各自记基准 `anchoredPosition.x`**，只写 `.x`。
设置面板要写两个：`BackMask/bg`（底板，基准 202）与 `layout`（内容容器，基准 0）。
一条静态 clip 绑不了两个不同基准的兄弟节点，Lua 侧各存一份最省事。

**只写 `anchoredPosition.x`**，别碰 `sizeDelta`（会被 fitter/布局组每帧改回去），
更别给无 sprite 的满屏遮罩写位移（见 §4 第 2 条）。

---

## 3. 位移量为什么要"现场量"

面板宽度 ≠ 可见内容宽度。设置面板底板只有 405 宽，但内容（`duanWei` 段位那一行）一直
伸到 874 —— 按底板宽度滑 405，关闭后右半截内容和返回按钮还挂在屏幕上。

量法（`SettingPanel.lua:MeasureRight`）：从内容容器递归，把每个**有 `CanvasRenderer`**
的活动节点的 `rect.xMax` 变换到 root 本地坐标取 max，再加 root 的 pivot 偏移换算成
"距屏幕左边缘"，最后 `+ 30` 余量、上限夹到屏宽。

🔴 **纯容器不能算进去**：`layout` / `settingInfo` 是满屏尺寸的透明容器，算进去直接把
travel 顶到 1080（多滑 500px、开场还有 0.1s 什么都不动）——只认 `CanvasRenderer` 就是这么来的。

量不到（取不到 RectTransform / 子树全空）时走 `屏宽 × 0.75 + 30` 兜底，绝不让它变成 0
（travel = 0 就是"根本没有动画"，虽然不崩但等于白做）。

---

## 4. 七个坑

| 坑 | 现象 | 规避 |
|---|---|---|
| ① `OnCloseBefore` 里顺手把面板关了 | 打开新全屏面板时旧面板被真的关掉/报 nil | 只播动画 + 调 callback，见 §1 |
| ② 给满屏无 sprite 遮罩写位移 | 滑入瞬间整块黑底跟着平移，边缘露场景 | 遮罩只写 `Image.color.a`（`DOFade`） |
| ③ 关闭后把节点的位置复位 | 面板"被新面板盖住"那条路径下会原地闪现一下再消失 | 关闭结束停在**屏外**（state=hidden），只有真关掉（`OnClose`）才复位 |
| ④ 只在 `OnOpen` 里起播 | 被新面板盖住后回头显示（`OpenUI(true)`）不动，停在屏外 | `OnShow` 里按 `state == "hidden"` 补播 |
| ⑤ 每次 `OnShow` 都起播 | 已在原位的面板被重新 Show 时会莫名"飞一次" | 用 `OnOpen` 置的一次性标记 + `hidden` 状态双判据 |
| ⑥ tween 的 `OnComplete` 当唯一出口 | `DOTween.KillAll`/切场景把 tween 杀掉后回调不触发 ⇒ **面板关不掉、新面板打不开** | 加超时兜底 `Timer.New(Finish, 时长 + 0.35)`；`Finish` 用 `finished` 标志幂等 |
| ⑦ 播放中再次请求关闭就覆盖 | 第一个 callback 被丢掉 ⇒ 卡死 | callback 排队（`closeCbs`），播完逐个 `pcall` 放行 |

补两条实现细节：

- `Ease` 枚举是 tolua 运行期注册的，取不到 `InQuad` 时**不要硬索引**（异常被 `pcall` 吃掉会整段静默不播），统一走 `SetEaseSafe(tween, "InQuad")`。
- `DOAnchorPosX` 是 `RectTransform` 的扩展：`go.transform` 拿到的是 `Transform` userdata，
  上面没有这个方法，必须 `GetComponent("RectTransform")`。

---

## 5. 验收（离线可做，不用开 Unity）

```bash
cd LuaEncoder/luajit_mac/64
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_settingpanel_slide.lua
# ⇒ 设置面板开关滑动：32 passed, 0 failed
```

harness 用假 `BasePanel/Util/RectTransform/DOTween/Timer` 跑**真源码**，覆盖：
打开滑入 / 位移量（内容右边缘 + 30）/ 关闭播完才回调且恰好 1 次 / 播放中二次请求排队 /
复位 / 从屏外回来的 OnShow 补播 / 原位不空播 / 缺节点立即放行 / tween 被 Kill 的超时兜底 / 兜底宽度。

真机前还要做：`bash scripts/lua-bytes-sync.sh <lua>` 重编字节码（只改源码 = 真机不生效），
然后跑一遍「打开→返回、打开→点新面板、连点返回 5 次」看有没有卡在屏外或半截位置。

---

## 6. 设置面板落地记录（2026-10-22）

| 项 | 值 |
|---|---|
| 面板 | `Assets/ManagedResources/Prefabs/UI/Setting/SettingPanel.prefab`（未改一行） |
| 平移节点 | `BackMask/bg`（baseX 202）、`layout`（baseX 0） |
| 遮罩 | `BackMask`，无 sprite，`color = (0,0,0,0.8)`，只淡 alpha |
| travel | 874 + 30 = 904（实测内容最右 = `settingInfo/playerInfo/duanWei/Text` 的 874） |
| 字节码 | `LuaBytes/Modules_Setting_SettingPanel_64.bytes`（`--check` 已同步） |

`selectBtn` / `btnList` 现在是 `INACTIVE`（老版页签遗留），不在 `layout` 里，所以不参与滑动；
将来若启用，要么挪进 `layout`，要么追加进 `kSlideNodes`。
