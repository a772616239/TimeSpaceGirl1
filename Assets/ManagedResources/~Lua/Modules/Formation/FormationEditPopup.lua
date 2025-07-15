require("Base/BasePanel")
FormationEditPopup = Inherit(BasePanel)
local this = FormationEditPopup

local chooseIndex = 0
local choosedList = {}
local deleteList = {}
local curFormationIndex
local order = 0
-- local orderImageTextList={}
-- 妖灵师等级限制显示
local _LimitLevel = 0
local _LimitNum = 0
local _BloodList = nil

-- local curFormation
local sortType = 1 -- 1：品阶  2：等级
local proId = 0--0 全部  1 火 2风 3 水 4 地
local tabs = {}--筛选按钮
local maxNum = 5 --最大上阵人数
local goList = {} --当前英雄对应预设的集合
local func = nil --回调

local healHero = {}--需要忽略的神将id

function FormationEditPopup:InitComponent()
    this.BgMask = Util.GetGameObject(this.gameObject, "BgMask")
	this.BtnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.BtnSure = Util.GetGameObject(this.gameObject, "bg/btnSure")
    this.allBtn = Util.GetGameObject(this.gameObject,"bg/allBtn")

    this.cardPre = Util.GetGameObject(this.gameObject, "item")
    this.grid = Util.GetGameObject(this.gameObject, "bg/scroll")
    this.desc = Util.GetGameObject(this.gameObject,"bg/desc"):GetComponent("Text")

    --筛选按钮
    for i = 0, 5 do
        tabs[i] = Util.GetGameObject(this.gameObject, "bg/Tabs/Grid/Btn" .. i)
    end
    this.selectBtn = Util.GetGameObject(this.gameObject, "bg/Tabs/SelectBtn")

    this.ShaiXuanBtn = Util.GetGameObject(self.gameObject, "bg/ShaiXuanBtn")
    this.ShaiXuanBtnLv = Util.GetGameObject(self.gameObject, "bg/ShaiXuanBtn/Lv")
    this.ShaiXuanBtnQu = Util.GetGameObject(self.gameObject, "bg/ShaiXuanBtn/Qu")

    this.ScrollBar = Util.GetGameObject(self.gameObject, "bg/Scrollbar"):GetComponent("Scrollbar")

    local scroll =  Util.GetGameObject(self.gameObject, "scroll").transform
    local rect = scroll.rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, scroll,
            this.cardPre, this.ScrollBar, Vector2.New(rect.width, rect.height), 1, 5, Vector2.New(5, 5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    -- this.isHaveInTeam = false
    healHero = string.split(ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig,"Id",86).Value,"|")
end
--是否是治疗神将
function FormationEditPopup:isNotHealHero(hero)
    for i = 1, #healHero do
        if hero.id == tonumber(healHero[i]) then
            return false
        end
    end
    return true
end

function FormationEditPopup:BindEvent()
    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out,0)
        self:ClosePanel()
    end)
	Util.AddClick(this.BgMask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out,0)
        self:ClosePanel()
    end)

    --选定按钮
    Util.AddClick(this.BtnSure, function()
        local go = function()
            local dids = {}
            local list = {}
            for i, v in ipairs(choosedList) do
                table.insert(dids,v.did)
                table.insert(list, {heroId = v.did, position=v.position})
            end
            if #choosedList <= maxNum and #choosedList > 0 then
            NetManager.TrialHeroInfoSaveRequest(dids,function()
                PopupTipPanel.ShowTipByLanguageId(10669)
                if func ~= nil then --保存完毕后 将英雄did合集传递过去 此时我拥有这些英雄 不用担心英雄已被删除
                    func(dids)
                end
                PlayerPrefs.SetInt(PlayerManager.uid.."Trial",1)--设置森罗红点关
                CheckRedPointStatus(RedPointType.Trial)
                -- FormationManager.RefreshFormation(FormationTypeDef.FORMATION_DREAMLAND,choosedList,
                -- FormationManager.formationList[FormationTypeDef.FORMATION_DREAMLAND].teamPokemonInfos)
    
                --> 暂时不能上支援和副官 编队为1 后期todo
                FormationManager.RefreshFormation(FormationTypeDef.FORMATION_AoLiaoer, list,"",
                    { supportId = 0,
                    adjutantId = 0 },
                    nil,
                    1)
                self:ClosePanel()
                -- TrialMapPanel.CheckTrialHeroInfo()
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(12323)
        end
        end

        if #choosedList < maxNum and #choosedList > 0 then
            MsgPanel.ShowTwo(GetLanguageStrById(10670), nil, function()
                go()
            end)
        else
            go()
        end
    end)

    --一键选择
    Util.AddClick(this.allBtn,function()
        for i, v in pairs(goList) do --先关闭全部选择项 清空选择列表
            Util.GetGameObject(v, "choosed"):SetActive(false)
            Util.GetGameObject(v, "select"):SetActive(false)
        end
        choosedList = {}
        --按战力从大到小排序
        local heros = {}
        if proId == ProIdConst.All then
            heros = HeroManager.GetAllHeroDatas(_LimitLevel)
        else
            heros = HeroManager.GetHeroDataByProperty(proId, _LimitLevel)
        end
        table.sort(heros,function(a,b)
            local aWarPower = HeroManager.CalculateHeroAllProValList(1,a.dynamicId,false)[HeroProType.WarPower]
            local bWarPower = HeroManager.CalculateHeroAllProValList(1,b.dynamicId,false)[HeroProType.WarPower]
            if aWarPower == bWarPower then
                return a.id > b.id
            else
                return aWarPower > bWarPower
            end
        end)
        --将战力前5英雄选中赋值
        for index, value in ipairs(heros) do
            local go
            local isNotHeal = self:isNotHealHero(heros[index])
            for k, v in pairs(goList) do
                if k and heros[index] and k == heros[index].dynamicId and isNotHeal then --goList的键值是英雄did 若它与当前英雄列表中的did相等
                    go = Util.GetGameObject(v, "choosed")
                    Util.GetGameObject(v, "select"):SetActive(true)
                    go.gameObject:SetActive(true)
                end
            end
            order = order + 1
            if heros[index] and isNotHeal then --若存在该索引 就插入数据（当我筛选某一元素时，该元素英雄长度可能不为5）
                table.insert(choosedList,{did = heros[index].dynamicId, choosed = go,position = order})
            end
            if #choosedList == 5 then
                break
            end
        end

        this.RefreshDesc()
    end)

    --筛选按钮
    for i = 0, 5 do
        Util.AddClick(tabs[i], function()
            if i == proId then
                proId = ProIdConst.All
            else
                proId = i
            end
            this.OnClickTabBtn(proId)
        end)
    end

    --品阶等级筛选
    Util.AddClick(this.ShaiXuanBtn, function()
        if sortType == SortTypeConst.Lv then
            sortType = SortTypeConst.Natural
        else
            sortType = SortTypeConst.Lv
        end
        this.ShaiXuanBtnLv:SetActive(sortType ~= SortTypeConst.Lv)
        this.ShaiXuanBtnQu:SetActive(sortType ~= SortTypeConst.Natural)
        this.OnClickTabBtn(proId)
    end)
end

function FormationEditPopup:AddListener()
end

function FormationEditPopup:RemoveListener()
end

function FormationEditPopup:OnOpen(...)
    local args = {...}
    func = args[1]

    choosedList = {}

    order = 0
    sortType = SortTypeConst.Lv
    proId = ProIdConst.All
    this.OnClickTabBtn(proId)
    this.ShaiXuanBtnLv:SetActive(sortType ~= SortTypeConst.Lv)
    this.ShaiXuanBtnQu:SetActive(sortType ~= SortTypeConst.Natural)
    local forMationData = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_AoLiaoer)
end

function FormationEditPopup:OnClose()

end

function FormationEditPopup:OnDestroy()
    this.ScrollView = nil
end

--点击页签__根据sortType和职业属性/类型进行排序
function this.OnClickTabBtn(_proId)
    local heros
    if _proId == ProIdConst.All then
        heros = HeroManager.GetAllHeroDatas(_LimitLevel)
    else
        heros = HeroManager.GetHeroDataByProperty(_proId, _LimitLevel)
    end
    this.SetRoleList(heros)
    this.RefreshDesc()
    this:SetSelectBtn()
end

--设置英雄列表数据
function this.SetRoleList(_roleDatas)
    this:SortHeroDatas(_roleDatas)

    if sortType == SortTypeConst.Natural then
        table.sort(_roleDatas,function(a,b)
            local aWarPower = HeroManager.CalculateHeroAllProValList(1,a.dynamicId,false)[HeroProType.WarPower]
            local bWarPower = HeroManager.CalculateHeroAllProValList(1,b.dynamicId,false)[HeroProType.WarPower]
            if a.Quality == b.Quality then
                return aWarPower > bWarPower
            else
                return a.Quality > b.Quality
            end
        end)
    end

    goList = {}

    -- local itemList = {}
    this.ScrollView:SetData(_roleDatas, function(index, go)
        this.SingleHeroDataShow(go, _roleDatas[index])
        -- itemList[index] = go
    end)
    -- this.DelayCreation(itemList)
end

--[[
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
]]

--设置单个英雄数据
function this.SingleHeroDataShow(_go, _heroData)
    local heroData = _heroData
    local go = _go
    goList[heroData.dynamicId] = go
    local choosed = Util.GetGameObject(go, "choosed")
    choosed:SetActive(false)
    local select = Util.GetGameObject(go, "select")
    select:SetActive(false)
    for i,v in ipairs(choosedList) do
        if heroData.dynamicId == v.did then
            choosed:SetActive(true)
            select:SetActive(true)
        end
    end

    Util.GetGameObject(go, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.icon)
    Util.GetGameObject(go, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    Util.GetGameObject(go, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    Util.GetGameObject(go, "proBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(go, "lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroData.heroConfig.Quality,heroData.star))

    --剩余血量 无尽副本才显示
    local hpExp = Util.GetGameObject(go, "hpExp")
    local heroHp = FormationManager.GetFormationHeroHp(curFormationIndex, heroData.dynamicId)
    local starGrid = Util.GetGameObject(go, "star")
    local starPre = Util.GetGameObject(go, "starPre")
    SetHeroStars(starGrid, heroData.star)
    this.SetHeroBlood(hpExp, heroHp, go)
    --hpExp:SetActive(false)
    --hpExp:GetComponent("Slider").value = 0.5
    -- Click On
    Util.AddOnceClick(go, function()
        for k, v in ipairs(choosedList) do
            if v.did == heroData.dynamicId then
                --选择的条目已存在，移除选择的item
                choosed:SetActive(false)
                select:SetActive(false)
                -- orderImage:SetActive(false)
                -- orderImageText.text=""
                table.remove(choosedList,k)
                order = order - 1
                -- table.remove(orderImageTextList,k)
                chooseIndex = v.position

                for i,v in ipairs(choosedList) do
                    if choosedList[i].position > chooseIndex then
                        choosedList[i].position = v.position - 1
                    end
                end
                this.OnClickTabBtn(proId)
                return
            end
        end
        -- 当前可选的最大上阵人数
        -- maxNum = 5--ActTimeCtrlManager.MaxArmyNum()
        if #choosedList >= maxNum then
            -- if maxNum < 5 then
            --     PopupTipPanel.ShowTip(ActTimeCtrlManager.NextArmCondition())
            -- end
            PopupTipPanel.ShowTipByLanguageId(10671)
            return
        end

        -- 判断是否有血量
        if heroHp and heroHp <= 0 then PopupTipPanel.ShowTipByLanguageId(10672) return end

        choosed:SetActive(true)
        select:SetActive(true)
        -- orderImage:SetActive(true)
        order = order + 1
        table.insert(choosedList, {did = heroData.dynamicId, choosed = choosed, position=order})
        -- table.insert(orderImageTextList,orderImageText)
        this.OnClickTabBtn(proId)
        choosedList[heroData.dynamicId] = choosed
    end)

    Util.AddLongPressClick(go, function()
        UIManager.OpenPanel(UIName.RoleInfoPopup, heroData)
    end, 0.5)
end

--刷新描述信息
function this.RefreshDesc()
    this.desc.text = string.format(GetLanguageStrById(10673),maxNum,#choosedList,maxNum)
end

-- 设置妖灵师血量
function this.SetHeroBlood(hpExp, heroHp, go)
    if heroHp then
        hpExp:SetActive(true)
        hpExp:GetComponent("Slider").value = heroHp
        Util.SetGray(go, heroHp <= 0)
    else
        hpExp:SetActive(false)
    end
end

function this:SortHeroDatas(_heroDatas)
    local choosed = {}
    local dieHeros = {}
    -- local curFormation = FormationManager.GetFormationByID(curFormationIndex)
    for i = 1, #_heroDatas do
        local heroHp = FormationManager.GetFormationHeroHp(curFormationIndex, _heroDatas[i].dynamicId)
        if heroHp then
            if heroHp <= 0 then
                dieHeros[_heroDatas[i].dynamicId] = _heroDatas[i].dynamicId
            end
        end
    end
    -- for j = 1, #curFormation.teamHeroInfos do
    --     local teamInfo = curFormation.teamHeroInfos[j]
    --     choosed[teamInfo.heroId] = j
    -- end

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
                                if a.id == b.id then
                                    return a.sortId > b.sortId
                                else
                                    return a.id > b.id
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
                                if a.id == b.id then
                                    return a.sortId > b.sortId
                                else
                                    return a.id > b.id
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

function this.OnClickEnterHeroInfo(_curhero, _heros)
    UIManager.OpenPanel(UIName.RoleInfoPanel, _curhero, _heros)
end

function this:SetSelectBtn()
    for key, value in pairs(tabs) do
        if key == proId then
            -- value:GetComponent("Image").sprite = Util.LoadSprite(CampTabSelectPic[key][2])
            this.selectBtn.transform:SetParent(value.transform)
            this.selectBtn:GetComponent("RectTransform").localPosition = Vector3.zero
            this.selectBtn:GetComponent("RectTransform").localScale = Vector3.one
        else
            -- value:GetComponent("Image").sprite = Util.LoadSprite(CampTabSelectPic[key][1])
        end
    end
end

return FormationEditPopup