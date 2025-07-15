HeroTemporaryManager = {}
local this = HeroTemporaryManager

local heroDatas = {}


function this.Initialize()
 
end

--初始化英雄数据
function this.InitHeroData(_msgHeroList)
    heroDatas = {}
    Log("服务端镜像英雄数量：" .. #_msgHeroList)
    for i = 1, #_msgHeroList do
        this.UpdateHeroDatas(_msgHeroList[i], true)
    end
    
end

--刷新本地数据
function this.UpdateHeroDatas(_msgHeroData,_isExtern)
    local heroData
   heroData= GoodFriendManager.GetHeroDatas(_msgHeroData.hero,_msgHeroData.force,_msgHeroData.SpecialEffects,_msgHeroData.guildSkill)
   GoodFriendManager.InitEquipData(_msgHeroData.equip,heroData)
   GoodFriendManager.InitModelData(_msgHeroData, heroData)
   heroDatas[heroData.dynamicId]=heroData
end



--获取单个英雄数据
function this.GetSingleHeroData(heroDId)
    if heroDatas[heroDId] then
        return heroDatas[heroDId]
    else
        --> todo 后续需要改
        local DefenseTrainingData = DefenseTrainingManager.GetSingleHeroData(heroDId)
        if DefenseTrainingData ~= nil then
            return DefenseTrainingData
        end

        return nil
    end
end


return this