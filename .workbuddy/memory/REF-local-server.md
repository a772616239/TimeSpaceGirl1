# REF：本地自测服（2026-10-18 重建，取代已失效的 ~/ts-shard10002）

> 用途：**官方包客户端直连本机**做功能/性能自测，不碰生产。
> ⚠️ 旧方案 `~/ts-shard10002/` + frp + 生产登录库 + `JL_TOKEN` 镜像**整套已不存在**
> （目录被删、`/etc/synthetic.conf` 被清、`/home` 回到 autofs 空挂载）⇒ 见 `REF-shard10002.md` 只能当历史参考。

## 拓扑（全本机，零 root）
| 组件 | 位置 | 端口 |
|---|---|---|
| 游戏服 | `~/home/java/gameserver`（新 jar + `lib/*`） | **16081** |
| 登录服 | `~/home/java/loginserver/apache-tomcat-8.5.95`（`webapps/tk`） | **8081**（8080 被 Jenkins 占） |
| Mongo | `127.0.0.1:27017`，**有认证**：`a772616239 / Wang --authenticationDatabase admin` | 27017 |
| Redis | `127.0.0.1:6379` 无密码，登录服与游戏服共用 | 6379 |
| 一键脚本 | `~/home/java/start-local.sh {gs\|login\|all\|stop\|status}` | — |

- 库：游戏 `m5_x1_game_10001`（自动建）/ 登录 `x1_cn_test_login`（**本地库，不是生产那份**）。
- `x1_cn_test_login.server_info`：`_id:1` 10001「北美洲」state=3、`_id:2` 10002「亚洲」state=2，两条 **ip 都是 127.0.0.1 / port 16081**。
- 客户端侧：Editor 的「外部版本文件」= `<工程>/AssetBundles/version.txt`（`AppConst.PersistentDataPath` 在 `UNITY_EDITOR` 下就是它），把 `serverUrl` 改成 `http://127.0.0.1:8081/` 即切本地登录服；`resUrl` 保留生产 CDN，AB 热更照常。**该文件是跟踪文件，测完 `git checkout -- AssetBundles/version.txt` 回滚**（备份 `AssetBundles/version.txt.bak-before-local-20261018`）。

## 🔴 不需要 root 的关键：`-Dgameserver.root`
线上 `lib/gamecommon-1.0.0-SNAPSHOT.jar` 的 `util.SysUtil.getRootPath()` 是**硬编码 `"/home/java/gameserver/"`**（`fightmanager.jar` 里 `CheckFight` 同款），所以正常必须有 `/home/java`。macOS 上 `/home` 是 autofs 空挂载，建软链要 root + `synthetic.conf` + `apfs.util -t`。

本机做法（**不动系统**）：用**源码重建**的 `util/SysUtil.class` 覆盖 gamecommon 内那份，改成
```java
path.append(System.getProperty("gameserver.root", "/home/java/gameserver/"));
```
启动加 `-Dgameserver.root=/Users/wangxufeng/home/java/gameserver/` 即可。默认值与线上部署包逐字一致 ⇒ 同一份 jar 推到服务器行为不变。
补丁产物留存：`/tmp/sysutil/`（源码+class）；`~/home/java/gameserver/lib.bak-20261018/` 是旧 lib 备份。

## 部署新 jar（本地自测）
1. `cd server_game && JAVA_HOME=<jdk8> GRADLE_USER_HOME=$PWD/.gradle_home sh ./gradlew :serverlogic:jar`
2. 把 `deploy-overlay/gameserver-jar/{application.properties,logback-boot.xml}` 用 `zip -u` 覆进该 jar（新 jar 的 manifest **没有** Class-Path，启动用 `-cp "gameSrv-1.0.0.jar:lib/*"` 即可）。
3. 各模块 `*/build/libs/*.jar`（common/gamecommon/fightmanager/hotfix/netty/tablemanager）一起覆盖到 `lib/` —— 🔴 **必须同批**：旧 `gamecommon` 缺 `PlayerInfoProto$SetPlayerCountryResponse`，新 `gameSrv` 启动即 `BeanCreationException`。
   - 🔴🔴 **重建后必须把本地补丁 `util/SysUtil.class` 塞回 `lib/gamecommon-*.jar`**：旧 jar 里那份
     `getRootPath()` 是补丁版（读 `-Dgameserver.root`，默认 `/home/java/gameserver/`），源码里是 `"../../../"`（测试路径）。
     换整包 = 补丁丢失 ⇒ 启动 `STrialSetting.init NPE` + `file not find ../../../conf/server/*.txt`（表加载崩，端口不起，
     JVM 还会挂在那里）。做法：`unzip` 备份 jar 的 `util/SysUtil.class` 后 `touch` 再 `zip -u`（mtime 不新会被静默跳过）。
     判据：`javap -v` 里能看到常量 `gameserver.root`、class 大小 1999B（源码版 2202B）。
   - 只改 java 逻辑时优先**热补丁**：`zip -u gameSrv-1.0.0.jar <改动的 class>`（协议/依赖在 `lib/gamecommon`，
     应用类都在 gameSrv 里），比整包重建安全得多。
4. 外部配置 `~/home/java/gameserver/config/application.properties`（Spring Boot 优先级最高）与生产 deploy-overlay 版只差 3 处：mongo 账号 `a772616239/Wang`、core 库指向**空库** `m5_x1_login_10001`、`server.debug=true`。
5. 表：`conf/server` 与 `assets/conf/server` 各 406 张；旧骨架只有 393，缺的 13 张（ItemConfig/ItemInfo/Language/Monster*/Reward*/Option/MainLevel/ActivityLevel/ChannelRechargeId/EquipTalismana/SupremacyLevel）从生产 `gs:/home/java/gameserver/conf/server` 拷。

## 登录链路自测（不跑客户端也能验）
签名 = `md5(userName + password + "d13b3e8ef74bf72d8aafce3a1c8672a0")`（`UserLoginController` 字节码里写死的 key）。
```bash
SIGN=d13b3e8ef74bf72d8aafce3a1c8672a0; S=$(printf "localtest123456%s" $SIGN | md5)
curl "http://127.0.0.1:8081/tk/registerUser?userName=localtest&password=123456&repeat=123456&sign=$S"
curl "http://127.0.0.1:8081/tk/userLogin?userName=localtest&password=123456&sign=$S"   # -> openId/token
curl "http://127.0.0.1:8081/tk/getUserInfo?openId=<openId>&version=1.2.45&serverId=10001&token=<token>&platform=1"  # -> uid, token
curl "http://127.0.0.1:8081/tk/getServerList?openId=<openId>&channel=pc&sub_channel=1&plat=android&server_version=1.26001"
```
- 已建测试号：**localtest / 123456**（openId `7e65e2241bd6bd2bef8fbed63c190dfa`，uid 10000002）。
- `getServerList` 的 `server_version` **必须传真版本 `1.26001`**，传 `0` 会被算进 `shenheNum` → 空列表（同生产坑）。
- `getUserInfo` 首次调用曾抛 `MyMongoDBPool.inc NPE`（`inc_c` 文档 `_id:"inc_k"` 不含计数名），重试即成功；若稳定复现再查。

## 公告（notice_info）——本地必须自己塞数据
`/tk/getNotice` 从 `x1_cn_test_login.notice_info` 取（按 `grade` 分 0/1/2 桶，**优先 grade=2**，桶内取 `publish_time` 最大），
集合为空时返回写死的 `title="公告" / content="暂无公告..."`（纯文本、无 `<语言id>:` 前缀）。
- 🔴 写数据必须 `grade: NumberInt(2)`、`publish_time: NumberLong(毫秒)`。直接写 `grade: 2` 会存成 double，
  控制器 `Integer.parseInt("2.0")` 抛 `NumberFormatException` → HTTP 200 但 body 为空。
- 本机已插入一条双语自测公告（title 形如 `10001:中文…|10101:English…`），用于验证多语言解析；
  想恢复「无公告」状态：`mongo x1_cn_test_login --eval 'db.notice_info.deleteMany({})'`。

## 🔴 luafight（服务端战斗校验脚本）—— 只认生产/仓库那份
`~/home/java/gameserver/luafight/` 是 `CheckFight` 跑的服务端战斗逻辑，**必须整套与生产一致**，不能拿客户端的 `~Lua/Modules/Battle/Logic` 或 `luafight/2/` 顶替。

| 位置 | 状态 | 说明 |
|---|---|---|
| `luafight/BattleMain.lua` | ✅ 生产同款（md5 `f098b332…`） | 337/442/449/453 行调用 `BattleLogManager.WriteServerFightDataB` |
| `luafight/Modules/`（34 lua，含 `Buff/BEffect.lua`） | ✅ 唯一正确版 | ≡ 生产 `gs:/home/java/gameserver/luafight/Modules` ≡ 仓库 `server_game/luafight/Modules` |
| `luafight/2/`、`Modules.old-20261018`、`Modules.broken-20261018` | ❌ 坏的（33 lua） | `BattleLogManager` 只有 4 个函数、缺 `WriteServerFightData(B)`/`LogCa` ⇒ 主线结算必抛 `BattleMain:449 attempt to call nil` |

- 一行判定：`grep -c "^function this\." luafight/Modules/Battle/Logic/BattleLogManager.lua` = **11** 才对；`4` = 装错版本。
- 重装（免重启，`require` 每次读盘）：`tar` 从 gs 拉 `luafight` → `rsync -a --delete <prod>/Modules/ Modules/`。
- `luafight/2/BattleMain.lua`（215 行 Execute）与主 `BattleMain.lua`（309 行）**不是同一份**，`2/` 整体只算调试副本。
- `CheckFight.getRootPath()` 非 Windows 硬编码 `"../../../"` ⇒ 依赖 `~/luafight -> ~/home/java/gameserver/luafight` 这条软链（17:20 建，删了立刻 `Globals.load` NPE）。
- 结算失败的通用表现：服务端 `HandlerLogicThread` 兜底发 `errCode=0 / errMsg=""` 的空 ErrorResponse（`HandlerLogicThread.java:232`），客户端 `Network.lua:189` 打 `[Network ERROR DEBUG]`，`MapFightResultRequest` 回调不触发 ⇒ 打完卡在战场不结算。

## 启动踩坑
- 🔴 Tomcat/游戏服 lib 都被裁过：Tomcat `lib/` 少 10 个（含 `catalina.jar`）→ `ClassNotFoundException: org.apache.catalina.startup.Catalina`；`webapps/tk/WEB-INF/lib` 少 13 个（含 `mongo-java-driver`）→ `NoClassDefFoundError: com/mongodb/DBObject`。补齐源都在仓里 `TimeSpaceServer/skzc/home/java/...`。
- 🔴 `webapps/tk.war` 存在时 Tomcat 会**删掉并重建** `webapps/tk` 目录（失败时目录直接消失）⇒ 已把 war 改名 `tk.war.bak-20261018`，用展开目录部署。
- 🔴 `webapps/ROOT` 启动报 `One or more listeners failed`（Mongo 监听器）——**与客户端无关，忽略**；`/tk/*` 正常。
- `~/home/java/gameserver/config/logicSrv.properties` 是**死文件**（Spring 只认 `application.properties`），里面还有 `1127.0.0.1` 拼写错误，别照着改。
- 后台进程一律 `subprocess.Popen(start_new_session=True)`（`nohup &` 会被父会话清掉）。

## 已验证基线（2026-10-18 16:30）
`0 ERROR` / `0 file not find` / `SensitiveWordInit: words=385374, nodes=2535771, estimatedMB=26.6, cost=774ms` /
`jmap -histo:live` 里 `HashMap$Node` 仅 **7.6 万**（生产旧版 254 万）。

## 开机自启（launchd，2026-10-19）

### 为什么之前「登录不上」
服务是**手动** `start-local.sh all` 起的，日志写 `/tmp/gs-local.out`、`/tmp/tomcat-login.out`；
macOS 一重启（10-19 09:27）进程和 `/tmp` 一起清空 ⇒ 客户端 `getServerList` / `userLogin` 报
`Cannot connect to destination host`（8081 无监听）。不是配置或数据问题。

### 现在的结构与文件
| 文件 | 作用 |
|---|---|
| `~/Library/LaunchAgents/com.ts.localserver.gameserver.plist` | 游戏服 16081 |
| `~/Library/LaunchAgents/com.ts.localserver.loginserver.plist` | 登录服 8081 |
| `~/home/java/run-gs.sh` | 前台 `exec` 启动游戏服；**先等 27017/6379 就绪（≤120s）** |
| `~/home/java/run-login.sh` | 前台 `exec` 启动 Tomcat `catalina.sh run`；同样等依赖 |
| `~/home/java/start-local.sh` | 控制台：`status` / `install` / `uninstall` / `purge` / `start[-all]` / `stop[-all]` / `restart` / `logs` |
| `~/home/java/install-autostart.command` | 双击安装（先 stop 手动进程 → install → 失败自动回退手动启动） |
| `~/home/java/logs/{gameserver,loginserver}.log` | 持久日志（不再是 `/tmp`） |

- `RunAtLoad=true` + `KeepAlive=true` + `ThrottleInterval=30`：登录即起、**任何退出 30s 后自愈**（含 SIGHUP 后 exit 0）。
  代价：手动 kill 会被拉起 ⇒ 手动停服**必须** `start-local.sh stop-*`（内部走 `launchctl bootout`）。
- 🔴 **不能用 `KeepAlive={SuccessfulExit:false}`**：Tomcat 撞端口时 `Protocol handler initialization failed`
  之后**退出码仍然是 0**，SuccessfulExit 判定为"成功"⇒ job 直接停在 exited，8081 静默死掉（2026-10-19 09:52 实锤）。
- 🔴 **bootstrap 前必须等端口真正释放**：killed 之后 Tomcat 优雅关闭要 **10s+**（Mongo 监控线程不退出，
  `WARN The acceptor thread did not stop cleanly`）。`stop-a && install` 连写会让新进程抢 8081 失败。
  `install` 已内置 `wait_port_free`（≤40s），别绕过脚本手动 bootstrap。
- 开机时序：Mongo/Redis 比 launchd 晚就绪也不怕，wrapper 会等；真等不到才 `WARN` 照常起（launchd 再重试）。

### 🔴 沙箱内装不了 launchd
在本机 agent shell 里执行 `launchctl bootstrap` **恒报**
`Bootstrap failed: 5: Input/output error`（`launchctl list` 返回空、`launchctl print gui/501` 可读、
`sudo` 直接被禁 `operation not permitted`）；最小 plist、`user/501` domain、`launchctl load -w`、
`osascript do shell script`、`tell Terminal to do script`（automation -10004）**全部失败**
⇒ 这不是 plist 写错，是 agent 进程拿不到 launchd 写权限。

**安装姿势（需用户在自己的 Terminal.app 里跑一次）**：
```bash
~/home/java/start-local.sh stop-all && ~/home/java/start-local.sh install
# 或双击 ~/home/java/install-autostart.command
```
装好后 `start-local.sh status` 应显示 `launchd=loaded`。plist 权限必须 `644 owner=$USER`、无 quarantine xattr。
**只把 plist 放进 `~/Library/LaunchAgents/` 也能在下次登录时被 launchd 自动加载**，但本次会话需上面这条命令验证+接管。

### 登录链路自测（服务是否真活，不看端口看 body）
```bash
SIGN=$(python3 -c "import hashlib;print(hashlib.md5(b'localtest123456d13b3e8ef74bf72d8aafce3a1c8672a0').hexdigest())")
curl -s "http://127.0.0.1:8081/tk/userLogin?userName=localtest&password=123456&sign=$SIGN"      # code:0
curl -s "http://127.0.0.1:8081/tk/getServerList?openId=7e65e2241bd6bd2bef8fbed63c190dfa&channel=pc&plat=android&sub_channel=1&server_version=1.26001"
```
2026-10-19 09:47 复测：`code:0` + 两个区服（10001/10002，均 127.0.0.1:16081）；客户端 `version.txt` 的 `serverUrl` 仍是 `http://127.0.0.1:8081/`。

## 性能基线（2026-10-19 两批日志/运行时优化后，别再把参数改回去）

**日志**（前 21.2MB + 22.9MB 双写/天 → 稳态 **13 行 / 1.4KB 每分钟**）
- 已降级/删除：`MessageUtil wrappedBuffer`(每包2条→1条DEBUG)、`BaseHandler getmessage`(proto JsonFormat→DEBUG)、`HandlerLogicThread doWork useTime`(DEBUG)、`SessionManager` 收包/心跳/ack 接收检查(DEBUG)、`MinuteTask start/end/003-005`、`Poster bbb/ccc`（整段删）、`RankingRewardLogic updateDataTask`、`OnlineUserReportTask start`、`GuildFightLogic 车迟斗法progress`。
- `cmd____uid userinfo` 全量 gson 改成只打 uid/level/nick（曾单行 7.09MB）。
- `[ERROR]` 滥用已清：`重新登录 new / offLine->uid / getAllTodayLike(uids)` 降级；`ChampionshipLogic` 的 `getLogger(HeroLogic.class)` 误用已修正；`readIdea not receieve heart` 由 ERROR→WARN。
- logback（jar 内 `logback-boot.xml` 才是生效那份）：root 去掉 `file_console`（双写根源）、`ERROR` appender 去重、pattern 去 `%line`。
- 🔴 排查时临时开 DEBUG 不用改代码：`logging.level.com.ljsd.jieling.util.MessageUtil=DEBUG` 等。
- 🔴 凭证脱敏（`477eb4f4`）：session token / tokenKey **一律不进 INFO 明文**，统一走 `util/LogMaskUtil`（只留末 4 位，0/null/空串原样体现故障）。已覆盖 5 个 handler 的 `processMessage->…token=`（降 DEBUG）、`AuthManager` 登录校验、`SessionManager check token error`。新增同类日志照此办理；`GMRequestHandler GM_LOGIN_BY_UID` 的 tokenKey 属后台运维追溯，保留明文。

**运行时参数**（`~/home/java/gameserver/config/application.properties` 外部优先；repo 副本在 `deploy-overlay/gameserver-jar/application.properties`）
- `server.threadNum=8`（原 50，`h` 线程族 50 个只用 2 个）；线程总数 148→72。
- `spring.redis.timeout=2000`（原 0=永不超时，Redis 抖动时业务线程硬挂）。
- `mongodb.options.maxConnectionIdleTime=60000`（原 1000，8.4h 重建 193 次连接）。
- JVM 在 `~/home/java/run-gs.sh`：`-Xms256m -Xmx1280m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m`。🔴 堆不是瓶颈（实测只用 453MB），**别动 -Xmx**；Metaspace 原来无上限参数、committed 78MB 已到 97.2%。
- netty（`lib/netty-1.0.0.jar` 的 `NettyGameServer`）：通道选项必须 `.childOption()`，写 `.option()` 对已 accept 的子连接无效（历史每次启动刷 `Unknown channel option 'TCP_NODELAY'/'SO_LINGER'`，共 36 条）；`SO_LINGER=0` 已去掉（服务端子通道会让 close 发 RST），`bossGroup` 0→1。

**已加的常驻观测点**
- `login-userLoad uid= cost=ms`（`UserManager.userLogin` 冷路径）：量 Mongo findById + Spring Data 反序列化。⚠️ 实测 mongo shell `findOne` 只要 **1ms**（506KB 文档）⇒ 冷登录慢不在 Mongo IO。
- `reconnect-flush uid= heart/activity/store/globalFlush/pack`（`SessionManager` 重连）：一次重连有 ~774ms 静默区间，四段拆分定位。

**🔴 不能碰的数据**
- `playerManager.rechargeInfo.timeLimitMap` 504 条/149KB：446 条是 `closed+endTime=0+refreshTime 已设` 的周期礼包状态，`refreshTime` 是刷新锚点。`refreshWelfareState` / `checkchargeType` 在 serverlogic **无调用点（死代码）**，删了不会被重建 ⇒ 礼包永久消失。要缩体积只能把 `rechargeInfo` 拆出 User 主文档做懒加载（架构级，未做）。
- User 文档 506KB/35 manager：`playerManager` 206KB、`userMissionManager` 170KB、`activityManager` 71.6KB。


## 🔴 冷登录 / 重连 800ms（2026-10-19 定因，别再重复排查）
- 埋点两条：`login-userLoad uid= cost=ms`（UserManager.userLogin 冷路径）、
  `reconnect-flush uid= heart/activity/store/globalFlush/pack`（SessionManager 重连）。
- 实测 `heart=748 activity=8 store=1 globalFlush=20 pack=40` ⇒ **慢在 heart 段**＝`sendHeartBeat` + `getUserInMem(uid)`；
  内存未命中时它走 `getUser(uid,true)` 整份从 Mongo 加载。刷新链/背包合计仅 69ms。
- 冷加载构成：Mongo 裸读+BSON 解码 **11–17ms**、Spring Data 映射 **≈570ms**、648 个礼包转换 **10ms**。
  ⇒ 570ms 是 Spring Data POJO 映射固有成本（506KB / 35 manager / 数千嵌套对象）。
- 要再降只能拆文档（`rechargeInfo` 206KB + `userMissionManager` 170KB + `activityManager` 71.6KB 懒加载，
  架构级、访问点全改），或启动后预热最近活跃玩家（User 常驻内存，玩家一多会吃满 1.28GB 堆，不可放开）。
  当前结论：**接受每次重启后每人首次 0.6–0.8s**。
- 🔴 已推翻、别再走：① `MongoRechargeConverter`（每包 gson→fastjson 两轮反射）实测 648 包仅 **10ms**，
  改直接字段装载反而 31ms（fastjson 有 ASM codec），改动已回滚；② 读库 setter 的 `updateString`
  假记账未落库（`_id=0`、`null.modId` 均 0 条），不是问题。

**已修缺陷**
- `LoginRequestHandler`：`if(split>=2) userLogin(...)` + `else{}` + 紧跟无条件再调一次 ⇒ 每次登录 `userLogin` 执行两遍（首次会重复走 registerUser/initPlayer），已补成 if/else。
- `MinuteTask`：19 处 `LOGGER.error("Exception::N=>{}", e.toString())` 丢堆栈，已改 `, e`。

## 服列表 IP（2026-10-21 起）
- `x1_cn_test_login.server_info` 两条服的 ip 已从 127.0.0.1 改为 **192.168.3.82**（用户明令：测试服口径必须局域网 IP，包/客户端分发到别的设备也要能连）。port 16081 不变；游戏服/登录服都监听 `*:端口`，无需改绑定。
- 客户端侧口径链：build_envs.json「测试服」serverUrl=http://192.168.3.82:8081/（commit 2ea017a45）+ server_info ip=192.168.3.82。已用 getServerList 实测下发 ✓。
- 本机 MongoDB 4.0（wire v7）连不上新 mongosh（要求 wire≥8），**用 /usr/local/mongodb/bin/mongo** 旧 shell。
