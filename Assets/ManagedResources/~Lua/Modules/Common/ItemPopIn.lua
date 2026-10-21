--- 列表项入场：逐格「放大缩小」（Coin Master 式的礼包墙/榜单弹入）
---
--- 复用点：ValuePackPanel 的礼包墙、GrowthManual 的两个列表页（RewardPreview / TaskPreview）。
--- 数据源统一是 ScrollCycleView：它的 item 由 SetData 克隆并排在 grid 下，ForeachItemGO
--- 按数据下标给出 1..dataCount，顺序即版面顺序。
---
--- 用法（三步）：
---   local ItemPopIn = require("Modules/Common/ItemPopIn")
---   this.popIn = ItemPopIn.New(function() return this.ScrollView end)  -- InitComponent
---   this.popIn:Play()   -- 打开面板 / 切页（必须在 SetData 之后）
---   this.popIn:Stop()   -- OnClose / OnDestroy（🔴 不调 = item 永久停在半截缩放）
---
--- 可调项（New 的第二参，缺省即下面的 defaultCfg）：
---   from/peak          起始与峰值缩放
---   riseDuration       放大段时长，fallDuration 缩小回落时长
---   step               相邻 item 的间隔，maxSpan 是整体跨度上限（item 多时自动压缩 step）
local ItemPopIn = {}
local this = ItemPopIn

local defaultCfg = {
    from = 0.82,
    peak = 1.02,
    riseDuration = 0.14,
    fallDuration = 0.12,
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
-- 否则会白占一轮错开时间）
function this:_Collect()
    local targets = {}
    local scrollView = self.getScrollView and self.getScrollView()
    if not Alive(scrollView) or not scrollView.ForeachItemGO then
        return targets
    end
    local ok, err = pcall(function()
        scrollView:ForeachItemGO(function(_, go)
            if Alive(go) and go.activeSelf then
                targets[#targets + 1] = go.transform
            end
        end)
    end)
    if not ok then
        LogError("ItemPopIn: 遍历列表项失败 " .. tostring(err))
        return {}
    end
    return targets
end

-- 播放：每格 基准 → from → peak → 基准，相邻错开 step
function this:Play()
    self:Stop()
    local targets = self:_Collect()
    local count = #targets
    if count <= 0 then
        return
    end

    local cfg = self.cfg
    local step = cfg.step
    if count > 1 and step * (count - 1) > cfg.maxSpan then
        step = cfg.maxSpan / (count - 1)
    end

    local order = 0
    local ok, err = pcall(function()
        for i = 1, count do
            local tf = targets[i]
            local base = tf.localScale
            self.items[#self.items + 1] = { tf = tf, base = base }
            tf.localScale = base * cfg.from

            local rise = tf:DOScale(base * cfg.peak, cfg.riseDuration)
            rise:SetDelay(order * step)
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
            order = order + 1
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把 item 留在半截缩放上
        LogError("ItemPopIn: 入场动画失败 " .. tostring(err))
        self:Stop()
    end
end

return ItemPopIn
