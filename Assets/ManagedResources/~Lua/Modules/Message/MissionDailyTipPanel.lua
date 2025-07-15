require("Base/BasePanel")
require("Base/Stack")
MissionDailyTipPanel = Inherit(BasePanel)
local this = MissionDailyTipPanel
local showType = 0
this.timer = Timer.New()
--初始化组件（用于子类重写）
function MissionDailyTipPanel:InitComponent()
    this.startTran = Util.GetGameObject(self.transform, "startTran")
    this.info = Util.GetGameObject(self.transform, "info")
    this.titleTypeText = Util.GetGameObject(self.transform, "info/titleTypeText"):GetComponent("Text")
    this.titleText = Util.GetGameObject(self.transform, "info/titleText"):GetComponent("Text")
    this.icon = Util.GetGameObject(self.transform, "info/Image/icon"):GetComponent("Image")
    this.content = Util.GetGameObject(self.transform, "info/content")
    this.qianwangButton = Util.GetGameObject(self.transform, "info/qianwangButton/Image")
    this.goAni = self.gameObject--:GetComponent("PlayFlyAnim")
end

--添加事件监听（用于子类重写）
function MissionDailyTipPanel:AddListener()
end

--移除事件监听（用于子类重写）
function MissionDailyTipPanel:RemoveListener()
end

function MissionDailyTipPanel:BindEvent()
    Util.AddClick(this.qianwangButton, function()
        if UIManager.IsOpen(UIName.BattlePanel) then
            PopupTipPanel.ShowTipByLanguageId(11347)--请等待战斗结束后查看！
            return
        end
        if showType == 1 then
            UIManager.OpenPanel(UIName.MissionDailyPanel, 1)
        elseif showType == 2 then
            UIManager.OpenPanel(UIName.MissionDailyPanel, 2)
        elseif showType == 3 then
            UIManager.OpenPanel(UIName.BattlePassPanel, 2)
        -- elseif showType == 4 then
        --     UIManager.OpenPanel(UIName.OperatingPanel, {tabIndex = 4, extraParam = 2, showType = 2})
        end
        self:ClosePanel()
    end)
end

local sortingOrder = 0
function MissionDailyTipPanel:OnSortingOrderChange()
    sortingOrder = self.sortingOrder
end

--界面打开时调用（用于子类重写）--OnOpen
function MissionDailyTipPanel.ShowInfo(_showType,_showStr)
    UIManager.OpenPanel(UIName.MissionDailyTipPanel)
    this:PlayerAniAndShowData(_showType,_showStr)
end

function MissionDailyTipPanel:PlayerAniAndShowData(_showType,showStr)
    showType = _showType
    this.info.transform.localPosition = this.startTran.transform.localPosition
    this.titleText.text = GetLanguageStrById(showStr)
    local showReward
    if showType == 1 then
        this.titleTypeText.text = GetLanguageStrById(11348)
        showReward = 12042
    elseif showType == 2 then
        this.titleTypeText.text = GetLanguageStrById(11349)
        showReward = 209255
    elseif showType == 3 then
        this.titleTypeText.text = GetLanguageStrById(50154)
        showReward = 11517
    -- elseif showType == 4 then
    --     this.titleTypeText.text = GetLanguageStrById(50365)
    --     showReward = 12036
    end
    this.icon.sprite = Util.LoadSprite(GetResourcePath(showReward))
    this.info.transform:DOLocalMove(Vector3.New(this.startTran.transform.localPosition.x, this.startTran.transform.localPosition.y - 350, this.startTran.transform.localPosition.z), 0.3, false):OnStart(function ()
    end):OnComplete(function ()
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            this.info.transform:DOLocalMove(this.startTran.transform.localPosition, 0.3, false):OnStart(function ()
            end):OnComplete(function ()
                this:RefreshShowDailyMissionTipPanel()
            end):SetEase(Ease.Linear)
        end,3)
        this.timer:Start()
    end):SetEase(Ease.Linear)
end

function MissionDailyTipPanel:RefreshShowDailyMissionTipPanel()
    local AllShowTipMission = TaskManager.GetAllShowTipMission()
    if #AllShowTipMission > 0 then
        local data = AllShowTipMission[1]
        if data.type == TaskTypeDef.DayTask then
            local curConfig = ConfigManager.TryGetConfigData(ConfigName.DailyTasksConfig, data.Id)
            if curConfig then
                this:PlayerAniAndShowData(1, string.format(GetLanguageStrById(curConfig.Desc), curConfig.Values[2][1]))
            else
                this:ClosePanel()
            end
        elseif data.type == TaskTypeDef.Achievement then
            local curConfig = ConfigManager.TryGetConfigData(ConfigName.AchievementConfig, data.Id)
            if curConfig then
                this:PlayerAniAndShowData(2, curConfig.ContentsShow)
            else
                this:ClosePanel()
            end
        elseif data.type == TaskTypeDef.BattlePass then
            local curConfig = ConfigManager.TryGetConfigData(ConfigName.BattlePassTask, data.Id)
            if curConfig then
                this:PlayerAniAndShowData(3, curConfig.Desc)
            else
                this:ClosePanel()
            end
        -- elseif data.type == 15 then
        --     local curConfig = ConfigManager.TryGetConfigData(ConfigName.ActivityRewardConfig, data.Id)
        --     if curConfig then
        --         MissionDailyTipPanel.ShowInfo(4, string.format(GetLanguageStrById(50366), curConfig.Reward[1][2]))
        --     else
        --         this:ClosePanel()
        --     end
        end

        TaskManager.DelAllShowTipMissionOne()
    else
        this:ClosePanel()
    end
end

--界面关闭时调用（用于子类重写）
function MissionDailyTipPanel:OnClose()
    this.info.transform.localPosition = this.startTran.transform.localPosition
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function MissionDailyTipPanel:OnDestroy()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

return MissionDailyTipPanel