require("Base/BasePanel")
AchievementPanel = Inherit(BasePanel)
local this = AchievementPanel
local redPointGrid = {}--红点
local imageSprite = {
    {"c_chengjiu_jiaoseanniu_1", "c_chengjiu_jiaoseanniu"},
    {"c_chengjiu_wanfaanniu_1", "c_chengjiu_wanfaanniu"},
    {"c_chengjiu_fubenanniu_1", "c_chengjiu_fubenanniu"},
    {"c_chengjiu_teshuanniu_1", "c_chengjiu_teshuanniu"},
    {"c_chengjiu_wanfaanniu_1", "c_chengjiu_wanfaanniu"}
}
local tabBtns = {}
local defaultIndex = 0
local curAllData = {}
local achievementConfig = ConfigManager.GetConfig(ConfigName.AchievementConfig)
this.UpView = nil
--初始化组件（用于子类重写）
function AchievementPanel:InitComponent()
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    self.btnBack = Util.GetGameObject(self.gameObject, "tabs/btnBack")
    self.selectBtn = Util.GetGameObject(self.gameObject, "tabs/rect/grid/selectBtn")
    for i = 1, LengthOfTable(imageSprite) do
        tabBtns[i] = Util.GetGameObject(self.gameObject, "tabs/rect/grid/Btn (" .. i .. ")")
        tabBtns[i]:GetComponent("Image").sprite = Util.LoadSprite(imageSprite[i][1])
        redPointGrid[i] = Util.GetGameObject(tabBtns[i], "redPoint")
        redPointGrid[i]:SetActive(false)
    end
    this.rewardPre = Util.GetGameObject(self.gameObject, "downLayout/AchievementGrid/rewardPre")
    local v = Util.GetGameObject(self.gameObject, "downLayout/AchievementGrid/rect"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "downLayout/AchievementGrid/rect").transform,
            this.rewardPre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,15))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    self.NoviceItemList={}--存储itemview 重复利用
end

--绑定事件（用于子类重写）
function AchievementPanel:BindEvent()
    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
    for i = 1, LengthOfTable(imageSprite) do
        Util.AddClick(tabBtns[i], function()
            self:OnShowPanelData(i)
        end)
    end
    --BindRedPointObject(RedPointType.Achievement_One, redPointGrid[1])
    --BindRedPointObject(RedPointType.Achievement_Two, redPointGrid[2])
    --BindRedPointObject(RedPointType.Achievement_Three, redPointGrid[3])
    --BindRedPointObject(RedPointType.Achievement_Four, redPointGrid[4])
    --BindRedPointObject(RedPointType.Achievement_Five, redPointGrid[5])
end

--添加事件监听（用于子类重写）
function AchievementPanel:AddListener()
    --Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose, self.RefreshActivityBtn, self)
end

--移除事件监听（用于子类重写）
function AchievementPanel:RemoveListener()
    --Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose, self.RefreshActivityBtn, self)
end

--界面打开时调用（用于子类重写）
function AchievementPanel:OnOpen(_defaultIndex)
    defaultIndex = _defaultIndex or 0
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AchievementPanel:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    if defaultIndex <= 0 then
        defaultIndex = 1
        defaultIndex = self:GetPriorityIndex(defaultIndex)
    end
    self:OnShowPanelData(defaultIndex)
    self:SetSelectBtn(defaultIndex)
end
function AchievementPanel:OnSortingOrderChange()
    for i, v in pairs(self.NoviceItemList) do
        for j = 1, #self.NoviceItemList[i] do
            self.NoviceItemList[i][j]:SetEffectLayer(self.sortingOrder)
        end
    end
end
function AchievementPanel:OnShowPanelData(_defaultIndex)
    defaultIndex = _defaultIndex
    local AllData = TaskManager.GetTypeTaskList(TaskTypeDef.Achievement)
    
    curAllData = {}
    for i = 1, #AllData do
        if AllData[i] and achievementConfig[AllData[i].missionId] then
            if achievementConfig[AllData[i].missionId].Sort == defaultIndex then
                --LogError("defaultIndex                         "..defaultIndex.."      AllData[i].missionId    "..AllData[i].missionId..
                --        "      AllData[i].state      "..AllData[i].state.."     AllData[i].progress       "..AllData[i].progress)
                table.insert(curAllData,AllData[i])
            end
        end
    end
    self:RewardTabsSort(curAllData)
    this.ScrollView:SetData(curAllData, function (index, go)
        self:SingleDataShow(go, curAllData[index])
    end)
    self:SetSelectBtn(defaultIndex)
end

function AchievementPanel:SingleDataShow(go,rewardData)
    local activityRewardGo = go
    activityRewardGo:SetActive(true)
    local sConFigData = achievementConfig[rewardData.missionId]
    local titleText = Util.GetGameObject(activityRewardGo, "titleImage/titleText"):GetComponent("Text")
    titleText.text = GetLanguageStrById(sConFigData.ContentsShow)
    local itemGroup = Util.GetGameObject(activityRewardGo, "content")
    --滚动条复用重设itemview
    if self.NoviceItemList[go] then
        for i = 1, 4 do
            self.NoviceItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #sConFigData.Reward do
            if self.NoviceItemList[go][i] then
                self.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.9,false,false,false,self.sortingOrder)
                self.NoviceItemList[go][i].gameObject:SetActive(true)
            end
        end
    else
        self.NoviceItemList[go]={}
        for i = 1, 4 do
            self.NoviceItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
            self.NoviceItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #sConFigData.Reward do
            self.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.9,false,false,false,self.sortingOrder)
            self.NoviceItemList[go][i].gameObject:SetActive(true)
        end
    end
    local lingquButton = Util.GetGameObject(activityRewardGo.gameObject, "lingquButton")
    Util.GetGameObject(lingquButton.gameObject, "redPoint"):SetActive(false)
    local qianwangButton = Util.GetGameObject(activityRewardGo.gameObject, "qianwangButton")
    local getFinishText = Util.GetGameObject(activityRewardGo.gameObject, "getFinishText")
    local getRewardProgress = Util.GetGameObject(activityRewardGo.gameObject, "getRewardProgress")
    local state = rewardData.state
    local value = sConFigData.Values[2][1]
    lingquButton:SetActive(state == 1)
    qianwangButton:SetActive(state == 0)
    getFinishText:SetActive(state == 2)
    getRewardProgress:SetActive(state == 0)
    getRewardProgress:GetComponent("Text").text = math.abs(rewardData.progress) .."/"..math.abs(value)
    Util.AddOnceClick(qianwangButton, function()
        if sConFigData.Jump then
            JumpManager.GoJump(sConFigData.Jump[1])
        end
    end)
    Util.AddOnceClick(lingquButton, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.Achievement,rewardData.missionId,  function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                self:OnShowPanelData(defaultIndex)
            end)
        end)
    end)
end

local sortTable = {
    [1] = 2,
    [2] = 0,
    [0] = 1,
}
function AchievementPanel:RewardTabsSort(missions)
    table.sort(missions,function(a,b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return sortTable[a.state] > sortTable[b.state]
        end
    end)
end

function AchievementPanel:SetSelectBtn(index)
    self.selectBtn.transform:SetParent(tabBtns[index].transform)
    self.selectBtn.transform.localScale = Vector3.one
    self.selectBtn.transform.localPosition = Vector3.zero;
    self.selectBtn:GetComponent("Image").sprite = Util.LoadSprite(imageSprite[index][2])
end

function AchievementPanel:GetPriorityIndex(defaultIndex)
    local index = defaultIndex
    for idx, operateItem in ipairs(tabBtns) do
        if operateItem.activeSelf and Util.GetGameObject(operateItem, "redPoint").activeSelf then
            index = idx
            break
        end
    end
    return index
end

--界面关闭时调用（用于子类重写）
function AchievementPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function AchievementPanel:OnDestroy()
    --ClearRedPointObject(RedPointType.Achievement_One)
    --ClearRedPointObject(RedPointType.Achievement_Two)
    --ClearRedPointObject(RedPointType.Achievement_Three)
    --ClearRedPointObject(RedPointType.Achievement_Four)
    --ClearRedPointObject(RedPointType.Achievement_Five)
    SubUIManager.Close(this.UpView)
end

return AchievementPanel