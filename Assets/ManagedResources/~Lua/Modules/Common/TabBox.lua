---
---tab管理器
---1、构建自己的tabbox节点，注意tabbox节点的根节点下必须包含两个命名为 tab 和 box 的两个节点
---     tab:    是一个按钮，所有tab节点从此节点clone，保存时请将此节点置为不可见，请自定义按钮的样式，我们将提供自定义按钮样式的接口
---     box:    是所有tab节点的父容器，建议使用横/纵向布局组件，管理器不提供自动布局功能
---
---2、创建管理器
---     local TabBox = require("Modules/Common/TabBox") -- 引用
---     local tabBox = TabBox.New()     -- 创建一个管理器
---
---3、 设置参数(非必须)
---     1>  tabBox.SetTabAdapter( func(tab, index, status) )   -- 设置自定义按钮样式的方法，
---             func   自定义按钮样式的方法
---                 tab     要处理的节点
---                 index   节点序号
---                 status   节点状态  "default" 默认状态  "select" 选中状态   "lock" 锁定状态
---     2>  tabBox.SetTabIsLockCheck( func(index) => isLock, errorTip )
---             func   检测tab是否锁定的方法
---                 参数：     index   tab的index
---                 返回值：   isLock   锁定状态   true 锁定   false 启用
---                            errorTip 锁定原因    点击锁定的tab将会弹出该提示
---     3>  tabBox.SetChangeTabCallBack( func(index, lastIndex) )    -- 设置tab选中状态改变回调事件
---             func  回调事件
---                 index       当前选中节点的序号
---                 lastIndex   上次选中节点的序号
---
--- 4、初始化
---     tabBox.Init(tabNode, tabData, defaultSelect)      -- 初始化方法，此方法必须在设置参数后调用
---         tabNode     在第一步中创建的tabbox节点的引用
---         tabData     是一个数组，数组长度决定tab节点的数量，
---                数组的每条数据中必须包含两个属性  default  和  select， 用于指定每个tab默认和选中状态的图片资源名称，
---         defaultSelect   默认选中的tab，默认是第一个
local TabBox = {}
local this = TabBox

this.gameObject = nil
this.TabData = {}
this.SelectIndex = nil
this.ChangeTabCallBack = nil
this.TabList = {}
this.TabAdapter = nil

-- 调用此方法创建一个管理器
function this.New()
    local o = {}
    this.__index = this
    setmetatable(o, this)
    return o
end

-- 初始化Tab,复制的this:Init代码,删除获得tab和box代码,
-- 不太清楚为什么,如果重构为Init调用Init_SetTabAndBox,会导致打开两个不同TabBox对象时报错
function this:Init_SetTabAndBox(gameObject, tabData, defaultSelect, tab, box)
    if not gameObject or not tabData then
       
        return
    end
    self.gameObject = gameObject
    self.TabData = tabData
    self.SelectIndex = defaultSelect or 1
    -- 获取tab
    if not tab then
       
        return
    end
    tab:SetActive(false)
    -- 获取存放节点
    if not box then
       
        return
    end

    --- 判断默认tab是否被锁定，如果被锁定，则置为空在下面找到第一个可用的tab作为默认tab
    if self.TabIsLockCheck then
        local isLock = self.TabIsLockCheck(self.SelectIndex)
        if isLock then
            self.SelectIndex = nil
        end
    end
    --- 开始创建tab
    self.TabList = {}
    Util.ClearChild(box.transform)
    for index = 1, #self.TabData do
        local newTab = newObjToParent(tab, box)
        newTab:SetActive(true)
        self.TabList[index] = newTab
        -- 检测tab是否可用
        local isLock = false
        if self.TabIsLockCheck then
            isLock = self.TabIsLockCheck(index)
        end
        -- 判断是否有默认tab
        if not self.SelectIndex and not isLock then
            self.SelectIndex = index  -- 设置默认tab
        end
        -- 判断当前tab是否被选中
        local isSelect = index == self.SelectIndex
        local status = isLock and "lock" or (isSelect and "select" or "default")
        -- 自定义数据
        if self.TabAdapter then
            self.TabAdapter(newTab, index, status)
        end
        -- 事件监听
        Util.AddClick(newTab, function ()
            -- 被选中则返回
            if index == self.SelectIndex then return end
            -- 如果被锁定 则返回
            if self.TabIsLockCheck then
                local isLock, errorTip = self.TabIsLockCheck(index)
                if isLock then
                    PopupTipPanel.ShowTip(errorTip)
                    return
                end
            end
            -- 切换页签
            self:ChangeTab(index)
        end)
    end
    -- 正确性检测
    if not self.SelectIndex then
       
        return
    end
    -- 初始化时调用一次 状态改变方法
    if self.ChangeTabCallBack then
        self.ChangeTabCallBack(self.SelectIndex)
    end
end

-- 初始化Tab
function this:Init(gameObject, tabData, defaultSelect)
    if not gameObject or not tabData then
       
        return
    end
    self.gameObject = gameObject
    self.TabData = tabData
    self.SelectIndex = defaultSelect or 1
    
    -- 获取tab
    local tab = Util.GetGameObject(self.gameObject.transform, "tab")
    if not tab then
       
        return
    end
    tab:SetActive(false)
    -- 获取存放节点
    local box = Util.GetGameObject(self.gameObject.transform, "box")
    if not box then
       
        return
    end

    --- 判断默认tab是否被锁定，如果被锁定，则置为空在下面找到第一个可用的tab作为默认tab
    if self.TabIsLockCheck then
        local isLock = self.TabIsLockCheck(self.SelectIndex)
        if isLock then
            self.SelectIndex = nil
        end
    end
    --- 开始创建tab
    self.TabList = {}
    Util.ClearChild(box.transform)
    for index = 1, #self.TabData do
        local newTab = newObjToParent(tab, box)
        newTab:SetActive(true)
        self.TabList[index] = newTab
        -- 检测tab是否可用
        local isLock = false
        if self.TabIsLockCheck then
            isLock = self.TabIsLockCheck(index)
        end
        -- 判断是否有默认tab
        if not self.SelectIndex and not isLock then
            self.SelectIndex = index  -- 设置默认tab
        end
        -- 判断当前tab是否被选中
        local isSelect = index == self.SelectIndex
        local status = isLock and "lock" or (isSelect and "select" or "default")

        -- 自定义数据
        if self.TabAdapter then
            self.TabAdapter(newTab, index, status)
        end
        -- 事件监听
        Util.AddClick(newTab, function ()
            -- 被选中则返回
            if index == self.SelectIndex then return end
            -- 如果被锁定 则返回
            if self.TabIsLockCheck then
                local isLock, errorTip = self.TabIsLockCheck(index)
                if isLock then
                    PopupTipPanel.ShowTip(errorTip)
                    return
                end
            end
            -- 切换页签
            self:ChangeTab(index)
        end)

    end
    -- 正确性检测
    if not self.SelectIndex then

        return
    end
    -- 初始化时调用一次 状态改变方法
    if self.ChangeTabCallBack then
        self.ChangeTabCallBack(self.SelectIndex)
    end
end

-- 设置自定义Tab显示方法
function this:SetTabAdapter(func)
    self.TabAdapter = func
end

function this:SetTabIsLockCheck(func)
    self.TabIsLockCheck = func
end

-- 设置切换Tab时的回调函数
function this:SetChangeTabCallBack(func)
    self.ChangeTabCallBack = func
end

-- 改变模块显示
function this:ChangeTab(index)
    if #self.TabList == 0 then return end
    -- 原来选中的变成未选中
    
    local curSelectTab = self.TabList[self.SelectIndex]

    if self.TabAdapter then
        self.TabAdapter(curSelectTab, self.SelectIndex, "default")
    end

    -- 新的选中状态
    local lastIndex = self.SelectIndex
    self.SelectIndex = index
    curSelectTab = self.TabList[self.SelectIndex]

    if self.TabAdapter then
        self.TabAdapter(curSelectTab, self.SelectIndex, "select")
        
    end

    -- tab改变回调
    if self.ChangeTabCallBack then
        self.ChangeTabCallBack(index, lastIndex)
    end
end

-- 获取tablist
function this:GetTabList()
    return self.TabList
end

return TabBox