--[[
  大招入场小卡（缩小版 HelpHeroShow）
  ==========================================================================
  英雄释放大招的瞬间，把助战英雄展示框 HelpHeroShow 的缩小副本摆到对应侧边角
  （我方 camp 0 → 左下角，敌方 camp 1 → 右下角），随后大招攻击照常播放。
  按需求：卡片与攻击同时进行，不额外暂停战斗。

  不新增 prefab 节点：直接克隆 BattlePanel 下的 HelpHeroShow（含立绘挂点 live、
  名字 name、地点 location），缩放到 28% 后重挂锚点。立绘走 LoadHerolive，
  与助战英雄入场展示框同一套资源链路。
]]

BattleUltCard = {}
local this = BattleUltCard

-- 触发范围：true  = 只有「带特写」的大招（CombatControl.Closeup 有值的技能，目前是主角大招）；
--           false = 所有英雄的技能（CombatControl.SkillType == 2，普攻 SkillType == 1 不算）。
local REQUIRE_CLOSEUP = false

-- 只给我方英雄弹卡（敌方也弹会让屏幕两侧同时出现卡片，噪音大）
local ONLY_MY_CAMP   = true

local CARD_SCALE     = 0.28  -- 相对整屏版 HelpHeroShow 的缩放
local CARD_MARGIN_X  = 180   -- 卡片中心距左/右边界的距离
local CARD_MARGIN_Y  = 290   -- 卡片中心距底边的距离（抬高一点，避开底部主角技能栏）
local CARD_SHOW_TIME = 2.0   -- 停留时长（对齐特写 CloseupDuration = 2000ms）
local POP_IN_TIME    = 0.18
local POP_OUT_TIME   = 0.12

this.card = nil      -- 复用的卡片副本（挂在 BattlePanel 下，随面板一起销毁）
this.cardLive = nil  -- 当前卡片上的立绘节点
this.cardHero = nil  -- 当前立绘对应的 heroConfig
this.hideTimer = nil
this.popTween = nil
this.lastKey = nil   -- 去重：一发大招可能被 SkillFireOnce 连续调用多次
this.lastTime = 0

local function IsAlive(go)
    return go ~= nil and not IsNull(go)
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

-- 清掉卡片（换战斗时重建，保证是从「没被入场动画改过」的模板克隆的）
function this.Destroy()
    -- 立绘要先还给对象池，否则跟着卡片一起 Destroy 会造成池泄漏
    if this.cardLive then
        UnLoadHerolive(this.cardHero, this.cardLive)
        this.cardLive = nil
    end
    if IsAlive(this.card) then
        GameObject.Destroy(this.card)
    end
    this.card = nil
    this.cardHero = nil
    if this.hideTimer then
        this.hideTimer:Stop()
        this.hideTimer = nil
    end
    this.popTween = nil
    this.lastKey = nil
    this.lastTime = 0
end

-- 战斗初始化时调用（BattleView.InitBattleData）
function this.ResetForBattle(view)
    this.Destroy()
    this.EnsureCard(view)
end

function this.EnsureCard(view)
    if IsAlive(this.card) then
        return this.card
    end
    local tpl = GetTemplate(view)
    if not tpl then
        return nil
    end

    local go = GameObject.Instantiate(tpl, view.transform)
    go.name = "HelpHeroMiniCard"

    -- 整屏版自带的入场动画会驱动根节点位移/缩放，会破坏角落定位，必须停掉
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
    this.card = go
    return go
end

-- 展示小卡。view = BattleView 实例，heroConfig = HeroConfig 行，camp = 0 我方 / 1 敌方
function this.Show(view, heroConfig, camp, dedupeKey)
    if not heroConfig then
        return
    end
    -- 多段技能会连续调 SkillFireOnce，同一发大招只亮一次卡
    local now = Time.realtimeSinceStartup
    if dedupeKey and dedupeKey == this.lastKey and now - this.lastTime < 1.5 then
        return
    end
    this.lastKey = dedupeKey
    this.lastTime = now

    local go = this.EnsureCard(view)
    if not go then
        LogRed("[UIFlow] 大招小卡创建失败：找不到 HelpHeroShow 模板")
        return
    end

    -- 先定位再激活（激活后再换立绘：SkeletonGraphic 需要在 active 状态初始化）
    local rt = go:GetComponent("RectTransform")
    if rt then
        rt.pivot = Vector2.New(0.5, 0.5)
        if camp == 0 then
            rt.anchorMin = Vector2.New(0, 0)
            rt.anchorMax = Vector2.New(0, 0)
            rt.anchoredPosition = Vector2.New(CARD_MARGIN_X, CARD_MARGIN_Y)
        else
            rt.anchorMin = Vector2.New(1, 0)
            rt.anchorMax = Vector2.New(1, 0)
            rt.anchoredPosition = Vector2.New(-CARD_MARGIN_X, CARD_MARGIN_Y)
        end
        rt.localScale = Vector3.New(CARD_SCALE * 0.7, CARD_SCALE * 0.7, 1)
    end
    go:SetActive(true)

    -- 换立绘：先卸掉上一张，避免多张叠在一起
    local liveRoot = Util.GetGameObject(go, "live")
    if liveRoot then
        if this.cardLive then
            UnLoadHerolive(this.cardHero, this.cardLive)
            this.cardLive = nil
        end
        Util.ClearChild(liveRoot.transform)
        this.cardHero = heroConfig
        this.cardLive = LoadHerolive(heroConfig, liveRoot.transform)
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
    if this.popTween then
        this.popTween:Kill()
    end
    this.popTween = go.transform:DOScale(Vector3.New(CARD_SCALE, CARD_SCALE, 1), POP_IN_TIME):SetEase(Ease.OutBack)

    Log("[UIFlow] 大招小卡 OPEN hero=" .. tostring(heroConfig.Id) .. " camp=" .. tostring(camp)
        .. " reading=" .. tostring(heroConfig.ReadingName))

    -- 停留后收起
    if this.hideTimer then
        this.hideTimer:Stop()
    end
    this.hideTimer = Timer.New(function ()
        this.Hide()
    end, CARD_SHOW_TIME, 1, true)
    this.hideTimer:Start()
end

function this.Hide()
    local go = this.card
    if not IsAlive(go) then
        return
    end
    if this.popTween then
        this.popTween:Kill()
    end
    this.popTween = go.transform:DOScale(Vector3.New(CARD_SCALE * 0.8, CARD_SCALE * 0.8, 1), POP_OUT_TIME)
        :SetEase(Ease.InQuad)
        :OnComplete(function ()
            if IsAlive(go) then
                go:SetActive(false)
                Log("[UIFlow] 大招小卡 CLOSE")
            end
        end)
end

return BattleUltCard
