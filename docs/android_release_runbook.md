# Android 发版 Runbook（AAB / APK → Google Play）

> 更新时间：2026-10-12
> 适用范围：`com.Warera.timespace`（Unity 6000.6.5f1，IL2CPP，仅 `arm64-v8a`）
> 配套：`scripts_reference.md`（脚本地图）、`unity_android_build_skill.md`（构建侧坑位与 Gradle/AGP 细节）、
> `google_play_upload_setup.md`（service account 申请与授权）、`client_build_chain.md`（改 Lua/配置表）

---

## 0. 🔴 三条红线（先看这个）

1. **绝不自行送审。** 打包、构建、校验、提交 git 可以做；**「上传到 production 轨道 + `status=completed`」= 提交审核，必须先问用户**。
   → 已用代码锁死，见 §5。**默认上传目标是 `internal`（内部测试轨道），不是 production**（2026-10-13 起）。
2. **上传期间不要并发调任何 Play API**（含 `play_16kb_watch.py`、其它脚本/其它 agent）。多进程对同一 App 开 edit 会互删。
3. **重启生产游戏服会踢线，必须先取得用户确认。**（见 `server_ops_runbook.md`）

---

## 1. 关键事实速查

| 项 | 值 |
|---|---|
| 包名 | `com.Warera.timespace` |
| Unity | `/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity` |
| 打包方法 | `CLIBuilder.BuildAndroidAAB`（发版）/ `CLIBuilder.BuildAndroidAPK`（自测） |
| 出包口径真源 | `Assets/Editor/ReleaseBuildSettings.cs`，CLI 固定 `MinimalGmOff` |
| 产物目录 | `apks/{yyyy-MM-dd}/CLIBuild/{HHmmss}.{aab\|apk}`（`apks/` 已 gitignore） |
| 当前版本 | versionCode **69** / versionName **1.2.50**（下一个包必须 ≥ 70） |
| 默认上传轨道 | **`internal`（内部测试）**；production 须显式 `--production`（2026-10-13 起） |
| 签名 | upload key：`beauty.keystore`，alias `xing`，DN `O=EMI`，证书 SHA-256 `8ed07291…` |
| Python | `/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python` |
| Play 凭证 | **`<工程>/.secrets/service-account.json`**（工程本地，`.gitignore` 排除、永不入库；回退 `~/.gplay/…`）→ `secrets_setup.md` |
| 一键入口 | `scripts/aab_release.sh` |

**耗时参考**：全量 ~10–15 分钟（Unity 启动 1–2min + IL2CPP 5–8min + Gradle 2–4min）；
**增量**（`Library/Bee` 缓存完好时）APK 约 1 分钟。

---

## 2. 出包口径：GM 面板问题（`isOpenGM`）

### 2.1 问题

`CLIBuilder` 过去**没有「是否正式包」这一步** ⇒ 命令行产的包一律沿用开发态设置，
最典型的就是 `isOpenGM=1`：**GM 面板随包发布**。
（2026-10-12 修正过一次误判：线上 v64 **就是** CLIBuilder 打的 ⇒ 线上一直带 GM 面板。）

### 2.2 修法（`297b9ba9f`）

新增 `Assets/Editor/ReleaseBuildSettings.cs` 作为**唯一真源**，`CLIBuilder` 与 GUI 的
`BuildWindow` 共用同一份逻辑，流程是：

```
打开 Logo.unity → 快照当前 GameSettings → ApplyProfile(口径) → Validate()（自检）
   → MarkSceneDirty + SaveScene（🔴 batchmode 下 BuildPlayer 读磁盘，必须落盘）
   → BuildPlayer → finally: RestoreScene()
```

| 口径 | 用途 |
|---|---|
| `Dev` | 开发态（GM 开） |
| `MinimalGmOff` | **CLI 默认**：最小改动，只把 `isOpenGM` 置 0，其余与线上逐位一致 |
| `FullTemplate` | 完整正式包模板（`isGuide`/`isUpdate` 也开） |

CLI 口径写在 `CLIBuilder.cs` 的 `kProfile` 常量里，**改口径就改这一处**。

### 2.3 为什么不能只看构建日志

构建日志只能证明"我以为我套了什么"。**必须以包内产物为准**：

```bash
scripts/verify_aab_release_config.py <aab|apk> --expect minimal
```

原理：`GameSettings.settingInfo` 是 `[System.Serializable]`，在场景 `level0` 的 SerializedFile 里
按**声明顺序**内联，12 个 int32 小端；`isOpenGM` 是**第 9 个**（下标 8）。
判据 = 那 48 字节特征在 `level0` 里**精确命中且唯一**。详见 `scripts_reference.md` §1.5。

### 2.4 🔴 CLI 崩溃会残留场景改动

`CLIBuilder` 用 `try/finally` 还原 `Assets/LuaFramework/Scenes/Logo.unity`。
**进程被硬杀时 `finally` 不执行** ⇒ 场景残留 `isOpenGM: 1→0`，工作区变脏。

> 2026-10-12 11:57 那次就是这么留下的（日志停在 `Building Gradle project` 后 `Application is shutting down...`）。

**起包前先 `git status` 看它，脏了就清回基线**：

```bash
git checkout -- Assets/LuaFramework/Scenes/Logo.unity
```

---

## 3. 端到端 Runbook

### 3.1 发版（AAB → Play）

```bash
cd /Users/wangxufeng/Documents/TimeSpaceGirl1

# ① 只读体检：包内资源链路（尤其 Lua）是否就绪
scripts/check_ab_ready.sh

# ② 干净起点（若上次打包崩过）
git status --short | grep Logo.unity && git checkout -- Assets/LuaFramework/Scenes/Logo.unity

# ③ 出包 + 三道包内校验（默认不上传）
scripts/aab_release.sh

# ④ 上传到 internal 内部测试轨道（默认目标；传完测试员几分钟内可装）
scripts/aab_release.sh --skip-build --upload --yes

# ⑤ 只有要发正式版才抬旗：传 production 草稿（不送审）
scripts/aab_release.sh --skip-build --upload --production --status draft --yes

# ⑥ 送审/上线 —— 🔴 必须先取得用户明确同意再执行
scripts/aab_release.sh --skip-build --upload --production --publish --yes
```

`--skip-build` 会复用 `apks/` 下最新的 AAB；也可以 `--aab <path>` 精确指定。

### 3.2 自测（APK 侧载）

```bash
# 打 APK（不提 versionCode，保持与线上 AAB 同号，便于对照）
/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity \
  -projectpath /Users/wangxufeng/Documents/TimeSpaceGirl1 \
  -batchmode -nographics \
  -executeMethod CLIBuilder.BuildAndroidAPK \
  -logFile /Users/wangxufeng/Documents/TimeSpaceGirl1/build_log_apk_main.txt \
  -quit

# 交付自检（一条命令回答"这包能不能拿去测"）
scripts/verify_apk_delivery.py apks/<date>/CLIBuild/<HHmmss>.apk --expect minimal
```

⚠️ **侧载前必须先卸载 Play 版** —— 这个 APK 用 upload key 签名，与 Play 的 app signing key 不同，装不上去。
⚠️ 只出 `arm64-v8a`，老 32 位设备装不了。

### 3.3 判读构建日志

```bash
grep -nE "CLIBuilder|ReleaseBuildSettings|Build SUCCESS|Build FAILED" build_log_apk_main.txt
```

正常应看到：`套用前: … isOpenGM=1 …` → `套用后(MinimalGmOff): … isOpenGM=0 …` →
`场景已落盘` → `BuildPipeline.BuildPlayer -> …` → `✅ Build SUCCESS!` →
`场景已还原为开发态: … isOpenGM=1 …` → `End (built=True)`。

⚠️ 有 `UNITY_EXIT=0` 但没产包 = 中途被外部杀掉（历史上有一次是会话/沙箱中断）。看日志末尾有没有
`Application is shutting down...`，有就是被杀，重跑即可（增量会很快）。

---

## 4. 16KB 页大小合规

### 4.1 两层门槛

| 层 | 判定 | 后果 |
|---|---|---|
| **门槛 1（硬）** | 每个 64 位 `.so` 的 `PT_LOAD p_align ≥ 16384` | 不过 = Play 直接不合规 |
| **门槛 2（软）** | Play「某些库是使用旧版 Android NDK 编译的」，**点名具体库** | 告警（2027-02 前不阻断发布） |

🔴 **两层是独立的！** 原库 `libtolua.so` 的 `p_align = 0x10000`（64KB）本来就远超 16KB ⇒
**只看对齐的巡检脚本拦不住门槛 2**，这正是 2026-10-12 的漏网原因。

### 4.2 判定依据

- 硬门槛：直接解析 ELF program header。
- 软告警：`.note.android.ident` 的版本串（`Android.r28130041008` 或旧式 `Android (13004108)`）、
  `.comment` 里有没有 `GCC:`、`p_align` 是不是 `0x10000`。
- 🔴 **Play 点名是按【库文件名】匹配已知问题库清单的**，与 NDK 版本阈值无关。
  文件名含版本号的库（如 `libFirebaseCppApp-12_8_0.so`）一换版本就等于换了名字 ——
  Firebase 12.8.0→12.10.1 就是这么让告警从 5 个降到 2 个的（这些库实测仍是 r21e）。

### 4.3 工具

```bash
scripts/verify_aab_native_16kb.py <aab|apk> [--strict]   # 包内体检（离线）
scripts/play_16kb_watch.py                               # 巡检 + 轨道现状 + diff + 邮件
scripts/libtolua16k/build.sh [--install]                 # 重编 libtolua.so（4 项硬校验）
```

### 4.4 当前状态（2026-10-12）

| 库 | NDK | 对齐 | Play 是否点名 |
|---|---|---|---|
| `libnative-googlesignin.so` | **已用 r28c 重编**（原 r17） | 0x4000 | 曾点名，已修 (`ca46e0e49`) |
| `libtolua.so` | r28 | 0x4000 | 从未点名 |
| `libil2cpp.so` / `libmain.so` / `libunity.so` | r23b | 0x4000 | 未点名 |
| Firebase / crashlytics 系列 | r21e / r25b / r25c | 0x4000 | 未点名 |

🔴 **升 Unity 引擎解决不了 16KB**：引擎只管 `libunity`/`libil2cpp`/`libmain`/`burst`，这些早已合规。
🔴 厂商库（Firebase 等）**无法由我们重编**；若将来被点名，只能等厂商升级。
⚠️ 换 NDK 版本会**同时改 note 与对齐**，重编后务必按 `libtolua16k/verify.py` 的 4 项逐项比对，
别只看 r28 字样。

### 4.5 ⚠️ Unity 的 `libtolua.so is not 16KB-aligned` 是**误报**

Unity 2022.3.62 每次 Android 打包都会打印：

```
Plugin 'Assets/Plugins/Android/libs/arm64-v8a/libtolua.so' is not 16KB-aligned.
```

**实测该库完全达标**，三路互证：

- 自写 ELF 解析：4 个 `PT_LOAD` 全 `p_align = 0x4000`（= 16384，正好是阈值）。
- `/usr/bin/objdump -p` 交叉验证：4 个 LOAD 全 `align 2**14`。
- **直接解 zip 看产物**：`092806.aab` / `113650.aab` / `093010.apk` / `121249.apk` 里
  该 `.so` md5 与源文件一致（`868a74d9b757…`），AGP 的 `stripped_native_libs` 也没改对齐。
- 旁证：Play 两轮 16KB 报障**从未点名 libtolua**。

⇒ Unity 自检口径有 bug（`0x4000` 恰等于阈值却被判"未对齐"），属噪声。
**判断 16KB 合规一律以包内产物为准**，别被 Unity 日志牵着走去"修"一个没坏的东西。

---

## 5. 发布闸门：怎么保证「不送审」

### 5.1 真因不是纪律，是默认值

2026-10-12 发生了一次误送审。根因：**三个入口的默认值都是发布** ——
`play_upload.py --status` 默认 `completed`、`aab_release.sh` 的 `STATUS` 默认 `completed`、
`DO_UPLOAD` 默认 `1`。任一处漏传参数 ⇒ 直接提交审核 + 面向全量用户。

### 5.2 现方案（`2479709ae` + 2026-10-13 收紧）：默认拒绝 + 默认 internal + 三旗标显式放行

| 想做的事 | 命令 | 必须显式给出 |
|---|---|---|
| 只出包（默认） | `scripts/aab_release.sh` | — |
| 传 **internal 内部测试**（默认轨道，传完即可测） | `… --skip-build --upload --yes` | `--upload` |
| 传 production **草稿** | `… --skip-build --upload --production --status draft --yes` | `--upload` + `--production` |
| **提交审核 / 上线** | `… --upload --production --publish` | 再加 `--publish`（须先获批！） |
| 只读看现状 | `… --dry-run` | —（`--dry-run` 不受闸门限制） |

- 默认不上传；**默认轨道 `internal`**；`status` 按轨道推导（internal ⇒ `completed`，其余 ⇒ `draft`）。
- **两层各自独立校验**（shell 与 python），脚本之间不传递旗标 ⇒ 双保险；
  第三层在 Jenkins `TS-Android-Release` 的上传阶段（人工审批前的复核），
  第四层是 `.jenkins/lib/checks/play_gate.sh` 的代码级断言（文本 + 行为，CI 每次发版前必跑）。
- 被拒时 shell 侧退出码 `1`、python 侧 `2`，并直接打印拒绝理由。
- 🔴 **`internal` 豁免 `--publish`**：它不面向公众、免常规审核、可随时 halt / 替换。
  这是刻意的 —— **草稿在 internal 轨道上等于「没传」**（测试员根本看不到），
  所以「传内部测试管线」这个动作本身就应该是 `completed`。

### 5.3 平台的坑

🔴 **`--status draft` 是 production 轨道「不送审」的唯一姿势。**
`--changes-not-sent-for-review` 只对 internal/alpha/beta 有效。
（已修：`aab_release.sh` 末尾的结论文案现在按轨道分支打印，不再对 draft 说「会进入审核」。）

🔴 **2026-10-17 起 Play 对「所有」轨道强制 `changesNotSentForReview=true`。**
`status=completed/inProgress` 时 `edits.commit` 不带该参数一律 `400 INVALID_ARGUMENT`：

```
Changes cannot be sent for review automatically. Please set the query parameter
changesNotSentForReview to true. Once committed, the changes in this edit can be sent
for review from the Google Play Console UI.
```

以前只有 non-prod 轨道需要、脚本默认没带 ⇒ **internal 上传 100% 卡在 commit**；
而 AAB 已经传完、edit 被丢弃后该 versionCode **不会进 bundle 池**
（复现：`--reuse-version-code 70` 报「不在 bundle 池里」），437 MB 白传一次。
现已修：`play_upload.py` 在 `status ∈ {completed, inProgress}` 且轨道属于
`internal/alpha/beta` 时**自动**带该参数。它的含义是「提交但不送审」——
internal 轨道本就免常规审核、测试员立即可装，不需要走审核流。

🔴 **Play 的所有轨道共享同一个 versionCode 空间** —— 一个号传过一次就永久占用，
换个轨道重传同一个号同样被拒。所以「传 internal」并不能省 versionCode，号照样要递增。

ℹ️ **internal 轨道的口径**（2026-10 核对）：上传后**不需要等常规审核**，一般几分钟内测试员即可
从内部测试链接安装（首次发布时商店名称/商品详情可能有最长 48h 的展示延迟）。但它**不等于免于
Google Play 政策**：Google 仍可事后拦截。它是「内部测试管线」，不是法外之地。

---

## 6. 交付自检：什么样的包不能拿去测

2026-10-12 踩过的坑：为绕开 Play 的 16KB 报障，临时把 `libnative-googlesignin.so`
从包里**摘掉**，产出 `090414.apk` / `093010.apk`（sidecar 记 `"googlesigninRemoved": true`）。

**这两个包 Google 登录必挂 ⇒ 账号派生链必然走注册分支 ⇒ 拿它们验证"老号变新号"只会得到假结论。**

现在用 `scripts/verify_apk_delivery.py` 一次性拦掉（`68313d686`）：

```bash
scripts/verify_apk_delivery.py <apk|aab> --expect minimal
```

- ① 版本号（APK 走 `aapt2`，AAB 读 `.release.json`）
- ② 出包口径（`--expect minimal`）
- ③ native 16KB / NDK
- ④ 🔴 **`libnative-googlesignin.so` 必须存在且有 64 位版本，且对齐 ≥ 16384**
- ⑤ 签名（有 `apksigner` 时），并提示"这是 upload key，侧载需先卸 Play 版"
- 写出 `<artifact>.delivery.json` 留证（含每个库的 md5/对齐）

> 同轮还修了 `verify_aab_native_16kb.py` 的一个**假通过** bug：它原来只认 `'/lib/' in 名字`，
> 而 APK 的路径是 `lib/<abi>/x.so`（开头无斜杠）⇒ 一个 `.so` 都数不到，直接走
> 「包内没有 .so，天然合规」分支。APK 上等于完全失效。已改为布局无关，并加保险：
> 归档里有 `.so` 却匹配不上就 rc=1 报错。

---

## 7. 账号体系：账号名 = f(登录 SDK 给的 id)

> 这一节解释「为什么同一个人换一次登录实现就变成新号」。

### 7.1 派生链

```
LoginPanel.lua:1243
  → GoogleSignMgr.cs 按 platformId 取 id
  → GetAcc("go"|"pl"|"gt"|"r2gt" + id)
       name = acc[0..12)
       pw   = acc[12..24)
  → tk/registerUser + tk/userLogin
```

- 前缀：`go` = Google(platformId 1)、`pl` = Play(2)、`gt` = 游客(3)、**`r2gt` = Editor 游客**。
- **服务端以 `name` 为账号主键**（`user_register_info._id = name`）；`openId` 是服务端生成的 32hex，1:1 绑定 `name`。

### 7.2 🔴 事故与修复

`72502790b` 把 Android `platformId==1` 的实现从 `SigninSampleScript`
（返回 Google Sign-In 的 `UserId`，**21 位数字**）换成了 `GooglePlayGamesLogin`
（返回 `Social.localUser.id`，**20 字符**）⇒ 同一账号算出的 id 变了 ⇒ 自动建新号。

**已回退**（`f74ffb436`）：改回 Google Sign-In。**勿再改回去。**
（该库 `p_align=0x10000`，不破 16KB 硬门槛；它带回的「旧版 NDK」软告警已由 `ca46e0e49` 用 NDK r28c 重编该 `.so` 修掉。）

**不用跑客户端的判别法**：查 `go` 账号的 `pw` 长度 ——
`11` ⇒ 21 位旧 Sign-In，`10` ⇒ 20 字符 PlayGames。

### 7.3 影响面

`LoginPanel.lua:1226` 判定 `lastPlt == LoginPlatform && user ~= defaultOpenIdkey` 才走
`RequestUser` 用旧凭据 ⇒ **PlayerPrefs 完好的老玩家不受影响**；
**清数据 / 重装 / 换设备 / 新装 ⇒ 走注册分支 ⇒ 100% 变新号。**

> 别把两区老号搞混：**10002 的 lv24 老号账号名是 `r2gtB27C2057`（Editor 游客号）**，
> 与真机 Google 号是两套体系；10001 库里没有它。

### 7.4 ⚠️ 渠道值为 `None` 是**正常**的

线上 `SDKChannelConfig.txt` 就是 `None`，`isSDK=false`。
本作 Google 登录走的是 `not IsSDKLogin` 的**账号密码分支**
（`LoginPanel.lua:7`：`IsSDKLogin = AppConst.isSDK and AppConst.isSDKLogin`）。
🔴 **渠道为 None 时若强行 `isSDK=true`，登录会走不存在的渠道 SDK 而全挂。**
`ReleaseBuildSettings.Validate()` 已把这条写成硬校验（"渠道为空但 isSDK=true" ⇒ 拒绝出包）。

---

## 8. 其它已修问题

### 8.1 Play「SDK 版本已过时」告警

`androidx.fragment 1.1.0` 是 `play-services-base/basement` 的**传递依赖**（工程文件里搜不到，
要从 `~/.gradle/caches/**/*.pom` 反查）。已在 `resolutionStrategy` 里 force
（fragment **1.6.2** / activity **1.7.2**，`7cc5a3afd`）。

🔴 **上限由 AGP 决定**：AGP 7.4.2 的 dexer 吃不下 core 1.13+，而 fragment 1.7+ 要 core 1.13+
⇒ **不能再往上升**。查包内版本文件：**AAB** 在 `base/root/META-INF/<group>_<name>.version`。

### 8.2 `aab_release.sh` 的 Unity 占用检查

原来是 `pgrep` 全量匹配，本机常年有其它项目（如 `~/Documents/main_android/Unity`）在跑 batchmode
⇒ 被误判"占用"而中止。已修（`b64b894dd`）：**只在命令行含 `-projectpath ${PROJECT_ROOT}` 时命中**。

### 8.3 上传超时 / edit 互删

- `TimeoutError` → 已内置 `300s` 超时 + `8MB` 分块 + 断点续传重试。
- `HTTP 400 FAILED_PRECONDITION / This Edit has been deleted.` → **并发调 Play API 导致**。
  重跑即可（新建 edit），但 ~437MB 要重传一遍。

### 8.4 包体基准（Unity 6 起）

AAB 体积基准随引擎升级上移，**不是资源变多**，逐文件归因见
`.workbuddy/memory/2026-10-13.md`：

| 引擎 | AAB | 口径 |
|---|---|---|
| 2022.3.62f2c1（≤v68） | **421.3 MiB** | `apks/2026-08-17/CLIBuild/231312.aab` |
| 6000.6.5f1（v69 起） | **437.5 MiB** | `apks/2026-10-13/CLIBuild/1.2.50_vc69_170356.aab` |

差异 +16.2 MiB ≈ AB 资产 +13.0（2750 个包 1910 个变大、中位 +0.5 KiB，属引擎侧统一开销）
+ 原生库 +2.2（`libunity.so` +2.34，被 Firebase 12.10.1 −0.35 抵消一部分）
+ Data +1.3（`global-metadata.dat` +0.80、内置 `unity default resources` +0.49）；dex / res 基本持平。

🔴 **附带异常（已修，见下）**：包内 AB 的**原始**字节数 411 MiB → 906 MiB（+495 MiB，2.2x）。
根因**不是「压缩档位变松」，也不是 Unity 6 引擎问题**，而是**工程代码 bug**：
`BuildSelectAssetBundles` 里 `if (builds.Length == 0) return;` 的守卫被注释掉了。

Unity 6 实测：传 `new AssetBundleBuild[0]` 给 `BuildPipeline.BuildAssetBundles` **不是**
「什么都不打」，而是回退成「按 AssetDatabase 里所有 assetBundleName 标记重建全部 bundle」，
并且用**本次传入的 options**。而 `FrameTool.BuildGameAssetBundles()` 连打三批：

| 批次 | options | buildMap | 后果 |
|---|---|---|---|
| ① | `ChunkBasedCompression` | 2755 | 正常压成 LZ4HC |
| ② | `None`（LZMA） | 2 | 正常压成 LZMA |
| ③ | `UncompressedAssetBundle` | **0** | **空数组回退 → 把①②全部覆写成未压缩** |

受控实验（同进程同目录，2026-10-17）：① 正常压缩打 10 个包 → 10 个文件 372,849 B，
单包 `adjutantpanelatlas` 16063 B；② 紧接空数组 + `UncompressedAssetBundle` → **2739 个文件
966,341,088 B**，同名包变 25296 B。完全复现线上现象。

已排除的旁支（都不是原因）：素材类型（真实 atlas/spine/prefab 单打均 LZ4HC）、批量规模
（2000 个真实 bundle 仍 100% LZ4HC）、AssetDatabase 标记数（2757 个标记时仍正常）、
SBP 缺失。唯一变量就是「空数组」这条调用。

修复 `ae8051b6c`：恢复该守卫。验证：`BuildABs` 1.8G → 842M，lz4 批次压缩率 **0.4321**
（2022.3 基线 0.4253）、lzma 批次 0.2410（`luabytes` 15.88MB → 3.8MB）；
剩余 69 个 None 全为 audio（Vorbis 本身已压缩，LZ4HC 无收益，属正常）；
**APK 965MB → 458MB**。AAB 侧因 zip deflate 兜底一直看不出问题（仅 +16.2 MiB）。

---

## 9. 故障速查表

| 现象 | 根因 | 处理 |
|---|---|---|
| `edits.insert` 失败 / 401 | Cloud 未启用 Google Play Android Developer API | `google_play_upload_setup.md` §1.1 |
| 403 `caller does not have permission` | Play Console 未授权该邮箱 / 漏勾「发布到正式版」 | 同上 §1.2；授权后传播需几分钟~几小时 |
| 400 `version code has already been used` | 号重复 | 检查是否误用 `--no-bump` |
| 400 `App bundle was not signed` | Play 应用签名未启用 | Console 启用 Play App Signing |
| 退出码 5 | versionCode 预检撞车，脚本主动拦截 | 提号后重打包 |
| `:launcher:mergeExtDexRelease FAILED` | AndroidX 与 AGP 7.4.2 dexer 不兼容 | `unity_android_build_skill.md` §3 双模板 force |
| `Multiple Unity instances cannot open the same project` | 本工程 GUI Unity 占锁 | 关 GUI / 删陈旧 `Library/SourceAssetDB-lock` |
| 前置检查报「未发现 Lua bundle」 | AB 链路断开，`StreamingAssets/Android` 里没有 `lzma\|luabytes.unity3d` | `scripts/check_ab_ready.sh` 定位；GUI 里「整体打包资源」→「复制资源到流媒体目录」 |
| 真机启动报 `StreamingAssets 路径资源丢失，请重新打包包内资源!` | 发出的包不含 Lua | 重建 AB 后重打包 |
| AAB 明显偏小（如 ~139MB；正常 **421 MiB @2022.3 / 437 MiB @Unity 6**，见 §8.4） | AB 构建残包（缺 prefabs/texture/spine/audio/atlas） | 重建 AB 再打包 |
| Unity 打印 `libtolua.so is not 16KB-aligned` | **误报** | 忽略，见 §4.5 |
| `build_log` 有 `Application is shutting down...` 且没产包 | 进程被外部杀掉，`finally` 未执行 | 重跑；先 `git checkout -- Logo.unity` 清残留 |

---

## 10. 当前轨道现状与待决事项（2026-10-13）

只读复核（`play_upload.py --dry-run`）：**`production draft v69; completed v68`**
（2026-10-12 时 beta/alpha 空）。

- v68（completed）= 已上线版本；v69（draft）= 2026-10-13 出的包 —— 含 r28c 重编的
  `libnative-googlesignin.so`、13 个 `.so` 全部 16KB 对齐、包内 `isOpenGM=0`。
- 🔴 v69 目前挂在 **production 的草稿位**。2026-10-13 用户要求「不要直接传正式环境，
  传内部测试的管线」⇒ 流程已改为**默认传 internal**；这个 production 草稿**暂时保留**，
  由用户决定撤下 / 提升 / 改传 internal。
- 下一个包 versionCode 必须 ≥ **70**。
- 本地 `release` 分支与 `origin/release` 已同步。

---

## 11. 环境路径备忘

```bash
UNITY=/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity
UNITY_ANDROID=/Applications/Unity/Hub/Editor/6000.6.5f1/PlaybackEngines/AndroidPlayer
# Gradle 7.5.1: $UNITY_ANDROID/Tools/gradle
# NDK:          $UNITY_ANDROID/NDK   （23.1.7779620；重编 .so 用独立的 r28，见 libtolua16k/README.md）
# JDK 11:       $UNITY_ANDROID/OpenJDK
# Android SDK build-tools（aapt2 / apksigner）: ~/Library/Android/sdk/build-tools/36.0.0
KEYS=~/Documents/TimeSpaceGirl1/beauty.keystore     # alias xing
```
