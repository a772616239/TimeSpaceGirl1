--[[
 * 运行期补充 UI 配置
 *
 * 背景：UIConfig 是 data_execl/base_data/UIConfig.xlsx 导出的 LZ 压缩表
 * （Framework/GameDataBase.lua decodeList 解码），手工改那张表要同时动
 * xlsx + 导出 lua + LuaBytes + DataConfigMD5Record 的 CRC32 四处，风险高且不可 review。
 *
 * 这里改为「运行期注册」：把新增面板的配置直接写进解码后的 UIConfig 表。
 *   - 不动 xlsx / CRC32
 *   - 不重排既有 id 索引
 *   - 只在真正需要时（UIManager 已初始化）注册一次
 *
 * 新增面板请在此登记，字段与 UIConfig.xlsx 的列一一对应：
 *   id / type / name / assetName / script / noDestory / sortingOrder
--]]

UIConfigExtension = {}

-- UIType：1=全屏栈面板 2=弹窗 3=固定层级
local UIType_Full = 1
local UIType_Popup = 2

UIConfigExtension.Entries = {
    [1010] = {
        id = 1010,
        type = UIType_Popup,
        name = "CountryRankPanel",
        assetName = "CountryRankPanel",
        script = "CountryRank/CountryRankPanel",
        noDestory = false,
        sortingOrder = 0,
    },
    [1011] = {
        id = 1011,
        type = UIType_Popup,
        name = "CountryFlagSelectPopup",
        assetName = "CountryFlagSelectPopup",
        script = "CountryRank/CountryFlagSelectPopup",
        noDestory = false,
        sortingOrder = 0,
    },
}

local registered = false

--- 把扩展配置注入 UIConfig（幂等）
function UIConfigExtension.Register()
    if registered then
        return
    end
    local uiConfig = ConfigManager.GetConfig(ConfigName.UIConfig)
    if not uiConfig then
        LogError("[UIConfigExtension] UIConfig 未加载，注册失败")
        return
    end
    for id, entry in pairs(UIConfigExtension.Entries) do
        -- 已存在则跳过，避免覆盖官方配置
        local existed = rawget(uiConfig, id)
        if existed == nil then
            -- ⚠️ 必须用 rawset：UIConfig 解码后带 SheetBase 元表，
            -- 其 __newindex 是 readonlyMT（空函数），普通赋值会被静默吞掉。
            rawset(uiConfig, id, entry)
            Log("[UIConfigExtension] 注册 UI id=" .. tostring(id) .. " asset=" .. entry.assetName)
        end
    end
    registered = true
end

return UIConfigExtension
