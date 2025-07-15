require("Base/BasePanel")
SecretBoxBuyOnePanel = Inherit(BasePanel)
local this = SecretBoxBuyOnePanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)

-- local _EffectColors = {}

--活动抽卡类型（动态的数据）
local drawtType = {
    FindFairySingle = 0,
}

local orginLayer
--初始化组件（用于子类重写）
function SecretBoxBuyOnePanel:InitComponent()

    orginLayer = 10
    self.bg = Util.GetGameObject(self.gameObject, "effect")

    -- this.effect = Util.GetGameObject(self.gameObject, "content/card_s_Effect") 
    -- for i = 1, this.effect.transform.childCount do
    --     _EffectColors[i] = this.effect.transform:GetChild(i-1).gameObject
    -- end

    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft, panelType = PanelType.ElementDrawCard })
    screenAdapte(self.bg)
    this.btnBack = Util.GetGameObject(self.gameObject, "content/bottom/backButton")
    this.content = Util.GetGameObject(self.gameObject, "content")
    this.openOneAgainButton = Util.GetGameObject(self.gameObject, "content/bottom/openOneAgainButton")

    this.detailImage = Util.GetGameObject(self.gameObject, "content/Tip")
    this.detailText = Util.GetGameObject(this.detailImage, "Text"):GetComponent("Text")

    this.content1 = Util.GetGameObject(self.gameObject,"content/bottom/openOneAgainButton/Content1")
    this.itemIcon1 = Util.GetGameObject(this.content1, "Icon"):GetComponent("Image")
    this.detailImage1 = Util.GetGameObject(this.content1, "Tip")
    this.detailText1 = Util.GetGameObject(this.detailImage1, "contentDetailText"):GetComponent("Text")

    this.content2 = Util.GetGameObject(self.gameObject,"content/bottom/openOneAgainButton/Content2")
    this.itemIcon2 = Util.GetGameObject(this.content2, "Icon"):GetComponent("Image")
    this.itemNum2 = Util.GetGameObject(this.content2,"Num"):GetComponent("Text")

    -- 关于抽卡的LotterySetting数据
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    if curActivityId then
        drawtType.FindFairySingle = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",1,"ActivityId",curActivityId).Id
    end
end

--绑定事件（用于子类重写）
function SecretBoxBuyOnePanel:BindEvent()

    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.openOneAgainButton, function ()
        if this.recruitType then
            if this.recruitType == drawtType.FindFairySingle then
                --如果道具不足 要做判断
                local d = RecruitManager.GetExpendData(this.recruitType)
                local itemId,itemNum = d[1],d[2]
                if BagManager.GetItemCountById(itemId) < itemNum then
                    if PrivilegeManager.GetPrivilegeRemainValue(32) <= 0 then --如果免费次数不足
                        PopupTipPanel.ShowTipByLanguageId(11880)
                        return
                    end
                end
            end
            
            --俱乐部
            if this.recruitType <= RecruitType.LightDarkSingle then
                local d = RecruitManager.GetExpendData(this.recruitType)
                local itemId,itemNum = d[1],d[2]
                if BagManager.GetItemCountById(itemId) < itemNum then
                    PopupTipPanel.ShowTipByLanguageId(11880)
                    return
                end
            end

            RecruitManager.RecruitRequest(this.recruitType, function(msg) --这已经做了道具不足检查了
                UIManager.OpenPanel(UIName.SecretBoxBuyOnePanel,msg.drop,this.recruitType)
                Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
            end)
        else
            if BagManager.GetItemCountById(SecretBoxManager.MainCost[2][1][1]) >= 1 then
                self:ClosePanel()
                if SecretBoxManager.SeasonTime > 1 then
                    SecretBoxManager.GetSecretBoxRewardRequest(SecretBoxManager.typeId[2*SecretBoxManager.SeasonTime-1],1)
                end
            else
                UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.GhostRing })
            end
        end
    end)
end

--添加事件监听（用于子类重写）
function SecretBoxBuyOnePanel:AddListener()

end

--移除事件监听（用于子类重写）
function SecretBoxBuyOnePanel:RemoveListener()

end

function SecretBoxBuyOnePanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder

    if this.view then
        this.view:OnOpen(true,this.itemDataList[1],0.8,true,false,false,self.sortingOrder)
    end
end
--界面打开时调用（用于子类重写）
function SecretBoxBuyOnePanel:OnOpen(...)
    -- this.itemIcon1.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[SecretBoxManager.MainCost[1][1][1]].ResourceID))
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.ElementDrawCard })
    local args = { ... }
    this.drop = args[1]
    this.recruitType = args[2]

    -- this.effect:SetActive(false)
    -- for i = 1,#_EffectColors do
    --     _EffectColors[i]:SetActive(false)
    -- end

    --面板特殊处理
    if this.recruitType then --如果有类型
        this.detailImage:SetActive(this.recruitType <= RecruitType.LightDarkSingle)
        this.content1:SetActive(this.recruitType <= RecruitType.LightDarkSingle)
        this.content2:SetActive(this.recruitType == drawtType.FindFairySingle)
        this.detailText.enabled = this.recruitType ~= drawtType.FindFairySingle
        this.detailText1.enabled = this.recruitType ~= drawtType.FindFairySingle

        if this.recruitType <= RecruitType.LightDarkSingle  then --光暗什么...的抽卡
            this.itemIcon1.sprite = Util.LoadSprite("cn2-X1_icon_item_huiyuanzhaomuka")
            this.detailText.text = GetLanguageStrById(11881)
            this.detailText1.text = GetLanguageStrById(11881)
        elseif this.recruitType == drawtType.FindFairySingle then --东海寻仙
            this.FindFairyCountDown(FindFairyManager.GetActivityTime())
            FindFairyManager.SetFreeExtract(1)
            local d = RecruitManager.GetExpendData(this.recruitType) --动态地根据抽卡类型获取表数据
            local itemId = d[1]
            local itemNum = d[2]
            this.itemIcon2.enabled = (FindFairyManager.myScore)/10%15 ~= 0
            local freeNum = PrivilegeManager.GetPrivilegeRemainValue(32)
            if freeNum > 0 then
                this.itemNum2.text = string.format(GetLanguageStrById(10647),freeNum)
                this.itemIcon2.enabled = false
            else
                this.itemIcon2.enabled = true
                this.itemIcon2.sprite = SetIcon(itemId)--默认显示妖晶
                this.itemNum2.text = itemNum
            end
        end
    else --如果没类型
        this.detailImage:SetActive(not this.recruitType)
        this.content1:SetActive(not this.recruitType)
        this.content2:SetActive(this.recruitType)
        this.itemIcon1.sprite = Util.LoadSprite("r_RareItem_Specail_0008")
        this.detailText.text = GetLanguageStrById(11882)
        this.detailText1.text = GetLanguageStrById(11882)
    end

    Util.ClearChild(Util.GetTransform(this.content, "itemContent1"))
    this.itemDataList = {}
    this.itemDataList = BagManager.GetTableByBackDropData(this.drop)
    this.view = SubUIManager.Open(SubUIConfig.ItemView,Util.GetTransform(this.content, "itemContent1"))
    this.view2 = SubUIManager.Open(SubUIConfig.ItemView,Util.GetTransform(this.content, "itemContent1"))
    this.view:OnOpen(true,this.itemDataList[1],0.8,true,false,false,self.sortingOrder)
    this.view2:OnOpen(true,this.itemDataList[3],0.8,true,false,false,self.sortingOrder)

    this.openOneAgainButton:GetComponent("Button").enabled = false
    local time = Timer.New(function ()
        this.openOneAgainButton:GetComponent("Button").enabled = true
        local itemDataList = BagManager.GetTableByBackDropData(this.drop)
        if itemDataList and #itemDataList > 0 then
            local singleItemConfigData = itemDataList[1].configData
            if singleItemConfigData and singleItemConfigData.ItemType == 4 and singleItemConfigData.Quantity >= gameSetting[1].IfVersion then
                UIManager.OpenPanel(UIName.SecretBoxShowPokemonPanel,singleItemConfigData.Id)
            end
        end

        -- this.effect:SetActive(true)
        -- for i = 1,#_EffectColors do
        --     _EffectColors[i]:SetActive(i == this.itemDataList[1].configData.Quantity)
        -- end

    end, 0.5)
    time:Start()
end
--界面关闭时调用（用于子类重写）
function SecretBoxBuyOnePanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function SecretBoxBuyOnePanel:OnDestroy()
    SubUIManager.Close(this.UpView)

    this.view = nil
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

---寻仙倒计时（活动结束切换表现）
function this.FindFairyCountDown(timeDown)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.timer = Timer.New(function()
        if timeDown < 1 then
            this.timer:Stop()
            this.timer = nil
            this.btnBack:GetComponent("RectTransform"):DOAnchorPosX(0, 0, true)
            this.openOneAgainButton:SetActive(false)
            PopupTipPanel.ShowTipByLanguageId(11883)
            return
        end
        timeDown = timeDown - 1
    end, 1, -1, true)
    this.timer:Start()
end

return SecretBoxBuyOnePanel