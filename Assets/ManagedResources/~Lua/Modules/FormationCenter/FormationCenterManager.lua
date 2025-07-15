FormationCenterManager={}
local this=FormationCenterManager
--侦查(是否开启)， 0 = 未开启， 1 = 已开启
local isOpenInvestigate = 0
--侦查(是否解锁)(大于0 = 等级)， 0 = 未解锁， 非0 = 等级(已解锁)
local investigateLevel = 0
--解锁商品类型
local storeTypeId = 0

local investigateConfigs = ConfigManager.GetConfig(ConfigName.InvestigateConfig)

function this.Initialize()
end

--初始化数据
function this.InitData(msg)
    isOpenInvestigate = msg.isOpenInvestigate
    investigateLevel = msg.investigateLevel
    if investigateLevel > 0 then
        storeTypeId = investigateConfigs[investigateLevel].StoreTypeId
    end
end

--数据推送
function this.PushData(msg)
    storeTypeId = msg.storeTypeId
    this.SetInvestigateLevel(msg.level)        
end

function this.GetStoreId()
    return storeTypeId
end

--侦查是否开启
function this.IsOpen()
   return isOpenInvestigate>0 
end

--侦查等级（0未解锁，非0=等级）
function this.GetInvestigateLevel()
    return investigateLevel
end

--设置侦查等级
function this.SetInvestigateLevel(level)
    investigateLevel = level
    if investigateLevel > 0 then
        storeTypeId = investigateConfigs[investigateLevel].StoreTypeId
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.FormationCenter.OnFormationCenterLevelChange, level)
end

function this.GetAllPropertyAdd()
    if investigateLevel == 0 then -- not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.InvestigateCenter) or
        return {}
    end
    local addAllProVal = {}

    local investigateConfig = investigateConfigs[investigateLevel]
    for i = 1, #investigateConfig.PropertyAdd do
        local propertyId = investigateConfig.PropertyAdd[i][1]
        local propertyValue = investigateConfig.PropertyAdd[i][2]
        if addAllProVal[propertyId] == nil then
            addAllProVal[propertyId] = 0
        end
        addAllProVal[propertyId] = addAllProVal[propertyId] + propertyValue
    end

    return addAllProVal
end
return this