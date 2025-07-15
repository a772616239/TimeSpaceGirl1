--混乱之治管理
ChaosManager = {};

local this = ChaosManager
local challengeData ={}
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local foodsConfig = ConfigManager.GetConfig(ConfigName.FoodsConfig)
local  rewardConfig =  ConfigManager.GetConfig(ConfigName.CampWarRewardConfig)
local chanllengeRedState =false
local zhanBaoRedState   = false
local chanllengeStar = 1
local selectData={}  --点击挑战数据
local chaosTeams={}  --挑战选择后 防守阵容
local itemsData={}  --刷新挑战后数据
local selectBtn = 1 --选择按钮
local matchTimeID = 520
function this:Initialize()
    Log("_________________________  init")
    this.addCamp = 0
    this.lastMatchTime = 0
    this.zhanliTeamId = 1
    this.challengeNums = 0   
    this.challengeBuyNums = 0
    this.MyCampRank = 1   --我的阵营当前排名
end
function this:SetSelectBtnState(num)
    selectBtn = num
end
function this:GetSelectBtnState()
      return   selectBtn 
end
function this:SetChaosTeams(data)
    chaosTeams = data
end
function this:SetItemsData(data)
    itemsData = data
end
function this:GetItemsData()
    return itemsData
end
function this:GetChaosTeams()
   return chaosTeams
end
function this:SetSelectData(data)
        selectData=data
end
function this:GetSelectData()
   return selectData 
end
function this:SetChallegeStar(star)
    chanllengeStar = star
end
function this:GetChallegeStar()
   return chanllengeStar 
end
function this:SetChallegeRedState(state)
    chanllengeRedState = state
end
function this:GetChallegeRedState()
    return chanllengeRedState
end
function this:SetZhanBaoRedState(state)
    zhanBaoRedState = state
end
function this:GetZhanBaoRedState()
    return zhanBaoRedState
end
function this:SetChallegeData(data)
    this.challengeNums  = data.challengeNums
    this.challengeBuyNums = data.challengeBuyNums
    this.addCamp = data.selfCamp
    challengeData = data
end
function this:GetSpecialConfigData()
     return  specialConfig 
end
function this:GetChallegeData()
    return  challengeData 
end

function this:GetItemConfigData()
    return  itemConfig
end
function this:GetFoodsConfig()
    return  foodsConfig
end
--图片资源config
function this:GetArtResourcesConfigData()
    return  artResourcesConfig
end
function this:GetRewardConfigConfigData()
    return  rewardConfig
end
function this:GetIsOpen()
    local time =  ActTimeCtrlManager.GetActLeftTime(FUNCTION_OPEN_TYPE.ChaosZZ)
    if time > 0 then
        return true
    else
        PopupTipPanel.ShowTip(GetLanguageStrById(10029))
        return false
    end
 end
function this:UnitConversion(num)
    local number = num
   if number then
      number = number/10000
   end
   number = tonumber(string.format("%.2f", number))
   if number < 0.01 then
      return 0
   end
   return number.."万"
end
--混乱之治任务红点
function this.TaskRedPoint()
    local Data = TaskManager.GetChaosTaskData(TaskTypeDef.Chaos)
    for index, value in ipairs(Data) do
        if value.state  == 1 then
            return true
        end
    end
    return false
end
--红点
function this.ChanllegeRedPoint()
    local ChanllengeItem = 0      --可挑战
    if ChaosManager.addCamp == 0 then
        return  true
    end
     if this.TaskRedPoint() then
        return true
     end 
    --判断挑战红点
    local  Data = ChaosManager:GetChallegeData()
    for _i, _v in ipairs(Data.campWarPlayerInfos) do
        if  _v.fightResult == 0 then
            ChanllengeItem = 1
            break
        end
    end 
    local specialConfigData =   ChaosManager:GetSpecialConfigData()  
    local startTime =ChaosManager.lastMatchTime
    local endTime = math.floor(GetTimeStamp()- startTime)  --服务器当前时间  减去点击匹配时的时间
    if endTime >= specialConfigData[matchTimeID].Value+0  and Data.challengeNums ~=0 then
        return true
    end

    if Data.challengeNums >0 and ChanllengeItem ~= 0 then
        return true
    elseif ChaosManager.challengeNums > 0 and ChanllengeItem ~= 0 then
        return true
    else
        return false
    end
end

--> 战斗
function this:ExecuteFight(isSkip,callBack)     
   -- Log("selectData.userSimpleInfo.userId            ________    "..selectData.userSimpleInfo.userId)
  -- LogError("_______________hlzz     client   request ")
    NetManager.CampWarChallengeReq(selectData.userSimpleInfo.userId, chanllengeStar, function(msg)
       -- LogError("___________________hlzz   server   return")
        NetManager.CampWarInfoGetReq(function (msg)
            ChaosManager:SetChallegeData(msg)
           -- LogError("_____________challengeNums   "..msg.challengeNums)
        end)
        local data = ChaosManager:GetItemsData()
        for index, value in ipairs(data) do
                if value.userSimpleInfo.userId == selectData.userSimpleInfo.userId then
                    value.changeScore = msg.changeScore
                     
                    if msg.isWin then
                        value.fightResult = 1
                    else
                        value.fightResult = 2
                    end
                    break
           end
        end   
        ChaosManager:SetItemsData(data)
        local enemy =  ChaosManager:GetSelectData()
        local blueData ={}
        for i, v in ipairs(chaosTeams) do
            if v.uid == enemy.userSimpleInfo.userId then
                blueData = v
                break
            end
        end 
         -- 战斗信息
         local structA = {
            head = PlayerManager.head,
            headFrame = PlayerManager.frame,
            name = PlayerManager.nickName,
            formationId = FormationManager.GetFormationByID(FormationTypeDef.CHAOS_BATTLE_ACK).formationId,
            investigateLevel = FormationCenterManager.GetInvestigateLevel()
        }
        local structB = {
            head = enemy.userSimpleInfo.headIcon,
            headFrame = enemy.userSimpleInfo.headFrame,
            name = enemy.userSimpleInfo.nickName,
            formationId = blueData.team.formationId or 1,
            investigateLevel = blueData.investigateLevel
        }
        BattleManager.SetAgainstInfoData(nil, structA, structB)
        --Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.ScoreRewardUpdate)
        local result = 0
        local myScore = msg.changeScore 
        local battleScore = msg.changeScore 
        if msg.isWin then
            result = 1
            battleScore = -msg.changeScore
        else
            myScore = -msg.changeScore 
        end
        --构建显示结果数据
         local arg = {}
         arg.result =  result
         arg.blue = {}
         arg.blue.uid = PlayerManager.uid
         arg.blue.name = PlayerManager.nickName
         arg.blue.head = PlayerManager.head
         arg.blue.frame = PlayerManager.frame
         arg.blue.deltaScore = myScore
         arg.red= {}
         arg.red.uid = selectData.userSimpleInfo.userId
         arg.red.name = selectData.userSimpleInfo.nickName
         arg.red.head = selectData.userSimpleInfo.headIcon
         arg.red.frame = selectData.userSimpleInfo.headFrame
         arg.red.deltaScore = battleScore
          --调用回调事件，关闭编队界面
        if callBack then callBack(msg) end

        --- 判断是否要播放战斗回放
        local fightData = msg.battleRecord.fightData
           
        if isSkip == 0 then
            -- 播放完成后，打开结果界面
            this.RequestReplayRecord(result, fightData, nil,function()
                BattleRecordManager.SetBattleBothNameStr(PlayerManager.nickName.."|"..enemy.userSimpleInfo.nickName)
                UIManager.OpenPanel(UIName.ArenaResultPopup, arg)
               -- this.challengeNums = this.challengeNums - 1 
            end)
        else
            -- 设置战斗数据用于统计战斗
            local _fightData = BattleManager.GetBattleServerData({fightData = fightData}, 1)
            BattleRecordManager.SetBattleRecord(_fightData)
            BattleRecordManager.SetBattleBothNameStr(PlayerManager.nickName.."|"..enemy.userSimpleInfo.nickName)
            -- 不用回放直接显示结果
            UIManager.OpenPanel(UIName.ArenaResultPopup, arg)
        end
    end)
end
--- 请求开始播放回放
--- isWin 战斗结果 1 胜利 0 失败
--- fightData 战斗数据
--- nameStr 交战双方名称
--- doneFunc 战斗播放完成要回调的事件
function this.RequestReplayRecord(isWin, fightData, nameStr, doneFunc)
    BattleManager.GotoFight(function()
        UIManager.OpenPanel(UIName.BattleStartPopup, function()
            local fightData = BattleManager.GetBattleServerData({fightData = fightData}, 1)
            local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, doneFunc)
            battlePanel:ShowNameShow(isWin, nameStr)
        end)
    end)
end

return this
