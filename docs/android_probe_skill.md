# adb 探测/校准：把「点一下看图」压成批处理（`scripts/android_probe.py`）

> 更新时间：2026-10-23
> 关联：`docs/functional_test_automation.md`（设备用例框架）、`docs/android_emulator_smoke.md`（冒烟）、
> `jenkins-shared/lib/android/case_run.py`（正式执行器）
> 一句话：**判「点了有没有反应」不需要看图，只需要知道画面变了多少。**

---

## 1. 它解决什么

调设备用例时的老循环是：`tap → screencap → 读图 → 人判断 → 再 tap`。两个代价都很高：

| 代价 | 老循环 | 用 probe |
|---|---|---|
| 单步耗时 | adb 往返 + 一次模型读图，3~8s | 纯 adb，1~2s |
| 读图成本 | 一张 1080×2340 截图 ≈ 1.5k tokens | 8 张拼一张联系表 ≈ 1.5k tokens |
| 一条 10 步用例 | ~1 分钟 + ~15k tokens | ~25 秒 + ~1.5k tokens |

**实测（2026-10-23，vivo V2002A）**：8 步底栏点击，一次调用 25 秒，
输出 1 张文字表 + 1 张联系表 —— 相当于原来 8 次往返、8 张图。

---

## 2. 三个命令

```bash
PY=/Users/wangxufeng/.workbuddy-ai/binaries/python/envs/default/bin/python   # 需要 Pillow

# ① 批量执行 + 每步变化率（主力用法）
PACKAGE=com.Warera.timespace $PY scripts/android_probe.py seq \
    --plan /tmp/plan.json --out /tmp/probe/bar --cols 4

# ② 已有截图拼联系表（一次看图覆盖 N 步）
$PY scripts/android_probe.py montage --out /tmp/sheet.png --cols 4 /tmp/probe/bar/*.png

# ③ 图片指纹（dHash），给 CI 做「是不是这个界面」的断言，不用人看图
$PY scripts/android_probe.py sig /tmp/probe/bar/01_bag.png /tmp/golden/bag.png
```

`seq` 每步输出一行：

```
shot               change   bbox                   size    focus / note
01_bag             79.8%    (0,45,1080,2214)       1182KB  tap(390,2150) · com.Warera.timespace/...
02_hero            0.1%     (766,43,895,78)        1181KB  tap(250,2150) · com.Warera.timespace/...
```

---

## 3. 变化率怎么读（⚠️ 只是提示，不是判定）

变化率 = 1/8 缩图后亮度差 > 18 的块占比（先缩小再比，是为了压掉粒子/呼吸光效）。

**实测结论（2026-10-23，本工程主城，务必先看这段）**：

| 对比 | 变化率 |
|---|---|
| 同一屏、相隔 3 秒（只有背景动效） | **36% ~ 60%** |
| 真的换了界面（公告弹窗 → 主城 / 主城 → 面板） | **30% ~ 36%** |

两者区间**重叠**，所以**没有任何阈值能把「点了有反应」和「没反应」分开**。
根因：主城背景有月亮、星空、粒子、镜头微移，大面积像素一直在变；而面板本身是半透明暗色，
叠上去反而只改变了中间一块。

所以：

- 变化率只用来看「这一步是不是完全静止」（< 5% 基本等于 adb 没送到）；
- **判「面板有没有打开」只能看联系表**（`--montage`），一次看图覆盖 N 步；
- 别再加阈值自动判绿 —— 会给出看起来很确定、其实是错的结论。
  dHash 指纹在 16×16 分辨率下同样失效（同屏 1~13、异屏 4~6，分不开）。

> 这条弯路值得记下来：**自动化判定的前提是「同屏差异 < 异屏差异」，这个游戏不满足**。
> 想做无人值守断言，只能上金标准截图 + 指定区域（例如只比标题条那一条），或者让客户端打日志。

---

## 4. plan.json

```json
{"steps": [
  {"shot": "00_home"},
  {"tap": [390, 2150], "wait": 2.5, "shot": "01_bag"},
  {"key": "BACK", "wait": 1.4},
  {"swipe": [540, 1800, 540, 800], "ms": 400, "wait": 1.0, "shot": "02_scroll"},
  {"probe": [250, 2150], "shot": "03_hero", "vs": "00_home"},
  {"shell": "input keyevent 3"}
]}
```

| 动作 | 说明 |
|---|---|
| `tap [x,y]` / `swipe [x1,y1,x2,y2]` / `key <code>` / `text <str>` / `shell <cmd>` | 直接下发 |
| `wait <秒>` | 只等待 |
| `shot <name>` | 截图；可带 `vs: "<更早的 shot 名>"` 指定基线（不写则和上一张比） |
| `probe [x,y]` | 点一下 + 截图 + 报变化率；`back: true` 才会按 BACK 收尾（默认不按） |

每个 step 都可以带 `wait`（执行后等待）和 `shot`（截图名）。

坐标口径：`wm size` 是 1080×2340 就直接用像素。**量坐标的办法**：截图后用 Pillow 裁一小块
（`im.crop((x1,y1,x2,y2))`）再读那张小图 —— 小图 token 便宜，且是原始像素、不会因为缩放算错。

---

## 5. 坑位

1. 🔴 **`focus` 变成别的包 = 一切归零**。2026-10-23 实测两次：连点「确定」把游戏退出确认也点掉了，
   游戏退到后台，后面几次 tap 全打在桌面/别的 app 上（`networld.price.app`）。
   **盲点「确定」之前先 `shot` 一张确认弹窗内容**；`seq` 的 focus 列就是为此存在的。

2. 🔴 **本工程有至少三种模态弹窗，会把后面所有点击吃掉**（按出现顺序）：

   | 弹窗 | 触发 | 危险度 |
   |---|---|---|
   | 游戏公告（`游戏公告`） | 冷启动后自动弹 | 低，点掉即可 |
   | 提示（`暂无任何提示` + 取消/确定） | 某些操作后弹 | 中，BACK 关不掉 |
   | 退出游戏（`取消/确定`） | **主城按 BACK** | 高，误点「确定」直接退出 |

   三者位置几乎重合（取消/确定 都在 y≈1427 一带），**分不清就会点错**。
   所以：`probe` 默认不按 BACK；连续几步都「几乎没变」时，先怀疑有弹窗盖着，别怀疑坐标。

3. 🔴 **vivo V2002A 的 logcat 主缓冲区是空的**（`-b main/system/crash` 全 0 行，
   只有 `-b events` 有 auditd 噪音）。后果：
   - `wait_log` 在这台机器上**永远超时**；
   - `assert_no_crash` **永远通过**（看不到 FATAL 就当没有）—— 这是假绿。
   所以本机只能靠「进程存活 + 前台是本包 + 联系表」判，别信日志锚点。
   要恢复得在手机上拨 `*#*#112#*#*` 开日志开关，不可脚本化。

4. **联系表别贪多**：4 列 × 300px 宽是能看清标题的极限；9 张以上建议分两张，
   或只拼「变化率最大」的那几张。

---

## 6. 与 case_run.py 的分工

| 场景 | 用什么 |
|---|---|
| 找坐标 / 找日志锚点 / 判断某个按钮有没有反应 | **probe.py seq**（人机协作，看变化率表） |
| 写进用例后日常回归、CI 判定、出 JUnit | `case_run.py`（无人值守，只认 pass/fail） |

校准完的用例可以把 probe 出的坐标直接填进 `tests/cases/<group>/*.json`；
`sig` 的 dHash 可以当「金标准」存进用例，跑完比对 hamming 距离 —— 这条路能让
**没有 logcat 的设备也能做界面断言**（待落地，见 `docs/functional_test_automation.md` §2.2）。
