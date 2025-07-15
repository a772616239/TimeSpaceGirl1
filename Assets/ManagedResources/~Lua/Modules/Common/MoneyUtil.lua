MoneyUtil = {}
local this = MoneyUtil


this.RMB2O = {}

function this.Initialize()
    --this.MT = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig, 79).Value)
    local er = ConfigManager.GetConfig(ConfigName.ExchangeRate)
    for _, v in ConfigPairs(er) do
        this.RMB2O[v.Price_1] = v 
    end

    this.multiLanguageData = G_MultiLanguage[GetCurLanguage()]
end

-- 获取相应的金额
function MoneyUtil.GetMoney(_rmbp)
    return this.multiLanguageData.Symbol .. MoneyUtil.GetPrice(_rmbp)
end

function MoneyUtil.GetPrice(_rmbp)
    local rmbp = tonumber(_rmbp)
    if rmbp < 0 then
        return rmbp
    end
    if not this.RMB2O[rmbp] then
        LogError("表 ExchangeRate 错误： 不包含档位："..tostring(rmbp)) 
        return 0
    end

    local m = this.RMB2O[rmbp][this.multiLanguageData.Exchange]
    if not m then
        LogError("表 ExchangeRate 错误： 档位："..tostring(rmbp).." , 未找到对应的货币类型 "..this.MT) 
        return 0
    end

    return tonumber(m)
end

--> 获取当前货币单位
function MoneyUtil.GetCurrencyUnit()
    return this.multiLanguageData.Symbol
end

return MoneyUtil