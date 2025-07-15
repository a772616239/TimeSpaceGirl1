local SaveFormation = {}
local this = SaveFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = true

--- 逻辑初始化
function this.Init(root, fightId)
    this.root = root
    this.teamId = fightId

    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10743)
    this.root.btnRightTxt.text = GetLanguageStrById(10726)
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return this.teamId and this.teamId or FormationManager.curFormationIndex
end

--- 关闭界面事件
function this.OnCloseBtnClick()
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    this.root:ClosePanel()
end

function this.On_BtnLeft_Click()
    this.root.SetOneKeyGo()
end

function this.On_BtnRight_Click()
    if this.root.order >= 1 then
        --保存编队
        FormationManager.RefreshFormation(
            this.root.curFormationIndex,
            this.root.choosedList,
            this.root.tibu,
        {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
            adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
        nil,
            this.root.choosedFormationId)
        Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnFormationChange)--主线保存编队显示战力变化
        PopupTipPanel.ShowTipByLanguageId(10713)
        if not this.root.isSaveTeam then
            this.root:ClosePanel()
        end
        if this.teamId and this.teamId == FormationTypeDef.EXPEDITION then
        else
            Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnFormationChange)--主线保存编队显示战力变化
        end
    else
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
    end
end

return this