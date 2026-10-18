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

## 启动踩坑
- 🔴 Tomcat/游戏服 lib 都被裁过：Tomcat `lib/` 少 10 个（含 `catalina.jar`）→ `ClassNotFoundException: org.apache.catalina.startup.Catalina`；`webapps/tk/WEB-INF/lib` 少 13 个（含 `mongo-java-driver`）→ `NoClassDefFoundError: com/mongodb/DBObject`。补齐源都在仓里 `TimeSpaceServer/skzc/home/java/...`。
- 🔴 `webapps/tk.war` 存在时 Tomcat 会**删掉并重建** `webapps/tk` 目录（失败时目录直接消失）⇒ 已把 war 改名 `tk.war.bak-20261018`，用展开目录部署。
- 🔴 `webapps/ROOT` 启动报 `One or more listeners failed`（Mongo 监听器）——**与客户端无关，忽略**；`/tk/*` 正常。
- `~/home/java/gameserver/config/logicSrv.properties` 是**死文件**（Spring 只认 `application.properties`），里面还有 `1127.0.0.1` 拼写错误，别照着改。
- 后台进程一律 `subprocess.Popen(start_new_session=True)`（`nohup &` 会被父会话清掉）。

## 已验证基线（2026-10-18 16:30）
`0 ERROR` / `0 file not find` / `SensitiveWordInit: words=385374, nodes=2535771, estimatedMB=26.6, cost=774ms` /
`jmap -histo:live` 里 `HashMap$Node` 仅 **7.6 万**（生产旧版 254 万）。
