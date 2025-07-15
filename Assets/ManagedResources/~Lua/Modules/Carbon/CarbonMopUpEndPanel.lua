require("Base/BasePanel")
CarbonMopUpEndPanel = Inherit(BasePanel)
local this=CarbonMopUpEndPanel
local challengeConfig = ConfigManager.GetConfig(ConfigName.ChallengeConfig)
local allRewardList={}
local mapShop = 0
local eliteMonster = nil
local curIndex=1
local isClick=false
local mopUpFightData
local callBack
--初始化组件（用于子类重写）
function CarbonMopUpEndPanel:InitComponent()

    this.carbonName = Util.GetGameObject(self.transform, "Bg/Image/Text"):GetComponent("Text")
    this.sureBtn = Util.GetGameObject(self.transform, "Bg/sureBtn")
    this.rewardGridGo = Util.GetGameObject(self.transform, "Bg/scroll/grid")
    this.rewardScrollGo = Util.GetGameObject(self.transform, "Bg/scroll")
    this.rewardPre = Util.GetGameObject(self.transform, "Bg/mapAreaPre")

end

--绑定事件（用于子类重写）
function CarbonMopUpEndPanel:BindEvent()

    Util.AddClick(this.sureBtn, function()
        if isClick then
            self:ClosePanel()
        else
            PopupTipPanel.ShowTipByLanguageId(10303)
        end
    end)
end

--添加事件监听（用于子类重写）
function CarbonMopUpEndPanel:AddListener()

end

--移除事件监听（用于子类重写）
function CarbonMopUpEndPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function CarbonMopUpEndPanel:OnOpen(...)

    local data={...}
    allRewardList=data[1]
    mapShop = data[2]
    eliteMonster = data[3]
    -- 回调
    if data[4] then
        callBack = data[4]
    end
    curIndex=1
    this.rewardScrollGo:GetComponent("ScrollRect").enabled = false
    this.rewardGridGo:GetComponent("RectTransform").anchoredPosition=Vector2.New(0,0)
    ClearChild(this.rewardGridGo)
    this.ShowPanelData()
    isClick=false
end

-- 扫荡完成遇到云游商人显示提示
function this.ShowTip()
    if mapShop > 0 then
        UIManager.OpenPanel(UIName.TrialBossTipPopup, 5)
    end
    -- 是否有精英怪，
    if eliteMonster and eliteMonster.suddBossId ~= 0 then
        -- 如果有商人先显示商人，0.5秒提示精英怪
        if mapShop > 0 then
            Timer.New(function ()
                UIManager.OpenPanel(UIName.TrialBossTipPopup, 6)
            end, 1.5, 1, true):Start()
        else
            UIManager.OpenPanel(UIName.TrialBossTipPopup, 6)
        end
    end
end

local DText = {
    [1] = GetLanguageStrById(10304),
    [2] = GetLanguageStrById(10305),
    [3] = GetLanguageStrById(10306),
    [4] = GetLanguageStrById(10307),
}


function this.ShowPanelData()
    local curCarbonId = MapManager.curMapId
    local name = challengeConfig[curCarbonId].Name

    local str = ""
    if CarbonManager.difficulty == 1 then
        str =  GetLanguageStrById(10308)
    elseif CarbonManager.difficulty == 2 then
        str =  GetLanguageStrById(10309)
    elseif CarbonManager.difficulty == 3 then
        -- 这玩意有4种难度
        local type = challengeConfig[curCarbonId].DifficultType
        str = DText[type]

    elseif CarbonManager.difficulty == 4 then
        str =  GetLanguageStrById(10310)
    else
        str =  ""
    end



    this.carbonName.text = str .. name
    if curIndex<=#allRewardList then
        local time = Timer.New(function ()
            local go = newObject(this.rewardPre)
            go.transform:SetParent(this.rewardGridGo.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            this.SetItemShow(go,curIndex)
            curIndex=curIndex+1
            if curIndex<=#allRewardList then
                this.ShowPanelData2()
            else
                isClick=true
                this.rewardScrollGo:GetComponent("ScrollRect").enabled = true
                this.ShowTip()
            end
        end, 0.3)
        time:Start()
    end
end
function this.ShowPanelData2()
    if curIndex<=#allRewardList then
        local time = Timer.New(function ()
            local go = newObject(this.rewardPre)
            go.transform:SetParent(this.rewardGridGo.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            this.SetItemShow(go,curIndex)
            curIndex=curIndex+1
            if curIndex<=#allRewardList then
                this.ShowPanelData()
            else
                isClick=true
                this.rewardScrollGo:GetComponent("ScrollRect").enabled = true
                this.ShowTip()
            end
        end, 0.3)
        time:Start()
    else
        this.rewardScrollGo:GetComponent("ScrollRect").enabled = true
    end
end

-- 根据物品列表数据显示物品
function  this.SetItemShow(_parentGo,curIndex)
    local drop=allRewardList[curIndex]
    if drop==nil then return end
    Util.GetGameObject(_parentGo, "bg/areaName"):GetComponent("Text").text=GetLanguageStrById(10311)..curIndex..GetLanguageStrById(10312)
    local itemDataList={}
    itemDataList = BagManager.GetItemListFromTempBag(drop)
    --if drop.itemlist~=nil and #drop.itemlist>0 then
    
    --    for i = 1, #drop.itemlist do
    --        local itemdata={}
    --        itemdata.itemType=1--item
    --        itemdata.backData=drop.itemlist[i]
    --        itemdata.configData=ConfigManager.GetConfigData(ConfigName.ItemConfig, drop.itemlist[i].itemId)
    --        itemdata.name= itemdata.configData.Name
    --        itemdata.frame=GetQuantityImageByquality(itemdata.configData.Quantity)
    --        itemdata.icon=GetResourcePath( itemdata.configData.ResourceID)
    --        itemdata.num=drop.itemlist[i].itemNum
    --        table.insert(itemDataList,itemdata)
    --    end
    --end
    --if drop.equipId~=nil and #drop.equipId>0  then
    
    --    for i = 1, #drop.equipId do
    --        local itemdata={}
    --        itemdata.itemType=2--装备
    --        itemdata.backData=drop.equipId[i]
    --        itemdata.configData=ConfigManager.GetConfigData(ConfigName.ItemConfig, drop.equipId[i].equipId)
    --        itemdata.name=itemdata.configData.Name
    --        itemdata.frame=GetQuantityImageByquality(itemdata.configData.Quantity)
    --        itemdata.icon=GetResourcePath(itemdata.configData.ResourceID)
    --        itemdata.num=1
    --        table.insert(itemDataList,itemdata)
    --    end
    --end
    --if drop.Hero~=nil and #drop.Hero>0  then
    
    --    for i = 1, #drop.Hero do
    --        local itemdata={}
    --        itemdata.itemType=3--英雄
    --        itemdata.backData=drop.Hero[i]
    --        itemdata.configData=ConfigManager.GetConfigData(ConfigName.HeroConfig, drop.Hero[i].heroId)
    --        itemdata.name=itemdata.configData.ReadingName
    --        itemdata.frame=GetHeroQuantityImageByquality(itemdata.configData.Star)
    --        itemdata.icon=GetResourcePath(itemdata.configData.Icon)
    --        itemdata.num=1
    --        table.insert(itemDataList,itemdata)
    --    end
    --end
    local rewardGos={}
    for i = 1, 30 do
        rewardGos[i]=Util.GetGameObject(_parentGo, "rewardPre ("..i..")")
    end
    for i = 1, 30 do
        if i<=#itemDataList then
            this.SetItemData(rewardGos[i], itemDataList[i])
            rewardGos[i]:SetActive(true)
        else
            rewardGos[i]:SetActive(false)
        end
    end
        this.SetGridPosY(#itemDataList)
end
function this.SetItemData(go, itemdata)
    Util.GetGameObject(go, "frame"):GetComponent("Image").sprite=Util.LoadSprite(itemdata.frame)
    local itemIcon = Util.GetGameObject(go, "icon")
    itemIcon:GetComponent("Image").sprite=Util.LoadSprite(itemdata.icon)
    --Util.GetGameObject(go, "name"):GetComponent("Text").text=itemdata.name
    Util.GetGameObject(go, "num"):GetComponent("Text").text=itemdata.num
    local  starGrid = Util.GetGameObject(go, "talismanStar")
    starGrid:SetActive(false)
    if itemdata.itemType==1 then
        if itemdata.configData.ItemType==2 then
            Util.GetGameObject(go.transform, "frameMask"):SetActive(true)
            Util.GetGameObject(go.transform, "frameMask"):GetComponent("Image").sprite =Util.LoadSprite(GetHeroChipQuantityImageByquality(itemdata.configData.Quantity))
        else
            Util.GetGameObject(go.transform, "frameMask"):SetActive(false)
        end
        --BagManager.UpdateBagData(itemdata.backData)
        Util.AddOnceClick(itemIcon, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,itemdata.backData.itemId)
        end)
    elseif itemdata.itemType==2 then
        EquipManager.UpdateEquipData(itemdata.backData)
        Util.AddOnceClick(itemIcon, function()
            UIManager.OpenPanel(UIName.RewardEquipSingleShowPopup,itemdata.backData)
        end)
    elseif itemdata.itemType==3 then
        HeroManager.UpdateHeroDatas(itemdata.backData)
        Util.AddOnceClick(itemIcon, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,itemdata.backData)
        end)
    elseif itemdata.itemType==4 then
        starGrid:SetActive(true)
        SetHeroStars(starGrid, TalismanManager.AllTalismanStartStar[itemdata.backData.equipId])
        TalismanManager.InitUpdateSingleTalismanData(itemdata.backData)
        Util.AddOnceClick(itemIcon, function()
            UIManager.OpenPanel(UIName.RewardTalismanSingleShowPopup,2,"",itemdata.backData.equipId,0,0)
        end)
    end
end
function  this.SetGridPosY(rewardItemNum)
    local yNum = 0
    if rewardItemNum > 8 then
        yNum = 565
    else
        yNum = 787
    end
        local darg=this.rewardGridGo:GetComponent("RectTransform").sizeDelta.y-yNum
        if darg>0 then
            this.rewardGridGo:GetComponent("RectTransform").anchoredPosition=Vector2.New(0,darg)
        end
end
--界面关闭时调用（用于子类重写）
function CarbonMopUpEndPanel:OnClose()

    --time1:Stop()
    --time2:Stop()
    if callBack then callBack() end
    callBack = nil
end

--界面销毁时调用（用于子类重写）
function CarbonMopUpEndPanel:OnDestroy()

end

return CarbonMopUpEndPanel