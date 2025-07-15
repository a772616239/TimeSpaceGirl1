require("Base/BasePanel")
LaddersChallengeRecordPanel = Inherit(BasePanel)
local this = LaddersChallengeRecordPanel
local TabBox = require("Modules/Common/TabBox")
local curIndex = 1

local _TabData = {
    [1] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name = GetLanguageStrById(50299) },
    [2] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name = GetLanguageStrById(50300) },
}
this.contents = {
    [1] = {view = require("Modules/Ladders/view/LaddersChallenge_MyRecord"), panelName = "LaddersMyRecord"},
    [2] = {view = require("Modules/Ladders/view/LaddersChallenge_ManitoShow"), panelName = "LaddersManitoShow"},
}
--初始化组件（用于子类重写）
function LaddersChallengeRecordPanel:InitComponent()
    this.prefabs = {}
    for i = 1,#this.contents do
        this.prefabs[i] = Util.GetGameObject(self.gameObject, "content/"..this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, "content/"..this.contents[i].panelName))
    end

    this.tabBox = Util.GetGameObject(self.gameObject, "tabbox")

    this.tabCtrl = TabBox.New()
    this.tabCtrl:SetTabAdapter(this.OnTabAdapter) 
    this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)
    this.tabCtrl:Init(this.tabBox, _TabData)

    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
end

--绑定事件（用于子类重写）
function LaddersChallengeRecordPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)

    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function LaddersChallengeRecordPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function LaddersChallengeRecordPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function LaddersChallengeRecordPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LaddersChallengeRecordPanel:OnShow()
end

function LaddersChallengeRecordPanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
    for i = 1, #this.contents do
        this.contents[i].view:OnSortingOrderChange(self.sortingOrder)
    end
end
function LaddersChallengeRecordPanel.OnTabAdapter(tab, index, status)
    tab:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    local default = Util.GetGameObject(tab, "default"):GetComponent("Text")
    local select = Util.GetGameObject(tab, "select"):GetComponent("Text")
    default.text = _TabData[index].name
    select.text = _TabData[index].name
    default.gameObject:SetActive(status == "default")
    select.gameObject:SetActive(status == "select")
end

--切换视图
function LaddersChallengeRecordPanel.OnChangeTab(index)
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

    --执行子模块初始化
    this.contents[index].view:OnShow(this)
end

--界面关闭时调用（用于子类重写）
function LaddersChallengeRecordPanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
end

--界面销毁时调用（用于子类重写）
function LaddersChallengeRecordPanel:OnDestroy()
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

return LaddersChallengeRecordPanel