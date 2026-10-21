require("Base/BasePanel")
local ThousandDrawPanel = Inherit(BasePanel)
local this = ThousandDrawPanel
local ItemPopIn = require("Modules/Common/ItemPopIn")--卡片/数字格的入场（phases 多段关键帧）
local ThousandDrawConfig = ConfigManager.GetAllConfigsData(ConfigName.ThousandDrawConfig)
local round --轮次
local thousandDrawCards = {} --卡组

--==================== 卡片 / 数字格入场（浮起—按回—落定） ====================
-- 千抽不是长列表，是「三张卡 + 四位数字」的固定版面 ⇒ 用 ItemPopIn 的 phases 模式：
-- 不再用 OutElastic 单段回弹（0.55s 内抖完，观感是「闪一下」），改成三段关键帧：
--   卡片  0.78 → 1.05（0.38s，OutCubic 减速浮起）
--              → 0.985（0.24s，InOutQuad 被按回）
--              → 1.0  （0.18s，OutQuad  落定）  合计 ≈ 0.8s，一张一张起（0.11 错开）
--   数字  0.82 → 1.04 → 0.99 → 1（0.24/0.14/0.10），排在卡片之后 0.34 再起，0.06 错开
-- 三段「先长后短」的节奏是刻意的：浮起要看清、按回要能察觉、落定要干脆；
-- 想再慢/再快只动 phases 里的 duration，不用改这段之外的代码。
-- 配方/坑见 docs/ui_item_pop_in_skill.md。
-- 🔴 卡片根节点（card1..3）没有 Animator，Animator 在每个卡的子节点 btn 上 ⇒ 动根节点缩放
--    不会被盖回去；但动 btn 自己会被盖（和页签翻入同一条坑）。
local kCardNames = { "card1", "card2", "card3" }
local kNumberNames = { "thousand", "hundred", "ten", "unit" }
-- 峰值 1.05 是版面允许的上限：卡 280 宽、相邻卡 -18 重叠，1.05 只把重叠多吃 6px，
-- 再大就会顶到邻居的边框上（礼包墙那边 1.04 就直接出屏了，别照抄那里的系数）。
local kCardPhases = {
    { scale = 1.05, duration = 0.38, ease = "OutCubic" },
    { scale = 0.985, duration = 0.24, ease = "InOutQuad" },
    { scale = 1, duration = 0.18, ease = "OutQuad" },
}
local kNumberPhases = {
    { scale = 1.04, duration = 0.24, ease = "OutCubic" },
    { scale = 0.99, duration = 0.14, ease = "InOutQuad" },
    { scale = 1, duration = 0.10, ease = "OutQuad" },
}
local kCardInCfg = {
    mode = "phases",
    from = 0.78,
    phases = kCardPhases,
    step = 0.11,
    maxSpan = 0.44,
}
local kNumberInCfg = {
    mode = "phases",
    from = 0.82,
    phases = kNumberPhases,
    delay = 0.34,      --等三张卡浮起来再弹，别和卡片糊在一起
    step = 0.06,
    maxSpan = 0.36,
}

function this:InitComponent()
    this.mask = Util.GetGameObject(self.gameObject, "mask")
	this.btnHelp = Util.GetGameObject(self.gameObject, "bg/btnHelp")
    this.btnHelpPos = this.btnHelp:GetComponent("RectTransform").localPosition
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    local number = Util.GetGameObject(self.gameObject, "bg/number")
    this.numberTitle = Util.GetGameObject(number, "title"):GetComponent("Text")
    this.numberGrid = Util.GetGameObject(number, "grid")
    this.limitTxt = Util.GetGameObject(self.gameObject, "bg/limit"):GetComponent("Text")
    this.cardGrid = Util.GetGameObject(self.gameObject, "bg/grid")

    --数据源是显式数组（ItemPopIn 认 Lua 数组：元素是 GameObject 或 transform）
    this.cardIn = ItemPopIn.New(function() return this:GetCardItems() end, kCardInCfg)
    this.numberIn = ItemPopIn.New(function() return this:GetNumberItems() end, kNumberInCfg)
end

--三张卡（版面顺序 card1 → card3）
function this:GetCardItems()
    local list = {}
    for i = 1, #kCardNames do
        local go = this.cardGrid and Util.GetGameObject(this.cardGrid, kCardNames[i]) or nil
        if go then
            list[#list + 1] = go
        end
    end
    return list
end

--剩余抽数（千/百/十/个），和版面顺序一致
function this:GetNumberItems()
    local list = {}
    for i = 1, #kNumberNames do
        local go = this.numberGrid and Util.GetGameObject(this.numberGrid, kNumberNames[i]) or nil
        if go then
            list[#list + 1] = go
        end
    end
    return list
end

--整版入场：卡先、数字后（数字靠 cfg.delay 错开）
function this:PlayCardsIn()
    if this.cardIn then
        this.cardIn:Play()
    end
    if this.numberIn then
        this.numberIn:Play()
    end
end

--只弹一张卡：下标就是 cardN 的 N（数组顺序即 card1..3）
function this:PlayCardIn(number)
    if this.cardIn then
        this.cardIn:Play(number)
    end
end

--回收：Kill + 复位。🔴 漏调 = 卡片/数字永久停在 0.78 上
function this:StopCardsIn()
    if this.cardIn then
        this.cardIn:Stop()
    end
    if this.numberIn then
        this.numberIn:Stop()
    end
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function ()
        self:ClosePanel()
    end)	
    Util.AddClick(this.btnHelp, function ()
        -- UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE., this.btnHelpPos.x, this.btnHelpPos.y)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

function this:OnOpen()
    this.Init()
    -- NetManager.ThousandDrawInfo(function (msg)
    --     this.Init(msg)

    --     for i = 1, #thousandDrawCards do
    --         local card = Util.GetGameObject(this.cardGrid, "card" .. thousandDrawCards[i].number)
    --         this.SetCard(card, thousandDrawCards[i])

    --         RecruitManager.ThousandDrawCards(1, thousandDrawCards[i])
    --     end

    --     this.SetInfo()
    -- end)
end

--界面打开时调用（用于子类重写）
function this:OnShow()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    --入场播到一半被关掉也要复位
    this:StopCardsIn()
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    this:StopCardsIn()
end

--初始化
function this.Init(msg)
    -- thousandDrawCards = {}
    -- round = msg.round
    -- this.limit = ConfigManager.GetConfigDataByKey(ConfigName.ThousandDrawConfig, "Round", round).LvRequire
    -- thousandDrawCards = msg.thousandDrawCards
    -- for i = 1, 3 do
    --     local card = Util.GetGameObject(this.cardGrid, "card" .. i)
    --     Util.GetGameObject(card, "btn/redpoint"):SetActive(false)
    --     this.SetCard(card, i)
    -- end
    -- RecruitManager.ThousandDrawCards(3)

    RecruitManager.InitThousandDraw(function ()
        round = RecruitManager.thousandDrawRound
        this.limit = RecruitManager.limitLevel
        thousandDrawCards = {}
        thousandDrawCards = RecruitManager.thousandDrawCards
        
        for i = 1, 3 do
            local card = Util.GetGameObject(this.cardGrid, "card" .. i)
            Util.GetGameObject(card, "btn/redpoint"):SetActive(false)
            this.SetCard(card, i)
        end

        for i = 1, #thousandDrawCards do
            local card = Util.GetGameObject(this.cardGrid, "card" .. thousandDrawCards[i].number)
            this.SetCard(card, thousandDrawCards[i])

            RecruitManager.ThousandDrawCards(1, thousandDrawCards[i])
        end

        this.SetInfo()
        --数据到位再入场：卡片是空的（只有「试炼」按钮）时弹，看不到卡面
        this:PlayCardsIn()
    end)
end

--设置基础信息
function this.SetInfo()
    this.numberTitle.text = string.format(GetLanguageStrById(50170), round)
    this.limitTxt.text = string.format(GetLanguageStrById(50171), this.limit)

    local curMaxDrawNum = (round - 1) * 30 + #thousandDrawCards * 10 --当前已抽
    local surplus = #ThousandDrawConfig * 30 - curMaxDrawNum --剩余抽
    Util.GetGameObject(this.numberGrid, "thousand"):GetComponent("Text").text = math.floor(surplus / 1000)
    Util.GetGameObject(this.numberGrid, "hundred"):GetComponent("Text").text = math.floor(surplus % 1000 / 100)
    Util.GetGameObject(this.numberGrid, "ten"):GetComponent("Text").text = math.floor(surplus % 1000 % 100 / 10)
    Util.GetGameObject(this.numberGrid, "unit"):GetComponent("Text").text = math.floor(surplus % 1000 % 100 % 10)
end

local btnSprite = {
    GetPictureFont("cn2-X1_qianchou_shilian"),
    GetPictureFont("cn2-X1_qianchou_dailingqu"),
    GetPictureFont("cn2-X1_qianchou_kelingqu")
}
--设置卡片
function this.SetCard(go, data)
    local btn = Util.GetGameObject(go, "btn"):GetComponent("Image")
    Util.GetGameObject(go, "card"):SetActive(type(data) == "table")
    if type(data) == "table" then
        local number = data.number
        local cards = data.cards
        local config = ConfigManager.GetConfigData(ConfigName.HeroConfig, cards[1])
        SetHeroBg(Util.GetGameObject(go, "card/bg"), Util.GetGameObject(go.transform, "card/frame"), config.Quality, config.Star)
        Util.GetGameObject(go, "card/lv"):GetComponent("Text").text = 1
        Util.GetGameObject(go, "card/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(config.Painting))
        Util.GetGameObject(go, "card/pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(config.PropertyName))
        Util.GetGameObject(go, "card/bg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityBgImageByquality(config.Quality, config.Star))
        SetHeroStars(Util.GetGameObject(go, "card/star"), config.Star)
        Util.GetGameObject(go, "card/sign/core"):SetActive(config.HeroValue == 1)

        if #thousandDrawCards == 3 and PlayerManager.level >= this.limit then --可领取
            btn.sprite = Util.LoadSprite(btnSprite[3])
        else
            btn.sprite = Util.LoadSprite(btnSprite[2])
        end

        Util.AddOnceClick(Util.GetGameObject(go, "btnInfo"), function () --英雄信息
            UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, cards[1], config.Star)
        end)
        Util.AddOnceClick(Util.GetGameObject(go, "card/card"), function () --当前抽取的所有英雄
            local randCards = RecruitManager.ThousandDrawCards(2, nil, number)
            UIManager.OpenPanel(UIName.TenRecruitPanel, randCards, nil, nil, true)
        end)
        Util.AddOnceClick(btn.gameObject, function () --领取
            if #thousandDrawCards < 3 then
                PopupTipPanel.ShowTip(GetLanguageStrById(50172))
                return
            end
            NetManager.ThousandDrawRequest(false, number, function (msg)
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function()
                    NetManager.ThousandDrawInfo(function (msg)
                        if msg.round == 0 then
                            MainPanel.RefreshActivityShow()
                            ThousandDrawPanel:ClosePanel()
                            return
                        end
                        this.Init()
                    end)
                end)
            end)
        end)
    else
        Util.GetGameObject(go, "card/sign/core"):SetActive(false)
        btn.sprite = Util.LoadSprite(btnSprite[1])
        Util.AddOnceClick(Util.GetGameObject(go, "btnInfo"), function () end)
        Util.AddOnceClick(Util.GetGameObject(go, "card/card"), function () end)
        Util.AddOnceClick(btn.gameObject, function ()
            NetManager.ThousandDrawRequest(true, data, function (msg)
                RecruitManager.SaveThousandDrawCards({number = msg.number, cards = msg.cards})
                -- table.insert(thousandDrawCards, {number = msg.number, cards = msg.cards})
                thousandDrawCards = RecruitManager.thousandDrawCards
                --随机排列英雄
                RecruitManager.ThousandDrawCards(1, {number = msg.number, cards = msg.cards})
                local randCards = RecruitManager.ThousandDrawCards(2, nil, msg.number)
                --抽卡展示
                UIManager.OpenPanel(UIName.TenRecruitPanel, randCards)

                if #thousandDrawCards == 3 and PlayerManager.level >= this.limit then
                    for i = 1, 3 do
                        Util.GetGameObject(this.cardGrid, "card" .. i .. "/btn"):GetComponent("Image").sprite = Util.LoadSprite(btnSprite[3])
                        Util.GetGameObject(this.cardGrid, "card" .. i .. "/btn/redpoint"):SetActive(true)
                    end
                end
                this.SetInfo()
                this.SetCard(Util.GetGameObject(this.cardGrid, "card" .. msg.number), msg)
                --抽中的那张自己浮一下（其余两张不动，别整墙重弹）
                this:PlayCardIn(msg.number)
            end)
        end)
    end
end

return this