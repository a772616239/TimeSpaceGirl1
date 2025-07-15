ScrollCycleView = {}
local this = ScrollCycleView

local reverse = table.reverse

--表循环移动算法
local function move(list, k)
	k = k%#list
	if k == 0 then
		return
	end

	reverse(list, 1, #list-k)
	reverse(list, #list-k+1, #list)
	reverse(list, 1, #list)
end

local function SetUpdate(self, index, item)
	if index <= self.dataCount then
		if not item.isActive then
			item.isActive = true
			item.go:SetActive(true)
		end
		self.updateFunc(index, item.go)
		self.goItemDataRefList[item.go] = index
	else
		if item.isActive then
			item.isActive = false
			item.go:SetActive(false)
		end
	end
end

local function ItemListOffset(self, offset)
	local newIndex, order, round, curRound, go
	for j = 1, self.fixedCount do
		order = math.abs(offset) % self.itemCount --当偏移量超过最大显示数量，进行取余计算，作多轮次偏移
		round = math.floor(math.abs(offset) / self.itemCount)
		if offset > 0 then
			for i = 1, self.itemCount do
				curRound = (i <= order and 1 or 0) + round
				if curRound > 0 then
					newIndex = self.itemCount * curRound + self.dataIndex + i
					go = self.cellItemList[j][i]
					go.tran.anchoredPosition = go.tran.anchoredPosition + self.offsetV2 * curRound
					SetUpdate(self, j + (newIndex - 1) * self.fixedCount, go)
				end
			end
		else
			for i = 1, self.itemCount do
				curRound = (i <= order and 1 or 0) + round
				if curRound > 0 then
					newIndex =  1 - self.itemCount * (curRound - 1) + self.dataIndex - i
					i = self.itemCount - i + 1
					go = self.cellItemList[j][i]
					go.tran.anchoredPosition = go.tran.anchoredPosition - self.offsetV2 * curRound
					SetUpdate(self, j + (newIndex - 1) * self.fixedCount, go)
				end
			end
		end
		move(self.cellItemList[j], -offset)
	end
end

local function SetItemIndex(self, curIndex)
	curIndex = math.clamp(curIndex, 0, self.maxOffset)
	if curIndex ~= self.dataIndex then
		ItemListOffset(self, curIndex - self.dataIndex)
		self.dataIndex = curIndex
	end
end

local function SetPosition(self, dv2)
	local av2 = self.dragGOTran.anchoredPosition
	if self.dragType == 1 then
		dv2.x = 0
	else
		dv2.y = 0
	end
	local fv2 = av2 + dv2
	
	if not self.elastic then
		if self.itemDis > 0 then
			if self.dragType == 1 then
				if fv2.y < 0 or fv2.y > self.itemDis then
					fv2.y = math.clamp(fv2.y, 0, self.itemDis)
				end
			elseif self.dragType == 2 then
				-- if fv2.x < 0 or fv2.x > self.itemDis then
				-- 	fv2.x = math.clamp(-fv2.x, -self.itemDis, 0)
				-- end
				if fv2.x < -self.itemDis or fv2.x > 0 then
					fv2.x = math.clamp(fv2.x, -self.itemDis, 0)
				end
			end
		else
			fv2 = Vector2.zero
		end
	end
	self.dragGOTran.anchoredPosition = fv2
	local curIndex
	if self.dragType == 1 then
		curIndex = math.floor(self.dragGOTran.anchoredPosition.y / self.itemHeight)
		if self.scrollBar then
			self.scrollBar.value = self.dragGOTran.anchoredPosition.y / self.itemDis
		end
	else
		curIndex = math.floor(-self.dragGOTran.anchoredPosition.x / self.itemWidth)
		if self.scrollBar then
			self.scrollBar.value = -self.dragGOTran.anchoredPosition.x / self.itemDis
		end
	end
	SetItemIndex(self, curIndex)

	if self.onUpdate then
		self.onUpdate(self.dragGOTran.anchoredPosition)
	end
end

local dir = 1
local moveDir = 1
local function OnBeginDrag(self, Pointgo, data, scrollType)
	if scrollType == 1 then
		dir = self.dragType
		moveDir = Mathf.Abs(data.delta.x) > Mathf.Abs(data.delta.y) and 2 or 1
		if moveDir ~= dir then
			return
		end
	end

	if self == nil or not self.dataList then return end
	self.moveTween.enabled = true
	self.moveTween.Momentum = Vector3.zero
	self.moveTween.IsUseCallBack = false
	data:Use()
end

local function OnDrag(self, Pointgo, data, scrollType)
	if scrollType == 1 then
		if moveDir ~= dir then
			return
		end
	end
	if scrollType == 2 then
		if moveDir == dir then
			return
		end
	end
	
	if self == nil or not self.dataList then return end
	self.moveTween:LerpMomentum(data.delta)
	SetPosition(self, data.delta)
	data:Use()
end

local function OnEndDrag(self, Pointgo, data, scrollType)
	if scrollType == 1 then
		if moveDir ~= dir then
			return
		end
	end
	if scrollType == 2 then
		if moveDir == dir then
			return
		end
	end
	if self == nil or not self.dataList then return end
	SetPosition(self, data.delta)
	self.moveTween.IsUseCallBack = true
	data:Use()
end

local function OnMoveEnd(self)
	local fv2 = self.dragGOTran.anchoredPosition
	if self.dragType == 1 then
		if self.itemDis < 0 then
			self.tmpTween = self.dragGOTran:DOAnchorPosY(0,0.3,false):OnUpdate(function()
				if self.onUpdate then
					self.onUpdate(self.dragGOTran.anchoredPosition)
				end
			end)
		else
			if fv2.y < 0 and self.dataIndex == 0 then
				self.tmpTween = self.dragGOTran:DOAnchorPosY(0,0.3,false):OnUpdate(function()
					if self.onUpdate then
						self.onUpdate(self.dragGOTran.anchoredPosition)
					end
				end)
			end
			if fv2.y > self.itemDis and self.dataIndex == self.maxOffset then
				self.tmpTween = self.dragGOTran:DOAnchorPosY(self.itemDis,0.3,false):OnUpdate(function()
					if self.onUpdate then
						self.onUpdate(self.dragGOTran.anchoredPosition)
					end
				end)
			end
		end
	elseif self.dragType == 2 then
		if self.itemDis < 0 then
			self.tmpTween = self.dragGOTran:DOAnchorPosX(0,0.3,false)
		else
			if fv2.x > 0 and self.dataIndex == 0 then
				self.tmpTween = self.dragGOTran:DOAnchorPosX(0,0.3,false)
			end
			if fv2.x < -self.itemDis and self.dataIndex == self.maxOffset then
				self.tmpTween = self.dragGOTran:DOAnchorPosX(-self.itemDis,0.3,false)
			end
		end
	end
end

function ScrollCycleView:New(gameObject)
	local b = {}
	b.gameObject = gameObject
	b.transform = gameObject.transform
	setmetatable(b,{ __index = ScrollCycleView })
	return b
end

--初始化组件（用于子类重写）
function ScrollCycleView:InitComponent()
	self.trigger = Util.GetEventTriggerListener(self.gameObject)
	self.trigger.onBeginDrag = self.trigger.onBeginDrag + function (p,d) OnBeginDrag(self,p,d,1) end
	self.trigger.onDrag = self.trigger.onDrag + function (p,d) OnDrag(self,p,d,1) end
	self.trigger.onEndDrag = self.trigger.onEndDrag + function (p,d) OnEndDrag(self,p,d,1) end

	self.trigger.onBeginDrag = self.trigger.onBeginDrag + function (p,d) OnBeginDrag(self.parentScroll,p,d,2) end
	self.trigger.onDrag = self.trigger.onDrag + function (p,d) OnDrag(self.parentScroll,p,d,2) end
	self.trigger.onEndDrag = self.trigger.onEndDrag + function (p,d) OnEndDrag(self.parentScroll,p,d,2) end

	self.rectTransform = self.gameObject:GetComponent("RectTransform")
	self.dragGO = Util.GetGameObject(self.gameObject, "grid")
	self.dragGOTran = self.dragGO:GetComponent("RectTransform")

	self.moveTween = self.dragGO:AddComponent(typeof(UITweenSpring))
	self.moveTween.enabled = false
	self.moveTween.OnUpdate = function (v2) SetPosition(self,v2) end
	self.moveTween.OnMoveEnd = function () OnMoveEnd(self) end
	self.moveTween.MomentumAmount = 0.5 --拖动灵敏度（越大越灵敏）
	self.moveTween.Strength = 1 --滑动阻力（越大阻力越大）

	-- self.picline = Util.GetGameObject(self.gameObject, "picline")
	-- self.picline:SetActive(false)

	self.elastic = true --支持超框拖动
end

--绑定事件（用于子类重写）
function ScrollCycleView:BindEvent()
end

--添加事件监听（用于子类重写）
function ScrollCycleView:AddListener()
end

--移除事件监听（用于子类重写）
function ScrollCycleView:RemoveListener()
end

--界面关闭时调用（用于子类重写）
function ScrollCycleView:OnClose()
end

--界面销毁时调用（用于子类重写）
function ScrollCycleView:OnDestroy()
end

--界面打开时调用（用于子类重写）
function ScrollCycleView:OnOpen(itemGO, scrollBar, scrollSizeDeltaV2, dragType, fixedCount, spacingV2, itemGoScale, onUpdate, parentScroll)
	self.item = itemGO --关联的预设
	self.scrollBar = scrollBar --关联scrollBar组件
	self.rectTransform.sizeDelta = scrollSizeDeltaV2 --滚动界面大小
	self.dragType = dragType  --1 竖 2 横
	self.fixedCount = fixedCount --自动排布的行数或者列数
	self.spacing = spacingV2 --左右，上下间距
	self.onUpdate = onUpdate --< 更新回调函数
	self.parentScroll = parentScroll

	-- -- 缩放适配scroll
	-- local x = itemGO:GetComponent("RectTransform").sizeDelta.x
	-- self.adapterScale = 1
	-- if self.dragType == 1 then
	-- 	local w = x * self.fixedCount + (self.fixedCount + 1) * self.spacing.x
	-- 	if self.rectTransform.sizeDelta.x < w then
	-- 		self.adapterScale = self.rectTransform.sizeDelta.x / w
	-- 	end
	-- else
	-- end
	self.itemGoScale = itemGoScale or 1
	itemGO:GetComponent("RectTransform").localScale = Vector3.one * self.itemGoScale
	itemGO:GetComponent("RectTransform").sizeDelta = 
	Vector2.New(itemGO:GetComponent("RectTransform").sizeDelta.x * self.itemGoScale,
				itemGO:GetComponent("RectTransform").sizeDelta.y * self.itemGoScale)

	self.cellSize = itemGO:GetComponent("RectTransform").sizeDelta

	self.itemWidth = self.spacing.x + self.cellSize.x
	self.itemHeight = self.spacing.y + self.cellSize.y

	if self.dragType == 1 then
		self.dragGOTran.anchorMin = Vector2.New(0.5, 1)
		self.dragGOTran.anchorMax = Vector2.New(0.5, 1)
		self.dragGOTran.pivot = Vector2.New(0.5, 1)
		self.dragGOTran.sizeDelta = Vector2.New(self.itemWidth * (self.fixedCount - 1), 0)

		self.itemCount = math.ceil(scrollSizeDeltaV2.y / self.itemHeight + 1)
		self.offsetV2 = Vector2.New(0, -self.itemHeight * self.itemCount)
	elseif self.dragType == 2 then
		self.dragGOTran.anchorMin = Vector2.New(0, 0.5)
		self.dragGOTran.anchorMax = Vector2.New(0, 0.5)
		self.dragGOTran.pivot = Vector2.New(0, 0.5)
		self.dragGOTran.sizeDelta = Vector2.New(0, self.itemHeight * (self.fixedCount - 1))

		self.itemCount = math.ceil(scrollSizeDeltaV2.x / self.itemWidth + 1)
		self.offsetV2 = Vector2.New(self.itemWidth * self.itemCount, 0)
	end

	self.cellItemList = {}
	for j = 1, self.fixedCount do
		local itemList = {}
		for i = 1, self.itemCount do
			itemList[i] = {go = nil, tran = nil, isActive = false}
		end
		self.cellItemList[j] = itemList
	end
end

function this:SetData(dataList, updateFunc, extData)
	self.dataList = dataList --传入的数据列表
	self.updateFunc = updateFunc --刷新回调，返回数据列表的索引和对应预设
	self.dataCount = #dataList

	if self.dragType == 1 then
		-- self.itemDis = self.itemHeight * math.ceil(self.dataCount / self.fixedCount) + self.spacing.y - self.rectTransform.sizeDelta.y
		self.itemDis = self.itemHeight * math.ceil(self.dataCount / self.fixedCount) - self.rectTransform.sizeDelta.y
		self.maxOffset = math.max(math.ceil(self.dataCount / self.fixedCount) - self.itemCount, 0)
	elseif self.dragType == 2 then
		-- self.itemDis = self.itemWidth * math.ceil(self.dataCount / self.fixedCount) + self.spacing.x - self.rectTransform.sizeDelta.x
		self.itemDis = self.itemWidth * math.ceil(self.dataCount / self.fixedCount) - self.rectTransform.sizeDelta.x
		self.maxOffset = math.max(math.ceil(self.dataCount / self.fixedCount) - self.itemCount, 0)
	end

	self.goItemList = {}
	self.goItemDataRefList = {}
	if self.tmpTween then
		self.tmpTween:Kill()
		self.tmpTween = nil
	end

	local oldIndex = self.dataIndex
	local oldPos = self.dragGOTran.anchoredPosition
	self.dataIndex = 0
	self.dragGOTran.anchoredPosition = Vector2.New(0, 0)
	local index, item
	-- if self.piclineArray then
	-- 	table.walk(self.piclineArray, function(obj)
	-- 		destroy(obj)
	-- 	end)
	-- end
	-- self.piclineArray = {}

	for j = 1, self.fixedCount do
		for i = 1, self.itemCount do
			item = self.cellItemList[j][i]
			index = j+(i-1)*self.fixedCount

			if not item.go and index <= self.dataCount then
				local go = newObject(self.item)
				go.name = "item"..index
				go.transform:SetParent(self.dragGO.transform)
				go.transform.localScale = Vector3.one * self.itemGoScale
				go.transform.localPosition = Vector3.zero
				go:SetActive(false)

				local tran = go:GetComponent("RectTransform")
				tran.anchorMin = Vector2.New(0, 1)
				tran.anchorMax = Vector2.New(0, 1)

				item.go = go
				item.tran = tran
			end

			if item.go then
				if self.dragType == 1 then
					item.tran.anchoredPosition = Vector2.New(self.itemWidth * (j-1), (0.5-i) * self.itemHeight)
				else
					item.tran.anchoredPosition = Vector2.New((i-0.5) * self.itemWidth, self.itemHeight * (1-j))
				end
				self.goItemList[index] = item.go
			end
			SetUpdate(self, index, item)

			
			-- if item.go and item.go.activeSelf and j == 1 and extData and extData.picline ~= nil and extData.piclineOffset ~= nil and self.dragType == 1 then
			-- 	local piclineGo = newObjToParent(self.picline, self.dragGO.transform)
			-- 	table.insert(self.piclineArray, piclineGo)
			-- 	if self.dragType == 1 then
			-- 		local w = self.fixedCount % 2 == 0 and self.itemWidth * self.fixedCount / 2 - self.itemWidth * 0.5 or self.itemWidth * math.floor(self.fixedCount / 2)
			-- 		piclineGo.transform.anchoredPosition = Vector2.New(w, (0.5-i) * self.itemHeight) + extData.piclineOffset
			-- 		piclineGo.transform:SetAsFirstSibling()
			-- 	else
			-- 		--todo
			-- 	end
			-- end
		end
	end

	if self.scrollBar then
		if self.dragType == 1 then
			self.scrollBar.size = self.rectTransform.sizeDelta.y / (self.itemHeight * math.ceil(self.dataCount / self.fixedCount) + self.spacing.y)
		elseif self.dragType == 2 then
			self.scrollBar.size = self.rectTransform.sizeDelta.x / (self.itemWidth * math.ceil(self.dataCount / self.fixedCount) + self.spacing.x)
		end
		if not oldIndex then
			self.scrollBar.value = 0
		else
			if self.dragType == 1 then
				self.scrollBar.value = oldPos.y / self.itemDis
			else
				self.scrollBar.value = -oldPos.x / self.itemDis
			end
		end
		self.scrollBar.onValueChanged:AddListener(function(f)
			local v2, curIndex
			if self.dragType == 1 then
				v2 = Vector2.Lerp(Vector2.zero, Vector2.New(0, self.itemDis), f)
				curIndex = math.floor(v2.y / self.itemHeight)
			elseif self.dragType == 2 then
				v2 = Vector2.Lerp(Vector2.zero, Vector2.New(-self.itemDis, 0), f)
				curIndex = math.floor(-v2.x / self.itemWidth)
			end

			self.dragGOTran.anchoredPosition = v2
			SetItemIndex(self, curIndex)
		end)
	end

	if oldIndex then
		if self.itemDis > 0 then
			if self.dragType == 1 then
				self.dragGOTran.anchoredPosition = Vector2.New(0, math.clamp(oldPos.y, 0, self.itemDis))
			elseif self.dragType == 2 then
				self.dragGOTran.anchoredPosition = Vector2.New(math.clamp(oldPos.x, -self.itemDis, 0), 0)
			end
		end
		SetItemIndex(self, oldIndex)
	end
end

function this:ForeachItemGO(func)
	if not func or not self.goItemList then return end
	for i = 1, math.min(#self.goItemList, self.dataCount) do
		func(i, self.goItemList[i])
	end
end

-- 设置当前索引位置在最上层
function this:SetIndex(curIndex)
	local itemOffset = math.ceil(curIndex / self.fixedCount) - 1
	if self.itemDis > 0 then
		if self.dragType == 1 then
			self.dragGOTran.anchoredPosition = Vector2.New(0, math.clamp(self.itemHeight * itemOffset, 0, self.itemDis))
		elseif self.dragType == 2 then
			self.dragGOTran.anchoredPosition = Vector2.New(math.clamp(-self.itemWidth * itemOffset, -self.itemDis, 0), 0)
		end
	else
		self.dragGOTran.anchoredPosition = Vector2.New(0, 0)
	end
	SetItemIndex(self, itemOffset)
end

-- 通过item预设获取关联的数据项索引
function this:GetItemDataIndex(go)
	return self.goItemDataRefList[go]
end

-- 设置滚动区域
function this:SetScrollRect(vec2)
	self.rectTransform.sizeDelta = vec2
	self:SetIndex(1)
end

-- 偏移
function this:GetOffset()
	return self.dragGOTran.anchoredPosition
end

function this:SetOffset(offset)
	self.dragGOTran.anchoredPosition = offset
end

return ScrollCycleView