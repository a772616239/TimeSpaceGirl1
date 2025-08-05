require("Base/BasePanel")
SevenDayCarnivalPanelV2 = Inherit(BasePanel)
local this = SevenDayCarnivalPanelV2
local treasureTaskConfig = ConfigManager.GetConfig(ConfigName.TreasureTaskConfig)
local TabBox = require("Modules/Common/TabBox")
local _TabData = {}
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1)}

local curIndex
local dayBtn = {}--天数btn
local rewardBtn = {}--积分btn
local curDayIndex = 1
local serverTaskList--服务器所有开服狂欢数据
local curServerTaskList--服务器所有开服狂欢某一天某页签数据  [missionid] = data
local allTaskListConfigDtata--表里所有开服狂欢某一天数据
local curTaskListConfigDtata--表里所有开服狂欢某一天某页签数据
local currentDay  -- 当前第几天
local allRewardTaskList --表里所有开服狂欢积分数据
local tabBoxRedPoint = {}
local itemList = {}--优化itemView使用
local sorting = 0
local fristOn = true
--半价购买数据
local shopInfoList
local curShopData
this.timer = Timer.New()

--初始化组件（用于子类重写）
function SevenDayCarnivalPanelV2:InitComponent()
    --子模块脚本
    this.BtnBack = Util.GetGameObject(self.transform, "bg/btnBack")
    this.helpBtn = Util.GetGameObject(self.gameObject, "bg/helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition + Vector3(0,200,0)
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")
    this.equipPre = Util.GetGameObject(self.gameObject, "bg/rewardPro")
    --this.ScrollBar = Util.GetGameObject(self.gameObject, "CompoundPanel_Equip/Scrollbar"):GetComponent("Scrollbar")
    local v2 = Util.GetGameObject(self.gameObject, "bg/taskList"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "bg/taskList").transform,
            this.equipPre, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 1, Vector2.New(50,5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    for i = 1, 7 do
        dayBtn[i] = Util.GetGameObject(self.gameObject, "bg/daysTabBg/tabsGroup/day_".. i)
    end

    this.progressImage = Util.GetGameObject(self.gameObject, "bg/finalTarget/progressbar/progress"):GetComponent("Image")
    this.progressText = Util.GetGameObject(self.gameObject, "bg/finalTarget/curProgress/Text"):GetComponent("Text")
    for i = 1, 4 do
        rewardBtn[i] = Util.GetGameObject(self.gameObject, "bg/finalTarget/rewardProgress/rewardBoxBtn".. i)
    end
    this.dayBtnSelect = Util.GetGameObject(self.gameObject, "bg/daysTabBg/tabsGroup/selected")
    this.dayBtnSelectText =  Util.GetGameObject(this.dayBtnSelect.transform, "Text"):GetComponent("Text")
    -- this.dayBtnSelect2 = Util.GetGameObject(self.gameObject, "bg/daysTabBg/tabsGroup/selected2")
    this.timeTextExpertgo = Util.GetGameObject(self.gameObject, "bg/actRemainTime")
    this.timeTextExpert = Util.GetGameObject(self.gameObject, "bg/actRemainTime"):GetComponent("Text")
    this.TabCtrl = TabBox.New()
    -- this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft })
    -- this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.transform)
end

--绑定事件（用于子类重写）
function SevenDayCarnivalPanelV2:BindEvent()
    for i = 1, 7 do
        Util.AddClick(dayBtn[i], function()
            if i == curDayIndex then return end
            this.OnDayClickBtn(i)
        end)
    end
    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.OpenSevenDay,this.helpPosition.x,this.helpPosition.y)
    end)
end

--添加事件监听（用于子类重写）
function SevenDayCarnivalPanelV2:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshTaskShow)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnCloseSevenDayGift, self.OnClosePanelFun, self)
end

--移除事件监听（用于子类重写）
function SevenDayCarnivalPanelV2:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshTaskShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnCloseSevenDayGift, self.OnClosePanelFun, self)
end

--界面打开时调用（用于子类重写）
function SevenDayCarnivalPanelV2:OnOpen(_curDayIndex)
    for i = 1, #dayBtn do
        Util.GetGameObject(dayBtn[i],"Text"):SetActive(true)
    end
    curDayIndex = _curDayIndex or 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SevenDayCarnivalPanelV2:OnShow()
    currentDay = SevenDayCarnivalManager.GetCurrentDayNumber()
    this.OnDayClickBtn(curDayIndex)
    this.ShowTitleDayBtnsData()
    this.ShowTitleProgressRewardData()
    this.ShowTime()
    this.RefreshRedPoint()
    -- this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    -- this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.MainCity })
end

function SevenDayCarnivalPanelV2:OnSortingOrderChange()
        for i, v in pairs(itemList) do
            for j = 1, #v do
                v[j]:SetEffectLayer(self.sortingOrder)
            end
        end
    -- Util.AddParticleSortLayer(Util.GetGameObject(self.transform, "bg/effect"), self.sortingOrder-sorting)
    sorting = self.sortingOrder
    -- this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
end

function this.RefreshRedPoint()
    for i = 1, #dayBtn do
        if i > currentDay then
            Util.GetGameObject(dayBtn[i], "redPoint"):SetActive(false)
        else
            local redPoint = SevenDayCarnivalManager.GetDayNumberRedPointStatus(i)
            Util.GetGameObject(dayBtn[i], "redPoint"):SetActive(redPoint)
        end
    end
end
function SevenDayCarnivalPanelV2:OnClosePanelFun()
    self:ClosePanel()
end
function this.ShowTime()
    local downTime = 0
    local SevenDayCarnivalData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SevenDayCarnival)
    if SevenDayCarnivalData then
        downTime = SevenDayCarnivalData.endTime - GetTimeStamp()
    end
    this.RemainTimeDown(this.timeTextExpertgo,this.timeTextExpert,downTime)
end

function this.RemainTimeDown(_timeTextExpertgo,_timeTextExpert,timeDown)
    if timeDown > 0 then
        if _timeTextExpertgo then
            _timeTextExpertgo:SetActive(true)
        end
        if _timeTextExpert then
            _timeTextExpert.text =  TimeToDHMS(timeDown) --[[GetLanguageStrById(10028)..]] --PatFaceManager.TimeStampToDateString2(timeDown)
        end
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if _timeTextExpert then
                _timeTextExpert.text =  TimeToDHMS(timeDown) --[[GetLanguageStrById(10028)..]] --PatFaceManager.TimeStampToDateString2(timeDown)
            end
            if timeDown < 0 then
                if _timeTextExpertgo then
                    _timeTextExpertgo:SetActive(false)
                end
                this.timer:Stop()
                this.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        if _timeTextExpertgo then
            _timeTextExpertgo:SetActive(false)
        end
    end
end
--消息刷新
function this.RefreshTaskShow()
    this.OnClickTabBtn(curIndex)
    this.ShowTitleProgressRewardData()
    this.DownTabBtnRedPointShow()
    this.RefreshRedPoint()
    if SevenDayCarnivalManager.RefreshNextDayData(currentDay) then
        --跨天
        currentDay = SevenDayCarnivalManager.GetCurrentDayNumber()
        this.OnDayClickBtn(curDayIndex)
        this.ShowTitleDayBtnsData()
        this.ShowTitleProgressRewardData()
        this.ShowTime()
        this.RefreshRedPoint()
    end
end

function this.CreateTabData()
    _TabData = {}
    for i = 1, #allTaskListConfigDtata do
        if allTaskListConfigDtata[i].DayNum == curDayIndex then
            if not _TabData[allTaskListConfigDtata[i].SheetId] then
                table.insert(_TabData,{ default = "nil", select = "cn2-X1_qiri_xuanzhong", name = allTaskListConfigDtata[i].SheetName })
            end
        end
    end
    --必有此页签  写死
    table.insert(_TabData,{ default = "nil", select = "cn2-X1_qiri_xuanzhong", name = 11922 })
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData,curIndex)
    tabBoxRedPoint = {}
    for i = 1, #_TabData do
        local curTabBtn = Util.GetGameObject(this.tabBox, "box").transform:GetChild(i-1)
        tabBoxRedPoint[i] = Util.GetGameObject(curTabBtn, "Redpot")
    end
end

--显示上边七天按钮
function this.ShowTitleDayBtnsData()
    for i = 1, 7 do
        -- local icon
        -- if i == 7 then
        --     icon = Util.GetGameObject(dayBtn[i], "iconMask/icon"):GetComponent("Image")
        -- else
        --     icon = Util.GetGameObject(dayBtn[i], "icon"):GetComponent("Image")
        -- end
        -- icon.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.SevenDaysActivity,i).ShowIcon))
        Util.GetGameObject(dayBtn[i], "Text"):GetComponent("Text").text = i --GetLanguageStrById(10311).. i ..GetLanguageStrById(10021)
        if i <= currentDay then
            Util.SetGray(dayBtn[i], false)
            Util.GetGameObject(dayBtn[i], "lock"):SetActive(false)
        else
            Util.SetGray(dayBtn[i], true)
            Util.GetGameObject(dayBtn[i], "lock"):SetActive(true)
        end
    end
end

--显示上边积分奖励
function this.ShowTitleProgressRewardData()
    local curNum = 0
    local maxNum = 0

    allRewardTaskList = {}
    local curAllTaskListConfigDtata = ConfigManager.GetAllConfigsDataByKey(ConfigName.TreasureTaskConfig,"ActivityId",ActivityTypeDef.SevenDayCarnival)
    for i = 1, #curAllTaskListConfigDtata do
        if curAllTaskListConfigDtata[i].TaskType == 38 then--积分
            table.insert(allRewardTaskList,curAllTaskListConfigDtata[i])
        end
    end
    for i = 1, #rewardBtn  do
        if allRewardTaskList[i] then
            if maxNum < allRewardTaskList[i].TaskValue[2][1] then
                maxNum = allRewardTaskList[i].TaskValue[2][1]
            end
            local curProgressData = curServerTaskList[allRewardTaskList[i].Id]
            if curProgressData then
                if curNum < curProgressData.progress then
                    curNum = curProgressData.progress
                end
                Util.GetGameObject(rewardBtn[i], "redPoint"):SetActive(curProgressData.state == 1)
                Util.GetGameObject(rewardBtn[i], "Text"):GetComponent("Text").text = allRewardTaskList[i].TaskValue[2][1]
                Util.GetGameObject(rewardBtn[i], "getFinish"):SetActive(curProgressData.state == 2)
                Util.AddOnceClick(rewardBtn[i], function()
                    if curProgressData.state == 0 then
                        --PopupTipPanel.ShowTip("完成任务数量不足")
                        UIManager.OpenPanel(UIName.BoxRewardShowPopup,allRewardTaskList[i].Reward,nil,nil,allRewardTaskList[i].TaskValue[2][1] .. GetLanguageStrById(11923))
                        return
                    end
                    if curProgressData.state == 2 then
                        PopupTipPanel.ShowTipByLanguageId(10350)
                        return
                    end
                    NetManager.TakeMissionRewardRequest(TaskTypeDef.SevenDayCarnival, curProgressData.missionId, function(respond)
                        UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1,function ()
                            this.OnClickTabBtn(curIndex)
                            this.ShowTitleProgressRewardData()
                            this.DownTabBtnRedPointShow()
                            this.RefreshRedPoint()
                        end)
                    end)
                end)
            end
        end
    end
    this.progressImage.fillAmount = curNum/maxNum
    this.progressText.text = curNum
end

function this.OnDayClickBtn(_curDayIndex)
    if _curDayIndex > currentDay then
        PopupTipPanel.ShowTipByLanguageId(11924)
        return
    end
    if SevenDayCarnivalManager.GetSevenDayHalfPriceRedPoint(_curDayIndex) then
        local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
        PlayerPrefs.SetInt(PlayerManager.uid .. "_SevenDay" .. "_" .. activityId .. "_" .. _curDayIndex, 1)
    end
    allTaskListConfigDtata = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.TreasureTaskConfig,"ActivityId",ActivityTypeDef.SevenDayCarnival,"DayNum",_curDayIndex)

    Util.GetGameObject(dayBtn[curDayIndex],"Text"):SetActive(true)
    curDayIndex = _curDayIndex
    curIndex = 1
    -- if curDayIndex ~= 7 then
    --     this.dayBtnSelect.transform:SetParent(Util.GetGameObject(dayBtn[curDayIndex], "selectedParent").transform)
    --     this.dayBtnSelect.transform.localPosition = Vector3.zero
    -- else
    --     this.dayBtnSelect2.transform:SetParent(Util.GetGameObject(dayBtn[curDayIndex], "selectedParent").transform)
    --     this.dayBtnSelect2.transform.localPosition = Vector3.zero
    -- end
    -- this.dayBtnSelect:SetActive(curDayIndex ~= 7)
    -- this.dayBtnSelect2:SetActive(curDayIndex == 7)
    this.dayBtnSelect.transform:SetParent(Util.GetGameObject(dayBtn[curDayIndex], "selectedParent").transform)
    Util.GetGameObject(dayBtn[curDayIndex],"Text"):SetActive(false)
    this.dayBtnSelectText.text = _curDayIndex--Util.GetGameObject(dayBtn[curDayIndex].transform,"Text"):GetComponent("Text").text
    -- if fristOn then
    --     this.dayBtnSelectText.text = 1
    --     fristOn = false
    -- end
    this.dayBtnSelect.transform.localPosition = Vector3.zero
    this.OnClickTabBtn(curIndex)
    this.CreateTabData()
    this.DownTabBtnRedPointShow()
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab, "default")
    local defaultName = Util.GetGameObject(tab, "default/Text")

    local select = Util.GetGameObject(tab, "select")
    local selectName = Util.GetGameObject(tab, "select/Text")

    -- local tabImage = Util.GetGameObject(tab,"Image")
    -- tabImage:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])

    defaultName:GetComponent("Text").text = GetLanguageStrById(_TabData[index].name)
    selectName:GetComponent("Text").text = GetLanguageStrById(_TabData[index].name)
    -- tabLab:GetComponent("Text").color = _TabFontColor[status]

    if status == "default" then
        default:SetActive(true)
        select:SetActive(false)
    else
        default:SetActive(false)
        select:SetActive(true)
    end
end

--切换视图
function this.SwitchView(index)
    this.OnClickTabBtn(index)
end

local sortTable = {
    [0] = 2,
    [1] = 1,
    [2] = 3,
    [3] = 4
}

function this.DownTabBtnRedPointShow()
    local redPointState = {}
    allTaskListConfigDtata = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.TreasureTaskConfig,"ActivityId",ActivityTypeDef.SevenDayCarnival,"DayNum",curDayIndex)
    serverTaskList = TaskManager.GetTypeTaskList(TaskTypeDef.SevenDayCarnival)
    for i = 1, #serverTaskList do
        --普通的任务
        if treasureTaskConfig[serverTaskList[i].missionId] and treasureTaskConfig[serverTaskList[i].missionId].SheetId then
                local SheetId = treasureTaskConfig[serverTaskList[i].missionId].SheetId
                if curDayIndex == treasureTaskConfig[serverTaskList[i].missionId].DayNum then
                    if not redPointState[SheetId] then
                        redPointState[SheetId] = serverTaskList[i].state == 1
                    end
                end
        end
    end
    redPointState[4] = SevenDayCarnivalManager.GetSevenDayCarnivalRedPoint2(curDayIndex)--半价
    for i = 1, #tabBoxRedPoint do
        tabBoxRedPoint[i].gameObject:SetActive(redPointState[i])
    end
end

--下方页签选择
function this.OnClickTabBtn(_curIndex)
    serverTaskList = TaskManager.GetTypeTaskList(TaskTypeDef.SevenDayCarnival)
    curIndex = _curIndex
    curTaskListConfigDtata = {}
    curServerTaskList = {}
    for i = 1, #allTaskListConfigDtata do
        if allTaskListConfigDtata[i].SheetId == curIndex then
            table.insert(curTaskListConfigDtata,allTaskListConfigDtata[i])
        end
    end
    for i = 1, #serverTaskList do
        --普通的任务
        if treasureTaskConfig[serverTaskList[i].missionId] and treasureTaskConfig[serverTaskList[i].missionId].SheetId then
            if treasureTaskConfig[serverTaskList[i].missionId].SheetId == curIndex then
                curServerTaskList[serverTaskList[i].missionId] = serverTaskList[i]
            end
        end
        --积分的任务
        if treasureTaskConfig[serverTaskList[i].missionId].TaskType == 38 then
            curServerTaskList[serverTaskList[i].missionId] = serverTaskList[i]
        end
    end
    if _curIndex ~= 4 then
        table.sort(curTaskListConfigDtata, function(a, b)
            if sortTable[curServerTaskList[a.Id].state] == sortTable[curServerTaskList[b.Id].state] then
                return a.Id < b.Id
            else
                return sortTable[curServerTaskList[a.Id].state] < sortTable[curServerTaskList[b.Id].state]
            end
        end)
        
        -- local itemList = {}
        this.ScrollView:SetData(curTaskListConfigDtata, function (index, go)
            this.SingleItemDataShow(go, curTaskListConfigDtata[index])
            -- itemList[index] = go
        end)
        -- DelayCreation(itemList)
    else-- 4  半价购买
        curShopData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.StoreTypeConfig,"StoreType",SHOP_TYPE.SEVENDAY_CARNIVAL_SHOP,"Sort",curDayIndex)
        if curShopData then
            shopInfoList = ShopManager.GetShopDataByShopId(curShopData.Id)
        end
        if shopInfoList then
            --self.storeConfig = ConfigManager.GetConfigData(ConfigName.StoreConfig,shopInfoList.storeItem[self.mainPanel.selectDayTab].id)
            --local goods = ShopManager.GetShopItemGoodsInfo(self.storeConfig.Id)

            -- local itemList = {}
            this.ScrollView:SetData(shopInfoList.storeItem, function (index, go)
                this.SingleItemDataShow2(go, shopInfoList.storeItem[index],curShopData.Id)
                -- itemList[index] = go
            end)
            -- DelayCreation(itemList)
        end
    end
end

--半价购买
function this.SingleItemDataShow2(go, data,curShopDataId)
    local storeConfig = ConfigManager.GetConfigData(ConfigName.StoreConfig,data.id)
    if not storeConfig then return end
    if not itemList[go.name] then
        itemList[go.name] = {}
    end
    for i = 1, #itemList[go.name] do
        itemList[go.name][i].gameObject:SetActive(false)
    end
    for i = 1, #storeConfig.Goods do
        if itemList[go.name][i] then
            itemList[go.name][i]:OnOpen(false, storeConfig.Goods[i], 0.7,false,false,false,sorting)
        else
            itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "itemContent").transform)
            itemList[go.name][i]:OnOpen(false, storeConfig.Goods[i], 0.7,false,false,false,sorting)
        end
        itemList[go.name][i].gameObject:SetActive(true)
    end
    Util.GetGameObject(go, "desc"):GetComponent("Text").text = GetLanguageStrById(storeConfig.GoodsName)
    Util.GetGameObject(go, "current/buyBtn"):SetActive(true)
    Util.GetGameObject(go, "current/dealBtn"):SetActive(false)
    Util.GetGameObject(go, "current/jumpBtn"):SetActive(false)
    Util.GetGameObject(go, "current/progress"):SetActive(false)
    -- Util.GetGameObject(go, "current/outDataBtn"):SetActive(false)
    --Util.GetGameObject(go, "current/finished"):SetActive(false)
    Util.GetGameObject(go, "current/buyBtn/progress"):SetActive(storeConfig.IsDiscount > 0)
    local item,num,oldNum = ShopManager.CalculateCostCountByShopId(curShopDataId, data.id, 1)
    Util.GetGameObject(go, "current/buyBtn/progress"):GetComponent("Text").text = oldNum
    Util.GetGameObject(go, "current/finished"):SetActive(not ((storeConfig.Limit - data.buyNum) > 0))
    Util.GetGameObject(go, "current/buyBtn/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,item).ResourceID))
    Util.GetGameObject(go, "current/buyBtn/progress/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,item).ResourceID))
    local buyBtn = Util.GetGameObject(go, "current/buyBtn")
    Util.GetGameObject(buyBtn, "Text"):GetComponent("Text").text = num
    Util.GetGameObject(buyBtn, "redPoint"):SetActive(num <= 0)
    buyBtn:SetActive((storeConfig.Limit - data.buyNum) > 0)
    Util.AddOnceClick(buyBtn, function()
        if BagManager.GetItemCountById(item) >= num then
            ShopManager.RequestBuyItemByShopId(curShopDataId, storeConfig.Id, 1, function ()
                this.OnClickTabBtn(curIndex)
                this.ShowTitleProgressRewardData()
                this.DownTabBtnRedPointShow()
                this.RefreshRedPoint()
            end)
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,item).Name)..GetLanguageStrById(10655))
            -- UIManager.OpenPanel(UIName.QuickPurchasePanel,{type = item })
        end
    end)
end

function this.SingleItemDataShow(go, data)
    if not curServerTaskList[data.Id] then return end
    local curServerTask = curServerTaskList[data.Id]
    if not itemList[go.name] then
        itemList[go.name] = {}
    end
    for i = 1, #itemList[go.name] do
        itemList[go.name][i].gameObject:SetActive(false)
    end
    for i = 1, #data.Reward do
        if itemList[go.name][i] then
            itemList[go.name][i]:OnOpen(false, data.Reward[i], 0.7,false,false,false,sorting)
        else
            itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "itemContent").transform)
            itemList[go.name][i]:OnOpen(false, data.Reward[i], 0.7,false,false,false,sorting)
        end
        itemList[go.name][i].gameObject:SetActive(true)
    end
    Util.GetGameObject(go, "desc"):GetComponent("Text").text = GetLanguageStrById(data.Show)
    if data.TaskType == 74 then
        Util.GetGameObject(go, "current/progress"):GetComponent("Text").text = "("..curServerTask.progress/100 .."/"..data.TaskValue[2][1]..")"
    else
        Util.GetGameObject(go, "current/progress"):GetComponent("Text").text = "( "..curServerTask.progress .." / "..data.TaskValue[2][1].." )"
    end
   
    local dealBtn = Util.GetGameObject(go, "current/dealBtn")
    local jumpBtn = Util.GetGameObject(go, "current/jumpBtn")
    -- local outDataBtn=Util.GetGameObject(go,"current/outDataBtn")
    -- Util.GetGameObject(outDataBtn,"Text"):GetComponent("Text").text=GetLanguageStrById(50333)
    --state = 3; //0:未完成 1：完成未领取 2：已达成（已领取）3:已过期
    dealBtn:SetActive(curServerTask.state == 1)
    --Util.GetGameObject(go, "current/redPoint"):SetActive(curServerTask.state == 1)
    Util.GetGameObject(go, "current/finished"):SetActive(curServerTask.state == 2)
    Util.GetGameObject(go, "current/buyBtn"):SetActive(false)
    jumpBtn:SetActive(curServerTask.state == 0)
    -- outDataBtn:SetActive(curServerTask.state==3)
    Util.GetGameObject(go, "current/progress"):SetActive(curServerTask.state == 0)
    Util.AddOnceClick(dealBtn, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.SevenDayCarnival, curServerTask.missionId, function(respond)
            UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1)
        end)
    end)
    Util.AddOnceClick(jumpBtn, function()
        local id = data.Jump[1]
        if id == 27001 then
            if ShopManager.SetMainRechargeJump() then
                id = 36006
            else
                id = 36008
            end
        end
        JumpManager.GoJump(id)
    end)
end

--界面关闭时调用（用于子类重写）
function SevenDayCarnivalPanelV2:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

--界面销毁时调用（用于子类重写）
function SevenDayCarnivalPanelV2:OnDestroy()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    itemList = {}
    -- SubUIManager.Close(this.UpView)
    -- SubUIManager.Close(this.BtView)
end

return SevenDayCarnivalPanelV2