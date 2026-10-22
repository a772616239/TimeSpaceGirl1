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
    -- 切换页签时选中底板滑动动画（opt-in，默认关闭，需 SetTabSlideAnim(true) 打开）
    o.SlideAnimEnabled = false
    o.slideTimer = nil
    o.slideSelect = nil
    o.slideOrig = nil
    o.boxGo = nil
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
    self.boxGo = box
    -- 重建页签前收掉未完成的滑动动画（box 下旧子节点即将被 ClearChild 销毁）
    self:KillTabSlide(false)

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
    self.boxGo = box
    -- 重建页签前收掉未完成的滑动动画（box 下旧子节点即将被 ClearChild 销毁）
    self:KillTabSlide(false)

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
            -- HighText.gameObject:SetActive(true)
            -- txt.gameObject:SetActive(false)
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

-- 设置切换页签时「选中底板」滑动动画开关（opt-in，默认关闭）
function this:SetTabSlideAnim(enable)
    self.SlideAnimEnabled = enable and true or false
end

-- 收尾滑动动画：停掉驱动 Timer 并把 select 位置复位到原值
-- 无论 finish 与否都复位位置——保证任何中断路径都不留下错位的选中底板
function this:KillTabSlide(finish)
    if self.slideTimer then
        self.slideTimer:Stop()
        self.slideTimer = nil
    end
    if self.slideSelect then
        if self.slideOrig then
            self.slideSelect.transform.localPosition = self.slideOrig
        end
        self.slideSelect = nil
        self.slideOrig = nil
    end
end

-- 选中底板从旧页签位置滑到新页签位置：直接位移 tween 新 select（不克隆节点）
-- 不克隆的原因：克隆体挂 box 下会被布局/锚点重新摆位，且 tween 一旦被杀
-- 克隆体就滞留在旧位置（表现为「错位 icon」）；select 是 tab 自己的子节点，动它无此风险
function this:PlayTabSlide(oldIndex, newIndex)
    local newTab = self.TabList[newIndex]
    local oldTab = self.TabList[oldIndex]
    if not newTab or not oldTab then return end
    local newSelect = Util.GetGameObject(newTab, "select")
    local oldSelect = Util.GetGameObject(oldTab, "select")
    if not newSelect or not oldSelect then return end
    -- 上一次动画没结束先复位，防连点叠播
    self:KillTabSlide(true)
    -- box 局部空间里两个 tab 的位移差（tab 尺度一致，可直接搬到 select 的局部空间用）
    local nt = newTab.transform.localPosition
    local ot = oldTab.transform.localPosition
    local dx, dy = ot.x - nt.x, ot.y - nt.y
    if math.abs(dx) < 1 and math.abs(dy) < 1 then return end
    local selTf = newSelect.transform
    local orig = selTf.localPosition
    self.slideSelect = newSelect
    self.slideOrig = orig
    local DUR = 0.15
    local elapsed = 0
    -- 先落到旧页签位置（首个 Timer tick 在下一帧，不先摆位会在终点闪一帧）
    selTf.localPosition = Vector3.New(orig.x + dx, orig.y + dy, orig.z)
    -- Timer 逐帧驱动（unscaledDeltaTime，UI 不受时间缩放影响），避免依赖全局 DOTween 存活
    self.slideTimer = Timer.New(function()
        elapsed = elapsed + Time.unscaledDeltaTime
        local p = elapsed / DUR
        if p >= 1 then
            selTf.localPosition = orig
            self:KillTabSlide(true)
            return
        end
        local e = 1 - (1 - p) * (1 - p) -- OutQuad
        selTf.localPosition = Vector3.New(orig.x + dx * (1 - e), orig.y + dy * (1 - e), orig.z)
    end, 0, -1, true)
    self.slideTimer:Start()
end

-- 改变模块显示
function this:ChangeTab(index)
    if #self.TabList == 0 then return end
    -- 原来选中的变成未选中

    local curSelectTab = self.TabList[self.SelectIndex]
    local oldIndex = self.SelectIndex

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

    -- 选中底板滑动动画（opt-in）
    if self.SlideAnimEnabled then
        self:PlayTabSlide(oldIndex, index)
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