require("Base/BasePanel")
LaddersTypePanel = Inherit(BasePanel)
local this = LaddersTypePanel
local orginLayer = 0
local trigger = nil
local SpecialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local type = {
        [1] = {--跨服竞技场
            open = true,
            id = FUNCTION_OPEN_TYPE.laddersChallenge,
            bg = "cn2-X1_wuxianzhanzhen_02_zh",
            bgEn = "cn2-X1_wuxianzhanzhen_02_en",
            name = GetLanguageStrById(50167),
            resetTime = string.format("<color=#a6b6d8>%s</color>", GetLanguageStrById(SpecialConfig[58].Value)),
            tip = GetLanguageStrById(50304),
            spevialId = 153,
            redPointType = RedPointType.LaddersChallenge,
            r = 0,
        },
        [2] = {--混乱之治
            open = true,
            id = FUNCTION_OPEN_TYPE.ChaosZZ,
            bg = "cn2-X1_kuafu_rukou",
            -- 图集里的中文原图没有 _zh 后缀，英文版单独出一张并登记成 _en
            bgEn = "cn2-X1_kuafu_rukou_en",
            name = GetLanguageStrById(16010080),
            resetTime = "",
            tip = "每周一0点~周五22点开启",
            spevialId = 551,  --奖励
            redPointType = -1,
            r = 0,
        },
        [3] = {--nil
            open = true,
            id = nil,
            bg = "cn2-X1_wuxianzhanzhen_02_zh",
            bgEn = "cn2-X1_wuxianzhanzhen_02_en",
            name = GetLanguageStrById(50167),
            resetTime = string.format("<color=#a6b6d8>%s</color>", GetLanguageStrById(SpecialConfig[58].Value)),
            tip = GetLanguageStrById(50304),
            spevialId = 153,
            redPointType = -1,
            r = 0,
        },
        [4] = {--nil
            open = true,
            id =nil,
            bg = "cn2-X1_wuxianzhanzhen_02_zh",
            bgEn = "cn2-X1_wuxianzhanzhen_02_en",
            name = GetLanguageStrById(50167),
            resetTime = string.format("<color=#a6b6d8>%s</color>", GetLanguageStrById(SpecialConfig[58].Value)),
            tip = GetLanguageStrById(50304),
            spevialId = 153,
            redPointType = -1,
            r = 0,
        },
        default =
        {
            id = -1,
        }
}
this.ItemViews = {}

--============================== 入场卡滑入（左滑入右：从右侧滑回原位 + 底板淡入）==============================
-- 参考 Assets/Art/UIAni/cn2-X1_UI_TreasureStorePopup.anim（docs/ui_item_slide_in_skill.md 配方）：
--   grid/item1..3     m_AnchoredPosition.x   -200/-150/-100 → 0   逐格错开（左侧滑入）
--   grid/item1..3/Bg  m_Color.a              0.3647 → 1           淡入比位移长
-- 本页按需求做**反向**：左滑入右 —— 卡从右侧 +260 向左归位（同 BattlePass 及后续落地的主流方向）。
-- 承载判断（docs/ui_item_slide_in_skill.md §4/§9）：
--   列表是 ScrollCycleView ⇒ SetData/SetItemIndex 会直接赋值 item 根的 anchoredPosition ⇒
--   位移只写 item 的可视子节点，不碰根节点。
--   卡的可视节点是直接子节点 Icon（1080x488 满幅，自带 Image，RefreshItem 就是往它设 sprite）；
--   Bg 是废弃遗留（INACTIVE 860x1121），nil 是占位卡。淡入与位移同落 Icon（CourtesyDressPanel 同款双通道）。
-- 播放时机：OnOpen SetData 后置 needSlideAnim，OnShow 末尾消费 —— 进无尽 PK/混乱之治再返回时
-- OnShow 会再走（BasePanel:OpenUI(IsBackOpen)），闸门放 OnOpen 防止每次返回都重播（同 FightRecordPopup）。
-- 无页签、无数据刷新路径（SetData 只在 OnOpen）⇒ 不需要 suppress / 切页签第二节奏。
-- 🔴 本文件顶部 local type = {...} 遮住了全局 type()（配方 §7 第 8 条），新增代码一律不许调 type()。
local kSlideFrom     = 260      -- 起点位移（px），卡宽 1080 的 ~24%
local kSlideDuration = 0.26     -- 单卡时长（打开那一套）
local kSlideStep     = 0.055    -- 相邻卡错开
local kFadeFrom      = 0.3647   -- 参考 item/Bg 的 alpha 起点

-- 卡的可视子节点（一起右移 = 整卡滑入）。Icon/nil 都是 rewardPre 的直接子节点，直接子节点 Find 先命中。
local kSlideNodes = { "Icon", "nil" }
local slideItems   = {}         -- { rect, x, y, graphic, color, tween }，rect 与 graphic 二选一
local slidePlaying = false      -- 这一轮还没播完（快速关开靠它判断，别叠着播）
local slidePending = 0          -- 还有几条 tween 没完成；减到 0 才算播完
this.needSlideAnim = false      -- OnOpen 置 true，OnShow 末尾消费

-- tolua 的枚举是运行期注册的：取不到就跳过，异常被 pcall 吃掉会整段静默不播
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能取字段。
-- 🔴 本文件第 7 行 local type = {...} 遮住了全局 type()，必须走 _G.type（配方 §7 第 8 条）
local rawtype = _G.type
local function Alive(obj)
    if obj == nil then
        return false
    end
    if rawtype(obj) == "userdata" then
        return not IsNull(obj)
    end
    return true
end

local function WithAlpha(color, a)
    return Color.New(color.r, color.g, color.b, a)
end

-- 回收：Kill 掉所有 tween 并把位置/颜色复位。
-- 🔴 漏复位 = 卡永久停在半截位置或半透明；重播 / 关闭 / 销毁都必须走这里。
function this.StopSlideIn()
    -- Kill 不会回调 OnComplete => 播中标记必须在这里自己清，否则一次 Stop 之后
    -- 后面所有入场都会被「播中保护」当成播中而跳过
    slidePlaying = false
    slidePending = 0
    for i = #slideItems, 1, -1 do
        local item = slideItems[i]
        if Alive(item.tween) then
            item.tween:Kill(false)
        end
        if item.rect and item.x and Alive(item.rect) then
            item.rect.anchoredPosition = Vector2.New(item.x, item.y)
        end
        if item.graphic and item.color and Alive(item.graphic) then
            item.graphic.color = item.color
        end
        slideItems[i] = nil
    end
end

-- 收集当前可见的入场卡（ScrollCycleView 只给可见 item，顺序即列表顺序）
local function CollectCards()
    local cards = {}
    local sv = this.ScrollView
    if sv ~= nil and sv.ForeachItemGO ~= nil then
        sv:ForeachItemGO(function(_, go)
            if Alive(go) and go.activeSelf then
                cards[#cards + 1] = go
            end
        end)
    end
    return cards
end

-- 起播：每张卡从右侧滑回原位，整卡底板 alpha 0.3647 → 1
function this.PlaySlideIn()
    -- 快速关开：上一轮还没播完就只复位、不再重播 —— 复位到终值本身就是「立刻到位」
    local interrupted = slidePlaying
    this.StopSlideIn()
    if interrupted then
        return 0
    end
    local cards = CollectCards()
    if #cards <= 0 then
        return 0
    end
    -- 每完成一条减一，减到 0 才算这一轮播完（Kill 不会回调 OnComplete，见 StopSlideIn）
    local function Done()
        slidePending = slidePending - 1
        if slidePending <= 0 then
            slidePending = 0
            slidePlaying = false
        end
    end
    slidePlaying = true
    local ok, err = pcall(function()
        for ci = 1, #cards do
            local card = cards[ci]
            local delay = (ci - 1) * kSlideStep
            -- 位移：卡的可视子节点一起走（ScrollCycleView 会重写卡根，别碰）
            for i = 1, #kSlideNodes do
                local go = Util.GetGameObject(card, kSlideNodes[i])
                if Alive(go) and go.activeSelf then
                    local rect = go:GetComponent("RectTransform")
                    if Alive(rect) then
                        local pos = rect.anchoredPosition
                        -- 左滑入右：起点在右边，向左归位（要改回左侧只需把这里的 + 改成 -）
                        rect.anchoredPosition = Vector2.New(pos.x + kSlideFrom, pos.y)
                        local tween = rect:DOAnchorPosX(pos.x, kSlideDuration)
                        tween:SetDelay(delay)
                        SetEaseSafe(tween, "OutQuad")
                        slidePending = slidePending + 1
                        tween:OnComplete(function()
                            if Alive(rect) then
                                rect.anchoredPosition = Vector2.New(pos.x, pos.y)
                            end
                            Done()
                        end)
                        slideItems[#slideItems + 1] = { rect = rect, x = pos.x, y = pos.y, tween = tween }
                    end
                end
            end
            -- 淡入：只淡整卡那张可视底板（Icon 自己的 Image）
            local fadeGo = Util.GetGameObject(card, "Icon")
            if Alive(fadeGo) then
                local image = fadeGo:GetComponent("Image")
                if Alive(image) then
                    local color = image.color
                    image.color = WithAlpha(color, kFadeFrom)
                    local tween = image:DOFade(color.a, kSlideDuration)
                    tween:SetDelay(delay)
                    SetEaseSafe(tween, "OutQuad")
                    slidePending = slidePending + 1
                    tween:OnComplete(function()
                        if Alive(image) then
                            image.color = color
                        end
                        Done()
                    end)
                    slideItems[#slideItems + 1] = { graphic = image, color = color, tween = tween }
                end
            end
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把卡留在半截位置/半透明
        LogError("LaddersTypePanel: 入场卡滑入失败 " .. tostring(err))
        this.StopSlideIn()
        return 0
    end
    if slidePending == 0 then
        slidePlaying = false
    end
    return #cards
end

--初始化组件（用于子类重写）
function LaddersTypePanel:InitComponent()
    orginLayer = 0

    this.Bg = Util.GetGameObject(self.gameObject,"Bg")
    this.backBtn = Util.GetGameObject(self.gameObject, "Bg/backBtn")
    -- this.title = Util.GetGameObject(self.gameObject,"Bg/Title/title"):GetComponent("Text")
    this.ImageRot = Util.GetGameObject(self.gameObject,"Bg/ImageRot")
    this.ImageMinRot = Util.GetGameObject(self.gameObject,"Bg/ImageMinRot")

    --列表
    this.rewardPre = Util.GetGameObject(self.gameObject, "Bg/rewardPre")
    local rect = Util.GetGameObject(self.gameObject, "Bg/rect")
    local v = rect:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, rect.transform,
            this.rewardPre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.NoviceItemList = {}--存储itemview 重复利用

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
end

--绑定事件（用于子类重写）
function LaddersTypePanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function LaddersTypePanel:AddListener()
end

--移除事件监听（用于子类重写）
function LaddersTypePanel:RemoveListener()
end

--副本类型 
function LaddersTypePanel:OnOpen()
    this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})

    -- fristZ = 0 -- 初始调整旋转位置
    -- rotstionAngle = 0 -- 旋转角度
    -- speed = 4 --旋转度倍数
    --this.ImageRot.transform.localEulerAngles = Vector3.New(0,0,fristZ)
    -- for i = 1, this.ImageRot.transform.childCount do
    --     local Index = Util.GetGameObject(this.ImageRot.transform:GetChild(i-1).gameObject,"Index")
    --     Index.transform:GetChild(0).name = i
    --     this.RefreshItem(this.ImageRot.transform:GetChild(i-1).gameObject,this.GetItem(i))
    -- end
    this.ScrollView:SetData(type, function (index, go)
        this.RefreshItem(go, type[index])
        -- allAchievement[index] = go
    end)
    -- 入场闸门：真正播放在 OnShow 末尾（此刻面板可能还没激活，tween 起来也等 OnShow 后可见）
    this.needSlideAnim = true
    -- if not trigger then
    --     trigger = Util.GetEventTriggerListener(this.Bg)
    --     trigger.onBeginDrag = trigger.onBeginDrag + this.OnBeginDrag
    --     trigger.onDrag = trigger.onDrag + this.OnDrag
    --     trigger.onEndDrag = trigger.onEndDrag + this.OnEndDrag
    -- end
end

--beginDragPosY = 0
--direction = 0 --单纯记录方向，单次只计算一个方向 1是上 -1是下
--isDrag = false
-- function this.OnBeginDrag(p,d)
-- end

-- function this.OnEndDrag(p,d)
--     isDrag = false
-- end

-- function this.OnDrag(p,d)
--     if d.delta.y > 0 then--向上划
--         if rotstionAngle == (this.GetItemCount() - 2)*40 then
--             return
--         end

--         rotstionAngle = rotstionAngle+1*speed
--         this.ImageRot.transform.localEulerAngles = Vector3.New(0,0,rotstionAngle)
--         this.ImageMinRot.transform.localEulerAngles = Vector3.New(0,0,-rotstionAngle)
--     elseif d.delta.y < 0 then--向下划
--         if rotstionAngle == 0 then
--             return
--         end

--         rotstionAngle = rotstionAngle-1*speed
--         this.ImageRot.transform.localEulerAngles = Vector3.New(0,0,rotstionAngle)
--         this.ImageMinRot.transform.localEulerAngles = Vector3.New(0,0,-rotstionAngle)
--     end
-- end

--界面打开时调用（用于子类重写）
function LaddersTypePanel:OnShow(...)
    this.HeadFrameView:OnShow()

    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)-- 音效

    CarbonManager.GetMissionLevelData()

    -- 入场卡滑入：OnOpen 置标记，这里消费 —— 进无尽 PK/混乱之治再返回触发的 OnShow 不重播
    if this.needSlideAnim then
        this.needSlideAnim = false
        this.PlaySlideIn()
    end
end

function this.GetItem(index)
    if type[index] then
        return type[index]
    else
        return type.default
    end
end

function this.GetItemCount()
    local count = 0
    for i = 1, #type do
        if type[i] then
            count = count+1
        end
    end
    return count
end

function this.RefreshItem(go,data)
    local Icon = Util.GetGameObject(go,"Icon")
   -- local Name = Util.GetGameObject(go,"Icon/Name"):GetComponent("Text")
    local Desc = Util.GetGameObject(go,"Icon/Desc"):GetComponent("Text")
    local ResetTime = Util.GetGameObject(go,"Icon/ResetTime"):GetComponent("Text")
     if data.id == nil then
        local nilData = Util.GetGameObject(go,"nil")
        nilData:SetActive(true)
        return
     end
    if data.id ~= -1 then
        BindRedPointObject(data.redPointType,Util.GetGameObject(Icon, "RedPoint"))
        Icon.gameObject:SetActive(true)
        -- 只看 bgEn 在不在：图集里的原图没有 _zh 后缀，
        -- 直接走 GetPictureFont 会拼出并不存在的 _zh/_jp，图片变白；
        -- 日文等暂无译图的语言继续用中文原图。
        local bgName = data.bg
        if data.bgEn ~= nil and GetLan() == 1 then
            bgName = data.bgEn
        end
        Icon:GetComponent("Image").sprite = Util.LoadSprite(bgName)
       -- Icon:GetComponent("Image").alphaHitTestMinimumThreshold = 0.1
        --Name.text = data.name
        Desc.text = data.tip
        ResetTime.text = string.format(data.resetTime)

        Icon:GetComponent("Button").onClick:RemoveAllListeners()
        if data.open then
            Util.SetGray(Icon,false)
            Icon:GetComponent("Button").enabled = true
            Util.AddClick(Icon, function()
                this.BtnClick(data.id)
            end)
        else
            -- 要置灰 不能点击
            Util.SetGray(Icon,true)
            Icon:GetComponent("Button").enabled = false
        end

        Icon:GetComponent("Button").onClick:RemoveAllListeners()

        if ActTimeCtrlManager.SingleFuncState(data.id) == false then
            Util.SetGray(Icon,true)
        end

        local items = this.GetItems(data.spevialId)
        if this.ItemViews[go] then
            for i = 1, #items do
                this.ItemViews[go][i]:OnOpen(false, items[i], 0.5, nil, nil, nil, nil, nil)
                this.ItemViews[go][i].transform.rotation = Vector3.zero
            end
        else
            this.ItemViews[go] = {}
            for i = 1, #items do
                this.ItemViews[go][i]= SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go,"Icon/ItemGrid").transform)
                this.ItemViews[go][i]:OnOpen(false, items[i], 0.5, nil, nil, nil, nil, nil)
                this.ItemViews[go][i].transform.rotation = Vector3.zero
            end
        end

        Util.AddClick(Icon, function()
            this.BtnClick(data.id)
        end)
    else
        Icon.gameObject:SetActive(false)
    end
end

function this.BtnClick(id)
    if id == FUNCTION_OPEN_TYPE.laddersChallenge then
        local peakednessTime= LaddersArenaManager.GetLeftTime()-435600 
        
        if ActTimeCtrlManager.SingleFuncState(id)  then
            NetManager.WorldArenaUnLockRequest(function (msg)
                if msg.unLock and peakednessTime > 0 then
                    local _, myRankInfo = ArenaManager.GetRankInfo()
                    local myRank = myRankInfo.personInfo.rank
                    -- if myRank > 100 then
                    --     PopupTipPanel.ShowTip(GetLanguageStrById(50301))
                    --     return
                    -- end
                    if myRank == -1 then
                        NetManager.RequestArenaRankData(1, function()
                            local _, myRankInfo = ArenaManager.GetRankInfo()
                            local myRank = myRankInfo.personInfo.rank
                            -- if myRank == -1 then
                            --     PopupTipPanel.ShowTip(GetLanguageStrById(50301))
                            --     return
                            -- else
                                UIManager.OpenPanel(UIName.LaddersMainPanel)
                            -- end
                        end)
                    else
                        NetManager.RequestArenaRankData(1, function()
                            UIManager.OpenPanel(UIName.LaddersMainPanel)
                        end)
                    end
                else
                    PopupTipPanel.ShowTip(GetLanguageStrById(10175))
                end
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.laddersChallenge))
        end
    elseif id == FUNCTION_OPEN_TYPE.ChaosZZ  then   --混乱之治
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ChaosZZ) then
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ChaosZZ))
            return
        end
        if ActTimeCtrlManager.SingleFuncState(id) then
            NetManager.CampSimpleInfoGetReq(function (msg)
                if msg.camp ~= 0 then
                    NetManager.CampWarInfoGetReq(function (msg)
                        UIManager.OpenPanel(UIName.ChaosMainPanel, msg)
                    end)
                else
                    UIManager.OpenPanel(UIName.ChaosSelectCampPanel, msg)
                end
            end)
        else
            PopupTipPanel.ShowTip("混乱之治尚未开始")
        end
    end
end

function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.wind, self.sortingOrder - orginLayer)

    orginLayer = self.sortingOrder
end

function LaddersTypePanel.GetItems(index)
    local items = string.split(SpecialConfig[index].Value,"|")
    local itemList = {}
    for i = 1, #items do
        local item = string.split(items[i],"#")
        table.insert(itemList,{[1] = item[1],[2] = item[2]})
    end
    return itemList
end

--界面关闭时调用（用于子类重写）
function LaddersTypePanel:OnClose()
    this.StopSlideIn()
end

--界面销毁时调用（用于子类重写）
function LaddersTypePanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    this.ItemViews = {}
    this.StopSlideIn()
    this.needSlideAnim = false
    -- trigger.onBeginDrag = trigger.onBeginDrag - this.OnBeginDrag
    -- trigger.onDrag = trigger.onDrag - this.OnDrag
    -- trigger.onEndDrag = trigger.onEndDrag - this.OnEndDrag
    -- trigger = nil
end

return LaddersTypePanel