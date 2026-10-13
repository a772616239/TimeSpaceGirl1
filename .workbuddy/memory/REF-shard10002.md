# REF：本地新区服 10002「庇护所九号」（内网穿透，2026-10-10 上线）

主入口记忆见 `MEMORY.md`。本文件是该新服的全部运维细节。

## 目录与组件
`~/ts-shard10002/`（**在 git 仓库之外**，勿放进工程）。统一入口 **`./all.sh {start|stop|restart|status|check}`**。

| 脚本 | 作用 |
|---|---|
| `shard.sh` / `shard-run.sh` | 本地游戏服（`gameSrv-1.0.0.jar`，netty 16081） |
| `detach.sh` | 脱离会话启动器（`Popen(start_new_session=True)`） |
| `frp/run-frpc.sh` | 隧道 frpc（本地 16181 → 127.0.0.1:16081） |
| `deploy-frps.sh` | 云服 frps 部署/状态 |
| `token-sync.sh` | `JL_TOKEN:*` 增量镜像（生产 Redis → 本地 6479） |
| `add-shard-10002.sh {backup\|apply\|verify\|rollback}` | 区服登记到登录库 |
| `setup-rootlink.sh` / `revert-rootlink.sh` | `/home/java` 软链建立/还原 |
| `recover.sh` | 幂等一键恢复（Redis→游戏服→frpc→token 镜像，含「进程活但 proxy 未注册」假活检测） |
| `install-launchd.sh {install\|uninstall\|status}` | 四件套交给 launchd 托管 |
| `install-launchd.command` | 双击入口（Finder 启动的终端必然在图形会话内） |

## 本机环境
- MongoDB **4.0.28** @ 127.0.0.1:27017（无认证）。须用 `/usr/local/opt/mongodb-community@4.4/bin/mongo`；官方 mongosh 2.6 要求 wire≥8，连不上。
- 独立 Redis 8.4 @ **6479**（与其它实例完全隔离）。
- JDK8：`/usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home`。
- frp **v0.71.0**：云服 `ts-frps.service`（systemd，enabled）监听 **7700**（控制）+ **16181**（新服公网）。
- 云服安全组 **7700 / 16181 均已放行**（check-host 三地实测）。
- 数据隔离：新服库 `m5_x1_game_10002`（自动建）+ Redis 6479 独立 ⇒ 与生产零交集。
- 登录库账号：`a772616239 / Wang177752 --authenticationDatabase admin`。
- 端口冲突备忘：本地 **7000 被 macOS AirPlay 的 ControlCenter 占**、**8080 被 jenkins 占**。

## 启动踩坑（按重要性）
- 🔴 **lib 硬编码 `/home/java/gameserver/`**：真凶 = `lib/fightmanager.jar` 的 `com/ljsd/fight/CheckFight.class` + `lib/gamecommon-1.0.0-SNAPSHOT.jar` 的 `util.SysUtil.getRootPath()`。缺此路径 → 全部配置表加载失败 → `NullPointerException: clazz.nullconfig.SXxxConfig` → 主线程崩溃。**别搞混**：gameSrv jar 内的 `com.ljsd.jieling.util.SysUtil.getRootPath()` 非 Windows 下返回 `"../"`，不是它。
- 🔴 **macOS `/home` 是「合成实体(synthetic)」，重启后不会自动出现** —— **2026-10-12 更正：旧结论「注释 auto_master 后建链、重启仍有效」是错的**。事实：macOS 默认 `/etc/auto_master` 里 `/home auto_home` **本来就是注释状态**，`/home` **默认根本不存在**；它只有被 `/etc/synthetic.conf` 声明后才会由 apfs 生成 → 重启后没有它，`/System/Volumes/Data/home/java` 就成**孤儿软链**。
  - **真实症状**（2026-10-12 首次踩到）：Mac 重启 → `/home` 消失 → 游戏服启动 `file not find /home/java/gameserver/conf/server/*.txt`（68 行）→ `Exception in thread "main" … NullPointerException at config.SBloodyBattleSetting.init` → **主线程崩、进程退出**；launchd `KeepAlive` 每 30s 拉起又崩，**日志里只有一串 START 横幅、极易误判为"在跑"**（`launchctl print` 仍显示 running，但 `:16081` 无监听）。表现层 = 玩家登录不上、或进不去老角色。
  - ✅ **正解（持久）**：`/etc/synthetic.conf` 写一行 **`home<TAB>/System/Volumes/Data/home`**（**必须真 tab**）→ `sudo /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t` → **立即生成 `/home`，无需重启**，且下次开机自动生成。
  - 落地：`~/ts-shard10002/fix-home-synthetic.sh`（幂等，可反复跑、是日常修复入口）；`setup-rootlink.sh` 已补 4b 步并订正注释。
  - **排查口诀**：`ls /home` 报 `No such file` = 就是它；`ls /home/java/gameserver/conf/server | wc -l` 应 = **406**。
  - 另一坑：`ln -s … /home/java` 在 `/home` 是 autofs 挂载点时确实报 `Operation not supported`（root 也一样）——但**别再把"注释 auto_master"当成解法**，真正缺的是 `synthetic.conf`。
- 🔴 **macOS 上 `nohup cmd &` 会被父会话进程组清理杀掉**（现象＝进程静默消失、日志无错，极易误判为崩溃）→ 必须用 `detach.sh`。
- 🔴 **配置加载层级**：生效的是 `file:./config/application.properties`（最高优先级）> jar **根目录**内置 `application.properties`（含 server.id / netty.tcpPort / redis / mongo 全默认值）⇒ **定义新服只需写这一个文件**，无需重编译。线上 `config/logicSrv.properties` 内容相同但**不被加载＝死文件**（本地已改名 `.disabled-10001`）。
- 🔴 **core 库必须指向【不存在】的空库**（`spring.data.mongodbcore.uri`）：指向真带 `server_info` 的库会让 `MongoUtil.init()` 遍历 NPE 崩溃。生产 `m5_x1_login`，本地 `m5_x1_login_10002`。（`the user=N not exists` 是常态噪音，生产出现 1139 次，非故障。）
- ⚠️ 本机 `sudo` 在执行环境里被**完全屏蔽**（`dangerouslyDisableSandbox` 也拦，报 `operation not permitted: sudo`）；提权只能用 `osascript -e 'do shell script "…" user name "…" password "…" with administrator privileges'`（实测可用；密码由用户口头提供，不落盘）。

## 鉴权链（二次反汇编修正）
客户端 → 登录服 `tk/userLogin`（写 `JL_LOGIN_TOKEN:<openId>`，仅登录服自用）→ `tk/getUserInfo`（分配**全局递增 uid** `inc("uid")+10000000`；`utoken=Math.abs(random.nextInt())` **写入【生产 Redis】`JL_TOKEN:<uid>`**）→ 返回 `{uid,token}` → 客户端连 `server_info` 的 `ip:port` → `SessionManager.onLoginORReLoginRequest`（**11100 登录 / 11700 重连都走**）→ `AuthManager.auVertiyFromRedis` 读**本服 Redis** `JL_TOKEN:<uid>`，与包内 token **必须严格相等**。

- 🔴 **游戏服确实校验 token**（推翻早前"零依赖"结论）：`LoginRequestHandler` 不看 token，但 `AuthManager` 看。
- ⚠️ 上游 bug：`tokenK==null` 时 `tokenK.isEmpty()` 抛 **NPE**（`AuthManager.java:32`）→ 连接直接关闭（`player offLine`）。
- `LoginManager.ServerId` 只出现在注释掉的埋点里，不发给游戏服。

## 🔴 `JL_TOKEN` 镜像（登录能进的关键）—— v2 推送式，2026-10-10 重做
`token-sync.sh` + LaunchAgent `com.tsg.shard10002.tokensync`。

**结构**：建链时全量 dump 一次 → 之后靠**生产 Redis keyspace 通知**推送（`PSUBSCRIBE __keyspace@0__:JL_TOKEN:*`，单条常驻连接，无轮询）→ 云服侧收到写事件立刻 `GET` 并把 `key\tvalue` 打到 stdout → 本地用**单条常驻 `redis-cli`**（喂 stdin，含 `DEL` 处理）落地到 6479 → 每 120s 全量 dump 兜底 + 自愈通知配置 → 断线自动重连。

### 🔴 生产 Redis 需要 `notify-keyspace-events = K$g`（缺一不可）
- `K` = keyspace 通道 `__keyspace@<db>:<key>`；`$` = **string 类事件（`SET`！）**；`g` = generic 类（`DEL`/`EXPIRE`）。
- ⚠️ **只设 `Kg` 收不到 `SET`**（`SET` 属 `$` 类不属 `g` 类），实测只收到 `del` —— 踩过。
- 这是**运行时**配置：不改 `redis.conf`、不重启、对没有订阅者的实例零影响；但 **Redis 重启会回落默认值** ⇒ 脚本每次建链 + 每 120s 幂等重设。
- 注意 `CONFIG GET` 返回字符串可能乱序（实测 `g$K`），判存在要按字符包含，别按顺序。

### v1（0.25s 全量轮询）为什么必须废弃 —— 两个致命缺陷（实测）
1. **延迟 3~4s**：每轮全量 225 个 key 都 fork 一个 `redis-cli`，本地读取管道被 225 次进程启动塞满，后续增量排在队尾。登录必然失败（`AuthManager` 读到上一轮的旧值 → `token=` 与 `serverToken=` 不等 → errCode **30014**「您的账号token不正确」）。
2. **反噬生产**：`INFO commandstats` 实测 6s 内 `get=5400 / eval=24` ⇒ **约 908 ops/s**，而生产 Redis **全部**流量也就 908 ops/s —— **镜像一个人把生产 Redis 打满了**。（改成 v2 后同一测法：**0.1 ops/s**。）

**v2 实测**：`token-sync.sh selftest`（写假 key 到生产 → 等本地可见）**291 ms**；225/225 键值逐字节一致。

**为什么不采用其它方案**
- `MONITOR`：零生产配置改动，但生产 900 ops/s 时要把每一条命令都推出来（实测 6s 4997 行）；虽然可服务端 grep 过滤，但开销按**总命令数**算，不如 keyspace 通知按**写命令数**算（实测写=0）。且自家 `GET` 会被 grep 命中形成自激回环（必须靠"只匹配写命令"规避）。
- 本地 Redis `REPLICAOF` 生产：需 SSH 隧道 + fork 全量 42MB；resync 会 `FLUSHALL` 本地 key；且会把生产 `JL_USER_SERVER_INFO` 等**不属于本服**的键一起灌进来，破坏隔离。
- 把本服 Redis 指到云上：每个 Redis 操作都要过一次 WAN（RTT ~500ms），游戏服不可用。
- 「预投递」根本不可能被做成保证：token 由登录服在 `tk/getUserInfo` 里生成，与客户端连游戏服只差约 0.2~0.4s，而任何远程同步都要过一次 WAN 单程。**能赢是因为客户端登录包要跨 WAN 两次**（客户端→云服:16181 → frp 反向隧道 → 本地:16081），而镜像只跨一次 —— 这是结构性的约 0.3~0.5s 余量，不是运气。

**只镜像 `JL_TOKEN:*`，不复制生产其它数据** → 新服 Redis 保持独立。`JL_USER_SERVER_INFO`/`JL_MAP_RANK` 由新服自己读写；`PIDGIDTEMP` 只在 `RedisKey`/`RedisUtil` 里作常量出现，游戏服实际不读（已全 jar 扫描确认）。

**链路自身健康度别忘**：v1 的 `已落地 N 条` 是每 200 条打一次，看着"一直有输出"其实可能全是全量重发；**判活要看 v2 日志有没有 `建立推送通道…` 之后紧跟断线，以及 `selftest` 的实际毫秒数**。

## 通道卫生（两次真实事故）
- 🔴 **frpc 绝不能继承 sandbox 代理环境变量**（2026-10-10 23:05 事故真因）：本机 shell 有 `HTTP(S)_PROXY=http://127.0.0.1:5xxxx`（透明代理，**端口随会话轮换**），frpc 会把它当成 frps 的代理地址，端口一换就无限重连一个死端口 → `dial tcp 127.0.0.1:50470: connection refused` → **隧道静默中断（进程还活着、日志在刷、服务已死）**。⇒ 启动必须 `env -u` 剥掉 `HTTP_PROXY/HTTPS_PROXY/ALL_PROXY/http_proxy/https_proxy/all_proxy`（已写进 `run-frpc.sh`；`token-sync.sh` 同样 unset；plist 里再显式置空双保险）。
- 🔴 **判活必须看注册状态，不能只看进程**：`grep "start proxy success" frpc.log`。

## 🔴 launchd 托管（2026-10-10 定案）
四件套 `~/Library/LaunchAgents/com.tsg.shard10002.{redis,shard,frpc,tokensync}.plist`，均 `RunAtLoad + KeepAlive + 显式置空代理`，已全部 `state=running`。

- 🔴 **`launchctl bootstrap` 只接受【在图形登录会话(Aqua)内的】进程**，否则一律 `Bootstrap failed: 5: Input/output error`。**这报错 ≠ plist 坏 / ≠ 权限错 / ≠ gui 域坏**——同机 `gui/501` 里 crash-restart、feed-bloggers、trump-flash 等一票服务全是好的；最小探针 plist（`/usr/bin/true`）同样 EIO。从 SSH / 后台会话 / 编辑器内置终端调用**必然失败**（本机这类进程 session 号 19408，非 Aqua）。
- 已逐一排除的无效绕法：`launchctl load -w -S Aqua`、`osascript do shell script`、`user/501` 域（EIO）、`login/501` 域（125 Domain does not support specified action）。
- **唯一有效绕法**：`osascript … with administrator privileges` → `launchctl asuser 501 launchctl bootstrap gui/501 <plist>`（以 root 身份进入 uid 的会话上下文，**本机实测可用**）。
- 因此 `install-launchd.sh` 内置**三级降级**：① 直接 bootstrap（用户在 Terminal.app 里跑）→ ② 自动走 root+asuser（口令取 `TSG_ADMIN_PW` → `$SHARD/.adminpw` → 交互隐藏输入）→ ③ 都不行则提示双击 `install-launchd.command`。**会话探测在停服【之前】进行**，探测失败原样退出、不碰四件套。
- ⚠️ 写 bash 注意：`$VAR` 紧跟全角字符（如 `$BOOT_MODE）`）在 `set -u` 下会把全角括号吞进变量名 → 报 `unbound variable`。一律写 `${VAR}`。

## 自启链：登出 / 重启后谁能自己回来（2026-10-11 核验）

**分两层，边界是「是否需要 GUI 登录」：**

| 层 | 谁 | 何时起 | 需登录桌面? |
|---|---|---|---|
| 系统 LaunchDaemon | `mongod` :27017 | **boot 后即起**（实测 boot 12:10:32 → PID 229 @12:10:34） | ❌ 不需要 |
| 用户 LaunchAgent | `com.tsg.shard10002.{redis,shard,frpc,tokensync}` | **GUI 登录时加载** | ✅ 必须 |

- mongod 归 **`/Library/LaunchDaemons/org.mongodb.mongod.plist`**（`RunAtLoad+KeepAlive`，`UserName=wangxufeng`，`/usr/local/mongodb/bin/mongod --dbpath ~/mongodb-data/db`）。**注意它跟 Homebrew 的 mongodb 服务毫无关系**，那三个 homebrew plist 是干扰项。
- 四个 LaunchAgent 已核验：`RunAtLoad=1 / KeepAlive=1 / Disabled 未设 / 无 session 限制 / print-disabled 无覆盖 / EnvironmentVariables 已显式置空 proxy + PATH 含 /usr/local/bin`。⇒ **登录即自动拉起，无需人工干预**。
- 依赖项全部落在磁盘上（登出不影响）：`/home/java` → `~/ts-shard10002/home/java` 软链、`/etc/auto_master` 中 `#/home auto_home` 仍注释、`~/.ssh/tencent-gameserver.pem`、各二进制均在位。
- ⚠️ **必须真正登录进桌面会话**。只重启停在登录窗口 / 纯 SSH / FileVault 解锁页 → 只有 mongod 会起，**游戏服务全都不起**。
- ⚠️ **别用 `all.sh stop` 停服务**：`KeepAlive` 会立刻拉回。停必须 `launchctl bootout gui/501/<label>` 或 `install-launchd.sh uninstall`。
- 自愈实测（00:10–00:11 一次真实网络抖动）：frpc 00:10:53 自动 `login to server success` + `start proxy success`；token-sync 00:11:36 断线、00:11:38 重连（2s）。**网络未就绪导致的首次失败会自动恢复**（frpc/redis/tokensync throttle 10s，shard 30s）。
- 遗留噪音（无害，可清理）：① `homebrew.mxcl.mongodb-community.plist` 已加载但 `last exit code=48`（27017 被 mongod 占）；② `homebrew.mxcl.mongodb-community@4.4` 是**僵尸注册**——plist 文件已被移到 `~/Library/LaunchAgents/_backup/`，label 仍 loaded（exit 48）。

## 延迟画像与「测量纪律」（2026-10-11 实测）

| 指标 | 改道前（走机场） | **改道后（DIRECT，当前）** |
|---|---|---|
| 到云服 **RTT**（常驻通道打点） | 239–804ms，中位 **299ms** | **76–88ms，中位 85ms**（偶发 362/1087 尖峰） |
| 理论**单向** | ≈150ms | **≈43ms** |
| 镜像端到端（生产写 → 本地可见） | 251–315ms，中位 264ms | 272–288ms（**几乎没变，见下**） |
| **玩家视角 RTT** | 欧洲 199+299≈**500ms** | 欧洲 199+85≈**284ms** |

- 🔴 **玩家 RTT 的正确公式 = RTT(玩家→云) + RTT(云→家)**（请求一趟 + 隧道一趟，各含往返）。不是「节点延迟 + 单向」。
- 🔴 **镜像延迟与网络无关**：拆解后 `selftest` 的 ~280ms 主要是**两端 bash 各起一次 `redis-cli` 进程**（远端 keyspace 循环里 `GET` 一次、本地喂 stdin 一次、selftest 轮询每 5ms 再起一次）。所以网络单向从 150ms 降到 43ms，镜像读数几乎不动 —— **镜像从来不是网络瓶颈**，277ms ≪ 0.8s 窗口，无需再优化。

- 🔴 **本机探针一律不可信**：本机有透明代理（系统 `127.0.0.1:7890` + 沙箱 `127.0.0.1:58555` + `utun0`–`utun4`）。`curl %{time_connect}` 连 `1.1.1.1` 都只有 **1.3ms**、连新加坡云服 1.5ms ⇒ 所有 `time_connect` / `ping` 数字作废（`traceroute` 被拦：operation not permitted）。
- ✅ **唯一可信测法**：`ssh -M -o ControlPath=… -fNT gs` 建常驻主连接 → 远端跑 `cat` → python 逐行打点（无远程 fork、无连接建立开销）。镜像延迟用 `bash token-sync.sh selftest`。
- ⚠️ 本机 load average 长期 **12–14** ⇒ 一切「进程启动类」测量严重虚高（`ssh gs true` ≈ 1.6s 却在 0.5s 级别属于正常），**不能当网络延迟**。
- ✅ 镜像"看起来比 RTT 还快"的正确解释：它只需**单向**传播（云 → 本地），而玩家登录包要跨 **1.5 次** WAN（客户端→云 是 1 RTT，云→本地再半程）。结构上镜像比登录包快约 1× 单向 ≈150ms ⇒ 这就是 0.8s 窗口够用的根因。

## 全球访问延迟实测（2026-10-11，check-host.net 57 节点）

TCP 连接 `129.226.213.65:16181`（新区服唯一入口 = frps）的往返：

| 区域 | 样本 | 最快 | 中位 | 最慢 |
|---|---|---|---|---|
| **南美**（巴西圣保罗） | 1 | 340ms | **340ms** | 340ms |
| **美洲**（美/加） | 5 | 161ms（温哥华） | **221ms** | 228ms（达拉斯/洛杉矶） |
| **欧洲** | 27 | 150ms（巴黎） | **199ms** | 275ms |
| 亚太（对照） | 17 | 14ms（新加坡） | 221ms | 332ms |

- 作废/异常样本：乌克兰 Kyiv 报 2ms（明显是节点本地拦截）；乌克兰 Khmelnytskyi 1335ms；罗马尼亚 Bucharest 超时；HK / 雅加达 / Rajpura 无结果。
- **玩家实际 RTT = 上表 + 云服↔本机那一跳**（改道前 ≈299ms、改道后 ≈85ms）⇒ 改道后：**欧洲 ≈284ms、美洲 ≈306ms、南美 ≈425ms**。

## ✅ 隧道改道直连（2026-10-11 已解决，ClashX Pro）

**根因**：ClashX Pro 处于 TUN 模式，`route get 129.226.213.65` → `gateway 198.18.0.1 / utun4`，`netstat -rn` 有 `128.0/1 → 198.18.0.1 utun4`（Clash TUN 特征路由）。订阅规则里没有任何针对该 IP 的条目 ⇒ 落到末尾 `Match → 🐟 漏网之鱼` **走代理**，云服看到的 frpc 来源是机场机房 IP（`103.151.173.99` 东京 / `141.11.146.74` 葵涌，均为 AS134972 IKUUU NETWORK，节点会飘）。⇒ **真实路径 = 家 → Clash TUN → 机场节点 → 新加坡**，白绕 ~200ms。
- 🔴 **`env -u` 剥代理变量只修了「frpc 把代理地址当 frps 地址」的崩溃，并没有让流量变直连** —— TUN 在网络层抓包，环境变量管不了。

**改动（ClashX Pro 专属）**：
- 客户端 = **ClashX Pro**（bundle `com.west2online.ClashXPro`），**不是** ClashX/Verge/Mihomo。配置目录 `~/.config/clash/`（是 git 仓库）。
- **生效配置 = `iKuuu_V2.yaml`**（494KB / 9816 条规则），由偏好 `SavedProxyModels` 决定 ⇒ `defaults export com.west2online.ClashXPro - ` 里 `[{"config":"iKuuu_V2",...}]`。`config.yaml` 是 823B 模板、规则**不生效**（只有端口设置会生效）。
- 内核 API 端口 = 偏好 `apiPort` = **64512**（不是 9090！`/version` 返回 `{"premium":true,"version":"c8abfc"}`）。
- 在 `rules:` 段**首行**插入：` - IP-CIDR,129.226.213.65/32,DIRECT,no-resolve`（缩进是 **1 空格 + `- `**）。
- **热加载无需重启 ClashX**：`curl -s -X PUT -H 'Content-Type: application/json' -d '{"path":"<cfg>"}' http://127.0.0.1:64512/configs`（空响应=成功）⇒ `/rules` 从 9816 → 9817。
- **必须让 frpc/tokensync 重连**才改道（旧 TCP 连接保留原路径）：`launchctl kickstart -k gui/501/com.tsg.shard10002.{frpc,tokensync}`，frpc 约 8s 重注册。
- **判定成功的唯一硬证据**：云服 `ss -tnH | awk '$4 ~ /:7700$/ {print $5}'` → 来源 IP 变成 **`113.83.112.247`（广州 · AS4134 CHINANET）** = 家宽真实出口。⚠️ `route get` 仍显示 utun4（TUN 抓包后 clash 自己直发），**不能作为判据**。
- ⚠️ **`iKuuu_V2.yaml` 是订阅文件**，「更新配置」会整份覆盖 ⇒ 规则丢失。幂等补救脚本 `~/ts-shard10002/clash-direct-fix.sh {apply [--reconnect]|verify|watch}`（自动从偏好识别生效配置 + API 端口，写入前备份，热加载，verify 还会查云服来源 IP 属于 CN 还是 IKUUU）。
- ⚠️ 两个会失效的场景：① 换成别的配置；② ClashX Pro 切到 **Global（全局）模式**（规则被绕过）。

## 区服改名 霓虹都市 → 庇护所九号 + 英文翻译（2026-10-11）

改的是**服务端数据**（客户端零改包即可显示新名），外加一条**客户端 i18n 登记**（英文语言包才需要）：

| # | 位置 | 改动 |
|---|---|---|
| 1 | 生产登录库 `x1_cn_test_login.server_info._id:2.name` | `霓虹都市` → `庇护所九号`（**只 `$set{name}`**，`open_time` 等原样保留；不要用 `add-shard-10002.sh apply`，它会把 `open_time` 刷成 now） |
| 2 | `~Lua/Common/LanguageManager.lua` | 末尾加 `AddManualTranslation("庇护所九号", "Shelter No. 9")` |
| 3 | `LuaBytes/Common_LanguageManager_64.bytes` | 重编（1174 → 1220 B），**必须与源码成对提交** |
| 4 | `~/ts-shard10002/*.sh` | `add-shard-10002.sh` 的 `NAME` 默认值 + 各脚本注释；`clash-direct-fix.sh` 的规则注释改成**不含区服名**（IP 永久，名字会变） |

- 🔴 **区服名的 i18n 机制**：`server_info.name` 只有中文字段，客户端 `Common/functions.lua GetLanguageStrByStr(zhStr)` 拿中文串去 `languageDicStr[zhStr]` 取 `.zh/.en/.jp/.kr`（依 `GetLan()` 选），**查不到就 `LogRed("languageDicStr no find Str: …")` 并回落原文**。`languageDicStr` 由 `Language.xlsx`（17626 行，列 `id/Chinese/English/Japanese`，**无 Korean 列**）→ `~Lua/Config/Data/Language.lua` → `LanguageManager.lua InitLanguageData()` 构建；**该表里从来没有区服名条目**（`霓虹序曲`/`霓虹都市`/`庇护所` 均 0 命中）。
  - ⇒ 加翻译**不必改 17626 行的 xlsx**（改 xlsx 要连带 `DataConfigMD5Record.asset` 的 CRC32 且会重导出覆盖手改 lua）。`LanguageManager.lua` 第 31–44 行有现成的 **`AddManualTranslation(zh, en)` 手动补充通道**（前人留的，commit `35ac53807 英语翻译`），前后各一个 entry 一行，`jp/kr` 自动回落中文。**这是新增区服名翻译的正规入口。**
- ✅ **字节码验证方法论**（可复用）：① 先用 `git show HEAD:<bytes>` 取基线，用**未改动源码**复编一次比对 md5 —— 一致（`727fa523…`）才证明工具链可信；② 改源码后重编，把新旧字节码各 `luajit -bl` 反汇编再 diff，**唯一语义差异应为新增的 `KSTR "庇护所九号"` + `KSTR "Shelter No. 9"` + `CALL`**；③ 最后用 `loadfile("<新bytes>")()` 真机同款路径跑一遍，确认 `languageDicStr["庇护所九号"].en == "Shelter No. 9"`。
- ⚠️ **到达真机需要客户端更新**：Editor 直接吃 `~Lua` 源码（立即生效）；真机（如 `com.Warera.timespace` 1.2.45/62）跑字节码，要么重打 APK（`docs/unity_android_build_skill.md` + `Assets/Editor/CLIBuilder.cs`），要么走热更（`BuildABs/files.unity3d` → `/www/wwwroot/rg/1/Android/version.txt`）。**未主动推热更**（会影响到该热更地址上的所有客户端）。
- 已提交：客户端 `d9059467d`（只 add 这两个路径，未用 `git add -A`）。全库扫过——生产 Mongo、工程、服务端仓库均无 `霓虹都市` 残留。
- ⚠️ 顺手发现（未处理）：10001「霓虹序曲」同样不在 `Language` 表里 ⇒ 英文语言包下它会显示中文，与「Shelter No. 9」并列会割裂。

## 区服列表「显示 / 隐藏」开关（2026-10-11 定案，当前状态 = 已隐藏）

**机制**（反汇编 `webapps/tk/WEB-INF/classes/com/ljsd/controller/GetServerListController.class` 逐条核实）：
- 登录服按 `{channel, sub_channel, plat}` 查 `server_info`，再在 **Java 主循环里逐条判定**：
  - `state == -1` 或 `state == 0` → `continue`（**不下发 ⇒ 客户端列表里整条消失**）★
  - `state == 5` → `getState(serverId, onlineNum)` 动态算成 2/3/4
  - `state == 2` → 参与「新服推荐位」竞选（取在线人数最多的那个，`recommend`）
  - 白名单 uid / 黑名单 IP 命中 → 强制 `state=2`；黑名单 uid 命中 → 强制 `state=1`
  - 之后还有 `server_version` 门控（见主 `MEMORY.md`）
- **客户端 `ServerListSelectPanel` 逐条渲染、不按 state 过滤**（`Maintenance` 只让点击弹 `11132`）⇒ 想让一条记录"消失"，**只能让服务端不下发**，改 state 图标之类没用。
- 「新服推荐位（`SetServerNew`）/ 最近登录（`SetServerRecent`）」都从 `serverList` 里反查 `GetServerInfo`，查不到就 `SetActive(false)` ⇒ **不下发即整条消失，客户端零改包**。

**操作**：`~/ts-shard10002/add-shard-10002.sh hide | show`（=`state:"0"` ↔ `state:"2"`，只 `$set{state}`，保留 `name/open_time`）。
- 实测：`hide` 后接口 `serverList` 只剩 `[{10001 霓虹序曲}]`、`recommend=null`；`show` 后回到两条。**登录服无缓存（每请求 `clear()` + 重查库）⇒ 立即生效，不用重启登录服。**
- 隐藏**不影响服务本体**：四件套照常跑、隧道照常、`JL_TOKEN` 镜像照常、`m5_x1_game_10002` 数据与已建号不动；**已在线玩家不掉线**（登录后不再查 `server_info`）。
- 备份：隐藏前文档存 `~/ts-shard10002/server_info_id2.hidden-backup.json`。
- ⚠️ 别用 `apply` 来"恢复显示"——它会把 `state` 写回 `"2"`（这点对）**但也会把 `open_time` 刷成 now**（这点不对）。恢复显示请用 `show`。

## 上线状态与遗留
隧道端到端 ESTABLISHED、406 张表加载（`file not find`=0）、四件套已由 launchd 托管、**隧道已改直连**（frpc 出口 = 家宽 113.83.112.247）。**区服列表当前只下发 10001 霓虹序曲；10002 庇护所九号已 `state="0"` 隐藏**（服务本体仍在跑，`show` 一键恢复）。

遗留：① 上游 `tokenK==null` NPE；② 跨服/世界聊天在新服不可用（`ChatLogic.initWorldChat → ThriftFactory.activateObject` NPE，本地无 worldserver/chatserver）；③ 家宽断电/动态 IP 无兜底 → **适合内测，不适合公测**；④ 订阅更新会冲掉 clash DIRECT 规则（用 `clash-direct-fix.sh` 兜）。
