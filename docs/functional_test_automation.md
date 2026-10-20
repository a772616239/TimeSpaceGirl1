# 游戏功能自动化测试（`TS-Test-*`）

> 更新时间：2026-10-20
> 一句话：**把「测什么功能」写成用例，把「什么时候跑」做成 job。** 加功能只加一个 JSON，不新建 job。
> 现状：Lua 逻辑回归 **14/15 通过、429 条断言、0.9 秒**（本机现在就能跑）；设备用例已搭好骨架，等真机校准。

---

## 1. 为什么分成多个 job，而不是一个大 job

**功能会长到几十个，但跑法永远只有几种节奏。** 按节奏分 job、按功能写用例：

| 节奏 | job | 要设备吗 | 典型耗时 | 什么时候点 |
|---|---|---|---|---|
| 改完 Lua 就想知道有没有踩回去 | **TS-Test-Lua** | ❌ 不需要 | ~1s | 每次改完 Lua / 每天 4 点 |
| 登录这条链能不能进游戏 | **TS-Test-Login** | ✅ 要 | 1~3min | 出包后 / 改登录、公告、SDK 后 |
| 战斗能不能打、结算会不会崩 | **TS-Test-Battle** | ✅ 要 | 3~8min | 改战斗、技能、掉落、数值后 |
| 背包/邮件/商店等面板开关 | **TS-Test-Func** | ✅ 要 | 3~6min | 改 UI 框架、面板生命周期后 |
| 一次看全貌 | **TS-Test-Suite** | 部分 | 10~20min | 每天 5 点 / 发版前 |
| 只验证「装上能起来」 | **TS-Android-SmokeTest** | ✅ 要 | 1min | 出包后立刻 |

> 为什么不把五件事塞进一个 job：**失败定位会变慢**。一个 job 里 30 条用例混着跑，
> 红了你得翻日志才知道是登录坏了还是战斗坏了；分开之后，红的是哪个 job 就说明哪块功能坏了。

---

## 2. 两层自动化（关键设计）

### 2.1 第一层：Lua 逻辑（不需要设备、不需要 Unity）

`scripts/lua-tests/*.lua` 用「假节点 + 真源码」在 luajit 里跑真逻辑，覆盖挂机气泡、
技能条计时、排行榜国旗、绑定倒计时、公告回调、多语言区服名……**0.9 秒跑完 429 条断言**。

执行器：`jenkins-shared/lib/test_runner.py`（通用执行器，`kind: lua` 只是其中一种）

- 自动发现 `test_*.lua`，不用登记；
- 统一判定：`✅/❌`、`[PASS]/[FAIL]`、`N passed, M failed`、`结果：N 通过 / M 失败` **四种标记都认**，
  最终以退出码为准（标记只用来数条数）；
- 每个文件一条 CHECK → 一个 JUnit testcase → 有趋势；
- 需要参数的用例（如 `test_getservername.lua` 要吃 `Common_functions_64.bytes`）
  在 `tests/tests.json` 的 `suites[0].tests` 里配 `args`。

清单长这样（`tests/tests.json`，同一个文件以后还能再加 C#/Python 套件）：

```json
{ "version": 2,
  "suites": [
    { "name": "lua", "title": "Lua 逻辑回归", "kind": "lua",
      "tests_dir": "scripts/lua-tests", "pattern": "test_*.lua",
      "workdir": "LuaEncoder/luajit_mac/64",
      "interpreter": "LuaEncoder/luajit_mac/64/luajit",
      "env": {"LUA_PATH": "./?.lua;;", "TS_ROOT": "{rel_project}"},
      "baseline": "tests/lua-baseline.json",
      "tests": { "test_getservername.lua": {"group": "多语言", "args": ["{project}/Assets/...bytes"]} } }
  ] }
```

手工只跑一个文件（排查用，比等 Jenkins 快）：

```bash
cd ~/Documents/TimeSpaceGirl1
/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python \
  ../jenkins-shared/lib/test_runner.py run --project "$PWD" --suite lua \
  --only test_rank_head_flag.lua --run-dir /tmp/t
```

### 2.2 第二层：设备用例（真机 / 模拟器）

执行器：`jenkins-shared/lib/android/case_run.py`。一个用例 = 一个 JSON：

```json
{
  "id": "01_bag_open",
  "title": "打开背包 → 列表渲染 → 关闭",
  "group": "func",
  "draft": true,
  "timeout": 180,
  "steps": [
    {"action": "restart"},
    {"action": "wait", "seconds": 12},
    {"action": "tap", "x": 540, "y": 2150, "note": "背包入口"},
    {"action": "wait_log", "pattern": "Bag|背包", "timeout": 60},
    {"action": "screenshot", "name": "bag-open"},
    {"action": "key", "code": "BACK"},
    {"action": "assert_alive"},
    {"action": "assert_no_crash"},
    {"action": "assert_focus"}
  ]
}
```

动作清单：

| 动作 | 作用 |
|---|---|
| `restart` | 强杀 → 清 logcat → `am start -W` → 等进程（**每条用例从干净状态开始**） |
| `wait` / `tap` / `swipe` / `key` / `text` | 基本操作 |
| `shell` | 任意 `adb shell` 命令 |
| `setup` | **宿主机**命令（GM 给道具、开隧道、改配置…），`$PY`/`$PROJ` 会被替换 |
| `wait_log` | 等 logcat 出现某段文字（`absent: true` = 等它消失） |
| `assert_alive` / `assert_no_crash` / `assert_focus` | 进程在、没 FATAL/ANR、前台是本包 |
| `screenshot` | 存图进 `evidence/cases/<id>/` |

**为什么用日志锚点而不是像素比对**：Unity 是 GL 直出，`uiautomator` 看不到任何控件；
像素比对对分辨率/机型/特效太敏感，维护成本高于收益。日志锚点（`wait_log`）是这套框架里
最稳的「到达了某个状态」的证据，配上截图给人看，够用了。

---

## 3. 校准流程（设备用例从 draft 到能跑）

新写的用例默认 `"draft": true` —— **只记「跳过（未校准）」，不判红**。原因：没在真机上
量过坐标的用例，跑起来必然乱点，把「点错地方」判成「功能坏了」比不测更糟。

```
① 勾 CALIBRATE=true 跑一次 TS-Test-Login
   → 每条用例只做「重启 + 3/8/15s 三张截图 + logcat」，不判断言
   → Build Artifacts 里下 cases/<id>/calib-03s.png / calib-08s.png / calib-15s.png

② 看截图量坐标（手机分辨率 1080×2340 就直接用像素；别的分辨率按比例换算）

③ 看 cases/<id>/logcat.txt 找锚点：挑一句「只有到了那个界面才会打出来」的日志

④ 把坐标和 pattern 填进 JSON，把 "draft" 改成 false

⑤ 再跑一次（不勾 CALIBRATE），这次就是真判定
```

用例全组都还是 draft 时，`case_run.py` 退 **3** → job 记黄并写明「N 条未校准」，
**不会假装通过**。

---

## 4. 已知失败基线（`tests/lua-baseline.json`）

有些失败已经定性、但暂时不该把流水线染红（例如要产品拍板的口径冲突）。登记成：

```json
{ "test_rank_head_flag.lua": { "failures": 1, "since": "2026-10-20", "reason": "…" } }
```

规则：

| 情况 | 结果 |
|---|---|
| 失败条数 ≤ `failures` | ⚠️ 黄，说明里带原因 |
| 失败条数 > `failures` | 🔴 红（**基线不会把新坏的也吞掉**） |
| 用例哪天自己绿了 | ⚠️ 黄「基线已过期，请删除」 |

> 现在的基线只有一条：`test_rank_head_flag.lua` 的「公会榜 → 我的排名旗隐藏」。
> 产品代码里明确写了「公会榜查不到会长时退回画自己」，用例却期望隐藏 —— **口径冲突，不是崩溃**，
> 需要产品二选一。同一次排查还补上了这个用例缺的 `RankingManager.GetGuildForeInfo` 桩：
> 之前跑到 [9] 就崩，`[9]~[11]` 的断言从来没执行过，「全过」是假的。

---

## 5. 现在能跑出什么（2026-10-20 实测）

**TS-Test-Lua #2**（本机，无设备）：

```
CHECK|Lua · test_afk_map_talk.lua|pass|断言 24 通过
CHECK|Lua · test_afk_ult_talk.lua|pass|断言 45 通过
CHECK|Lua · test_country_rank.lua|pass|断言 70 通过
CHECK|Lua · test_ult_card_follow_bar.lua|pass|断言 48 通过
CHECK|Lua · test_rank_head_flag.lua|warn|断言 32 通过 / 1 失败 · 基线内已知失败
CHECK|Lua 汇总|warn|14/15 通过 · 断言 429 条 · 0.9s，1 个需关注
```

构建结果 **UNSTABLE（黄）**，描述：`⚠️ 0/1 环节通过，1 项需关注 · 14/15 通过 · 断言 429 条`。

**TS-Test-Login #1 / TS-Test-Suite #1**（本机起不了模拟器）：体检 rc=3 → 装包与用例跳过，
3~4 个环节、黄球，描述写明「没设备」。**没有一条用例被假装成通过。**

---

## 6. 加一个新功能测试

1. `tests/cases/func/03_shop_open.json` 照抄一个现有用例，改 `id` / `title` / `steps`；
2. `"draft": true` 先跑校准（第 3 节）；
3. 校准完改 `false`，跑 **TS-Test-Func** —— 不用改 job、不用改脚本。

需要 GM 造数据的用例，在 `pre` 里加一条 `setup`：

```json
"pre": [{"action": "setup", "cmd": "$PY scripts/gm_client.py 'additem 10000004 100'"}]
```

> 注意：GM 只对**测试服**有效，且生产服 gmport 只监听 127.0.0.1（要先开 ssh 隧道）。
> 用例连的必须是测试服包，否则会打真实数据。

---

## 7. 与其它 job 的关系

```
                      ┌─ TS-Test-Lua ──── 客户端 Lua 逻辑（无设备，1s）
出包（TestPackage）──►│
                      ├─ TS-Android-SmokeTest ─ 装上能起来吗（1min）
                      └─ TS-Test-Login / Battle / Func ─ 功能链路（要设备）
                                    │
                                    └─ TS-Test-Suite ── 上面全部，一次跑完 + 一份报告
```

- **只测不打包、不上传**：整套 `TS-Test-*` 没有任何 Unity 构建、没有 Play 上传。
- **不并发**：设备类 job 都 `concurrent: false`（一个 adb / 一个模拟器端口）。
- **共享实现**：`jenkins-shared/lib/{test_runner.py, android/case_run.py, android/device.sh, test_job_stages.sh}`，
  工程里只有 job 定义、用例和 `tests/tests.json` 清单。换工程只改用例，不复制引擎 ——
  main_android 的 `RL-Test` 就是同一个执行器跑 C# 单测（`kind: dotnet`），判定/基线/JUnit 一套通吃。

---

## 8. 排障

| 现象 | 原因 | 处理 |
|---|---|---|
| 用例全「跳过（未校准）」 | 都是 draft | 勾 `CALIBRATE=true` 出图，按第 3 节校准 |
| `等 60s 没等到日志「xxx」` | 锚点写错 / 界面没到 / 日志被别的东西刷掉 | 看 `cases/<id>/logcat.txt`，换一句更稳的锚点 |
| `前台不是本包` | 弹了权限框、更新框、评分框 | 先点掉，或给用例加一步 `key BACK` |
| `用例脚本异常` | JSON 写错（少逗号、动作名拼错） | 报错里带动作名，照第 2 节表改 |
| Lua 用例 `崩溃/中断` 但一条断言都没跑 | 桩缺失（例如少了 `GetGuildForeInfo`） | 补桩，别往基线里塞 —— 基线只接「断言失败」，不接「跑不起来」 |
| 慢模拟器上大量 `wait_log` 超时 | 软渲染帧率低 | 把 `CASE_SCALE` 设成 2~3 |
