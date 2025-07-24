require("Base/BasePanel")
FightPointPassMainPanel = Inherit(BasePanel)
local this = FightPointPassMainPanel
local invadeMonster = require("Modules/Fight/View/InvadeMonsterView")
local fightOnHook = require("Modules/Fight/View/FightPointMapOnHook")
local chatPanel = require("Modules/Fight/View/FightPointMapChatPanel")
local fightLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local fightLevelSetConfig = ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local activityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
-- local points = {}
local isCounting = false
local orginLayer = 0
local hasLoad = false
this.funcBtnList = {}
local curMianTaskData = {}
local timePressStarted
local callBack
local worldLevel = 0--世界等级

--初始化组件（用于子类重写）
function FightPointPassMainPanel:InitComponent()
    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    this.battleSceneLogicGameObject, this.battleSceneGameObject = BattleManager.CreateBattleScene(nil)--创建战场Prefab

    invadeMonster:InitComponent(self.gameObject, this)
    fightOnHook:InitComponent(self.gameObject, this, this.battleSceneLogicGameObject, this.battleSceneGameObject)
    chatPanel:InitComponent(Util.GetGameObject(self.gameObject, "Bg/ChatPanel"), this)


    this.btnDailyMission = Util.GetGameObject(self.gameObject, "Bg/btnGroup/btnDailyMission")--任务
    this.btnRank = Util.GetGameObject(self.gameObject, "Bg/btnGroup/btnRank")--排行
    this.btnLevelInfo = Util.GetGameObject(self.gameObject,"Bg/btnGroup/btnLevelInfo")--记录
    this.dailyRedPoint = Util.GetGameObject(this.btnDailyMission, "redPoint")--任务红点

    this.funcBtnList[12] = this.btnDailyMission

    this.chapterName = Util.GetGameObject(self.gameObject, "Bg/btnArea/chapterName"):GetComponent("Text")--章节名

    -- 挂机奖励
    this.rewardList = {}
    this.getBoxReward = Util.GetGameObject(self.gameObject,"Bg/getBoxReward")
    for i = 1, 4 do
        local go = {}
        go.icon = Util.GetGameObject(this.getBoxReward,"profits/pro" .. i):GetComponent("Image")
        go.num = Util.GetGameObject(this.getBoxReward,"profits/pro" .. i .. "/Text"):GetComponent("Text")
        this.rewardList[i] = go
    end
    this.hangOnTime = Util.GetGameObject(self.gameObject,"Bg/getBoxReward/time"):GetComponent("Text")
    this.slider = Util.GetGameObject(self.gameObject,"Bg/getBoxReward/fill"):GetComponent("Image")

    this.btnFight = Util.GetGameObject(self.gameObject, "Bg/btnDown/btnFight")--战斗
    this.fightRedPoint = Util.GetGameObject(this.btnFight, "redPoint")--战斗红点
    this.fightLock = Util.GetGameObject(this.btnFight, "lock")--战斗锁定
    this.lockText = Util.GetGameObject(this.fightLock, "Text"):GetComponent("Text")

    FightPointPassManager.GetLastFightID()
    --探索
    this.RightUpVertical = Util.GetGameObject(self.gameObject, "Bg/RightUpVertical")
    this.btnFindTreasure = Util.GetGameObject(this.RightUpVertical, "btnFindTreasure")--优化
    this.btnFindTreasureText = Util.GetGameObject(this.RightUpVertical, "btnFindTreasure/num"):GetComponent("Text")
    this.btnFindTreasureredPoint = Util.GetGameObject(this.RightUpVertical, "btnFindTreasure/redPoint")
    this.RightUpVerticalPos = Util.GetGameObject(self.gameObject, "Bg/RightUpVerticalPos").transform.localPosition

    -- 开服福利
    this.btnBox = Util.GetGameObject(self.gameObject, "Bg/box")
    this.btnOpenSeverWelfare = Util.GetGameObject(self.gameObject, "Bg/box/btnOpenSeverWelfare")
    this.OpenSeverWelfare = Util.GetGameObject(this.btnOpenSeverWelfare, "bg")
    this.OpenSeverWelfareIcon = Util.GetGameObject(this.OpenSeverWelfare, "icon"):GetComponent("Image")
    -- this.OpenSeverWelfareiconText = Util.GetGameObject(this.OpenSeverWelfare, "iconText"):GetComponent("Image")
    this.OpenSeverWelfareTimeText = Util.GetGameObject(this.OpenSeverWelfare, "time"):GetComponent("Text")
    this.OpenSeverWelfareInfoText = Util.GetGameObject(this.OpenSeverWelfare, "info"):GetComponent("Text")
    this.OpenSeverWelfareInfoSlider = Util.GetGameObject(this.OpenSeverWelfare, "Slider"):GetComponent("Slider")
    this.OpenSeverWelfareFrame = Util.GetGameObject(this.btnOpenSeverWelfare, "bg/frame"):GetComponent("Image")
    this.OpenSeverWelfareName = Util.GetGameObject(this.btnOpenSeverWelfare, "bg/name"):GetComponent("Text")
    this.OpenSeverWelfareGetEffect = Util.GetGameObject(this.btnOpenSeverWelfare, "getEffect")
    
    this.btnRewardOnline = Util.GetGameObject(self.gameObject, "Bg/box/btnRewrdOnline")
    this.btnRewardOnlinePos = Util.GetGameObject(self.gameObject, "Bg/btnRewrdOnlinePos").transform.position
    this.OpenSeverWelfareRedpot = Util.GetGameObject(this.btnOpenSeverWelfare, "redpot")

    this.chatBox = Util.GetGameObject(self.gameObject, "Bg/ChatPanel/Box/box")

    this.battleGuideFinger = Util.GetGameObject(this.btnFight, "tipButtom")--闯关引导
    this.taskGuideFinger = Util.GetGameObject(this.BtView.gameObject, "Down/btnMainCity/tipButtom")--主城引导

    this.btnWorldLevel = Util.GetGameObject(self.gameObject, "Bg/btnWorldLevel")--世界等级
    this.btnWorldLevelPos = this.btnWorldLevel:GetComponent("RectTransform").localPosition
    this.worldLevel = Util.GetGameObject(self.gameObject, "Bg/btnWorldLevel/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function FightPointPassMainPanel:BindEvent()
    invadeMonster:BindEvent()
    chatPanel:BindEvent()

    -- 日常任务
    Util.AddClick(this.btnDailyMission, function ()
        FightPointPassManager.isBeginFight = true
        UIManager.OpenPanel(UIName.MissionDailyPanel)
    end)

    -- 关卡排行
    Util.AddClick(this.btnRank, function ()
        --PopupTipPanel.ShowTip("关卡排行！")
        FightPointPassManager.isBeginFight = true
        --UIManager.OpenPanel(UIName.FightPointPassRankPopup)
        UIManager.OpenPanel(UIName.RankingSingleListPanel,RankKingList[1])
    end)

    -- 挂机奖励
    Util.AddClick(this.btnrewardDetail, function ()
        UIManager.OpenPanel(UIName.FightAreaRewardPopup)
    end)

    Util.AddClick(this.btnFight, function ()
        --> battlePanelBehind
        BattleManager.isFightBack = false
        if BattleManager.IsInBackBattle() then
            local battlePanelGo = UIManager.uiNode.transform:Find("BattlePanel").gameObject
            if not battlePanelGo.activeSelf then
                -- UIManager.OpenPanel(UIName.BattlePanel)
                UIManager.OpenPanel(UIName.LoadingPopup)
                SoundManager.SetBattleVolume(1)
                return
            end
        end
        this.ExcuteBattle()
        SoundManager.SetBattleVolume(1)
    end)

    Util.AddClick(this.btnLevelInfo,function ()
        NetManager.GetLevelInfoData(FightPointPassManager.curOpenFight,function (msg)
            UIManager.OpenPanel(UIName.FightRecordPopup,msg)
        end)
    end)

    --寻宝
    Util.AddClick(this.btnFindTreasure,function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.FINDTREASURE) then
            UIManager.OpenPanel(UIName.FindTreasureMainPanel)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.FINDTREASURE))
        end
    end)

    Util.AddClick(Util.GetGameObject(this.btnOpenSeverWelfare, "btn"), function()
        UIManager.OpenPanel(UIName.OpenSeverWelfarePanel)
    end)

    Util.AddClick(this.btnExpedition,function ()
        if ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.ENDLESS) then
            if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ENDLESS) then
                NetManager.MapInfoListRequest(function (msg)
                    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.ENDLESS)
                    PlayerPrefs.SetInt("WuJin1"..PlayerManager.uid,serData.endTime)
                    -- CheckRedPointStatus(RedPointType.EndlessPanel)
                    MapManager.curCarbonType = CarBonTypeId.ENDLESS
                    MapManager.SetViewSize(3)--设置视野范围（明雷形式）
                    MapManager.isTimeOut = false 
                    UIManager.OpenPanel(UIName.EndLessCarbonPanel,msg.info)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10281)
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ENDLESS))
        end
    end)

    Util.AddClick(this.btnWorldLevel, function ()
        UIManager.OpenPanel(UIName.HelpPopup, nil, this.btnWorldLevelPos.x, this.btnWorldLevelPos.y, string.format(GetLanguageStrById(50237), worldLevel))
    end)
    BindRedPointObject(RedPointType.DailyTaskMain, this.dailyRedPoint)
    BindRedPointObject(RedPointType.VipPrivilege, this.vipRedPoint)
    BindRedPointObject(RedPointType.SecretTer_IsCanFight, this.fightRedPoint)
end

function this.SetInitAnim()
    fightOnHook:StopAction()

    UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.STORY, FightPointPassManager.curOpenFight)
end

--添加事件监听（用于子类重写）
function FightPointPassMainPanel:AddListener()
    invadeMonster:AddListener()
    chatPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionOpen, this.BtnsIsOpen)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.UpdateFindTreasureMaterialNum)
    Game.GlobalEvent:AddEvent(GameEvent.FindTreasure.RefreshFindTreasureRedPot, this.RefreshFindTreasureRedPoint)
    Game.GlobalEvent:AddEvent(GameEvent.Mission.GetOpenServerRewardRefreshFightPoint, this.UpdateOpenSeverWelfare)
    Game.GlobalEvent:AddEvent(GameEvent.Battle.OnBattleUIEnd, this.RefreshFightBtn)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnLevelChange,this.RefreshFightBtn)
end

--移除事件监听（用于子类重写）
function FightPointPassMainPanel:RemoveListener()
    invadeMonster:RemoveListener()
    chatPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.FunctionCtrl.OnFunctionOpen, this.BtnsIsOpen)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.UpdateFindTreasureMaterialNum)
    Game.GlobalEvent:RemoveEvent(GameEvent.FindTreasure.RefreshFindTreasureRedPot, this.RefreshFindTre3asureRedPoint)
    Game.GlobalEvent:RemoveEvent(GameEvent.Mission.GetOpenServerRewardRefreshFightPoint, this.UpdateOpenSeverWelfare)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnShowBattleUpLvTip, this.RefreshBattleUpLvTip)
    Game.GlobalEvent:RemoveEvent(GameEvent.Battle.OnBattleUIEnd, this.RefreshFightBtn)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnLevelChange,this.RefreshFightBtn)
end

--界面打开时调用（用于子类重写）
function FightPointPassMainPanel:OnOpen(func)
    this.PlayerHeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.FightPointPass })
    this.BtView:OnOpen({ sortOrder = self.sortingOrder + 50, panelType = PanelTypeView.JieLing })
    callBack = nil
    if func then
        callBack = func
    end
end

local _TabImage = {
    [1] = {"cn2-X1_guaji_liaotiantubiao_01"},
    [2] = {"cn2-X1_guaji_liaotiantubiao_02"},
    [3] = {"cn2-X1_guaji_liaotiantubiao_03"},
    [4] = {"cn2-X1_guaji_liaotiantubiao_04"}
}

-- tab节点自定义设置
function this.TabAdapter(tab, index, status)
    Util.GetGameObject(tab, "Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabImage[index])
    Util.GetGameObject(tab, "select"):SetActive(status == "select")

    local redpot = Util.GetGameObject(tab, "redpot")
    if ChatManager._TabData[index].rpType then
        BindRedPointObject(ChatManager._TabData[index].rpType, redpot)
    else
        redpot:SetActive(false)
    end
end

-- 从战斗出来会加载两次
function FightPointPassMainPanel:OnShow()
    CheckRedPointStatus(RedPointType.QuickTrain)
    if this.battleSceneLogicGameObject ~= nil then
        this.battleSceneLogicGameObject:SetActive(true)
    end
    if this.battleSceneGameObject ~= nil then
        this.battleSceneGameObject:SetActive(true)
    end

    if FightPointPassManager.GetIsOpenRewardUpTip() then
        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Onhook)
    end

    --如果关卡未解锁,就跳过章节
    if not FightPointPassManager.IsChapterClossState() then
        FightPointPassManager.SetChapterOpenState(false)
    end

    this.btnWorldLevel:SetActive(ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.WorldLevel))
    NetManager.WorldArenaUnLockRequest(function (msg)
        worldLevel = msg.worldLevel
        this.worldLevel.text = "Lv"..worldLevel
    end)

    SoundManager.PlayMusic(SoundConfig.BGM_Main)
    

    if not hasLoad then
        timePressStarted = Time.realtimeSinceStartup
        this.chapterName.text = fightLevelConfig[FightPointPassManager.curOpenFight].Name
        this.IntiReward()
        isCounting = false
        fightOnHook:Init()
        chatPanel:OnShow()

        FightPointPassManager.isBattleBack = false
        hasLoad = true

        this:Update()
        -- this.FreshVip()

        if callBack then
            callBack()
            callBack = nil
        end
    end

    local loadMapName = fightLevelConfig[FightPointPassManager.curOpenFight].BG
    if this.mapName ~= loadMapName then
        this.mapName = loadMapName
        if this.mapGameObject ~= nil then
            GameObject.Destroy(this.mapGameObject)
        end
        this.mapGameObject = BattleManager.CreateMap(this.battleSceneGameObject, loadMapName)
        fightOnHook:UpdateMap(this.mapGameObject)
    end

    this.BtnsIsOpen()
    this.UpdateFindTreasureMaterialNum()
    this.UpdateOpenSeverWelfare()
    this.RefreshFightBtn()
    this.ShowGuide()
    -- 调用onshow
    invadeMonster:OnShow()
end

local fightBtnSprite = {
    GetPictureFont("cn2-X1_guaji_zhandouzhong"),
    GetPictureFont("cn2-X1_guaji_bosszhan"),
    GetPictureFont("cn2-X1_guaji_zhandou")
}

--刷新战斗按钮
function this.RefreshFightBtn()
    local btnFightBg = Util.GetGameObject(this.btnFight, "Image"):GetComponent("Image")
    if BattleManager.IsInBackBattle() then
        btnFightBg.sprite = Util.LoadSprite(fightBtnSprite[1])
        this.fightLock:SetActive(false)
    else
        if fightLevelConfig[FightPointPassManager.curOpenFight].BossShow == 1 then
            btnFightBg.sprite = Util.LoadSprite(fightBtnSprite[2])
        else
            btnFightBg.sprite = Util.LoadSprite(fightBtnSprite[3])
        end
        this.SetFightBtnText()
    end
end

-- 设置挑战按钮文字
function this.SetFightBtnText()
    this.fightLock:SetActive(false)
    local isPass = FightPointPassManager.IsCanFight(FightPointPassManager.curOpenFight)
    if not isCounting then
        if not isPass then
            this.fightLock:SetActive(true)
            this.lockText.text = FightPointPassManager.GetBtnText()
        end
    end
end

--探索显示
function this.UpdateFindTreasureMaterialNum()
    this.btnFindTreasure:SetActive(ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.FINDTREASURE))
    this.btnFindTreasureText.text = BagManager.GetItemCountById(FindTreasureManager.materialItemId)
    this.RefreshFindTreasureRedPoint()
end

--刷新探索红点
function this.RefreshFindTreasureRedPoint()
    this.btnFindTreasureredPoint:SetActive(FindTreasureManager.RefreshFindTreasureRedPoint())
end

local isCanShowMainTaskJumpEffect = true
function this:Update()
    this.FreshTime()--刷新挂机时间
    if curMianTaskData and curMianTaskData.state == 0 then
        if isCanShowMainTaskJumpEffect then
            if Time.realtimeSinceStartup - timePressStarted > 5 then
                isCanShowMainTaskJumpEffect = false
                -- this.GuideJumpEffectGo:SetActive(true)
            end
        end
        if Input.GetMouseButtonDown(0) then
            timePressStarted = Time.realtimeSinceStartup
            isCanShowMainTaskJumpEffect = true
            -- this.GuideJumpEffectGo:SetActive(false)
        end
    end
    fightOnHook:Update()
end


--按钮开启限制
function this.BtnsIsOpen()
    for i, v in pairs(this.funcBtnList) do
        local isOpen = ActTimeCtrlManager.SingleFuncState(i)
        v:SetActive(isOpen)
    end
    this.btnRank.gameObject:SetActive(ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALLRANKING))
end

local icon = {
    [1] = Util.LoadSprite("cn2-X1_zhandou_shouyitubiao_02"),
    [2] = Util.LoadSprite("cn2-X1_zhandou_shouyitubiao_04"),
    [3] = Util.LoadSprite("cn2-X1_zhandou_shouyitubiao_01"),
    [4] = Util.LoadSprite("cn2-X1_zhandou_shouyitubiao_03"),
}

--初始化奖励
function this.IntiReward()
    local rewardData
    if FightPointPassManager.isOpenNewChapter then
        rewardData = fightLevelConfig[FightPointPassManager.curOpenFight].RewardShowMin
    else
        rewardData = fightLevelConfig[FightPointPassManager.lastPassFightId].RewardShowMin
    end
    for i = 1, #rewardData do
        this.rewardList[i].icon.sprite = icon[i]

        local addValue = FightPointPassManager.GetItemVipValue(rewardData[i][1])
        if addValue - 1 <= 0 then
            this.rewardList[i].num.text = rewardData[i][2]
        else
            this.rewardList[i].num.text = math.ceil(rewardData[i][2] * addValue)
        end
    end
end

-- 刷新挂机显示(新添加，在Update里调用)
function this.FreshTime()
    if AdventureManager.stateTime > AdventureManager.adventureOffline * 3600 then
        AdventureManager.stateTime = AdventureManager.adventureOffline * 3600
    end
    this.hangOnTime.text = TimeToHM(AdventureManager.stateTime)
    this.slider.fillAmount = AdventureManager.stateTime/(AdventureManager.adventureOffline * 3600)
end

-- 执行关卡战斗
function this.ExcuteBattle()
    if not FightPointPassManager.IsChapterClossState() then
        UIManager.OpenPanel(UIName.FightMiddleChoosePanel, FightPointPassManager.curOpenFight, true,function ()
            --- 临时代码
            --FightPointPassManager.SetChapterOpenState(false)
        end)
        return
    end

    if isCounting then PopupTipPanel.ShowTipByLanguageId(10589) return end
    local curFightId = FightPointPassManager.curOpenFight
    local state, tip = FightPointPassManager.IsCanFight(curFightId)
    if state == -1 then
        PopupTipPanel.ShowTip(tip)
        return
    end

    if not state then
        PopupTipPanel.ShowTip(tip)
        return
    end

    this.SetInitAnim()
end

function FightPointPassMainPanel:OnSortingOrderChange()
    -- 区分特效层级
    -- Util.GetGameObject(self.transform, "FightPoint"):GetComponent("Canvas").sortingOrder = self.canvas.sortingOrder
    Util.SetParticleSortLayer(Util.GetGameObject(self.transform, "n1_eff_idle_atms"), self.canvas.sortingOrder + 4)
    Util.SetParticleSortLayer(Util.GetGameObject(self.transform, "effectCloud"), self.canvas.sortingOrder + 4)
    
    self.canvas.sortingOrder = self.canvas.sortingOrder + 5
    self.sortingOrder = self.canvas.sortingOrder

    invadeMonster:OnSortingOrderChange()
    -- Util.AddParticleSortLayer(this.GuideEffectGo, self.sortingOrder - orginLayer)
    -- Util.AddParticleSortLayer(this.GuideJumpEffectGo, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.pgEffect, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.vipPrivilegeBtn, self.sortingOrder - orginLayer)
    -- Util.AddParticleSortLayer(this.UI_MuBiaoJiangLi, self.sortingOrder - orginLayer)
    -- fightMap:OnSortingOrderChange(self.sortingOrder)
    fightOnHook:OnSortingOrderChange(self.sortingOrder)
    chatPanel:OnSortingOrderChange(self.sortingOrder)
    orginLayer = self.sortingOrder

    this.PlayerHeadFrameView:OnSortingOrderChange(self.sortingOrder + 50)
    this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder + 50})
    this.UpView:OnSortingOrderChange(self.sortingOrder + 51)

    Util.GetGameObject(this.battleGuideFinger,"icon"):GetComponent("Canvas").sortingOrder = self.canvas.sortingOrder + 55
    Util.SetParticleSortLayer(Util.GetGameObject(this.battleGuideFinger,"icon/ring"), self.canvas.sortingOrder + 55)
    Util.SetParticleSortLayer(Util.GetGameObject(this.battleGuideFinger,"icon/glow"), self.canvas.sortingOrder + 55)
    Util.SetParticleSortLayer(Util.GetGameObject(this.battleGuideFinger,"icon/diliang"), self.canvas.sortingOrder + 55)
    Util.GetGameObject(this.taskGuideFinger,"icon"):GetComponent("Canvas").sortingOrder = self.canvas.sortingOrder + 55
    Util.SetParticleSortLayer(Util.GetGameObject(this.taskGuideFinger,"icon/ring"), self.canvas.sortingOrder + 55)
    Util.SetParticleSortLayer(Util.GetGameObject(this.taskGuideFinger,"icon/glow"), self.canvas.sortingOrder + 55)
    Util.SetParticleSortLayer(Util.GetGameObject(this.taskGuideFinger,"icon/diliang"), self.canvas.sortingOrder + 55)
end

--界面关闭时调用（用于子类重写）
function FightPointPassMainPanel:OnClose()
    if this.battleSceneLogicGameObject ~= nil then
        this.battleSceneLogicGameObject:SetActive(false)
    end

    if this.battleSceneGameObject ~= nil then
        this.battleSceneGameObject:SetActive(false)
    end

    hasLoad = false
    invadeMonster:OnClose()
    -- fightMap:Dispose()
    fightOnHook:Dispose()
    chatPanel:OnClose()
    if this.animTimer then
        this.animTimer:Stop()
    end

    this.animTimer = nil

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    if this.homeOntimer then
        this.homeOntimer:Stop()
        this.homeOntimer = nil
    end
end

--界面销毁时调用（用于子类重写）
function FightPointPassMainPanel:OnDestroy()
    --销毁战场
    if this.battleSceneLogicGameObject ~= nil then
        GameObject.Destroy(this.battleSceneLogicGameObject)
        this.battleSceneLogicGameObject = nil
    end

    this.mapGameObject = nil

    if this.battleSceneGameObject ~= nil then
        GameObject.Destroy(this.battleSceneGameObject)
        this.battleSceneGameObject = nil
    end

    invadeMonster:OnDestroy()
    fightOnHook:OnDestroy()

    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.BtView)
    ClearRedPointObject(RedPointType.DailyTaskMain, this.DailyRedPoint)
    ClearRedPointObject(RedPointType.VipPrivilege, this.vipRedPoint)
    ClearRedPointObject(RedPointType.SecretTer_IsCanFight, this.fightRedPoint)
end

--跳转显示新手提示圈
function FightPointPassMainPanel.ShowGuideGo(btnIndex)
    if btnIndex == 1 then--关卡
        if this.btnFight then
            JumpManager.ShowGuide(UIName.FightPointPassMainPanel, this.btnFight)
        end
    elseif btnIndex == 6 then--在线
        if invadeMonster.btnRewardOnline then
            JumpManager.ShowGuide(UIName.FightPointPassMainPanel, invadeMonster.btnRewardOnline)
        end
    elseif btnIndex == 5 then--章节奖励
        if invadeMonster.btnRewardChapter then
            JumpManager.ShowGuide(UIName.FightPointPassMainPanel, invadeMonster.btnRewardChapter)
        end
    elseif btnIndex == 2 then--极速探索
        if invadeMonster.btnFastExplore then
            JumpManager.ShowGuide(UIName.FightPointPassMainPanel, invadeMonster.btnFastExplore)
        end
    elseif btnIndex == 3 then--召唤外敌
        if invadeMonster.callMonsterBtn then
            JumpManager.ShowGuide(UIName.FightPointPassMainPanel, invadeMonster.callMonsterBtn)
        end
    elseif btnIndex == 4 then--挂机宝箱
        if invadeMonster.rewardBox then
            JumpManager.ShowGuide(UIName.FightPointPassMainPanel, invadeMonster.rewardBox)
        end
    end
end

--预先显示玩家等级 解锁的功能list
function this.GetNextFightOpenFun()
    local nextFightId = 0
    local nextFightSortId = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,FightPointPassManager.curOpenFight).SortId - 1
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)) do
        if v.OpenRules then
            if v.OpenRules[1] == 1 then--1关卡开启
                local OpenRulesSortId = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,v.OpenRules[2]).SortId
                if OpenRulesSortId > nextFightSortId and v.IsOpen == 1 and v.IsShow == 1  then
                    if nextFightId == 0 then
                        nextFightId = v.OpenRules[2]
                    else
                        if ConfigManager.GetConfigData(ConfigName.MainLevelConfig,nextFightId).SortId > OpenRulesSortId  then
                            nextFightId = v.OpenRules[2]
                        end
                    end
                end
            end
        end
    end
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)) do
        if v.OpenRules then
            if v.OpenRules[1] == 1 then--1关卡开启
                if v.OpenRules[2] == nextFightId and  v.IsOpen == 1 and  v.IsShow == 1 then
                    return v
                end
            end
        end
    end
    return nil
end

--刷新开服福利
function this.UpdateOpenSeverWelfare()
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.OpenSeverWelfare)
    local activityData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.OpenSeverWelfare)

    if activityId and activityId > 0 and activityData and #activityData.mission > 0 then
        ActivityGiftManager.OpenSeverWelfareRewardTabsSort(activityData.mission)
        local curMissionConfig = nil
        local isShowBtn = false
        for i = 1, #activityData.mission do
            while true
            do
                if activityData.mission[i].state == 0 and not curMissionConfig then
                    curMissionConfig = activityRewardConfig[activityData.mission[i].missionId]
                end
                if activityData.mission[i].state == 0 then
                    isShowBtn = true
                end
                if curMissionConfig == nil then
                    break
                end
                break
            end
            if activityData.mission[i].state == 0 then
                isShowBtn = true
            end
        end
        this.btnOpenSeverWelfare:SetActive(isShowBtn)
        if not curMissionConfig then return end
        local curPassLevelSortId = FightPointPassManager.lastPassFightId ~= FightPointPassManager.curOpenFight and fightLevelConfig[FightPointPassManager.lastPassFightId].SortId or 0
        local getRewardLevelSortId = fightLevelConfig[curMissionConfig.Values[1][1]].SortId
        curPassLevelSortId = curPassLevelSortId >= getRewardLevelSortId and getRewardLevelSortId or curPassLevelSortId
        this.OpenSeverWelfareRedpot:SetActive(curPassLevelSortId >= getRewardLevelSortId)
        this.OpenSeverWelfareGetEffect:SetActive(curPassLevelSortId >= getRewardLevelSortId)

        this.OpenSeverWelfareFrame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[curMissionConfig.Reward[1][1]].Quantity))
        this.OpenSeverWelfareIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[curMissionConfig.Reward[1][1]].ResourceID))
        this.OpenSeverWelfareName.text = GetLanguageStrById(curMissionConfig.ContentsShow)
        if curPassLevelSortId >= getRewardLevelSortId then
            this.OpenSeverWelfareInfoSlider.value = 1
            this.OpenSeverWelfareInfoText.text = "<color=#34F385>"..GetLanguageStrById(10471).."</color>"
        else
            this.OpenSeverWelfareInfoSlider.value = curPassLevelSortId/getRewardLevelSortId
            this.OpenSeverWelfareInfoText.text = curPassLevelSortId .. "/" .. getRewardLevelSortId
        end
        this.RemainTimeDown(this.btnOpenSeverWelfare, this.OpenSeverWelfareTimeText, activityData.endTime - GetTimeStamp())
    else
        this.btnBox:GetComponent("HorizontalLayoutGroup").enabled = false
        this.btnRewardOnline.transform.position = this.btnRewardOnlinePos
        this.btnOpenSeverWelfare:SetActive(false)
    end

    if not this.btnOpenSeverWelfare.activeSelf and not this.btnRewardOnline.activeSelf then
        this.RightUpVertical.transform.localPosition = this.RightUpVerticalPos
    end
end

this.timer = Timer.New()
--刷新倒计时显示
function this.RemainTimeDown(go, txt, timeDown)
    if timeDown > 0 then
        if go then
            go:SetActive(true)
        end
        if txt then
            txt.text = GetLeftTimeStrByDeltaTime2(timeDown)
        end
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if txt then
                txt.text = GetLeftTimeStrByDeltaTime2(timeDown)
            end
            if timeDown < 0 then
                if go then
                    go:SetActive(false)
                end
                this.timer:Stop()
                this.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        if go then
            go:SetActive(false)
        end
    end
end

--弱引导
function this.ShowGuide()
    if GuideManager.IsInMainGuide() or UIManager.IsOpen(UIName.GuidePanel) then
        if this.guideTimer then
            this.guideTimer:Stop()
            this.guideTimer = nil
        end
    end
    this.taskGuideFinger:SetActive(false)
    this.battleGuideFinger:SetActive(GuideManager.isShowGuide)
    GuideManager.isShowGuide = false
    if this.guideTimer then
        this.guideTimer:Stop()
        this.guideTimer = nil
    end
    local time = 5
    this.guideTimer = Timer.New(function()
        if time < 0 then
            this.guideTimer:Stop()
            this.guideTimer = nil

            local task, battle = GuideManager.RefreshGuide()
            this.taskGuideFinger:SetActive(task)
            this.battleGuideFinger:SetActive(battle)
            GuideManager.isShowGuide = task
        end
        time = time - 1
        if GuideManager.IsInMainGuide() or UIManager.IsOpen(UIName.GuidePanel) then
            if this.guideTimer then
                this.guideTimer:Stop()
                this.guideTimer = nil
            end
        end
    end, 1, -1, true)
    this.guideTimer:Start()
end

return FightPointPassMainPanel