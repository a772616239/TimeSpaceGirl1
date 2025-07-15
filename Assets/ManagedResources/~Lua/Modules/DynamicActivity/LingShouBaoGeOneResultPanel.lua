require("Base/BasePanel")
LingShouBaoGeOneResultPanel = Inherit(BasePanel)
local this=LingShouBaoGeOneResultPanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local privilegeConfig=ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local itemNum=0  --抽卡小号道具数量
local isFree=false
local itemId = 0
local RecruitMaxtimesId = 0
local freeTimesId = 0
local activityId = nil
local singleRecruit = nil
local tenRecruit = nil
--活动抽卡类型（动态的数据）
local drawtType={
    FindFairySingle=0,
}

local orginLayer
local itemViewList = {}
--初始化组件（用于子类重写）
function LingShouBaoGeOneResultPanel:InitComponent()
    orginLayer = 10
    self.bg = Util.GetGameObject(self.gameObject, "effect")
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShouBaoGe })
    screenAdapte(self.bg)
    this.btnBack=Util.GetGameObject(self.gameObject, "bottom/backButton")
    this.openOneAgainButton=Util.GetGameObject(self.gameObject, "bottom/openOneAgainButton")
    
    this.content3=Util.GetGameObject(self.gameObject,"bottom/openOneAgainButton/Content3")
    this.itemIcon3=Util.GetGameObject(this.content3, "icon"):GetComponent("Image")
    this.itemNum3=Util.GetGameObject(this.content3, "num"):GetComponent("Text")
    this.itemInfo3=Util.GetGameObject(this.content3, "info"):GetComponent("Text")
    this.tipText=Util.GetGameObject(this.openOneAgainButton, "Text"):GetComponent("Text")
    this.content=Util.GetGameObject(self.gameObject, "content")
    this.detailImage=Util.GetGameObject(self.gameObject, "Tip")
end

--绑定事件（用于子类重写）
function LingShouBaoGeOneResultPanel:BindEvent()

    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.openOneAgainButton, function ()
        --是否超过每日最大上限
        if PrivilegeManager.GetPrivilegeRemainValue(RecruitMaxtimesId) < 1 then
            PopupTipPanel.ShowTipByLanguageId(11760)
            return
        end
        if not isFree then
            if BagManager.GetItemCountById(itemId) < itemNum then
                PopupTipPanel.ShowTip(GetLanguageStrById(ItemConfig[itemId].Name)..GetLanguageStrById(10492))
                return
            end
        end
        RecruitManager.RecruitRequest(this.recruitType, function(msg)
            PrivilegeManager.RefreshPrivilegeUsedTimes(RecruitMaxtimesId,1)--记录抽卡次数
            UIManager.OpenPanel(UIName.PokemonSingleResultPanel,this.recruitType,msg.drop,activityId)
        end,freeTimesId,itemId,itemNum)
    end)
end

--添加事件监听（用于子类重写）
function LingShouBaoGeOneResultPanel:AddListener()

end

--移除事件监听（用于子类重写）
function LingShouBaoGeOneResultPanel:RemoveListener()

end

function LingShouBaoGeOneResultPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
    if this.view then
        this.view:OnOpen(true,this.itemDataList[1],1.4,true,false,false,self.sortingOrder)
    end
end
--界面打开时调用（用于子类重写）
function LingShouBaoGeOneResultPanel:OnOpen(...)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShouBaoGe})
    local args = { ... }
    this.drop=args[1]
    this.recruitType = args[2]
    activityId = args[3]
    this.detailImage:SetActive(false)
    this.content3:SetActive(true)
    --获取免费次数
    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",activityId)
    singleRecruit = array[1]
    tenRecruit = array[2]
    local currLottery= ConfigManager.GetConfigData(ConfigName.LotterySetting,singleRecruit.Id)
    freeTimesId=currLottery.FreeTimes
    RecruitMaxtimesId = currLottery.MaxTimes
    local  freeTime=0
    if freeTimesId>0 then
        freeTime= PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
    end
    isFree=freeTime and freeTime >= 1
    if isFree then
        this.itemNum3.gameObject:SetActive(false)
        this.itemIcon3.gameObject:SetActive(false)
        this.itemInfo3.text=GetLanguageStrById(23040)
        this.tipText.gameObject:SetActive(false)
    else
        this.itemNum3.gameObject:SetActive(true)
        this.itemIcon3.gameObject:SetActive(true)
        this.itemInfo3.text=GetLanguageStrById(12480)
        itemId=0
        local d = RecruitManager.GetExpendData(this.recruitType)  
        itemId = d[1]
        itemNum = d[2]

        this.tipText.gameObject:SetActive(false)
        this.itemIcon3.sprite=Util.LoadSprite(artResourcesConfig[ItemConfig[itemId].ResourceID].Name)  
        this.itemNum3.text=  "×"..itemNum
    end
    this.itemDataList = {}
    this.itemDataList = BagManager.GetTableByBackDropData(this.drop)

    if not itemViewList then
        itemViewList = {}
    end 
    for k,v in pairs(itemViewList) do
        v.gameObject:SetActive(false)
    end
    for i = 1, #this.itemDataList do
        if not itemViewList[i] then
            Util.GetTransform(this.content, "itemContent"..i).gameObject:SetActive(true)
            itemViewList[i] = SubUIManager.Open(SubUIConfig.ItemView,Util.GetTransform(this.content, "itemContent"..i))
        end 
        itemViewList[i].gameObject:SetActive(true)
        itemViewList[i]:OnOpen(true,this.itemDataList[i],1.4,true,false,false,self.sortingOrder)
    end
end
--界面关闭时调用（用于子类重写）
function LingShouBaoGeOneResultPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function LingShouBaoGeOneResultPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    this.view = nil
    itemViewList = {}
end

return LingShouBaoGeOneResultPanel