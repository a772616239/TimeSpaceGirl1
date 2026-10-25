# 资源站（:81）运维手册

> 更新时间：2026-10-25
> 关联：`docs/server_ops_runbook.md`（生产服总览）、`scripts/build_envs.json`（resUrl 唯一真源）、
> `docs/jenkins_ci.md`（出包链路）、`docs/unity_android_build_skill.md`（AB 重建）
> 一句话：**客户端热更/多语言文本都从 `http://129.226.213.65:81/` 取，这个站点是自己搭的，
> 服务器上任何一次 nginx 掉线/重装都会把它弄没。**

---

## 1. 客户端怎么拼 URL（决定目录结构）

`Assets/Scripts/Core/ResUpdate/Manager/ResourcesUpdateManager.cs:322`：

```csharp
downLoadURL = VersionManager.GetVersionInfo("resUrl")          // http://129.226.213.65:81/
            + VersionManager.GetVersionInfo("packageVersion")   // 1.26001
            + "/" + AppConst.PlatformPath + "/";                // Android/
// 于是实际请求：
//   http://129.226.213.65:81/1.26001/Android/version.txt
//   http://129.226.213.65:81/1.26001/Android/files.unity3d
//   http://129.226.213.65:81/1.26001/Android/lz4|xxx.unity3d
```

⇒ 站点根 = 一个含 `{packageVersion}/Android/` 的目录，本手册统一用 `/www/wwwroot/res`。
`packageVersion` 换了（换包）就要新建一个目录，**老目录不要删**——还在跑老包的玩家还要用。

## 2. 现状事实（2026-10-25 实测）

| 项 | 值 |
|---|---|
| 站点根 | `/www/wwwroot/res` |
| nginx | `/www/server/nginx/sbin/nginx`，vhost 在 `/www/server/panel/vhost/nginx/res81.conf` |
| 监听 | `*:81` |
| 日志 | `/www/wwwlogs/res81.log`、`/www/wwwlogs/res81.error.log` |
| 内容 | `/www/wwwroot/res/1.26001/Android/`（2753 个文件，约 436MB，来自 `Assets/StreamingAssets/Android/`） |
| 启动/重载 | `/www/server/nginx/sbin/nginx` / `nginx -s reload` |

🔴 **2026-10-25 之前这个站点根本不存在**：服务器上 nginx 进程没在跑、
`/www/server/panel/vhost/nginx/` 里没有任何站点配置、宝塔 `sites` 表查不到、磁盘上也没有本工程
的资源树。所以 `resUrl` 里的 `:81` 一直是个死地址（客户端表现为
`Cannot connect to destination host` → 后续 CDN/Lua 回调拿到 nil → 一串
`attempt to index local 'self'`）。

🔴 `/www/wwwroot/rg`（936MB）**不是我们的资源站**，是 2024 年模板包（戒灵/QuickGame）的残留：
`1/Android/lz4` 里只有 1 个文件，version.txt 指向早已下线的 `123.207.42.5`。别拿它当资源站，
也别删（留着当考古证据，不占事）。

## 3. 重建步骤（从零到可用）

### 3.1 确认 81 没被占用、nginx 能起

```bash
ssh gs 'ss -lntp | grep ":81 "'          # 应该没有输出
ssh gs '/www/server/nginx/sbin/nginx -t' # 必须 successful
```

### 3.2 写 vhost

`/www/server/panel/vhost/nginx/res81.conf`：

```nginx
server {
    listen 81;
    server_name _;
    root /www/wwwroot/res;
    index index.html;
    autoindex off;
    charset utf-8;

    location / {
        try_files $uri $uri/ =404;
    }

    add_header Access-Control-Allow-Origin *;

    location ~* \.(unity3d|bytes|txt|json)$ {
        expires 1h;
        add_header Cache-Control "public";
    }

    access_log /www/wwwlogs/res81.log;
    error_log  /www/wwwlogs/res81.error.log;
}
```

### 3.3 铺内容

```bash
ssh gs 'mkdir -p /www/wwwroot/res/1.26001/Android'
# 只传运行时要的，.meta 是 Unity 编辑器元数据，传上去纯浪费
rsync -a --partial --exclude='*.meta' \
      Assets/StreamingAssets/Android/ gs:/www/wwwroot/res/1.26001/Android/
# CDN 根必须有一份 version.txt（客户端第一个请求就是它）
scp Assets/StreamingAssets/Android/Resources/version.txt \
    gs:/www/wwwroot/res/1.26001/Android/version.txt
```

⚠️ AB 文件名里带竖线（`lz4|artfont_en|xxx.unity3d`），shell 里必须引号包住，
`rsync`/`scp` 传目录时没问题，但别写 `cp lz4|* ...`（`|` 会被当管道）。

### 3.4 起 nginx 并自检

```bash
ssh gs '/www/server/nginx/sbin/nginx'
ssh gs 'curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:81/1.26001/Android/version.txt'  # 期望 200
```

## 4. 🔴 坑位

### 4.1 安全组：本机能通 ≠ 外网能通

2026-10-25 实测：nginx 起好、`127.0.0.1:81` 200，但**外网仍然 000（7 秒超时）**。
根因是腾讯云安全组没放行 81（主机侧 `iptables -L INPUT` policy 是 ACCEPT，只有两条
按源 IP 的 DROP，没有端口规则）。

判定手法（不用登控制台）：

```bash
# hairpin：让服务器自己访问自己的公网 IP
ssh gs 'curl -s -m 6 -o /dev/null -w "%{http_code}\n" http://129.226.213.65:81/'   # 000 ⇒ 安全组拦的
ssh gs 'curl -s -m 6 -o /dev/null -w "%{http_code}\n" http://129.226.213.65:8080/'  # 200 ⇒ hairpin 本身是通的
```

两条一对比就能定位：hairpin 能通说明回环 NAT 没问题，81 通不了就是**安全组按端口拦**。
放行要在腾讯云控制台做：**安全组 → 入站规则 → 添加 TCP:81，来源 0.0.0.0/0**。

⚠️ 沙箱里 `socket.connect()` 会被透明代理劫持（连死 IP 也 0ms 返回成功），
**判端口死活只能用 curl，或从服务器侧 ssh 过去测**。

### 4.2 443 不是网站，是 xray

`129.226.213.65:443` 是 xray VPN 在监听，证书 `CN=www.cloudflare.com`
（Google Trust Services 签发）。任何 `https://129.226.213.65/...` 必然
`Curl error 60: Cert verify failed: UNITYTLS_X509VERIFY_FLAG_USER_ERROR1`。
**资源站只用 http，不要改成 https。**

### 4.3 `isUpdate=0` 时这套东西根本不跑

`Assets/LuaFramework/Scenes/Logo.unity` 的 `GameSettings.settingInfo.isUpdate = 0`
⇒ `ResourcesUpdateManager.GetGameVersion()` 第一件事就是 `UpdateSuccess()` 直接返回，
不发任何请求。所以「:81 挂了」对当前出包**不影响启动**，只影响：
- 开了热更的包（`isUpdate=1`）
- 依赖 CDN 拉多语言文本/公告的客户端（那类客户端不走 `isUpdate` 开关）

### 4.4 `packageVersion` 对不上会直接判「需要换包」

`ResourcesUpdateManager.GetGameVersion()` 里
`VersionManager.CheckPackageVersionSame(table["packageVersion"])` 为 false 就走
`OldPackageNeedChange` → 弹「与最新版本差异过大，请下载最新安装包」。
⇒ 站点只服务 `1.26001` 这一档；换包时**新建目录、别覆盖**，否则老包玩家全部被踢去更新。

## 5. 验收清单

```bash
# 1) 外网能取到版本文件（应回一段 JSON）
curl -s http://129.226.213.65:81/1.26001/Android/version.txt

# 2) 清单能下（应回 200 + 78KB 左右）
curl -s -o /dev/null -w "%{http_code} %{size_download}\n" \
     http://129.226.213.65:81/1.26001/Android/files.unity3d

# 3) 抽一个 AB（竖线要引号）
curl -s -o /dev/null -w "%{http_code} %{size_download}\n" \
     'http://129.226.213.65:81/1.26001/Android/lz4|artfont_en|adjutantpanelatlas.unity3d'

# 4) 文件数与体积对得上本地
ssh gs 'find /www/wwwroot/res/1.26001/Android -type f | wc -l; du -sh /www/wwwroot/res/1.26001/Android'
```

## 6. 出问题先看哪

| 症状 | 先看 |
|---|---|
| 外网 000、本机 200 | 安全组（4.1） |
| 本机也 000 | `pgrep -a nginx` / `ss -lntp \| grep :81` / `nginx -t` |
| 403 | `autoindex off` + 请求的是目录；或 `try_files` 没命中 |
| 404 | 路径里的 `packageVersion` 与磁盘目录不一致 |
| 客户端 cert verify failed | 有人把 resUrl 改成 https 了（4.2） |
| 客户端「需要换包」 | 站点 version.txt 的 packageVersion 与客户端不一致（4.4） |
