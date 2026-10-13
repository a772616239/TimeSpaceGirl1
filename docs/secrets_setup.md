# 工程本地凭据 `.secrets/` —— 布局、接线与换机恢复

> 一句话：**密钥 / pem / 授权码一律放工程根的 `.secrets/`，随工程目录一起备份，但永远不进 git。**
>
> 🔴 远端 `github.com/a772616239/TimeSpaceGirl1` 是 **PUBLIC 仓库** —— 入库即等于把密钥公开到公网，
> 而且 **push 之后无法真正撤回**（有 fork / 缓存 / 打包站），只能轮换密钥。

2026-10-13 起按用户要求（「密钥和 pem 都要保存到工程本地」）从工程外迁入。
此前只放 `~/.gplay/`、`~/.ssh/` 等工程外位置，**实测已经丢过**：本次核查发现
`~/.gs_health.env` 已不存在，巡检脚本只能在借读 TD 工程的 `/Volumes/S/TD/.env`。

---

## 1. 目录布局

```
<工程根>/.secrets/              # 目录权限 700，被 .gitignore 整目录排除
├── service-account.json        # 600  Google Play 发布用 service account 密钥
├── tencent-gameserver.pem      # 600  游戏服 SSH 私钥（129.226.213.65）
└── health.env                  # 600  巡检邮件 SMTP 授权码（可选，见 §4）
```

## 2. 谁在用它（解析优先级）

| 用途 | 脚本 | 优先 1 | 优先 2 | 优先 3（回退） |
|---|---|---|---|---|
| Play 上传 | `scripts/play_upload.py` | `--service-account` | `$GOOGLE_PLAY_SERVICE_ACCOUNT` | **`<工程>/.secrets/service-account.json`** → `~/.gplay/service-account.json` |
| 16KB 巡检 | `scripts/play_16kb_watch.py` | — | — | **`<工程>/.secrets/service-account.json`** → `~/.gplay/service-account.json` |
| 发版总入口 | `scripts/aab_release.sh` | `--key` | 同上（转交 `play_upload.py`） | 同上 |
| 服务器巡检 SSH | `scripts/server_health_check.py` | `$GS_SSH_KEY` | **`<工程>/.secrets/tencent-gameserver.pem`** | `~/.ssh/config` 的 `Host gs` → `~/.ssh/tencent-gameserver.pem` |
| 巡检邮件 | `scripts/server_health_check.py` | `$EMAIL_PASSWORD` | **`<工程>/.secrets/health.env`** | `~/.gs_health.env` → `/Volumes/S/TD/.env` → … |

**回退全部保留**：`.secrets/` 里缺哪个文件就自动退回原来那条链，行为与改动前一致。
（已实测：删掉 `health.env` 不抛异常；SSH 少了 pem 就不加 `-i`，身份仍由 `Host gs` 别名提供。）

## 3. 换机 / 重装恢复步骤

`.secrets/` 不在 git 里，新机器 clone 完是**空的** —— 这不是故障，按下面重建即可：

```bash
cd <工程根>
mkdir -p .secrets && chmod 700 .secrets

# ① Play service account
#    Google Cloud Console → IAM 和管理 → 服务账号 → 选 play-publisher@… → 密钥 → 新建 JSON 密钥
cp ~/Downloads/<刚下载的>.json .secrets/service-account.json

# ② 游戏服 SSH 私钥（从备份 / 密码管理器取回，或让运维重新下发）
cp <备份路径>/tencent-gameserver.pem .secrets/tencent-gameserver.pem

# ③ 巡检邮件授权码（QQ 邮箱 → 设置 → 账户 → 生成授权码，16 位）
printf 'EMAIL_PASSWORD=<16位授权码>\n' > .secrets/health.env

chmod 600 .secrets/*

# ---- 验证 ----
ssh-keygen -y -f .secrets/tencent-gameserver.pem >/dev/null && echo "✓ pem 可解析"
python3 -c "import json;json.load(open('.secrets/service-account.json'))" && echo "✓ json 合法"
ssh -i .secrets/tencent-gameserver.pem -o IdentitiesOnly=yes gs hostname && echo "✓ SSH 通"
```

验证脚本自身是否已指向工程本地：

```bash
PY=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python
$PY -c "import sys;sys.path.insert(0,'scripts');import play_upload as u;print(u.resolve_service_account(None))"
```

## 4. `health.env` 是可选项

不放就继续走原优先级链（当前实际是借读 `/Volumes/S/TD/.env`）。
⚠️ 但 `/Volumes/S/TD` 是**外挂卷**，拔掉 / 换机就没了 ⇒ 想彻底自包含就把它收进来。

## 5. 红线：绝不入库

`.gitignore` 已加：

```
.secrets/
*.pem
*.p12
*.key
service-account*.json
*credentials*.json
```

🔴 **`.gitignore` 只挡「未来」的提交，不会把已经入库的文件摘出来。**
仓库里 4 个签名 keystore（`user.keystore`、`beauty.keystore`、
`keystore/emiplay.keystore`、`userGP_for_total_war.keystore`）是 2025-07 就进公开库的
**历史遗留**，新的兜底规则同样挡不住它们 —— 需单独处置。

## 6. 已经泄漏了怎么办

1. 该 secret **立刻视为已泄露**：公开仓库的 git 历史删不掉（fork / 缓存 / 第三方镜像）。
2. **轮换优先于删文件**：
   - Play service account → Console 删旧密钥、重建 JSON；
   - SSH 私钥 → 服务器换 `authorized_keys`；
   - SMTP 授权码 → 重新生成；
   - Android 签名 keystore → 本项目走 AAB + Play App Signing，仓里这几个多半只是
     **上传密钥**，可在 Play Console → 应用完整性 → 申请重置上传密钥，**App 签名不变、用户无感**。
     （执行前先到「应用完整性」页确认当前是 Play 托管签名，别凭印象。）
3. 再用 `git filter-repo` 重写历史 + 强推，把公开面收敛掉。
4. 轮换后 **同步更新 `.secrets/` 与所有回退位置**，否则脚本会读到已作废的密钥而报认证失败。
