XuanYuanMirrorManager = {};
local raceTowerConfig 
local raceTowerRewardConfig 
local this = XuanYuanMirrorManager
this.levelData = {}
this.buyTime = 0
this.freeTime = 0
this.buyTimeId = 0
this.freeTimeId = 0
this.curType = 0
function this.Initialize()
    raceTowerConfig = ConfigManager.GetConfig(ConfigName.RaceTowerConfig)
    raceTowerRewardConfig = ConfigManager.GetConfig(ConfigName.RaceTowerRewardConfig)
    local config = raceTowerConfig[1].Privilege
    this.buyTimeId= config[2]
    this.freeTimeId = config[1]
    this.InitMirrorData()
end

function this.InitMirrorData()
    this.levelData = {}
    for k,v in ConfigPairs(raceTowerConfig) do
        if not this.levelData[v.Type] then
            this.levelData[v.Type] = {}
            this.levelData[v.Type].data = {}
            --0未开启   1开启
            this.levelData[v.Type].state = 0
            this.levelData[v.Type].endingTime = 0
        end       
        local data={}
        data.id = v.Id 
        data.type = v.Type
        data.openLevel = v.IsShow
        data.difficulity = v.Quality
        data.teamRules = v.TeamRules
        --组队条件
        --data.condition = string.format(GetLanguageStrById(12248),data.teamRules[1][2],this.PropertyName(data.teamRules[1][1]))
        --战力
        data.power = v.FightForce
        data.rewardList = {}
        --概率奖励
        -- local tempConfig = ConfigManager.GetConfigData(ConfigName.RewardGroup,v.Reward[1])   
        -- if tempConfig.ShowItem then
        --     for i=1, #tempConfig.ShowItem do
        --         
        --         
        --         
        --         table.insert(data.rewardList,{id = tempConfig.ShowItem[i][1],num = tempConfig.ShowItem[i][2],israte = 0}) 
        --     end
        -- end

        --> 此处改为 只有两种  之前有概率  如果后端没改 有概率掉落 则会不一样
        if v.Reward and #v.Reward > 0 then
            for m = 1, #v.Reward do
                local tempConfig = ConfigManager.GetConfigData(ConfigName.RewardGroup,v.Reward[m])   
                if tempConfig.ShowItem then
                    for i=1, #tempConfig.ShowItem do
                        table.insert(data.rewardList,{id = tempConfig.ShowItem[i][1],num = tempConfig.ShowItem[i][2],israte = 1}) 
                    end
                end
            end
        end
        -- --扫荡奖励
        -- tempConfig = ConfigManager.GetConfigData(ConfigName.RewardGroup,v.Reward[2])   
        -- if tempConfig.ShowItem then
        --     for i=1, #tempConfig.ShowItem do
        --         table.insert(data.rewardList,{id = tempConfig.ShowItem[i][1],num = tempConfig.ShowItem[i][2],israte = 1}) 
        --     end
        -- end
        --首通奖励
        if v.FirstReward and #v.FirstReward > 0 then
            for m = 1, #v.FirstReward do
                local tempConfig = ConfigManager.GetConfigData(ConfigName.RewardGroup, v.FirstReward[m]) 
                if tempConfig.ShowItem then
                    for i=1, #tempConfig.ShowItem do
                        table.insert(data.rewardList,{id = tempConfig.ShowItem[i][1],num = tempConfig.ShowItem[i][2],israte = 2}) 
                    end
                end
            end
        end

        -- -1不显示   --0未开启   1挑战   2扫荡
        data.state = -1
        table.insert(this.levelData[v.Type].data,data)
    end
end

function this.CarbonRedCheck()
    if not ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.PEOPLE_MIRROR) then
        return false
    end
    this.GetTimeTip()
    if this.freeTime > 0 then
        return true
    end
    return false
end
function this.UpdateMirrorState(msg)
    if not msg.infos or #msg.infos < 1 then
        return
    end
    for k,v in pairs(this.levelData) do
        v.state = 0
    end

    for k,v in ipairs(msg.infos) do 
        if this.levelData[v.id] then
            this.levelData[v.id].state = 1
            this.levelData[v.id].endingTime = v.overTime 
            this.levelData[v.id].passId = v.passId or 0
            this.UpdateLevelState(v.id)
        end
    end
    -- for k,v in pairs(this.levelData) do
    --     for n,m in ipairs(v.data) do
    --     end
    -- end
end

function this.UpdateLevelState(type)
    if this.levelData[type] then
        table.sort(this.levelData[type].data,function(a,b)
            return a.difficulity < b.difficulity
        end)
        --local openLevel = 3
        for k,v in ipairs(this.levelData[type].data) do
            if v.id <= this.levelData[type].passId then
                v.state = 2
                --if v.id == this.levelData[type].passId then
                    --openLevel = v.openLevel
                --end
            else
                v.state = -1
            end
            --if v.difficulity <= openLevel then
                if v.state == -1 then
                    v.state = 0
                end
                if this.levelData[type].passId == 0 then
                    if v.difficulity == (this.levelData[type].passId + 1) then
                        v.state = 1
                    end
                else                    
                    if v.id == (this.levelData[type].passId + 1) then
                        v.state = 1
                    end
                end
            --end
        end
    end
end

function this.PropertyName(_type)
    _type = tonumber(_type)
    if _type == 1 then
        return GetLanguageStrById(11057)
    elseif _type == 2 then
        return GetLanguageStrById(12120)
    elseif _type == 3 then
        return GetLanguageStrById(12121)
    elseif _type == 4 then
        return GetLanguageStrById(12122)
    else
        return GetLanguageStrById(11057)
    end
end

--设置剩余次数
function this.GetTimeTip()
    this.buyTime = PrivilegeManager.GetPrivilegeRemainValue(this.buyTimeId) --可购买次数
    this.freeTime = PrivilegeManager.GetPrivilegeRemainValue(this.freeTimeId) --免费次数

    local str = ""
    if this.freeTime > 0 then
        str = string.format(GetLanguageStrById(10344),tostring(this.freeTime))
    else
        str = string.format(GetLanguageStrById(10345),tostring(this.buyTime))
    end
    return str
end

function this.GetBuyTimesTip()
    local config = raceTowerConfig[1].Privilege
    local rechargeCommodityConfig=ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,4003)
    local rechargeId =tonumber(rechargeCommodityConfig.OpenPrivilege[1]) 
    return PrivilegeManager.GetPrivilegeOpenStatusById(rechargeId)
end

function this.GetMirrorLevelData(_type)

    for k,v in ipairs(this.levelData) do
    end

    --type对应表里state不为-1的数据
    if this.levelData[_type] then
        local temp = {}
        for k,v in ipairs(this.levelData[_type].data) do
            if v.state ~= -1 then
                table.insert(temp,v)
            end
        end
        table.sort(temp,function(a,b)
            return a.id < b.id
        end)   
        return temp
    end
    return nil
end

function this.GetMirroData(_type)
    if this.levelData[_type] then        
        return this.levelData[_type]    
    end   
    return nil
end

function this.GetMirrorState(_type)
    if this.levelData[_type] then
        return this.levelData[_type].state
    end
    return 0
end

function this.GetMirrorEndTime(_type)
    if this.levelData[_type] then
        return this.levelData[_type].endingTime
    end
    return 0
end

function this.GetRewardView()
    local dataList = {}
    for k,v in ConfigPairs(raceTowerRewardConfig) do
        local data = {}
        if v.Section[1] == v.Section[2] then
            data.rank = v.Section[1]
        elseif v.Section[2] ~= -1 then
            data.rank = v.Section[1] - v.Section[2]
        else

        end
    end
end

--开始战斗
function this.ExecuteFightBattle(id,type,func)
    NetManager.StartSituationChallengeRequest(id,type,function(msg)
        if type == 1 then
            --> fightInfo
            UIManager.OpenPanel(UIName.BattleStartPopup, function ()
                BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.REDCLIFF, G_RaceTowerConfig[id].MonsterId)
                local fightData = BattleManager.GetBattleServerData(msg,0)
                UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.REDCLIFF,function(result)
                    if func then
                        func()
                    end
                    if msg.fightResult == 0 then
                        -- if this.levelData[this.curType].state == 1 then 
                        --     UIManager.OpenPanel(UIName.XuanYuanMirrorPanelList,this.curType) 
                        -- else
                        --     UIManager.OpenPanel(UIName.XuanYuanMirrorPanel)
                        -- end
                    elseif msg.fightResult == 1 then
                        this.levelData[this.curType].passId = id
                        this.UpdateLevelState(this.curType)
                        PrivilegeManager.RefreshPrivilegeUsedTimes(XuanYuanMirrorManager.freeTimeId, 1)
                        CheckRedPointStatus(RedPointType.People_Mirror)
                    --     if this.levelData[this.curType].state == 1 then 
                    --         UIManager.OpenPanel(UIName.XuanYuanMirrorPanelList,this.curType)
                    --     else
                    --         UIManager.OpenPanel(UIName.XuanYuanMirrorPanel)
                    --     end
                        UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                        end)
                    end
                end)
            end)
        else
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                if func then
                    func()
                end
            end)
        end      
    end)
end

return this