require("Base/BasePanel")
CardActivityPanel = Inherit(BasePanel)
local this = CardActivityPanel
local _CurPageIndex = 1
local TabBox = require("Modules/Common/TabBox")
local ItemPopIn = require("Modules/Common/ItemPopIn")--列表项逐格入场（页面级批量接入）
local tabs = {
    [1] = {
        default = "cn2-X1_zhutihuodong_yingxiongjiadao_02",
        select = "cn2-X1_zhutihuodong_yingxiongjiadao_01",
        rpType = RedPointType.CardActivity_Draw,
        panelType = PanelType.CardActivity,
        ActType = ActivityTypeDef.CardActivity_Draw
    },
    [2] = {
        default = "cn2-X1_zhutihuodong_shenmizhiling_02",
        select = "cn2-X1_zhutihuodong_shenmizhiling_01",
        rpType = RedPointType.CardActivity_Task,
        panelType = PanelType.CardActivity,
        ActType = ActivityTypeDef.CardActivity_Task
    },
    [3] = {
        default = "cn2-X1_zhutihuodong_yingxionglibao_02",
        select = "cn2-X1_zhutihuodong_yingxionglibao_01",
        rpType = -1,
        panelType = PanelType.CardActivity,
        ActType = ActivityTypeDef.CardActivity_Gift
    },
    [4] = {
        default = "cn2-X1_zhutihuodong_yingxionghaoli_02",
        select = "cn2-X1_zhutihuodong_yingxionghaoli_01",
        rpType = RedPointType.CardActivity_Haoli,
        panelType = PanelType.CardActivity,
        ActType = ActivityTypeDef.CardActivity_Haoli
    },
    [5] = {
        default = "cn2-X1_zhutihuodong_yingxiongshouji_02",
        select = "cn2-X1_zhutihuodong_yingxiongshouji_01",
        rpType = RedPointType.CardActivity_Collect,
        panelType = PanelType.CardActivity,
        ActType = ActivityTypeDef.CardActivity_Collect
    },
}

this.contents = {
    [1] = {view = require("Modules/CardActivity/DrawCardPanel"), panelName = "page_1"},
    [2] = {view = require("Modules/CardActivity/TaskPanel"), panelName = "page_2"},
    [3] = {view = require("Modules/CardActivity/GiftPanel"), panelName = "page_3"},
    [4] = {view = require("Modules/CardActivity/WishPanel"), panelName = "page_4"},
    [5] = {view = require("Modules/CardActivity/CollectPanel"), panelName = "page_5"},
}
--初始化组件（用于子类重写）
function CardActivityPanel:InitComponent()
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
    this.contents[index].view:OnShow(this.sortingOrder,this)
    --🔴 必须点号调用：PlayContentPopIn 是点号定义（首参就是 index），写成 this:PlayContentPopIn(index)
    --  会把 this 当 index 传进去 ⇒ contents[this] = nil ⇒ "attempt to index field '?'"
    this.PlayContentPopIn(index)--列表项逐格入场（必须在页内容 OnShow 的 SetData 之后）
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType =  tabs[index].panelType })
end

-- 列表项逐格入场（页面级批量）：Task/Gift/Wish/Collect 四页都是 OnShow 里同步
-- SetData 的 ScrollCycleView，PlayPage 自动扫描即可（找不到列表 no-op）。
-- 🔴 page_1（DrawCardPanel）要跳过：它唯一的长列表挂在 ChangeWishPanel 弹窗里、
-- 平时整窗隐藏，PlayPage 会把它扫出来播在看不见的弹窗里（弹窗真正打开时反而没动画），
-- 这一页由弹窗打开时机自己播（DrawCardPanel:PlayWishPopIn）。
-- 播的时机 = 玩家切页签 / 打开面板（OnShow → ChangeTab 也走 OnPageTabChange 这条）；
-- 数据回调刷新（领奖 this.Refresh / 买礼包 / GameEvent.Task.Achievement → view:OnShow）
-- 都不经过面板这条路径 ⇒ 天然不重播。
function this.PlayContentPopIn(index)
    if this.contents[index].view == DrawCardPanel then
        return
    end
    ItemPopIn.PlayPage(this.contents[index].view)
end

-- 切页 / 关闭 / 销毁都要回收（🔴 漏调 = item 永久停在半截缩放上）。
-- 没接上的页（DrawCardPanel 的批量入口）StopPage 是 no-op，循环全停即可。
function this.StopContentPopIn()
    for i = 1, #this.contents do
        ItemPopIn.StopPage(this.contents[i].view)
    end
end

--绑定事件（用于子类重写）
function CardActivityPanel:BindEvent()
    Util.AddClick(this.close,function ()
        self:ClosePanel()
    end)
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function CardActivityPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function CardActivityPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function CardActivityPanel:OnOpen(index)
    _CurPageIndex = index and index or 1

    this.PageTabCtrl:Init(this.tabbox, tabs,_CurPageIndex)

    for i = 1, #tabs do
        local go = Util.GetGameObject(this.tabbox, "box").transform:GetChild(i - 1).gameObject
        BindRedPointObject(tabs[i].rpType, Util.GetGameObject(go, "redPoint"))
    end
end

function CardActivityPanel:OnShow()
    for i = 1, #tabs do
        CheckRedPointStatus(tabs[i].rpType)
    end
    this.PageTabCtrl:ChangeTab(_CurPageIndex)
    this.contents[_CurPageIndex].view:OnShow()
    this.PlayerHeadFrameView:OnShow(true)
end

--界面关闭时调用（用于子类重写）
function CardActivityPanel:OnClose()
    this.StopContentPopIn()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

--界面销毁时调用（用于子类重写）
function CardActivityPanel:OnDestroy()
    this.StopContentPopIn()
    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
    for i = 1, #tabs do
        ClearRedPointObject(tabs[i].rpType)
    end
end

return CardActivityPanel