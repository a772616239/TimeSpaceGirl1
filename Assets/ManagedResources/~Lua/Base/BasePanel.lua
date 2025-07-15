--- 初次打开流程 Awake->InitComponent->BindEvent->AddListener->OnOpen->OnShow
--- 再次打开流程 AddListener->OnShow

BasePanel = {}
local this = BasePanel
this.isOpened = false
this.game = nil
this.name = nil
this.isPlayAudio = true



--UIManager打开UI时调用（子类不要重写此方法）
function BasePanel:CreateUI(gameObject)
    self.name = gameObject.name
    self.gameObject = gameObject
    self.transform = gameObject.transform
    self.canvas = self.gameObject:GetComponent("Canvas")
    self.openNum = 0
    if self.Awake ~= nil then
        MyPCall(function() self:Awake() end)
    end
    MyPCall(function() self:InitComponent() end)
    MyPCall(function() self:BindEvent() end )
end

--设置渲染层级
function BasePanel:SetSortingOrder(sortingOrder)
    self.sortingOrder = sortingOrder
    self.canvas.overrideSorting = true
    self.canvas.sortingOrder = sortingOrder
    self:OnSortingOrderChange()
end

--UI打开时由UIManager调用（子类不要重写此方法）
function BasePanel:OpenUI(IsBackOpen, ...)
    if not self.isOpened then
        MyPCall(function() self:AddListener() end)
        if self.Update ~= nil then
            UpdateBeat:Add(self.Update, self)
        end
        self.isOpened = true
    end
    --> battlePanelBehind
    if self.uiConfig.name == "BattlePanel" and BattleManager.IsInBackBattle() then
        self:OnOpenCustom()
    else
        if IsBackOpen then
            self:OnShow()
        else
            self:OnOpen(...)
            self:OnShow()
        end
    end
    
    Game.GlobalEvent:DispatchEvent(GameEvent.UI.OnOpen, self.uiConfig.id, self)
    PlayUIAnim(self.gameObject)
end

--UI获得焦点时由UIManager调用（子类不要重写此方法）
function BasePanel:Focus()
    if self.OnFocus then
        self:OnFocus()
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.UI.OnFocus, self.uiConfig.id, self)
end

--UI关闭时由UIManager调用（子类不要重写此方法）
function BasePanel:CloseUI()
    if self.isOpened then
        MyPCall(function() self:RemoveListener() end)
        if self.Update ~= nil then
            UpdateBeat:Remove(self.Update, self)
        end
        self.isOpened = false
    end
    self:OnClose()
    Game.GlobalEvent:DispatchEvent(GameEvent.UI.OnClose, self.uiConfig.id, self)
end

--UI失去焦点时由UIManager调用（子类不要重写此方法）
function BasePanel:LoseFocus()
    if self.OnLoseFocus then
        self:OnLoseFocus()
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.UI.OnLoseFocus, self.uiConfig.id, self)
end

--UI销毁时由UIManager调用（子类不要重写此方法）
function BasePanel:DestroyUI()
    self:OnDestroy()
    Game.GlobalEvent:DispatchEvent(GameEvent.UI.OnDestroy, self.uiConfig.id, self)
end

--关闭面板
--@isPlayAudio:是否播放按钮音效
function BasePanel:ClosePanel()
    if self.uiConfig then
        UIManager.ClosePanel(self.uiConfig.id, false)
    end
end

--销毁面板
--@isPlayAudio:是否播放按钮音效
function BasePanel:DestroyPanel()
    if self.uiConfig then
        UIManager.ClosePanel(self.uiConfig.id, true)
    end
end

--初始化组件（用于子类重写）
function BasePanel:InitComponent()
end

--绑定事件（用于子类重写）
function BasePanel:BindEvent()
end

--添加事件监听（用于子类重写）
function BasePanel:AddListener()
end

--移除事件监听（用于子类重写）
function BasePanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BasePanel:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BasePanel:OnShow(...)
end

function BasePanel:OnOpenCustom()
end

--界面层级发生改变（用于子类重写）
function BasePanel:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function BasePanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function BasePanel:OnDestroy()
end








