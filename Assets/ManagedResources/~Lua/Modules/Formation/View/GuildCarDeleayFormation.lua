----- 梦魇入侵 -----
local GuildCarDeleayFormation = {}
local this = GuildCarDeleayFormation
--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false
local hadClick = false
--- 逻辑初始化
function this.Init(root, isSaveTeam)
    this.root = root
    this.isSaveTeam = isSaveTeam
    this.InitView()
end
--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_NORMAL
end
--- btn1点击回调事件
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
        else
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
            hadClick = false
            return
        end
        -- 编队为空
        if #FormationManager.formationList[FormationTypeDef.FORMATION_NORMAL].teamHeroInfos == 0 then
            PopupTipPanel.ShowTipByLanguageId(10702)
            hadClick = false
            return
        end
        if this.root.isSaveTeam then
            PopupTipPanel.ShowTipByLanguageId(10700)
            return
        end
        this.StartFight()
    end
end
-- 初始化界面显示
function this.InitView()
    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)

    this.root.btnLeftTxt.text = GetLanguageStrById(10743)
    if this.root.isSaveTeam then
        this.root.btnRightTxt.text = GetLanguageStrById(10726)
    else
        this.root.btnRightTxt.text = GetLanguageStrById(10708)
    end

    MapManager.isCarbonEnter = false
    hadClick = false
end

-- 开始战斗
function this.StartFight()
    if BattleManager.IsInBackBattle() then
        return
    end
    GuildCarDelayManager.FightBattle(function()
        this.root:ClosePanel()
    end)
end
return this