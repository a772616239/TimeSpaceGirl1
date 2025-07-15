----- 腐化之战 -----
local XuanYuanMirrorFormation = {}
local this = XuanYuanMirrorFormation
local curType = 0
local data = nil
local index = 0
-- root-- FormationPanelV2
local isInBattle = false

--- 逻辑初始化
function this.Init(root, ...)
    local temp = {...}
    curType = 0   
    if temp[1] and temp[1] ~= 0 then
        curType = temp[1]
    end
    if temp[2] then
        data = temp[2]
    end
    this.root = root
    this.InitView()
end

-- 初始化界面显示
function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)

    this.root.btnLeftTxt.text = GetLanguageStrById(10743)
    if this.root.isSaveTeam then
        this.root.btnRightTxt.text = GetLanguageStrById(10726)
    else
        this.root.btnRightTxt.text = GetLanguageStrById(10709)
    end
    isInBattle = false
    -- this.root.tip:SetActive(true)
    -- this.root.exampleBtn:SetActive(false)
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_NORMAL--所有阵营使用同一编队
end

function this.On_BtnLeft_Click()
    this.root.SetOneKeyGo()
end

-- 进入地图
function this.On_BtnRight_Click()
    if this.root.isSaveTeam then
        FormationManager.RefreshFormation(FormationTypeDef.FORMATION_NORMAL, this.root.choosedList, this.root.tibu,
            { supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
            adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
            nil,
            this.root.choosedFormationId)

        PopupTipPanel.ShowTipByLanguageId(10700)
        return
    end
    if index >= data.teamRules[1][2] then
        FormationManager.RefreshFormation(FormationTypeDef.FORMATION_NORMAL, this.root.choosedList, this.root.tibu,
            {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
            adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
            nil,
            this.root.choosedFormationId)

        this.StartFight()
    else
        PopupTipPanel.ShowTip(data.condition)
    end
end

--刷新编队
function this.RefreshFormation(curFormation)
    --上阵列表赋值
    index = 0
    for i = 1, #curFormation do
        local teamInfo = curFormation[i]
        -- 加空判断避免不知名错误
        if teamInfo and HeroManager.GetSingleHeroData(teamInfo.heroId) then
            local heroData = HeroManager.GetSingleHeroData(teamInfo.heroId)
            if heroData.property == data.teamRules[1][1] then
                index = index + 1
            end
        end
    end
    -- if index >= tonumber(data.teamRules[1][2]) then
    --     this.root.tip:GetComponent("Text").text = string.format("<color=#715F17>%s</color>", data.condition)
    -- else
    --     this.root.tip:GetComponent("Text").text = string.format("<color=#CB493D>%s</color>", data.condition)
    -- end
end

-- 开始战斗
function this.StartFight()
    if BattleManager.IsInBackBattle() or isInBattle then
        PopupTipPanel.ShowTip(GetLanguageStrById(50014))
        return
    end
    isInBattle = true
    XuanYuanMirrorManager.ExecuteFightBattle(data.id,1,function() this.OnCloseBtnClick() end)
end

--- 关闭界面事件
function this.OnCloseBtnClick()
    this.root:ClosePanel()
end

return this