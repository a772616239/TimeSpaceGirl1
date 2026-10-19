--[[
  大招入场小卡（缩小版 HelpHeroShow）
  ==========================================================================
  英雄释放大招的瞬间，把助战英雄展示框 HelpHeroShow 的缩小副本摆到对应角落：
  我方 camp 0 -> 左上角，敌方 camp 1 -> 右上角，随后大招攻击照常播放。
  按需求：卡片与攻击同时进行，不额外暂停战斗。

  不新增 prefab 节点：直接克隆 BattlePanel 下的 HelpHeroShow（含立绘挂点 live、
  名字 name、地点 location），缩放到 26% 后重挂锚点。立绘走 LoadHerolive，
  与助战英雄入场展示框同一套资源链路。

  🔴 定位规则：跟随技能栏（myRect_Skill / enemyRect_Skill）——卡片纵向落在技能栏那一带，
  不是在屏幕顶角；X 贴左右边缘。位置全部在技能栏的锚点空间里算，所以技能栏怎么锚
  卡片就怎么跟，不再自己揣一套绝对坐标。
  🔴 位置是「绑定」而不是「算一次」：卡片存活期间每 0.1s 跟着技能栏重算一次
  （等同 ParentConstraint 的锁定位置语义，但不动父子关系、不动层级、不跟技能栏的
  SetActive 联动 —— 见文件末尾 LockToSkillBar 注释）。

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

local CARD_SCALE       = 0.26   -- 相对整屏版 HelpHeroShow 的缩放
local CARD_MARGIN_X    = 140    -- 卡片中心距左/右边缘的距离（0.26 缩放后卡宽 280.8，半宽 140.4，边缘贴齐）
local CARD_GAP_Y       = 8      -- 卡片顶边与技能栏底边的间隙（参考分辨率像素，CanvasScaler 统一缩放）
local CARD_CONTENT_TOP = 642.5  -- 卡片内容顶边相对卡片中心（缩放前，Image1 顶边 = pos.y 7 + 高 1271/2）
local CARD_Y_OFFSET    = 309.35 -- 在「技能栏下沿」基础上的整体竖向微调（正数向上）
local CARD_FALLBACK_Y  = -520   -- 兜底：找不到技能栏时卡片中心的 Y（相对顶部锚点）
local POP_IN_TIME     = 0.18
local POP_OUT_TIME    = 0.12

-- 收场参数：卡片跟着技能栏（myRect_Skill / enemyRect_Skill）的生命周期走
-- 🔴 卡片不再自己拍一个固定时长。技能栏亮 3 秒（BattlePanel.RECT_SKILL_SHOW_TIME，unscaled），
--    以前卡片写死 2.0s（对齐 CloseupDuration）⇒ 卡片必然比技能栏早 1 秒消失。
--    放大招带特写时更糟：前摇 0.5s + CloseupDuration 这段里战斗是暂停的，技能栏还没亮，
--    卡片的 2 秒却照走不误，等技能栏亮起来时卡片早就收掉了。
-- 判定分三种情况（0.1s 轮询，真实时间）：
--   ① 技能栏亮着              → 卡片留着（记 barSeen = true）；
--   ② 技能栏亮过、现在灭了     → 连续 FOLLOW_MISS_LIMIT 次看不到才收（≈0.2s 内跟上技能栏）；
--   ③ 技能栏还没亮（特写前摇） → 只等，不算消失，等它亮起来再跟。
local CARD_MIN_LIVE_TIME = 1.2  -- 弹出后这段时间内不吃「技能栏消失」的信号（真实秒）
local FOLLOW_MISS_LIMIT  = 2    -- 连续这么多次轮询都看不到技能栏才算真的消失（0.1s/次）
local CARD_MAX_LIFE_TIME = 6.0  -- 兜底：技能栏计时异常（一直不灭/一直不亮）时卡片的上限

-- [camp] = { go, live, hero, tween, lastKey, lastTime, showTime, barSeen, followMiss }
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
-- 定位、跟随消失、压层级三处都用它，是卡片唯一的参照物
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

-- 卡片定位：跟随技能栏（我方 myRect_Skill / 敌方 enemyRect_Skill）
--   🔴 位置口径按昨晚定稿：卡片纵向落在技能栏那一带（屏幕中部略偏下），不是贴屏幕顶角。
--   直接复制技能栏的锚点（我方 (0,0.5)、敌方 (1,0.5)），X 只给「距边距离」；
--   Y = 技能栏底边 - 间隙 - 卡片内容半高 + 固定微调，全部在技能栏的锚点空间里算。
--   🔴 纯函数、可重复调用：Show 时算一次，存活期间跟随 tick 再算一次，
--      两次口径完全一致，所以不会出现「弹出时对齐、之后漂走」。
local function ApplyLayout(view, s, rt)
    local bar = GetSkillBar(view, s.camp)
    local barRt = bar and bar:GetComponent("RectTransform")
    rt.pivot = Vector2.New(0.5, 0.5)
    if not barRt then
        -- 兜底：拿不到技能栏才退回顶部锚点绝对定位
        local ax = ((tonumber(s.camp) or 0) == 0) and 0 or 1
        rt.anchorMin = Vector2.New(ax, 1)
        rt.anchorMax = Vector2.New(ax, 1)
        local dx = ((tonumber(s.camp) or 0) == 0) and CARD_MARGIN_X or -CARD_MARGIN_X
        local dy = CARD_FALLBACK_Y + CARD_Y_OFFSET
        rt.anchoredPosition = Vector2.New(dx, dy)
        LogRed("[UIFlow] 大招小卡定位兜底：找不到技能栏节点")
        return { x = dx, y = dy }
    end

    rt.anchorMin = barRt.anchorMin
    rt.anchorMax = barRt.anchorMax
    -- 技能栏底边（相对其锚点参考点）；pivot.y 通常是 0.5，用配置值算，不写死
    local barBottom = barRt.anchoredPosition.y - barRt.pivot.y * barRt.sizeDelta.y
    local centerY = barBottom - CARD_GAP_Y - CARD_CONTENT_TOP * CARD_SCALE + CARD_Y_OFFSET
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
    if s.followTimer then
        s.followTimer:Stop()
        s.followTimer = nil
    end
    s.tween = nil
    s.lastKey = nil
    s.lastTime = 0
    s.showTime = 0
    s.barSeen = false
    s.followMiss = 0
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
    -- 记录弹出时刻 + 清零跟随状态：跟随技能栏的那套判定从这里重新起算
    s.showTime = now
    s.barSeen = false
    s.followMiss = 0

    local go = EnsureCard(view, s)
    if not go then
        LogRed("[UIFlow] 大招小卡创建失败：找不到 HelpHeroShow 模板")
        return
    end

    -- 定位：跟随技能栏（相对技能栏锚点，换分辨率不跑偏）
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

    -- 收场：跟着技能栏走（技能栏亮着就留着，技能栏灭了就跟着灭）
    -- 🔴 这里不再有「停留 N 秒」的独立定时器：一旦卡片和技能栏各持一个时钟，
    --    两者时长对不上（3.0s vs 2.0s）就必然出现「卡片比技能栏先消失」，
    --    宁可只留技能栏一个时钟，卡片只做跟随 + 兜底上限。
    if s.followTimer then
        s.followTimer:Stop()
    end
    s.followTimer = Timer.New(function ()
        if not IsAlive(s.go) then
            s.followTimer:Stop()
            return
        end
        local lived = Time.realtimeSinceStartup - (s.showTime or 0)
        local ui = GetSkillBar(view, s.camp)
        local barOn = IsAlive(ui) and ui.activeInHierarchy

        if barOn then
            -- 技能栏亮着 → 卡片必须是活的
            s.barSeen = true
            s.followMiss = 0
            -- 位置锁定：等同 ParentConstraint 的「锁定位置」，但只锁位置 ——
            -- 卡片仍是 BattlePanel 的子节点（层级压技能栏之下），也不跟技能栏的 SetActive 联动
            -- （特写前摇里技能栏是灭的，卡片必须还能显示）。
            -- 用同一套 ApplyLayout 重算，弹出时和存活期间位置口径一致。
            if rt then
                ApplyLayout(view, s, rt)
            end
        elseif s.barSeen and lived >= CARD_MIN_LIVE_TIME then
            -- 技能栏亮过又灭了 → 防抖几次再收，约 0.2s 内跟上技能栏
            s.followMiss = (s.followMiss or 0) + 1
            if s.followMiss >= FOLLOW_MISS_LIMIT then
                Log(string.format("[UIFlow] 大招小卡跟随技能栏收起 camp=%s（技能栏已隐藏）", tostring(camp)))
                this.Hide(camp)
                return
            end
        end
        -- ③ 技能栏还没亮（放大招前摇 + 特写期间战斗暂停）→ 什么都不做，继续等

        if lived >= CARD_MAX_LIFE_TIME then
            Log(string.format("[UIFlow] 大招小卡兜底收起 camp=%s（技能栏 %.1fs 内没收场）",
                tostring(camp), CARD_MAX_LIFE_TIME))
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
    -- 🔴 卡片只有一个时钟（followTimer），收起后就没了；
    --    以前还给卡片挂过一个「停留 2 秒」的定时器，提前收起后它照样到点再 Hide 一次，
    --    正好把同一阵营下一次弹出的卡片按上一个时间点切掉。
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
