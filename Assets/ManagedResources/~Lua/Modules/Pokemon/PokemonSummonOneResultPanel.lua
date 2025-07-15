require("Base/BasePanel")
PokemonSummonOneResultPanel = Inherit(BasePanel)
local this=PokemonSummonOneResultPanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local privilegeConfig=ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local itemNum=0  --抽卡小号道具数量
local isFree=false
local itemId = 0
local RecruitMaxtimesId = 0
local freeTimesId = 0
--活动抽卡类型（动态的数据）
local drawtType={
    FindFairySingle=0,
}

local YaojingCallPrivilegeId = 2006
local orginLayer
local itemViewList = {}
--初始化组件（用于子类重写）
function PokemonSummonOneResultPanel:InitComponent()
    orginLayer = 10
    self.bg = Util.GetGameObject(self.gameObject, "effect")
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft, panelType = PanelType.ElementDrawCard })
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
    this.detailText = Util.GetGameObject(this.detailImage, "Text"):GetComponent("Text")    
end

--绑定事件（用于子类重写）
function PokemonSummonOneResultPanel:BindEvent()

    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.openOneAgainButton, function ()
        local currLottery = ConfigManager.GetConfigData(ConfigName.LotterySetting,RecruitType.LingShowSingle)
        local freeTimesId = currLottery.FreeTimes
        local freeTime=0
        if freeTimesId > 0 then
            freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        end
        --是否超过每日最大上限
        if freeTime==0 then
            
            if PrivilegeManager.GetPrivilegeRemainValue(RecruitMaxtimesId) < 1 then
                PopupTipPanel.ShowTipByLanguageId(11760)
                 return
            end
            
        --是否妖晶,是否超过每日妖晶最大上限
            if itemId == 16 then
                if PrivilegeManager.GetPrivilegeRemainValue(YaojingCallPrivilegeId) < 1 then
                    PopupTipPanel.ShowTipByLanguageId(23094)
                     return         
                end
            end
            
        end
        if not isFree then
            if BagManager.GetItemCountById(itemId) < itemNum then
                PopupTipPanel.ShowTip(GetLanguageStrById(ItemConfig[itemId].Name)..GetLanguageStrById(10492))
                return
            end
        end
        
        RecruitManager.RecruitRequest(this.recruitType, function(msg)
            PrivilegeManager.RefreshPrivilegeUsedTimes(RecruitMaxtimesId,1)--记录抽卡次数
            if itemId == 16 and not isFree then
                PrivilegeManager.RefreshPrivilegeUsedTimes(YaojingCallPrivilegeId,1)--记录妖晶抽卡次数
            end
            UIManager.OpenPanel(UIName.PokemonSingleResultPanel,this.recruitType,msg.drop)
            --CheckRedPointStatus(RedPointType.QianKunBox)
        end,freeTimesId,itemId,itemNum)
    end)
end

--添加事件监听（用于子类重写）
function PokemonSummonOneResultPanel:AddListener()

end

--移除事件监听（用于子类重写）
function PokemonSummonOneResultPanel:RemoveListener()

end

function PokemonSummonOneResultPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
    if this.view then
        this.view:OnOpen(true,this.itemDataList[1],1.4,true,false,false,self.sortingOrder)
    end
end
--界面打开时调用（用于子类重写）
function PokemonSummonOneResultPanel:OnOpen(...)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShou})
    local args = { ... }
    this.drop=args[1]
    this.recruitType = args[2]
    this.detailImage:SetActive(true)
    this.content3:SetActive(true)
    --获取免费次数
    local currLottery= ConfigManager.GetConfigData(ConfigName.LotterySetting,RecruitType.LingShowSingle)
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
        --是否激活特权
        local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(3004)   
        if itemId == 16 and isActive then
            local currPrivilege = privilegeConfig[3004]
            itemNum = itemNum * (1+currPrivilege.Condition[1][2]/10000)
        end
        if itemId ==16 then
            this.tipText.gameObject:SetActive(true)
            this.tipText.text=string.format(GetLanguageStrById(23095),PrivilegeManager.GetPrivilegeRemainValue(YaojingCallPrivilegeId), PrivilegeManager.GetPrivilegeNumber(YaojingCallPrivilegeId))
        else
            this.tipText.gameObject:SetActive(false)
        end
        this.itemIcon3.sprite=Util.LoadSprite(artResourcesConfig[ItemConfig[itemId].ResourceID].Name)  
        this.itemNum3.text=  "×"..itemNum
    end
    this.itemDataList = {}
    this.itemDataList = BagManager.GetTableByBackDropData(this.drop)
    --抽奖赠送物品
    local tenConfig = lotterySetting[RecruitType.LingShowSingle]
    local itemid = 0
    local itemnum = 0
    local ishave = false
    if tenConfig then
        itemid = tenConfig.TenTimesMustGetItem[1][1]
        itemnum = tenConfig.TenTimesMustGetItem[1][2]
    end
    for key, value in pairs(this.itemDataList) do
        if ishave == false and value.sId == itemid and value.num == itemnum then
            table.removebyvalue(this.itemDataList,value)
            ishave = true
        end
    end
    this.detailText.text = string.format(GetLanguageStrById(12482),itemnum,ItemConfig[itemid].Name)
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
function PokemonSummonOneResultPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function PokemonSummonOneResultPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    this.view = nil
    itemViewList = {}
end

return PokemonSummonOneResultPanel