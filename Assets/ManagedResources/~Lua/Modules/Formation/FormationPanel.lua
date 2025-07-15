require("Base/BasePanel")
FormationPanel = Inherit(BasePanel)
local this = FormationPanel
this.curFormationIndex = 1
this.formationPower = 0
local pokemonInfoList = {}
local mopUpDeleNum = 0
local heroListGo = {}
local yiyaoListGo = {}

--副本剩余次数
local leftTime = 0
local itemId = 0
local effectList = {}
local oldPowerNum = 0
this.demonlive2dInfo = {
    [1] = { Name = "live2d_s_jieling_dlg_3010",
            Scale = Vector3.New(0.3, 0.3, 1),
            Position = Vector2.New(0, -128), },
    [2] = { Name = "live2d_s_jieling_zlz_3001",
            Scale = Vector3.New(0.3, 0.3, 1),
            Position = Vector2.New(0, -128), },
    [3] = { Name = "live2d_s_jieling_hg_3002",
            Scale = Vector3.New(0.3, 0.3, 1),
            Position = Vector2.New(0, -128), },
    [4] = { Name = "live2d_s_jieling_jhj_3003",
            Scale = Vector3.New(0.35, 0.35, 1),
            Position = Vector2.New(0, -128), },
    [5] = { Name = "live2d_s_jieling_hs_3006",
            Scale = Vector3.New(0.25, 0.25, 1),
            Position = Vector2.New(49, -128), },
    [6] = { Name = "live2d_s_jieling_lms_3009",
            Scale = Vector3.New(0.35, 0.35, 1),
            Position = Vector2.New(0, -128), },
    [7] = { Name = "live2d_s_jieling_sl_3005",
            Scale = Vector3.New(0.45, 0.45, 1),
            Position = Vector2.New(0, -128), },
    [8] = { Name = "live2d_s_jieling_md_3007",
            Scale = Vector3.New(0.35, 0.35, 1),
            Position = Vector2.New(0, -128), },
    [9] = { Name = "live2d_s_jieling_fl_3008",
            Scale = Vector3.New(0.4, 0.4, 1),
            Position = Vector2.New(0, -128), },
    [10] = { Name = "live2d_s_jieling_tl_3004",
             Scale = Vector3.New(0.25, 0.25, 1),
             Position = Vector2.New(0, -128), },

}

-- 各个类型编队系统逻辑列表
this.PanelOptionView = {
    [FORMATION_TYPE.CARBON] = "Modules/Formation/View/CarbonFormation",
    [FORMATION_TYPE.STORY] = "Modules/Formation/View/StoryFormation",
    [FORMATION_TYPE.MAIN] = "Modules/Formation/View/MainFormation",
    [FORMATION_TYPE.ARENA_DEFEND] = "Modules/Formation/View/ArenaDefendFormation",
    [FORMATION_TYPE.ARENA_ATTACK] = "Modules/Formation/View/ArenaAttackFormation",
    [FORMATION_TYPE.ARENA_TOP_MATCH] = "Modules/Formation/View/ArenaTopMatchFormation",
    [FORMATION_TYPE.ADVENTURE] = "Modules/Formation/View/AdventureFormation",
    [FORMATION_TYPE.ADVENTURE_BOSS] = "Modules/Formation/View/AdventureBossFormation",
    [FORMATION_TYPE.ELITE_MONSTER] = "Modules/Formation/View/EliteMonsterFormation",
    [FORMATION_TYPE.GUILD_DEFEND] = "Modules/Formation/View/GuildFightDefendFormation",
    [FORMATION_TYPE.GUILD_ATTACK] = "Modules/Formation/View/GuildFightAttackFormation",
    [FORMATION_TYPE.GUILD_BOSS] = "Modules/Formation/View/GuildBossFormation",
    [FORMATION_TYPE.MONSTER_CAMP] = "Modules/Formation/View/MonsterCampFormation",
    [FORMATION_TYPE.BLOODY_BATTLE] = "Modules/Formation/View/FormFightFormation",
    [FORMATION_TYPE.PLAY] = "Modules/Formation/View/PlayWithSBFormation",
    [FORMATION_TYPE.EXPEDITION] = "Modules/Formation/View/ExpeditionFormation",
}
local orginLayer
local orginLayer1
local orginLayer2
local list = {}
--初始化组件（用于子类重写）
function this:InitComponent()
    orginLayer = 0
    orginLayer1 = 0
    orginLayer2 = 0
    self.bg = Util.GetGameObject(self.gameObject, "bg")

    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.elementHelpBtn=Util.GetGameObject(self.gameObject,"elementHelpBtn")
    this.FormationName = Util.GetGameObject(self.transform, "formation/Text"):GetComponent("Text")
    this.FormationNameEditBtn = Util.GetGameObject(self.transform, "formation/edit")
    this.FormationNameLeftArrowBtn = Util.GetGameObject(self.transform, "formation/leftArrow")
    this.FormationNameRightArrowBtn = Util.GetGameObject(self.transform, "formation/rightArrow")
    this.powerNum = Util.GetGameObject(self.transform, "bottom/powerBtn/value"):GetComponent("Text")
    screenAdapte(self.bg)

    local scale = (Screen.width / Screen.height / 1080 * 1920 + 1) / 2
    for i = 1, 5 do
        heroListGo[i] = SubUIManager.Open(SubUIConfig.RoleItemView, Util.GetGameObject(self.transform, "roleGrid/card" .. i).transform)
        if scale < 1 then
            Util.SetParticleScale(Util.GetGameObject(self.transform, "roleGrid/card" .. i .."/effect"), scale)
        end
    end
    for i = 1, 5 do 
        Util.AddParticleSortLayer(Util.GetGameObject(self.transform, "roleGrid/card" .. i).gameObject, self.sortingOrder - orginLayer2)
    end
    orginLayer2 = self.sortingOrder
    orginLayer = self.sortingOrder
    this.ElementalResonanceView = SubUIManager.Open(SubUIConfig.ElementalResonanceView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    self.effect = Util.GetGameObject(self.gameObject, "effect")
    screenAdapte(self.effect)

    for i = 1, 3 do
        yiyaoListGo[i] = {go = Util.GetGameObject(this.transform, "yiyao/" .. i)}
    end

    --副本扫荡
    this.mopUpGo = Util.GetGameObject(self.transform, "root/showMopUp")
    this.btnMpoUpBack = Util.GetGameObject(self.transform, "showMopUp/bg/btnBack")
    this.Slider = Util.GetGameObject(self.transform, "showMopUp/bg/Slider")
    this.numText = Util.GetGameObject(self.transform, "showMopUp/bg/Slider/numText"):GetComponent("Text")
    this.btnMpoUpSure = Util.GetGameObject(self.transform, "showMopUp/bg/btnSure")
    this.buyGoNumTex = Util.GetGameObject(self.transform, "showMopUp/bg/buyGo/numText"):GetComponent("Text")
    -- 购买次数
    this.btnBuyCount = Util.GetGameObject(self.transform, "showMopUp/bg/buyGo/addBtn/GameObject")

    -- 底部panel
    this.bottom = Util.GetGameObject(self.gameObject, "bottom")
    -- 获取按钮
    this.btn_1 = Util.GetGameObject(self.gameObject, "bottom/btnbox/btn_1")
    this.btn_1_lab = Util.GetGameObject(self.gameObject, "bottom/btnbox/btn_1/btnLab"):GetComponent("Text")
    this.btn_2 = Util.GetGameObject(self.gameObject, "bottom/btnbox/btn_2")
    this.btn_2_lab = Util.GetGameObject(self.gameObject, "bottom/btnbox/btn_2/btnLab"):GetComponent("Text")
    -- tip
    this.mobTip = Util.GetGameObject(self.gameObject, "bottom/mobtip")
    this.costTip = Util.GetGameObject(self.gameObject, "bottom/costtip")
    this.failText = Util.GetGameObject(self.gameObject, "bottom/costtip/fail")
    -- 精英副本扫荡提示
    this.eliteTip = Util.GetGameObject(self.gameObject, "bottom/eliTip")
    this.eliteNumNeed = Util.GetGameObject(this.eliteTip, "condition"):GetComponent("Text")
    -- 跳过战斗
    this.passBattle0 = Util.GetGameObject(self.transform, "bottom/passBattle0")
    this.passBattle1 = Util.GetGameObject(self.transform, "bottom/passBattle1")

    -- 上阵等级提示
    this.formTip = Util.GetGameObject(self.transform, "formTip")

    this.mopUpGo.transform:SetParent(self.gameObject.transform)
    this.mopUpGo:SetActive(false)


end

--绑定事件（用于子类重写）
function this:BindEvent()
    -- 逻辑调用
    Util.AddClick(this.btn_1, function()
        if this.opView and this.opView.On_Btn1_Click then
            this.opView.On_Btn1_Click(this.curFormationIndex)
        end
    end)
    Util.AddToggle(this.passBattle0,function (isOn)
        if this.opView and this.opView.On_PassBattle0_Click then
            this.opView.On_PassBattle0_Click(isOn)
        end
    end)
    Util.AddClick(this.btn_2, function()
        if this.opView and this.opView.On_BtnRight_Click then
            this.opView.On_BtnRight_Click(this.curFormationIndex)
        end
    end)
    Util.AddClick(this.BtnBack, function()
        if this.opView and this.opView.OnCloseBtnClick then
            this.opView.OnCloseBtnClick()
        else
            this:ClosePanel()
        end
    end)
    --元素克制帮助按钮
    Util.AddClick(this.elementHelpBtn,function()
        UIManager.OpenPanel(UIName.ElementRestraintPopup)
    end)

    -- 购买副本次数
    Util.AddClick(this.btnBuyCount, function()
        --UIManager.OpenPanel(UIName.CarbonBuyCountPopup, 1)
    end)
    -- 扫荡
    Util.AddClick(this.btnMpoUpSure, function()
        if CarbonManager.difficulty == 1 then
            itemId = 27
        elseif CarbonManager.difficulty == 3 then
            itemId = 28
        end
        if mopUpDeleNum > 0 then
            this.mopUpGo:SetActive(false)
            NetManager.MapSweepRequest(MapManager.curMapId, mopUpDeleNum, function(msg)

                local callBack = function()
                    ShopManager.RequestAllShopData(function()
                        local curTimeStamp = GetTimeStamp()
                        local shopData = ShopManager.GetShopDataByType(SHOP_TYPE.ROAM_SHOP)

                    end)
                end

                -- 扫荡遇到云游商人，则刷新数据
                local func
                -- 精英副本扫荡
                if CarbonManager.difficulty == 3 then
                    if msg.cloudStore > 0 then
                        func = callBack
                    else

                    end

                    -- 判断扫荡是否遇到精英怪
                    if msg.suddenlyBossInfo.suddBossId ~= 0 then
                        if not EliteMonsterManager.HasEliteMonster() then
                            -- 保存精英怪数据
                            local suddBossId = msg.suddenlyBossInfo.suddBossId
                            local endTime = msg.suddenlyBossInfo.endTime
                            local findMapId = msg.suddenlyBossInfo.findMapId
                            EliteMonsterManager.SetEliteData(suddBossId, endTime, findMapId)
                        end
                    end
                end
                UIManager.OpenPanel(UIName.CarbonMopUpEndPanel, msg.drop, msg.cloudStore, msg.suddenlyBossInfo, func)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10689)
        end
    end)
    Util.AddClick(this.btnMpoUpBack, function()
        this.mopUpGo:SetActive(false)
    end)
    Util.AddSlider(this.Slider, function(go, value)
        this.ShowMopUpInfoData(value)
    end)

    Util.AddClick(this.FormationNameLeftArrowBtn, function()
        this.curFormationIndex = this.curFormationIndex - 1
        if this.curFormationIndex < 1 then
            this.curFormationIndex = 3
        end
        FormationManager.curFormationIndex = this.curFormationIndex
        this.RefreshFormation()
    end)

    Util.AddClick(this.FormationNameRightArrowBtn, function()
        this.curFormationIndex = this.curFormationIndex + 1
        if this.curFormationIndex > 3 then
            this.curFormationIndex = 1
        end
        FormationManager.curFormationIndex = this.curFormationIndex
        this.RefreshFormation()
    end)

    for i = 1, 3 do
        Util.AddClick(yiyaoListGo[i].go, function()
            --local pokemonList = {}
            --local curFormation = FormationManager.GetFormationByID(this.curFormationIndex)
            --for i = 1, #curFormation.teamPokemonInfos do
            --    table.insert(pokemonList,{curFormation.teamPokemonInfos[i].pokemonId,curFormation.teamPokemonInfos[i].position})
            --end
            UIManager.OpenPanel(UIName.DiffmonsterEditPopup, this, this.curFormationIndex,i)
        end)
    end
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Formation.OnFormationChange, this.RefreshFormation)
    Game.GlobalEvent:AddEvent(GameEvent.UI.OnBtnClicked, this.ShowStartMopUpInfoData)
    Game.GlobalEvent:AddEvent(GameEvent.Carbon.CarbonCountChange, this.ShowStartMopUpInfoData)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnFormationChange, this.RefreshFormation)
    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnBtnClicked, this.ShowStartMopUpInfoData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Carbon.CarbonCountChange, this.ShowStartMopUpInfoData)

end

function this:OnSortingOrderChange()
    -- 设置特效
    Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)
    for i = 1, 5 do
        Util.AddParticleSortLayer(Util.GetGameObject(self.transform, "roleGrid/card" .. i).gameObject, self.sortingOrder - orginLayer)
    end
    orginLayer = self.sortingOrder
end
--界面打开时调用（用于子类重写）
function this:OnOpen(_panelType, ...)
    if CarbonManager.difficulty == 1 then
        itemId = 27
    elseif CarbonManager.difficulty == 3 then
        itemId = 28
    end
    -- 初始化显示
    this.passBattle0:SetActive(false)
    this.passBattle1:SetActive(false)
    this.btn_1:SetActive(false)
    this.btn_1:GetComponent("Button").enabled = true
    Util.SetColor(this.btn_1, Color.New(1, 1, 1, 1))
    this.btn_2:SetActive(false)
    this.mobTip:SetActive(false)
    this.costTip:SetActive(false)
    this.eliteTip:SetActive(false)
    this.failText:SetActive(false)
    this.formTip:SetActive(false)

    -- 初始化逻辑
    
    this.opView = require(this.PanelOptionView[_panelType])
    this.opView.Init(this, ...)
    this.curFormationIndex = this.opView.GetFormationIndex()
    FormationManager.currentFormationIndex = this.opView.GetFormationIndex()

    --- 判断是否需要切换编队
    this.FormationNameLeftArrowBtn:SetActive(false)--this.opView.IsNeedChangeFormation)
    this.FormationNameRightArrowBtn:SetActive(false)--this.opView.IsNeedChangeFormation)
    this.FormationNameEditBtn:SetActive(false)--this.opView.IsNeedChangeFormation)

    -- 编队刷新
    --this.RefreshFormation(true)
    this.ShowStartMopUpInfoData()
end

function this:OnShow()
    if CarbonManager.difficulty == 1 then
        itemId = 27
    elseif CarbonManager.difficulty == 3 then
        itemId = 28
    end
    this.ElementalResonanceView:OnOpen({ sortOrder = self.sortingOrder})
    this:SetDrawLevel()

    this.RefreshFormation(true)
end


-- 设置扫荡显示的层级
function this:SetDrawLevel()
    local go = this.ElementalResonanceView.gameObject
    local canvas = go:GetComponent("Canvas")
    canvas.overrideSorting = false
end

-- 刷新编队显示
function this.RefreshFormation(isCome)
    EndLessMapManager.RrefreshFormation()
    ExpeditionManager.ExpeditionRrefreshFormation()
    local curFormation = FormationManager.GetFormationByID(this.curFormationIndex)
    this.ElementalResonanceView:SetElementalPropertyTextColor()
    this.ElementalResonanceView:GetElementalType(curFormation.teamHeroInfos,1)
    this.ElementalResonanceView:SetPosition(1)
    this.FormationName.text = curFormation.teamName
    this.formationPower = 0
    --actionNum=0
    for i = 1, 5 do
        if (effectList[i] ~= nil) then
            local go = Util.GetGameObject(this.transform, "roleGrid/card" .. i)
            Util.GetGameObject(go, "effect"):SetActive(false)
        end
    end
    -- 妖灵师等级限制
    local limitLevel = 0
    limitLevel = CarbonManager.difficulty == 4 and EndLessMapManager.limiteLevel or 0
   
    if this.curFormationIndex == FormationTypeDef.EXPEDITION then
        limitLevel = 20
    end
    local limitNum = 1      -- 数量限制
    --limitNum = this.curFormationIndex == FormationManager.FORMATION_GUILD_FIGHT_DEFEND and 5 or 1


    local allHeroTeamAddProVal = HeroManager.GetAllHeroTeamAddProVal(curFormation.teamHeroInfos)
    for i = 1, 5 do
        local go = Util.GetGameObject(this.transform, "roleGrid/card" .. i)
        -- 当前位置是否可上阵
        this.InitArmPos(i, go)
        -- 显示选择的英雄
        local heroData
        if curFormation.teamHeroInfos[i] then
            heroData = HeroManager.GetSingleHeroData(curFormation.teamHeroInfos[i].heroId)
            if not heroData then
               
                return
            end
            -- ==== 上阵显示特效 =====
            if (isCome ~= true) then
                effectList[i]:SetActive(true)
            end
            --effectList[i]:SetActive(false)

            -- ========================== 生成妖灵师并显示出来 =======================
            local heroId = curFormation.teamHeroInfos[i].heroId
            if this.curFormationIndex == FormationTypeDef.EXPEDITION then-- 远征加血量
                heroListGo[i]:OnOpen(heroId, true, true,ExpeditionManager.heroInfo[heroId].remainHp)
            else
                heroListGo[i]:OnOpen(heroId, true, false)
            end
            heroListGo[i].gameObject:SetActive(true)
            this.CalculateAllHeroPower(heroData,allHeroTeamAddProVal)
            -- ====================================================================
        else
            heroListGo[i].gameObject:SetActive(false)
            --Util.GetGameObject(go.transform, "info"):SetActive(false)
        end
        heroListGo[i]:AddClick(function()
            -- UIManager.OpenPanel(UIName.FormationEditPopup, this.curFormationIndex, limitLevel, limitNum)
        end)
        Util.AddOnceClick(go, function()
            -- UIManager.OpenPanel(UIName.FormationEditPopup, this.curFormationIndex, limitLevel, limitNum)
        end)
        Util.AddLongPressClick(Util.GetGameObject(heroListGo[i].transform, "frame"), function()
            if curFormation.teamHeroInfos[i] then
                UIManager.OpenPanel(UIName.RoleInfoPopup, heroData)
            end
        end, 0.5)
    end
    if this.curFormationIndex == FormationTypeDef.EXPEDITION then-- 远征加圣物战力
        this.formationPower = math.floor(this.formationPower * (1 + ExpeditionManager.CalculateallHolyWarPower()/10000))

    end
    local newPowerNum = this.formationPower
    -- if oldPowerNum ~= newPowerNum and oldPowerNum ~= 0 then
    --     UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2,{oldValue = oldPowerNum,newValue = newPowerNum})
    -- end
    RefreshPower(oldPowerNum, newPowerNum)
    oldPowerNum = this.formationPower
    this.powerNum.text = this.formationPower
    --this.actionNum.text=actionNum
    local pokemonList = {}
    for i = 1, #curFormation.teamPokemonInfos do
        table.insert(pokemonList,{curFormation.teamPokemonInfos[i].pokemonId,curFormation.teamPokemonInfos[i].position})
    end
    this.UpdataYiYaoData(pokemonList)
end

-- 设置上阵位置,
function this.InitArmPos(index, go)
    local armNum = ActTimeCtrlManager.MaxArmyNum()
    local canOn = index <= armNum
    local mask = Util.GetGameObject(go, "Mask")
    local tip = Util.GetGameObject(go, "tip")
    local effect = Util.GetGameObject(go, "effect")
    --screenAdapte(effect)
    effectList[index] = effect
    Util.AddParticleSortLayer(effect, this.sortingOrder - orginLayer1)
    --orginLayer1 = this.sortingOrder
    local limitStr = Util.GetGameObject(mask, "lvLimit"):GetComponent("Text")
    mask:SetActive(not canOn)
    tip:SetActive(canOn)
    go:GetComponent("Button").enabled = canOn
    limitStr.text = ActTimeCtrlManager.UnLockCondition(index)
end
-- 刷新异妖显示
function this.UpdataYiYaoData(_pokemonInfoList)
    pokemonInfoList = _pokemonInfoList
    local goList={}
    local tipList={}
    local maxNum = ActTimeCtrlManager.MaxDemonNum()
    for i = 1, 3 do
        goList[i]= Util.GetGameObject(yiyaoListGo[i].go, "icon")
        tipList[i] = Util.GetGameObject(yiyaoListGo[i].go, "tip")
        this.InitDemonNum(i, yiyaoListGo[i].go)
        -- 能选择的异妖数量
        if maxNum > 0 then
            --动态加载立绘
            if yiyaoListGo[i].live then
                poolManager:UnLoadLive(yiyaoListGo[i].name, yiyaoListGo[i].live)
                yiyaoListGo[i].live = nil
            end
        end
    end

    for i = 1, 3 do
        goList[i]:SetActive(false)
        tipList[i]:SetActive(true)
    end

    for i = 1, #_pokemonInfoList do
        if #_pokemonInfoList >= i and i <= maxNum then
            
            local pokemon = _pokemonInfoList[i][1]

            yiyaoListGo[_pokemonInfoList[i][2]].name = this.demonlive2dInfo[pokemon].Name
            yiyaoListGo[_pokemonInfoList[i][2]].live = poolManager:LoadLive(this.demonlive2dInfo[pokemon].Name, goList[_pokemonInfoList[i][2]].transform,
                    this.demonlive2dInfo[pokemon].Scale, Vector3.zero)
            yiyaoListGo[_pokemonInfoList[i][2]].live:GetComponent("RectTransform").anchoredPosition = this.demonlive2dInfo[pokemon].Position

            goList[_pokemonInfoList[i][2]]:SetActive(true)
            tipList[_pokemonInfoList[i][2]]:SetActive(false)
        end
    end
end

--设置异妖上阵显示
function this.InitDemonNum(index, go)
    local maxNum = ActTimeCtrlManager.MaxDemonNum()
    local canOn = false
    if maxNum == 0 then
        canOn = false
    else
        canOn = index <= maxNum
    end
    local mask = Util.GetGameObject(go, "Mask")
    local tip = Util.GetGameObject(mask, "vipLimit"):GetComponent("Text")
    mask:SetActive(not canOn)
    tip.text = ActTimeCtrlManager.DemonNeedVipLv(index,1)
    go:GetComponent("Image").enabled = canOn
    go:GetComponent("Button").enabled = canOn

end

local allEquipAddProVal

function this.CalculateAllHeroPower(curHeroData,allHeroTeamAddProVal)
    allEquipAddProVal = HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId, false,nil,nil,true,allHeroTeamAddProVal)
    this.formationPower = this.formationPower + allEquipAddProVal[HeroProType.WarPower]
    -- actionNum = actionNum + curHeroData.actionPower
end

function this.ShowStartMopUpInfoData()
    local leftTimes = BagManager.GetItemCountById(itemId)
    this.buyGoNumTex.text = leftTimes
    this.Slider:GetComponent("Slider").maxValue = leftTimes
    this.Slider:GetComponent("Slider").minValue = 0
    if leftTimes > 0 then
        mopUpDeleNum = 1 -- 默认从1开始
        --this.Slider:GetComponent("Slider").minValue = 0
    else
        mopUpDeleNum = 0
    end

    this.Slider:GetComponent("Slider").value = mopUpDeleNum
    this.numText.text = mopUpDeleNum
end
function this.ShowMopUpInfoData(value)
    this.numText.text = value
    mopUpDeleNum = value
end
--界面关闭时调用（用于子类重写）
function this:OnClose()
    oldPowerNum = 0
    for i = 1, 3 do
        if yiyaoListGo[i].live then
            poolManager:UnLoadLive(yiyaoListGo[i].name, yiyaoListGo[i].live)
            yiyaoListGo[i].live = nil
        end
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.ElementalResonanceView)
end

return FormationPanel