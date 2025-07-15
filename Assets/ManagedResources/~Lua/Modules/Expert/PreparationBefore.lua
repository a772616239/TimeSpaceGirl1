local PreparationBefore = quick_class("PreparationBefore")
local this = PreparationBefore
local ThemeActivityTaskConfig = ConfigManager.GetConfig(ConfigName.ThemeActivityTaskConfig)
local itemsGrid = {}--item重复利用


function PreparationBefore:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function PreparationBefore:InitComponent(gameObject)
    this.rewardPre = Util.GetGameObject(gameObject, "rewardPre")
    this.rect = Util.GetGameObject(gameObject, "rect")
    local rootHight = this.rect.transform.rect.height
    local width = this.rect.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rect.transform,
            this.rewardPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 10))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function PreparationBefore:BindEvent()
end

--添加事件监听（用于子类重写）
function PreparationBefore:AddListener()
end

--移除事件监听（用于子类重写）
function PreparationBefore:RemoveListener()
end

--界面打开时调用（用于子类重写）
function PreparationBefore:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PreparationBefore:OnShow()
    PreparationBefore:OnShowData()
end
function PreparationBefore:OnSortingOrderChange()

end
function PreparationBefore:OnShowData()
    local allData = this.InitDynamicActData()
    this.ScrollView:SetData(allData, function (index, go)
        this.SingleDataShow(go, allData[index])
    end)
end
--刷新每一条的显示数据
function this.SingleDataShow(go, data)
    --绑定组件
    local titleImage = Util.GetGameObject(go, "titleImage/titleText"):GetComponent("Text")
    local content = Util.GetGameObject(go, "content")--data.reward
  
    local getFinishImage = Util.GetGameObject(go, "getFinishImage")
    local getRewardProgress = Util.GetGameObject(go, "getRewardProgress")
    local getRewardProgressText = Util.GetGameObject(go, "getRewardProgress/Txt")

    local lingquBtn = Util.GetGameObject(go, "lingquButton")
    local qianwangBtn = Util.GetGameObject(go, "qianwangButton")
  
    if itemsGrid[go] then
        itemsGrid[go]:OnOpen(false, data.reward, 1,false,false,false)
        itemsGrid[go].gameObject:SetActive(true)
    else

        itemsGrid[go] = SubUIManager.Open(SubUIConfig.ItemView, content.transform)
        itemsGrid[go].gameObject:SetActive(true)
        itemsGrid[go]:OnOpen(false, data.reward, 1,false,false,false)

    end

    titleImage.text = data.content
    getRewardProgress:GetComponent("Slider").value = data.progress/data.value
    getRewardProgressText:GetComponent("Text").text = data.progress.."/"..data.value

    --0-未完成，1-完成未领取  2-已领取
    local state = data.state
    
    getFinishImage:SetActive(state == 2)
    lingquBtn:SetActive(state == 1)
    qianwangBtn:SetActive(state == 0)
    getRewardProgress:SetActive(state ~= 2)

    Util.AddOnceClick(lingquBtn, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.PreparationBefore,data.id, function(msg)    
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function ()
                PreparationBefore:OnShowData()
            end)
        end)
    end)
    Util.AddOnceClick(qianwangBtn, function()
        --跳转任务
        JumpManager.GoJump(data.jump)
    end)
end

--界面关闭时调用（用于子类重写）
function PreparationBefore:OnClose()

end

--界面销毁时调用（用于子类重写）
function PreparationBefore:OnDestroy()

end

function this.InitDynamicActData()
    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.PreparationBefore)

    if (not id) or id < 1 then
        return nil
    end    
    this.allData = {}
    local allListData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ThemeActivityTaskConfig, "ActivityId", id)
    local allMissionData = TaskManager.GetTypeTaskList(TaskTypeDef.PreparationBefore)--TODO定义任务类型
    for i = 1,#allListData do 
        for j = 1,#allMissionData do 
            if allListData[i].Id == allMissionData[j].missionId  then
                local data = {}
                data.id = allMissionData[j].missionId
                data.progress = allMissionData[j].progress 
                local strs = string.split(GetLanguageStrById(allListData[i].Show),"#")
                data.title = strs[1]
                data.content = strs[2]
                data.value = allListData[i].TaskValue[2][1]
                data.state = allMissionData[j].state
                data.type = allListData[i].Type               
                data.reward = {allListData[i].Integral[1][1],allListData[i].Integral[1][2]} 
                data.jump = allListData[i].Jump[1]
                table.insert(this.allData,data)
            end
        end
    end

    table.sort(this.allData,function (a,b)
        if a.state == b.state then
            return a.progress > b.progress
        else
            -- if a.state==2 or b.state==2 then
            --     return false
            -- end
            return a.state > b.state
        end
    end)
    return this.allData
end

return PreparationBefore