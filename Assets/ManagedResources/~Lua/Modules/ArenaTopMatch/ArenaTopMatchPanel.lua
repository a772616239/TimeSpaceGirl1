require("Base/BasePanel")
local ArenaTopMatchPanel = Inherit(BasePanel)
local this = ArenaTopMatchPanel

-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabImgData = {select = "cn2-X1_shouhu_biaoqian_xuanzhong", default = "cn2-X1_tongyong_fenlan_weixuanzhong_03",}

local _TabData = {
    [1]= {txt = GetLanguageStrById(10128)},
    [2]= {txt = GetLanguageStrById(10129)},
    [3]= {txt = GetLanguageStrById(10130)},
    [4]= {txt = GetLanguageStrById(10131)},
    --[5]= {txt = GetLanguageStrById(10080)},
}
-- 内容数据
local _ViewData = {
    [1] = {script = "Modules/ArenaTopMatch/View/ATM_MainMatchView", titleType = 1},
    [2] = {script = "Modules/ArenaTopMatch/View/ATM_GuessView", titleType = 2},
    [3] = {script = "Modules/ArenaTopMatch/View/ATM_EliminationView", titleType = 2},
    [4] = {script = "Modules/ArenaTopMatch/View/ATM_RankView", titleType = 0},
    [5] = {script = "Modules/ArenaTopMatch/View/ATM_RewardView", titleType = 0},
    [6] = {script = "Modules/ArenaTopMatch/View/ATM_GuessTipView", titleType = 2},
}

local commonInfo = require("Modules/ArenaTopMatch/View/ATM_CommonInfo")
local commonTitle = require("Modules/ArenaTopMatch/View/ATM_Title")

--初始化组件（用于子类重写）
function ArenaTopMatchPanel:InitComponent()
    commonInfo.InitComponent(ArenaTopMatchPanel)
    this.tabbox = Util.GetGameObject(self.gameObject, "tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.content = Util.GetGameObject(self.gameObject, "content")

    this.ViewList = {}
    this.ViewList[1] = Util.GetGameObject(self.gameObject, "content/ATM_MainMatchView")
    this.ViewList[2] = Util.GetGameObject(self.gameObject, "content/ATM_GuessView")
    this.ViewList[3] = Util.GetGameObject(self.gameObject, "content/ATM_EliminationView")
    this.ViewList[4] = Util.GetGameObject(self.gameObject, "content/ATM_RankView")
    this.ViewList[5] = Util.GetGameObject(self.gameObject, "ATM_RewardView")
    this.ViewList[6] = Util.GetGameObject(self.gameObject, "content/ATM_GuessTipView")
     for _, view in ipairs(this.ViewList) do
         view:SetActive(false)
     end

    this.ViewLogicList = {}

    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    -- 上部货币显示
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowRight})

    -- 初始化公用title
    local ATM_Title = Util.GetGameObject(self.gameObject, "content/ATM_Title")
    commonTitle:InitComponent(ATM_Title)
    ATM_Title:SetActive(true)

end

--绑定事件（用于子类重写）
function ArenaTopMatchPanel:BindEvent()
    commonTitle:BindEvent()
    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)

    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)

end

--添加事件监听（用于子类重写）
function ArenaTopMatchPanel:AddListener()
    commonTitle:AddListener()
end

--移除事件监听（用于子类重写）
function ArenaTopMatchPanel:RemoveListener()
    commonTitle:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ArenaTopMatchPanel:OnOpen(...)
    commonTitle:OnOpen()
    -- 参数保存
    local args = {...}
    this._CurTabIndex = args[1] or 1
    ArenaTopMatchManager.SetCurTabIndex(this._CurTabIndex)
    ArenaTopMatchManager.RequestTopMatchBaseInfo()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ArenaTopMatchPanel:OnShow()
    commonTitle:OnShow()
    if this.TabCtrl then
        if this._CurTabIndex > 5 then
            ArenaTopMatchManager.SetCurTabIndex(2)
        end
        this._CurTabIndex = ArenaTopMatchManager.GetCurTabIndex()
        this.TabCtrl:ChangeTab(this._CurTabIndex)
    end
    SoundManager.PlayMusic(SoundConfig.BGM_Arena)
end

this.cursortingOrder = 0
function ArenaTopMatchPanel:OnSortingOrderChange()
    commonTitle:OnSortingOrderChange()

    this.cursortingOrder = self.sortingOrder

    for index, logic in pairs(this.ViewLogicList) do
        if logic.OnSortingOrderChange then
            logic:OnSortingOrderChange(self.sortingOrder)
        end
    end
end

--界面关闭时调用（用于子类重写）
function ArenaTopMatchPanel:OnClose()
    ClearRedPointObject(RedPointType.Championships_Rank_Link)
    commonTitle:OnClose()

    if this._CurLogicIndex then
        this.CloseView(this._CurLogicIndex)
    end
end

--界面销毁时调用（用于子类重写）
function ArenaTopMatchPanel:OnDestroy()
    commonTitle:OnDestroy()
    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
    -- 调用销毁方法
    for index, logic in pairs(this.ViewLogicList) do
        if logic.OnDestroy then
            logic:OnDestroy()
        end
    end
end

-- tab按钮自定义显示设置
function this.TabAdapter(tab, index, status)
    local img = Util.GetGameObject(tab, "bg")
    local select = Util.GetGameObject(tab, "select")
    local default = Util.GetGameObject(tab, "default")
    img:GetComponent("Image").sprite = Util.LoadSprite(_TabImgData[status])
    default:GetComponent("Text").text = _TabData[index].txt
    select:GetComponent("Text").text = _TabData[index].txt
    default:SetActive(status == "default")
    select:SetActive(status == "select")

    if index == 4 then
        BindRedPointObject(RedPointType.Championships_Rank_Link, Util.GetGameObject(tab, "redpoint"))
    end
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    if lastIndex then
        this.CloseView(lastIndex)
    end
    this.OpenView(index)
end

function this.OpenView(index)
    this._CurLogicIndex = index
    ArenaTopMatchManager.SetCurTabIndex(index)
    this._CurTabIndex = index

    local logic = this.ViewLogicList[index]
    if not logic then
        this.ViewLogicList[index] = reimport(_ViewData[index].script)
        logic = this.ViewLogicList[index]
        logic.gameObject = this.ViewList[index]
        logic.transform = this.ViewList[index].transform

        if logic.InitComponent then
            logic:InitComponent()
        end
        if logic.BindEvent then
            logic:BindEvent()
        end
    end
    logic.gameObject:SetActive(true)

    if logic.AddListener then
        logic:AddListener()
    end

    if logic.OnOpen then
        logic:OnOpen()
    end

    --if logic.OnSortingOrderChange then
    --    logic:OnSortingOrderChange(this.cursortingOrder)
    --end

    this.PlayerHeadFrameView:OnShow()
    -- 货币界面
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.TopMatch })

    -- 公用的title显示
    commonTitle:SetTitleType(_ViewData[index].titleType)
end

function this.CloseView(index)
    -- if this._CurLogicIndex ~= index then return end
    local logic = this.ViewLogicList[index]
    if logic then
        if logic.RemoveListener then
            logic:RemoveListener()
        end
        if logic.OnClose then
            logic:OnClose()
        end
        logic.gameObject:SetActive(false)
    end
end
-- 设置显隐
function this.SetRewardViewActive(index)
    -- body
    this.OpenView(index)
end
-- 设置显隐
function this.SetRewardViewClose(index)
    -- body
    this.CloseView(index)
end
return ArenaTopMatchPanel