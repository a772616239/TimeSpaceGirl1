----- 竞技场防守 -----
local ArenaDefendFormation = {}
local this = ArenaDefendFormation

-- -- 是否需要切换编队的功能
-- this.IsNeedChangeFormation = false

--- 初始化
function this.Init(root)
    this.root = root
    this.InitView()
end

function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10743)
    this.root.btnRightTxt.text = GetLanguageStrById(10726)
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_ARENA_DEFEND
end

function this.On_BtnLeft_Click()
    this.root.SetOneKeyGo()
end

--- 提交按钮点击事件
function this.On_BtnRight_Click(Index, Isjump)
    local formation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_ARENA_DEFEND)
    if #formation.teamHeroInfos == 0 then
        PopupTipPanel.ShowTipByLanguageId(10711)
        return
    end
    if this.root.order >= 1 then
        --保存编队
        FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
        {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
        adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
        nil,
        this.root.choosedFormationId)
    else
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
        return
    end

    if this.root.isSaveTeam then
        PopupTipPanel.ShowTipByLanguageId(10700)
        return
    end

    this.root:ClosePanel()
    -- 如果未打开则打开
    if not UIManager.IsOpen(UIName.ArenaMainPanel) and Isjump then
        UIManager.OpenPanel(UIName.ArenaMainPanel)
    end
end

return this