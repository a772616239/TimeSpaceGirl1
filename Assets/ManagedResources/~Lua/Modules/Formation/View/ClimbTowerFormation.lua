----- 神之塔 -----
local ClimbTowerFormation = {}
local this = ClimbTowerFormation

local hadClick = false
--- 逻辑初始化
function this.Init(root, fightId, type)
    this.root = root
    this.fightId = fightId
    this.type = type or ClimbTowerManager.ClimbTowerType.Normal
    this.InitView()
end

-- 初始化界面显示
function this.InitView()
    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)

    this.root.btnRightTxt.text = GetLanguageStrById(10743)
    if this.root.isSaveTeam then
        this.root.btnRightTxt.text = GetLanguageStrById(10726)
    else
        this.root.btnRightTxt.text = GetLanguageStrById(10708)
    end

    MapManager.isCarbonEnter = false
    hadClick = false

    FormationManager.curFormationIndex = FormationTypeDef.FORMATION_NORMAL
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_NORMAL
end

function this.On_BtnLeft_Click()
    this.root.SetOneKeyGo()
end

function this.On_BtnRight_Click()
    if not hadClick then
        hadClick = true
        if this.root.order >= 1 then
            --保存编队
            FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
            {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
            adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
            nil,
            this.root.choosedFormationId)
            if this.root.isSaveTeam then
                hadClick = false
                PopupTipPanel.ShowTipByLanguageId(10700)
                return
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10702)
            hadClick = false
            return
        end

        this.StartFight()
    end
end

-- 开始战斗
function this.StartFight()
    if this.type == ClimbTowerManager.ClimbTowerType.Normal then
        ClimbTowerManager.ExecuteFight(this.fightId, function()
            this.root:ClosePanel()
        end)
    elseif this.type == ClimbTowerManager.ClimbTowerType.Advance then
        ClimbTowerManager.ExecuteFightAdvance(this.fightId, function()
            this.root:ClosePanel()
        end)
    end
end

return this