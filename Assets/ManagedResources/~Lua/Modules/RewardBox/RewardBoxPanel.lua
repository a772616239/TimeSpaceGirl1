require("Base/BasePanel")
local RewardBoxPanel = Inherit(BasePanel)
local this = RewardBoxPanel

local rewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)

local orginLayer = 0

local itemData--当前物品数据
local curId = nil--当前已选择的物品的Id
local curNum = 1--当前数量
local maxOwnNum = 0--拥有的数量
local maxNum = 0--可选的最大数量（配表）
-- local callBackFun--传值了，未使用
local itemList = {}--克隆预制体列表
local itemIconList = {}--ItemView的List
local tagNum--页签号

local goList = {}--勾选按钮列表
local choosedBgList = {}

--初始化组件（用于子类重写）
function RewardBoxPanel:InitComponent()
	this.mask = Util.GetGameObject(this.gameObject,"mask")
	this.downImage = Util.GetGameObject(this.gameObject,"bg/bottomBar/downImage")
    this.name = Util.GetGameObject(this.gameObject,"bg/name"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(this.gameObject,"btnBack")
    this.scroll = Util.GetGameObject(this.gameObject,"bg/Scroll View/Viewport/Content")
    this.itemPre = Util.GetGameObject(this.scroll,"itemPre")
    this.selectBar = Util.GetGameObject(this.gameObject,"bg/topBar/selectBar")
    this.topTip = Util.GetGameObject(this.gameObject,"bg/topBar/tip")
    this.selectBtn = Util.GetGameObject(this.gameObject,"bg/di/selectBtn")
    this.di = Util.GetGameObject(this.gameObject,"bg/di")
    this.slider = Util.GetGameObject(this.gameObject,"bg/bottomBar/slider")
    this.Slider = Util.GetGameObject(this.gameObject,"bg/bottomBar/slider/Slider")
    this.btnReduce = Util.GetGameObject(this.gameObject,"bg/bottomBar/slider/btnReduce")
    this.btnAdd = Util.GetGameObject(this.gameObject,"bg/bottomBar/slider/btnAdd")
    this.btnSure = Util.GetGameObject(this.gameObject,"bg/bottomBar/slider/btnSure")
    this.btnOk = Util.GetGameObject(this.gameObject,"bg/bottomBar/btnOk")
    this.num = Util.GetGameObject(this.gameObject,"bg/bottomBar/slider/num"):GetComponent("Text")
    this.ButtonPre = Util.GetGameObject(this.gameObject,"bg/ButtonPre")
end

--绑定事件（用于子类重写）
function RewardBoxPanel:BindEvent()
    Util.AddClick(this.mask, function()
		PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
		PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    Util.AddSlider(this.Slider, function(go, value)
        RewardBoxPanel:ShowCompoundNumData2(value)
    end)
    Util.AddClick(this.btnAdd, function()
        if curNum < maxNum and curNum < maxOwnNum then
            curNum = curNum + 1
            RewardBoxPanel:ShowCompoundNumData(curNum)
        end
    end)
    Util.AddClick(this.btnReduce, function()
        if curNum >= 2 then
            curNum = curNum - 1
            RewardBoxPanel:ShowCompoundNumData(curNum)
        end
    end)

    Util.AddClick(this.btnSure, function()
        self:OnBtnSureClick()
    end)
    Util.AddClick(this.btnOk, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RewardBoxPanel:AddListener()
end

--移除事件监听（用于子类重写）
function RewardBoxPanel:RemoveListener()
end


--界面打开时调用（用于子类重写）
function RewardBoxPanel:OnOpen(...)
    local data = {...}
    itemData = data[1]
end

-- 打开，重新打开时回调
function RewardBoxPanel:OnShow()
    curId = nil
    tagNum = 1
    curNum = 1
    this.name.text = GetLanguageStrById(itemData.itemConfig.Name)
    self:RefreshData()
end

function RewardBoxPanel:RefreshData()
    RewardBoxPanel:SetTopBar()
    RewardBoxPanel:SetGiftData(tagNum)
    RewardBoxPanel:SetBottom()
end

--刷新奖励信息
function RewardBoxPanel:SetGiftData(tagNum)--设置奖励列表
    local RewardGroupList = {}

    for index, value in pairs(itemData.itemConfig.RewardGroup) do
        RewardGroupList[index] = value
    end
    for i = 1, #itemList do
        itemList[i]:SetActive(false)
    end
    local showItem = rewardGroup[RewardGroupList[tagNum]].ShowItem
    for i = 1, #showItem do
        local go = itemList[i]
        if not go then
            go = newObject(this.itemPre)
            go.transform:SetParent(this.scroll.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            itemList[i] = go
        end
        go:SetActive(true)
        this:SetSingleGiftData(i, go, RewardGroupList[tagNum])
    end
end

--刷新每一条奖励信息
function RewardBoxPanel:SetSingleGiftData(index, item, boxId, tagNum)
    local icon = Util.GetGameObject(item,"icon")
    local tip = Util.GetGameObject(item,"tip"):GetComponent("Text")
    local select = Util.GetGameObject(item,"select")
    local go = Util.GetGameObject(item,"Go")
	local choosedBg = Util.GetGameObject(item,"choosedBg")
    
    goList[index] = go
	choosedBgList[index] = choosedBg

    item:SetActive(true)
    if not itemIconList[item] then
        local view = SubUIManager.Open(SubUIConfig.ItemView, icon.transform)
        itemIconList[item] = view
    end
    itemIconList[item]:OnOpen(false, rewardGroup[boxId].ShowItem[index], 0.8, false)
    tip.text = GetLanguageStrById(itemConfig[rewardGroup[boxId].ShowItem[index][1]].Name)

    --判断是否是在背包界面打开
    select:SetActive(BagManager.isBagPanel)
    select:GetComponent("Button").interactable = BagManager.isBagPanel

    --判断是否选了该物品
    if curId == rewardGroup[boxId].ShowItem[index][1] then
        go:SetActive(true)
		choosedBg:SetActive(true)
    else
        go:SetActive(false)
		choosedBg:SetActive(false)
    end
    --选择一个物品
    Util.AddOnceClick(select,function()
        if go.activeSelf then
            go:SetActive(false)
			choosedBg:SetActive(false)
            curId = nil
        else
            for index, value in ipairs(goList) do
                if goList[index] then
                    goList[index]:SetActive(false)
					choosedBgList[index]:SetActive(false)
                end
            end
            go:SetActive(true)
			choosedBg:SetActive(true)
            -- curId = rewardGroup[boxId].ShowItem[index][1]
        end
        -- self:SetGiftData(tagNum)
    end)
end
local buttonPreList = {}
--设置头部属性标签显示
function RewardBoxPanel:SetTopBar()
    for i = 1, #buttonPreList do
        buttonPreList[i]:SetActive(false)
    end
    local selfSelectTab
    if itemData.itemConfig.SelfSelectTab then
        selfSelectTab = string.split(GetLanguageStrById(itemData.itemConfig.SelfSelectTab[1]),"#")
    else
        selfSelectTab = string.split(nil,"#")
    end
    if selfSelectTab then
        for i = 1, #selfSelectTab do
            if buttonPreList[i] == nil then
                local go = newObject(this.ButtonPre)
                go.transform:SetParent(this.selectBar.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero
                table.insert(buttonPreList,go)            
            end
            buttonPreList[i]:SetActive(true)
            Util.GetGameObject(buttonPreList[i],"Text"):GetComponent("Text").text = selfSelectTab[i]
            this.button = Util.GetGameObject(buttonPreList[i],"Button")
            Util.AddClick(this.button,function()            
                RewardBoxPanel:SetGiftData(i)
                this.selectBtn.transform.parent = Util.GetGameObject(buttonPreList[i],"Image").transform
                this.selectBtn.transform.localPosition = Vector3.zero
                this.selectBtn.transform.localScale = Vector3.one
            end)
        end
    end
    this.selectBar:SetActive(#itemData.itemConfig.RewardGroup ~= 0)--设置顶部属性条
    this.di:SetActive(#itemData.itemConfig.RewardGroup ~= 0)
    if buttonPreList[1] then
        this.selectBtn.transform.parent = Util.GetGameObject(buttonPreList[1],"Image").transform
        this.selectBtn.transform.localPosition = Vector3.zero
        this.selectBtn.transform.localScale = Vector3.one
    end
end

--设置底部滑动条
function RewardBoxPanel:SetBottom()--设置底部滑动条
    this.num.text = 1
    this.slider:SetActive(BagManager.isBagPanel)
	this.downImage:SetActive(BagManager.isBagPanel)
    this.btnOk:SetActive(false)
    maxOwnNum = BagManager.GetItemCountById(itemData.id)--拥有的最大数量
    maxNum = gameSetting[1].OpenBoxLimits--最大领取数量(配表)
    this.Slider:GetComponent("Slider").value = 1
    if maxOwnNum == 1 then
        this.Slider:GetComponent("Slider").minValue = 0
    elseif maxOwnNum > 1 then
        this.Slider:GetComponent("Slider").minValue = 1
    end
    this.Slider:GetComponent("Slider").maxValue = maxOwnNum >= maxNum and maxNum or maxOwnNum--当前物品总数量
    this.Slider:GetComponent("Slider").interactable = maxOwnNum ~= 1
end

--滑动条显示
function RewardBoxPanel:ShowCompoundNumData(value)
    if value < 1 then
        value = 1
    end
    RewardBoxPanel:ShowCompoundNumData2(value)
    this.Slider:GetComponent("Slider").value = value
end
function RewardBoxPanel:ShowCompoundNumData2(value)
    if value < 1 then
        value = 1
    end
    this.num.text = value
    curNum = value
end

function RewardBoxPanel:OnBtnSureClick()
    if curId then
        local data = {itemData.id,curId,curNum}
        NetManager.UseAndPriceItemRequest(6,data,function (drop)
            --获得英雄表现
            if drop.Hero ~= nil and #drop.Hero > 0 then
                local itemDataList = {}
                local itemDataStarList = {}

                for i = 1, #drop.Hero do
                    local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", drop.Hero[i].heroId)
                    table.insert(itemDataList, heroData)
                    table.insert(itemDataStarList, drop.Hero[i].star)
                end
                self:ClosePanel()
                UIManager.OpenPanel(UIName.PublicGetHeroPanel,itemDataList,itemDataStarList,function ()
                    UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                        Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
                    end)
                end)
            else
                UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                    self:ClosePanel()
                    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
                end)
            end
        end)
    else
        PopupTipPanel.ShowTipByLanguageId(11796)
    end
end

--界面关闭时调用（用于子类重写）
function RewardBoxPanel:OnClose()
    curNum = 1
end

--界面销毁时调用（用于子类重写）
function RewardBoxPanel:OnDestroy()
    itemIconList = {}
    buttonPreList = {}
    goList = {}
	choosedBgList = {}

    itemList = {}
    Util.ClearChild(this.scroll.transform)
end
return RewardBoxPanel