--[[
 * 主动弹窗队列（弹框列表）
 *
 * 解决的问题：
 *   登录进主城时，首充、拍脸、国家选择、至尊英雄等多个界面会在同一帧里各自
 *   OpenPanel，UIManager 只给它们递增 sortingOrder，于是全部叠在一起。
 *
 * 做法：
 *   需要「排队逐个展示」的主动弹窗，把 UIManager.OpenPanel* 换成 PopupQueue.Push*。
 *   队列空闲 -> 立刻开；队列忙 -> 挂在队尾，等当前弹窗关闭（UIManager 通知）后，
 *   延迟一小段再开下一个，保证同一时刻屏幕上只有一个主动弹窗。
 *
 *   ⚠️ 只管「主动弹出」的界面。玩家点击触发的弹窗（商店确认框之类）不要走这里，
 *      否则确认框会排在底层界面后面，交互直接断掉。
 *
 * 关闭通知链路：
 *   BasePanel:ClosePanel -> UIManager.ClosePanel -> CloseStackPanel/CloseFixedPanel
 *   -> UIManager.SetPopupQueue 注册进来的 OnPanelClosed(id)
 *
 * 使用：
 *   PopupQueue.Push(UIName.FirstRechargePanel)              -- 等价 OpenPanelWithSound
 *   PopupQueue.PushSilent(UIName.CountryFlagSelectPopup, cb) -- 等价 OpenPanel
--]]

PopupQueue = {}
local this = PopupQueue

-- 关闭后等一小段再开下一个。
-- 🔴 不能在同一帧开：此刻还在 CloseStackPanel 的收尾流程里（唤醒下层 / 恢复
--    eventSystem / 重排 sortingOrder），紧接着 OpenPanel 会被它继续改层级。
--    与 CountryRankManager.ShowFirstEnterPopup 等待 GuidePanel 关闭的处理保持一致。
local OPEN_DELAY = 0.15

-- 待弹列表，元素：{ id, name, args = {n=, ...}, withSound }
local queue = {}
-- 已经入队、还没开出来的 id（同一界面不重复排队）
local pending = {}
-- 当前正在展示的项；closed = true 表示已关闭、正在等下一个
local current = nil
-- 关闭后延迟开下一个的定时器
local advanceTimer = nil

-- 参数打包：必须带 n，弹窗参数里可能存在 nil（如 FirstRechargePanel 的 nil, cb）
local function pack(...)
    return { n = select("#", ...), ... }
end

local function unpackArgs(args)
    return unpack(args, 1, args.n or 0)
end

local function isShowing(id)
    return current ~= nil and current.closed ~= true and current.id == id
end

local function scheduleAdvance()
    if advanceTimer ~= nil then
        advanceTimer:Stop()
        advanceTimer = nil
    end
    local timer
    timer = Timer.New(function()
        timer:Stop()
        if advanceTimer == timer then
            advanceTimer = nil
        end
        this.TryOpenNext()
    end, OPEN_DELAY, 1, true)
    advanceTimer = timer
    timer:Start()
end

--- 打开队列里的下一个（队列空闲时才真正开）
function PopupQueue.TryOpenNext()
    if advanceTimer ~= nil then
        advanceTimer:Stop()
        advanceTimer = nil
    end

    if current ~= nil then
        if current.closed ~= true then
            -- 还有界面在展示，等它关闭时再进来
            return
        end
        current = nil
    end

    while #queue > 0 do
        local item = table.remove(queue, 1)
        pending[item.id] = nil

        if UIManager.IsOpen(item.id) then
            Log("[PopupQueue] 跳过（已打开）：" .. item.name)
        else
            local openFunc = item.withSound and UIManager.OpenPanelWithSound or UIManager.OpenPanel
            local ok, panel = pcall(openFunc, item.id, unpackArgs(item.args))
            if not ok then
                LogError("[PopupQueue] 打开异常：" .. item.name .. " -> " .. tostring(panel))
            elseif panel == nil then
                LogError("[PopupQueue] 打开失败（配置或资源缺失）：" .. item.name)
            else
                item.closed = false
                current = item
                Log("[PopupQueue] 打开：" .. item.name .. "，队列剩余 " .. #queue)
                return
            end
        end
        -- 打开失败/跳过：继续尝试下一个，避免一个坏界面把整条队列卡死
    end
end

local function enqueue(withSound, id, ...)
    if id == nil then
        LogError("[PopupQueue] Push 缺少界面 id")
        return false
    end
    local uiConfig = UIManager.GetConfig(id)
    if uiConfig == nil then
        LogError("[PopupQueue] 没有找到 UI 配置：id=" .. tostring(id))
        return false
    end
    local name = uiConfig.assetName or tostring(id)

    -- 去重：同一界面在排队/展示中，重复请求直接忽略
    if pending[id] then
        Log("[PopupQueue] 已在队列中，忽略重复请求：" .. name)
        return true
    end
    if isShowing(id) then
        Log("[PopupQueue] 正在展示，忽略重复请求：" .. name)
        return true
    end
    if UIManager.IsOpen(id) then
        Log("[PopupQueue] 已经打开，忽略重复请求：" .. name)
        return true
    end

    local item = {
        id = id,
        name = name,
        args = pack(...),
        withSound = withSound,
    }
    queue[#queue + 1] = item
    pending[id] = true

    if #queue > 1 or current ~= nil then
        Log("[PopupQueue] 入队：" .. name .. "，前面还有 " .. (#queue - 1) .. " 个")
    end
    this.TryOpenNext()

    -- 区分三种结果，调用方要靠返回值判断「这次到底有没有弹出来」：
    --   开出来了   -> current 就是这一项
    --   排在队尾   -> 前面还有界面在展示，等着就行
    --   开不出来   -> 既没开出来也不在队列里（配置/资源缺失），本次失败
    if current == item then
        return true
    end
    if #queue > 0 and queue[#queue] == item then
        return true
    end
    return false
end

--- 入队一个主动弹窗（带音效，等价 UIManager.OpenPanelWithSound）
--- @return boolean 是否被接受（排队或立即打开）
function PopupQueue.Push(id, ...)
    return enqueue(true, id, ...)
end

--- 入队一个主动弹窗（不带额外音效，等价 UIManager.OpenPanel）
function PopupQueue.PushSilent(id, ...)
    return enqueue(false, id, ...)
end

--- 某个界面关闭了（由 UIManager 调用）：轮到下一个
function PopupQueue.OnPanelClosed(id)
    if current == nil or current.id ~= id then
        return
    end
    current.closed = true
    Log("[PopupQueue] 关闭：" .. current.name .. "，队列剩余 " .. #queue)
    scheduleAdvance()
end

--- 该界面是否正在展示（含「刚关闭、等下一个」的空档不算）
function PopupQueue.IsShowing(id)
    return isShowing(id)
end

--- 该界面是否还在队列里等（没开出来）
function PopupQueue.IsQueued(id)
    return pending[id] == true
end

--- 队列里还压着几个
function PopupQueue.Count()
    return #queue
end

--- 清空队列（切场景 / 退出游戏时调用，避免在已销毁的 UIRoot 上开界面）
function PopupQueue.Clear()
    queue = {}
    pending = {}
    current = nil
    if advanceTimer ~= nil then
        advanceTimer:Stop()
        advanceTimer = nil
    end
end

--- 调试用：当前队列快照
function PopupQueue.Dump()
    local names = {}
    for i = 1, #queue do
        names[#names + 1] = queue[i].name
    end
    return string.format("current=%s pending=[%s]",
        current and current.name or "nil", table.concat(names, ","))
end

--- 注册到 UIManager（幂等）。关闭通知依赖这条链路。
function PopupQueue.Initialize()
    if UIManager ~= nil and UIManager.SetPopupQueue ~= nil then
        UIManager.SetPopupQueue(this)
    end
end

PopupQueue.Initialize()

return this
