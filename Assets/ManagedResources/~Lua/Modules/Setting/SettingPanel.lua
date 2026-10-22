require("Base/BasePanel")
local SettingPanel = Inherit(BasePanel)
local this = SettingPanel
local funIndex = 1
-- local tabBtns = {}

local SettingInfo = require("Modules/Setting/SettingInfo")
-- local SettingPlayerTitle = require("Modules/Setting/SettingPlayerTitle")
-- local SettingPlayerRide = require("Modules/Setting/SettingPlayerRide")
-- local SettingPlayerSkin = require("Modules/Setting/SettingPlayerSkin")

--------------------------------------------------------------------------
-- 开关滑动：左侧抽屉进出（打开向右滑入 → 关闭向左滑出）
--
-- 为什么是 Lua 驱动而不是给 prefab 挂 Animator：
--   ① 关闭动画必须"播完再真正关面板" ⇒ 只能接 UIManager 的 OnCloseBefore 钩子；
--   ② 面板会被缓存复用（再次打开不走 InitComponent），静态 clip 还得手动 Play + 复位；
--   ③ 底板 BackMask/bg 与内容容器 layout 是两个**兄弟节点**，基准 anchoredPosition.x
--      不同（bg=202 / layout=0），一条静态曲线绑不了两者，Lua 侧各自记基准最省事。
--
-- 节点分工（别改）：
--   BackMask     全屏无 sprite 实色遮罩（alpha 0.8）⇒ **只淡 alpha，绝不位移**
--   BackMask/bg  左侧底板，405 宽，贴屏幕左边缘
--   layout       全屏内容容器，settingInfo 在里面（内容实际占到 x≈740，比底板宽）
--   位移一律只写 anchoredPosition.x，不碰 sizeDelta（会被 fitter/布局组每帧改回去）
--------------------------------------------------------------------------
local kSlideNodes       = { "BackMask/bg", "layout" }  -- 一起平移的节点
local kMaskNode         = "BackMask"                   -- 只改 alpha 的遮罩
local kMeasureNode      = "layout"                     -- 量内容宽度的子树根
local kOpenDuration     = 0.28   -- 滑入
local kCloseDuration    = 0.22   -- 滑出
local kMaskFadeDuration = 0.20   -- 遮罩淡入/淡出（比位移略快，收尾更利索）
local kSlideMargin      = 30     -- 多滑这一截，保证最右边缘彻底出屏
local kTravelFallback   = 0.75   -- 量不到真实宽度时的兜底比例（× 屏宽）
local kStateTimeoutPad  = 0.35   -- tween 被外部 Kill 时的状态兜底延时

local slideItems = {}   -- { rt = RectTransform, baseX = 基准x, tween = 当前 tween }
local maskImage  = nil
local maskAlpha  = 0.8  -- 遮罩基准 alpha（prefab 里是 0.8，InitComponent 实测覆盖）
local maskTween  = nil
local measureTf  = nil  -- 量宽度用的子树根 Transform
local rootRect   = nil
local travel     = 0    -- 出屏位移量（正值 = 向左推多远）
local slideState = "base"   -- base 原位 / moving 播动画 / hidden 已在屏外
local closeGuard = false
local closeCbs   = {}
local stateTimer = nil

-- tolua 的 Ease 是运行期注册的：取不到就不设，异常被 pcall 吃掉会整段静默不播
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能取字段
local function Alive(obj)
    if obj == nil then
        return false
    end
    if type(obj) == "userdata" then
        return not IsNull(obj)
    end
    return true
end

-- 递归求子树里最靠右的 x（rootRect 本地坐标，原点在 root 的 pivot 上）
-- 🔴 只算"真的会画东西"的节点（有 CanvasRenderer）：layout / settingInfo 这类纯容器是满屏尺寸，
--    把它们算进去会把内容宽度直接顶到屏宽，滑出距离就白多了 500px。
local function MeasureRight(tr, best)
    local rt = tr:GetComponent("RectTransform")
    if Alive(rt) and Alive(tr:GetComponent("CanvasRenderer")) then
        local r = rt.rect
        local x = rootRect:InverseTransformPoint(rt:TransformPoint(Vector3.New(r.xMax, 0, 0))).x
        if x > best then
            best = x
        end
    end
    for i = 0, tr.childCount - 1 do
        local child = tr:GetChild(i)
        if Alive(child) and child.gameObject.activeSelf then
            best = MeasureRight(child, best)
        end
    end
    return best
end

-- 出屏位移量：把「可见内容最右边缘」推到屏幕左边缘之外（内容宽度随语言/数据变，所以现场量）
local function GetTravel()
    if travel > 0 then
        return travel
    end
    local width = Alive(rootRect) and rootRect.rect.width or 1080
    local right = 0
    if Alive(measureTf) and Alive(rootRect) then
        local ok = pcall(function() right = MeasureRight(measureTf, 0) end)
        if not ok then right = 0 end
    end
    if right > 0 and Alive(rootRect) then
        -- right 是相对 root 中心的坐标 ⇒ 加 pivot 偏移换成「距屏幕左边缘」
        right = right + rootRect.rect.width * rootRect.pivot.x
    end
    if right <= 0 then
        right = width * kTravelFallback
    end
    if right > width then
        right = width
    end
    travel = right + kSlideMargin
    return travel
end

-- 复位到原位 + 清掉所有 tween。真正关闭 / 销毁 / 异常回滚都走这里。
function this.ResetSlide()
    if Alive(stateTimer) then
        stateTimer:Stop()
    end
    stateTimer = nil
    for i = 1, #slideItems do
        local item = slideItems[i]
        if Alive(item.tween) then
            item.tween:Kill(false)
        end
        item.tween = nil
        if Alive(item.rt) then
            item.rt.anchoredPosition = Vector2.New(item.baseX, item.rt.anchoredPosition.y)
        end
    end
    if Alive(maskTween) then
        maskTween:Kill(false)
    end
    maskTween = nil
    if Alive(maskImage) then
        local c = maskImage.color
        maskImage.color = Color.New(c.r, c.g, c.b, maskAlpha)
    end
    slideState = "base"
    -- 关闭态一起清：真关掉/销毁之后不该再留着"正在关"的标记，
    -- 否则被打断过的关闭会让后续 OnCloseBefore 直接 return（面板永远关不掉）
    closeGuard = false
    closeCbs = {}
end

-- 打开：从屏幕左外侧向右滑入 + 遮罩淡入。
-- 已在下滑中就直接跳过（连开/重入时重播 = 面板刚到位又被弹回屏外）。
function this.PlaySlideOpen()
    if slideState == "moving" then
        -- 上一轮（滑入或滑出）还没播完：直接跳过。
        -- 两条关闭路径都会在动画期间关掉 eventSystem，玩家点不动，实际撞不上
        return
    end
    if #slideItems == 0 then
        return  -- 节点没取到：静默跳过，绝不把打开流程卡住
    end
    if slideState == "base" then
        travel = 0  -- 只有停在原位时才重新量（文案/语言会改变内容宽度）
    end
    local dist = GetTravel()
    local ok = pcall(function()
        slideState = "moving"
        local pending = 0
        for i = 1, #slideItems do
            local item = slideItems[i]
            local rt = item.rt
            if Alive(rt) then
                if Alive(item.tween) then
                    item.tween:Kill(false)
                end
                local baseY = rt.anchoredPosition.y
                rt.anchoredPosition = Vector2.New(item.baseX - dist, baseY)
                local tween = rt:DOAnchorPosX(item.baseX, kOpenDuration)
                SetEaseSafe(tween, "OutQuad")
                item.tween = tween
                pending = pending + 1
                tween:OnComplete(function()
                    -- 精确落位，别靠 tween 尾帧浮点值
                    if Alive(rt) then
                        rt.anchoredPosition = Vector2.New(item.baseX, baseY)
                    end
                    pending = pending - 1
                    if pending <= 0 then
                        slideState = "base"
                        if Alive(stateTimer) then
                            stateTimer:Stop()
                        end
                        stateTimer = nil
                    end
                end)
            end
        end
        if Alive(maskImage) then
            local c = maskImage.color
            maskImage.color = Color.New(c.r, c.g, c.b, 0)
            maskTween = maskImage:DOFade(maskAlpha, kMaskFadeDuration)
            SetEaseSafe(maskTween, "OutQuad")
        end
        if pending <= 0 then
            slideState = "base"
        end
        -- 兜底：tween 被外部 Kill 时 OnComplete 不会回调，否则会永久卡在 moving
        if Alive(stateTimer) then
            stateTimer:Stop()
        end
        stateTimer = Timer.New(function() slideState = "base" end, kOpenDuration + kStateTimeoutPad)
        stateTimer:Start()
    end)
    if not ok then
        this.ResetSlide()
    end
end

-- 关闭：向左滑出 + 遮罩淡出，播完再放行。
-- 🔴 callback 必须被调用：UIManager 有两条路在等它（CloseStackPanel/CloseFixedPanel 的
--    closeAction，以及 GetPanel 里"等旧面板播完关闭动画再开新全屏面板"），漏调 = 面板关不掉/新面板打不开。
function SettingPanel:OnCloseBefore(callback)
    if callback then
        closeCbs[#closeCbs + 1] = callback
    end
    if closeGuard then
        return  -- 已在播：这一轮的 callback 排队，等播完统一放行
    end
    closeGuard = true
    local finished = false
    local function Finish()
        if finished then
            return
        end
        finished = true
        closeGuard = false
        if Alive(stateTimer) then
            stateTimer:Stop()
        end
        stateTimer = nil
        if Alive(maskTween) then
            maskTween:Kill(false)
        end
        maskTween = nil
        for i = 1, #slideItems do
            slideItems[i].tween = nil
        end
        -- 停在"屏外"而不是复位：面板可能只是被新面板盖住，回头还要从这里滑回来
        slideState = "hidden"
        local cbs = closeCbs
        closeCbs = {}
        for i = 1, #cbs do
            local ok = pcall(cbs[i])
            if not ok then
                LogError("SettingPanel:OnCloseBefore callback error")
            end
        end
    end
    if #slideItems == 0 then
        Finish()
        return
    end
    local dist = GetTravel()
    local ok = pcall(function()
        slideState = "moving"
        local pending = 0
        for i = 1, #slideItems do
            local item = slideItems[i]
            local rt = item.rt
            if Alive(rt) then
                if Alive(item.tween) then
                    item.tween:Kill(false)
                end
                local tween = rt:DOAnchorPosX(item.baseX - dist, kCloseDuration)
                SetEaseSafe(tween, "InQuad")
                item.tween = tween
                pending = pending + 1
                tween:OnComplete(function()
                    pending = pending - 1
                    if pending <= 0 then
                        Finish()
                    end
                end)
            end
        end
        if Alive(maskImage) then
            if Alive(maskTween) then
                maskTween:Kill(false)
            end
            maskTween = maskImage:DOFade(0, kMaskFadeDuration)
            SetEaseSafe(maskTween, "InQuad")
            pending = pending + 1
            maskTween:OnComplete(function()
                pending = pending - 1
                if pending <= 0 then
                    Finish()
                end
            end)
        end
        if pending <= 0 then
            Finish()
        end
    end)
    if not ok then
        Finish()
        return
    end
    -- 兜底：tween 被外部 Kill（DOTween.KillAll / 切场景）时必须自己放行
    if not finished then
        local timer = Timer.New(function() Finish() end, kCloseDuration + kStateTimeoutPad)
        timer:Start()
    end
end

--初始化组件（用于子类重写）
function SettingPanel:InitComponent()
    -- for i = 1, 4 do
    --     tabBtns[i] = Util.GetGameObject(this.transform, "btnList/btn"..i)
    -- end
    -- this.selectBtn = Util.GetGameObject(this.transform, "selectBtn")
    this.btnBackSetting = Util.GetGameObject(this.transform, "settingInfo/btnBack")
    this.BackMask = Util.GetGameObject(this.transform, "BackMask")

    this.settingInfo = SettingInfo.new(self, Util.GetGameObject(self.transform, "layout/settingInfo"))
    -- this.settingPlayerBg = Util.GetGameObject(self.transform, "layout/settingPlayerBgImage")
    -- this.settingPlayerTitle = SettingPlayerTitle.new(self, Util.GetGameObject(self.transform, "layout/settingPlayerTitle"))
    -- this.settingPlayerRide = SettingPlayerRide.new(self, Util.GetGameObject(self.transform, "layout/settingPlayerRide"))
    -- this.settingPlayerSkin = SettingPlayerSkin.new(self, Util.GetGameObject(self.transform, "layout/settingPlayerSkin"))

    this.settingInfoGo = Util.GetGameObject(this.gameObject, "layout/settingInfo")
    -- this.settingPlayerTitleGo = Util.GetGameObject(this.gameObject, "layout/settingPlayerTitle")
    -- this.settingPlayerRideGo = Util.GetGameObject(this.gameObject, "layout/settingPlayerRide")
    -- this.settingPlayerSkinGo = Util.GetGameObject(this.gameObject, "layout/settingPlayerSkin")

    -- 滑动动画：基准 x 只在这里取一次（此时是 prefab 默认值），后续全靠 baseX 复位
    rootRect = self.transform:GetComponent("RectTransform")
    measureTf = Util.GetGameObject(self.transform, kMeasureNode)
    slideItems = {}
    travel = 0
    slideState = "base"
    for i = 1, #kSlideNodes do
        local go = Util.GetGameObject(self.transform, kSlideNodes[i])
        if Alive(go) then
            local rt = go:GetComponent("RectTransform")
            if Alive(rt) then
                slideItems[#slideItems + 1] = { rt = rt, baseX = rt.anchoredPosition.x }
            end
        end
    end
    local maskGo = Util.GetGameObject(self.transform, kMaskNode)
    maskImage = nil
    if Alive(maskGo) then
        maskImage = maskGo:GetComponent("Image")
        if Alive(maskImage) then
            local a = maskImage.color.a
            if a > 0 then
                maskAlpha = a
            end
        end
    end
end

--绑定事件（用于子类重写）
function SettingPanel:BindEvent()
    Util.AddClick(this.btnBackSetting, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
    -- for i = 1, 4 do
    --     if i == 1 then
    --         Util.AddClick(tabBtns[i], function()
    --             this.OnShowPanelData(i)
    --         end)
    --     else
    --         Util.AddClick(tabBtns[i], function()
    --             PopupTipPanel.ShowTipByLanguageId(11902)
    --         end)
    --     end
    -- end
    this.settingInfo.BindEvent()
    -- this.settingPlayerTitle.BindEvent()
    -- this.settingPlayerRide.BindEvent()
    -- this.settingPlayerSkin.BindEvent()
end

--添加事件监听（用于子类重写）
function SettingPanel:AddListener()
    this.settingInfo.AddListener()
    -- this.settingPlayerTitle.AddListener()
    -- this.settingPlayerRide.AddListener()
    -- this.settingPlayerSkin.AddListener()
end

--移除事件监听（用于子类重写）
function SettingPanel:RemoveListener()
    this.settingInfo.RemoveListener()
    -- this.settingPlayerTitle.RemoveListener()
    -- this.settingPlayerRide.RemoveListener()
    -- this.settingPlayerSkin.RemoveListener()
end

--界面打开时调用（用于子类重写）
function SettingPanel:OnOpen(index)
    funIndex = index or 1
    this.pendingSlideOpen = true  -- 首次打开/重新打开才算"打开"，IsBackOpen 不进这里（见 OnShow）
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SettingPanel:OnShow()
    this.OnShowPanelData(funIndex)
    -- 两种情形要滑入：① 真的打开了（OnOpen 设过标记）；② 被新面板盖住后回头显示（停在屏外）。
    -- 其余（例如已在原位的面板被重新 Show）不播，免得无端"飞一次"。
    local wantPlay = false
    if this.pendingSlideOpen then
        this.pendingSlideOpen = false
        wantPlay = true
    elseif slideState == "hidden" then
        wantPlay = true
    end
    if wantPlay then
        this.PlaySlideOpen()
    end
end
function this.OnShowPanelData(_funIndex)
    funIndex = _funIndex
    this.settingInfoGo:SetActive(false)
    -- this.settingPlayerTitleGo:SetActive(false)
    -- this.settingPlayerRideGo:SetActive(false)
    -- this.settingPlayerSkinGo:SetActive(false)
    -- this.settingPlayerBg:SetActive(true)
    -- this.SetSelectBtn(funIndex)
    -- if funIndex == 1 then--信息
    --     this.settingPlayerBg:SetActive(false)
        this.settingInfoGo:SetActive(true)
        this.settingInfo.OnShow()
    -- elseif funIndex == 2 then--称号
    --     this.settingPlayerTitleGo:SetActive(true)
    --     this.settingPlayerTitle.OnShow()
    -- elseif funIndex == 3 then--坐骑
    --     this.settingPlayerRideGo:SetActive(true)
    --     this.settingPlayerRide.OnShow()
    -- elseif funIndex == 4 then--皮肤
    --     this.settingPlayerSkinGo:SetActive(true)
    --     this.settingPlayerSkin.OnShow()
    -- end
end
-- function this.SetSelectBtn(index)
--     this.selectBtn.transform:SetParent(tabBtns[index].transform)
--     this.selectBtn.transform.localScale = Vector3.one
--     this.selectBtn.transform.localPosition = Vector3.zero
--     Util.GetGameObject(this.selectBtn.transform, "Text"):GetComponent("Text").text = Util.GetGameObject(tabBtns[index].transform, "Text"):GetComponent("Text").text
-- end
--界面关闭时调用（用于子类重写）
function SettingPanel:OnClose()
    this.settingInfo.OnClose()
    -- this.settingPlayerTitle.OnClose()
    -- this.settingPlayerRide.OnClose()
    -- this.settingPlayerSkin.OnClose()
    this.ResetSlide()  -- 真关掉（GameObject 已 inactive）后复位，下次打开从原位重新量/重新滑
end

--界面销毁时调用（用于子类重写）
function SettingPanel:OnDestroy()
    this.settingInfo.OnDestroy()
    -- this.settingPlayerTitle.OnDestroy()
    -- this.settingPlayerRide.OnDestroy()
    -- this.settingPlayerSkin.OnDestroy()
    this.ResetSlide()
end

return SettingPanel
