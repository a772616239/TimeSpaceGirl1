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