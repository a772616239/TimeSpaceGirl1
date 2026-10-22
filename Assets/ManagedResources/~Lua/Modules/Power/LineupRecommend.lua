require("Base/BasePanel")
local LineupRecommend = Inherit(BasePanel)
local this = LineupRecommend
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local lineupList = {}--阵容列表
local receivedList = {}--奖励领取信息

-- 入场：卡从右往左依次快速滑回原位（配方见 docs/ui_item_slide_in_skill.md）
-- 🔴 Content 上挂着 VerticalLayoutGroup + ContentSizeFitter，每次重建都会重写**卡的根节点**
--    anchoredPosition => 位移只写卡的子节点 iconPanel（卡下唯一；descPanel 是点开才显示的详情，
--    默认隐藏，不参与）。
-- 🔴 没有淡入通道：iconPanel 下三个 Image 同名（1080x885 / 1040x423 x2），Util.GetGameObject
--    按名字 DFS 会命中第一个 => 只做位移，别按名字找底板。
local kSlideFrom     = 240    -- 起点位移（px）：卡宽 1060、视口 1080，再大就被 RectMask2D 裁掉一截
local kSlideDuration = 0.22   -- 单卡时长
local kSlideStep     = 0.055  -- 相邻卡错开
local kSlideNode     = "iconPanel"

local slideItems   = {}     -- { rect, x, y, tween }
local slidePlaying = false  -- 这一轮还没播完（连点靠它挡住叠播）
local slidePending = 0      -- 还有几条 tween 没完成；减到 0 才算播完
local needSlideIn  = false  -- 只有玩家主动打开（OnOpen）才播；从弹窗返回只走 OnShow，不播

-- tolua 的枚举是运行期注册的：取不到就跳过（异常被 pcall 吃掉会整段静默不播）
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能直接取字段
local function Alive(obj)
    if obj == nil then
        return false
    end
    if type(obj) == "userdata" then
        return not IsNull(obj)
    end
    return true
end

-- 回收：Kill 所有 tween 并把位置复位（Kill 不会回调 OnComplete，播中标记必须在这里自己清）
function this.StopSlideIn()
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
        slideItems[i] = nil
    end
end

-- 列表顺序 = lineupList 的顺序（1..N），已 SetActive 的才参与
local function CollectCards()
    local cards = {}
    for i = 1, #lineupList do
        local card = lineupList[i] and lineupList[i].prefab
        if Alive(card) and card.activeSelf then
            cards[#cards + 1] = card
        end
    end
    return cards
end

-- 起播：第 i 张卡从右侧 kSlideFrom 处滑回原位，相邻错开 kSlideStep
function this.PlaySlideIn()
    local interrupted = slidePlaying
    this.StopSlideIn()
    if interrupted then
        -- 连点：上一轮没播完就只复位、不重播（复位到终值本身就是「立刻到位」）
        return 0
    end
    local cards = CollectCards()
    if #cards <= 0 then
        return 0
    end
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
            local go = Util.GetGameObject(cards[ci], kSlideNode)
            if Alive(go) and go.activeSelf then
                local rect = go:GetComponent("RectTransform")
                if Alive(rect) then
                    local pos = rect.anchoredPosition
                    local delay = (ci - 1) * kSlideStep
                    -- 从右侧滑入：起点在右，向左归位（改左侧只需把 + 改成 -）
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
    end)
    if not ok then
        LogError("LineupRecommend: 阵容卡入场失败 " .. tostring(err))
        this.StopSlideIn()
        return 0
    end
    if slidePending == 0 then
        slidePlaying = false
    end
    return #cards
end

-- 播 / 不播的唯一入口：只有「主动打开」那一次播
function this.ApplySlideIn()
    if not needSlideIn then
        -- 没有待播任务：上一轮还在播就让它播完，只清残留
        if not slidePlaying then
            this.StopSlideIn()
        end
        return 0
    end
    needSlideIn = false
    return this.PlaySlideIn()
end

--初始化组件（用于子类重写）
function LineupRecommend:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")

    this.content = Util.GetGameObject(this.gameObject, "Scroll View/Viewport/Content")
    this.prefab = Util.GetGameObject(this.gameObject, "Scroll View/Viewport/Content/prefab")
end

--绑定事件（用于子类重写）
function LineupRecommend:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function LineupRecommend:AddListener()
end

--移除事件监听（用于子类重写）
function LineupRecommend:RemoveListener()
end

--界面打开时调用（用于子类重写）
function LineupRecommend:OnOpen()
    needSlideIn = true
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LineupRecommend:OnShow()
    NetManager.HeroCollectRewardInfo(function (msg)
        receivedList = msg.infos

        local list = ConfigManager.GetAllConfigsDataByKey(ConfigName.BeStronger, "Type", 5)
        for i, v in ipairs(list) do
            if lineupList[i] == nil then
                lineupList[i] = {
                    prefab = nil,
                    cards = {},
                    rawards = {}
                }
            end
            if lineupList[i].prefab == nil then
                lineupList[i].prefab = newObject(this.prefab)
                lineupList[i].prefab.transform:SetParent(this.content.transform)
                lineupList[i].prefab.transform.localScale = Vector3.one
                lineupList[i].prefab:SetActive(true)
            end
            this.SetPrefabData(lineupList[i].prefab, v, i)
        end

        -- 列表建好 / 更新完再播：入场只在「主动打开」那次（needSlideIn 由 OnOpen 置位）
        this.ApplySlideIn()
    end)
    CheckRedPointStatus(RedPointType.LineupRecommend)
end

--界面关闭时调用（用于子类重写）
function LineupRecommend:OnClose()
    -- 🔴 关闭要 Stop 并清标记：网络回调可能在关闭之后才到，标记留着会让它播在已隐藏的面板上
    needSlideIn = false
    this.StopSlideIn()
end

--界面销毁时调用（用于子类重写）
function LineupRecommend:OnDestroy()
    needSlideIn = false
    this.StopSlideIn()
    lineupList = {}
end

function this.SetPrefabData(go, data, index)
    local iconPanel = Util.GetGameObject(go, "iconPanel")
    local descPanel = Util.GetGameObject(go, "descPanel")
    local title = Util.GetGameObject(iconPanel, "title"):GetComponent("Text")
    local grid = Util.GetGameObject(iconPanel, "grid")
    local hero = Util.GetGameObject(iconPanel, "grid/hero")
    local btnPreview = Util.GetGameObject(iconPanel, "btnPreview")
    local redPoint = Util.GetGameObject(iconPanel, "btnPreview/redpoint")

    title.text = GetLanguageStrById(data.DescFirst)
    local haveNum = 0--拥有英雄数量
    for i, v in ipairs(data.ItemId) do
        if lineupList[index].cards[i] == nil then
            lineupList[index].cards[i] = newObject(hero)
            lineupList[index].cards[i].transform:SetParent(grid.transform)
            lineupList[index].cards[i].transform.localScale = Vector3.one * 0.7
            lineupList[index].cards[i]:SetActive(true)
        end
        local card = lineupList[index].cards[i]
        local config = HeroConfig[v]
        SetHeroBg(Util.GetGameObject(card, "card/card/bg"), Util.GetGameObject(card, "card/card/frame"), config.Quality, config.Star)
        Util.GetGameObject(card, "card/card/lv"):GetComponent("Text").text = 1
        Util.GetGameObject(card, "card/card/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(config.Painting))
        Util.GetGameObject(card, "card/card/pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(config.PropertyName))
        Util.GetGameObject(card, "card/card/sign/core"):SetActive(config.HeroValue == 1)
        Util.GetGameObject(card, "location"):GetComponent("Text").text = GetLanguageStrById(config.HeroLocationDesc1)

        local isHave = PlayerManager.heroHandBook and PlayerManager.heroHandBook[v]--是否拥有英雄
        Util.SetGray(Util.GetGameObject(card, "card/card/bg"), not isHave)
        Util.SetGray(Util.GetGameObject(card, "card/card/icon"), not isHave)
        Util.SetGray(Util.GetGameObject(card, "card/card/pro"), not isHave)
        if isHave then haveNum = haveNum + 1 end

        Util.AddOnceClick(Util.GetGameObject(card, "card/card"), function () --英雄信息
            UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, v, config.Star)
        end)
    end
    --红点
    local num = 0
    for _, v in pairs(receivedList) do
        if data.Id == v.id then
            num = #v.indexArray
        end
    end
    redPoint:SetActive(haveNum > num)

    Util.AddOnceClick(btnPreview, function ()
        descPanel:SetActive(not descPanel.activeSelf)
        if descPanel.activeSelf then
            this.SetReward(data, index, go, haveNum)
        end
    end)
end

function this.SetReward(data, index, go, haveNum)
    local descPanel = Util.GetGameObject(go, "descPanel")
    local describe = Util.GetGameObject(descPanel, "describe/Text"):GetComponent("Text")
    local progress = Util.GetGameObject(descPanel, "progress/Text"):GetComponent("Text")
    local slider = Util.GetGameObject(descPanel, "progress/Slider"):GetComponent("Slider")
    local prefab = Util.GetGameObject(descPanel, "prefab")
    local redPoint = Util.GetGameObject(go, "iconPanel/btnPreview/redpoint")

    for i, v in ipairs(data.CollectReward) do
        local item
        if i == #data.CollectReward then
            item = Util.GetGameObject(descPanel, "reward")
            lineupList[index].rawards[i] = item
        else
            if lineupList[index].rawards[i] == nil then
                lineupList[index].rawards[i] = newObject(prefab)
                lineupList[index].rawards[i].transform:SetParent(descPanel.transform)
                lineupList[index].rawards[i].transform.localScale = Vector3.one
                lineupList[index].rawards[i]:SetActive(true)
            end
            item = lineupList[index].rawards[i]
            slider.value = i / #data.CollectReward
            item.transform.position = Util.GetGameObject(slider.gameObject, "Fill Area/Fill/pos").transform.position
            item.transform.localPosition = Vector3.New(item.transform.localPosition.x, item.transform.localPosition.y + 45,0)
        end
        local config = ItemConfig[v[1]]
        Util.GetGameObject(item, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(config.Quantity))
        Util.GetGameObject(item, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(config.ResourceID))
        Util.GetGameObject(item, "num"):GetComponent("Text").text = v[2]
        Util.GetGameObject(item, "receive"):SetActive(i <= haveNum)

        --已领取
        for _, array in ipairs(receivedList) do
            if data.Id == array.id then
                for _, number in ipairs(array.indexArray) do
                    if number == i then
                        Util.GetGameObject(item, "receive"):SetActive(false)
                        Util.GetGameObject(item, "received"):SetActive(true)
                        Util.SetGray(Util.GetGameObject(item, "frame"), true)
                        Util.SetGray(Util.GetGameObject(item, "icon"), true)
                    end
                end
            end
        end

        Util.AddOnceClick(Util.GetGameObject(item, "frame"), function ()
            NetManager.HeroCollectRewardRequest(data.Id, i, function (msg)
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function()
                    PlayerManager.RefreshreceivedList()
                    NetManager.HeroCollectRewardInfo(function (msg)
                        receivedList = msg.infos
                        this.SetReward(data, index, go, haveNum)

                        --红点
                        local num = 0
                        for _, array in ipairs(receivedList) do
                            if data.Id == array.id then
                                num = #array.indexArray
                            end
                        end
                        redPoint:SetActive(haveNum > num)
                    end)
                end)
            end)
        end)
    end

    describe.text = GetLanguageStrById(data.DescSecond)
    progress.text = haveNum .. "/" .. #data.ItemId
    slider.value = haveNum / #data.ItemId
end

return LineupRecommend