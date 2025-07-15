local LimitScrollView = {}

function LimitScrollView.New()
    local o = {}
    LimitScrollView.__index = LimitScrollView
    setmetatable(o, LimitScrollView)
    return o
end

--- 设置节点
function LimitScrollView:SetScrollView(scrollView, content)
    self.gameObject = scrollView
    self.transform = scrollView.transform
    self.content = content
end

--- 设置节点管理器
function LimitScrollView:SetNodeController(controller)
    self.controller = controller
end

--- 设置数据
function LimitScrollView:SetData(dataList, func)
    self.DataList = dataList
    self.ChatItemAdapter = func
    self:RefreshShow()
    --self:ScrollToBottom(false)
end

--- 滑动到底部
function LimitScrollView:ScrollToBottom(isForceBottom)
    Timer.New(function()
        local cheight = self.content.transform.rect.height
        local vheight = self.transform.rect.height
        local dheight = cheight - vheight
        -- 判断滚动到最下面的条件
        local pos = self.content.transform.anchoredPosition3D
        -- 判断是否强制
        if isForceBottom then
            if dheight > 0 then
                self.content.transform.anchoredPosition3D = Vector3(pos.x, dheight, 0)
            end
            return
        end
        -- 如果不强制，判断是否符合条件
        if dheight > 0 and pos.y > dheight - vheight then
            self.content.transform.anchoredPosition3D = Vector3(pos.x, dheight, 0)
        end
    end, 0.1, 0, true):Start()
end

--- 刷新显示
function LimitScrollView:RefreshShow()
    if not self.NodeList then
        self.NodeList = {}
    else
        self:RecycleNode()
    end
    local len = #self.DataList
    for i = 1, len do
        local node = self:CreateChatNode(i)
        table.insert(self.NodeList, node)
    end
end

--- 回收所有节点
function LimitScrollView:RecycleNode()
    self.controller:RecycleAllNode()
    self.NodeList = {}
end


--- 创建聊天节点
function LimitScrollView:CreateChatNode(index)
    local item = nil
    local data = self.DataList[index]
    item = self.controller:CreateNode(self.content, data)
    if self.ChatItemAdapter then
        self.ChatItemAdapter(index, item.gameObject)
    end
    return item
end

return LimitScrollView