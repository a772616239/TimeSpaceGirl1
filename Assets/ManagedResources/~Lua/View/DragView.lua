DragView={}
local this = DragView
local IsScrollMouse=true
function DragView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform

    setmetatable(b, { __index = DragView })
    return b
end

--初始化组件（用于子类重写）
function this:InitComponent()
    self.triggerEnabled = true
    self.trigger = Util.GetEventTriggerListener(self.gameObject)
    self.trigger.onPointerDown = self.trigger.onPointerDown + function (p,d) self:OnPointerDown(p,d) end
    self.trigger.onPointerUp = self.trigger.onPointerUp + function (p,d) self:OnPointerUp(p,d) end
    self.trigger.onBeginDrag = self.trigger.onBeginDrag + function (p,d) self:OnBeginDrag(p,d) end
    self.trigger.onDrag = self.trigger.onDrag + function (p,d) self:OnDrag(p,d) end
    self.trigger.onEndDrag = self.trigger.onEndDrag + function (p,d) self:OnEndDrag(p,d) end
    -- self.trigger.onScroll = self.trigger.onScroll + function (p,d) self:OnScrollMouse(p,d) end
end
--绑定事件（用于子类重写）
function this:BindEvent()

end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
    local go = ...
    if go then
        self:SetDragGO(go)
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

function this:SetDragGO(go)
    self.dragGO = go
    self.moveTween = self.dragGO:GetComponent(typeof(UITweenSpring))
    if not self.moveTween then
        self.moveTween = self.dragGO:AddComponent(typeof(UITweenSpring))
    end
    self.moveTween.enabled = false;
    self.moveTween.OnUpdate = function (v2) self:SetPosition(v2) end
    self.moveTween.MomentumAmount = 0.5
    self.moveTween.Strength = 50
    self.points = {}
end

function this:OnPointerDown(Pointgo, data)
    if not self.triggerEnabled then return end
    if not self.dragGO then return end
    data:Use()
    if self.points then
        if data.pointerEnter == self.trigger.gameObject and #self.points < 2 then
            table.insert(self.points, data)
            if #self.points >= 2 then
                self.moveTween.enabled = false
            end
        end
    end
end

function this:OnPointerUp(Pointgo, data)
    if not self.triggerEnabled then return end
    if not self.dragGO then return end
    data:Use()
    if self.points then
        if self.points[1] == data then
            self.points[1] = nil
        elseif self.points[2] == data then
            self.points[2] = nil
        end
    end
end

function this:OnBeginDrag(Pointgo, data)
    if not self.triggerEnabled then return end
    if not self.dragGO then return end
    if self.points then
        if #self.points <= 1 then
            if self.points[1] == data then
                self.moveTween.enabled = true
                self.moveTween.Momentum = Vector3.zero
                self.moveTween.IsUseCallBack = false
            end
        end
    end
    data:Use()
end

function this:OnDrag(Pointgo, data)
    if not self.triggerEnabled then return end
    if not self.dragGO then return end
    if self.points then
        if self.points[1] == data or self.points[2] == data then
            if #self.points >= 2 then --双点缩放
                -- local distance = Vector2.Distance(self.points[1].position, self.points[2].position)
                -- local distance1 = Vector2.Distance(self.points[1].pressPosition, self.points[2].pressPosition)
                -- if distance1 <= 0 then
                --     return
                -- end
                -- self:SetScale((distance1 - distance) / Screen.width / 10)
            else --单点移动
                self.moveTween:LerpMomentum(data.delta)
                self:SetPosition(data.delta)
            end
        end
    end
    data:Use()
end

function this:OnEndDrag(Pointgo, data)
    if not self.triggerEnabled then return end
    if not self.dragGO then return end
    if self.points then
        if #self.points == 0 then --移动增加缓动效果
            self:SetPosition(data.delta)
            self.moveTween.IsUseCallBack = true
        elseif #self.points == 1 then --限定缩放范围
        end

    end
    data:Use()
end

function this:OnScrollMouse(Pointgo, data)
    if not self.triggerEnabled then return end
    if IsScrollMouse==false then return end
    if not self.dragGO then return end
    local tran = self.dragGO.transform
    tran.localScale = Vector3.New(math.clamp(tran.localScale.x + data.scrollDelta.y/10, 0.1, 1),
            math.clamp(tran.localScale.y + data.scrollDelta.y/10, 0.1, 1),
            tran.localScale.z)
end

--设置鼠标滑动
function this:SetScrollMouse(b)
    IsScrollMouse=b
end

function this:SetPosition(v2)
    local av2 = self.dragGO:GetComponent("RectTransform").anchoredPosition
    self.dragGO:GetComponent("RectTransform").anchoredPosition = av2 + Vector2.New(v2.x, v2.y)
end

function this:SetScale(scale)
    local tran = self.dragGO.transform
    tran.localScale = Vector3.New(math.clamp(tran.localScale.x - scale, 0.1, 1),
            math.clamp(tran.localScale.y - scale, 0.1, 1),
            tran.localScale.z)
end

--> SetEnabled
function this:SetEnabled(v)
    self.triggerEnabled = v
end

return this