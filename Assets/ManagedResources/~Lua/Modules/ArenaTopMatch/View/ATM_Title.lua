local ATM_Title={}
local this = ATM_Title

--初始化组件（用于子类重写）
function ATM_Title:InitComponent(root)
    -- 标题数据
    this.stagePanel = Util.GetGameObject(root.transform, "Name")
    this.matchName = Util.GetGameObject(this.stagePanel, "name"):GetComponent("Text")
    this.freshTime = Util.GetGameObject(this.stagePanel, "time"):GetComponent("Text")
    this.timeType = Util.GetGameObject(this.stagePanel, "timelab"):GetComponent("Text")

    this.integralPanel = Util.GetGameObject(root.transform, "ImgIntegral")
    this.score = Util.GetGameObject(this.integralPanel, "integral"):GetComponent("Text")

    this.rankPanel = Util.GetGameObject(root.transform, "ImgRank")
    this.myRank = Util.GetGameObject(this.rankPanel, "rankImg/myRank"):GetComponent("Text")

    this.imgBig = Util.GetGameObject(root.transform, "ImgBig")
    this.imgSmall = Util.GetGameObject(root.transform, "ImgSmall")

    this.btnHelp = Util.GetGameObject(root.transform, "helpBtn")
    this.helpPosition = this.btnHelp:GetComponent("RectTransform").localPosition
end

--绑定事件（用于子类重写）
function ATM_Title:BindEvent()
    Util.AddClick(this.btnHelp, function ()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.ArenaTypePanelTopMatch, this.helpPosition.x, this.helpPosition.y)
    end)

end

--添加事件监听（用于子类重写）
function ATM_Title:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshBaseShow)
end

--移除事件监听（用于子类重写）
function ATM_Title:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshBaseShow)

end

--界面打开时调用（用于子类重写）
function ATM_Title:OnOpen(...)
    -- 默认都不显示
    this:SetTitleType(0)
end
function ATM_Title:OnShow()
end
function ATM_Title:OnSortingOrderChange()
end

-- 0 都不显示 1 都显示 2 只显示name
function ATM_Title:SetTitleType(type)
    if type == 0 then
        this.stagePanel:SetActive(false)
    elseif type == 1 then
        this.stagePanel:SetActive(true)
    elseif type == 2 then
        this.stagePanel:SetActive(true)
    end

    -- 刷新显示
    this.RefreshBaseShow()
end

-- 刷新基础显示
function this.RefreshBaseShow()
    local isOpen = ArenaTopMatchManager.IsTopMatchActive()
    local tmData = ArenaTopMatchManager.GetBaseData()
    local isJoin = tmData.joinState == 1
    local titleName, stageName, stateName = ArenaTopMatchManager.GetCurTopMatchName()
    if not isOpen then
        if tmData.progress == -2 then
            this.matchName.text = titleName
            this.timeType.text = GetLanguageStrById(10177)
            -- 排名显示
            this.myRank.text = ArenaTopMatchManager.GetRankNameByRank(tmData.myrank)
            --  判断积分显示
            if isJoin then
                -- 判断是否被淘汰
                this.score.text = tmData.myscore * ArenaTopMatchManager.GetMatchDeltaIntegral()
            else
                this.score.text = GetLanguageStrById(10178)
            end
        else
            this.matchName.text = titleName
            this.timeType.text = GetLanguageStrById(10179)
            this.myRank.text = GetLanguageStrById(10041)
            this.score.text = GetLanguageStrById(10122)
        end
    else
        -- 标题显示
        if tmData.progress == -1 then --即将开启
            this.matchName.text = titleName
            this.timeType.text = GetLanguageStrById(10179)
        elseif tmData.progress == -2 then--已结束
            this.matchName.text = titleName
            this.timeType.text = GetLanguageStrById(10177)
        else
            this.matchName.text = titleName .. "·" .. stageName
            this.timeType.text = stateName
        end
        -- 排名显示
        this.myRank.text = ArenaTopMatchManager.GetRankNameByRank(tmData.myrank)
        --  判断积分显示
        if isJoin then
            -- 判断是否被淘汰
            this.score.text = tmData.myscore * ArenaTopMatchManager.GetMatchDeltaIntegral()
        else
            this.score.text = GetLanguageStrById(10178)
        end

    end

    -- 计时器
    if not this.timer then
        local function _UpdateTime()
            local isOpen = ArenaTopMatchManager.IsTopMatchActive()
            local baseData = ArenaTopMatchManager.GetBaseData()
            if baseData.progress == -2 then
                this.freshTime.text = ""
                return
            end
            if isOpen then
                local leftTime = baseData.endTime - PlayerManager.serverTime
                leftTime = leftTime < 0 and 0 or leftTime
                this.freshTime.text = TimeToHMS(leftTime)
            else
                local startTime = ArenaTopMatchManager.GetTopMatchTime()
                local during = startTime - PlayerManager.serverTime
                during = during <= 0 and 0 or during
                local timeStr = TimeToHMS(during)
                this.freshTime.text = timeStr
            end
        end
        _UpdateTime()
        this.timer = Timer.New(_UpdateTime, 1 , -1, true)
        this.timer:Start()
    end
end

--界面关闭时调用（用于子类重写）
function ATM_Title:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function ATM_Title:OnDestroy()
end

return ATM_Title