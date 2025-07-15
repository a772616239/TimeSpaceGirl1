----- 装备合成 -----
local this = {}
local sortingOrder = 0
local equipStarsConfig = ConfigManager.GetConfig(ConfigName.EquipStarsConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local TabBox = require("Modules/Common/TabBox")
local _TabData = {
    [1] = {default = "cn2-x1_haoyou_biaoqian_weixuanzhong",        select = "cn2-x1_beibao_xuanzhong_yeqian", name = GetLanguageStrById(22323)},
    [2] = {default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_beibao_xuanzhong_yeqian", name = GetLanguageStrById(22324)},
    [3] = {default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_beibao_xuanzhong_yeqian", name = GetLanguageStrById(22325)},
    [4] = {default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_beibao_xuanzhong_yeqian", name = GetLanguageStrById(22326)},
}
local _TabFontColor = { default = Color.New(152 / 255, 151 / 255, 151 / 255, 1),
                        select = Color.New(255 / 255, 255 / 255, 255 / 255, 1)}
local _TabImagePos = { default = -3,
                        select = -3}
local curIndex = 0
local compoundNum = 0
local compoundMaxNum = 0
--this.tabs = {}
local curNeedEquip = {}
local curSelectEquip = {}
local curSelectGO
local materidaIsCan = false
local bagPosEquips = {} 
local needGoldNum = 0
function this:InitComponent(gameObject)
    this.tabBox = Util.GetGameObject(gameObject, "TabBox")
    this.needGoldText = Util.GetGameObject(gameObject, "titleGo/priceText/needGoldText"):GetComponent("Text")
    this.compoundBtn = Util.GetGameObject(gameObject, "titleGo/compoundBtn")
    this.autoCompoundBtn = Util.GetGameObject(gameObject, "titleGo/autoCompoundBtn")
    this.addBtn = Util.GetGameObject(gameObject, "titleGo/addBtn")
    this.subtractBtn = Util.GetGameObject(gameObject, "titleGo/subtractBtn")
    this.numText = Util.GetGameObject(gameObject, "titleGo/numText"):GetComponent("Text")
    --this.progressText = Util.GetGameObject(gameObject, "titleGo/progressText"):GetComponent("Text")   
    this.needEquip = Util.GetGameObject(gameObject, "titleGo/needEquip")
    this.compoundEquip = Util.GetGameObject(gameObject, "titleGo/compoundEquip")
    --this.progressImage = Util.GetGameObject(gameObject, "titleGo/progress/Image"):GetComponent("Image")

    --for i = 1, 6 do
    --    this.tabs[i] = Util.GetGameObject(gameObject, "Tabs/Btn" .. i)
    --end
    self.scrollItem = Util.GetGameObject(gameObject, "scroll")
    local rootHight = self.scrollItem.transform.rect.height
    local width = self.scrollItem.transform.rect.width

    this.equipPre = Util.GetGameObject(gameObject, "equipPre")
    this.ScrollBar = Util.GetGameObject(gameObject, "Scrollbar"):GetComponent("Scrollbar")
    -- local v2 = Util.GetGameObject(gameObject, "scroll"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "scroll").transform,
            this.equipPre, this.ScrollBar, Vector2.New(width, rootHight), 1, 5, Vector2.New(5,5))---v2.x*2, -v2.y*2
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    -- this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0, 0)
    -- this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(1, 1)
    -- this.ScrollView.rectTransform.offsetMin = Vector2.New(0, 0)
    -- this.ScrollView.rectTransform.offsetMax = Vector2.New(0, 0)

    this.slider = Util.GetGameObject(gameObject, "Slider"):GetComponent("Slider")
end

function this:BindEvent()
    Util.AddClick(this.compoundBtn, function()
        this.Compound()
        
    end)
    Util.AddClick(this.autoCompoundBtn, function()
        this.AutoCompound(curIndex)

    end)
    Util.AddClick(this.addBtn, function()
        this.CompoundNumChange(1)
    end)
    Util.AddClick(this.subtractBtn, function()
        this.CompoundNumChange(2)
    end)
    Util.AddSlider(this.slider.gameObject, function(value)
        this.OnSliderValueChange(value)
    end)
end

--- 滑动条值改变回调
function this.OnSliderValueChange(value)
    this.RefreshCostShow()
end
--- 根据slider值刷新显示
function this.RefreshCostShow()
    -- 合成数量
    compoundNum = this.slider.value
    this.numText.text = compoundNum

    this.ShowGoldNum(equipStarsConfig[curSelectEquip.Star],compoundNum)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold,this.ShowGoldNum0)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold,this.ShowGoldNum0)
end

function this.ShowGoldNum0()
    if needGoldNum > BagManager.GetItemCountById(14) then
        materidaIsCan = false
        this.needGoldText.text = string.format("<color=#FF0011>%s</color>", needGoldNum)
    else
        materidaIsCan = true
        this.needGoldText.text = string.format("<color=#FCF5D3FF>%s</color>", needGoldNum)
    end
end

function this:OnShow(...)
    curIndex = 1
    sortingOrder = 0
    needGoldNum = 0
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData,curIndex)

    this.RefreshRedPoint()
    CheckRedPointStatus(RedPointType.ResearchInstitute_EquipCompound)
end
local sortingOrder = 0
function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end
function this.OnClickTabBtn(_curIndex)
    curIndex = _curIndex
    bagPosEquips = EquipManager.GetEquipCompoundDataByEquipPosition1(curIndex)
    local equipDatas = EquipManager.GetAllSEquipsByPosition(curIndex)

    if equipDatas and #equipDatas > 0 then
        curSelectEquip = equipDatas[1]
    end
    -- local itemList = {}
    this.ScrollView:SetData(equipDatas, function (index, go)
        this.SingleItemDataShow(go, equipDatas[index],equipStarsConfig[equipDatas[index].Star])
        -- itemList[index] = go
    end)
    this.ShowTitleData(equipStarsConfig[curSelectEquip.Star])
    -- DelayCreation(itemList)
end

function this.ShowTitleData(curEquipStarsConfig)
    this.ShowTitleEquipData(this.compoundEquip,curSelectEquip,curEquipStarsConfig)

    --得到静态表中合成当前装备需要的装备
    curNeedEquip = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipConfig,"Position",curSelectEquip.Position,"Star",curSelectEquip.Star - 1)
    this.ShowTitleEquipData(this.needEquip,curNeedEquip,equipStarsConfig[curSelectEquip.Star - 1])--需要的材料

    --得到背包中中合成当前装备需要的装备
    local allCanCompoundEquips = EquipManager.GetBagCompoundEquipDatasByequipSData(curSelectEquip)
    local num = 0 
    for i = 1,#allCanCompoundEquips do
        num = num+allCanCompoundEquips[i].num
    end
    --this.progressText.text = num .. "/" .. equipStarsConfig[curSelectEquip.Star - 1].RankupCount
    --this.progressImage.fillAmount = num / equipStarsConfig[curSelectEquip.Star - 1].RankupCount
    compoundNum = math.floor(num / equipStarsConfig[curSelectEquip.Star - 1].RankupCount)
    compoundMaxNum = math.floor(num / equipStarsConfig[curSelectEquip.Star - 1].RankupCount)

    -- 设置滑动范围
    this.slider.enabled = compoundMaxNum > 1
    this.slider.maxValue = compoundMaxNum
    this.slider.minValue = 0
    -- this.slider.value = compoundMaxNum > 0 and 1 or 0

    this.slider.value = compoundNum

    this.ShowGoldNum(equipStarsConfig[curSelectEquip.Star-1],compoundNum)
end
function this.ShowGoldNum(upEquipStarsConfig,compoundNum)
    local data = equipStarsConfig[curSelectEquip.Star-1]
    needGoldNum = compoundNum * data.RankupResources[1][2]--upEquipStarsConfig.RankupResources[1][2]
    local id = data.RankupResources[1][1]
    if needGoldNum > BagManager.GetItemCountById(id) then
        materidaIsCan = false
        this.needGoldText.text = string.format("<color=#FF0011>%s</color>", needGoldNum)
    else
        materidaIsCan = true
        this.needGoldText.text = string.format("<color=#06FF00>%s</color>", needGoldNum)
    end
    this.numText.text = compoundNum
    this.slider.value = compoundNum

    Util.SetGray(this.addBtn,false)
    Util.SetGray(this.subtractBtn,false)
    this.addBtn:GetComponent("Button").enabled = true
    this.subtractBtn:GetComponent("Button").enabled = true
    if compoundNum >= compoundMaxNum then
        Util.SetGray(this.addBtn,true)
        this.addBtn:GetComponent("Button").enabled = false
    end
    if compoundNum <= 1 then
        Util.SetGray(this.subtractBtn,true)
        this.subtractBtn:GetComponent("Button").enabled = false
    end
    if compoundNum == 0 and compoundMaxNum <= 0 then
        Util.SetGray(this.addBtn,true)
        Util.SetGray(this.subtractBtn,true)
        this.addBtn:GetComponent("Button").enabled = false
        this.subtractBtn:GetComponent("Button").enabled = false
    end
end
function this.ShowTitleEquipData(_go,_itemData,curEquipStarsConfig)
    Util.GetGameObject(_go.transform,"frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(curEquipStarsConfig.Quality))
    Util.GetGameObject(_go.transform,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[_itemData.Id].ResourceID))
    Util.GetGameObject(_go.transform,"name"):GetComponent("Text").text = GetLanguageStrById(itemConfig[_itemData.Id].Name)
    --Util.GetGameObject(_go.transform,"name"):GetComponent("Text").text=_itemData.Name
    SetHeroStars(Util.GetGameObject(_go.transform, "star"), curEquipStarsConfig.Stars)
    Util.AddClick(Util.GetGameObject(_go.transform,"icon"), function()
        UIManager.OpenPanel(UIName.HandBookEquipInfoPanel, _itemData.Id)
    end)
end

function this.SingleItemDataShow(_go,_itemData,curEquipStarsConfig)
    Util.GetGameObject(_go.transform,"frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(curEquipStarsConfig.Quality))
    Util.GetGameObject(_go.transform,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[_itemData.Id].ResourceID))
    Util.GetGameObject(_go.transform,"name"):GetComponent("Text").text = _itemData.Name
    SetHeroStars(Util.GetGameObject(_go.transform, "star"), curEquipStarsConfig.Stars)
    local choosed = Util.GetGameObject(_go.transform, "choosed")
    local choosedBg = Util.GetGameObject(_go.transform, "choosedBg")
    choosed:SetActive(curSelectEquip.Id == _itemData .Id)
    choosedBg:SetActive(curSelectEquip.Id == _itemData .Id)
    local redPoint =  Util.GetGameObject(_go.transform,"redPoint")
    redPoint:SetActive(bagPosEquips[curEquipStarsConfig.Id - 1] and bagPosEquips[curEquipStarsConfig.Id - 1] >= equipStarsConfig[curEquipStarsConfig.Id - 1].RankupCount)
    if curSelectEquip.Id == _itemData .Id then
        curSelectGO = _go
    end
    Util.AddOnceClick(Util.GetGameObject(_go.transform,"icon"), function()
        if curSelectEquip.Id == _itemData .Id then
            return
        else
            curSelectEquip = _itemData
            choosed:SetActive(true)
            choosedBg:SetActive(true)
            if curSelectGO then
                Util.GetGameObject(curSelectGO.transform, "choosed"):SetActive(false)
                Util.GetGameObject(curSelectGO.transform, "choosedBg"):SetActive(false)
                curSelectGO = _go
            end
        end
        this.ShowTitleData(curEquipStarsConfig)
    end)
    Util.AddLongPressClick(Util.GetGameObject(_go.transform,"icon"), function()
        UIManager.OpenPanel(UIName.HandBookEquipInfoPanel, _itemData.Id)
    end, 0.5)
end
--加减方法
function this.CompoundNumChange(type)
    if type == 1 then--加
        compoundNum = compoundNum + 1
    else--减
        compoundNum = compoundNum - 1
    end
    
    this.ShowGoldNum(equipStarsConfig[curSelectEquip.Star],compoundNum)
end
function this.Compound()
    if compoundNum <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10431)
        return
    end
    if not materidaIsCan then
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.Gold })
        return
    end
    NetManager.ComplexEquipRequest(curIndex,curSelectEquip.Star,compoundNum,function(msg)
        UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
            this.OnClickTabBtn(curIndex)
            this.RefreshRedPoint()
            CheckRedPointStatus(RedPointType.ResearchInstitute_EquipCompound)
        end)
    end)
end

function this.AutoCompound(_position)
    --进度剩余的的装备材料的数量
    local curPosEquips = EquipManager.GetEquipCompoundDataByEquipPosition1(_position)
    local bagPosEquips = EquipManager.GetEquipCompoundDataByEquipPosition1(_position)
    --进度需要的消耗材料的数量
    local shengGoldNum = 0
    --进度剩余的的消耗材料的数量
    local bagNums = {}

    --已有的消耗材料数量
    for i = 1, #curPosEquips do
        if equipStarsConfig[i].RankupResources then
            for j = 1, #equipStarsConfig[i].RankupResources do
                bagNums[equipStarsConfig[i].RankupResources[j][1]] = BagManager.GetItemCountById(equipStarsConfig[i].RankupResources[j][1])
            end
        end
    end

    --一种装备一种装备的循环检测 金币能合成的数量 与 背包装备能合成的数量 取最小值 然后扣除临时消耗道具
    --最后所有装备存在curPosEquips  与 之前背包  bagPosEquips 作比较  看合成了什么装备 删除了什么装备  和计算消耗材料
    for i = 1, #curPosEquips do
        local materialEndNum = -1
        --合成的1个 下一个装备的需要的消耗材料的数量
        local materialNums = {}
        --当前已有的消耗材料能合成的下一个装备的数量最大数量
        if equipStarsConfig[i].RankupResources then
            for j = 1, #equipStarsConfig[i].RankupResources do
                local itemId = equipStarsConfig[i].RankupResources[j][1]
                materialNums[itemId] = equipStarsConfig[i].RankupResources[j][2]
                local  curItmeCompoundNums =math.floor( bagNums[itemId] / equipStarsConfig[i].RankupResources[j][2])
                if materialEndNum == -1 then
                    materialEndNum = curItmeCompoundNums
                elseif materialEndNum > curItmeCompoundNums then
                    materialEndNum = curItmeCompoundNums
                end
            end
        end

        if i < #curPosEquips or i == 1 then
            --当前拥有的装备材料能合成的下一个装备的数量
            local curQuEquipCompoundNum = math.floor(curPosEquips[i] / equipStarsConfig[i].RankupCount)
            local endCompoundNum = materialEndNum > curQuEquipCompoundNum and curQuEquipCompoundNum or materialEndNum
            
            for itemId, num in pairs(materialNums) do
                bagNums[itemId] = bagNums[itemId] - endCompoundNum * num
                shengGoldNum = shengGoldNum + endCompoundNum * num
            end
            curPosEquips[i] = curPosEquips[i] -  endCompoundNum * equipStarsConfig[i].RankupCount
            if curPosEquips[i + 1] then
                curPosEquips[i + 1] = curPosEquips[i + 1] + endCompoundNum
            end
        end
    end

    local curRewards = {}
    for i = 1, #curPosEquips do
        local str = ""
        if curPosEquips[i] - bagPosEquips[i] > 0 then
            str = GetLanguageStrById(10432)..i.."           "..curPosEquips[i] - bagPosEquips[i]
            local singleEquipData = {}
            singleEquipData.id = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipConfig,"Position",curIndex,"Star",i).Id
            singleEquipData.num = curPosEquips[i] - bagPosEquips[i]
            table.insert(curRewards,{singleEquipData.id,singleEquipData.num})
        else
            str = str .. GetLanguageStrById(10433)..bagPosEquips[i] - curPosEquips[i]
        end
    end
    
    if shengGoldNum <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10434)
        return
    end
    --BagManager.GetItemCountById(14) -
    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.EquipCompound,shengGoldNum,curRewards,function ()
        NetManager.ComplexEquipRequest(curIndex,0,0,function(msg)
            this.OnClickTabBtn(curIndex)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                -- Game.GlobalEvent:DispatchEvent(GameEvent.ResearchInstitute.OnResearchInstituteRedpointChange)
                this.RefreshRedPoint()
                CheckRedPointStatus(RedPointType.ResearchInstitute_EquipCompound)
            end)
        end)
    end)
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    -- local tabImage = Util.GetGameObject(tab,"Image")
    -- local tabLab = Util.GetGameObject(tab, "Image/Text")
    -- tabImage:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    -- tabImage:GetComponent("Image"):SetNativeSize()
    -- tabLab:GetComponent("Text").text = _TabData[index].name
    -- tabLab:GetComponent("Text").color = _TabFontColor[status]
    -- tabImage.transform.localPosition = Vector3.New( tabImage.transform.localPosition.x, _TabImagePos[status], 0);

    local Unchecked = Util.GetGameObject(tab, "Unchecked")
    local select = Util.GetGameObject(tab, "select")
    Util.GetGameObject(Unchecked,"Text"):GetComponent("Text").text = _TabData[index].name
    Util.GetGameObject(select,"Text"):GetComponent("Text").text = _TabData[index].name
    Unchecked:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].default)

    Unchecked:SetActive(status == "default")
    select:SetActive(status == "select")
end

--切换视图
function this.SwitchView(index)
    this.OnClickTabBtn(index)
end

--刷新tab红点
function this.RefreshRedPoint()
    local box = Util.GetGameObject(this.tabBox,"box")
    for i = 1, 4 do
        Util.GetGameObject(box.transform:GetChild(i-1), "Redpot"):SetActive(EquipManager.RefreshEquipCompoundRedpoint(i))
    end
end

function this:OnClose()
    needGoldNum = 0
end

function this:OnDestroy()
    needGoldNum = 0
end

return this