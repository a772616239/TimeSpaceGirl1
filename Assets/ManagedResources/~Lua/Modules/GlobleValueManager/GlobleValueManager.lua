GVM = {};
local this = GVM

--***************************************************************************************************
this.FormationMaxNum = 1                    --< enum 编队人数上限
--***************************************************************************************************

this.GlobleValueArray = {}

this.soundsIdx = 0
this.sounds = {}
function this.Initialize()
    this.GlobleValueArray[this.FormationMaxNum] = 5
end

function this.SetGVValue(vType, value)
    this.GlobleValueArray[vType] = value
end
function this.GetGVValue(vType)
    return this.GlobleValueArray[vType]
end

--> global task
local TaskTypeProfession = {
    [1] = GetLanguageStrById(12162),
    [2] = GetLanguageStrById(12161),
    [3] = GetLanguageStrById(12160),
    [4] = GetLanguageStrById(12163),
}
local TaskTypeControy = {
    [1] = HeroElementDef[1] .. GetLanguageStrById(22524),
    [2] = HeroElementDef[2] .. GetLanguageStrById(22524),
    [3] = HeroElementDef[3] .. GetLanguageStrById(22524),
    [4] = HeroElementDef[4] .. GetLanguageStrById(22524),
    [5] = HeroElementDef[5] .. GetLanguageStrById(22524),
}
local TaskTypeRange = {
    [1] = GetLanguageStrById(22525),
    [2] = GetLanguageStrById(22526),
}
local TaskTypeFormation = {
    [1] = GetLanguageStrById(22527),
    [2] = GetLanguageStrById(22528),
    [3] = GetLanguageStrById(22529),
    [4] = GetLanguageStrById(22530),
    [5] = GetLanguageStrById(22531),
    [6] = GetLanguageStrById(22532),
}

function GVM.GetTaskById(id, ...)
    local args = {...}
    local str = ""
    if id == 1 then
        str = string.format(GetLanguageStrById(22518), TaskTypeProfession[args[1]], TaskTypeRange[args[2]], args[3])
    elseif id == 2 then
        -- 验证参数数量和有效性
        if #args < 3 then
            error(string.format("GetTaskById(id=2) requires 3 arguments, got %d", #args))
        end
        if not args[1] or not TaskTypeControy[args[1]] then
            args[1] = "UNKNOWN_TYPE" -- 默认值
        end
        if not args[2] or not TaskTypeRange[args[2]] then
            args[2] = "UNKNOWN_RANGE"
        end
        if not args[3] then
            args[3] = 0 -- 默认值
        end
        
        str = string.format(
            GetLanguageStrById(22518), 
            TaskTypeControy[args[1]], 
            TaskTypeRange[args[2]], 
            args[3]
        )
    elseif id == 3 then
        str = string.format(GetLanguageStrById(22519), args[1])
    elseif id == 4 then
        str = string.format(GetLanguageStrById(22520), args[1])
    elseif id == 5 then
        str = GetLanguageStrById(22521)
    elseif id == 6 then
        str = string.format(GetLanguageStrById(22522), TaskTypeFormation[args[1]])
    elseif id == 7 then 
        str = GetLanguageStrById(22523)
    end
    return str
end

return this