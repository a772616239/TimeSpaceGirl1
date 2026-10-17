# TimeSpaceGirl1 运维文档索引

> 更新时间：2026-10-18
> 本项目（Unity 手游「时空美少女/时空战场」客户端 + 同仓 `TimeSpaceServer/`）的**运维与发版知识库**。
> 本目录面向"要动手做事"的场景；历史决策细节另见 `.workbuddy/memory/`。

---

## 我要做什么 → 看哪篇

| 我想…… | 看这篇 |
|---|---|
| **把全流程跑起来 / 各环节看结论（CI）** | **`jenkins_ci.md`** |
| 打包 / 发版 / 传 Google Play | **`android_release_runbook.md`** |
| 知道有哪些脚本、怎么调、退出码是什么 | **`scripts_reference.md`** |
| 改 Lua / 配置表 / 资源，改完不生效 | **`client_build_chain.md`** |
| 起服 / 开区服 / 改线上 / 每日巡检 | **`server_ops_runbook.md`** |
| **查某个玩家是不是开挂（判定）** | **`cheat_detection_skill.md`** |
| **玩家作弊 / 数据异常 / 封号处置（动作）** | **`gm_abuse_incident_playbook.md`** |
| Unity 构建侧深坑（Gradle / AGP / billing / AndroidX） | `unity_android_build_skill.md` |
| service account 申请与 Play 后台授权 | `google_play_upload_setup.md` |
| **密钥 / pem 放哪、换机怎么恢复** | **`secrets_setup.md`** |
| 原始服务端架设文档（厂商版） | `serverbuild.md` |
| 客户端功能设计（英雄对比 / 时间线 / 多语言公告） | `HeroCompare_FeatureDesign.md`、`HeroTimeline_FeatureDesign.md` |
| **多语言：公告 / 区服名** | `notice_multi_lang_guide.md`、`server_name_multi_lang_guide.md` |

---

## 全流程脚本地图

```
┌─ A. Android 发版链 ──────────────────────────────────────────────────────┐
│                                                                         │
│  ① 改客户端资源                                                          │
│      Lua  → LuaEncoder/luajit_mac/64/luajit -b   → LuaBytes/*_64.bytes   │
│      表   → DataConfigWindow（Unity 菜单 Data Config/Window）             │
│      资源 → FrameTool.BuildGameAssetBundles                              │
│             → CopyAssetBundleToStreamingAssets                           │
│                          ↓                                              │
│  ② 提版本号   scripts/bump_version.py                                    │
│                          ↓                                              │
│  ③ 一键出包   scripts/aab_release.sh        ← 默认只打包，不上传          │
│       ├─ 前置检查（Unity 占用 / Gradle 模板 / AB 就绪闸门）               │
│       ├─ scripts/check_ab_ready.sh              （只读 AB 体检）          │
│       ├─ scripts/verify_aab_release_config.py   （包内出包开关）          │
│       └─ scripts/verify_aab_native_16kb.py      （包内 native 16KB/NDK）  │
│                          ↓                                              │
│  ④ 上传（默认 internal 内部测试；正式版须显式抬旗）                       │
│       scripts/play_upload.py                                             │
│                          ↓                                              │
│  ⑤ 交付自检   scripts/verify_apk_delivery.py    （这包能不能拿去测）      │
│                                                                         │
│  旁路：scripts/play_16kb_watch.py  （16KB 巡检，🔴 勿与上传并发）         │
│        scripts/libtolua16k/build.sh（重编 libtolua.so）                  │
└─────────────────────────────────────────────────────────────────────────┘

┌─ B. 服务端 / 区服链 ────────────────────────────────────────────────────┐
│  ~/server-push.sh                      本机 → 生产服（scp 助手）          │
│  ~/ts-shard10002/*.sh                  本地 10002 区服（frp + launchd）   │
│     ├─ add-shard-10002.sh {hide|show}  区服登记 / 隐藏（幂等）            │
│     ├─ token-sync.sh                   同步 JL_LOGIN_TOKEN（端到端自测）  │
│     └─ setup-rootlink / clash-direct-fix / install-launchd …            │
│  ~/ts-chat-patch-20261010/deploy-chat-patch.sh   {verify|patch|restart|rollback} │
│  ~/ts-upstar-restore-20261010/deploy.sh          英雄升星氪金点恢复        │
│  远端 /home/java/gameserver/RESTART-GAMESERVER.sh  幂等重启（会踢线！）    │
│  巡检 scripts/server_health_check.py                                     │
└─────────────────────────────────────────────────────────────────────────┘

┌─ C. 服务端源码构建链（改 Java 时） ─────────────────────────────────────┐
│  TimeSpaceServer/Server_x1tag1.2.2/server_game/package.sh                │
│  proto/build.sh | build-pb.sh | build-lua.sh   （.proto → java/pb/lua）   │
└─────────────────────────────────────────────────────────────────────────┘
```

每个脚本的参数、退出码、内部步骤与产物 → **`scripts_reference.md`**。

---

## 全流程 CI（`.jenkins/` → 本机 Jenkins）

A/B/C 三条链已经收口成 **7 个 Jenkins job**，跑在 `http://127.0.0.1:8080/`
（视图「时空美少女 · 全流程」），并且每个环节的结论都以
**stage 图 / 测试结果表格+趋势图 / 构建描述 / 归档证据**四种形式呈现，不用翻控制台。

```bash
.jenkins/lint.sh              # 改完 .jenkins/** 必跑（四道静态检查）
.jenkins/apply-jobs.sh        # 同步 job 定义（单一真源在仓库，改 job 不用点界面）
.jenkins/apply-jobs.sh --list # 看每个 job 的参数与触发器
```

> 细节（job 拓扑 / 参数 / 送审三层闸门 / REST 触发姿势 / 本机踩过的 7 个坑 / 排障清单 / 验收清单）
> → **`jenkins_ci.md`**。**`.jenkins/run/` 是运行态产物，不入库。**

---

## 🔴 全场通用红线

这些在多个流程里反复出现，单独拎出来：

1. **绝不自行提交审核。** 打包、构建、校验可以；**「上传 production + `status=completed`」必须先获用户明确同意。**
   → 已用代码锁死（默认拒绝 + `--upload`/`--production`/`--publish` 三旗标显式放行）。
   → 且 2026-10-13 起**默认目标轨道是 `internal` 内部测试**，不是 production；只有显式 `--production` 才走得通。
2. **上传期间不要并发调用任何 Play API**（含巡检脚本、其它 agent）——
   多进程对同一 App 开 edit 会互删，实测导致 421MB 白传。
3. **重启生产游戏服会踢线，必须先取得用户确认。**
4. **巡检默认只读**：不重启服务、不改配置。报告要有量化证据，区分「🔴 严重 / ⚠️ 关注」。
5. **改了客户端 Lua 必须重编 `.bytes`**，两个文件成对提交（真机不读源码）。
6. **改了配置表源 xlsx 必须同步 `DataConfigMD5Record.asset` 的 CRC32**，并同步三处产物
   （客户端 lua + 字节码 + 服务端 TSV）。
7. **严禁 `git add -A`**，逐条 commit，中文 `type(scope): 摘要`。
8. **改动系统级状态**（`/home`、挂载点、`synthetic.conf`、launchd 域、`/etc/*`）前先备份、可回滚。

---

## 常见误判清单（别被牵着走）

| 看起来很严重 | 实际上 |
|---|---|
| Unity 打印 `libtolua.so is not 16KB-aligned` | **误报**。实测 `p_align = 0x4000` = 16384 正好达标，包内产物也一致，Play 从未点名 |
| 线上渠道值是 `None`、`isSDK=false` | **正常**。本作 Google 登录走账号密码分支；强行 `isSDK=true` 反而全挂 |
| CLI 打的包 versionCode 一直不变 | **设计如此**。`CLIBuilder` 只读不自增，用 `bump_version.py` 补 |
| `zip -u` 报 `Local Entry CRC does not match CD` | **无害**。原 jar 本就如此；按 CRC diff 条目数验证，别看体积 |
| 「上传到 production 就是送审」 | 对 `status=draft` **不成立**；`--changes-not-sent-for-review` 只对 internal/alpha/beta 有效 |
| internal 上传报 `400 Changes cannot be sent for review automatically` | 2026-10-17 起 Play **所有轨道**都要求 `changesNotSentForReview=true`；脚本已在 non-prod 轨道自动带（见 runbook §5.3） |
| `main_android/Unity` 在跑 batchmode | 与本工程无关，不再会误判为「占用」（已修 `b64b894dd`） |
| 新机器 clone 完 `.secrets/` 是**空的** | **正常**。凭据不入库，按 `secrets_setup.md` §3 恢复；脚本缺文件会自动走回退链 |

---

## 作弊排查速查

```bash
python3 scripts/cheat_scan.py --uid 10000017    # 单号裁决（只读，~30s）
python3 scripts/cheat_scan.py --hunt            # 全服扫可疑号（~90s）
python3 scripts/cheat_scan.py --ban-list        # 当前 FORBID_LOGIN 名单
```

判据 / 阈值 / 误判陷阱 / 四个真实样本的回归集 → **`cheat_detection_skill.md`**
确认作弊后的封禁与数据清理动作 → **`gm_abuse_incident_playbook.md`**

---

## 关键路径速查

```bash
PROJECT=/Users/wangxufeng/Documents/TimeSpaceGirl1
UNITY=/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity
PY=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python
ANDROID_SDK_BT=~/Library/Android/sdk/build-tools/36.0.0   # aapt2 / apksigner
KEYSTORE=$PROJECT/beauty.keystore                          # alias xing，DN O=EMI
PLAY_SA=$PROJECT/.secrets/service-account.json               # 工程本地优先（回退 ~/.gplay/…）
SSH_HOST=gs                                                # 129.226.213.65
SSH_KEY=$PROJECT/.secrets/tencent-gameserver.pem             # 工程本地优先（回退 ~/.ssh/config）
```
