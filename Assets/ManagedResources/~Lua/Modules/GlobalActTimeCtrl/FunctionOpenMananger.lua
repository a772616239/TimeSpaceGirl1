FunctionOpenMananger = {};
local this = FunctionOpenMananger

-- 临时处理
local mainCity = {}
local carbon = {}

function this.Initialize()
    -- this.Insert(FUNCTION_OPEN_TYPE.NORMALCARBON, carbon)
    -- this.Insert(FUNCTION_OPEN_TYPE.ENDLESS, carbon)
    -- this.Insert(FUNCTION_OPEN_TYPE.TRIAL, carbon)
    -- this.Insert(FUNCTION_OPEN_TYPE.ELITE, carbon)

    this.Insert(FUNCTION_OPEN_TYPE.SHOP, mainCity)
    -- this.Insert(FUNCTION_OPEN_TYPE.ALLRANKING, mainCity)
    -- this.Insert(FUNCTION_OPEN_TYPE.ASPECT_STAR, mainCity)
    this.Insert(FUNCTION_OPEN_TYPE.HERO_RESOLVE, mainCity)
    -- this.Insert(FUNCTION_OPEN_TYPE.HAND_BOOK, mainCity)
    this.Insert(FUNCTION_OPEN_TYPE.ARENA, mainCity)
    this.Insert(FUNCTION_OPEN_TYPE.TRIAL, mainCity)
    -- this.Insert(FUNCTION_OPEN_TYPE.GUILD, mainCity)
    -- this.Insert(FUNCTION_OPEN_TYPE.MONSTER_COMING, mainCity)
    this.Insert(FUNCTION_OPEN_TYPE.COMPOUND, mainCity)
    this.Insert(FUNCTION_OPEN_TYPE.RECURITY, mainCity)
    this.Insert(FUNCTION_OPEN_TYPE.ELEMENT_RECURITY, mainCity)
    -- this.Insert(FUNCTION_OPEN_TYPE.SECRETBOX, mainCity)
    -- this.Insert(FUNCTION_OPEN_TYPE.TALENT_TREE, mainCity)
    -- this.Insert(FUNCTION_OPEN_TYPE.DIFFER_DEMONS, mainCity)
    -- this.Insert(FUNCTION_OPEN_TYPE.FIGHT_ALIEN, mainCity)


end


function this.InitCheck()

end

-- 获取某一功能是否显示恶心的字
function this.GetModuleOpen(openId)
    local isOpen = false
    local saveValue = PlayerPrefs.GetInt(PlayerManager.uid .. FUNC_OPEN_STR[openId])
    local funcOpen = ActTimeCtrlManager.IsQualifiled(openId)
    isOpen = saveValue == 0 and funcOpen
    
    return isOpen
end

-- 某个功能开启后，点击按键设置状态
function this.CleadNewText(openId)
    PlayerPrefs.SetInt(PlayerManager.uid .. FUNC_OPEN_STR[openId], 1)
end

function this.GetRootState(type)
    local openNum = 0
    local root = type == PanelTypeView.MainCity and mainCity or carbon
    for i, v in pairs(root) do
        if v ~= FUNCTION_OPEN_TYPE.FIGHT_ALIEN then -- 暂时不处理外敌
            local isOpen = this.GetModuleOpen(v)
            if isOpen then
                openNum = openNum + 1
            end
        end
    end

    return openNum > 0
end


function this.Insert(openId, insertTab)
    insertTab[#insertTab + 1] = openId
end



return this