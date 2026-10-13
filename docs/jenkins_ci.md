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
│   ├── TS-Android-Release.groovy       AAB 全链路
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
│   ├── find_artifact.py       按 mtime 定位「本次」产物；**默认拒绝回退到旧包**
│   ├── server_ops.sh          服务端动作统一派发口（14 个动作，标注破坏性/只读）
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

## 3. 七个 job

视图：**「时空美少女 · 全流程」**（`ListView`，含全部 7 个 job，带状态球/天气/上次成功/耗时/构建按钮列）。

| Job | 做什么 | 参数（默认值） | 定时 | 并发 |
|---|---|---|---|---|
| **TS-Pipeline-Overview** | 只读总览：一次看完 8 个环节，失败互不阻断 | `SKIP_PLAY=False` `SKIP_HEALTH=False` | — | 允许 |
| **TS-Android-Release** | AAB 全链路（9 stage），含**送审审批闸门** | `EXPECT_PROFILE=minimal` `BUMP_VERSION=True` `REUSE_AAB=` `ALLOW_NO_LUA=False` `UPLOAD=False` `TRACK=production` `STATUS=draft` `PUBLISH=False` `NOTES=` | — | **禁止** |
| **TS-Android-TestPackage** | 出测试 APK（universal，upload key 签名） | `BUMP_VERSION=False` `EXPECT_PROFILE=minimal` | — | **禁止** |
| **TS-Client-Resources** | Lua 源码 → LuaBytes 字节码 同步/复核 | `ACTION=check` `LUA_FILES=` | — | 允许 |
| **TS-Server-Health** | 生产游戏服巡检（只读，默认不发信） | `SEND_MAIL=False` `TO=` | `H 10 * * *` | 允许 |
| **TS-Server-Ops** | 服务端/区服运维动作统一入口 | `ACTION=health` `CONFIRM=` `REASON=` | — | 允许 |
| **TS-Play-Watch** | Play 轨道 + 16KB 合规巡检 | `DRY_RUN=True` `NO_MAIL=False` `AAB=` `TO=` | `H 9 * * *` | 允许 |

### 3.1 送审红线（三层闸门，写在代码里）

> 红线：**绝不自行提交审核。** 打包/构建/校验可以做；**「上传 production + `status=completed`」必须先获用户明确同意。**

1. **参数默认值**：`UPLOAD=False`、`STATUS=draft`、`PUBLISH=False`。
2. **运行时硬拦**：`STATUS in [completed, inProgress] && !PUBLISH` ⇒ `error(...)` 直接失败（防「下拉框手滑」）。
3. **人工审批**：上传 stage 带 `input` 步骤，必须有人点确认。

另有 `play_gate.sh` 做**行为断言**：真跑 `aab_release.sh --skip-build --upload --status completed` 等组合，必须被拒绝且输出含「拒绝」——防止哪天有人把默认值改松了而没人发现。

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
- [ ] `.jenkins/apply-jobs.sh` → `完成：成功 7，失败 0`
- [ ] 参数核对无误：`.jenkins/apply-jobs.sh --list`
- [ ] **真跑一次 `TS-Pipeline-Overview`**（只读、无副作用），核对四件产物：
  - [ ] stage 图有多层嵌套分组
  - [ ] 测试结果表格有 8 个环节、按 6 个分组排列
  - [ ] 构建描述是 `stage_report.py desc` 的单行结论
  - [ ] `evidence/**` 归档条目数 = **21**（5 个文件 + 8 个 log + 8 个 stage json）
- [ ] 球色语义正确：有 warn 但无 fail ⇒ **黄球（UNSTABLE）**，不是红球
- [ ] 改过 `checks/*.sh` 的话，确认退出码语义没被改坏（尤其 `android_env.sh` 的 rc=3）

> 为什么必须真跑：`pipeline-model-converter/validate` 查不到 DSL 结构问题（第 6 节），
> 本机这四个坑里有三个（坑 2/3/5）都是**静态检查过了、跑起来才炸**。

---

## 10. 限制与待办

- [ ] **未实跑过的 job**：`TS-Android-Release`、`TS-Android-TestPackage`、`TS-Server-Ops`。
  它们含破坏性动作（重启游戏服会踢线 / 上传）⇒ **需要用户明确同意才能试跑**，不自行验证。
- [ ] `TS-Server-Health` / `TS-Play-Watch` 的定时触发**尚未等到自然触发一次**（`H 9` / `H 10`），
  目前只用 REST 手动触发验证过。
- [ ] 本机有 Unity 实例（pid 76463）占用本工程 ⇒ 打包类 job 现在跑不了（这正是 `android_env.sh`
  rc=3 那条黄球在说的事）。**关掉编辑器即可**，不是代码问题。
- [ ] `.jenkins/**` 尚未 commit（本次一并提交）。
- [ ] `junit` 的趋势图需要**至少两次**构建才有曲线；目前 #4（失败）→ #6（7 通过）已能看出差异。
