languageDic={}
languageDicStr = {}

IsLanguagePack = ServerConfigManager.IsSettingActive(ServerConfigManager.SettingConfig.LanguagePackager)

function InitLanguageData()
    Log("fix yy InitLanguageData")
    local languageData= ConfigManager.GetConfig(ConfigName.Language)
    for index, config in ConfigPairs(languageData) do
        -- LogPink("config.originalconfig.original         "..config.id.."        "..tostring(config.text).."     "..tostring(config.english).."        "..tostring(config.vietnamese))
        if config.id then
            languageDic[config.id] = {}
            languageDic[config.id].zh = config.Chinese
            languageDic[config.id].en = config.English or config.Chinese
            languageDic[config.id].jp = config.Japanese or config.Chinese
            languageDic[config.id].kr = config.Korean or config.Chinese
        end
        if config.Chinese then
            languageDicStr[config.Chinese] = {}
            languageDicStr[config.Chinese].zh = config.Chinese
            languageDicStr[config.Chinese].en = config.English or config.Chinese
            languageDicStr[config.Chinese].jp = config.Japanese or config.Chinese
            languageDicStr[config.Chinese].kr = config.Korean or config.Chinese
        end
    end  
    LogGreen("语言初始化完成:"..tostring(#languageData))
end 

InitLanguageData()

-- 补充手动翻译（Config/Data/Language.lua 中缺失的条目）
local function AddManualTranslation(zhStr, enStr)
    if not languageDicStr[zhStr] then
        languageDicStr[zhStr] = {}
        languageDicStr[zhStr].zh = zhStr
        languageDicStr[zhStr].en = enStr
        languageDicStr[zhStr].jp = zhStr
        languageDicStr[zhStr].kr = zhStr
    end
end

AddManualTranslation("英雄祭品未选满", "Not all hero sacrifice slots are filled.")
AddManualTranslation("升星材料不足", "Insufficient materials for limit break.")
AddManualTranslation("材料不足且英雄祭品未满", "Insufficient materials and hero sacrifice slots not filled.")

-- 区服名（服务端 server_info.name 下发；Language 表中没有区服名的条目，故走手动通道）
AddManualTranslation("庇护所九号", "Shelter No. 9")

-- 国家排行榜（新增功能；比 Language.xlsx 多走一道 CRC32 + 服务端 TSV 链不划算，
-- 且这些文案纯客户端使用，故走手动通道。查表用 GetLanguageStrByStr(中文)）
AddManualTranslation("国家排行", "Country Ranking")
AddManualTranslation("国家排行榜", "Country Ranking")
AddManualTranslation("选择国家", "Change Country")
AddManualTranslation("选择你的国家", "Choose Your Country")
AddManualTranslation("选择国家/地区", "Select Country/Region")
AddManualTranslation("全服排行", "Global")
AddManualTranslation("本国排行", "My Country")
AddManualTranslation("我的排名", "My Rank")
AddManualTranslation("未上榜", "Unranked")