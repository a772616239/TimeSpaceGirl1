require("Base/BasePanel")
AdjutantActivityPanel = Inherit(BasePanel)
local this = AdjutantActivityPanel
local _CurPageIndex = 1
local TabBox = require("Modules/Common/TabBox")
local tabs = {
    [1] = {
        default = "cn2-X1_xianquhuodong_yeqian_01",
        select = "cn2-X1_xianquhuodong_yeqianxuanzhong_01",
        rpType = -1,
        panelType = PanelType.Main,
        ActType = ActivityTypeDef.AdjutantCurrent
    },
    [2] = {
        default = "cn2-X1_xianquhuodong_yeqian_02",
        select = "cn2-X1_xianquhuodong_yeqianxuanzhong_02",
        rpType = RedPointType.AdjutantActivity_Challenge,
        panelType = PanelType.Main,
        ActType = ActivityTypeDef.AdjutantChallenge
    },
    [3] = {
        default = "cn2-X1_xianquhuodong_yeqian_03",
        select = "cn2-X1_xianquhuodong_yeqianxuanzhong_03",
        rpType = -1,
        panelType = PanelType.AdjutantRecruitPanel,
        ActType = ActivityTypeDef.AdjutantRecruit
    },
    [4] = {
        default = "cn2-X1_xianquhuodong_yeqian_04",
        select = "cn2-X1_xianquhuodong_yeqianxuanzhong_04",
        rpType = -1,
        panelType = PanelType.Main,
        ActType = ActivityTypeDef.AdjutantGift
    },
}

this.contents = {
    [1] = {view = require("Modules/AdjutantActivity/AdjutantCurrentPanel"), panelName = "page_1"},
    [2] = {view = require("Modules/AdjutantActivity/AdjutantChallengePanel"), panelName = "page_2"},
    [3] = {view = require("Modules/AdjutantActivity/AdjutantRecruitPanel"), panelName = "page_3"},
    [4] = {view = require("Modules/AdjutantActivity/AdjutantGiftPanel"), panelName = "page_4"},
}
--初始化组件（用于子类重写）
function AdjutantActivityPanel:InitComponent()
    this.close = Util.GetGameObject(self.gameObject,"btnBack")
    this.tabbox = Util.GetGameObject(self.gameObject, "tabbox")

    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)

    this.prefabs = {}

    for i = 1, #this.contents do
        this.prefabs[i] = Util.GetGameObject(self.gameObject,this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, this.contents[i].panelName))
    end

    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)
end

-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    local img = Util.GetGameObject(tab, "icon"):GetComponent("Image")
    local selected = Util.GetGameObject(tab, "selected")

    img.sprite = Util.LoadSprite(GetPictureFont(tabs[index].default))
    Util.GetGameObject(selected, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(tabs[index].select))
    selected:SetActive(status == "select")

    local id = ActivityGiftManager.IsActivityTypeOpen(tabs[index].ActType)
    if id and id > 0 and ActivityGiftManager.IsQualifiled(tabs[index].ActType) then
        tab.gameObject:SetActive(true)
    else
        tab.gameObject:SetActive(false)
    end
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
    return false
end

-- tab改变事件
function this.OnPageTabChange(index)
    _CurPageIndex = index

    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    this.contents[index].view:OnShow(this.sortingOrder, this)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType =  tabs[index].panelType })
end

--绑定事件（用于子类重写）
function AdjutantActivityPanel:BindEvent()
    Util.AddClick(this.close,function ()
        self:ClosePanel()
    end)
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function AdjutantActivityPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function AdjutantActivityPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function AdjutantActivityPanel:OnOpen(index)
    _CurPageIndex = index and index or 1

    this.PageTabCtrl:Init(this.tabbox, tabs,_CurPageIndex)

    for i = 1, #tabs do
        local go = Util.GetGameObject(this.tabbox, "box").transform:GetChild(i - 1).gameObject
        BindRedPointObject(tabs[i].rpType, Util.GetGameObject(go, "redPoint"))
    end
end

function AdjutantActivityPanel:OnShow()
    this.PageTabCtrl:ChangeTab(_CurPageIndex)
    this.contents[_CurPageIndex].view:OnShow()
    this.PlayerHeadFrameView:OnShow(true)

    CheckRedPointStatus(RedPointType.AdjutantActivity_Challenge)
end

--界面关闭时调用（用于子类重写）
function AdjutantActivityPanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end

    for i = 1, #tabs do
        ClearRedPointObject(tabs[i].rpType)
    end
end

--界面销毁时调用（用于子类重写）
function AdjutantActivityPanel:OnDestroy()
    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

return AdjutantActivityPanel