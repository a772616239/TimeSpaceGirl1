require("Base/BasePanel")
local ArenaTypePanel = Inherit(BasePanel)
local this = ArenaTypePanel
local TabBox = require("Modules/Common/TabBox")
local _TabData = { [1] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", 
                    select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", 
                    name = GetLanguageStrById(12571),
                    title = "" },
                    [2] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
                    select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", 
                    name = GetLanguageStrById(12572)}, 
                    title = "" }
this.contents = {
    [1] = {view = require("Modules/Arena/View/ArenaTypePanel_Arena"), panelName = "ArenaTypePanel_Arena"},
    [2] = {view = require("Modules/Arena/View/ArenaTypePanel_TopMatch"), panelName = "ArenaTypePanel_TopMatch"},
}                       
local curIndex = 1    
                 
--初始化组件（用于子类重写）
function ArenaTypePanel:InitComponent()
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    --this.btnArenaRedpot = Util.GetGameObject(this.btnArena, "bg/redpot") --TODO红点提示

    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft})
    -- this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    
    --预设赋值
    this.prefabs = {}
    for i = 1,#this.contents do
        this.prefabs[i] = Util.GetGameObject(self.gameObject,this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, "content"))
    end
end

--绑定事件（用于子类重写）
function ArenaTypePanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        --PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    --BindRedPointObject(RedPointType.Arena_Type_Normal, this.btnArenaRedpot)

    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function ArenaTypePanel:AddListener()
    -------------------------------
     --Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshTopMatchShow)
     Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionOpen, this.OnOpen, this)
     Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionClose, this.OnOpen, this)
    ------------------------------------
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function ArenaTypePanel:RemoveListener()
    ---------------------------------
    -- Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshTopMatchShow)
     Game.GlobalEvent:RemoveEvent(GameEvent.FunctionCtrl.OnFunctionOpen, this.OnOpen, this)
     Game.GlobalEvent:RemoveEvent(GameEvent.FunctionCtrl.OnFunctionClose, this.OnOpen, this)
    -------------------------------
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end


--界面打开时调用（用于子类重写）
function ArenaTypePanel:OnOpen(_curIndex)
    curIndex = _curIndex and _curIndex or 1
    -- SoundManager.PlayMusic(SoundConfig.BGM_Arena)
    FormationManager.GetFormationByID(FormationTypeDef.ARENA_TOM_MATCH)

end
-- 打开，重新打开时回调
function ArenaTypePanel:OnShow()
    CheckRedPointStatus(RedPointType.Championships_Rank)
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)
    -- this.BtView:OnOpen({sortOrder = self.sortingOrder,panelType = PanelTypeView.MainCity})
end
-- 层级变化时，子界面层级刷新
function ArenaTypePanel:OnSortingOrderChange()
    if this.shopView then
        this.shopView:SetSortLayer(self.sortingOrder)
    end
    -- this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
end
-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab, "default")
    local select = Util.GetGameObject(tab, "select")
    Util.GetGameObject(tab,"bg"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    local title = Util.GetGameObject(tab,"title")
    -- title:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].title)
    default:GetComponent("Text").text = _TabData[index].name
    select:GetComponent("Text").text = _TabData[index].name
    default:SetActive(status == "default")
    select:SetActive(status == "select")
    title:SetActive(status == "select")

    if index == 2 then
        BindRedPointObject(RedPointType.Championships, Util.GetGameObject(tab, "Redpot"))
    end
end
--切换视图
function this.SwitchView(index)
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, curIndex = curIndex, index
    for i = 1, #this.contents do
        if oldSelect ~= 0 then this.contents[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    this.PlayerHeadFrameView:OnShow()
    --区分显示
    if index == 1 then
        this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    elseif index == 2 then
        this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    elseif index == 3 then
        this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    end
    --this.RefreshHelpBtn()
    --执行子模块初始化
    this.contents[index].view:OnShow(this)
end

-- 刷新竞技场显示
function this.RefreshArenaShow()
    this.Arena_Name.text = ArenaManager.GetArenaName()
    local baseData = ArenaManager.GetArenaBaseData()
    this.Arena_Score.text = baseData.score
    local _, myRankInfo = ArenaManager.GetRankInfo()
    local myRank = myRankInfo.personInfo.rank
    if myRank < 0 then
        myRank = GetLanguageStrById(10041)
    end
    this.Arena_Rank.text = myRank

    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.ARENA)
    local startDate = os.date("%m.%d", serData.startTime)
    local endDate = os.date("%m.%d", serData.endTime)
    this.Arena_Season.text = string.format("%s-%s", startDate, endDate)
end

-- 刷新巅峰战显示
function this.RefreshTopMatchShow()
    local tmData = ArenaTopMatchManager.GetBaseData()
    local titleName, stageName = ArenaTopMatchManager.GetCurTopMatchName()
    this.TopMatch_Name.text = titleName
    this.TopMatch_Stage.text = stageName
    this.TopMatch_Rank.text = tmData.myrank <= 0 and GetLanguageStrById(10041) or ArenaTopMatchManager.GetRankNameByRank(tmData.myrank)
    this.TopMatch_BestRank.text = tmData.maxRank <= 0 and GetLanguageStrById(10094) or this.GetRankName(tmData.maxRank)

    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.TOP_MATCH)
    local startDate = os.date("%m.%d", serData.startTime)
    local endDate = os.date("%m.%d", serData.endTime)
    this.TopMatch_Season.text = string.format("%s-%s", startDate, endDate)
end

-- 获取我得排名信息
function this.GetRankName(rank)
    if rank == 1 then
        return GetLanguageStrById(10095)
    elseif rank == 2 then
        return GetLanguageStrById(10096)
    else
        local maxTurn = ArenaTopMatchManager.GetEliminationMaxRound()
        for i = 1, maxTurn do
            if i == maxTurn then
                local config = ConfigManager.GetConfigData(ConfigName.ChampionshipSetting, 1)
                return config.ChampionshipPlayer..GetLanguageStrById(10097)
            end
            if rank > math.pow(2, i) and rank <= math.pow(2, i+1) then
                return (i+1)..GetLanguageStrById(10097)
            end
        end
    end
end
--

function this.TimeUpdate()
    local leftTime = ArenaManager.GetLeftTime()
    if leftTime <= 0 then
        this.RefreshArenaShow()
    end
    this.Arena_SeasonTime.text = string.format(GetLanguageStrById(10098), TimeToHMS(leftTime))

    local isActive = ArenaTopMatchManager.IsTopMatchActive()
    local startTime, endTime = ArenaTopMatchManager.GetTopMatchTime()
    if isActive then
        local leftTime = endTime - GetTimeStamp()
        if leftTime <= 0 then
            this.RefreshTopMatchShow()
        end
        this.TopMatch_SeasonTime.text = string.format(GetLanguageStrById(10098), TimeToHMS(leftTime))
    else
        local leftTime = startTime - GetTimeStamp()
        if leftTime <= 0 then
            this.RefreshTopMatchShow()
            this.TopMatch_SeasonTime.text = ""
        else
            this.TopMatch_SeasonTime.text = string.format(GetLanguageStrById(10099), TimeToHMS(leftTime))
        end
    end
end

--界面关闭时调用（用于子类重写）
function ArenaTypePanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
    ClearRedPointObject(RedPointType.Championships)
end

--界面销毁时调用（用于子类重写）
function ArenaTypePanel:OnDestroy()
    --ClearRedPointObject(RedPointType.Arena_Type_Normal, this.btnArenaRedpot)
    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
    -- SubUIManager.Close(this.BtView)
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

return ArenaTypePanel