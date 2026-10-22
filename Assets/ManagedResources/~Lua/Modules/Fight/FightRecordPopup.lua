require("Base/BasePanel")
FightRecordPopup = Inherit(BasePanel)
local this = FightRecordPopup
-- local fightPopup = require("Modules/Fight/FightRecordPopup")
local fightLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local isBattle = true
this.firstData = nil
this.scandData = nil
this.threeData = nil
--============================== 战斗记录卡入场（右滑入 + 淡入）==============================
-- 参考 Assets/Art/UIAni/cn2-X1_UI_TreasureStorePopup.anim（docs/ui_item_slide_in_skill.md 配方）：
--   grid/item1..3     m_AnchoredPosition.x   -200/-150/-100 → 0   逐格错开（左侧滑入）
--   grid/item1..3/Bg  m_Color.a              0.3647 → 1           淡入比位移长
-- 本页按要求做**反向**：从右侧 +260 向左归位，三张 RewardInfoGroupPre 陆续嵌进来。
-- 承载判断（docs/ui_item_slide_in_skill.md §4/§9）：
--   Bg/Grid 挂的是 VerticalLayoutGroup ⇒ 卡根 anchoredPosition 会被布局重建抹回 ⇒ 位移只写卡的可视子节点；
--   卡根节点自己就是整卡那张 Image（1080×260）⇒ 淡入走 card:GetComponent("Image")
--   （底板形态二，同 MissionDailyPanel_Daily，不翻子节点）。
-- 播放时机：OnOpen 收到有效数据后置 needSlideAnim，OnShow 末尾消费 —— 本弹窗从战斗回显返回时
-- OnShow 会再走一次（BasePanel:OpenUI(IsBackOpen)），闸门放 OnOpen 防止每次返回都重播（同 MapPanel §10）。
-- 无 tab、无数据刷新路径 ⇒ 不需要 suppress / 切页签那套第二节奏。
local kSlideFrom     = 260      -- 起点位移（px），卡宽 1080 的 ~24%
local kSlideDuration = 0.26     -- 单卡时长
local kSlideStep     = 0.055    -- 相邻卡错开
local kFadeFrom      = 0.3647   -- 参考 item/Bg 的 alpha 起点

-- 卡的可视子节点（一起右移 = 整卡滑入）。GoFightBtn 里还有个同名 Image，
-- Util.GetGameObject 先做直接子节点 Find 命中的是卡自己那张，同名不碍事（CourtesyDressPanel 同款依赖）。
local kSlideNodes = { "titleImage", "type", "Name", "Image", "desc", "headPos", "GoFightBtn" }
local slideItems   = {}         -- { rect, x, y, graphic, color, tween }，rect 与 graphic 二选一
local slidePlaying = false      -- 这一轮还没播完（快速关开靠它判断，别叠着播）
local slidePending = 0          -- 还有几条 tween 没完成；减到 0 才算播完
this.needSlideAnim = false      -- OnOpen 有有效数据时置 true，OnShow 末尾消费

-- tolua 的枚举是运行期注册的：取不到就跳过，异常被 pcall 吃掉会整段静默不播
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

local function WithAlpha(color, a)
    return Color.New(color.r, color.g, color.b, a)
end

-- 回收：Kill 掉所有 tween 并把位置/颜色复位。
-- 🔴 漏复位 = 战斗记录卡永久停在半截位置或半透明；重播 / 关闭 / 销毁都必须走这里。
function this.StopSlideIn()
    -- Kill 不会回调 OnComplete => 播中标记必须在这里自己清，否则一次 Stop 之后
    -- 后面所有入场都会被「连点保护」当成播中而跳过
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

-- 收集当前可见的战斗记录卡（Bg/Grid 下三张固定 Pre，OnOpen 按 dataID SetActive）
local function CollectCards()
    local cards = {}
    for _, go in ipairs({ this.rewInfo1, this.rewInfo2, this.rewInfo3 }) do
        if Alive(go) and go.activeSelf then
            cards[#cards + 1] = go
        end
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
            -- 位移：卡的可视子节点一起走（VerticalLayoutGroup 会重写卡根，别碰）
            for i = 1, #kSlideNodes do
                local go = Util.GetGameObject(card, kSlideNodes[i])
                if Alive(go) and go.activeSelf then
                    local rect = go:GetComponent("RectTransform")
                    if Alive(rect) then
                        local pos = rect.anchoredPosition
                        -- 从右侧滑入：起点在右边，向左归位（要改回左侧只需把这里的 + 改成 -）
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
            -- 淡入：只淡整卡那张底板（卡根节点自己的 Image）
            if Alive(card) then
                local image = card:GetComponent("Image")
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
        -- DOTween 侧任何异常都不能把战斗记录卡留在半截位置/半透明
        LogError("FightRecordPopup: 战斗记录卡入场失败 " .. tostring(err))
        this.StopSlideIn()
        return 0
    end
    if slidePending == 0 then
        slidePlaying = false
    end
    return #cards
end

--初始化组件（用于子类重写）
function FightRecordPopup:InitComponent()
    -- fightPopup:InitComponent(self.gameObject, this)
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "closeBtn")
    this.rewInfo1 = Util.GetGameObject(self.gameObject, "Bg/Grid/RewardInfoGroupPre1")
    this.rewInfo2 = Util.GetGameObject(self.gameObject, "Bg/Grid/RewardInfoGroupPre2")
    this.rewInfo3 = Util.GetGameObject(self.gameObject, "Bg/Grid/RewardInfoGroupPre3")
end

--绑定事件（用于子类重写）
function FightRecordPopup:BindEvent()
    Util.AddClick(this.btnClose,function ()
        UIManager.OpenPanel(UIName.FightPointPassMainPanel)
    end)
    Util.AddClick(this.BackMask,function ()
        UIManager.OpenPanel(UIName.FightPointPassMainPanel)
    end)
end

--添加事件监听（用于子类重写）
function FightRecordPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function FightRecordPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function FightRecordPopup:OnOpen(msg)

    if msg.levelData == nil or msg.levelData[1] == nil then
        this.btnClose = Util.GetGameObject(self.gameObject, "NoPeople"):SetActive(true)
        return
    end
    this.rewInfo1:SetActive(false)
    this.rewInfo2:SetActive(false)
    this.rewInfo3:SetActive(false)
    for key, value in pairs(msg.levelData) do
        if value.dataID ~= nil then
            if value.dataID == 1 then
                this.firstData = value
                this.rewInfo1:SetActive(true)
                -- Util.GetGameObject(this.rewInfo1, "desc"):GetComponent("Text").text=GetLanguageStrById(22291)..GetTimeMaoHaoStrBySeconds(value.playTime)
                Util.GetGameObject(this.rewInfo1, "desc"):GetComponent("Text").text = GetLanguageStrById(22292)..value.curFormationIndex
                Util.GetGameObject(this.rewInfo1, "Name"):GetComponent("Text").text = value.playName
                Util.GetGameObject(this.rewInfo1, "headPos/headIcon"):GetComponent("Image").sprite = GetPlayerHeadSprite(value.headId)
                Util.AddOnceClick(Util.GetGameObject(this.rewInfo1, "GoFightBtn"),function ()
                    if  isBattle  then
                        isBattle = false
                        BattleManager.GotoFight(function()
                            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                            FightRecordPopup.SetFightInfo(value)
                            local fightData = BattleManager.GetBattleServerData({fightData = value.fightData}, 0)
                            fightData.mapName = fightLevelConfig[FightPointPassManager.curOpenFight].BG
                            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                               isBattle = true
                            end)
                            end)
                        end)
                    end
                   
                end)
            end
            if value.dataID == 2 then
                this.scandData = value
                this.rewInfo2:SetActive(true)
                -- Util.GetGameObject(this.rewInfo2, "desc"):GetComponent("Text").text=GetLanguageStrById(22291)..GetTimeMaoHaoStrBySeconds(value.playTime)
                Util.GetGameObject(this.rewInfo2, "desc"):GetComponent("Text").text = GetLanguageStrById(22292)..value.curFormationIndex
                Util.GetGameObject(this.rewInfo2, "Name"):GetComponent("Text").text = value.playName
                Util.GetGameObject(this.rewInfo2, "headPos/headIcon"):GetComponent("Image").sprite = GetPlayerHeadSprite(value.headId)
                Util.AddOnceClick(Util.GetGameObject(this.rewInfo2, "GoFightBtn"),function ()
                    if  isBattle  then
                        isBattle = false
                        BattleManager.GotoFight(function()
                            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                            FightRecordPopup.SetFightInfo(value)
                            local fightData = BattleManager.GetBattleServerData({fightData = value.fightData}, 0)
                            fightData.mapName = fightLevelConfig[FightPointPassManager.curOpenFight].BG
                            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                                isBattle = true
                            end)
                            end)
                        end)
                    end
                end)
            end
            if value.dataID == 3 then
                this.threeData = value
                this.rewInfo3:SetActive(true)
                Util.GetGameObject(this.rewInfo3, "desc"):GetComponent("Text").text = GetLanguageStrById(22292)..value.curFormationIndex
                Util.GetGameObject(this.rewInfo3, "Name"):GetComponent("Text").text = value.playName
                Util.GetGameObject(this.rewInfo3, "headPos/headIcon"):GetComponent("Image").sprite = GetPlayerHeadSprite(value.headId)
                Util.AddOnceClick(Util.GetGameObject(this.rewInfo3, "GoFightBtn"),function ()
                    if  isBattle  then
                        isBattle = false
                        BattleManager.GotoFight(function()
                            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                            FightRecordPopup.SetFightInfo(value)
                            local fightData = BattleManager.GetBattleServerData({fightData = value.fightData}, 0)
                            fightData.mapName = fightLevelConfig[FightPointPassManager.curOpenFight].BG
                            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                                isBattle = true
                            end)
                            end)
                        end)
                    end
                    
                    
                    
                end)
            end
        end
    end
    -- 有有效数据才入场；空数据（NoPeople 分支）不置标记
    this.needSlideAnim = true
end

function FightRecordPopup.SetFightInfo(sData)
    
    local data = sData
    --> fightInfo
    local structA = {
        head = data.headId,
        headFrame = data.headFrame,
        name = data.playName,
        formationId = data.formationId or 1,
        investigateLevel=data.investigateLevel
    }
    local _monsterGroupId = G_MainLevelConfig[FightPointPassManager.curOpenFight].MonsterGroup
    local monsterShowId = GetMonsterGroupFirstEnemy(_monsterGroupId)
    local heroid = G_MonsterConfig[monsterShowId].MonsterId
    local image = GetResourcePath(G_HeroConfig[heroid].Icon)
    local structB = {
        head = tostring(image),
        headFrame = nil,
        name = nil,
        formationId = G_MonsterGroup[_monsterGroupId].Formation,
        investigateLevel=1
    }
    BattleManager.SetAgainstInfoData(BATTLE_TYPE.BACK, structA, structB)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FightRecordPopup:OnShow()
    isBattle = true
    -- 只有 OnOpen 带了新数据这一次播入场；战斗回显返回触发的 OnShow 不重播
    if this.needSlideAnim then
        this.needSlideAnim = false
        this.PlaySlideIn()
    end
end

--界面关闭时调用（用于子类重写）
function FightRecordPopup:OnClose()
    this.StopSlideIn()
end

--界面销毁时调用（用于子类重写）
function FightRecordPopup:OnDestroy()
    this.StopSlideIn()
    this.needSlideAnim = false
end

return FightRecordPopup