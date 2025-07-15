require("Base/BasePanel")
require("Base/Stack")
QianKunBoxBuyTenPanel = Inherit(BasePanel)
local this = QianKunBoxBuyTenPanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local recType = {}

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
function QianKunBoxBuyTenPanel:InitComponent()

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

    this.content3 = Util.GetGameObject(self.gameObject,"bottom/openTenAgainButton/Content3")
    this.itemIcon3 = Util.GetGameObject(this.content3, "icon"):GetComponent("Image")
    this.itemNum3 = Util.GetGameObject(this.content3, "num"):GetComponent("Text")

    this.content2 = Util.GetGameObject(self.gameObject,"bottom/openTenAgainButton/Content2")
    this.itemIcon2 = Util.GetGameObject(this.content2,"Icon"):GetComponent("Image")
    this.itemNum2 = Util.GetGameObject(this.content2,"Num"):GetComponent("Text")

    for i = 1, 10 do
        this.contentList[i] = Util.GetGameObject(self.gameObject, "content/itemAnimEffect"..i.."/image/Kuang")
        this.contentListParent[i] = Util.GetGameObject(self.gameObject, "content/itemAnimEffect"..i)
    end

    -- 关于抽卡的LotterySetting数据
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.QianKunBox)
    drawtType.FindFairySingle = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",1,"ActivityId",curActivityId).Id
    drawtType.FindFairyTen = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",10,"ActivityId",curActivityId).Id
end

--绑定事件（用于子类重写）
function QianKunBoxBuyTenPanel:BindEvent()

    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.openTenAgainButton, function ()
        local d = RecruitManager.GetExpendData(this.recruitType)
        local maxtimesId = lotterySetting[this.recruitType].MaxTimes
        local freeTimesId = lotterySetting[this.recruitType].FreeTimes
        if(BagManager.GetItemCountById(1003)>=10 or BagManager.GetItemCountById(16)>=2000) then
            local recruitTen = function()
                self:ClosePanel()
                RecruitManager.RecruitRequest(this.recruitType, function(msg)
                    PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,10)--记录抽卡次数
                    UIManager.OpenPanel(UIName.QianKunBoxBuyTenPanel,msg.drop,this.recruitType,recType)
                    CheckRedPointStatus(RedPointType.QianKunBox)
                end,freeTimesId)
            end
            local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..recType[2])
            if state==0 and d[1] == 16 then
                UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,this.recruitType,recruitTen)
            else
                recruitTen()
            end
        else
            --UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.DemonCrystal })--应跳到充值界面，现在是用之前的货币换取妖晶
            PopupTipPanel.ShowTipByLanguageId(11139)
            self:ClosePanel()
        end
    end)
end

--添加事件监听（用于子类重写）
function QianKunBoxBuyTenPanel:AddListener()

end

--移除事件监听（用于子类重写）
function QianKunBoxBuyTenPanel:RemoveListener()

end

function QianKunBoxBuyTenPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    for i = 1, 10 do
        Util.AddParticleSortLayer(this.contentListParent[i], self.sortingOrder - orginLayer)
    end
    orginLayer = self.sortingOrder

    if this.views and this.itemDataList then
        for index, view in pairs(this.views) do
            view:OnOpen(true,this.itemDataList[index],0.75,true,false,false,self.sortingOrder)
        end
    end

end
--界面打开时调用（用于子类重写）
function QianKunBoxBuyTenPanel:OnOpen(...)
    local args = { ... }
    this.drop = args[1]
    this.recruitType = args[2]
    recType = args[3]
    this.detailImage:SetActive(true)
    this.content1:SetActive(false)
    this.content2:SetActive(false)
    this.content3:SetActive(true)

    local itemId = 0
    local itemNum = 0
    local d
    d = RecruitManager.GetExpendData(this.recruitType)  
    itemId = d[1]
    itemNum = d[2]
    this.itemIcon3.sprite = Util.LoadSprite(artResourcesConfig[ItemConfig[itemId].ResourceID].Name)
    this.itemNum3.text = tostring(itemNum)

    this.detailText.text = GetLanguageStrById(12228)

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
        this.views[i] = SubUIManager.Open(SubUIConfig.ItemView,this.contentList[i].transform)
        local curItemData = itemDataList[i]
        local contentGO = this.contentListParent[i]
        this.views[i]:OnOpen(true,curItemData,0.75,true,false,false,self.sortingOrder)
        contentGO:SetActive(false)
        callList:Push(function ()
            if curItemData.configData and curItemData.configData.ItemType == 4 and  curItemData.configData.Quantity >= gameSetting[1].IfVersion then
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

    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.QianKunBoxRefreshBtn)
end

--界面关闭时调用（用于子类重写）
function QianKunBoxBuyTenPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function QianKunBoxBuyTenPanel:OnDestroy()
    this.views = nil
end

return QianKunBoxBuyTenPanel