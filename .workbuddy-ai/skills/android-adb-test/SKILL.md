---
name: android-adb-test
description: 用 adb 在真机/模拟器上测这个游戏的安卓包（装机、启动、冒烟断言、抓 logcat、按坐标点界面、截图判断）。当需求是「把包装到手机看看会不会崩」「点一下这个按钮有没有反应」「找底栏/面板的点击坐标」「跑设备用例/冒烟测试」「TS-Android-SmokeTest 红了」「真机连不上 / 装机卡住 / 一直转圈」时使用。关键词：adb、android_probe、probe seq、montage、dHash、screencap、logcat、am start、adb install、adb reverse、INSTALL_FAILED_UPDATE_INCOMPATIBLE、冒烟、smoke、device.sh、case_run、uiautomator、模拟器、真机、vivo V2002A、坐标校准、设备用例。
agent_created: true
---

# adb 安卓测试（本工程）

**正文都在 `docs/`，按场景只读对应那一份**，别一次全读。

| 场景 | 读哪份 |
|---|---|
| 找坐标 / 判「点了有没有反应」/ 一次看图覆盖 N 步 | `docs/android_probe_skill.md` ← 主力 |
| 装机启动冒烟、logcat、断言清单、失败码、换平台 | `docs/android_emulator_smoke.md` |
| 写设备用例、CI 回归、JUnit、draft→能跑的校准流程 | `docs/functional_test_automation.md` |

工具与执行器：

- 本仓：`scripts/android_probe.py`（`seq` / `montage` / `sig` 三个子命令）
- 另一仓：`~/Documents/jenkins-shared/lib/android/{device.sh,case_run.py,selftest.sh}`
  （`device.sh` 是唯一的装包/启动/断言实现，工程差异全走参数）

三句先记住：

1. **变化率不能当断言。** 本工程主城背景一直在动（同屏 36~60%），换屏只有 30~36%，区间重叠 ⇒
   没有任何阈值能分开。变化率只看「是不是完全静止」（<5% ≈ adb 没送到），判界面只能看联系表。
2. **`focus` 变成别的包 = 一切归零。** 盲点「确定」可能把游戏退到后台，后面几次 tap 全打在桌面/别的 app 上，
   变化率 30~80% 看着像「功能正常」。点之前先截图确认弹窗内容。
3. **vivo V2002A 的 logcat 主缓冲区是空的**（只有 `-b events` 有噪音）⇒ `wait_log` 永远超时、
   `assert_no_crash` 永远通过（假绿）。这台机只能靠「进程存活 + 前台是本包 + 截图」判。
