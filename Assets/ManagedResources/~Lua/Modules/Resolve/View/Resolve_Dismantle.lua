----- 献祭 -----
local this = {}
local sortingOrder = 0
local tabSortType = 0
local tarHero
local selectHeroData = {}--选择的英雄list did = data
local selectHeroChoose = {}
local maxSelectNum = 30--最大选择数量
function this:InitComponent(gameObject)
    this.gameObject = Util.GetGameObject(gameObject,"Content/Resolve_Dismantle")

    --上部内容
    this.helpBtn = Util.GetGameObject(this.gameObject,"HelpBtn")
    this.helpPos = this.helpBtn:GetComponent("RectTransform").localPosition
    --回溯按钮
    this.confirmBtn = Util.GetGameObject(this.gameObject,"btns/ConfirmBtn")
    this.confirmAllBtn = Util.GetGameObject(this.gameObject,"btns/ConfirmAllBtn")
    this.shopBtn = Util.GetGameObject(this.gameObject,"shopBtn")

    this.selectNumText = Util.GetGameObject(this.gameObject,"selectNumImage/selectNumText"):GetComponent("Text")
    this.selectBtn = Util.GetGameObject(this.gameObject,"btns/selectBtn")
    this.noSelectBtn = Util.GetGameObject(this.gameObject,"btns/noSelectBtn")

    this.Empty = Util.GetGameObject(this.gameObject,"Empty")
    this.recycleNum = Util.GetGameObject(gameObject,"recycleNum"):GetComponent("Text")
    this.cardPre = Util.GetGameObject(gameObject,"DismantleItem")
    this.scrollbar = Util.GetGameObject(this.gameObject,"Scrollbar"):GetComponent("Scrollbar")

    this.ItemListRoot = Util.GetGameObject(this.gameObject, "ItemListRoot")
    local v21 = this.ItemListRoot:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ItemListRoot.transform,
        this.cardPre, this.scrollbar,  Vector2.New(-v21.x*2, -v21.y*2), 1, 5, Vector2.New(5,5))
    this.ScrollView.moveTween.Strength = 1
    maxSelectNum = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,54).Value)
end

function this:BindEvent()
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Resolve_Dismantle,this.helpPos.x,this.helpPos.y)
    end)
    Util.AddClick(this.confirmBtn,function()
        if tonumber(LengthOfTable(selectHeroData)) == 0 then
            PopupTipPanel.ShowTipByLanguageId(11787)
        else
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.ResolveDismantle,
            HeroManager.GetHeroReturnItems(selectHeroData,GENERAL_POPUP_TYPE.ResolveDismantle),selectHeroData)
        end
    end)
    --一键回收
    Util.AddClick(this.confirmAllBtn,function()
        this.QuickSelectListData(3)
        if LengthOfTable(selectHeroData) > 0 then
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.OnrKeyResolveDismantle,
            HeroManager.GetHeroReturnItems(selectHeroData,GENERAL_POPUP_TYPE.ResolveDismantle),selectHeroData,function()
                selectHeroData = {}
                this.ScrollView:SetData(tarHero, function (index, go)
                    this.SingleHeroDataShow(go, tarHero[index])
                end)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(50358)
        end
    end)
    Util.AddClick(this.selectBtn, function()
        this.QuickSelectListData(1)
        if LengthOfTable(selectHeroData) > 0 then
            this.noSelectBtn.gameObject:SetActive(true)
            this.selectBtn.gameObject:SetActive(false)
        end
    end)
    Util.AddClick(this.noSelectBtn, function()
        this.QuickSelectListData(2)
        this.noSelectBtn.gameObject:SetActive(false)
        this.selectBtn.gameObject:SetActive(true)
    end)
    Util.AddClick(this.shopBtn, function()
        local isActive, errorTip = ShopManager.IsActive(SHOP_TYPE.SOUL_CONTRACT_SHOP)
        if not isActive then
            PopupTipPanel.ShowTip(errorTip or GetLanguageStrById(10528))
            return
        end
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.SOUL_CONTRACT_SHOP)
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(...)
    sortingOrder = 0
    this.SortTypeClick(sortingOrder)
    this.selectBtn.gameObject:SetActive(true)
    this.noSelectBtn.gameObject:SetActive(false)
end

--展示数据
function this.SortTypeClick(_sortType)
    tabSortType = _sortType
    selectHeroData = {}
    tarHero = HeroManager.GetAllHeroDataMsinusUpWar(_sortType,2)
    this.selectNumText.text = GetLanguageStrById(11775).."0/"..maxSelectNum
    this.selectBtn.gameObject:SetActive(true)
    this.noSelectBtn.gameObject:SetActive(false)
    this.SortHeroDatas(tarHero)
    this.Empty:SetActive(#tarHero <= 0)
    this.recycleNum.text = #tarHero

    -- local itemList = {}
    this.ScrollView:SetData(tarHero, function (index, go)
        this.selfindex = tarHero[index].dynamicId
        this.SingleHeroDataShow(go, tarHero[index])
        -- itemList[index] = go
    end)
    -- this.DelayCreation(itemList)
end

--延迟显示List里的item
function this.DelayCreation(list,maxIndex)
    if this._timer ~= nil then
        this._timer:Stop()
        this._timer = nil
    end

    if this.ScrollView then
        this.grid = Util.GetGameObject(this.ScrollView.gameObject,"grid").transform
        for i = 1, this.grid.childCount do
            if this.grid:GetChild(i-1).gameObject.activeSelf then
                this.grid:GetChild(i-1).gameObject:SetActive(false)
            end
        end
    end

    if list == nil then return end
    if #list == 0 then return end

    local time = 0.01
    local _index = 1

    if not maxIndex then
        maxIndex = #list
    end

    for i = 1, #list do
        if list[i].activeSelf then
            list[i]:SetActive(false)
        end
    end

    local fun = function ()
        if _index == maxIndex + 1 then
            if this._timer then
                this._timer:Stop()
            end
        end
        list[_index]:SetActive(true)
        Timer.New(function ()
            _index = _index + 1
        end,time):Start()
    end

    this._timer = Timer.New(fun,time,maxIndex + 1)
    this._timer:Start()
end

--英雄单个数据展示
function this.SingleHeroDataShow(go,_heroData)
    local heroData = _heroData
    local _go = go
    Util.GetGameObject(_go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv
    -- Util.GetGameObject(_go.transform, "Text"):GetComponent("Text").text = GetLanguageStrById(heroData.heroConfig.ReadingName)
    Util.GetGameObject(_go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    -- Util.GetGameObject(_go.transform, "posIcon"):SetActive(false)--:GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)

    Util.GetGameObject(_go.transform, "lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroData.heroConfig.Quality,heroData.star))
    if heroData.heroConfig.PropertyName == 0 then
        Util.GetGameObject(_go.transform, "proIcon"):SetActive(false)
        Util.GetGameObject(_go.transform, "proIconBg"):SetActive(false)
     else
        Util.GetGameObject(_go.transform, "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.heroConfig.Quality,heroData.star))
        Util.GetGameObject(_go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    end
    --Util.GetGameObject(_go.transform, "heroStage"):GetComponent("Image").sprite = Util.LoadSprite(HeroStageSprite[heroData.heroConfig.HeroStage])
    local starGrid = Util.GetGameObject(_go.transform, "star")
    SetHeroStars(starGrid, heroData.star)
    local choosed = Util.GetGameObject(_go.transform, "choosed")
    local choosedBg = Util.GetGameObject(_go.transform, "choosedBg")
    local FormationId = HeroManager.GetFormationByHeroId(heroData.dynamicId)
    local formationMask = Util.GetGameObject(_go.transform, "formationMask")
    formationMask:SetActive(FormationId ~= nil)

    local lockMask = Util.GetGameObject(_go.transform, "lockMask")
    lockMask:SetActive(heroData.lockState == 1)
    choosed:SetActive(selectHeroData[heroData.dynamicId] ~= nil)
    choosedBg:SetActive(selectHeroData[heroData.dynamicId] ~= nil)
    local cardclickBtn = Util.GetGameObject(_go.transform, "icon")
    this.selectNumText.text = LengthOfTable(selectHeroData).."/"..maxSelectNum
   
    Util.AddOnceClick(cardclickBtn, function()
        if heroData.lv > 1 then
            PopupTipPanel.ShowTipByLanguageId(50163)
            return
        end

        if selectHeroData[heroData.dynamicId] then
            choosed:SetActive(false)
            choosedBg:SetActive(false)
            selectHeroData[heroData.dynamicId] = nil
            this.selectNumText.text = LengthOfTable(selectHeroData).."/"..maxSelectNum
            --this.noSelectBtn.gameObject:SetActive(LengthOfTable(selectHeroData)>0)
            return
        end
        if LengthOfTable(selectHeroData) >= maxSelectNum then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12211),maxSelectNum))
            return
        end
        selectHeroData[heroData.dynamicId] = heroData
        choosed:SetActive(true)
        choosedBg:SetActive(true)
        this.selectNumText.text = LengthOfTable(selectHeroData).."/"..maxSelectNum
        --this.noSelectBtn.gameObject:SetActive(LengthOfTable(selectHeroData)>0)
        
    end)

    Util.AddOnceClick(formationMask, function()
        --if heroData.isFormation ~= "" then
            --TODONow
            -- if selectHeroData[heroData.dynamicId] then
            --     choosed:SetActive(false)
            --     selectHeroData[heroData.dynamicId] = nil
            --     this.selectText.text = GetLanguageStrById(11775)..LengthOfTable(selectHeroData).."/"..maxSelectNum
            --     --this.noSelectBtn.gameObject:SetActive(LengthOfTable(selectHeroData)>0)
            --     return
            -- end
            -- selectHeroData[_heroData.dynamicId]=_heroData
            -- this.selectText.text = GetLanguageStrById(11775)..LengthOfTable(selectHeroData).."/"..maxSelectNum
            -- choosed:SetActive(true)
                      
            -- 复位角色的状态
            --GetLanguageStrById(11788)..heroData.isFormation..GetLanguageStrById(11789)

            if FormationId ~= nil then
                local teamIdList = HeroManager.GetAllFormationByHeroId(heroData.dynamicId)
                local name = ""
                for k,v in pairs(teamIdList)do
                    local formationName = FormationManager.MakeAEmptyTeam(v)
                    name = name..formationName.teamName

                    if --[[v == FormationTypeDef.FORMATION_DREAMLAND or v == FormationTypeDef.FORMATION_AoLiaoer or]] v == FormationTypeDef.DEFENSE_TRAINING then
                        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(50153),name))
                        return
                    end
                end
                -- 复位角色的状态
                MsgPanel.ShowTwo(string.format(GetLanguageStrById(22704),name), nil, function()
                    for i = 1, #teamIdList do
                        local teamId = HeroManager.GetFormationByHeroId(heroData.dynamicId)
                        local formationName = FormationManager.MakeAEmptyTeam(teamId)
                        if teamId then
                            local teamData = FormationManager.GetFormationByID(teamId)
                            if LengthOfTable(teamData.teamHeroInfos)<=1 then
                                PopupTipPanel.ShowTipByLanguageId(23118)
                                -- return
                            else
                                for k, v in pairs(teamData.teamHeroInfos)do
                                    if v.heroId == heroData.dynamicId then
                                        table.removebyvalue(teamData.teamHeroInfos,v)
                                        break
                                    end
                                end
                                FormationManager.RefreshFormation(teamId, teamData.teamHeroInfos,"",
                                { supportId = SupportManager.GetFormationSupportId(teamId),
                                adjutantId = AdjutantManager.GetFormationAdjutantId(teamId) },
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
                return
            end
            -- MsgPanel.ShowTwo(string.format(GetLanguageStrById(22704),heroData.isFormation), nil, function()
            --         if heroData.isFormations[1] then
            --             if heroData.isFormations[1] == FormationTypeDef.FORMATION_NORMAL then
            --                 --只是打开界面 并没有进行数据的传输
            --                 --UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.SAVE_FORMATION)

            --                 --上阵列表赋值
            --                 this.choosedList ={}
            --                 this.curFormation = FormationManager.GetFormationByID(heroData.isFormations[1])
            --                 for j = 1, #this.curFormation.teamHeroInfos do
            --                     local teamInfo = this.curFormation.teamHeroInfos[j]--单个英雄数据
            --                     table.insert(this.choosedList, {heroId =teamInfo.heroId,position=teamInfo.position})
            --                 end

            --                 if LengthOfTable(this.choosedList)<=1 then
            --                     PopupTipPanel.ShowTipByLanguageId(23118)
            --                    return
            --                 end

            --                 for k, v in ipairs(this.choosedList) do
            --                     if v.heroId == heroData.dynamicId then
            --                         table.remove(this.choosedList,k)
            --                     end
            --                 end
            --                 FormationManager.RefreshFormation(heroData.isFormations[1], this.choosedList,
            --                     {supportId = SupportManager.GetFormationSupportId(heroData.isFormations[1]),
            --                     adjutantId = AdjutantManager.GetFormationAdjutantId(heroData.isFormations[1])},
            --                     nil,
            --                     this.curFormation.formationId)
            --                 heroData.isFormation = ""
            --                 formationMask:SetActive(false)
            --                 PopupTipPanel.ShowTipByLanguageId(10713)
            --                 --this.SortTypeClick(sortingOrder)

            --                 selectHeroData[heroData.dynamicId]=heroData
            --                 choosed:SetActive(true)
            --                 this.selectText.text = GetLanguageStrById(11775)..LengthOfTable(selectHeroData).."/"..maxSelectNum

            --                 --Now
            --             UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.ResolveDismantle,
            --             HeroManager.GetHeroReturnItems(selectHeroData,GENERAL_POPUP_TYPE.ResolveDismantle),selectHeroData)


            --             elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_ARENA_DEFEND then
            --                 JumpManager.GoJump(8001)
            --             elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_ENDLESS_MAP then
            --                 JumpManager.GoJump(57001) 
            --             elseif heroData.isFormations[1] == FormationTypeDef.ARENA_TOM_MATCH then
            --                 JumpManager.GoJump(57001)
            --             end


                        --Before
                    --     if heroData.isFormations[1] == FormationTypeDef.FORMATION_NORMAL then
                    --         JumpManager.GoJump(1013)
                    --     elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_ARENA_DEFEND then
                    --         JumpManager.GoJump(1014)
                    --     elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_ARENA_ATTACK then
                    --         JumpManager.GoJump(1015) 
                    --     elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_DREAMLAND then
                    --         JumpManager.GoJump(64001)                                                                                                                                                                                                             
                    --     elseif heroData.isFormations[1] == FormationTypeDef.ARENA_TOM_MATCH then
                    --         JumpManager.GoJump(80008)
                    --     elseif heroData.isFormations[1] == FormationTypeDef.CLIMB_TOWER then
                    --         JumpManager.GoJump(80007) 
                    --     elseif heroData.isFormations[1] == FormationTypeDef.Arden_MIRROR then
                    --         JumpManager.GoJump(80005)
                    --     elseif heroData.isFormations[1] == FormationTypeDef.GUILD_TRANSCRIPT then
                    --         JumpManager.GoJump(80003)
                    --     elseif heroData.isFormations[1] == FormationTypeDef.DEFENSE_TRAINING then
                    --         JumpManager.GoJump(80001) 
                    --     elseif heroData.isFormations[1] == FormationTypeDef.BLITZ_STRIKE then
                    --         JumpManager.GoJump(80002)
                    --     elseif heroData.isFormations[1] == FormationTypeDef.CONTEND_HEGEMONY then
                    --         JumpManager.GoJump(80004)
                    --     elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_AoLiaoer then
                    --         JumpManager.GoJump(64001)
                    --     end
                    

                    --点击确认无跳转反应
            -- end)
            -- return
        --end
    end)
    Util.AddOnceClick(lockMask, function()
        if heroData.lockState == 1 then
            MsgPanel.ShowTwo(GetLanguageStrById(11790), nil, function()
                NetManager.HeroLockEvent(heroData.dynamicId,0,function ()
                    PopupTipPanel.ShowTipByLanguageId(11791)
                    HeroManager.UpdateSingleHeroLockState(heroData.dynamicId,0)
                    lockMask:SetActive(false)
                end)
            end)
            return
        end
    end)
end

--英雄排序
function this.SortHeroDatas(_heroDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if a == nil or b == nil then
            return
        end
        local teamListA=HeroManager.GetAllFormationByHeroId(a.dynamicId)
        local teamListB=HeroManager.GetAllFormationByHeroId(b.dynamicId)
        if #teamListA<=0 and #teamListB<=0 then
            if a.lockState == b.lockState then
                if a.heroConfig.Natural ==b.heroConfig.Natural then
                    if a.star == b.star then
                        if a.lv == b.lv then
                            return a.heroConfig.Id > b.heroConfig.Id
                        else
                            return a.lv < b.lv
                        end
                    else
                        return a.star < b.star
                    end
                else
                    return a.heroConfig.Natural < b.heroConfig.Natural
                end
            else
                return a.lockState < b.lockState
            end
        else
            return #teamListA<=0  and not b.dynamicId ~= ""
        end
    end)
end

--快速选择英雄 或者 装备
function this.QuickSelectListData(type)--1:一键选择 2.取消选择 3.一键回收
    if type == 1 then
        selectHeroData = {}
        for k, v in pairs(tarHero) do
            if LengthOfTable(selectHeroData) < maxSelectNum and v.isFormation == "" and v.lockState == 0 and v.star < 4 and v.lv < 2 then
                selectHeroData[v.dynamicId] = v
            else
                break
            end
        end
        this.ScrollView:SetData(tarHero, function (index, go)
            this.SingleHeroDataShow(go, tarHero[index])
        end)
    elseif type == 2 then
        selectHeroData = {}
        this.ScrollView:SetData(tarHero, function (index, go)
            this.SingleHeroDataShow(go, tarHero[index])
        end)
    elseif type == 3 then
        selectHeroData = {}
        local forma = {}
        for k, v in pairs(tarHero) do
            local threeStarHero = {}
            local teamIdList = HeroManager.GetAllFormationByHeroId(v.dynamicId)
            if v.lv < 2 and v.star <= 3 and #teamIdList <= 0 then
                if v.star <= 2 then
                    selectHeroData[v.dynamicId] = v
                end
                if v.star == 3 then
                    if forma[v.heroConfig.PropertyName] then
                        table.insert(forma[v.heroConfig.PropertyName],v)
                    else
                        table.insert(threeStarHero,v)
                        forma[v.heroConfig.PropertyName] = threeStarHero
                    end
                end
            end
        end

        local allTeam = {}
        for k,v in pairs(forma) do
            if #v > 10 then
                local team = {}
                for i = 1, #forma[k] - 10 do
                    table.insert(team, forma[k][i])
                end
                table.insert(allTeam, team)
            end
        end
        for _, v in ipairs(allTeam) do
            for i = 1, #v do
                selectHeroData[v[i].dynamicId] = v[i]
            end
        end

        -- for k,v in pairs(forma) do
        --     if #v > 10 then
        --         for i = 1, #v-10 do
        --             selectHeroData[v[i].dynamicId] = v[i]
        --         end
        --     end
        -- end
        this.ScrollView:SetData(tarHero, function (index, go)
            this.SingleHeroDataShow(go, tarHero[index])
        end)
    end
end

function this:OnClose()
end

function this:OnDestroy()
end

return this