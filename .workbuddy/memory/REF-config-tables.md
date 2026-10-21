# 参考：客户端配置表（xlsx → lua → 服务端 TSV）链路

> 从 `MEMORY.md` 拆出（2026-10-12），内容未改动，仅迁址以免主记忆文件过大。
> 改动 `data_execl/base_data/*.xlsx` 源表时读本文件。

## 链路
`data_execl/base_data/<X>.xlsx`（**唯一真源**）
→ 导表工具 `Assets/Scripts/Editor/ExcelTool/DataConfig/DataConfigWindow.cs`（Unity 菜单 Data Config/Window）
→ 客户端 `~Lua/Config/Data/<X>.lua`（压缩编码）+ `Assets/ManagedResources/LuaBytes/Config_Data_<X>_64.bytes`
→ 服务端 `conf/server/<X>.txt`（TSV）。

## 🔴 CRC32 门控
- `DataConfigMD5Record.asset` 存每张源表 xlsx 的 **CRC32（十进制）**。**改 xlsx 必须同步该值**，否则导表判「已变更」重导出、覆盖手改的 lua。
- 结构 = Unity YAML 的 `_keys:` / `_values:` 两个平行数组（各 300 项）。**按 key 后缀匹配定位**，不可按行号（顺序会变）。
- 算：`python -c "import zlib;print(zlib.crc32(open('x.xlsx','rb').read())&0xffffffff)"`。

## 改表工具
- 样例 `/tmp/tsfix/{restore_xlsx,update_crc}.py`：`openpyxl.load_workbook()`（**不要**传 `data_only=True`）+ `wb.save()`。
- ⚠️ xlsx 有两种写法：Excel 原版（含 sharedStrings）/ openpyxl 重存版（inlineStr）。**别盲目 `git checkout` 历史 xlsx**，优先原地改；判据看逐格内容，不是哈希/文件体积。

## 客户端压缩表解码
- 解码器 `~Lua/Framework/GameDataBase.lua decodeList`：`__indexs/__values/__refs/__refPoss` + LZ 式十进制重复 + 末位累计和。
- 🔴 比对前**必须归一化行尾 TAB / CR**，否则全表逐行 diff 全是假差异。

## 🔴 导表三个已知坑（2026-10-20 实测）
1. **服务端 txt 输出目录是错的**：`DataConfigSetting.serverOutputDir` 硬编码
   `TimeSpaceServer/skzc/home/java/gameserver/conf/server`（2026-09-20 的老结构影子目录），
   真实服务端仓在 `TimeSpaceServer/Server_x1tag1.2.2/server_game/conf/server/`（独立 git 仓，分支 `x1-tag-1.2.2`）。
   ⇒ 导表产出的服务端配置**不会进真实仓**，必须另行同步。
2. **`DataToTxtExporter` 曾在每行末尾多写一个 TAB**（`sw.Write(val+"\t")` 后才 WriteLine）⇒ 288 个 txt 全部
   `1,Nc1,N` 整文件差异。2026-10-20 已改为 `string.Join("\t", cells)`（首尾不留 TAB）。
3. **列漂移是真的会发生的**：`RechargeCommodityConfig` xlsx 43 列 → 33 个服务端字段，但服务端仓 txt 只有 32 列，
   缺 `SystemMessageShow`（Java `SRechargeCommodityConfig`/`BuyGoodsLogic` 已引用）⇒ 判断「多一列」前先看是不是
   仓里的 txt 落后于代码。
- 导表是**确定性**的：全量重导后若只有你改过的表变化，说明其余 283 张与已提交 lua 逐字节一致（可当回归判据）。
- 导表只写 `~Lua` + 服务端 txt，**不写 LuaBytes**；字节码必须另跑 `scripts/lua-bytes-sync.sh`（自动取 git 改动集）。
- 导表会被 Unity GUI 占用挡住：`scripts/resource_build.sh` 的占用检查 2026-10-20 已修（旧版大小写不匹配 + 条件写反，从来没拦过）。

## 🔴 2026-10-21：服务端 txt 空值必须 `null`，不能 `nil`
- `DataHelper.GetValByDefault`（**仅** `DataToTxtExporter` 调用；客户端走 `GetClientValByDefault`）
  原本默认 `"nil"`。服务端 `StringUtil.parseFiledInt/parseFiledInt2/parseFiledInt3`
  （`gamecommon/src/main/java/util/StringUtil.java:20-56`）**只认 `null` / 空串 / `" "`**，其余直接
  `Integer.parseInt` ⇒ 任何 `mut,int#...` 列的空单元格都抛 `NumberFormatException`，**整张表加载中断**。
  `RechargeCommodityConfig` 就是 4547 格 → 本地服 15:10 那次起不来。已改 `"null"`（提交 `096d21d56`）。
- 判据：导出后 `grep -c $'\tnil' xxx.txt` 必须为 0；`null` 数量应与空单元格数一致。
- 为何长期没暴露：导出落影子目录 `TimeSpaceServer/skzc/.../conf/server`，真实仓
  `Server_x1tag1.2.2/server_game/conf/server` 从没被覆盖过 ⇒ 这条链 2026-10-21 才第一次真正跑通。
- 🔴 `scripts/resource_build.sh` 的 `ORIG_ARGS=("$@")` 必须在 **while 解析之前**取。
  放在后面 = 重入时 argv 已空 ⇒ `--action export` 跑成 `all`（白多建一次 AB）、`--server-env` 丢失
  （AB 打进工程当前 version.txt 口径 = 连错服）。已在 2026-10-21 修（提交 `69726cc00`）。
