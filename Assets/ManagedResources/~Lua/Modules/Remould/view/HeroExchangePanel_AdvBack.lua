local this = {}
local sortingOrder = 0
local HeroStarBackConfig = ConfigManager.GetConfig(ConfigName.HeroStarBackConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local HeroLevelConfig = ConfigManager.GetConfig(ConfigName.HeroLevelConfig)
local HeroRankupConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
local selectData
local selectHeroData
local itemList = {}
local itemDefultList = {}

local heroEndBtns = {}
local oldChoosed
local selectHeroData = {}
local tabSortType
local tarHero

function this:InitComponent(gameObject)
    this.gameObject = Util.GetGameObject(gameObject, "HeroExchangePanel_AdvBack/bg")

    this.selectBtn = Util.GetGameObject(this.gameObject, "SelectBtn")

    this.HelpBtn = Util.GetGameObject(this.gameObject,"HelpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    --回溯
    this.SelectHeroPanel = Util.GetGameObject(gameObject, "SelectHero")
    this.goBtn = Util.GetGameObject(this.SelectHeroPanel, "downPanel/GoBtn2")
    this.Item = Util.GetGameObject(this.SelectHeroPanel, "downPanel/Item")
    this.backIcon = Util.GetGameObject(this.Item, "Icon")
    this.backNum = Util.GetGameObject(this.Item, "Num")

    --列表相关
    this.selectTabs = Util.GetGameObject(gameObject, "SelectHero/SelectTabs")
    this.btnHeroGrid = Util.GetGameObject(this.selectTabs, "btnHeroGrid")
    this.itemPro = Util.GetGameObject(gameObject, "SelectHero/Item")
    this.selectHeroBtn = Util.GetGameObject(this.selectTabs, "selectBtn")
    for i = 1, 6 do
        heroEndBtns[i] = Util.GetGameObject(this.btnHeroGrid, "Btn"..i-1)
    end

    this.scroll = Util.GetGameObject(gameObject, "SelectHero/Scroll")
    this.noHero = Util.GetGameObject(this.scroll,"noHero")
    local v21 = this.scroll:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.itemPro, nil, Vector2.New(-v21.x*2, -v21.y*2), 1, 5, Vector2.New(5,5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.ScrollView.gameObject.name = panelName[2]
    this.ScrollView.gameObject:SetActive(false)

    --英雄数据
    this.select = Util.GetGameObject(this.gameObject,"Select")
    this.cardInfo = Util.GetGameObject(this.gameObject,"CardInfo")

    this.cur = Util.GetGameObject(this.gameObject,"CardInfo/cur")
    this.curFrame = Util.GetGameObject(this.cur,"frame"):GetComponent("Image")
    this.curIcon = Util.GetGameObject(this.cur,"icon"):GetComponent("Image")
    this.curProIconBg = Util.GetGameObject(this.cur,"proIcon"):GetComponent("Image")
    this.curProIcon = Util.GetGameObject(this.cur,"proIcon/icon"):GetComponent("Image")
    this.curLvBg = Util.GetGameObject(this.cur,"Lv"):GetComponent("Image")
    this.curLv = Util.GetGameObject(this.cur,"Lv/lv"):GetComponent("Text")
    this.curStar = Util.GetGameObject(this.cur,"Star")
    this.curName = Util.GetGameObject(this.cur,"name"):GetComponent("Text")

    this.new = Util.GetGameObject(this.gameObject,"CardInfo/new")
    this.newFrame = Util.GetGameObject(this.new,"frame"):GetComponent("Image")
    this.newIcon = Util.GetGameObject(this.new,"icon"):GetComponent("Image")
    this.newProIconBg = Util.GetGameObject(this.new,"proIcon"):GetComponent("Image")
    this.newProIcon = Util.GetGameObject(this.new,"proIcon/icon"):GetComponent("Image")
    this.newLvBg = Util.GetGameObject(this.new,"Lv"):GetComponent("Image")
    this.newLv = Util.GetGameObject(this.new,"Lv/lv"):GetComponent("Text")
    this.newStar = Util.GetGameObject(this.new,"Star")
    this.newName = Util.GetGameObject(this.new,"name"):GetComponent("Text")

    this.BackDataList = Util.GetGameObject(this.gameObject,"Scroll")
end

function this:BindEvent()
    Util.AddClick(this.goBtn, function()
        if selectData == nil then
           PopupTipPanel.ShowTipByLanguageId(12655)
           return
        end
        if this.returnItem[2] <= BagManager.GetItemCountById(this.returnItem[1]) then
            local dropList = HeroManager.GetHeroReturnItems(selectHeroData,GENERAL_POPUP_TYPE.GeneralPopup_HeroStarBack,2)
            for k, v in pairs(this.BackAllData)do
                -- curReward.id = m[1]
                -- curReward.num = math.floor(m[2])
                -- curReward.itemConfig = itemConfig[curReward.id]
                -- curReward.star = m[3] or nil
                local data = {}
                data["id"] = v[1]
                data["num"] = v[2]
                data["itemConfig"] = ItemConfig[v[1]]
                data["star"] = nil
                table.insert(dropList,data)
            end
            local item = {}
            for index, value in ipairs(dropList) do
                local state = true
                for i = 1, #item do
                    if item[i][1] == value.id then
                        state = false
                        item[i][2] = item[i][2] + value.num
                    end
                end
                if state then
                    table.insert(item, {value.id, value.num})
                end
            end
            --HeroManager.GetHeroReturnItems(selectHeroData,GENERAL_POPUP_TYPE.ResolveRecall)
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.GeneralPopup_HeroStarBack, item, selectData, function (msg)
               local selectDataListIds = {}
               table.insert(selectDataListIds,selectData.dynamicId)
               NetManager.HeroStarBackRequest(2,selectData.dynamicId,function (msg)
                    -- local HeroRankupConfigData=ConfigManager.TryGetConfigDataByKey("HeroRankupConfig", "LimitStar", this.backStar)
                    local HeroRankupConfigData = ConfigManager.GetConfigDataByDoubleKey("HeroRankupConfig", "OpenStar", this.backStar,"Type",2)
                    HeroManager.UpdateSingleHeroDatas(selectData.dynamicId,this.backLv,this.backStar,selectData.breakId, HeroRankupConfigData.Id)
                    -- HeroManager.UpdateHeroDownData(HeroDownDataType.EQUIP,selectData.dynamicId)
                    -- HeroManager.UpdateHeroDownData(HeroDownDataType.WARWAY,selectData.dynamicId,2)
                    UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                    end)
                    this.ChooseDefult()
                    this:OnShow()
                end)
            end)
        else
           PopupTipPanel.ShowTipByLanguageId(10455)
        end
    end)

    for i = 1, 6 do
        Util.AddClick(heroEndBtns[i], function()
            if tabSortType == i-1 then
                tabSortType = 0
                this.SortTypeClick(0)--全部
                this.selectHeroBtn:GetComponent("Image").sprite = Util.LoadSprite("cn2-x1_AN_shuxing_xuanzhong")
                this.EndTabBtnSelect()
            else
                tabSortType = i-1
                this.SortTypeClick(i-1)
                this.selectHeroBtn:GetComponent("Image").sprite = Util.LoadSprite("cn2-x1_AN_shuxing_xuanzhong")
                this.EndTabBtnSelect(heroEndBtns[i])
            end         
        end)
    end
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.HeroExchange2,this.helpPosition.x,this.helpPosition.y+250) 
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end

function this:OnShow(...)
    sortingOrder = 0

    this.EndTabBtnSelect()
    this.SortTypeClick(0)
    this.ScrollView.gameObject:SetActive(true)
    tabSortType = 0

    -- this.goBtn:GetComponent("Image").color = btnData[1].colorBg
    -- Util.GetGameObject(this.goBtn,"Text"):GetComponent("Text").text = btnData[1].name
    -- Util.GetGameObject(this.goBtn,"Text"):GetComponent("Text").color = btnData[1].colorFont

    this.goBtn:SetActive(true)

    if #tarHero == 0 then
        this.noHero:SetActive(true)
    else
        this.noHero:SetActive(false)
    end
end

function this:OnClose()
    this.ChooseDefult()
end

function this:OnDestroy()
end


function this.SortTypeClick(_sortType)
    tabSortType = _sortType
    -- selectHeroData = {}
    tarHero = HeroManager.GetAllHeroDataMsinusUpWar1(_sortType,2)
    this.SortHeroDatas(tarHero)
    -- local _itemList = {}
    this.ScrollView:SetData(tarHero, function (index, go)
        this.selfindex = tarHero[index].dynamicId
        this.SingleHeroDataShow(go, tarHero[index])
        -- _itemList[index] = go
    end)
    -- this.DelayCreation(_itemList)
end

-- --延迟显示List里的item
-- function this.DelayCreation(list,maxIndex)
--     if this._timer ~= nil then
--         this._timer:Stop()
--         this._timer = nil
--     end

--     if this.ScrollView then
--         this.grid = Util.GetGameObject(this.ScrollView.gameObject,"grid").transform
--         for i = 1, this.grid.childCount do
--             if this.grid:GetChild(i-1).gameObject.activeSelf then
--                 this.grid:GetChild(i-1).gameObject:SetActive(false)
--             end
--         end
--     end

--     if list == nil then return end
--     if #list == 0 then return end

--     local time = 0.01
--     local _index = 1

--     if not maxIndex then
--         maxIndex = #list
--     end

--     for i = 1, #list do
--         if list[i].activeSelf then
--             list[i]:SetActive(false)
--         end
--     end

--     local fun = function ()
--         if _index == maxIndex + 1 then
--             if this._timer then
--                 this._timer:Stop()
--             end
--         end
--         list[_index]:SetActive(true)
--         Timer.New(function ()
--             _index = _index + 1
--         end,time):Start()
--     end

--     this._timer = Timer.New(fun,time,maxIndex + 1)
--     this._timer:Start()
-- end

--英雄排序
function this.SortHeroDatas(_heroDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if a == nil or b == nil then
            return
        end
        if a.isFormation == "" and b.isFormation == "" then
            if a.lockState == b.lockState then
                if a.heroConfig.Natural == b.heroConfig.Natural then
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
            return a.isFormation == ""  and not b.dynamicId ~= ""
        end
    end)
end

--下部页签排序
function this.EndTabBtnSelect(_btn)
    if _btn then
        this.selectHeroBtn.transform:SetParent(_btn.transform)
        this.selectHeroBtn.transform.localScale = Vector3.one
        this.selectHeroBtn.transform.localPosition = Vector3.zero
    else
        this.selectHeroBtn.transform:SetParent(heroEndBtns[1].transform)
        this.selectHeroBtn.transform.localScale = Vector3.one
        this.selectHeroBtn.transform.localPosition = Vector3.zero
    end
end

--设置英雄列表
function this.SingleHeroDataShow(_go,heroData)
    local heroConfig = HeroConfig[heroData.id]
    Util.GetGameObject(_go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
    Util.GetGameObject(_go.transform, "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    Util.GetGameObject(_go.transform, "lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv
    local starGrid = Util.GetGameObject(_go.transform, "star")
    SetHeroStars(starGrid, heroData.star)

    local choosed = Util.GetGameObject(_go.transform, "choosed")
    local FormationId = HeroManager.GetFormationByHeroId(heroData.dynamicId)
    local formationMask = Util.GetGameObject(_go.transform, "formationMask")
    formationMask:SetActive(FormationId ~= nil)
    local lockMask = Util.GetGameObject(_go.transform, "lockMask")
    lockMask:SetActive(heroData.lockState == 1)
    choosed:SetActive(false)
    local cardclickBtn = Util.GetGameObject(_go.transform, "icon")

    Util.AddOnceClick(cardclickBtn, function()
        if selectHeroData[heroData.dynamicId] then
            if oldChoosed then
                oldChoosed.gameObject:SetActive(false)
                oldChoosed = nil
                selectData = nil
                selectHeroData = {}
                this.cardInfo:SetActive(false)
                this.Item:SetActive(false)
                this.BackDataList:SetActive(false)
            end
            return
        end
        if oldChoosed then
            oldChoosed.gameObject:SetActive(false)
            selectHeroData = {}
        end

        selectHeroData[heroData.dynamicId] = heroData
        selectData = selectHeroData[heroData.dynamicId]
        choosed:SetActive(true)
        oldChoosed = choosed

        this.ShowCurHeroInfo(selectData)
        this.ShowBackData()
    end)
    --英雄下阵
    Util.AddOnceClick(formationMask, function()
        if FormationId ~= nil then
            local teamIdList = HeroManager.GetAllFormationByHeroId(heroData.dynamicId)
            local name = ""
            for k,v in pairs(teamIdList)do
                local formationName = FormationManager.MakeAEmptyTeam(v)
                name = name..formationName.teamName

                if --[[v == FormationTypeDef.FORMATION_DREAMLAND
                    or v == FormationTypeDef.FORMATION_AoLiaoer
                    or]] v == FormationTypeDef.DEFENSE_TRAINING then
                    PopupTipPanel.ShowTip(string.format(GetLanguageStrById(50153),name))
                    return
                end
            end
            -- 复位角色的状态
            MsgPanel.ShowTwo(string.format(GetLanguageStrById(22704),name), nil, function()
                for i = 1,#teamIdList do
                    local teamId = HeroManager.GetFormationByHeroId(heroData.dynamicId)
                    local formationName = FormationManager.MakeAEmptyTeam(teamId)
                    if teamId then
                        local teamData = FormationManager.GetFormationByID(teamId)
                        if teamData then
                            if LengthOfTable(teamData.teamHeroInfos) <= 1 then
                                PopupTipPanel.ShowTipByLanguageId(23118)
                                -- return
                            else
                                for k,v in pairs(teamData.teamHeroInfos)do
                                    if v.heroId == heroData.dynamicId then
                                        table.removebyvalue(teamData.teamHeroInfos,v)
                                        break
                                    end
                                end
                                FormationManager.RefreshFormation(teamId, teamData.teamHeroInfos,"",
                                {
                                    supportId = SupportManager.GetFormationSupportId(teamId),
                                    adjutantId = AdjutantManager.GetFormationAdjutantId(teamId)
                                    },
                                nil,
                                teamData.formationId)
                                PopupTipPanel.ShowTipByLanguageId(10713)
                            end
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
    end)
end

--设置需要回溯英雄的信息
function this.ShowCurHeroInfo(selectData)
    this.select:SetActive(false)
    this.cardInfo:SetActive(true)
    this.BackDataList:SetActive(true)

    if selectData == nil then
        this.ChooseDefult()
        return
    end
    --返还的所有道具
    this.BackAllData = {}

    --本体返还
    local HeroStarBackConfigData = ConfigManager.GetConfigDataByDoubleKey("HeroStarBackConfig", "Star", selectData.star, "Country", selectData.heroConfig.PropertyName)
    local SelfPieceReturnId = HeroStarBackConfigData.SelfPieceReturn
    local HeroConfigData = ConfigManager.TryGetConfigDataByKey("HeroConfig", "Id", selectData.id)
    local ItemConfigDataSelf = ConfigManager.TryGetConfigDataByKey("ItemConfig", "Id", HeroConfigData.PiecesId)
    local selfBack = {HeroConfigData.PiecesId,SelfPieceReturnId}
    table.insert(this.BackAllData,selfBack)

    --随机返还
    local ItemReturn = HeroStarBackConfigData.ItemReturn
    for i = 1,#ItemReturn do
        local ItemConfigDataRandom = ConfigManager.TryGetConfigDataByKey("ItemConfig", "Id", ItemReturn[i][1])--返还材料Id
        local itemNum = ItemReturn[i][2]--返还材料数量
        local ramdomBack = {ItemReturn[i][1],itemNum}
        table.insert(this.BackAllData,ramdomBack)
    end

    --本体显示 
    local HeroRankupConfigData = ConfigManager.TryGetConfigDataByKey("HeroRankupConfig", "OpenStar",  HeroStarBackConfigData.BackStar)
    this.curFrame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(nil,selectData.star))
    this.curProIconBg.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(nil,selectData.star))
    this.curProIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(HeroConfigData.PropertyName))
    this.curName.text = GetLanguageStrById(selectData.name)
    this.curLvBg:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(nil,selectData.star))
    this.curLv.text = selectData.lv

    this.curIcon.sprite = Util.LoadSprite(selectData.icon)
    this.newIcon.sprite = Util.LoadSprite(selectData.icon)

    this.backStar = HeroStarBackConfigData.BackStar
    SetHeroStars(this.curStar, selectData.star)
    SetHeroStars(this.newStar, this.backStar)

    --返还等级
    if selectData.lv <= HeroRankupConfigData.OpenLevel then
        this.backLv  =  selectData.lv
        this.newLv.text = selectData.lv
    else
        this.backLv  =  HeroRankupConfigData.OpenLevel
        this.newLv.text = HeroRankupConfigData.OpenLevel
    end

    -- this.backLv = HeroRankupConfigData.OpenLevel
    -- this.newLv.text = HeroRankupConfigData.OpenLevel
    this.newFrame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(nil,this.backStar))
    this.newProIconBg.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(nil,this.backStar))
    this.newProIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(HeroConfigData.PropertyName))
    this.newName.text = GetLanguageStrById(selectData.name)
    this.newLvBg:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(nil,this.backStar))
    if selectData.lv > this.backLv then
        --等级返还
        local HeroLevelConfigData = ConfigManager.TryGetConfigDataByKey("HeroLevelConfig", "Level", selectData.lv)
        local BackHeroLevelConfigData = ConfigManager.TryGetConfigDataByKey("HeroLevelConfig", "Level", HeroRankupConfigData.OpenLevel)
        local LevelBackList = HeroLevelConfigData.SumConsume
        local BackLevelBackList = BackHeroLevelConfigData.SumConsume
        for i = 1, #LevelBackList do
            local levelBack = LevelBackList[i]
            local backlevelBack = BackLevelBackList[i]
            local data = {}
            data[1] = levelBack[1]
            data[2] = levelBack[2]-backlevelBack[2]
            table.insert(this.BackAllData,data)
        end
    end

    FindFairyManager.ResetItemView(this.BackDataList,this.BackDataList.transform,itemList,10,0.7,sortingOrder,false,this.BackAllData)
end

---转换材料显示
function this.ShowBackData()
    this.Item:SetActive(true)
    -- this.backNum:SetActive(true)
    --回溯道具消耗
    local HeroStarBackConfigData = ConfigManager.GetConfigDataByDoubleKey("HeroStarBackConfig", "Star", selectData.star, "Country", selectData.heroConfig.PropertyName)
    this.returnItem = HeroStarBackConfigData.Cost
    local ItemConfigDataReturn = ConfigManager.TryGetConfigDataByKey("ItemConfig", "Id", this.returnItem[1])
    this.Item:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(ItemConfigDataReturn.Quantity))
    this.backIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfigDataReturn.ResourceID))

    local bagNum = BagManager.GetItemCountById(ItemConfigDataReturn.Id)
    local str
    if bagNum >= this.returnItem[2] then
        str = bagNum .. "/" .. this.returnItem[2]
    else
        str = string.format("<color=#FF6868>%s</color>",bagNum) .. "/" .. this.returnItem[2]
    end
    this.backNum:GetComponent("Text").text = str
    Util.AddOnceClick(this.backIcon, function ()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, this.returnItem[1])
    end)
end

function this.ChooseDefult()
    selectData = nil--关闭时清空数据
    this.select:SetActive(true)
    this.Item:SetActive(false)
    this.cardInfo:SetActive(false)
    this.ScrollView.gameObject:SetActive(false)
    this.BackDataList:SetActive(false)
    this.goBtn:SetActive(false)

    selectHeroData = {}
    oldChoosed = nil
end

return this