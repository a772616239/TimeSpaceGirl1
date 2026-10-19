# Jenkins 全流程 CI（`.jenkins/` + 本机 Jenkins）

> 更新时间：2026-10-12
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
│   ├── TS-Client-Resources.groovy      Lua 源码 ↔ 字节码
│   ├── TS-Server-Health.groovy         生产服巡检（定时）
│   ├── TS-Server-Ops.groovy            服务端/区服运维动作
│   └── TS-Play-Watch.groovy            Play 轨道与 16KB（定时）
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
    └── <BUILD_TAG>/          每次构建的证据目录（stages/ logs/ junit.xml summary.md）
```

---

## 3. 八个 job

视图：**「时空美少女 · 全流程」**（`ListView`，含全部 8 个 job，带状态球/天气/上次成功/耗时/构建按钮列）。

| Job | 做什么 | 参数（默认值） | 定时 | 并发 |
|---|---|---|---|---|
| **TS-Pipeline-Overview** | 只读总览：一次看完 8 个环节，失败互不阻断 | `SKIP_PLAY=False` `SKIP_HEALTH=False` | — | 允许 |
| **TS-Android-Release** | **AAB + APK** 全链路（10 stage），默认打包 + 上传发布 | `SERVER_ENV=正式服` `EXPECT_PROFILE=minimal` `BUMP_VERSION=True` `BUILD_APK=True` `REUSE_AAB=` `ALLOW_NO_LUA=False` `UPLOAD=True` `TRACK=internal` `STATUS=completed` `PUBLISH=False` `AUTO_APPROVE=True` `NOTES=` | — | **禁止** |

> **`BUILD_APK`（默认 True）**：打完 AAB 立刻在同一把 `unity` 锁下再出 **同 versionCode** 的 universal APK
> （`--no-bump`，绝不二次提号），供直接装机测试。
> - APK 失败**不阻断** AAB 发版（红线是 Play 包），但会记成「关注」并在归档里写明「本次未产出 APK」。
> - APK 会单独跑 `verify_apk_delivery.py` 生成 `.delivery.json`（口径 / 16KB / googlesignin / 签名），
>   ⑦ 的三重校验只针对 AAB —— 不单独校，就是「发出去的装机包没人验过」。
> - ⚠️ APK 用 upload key，与 Play 的 app signing key 不同 ⇒ **侧载前必须先卸载 Play 版**。

| **TS-Android-TestPackage** | 出测试 APK（universal，upload key 签名） | `SERVER_ENV=测试服` `BUMP_VERSION=False` `EXPECT_PROFILE=minimal` | — | **禁止** |

> **`TS-Android-TestPackage` 的产物就是 APK 本体**（2026-10-17 修正）：构建页「Build Artifacts」
> 里直接挂着 `artifacts/<版本>_vc<N>_<HHmmss>.apk`，点一下就下载，不用去磁盘上翻 `apks/`。
> 构建描述也会写成 `✅ 9 个环节全部通过 · APK 1.2.51_vc74_215144.apk · 965M`。
> - 另有**固定下载地址** `http://localhost:8080/userContent/TS-TestPackage-latest.apk`，
>   永远指向最新一次的 APK（`userContent/` 下的软链，构建时自动重建）。适合存书签 / 发给自己。
> - 🔴 以前只归档 `evidence/**`，APK 本体只留一行**相对路径文本** ⇒ 构建页一个安装包都下不到，
>   且那条相对路径离开工程目录就指不到文件。这是「生成物应该是 apk」这个诉求的真正堵点。
> - 归档用 `cp -c`（APFS clone，写时复制）：965MB 瞬间就位、不额外占盘；跨卷时自动退化成硬链接或真复制。
> - 产物**只留最近 3 份 / 14 天**（META `artifactKeep` / `artifactDays`）。不设限则 30 次 × 965MB ≈ 29GB。
> - 本次没产出 APK 时，post 段会**清空** `workspace/artifacts/`：宁可不给下载，也不把上一次的旧包当本次产物挂上去。

| **TS-Client-Resources** | Lua 源码 → LuaBytes 字节码 同步/复核 | `ACTION=check` `LUA_FILES=` | — | 允许 |
| **TS-Server-Health** | 生产游戏服巡检（只读，默认不发信） | `SEND_MAIL=False` `TO=` | `H 10 * * *` | 允许 |
| **TS-Server-Ops** | 服务端/区服运维动作统一入口 | `ACTION=health` `CONFIRM=` `REASON=` | — | 允许 |
| **TS-Server-Release** | **服务端代码发包正式服**：切 release 分支 → JDK8 编译 → 与线上逐条目 CRC 比对 → 审批 → 备份 → 注入差异类 → 重启 → 自检 → 回写发布记录 | `ACTION=release` `SOURCE_BRANCH=x1-tag-1.2.2` `RELEASE_BRANCH=` `DEPLOY=False` `CONFIRM=` `AUTO_APPROVE=False` `ONLY_CLASSES=` `EXCLUDE_CLASSES=` `RESTART=gameserver` `ALLOW_DIRTY=False` `PUSH_BRANCH=True` `ROLLBACK_DIR=` `NOTES=` `SEND_MAIL=False` | — | **禁止** |
| **TS-Play-Watch** | Play 轨道 + 16KB 合规巡检 | `DRY_RUN=True` `NO_MAIL=False` `AAB=` `TO=` | `H 9 * * *` | 允许 |

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

#### 12 个环节

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
| ⑪ | 回写发布记录 | 发布记录 | 写 `server_game/deploy/releases/<stamp>.{md,json}` + 重建 `INDEX.md` → 提交 release 分支 → 打 tag `rel-<stamp>` → （真上线时）push | 黄（`--warn-ok`） |
| ⑫ | 发布看板 | 交付 | 生成自包含 HTML，归档 + 拷到 `userContent` 固定地址 | 红 |

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

---

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

带参数时把 `json` 换成 `{"parameter":[{"name":"SKIP_PLAY","value":"true"}, …]}`。
（`--data-urlencode` 是必须的：`json` 里含 `{` `}` `"`。）

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
