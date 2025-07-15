require("Base/BasePanel")
QianKunBoxBuyOnePanel = Inherit(BasePanel)
local this = QianKunBoxBuyOnePanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
-- local iconsData = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotteryRewardConfig,"Pool",4401)
local artConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local privilegeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local recType = {}

--活动抽卡类型（动态的数据）
local drawtType = {
    FindFairySingle = 0,
}

local orginLayer
--初始化组件（用于子类重写）
function QianKunBoxBuyOnePanel:InitComponent()

    orginLayer = 10
    self.bg = Util.GetGameObject(self.gameObject, "effect")
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft, panelType = PanelType.ElementDrawCard })
    screenAdapte(self.bg)
    this.btnBack = Util.GetGameObject(self.gameObject, "bottom/backButton")
    this.content = Util.GetGameObject(self.gameObject, "content")
    this.openOneAgainButton = Util.GetGameObject(self.gameObject, "bottom/openOneAgainButton")

    this.detailImage = Util.GetGameObject(self.gameObject, "Tip")
    this.detailText = Util.GetGameObject(this.detailImage, "Text"):GetComponent("Text")

    this.content1 = Util.GetGameObject(self.gameObject,"bottom/openOneAgainButton/Content1")
    this.itemIcon1 = Util.GetGameObject(this.content1, "Icon"):GetComponent("Image")
    this.detailImage1 = Util.GetGameObject(this.content1, "Tip")
    this.detailText1 = Util.GetGameObject(this.detailImage1, "contentDetailText"):GetComponent("Text")

    this.content3 = Util.GetGameObject(self.gameObject,"bottom/openOneAgainButton/Content3")
    this.itemIcon3 = Util.GetGameObject(this.content3, "icon"):GetComponent("Image")
    this.itemNum3 = Util.GetGameObject(this.content3, "num"):GetComponent("Text")

    this.content2 = Util.GetGameObject(self.gameObject,"bottom/openOneAgainButton/Content2")
    this.itemIcon2 = Util.GetGameObject(this.content2, "Icon"):GetComponent("Image")
    this.itemNum2 = Util.GetGameObject(this.content2,"Num"):GetComponent("Text")

    -- 关于抽卡的LotterySetting数据
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.QianKunBox)
    drawtType.FindFairySingle = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",1,"ActivityId",curActivityId).Id
end

--绑定事件（用于子类重写）
function QianKunBoxBuyOnePanel:BindEvent()

    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.openOneAgainButton, function ()
        local d = RecruitManager.GetExpendData(this.recruitType)
        local maxtimesId = lotterySetting[this.recruitType].MaxTimes
        local freeTimesId = lotterySetting[this.recruitType].FreeTimes
        if(BagManager.GetItemCountById(1002) >= 1 or BagManager.GetItemCountById(16) >= 200) then
            local recruitOne = function()
                self:ClosePanel()
                RecruitManager.RecruitRequest(this.recruitType, function(msg)
                    PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,1)--记录抽卡次数
                    UIManager.OpenPanel(UIName.QianKunBoxBuyOnePanel,msg.drop,this.recruitType,recType)
                    CheckRedPointStatus(RedPointType.QianKunBox)
                end,freeTimesId)
            end
            local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..recType[2])
            if state == 0 and d[1] == 16 then
                UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,this.recruitType,recruitOne)
            else
                recruitOne()
            end
        else
            --UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.DemonCrystal })--应跳到充值界面，现在是用之前的货币换取妖晶
            PopupTipPanel.ShowTipByLanguageId(11139)
            self:ClosePanel()
        end
    end)
end

--添加事件监听（用于子类重写）
function QianKunBoxBuyOnePanel:AddListener()

end

--移除事件监听（用于子类重写）
function QianKunBoxBuyOnePanel:RemoveListener()

end

function QianKunBoxBuyOnePanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder

    if this.view then
        this.view:OnOpen(true,this.itemDataList[1],0.8,true,false,false,self.sortingOrder)
    end
end
--界面打开时调用（用于子类重写）
function QianKunBoxBuyOnePanel:OnOpen(...)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.QianKunBox })
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

    this.detailText.text = GetLanguageStrById(12227)

    Util.ClearChild(Util.GetTransform(this.content, "itemContent1"))
    this.view = nil
    this.itemDataList = {}
    this.itemDataList = BagManager.GetTableByBackDropData(this.drop)
    this.view = SubUIManager.Open(SubUIConfig.ItemView,Util.GetTransform(this.content, "itemContent1"))
    this.view:OnOpen(true,this.itemDataList[1],0.8,true,false,false,self.sortingOrder)

    this.openOneAgainButton:GetComponent("Button").enabled=false
    local time = Timer.New(function ()
        this.openOneAgainButton:GetComponent("Button").enabled=true
        local itemDataList=BagManager.GetTableByBackDropData(this.drop)
        if itemDataList and #itemDataList>0 then
            local singleItemConfigData=itemDataList[1].configData
            if singleItemConfigData and singleItemConfigData.ItemType==4 and  singleItemConfigData.Quantity>=gameSetting[1].IfVersion then
                UIManager.OpenPanel(UIName.SecretBoxShowPokemonPanel,singleItemConfigData.Id)
            end
        end
    end, 0.5)
    time:Start()

    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.QianKunBoxRefreshBtn)
end
--界面关闭时调用（用于子类重写）
function QianKunBoxBuyOnePanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function QianKunBoxBuyOnePanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    this.view = nil
end

return QianKunBoxBuyOnePanel