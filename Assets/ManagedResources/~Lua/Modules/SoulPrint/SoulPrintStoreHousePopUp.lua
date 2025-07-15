require("Base/BasePanel")
SoulPrintStoreHousePopUp = Inherit(BasePanel)
local this = SoulPrintStoreHousePopUp
local chooseNum = 0
local tabs1 = {}
local itemData = {}
local currentDataList = {}
local currentChoose = 0
local chooseIdList = {}
local upLevelItemData = {}
local lastLevelItem = {}
--初始化组件（用于子类重写）
function SoulPrintStoreHousePopUp:InitComponent()
    this.item = Util.GetGameObject(self.gameObject, "item")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.helpBtn= Util.GetGameObject(self.transform, "helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.Scrollbar = Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    this.chooseText = Util.GetGameObject(self.gameObject, "chooseText"):GetComponent("Text")
    this.upLevelBtn = Util.GetGameObject(self.gameObject, "upLevelBtn")
    this.quickEnterBtn = Util.GetGameObject(self.gameObject, "quickEnterBtn")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.quality = Util.GetGameObject(self.gameObject, "soulPrintShow/itemShow/quality"):GetComponent("Image")
    this.icon = Util.GetGameObject(self.gameObject, "soulPrintShow/itemShow/icon"):GetComponent("Image")
    this.level = Util.GetGameObject(self.gameObject, "soulPrintShow/itemShow/level"):GetComponent("Text")
    this.name = Util.GetGameObject(self.gameObject, "soulPrintShow/itemShow/name"):GetComponent("Text")
    this.lastLevelText = Util.GetGameObject(self.gameObject, "soulPrintShow/itemShow/lastLevelText"):GetComponent("Text")
    this.nextLevelText = Util.GetGameObject(self.gameObject, "soulPrintShow/itemShow/nextLevelText"):GetComponent("Text")
    this.slider = Util.GetGameObject(self.gameObject, "soulPrintShow/itemShow/Slider"):GetComponent("Slider")
    this.sliderText = Util.GetGameObject(self.gameObject, "soulPrintShow/itemShow/Slider/Text"):GetComponent("Text")
    this.image1=Util.GetGameObject(self.gameObject, "soulPrintShow/itemShow/Image (1)")
    this.upLevelId = 0
    this.heroId=0
    for i = 1, 4 do
        tabs1[i] = Util.GetGameObject(self.transform, "Tabs1/Btn" .. i)
    end
    this.selectBtn = Util.GetGameObject(self.gameObject, "Tabs1/selectBtn")
    this.selectBtnText = Util.GetGameObject(this.selectBtn.transform, "Text"):GetComponent("Text")
    local v2 = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.transform, "scroll").transform,
            this.item, this.Scrollbar, Vector2.New(-v2.x * 2, -v2.y * 2), 1, 5, Vector2.New(40, 40))
end

--绑定事件（用于子类重写）
function SoulPrintStoreHousePopUp:BindEvent()
    for i = 1, 4 do
        Util.AddClick(tabs1[i], function()
            if (currentChoose == i) then
                this.selectBtn:SetActive(false)
            else
                this.selectBtn:SetActive(true)
            end
            currentChoose = i
            this.selectBtn.transform.localPosition = tabs1[i].transform.localPosition
            if (this.selectBtn.activeSelf) then
                this:SetOrderByQuality(i + 1, itemData)
            else
                --没有选定筛选按钮显示全部魂印
                this:OnRefresh()
                currentChoose = 0
            end
            this.selectBtnText.text = Util.GetGameObject(tabs1[i].transform, "Text"):GetComponent("Text").text
        end)
    end
    -- 升一级(消耗升一级所需的魂印)
    Util.AddClick(this.upLevelBtn, function()
        if(upLevelItemData.level<SoulPrintManager.GetSoulPrintMaxLevel(upLevelItemData.id)) then
            if (#itemData >= 1) then
                local needExp = upLevelItemData.upLevelExp - upLevelItemData.remainExp
                local costSoulPrintId = {}
                costSoulPrintId = SoulPrintManager.GetCostSoulPrintIdList(needExp, itemData)
                this.lastGetLevel = upLevelItemData.level
                local lastData = { level = 0, name = 0, icon = 0, quality = 0, property = 0 }
                lastData.level = upLevelItemData.level
                lastData.name = upLevelItemData.name
                lastData.icon = upLevelItemData.icon
                lastData.quality = upLevelItemData.quality
                lastData.property = upLevelItemData.property
                lastLevelItem = lastData
                this:OnUpLevelHandleSoulPrint(costSoulPrintId, this.upLevelId,this.heroId)
            else
                PopupTipPanel.ShowTipByLanguageId(11954)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(11955)
        end

    end)
    --消耗勾选的魂印转换为经验
    Util.AddClick(this.quickEnterBtn, function()
        if(upLevelItemData.level<SoulPrintManager.GetSoulPrintMaxLevel(upLevelItemData.id)) then
            if (table.nums(chooseIdList) >= 1) then
                this.lastGetLevel = upLevelItemData.level
                local lastData = { level = 0, name = 0, icon = 0, quality = 0, property = 0 }
                lastData.level = upLevelItemData.level
                lastData.name = upLevelItemData.name
                lastData.icon = upLevelItemData.icon
                lastData.quality = upLevelItemData.quality
                lastData.property = upLevelItemData.property
                lastLevelItem = lastData
                this:OnUpLevelHandleSoulPrint(chooseIdList, this.upLevelId,this.heroId)
            else
                PopupTipPanel.ShowTipByLanguageId(11956)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(11955)
        end
    end)
    --帮助说明按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.SoulPrintUpgrade,this.helpPosition.x,this.helpPosition.y)
    end)
    --关闭页面
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function SoulPrintStoreHousePopUp:AddListener()

end

--移除事件监听（用于子类重写）
function SoulPrintStoreHousePopUp:RemoveListener()

end

--界面打开时调用（用于子类重写）
function SoulPrintStoreHousePopUp:OnOpen(upLevelId,heroId)
    this.upLevelId = upLevelId
    this.heroId=heroId
    this:OnRefresh()
end

--打开页面时，页面数据刷新
function SoulPrintStoreHousePopUp:OnRefresh()
    this:GetUpLevelSoulPrintData()
    this:SetOrderByQuality(1, itemData)
    currentChoose=0
    chooseNum = table.nums(chooseIdList)
    this.chooseText.text = GetLanguageStrById(11957) .. chooseNum .. "/" .. table.nums(itemData)
    if (table.nums(upLevelItemData) >= 1) then
        this.quality.sprite = Util.LoadSprite(GetQuantityImageByquality(upLevelItemData.quality))
        this.icon.sprite = Util.LoadSprite(upLevelItemData.icon)
        this.level.text = "+" .. upLevelItemData.level
        this.name.text = upLevelItemData.name
    end
end

-- 得到要升级的魂印数据
function this:GetUpLevelSoulPrintData()
    local itemDataList = SoulPrintManager.soulPrintData
    itemData = SoulPrintManager.GetSoulPrintLevelAndSort(itemDataList)
    for i, v in pairs(itemDataList) do
        if (v.did == this.upLevelId) then
            upLevelItemData = v
        end
    end
    for i, v in ipairs(itemData) do
        if (v.did == this.upLevelId) then
            table.remove(itemData, i)
        end
    end
end
--进行升级时消耗魂印处理(先消耗品质差的魂印)
function this:OnUpLevelHandleSoulPrint(_chooseIdList, upLevelId, _heroId)
    --遍历升级消耗的魂印是否有紫色及以上品质，有则弹提示框
    local haveHighQuality=false
    for i,v in pairs(_chooseIdList) do
        if(SoulPrintManager.soulPrintData[i].quality>=4) then
            haveHighQuality=true
        end
    end
    local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid ..GetLanguageStrById(11958))
    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
    if (isPopUp ~= currentTime and haveHighQuality) then
        local str =GetLanguageStrById(11959)
        MsgPanel.ShowTwo(str, function()
        end, function(isShow)
            if (isShow) then
                local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. GetLanguageStrById(11958), currentTime)
            end
            SoulPrintManager.UpQuickSoulEquipRequest(upLevelId, _chooseIdList, _heroId, function()
                chooseIdList={}
                this:GetUpLevelSoulPrintData()
                this:SetOrderByQuality(currentChoose + 1, itemData)
                Game.GlobalEvent:DispatchEvent(GameEvent.SoulPrint.OnRefreshBag)
            end)
        end, GetLanguageStrById(10719), GetLanguageStrById(10720),nil,true)
    else
        SoulPrintManager.UpQuickSoulEquipRequest(upLevelId, _chooseIdList, _heroId, function()
            chooseIdList={}
            this:GetUpLevelSoulPrintData()
            this:SetOrderByQuality(currentChoose + 1, itemData)
            Game.GlobalEvent:DispatchEvent(GameEvent.SoulPrint.OnRefreshBag)
        end)
    end
end
--设置魂印循环滚动数据
function this:SetSoulPrintData(_go, _itemData)
    _go.gameObject:SetActive(true)
    local chooseBtn = Util.GetGameObject(_go.gameObject, "chooseBtn")
    local quality = Util.GetGameObject(_go.gameObject, "quality"):GetComponent("Image")
    local icon = Util.GetGameObject(_go.gameObject, "icon"):GetComponent("Image")
    local name = Util.GetGameObject(_go.gameObject, "name"):GetComponent("Text")
    local level = Util.GetGameObject(_go.gameObject, "level"):GetComponent("Text")
    local chooseImage = Util.GetGameObject(_go.gameObject, "chooseImage")
    quality.sprite = Util.LoadSprite(GetQuantityImageByquality(_itemData.quality))
    icon.sprite = Util.LoadSprite(_itemData.icon)
    name.text = _itemData.name
    level.text = "+" .. _itemData.level
    chooseImage:SetActive(chooseIdList[_itemData.did] ~= nil)
    Util.AddOnceClick(chooseBtn, function()
        if (chooseIdList[_itemData.did]) then
            chooseIdList[_itemData.did] = nil
        else
            chooseIdList[_itemData.did] = SoulPrintManager.GetSoulPrintId(_itemData.id, _itemData.level)
        end
        chooseImage:SetActive(chooseIdList[_itemData.did] ~= nil)
        chooseNum = table.nums(chooseIdList)
        this.chooseText.text = GetLanguageStrById(11957) .. chooseNum .. "/" .. table.nums(itemData)
        this:RefreshLevelExpShow()
    end)
end

-- 勾选物品刷新经验条等级信息
function this:RefreshLevelExpShow()
    local exp=SoulPrintManager.ExChangeSoulPrintToExp(chooseIdList)
    SoulPrintManager.UpSoulPrintLevel(upLevelItemData.id,exp+upLevelItemData.haveExp)
    local showLevel=SoulPrintManager.chooseLevelShow
    this.lastLevelText.text =showLevel
    this.nextLevelText.text =showLevel+1
    this.image1:SetActive(true)
    this.slider.value = (SoulPrintManager.chooseExpShow)/ SoulPrintManager.chooseExpUpLevel
    this.sliderText.text = string.format("%s/%s",(SoulPrintManager.chooseExpShow),SoulPrintManager.chooseExpUpLevel)
    chooseNum = table.nums(chooseIdList)
    this.chooseText.text = GetLanguageStrById(11957) .. chooseNum .. "/" .. table.nums(itemData)
    if(showLevel>=SoulPrintManager.GetSoulPrintMaxLevel(upLevelItemData.id)) then
        this.sliderText.text=GetLanguageStrById(11960)
        this.nextLevelText.text=""
        this.image1:SetActive(false)
    end
end


--根据魂印品质进行排序
--- 参数_qualityIndex：2(品质绿)3(品质蓝)4(品质紫)5(品质橙)
function this:SetOrderByQuality(_qualityIndex, itemData)
    currentDataList = {}
    chooseIdList={}
    for i, v in pairs(itemData) do
        if (v.quality == _qualityIndex) then
            table.insert(currentDataList, v)
            chooseIdList[v.did] =SoulPrintManager.GetSoulPrintId(v.id, v.level)
        end
    end
    if (_qualityIndex == 1) then
        for i, v in pairs(itemData) do
            table.insert(currentDataList, v)
        end
    end
    this:RefreshLevelExpShow()
    --判断是否升级成功，成功弹板
    SoulPrintStoreHousePopUp:OnShowSuccessLevel()
    this.ScrollView:SetData(currentDataList, function(index, go)
        go.gameObject:SetActive(false)
        this:SetSoulPrintData(go, currentDataList[index])
    end)
end


--显示升级成功页面
function SoulPrintStoreHousePopUp:OnShowSuccessLevel()
    this.level.text = "+" .. upLevelItemData.level
    if (table.nums(upLevelItemData) >= 1) then
        if (this.lastGetLevel) then
            if (upLevelItemData.level > this.lastGetLevel) then
                UIManager.OpenPanel(UIName.SoulPrintUpLevelSuccessPopUp, lastLevelItem, upLevelItemData)
                this.lastGetLevel = nil
            end
        end
    end
end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SoulPrintStoreHousePopUp:OnShow()

end

--界面关闭时调用（用于子类重写）
function SoulPrintStoreHousePopUp:OnClose()

end

--界面销毁时调用（用于子类重写）
function SoulPrintStoreHousePopUp:OnDestroy()

end

return SoulPrintStoreHousePopUp