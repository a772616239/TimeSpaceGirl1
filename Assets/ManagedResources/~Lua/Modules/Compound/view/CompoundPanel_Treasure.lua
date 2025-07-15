----- 寶物合成 -----
local this = {}
local sortingOrder=0
local jewelConfig = ConfigManager.GetConfig(ConfigName.JewelConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1)}
local _TabImagePos = { default = -3,
                        select = -10}
local curIndex = 0
local compoundNum = 0
local compoundMaxNum = 0
--this.tabs = {}
local curNeedEquip = {}
local curSelectEquip = {}
local curSelectGO
local materidaIsCan = false
local tabs={}
function this:InitComponent(gameObject)
    this.tabBox = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/TabBox")
    this.needGoldText = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/compoundBtn/needGoldText"):GetComponent("Text")
    this.compoundBtn = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/compoundBtn")
    this.autoCompoundBtn = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/autoCompoundBtn")
    this.addBtn = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/titleGo/addBtn")
    this.subtractBtn = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/titleGo/subtractBtn")
    this.numText = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/titleGo/numText"):GetComponent("Text")
    this.progressText = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/titleGo/progressText"):GetComponent("Text")
    this.needEquip = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/titleGo/needEquip")
    this.compoundEquip = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/titleGo/compoundEquip")
    this.progressImage = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/titleGo/progress/Image"):GetComponent("Image")
    for i = 1, 5 do
        tabs[i] = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/Tabs/grid/Btn" .. i)
    end
    this.selectBtn=Util.GetGameObject(gameObject, "CompoundPanel_Treasure/selectBtn")
    this.equipPre = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/equipPre")
    this.ScrollBar=Util.GetGameObject(gameObject, "CompoundPanel_Treasure/Scrollbar"):GetComponent("Scrollbar")
    local v2 = Util.GetGameObject(gameObject, "CompoundPanel_Treasure/scroll"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "CompoundPanel_Treasure/scroll").transform,
            this.equipPre, this.ScrollBar, Vector2.New(-v2.x*2, -v2.y*2), 1, 5, Vector2.New(50,15))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

function this:BindEvent()
    Util.AddClick(this.compoundBtn, function()
        this.Compound(curIndex)
    end)
    --
    Util.AddClick(this.autoCompoundBtn, function()
        this.AutoCompound(curIndex)
    end)
    Util.AddClick(this.addBtn, function()
        this.CompoundNumChange(1)
    end)
    Util.AddClick(this.subtractBtn, function()
        this.CompoundNumChange(2)
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end
local sortingOrder = 0
function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end
function this:OnShow(...)
    curIndex = 1
    sortingOrder =0
    for i = 1,#tabs do
        local index=i
        Util.GetGameObject(tabs[i], "Image"):GetComponent("Image").sprite=Util.LoadSprite(GetProStrImageByProNum(index))
        Util.AddClick(tabs[i], function()
            this.TreasureBtnClick(tabs[i],index)
        end)
    end
    this.TreasureBtnClick(tabs[1],1)
end


--宝物类型按钮点击事件
function this.TreasureBtnClick(_btn,_curIndex)
    curIndex = _curIndex
    this.SetBtnSelect(_btn)
    this.ShowCurrPosTreasures()
end
--显示当前阵营的宝物
function this.ShowCurrPosTreasures()
    local equipDatas = EquipTreasureManager.GetAllTabletTreasuresByRace(curIndex)
    if equipDatas and #equipDatas > 0 then
        curSelectEquip = equipDatas[1]
    end
    this.ShowTitleData(curSelectEquip)
    this.ScrollView:SetData(equipDatas, function (index, go)
        this.SingleItemDataShow(go, equipDatas[index])
    end)

end

--设置按钮选中
function this.SetBtnSelect(_parObj)
    this.selectBtn.transform:SetParent(_parObj.transform)
    this.selectBtn.transform.localScale = Vector3.one
    this.selectBtn.transform.localPosition=Vector3.zero
end
function this.ShowTitleData(_data)
    local allCanCompoundEquips = EquipTreasureManager.GetBagCompoundEquipDatasByequipSData(_data)
    this.ShowTitleEquipData(this.compoundEquip,curSelectEquip,curSelectEquip.frame,curSelectEquip.Id)
    this.ShowTitleEquipData(this.needEquip,curSelectEquip,curSelectEquip.lowFrame,curSelectEquip.lowId)--需要的材料
    this.progressText.text = #allCanCompoundEquips .. "/" .. curSelectEquip.quaUpCount
    this.progressImage.fillAmount = #allCanCompoundEquips/curSelectEquip.quaUpCount
    compoundNum = math.floor(#allCanCompoundEquips/curSelectEquip.quaUpCount)
    compoundMaxNum = math.floor(#allCanCompoundEquips/curSelectEquip.quaUpCount)
    this.ShowGoldNum(curSelectEquip.costCoin,compoundNum)
end
--显示金币数量
function this.ShowGoldNum(_costData,_num)
    local needGoldNum = _costData[1][2]*_num
    local id=_costData[1][1]
    if needGoldNum > BagManager.GetItemCountById(id) then
        materidaIsCan = false
        this.needGoldText.text = string.format("<color=#FF0011>%s</color>", needGoldNum)
    else
        materidaIsCan = true
        this.needGoldText.text =string.format("<color=#FCF5D3FF>%s</color>", needGoldNum)
    end
    this.numText.text = compoundNum
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
    if compoundNum == 0 then
        Util.SetGray(this.addBtn,true)
        Util.SetGray(this.subtractBtn,true)
        this.addBtn:GetComponent("Button").enabled = false
        this.subtractBtn:GetComponent("Button").enabled = false
    end
end
function this.ShowTitleEquipData(_go,_itemData,_frame,_id)
    Util.GetGameObject(_go.transform,"frame"):GetComponent("Image").sprite=Util.LoadSprite(_frame)
    Util.GetGameObject(_go.transform,"icon"):GetComponent("Image").sprite=Util.LoadSprite(_itemData.icon)
    Util.GetGameObject(_go.transform,"proImg"):GetComponent("Image").sprite=Util.LoadSprite(GetProStrImageByProNum(itemConfig[_itemData.Id].PropertyName))
    Util.GetGameObject(_go.transform,"name"):GetComponent("Text").text=GetLanguageStrById(_itemData.name)
    Util.GetGameObject(_go.transform, "star").gameObject:SetActive(false)
    Util.AddClick(Util.GetGameObject(_go.transform,"icon"), function()
        --UIManager.OpenPanel(UIName.HandBookEquipInfoPanel, _itemData.Id)
        UIManager.OpenPanel(UIName.RewardTalismanSingleShowPopup, 0,nil,_id, 0, 0,nil)
    end)
end

--宝物列表宝物数据显示
function this.SingleItemDataShow(_go,_itemData)
    Util.GetGameObject(_go.transform,"frame"):GetComponent("Image").sprite=Util.LoadSprite(_itemData.frame)
    Util.GetGameObject(_go.transform,"icon"):GetComponent("Image").sprite=Util.LoadSprite(_itemData.icon)
    Util.GetGameObject(_go,"proImg"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(itemConfig[_itemData.Id].PropertyName))
    Util.GetGameObject(_go.transform,"name"):GetComponent("Text").text=GetLanguageStrById(_itemData.name)
    SetHeroStars(Util.GetGameObject(_go.transform, "star"), 0)
    local choosed =Util.GetGameObject(_go.transform, "choosed")
    choosed.gameObject:SetActive(curSelectEquip.Id == _itemData.Id)
    local redPoint =  Util.GetGameObject(_go.transform,"redPoint")
    local haveCount=LengthOfTable(EquipTreasureManager.GetBagCompoundEquipDatasByequipSData(_itemData))
    redPoint:SetActive( haveCount>= _itemData.quaUpCount)
    if curSelectEquip.Id == _itemData .Id then
        curSelectGO = _go
    end
    Util.AddOnceClick(Util.GetGameObject(_go.transform,"icon"), function()
        if curSelectEquip.Id == _itemData .Id then
            return
        else
            curSelectEquip = _itemData
            choosed:SetActive(true)
            if curSelectGO then
                Util.GetGameObject(curSelectGO.transform, "choosed"):SetActive(false)
                curSelectGO = _go
            end
        end
        this.ShowTitleData(_itemData)
    end)
    Util.AddLongPressClick(Util.GetGameObject(_go.transform,"icon"), function()
        --UIManager.OpenPanel(UIName.HandBookEquipInfoPanel, _itemData.Id)
    end, 0.5)
end
--加减方法
function this.CompoundNumChange(type)
    if type == 1 then--加
        compoundNum = compoundNum + 1
    else--减
        compoundNum = compoundNum - 1
    end
    
    this.ShowGoldNum(curSelectEquip.costCoin,compoundNum)
end
function this.Compound()
    
    if compoundNum <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10431)
        return
    end
    if not materidaIsCan then
        PopupTipPanel.ShowTipByLanguageId(12193)
        -- UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.Gold })
        return
    end
    NetManager.ComplexTreasureRequest(curSelectEquip.equipType,curIndex,curSelectEquip.quantity,compoundNum,function(msg)
        for i = 1, #msg.equipIds do
            EquipTreasureManager.RemoveTreasureByIdDyn(msg.equipIds[i])
        end
        UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
            this.ShowCurrPosTreasures()
        end)
    end)
end

 --一种装备一种装备的循环检测 金币能合成的数量 与 背包装备能合成的数量 取最小值 然后扣除临时消耗道具
    --最后所有装备存在curPosEquips  与 之前背包  bagPosEquips 作比较  看合成了什么装备 删除了什么装备  和计算消耗材料
function this.AutoCompound(_position)
    --表数据
    local curPosEquips = EquipTreasureManager.GetAllTabletTreasuresByRaceAndType(_position)--,curSelectEquip.equipType)
    --实际数据
    local curPosEquipsData = EquipTreasureManager.GeEquipTreasureDatas(_position)

    local totalGoldNum = 0  
    --jwelConfig.RankupResourcess对应所有背包数据
    local bagNums = {}
    --循环宝物的表消耗道具，得出对应的背包数据
    for i = 1, #curPosEquips do
        local equipData = curPosEquips[i]
        for j = 1, #equipData.costCoin do
            if not bagNums[equipData.costCoin[j][1]] then
                bagNums[equipData.costCoin[j][1]] = BagManager.GetItemCountById(equipData.costCoin[j][1])
            end
        end
    end

    
    -- for n,m in pairs(bagNums) do
    
    -- end

    --循环宝物的表数据，得到可以合成的宝物数量
    for i = 1, #curPosEquips do
        local equipData = curPosEquips[i]

        --从表消耗道具得出可以合成的数量
        local materialEndNum = -1
        --循环宝物的表消耗数据，得出对应的消耗数据
        for j = 1, #equipData.costCoin do
            --可以合成的宝物数量
            local config = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.JewelConfig,"Location",equipData.equipType,"Level",equipData.quantity-1,"Race",_position)
            local  curItmeCompoundNums = math.floor(bagNums[config.RankupResources[j][1]] / config.RankupResources[j][2])
            if materialEndNum == -1 then
                materialEndNum = curItmeCompoundNums
            elseif materialEndNum > curItmeCompoundNums then
                materialEndNum = curItmeCompoundNums
            end
        end
        

        if materialEndNum > 0  then
            --可消耗宝物的数量   （没有强化，没有精炼，没有装备，同样的位置，品级-1）
            local materialHaveNum= curPosEquipsData[equipData.equipType][equipData.quantity-1]
            
            --可以合成的
            local nextCompoundNum = math.floor(materialHaveNum / equipData.quaUpCount)
            

            --消耗物品可以合成的和材料合成的作比较，取最小值
            local endCompoundNum = materialEndNum > nextCompoundNum and nextCompoundNum or materialEndNum
            

            --如果当前品质宝物可以合成，就把当前品质的id及合成的数量储存，判断下一个品质加上当前合成的是否能多合成
            if endCompoundNum > 0 then
                local config = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.JewelConfig,"Location",equipData.equipType,"Level",equipData.quantity-1,"Race",_position)
                if not config then
                    
                else
                for j = 1, #config.RankupResources do
                    bagNums[config.RankupResources[j][1]] =
                     bagNums[config.RankupResources[j][1]] - endCompoundNum * config.RankupResources[j][2]
                     totalGoldNum = totalGoldNum + endCompoundNum * config.RankupResources[j][2]
                     
                     
                end
               --消耗之后剩余的数量
                
                curPosEquipsData[equipData.equipType][equipData.quantity - 1] = materialHaveNum - (endCompoundNum * equipData.quaUpCount)
                 
                 
                 
                curPosEquipsData[equipData.equipType][equipData.quantity] = curPosEquipsData[equipData.equipType][equipData.quantity] + endCompoundNum
                
                end
            end
        end
    end
    local origiData = EquipTreasureManager.GeEquipTreasureDatas(_position)
    local  endReward={}
    for i, v in pairs(curPosEquipsData) do
        for n, m in pairs(v) do
            
            if m > origiData[i][n] then
                local config = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.JewelConfig,"Location",i,"Level",n,"Race",_position)
                
                table.insert(endReward,{config.Id,m - origiData[i][n]})
            end
        end
    end
    if LengthOfTable(endReward) < 1 then
        PopupTipPanel.ShowTipByLanguageId(12258)
        return
    end 
    --BagManager.GetItemCountById(14) -
    
    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.TreasureCompound,totalGoldNum,endReward,function ()
        NetManager.ComplexTreasureRequest(curSelectEquip.equipType,curIndex,0,0, function(msg)
            for i = 1, #msg.equipIds do
                 EquipTreasureManager.RemoveTreasureByIdDyn(msg.equipIds[i])
            end
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                this.ShowCurrPosTreasures()
            end)
        end)
    end)
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    local tabImage = Util.GetGameObject(tab,"Image")
    tabImage:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabImage:GetComponent("Image"):SetNativeSize()
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
    tabImage.transform.localPosition = Vector3.New( tabImage.transform.localPosition.x, _TabImagePos[status], 0);
end
--切换视图
function this.SwitchView(index)
    this.OnClickTabBtn(index)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this