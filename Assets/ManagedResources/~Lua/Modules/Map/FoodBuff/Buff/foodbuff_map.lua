local FoodBuff = require("Modules/Map/FoodBuff/FoodBuff")
local foodbuff_map = Inherit(FoodBuff)
local this = foodbuff_map

-- 构造方法
function this:new(id)
    local o = {}
    this.__index = this
    setmetatable(o, this)
    o.ID = id
    o:ctor()
    return o
end

-- 持续buff，开始回调
function this:onStart()
    for _, v in ipairs(self.effectPara) do
        local funcData = ConfigManager.GetConfigData(ConfigName.ExploreFunctionConfig, v[1])
        local _ExploreFunc = require("Modules/Map/FoodBuff/Buff/ExploreFunc/f"..funcData.type)
        if _ExploreFunc and _ExploreFunc.Start then
            _ExploreFunc:Start(v[2], funcData.Value)
        end
    end
end

-- 持续buff，结束回调，取消buff效果
function this:onEnd()
    for _, v in ipairs(self.effectPara) do
        local funcData = ConfigManager.GetConfigData(ConfigName.ExploreFunctionConfig, v[1])
        local _ExploreFunc = require("Modules/Map/FoodBuff/Buff/ExploreFunc/f"..funcData.type)
        if _ExploreFunc and _ExploreFunc.End then
            _ExploreFunc:End(v[2], funcData.Value)
        end
    end
end


-- 如果是一次性触发的buff，回调此事件，本次副本永久性增加，
function this:onOnceBuff()
    for _, v in ipairs(self.effectPara) do
        local funcData = ConfigManager.GetConfigData(ConfigName.ExploreFunctionConfig, v[1])
        local _ExploreFunc = require("Modules/Map/FoodBuff/Buff/ExploreFunc/f"..funcData.type)
        if _ExploreFunc and _ExploreFunc.Start then
            _ExploreFunc:Start(v[2], funcData.Value)
        end
    end
end


return this