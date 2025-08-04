require("Base/BasePanel")
FormationPanelV2 = Inherit(BasePanel)
local this = FormationPanelV2

local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local elementalResonanceConfig = ConfigManager.GetConfig(ConfigName.ElementalResonanceConfig)
local guildWarConfig = ConfigManager.GetConfig(ConfigName.GuildWarConfig)
local monsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local formationConfig = ConfigManager.GetConfig(ConfigName.FormationConfig)
local artifactConfig = ConfigManager.GetConfig(ConfigName.ArtifactConfig)
local adjutantConfig = ConfigManager.GetConfig(ConfigName.AdjutantConfig)
local roleConfig = ConfigManager.GetConfig(ConfigName.RoleConfig)
local globalSystemConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)

local orginLayer
local curFormation  --打开面板编队信息
this.choosedList = {}
this.choosedFormationId = 1     --阵型
 --选择上阵列表 临时数据
this.curFormationIndex = 1 --当前编队索引
this.trigger = {}

local bgListGo = {} --上阵背景预设
local heroListGo = {}--英雄上阵预设列表
local dragViewListGo = {}--dragView预设列表

local tabs = {} --筛选按钮
local proId = 0--0 全部  1机械 2体术 3魔法 4秩序 5混沌

local limitLevel = 0--等级限制
local sortType = 1 -- 1：品阶  2：等级

this.order = 0--上阵人数
this.isSaveTeam = false--是否保存队伍

this.formationPower = 0--战力
this.monsterPower = 0--怪物战力
local oldPowerNum = 0 --旧战力
local tempPowerNum = 0 --临时战力

local panelType--窗口类型

local downTimeStart = Time.realtimeSinceStartup
local isDraged = false

this.tibu = ""
this.substitute = {}
this.subLock = {}
this.subAdd = {}
local isLockTibu = false
local tibuGo-- 替补英雄

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
    [FORMATION_TYPE.SAVE_FORMATION] = "Modules/Formation/View/SaveFormation",
    [FORMATION_TYPE.GUILD_CAR_DELEAY] = "Modules/Formation/View/GuildCarDeleayFormation",
    [FORMATION_TYPE.GUILD_DEATHPOS] = "Modules/Formation/View/GuildDeathPosFormation",
    [FORMATION_TYPE.XUANYUAN_MIRROR] = "Modules/Formation/View/XuanYuanMirrorFormation",
    [FORMATION_TYPE.CLIMB_TOWER] = "Modules/Formation/View/ClimbTowerFormation",
    [FORMATION_TYPE.GUILD_TRANSCRIPT] = "Modules/Formation/View/GuildTranscriptFormation",
    [FORMATION_TYPE.DefenseTraining] = "Modules/Formation/View/DefenseTrainingFormation",
    [FORMATION_TYPE.CONTEND_HEGEMONY] = "Modules/Formation/View/ContendHegemonyFormation",
    [FORMATION_TYPE.BLITZ_STRIKE] = "Modules/Formation/View/BlitzStrikeFormation",
    [FORMATION_TYPE.ALAMEIN_WAR] = "Modules/Formation/View/AlameinWarFormation",
    [FORMATION_TYPE.LADDERSCHALLENGE]  = "Modules/Formation/View/LaddersChallengeFormation",
    [FORMATION_TYPE.CHAOS_BATTLE] = "Modules/ChaosZZ/ChaosFormationPanel",
    [FORMATION_TYPE.CHAOS_BATTLE_ACK] = "Modules/ChaosZZ/ChaosFormationACKPanel",
}

local tabType = {
    story = 1,          --闯关
    area = 2,           --竞技
    area_match = 3,     --锦标赛
    -- tower_god = 4,      --神之塔
    -- tower_magic = 5,    --魔之塔
    -- guide_challenge = 6,--公会副本
    -- guide_battle = 7,   --公会战
    -- corruption = 8,     --腐化之战
    -- nightmare = 9,      --梦魇入侵
    -- denseFog = 10,      --迷雾之战
    forget = 11,        --遗忘之城
    -- broken = 12,        --破碎王座
    crossServer = 13,   --跨服竞技场
  --  chaosBattle   = 14, --混乱之治
}
local tabNames = {
    {GetLanguageStrById(50286), tabType.story},--闯关
    {GetLanguageStrById(50287), tabType.area},--竞技
    {GetLanguageStrById(50288), tabType.area_match},--锦标赛
    -- {GetLanguageStrById(50289), tabType.tower_god},--神之塔
    --{GetLanguageStrById("魔之塔"), tabType.tower_magic},--魔之塔
    -- {GetLanguageStrById(50290), tabType.guide_challenge},--公会副本
    -- {GetLanguageStrById(10550), tabType.guide_battle},--公会战
    -- {GetLanguageStrById(23023), tabType.corruption},--腐化之战
    -- {GetLanguageStrById(50217), tabType.nightmare},--梦魇入侵
    -- {GetLanguageStrById(23155), tabType.denseFog},--迷雾之战
    {GetLanguageStrById(50213), tabType.forget},--遗忘之城
    -- {GetLanguageStrById(50214), tabType.broken},--破碎王座
    {GetLanguageStrById(50228), tabType.crossServer},--跨服天梯
   -- {"1111111", tabType.chaosBattle},--混乱之治
}
local tabBtns = {}
local btnSprite = {
    "cn2-X1_tongyong_fenlan_weixuanzhong_02",
    "cn2-X1_shouhu_biaoqian_xuanzhong"
}

--设置先驱，守护 图标位置
local poslist = {
    --- 解锁后位置
    aft_btnGuard = Vector2(430,-480),
    aft_btnPioneer = Vector2(430,-890),
    --- 解锁前位置
    befor_btnGuard = Vector3(-423,-480),
    befor_btnPioneer = Vector3(-423,-890)
}


function this:InitComponent()
    IsJump = true
    this.storyjump = true
    orginLayer = 0
    this.bg = Util.GetGameObject(this.gameObject, "Bg")
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")

    this.power = Util.GetGameObject(this.gameObject, "Power/Value"):GetComponent("Text")
    this.root = Util.GetGameObject(this.gameObject, "Root")

    this.roleGrid = Util.GetGameObject(this.gameObject, "RoleGrid")
    this.line = Util.GetGameObject(this.gameObject, "RoleGrid/Line")
    this.heroPre = Util.GetGameObject(this.gameObject, "Scroll/HeroPre2")
    heroListGo = {}
    for i = 1, 9 do
        bgListGo[i] = Util.GetGameObject(this.gameObject, "RoleGrid/Bg" .. i)
        if not heroListGo[i] then
            local go = newObject(this.heroPre)
            go.name = "Card" .. tostring(i)
            go.transform:SetParent(Util.GetGameObject(this.gameObject, "RoleGrid/Bg" .. i).transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:GetComponent("EmptyRaycast").raycastTarget = false
            heroListGo[i] = go
        end

        if not dragViewListGo[i] then
            dragViewListGo[i] = SubUIManager.Open(SubUIConfig.DragView, bgListGo[i].transform)
        end
        dragViewListGo[i].gameObject.name = "DragView"..i
        dragViewListGo[i].gameObject:SetActive(false)
        dragViewListGo[i]:SetScrollMouse(false)
        this.trigger[i] = Util.GetEventTriggerListener(dragViewListGo[i].gameObject)
        this.trigger[i].onPointerDown = this.trigger[i].onPointerDown+this.OnPointerDown
        this.trigger[i].onPointerUp = this.trigger[i].onPointerUp+this.OnPointerUp
        this.trigger[i].onEndDrag = this.trigger[i].onEndDrag+this.OnEndDrag
        this.trigger[i].onDrag = this.trigger[i].onDrag+this.OnDrag
        dragViewListGo[i]:SetDragGO(heroListGo[i])
    end

    --替补
    this.substitute = Util.GetGameObject(this.gameObject, "substitute")
    Util.GetGameObject(this.substitute, "_name"):GetComponent("Text").text = GetLanguageStrById(50291)
    this.subLock = Util.GetGameObject(this.substitute, "lock")
    this.subAdd = Util.GetGameObject(this.substitute, "Pos/add")
    local go = newObject(this.heroPre)
    go.name = "Card10"
    go.transform:SetParent(this.substitute.transform)
    go.transform.localScale = Vector3.one*0.86
    go.transform.localPosition = Vector3.zero
    go:GetComponent("EmptyRaycast").raycastTarget = false
    tibuGo = go
    this.SetTibuAsDragabel(this.substitute,go)

    this.HeroPre = Util.GetGameObject(this.gameObject, "Scroll/HeroPre")
    this.HeroPre.transform:SetParent(self.transform)
    this.HeroPre:GetComponent("RectTransform").localScale = Vector3.one

    this.empty = Util.GetGameObject(this.gameObject,"Scroll/Empty")
    this.scroll = Util.GetGameObject(this.gameObject, "Scroll")
    -- this.scrollBar = Util.GetGameObject(this.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    local rect = this.scroll.transform.rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scroll.transform,
        this.HeroPre, this.scrollBar, Vector3.New(rect.width,rect.height), 1, 5, Vector2.New(5, 5), 1)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    --筛选按钮
    for i = 0, 5 do
        tabs[i] = Util.GetGameObject(this.gameObject, "Tabs/grid/Btn" .. i)
    end

    -- 获取按钮
    this.btnLeft = Util.GetGameObject(self.gameObject, "bottom/btnbox/btn_1")
    this.btnLeftTxt = Util.GetGameObject(this.btnLeft, "Text"):GetComponent("Text")
    this.btnRight = Util.GetGameObject(self.gameObject, "bottom/btnbox/btn_2")
    this.btnRightTxt = Util.GetGameObject(this.btnRight, "Text"):GetComponent("Text")

    this.tabsContent = Util.GetGameObject(self.transform, "tabsbg/grid/tabsContent")
    this.tabPre = Util.GetGameObject(this.tabsContent, "tab")

    this.btnGuard = Util.GetGameObject(self.transform, "btnGuard")--守护
    this.btnPioneer = Util.GetGameObject(self.transform, "btnPioneer")--先驱
    -- this.btnSubstitute = Util.GetGameObject(self.transform, "btnSubstitute")--替补
    this.btnFormation = Util.GetGameObject(self.transform, "btnFormation")--阵型
    this.btnBattleBuff = Util.GetGameObject(self.transform, "btnBattleBuff")--克制
    this.btnLeadGene = Util.GetGameObject(self.transform, "btnLeadGene")--基因
end

--抽象出的相同代码
function clickbutton()
    this.btnLeft:SetActive(false)
    this.btnLeft:GetComponent("Button").enabled = true
    this.btnRight:SetActive(false)
    this.empty:SetActive(false)
end

function this:BindEvent()
    --返回按钮
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)

    --筛选按钮
    for i = 0, 5 do
        Util.AddClick(tabs[i], function()
            proId = i
            this.OnClickTabBtn(proId)
        end)
    end
    -- --推荐阵容
    -- Util.AddClick(this.btnExample,function()
    --     UIManager.OpenPanel(UIName.FormationExamplePopup)
    -- end)

    --通用逻辑调用
    Util.AddOnceClick(this.btnLeft, function()
        if this.opView and this.opView.On_BtnLeft_Click then
            if panelType == FORMATION_TYPE.PLAY then
                BattleManager.GotoFight(function()
                    this.opView.On_BtnLeft_Click(this.curFormationIndex, IsJump)
                end)
            else
                this.opView.On_BtnLeft_Click(this.curFormationIndex, IsJump)
            end
        end
    end)
    Util.AddOnceClick(this.btnRight, function()
        if this.opView and this.opView.On_BtnRight_Click then
            BattleManager.GotoFight(function()
                this.opView.On_BtnRight_Click(this.curFormationIndex)
            end)
        end
    end)

    --阵型
    Util.AddClick(this.btnFormation, function()
        if not this.opView.ChangeFormation then
            PopupTipPanel.ShowTipByLanguageId(12555)
            return
        end
        UIManager.OpenPanel(UIName.FormationPositonPopup, self,function()
            this.SetFormationIcon()
        end)
    end)

    Util.AddClick(this.btnBattleBuff, function()
        UIManager.OpenPanel(UIName.FormationBuffPopup, this.choosedList)
    end)
    --守护
    Util.AddClick(this.btnGuard, function()
        if not this.opView.ChangeFormation then
            PopupTipPanel.ShowTipByLanguageId(12555)
            return
        end
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT) then
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.SUPPORT))
            return
        end

        NetManager.GetSupportList(function()
            UIManager.OpenPanel(UIName.SupportSelectPanel, this.curFormationIndex)
        end)
    end)
    --先驱
    Util.AddClick(this.btnPioneer, function()
        if not this.opView.ChangeFormation then
            PopupTipPanel.ShowTipByLanguageId(12555)
            return
        end
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT) then
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ADJUTANT))
            return
        end
        UIManager.OpenPanel(UIName.AdjutantSelectPanel, this.curFormationIndex)
    end)
    --基因
    Util.AddClick(this.btnLeadGene, function()
        -- if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER) then
        --     PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER))
        --     return
        -- end
        local data = AircraftCarrierManager.GetAllSkillData(true)
        if #data < 1 then
            PopupTipPanel.ShowTipByLanguageId(91000141)
            return
        end
        UIManager.OpenPanel(UIName.LeadAssemblyPanel)
    end)
    -- Util.AddClick(this.btnSubstitute, function()
    --     if not this.opView.ChangeFormation then
    --         PopupTipPanel.ShowTipByLanguageId(12555)
    --         return
    --     end
    -- end)
    Util.AddClick(tibuGo, function()
        --冲突 需要解决
        if isLockTibu then
            -- PopupTipPanel.ShowTip("") --todo 等待文本id
            return
        end
        if this.tibu ~= "" and  this.tibu ~= nil then
            if not isLockTibu then
                this.RefreshTibuWarPower(true)
                this.tibu = ""
                this.SetCardsData()
                this.OnClickTabBtn(proId)
            end
        end
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Formation.OnFormationChange, this.RefreshPower)
    Game.GlobalEvent:AddEvent(GameEvent.Formation.OnSupportChange, this.OnSupportChange)
    Game.GlobalEvent:AddEvent(GameEvent.Formation.OnAdjutantChange, this.OnAdjutantChange)
    -- Game.GlobalEvent:AddEvent(GameEvent.Formation.OnCVChange, this.OnCVChange)
    Game.GlobalEvent:AddEvent(GameEvent.Lead.RefreshSkill, this.SetLeadGene)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnFormationChange, this.RefreshPower)
    Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnSupportChange, this.OnSupportChange)
    Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnAdjutantChange, this.OnAdjutantChange)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnCVChange, this.OnCVChange)
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.RefreshSkill, this.SetLeadGene)
end

function this:OnSortingOrderChange()
    for _,o in pairs(heroListGo) do
        Util.AddParticleSortLayer(o, self.sortingOrder - orginLayer)
    end
    orginLayer = self.sortingOrder
end

function this:OnOpen(_panelType,...)
    panelType = _panelType
    clickbutton()
    this.isSaveTeam = _panelType == FORMATION_TYPE.SAVE_FORMATION

    this.SetRoreignAid()
    if _panelType == FORMATION_TYPE.SAVE_FORMATION then
        this.storyjump = false
    end
    this.opView = require(this.PanelOptionView[_panelType])
    this.opView.Init(this, ...)
    this.curFormationIndex = this.opView.GetFormationIndex()
    FormationManager.currentFormationIndex = this.opView.GetFormationIndex()
    SoundManager.PlaySound(SoundConfig.Sound_BattleStart_01)
    if this.opView.ChangeFormation == nil then
        this.opView.ChangeFormation = true
    end
    isLockTibu = this.IsTibuLock()
    this.SetTibuLock()
    this.tabsContent:SetActive(_panelType == FORMATION_TYPE.SAVE_FORMATION)
end

function this:OnShow()
    for i = 1, #tabNames do
        if not tabBtns[i] then
            tabBtns[i] = {}
        end
        if not tabBtns[i].go then
            tabBtns[i].go = newObjToParent(this.tabPre, this.tabsContent)
        end
        Util.GetGameObject(tabBtns[i].go, "name"):GetComponent("Text").text = tabNames[i][1]
        Util.GetGameObject(tabBtns[i].go, "select"):GetComponent("Text").text = tabNames[i][1]
        tabBtns[i].type = tabNames[i][2]
        tabBtns[i].go:SetActive(true)
        Util.AddOnceClick(tabBtns[i].go, function ()
            this.TabAddListen(tabBtns[i].type)
        end)
    end

    this.choosedFormationId = FormationManager.GetFormationByID(this.curFormationIndex).formationId
    FormationManager.SetFormationId(this.choosedFormationId)

    this.RefreshFormation()

    FormationManager.UpdateSupportData()
    Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnSupportChange)
    FormationManager.UpdateAdjutantData()
    Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnAdjutantChange)
    -- Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnCVChange)

    this:SetDragEnabled()
    this.SetFormationIcon()
    this.SetSelect(1)
    this.SetLeadGene()
end

--设置外援是否解锁
function this.SetRoreignAid()
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT) then
        Util.GetGameObject(this.btnPioneer, "lock"):SetActive(false)
        Util.GetGameObject(this.btnPioneer, "add"):SetActive(true)
    else
        Util.GetGameObject(this.btnPioneer, "lock"):SetActive(true)
        Util.GetGameObject(this.btnPioneer, "add"):SetActive(false)
    end
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT) then
        Util.GetGameObject(this.btnGuard, "lock"):SetActive(false)
        Util.GetGameObject(this.btnGuard, "add"):SetActive(true)
    else
        Util.GetGameObject(this.btnGuard, "lock"):SetActive(true)
        Util.GetGameObject(this.btnGuard, "add"):SetActive(false)
    end
end

--设置拖拽是否有效
function this:SetDragEnabled()
    local isEnabled = true
    if this.curFormationIndex == FormationTypeDef.DEFENSE_TRAINING then
        if not this.opView.ChangeFormation then
            isEnabled = false
        end
    elseif this.curFormationIndex == FormationTypeDef.ARENA_TOM_MATCH then
        if not this.opView.ChangeFormation then
            isEnabled = false
        end
    end
    for i = 1, #dragViewListGo do
        dragViewListGo[i]:SetEnabled(isEnabled)
    end
end

function this:OnClose()
    -- 防止拖动关闭卡死
    isDraged = false

    tempPowerNum = 0
    this.formationPower = 0
    this.monsterPower = 0
    oldPowerNum = 0
    proId = 0--面板关闭时 重置筛选按钮为全部

    --改变bool值
    this.storyjump = true
    this.tabsContent:SetActive(true)
end

function this:OnDestroy()
    for k, v in ipairs(dragViewListGo) do
        SubUIManager.Close(SubUIConfig.DragView, v)
    end
    dragViewListGo = {}
    tabBtns = {}

    this.scrollView = nil
end

function this:OpenPanel(type, func)
    this.opView = require(this.PanelOptionView[type])
    func()
    this.curFormationIndex = this.opView.GetFormationIndex()
    FormationManager.currentFormationIndex = this.opView.GetFormationIndex()
    SoundManager.PlaySound(SoundConfig.Sound_BattleStart_01)
    this.choosedFormationId = FormationManager.GetFormationByID(this.curFormationIndex).formationId
    FormationManager.SetFormationId(this.choosedFormationId)
    this.RefreshFormation()
    FormationManager.UpdateSupportData()
    Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnSupportChange)
    FormationManager.UpdateAdjutantData()
    Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnAdjutantChange)
    this:SetDragEnabled()
end

--刷新编队
function this.RefreshFormation()
    proId = 0
    EndLessMapManager.RrefreshFormation()
    --获取当前编队数据
    if this.curFormationIndex == FormationTypeDef.EXPEDITION then
        ExpeditionManager.ExpeditionRrefreshFormation()--刷新编队
    end
    curFormation = FormationManager.GetFormationByID(this.curFormationIndex)
    --上阵列表赋值
    this.choosedList = {}
    for j = 1, #curFormation.teamHeroInfos do
        local teamInfo = curFormation.teamHeroInfos[j]
        table.insert(this.choosedList, {heroId = teamInfo.heroId,position = teamInfo.position})
    end
    this.order = #this.choosedList

    this.tibu = curFormation.substitute

    -- 妖灵师等级限制
    limitLevel = 0
    limitLevel = CarbonManager.difficulty == 4 and EndLessMapManager.limiteLevel or 0
    if this.curFormationIndex == FormationTypeDef.EXPEDITION then
        limitLevel = 20
    end

    --设置上阵英雄信息
    this.SetCardsData()
    --显示英雄列表
    this.OnClickTabBtn(proId)
    --战力
    this.RefreshPower()
end

--设置编队上阵英雄信息
function this.SetCardsData()
    this.formationPower = 0--战力
    this.InitArmPos()
    this.InitArmData()

    --编队为0显示0战力
    if #this.choosedList <= 0 then
        this.formationPower = 0
    end
    this.power.text = this.formationPower

    --飘战力
    local newPowerNum = this.formationPower
    RefreshPower(tempPowerNum, newPowerNum)
    tempPowerNum = this.formationPower

    this.UpdateElementIcon()

    --设置不可挪动位置显示
    local posArray = formationConfig[this.choosedFormationId].pos
    for i = 1, #bgListGo do
        local isHave = false
        for j = 1, #posArray do
            if posArray[j] == i then
                isHave = true
            end
        end
        if i ~= 10 then
            Util.GetGameObject(bgListGo[i], "NoUse"):SetActive(not isHave)
            Util.GetGameObject(bgListGo[i], "Pos"):SetActive(isHave)
        end
    end

    for i = 1, 9 do
        if bgListGo[i] then
            local nameGo = Util.GetGameObject(bgListGo[i], "name")
            -- local name = nil
            for j = 1, #this.choosedList do
                if this.choosedList[j].position == i then
                    local herodata = HeroManager.GetSingleHeroData(this.choosedList[j].heroId)
                    -- name = GetLanguageStrById(herodata.name)
                end
            end
            -- if name then
            --     nameGo:SetActive(true)
            --     nameGo:GetComponent("Text").text = name
            -- else
                nameGo:SetActive(false)
            -- end
        end
    end
    --Util.GetGameObject(this.gameObject, "RoleGrid/Bg" .. i .. "/name"):SetActive(false)
    if not isLockTibu then
        if this.tibu ~= "" and this.tibu ~= nil then
            -- this.RefreshTibuWarPower(false)
            tibuGo:SetActive(true)
        else
            tibuGo:SetActive(false)
        end
    end
end

-- 设置编队上阵位置显隐
function this.InitArmPos()
    for i = 1, 9 do
        local info = heroListGo[i]
        local armNum = GVM.GetGVValue(GVM.FormationMaxNum)
        local canOn = i <= armNum--能上阵

        -- 显示解锁条件
        if #this.choosedList == 0 then
            info:SetActive(false)
            dragViewListGo[i].gameObject:SetActive(false)
        end
        -- 显示上阵的英雄
        local heroData
        for j = 1, #this.choosedList do
            if i == this.choosedList[j].position then
                if special and DefenseTrainingManager.teamLock == 1 then
                    heroData = HeroTemporaryManager.GetSingleHeroData(this.choosedList[j].heroId)
                else
                    heroData = HeroManager.GetSingleHeroData(this.choosedList[j].heroId)
                end
                if not heroData then
                    --LogError("heroData is not exist! error Did:" .. this.choosedList[j].heroId)
                    return
                end
                info:SetActive(true)
                dragViewListGo[i].gameObject:SetActive(true)
                break
            else
                info:SetActive(false)
                dragViewListGo[i].gameObject:SetActive(false)
            end
        end
    end
    -- 替补可拖拽
    if #dragViewListGo>= 10 then
        dragViewListGo[10].gameObject:SetActive(true)
    end
end
-- 设置编队上阵数据
function this.InitArmData()
    --为每个英雄添加拖动组件
    for n = 1, #this.choosedList do
        local allHeroTeamAddProVal = HeroManager.GetAllHeroTeamAddProVal(this.choosedList,this.choosedList[n].heroId)
        --已上阵操作
        local pos = this.choosedList[n].position

        local heroId = this.choosedList[n].heroId
        local heroData = HeroManager.GetSingleHeroData(heroId)

        this.SetOneCardData(heroListGo[pos], heroData)

        --战力计算
        this.CalculateAllHeroPower(heroData,allHeroTeamAddProVal)

        --英雄长按
        local heroClick = Util.GetGameObject(bgListGo[pos],"DragView"..pos)
        Util.AddLongPressClick(heroClick, function()
            UIManager.OpenPanel(UIName.RoleInfoPopup, heroData)
        end, 0.5)
    end
    if not isLockTibu then
        if this.tibu ~= "" and this.tibu ~= nil then
            local heroData = HeroManager.GetSingleHeroData(this.tibu)
            local tiBuPower = HeroManager.CalculateHeroAllProValList(1, this.tibu, false)
            this.formationPower = this.formationPower +tiBuPower[HeroProType.WarPower]
            this.SetOneCardData(tibuGo, heroData)
        end
    end
end

function this.SetOneCardData(_go, _heroData)
    local go = _go
    local heroData = _heroData
    local frame = Util.GetGameObject(go,"frame"):GetComponent("Image")
    local icon = Util.GetGameObject(go, "icon"):GetComponent("Image")
    local lv = Util.GetGameObject(go, "lv"):GetComponent("Text")
    local Image_proBg = Util.GetGameObject(go, "Image_proBg"):GetComponent("Image")
    local pro = Util.GetGameObject(go, "Image_proBg/proIcon"):GetComponent("Image")
    local starGrid = Util.GetGameObject(go, "star")
    -- local yuanImage = Util.GetGameObject(go, "yuanImage")
    local choosedObj = Util.GetGameObject(go, "choosed")
    local hpExp = Util.GetGameObject(go, "hpExp")
    local lvBg = Util.GetGameObject(go, "lvBg"):GetComponent("Image")

    frame.sprite = Util.LoadSprite(GetQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
    icon.sprite = Util.LoadSprite(heroData.icon)
    lv.text = tostring(heroData.lv)
    Image_proBg.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.heroConfig.Quality,heroData.star))
    pro.sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    lvBg.sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroData.heroConfig.Quality,heroData.star))
    SetHeroStars(starGrid, heroData.star)
    --血量显示
    hpExp:SetActive(false)
    choosedObj:SetActive(false)
end

--战力计算
function this.CalculateAllHeroPower(curHeroData, allHeroTeamAddProVal)
    local allEquipAddProVal =
        HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId, false, nil, nil, true, allHeroTeamAddProVal)
    this.formationPower = this.formationPower + allEquipAddProVal[HeroProType.WarPower]
end

--点击筛选
function this.OnClickTabBtn(_proId)
    local heros
    if this.curFormationIndex == FormationTypeDef.EXPEDITION then
        if _proId == ProIdConst.All then
            heros = HeroManager.GetAllHeroDatas(limitLevel)
            heros = ExpeditionManager.GetAllHeroDatas(heros,limitLevel)
        else
            heros = HeroManager.GetHeroDataByProperty(_proId, limitLevel)
            heros = ExpeditionManager.GetHeroDataByProperty(heros,_proId, limitLevel)
        end
    elseif this.curFormationIndex == FormationTypeDef.DEFENSE_TRAINING then
        if _proId == ProIdConst.All then
            heros = HeroManager.GetAllHeroDatas(limitLevel)
            heros = DefenseTrainingManager.GetAllHeroDatas(heros,limitLevel)
        else
            heros = HeroManager.GetHeroDataByProperty(_proId, limitLevel)
            heros = DefenseTrainingManager.GetHeroDataByProperty(heros,_proId, limitLevel)
        end
    else
        if _proId == ProIdConst.All then
            heros = HeroManager.GetAllHeroDatas(limitLevel)
        else
            heros = HeroManager.GetHeroDataByProperty(_proId, limitLevel)
        end
    end
    this.empty:SetActive(#heros <= 0)
    this.SetRoleList(heros)

    --
    for key, value in pairs(tabs) do
        value:GetComponent("Image").sprite = Util.LoadSprite(X1CampTabSelectPic[key])
        local Image_Select = Util.GetGameObject(value,"select")
        Image_Select:SetActive(key == _proId)
    end
end

--设置英雄列表数据
function this.SetRoleList(_roleDatas)
    this.SortHeroDatas(_roleDatas)
    -- local curFormation = FormationManager.formationList[this.curFormationIndex]
    this.scrollView:SetData(_roleDatas, function(index, go)
        this.SingleHeroDataShow(go, _roleDatas[index])
    end)
end

function this.SetSelect(id)
    for i = 1, #tabBtns do
        Util.GetGameObject(tabBtns[i].go, "name"):SetActive(tabBtns[i].type ~= id)
        Util.GetGameObject(tabBtns[i].go, "select"):SetActive(tabBtns[i].type == id)
        if tabBtns[i].type == id then
            Util.GetGameObject(tabBtns[i].go, "bg"):GetComponent("Image").sprite = Util.LoadSprite(btnSprite[2])
        else
            Util.GetGameObject(tabBtns[i].go, "bg"):GetComponent("Image").sprite = Util.LoadSprite(btnSprite[1])
        end
    end
end

--排序英雄数据
function this.SortHeroDatas(_heroDatas)
    local choosed = {}
    local dieHeros = {}
    local curFormation = FormationManager.GetFormationByID(this.curFormationIndex)

    for i = 1, #_heroDatas do
        local heroHp = FormationManager.GetFormationHeroHp(this.curFormationIndex, _heroDatas[i].dynamicId)
        if heroHp then
            if heroHp <= 0 then
                dieHeros[_heroDatas[i].dynamicId] = _heroDatas[i].dynamicId
            end
        end
    end
    for j = 1, #curFormation.teamHeroInfos do
        local teamInfo = curFormation.teamHeroInfos[j]
        choosed[teamInfo.heroId] = j
    end

    table.sort(_heroDatas, function(a, b)
        if (choosed[a.dynamicId] and choosed[b.dynamicId]) or
                (not choosed[a.dynamicId] and not choosed[b.dynamicId])
        then
            if (dieHeros[a.dynamicId] and dieHeros[b.dynamicId]) or
                    (not dieHeros[a.dynamicId] and not dieHeros[b.dynamicId])
            then
                if sortType == SortTypeConst.Natural then
                    if a.heroConfig.Natural == b.heroConfig.Natural then
                        if a.heroConfig.Quality == b.heroConfig.Quality then
                            if a.star == b.star then
                                if a.lv == b.lv then
                                    if a.warPower == b.warPower then
                                        if a.id == b.id then
                                            return a.sortId > b.sortId
                                        else
                                            return a.id > b.id
                                        end
                                    else
                                        return a.warPower > b.warPower
                                    end
                                else
                                    return a.lv > b.lv
                                end
                            else
                                return a.star > b.star
                            end
                        else
                            return a.heroConfig.Quality > b.heroConfig.Quality
                        end
                    else
                        return a.heroConfig.Natural > b.heroConfig.Natural
                    end
                else
                    if a.lv == b.lv then
                        if a.heroConfig.Quality == b.heroConfig.Quality then
                            if a.star == b.star then
                                if a.heroConfig.Natural == b.heroConfig.Natural then
                                    if a.warPower == b.warPower then
                                        if a.id == b.id then
                                            return a.sortId > b.sortId
                                        else
                                            return a.id > b.id
                                        end
                                    else
                                        return a.warPower > b.warPower
                                    end
                                else
                                    return a.heroConfig.Natural > b.heroConfig.Natural
                                end
                            else
                                return a.star > b.star
                            end
                        else
                            return a.heroConfig.Quality > b.heroConfig.Quality
                        end
                    else
                        return a.lv > b.lv
                    end
                end
            else
                return not dieHeros[a.dynamicId] and  dieHeros[b.dynamicId]
            end
        else
            return choosed[a.dynamicId] and not choosed[b.dynamicId]
        end
    end)
end

--设置每条英雄数据
function this.SingleHeroDataShow(_go, _heroData)
    local go = _go
    local heroData = _heroData
    local frame = Util.GetGameObject(go,"frame"):GetComponent("Image")
    local icon = Util.GetGameObject(go, "icon"):GetComponent("Image")
    local lv = Util.GetGameObject(go, "lv"):GetComponent("Text")
    local Image_proBg = Util.GetGameObject(go, "Image_proBg"):GetComponent("Image")
    local pro = Util.GetGameObject(go, "Image_proBg/proIcon"):GetComponent("Image")
    local starGrid = Util.GetGameObject(go, "star")
    local choosedObj = Util.GetGameObject(go, "choosed")
    local hpExp = Util.GetGameObject(go, "hpExp")
    local lvBg = Util.GetGameObject(go, "lvBg"):GetComponent("Image")
    local choosedBg = Util.GetGameObject(go, "choosedBg")

    frame.sprite = Util.LoadSprite(GetQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
    icon.sprite = Util.LoadSprite(heroData.icon)
    lv.text = tostring(heroData.lv)
    Image_proBg.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.heroConfig.Quality,heroData.star))
    pro.sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    lvBg.sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroData.heroConfig.Quality,heroData.star))
    SetHeroStars(starGrid, heroData.star)
    --血量显示
    hpExp:SetActive(false)
    choosedObj:SetActive(false)
    choosedBg:SetActive(false)

    --> 血量显示
    local curHeroHpVal = FormationManager.GetFormationHeroHp(this.curFormationIndex, _heroData.dynamicId)
    if not curHeroHpVal then
        Util.SetGray(go,false)
        hpExp:SetActive(false)
    else
        hpExp:SetActive(true)
        hpExp:GetComponent("Slider").value = curHeroHpVal
        if curHeroHpVal <= 0 then
            --替补下阵
            if this.tibu == _heroData.dynamicId then
                this.tibu = ""
                this.SetCardsData()
                -- this.OnClickTabBtn(proId)
            end
            Util.SetGray(go,true)
        else
            Util.SetGray(go,false)
        end
    end

    choosedObj:SetActive(false)
    choosedBg:SetActive(false)
    for i, v in pairs(this.choosedList) do
        if heroData.dynamicId == v.heroId then
            choosedObj:SetActive(true)
            choosedBg:SetActive(true)
        end
    end

    -- 替补被选择
    if this.tibu ~= nil then
        if this.tibu == heroData.dynamicId then
            choosedObj:SetActive(true)
            choosedBg:SetActive(true)
        end
    end

    local redPoint = Util.GetGameObject(_go.transform, "redAndLock/redPoint")
    Util.GetGameObject(_go.transform, "redAndLock/lockImage"):SetActive(heroData.lockState == 1)

    -- local redPoint = Util.GetGameObject(_go.transform, "card/sign/redPoint")
    -- Util.GetGameObject(_go.transform, "card/sign/lockImage"):SetActive(heroData.lockState == 1)
    local starGrid = Util.GetGameObject(_go.transform, "star")
    -- local starPre = Util.GetGameObject(_go.transform, "starPre")
    SetHeroStars(starGrid, heroData.star)

    redPoint:SetActive(false)
    Util.AddOnceClick(_go, function()
        --已上阵取消勾选
        if this.opView.ChangeFormation then
            if curHeroHpVal and curHeroHpVal <= 0 then
                PopupTipPanel.ShowTipByLanguageId(10691)
                return
            end

            -- 英雄下阵
            for k, v in ipairs(this.choosedList) do
                if v.heroId == heroData.dynamicId then
                    choosedObj:SetActive(false)
                    choosedBg:SetActive(false)
                    this.order = this.order-1
                    chooseIndex = v.position
                    table.remove(this.choosedList,k)
                    this.SetCardsData()
                    return
                end
            end

            if heroData.dynamicId == this.tibu and not isLockTibu  then
                --替补下阵
                this.RefreshTibuWarPower(true)
                this.tibu = ""
                choosedObj:SetActive(false)
                choosedBg:SetActive(false)
                this.SetCardsData()
                this.OnClickTabBtn(proId)
                return
            end

            local isTibu = false

            -- 当前可选的最大上阵人数
            local maxNum = GVM.GetGVValue(GVM.FormationMaxNum)
            if LengthOfTable(this.choosedList) >= maxNum then
                --检测替补位置是否可以上阵
                if not isLockTibu then
                    if  this.tibu == "" or this.tibu == nil then
                        if  this.tibu ~= "" and this.tibu == heroData.dynamicId then
                            PopupTipPanel.ShowTipByLanguageId(10693)
                            return
                        end
                        --判断是否上阵相同猎妖师
                        for k, v in pairs(this.choosedList) do
                            if HeroManager.GetSingleHeroData(v.heroId).id == heroData.id then
                                PopupTipPanel.ShowTipByLanguageId(10693)
                                return
                            end
                        end

                        isTibu = true
                        this.tibu = heroData.dynamicId
                        choosedObj:SetActive(true)
                        choosedBg:SetActive(true)
                        this.SetCardsData()
                        this.OnClickTabBtn(proId)
                    end
                else
                    PopupTipPanel.ShowTipByLanguageId(10692)
                end
                return
            end

            --判断是否上阵相同猎妖师
            for k, v in pairs(this.choosedList) do
                if HeroManager.GetSingleHeroData(v.heroId).id == heroData.id then
                    PopupTipPanel.ShowTipByLanguageId(10693)
                    return
                end
            end
            -- 判断是否同替补英雄  id 不可对比
            local tibuDid = {}
            if  this.tibu ~= "" and this.tibu ~= nil then
                tibuDid = HeroManager.GetSingleHeroData(this.tibu).id
                if  tibuDid == heroData.id then
                    PopupTipPanel.ShowTipByLanguageId(10693)
                    return
                end
            end

            choosedObj:SetActive(true)
            choosedBg:SetActive(true)

            --自动计算位置 并赋值pos
            if this.GetPos() == 0 then
                PopupTipPanel.ShowTipByLanguageId(10692)
                return
            end
            this.order = this.order+1
            table.insert(this.choosedList, {heroId = heroData.dynamicId, position = this.GetPos()})

            this.SetCardsData()
        else
            PopupTipPanel.ShowTipByLanguageId(12555)
        end
    end)

    Util.AddLongPressClick(Util.GetGameObject(_go.transform, "card"), function()
        UIManager.OpenPanel(UIName.RoleInfoPopup, heroData)
    end, 0.5)
end

--计算上阵空余位置 返回最小位置
function this.GetPos()
    local posArray = formationConfig[this.choosedFormationId].pos

    local data = {}
    for i = 1, 9 do
        if heroListGo[i].gameObject.activeSelf then
            table.insert(data,i,i)
        end
    end
    for j = 1, 9 do
        if data[j] == nil and table.keyof(posArray, j) then
            return j
        end
        if LengthOfTable(data) ==9 then
            return 0
        end
    end
end

--计算上阵空余位置 返回所有位置列表
function this.GetPosList()
    local posArray = formationConfig[this.choosedFormationId].pos

    local list = {}
    for j = 1, 9 do
        if not list[j] and table.keyof(posArray, j) then
            table.insert(list,j)
        end
    end
    return list
end

function this.OnPointerDown(Pointgo, data) --按下
    if not this.opView.ChangeFormation then
        return
    end
    local _j = tonumber(string.sub(Pointgo.transform.name, -1))
    if _j == 0 then _j = 10 end
    local heroObj = Util.GetTransform(Pointgo.transform.parent, "Card" .. _j)
    heroObj.transform:SetParent(this.root.transform)
    downTimeStart = Time.realtimeSinceStartup
end

function this.OnPointerUp(Pointgo, data) --抬起
    if not this.opView.ChangeFormation then
        return
    end
    local _j = tonumber(string.sub(Pointgo.transform.name, -1))
    if _j == 0 then _j = 10 end
    Util.Peer(Pointgo.transform, "Pos").transform:SetAsFirstSibling()

    local heroObj = Util.GetTransform(this.gameObject, "Card" .. _j)
    heroObj.transform:SetParent(bgListGo[_j].transform)
    heroObj.transform:SetAsLastSibling()
    if Time.realtimeSinceStartup - downTimeStart < 0.1 and not isDraged then
        if this.opView.ChangeFormation then
            -- 如果是替补 加逻辑
            for i, v in ipairs(this.choosedList) do
                if _j == v.position then
                    table.remove(this.choosedList,i)
                    this.order = this.order - 1
                    dragViewListGo[_j].gameObject:SetActive(false)
                    break
                end
            end
            if _j == 10 then
                if isLockTibu then
                    -- PopupTipPanel.ShowTip("") --todo 等待文本id
                    return
                end
                if this.tibu ~= "" and  this.tibu ~= nil then
                    if not isLockTibu then
                        this.RefreshTibuWarPower(true)
                        this.tibu = ""
                    end
                end
            end
            this.SetCardsData()
            this.OnClickTabBtn(proId)
        end
    end
    isDraged = false
end

function this.OnEndDrag(Pointgo, data) --结束拖动
    if not this.opView.ChangeFormation then
        return
    end

    local _j = tonumber(string.sub(Pointgo.transform.name, -1))
    if _j == 0 then _j = 10 end

    local heroObj = Util.GetGameObject(this.gameObject, "Card" .. _j)
    if data.pointerEnter == nil then --防止拖到屏幕外
        heroObj.transform:DOAnchorPos(Vector3.New(0, 0), 0)
        heroObj.transform:SetParent(bgListGo[_j].transform)
        heroObj.transform:SetAsLastSibling()
        -- Util.Peer(Pointgo.transform, "name"):SetActive(true)
        return
    end
    -- Util.Peer(Pointgo.transform, "name"):SetActive(true)

    local _i = tonumber(string.sub(data.pointerEnter.gameObject.name,-1))
    local nameIn = data.pointerEnter.gameObject.name --进入的UI名
    local _num = string.sub(nameIn,5,-1)
    local itemName = "item".._num

    local heroObj = Util.GetGameObject(this.gameObject,"Card".._j)
    heroObj.transform:DOAnchorPos(Vector3.New(0, 0),0)
    heroObj.transform:SetParent(bgListGo[_j].transform)
    heroObj.transform:SetAsLastSibling()

    if _i == nil then
        _i = tonumber(string.sub(Pointgo.transform.name, -1))
    end
    if _i == 0 then _i = 10 end

    -- 替补切换
    if not this.CheckFormationPosIsValid(_i, this.choosedFormationId) and _j ~= 10 and _i ~= 10 then
        return
    end

    if _j == 10 and _i ~= 10 then
        if nameIn == "DragView".._i then --阵上
            this.OnDragEndHaveInfomation(_i)
        elseif nameIn == "Bg".._i then   --没人
            this.OnDragEndNotHaveInfomation(_i)
            this.order = this.order + 1
        elseif nameIn == "ScrollCycleView" or nameIn == itemName or nameIn == "card" then -- 列表内
            this.SwitchTibuRoleDown()
        end
    else
        if nameIn == "DragView".._i then --有人
            if _i ~= 10 then
                local curData
                local tarData
                for i, v in ipairs(this.choosedList) do
                    if _j == v.position then
                        curData = v.heroId
                    end
                    if _i == v.position then
                        tarData = v.heroId
                    end
                end
                for i, v in ipairs(this.choosedList) do
                    if _j == v.position then
                        this.choosedList[i].heroId = tarData
                    end
                    if _i == v.position then
                        this.choosedList[i].heroId = curData
                    end
                end
            --且是替补
            elseif _i == 10 then
                this.SwitchChooseHero(_j)
            end
        elseif nameIn == "Bg".._i then --没人
            local did
            for i, v in ipairs(this.choosedList) do
                if _j == v.position then
                    did = v.heroId
                    table.remove(this.choosedList,i)
                end
            end
            table.insert(this.choosedList, {heroId = did, position = _i})
        elseif nameIn == "ScrollCycleView" or nameIn == itemName or nameIn == "card" then
            if this.opView.ChangeFormation then
                for i, v in ipairs(this.choosedList) do
                    if _j == v.position then
                        this.order = this.order - 1
                        table.remove(this.choosedList,i)
                        dragViewListGo[_j].gameObject:SetActive(false)
                        break
                    end
                end
            end
        end
    end
    this.line.gameObject:SetActive(false)
    this.SetCardsData()
    this.OnClickTabBtn(proId)
end

function this.OnDrag(Pointgo,data)--拖动中
    if not this.opView.ChangeFormation then
        return
    end
    isDraged = true

    if data.pointerEnter == nil then--拖到屏幕外
        this.line.transform:SetParent(this.roleGrid.transform)
        this.line.gameObject:SetActive(false)
        return
    end

    local _i = tonumber(string.sub(data.pointerEnter.gameObject.name,-1))
    if _i == nil then _i = 0 end

    local nameIn = data.pointerEnter.gameObject.name --进入的UI名   card10 --tibu

    local isA = nameIn == "DragView".._i or nameIn == "Bg".._i or nameIn =="card10"
    if isA and nameIn ~= "card10" then
        if not this.CheckFormationPosIsValid(_i, this.choosedFormationId) then
            this.line.transform:SetParent(this.roleGrid.transform)
            this.line.gameObject:SetActive(false)
        return end
    end

    this.line:SetActive(isA)

    if nameIn == "DragView".._i then
        this.line.transform:SetParent(bgListGo[_i].transform)
        this.line.transform.anchoredPosition = Vector2.New(0, 0)
    elseif nameIn == "Bg".._i then
        this.line.transform:SetParent(bgListGo[_i].transform)
        this.line.transform.anchoredPosition = Vector2.New(0, 0)
    elseif nameIn == "" then
        --替补
    else
        this.line.transform:SetParent(this.roleGrid.transform)
        this.line.gameObject:SetActive(false)
    end
    this.line.transform:SetAsFirstSibling()

    Util.Peer(Pointgo.transform, "name"):SetActive(false)
end

--战力刷新
function this.RefreshPower()
    local newPowerNum = this.formationPower
    RefreshPower(oldPowerNum, newPowerNum)
    oldPowerNum = this.formationPower
end

--设置一键上阵
function this.SetOneKeyGo()
    Log("SetOneKeyGo")
    SoundManager.PlaySound(SoundConfig.Sound_UI_place_army)

    if not this.opView.ChangeFormation then
        PopupTipPanel.ShowTipByLanguageId(12555)
        return
    end

    --获取需要上阵的位置
    local posArr = this.GetPosList()
    if #posArr == 0 then
        PopupTipPanel.ShowTipByLanguageId(10692)
        return
    end

    local heros = HeroManager.GetAllHeroDatas(limitLevel)
    --按战力从大到小排序
    table.sort(heros,function(a,b)
        local aAllProData = HeroManager.CalculateHeroAllProValList(1, a, false)
        local bAllProData = HeroManager.CalculateHeroAllProValList(1, b, false)
        if aAllProData[HeroProType.WarPower] == bAllProData[HeroProType.WarPower] then
            return a.id > b.id
        else
            return aAllProData[HeroProType.WarPower] > bAllProData[HeroProType.WarPower]
        end
    end)

    this.order = 0
    this.choosedList = {}

    local heroData = {}
    local tibuDid = {}
    local tibuPower = 0
    local hero=nil
    if  this.tibu ~= "" and this.tibu ~= nil then
        hero = HeroManager.GetSingleHeroData(this.tibu)
        if hero then
            tibuPower = hero.warPower
            tibuDid = hero.id
            -- LogError(hero.warPower)
        end
    end

    local selectHerosTemp = {}
    local upHeroSidTable = {}
    local idx = 0
    for k, v in ipairs(heros) do
        local heroHp = FormationManager.GetFormationHeroHp(this.curFormationIndex, v.dynamicId)
        if not (heroHp and heroHp <= 0) and not upHeroSidTable[v.id] then
            if v.id ~= tibuDid then
                idx = idx + 1
                if idx > 5 then
                    heroData.id = v.id
                    heroData.dynamicId = v.dynamicId
                    heroData.warPower = v.warPower
                    break
                end
                upHeroSidTable[v.id] = v.id
                table.insert(selectHerosTemp, v)
            end
        end
    end

    -- 新规则排序
    -- 1、防御
    -- 2、高爆
    -- 3、穿甲
    -- 4，辅助
    local isSort = {false, false, false}
    for i = 1, #posArr do
        if posArr[i] >= 1 and posArr[i] <= 3 then
            if not isSort[1] then
                --> 防御》穿甲》爆炸》辅助
                local sortPar = {111, 333, 222, 444}
                table.sort(selectHerosTemp, function(a, b)
                    return sortPar[a.heroConfig.Profession] < sortPar[b.heroConfig.Profession]
                end)
                isSort[1] = true
            end
        end
        if posArr[i] >= 4 and posArr[i] <= 6 then
            if not isSort[2] then
                local sortPar = {333, 222, 111, 444}
                table.sort(selectHerosTemp, function(a, b)
                    return sortPar[a.heroConfig.Profession] < sortPar[b.heroConfig.Profession]
                end)
                isSort[2] = true
            end
        end
        if posArr[i] >= 7 and posArr[i] <= 9 then
            if not isSort[3] then
                local sortPar = {444, 333, 222, 111}
                table.sort(selectHerosTemp, function(a, b)
                    return sortPar[a.heroConfig.Profession] < sortPar[b.heroConfig.Profession]
                end)
                isSort[3] = true
            end
        end

        if #selectHerosTemp > 0 then
            table.insert(this.choosedList, {heroId = selectHerosTemp[1].dynamicId, position=posArr[i]})
            this.order = this.order + 1
            table.remove(selectHerosTemp, 1)
        end
    end

    ------------------------ 替补加入一键上阵 to do 加入权限设置
    if not isLockTibu then
        local isTibu = false
        -- 当前可选的最大上阵人数
        local maxNum = GVM.GetGVValue(GVM.FormationMaxNum)
        if LengthOfTable(this.choosedList) >= maxNum  then
            --检测替补位置是否可以上阵
            isTibu = true
            if this.tibu ~= nil and this.tibu ~= "" and  heroData.dynamicId==this.tibu then
                PopupTipPanel.ShowTipByLanguageId(10692)
                isTibu = false
            end
        end
        for k, v in pairs(this.choosedList) do
            if HeroManager.GetSingleHeroData(v.heroId).id == heroData.id then
                PopupTipPanel.ShowTipByLanguageId(10693)
                isTibu = false
            end
        end
        if  this.tibu ~= nil and this.tibu ~= "" and HeroManager.GetSingleHeroData(this.tibu).id == heroData.id  then
            PopupTipPanel.ShowTipByLanguageId(10693)
            isTibu = false
        end

        if  this.tibu ~= nil and this.tibu ~= "" and next(heroData)~=nil and tibuPower >= heroData.warPower then
            -- PopupTipPanel.ShowTipByLanguageId(10693)
            isTibu = false
        end

        if isTibu  then
            if  next(heroData) ~=nil then
                this.tibu = heroData.dynamicId
            else
                --使用默认替补
                this.tibu = hero.dynamicId
            end
        end
    end
    ------------------------ 替补加入一键上阵 end
    this.SetCardsData()
    this.OnClickTabBtn(proId)
           --设置守护一键上阵
    if  this.opView.ChangeFormation and ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT) then
        NetManager.GetSupportList(function()
            local shouhuData ={}  --守护激活列表
            local data = SupportManager.GetSelectData()   --获取守护列表
            for index, value in ipairs(data) do
                if value.openStatus ~= 0 then --激活
                    -- SupportManager.GetDataById(value.supportId).skillLevel
                    table.insert(shouhuData, value)
                end
            end

            if #shouhuData<=0 then   --没有激活
                return
            end
            table.sort(shouhuData,function(a,b)
                if a.skillLevel == b.skillLevel then
                    return a.supportId > b.supportId
                else
                    return a.skillLevel > b.skillLevel
                end
            end)
            local selectData = shouhuData[1]
                SupportManager.SetFormationSupportId(this.curFormationIndex, selectData.supportId)
                Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnSupportChange)
        end)
    end
        
      --设置先驱一键上阵
      if  this.opView.ChangeFormation and ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT) then
                NetManager.GetAllAdjutantInfo(function ()
                    local xianquData = {}
                    local data = AdjutantManager.GetConfigAdjutants()
                    this.openStatus = {}
                    for i, v in ipairs(data) do
                        local isOpen = false
                        for j, w in ipairs(AdjutantManager.GetAdjutantData().adjutants) do
                            if w.id == v.AdjutantId then
                                isOpen = true
                            end
                        end
                        table.insert(this.openStatus, isOpen)
                    end
                    for index, value in ipairs(data) do
                        if  this.openStatus[index] then
                            table.insert(xianquData, value)
                        end
                    end
                    if #xianquData<=0 then   --没有激活
                        return
                    end
            
                    local alldata = AdjutantManager.GetAdjutantData().adjutants
                    for i = 1, #alldata do
                        if xianquData[i] then
                            if alldata[i].id == xianquData[i].AdjutantId then
                                if xianquData[i].skillLevel == nil then
                                    xianquData[i].skillLevel = 1
                                    xianquData[i].skillLevel = alldata[i].skillLevel
                                else
                                    xianquData[i].skillLevel = alldata[i].skillLevel
                                end
                            end
                        end
                    end
            
            
                    table.sort(xianquData,function(a,b)
                        if a.skillLevel == b.skillLevel then
                            return a.AdjutantId> b.AdjutantId
                        else
                            return a.AdjutantId> b.AdjutantId
                        end
                    end)
                    local selectXqData = xianquData[1]
                    AdjutantManager.SetFormationAdjutantId(this.curFormationIndex, selectXqData.AdjutantId)
                    Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnAdjutantChange)
                end)
      end
end

function this.SetChoosedFormationId(value)
    this.choosedFormationId = value
end

--依据阵型重设chooselist
function this.ResetChooseWithFormationId()
    local posArray = formationConfig[this.choosedFormationId].pos

    for k, v in ipairs(posArray) do
        if this.choosedList and this.choosedList[k] ~= nil then
            this.choosedList[k].position = v
        end
    end
    this.SetCardsData()
end

--检测位置可用性
function this.CheckFormationPosIsValid(Pos, formationID)
    local posArray = formationConfig[formationID].pos
    return table.keyof(posArray, Pos)
end

--修改守护
function this.OnSupportChange()
    local supportId = SupportManager.GetFormationSupportId(this.curFormationIndex)
    local guardIcon = Util.GetGameObject(this.btnGuard, "Icon")
    if supportId == 0 then
        guardIcon:SetActive(false)
    else
        local artifactData = artifactConfig[supportId]
        guardIcon:GetComponent("Image").sprite = Util.LoadSprite(artifactData.Head)
        guardIcon:SetActive(true)
    end
end

--修改先驱
function this.OnAdjutantChange()
    local adjutantId = AdjutantManager.GetFormationAdjutantId(this.curFormationIndex)
    local pioneerIcon = Util.GetGameObject(this.btnPioneer, "Icon")
    if adjutantId == 0 then
        pioneerIcon:SetActive(false)
    else
        local adjutantData = adjutantConfig[adjutantId]
        pioneerIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(adjutantData.Head))
        pioneerIcon:SetActive(true)
    end
end

--[[
-- function FormationPanelV2.OnCVChange()
--     if AircraftCarrierManager.CVInfo then
--         this.cv:SetActive(true)
--         local equipList = AircraftCarrierManager.EquipPlaneDataToChooseList()
--         local maxSlotCnt = AircraftCarrierManager.GetOpenSlotMaxCnt()
--         local frame = Util.GetGameObject(this.cv, "frame")
--         for i = 1, 4 do
--             local slotGo = Util.GetGameObject(frame, "slot" .. tostring(i))
--             local icon = Util.GetGameObject(slotGo, "icon")
--             local lock = Util.GetGameObject(slotGo, "lock")
--             if i <= maxSlotCnt then
--                 lock:SetActive(false)
--                 local equip
--                 for j = 1, #equipList do
--                     if equipList[j].sort == i then
--                         equip = equipList[j]
--                     end
--                 end
--                 if equip then
--                     icon:GetComponent("Image").sprite = SetIcon(equip.cfgId)
--                     icon:SetActive(true)
--                 else
--                     icon:SetActive(false)
--                 end
--             else
--                 lock:SetActive(true)
--                 icon:SetActive(false)
--             end
--         end

--         Util.AddOnceClick(frame, function()
--             UIManager.OpenPanel(UIName.AircraftCarrierSkillSequencePopup)
--         end)
--     else
--         this.cv:SetActive(false)
--     end
-- end
]]

--设置克制图片
function this.UpdateElementIcon()
    local elementIds = TeamInfosToElementIds(this.choosedList)
    SetFormationBuffIcon(Util.GetGameObject(this.btnBattleBuff, "Image"), elementIds)
end

function this.getFormationIcon(id)
    return formationConfig[id].icon
end

--设置阵型图片
function this.SetFormationIcon()
    local FormationId = FormationManager.GetFormationId()
    local str = this.getFormationIcon(FormationId)
    Util.GetGameObject(this.btnFormation, "Image"):GetComponent("Image").sprite = Util.LoadSprite(str)
end

function this.TabAddListen(type)
    if type == tabType.story then
        this.SetSelect(type)
        clickbutton()
        IsJump = false
        this.storyjump = false
        this:OpenPanel(FORMATION_TYPE.STORY, function ()
            this.opView.Init(this)
            this.opView.ChangeFormation = true
        end)
    elseif type == tabType.area then
        if PlayerManager.level < 8 then
            PopupTipPanel.ShowTipByLanguageId(23042)
        else
            this.SetSelect(type)
            clickbutton()
            IsJump = false
            this:OpenPanel(FORMATION_TYPE.ARENA_DEFEND, function ()
                this.opView.Init(this)
                this.opView.ChangeFormation = true
            end)
        end

    elseif type == tabType.area_match then
        if PlayerManager.level < 8 then
            PopupTipPanel.ShowTipByLanguageId(23042)
        else
            this.SetSelect(type)
            clickbutton()
            this:OpenPanel(FORMATION_TYPE.ARENA_TOP_MATCH, function ()
                this.opView.Init(this)
            end)
        end
    elseif type == tabType.tower_god then
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.CLIMB_TOWER) then
            this.SetSelect(type)
            clickbutton()
            this:OpenPanel(FORMATION_TYPE.CLIMB_TOWER, function ()
                this.opView.Init(this)
                this.opView.ChangeFormation = true
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.CLIMB_TOWER))
        end
    -- elseif type == tabType.tower_magic then
    --     local isVisible, isOpen = ClimbTowerManager.CheckEliteModeIsOpen()
    --     if not isOpen then
    --         PopupTipPanel.ShowTip(GetLanguageStrById(23042))
    --         return
    --     end
    --     this.SetSelect(type)
    --     clickbutton()
    --     this:OpenPanel(FORMATION_TYPE.CLIMB_TOWER, function ()
    --         this.opView.Init(this)
    --         this.opView.ChangeFormation = true
    --     end)
    elseif type == tabType.guide_challenge then
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
            if PlayerManager.familyId == 0 then--没有公会
                PopupTipPanel.ShowTip(GetLanguageStrById(10405))
            else
                this.SetSelect(type)
                clickbutton()
                this:OpenPanel(FORMATION_TYPE.GUILD_TRANSCRIPT, function ()
                    this.opView.Init(this)
                    this.opView.ChangeFormation = true
                end)
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.GUILD))
        end
    elseif type == tabType.corruption then
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.PEOPLE_MIRROR) then
            this.SetSelect(type)
            clickbutton()
            this:OpenPanel(FORMATION_TYPE.XUANYUAN_MIRROR, function ()
                this.opView.Init(this)
                this.opView.ChangeFormation = true
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.PEOPLE_MIRROR))
        end
    elseif type == tabType.nightmare then
        if ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.MINSKBATTLE) then
            this.SetSelect(type)
            clickbutton()
            this:OpenPanel(FORMATION_TYPE.GUILD_CAR_DELEAY, function ()
                this.opView.Init(this)
                this.opView.ChangeFormation = true
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.MINSKBATTLE))
        end
    elseif type == tabType.denseFog then
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALAMEIN_WAR) then
            this.SetSelect(type)
            clickbutton()
            this:OpenPanel(FORMATION_TYPE.ALAMEIN_WAR, function ()
                this.opView.Init(this)
                this.opView.ChangeFormation = true
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.ALAMEIN_WAR))
        end
    elseif type == tabType.forget then
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.BLITZ_STRIKE) then
            this.SetSelect(type)
            clickbutton()
            this:OpenPanel(FORMATION_TYPE.BLITZ_STRIKE, function ()
                this.opView.Init(this)
                this.opView.ChangeFormation = true
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.BLITZ_STRIKE))
        end
    elseif type == tabType.broken then
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.Hegemony) then
            this.SetSelect(type)
            clickbutton()
            this:OpenPanel(FORMATION_TYPE.CONTEND_HEGEMONY, function ()
                this.opView.Init(this)
                this.opView.ChangeFormation = true
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.Hegemony))
        end
    elseif type == tabType.crossServer then
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.laddersChallenge) then
            this.SetSelect(type)
            clickbutton()
            this:OpenPanel(FORMATION_TYPE.LADDERSCHALLENGE, function ()
                this.opView.Init(this)
                this.opView.ChangeFormation = true
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.laddersChallenge))
        end
    elseif type == tabType.guide_battle then
        if ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.GUILD_BATTLE) then
            if PlayerManager.familyId == 0 then--没有公会
                PopupTipPanel.ShowTip(GetLanguageStrById(10405))
            else
                this.SetSelect(type)
                clickbutton()
                this:OpenPanel(FORMATION_TYPE.GUILD_DEATHPOS, function ()
                    this.opView.Init(this)
                    this.opView.ChangeFormation = true
                end)
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.GUILD_BATTLE))
        end
    end
end

--- 抽象逻辑 替补相关方法
function this.SetTibuAsDragabel(go,_heroGo)
    --  初始化替补可以拖拽
    local i = 10
    bgListGo[i] = this.substitute --bg
    heroListGo[i ] = _heroGo
    if not dragViewListGo[i] then
        dragViewListGo[i] = SubUIManager.Open(SubUIConfig.DragView, go.transform)
    end
    dragViewListGo[i].gameObject.name = "DragView"..i
    dragViewListGo[i].gameObject:SetActive(true)
    dragViewListGo[i]:SetScrollMouse(false)
    this.trigger[i] = Util.GetEventTriggerListener(dragViewListGo[i].gameObject)
    this.trigger[i].onPointerDown = this.trigger[i].onPointerDown+this.OnPointerDown
    this.trigger[i].onPointerUp = this.trigger[i].onPointerUp+this.OnPointerUp
    this.trigger[i].onEndDrag = this.trigger[i].onEndDrag+this.OnEndDrag
    this.trigger[i].onDrag = this.trigger[i].onDrag+this.OnDrag
    dragViewListGo[i]:SetDragGO(heroListGo[i])
end

-- 有人的时候交换
function this.OnDragEndHaveInfomation(_pos)
    local curData = HeroManager.GetSingleHeroData(this.tibu).dynamicId
    local tarData
    for i, v in ipairs(this.choosedList) do
        if _pos == v.position then
            tarData = HeroManager.GetSingleHeroData(v.heroId)
        end
    end
        this.tibu = tarData.dynamicId
    for i, v in ipairs(this.choosedList) do
        if _pos == v.position then
            this.choosedList[i].heroId = curData
        end
    end
end

-- 没人的时候交换
function this.OnDragEndNotHaveInfomation(_pos)
    if not this.CheckFormationPosIsValid(_pos, this.choosedFormationId) then
        return
    end
    if not isLockTibu then
        table.insert(this.choosedList,
        {heroId = HeroManager.GetSingleHeroData(this.tibu).dynamicId,
         position = _pos})
        this.tibu = ""
    end
end

--交换替补
function this.SwitchChooseHero(_pos)
    if not isLockTibu then
        if this.tibu == "" then  --阵容英雄下阵
            local tarData
            for i, v in ipairs(this.choosedList) do
                if _pos == v.position then
                    tarData = HeroManager.GetSingleHeroData(v.heroId)
                    table.remove(this.choosedList,i)
                end
            end
            this.tibu = tarData.dynamicId
            this.order = this.order - 1
        else
            local curData = HeroManager.GetSingleHeroData(this.tibu).dynamicId
            local tarData
            for i, v in ipairs(this.choosedList) do
                if _pos == v.position then
                    tarData = HeroManager.GetSingleHeroData(v.heroId)
                end
            end
                this.tibu = tarData.dynamicId
            for i, v in ipairs(this.choosedList) do
                if _pos == v.position then
                    this.choosedList[i].heroId = curData
                end
            end
         end
    end
end

--队列英雄下场
function this.SwitchHeroRoleDown()
    if not isLockTibu then
        this.RefreshTibuWarPower(true)
        this.tibu = ""
    end
end

--替补下场
function this.SwitchTibuRoleDown()
    if not isLockTibu then
        this.RefreshTibuWarPower(true)
        this.tibu = ""
    end
end

function this.RefreshTibuWarPower(isDown)
    tempPowerNum = this.formationPower
    local heroData = HeroManager.GetSingleHeroData(this.tibu)
    local allHeroTeamAddProVal = HeroManager.GetAllHeroTeamAddProVal(this.choosedList,heroData.dynamicId)
    this.CalculateAllHeroPower(heroData,allHeroTeamAddProVal)
    local newPowerNum = this.formationPower
    if isDown then
        RefreshPower(newPowerNum,tempPowerNum)
    else
        RefreshPower(tempPowerNum, newPowerNum)
    end
end

function this.IsTibuLock()
    local lockParam = globalSystemConfig[108].OpenRules
    if lockParam ~= nil then
        if PlayerManager.level >= lockParam[2] then
            return false
        end
        return true
    else
        return true
    end
end

--设置外援是否解锁 位置样式
function this.SetTibuLock()
    if isLockTibu then
        this.btnGuard.transform.anchoredPosition = poslist.befor_btnGuard
        this.btnPioneer.transform.anchoredPosition = poslist.befor_btnPioneer
    else
        this.btnGuard.transform.anchoredPosition = poslist.aft_btnGuard
        this.btnPioneer.transform.anchoredPosition = poslist.aft_btnPioneer
    end

    this.subLock:SetActive(isLockTibu)
    this.substitute:SetActive(not isLockTibu)
    this.subAdd:SetActive(not isLockTibu)
    tibuGo:SetActive(not isLockTibu)
end

--拖拽读取id
function this.GetNumber(str)
    local str = string.gsub(str,"%a","")
    local num = tonumber(str)
    return num
end

--设置基因
function this.SetLeadGene()
    this.btnLeadGene:SetActive(ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER))
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER) then
        return
    end
    local func = function ()
        for i = 1, 4 do
            local gene = this.btnLeadGene.transform:GetChild(i-1)
            local add = Util.GetGameObject(gene, "add")
            local lock = Util.GetGameObject(gene, "lock")
            local mask = Util.GetGameObject(gene, "mask")
            local icon = Util.GetGameObject(gene, "mask/icon"):GetComponent("Image")
            local level = Util.GetGameObject(gene, "level"):GetComponent("Image")
    
            local data
            for j = 1, #AircraftCarrierManager.LeadData.skill do
                if AircraftCarrierManager.LeadData.skill[j].sort == i then
                    data = AircraftCarrierManager.LeadData.skill[j]
                end
            end
            if i > AircraftCarrierManager.GetOpenSlotMaxCnt() then
                lock:SetActive(true)
                add:SetActive(false)
                mask:SetActive(false)
                level.gameObject:SetActive(false)
            else
                lock:SetActive(false)
                if data then
                    add:SetActive(false)
                    mask:SetActive(true)
                    level.gameObject:SetActive(true)
                    local config = AircraftCarrierManager.GetSkillLvImgForId(data.cfgId)
                    icon.sprite = SetIcon(data.cfgId)
                    level.sprite = Util.LoadSprite(config.lvImg)
                else
                    add:SetActive(true)
                    mask:SetActive(false)
                    level.gameObject:SetActive(false)
                end
            end
        end
    end
    if not AircraftCarrierManager.LeadData then
        AircraftCarrierManager.GetLeadData(function ()
            func()
        end)
    else
        func()
    end
end

--- 抽象逻辑 替补相关方法 end
return FormationPanelV2

