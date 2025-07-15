require("Base/BasePanel")
local TabBox = require("Modules/Common/TabBox") -- 引用
SupportPanel = Inherit(BasePanel)
local this = SupportPanel

local artifactConfig = ConfigManager.GetConfig(ConfigName.ArtifactConfig)
local taskConfig = ConfigManager.GetConfig(ConfigName.TaskConfig)
local artifactLevelConfig = ConfigManager.GetConfig(ConfigName.ArtifactLevelConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local artifactRefineConfig = ConfigManager.GetConfig(ConfigName.ArtifactRefineConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local artifactSoulConfig = ConfigManager.GetConfig(ConfigName.ArtifactSoulConfig)
-- local _levelFinish = true
-- local _isAutoLevelUp = false
-- local _autoLevelUpIntervalTime = 0.1
-- local _lastLevelUpTime = 0
local _tabIdx = 1
-- local redPointList = {}

local _TabData = {
    [1] = { name = GetLanguageStrById(22293) },
    [2] = { name = GetLanguageStrById(22294) },
    [3] = { name = GetLanguageStrById(22709) },
    [4] = { name = GetLanguageStrById(22708)}
}
-- local redType = {
--     [1] = RedPointType.Support_LevelUp,
--     [2] = RedPointType.Support_Skill,
--     [3] = RedPointType.Support_Remould,
-- }
local tabRedGo = {}
-- local tabIsInit = false

local skillState = {
    [1] = "cn2-X1_shouhu_renwusuo",
    [2] = "cn2-X1_shouhu_renwuwancheng",
    [3] = "cn2-X1_shouhu_renwuyiling"
}

--初始化组件（用于子类重写）
function SupportPanel:InitComponent()

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    this.backBtn = Util.GetGameObject(self.gameObject, "backBtn")

    --信息
    this.Info = Util.GetGameObject(self.gameObject, "Info")
    this.lihuiPos = Util.GetGameObject(self.Info, "lihui")
    this.name = Util.GetGameObject(self.Info, "nameBg/name"):GetComponent("Text")
    this.skill = Util.GetGameObject(self.Info, "skill")
    this.skillName = Util.GetGameObject(self.skill, "skillName"):GetComponent("Text")
    this.skillDesc = Util.GetGameObject(self.skill, "skillDesc"):GetComponent("Text")

    this.leftBtn = Util.GetGameObject(self.gameObject, "leftBtn")
    this.rightBtn = Util.GetGameObject(self.gameObject, "rightBtn")
    -- this.AllUnit = Util.GetGameObject(self.Info, "AllUnit")
    this.HelpBtn = Util.GetGameObject(self.Info,"helpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    --激活
    this.activatePart = Util.GetGameObject(self.gameObject, "activatePart")
    this.activateFight = Util.GetGameObject(self.activatePart, "activateFight")
    this.progressBar = Util.GetGameObject(this.activatePart, "progressBar")--进度
    this.progressList = {}
    for i = 1, 4 do
        this.progressList[i] = Util.GetGameObject(this.progressBar, "progress/progress" .. i)
    end

    this.activateTask = Util.GetGameObject(this.activatePart, "activateTask")--任务
    this.taskListGo = {}
    this.taskredPointListGo={}--红点
    for i = 1, 4 do
        this.taskListGo[i] = Util.GetGameObject(this.activateTask, "taskList/itemPro" .. i)
    end
    for i = 1, 4 do
        this.taskredPointListGo[i] = Util.GetGameObject(this.activateTask, "taskList/itemPro" .. i .."/redPoint")
    end
    this.repeatItemViews = {}

    -- > trainningPart
    this.trainningPart = Util.GetGameObject(self.gameObject, "trainningPart")
    this.UpLevelPart = Util.GetGameObject(self.trainningPart, "UpLevelPart")--升级
    this.UpLevelBtnOnce = Util.GetGameObject(this.UpLevelPart, "upLv")
    this.UpLevelBtnAuto = Util.GetGameObject(this.UpLevelPart, "autoUpLv")
    this.upLvTrigger = Util.GetEventTriggerListener(this.UpLevelBtnAuto)
    this.UpLevelBtnOnceRedPoint = Util.GetGameObject(this.UpLevelPart, "upLv/Redpot")
    this.UpLevelBtnAutoRedPoint = Util.GetGameObject(this.UpLevelPart, "autoUpLv/Redpot")

    Util.GetGameObject(this.UpLevelPart, "autoUpLv/Text"):GetComponent("Text").text=GetLanguageStrById(50336) --91000158 暂停一键


    this.SkillPart = Util.GetGameObject(self.trainningPart, "SkillPart")--技能
    this.upLvBtnRedPoint = Util.GetGameObject(this.SkillPart, "upLv/Redpot")
 
    this.ModifyPart = Util.GetGameObject(self.trainningPart, "ModifyPart")--改造
    this.Reform = Util.GetGameObject(this.ModifyPart, "Reform")
    this.ModifyBtnRedPoint = Util.GetGameObject(this.ModifyPart, "ModifyBtn/Redpot")
    this.RemouldPropertys = Util.GetGameObject(this.ModifyPart, "RemouldPropertys")--改造总览
    this.pro = Util.GetGameObject(this.RemouldPropertys, "pro")
    this.ScrollStatic = Util.GetGameObject(this.RemouldPropertys, "ScrollStatic")
    local w = this.ScrollStatic.transform.rect.width
    local h = this.ScrollStatic.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ScrollStatic.transform, this.pro, nil,
            Vector2.New(w, h), 1, 3, Vector2.New(8, 14))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    this.scrollView.elastic = false

    this.previewBtn = Util.GetGameObject(this.ModifyPart, "previewBtn")


    -- this.ReinforceBtn = Util.GetGameObject(self.trainningPart, "ReinforceBtn")
    -- this.ReinforceBtnRedPoint = Util.GetGameObject(this.trainningPart, "ReinforceBtn/Redpot")
    -- this.RemouldPropertys = Util.GetGameObject(this.frame, "RemouldPropertys")

    this.OverclockingPart = Util.GetGameObject(this.trainningPart, "OverclockingPart")
    this.slider = Util.GetGameObject(this.OverclockingPart, "Slider"):GetComponent("Slider")
    this.reduceBtn = Util.GetGameObject(this.OverclockingPart, "leftbtn")
    this.addBtn = Util.GetGameObject(this.OverclockingPart, "rightbtn")
    this.count = Util.GetGameObject(this.OverclockingPart, "Slider/count"):GetComponent("Text")
    this.SureBtn = Util.GetGameObject(this.OverclockingPart, "SureBtn")

    this.ReinforceBtnRedPoint = Util.GetGameObject(this.OverclockingPart, "SureBtn/Redpot")

    this.tabBox = Util.GetGameObject(self.trainningPart, "TabBox")

    -- this.AllSupport = Util.GetGameObject(self.gameObject, "AllSupport")
    -- this.AllSupport:SetActive(false)
end

--绑定事件（用于子类重写）
function SupportPanel:BindEvent()
    Util.AddClick(this.leftBtn, function()
        this.SetAutoLvUpValue()
        self:Turn(true)
    end)
    Util.AddClick(this.rightBtn, function()
        this.SetAutoLvUpValue()
        self:Turn(false)
    end)
    -- Util.AddClick(this.AllUnit, function()
    --     this.SetAutoLvUpValue()
    --     -- this.SetAllSupportUI()
    --     this.AllSupport:SetActive(true)
    -- end)
    Util.AddClick(this.backBtn, function()
        -- if this.AllSupport.activeSelf then
        --     this.AllSupport:SetActive(false)
        -- else
            self:ClosePanel()
        -- end
    end)

    Util.AddClick(this.UpLevelBtnOnce, function()
        -- if not _isAutoLevelUp then
            SupportPanel.LevelUp(1)
        -- end
    end)
    Util.AddClick(this.UpLevelBtnAuto, function()
        -- _isAutoLevelUp = not _isAutoLevelUp
        SupportPanel.LevelUp(2)
    end)

    Util.AddClick(this.previewBtn, function()
        if this.Reform.activeSelf then
            this.Reform:SetActive(false)
            this.RemouldPropertys:SetActive(true)
            this.previewBtn:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_shouhu_qiehuan")
        else
            this.Reform:SetActive(true)
            this.RemouldPropertys:SetActive(false)
            this.previewBtn:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_hecheng_jiezhi_yulan") 
        end
    end)

    Util.AddClick(this.SureBtn, function()
        if this.supportLv >= 3 then
            local count = this.slider.value
            if count <= 0 then
                PopupTipPanel.ShowTipByLanguageId(22301)
                return
            end
            local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            NetManager.GetSupportSoulUp(count, function(_msg)
                if _msg.result and _msg.result ~= 0 then
                    local oldlv = SupportManager.GetDataById("soulNum")
                    SupportManager.SetDataById("soulNum", oldlv + count)
                    PopupTipPanel.ShowTipByLanguageId(22302)
                    -- self:ClosePanel()
                    RefreshPower(oldPower)
                    SupportPanel.SetOverclockingUI()

                    if SupportPanel then
                        SupportPanel.CheckRedPoint()
                    end
                    
                end
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10598)
            return
        end
    end)
    Util.AddSlider(this.slider.gameObject, function(go, value)
        this.count.text = value
    end)

    Util.AddClick(this.reduceBtn, function()
        local curCount = this.slider.value
        if curCount <= 1 then return end
        this.slider.value = curCount - 1
    end)
    Util.AddClick(this.addBtn, function()
        local curCount = this.slider.value
        if curCount >= this.maxNum then return end
        this.slider.value = curCount + 1
    end)
end
--更新帮助按钮的事件
function SupportPanel.RefreshHelpBtn()
    this.HelpBtn:SetActive(true)
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Support,this.helpPosition.x,this.helpPosition.y + 30) 
    end)
end

--添加事件监听（用于子类重写）
function SupportPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.UpdateActivateUI)
    Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, this.SetAutoLvUpValue)
end

--移除事件监听（用于子类重写）
function SupportPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.UpdateActivateUI)
    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, this.SetAutoLvUpValue)
end

--界面打开时调用（用于子类重写）
function SupportPanel:OnOpen()
   this.RefreshHelpBtn()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SupportPanel:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.SupportPanel })

    this:Init()
    
    FixedUpdateBeat:Add(this.OnUpdate, self)--长按方法注册

    -- _levelFinish = true
    -- _isAutoLevelUp = false
    -- _lastLevelUpTime = 0
end

function SupportPanel.SetAutoLvUpValue(panelId)
    if panelId == 5 or panelId == 209 then
        return
    end
    -- _isAutoLevelUp = false
    SupportPanel.ChangeTab(_tabIdx)
end

function SupportPanel:Init()
    self.ArtifactDataArray = SupportManager.GetArtifactDataArray()
    self.curArtifactData = self.ArtifactDataArray[#self.ArtifactDataArray]
    self.curArtifactIdx = #self.ArtifactDataArray

    local isAllActive = SupportManager.CheckIsAllActivate()

    Util.GetGameObject(self.Info, "nameBg"):SetActive(not isAllActive)
    
    this.skill:SetActive(not isAllActive)
    -- this.activateTask:SetActive(not isAllActive)
    -- this.activateFight:SetActive(not isAllActive)

    this.activatePart:SetActive(not isAllActive)
    this.trainningPart:SetActive(isAllActive)

    this.UpdateActivateUI()

    this.tabCtrl = TabBox.New()
    this.tabCtrl:SetTabAdapter(this.OnTabAdapter) 
    this.tabCtrl:SetTabIsLockCheck(this.OnTabIsLockCheck)
    this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)
    this.tabCtrl:Init(this.tabBox, _TabData)

    _tabIdx = 1
    SupportPanel.ChangeTab(_tabIdx)

    SupportPanel.CheckRedPoint()
end

--刷新页面
function SupportPanel.UpdateActivateUI()
    this:UpdateActivateUpUI()
    this:UpdateActivateDownUI()
end

function SupportPanel:UpdateActivateUpUI()
    local lv
    if SupportManager.GetSupportDatas().level > 1 then
        lv = "+" .. SupportManager.GetSupportDatas().level - 1
    else
        lv = ""
    end
    this.name.text = GetLanguageStrById(self.curArtifactData.bData.Name) .. lv
    Util.GetGameObject(this.SkillPart,"nameBg/name"):GetComponent("Text").text = this.name.text
    Util.GetGameObject(this.activateFight,"nameBg/name"):GetComponent("Text").text = this.name.text
    Util.GetGameObject(this.UpLevelPart,"nameBg/name"):GetComponent("Text").text = this.name.text
    Util.GetGameObject(this.ModifyPart,"nameBg/name"):GetComponent("Text").text = this.name.text
    Util.GetGameObject(this.OverclockingPart,"nameBg/name"):GetComponent("Text").text = this.name.text
    
    --> skill
    local artifactId = this.curArtifactData.sData.artifactid
    local artifactSkillLv = 1
    local configData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ArtifactSkillConfig, "ArtifactId", artifactId, "SkillLevel", artifactSkillLv)
    local skillData = skillConfig[configData.SkillId]
    local desc = GetSkillConfigDesc(skillData)
    this.skillName.text = GetLanguageStrById(skillData.Name)
    this.skillDesc.text = desc

    --> 立绘
    if this.live then
        poolManager:UnLoadLive(this.liveName, this.live)
    end
    this.liveName = artifactConfig[artifactId].Image
    this.live = poolManager:LoadLive(this.liveName, this.lihuiPos.transform,Vector3.one,Vector3.New(0,0,0))

    if #self.ArtifactDataArray < 2 then
        this.leftBtn:SetActive(false)
        this.rightBtn:SetActive(false)
    else
        this.leftBtn:SetActive(true)
        this.rightBtn:SetActive(true)
    end
end

function SupportPanel:UpdateActivateDownUI()
    local isAllTaskGet = nil
    local finishTimes = 0
    local totalTaskNum = 0

    if self.curArtifactData.openStatus == 0 then
        local singleTasks = SupportManager.GetTaskData(self.curArtifactData.sData.artifactid)
        totalTaskNum = #singleTasks
        local getTimes = 0
        for i = 1, #singleTasks do
            if singleTasks[i].state ~= 0 then
                finishTimes = finishTimes + 1
                if singleTasks[i].state == 2 then
                    getTimes = getTimes + 1
                end
            end
        end

        isAllTaskGet = getTimes == totalTaskNum
    else
        isAllTaskGet = true
    end

    Util.GetGameObject(self.Info, "nameBg"):SetActive(not isAllTaskGet)
    this.progressBar:SetActive(not isAllTaskGet)
    this.skill:SetActive(not isAllTaskGet)
    this.activateFight:SetActive(isAllTaskGet)
    this.activateTask:SetActive(not isAllTaskGet)
    
    if isAllTaskGet then
        local artifactId = this.curArtifactData.sData.artifactid
        local artifactSkillLv = 1
        local configData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ArtifactSkillConfig, "ArtifactId", artifactId, "SkillLevel", artifactSkillLv)
        local skillData = skillConfig[configData.SkillId]
        local desc = GetSkillConfigDesc(skillData)
        Util.GetGameObject(this.activateFight,"skillName"):GetComponent("Text").text = GetLanguageStrById(skillData.Name)
        Util.GetGameObject(this.activateFight,"skillDesc"):GetComponent("Text").text = desc
        
        Util.AddOnceClick(Util.GetGameObject(this.activateFight, "btnLvUp"), function()
            JumpManager.GoJump(26082)
        end)
    else             
        --< 任务
        self:UpdateTaskUI()
    end

    --> progress
    if finishTimes == totalTaskNum then
        this.progressBar:GetComponent("Slider").value = 3
    else
        this.progressBar:GetComponent("Slider").value = finishTimes - 1
    end
    
    for i = 1, 4 do
        this.progressList[i]:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_shouhu_jindu_daijiesuo")
        if i <= finishTimes then
            this.progressList[i]:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_shouhu_jindu_wancheng")
        end
    end
end

--刷新激活任务
function SupportPanel:UpdateTaskUI()
    local config = artifactConfig[self.curArtifactData.sData.artifactid]
    if config then
        local singleTasks = SupportManager.GetTaskData(config.ArtifactId)
        for i = 1, 4 do
            if singleTasks[i] then
                local taskid = config.UnlockTaskID[i]
                local status = singleTasks[i].state
                local desc = Util.GetGameObject(this.taskListGo[i], "desc")
                local btn = Util.GetGameObject(this.taskListGo[i], "dealBtn")
                local redPoint = Util.GetGameObject(this.taskListGo[i], "redPoint")
                desc:GetComponent("Text").text = GetLanguageStrById(taskConfig[taskid].Desc)
                redPoint:SetActive(status == 1)
                desc:SetActive(status ~= 2)
                Util.AddOnceClick(btn, function()
                    if status == 0 then
                        if taskConfig[taskid].Jump then
                            JumpManager.GoJump(taskConfig[taskid].Jump[1])
                        end
                    elseif status == 1 then
                        NetManager.TakeMissionRewardRequest(TaskTypeDef.SupportTask, taskid, function (msg)
                            redPoint:SetActive(status == 1)
                            TaskManager.SetTypeTaskState(TaskTypeDef.SupportTask, taskid, TaskStatusDef.Finished)
                            SupportPanel:Init()
                            local isAllFinish = SupportManager.CheckIsAllFinish(config.ArtifactId)
                            if isAllFinish then
                                NetManager.GetSupportActive(function(msg_SupportActive)
                                    TaskManager.SetTypeTaskList(TaskTypeDef.SupportTask, msg_SupportActive.userMissionInfo)
                                    SupportManager.SetStatus(config.ArtifactId, 1)
                                    SupportManager.UpdateArray(msg_SupportActive.supportId)
                                    --CheckRedPointStatus(RedPointType.Support_Gift)
                                    
                                    --这个恭喜获得是完成那个任务的恭喜获得,恭喜获得完成后再弹获得新守护
                                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                                        SupportPanel:ShowGetNew(config.ArtifactId)
                                        Timer.New(function()
                                            SupportPanel:Init()
                                        end,0.5):Start()
                                    end)
                                end)
                            else
                                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                                end)
                            end
                            CheckRedPointStatus(RedPointType.Support)
                        end)
                    elseif status == 2 then
                    end
                end)
                
                local jump = Util.GetGameObject(this.taskListGo[i],"jump")
                local get = Util.GetGameObject(this.taskListGo[i],"get")
                local num = Util.GetGameObject(jump,"num"):GetComponent("Text")
                local num2 = Util.GetGameObject(get,"num"):GetComponent("Text")
                local icon = Util.GetGameObject(jump,"icon"):GetComponent("Image")
                local icon2 = Util.GetGameObject(get,"icon"):GetComponent("Image")
                btn:GetComponent("Button").enabled = true
                
                if status == 0 then--前往
                    this.taskListGo[i]:GetComponent("Image").sprite = Util.LoadSprite(skillState[1])
                    jump:SetActive(true)
                    get:SetActive(false)
                elseif status == 1 then--领取
                    this.taskListGo[i]:GetComponent("Image").sprite = Util.LoadSprite(skillState[2])
                    jump:SetActive(false)
                    get:SetActive(true)
                elseif status == 2 then--已领取
                    this.taskListGo[i]:GetComponent("Image").sprite = Util.LoadSprite(skillState[3])
                    jump:SetActive(false)
                    get:SetActive(false)
                    btn:GetComponent("Button").enabled = false
                end

                -- local itemPos = Util.GetGameObject(this.taskListGo[i], "content/itemPos")
                local sortItems = {}
                for j = 1, #taskConfig[taskid].Reward do
                    table.insert(sortItems, {itemid = taskConfig[taskid].Reward[j][1], num = taskConfig[taskid].Reward[j][2]})
                end

                local idx = i
                if this.repeatItemViews[idx] == nil then
                    this.repeatItemViews[idx] = {}
                end
                local totalNum = math.max(#sortItems, #this.repeatItemViews[idx])
                for itemidx = 1, totalNum do
                    if itemidx <= #sortItems then
                        if this.repeatItemViews[idx][itemidx] == nil then
                            -- this.repeatItemViews[idx][itemidx] = SubUIManager.Open(SubUIConfig.ItemView, itemPos.transform)
                        end
                        -- this.repeatItemViews[idx][itemidx]:OnOpen(false, {sortItems[itemidx].itemid, sortItems[itemidx].num}, 0.65, nil, nil, nil, nil, nil)
                        -- this.repeatItemViews[idx][itemidx].gameObject:SetActive(true)
                        icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[sortItems[itemidx].itemid].ResourceID))
                        icon2.sprite = Util.LoadSprite(GetResourcePath(itemConfig[sortItems[itemidx].itemid].ResourceID))
                        num.text = sortItems[itemidx].num
                        num2.text = sortItems[itemidx].num
                    else
                        if this.repeatItemViews[idx][itemidx] ~= nil then
                            -- this.repeatItemViews[idx][itemidx].gameObject:SetActive(false)
                        end
                    end
                end
            else
                LogError("support task not 4")
            end
            
        end
    end
end

function SupportPanel:Turn(isLeft)
    if #self.ArtifactDataArray < 2 then
        return
    end
    if isLeft then
        self.curArtifactIdx = self.curArtifactIdx - 1 < 1 and #self.ArtifactDataArray or self.curArtifactIdx - 1
    else
        self.curArtifactIdx = self.curArtifactIdx + 1 > #self.ArtifactDataArray and 1 or self.curArtifactIdx + 1
    end
    self.curArtifactData = self.ArtifactDataArray[self.curArtifactIdx]

    this:UpdateActivateUI()
    SupportPanel.SetSkillUI()
end

function SupportPanel.OnTabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab, "default")
    local select = Util.GetGameObject(tab, "select")
    Util.GetGameObject(default,"Text"):GetComponent("Text").text = _TabData[index].name
    Util.GetGameObject(select,"Text"):GetComponent("Text").text = _TabData[index].name

    default:SetActive(status == "default")
    select:SetActive(status == "select")

    _tabIdx = index
    SupportPanel.ChangeTab(_tabIdx)

    if tabRedGo[index] == nil and IsNull(tabRedGo[index]) then
        tabRedGo[index] = Util.GetGameObject(tab,"Redpot")
    end
end
function SupportPanel.OnTabIsLockCheck(index)
end
function SupportPanel.OnChangeTab(index, lastIndex)
    this.SetAutoLvUpValue()
end
function SupportPanel.ChangeTab(index)
    this.UpLevelPart:SetActive(false)
    this.SkillPart:SetActive(false)
    this.ModifyPart:SetActive(false)
    this.OverclockingPart:SetActive(false)
    if index == 1 then
        this.UpLevelPart:SetActive(true)
        SupportPanel.SetLevelUpUI()
    elseif index == 2 then
        this.SkillPart:SetActive(true)
        SupportPanel.SetSkillUI()
    elseif index == 3 then
        this.ModifyPart:SetActive(true)
        this.Reform:SetActive(true)
        this.RemouldPropertys:SetActive(false)
        SupportPanel.SetRemouldUI()
    elseif index == 4 then
        this.OverclockingPart:SetActive(true)
        SupportPanel.SetOverclockingUI()
    end
end

--设置升级
function SupportPanel.SetLevelUpUI()
    local supportDatas = SupportManager.GetSupportDatas()

    local curLvData = artifactLevelConfig[supportDatas.level]
    Util.GetGameObject(this.UpLevelPart, "HP/num"):GetComponent("Text").text = "+"..supportDatas.hp
    Util.GetGameObject(this.UpLevelPart, "ATK/num"):GetComponent("Text").text = "+"..supportDatas.att
    Util.GetGameObject(this.UpLevelPart, "ExpBar"):GetComponent("Slider").value = supportDatas.exp / curLvData.ExpFull
    Util.GetGameObject(this.UpLevelPart, "ExpBar/Fill Area/Text"):GetComponent("Text").text = supportDatas.exp .. "/" .. curLvData.ExpFull

    if curLvData.ConsumeItem == nil then
        -- max
        Util.GetGameObject(this.UpLevelPart, "ExpBar"):SetActive(false)
        Util.GetGameObject(this.UpLevelPart, "Max"):SetActive(true)
        Util.GetGameObject(this.UpLevelPart, "Cost1"):SetActive(false)
        Util.GetGameObject(this.UpLevelPart, "Cost2"):SetActive(false)
        Util.GetGameObject(this.UpLevelPart, "upLv"):SetActive(false)
        Util.GetGameObject(this.UpLevelPart, "autoUpLv"):SetActive(false)
    else
        Util.GetGameObject(this.UpLevelPart, "ExpBar"):SetActive(true)
        Util.GetGameObject(this.UpLevelPart, "Max"):SetActive(false)
        Util.GetGameObject(this.UpLevelPart, "Cost1"):SetActive(true)
        Util.GetGameObject(this.UpLevelPart, "Cost2"):SetActive(true)
        Util.GetGameObject(this.UpLevelPart, "upLv"):SetActive(true)

        for i = 1, 2 do
            local itemId = curLvData.ConsumeItem[i][1]
            local itemData = itemConfig[itemId]
            Util.GetGameObject(this.UpLevelPart, "Cost" .. i):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemData.Quantity))
            Util.GetGameObject(this.UpLevelPart, "Cost" .. i .. "/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))

            local str
            if BagManager.GetItemCountById(itemId) >= curLvData.ConsumeItem[i][2] then
                str = PrintWanNum4(BagManager.GetItemCountById(itemId)) .. "/" .. PrintWanNum4(curLvData.ConsumeItem[i][2])
            else
                str = string.format("<color=#ff6868>%s</color>",PrintWanNum4(BagManager.GetItemCountById(itemId))) .. "/" .. PrintWanNum4(curLvData.ConsumeItem[i][2])
            end
            Util.GetGameObject(this.UpLevelPart, "Cost" .. i .. "/Num"):GetComponent("Text").text = str
            ItemImageTips(itemId, Util.GetGameObject(this.UpLevelPart, "Cost" .. i .. "/icon"))
        end
    end
end

--设置技能
function SupportPanel.SetSkillUI()
    local artifactId = this.curArtifactData.sData.artifactid
    local artifactSkillLv = this.curArtifactData.sData.skillLevel
    local supportLv = SupportManager.GetDataById("level")

    --cur
    local configData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ArtifactSkillConfig, "ArtifactId", artifactId, "SkillLevel", artifactSkillLv)
    local skillData = skillConfig[configData.SkillId]
    local desc = GetSkillConfigDesc(skillData)

    --next
    local configDataNext = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ArtifactSkillConfig, "ArtifactId", artifactId, "SkillLevel", artifactSkillLv + 1)
    local skillDataNext = skillConfig[configDataNext.SkillId]
    local descNext = GetSkillConfigDesc(skillDataNext)

    local helpBtn = Util.GetGameObject(this.SkillPart, "helpBtn")
    local helpPosition = helpBtn:GetComponent("RectTransform").localPosition
    Util.AddOnceClick(helpBtn, function()
        local str = GetLanguageStrById(10094)
        if configData.PassiveSkillId and configData.PassiveSkillId ~= 0 then
            str = G_PassiveSkillConfig[configData.PassiveSkillId].Desc
        end
        UIManager.OpenPanel(UIName.HelpPopup, nil, helpPosition.x, helpPosition.y + 600, str)
    end)

    Util.GetGameObject(this.SkillPart, "curSkill/skillName"):GetComponent("Text").text = GetLanguageStrById(skillData.Name)
    Util.GetGameObject(this.SkillPart, "curSkill/skillDesc"):GetComponent("Text").text = desc
    Util.GetGameObject(this.SkillPart, "curSkill/skillLv"):GetComponent("Text").text = "Lv" .. artifactSkillLv
    Util.GetGameObject(this.SkillPart, "nextSkill/skillName"):GetComponent("Text").text = GetLanguageStrById(skillDataNext.Name)
    Util.GetGameObject(this.SkillPart, "nextSkill/skillDesc"):GetComponent("Text").text = descNext
    Util.GetGameObject(this.SkillPart, "nextSkill/skillLv"):GetComponent("Text").text = "Lv" .. artifactSkillLv + 1

    if not configData.ConsumeItem then
        --max
        Util.GetGameObject(this.SkillPart, "Cost1"):SetActive(false)
        Util.GetGameObject(this.SkillPart, "Cost2"):SetActive(false)
        Util.GetGameObject(this.SkillPart, "upLv"):SetActive(false)
        Util.GetGameObject(this.SkillPart, "nextSkill"):SetActive(false)
        Util.GetGameObject(this.SkillPart, "Max"):SetActive(true)
    else
        Util.GetGameObject(this.SkillPart, "Cost1"):SetActive(true)
        Util.GetGameObject(this.SkillPart, "Cost2"):SetActive(true)
        Util.GetGameObject(this.SkillPart, "upLv"):SetActive(true)
        Util.GetGameObject(this.SkillPart, "nextSkill"):SetActive(true)
        Util.GetGameObject(this.SkillPart, "Max"):SetActive(false)

        --升级所需道具
        for i = 1, 2 do
            local itemId = configData.ConsumeItem[i][1]
            local itemData = itemConfig[itemId]
            Util.GetGameObject(this.SkillPart, "Cost" .. i):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemData.Quantity))
            Util.GetGameObject(this.SkillPart, "Cost" .. i .. "/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
            -- Util.GetGameObject(this.SkillPart, "Cost" .. i .. "/Num"):GetComponent("Text").text = PrintWanNum4(BagManager.GetItemCountById(itemId)) .. "/" .. PrintWanNum4(configData.ConsumeItem[i][2])

            local str
            if BagManager.GetItemCountById(itemId) >= configData.ConsumeItem[i][2] then
                str = PrintWanNum4(BagManager.GetItemCountById(itemId)) .. "/" .. PrintWanNum4(configData.ConsumeItem[i][2])
            else
                str = string.format("<color=#ff6868>%s</color>",PrintWanNum4(BagManager.GetItemCountById(itemId))) .. "/" .. PrintWanNum4(configData.ConsumeItem[i][2])
            end
            Util.GetGameObject(this.SkillPart, "Cost" .. i .. "/Num"):GetComponent("Text").text = str

            ItemImageTips(itemId, Util.GetGameObject(this.SkillPart, "Cost" .. i .. "/icon"))
        end

        this.upLvBtn = Util.GetGameObject(this.SkillPart, "upLv")

        if supportLv >= configData.UnlockFactor then
            Util.GetGameObject(this.upLvBtn, "tip"):GetComponent("Text").text = ""
        else
            Util.GetGameObject(this.upLvBtn, "tip"):GetComponent("Text").text = string.format(GetLanguageStrById(50017),configData.UnlockFactor)
        end

        Util.AddOnceClick(this.upLvBtn, function()
            if supportLv >= configData.UnlockFactor then
                for i = 1, 2 do
                    local itemId = configData.ConsumeItem[i][1]
                    if BagManager.GetItemCountById(itemId) < configData.ConsumeItem[i][2] then
                        PopupTipPanel.ShowTipByLanguageId(10073)
                        return
                    end
                end
                local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
                NetManager.GetSupportSkillUp(artifactId, function(_msg)
                    if _msg.result and _msg.result ~= 0 then
                        SupportManager.UpdateSkillLv(artifactId)
                        SupportPanel.SetSkillUI()
                        RefreshPower(oldPower)
                        this.CheckRedPoint()
                    end
                    --CheckRedPointStatus(RedPointType.Support_SkillBtn)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10598)
                return
            end
        end)
    end
    this.CheckRedPoint()
end

--设置改造
function SupportPanel.SetRemouldUI()
    local refineLevel = SupportManager.GetDataById("refineLevel")
    local refineData = ConfigManager.GetConfigDataByKey(ConfigName.ArtifactRefineConfig, "RefineLevel", refineLevel)
    local nextRefineData = ConfigManager.TryGetConfigDataByKey(ConfigName.ArtifactRefineConfig, "RefineLevel", refineLevel + 1)
    local supportLv = SupportManager.GetDataById("level")

    --> all属性
    local allProData = SupportManager.GetRemouldPropertyAllValue(refineLevel)
    this.scrollView:SetData(allProData, function(index, root)
        SupportPanel.SetRemouldPro(root, allProData[index], SupportRemouldSysMap[index])
    end)
    this.scrollView:SetIndex(1)

    this.ModifyBtn = Util.GetGameObject(this.ModifyPart, "ModifyBtn")

    if nextRefineData == nil then
        this.ModifyBtn:SetActive(false)
        this.previewBtn:SetActive(false)
        this.Reform:SetActive(false)
        this.RemouldPropertys:SetActive(true)
        for i = 1, 2 do
            Util.GetGameObject(this.ModifyPart, "Cost" .. i):SetActive(false)
        end
    else
        -- this.ModifyBtn:SetActive(true)
        -- this.previewBtn:SetActive(true)

        local curAddPro = SupportManager.GetRemouldPropertyValue(refineLevel, nextRefineData.PropertyId)
        local curTxt = Util.GetGameObject(this.ModifyPart, "curDesc"):GetComponent("Text")
        local nextProData = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyId", nextRefineData.PropertyId)
        if nextProData.Style == 1 then               --< 绝对值
            curTxt.text = GetLanguageStrById(nextProData.Info) .. " +" .. GetPropertyFormatStr(1, curAddPro)
        elseif nextProData.Style == 2 then           --< 百分比
            curTxt.text = GetLanguageStrById(nextProData.Info) .. " +" .. GetPropertyFormatStr(2, curAddPro)
        end

        local nextTxt = Util.GetGameObject(this.ModifyPart, "nextDesc"):GetComponent("Text")
        if nextProData.Style == 1 then               --< 绝对值
            nextTxt.text = GetLanguageStrById(nextProData.Info) .. " +" .. GetPropertyFormatStr(1, curAddPro + nextRefineData.Value)
        elseif nextProData.Style == 2 then           --< 百分比
            nextTxt.text = GetLanguageStrById(nextProData.Info) .. " +" .. GetPropertyFormatStr(2, curAddPro + nextRefineData.Value)
        end

        Util.GetGameObject(this.ModifyPart, "curLv"):GetComponent("Text").text = GetLanguageStrById(22299) .. refineLevel
        Util.GetGameObject(this.ModifyPart, "nextLv"):GetComponent("Text").text = GetLanguageStrById(22299) .. (refineLevel+1)
        for i = 1, 2 do
            local itemId = refineData.ConsumeItem[i][1]
            local itemData = itemConfig[itemId]
            Util.GetGameObject(this.ModifyPart, "Cost" .. i):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemData.Quantity))
            Util.GetGameObject(this.ModifyPart, "Cost" .. i .. "/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
            -- Util.GetGameObject(this.ModifyPart, "Cost" .. i .. "/Num"):GetComponent("Text").text = PrintWanNum4(BagManager.GetItemCountById(itemId)) .. "/" .. PrintWanNum4(refineData.ConsumeItem[i][2])
            local str
            if BagManager.GetItemCountById(itemId) >= refineData.ConsumeItem[i][2] then
                str = PrintWanNum4(BagManager.GetItemCountById(itemId)) .. "/" .. PrintWanNum4(refineData.ConsumeItem[i][2])
            else
                str = string.format("<color=#ff6868>%s</color>",PrintWanNum4(BagManager.GetItemCountById(itemId))) .. "/" .. PrintWanNum4(refineData.ConsumeItem[i][2])
            end
            Util.GetGameObject(this.ModifyPart, "Cost" .. i .. "/Num"):GetComponent("Text").text = str

            ItemImageTips(itemId, Util.GetGameObject(this.ModifyPart, "Cost" .. i .. "/icon"))
        end
    end

    Util.AddOnceClick(this.ModifyBtn, function()
        if supportLv >= refineData.UnlockFactor then
            for i = 1, 2 do
                local itemId = refineData.ConsumeItem[i][1]
                if BagManager.GetItemCountById(itemId) < refineData.ConsumeItem[i][2] then
                    PopupTipPanel.ShowTipByLanguageId(10073)
                    return
                end
            end
            local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            NetManager.GetSupportRefineUp(function(_msg)
                if _msg.result and _msg.result ~= 0 then
                    local oldlv = SupportManager.GetDataById("refineLevel")
                    SupportManager.SetDataById("refineLevel", oldlv + 1)
                    SupportPanel.SetRemouldUI()
                    SupportPanel.CheckRedPoint()
                    RefreshPower(oldPower)
                end
                --CheckRedPointStatus(RedPointType.Support_RemouldBtn)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10598)
            return
        end
    end)
end

function SupportPanel.SetImproveUI()
end

function SupportPanel.SetRemouldPro(go, value, proId)
    local proData = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyId", proId)
    Util.GetGameObject(go, "proName"):GetComponent("Text").text =GetLanguageStrById(proData.Info)
    local txt = Util.GetGameObject(go, "proVale"):GetComponent("Text")
    if proData.Style == 1 then               --< 绝对值
        txt.text = "+"..GetPropertyFormatStr(1, value)
    elseif proData.Style == 2 then           --< 百分比
        txt.text = "+"..GetPropertyFormatStr(2, value)
    end

    Util.GetGameObject(go, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(proData.Icon))
end

--升级
function SupportPanel.LevelUp(type)
    if not SupportManager.CheckLevelUpIsEnough() then
        PopupTipPanel.ShowTipByLanguageId(10073)
        return
    end
    -- _levelFinish = false

    local oldLevel = SupportManager.GetSupportDatas().level
    local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
    NetManager.GetSupportLevelUp(type, function(msg)
        SupportManager.RefreshLevelData(msg)
        SupportPanel.SetLevelUpUI()
        -- _levelFinish = true

        -- if SupportManager.GetSupportDatas().level > oldLevel then
        --     _isAutoLevelUp = false
        -- end
        --CheckRedPointStatus(RedPointType.Support_LevelUpBtn)

        SupportPanel.CheckRedPoint()
        RefreshPower(oldPower)

        Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnPowerChange)
    end)
end

function SupportPanel.OnUpdate()
    -- if _isAutoLevelUp and Time.realtimeSinceStartup - _lastLevelUpTime > _autoLevelUpIntervalTime and _levelFinish then
    --     if not SupportManager.CheckLevelUpIsEnough() then
    --         _isAutoLevelUp = false
    --         return
    --     end
    --     _lastLevelUpTime = Time.realtimeSinceStartup
    --     SupportPanel.LevelUp()
    -- end
    
    -- if _isAutoLevelUp ==true then
    --     Util.GetGameObject(this.UpLevelPart, "autoUpLv/Text"):GetComponent("Text").text=GetLanguageStrById(50208)
    -- else
    --     Util.GetGameObject(this.UpLevelPart, "autoUpLv/Text"):GetComponent("Text").text=GetLanguageStrById(50336)
    -- end
end

--设置全部守护
function SupportPanel.SetAllSupportUI()
    for i = 1, 5 do
        local icon = Util.GetGameObject(this.AllSupport, "bg/Image" .. tostring(i).."/Icon")
        -- local imageTitle = Util.GetGameObject(this.AllSupport, "bg/Desc" .. tostring(i) .. "/Image")
        local TitleText = Util.GetGameObject(this.AllSupport, "bg/Image" .. tostring(i) .. "/TitleText")
        local lock = Util.GetGameObject(this.AllSupport, "bg/Image" .. tostring(i).."/Lock")
        icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(artifactConfig[i].Image))
        -- imageTitle:GetComponent("Image").sprite = Util.LoadSprite("N1_imgtxt_zhiyuan_mingcheng" .. tostring(i)) --< todo
        lock:SetActive(false)

        local artifactId = i
        local artifactSkillLv = SupportManager.GetSkillMaxLvById(artifactId)
        local configData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ArtifactSkillConfig, "ArtifactId", artifactId, "SkillLevel", artifactSkillLv)
        local skillData = skillConfig[configData.SkillId]
        local desc = GetSkillConfigDesc(skillData)
        TitleText:GetComponent("Text").text = desc
    end
end

--设置超频
function SupportPanel.SetOverclockingUI()
    -- this.SureBtnRedPoint = Util.GetGameObject(this.OverclockingPart, "SureBtn/Redpot")
    this.UsedTimes = Util.GetGameObject(this.OverclockingPart, "UsedTimes"):GetComponent("Text")

    this.usedTimes = SupportManager.GetDataById("soulNum")
    this.soulData = artifactSoulConfig[1]
    this.addProTimes = math.floor(this.usedTimes / this.soulData.Bout)
    this.supportLv = SupportManager.GetDataById("level")
    local artifactConfig = artifactLevelConfig[this.supportLv]
    this.upLimitTimes = artifactConfig.SoulLimit
    this.canUseTimesMax = this.upLimitTimes - this.usedTimes
    local materialTimes = BagManager.GetItemCountById(this.soulData.ConsumeItem[1]) / this.soulData.ConsumeItem[2]
    this.maxNum = math.min(this.canUseTimesMax, materialTimes)
    Util.GetGameObject(this.OverclockingPart, "Item"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[this.soulData.ConsumeItem[1]].Quantity))
    Util.GetGameObject(this.OverclockingPart, "Item/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[this.soulData.ConsumeItem[1]].ResourceID))
    ItemImageTips(this.soulData.ConsumeItem[1], Util.GetGameObject(this.gameObject, "Item/icon"))
    
    this.slider.enabled = this.maxNum > 1
    this.slider.maxValue = this.maxNum
    this.slider.minValue = 0
    this.slider.value = this.maxNum > 0 and 1 or 0
    this.count.text = this.slider.value
    local proid1 = this.soulData.PropertyAdd[1][1]
    local provalue1 = this.soulData.PropertyAdd[1][2]
    local proid2 = this.soulData.PropertyAdd[2][1]
    local provalue2 = this.soulData.PropertyAdd[2][2]
    provalue1 = provalue1 * this.addProTimes
    provalue2 = provalue2 * this.addProTimes
    Util.GetGameObject(this.OverclockingPart, "ATK/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(propertyConfig[proid1].Icon))
    Util.GetGameObject(this.OverclockingPart, "HP/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(propertyConfig[proid2].Icon))
    Util.GetGameObject(this.OverclockingPart, "ATK/name"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[proid1].Info)
    Util.GetGameObject(this.OverclockingPart, "HP/name"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[proid2].Info)
    Util.GetGameObject(this.OverclockingPart, "ATK/value"):GetComponent("Text").text = "+" .. GetPropertyFormatStr(propertyConfig[proid1].Style, provalue1)
    Util.GetGameObject(this.OverclockingPart, "HP/value"):GetComponent("Text").text =  "+" .. GetPropertyFormatStr(propertyConfig[proid2].Style, provalue2)
    this.UsedTimes.text = GetLanguageStrById(22710) .. "  ".. this.usedTimes .. "/" .. this.upLimitTimes
    -- this.SureBtnRedPoint:SetActive(SupportManager.CheckImproveIsEnough())
end

--红点
function SupportPanel.CheckRedPoint()
    local isRed1 = SupportManager.CheckLevelUpIsEnough()
    this.UpLevelBtnOnceRedPoint:SetActive(isRed1)
    this.UpLevelBtnAutoRedPoint:SetActive(isRed1)
    if tabRedGo[1] and not IsNull(tabRedGo[1]) then
        tabRedGo[1]:SetActive(isRed1)
    end

    local isRed2 = SupportManager.CheckSkillIsEnough(this.curArtifactData)
    this.upLvBtnRedPoint:SetActive(isRed2)
    if tabRedGo[2] and not IsNull(tabRedGo[2]) then
        tabRedGo[2]:SetActive(isRed2)
    end

    local isRed3 = SupportManager.CheckRemouldIsEnough()
    this.ModifyBtnRedPoint:SetActive(isRed3)
    if tabRedGo[3] and not IsNull(tabRedGo[3]) then
        tabRedGo[3]:SetActive(isRed3)
    end

    local isRed4 = SupportManager.CheckImproveIsEnough()
    this.ReinforceBtnRedPoint:SetActive(isRed4)
    if tabRedGo[4] and not IsNull(tabRedGo[4]) then
        tabRedGo[4]:SetActive(isRed4)
    end

    CheckRedPointStatus(RedPointType.Support)
end

--界面关闭时调用（用于子类重写）
function SupportPanel:OnClose()
    
    FixedUpdateBeat:Remove(this.OnUpdate, self)--长按方法注册
    -- if redPointList[1] and redPointList[2] and redPointList[3]  then
    --     ClearRedPointObject(RedPointType.Support_LevelUp, redPointList[1])
    --     ClearRedPointObject(RedPointType.Support_Skill, redPointList[2])
    --     ClearRedPointObject(RedPointType.Support_Remould, redPointList[3])
    -- end

    -- ClearRedPointObject(RedPointType.Support_LevelUpBtn,this.UpLevelBtnOnceRedPoint)
    -- ClearRedPointObject(RedPointType.Support_SkillBtn,this.upLvBtnRedPoint)
    -- ClearRedPointObject(RedPointType.Support_RemouldBtn,this.ModifyBtnRedPoint)
    tabRedGo = {}
end

--界面销毁时调用（用于子类重写）
function SupportPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    -- SubUIManager.Close(this.BtView)
    -- if this.playerHead then
    --     this.playerHead:Recycle()
    --     this.playerHead = nil
    -- end

    this.repeatItemViews = {}
    tabIsInit = false

    if this.live then
        poolManager:UnLoadLive(this.liveName, this.live)
    end
end

function SupportPanel:ShowGetNew(artifactId)
    --播放得到新守护特效
    local prefagName = "JiesuoUI_Shouhu"
    local gameObject = poolManager:LoadAsset(prefagName, PoolManager.AssetType.GameObject)
    gameObject.transform:SetParent(self.gameObject.transform)
    gameObject.transform.localPosition = Vector3.zero
    gameObject.transform.localScale = Vector3.one

    local back = Util.GetGameObject(gameObject, "back")
    local move = Util.GetGameObject(gameObject, "move")
    local effect = Util.GetGameObject(gameObject, "effect")
    local UI = Util.GetGameObject(gameObject, "UI")
    local Text = Util.GetGameObject(gameObject, "UI/UIback02/Text")
    local img = Util.GetGameObject(gameObject, "UI/UIback02"):GetComponent("Image")
    img.sprite = Util.LoadSprite(GetPictureFont("UI_Jiesuo_2d_003"))

    --设置sortingOrder
    back:GetComponent("Canvas").sortingOrder = self.sortingOrder + 1
    move:GetComponent("Canvas").sortingOrder = self.sortingOrder + 10
    Util.SetParticleSortLayer(effect, self.sortingOrder + 15)
    UI:GetComponent("Canvas").sortingOrder = self.sortingOrder + 20

    --设置内容

    --立绘
    local liveName = artifactConfig[artifactId].Image
    local live = poolManager:LoadLive(liveName, move.transform, Vector3.New(1.5, 1.5, 1), Vector3.New(0,0,0))
    local liveMaterial = poolManager:LoadAsset("cn2-X1_UIChouKa_mat_033", PoolManager.AssetType.Other)
    local liveMaterialOld = live:GetComponent("SkeletonGraphic").material
    live:GetComponent("SkeletonGraphic").material = liveMaterial

    --点击关闭
    local startTime = Time.time
    local isClick = false
    Util.AddOnceClick(back, function()
        if Time.time - startTime < 1.5 then --动画未播放完毕
            return
        end

        if isClick then --防止重复点击
            return
        end

        isClick = true

        --调用关闭动画,然后销毁特效
        local animator = gameObject:GetComponent("Animator")
        animator:SetBool("play",true)
        Timer.New(function()
            --换回原材质
            live:GetComponent("SkeletonGraphic").material = liveMaterialOld

            --材质释放
            poolManager:UnLoadAsset("cn2-X1_UIChouKa_mat_033", liveMaterial, PoolManager.AssetType.Other)

            --立绘释放
            if live then
                poolManager:UnLoadLive(liveName, live)
            end

            --守护特效释放
            poolManager:UnLoadAsset(prefagName, gameObject, PoolManager.AssetType.GameObject)
        end, 1):Start()
    end)
    --说明
    Text:GetComponent("Text").text = string.format(GetLanguageStrById(50011), GetLanguageStrById(artifactConfig[artifactId].Name))
end

return SupportPanel