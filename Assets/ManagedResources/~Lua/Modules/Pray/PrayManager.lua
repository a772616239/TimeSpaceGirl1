PrayManager = {};
local this = PrayManager
local blessingRewardPool = ConfigManager.GetConfig(ConfigName.BlessingRewardPool)
this.patyRewardData = {}--16 个奖励  祈祷用
this.patyPreviewRewardData = {}--16 个奖励  预览用
--12 个奖励  选择库
this.legendReward = {}--传说奖励
this.supremeReward = {}--至尊奖励

this.extraRewardData = {}--额外奖励  抽到一定次数会有额外奖励   3#5#7#10#13#16
this.lastRefreshTime = 0
function this.Initialize(_msg)
end
function this.InitializeData(_msg)
    this.patyRewardData = {}
    this.patyPreviewRewardData = {}
    this.legendReward = {}
    this.supremeReward = {}
    this.extraRewardData = {}
    if _msg == nil then
        
        return
    end
    
    this.lastRefreshTime = 0
    if  _msg.lastRefreshTime and  _msg.lastRefreshTime > 0 then
        this.lastRefreshTime = _msg.lastRefreshTime
    end
    --16 个奖励  祈祷用
    for i = 1, #_msg.fixReward do
        local reward ={}
        reward.id = _msg.fixReward[i].locationId
        
        reward.rewardId = _msg.fixReward[i].rewardId
        if _msg.fixReward[i].rewardId > 0 then
            reward.itemId = blessingRewardPool[_msg.fixReward[i].rewardId].Reward[1]
            reward.num = blessingRewardPool[_msg.fixReward[i].rewardId].Reward[2]
        else
            reward.itemId = 0
            reward.num = 0
        end
       -- 0未保存无物品 1 未保存有物品 2 已选择 3 已祈福
       -- _msg.fixReward[i].state   0 时 选择保存之前 itemId<0 0未保存无物品 反之 1 未保存有物品
       --                           1 时 选择保存之后 itemId<0 2 已选择  反之  3 已祈福
        if _msg.fixReward[i].state == 0  then
            if reward.itemId <= 0 then
                reward.state = 0
            else
                reward.state = 1
            end
        elseif _msg.fixReward[i].state == 1  then
            if reward.itemId <= 0 then
                reward.state = 2
            else
                reward.state = 3
            end
        end
        this.patyRewardData[reward.id] = reward
    end
    --16 个奖励  预览用
    if _msg.rewardView then
        for i = 1, #_msg.rewardView do
            local reward ={}
            reward.id = _msg.rewardView[i].locationId
            
            reward.rewardId = _msg.rewardView[i].rewardId
            if _msg.rewardView[i].rewardId > 0 then
                reward.itemId = blessingRewardPool[_msg.rewardView[i].rewardId].Reward[1]
                reward.num = blessingRewardPool[_msg.rewardView[i].rewardId].Reward[2]
            end
            reward.state = 2
            for i = 1, #this.patyRewardData do
                if this.patyRewardData[i].rewardId == reward.rewardId then
                    reward.state = 3
                    break
                end
            end
            this.patyPreviewRewardData[reward.id] = reward
        end
    end
    --12 个奖励  选择用
    for i = 1, #_msg.legendReward do
        local reward ={}
        reward.id = _msg.legendReward[i].locationId
        reward.rewardId = _msg.legendReward[i].rewardId
        if _msg.legendReward[i].rewardId > 0 then
            reward.itemId = blessingRewardPool[_msg.legendReward[i].rewardId].Reward[1]
            reward.num = blessingRewardPool[_msg.legendReward[i].rewardId].Reward[2]
        else
            reward.itemId = 0
            reward.num = 0
        end
        reward.type = 3
        table.insert(this.legendReward,reward)
    end
    --for i = 1, #this.legendReward do
    
    --end
    for i = 1, #_msg.supremeReward do
        local reward ={}
        reward.id = _msg.supremeReward[i].locationId
        reward.rewardId = _msg.supremeReward[i].rewardId
        if _msg.supremeReward[i].rewardId > 0 then
            reward.itemId = blessingRewardPool[_msg.supremeReward[i].rewardId].Reward[1]
            reward.num = blessingRewardPool[_msg.supremeReward[i].rewardId].Reward[2]
        else
            reward.itemId = 0
            reward.num = 0
        end
        reward.type = 4
        table.insert(this.supremeReward,reward)
    end
    --for i = 1, #this.supremeReward do
    
    --end
    --6 个奖励  额外获得
    local extraRewardCounts = ConfigManager.GetConfigData(ConfigName.BlessingConfig,1).Counts
    for i = 1, #_msg.countReward do
        local reward ={}
        reward.id = _msg.countReward[i].locationId
        reward.rewardId = _msg.countReward[i].rewardId
        if _msg.countReward[i].rewardId > 0 then
            reward.itemId = blessingRewardPool[_msg.countReward[i].rewardId].Reward[1]
            reward.num = blessingRewardPool[_msg.countReward[i].rewardId].Reward[2]
        else
            reward.itemId = 0
            reward.num = 0
        end
        reward.extraRewardCount =  _msg.countReward[i].locationId
        table.insert(this.extraRewardData,reward)
    end
    table.sort(this.extraRewardData, function(a,b) return a.extraRewardCount < b.extraRewardCount end)
    --for i = 1, #this.extraRewardData do
    
    --end
    --this.patyRewardData = _msgPatyList
end
--设置云梦祈祷自选奖励
function this.SetPatyRewardData(rewardListData)
    local index = 1
    for i, v in pairs(rewardListData) do
        local reward ={}
        reward.id = index
        reward.rewardId = v.rewardId
        reward.itemId = v.itemId
        reward.num = v.num
        reward.state = 1
        this.patyRewardData[index] = reward
        index = index+1
    end
    this.patyPreviewRewardData = {}
    for i = 1, #this.patyRewardData do
        this.patyRewardData[i].state = 2

        --保存时 创建预览列表
        local reward ={}
        reward.id = this.patyRewardData[i].id
        reward.rewardId = this.patyRewardData[i].rewardId
        if this.patyRewardData[i].rewardId > 0 then
            reward.itemId = blessingRewardPool[this.patyRewardData[i].rewardId].Reward[1]
            reward.num = blessingRewardPool[this.patyRewardData[i].rewardId].Reward[2]
        else
            reward.itemId = 0
            reward.num = 0
        end
        reward.state = 2
        table.insert(this.patyPreviewRewardData,reward)
    end
end
--设置云梦祈祷翻牌
function this.SetPatySingleRewardData(rewardId,chooseRewardId)
    for i = 1, #this.patyRewardData do
        if this.patyRewardData[i].id == rewardId then
            this.patyRewardData[i].rewardId = chooseRewardId
            if blessingRewardPool[chooseRewardId] then
                this.patyRewardData[i].itemId = blessingRewardPool[chooseRewardId].Reward[1]
                this.patyRewardData[i].num = blessingRewardPool[chooseRewardId].Reward[2]
                
            end
            this.patyRewardData[i].state = 3
        end
    end
    for i = 1, #this.patyPreviewRewardData do
        if this.patyPreviewRewardData[i].rewardId == chooseRewardId then
            this.patyPreviewRewardData[i].state = 3
        end
    end
end
--重置云梦祈祷
function this.ResetPatyRewardData(_msg)
    this.InitializeData(_msg)
end
return this