# REF · Jenkins 全流程 CI（`.jenkins/` + 本机 Jenkins）

> **权威文档在仓库里：`docs/jenkins_ci.md`**（job 拓扑 / 参数 / 排障 / 验收清单全在那）。
> 这里只留「下次动手前必须知道、且不该去翻文档才发现」的硬事实。

## 基本盘
- 本机 Jenkins **2.568**，Homebrew 装的（`/usr/local/Cellar/jenkins/2.551/libexec/jenkins.war`,
  Homebrew 版本号与核心版本号不一致，看核心版本），绑 `127.0.0.1:8080`，根目录 `~/.jenkins`。
- 🔴 **日志在 `/usr/local/var/log/jenkins/error.log`**（异常栈）与 `output.log`（启动）。`~/.jenkins/logs/` 里没有主日志。
- 凭据 `~/.jenkins/.qclaw-creds`（`JENKINS_URL` / `JENKINS_USER=a772616239` / `JENKINS_TOKEN`）。
- 安全：`useSecurity=true` + `FullControlOnceLoggedInAuthorizationStrategy` + `denyAnonymousReadAccess`。
- 视图 **「时空美少女 · 全流程」**，7 个 job：`TS-Pipeline-Overview` / `TS-Android-Release` /
  `TS-Android-TestPackage` / `TS-Client-Resources` / `TS-Server-Health` / `TS-Server-Ops` / `TS-Play-Watch`。
- 装了 `pipeline-graph-view`（stage 图来源），**没装** `pipeline-stage-view` ⇒ `/wfapi/describe` 是 404（别误判成坏了）。
  也**没装** `blueocean` / `build-user-vars` / `ansi-color` / `lockable-resources` / `htmlpublisher`。

## 🔴 七个坑（全部实测，静态检查挡不住前三个中的 2、3、5）
1. **`POST /job/<n>/config.xml` 的 `Content-Type` 必须带 `charset=UTF-8`**，否则中文 → ISO-8859-1 解码 →
   SAX `invalid XML character` → **HTTP 500**。假象：`createItem` 走 `getInputStream()`（正常），
   所以「首次创建成功、第二次更新全 500」会骗人。
2. **`CpsFlowDefinition` 的 `<sandbox>` 必须 `true`**。写 `false` ⇒ 要求管理员逐份批准脚本内容，
   而批准对象是**脚本文本哈希** ⇒ 仓库改一个字就 `UnapprovedUsageException`，直接废掉「改 job 不用点界面」。
3. **`BUILD_CAUSE` / `BUILD_USER_ID` 来自没装的 build-user-vars 插件** ⇒ `set -u` 下裸引用 unbound。
   核心里能裸用的只有 `BUILD_NUMBER/ID/TAG/URL/DISPLAY_NAME`、`JOB_NAME`、`WORKSPACE`、`WORKSPACE_TMP`、
   `NODE_NAME`、`EXECUTOR_NUMBER`、`GIT_*`；其余一律 `:-` 兜底。
4. **`junit` 的 `testResults` 必须相对 workspace**。绝对路径 ⇒ `fileExists` 为真、步骤会跑，
   但 glob 匹配不到 ⇒ **测试结果表格与趋势图静默空白**。
5. **ANSI 颜色码会让整份 JUnit 报告解析失败**（`ESC=0x1b` 是 XML 1.0 非法字符）⇒
   测试结果页只剩一条 `[failed-to-read]`，**控制台一字不报**。
   `stage_report.py` 的 `sanitize()` 在 add / load / 写盘三处生效；`run_stage.sh` 复用 `stage_report.py san`。
6. **workspace 不清理** ⇒ `cp -R` 只增不删 ⇒ 归档里混进上几次构建的 `stages/*.json`。复制前先删本 job 的 `evidence/`。
7. **沙箱工具限制**：`ps -p` 不可用（用 `pgrep -fl`）；PATH 上的 `grep`/`rmdir` 可能是 shim（用 `/usr/bin/grep`）；
   `mktemp -d` + `rmdir` 在 `~/Documents` 下被拦（用 `.jenkins/run/rendered`）。

## 触发构建的正确姿势
```bash
U=a772616239; T=$(sed -n 's/^JENKINS_TOKEN=//p' ~/.jenkins/.qclaw-creds)
CRUMB=$(curl -s -u "$U:$T" "http://localhost:8080/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)")
curl -X POST -u "$U:$T" -H "$CRUMB" --data-urlencode 'json={"parameter":[]}' \
  "http://localhost:8080/job/TS-Pipeline-Overview/buildWithParameters"   # → 201
```
🔴 **`POST /job/<n>/build` 在 2.568 上恒 400 `Nothing is submitted`**（裸 POST / `--data ''` / `--data 'delay=0sec'` 都试过，全 400）。
带参数就把 `json` 换成 `{"parameter":[{"name":"SKIP_PLAY","value":"true"}]}`。

## 改 job 的标准动作
```bash
# 改 .jenkins/jobs/<JOB>.groovy 或 .jenkins/lib/**
.jenkins/lint.sh                       # 四道静态检查，必跑
.jenkins/apply-jobs.sh                 # 幂等同步（期望：完成 7，失败 0）
.jenkins/apply-jobs.sh --list          # 核对参数/触发器
# 然后**真跑一次只读的 TS-Pipeline-Overview** 核对四件可视化产物
```
> `pipeline-model-converter/validate` **只查 Groovy 语法，不查 DSL 结构/步骤名** —— 别把 lint 当验收。

## 可视化四件套（用户要求的「各环节可视化」）
① stage 图（嵌套 `stages` 分组，pipeline-graph-view）② JUnit 表格+趋势（warn/skip → `<skipped message="[WARN] …">`）
③ `currentBuild.description` 单行结论 ④ `evidence/**` 归档。
**球色**：有 warn 无 fail ⇒ `UNSTABLE`（黄球）——「没坏，但值得看一眼」，全绿/全红都表达不了。
**分级降级**：`run_stage.sh --warn-rc 3`；`android_env.sh` rc=3 = 「环境就绪但被 Unity 编辑器占用」（临时状态），
总览用 `--warn-rc 3` 标黄，打包 job 不加 ⇒ rc=3 当硬阻塞。

## 状态（2026-10-13 傍晚实跑核对）
- 7 个 job 定义与视图已核对：`lint.sh` 四道全绿（7/7 语法通过）、`apply-jobs.sh --dry-run` **7/0**。
- **已实跑拿到绿 / 黄球（无红球）**：
  - `TS-Pipeline-Overview` **#8 / #9 连两次 UNSTABLE**（7 通过 · 0 失败 · 1 关注），
    归档 21 条（5 文件 + 8 log + 8 stage json），构建历史 #1~#3 逐步修通、#4~#6 红、#7 假红、#8~#9 黄。
  - `TS-Client-Resources`(`ACTION=check`) #1 SUCCESS · `TS-Server-Health` #1 SUCCESS · `TS-Play-Watch` #2 SUCCESS。
  - 三者默认都不发信（`SEND_MAIL=false` / `DRY_RUN=true`），可安全试跑。
- 🔴 **闸门自检曾偶发假红**：Jenkins #7 判「发布闸门已被削弱」，而**同一份代码**本地连跑 17 次全绿。
  根因是判定用了 `printf '%s' "$out" | grep -q 拒绝` —— `set -o pipefail` 下 `grep -q` 命中即退、
  写端收 SIGPIPE(141)，「已命中」被读成「未命中」。已改 shell 内建 `[[ "$out" == *"$TAG"* ]]`，
  并把失败诊断由 `tail -3`（会把决定性首行裁掉）改为打印完整输出（commit `930965657`）。
  **教训：自检本身也是代码，也会出假红；假红比没有自检更糟 —— 它会训练人忽略红灯。**
- **未实跑**：`TS-Android-Release` / `TS-Android-TestPackage` / `TS-Server-Ops`（含破坏性动作，**需用户明确同意**）。
- 🔴 **cron 语义极易读错**：`H 9 * * *` / `H 10 * * *` 里 `H` 是**分钟**占位、`9` / `10` 是**小时**，
  ⇒ 含义是「**每天 9 点 / 10 点各一次**」，**不是每小时第 9/10 分**。这两个 job 建于当天 14:13，
  已过当日窗口 ⇒ **要等次日早晨才能确认调度真的会响**；此前只经 REST 手动触发验证过。
- 本机只有 **Unity Hub** 在跑、**无编辑器实例**占用工程 ⇒ 打包类 job 现在**可跑**
  （`android_env.sh` rc=3 那条黄球今天没出现；真开编辑器时会变黄球，属正常，非代码问题）。
- 唯一黄球：`本地 10002 区服状态` → 找不到 `~/ts-shard10002`（该环节计「关注」，不阻断流水线）。

## job 定义的两个落点 & `/Users/wangxufeng/.jenkins/jobs/` 的 git 问题（2026-10-13）

用户要求「**今后所有任务都用 Jenkins 跑、功能改动加到 Jenkins 上，改完 push git `/Users/wangxufeng/.jenkins/jobs/`**」。

**两个落点（改完两边都要入库）**：
1. 项目内 `TimeSpaceGirl1/.jenkins/jobs/*.groovy` ＝ 单一真源 → `lint.sh` → `apply-jobs.sh`（REST 推 `config.xml`，热生效）。
2. 本机 `/Users/wangxufeng/.jenkins/jobs/` **本身是 git 仓库**（分支 `main`）：
   - 每 job 一个目录，跟踪 `config.xml` + `nextBuildNumber`；`.gitignore` = `Daily_Open_iKuuu/builds` + `*/builds`。
   - **34940 个跟踪文件里 34910 个是 `*/builds/`（全是 System_Monitor 的构建日志，19MB 已入库，磁盘上 209MB）**
     ⇒ `.gitignore` 只挡未来提交、摘不出已入库的；仓库 `.git` 已 32MB。
   - 2 条提交：`20c65cb1 Initial commit`（2026-06-03）、`f9118b89 jobs`（**2026-10-13 18:33**，提交者
     `AI Assistant <992694856@qq.com>` —— 是**并发 AI 工具 QClaw 自动 commit 的**，不是我）。
   - 工作区当前干净。
- 🔴 **远端坏了**：`origin` = `https://<PAT>@github.com/a772616239/jobs1.git` → **GitHub 404，仓库不存在**
  （PAT 本身有效，`/user` 200 登录 `a772616239`；token scopes 含 `repo`/`delete_repo`，**足够建新仓**）。
  ⇒ 「改完 push」这条约定**目前兑现不了**。账号下只有个 2024 年的 `a772616239/JenkinJobs`
  （private、默认分支 `master`、last push 2024-05-12，内容是 android/ios 构建脚本，**与本仓库无关，别误指过去**）。
- 待用户定夺：① 建 private `jobs1` 再推（含是否先把 `*/builds` 从索引摘掉瘦身）；② 改指向别的仓；③ 先不动。
- ⚠️ 该目录有**并发 AI 工具在写**，动手前先 `git status` + `git reflog` 看有没有别人刚提交。

