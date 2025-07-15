require("Base/BasePanel")
FormationSetPanel = Inherit(BasePanel)

local proId = 0--0 全部  1 火 2风 3 水 4 地  5 光 6 暗
local funFormationId = 1--1 主线阵容 5 无尽副本  2 兽潮来袭 3竞技进攻 4 竞技防守     6 公会进攻 7  公会防守

local needRank = {
    [1] = {Id = 2,Name = GetLanguageStrById(10674), FormationType = FormationTypeDef.FORMATION_NORMAL,Weight = 1},
    [2] = {Id = 46,Name = GetLanguageStrById(10694), FormationType = FormationTypeDef.FORMATION_ENDLESS_MAP,Weight = 2},
    --[3] = {Id = 44,Name = "锁妖阵容", FormationType = FormationTypeDef.FORMATION_NORMAL,Weight=3},
    [3] = {Id = 8, Name = GetLanguageStrById(10695), FormationType = FormationTypeDef.FORMATION_ARENA_ATTACK,Weight = 4},
    [4] = {Id = 8, Name = GetLanguageStrById(10696), FormationType = FormationTypeDef.FORMATION_ARENA_DEFEND,Weight = 5},
    [5] = {Id = 4, Name = GetLanguageStrById(10697), FormationType = FormationTypeDef.FORMATION_GUILD_FIGHT_ATTACK,Weight = 6},
    [6] = {Id = 4, Name = GetLanguageStrById(10698), FormationType = FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND,Weight = 7},
    [7] = {Id= 64, Name = GetLanguageStrById(10699), FormationType = FormationTypeDef.EXPEDITION,Weight = 8},
    --[9] = {Id = FUNCTION_OPEN_TYPE.GUILD_BOSS, Name = "公会Boss", FormationType = FormationTypeDef.FORMATION_NORMAL,Weight = 9},
}


local funForMationIds = {}
local funLockStateTabs = {}
local tarHero = {}
local teamHero = {}
local dieTeamHero = {}
local heroProTabs = {}
local funFormationTabs = {}
local isFirstOpen = true
local roleDatas
local curClickNum = 0
local isChange = false
--初始化组件（用于子类重写）
function FormationSetPanel:InitComponent()
    self.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    self.elementHelpBtn=Util.GetGameObject(self.gameObject,"elementHelpBtn")
    self.cardPre = Util.GetGameObject(self.gameObject, "card")
    for i = 1, 6 do
        heroProTabs[i] = Util.GetGameObject(self.transform, "heroProTabs/grid/Btn" .. i)
    end
    self.heroProTabsSelectBtn = Util.GetGameObject(self.gameObject, "heroProTabs/selectBtn")
    funFormationTabs = {}
    for i = 1, #needRank do
        funFormationTabs[i] = Util.GetGameObject(self.transform, "funFormationTabs/rect/grid/Btn ("..i..")")
        funFormationTabs[i]:SetActive(false)
    end
    self.funFormationTabsSelectBtn = Util.GetGameObject(self.gameObject, "funFormationTabs/selectBtn")
    self.formationSureBtn = Util.GetGameObject(self.gameObject, "formationSureBtn")

    self.ScrollBar = Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    local v2 = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.transform, "scroll").transform,
            self.cardPre, self.ScrollBar, Vector2.New(-v2.x*2, -v2.y*2), 1, 5, Vector2.New(19.32,15))
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1
    self.UpRoot = Util.GetGameObject(self.gameObject, "UpRoot")
    self.ElementalResonanceView = SubUIManager.Open(SubUIConfig.ElementalResonanceView, self.gameObject.transform)
    self.ElementalResonanceView.transform:SetParent(self.UpRoot.transform)
    self.ElementalResonanceView.transform.localScale = Vector3.one
    self.ElementalResonanceView.transform.localPosition=Vector3.zero;
end

--绑定事件（用于子类重写）
function FormationSetPanel:BindEvent()


    Util.AddClick(self.BtnBack, function()
        self:FormationSureBtnClick()
        self:ClosePanel()
    end)

    --元素克制帮助按钮
    Util.AddClick(self.elementHelpBtn,function()
        UIManager.OpenPanel(UIName.ElementRestraintPopup)
    end)
    for i = 1, 6 do
        Util.AddClick(heroProTabs[i], function()
            if i == proId then
                proId=ProIdConst.All
            else
                proId=i
            end
            self:GetCurSortHeroListData()
        end)
    end
    for i = 1, #needRank do
        Util.AddClick(funFormationTabs[i], function()
            if funFormationId ~= i then
                self:FormationSureBtnClick()
                if funLockStateTabs[i] then
                    funFormationId=i
                    self:GetCurFunForMationHeroListData()
                else
                    PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(needRank[i].Id))
                end
            end
        end)
    end
    Util.AddClick(self.formationSureBtn, function()
        self:FormationSureBtnClick()
    end)
end

--添加事件监听（用于子类重写）
function FormationSetPanel:AddListener()

end

--移除事件监听（用于子类重写）
function FormationSetPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function FormationSetPanel:OnOpen(_funFormationId)

    NetManager.RequestAllHeroHp()
    self.ElementalResonanceView:OnOpen({ sortOrder = self.sortingOrder})
    if _funFormationId then funFormationId = _funFormationId else  funFormationId = 1 end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FormationSetPanel:OnShow()

    self:InitNeedRanking()
    for i = 1, #funForMationIds do
        if needRank[i].FormationType == funFormationId then
            funFormationId = i
        end
    end
    funLockStateTabs = {}
    for i = 1, #needRank do
        funFormationTabs[i]:SetActive(true)
        funLockStateTabs[i] = needRank[i].isOpen
        Util.GetGameObject(funFormationTabs[i].transform, "huiImage"):SetActive(not needRank[i].isOpen)
        Util.GetGameObject(funFormationTabs[i].transform, "Text"):GetComponent("Text").text = needRank[i].Name
    end
  
    --- 隐藏第三个
    --funFormationTabs[3].gameObject:SetActive(false)

    isFirstOpen=true
    self:GetCurFunForMationHeroListData()
end
function FormationSetPanel:GetCurFunForMationHeroListData()
    isChange = false
    self:SetHeroProSelectBtn(1)
    --1 主线阵容  2 兽潮来袭  3 竞技进攻 4 竞技防守
    self:GetFormationHeroIdsByForMId(funForMationIds[funFormationId])
    proId = ProIdConst.All
    self:GetCurSortHeroListData()
end
function FormationSetPanel:GetFormationHeroIdsByForMId(forMationId)
    teamHero = {}
    local teamHeroInfos = FormationManager.GetFormationByID(forMationId).teamHeroInfos
    --无尽副本队伍检测是否阵亡人员
    if forMationId == FormationTypeDef.FORMATION_ENDLESS_MAP then
        teamHeroInfos = EndLessMapManager.RoleListFormationNewMapTeam()
    end
    for i = 1, #teamHeroInfos do
        local info = {}
        info.index = teamHeroInfos[i].position
        info.go = nil
        teamHero[teamHeroInfos[i].heroId] = info
    end
    curClickNum = #teamHeroInfos
    self.ElementalResonanceView:SetElementalPropertyTextColor()
    self.ElementalResonanceView:GetElementalType(FormationManager.GetFormationByID(forMationId),1)
    self.ElementalResonanceView:SetPosition(1)
end
--获取当前英雄列表
function FormationSetPanel:GetCurSortHeroListData()
    self:SetHeroProSelectBtn(2)
    dieTeamHero = {}
    local limitLevel = needRank[funFormationId].Id == 46 and EndLessMapManager.limiteLevel or 0
    if needRank[funFormationId].Id == 64 then limitLevel = 20 end
    if proId == ProIdConst.All then
        tarHero = HeroManager.GetAllHeroDatas(limitLevel)
    else
        tarHero = HeroManager.GetHeroDataByProperty(proId, limitLevel)
    end
    for i = 1, #tarHero do
        local heroHp = FormationManager.GetFormationHeroHp(funForMationIds[funFormationId], tarHero[i].dynamicId)
        if heroHp then
            if heroHp <= 0 then
                dieTeamHero[tarHero[i].dynamicId] = tarHero[i].dynamicId
            end
        end
    end
   
    self:SetRoleList(tarHero)
end
--设置英雄列表数据
function FormationSetPanel:SetRoleList(_roleDatas)
    roleDatas=_roleDatas
    self:SortHeroDatas(_roleDatas)
    self.ScrollView:SetData(_roleDatas, function (index, go)
        if isFirstOpen then
            go.gameObject:SetActive(false)
        end
        self:SingleHeroDataShow(go, roleDatas[index])
    end)
    if isFirstOpen then
        self.ScrollView:ForeachItemGO(function (index, go)
            Timer.New(function ()
                go.gameObject:SetActive(true)
                PlayUIAnim(go.gameObject)
            end, 0.03*(index-1)):Start()
        end)
        isFirstOpen = false
    end
end
function FormationSetPanel:SingleHeroDataShow(_go,_heroData)
    local heroData = _heroData
    Util.GetGameObject(_go.transform, "card/bg"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroCardQuantityImage[heroData.heroConfig.Quality])
    Util.GetGameObject(_go.transform, "card/lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(_go.transform, "card/name"):GetComponent("Text").text = GetLanguageStrById(heroData.heroConfig.ReadingName)
    Util.GetGameObject(_go.transform, "card/icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.painting)
    Util.GetGameObject(_go.transform, "card/pos/icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)
    Util.GetGameObject(_go.transform, "card/pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    Util.GetGameObject(_go.transform, "card/redPoint"):SetActive(false)
    SetHeroStars(Util.GetGameObject(_go.transform, "star"), heroData.star)
    local choosed = Util.GetGameObject(_go.transform, "card/sign/choosed")
    if teamHero[heroData.dynamicId] then
        choosed:SetActive(true)
        Util.GetGameObject(choosed.transform, "sortNum"):GetComponent("Text").text = teamHero[heroData.dynamicId].index
        teamHero[heroData.dynamicId].go = Util.GetGameObject(choosed.transform, "sortNum"):GetComponent("Text")
    else
        choosed:SetActive(false)
    end

    --剩余血量 无尽副本才显示
    local hpExp = Util.GetGameObject(_go, "card/dieImage")
    local heroHp = FormationManager.GetFormationHeroHp(funForMationIds[funFormationId], heroData.dynamicId)
    self:SetHeroBlood(hpExp, heroHp)

    local card = Util.GetGameObject(_go.transform, "card")
    Util.AddOnceClick(hpExp, function()
        PopupTipPanel.ShowTipByLanguageId(10672)
    end)
    Util.AddOnceClick(card, function()
        if teamHero[heroData.dynamicId] then
            choosed:SetActive(false)
            curClickNum = teamHero[heroData.dynamicId].index
            teamHero[heroData.dynamicId] = nil
            for i, v in pairs(teamHero) do
                if v.index - curClickNum > 0 then
                    teamHero[i].index = v.index - 1
                    teamHero[i].go.text = teamHero[i].index
                end
            end
            curClickNum = LengthOfTable(teamHero)
            self:RefreshElementalResonanceView()
            isChange = true
            return
        end
        local maxNum = ActTimeCtrlManager.MaxArmyNum()
        if LengthOfTable(teamHero) >= maxNum then
            if maxNum < 5 then
                PopupTipPanel.ShowTip(ActTimeCtrlManager.NextArmCondition())
            end
            return
        end
        choosed:SetActive(true)
        curClickNum = curClickNum + 1
        local info = {}
        info.index = curClickNum
        info.go = Util.GetGameObject(choosed.transform, "sortNum"):GetComponent("Text")
        Util.GetGameObject(choosed.transform, "sortNum"):GetComponent("Text").text = info.index
        teamHero[heroData.dynamicId] = info
        self:RefreshElementalResonanceView()
        isChange = true
    end)
    Util.AddLongPressClick(card, function()
            UIManager.OpenPanel(UIName.RoleInfoPopup, heroData)
    end, 0.5)
end
-- 设置妖灵师血量
function FormationSetPanel:SetHeroBlood(hpExp, heroHp)
    if heroHp then
        hpExp:SetActive( heroHp <= 0)
    else
        hpExp:SetActive(false)
    end
end
function FormationSetPanel:SetHeroProSelectBtn(index)
    if index == 1 then
        self.funFormationTabsSelectBtn.transform:SetParent(funFormationTabs[funFormationId].transform)
        self.funFormationTabsSelectBtn.transform.localScale = Vector3.one
        self.funFormationTabsSelectBtn.transform.localPosition=Vector3.zero;
        Util.GetGameObject(self.funFormationTabsSelectBtn.transform, "Text"):GetComponent("Text").text = Util.GetGameObject(funFormationTabs[funFormationId].transform, "Text"):GetComponent("Text").text
    elseif index == 2 then
        self.heroProTabsSelectBtn:SetActive(proId ~= ProIdConst.All)
        if proId ~= ProIdConst.All then
            self.heroProTabsSelectBtn.transform.localPosition = heroProTabs[proId].transform.localPosition
        end
    end
end
function FormationSetPanel:SortHeroDatas(_heroDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if (teamHero[a.dynamicId] and teamHero[b.dynamicId]) or
                (not teamHero[a.dynamicId] and not teamHero[b.dynamicId])
        then
            if (dieTeamHero[a.dynamicId] and dieTeamHero[b.dynamicId]) or
                    (not dieTeamHero[a.dynamicId] and not dieTeamHero[b.dynamicId])
            then
                if a.heroConfig.Quality ==b.heroConfig.Quality then--Natural
                    if a.star == b.star then
                        if a.lv == b.lv then
                            return a.heroConfig.Id < b.heroConfig.Id
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
                return  not dieTeamHero[a.dynamicId] and  dieTeamHero[b.dynamicId]
            end
        else
            return teamHero[a.dynamicId] and not teamHero[b.dynamicId]
        end
    end)
end
function FormationSetPanel:FormationSureBtnClick()
    if isChange then
        local selectHeroIdListData = {}
        local index = 1
        for k, v in pairs(teamHero) do
            local singleData = {}
            singleData.heroId =k
            singleData.position = v.index
            index = index + 1
            table.insert(selectHeroIdListData, singleData)
        end
        table.sort(selectHeroIdListData, function(a,b)
           return a.position<b.position
        end)
        local limitNum = 1      -- 数量限制
        if index > limitNum then
             -- 核实关卡是否需要替补 参量偏移bug
            FormationManager.RefreshFormation(funForMationIds[funFormationId], selectHeroIdListData,"", FormationManager.formationList[funForMationIds[funFormationId]].teamPokemonInfos)
            PopupTipPanel.ShowTipByLanguageId(10700)
        else
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), limitNum))
        end
        -- 无尽副本中换人刷新数据
        EndLessMapManager.RefershMapTeam()
    end
end

function FormationSetPanel:RefreshElementalResonanceView()
    local selectHeroIdListData = {}
    local index = 1
    for k, v in pairs(teamHero) do
        local singleData = {}
        singleData.heroId =k
        singleData.position = v.index
        index = index + 1
        table.insert(selectHeroIdListData, singleData)
    end
    local forMationTeamData = {}
    forMationTeamData.teamHeroInfos = {}
    for i = #selectHeroIdListData, 1,-1 do
        table.insert(forMationTeamData.teamHeroInfos, selectHeroIdListData[i])
    end
    self.ElementalResonanceView:SetElementalPropertyTextColor()
    self.ElementalResonanceView:GetElementalType(forMationTeamData,1)
    self.ElementalResonanceView:SetPosition(1)
end
--界面关闭时调用（用于子类重写）
function FormationSetPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function FormationSetPanel:OnDestroy()

    SubUIManager.Close(self.ElementalResonanceView)
end


--初始化需要显示的排行
function  FormationSetPanel:InitNeedRanking()
    funForMationIds = {}
    for i = 1, #needRank do
        if needRank[i].Id == 9 or needRank[i].Id == 46 or needRank[i].Id == FUNCTION_OPEN_TYPE.GUILD_BOSS then
            needRank[i].isOpen = ActTimeCtrlManager.IsQualifiled(needRank[i].Id)
        else
            needRank[i].isOpen = ActTimeCtrlManager.SingleFuncState(needRank[i].Id)
        end
    end
    table.sort(needRank,function(a,b)
        if a.isOpen and b.isOpen
                or not a.isOpen and not b.isOpen then
            return a.Weight<b.Weight
        else
            return a.isOpen and not b.isOpen
        end
    end)
    for i = 1, #needRank do
        
        table.insert(funForMationIds,needRank[i].FormationType)
    end

end

return FormationSetPanel