# 安卓模拟器 / 虚拟机自动化测试（`TS-Android-SmokeTest`）

> 更新时间：2026-10-20
> 一句话：**给一个已经打好的 APK，把它装进安卓设备拉起来，回答「会不会崩、画面出不出得来」，并留下截图和 logcat。**
> 只测不打包、不上传、不碰 Play 轨道 —— 与 `TS-Android-Release` 完全解耦。

---

## 1. 为什么单独做一个 job

打包（`TS-Android-TestPackage`）只能证明「**能出包**」，证明不了「**能跑**」。
一个包可以顺利构建、校验全过，装上去 3 秒闪退 —— 这类问题以前只能靠人把包拖到手机上试。

所以这里把「装 + 跑 + 看」做成流水线的一环：

| 以前 | 现在 |
|---|---|
| 打完包 → 手动 adb install → 手动点开 → 肉眼看 | 打完包 → 点一下 `TS-Android-SmokeTest` → 页面直接给结论 + 截图 |
| 崩了只有一句「闪退了」 | logcat 里第一条 `FATAL EXCEPTION` 直接进构建描述 |
| 换了台机器就重写一遍 adb 脚本 | 同一套 job，换 `TARGET` 就行（真机 / 本地模拟器 / 远程模拟器） |

---

## 2. 本机现状（2026-10-20 实测）

| 项 | 结果 |
|---|---|
| 平台 | macOS **x86_64**（宿主机 AMD Ryzen 9 5900X，本机是虚拟机） |
| 硬件虚拟化 | 🔴 `kern.hv_support = 0` ⇒ **没有嵌套虚拟化** |
| Android SDK | ✅ `/Users/wangxufeng/Library/Android/sdk`（platform-tools / build-tools 36.0.0 / ndk） |
| `emulator` 包 | 🔴 未安装（SDK 里没有 `emulator/`） |
| 系统镜像 | 🔴 未安装 `system-images;android-33;...` |
| `adb` | ✅ 1.0.41（设备列表时有时无：`0000020c0d3e53c9` vivo V2002A / Android 10 / arm64-v8a 曾经连上过，后来掉线） |

**结论：这台机器起不了本地模拟器**，两道墙各一道：

1. **没有硬件虚拟化** ⇒ 模拟器只能退化成纯软件模拟（QEMU TCG），慢到没有测试价值；
2. **没装 `emulator` + 系统镜像** ⇒ 连退化的机会都没有。

装 emulator 本身要 JDK 17+（本机默认 JDK 是 8，Jenkins 里是 21）：

```bash
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-24.jdk/Contents/Home \
  sdkmanager --install emulator platform-tools 'system-images;android-33;google_apis;x86_64'
```

装完也仍然过不了第 1 道墙。**所以本机的正确姿势不是「想办法跑起来」，而是「换一条路」**：
真机（`TARGET=已连接设备`）或别的机器（`TARGET=远程 adb`）。这也是为什么 job 把
「环境不具备」判成**黄球 + 跳过**，而不是红球。

---

## 3. 三条设备路线

`TARGET` 下拉框决定「设备从哪来」，四条路对应同一套断言：

| TARGET | 做什么 | 需要什么 | 适合 |
|---|---|---|---|
| `auto`（默认） | 有已连设备就复用，没有才起本地模拟器 | 至少一条路可用 | 日常；不知道机器上有没有真机 |
| `已连接设备` | 只用 `adb devices` 里 `state=device` 的 | USB 调试已授权 / `adb connect` 过 | 本机 + 真机；最稳 |
| `本地模拟器` | 起 headless `emulator`，装完自动关 | 硬件虚拟化 + emulator + 系统镜像 | 干净的 CI 机器 |
| `远程 adb` | `adb connect host:5555` 后照常装包 | 另一台机器上已经起好的模拟器 | **本机没有虚拟化时最实用** |

`auto` 的实际判定（`device.sh probe` 里就这一段）：

```
有 state=device 的设备？ ── 有 ──► 直接用（不起模拟器）
        │ 没有
        ▼
emulator 存在 且 有硬件虚拟化？ ── 有 ──► 起本地模拟器
        │ 没有
        ▼
rc=3「环境不具备」──► 记黄球、跳过装包与冒烟（ALLOW_NO_DEVICE 控制）
```

---

## 4. 一次构建发生了什么

六个阶段，每个阶段都在构建页上留一行结论（`run_stage.sh` + `stage_report.py`）：

| 阶段 | 干什么 | 失败意味着 |
|---|---|---|
| ① 准备与取证 | 写 `context.txt`（工程 HEAD / 设备目标 / 被测包 / 观察时长） | 环境坏了 |
| ② 定位被测包 | `APK` 参数 → 否则 `apks/` 下 mtime 最新的 `.apk` | 没包可测（**不回退旧包**） |
| ③ 环境体检 | 工具链 / 设备 / 虚拟化 / 镜像，输出「补齐清单」 | rc=3 ⇒ 黄球跳过（不是缺陷） |
| ④ 设备就绪 | 起模拟器（等 `sys.boot_completed`）/ `adb connect` / 复用 | 设备起不来 |
| ⑤ 装包与启动 | `aapt2` 读包名与入口 → `adb install -r -g` → 端口反向 → `am start -W` → 等 `pidof` | 装不上 / 启动即崩 |
| ⑥ 冒烟断言 | 观察 `SMOKE_SECONDS` 秒后跑 6~8 条断言 | **真缺陷，必须红** |

收尾（关模拟器 / 断远程设备）放在 `post.always`：⑥ 失败时后面的 stage 会被跳过，
而模拟器不关就会一直占着端口和内存，下一次构建直接起不来。

### 4.1 断言清单

| 断言 | 判据 | 失败时说明什么 |
|---|---|---|
| 进程存活 | `pidof <pkg>` 在观察期结束后仍有输出 | 崩了，或被系统杀了（内存不够 / 被安全软件清） |
| 无崩溃 / 无 ANR | 本包 pid 的 logcat 里没有 `FATAL EXCEPTION` / `Fatal signal` / `ANR in` | 真崩，日志里有堆栈 |
| 前台窗口是本包 | `dumpsys window` 的 `mCurrentFocus` 含包名 | 弹了权限框 / 更新框 / 闪回桌面 |
| 引擎已初始化 | logcat 有 `Initialize engine version` | Unity 包没起来（非 Unity 包记 skip） |
| 截图取证 | `screencap -p` 出的 PNG > 10KB | 截图失败（设备忙 / 无画面） |
| 画面非纯色（启发式） | PNG ≥ 30KB | **只标黄**：纯色画面压得极小，但加载页也可能很小，交给人看一眼 |
| 端口反向映射 | `adb reverse --list` 里有每个端口 | 测试服的包连不上本机服务端，登录会一直转圈 |
| 自定义流程 | `FLOW_SCRIPT` 退出码 0 | 各工程自己的「登录 → 进游戏」脚本 |

> 「画面非纯色」为什么是启发式：不引入图像库（PIL/ImageMagick 不一定有），
> 用「PNG 压缩后大小」当代理指标。1080×2340 的黑屏通常 <10KB，真实游戏画面 200KB+。
> 宁可标黄让人看一眼，也不要误判成「挂了」。

### 4.2 产物

| 产物 | 位置 | 用途 |
|---|---|---|
| 环节表 | `evidence/summary.md` + 构建页 JUnit | 哪一步红了 |
| 冒烟断言表 | `evidence/smoke/junit.xml` | **趋势**：这个包的崩溃是从哪一版开始的 |
| 截图 | `evidence/smoke/screenshot.png` | 一张图回答「画面出没出来」 |
| logcat | `evidence/smoke/logcat.txt` / `logcat-crash.txt` | 复现时不用再去翻设备 |
| 现场快照 | `evidence/smoke/window-focus.txt`、`device.info`、`app.package` | 前台是谁 / 哪台设备 / 哪个包 |

构建描述会写成：`⚠️ 2/3 环节通过，1 项需关注 · 1.2.51_vc77_021047.apk · vivo V2002A | Android 10 (API 29) | arm64-v8a · 断言 8 过 0 败`。

---

## 5. 换平台怎么改（这是「后续给别的平台用」的落点）

**实现只有一份**：`/Users/wangxufeng/Documents/jenkins-shared/lib/android/device.sh`
（装包/启动/断言这套逻辑与工程无关；工程差异只有包名、入口、端口，全走参数）。

要换平台，改的永远是这三样，**不用碰断言逻辑**：

| 换什么 | 改哪里 |
|---|---|
| 设备从哪来 | `device.sh` 的 `do_up()`（加一个 `TARGET` 分支）+ `probe` 的判定 |
| SDK / 二进制在哪 | 环境变量 `ANDROID_SDK_ROOT` / `ADB` / `EMULATOR`（脚本不写死路径） |
| 包名 / 入口 / 端口 | job 参数 `PACKAGE` / `ACTIVITY` / `REVERSE_PORTS`（留空则从 APK 读） |

### 5.1 Linux CI（KVM，最省事）

```bash
# 一次性：装 SDK + 镜像，把 jenkins 用户加进 kvm 组
sudo usermod -aG kvm jenkins
sdkmanager --install emulator platform-tools 'system-images;android-33;google_apis;x86_64'
echo no | avdmanager create avd -n ts-smoke-api33 -k 'system-images;android-33;google_apis;x86_64' -d pixel_5
```

然后 `TARGET=本地模拟器` 直接能跑。判定条件是 `/dev/kvm` 可读写（`hv_ok()`）。
**注意**：`-no-window` 必须有，CI 没有 X server。

### 5.2 Apple Silicon（M 系列 Mac）

只改一个参数：`SYSTEM_IMAGE=system-images;android-33;google_apis;arm64-v8a`。
x86_64 镜像在 arm 上跑不了（不是慢，是起不来）。

### 5.3 Windows

`ADB=C:\Android\sdk\platform-tools\adb.exe`、`EMULATOR=C:\Android\sdk\emulator\emulator.exe`，
在 Git Bash / WSL 里跑同一份脚本。虚拟化判据走 `emulator -accel-check`（WHPX）。
WSL 里没有 USB ⇒ 真机路线不可用，只能用模拟器或 `adb connect` 到 Windows 侧的 adb。

### 5.4 云真机 / 设备农场（Firebase Test Lab、云测平台）

这条路**不需要**本地设备，但也不是「换一个 adb 命令」那么简单：云端跑完只回传结果。
推荐做法是**并列而不是替换**：

- 保留本 job 做「本机能测就测」的快速冒烟（30 秒级）；
- 云真机作为夜间全量（多机型 × 多系统版本），用它们自己的 CLI/API 触发，
  把返回的 `junit.xml` 丢进同一个 `evidence/`，趋势图就能合在一起看。

`device.sh` 里 `TARGET` 的分支点就是给这条路留的口子：加一个 `cloud` 分支，
内部调 `gcloud firebase test android run --type robo`，把结果转成 CHECK 行即可，
后面的报告链（`checks_to_junit.py` / `stage_report.py`）完全复用。

### 5.5 GitHub Actions（不用 Jenkins 时）

```yaml
- uses: reactivecircus/android-emulator-runner@v2
  with:
    api-level: 33
    target: google_apis
    arch: x86_64
    script: |
      adb install -r app.apk
      adb shell am start -W -n com.example/.MainActivity
      sleep 30
      adb logcat -d | grep -E 'FATAL EXCEPTION' && exit 1 || exit 0
```

思路与 `device.sh` 一致（装 → 起 → 等 → 查日志），只是没有本项目的报告链。

---

## 6. 失败码与排障

| rc | 含义 | 构建球色 | 怎么办 |
|---|---|---|---|
| 0 | 通过 | 绿 | — |
| 1 | 断言失败（真缺陷） | 红 | 看 `evidence/smoke/logcat-crash.txt` 第一条 `FATAL EXCEPTION` |
| 2 | 用法错误（没给 APK / 没设备就 install） | 红 | 看日志里那句 `✗ ...` |
| 3 | **环境不具备** | 黄（`ALLOW_NO_DEVICE=true`） | 按「补齐清单」换机器 / 插真机 / 改 `TARGET` |

常见现象对照：

| 现象 | 原因 | 处理 |
|---|---|---|
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 机器上装的是 Play 版（app signing key），这个包是 upload key 签的 | 勾 `UNINSTALL_FIRST`（会清本地数据；账号数据在服务端） |
| `adb install` 挂住十几分钟不动，`mCurrentFocus` 是 `com.android.packageinstaller` | 国产 ROM（vivo/OPPO/小米/华为）的「外部来源应用」拦截页：要先勾「已了解风险」再点「继续安装」，**命令不会自己过去** | 已内置看门狗 `auto_accept_install_dialog`：边装边盯前台窗口，按 `uiautomator` 的 bounds 自动勾选 + 点确认（不写死坐标）。超时由 `INSTALL_DIALOG_TIMEOUT`（默认 1800s）控制 |
| 装上了但一直转圈登录 | 测试服的包连 `127.0.0.1:8081`，端口反向没生效 | 确认 `REVERSE_PORTS` 非空、`adb reverse --list` 有记录 |
| `启动后 60s 内没拿到进程` | 启动即崩（缺 so / ABI 不匹配 / 资源没打进包） | 看 `evidence/smoke/logcat-startup.txt` |
| 模拟器起了但 `am start` 报 `Error type 3` | Activity 名读错了（多渠道包入口不同） | 显式给 `ACTIVITY` |
| 截图全黑但进程活着 | 软渲染没出首帧 / 还在加载 | 调大 `SMOKE_SECONDS`；或看截图判断是不是加载页 |

---

## 7. 没有设备时怎么验证这套脚本

```bash
/usr/local/bin/bash /Users/wangxufeng/Documents/jenkins-shared/lib/android/selftest.sh
```

它造一个**假 adb**（按真机输出应答），把 `resolve → up → install → smoke → down`
整条链跑一遍，断言 8 条 CHECK 全 pass，再故意灌一条 `FATAL EXCEPTION` 确认能报红。

```
  ✓ probe / resolve / up / install / smoke   rc=0
  ✓ 至少 7 条断言通过（实际 8）
  ✓ 崩溃时 smoke 返回 1
✅ 自测全部通过（假设备链路 + 崩溃检测）
```

**为什么值得有**：没有设备的机器恰恰最需要先验证脚本。没有自测，就得等真机接上、
装了 460MB 的包之后，才发现 `dumpsys window` 的字段名写错了。

---

## 8. 与其它 job 的关系

```
TS-Android-TestPackage  ──(出包)──►  apks/<日期>/CLIBuild/*.apk
                                            │
                                            ▼  ② 定位被测包（默认取最新）
                                   TS-Android-SmokeTest
                                            │
                                            ├─► evidence/smoke/screenshot.png
                                            ├─► evidence/smoke/junit.xml（趋势）
                                            └─► 构建描述：包名 · 设备 · 断言 8 过 0 败
```

- **不打包**：这个 job 不做 Unity 构建，也不提 versionCode。包从哪来由 `APK` 参数决定。
- **不并发**：同一台机器只有一个 adb / 一个模拟器端口，两个构建同时跑会互相抢设备
  （META 里 `concurrent: false`）。
- **不碰 Play**：全程没有任何上传动作，与发版红线无关。
