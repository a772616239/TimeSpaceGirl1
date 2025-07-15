require("Base/BasePanel")
FindTreasureMainPanel = Inherit(BasePanel)
local this=FindTreasureMainPanel
local findTreasureGrid = {}
local findTreasureItemsGrid = {}
local timer = Timer.New()
local missionInfo = {}
local refreshIsMaterial = true
local isRefreshAddNum = false
local orginLayer = 0
local isFirstOpen
local conFigData
this.isjump = false
-- local isFirstOn = true--是否首次打开页面

local taskColor = {
    [1] = Color.New(245/255,245/255,245/255,255/255),
    [2] = Color.New(159/255,255/255,136/255,255/255),
    [3] = Color.New(136/255,228/255,255/255,255/255),
    [4] = Color.New(240/255,136/255,255/255,255/255),
    [5] = Color.New(255/255,186/255,136/255,255/255),
    [6] = Color.New(255/255,104/255,104/255,255/255)
}

local changeBgColor = {
    [1] = Color.New(77/255,77/255,77/255,150/255),
    [2] = Color.New(130/255,77/255,238/255,150/255)
}
-- local starImage={[1]="m5_img_tansuo-kongbaixingxing",[2]="ui_1yue"}--星星资源名
--初始化组件（用于子类重写）
function FindTreasureMainPanel:InitComponent()

    self.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    --self.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    --self.helpPos = Util.GetGameObject(self.gameObject, "helpBtn"):GetComponent("RectTransform").localPosition
    self.findTreasureVipBtn = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn")
    self.findTreasureVipBtnRedPoint = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/redPoint")
    self.allGetBtn = Util.GetGameObject(self.gameObject, "allGetBtn")
    self.findTreasureGridGo = Util.GetGameObject(self.gameObject, "rect/rect1/grid")
    self.rewardPre = Util.GetGameObject(self.gameObject, "rewardPre")
    for i = 1, 2 do
        findTreasureGrid[i] = Util.GetGameObject(self.gameObject, "rect/rect1/grid/rewardPre"..i)
        local curexpertRewardItemsGri = {}
        for j = 1, 4 do
            curexpertRewardItemsGri[j] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(findTreasureGrid[i], "content").transform)
        end
        findTreasureItemsGrid[i] = curexpertRewardItemsGri
    end
    self.FindTreasureVipIcon = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/icon")
    --self.FindTreasureVipTextIcon = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/icon/icon (1)"):GetComponent("Image")
    --self.FindTreasureVipTextIcon = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/icon/iconText"):GetComponent("Text")
    --self.FindTreasureVipImageIcon = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/icon/Image"):GetComponent("Image")

     --获取帮助按钮
    self.HelpBtn = Util.GetGameObject(self.gameObject,"HelpBtn")
    self.helpPosition = self.HelpBtn:GetComponent("RectTransform").localPosition

    self.FindTreasureVipText = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/Text"):GetComponent("Text")
    self.FindTreasureVipEffect = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/FindTreasureVipEffect")

    self.refreshBtn = Util.GetGameObject(self.gameObject, "refreshBtn")
    self.refreshBtnText = Util.GetGameObject(self.refreshBtn, "Text")
    self.refreshBtnFreeText = Util.GetGameObject(self.refreshBtn, "Text/Text"):GetComponent("Text")
    self.refreshImageGo = Util.GetGameObject(self.refreshBtn, "refreshImage")
    self.refreshBtnNumText = Util.GetGameObject(self.refreshBtn, "refreshImage/numText"):GetComponent("Text")
    self.refreshBtnImage = Util.GetGameObject(self.refreshBtn, "refreshImage"):GetComponent("Image")

    self.materialImageBg = Util.GetGameObject(self.gameObject, "materialImageBg")
    self.materialImage = Util.GetGameObject(self.materialImageBg , "materialImage"):GetComponent("Image")
    self.materialImageNumText = Util.GetGameObject(self.materialImageBg, "Slider/numText"):GetComponent("Text")
    self.materialImageSlider = Util.GetGameObject(self.materialImageBg, "Slider"):GetComponent("Slider")

    self.refreshObj = Util.GetGameObject(self.gameObject, "refreshObj")
    self.refreshNumText = Util.GetGameObject(self.refreshObj, "numText"):GetComponent("Text")
    self.refreshImage = Util.GetGameObject(self.refreshObj, "refreshImage"):GetComponent("Image")
    orginLayer = 0

    self.skipBtn = Util.GetGameObject(self.gameObject, "skipBtn")
    this.skipImage = Util.GetGameObject(self.skipBtn, "skip")

end

--绑定事件（用于子类重写）
function FindTreasureMainPanel:BindEvent()
    Util.AddClick(self.btnBack, function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Task.Achievement)
        Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.TrainTask)
        self:ClosePanel()
    end)
    Util.AddClick(self.materialImageBg, function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, FindTreasureManager.materialItemId)
    end)
    Util.AddClick(self.refreshObj, function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, ConfigManager.GetConfigData(ConfigName.MazeTreasureSetting,1).RefreshItem[1])
    end)
    Util.AddClick(self.helpBtn, function()
       UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.FindTreasure,self.helpPosition.x,self.helpPosition.y)
   end)
    Util.AddClick(self.findTreasureVipBtn, function()
        UIManager.OpenPanel(UIName.FindTreasureVipPopup)
        FindTreasureManager.SetShowFindTreasureVipRedPoint(false)
        self.findTreasureVipBtnRedPoint:SetActive(FindTreasureManager.GetShowFindTreasureVipRedPoint())
    end)
    Util.AddClick(self.refreshBtn, function()
        if refreshIsMaterial then
            local isShowTwo = false
            for i = 1, #missionInfo do
                if missionInfo[i].state ~= 2 then
                    if ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(missionInfo[i].missionId%10000)).TaskType >= 4
                    and #missionInfo[i].heroId <= 0 then
                        isShowTwo = true
                    end
                end
            end
            if isShowTwo then
                MsgPanel.ShowTwo(GetLanguageStrById(10661), nil, function()
                    NetManager.FindTreasureRefreshRequest(function(msg)
                        TaskManager.RefreshFindTreasureData(msg)
                        if isRefreshAddNum then
                            PlayerManager.missingRefreshCount = PlayerManager.missingRefreshCount + 1
                        end
                        self:OnShowPanelData(true)
                    end)
                end, nil, nil, nil)
            else
                NetManager.FindTreasureRefreshRequest(function(msg)
                    TaskManager.RefreshFindTreasureData(msg)
                    if isRefreshAddNum then
                        PlayerManager.missingRefreshCount = PlayerManager.missingRefreshCount + 1
                    end
                    self:OnShowPanelData(true)
                end)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(11139)
        end
        --刷新回到顶部
        self.findTreasureGridGo.transform.anchoredPosition3D = Vector3(0, 0, 0)

    end)
    Util.AddClick(self.allGetBtn, function()
        local allGetMissionData = {}
        for i = 1, #missionInfo do
            if missionInfo[i].state == 1 then
                table.insert(allGetMissionData,missionInfo[i])
            end
        end
        if #allGetMissionData > 0 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.FindTreasure,0, function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                end)
                --刷新界面
                for i = 1, #allGetMissionData do
                    TaskManager.RefreshFindTreasureStatrData(allGetMissionData[i].missionId,2)
                end
                self:OnShowPanelData(true)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10662)
        end
    end)

    Util.AddClick(self.skipBtn, function()
        if this.isjump then
            this.isjump = false
            this.skipImage:SetActive(false)
        else
            this.isjump = true
            this.skipImage:SetActive(true)
        end
    end)
end

--添加事件监听（用于子类重写）
function FindTreasureMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.FindTreasure.RefreshFindTreasure, self.OnShowPanelData,self)
end

--移除事件监听（用于子类重写）
function FindTreasureMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.FindTreasure.RefreshFindTreasure, self.OnShowPanelData,self)
end

--界面打开时调用（用于子类重写）
function FindTreasureMainPanel:OnOpen(...)
end

function FindTreasureMainPanel:RefreshHelpBtn()
    Util.AddOnceClick(self.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.FindTreasure,self.helpPosition.x,self.helpPosition.y) 
    end)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FindTreasureMainPanel:OnShow()
    if this.isjump then
        this.isjump = true
        this.skipImage:SetActive(true)
    else
        this.isjump = false
        this.skipImage:SetActive(false)
    end
    self:OnShowPanelData(true)
    self:RefreshHelpBtn()
end

function FindTreasureMainPanel:OnSortingOrderChange()
    --特效穿透签到
    for i = 1, #findTreasureItemsGrid do
        for j = 1, #findTreasureItemsGrid[i] do
            findTreasureItemsGrid[i][j]:SetEffectLayer(self.sortingOrder)
        end
    end
    Util.AddParticleSortLayer(self.FindTreasureVipEffect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

function FindTreasureMainPanel:OnShowPanelData(isSort)
    refreshIsMaterial = true
    isRefreshAddNum = false
    TaskManager.SetFindTreasureDataState()

    local temp = TaskManager.GetTypeTaskList(TaskTypeDef.FindTreasure)
    if temp == nil then return end
    missionInfo = {}
    for i = 1, #temp do
        if temp[i].state ~= 2 then
            table.insert(missionInfo,temp[i])
        end
    end

    if isSort then
        self:MissionInfoSort(missionInfo)
    end
    for i = 1, math.max(#missionInfo, #findTreasureGrid) do
        local go = findTreasureGrid[i]
        if not go then
            go = newObject(self.rewardPre)
            --go:SetActive(true)
            go.transform:SetParent(self.findTreasureGridGo.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go.name = "rewardPre"..i
            findTreasureGrid[i] = go
            findTreasureItemsGrid[i] = {}
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #missionInfo do
        if missionInfo[i].state ~= 2 then
          self:ActivityRewardSingleShow(i,missionInfo[i])
        end
    end

    --DelayCreation(findTreasureGrid)

    if isFirstOpen then
        isFirstOpen = false
        self.findTreasureGridGo:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    end
    self:RemainTimeDown()

    --vip
    self.FindTreasureVipIcon:GetComponent("Image").sprite = Util.LoadSprite(FindTreasureVipTypeSprite[1])
    Util.SetGray(self.FindTreasureVipIcon,true)
    local curVipState = 1
    local curVipStateId = 1
    local FindTreasureGaoIdNum = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.GoFindTreasure)--高级寻宝
    local FindTreasureHaoIdNum = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.HaoFindTreasure)--豪华寻宝
    if FindTreasureGaoIdNum then
        curVipStateId = FindTreasureManager.FindTreasureGaoId
        curVipState = 2
        Util.SetGray(self.FindTreasureVipIcon,false)
    end
    if FindTreasureHaoIdNum then
        curVipStateId = FindTreasureManager.FindTreasureHaoId
        curVipState = 3
        Util.SetGray(self.FindTreasureVipIcon,false)
    end
    self.FindTreasureVipEffect:SetActive(curVipState > 1)
    --self.FindTreasureVipText.text = RefreshItemNum
    --self.FindTreasureVipTextIcon.sprite = Util.LoadSprite(FindTreasureVipTextTypeSprite[curVipState])
    -- self.FindTreasureVipImageIcon.sprite = Util.LoadSprite(FindTreasureVipImageTypeSprite[curVipState]) -- m5
    --刷新道具
    local mazeTreasureSetting = ConfigManager.GetConfigData(ConfigName.MazeTreasureSetting,1)--得判断是否 特权
    local itemNum = BagManager.GetItemCountById(FindTreasureManager.refreshTicketItemId)
    local RefreshItemNum = BagManager.GetItemCountById(mazeTreasureSetting.RefreshItem[1])
    
    self.refreshBtnFreeText.text = "(" .. itemNum .. "/".. 2 ..")"
    
    self.refreshBtnText:SetActive(itemNum > 0)
    self.refreshImageGo:SetActive(itemNum <= 0)

    if itemNum <= 0 then
        if RefreshItemNum > 0 then--劵有时花卷  没时候花妖晶
            self.refreshBtnNumText.text = mazeTreasureSetting.RefreshItem[2]
            
            self.refreshBtnImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,mazeTreasureSetting.RefreshItem[1]).ResourceID))
        else
            local refreshNum = PlayerManager.missingRefreshCount
            local cost = mazeTreasureSetting.Cost[2]
            local costNum = math.floor(((cost[1] * math.pow(refreshNum, 3) + cost[2] * math.pow(refreshNum, 2) + cost[3] * refreshNum + cost[4])))
            self.refreshBtnNumText.text = costNum
            
            self.refreshBtnImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,mazeTreasureSetting.Cost[1][1]).ResourceID))
            isRefreshAddNum = true
            if BagManager.GetItemCountById(mazeTreasureSetting.Cost[1][1]) < costNum then
                refreshIsMaterial = false
            end
        end
    end
    local mazeTreasureMax = ConfigManager.GetConfigData(ConfigName.PlayerLevelConfig,PlayerManager.level).MazeTreasureMax
    local bagNum = BagManager.GetItemCountById(FindTreasureManager.materialItemId)
    if bagNum >= mazeTreasureMax then
        self.materialImageNumText.text = "<size=46><B><color=#FF9725>"..PrintWanNum3(bagNum).."</color></B></size>/"..mazeTreasureMax
        self.materialImageSlider.value = bagNum/mazeTreasureMax
    else
        self.materialImageNumText.text = "<size=46><B><color=#FFD12B>"..PrintWanNum3(bagNum).."</color></B></size>/"..mazeTreasureMax
        self.materialImageSlider.value = bagNum/mazeTreasureMax
    end

    self.materialImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,FindTreasureManager.materialItemId).ResourceID))

    self.refreshNumText.text = RefreshItemNum
    self.refreshImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,mazeTreasureSetting.RefreshItem[1]).ResourceID))
    
    local gaoState = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.GoFindTreasure)
    local haoState = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.HaoFindTreasure)
    if gaoState and haoState then
        FindTreasureManager.SetShowFindTreasureVipRedPoint(false)
    end
    self.findTreasureVipBtnRedPoint:SetActive(FindTreasureManager.GetShowFindTreasureVipRedPoint())
end

--活动奖励2
function FindTreasureMainPanel:ActivityRewardSingleShow(index,rewardData)
    local activityRewardGo = findTreasureGrid[index]
    activityRewardGo:SetActive(true)
    local sConFigData = ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(rewardData.missionId%10000))
    local titleText = Util.GetGameObject(activityRewardGo, "titleImage/titleText"):GetComponent("Text")
    local titleText2 = Util.GetGameObject(activityRewardGo, "titleImage/titleText/titleText2"):GetComponent("Text")
    titleText.text = GetLanguageStrById(sConFigData.Desc)
    titleText2.text = FindTreasureMissionTitleTypeStr[sConFigData.TaskType]
    titleText.color =  taskColor[sConFigData.TaskType]
    titleText2.color =  taskColor[sConFigData.TaskType]
    local content = Util.GetGameObject(activityRewardGo, "content")

    for i = 1, math.max(#sConFigData.Reward, #findTreasureItemsGrid[index]) do
        local go = findTreasureItemsGrid[index][i]
        if not go then
            go = SubUIManager.Open(SubUIConfig.ItemView, content.transform)
            findTreasureItemsGrid[index][i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #sConFigData.Reward do
        findTreasureItemsGrid[index][i].gameObject:SetActive(true)
        findTreasureItemsGrid[index][i]:OnOpen(false,sConFigData.Reward[i],0.7,false,false,true,self.sortingOrder)
    end
    local getButton = Util.GetGameObject(activityRewardGo.gameObject, "getButton")
    local jumpButton = Util.GetGameObject(activityRewardGo.gameObject, "jumpButton")
    local quickGetButton = Util.GetGameObject(activityRewardGo.gameObject, "quickGetButton")
    local quickGetButtonImage = Util.GetGameObject(activityRewardGo.gameObject, "quickGetButton/item/Image")
    local quickGetButtonNumText = Util.GetGameObject(activityRewardGo.gameObject, "quickGetButton/item/numText")
    local getFinishText = Util.GetGameObject(activityRewardGo.gameObject, "getFinishText")
    local consumeObj = Util.GetGameObject(activityRewardGo.gameObject, "consumeObj")
    local consumeObjImage = Util.GetGameObject(activityRewardGo.gameObject, "consumeObj/Image"):GetComponent("Image")
    local consumeObjNumText = Util.GetGameObject(activityRewardGo.gameObject, "consumeObj/numText"):GetComponent("Text")
    local timeTextGo = Util.GetGameObject(activityRewardGo.gameObject, "timeObject")
    local changeBg = Util.GetGameObject(activityRewardGo.gameObject, "BG/change"):GetComponent("Image")
    
    timeTextGo:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId > 0)
    getButton:SetActive(rewardData.state == 1)
    jumpButton:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId <= 0)
    getFinishText:SetActive(rewardData.state == 2)

    if rewardData.state == 0 and rewardData.heroId and #rewardData.heroId <= 0 then
        changeBg.color = changeBgColor[1]
    else
        changeBg.color = changeBgColor[2]
    end
    
    consumeObj:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId <= 0)
    quickGetButton:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId > 0)
    consumeObjImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,sConFigData.TakeItem[1]).ResourceID))
    consumeObjNumText.text = sConFigData.TakeItem[2]
    quickGetButtonImage:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,sConFigData.SpeedUpTake[1]).ResourceID))
    quickGetButtonNumText:GetComponent("Text").text = sConFigData.SpeedUpTake[2]
    quickGetButtonImage:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId > 0)
    quickGetButtonNumText:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId > 0)
    Util.AddOnceClick(jumpButton, function()
        if this.isjump then
            FindTreasureMainPanel:Jump(rewardData)
        else
            UIManager.OpenPanel(UIName.FindTreasureDispatchPanel,rewardData)
        end
    end)
    Util.AddOnceClick(getButton, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.FindTreasure,rewardData.missionId, function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
            end)
            --刷新界面
            TaskManager.RefreshFindTreasureStatrData(rewardData.missionId,2)
            self:OnShowPanelData(true)
        end)
    end)
    Util.AddOnceClick(quickGetButton, function()
        NetManager.FindTreasureMissingRoomAccelerateRequest(rewardData.missionId, function()
            --刷新界面
            TaskManager.RefreshFindTreasureStatrData(rewardData.missionId,1)
            self:OnShowPanelData(true)
            end)
    end)
end
--刷新倒计时显示
function FindTreasureMainPanel:RemainTimeDown()
    if timer then
        timer:Stop()
        timer = nil
    end
    self:RemainTimeDown2()
    timer = Timer.New(function()
        self:RemainTimeDown2()
    end, 1, -1, true)
    timer:Start()
end
function FindTreasureMainPanel:RemainTimeDown2()
    for i = 1, #missionInfo do
        if missionInfo[i].state == 0 and #missionInfo[i].heroId > 0  then--未完成 已派遣
            local timeTextGo = Util.GetGameObject(findTreasureGrid[i], "timeObject/timeText")
            local timeDown  = missionInfo[i].progress - GetTimeStamp()
            if timeDown > 0 then
                timeTextGo:SetActive(true)
                local cursConFigData = ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(missionInfo[i].missionId%10000))
                local timeText = Util.GetGameObject(findTreasureGrid[i], "timeObject/timeText"):GetComponent("Text")
                local timeExp = Util.GetGameObject(findTreasureGrid[i], "timeObject/exp"):GetComponent("Slider")
                timeExp.value = (1- (timeDown / cursConFigData.WasteTime ))
                timeText.text = self:TimeStampToDateString(timeDown)
            else
                missionInfo[i].state = 1
                timeTextGo:SetActive(false)
                self:ActivityRewardSingleShow(i,missionInfo[i])
            end
        end
    end
end
function FindTreasureMainPanel:TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format("%02d:%02d:%02d", hour, minute, sec)
end
local sortTable = {
    [0] = 0,
    [1] = -1,
    [2] = 2,
}
function FindTreasureMainPanel:MissionInfoSort(missionInfo)
    table.sort(missionInfo, function(a, b)
        if a.state == b.state then
            if #a.heroId > 0 and #b.heroId > 0 or #a.heroId <= 0 and #b.heroId <= 0 then
                return ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(a.missionId%10000)).TaskType >
                        ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(b.missionId%10000)).TaskType
            else
                return #a.heroId < #b.heroId
            end
        else
            return sortTable[a.state] < sortTable[b.state]
        end
    end)
end

--界面关闭时调用（用于子类重写）
function FindTreasureMainPanel:OnClose()
    if timer then
        timer:Stop()
        timer = nil
    end
    refreshIsMaterial = true
    isRefreshAddNum = false
    Game.GlobalEvent:DispatchEvent(GameEvent.CloseUI.OnClose)
end

--界面销毁时调用（用于子类重写）
function FindTreasureMainPanel:OnDestroy()
     findTreasureGrid = {}
    findTreasureItemsGrid = {}
    missionInfo = {}
    refreshIsMaterial = true
    isRefreshAddNum = false
end

function FindTreasureMainPanel:Jump(rewardData)
    local isMaterial = true

    conFigData = ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(rewardData.missionId%10000))
    if BagManager.GetItemCountById(FindTreasureManager.materialItemId) < conFigData.TakeItem[2]  then isMaterial = false end

    if not isMaterial then
        PopupTipPanel.ShowTip(GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,FindTreasureManager.materialItemId).Name)..GetLanguageStrById(10655))
        return
    end
    -- for i = 1, #needState do
    --     if needState[i] < 1 then
    --         PopupTipPanel.ShowTipByLanguageId(10656)
    --         return
    --     end
    -- end

    local conditionHeros = {}
    for i = 1, #conFigData.Condition do
        local curConditionHeros = {}
        local curSortHeroList = HeroManager.GetFingTreasureAllHeroDatas()
        for k, v in pairs(curSortHeroList) do
            if conFigData.Condition[i][1] == FindTreasureNeedType.Star then
                if v.star >= conFigData.Condition[i][2] then
                    table.insert(curConditionHeros,v)
                end
            elseif conFigData.Condition[i][1] == FindTreasureNeedType.Pro then
                if v.heroConfig.PropertyName == conFigData.Condition[i][2] then
                    table.insert(curConditionHeros,v)
                end
            end
        end
        conditionHeros[i] = curConditionHeros
    end


    local curSelectHeroList = {}
    local conditionTabs = {}
    for i = 1, #conFigData.Condition do
        conditionTabs[i] = 0
    end
    for i = 1, #conditionHeros do
        if #conditionHeros[i] > 0 then
            local jixu = self:AutoSelectState(conditionTabs)
            --if jixu <= 0  then needState = conditionTabs return end
            if i > jixu then jixu = i end
            if #conditionHeros[jixu] <= 0  then  return end
          
            local curSelectSingleHero = self:AutoSelectHeroId(conditionHeros[jixu])
            -- curSelectSingleHero.sortId = curPanelHerosSortNum--排序
            -- curPanelHerosSortNum = curPanelHerosSortNum + 1--排序
            curSelectHeroList[curSelectSingleHero.dynamicId] = curSelectSingleHero
            -- for k = 1, #conFigData.Condition do
            --     if conFigData.Condition[k][1] == FindTreasureNeedType.Star then
            --         for j, v in pairs(curSelectHeroList) do
            --             if v.star >= conFigData.Condition[k][2] then
            --                 conditionTabs[i] = 1
            --             end
            --         end
            --     elseif conFigData.Condition[k][1] == FindTreasureNeedType.Pro then
            --         for j, v in pairs(curSelectHeroList) do
            --             if v.heroConfig.PropertyName == conFigData.Condition[k][2] then
            --                 conditionTabs[i] = 1
            --             end
            --         end
            --     end
            -- end
            --监测方法
            -- self:ShowNeedConditionData()
            -- self:ShowSelectHeroData()
        end
    end

    local curSelectHeroIdsTab = {}
    for k, v in pairs(curSelectHeroList) do
        table.insert(curSelectHeroIdsTab,k)
    end

    NetManager.FindTreasureMissingRoomSendHeroRequest(rewardData.missionId,curSelectHeroIdsTab,function()
        TaskManager.RefreshFindTreasureHerosData(rewardData.missionId,curSelectHeroIdsTab,conFigData.WasteTime)
        Game.GlobalEvent:DispatchEvent(GameEvent.FindTreasure.RefreshFindTreasure,true)
    end)
end

function FindTreasureMainPanel:AutoSelectState(conditionTabs)
    for i = 1, #conditionTabs do
        if conditionTabs[i] < 1 then
           return i
        end
    end
    return 0
end

function FindTreasureMainPanel:AutoSelectHeroId(conditionSingleHeros)
    local heroData = conditionSingleHeros[1]
    local endfeheNeedNum = 0
    for i = 1, #conditionSingleHeros do
        local feheNeedNum = 0
        for j = 1, #conFigData.Condition do
            if conFigData.Condition[j][1] == FindTreasureNeedType.Star then
                if conditionSingleHeros[i].star >= conFigData.Condition[j][2] then
                    feheNeedNum = feheNeedNum + 1
                end
            elseif conFigData.Condition[j][1] == FindTreasureNeedType.Pro then
                if conditionSingleHeros[i].heroConfig.PropertyName == conFigData.Condition[j][2] then
                    feheNeedNum = feheNeedNum + 1
                end
            end
        end
        if endfeheNeedNum < feheNeedNum then
            endfeheNeedNum = feheNeedNum
            heroData = conditionSingleHeros[i]
        end
    end
    return heroData
end

return FindTreasureMainPanel