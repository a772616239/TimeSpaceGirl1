local GuildFightDefendFormation = {}
local this = GuildFightDefendFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false

function this.Init(root, type, buildType)
    this.root = root
    this._ViewType = type
    this._CurBuildType = buildType
    this.InitView()
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND
end
--- 界面关闭时回调
function this.OnCloseBtnClick()
    -- 重置我的战斗力
    GuildFightManager.ResetDefendStageDataForce(PlayerManager.uid, this.root.formationPower)
    this.root:ClosePanel()
end
--- 提交按钮点击事件
function this.On_BtnLeft_Click()
    local formation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND)
    if #formation.teamHeroInfos == 0 then
        PopupTipPanel.ShowTipByLanguageId(10738)
        return
    end
    
    if this._ViewType == "EDIT" then
        -- 重置我的战斗力
        GuildFightManager.ResetDefendStageDataForce(PlayerManager.uid, this.root.formationPower)
        this.root:ClosePanel()
    elseif this._ViewType == "DEFEND" then
        GuildFightManager.RequestDefend(this._CurBuildType, function()
            this.root:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10739)
        end)
    end
end

-- 界面显示刷新
function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(true)
    if this._ViewType == "EDIT" then
        this.root.btnLeftTxt.text = GetLanguageStrById(10729)
    elseif this._ViewType == "DEFEND" then
        this.root.btnLeftTxt.text = GetLanguageStrById(10740)
    end

    this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
end




return this