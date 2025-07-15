--local LuckyTurnTablePanel= quick_class("LuckyTurnTablePanel")
--local this = LuckyTurnTablePanel
--function LuckyTurnTablePanel:ctor(mainPanel, gameObject)
--    self.mainPanel = mainPanel
--    self.gameObject = gameObject
--    self:InitComponent(gameObject)
--    self:BindEvent()
--end
require("Base/BasePanel")
LuckyTurnTablePanel = Inherit(BasePanel)
local this = LuckyTurnTablePanel

---背景盘图片切换资源名
-- local BgName = { "cn2-x1_choujiang_beijing_renwu_01","cn2-x1_choujiang_beijing_renwu_02","N1_bg_xunbao_haohuaxunbao","x_xytb_quan_33" }
local BgColor = {Color.New(72/255,157/255,228/255,255/255),
                Color.New(188/255,133/255,252/255,255/255)}

local BtnBg = {
    {"cn2-x1_choujiang_jinbichoujiang_01","cn2-x1_choujiang_jinbichoujiang_02"},
    {"cn2-x1_choujiang_zuanshichoujiang_01","cn2-x1_choujiang_zuanshichoujiang_02"},
}

---转盘旋转类型
local TableTurnType = {
    Normal = 1,--默认旋转
    Expedite = 2,--加快旋转
}

local curTurnPos = 1 --当前位置
this.thread = nil --协程

this.refreshTimer = nil
this.upView = nil

local maxTimesCount = 0
---初始化组件（用于子类重写）
function LuckyTurnTablePanel:InitComponent(gameObject)
    LuckyTurnTableManager.InitTableData()
    LuckyTurnTableManager.GetLuckyTurnRequest()

    this.luckyTurnPanel = Util.GetGameObject(self.gameObject,"Panel")
    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowRight, panelType = PanelType.LuckyTreasure })
    this.maskBG = Util.GetGameObject(this.luckyTurnPanel,"Mask")
    this.helpBtn = Util.GetGameObject(this.luckyTurnPanel,"HelpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    this.backBtn = Util.GetGameObject(this.luckyTurnPanel,"BackBtn")
    --this.activityCountDownText = Util.GetGameObject(this.luckyTurnPanel, "CountDownTimeText"):GetComponent("Text")--活动倒计时

    this.luckyTreasureBtn = Util.GetGameObject(this.luckyTurnPanel, "Content/Top/LuckyTreasureBtn")--幸运探宝按钮
    this.luckyTreasureSelectBG = Util.GetGameObject(this.luckyTreasureBtn, "SelectBG")
    this.luckyTreasureText = Util.GetGameObject(this.luckyTreasureBtn,"Text"):GetComponent("Text")
    this.luckyTreasureTitle = Util.GetGameObject(this.luckyTreasureBtn,"title"):GetComponent("Image")
    this.luckyTreasureBtn.gameObject:SetActive(false)

    this.advancedTreasureBtn = Util.GetGameObject(this.luckyTurnPanel, "Content/Top/AdvancedTreasureBtn")--高级探宝按钮
    this.advancedTreasureSelectBG = Util.GetGameObject(this.advancedTreasureBtn, "SelectBG")
    this.advancedTreasureText = Util.GetGameObject(this.advancedTreasureBtn,"Text"):GetComponent("Text")
    this.advancedTreasureTitle = Util.GetGameObject(this.advancedTreasureBtn,"title"):GetComponent("Image")

    this.bg1 = Util.GetGameObject(self.gameObject, "Panel/BG1"):GetComponent("Image")
    this.bg2 = Util.GetGameObject(this.luckyTurnPanel, "Content/TurnTableImage/BG/BG2")
    this.bg3 = Util.GetGameObject(this.luckyTurnPanel, "Content/TurnTableImage/BG/BG3")

    ---跑马灯位置(物品位置)
    this.itemList = {}
    for i = 1,8 do
        this.itemList[i] = Util.GetGameObject(this.luckyTurnPanel, "Content/TurnTableImage/ItemList/Item"..i)
    end

    this.itemEffectIcon = {}--跑马灯亮灯
    this.itemViewList = {}--跑马灯itemviewList
    this.itemViewCurPos = {}
    local tab = {{14,0},{3,0},{12001,0},{5,0},{4,0},{21,0},{60068,0},{60071,0}}---防白片临时数据
    for i = 1, 8 do
        this.itemEffectIcon[i] = Util.GetGameObject(this.itemList[i], "Image")
        local parent = Util.GetGameObject(this.itemList[i].transform,"box").transform
        this.itemViewList[i] = SubUIManager.Open(SubUIConfig.ItemView,parent)
        this.itemViewList[i]:OnOpen(false, {tab[1][1],tab[1][2]},0.75)

        local rect = this.itemViewList[i].transform
        rect.anchoredPosition = Vector2.New(0,0)
        rect.anchorMin = Vector2.New(0.5, 0.5)
        rect.anchorMax = Vector2.New(0.5, 0.5)
        rect.pivot = Vector2.New(0.5, 0.5)
        this.itemViewCurPos[i] = this.itemList[i].transform.position
    end

    --记录
    this.recordTextList = {}
    for i = 1,6 do
        this.recordTextList[i] = Util.GetGameObject(this.luckyTurnPanel, "TreasureRecord/RecordTextList/Viewport/Content/Text"..i):GetComponent("Text")
    end

    --拥有道具数量
    this.propBtn = Util.GetGameObject(this.luckyTurnPanel,"Content/Prop")
    this.propImage = Util.GetGameObject(this.luckyTurnPanel, "Content/Prop/PropImage"):GetComponent("Image")--道具
    this.propText = Util.GetGameObject(this.luckyTurnPanel, "Content/Prop/PropText"):GetComponent("Text")

    this.bottom = Util.GetGameObject(this.luckyTurnPanel,"Bottom")
    this.treasureOnceBtn = Util.GetGameObject(this.bottom,"TreasureOnceBtn")
    this.treasureOnceText = Util.GetGameObject(this.treasureOnceBtn,"Text"):GetComponent("Text")--探宝次数
    this.treasureOnceIcon = Util.GetGameObject(this.treasureOnceBtn,"Icon"):GetComponent("Image")--消耗道具图标
    this.treasureOnceNum = Util.GetGameObject(this.treasureOnceBtn,"Num"):GetComponent("Text")--消耗道具数量
    this.treasureMultipleBtn = Util.GetGameObject(this.bottom,"TreasureMultipleBtn")
    this.treasureMultipleText = Util.GetGameObject(this.treasureMultipleBtn,"Text"):GetComponent("Text")
    this.treasureMultipleIcon = Util.GetGameObject(this.treasureMultipleBtn,"Icon"):GetComponent("Image")
    this.treasureMultipleNum = Util.GetGameObject(this.treasureMultipleBtn,"Num"):GetComponent("Text")
    this.refreshBtn = Util.GetGameObject(self.gameObject,"Content/TurnTableImage/RefreshBtn")
    this.freeDetail = Util.GetGameObject(this.refreshBtn,"FreeDetail")
    this.detail = Util.GetGameObject(this.refreshBtn,"Detail")
    this.costItemImage = Util.GetGameObject(this.detail,"CostItemImage"):GetComponent("Image")
    this.costItemNumText = Util.GetGameObject(this.detail,"CostItemNumText"):GetComponent("Text")
    this.freeRefreshTime = Util.GetGameObject(this.refreshBtn,"FreeRefreshTime/Text"):GetComponent("Text")

    this.slider = Util.GetGameObject(this.luckyTurnPanel,"Slider")
    this.luckyValueNum = Util.GetGameObject(this.slider, "LuckyValue/LuckyValueNum"):GetComponent("Text")--幸运值
    this.luckySlider = Util.GetGameObject(this.slider, "LuckySlider"):GetComponent("Slider")

    this.rewardBoxList = {}--奖励盒
    this.rewardBox = Util.GetGameObject(this.slider,"RewardBox")
    for i = 1,5 do
        this.rewardBoxList[i] = Util.GetGameObject(this.rewardBox,"Item"..i)
    end
    this.rewardPanel = Util.GetGameObject(this.slider,"RewardPanel")--幸运值奖励预览面板
    this.itemViewParent = Util.GetGameObject(this.rewardPanel,"ItemViewParent")--item父物体
    this.rewardPanelMaskBtn = Util.GetGameObject(this.rewardPanel,"Mask")--幸运值奖励预览遮罩按钮
    this.rewardItemView = SubUIManager.Open(SubUIConfig.ItemView,this.itemViewParent.transform)

    -- 奖励预览
    this.btnPreview = Util.GetGameObject(self.gameObject, "Panel/Content/Top/btnPreview")
    this.maxTimes = Util.GetGameObject(self.gameObject, "Panel/maxTimes"):GetComponent("Text")

    this.mask = Util.GetGameObject(self.gameObject, "Panel/Content/Top/mask")
    this.maskText = Util.GetGameObject(this.mask,"Text"):GetComponent("Text")
    this.maskTitle = Util.GetGameObject(this.mask,"title"):GetComponent("Image")
    this.material = Util.GetGameObject(this.rewardBox,"material"):GetComponent("Image").material

    this.shopBtn = Util.GetGameObject(self.gameObject, "Panel/Content/shopBtn")
end

---绑定事件（用于子类重写）
function LuckyTurnTablePanel:BindEvent()
    --帮助按钮
    Util.AddClick(this.helpBtn,function() 
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.LuckyTurn,this.helpPosition.x,this.helpPosition.y)
    end)
    --返回按钮
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
    --幸运探宝按钮
    Util.AddClick(this.luckyTreasureBtn, function()    
        if LuckyTurnTableManager.curTreasureType == TreasureType.Lucky then
            return
        end
        this.SwitchTreasureType(TreasureType.Lucky)
        this.luckyTreasureBtn:SetActive(false)
        this.advancedTreasureBtn:SetActive(true)
        this.mask.transform.position = this.luckyTreasureBtn.transform.position
        this.maskText.text = this.luckyTreasureText.text
        this.maskTitle.sprite = this.luckyTreasureTitle.sprite
    end)

    --高级探宝按钮
    Util.AddClick(this.advancedTreasureBtn, function()
        if LuckyTurnTableManager.curTreasureType == TreasureType.Advanced then
            return
        end
        this.SwitchTreasureType(TreasureType.Advanced)
        this.luckyTreasureBtn:SetActive(true)
        this.advancedTreasureBtn:SetActive(false)
        this.mask.transform.position = this.advancedTreasureBtn.transform.position
        this.maskText.text = this.advancedTreasureText.text
        this.maskTitle.sprite =  this.advancedTreasureTitle.sprite
    end)
    --幸运值奖励预览遮罩按钮
    Util.AddClick(this.rewardPanelMaskBtn, function()
        this.rewardPanelMaskBtn.gameObject:SetActive(false)
        this.rewardPanel.gameObject:SetActive(false)
    end)

    Util.AddClick(this.btnPreview, function()
        UIManager.OpenPanel(UIName.HeroPreviewPanel, 4, false)
    end)

    Util.AddClick(this.shopBtn, function()
        UIManager.OpenPanel(UIName.MainShopPanel,61)
    end)
end

---添加事件监听（用于子类重写）
function LuckyTurnTablePanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnLuckyTableWorldMessage, this.ShowRecordMessage)
end

---移除事件监听（用于子类重写）
function LuckyTurnTablePanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnLuckyTableWorldMessage, this.ShowRecordMessage)
end

---界面打开时调用（用于子类重写）
function LuckyTurnTablePanel:OnOpen(_TreasureType)
    LuckyTurnTableManager.curTreasureType = _TreasureType and _TreasureType or TreasureType.Lucky
    maxTimesCount = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,53).Value) 
end

---界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LuckyTurnTablePanel:OnShow()
    this.maskBG.gameObject:SetActive(false)
    if LuckyTurnTableManager.curTreasureType == TreasureType.Lucky then--防止当前为高级探宝时 按下探宝后跳转到幸运探宝
        this.LuckyTurnOnShow(TreasureType.Lucky)

        this.luckyTreasureBtn:SetActive(false)
        this.advancedTreasureBtn:SetActive(true)
        this.mask.transform.position = this.luckyTreasureBtn.transform.position
        this.maskText.text = this.luckyTreasureText.text
        this.maskTitle.sprite = this.luckyTreasureTitle.sprite

    elseif  LuckyTurnTableManager.curTreasureType == TreasureType.Advanced then
        this.LuckyTurnOnShow(TreasureType.Advanced)

        this.luckyTreasureBtn:SetActive(true)
        this.advancedTreasureBtn:SetActive(false)
        this.mask.transform.position = this.advancedTreasureBtn.transform.position
        this.maskText.text = this.advancedTreasureText.text
        this.maskTitle.sprite =  this.advancedTreasureTitle.sprite

    end
    this.PlayerHeadFrameView:OnShow()
    this.upView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.LuckyTreasure })

    -- this.mask.transform.position = this.luckyTreasureBtn.transform.position
    -- this.maskTitle.sprite = this.luckyTreasureTitle.sprite
    -- this.luckyTreasureBtn:SetActive(false)
    -- this.advancedTreasureBtn:SetActive(true)
end

local sortingOrder = 0
---重设层级
function LuckyTurnTablePanel:OnSortingOrderChange()
    sortingOrder = self.sortingOrder
    for i, v in pairs(this.itemViewList) do
        v:SetEffectLayer(sortingOrder)
    end
end

---界面关闭时调用（用于子类重写）
function LuckyTurnTablePanel:OnClose()
    RedpotManager.CheckRedPointStatus(RedPointType.LuckyTurn)
    this.rewardPanel.gameObject:SetActive(false)
    if this.thread then
        coroutine.stop(this.thread)
        this.thread = nil
    end
    if this.turnEffect then
        this.turnEffect:Stop()
        this.turnEffect = nil
    end
    if this.outsideLightTurnEffect then
        this.outsideLightTurnEffect:Stop()
        this.outsideLightTurnEffect = nil
    end
    if this.refreshTimer then
        this.refreshTimer:Stop()
        this.refreshTimer = nil
    end
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    if LuckyTurnTableManager._CountDownTimer then
        LuckyTurnTableManager._CountDownTimer:Stop()
        LuckyTurnTableManager._CountDownTimer = nil
    end

    LuckyTurnTableManager.ClearSaveData()
end

---界面销毁时调用（用于子类重写）
function LuckyTurnTablePanel:OnDestroy()
    this.itemViewList = nil
    this.rewardItemView = nil
    SubUIManager.Close(this.upView)
end

---打开面板
function this.LuckyTurnOnShow(treasureType)
    if not this.turnEffect then
        this.turnEffect = Timer.New(nil,1,-1,true)
    end
    if not this.outsideLightTurnEffect then
        this.outsideLightTurnEffect = Timer.New(nil,1,-1,true)
    end
    if not this.refreshTimer then
        this.refreshTimer = Timer.New(nil,1,-1,true)
    end
    --初始化幸运探宝
    this.SwitchTreasureType(treasureType)
    this.SetTableTurnEffect(TableTurnType.Normal)
end

---切换探宝类型
function this.SwitchTreasureType(treasureType)
    this.ClearDefault()
    if treasureType == TreasureType.Lucky then
        LuckyTurnTableManager.curTreasureType = treasureType
        this.maxTimes.text = string.format(GetLanguageStrById(12260),LuckyTurnTableManager.luckyTimes,maxTimesCount)

        this.upView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.LuckyTreasure })

        this.bg3:SetActive(false)
        this.bg2:SetActive(true)
        this.treasureOnceBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(BtnBg[1][1]))
        this.treasureMultipleBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(BtnBg[1][2]))
        this.bg1.color = BgColor[1]     

        --显示免费刷新状态
        this.RefreshBtnCountDown()

        --设置顶部按钮
        this.luckyTreasureSelectBG:SetActive(true)
        this.luckyTreasureText.text = GetLanguageStrById(11138)
        --请求跑马灯物品数据
        LuckyTurnTableManager.GetLuckyTurnRequest(function(msg)
            this.SetItemViewShow(msg.posInfos,function()
                this.SetItemViewGray(LuckyTurnTableManager.luckyData)
            end)
        end)
        --立即刷新一次转盘记录
        if LuckyTurnTableManager.isCanGetWorldMessage then
            LuckyTurnTableManager.TimeUpdate()
        end
        --启动定时刷新转盘记录
        LuckyTurnTableManager.StartLuckyTurnRecordDataUpdate()
        --设置需要材料显示
        this.SetPropShow(60,treasureType)
        --探宝按钮显示
        local oneData,moreData,icon = LuckyTurnTableManager.GetTreasureBtnInfo(treasureType)
        this.SetTreasureBtnShow(oneData,moreData,icon)
        --探宝泉预览
        Util.AddOnceClick(this.propBtn,function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,60)
        end)
        --探宝1次按钮
        Util.AddOnceClick(this.treasureOnceBtn, function()
            if LuckyTurnTableManager.GetTreasureTicketNum(treasureType) - oneData[2] >= 0 
            and LuckyTurnTableManager.luckyTimes + 1 <= maxTimesCount then
                LuckyTurnTableManager.GetLuckyTurnRankRequest(TreasureType.Lucky,false,function()
                    
                    this.SetTableTurnEffect(TableTurnType.Expedite,TreasureType.Lucky,LuckyTurnTableManager.luckyTempData.posInfos[1].pos)
                    this.SetPropShow(60,TreasureType.Lucky)--更新消耗道具显示
                    this.RrFreshInfo()
                    LuckyTurnTableManager.SetTimes(LuckyTurnTableManager.luckyTimes + 1)
                    this.maxTimes.text = string.format(GetLanguageStrById(12260),LuckyTurnTableManager.luckyTimes,maxTimesCount)
                end)
            else
                --PopupTipPanel.ShowTip("幸运探宝券不足！")
                if LuckyTurnTableManager.luckyTimes + 1 > maxTimesCount then
                    PopupTipPanel.ShowTipByLanguageId(12261)
                    return
                else
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,60,nil)
                end
            end
        end)
        --探宝10次按钮
        Util.AddOnceClick(this.treasureMultipleBtn, function()
            if LuckyTurnTableManager.GetTreasureTicketNum(treasureType)-moreData[2] >= 0
            and LuckyTurnTableManager.luckyTimes + 15 <= maxTimesCount then              
                LuckyTurnTableManager.GetLuckyTurnRankRequest(TreasureType.Lucky,true,function()
                    this.SetTableTurnEffect(TableTurnType.Expedite,TreasureType.Lucky,LuckyTurnTableManager.luckyTempData.posInfos[1].pos)
                    this.SetPropShow(60,TreasureType.Lucky)--更新消耗道具显示
                    this.RrFreshInfo()
                    LuckyTurnTableManager.SetTimes(LuckyTurnTableManager.luckyTimes + 15)
                    this.maxTimes.text = string.format(GetLanguageStrById(12260),LuckyTurnTableManager.luckyTimes,maxTimesCount)
                end)
            else
                --PopupTipPanel.ShowTip("幸运探宝券不足！")
                if LuckyTurnTableManager.luckyTimes + 15 > maxTimesCount then
                    PopupTipPanel.ShowTipByLanguageId(12261)
                    return
                else
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,60,nil)
                end
            end
        end)
        --刷新按钮
        Util.AddOnceClick(this.refreshBtn, function()
            if BagManager.GetItemCountById(62) > 0 then--如果是免费刷新              
                this.PlayItemListAnim()
                LuckyTurnTableManager.GetLuckyTurnRefreshRequest(TreasureType.Lucky,true,function()
                    this.SetItemViewShow(LuckyTurnTableManager.luckyData,function()
                        this.SetItemViewGray(LuckyTurnTableManager.luckyData)
                    end)
                    this.RefreshBtnCountDown()
                end)
            else
                if LuckyTurnTableManager.GetRefreshItemNum() - LuckyTurnTableManager.dialRewardSettingConfig[1].Cost[2][4] >= 0 then--如果材料够
                    this.PlayItemListAnim()
                    LuckyTurnTableManager.GetLuckyTurnRefreshRequest(TreasureType.Lucky,false,function()
                        this.SetItemViewShow(LuckyTurnTableManager.luckyData,function()
                            this.SetItemViewGray(LuckyTurnTableManager.luckyData)
                        end)
                        this.RefreshBtnCountDown()
                    end)
                else
                    PopupTipPanel.ShowTipByLanguageId(11139)
                    --UIManager.OpenPanel(UIName.ShopExchangePopup, SHOP_TYPE.FUNCTION_SHOP, 10013, "兑换妖晶")
                end
            end
        end)

        RedpotManager.CheckRedPointStatus(RedPointType.LuckyTurn)
        this.RrFreshInfo()
    elseif treasureType == TreasureType.Advanced then
        LuckyTurnTableManager.curTreasureType = treasureType

        this.maxTimes.text = string.format(GetLanguageStrById(12260),LuckyTurnTableManager.advanceTimes,maxTimesCount)

        this.upView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.AdvancedTreasure })
        this.bg2:SetActive(false)
        this.bg3:SetActive(true)
        this.treasureOnceBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(BtnBg[2][1]))
        this.treasureMultipleBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(BtnBg[2][2]))
        this.bg1.color = BgColor[2]

        this.RefreshBtnCountDown()

        --设置顶部按钮
        this.advancedTreasureSelectBG:SetActive(true)
        this.advancedTreasureText.text = GetLanguageStrById(11140) 

        --请求跑马灯物品数据
        LuckyTurnTableManager.GetLuckyTurnRequest(function(msg)
            this.SetItemViewShow(msg.posInfosAdvance,function()
                this.SetItemViewGray(LuckyTurnTableManager.advancedData)
            end)
        end)
        --立即刷新一次转盘记录
        if LuckyTurnTableManager.isCanGetWorldMessage then
            LuckyTurnTableManager.TimeUpdate()
        end
        --启动定时刷新转盘记录
        LuckyTurnTableManager.StartLuckyTurnRecordDataUpdate(treasureType)

        --设置需要材料显示
        this.SetPropShow(61,treasureType)

        --探宝按钮显示
        local oneData,moreData,icon = LuckyTurnTableManager.GetTreasureBtnInfo(treasureType)
        this.SetTreasureBtnShow(oneData,moreData,icon)
        --探宝泉预览
        Util.AddOnceClick(this.propBtn,function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,61)
        end)
        --探宝1次按钮
        Util.AddOnceClick(this.treasureOnceBtn, function()
            if LuckyTurnTableManager.GetTreasureTicketNum(treasureType) - oneData[2] >= 0 and LuckyTurnTableManager.advanceTimes + 1 <= maxTimesCount then
                LuckyTurnTableManager.GetLuckyTurnRankRequest(TreasureType.Advanced,false,function()
                    LuckyTurnTableManager.SetTimes(nil,LuckyTurnTableManager.advanceTimes + 1)
                    this.maxTimes.text = string.format(GetLanguageStrById(12260),LuckyTurnTableManager.advanceTimes,maxTimesCount)
                    
                    this.SetTableTurnEffect(TableTurnType.Expedite,TreasureType.Advanced,LuckyTurnTableManager.advancedTempData.posInfos[1].pos)
                    this.SetPropShow(61,TreasureType.Advanced)
                    this.RrFreshInfo()
                end)
            else
                if not RECHARGEABLE then--（是否开启充值）
                    PopupTipPanel.ShowTipByLanguageId(12262)
                else
                    if LuckyTurnTableManager.advanceTimes + 1 > maxTimesCount then
                        PopupTipPanel.ShowTipByLanguageId(12249)
                        return
                    else
                        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,61,nil)
                    end
                end
            end
        end)
        --探宝10次按钮
        Util.AddOnceClick(this.treasureMultipleBtn, function()
            if LuckyTurnTableManager.GetTreasureTicketNum(treasureType) - moreData[2] >= 0 
            and LuckyTurnTableManager.advanceTimes + 10 <= maxTimesCount then
                LuckyTurnTableManager.GetLuckyTurnRankRequest(TreasureType.Advanced,true,function()
                    LuckyTurnTableManager.SetTimes(nil,LuckyTurnTableManager.advanceTimes + 10)
                    this.maxTimes.text = string.format(GetLanguageStrById(12260),LuckyTurnTableManager.advanceTimes,maxTimesCount)
                    
                    this.SetTableTurnEffect(TableTurnType.Expedite,TreasureType.Advanced,LuckyTurnTableManager.advancedTempData.posInfos[1].pos)
                    this.SetPropShow(61,TreasureType.Advanced)
                    this.RrFreshInfo()
                end)
            else
                if not RECHARGEABLE then--（是否开启充值）
                    PopupTipPanel.ShowTipByLanguageId(12262)
                else
                    if LuckyTurnTableManager.advanceTimes + 10 > maxTimesCount then
                        PopupTipPanel.ShowTipByLanguageId(12249)
                        return
                    else
                        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,61,nil)
                    end
                end
            end
        end)
        --刷新按钮
        Util.AddOnceClick(this.refreshBtn, function()
            if BagManager.GetItemCountById(63) > 0 then
                this.PlayItemListAnim()
                LuckyTurnTableManager.GetLuckyTurnRefreshRequest(TreasureType.Advanced,true,function()
                    this.SetItemViewShow(LuckyTurnTableManager.advancedData,function()
                        this.SetItemViewGray(LuckyTurnTableManager.advancedData)
                    end)
                    this.RefreshBtnCountDown()
                end)
            else
                if LuckyTurnTableManager.GetRefreshItemNum()-LuckyTurnTableManager.dialRewardSettingConfig[2].Cost[2][4] >= 0 then
                    this.PlayItemListAnim()
                    LuckyTurnTableManager.GetLuckyTurnRefreshRequest(TreasureType.Advanced,false,function()
                        this.SetItemViewShow(LuckyTurnTableManager.advancedData,function()
                            this.SetItemViewGray(LuckyTurnTableManager.advancedData)
                        end)
                        this.RefreshBtnCountDown()
                    end)
                else
                    PopupTipPanel.ShowTipByLanguageId(11139)
                end
            end
        end)

        RedpotManager.CheckRedPointStatus(RedPointType.LuckyTurn)
        this.RrFreshInfo()
    end
    this.mask.transform:SetAsLastSibling()
    this.ShowRecordMessage(LuckyTurnTableManager.curTreasureType)
end

--重置默认
function this.ClearDefault()
    this.luckyTreasureSelectBG:SetActive(false)
    this.luckyTreasureText.text = GetLanguageStrById(11141)
    this.advancedTreasureSelectBG:SetActive(false)
    this.advancedTreasureText.text = GetLanguageStrById(11142)
    --清除红点
    Util.GetGameObject(this.luckyTreasureBtn,"redPoint"):SetActive(false)
    Util.GetGameObject(this.advancedTreasureBtn,"redPoint"):SetActive(false)
    for i = 1, 5 do
        Util.GetGameObject(this.rewardBoxList[i],"redPoint"):SetActive(false)
    end

    -- for i = 1, 6 do
    --     this.recordTextList[i].text = ""
    -- end
end

--设置转盘滚动 1旋转类型 2探宝类型 3服务器给的探宝后位置
function this.SetTableTurnEffect(turnType,treasureType,pos)
    if turnType == TableTurnType.Normal then --默认旋转
        this.TurnEffectReset(0.5)
        this.turnEffect:Start()
    elseif turnType == TableTurnType.Expedite then --抽奖旋转 至指定位置
        this.DelayMaskWithBool(true)
        LuckyTurnTableManager.isCanGetWorldMessage = false
        this.TurnEffectReset(0.05)
        this.turnEffect:Start()
        this.thread = coroutine.start(function()
            coroutine.wait(1)
            this.TurnEffectReset(0.2)
            coroutine.wait(0.4)
            this.TurnEffectReset(0.4,true,pos,function()--当效果播放完毕后 从管理器取得数据
                local timer = Timer.New(function()
                    this.DelayMaskWithBool(false)
                    if treasureType == TreasureType.Lucky then
                        UIManager.OpenPanel(UIName.RewardItemPopup,LuckyTurnTableManager.luckyTempData.drop,1,function()
                            this.SetTableTurnEffect(TableTurnType.Normal)--恢复转盘旋转
                            LuckyTurnTableManager.isCanGetWorldMessage = true
                        end)--打开奖励弹窗
                        this.SetItemViewGray(LuckyTurnTableManager.luckyData)--刷新物品是否置灰
                    elseif treasureType == TreasureType.Advanced then
                        UIManager.OpenPanel(UIName.RewardItemPopup,LuckyTurnTableManager.advancedTempData.drop,1,function()
                            this.SetTableTurnEffect(TableTurnType.Normal)--恢复转盘旋转
                            LuckyTurnTableManager.isCanGetWorldMessage = true
                        end)
                        this.SetItemViewGray(LuckyTurnTableManager.advancedData)
                    end
                end,0.5,1,true)
                timer:Start()
            end)
        end)
    end
end

--转盘滚动特效重设 1移动速度，值越小越快 2是否停止 3停止位置
function this.TurnEffectReset(turnSpeed,isStop,pos,func)
    this.turnEffect:Reset(function()
        if curTurnPos == 1 then
            this.itemEffectIcon[8]:SetActive(false)
        else
            this.itemEffectIcon[curTurnPos-1]:SetActive(false)
        end
        if curTurnPos >= 9 then
            curTurnPos = 1
        end
        if isStop then
            if pos == curTurnPos then--如果停到对应位置
                this.turnEffect:Stop()--暂停跑马灯
                if func then--回调
                    func()
                end
            end
        end
        this.itemEffectIcon[curTurnPos]:SetActive(true)
        curTurnPos = curTurnPos + 1
    end,turnSpeed,-1,true)
end

--设置跑马灯物品显示 func确保先生成itemview 再置灰
function this.SetItemViewShow(data,func)
    for i = 1, #this.itemViewList do        
        local tab = {LuckyTurnTableManager.dialRewardConfig[data[i].luckId].Reward[1],LuckyTurnTableManager.dialRewardConfig[data[i].luckId].Reward[2]}
        this.itemViewList[i]:OnOpen(false, {tab[1],tab[2]},1, false, false, false, sortingOrder)
    end
    if func then
        func()
    end
end

--设置跑马灯物品置灰
function this.SetItemViewGray(data)
    for i = 1, #data do
        if LuckyTurnTableManager.dialRewardConfig[data[i].luckId].LimitNum ~= 0 then
            Util.SetGray(this.itemViewList[i].gameObject,data[i].luckTimes >= LuckyTurnTableManager.dialRewardConfig[data[i].luckId].LimitNum)
        end
        if LuckyTurnTableManager.dialRewardConfig[data[i].luckId].LimitNum == 0 then
            Util.SetGray(this.itemViewList[i].gameObject,false)
        end
    end
end

---跑马灯记录
function this.ShowRecordMessage(type)
    if LuckyTurnTableManager.isCanGetWorldMessage then
        local messageList = {}
        messageList = LuckyTurnTableManager.GetShowDataByType(type)
        for i = 1, 6 do
            this.recordTextList[i].text = messageList[i]
            if messageList[i] == "" or messageList[i] == nil then
                this.recordTextList[i].gameObject:SetActive(false)
            else
                this.recordTextList[i].gameObject:SetActive(true)
            end
        end
    end
end

--设置道具拥有显示  1道具id 2探宝类型
function this.SetPropShow(itemId,treasureType)
    this.propImage.sprite = SetIcon(itemId)
    this.propText.text = LuckyTurnTableManager.GetTreasureTicketNum(treasureType)
end

--探宝按钮显示
function this.SetTreasureBtnShow(oneData,moreData,icon)
    this.treasureOnceText.text = GetLanguageStrById(11143)..oneData[1]..GetLanguageStrById(10054)
    this.treasureOnceNum.text = oneData[2]
    this.treasureOnceIcon.sprite = icon
    this.treasureMultipleText.text = GetLanguageStrById(11143)..moreData[1]..GetLanguageStrById(10054)
    this.treasureMultipleNum.text = moreData[2]
    this.treasureMultipleIcon.sprite = icon
end

--------------------------------免费刷新--------------------------------
--打开、切换活动界面，刷新倒计时
function this.RefreshBtnCountDown()
    if LuckyTurnTableManager.curTreasureType == TreasureType.Lucky then
        if this.refreshTimer then
            this.refreshTimer:Stop()
        end
        if BagManager.GetItemCountById(62) > 0 then
            --显示免费刷新
            this.SetRefreshBtnShowState(true)
            this.freeRefreshTime.text = "  "
        else
            --显示道具刷新
            this.SetRefreshBtnShowState(false)
            --因转换时间计算精度问题 在有免费刷新 未刷新状态下操作
            local time = BagManager.GetNextRefreshTime(62) - GetTimeStamp()
            local intervalTime = LuckyTurnTableManager.GetItemRecoverTime(62)
            if time > intervalTime then
                time = intervalTime
            end
            this.freeRefreshTime.text = TimeToHMS(time)--立即刷新一次
            this.refreshTimer:Reset(function()
                if time < 0 then
                    time = 0
                    this.refreshTimer:Stop()
                    this.SetRefreshBtnShowState(true)
                    NetManager.GetRefreshCountDownRequest({62})
                end
                time = time - 1
                this.freeRefreshTime.text = TimeToHMS(time)
            end,1,-1,true)
            this.refreshTimer:Start()
        end
    elseif LuckyTurnTableManager.curTreasureType == TreasureType.Advanced then
        this.refreshTimer:Stop()
        if BagManager.GetItemCountById(63) > 0 then
            --显示免费刷新
            this.SetRefreshBtnShowState(true)
            this.freeRefreshTime.text = "  "--" 0:00:00"
        else
            --显示道具刷新
            this.SetRefreshBtnShowState(false)
            local time = BagManager.GetNextRefreshTime(63)-GetTimeStamp()
            local intervalTime = LuckyTurnTableManager.GetItemRecoverTime(63)
            if time > intervalTime then
                time = intervalTime
            end
            this.freeRefreshTime.text = TimeToHMS(time)--立即刷新一次
            this.refreshTimer:Reset(function()
                if time < 0 then
                    this.refreshTimer:Stop()
                    time = 0
                    this.SetRefreshBtnShowState(true)
                    NetManager.GetRefreshCountDownRequest({63})
                end
                time = time-1
                this.freeRefreshTime.text = TimeToHMS(time)
            end,1,-1,true)
            this.refreshTimer:Start()
        end
    end
end

---控制刷新按钮的显示状态  1是否免费
function this.SetRefreshBtnShowState(isFree)
    if isFree then
        this.freeDetail:SetActive(true)
        this.detail:SetActive(false)
    else
        this.freeDetail:SetActive(false)
        this.detail:SetActive(true)
        if LuckyTurnTableManager.curTreasureType == TreasureType.Lucky then
            this.costItemImage.sprite = SetIcon(LuckyTurnTableManager.dialRewardSettingConfig[1].Cost[1][1])
            this.costItemNumText.text = LuckyTurnTableManager.dialRewardSettingConfig[1].Cost[2][4]--..GetLanguageStrById(11144)
        end
        if LuckyTurnTableManager.curTreasureType == TreasureType.Advanced then
            this.costItemImage.sprite = SetIcon(LuckyTurnTableManager.dialRewardSettingConfig[2].Cost[1][1])
            this.costItemNumText.text = LuckyTurnTableManager.dialRewardSettingConfig[2].Cost[2][4]--..GetLanguageStrById(11144)
        end
    end
end

---播放刷新动画
function this.PlayItemListAnim()
    this.DelayMaskWithTime(1.5)
    for i = 1, 8 do
        this.itemList[i]:GetComponent("PlayFlyAnim"):PlayAnim(true)
    end

    for i = 1, #this.itemViewCurPos do
        this.itemList[i].transform.position = this.itemViewCurPos[i]
    end
end
-----------------------------------------------------------------------

---本地检查红点 幸运高级按钮
function this.CheckRedPoint()
    for i = 1, #this.rewardBoxList do
        if LuckyTurnTableManager.value_1 >= LuckyTurnTableManager.boxReward_One[i].Values[1][1] then
            Util.GetGameObject(this.luckyTreasureBtn,"redPoint"):SetActive(LuckyTurnTableManager.GetRewardState(30,LuckyTurnTableManager.boxReward_One[i].Id)==0)
        end
        if LuckyTurnTableManager.value_2 >= LuckyTurnTableManager.boxReward_Two[i].Values[1][1] then
            Util.GetGameObject(this.advancedTreasureBtn,"redPoint"):SetActive(LuckyTurnTableManager.GetRewardState(31,LuckyTurnTableManager.boxReward_Two[i].Id)==0)
        end
    end
end

---设置奖盒
function this.SetRewardBox()
    if LuckyTurnTableManager.curTreasureType == TreasureType.Lucky then
        for i = 1, 5 do
            local BG1 = Util.GetGameObject(this.rewardBoxList[i],"BG1"):GetComponent("Image")
            local BG2 = Util.GetGameObject(this.rewardBoxList[i],"BG1/BG2"):GetComponent("Image")
            local baoxiang = Util.GetGameObject(this.rewardBoxList[i],"BG1/UI_baoxiang")

            Util.GetGameObject(this.rewardBoxList[i],"Value"):GetComponent("Text").text = LuckyTurnTableManager.boxReward_One[i].Values[1][1]
            BG2.sprite = SetIcon(LuckyTurnTableManager.boxReward_One[i].Reward[1][1])
            BG1.sprite = SetFrame(LuckyTurnTableManager.boxReward_One[i].Reward[1][1])
            Util.GetGameObject(this.rewardBoxList[i],"yilingqu"):SetActive(false)

            --显示奖盒红点
            --BG1:灰色合箱子 BG2:灰色开箱子 BG3:彩色合箱子
            if LuckyTurnTableManager.value_1 >= LuckyTurnTableManager.boxReward_One[i].Values[1][1] then
                if LuckyTurnTableManager.GetRewardState(30,LuckyTurnTableManager.boxReward_One[i].Id) == 0 then
                    Util.GetGameObject(this.rewardBoxList[i],"redPoint"):SetActive(true)
                    BG1.material = nil
                    BG2.material = nil
                    baoxiang:SetActive(true)
                else--奖励已领取
                    BG1.material = this.material
                    BG2.material = this.material
                    baoxiang:SetActive(false)
                    Util.GetGameObject(this.rewardBoxList[i],"yilingqu"):SetActive(true)
                end
            else--幸运值未超过该箱子
                BG1.material = this.material
                BG2.material = this.material
                baoxiang:SetActive(false)
            end

            Util.AddOnceClick(this.rewardBoxList[i], function()
                RedpotManager.CheckRedPointStatus(RedPointType.LuckyTurn)
                --如果幸运值达到奖励要求值
                if LuckyTurnTableManager.value_1 >= LuckyTurnTableManager.boxReward_One[i].Values[1][1] then
                    --奖励未领取 先请求领取
                    if LuckyTurnTableManager.GetRewardState(30,LuckyTurnTableManager.boxReward_One[i].Id) == 0 then
                        NetManager.GetActivityRewardRequest(LuckyTurnTableManager.boxReward_One[i].Id,30,function(drop)
                            UIManager.OpenPanel(UIName.RewardItemPopup,drop)
                            Util.GetGameObject(this.rewardBoxList[i],"redPoint"):SetActive(false)--隐藏红点
                            this.RrFreshInfo()
                        end)
                    else--奖励已领取 可预览
                        -- this.OpenRewardPreview(LuckyTurnTableManager.boxReward_One,i)
                        -- print(LuckyTurnTableManager.boxReward_One[i].Values[1][1])
                    end
                else
                    --奖励不可领，可预览
                    -- this.OpenRewardPreview(LuckyTurnTableManager.boxReward_One,i)
                end
            end)
        end
    elseif LuckyTurnTableManager.curTreasureType==TreasureType.Advanced then
        for i = 1, 5 do
            local BG1 = Util.GetGameObject(this.rewardBoxList[i],"BG1"):GetComponent("Image")
            local BG2 = Util.GetGameObject(this.rewardBoxList[i],"BG1/BG2"):GetComponent("Image")
            local baoxiang = Util.GetGameObject(this.rewardBoxList[i],"BG1/UI_baoxiang")

            Util.GetGameObject(this.rewardBoxList[i],"Value"):GetComponent("Text").text=LuckyTurnTableManager.boxReward_Two[i].Values[1][1]
            BG2.sprite = SetIcon(LuckyTurnTableManager.boxReward_Two[i].Reward[1][1])
            BG1.sprite = SetFrame(LuckyTurnTableManager.boxReward_Two[i].Reward[1][1])
            Util.GetGameObject(this.rewardBoxList[i],"yilingqu"):SetActive(false)
            --显示红点
            if LuckyTurnTableManager.value_2>=LuckyTurnTableManager.boxReward_Two[i].Values[1][1] then
                if LuckyTurnTableManager.GetRewardState(31,LuckyTurnTableManager.boxReward_Two[i].Id)==0 then
                    Util.GetGameObject(this.rewardBoxList[i],"redPoint"):SetActive(true)
                    BG1.material = nil
                    BG2.material = nil
                    baoxiang:SetActive(true)
                else
                    BG1.material = this.material
                    BG2.material = this.material
                    baoxiang:SetActive(false)
                    Util.GetGameObject(this.rewardBoxList[i],"yilingqu"):SetActive(true)
                end
            else
                BG1.material = this.material
                BG2.material = this.material
                baoxiang:SetActive(false)
            end
            Util.AddOnceClick(this.rewardBoxList[i], function()
                
                RedpotManager.CheckRedPointStatus(RedPointType.LuckyTurn)
                if LuckyTurnTableManager.value_2>=LuckyTurnTableManager.boxReward_Two[i].Values[1][1] then
                    if LuckyTurnTableManager.GetRewardState(31,LuckyTurnTableManager.boxReward_Two[i].Id)==0 then
                        NetManager.GetActivityRewardRequest(LuckyTurnTableManager.boxReward_Two[i].Id,31,function(drop)
                            UIManager.OpenPanel(UIName.RewardItemPopup,drop)
                            Util.GetGameObject(this.rewardBoxList[i],"redPoint"):SetActive(false)--隐藏红点
                            this.RrFreshInfo()
                        end)
                    else
                        -- this.OpenRewardPreview(LuckyTurnTableManager.boxReward_Two,i)
                    end
                else
                    -- this.OpenRewardPreview(LuckyTurnTableManager.boxReward_Two,i)
                end
            end)
        end
    end
end

---奖盒滑动条奖励背景切换
function this.RewardBgProgress()
    -- for i = 1, 4 do
    --     local bg=Util.GetGameObject(this.rewardBoxList[i],"BG"):GetComponent("Image")
    --     if LuckyTurnTableManager.curTreasureType==TreasureType.Lucky then
    --         if LuckyTurnTableManager.value_1>=LuckyTurnTableManager.boxReward_One[i].Values[1][1] then
    --             -- bg.sprite=Util.LoadSprite(RewardName[2]) --m5
    --         else
    --             -- bg.sprite=Util.LoadSprite(RewardName[1]) --m5
    --         end
    --     elseif LuckyTurnTableManager.curTreasureType==TreasureType.Advanced then
    --         if LuckyTurnTableManager.value_2>=LuckyTurnTableManager.boxReward_Two[i].Values[1][1] then
    --             -- bg.sprite=Util.LoadSprite(RewardName[2]) --m5
    --         else
    --             -- bg.sprite=Util.LoadSprite(RewardName[1]) --m5
    --         end
    --     end
    --     -- bg:SetNativeSize()
    -- end
end

---设置奖盒预览信息 并打开面板
function this.OpenRewardPreview(boxReward,i)
    --设置奖励预览信息 并打开面板
    local tab = {boxReward[i].Reward[1][1],boxReward[i].Reward[1][2]}
    this.rewardItemView:OnOpen(false, {tab[1],tab[2]},1, false, false, false, sortingOrder)

    this.rewardPanelMaskBtn.gameObject:SetActive(true)
    this.rewardPanel.gameObject:SetActive(true)
end

local luckyLevels = {0.2,0.42,0.63,0.83,1}--幸运值条到达档位时实际位置

---刷新幸运值
function this.RefreshLuckyValue()
    if LuckyTurnTableManager.curTreasureType == TreasureType.Lucky then
        LuckyTurnTableManager.SetLuckyValue()
        local data = LuckyTurnTableManager.GetLuckyValue()
        
        this.luckySlider.minValue = 0
        this.luckySlider.maxValue = LuckyTurnTableManager.boxReward_One[5].Values[1][1]
        this.luckyValueNum.text = data--.."/"..LuckyTurnTableManager.boxReward_One[5].Values[1][1]

        --确定档位
        local nowLevel = 5--如果data超过最高档位,认为是最高档位
        for i = 1,5 do
            if data <= LuckyTurnTableManager.boxReward_One[i].Values[1][1] then
                nowLevel = i
                break
            end
        end

        local pLevelValue = 0--上一档值
        local pLuckyLevel = 0--上一档幸运条值
        if nowLevel > 1 then
            pLevelValue = LuckyTurnTableManager.boxReward_One[nowLevel-1].Values[1][1]
            pLuckyLevel = luckyLevels[nowLevel-1]
        end

        local nowLevelValue = LuckyTurnTableManager.boxReward_One[nowLevel].Values[1][1]--当前档值
        local LevelValue = luckyLevels[nowLevel]--当前档幸运条值
        local sliderValue = (data-pLevelValue)/(nowLevelValue-pLevelValue)*(LevelValue-pLuckyLevel)+pLuckyLevel
        this.luckySlider.value = data

    elseif LuckyTurnTableManager.curTreasureType == TreasureType.Advanced then
        LuckyTurnTableManager.SetLuckyValue()
        local data = LuckyTurnTableManager.GetLuckyValue()

        this.luckySlider.minValue = 0
        this.luckySlider.maxValue = LuckyTurnTableManager.boxReward_Two[5].Values[1][1]
        this.luckyValueNum.text = data --.."/"..LuckyTurnTableManager.boxReward_Two[5].Values[1][1]

        --确定档位
        local nowLevel = 5
        for i = 1,5 do
            if data <= LuckyTurnTableManager.boxReward_Two[i].Values[1][1] then
                nowLevel = i
                break
            end
        end

        local pLevelValue = 0--上一档值
        local pLuckyLevel = 0--上一档幸运条值
        if nowLevel > 1 then
            pLevelValue = LuckyTurnTableManager.boxReward_Two[nowLevel-1].Values[1][1]
            pLuckyLevel = luckyLevels[nowLevel-1]
        end

        local nowLevelValue = LuckyTurnTableManager.boxReward_Two[nowLevel].Values[1][1]--当前档值
        local LevelValue = luckyLevels[nowLevel]--当前档幸运条值
        local sliderValue = (data-pLevelValue)/(nowLevelValue-pLevelValue)*(LevelValue-pLuckyLevel)+pLuckyLevel
        this.luckySlider.value = data
    end
end

---刷新信息
function this.RrFreshInfo()
    this.RefreshLuckyValue()
    this.CheckRedPoint()
    this.SetRewardBox()
    this.RewardBgProgress()
    RedpotManager.CheckRedPointStatus(RedPointType.LuckyTurn)
end

---延时遮罩 1按时间
function this.DelayMaskWithTime(delayTime)
    this.maskBG.gameObject:SetActive(true)
    local closeMask = Timer.New(function()
        this.maskBG.gameObject:SetActive(false)
    end,delayTime,1,true)
    closeMask:Start()
end
---延时遮罩 1按bool
function this.DelayMaskWithBool(b)
    if b then
        this.maskBG.gameObject:SetActive(true)
    else
        this.maskBG.gameObject:SetActive(false)
    end
end


return LuckyTurnTablePanel