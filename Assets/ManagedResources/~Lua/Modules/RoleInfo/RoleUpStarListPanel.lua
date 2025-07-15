require("Base/BasePanel")
RoleUpStarListPanel = Inherit(BasePanel)
local this = RoleUpStarListPanel
local curSelectHeroList = {}
local heroDataList = {}
local curNeedRoleNum
local openThisPanel
local curHeroData = {}
local jumpSelectHeroData = {} --跳转选择的英雄信息
local selectList = {}
local isAssemblyHero = false

--初始化组件（用于子类重写）
function RoleUpStarListPanel:InitComponent()
	this.Mask = Util.GetGameObject(self.transform, "Mask")
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.BtnSure = Util.GetGameObject(self.transform, "bg/btnSure")
    this.btnAutoSelect = Util.GetGameObject(self.transform, "bg/btnAutoSelect")
    this.cardPre = Util.GetGameObject(self.gameObject, "item")
    --this.grid = Util.GetGameObject(self.gameObject, "scroll/grid")
    this.desText = Util.GetGameObject(self.gameObject, "bg/desText"):GetComponent("Text")
    this.numText = Util.GetGameObject(self.gameObject, "bg/numText"):GetComponent("Text")

    this.Scrollbar = Util.GetGameObject(self.gameObject, "bg/Scrollbar"):GetComponent("Scrollbar")
    local scroll = Util.GetGameObject(self.gameObject, "bg/scroll").transform
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,scroll,
            this.cardPre, this.Scrollbar, Vector2.New(scroll.rect.width, scroll.rect.height), 1, 5, Vector2.New(5,5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1

    this.goBtn = Util.GetGameObject(self.gameObject, "bg/goBtn")--跳转
end

--绑定事件（用于子类重写）
function RoleUpStarListPanel:BindEvent()
    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.Mask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BtnSure, function()
        self:ClosePanel()
        if LengthOfTable(curSelectHeroList) < 1 then
            return
        end
        local strHero = {}
        local str
        for index, value in pairs(curSelectHeroList) do
            if value.heroConfig.HeroValue == 1 then
                if str == nil then
                    str = GetLanguageStrById(value.heroConfig.ReadingName)
                    table.insert(strHero, value.heroConfig.Id)
                else
                    local state = true
                    for i, v in ipairs(strHero) do
                        if value.heroConfig.Id == v then
                            state = false
                        end
                    end
                    if state then
                        str = str .. "," .. GetLanguageStrById(value.heroConfig.ReadingName)
                    end
                end
            end
        end

        if str == nil then
            if not isAssemblyHero then
                openThisPanel.UpdateUpStarPosHeroData(curSelectHeroList)
            else
                openThisPanel.ChangeCurHero(curSelectHeroList)
            end
        else
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Currency, string.format(GetLanguageStrById(50173), str),function()
                openThisPanel.UpdateUpStarPosHeroData(curSelectHeroList)
            end)
        end
    end)
    Util.AddClick(this.btnAutoSelect, function()
        self:AutoSelectHero()
    end)
    Util.AddClick(this.goBtn, function()
        self:ClosePanel()
        if curHeroData then
            local id = curHeroData.id
            if id == nil then id = curHeroData.Id end--有的大写有的小写
            UIManager.OpenPanel(UIName.JumpSelectPopup, true, jumpSelectHeroData.RankupConsumeMaterial[3], jumpSelectHeroData, id)
        else
            UIManager.OpenPanel(UIName.AssemblePanel, jumpSelectHeroData)
        end
    end)
end

--添加事件监听（用于子类重写）
function RoleUpStarListPanel:AddListener()
end

--移除事件监听（用于子类重写）
function RoleUpStarListPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）参数1 显示的herolist     2 3 升当前星的规则     4 打开RoleUpStarListPanel的界面
function RoleUpStarListPanel:OnOpen(_heroDataList, HeroRankupGroupData, RankupConsumeMaterialData, _openThisPanel, _curSelectHeroList, _curHeroData, general, strs, assemblyHero)
    openThisPanel = _openThisPanel
    curSelectHeroList = {}
    if HeroRankupGroupData then
        if HeroRankupGroupData.IsId ~= 0 then
            jumpSelectHeroData = {
                id = HeroRankupGroupData.IsId,
                data = ConfigManager.GetConfigData(ConfigName.HeroConfig, HeroRankupGroupData.IsId),
                RankupConsumeMaterial = RankupConsumeMaterialData
            }
        else
            jumpSelectHeroData = {
                RankupConsumeMaterial = RankupConsumeMaterialData
            }
        end
    end
    isAssemblyHero = assemblyHero
    if _curSelectHeroList ~= nil then
        for i = 1, #_curSelectHeroList do
            curSelectHeroList[_curSelectHeroList[i]] = _curSelectHeroList[i]
        end
    end
    curHeroData = _curHeroData
    heroDataList = _heroDataList
    this.generalData = nil
    if general then
        this.generalData = general
    end
    this.HeroSortData(heroDataList)
    for i, v in pairs(heroDataList) do
        for n, w in pairs(FormationManager.formationList) do
            if HeroManager.heroResolveLicence[n] then
                for m = 1, #w.teamHeroInfos do
                    if v.dynamicId == w.teamHeroInfos[m].heroId then
                        local isFormationStr = HeroManager.GetHeroFormationStr2(n)
                        v.isFormation = isFormationStr
                    end
                end
            end
        end
    end

    this.ScrollView:SetData(heroDataList, function (index, go)
        this.OnShowSingleCardData(go, heroDataList[index])
    end)

    this.goBtn:SetActive(#heroDataList < 1)
    this.BtnSure:SetActive(#heroDataList > 0)
    this.btnAutoSelect:SetActive(#heroDataList > 0)

    this:SetText(_curHeroData,HeroRankupGroupData,RankupConsumeMaterialData,strs)
end

function this:SetText(_curHeroData, HeroRankupGroupData, RankupConsumeMaterialData, strs)
    curNeedRoleNum = 1
    local str
    if _curHeroData ~= nil then
        str = _curHeroData.heroConfig and GetLanguageStrById(_curHeroData.heroConfig.ReadingName) or GetLanguageStrById(_curHeroData.ReadingName)
    end
    if HeroRankupGroupData ~= nil and RankupConsumeMaterialData ~= nil then
    curNeedRoleNum = RankupConsumeMaterialData[4]
        str = ""
        if HeroRankupGroupData.Issame == 1 then
            str = HeroRankupGroupData.StarLimit .. GetLanguageStrById(11868)
        else
            if HeroRankupGroupData.IsId ~= 0 then
                str = HeroRankupGroupData.StarLimit .. GetLanguageStrById(11869) .. GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.HeroConfig,HeroRankupGroupData.IsId).ReadingName)
            else
                if HeroRankupGroupData.IsSameClan == 0 then
                    str = HeroRankupGroupData.StarLimit .. GetLanguageStrById(11870)
                else
                    str = HeroRankupGroupData.StarLimit .. GetLanguageStrById(11871)
                end
            end
        end
        this.desText.text = string.format(GetLanguageStrById(11872),curNeedRoleNum,str)--HeroRankupGroupData.Name)
        this.numText.text = string.format("(%s/%s)",LengthOfTable(curSelectHeroList),curNeedRoleNum)
    else
        str = ""
        if strs ~= nil then
            if curHeroData then
                local id = 0
                if curHeroData.dynamicId ~= nil then
                    id = curHeroData.id
                else
                    id = curHeroData.Id
                end

                local data = ConfigManager.GetConfigData(ConfigName.HeroConfig,id)
                str = strs..string.format(GetLanguageStrById(23123),data.Star,GetLanguageStrById(data.ReadingName))
            else
                str = strs .. GetLanguageStrById(12736)
            end
        else
            if curHeroData then

                local id = 0
                if curHeroData.dynamicId ~= nil then
                    id = curHeroData.id
                else
                    id = curHeroData.Id
                end

                local data = ConfigManager.GetConfigData(ConfigName.HeroConfig,id)
                str = string.format(GetLanguageStrById(23123),data.Star,GetLanguageStrById(data.ReadingName))
            else
                str = GetLanguageStrById(12736)
            end
        end
        this.desText.text = string.format(GetLanguageStrById(11872),1,str)--HeroRankupGroupData.Name)
        this.numText.text = string.format("(%s/%s)",LengthOfTable(curSelectHeroList),1)
    end
end

--[[
function this.OnClickEnterHero(go,heroData,type)
    if type == 1 then
        if #curSelectHeroList >= curNeedRoleNum then
            PopupTipPanel.ShowTipByLanguageId(10660)
            return
        else
            table.insert(curSelectHeroList,heroData)
        end
    elseif type == 2 then
        for i = 1, #curSelectHeroList do
            if heroData.dynamicId == curSelectHeroList[i].dynamicId then
                table.remove(curSelectHeroList,i)
                break
            end
        end
    end
    this.OnShowSingleCardData(go,heroData,type)
    this.numText.text = string.format("%s/%s",#curSelectHeroList,curNeedRoleNum)
end
]]

function this.OnShowSingleCardData(go, heroData)--isSelect 1选择  2 没选择
    local choosed = Util.GetGameObject(go.transform, "choosed")
    local bg = Util.GetGameObject(go.transform, "bg")
    choosed:SetActive(false)
    bg:SetActive(false)
    if curSelectHeroList[heroData.dynamicId] then
        curSelectHeroList[heroData.dynamicId] = heroData
        choosed:SetActive(true)
        bg:SetActive(true)
    end
    Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go.transform, "lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    Util.GetGameObject(go.transform, "proBG"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    local formationMask = Util.GetGameObject(go.transform, "formationMask")
    local upImg = Util.GetGameObject(go.transform, "formationMask/formationImage/upImage")

    local teamIdList = HeroManager.GetAllFormationByHeroId(heroData.dynamicId)
    formationMask:SetActive(#teamIdList > 0 or heroData.lockState == 1)
    upImg:SetActive(#teamIdList > 0)
    
    Util.GetGameObject(go.transform, "lockImage"):SetActive(heroData.lockState == 1)
    if this.generalData ~= nil then
        Util.GetGameObject(go.transform, "noumenon"):SetActive(false)
    else
        Util.GetGameObject(go.transform, "noumenon"):SetActive(heroData.id == curHeroData.id)
    end
    local starGrid = Util.GetGameObject(go.transform, "star")
    SetHeroStars(starGrid,  heroData.star)
    local cardBtn = Util.GetGameObject(go.transform, "icon")
    Util.AddLongPressClick(cardBtn, function ()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroData.id, heroData.star)
    end, 0.5)
    Util.AddOnceClick(cardBtn, function()
        if heroData.lockState == 1 then
            MsgPanel.ShowTwo(GetLanguageStrById(11790), nil, function()
                NetManager.HeroLockEvent(heroData.dynamicId,0,function ()
                    PopupTipPanel.ShowTipByLanguageId(11791)
                    HeroManager.UpdateSingleHeroLockState(heroData.dynamicId,0)
                    this.HeroSortData(heroDataList)
                    this.ScrollView:SetData(heroDataList, function (index, go)
                        this.OnShowSingleCardData(go, heroDataList[index])
                    end)
                    --lockMask:SetActive(false)
                end)
            end)
            --PopupTipPanel.ShowTipByLanguageId(11776)
            return
        end

        if curSelectHeroList[heroData.dynamicId] then
            bg:SetActive(false)
            choosed:SetActive(false)
            curSelectHeroList[heroData.dynamicId] = nil
            this.numText.text = string.format("(%s/%s)", LengthOfTable(curSelectHeroList), curNeedRoleNum)
            return
        end
        if LengthOfTable(curSelectHeroList) >= curNeedRoleNum then
            PopupTipPanel.ShowTipByLanguageId(10660)
            return
        end
        curSelectHeroList[heroData.dynamicId] = heroData
        choosed:SetActive(true)
        bg:SetActive(true)

        this.numText.text = string.format("(%s/%s)",LengthOfTable(curSelectHeroList), curNeedRoleNum)
    end)

    Util.AddOnceClick(formationMask, function()
         if #teamIdList > 0 then
            local teamIdList = HeroManager.GetAllFormationByHeroId(heroData.dynamicId)
            local name = ""
            for k, v in pairs(teamIdList)do
                local formationName = FormationManager.MakeAEmptyTeam(v)
                name = name..formationName.teamName
                if k ~= #teamIdList then
                    name = name .. "、"
                end

                if --[[v == FormationTypeDef.FORMATION_DREAMLAND or v == FormationTypeDef.FORMATION_AoLiaoer or]] v == FormationTypeDef.DEFENSE_TRAINING then
                    PopupTipPanel.ShowTip(string.format(GetLanguageStrById(50153), name))
                    return
                end
            end

            -- 复位角色的状态
            MsgPanel.ShowTwo(string.format(GetLanguageStrById(22704), name), nil, function()
                for i = 1,#teamIdList do
                    local teamId = HeroManager.GetFormationByHeroId(heroData.dynamicId)

                    local formationName = FormationManager.MakeAEmptyTeam(teamId)
                    if teamId then
                        local teamData = FormationManager.GetFormationByID(teamId)
                        if LengthOfTable(teamData.teamHeroInfos) <= 1 then
                            PopupTipPanel.ShowTipByLanguageId(23118)
                        else
                            for k,v in pairs(teamData.teamHeroInfos)do
                                if v.heroId == heroData.dynamicId then
                                    table.removebyvalue(teamData.teamHeroInfos,v)
                                    break
                                end
                            end
                             -- 核实关卡是否需要替补 参量偏移bug
                            FormationManager.RefreshFormation(teamId, teamData.teamHeroInfos,"",
                            {supportId = SupportManager.GetFormationSupportId(teamId),
                            adjutantId = AdjutantManager.GetFormationAdjutantId(teamId)},
                            nil,
                            teamData.formationId)
        
                            PopupTipPanel.ShowTipByLanguageId(10713)
                        end
                    end
                end
                local teamId = HeroManager.GetFormationByHeroId(heroData.dynamicId)
                if teamId then
                    formationMask:SetActive(true)
                else
                    formationMask:SetActive(false)

                end
            end)
        end

        -- if heroData.isFormation ~= "" then
        --     PopupTipPanel.ShowTip( heroData.isFormation)
        --     return
        -- end
        -- if heroData.lockState == 1 then
        --     PopupTipPanel.ShowTipByLanguageId(11776)
        --     return
        -- end
    end)
end

function this.HeroSortData(heroData)
    table.sort(heroData, function(a, b)
        if a.isFormation == "" and b.isFormation == "" or a.isFormation ~= "" and b.isFormation ~= "" then
            if a.lockState == b.lockState then
                --if a.id == b.id then
                --    if a.lv == b.lv then
                --        return a.id > b.id
                --    else
                --        return a.lv < b.lv
                --    end
                --else
                --    return a.id > b.id
                --end
                if this.generalData ~= nil then
                    if a.heroConfig.Star == b.heroConfig.Star then
                        if a.lv == b.lv then
                            return a.id > b.id
                        else
                            return a.lv < b.lv
                        end
                    else
                       return a.heroConfig.Star < b.heroConfig.Star
                    end
                else
                    if a.heroConfig.Star == b.heroConfig.Star then
                        if a.lv == b.lv then
                            if a.id ~= curHeroData.id and b.id ~= curHeroData.id or a.id == curHeroData.id and b.id == curHeroData.id then 
                                return a.id > b.id
                            else
                                return not a.id ~= curHeroData.id and b.id == curHeroData.id
                            end
                        else
                            return a.lv < b.lv
                        end
                    else
                       return a.heroConfig.Star < b.heroConfig.Star
                    end
                end
            else
                return a.lockState < b.lockState
            end
        else
            return a.isFormation == ""  and not b.dynamicId ~= ""
        end
    end)
end

function RoleUpStarListPanel:AutoSelectHero()
    curSelectHeroList = {}
    for i = 1, #heroDataList do
        if LengthOfTable(curSelectHeroList) < curNeedRoleNum and (heroDataList[i].isFormation == "" or heroDataList[i].isFormation==nil) and heroDataList[i].lockState == 0 then
            curSelectHeroList[heroDataList[i].dynamicId] = heroDataList[i]
        end
    end
    this.numText.text = string.format("(%s/%s)",LengthOfTable(curSelectHeroList),curNeedRoleNum)
    this.ScrollView:SetData(heroDataList, function (index, go)
        this.OnShowSingleCardData(go, heroDataList[index])
    end)
end

--界面关闭时调用（用于子类重写）
function RoleUpStarListPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function RoleUpStarListPanel:OnDestroy()
    this.ScrollView = nil
end

return RoleUpStarListPanel