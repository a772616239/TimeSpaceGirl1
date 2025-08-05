require("Base/BasePanel")
local DynamicActivityPanel = Inherit(BasePanel)
local this = DynamicActivityPanel

local TabBox = require("Modules/Common/TabBox")-- Tab管理器
local GlobalActConfig = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local AcitvityShowTheme = ConfigManager.GetAllConfigsData(ConfigName.AcitvityShowTheme)
local curPageIndex = 1
local orginLayer
local tabs = {}

local curActivityCount = {
    [1] = require("Modules/DynamicActivity/DynamicTaskPage"),   --主题活动
    [2] = require("Modules/DynamicActivity/SheJiDaDian"),       --次元引擎
    [3] = require("Modules/DynamicActivity/TimeLimitedCall"),   --限时招募
    [4] = require("Modules/DynamicActivity/QianKunBox"),        --神秘盲盒
    [5] = require("Modules/DynamicActivity/ZhenQiYiBaoPage"),   --秘境探索
    [6] = require("Modules/DynamicActivity/LeiJiChongZhiPage"), --累计充值
    [7] = require("Modules/DynamicActivity/XianShiShangShi"),   --位面商人
    [8] = require("Modules/Expert/DynamicActivityExChange"),    --限时兑换(在限时活动)
    [9] = require("Modules/DynamicActivity/YiJingBaoKu"),       --命运魔镜
    [10] = require("Modules/DynamicActivity/ShengYiTianJiang"),
    [11] = require("Modules/DynamicActivity/LingShowTeHui"),
    [12] = require("Modules/DynamicActivity/LingShouBaoGe"),
    [13] = require("Modules/DynamicActivity/XinJiangLaiXi"),
    [14] = require("Modules/DynamicActivity/XiangYaoDuoBao"),
    [15] = require("Modules/DynamicActivity/ShengXingYouLi"),
}

--初始化组件（用于子类重写）
function DynamicActivityPanel:InitComponent()
    orginLayer = 0
    this.tabbox = Util.GetGameObject(self.gameObject, "bg/tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.content = Util.GetGameObject(self.gameObject, "bg/pageContent")
    this.tabList = Util.GetGameObject(self.gameObject,"bg/tabbox")
    this.PageList = {}
    for i = 1,#curActivityCount do
        this.PageList[i] = curActivityCount[i].new(self, Util.GetGameObject(self.transform, "bg/pageContent/page"..i),this.UpView)
    end
    -- 上部货币显示
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})
    -- 初始化Tab管理器
    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)

    this.InitTabs()
end
--绑定事件（用于子类重写）
function DynamicActivityPanel:BindEvent()
    -- 关闭界面打开主城
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    end)
end

--添加事件监听（用于子类重写）
function DynamicActivityPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivityBtn)
    for i = 1, #this.PageList do
        if this.PageList[i] then
            this.PageList[i]:AddListener()
        end
    end
end
--移除事件监听（用于子类重写）
function DynamicActivityPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivityBtn)
    for i = 1, #this.PageList do
        if this.PageList[i] then
            this.PageList[i]:RemoveListener()
        end
    end
end

this.RefreshActivityBtn = function()
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct) then
        this:ClosePanel()
    end
end

--界面打开时调用（用于子类重写）
function DynamicActivityPanel:OnOpen(chooseIndex)
    -- -- 初始化tab数据
    -- if chooseIndex and chooseIndex ~= ActivityTypeDef.DynamicAct then
    --     for i = 1, #tabs do
    --         if tabs[i].ActType == chooseIndex then
    --             curPageIndex = i
    --         end
    --     end
    -- else
    --     curPageIndex = chooseIndex or 1
    -- end

    if chooseIndex then
        for i = 1, #tabs do
            if tabs[i].Id == chooseIndex then
                curPageIndex = i
            end
        end
    else
        curPageIndex = 1
    end
    this.PageTabCtrl:Init(this.tabbox, tabs,curPageIndex)
end

-- 打开，重新打开时回调
function DynamicActivityPanel:OnShow()
    SoundManager.PlayMusic(SoundConfig.BGM_Main)

    local activiytId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct) 
    if not activiytId or activiytId <= 0 then
       self:ClosePanel()
    end
    this.btnBack:SetActive(true)
    this.tabList:SetActive(true)
    if curPageIndex and curPageIndex == 1 then
        local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct)
        curPageIndex = GlobalActConfig[id].ShowArt
        this.PageTabCtrl:ChangeTab(curPageIndex)
    elseif curPageIndex then
        this.PageTabCtrl:ChangeTab(curPageIndex)
    end
end

--界面关闭时调用（用于子类重写）
function DynamicActivityPanel:OnClose()
    if curPageIndex then
        this.PageList[tabs[curPageIndex].tabIndex]:OnHide()
        this.PageList[tabs[curPageIndex].tabIndex].gameObject:SetActive(false)
    end
end

--界面销毁时调用（用于子类重写）
function DynamicActivityPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    -- 清除红点
    this.ClearPageRedpot()
    -- 这里管理全部子界面的销毁，保证子界面生命周期完整
    for _, page in pairs(this.PageList) do
        if page.OnDestroy then
            page:OnDestroy()
        end
    end
end

-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    local img = Util.GetGameObject(tab, "icon"):GetComponent("Image")
    local lock = Util.GetGameObject(tab, "lock")
    local redpot = Util.GetGameObject(tab, "redPoint")
    local selected = Util.GetGameObject(tab, "selected")

    img.sprite = Util.LoadSprite(tabs[index].default)
    Util.GetGameObject(selected, "icon"):GetComponent("Image").sprite = Util.LoadSprite(tabs[index].select)
    selected:SetActive(status == "select")
    local islock = status == "lock"
    Util.SetGray(img.gameObject, islock)
    lock:SetActive(islock)

    -- 判断是否需要检测红点
    redpot:SetActive(false)
    if not islock then
        this.ClearPageRedpot(index)
        this.BindPageRedpot(index, redpot)
    end
    local id = ActivityGiftManager.IsActivityTypeOpen(tabs[index].ActType)
    if id and id > 0 and ActivityGiftManager.IsQualifiled(tabs[index].ActType) then
        --主题活动  
        if GlobalActConfig[id].Type == ActivityTypeDef.DynamicAct then
            if GlobalActConfig[id].ShowArt and GlobalActConfig[id].ShowArt > 0 then
                tab:SetActive(GlobalActConfig[id].ShowArt == tabs[index].Id)
            end
        --限时兑换
        elseif GlobalActConfig[id].Type == ActivityTypeDef.LimitExchange then
            tab.gameObject:SetActive(false)
        --累计充值
        elseif GlobalActConfig[id].Type == ActivityTypeDef.AccumulativeRechargeExper then
            if GlobalActConfig[id] and GlobalActConfig[id].ShowArt ~= 1 then
                tab.gameObject:SetActive(true)
            else
                tab.gameObject:SetActive(false)
            end
        elseif GlobalActConfig[id].Type == ActivityTypeDef.DynamicAct_recharge then
            tab.gameObject:SetActive(true)
        end
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
    if tabs[index].ActType == ActivityTypeDef.Celebration then
        if PlayerManager.familyId == 0 then
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.SheJiCheckGuild)
            return
        end
    end
    curPageIndex = index

    for i = 1, #this.PageList do
        if this.PageList[i] then
            this.PageList[i]:OnHide()
            this.PageList[i].gameObject:SetActive(false)
        end
    end
    this.PageList[tabs[index].tabIndex].gameObject:SetActive(true)
    this.PageList[tabs[index].tabIndex]:OnShow(this.sortingOrder, this, tabs[index].ActType)
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = tabs[index].panelType })
end

-- 绑定数据
local _PageBindData = {}
local _TabBindData = {}
function this.BindPageRedpot(page, redpot)
    local rpType = tabs[page].rpType
    if not rpType then return end
    BindRedPointObject(rpType, redpot)
    _PageBindData[rpType] = redpot
end
function this.ClearPageRedpot(page)
    -- 清除红点绑定
    if page then    -- 清除某个
        local rpType = tabs[page].rpType
        if not rpType then return end
        ClearRedPointObject(rpType, _PageBindData[rpType])
        _PageBindData[rpType] = nil
    else    -- 全部清除
        for rpt, redpot in pairs(_PageBindData) do
            ClearRedPointObject(rpt, redpot)
        end
        _PageBindData = {}
    end
end

--初始化tab信息
function this.InitTabs()
    tabs = {}
    for i, v in ipairs(AcitvityShowTheme) do
        table.insert(tabs, {
            Id = v.Id,
            default = GetPictureFont(v.TabDefault),
            lock = v.TabLock,
            select = GetPictureFont(v.TabSelect),
            rpType = RedPointType.DynamicActTask,
            panelType = PanelType.Main,
            ActType = ActivityTypeDef.DynamicAct,
            tabIndex = 1,
        })
    end
    --次元引擎
    table.insert(tabs, {
        Id = 40,
        default = GetPictureFont("cn2-X1_zhutihuodong_yeqian_01"),
        lock = "cn2-X1_tongyong_suo",
        select = GetPictureFont("cn2-X1_zhutihuodong_yeqianxuanzhong_01"),
        rpType = RedPointType.Celebration,
        panelType = PanelType.Celebration,
        ActType = ActivityTypeDef.Celebration,
        tabIndex = 2,
    })
    --厄里斯魔镜
    table.insert(tabs, {
        Id = 41,
        default = GetPictureFont("cn2-X1_zhutihuodong_yeqian_02"),
        lock = "cn2-X1_tongyong_suo",
        select = GetPictureFont("cn2-X1_zhutihuodong_yeqianxuanzhong_02"),
        rpType = RedPointType.YiJingBaoKu,
        panelType = PanelType.YiJingBaoKu,
        ActType = ActivityTypeDef.YiJingBaoKu,
        tabIndex = 9,
    })

    local type = PanelType.Main
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    if activityId then
        local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting, "ActivityId", activityId)
        local d = G_LotterySetting[array[1].Id].CostItem[1][1]
        type = {d, 16}
    end
    --限时召唤
    table.insert(tabs, {
        Id = 42,
        default = GetPictureFont("cn2-X1_wmsr_yeqian_03"),
        lock = "cn2-X1_tongyong_suo",
        select = GetPictureFont("cn2-X1_wmsr_yeqian_010"),
        rpType = RedPointType.TimeLimited,
        panelType = type,
        ActType = ActivityTypeDef.FindFairy,
        tabIndex = 3,
    })
    --神秘盲盒
    table.insert(tabs, {
        Id = 43,
        default = GetPictureFont("cn2-X1_wmsr_yeqian_04"),
        lock = "cn2-X1_tongyong_suo",
        select = GetPictureFont("cn2-X1_wmsr_yeqian_08"),
        rpType = RedPointType.QianKunBox,
        panelType = PanelType.QianKunBox,
        ActType = ActivityTypeDef.QianKunBox,
        tabIndex = 4,
    })
    --秘境探索
    table.insert(tabs, {
        Id = 44,
        default = GetPictureFont("cn2-X1_wmsr_yeqian_01"),
        lock = "cn2-X1_tongyong_suo",
        select = GetPictureFont("cn2-X1_wmsr_yeqian_07"),
        rpType = 0,
        panelType = PanelType.Main,
        ActType = ActivityTypeDef.DynamicAct_Treasure,
        tabIndex = 5,
    })
    --累计充值
    table.insert(tabs, {
        Id = 46,
        default = GetPictureFont("cn2-X1_wmsr_yeqian_02"),
        lock = "cn2-X1_tongyong_suo",
        select = GetPictureFont("cn2-X1_wmsr_yeqian_09"),
        rpType = RedPointType.DynamicActRecharge,
        panelType = PanelType.Main,
        ActType = ActivityTypeDef.DynamicAct_recharge,
        tabIndex = 6,
    })
    --位面商人
    table.insert(tabs, {
        Id = 47,
        default = GetPictureFont("cn2-X1_wmsr_yeqian_05"),
        lock = "cn2-X1_tongyong_suo",
        select = GetPictureFont("cn2-X1_wmsr_yeqian_06"),
        rpType = 0,
        panelType = PanelType.Main,
        ActType = ActivityTypeDef.DynamicAct_TimeLimitShop,
        tabIndex = 7,
    })
end

return this