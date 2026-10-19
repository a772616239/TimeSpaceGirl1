--[[
  大招入场小卡（缩小版 HelpHeroShow）
  ==========================================================================
  英雄释放大招的瞬间，把助战英雄展示框 HelpHeroShow 的缩小副本摆到对应角落：
  我方 camp 0 -> myRect_Skill 左侧，敌方 camp 1 -> enemyRect_Skill 右侧，
  随后大招攻击照常播放。按需求：卡片与攻击同时进行，不额外暂停战斗。

  不新增 prefab 节点：直接克隆 BattlePanel 下的 HelpHeroShow（含立绘挂点 live、
  名字 name、地点 location），缩放到 26% 后挂到技能栏下面。

  🔴 卡片是技能栏的【子节点】，生成时就挂进 myRect_Skill / enemyRect_Skill：
     - 位置：Show 时按技能栏【当前的世界坐标】算一次，落到技能栏外侧下沿；
       之后技能栏怎么动（入场动画滑 anchoredPosition、换分辨率重排）卡片都自动跟着，
       不再需要每帧重算（旧实现用 50Hz 计时器模拟 ParentConstraint，现在父子关系天然跟随）。
     - 缩放：技能栏自己带 1.2 缩放，敌方那条还是 -1.2 的镜像副本；
       子节点必须按父链缩放反算，否则卡片凭空放大 1.2 倍、敌方那张还会左右翻转。
     - 显隐：技能栏 SetActive(false) 一关，卡片作为子节点跟着一起消失，
       所以卡片不再自己隐藏（旧实现那套 3 秒 / 2 秒 / 防抖判定全部删掉）。

  注意：每个阵营各持一张卡（slots[camp]），敌我可能同时放大招，
  共用一张会互相覆盖、位置乱跳。
]]

BattleUltCard = {}
local this = BattleUltCard

-- 触发范围：true  = 只有「带特写」的大招（CombatControl.Closeup 有值的技能）；
--           false = 所有英雄的技能（CombatControl.SkillType == 2，普攻 SkillType == 1 不算）。
local REQUIRE_CLOSEUP = false

-- 敌我都弹，靠角落位置区分：我方贴 myRect_Skill、敌方贴 enemyRect_Skill
local ONLY_MY_CAMP    = false

local CARD_SCALE       = 0.26   -- 相对整屏版 HelpHeroShow 的缩放
local CARD_MARGIN_X    = 140    -- 卡片中心距技能栏外侧边缘的距离（0.26 缩放后卡宽 280.8，半宽 140.4，边缘贴齐）
local CARD_GAP_Y       = 8      -- 卡片顶边与技能栏底边的间隙（参考分辨率像素，CanvasScaler 统一缩放）
local CARD_CONTENT_TOP = 642.5  -- 卡片内容顶边相对卡片中心（缩放前，Image1 顶边 = pos.y 7 + 高 1271/2）
local CARD_Y_OFFSET    = 309.35 -- 在「技能栏下沿」基础上的整体竖向微调（正数向上）
local CARD_FALLBACK_Y  = -520   -- 兜底：找不到技能栏时卡片中心的 Y（相对顶部锚点）
local POP_IN_TIME     = 0.18

-- [camp] = { go, live, hero, tween, lastKey, lastTime }
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

-- 技能栏【当前世界坐标】下的几何：左右下边界 + 父链缩放
--   🔴 必须读运行时的 position / lossyScale / rect：
--      技能栏自带入场动画会改 anchoredPosition，换分辨率后 rect 也会变，
--      拿 prefab 里的数字写死（anchoredPosition=(0,-215)、size 529x90）迟早错位。
local function GetBarGeom(bar)
    if not IsAlive(bar) or not IsAlive(bar.transform) then
        return nil
    end
    local rt = bar:GetComponent("RectTransform")
    if not rt then
        return nil
    end
    local tr = bar.transform
    local pos = tr.position
    local lossy = tr.lossyScale
    local rect = rt.rect
    if not pos or not rect then
        return nil
    end
    -- 敌方那条技能栏 localScale.x 是 -1.2（横向镜像），符号必须保留，后面要靠它把卡片翻回来
    local sx = (lossy and lossy.x and lossy.x ~= 0) and lossy.x or 1
    local sy = (lossy and lossy.y and lossy.y ~= 0) and lossy.y or 1
    local ax = pos.x + sx * rect.xMin
    local bx = pos.x + sx * rect.xMax
    local ay = pos.y + sy * rect.yMin
    local by = pos.y + sy * rect.yMax
    return {
        pos = pos,
        sx = sx,
        sy = sy,
        left = math.min(ax, bx),
        right = math.max(ax, bx),
        bottom = math.min(ay, by),
        top = math.max(ay, by),
    }
end

-- 面板（卡片原来的父节点）的缩放：CARD_* 这些像素量纲都是按面板空间调的，
-- 换到世界坐标时要乘上它；卡片换父节点后缩放也要按它反算。
local function GetPanelScale(view)
    if view and IsAlive(view.transform) then
        local s = view.transform.lossyScale
        if s and s.x and s.x ~= 0 then
            return math.abs(s.x)
        end
    end
    return 1
end

-- 卡片定位：落在技能栏外侧下沿（我方左边缘 / 敌方右边缘），全部按技能栏当前世界坐标算
--   🔴 只在 Show 时算一次：卡片已经是技能栏的子节点，之后技能栏移动卡片跟着移动，
--      不需要也不应该每帧重算。
--   返回 卡片本地缩放 (lx, ly) 和落点世界坐标 (wx, wy)
local function ApplyLayout(view, s, rt)
    local bar = GetSkillBar(view, s.camp)
    local geom = bar and GetBarGeom(bar)
    local px = GetPanelScale(view)

    rt.pivot = Vector2.New(0.5, 0.5)
    rt.anchorMin = Vector2.New(0.5, 0.5)
    rt.anchorMax = Vector2.New(0.5, 0.5)

    if not geom then
        -- 兜底：拿不到技能栏（正常不会走到）⇒ 还挂在面板下，退回「贴屏幕顶角」的绝对定位
        local ax = ((tonumber(s.camp) or 0) == 0) and 0 or 1
        rt.anchorMin = Vector2.New(ax, 1)
        rt.anchorMax = Vector2.New(ax, 1)
        local dx = ((tonumber(s.camp) or 0) == 0) and CARD_MARGIN_X or -CARD_MARGIN_X
        local dy = CARD_FALLBACK_Y + CARD_Y_OFFSET
        rt.anchoredPosition = Vector2.New(dx, dy)
        rt.localScale = Vector3.New(CARD_SCALE, CARD_SCALE, 1)
        LogRed("[UIFlow] 大招小卡定位兜底：找不到技能栏节点")
        return CARD_SCALE, CARD_SCALE, dx, dy
    end

    -- X：贴技能栏外侧（我方取左边界、敌方取右边界），距离按面板像素量纲折成世界单位
    local margin = CARD_MARGIN_X * px
    local wx
    if (tonumber(s.camp) or 0) == 0 then
        wx = geom.left + margin
    else
        wx = geom.right - margin
    end
    -- Y：技能栏下沿往上（- 间隙 - 卡片内容半高 + 竖向微调）
    local lift = (CARD_Y_OFFSET - CARD_GAP_Y - CARD_CONTENT_TOP * CARD_SCALE) * px
    local wy = geom.bottom + lift

    -- 🔴 世界坐标 -> 技能栏本地坐标。技能栏的 lossyScale 可能带负号（敌方是镜像副本），
    --    除以它同时完成「换算到本地单位」和「把镜像翻回来」两件事。
    rt.localPosition = Vector3.New((wx - geom.pos.x) / geom.sx, (wy - geom.pos.y) / geom.sy, 0)

    -- 缩放反算：父链 1.2 倍缩放（敌方 x 还是 -1.2）=> 本地缩放除回去，
    -- 卡片的世界尺寸才等于面板下 0.26 的观感，且敌方那张不会被左右翻转。
    local lx = CARD_SCALE * px / geom.sx
    local ly = CARD_SCALE * px / geom.sy
    rt.localScale = Vector3.New(lx, ly, 1)
    return lx, ly, wx, wy
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

    -- 🔴 直接生成成技能栏的子节点：位置/缩放/显隐全交给父节点，
    --    不再像旧实现那样挂在面板下、靠每帧重算位置模拟「锁在技能栏上」。
    local bar = GetSkillBar(view, s.camp)
    local parent = view.transform
    if bar and IsAlive(bar.transform) then
        parent = bar.transform
    else
        LogRed("[UIFlow] 大招小卡没挂到技能栏下：找不到 myRect_Skill / enemyRect_Skill")
    end

    local go = GameObject.Instantiate(tpl, parent)
    go.name = (s.camp == 0) and "HelpHeroMiniCard_Mine" or "HelpHeroMiniCard_Enemy"

    -- 整屏版自带的入场动画会驱动根节点位移/缩放，会把定位改回全屏，必须停掉
    local anim = go:GetComponent("Animation")
    if anim then
        anim:Stop()
        anim.enabled = false
    end
    -- 整屏粒子缩到 26% 会糊成一片，关掉
    local effect = Util.GetGameObject(go, "effect")
    if effect then
        effect:SetActive(false)
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

    -- 定位：按技能栏当前世界坐标算一次，之后由父子关系跟随
    local rt = go:GetComponent("RectTransform")
    local sx, sy, wx, wy = CARD_SCALE, CARD_SCALE, nil, nil
    if rt then
        sx, sy, wx, wy = ApplyLayout(view, s, rt)
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
    if rt then
        rt.localScale = Vector3.New(sx * 0.7, sy * 0.7, 1)
        s.tween = go.transform:DOScale(Vector3.New(sx, sy, 1), POP_IN_TIME):SetEase(Ease.OutBack)
    end

    Log(string.format("[UIFlow] 大招小卡 OPEN hero=%s camp=%s 挂点=%s pos=(%s,%s)",
        tostring(heroConfig.Id), tostring(camp),
        (camp == 0) and "myRect_Skill" or "enemyRect_Skill",
        wx and string.format("%.0f", wx) or "?",
        wy and string.format("%.0f", wy) or "?"))
end

-- 手动清场（正常流程不需要：卡片是技能栏的子节点，技能栏一关就跟着隐藏了）
function this.Hide(camp)
    local s = this.slots[tonumber(camp) or 0]
    if not s then
        return
    end
    if s.tween then
        s.tween:Kill()
        s.tween = nil
    end
    if IsAlive(s.go) then
        s.go:SetActive(false)
    end
    s.lastKey = nil
    s.lastTime = 0
end

return BattleUltCard
