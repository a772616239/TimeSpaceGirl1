require("Base/BasePanel")
local GuildBattlePanel = Inherit(BasePanel)
local this = GuildBattlePanel

this.contents = {
    [1] = {view = require("Modules/Guild/Battle/ChallengePanel"), panelName = "challengePanel"},
    [2] = {view = require("Modules/Guild/Battle/RewardRankPanel"), panelName = "rewardRankPanel"},
    [3] = {view = require("Modules/Guild/Battle/BoxPanel"), panelName = "boxPanel"},
}
local TabBox = require("Modules/Common/TabBox")
local tabs = {
    [1] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
        title = "cn2-X1_jingjichang_tiaozhanyeqian",
        name = GetLanguageStrById(50295),
        rpType = RedPointType.GuildBattle_FreeTime,
    },
    [2] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
        title = "cn2-X1_jingjichang_paihangyeqian",
        name = GetLanguageStrById(50296),
        rpType = -1,
    },
    [3] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
        title = "cn2-X1_yjingjichang_jiangliyeqian",
        name = GetLanguageStrById(50297),
        rpType = RedPointType.GuildBattle_BoxReward,
    },
}
local curPanelIndex = 1
function this:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnList/btnBack")
    this.tabbox = Util.GetGameObject(this.gameObject, "btnList")
    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)

    this.prefabs = {}
    for i = 1,#this.contents do
        this.prefabs[i] = Util.GetGameObject(self.gameObject, this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, this.contents[i].panelName))
    end

    this.chanageInfo = Util.GetGameObject(this.gameObject, "chanageInfo")
end

function this:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function this:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshGuildBattleState, this.PushState)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshGuildBattleState, this.PushState)
end

-- 打开时调用
function this:OnOpen(index)
    curPanelIndex = index and index or 1
    this.PageTabCtrl:Init(this.tabbox, tabs, curPanelIndex)
end

--界面打开时调用（用于子类重写）
function this:OnShow()
    this.PageTabCtrl:ChangeTab(curPanelIndex)
    this.contents[curPanelIndex].view:OnShow()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
    ClearRedPointObject(RedPointType.GuildBattle_FreeTime)
    ClearRedPointObject(RedPointType.GuildBattle_BoxReward)
end

-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    tab:GetComponent("Image").sprite = Util.LoadSprite(tabs[index][status])
    local title = Util.GetGameObject(tab, "title"):GetComponent("Image")
    local redpoint = Util.GetGameObject(tab, "redpoint")
    title.sprite = Util.LoadSprite(tabs[index].title)
    title.gameObject:SetActive(status == "select")
    Util.GetGameObject(tab, "Text"):GetComponent("Text").text = tabs[index].name
    if status == "default" then
        Util.GetGameObject(tab, "Text"):GetComponent("Text").color = UIColor.GRAY
    else
        Util.GetGameObject(tab, "Text"):GetComponent("Text").color = UIColor.WHITE
    end
    BindRedPointObject(tabs[index].rpType, redpoint)
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
    return false
end

-- tab改变事件
function this.OnPageTabChange(index)
    CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
    CheckRedPointStatus(RedPointType.GuildBattle_BoxReward)
    if index == 3 then
        if GuildBattleManager.guildBattleState == 1 then
            PopupTipPanel.ShowTipByLanguageId(11347)
            this.PageTabCtrl:ChangeTab(curPanelIndex)
            return
        end
    end

    --战果宝箱数据长度为0 默认为没有领取权限
    if #GuildBattleManager.rewardInfo == 0 and index == 3 then
        PopupTipPanel.ShowTip(GetLanguageStrById(50254))
        this.PageTabCtrl:ChangeTab(curPanelIndex)
        return
    end

    curPanelIndex = index

    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    this.contents[index].view:OnShow()
end

--推送状态
function this.PushState()
    if GuildBattleManager.guildBattleState == 1 and curPanelIndex == 3 then
        PopupTipPanel.ShowTipByLanguageId()
        this.PageTabCtrl:ChangeTab(1)
    end
end

return this