require("Base/BasePanel")
require("Base/Stack")
PokemonSummonTenResultPanel = Inherit(BasePanel)
local this=PokemonSummonTenResultPanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local gameSetting=ConfigManager.GetConfig(ConfigName.GameSetting)
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local privilegeConfig=ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local itemId=0
local itemNum=0  --抽卡小号道具数量
--活动抽卡类型（动态的数据）
-- local drawtType={
--     FindFairySingle=0,
--     FindFairyTen=0,
-- }
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
--local callList = Stack.New()
this.contentList={}
this.contentListParent={}
this.isElementDrawPanel=false
local YaojingCallPrivilegeId = 2006
local orginLayer
--初始化组件（用于子类重写）
function PokemonSummonTenResultPanel:InitComponent()
    orginLayer = 0
    self.bg = Util.GetGameObject(self.gameObject, "effect")
    screenAdapte(self.bg)
    this.btnBack=Util.GetGameObject(self.gameObject, "bottom/backButton")
    this.openTenAgainButton=Util.GetGameObject(self.gameObject, "bottom/openTenAgainButton")
    this.costImage=Util.GetGameObject(self.gameObject, "bottom/openTenAgainButton/Image")
    this.detailImage=Util.GetGameObject(self.gameObject, "Tip")
    this.detailText = Util.GetGameObject(this.detailImage, "Text"):GetComponent("Text")
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
    -- 关于抽卡的LotterySetting数据
    -- local curActivityId=ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.QianKunBox)
    -- drawtType.FindFairySingle=ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",1,"ActivityId",curActivityId).Id
    -- drawtType.FindFairyTen=ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",10,"ActivityId",curActivityId).Id
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})--, panelType = PanelType.ElementDrawCard })
end

--绑定事件（用于子类重写）
function PokemonSummonTenResultPanel:BindEvent()
    
    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.openTenAgainButton, function ()
        local maxTimesId = lotterySetting[RecruitType.LingShowSingle].MaxTimes
        local freeTimesId = lotterySetting[RecruitType.LingShowSingle].FreeTimes
        --是否超过每日最大上限
        if PrivilegeManager.GetPrivilegeRemainValue(maxTimesId) < 10 then
            
            PopupTipPanel.ShowTipByLanguageId(11760)
            return
        end
        --是否妖晶,是否超过每日妖晶最大上限
        if itemId == 16 then
            if PrivilegeManager.GetPrivilegeRemainValue(YaojingCallPrivilegeId) < 10 then
                PopupTipPanel.ShowTipByLanguageId(23094)
                return         
            end
        end
         
            if BagManager.GetItemCountById(itemId) < itemNum then
                PopupTipPanel.ShowTip(GetLanguageStrById(ItemConfig[itemId].Name)..GetLanguageStrById(10492))
                return
            end
        RecruitManager.RecruitRequest(this.recruitType, function(msg)
            PrivilegeManager.RefreshPrivilegeUsedTimes(maxTimesId,10)--记录抽卡次数
            if itemId == 16 then
                PrivilegeManager.RefreshPrivilegeUsedTimes(YaojingCallPrivilegeId,10)--记录妖晶抽卡次数
            end
            UIManager.OpenPanel(UIName.PokemonSingleResultPanel,this.recruitType,msg.drop)  
            --CheckRedPointStatus(RedPointType.QianKunBox)
        end,freeTimesId,itemId,itemNum)
    end)
end

--添加事件监听（用于子类重写）
function PokemonSummonTenResultPanel:AddListener()

end

--移除事件监听（用于子类重写）
function PokemonSummonTenResultPanel:RemoveListener()

end

function PokemonSummonTenResultPanel:OnSortingOrderChange()
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
function PokemonSummonTenResultPanel:OnOpen(...)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShou})
    -- this.itemIcon1.sprite=Util.LoadSprite(GetResourcePath(ItemConfig[SecretBoxManager.MainCost[2][1][1]].ResourceID))
    local args = { ... }
    this.drop=args[1]
    this.recruitType = args[2]
    this.detailImage:SetActive(true)
    this.content1:SetActive(false)
    this.content2:SetActive(false)
    this.content3:SetActive(true)

    local d
    d = RecruitManager.GetExpendData(this.recruitType)  
    itemId = d[1]
    itemNum = d[2]
    this.itemIcon3.sprite=Util.LoadSprite(artResourcesConfig[ItemConfig[itemId].ResourceID].Name)
    local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(3004)
    if itemId == 16 and isActive then
        local currPrivilege = privilegeConfig[3004]
        itemNum = itemNum*(1+currPrivilege.Condition[1][2]/10000)
    end
    if itemId ==16 then
        this.tipText.gameObject:SetActive(true)
        this.tipText.text=string.format(GetLanguageStrById(23095),PrivilegeManager.GetPrivilegeRemainValue(YaojingCallPrivilegeId), PrivilegeManager.GetPrivilegeNumber(YaojingCallPrivilegeId))
    else
        this.tipText.gameObject:SetActive(false)
    end   
    this.infoTxt.text=GetLanguageStrById(12483)
    this.itemNum3.text= "×"..itemNum    

    local itemDataList={}
    itemDataList=BagManager.GetTableByBackDropData(this.drop)
    local tenConfig=lotterySetting[43]
    local id=0
    local num=0
    local ishave=false
    if tenConfig then
        id=tenConfig.TenTimesMustGetItem[1][1]
        num=tenConfig.TenTimesMustGetItem[1][2]
    end

    for key, value in pairs(itemDataList) do
        if ishave==false and value.sId==id and value.num==num then
            table.removebyvalue(itemDataList,value)
            ishave=true
        end
    end
    this.detailText.text = string.format(GetLanguageStrById(12482),num,ItemConfig[id].Name)
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

        -- callList:Push(function ()
        --     if curItemData.configData and curItemData.configData.ItemType==4 and  curItemData.configData.Quantity>=gameSetting[1].IfVersion then
        --         UIManager.OpenPanel(UIName.SecretBoxShowPokemonPanel,curItemData.configData.Id, function ()
        --             Timer.New(function ()
        --                 contentGO:SetActive(true)
        --                 callList:Pop()()
        --             end, 0.2):Start()
        --         end)
        --     else
        --         Timer.New(function ()
        --             contentGO:SetActive(true)
        --             callList:Pop()()
        --         end, 0.2):Start()
        --     end
        -- end)
    end
    --callList:Pop()()
end

--界面关闭时调用（用于子类重写）
function PokemonSummonTenResultPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function PokemonSummonTenResultPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    this.views = nil
    this.contentList={}
    this.contentListParent={}
    this.views = {}
end

return PokemonSummonTenResultPanel