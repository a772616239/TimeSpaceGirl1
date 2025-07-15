require("Base/BasePanel")
PatFacePanel = Inherit(BasePanel)
local patFaceSingleData = {}
local callBackEvent = nil
local openPanle
local guildWarRewardTabs = {}--公会战奖励
local cursortingOrder
-- local PatFaceFindFairy = require("Modules/Expert/PatFaceFindFairy")

--初始化组件（用于子类重写）
function PatFacePanel:InitComponent()
    self.btnBack = Util.GetGameObject(self.transform, "btnBack")

    -- -- 公会战系列
    self.obg3 = Util.GetGameObject(self.transform, "frame/obg3")
    self.btnObg3 = Util.GetGameObject(self.transform, "frame/obg3/btn")
    self.obg3Txt = Util.GetGameObject(self.transform, "frame/obg3/infoText"):GetComponent("Text")
    self.btnObg3Time = Util.GetGameObject(self.transform, "frame/obg3/cancelBtn/num"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function PatFacePanel:BindEvent()
    Util.AddClick(self.btnBack, function()
       self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function PatFacePanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.PatFace.PatFaceClear, self.JumpBtnClickEvent, self)
end

--移除事件监听（用于子类重写）
function PatFacePanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.PatFace.PatFaceClear, self.JumpBtnClickEvent, self)
end

--界面打开时调用（用于子类重写）
function PatFacePanel:OnOpen(_patFaceAllData,_callBackEvent,_openPanle)
    patFaceSingleData = _patFaceAllData
    callBackEvent = _callBackEvent
    openPanle = _openPanle
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PatFacePanel:OnShow()
    self:OnShowPatFaceData()
    PatFacePanel:SetSortingOrder(6100)
end

function PatFacePanel:OnShowPatFaceData()
    if patFaceSingleData then
        self.obg3:SetActive(patFaceSingleData.Type == FacePanelType.Championship)
        if patFaceSingleData.Type == FacePanelType.GuildFight
            or patFaceSingleData.Type == FacePanelType.Championship
        then
            PatFacePanel:OnShowObData_Match()
        else
        --     if patFaceSingleData.Type == FacePanelType.NewGrowGift
        --     or patFaceSingleData.Type == FacePanelType.OpenLevel
        --     or patFaceSingleData.Type == FacePanelType.BattleFailGift
        --     or patFaceSingleData.Type == FacePanelType.ValueDiscountGift
        --     or patFaceSingleData.Type == FacePanelType.GrowGift6
        --     or patFaceSingleData.Type == FacePanelType.GrowGift7
        --     or patFaceSingleData.Type == FacePanelType.GrowGift8
        --     or patFaceSingleData.Type == FacePanelType.GrowGift9
        --     or patFaceSingleData.Type == FacePanelType.GrowGift10
        --     or patFaceSingleData.Type == FacePanelType.guard
        --     or patFaceSingleData.Type == 27
        --     or patFaceSingleData.Type == 28
        -- then
            PatFacePanel:OnShowData()
        end
    else
        self:ClosePanel()
    end
end
function PatFacePanel:OnSortingOrderChange()
    cursortingOrder = self.sortingOrder
end

--锦标赛
local timerDown
function PatFacePanel:OnShowObData_Match()
    self.obg3Txt.text = GetLanguageStrById(patFaceSingleData.Desc)
    local rewardTableStr = ""
    if patFaceSingleData.OpenRules[1] == 6 then
        rewardTableStr = ConfigManager.GetConfigData(ConfigName.GuildRewardConfig,1).Reward--策划让默认直接读取公会战第一名奖励
        local rewardTable = string.split(rewardTableStr, "|")
        for i = 1, math.max(#guildWarRewardTabs, #rewardTable) do
            local go = guildWarRewardTabs[i]
            if not go then
                go = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(self.transform, "frame/obg3/rect/grid").transform)
                guildWarRewardTabs[i] = go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #rewardTable do
            local rewardItemTable = string.split(rewardTable[i],"#")
            guildWarRewardTabs[i].gameObject:SetActive(true)
            guildWarRewardTabs[i]:OnOpen(false,{rewardItemTable[1], 0}, 1)
        end
    elseif patFaceSingleData.OpenRules[1] == 7 then --锦标赛
        local rewardTable  = {}
        rewardTable = ConfigManager.GetConfigData(ConfigName.ChampionshipReward,1).SeasonReward--巅峰战
        for i = 1, math.max(#guildWarRewardTabs, #rewardTable) do
            local go = guildWarRewardTabs[i]
            if not go then
                go = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(self.transform, "frame/obg3/rect/grid").transform)
                guildWarRewardTabs[i] = go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #rewardTable do
            local rewardItemTable = rewardTable[i]
            guildWarRewardTabs[i].gameObject:SetActive(true)
            guildWarRewardTabs[i]:OnOpen(false,{rewardItemTable[1], 0}, 0.7)
        end
    end

    Util.AddOnceClick(self.btnObg3, function()
        self:JumpBtnClickEvent()
    end)
    local timeDownNum = 5
    if timerDown then
        timerDown:Stop()
        timerDown = nil
    end
    timerDown = Timer.New(function()
        self.btnObg3Time.text = "( " .. timeDownNum .." )"
        if timeDownNum < 0 then
            self:ClosePanel()
            if timerDown then
                timerDown:Stop()
                timerDown = nil
            end
        end
        timeDownNum = timeDownNum - 1
    end, 1, -1, true)
    timerDown:Start()
end

function PatFacePanel:OnShowData()
    UIManager.OpenPanel(UIName.UpGradePackagePanel,function()
        self:ClosePanel()
    end)
end

function PatFacePanel:JumpBtnClickEvent()
    if openPanle then
        openPanle.patFaceCallList:Clear()
    end
    if callBackEvent then
        callBackEvent = nil
    end
    if patFaceSingleData.Jump then
        JumpManager.GoJump( patFaceSingleData.Jump)
        self:ClosePanel()
    end
end
--界面关闭时调用（用于子类重写）
function PatFacePanel:OnClose()
    if timerDown then
        timerDown:Stop()
        timerDown = nil
    end
end

--界面销毁时调用（用于子类重写）
function PatFacePanel:OnDestroy()
    guildWarRewardTabs = {}
end

return PatFacePanel