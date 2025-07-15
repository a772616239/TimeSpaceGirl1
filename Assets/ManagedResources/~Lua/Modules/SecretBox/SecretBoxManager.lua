SecretBoxManager = {};
local this = SecretBoxManager
local DifferDemonsBoxSetting = ConfigManager.GetConfig(ConfigName.DifferDemonsBoxSetting)
local PrivilegeTypeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)

function this.Initialize()
    --主打异妖碎片Id
    this.StarDifferDemonsId = {}
    --免费抽取1次时间间隔
    --this.FreeTimeInterval=0
    --额外赠送物品Id和数量
    this.ExtraItem = {}
    --物品消耗Id和数量
    this.MainCost = {}
    --周期时间开始时间
    this.SeasonOpen = 0
    --周期时间结束时间
    this.SeasonEnd = 0
    --总抽取次数
    this.count = 0
    --今日抽取次数
    this.dayCount = 0
    --免费已使用次数
    this.secretBoxFreeUseTime = 0
    this.drop = {}
    this.extrarReward = {}
    this.typeId = {}
    this.SeasonTime = 1
    --获取界面显示必出次数
    this.ShowTime = 0
    --每日最大次数
    this.MaxNum = 0
    --获取秘盒显示所用数据
    --this.GetDifferDemonsBoxData()
end

--获取秘盒显示所用数据
function this.GetDifferDemonsBoxData()
    this.StarDifferDemonsId = {}
    for k, v in ConfigPairs(DifferDemonsBoxSetting) do
        if (v.SeasonTimes == this.SeasonTime and v.SecondaryCost == 1) then
            for i, m in pairs(v.StarDifferDemons) do
                table.insert(this.StarDifferDemonsId, m)
            end
            --this.FreeTimeInterval=v.FreeInterval*60
            this.SeasonOpen = v.SeasonOpen
            this.SeasonEnd = v.SeasonEnd
            this.ShowTime = v.ShowTimes
            this.MaxNum = PrivilegeManager.GetPrivilegeRemainValue(v.LimitPrivigele)
        end
        table.insert(this.typeId, v.Id)
        if (v.SeasonTimes == this.SeasonTime) then
            table.insert(this.ExtraItem, v.ExtraItem)
            table.insert(this.MainCost, v.MainCost)
        end
    end
    this.secretBoxFreeUseTime=PrivilegeManager.GetPrivilegeRemainValue(15)
    --免费已使用次数
    RecruitManager.recruitFreeUseTime =PrivilegeManager.GetPrivilegeRemainValue(14)
end

--获取秘盒当前周期和抽取次数
function this.GetSecretBoxRewardRequest(type, index)
    NetManager.GetSecretBoxRewardRequest(type, function(msg)
        this.drop = msg.drop
        this.extrarReward = msg.extrarReward
        this.RewardItemEnter(this.extrarReward)
        Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
        if (index == 1) then
            this.count = this.count + 1
            if(this.count==this.ShowTime) then
                this.count=0
            end
            PrivilegeManager.RefreshPrivilegeUsedTimes(DifferDemonsBoxSetting[1].LimitPrivigele,1)
            this.MaxNum = PrivilegeManager.GetPrivilegeRemainValue(DifferDemonsBoxSetting[1].LimitPrivigele)
            if(this.secretBoxFreeUseTime>=1) then
                PrivilegeManager.RefreshPrivilegeUsedTimes(15,1)
                this.secretBoxFreeUseTime=PrivilegeManager.GetPrivilegeRemainValue(15)
                CheckRedPointStatus(RedPointType.SecretBox_Red1)
            end
            Game.GlobalEvent:DispatchEvent(GameEvent.SecretBox.OnOpenOneReward, this.drop)
        end
        if (index == 10) then
            this.count = this.count + 10
            if(this.count>=this.ShowTime) then
                this.count=this.count%this.ShowTime
            end
            PrivilegeManager.RefreshPrivilegeUsedTimes(DifferDemonsBoxSetting[1].LimitPrivigele,10)
            this.MaxNum = PrivilegeManager.GetPrivilegeRemainValue(DifferDemonsBoxSetting[1].LimitPrivigele)
            Game.GlobalEvent:DispatchEvent(GameEvent.SecretBox.OnOpenTenReward, this.drop)
        end
    end)
end
--额外奖励物品进背包
function this.RewardItemEnter(drop)
    --if drop.itemlist ~= nil and #drop.itemlist > 0 then
    --    for i = 1, #drop.itemlist do
    --        local itemdata = {}
    --        itemdata.backData = drop.itemlist[i]
    --        BagManager.UpdateBagData(itemdata.backData)
    --    end
    --end
end

function this.RefreshFreeTime()
    this.secretBoxFreeUseTime=PrivilegeManager.GetPrivilegeRemainValue(15)
    if(ActTimeCtrlManager.SingleFuncState(21)) then
        CheckRedPointStatus(RedPointType.SecretBox_Red1)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.SecretBox.OnRefreshSecretBoxData)
end

--秘盒跨期数据刷新
function this.RefreshSeasonTime(msg)
    this.SeasonTime = msg.newSeasonId
    this.count =0
    this.GetDifferDemonsBoxData()
    Game.GlobalEvent:DispatchEvent(GameEvent.SecretBox.OnRefreshSecretBoxData)
end


--初始红点状态
function this.GetSecretBoxRedPointStatus()
    return this.secretBoxFreeUseTime < 1
end
--刷新红点状态(服务器暂定推送)
function this.RefreshSecretBoxRedPointStatus()
    CheckRedPointStatus(RedPointType.SecretBox_Red1)
end

--刷新秘盒红点
function this.CheckSecretRedPoint()
    if(this.secretBoxFreeUseTime>=1) then
        return true
    else
        return false
    end
end


return this