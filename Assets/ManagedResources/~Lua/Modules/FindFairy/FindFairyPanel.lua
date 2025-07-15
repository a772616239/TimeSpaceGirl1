---东海寻仙限时抽卡活动---
require("Base/BasePanel")
FindFairyPanel = Inherit(BasePanel)
local this = FindFairyPanel

--底部按钮
local tabBtns = {}
local redPointGrid = {}

--子模块脚本
this.contents = {
    --主面板
    [1] = {view = require("Modules/FindFairy/View/FindFairy_MainView"), panelName = "MainView", tag = "d_dhxx_anniu_02", selectTag = "d_dhxx_anniu_01"},
    --天官赐福
    [2] = {view = require("Modules/FindFairy/View/FindFairy_GiftOneView"), panelName = "GiftOneView", tag = "d_dhxx_tianguananiu_01", selectTag = "d_dhxx_tianguananiu"},
    --每日仙缘礼
    [3] = {view = require("Modules/FindFairy/View/FindFairy_GiftTwoView"), panelName = "GiftTwoView", tag = "d_dhxx_xianyuananniu_01", selectTag = "d_dhxx_xianyuananniu"},
    --寻仙进阶
    [4] = {view = require("Modules/FindFairy/View/FindFairy_GiftThreeView"), panelName = "GiftThreeView", tag = "d_dhxx_anniu_04", selectTag = "d_dhxx_anniu_03"},
    --寻仙限时豪礼
    [5] = {view = require("Modules/FindFairy/View/FindFairy_GiftFourView"), panelName = "GiftFourView", tag = "d_dhxx_anniu_06", selectTag = "d_dhxx_anniu_05"},
    --寻仙盛典
    [6] = {view = require("Modules/FindFairy/View/FindFairy_GiftFiveView"), panelName = "GiftFiveView", tag = "d_dhxx_xianshihaolinanniu_01", selectTag = "d_dhxx_xianshihaolinanniu"},
}
--上一子模块索引
local curIndex=0

--初始化组件（用于子类重写）
function FindFairyPanel:InitComponent()
    this.panel = Util.GetGameObject(self.gameObject, "Panel")
    this.backBtn = Util.GetGameObject(this.panel, "BackBtn")
    for i = 1, #this.contents do
        tabBtns[i] = Util.GetGameObject(this.panel, "Tabs/Rect/Grid/Btn (" .. i .. ")")
        redPointGrid[i] = Util.GetGameObject(tabBtns[i], "RedPoint")
        redPointGrid[i]:SetActive(false)
    end

    this.content = Util.GetGameObject(this.panel, "Content")

    --预设
    for i = 1, #this.contents do
        this.contents[i].view:InitComponent(Util.GetGameObject(this.content, this.contents[i].panelName))
    end
end

--绑定事件（用于子类重写）
function FindFairyPanel:BindEvent()
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
    --底部页签按钮
    for i = 1, #this.contents do
        Util.AddClick(
            tabBtns[i],
            function()
                if i==curIndex then return end --防止连点
                this.SwitchView(i)
            end)
    end
    --返回按钮
    Util.AddClick(
        this.backBtn,
        function()
            CheckRedPointStatus(RedPointType.FindFairy_OneView)
            self:ClosePanel()
        end)

    BindRedPointObject(RedPointType.FindFairy_OneView, redPointGrid[1])
    BindRedPointObject(RedPointType.FindFairy_ThreeView, redPointGrid[4])
    BindRedPointObject(RedPointType.FindFairy_FourView, redPointGrid[5])
end

--添加事件监听（用于子类重写）
function FindFairyPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
    Game.GlobalEvent:AddEvent(GameEvent.FindFairy.RefreshBuyOpenState, this.CheckTabBtnsState)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose,this.CheckTabBtnsState)--活动开启关闭
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnPatFaceRedRefresh,this.CheckTabBtnsState)--刷新拍脸
end

--移除事件监听（用于子类重写）
function FindFairyPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
    Game.GlobalEvent:RemoveEvent(GameEvent.FindFairy.RefreshBuyOpenState, this.CheckTabBtnsState)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose,this.CheckTabBtnsState)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnPatFaceRedRefresh,this.CheckTabBtnsState)
end

--界面打开时调用（用于子类重写）
function FindFairyPanel:OnOpen(...)
    local args = {...}
    if args[1] then
        curIndex=args[1]
    else
        curIndex=1
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FindFairyPanel:OnShow()
    this.upView = SubUIManager.Open(SubUIConfig.UpView, self.transform, {showType = UpViewOpenType.ShowLeft})
    this.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.FindFairy})
    this.CheckTabBtnsState()


    -- 如果是出海返回时 这里显示主面板即可
    if FindFairyManager.isGoToSea then
        this.SwitchView(1)
        FindFairyManager.isGoToSea=false
    elseif FindFairyManager.isOver then--如果是活动结束的返回
        this.SwitchView(1)
    else
        this.SwitchView(this.GetPriorityIndex(curIndex))--走的红点
    end
end

--重设层级
function FindFairyPanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

--界面关闭时调用（用于子类重写）
function FindFairyPanel:OnClose()
    SubUIManager.Close(this.upView)
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
end

--界面销毁时调用（用于子类重写）
function FindFairyPanel:OnDestroy()
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
    ClearRedPointObject(RedPointType.FindFairy_OneView)
    ClearRedPointObject(RedPointType.FindFairy_ThreeView)
    ClearRedPointObject(RedPointType.FindFairy_FourView)
end

--切换视图
function this.SwitchView(index)
    --根据开启类型显隐对应按钮 防止表配错意外显示

    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, curIndex = curIndex, index
    for i = 1, #this.contents do
        if oldSelect~=0 then this.contents[oldSelect].view:OnClose() break end
    end
    --切换底部页签表现
    for i = 1, #tabBtns do
        tabBtns[i]:GetComponent("Image").sprite = Util.LoadSprite(this.contents[i].tag)
        this.contents[i].view.gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    tabBtns[index]:GetComponent("Image").sprite = Util.LoadSprite(this.contents[index].selectTag)

    --执行子模块初始化
    this.contents[index].view:OnShow(this.sortingOrder)
end

--检测页签按钮状态
function this.CheckTabBtnsState()
    tabBtns[1]:SetActive(ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)~=nil)

    --天官赐福
    local tgcfIds = FindFairyManager.GetGiftActiveBtnState(DirectBuyType.TGCF)
    tabBtns[2]:SetActive(tgcfIds and #tgcfIds > 0)

    local mrxyIds = FindFairyManager.GetGiftActiveBtnState(DirectBuyType.MRXY)
    tabBtns[3]:SetActive(mrxyIds and #mrxyIds > 0)

    local data4=ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairyUpStar)
    tabBtns[4]:SetActive(data4~=nil)

    local data5=ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairyCeremony)
    tabBtns[5]:SetActive(data5~=nil)

    local allTimeLi = FindFairyManager.GetGiftBtnState()
    tabBtns[6]:SetActive(#allTimeLi > 0)
    --local conFigData = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, 39)--限时豪礼
    --local data6 = OperatingManager.GetGiftGoodsInfo(conFigData.Type,conFigData.Id)
    --tabBtns[6]:SetActive(data6 ~= nil)

    local isClosePanel = true --预告结束关闭面板
    if tabBtns[1].activeSelf==false then
        isClosePanel = false
        CheckRedPointStatus(RedPointType.FindFairy_OneView)
        this:ClosePanel()
    end
end

--获取红点索引
function this.GetPriorityIndex(defaultIndex)
    local index = defaultIndex
    for idx, operateItem in ipairs(tabBtns) do
        if operateItem.activeSelf and Util.GetGameObject(operateItem, "RedPoint").activeSelf then
            index = idx
            break
        end
    end
    return index
end

return FindFairyPanel