require("Base/BasePanel")
DefenseTrainingBuffPopup = Inherit(BasePanel)
local this = DefenseTrainingBuffPopup
local isFirst = true

--初始化组件（用于子类重写）
function DefenseTrainingBuffPopup:InitComponent()
    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.btnBack = Util.GetGameObject(self.gameObject, "Bg/btnBack")

    this.Scroll = Util.GetGameObject(self.gameObject, "Bg/Formation/Scroll")
    this.tankPre = Util.GetGameObject(self.gameObject, "Bg/item2")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.tankPre, nil,
            Vector2.New(w, h), 2, 1, Vector2.New(0, 10))
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    this.scrollView.elastic = false

    this.skillBuffGos = {}
    for i = 1, 3 do
        this.skillBuffGos[i] = Util.GetGameObject(self.gameObject, "Bg/skill" .. tostring(i))
    end
    this.time = Util.GetGameObject(self.gameObject, "Bg/time"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function DefenseTrainingBuffPopup:BindEvent()
    Util.AddClick(this.mask, function()
        self:ClosePanel()
        Game.GlobalEvent:DispatchEvent(GameEvent.DefenseTrainingPopup.RefreshBtnClick)
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
        Game.GlobalEvent:DispatchEvent(GameEvent.DefenseTrainingPopup.RefreshBtnClick)
    end)
end

--添加事件监听（用于子类重写）
function DefenseTrainingBuffPopup:AddListener()
end

--移除事件监听（用于子类重写）
function DefenseTrainingBuffPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function DefenseTrainingBuffPopup:OnOpen(...)
    local args = {...}
    this.fightId = args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DefenseTrainingBuffPopup:OnShow()
    this:SetTanks()
    this:SetBuffChooseUI()
    this:StartCountdown()
end

function DefenseTrainingBuffPopup:SetTanks()
    local formationData = FormationManager.GetFormationByID(FormationTypeDef.DEFENSE_TRAINING)
    local data = formationData.teamHeroInfos
    this.scrollView:SetData(data, function(index, root)
        self:SetSingleTank(root, data[index])
    end)
end

function DefenseTrainingBuffPopup:SetSingleTank(go, data)
    if not DefenseTrainingManager.heroInfo then
        return
    end
    local info = DefenseTrainingManager.heroInfo[data.heroId]
    local herodata = HeroManager.GetSingleHeroData(data.heroId)
    local go = go
    local frame = Util.GetGameObject(go,"frame"):GetComponent("Image")
    local icon = Util.GetGameObject(go, "icon"):GetComponent("Image")
    local lv = Util.GetGameObject(go, "lv/Text")
    local pro = Util.GetGameObject(go, "proIcon"):GetComponent("Image")
    local starGrid = Util.GetGameObject(go, "star")
    local Slider = Util.GetGameObject(go, "Slider")
    local Text = Util.GetGameObject(go, "Slider/Text")
    Text:SetActive(false)
    local heroConfig = G_HeroConfig[herodata.id]
    frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig.Quality, herodata.star))
    icon.sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
    lv:GetComponent("Text").text = herodata.lv
    pro.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    SetHeroStars(starGrid, herodata.star)
    Slider:GetComponent("Slider").value = info.remainHp

    Util.SetGray(go, info.remainHp <= 0)
end

function DefenseTrainingBuffPopup:SetBuffChooseUI()
    local skillids = {}
    for i = 1, #DefenseTrainingManager.randomBuff do
        table.insert(skillids, G_DefTrainingBuff[DefenseTrainingManager.randomBuff[i]].PassiveSkillId)
    end

    for i = 1, #this.skillBuffGos do
        local root = this.skillBuffGos[i]
        local skillConfig = G_PassiveSkillConfig[skillids[i]]
        Util.GetGameObject(root, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
        Util.GetGameObject(root, "Text"):GetComponent("Text").text = GetLanguageStrById(skillConfig.Name)
        Util.GetGameObject(root, "des"):GetComponent("Text").text = GetSkillConfigDesc(skillConfig, false, 1)

        Util.AddOnceClick(Util.GetGameObject(root, "icon"), function()
            local heroSkill = {}
            heroSkill.skillId = skillConfig.Id
            heroSkill.skillConfig = skillConfig
            UIManager.OpenPanel(UIName.SkillInfoPopup, heroSkill, 1, nil, nil, 2, nil, 2)
        end)

        Util.AddOnceClick(Util.GetGameObject(root, "btn"), function()
            if not isFirst then --避免连点
                return
            end
            if this.timer then
                this.timer:Stop()
                this.timer = nil
            end
            isFirst = false
            DefenseTrainingManager.fightBuffId = DefenseTrainingManager.randomBuff[i]
            DefenseTrainingManager.curBuffId = DefenseTrainingManager.fightBuffId
            DefenseTrainingManager.ExecuteFight(this.fightId, function()
                self:ClosePanel()
            end)
        end)
    end
end

--界面关闭时调用（用于子类重写）
function DefenseTrainingBuffPopup:OnClose()
    isFirst = true
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function DefenseTrainingBuffPopup:OnDestroy()
end

--开始选择BUFF倒计时
function DefenseTrainingBuffPopup:StartCountdown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end

    local time = 10
    this.time.text = time
    this.timer = Timer.New( function()
        time = time - 1
        this.time.text = time

        if time <= 0 then
            if this.timer then
                this.timer:Stop()
                this.timer = nil
            end
            if not isFirst then
                return
            end
            isFirst = false
            local buff = Random.RangeInt(1, #this.skillBuffGos)
            DefenseTrainingManager.fightBuffId = DefenseTrainingManager.randomBuff[buff]
            DefenseTrainingManager.curBuffId = DefenseTrainingManager.fightBuffId
            DefenseTrainingManager.ExecuteFight(this.fightId, function()
                self:ClosePanel()
            end)
        end
    end, 1, -1)
    this.timer:Start()
end

return DefenseTrainingBuffPopup