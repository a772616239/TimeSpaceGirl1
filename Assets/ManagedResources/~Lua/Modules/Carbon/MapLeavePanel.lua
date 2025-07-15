require("Base/BasePanel")
MapLeavePanel = Inherit(BasePanel)
local this = MapLeavePanel
local challengeConfig = ConfigManager.GetConfig(ConfigName.ChallengeConfig)

local tipType = {}
--初始化组件（用于子类重写）
function MapLeavePanel:InitComponent()

    this.btnWait = Util.GetGameObject(self.gameObject, "Frame/btnWait")
    this.frame = Util.GetGameObject(self.gameObject, "Frame")
    this.starRoot = Util.GetGameObject(self.gameObject, "Frame/Img/Rect")
    this.btnEnd = Util.GetGameObject(self.gameObject, "Frame/btnEnd")
    this.condition = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item2/condition"):GetComponent("Text")

    -- 任务状态显示
    this.missionTip = Util.GetGameObject(self.gameObject, "Frame/Img")

    -- 三星条件显示
    this.MissionDone = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item1/done")
    this.MissionDoing = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item1/doing")
    this.TimeDone = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item2/done")
    this.TimeDoing = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item2/doing")
    this.ExploreDone = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item3/done")
    this.ExploreDoing = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item3/doing")

    -- 完成任务文字
    this.TextMissionDone = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item1/condition_done")
    this.TextMissionDoing = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item1/condition")
    this.TextTimeDone = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item2/condition_done")
    this.TextTimeDoing = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item2/condition")
    this.TextExploreDone = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item3/condition_done")
    this.TextExploreDoing = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item3/condition")
    -- 遮罩
    this.Mask = Util.GetGameObject(self.gameObject, "Mask")
    -- 试炼副本提示文字
    this.trialText = Util.GetGameObject(self.gameObject, "Frame/trialText")

    -- 显示探索度
    this.exploreText = Util.GetGameObject(self.gameObject, "Frame/Img/Rect/Item3")
    --=普通副本提示文字
    this.normalTip = Util.GetGameObject(self.gameObject, "Frame/Img/backTip")

    tipType = {
        [1] = this.starRoot,
        [3] = this.starRoot,
        [2] = this.trialText,
    }
end

--绑定事件（用于子类重写）
function MapLeavePanel:BindEvent()

    Util.AddClick(this.btnWait, function ()
        this.Mask:SetActive(false)
        --PlayUIAnimBack(this.frame, function ()
        --    PlayUIAnimBack(this.starRoot, function ()
                self:ClosePanel()
        --    end)
        --end)
    end)

    Util.AddClick(this.btnEnd, function()
        UIManager.OpenPanel(UIName.MapStatsPanel)
        --PlayUIAnimBack(this.frame, function ()
        --    PlayUIAnimBack(this.starRoot, function ()
                self:ClosePanel()
        --    end)
        --end)
    end)
end


--添加事件监听（用于子类重写）
function MapLeavePanel:AddListener()

end

--移除事件监听（用于子类重写）
function MapLeavePanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MapLeavePanel:OnOpen(...)

    this.InitAimi()
end


-- 初始化动画
function this.InitAimi()
    this.Mask:SetActive(true)
    tipType[CarbonManager.difficulty]:SetActive(true)
    if CarbonManager.difficulty == 2 then
        this.missionTip:SetActive(false)
    else
        this.missionTip:SetActive(true)
    end

    if CarbonManager.difficulty ~= 2 then
        -- 设置三星结果
        local isMissionDone = CarbonManager.IsMissionDone()
        this.MissionDone:SetActive(isMissionDone)
        this.MissionDoing:SetActive(not isMissionDone)
        this.TextMissionDone:SetActive(isMissionDone)
        this.TextMissionDoing:SetActive(not isMissionDone)


        local isLimitTime = CarbonManager.DoneAtLimitTime()
        this.TimeDone:SetActive(false)
        this.TimeDoing:SetActive(false)
        this.TextTimeDone:SetActive(false)
        this.TextTimeDoing:SetActive(false)
        local missionData = challengeConfig[MapManager.curMapId]
        this.TextTimeDone:GetComponent("Text").text = GetLanguageStrById(10363) .. missionData.Time .. GetLanguageStrById(10364)
        this.TextTimeDoing:GetComponent("Text").text = GetLanguageStrById(10363) .. missionData.Time .. GetLanguageStrById(10364)

        local isExploreDone = CarbonManager.ExplorationDone()
        this.ExploreDone:SetActive(isExploreDone)
        this.ExploreDoing:SetActive(not isExploreDone)
        this.TextExploreDone:SetActive(isExploreDone)
        this.TextExploreDoing:SetActive(not isExploreDone)
        this.normalTip:SetActive(CarbonManager.difficulty == 1)
    end

    -- 显示探索度
    this.exploreText:SetActive(CarbonManager.difficulty == 1)


end

--界面关闭时调用（用于子类重写）
function MapLeavePanel:OnClose()

    tipType[CarbonManager.difficulty]:SetActive(false)
end

--界面销毁时调用（用于子类重写）
function MapLeavePanel:OnDestroy()

end

return MapLeavePanel