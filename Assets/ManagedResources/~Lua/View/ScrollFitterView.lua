ScrollFitterView = {}
local this = ScrollFitterView
local fitterV2=0
local function SetUpdate(self, index, item)
    item.isUsed = true
    if not item.isActive then
        item.isActive = true
        item.go:SetActive(true)
    end
    self.updateFunc(index, item.go)
    self.goItemDataRefList[item.go] = index
    if self.dragType == 1 then
        item.offset = LayoutUtility.GetPreferredHeight(item.tran) + self.spacing
    else
        item.offset = LayoutUtility.GetPreferredWidth(item.tran) + self.spacing
    end
end

local function CreateItem(self)
    if self.usedItemCount < #self.goItemList then
        for i=1, #self.goItemList do
            if not self.goItemList[i].isUsed then
                self.usedItemCount=self.usedItemCount+1
                return self.goItemList[i]
            end
        end
    end
    local item = {go=nil, tran=nil, isActive=false, isUsed=false, pre=nil, next=nil, offset=0, pos=0}
    local go = newObject(self.item)
    go.name = "item"..#self.goItemList+1
    go.transform:SetParent(self.dragGO.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero

    local tran = go:GetComponent("RectTransform")
    local v2 = self.dragType == 1 and Vector2.New(0.5, 1) or Vector2.New(0, 0.5)
    tran.anchorMin = v2
    tran.anchorMax = v2
    tran.pivot = v2

    item.go = go
    item.tran = tran
    table.insert(self.goItemList, item)
    self.goItemDataRefList[go] = #self.goItemList
    self.usedItemCount=self.usedItemCount+1
    return item
end

local function SetItemPos(self, item, pos)
    item.tran.anchoredPosition = pos
    item.pos = self.dragType == 1 and pos.y or pos.x
end

local function SetPosition(self, dv2)
    dv2 = self.dragType == 1 and Vector2.New(0, dv2.y) or Vector2.New(dv2.x, 0)
    local fv2 = self.dragGOTran.anchoredPosition + dv2
    self.dragGOTran.anchoredPosition = fv2

    local r = self.firstCellItem
    local l = self.lastCellItem
    local temp
    if self.dragType == 1 then
        if dv2.y > 0 then
            while self.offsetIndex + self.usedItemCount < self.dataCount and
                    -fv2.y < r.next.pos - r.next.offset do
                temp = r.next
                self.offsetIndex = self.offsetIndex + 1
                SetUpdate(self, self.offsetIndex + self.usedItemCount, temp)
                SetItemPos(self, temp, l.pre.tran.anchoredPosition - Vector2.New(0, l.pre.offset))

                r.next = temp.next
                temp.next.pre = r
                temp.pre = l.pre
                l.pre.next = temp
                temp.next = l
                l.pre = temp
            end
            while self.offsetIndex + self.usedItemCount < self.dataCount and
                    l.pre.pos - l.pre.offset > -fv2.y-self.scrollSize do
                local item = CreateItem(self)
                SetUpdate(self, self.offsetIndex + self.usedItemCount, item)
                SetItemPos(self, item, l.pre.tran.anchoredPosition - Vector2.New(0, l.pre.offset))

                item.pre = l.pre
                l.pre.next = item
                l.pre = item
                item.next = l
            end
        elseif dv2.y < 0 then
            while self.offsetIndex > 0 and -self.scrollSize-fv2.y > l.pre.pos do
                temp = l.pre
                SetUpdate(self, self.offsetIndex, temp)
                self.offsetIndex = self.offsetIndex - 1
                SetItemPos(self, temp, r.next.tran.anchoredPosition + Vector2.New(0, temp.offset))

                l.pre = temp.pre
                temp.pre.next = l
                temp.next = r.next
                r.next.pre = temp
                temp.pre = r
                r.next = temp
            end
            while self.offsetIndex > 0 and fv2.y < -r.next.pos do
                local item = CreateItem(self)
                SetUpdate(self, self.offsetIndex, item)
                self.offsetIndex = self.offsetIndex - 1
                SetItemPos(self, item, r.next.tran.anchoredPosition + Vector2.New(0, item.offset))

                item.next = r.next
                r.next.pre = item
                r.next = item
                item.pre = r
            end
        end
    else
        if dv2.x < 0 then
            while self.offsetIndex + self.usedItemCount < self.dataCount and
                    fv2.x < -r.next.offset - r.next.pos do
                temp = r.next
                self.offsetIndex = self.offsetIndex + 1
                SetUpdate(self, self.offsetIndex + self.usedItemCount, temp)
                SetItemPos(self, temp, l.pre.tran.anchoredPosition + Vector2.New(l.pre.offset, 0))

                r.next = temp.next
                temp.next.pre = r
                temp.pre = l.pre
                l.pre.next = temp
                temp.next = l
                l.pre = temp
            end
            while self.offsetIndex + self.usedItemCount < self.dataCount and
                    l.pre.pos + l.pre.offset < -fv2.x+self.scrollSize do
                local item = CreateItem(self)
                SetUpdate(self, self.offsetIndex + self.usedItemCount, item)
                SetItemPos(self, item, l.pre.tran.anchoredPosition + Vector2.New(l.pre.offset, 0))

                item.pre = l.pre
                l.pre.next = item
                l.pre = item
                item.next = l
            end
        elseif dv2.x > 0 then
            while self.offsetIndex > 0 and fv2.x-self.scrollSize > -l.pre.pos do
                temp = l.pre
                SetUpdate(self, self.offsetIndex, temp)
                self.offsetIndex = self.offsetIndex - 1
                SetItemPos(self, temp, r.next.tran.anchoredPosition - Vector2.New(temp.offset, 0))

                l.pre = temp.pre
                temp.pre.next = l
                temp.next = r.next
                r.next.pre = temp
                temp.pre = r
                r.next = temp
            end
            while self.offsetIndex > 0 and fv2.x > -r.next.pos do
                local item = CreateItem(self)
                SetUpdate(self, self.offsetIndex, item)
                self.offsetIndex = self.offsetIndex - 1
                SetItemPos(self, item, r.next.tran.anchoredPosition - Vector2.New(item.offset, 0))

                item.next = r.next
                r.next.pre = item
                r.next = item
                item.pre = r
            end
        end
    end

    if not self.elastic then
        local first = r.next
        local last = l.pre
        if self.dragType == 1 then
            if -fv2.y > first.pos then
                fv2.y = -first.pos
            else
                if first.pos-last.pos+last.offset < self.scrollSize then
                    fv2.y = -first.pos
                else
                    local itemDis = last.pos-last.offset+self.spacing
                    if -fv2.y-self.scrollSize < itemDis then
                        fv2.y = -itemDis-self.scrollSize
                    end
                end
            end
        elseif self.dragType == 2 then
            if fv2.x > -first.pos then
                fv2.x = -first.pos
            else
                if last.pos+last.offset-first.pos < self.scrollSize then
                    fv2.x = -first.pos
                else
                    local itemDis = last.pos+last.offset-self.spacing
                    if -fv2.x+self.scrollSize > itemDis then
                        fv2.x = -itemDis+self.scrollSize
                    end
                end
            end
        end
        self.dragGOTran.anchoredPosition = fv2
    end
end

local function OnBeginDrag(self, Pointgo, data)
    if not self.dataList then return end
    self.moveTween.enabled = true
    self.moveTween.Momentum = Vector3.zero
    self.moveTween.IsUseCallBack = false
    data:Use()
end

local function OnDrag(self, Pointgo, data)
    if not self.dataList then return end
    self.moveTween:LerpMomentum(data.delta)
    SetPosition(self, data.delta)
    data:Use()
end

local function OnEndDrag(self, Pointgo, data)
    if not self.dataList then return end
    SetPosition(self, data.delta)
    self.moveTween.IsUseCallBack = true
    data:Use()
end

local function OnMoveEnd(self)
    local fv2 = self.dragGOTran.anchoredPosition
    local first = self.firstCellItem.next
    local last = self.lastCellItem.pre
    if self.dragType == 1 then
        if -fv2.y > first.pos then
            self.tmpTween = self.dragGOTran:DOAnchorPosY(-first.pos,0.3,false)
        else
            if first.pos-last.pos+last.offset < self.scrollSize then
                self.tmpTween = self.dragGOTran:DOAnchorPosY(-first.pos,0.3,false)
            else
                local itemDis = last.pos-last.offset+self.spacing
                if -fv2.y-self.scrollSize < itemDis then
                    self.tmpTween = self.dragGOTran:DOAnchorPosY(-itemDis-self.scrollSize,0.3,false)
                end
            end
        end
    elseif self.dragType == 2 then
        if fv2.x > -first.pos then
            self.tmpTween = self.dragGOTran:DOAnchorPosX(-first.pos,0.3,false)
        else
            if last.pos+last.offset-first.pos < self.scrollSize then
                self.tmpTween = self.dragGOTran:DOAnchorPosX(-first.pos,0.3,false)
            else
                local itemDis = last.pos+last.offset-self.spacing
                if -fv2.x+self.scrollSize > itemDis then
                    self.tmpTween = self.dragGOTran:DOAnchorPosX(-itemDis+self.scrollSize,0.3,false)
                end
            end
        end
    end
end

function ScrollFitterView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b,{ __index = ScrollFitterView })
    return b
end

--初始化组件（用于子类重写）
function ScrollFitterView:InitComponent()
    self.trigger = Util.GetEventTriggerListener(self.gameObject)
    self.trigger.onBeginDrag = self.trigger.onBeginDrag + function (p,d) OnBeginDrag(self,p,d) end
    self.trigger.onDrag = self.trigger.onDrag + function (p,d) OnDrag(self,p,d) end
    self.trigger.onEndDrag = self.trigger.onEndDrag + function (p,d) OnEndDrag(self,p,d) end

    self.rectTransform = self.gameObject:GetComponent("RectTransform")
    self.dragGO = Util.GetGameObject(self.gameObject, "grid")
    self.dragGOTran = self.dragGO:GetComponent("RectTransform")

    self.moveTween = self.dragGO:AddComponent(typeof(UITweenSpring))
    self.moveTween.enabled = false
    self.moveTween.OnUpdate = function (v2) 
        fitterV2=v2
        SetPosition(self,v2) 
    end
    self.moveTween.OnMoveEnd = function () OnMoveEnd(self) end
    self.moveTween.MomentumAmount = 0.5 --拖动灵敏度（越大越灵敏）
    self.moveTween.Strength = 8 --滑动阻力（越大阻力越大）
    
    self.elastic = true --支持超框拖动
end

--绑定事件（用于子类重写）
function ScrollFitterView:BindEvent()
end

--添加事件监听（用于子类重写）
function ScrollFitterView:AddListener()
end

--移除事件监听（用于子类重写）
function ScrollFitterView:RemoveListener()
end

--界面关闭时调用（用于子类重写）
function ScrollFitterView:OnClose()
end

--界面销毁时调用（用于子类重写）
function ScrollFitterView:OnDestroy()
end

--界面打开时调用（用于子类重写）
function ScrollFitterView:OnOpen(itemGO, scrollSizeDeltaV2, dragType, spacing)
    self.item = itemGO --关联的预设
    self.rectTransform.sizeDelta = scrollSizeDeltaV2 --滚动界面大小
    self.dragType = dragType  --1 竖 2 横
    self.spacing = spacing --左右，上下间距
    self.scrollSize = dragType == 1 and scrollSizeDeltaV2.y or scrollSizeDeltaV2.x

    local v2 = self.dragType == 1 and Vector2.New(0.5, 1) or Vector2.New(0, 0.5)
    self.dragGOTran.anchorMin = v2
    self.dragGOTran.anchorMax = v2
    self.dragGOTran.pivot = v2

    self.firstCellItem = {next=nil, tran=self.dragGOTran, offset=0, pos=0}
    self.lastCellItem = {pre=nil}
    self.firstCellItem.next = self.lastCellItem
    self.lastCellItem.pre = self.firstCellItem
    self.offsetIndex = 0

    self.goItemList = {}
    self.goItemDataRefList = {}
    self.usedItemCount = 0
end

function this:SetData(dataList, updateFunc, startIndex)
  
    self.dataList = dataList --传入的数据列表

    self.updateFunc = updateFunc --刷新回调，返回数据列表的索引和对应预设
    self.dataCount = #dataList

    self:SetIndex(startIndex or self.offsetIndex+1) --设置初始索引，若为空则默认为上一次索引
end

function this:ForeachItemGO(func)
    if not func or not self.goItemList then return end
    for i=1, math.min(#self.goItemList, self.dataCount) do
        func(i, self.goItemList[i].go)
    end
end

--设置当前索引位置在最上层
function this:SetIndex(curIndex)
    if self.dataCount == 0 then
        for i=1, #self.goItemList do
            self.goItemList[i].isUsed = false
            self.goItemList[i].isActive = false
            self.goItemList[i].go:SetActive(false)
        end
        self.dataList = nil
        return
    end
    if self.tmpTween then
        self.tmpTween:Kill()
        self.tmpTween = nil
    end

    self.dragGOTran.anchoredPosition = Vector2.New(0, 0)
    self.offsetIndex = curIndex-1
    self.usedItemCount=0

    for i=1, #self.goItemList do
        self.goItemList[i].isUsed = false
    end
    local index = self.firstCellItem
    while curIndex+self.usedItemCount<=self.dataCount do
        local item = CreateItem(self)
        index.next = item
        item.pre = index
        index = item
        SetUpdate(self, self.offsetIndex+self.usedItemCount, item)
        if self.dragType == 1 then
            SetItemPos(self, item, item.pre.tran.anchoredPosition - Vector2.New(0, item.pre.offset))
            if item.pos-item.offset<=-self.scrollSize then
                break
            end
        else
            SetItemPos(self, item, item.pre.tran.anchoredPosition + Vector2.New(item.pre.offset, 0))
            if item.pos+item.offset>=self.scrollSize then
                break
            end
        end
    end
    index.next = self.lastCellItem
    self.lastCellItem.pre = index

    if self.offsetIndex > 0 then
        local last = self.lastCellItem
        local first = self.firstCellItem
        if self.dragType == 1 then
            local itemDis = last.pre.pos-last.pre.offset+self.spacing
            if -self.scrollSize < itemDis then
                SetPosition(self, Vector2.New(0, -itemDis-self.scrollSize))
                itemDis = first.next.pos-last.pre.pos+last.pre.offset-self.spacing
                if itemDis < self.scrollSize then
                    self.dragGOTran.anchoredPosition = Vector2.New(0,-first.next.pos)
                end
            end
        else
            local itemDis = last.pre.pos+last.pre.offset-self.spacing
            if self.scrollSize > itemDis then
                SetPosition(self, Vector2.New(-itemDis+self.scrollSize, 0))
                itemDis = last.pre.pos+last.pre.offset-first.next.pos-self.spacing
                if itemDis < self.scrollSize then
                    self.dragGOTran.anchoredPosition = Vector2.New(-first.next.pos,0)
                end
            end
        end
    end
    for i=1, #self.goItemList do
        if not self.goItemList[i].isUsed then
            self.goItemList[i].isActive = false
            self.goItemList[i].go:SetActive(false)
        end
    end
end

--通过item预设获取关联的数据项索引
function this:GetItemDataIndex(go)
    return self.goItemDataRefList[go]
end
function this:GetOffset()
	return self.dragGOTran.anchoredPosition
end
function this:GetOffsetV2()
    return fitterV2
end

function this:SetOffset(offset,v2Data)
	self.dragGOTran.anchoredPosition = offset
    SetPosition(self,v2Data)
end

return ScrollFitterView