----- 混乱之治进攻阵容 -----
local ChaosFormationACKPanel = {}
local this = ChaosFormationACKPanel
local hadClick = false

--- 逻辑初始化
function this.Init(root, fightId)
    this.root = root
    this.fightId= fightId
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
        -- -- 编队为空
        -- if #FormationManager.formationList[FormationManager.curFormationIndex].teamHeroInfos == 0 then
        --     hadClick = false
        --     PopupTipPanel.ShowTipByLanguageId(10702)
        --     return
        -- end

        if this.root.order >= 1 then
            --保存编队
            FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList, this.root.tibu,
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
        ChaosManager:ExecuteFight(0,function()
            this.root:ClosePanel()
        end)
        -- -- 战斗力判断
        -- if this.root.formationPower >= mainLevelConfig[FightPointPassManager.curOpenFight].RecommendFightAbility then
        --     if not this.root.storyjump then
        --         -- this.root:ClosePanel()
        --         return
        --     end
        --     this.StartFight()
        -- else
        --     MsgPanel.ShowTwo(GetLanguageStrById(10744), function()
        --         hadClick = false
        --     end, function()
        --         this.StartFight()
        --     end, GetLanguageStrById(10719), GetLanguageStrById(10720)
        --     )
        -- end
    end

    
    -- if this.root.order >= 1 then
    --     --保存编队
    --     FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
    --     FormationManager.formationList[this.root.curFormationIndex].teamPokemonInfos)
    -- else
    --     PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
    --     return
    -- end
    -- 请求开始挑战
--    local data = ChaosManager:GetChallegeData()
--     ChaosManager:SetItemsData(data.)
  
end


return this



