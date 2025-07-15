require("Base/BasePanel")
MedalTeachPopup = Inherit(BasePanel)
local this = MedalTeachPopup
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local MedalRefineLock = ConfigManager.GetConfig(ConfigName.MedalRefineLock)
local MedalConfigData
local selectLock = {}
this.isOk = true

--初始化组件（用于子类重写）
function MedalTeachPopup:InitComponent()

    this.describe = Util.GetGameObject(self.gameObject,"bg/describe")
    this.frame = Util.GetGameObject(this.describe,"frame")
    this.icon = Util.GetGameObject(this.describe,"frame/icon")
    this.name = Util.GetGameObject(this.describe,"name/text")
    this.base = Util.GetGameObject(this.describe,"base")
    this.baseIcon = Util.GetGameObject(this.base,"icon")
    this.baseName = Util.GetGameObject(this.base,"name")
    this.baseValue = Util.GetGameObject(this.base,"value")

    --洗练前
    this.randomBefore = Util.GetGameObject(self.gameObject,"bg/randomBefore")
    this.costTip = Util.GetGameObject(this.randomBefore,"costTip")
    this.lockcostIcon = Util.GetGameObject(this.randomBefore,"costTip/icon")
    this.lockcostValue = Util.GetGameObject(this.randomBefore,"costTip/icon/value")

    this.beforeIcon1 = Util.GetGameObject(this.randomBefore,"icon1")
    this.beforeIcon1Value = Util.GetGameObject(this.randomBefore,"icon1/value")
    this.beforeIcon1Slider = Util.GetGameObject(this.randomBefore,"icon1/Slider")
    this.beforeIcon1Num = Util.GetGameObject(this.randomBefore,"icon1/Slider/numText")

    this.beforeIcon2 = Util.GetGameObject(this.randomBefore,"icon2")
    this.beforeIcon2Value = Util.GetGameObject(this.randomBefore,"icon2/value")
    this.beforeIcon2Slider = Util.GetGameObject(this.randomBefore,"icon2/Slider")
    this.beforeIcon2Num = Util.GetGameObject(this.randomBefore,"icon2/Slider/numText")

    this.lockBtn1 = Util.GetGameObject(this.randomBefore,"lockBtn1")
    this.lockBtn1Select = Util.GetGameObject(this.randomBefore,"lockBtn1/Image")
    this.lockBtn2 = Util.GetGameObject(this.randomBefore,"lockBtn2")
    this.lockBtn2Select = Util.GetGameObject(this.randomBefore,"lockBtn2/Image")

    --洗练后
    this.randomAfter = Util.GetGameObject(self.gameObject,"bg/randomAfter")
    this.afterIcon1 = Util.GetGameObject(this.randomAfter,"icon1")
    this.afterIcon1Value = Util.GetGameObject(this.randomAfter,"icon1/value")
    this.afterIcon1Slider = Util.GetGameObject(this.randomAfter,"icon1/Slider")
    this.afterIcon1Num = Util.GetGameObject(this.randomAfter,"icon1/Slider/numText")
    this.afterIcon1None = Util.GetGameObject(this.randomAfter,"none1")

    this.afterIcon2 = Util.GetGameObject(this.randomAfter,"icon2")
    this.afterIcon2Value = Util.GetGameObject(this.randomAfter,"icon2/value")
    this.afterIcon2Slider = Util.GetGameObject(this.randomAfter,"icon2/Slider")
    this.afterIcon2Num = Util.GetGameObject(this.randomAfter,"icon2/Slider/numText")
    this.afterIcon2None = Util.GetGameObject(this.randomAfter,"none2")

    --洗练消耗
    this.costIcons = Util.GetGameObject(self.gameObject,"bg/costIcons")
    this.item1Bg = Util.GetGameObject(this.costIcons,"item1")
    this.costIcon1 = Util.GetGameObject(this.costIcons,"item1/icon")
    this.costNum1 = Util.GetGameObject(this.costIcons,"item1/num")
    this.item2Bg = Util.GetGameObject(this.costIcons,"item2")
    this.costIcon2 = Util.GetGameObject(this.costIcons,"item2/icon")
    this.costNum2 = Util.GetGameObject(this.costIcons,"item2/num")


    this.backBtn = Util.GetGameObject(self.gameObject,"backBtn")
    this.Mask = Util.GetGameObject(self.gameObject,"Mask")
    this.helpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.RandomBtn = Util.GetGameObject(self.gameObject,"bg/btn/RandomBtn")
    this.count = Util.GetGameObject(this.RandomBtn,"count")

    this.SaveBtn = Util.GetGameObject(self.gameObject,"bg/btn/SaveBtn")

end
 this.lockId={}
--绑定事件（用于子类重写）
function MedalTeachPopup:BindEvent()

    for i = 1, 2 do
        local locaBtn = Util.GetGameObject(this.randomBefore,"lockBtn"..i)
        Util.AddOnceClick(locaBtn,function()
            local lockSelect = Util.GetGameObject(this.randomBefore,"lockBtn"..i.."/Image")
            if selectLock[locaBtn] then
                selectLock[locaBtn] = nil
                lockSelect:SetActive(false)
            else
                --selectLock[locaBtn]=locaBtn
                selectLock[locaBtn] = this.redomValue[i].id
                lockSelect:SetActive(true)
            end
            MedalTeachPopup:lockCost(selectLock)
        end)
    end

    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.Mask,function()
        self:ClosePanel()
    end)	
    Util.AddClick(this.helpBtn,function()
        
    end)
    Util.AddClick(this.RandomBtn,function()
        this.item3 = true
        this.itemId3 = 0
        if #this.lockId > 0 then
            local costData = MedalRefineLock[#this.lockId].Cost
            if BagManager.GetItemCountById(costData[1]) < costData[2] then
                this.itemId3 = costData[1]
                this.item3 = false
            end
        end
        
        if this.item1 == false then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(23080), GetLanguageStrById(ItemConfig[this.itemId1].Name)))
        elseif this.item3 == false then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(23080), GetLanguageStrById(ItemConfig[this.itemId3].Name)))
        elseif this.item2 == false then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(23080), GetLanguageStrById(ItemConfig[this.itemId2].Name)))
        else
            MedalManager.RefineMedal(this.itemData.idDyn,this.lockId,function() this:ShowItemInfo() end)
        end
    end)
    Util.AddClick(this.SaveBtn,function()
        MedalManager.SaveMedal(this.itemData.idDyn,function() 
            this:ShowItemInfo()
            selectLock = {}
            MedalTeachPopup:lockCost(selectLock)
            for i = 1, 2 do
                local lockSelect = Util.GetGameObject(this.randomBefore,"lockBtn"..i.."/Image")
                lockSelect:SetActive(false)
            end
        end)
    end)
end

--添加事件监听（用于子类重写）
function MedalTeachPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalTeachPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
--1.勋章Id
function MedalTeachPopup:OnOpen(...)
    local args = {...}
    this.itemData = args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalTeachPopup:OnShow()
    --获取临时数据
    this.costTip:SetActive(false)
    selectLock = {}
    for i = 1, 2 do
        local lockSelect = Util.GetGameObject(this.randomBefore,"lockBtn"..i.."/Image")
        lockSelect:SetActive(false)
    end
    MedalTeachPopup:lockCost(selectLock)

    MedalManager.RefineTempPropertyMedal(this.itemData.idDyn,function() this:ShowItemInfo() end)
    --this:ShowItemInfo()
    
end

function MedalTeachPopup:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function MedalTeachPopup:OnClose()
    selectLock = {}
end

--界面销毁时调用（用于子类重写）
function MedalTeachPopup:OnDestroy()

end

function this:ShowItemInfo()
    this.redomValue = this.itemData.RandomProperty--和锁定属性有关,不能放在OnShow里面 因为更新的是ShowItemInfo

    --基本信息
    MedalConfigData = this.itemData.medalConfig
    this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(MedalConfigData.Quality))
    this.icon:GetComponent("Image").sprite = Util.LoadSprite(this.itemData.icon)
    this.name:GetComponent("Text").text = GetStringByEquipQua(MedalConfigData.Quality,string.format(GetLanguageStrById(23055),
     MedalManager.GetQualityName(MedalConfigData.Quality),
      MedalConfigData.Star,
      GetLanguageStrById(MedalConfigData.TypeName)))

    local PropertyConfigData=PropertyConfig[MedalConfigData.BasicAttr[1]]
    this.baseIcon:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfigData.Icon)
    this.baseName:GetComponent("Text").text = GetLanguageStrById(PropertyConfigData.Info)
    this.baseValue:GetComponent("Text").text = "+"..GetPropertyFormatStr(PropertyConfigData.Style,MedalConfigData.BasicAttr[2])

    --自身的随机属性值
    local RandomProperty = this.itemData.RandomProperty
    local randAttr = MedalConfigData.RandAttr
    local randList = {}
    for i = 1, #randAttr do
        randList[randAttr[i][1]] = randAttr[i]
    end 
    this.beforeIcon1:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfig[RandomProperty[1].id].Icon)
    this.beforeIcon1Value:GetComponent("Text").text = GetLanguageStrById(PropertyConfig[RandomProperty[1].id].Info)
    this.beforeIcon1Slider:GetComponent("Slider").value = RandomProperty[1].value/randList[RandomProperty[1].id][3]
    this.beforeIcon1Num:GetComponent("Text").text = string.format("%s/%s",GetProDataStr(RandomProperty[1].id, RandomProperty[1].value),GetProDataStr(randList[RandomProperty[1].id][1],randList[RandomProperty[1].id][3]))
  
    --this.beforeIcon1Slider:GetComponent("Slider").value=tonumber(GetPropertyFormatStr(PropertyConfig[RandomProperty[1].id].Style,RandomProperty[1].value))/randList[RandomProperty[1].id][3]
    --this.beforeIcon1Num:GetComponent("Text").text=string.format("%s/%s",GetPropertyFormatStr(PropertyConfig[RandomProperty[1].id].Style,RandomProperty[1].value),randList[RandomProperty[1].id][3])
    if MedalConfigData.RefineAttrNum == 1 then
        this.beforeIcon2:SetActive(false)
    else
        this.beforeIcon2:SetActive(true)
        this.beforeIcon2:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfig[RandomProperty[2].id].Icon)
        this.beforeIcon2Value:GetComponent("Text").text = GetLanguageStrById(PropertyConfig[RandomProperty[2].id].Info)
        this.beforeIcon2Slider:GetComponent("Slider").value = RandomProperty[2].value/randList[RandomProperty[2].id][3]
        this.beforeIcon2Num:GetComponent("Text").text = string.format("%s/%s",GetProDataStr(RandomProperty[2].id, RandomProperty[2].value),GetProDataStr(randList[RandomProperty[2].id][1],randList[RandomProperty[2].id][3]))
    end

    --
    if MedalConfigData.RefineAttrNum==1 then
        this.lockBtn2:SetActive(false)
    else
        this.lockBtn2:SetActive(true)
    end

    --调教之后的随机属性值
    this.afterIcon1:SetActive(false)
    this.afterIcon2:SetActive(false)
    this.afterIcon1None:SetActive(false)
    this.afterIcon2None:SetActive(false)
    this.SaveBtn:SetActive(false)
    this.count:GetComponent("Text").text = string.format(GetLanguageStrById(23081), MedalManager.count)
    local AfterRandomProperty = MedalManager.randomProperty
    if AfterRandomProperty and #AfterRandomProperty > 0 then
        --未保存临时数据
        this.SaveBtn:SetActive(true)
        local randAttr = MedalConfigData.RandAttr
        local randList = {}
        for i = 1, #randAttr do
            randList[randAttr[i][1]] = randAttr[i]
        end 
        this.afterIcon1:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfig[AfterRandomProperty[1].id].Icon)
        this.afterIcon1Value:GetComponent("Text").text = GetLanguageStrById(PropertyConfig[AfterRandomProperty[1].id].Info)
        this.afterIcon1Slider:GetComponent("Slider").value = AfterRandomProperty[1].value/randList[AfterRandomProperty[1].id][3]
        this.afterIcon1Num:GetComponent("Text").text = string.format("%s/%s",GetProDataStr(AfterRandomProperty[1].id, AfterRandomProperty[1].value),GetProDataStr(randList[AfterRandomProperty[1].id][1],randList[AfterRandomProperty[1].id][3]))
      
        this.afterIcon1:SetActive(true)
        if #AfterRandomProperty == 2 then
            this.afterIcon2:SetActive(true)
            this.afterIcon2:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfig[AfterRandomProperty[2].id].Icon)
            this.afterIcon2Value:GetComponent("Text").text = GetLanguageStrById(PropertyConfig[AfterRandomProperty[2].id].Info)
            this.afterIcon2Slider:GetComponent("Slider").value = AfterRandomProperty[2].value/randList[AfterRandomProperty[2].id][3]
            this.afterIcon2Num:GetComponent("Text").text = string.format("%s/%s",GetProDataStr(AfterRandomProperty[2].id, AfterRandomProperty[2].value),GetProDataStr(randList[AfterRandomProperty[2].id][1],randList[AfterRandomProperty[2].id][3]))
        end
    else
        --未开始洗练
        this.afterIcon1None:SetActive(true)
        if MedalConfigData.RefineAttrNum == 2 then
            this.afterIcon2None:SetActive(true)
        end
    end

    --洗练消耗
    local cost = MedalConfigData.RefineCost
    this.item1Bg:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(ItemConfig[cost[1][1]].Quantity))
    this.costIcon1:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[cost[1][1]].ResourceID))
    this.costNum1:GetComponent("Text").text = string.format("%s/%s",BagManager.GetItemCountById(cost[1][1]),cost[1][2])
    this.item2Bg:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(ItemConfig[cost[2][1]].Quantity))
    this.costIcon2:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[cost[2][1]].ResourceID))
    this.costNum2:GetComponent("Text").text = string.format("%s/%s",PrintWanNum(BagManager.GetItemCountById(cost[2][1])),cost[2][2])
    if BagManager.GetItemCountById(cost[2][1]) < cost[2][2] then
        local txt1 = string.format("%s",PrintWanNum(BagManager.GetItemCountById(cost[2][1])))
        this.costNum2:GetComponent("Text").text = string.format("<color=#FF0000>%s</color>/%s",txt1,cost[2][2])
    end
    
    Util.AddOnceClick(this.costIcon1, function ()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, cost[1][1])
    end)
    Util.AddOnceClick(this.costIcon2, function ()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, cost[2][1])
    end)

    this.itemId1 = 0
    this.itemId2 = 0
    this.item1 = true--材料
    this.item2 = true

    if BagManager.GetItemCountById(cost[1][1]) < cost[1][2]  then
        this.itemId1 = cost[1][1]
        this.item1 = false
    elseif BagManager.GetItemCountById(cost[2][1]) < cost[2][2] then
        this.itemId2 = cost[2][1]
        this.item2 = false
    end
end

function MedalTeachPopup:lockCost(selectLock)
    this.lockId = {}

    if selectLock ~= nil and LengthOfTable(selectLock) > 0 then
        for k,v in pairs(selectLock)do
            table.insert(this.lockId,v)
        end
        --显示锁定属性的消耗
        this.costTip:SetActive(true)
        local costData = MedalRefineLock[#this.lockId].Cost
        this.lockcostIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[costData[1]].ResourceID))
        this.lockcostValue:GetComponent("Text").text = costData[2]
    else
        this.costTip:SetActive(false)
    end
end

return MedalTeachPopup