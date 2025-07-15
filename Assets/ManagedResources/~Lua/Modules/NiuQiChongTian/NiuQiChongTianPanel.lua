require("Base/BasePanel")
NiuQiChongTianPanel = Inherit(BasePanel)
local artConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local sortingOrder = 0

local TabBox = require("Modules/Common/TabBox")
local _TabData = {[1] = { name = GetLanguageStrById(50315) ,rpType = RedPointType.NiuQiChongTian_1},
                [2] = {name = GetLanguageStrById(50316) ,rpType = RedPointType.NiuQiChongTian_2},
                [3] = {name = GetLanguageStrById(50317) ,rpType = RedPointType.NiuQiChongTian_3},}

--初始化组件（用于子类重写）
function NiuQiChongTianPanel:InitComponent()
    self.progressData = {}
    self.rewardData = {}
    self.curScore = 0
    self.itemsGrid = {}--item重复利用
    self.curPage = 1
    self.curIndex = 1
    self.redPointList = {}

    self.mid = Util.GetGameObject(self.gameObject, "mid")
    self.backBtn = Util.GetGameObject(self.gameObject,"backBtn")
    self.tabBox = Util.GetGameObject(self.mid , "TabBox")

    --进度条
    self.reward = Util.GetGameObject(self.mid, "reward")
    self.progress = Util.GetGameObject(self.mid, "progress/value"):GetComponent("Image")

    --任务列表
    self.itemPre = Util.GetGameObject(self.gameObject, "rewardPre")
    self.scrollItem = Util.GetGameObject(self.mid, "rewardArena")
    local rootHight = self.scrollItem.transform.rect.height
    local width = self.scrollItem.transform.rect.width
    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scrollItem.transform,self.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0,0))
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 2

    self.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    self.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)
end

--绑定事件（用于子类重写）
function NiuQiChongTianPanel:BindEvent()
    Util.AddClick(self.backBtn,function ()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function NiuQiChongTianPanel:AddListener()
end

--移除事件监听（用于子类重写）
function NiuQiChongTianPanel:RemoveListener()
end

function NiuQiChongTianPanel:OnSortingOrderChange()   
end

--界面打开时调用（用于子类重写）
function NiuQiChongTianPanel:OnOpen(_activityConfig)
    self.actConfig = _activityConfig   
end

-- 打开，重新打开时回调
function NiuQiChongTianPanel:OnShow()
    self.gameObject:SetActive(true)
    self.activityId = self.actConfig.ActId
    self.actType = self.actConfig.ActiveType > 0 and self.actConfig.ActiveType or self.actConfig.FunType
    if self.actConfig.IfBack == 1 then
        if self.actConfig.ActiveType > 0 then
            local id = ActivityGiftManager.IsActivityTypeOpen(self.actConfig.ActiveType)
            if id and id > 0 then
                self.activityId = id
                local config = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.ActivityGroups,"PageType",self.actConfig.PageType,"ActiveType",self.actConfig.ActiveType,"ActId",id)
                if config then
                    self.actConfig = config
                end
            end
        end
    end

    local NiuQiChongTianPanelTabAdapter = function(tab, index, status)
        local default = Util.GetGameObject(tab, "default")
        local select = Util.GetGameObject(tab, "select")
        local redPoint = Util.GetGameObject(tab, "Redpoint")
        if _TabData[index].rpType > 0 then
            if self.redPointList[_TabData[index].rpType] then
                ClearRedPointObject(_TabData[index].rpType, self.redPointList[_TabData[index].rpType])
            end
            BindRedPointObject(_TabData[index].rpType,redPoint)
            self.redPointList[_TabData[index].rpType] = redPoint
        end
        default:GetComponent("Text").text = _TabData[index].name
        select:GetComponent("Text").text = _TabData[index].name
        default:SetActive(status == "default")
        select:SetActive(status == "select")
        Util.GetGameObject(tab, "bg"):SetActive(status == "select")
    end

    local NiuQiChongTianPanelSwitchView = function(index,bool)
        self.curPage = index
        self.rewardData = NiuQiChongTianManager.GetNeedRewardData(self.curPage)

        self:SetProgress()
        self:SetReward(bool)
    end

    self.TabCtrl = TabBox.New()
    self.TabCtrl:SetTabAdapter(NiuQiChongTianPanelTabAdapter)
    self.TabCtrl:SetChangeTabCallBack(NiuQiChongTianPanelSwitchView)
    self.TabCtrl:Init(self.tabBox, _TabData, self.curIndex)

    self.HeadFrameView:OnShow(true)
    self.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
    self:SetTime()
    self:CheckRedPoint()

end

function  NiuQiChongTianPanel:SwitchView(index,bool)
    self.curPage = index
    self.rewardData = NiuQiChongTianManager.GetNeedRewardData(self.curPage)

    self:SetProgress()
    self:SetReward(bool)
end

function NiuQiChongTianPanel:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    local info = ActivityGiftManager.GetActivityTypeInfo(self.actType)
    local tempTime = info.endTime - GetTimeStamp()
    if tempTime < 0 then
        return
    end
    local updateTime = function()
        if tempTime <= 0 then
            self.parent:ClosePanel()
        end
    end
    updateTime()
    self.timer = Timer.New(function()
        tempTime = tempTime - 1
        updateTime()
    end,1,-1,false)
    self.timer:Start()
end

function NiuQiChongTianPanel:SetProgress()
    self.curScore = NiuQiChongTianManager.GetScore()
    self.progressData = NiuQiChongTianManager.configData
    self.progress.fillAmount = self.curScore/self.progressData[#self.progressData].value[2][1]
    for i = 1, self.reward.transform.childCount do
        local item = self.reward.transform:GetChild(i-1)
        item:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[self.progressData[i].reward[1][1]].Quantity))
        Util.GetGameObject(item, "Text"):GetComponent("Text").text = self.progressData[i].reward[1][2]
        Util.GetGameObject(item, "Text_Num"):GetComponent("Text").text = self.progressData[i].value[2][1]
        Util.GetGameObject(item, "icon"):GetComponent("Image").sprite = Util.LoadSprite(artConfig[itemConfig[self.progressData[i].reward[1][1]].ResourceID].Name)
        Util.GetGameObject(item, "Redpoint"):SetActive(self.progressData[i].state == 1)
        local btn = Util.GetGameObject(item, "icon")
        Util.AddOnceClick(btn,function ()
            if self.progressData[i].state == 1 then
                NetManager.GetActivityRewardRequest(self.progressData[i].missionId,self.activityId,function (drop)
                    UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1,function ()
                        self.progressData[i].state = 2
                        self:SetProgress()
                        CheckRedPointStatus(RedPointType.NiuQiChongTian_4)
                    end)
                end)
            elseif self.progressData[i].state == 0 then
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,self.progressData[i].reward[1][1],nil)
            else
                PopupTipPanel.ShowTipByLanguageId(10350)
            end
        end)
    end
end

local stateSort = {
    [0] = 1,
    [1] = 0,
    [2] = 2
}

function NiuQiChongTianPanel:SetReward(bool)
    local anim = bool or false

    table.sort(self.rewardData, function(a, b)
        if stateSort[a.state] == stateSort[b.state] then
            if a.SortI == b.SortI then
                return a.id < b.id
            end
            return a.SortI < b.SortI
            -- return false
        elseif stateSort[a.state] < stateSort[b.state] then
            return true
        end
    end)
    self.rewardData[#self.rewardData + 1] = {}
    self.ScrollView:SetData(self.rewardData, function (index, go)
        if index == #self.rewardData then
            go:SetActive(false)
            return
        end
        go:SetActive(true)
        self:SingleDataShow(go,index, self.rewardData[index])
    end,false,anim)
end

function NiuQiChongTianPanel:SingleDataShow(go, index, data)
    local title = Util.GetGameObject(go, "titleText"):GetComponent("Text")
    local goBtn = Util.GetGameObject(go, "goBtn")
    local getBtn = Util.GetGameObject(go, "getBtn")
    local received = Util.GetGameObject(go,"received")
    local grid = Util.GetGameObject(go, "rewardList")
    local shows = data.Reward
    title.text = GetLanguageStrById(data.Text)

    goBtn:SetActive(data.state == 0)
    getBtn:SetActive(data.state == 1)
    received:SetActive(data.state == 2)

    --滚动条复用重设itemview
    if self.itemsGrid[go] then
        for i = 1, 4 do
            self.itemsGrid[go][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            if self.itemsGrid[go][i] then
                self.itemsGrid[go][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.7,false,false,false,sortingOrder)
                self.itemsGrid[go][i].gameObject:SetActive(true)
            end
        end
    else
        self.itemsGrid[go] = {}
        for i = 1, 4 do
            self.itemsGrid[go][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            self.itemsGrid[go][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            self.itemsGrid[go][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.7,false,false,false,sortingOrder)
            self.itemsGrid[go][i].gameObject:SetActive(true)
        end
    end

    Util.AddOnceClick(goBtn,function ()
        UIManager.OpenPanel(UIName.RecruitPanel)
    end)

    Util.AddOnceClick(getBtn,function ()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.NiuQiChongTian,data.id,function (msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
                CheckRedPointStatus(RedPointType.NiuQiChongTian + self.curPage)
                CheckRedPointStatus(RedPointType.NiuQiChongTian_4)
                self:SwitchView(self.curPage,true)
            end)
        end)
    end)
end

--界面关闭时调用（用于子类重写）
function NiuQiChongTianPanel:OnClose()
    self.gameObject:SetActive(false)
    for key, value in pairs(self.redPointList) do
        ClearRedPointObject(key, value)
    end
    self.redPointList = {}
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function NiuQiChongTianPanel:OnDestroy()
    for k,v in pairs(self.itemsGrid) do
        for i = 1,#v do
            SubUIManager.Close(v[i])
        end
    end
    self.itemsGrid = {}
    SubUIManager.Close(self.HeadFrameView)
end

function NiuQiChongTianPanel:CheckRedPoint()
    CheckRedPointStatus(RedPointType.NiuQiChongTian + self.curPage)
    CheckRedPointStatus(RedPointType.NiuQiChongTian_4)
    RedpotManager.RefreshRedObjectStatus(RedPointType.NiuQiChongTian + self.curPage)
    RedpotManager.RefreshRedObjectStatus(RedPointType.NiuQiChongTian_4)
end

return NiuQiChongTianPanel