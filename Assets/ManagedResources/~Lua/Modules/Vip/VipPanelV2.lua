--[[
 * @ClassName OperatingPanel
 * @Description 等级特权面板
 * @Date 2019/5/27 11:14
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
-- local VipTaskListItem = require("Modules/Vip/VipTaskListItem")

---@class VipPanelV2
local VipPanelV2 = quick_class("VipPanelV2", BasePanel)
local this = VipPanelV2
local kMaxGiftCount, kMaxTaskCount = 4, 5
local ReceiveTypeIconDef = {
    "t_tequan_tequandengjilibao", --特权等级礼包
    "t_tequan_meirijiangli", --每日礼包
}
local orginLayer

function VipPanelV2:InitComponent()
    orginLayer = 0
    self.bg = Util.GetGameObject(self.transform, "bg")
    if Screen.width / Screen.height < 1080 / 1920 then
        screenAdapte(self.bg)
    end

    this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    -- 嚣张的头像
    this.level = Util.GetGameObject(self.gameObject, "LeftUp/headBox/lvFrame/lv"):GetComponent("Text")
    this.playName = Util.GetGameObject(self.gameObject, "LeftUp/headBox/name"):GetComponent("Text")
    this.expSliderValue = Util.GetGameObject(self.gameObject, "LeftUp/headBox/exp"):GetComponent("Slider")
    this.headBox = Util.GetGameObject(self.gameObject, "LeftUp/headBox")
    this.headPos = Util.GetGameObject(self.gameObject, "LeftUp/headBox/headpos")
    this.headRedpot = Util.GetGameObject(self.gameObject, "LeftUp/headBox/redpot")
    this.teamPower = Util.GetGameObject(self.gameObject, "LeftUp/powerBtn/value"):GetComponent("Text")
    -- self.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    -- this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    -- this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    --topPart
    self.topPart = Util.GetGameObject(self.transform, "frame/topPart")
    self.BtnLeft = Util.GetGameObject(self.transform, "leftBtn")
    self.BtnRight = Util.GetGameObject(self.transform, "rightBtn")
    self.BtnTip = Util.GetGameObject(self.transform, "btnTip")
    self.curLevel = Util.GetGameObject(self.transform, "btnTip/bg/vip"):GetComponent("Text")

    self.StateRoot = Util.GetGameObject(self.topPart, "stateRoot")

    self.curStatePart = Util.GetGameObject(self.StateRoot, "curState")
    self.currentLvNum=Util.GetGameObject(self.curStatePart,"title/num"):GetComponent("Text")
    self.progressBar = Util.GetGameObject(self.gameObject,"bottomPart/progressBar"):GetComponent("Slider")  -- m5
    self.progressText = Util.GetGameObject(self.gameObject,"bottomPart/progressBar/Fill Area/Text"):GetComponent("Text") -- m5


    --midPart
    self.midPart = Util.GetGameObject(self.transform, "midPart")
    self.giftRoot = Util.GetGameObject(self.midPart, "giftRoot")
    self.giftTypeIcon = Util.GetGameObject(self.giftRoot, "title"):GetComponent("Image")
    self.giftItemContent = Util.GetGameObject(self.giftRoot, "grid")
    self.giftItemList = {}
    for i = 1, kMaxGiftCount do
        self.giftItemList[i] = Util.GetGameObject(self.giftRoot, "grid/prop_"..i)--SubUIManager.Open(SubUIConfig.ItemView, self.giftItemContent.transform)
    end

    self.effect = Util.GetGameObject(self.giftRoot, "UI_Effect_VipPanel")
    effectAdapte(self.effect)

    self.BtnReceive = Util.GetGameObject(self.topPart, "btnGet")
    self.BtnReceiveText = Util.GetGameObject(self.BtnReceive, "Text"):GetComponent("Text")
    self.receiveRedPoint = Util.GetGameObject(self.BtnReceive,"redPoint")

    --privilege
    self.privilegeTitle = Util.GetGameObject(self.transform, "frame/topPart/privilegeRoot/title"):GetComponent("Text")
    self.privilegeContent = Util.GetGameObject(self.transform, "frame/topPart/privilegeRoot/privilegeList/viewPort/content")
    self.privilegeItem = Util.GetGameObject(self.privilegeContent, "itemPro")
    self.privilegeItem.gameObject:SetActive(false)
    self.privilegeList = {}
    --bottomPart
    self.maxLv = Util.GetGameObject(self.transform, "bottomPart/maxLv")
    self.btnLvUp = Util.GetGameObject(self.transform, "bottomPart/btnLvUp")
    self.taskList = Util.GetGameObject(self.transform, "bottomPart/taskList")

    self.taskItemList = {}
    for i = 1, self.taskList.transform.childCount do
        self.taskItemList[i] = self.taskList.transform:GetChild(i - 1)
    end

end

-- 刷新玩家信息显示
function this.FreshPlayerInfo()
    this.level.text = PlayerManager.level
    this.expSliderValue.value = PlayerManager.exp / PlayerManager.userLevelData[PlayerManager.level].Exp
    this.playName.text = PlayerManager.nickName
    this.teamPower.text = FormationManager.GetFormationPower(FormationManager.curFormationIndex)
end

-- 设置头像
function this.SetPlayerHead()
    if not this.playerHead then
        this.playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.headPos.transform)
    end
    this.playerHead:SetHead(PlayerManager.head)
    this.playerHead:SetFrame(PlayerManager.frame)
    this.playerHead:SetScale(Vector3.one * 0.9)
    this.playerHead:SetPosition(Vector3.New(-5, 0, 0))

end

function VipPanelV2:BindEvent()

    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.VIP, this.helpPosition.x,this.helpPosition.y)
    end)

    Util.AddClick(self.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)

    Util.AddClick(self.BtnLeft, function()
        self:OnTurnLeftBtnClicked()
    end)
    Util.AddClick(self.BtnRight, function()
        self:OnTurnRightBtnClicked()
    end)

    Util.AddClick(self.BtnReceive, function()
        self:OnReceiveBtnClicked()
    end)

    Util.AddClick(self.btnLvUp, function()
        self:OnBtnLvUpClicked()
    end)

end

function VipPanelV2:OnVipTaskStatusChanged(taskId)
    self:OnTaskStatusChanged(taskId)
end

function VipPanelV2:OnVipDailyRewardStatusChanged(taskId)
    self:OnShow()
end

function VipPanelV2:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Vip.OnVipTaskStatusChanged, self.OnVipTaskStatusChanged, self)
    Game.GlobalEvent:AddEvent(GameEvent.Vip.OnVipDailyRewardStatusChanged, self.OnVipDailyRewardStatusChanged, self)
    Game.GlobalEvent:AddEvent(GameEvent.CloseUI.OnClose,self.OnVipDailyRewardStatusChanged, self)
end

function VipPanelV2:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Vip.OnVipTaskStatusChanged, self.OnVipTaskStatusChanged, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Vip.OnVipDailyRewardStatusChanged, self.OnVipDailyRewardStatusChanged, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.CloseUI.OnClose,self.OnVipDailyRewardStatusChanged, self)
end

--待功能扩展(试图打开某个状态)
function VipPanelV2:OnOpen()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
    this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.TeQuan })
end

function VipPanelV2:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

function VipPanelV2:OnShow()
    self:InitVipContext()
    self:SetPanelStatus()
    this.FreshPlayerInfo()
    this.SetPlayerHead()
end

function VipPanelV2:OnClose()
    if self.priThread then
        coroutine.stop(self.priThread)
        self.priThread = nil
    end

    if self.taskThread then
        coroutine.stop(self.taskThread)
        self.taskThread = nil
    end
end

function VipPanelV2:OnDestroy()
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.BtView)
end

function VipPanelV2:InitVipContext()
    self.context = {}
    self.context.UserMissionInfo = TaskManager.GetTypeTaskList(TaskTypeDef.VipTask)
    self.context.vipLevel = VipManager.GetVipLevel()
end

function VipPanelV2:SetPanelStatus()
    local maxLv = VipManager.GetMaxVipLevel()
    self.curLevel.text = GetLanguageStrById(12009)..self.context.vipLevel  -- m5
    -- 显示的
    self.curShowLevel = math.min(self.context.vipLevel + 1, maxLv)
    self:RefreshPanelStatus(self.curShowLevel)
    self:CheckTaskShow()
    self.BtnLeft:SetActive(self.curShowLevel > 1)
    self.BtnRight:SetActive(self.curShowLevel ~= maxLv)
end

-- 检测任务显示
function VipPanelV2:CheckTaskShow()
    if self.context.vipLevel == VipManager.GetMaxVipLevel() then
        self.taskList:SetActive(false)
        self.btnLvUp:SetActive(false)
        self.maxLv:SetActive(true)
    else
        self.maxLv:SetActive(false)
        local isfinish = true
        local taskListInfo = self.context.UserMissionInfo
        for i = 1, #taskListInfo do
            if taskListInfo[i].state ~= VipTaskStatusDef.Received then
                isfinish = false
            end
        end
        self.taskList:SetActive(not isfinish)
        self.btnLvUp:SetActive(isfinish)
        if not isfinish then 
            self:SetVipTaskList(self.context.vipLevel)
        end
    end
end


function VipPanelV2:SetProgressShow(level)
    local taskLevel = level - 1
    if taskLevel < self.context.vipLevel then
        self.progressBar.value = 1
        self.progressText.text = "4/4"
    elseif taskLevel > self.context.vipLevel then
        self.progressBar.value = 0
        self.progressText.text = "0/4"
    else
        local taskFinishNum = 0
        local taskListInfo = self.context.UserMissionInfo
        for i = 1, #taskListInfo do
            if taskListInfo[i].state == VipTaskStatusDef.Received then
                taskFinishNum = taskFinishNum + 1
            end
        end
        self.progressBar.value = taskFinishNum / #taskListInfo
        self.progressText.text = string.format("%d/%d", taskFinishNum, #taskListInfo)
    end
end

function VipPanelV2:SetRewardList(level)
    local VipLvConfig = ConfigManager.GetConfigData(ConfigName.VipLevelConfig, level)
    local configData = VipLvConfig.Property
    table.walk(self.giftItemList, function(giftItem)
        giftItem:SetActive(false)
    end)
    for idx, dataInfo in ipairs(configData) do
        local id = dataInfo[1]
        local num = dataInfo[2]
        if num ~= 0 then
            self.giftItemList[idx]:SetActive(true)
            local propInfo = ConfigManager.GetConfigData(ConfigName.PropertyConfig, id)
            if propInfo.Style == 1 then
                self.giftItemList[idx]:GetComponent("Text").text = string.format(GetLanguageStrById(12023), propInfo.Info) 
                Util.GetGameObject(self.giftItemList[idx], "value"):GetComponent("Text").text = "+"..num
            elseif propInfo.Style == 2 then
                self.giftItemList[idx]:GetComponent("Text").text = propInfo.Info
                Util.GetGameObject(self.giftItemList[idx], "value"):GetComponent("Text").text = string.format("+%d%%", num/100)
            end
        end
    end
end


--特权增益描述
function VipPanelV2:SetVipPrivileges(curVipLevel)
    if self.priThread then
        coroutine.stop(self.priThread)
        self.priThread = nil
    end
    table.walk(self.privilegeList, function(privilegeItem)
        privilegeItem:SetActive(false)
    end)
    local curVipData = PrivilegeManager.GetTipsByVipLv(curVipLevel)
    local tempNumber = 0
    self.priThread = coroutine.start(function()
        for _, privilegeInfo in ipairs(curVipData) do
            
            if privilegeInfo.value == "" 
            or (privilegeInfo.IfFloat == 1 and privilegeInfo.value > 0)
            or (privilegeInfo.IfFloat == 2 and privilegeInfo.value > 1) 
            then
                tempNumber = tempNumber + 1
                local item = self:GetPrivilegeItem(tempNumber)
                item:SetActive(false)
                -- local str = "<size=45><color=#7bb15bFF> </color></size>"
                -- str = string.format("<size=45><color=#7bb15bFF>%s</color></size>", privilegeInfo.value)
                if privilegeInfo.IfFloat == 2 then --特权关卡挂机加成百分比
                    Util.GetGameObject(item, "title"):GetComponent("Text").text = string.format(privilegeInfo.content, "<color=#7AB159><size=35>"..(privilegeInfo.value*100-100).."%</size></color>")
                else
                    Util.GetGameObject(item, "title"):GetComponent("Text").text = string.format(privilegeInfo.content, "<color=#7AB159><size=35>" .. privilegeInfo.value .. "</size></color>")
                end
                PlayUIAnim(Util.GetGameObject(item, "content"))
                coroutine.wait(0.03)
                --加成为0就别丢人现眼了
                if privilegeInfo.value == 0 then
                -- if privilegeInfo.id==1 and (privilegeInfo.value*100-100)==0 then
                    item:SetActive(false)
                else
                    item:SetActive(true)
                end
            end

        end
    end)
end
function VipPanelV2:SetExtraPrivilege(index, configData)
    local item = self:GetPrivilegeItem(index)
    item.gameObject:SetActive(true)
    local str = GetLanguageStrById(10106)
    for _, rewardInfo in ipairs(configData.VipBoxDailyReward) do
        local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig, rewardInfo[1])
        assert(itemConfig, string.format("ConfigName.ItemConfig not find Id:%s", rewardInfo[1]))
        str = str .. string.format("%s<size=45><color=#7bb15bFF>%s</color></size>", GetLanguageStrById(itemConfig.Name), rewardInfo[2])
    end
    Util.GetGameObject(item, "title"):GetComponent("Text").text = str
end
function VipPanelV2:GetPrivilegeItem(index)
    if self.privilegeList[index] then
        return self.privilegeList[index]
    else
        local newItem = newObjToParent(self.privilegeItem, self.privilegeContent)
        table.insert(self.privilegeList, newItem)
        return newItem
    end
end

--设置特权任务
function VipPanelV2:SetVipTaskList(level)
    local configData = ConfigManager.GetConfigData(ConfigName.VipLevelConfig, level)
    table.walk(self.taskItemList, function(taskItem)
        taskItem.gameObject:SetActive(false)
    end)

    if level < self.context.vipLevel then
        for i, taskId in ipairs(configData.OpenRules) do
            self.taskItemList[i]:Init(taskId)
            local taskConfigInfo = ConfigManager.GetConfigData(ConfigName.TaskConfig, taskId)
            self.taskItemList[i]:SetValue({state = VipTaskStatusDef.Received, progress = taskConfigInfo.TaskValue[2][1]})
        end
        self:SetTaskAnimation(#configData.OpenRules)
    elseif level > self.context.vipLevel then
        for i, taskId in ipairs(configData.OpenRules) do
            self.taskItemList[i]:Init(taskId)
            self.taskItemList[i]:SetValue({state = VipTaskStatusDef.NotFinished, progress = 0})
        end
        self:SetTaskAnimation(#configData.OpenRules)
    elseif level == self.context.vipLevel then--好像一定走这里
        if #self.context.UserMissionInfo == 0 then
            return
        end
        for i, taskInfo in ipairs(self.context.UserMissionInfo) do
            -- self.taskItemList[i]:Init(taskInfo.missionId)
            -- self.taskItemList[i]:SetValue(taskInfo)
            self:showSingleTask(self.taskItemList[i],taskInfo)
        end
        self:SetTaskAnimation(#self.context.UserMissionInfo)
    end
end

--单个初始化任务
function VipPanelV2:showSingleTask(item,taskInfo)
    --creat
    local itemPos = Util.GetGameObject(item, "content/itemPos")
    local giftInfo = SubUIManager.Open(SubUIConfig.ItemView, itemPos.transform)
    local desc = Util.GetGameObject(item, "content/desc"):GetComponent("Text")
    local progressBar = Util.GetGameObject(item, "content/progressBar"):GetComponent("Slider")
    local progressValue = Util.GetGameObject(item, "content/dealBtn/value"):GetComponent("Text")
    local dealBtn = Util.GetGameObject(item, "content/dealBtn")

    local finishFlag = Util.GetGameObject(item, "content/finished")
    local redPoint = Util.GetGameObject(item,"content/redPoint")

    --init
    local data = nil
    local taskConfigInfo = ConfigManager.GetConfigData(ConfigName.TaskConfig, taskInfo.missionId)
    giftInfo:OnOpen(false, taskConfigInfo.Reward[1], 0.8)
    desc.text = GetLanguageStrById(taskConfigInfo.Desc)
    progressBar.value = 0
    progressValue.text = "0/" .. taskConfigInfo.TaskValue[2][1]
    dealBtn:SetActive(false)
    finishFlag:SetActive(false)
    redPoint:SetActive(false)

    --setvalue
    data = taskInfo
    progressBar.value = taskInfo.progress / taskConfigInfo.TaskValue[2][1]
    progressValue.text = string.format("%s/%s", taskInfo.progress, taskConfigInfo.TaskValue[2][1])
    dealBtn:SetActive(taskInfo.state == VipTaskStatusDef.NotFinished or taskInfo.state == VipTaskStatusDef.CanReceive)
    if dealBtn.activeSelf then
        dealBtn:GetComponent("Image").sprite = Util.LoadSprite(TaskGetBtnIconDef[taskInfo.state])
        if taskInfo.state == 0 then  -- m5
            Util.GetGameObject(item, "content/dealBtn/Text1"):GetComponent("Text").text = GetLanguageStrById(10023)
        else
            Util.GetGameObject(item, "content/dealBtn/Text"):GetComponent("Text").text = GetLanguageStrById(10022)
        end
    end
    finishFlag:SetActive(taskInfo.state == VipTaskStatusDef.Received)
    redPoint:SetActive(taskInfo.state == VipTaskStatusDef.CanReceive)

    Util.AddOnceClick(dealBtn,function ()
        if data.state == VipTaskStatusDef.NotFinished then
            JumpManager.GoJump(taskConfigInfo.Jump[1])
        else
            NetManager.TakeMissionRewardRequest(TaskTypeDef.VipTask, taskConfigInfo.Id, function(respond)
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1)
                TaskManager.SetTypeTaskState(TaskTypeDef.VipTask, taskConfigInfo.Id, VipTaskStatusDef.Received)
                Game.GlobalEvent:DispatchEvent(GameEvent.Vip.OnVipTaskStatusChanged, taskConfigInfo.Id)
                self:SetPanelStatus()
            end)
        end
    end)
end


function VipPanelV2:SetTaskAnimation(length)
    if self.taskThread then
        coroutine.stop(self.taskThread)
        self.taskThread = nil
    end
    self.taskThread = coroutine.start(function()
        for i = 1, length do
            self.taskItemList[i].gameObject:SetActive(false)
            PlayUIAnim(Util.GetGameObject(self.taskItemList[i], "content"))
            coroutine.wait(0.05)
            self.taskItemList[i].gameObject:SetActive(true)
            -- coroutine.wait(0.05)
        end
    end)
end


function VipPanelV2:OnTurnLeftBtnClicked()
    -- self:SwitchState(self:GetCurrentStatus(self.context.UserMissionInfo))
    if self.curShowLevel <= 1 then
        return 
    end
    self.curShowLevel = self.curShowLevel - 1
    self:RefreshPanelStatus(self.curShowLevel)

    self.BtnLeft:SetActive(self.curShowLevel > 1)
    self.BtnRight:SetActive(self.curShowLevel ~= VipManager.GetMaxVipLevel())
end

function VipPanelV2:OnTurnRightBtnClicked()
    -- self:SwitchState(VipShowStatusDef.Preview)
    if self.curShowLevel >= VipManager.GetMaxVipLevel() then
        return 
    end
    self.curShowLevel = self.curShowLevel + 1
    self:RefreshPanelStatus(self.curShowLevel)

    self.BtnLeft:SetActive(self.curShowLevel > 1)
    self.BtnRight:SetActive(self.curShowLevel ~= VipManager.GetMaxVipLevel())
end

function VipPanelV2:OnBtnLvUpClicked()
    NetManager.RequestVipLevelUp(function(respond)
        self:OnShow()
        SoundManager.PlaySound(SoundConfig.Sound_VipUpLevel)
    end)
end

--刷新界面
function VipPanelV2:RefreshPanelStatus(level)
    self:SetProgressShow(level)
    self.currentLvNum.text = level
    self:SetVipPrivileges(level)
    self:SetRewardList(level)
end

--特权任务发生变化
function VipPanelV2:OnTaskStatusChanged(taskId)
    for i = 1, #self.context.UserMissionInfo do
        local taskInfo = self.context.UserMissionInfo[i]
        if taskInfo.missionId == taskId then
            taskInfo.state = VipTaskStatusDef.Received
            self.taskItemList[i]:SetValue(taskInfo)
            break
        end
    end

    if self.curShowLevel - 1 == self.context.vipLevel then
        self:SetProgressShow(self.curShowLevel)
    end

    local isfinish = true
    local taskListInfo = self.context.UserMissionInfo
    for i = 1, #taskListInfo do
        if taskListInfo[i].state ~= VipTaskStatusDef.Received then
            isfinish = false
        end
    end
    if isfinish then
        self:CheckTaskShow()
    end
end

--跳转显示新手提示圈
function this.ShowGuideGo()
    JumpManager.ShowGuide(UIName.VipPanelV2, this.taskItemList[1].dealBtn)
end

--修正因VIP字体导致等级数篡位
function this.CheckVipLvPos(tarObj,lv)
    if lv>9 then
        tarObj.transform:DOAnchorPosX(10,0)
    else
        tarObj.transform:DOAnchorPosX(0,0)
    end
end

return VipPanelV2