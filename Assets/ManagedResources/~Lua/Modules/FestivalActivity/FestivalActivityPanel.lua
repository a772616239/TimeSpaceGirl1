require("Base/BasePanel")
local FestivalActivityPanel = Inherit(BasePanel)
local this = FestivalActivityPanel
-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local GlobalActConfig = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local _CurPageIndex  =1
local orginLayer
local tabs = {
    [1] = {     --圣诞活动
    default = "N1_btn_zhuangzhilingyun_huandushengdan", lock = "N1_btn_zhuangzhilingyun_huandushengdan", select = "N1_btn_zhuangzhilingyun_huandushengdanxuanzhong",--N1
    rpType = RedPointType.DynamicActTask,panelType = PanelType.Main,ActType = ActivityTypeDef.FestivalActivity
    },
    [2] = {     --第四周 叱咤风云
    default = "N1_btn_zhuangzhilingyun_shengdanhaoli", lock = "N1_btn_zhuangzhilingyun_shengdanhaoli", select = "N1_btn_zhuangzhilingyun_shengdanhaolixuanzhong",--N1
    rpType = RedPointType.DynamicActTask,panelType = PanelType.Main,ActType = ActivityTypeDef.FestivalActivity_recharge
    },

}
local _PageInfo = {--后期可以做成tableInsert，icon名字都去读表
    [1] = 1,--圣诞活动
    [2] = 2,--第四周 叱咤风云
}
local curActivityCount = {
    [1] = require("Modules/FestivalActivity/FestivalDynamicTaskPage"),
    [2] = require("Modules/FestivalActivity/FestivalStorePage"),
}

--初始化组件（用于子类重写）
function FestivalActivityPanel:InitComponent()
    orginLayer = 0
    -- this.mask = Util.GetGameObject(self.gameObject,"mask")
    -- this.mask:SetActive(false)
    this.tabbox = Util.GetGameObject(self.gameObject, "bg/tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.content = Util.GetGameObject(self.gameObject, "bg/pageContent")
    this.tabList = Util.GetGameObject(self.gameObject,"bg/tabbox")
    this.bottomBar = Util.GetGameObject(self.gameObject,"bg/bottomBar")
    this.PageList = {}
    for i=1,#curActivityCount do
        this.PageList[i] = curActivityCount[i].new(self, Util.GetGameObject(self.transform, "bg/pageContent/Festivalpage"..i),this.UpView)
    end
    -- 上部货币显示
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})
    -- 初始化Tab管理器
    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)
    this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.transform)
end
--绑定事件（用于子类重写）
function FestivalActivityPanel:BindEvent()
    
    -- 关闭界面打开主城
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)

end

--添加事件监听（用于子类重写）
function FestivalActivityPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivityBtn)
    for i = 1, #this.PageList do
        if this.PageList[i] then
            this.PageList[i]:AddListener()
        end
    end
end
--移除事件监听（用于子类重写）
function FestivalActivityPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivityBtn)
    for i = 1, #this.PageList do
        if this.PageList[i] then
            this.PageList[i]:RemoveListener()
        end
    end
end

this.RefreshActivityBtn = function()
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FestivalActivity) then
        this:ClosePanel()
    end
end

--界面打开时调用（用于子类重写）
function FestivalActivityPanel:OnOpen(chooseIndex)
    -- 初始化tab数据
    if chooseIndex and chooseIndex ~= ActivityTypeDef.FestivalActivity then
        for i = 1, #tabs do
            if tabs[i].ActType == chooseIndex then
                _CurPageIndex = i
            end
        end
    else
        _CurPageIndex =  chooseIndex or 1
    end
    this.PageTabCtrl:Init(this.tabbox, tabs,_CurPageIndex)
end

-- 打开，重新打开时回调
function FestivalActivityPanel:OnShow()
    
    SoundManager.PlayMusic(SoundConfig.BGM_Main)
    
    local activiytId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FestivalActivity) 
    if not activiytId or activiytId <= 0 then
       self:ClosePanel()
    end
    this.btnBack:SetActive(true)
    this.tabList:SetActive(true)
    this.bottomBar:SetActive(true)
    -- this.mask:SetActive(false)
    if _CurPageIndex and _CurPageIndex == 1 then
        local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FestivalActivity)
        _CurPageIndex = GlobalActConfig[id].ShowArt
        this.PageTabCtrl:ChangeTab(_CurPageIndex)
    elseif _CurPageIndex then
        this.PageTabCtrl:ChangeTab(_CurPageIndex)
    end
    this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.MainCity })
end

----==========================一级页签相关===========================================
-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    local img = Util.GetGameObject(tab, "img"):GetComponent("Image")
    local lock = Util.GetGameObject(tab, "lock")
    local redpot = Util.GetGameObject(tab, "redpot")

    img.sprite = Util.LoadSprite(tabs[index][status])
    img:SetNativeSize()
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
    if id and id > 0  and ActivityGiftManager.IsQualifiled(tabs[index].ActType) then     
        if GlobalActConfig[id].Type == ActivityTypeDef.FestivalActivity then
            if GlobalActConfig[id].ShowArt and GlobalActConfig[id].ShowArt > 0 then
                tab:SetActive(GlobalActConfig[id].ShowArt == index)
            end
        --限时兑换特殊处理
        elseif GlobalActConfig[id].Type == ActivityTypeDef.LimitExchange then
            tab.gameObject:SetActive(GlobalActConfig[id].ShowArt ~= 1)

        --累计充值特殊处理
        elseif GlobalActConfig[id].Type == ActivityTypeDef.AccumulativeRechargeExper then
            if GlobalActConfig[id] and GlobalActConfig[id].ShowArt ~= 1 then
                tab.gameObject:SetActive(true)
            else
                tab.gameObject:SetActive(false)
            end
        elseif GlobalActConfig[id].Type == ActivityTypeDef.FestivalActivity_recharge then
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
    if index==40 then
        if PlayerManager.familyId == 0 then
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.SheJiCheckGuild)
            return
        end
    end
    _CurPageIndex = index
    -- this.mask:SetActive(false)
    for i = 1, #this.PageList do
        if this.PageList[i] then
            this.PageList[i]:OnHide()
            this.PageList[i].gameObject:SetActive(false)
        end
    end
    this.PageList[_PageInfo[index]].gameObject:SetActive(true)
    this.PageList[_PageInfo[index]]:OnShow(this.sortingOrder,this,tabs[index].ActType)
    this.PageList[_PageInfo[index]].gameObject:SetActive(true)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType =  tabs[index].panelType })
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

--界面关闭时调用（用于子类重写）
function FestivalActivityPanel:OnClose()
    if _CurPageIndex then
        this.PageList[_PageInfo[_CurPageIndex]]:OnHide()
        this.PageList[_PageInfo[_CurPageIndex]].gameObject:SetActive(false)
    end
end
--界面销毁时调用（用于子类重写）
function FestivalActivityPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    -- 清除红点
    this.ClearPageRedpot()
    -- 这里管理全部子界面的销毁，保证子界面生命周期完整
    for _, page in pairs(this.PageList) do
        if page.OnDestroy then
            page:OnDestroy()
        end
    end
    SubUIManager.Close(this.BtView)
end
return this