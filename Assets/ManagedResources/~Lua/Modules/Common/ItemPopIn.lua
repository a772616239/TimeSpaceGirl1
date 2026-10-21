--- 列表项入场：逐格「放大缩小」（Coin Master 式的礼包墙/榜单弹入）
---
--- 复用点：ValuePackPanel 的礼包墙、GrowthManual 的两个列表页（RewardPreview / TaskPreview）。
--- 数据源统一是 ScrollCycleView：它的 item 由 SetData 克隆并排在 grid 下，ForeachItemGO
--- 按数据下标给出 1..dataCount，顺序即版面顺序。
---
--- 用法 A（单列表，三步）：
---   local ItemPopIn = require("Modules/Common/ItemPopIn")
---   this.popIn = ItemPopIn.New(function() return this.ScrollView end)  -- InitComponent
---   this.popIn:Play()   -- 打开面板 / 切页（必须在 SetData 之后）
---   this.popIn:Stop()   -- OnClose / OnDestroy（🔴 不调 = item 永久停在半截缩放）
---
--- 用法 B（页面级，一行接入；页签多的面板用这个）：
---   ItemPopIn.PlayPage(内容页对象)   -- 打开 / 切页时（列表重建之后）
---   ItemPopIn.StopPage(内容页对象)   -- 切页 / 关闭 / 销毁时
--- 它会自己到页面里找长列表（ScrollCycleView，字段名随意）；找不到就 no-op，
--- 所以面板可以对每个页签无脑调用。手工克隆的列表让页面实现 GetPopInSource() 即可。
---
--- 数据源（getScrollView 的返回值，四种都认）：
---   ① ScrollCycleView（有 ForeachItemGO）——最常用
---   ② 容器 GameObject / RectTransform——取 active 子节点（手工克隆的列表）
---   ③ Lua 数组 { go1, go2, ... }——元素可以是 GameObject 或 transform（card1..card3 这种固定的几格）
---   ④ 无 → no-op
---
--- 三种手感（cfg.mode）：
---   "surge"（缺省）0.82 → 1.02 → 1，两段 + 逐格错开 = 礼包墙那种「逐格放大缩小」
---   "duang"        0.5 → 1，单段 OutElastic，自带回弹过冲 = 抽卡那种「duang 一下」（不会和别的配方混）
---   "phases"       0.78 → 1.05 → 0.985 → 1，按 cfg.phases 逐段走 = 「浮起—按回—落定」的慢速手感，
---                  段数/峰值/时长/缓动全由调用方给，想多慢就多慢（duang 的时长只能整体拉长，越拉越拖沓）
---
--- 可调项（New 的第二参，缺省即下面的 defaultCfg）：
---   mode               "surge" / "duang" / "phases"
---   phases             phases 模式的关键帧数组：{{scale=1.05,duration=0.38,ease="OutCubic"}, ...}
---                      scale 是相对基准的倍数（1 = 原大小），最后一段落回 1 时自动吸附复位
---   from/peak          起始与峰值缩放
---   riseDuration       放大段时长，fallDuration 缩小回落时长
---   duangDuration      duang 模式的整体时长，ease 是它的缓动（缺省 OutElastic）
---   delay              整批延后多久起播（同一页里两批要错开时用，比如卡片先、数字后）
---   step               相邻 item 的间隔，maxSpan 是整体跨度上限（item 多时自动压缩 step）
local ItemPopIn = {}
local this = ItemPopIn

local defaultCfg = {
    mode = "surge",
    from = 0.82,
    peak = 1.02,
    riseDuration = 0.14,
    fallDuration = 0.12,
    duangDuration = 0.5,
    ease = "OutElastic",
    phases = nil,
    delay = 0,
    step = 0.055,
    maxSpan = 0.55,
}

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能直接取字段
-- （tolua fake-null），必须先 IsNull 判活。
local function Alive(obj)
    if obj == nil then
        return false
    end
    if type(obj) == "userdata" then
        return not IsNull(obj)
    end
    return true
end

-- 取 userdata 的 transform（GameObject / Component 都有，Transform 的 .transform 返回自身）。
-- 🔴 绝对不要在 userdata 上直接探字段：tolua 对**不存在**的字段是抛错
-- （field or property 'childCount' does not exist），不是返回 nil，一探就整段 pcall 失败。
-- GameObject 没有 childCount / GetChild，只有 transform 有 ⇒ 必须先落 transform 再取。
local function SafeTransform(obj)
    if obj == nil or type(obj) == "table" then
        return nil
    end
    local ok, tf = pcall(function()
        return obj.transform
    end)
    if ok and Alive(tf) then
        return tf
    end
    return nil
end

-- tolua 的枚举表是运行期注册的，取不到就不设：否则整段被 pcall 吃掉、什么都不动
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

--- getScrollView: function() return ScrollCycleView实例 end
---   用函数而不是实例，是因为面板的 ScrollView 可能晚于本对象创建，也可能被销毁重建。
function this.New(getScrollView, cfg)
    local o = { getScrollView = getScrollView, tweens = {}, items = {} }
    o.cfg = {}
    for k, v in pairs(defaultCfg) do
        o.cfg[k] = v
    end
    if cfg then
        for k, v in pairs(cfg) do
            o.cfg[k] = v
        end
    end
    setmetatable(o, { __index = this })
    return o
end

-- 回收：Kill 掉所有 tween，并把缩放复位到基准值（ScrollCycleView 给的 itemGoScale）
function this:Stop()
    for i = #self.tweens, 1, -1 do
        if Alive(self.tweens[i]) then
            self.tweens[i]:Kill(false)
        end
        self.tweens[i] = nil
    end
    for i = #self.items, 1, -1 do
        local item = self.items[i]
        if Alive(item.tf) then
            item.tf.localScale = item.base
        end
        self.items[i] = nil
    end
end

-- 收集可见 item 的 transform（滚出可视区的 item 是 SetActive(false) 的，跳过，
-- 否则会白占一轮错开时间）。
-- 数据源三种：
--   ① ScrollCycleView（有 ForeachItemGO）——item 由 SetData 克隆，顺序即版面顺序；
--   ② Lua 数组（{ go1, go2, go3 }，元素是 GameObject 或 transform）——固定几格、顺序由调用方定，
--      典型如千抽的三张卡；不用容器扫，是因为容器下还挂着别的装饰节点；
--   ③ 容器（手工克隆的长列表，如 ContinuityRechargePage）——取容器下所有 active 子节点，
--      模板项自己 SetActive(false) 着，天然被跳过。
--
-- 🔴 两条都不能碰（都踩过：整段 pcall 失败 ⇒ 那页永远没动画，还在日志里刷错误）：
--    ① 先判 table：别对 userdata 取 [1]（tolua 的 GameObject 不支持下标，直接抛错）；
--    ② 别在 userdata 上**探字段**：GameObject 没有 childCount，tolua 对不存在的字段是
--       **抛错**而不是给 nil ⇒ 必须先 SafeTransform 落 transform 再取。积天豪礼页的
--       GetPopInSource 返回的就是 GameObject，曾报 field or property 'childCount' does not exist。
function this:_Collect()
    local targets = {}
    local getter = self.getScrollView
    if type(getter) ~= "function" then
        return targets
    end
    -- 取值本身也可能炸：面板已销毁（fake-null）时去 GetGameObject 会抛错
    local okGet, src = pcall(getter)
    if not okGet then
        LogError("ItemPopIn: 取数据源失败 " .. tostring(src))
        return targets
    end
    if not Alive(src) then
        return targets
    end
    local ok, err = pcall(function()
        -- ① ScrollCycleView：item 由 SetData 克隆，顺序即版面顺序
        if type(src) == "table" and type(src.ForeachItemGO) == "function" then
            src:ForeachItemGO(function(_, go)
                if Alive(go) and go.activeSelf then
                    targets[#targets + 1] = go.transform
                end
            end)
            return
        end
        -- ② 容器：table 替身（有 GetChild）或 userdata（一律先落 transform，见 SafeTransform）
        local container
        if type(src) == "table" then
            if type(src.GetChild) == "function" then
                container = src
            end
        else
            container = SafeTransform(src)
        end
        if container then
            local count = container.childCount or 0
            for i = 0, count - 1 do
                local child = container:GetChild(i)
                if Alive(child) and child.gameObject.activeSelf then
                    targets[#targets + 1] = child
                end
            end
            return
        end
        -- ③ Lua 数组 { go1, go2, ... }：元素 GO / transform 都收
        if type(src) == "table" then
            for i = 1, #src do
                local item = src[i]
                if Alive(item) then
                    local tf = item.transform or item
                    local go = item.gameObject or item
                    if Alive(go) and go.activeSelf and Alive(tf) then
                        targets[#targets + 1] = tf
                    end
                end
            end
        end
    end)
    if not ok then
        LogError("ItemPopIn: 遍历列表项失败 " .. tostring(err))
        return {}
    end
    return targets
end

-- phases 模式：按关键帧逐段播，每段在 OnComplete 里建下一段。
-- 中途被 Kill 时 OnComplete 不回调 ⇒ 链自然断掉，不会在已关闭的面板上补建 tween。
local function RunPhases(o, tf, base, phases, startDelay)
    local function run(i)
        local p = phases[i]
        if not p then
            return
        end
        local tween = tf:DOScale(base * (p.scale or 1), p.duration or 0.2)
        if i == 1 then
            tween:SetDelay(startDelay)
        end
        SetEaseSafe(tween, p.ease or "OutQuad")
        o.tweens[#o.tweens + 1] = tween
        tween:OnComplete(function()
            if not Alive(tf) then
                return
            end
            if i < #phases then
                run(i + 1)
            else
                tf.localScale = base -- 收尾吸附，别把浮点残差留在 item 上
            end
        end)
    end
    run(1)
end

-- 播放。only 传下标就只弹那一格（抽到牌时「duang 一下」就是这么用的），
-- 下标对应 _Collect 的收集顺序（ScrollCycleView = 数据下标，数组 = 数组下标）。
function this:Play(only)
    self:Stop()
    local targets = self:_Collect()
    if only then
        targets = targets[only] and { targets[only] } or {}
    end
    local count = #targets
    if count <= 0 then
        return 0
    end

    local cfg = self.cfg
    local step = cfg.step
    if count > 1 and step * (count - 1) > cfg.maxSpan then
        step = cfg.maxSpan / (count - 1)
    end
    local mode = cfg.mode
    local duang = mode == "duang"
    local phases = mode == "phases" and type(cfg.phases) == "table" and #cfg.phases > 0 and cfg.phases or nil

    local order = 0
    local ok, err = pcall(function()
        for i = 1, count do
            local tf = targets[i]
            local base = tf.localScale
            self.items[#self.items + 1] = { tf = tf, base = base }
            tf.localScale = base * cfg.from

            if duang then
                -- 单段 from → 基准 + OutElastic：缓动自己会冲过 1 再抖回来，这就是「duang」
                local tween = tf:DOScale(base, cfg.duangDuration)
                tween:SetDelay(cfg.delay + order * step)
                SetEaseSafe(tween, cfg.ease)
                self.tweens[#self.tweens + 1] = tween
                tween:OnComplete(function()
                    if Alive(tf) then
                        tf.localScale = base
                    end
                end)
            elseif phases then
                -- 多段关键帧：起始位由 cfg.from 给定，之后每段的目标/时长/缓动都来自 phases
                RunPhases(self, tf, base, phases, cfg.delay + order * step)
            else
                local rise = tf:DOScale(base * cfg.peak, cfg.riseDuration)
                rise:SetDelay(cfg.delay + order * step)
                SetEaseSafe(rise, "OutQuad")
                self.tweens[#self.tweens + 1] = rise
                rise:OnComplete(function()
                    -- 中途被 Kill 时 OnComplete 不回调，回落段也就不会再建
                    if not Alive(tf) then
                        return
                    end
                    local fall = tf:DOScale(base, cfg.fallDuration)
                    SetEaseSafe(fall, "InOutQuad")
                    self.tweens[#self.tweens + 1] = fall
                    fall:OnComplete(function()
                        if Alive(tf) then
                            tf.localScale = base
                        end
                    end)
                end)
            end
            order = order + 1
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把 item 留在半截缩放上
        LogError("ItemPopIn: 入场动画失败 " .. tostring(err))
        self:Stop()
    end
    return count
end

--============================== 页面级批量接入 ==============================
-- 面板只关心「什么时候播」，找列表交给这里：
--   ① 扫页面表里的 ScrollCycleView（字段名随意，scrollView / ScrollView / noviceScrollView 都认）；
--      quick_class 的 `local this = Class` 写法把字段写在类表上，实例通过 __index 取，
--      所以实例表、page.class、metatable.__index 三处都要扫；
--   ② 页面实现 GetPopInSource() 返回容器 / 数组 / ScrollCycleView（手工克隆、不是 ScrollCycleView 的列表）。
-- 都没有就什么都不做 ⇒ 面板可以对每个页签无脑调用，不用维护「哪些页签有列表」的名单。
--
-- ⚠️ 列表有可能是异步填的：Expert_UpLv / BoxPool 的 OnShow 要等数据回调才造 item，
--    而面板切页签是同步调 PlayPage 的 ⇒ 这一轮扫到 0 个就按 kRetryDelays 再扫几轮。
--    有列表就播、一直没有就静默收工（没列表的页签最多白扫 3 次，代价可以忽略）。
local pagePops = setmetatable({}, { __mode = "k" })
local kRetryDelays = { 0.1, 0.25, 0.5 }

-- ScrollCycleView 的特征是 SetData + ForeachItemGO。用 duck typing 而不是 require，
-- 免得 Common 反向依赖 View。
local function IsListView(v)
    return type(v) == "table" and type(v.SetData) == "function" and type(v.ForeachItemGO) == "function"
end

local function ScanForList(tbl, out, scanned, added)
    if type(tbl) ~= "table" or scanned[tbl] then
        return
    end
    scanned[tbl] = true
    for _, v in pairs(tbl) do
        if IsListView(v) and not added[v] then
            added[v] = true
            out[#out + 1] = v
        end
    end
end

local function CollectGetters(page)
    local out, scanned, added = {}, {}, {}
    ScanForList(page, out, scanned, added)
    local cls = page.class
    if type(cls) == "table" then
        ScanForList(cls, out, scanned, added)
    end
    local mt = getmetatable(page)
    if type(mt) == "table" then
        ScanForList(mt.__index, out, scanned, added)
    end
    if type(page.GetPopInSource) == "function" then
        out[#out + 1] = function()
            return page:GetPopInSource()
        end
    end
    local getters = {}
    for i = 1, #out do
        local src = out[i]
        if type(src) == "function" then
            getters[i] = src
        else
            getters[i] = function()
                return src
            end
        end
    end
    return getters
end

local function PlayAll(pops)
    local n = 0
    for i = 1, #pops do
        n = n + pops[i]:Play()
    end
    return n
end

--- 播放页面里所有长列表，返回接上的列表个数（0 = 这一页没有列表，正常）。
--- 这一轮扫到 0 个 item 时会按 kRetryDelays 自动重试，所以异步建列表的页也能播上。
--- cfg 只在第一次调用时生效：之后复用第一次建的那批 popIn。
function ItemPopIn.PlayPage(page, cfg)
    if type(page) ~= "table" then
        return 0
    end
    local entry = pagePops[page]
    if not entry then
        entry = { pops = {}, gen = 0 }
        local getters = CollectGetters(page)
        for i = 1, #getters do
            entry.pops[i] = ItemPopIn.New(getters[i], cfg)
        end
        pagePops[page] = entry
    end
    -- 每次调用都是一「轮」：重播会让上一轮还没跑的重试作废（否则切页后又弹一次旧的）
    entry.gen = entry.gen + 1
    local gen = entry.gen
    if entry.timer then
        entry.timer:Stop()
        entry.timer = nil
    end
    local played = 0
    local function attempt(step)
        if entry.gen ~= gen then
            return
        end
        played = PlayAll(entry.pops)
        if played > 0 then
            return
        end
        local wait = kRetryDelays[step]
        if not wait or type(Timer) ~= "table" or type(Timer.New) ~= "function" then
            return
        end
        local timer = Timer.New(function()
            entry.timer = nil
            attempt(step + 1)
        end, wait)
        entry.timer = timer
        timer:Start()
    end
    attempt(1)
    return #entry.pops
end

--- 回收页面里所有长列表（Kill + 复位）。切页 / 关闭 / 销毁都要走这里。
--- 🔴 漏调 = 那一页的 item 永久停在半截缩放上。
function ItemPopIn.StopPage(page)
    local entry = type(page) == "table" and pagePops[page]
    if not entry then
        return
    end
    -- 作废还没跑的重试：关掉面板后不能在隐藏页上再弹一次
    entry.gen = entry.gen + 1
    if entry.timer then
        entry.timer:Stop()
        entry.timer = nil
    end
    for i = 1, #entry.pops do
        entry.pops[i]:Stop()
    end
end

return ItemPopIn
