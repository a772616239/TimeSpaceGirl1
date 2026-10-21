# TimeSpaceGirl1 长期记忆（索引·红线）

> 细节在同目录 `REF-*.md` 与 `YYYY-MM-DD.md`；这里只留「不知道就会踩坑」的红线。
> REF：`server-ops`（打包/热补丁/区服寻址）·`local-server`（自测服 16081+8081）·`shard10002`（历史）·`android-release`（AAB/AB/16KB/账号）·`config-tables`（xlsx→lua→TSV+CRC32）·`server-name-i18n`·`jenkins-ci`·`monetization`（付费/定价/抽卡，🔴 标尺用「抽等值」不用钻/元）。

## 环境
- Unity `6000.6.5f1`：必须国际版号；batchmode 显式 `-buildTarget Android`。
- 客户端 `a772616239/TimeSpaceGirl1`（PUBLIC，release）；服务端 `TimeSpaceServer/Server_x1tag1.2.2/`（独立 repo，`x1-tag-1.2.2`）。**并行会话会自动 commit ⇒ 提交必须显式列路径**。
- 登录服源码在 `TimeSpaceServer/skzc/home/java/loginserver/src/`（属主仓）：`verify-recommend-patch.sh`、`deploy-login-server.sh check|deploy --confirm|rollback`。
- SSH `gs` 129.226.213.65（2vCPU/3.6GB 已榨干）；Mongo 串必须 `authSource=admin`；编译 `sh gradlew`。`/data/srvlog/` 仅 ~3 天，审计走 `assets/log/jl_item|jl_logs|jl_blogs`。

## 🔴 红线
- 真机读 `LuaBytes/<路径>_64.bytes` ⇒ 源码+字节码成对提交（`scripts/lua-bytes-sync.sh`，不加 `-g`）。
- 货币 id `16=钻石 3=英雄经验 14=金钱 17=经验 79=情报`；名字走 `scripts/cheat/currency.py` 现算，禁写死。`item17` 语义未定，不能当离群基线；`reason=1` 永不产出钻石。
- `tolua` fake-null 只能 `IsNull()`；红点 `BindObjs[rpType]` 不幂等；`Timer.New` 第 4 参 UI 传 `true`。
- 配置表真源 `data_execl/base_data/*.xlsx`，改后同步 CRC32 + lua + LuaBytes + 服务端 `conf/server/*.txt`；备份禁放 `base_data/`。
- 正式服 `server.debug=false`；versionCode 只增不减、同号只能上一次；`--status draft` 是 production 不送审的唯一姿势。
- 删号/删英雄须清 rank 与引用（`rank-audit`/`refs-audit`），且**先归档**（`cheatctl archive`）。
- `tk/getServerList` 的 `recommend` 只许来自 `is_new=1`；否则老客户端 `serverList[i].level` 空值比较中断 → 登录报 `SocketAddress is nil`。
- 全服排行宝箱（`RankingRewardLogic.takeRankingReward`）**只判宝箱非空、不判玩家在不在榜** ⇒ 人人可领（10-21 已定位，待决策）。领取后界面又变可领＝客户端不回写 `RankingRewardedList`。
- 美术换风格出图**禁用内置 ImageGen**（10-21 用户明确），只走 AdsPower 换号；号池 6 个但换号链默认只试 3 个 ⇒ 必须显式 `ADSPOWER_PROFILES`，且换号要看过期台账 `_output/art_restyle/provider_state.json`。
- 新增地图 = **三步都得做**：prefab 的 `.meta assetBundleName`（复制来的会继承成 mapN-1）+ `ResourcePathConfig.asset` 三处**末尾追加**（resAbNameList / resInfoList / assetBundleList，条数必须相等，插中间会平移几千个 resAbNameIndex）+ `MainLevelConfig.BG`。漏资源登记 ⇒ `resMgr:LoadAsset` 返 nil，挂机战斗起不来。
- **本地 Unity 开着时不能跑 batchmode 导表**（`resource_build.sh` 检测同 `-projectpath` 进程直接拒绝）；导表走 Jenkins `TS-Resource-Build`，但打包目录从 origin 无条件 reset ⇒ **先 commit+push，产物再手动 copy 回开发目录**。

## 约定
- 巡检只读、量化分级；打包/校验/commit/push 可自行做，**送审/重启生产服/改线上部署先问**。
- 逐条 commit 且必须 push；中文 `type(scope): 摘要`；严禁 `git add -A`。
- 「都推了」= 两仓 `rev-list --count origin/<b>..<b>` 都为 0；push 前看有没有混进并行会话的提交。凭据一律 `.secrets/`（700/600）。
- 后台长任务 `Popen(..., start_new_session=True)`；zsh 下 `--include` 报 no matches（用 Grep）；GBK 源码 `grep -a`。
- 改系统级状态须当场验证并标注「重启后是否有效」；打补丁先用 `git show HEAD:path`。
