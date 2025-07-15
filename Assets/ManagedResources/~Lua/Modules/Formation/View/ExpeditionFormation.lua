----- 猎妖之路 -----
local ExpeditionFormation = {}
local this = ExpeditionFormation
--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false
local hadClick = false
--local GetCurNodeInfo
this.nodeData = {}
--- 逻辑初始化
function this.Init(root, _nodeData)
    this.root = root
    this.nodeData = _nodeData
    this.InitView()
end
--- 获取需要显示的编队id
function this.GetFormationIndex()
    --FormationManager.curFormationIndex = FormationTypeDef.FORMATION_NORMAL
    return FormationTypeDef.EXPEDITION
end
--- btn1点击回调事件
function this.On_BtnLeft_Click()
    if not hadClick then
        hadClick = true
        if this.root.order >= 1 then
            --保存编队
            FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
                FormationManager.formationList[this.root.curFormationIndex].teamPokemonInfos)
        else
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
            hadClick = false
            return
        end
        -- 编队为空
        if #FormationManager.formationList[FormationTypeDef.EXPEDITION].teamHeroInfos == 0 then
            PopupTipPanel.ShowTipByLanguageId(10702)
            hadClick = false
            return
        end

        -- 战斗力判断
        -- GetCurNodeInfo = ExpeditionManager.GetCurNodeInfo()
        --if this.root.formationPower >= this.nodeData.bossTeaminfo.totalForce then
            this.StartFight()
        --else
        --    MsgPanel.ShowTwo("当前队伍战力小于推荐战力，战斗可能会有失败风险。确定是否要继续战斗？", function()
        --        hadClick = false
        --    end, function()
        --        this.StartFight()
        --    end, "取消", "确定"
        --    )
        --end
    end
end

-- 初始化界面显示
function this.InitView()
    this.root.btnLeft:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10708)
    MapManager.isCarbonEnter = false
    -- this.root.formTip:SetActive(true)
    -- this.root.formTip:GetComponent("Text").text = GetLanguageStrById(10727) ..20 .. GetLanguageStrById(10728)
    -- local costTip = this.root.costTip
    -- costTip:SetActive(false)
    hadClick = false

    this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    --FormationManager.curFormationIndex = FormationTypeDef.EXPEDITION
end

-- 开始战斗
function this.StartFight()
    ExpeditionManager.ExecuteFightBattle(this.nodeData.sortId,FormationTypeDef.EXPEDITION,{}, function()
        this.root:ClosePanel()
    end)
end

return this