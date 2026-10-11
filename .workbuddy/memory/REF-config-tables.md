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
