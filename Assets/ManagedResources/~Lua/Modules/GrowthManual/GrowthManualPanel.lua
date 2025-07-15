require("Base/BasePanel")
GrowthManualPanel = Inherit(BasePanel)
local this = GrowthManualPanel

local curScore = 0--当前分数
local treasureState = 0
--local maskList = {}
local contentScripts = {
    [1] = {view = require("Modules/GrowthManual/GrowthManual_RewardPreview"), panelName = "RewardPreview",type = 1},
    [2] = {view = require("Modules/GrowthManual/GrowthManual_TaskPreview"), panelName = "TaskPreview",type = 2} ,
}
--子模块预设
local contentPrefabs = {}

local TabBox = require("Modules/Common/TabBox")
local _TabData = { 
                 [1] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", name = GetLanguageStrById(10859) ,type = ActivityTypeDef.TreasureOfSomeBody },
                 [2] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", name = GetLanguageStrById(10625) ,type = ActivityTypeDef.TreasureOfSomeBody }, 
}
local _TabFontColor = { default = Color.New(37 / 255, 37 / 255, 37 / 255, 1),
                        select = Color.New(50 / 255, 18 / 255, 18 / 255, 1)}
local index = 1
function GrowthManualPanel:InitComponent()
    this.TabCtrl = TabBox.New()
     --topBar/btnBack    
    this.tabBox = Util.GetGameObject(this.gameObject,"TabBox")
    this.closeBtn = Util.GetGameObject(this.gameObject,"closeBtn")
    this.testBtn = Util.GetGameObject(this.gameObject,"testbtn")
    this.helpBtn = Util.GetGameObject(this.gameObject, "bg/helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    this.time = Util.GetGameObject(this.gameObject, "bg/time/Text"):GetComponent("Text")

    this.type = Util.GetGameObject(this.gameObject, "bg/Type")
    this.elite =  Util.GetGameObject(this.type, "Image_Elite")
    this.lv =  Util.GetGameObject(this.type, "Level"):GetComponent("Text")
    this.jiesuoBtn = Util.GetGameObject(this.type,  "unLockBtn")

    this.progress = Util.GetGameObject(this.type, "slider"):GetComponent("Image")
    this.scoreText = Util.GetGameObject(this.type, "slider/Text"):GetComponent("Text")   

    this.contents = Util.GetGameObject(this.gameObject, "bg/Rects")
      --子模块脚本初始化
    for i = 1, #contentScripts do
        contentScripts[i].view:InitComponent(Util.GetGameObject(this.contents, contentScripts[i].panelName))
    end
    --预设赋值
    for i = 1,#contentScripts do
        contentPrefabs[i] = Util.GetGameObject(this.contents,contentScripts[i].panelName)
    end

    this.HeadFrameView =SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowRight})
end

function GrowthManualPanel:BindEvent()
    Util.AddClick(this.testBtn,function ()
        UIManager.OpenPanel(UIName.GrowthManualLevelUpPanel,15)
    end)
    Util.AddClick(this.closeBtn,function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.QingLongSerectTreasure,this.helpPosition.x,this.helpPosition.y)
    end)

    for i = 1, #contentScripts do
        contentScripts[i].view:BindEvent()
    end
end

function GrowthManualPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TreasureOfHeaven.BuyQinglongSerectLevelSuccess, this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.TreasureOfHeaven.RechargeQinglongSerectSuccess, this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose,this.Closefunction)
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold,this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.GrowthManual.OnGrowthManualRedpointChange,this.RefreshTabRedpoint)

    for i = 1, #contentScripts do
        contentScripts[i].view:AddListener()
    end
end

function GrowthManualPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TreasureOfHeaven.BuyQinglongSerectLevelSuccess, this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.TreasureOfHeaven.RechargeQinglongSerectSuccess, this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose,this.Closefunction)
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold,this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.GrowthManual.OnGrowthManualRedpointChange,this.RefreshTabRedpoint)
    for i = 1, #contentScripts do
        contentScripts[i].view:RemoveListener()
    end
end
this.Closefunction = function()
    Timer.New(function()
        if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
            PopupTipPanel.ShowTipByLanguageId(10029)            
            self:ClosePanel()            
            return
        else
            this.refresh()
        end
    end,1):Start()
end

function  GrowthManualPanel:OnOpen()
    if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) and ActivityGiftManager.IsQualifiled( ActivityTypeDef.TreasureOfSomeBody) then
        if GrowthManualManager.GetQinglongSerectTreasureRedPot() then
            index = 1
        elseif GrowthManualManager.GetSerectTreasureTrailRedPot() then
            index = 2
        end
    end
    for i = 1,#contentPrefabs do
        contentPrefabs[i].gameObject:SetActive(false)
    end
    contentPrefabs[index].gameObject:SetActive(true)
    contentScripts[index].view:OnShow(this)--1、传入自己 2、传入不定参
end
function GrowthManualPanel:OnShow()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, index)
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
        self:ClosePanel()
        return
    end
    local startTime,endTime,endTimeScale = GrowthManualManager.GetTimeStartToEnd()

    this.time.text = string.format(" %s-%s",startTime,endTime)
    this.refresh()

    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})

    this.RefreshTabRedpoint()
end
function GrowthManualPanel:OnSortingOrderChange()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnSortingOrderChange(self.sortingOrder)
    end
end
-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    local default = Util.GetGameObject(tab,"default")
    local select = Util.GetGameObject(tab,"select")
    default:GetComponent("Text").text = _TabData[index].name
    select:GetComponent("Text").text = _TabData[index].name
    default:SetActive(status == "default")
    select:SetActive(status == "select")
    if ActivityGiftManager.IsQualifiled( _TabData[index].type) and ActivityGiftManager.IsActivityTypeOpen( _TabData[index].type) then
        tab.gameObject:SetActive(true)
    else
        tab.gameObject:SetActive(false)
    end
end

function this.RefreshTabRedpoint()
    Util.GetGameObject(Util.GetGameObject(this.tabBox,"box").transform:GetChild(0).gameObject,"redpoint"):SetActive(GrowthManualManager.RefreshRewardRedpoint())
    local state = false
    for i = 1, 3 do
        if state == false then
            state = GrowthManualManager.RefreshTeskRedpoint(i - 1)
        end
    end
    Util.GetGameObject(Util.GetGameObject(this.tabBox,"box").transform:GetChild(1).gameObject,"redpoint"):SetActive(state)
    CheckRedPointStatus(RedPointType.TreasureOfSl)
end

--切换视图
function this.SwitchView(_index)
    if _index == 1 or _index == 2 then
        if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
            PopupTipPanel.ShowTipByLanguageId(10778)
            return
        end
    end
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, index = index, _index
    for i = 1, #contentScripts do
        if oldSelect ~= 0 then contentScripts[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #contentPrefabs do
        contentPrefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    --执行子模块初始化
    contentScripts[index].view:OnShow(this)   
end
function GrowthManualPanel:OnClose()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnClose()
    end
end
function GrowthManualPanel:OnDestroy()    
    for i = 1, #contentScripts do
        contentScripts[i].view:OnDestroy()
    end
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
end

this.refresh = function() 
    GrowthManualManager.UpdateTreasureState2() 
    this:topBar()   
end

--topBar按钮状态
function GrowthManualPanel:topBar()
    --设置礼包购买按钮状态  
    treasureState = GrowthManualManager.GetTreasureState()--秘宝礼包状态 false:可购买  true:已购买
    curScore = GrowthManualManager.GetScore()
    local lv = GrowthManualManager.GetLevel()
    this.lv.text = lv
    local rewardData = GrowthManualManager.GetRewardData(lv)
    local needScore
    if lv > 0 then
        local lastRewardData = GrowthManualManager.GetRewardData(lv - 1)
        if not lastRewardData then
            needScore = 0
        else
            needScore = lastRewardData.needScore
        end
    else
        needScore = 0
    end
    if rewardData.needScore and rewardData.needScore ~= 0 then
        this.scoreText.text = "<color=#FFFFFF>"..curScore .."</color>/"..rewardData.needScore - needScore
        this.progress.fillAmount = (curScore/(rewardData.needScore - needScore)) + 0.1
    else
        this.scoreText.text = GetLanguageStrById(12351)
        this.progress.fillAmount = 1
    end
    local sprite = ""
    if treasureState then
        sprite = GetPictureFont("cn2-X1_chengzhangshouce_jifenjindu02")
    else
        sprite = GetPictureFont("cn2-X1_chengzhangshouce_jifenjindu01")
    end
    this.type:GetComponent("Image").sprite = Util.LoadSprite(sprite)
    this.jiesuoBtn:GetComponent("Button").enabled = (not treasureState)
    this.jiesuoBtn:GetComponent("Image").sprite = ((not treasureState) and Util.LoadSprite(GetPictureFont("cn2-X1_chengzhangshouce_jiesuo")) or Util.LoadSprite(GetPictureFont("cn2-X1_chengzhangshouce_yijiesuo")))
    
    Util.AddOnceClick(this.jiesuoBtn,function()
        UIManager.OpenPanel(UIName.GrowthManualBuyPanel)
        Game.GlobalEvent:DispatchEvent(GameEvent.GrowthManual.OnGrowthManualRedpointChange)
    end) 
end


return this