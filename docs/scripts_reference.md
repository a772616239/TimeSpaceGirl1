# 全流程脚本速查（TimeSpaceGirl1）

> 更新时间：2026-10-18
> 面向：所有需要「出包 / 发版 / 起服 / 改客户端资源 / 查作弊」的动作。
> 一句话定位：**本文回答「有哪条链、链上有哪些脚本、每个脚本干什么、怎么调、失败看什么」。**
> 端到端操作步骤见 `android_release_runbook.md` 与 `server_ops_runbook.md`；
> 作弊判定方法论见 `cheat_detection_skill.md`。

---

## 0. 三条链路总览

```
┌─ A. Android 发版链 ─────────────────────────────────────────────────────┐
│                                                                        │
│  ①改客户端资源（Lua / 配置表 / AB）                                     │
│      LuaEncoder/luajit → LuaBytes/*.bytes     ← 见 client_build_chain.md │
│      DataConfigWindow（导表）                                          │
│      FrameTool.BuildGameAssetBundles → CopyAssetBundleToStreamingAssets │
│            ↓                                                           │
│  ②提版本号   scripts/bump_version.py                                    │
│            ↓                                                           │
│  ③打包+校验  scripts/aab_release.sh   ← 一键入口（默认不上传）           │
│       ├─ 前置检查（Unity 占用 / Gradle 模板 / AB 就绪闸门）              │
│       ├─ scripts/check_ab_ready.sh            （只读 AB 体检，可单独跑） │
│       ├─ scripts/verify_aab_release_config.py （包内出包开关）           │
│       └─ scripts/verify_aab_native_16kb.py    （包内 native 16KB/NDK）   │
│            ↓                                                           │
│  ④上传（默认 internal 内部测试；正式版须显式抬旗）                     │
│       scripts/play_upload.py                                            │
│            ↓                                                           │
│  ⑤交付/自测 scripts/verify_apk_delivery.py（APK·AAB 能不能拿去测）       │
│                                                                        │
│  旁路：scripts/play_16kb_watch.py（16KB 巡检 + 轨道现状，🔴 勿与上传并发）│
└────────────────────────────────────────────────────────────────────────┘

┌─ B. 服务端 / 区服链 ───────────────────────────────────────────────────┐
│  ~/server-push.sh           本机 → 生产服（scp 助手）                   │
│  ~/ts-shard10002/*.sh       本地 10002 区服（frp 穿透 + launchd 常驻）  │
│  ~/ts-chat-patch-20261010/  聊天 Redis 兜底热补丁                       │
│  ~/ts-upstar-restore-20261010/ 英雄升星氪金点恢复                       │
│  远端 /home/java/gameserver/RESTART-GAMESERVER.sh  幂等重启             │
│  巡检 scripts/server_health_check.py                                   │
└────────────────────────────────────────────────────────────────────────┘

┌─ C. 服务端源码构建链（改服务端 Java 时） ─────────────────────────────┐
│  TimeSpaceServer/Server_x1tag1.2.2/server_game/package.sh              │
│  proto/build.sh|build-pb.sh|build-lua.sh（.proto → java/pb/lua）        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Android 发版链（仓库 `scripts/`）

统一约定：

- Python 解释器固定用 `/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python`（已装 `google-api-python-client` / `google-auth`）。
- 产物目录 `apks/{yyyy-MM-dd}/CLIBuild/{HHmmss}.{aab|apk}`（`apks/` 已 gitignore）。
- **退出码约定**：`0` 成功；`1` 有阻断项/校验不过；`2` 参数或环境错误；`3` 认证失败；`4` API 业务错误；`5` versionCode 撞车。

### 1.1 `scripts/aab_release.sh` —— 一键发版入口

**职责**：提版本号 → Unity batchmode 打 AAB → 三道路包内校验 → （可选）上传 Play。

**默认行为：只打包 + 校验，不上传。要上传时默认目标是 `internal`（内部测试轨道）且
`status=completed` ⇒ 传完测试员几分钟内即可安装**（2026-10-13 起；`production` 正式版必须显式抬旗）。

```bash
scripts/aab_release.sh                                  # 出包 + 校验，不上传（默认）
scripts/aab_release.sh --dry-run                        # 打包 + 只认证列轨道现状（只读）
scripts/aab_release.sh --skip-build --aab <path>        # 复用已有 AAB
scripts/aab_release.sh --upload --yes                   # ★ 传 internal 内部测试（默认，立即可测）
scripts/aab_release.sh --upload --production --status draft --yes    # 传 production 草稿
scripts/aab_release.sh --upload --production --publish --yes         # 🔴 送审/上线（须先获批）
```

| 参数 | 说明 |
|---|---|
| `--upload` | 🔴 才会上传；不加则只在本地出包 |
| `--internal` | **默认**。传 internal 内部测试轨道（不面向公众、免常规审核、可随时 halt/替换） |
| `--production` | 🔴 才允许写 production 轨道（同时把 `--track` 置为 production） |
| `--publish` | 🔴 才允许**非 internal 轨道**用 `status=completed/inProgress`（= 提交审核 / 上线） |
| `--track` | `internal`(默认) / `alpha` / `beta` / `production` |
| `--status` | 不传则按轨道推导：`internal` ⇒ `completed`，其余 ⇒ `draft`；可显式 `completed` / `inProgress` / `halted` |
| `--user-fraction` | 灰度比例，仅 `inProgress` 有效 |
| `--notes` | 更新说明 |
| `--key` | 指定 service account JSON（默认 **`<工程>/.secrets/service-account.json`**，回退 `~/.gplay/service-account.json`；见 `secrets_setup.md`） |
| `--package` | 覆盖包名（默认 `com.Warera.timespace`） |
| `--aab <path>` | 直接指定 AAB，隐含 `--skip-build` |
| `--skip-build` | 跳过 Unity 打包 |
| `--no-bump` | ⚠️ 不动 versionCode（仅调试；Play **各轨道共享同一个 versionCode 空间**，重复号一律被拒） |
| `--no-upload` | 兼容保留（已等于默认行为） |
| `--allow-no-lua` | 强行跳过「未发现 Lua bundle」闸门（风险自负） |
| `--yes` / `-y` | 跳过交互确认 |
| `--dry-run` | 只读认证 + 列轨道，不受发布闸门限制 |

**步骤**（`step` 打印）：

| # | 步骤 | 失败会怎样 |
|---|---|---|
| 0 | 前置检查 | `fail` 直接中止 |
| — | 定位 AAB 产物 / 产物校验 | 结构不完整即中止 |
| 4.5 | 包内出包开关自检（期望 `minimal` = 只关 GM） | 中止 |
| 4.6 | 包内 native 库 16KB / NDK 体检 | 中止（Play 硬门槛） |
| 5 | 上传 Google Play | 按退出码给出原因 |

**前置检查明细**：Unity 可执行文件存在 → `CLIBuilder.cs` 存在 → **本工程无 Unity 占用**
（只认命令行含 `-projectpath ${PROJECT_ROOT}` 的进程，本机其它项目在跑不误伤）→ 三个 Gradle 模板
存在且含 AndroidX 降级 force、`launcherTemplate.gradle` 不含 `**DEPS**` → IAP 包版本 →
**AB 就绪闸门**（`Assets/StreamingAssets/Android` 下必须有文件名含 `luabytes` 的 bundle，
否则 `fail`；确需继续加 `--allow-no-lua`）→ bundle 与 `ResourcePathConfig.asset` 的新旧比对（仅 warn）。

**发布闸门自检**（`aab_release.sh` 内、`play_upload.py` 内各一份，互不传递旗标 = 双保险）：

```bash
# 下面三条都会被拒（这正是设计目标）
scripts/aab_release.sh --upload --track production                 # 没 --production → 拒
scripts/aab_release.sh --upload --production --status completed    # 没 --publish → 拒
scripts/aab_release.sh --upload --production --status inProgress   # 没 --publish → 拒
# 而这条放行：internal 内部测试不面向公众 ⇒ 免 --publish
scripts/aab_release.sh --upload                                    # → internal + completed
```

代码级守门人：`.jenkins/lib/checks/play_gate.sh`（文本断言 + 行为断言，CI 每次发版前必跑）。

### 1.2 `scripts/bump_version.py` —— 提版本号

**为什么存在**：GUI 打包（`BuildWindow.cs`）会 `bundleVersionCode++` 自增，而 CLI 的 `CLIBuilder.cs`
**只读不自增** ⇒ CLI 连打多个包号都一样，传 production 必被 Play 拒。

```bash
scripts/bump_version.py --show                # 看当前版本
scripts/bump_version.py --bump                # versionCode +1（最常用）
scripts/bump_version.py --bump --bump-name    # 同时把 versionName patch 位 +1（1.2.49 → 1.2.50）
scripts/bump_version.py --set-code 70         # 直接设值
```

改的是 `ProjectSettings/ProjectSettings.asset` 里的 `AndroidBundleVersionCode` / `bundleVersion`（纯文本 YAML，可 `git checkout` 回滚）。退出码 `0` / `2`。

### 1.3 `scripts/play_upload.py` —— Play Developer API v3 上传

```bash
python3 scripts/play_upload.py --aab <path> --dry-run                       # 只读：认证 + 列轨道
python3 scripts/play_upload.py --aab <path> --track internal --yes           # 传内测（默认轨道，status=completed）
python3 scripts/play_upload.py --aab <path> --track production --status draft \
        --allow-production-write --yes                                       # 传草稿（不送审）
python3 scripts/play_upload.py --aab <path> --track production --status completed \
        --allow-production-write --allow-publish --yes                       # 🔴 送审（须先获批）
python3 scripts/play_upload.py --reuse-version-code 69 --track internal --yes # 🔁 复用已上传号挂轨道（不传文件）
```

| 参数 | 说明 |
|---|---|
| `--aab` | AAB 路径（正常上传必填；用 `--reuse-version-code` 时可省） |
| `--reuse-version-code N` | 🔁 **不传任何文件**，把 app 已上传过的 N 写进目标轨道（Play 原生 track promotion）。与 `--aab` 互斥。因不产生新上传 ⇒ 不受「versionCode 必须递增」约束 |
| `--package` / `--track` / `--status` | 默认 `com.Warera.timespace` / **`internal`** / 按轨道推导（internal ⇒ `completed`，其余 ⇒ `draft`） |
| `--allow-production-write` | 🔴 放行 production 轨道写操作，不传一律拒绝 |
| `--allow-publish` | 🔴 放行非 internal 轨道的 `completed`/`inProgress`，不传一律拒绝（internal 豁免） |
| `--user-fraction` / `--release-notes` / `--service-account` / `--dry-run` / `--yes` | 同前 |

🔴 **versionCode 是 app 级全局的**：撞车判定取**全部轨道**的全局最大值（不是只看目标轨道），
否则会白跑整包上传、到 Play 才被拒。🔁 复用已上传号时改用 `bundles().list()` 查号池。

**已内置的健壮性修复**（勿回退）：上传超时 `300s`、分块 `8MB`、断点续传重试；
`tracks.update` / `edits.commit` 可重试 + commit 结果回查兜底。
需要时用环境变量调：`PLAY_UPLOAD_TIMEOUT_S` / `PLAY_UPLOAD_CHUNK_MB` / `PLAY_UPLOAD_MAX_RETRIES`。

> 背景坑：`google-auth-httplib2` 给 httplib2 设 60s 超时，而默认分块 100MB，
> 421MB 走代理单块要 4 分钟 ⇒ 必然 `TimeoutError`。

### 1.4 `scripts/check_ab_ready.sh` —— AssetBundle 就绪体检（**只读**）

回答「包内资源链路是不是断的」，重点看 Lua。四步：

1. **LuaBytes 源侧**：`Assets/ManagedResources/LuaBytes.meta` 的 `assetBundleName` 是否 `lzma/luabytes`；
2. **BuildABs 构建产物**：`BuildABs/Android/` 是否跑过；
3. **StreamingAssets**：`Assets/StreamingAssets/Android/`（AAB 包内资源的**唯一来源**）；
4. **最近一次 AAB**：它到底带没带 Lua。

退出码 `0` 全部就绪 / `1` 有阻塞项 / `2` 环境错误。

🔴 **Lua bundle 真实名字是 `lzma|luabytes.unity3d`** —— 不带 `lua` 前缀、也不在 `lua/` 目录。
`Assets/StreamingAssets/lua/` 是遗留空目录，别拿它当判据。判定只认**文件名含 `luabytes`**。

### 1.5 `scripts/verify_aab_release_config.py` —— 包内出包开关核验

离线解包读 `GameSettings.settingInfo` 的 12 个 int32 特征，判断有没有带 GM 面板。

```bash
scripts/verify_aab_release_config.py <aab|apk> --expect minimal
```

| 口径 | 值（12 个 int32 小端） | 含义 |
|---|---|---|
| `dev` | `[0,0,1,1,0,0,1,0,1,0,0,10001]` | 开发态，**GM 面板开启**（线上 v64 实测就是这个） |
| `minimal` | `[0,0,1,1,0,0,1,0,0,0,0,10001]` | **CLI 默认口径**：只把 `isOpenGM` 置 0 |
| `full` | `[0,0,1,1,1,0,0,1,0,0,0,10001]` | 完整正式包模板（`isGuide`/`isUpdate` 也开） |

退出码 `0` 通过 / `1` 不符合期望 / `2` 用法或结构错误。

### 1.6 `scripts/verify_aab_native_16kb.py` —— 包内 native 16KB / NDK 体检

```bash
scripts/verify_aab_native_16kb.py <aab|apk> [--strict]
```

- **FAIL**：任何 64 位 `.so` 的 `PT_LOAD p_align < 16384`（Play 硬门槛）。
- **WARN**：命中「`.note.android.ident` < r19」或「64 位库 `p_align == 0x10000`」（Play「旧版 NDK」软告警候选）。
- `--strict`：软告警也算失败。
- ⚠️ AAB 布局 `base/lib/<abi>/`、APK 布局 `lib/<abi>/` **都要能查**；若归档里有 `.so` 却一个都没匹配上，脚本 **rc=1 报错**，不当"合规"放过。

### 1.7 `scripts/verify_apk_delivery.py` —— 交付自检（"这包能不能拿去测"）

```bash
scripts/verify_apk_delivery.py apks/.../121249.apk --expect minimal
```

一次查完：① 版本号（APK 走 `aapt2`，AAB 读 `.release.json`）② 出包口径（委托 1.5）
③ native 16KB/NDK（委托 1.6）④ 🔴 **`libnative-googlesignin.so` 必须存在且有 64 位版本**
⑤ 签名（有 `apksigner` 时）。并写出 `<artifact>.delivery.json` 留证。

> 为什么加 ④：2026-10-12 为绕 Play 报障曾临时把该 `.so` 从包里摘掉，产出
> `090414.apk` / `093010.apk`。这两个包 **Google 登录必挂**，拿来验账号只会得到假结论。

退出码 `0` 可交付 / `1` 有阻断项 / `2` 用法错误。

### 1.8 `scripts/play_16kb_watch.py` —— 16KB 合规巡检 + 轨道现状

```bash
scripts/play_16kb_watch.py [--dry-run] [--aab <path>] [--no-mail]
```

三件事：查 Play 各轨道 versionCode/status → 对最新 AAB 做两层 16KB 取证 → 与上次 diff 后邮件汇报。
状态文件 `scripts/.play16kb_state.json`。退出码 `0` 正常 / `1` 门槛1 回归 / `2` 自身出错。

🔴 **会创建/删除一个 Play edit，绝对不能与 `play_upload.py` 上传并发运行** ——
实测「上传到 85% 时另一个进程开了 edit」⇒ 上传的 edit 被判 `This Edit has been deleted`
（HTTP 400 / FAILED_PRECONDITION），421MB 白传。

⚠️ Play Console 的 16KB 告警**没有公开 API**，另一半只能人工核对：
Console → 发布 → App Bundle 浏览器 → 选版本 → 「支持的页大小」。

### 1.9 `scripts/libtolua16k/` —— `libtolua.so` 16KB 重编译工具

```bash
export ANDROID_NDK_HOME=/path/to/android-ndk-r28
scripts/libtolua16k/build.sh              # 编译 + 4 项校验
scripts/libtolua16k/build.sh --install    # 校验通过后替换进工程（自动备份旧库）
scripts/libtolua16k/verify.py <libtolua.so>   # 只跑校验
```

4 项硬校验：① `PT_LOAD` 对齐 ≥ 16384 ② `.note.android.ident` ≥ r28 ③ 对 `ref/original-symbols.txt`
**零缺失导出符号** ④ `.so` 内 LuaJIT 版本串 == `LuaEncoder/luajit_mac/64/luajit -v`。
任一项不过即中止，**不会覆盖工程内库**。详见 `scripts/libtolua16k/README.md`。

🔴 **别用 `alex4814/tolua_runtime`**（LuaJIT 2.1.ROLLING，opcode 表与 beta3 有增删 ⇒ 真机启动即卡死）。
本工具固定在 `topameng/tolua_runtime`（LuaJIT 2.1.0-beta3）。

### 1.10 `scripts/server_health_check.py` —— 游戏服每日巡检

```bash
scripts/server_health_check.py [--dry-run] [--to a@b.com] [--json]
```

本机 SSH（`Host gs` 别名）采集 → QQ SMTP 发信（465 SSL，回退 587）→ 留档 `scripts/logs/`。
状态文件 `scripts/.server_health_state.json`（幂等标记）。
🔴 **默认只读**：不重启服务、不改服务器配置。报告要量化证据并区分「🔴 严重 / ⚠️ 关注」。

授权码优先级：**`<工程>/.secrets/health.env`**（工程本地）→ `~/.gs_health.env` → `/Volumes/S/TD/.env`（当前有效）
→ `~/TD-recovery/.env` → `~/TD-salvage-20260911/.env`（失效）；脚本逐个试登录自动跳过失效口令，
**缺失文件也会被安全跳过**。SSH 私钥同理：工程本地 `.secrets/tencent-gameserver.pem` 优先，
回退 `~/.ssh/config` 的 `Host gs`（见 `secrets_setup.md`）。

### 1.11 `scripts/cheat_scan.py` —— 作弊快速排查（**只读**）

```bash
scripts/cheat_scan.py --uid 10000017        # 单号裁决，~30s
scripts/cheat_scan.py --uid 10000017 --full # 追加 IP / 同伙 / 登录轨迹
scripts/cheat_scan.py --hunt                # 全服扫可疑号，~90s
scripts/cheat_scan.py --ban-list            # 当前 FORBID_LOGIN 名单
scripts/cheat_scan.py --uid <UID> --json    # 机器可读
```

退出码：`0` = 干净或可疑；`1` = **确证作弊**（可接告警/CI）；`2` = 参数错误。

三层判定（硬信号 → 软信号 → 参考信号），阈值集中在文件顶部 `TH = {...}`：

| 层 | 判据 | 阈值 |
|---|---|---|
| 硬 | `GM_REQUEST` 次数 | `> 12` |
| 硬 | `itemLog.reason=28`（`GM_REWARD`）单笔 | `≥ 100 万` |
| 硬 | 任意单笔发放 | `≥ 1 亿` |
| 硬 | 主线 `delta = fightLog最高 − (Name−1)` | `< -1`（跳关；`> +1` 是回档不算） |
| 软 | 金币 | `> 活跃号 P90 × 3` |
| 软 | 竞技场相邻战斗间隔 | `< 1s` |
| 软 | 竞技场场次 vs 挑战券（`reason=1022`） | 差 `> 券 × 50%` |
| 软 | 主线已通关范围内有缺口 | 任意 |

🔴 **只读**：不封号、不改数据。封禁动作走 `gm_abuse_incident_playbook.md` §3/§5。
判据来源、误判陷阱、四个真实样本的回归集 → **`cheat_detection_skill.md`**。

依赖：本机 `Host gs` 别名、远端 `mongo`/`redis-cli`、本地 `openpyxl`（读 `MainLevelConfig.xlsx`
做 `Id→Name` 换算；缺了会自动跳过该项并标注 `SKIP`）。
`--hunt` 的四项：GM_REWARD 持有者 / 单笔发放 TOP15 / 主线进度不一致 / 排行榜脏数据。

---

## 2. 服务端 / 区服链（本机 `~/ts-*` + 远端）

### 2.1 上传助手

| 脚本 | 用途 |
|---|---|
| `~/server-push.sh` | 一键 scp 文件/目录到 `gs`（129.226.213.65）。`./server-push.sh <本地路径> [远端目录,默认 /root/]` |

### 2.2 本地 10002 区服「庇护所九号」（`~/ts-shard10002/`）

| 脚本 | 用途 |
|---|---|
| `add-shard-10002.sh {hide\|show}` | 幂等：在登录库 `server_info` 登记/隐藏 10002 区服 |
| `setup-rootlink.sh` / `revert-rootlink.sh` | 建立/撤销 `/home` 到外置卷的符号链接（macOS 上 `/home` 是 synthetic.conf 保留路径） |
| `fix-home-synthetic.sh` | 修复 `synthetic.conf` 造成的 `/home` 异常 |
| `deploy-frps.sh` | 部署 frp 服务端（内网穿透） |
| `install-launchd.sh` / `install-launchd.command` | 把服务注册成 launchd 常驻（开机自起） |
| `clash-direct-fix.sh` | 修正 clash 代理直连规则（避免穿透流量被代理吃掉） |
| `token-sync.sh` | 同步登录令牌（`JL_LOGIN_TOKEN:<openId>`）以便端到端自测 |
| `shard.sh` / `shard-run.sh` / `detach.sh` / `recover.sh` / `all.sh` | 起停/脱离终端/恢复/一键全流程 |
| `logs/` | 运行日志 |
| `server_info_id2*.json` | 区服记录的备份（含 hidden-backup） |

细节见 `server_ops_runbook.md`。

### 2.3 热修补丁包

| 目录 | 脚本 | 用途 |
|---|---|---|
| `~/ts-chat-patch-20261010/` | `deploy-chat-patch.sh {verify\|patch\|restart\|rollback}` | 聊天消息 Redis 持久化兜底 |
| `~/ts-upstar-restore-20261010/` | `deploy.sh` + `restore_hrg.py` + `tools/` | 恢复英雄升星「氪金点」（`HeroRankupGroup` Id 31–53） |

### 2.4 远端生产服（`gs:/home/java/`）

| 路径 | 用途 |
|---|---|
| `/home/java/gameserver/RESTART-GAMESERVER.sh` | **幂等**重启游戏服（会踢线，须先获用户确认） |
| `/home/java/{gameserver,loginserver,chatserver,xxljob}` | 各服务目录 |
| `/data/srvlog/{gameserver,chatserver}.log` | 日志 |
| `gameSrv-1.0.0.jar` | 游戏服主程序（netty 16081，`-Xms1280m -Xmx1280m`） |

部署五步（**不可逆序**）：备份 → 停服（`pkill -f gameSrv-1.0.0.jar`，等 30s 确认 16081 释放）→ 上传 → 解压 → `RESTART-GAMESERVER.sh`。

### 2.5 服务端源码构建（改 Java 时）

| 路径 | 用途 |
|---|---|
| `TimeSpaceServer/Server_x1tag1.2.2/server_game/package.sh` | gradle 构建 → 重写 app jar → 组装 `dist/home/java/*` → tar.gz |
| `proto/build.sh` | `.proto` → **Java** 代码 |
| `proto/build-pb.sh` | `.proto` → **C**（descriptor_set，`pb_out/*.pb`） |
| `proto/build-lua.sh` | `.proto` → **Lua**（需要 `tools/protoc-gen-lua`） |

🔴 构建**必须 JDK8**（`/usr/local/Cellar/openjdk@8/1.8.0-482/...`），gradle wrapper 4.8 +
`GRADLE_USER_HOME=.gradle_home`；**别用根目录 `gradle build`**（worldserver 会挂）。
**生产配置改 `server_game/deploy-overlay/`，不要改 `src/main/resources/application*.properties`。**
**热补丁 ≫ 整包重打**：改线上优先 `jar uf` / `zip -u` 只替换改动 class。

---

## 3. 客户端资源与工具链（仓库内）

| 入口 | 位置 | 用途 |
|---|---|---|
| CLI 打包 | `Assets/Editor/CLIBuilder.cs` | `BuildAndroidAAB` / `BuildAndroidAPK` |
| 出包配置真源 | `Assets/Editor/ReleaseBuildSettings.cs` | 口径 `Dev / MinimalGmOff / FullTemplate` |
| GUI 打包 | `Assets/Scripts/Editor/GameEditor/FrameTool/BuildWindow.cs` | **versionCode 自增在这里** |
| AB 构建/拷贝 | `Assets/Scripts/Editor/GameEditor/FrameTool/FrameTool.cs` | `BuildGameAssetBundles` / `CopyAssetBundleToStreamingAssets` / `BuildLuaAssetBundles` |
| 导表 | `Assets/Scripts/Editor/ExcelTool/DataConfig/DataConfigWindow.cs` | xlsx → 客户端 lua |
| 字节码编码器 | `LuaEncoder/luajit_mac/64/luajit` | `~Lua/*.lua` → `*.bytes` |
| 自动签名 | `Assets/Scripts/Editor/AutoSignKeystore.cs` | 打包前注入 `beauty.keystore` |

---

## 4. 通用约定与坑（跨脚本）

- 🔴 **`set -o pipefail` 下 `cmd | head -1` 必须加 `|| true`**：head 早退关管道 → cmd 收 SIGPIPE(141) → 被当失败 → `set -e` 中止。
- 🔴 **shell 里含中文标点时变量必须写 `${VAR}` 花括号**：`set -u` 下 `"…$STATUS）"` 会因全角括号字节并入变量名而报 `unbound variable`，报错位置极迷惑。
- 本机 `find` 是 BSD 版：**不支持 `-newermt`**，用 `-mmin`。
- 本机 `ps` 在沙箱里 `operation not permitted`，用 `pgrep -fl` 代替。
- 上传期间**不要并发调任何 Play API**（含 `play_16kb_watch.py`）。
- 巡检默认**只读**；重启生产游戏服（会踢线）**必须先取得用户确认**。
- 发版/上线前**必须先给用户看过并取得明确同意**，绝不自行提交审核。
