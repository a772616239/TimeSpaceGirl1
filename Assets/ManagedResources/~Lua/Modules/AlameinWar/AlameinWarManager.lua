AlameinWarManager = {}
local this = AlameinWarManager



function this.Initialize()
    this.curFightCfgId = 0
    this.challengeTimes = 0
    this.residueBuyTimes = 0
    this.openedBoxs = {}
    this.stages = {}
    this.chapters = {}
    this.stagesById = {}

    this.boxStarNum = {10, 20, 30}
end

function AlameinWarManager.GetMaxChapterNum()
    return G_AlameinLevel[this.curFightCfgId].AlameinId
end

function AlameinWarManager.GetCurFightStageId()
    return this.curFightCfgId
end

function AlameinWarManager.InitData()
    
end

--> 请求主数据
function AlameinWarManager.RequestMainData(func)
    NetManager.AlameinBattleStageDataRequest(function(msg)
        this.curFightCfgId = msg.curFightCfgId
        this.challengeTimes = msg.challengeTimes
        this.residueBuyTimes = msg.residueBuyTimes
        this.openedBoxs = {}
        for i = 1, #msg.openedBoxs do
            local c = msg.openedBoxs[i].chapter
            if not this.openedBoxs[c] then
                this.openedBoxs[c] = {}
            end
            local bid = msg.openedBoxs[i].id
            this.openedBoxs[c][bid] = bid
        end
        this.stages = {}
        --> finished fight data
        if msg.stages and #msg.stages > 0 then
            for i = 1, #msg.stages do
                local _finishedStarIds = {}
                for j = 1, #msg.stages[i].finishedStarIds do
                    table.insert(_finishedStarIds, msg.stages[i].finishedStarIds[j])
                end
                table.insert(this.stages, {cfgId = msg.stages[i].cfgId, finishedStarIds = _finishedStarIds, alameinConfig = G_AlameinLevel[msg.stages[i].cfgId]})
            end
        end
        
        --> current fight data
        if this.curFightCfgId ~= -1 then    --< 最后一关打完 -1   todo
            table.insert(this.stages, {cfgId = this.curFightCfgId, finishedStarIds = {}, alameinConfig = G_AlameinLevel[this.curFightCfgId]})
        end
        
        table.sort(this.stages, function(a, b)
            return a.cfgId < b.cfgId
        end)

        this.chapters = {}
        this.stagesById = {}
        for i = 1, #this.stages do
            this.stagesById[this.stages[i].cfgId] = this.stages[i]

            local chapter = this.stages[i].alameinConfig.AlameinId
            if this.chapters[chapter] == nil then
                this.chapters[chapter] = {}
            end
            table.insert(this.chapters[chapter], this.stages[i])
        end

        if func then
            func(msg)
        end
    end)
end

--> 获取章节所有完成星星数
function AlameinWarManager.GetChapterStars(chapter)
    local stages = this.chapters[chapter]
    if stages == nil then
        LogError("GetChapterStars Error!")
        return 0
    end

    local totalStars = 0
    for i = 1, #stages do
        local stage = stages[i]
        totalStars = totalStars + #stage.finishedStarIds
    end
    return totalStars
end

--> 检测箱子是否开启了
function AlameinWarManager.CheckBoxIsOpend(boxid, chapter)
    local stages = this.chapters[chapter]
    if stages == nil then
        LogError("CheckBoxIsOpend Error!")
        return false
    end
    if this.openedBoxs[chapter] then
        if this.openedBoxs[chapter][boxid] then
            return true
        end
    end
    
    return false
end

--> 获取当前章节选中关
function AlameinWarManager.GetInitStageByChapter(chapter)
    local stages = this.chapters[chapter]
    if stages == nil then
        LogError("GetInitStageByChapter Error!")
        return nil
    end
    local stageid = nil
    if chapter == #this.chapters then
        stageid = stages[#stages].cfgId
    else
        stageid = stages[#stages].cfgId
    end

    return stageid
end

function AlameinWarManager.GetMaxChapter()
    return #this.chapters
end

--> 战斗
function AlameinWarManager.ExecuteFight(_fightId, callBack)
    --> fightInfo
    BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.ALAMEIN_WAR, G_AlameinLevel[_fightId].MonsterGroup)

    NetManager.FightStartRequest(BATTLE_TYPE.ALAMEIN_WAR, _fightId, function(msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg, nil)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.ALAMEIN_WAR, callBack, _fightId)
        end)
    end)
end

function AlameinWarManager.BuyTimesBtn()
    if AlameinWarManager.residueBuyTimes <= 0 then
        PopupTipPanel.ShowTip(GetLanguageStrById(10540))
        return
    end

    local x = PrivilegeManager.GetPrivilegeNumber(40001) - AlameinWarManager.residueBuyTimes --< 已购次数
    local cost = G_StoreConfig[10032].Cost
    local costNum = CalculateCostCount(x, unpack(cost[2], 1, #cost[2]))

    UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.AlameinBuy, function()
        local own = BagManager.GetItemCountById(tonumber(cost[1][1]))
        if own < costNum then
            PopupTipPanel.ShowTipByLanguageId(10854)
            return
        end

        NetManager.AlameinBattleChallengeTimesRequest(function()
            PopupTipPanel.ShowTipByLanguageId(10545)
            AlameinWarManager.challengeTimes = AlameinWarManager.challengeTimes + 1
            AlameinWarManager.residueBuyTimes = AlameinWarManager.residueBuyTimes - 1
            Game.GlobalEvent:DispatchEvent(GameEvent.AlameinWar.RefreshTimes)
        end)
    end, cost[1][1], string.format(GetLanguageStrById(12526), costNum))
end

return this