require("Base/BasePanel")
BattleWinPopup = Inherit(BasePanel)
local this = BattleWinPopup
local m_isBack
local m_battlePanel
local m_fightType
local m_battleResult
local m_notShowRecord = false
local m_backPanel
local orginLayer
local m_callBack
local hadClick = false

--初始化组件（用于子类重写）
function BattleWinPopup:InitComponent()
    orginLayer = 0
end

--绑定事件（用于子类重写）
function BattleWinPopup:BindEvent()
end

--添加事件监听（用于子类重写）
function BattleWinPopup:AddListener()
end

--移除事件监听（用于子类重写）
function BattleWinPopup:RemoveListener()
end

function BattleWinPopup:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.btnWin, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function BattleWinPopup:OnOpen(battlePanel, isBack, fightType, result, showRecord, backPanel, func)
    if UIManager.IsOpen(UIName.PublicGetHeroPanel) then
        UIManager.ClosePanel(UIName.PublicGetHeroPanel)
    end
    
    hadClick = false
    if battlePanel then
        m_battlePanel = battlePanel
    end
    if isBack ~= nil then
        m_isBack = isBack
    end
    if fightType then
        m_fightType = fightType
    end
    if result then
        m_battleResult = result
    end
    m_notShowRecord = false
    if showRecord then
        m_notShowRecord = showRecord
    end
    m_backPanel = nil
    if backPanel then
        m_backPanel = backPanel
    end
    m_callBack = nil
    if func then
        m_callBack = func
    end

    -- 闪闪闪，一闪而过，舒服的一批
    Timer.New(function()
        self:NextStep()
    end, 0.1):Start()
end

--界面关闭时调用（用于子类重写）
function BattleWinPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function BattleWinPopup:OnDestroy()
end

-- 
function BattleWinPopup:NextStep()
    if not hadClick then -- 避免重复结算
        hadClick = true
        if m_isBack then
            if m_battlePanel then
                m_battlePanel:ClosePanel()
            end
            self:ClosePanel()
            return
        end

        if m_fightType == BATTLE_TYPE.MAP_FIGHT then
            -- UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 2, function()
            MapManager.DropAddShotTimeBag(m_battleResult.drop)
            UIManager.OpenPanel(UIName.BattleEndPanel, m_battlePanel, m_battleResult.hpList, m_battleResult.drop, function() m_battlePanel:ClosePanel() self:ClosePanel() end, true)
            -- end)
        elseif m_fightType == BATTLE_TYPE.ELITE_MONSTER then
            UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function() m_battlePanel:ClosePanel() self:ClosePanel() end, 1, true)
        elseif m_fightType == BATTLE_TYPE.MONSTER_CAMP then
            if m_battlePanel then
                m_battlePanel:ClosePanel()
            end
            self:ClosePanel()
            if m_backPanel then
                UIManager.OpenPanel(m_backPanel)
            end
            UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                if m_callBack then m_callBack() end
            end, nil, not m_notShowRecord)
        elseif m_fightType == BATTLE_TYPE.STORY_FIGHT then
            FightPointPassManager.FightBattleEnd()
            FightPointPassManager.OnBattleEnd(m_battleResult)
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                        if _BattleBestPopup then
                            _BattleBestPopup:ClosePanel()
                        end
                        if m_battlePanel then
                            m_battlePanel:ClosePanel()
                        end
                        self:ClosePanel()
                    end, 1, true, true,nil,false, nil, m_fightType)
                end)
            else
                -- 打开关卡奖励界面
                UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                    if m_battlePanel then
                        m_battlePanel:ClosePanel()
                    end
                    self:ClosePanel()
                end, 1, true, nil, nil, nil, nil, m_fightType)
            end
        elseif m_fightType == BATTLE_TYPE.EXECUTE_FIGHT then
            self:ClosePanel()
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                local GetCurNodeInfo = ExpeditionManager.curAttackNodeInfo--ExpeditionManager.GetCurNodeInfo()
                local func2 = nil
                if GetCurNodeInfo.type == ExpeditionNodeType.Trail then--试炼节点
                    func2 = function()
                        Game.GlobalEvent:DispatchEvent(GameEvent.Expedition.RefreshPlayAniMainPanel)
                    end
                end
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    --贪婪节点不弹领取圣物
                    if GetCurNodeInfo.type == ExpeditionNodeType.Greed then--贪婪节点
                        if m_battleResult.drop.itemlist and #m_battleResult.drop.itemlist > 0 then
                        else
                        end
                        UIManager.OpenPanel(UIName.RewardItemPopup,m_battleResult.drop, 1,function()
                            if m_battlePanel then
                                m_battlePanel:ClosePanel()
                            end
                            if _BattleBestPopup then
                                _BattleBestPopup:ClosePanel()
                            end
                            Game.GlobalEvent:DispatchEvent(GameEvent.Expedition.RefreshPlayAniMainPanel)
                        end, 0,true,true)
                    elseif GetCurNodeInfo.type == ExpeditionNodeType.Trail then--试炼节点
                        if m_battleResult.drop and m_battleResult.drop.Hero and m_battleResult.drop.Hero[1] then
                            ExpeditionManager.UpdateHeroDatas(m_battleResult.drop.Hero[1])
                        else

                        end
                        if m_battlePanel then
                            m_battlePanel:ClosePanel()
                        end
                        PopupTipPanel.ShowTipByLanguageId(12192)
                    else
                        UIManager.OpenPanel(UIName.RewardItemPopup,m_battleResult.drop, 1,function()
                            if m_battlePanel then
                                m_battlePanel:ClosePanel()
                            end
                            if _BattleBestPopup then
                                _BattleBestPopup:ClosePanel()
                            end
                            if GetCurNodeInfo.holyEquipID and #GetCurNodeInfo.holyEquipID > 0 then
                                UIManager.OpenPanel(UIName.ExpeditionSelectHalidomPanel,true,function ()
                                end)
                            else
                                --此时战斗了但没有圣物 所有直接刷新界面动画 后并刷新界面
                                Game.GlobalEvent:DispatchEvent(GameEvent.Expedition.RefreshPlayAniMainPanel)
                            end
                        end, 0,true,true,nil,false)
                    end
                end,func2)
            end
        elseif m_fightType == BATTLE_TYPE.DAILY_CHALLENGE
            or m_fightType == BATTLE_TYPE.REDCLIFF
            or m_fightType == BATTLE_TYPE.CollectMaterials
            then
            m_battlePanel:ClosePanel()
            self:ClosePanel()
        elseif m_fightType == BATTLE_TYPE.GUILD_CAR_DELAY then
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup,nil, 1,function()
                        --车迟抢夺cd计时
                        GuildCarDelayManager.SetCdTime(GuildCarDelayProType.Loot)
                        if _BattleBestPopup then
                            _BattleBestPopup:ClosePanel()
                        end
                        if m_battlePanel then
                            m_battlePanel:ClosePanel()
                        end
                        self:ClosePanel()
                    end, 3,true,true,nil,false)
                end)
            end
        elseif m_fightType == BATTLE_TYPE.Climb_Tower then
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    NetManager.VirtualBattleGetInfo(function()
                        -- 打开关卡奖励界面
                        UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                            if _BattleBestPopup then
                                _BattleBestPopup:ClosePanel()
                            end
                            if m_battlePanel then
                                m_battlePanel:ClosePanel()
                            end
                            self:ClosePanel()
                        end, 0, true, true,nil,false, nil, m_fightType)
                    end)
                end)
            else
                NetManager.VirtualBattleGetInfo(function()
                    -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                        if m_battlePanel then
                            m_battlePanel:ClosePanel()
                        end
                        self:ClosePanel()
                    end, 0, true, nil, nil, nil, nil, m_fightType)
                end)
            end
        elseif m_fightType == BATTLE_TYPE.Climb_Tower_Advance then
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- 打开关卡奖励界面
                    NetManager.VirtualElitBattleGetInfo(function()
                        ClimbTowerManager.GetRankData(function()
                            UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                                if _BattleBestPopup then
                                    _BattleBestPopup:ClosePanel()
                                end
                                if m_battlePanel then
                                    m_battlePanel:ClosePanel()
                                end
                                self:ClosePanel()
                            end, 0, true, true,nil,false, nil, BATTLE_TYPE.Climb_Tower_Advance)
                        end, ClimbTowerManager.ClimbTowerType.Advance)
                    end)
                end)
            else
                -- 打开关卡奖励界面
                NetManager.VirtualElitBattleGetInfo(function()
                    ClimbTowerManager.GetRankData(function()
                        UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                            if m_battlePanel then
                                m_battlePanel:ClosePanel()
                            end
                            self:ClosePanel()
                        end, 0, true)
                    end, ClimbTowerManager.ClimbTowerType.Advance)
                end)
            end
        elseif m_fightType == BATTLE_TYPE.DefenseTraining then
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- 打开关卡奖励界面
                    NetManager.DefTrainingGetInfo(function(msg) --拉数据
                        UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                            if _BattleBestPopup then
                                _BattleBestPopup:ClosePanel()
                            end
                            if m_battlePanel then
                                m_battlePanel:ClosePanel()
                            end
                            self:ClosePanel()
                        end, 0, true, true,nil,false, nil, BATTLE_TYPE.DefenseTraining)
                    end)
                end)
            else
                -- 打开关卡奖励界面
                NetManager.DefTrainingGetInfo(function(msg)
                    UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                        if m_battlePanel then
                            m_battlePanel:ClosePanel()
                        end
                        self:ClosePanel()
                    end, 0, true, nil, nil, nil, nil, BATTLE_TYPE.DefenseTraining)
                end)
            end
        elseif m_fightType == BATTLE_TYPE.BLITZ_STRIKE then
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                        NetManager.BlitzInfo(function(msg)
                            NetManager.BlitzTypeInfo(function()
                                if _BattleBestPopup then
                                    _BattleBestPopup:ClosePanel()
                                end
                                if m_battlePanel then
                                    m_battlePanel:ClosePanel()
                                end
                                self:ClosePanel()
        
                                if BlitzStrikePreFightPopup then
                                    BlitzStrikePreFightPopup:ClosePanel()
                                end
                                if BlitzStrikePanel then
                                    BlitzStrikePanel.UpdateMain()
                                end
                            end)
                        end)
                    end, 0, true, true,nil,false)
                end)
            else
                -- 打开关卡奖励界面
                UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                    NetManager.BlitzInfo(function(msg)
                        NetManager.BlitzTypeInfo(function()
                            if m_battlePanel then
                                m_battlePanel:ClosePanel()
                            end
                            self:ClosePanel()
                            if BlitzStrikePreFightPopup then
                                BlitzStrikePreFightPopup:ClosePanel()
                            end
                            if BlitzStrikePanel then
                                BlitzStrikePanel.UpdateMain()
                            end
                        end)
                    end)
                end, 0, true)
            end
        elseif m_fightType == BATTLE_TYPE.CONTEND_HEGEMONY then
            Timer.New(function()
                local bestData, allDamage = BattleRecordManager.GetBattleBestData()
                if bestData then
                    --胜利显示本场比赛的表现最好的英雄
                    UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                        -- 打开关卡奖励界面
                        UIManager.OpenPanel(UIName.RewardItemPopup,false, 1,function()
                            if _BattleBestPopup then
                                _BattleBestPopup:ClosePanel()
                            end
                            UIManager.ClosePanel(UIName.HegemonyPopup)
                            UIManager.ClosePanel(UIName.BattlePanel)
                            this:ClosePanel()
                        end,7,true,true,nil,false,HegemonyManager.curFightId)
                    end)
                end
            end, 0.1):Start()
        elseif m_fightType == BATTLE_TYPE.ALAMEIN_WAR then
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                        AlameinWarManager.RequestMainData(function()
                            AlameinWarStagePanel.UpdateMain(true)
                            if _BattleBestPopup then
                                _BattleBestPopup:ClosePanel()
                            end
                            if m_battlePanel then
                                m_battlePanel:ClosePanel()
                            end
                            self:ClosePanel()
                        end)
                    end, 0, true, true,nil,false)
                end)
            else
                -- 打开关卡奖励界面
                UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                    AlameinWarManager.RequestMainData(function()
                        AlameinWarStagePanel.UpdateMain(true)
                        if m_battlePanel then
                            m_battlePanel:ClosePanel()
                        end
                        self:ClosePanel()
                    end)
                end, 0, true)
            end
        elseif m_fightType == BATTLE_TYPE.Ladders_Challenge then
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup, LaddersArenaManager.drop, 1,function()
                        UIManager.ClosePanel(UIName.PlayerInfoPopup)
                        if _BattleBestPopup then
                            _BattleBestPopup:ClosePanel()
                        end
                        if m_battlePanel then
                            m_battlePanel:ClosePanel()
                        end
                        self:ClosePanel()
                    end, 8, true, true,nil,false)
                end)
            else
                -- 打开关卡奖励界面
                UIManager.OpenPanel(UIName.RewardItemPopup,LaddersArenaManager.drop, 1,function()
                    if m_battlePanel then
                        m_battlePanel:ClosePanel()
                    end
                    self:ClosePanel()
                end, 8, true, true,nil,false)
            end
        elseif m_fightType == BATTLE_TYPE.PVEActivity then
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                        if _BattleBestPopup then
                            _BattleBestPopup:ClosePanel()
                        end
                        if m_battlePanel then
                            m_battlePanel:ClosePanel()
                        end
                        self:ClosePanel()
                    end, 0, true, true,nil,false)
                end)
            else
                -- 打开关卡奖励界面
                UIManager.OpenPanel(UIName.RewardItemPopup, m_battleResult.drop, 1,function()
                    if m_battlePanel then
                        m_battlePanel:ClosePanel()
                    end
                    self:ClosePanel()
                end, 0, true, true,nil,false)
            end
        end
    end
end

return BattleWinPopup