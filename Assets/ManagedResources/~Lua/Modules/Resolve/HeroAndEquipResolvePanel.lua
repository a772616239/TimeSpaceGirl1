require("Base/BasePanel")
HeroAndEquipResolvePanel = Inherit(BasePanel)
local this=HeroAndEquipResolvePanel
local heroEndBtns={}--英雄筛选所有按钮
local equipEndBtns={}--装备筛选所有按钮
local soulPrintEndBtns={}--魂印筛选所有按钮
local equipTreasureEndBtns={}--法宝筛选所有按钮
local tarHero={}--展示英雄数据list
local tarEquip={}--展示装备数据list
local equipTreasureData={}--展示法宝数据list
local soulPrintData={}--展示魂印数据list
local tabType=0--大页签  1 英雄  2  装备
local tabSortType=0--筛选页签
local selectHeroData={}--选择的英雄list did = data
local selectEquipData={}--选择的装备list
local selectEquipTreasureData={}--选择的法宝list
local chooseIdList={}--选择的魂印list

local curSelectBtn--当前选择的底部筛选btn
local isSha=false--筛选按钮状态
local itemMaxList={}--分解获得的物品是否超过上限 物品list
local rewardGroup=ConfigManager.GetConfig(ConfigName.RewardGroup)
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local showList = {}
local endSelectEquipData = {}
local _PanelType = {
    [1] = PanelType.HeartFireStone,
    [2] = PanelType.IronResource,
    [3] = PanelType.requiem,
    [4] = PanelType.StarSoul,
}

local list={}
local orginLayer2=0
local orginLayer=0
--初始化组件（用于子类重写）
function HeroAndEquipResolvePanel:InitComponent()

    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    this.BtnBack = Util.GetGameObject(self.transform, "rightUp/btnBack")
    this.Scrollbar1 = Util.GetGameObject(self.transform, "heroObject/Scrollbar"):GetComponent("Scrollbar")
    this.Scrollbar2 = Util.GetGameObject(self.transform, "equipObject/Scrollbar"):GetComponent("Scrollbar")
    this.Scrollbar3 = Util.GetGameObject(self.transform, "soulPrintObject/Scrollbar"):GetComponent("Scrollbar")
    this.selectHeroBtn = Util.GetGameObject(self.transform, "endTabs/btnHeroGrid/selectBtn")
    this.selectEndBtn = Util.GetGameObject(self.transform, "endTabs/selectBtn")
    for i = 1, 6 do
        heroEndBtns[i]=Util.GetGameObject(self.transform, "endTabs/btnHeroGrid/btnHeroGrid/Btn"..i)
        Util.AddClick( heroEndBtns[i], function()
            if tabSortType == i then
                this.SortTypeClick(0,heroEndBtns[i])--全部
            else
                this.SortTypeClick(i,heroEndBtns[i])
            end
        end)
    end
    for i = 1, 7 do
        equipEndBtns[i]=Util.GetGameObject(self.transform, "endTabs/btnEquipGrid/btnEquipGrid/Btn ("..i..")")
        Util.AddClick(equipEndBtns[i], function()
            if tabSortType == i then
                this.SortTypeClick(0,equipEndBtns[i])--全部
            else
                this.SortTypeClick(i,equipEndBtns[i])
            end
        end)
    end
    for i=1,4 do
        soulPrintEndBtns[i]=Util.GetGameObject(self.transform, "endTabs/btnSoulPrintGrid/btnSoulPrintGrid/Btn"..i)
        Util.AddClick( soulPrintEndBtns[i], function()            
            if tabSortType == i+3 then
                this.SortTypeClick(0,equipEndBtns[i])--全部
            else
                tabSortType = i+3
                this.SortTypeClick(tabSortType,soulPrintEndBtns[i])
            end
        end)
    end
    for i=1,5 do
        equipTreasureEndBtns[i]=Util.GetGameObject(self.transform, "endTabs/btnEquiptreasureGrid/btnEquiptreasureGrid/Btn"..i)
        Util.AddClick( equipTreasureEndBtns[i], function()
            if tabSortType == i then
                this.SortTypeClick(0,equipTreasureEndBtns[i])--全部
            else
                this.SortTypeClick(i,equipTreasureEndBtns[i])
            end
        end)
    end

    this.shaBtn = Util.GetGameObject(self.transform, "endGo/shaBtn")
    this.quickBtn = Util.GetGameObject(self.transform, "endGo/quickBtn")
    this.resolveBtn = Util.GetGameObject(self.transform, "endGo/resolveBtn")
    this.shopBtn = Util.GetGameObject(self.transform, "endGo/shopBtn")
    this.selectText = Util.GetGameObject(self.transform, "endGo/selectText"):GetComponent("Text")
    this.itemRewardPre = Util.GetGameObject(self.transform, "rewardGrid/itemRewardPre")
    this.rewardGridGo = Util.GetGameObject(self.transform, "rewardGrid")
    this.rewardGrid = Util.GetGameObject(self.transform, "rewardGrid/rewardGrid")
    this.rewardGridText = Util.GetGameObject(self.transform, "rewardGrid/Text")
    this.soulPrintScroll=Util.GetGameObject(self.gameObject, "scroll")
    --英雄
    this.cardPre = Util.GetGameObject(self.gameObject, "heroObject/card")
    --this.grid = Util.GetGameObject(self.gameObject, "scroll/grid")
    local v21 = Util.GetGameObject(self.gameObject, "heroObject"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.transform, "heroObject").transform,
            this.cardPre, this.Scrollbar1, Vector2.New(-v21.x*2, -v21.y*2), 1, 5, Vector2.New(19.32,15))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    --装备
    this.equipPre = Util.GetGameObject(self.gameObject, "equipObject/equipPre")
    this.soulPrintPre=Util.GetGameObject(self.gameObject, "soulPrintObject/item")

    local v22 = Util.GetGameObject(self.gameObject, "equipObject"):GetComponent("RectTransform").rect
    this.ScrollView2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.transform, "equipObject").transform,
            this.equipPre, this.Scrollbar2, Vector2.New(-v22.x*2, -v22.y*2), 1, 5, Vector2.New(40, 30))
    this.ScrollView2.moveTween.MomentumAmount = 1
    this.ScrollView2.moveTween.Strength = 1
    local v23 = Util.GetGameObject(self.gameObject, "soulPrintObject"):GetComponent("RectTransform").rect
    this.ScrollView3 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.soulPrintScroll.transform,
            this.soulPrintPre, this.Scrollbar3, Vector2.New(-v23.x*2, -v23.y*2), 1, 5, Vector2.New(40, 50))
    this.ScrollView3.moveTween.MomentumAmount = 1
    this.ScrollView3.moveTween.Strength = 1
    --隐藏显示用
    this.heroObject=Util.GetGameObject(self.gameObject, "heroObject")
    this.equipObject=Util.GetGameObject(self.gameObject, "equipObject")
    this.soulPrintObject=Util.GetGameObject(self.gameObject, "soulPrintObject")
    this.btnHeroGrid=Util.GetGameObject(self.gameObject, "endTabs/btnHeroGrid")
    this.btnEquipGrid=Util.GetGameObject(self.gameObject, "endTabs/btnEquipGrid")
    this.btnSoulPrintGrid=Util.GetGameObject(self.gameObject, "endTabs/btnSoulPrintGrid")
    this.btnEquiptreasureGrid=Util.GetGameObject(self.gameObject, "endTabs/btnEquiptreasureGrid")

    this.endTabs = Util.GetGameObject(self.gameObject, "endTabs")
    this.endTabs:SetActive(false)
    --this.endTabsClose = Util.GetGameObject(self.gameObject, "endTabs/closeBtn")

    this.noneImage= Util.GetGameObject(self.gameObject, "NoneImage")
    chooseIdList={}
end

--绑定事件（用于子类重写）
function HeroAndEquipResolvePanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        if isSha then
            this.shaBtn:GetComponent("Button").enabled = false
            isSha=not isSha
            this.rewardGridGo.transform:DOAnchorPosY(-766, 0, false)
            this.endTabs.transform:DOAnchorPosY(-38.64, 0, false):OnComplete(function()
                this.shaBtn:GetComponent("Button").enabled = true
                this.endTabs:SetActive(false)
                PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
                self:ClosePanel()
            end)
        else
            PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
            self:ClosePanel()
        end
    end)
    Util.AddClick(this.shaBtn, function()
        isSha=not isSha
        this.shaBtn:GetComponent("Button").enabled = false
        --this.endTabsClose:GetComponent("Button").enabled = false
        if isSha then
            this.endTabs:SetActive(true)
            this.rewardGridGo.transform:DOAnchorPosY(-670, 0.5, false)
            this.endTabs.transform:DOAnchorPosY(251.62, 0.5, false):OnComplete(function()
                this.shaBtn:GetComponent("Button").enabled = true
                --this.endTabsClose:GetComponent("Button").enabled = true
            end)
        else
            this.rewardGridGo.transform:DOAnchorPosY(-766, 0.5, false)
            this.endTabs.transform:DOAnchorPosY(-38.64, 0.5, false):OnComplete(function()
                this.shaBtn:GetComponent("Button").enabled = true
                --this.endTabsClose:GetComponent("Button").enabled = true
                this.endTabs:SetActive(false)
            end)
        end
    end)
    --Util.AddClick(this.endTabsClose, function()
    --    this.rewardGridGo.transform:DOAnchorPosY(-766, 0.5, false)
    --    isSha=false
    --    this.shaBtn:GetComponent("Button").enabled = false
    --    this.endTabsClose:GetComponent("Button").enabled = false
    --    this.endTabs.transform:DOAnchorPosY(-38.64, 0.5, false):OnComplete(function()
    --        this.shaBtn:GetComponent("Button").enabled = true
    --        this.endTabsClose:GetComponent("Button").enabled = true
    --        this.endTabs:SetActive(false)
    --    end)
    --end)
    Util.AddClick(this.quickBtn, function()
        this.QuickSelectListData()
    end)
    Util.AddClick(this.resolveBtn, function()
        this.ResolveBtnClickEvent()
    end)
    Util.AddClick(this.shopBtn, function()
        local isActive, errorTip = ShopManager.IsActive(SHOP_TYPE.SOUL_CONTRACT_SHOP)
        if not isActive then
            PopupTipPanel.ShowTip(errorTip or GetLanguageStrById(10528))
            return
        end
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.SOUL_CONTRACT_SHOP)
    end)
end

--添加事件监听（用于子类重写）
function HeroAndEquipResolvePanel:AddListener()

end

--移除事件监听（用于子类重写）
function HeroAndEquipResolvePanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function HeroAndEquipResolvePanel:OnOpen(_tabType)
    tabType=_tabType
end
function HeroAndEquipResolvePanel:OnShow()
    tabSortType=0
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = _PanelType[tabType] })
    this.GetTabTypeShoePanel(tabType)
end
--隐藏 grid
function this.GetTabTypeShoePanel(_tabType)
    this.heroObject:SetActive(false)
    this.equipObject:SetActive(false)
    this.btnHeroGrid:SetActive(false)
    this.btnEquipGrid:SetActive(false)
    this.btnSoulPrintGrid:SetActive(false)
    this.btnEquiptreasureGrid:SetActive(false)
    this.shopBtn:SetActive(false)
    this.soulPrintScroll:SetActive(false)
    this.soulPrintObject:SetActive(false)
    if _tabType==1 then
        this.heroObject:SetActive(true)
        this.btnHeroGrid:SetActive(true)
        this.shopBtn:SetActive(true)
        this.SortTypeClick(tabSortType,heroEndBtns[1])
    elseif _tabType==2 then
        this.equipObject:SetActive(true)
        this.btnEquipGrid:SetActive(true)
        this.SortTypeClick(tabSortType,equipEndBtns[1])
    elseif _tabType==3 then
        this.equipObject:SetActive(true)
        this.btnEquiptreasureGrid:SetActive(true)
        this.SortTypeClick(tabSortType,equipTreasureEndBtns[1])
    elseif _tabType==4 then
        this.btnSoulPrintGrid:SetActive(true)
        this.soulPrintScroll:SetActive(true)
        this.soulPrintObject:SetActive(true)
        this.SortTypeClick(tabSortType,soulPrintEndBtns[1])
    end
end
--展示数据
function this.SortTypeClick(_sortType,_btn)
    curSelectBtn=_btn
    
    if _sortType and _sortType > 0  then
        tabSortType = _sortType
    else 
        tabSortType = 0
    end

    this.EndTabBtnSelect(_btn)

    this.CleanSelectList()
    if tabType == 4 then
        list={}
        soulPrintData= BagManager.GetAllSoulPrintData(tabSortType)
        this.soulPrintChooseType=tabSortType      
        if(not soulPrintData or #soulPrintData<1) then
            this.noneImage:SetActive(true)
        else
            this.noneImage:SetActive(false)
        end
        this.selectText.text = GetLanguageStrById(11775).."0/"..#soulPrintData
        this.ScrollView3:SetData(soulPrintData, function (index, go)
            this:SetSoulPrintData(go, soulPrintData[index],index)
            table.insert(list,go)
        end)

        --特效层级重设
    for i=1,#list do
        Util.AddParticleSortLayer(list[i], this.sortingOrder - orginLayer2)
    end   
    orginLayer2 = this.sortingOrder
    orginLayer = this.sortingOrder
    end

end

--设置魂印循环滚动数据
function this:SetSoulPrintData(_go, _itemData,index)
    _go.gameObject:SetActive(true)
    local chooseBtn = Util.GetGameObject(_go.gameObject, "chooseBtn")
    local quality = Util.GetGameObject(_go.gameObject, "quality"):GetComponent("Image")
    local circle = Util.GetGameObject(_go.gameObject, "circle"):GetComponent("Image")
    local icon = Util.GetGameObject(_go.gameObject, "icon"):GetComponent("Image")
    local name = Util.GetGameObject(_go.gameObject, "name"):GetComponent("Text")
    local level = Util.GetGameObject(_go.gameObject, "level"):GetComponent("Text")
    local chooseImage = Util.GetGameObject(_go.gameObject, "chooseImage")
    quality.sprite = Util.LoadSprite(_itemData.frame)--GetQuantityImageByquality(_itemData.quality))
    icon.sprite = Util.LoadSprite(_itemData.icon)
    circle.sprite = Util.LoadSprite(SoulPrintSpriteByQuantity[_itemData.quality].circle)
    name.text = _itemData.itemConfig.Name
    level.gameObject:SetActive(false)
    chooseImage:SetActive(_itemData.isSelect)
    Util.AddOnceClick(chooseBtn, function()
        if (_itemData.isSelect) then
            _itemData.isSelect = false
            
            for i=1,#chooseIdList do
                if chooseIdList[i] == _itemData.id then
                    table.remove(chooseIdList,i)
                    break
                end
            end       
            soulPrintData[index].isSelect = false 
            
        else
            _itemData.isSelect = true
            table.insert(chooseIdList,_itemData.id)
            soulPrintData[index].isSelect = true 
        end 
        this.UpdataPanelRewardAndSelectText()
        chooseImage:SetActive(_itemData.isSelect)
    end)
end

--上部页签排序
function this.UpTabBtnSelect(_index,_btn)
    this.selectUpBtn.transform:SetParent(_btn.transform)
    this.selectUpBtn.transform.localScale = Vector3.one
    this.selectUpBtn.transform.localPosition=Vector3.zero
    if _index == 1 then
        this.selectUpBtnHeroImage:SetActive(true)
        this.selectUpBtnEquipImage:SetActive(false)
    elseif _index == 2 then
        this.selectUpBtnHeroImage:SetActive(false)
        this.selectUpBtnEquipImage:SetActive(true)
    elseif _index == 3 then
        this.selectUpBtnHeroImage:SetActive(false)
        this.selectUpBtnEquipImage:SetActive(true)
    end
end
--下部页签排序
function this.EndTabBtnSelect(_btn)
    if tabType == 1 then
        this.selectEndBtn:SetActive(false)
        this.selectHeroBtn:SetActive(tabSortType > 0)
        this.selectHeroBtn.transform:SetParent(_btn.transform)
        this.selectHeroBtn.transform.localScale = Vector3.one
        this.selectHeroBtn.transform.localPosition=Vector3.zero
    else
        this.selectHeroBtn:SetActive(false)
        this.selectEndBtn:SetActive(tabSortType > 0)
        this.selectEndBtn.transform:SetParent(_btn.transform)
        this.selectEndBtn.transform.localScale = Vector3.one
        this.selectEndBtn.transform.localPosition=Vector3.zero
    end
    --Util.GetGameObject(this.selectEndBtn.transform, "Text"):GetComponent("Text").text = btnText
end

--计算奖励 和 已选择数量
function this.UpdataPanelRewardAndSelectText()
    local allRewardData={}
    if tabType == 4 then
        this.selectText.text = GetLanguageStrById(11775)..LengthOfTable(chooseIdList).."/"..#soulPrintData
        for i, v in pairs(chooseIdList) do
            local rewardGroupId = tonumber(itemConfig[v].ResolveReward)
            if rewardGroup[rewardGroupId] then
                local ShowItemlist = rewardGroup[rewardGroupId].ShowItem
                if ShowItemlist and #ShowItemlist > 0 then
                    for i=1, #ShowItemlist do
                        local curReward={}
                        curReward.id=ShowItemlist[i][1]
                        curReward.num=ShowItemlist[i][2]
                        curReward.itemConfig=itemConfig[curReward.id]
                        if allRewardData[curReward.id]==nil then
                            allRewardData[curReward.id]=curReward
                        else
                            allRewardData[curReward.id].num=allRewardData[curReward.id].num+ curReward.num
                        end
                    end
                end
            end
        end
    end
    itemMaxList={}
    --实例化分解可得奖励
    Util.ClearChild(this.rewardGrid.transform)
    for i, v in pairs(allRewardData) do
        local go=newObject(this.itemRewardPre)
        go.transform:SetParent(this.rewardGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition=Vector3.zero
        Util.GetGameObject(go.transform, "Image"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(v.itemConfig.ResourceID))
        Util.GetGameObject(go.transform, "Text"):GetComponent("Text").text="X"..PrintWanNum2(v.num)
        go:SetActive(true)
        if BagManager.GetItemCountById(v.id)+v.num>v.itemConfig.ItemNumlimit then
            table.insert(itemMaxList,v.itemConfig.Name)
        end
    end
    if LengthOfTable(allRewardData)>0 then
        this.rewardGridText:SetActive(true)
    else
        this.rewardGridText:SetActive(false)
    end
end

--清空已选择的英雄和装备list
function this.CleanSelectList()
    selectHeroData={}
    selectEquipData={}
    selectEquipTreasureData = {}
    chooseIdList={}
    this.UpdataPanelRewardAndSelectText()
end

--快速选择英雄 或者 装备
function this.QuickSelectListData()
   if tabType == 4 then
        chooseIdList={}
        local tempchooseIdList={}
        for k, v in pairs(soulPrintData) do
            if LengthOfTable(chooseIdList)<30 then
                table.insert(chooseIdList,v.id)
                table.insert(tempchooseIdList,v.id)
            else
                break
            end
        end
        if tempchooseIdList and #tempchooseIdList > 0 then 
            for n,m in pairs(soulPrintData) do
                m.isSelect=false
                for i=1,#tempchooseIdList do
                    if tempchooseIdList[i] == m.id then
                        table.remove(tempchooseIdList,i)
                        m.isSelect=true
                        break
                    end
                end
            end
        end
        this.ScrollView3:SetData(soulPrintData, function (index, go)
            this:SetSoulPrintData(go, soulPrintData[index],index)
        end)
    end
    this.UpdataPanelRewardAndSelectText()
end

function this.SendBackResolveReCallBack(drop)
    local isShowReward=false
    if drop.itemlist~=nil and #drop.itemlist>0 then
        for i = 1, #drop.itemlist do
            if drop.itemlist[i].itemNum>0 then
                isShowReward=true
                break
            end
        end
    end
    if isShowReward then
        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function ()
            BagManager.OnShowTipDropNumZero(drop)
        end)
    else
        BagManager.OnShowTipDropNumZero(drop)
    end
    if tabType== 4 then
            --移除魂印
        SoulPrintManager.RemoveSoulPrint(chooseIdList)
        local soulPrint= SoulPrintManager.GetSoulPrintQualityDataByType(this.soulPrintChooseType)
        soulPrintData=SoulPrintManager.GetSoulPrintAndSort(soulPrint)
        this.selectText.text = GetLanguageStrById(11775).."0/"..#soulPrintData
        --this.SortSoulPrintData(soulPrintData)
        --this.ScrollView3:SetData(soulPrintData, function (index, go)
        --    this:SetSoulPrintData(go, soulPrintData[index],index)
        --end)
    end
    this.CleanSelectList()
    --刷新界面

    this.SortTypeClick(tabSortType,curSelectBtn)
    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
end
--分解按钮事件处理
function this.ResolveBtnClickEvent()
    local curResolveAllItemList={}
    local isSoulPrintShowSure=false
    local type=-1
    if tabType==4 then
        isSoulPrintShowSure=false
        type=1
        local temp = {}

        for i=1,#chooseIdList do  
            if temp[chooseIdList[i]] and temp[chooseIdList[i]] >=1 then
                temp[chooseIdList[i]] = temp[chooseIdList[i]] + 1
            else
                temp[chooseIdList[i]] = 1
            end
            if not isSoulPrintShowSure then
                for i=1,#soulPrintData do
                    if soulPrintData[i].id == chooseIdList[i] and soulPrintData[i].quality >= 4 then
                        isSoulPrintShowSure=true
                        break 
                    end
                end
            end           
        end

        local index=1
        for k,v in pairs(temp) do
            local item={}
            item.itemId = k
            item.itemNum = v
            curResolveAllItemList[index] = item
            index = index+1
        end
    end
    if isSoulPrintShowSure then
        if isSoulPrintShowSure then
            local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "isSoulPrintShowSure")
            local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
            if (isPopUp ~= currentTime) then
                MsgPanel.ShowTwo(GetLanguageStrById(11780), nil, function(isShow)
                    if (isShow) then
                        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                        RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .."isSoulPrintShowSure", currentTime)
                    end
                    if #itemMaxList>0 then--是否分解物品有超过物品上限的
                        this.GetItemIsBeyondMaxNum(type,curResolveAllItemList)
                    else
                        NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)
                            this.SendBackResolveReCallBack(drop)
                        end)
                    end
                end,nil,nil,nil,true)
            else
                if #itemMaxList>0 then--是否分解物品有超过物品上限的
                    this.GetItemIsBeyondMaxNum(type,curResolveAllItemList)
                else
                    NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)
                        this.SendBackResolveReCallBack(drop)
                    end)
                end
            end
        end
    else
        if #curResolveAllItemList>0 then
            if #itemMaxList>0 then--是否分解物品有超过物品上限的
                this.GetItemIsBeyondMaxNum(type,curResolveAllItemList)
            else
                NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)
                    this.SendBackResolveReCallBack(drop)
                end)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(11781)
        end
    end
end
function this.GetItemIsBeyondMaxNum(type,curResolveAllItemList)
    if #itemMaxList>0 then--是否分解物品有超过物品上限的
        local itemMaxNumStr=""
        for i = 1, #itemMaxList do
            if i==#itemMaxList then
                itemMaxNumStr=itemMaxNumStr..itemMaxList[i]
            else
                itemMaxNumStr=itemMaxNumStr..itemMaxList[i].."、"
            end
        end
        MsgPanel.ShowTwo(itemMaxNumStr..GetLanguageStrById(11782),nil, function()

            NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)

                this.SendBackResolveReCallBack(drop)
            end)
        end)
    end
end
--界面关闭时调用（用于子类重写）
function HeroAndEquipResolvePanel:OnClose()

    tabSortType = 0
end

--界面销毁时调用（用于子类重写）
function HeroAndEquipResolvePanel:OnDestroy()

    SubUIManager.Close(this.UpView)
    this.ScrollView = nil
    this.ScrollView2 = nil
    this.ScrollView3=nil
    list={}
    orginLayer2=0
    orginLayer=0
end

function this.OnSortingOrderChange()
    --特效层级重设
    for i=1,#list do
        Util.AddParticleSortLayer(list[i], this.sortingOrder- orginLayer)
    end   
    orginLayer = this.sortingOrder
end

return HeroAndEquipResolvePanel