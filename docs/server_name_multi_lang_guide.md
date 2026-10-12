# 🌐 《超时空美少女》区服名多语言配置与运维手册

本手册记录选服界面「区服名」多语言的实现方式、新增区服的标准动作，以及服务端补丁的验证与部署流程。
配套文档：`notice_multi_lang_guide.md`（运营公告多语言）、`server_ops_runbook.md`（服务端运维）。

---

## 🛠️ 一、问题回顾与根因分析

**原实现**：`server_info.name` 只存中文。客户端拿到这条中文串后，去本地翻译表反查：

```lua
-- ~Lua/Common/functions.lua
GetLanguageStrByStr(serverInfo.name)   -- languageDicStr[name].en / .jp / .kr
```

而 `languageDicStr` 由 `Language.xlsx`（17626 行）构建，**该表从来没有区服名条目**，
所以英文/日文包下会：

1. 打印 `LogRed("languageDicStr no find Str: …")` 红字告警；
2. 回落显示中文。

**后果**：每新增一个区服，都要改 `~Lua/Common/LanguageManager.lua` 的 `AddManualTranslation`
→ 重编 `LuaBytes/Common_LanguageManager_64.bytes` → **重新发版**。运营侧完全被客户端发版节奏卡住。

**另外发现两处漏网**：`ServerListItem:SetValue` 的列表项名、`ServerListSelectPanel:SetServerNew`
的「新服推荐位」名**压根没有过 i18n**，英文包下一直是中文（`LoginPanel` 的 `serverMes` 过了）。

---

## 💾 二、MongoDB 数据结构（`x1_cn_test_login.server_info`）

| 字段 | 必填 | 说明 |
|---|---|---|
| `name` | ✅ | **中文原名**。语义不变，见下方「§五 不要动 name」 |
| `name_en` | ➖ | 英文区名 |
| `name_jp` | ➖ | 日文区名 |
| `name_kr` | ➖ | 韩文区名 |

```js
// ✅ 正确：分语言字段齐全
{
  "_id": 2, "server_id": "10002", "name": "庇护所九号",
  "name_en": "Shelter No. 9", "name_jp": "シェルター9号",
  "channel": "pc", "sub_channel": "1", "plat": "android",
  "server_version": "0", "state": "2", "open_time": "1791644066",
  "ip": "129.226.213.65", "port": "16181"
}
```

**缺失/空串都安全**：三个字段留空则服务端**不下发**，客户端回落翻译表、再回落中文原名。
老区服不动也不会坏。

---

## 🚀 三、新增一个区服的标准动作（**客户端零改动**）

1. 往 `server_info` 插一条记录，`name` / `name_en` / `name_jp` 都写全；
   注意 `channel=pc`、`sub_channel=1`、`plat=android`（客户端硬编码），`server_version` 照抄现网值 `"0"`。
2. 生效即刻，**无需重启登录服**（列表每请求重查、无缓存）。
3. 自测：

```bash
# 在云服本机执行（平台参数必须与客户端硬编码一致，server_version 传真实版本号）
curl -s 'http://127.0.0.1:8080/tk/getServerList?openId=probe&channel=pc&plat=android&sub_channel=1&server_version=1.26001'
```

返回里该区服应带 `name_en` / `name_jp`。**不再需要**改 Lua、重编字节码或发版。

---

## 🧩 四、客户端取值链（`GetServerName`）

```
服务端分语言字段 (name_en/jp/kr，按 GetLan() 选)
   ↓ 缺失 / 空串 / 类型异常
本地翻译表 GetLanguageStrByStr(name)      ← 既有 AddManualTranslation 条目仍生效
   ↓ 查不到（会红字告警）
中文原名 name
```

- 只接受**非空字符串**，脏数据不会塞进 `Text`。
- `GetLan() == 0`（中文）直接返回原名，顺带消掉中文语言下也会刷的 `languageDicStr no find Str` 红字。
- 语言 id：`10001=中文 / 10101=English / 10201=日文 / 10301=韩文`
  （解析式 `floor(id/100)%100`，权威表 `conf/server/MultiLanguage.txt`）。

---

## ⚠️ 五、不要动 `name`

`name` 同时是**稳定身份键**，改语义会连带炸掉：

- `LoginPanel.lua` 的 `PlayerPrefs["lastServerName"]` 写入与回查（`isOpenGM` 分支按它匹配选中服）；
- 客户端若干按 `name` 反查/排序的逻辑。

⇒ 分语言只加**新字段**，`name` 永远保持中文。

---

## 🔧 六、服务端补丁：来源、验证与部署

补丁对象：`webapps/tk/WEB-INF/classes/com/ljsd/controller/GetServerListController.class`
（接口 `tk/getServerList`）。

### 6.1 🔴 源码是反编译重建的

原始工程**只发布了 class，Java 源码早已丢失**。首次加字段时用 CFR 反编译重建了源码，
再用 `javap` 校准类型（`-l` 拿槽位与擦除签名、`-v` 的 `LocalVariableTypeTable` 拿泛型），
最后以「同源复编 → 指令流归一化 diff」证明重建版与线上 class **语义完全一致**。

源码与配套工具都在 `TimeSpaceServer/skzc/home/java/loginserver/src/`：

| 文件 | 作用 |
|---|---|
| `com/ljsd/controller/GetServerListController.java` | 重建 + 增强后的源码 |
| `build-and-verify.sh` | JDK8 离线编译 + 两级 diff 验证（`--emit-class` 出包） |
| `dry-run/` | 不启 Tomcat 直接跑 `doGet` 的探针 + 原版/补丁版语义比对 |
| `deploy-login-server.sh` | 部署（默认只读，`--confirm` 才上线） |

### 6.2 验证（可复现）

```bash
cd TimeSpaceServer/skzc/home/java/loginserver/src

./build-and-verify.sh              # ① 纯重建版 vs 线上 class 必须完全一致
                                   # ② 补丁版 vs 纯重建版 必须只有预期新增

./dry-run/run-dry-run.sh local     # 本地隔离库 gsl_dryrun：验新字段的各种形态
./dry-run/run-dry-run.sh prod      # 云服对生产库只读：验存量记录零回归
```

判定标准：两级 diff 中，① 指令流完全一致；② **纯新增 31 行 / 0 行删除**。

### 6.3 部署（🔴 需明确同意）

```bash
./deploy-login-server.sh check                  # 只读体检：比对 md5、取接口基线、看 WAR mtime/重载次数
./deploy-login-server.sh deploy --confirm       # 备份 → 上传 → touch web.xml → 等重载日志 → 验证
./deploy-login-server.sh rollback --confirm     # 还原
```

#### 重载机制（本机 Tomcat 8.5.95 离线沙箱**实测**，不是推测）

| 动作 | 结果 |
|---|---|
| 只上传新的 `.class` | ❌ **不触发重载**（`WEB-INF/classes/**` 不是被监视资源）⇒ 补丁不生效 |
| `touch webapps/tk/WEB-INF/web.xml` | ✅ 被 `ContainerBackgroundProcessor` 发现 → `HostConfig.reload` → `context.reload()`（**只重载该应用**，不重启 Tomcat） |
| `touch webapps/tk.war` | 🔴 `undeploy` + **从 WAR 重新解包** ⇒ **把补丁 class 覆盖回原版**。**绝对不要动** |

- 所以标准动作是**两步：上传 class（必需）+ `touch web.xml`（必需）**。
- 触发**有延迟**：后台线程按周期扫描，本机实测 `touch` 后约 **20~40s** 才打印重载日志。
  ⇒ 🔴 **不能**拿「打接口是否 200」当重载完成判据 —— 重载发生前旧 class 照样返回 200，
  会**假报成功**。`deploy` 已改为轮询 `catalina.out` 里的 `HostConfig.reload … [/tk]` 行
  （只匹配 logger/方法名与 `[/tk]`，都是非本地化字串，中英文 Tomcat 通吃）。
- 真机重载耗时：同应用**冷部署**实测 `3,809 ms`（TLD/JAR 扫描 ~2.87s + `WebContextListener`
  /Mongo 连接池 ~0.56s）；`reload` 省掉 WAR 解包但**省不掉**这两项 ⇒ 窗口按**秒级**估计。
- Manager 应用**没有可用账号**（`tomcat-users.xml` 全是注释样例），所以走 touch。
- 基线 md5 `87104ceebb8898be15d3a1398354a3e4` / 补丁 md5 `d2a576bb00d5e42a6e896af93bd9d312`；
  线上既不是这两个值就说明被改过，先查清楚。
- 沙箱实测参考：`touch web.xml` 触发的重载耗时 **17ms**（空应用）、期间持续请求
  **1110 次全部 200**；真实 `tk` 应用因为有 JAR 扫描 + 连接池重建，窗口会明显更长。
- ⚠️ 线上 `catalina.out` 里 `/tk` 重载次数基线为 **0** —— 这个登录服**从未热重载过**，
  历史上都是整机重启。本次是首次使用该机制。

---

## 📦 七、客户端侧：改 Lua 必须重编字节码

真机吃预编译字节码（`Assets/ManagedResources/LuaBytes/<路径下划线化>_64.bytes`），
只有 Editor 回落 `~Lua/*.lua` ⇒ **只改源码 = Editor 有效、真机无效**，两文件必须成对提交。

```bash
scripts/lua-bytes-sync.sh                  # 自动处理 git 里改动的 ~Lua/*.lua
scripts/lua-bytes-sync.sh --check          # 只检查（可当提交前闸门）

# 行为验证：直接 loadfile 预编译字节码，与真机同路径
cd LuaEncoder/luajit_mac/64
LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_getservername.lua \
  ../../../Assets/ManagedResources/LuaBytes/Common_functions_64.bytes
```

本次涉及 4 个：`Common_functions`、`Modules_Login_{LoginPanel,ServerListItem,ServerListSelectPanel}`。

---

## 🕐 八、上线顺序与兼容性

服务端与客户端**可以分别先上**，两边都不冲突：

| 场景 | 行为 |
|---|---|
| 服务端已上、客户端没升 | 老逻辑读 `name` 中文（新字段被忽略），与现状一致 |
| 客户端已升、服务端没上 | `GetServerName` 取不到分语言字段 → 回落翻译表（现状） |
| 两边都上齐 | ✅ **新增区服只需写数据，客户端零改动** |

### 8.1 为什么服务端多下发字段不会影响线上玩家

1. **响应内容是超集，老记录逐字节不变。** 新字段按需下发（缺失/空串不下发），
   `server_info` 里只有中文 `name` 的老记录，其响应体与改动前**完全一致** —— 已对**生产库**
   只读 dry-run 验证（原版 class vs 补丁版，10001/10002 两条真实记录逐字节等价）。
2. **客户端解析对未知字段天然免疫。** 响应经 `cjson.decode` 变成普通 Lua table，
   之后全程**按名取值**（`server_id`/`name`/`ip`/`port`/`state`/`isnew`），
   **没有任何 schema 校验、也没有 `pairs()` 全量遍历**（选服面板与列表项都已核对）。
   ⇒ 多出来的 `name_en/jp/kr` 只是躺在那里的死键，不会被渲染、不会被误用。
3. **服务端补丁对数据只读。** `putIfNotEmpty` 从 Mongo 文档读字段写进新建的响应对象，
   **不回写 DB**；其余 Redis 调用全是读（`hgetAll`/`get`）。
4. **没有别的消费方。** 线上访问日志里 `tk/*` 只有 5 个端点
   （`getNotice`/`getServerList`/`userLogin`/`getUserInfo`/`registerUser`），
   全部来自游戏客户端，没有 Web 端/第三方在解析这个接口。

⇒ **唯一会给玩家带来可感知影响的是「部署那一刻重载 tk 应用」的秒级窗口**
（见 6.3）。近 7 日实测流量峰值仅 14 次 `getServerList`/小时（最闲时段 ~8 次/小时），
撞上秒级窗口的概率 < 1%，且失败表现为登录请求失败一次、重试即可。

⚠️ 客户端**需要升级一次**（要走新的 `GetServerName`），此后新增区服不用再出包。
