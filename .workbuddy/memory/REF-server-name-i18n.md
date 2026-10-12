# REF：区服名多语言（2026-10-12 改造，取代旧的 AddManualTranslation 路径）

主入口见 `MEMORY.md`。本文件是该机制的全部细节。

## 为什么改

原实现：`server_info.name` 只存中文 → 客户端拿中文串去本地翻译表 `languageDicStr` 反查
（`~Lua/Common/functions.lua GetLanguageStrByStr`，查不到 `LogRed` 并回落中文）。
`Language.xlsx` **从来没有区服名条目**，所以每新增一个区服都要：
改 `LanguageManager.lua` 的 `AddManualTranslation` → 重编字节码 → **重新发版**。

⇒ 现改为把翻译下沉到**服务端数据**，客户端按语言选用。

## 数据模型（`x1_cn_test_login.server_info`）

沿用既有 snake_case 约定（`is_new` / `is_banreg` / `sub_channel`）：

| 字段 | 含义 |
|---|---|
| `name` | 中文原名（**语义不变**，见下方「不要动 name」） |
| `name_en` | 英文区名 |
| `name_jp` | 日文区名 |
| `name_kr` | 韩文区名 |

三个新字段**可缺省**：缺失或空串 ⇒ 登录服不下发 ⇒ 客户端回落翻译表 ⇒ 再回落中文原名。

## 已登记数据（2026-10-12 写入生产 `x1_cn_test_login`）

| `_id` | `server_id` | `name` | `name_en` | `name_jp` | `name_kr` | `state` |
|---|---|---|---|---|---|---|
| 1 | 10001 | 霓虹序曲 | `Neon Overture` | `ネオン序曲` | — | 2 |
| 2 | 10002 | 庇护所九号 | `Shelter No. 9` | `シェルター9号` | — | 2 |

- 命名口径：`Neon` 对齐游戏英文品牌 *Neon Valkyries*；「序曲」= *overture* / 日文 `序曲`（保留汉字）。
  10002 英文沿用早前客户端 `AddManualTranslation` 已登记的 `Shelter No. 9`，两处一致。
- `name_kr` 未填（用户本次只要英/日）⇒ 韩文包回落。补丁已支持该字段，需要时补一条 `$set` 即可。
- 写入方式：只 `$set` 这两个键，其它字段不动；备份
  `~/server-info-backups/server_info_id1_id2-before-i18n-20261012.json`（云服）+ `src/dry-run/backup/`（工程）；
  回滚 = `$unset{name_en:"",name_jp:""}`。
- ⚠️ **`x1_cn_test_login.server_info` 共 17 条**：`_id:1/2` 是真区服，`_id:3~17` 是 15 条
  `server_version:1` 的**全 null 占位**（不匹配 `{channel:"pc",sub_channel:"1",plat:"android"}` ⇒ 永不参与下发）。
  ⇒ 用 `find()` 核对时别被条数吓到，也别去"清理"它们（它们是 `shenheNum` 门控的既有形状）。
- 🔴 **只有登录服读这个集合**：生产游戏服 core 库是 `m5_x1_login`，**没有** `server_info`
  （REF-shard10002 记过：core 指向带 `server_info` 的库会让 `MongoUtil.init()` 遍历 NPE）
  ⇒ 往 `x1_cn_test_login.server_info` 加字段**碰不到游戏服**。
- ✅ **数据先写是安全的**：补丁未部署时线上 controller **不读**这两个字段，线上响应逐字节不变（实测）。
- **端到端验证**：写完后跑 `dry-run/run-dry-run.sh prod` ⇒ 补丁版响应里 10001/10002 各新增
  `name_en`/`name_jp`，原版无变化，`compare.py` 判定「除 name_* 外无任何差异」。

## 服务端：登录服 `tk/getServerList`

- 类：`webapps/tk/WEB-INF/classes/com/ljsd/controller/GetServerListController.class`
- 🔴 **原始工程只发布了 class，Java 源码早已丢失**。补丁是 **CFR 0.152 反编译重建 + 增强**，
  源码在 `TimeSpaceServer/skzc/home/java/loginserver/src/com/ljsd/controller/GetServerListController.java`。
- 🔴 该接口是**显式白名单**式构造响应（不是原样透传 Mongo 文档），所以加字段**必须改这个 class**。
  响应体由 `BasicDBObject.toString()` 输出（Mongo 风格 JSON，客户端直接解析）。
- 新增 `putIfNotEmpty(res, serverInfo, "name_en"|"name_jp"|"name_kr")`，**按需下发**。
- 响应里另有 `name` 字段属于 **`myServerList`/`lastServer` 的玩家角色名**（`getDBObject`），
  与区服名无关，**不要**往里塞分语言字段。

### 工具链（都在 `.../loginserver/src/`）

| 文件 | 作用 |
|---|---|
| `com/ljsd/controller/GetServerListController.java` | 重建+增强后的源码 |
| `build-and-verify.sh` | JDK8 离线编译 + 两级 diff 验证（`--emit-class` 出包到 `dist/`） |
| `dry-run/GslProbe.java` | 动态代理 mock `HttpServletRequest/Response`，不启 Tomcat 直接跑 `doGet` |
| `dry-run/run-dry-run.sh {local\|prod}` | `local` = 本地隔离库 `gsl_dryrun` 验新字段；`prod` = 云服对生产只读验零回归 |
| `dry-run/compare.py` | 原版/补丁版响应的语义级比对（只允许新增 `name_*`） |
| `deploy-login-server.sh {check\|deploy --confirm\|verify\|rollback --confirm}` | 部署（默认只读） |

### 🔴 重建/验证方法论（可复用到其它「只有 class」的服务端补丁）

1. **反编译基线**：`java -jar cfr.jar X.class --outputdir /tmp/out`。
2. **类型校准**：CFR 会丢泛型与显式强转，必须用
   `javap -l`（LocalVariableTable，拿**擦除后**签名与**槽位**）+
   `javap -v` 的 **LocalVariableTypeTable**（拿**泛型**）逐条校正声明类型。
   类型不对会让 `put` 之类绑定到 `BasicDBObject.put(Object,Object)` 而不是
   `DBObject.put(String,Object)` ⇒ 反汇编立刻能看出来。
3. **源码形状也要还原**：`if (a==0||a==-1||x&&y) continue;` 拆成三条独立
   `if (...) continue;`、三元改 if/else 等，否则分支极性不同、diff 一堆噪音。
4. **归一化比对**：必须把三类与语义无关的噪音归一化掉 ——
   **字节码偏移**（含分支目标与异常表 from/to/target）、**常量池索引**、**局部变量槽编号**。
   `build-and-verify.sh` 里有实现。
5. 两级 diff：① 纯重建版（删掉新增部分）vs 线上 class **必须完全一致**；
   ② 补丁版 vs 纯重建版 **必须只有预期新增**。实测本补丁 ② = 31 行新增 / 0 行删除。
6. ⚠️ `javap -bl`/`-c` 的文件名会进输出，比对时两侧**文件名必须相同**。

### 部署（🔴 重载机制已用**本机 Tomcat 8.5.95 离线沙箱实测**，2026-10-12）

🔴 **三步事实**（不是推测，沙箱复现过）：

| 动作 | 结果 |
|---|---|
| 只上传新 `.class` | ❌ **不触发重载**（`WEB-INF/classes/**` 不是被监视资源）⇒ 补丁不生效 |
| `touch webapps/tk/WEB-INF/web.xml` | ✅ `ContainerBackgroundProcessor` → `HostConfig.reload` → `context.reload()`，**只重载该应用、不重启 Tomcat**，也**不会**从 WAR 重新解包 ⇒ 补丁保留 |
| `touch webapps/tk.war` | 🔴 `undeploy` + **重新解包** ⇒ **把补丁 class 覆盖回 WAR 里的原版**。**绝对不要动** |

⇒ 标准动作 = **上传 class（必需）+ `touch WEB-INF/web.xml`（必需）**，两步缺一不可。

- 🔴 **重载有延迟**：后台线程按周期扫描，沙箱实测 `touch` 后约 **20~40s** 才打印重载日志。
  ⇒ **不能**用「打接口看是否 200」当重载完成判据（旧 class 期间照样 200 ⇒ **假报成功**）。
  正确判据：轮询 `catalina.out` 里的 `HostConfig.reload` + `[/tk]` 行
  （只匹配 logger/方法名与上下文名，**非本地化字串**，中英文 Tomcat 通吃）。
  `deploy-login-server.sh` 已按此改写，并加了「WAR mtime 变化告警」+「重载后复核磁盘 class md5」两道护栏。
- 真机窗口估计（**秒级**）：同应用冷部署实测 `3,809 ms` = TLD/JAR 扫描 ~2.87s +
  `WebContextListener`/Mongo 连接池 ~0.56s；`reload` 省掉解包但省不掉这两项。
  沙箱空应用 reload 仅 **17ms**、期间持续请求 1110 次全 200 —— 但真实 `tk` 明显更慢。
- ⚠️ 线上 `catalina.out` 里 `/tk` 重载次数基线 = **0**：该登录服**从未热重载过**，
  历史都是整机重启（最近一次进程启动 10-Oct 17:22:56）。本次是首次用这个机制。
- Manager 应用**没有可用账号**（`tomcat-users.xml` 里全是注释样例），所以走 touch 这条路。
- `deploy-login-server.sh deploy --confirm`：备份（云服 `$TC/backup-gsl-i18n/` + 本地 `src/backup-gsl-i18n/`）
  → 上传 → `touch web.xml` → **等重载日志（≤120s）** → 复核 class 未被 WAR 覆盖 → 轮询接口 90s。
  未观察到重载 ⇒ 自动还原磁盘 class 并报错（不会假报成功）。
- 基线 class md5 = `87104ceebb8898be15d3a1398354a3e4`；补丁 md5 = `d2a576bb00d5e42a6e896af93bd9d312`
  （`check` 会比对；线上既不是这两者就要先查清楚）。
- 自测接口（云服本机）：
  `curl -s 'http://127.0.0.1:8080/tk/getServerList?openId=x&channel=pc&plat=android&sub_channel=1&server_version=1.26001'`

#### 兼容性论证（为什么不会影响线上玩家）

1. **响应是超集**：新字段按需下发，只有中文 `name` 的老记录响应体**逐字节不变**
   （已对**生产库**只读 dry-run 验证：原版 vs 补丁版响应逐字节等价）。
2. **客户端对未知字段免疫**：`cjson.decode` → 普通 Lua table，之后**全程按名取值**，
   无 schema 校验、无 `pairs()` 全量遍历（选服面板 + 列表项都已核对）⇒ 新字段是死键。
3. **服务端只读**：`putIfNotEmpty` 只读 Mongo 文档、写进新建的响应对象，**不回写 DB**。
4. **无其它消费方**：线上访问日志里 `/tk/*` 只有 5 个端点，全来自游戏客户端。
5. ⇒ 唯一可感知影响是**部署那一刻的秒级重载窗口**；近 7 日实测 `getServerList` 峰值
   仅 14 次/小时（最闲 ~8 次/小时），撞上概率 < 1%，失败即重试。

## 客户端：`GetServerName(serverInfo)`

`~Lua/Common/functions.lua`（紧挨 `GetLanguageStrByStr`），取值优先级：

1. `name_en` / `name_jp` / `name_kr`（按 `GetLan()` 选）
2. `GetLanguageStrByStr(name)` —— 既有翻译表
3. `name` 中文原名

- 只接受 **非空字符串**：缺失 / 空串 / 类型异常一律视为「没配」并回落。
- `GetLan() == 0`（中文）直接返回原名，顺带消掉 `GetLanguageStrByStr` 在中文下也会刷的
  `languageDicStr no find Str` 红字告警。
- **5 处显示点**已统一走它：`LoginPanel.lua:262/:634`、`ServerListSelectPanel.lua`（新服推荐位 + 最近登录）、
  `ServerListItem.lua:SetValue`。⚠️ 后两处原先**根本没过 i18n**，英文包下一直是中文，本次顺带修掉。

### 🔴 不要动 `name`

`name` 同时被当作**稳定身份键**用，改语义会连带炸掉：
- `LoginPanel.lua` 的 `PlayerPrefs["lastServerName"]` 写入与回查（`isOpenGM` 分支按 `name` 匹配选中服）；
- 反查/排序逻辑。
⇒ 分语言只加**新字段**，`name` 永远保持中文。

## 真机生效前提：客户端必须重编字节码并发版

`~Lua` 改动对 Editor 立即生效，**真机吃 `LuaBytes/*_64.bytes`**。
用 `scripts/lua-bytes-sync.sh`（默认处理 git 里改动的 `~Lua/*.lua`；`--check` 可当提交前闸门）重编。
本次涉及 4 个：`Common_functions`、`Modules_Login_{LoginPanel,ServerListItem,ServerListSelectPanel}`。

行为验证：`scripts/lua-tests/test_getservername.lua`（`loadfile` 直接吃字节码，真机同路径，
**28 个断言**：含「真实生产数据」一节，逐条抄生产响应体验证 zh/en/jp/kr 四种语言；桩必须提供
`PlayerPrefs`，因为 `GetCurLanguage` 用 upvalue 缓存语言，换个语言要重新 load）。

## 时序 / 兼容性

- 服务端与客户端**可分别先上**：客户端没升 → 老逻辑读 `name`（也不看新字段）；服务端没升 → 客户端回落翻译表。
  两边都上齐才「新增区服零客户端改动」。
- 客户端**升级一次**是必须的（要走 `GetServerName`），此后新增区服不用再出包。
