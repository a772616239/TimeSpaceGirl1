----- 招募二次确认弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local func

local LotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.root = Util.GetGameObject(gameObject, "Root")
    this.confirm = Util.GetGameObject(gameObject, "ConfirmBtn")
    this.cancel = Util.GetGameObject(gameObject, "CancelBtn")
    this.btn = Util.GetGameObject(this.root,"Btn1")
    this.rootText = Util.GetGameObject(this.root,"Text"):GetComponent("Text")
end

function this:BindEvent()
    Util.AddClick(this.confirm,function()
        parent:ClosePanel()
        if func then
            func()
        end
    end)
    Util.AddClick(this.cancel,function()
        parent:ClosePanel()
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

--不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder = _parent.sortingOrder

    local args = {...}
    func = args[2]
    this.titleText.text = GetLanguageStrById(11351)
    local var = PlayerManager.uid.."GeneralPopup_RecruitConfirm"
    local str
    local config = LotterySetting[args[1]]
    if config and config.LotteryType == 3 then--活动
        var = var .. args[1]
        local type = ActivityGiftManager.GetActivityTypeFromId(config.ActivityId)
        local d, v1 = RecruitManager.GetExpendData(args[1])
        if type == ActivityTypeDef.FindFairy then
            if config.PerCount == 1 then
                str = string.format(GetLanguageStrById(12375), d[2])
            elseif config.PerCount == 10 then
                -- str = string.format(GetLanguageStrById(12378), d[2])
                local count = BagManager.GetItemCountById(config.CostItem[1][1])
                if count > 0 then
                    this.btn:SetActive(false)
                    var = ""
                    local singleCost = config.CostItem[2][2]/config.PerCount
                    local deficiencyCount = config.PerCount-count
                    str = string.format(GetLanguageStrById(50355),singleCost*deficiencyCount, config.PerCount, GetLanguageStrById(ItemConfig[config.CostItem[1][1]].Name))
                else
                    var = var..RecruitType.TimeLimitTen
                    local d = RecruitManager.GetExpendData(RecruitType.TimeLimitTen)
                    str = string.format(GetLanguageStrById(12378), d[2])
                end
            end
        elseif type == ActivityTypeDef.QianKunBox then
            if config.PerCount == 1 then
                str = string.format(GetLanguageStrById(12374), d[2])
            elseif config.PerCount == 10 then
                str = string.format(GetLanguageStrById(12377), d[2])
            end
        end
    else
        if args[1] == RecruitType.Single then
            var = var..RecruitType.Ten
            local d = RecruitManager.GetExpendData(RecruitType.Single)
            str = string.format(GetLanguageStrById(12373),d[2])
        elseif args[1] == RecruitType.QianKunBoxSingle then
            var = var..RecruitType.QianKunBoxTen
            local d = RecruitManager.GetExpendData(RecruitType.QianKunBoxSingle)
            str = string.format(GetLanguageStrById(12374),d[2])
        elseif args[1] == RecruitType.TimeLimitSingle then
            var = var..RecruitType.TimeLimitTen
            local d = RecruitManager.GetExpendData(RecruitType.TimeLimitSingle)
            str = string.format(GetLanguageStrById(12375),d[2])
        elseif args[1] == RecruitType.Ten then
            local count = BagManager.GetItemCountById(config.CostItem[1][1])
            if count > 0 then
                this.btn:SetActive(false)
                var = ""
                local singleCost = config.CostItem[2][2]/config.PerCount
                local deficiencyCount = config.PerCount-count
                str = string.format(GetLanguageStrById(50355),singleCost*deficiencyCount, config.PerCount, GetLanguageStrById(ItemConfig[config.CostItem[1][1]].Name))
            else
                var = var..RecruitType.Ten
                local d = RecruitManager.GetExpendData(RecruitType.Ten)
                str = string.format(GetLanguageStrById(12376),d[2])
            end
        elseif args[1] == RecruitType.QianKunBoxTen then
            var = var..RecruitType.QianKunBoxTen
            local d = RecruitManager.GetExpendData(RecruitType.QianKunBoxTen)
            str = string.format(GetLanguageStrById(12377),d[2])
        elseif args[1] == RecruitType.TimeLimitTen then
            var = var..RecruitType.TimeLimitTen
            local d = RecruitManager.GetExpendData(RecruitType.TimeLimitTen)
            str = string.format(GetLanguageStrById(12378),d[2])
        elseif args[1] == RecruitType.ProveUpOne then
            var = var..RecruitType.ProveUpOne
            local d = RecruitManager.GetExpendData(RecruitType.ProveUpOne)
            str = string.format(GetLanguageStrById(23103),d[2])
        elseif args[1] == RecruitType.ProveUpTen then
            local count = BagManager.GetItemCountById(config.CostItem[1][1])
            if count > 0 then
                this.btn:SetActive(false)
                local singleCost = config.CostItem[2][2]/config.PerCount
                local deficiencyCount = config.PerCount-count
                str = string.format(GetLanguageStrById(50325),singleCost*deficiencyCount, config.PerCount, GetLanguageStrById(ItemConfig[config.CostItem[1][1]].Name))
            else
                var = var..RecruitType.ProveUpTen
                local d = RecruitManager.GetExpendData(RecruitType.ProveUpTen)
                str = string.format(GetLanguageStrById(50326),d[2])
            end
        elseif args[1] == 2031 then
            var = var..RecruitType.TimeLimitTen
            local d = RecruitManager.GetExpendData(RecruitType.TimeLimitTen)
            str = string.format(GetLanguageStrById(12378),d[2])
        elseif args[1] == 2041 then
            var = var..RecruitType.TimeLimitTen
            local d = RecruitManager.GetExpendData(RecruitType.TimeLimitTen)
            str = string.format(GetLanguageStrById(12378),d[2])
        end
    end

    this.rootText.text = str

    local go = Util.GetGameObject(this.btn, "Go")
    Util.AddOnceClick(this.btn,function()
        this.btnClick = (this.btnClick and this.btnClick == 1) and 0 or 1
        PlayerPrefs.SetInt(var,this.btnClick)
        go:SetActive(PlayerPrefs.GetInt(var) == 1)
    end)

    if PlayerPrefs.HasKey(var) then
        go:SetActive(PlayerPrefs.GetInt(var) == 1)
    else
        go:SetActive(false)
    end
end

function this:OnClose()
end

function this:OnDestroy()
    this.btn = {}
end

return this