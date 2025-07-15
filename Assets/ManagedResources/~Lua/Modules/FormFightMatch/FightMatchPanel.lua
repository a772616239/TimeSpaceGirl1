require("Base/BasePanel")
FightMatchPanel = Inherit(BasePanel)
local this = FightMatchPanel
local matchView = require("Modules/FormFightMatch/MatchFight")
local rankView = require("Modules/FormFightMatch/RankInfoView")
local rewardView = require("Modules/FormFightMatch/RewardView")
-- 选择的标签
this.tabList = {}
this.panelList = {}
this.choseTab = {}
local panelType = {
    Match = 1,
    Rank = 2,
    Reward = 3,
}
-- 已经选中的标签
this.selectTab = 1

--初始化组件（用于子类重写）
function FightMatchPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "Bg/btnBack")
    this.tabList = {
        [1] = Util.GetGameObject(self.gameObject, "Bg/tabRoot/tabMatch"),
        [2] = Util.GetGameObject(self.gameObject, "Bg/tabRoot/tabRank"),
        [3] = Util.GetGameObject(self.gameObject, "Bg/tabRoot/tabReward"),
    }

    -- 构造方法实例对象
    this.panelList = {
        [1] = matchView.new(self, Util.GetGameObject(self.gameObject, "Bg/MatchView")),
        [2] = rankView.new(self, Util.GetGameObject(self.gameObject, "Bg/RankView")),
        [3] = rewardView.new(self, Util.GetGameObject(self.gameObject, "Bg/RewardView")),
    }

    this.choseTab = {
        [1] = Util.GetGameObject(this.tabList[1], "choose"),
        [2] = Util.GetGameObject(this.tabList[2], "choose"),
        [3] = Util.GetGameObject(this.tabList[3], "choose"),
    }
end

--绑定事件（用于子类重写）
function FightMatchPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)

    for i = 1, 3 do
        Util.AddClick(this.tabList[i], function ()
            this.SetChooseTab(i)
        end)
    end

end

--添加事件监听（用于子类重写）
function FightMatchPanel:AddListener()

end

--移除事件监听（用于子类重写）
function FightMatchPanel:RemoveListener()

end


--界面打开时调用（用于子类重写）
function FightMatchPanel:OnOpen()
end

function FightMatchPanel:OnShow()

    this.SetTabShowState(1)
    this.panelList[1]:ReShowPanel()
    this.panelList[1]:OnShow()
end

-- 设置标签
function this.SetChooseTab(curTab)
    if this.selectTab ~= curTab then
        -- 设置标签显示
        this.SetTabShowState(curTab)
        -- 设置数据显示
        this.SetPanelData(curTab)
        this.selectTab = curTab
    end
end

function this.SetTabShowState(curTab)
    this.choseTab[1]:SetActive(curTab == panelType.Match)
    this.choseTab[2]:SetActive(curTab == panelType.Rank)
    this.choseTab[3]:SetActive(curTab == panelType.Reward)

end

function this.SetPanelData(curTab)
    this.panelList[curTab]:OnShow()
    this.panelList[this.selectTab]:OnHidePanel()

end

--界面关闭时调用（用于子类重写）
function FightMatchPanel:OnClose()

    this.panelList[this.selectTab]:OnHidePanel()
    this.selectTab = 1
end

--界面销毁时调用（用于子类重写）
function FightMatchPanel:OnDestroy()

    for _, panel in pairs(this.panelList) do
        if panel.OnDestroy then
            panel:OnDestroy()
        end
    end

    this.tabList = {}
    this.panelList = {}
    this.choseTab = {}
end

return FightMatchPanel