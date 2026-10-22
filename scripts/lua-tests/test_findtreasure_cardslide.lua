-- 离线验证 FindTreasureMainPanel 的任务卡入场动画（不依赖 Unity）：
-- 用假 Util / config / DOTween / 事件总线跑**真源码**，且走真实接线
-- （InitComponent → AddListener → OnOpen → OnShow → OnShowPanelData）：
--   ① 入场              每张卡的可视子节点一起从右侧 +260 滑回原位（0.26s / 错开 0.055）
--                       + 底板 BG/Image_BG1 淡入 0.3647（BG 容器自己没有 Image ⇒ 第四种底板形态）
--   ② 完成恢复          anchoredPosition 与 alpha 精确回到基准值
--   ③ 中途 Stop         Kill 后必须全复位（不能停在半截位置/半透明）
--   ④ 状态显隐          getButton / jumpButton / quickGetButton / consumeObj / timeObject
--                       按任务状态互斥显隐，未激活的不参与（每卡 tween 数随状态变）
--   ⑤ 空数据            missionInfo 为空 / GetTypeTaskList 返回 nil，不报错
--   ⑥ 生命周期          OnClose / OnDestroy 都要回收
--   ⑦ 入场闸门          OnOpen 置 needCardSlide ⇒ OnShow 播；事件刷新
--                       （GameEvent.FindTreasure.RefreshFindTreasure）不播且会 Stop 上一轮
--   ⑧ 闸门早退安全      GetTypeTaskList 返回 nil 提前 return，标记也不漏到下次刷新
--   ⑨ 连点保护          上一轮没播完时只复位、不重播；Stop / 播完之后能再触发
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_findtreasure_cardslide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/FindTreasure/FindTreasureMainPanel.lua"

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
        if self.kind == "posx" then
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

local function newGraphic(cls)
    local g = { cls = cls, color = { r = 1, g = 1, b = 1, a = 1 }, sprite = nil, text = "", value = 0 }
    function g:DOFade(v, dur) return newTween(self, v, dur, "fade") end
    return g
end

-- 卡的可视子节点在 prefab 里的实测坐标（FindTreasureMainPanel.prefab / rewardPre1）
local NAME_POS = {
    BG = { 0, 0 },        titleImage = { -60, 60 },  content = { 320, 20 },
    getButton = { 380, 0 }, jumpButton = { 380, 0 }, quickGetButton = { 380, 0 },
    consumeObj = { 380, 10 }, timeObject = { 0, 0 },  getFinishText = { 380, 0 },
}
local CARD_NODES = { "BG", "titleImage", "content", "getButton", "jumpButton",
                     "quickGetButton", "consumeObj", "timeObject", "getFinishText" }

local nodeSeq = 0
local function makeNode(name)
    nodeSeq = nodeSeq + 1
    local o = { name = name .. "#" .. nodeSeq, rawname = name, activeSelf = true,
                childCount = 0, anchoredPosition = { x = 0, y = 0 }, graphics = {} }
    o.children, o.order = {}, {}
    o.transform = o
    o.gameObject = o
    local pos = NAME_POS[name]
    if pos then o.anchoredPosition = { x = pos[1], y = pos[2] } end
    function o:GetComponent(cls)
        if cls == "RectTransform" or cls == "Transform" then return self end
        if not self.graphics[cls] then
            self.graphics[cls] = newGraphic(cls)
        end
        return self.graphics[cls]
    end
    function o:SetActive(v) self.activeSelf = v and true or false end
    function o:DOAnchorPosX(v, dur) return newTween(self, v, dur, "posx") end
    function o:AddChild(c)
        self.children[c.rawname] = c
        self.order[#self.order + 1] = c
        self.childCount = #self.order
        return c
    end
    function o:Find(path)
        local cur = self
        for name in path:gmatch("[^/]+") do
            if not cur.children[name] then
                -- 兼容「AddChild 之后才改名」的节点（OnShowPanelData 里 go.name = "rewardPre"..i）
                for _, c in ipairs(cur.order) do
                    if c.name == name then cur.children[name] = c break end
                end
            end
            if not cur.children[name] then cur:AddChild(makeNode(name)) end
            cur = cur.children[name]
            if not cur then return nil end
        end
        return cur
    end
    function o:SetParent(parent)
        if parent and parent.AddChild then parent:AddChild(self) end
        return self
    end
    return o
end

-- Util.GetGameObject 复刻 C# FindChild 语义：先 root.Find(path)，路径逐段走
Util = {
    GetGameObject = function(root, path)
        local base = (type(root) == "table" and rawget(root, "transform")) or root
        if base and base.Find then return base:Find(path) end
        return nil
    end,
    AddClick = function() end,
    AddOnceClick = function() end,
    LoadSprite = function() return { loaded = true } end,
    SetGray = function() end,
    AddParticleSortLayer = function() end,
}

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { one = { x = 1, y = 1, z = 1 }, New = function(x, y, z) return { x = x, y = y, z = z } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { OutQuad = "OutQuad", Linear = "Linear" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
GetLanguageStrById = function(id) return "L" .. tostring(id) end
GetResourcePath = function(id) return "res_" .. tostring(id) end
GetTimeStamp = function() return 0 end
PrintWanNum3 = function(n) return tostring(n) end
function Inherit(base) return setmetatable({}, { __index = base }) end
function newObject(tpl) return makeNode("rewardPre") end

Timer = { New = function(...) return { Stop = function() end, Start = function() end } end }

-- 事件总线：让 AddListener / DispatchEvent 真正连通（测「事件刷新不播入场」）
GameEvent = { FindTreasure = { RefreshFindTreasure = 1 }, Task = { Achievement = 2 },
              RedPoint = { TrainTask = 3 }, CloseUI = { OnClose = 4 } }
Game = { GlobalEvent = {} }
do
    local listeners = {}
    function Game.GlobalEvent:AddEvent(ev, fn, inst)
        listeners[ev] = listeners[ev] or {}
        listeners[ev][#listeners[ev] + 1] = { fn = fn, inst = inst }
    end
    function Game.GlobalEvent:RemoveEvent(ev, fn, inst)
        local l = listeners[ev]
        if not l then return end
        for i = #l, 1, -1 do
            if l[i].fn == fn and l[i].inst == inst then table.remove(l, i) end
        end
    end
    function Game.GlobalEvent:DispatchEvent(ev, ...)
        local l = listeners[ev]
        if not l then return end
        for i = 1, #l do l[i].fn(l[i].inst, ...) end
    end
end

-- 配置行：预置关键字段，其余走 __index = 0（别让 #row 在 load/刷新路径上炸）
local function cfgRow(fields)
    local base = fields or {}
    return setmetatable({}, {
        __index = function(_, k) return base[k] ~= nil and base[k] or 0 end,
    })
end
local cfgMazeTreasure = cfgRow({ Desc = 10660, TaskType = 1, Reward = {},
                                 TakeItem = { 1, 2 }, SpeedUpTake = { 1, 2 },
                                 WasteTime = 100, Condition = {} })
local cfgMazeSetting = cfgRow({ RefreshItem = { 5, 2 }, Cost = { { 1, 1, 1, 1 } } })
local cfgItem = cfgRow({ ResourceID = 1, Name = 10650 })
local cfgPlayerLevel = cfgRow({ MazeTreasureMax = 100 })
ConfigName = { MazeTreasure = 1, MazeTreasureSetting = 2, ItemConfig = 3, PlayerLevelConfig = 4 }
ConfigManager = {
    GetConfigData = function(name, id)
        if name == ConfigName.MazeTreasure then return cfgMazeTreasure end
        if name == ConfigName.MazeTreasureSetting then return cfgMazeSetting end
        if name == ConfigName.ItemConfig then return cfgItem end
        if name == ConfigName.PlayerLevelConfig then return cfgPlayerLevel end
        return cfgRow()
    end,
}

TaskTypeDef = { FindTreasure = 7 }
-- 任务数据由测试用例注入（GetTypeTaskList 返回什么，missionInfo 就是什么）
local fakeTasks = {}
TaskManager = {
    SetFindTreasureDataState = function() end,
    GetTypeTaskList = function(typeId)
        if typeId ~= TaskTypeDef.FindTreasure then return nil end
        return fakeTasks
    end,
    RefreshFindTreasureStatrData = function() end,
    RefreshFindTreasureData = function() end,
}

FindTreasureManager = { materialItemId = 16, refreshTicketItemId = 17,
                        SetShowFindTreasureVipRedPoint = function() end,
                        GetShowFindTreasureVipRedPoint = function() return false end,
                        FindTreasureGaoId = 1, FindTreasureHaoId = 2 }
FindTreasureVipTypeSprite = { [1] = "vip1", [2] = "vip2", [3] = "vip3" }
FindTreasureMissionTitleTypeStr = { [1] = "T1", [2] = "T2", [3] = "T3",
                                    [4] = "T4", [5] = "T5", [6] = "T6" }
PrivilegeManager = { GetPrivilegeOpenStatus = function() return false end }
PRIVILEGE_TYPE = { GoFindTreasure = 1, HaoFindTreasure = 2 }
BagManager = { GetItemCountById = function() return 1 end }
PlayerManager = { missingRefreshCount = 0, level = 60, maxForce = 1000 }

SubUIConfig = { ItemView = 1 }
SubUIManager = {
    Open = function() return { SetEffectLayer = function() end, OnOpen = function() end,
                               gameObject = makeNode("ItemView") } end,
    Close = function() end,
}

UIManager = { OpenPanel = function() end }
UIName = { RewardItemPopup = 1, RewardItemSingleShowPopup = 2, HelpPopup = 3,
           FindTreasureVipPopup = 4, FindTreasureDispatchPanel = 5 }
HELP_TYPE = { FindTreasure = 1 }
PopupTipPanel = { ShowTip = function() end, ShowTipByLanguageId = function() end }
MsgPanel = { ShowTwo = function() end }
NetManager = { TakeMissionRewardRequest = function() end,
               FindTreasureRefreshRequest = function() end,
               FindTreasureMissingRoomAccelerateRequest = function() end,
               FindTreasureMissingRoomSendHeroRequest = function() end }
HeroManager = { GetFingTreasureAllHeroDatas = function() return {} end }
FindTreasureNeedType = { Star = 1, Pro = 2 }
RedPointType = setmetatable({}, { __index = function() return 0 end })

local fakeModule = setmetatable({}, { __index = function() return function() end end })
function require(path) return fakeModule end

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()

-- 真实接线：InitComponent → AddListener → OnOpen → OnShow
local panelRoot = makeNode("FindTreasureMainPanel")
local function hookNode(name)
    return Util.GetGameObject(panelRoot, name)
end
Panel.gameObject = panelRoot
Panel:InitComponent()
Panel:BindEvent()
Panel:AddListener()

-- 任务行：state 语义 0=派遣中/未派遣 1=可领取；heroId 空表=未派遣
local function mission(state, heroN, progress)
    return { state = state, heroId = heroN and {} or {},
             missionId = 700001, progress = progress or 0 }
end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

local function assertBase(card, tag)
    for _, name in ipairs(CARD_NODES) do
        local n = Util.GetGameObject(card, name)
        local b = NAME_POS[name]
        assert(n.anchoredPosition.x == b[1] and n.anchoredPosition.y == b[2],
               ("%s: %s 应回到 (%s,%s)，实际 (%.2f,%.2f)"):format(tag, name, b[1], b[2],
                   n.anchoredPosition.x, n.anchoredPosition.y))
    end
    local plate = Util.GetGameObject(card, "BG/Image_BG1")
    assert(plate:GetComponent("Image").color.a == 1, tag .. ": 底板 alpha 应回 1")
end

-- ---------------- case 1: OnOpen → OnShow 真实链路，三卡入场 ----------------
print("== case1 OnOpen→OnShow 入场（3 卡，混合状态）==")
fakeTasks = {
    mission(1),                       -- 可领取：getButton
    mission(0),                       -- 未派遣：jumpButton + consumeObj
    mission(0, true, 999999),         -- 派遣中：quickGetButton + timeObject
}
Panel:OnOpen()
assert(Panel.needCardSlide == true, "OnOpen 应置入场标记")
Panel:OnShow()
assert(Panel.needCardSlide == false, "OnShowPanelData 应消费入场标记")

local cards = {}
for i = 1, 3 do
    cards[i] = Util.GetGameObject(panelRoot, "rect/rect1/grid/rewardPre" .. i)
    assert(cards[i] and cards[i].activeSelf, "rewardPre" .. i .. " 应被激活")
end
-- 卡1 state=1：BG/titleImage/content/getButton 4 位移 + 1 淡入 = 5
-- 卡2 state=0 无派遣：BG/titleImage/content/jumpButton/consumeObj 5 + 1 = 6
-- 卡3 state=0 已派遣：BG/titleImage/content/quickGetButton/timeObject 5 + 1 = 6
assert(#tweens == 17, "3 卡应共 17 条 tween，实际 " .. #tweens)
for ci, card in ipairs(cards) do
    for _, name in ipairs(CARD_NODES) do
        local n = Util.GetGameObject(card, name)
        local b = NAME_POS[name]
        if n.activeSelf then
            assert(n.anchoredPosition.x == b[1] + 260,
                   ("卡%d %s 起点应为 x+260，实际 %.1f"):format(ci, name, n.anchoredPosition.x))
        else
            -- 未激活的子节点（按状态互斥显隐）不该被动
            assert(n.anchoredPosition.x == b[1],
                   ("卡%d 未激活的 %s 不该被动"):format(ci, name))
        end
        assert(n.anchoredPosition.y == b[2], "卡" .. ci .. " " .. name .. " 的 y 不该被动")
    end
    local plate = Util.GetGameObject(card, "BG/Image_BG1")
    assert(math.abs(plate:GetComponent("Image").color.a - 0.3647) < 1e-6,
           "卡" .. ci .. " 底板淡入起点应为 0.3647")
    assert(card.anchoredPosition.x == 0, "卡根节点不能被动（VerticalLayoutGroup 会重写它）")
end
for _, t in ipairs(tweens) do
    assert(t.dur == 0.26, "单卡时长应为 0.26")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
end
local function delayOf(card, path)
    for _, t in ipairs(tweens) do
        if t.kind == "posx" and t.tf == Util.GetGameObject(card, path) then return t.delay end
    end
end
assert(delayOf(cards[1], "BG") == 0, "卡1 应立即起播")
assert(math.abs(delayOf(cards[2], "BG") - 0.055) < 1e-6, "卡2 应错开 0.055")
assert(math.abs(delayOf(cards[3], "BG") - 0.11) < 1e-6, "卡3 应错开 0.11")
print("  3 卡 17 条 tween：x+260 / 0.26s / 错开 0.055，底板 0.3647，卡根未动")

-- ---------------- case 2: 完成恢复 ----------------
print("== case2 完成后精确回基准值 ==")
for _, t in ipairs(tweens) do t:Complete() end
for _, card in ipairs(cards) do assertBase(card, "完成后") end
print("  位置/颜色全复位")

-- ---------------- case 3: 中途 Stop ----------------
print("== case3 中途 Stop 全复位 ==")
tweens = {}
assert(Panel.PlayCardSlideIn() == 3, "重播应覆盖 3 张卡")
Panel.StopCardSlideIn()
assert(liveTweens() == 0, "Stop 后不该有存活 tween")
for _, card in ipairs(cards) do assertBase(card, "Stop 后") end
print("  Kill + 位置/颜色全复位")

-- ---------------- case 4: 事件刷新不播入场（且会 Stop 上一轮） ----------------
print("== case4 GameEvent.FindTreasure.RefreshFindTreasure 刷新不播 ==")
Panel.PlayCardSlideIn()
local before = #tweens
Game.GlobalEvent:DispatchEvent(GameEvent.FindTreasure.RefreshFindTreasure, true)
assert(#tweens == before, "事件刷新不该新建 tween，实际新增 " .. (#tweens - before))
assert(liveTweens() == 0, "事件刷新应 Stop 上一轮的存活 tween")
for _, card in ipairs(cards) do assertBase(card, "事件刷新后") end
print("  0 条新 tween，上一轮已复位")

-- ---------------- case 5: 闸门早退安全（GetTypeTaskList 返回 nil） ----------------
print("== case5 提前 return 时标记不漏到下次刷新 ==")
fakeTasks = nil
Panel:OnOpen()
assert(Panel.needCardSlide == true, "OnOpen 置标记")
Panel:OnShow()   -- temp == nil 提前 return
assert(Panel.needCardSlide == false, "提前 return 也应消费标记")
assert(#tweens == before, "不该产生新 tween")
print("  标记已消费，不会漏到下次数据刷新")

-- ---------------- case 6: 空任务列表不报错 ----------------
print("== case6 空任务列表 ==")
tweens = {}
fakeTasks = {}
Panel:OnOpen()
Panel:OnShow()
assert(#tweens == 0, "空列表不该有 tween")
assert(Panel.PlayCardSlideIn() == 0, "空列表 Play 应返回 0")
print("  返回 0，不报错")

-- ---------------- case 7: 连点保护 ----------------
print("== case7 连点不叠播 ==")
fakeTasks = { mission(1), mission(1) }
Panel:OnOpen()
Panel:OnShow()
assert(#tweens == 10, "2 张 state=1 的卡应 10 条，实际 " .. #tweens)
local n0 = #tweens
assert(Panel.PlayCardSlideIn() == 0, "上一轮播中再请求应返回 0")
assert(#tweens == n0, "不该新建 tween")
for _, card in ipairs(cards) do assertBase(card, "连点中断后") end
print("  返回 0，0 条新 tween，位置已回终值")

-- ---------------- case 8: Stop / 自然播完后能再触发 ----------------
print("== case8 之后还能再触发 ==")
tweens = {}
assert(Panel.PlayCardSlideIn() == 2, "Stop 之后应能重新播")
Panel.StopCardSlideIn()
tweens = {}
assert(Panel.PlayCardSlideIn() == 2, "Stop 后应能重播")
for _, t in ipairs(tweens) do t:Complete() end
tweens = {}
assert(Panel.PlayCardSlideIn() == 2, "自然播完之后应能重新播")
assert(#tweens == 10, "应新建 10 条，实际 " .. #tweens)
print("  Stop 后 / 自然播完后都能重播")

-- ---------------- case 9: 生命周期回收 ----------------
print("== case9 OnClose / OnDestroy 回收 ==")
Panel.StopCardSlideIn()
tweens = {}
Panel.PlayCardSlideIn()
Panel:OnClose()
assert(liveTweens() == 0, "OnClose 后不该有存活 tween")
for _, card in ipairs(cards) do assertBase(card, "OnClose 后") end
tweens = {}
Panel.PlayCardSlideIn()
Panel:OnDestroy()
assert(liveTweens() == 0, "OnDestroy 后不该有存活 tween")
assert(Panel.needCardSlide == false, "OnDestroy 应清入场标记")
print("  两处都回收")

print("ALL OK")
