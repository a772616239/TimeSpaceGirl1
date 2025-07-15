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
    this.rootText = Util.GetGameObject(this.root,"font/num"):GetComponent("Text")
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

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local args = {...}
    func = args[2]
    this.titleText.text = GetLanguageStrById(11351)
    local go = Util.GetGameObject(this.btn,"Go")
    local var = PlayerManager.uid.."GeneralPopup_RecruitConfirm"

    local config = LotterySetting[args[1]]
    if args[1] == RecruitType.Single then
        var = var..RecruitType.Ten
        local d = RecruitManager.GetExpendData(RecruitType.Single)
        this.rootText.text = string.format(GetLanguageStrById(12373),d[2])
    elseif args[1] == RecruitType.Ten then
        local count = BagManager.GetItemCountById(config.CostItem[1][1])
        if count > 0 then
            this.btn:SetActive(false)
            local singleCost = config.CostItem[2][2]/config.PerCount
            local deficiencyCount = config.PerCount-count
            this.rootText.text = string.format(GetLanguageStrById(50259),singleCost*deficiencyCount,config.PerCount,GetLanguageStrById(ItemConfig[config.CostItem[1][1]].Name))
        else
            var = var..RecruitType.Ten
            local d = RecruitManager.GetExpendData(RecruitType.Ten)
            this.rootText.text = string.format(GetLanguageStrById(12376),d[2])
        end
    elseif args[1] == RecruitType.ProveUpOne then
        var = var..RecruitType.ProveUpOne
        local d = RecruitManager.GetExpendData(RecruitType.ProveUpOne)
        this.rootText.text = string.format(GetLanguageStrById(50257),d[2])
    elseif args[1] == RecruitType.ProveUpTen then
        var = var..RecruitType.ProveUpTen
        local count = BagManager.GetItemCountById(config.CostItem[1][1])
        if count > 0 then
            this.btn:SetActive(false)
            local singleCost = config.CostItem[2][2]/config.PerCount
            local deficiencyCount = config.PerCount-count
            this.rootText.text = string.format(GetLanguageStrById(50259),singleCost*deficiencyCount,config.PerCount,GetLanguageStrById(ItemConfig[config.CostItem[1][1]].Name))
        else
            local d = RecruitManager.GetExpendData(RecruitType.ProveUpTen)
            this.rootText.text = string.format(GetLanguageStrById(50258),d[2])
        end
    elseif config.LotteryType == 3 then
        var = var..args[1]
        -- local type = ActivityGiftManager.GetActivityTypeFromId(config.ActivityId)
        if config.PerCount == 10 then
            local count = BagManager.GetItemCountById(config.CostItem[1][1])
            if count > 0 then
                this.btn:SetActive(false)
                local singleCost = config.CostItem[2][2]/config.PerCount
                local deficiencyCount = config.PerCount-count
                this.rootText.text = string.format(GetLanguageStrById(50259),singleCost*deficiencyCount, config.PerCount, GetLanguageStrById(ItemConfig[config.CostItem[1][1]].Name))
            else
                local d = RecruitManager.GetExpendData(args[1])
                this.rootText.text = string.format(GetLanguageStrById(12378), d[2])
            end
        else
            local d = RecruitManager.GetExpendData(args[1])
            this.rootText.text = string.format(GetLanguageStrById(12378), d[2])
        end
    end

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