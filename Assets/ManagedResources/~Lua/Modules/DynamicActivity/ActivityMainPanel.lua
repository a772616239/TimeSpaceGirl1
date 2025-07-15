require("Base/BasePanel")
local ActivityMainPanel = Inherit(BasePanel)
local this = ActivityMainPanel
-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local GlobalActConfig = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local _CurPageIndex = 0
local orginLayer
local redPointTypeList = {}
local tabs = {}
local subViewList = {}
--初始化组件（用于子类重写）
function ActivityMainPanel:InitComponent()
    orginLayer = 0
    this.mask = Util.GetGameObject(self.gameObject,"mask")
    this.mask:SetActive(false)
    this.tabbox = Util.GetGameObject(self.gameObject, "bg/tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.content = Util.GetGameObject(self.gameObject, "bg/pageContent")
    this.upView = SubUIManager.Open(SubUIConfig.UpView,self.gameObject.transform)
end

--绑定事件（用于子类重写）
function ActivityMainPanel:BindEvent()
    -- 初始化Tab管理器
    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)

    -- 关闭界面打开主城
    Util.AddClick(this.btnBack, function()
        DynamicActivityManager.RemoveUIList()
        if #DynamicActivityManager.OpenUIList > 0 then
            JumpManager.GoJump(DynamicActivityManager.OpenUIList[#DynamicActivityManager.OpenUIList],function()
                DynamicActivityManager.RemoveUIList()
            end)
        else
            this:ClosePanel()
        end     
    end)
end

--添加事件监听（用于子类重写）
function ActivityMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose, this.OnShow)
end

--移除事件监听（用于子类重写）
function ActivityMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose, this.OnShow)
end

--界面打开时调用（用于子类重写）
function ActivityMainPanel:OnOpen(_activityType,_index)
    this.activityType = _activityType
    _CurPageIndex = _index
    DynamicActivityManager.curActivityType = this.activityType
    tabs = DynamicActivityManager.GetActivityTableDataByPageInde(this.activityType)
end

-- 打开，重新打开时回调
function ActivityMainPanel:OnShow()
    orginLayer = self.sortingOrder
    if _CurPageIndex and _CurPageIndex > #tabs then
        _CurPageIndex = #tabs
    end
    this.PageTabCtrl:Init(this.tabbox.gameObject, tabs,_CurPageIndex)
end

function this:OnSortingOrderChange()
    orginLayer = self.sortingOrder
end
----==========================一级页签相关===========================================
-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    tab.gameObject.name = "tab"..tabs[index].Id
    local img = Util.GetGameObject(tab, "img"):GetComponent("Image")
    local lock = Util.GetGameObject(tab, "lock")
    local redpot = Util.GetGameObject(tab, "redpot")
    if status == "lock" then
        lock.gameObject:SetActive(true)
        Util.SetGray(tab.gameObject, true)
    else
        Util.SetGray(tab.gameObject, false)
        lock.gameObject:SetActive(false)
    end
    --设置红点
    redpot.gameObject:SetActive(false)
    if status ~= "lock" then
        if redPointTypeList[tabs[index].RpType] then
            ClearRedPointObject(tabs[index].RpType,redPointTypeList[tabs[index].RpType])
            redPointTypeList[tabs[index].RpType] = nil
        end
        if not tabs[index].RpType or tabs[index].RpType < 1 then
            redpot.gameObject:SetActive(false)
        else           
            BindRedPointObject(tabs[index].RpType,redpot)
            redPointTypeList[tabs[index].RpType] = redpot
        end
    end
    --设置图片
    local sprite = nil
    if tabs[index].ActiveType > 0 then
        local id = ActivityGiftManager.IsActivityTypeOpen(tabs[index].ActiveType)
        if id and id > 0 then                
            local actConfig = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.ActivityGroups,"ActId",id,"PageType",this.activityType,"ActiveType",tabs[index].ActiveType)
            if actConfig then 
                sprite = (status == "select" and actConfig.Icon[2] or actConfig.Icon[1])
            end
        end
    end
    if not sprite then
        sprite = (status == "select" and tabs[index].Icon[2] or tabs[index].Icon[1])
    end  
    img.sprite = Util.LoadSprite(sprite)
    --设置显示隐藏
    if not DynamicActivityManager.IsQualifiled(tabs[index].Id) then
        tab.gameObject:SetActive(false)
        return
    end
    if tabs[index].IsRecharge == 1 and not RECHARGEABLE then
        tab.gameObject:SetActive(false)
        return
    end 
    local isshow = false
    if tabs[index].IfBack == 1 then
        if tabs[index].ActiveType > 0 then
            local id = ActivityGiftManager.IsActivityTypeOpen(tabs[index].ActiveType)
            isshow = id and id > 0 and ActivityGiftManager.IsQualifiled(tabs[index].ActiveType)
        elseif tabs[index].FunType > 0 then
            isshow = ActTimeCtrlManager.SingleFuncState(tabs[index].FunType)
        else
            isshow = true
        end
    else
        if tabs[index].ActiveType > 0 then
            isshow = ActivityGiftManager.IsQualifiled(tabs[index].ActiveType)
        elseif tabs[index].FunType > 0 then
            isshow = ActTimeCtrlManager.IsQualifiled(tabs[index].FunType)
        else
            isshow = true
        end
    end
    tab.gameObject:SetActive(isshow)
end

-- tab 加锁 页签是否需要加锁显示
function this.PageTabIsLockCheck(index)
    -- --充值 每日礼包页签 需要加锁显示
    -- if tabs[index].ActiveType and tabs[index].ActiveType == 10004 then
    --     if not OperatingManager.HasGoodsByShowType(14) then
    --         return true
    --     end
    -- end
    -- return false
end

-- tab改变事件
function this.OnPageTabChange(index)
    -- if index == _CurPageIndex then
    --     return
    -- end   
    if subViewList[_CurPageIndex] and subViewList[_CurPageIndex].config and subViewList[_CurPageIndex].sub then
        subViewList[_CurPageIndex].sub:OnClose()
    end  
    if subViewList[index] and subViewList[index].config and subViewList[index].sub then
        subViewList[index].sub:OnShow(orginLayer)
    else
        subViewList[index] = {}
        if tabs[index].UIName then
            subViewList[index].config = SubUIConfig[tabs[index].UIName[1]]
            subViewList[index].sub = SubUIManager.Open(subViewList[index].config,this.content.transform,tabs[index],index,this)
            subViewList[index].sub:OnShow(orginLayer)
        end       
    end
    if tabs[index].UpView and #tabs[index].UpView > 0 then
        this.upView:OnOpen({showType = tabs[index].UpView[1][1], panelType = tabs[index].UpView[2] })
        this.upView.gameObject:SetActive(true)
    else
        this.upView.gameObject:SetActive(false)
    end
    DynamicActivityManager.ChangeUIList(tabs[index].Jump)
    _CurPageIndex = index
end


--界面关闭时调用（用于子类重写）
function ActivityMainPanel:OnClose()
    --清除红点   
    for k,v in pairs(redPointTypeList) do
        ClearRedPointObject(k,v)
    end
    redPointTypeList = {}
    --关闭弹窗界面
    for k,v in pairs(subViewList) do
        v.sub:OnDestroy()
        SubUIManager.Close(v.sub) 
    end 
    subViewList = {}
    DynamicActivityManager.curActivityType = 0
    _CurPageIndex = 0
end

--界面销毁时调用（用于子类重写）
function ActivityMainPanel:OnDestroy()
    --清除红点   
    for k,v in pairs(redPointTypeList) do
        ClearRedPointObject(k,v)
    end
    redPointTypeList = {}
    --关闭弹窗界面
    for k,v in pairs(subViewList) do
        --UIManager.ClosePanel(k)
        v.sub:OnDestroy()
        SubUIManager.Close(v.sub)
    end 
    subViewList = {}
    DynamicActivityManager.curActivityType = 0
    tabs = {}
    SubUIManager.Close(this.upView)
    this.upView = nil
    _CurPageIndex = 0
end
return this