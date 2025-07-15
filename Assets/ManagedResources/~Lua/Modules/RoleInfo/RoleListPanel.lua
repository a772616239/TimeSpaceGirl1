
local this = {}
local sortType = 1 -- 1：品阶  2：等级
local proId = 0--0全部 1机械 2体能 3魔法 4秩序 5混沌 6
local tarHero = {}
local teamHero = {}
local roleDatas = {}
this.isFirstOpen = true
local tabs = {}
local soulPrintData = {}
local orginLayer = 0
local orginLayer2 = 0
local isFristOpenTime = Timer.New()

function this:InitComponent(root)
    this.Limit = 0
    this.Buytime = 0
    self.gameObject = root
    this.BtnBack = Util.GetGameObject(self.gameObject, "rightUp/btnBack")
    this.cardPre = poolManager:LoadAsset("card", PoolManager.AssetType.GameObject)   
    this.cardPre.transform:SetParent(self.gameObject.transform)  
    this.cardPre:GetComponent("RectTransform").localScale = Vector3.New(1,1,1)
    this.cardPre:SetActive(false)
    this.btnPrant = Util.GetGameObject(self.gameObject, "Tabs")
    for i = 0, 5 do
        tabs[i] = Util.GetGameObject(self.gameObject, "Tabs/grid/Btn" .. i)
        -- Util.GetGameObject(tabs[i], "redPoint"):SetActive(false)
    end

    this.heroNumText = Util.GetGameObject(self.gameObject, "heroNum")
    this.ScrollBar = Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    this.herobutton = Util.GetGameObject(self.gameObject, "heroNum/Button")
    local v2 = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "scroll").transform,
            this.cardPre, this.ScrollBar, Vector2.New(-v2.x*2, -v2.y*2), 1, 4, Vector2.New(-5, -5))
    this.ScrollView.moveTween.MomentumAmount = 0.3
    this.ScrollView.moveTween.Strength = 1.5

    this.mask = Util.GetGameObject(self.gameObject, "mask")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    for i = 0, 5 do
        Util.AddClick(tabs[i], function()
            if this.isFirstOpen == false then
                -- if i == proId then
                --     proId = ProIdConst.All
                --     HeroManager.heroListPanelProID = ProIdConst.All
                -- else
                    proId = i
                    HeroManager.heroListPanelProID = proId
                -- end
                this:GetCurSortHeroListData()
            end
        end)
    end
    Util.AddClick(this.herobutton, function()
        local num = 100 + this.Buytime * 50

        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.AlameinBuy,function()            
            if BagManager.GetItemCountById(16) >= num then
                if this.Limit < 999 then
                    NetManager.BuyBackpackLimitRequest()
                    NetManager.BackpackLimitRequest(function(msg)
                    if this.Limit ~= msg.backpackLimitCount then 
                        PopupTipPanel.ShowTipByLanguageId(22702)
                    end    
                    this.Limit = msg.backpackLimitCount
                    this.heroNumText:GetComponent("Text").text = "<size=36><color=#45D675><B>" .. #tarHero .. "</B></color></size>/" .. msg.backpackLimitCount                        
                    this.Buytime = msg.hasBuyCount
                    end)
                else               
                    PopupTipPanel.ShowTipByLanguageId(50136)
                end
            else              
                    PopupTipPanel.ShowTipByLanguageId(11139)               
            end
        end,16,string.format(GetLanguageStrById(22703), num))

        -- local num = 100 + this.Buytime * 50
        -- MsgPanel.ShowTwo(string.format(GetLanguageStrById(22703), num),nil,function ()
        --     if BagManager.GetItemCountById(16) >= num then
        --         if this.Limit < 999 then
        --             NetManager.BuyBackpackLimitRequest()
        --             NetManager.BackpackLimitRequest(function(msg)
        --             this.Limit = msg.backpackLimitCount
        --             this.heroNumText:GetComponent("Text").text = "<size=36><color=#45D675><B>" .. #tarHero .. "</B></color></size>/" .. msg.backpackLimitCount
        --             PopupTipPanel.ShowTipByLanguageId(22702)
        --             this.Buytime = msg.hasBuyCount
        --         end)
        --         else
        --             PopupTipPanel.ShowTipByLanguageId(50136)
        --         end
        --     else
        --         PopupTipPanel.ShowTipByLanguageId(11139)
        --     end
        -- end)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Formation.OnFormationChange, this.UpdateShow)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnFormationChange, this.UpdateShow)
end

function this:OnSortingOrderChange(sortingOrder)
    self.sortingOrder = sortingOrder
    this.ScrollView:ForeachItemGO(function (index, go)
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer)
    end)
    orginLayer = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function this:OnShow()
    NetManager.BackpackLimitRequest(function(msg)
        this.Limit = msg.backpackLimitCount
        this.Buytime = msg.hasBuyCount
        this.heroNumText:GetComponent("Text").text = "<size=36><color=#45D675><B>"..#tarHero .. "</B></color></size>/" .. this.Limit
    end)
    --检测成员红点
    CheckRedPointStatus(RedPointType.Role)
    CheckRedPointStatus(RedPointType.LineupRecommend)
    CheckRedPointStatus(RedPointType.HeroTab)

    tarHero = HeroManager.GetAllHeroDatasAndZero()--特殊处理 可以包括万能卡
    teamHero = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_NORMAL)
    this.isFirstOpen = true
    this.mask:SetActive(true)

    this.heroNumText:GetComponent("Text").text = "<size=36><color=#45D675><B>"..#tarHero .. "</B></color></size>/" .. this.Limit

    sortType = HeroManager.heroListPanelSortID
    proId = HeroManager.heroListPanelProID
    this:GetCurSortHeroListData()

    if this.ScrollView then
        this.ScrollView:SetIndex(1)
    end

    Timer.New(function() self:SetSelectBtn() end, 0.1, 1):Start()
end

function this:UpdateShow()
    CheckRedPointStatus(RedPointType.Role)

    tarHero = HeroManager.GetAllHeroDatas()
    teamHero = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_NORMAL)
    this.isFirstOpen = false
    this.mask:SetActive(false)
    this.heroNumText:GetComponent("Text").text = "<size=36><color=#45D675><B>"..#tarHero .. "</B></color></size>/" .. this.Limit

    sortType = HeroManager.heroListPanelSortID
    proId = HeroManager.heroListPanelProID
    this:GetCurSortHeroListData()

    if this.ScrollView then
        this.ScrollView:SetIndex(1)
    end
end

--组合当前选项数据
function this:GetCurSortHeroListData()
    local heros = {}
    if proId ~= ProIdConst.All then
        heros = HeroManager.GetHeroDataByProperty(proId)
    else
        heros = tarHero
    end

    this:SetRoleList(heros)
    this:SetSelectBtn()
end

--设置英雄列表数据
function this:SetRoleList(_roleDatas)
    roleDatas = _roleDatas
    this:SortHeroDatas(_roleDatas)

    -- --上阵英雄数量
    -- this.upZhenNum = 0
    -- for i = 1, #_roleDatas do
    --     if teamHero[_roleDatas[i].dynamicId] then
    --         this.upZhenNum = this.upZhenNum + 1
    --     end
    -- end

    HeroManager.heroSortedDatas = roleDatas
    this.heroNumText:GetComponent("Text").text = "<size=36><color=#45D675><B>"..#_roleDatas .. "</B></color></size>/" .. this.Limit

    this.ScrollView:SetData(_roleDatas, function (index, go)
        if this.isFirstOpen then
            go.gameObject:SetActive(false)
        end
        this.SingleHeroDataShow(go, roleDatas[index])
    end)
    if this.isFirstOpen then
        this.ScrollView:ForeachItemGO(function (index, go)
            Timer.New(function ()
                go.gameObject:SetActive(true)
                PlayUIAnim(go.gameObject)
            end, 0.03*(index-1)):Start()
        end)
        if isFristOpenTime then
            isFristOpenTime:Stop()
            isFristOpenTime = nil
        end
        isFristOpenTime = Timer.New(function()
            this.isFirstOpen = false
            this.mask:SetActive(false)
        end, 0.8):Start()
    end
    this.ScrollView:ForeachItemGO(function (index, go)
        Util.AddParticleSortLayer(go, orginLayer - orginLayer2)
    end)
    orginLayer2 = self.sortingOrder
    orginLayer = self.sortingOrder
end

function this.SingleHeroDataShow(_go,_heroData)
    local heroData = _heroData

    SetHeroBg(Util.GetGameObject(_go.transform, "card/bg"), Util.GetGameObject(_go.transform, "card/frame"), heroData.heroConfig.Quality, _heroData.star)
    Util.GetGameObject(_go.transform, "card/lv"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(_go.transform, "card/icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.painting)
    Util.GetGameObject(_go.transform, "card/pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    Util.GetGameObject(_go.transform, "card/bg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityBgImageByquality(heroData.heroConfig.Quality,_heroData.star))

    local redPoint = Util.GetGameObject(_go.transform, "card/sign/redPoint")
    Util.GetGameObject(_go.transform, "card/sign/lock"):SetActive(heroData.lockState == 1)
    local starGrid = Util.GetGameObject(_go.transform, "star")
    SetHeroStars(starGrid, heroData.star)
    SoulPrintManager.UnLockSoulPrintPos(heroData)
    if teamHero[heroData.dynamicId] ~= nil then
        Util.GetGameObject(_go.transform, "sign/choosed"):SetActive(true)
        --角色右上角的红点
        redPoint:SetActive(HeroManager.GetCurHeroIsShowRedPoint(heroData))
    else
        --角色右上角的红点
        -- redPoint:SetActive(HeroManager.GetCurHeroIsShowRedPoint(heroData))
        -- redPoint:SetActive(false)

        --单个所有英雄红点判断
        --redPoint:SetActive(HeroManager.GetIsHeroAlternativeRedPoint(heroData))
        redPoint:SetActive(false)
        Util.GetGameObject(_go.transform, "card/sign/choosed"):SetActive(false)
    end

    

    Util.GetGameObject(_go.transform, "card/sign/core"):SetActive(heroData.heroConfig.HeroValue == 1)
    Util.AddOnceClick(Util.GetGameObject(_go.transform, "card"), function()
        this.OnClickEnterHeroInfo(heroData, HeroManager.heroSortedDatas,teamHero[heroData.dynamicId] ~= nil)
    end)
end

function this:SetSelectBtn()
    for key, value in pairs(tabs) do
        value:GetComponent("Image").sprite = Util.LoadSprite(X1CampTabSelectPic[key])
        Util.GetGameObject(value.transform, "Image"):SetActive(key == proId)
    end 
end

function this:SortHeroDatas(_heroDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if (teamHero[a.dynamicId] and teamHero[b.dynamicId]) or (not teamHero[a.dynamicId] and not teamHero[b.dynamicId]) then
            if sortType == SortTypeConst.Lv then
                if a.lv == b.lv then
                    if a.heroConfig.Quality == b.heroConfig.Quality then--Natural
                        if a.star == b.star then
                            if a.warPower == b.warPower then
                                if a.heroConfig.Natural == b.heroConfig.Natural then--Natural
                                    return a.heroConfig.Id < b.heroConfig.Id
                                else
                                    return a.heroConfig.Natural > b.heroConfig.Natural
                                end
                            else
                                return a.warPower > b.warPower
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
            elseif sortType == SortTypeConst.Natural then
                if a.heroConfig.Quality == b.heroConfig.Quality then--Natural
                    if a.star == b.star then
                        if a.lv == b.lv then
                                if a.warPower == b.warPower then
                                    if a.heroConfig.Natural == b.heroConfig.Natural then--Natural
                                        return a.heroConfig.Id < b.heroConfig.Id
                                    else
                                        return a.heroConfig.Natural > b.heroConfig.Natural
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
             end
        else
            return teamHero[a.dynamicId] and not teamHero[b.dynamicId]
        end
    end)
end

function this.OnClickEnterHeroInfo(_curhero, _heros,isUpZhen)
    UIManager.OpenPanel(UIName.RoleInfoPanel, _curhero, _heros, isUpZhen)--,this.upZhenNum)
end

function this.GetRoleItemByName(name)
    local targetItem
    this.ScrollView:ForeachItemGO(function (index, go)
        local itemName = Util.GetGameObject(go.transform, "card/name"):GetComponent("Text").text
        if Util.GetGameObject(go.transform, "card/sign/choosed").activeInHierarchy then
            if not targetItem and name == itemName then
                targetItem = go
                return
            end
        end
        if not targetItem and name == itemName then
            targetItem = go
        end
    end)
    return targetItem
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    proId = 0--面板关闭时 重置筛选按钮为全部
    if isFristOpenTime then
        isFristOpenTime:Stop()
        isFristOpenTime = nil
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    ClearRedPointObject(RedPointType.Setting, this.headRedpot)
    ClearRedPointObject(RedPointType.VipPrivilege, this.vipRedPoint)

    this.ScrollView = nil
end

return this