----- 副本 -----
local CarbonFormation = {}
local this = CarbonFormation
local trialMapData = ConfigManager.GetConfig(ConfigName.TrialConfig)
local gameConfig = ConfigManager.GetConfig((ConfigName.GameSetting))

local _PanelType = {
    [1] = PanelType.Main,
    [2] = PanelType.Main,
    [3] = PanelType.EliteCarbon
}
--- 是否需要切换编队的功能
this.IsNeedChangeFormation = true

--- 逻辑初始化
function this.Init(root, curMapId)
    this.root = root
    this.curMapId = curMapId
    this.InitView()
end
local index = 0
--- 获取需要显示的编队id
function this.GetFormationIndex()
    if  CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        index = FormationTypeDef.FORMATION_ENDLESS_MAP
    else
        FormationManager.curFormationIndex = FormationTypeDef.FORMATION_NORMAL
        index = FormationTypeDef.FORMATION_NORMAL
    end

    return index
end
-- 扫荡按钮
--- btn1点击回调事件
function this.On_BtnLeft_Click()
    -- this.root.SetOneKeyGo()
    -- this.root.SetOneKeyCarBonGo()
    --以前的换成的一键上阵

    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        -- if this.root.order>=1 then
        --     --保存编队
        --     FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,
        --     FormationManager.formationList[this.root.curFormationIndex].teamPokemonInfos)
        --     PopupTipPanel.ShowTip("保存编队成功！")
        -- else
        --     PopupTipPanel.ShowTip("未上阵神将，无法保存阵容！")
        -- end
        -- return
        this.root.SetOneKeyGo()
    end
    -- 刷新扫荡数据--应该是没了
    -- this.root.ShowStartMopUpInfoData() 
    -- -- 显示扫荡界面
    -- this.root.mopUpGo:SetActive(true)
    -- PlayUIAnim( this.root.mopUpGo)
end

--- btn2点击回调事
-- local itemType = {
--    [1] = 27,
--    [3] = 28,
-- }

--编队了i去掉死亡的英雄
function this.RrefreshFormation()
    -- if CarbonManager.difficulty ~= CARBON_TYPE.ENDLESS then return end
    -- local tempList = {}
    -- local curTeam = EndLessMapManager.formation

    -- for i = 1, #curTeam do
    --     local roleData = curTeam[i]
    --     -- 如果队员没死翘翘了
    --     local curRoleHp = EndLessMapManager.GetHeroLeftBlood(roleData.heroId)
    --     if curRoleHp > 0 then
    --         -- 编队界面数据重组
    --         table.insert(tempList, roleData)
    --     end
    -- end
    -- FormationManager.formationList[FormationTypeDef.FORMATION_ENDLESS_MAP].teamHeroInfos = tempList
end

-- 进入地图
function this.On_BtnRight_Click()
    --保存编队
    if this.root.order >= 1 then
        --保存编队
        FormationManager.RefreshFormation(
            this.root.curFormationIndex,
            this.root.choosedList,
            this.root.tibu,
            {
                supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
                adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)
                },
            nil,
            this.root.choosedFormationId
            )
        table.sort(FormationManager.formationList[this.root.curFormationIndex].teamHeroInfos,function(a,b)
            return a.position < b.position
        end)
        EndLessMapManager.formation = FormationManager.formationList[this.root.curFormationIndex].teamHeroInfos
        EndLessMapManager.SetCanUseHeroNew()
        this.root:ClosePanel()
    else
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
        return
    end

    -- 无尽副本
    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        if MapManager.Mapping then--在地图里
            if this.root.order >= 1 then
                FormationManager.RefreshFormation(FormationTypeDef.FORMATION_AoLiaoer, this.root.choosedList,this.root.tibu,
                {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
                adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
                nil,
                this.root.choosedFormationId)
                PopupTipPanel.ShowTipByLanguageId(10713)
            else
                PopupTipPanel.ShowTipByLanguageId(10712)
            end
        else
           
            this.EnterMapbyType(CarbonManager.difficulty)--, itemId)
        end
    end

--+=======================================


    -- if this.root.order>=1 then
    --     --保存编队
    --     FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,
    --     FormationManager.formationList[this.root.curFormationIndex].teamPokemonInfos)
    -- else
    --     PopupTipPanel.ShowTip(string.format("编队至少上阵%d个神将", 1))
    --     return
    -- end
    -- -- 判断当前选择的副本类型
    -- local itemId = itemType[CarbonManager.difficulty]

    -- 无尽副本
    -- if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
    --     if #FormationManager.GetFormationByID(401).teamHeroInfos == 0 then
    --         PopupTipPanel.ShowTip("未上阵神将，无法保存阵容！")
    --         return
    --     end
    -- else
    --     if #FormationManager.formationList[FormationManager.curFormationIndex].teamHeroInfos == 0 then
    
    --         PopupTipPanel.ShowTip("未上阵神将，无法保存阵容！")
    --         return
    --     end
    -- end



    -- 判断挑战次数
    -- if CarbonManager.difficulty == CARBON_TYPE.NORMAL then -- 普通副本
    --     if BagManager.GetItemCountById(itemId) <= 0 and CarbonManager.GetNormalState(this.curMapId)then
    --         PopupTipPanel.ShowTip("剧情副本剩余次数为0！")
    --         return
    --     end
    -- elseif CarbonManager.difficulty == CARBON_TYPE.HERO then -- 英雄副本
    --     if BagManager.GetItemCountById(itemId) <= 0 then
    --         PopupTipPanel.ShowTip("精英副本剩余次数为0！")
    --         UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.EliteCarbonTicket })
    --         return
    --     end
    -- end
    -- if CarbonManager.difficulty == CARBON_TYPE.NORMAL or  CarbonManager.difficulty == CARBON_TYPE.HERO then
    --     -- 战斗力判断
    --     if this.root.formationPower <CarbonManager.recommendFightAbility[this.curMapId] then
    --         MsgPanel.ShowTwo("当前队伍战力小于推荐战力，战斗可能会有失败风险。确定是否要继续进入副本？", function()
    --         end, function()
    --             -- 开始挑战
    --             this.EnterMapbyType(CarbonManager.difficulty, itemId)
    --         end, "取消", "确定"
    --         )
    --     else
    --         this.EnterMapbyType(CarbonManager.difficulty, itemId)
    --     end
    -- else
    
    --     this.EnterMapbyType(CarbonManager.difficulty, itemId)
    -- end

end

-- 根据不同的副本类型进入地图
function this.EnterMapbyType(type)--, itemId)
    if type == CARBON_TYPE.NORMAL or type == CARBON_TYPE.HERO then
         MapManager.curMapId = this.curMapId
    elseif type == CARBON_TYPE.ENDLESS then
        MapManager.curMapId = EndLessMapManager.openMapId
    end

    local index = CarbonManager.difficulty == CARBON_TYPE.ENDLESS and FormationTypeDef.FORMATION_ENDLESS_MAP or FormationManager.curFormationIndex
    NetManager.MapInfoRequest(MapManager.curMapId, function()
        MapManager.isReloadEnter = false

        SwitchPanel.OpenPanel(UIName.MapPanel)
    end,MapManager.curCarbonType)
end

--- 关闭界面事件
function this.OnCloseBtnClick()
    this.root:ClosePanel()
end

-- 初始化界面显示
function this.InitView()
    if CarbonManager.difficulty == 2 then
        this.TrialCarbon()
    elseif CarbonManager.difficulty == 1 or CarbonManager.difficulty == 3 then
        this.NormalCarbon()
    elseif CarbonManager.difficulty == 4 then
        this.EndLessCarbon()
    end

    -- 初始化编队数据
    this.IniFormationSet(CarbonManager.difficulty)
    -- this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main})--_PanelType[CarbonManager.difficulty] })
end

--
function this.IniFormationSet(type)
    this.IsNeedChangeFormation = type ~= CARBON_TYPE.ENDLESS
end

-- 试炼副本设置
function this.TrialCarbon()
    this.root.bg:SetActive(true)
    this.root.btn_1:SetActive(false)
    this.root.btn_2:SetActive(true)
    this.root.mobTip:SetActive(false)
    this.root.eliteTip:SetActive(false)
    Util.SetGray(this.root.btn_1, true)
    this.root.btn_2_lab.text = GetLanguageStrById(10725)
end

-- 无尽副本设置
function this.EndLessCarbon()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)
    if MapManager.Mapping then
        this.root.btnLeftTxt.text = GetLanguageStrById(10743)
        this.root.btnRightTxt.text = GetLanguageStrById(10726)
    else
        this.root.btnLeftTxt.text = GetLanguageStrById(10743)
        this.root.btnRightTxt.text = GetLanguageStrById(10724)
        -- 进入副本显示设置
        MapManager.isCarbonEnter = true
    end

    this.root.formTip:SetActive(true)
    this.root.formTip:GetComponent("Text").text = GetLanguageStrById(10727) .. gameConfig[1].EndlessMinLevel .. GetLanguageStrById(10728)
end

return this