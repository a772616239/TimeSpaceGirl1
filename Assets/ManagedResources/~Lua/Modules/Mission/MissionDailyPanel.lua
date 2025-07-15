require("Base/BasePanel")
MissionDailyPanel = Inherit(BasePanel)
local this = MissionDailyPanel
--子模块脚本
local contentScripts = {
    --日常
    [1] = {view = require("Modules/Mission/MissionDailyPanel_Daily"), panelName = "MissionDailyPanel_Daily",type = 1},
    --成就
    [2] = {view = require("Modules/Mission/MissionDailyPanel_Achievement"), panelName = "MissionDailyPanel_Achievement",type = 2},
}
local TabBox = require("Modules/Common/TabBox")
local _TabData = { [1] = { icon = "cn2-X1_richang_richangyeqian", name = GetLanguageStrById(11358) },
                 [2] = { icon = "cn2-X1_richang_chengjiuyeqian", name = GetLanguageStrById(11359) },
                 }
local BannerBg = {[1] = "cn2-X1_richang_banner_01", [2] = "cn2-X1_richang_banner_02"}
--子模块预设
local contentPrefabs = {}
--打开弹窗索引
local index = 0
local redPointList

    --初始化组件（用于子类重写）
function MissionDailyPanel:InitComponent()
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")
    this.TabCtrl = TabBox.New()
    this.closeBtn = Util.GetGameObject(self.transform, "closeBtn")
    this.contents = Util.GetGameObject(self.transform, "Contents")
    this.banner = Util.GetGameObject(self.transform, "bg/Banner"):GetComponent("Image")
    --子模块脚本初始化
    for i = 1, #contentScripts do
        contentScripts[i].view:InitComponent(Util.GetGameObject(this.contents, contentScripts[i].panelName))
    end
    --预设赋值
    for i = 1,#contentScripts do
        contentPrefabs[i] = Util.GetGameObject(this.contents,contentScripts[i].panelName)
    end
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowRight})
end

--绑定事件（用于子类重写）
function MissionDailyPanel:BindEvent()
    Util.AddClick(this.closeBtn, function()
        self:ClosePanel()
    end)

    for i = 1, #contentScripts do
        contentScripts[i].view:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function MissionDailyPanel:AddListener()
    for i = 1, #contentScripts do
        contentScripts[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function MissionDailyPanel:RemoveListener()
    for i = 1, #contentScripts do
        contentScripts[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function MissionDailyPanel:OnOpen(popupType,...)
    this.HeadFrameView:OnShow()

    --根据传入类型打开对应面板
    index = popupType
    if not index then
        index = 1
        if RedPointManager.GetRedPointMissionDaily() then
            index = 1
        elseif TaskManager.GetAchievementState() then
            index = 2
        end
    end

    for i = 1,#contentPrefabs do
        contentPrefabs[i].gameObject:SetActive(false)
    end
    contentPrefabs[index].gameObject:SetActive(true)
    contentScripts[index].view:OnShow(this,...)--1、传入自己 2、传入不定参
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MissionDailyPanel:OnShow()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, index)
    redPointList = {}
    for i = 1, Util.GetGameObject(this.tabBox,"box").transform.childCount do
        redPointList[i] = Util.GetGameObject(Util.GetGameObject(this.tabBox,"box").transform:GetChild(i-1).gameObject,"Redpot")
        redPointList[i]:SetActive(false)
    end
    if redPointList[1] and redPointList[2] then
        BindRedPointObject(RedPointType.DailyTask, redPointList[1])
        BindRedPointObject(RedPointType.Achievement_Main, redPointList[2])
    end
end

function MissionDailyPanel:OnSortingOrderChange()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnSortingOrderChange(self.sortingOrder)
    end
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab, "default")
    local select = Util.GetGameObject(tab, "select")
    Util.GetGameObject(default, "Text"):GetComponent("Text").text = _TabData[index].name
    Util.GetGameObject(select, "Text"):GetComponent("Text").text = _TabData[index].name
    Util.GetGameObject(select, "icon"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].icon)
    default:SetActive(status == "default")
    select:SetActive(status == "select")
end

--切换视图
function this.SwitchView(_index)
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, index = index, _index
    for i = 1, #contentScripts do
        if oldSelect ~= 0 then contentScripts[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #contentPrefabs do
        contentPrefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    --执行子模块初始化
    contentScripts[index].view:OnShow(this)

    this.banner.sprite = Util.LoadSprite(BannerBg[index])
end
--界面关闭时调用（用于子类重写）
function MissionDailyPanel:OnClose()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnClose()
    end
    ClearRedPointObject(RedPointType.DailyTask)
    ClearRedPointObject(RedPointType.Achievement_Main)
end

--界面销毁时调用（用于子类重写）
function MissionDailyPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.upView)

    for i = 1, #contentScripts do
        contentScripts[i].view:OnDestroy()
    end
end

return MissionDailyPanel