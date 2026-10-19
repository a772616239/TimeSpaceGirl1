--[[
  大招入场小卡（缩小版 HelpHeroShow）
  ==========================================================================
  英雄释放大招的瞬间，把助战英雄展示框 HelpHeroShow 的缩小副本摆到对应角落：
  我方 camp 0 -> myRect_Skill 正上方，敌方 camp 1 -> enemyRect_Skill 正上方，
  随后大招攻击照常播放。按需求：卡片与攻击同时进行，不额外暂停战斗。

  🔴 为什么是「正上方」而不是「左侧 / 右侧」：
     技能栏 anchor(0,0.5) + pivot(0,0.5) 贴在屏幕【左边缘】（我方）/ 右边缘（敌方），
     外侧根本没有空间；卡片 224x264 摆在同一个 x 上就会整块压住技能底板 Image(280x90)
     与 SkillName 文字（0.26 时代实测 canvas: 技能栏 [-540,-269]-[95,-161]，卡片 [-540,-298]-[-260,32]）。
     卡片以前画在技能栏【下面】所以看不出来，改成子节点后 z 序在上 ⇒ 直接盖住技能名。
     所以落点改为：水平贴技能栏外缘（与技能底板同宽、左/右对齐），
     垂直方向卡片【底边】顶在技能栏【上沿】之上 GAP_Y，完全不与技能栏矩形相交。

  不新增 prefab 节点：直接克隆 BattlePanel 下的 HelpHeroShow（含立绘挂点 live、
  卡片框 Image1、底板 Image、名字 name、地点 location），缩放到 20.8% 后作为技能栏的子节点挂上去。

  🔴 卡面装饰件（底板 Image + 名字 name + 地点 location）只在【新手引导动画】里显示：
     教学关（GuideBattlePanel）要借这张卡交代「这是谁、从哪来」，名字/地点是教学内容；
     正常战斗里卡片只有 20.8% 大，700x225 的名字、410x116 的地点缩完根本读不出来，
     底板还会实打实压住战斗画面 ⇒ 非引导场景一律 SetActive(false)，只留立绘 + 卡片框。
     判定见 IsGuideScene()（view == GuideBattlePanel 或强制引导进行中），
     临时要改口径用 this.forceDecor = true/false 覆盖，不用动这里。

  🔴 卡片是技能栏的【子节点】，生成时就挂进 myRect_Skill / enemyRect_Skill：
     - 位置：Show 时按技能栏【当前的世界坐标】算一次，落成「贴外缘 + 压在技能栏上方」；
       之后技能栏怎么动（入场动画滑 anchoredPosition、换分辨率重排）卡片都自动跟着，
       不再需要每帧重算（旧实现用 50Hz 计时器模拟 ParentConstraint，现在父子关系天然跟随）。
     - 缩放：技能栏自己带 1.2 缩放，敌方那条还是 -1.2 的镜像副本；
       子节点必须按父链缩放反算，否则卡片凭空放大 1.2 倍、敌方那张还会左右翻转。
     - 显隐：技能条到点收场时，由 BattlePanel:PlaySkillBarOut 把【父节点】横向滑出屏幕
       （0.16s，方向与入场一致），卡片作为子节点跟着滑出去，滑完再一起关；
       所以卡片自己不做消失动画、也不再自己计时。技能条重新亮起前由 OnBarHidden 把卡片
       的 activeSelf 真正关掉，避免上一张大招卡跟着新技能条又冒出来。

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

-- 缩放：原 0.26，按需求再缩到 0.8 倍 ⇒ 0.208（整屏版 HelpHeroShow 的 20.8%）
--   CARD_MARGIN_X 必须跟着缩放走：它等于卡片【半宽】，边缘才能与技能底板贴齐；
--   写死 140 是 0.26 时代的半宽，缩小后会把卡片往外推一截、与技能栏错开。
local CARD_SCALE       = 0.26 * 0.8
local CARD_W           = 1080 * CARD_SCALE   -- 224.64：卡片框（整屏版 Image1 宽 1080）缩放后的实际宽度
local CARD_MARGIN_X    = CARD_W * 0.5        -- 112.32：卡片中心距技能栏外缘 = 半宽 ⇒ 边缘贴齐
local CARD_GAP_Y       = 8       -- 卡片【底边】与技能栏【上沿】的间隙（参考分辨率像素，CanvasScaler 统一缩放）
local CARD_BOTTOM_HALF = 628.5   -- 卡片内容底边相对卡片中心（缩放前，Image1 底边 = pos.y 7 - 高 1271/2）
local CARD_FALLBACK_Y  = -211    -- 兜底：找不到技能栏时卡片中心的 Y（相对顶部锚点，沿用改版前的观感）
local POP_IN_TIME     = 0.18
-- 收场动画不在本模块做：卡片是技能条的子节点，由 BattlePanel:PlaySkillBarOut 把【父节点】
-- 横向滑出屏幕（见 BattlePanel.SKILL_BAR_OUT_*），卡片跟着一起走，滑完再一起关。

-- 卡面装饰件：底部底板 Image（1080x376）+ 英雄名 name（700x225）+ 阵营地点 location（410x116）。
--   🔴 只在【新手引导动画】里显示，正常战斗只留立绘 + 卡片框 Image1（1080x1271）。
--   名字/地点缩到 26% 后字号不到 10px 根本读不出来，底板还会压住战斗画面。
--   卡片框 Image1 不能关：卡片的可见边缘就是它的矩形（CARD_BOTTOM_HALF 按它算的）。
local DECOR_NODES = { "Image", "name", "location" }

-- 装饰件显示开关：nil = 按场景自动判断（默认）；true/false = 强制（GM / 回归测试用）
this.forceDecor = nil

-- [camp] = { go, live, hero, tween, lastKey, lastTime }
this.slots = {}
this.view = nil

local function IsAlive(go)
    return go ~= nil and not IsNull(go)
end

-- 是否「新手引导动画」场景（卡面装饰件 Image / name / location 只在这里显示）
--   ① 教学关：卡片挂在 GuideBattlePanel 上（它自己带一套 myRect_Skill，不是 BattlePanel）；
--   ② 强制新手引导进行中（GuideManager.IsInMainGuide，教学期普通战斗也算引导）。
--   🔴 两个模块都可能没加载（引导关闭 / 单测桩），一律按「不在引导」处理，绝不能让判定抛错。
local function IsGuideScene(view)
    if this.forceDecor ~= nil then
        return this.forceDecor and true or false
    end
    if GuideBattlePanel ~= nil and view ~= nil and view == GuideBattlePanel then
        return true
    end
    if GuideManager ~= nil and type(GuideManager.IsInMainGuide) == "function" then
        local ok, inGuide = pcall(GuideManager.IsInMainGuide)
        if ok and inGuide then
            return true
        end
    end
    return false
end

-- 装饰件开关：show=false 时把底板 Image / 名字 / 地点 全部 SetActive(false)，只留立绘 + 卡片框
--   🔴 只动这三个节点，不碰 Image1（卡片框）与 live（立绘挂点）：
--      Image1 的矩形是落点基准（CARD_BOTTOM_HALF），关掉卡片会变成看不见但仍在挡的空白。
local function ApplyDecor(go, show)
    show = show and true or false
    for i = 1, #DECOR_NODES do
        local node = Util.GetGameObject(go, DECOR_NODES[i])
        if IsAlive(node) then
            node:SetActive(show)
        end
    end
end

-- 对外：当前这一局该不该显示装饰件（供 GM/其它模块查询）
function this.ShouldShowDecor(view)
    return IsGuideScene(view or this.view)
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

-- 卡片定位：水平贴技能栏外缘、垂直整块压在技能栏【上方】（不与技能栏矩形相交）
--   全部按技能栏当前世界坐标算。
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
        local dy = CARD_FALLBACK_Y
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
    -- Y：卡片【底边】落在技能栏【上沿】之上 GAP_Y ⇒ 中心 = 上沿 + 间隙 + 卡片下半高
    --    🔴 不能用「下沿往上」：技能栏只有 108 高，卡片 330 高，那样必然盖住技能底板与技能名。
    local lift = (CARD_GAP_Y + CARD_BOTTOM_HALF * CARD_SCALE) * px
    local wy = geom.top + lift

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
    -- 整屏粒子缩到 20.8% 会糊成一片，关掉
    local effect = Util.GetGameObject(go, "effect")
    if effect then
        effect:SetActive(false)
    end

    -- 名字 / 地点 / 底板：非新手引导场景一律不显示（只留立绘 + 卡片框）
    ApplyDecor(go, IsGuideScene(view))

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
    -- 每次亮卡都校正一次装饰件：forceDecor / 引导状态中途变化也能立刻生效
    ApplyDecor(go, IsGuideScene(view))

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

-- 技能条收场滑完、要把父节点关掉时调用
--   🔴 卡片是技能条的子节点，父节点一关它自己【不会】变成 inactive（activeSelf 仍是 true），
--      下次技能条为别的技能亮起来时会把上一张大招卡一起带出来 ⇒ 这里真正关掉它。
function this.OnBarHidden(camp)
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
end

-- 手动清场（正常流程不需要：技能条滑出屏幕后由 OnBarHidden 关掉）
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
