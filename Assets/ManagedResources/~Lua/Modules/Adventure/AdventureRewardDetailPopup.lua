require("Base/BasePanel")
local AdventureRewardDetailPopup = Inherit(BasePanel)
local this = AdventureRewardDetailPopup

local adventureConfig = ConfigManager.GetConfig(ConfigName.AdventureConfig)
local monsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local rewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)
local mainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
this.selfsortingOrder = 0
--初始化组件（用于子类重写）
function AdventureRewardDetailPopup:InitComponent()
    this.mask = Util.GetGameObject(self.transform, "maskImage")
    this.finderRewardRoot = Util.GetGameObject(self.transform, "content/findsv/grid")
    this.killerRewardRoot = Util.GetGameObject(self.transform, "content/finalsv/gridFinal")
end

--绑定事件（用于子类重写）
function AdventureRewardDetailPopup:BindEvent()
    Util.AddClick(this.mask, function()
        this:ClosePanel()
    end)
end

--界面打开时调用（用于子类重写）
function AdventureRewardDetailPopup:OnOpen(areaId, arenaLevel, monsterId)
    -- 发现者奖励
    this.selfsortingOrder = self.sortingOrder
    local finderRewardId = nil
    for i,v in pairs(mainLevelConfig[areaId].InvasionBossReward) do
        if(v[1]==monsterId) then
            finderRewardId = v[2]
        end
    end
    this.GridAdapter(this.finderRewardRoot, finderRewardId)

    -- 击杀奖励
    local killerRewardId = monsterGroup[monsterId].Rewardgroup[1]
    this.GridAdapter(this.killerRewardRoot, killerRewardId)
end

-- 数据匹配
function this.GridAdapter(grid, rewardGroupId)
    Util.ClearChild(grid.transform)
    local itemDataList = rewardGroup[rewardGroupId].ShowItem
    for i = 1, #itemDataList do
        local view = SubUIManager.Open(SubUIConfig.ItemView,grid.transform)
        view:OnOpen(false,itemDataList[i],0.8,false,false,false,this.selfsortingOrder)
    end
end

return AdventureRewardDetailPopup