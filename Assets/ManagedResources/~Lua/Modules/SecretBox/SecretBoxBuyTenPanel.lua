require("Base/BasePanel")
require("Base/Stack")
SecretBoxBuyTenPanel = Inherit(BasePanel)
local this=SecretBoxBuyTenPanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
--活动抽卡类型（动态的数据）
local drawtType = {
    FindFairySingle = 0,
    FindFairyTen = 0,
}

local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local callList = Stack.New()
this.contentList = {}
this.contentListParent = {}
this.isElementDrawPanel = false
local orginLayer
--初始化组件（用于子类重写）
function SecretBoxBuyTenPanel:InitComponent()

    orginLayer = 0
    self.bg = Util.GetGameObject(self.gameObject, "effect")
    screenAdapte(self.bg)
    this.btnBack = Util.GetGameObject(self.gameObject, "bottom/backButton")
    this.openTenAgainButton = Util.GetGameObject(self.gameObject, "bottom/openTenAgainButton")
    this.costImage = Util.GetGameObject(self.gameObject, "bottom/openTenAgainButton/Image")

    this.detailImage = Util.GetGameObject(self.gameObject, "Tip")
    this.detailText = Util.GetGameObject(this.detailImage, "Text"):GetComponent("Text")

    this.content1 = Util.GetGameObject(self.gameObject,"bottom/openTenAgainButton/Content1")
    this.itemIcon1 = Util.GetGameObject(this.content1,"Icon"):GetComponent("Image")
    this.detailImage1 = Util.GetGameObject(this.content1,"Tip")
    this.detailText1 = Util.GetGameObject(this.detailImage1, "contentDetailText"):GetComponent("Text")

    this.content2 = Util.GetGameObject(self.gameObject,"bottom/openTenAgainButton/Content2")
    this.itemIcon2 = Util.GetGameObject(this.content2,"Icon"):GetComponent("Image")
    this.itemNum2 = Util.GetGameObject(this.content2,"Num"):GetComponent("Text")

    for i = 1, 10 do
        this.contentList[i] = Util.GetGameObject(self.gameObject, "content/itemAnimEffect"..i.."/image/Kuang")--/itemName/itemContent
        this.contentListParent[i] = Util.GetGameObject(self.gameObject, "content/itemAnimEffect"..i)
    end

    -- 关于抽卡的LotterySetting数据
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    drawtType.FindFairySingle = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",1,"ActivityId",curActivityId).Id
    drawtType.FindFairyTen = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",10,"ActivityId",curActivityId).Id
end

--绑定事件（用于子类重写）
function SecretBoxBuyTenPanel:BindEvent()

    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.openTenAgainButton, function ()
        if this.recruitType then
            self:ClosePanel()

            if this.recruitType == drawtType.FindFairyTen then
                --如果道具不足 要做判断
                local d = RecruitManager.GetExpendData(this.recruitType)
                local itemId,itemNum = d[1],d[2]
                if BagManager.GetItemCountById(itemId) < itemNum and PrivilegeManager.GetPrivilegeRemainValue(32) < 10 then--判断道具不足 要根据是否有寻仙玉判断
                    --如果免费次数不足
                    PopupTipPanel.ShowTipByLanguageId(11880)
                    return
                end
            end

            RecruitManager.RecruitRequest(this.recruitType, function(msg)
                UIManager.OpenPanel(UIName.SecretBoxBuyTenPanel,msg.drop,this.recruitType)
                Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
            end)
        else
            if BagManager.GetItemCountById(SecretBoxManager.MainCost[2][1][1]) >= 10 then
                self:ClosePanel()
                if SecretBoxManager.SeasonTime > 1 then
                    SecretBoxManager.GetSecretBoxRewardRequest(SecretBoxManager.typeId[2*SecretBoxManager.SeasonTime], 10)
                end
            else
                UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.GhostRing })
            end

        end
    end)
end

--添加事件监听（用于子类重写）
function SecretBoxBuyTenPanel:AddListener()

end

--移除事件监听（用于子类重写）
function SecretBoxBuyTenPanel:RemoveListener()

end

function SecretBoxBuyTenPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    for i = 1, 10 do
        Util.AddParticleSortLayer(this.contentListParent[i], self.sortingOrder - orginLayer)
    end
    orginLayer = self.sortingOrder

    if this.views and this.itemDataList then
        for index, view in pairs(this.views) do
            view:OnOpen(true,this.itemDataList[index],0.8,true,false,false,self.sortingOrder)
        end
    end

end
--界面打开时调用（用于子类重写）
function SecretBoxBuyTenPanel:OnOpen(...)
    -- this.itemIcon1.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[SecretBoxManager.MainCost[2][1][1]].ResourceID))
    local args = { ... }
    this.drop = args[1]
    this.recruitType = args[2]

    if this.recruitType then
        this.detailImage:SetActive(this.recruitType <= RecruitType.LightDarkSingle)
        this.content1:SetActive(this.recruitType <= RecruitType.LightDarkSingle)
        this.content2:SetActive(this.recruitType == drawtType.FindFairyTen)
        this.detailText.enabled = this.recruitType ~= drawtType.FindFairySingle
        this.detailText1.enabled = this.recruitType ~= drawtType.FindFairySingle

        if this.recruitType <= RecruitType.LightDarkSingle then
            this.itemIcon1.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig, 20).ResourceID))
            this.detailText.text = GetLanguageStrById(11884)
            this.detailText1.text = GetLanguageStrById(11884)
        elseif this.recruitType == drawtType.FindFairyTen then--东海寻仙
            this.FindFairyCountDown(FindFairyManager.GetActivityTime())
            FindFairyManager.SetFreeExtract(10)
            local freeNum = PrivilegeManager.GetPrivilegeRemainValue(32)
            this.itemIcon2.enabled = freeNum < 10
            if freeNum >= 10 then
                this.itemNum2.text = string.format(GetLanguageStrById(10647),freeNum)
            else
                local d = RecruitManager.GetExpendData(this.recruitType)
                local itemId,itemNum = d[1],d[2]
                this.itemIcon2.sprite = SetIcon(itemId)--默认显示妖晶
                this.itemNum2.text = itemNum
            end
        end
    else
        this.detailImage:SetActive(not this.recruitType)
        this.content1:SetActive(not this.recruitType)
        this.content2:SetActive(this.recruitType)
        this.itemIcon1.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig, 20).ResourceID))
        this.detailText.text = GetLanguageStrById(11885)
        this.detailText1.text = GetLanguageStrById(11885)
    end

    local itemDataList = {}
    itemDataList = BagManager.GetTableByBackDropData(this.drop)
    this.openTenAgainButton:GetComponent("Button").enabled = false
    this.btnBack:GetComponent("Button").enabled = false
    callList:Clear()
    callList:Push(function ()
        this.openTenAgainButton:GetComponent("Button").enabled = true
        this.btnBack:GetComponent("Button").enabled = true
    end)
    this.views = {}
    this.itemDataList = itemDataList
    local dataNum = #itemDataList > 10 and 10 or #itemDataList
    for i = dataNum, 1, -1 do
        Util.ClearChild(this.contentList[i].transform)
        this.views[i] = SubUIManager.Open(SubUIConfig.ItemView, this.contentList[i].transform)
        local curItemData = itemDataList[i]
        local contentGO = this.contentListParent[i]
        this.views[i]:OnOpen(true,curItemData,0.8,true,false,false,self.sortingOrder)
        contentGO:SetActive(false)
        callList:Push(function ()
            if curItemData.configData and curItemData.configData.ItemType == 4 and curItemData.configData.Quantity >= gameSetting[1].IfVersion then
                UIManager.OpenPanel(UIName.SecretBoxShowPokemonPanel,curItemData.configData.Id, function ()
                    Timer.New(function ()
                        contentGO:SetActive(true)
                        callList:Pop()()
                    end, 0.2):Start()
                end)
            else
                Timer.New(function ()
                    contentGO:SetActive(true)
                    callList:Pop()()
                end, 0.2):Start()
            end
        end)
    end
    callList:Pop()()
end

--界面关闭时调用（用于子类重写）
function SecretBoxBuyTenPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function SecretBoxBuyTenPanel:OnDestroy()
    this.views = nil
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
            this.openTenAgainButton:SetActive(false)
            PopupTipPanel.ShowTipByLanguageId(11883)
            return
        end
        timeDown = timeDown - 1
    end, 1, -1, true)
    this.timer:Start()
end

return SecretBoxBuyTenPanel