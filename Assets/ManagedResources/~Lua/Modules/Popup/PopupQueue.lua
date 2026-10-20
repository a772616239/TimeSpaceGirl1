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
 * 只在「底屏」上弹（BASE_SCREEN_NAMES）：
 *   弹窗里点「前往 / 去完成」会先关掉弹窗、再跳进功能界面（如 OperatingPanel）。
 *   跳转那次关闭同样会唤醒队列，下一个主动弹窗就会压在刚打开的功能界面之上。
 *   ⇒ 队列只有在栈顶是主界面（或屏幕上什么都没有）时才放行；玩家跳到别处就先压着，
 *     等他关回主界面再继续。压着不丢：PlayerPrefs 的「已弹过」标记在 Push 时就写了，
 *     真丢了就再也不弹，所以必须延后而不是丢弃。
 *
 * 关闭通知链路（两条，互为兜底）：
 *   1. BasePanel:CloseUI -> GameEvent.UI.OnClose（被全屏界面顶掉时也会派发）
 *   2. UIManager.CloseStackPanel/CloseFixedPanel 收尾 -> UIManager.SetPopupQueue
 *      注册进来的 OnPanelClosed(id)（此时下层界面已重开，用来判断「回到主界面」）
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

-- 允许主动弹窗落屏的「底屏」界面（按 UIConfig.name 匹配）。
-- 玩家点了弹窗里的「前往」跳到功能界面后，栈顶就不是这些界面了，队列自动压住。
-- 需要放开新界面时往这里加名字即可（改配置表前先确认它确实是常驻底屏）。
local BASE_SCREEN_NAMES = {
    ["MainPanel"] = true,   -- 主界面
}

-- 待弹列表，元素：{ id, name, args = {n=, ...}, withSound }
local queue = {}
-- 已经入队、还没开出来的 id（同一界面不重复排队）
local pending = {}
-- 当前正在展示的项；closed = true 表示已关闭、正在等下一个
local current = nil
-- 关闭后延迟开下一个的定时器
local advanceTimer = nil
-- 是否因为「玩家不在主界面」而暂时压着队列
local holding = false

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

--- 栈顶是否是「底屏」（主界面）。拿不到 UI 状态时一律放行，保持老行为。
local function canFireOnScreen()
    if UIManager == nil or UIManager.GetTopStackPanel == nil then
        return true
    end
    local ok, panel = pcall(UIManager.GetTopStackPanel)
    if not ok then
        LogError("[PopupQueue] 读取栈顶界面异常：" .. tostring(panel))
        return true
    end
    -- 屏幕上什么都没开（切场景、登录加载中）：没有可以压的东西
    if panel == nil or panel.uiConfig == nil then
        return true
    end
    local key = panel.uiConfig.name or panel.uiConfig.assetName
    return BASE_SCREEN_NAMES[key] == true
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

--- 打开队列里的下一个（队列空闲、且回到主界面时才真正开）
function PopupQueue.TryOpenNext()
    if advanceTimer ~= nil then
        -- 刚关掉一个、正在等那 0.15s 的空档：交给定时器处理，
        -- 此刻开新界面还是会被 CloseStackPanel 的收尾流程改层级
        return
    end

    if current ~= nil then
        if current.closed ~= true then
            -- 还有界面在展示，等它关闭时再进来
            return
        end
        current = nil
    end

    if #queue == 0 then
        holding = false
        return
    end

    -- 玩家跳进了功能界面（弹窗里的「前往」/去完成）：先压着，别压在人家刚打开的界面上
    if not canFireOnScreen() then
        if not holding then
            holding = true
            Log("[PopupQueue] 当前不在主界面，暂缓弹出：" .. (queue[1] and queue[1].name or ""))
        end
        return
    end
    holding = false

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

--- 界面栈变了（关掉一个 / 被顶掉 / 回到主界面）后重新判断能不能弹。
--- 可以被重复调用：只有「队列里还有东西、当前没有界面在展示」时才推进。
function PopupQueue.Recheck()
    if #queue == 0 then
        holding = false
        if advanceTimer ~= nil then
            advanceTimer:Stop()
            advanceTimer = nil
        end
        return
    end
    if advanceTimer ~= nil then
        return
    end
    if current ~= nil and current.closed ~= true then
        return
    end
    -- 统一走延迟定时器：关界面后下层界面还在唤醒/重排，同帧开会被改层级
    scheduleAdvance()
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

--- 某个界面真的关掉了（BasePanel:CloseUI 派发的 UI.OnClose）：
--- 该界面若正是队列里展示中的那个，标记已关闭；然后重新判断能否弹下一个。
--- 被全屏界面顶掉（SupremeHeroPopup 点「前往」跳 OperatingPanel 这类）也走这里，
--- 所以弹窗没自己 ClosePanel 时队列也不会永久卡在「展示中」。
function PopupQueue.OnPanelClosed(id)
    if current ~= nil and current.closed ~= true and current.id == id then
        current.closed = true
        Log("[PopupQueue] 关闭：" .. current.name .. "，队列剩余 " .. #queue)
    end
    this.Recheck()
end

--- 该界面是否正在展示（含「刚关闭、等下一个」的空档不算）
function PopupQueue.IsShowing(id)
    return isShowing(id)
end

--- 该界面是否还在队列里等（没开出来）
function PopupQueue.IsQueued(id)
    return pending[id] == true
end

--- 队列是否因为「玩家不在主界面」而压着
function PopupQueue.IsHolding()
    return holding
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
    holding = false
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
    return string.format("current=%s holding=%s pending=[%s]",
        current and current.name or "nil", holding and "true" or "false", table.concat(names, ","))
end

local listeningUIPanelEvent = false

--- 注册到 UIManager（幂等）。关闭通知依赖这条链路。
function PopupQueue.Initialize()
    if UIManager ~= nil and UIManager.SetPopupQueue ~= nil then
        UIManager.SetPopupQueue(this)
    end
    -- 兜底监听 UI 开/关事件：
    --   关：面板被全屏界面顶掉时 UIManager 不一定走到 CloseStackPanel 的收尾通知，
    --       BasePanel:CloseUI 派发的 UI.OnClose 一定会来；
    --   开：队列可能压在主界面出来之前（网络回调比 MainPanel 早到），
    --       MainPanel 打开那一刻要重新放行，否则会一直压到下次关界面。
    if not listeningUIPanelEvent
            and Game ~= nil and Game.GlobalEvent ~= nil and GameEvent ~= nil
            and GameEvent.UI ~= nil and Game.GlobalEvent.AddEvent ~= nil then
        listeningUIPanelEvent = true
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, function(panelId)
            pcall(function()
                this.OnPanelClosed(panelId)
            end)
        end)
        if GameEvent.UI.OnOpen ~= nil then
            Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, function()
                pcall(function()
                    this.Recheck()
                end)
            end)
        end
    end
end

PopupQueue.Initialize()

return this
