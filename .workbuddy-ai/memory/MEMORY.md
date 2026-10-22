# TimeSpaceGirl1 项目长期记忆

## 工作约定

- **改完就提交**（用户 2026-10-20 明确要求「记住提交啊」）：任何代码/配置/脚本改动完成后，
  立即 `git add` → 分组提交 → `git push origin release`，不要攒在工作区。
- 提交按主题分组，不要一把梭；信息用 conventional commits 中文描述（`fix(client):`、`feat(ci):`、
  `chore(build):`、`test(lua):`），正文写清根因/影响面。
- 提交前排除产物与临时文件：`apks/`、`build_log_*.txt`、`Assets/_Recovery/`、
  `.workbuddy*/tmp*/`、Unity 自动生成的 `untitledfolder`。
- 分支：主开发分支是 `release`（不是 main/master）。
- **总结的 skill 一律放 `docs/`**（用户 2026-10-20 明确要求）：写成扁平的
  `docs/<topic>_skill.md`（与 `unity_android_build_skill.md`、`cheat_detection_skill.md` 同风格：
  顶部写适用范围/更新时间/关联文档，正文含配方、判断规则、坑位、案例数据）。
  `.workbuddy-ai/skills/<name>/` 只留一个十几行的路由 `SKILL.md`（frontmatter + 指向 docs）
  和可执行脚本，**正文不要再堆在 skills 目录里**。

## 打包与服务器口径

- **线上服 = 柯测试服 = `129.226.213.65:8080`**（资源站 `:81`），即历史 Play 上架包用的现网。
  Jenkins 里选 `SERVER_ENV=现网-129.226.213.65`。
- `build_envs.json` 里标「正式服」的 `103.151.173.99:8080` 实测已死（HTTP 000），**不要用**。
- 出包前必须确认 Unity 编辑器未占用工程（`pgrep -x Unity`），否则 AB 重建 rc=3 直接失败；
  本机 AppleScript quit 被 TCC 拒，只能 `kill -TERM <pid>`。
- version.txt 共四处（`Assets/Resources/`、`Assets/StreamingAssets/Android/Resources/`、
  `Assets/Android/Resources/`、`AssetBundles/`），改环境要一起对齐；进包的是 StreamingAssets 那份。

## 关键坑位

- **导表产物 int 列必须按类型归一化，否则整张表不加载**：服务端 `STableManager.dealParams`
  对 int 列直接 `Integer.parseInt`、catch 后 `throw e`，一个单元格坏 = 整表跳过。
  xlsx 里常见的是**存成文本的 Excel 浮点噪声**（`'740.0000000000006'`、`'499.99999999999994'`）
  和越界哨兵（`9999999999`）、整数列写小数（`1.25`）。现口径 = Java `(int)` 向零截断 +
  int32 夹取（`1.25→1` 有损，要小数得改服务端列类型），导出器
  `DataHelper.GetServerValByType` 已内置，历史产物用 `table_sync.py --fix-numeric`。
  判定依据：发包树 `Server_x1tag1.2.2` 里就是截断后的值，说明这步以前有、后来丢了。

- 真机换包后仍连旧服：`VersionManager.InitVersions()` 优先用持久化
  `persistentDataPath/Android/version.txt`，已加 `SyncServerConfigFromPackage()` 用包内值纠正。
- 纯后端表（第 3 行导出类型全 4）导表工具会空跑，需要 `append_reward_items_to_server.py` 手工补。
- Unity batchmode 下 `Debug.Log` 抓不到，只能自己写文件日志；`Logs/Editor.log` 也不可靠。
- **包体积翻倍（AAB 822M / APK 855M）的元凶 = Gradle 里的陈旧临时文件**：
  `Library/Bee/Android/Prj/IL2CPP/Gradle/unityLibrary/src/main/assets/Android/` 下会残留
  2742 个 `.filename.XXXXXX`（每个正式 AB 一个同体积副本），Gradle 增量构建**永不清理**，
  每次打包全带上。判定：`unzip -l <包> | grep -c 'assets/Android/\.'`，正常应为 0。
  修法（`aab_release.sh` / `build_apk.sh` 已内置）：打包前 `find -delete` 清
  **StreamingAssets + `src/main/assets` + `build/intermediates/assets`** 三处。
  ⚠️ 只清 intermediates 无效，`src/main/assets` 才是真源头。
- **Jenkins 的 unity 锁不可嵌套**：`resource_build.sh` / `build_apk.sh` 会 exec 自身套
  `lock.sh --name unity`，job 里就**不能**再在外层套同一把锁（flock 不可重入 ⇒ 自己等自己，
  等满 timeout 判 rc=75）。TS-Resource-Build 已按此修过。
- `aab_release.sh` 的工程根取 `${PROJ:-脚本所在工程上一级}`，**别写死开发目录**：
  Jenkins 在 `TimeSpaceGirl1-build` 里调它，写死会去构建开发目录（GUI Unity 占用必拦）。
- **克隆玩家数据（机器人账号）两个必踩坑**：① Bson `Date` 是原生对象、没有 `_bsontype`，
  递归改写不先拦会变 `{}` → `getUser` 抛 `No mapping metadata found for java.util.Date`；
  ② 游戏实例 id 是 `uid+类型+时间戳` 字符串（英雄 `10000002010017798801320000`），
  只改 map **key** 不改字符串**值** → 编队 `heroId` 还是旧前缀，`getHero()` 查不到 →
  面板「有头像等级、编队 0 人、战力 0」。key 和值必须用同一条前缀替换规则。
  验证用 GM `bot team <uid>`（复刻 16650 协议路径，执行前会踢内存缓存）。
- **本地自测服和测试服是两套环境，只改一边等于没改**：本地 `~/home/java/gameserver`
  （launchd `com.ts.localserver.gameserver`，本机 Mongo 27017 是 **4.0 / wire version 7**，
  mongosh 和 pymongo 新版都连不上，灌数据走 `mongodump → scp → mongorestore`；
  jar 也是另一份构建，用 `scripts/bot/patch_local.sh` 编译打回，别拿测试服补丁 jar 覆盖）。
  用户经常在本地服（Unity 编辑器）上验证，报的 bug 可能只存在于本地。
- **Lua 里「按 id 查表」的函数会被喂已翻译文本**：`GetLanguageStrById(x)` 的入参在项目里
  经常是「查过一次的结果再查一次」（如 `GetLanguageStrById(this.getType())`），
  `tonumber` 失败后 `languageID` 为 nil。任何以入参为键的**缓存/去重表**都要先挡 nil 键，
  否则 `_cache[nil] = 1` 直接 `table index is nil`（2026-10-21 真机 Fatal，70807e4b1 修）。
  现口径：非数字串原样返回，不查表不记日志。

## 美术多语言贴片（scripts/image/loading_plate_overlay.py）

- 铭牌贴片 = 中文底图上覆盖「角色名 + 红条标签 + 台词」的小 PNG，运行时按 anchor 叠回去。
  贴片 **bbox 必须由实际墨迹反推**（`build_lines` → `layer_ink_quad` → `plate_box`），
  不能由 `name_box` / 红条几何推：大字斜排 15° + 纵向拉伸后左上角会跑到 name_box 的
  左外侧 `h/2·sinθ`、上外侧 `w·sinθ + h/2·cosθ`，几何框框不住 → 字母顶被切成一条直线
  （2026-10-22 修，05 的 BRUTUS 曾缺顶部 46px）。
- 大字另受 `NAME_HEADROOM=92` 硬约束（名字区上沿 = `name_box` 顶 - 92），越界就降字号。
- 🔴 **贴片 bbox 必须与语言无关**：`LoadingPlateGeom.lua` 一张图只存一组 anchor
  （`LoadingPanel.ApplyLangPlate` 按图号取，没有按语言分表），所以 bbox 对 `LANGS`
  全部语言取并集、小字擦除框按最长译名推。加新语言后要**九张全部重 publish**。
- `geom.json` 的 `ink_clip_px` = 墨迹被画板削掉的像素，`verify` 卡它必须为 0。
- 改完贴片 ≠ 进包：还要重打 LoginPanelAtlas 所在 AssetBundle。

## 服务端虚拟玩家（机器人）

- 代码在服务端仓 `com.ljsd.jieling.bot`（BotProfile/BotConfig/BotText/BotManager/DshClient/BotTask），
  配置 `server_game/conf/bot_config.json`（运行时 `~/home/java/gameserver/conf/`），
  文档 `docs/bot_player_skill.md`，桥接 `scripts/bot/dsh_bridge.py` + `start_bridge.sh`。
- 机器人是**内存虚拟玩家**（uid 9xxxxxxx），没有 netty 连接、没有 Mongo user：
  后台在线数靠 `MinuteTask` 往 `ONLINE_NUM` 叠加，世界发言靠 `MessageCache.addWordMsg`，
  msg 必须是 `"0|正文"`（客户端按 `<type>|` 解析，纯文本会让主界面 string.format 崩）。
- 英雄公告复用 `sendSysChatMessage(lists, Global.LUCKY_LUCK, heroId, ...)`（文案 key
  `lamp_lottery_content` = 语言 id 25010009，参数走 chatparms）。
- 回话链路：`ChatLogic` 世界(1)/跨服(16) 两处 `onWorldChat` → BotTask(15s) 判
  `lastHumanMsgId > lastBotMsgId` → 近 72h 上下文 POST 桥接 → 洗成 ≤40 字符口语 → 发回原频道。
- 🔴 **DSH headless 的 provider 坑**：默认 `provider=workbuddy` 从命令行调用恒定 400
  「请求被拦截」；必须 `provider=workbuddy-ai` + `WORKBUDDY_AUTH_FILE=/nonexistent`（屏蔽 CN 变体），
  用 `--patch` 叠加模型（不改 profile），10~15s 出话。根因见 TD `deepseek_harness.py`。
- GM 调试：`bot status|on|off|reload|say|announce|fake|reply`；`bot fake <名> <文本>` 可在
  没有客户端时验证整条 AI 回复链路。本机 GM 端口 7916（线上只监听 127.0.0.1，要开隧道）。
