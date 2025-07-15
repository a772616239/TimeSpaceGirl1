WarWayManager = {}
local this = WarWayManager
local WarWaySkillConfig = ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)

function this.Initialize()

end

function WarWayManager.GetDataWithLv(lv)
    local list = ConfigManager.GetAllConfigsDataByKey(ConfigName.WarWaySkillConfig, "Level", lv)
    local listA = {}
    for i = 1, #list do
        table.insert(listA, list[i])
    end
    return listA
end

function WarWayManager.InitData(_msg)

end


return this