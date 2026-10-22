# Google Play 后台上传管线 —— 申请、授权与发布

> 适用：TimeSpaceGirl1（`com.Warera.timespace`）
> 目标：把 Unity 打出的 `.aab` 通过 **Google Play Developer API** 自动上传到 Play 后台
> 建立时间：2026-10-11

---

## 0. 管线总览

```
scripts/aab_release.sh                 ← 一键入口
        │
        ├─ 1. 前置检查        Unity 未占用工程 / Gradle 模板完整 / IAP 版本
        ├─ 2. 提版本号        scripts/bump_version.py --bump
        │                     （CLI 打包不自增 versionCode，必须补）
        ├─ 3. Unity 打包      CLIBuilder.BuildAndroidAAB   ~10-15 min
        ├─ 4. 产物校验 + sidecar（记录 versionCode）
        └─ 5. 上传发布        scripts/play_upload.py
                                 ├─ 认证（service account JSON）
                                 ├─ edits.insert     开一个原子变更
                                 ├─ bundles.upload   传 AAB
                                 ├─ tracks.update    绑到目标轨道
                                 └─ edits.commit     提交（production 触发审核）
```

**为什么选 API 直连而不是 fastlane**：本机没有 Ruby 环境，fastlane 要额外装一整套；
Play Developer API 只要一个 service account JSON + 两个 Python 包，更适合这个仓库的现状。
后续如果想换 fastlane，`play_upload.py` 里的鉴权和轨道语义可以直接平移。

---

## 1. 一次性准备（只需做一次）

### 1.1 Google Cloud 侧：创建 service account

1. 打开 <https://console.cloud.google.com/>，选择或新建一个项目。
   （Cloud 项目不必与 Play 开发者账号同组织，只要你的 Google 账号能访问即可。）

2. **启用 API**：
   <https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com>
   点「启用」。这一步漏了的话，后面所有调用都会 401/403。

3. **创建服务账号**：
   「IAM 和管理」→「服务账号」→「创建服务账号」
   - 名称随便，例如 `play-publisher`
   - **不要授予任何 Cloud IAM 角色** —— Play 的权限在 Play Console 里单独发，Cloud 角色给了反而过宽

4. **创建密钥**：
   点进刚建的服务账号 →「密钥」→「添加密钥」→「创建新密钥」→ 选 **JSON** → 下载。

5. **记下服务账号邮箱**，形如：
   ```
   play-publisher@<your-project>.iam.gserviceaccount.com
   ```
   下一节要用。

### 1.2 Play Console 侧：把 service account 加为发布用户

> 这一步是**整个管线最容易卡住的地方**。Cloud 建完账号 ≠ 能发布，
> 必须在 Play Console 里显式授权，否则 API 一律返回 403。

1. 打开 <https://play.google.com/console>，进入 `com.Warera.timespace` 所属的开发者账号。

2. 左侧「**用户和权限**」→「**邀请新用户**」。

3. **电子邮件地址**填上面那个 `...iam.gserviceaccount.com` 邮箱。

4. **权限**按下表勾选：

   | 分类 | 需要勾选 | 为什么 |
   |---|---|---|
   | 应用（先选定 `com.Warera.timespace`） | —— | 只授权这一个应用，最小权限 |
   | 正式版 → 发布 | ✅ **发布到正式版、排除设备并使用 Google Play 应用签名** | 传 production 必需 |
   | 测试轨道 → 发布 | ✅ **管理测试轨道和修改测试人员列表** | 传 internal / alpha / beta 时需要 |
   | 应用信息 → 查看 | ✅ **查看应用信息并下载批量报告** | 脚本读取各轨道现状需要 |

   ⚠️ 如果只勾了「测试轨道」没勾「正式版」，传 production 会返回
   `The caller does not have permission`。

5. 点「邀请用户」。service account **不需要点确认邮件**（它没有收件箱），
   授权会自动生效。

6. **等待权限传播**：通常几分钟，极端情况几小时。
   刚授权完立刻跑可能还是 403，等一会儿重试。

### 1.3 本机：落地密钥

🔴 2026-10-13 起**首选工程本地 `.secrets/`** —— 随工程目录一起备份、换机不丢；
`~/.gplay/` 作为兼容回退仍然有效。布局与恢复步骤见 **`docs/secrets_setup.md`**。

```bash
# 首选：工程本地（.gitignore 已排除，永不入库）
mkdir -p .secrets && chmod 700 .secrets
mv ~/Downloads/<刚下载的>.json .secrets/service-account.json
chmod 600 .secrets/service-account.json
```

验证内容可读（以工程本地为例）：

```bash
python3 -c "import json;d=json.load(open('.secrets/service-account.json'));print('client_email:',d['client_email']);print('project_id  :',d['project_id'])"
```

脚本按以下优先级找密钥：

1. `--service-account /abs/path.json`
2. 环境变量 `GOOGLE_PLAY_SERVICE_ACCOUNT`
3. `<工程>/.secrets/service-account.json` ← **建议用这个**（工程本地）
4. `~/.gplay/service-account.json` ← 兼容回退

### 1.4 本项目的实际配置（2026-10-11 落地）

| 项 | 值 |
|---|---|
| Cloud project_id | `platinum-loop-468100-k5` |
| service account 邮箱 | `play-publisher@platinum-loop-468100-k5.iam.gserviceaccount.com` |
| 密钥落盘位置 | **`<工程>/.secrets/service-account.json`**（`600`，`.gitignore` 排除、**永不入库**）；`~/.gplay/service-account.json` 作为回退保留（2026-10-13 起由工程外迁入工程本地，见 `secrets_setup.md`） |
| 源密钥文件 | `~/Downloads/platinum-loop-468100-k5-29f09eaebc62.json`（**验证通过后应删除**） |

当前状态：**密钥有效、认证通过**，但 Play Console 侧尚未授权，接口返回
`HTTP 403 / PERMISSION_DENIED / The caller does not have permission`。
`PERMISSION_DENIED` 这个 status 说明 Google Play Android Developer API **已在
Cloud 项目启用**（否则会是 `accessNotConfigured`），⇒ 只差 §1.2 的授权动作。

---

## 2. 验证管线是否通

```bash
cd /Users/wangxufeng/Documents/TimeSpaceGirl1
scripts/aab_release.sh --skip-build --dry-run
```

`--skip-build` 复用 `apks/` 下最近的 AAB，`--dry-run` 只认证 + 列出各轨道现状、不上传。
**能看到类似下面这段就说明通路正常**：

```
[auth] service account: play-publisher@xxx.iam.gserviceaccount.com
[edit] editId = ...
[tracks] 当前轨道现状：
  - internal     (空)
  - production   completed v62
[dry-run] 未上传、未提交。删除 edit 后退出。
```

如果这一步就在 `edits.insert` 失败，问题几乎一定在 1.1 的启用 API 或 1.2 的 Play Console 授权。

---

## 3. 日常发布

```bash
# ★ 默认路径：只出包 + 校验，不上传
scripts/aab_release.sh

# 传内部测试（internal）—— 现在 --upload 的默认轨道，传完测试员几分钟内可装
scripts/aab_release.sh --skip-build --upload --yes

# 正式版草稿（不送审）—— 必须显式抬 --production
scripts/aab_release.sh --skip-build --upload --production --status draft --yes

# 🔴 正式版送审 / 上线 —— 须先获批，再抬 --publish
scripts/aab_release.sh --skip-build --upload --production --publish --yes

# 正式版分阶段放量 10%
scripts/aab_release.sh --upload --production --status inProgress --user-fraction 0.1 --publish

# 只打包不传（写出来只是显式；这已是默认行为）
scripts/aab_release.sh --no-upload

# 自定义更新说明
scripts/aab_release.sh --notes "修复卡顿；优化新手引导"
```

常用参数：

| 参数 | 说明 |
|---|---|
| `--track` | `internal`(**默认**) / `alpha` / `beta` / `production` |
| `--status` | 不传则按轨道推导：`internal` ⇒ `completed`（立即可测），其余 ⇒ `draft`。可显式 `completed`(全量) / `inProgress`(灰度) / `halted` |
| `--user-fraction` | 灰度比例，仅 `inProgress` 有效 |
| `--notes` | 更新说明（默认写「问题修复与体验优化。」） |
| `--no-bump` | 不动 versionCode（⚠️ 号重复必被 Play 拒 —— 各轨道共享同一个号空间） |
| `--skip-build` | 跳过 Unity 打包，复用最近 AAB |
| `--no-upload` | 只打包 + 校验（已等于默认） |
| `--dry-run` | 认证 + 列现状，不上传 |
| `--yes` / `-y` | 跳过交互确认（自动化用） |
| `--key` | 指定 service account JSON 路径 |

🔴 **三层闸门**：`--upload` 才会上传；写 `production` 还要 `--production`；
**非 internal 轨道**的 `completed`/`inProgress` 还要 `--publish`。
`internal` 轨道不受 `--publish` 限制 —— 它不面向公众、可随时 halt / 替换。

---

## 4. production 轨道特别注意

这几条是**别人踩过的坑**，务必确认：

1. **首次正式版必须手动发**
   如果应用在 production 轨道**从未有过任何发布**，Play 不允许通过 API 创建第一个正式版 release，
   必须先在 Play Console 网页上手动完成一次正式版发布。之后 API 才能接管。

2. **必须已启用 Play 应用签名（Play App Signing）**
   未启用时 AAB 上传会被拒。在 Console →「测试和发布」→「应用完整性」里确认。

3. **versionCode 必须严格递增（各轨道共享同一个号空间）**
   这就是本项目最需要小心的一条：`Assets/Editor/CLIBuilder.cs` **只读不自增** versionCode，
   自增逻辑只在 GUI 的 `Assets/Scripts/Editor/GameEditor/FrameTool/BuildWindow.cs:449`。
   → CLI 打包出来的包号会一直停在同一个值，直接传任何轨道都必被拒。
   🔴 **别以为「传 internal 就能省号」**：production / internal / alpha / beta
   **共享同一个 versionCode 空间**，一个号上传过一次就永久占用，换轨道重传同号同样被拒。
   `aab_release.sh` 默认帮你在打包前 `+1`（`scripts/bump_version.py`）。
   脚本还会在上传前查询轨道现有最大 versionCode 做比对，撞车会**在上传前就拦住并返回退出码 5**。

4. **「应用内容」问卷 / 数据安全表单必须已完成**
   否则正式版发布会被 Play 拦下。

5. **提交 ≠ 上线**
   `edits.commit` 只是把 release 提交给 Google 审核。审核通过后才会真正对用户生效。
   如果账号开了「托管式发布」(managed publishing)，commit 之后还要在 Console 手动点「开始发布」。

   🔴 **2026-10-23 实测：本账号就是托管式发布，API 根本无法「自动送审」**。
   `status=completed` 提交 production 时 Play 会返回
   `400 INVALID_ARGUMENT / Changes cannot be sent for review automatically. Please set the
   query parameter changesNotSentForReview to true.`
   ⇒ 现在 `play_upload.py` 对会送审的 status **一律先带 `changesNotSentForReview=true`**，
   commit 能成功，但 release 只是挂在 production 轨道上**待送审**，
   必须人工到 Console →「发布概览」点「送审」才进审核队列。
   ⚠️ 这个参数**只能在 commit 时带**，事后补不了：第一次传 vc83 时 442MB 全传完、
   轨道也写好了，才在 commit 被判 400、edit 被回滚，只能整包重传（4.5 min）。
   脚本现在加了兜底：真撞上这个 400 会**原地补参数重试 commit**，不重传。

6. **签名密钥**
   项目已有 `Assets/Scripts/Editor/AutoSignKeystore.cs`，在打包预处理阶段自动注入
   `beauty.keystore`（alias `xing`），无需手动配置。

---

## 5. 错误对照表

上传脚本会解析 Play 的响应体，输出形如
`HTTP 403 / PERMISSION_DENIED / reason=-` + `message: ...`，并直接给出诊断建议。
**两种 403 靠 `status` 区分**：

- `PERMISSION_DENIED` → API 已启用，缺的是 Play Console 授权（走 §1.2）
- `accessNotConfigured` / `has not been used in project` → API 未启用（走 §1.1 第 2 步）

| 现象 | 根因 | 解决 |
|---|---|---|
| `edits.insert` 就失败 / HTTP 401 | Cloud 侧未启用 **Google Play Android Developer API** | 回到 §1.1 第 2 步 |
| HTTP 403 `The caller does not have permission` | service account 邮箱没在 Play Console 授权，或权限勾漏了「正式版→发布」 | 回到 §1.2，确认邮箱逐字符一致 |
| HTTP 403 刚授权后立刻调 | 权限还在传播 | 等 10 分钟～数小时重试 |
| HTTP 400 `version code ... has already been used` | versionCode 重复 | 用 `--bump`（默认已开）提号后重新打包 |
| HTTP 400 `App bundle was not signed` / 上传被拒 | Play 应用签名未启用，或签名不对 | Console 启用 Play 应用签名；确认 `AutoSignKeystore.cs` 生效 |
| HTTP 400 `APK/bundle targets ... ` | targetSdk 不足 | 本项目 targetSdk 36，正常不会遇到 |
| HTTP 404 | 包名写错 | 应为 `com.Warera.timespace` |
| HTTP 400 `FAILED_PRECONDITION` / `This Edit has been deleted`（常在上传到 80%+ 时突然出现） | edit 会话被作废。未提交的 edit 有生命周期；**同一 App 的并发 edit 会互相作废** | 上传期间不要并发调用 Play API（如 16KB 巡检脚本 `play_16kb_watch.py` 会开新 edit）。直接重跑上传脚本即可 —— 🔴 **不要用 `aab_release.sh` 重跑**，它会再提一次 versionCode |
| HTTP 400 `Changes cannot be sent for review automatically. Please set ... changesNotSentForReview to true` | 账号开了托管式发布，API 无权自动送审；参数只能在 commit 时带 | 已在脚本里默认带上（见 §4-5）。若老版本脚本撞上：**别重跑整包**，直接补参数重试 commit（新脚本已自动做） |
| 脚本报「找不到 service account 密钥」 | 密钥没放到默认位 | 见 §1.3 |
| 脚本报「检测到 Unity 编辑器正在运行」 | GUI Unity 锁定工程 | `osascript -e 'tell application "Unity" to quit'` |
| 打包日志 `:launcher:mergeExtDexRelease FAILED` | AndroidX 与 AGP 7.4.2 dexer 不兼容 | 见 `docs/unity_android_build_skill.md` 第 3 节（双模板 force 降级） |

---

## 6. 安全约定

- JSON 密钥等同于该 service account 的全部权限，**绝不提交进 git**。
  首选放工程本地 `.secrets/service-account.json`（`.gitignore` 已排除整目录），权限 `600`；
  `~/.gplay/` 作回退同样设 `600`。⚠️ 本工程远端是 **PUBLIC 仓库**，
  `.gitignore` 只挡未来提交，**不能**把已入库的文件摘出来 —— 详见 `secrets_setup.md` §5/§6。
- 只授权需要的那一个应用，不要给「所有应用」的全局权限。
- 授权时不要勾「管理账户 / 财务」等无关高危权限。
- 密钥泄漏时：在 Google Cloud 删除该密钥 → 在 Play Console 移除该 service account 用户 → 重建。
- 需要轮换密钥时，新旧密钥可短暂共存，上传脚本通过 `--key` 切到新密钥验证无误后再删旧密钥。

---

## 7. 相关文件

| 文件 | 作用 |
|---|---|
| `scripts/aab_release.sh` | 一键：提号 → 打包 → 校验 → 上传 |
| `scripts/play_upload.py` | Play Developer API 上传 + 轨道发布 |
| `scripts/play_16kb_watch.py` | Play 16KB 合规巡检（轨道现状 + ELF 对齐 + 构建 NDK，邮件汇报）⚠️ 勿与上传并发 |
| `scripts/bump_version.py` | versionCode / versionName 提升 |
| `docs/unity_android_build_skill.md` | Unity 打包流程与全部坑位（打包侧真源） |
| `.workbuddy/skills/play-aab-release/SKILL.md` | 项目级 skill，供 agent 调用 |
