----- 魂印合成 -----
local this = {}
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
this.seleceList = {}
this.selsectProperty = {}
this.count = 0--可选择的属性数量

function this:InitComponent(gameObject)
    local CompoundPanel_SoulPrint = Util.GetGameObject(gameObject, "CompoundPanel_SoulPrint")

    --合成材料
    this.medals = Util.GetGameObject(CompoundPanel_SoulPrint, "medals")
    this.medalList = {}
    for i = 1, 3 do
        this.medalList[i] = Util.GetGameObject(this.medals, "frame"..i)
    end
    this.targetMedal = Util.GetGameObject(this.medals, "Targetframe")
    this.targetFrame = Util.GetGameObject(this.targetMedal,"frame")
    this.noTargetFrame = Util.GetGameObject(this.targetMedal,"noFrame")

    this.targetIcon = Util.GetGameObject(this.targetFrame,"icon")
    -- this.targetPro = Util.GetGameObject(this.targetFrame,"pro")
    -- this.targetStarPre = Util.GetGameObject(this.targetFrame,"starPre")
    -- this.targetStar = Util.GetGameObject(this.targetFrame,"star/num")
    --this.targetName=Util.GetGameObject(this.targetFrame,"name")
    this.targetStarGrid = Util.GetGameObject(this.targetFrame,"starGrid")

    --item
    this.property = Util.GetGameObject(CompoundPanel_SoulPrint, "property")

    --随机属性选择 消耗
    this.bgDown = Util.GetGameObject(CompoundPanel_SoulPrint, "bgDown")
    this.scroll = Util.GetGameObject(this.bgDown, "scheme/scroll")

    this.costIcons = Util.GetGameObject(this.bgDown,"scheme/costIcons")
    this.costIcon1 = Util.GetGameObject(this.costIcons,"item1/icon")
    this.costNum1 = Util.GetGameObject(this.costIcons,"item1/num")
    this.costIcon2 = Util.GetGameObject(this.costIcons,"item2/icon")
    this.costNum2 = Util.GetGameObject(this.costIcons,"item2/num")

    --btn
    this.compoundBtn = Util.GetGameObject(this.bgDown, "compoundBtn")
    this.autoCompoundBtn = Util.GetGameObject(this.bgDown, "autoCompoundBtn")
    -- this.hintBtn = Util.GetGameObject(CompoundPanel_SoulPrint, "hintBtn")
    -- this.hintPosition = this.hintBtn:GetComponent("RectTransform").localPosition

    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.property, this.ScrollBar, Vector2.New(this.scroll.transform.rect.width,  this.scroll.transform.rect.height), 1, 2, Vector2.New(80,20))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

function this:BindEvent()
    Util.AddClick(this.compoundBtn, function()
        if LengthOfTable(this.seleceList) == 3 and LengthOfTable(this.selsectProperty) == this.count then
           this.CompoundData()
        else
            if LengthOfTable(this.seleceList) ~= 3 then
                PopupTipPanel.ShowTipByLanguageId(23035)
            else
                PopupTipPanel.ShowTipByLanguageId(23036)
            end
        end
    end)
    Util.AddClick(this.autoCompoundBtn, function()
        local itemlist = MedalManager.MedalDaraByType(0)
        local data = {}
        for i = 1, #itemlist do

            if data[itemlist[i].id] then
                table.insert(data[itemlist[i].id],itemlist[i]) 
            else
                data[itemlist[i].id]={itemlist[i]}
            end
        end
        local number = 0
        local seleceData={}
        local tipsNum = 0
        for index, value in pairs(this.seleceList) do 
            number = number + 1 
            seleceData = value
        end

        for _i, _v in pairs(data) do
            if number ~= 0  then
                for i = 1, #_v do
                    if seleceData.id == _i and  _v[i].medalConfig.Star == seleceData.medalConfig.Star then
                        tipsNum = tipsNum + 1
                    end
                end
            end
        end

        for k, v in pairs(data) do
            if number ~= 0  then
                if #v >= 3 then
                        for i = 1, 3 do
                            if seleceData.id == k and  v[i].medalConfig.Star == seleceData.medalConfig.Star then
                                if this.seleceList[v[i].idDyn] == nil then
                                    this.seleceList[v[i].idDyn] = v[i]
                                    number = number + 1 
                                end
                                if number >= 3 then
                                    this.UpdataPanel(this.seleceList)
                                    return
                                end
                            end
                        end
                end
            else
                if #v >= 3 then
                    for i = 1, 3 do
                        if this.seleceList[v[i].idDyn] == nil then
                            this.seleceList[v[i].idDyn] = v[i]
                            number = number + 1 
                        end
                        if number >= 3 then
                            break
                        end
                    end
                    this.UpdataPanel(this.seleceList)
                    return
                end
            end
        end
        -- if number == 0 then
        --     PopupTipPanel.ShowTipByLanguageId(23149)
        -- else
        --     PopupTipPanel.ShowTipByLanguageId("该芯片数量不足")
        -- end
        PopupTipPanel.ShowTipByLanguageId(23149)
      
    end)

    Util.AddClick(this.hintBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.compoundMedal,this.hintPosition.x,this.hintPosition.y)
    end)

    for i = 1, 3 do
        Util.AddClick(this.medalList[i], function()
            UIManager.OpenPanel(UIName.MedalCompoundChoosePopup,this,this.seleceList)
        end)
    end

end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnSortingOrderChange(_sortingOrder)
    --sortingOrder = _sortingOrder
end

function this:OnShow(_openThisPanel)
    this.seleceList = {}
    this.UpdataPanel(this.seleceList)
    --openThisPanel = _openThisPanel
    if LengthOfTable(this.seleceList) >= 1 then
        this.costIcons:SetActive(true)
    else
        this.costIcons:SetActive(false)
    end
end

function this:OnClose()
    this.seleceList = {}
end

function this:OnDestroy()
end

function this.UpdataPanel(medaList)
    this.Property = {}
    this.selsectProperty = {}
    this.seleceList = medaList
   
    --选中芯片数组
    local begsite = 1
    for k,v in pairs(this.seleceList) do
        this.count = #v.RandomProperty--可选择属性个数
        this.selectMedal = v--选中单个勋章
      
        if v.RandomProperty then
            for i = 1,LengthOfTable(v.RandomProperty) do
                --有空值
                table.insert(this.Property,v.RandomProperty[i])
            end
        end
        this.MedalConfigData = v.medalConfig
        local noframe = Util.GetGameObject(this.medalList[begsite],"noFrame")
        local go = Util.GetGameObject(this.medalList[begsite],"haveFrame")
        go:SetActive(true)
        noframe:SetActive(false)

        this.frame = Util.GetGameObject(go,"frame")
        this.icon = Util.GetGameObject(go,"icon")
        this.starGrid = Util.GetGameObject(go,"starGrid")
        SetHeroStars(this.starGrid,this.MedalConfigData.Star)
        this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(this.MedalConfigData.Quality))
        this.icon:GetComponent("Image").sprite = Util.LoadSprite(v.icon)
        begsite = begsite+1
    end

    --未选满的位置显示默认图片
    if begsite ~= 4 then
        for i = begsite, 3 do
            local noframe = Util.GetGameObject(this.medalList[i],"noFrame")
            local go = Util.GetGameObject(this.medalList[i],"haveFrame")
            go:SetActive(false)
            noframe:SetActive(true)
        end
    end

    --显示目标芯片
    if LengthOfTable(this.seleceList) == 3 then
        local targetId = this.selectMedal.medalConfig.NextId
        this.targetMedalData = MedalConfig[targetId]

        this.targetFrame:SetActive(true)
        this.noTargetFrame:SetActive(false)

        this.targetFrame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(this.targetMedalData.Quality))
        this.targetIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[targetId].ResourceID) )
        SetHeroStars(this.targetStarGrid,this.targetMedalData.Star)
    else
        this.targetFrame:SetActive(false)
        this.noTargetFrame:SetActive(true)

    end

    --属性展示
    this.ScrollView:SetData(this.Property, function(index, Item)
        this.SetData(Item, this.Property[index])
    end)

    --合成消耗
    if LengthOfTable(this.seleceList)>=1 then
        this.costIcons:SetActive(true)
        local cost = this.selectMedal.medalConfig.MergeCostItem
        this.costIcon1:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[cost[1][1]].ResourceID))
        this.costNum1:GetComponent("Text").text = string.format("%s/%s",BagManager.GetItemCountById(cost[1][1]),cost[1][2])
        this.costIcon2:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[cost[2][1]].ResourceID))
        this.costNum2:GetComponent("Text").text = string.format("%s/%s",PrintWanNum(BagManager.GetItemCountById(cost[2][1])),cost[2][2] )
        Util.AddOnceClick(this.costIcon1, function ()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, cost[1][1])
        end)
        Util.AddOnceClick(this.costIcon2, function ()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, cost[2][1])
        end)
    else
        this.costIcons:SetActive(false)
    end
end

function this.SetData(Item,propertyData)
    Item:SetActive(true)
    this.icon = Util.GetGameObject(Item,"icon")
    this.value = Util.GetGameObject(Item,"value")
    local lockBtn = Util.GetGameObject(Item,"lockBtn")
    local lockBtnImage = Util.GetGameObject(Item,"lockBtn/Image")
    local PropertyConfigData = PropertyConfig[propertyData.id]
    this.icon:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfigData.BuffShow)
    this.value:GetComponent("Text").text = string.format("%s:<color=#FFD12B> %s</color>",GetLanguageStrById(PropertyConfigData.Info),GetPropertyFormatStr(PropertyConfigData.Style,propertyData.value))

    if this.selsectProperty[propertyData] then
        lockBtnImage:SetActive(true)
     else
        lockBtnImage:SetActive(false)
     end
    Util.AddOnceClick(lockBtn, function()  
        --todo同一属性不能重复选择
        if this.selsectProperty[propertyData] then
            this.selsectProperty[propertyData] = nil
            lockBtnImage:SetActive(false)
        else
            for k,v in pairs(this.selsectProperty)do
                if propertyData.id == k.id then
                    PopupTipPanel.ShowTipByLanguageId(23037)
                    return
                end
            end

            if LengthOfTable(this.selsectProperty) < this.count then
                this.selsectProperty[propertyData] = propertyData
                lockBtnImage:SetActive(true)
            else
                PopupTipPanel.ShowTipByLanguageId(23038)
            end
        end
    end)
end

function this.CompoundData()
    local _medalId = {}
    local lockPropertyId = {}
    for k,v in pairs(this.seleceList)do
        table.insert(_medalId,v.idDyn)
    end

    for k,v in pairs(this.selsectProperty)do
        table.insert(lockPropertyId,v)
    end

    MedalManager.CompoundMedal(_medalId,lockPropertyId,function()
        this.seleceList = {}
        this.UpdataPanel(this.seleceList)
    end)

    --TODO
    --随机属性选择不能有重复的
end

return this