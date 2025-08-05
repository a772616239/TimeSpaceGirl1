require("Base/BasePanel")
local ThousandDrawPanel = Inherit(BasePanel)
local this = ThousandDrawPanel
local ThousandDrawConfig = ConfigManager.GetAllConfigsData(ConfigName.ThousandDrawConfig)
local round --轮次
local thousandDrawCards = {} --卡组

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
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
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
            end)
        end)
    end
end

return this