require("Base/BasePanel")
GuildActivePointPopup = Inherit(BasePanel)
local this = GuildActivePointPopup
local isEff = true

local GuildActiveTaskConfig = ConfigManager.GetConfig(ConfigName.GuildActiveTaskConfig)

--初始化组件（用于子类重写）
function GuildActivePointPopup:InitComponent()
    this.btnClose = Util.GetGameObject(self.gameObject, "bg/btnBack")

    this.Scroll = Util.GetGameObject(self.gameObject, "bg/Scroll")
    this.TaskPre = Util.GetGameObject(self.gameObject, "bg/TaskPre")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.TaskPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 5))
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.RewardReview = Util.GetGameObject(self.gameObject, "bg/Reward/RewardReview")
    this.RewardGrid = Util.GetGameObject(self.gameObject, "bg/Reward/Grid/RewardGrid")
    this.AllGet = Util.GetGameObject(self.gameObject, "bg/Reward/AllGet")
    this.Status = Util.GetGameObject(self.gameObject, "bg/Reward/Status")
    this.GetBtn = Util.GetGameObject(self.gameObject, "bg/Reward/Status/GetBtn")
    this.Prompt = Util.GetGameObject(self.gameObject, "bg/Reward/Status/Prompt")

    this.CurPro = Util.GetGameObject(self.gameObject, "bg/Property/CurPro")
    this.NextPro = Util.GetGameObject(self.gameObject, "bg/Property/NextPro")
    this.MaxFont = Util.GetGameObject(self.gameObject, "bg/Property/MaxFont")
    this.ActiveLvNum = Util.GetGameObject(self.gameObject, "bg/Property/ActiveLv/Num"):GetComponent("Text")
    this.ExpBar = Util.GetGameObject(self.gameObject, "bg/Property/Exp/ExpBar")
    this.ExpBarText = Util.GetGameObject(self.gameObject, "bg/Property/Exp/ExpBar/Fill Area/Text"):GetComponent("Text")
    this.TodayNum = Util.GetGameObject(self.gameObject, "bg/ActiveNum/Today/Num"):GetComponent("Text")
    this.WeekNum = Util.GetGameObject(self.gameObject, "bg/ActiveNum/Week/Num"):GetComponent("Text")

    this.repeatItemView = {}
end

--绑定事件（用于子类重写）
function GuildActivePointPopup:BindEvent()
    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.RewardReview, function()
        UIManager.OpenPanel(UIName.GuildActivePointRewardPopup)
    end)
end

--添加事件监听（用于子类重写）
function GuildActivePointPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.UpdateMainWithServer)
end

--移除事件监听（用于子类重写）
function GuildActivePointPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.UpdateMainWithServer)
end

--界面打开时调用（用于子类重写）
function GuildActivePointPopup:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildActivePointPopup:OnShow()
    this.UpdateMain()
    GuildActivePointPopup.UpdateMainWithServer()        --< 二次刷新 战斗出来
end

function GuildActivePointPopup.UpdateMain()
    this.data = TaskManager.GetTypeTaskList(TaskTypeDef.GuildActiveTask)

    table.sort(this.data, function(a, b)
        if a.state == b.state then
            local aConfig = ConfigManager.GetConfigDataByKey(ConfigName.GuildActiveTaskConfig, "Type", a.missionId)
            local bConfig = ConfigManager.GetConfigDataByKey(ConfigName.GuildActiveTaskConfig, "Type", b.missionId)
            if aConfig.RefreshType == bConfig.RefreshType then
                return aConfig.Id > bConfig.Id
            else
                return aConfig.RefreshType > bConfig.RefreshType
            end
        else
            return a.state < b.state
        end
    end)

    local itemList = {}
    this.scrollView:SetData(this.data, function(index, root)
        this:FillItem(root, this.data[index])
        itemList[index] = root
    end)
    this.scrollView:SetIndex(1)
    
    if isEff then
        DelayCreation(itemList)
        isEff = false
    end

    this.UpdateData()
    this:UpdateProUI()
    this:UpdateRewardUI()
end

function GuildActivePointPopup.UpdateMainWithServer()
    NetManager.RequestMyGuildInfo(function()
        GuildActivePointPopup.UpdateMain()
    end)
end

function GuildActivePointPopup.UpdateData()
    local myMemInfo = MyGuildManager.GetMyMemInfo()
    
    this.guildActiveRewardProgress = myMemInfo.guildActiveRewardProgress
    this.guildActiveNumToday = myMemInfo.guildActiveNumToday
    this.guildActiveNumWeek = myMemInfo.guildActiveNumWeek

    this.liveness, this.reduceCnt, this.isMax, this.curMaxExp = MyGuildManager.GetLivenessData()
end

function GuildActivePointPopup:FillItem(go, data)
    -- go:SetActive(true)
    local guildActiveTaskConfig = ConfigManager.GetConfigDataByKey(ConfigName.GuildActiveTaskConfig, "Type", data.missionId)
    Util.GetGameObject(go, "Grid/TaskDesc/Text"):GetComponent("Text").text = GetLanguageStrById(guildActiveTaskConfig.Desc)
    local progress = Util.GetGameObject(go, "Grid/TimesLimit/Text")
    progress:GetComponent("Text").text = "(" .. data.progress .. "/" .. guildActiveTaskConfig.Times .. ")"
    -- Util.GetGameObject(go, "Grid/SingleActive/Text"):GetComponent("Text").text = GetLanguageStrById(guildActiveTaskConfig.EachReward[2])
    Util.GetGameObject(go, "Grid/SingleActive/Text"):GetComponent("Text").text = guildActiveTaskConfig.EachReward[2]
    local Finish = Util.GetGameObject(go, "Grid/Status/Finish")
    local Goto = Util.GetGameObject(go, "Grid/Status/Goto")
    Finish:SetActive(false)
    Goto:SetActive(false)
    if data.state == 0 then
        Goto:SetActive(true)
        progress:SetActive(true)
    else
        Finish:SetActive(true)
        progress:SetActive(false)
    end
    Util.AddOnceClick(Goto, function()
        if data.state == 0 then
            JumpManager.GoJump(guildActiveTaskConfig.Jump)
        end
    end)

    Util.GetGameObject(go, "Corner1"):SetActive(guildActiveTaskConfig.RefreshType == 1)
    Util.GetGameObject(go, "Corner2"):SetActive(guildActiveTaskConfig.RefreshType == 2)

end

function GuildActivePointPopup:UpdateProUI()
    this.MaxFont:SetActive(false)
    this.NextPro:SetActive(false)
    if this.isMax then
        this.MaxFont:SetActive(true)
    else
        this.NextPro:SetActive(true)

        local allPro = MyGuildManager.GetLivenessAllPro(this.liveness + 1)
        for i = 1, 2 do
            local go = Util.GetGameObject(this.NextPro, "Pro" .. i)
            local idx = 0
            
            for k, v in pairs(allPro) do
                idx = idx + 1
               
                if idx == i then
                    this.SetPro(go, v, k)

                end
            end
        end
    end

    local allPro = MyGuildManager.GetLivenessAllPro(this.liveness)
    if next(allPro) == nil then --< 空值取下一级属性 仅配表所有属性一样可用
        local allProNext = MyGuildManager.GetLivenessAllPro(this.liveness + 1)
        local allProAhead = {}
        for _, v in pairs(allProNext) do
            table.insert(allProAhead, {pro = _, v = v})
        end
        for i = 1, 2 do
            local go = Util.GetGameObject(this.CurPro, "Pro" .. i)
            this.SetPro(go, 0, allProAhead[i].pro)

        end
    end
    for i = 1, 2 do --< 正常有属性时设置值
        local go = Util.GetGameObject(this.CurPro, "Pro" .. i)
        local idx = 0
        for k, v in pairs(allPro) do
            idx = idx + 1
            if idx == i then
                this.SetPro(go, v, k)
                if this.liveness==0 then
                   this.SetPro(go, 0, k) 
                end
            end
        end
    end

    this.ActiveLvNum.text = this.liveness
    this.TodayNum.text = this.guildActiveNumToday
    this.WeekNum.text = this.guildActiveNumWeek
    this.ExpBar:GetComponent("Slider").value = this.reduceCnt / this.curMaxExp
    this.ExpBarText.text = this.reduceCnt .. "/" .. this.curMaxExp

    if this.isMax then
        this.ExpBar:GetComponent("Slider").value = 1
        this.ExpBarText.text = "MAX"
    end
   
end

function GuildActivePointPopup:UpdateRewardUI()
    this.AllGet:SetActive(false)
    this.Prompt:SetActive(false)
    this.GetBtn:SetActive(false)

    local curGetLiveness = -1
    if this.liveness > 0 and this.guildActiveRewardProgress < this.liveness then
        --> 可领
        this.GetBtn:SetActive(true)
        Util.AddOnceClick(this.GetBtn, function()
            NetManager.GuildActiveLevelUp(function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
                NetManager.RequestMyGuildInfo(function(msgb)
                    this.UpdateData()
                    this:UpdateRewardUI()
                end)
            end)
        end)

        curGetLiveness = this.guildActiveRewardProgress + 1
    else
        if this.isMax then
            this.AllGet:SetActive(true)
        else
            this.Prompt:SetActive(true)
            this.Prompt:GetComponent("Text").text = string.format(GetLanguageStrById(12538), this.liveness + 1)
            curGetLiveness = this.liveness + 1
        end
    end

    if curGetLiveness ~= -1 then
        local guildActiveConfigData = ConfigManager.GetConfigDataByKey(ConfigName.GuildActiveConfig, "Lv", curGetLiveness)

        local itemDatas = {}
        for i = 1, #guildActiveConfigData.Reward do
            table.insert(itemDatas, {itemid = guildActiveConfigData.Reward[i][1], num = guildActiveConfigData.Reward[i][2]})
        end

        if #this.repeatItemView == 0 then
            for i = 1, 4 do --< 支持四个
                this.repeatItemView[i] = SubUIManager.Open(SubUIConfig.ItemView, this.RewardGrid.transform)
            end
        end

        for i = 1, #this.repeatItemView do
            if i <= #itemDatas then
                this.repeatItemView[i]:OnOpen(false, {itemDatas[i].itemid, itemDatas[i].num}, 0.7, nil, nil, nil, nil, itemDatas[i].cornerType)
                this.repeatItemView[i].gameObject:SetActive(true)
            else
                this.repeatItemView[i].gameObject:SetActive(false)
            end
        end
    end
end

function GuildActivePointPopup.SetPro(go, value, proId)
    local proData = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyId", proId)
    local pro = 0
    if proData.Style == 1 then               --< 绝对值
        pro = GetPropertyFormatStr(1, value)
    elseif proData.Style == 2 then           --< 百分比
        pro = GetPropertyFormatStr(2, value)
    end
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(proData.Icon))
    Util.GetGameObject(go, "name"):GetComponent("Text").text = GetLanguageStrById(proData.Info)
    Util.GetGameObject(go, "value"):GetComponent("Text").text = pro
end

--界面关闭时调用（用于子类重写）
function GuildActivePointPopup:OnClose()
    isEff = true
end

--界面销毁时调用（用于子类重写）
function GuildActivePointPopup:OnDestroy()
    isEff = true
    this.repeatItemView = {}
end

return GuildActivePointPopup