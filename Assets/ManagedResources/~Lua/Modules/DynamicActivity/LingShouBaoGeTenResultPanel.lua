require("Base/BasePanel")
require("Base/Stack")
LingShouBaoGeTenResultPanel = Inherit(BasePanel)
local this=LingShouBaoGeTenResultPanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local gameSetting=ConfigManager.GetConfig(ConfigName.GameSetting)
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local privilegeConfig=ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local itemId=0
local itemNum=0  --抽卡小号道具数量

local activityId = nil
local singleRecruit = nil
local tenRecruit = nil

local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)

this.contentList={}
this.contentListParent={}
this.isElementDrawPanel=false
local orginLayer
--初始化组件（用于子类重写）
function LingShouBaoGeTenResultPanel:InitComponent()
    orginLayer = 0
    self.bg = Util.GetGameObject(self.gameObject, "effect")
    screenAdapte(self.bg)
    this.btnBack=Util.GetGameObject(self.gameObject, "bottom/backButton")
    this.openTenAgainButton=Util.GetGameObject(self.gameObject, "bottom/openTenAgainButton")
    this.costImage=Util.GetGameObject(self.gameObject, "bottom/openTenAgainButton/Image")
    this.detailImage=Util.GetGameObject(self.gameObject, "Tip")
    this.content1=Util.GetGameObject(self.gameObject,"bottom/openTenAgainButton/Content1")
    this.itemIcon1=Util.GetGameObject(this.content1,"Icon"):GetComponent("Image")
    this.detailImage1=Util.GetGameObject(this.content1,"Tip")
    this.detailText1 = Util.GetGameObject(this.detailImage1, "contentDetailText"):GetComponent("Text")
    this.content3=Util.GetGameObject(self.gameObject,"bottom/openTenAgainButton/Content3")
    this.infoTxt=Util.GetGameObject(this.content3,"info"):GetComponent("Text")
    this.itemIcon3=Util.GetGameObject(this.content3, "icon"):GetComponent("Image")
    this.itemNum3=Util.GetGameObject(this.content3, "num"):GetComponent("Text")
    this.content2=Util.GetGameObject(self.gameObject,"bottom/openTenAgainButton/Content2")
    this.itemIcon2=Util.GetGameObject(this.content2,"Icon"):GetComponent("Image")
    this.itemNum2=Util.GetGameObject(this.content2,"Num"):GetComponent("Text")
    this.tipText=Util.GetGameObject(this.openTenAgainButton, "Text"):GetComponent("Text")
    for i = 1, 10 do
        this.contentList[i]=Util.GetGameObject(self.gameObject, "content/itemAnimEffect"..i.."/image/Kuang/itemName/itemContent")
        this.contentListParent[i]=Util.GetGameObject(self.gameObject, "content/itemAnimEffect"..i)
    end
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShouBaoGe })
end

--绑定事件（用于子类重写）
function LingShouBaoGeTenResultPanel:BindEvent()
    
    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.openTenAgainButton, function ()
        local maxTimesId = lotterySetting[singleRecruit.Id].MaxTimes
        local freeTimesId = lotterySetting[singleRecruit.Id].FreeTimes
        --是否超过每日最大上限
        if PrivilegeManager.GetPrivilegeRemainValue(maxTimesId) < 10 then
            
            PopupTipPanel.ShowTipByLanguageId(11760)
            return
        end
        if BagManager.GetItemCountById(itemId) < itemNum then
            PopupTipPanel.ShowTip(GetLanguageStrById(ItemConfig[itemId].Name)..GetLanguageStrById(10492))
            return
        end
        RecruitManager.RecruitRequest(this.recruitType, function(msg)
            PrivilegeManager.RefreshPrivilegeUsedTimes(maxTimesId,10)--记录抽卡次数
            UIManager.OpenPanel(UIName.PokemonSingleResultPanel,this.recruitType,msg.drop,activityId)  
        end,freeTimesId,itemId,itemNum)
    end)
end

--添加事件监听（用于子类重写）
function LingShouBaoGeTenResultPanel:AddListener()

end

--移除事件监听（用于子类重写）
function LingShouBaoGeTenResultPanel:RemoveListener()

end

function LingShouBaoGeTenResultPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    for i = 1, 10 do
        Util.AddParticleSortLayer(this.contentListParent[i], self.sortingOrder - orginLayer)
    end
    orginLayer = self.sortingOrder

    if this.views and this.itemDataList then
        for index, view in pairs(this.views) do
            view:OnOpen(true,this.itemDataList[index],1.4,true,false,false,self.sortingOrder)
        end
    end

end
--界面打开时调用（用于子类重写）
function LingShouBaoGeTenResultPanel:OnOpen(...)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShouBaoGe})
    local args = { ... }
    this.drop=args[1]
    this.recruitType = args[2]
    activityId = args[3]
    this.detailImage:SetActive(false)
    this.content1:SetActive(false)
    this.content2:SetActive(false)
    this.content3:SetActive(true)

    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",activityId)
    singleRecruit = array[1]
    tenRecruit = array[2]

    local d
    d = RecruitManager.GetExpendData(this.recruitType)  
    itemId = d[1]
    itemNum = d[2]
    this.itemIcon3.sprite=Util.LoadSprite(artResourcesConfig[ItemConfig[itemId].ResourceID].Name)

    this.tipText.gameObject:SetActive(false)
    this.infoTxt.text=GetLanguageStrById(12483)
    this.itemNum3.text= "×"..itemNum

    local itemDataList={}
    itemDataList=BagManager.GetTableByBackDropData(this.drop)

    if not this.views then
        this.views = {}
    end
    for k,v in pairs(this.views) do
        v.gameObject:SetActive(false)
    end

    this.itemDataList = itemDataList
    local dataNum = #itemDataList > 10 and 10 or #itemDataList
    for i = dataNum, 1, -1 do
        if not this.views[i] then
            this.views[i] = SubUIManager.Open(SubUIConfig.ItemView,this.contentList[i].transform)
        end
        this.views[i].gameObject:SetActive(true)
        local curItemData = itemDataList[i]
        local contentGO = this.contentListParent[i]
        this.views[i]:OnOpen(true,curItemData,1.4,true,false,false,self.sortingOrder)
        contentGO:SetActive(true)
    end
end

--界面关闭时调用（用于子类重写）
function LingShouBaoGeTenResultPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function LingShouBaoGeTenResultPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    this.views = nil
    this.contentList={}
    this.contentListParent={}
    this.views = {}
end

return LingShouBaoGeTenResultPanel