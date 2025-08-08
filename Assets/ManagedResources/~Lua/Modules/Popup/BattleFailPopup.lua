require("Base/BasePanel")
BattleFailPopup = Inherit(BasePanel)
local this = BattleFailPopup
local m_battlePanel
local m_showRecord = true
local m_backPanel
-- local orginLayer
local fightType
local drop
local leftPlayerHeadList
local rightPlayerHeadList
--初始化组件（用于子类重写）
function BattleFailPopup:InitComponent()
    -- orginLayer = 0
    this.btnClose = Util.GetGameObject(self.gameObject, "bg/closeBtn")
    -- this.closeBtn = Util.GetGameObject(self.gameObject,"Lose/closeBtn")
end

--绑定事件（用于子类重写）
function BattleFailPopup:BindEvent()
    Util.AddClick(this.btnClose, function ()
        if m_battlePanel then
            m_battlePanel:ClosePanel()
        end
        self:ClosePanel()

        if m_backPanel then
            UIManager.OpenPanel(m_backPanel)
        end
        this.ClosePanelRefreshData()
        if fightType ==BATTLE_TYPE.Ladders_Challenge then
            UIManager.ClosePanel(UIName.PlayerInfoPopup)
        end
    end)

    -- Util.AddClick(this.closeBtn, function ()
    --     if m_battlePanel then
    --         m_battlePanel:ClosePanel()
    --     end
    --     self:ClosePanel()

    --     if m_backPanel then
    --         UIManager.OpenPanel(m_backPanel)
    --     end
    --     this.ClosePanelRefreshData()
-- end)
        
        if fightType == BATTLE_TYPE.Ladders_Challenge then
             UIManager.ClosePanel(UIName.PlayerInfoPopup)
        end

    Util.AddClick(Util.GetGameObject(this.gameObject, "Lose/tip/zhaomu"), function ()
        FightManager.curIsInFightArea = 0
        this:LoseJump(1001)
        this.ClosePanelRefreshData()
    end)
    Util.AddClick(Util.GetGameObject(this.gameObject, "Lose/tip/peiyang"), function ()
        FightManager.curIsInFightArea = 0
        this:LoseJump(22001)
        this.ClosePanelRefreshData()
    end)
    Util.AddClick(Util.GetGameObject(this.gameObject, "Lose/tip/zhuangbei"), function ()
        FightManager.curIsInFightArea = 0
        this:LoseJump(23001)
        this.ClosePanelRefreshData()
    end)
    Util.AddClick(Util.GetGameObject(this.gameObject, "Lose/tip/shouhu"), function ()
        FightManager.curIsInFightArea = 0
        this:LoseJump(7901)
        this.ClosePanelRefreshData()
    end)
    Util.AddClick(Util.GetGameObject(this.gameObject, "Lose/beStrongBtn"), function ()
        UIManager.OpenPanel(UIName.GiveMePowerPanel)
    end)

    Util.AddClick(Util.GetGameObject(this.gameObject, "Lose/record"), function ()
        UIManager.OpenPanel(UIName.DamageResultPanel, 0)
        --this.ClosePanelRefreshData()
    end)
end

--添加事件监听（用于子类重写）
function BattleFailPopup:AddListener()

end

--移除事件监听（用于子类重写）
function BattleFailPopup:RemoveListener()

end

function BattleFailPopup:OnSortingOrderChange()
    -- Util.AddParticleSortLayer(this.btnClose, self.sortingOrder - orginLayer)
    -- orginLayer = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function BattleFailPopup:OnOpen(battlePanel, showRecord, backPanel,_fightType)
    if battlePanel then
        m_battlePanel = battlePanel
    end
    m_showRecord = true  -- 默认显示
    if showRecord  == false then
        m_showRecord = showRecord
    end
    m_backPanel = nil
    if backPanel then
        m_backPanel = backPanel
    end
    if _fightType then
        fightType = _fightType
    end
    FightPointPassManager.FightBattleEnd()
    Util.GetGameObject(this.gameObject, "Lose/record"):SetActive(m_showRecord)
    -- Util.GetGameObject(this.btnClose,"tip"):SetActive(not fightType == 12)--副本内无法点击招募

    -- Util.GetGameObject(this.btnClose,"Image/fail"):SetActive(not (fightType == BATTLE_TYPE.Ladders_Challenge))
    -- Util.GetGameObject(this.btnClose,"Image/laddersChallenge"):SetActive(fightType == BATTLE_TYPE.Ladders_Challenge)
    -- Util.GetGameObject(this.btnClose,"Image/Viewport"):SetActive(fightType == BATTLE_TYPE.Ladders_Challenge)

    if fightType == BATTLE_TYPE.Ladders_Challenge then
        UIManager.OpenPanel(UIName.RewardItemPopup, LaddersArenaManager.drop, 1,function()
            UIManager.ClosePanel(UIName.BattlePanel)
            UIManager.ClosePanel(UIName.PlayerInfoPopup)

            -- if m_battlePanel then
            --     m_battlePanel:ClosePanel()
            -- end
            self:ClosePanel()
        end, 8, true, true,nil,false)
        -- BattleFailPopup:SetLaddersData(drop)
    elseif fightType == BATTLE_TYPE.Climb_Tower then
        NetManager.VirtualBattleGetInfo()
    elseif fightType == BATTLE_TYPE.Climb_Tower_Advance then
        NetManager.VirtualElitBattleGetInfo()
    end
   
    Game.GlobalEvent:DispatchEvent( BattleEventName.BattleEndClearSceneRoles)
    Log("BattleEndClearSceneRoles")
end

function this:LoseJump(id)
    -- if not MapManager.isInMap then
        if JumpManager.CheckJump(id) then
            if m_battlePanel then
                m_battlePanel:ClosePanel()
            end
            self:ClosePanel()
            JumpManager.GoJumpWithoutTip(id)
        end
    -- else
        -- PopupTipPanel.ShowTipByLanguageId(10250)
    -- end
end

function  this.ClosePanelRefreshData()
    if fightType then
        if fightType == 8 then--远征
            local GetCurNodeInfo = ExpeditionManager.curAttackNodeInfo
            if GetCurNodeInfo.type == ExpeditionNodeType.Greed then--贪婪节点
                Game.GlobalEvent:DispatchEvent(GameEvent.Expedition.RefreshMainPanel)--刷新界面
                PopupTipPanel.ShowTip( GetLanguageStrById(12194))
            else
                MsgPanel.ShowTwo(GetLanguageStrById(11540), function()
                end, function()
                    NetManager.EndConfirmExpeditionBattleRequest(GetCurNodeInfo.sortId, function (msg)
                    end)
                end,GetLanguageStrById(10719),GetLanguageStrById(12201))
                Game.GlobalEvent:DispatchEvent(GameEvent.Expedition.RefreshMainPanel)--刷新界面
            end
        elseif fightType == 10 then--车迟
            --车迟抢夺cd计时
            GuildCarDelayManager.SetCdTime(GuildCarDelayProType.Loot)
        elseif fightType == BATTLE_TYPE.DefenseTraining then
            NetManager.DefTrainingGetInfo(function(msg) --拉数据
            end)
        end
    end
end
--界面关闭时调用（用于子类重写）
function BattleFailPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function BattleFailPopup:OnDestroy()

end

function BattleFailPopup:SetLaddersData(drop)
    this.laddersChallenge = Util.GetGameObject(self.gameObject,"Lose/Image/laddersChallenge")
    this.laddersLeftIcon = Util.GetGameObject(this.laddersChallenge,"leftIcon")
    this.laddersRightIcon = Util.GetGameObject(this.laddersChallenge,"rightIcon")

    local LeftName = Util.GetGameObject(this.laddersLeftIcon,"name")
    -- local LeftFlag = Util.GetGameObject(this.laddersLeftIcon,"flag")
    -- local LeftFlagScore = Util.GetGameObject(this.laddersLeftIcon,"flag/score")
    local LeftIntegral = Util.GetGameObject(this.laddersLeftIcon,"integral")
 
    local RightName = Util.GetGameObject(this.laddersRightIcon,"name")
    -- local RightFlag = Util.GetGameObject(this.laddersRightIcon,"flag")
    -- local RightFlagScore = Util.GetGameObject(this.laddersRightIcon,"flag/score")
    local RightIntegral = Util.GetGameObject(this.laddersRightIcon,"integral")
 
    --攻方
    if not leftPlayerHeadList then
        leftPlayerHeadList = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.laddersLeftIcon.transform)
    end
    leftPlayerHeadList:Reset()
    leftPlayerHeadList:SetScale(Vector3.one * 0.8)
    leftPlayerHeadList:SetHead(PlayerManager.head)
    leftPlayerHeadList:SetFrame(PlayerManager.frame)

    local newScore = LaddersArenaManager.newScore
    local score = LaddersArenaManager.GetMyRank()-newScore
    LeftName:GetComponent("Text").text = PlayerManager.nickName
    LeftIntegral:GetComponent("Text").text = GetLanguageStrById(12394)..LaddersArenaManager.GetMyRank()

    local defchange = LaddersArenaManager.defchange
    local data = LaddersArenaManager.enemy
    --守方
    if not rightPlayerHeadList then
        rightPlayerHeadList = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.laddersRightIcon.transform)
    end
    rightPlayerHeadList:Reset()
    rightPlayerHeadList:SetScale(Vector3.one * 0.8)
    rightPlayerHeadList:SetHead(data.personInfo.head)
    rightPlayerHeadList:SetFrame(data.personInfo.headFrame)
    RightName:GetComponent("Text").text = data.personInfo.name
    RightIntegral:GetComponent("Text").text = GetLanguageStrById(12394)..data.personInfo.rank

    this.dropGrid= Util.GetGameObject(self.gameObject, "Lose/Image/Viewport/Content")
    for i = 1, #drop.itemlist do 
        local view = SubUIManager.Open(SubUIConfig.ItemView, this.dropGrid.transform)
        local data = {}
        table.insert(data,drop.itemlist[i].itemId)
        table.insert(data,drop.itemlist[i].itemNum)
        view:OnOpen(false, data, 0.9)
    end
end

return BattleFailPopup