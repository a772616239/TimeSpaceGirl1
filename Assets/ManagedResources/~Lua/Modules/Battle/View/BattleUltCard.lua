--[[
  大招入场小卡（缩小版 HelpHeroShow）
  ==========================================================================
  英雄释放大招的瞬间，把助战英雄展示框 HelpHeroShow 的缩小副本摆到对应角落：
  我方 camp 0 -> 左上角，敌方 camp 1 -> 右上角，随后大招攻击照常播放。
  按需求：卡片与攻击同时进行，不额外暂停战斗。

  不新增 prefab 节点：直接克隆 BattlePanel 下的 HelpHeroShow（含立绘挂点 live、
  名字 name、地点 location），缩放到 28% 后重挂锚点。立绘走 LoadHerolive，
  与助战英雄入场展示框同一套资源链路。

  注意：每个阵营各持一张卡（slots[camp]），敌我可能同时放大招，
  共用一张会互相覆盖、位置乱跳。
]]

BattleUltCard = {}
local this = BattleUltCard

-- 触发范围：true  = 只有「带特写」的大招（CombatControl.Closeup 有值的技能）；
--           false = 所有英雄的技能（CombatControl.SkillType == 2，普攻 SkillType == 1 不算）。
local REQUIRE_CLOSEUP = false

-- 敌我都弹，靠角落位置区分：我方左上角、敌方右上角
local ONLY_MY_CAMP    = false

local CARD_SCALE       = 0.22   -- 相对整屏版 HelpHeroShow 的缩放（0.28 的 0.8 倍 = 0.224）
local CARD_MARGIN_X    = 120    -- 卡片中心距左/右边缘的距离（相对技能栏锚点，随屏幕尺寸自适应）
local CARD_GAP_Y       = 8      -- 卡片顶边与技能栏底边的间隙（参考分辨率像素，CanvasScaler 统一缩放）
local CARD_CONTENT_TOP = 642.5  -- 卡片内容顶边相对卡片中心（缩放前，Image1 顶边 = pos.y 7 + 高 1271/2）
local CARD_FALLBACK_Y  = -520   -- 兜底：找不到技能栏时卡片中心的 Y（相对顶部锚点）
local CARD_SHOW_TIME   = 2.0    -- 停留时长（对齐特写 CloseupDuration = 2000ms）
local POP_IN_TIME     = 0.18
local POP_OUT_TIME    = 0.12

-- [camp] = { go, live, hero, timer, tween, lastKey, lastTime }
this.slots = {}
this.view = nil

local function IsAlive(go)
    return go ~= nil and not IsNull(go)
end

local function GetSlot(camp)
    local s = this.slots[camp]
    if not s then
        s = { camp = camp, lastTime = 0 }
        this.slots[camp] = s
    end
    return s
end

-- 该技能是否算「大招」；camp 传 nil 时不做阵营过滤
function this.IsUltSkill(combat, camp)
    if not combat then
        return false
    end
    if ONLY_MY_CAMP and camp ~= nil and camp ~= 0 then
        return false
    end
    if REQUIRE_CLOSEUP then
        local closeup = tonumber(combat.Closeup)
        return closeup ~= nil and closeup ~= 0
    end
    return tonumber(combat.SkillType) == 2
end

local function GetTemplate(view)
    if not view then
        return nil
    end
    local tpl = view.HelpHeroShow
    if IsAlive(tpl) then
        return tpl
    end
    -- 兜底：字段还没赋值时按名字找
    if IsAlive(view.gameObject) then
        local go = Util.GetGameObject(view.gameObject, "HelpHeroShow")
        if IsAlive(go) then
            view.HelpHeroShow = go
            return go
        end
    end
    return nil
end

-- 技能栏节点：我方 myRect_Skill（贴左），敌方 enemyRect_Skill（贴右）
local function GetSkillBar(view, camp)
    if not view or not IsAlive(view.transform) then
        return nil
    end
    local nodeName = (tonumber(camp) or 0) == 0 and "myRect_Skill" or "enemyRect_Skill"
    local ui = Util.GetGameObject(view.transform, nodeName)
    if not IsAlive(ui) then
        ui = Util.GetGameObject(view.transform, "myRect_Skill")
    end
    if not IsAlive(ui) then
        return nil
    end
    return ui
end

-- 卡片定位：跟随技能栏，不用屏幕绝对坐标，否则换分辨率/宽高比就会乱
--   锚点直接复制技能栏的（我方 left、敌方 right），X 只给「距边距离」；
--   Y = 技能栏底边 - 间隙 - 卡片内容半高，全部在技能栏的锚点空间里算
local function ApplyLayout(view, s, rt)
    local bar = GetSkillBar(view, s.camp)
    local barRt = bar and bar:GetComponent("RectTransform")
    rt.pivot = Vector2.New(0.5, 0.5)
    if not barRt then
        -- 兜底：拿不到技能栏才退回屏幕顶角绝对定位
        local ax = ((tonumber(s.camp) or 0) == 0) and 0 or 1
        rt.anchorMin = Vector2.New(ax, 1)
        rt.anchorMax = Vector2.New(ax, 1)
        local dx = ((tonumber(s.camp) or 0) == 0) and CARD_MARGIN_X or -CARD_MARGIN_X
        rt.anchoredPosition = Vector2.New(dx, CARD_FALLBACK_Y)
        LogRed("[UIFlow] 大招小卡定位兜底：找不到技能栏节点")
        return { x = dx, y = CARD_FALLBACK_Y }
    end

    rt.anchorMin = barRt.anchorMin
    rt.anchorMax = barRt.anchorMax
    -- 技能栏底边（相对其锚点参考点）；pivot.y 通常是 0.5，用配置值算，不写死
    local barBottom = barRt.anchoredPosition.y - barRt.pivot.y * barRt.sizeDelta.y
    local centerY = barBottom - CARD_GAP_Y - CARD_CONTENT_TOP * CARD_SCALE
    local dx = CARD_MARGIN_X
    if (tonumber(s.camp) or 0) ~= 0 then
        dx = -dx
    end
    rt.anchoredPosition = Vector2.New(dx, centerY)
    return { x = dx, y = centerY }
end

local function DestroySlot(s)
    -- 立绘要先还给对象池，否则跟着卡片一起 Destroy 会造成池泄漏
    if s.live then
        UnLoadHerolive(s.hero, s.live)
        s.live = nil
    end
    if IsAlive(s.go) then
        GameObject.Destroy(s.go)
    end
    s.go = nil
    s.hero = nil
    if s.timer then
        s.timer:Stop()
        s.timer = nil
    end
    if s.followTimer then
        s.followTimer:Stop()
        s.followTimer = nil
    end
    s.tween = nil
    s.lastKey = nil
    s.lastTime = 0
end

-- 清掉全部卡片（换战斗时重建，保证是从「没被入场动画改过」的模板克隆的）
function this.Destroy()
    for _, s in pairs(this.slots) do
        DestroySlot(s)
    end
    this.slots = {}
    this.view = nil
end

-- 战斗初始化时调用（BattleView.InitBattleData）
function this.ResetForBattle(view)
    this.Destroy()
    this.view = view
end

local function EnsureCard(view, s)
    if IsAlive(s.go) then
        return s.go
    end
    local tpl = GetTemplate(view)
    if not tpl then
        return nil
    end

    local go = GameObject.Instantiate(tpl, view.transform)
    go.name = (s.camp == 0) and "HelpHeroMiniCard_Mine" or "HelpHeroMiniCard_Enemy"

    -- 整屏版自带的入场动画会驱动根节点位移/缩放，会把角落定位改回全屏，必须停掉
    local anim = go:GetComponent("Animation")
    if anim then
        anim:Stop()
        anim.enabled = false
    end
    -- 整屏粒子缩到 28% 会糊成一片，关掉
    local effect = Util.GetGameObject(go, "effect")
    if effect then
        effect:SetActive(false)
    end

    go:SetActive(false)
    -- 层级压到技能栏（myRect_Skill）之下，避免卡片盖住技能释放 UI
    local skillUI = GetSkillBar(view, 0)
    if IsAlive(skillUI) then
        go.transform:SetSiblingIndex(skillUI.transform:GetSiblingIndex())
    else
        LogRed("[UIFlow] 大招小卡排序失败：找不到 myRect_Skill")
    end
    s.go = go
    return go
end

-- 展示小卡。view = BattleView 实例，heroConfig = HeroConfig 行，camp = 0 我方 / 1 敌方
function this.Show(view, heroConfig, camp, dedupeKey)
    if not heroConfig then
        return
    end
    camp = tonumber(camp) or 0
    local s = GetSlot(camp)

    -- 多段技能会连续调 SkillFireOnce，同一发大招只亮一次卡
    local now = Time.realtimeSinceStartup
    if dedupeKey and dedupeKey == s.lastKey and now - s.lastTime < 1.5 then
        return
    end
    s.lastKey = dedupeKey
    s.lastTime = now

    local go = EnsureCard(view, s)
    if not go then
        LogRed("[UIFlow] 大招小卡创建失败：找不到 HelpHeroShow 模板")
        return
    end

    -- 定位：紧贴技能栏下沿（相对技能栏锚点，换分辨率不跑偏）
    local rt = go:GetComponent("RectTransform")
    local pos = nil
    if rt then
        pos = ApplyLayout(view, s, rt)
        rt.localScale = Vector3.New(CARD_SCALE * 0.7, CARD_SCALE * 0.7, 1)
    end
    go:SetActive(true)

    -- 换立绘：先卸掉上一张，避免多张叠在一起
    local liveRoot = Util.GetGameObject(go, "live")
    if liveRoot then
        if s.live then
            UnLoadHerolive(s.hero, s.live)
            s.live = nil
        end
        Util.ClearChild(liveRoot.transform)
        s.hero = heroConfig
        s.live = LoadHerolive(heroConfig, liveRoot.transform)
    end

    -- 名字 / 阵营地点
    local nameGo = Util.GetGameObject(go, "name")
    if nameGo and heroConfig.ReadingName and heroConfig.ReadingName ~= 0 then
        local txt = nameGo:GetComponent("Text")
        if txt then
            txt.text = GetLanguageStrById(heroConfig.ReadingName)
        end
    end
    local locGo = Util.GetGameObject(go, "location")
    if locGo and heroConfig.HeroLocation and heroConfig.HeroLocation ~= 0 then
        local txt = locGo:GetComponent("Text")
        if txt then
            txt.text = GetLanguageStrById(heroConfig.HeroLocation)
        end
    end

    -- 弹出
    if s.tween then
        s.tween:Kill()
    end
    s.tween = go.transform:DOScale(Vector3.New(CARD_SCALE, CARD_SCALE, 1), POP_IN_TIME):SetEase(Ease.OutBack)

    Log(string.format("[UIFlow] 大招小卡 OPEN hero=%s camp=%s bar=%s pos=(%s,%s)",
        tostring(heroConfig.Id), tostring(camp),
        (camp == 0) and "myRect_Skill" or "enemyRect_Skill",
        pos and string.format("%.0f", pos.x) or "?",
        pos and string.format("%.0f", pos.y) or "?"))

    -- 停留后收起
    if s.timer then
        s.timer:Stop()
    end
    s.timer = Timer.New(function ()
        this.Hide(camp)
    end, CARD_SHOW_TIME, 1, true)
    s.timer:Start()

    -- 跟随技能栏：技能栏一消失，卡片同步消失（大招表现结束）
    if s.followTimer then
        s.followTimer:Stop()
    end
    s.followTimer = Timer.New(function ()
        if not IsAlive(s.go) then
            s.followTimer:Stop()
            return
        end
        local ui = GetSkillBar(view, s.camp)
        if not IsAlive(ui) or not ui.activeInHierarchy then
            this.Hide(camp)
        end
    end, 0.1, -1, true)
    s.followTimer:Start()
end

function this.Hide(camp)
    local s = this.slots[tonumber(camp) or 0]
    if not s or not IsAlive(s.go) then
        return
    end
    if s.followTimer then
        s.followTimer:Stop()
        s.followTimer = nil
    end
    local go = s.go
    if s.tween then
        s.tween:Kill()
    end
    s.tween = go.transform:DOScale(Vector3.New(CARD_SCALE * 0.8, CARD_SCALE * 0.8, 1), POP_OUT_TIME)
        :SetEase(Ease.InQuad)
        :OnComplete(function ()
            if IsAlive(go) then
                go:SetActive(false)
                Log("[UIFlow] 大招小卡 CLOSE camp=" .. tostring(camp))
            end
        end)
end

return BattleUltCard
