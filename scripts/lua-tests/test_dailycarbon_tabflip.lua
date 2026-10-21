-- 离线验证 DailyCarbonPanel 的**页签翻入**（不依赖 Unity）：
-- 用假 Util / DOTween / 组件表 + **真 TabBox**（真克隆流程）跑真源码，覆盖
--   ① PlayTabFlipIn      按 GetTabList 顺序逐格 scaleX 0→1，0.167s/格、错开 0.033s
--   ② Animator 通道      每格 CommonButton 的 Animator 必须临时 enabled=false，完成后恢复
--   ③ 完成 / Stop 复位   scale 回 1、Animator 恢复、高亮板复位，Kill 后不留存活 tween
--   ④ 压缩错开           格数多时末格延迟压到 0.5
--   ⑤ PlayTabSelectFlip  只翻「激活的高亮板」；tabAnimReady / suppressOpenAnim 两道闸门
--   ⑥ 真实调用链         OnTabChange 末尾确实翻高亮板；数据刷新（抑制）时不翻
--   ⑦ 生命周期           OnClose / OnDestroy 必须回收
--   ⑧ 空列表             GetTabList 为空 / TabCtrl 缺失都返回 0，不报错
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_dailycarbon_tabflip.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Carbon/DailyCarbonPanel.lua"
local TABBOX = ROOT .. "Assets/ManagedResources/~Lua/Modules/Common/TabBox.lua"

-- ---------------- stubs ----------------
local tweens = {}
local function newTween(tf, endv, dur, kind)
    local t = { tf = tf, endv = endv, dur = dur, kind = kind,
                delay = 0, ease = nil, onComplete = nil, killed = false }
    function t:SetDelay(d) self.delay = d; return self end
    function t:SetEase(e) self.ease = e; return self end
    function t:OnComplete(cb) self.onComplete = cb; return self end
    function t:Kill() self.killed = true end
    function t:Complete()
        if self.killed then return end
        if self.kind == "scale" then
            self.tf.localScale = self.endv
        elseif self.kind == "posx" then
            self.tf.anchoredPosition = { x = self.endv, y = self.tf.anchoredPosition.y }
        else -- fade
            self.tf.color = { r = self.tf.color.r, g = self.tf.color.g,
                              b = self.tf.color.b, a = self.endv }
        end
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

local function newGraphic(a)
    local g = { color = { r = 1, g = 1, b = 1, a = a or 1 }, sprite = nil, text = "" }
    function g:DOFade(v, dur) return newTween(self, v, dur, "fade") end
    return g
end

local function newRect(name, active, hasAnimator)
    local o = { name = name, activeSelf = active ~= false, childCount = 0,
                localScale = { x = 1, y = 1, z = 1 },
                anchoredPosition = { x = 0, y = 0 }, graphics = {} }
    o.children, o.order = {}, {}
    o.transform = o
    o.gameObject = o
    o.anim = hasAnimator and { enabled = true } or nil
    function o:GetComponent(cls)
        if cls == "Animator" then return self.anim end
        if cls == "RectTransform" then return self end
        return self.graphics[cls]
    end
    function o:SetActive(v) self.activeSelf = v and true or false end
    function o:DOScale(v, dur) return newTween(self, v, dur, "scale") end
    function o:DOAnchorPosX(v, dur) return newTween(self, v, dur, "posx") end
    function o:AddChild(c)
        self.children[c.name] = c
        self.order[#self.order + 1] = c
        self.childCount = #self.order
        self.transform.childCount = self.childCount
        return c
    end
    function o:Find(path)
        local cur = self
        for n in path:gmatch("[^/]+") do
            cur = cur.children and cur.children[n]
            if not cur then return nil end
        end
        return cur
    end
    function o.transform:GetChild(i) return self.order[i + 1] end
    return o
end

-- tabbox：tab 模板（带 Animator，TabBox 会 SetActive(false)）+ box（VerticalLayoutGroup）
local tabbox = newRect("TabBox", true, false)
local template = newRect("tab", true, true)
local box = newRect("box", true, false)
tabbox:AddChild(template)
tabbox:AddChild(box)

-- 克隆体结构与 prefab 一致：select（高亮板，纯 Image）/ bg / LockImage / Redpot
newObjToParent = function(tpl, parent)
    local c = newRect(tpl.name, tpl.activeSelf, tpl.anim ~= nil)
    c:AddChild(newRect("select", true, false))
    local bg = c:AddChild(newRect("bg", true, false))
    bg.graphics.Image = newGraphic(1)
    c:AddChild(newRect("LockImage", false, false))
    c:AddChild(newRect("Redpot", true, false))
    parent:AddChild(c)
    return c
end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { one = { x = 1, y = 1, z = 1 }, zero = { x = 0, y = 0, z = 0 },
            New = function(x, y, z) return { x = x, y = y, z = z } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { Linear = "Linear", OutQuad = "OutQuad", InOutQuad = "InOutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
function Inherit(base) return setmetatable({}, { __index = base }) end

Util = {
    GetGameObject = function(root, path)
        local base = (type(root) == "table" and root.transform) or root
        if base and base.Find then return base:Find(path) end
        return nil
    end,
    ClearChild = function(t) t.order = {}; t.children = {}; t.childCount = 0 end,
    AddClick = function() end,
    AddOnceClick = function() end,
    LoadSprite = function() return nil end,
    SetGray = function() end,
}
GetPictureFont = function() return nil end

local function configRow()
    return setmetatable({}, { __index = function() return 0 end })
end
ConfigManager = {
    GetConfig = function() return setmetatable({}, { __index = function() return configRow() end }) end,
    GetConfigData = function() return configRow() end,
    GetAllConfigsDataByKey = function() return {} end,
    GetConfigDataByKey = function() return configRow() end,
    GetConfigDataByDoubleKey = function() return configRow() end,
}
ConfigName = { DailyChallengeConfig = 1, MainLevelConfig = 2, ItemConfig = 3,
               SpecialConfig = 4, StoreConfig = 5 }
FUNCTION_OPEN_TYPE = setmetatable({}, { __index = function() return 0 end })
GetLanguageStrById = function() return "" end
SubUIManager = { Open = function() return { SetData = function() end } end,
                 Close = function() end }
SubUIConfig = { ScrollCycleView = 1, PlayerHeadFrameView = 2, UpView = 3 }
Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end } }
GameEvent = { FiveAMRefresh = { ServerNotifyRefresh = 1 } }
CarbonManager = { GetDailyCarbons = function() return {} end, IsDailyCarbonPass = function() return false end }
SoundManager = { PlayMusic = function() end }
SoundConfig = { Sound_UICancel = 1, BGM_Carbon = 2 }
CheckRedPointStatus = function() end
RedPointType = { HeroExplore = 1 }
PopupTipPanel = { ShowTip = function() end, ShowTipByLanguageId = function() end }
UpViewOpenType = { ShowRight = 1 }
PanelType = { Main = 1 }
ActTimeCtrlManager = { SingleFuncState = function() return true end,
                       SystemOpenTip = function() return "" end }

local realRequire = require
function require(path)
    if path == "Modules/Common/TabBox" then
        return assert(loadfile(TABBOX))()
    end
    return setmetatable({}, { __index = function() return function() end end })
end

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()
Panel.tabBox = tabbox
Panel.TabCtrl = require("Modules/Common/TabBox").New()

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- 面板组件注入（真机由 InitComponent 赋值）：Init_SetTabAndBox 末尾会立刻回调一次 OnTabChange，
-- 所以这些必须在 Init 之前就位
Panel.bg = newGraphic(1)
Panel.titleIcon = newGraphic(1)
Panel.titleText = { text = "" }
Panel.titleFontBg = newGraphic(1)
Panel.titleFont = { text = "" }
Panel.timeTip = { text = "" }
Panel.sweepBtn = newRect("sweepBtn", true, false)
local listView = { items = {} }
function listView:SetData() end
function listView:ForeachItemGO() end
function listView:SetIndex() end
Panel.scrollView = listView
-- SetTimeTip 要读 curData[1].PrivilegeId（真实配置表数据），与本用例无关 ⇒ 打桩
Panel.SetTimeTip = function() end

-- 真机在 OnShow 里就是这五行（_TabData 是模块内 local，这里用同长度的空表）
Panel.TabCtrl:SetTabAdapter(Panel.TabAdapter)
Panel.TabCtrl:SetTabIsLockCheck(Panel.TabIsLockCheck)
Panel.TabCtrl:SetChangeTabCallBack(Panel.OnTabChange)
Panel.TabCtrl:Init_SetTabAndBox(tabbox, { {}, {}, {}, {}, {} }, 1,
    Util.GetGameObject(tabbox, "tab"), Util.GetGameObject(tabbox, "box"))

local tabs = Panel.TabCtrl:GetTabList()
assert(#tabs == 5, "应克隆 5 个页签（TabBox 走 Init_SetTabAndBox，TabList 必须有值），实际 " .. #tabs)
assert(template.activeSelf == false, "模板 tab 必须被 TabBox 藏起来")
assert(tabs[1].children.select.activeSelf == true, "默认页的高亮板应打开")
assert(tabs[2].children.select.activeSelf == false, "非默认页的高亮板应关闭")

-- ---------------- case 1: 打开时逐格翻入 ----------------
print("== case1 PlayTabFlipIn ==")
tweens = {}
local n = Panel.PlayTabFlipIn()
assert(n == 5, "应翻 5 格，实际 " .. tostring(n))
assert(#tweens == 5, "应有 5 条翻入 tween，实际 " .. #tweens)
assert(template.localScale.x == 1, "模板 tab 不该被动")
for i, go in ipairs(tabs) do
    assert(go.localScale.x == 0, "页签应置 0: " .. i)
    assert(go.localScale.y == 1 and go.localScale.z == 1, "只该压 x 轴: " .. i)
    assert(go.anim.enabled == false, "翻入期间应关掉 CommonButton 的 Animator: " .. i)
end
for i, t in ipairs(tweens) do
    local want = (i - 1) * 0.033
    assert(math.abs(t.delay - want) < 1e-6, ("第 %d 个延迟 %s != %s"):format(i, t.delay, want))
    assert(t.dur == 0.167, "时长应为参考的 0.167")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
    assert(t.tf == tabs[i], "tween 应按 GetTabList 顺序绑定")
end
print("  5 格，延迟 0 / 0.033 / 0.066 / 0.099 / 0.132，单格 0.167s")

-- ---------------- case 2: 完成恢复 ----------------
print("== case2 完成后恢复 ==")
for _, t in ipairs(tweens) do t:Complete() end
for i, go in ipairs(tabs) do
    assert(go.localScale.x == 1, "结束后 scale 应回 1: " .. i)
    assert(go.anim.enabled == true, "结束后 Animator 应恢复: " .. i)
end
print("  scale=1 / Animator 已恢复")

-- ---------------- case 3: 高亮板翻入 + 两道闸门 ----------------
print("== case3 PlayTabSelectFlip ==")
tweens = {}
Panel:PlayTabSelectFlip(1)
assert(#tweens == 1, "tabAnimReady 后应创建 1 条高亮 tween，实际 " .. #tweens)
local sel1 = tabs[1].children.select
assert(sel1.localScale.x == 0, "高亮板应从 0 起")
assert(tweens[1].dur == 0.167 and tweens[1].ease == Ease.OutQuad, "时长/ease 与页签同档")
tweens[1]:Complete()
assert(sel1.localScale.x == 1, "高亮板应回到 1")

tweens = {}
Panel:PlayTabSelectFlip(2)
assert(#tweens == 0, "未选中页的高亮板是隐藏的，不该起 tween，实际 " .. #tweens)
print("  只翻激活的高亮板（tab2 的 select 是关的 ⇒ 0 条）")

tweens = {}
Panel.suppressOpenAnim = true
Panel:PlayTabSelectFlip(1)
assert(#tweens == 0, "数据刷新期间不该翻高亮板")
Panel.suppressOpenAnim = false
print("  suppressOpenAnim 闸门生效")

-- ---------------- case 4: 中途 Stop 全复位 ----------------
print("== case4 StopTabFlipIn 全复位 ==")
tweens = {}
Panel.PlayTabFlipIn()
Panel:PlayTabSelectFlip(1)
Panel.StopTabFlipIn()
assert(liveTweens() == 0, "Stop 后不该有存活 tween，实际 " .. liveTweens())
for i, go in ipairs(tabs) do
    assert(go.localScale.x == 1, "Stop 后 scale 应为 1: " .. i)
    assert(go.anim.enabled == true, "Stop 后 Animator 应恢复: " .. i)
end
assert(sel1.localScale.x == 1, "高亮板 Kill 后必须复位到 1，否则永久停在半截")
tweens = {}
Panel:PlayTabSelectFlip(1)
assert(#tweens == 0, "Stop 之后 tabAnimReady 应为 false，闸门重新关上")
print("  Kill + scale/Animator/高亮板复位；闸门复位")

-- ---------------- case 5: 压缩错开 ----------------
print("== case5 压缩错开 ==")
tweens = {}
local saved = Panel.TabCtrl
Panel.TabCtrl = { GetTabList = function()
    local list = {}
    for i = 1, 24 do list[i] = newRect("t" .. i, true, true) end
    return list
end }
Panel.PlayTabFlipIn()
local last = tweens[#tweens]
assert(#tweens == 24, "应有 24 条，实际 " .. #tweens)
assert(math.abs(last.delay - 0.5) < 1e-6, ("24 格时末格延迟应压到 0.5，实际 %s"):format(last.delay))
print(("  24 格：首格 0 / 末格 %.3f / 含单格总时长 %.3f"):format(last.delay, last.delay + last.dur))
Panel.StopTabFlipIn()
Panel.TabCtrl = saved
tweens = {}

-- ---------------- case 6: 真实调用链（OnTabChange 末尾翻高亮板） ----------------
print("== case6 OnTabChange 调用链 ==")
-- 初始化那次回调发生在 tabAnimReady=false 时：这里先 Stop 复位闸门，再走一次真实 OnTabChange
Panel.StopTabFlipIn()
tweens = {}
Panel.OnTabChange(1)
assert(#tweens == 0, "页签未翻入（闸门关）时 OnTabChange 不该翻高亮板，实际 " .. #tweens)

Panel.PlayTabFlipIn()
tweens = {}
Panel.OnTabChange(1)
assert(#tweens == 1, "闸门开 + 高亮板激活 ⇒ OnTabChange 末尾应有 1 条，实际 " .. #tweens)
Panel.StopTabFlipIn()

Panel.PlayTabFlipIn()
tweens = {}
Panel.suppressOpenAnim = true                     -- 模拟 FiveRefresh 的包法
Panel.OnTabChange(1)
Panel.suppressOpenAnim = false
assert(#tweens == 0, "数据刷新（抑制）时 OnTabChange 不该翻高亮板，实际 " .. #tweens)
print("  闸门关 ⇒ 0 条；闸门开 ⇒ 1 条；抑制 ⇒ 0 条")

-- ---------------- case 7: 空列表 ----------------
print("== case7 空列表不报错 ==")
Panel.StopTabFlipIn()
Panel.TabCtrl = { GetTabList = function() return {} end }
assert(Panel.PlayTabFlipIn() == 0, "空 TabList 应返回 0")
Panel.TabCtrl = nil
assert(Panel.PlayTabFlipIn() == 0, "TabCtrl 缺失应返回 0")
Panel.TabCtrl = saved
print("  返回 0，不报错")

-- ---------------- case 8: 生命周期回收 ----------------
print("== case8 OnClose / OnDestroy 回收 ==")
tweens = {}
Panel.PlayTabFlipIn()
Panel:OnClose()
assert(liveTweens() == 0, "OnClose 后不该有存活 tween，实际 " .. liveTweens())
for i, go in ipairs(tabs) do
    assert(go.localScale.x == 1, "OnClose 后 scale 应为 1: " .. i)
    assert(go.anim.enabled == true, "OnClose 后 Animator 应恢复: " .. i)
end
tweens = {}
Panel.PlayTabFlipIn()
Panel:OnDestroy()
assert(liveTweens() == 0, "OnDestroy 后不该有存活 tween，实际 " .. liveTweens())
print("  两处都回收")

print("ALL OK")
