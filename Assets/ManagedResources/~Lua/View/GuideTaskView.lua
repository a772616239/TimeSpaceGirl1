local GuideTaskView = {}
local curGuideTaskData
local guideTaskConfig = ConfigManager.GetConfig(ConfigName.GuideTaskConfig)
local curGuideTaskConfig
local itemRewardList = {}
function GuideTaskView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = GuideTaskView })
    return b
end

--初始化组件（用于子类重写）
function GuideTaskView:InitComponent()
    self.button = Util.GetGameObject(self.transform,"button")
    self.Image_CanGet = Util.GetGameObject(self.button,"Image_CanGet")
    self.RewardContent = Util.GetGameObject(self.transform,"RewardContent")
    self.Slider = Util.GetGameObject(self.transform,"Slider")
    self.Text_Progress = Util.GetGameObject(self.Slider,"Text_Progress"):GetComponent("Text")
    self.Text_Content = Util.GetGameObject(self.button,"Text_Content"):GetComponent("Text")
    self.buuttonDone = Util.GetGameObject(self.transform,"ButtonDone")
    self.effect = Util.GetGameObject(self.button,"back1")

    self.guideFinger = Util.GetGameObject(self.button,"tipButtom")
end

--绑定事件（用于子类重写）
function GuideTaskView:BindEvent()
   Util.AddClick(self.button,function ()
        if curGuideTaskData.state == 0 then
            if curGuideTaskConfig.Jump[1] then
                JumpManager.GoJump(curGuideTaskConfig.Jump[1])
            end
        elseif curGuideTaskData.state == 1 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.GuideTask,curGuideTaskData.missionId, function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                end)
                TaskManager.SetMissionIdState(TaskTypeDef.GuideTask,curGuideTaskData.missionId,2)
                TaskManager.OnTriggerGuideTaskGuide(TaskTypeDef.GuideTask)
            end)
        end
        if self.guideFinger.activeSelf then
            self.guideFinger:SetActive(false)
        end
   end)
   Util.AddClick(self.buuttonDone,function ()   
        NetManager.TakeMissionRewardRequest(TaskTypeDef.GuideTask,curGuideTaskData.missionId, function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
            end)
            TaskManager.SetMissionIdState(TaskTypeDef.GuideTask,curGuideTaskData.missionId,2)
            TaskManager.OnTriggerGuideTaskGuide(TaskTypeDef.GuideTask)
        end)
        if self.guideFinger.activeSelf then
            self.guideFinger:SetActive(false)
        end
    end)

    BindRedPointObject(RedPointType.MainCity, self.Image_CanGet)
end

--添加事件监听（用于子类重写）
function GuideTaskView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, self.ShowCurrentGuideTask,self)
end

--移除事件监听（用于子类重写）
function GuideTaskView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, self.ShowCurrentGuideTask,self)
end

--界面打开时调用（用于子类重写）
function GuideTaskView:OnOpen(sortingOrder,btn,btn2)
    self.sortingOrder = sortingOrder
    self.changeBtn = btn
    self.changeBtn2 = btn2
    self.changeBtnPos = self.changeBtn.localPosition
    self.changeBtnPos2 = self.changeBtn2.localPosition
    self:ShowCurrentGuideTask()
end

-- 刷新聊天显示
function GuideTaskView:RefreshChatShow()
end

--界面关闭时调用（用于子类重写）
function GuideTaskView:OnClose()
end

function GuideTaskView:OnDestroy()
     itemRewardList = {}
end

function GuideTaskView: RefreshAgainRequest()
    curGuideTaskData = TaskManager.GetCurrentGuideTask(TaskTypeDef.GuideTask)
    if curGuideTaskData == nil then
        self.transform.gameObject:SetActive(false)
        return
    end

    --防止数据不同步，重新请求服务器的任务进度
    NetManager.RequestGuideTaskDataRefresh(function()
        self:ShowCurrentGuideTaskUI()
    end)
end

function GuideTaskView: ShowCurrentGuideTask()
    curGuideTaskData = TaskManager.GetCurrentGuideTask(TaskTypeDef.GuideTask)
    if curGuideTaskData == nil then
        self.transform.gameObject:SetActive(false)
        return
    end

    self:ShowCurrentGuideTaskUI()
end

function GuideTaskView:ShowCurrentGuideTaskUI()
    self.changeBtn.localPosition = self.changeBtnPos + Vector3(0,135)
    self.changeBtn2.localPosition = self.changeBtnPos2 + Vector3(0,135)
    curGuideTaskConfig = guideTaskConfig[curGuideTaskData.missionId]
    self.Image_CanGet:SetActive(curGuideTaskData.state == 1)
    CheckRedPointStatus(RedPointType.MainCity)
    self.effect:SetActive(curGuideTaskData.state == 1)
    self.Text_Content.text = GetLanguageStrById(curGuideTaskConfig.ContentsShow)
    self.Text_Progress.text = string.format("%s/%s",curGuideTaskData.progress,curGuideTaskConfig.Values[2][1]) 
    self.Slider:GetComponent("Slider").value = curGuideTaskData.progress/curGuideTaskConfig.Values[2][1]
    self.buuttonDone:SetActive(curGuideTaskData.state == 1)
    local go = self.transform.gameObject

    if itemRewardList[go] == nil then
        itemRewardList[go] = {}
        for i = 1, 2 do
            itemRewardList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, self.RewardContent.transform)
            itemRewardList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #curGuideTaskConfig.Reward do
            itemRewardList[go][i].gameObject:SetActive(true)
            itemRewardList[go][i]:OnOpen(false, {curGuideTaskConfig.Reward[i][1],curGuideTaskConfig.Reward[i][2]}, 0.55,false,false,false,self.sortingOrder)            
        end
    else
        for i = 1, #curGuideTaskConfig.Reward do
            itemRewardList[go][i].gameObject:SetActive(true)
            itemRewardList[go][i]:OnOpen(false, {curGuideTaskConfig.Reward[i][1],curGuideTaskConfig.Reward[i][2]}, 0.55,false,false,false,self.sortingOrder)
        end
    end
end

return GuideTaskView