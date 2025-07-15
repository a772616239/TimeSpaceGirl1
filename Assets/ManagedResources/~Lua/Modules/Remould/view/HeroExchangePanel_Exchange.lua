local this = {}
local heroEndBtns = {}
local tabSortType
local sortingOrder = 0
local HeroExchangeConfig = ConfigManager.GetConfig(ConfigName.HeroExchangeConfig)

local tarHero
local selectHeroData = {}--选择的英雄list did = data
local maxSelectNum = 30--最大选择数量

local selectData--选择的改装坦克
local oldChoosed
-- local selectDatas--改造坦克需要的材料
-- local selectDataCount --选中的材料数量
local selectDataList = {} --选中的坦克列表
local needNumber --需要的材料数量

function this:InitComponent(gameObject)
    this.gameObject = Util.GetGameObject(gameObject, "HeroExchangePanel_Exchange/bg")

    this.HelpBtn = Util.GetGameObject(this.gameObject,"HelpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    --选择的英雄
    this.chooseTarget = Util.GetGameObject(this.gameObject, "ChooseTarget")
    this.chooseTargetempty = Util.GetGameObject(this.chooseTarget, "Empty")
    this.chooseTargetItem = Util.GetGameObject(this.chooseTarget, "Item")
    this.chooseTargettipName = Util.GetGameObject(this.chooseTarget, "Name")
    this.chooseTargetItem:SetActive(false)

    --旧
    this.curCard = Util.GetGameObject(this.gameObject, "cur")
    this.curCardBg = Util.GetGameObject(this.curCard, "di"):GetComponent("Image")
    this.curCardFarme = Util.GetGameObject(this.curCard, "frame"):GetComponent("Image")
    this.curCardIcon = Util.GetGameObject(this.curCard, "icon"):GetComponent("Image")
    this.curCardName = Util.GetGameObject(this.curCard, "name"):GetComponent("Text")
    this.curCardStar = Util.GetGameObject(this.curCard, "starGrid")
    this.curCardProIcon = Util.GetGameObject(this.curCard, "pro"):GetComponent("Image")
    this.curCardLv = Util.GetGameObject(this.curCard, "lv"):GetComponent("Text")
    this.curCard:SetActive(false)

    --新
    this.newCard = Util.GetGameObject(this.gameObject, "new")
    this.newCardBg = Util.GetGameObject(this.newCard, "di"):GetComponent("Image")
    this.newCardFarme = Util.GetGameObject(this.newCard, "frame"):GetComponent("Image")
    this.newCardIcon = Util.GetGameObject(this.newCard, "icon"):GetComponent("Image")
    this.newCardName = Util.GetGameObject(this.newCard, "name"):GetComponent("Text")
    this.newCardStar = Util.GetGameObject(this.newCard, "starGrid")
    this.newCardProIcon = Util.GetGameObject(this.newCard, "pro"):GetComponent("Image")
    this.newCardLv = Util.GetGameObject(this.newCard, "lv"):GetComponent("Text")
    this.newCard:SetActive(false)

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
    this.ScrollView.gameObject.name = panelName[3]
    this.ScrollView.gameObject:SetActive(false)

    --回溯
    this.SelectHeroPanel = Util.GetGameObject(gameObject, "SelectHero")
    this.goBtn = Util.GetGameObject(this.SelectHeroPanel, "downPanel/GoBtn3")
    this.Item = Util.GetGameObject(this.SelectHeroPanel, "downPanel/Item")
    this.backIcon = Util.GetGameObject(this.Item, "Icon")
    this.backNum = Util.GetGameObject(this.Item, "Num")
end

function this:BindEvent()
    Util.AddClick(this.chooseTarget, function()
        if selectData ~= nil then
            this.chooseTargetItem:SetActive(false)
            this.chooseTargetempty:SetActive(true)
            this.newCard:SetActive(false)
           UIManager.OpenPanel(UIName.HeroListPopup,2,this,panelName[2],selectData) 
        else
            PopupTipPanel.ShowTipByLanguageId(12656)
        end
    end)

    Util.AddClick(this.goBtn, function()
        if selectData == nil then
           PopupTipPanel.ShowTipByLanguageId(12656)--请选择要改装的战车
           return
        elseif needNumber == nil or LengthOfTable(selectDataList) < needNumber then
           PopupTipPanel.ShowTipByLanguageId(10455)--材料不足
           return
        end
  
        local selectDataListIds = {}

        for k, v in pairs(selectDataList) do
            table.insert(selectDataListIds,k)
        end

        --回溯
        NetManager.HeroExchangeRequest(selectData.dynamicId,selectDataListIds,function (msg)
            table.insert(selectDataListIds,selectData.dynamicId)
            HeroManager.DeleteHeroDatas(selectDataListIds)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
            end)
            selectData = nil
            selectHeroData = {}
            this.InitState()
            this.SortTypeClick(0)
        end)
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
end

--更新帮助按钮的事件
function this.RefreshHelpBtn()
    this.HelpBtn:SetActive(true)
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.HeroExchange1,this.helpPosition.x,this.helpPosition.y+450)
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
    selectHeroData = {}
    this.EndTabBtnSelect()
    this.InitState()

    this.SortTypeClick(0)
    tabSortType = 0
    sortingOrder = 0
    this.RefreshHelpBtn()
    this.ScrollView.gameObject:SetActive(true)
    this.goBtn:GetComponent("Image").color = btnData[2].colorBg
    Util.GetGameObject(this.goBtn,"Text"):GetComponent("Text").text = btnData[2].name
    Util.GetGameObject(this.goBtn,"Text"):GetComponent("Text").color = btnData[2].colorFont
    this.goBtn:SetActive(true)

    if #tarHero == 0 then
        this.noHero:SetActive(true)
    else
        this.noHero:SetActive(false)
    end
end

function this:OnClose()
    this.selectHeroBtn:GetComponent("Image").sprite = Util.LoadSprite("cn2-x1_AN_shuxing_xuanzhong")
    this.SortTypeClick(0)
    oldChoosed = nil
    this.goBtn:SetActive(false)
    this.Item:SetActive(false)
    this.curCard:SetActive(false)
    this.newCard:SetActive(false)
    this.ScrollView.gameObject:SetActive(false)
    this.chooseTargetItem:SetActive(false)
    this.chooseTargetempty:SetActive(true)
    selectData = nil
    selectHeroData = {}
    oldChoosed = nil
end

function this:OnDestroy()
end

-----------------------------------------------可改装的坦克显示（可根据阵营分）-----------------------------------------------
function this.SortTypeClick(_sortType)
    tabSortType = _sortType
    tarHero = HeroManager.GetAllHeroDataMsinusUpWar1(_sortType,2)
    this.SortHeroDatas(tarHero)

    -- local itemList = {}
    this.ScrollView:SetData(tarHero, function (index, go)
        this.selfindex = tarHero[index].dynamicId
        this.SingleHeroDataShow(go, tarHero[index])
        -- itemList[index] = go
    end)
    -- this.DelayCreation(itemList)
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

--英雄单个数据展示
function this.SingleHeroDataShow(go,_heroData)
    local heroData = _heroData
    local _go = go
    Util.GetGameObject(_go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    Util.GetGameObject(_go.transform, "proIconBg"):GetComponent("Image").sprite  = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    Util.GetGameObject(_go.transform, "lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv

    local starGrid = Util.GetGameObject(_go.transform, "star")
    SetHeroStars(starGrid, heroData.star)
    local choosed = Util.GetGameObject(_go.transform, "choosed")
    local formationMask = Util.GetGameObject(_go.transform, "formationMask")
    local teamIdList = HeroManager.GetAllFormationByHeroId(heroData.dynamicId)
    formationMask:SetActive(#teamIdList>0)
    local lockMask = Util.GetGameObject(_go.transform, "lockMask")
    lockMask:SetActive(heroData.lockState == 1)
    choosed:SetActive(selectHeroData[heroData.dynamicId] ~= nil)
    local cardclickBtn = Util.GetGameObject(_go.transform, "icon")

    Util.AddOnceClick(cardclickBtn, function()
        if selectHeroData[heroData.dynamicId] then
               if oldChoosed then
                  oldChoosed.gameObject:SetActive(false)
                  oldChoosed = nil
                  selectData = nil
                  this.curCard:SetActive(false)
                  this.newCard:SetActive(false)
                  this.chooseTargetItem:SetActive(false)
                  this.chooseTargetempty:SetActive(true)
                  selectHeroData = {}
               end
               return
        end
        if oldChoosed ~= nil then
            oldChoosed.gameObject:SetActive(false)
            selectHeroData = {}
        end
        selectHeroData[heroData.dynamicId] = heroData
        selectData = selectHeroData[heroData.dynamicId]
        choosed:SetActive(true)
        oldChoosed = choosed

        this.newCard:SetActive(false)
        this.chooseTargetItem:SetActive(false)
        this.chooseTargetempty:SetActive(true)
        this.FormShowItem(selectHeroData[heroData.dynamicId])
        this:setData(nil)
    end)

    Util.AddOnceClick(formationMask, function()
        if #teamIdList > 0 then
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
            MsgPanel.ShowTwo(string.format(GetLanguageStrById(22705),name), nil, function()
                for i = 1,#teamIdList do
                    local teamId = HeroManager.GetFormationByHeroId(heroData.dynamicId)
                    local formationName = FormationManager.MakeAEmptyTeam(teamId)
                    if teamId then
                        local teamData = FormationManager.GetFormationByID(teamId)
                        if LengthOfTable(teamData.teamHeroInfos) <= 1 then
                            PopupTipPanel.ShowTip(GetLanguageStrById(23118))
                        else
                            for k,v in pairs(teamData.teamHeroInfos)do
                                if v.heroId == heroData.dynamicId then
                                    table.removebyvalue(teamData.teamHeroInfos,v)
                                    break
                                end
                            end
                            FormationManager.RefreshFormation(teamId, teamData.teamHeroInfos,"",
                            {supportId = SupportManager.GetFormationSupportId(teamId),
                            adjutantId = AdjutantManager.GetFormationAdjutantId(teamId)},
                            nil,
                            teamData.formationId)
                            PopupTipPanel.ShowTip(GetLanguageStrById(10713))
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
        local teamListA = HeroManager.GetAllFormationByHeroId(a.dynamicId)
        local teamListB = HeroManager.GetAllFormationByHeroId(b.dynamicId)
        if #teamListA <= 0 and #teamListB <= 0 then
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
            return #teamListA <= 0  and not b.dynamicId ~= ""
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

local star
-----------------------------------------------选中的坦克显示-----------------------------------------------
function this.FormShowItem(_heroData)
    this.curCard:SetActive(true)
    local selectData = _heroData
    star = selectData.star
    local HeroConfigData = ConfigManager.TryGetConfigDataByKey("HeroConfig", "Id", selectData.id)

    SetHeroBg(this.curCardBg,this.curCardFarme,nil,selectData.star)
    -- this.curCardBg.sprite = Util.LoadSprite(GetQuantityBgImageByquality(nil,selectData.star))
    this.curCardIcon.sprite = Util.LoadSprite(selectData.painting)
    this.curCardName.text = GetLanguageStrById(selectData.name)
    this.curCardProIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(selectData.property))
    SetHeroStars(this.curCardStar,selectData.star)
    this.curCardLv.text = selectData.lv
end

function this.ToShowItem(_heroData)
    this.newCard:SetActive(true)
    this.Item:SetActive(true)
    local selectData = _heroData
    local HeroConfigData = ConfigManager.TryGetConfigDataByKey("HeroConfig", "Id", selectData.id)

    this.newCardIcon.sprite = Util.LoadSprite(selectData.painting)
    this.newCardName.text = GetLanguageStrById(selectData.name)
    this.newCardProIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(selectData.property))
    this.newCardLv.text = this.curCardLv.text

    SetHeroBg(this.newCardBg,this.newCardFarme,nil,star)
    SetHeroStars(this.newCardStar,star)
end

-----------------------------------------------转换材料显示-----------------------------------------------
function this:setData(_selectData,_selectDataList)--HeroListPopup调用
    if _selectData == nil then
        --this.formCard:SetActive(false)
        this.newCard:SetActive(false)
        this.chooseTargetItem:SetActive(false)
        this.chooseTargetempty:SetActive(true)
        _selectDataList = nil
        return
    end
    -- selectDatas=_selectData
    selectDataList = _selectDataList
    -- selectDataCount=LengthOfTable(_selectDataList)
    this.ShowBackData(_selectData)

end

--选择材料显示
function this.ShowBackData(_selectData)
    -- this.backIcon:SetActive(true)
    -- this.backNum:SetActive(true)
    this.chooseTargetItem:SetActive(true)
    this.chooseTargetempty:SetActive(false)

    local heroExchangeConfigData = ConfigManager.GetConfigDataByDoubleKey("HeroExchangeConfig", "Star", selectData.star, "Country", selectData.property)
    local returnItem = heroExchangeConfigData.Cost
    needNumber = heroExchangeConfigData.NeedNumber
    local ItemConfigDataReturn = ConfigManager.TryGetConfigDataByKey("ItemConfig", "Id", returnItem[1])
    this.Item:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(ItemConfigDataReturn.Quantity))
    this.backIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfigDataReturn.ResourceID))

    local frame = Util.GetGameObject(this.chooseTargetItem, "Frame"):GetComponent("Image")
    local icon = Util.GetGameObject(this.chooseTargetItem, "Icon"):GetComponent("Image")
    local num = Util.GetGameObject(this.chooseTargetItem, "Num"):GetComponent("Text")
    local star = Util.GetGameObject(this.chooseTargetItem, "star")
    -- local proIconBg = Util.GetGameObject(this.chooseTargetItem, "proIconBg"):GetComponent("Image")
    local proIcon = Util.GetGameObject(this.chooseTargetItem, "proIcon"):GetComponent("Image")

    frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(_selectData.heroConfig.Quality,_selectData.star))
    icon.sprite = Util.LoadSprite(GetResourcePath(_selectData.heroConfig.Icon))
    local currNum = LengthOfTable(selectDataList)
    local needNum = needNumber
    local curr = currNum >= needNum and "<color='white'>"..currNum.."</color>" or "<color='red'>"..currNum.."</color>"
    num.text = curr.."/"..needNum
    -- local starSize = Vector2.New(60,65)
    SetHeroStars(star, _selectData.star)
    proIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(_selectData.property))

    this.ToShowItem(_selectData)

    
    local ItemConfigDataReturn = ConfigManager.TryGetConfigDataByKey("ItemConfig", "Id", returnItem[1])
    this.backIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfigDataReturn.ResourceID))

    local bagNum = BagManager.GetItemCountById(ItemConfigDataReturn.Id)
    local str
    if bagNum >= returnItem[2] then
        str = bagNum .. "/" .. returnItem[2]
    else
        str = string.format("<color=#FF6868>%s</color>",bagNum) .. "/" .. returnItem[2]
    end

    this.backNum:GetComponent("Text").text = str

    Util.AddOnceClick(this.backIcon, function ()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, returnItem[1])
    end)
end

function this.InitState()
    this.curCard:SetActive(false)
    this.newCard:SetActive(false)
    this.Item:SetActive(false)
    -- this.backIcon:SetActive(false)
    -- this.backNum:SetActive(false)
    this.chooseTargetItem:SetActive(false)
    this.chooseTargetempty:SetActive(true)
end

return this