-- 挂机界面（FightPointPassMainPanel）子模块生命周期回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_fightpoint_panel_lifecycle.lua
--
-- 线上报错（2026-10-19 17:24）：
--   ① LuaException: The object of type 'UnityEngine.GameObject' has been destroyed ...
--        [C]: in function 'SetActive'
--        Modules/Fight/View/FightPointMapChatPanel:155: in function 'ChangeTabCallBack'
--        Modules/Common/TabBox:254: in function 'ChangeTab'
--        Modules/Fight/View/FightPointMapChatPanel:89: in function 'OnShow'
--        Modules/Fight/FightPointPassMainPanel:278: in function 'OnShow'
--   ② LuaException: event:172: attempt to index material on a nil value
--        Modules/Fight/View/FightPointMapOnHook:966: in function 'Update'
--        Modules/Fight/FightPointPassMainPanel:373: in function 'func'
--
-- 根因：
--   ① FightPointMapChatPanel / FightPointMapOnHook 都是**模块级单表**（require 缓存），
--      SubUIManager.Open 动态建出来的滚动列表挂在当前面板实例节点下。UIManager.DestroyPanel
--      （noDestory==0 的面板关闭 15s 后必销毁）把整棵子树带走后，this.ChatScrollView 这类
--      引用仍然存在（Lua 侧非 nil），指向的却是已销毁节点 ⇒ 再次 OnShow 时
--      TabBox:ChangeTab → OnTabChange 里 lastSV.gameObject:SetActive 抛异常。
--   ② OnShow 里建图/UpdateMap 排在 chatPanel:OnShow() 之后，①一抛错 OnShow 就断了，
--      fightOnHook:Init() 已经把 isPlay/isFindEnemy 置 true ⇒ 每帧 Update 拿上一轮已销毁的
--      MeshRenderer.material（已销毁时 GetComponent 返回 nil）去 GetFloat，报 "index material on nil"。
--
-- 这里用"Destroy 后 IsNull 为真、访问即抛 tolua 同款错误"的假节点驱动真源码。

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"

local failed = 0
local function Check(cond, msg)
    if cond then
        print("  ✅ " .. msg)
    else
        failed = failed + 1
        print("  ❌ " .. msg)
    end
end

----------------------------------------------------------------------
-- 1) 假节点：Destroy 后 IsNull 为真，SetActive / 索引 transform 抛 tolua 同款错误
----------------------------------------------------------------------
local DESTROYED_MSG = "The object of type 'UnityEngine.GameObject' has been destroyed but you are still trying to access it."

local function NewNode(name, extra)
    local node = { __name = name, __destroyed = false, rect = { height = 1100 } }
    for k, v in pairs(extra or {}) do
        node[k] = v
    end
    return setmetatable(node, {
        __index = function(t, k)
            if t.__destroyed then
                error(DESTROYED_MSG, 2)
            end
            if k == "transform" or k == "gameObject" then
                return t
            end
            if k == "SetActive" then
                return function()
                    if t.__destroyed then
                        error(DESTROYED_MSG, 2)
                    end
                    t.__active = true
                end
            end
            if k == "GetComponent" then
                return function()
                    return { anchoredPosition = nil, rect = { height = 1100 }, sortingOrder = 0 }
                end
            end
            return nil
        end,
    })
end

local function DestroyNode(node)
    if node then
        node.__destroyed = true
    end
end

function IsNull(obj)
    if obj == nil then
        return true
    end
    if type(obj) == "table" and obj.__destroyed ~= nil then
        return obj.__destroyed
    end
    return false
end

----------------------------------------------------------------------
-- 2) 全局桩
----------------------------------------------------------------------
Vector2 = { New = function(x, y)
    return { x = x, y = y }
end }
Vector3 = { New = function(x, y, z)
    return { x = x, y = y, z = z }
end }
Time = { deltaTime = 0.033, realtimeSinceStartup = 0 }

ConfigName = { ItemConfig = "ItemConfig", AfkSpeak = "AfkSpeak" }
ConfigManager = {
    GetConfig = function()
        return {}
    end,
    GetConfigData = function()
        return nil
    end,
}
CHAT_CHANNEL = { FRIEND = 1, FAMILY = 2, GLOBAL = 3, CrossRealm = 4, SYSTEM = 5 }
RedPointType = { Chat_Friend = 90001 }
SubUIConfig = { ScrollCycleView = { name = "ScrollCycleView" }, ScrollFitterView = { name = "ScrollFitterView" } }
PlayerManager = {}
ItemType = {}
FUNCTION_OPEN_TYPE = setmetatable({}, { __index = function(_, k)
    return k
end })
ActTimeCtrlManager = {
    SingleFuncState = function()
        return true
    end,
}

function GetLanguageStrById(id)
    return tostring(id)
end
function Log() end
function LogError(msg)
    print("     (LogError) " .. tostring(msg))
end
function BindRedPointObject() end
function ClearRedPointObject() end

Util = {
    GetGameObject = function(_, path)
        return NewNode("node:" .. tostring(path))
    end,
    AddClick = function() end,
    AddOnceClick = function() end,
    LoadSprite = function()
        return nil
    end,
}

ChatManager = {
    _TabData = {},
    ShowTimeDT = 60,
    GetChatList = function()
        return {}
    end,
    StartChatDataUpdate = function() end,
    StopChatDataUpdate = function() end,
    AnalysisGlobalChat = function()
        return { content = "", type = 0 }
    end,
    GetPlayerCountry = function()
        return nil
    end,
}

-- SubUIManager：每次 Open 都新建一个"子界面"，节点登记到 created 里方便批量销毁
local createdViews = {}
SubUIManager = {
    Open = function(config, parent, prefab, bar, size, a, b, c)
        local view = {
            gameObject = NewNode("SubUI:" .. tostring(config and config.name)),
            moveTween = {},
            data = nil,
        }
        view.SetData = function(_, datalist)
            view.data = datalist
        end
        view.SetIndex = function() end
        view.ForeachItemGO = function() end
        createdViews[#createdViews + 1] = view
        return view
    end,
    Close = function() end,
}

-- TabBox 行为对齐真实现：Init 里回调 (index, nil)，ChangeTab 里回调 (index, lastIndex)
package.preload["Modules/Common/TabBox"] = function()
    local TabBox = {}
    function TabBox.New()
        local o = {}
        function o.SetTabAdapter(self, f)
            self.TabAdapter = f
        end

        function o.SetTabIsLockCheck(self, f)
            self.TabIsLockCheck = f
        end

        function o.SetChangeTabCallBack(self, f)
            self.ChangeTabCallBack = f
        end

        function o.Init(self, gameObject, tabData, defaultSelect)
            self.TabData = tabData
            self.SelectIndex = defaultSelect or 1
            self.TabList = {}
            if self.ChangeTabCallBack then
                self.ChangeTabCallBack(self.SelectIndex)
            end
        end

        function o.ChangeTab(self, index)
            local lastIndex = self.SelectIndex
            self.SelectIndex = index
            if self.ChangeTabCallBack then
                self.ChangeTabCallBack(index, lastIndex)
            end
        end

        return o
    end
    return TabBox
end
package.preload["Modules/CountryRank/CountryFlagUtil"] = function()
    return { Apply = function() end }
end

----------------------------------------------------------------------
-- 3) [①] 聊天页签：面板实例销毁后重新打开不能访问已销毁的滚动列表
----------------------------------------------------------------------
print("[1] FightPointMapChatPanel：面板实例重建后 OnShow 不碰已销毁的滚动列表")
local ChatPanel = assert(loadfile(LUA_SRC .. "/Modules/Fight/View/FightPointMapChatPanel.lua"))()

-- 实例 A：完整走一遍 InitComponent -> BindEvent -> OnShow
local okA, errA = pcall(function()
    ChatPanel:InitComponent(NewNode("ChatPanel"))
    ChatPanel:BindEvent()
    ChatPanel:OnShow()
end)
Check(okA, "实例 A 正常打开" .. (okA and "" or ("（" .. tostring(errA) .. "）")))
local viewsAfterA = #createdViews
Check(ChatPanel.ChatScrollView ~= nil and ChatPanel.FriendScrollView ~= nil, "实例 A 建出了滚动列表")

-- 面板被 UIManager.DestroyPanel 销毁：整棵子树带走（模块表里的引用还在，指向已销毁节点）
for _, view in ipairs(createdViews) do
    DestroyNode(view.gameObject)
end

-- 实例 B：新面板实例（CreateUI -> InitComponent -> BindEvent -> OpenUI -> OnShow）
local okB, errB = pcall(function()
    ChatPanel:InitComponent(NewNode("ChatPanel"))
    ChatPanel:BindEvent()
    ChatPanel:OnShow()
end)
Check(okB, "实例 B 打开不抛异常" .. (okB and "" or ("（" .. tostring(errB) .. "）")))
Check(#createdViews > viewsAfterA, "实例 B 重新创建了滚动列表（旧引用被判废）")
local sv = ChatPanel.ChatScrollView
Check(sv ~= nil and not IsNull(sv.gameObject), "实例 B 的滚动列表指向存活节点")

print("[2] FightPointMapChatPanel：缓存没被清掉时也不抛异常（懒判定兜底）")
for _, view in ipairs(createdViews) do
    DestroyNode(view.gameObject)
end
-- 故意跳过 InitComponent，直接切页签：ChangeTab 会把 lastIndex 的滚动列表 SetActive(false)
local ok3, err3 = pcall(ChatPanel.OnTabChange, 3, 3)
Check(ok3, "OnTabChange 遇到已销毁的列表不抛异常" .. (ok3 and "" or ("（" .. tostring(err3) .. "）")))
Check(ChatPanel.ChatScrollView ~= nil and not IsNull(ChatPanel.ChatScrollView.gameObject),
    "OnTabChange 会重建已销毁的列表")

print("[3] FightPointMapChatPanel：OnDestroy 清缓存")
ChatPanel:OnDestroy()
Check(ChatPanel.ChatScrollView == nil and ChatPanel.FriendScrollView == nil and ChatPanel.SystemScrollView == nil,
    "OnDestroy 后滚动列表缓存已清空")

----------------------------------------------------------------------
-- 4) [②] 地图 UV：销毁后不能再拿 Material 去 GetFloat，且不能每帧 new 材质
----------------------------------------------------------------------
print("[4] FightPointMapOnHook：UpdateMap 只取一次 material（避免每帧 new 材质实例）")
package.preload["Modules/Battle/Config/FightEffectAudioConfig"] = function()
    return { GetAudioData = function()
        return nil
    end }
end
package.preload["Base.Bezier"] = function()
    return {}
end

local Hook = assert(loadfile(LUA_SRC .. "/Modules/Fight/View/FightPointMapOnHook.lua"))()

local materialAccessCount = 0
local function NewMeshChild(name)
    local material = { _time = 0, __destroyed = false }
    function material:GetFloat()
        if self.__destroyed then
            error(DESTROYED_MSG, 2)
        end
        return self._time
    end

    function material:SetFloat(_, v)
        if self.__destroyed then
            error(DESTROYED_MSG, 2)
        end
        self._time = v
    end

    local renderer = { __destroyed = false, _material = material }
    setmetatable(renderer, {
        __index = function(t, k)
            if k == "material" then
                materialAccessCount = materialAccessCount + 1
                return t._material
            end
            return nil
        end,
    })
    local child = NewNode(name, { renderer = renderer })
    child.GetComponent = function()
        return renderer
    end
    return child, material, renderer
end

local mapChildren, materials, renderers = {}, {}, {}
for i = 1, 3 do
    local child, material, renderer = NewMeshChild("map_child_" .. i)
    mapChildren[i] = child
    materials[i] = material
    renderers[i] = renderer
end
local map = NewNode("map", { childCount = #mapChildren })
map.transform = map
function map.GetChild(self, i)
    return mapChildren[i + 1]
end

local ok4, err4 = pcall(function()
    Hook:UpdateMap(map)
end)
Check(ok4, "UpdateMap 正常执行" .. (ok4 and "" or ("（" .. tostring(err4) .. "）")))
Check(materialAccessCount == 3, "每块地图只取一次 material（实际 " .. materialAccessCount .. " 次）")

local before = materials[1]._time
Hook:UpdateMapUV()
Hook:UpdateMapUV()
Check(math.abs(materials[1]._time - (before + Time.deltaTime * 2)) < 1e-6, "UpdateMapUV 每帧推进 _time")
Check(materialAccessCount == 3, "UpdateMapUV 不再重复取 material（累计 " .. materialAccessCount .. " 次）")

print("[5] FightPointMapOnHook：地图销毁后 Update 相关逻辑不报错且能自愈")
for i = 1, #materials do
    DestroyNode(materials[i])
    DestroyNode(renderers[i])
    DestroyNode(mapChildren[i])
end
DestroyNode(map)

local ok5, err5 = pcall(Hook.UpdateMapUV, Hook)
Check(ok5, "地图销毁后 UpdateMapUV 不抛异常" .. (ok5 and "" or ("（" .. tostring(err5) .. "）")))
local ok6, err6 = pcall(Hook.UpdateMapUV, Hook)
Check(ok6, "第二帧也不抛异常（缓存已自愈清空）" .. (ok6 and "" or ("（" .. tostring(err6) .. "）")))

local ok7, err7 = pcall(Hook.UpdateMap, Hook, nil)
Check(ok7, "UpdateMap(nil) 安全" .. (ok7 and "" or ("（" .. tostring(err7) .. "）")))
local ok8, err8 = pcall(Hook.UpdateMap, Hook, map)
Check(ok8, "UpdateMap(已销毁 map) 安全" .. (ok8 and "" or ("（" .. tostring(err8) .. "）")))
local ok9, err9 = pcall(Hook.UpdateMapUV, Hook)
Check(ok9, "UpdateMap 传入已销毁 map 后 UpdateMapUV 仍安全" .. (ok9 and "" or ("（" .. tostring(err9) .. "）")))

print("[6] FightPointMapOnHook：Dispose 清空地图渲染器缓存")
Hook:UpdateMap(map)
-- Dispose 会回收宝箱特效父节点、Spine 等，测试里补最小可用桩
Hook.boxEffectParent = NewNode("boxEffectParent")
Hook:Dispose()
local ok10, err10 = pcall(Hook.UpdateMapUV, Hook)
Check(ok10, "Dispose 后 UpdateMapUV 安全" .. (ok10 and "" or ("（" .. tostring(err10) .. "）")))

print("")
if failed > 0 then
    print("❌ 失败 " .. failed .. " 项")
    os.exit(1)
end
print("✅ 全部通过")
