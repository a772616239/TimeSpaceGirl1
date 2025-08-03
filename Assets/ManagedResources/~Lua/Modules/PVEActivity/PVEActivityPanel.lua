require("Base/BasePanel")
local PVEActivityPanel = Inherit(BasePanel)
local this = PVEActivityPanel

this.contents = {
    [1] = {view = require("Modules/PVEActivity/ChanagePanel"), panelName = "panel1"},
}
local TabBox = require("Modules/Common/TabBox")
local tabs = {}
local curPanelIndex = 1

local ActivityId
function this:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "bg/btnBack")
    this.tabbox = Util.GetGameObject(this.gameObject, "bg/tabList/viewPort")
    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)

    this.prefabs = {}
    for i = 1,#this.contents do
        this.prefabs[i] = Util.GetGameObject(self.gameObject, this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, this.contents[i].panelName))
    end

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowRight})
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
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

-- 打开时调用
function this:OnOpen(index)
    curPanelIndex = index and index or 1

    tabs = PVEActivityManager.ActivityTabData()

    this.PageTabCtrl:Init(this.tabbox, tabs, curPanelIndex)
end

--界面打开时调用（用于子类重写）
function this:OnShow()
    this.PageTabCtrl:ChangeTab(curPanelIndex)

    -- this.contents[curPanelIndex].view:OnShow()
    this.contents[1].view:OnShow(this, ActivityId)
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
    
    CheckRedPointStatus(RedPointType.Challenge)
    Log("PVEActivityPanel OnClose")
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
    -- Log("PVEActivityPanel OnDestroy")
end

-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    Util.GetGameObject(tab, "Image"):GetComponent("Image").sprite = Util.LoadSprite(tabs[index].default)
    Util.GetGameObject(tab, "selected/Image"):GetComponent("Image").sprite = Util.LoadSprite(tabs[index].select)
    Util.GetGameObject(tab, "selected"):SetActive(status == "select")
    -- local redpoint = Util.GetGameObject(tab, "redPoint")
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
    return false
end

-- tab改变事件
function this.OnPageTabChange(index)
    curPanelIndex = index
    -- for i = 1, #this.prefabs do
    --     this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    -- end
    -- this.contents[index].view:OnShow()
    ActivityId = tabs[curPanelIndex].activityId
    this.HeadFrameView:OnShow()
    this.contents[1].view:OnShow(this, ActivityId)
    -- this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = tabs[index].panelType})
    -- this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
end

return this