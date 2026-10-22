# Jenkins 全流程 CI（`.jenkins/` + 本机 Jenkins）

> 更新时间：2026-10-20
> 目标实例：本机 Jenkins **2.568**，`http://127.0.0.1:8080/`（Homebrew 装的，`~/.jenkins`）
> 一句话：**把散在 `scripts/` 与 `~/ts-*` 里的全流程收口成 7 个 Jenkins job，并且每个环节的结论都要能在 Jenkins 界面上直接看到，而不是让人去翻几百行控制台。**

---

## 1. 为什么这么做

原来这些流程要人肉拼命令：`aab_release.sh`、`lua-bytes-sync.sh`、`server_health_check.py`、
`~/ts-chat-patch-*/deploy-chat-patch.sh`、`~/ts-shard10002/add-shard-10002.sh`……

痛点有三个：

1. **参数记不住 / 顺序会错**，尤其是那些「破坏性动作」（重启游戏服会踢线、上传会改线上轨道）。
2. **结论看不出来**：跑完一屏日志，到底哪一步黄了、哪一步是红的，得自己数。
3. **约定会漂移**：改了脚本忘了改文档，下次照着旧文档做就踩坑。

所以做成 Jenkins job，并且刻意追求**四件可视化产物**（见第 4 节）。

### 单一真源：job 定义在仓库里，不在 Jenkins 界面上

`job` 不点在 Jenkins 里，而是：

```
.jenkins/jobs/<JOB>.groovy   ← 人写这里（含 /**@META {json} META*/ 头：描述/参数/定时/并发/保留策略）
        │  .jenkins/lib/render_job.py 渲染
        ▼
     Jenkins config.xml      ← 机器产物
```

好处：**改 job 不用点界面、不用重启 Jenkins、改动进 git 可以 review 与回滚。**

```bash
.jenkins/apply-jobs.sh                 # 全量同步（幂等：先 POST config.xml，404 再 createItem）
.jenkins/apply-jobs.sh --only TS-Server-Ops
.jenkins/apply-jobs.sh --dry-run       # 只渲染，不推
.jenkins/apply-jobs.sh --list          # 列出定义文件 → 触发器 → 参数
```

---

## 2. 目录结构

```
.jenkins/
├── apply-jobs.sh              ← 把 jobs/*.groovy 同步成 Jenkins job（幂等）
├── lint.sh                    ← 推送前四道静态检查（见第 6 节）
├── jobs/
│   ├── TS-Pipeline-Overview.groovy     只读总览（8 个环节一次看完）
│   ├── TS-Android-Release.groovy       AAB + APK 全链路
│   ├── TS-Android-TestPackage.groovy   测试 APK
│   ├── TS-Android-SmokeTest.groovy     已打包 APK 的装机冒烟（模拟器 / 真机 / 远程）
│   ├── TS-Resource-Build.groovy        导表 + 同步字节码 + 重建 AB（可被别的 job 调用）
│   ├── TS-Client-Resources.groovy      Lua 源码 ↔ 字节码
│   ├── TS-Art-Restyle.groovy           美术资源换节日风格（生图 + 归位 + 验收）
│   ├── TS-Art-Translate.groovy         战令横幅中文美术字 → 英文版（擦字 + 补底板 + 排字）
│   ├── TS-Art-BottomFade.groovy        底部紫色虚化（纯像素工序，不调 AI）
│   ├── TS-Art-Frame.groovy             套外框（卡框/紫框，纯像素工序，不调 AI）
│   ├── TS-Server-Health.groovy         生产服巡检（定时）
│   ├── TS-Server-Ops.groovy            服务端/区服运维动作
│   ├── TS-Server-Release.groovy        服务端代码发包正式服
│   ├── TS-Play-Watch.groovy            Play 轨道与 16KB（定时）
│   ├── TS-Test-Lua.groovy              Lua 逻辑回归（headless luajit）
│   ├── TS-Test-Login.groovy            登录链路设备用例
│   ├── TS-Test-Battle.groovy           战斗/关卡设备用例
│   ├── TS-Test-Func.groovy             功能点设备用例
│   ├── TS-Test-Suite.groovy            全量总入口（Lua + 三组设备用例）
│   └── TS-Local-Deploy.groovy          本地测试服一键部署
├── lib/
│   ├── render_job.py          groovy + META → config.xml
│   ├── run_stage.sh           跑一个环节并把结论登记进报告（一个环节一行）
│   ├── stage_report.py        环节报告库：add / junit / summary / desc / status / san
│   ├── lock.sh → lock.py      flock(2) 跨 job 命名互斥锁（rc=75 = 拿不到锁）
│   ├── build_apk.sh           APK 构建层（固定 MinimalGmOff 口径）
│   ├── stage_apk.sh           APK 收成构建产物（cp -c 克隆 → workspace/artifacts/，出固定下载链接）
│   ├── find_artifact.py       按 mtime 定位「本次」产物；**默认拒绝回退到旧包**
│   ├── server_ops.sh          服务端动作统一派发口（14 个动作，标注破坏性/只读）
│   ├── server_release.sh      服务端「代码发包正式服」执行口（11 个子命令：切分支/编译/差异/备份/注入/自检/记录/回滚）
│   ├── server_release.py      发布辅助：jar 条目清单 / 逐条目 CRC 差异 / 发布记录 / 发布看板 HTML
│   └── checks/
│       ├── android_env.sh         打包环境预检（工具链/三口径/Gradle 模板/keystore/Unity 占用）
│       ├── repo_hygiene.sh        仓库卫生 + Lua 源码↔字节码成对性（唯一硬闸门）
│       ├── play_gate.sh           送审闸门自检（文本断言 + 行为断言）
│       ├── remote_health.sh       生产服只读巡检适配层（默认 --dry-run 不发信）
│       ├── health_report.py       巡检 JSON → 机器化结论
│       └── local_shard.sh         本地 10002 区服体检（只看本机，秒级）
└── run/                       ← 🔴 运行态产物，**不入库**（.gitignore 已忽略）
    ├── rendered/              渲染出的 config.xml
    └── <BUILD_TAG>/          每次构建的证据目录（stages/ logs/ junit.xml summary.md smoke/）
```

装包冒烟的执行口不在工程里，在共享库（`jenkins-shared/lib/android/`，与工程无关）：
`device.sh`（probe / up / install / smoke / down / resolve）+ `checks_to_junit.py` + `selftest.sh`。
理由见 `docs/android_emulator_smoke.md` 第 5 节：换平台只改 `TARGET` 分支，不复制一份脚本。

---

## 3. 十九个 job

视图：**「时空美少女 · 全流程」**（`ListView`，含全部 19 个 job，带状态球/天气/上次成功/耗时/构建按钮列）。

| Job | 做什么 | 参数（默认值） | 定时 | 并发 |
|---|---|---|---|---|
| **TS-Pipeline-Overview** | 只读总览：一次看完 8 个环节，失败互不阻断 | `SKIP_PLAY=False` `SKIP_HEALTH=False` | — | 允许 |
| **TS-Android-Release** | **AAB + APK** 全链路，默认打包 + 上传发布。**只管客户端**：服务端表只做 `②-3` 只读一致性体检（只提醒不改），改表走独立 job `TS-Table-Sync` | `SERVER_ENV=正式服` `EXPECT_PROFILE=minimal` `BUMP_VERSION=True` `BUILD_APK=True` `REUSE_AAB=` `ALLOW_NO_LUA=False` `UPLOAD=True` `TRACK=internal` `STATUS=completed` `PUBLISH=False` `AUTO_APPROVE=True` `NOTES=` | — | **禁止** |

> **`BUILD_APK`（默认 True）**：打完 AAB 立刻在同一把 `unity` 锁下再出 **同 versionCode** 的 universal APK
> （`--no-bump`，绝不二次提号），供直接装机测试。
> - APK 失败**不阻断** AAB 发版（红线是 Play 包），但会记成「关注」并在归档里写明「本次未产出 APK」。
> - APK 会单独跑 `verify_apk_delivery.py` 生成 `.delivery.json`（口径 / 16KB / googlesignin / 签名），
>   ⑦ 的三重校验只针对 AAB —— 不单独校，就是「发出去的装机包没人验过」。
> - ⚠️ APK 用 upload key，与 Play 的 app signing key 不同 ⇒ **侧载前必须先卸载 Play 版**。

| **TS-Android-TestPackage** | 出测试 APK（universal，upload key 签名）**+ 出完发结果邮件** | `SERVER_ENV=现网-129.226.213.65` `BUMP_VERSION=False` `EXPECT_PROFILE=minimal` `SEND_MAIL=True` `MAIL_TO=` | **`0 3 * * *`（每天 03:00 夜间包）** | **禁止** |

> **`TS-Android-TestPackage` 的产物就是 APK 本体**（2026-10-17 修正）：构建页「Build Artifacts」
> 里直接挂着 `artifacts/<版本>_vc<N>_<HHmmss>.apk`，点一下就下载，不用去磁盘上翻 `apks/`。
> 构建描述也会写成 `✅ 9 个环节全部通过 · APK 1.2.51_vc74_215144.apk · 965M`。
> - **稳定下载地址**（推荐收藏 / 发人）：
>   `http://127.0.0.1:8080/job/TS-Android-TestPackage/lastSuccessfulBuild/artifact/artifacts/`
>   —— Jenkins 原生 permalink，永远指向最近一次**成功**的包，不随构建号变化，随 `buildDiscarder` 一起过期（不会留死链）。
>   ⚠️ 文档曾写「`userContent/TS-TestPackage-latest.apk` 软链」——**那是错的**，Jenkins 不对软链提供下载（2026-10-17 实测 404），已改 permalink。
>   ⚠️ 本机 Jenkins 只监听 `127.0.0.1`，所以这个地址**只有这台 Mac 打得开**；手机/别人要包得走邮件里的「本机路径」或另开上传。
> - 🔴 以前只归档 `evidence/**`，APK 本体只留一行**相对路径文本** ⇒ 构建页一个安装包都下不到，
>   且那条相对路径离开工程目录就指不到文件。这是「生成物应该是 apk」这个诉求的真正堵点。
> - 归档用 `cp -c`（APFS clone，写时复制）：965MB 瞬间就位、不额外占盘；跨卷时自动退化成硬链接或真复制。
> - 产物**只留最近 3 份 / 14 天**（META `artifactKeep` / `artifactDays`）。不设限则 30 次 × 965MB ≈ 29GB。
> - 本次没产出 APK 时，post 段会**清空** `workspace/artifacts/`：宁可不给下载，也不把上一次的旧包当本次产物挂上去。
> - **夜间包（2026-10-21 新增）**：每天 03:00 定时跑，`SERVER_ENV` 默认改成 **现网（柯测试服 129.226.213.65）**，
>   出完/失败都发一封结果邮件（版本号 + 下载地址 + 失败环节）。细节见 **3.11**。

| **TS-Android-SmokeTest** | **已打包 APK 的装机冒烟**：定位包 → 环境体检 → 起/连设备 → 装包启动 → 等 N 秒断言 → 截图 + logcat 归档 | `APK=` `TARGET=auto` `SERIAL=` `AVD_NAME=ts-smoke-api33` `SYSTEM_IMAGE=system-images;android-33;google_apis;x86_64` `SMOKE_SECONDS=30` `BOOT_TIMEOUT=300` `REVERSE_PORTS=8081:8081,16081:16081` `PACKAGE=` `ACTIVITY=` `UNINSTALL_FIRST=False` `KEEP_DEVICE=False` `ALLOW_NO_DEVICE=True` | — | **禁止** |

> **`TS-Android-SmokeTest`（2026-10-20 新增）**：把「已经打好的 APK」装进设备拉起来，回答
> **「会不会崩、画面出不出得来」**。只测不打包、不上传，与发版红线无关。
> - 包从哪来：`APK` 参数 → 留空则取 `apks/` 下 mtime 最新的一份（**不回退旧包**）。
> - 设备从哪来：`TARGET=auto` 先复用已连设备（真机/已在跑的模拟器），没有再起本地 headless 模拟器；
>   另有 `已连接设备` / `本地模拟器` / `远程 adb` 三条显式路线。
> - 🔴 **本机起不了模拟器**（`kern.hv_support=0`，无嵌套虚拟化；且 SDK 缺 `emulator` 包）⇒
>   体检 rc=3 → 记「需关注」并跳过装包，**黄球不是绿球**：它表示「没测」，不是「通过」。
>   `ALLOW_NO_DEVICE=False` 可把它变成红球（接了定时任务、缺设备本身就要报警时用）。
> - 断言 6~8 条：进程存活 / 无 FATAL·ANR / 前台是本包 / 引擎已初始化 / 截图取证 /
>   画面非纯色（启发式，只标黄）/ 端口反向 / 自定义流程。**崩溃判红，环境问题判黄。**
> - 产物：`evidence/smoke/screenshot.png` + `logcat*.txt` + `smoke/junit.xml`（趋势），
>   构建描述写成 `… · 1.2.51_vc77_021047.apk · vivo V2002A | Android 10 (API 29) · 断言 8 过 0 败`。
> - 实现与换平台（Linux KVM / Apple Silicon / Windows / 云真机 / GitHub Actions）：
>   见 **`docs/android_emulator_smoke.md`**；无设备时可跑 `jenkins-shared/lib/android/selftest.sh` 自测。

| **TS-Resource-Build** | **包内资源构建**：导表（xlsx→客户端 Lua + 服务端 txt）→ 同步 Lua 字节码 → 处理 AB（`重建` / **`复用缓存`** / `跳过`）并复制到 StreamingAssets → 新鲜度硬闸门 + 就绪体检 | `EXPORT_TABLES=True` `SYNC_BYTES=True` `AB_MODE=重建` `SERVER_ENV=正式服` `LUA_FILES=` | — | **禁止** |
| **TS-Table-Sync** | **服务器配置表发版**（2026-10-23 拆出，只碰服务端不出包）：代码同步 → 导表 → int 列归一化（可选）→ **把服务端 txt 增量推到指定环境**（逐表结构体检 + 推前备份 + 推后双向 md5）→ 可选重启。目标按 `build_envs.json` 的 `tableTargets`：现网→gs、测试服→local、正式服→gs | `SERVER_ENV=现网-129.226.213.65` `MODE=apply` `EXPORT=True` `FIX_NUMERIC=False` `RESTART=False` | — | **禁止** |
| **TS-Client-Resources** | Lua 源码 → LuaBytes 字节码 同步/复核 | `ACTION=check` `LUA_FILES=` | — | 允许 |
| **TS-Art-Restyle** | **美术资源换节日风格**（登录底板 → 圣诞版等）：生图交给 provider → 去水印 → 等比归位（绝不拉伸）→ 出不透明版 + 沿用原 alpha 的浮层版 → 像素级验收 → 可选写回 | `ASSET=` `THEME=christmas` `PROVIDER=chatgpt_web` `CDP_PORT=` `GEN_IMAGE=` `COMPOSITION=lock` `POSE=` `FRAME=auto` `WATERMARK=auto` `WRITE_BACK=True` `BACKUP_ROOT=` | — | **禁止** |
| **TS-Art-Translate** | **战令横幅中文美术字 → 英文版**：圈污染区擦字 → 逐行中位色 + 六边形纹理补底板 → 按已上线英文图层级排白字 → 六项像素验收 → 写回 `ArtFont_en` 并补 `.meta`。缺哪张补哪张 | `MODE=batch` `ASSET=` `FORCE=False` `WRITE=True` | — | **禁止** |
| **TS-Art-BottomFade** | **底部紫色虚化**（确定性像素工序，**不调 AI**）：末 N px 渐进高斯模糊 + 过渡到紫色 + 末行 alpha 收到 0，让横幅溶进紫色面板而不是一条硬切 | `ASSET=` `PX=130` `RIM=violet` `WRITE_BACK=True` `BACKUP_ROOT=` `COMPRESS=auto` `COMPRESS_MAX_DIFF=6` `FORCE=False` | — | **禁止** |
| **TS-Art-Frame** | **套外框**（确定性像素工序，**不调 AI**）：亮边 + 墨带 + 菱形网纹 + 45° 切角，画面等比缩进框内、画布尺寸不变。紫框 = `RIM=violet`；像素级验收 11 条 → 可选写回 | `ASSET=` `STYLE=card` `RIM=violet` `RATIO=0.022` `HAIRLINE=False` `WRITE_BACK=True` `BACKUP_ROOT=` `COMPRESS=auto` `COMPRESS_MAX_DIFF=8` `FORCE=False` | — | **禁止** |
| **TS-Server-Health** | 生产游戏服巡检（只读，默认不发信） | `SEND_MAIL=False` `TO=` | `H 10 * * *` | 允许 |
| **TS-Server-Ops** | 服务端/区服运维动作统一入口 | `ACTION=health` `CONFIRM=` `REASON=` | — | 允许 |
| **TS-Server-Release** | **服务端发包正式服（代码 + 配置表一次发完）**：切 release 分支 → JDK8 编译 → 与线上逐条目 CRC 比对 → 审批 → 备份 → **配置表一起发（调 TS-Table-Sync）** → 注入差异类 → 重启（新代码+新表同时生效）→ 上线自检 → **协议连通自检** → 回写发布记录 → 发布看板 → **异步触发 TS-Server-Health** | `ACTION=release` `SOURCE_BRANCH=x1-tag-1.2.2` `RELEASE_BRANCH=` `DEPLOY=False` `CONFIRM=` `AUTO_APPROVE=False` `ONLY_CLASSES=` `EXCLUDE_CLASSES=` `RESTART=gameserver` `SYNC_TABLES=True` `PROTO_CHECK=True` `PROTO_LOGIN=False` `PROTO_OPERATOR=` `HEALTH_AFTER=True` `ALLOW_DIRTY=False` `PUSH_BRANCH=True` `ROLLBACK_DIR=` `NOTES=` `SEND_MAIL=False` | — | **禁止** |
| **TS-Play-Watch** | Play 轨道 + 16KB 合规巡检 | `DRY_RUN=True` `NO_MAIL=False` `AAB=` `TO=` | `H 9 * * *` | 允许 |
| **TS-Test-Lua** | **客户端 Lua 逻辑回归**（headless luajit，**不需要设备**）：15 个 `test_*.lua`，429 条断言，约 1 秒 | `ONLY=` `GROUP=全部` | `H 4 * * *` | 允许 |
| **TS-Test-Login** | 登录链路设备用例（`tests/cases/login/*.json`） | `APK=` `TARGET=auto` `SERIAL=` `CASES=` `CALIBRATE=False` `CASE_SCALE=1` `REVERSE_PORTS=8081:8081,16081:16081` `UNINSTALL_FIRST=False` `KEEP_DEVICE=False` `ALLOW_NO_DEVICE=True` | — | **禁止** |
| **TS-Test-Battle** | 战斗/关卡设备用例（`battle/*.json`） | 同上 | — | **禁止** |
| **TS-Test-Func** | 功能点设备用例（`func/*.json`：背包/邮件/商店） | 同上 | — | **禁止** |
| **TS-Test-Suite** | **全量总入口**：Lua + 三组设备用例，一份报告 | `GROUPS=全部` `SKIP_LUA=False` + 设备类参数 | `H 5 * * *` | **禁止** |
| **TS-Local-Deploy** | **本地测试服一键部署**（本机 `~/home/java`，游戏服 `127.0.0.1:16081`）：体检 → JDK8 编译 → 逐条目比 CRC（**主 jar + lib 下 6 个 module jar**）→ 备份 → **副本注入** → CRC 复核 → **原子替换** → 重启 → 自检 | `SOURCE=本地工作区` `FETCH=True` `SKIP_BUILD=False` `GRADLE_ARGS=--offline` `SKIP_VERIFY=False` `DRY_RUN=False` `NOTES=` | — | **禁止** |

### 3.1 送审红线（三层闸门 + 一层代码级自检）

> 红线：**绝不自行提交审核。** 打包/构建/校验可以做；**「上传 production + `status=completed`」必须先获用户明确同意。**
> 2026-10-13 起默认目标轨道是 **`internal`（内部测试）**，production 必须显式抬旗。
> 2026-10-17 起 **`UPLOAD` 与 `AUTO_APPROVE` 都默认 `True`**（用户要求「默认上传并发布测试管道；
> 选线上管线时也上传发布」）⇒ **不带任何参数点构建 = 打包 + 传 internal + 发布**，无需人点按钮。

1. **参数默认值**：`UPLOAD=True`、`AUTO_APPROVE=True`、`TRACK=internal`、`STATUS=completed`、`PUBLISH=False`。
   注意 `PUBLISH=False` 依然把守线上轨道 —— 默认值组合只会走到 internal。
2. **运行时硬拦**：`TRACK != internal && STATUS in [completed, inProgress] && !PUBLISH` ⇒ `error(...)` 直接失败（防「下拉框手滑」）。
   `internal` 轨道豁免 —— 它不面向公众、可随时 halt / 替换。
3. **审批闸门**：上传 stage 的 `input` 步骤由 `AUTO_APPROVE` 控制 —— 默认 True 时打印确认信息后**自动放行**，
   设 `False` 才停下来等人在页面点「确认上传」。
   🔴 自动放行**只解掉「点按钮」这一步**，不会替你把线上轨道的 `PUBLISH` 抬起来；
   脚本层闸门（`aab_release.sh` / `play_upload.py` 的 `--upload` / `--production` / `--publish`）
   与 `play_gate.sh` 的 18 项断言**完全没动**，仍是「不加参数不上传 / 不写 production / 不送审」。

另有 `play_gate.sh` 做**行为断言**：真跑 `aab_release.sh --skip-build --upload --track production`、
`--upload --production --status completed` 等组合，必须被拒绝且输出含「拒绝」；同时断言
`--upload`（默认 internal + completed）**不被拦** —— 防止哪天有人把默认值改松了而没人发现。

### 3.2 跨 job 互斥：为什么不用 `disableConcurrentBuilds`

`disableConcurrentBuilds` 只挡**同一个 job 自己**并发。而这里有两处**全局排他资源**：

- **Play API 的 `edits`**：多进程对同一 App 开 edit 会互删（实测 421MB 白传）。
- **Unity 工程**：`Library/SourceAssetDB-lock` 只允许一个实例持有。

所以用 **flock(2) 命名锁**（`.jenkins/lib/lock.py`）：`lock.sh --name play|unity run -- <命令>`。

- 进程退出（含 `kill -9`）内核自动释放 ⇒ **无陈旧锁、无需删文件**。
- **rc=75**（`EX_TEMPFAIL`）= 拿不到锁，刻意与项目业务退出码 `1/2/3/4/5` 不冲突。
- `--name` 允许出现在任意位置（手动扫描，遇 `--` 即停，不吃命令自己的 `--name`）。

> ⚠️ 曾经用 `mkdir` 做锁，被否掉：释放要 `rmdir`，而 `~/Documents` 下 `rmdir` 被沙箱 broker 拦
> （`Operation not permitted`），结果锁残留 + 后续任务无限排队。

---

### 3.3 打哪个服的包（`SERVER_ENV`，2026-10-18 新增）

出包连哪个服务器**只由 `Assets/Resources/version.txt` 的 `serverUrl` / `resUrl` 决定**，
而这条链路以前完全没人管它（`CLIBuilder` / `aab_release.sh` / `build_apk.sh` 都不碰这个文件）
⇒ 只能人肉改文件、还得记得改回来，漏一次就是**发错服**。现在收成一个下拉框：

```
Jenkins 参数 SERVER_ENV ──┐
scripts/build_envs.json ──┴─→ scripts/apply_build_env.py apply <env>   （Unity 启动前写盘）
                                  ↓
                        Assets/Resources/version.txt  ← 临时改写（首次 apply 自动备份）
                                  ↓
                        Unity batchmode 打包
                                  ↓
               EXIT trap → apply_build_env.py restore（成功/失败/中断都还原）
                                  ↓
        scripts/verify_aab_server_env.py 解包核验（不符就拒绝上传/交付）
```

| 选项 | serverUrl | 用途 |
|---|---|---|
| `正式服` | `http://103.151.173.99:8080/` | 面向玩家的正式包（Release job 默认） |
| `测试服` | `http://127.0.0.1:8081/` | 本机自测服（Tomcat 8081 + 游戏服 16081，TestPackage 默认） |
| `现网-129.226.213.65` | `http://129.226.213.65:8080/` | 历史所有包（含上架 Play 的 vc73/vc74）用的那条，留作对照/回滚 |

⚠️ **改地址只改 `scripts/build_envs.json`，不要改脚本**。加新环境时 Job 的 `choices` 要同步（两边都改）。

几条必须知道的：

- 🔴 **注入必须在 Unity 启动之前**：batchmode 一启动就重新导入 Resources 下的 TextAsset，
  启动后再改文件等于没改 ⇒ 注入落在 shell 层，`CLIBuilder` 一行未改（不重编、不引入新风险）。
- 🔴 **还原挂在 `EXIT` trap 上**：脚本里有十几处 `fail`，若只写「打完再还原」，失败时会把正式服地址
  残留在工程里，下一次打包（哪怕没传 `--server-env`）就会静默打出正式服包 —— 比打包失败严重得多。
- 🔴 **AAB 与 APK 是两次独立 Unity 构建**，Release job 把同一个 `SERVER_ENV` 同时传给
  `aab_release.sh` 与 `build_apk.sh`；只给一处注入 = 两个包连不同服。
- `--skip-build` / `REUSE_AAB` 复用旧包时**不注入、只核验**；包内环境与所选不符一律拒绝
  （逃生门 `--allow-env-mismatch`）。这条专门防「把测试服包传上 production」。
- 测试服包连 `127.0.0.1`，**真机必须先做端口反向映射**：
  `adb reverse tcp:8081 tcp:8081` + `adb reverse tcp:16081 tcp:16081`，
  否则登录一直转圈（TestPackage 的归档说明与构建日志都会打印这段）。
- 手动核对：`python3 scripts/apply_build_env.py show`（工程当前连哪）、
  `python3 scripts/verify_aab_server_env.py <aab|apk>`（某个包连哪）、
  `python3 scripts/apply_build_env.py envs`（列可选环境）。

---

### 3.4 服务端发包正式服（`TS-Server-Release`，2026-10-19 新增）

服务端代码要上线时，以前是人肉拼命令：切分支 → `gradlew` 编译 → 比线上 jar → 备份 →
`zip -u` 注入 → 重启 → 看日志。每条都有坑，而且**顺序不能错**。现在收成一个 job。

#### 为什么不是「`package.sh` 打全量包覆盖线上」

这一点是 2026-10-18 用数据定论的，别再翻案：

| 现象 | 量化证据 |
|---|---|
| `package.sh` 的包 ≠ 线上正在跑的包 | 线上 jar 与 HEAD 源码**154 个类同名不同 CRC**（差异全在日志层：线上中文串乱码、缺新增 LOGGER 行） |
| 全量覆盖会顺手带走未上线改动 | 工作区有未提交的 `MongoBitSetConverter`（Mongo BSON 存储迁移，回退不可逆） |
| 全量覆盖会动运行时数据 | `conf/` 混着 `hotfix.json`/玩家 `checkout_*.txt`；`assets/` 有 889MB 运行期日志 |

⇒ 正确姿势：**以线上 jar 为基线，只 `zip -u` 差异条目**（类级注入）。本 job 固定走这条。

#### 14 个环节

| # | 环节 | 分组 | 干什么 | 失败会怎样 |
|---|---|---|---|---|
| ① | 参数与影响说明 | 前置 | 把「这次会动什么」打印在最前面；`DEPLOY=true` 但 `CONFIRM≠正式服` 直接拒 | 红 |
| ② | 发布前预检 | 预检 | 源码是否干净 / JDK8 / gradle 缓存 / SSH / 线上实例·端口·在线数·内存·磁盘 / 备份数 | 红（关注项黄） |
| ③ | 切 release 分支（独立 worktree） | 发布记录 | `git worktree add -b release/x1-<版本>-<YYYYMMDD-HHmm>` | 红 |
| ④ | 编译（JDK8 + gradle） | 构建 | 只编 `:serverlogic:jar :chatserver:jar`（根 `gradle build` 会连 worldserver 一起挂） | 红 |
| ⑤ | 产物校验 | 构建 | `unzip -t` / class major=52 / 注入边界 / lib 数量 | 红 |
| ⑥ | 与线上逐条目差异 | 差异 | 下载线上 jar，按**同名同 CRC** 分类：变更 / 仅本地 / 仅线上 / 将注入 / 被排除 | 无差异 ⇒ **黄**（rc=3） |
| ⑦ | 部署审批闸门 | 发布闸门 | 列出分支、注入条数、重启范围、在线连接数、说明；`AUTO_APPROVE=False` 时停在这 | 等人 |
| ⑧ | 线上备份 | 发布 | `deploy-staging/<stamp>/backup/`：jar + `gamecommon` + `config/*.properties` + `MD5SUMS` | 红（**无备份绝不注入**） |
| ⑨ | 注入差异条目 + 重启 | 发布 | 抽差异条目 → 传 → 服务器 `zip -u` 分批 → `unzip -t` → `RESTART-GAMESERVER.sh` | 红 |
| ⑨-2 | 回滚（恢复备份 + 重启） | 发布 | `ACTION=rollback` 时走这条：恢复 jar + config → 重启 | 红 |
| ⑩ | 上线自检 | 发布 | **把线上 jar 再拉回来逐条目比 CRC** + 实例数/16081/认证失败/端口冲突/OOM/ERROR 行数 | 红 |
| **⑩-2** | **协议连通自检** | 发布 | 本地直连 16081 跑协议矩阵：TEA 编解码往返 / TCP / 双向通道 / 未登录 GM 鉴权 / 会话存储（`PROTO_CHECK`；真登录默认关） | 红（关注项黄） |
| ⑪ | 回写发布记录 | 发布记录 | 写 `server_game/deploy/releases/<stamp>.{md,json}` + 重建 `INDEX.md` → 提交 release 分支 → 打 tag `rel-<stamp>` → （真上线时）push | 黄（`--warn-ok`） |
| ⑫ | 发布看板 | 交付 | 生成自包含 HTML，归档 + 拷到 `userContent` 固定地址 | 红 |
| **⑬** | **触发生产巡检** | 交付 | `build job: TS-Server-Health`（`wait:false`，异步，`SEND_MAIL=false`）——巡检另开一个 job，不阻塞发布 | 不阻塞（`HEALTH_AFTER`） |

> ⑭「完成通知」只在 `SEND_MAIL=true` 时出现，默认不发信，所以不计入上表。

#### ⑩-2 协议连通自检：为什么上线自检之后还要再连一次

「端口在听」和「协议通」是两件事。⑩ 那一步是 `ss -ltn | grep :16081` ——
它能证明 netty 起来了，证明不了下面这几层还是对的：

| 层 | 出错时的客户端表现 | 服务端能看到的 |
|---|---|---|
| TEA 密钥 / 32 轮 | 连上就断、进不去登录 | 只有一行 `decode->emsg=...` |
| 2 字节长度前缀 + 8 字节对齐 | 收包错位，越往后越乱 | 无日志或乱码日志 |
| 回包编码（`TeaEncoder`） | 客户端解析失败卡 Loading | 无日志 |
| 鉴权（未登录能否调 GM） | 正常客户端看不出来 | 无日志（提权缺口） |

实现：`scripts/verify/protocol_selftest.py`，**复用** `scripts/verify/gm_uid_login_probe.py`
里的 TEA/帧/Redis 原语（改密钥只改一处），按矩阵逐项出结论并顺带写
`CHECK|name|status|detail` 行给 `checks_to_junit.py`。

| 检查 | 口径 | 生产实测（2026-10-20） |
|---|---|---|
| `codec` | 纯本地：随机 20 帧（16B~4KB）加密→拆帧→解密必须回原文 | ✅ 20 帧一致 |
| `tcp` | 16081 可连 | ✅ 4ms |
| `duplex` | 发心跳帧后服务端**是否真的往回写字节**（零字节返回 ⇒ 解码/回包线程卡死） | ✅ 有回写 |
| `auth-guard` | 未登录直接发 `GM_REQUEST`，**不得**拿到 `GM_RESPONSE` | ✅ 无回包 |
| `session` | SSH 只读数 `JL_TOKEN:*` 条数（登录态写入链路） | ✅ 242 条 |
| `login-e2e` | 真登录 + GM（`40#uid#0`）。**默认跳过** | ⏭️ 默认关 |

🔴 `PROTO_LOGIN` 默认 `false`：真登录要拿某个真实账号的 token 建会话，
该号在线就会被顶掉。只有明确指定 `PROTO_OPERATOR` 且确认它不在线时才打开。
`login-e2e` 的判定里 **`In a formal setting`（生产 `debug=false`）算 pass** ——
它证明的是「登录通 + GM 协议通」，GM 业务关闭是配置不是故障。

退出码：`0` 全通或含跳过 / `3` 只有关注项（黄球）/ `1` 硬失败。


#### release 分支与「做好记录」

- 分支名：`release/x1-<版本>-<YYYYMMDD-HHmm>`（从 `SOURCE_BRANCH` 切，默认 `x1-tag-1.2.2`）。
- 🔴 **用 `git worktree` 而不是 `checkout`**：服务端主工作区常年有并行会话在改，
  在主工作区切分支会把人家 WIP 一起带走；独立 worktree 还能保证「release 分支 = 编译产物」这句话成立。
- 记录落在**分支里**（不是只留在 Jenkins 上），三件：
  - `server_game/deploy/releases/<stamp>.md` —— 人看的：源提交、脏项、注入统计、自检结论、环节明细
  - `server_game/deploy/releases/<stamp>.json` —— 机器看的：完整 diff 计数、`backup_dir`、健康检查
  - `server_game/deploy/releases/INDEX.md` —— 台账，每次**从 JSON 全量重建**（追加写法在重跑时会写重）
- tag：`rel-<stamp>`（annotated，message 带本次提交摘要）。
- 推送策略：**打包成功就推，一次原子推送**（`git push --atomic origin <branch> rel-<stamp>`）。
  演练也推 —— 演练与真上线的差别是「有没有动生产」，不该连「记录能不能追溯」也一起差别对待；
  三天后没人说得清那次演练注入了哪 58 个条目。嫌远端分支多时把 `PUSH_BRANCH` 设为 false。
  - 用 `--atomic` 而不是推两次：分支推上去而 tag 失败会留下「有分支没标签」的半截状态，回滚时只能靠猜。
    远端不支持 atomic 时自动退回逐条推（并标黄提示）。
- 提交只 `git add` 这三个路径 —— 🔴 绝不 `git add -A`（这个仓有并行会话在改源码，`-A` 会把别人的 WIP 卷进来）。

#### 三道闸门（默认「什么都不做」）

1. `DEPLOY=False`（默认）⇒ 只切分支 + 编译 + 比对 + 记录，**生产零写入**。
2. `DEPLOY=True` 且 `CONFIRM` 不等于「正式服」⇒ ① 环节直接 `error`（回滚时为「回滚」）。
3. `AUTO_APPROVE=False`（默认）⇒ ⑦ 停下来等人在页面点「确认部署」。

#### 注入边界（哪些条目永不自动注入）

`META-INF/*`、`application*.properties`、`*.properties`、`*.xml` —— 默认排除。原因：

- 注入 `MANIFEST.MF` 会改写 `Class-Path`，等于顺手换了整条依赖链（47 个 lib）；
- 编译产物里的 `application.properties` 是 `src` 的**开发配置**（`server.id=70001`、远程 Mongo），
  线上那份是 `deploy-overlay` 的生产配置，注入即连错库。

`ONLY_CLASSES` / `EXCLUDE_CLASSES` 可再收窄（热修口径用前者，例如 `com/ljsd/jieling/handler/*`）。

#### 可视化五件套

除 §4 的四件（stage 图 / JUnit 表格 / 构建描述 / `evidence/**`）之外，这个 job 多一件：

- **发布看板**：`evidence/release/release-report.html`（自包含、无外链），一页看完
  结论 KPI / 环节流水线 / 环节明细（含耗时）/ 每个 jar 的差异条形图与包分布 / 上线自检表。
  另拷贝到固定地址 **`http://localhost:8080/userContent/TS-Server-Release-latest.html`**（可收藏）。
- 构建描述形如：`✅ 7 个环节全部通过 | x1-1.2.2-20261019-2120 · 注入 58 条 · 演练 · 记录已推 origin`。
  「记录已推 origin / 记录仅本地」这一项是刻意加的：光有分支名说明不了它到底推没推上去。

#### 球的颜色语义（别把告警当噪音）

| 结果 | 含义 | 典型触发 |
|---|---|---|
| 蓝/绿 | 通过 | 演练或上线全链路无关注项 |
| **黄（UNSTABLE）** | 通过但**有需要人看一眼**的事 | 预检有 `[WARN]`（可用内存/磁盘偏低、缺重启脚本）、线上已有相同代码（`⑥` 全 0 条）、分支推送失败、`RESTART=none` |
| 红 | 失败 | 任一环节 `rc=1` |

🔴 **告警必须与「真会造成的后果」对齐**：长连接（会踢玩家）只在
`DEPLOY=true` 且 `RESTART≠none`，或 `ACTION=rollback` 时才算 `[WARN]`；
演练模式只打印一行 `[info] 生产服当前 N 条 16081 长连接（本次不重启，不影响）`。
早期版本一刀切当告警，结果线上只有 1 条心跳连接时演练也会变黄 —— 黄球一多就没人看颜色了（`#3` 实测踩到，`#4` 修正后转绿）。

#### 实测状态（2026-10-19）

- ✅ `#1` 演练（`DEPLOY=false`）：7 个环节全绿（预检/切分支/编译/校验/差异/记录/看板），
  JUnit `passCount=7`、stage 图 200、看板 200；产出 release 分支
  `release/x1-1.2.2-20261019-2030` + 记录提交 + tag `rel-20261019-2030`（本地，未推）。
- ✅ `#4` 演练（长连接告警语义修正后）：`SUCCESS`，255s，描述
  `✅ 7 个环节全部通过 | x1-1.2.2-20261019-2056 · 注入 58 条 · 演练`；产物 29 个（**无 jar**，
  证据目录从 34M 压到 152K）；看板 `userContent` 已刷新。
- ✅ `#5` 演练（**推送策略改为「打包成功即推」**）：`SUCCESS`，185s，描述
  `✅ 7 个环节全部通过 | x1-1.2.2-20261019-2120 · 注入 58 条 · 演练 · 记录已推 origin`。
  实测远端核验：`origin` 上出现 `release/x1-1.2.2-20261019-2120` 与 annotated tag
  `rel-20261019-2120`（都指向 `99aea56`，即记录提交），`meta.json` 里
  `pushed=true / pushed_branch / pushed_tag` 齐备；看板多一格「发布记录 · 已推送」。
- ✅ 注入机制在**生产 staging 副本**上验证过（不动线上）：抽取 2 个 class → `tar` → `zip -u` 分批 →
  `unzip -t` OK → 逐条目 CRC 与本地编译产物**完全相同**；复核的失败分支（清单里混入不存在的条目）会 rc=1。
- 🔴 **`DEPLOY=true` 尚未实跑**（会重启生产、踢线）⇒ 首次真上线必须由用户点头；
  建议先拿一次「只注 1~2 个类」的小范围热修（`ONLY_CLASSES`）走通全链路。

#### 演练分支要清理（否则本地 + 远端都攒）

每次构建都会切一条 `release/x1-...-<stamp>` 分支 + tag，并且**打包成功就推 origin**：

```bash
cd TimeSpaceServer/Server_x1tag1.2.2
git ls-remote --heads origin 'release/*'          # 远端有哪些
git branch --list 'release/*'                     # 本地有哪些
# 删远端 + 本地 + tag（一条一条来，别用通配批量删）
git push origin --delete release/x1-1.2.2-20261019-2030
git branch -D release/x1-1.2.2-20261019-2030
git tag -d rel-20261019-2030 && git push origin --delete rel-20261019-2030
```

🔴 **别对 `release/*` 通配批量删**：真上线的分支混在里面，删错就没有那次发布的事实记录了。
判断依据：记录里的 `deployed` 字段 —— `false` 是演练可删，`true` 必须留。
演练记录被删是**设计如此**（演练不产生发布事实）；Jenkins 侧还各留一份 `record.md` / `record.json` + 看板。


#### 排障

| 症状 | 先查什么 |
|---|---|
| ② 报「源码有未提交改动」 | 这个仓把 `server_game/.gradle_home`（11918 个文件）和 `dist/` 也纳入了版本管理 ⇒ 每编译一次就有十几项脏。脚本已把这类**构建残留**单独统计（只报告不阻断），真正阻断的是源码改动；急发时勾 `ALLOW_DIRTY`（不参与构建，仅留痕） |
| ③ 报「分支已存在」 | 同一分钟重复构建。换 `RELEASE_BRANCH` 或等一分钟 |
| ⑥ 全 0 条 | 线上已经和这个提交一致（重复发布）⇒ 黄球，不是失败 |
| ⑥ 提示 `overlay/application.properties 与线上不一致` | 类级注入**不更新** `deploy-overlay` 里的 `application.properties` / `logback-boot.xml`；要生效需单独注入该文件或走 package 模式 |
| ⑨ 报 `zip -u 失败` | 看 `deploy-staging/<stamp>/` 下的 `*.list`；条目名含空格/中文时 `zip` 会当作多个参数 |
| ⑩ 注入复核失败 | 说明 `zip -u` 没写进去。最常见原因：**没 `touch`**（zip 按 mtime 2 秒粒度判更新，同秒文件会被静默跳过） |
| 想回滚 | 同一 job 选 `ACTION=rollback` + `DEPLOY=true` + `CONFIRM=回滚`；或手工 `server_release.sh rollback` |

### 3.5 装机冒烟（`TS-Android-SmokeTest`，2026-10-20 新增）

**它解决的是「包能出 ≠ 能跑」。** 打包链只能证明 APK 合法，装上去闪退这件事以前只能靠人肉试。

六个环节，一环节一行结论：

| 环节 | 结论怎么来 | 判红/判黄 |
|---|---|---|
| ② 定位被测包 | `APK` 参数 / `apks/` 最新 | 没包 ⇒ 红 |
| ③ 设备与环境体检 | `device.sh probe`：adb / 设备 / 虚拟化 / 镜像 | **rc=3 ⇒ 黄（跳过）**，其余 ⇒ 红 |
| ④ 设备就绪 | 起模拟器等 `sys.boot_completed` / `adb connect` / 复用 | 起不来 ⇒ 红 |
| ⑤ 装包与启动 | `aapt2` 读包名 → `adb install -r -g` → `adb reverse` → `am start -W` → `pidof` | 装不上/启动即崩 ⇒ 红 |
| ⑥ 冒烟断言 | 8 条 CHECK → `smoke/junit.xml` | **崩了就是红**，环境问题不在这里 |
| 收尾（post） | 只关「自己起的」模拟器、只断「自己连的」远程设备 | 恒为通过 |

**为什么「环境不具备」判黄而不是红**：这台机器（macOS in VM，`kern.hv_support=0`）根本起不了
模拟器，判红只会训练人忽略红灯。黄球的信息量是「**没测**」，构建描述里也这么写。
真要它红，勾 `ALLOW_NO_DEVICE=False`。

**为什么实现放在共享库**：`jenkins-shared/lib/android/device.sh` 与工程无关（包名从 APK 读、
端口走参数、SDK 自动探测）。换平台只加一个 `TARGET` 分支，不复制脚本 —— 复制就会漂移，
这是共享库存在的理由（见 `jenkins-shared/README.md`）。

**没有设备也能验证**：

```bash
/usr/local/bin/bash /Users/wangxufeng/Documents/jenkins-shared/lib/android/selftest.sh
# 假 adb 跑通 resolve→up→install→smoke→down，再灌一条 FATAL 确认能报红
```

详细参数、断言判据、排障对照表、以及「换到 Linux KVM / Apple Silicon / Windows / 云真机 /
GitHub Actions」的具体改法：**`docs/android_emulator_smoke.md`**。

### 3.6 功能自动化（`TS-Test-*`，2026-10-20 新增）

**按「跑法节奏」分 job，按「功能」写用例。** 加一个功能测试 = 加一个 JSON，不新建 job。

| job | 需要设备 | 内容 | 实测 |
|---|---|---|---|
| `TS-Test-Lua` | ❌ | 15 个 headless Lua 测试，429 条断言 | **14/15 通过、0.9s**（本机已跑） |
| `TS-Test-Login` / `Battle` / `Func` | ✅ | `tests/cases/<组>/*.json` 设备用例 | 无设备 → 黄球跳过 |
| `TS-Test-Suite` | 部分 | Lua + 三组用例一次跑完 | Lua 段有效，设备段跳过 |

两个关键设计（细节见 **`docs/functional_test_automation.md`**）：

1. **`draft` 用例只记 skip，不判红。** 没在真机量过坐标的用例必然乱点，把「点错地方」判成
   「功能坏了」比不测更糟。勾 `CALIBRATE=true` 只出「重启 + 3/8/15s 截图 + logcat」，
   照着填坐标与日志锚点，再把 `draft` 改 `false`。
2. **已知失败走基线**（`tests/lua-baseline.json`）：失败条数 ≤ 基线记黄并写明原因，
   超过基线记红 —— **基线不会把新坏的也一起吞掉**；用例哪天自己绿了会提示删基线。

Lua 段的判定要认四种断言标记（`✅/❌`、`[PASS]/[FAIL]`、`N passed, M failed`、
`结果：N 通过 / M 失败`），最终以退出码为准；需要参数的用例在 `tests/tests.json` 的
`suites[0].tests` 里配 `args`。执行器是通用的 `jenkins-shared/lib/test_runner.py`
（`kind: lua`），同一个 job 模板换 `kind` 就能跑 C#/Python 测试 —— 见共享库 README「通用测试能力」。

> 本次顺手修了一个「假绿」：`test_rank_head_flag.lua` 缺 `RankingManager.GetGuildForeInfo` 桩，
> 跑到 [9] 就崩，`[9]~[11]` 的断言从来没执行过。补桩后跑出 32 过 1 失败，
> 那 1 条是**口径冲突**（产品注释说公会榜查不到会长就退回画自己，用例却期望隐藏）⇒ 进基线待产品拍板。

---

### 3.7 本地测试服一键部署（`TS-Local-Deploy`，2026-10-20 新增）

**要解决的问题**：手上改完服务端代码，想在本机测试服（`~/home/java`，游戏服 16081 + 登录服 Tomcat 8081）
上跑起来看看。以前这条链路全靠手打：编译 → 找出该替换哪些类 → 备份 → 停服 → `zip -u` → 起服 → 看日志。
每一步都有坑，而且**顺序错了的后果比失败更糟**（半新半旧的类在跑）。

现在点一次构建（默认参数即可）就完成全部动作，46 秒：

| # | 环节 | 干什么 | 判红 / 判黄 |
|---|---|---|---|
| ① | 参数与影响说明 | 打印这次会动什么、影响面（本机测试号掉线一次） | — |
| ② | 源码就绪与部署前体检 | JDK8 / 源码状态 / jar 与 lib **文件名集合 + 内容 CRC** 一致性；`SOURCE=origin 干净副本` 时用 worktree 拉远端 | 依赖集合变了 ⇒ **红**（注入带不上新依赖） |
| ③ | 编译 | JDK8 + `:serverlogic:jar :serverlogic:copyJars`，默认 `--offline` | 编译失败 ⇒ 红 |
| ④ | 差异分析 | 主 jar（`serverlogic`）**与 lib 下 6 个 module jar** 各自逐条目 CRC：变更 / 新增 / 排除 / 仅本地保留；两边条数合计决定要不要部署 | 合计无差异 ⇒ **黄**（`rc=3`，跳过部署、不重启） |
| ⑤ | 部署 | 备份（主 jar + 将改动的 lib module）→ 两边都**在副本上 `zip -u`** → 逐条目 CRC 复核 → `mv` 原子替换（先 lib 后主 jar）→ 重启 | 复核不符 ⇒ 红（对应文件未动） |
| ⑥ | 自检 | 端口 / `Started GameApplication` / 表数量（基线 280）/ 致命关键字 / ERROR 行数 / 协议探测 | 有 ERROR 或协议告警 ⇒ 黄 |
| ⑦ | 部署报告 | `artifacts/local-deploy.md` + `userContent/TS-Local-Deploy-latest.md` | — |

#### 为什么是「注入差异」而不是「整包覆盖」

`package.sh` 打的是**给线上用**的包，本地服不能这么做：

- 编译产物里的 `application.properties` 是 `src/main/resources` 的**开发配置**（`server.id=70001`、远程 Mongo），
  本地服那份是对着 `127.0.0.1` 改过的；`logback-boot.xml` 同理。
- `META-INF/MANIFEST.MF` 的 `Class-Path` 是本地 82 个 lib 的引用表，覆盖它等于换掉整条依赖链。
- 本地 jar 里可能有源码中已不存在的**补丁类**（历史事故：重建丢过 `SysUtil.class`）。

⇒ 只注入 CRC 真变了的条目，其余一律不碰。实测第一次跑：`变更 53 / 新增 3 / 排除 4 / 仅本地保留 1`
（那 1 条就是 `logback-boot.xml`，正好证明排除规则在起作用）。

#### 🔴 只注入主 jar 是不够的：lib 下 6 个 module jar 必须一起同步

`gameSrv-1.0.0.jar` 只是 `serverlogic` 的产物。`common` / `netty` / `gamecommon` / `hotfix` /
`fightmanager` / `tablemanager` 是**各自独立的 lib jar**，靠 MANIFEST 的 `Class-Path` 加载。
只注入主 jar ⇒ 改了 module 的方法签名后，运行期才炸：

```
Exception in thread "h-5" java.lang.NoSuchMethodError:
    com.ljsd.common.mogodb.MongoUpdateCacheThreadLocal.clear()I
    at com.ljsd.jieling.core.HandlerLogicThread.doWork(HandlerLogicThread.java:211)
```

2026-10-20 实际踩了一次：`common` 新增 `public static int clear()`，产物 20:15 就编出来了，
但部署只带了主 jar ⇒ `lib/common-1.0.0.jar` 还是 10-18 的旧版 ⇒ **每处理一条消息就打死一个
`h-N` 逻辑线程**，回包丢失 ⇒ 玩家侧的体感就是「老要重登」。更坑的是它带个假象：
主 jar 那 1999 条 CRC 完全一致，`diff` 判「无变化」，整次部署被跳过。

现在这 6 个 jar 也走「逐条目 CRC 差异注入」，与主 jar 同一套副本注入 + 复核 + 原子替换。
三条约束：

- **先 lib 后主 jar**：lib 多出方法不碍事，缺方法才炸；反序失败会留下「主 jar 新、lib 旧」。
- **`gamecommon` 排除 `util/SysUtil.class`**：那是「本地 lib 带补丁、gradle 重建后没补丁」的类，
  误注入会静默丢补丁（少加载配置表）。排除规则写死在 `LIB_MODULES` 第三列。
- **备份同批次配对**：`backup/lib-<stamp>/` 只放真正被改动的 jar，
  `rollback` 按 `gameSrv-<stamp>.jar ⇔ lib-<stamp>/` 一起还原。

#### 为什么是「副本注入 + 原子 mv」而不是「停服再改正式 jar」

1. `zip -u` 是**就地写**。运行中的 JVM 后续懒加载到被改过的条目 ⇒ 一半旧类一半新类 ⇒ `LinkageError`。
2. 先停服再改，改到一半失败 = **服务已停 + jar 半新**，恢复要人肉拼。

副本注入 + `mv`（同一文件系统，原子 rename）：运行中的进程始终读旧 inode，替换是瞬时的；
**失败时正式 jar 一个字节都没动**，服务照旧。三道闸门保证不会带着半成品替换：`zip` 失败 / CRC 复核不符都会
直接 `rm` 副本并退出。

#### 🔴 三个只有真跑才会发现的坑（都已修）

| 现象 | 真因 | 修法 |
|---|---|---|
| 自检全绿，**构建一结束进程就没了** | Jenkins `ProcessTreeKiller` 按 `HUDSON_COOKIE` / `JENKINS_SERVER_COOKIE` 环境变量杀光属于本次构建的进程 —— 它是按**环境变量**找进程的，`nohup`/`setsid` 都拦不住 | 拉起子进程时把 `HUDSON_COOKIE`/`JENKINS_SERVER_COOKIE`/`BUILD_*`/`WORKSPACE` 从环境里摘掉，再 `start_new_session=True` |
| `launchctl bootstrap` **恒 rc=5**（`Input/output error`），`install gs` 必失败 | Jenkins / agent shell 不在 Aqua 登录会话，无 launchd 写权限（`launchctl load -wF` 同样 5，老接口也没用） | **全程不碰托管状态**：托管中就用 `launchctl kickstart -k` 原地重启；未托管就用独立会话拉起。要真正恢复托管：**双击 `~/home/java/install-autostart.command`**（在 Terminal.app 会话里跑 `start-local.sh install`，失败会自动回退为手动启动） |
| `[[ 0\n0 -ge 0 ]]` 语法错、`ERROR 行统计` 崩 | `grep -c` 无匹配时**输出 0 且退出码 1** ⇒ `|| echo 0` 又追加一行 0 | 只兜空不兜零：`x="$(grep -c ... \|\| true)"; x="${x:-0}"` |

还有一个：备份用 `cp -p` 会保留**被备份 jar 的 mtime**，所以 `ls -t` 排不出「最近一份」，回滚会挑错备份
（实测挑成了第一次那份）。备份文件名本身带 `gameSrv-YYYYMMDD-HHMMSS` ⇒ 改成按文件名降序。

#### 参数

| 参数 | 默认 | 说明 |
|---|---|---|
| `SOURCE` | `本地工作区` | `本地工作区` = 含未提交改动（最贴近手上这版）；`origin 干净副本` = `git worktree` 拉 `origin` 分支，不受并行会话 WIP 影响（代价是全量编译） |
| `FETCH` | `True` | 只在 `origin 干净副本` 模式下 `git fetch`；本地工作区模式只做只读提示，**绝不 merge/pull**（这个仓常年有并行会话在改） |
| `SKIP_BUILD` | `False` | 复用上一次编译产物，只想重跑部署时用 |
| `GRADLE_ARGS` | `--offline` | 新增依赖时清空（离线会失败） |
| `SKIP_VERIFY` / `DRY_RUN` | `False` | 跳过自检 / 只演练不动本地服 |
| `NOTES` | 空 | 写进构建描述与报告，说明本次测什么 |

#### 手工等价命令（排障用）

```bash
B=/usr/local/bin/bash
$B .jenkins/lib/local_deploy.sh info        # 现状（端口/launchd/jar/git）
$B .jenkins/lib/local_deploy.sh precheck    # 部署前体检
$B .jenkins/lib/local_deploy.sh build       # 只编译
$B .jenkins/lib/local_deploy.sh diff        # 只看差异（不部署）
$B .jenkins/lib/local_deploy.sh deploy      # 注入 + 重启
$B .jenkins/lib/local_deploy.sh health      # 只跑自检
$B .jenkins/lib/local_deploy.sh rollback    # 回到最近一份备份（自动重启）
$B .jenkins/lib/local_deploy.sh rollback ~/home/java/gameserver/backup/gameSrv-20261020-202429.jar
```

备份保留最近 15 份（`~/home/java/gameserver/backup/`，每份带 `.sha256`，回滚前会校验）。

#### 幂等性：重复点构建不会把服务弄挂

代码已经在本地服上了再点一次，差异分析算出 `注入 0` ⇒ **跳过替换、跳过重启**（不改 jar、不踢人），
自检也只做端口/进程/协议连通检查（不再等 `Started GameApplication`——那轮根本没有新启动）。
实测 #9/#10：5/6 环节通过，唯一的黄是「代码与本地服完全一致，无需注入」，服务 pid 前后不变。

> 球的颜色语义：**黄 = 这次没做事 / 有需要看一眼的**，红 = 真的坏了。重复构建的黄是诚实的。

#### 实测（2026-10-20）

| 构建 | 结果 | 说明 |
|---|---|---|
| #1 | UNSTABLE | 注入 58 条 + CRC 全过；但 `bootstrap rc=5` 退回 nohup，且进程被 ProcessTreeKiller 收走 |
| #3 | UNSTABLE | 副本注入 65 条 + 原子替换跑通；`ERROR 统计` 的 `grep -c` 双零 bug 暴露 |
| #6 | SUCCESS | 6/6 环节 · 46s · 启动 6.0s · 280 表 · 0 ERROR · 协议 4 通过 2 跳过 |
| #7 | SUCCESS | 同上，且**构建结束后进程存活**（pid 常驻，16081 可连）—— ProcessTreeKiller 修复的验收 |

> 红线不变：这个 job **只动本机**，与生产服 `129.226.213.65` 毫无关系。
> 要发正式服请走 `TS-Server-Release`（默认 `DEPLOY=False` 演练）。

---

### 3.8 横幅美术字翻译（`TS-Art-Translate`，2026-10-21 新增）

**要解决的问题**：`ArtFont_zh/OperatingPanelAtlas/` 下这批战令横幅（`cn2-X1_zhanling_*_bg_zh.png`）
的标题和两行文案是**烘进图里的中文艺术字**（外发光 + 渐变 + 立体投影），TMP 文本做不出来，
英文版只能**重出一张图**。手工做法是在 PS 里一块块擦、再仿一块底板出来——擦不干净会留粉色鬼影，
底板接缝会出横条带。现在点一次构建就完成，**缺哪张补哪张，已存在的不动**。

| # | 环节 | 干什么 | 判红 / 判黄 |
|---|---|---|---|
| ① | 环境与清单体检 | 打印口径与影响面（`evidence/context.txt`）+ `scan` 盘点全目录（「开工盘点」） | 永远不判红（`--strict-ok`） |
| ② | 生成英文图 | 擦字 → 补底板 → 排白字，逐张出 `out.png` + `compare.png` | 尺寸不达标（占位图）⇒ **黄**（`rc=3`，跳过该张） |
| ③ | 像素级验收 | 六条断言逐张跑 | 任一断言不符 ⇒ **红** |
| ④ | 写回资源 | 覆盖 `ArtFont_en/...` 并补 `.meta`，原图先备份到 `ResBackpack/备份` | 已有英文版且未 `FORCE` ⇒ 跳过（黄） |
| ⑤ | 收尾复核与证据归档 | 再扫一次（「收尾清单」）+ 把 `compare.png` / `out.png` / `state.json` 按 `名字__文件` 收进 `evidence/artifacts/` + 写 `manifest.txt` | 仍有待生成的图 ⇒ **黄**（`rc=3`） |

六条断言（`verify`，全过才算通过）：

| # | 断言 | 阈值 |
|---|---|---|
| 1 | 与中文源图**尺寸一致** | 完全相等 |
| 2 | **alpha 通道逐字节一致** | 0 字节差异 |
| 3 | **重建区外零改动** | 0 px |
| 4 | 中文残留·粉色（`R-max(G,B) > 40`） | < 200 px |
| 5 | 中文残留·黄色（`R,G > 150 且 B < 110`） | < 200 px |
| 6 | 白字已排上（`min(R,G,B) > 200`） | > 2000 px |

#### 参数

| 参数 | 默认 | 说明 |
|---|---|---|
| `MODE` | `batch` | `batch` = 扫全目录，只补「缺英文版 **且** 译名表里有条目」的；`one` = 只做 `ASSET` 那一张 |
| `ASSET` | 空 | `MODE=one` 时必填，中文源图相对工程根的路径 |
| `FORCE` | `False` | 已有英文版的也重做（旧图先备份）。改了口径/译名时才勾 |
| `WRITE` | `True` | 传 `False` 则只出图、不动工程里的资源（构建页 `compare.png` 照样能看） |

译名**只认** `scripts/image/banner_translate_map.json`（单一真源，`_readme` 里写了口径）：
译名优先取游戏自己的语言表（`迷雾计划 → The Mist Plan`、`累计返利 → Total Rebate`），
并对齐**已上线的英文兄弟图**——它们去掉了第三行「累计返利」⇒ 新图也只排两行。

#### 🔴 四个只有真跑才会发现的坑（都已修）

| 现象 | 真因 | 修法 |
|---|---|---|
| 验收报「重建区外像素未被改动 — 越界改动 1832 px」 | 9px 的外发光**溢出**到 `ZONE_RIGHT=342` 之外 | 排字时用 `ImageChops.multiply(..., keep_mask)` 把光晕与字芯都裁在重建区内；`MAX_WIDTH` 330 → 306 |
| `operands could not be broadcast (100,342,3) (100,100,1)` | `cn2-X1_zhanling_yiduan_bg2_zh.png` 是 **100×100 占位图** | `run` 加尺寸闸门（`w<600 or h<400` ⇒ `rc=3` 判黄跳过）；`zone_for()` 里 `min(ZONE_RIGHT, w)` |
| 新生成的 `.meta` 让横幅**发虚** | 模板挑错了：`filterMode` 2 vs 1、`spriteMeshType` 1 vs 0、`applyGammaDecoding` 1 vs 0、`buildTarget` Android vs Default | `.meta` 按 **family** 选模板（先找同族 `*bg_en.png.meta`，再退到 `*_en.png.meta` / 中文同族），现在与 `pata_bg_en.png.meta` diff 只差 `guid` |
| 报告里「英文版清单」**出现两行** | `run_stage.sh` 与 python 的 `register()` 各写了一次 | 只保留收尾那次登记；`scan` 加 `--quiet` 不写行 |

> 还有一条语义坑：①「开工盘点」如果按「还有待生成的图」判黄，**每次构建都是黄球**（正常状态）。
> ⇒ 盘点用 `--strict-ok` 永远通过，「没做完」的结论挪到 ⑤「收尾清单」用 `--warn-rc 3`。

#### 实测（2026-10-21）

| 构建 | 结果 | 说明 |
|---|---|---|
| #1 | UNSTABLE | `WRITE=False` 演练，出图 + 验收全过，黄是「本次不写回」 |
| #2 | UNSTABLE | 环节本身全过，但 ①/② 都判黄 ⇒ 球色语义错（上一条坑） |
| #4 | SUCCESS | **6 个环节全部通过**，补出 `mota` / `yiduan` 两张并写回 |

> ⚠️ **范围限定**：只扫 `*_bg_zh.png`。`*_peitu_zh.png` 那批是纯配图、没有字，扫进来会误判。
> ⚠️ **已知缺陷**：`x≈340..375` 那道**蓝色光带**压在蓝底上，用板块色或背景色都盖不干净，
> 现在留成一块蓝色装饰块。要真正还原需要分层 PSD（手上的 `cn2-X1_zhanling_yiduan_bg_en.psd`
> 只有 2 个合并层，用不上）。配方细节见 **`docs/art_banner_translate_skill.md`**。

---

### 3.9 底部紫色虚化（`TS-Art-BottomFade`，2026-10-21 新增）

**要解决的问题**：横幅/底板的底边是**硬切**。贴在深色或紫色面板上，下沿就是一条刀切的线；
换成「下沿化开、溶进面板」的观感，本来是 PS 里拉个渐变蒙版+模糊的事。

**为什么单独做一个 job、而不走 `TS-Art-Restyle`**：这是**已经定稿的图只改下沿**。
走生图链路要烧一次模型额度，而且**出来的是另一张图**（构图/人物/文案全变了）——
拿回来的根本不是「原来的图 + 虚化」。渐变+模糊+alpha 收边每一步都能写成确定的算法，
所以它是纯像素工序：无额度、无随机性、可反复跑。

| # | 环节 | 干什么 | 判红 / 判黄 |
|---|---|---|---|
| ① | 参数与上下文 | 打印资源/带宽/色系/写回口径（`evidence/context.txt`） | 永不判红 |
| ② | 底部虚化 + 像素验收 | 末 N px 渐进高斯模糊 → 过渡到紫色 → 末行 alpha 收到 0，六条断言 | 断言不符 ⇒ **红**；已虚化过还重跑 ⇒ **黄**（`rc=3`） |
| ③ | 写回资源 | `--publish-only` 只写回不重算，原图先入背包（`.meta` 不动） | 写回失败 ⇒ **红** |
| ④ | 证据归档 | 对比图/成品/`fade.json` 收进 `evidence/`，并核对表1 的 `soft_bottom` / `post_ops` | 永不判红 |

六条断言（`bottom_fade.py check`）：

| # | 断言 | 阈值 |
|---|---|---|
| 1 | 尺寸未变 | 完全相等 |
| 2 | 色彩模式未变 | `RGBA`→`RGBA`（源是 `RGB` 不许变成 `RGBA`） |
| 3 | **虚化带以上零改动** | 最大通道差 = 0 |
| 4 | 带内转向紫色相 | `(B-R)` 均值至少 +6 |
| 5 | 带内高频能量下降 | 严格小于源 |
| 6 | 底边 alpha 收到 0，且带以上 alpha 未动 | 末行均值 < 4 / 带以上差 = 0 |

🔴 **幂等守卫**：已经虚化过的图（末行 alpha≈0）再跑一次会在原带上**再叠一层**——
紫色更重、细节更糊，而且**一声不报**。工具默认拒绝并返 `rc=3`，要叠第二层必须显式 `FORCE=true`。

**参数怎么调**：`PX` 是带宽（130 ≈ 436 高的 30%），`RIM` 是色系（`violet` 紫 / `ivory` 冷银 / `warm` 暖金）。
紫色太重就减 `PX`，不要减覆盖率——覆盖率写在 `restyle_pipeline._bottom_fade_rgb` 里，
模糊 0.92 / 染色 0.80 是分开的权重：只染色不模糊会像「压了一层紫滤镜」，一眼能看出是加了特效。

### 3.10 套外框（`TS-Art-Frame`，2026-10-21 新增）

**要解决的问题**：图的内容已经定了（甚至是手改过的），只需要给它加/换一道**游戏自己的**边框语言 ——
道具槽 `tongyong_daojukuang_01~07`、英雄卡 `yingxiongkuang_01~06`、对话框 `yindao_duihuakuang_02`
用的都是「暗带 + 亮边」。紫框 = 亮边选 `violet`（`206,158,246`），跟紫色面板同色系。

**为什么单独做一个 job、而不复用 `TS-Art-Restyle` 的 `FRAME=card`**：
框原本只是换风格链路的一个可选后处理，必须跟着生图走 —— 要烧一次额度，而且**出来的是另一张图**。
「内容已定稿、只加框」这个需求拿到的应该是「原图 + 框」，走生图是错的。
所以把画框拆成独立工序：同一份绘制代码（`restyle_pipeline.frame_card`），输入输出只有像素。

| # | 环节 | 干什么 | 判红 / 判黄 |
|---|---|---|---|
| ① | 参数与上下文 | 打印资源/样式/亮边/带宽/写回口径（`evidence/context.txt`） | 永不判红 |
| ② | 套框 + 像素验收 | 画框 → 11 条断言 | 断言不符 ⇒ **红**；已套过框还重跑 ⇒ **黄**（`rc=3`） |
| ③ | 写回资源 | `--publish-only` 只写回不重画，原图先入背包（`.meta` 不动） | 写回失败 ⇒ **红** |
| ④ | 证据归档 | 对比图/成品/`frame.json` 收进 `evidence/`，并核对 `_manifest.jsonl` 台账 | 永不判红 |

11 条断言（`frame_draw.py check`，card 样式）：

| # | 断言 | 阈值 |
|---|---|---|
| 1 | 尺寸未变 | 完全相等 |
| 2 | 色彩模式未变 | `RGB`→`RGB`（不许偷偷变 `RGBA`） |
| 3 | 外沿 1px 暗描边 | 均值亮度 < 40 |
| 4 | 框宽合理 | 16 ≤ bw ≤ 短边/8 |
| 5 | **亮边存在且够亮** | rim 圈均值 ≥ 110 |
| 6 | 亮边与暗描边有对比 | 差 ≥ 70 |
| 7 | 四角为硬切角 | 切角区均值 < 90（角上是墨带不是画面） |
| 8 | 内框暗槽存在 | `(6,4,10)`，均值 < 30 |
| 9 | 内框里是画面 | 与暗槽最大通道差 > 12 |
| 10 | 框带含网纹（非纯色） | 相邻像素差 > 0.2 |
| 11 | **内框内容 = 原图等比缩进** | 中心区平均通道差 < 6 |

🔴 **第 5 条是这套框能不能用的分水岭**：墨带 `(18,16,24)` 跟面板底 `(17,17,25)` 亮度几乎一样，
深色底上「只有墨带没有亮边」等于没画框。所以亮边不是装饰，是轮廓。

🔴 **画法是「画面缩进框内」（cover 到内框，缩 ~0.96）**，不是把框盖在画面上 ——
贴边的艺术字（如登录底板的 `8-DAY`）才不会被框咬掉字角。代价是内容会轻微重排。

🔴 **幂等守卫**：已套框的图外沿是「暗描边 + 亮边」，再套一次画面会再缩一圈、框带叠框带，
而每一步都算成功 ⇒ 工具默认拒绝并返 `rc=3`，要叠必须 `FORCE=true`；换框请先 `restore`。

**参数怎么调**：`RATIO` 是带宽比例（`0.022` 与换风格链路的 card 口径一致，1080x568 → 16px；
想更明显用 `0.028~0.032`），`RIM` 是亮边色板，`HAIRLINE=true` 会在带内侧再加一道细线
（默认关：亮边 + 内细线挤在窄带里会变成相框式双线）。

### 3.11 夜间测试包（`0 3 * * *` + 结果邮件，2026-10-21 新增）

**诉求原话**：「Jenkins 半夜 3 点直接打包测试包、不传 Play，直接拉最新 git 代码，传完发通用邮件告诉我版本 url。」
落地成三件事，全部挂在**已有的** `TS-Android-TestPackage` 上，没有新建 job —— 因为「出测试包」
这条链路（同步 → 预检 → Unity → 包内四重校验 → 收成产物）本来就是它，复制一份只会多一份要维护的漂移。

| 诉求 | 落在哪 | 关键实现 |
|---|---|---|
| 每天 03:00 自动跑 | job META 的 `"cron": "0 3 * * *"` | `render_job.py` 渲染成 `TimerTrigger`，`apply-jobs.sh` 推上去即生效（不用重启 Jenkins） |
| 拉最新 git 代码 | 已有 ①-1「代码同步」 | `ci_sync.sh`：`fetch` → 脏工作区 `stash` 快照 → `reset --hard origin/release` → 镜像 `.secrets/keystore/TimeSpaceServer`。**定时构建不会跳这一步**，因为它不是「可选参数」而是链路第一段 |
| 不传 Play | 本来就只到「收成构建产物」为止 | 全链没有一个上传动作（`play_upload.py` 只在 `TS-Android-Release` 里） |
| 邮件 + 版本 url | post 段 → `.jenkins/lib/notify_package.py` | 投递复用共享库 `notify.py` 的 `send()`（多候选授权码 / 465→587 / 失败分类重试，**不写第二份 SMTP**） |

**为什么邮件放 `post { always }` 而不是一个 stage**：夜间包**失败时更**需要这封信
（「没出包，因为 ③ 红了」），而 stage 在失败后会被 skip，只有 `post.always` 一定跑得到。

**邮件长什么样**（主题就能回答「有没有包 / 什么版本 / 连哪个服」）：

```
主题：✅【夜间测试包】TS-Android-TestPackage #17 · 1.2.51 (79) · 现网-129.226.213.65
      或 🔴【夜间测试包】… #18 · 出包未完成（无可用包） · 现网-129.226.213.65

结果: SUCCESS    版本: 1.2.51 (79)    连服: 现网-129.226.213.65
代码: release @ 3f2a1b9 · fix(client): …
包  : 1.2.51_vc79_030512.apk · 461M · md5 e682b0f3
下载: http://127.0.0.1:8080/job/…/17/artifact/artifacts/1.2.51_vc79_030512.apk
稳定地址: http://127.0.0.1:8080/job/…/lastSuccessfulBuild/artifact/artifacts/（可收藏）
本机路径: /Users/wangxufeng/Documents/TimeSpaceGirl1-build/apks/…
环节（11 个）: 全部通过          ← 有问题时逐条列出 🔴/⚠️ 环节 + 说明原文
```

**几个必须知道的坑（都已踩过 / 已挡住）**

- **`SERVER_ENV` 默认值从「测试服」改成了「现网-129.226.213.65」**。原因：测试服口径是
  `127.0.0.1:8081`，凌晨没人起本机测试服、也没人 `adb reverse`，包出来装上必然连不上；
  现网（柯测试服）装真机就能连。手动要连本机测试服，选参数即可。
- **choice 参数的默认值 ≠ `choices[0]` 会静默失效**：`render_job.py` 以前不写 `<defaultValue>`，
  Jenkins 就取第一个 choice，META 里的 `"default"` 被无声忽略（本次实测：页面默认值仍是「测试服」）。
  已给共享库补上 `<defaultValue>`（只在 default 确实在 choices 里时才写，写错值 Jenkins 会加载失败）。
- **发信失败不改球色**：`notify_package.py` 用 `sh(returnStatus: true)` 调用，rc≠0 只打一行
  `⚠️ 结果邮件没发出去`。包已经出好了，一个红球会让人以为包不能用。
- **收件人**：`MAIL_TO` 留空 = 共享库默认（`notify.py` 的 `NOTIFY_TO`，当前 `772616239@qq.com`）。
  口令来自 `jenkins-shared/.secrets/mail.env` 或工程 `.secrets/health.env`（本次用的是后者，日志会写明来源）。
- **想先看正文不发信**：`TS_MAIL_DRYRUN=1`（job 环境或临时改一行），或直接手动跑
  `.jenkins/lib/notify_package.py --run-dir <取证目录> --dry-run`。
- **定时与手动是同一条链**：手动跑也会发信（`SEND_MAIL` 默认 true），不想收就取消勾选；
  邮件里「触发」一行会写清是定时还是手动。

### 3.12 AB 复用缓存（`AB_MODE=复用缓存`，2026-10-23 新增）

**诉求原话**：「加一个不重建 AssetBundle 的选项，直接复用上一个打包的缓存来打包。」

原来只有 `REBUILD_AB`（bool）：勾 = 重建 5~8 分钟，不勾 = **什么都不做**。后者的问题是
「包里资源到底是什么」没人知道 —— 可能少了 `luabytes`（装上起不来），也可能是导表前的旧 Lua
（改了配置真机不生效），而这两种错**运行期都不报错**。所以改成三档 `AB_MODE`：

| 档位 | 做什么 | 耗时 | 什么时候用 |
|---|---|---|---|
| `重建`（默认） | Unity `BuildAllABs` + 复制到 StreamingAssets | 5~8 min | 改了 prefab / 图 / lua / xlsx |
| `复用缓存` | **不启动 Unity**，直接用打包目录上一轮重建的 `Assets/StreamingAssets/Android`，只做「对齐环境快照 + 校验缓存指纹」 | ~10 s | 只改了 C# / 打包参数 / 环境，资源没动 |
| `跳过` | 完全不碰 AB（不重建也不校验） | 0 | 只想导表 / 同步字节码，包内资源保持原样 |

**为什么缓存能跨构建存活**：`Assets/StreamingAssets/Android` 是 gitignore 的，`ci_sync.sh` 的
`git reset --hard` 不会删它 ⇒ 打包目录里天然留着上一次重建的产物，这就是「上一个打包的缓存」。

**复用前必须回答的三个问题**（`scripts/ab_cache.py` 是唯一实现）：

1. **缓存还在不在、全不全**：bundle 总数、`lzma|luabytes.unity3d`、`files.unity3d`、
   `lzma|resconfigs.unity3d` —— 缺任何一个都判红（包能装上但起不来 / 没有资源索引）。
2. **这份缓存是哪次重建产出的**：`build/ab_cache/manifest.json` 记 git HEAD / 时间 / 环境 /
   Lua bundle 的 `sha256` / 字节码全量内容哈希。指纹里 `bundle.sha256` 与现文件不符 ⇒ 打黄
   （缓存被别的构建覆盖过，指纹失效）。
3. **字节码从那之后变过没有**：`LuaBytes/**/*.bytes` 的**内容哈希**（不是 mtime）。
   变了 ⇒ **判红**，因为复用等于把旧 Lua 打进包。

**为什么用内容哈希而不是 mtime**：`git reset --hard` 会把改动过的文件重新检出 —— 内容一模一样、
mtime 变新。纯 mtime 判据（`check_lua_bundle_fresh.sh` 原来的口径）在这种场景下必然误报
「bundle 过期」。所以给硬闸门加了兜底：mtime 说过期时再问一次内容哈希，指纹对得上就放行
（判「不过期」时行为不变，老路径零影响）。

**怎么用**

```bash
# Jenkins：TS-Resource-Build（EXPORT_TABLES=false / SYNC_BYTES=false / AB_MODE=复用缓存 / SERVER_ENV=…）
# TS-Android-Release 也透传：REBUILD_RESOURCES=true + AB_MODE=复用缓存 ⇒ 整条发版链路省 5~8 分钟

# 手工（在打包目录或开发目录都行，不启动 Unity）
scripts/resource_build.sh --action reuse --server-env 正式服
python scripts/ab_cache.py verify --server-env 正式服    # 0 可用 / 1 不可用
python scripts/ab_cache.py record --server-env 正式服    # AB 重建后由脚本自动调
```

**边界（别踩）**

- 复用的是**打包目录**的缓存，不是开发目录的：两个目录各有一份 `StreamingAssets` 与
  `build/ab_cache/manifest.json`，互不相干。开发目录开着 Unity 也能跑（`reuse` 不做 Unity 占用检查）。
- `EXPORT_TABLES=true` + `复用缓存` 是自相矛盾的组合：导表会改 LuaBytes，④ 会因内容哈希不同判红。
- `跳过` 是「我知道自己在做什么」的逃生口：④ 不跑任何校验，⑤ 的 Lua 新鲜度闸门仍会拦。
- 首次复用（没有 `manifest.json`，比如缓存是本次改造之前重建的）只做存在性判断并打黄 ——
  先跑一次 `AB_MODE=重建` 把指纹立起来，之后复用才有内容级判据。

## 4. 「各环节可视化」到底指什么（四件产物）

用户原话是「**要求各环节可视化**」。落地成四件东西，每件都验证过：

| # | 产物 | 落在哪 | 实现 |
|---|---|---|---|
| ① | **stage 图**（含多层嵌套分组） | 构建页 | `pipeline-graph-view` 渲染；job 里用嵌套 `stages` 做分组 |
| ② | **测试结果表格 + 趋势图** | `/job/<n>/<b>/testReport/` | `stage_report.py junit` 生成 JUnit XML，`junit` 步骤收录 |
| ③ | **单行结论** | 构建页标题下 | `stage_report.py desc` → `currentBuild.description` |
| ④ | **证据归档** | 构建「归档」 | `evidence/**`（`context.txt` / `stages/*.json` / `logs/*.log` / `summary.md` / `junit.xml`） |

### 4.1 环节结论怎么变成「测试结果」

JUnit 没有原生「警告」级别。硬把 warn 当失败会红，当成功会骗人。所以：

- `pass` → 正常 `testcase`（绿）
- `fail` → `<failure>`（红）
- **`warn` / `skip` → `<skipped message="[WARN] …">`** ⇒ 既不在趋势图上冒充绿灯，也不误报失败。

`testsuite` 按**分组**（客户端资源链 / 打包环境 / 仓库卫生 / 发布安全 / Play / 服务端）划分，
所以测试结果页天然是一张「分组 → 环节 → 结果 → 说明」的表格。

### 4.2 构建球色：为什么要有黄球

Jenkins 默认只有红/绿。但本项目的很多事情天然是「**没坏，但值得看一眼**」：

- 打包环境就绪但 Unity 编辑器正开着（现在做不了包，不是缺陷）；
- 巡检发现可用内存 533MB 低于 600MB 线；
- 有未推送的提交。

把它判成红色，人会学会忽略红灯。所以 `stage_report.py status` 只吐 `pass|warn|fail`，
Pipeline 据此把构建置为 **`UNSTABLE`（黄球）**。**黄球是有信息量的。**

### 4.3 分级降级：`--warn-rc`

同一个检查要能区分「环境坏了」和「环境好的但有临时状态」。`android_env.sh` 因此分了退出码：

| rc | 含义 | 退出码语义 |
|---|---|---|
| 0 | 全部就绪 | — |
| 1 | 真问题（缺工具 / Gradle 模板被 GUI 重置 / 缺 keystore） | **必须红** |
| 2 | 环境错误（工程目录找不到） | — |
| **3** | 环境本身**就绪**，只是本工程被 Unity 编辑器占用 | **临时状态，只该黄** |

于是 `run_stage.sh` 支持 `--warn-rc 3`：

- **TS-Pipeline-Overview**（只读总览）用 `--warn-rc 3` ⇒ 黄球，不因「人开着编辑器」变红；
- **TS-Android-Release / -TestPackage** 什么都不加 ⇒ rc=3 就是**硬阻塞**（此时打包必失败，早点报早省事）。

### 4.4 验证命令（照抄即可）

```bash
U=a772616239; T=$(sed -n 's/^JENKINS_TOKEN=//p' ~/.jenkins/.qclaw-creds)

# ③ 构建描述 + 结果
curl -s -u "$U:$T" "http://localhost:8080/job/TS-Pipeline-Overview/6/api/json?tree=description,result"

# ② JUnit 表格
curl -s -u "$U:$T" "http://localhost:8080/job/TS-Pipeline-Overview/6/testReport/api/json?tree=passCount,failCount,skipCount"

# ④ 归档产物清单
curl -s -u "$U:$T" "http://localhost:8080/job/TS-Pipeline-Overview/6/api/json?tree=artifacts%5BrelativePath%5D"

# ① stage 图（pipeline-graph-view 的页面）
curl -sL -o /dev/null -w '%{http_code}\n' -u "$U:$T" \
  "http://localhost:8080/job/TS-Pipeline-Overview/6/pipeline-graph"
```

> 本机**没装** `pipeline-stage-view`，所以 `/wfapi/describe` 是 404。
> stage 图由 **`pipeline-graph-view`** 提供（构建页内嵌）。

---

## 5. 怎么触发构建（REST 的正确姿势）

```bash
CRUMB=$(curl -s -u "$U:$T" \
  "http://localhost:8080/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)")

curl -X POST -u "$U:$T" -H "$CRUMB" \
  --data-urlencode 'json={"parameter":[]}' \
  "http://localhost:8080/job/TS-Pipeline-Overview/buildWithParameters"
```

🔴 **别用 `POST /job/<n>/build`。** 本机实测（Jenkins 2.568）：

| 写法 | 结果 |
|---|---|
| `-X POST /build`（无 body） | **400 `Nothing is submitted`** |
| `-X POST --data '' /build` | 400 |
| `-X POST --data 'delay=0sec' /build?delay=0sec` | 400 |
| **`POST /buildWithParameters` + `--data-urlencode 'json={"parameter":[]}'`** | **201 ✅** |

带参数时**用表单字段，不要用 `json`**（2026-10-20 实测纠正）：

```bash
# ✅ 这样传真的生效（实测 NOTES 进了构建描述与 parameters API）
curl -X POST -u "$U:$T" -H "$CRUMB" \
  --data-urlencode 'NOTES=验证 XX 修复' \
  --data-urlencode 'SOURCE=origin 干净副本' \
  "http://localhost:8080/job/TS-Local-Deploy/buildWithParameters"

# ❌ 这样传**不生效**：构建能起来（201），但所有参数取默认值，
#    parameters API 里看到的是 defaultValue，NOTES=''。
#      --data-urlencode 'json={"parameter":[{"name":"NOTES","value":"x"}]}'
```

（`json` 只用于**无参数**构建：`--data-urlencode 'json={"parameter":[]}'` —— 这条是有效的。
之前的文档写成"带参数把 json 换掉即可"，实测在本机 Jenkins 2.568 上不行，已纠正。）

---

## 6. 推送前必跑：`.jenkins/lint.sh`

四道检查，**每次改完 `.jenkins/**` 都要跑**：

```bash
.jenkins/lint.sh              # 全跑
.jenkins/lint.sh TS-Server-Ops  # 只 lint 指定 job（① ② ④ 仍全量跑）
```

| # | 检查 | 为什么 |
|---|---|---|
| ① | **shell 花括号审计**：`$VAR` 后紧跟全角字符 | 本项目红线。`set -u` 下 `"…${STATUS}）"` 会把全角括号的字节并进变量名 ⇒ `unbound variable`，**报错行看起来完全正常** |
| ② | **Jenkins 集成陷阱**：裸引用插件变量 / `junit` 用绝对路径 | 见第 7 节坑 2 与坑 4 —— 这两类都是「静默失败」 |
| ③ | **声明式 Pipeline 语法校验**（走 Jenkins 官方 `/pipeline-model-converter/validate`） | 挡语法错 |
| ④ | — | （② 内含两条规则，编号按输出顺序） |

> ⚠️ **诚实说明 ③ 查不到什么**：该接口**只做 Groovy 语法检查，不校验 DSL 结构与步骤名**。
> 实测 `when` 写在 `steps` 里、`echoNope "x"` 这种它都判 `successfully validated`。
> 所以「用了不存在的步骤 / 放错位置」这类问题**只能靠真跑一次只读 job 发现**。

---

## 7. 🔴 本机踩过的坑（全部实测，别再踩第二遍）

### 坑 1：`POST config.xml` 不带 charset ⇒ 中文全变 HTTP 500

`Content-Type: application/xml` **没带 charset** 时，Jenkins 在 `POST /job/<n>/config.xml` 路径上走
`AbstractItem.doConfigDotXml` → `req.getReader()`；Servlet 规范规定 charset 未声明时
`getCharacterEncoding()` 返回 `null`，容器按 **ISO-8859-1** 解码 ⇒ 中文描述变乱码单字节 ⇒
SAX 报 `invalid XML character (Unicode: 0x94)` ⇒ **HTTP 500**。

最坑的是它的**假象**：

- `POST /createItem` 走的是 `req.getInputStream()`（交给 XML 解析器自认 UTF-8 声明）⇒ **正常**；
- 所以第一次「创建」全成功，第二次「更新」全 500 —— 会让人误以为请求头没问题。

✅ 修法：`apply-jobs.sh` 里四条 curl 统一用
`-H 'Content-Type: application/xml; charset=UTF-8'`。
（已实测：不带 charset → 500；带 → 200。）

### 坑 2：`sandbox=false` 会让「改一个字就构建不了」

`CpsFlowDefinition` 的 `<sandbox>` 写 `false` = 信任脚本、不沙箱。此时 workflow-cps 的
`create()` 会调 `ScriptApproval.using(...)` ⇒ **要求管理员在「In-process Script Approval」里逐份批准脚本内容**，
而批准对象是**脚本文本的哈希** ⇒ 仓库里改一个字，approval 立即失效，job 直接：

```
org.jenkinsci.plugins.scriptsecurity.scripts.UnapprovedUsageException: script not yet approved for use
Finished: FAILURE
```

（实测：首个能跑起来的构建 21 秒即 FAILURE，控制台第一行就是它。）

这等于把「改 job 不用点界面」的设计目标废掉 ⇒ **`render_job.py` 固定输出 `<sandbox>true</sandbox>`**。
沙箱下 job 只用标准 DSL + `env` / `currentBuild` 这类已白名单的访问，够用；
真撞上需要提权的调用，script-security 会把它挂到 Script Approval 页面上，那时才需要人介入
（而且是「单个方法」而非「整份脚本」）。

### 坑 3：`$BUILD_CAUSE` 来自没装的插件 ⇒ `unbound variable`

`BUILD_CAUSE` / `BUILD_USER_ID` 来自 **build-user-vars 插件，本机没装**。
`set -u` 下裸引用直接炸，而且因为 ① 阶段是致命阶段，**后面 8 个阶段全被 skip**。

这台机器上「Jenkins 核心自带、可裸用」的只有：
`BUILD_NUMBER` / `BUILD_ID` / `BUILD_TAG` / `BUILD_URL` / `BUILD_DISPLAY_NAME` / `JOB_NAME` /
`WORKSPACE` / `WORKSPACE_TMP` / `NODE_NAME` / `EXECUTOR_NUMBER` / `GIT_*`。
**其余一律写 `:-` 兜底** ⇒ `${BUILD_CAUSE:-（无 build-user-vars 插件，未记录原因）}`。

已做成 lint 检查 ② 的一条规则（并做过**负向测试**：探针文件必须被点名）。

### 坑 4：`junit` 的 `testResults` 给绝对路径 ⇒ 测试结果**静默空白**

给绝对路径时 `fileExists` 为真、步骤也会执行，但 glob 匹配不到任何文件，日志只说
`No test report files were found. Configuration error?` ⇒ **表格与趋势图永远空白**，
而 `[Pipeline] junit` 看起来一切正常。

✅ 修法：`junit ... testResults: 'evidence/junit.xml'`（**相对 workspace**）。
post 段本来就会 `cp -R "$TS_RUN_DIR/." "$WORKSPACE/evidence/"`，所以直接指过去即可。

### 坑 5：环节结论带着 ANSI 颜色码 ⇒ **整份测试报告**解析失败

环节结论取自被 `tee` 下来的日志的**最后一条非空行**，而日志带颜色码（`\x1b[1;32m…\x1b[0m`）。
**ESC(0x1b) 在 XML 1.0 里是非法字符**，写进 `junit.xml` 会让整份报告解析失败：

```
Failed to read test report file …/junit.xml
org.dom4j.DocumentException: … invalid XML character (Unicode: 0x1b)
```

表现是「测试结果」页整块只剩一条 **`[failed-to-read]`**，而控制台里 junit 步骤**一个字都不报**
（最坏的一种：静默失败）。

✅ 修法：`stage_report.py` 加 `sanitize()`（去 ANSI 序列 + 其余 C0 控制字符），三处生效：

1. `add` 登记时洗 —— 存进 JSON 的就是干净的；
2. `load` 读取时再洗一遍 —— **兜住历史记录**；
3. `junit` 写盘前对整份 XML 再洗一次 —— 最后一道闸。

另外把同一个 `sanitize()` 暴露成 `stage_report.py san`（stdin→stdout 过滤器），
给 `run_stage.sh` 算 `DETAIL` 时复用 —— **避免在两处各写一份正则**（迟早漂移）。

### 坑 6：workspace 不清理 ⇒ 归档里混进上几次构建的证据

`cp -R` 只增不删。实测构建 #5 的 `evidence/stages/` 里混了 #3 和 #4 的记录（看着像「同一个环节跑了两遍」）。
✅ 修法：复制前先 `rm -rf "$WORKSPACE/evidence"`
（有 `[[ -n "${WORKSPACE:-}" && -d … ]]` 守卫，只动本 job 自己的证据目录）。

### 坑 7（工具链）：沙箱里的 `ps` / `rmdir` 不可用

- `ps -o … -p <pid>` ⇒ `operation not permitted` ⇒ 用 `pgrep -fl` 代替。
- PATH 上的 `grep` / `rmdir` 可能是 WorkBuddy shim ⇒ 用 `/usr/bin/grep`、`/usr/bin/sed`。
- 临时目录别用 `mktemp -d` + `rmdir`（`~/Documents` 下会被拦）⇒ 用 `.jenkins/run/rendered`。

---

## 8. 排障清单

| 症状 | 先查什么 |
|---|---|
| `apply-jobs.sh` 报 **HTTP 500** | Content-Type 是不是漏了 `charset=UTF-8`（坑 1）。看 `~/Library/Logs`… 不对，看 `/usr/local/var/log/jenkins/error.log` 找 `SAXParseException` |
| 构建秒失败 + `UnapprovedUsageException` | `config.xml` 里 `<sandbox>` 是不是 `false`（坑 2） |
| 某 stage 一开始就 `unbound variable` | 是不是裸引用了插件变量（坑 3）；`bash -n` 查不出来，跑 `.jenkins/lint.sh` |
| **后面所有 stage 全 `skipped due to earlier failure`** | ① 阶段（准备与取证）失败了。它是致命阶段（`TS_RUN_DIR` 建不出来后面全废），属正常设计 |
| 测试结果页只有 `[failed-to-read]` | `junit.xml` 里有 XML 非法字符（坑 5，多半是 ANSI） |
| 测试结果页**空白**、日志说 `No test report files were found` | `testResults` 用了绝对路径（坑 4） |
| 归档里出现重复的 `stages/*.json` | workspace 没清理（坑 6） |
| 拿不到锁 | `lock.py status --name play` / `--name unity`；rc=75 = 有人占着 |
| 想知道某 job 到底注册了哪些环节 | `ls .jenkins/run/<BUILD_TAG>/stages/`，或看 `evidence/summary.md` |
| Jenkins 日志在哪 | `/usr/local/var/log/jenkins/error.log`（异常栈）、`output.log`（启动） |

---

## 9. 验收清单（改完 job 必过）

- [ ] `.jenkins/lint.sh` 全绿（四道）
- [ ] `.jenkins/apply-jobs.sh` → `完成：成功 8，失败 0`
- [ ] 参数核对无误：`.jenkins/apply-jobs.sh --list`
- [ ] **真跑一次 `TS-Pipeline-Overview`**（只读、无副作用），核对四件产物：
  - [ ] stage 图有多层嵌套分组
  - [ ] 测试结果表格有 8 个环节、按 6 个分组排列
  - [ ] 构建描述是 `stage_report.py desc` 的单行结论
  - [ ] `evidence/**` 归档条目数 = **21**（5 个文件 + 8 个 log + 8 个 stage json）
- [ ] 动过服务端发布链路的话，**真跑一次 `TS-Server-Release`（`DEPLOY=False`）**：
  - [ ] 7 个环节全绿、`testReport` 的 `passCount=7`
  - [ ] 构建描述形如 `✅ 7 个环节全部通过 | x1-1.2.2-<stamp> · 注入 N 条 · 演练`
  - [ ] `evidence/release/release-report.html` 打得开，且 `~/.jenkins/userContent/TS-Server-Release-latest.html` 已更新
  - [ ] 归档里**没有** `*.jar`（基线 jar 不入归档，见 3.4）
  - [ ] 跑完 `git -C TimeSpaceServer/Server_x1tag1.2.2 worktree list` 只剩主工作区（worktree 已回收）
- [ ] 球色语义正确：有 warn 但无 fail ⇒ **黄球（UNSTABLE）**，不是红球
- [ ] 改过 `checks/*.sh` 的话，确认退出码语义没被改坏（尤其 `android_env.sh` 的 rc=3）

> 为什么必须真跑：`pipeline-model-converter/validate` 查不到 DSL 结构问题（第 6 节），
> 本机这四个坑里有三个（坑 2/3/5）都是**静态检查过了、跑起来才炸**。

> **2026-10-13 实跑核对**：`lint.sh` 四道全绿 · `apply-jobs.sh` 完成 7/失败 0 ·
> `TS-Pipeline-Overview` #8 / #9 连两次黄球（7 通过 · 0 失败 · 1 关注）·
> `evidence/**` 归档 **21** 条（5 文件 + 8 log + 8 stage json）✓。

---

## 10. 限制与待办

### 已验证（2026-10-13 傍晚实跑）

| job | 结果 | 说明 |
|---|---|---|
| `TS-Pipeline-Overview` | **UNSTABLE**（#8 / #9 连两次） | 7 通过 · 0 失败 · 1 关注；黄球符合设计 |
| `TS-Client-Resources`（`ACTION=check`） | **SUCCESS** #1 | 字节码一致性 + AB 就绪体检，真跑了环节 |
| `TS-Server-Health` | **SUCCESS** #1 | 默认 `SEND_MAIL=false`，只采集不发信 |
| `TS-Play-Watch` | **SUCCESS** #2 | 默认 `DRY_RUN=true`，不发信、不写状态 |
| `TS-Server-Release` | **SUCCESS** #1（2026-10-19，演练） | 7 环节全绿 · 注入 58 条 · 产出 release 分支+记录+tag（本地） |

- ✅ 球色语义符合设计：**有 warn 无 fail ⇒ 黄球（UNSTABLE）**；有 fail ⇒ 红球。
- 🔴 **送审闸门自检曾偶发假红**：同一份代码在 Jenkins 判 fail（rc=2 却判「竟然放行」），
  本地连跑 17 次全绿。根因是判定用了 `printf '%s' "$out" | grep -q 拒绝` ——
  `set -o pipefail` 下 `grep -q` 命中即退、写端收 SIGPIPE(141)，把「已命中」读成「未命中」。
  已改 shell 内建子串比较，并把失败诊断从 `tail -3` 改为打印完整输出（`930965657`）。
  **教训：自检本身也是代码，也会出假红 —— 假红比没有自检更糟（会训练人忽略它）。**

### 仍未做

- [x] **`TS-Android-TestPackage` 已实跑**（2026-10-17 #1 / #2 / #3）：#2 九环节全绿、产出
  `1.2.51_vc74_215144.apk`（965M）；#3 验证「APK 本体进构建产物」这次改造。
- [ ] **未实跑过的 job**：`TS-Android-Release`、`TS-Server-Ops`。
  它们含破坏性动作（Unity 打包 / 重启游戏服会踢线 / 上传）⇒ **需要用户明确同意才能试跑**，不自行验证。
- [ ] **`TS-Server-Release` 的 `DEPLOY=true` 路径未实跑**（会写生产 jar 并重启、踢线）。
  已做的替代验证：注入机制在生产 `deploy-staging/` 的**副本**上跑通（`zip -u` 分批 + `unzip -t` +
  逐条目 CRC 与本地一致），复核失败分支也验过。首次真上线建议先用 `ONLY_CLASSES` 只注 1~2 个类走通全链路。
- [ ] 发布记录目前落在 `release` 分支（本地）；**推送策略是「只有真上线才 push」**，
  所以演练产生的分支不会出现在 origin。若希望演练也留远端痕迹，把 `PUSH_BRANCH` 的逻辑改成随 `record` 无条件推。
- [ ] `TS-Server-Health` / `TS-Play-Watch` 的**定时触发尚未自然触发**过 ——
  注意 `H 9 * * *` / `H 10 * * *` 里 `H` 是**分钟**、`9` / `10` 是**小时** ⇒
  含义是「**每天 9 点 / 10 点各一次**」，**不是每小时**。这两个 job 建于当天 14:13，
  已过当日窗口，要等**次日早晨**才能确认调度真的会响。目前只经 REST 手动触发验证过。
- [ ] `junit` 趋势图需至少两次构建；`TS-Pipeline-Overview` 现已有 #4（失败）→ #9（7 通过）多条可比。

### 已知黄球（非缺陷）

- `本地 10002 区服状态` → `找不到 10002 区服目录：/Users/wangxufeng/ts-shard10002`。
  本地区服目录当前不存在（脚本按 `$HOME/ts-shard10002` 找）。该环节计为「关注」而非「失败」，
  不阻断流水线；要恢复本地 10002 区服见记忆 `REF-shard10002.md`。
- 打包类 job 的 `android_env.sh` rc=3（编辑器占着工程）今天**没有出现**：
  当前只有 Unity Hub 在跑、无编辑器实例，故「打包环境预检」是 ✅ 而非黄球。

## 11. 打包目录（TimeSpaceGirl1-build，2026-10-20 起）

**结论：打包类 job 不再在开发目录构建。** `TS-Android-Release` / `TS-Android-TestPackage` /
`TS-Resource-Build` 的 `PROJ` 已切到独立 clone `/Users/wangxufeng/Documents/TimeSpaceGirl1-build`，
开发目录开着 Unity 编辑器也能打包 —— 两个 Unity 实例各锁各的工程
（`android_env.sh` / `resource_build.sh` 的占用检查按 `-projectpath` 精确匹配，互不误伤）。

### 同步口径（`.jenkins/ci_sync.sh`，job 的 ①-1 阶段自动跑）

1. `git fetch origin <分支>`（origin = GitHub）
2. 工作区若有改动（上次构建/导表残留）→ `git stash` 快照（可恢复）→ `reset --hard origin/<分支>`。
   **打包目录的本地改动一律不是真源。**
3. 从开发目录镜像不入库资产：`.secrets/`、`keystore/`、`TimeSpaceServer/`（凭据与独立服务端仓
   git 拉不到，开发目录是真源）。

### 边界与红线

- 🔴 `ci_sync.sh` 只允许在打包目录跑（`.jenkins/run/.CI_BUILD_DIR` 标记 + origin 必须是 GitHub），
  误在开发目录执行会 `reset --hard` 掉未提交工作，防呆必须挡死。
- **Library / BuildABs / StreamingAssets 不在 ci_sync 职责内**：Library 首次从开发目录播种后由
  打包目录自己维护（Unity 增量）；AB 过期由 `check_ab_ready.sh` 闸门拦住 → 重跑
  `TS-Resource-Build` 在打包目录重建。
  🔁 **不想重建时**用 `AB_MODE=复用缓存`（见 §3.12）：直接吃打包目录里上一轮的
  `StreamingAssets/Android`（gitignore，跨 reset 存活），④ 只做缓存指纹校验，约 10 秒。
- 改了 xlsx / Lua / 资源想打进包：**先在开发目录 commit + push，再触发打包** —— 打包目录只认
  origin，开发目录未推送的改动打不进包（这是特性不是 bug）。
- 其余 job（Server-* / Pipeline-Overview / Test-* / Art-Restyle / Client-Resources）**仍在开发目录**，
  不受本次切换影响。
- 首次播种清单（rsync 自开发目录，仅一次）：`Library/`（12G，省首次导入）、`BuildABs/`（843M）、
  `Assets/StreamingAssets/Android/`（432M）、未跟踪的零散工作文件。
