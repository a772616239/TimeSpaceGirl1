local WarOrder = quick_class("WeekCard")
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local EncourageTaskConfig = ConfigManager.GetConfig(ConfigName.EncourageTaskConfig)
local EncouragePlanConfig = ConfigManager.GetConfig(ConfigName.EncouragePlanConfig)

local bannerImg = {
    [15] = {GetPictureFont("cn2-X1_zhanling_pata_bg"), "", 131},--爬塔
    [16] = {GetPictureFont("cn2-X1_zhanling_mota_bg"), "cn2-X1_zhanling_mota_icon", 132},--魔之塔
    [17] = {GetPictureFont("cn2-X1_zhanling_yiduan_bg"),"cn2-X1_zhanling_yiduan_icon", 133},--异端
    [18] = {GetPictureFont("cn2-X1_zhanling_miwu_bg"), "cn2-X1_zhanling_miwu_icon", 134},--迷雾
    [19] = {GetPictureFont("cn2-X1_zhanling_shenyuan_bg"), "cn2-X1_zhanling_shenyuan_icon", 135},--深渊
}
local curIndex
local lastGlobalSystemId
local lastwarOrders

function WarOrder:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()

    self.itemList = {}
    curIndex = nil
    lastGlobalSystemId = nil
    lastwarOrders = nil
end

-- 初始化组件
function WarOrder:InitComponent(gameObject)
    self.btnUnlock = Util.GetGameObject(gameObject, "grid/progress/btnUnlock")
    self.timeObj = Util.GetGameObject(gameObject, "time")
    self.time = Util.GetGameObject(gameObject, "time/Text"):GetComponent("Text")
    self.scroll = Util.GetGameObject(gameObject, "scroll")
    self.itemPre = Util.GetGameObject(gameObject, "scroll/pre")
    local rootHight = self.scroll.transform.rect.height
    local width = self.scroll.transform.rect.width
    self.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scroll.transform,
            self.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 5))
    self.scrollView.moveTween.MomentumAmount = 1
    self.scrollView.moveTween.Strength = 2
    self.btnHelp = Util.GetGameObject(gameObject , "btnHelp")
    self.helpPosition = self.btnHelp:GetComponent("RectTransform").localPosition
    self.Unlocked = Util.GetGameObject(gameObject, "grid/progress/Unlocked")
end

function WarOrder:BindEvent()
    Util.AddClick(self.btnUnlock, function ()
        local warOrder = OperatingManager.GetWarOrderForGlobalSystemIdAndId(WarOrderType[self.warOrderType], self.warOrderId)
        if warOrder.unlockPrivilege then
            return
        end
        UIManager.OpenPanel(UIName.UnLockWarOrderPanel, self.warOrderId)
    end)
    Util.AddClick(self.btnHelp, function()
        UIManager.OpenPanel(UIName.HelpPopup, bannerImg[self.warOrderType][3], self.helpPosition.x, self.helpPosition.y) 
    end)
end

function WarOrder:AddEvent()
end

function WarOrder:RemoveEvent()
end

function WarOrder:OnShow(warOrderType)
    self.gameObject:SetActive(true)
    self.warOrderType = warOrderType
    -- OperatingManager.GetAllWarOrderData(function ()
    -- end)
    local warOrders = OperatingManager.GetWarOrderForGlobalSystemId(WarOrderType[self.warOrderType])
    if not warOrders then
        return
    end
    self:SetData()
    self:SetBanner()
    self:SetWarOrdersBtn()
end

function WarOrder:OnHide()
    CardActivityManager.StopTimeDown()
    self.gameObject:SetActive(false)
end

function WarOrder:SetData()
    local setTop = false
    local warOrders = OperatingManager.GetWarOrderForGlobalSystemId(WarOrderType[self.warOrderType])
    if not warOrders then
        return
    end
    if not curIndex then
        curIndex = #warOrders.encouragePlanInfos
        setTop = true
    end
    if not lastGlobalSystemId then
        lastGlobalSystemId = WarOrderType[self.warOrderType]
    else
        if WarOrderType[self.warOrderType] ~= lastGlobalSystemId then
            curIndex = #warOrders.encouragePlanInfos
            lastwarOrders = curIndex
            setTop = true
        else
            if curIndex ~= lastwarOrders and lastwarOrders then
                curIndex = lastwarOrders
                setTop = true
            end
        end
    end
    lastGlobalSystemId = WarOrderType[self.warOrderType]
    self.warOrderId = warOrders.encouragePlanInfos[curIndex].encouragePlanId
    self.RechargeID = EncouragePlanConfig[self.warOrderId].RechargeID
    local allData = ConfigManager.GetAllConfigsDataByKey(ConfigName.EncourageTaskConfig, "EncouragePlan", self.warOrderId)
    table.insert(allData, {})
    self.scrollView:SetData(allData, function (index, go)
        self:SetItem(go, allData[index], index, #allData)
    end)
    if setTop then
        self.scrollView:SetIndex(1)
    end
end

function WarOrder:SetBanner()
    local banner = Util.GetGameObject(self.gameObject, "banner"):GetComponent("Image")
    local icon = Util.GetGameObject(banner.gameObject, "icon"):GetComponent("Image")
    local progress = Util.GetGameObject(self.gameObject, "grid/progress/progress"):GetComponent("Text")
    local company = Util.GetGameObject(self.gameObject, "grid/progress/company"):GetComponent("Text")
    local requirement = Util.GetGameObject(self.gameObject, "grid/progress/requirement"):GetComponent("Text")
    local multiple = Util.GetGameObject(banner.gameObject, "multiple"):GetComponent("Text")
    local title = Util.GetGameObject(self.gameObject, "title"):GetComponent("Image")

    local warOrder = OperatingManager.GetWarOrderForGlobalSystemIdAndId(WarOrderType[self.warOrderType], self.warOrderId)
    progress.text = warOrder.progress
    banner.sprite = Util.LoadSprite(EncouragePlanConfig[self.warOrderId].Banner)
    icon.sprite = Util.LoadSprite(EncouragePlanConfig[self.warOrderId].PrivilegeIcon)
    -- banner.sprite = Util.LoadSprite(bannerImg[self.warOrderType][1])
    -- if self.warOrderType == 15 then
    --     icon.sprite = Util.LoadSprite(string.format("cn2-X1_zhanling_pata%s_icon", curIndex))
    -- else
    --     icon.sprite = Util.LoadSprite(bannerImg[self.warOrderType][2])
    -- end
    -- Util.SetGray(self.btnUnlock, warOrder.unlockPrivilege)
    self.Unlocked:SetActive(warOrder.unlockPrivilege)
    self.btnUnlock:SetActive(not warOrder.unlockPrivilege)

    requirement.text = GetLanguageStrById(EncouragePlanConfig[self.warOrderId].TaskDesc)
    if EncouragePlanConfig[self.warOrderId].TitleShow == 0 then
        title.gameObject:SetActive(false)
    else
        title.sprite = Util.LoadSprite(GetResourcePath(EncouragePlanConfig[self.warOrderId].TitleShow))
        title.gameObject:SetActive(true)
    end
    multiple.text = EncouragePlanConfig[self.warOrderId].MultipleShow
    if warOrder.cycleEndingTime > 0 then
        --LogError(warOrder.cycleEndingTime-GetTimeStamp())
        CardActivityManager.TimeDown(self.time, warOrder.cycleEndingTime-GetTimeStamp())
    end
    self.timeObj:SetActive(warOrder.cycleEndingTime > 0)
    local lang= GetCurLanguage()
    if lang == 10101 then
       multiple.gameObject:SetActive(false)
    end
end

local btnImg = {
    [1] = {"cn2-X1_zhanling_pata_bt_02", "cn2-X1_zhanling_pata_bt_01"},
    [2] = {"cn2-X1_zhanling_pata_bt_04", "cn2-X1_zhanling_pata_bt_03"},
}
function WarOrder:SetWarOrdersBtn()
    local tab = Util.GetGameObject(self.gameObject, "grid/tab")
    local grid = Util.GetGameObject(self.gameObject, "grid/tab/grid")
    local btn = Util.GetGameObject(self.gameObject, "grid/tab/grid/btn")
    local space = Util.GetGameObject(self.gameObject, "grid/space")

    local warOrders = OperatingManager.GetWarOrderForGlobalSystemId(WarOrderType[self.warOrderType]).encouragePlanInfos
    tab:SetActive(#warOrders > 1 or self.warOrderType == 15)
    space:SetActive(not tab.activeSelf)
    if #warOrders > 1 or self.warOrderType == 15 then
        if not self.warOrderBtns then
            self.warOrderBtns = {}
        end
        for i = 1, #self.warOrderBtns do
            self.warOrderBtns[i]:SetActive(false)
        end
        for i = 1, #warOrders do
            if not self.warOrderBtns[i] then
                self.warOrderBtns[i] = newObjToParent(btn, grid.transform)
            end
            local a, b = 2, 1
            if i == 1 and i ~= curIndex then
                a = 1
            elseif i == curIndex then
                if i == 1 then
                    a = 1
                else
                    a = 2
                end
                b = 2
            end
            self.warOrderBtns[i]:GetComponent("Image").sprite = Util.LoadSprite(btnImg[a][b])
            Util.GetGameObject(self.warOrderBtns[i], "Text"):GetComponent("Text").text = GetLanguageStrById(EncouragePlanConfig[warOrders[i].encouragePlanId].Name)
            Util.GetGameObject(self.warOrderBtns[i], "redpoint"):SetActive(OperatingManager.WarOrderRedPointForId(self.warOrderType, warOrders[i].encouragePlanId))
            self.warOrderBtns[i]:SetActive(true)
            Util.AddOnceClick(self.warOrderBtns[i], function ()
                for i = 1, #self.warOrderBtns do
                    local index = 2
                    if i == 1 then
                        index = 1
                    end
                    self.warOrderBtns[i]:GetComponent("Image").sprite = Util.LoadSprite(btnImg[index][1])
                end
                local index = 2
                if i == 1 then
                    index = 1
                end
                self.warOrderBtns[i]:GetComponent("Image").sprite = Util.LoadSprite(btnImg[index][2])
                -- curIndex = i
                lastwarOrders = i
                self:OnShow(self.warOrderType)
            end)
        end
    end
end

function WarOrder:SetItem(go, data, index, max)
    if index == max then
        go:SetActive(false)
        return
    else
        go:SetActive(true)
    end
    local upLine = Util.GetGameObject(go, "upLine")
    local downLine = Util.GetGameObject(go, "downLine")
    local progress = Util.GetGameObject(go, "progress"):GetComponent("Text")
    local freeGrid = Util.GetGameObject(go, "freeGrid")
    local privilegeGrid = Util.GetGameObject(go, "privilegeGrid")
    local received = Util.GetGameObject(go, "received")
    local btn = Util.GetGameObject(go, "btn")
    local btnTxt = Util.GetGameObject(go, "btn/Text"):GetComponent("Text")
    local redpoint = Util.GetGameObject(go, "btn/redpoint")

    upLine:SetActive(index ~= 1)
    downLine:SetActive(index ~= max-1)
    local warOrder = OperatingManager.GetWarOrderForGlobalSystemIdAndId(WarOrderType[self.warOrderType], self.warOrderId)
    local taskData = OperatingManager.GetWarOrderTaskState(WarOrderType[self.warOrderType], self.warOrderId, data.Id)
    if not self.itemList then
        self.itemList = {}
    end
    if not self.itemList[go] then
        self.itemList[go] = {}
    end
    if not self.itemList[go][freeGrid] then
        self.itemList[go][freeGrid] = {}
    end
    if not self.itemList[go][privilegeGrid] then
        self.itemList[go][privilegeGrid] = {}
    end
    for i = 1, #self.itemList[go][freeGrid] do
        self.itemList[go][freeGrid][i].gameObject:SetActive(false)
    end
    for i = 1, #self.itemList[go][privilegeGrid] do
        self.itemList[go][privilegeGrid][i].gameObject:SetActive(false)
    end
    for i = 1, #data.FreeReward do
        if not self.itemList[go][freeGrid][i] then
            self.itemList[go][freeGrid][i] = SubUIManager.Open(SubUIConfig.ItemView, freeGrid.transform)
        end
        self.itemList[go][freeGrid][i]:OnOpen(false, data.FreeReward[i], 0.55)
        self.itemList[go][freeGrid][i]:SetCorner(4, taskData.freeObtained)
        self.itemList[go][freeGrid][i].gameObject:SetActive(true)
    end
    for i = 1, #data.PrivilegeReward do
        if not self.itemList[go][privilegeGrid][i] then
            self.itemList[go][privilegeGrid][i] = SubUIManager.Open(SubUIConfig.ItemView, privilegeGrid.transform)
        end
        self.itemList[go][privilegeGrid][i]:OnOpen(false, data.PrivilegeReward[i], 0.55)
        self.itemList[go][privilegeGrid][i]:SetCorner(2, not warOrder.unlockPrivilege)
        self.itemList[go][privilegeGrid][i]:SetCorner(4, taskData.privilegeObtained)
        self.itemList[go][privilegeGrid][i].gameObject:SetActive(true)
    end

    progress.text = data.TaskRequire
    if warOrder.unlockPrivilege then
        received:SetActive(taskData.freeObtained and taskData.privilegeObtained and taskData.isCompeted)
    else
        received:SetActive(taskData.freeObtained and taskData.isCompeted)
    end
    btn:SetActive(not received.gameObject.activeSelf)
    redpoint:SetActive(false)
    if not taskData.isCompeted then
        btnTxt.text = GetLanguageStrById(91000004   )
    else
        if warOrder.unlockPrivilege then
            if taskData.freeObtained and not taskData.privilegeObtained then
                btnTxt.text = GetLanguageStrById(10752)
                redpoint:SetActive(true)
            elseif not taskData.freeObtained and not taskData.privilegeObtained then
                btnTxt.text = GetLanguageStrById(91000003)
                redpoint:SetActive(true)
            end
        else
            if not taskData.freeObtained then
                btnTxt.text = GetLanguageStrById(91000003)
                redpoint:SetActive(true)
            end
        end
    end
    Util.AddOnceClick(btn, function ()
        if not taskData.isCompeted then
            JumpManager.GoJump(EncouragePlanConfig[self.warOrderId].Jump)
        else
            local state = 1
            if warOrder.unlockPrivilege then
                if taskData.freeObtained and not taskData.privilegeObtained then
                    state = 2
                elseif not taskData.freeObtained and not taskData.privilegeObtained then
                    state = 3
                end
            end
            OperatingManager.GetWarOrderReward(data.Id, state, function ()
                self:OnShow(self.warOrderType)
            end)
        end
    end)
end

return WarOrder