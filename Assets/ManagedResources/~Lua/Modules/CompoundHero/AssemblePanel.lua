----- 神将合成 -----
require("Base/BasePanel")
AssemblePanel = Inherit(BasePanel)
local this = AssemblePanel
local this = {}
local sortingOrder = 0
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local curIndex = 0
local curNeedHero = {}
local curSelectHero = {}
local curSelectHeroConfig = {}
local curSelectGO
local curSelectBg
local materidaIsCan = false
local tabs = {}
local needHeros = {}
local selectBtnRes = {
    [1] = "cn2-x1_AN_shuxing_xuanzhong",
    [2] = "cn2-x1_AN_shuxing_xuanzhong",
    [3] = "cn2-x1_AN_shuxing_xuanzhong",
    [4] = "cn2-x1_AN_shuxing_xuanzhong",
    [5] = "cn2-x1_AN_shuxing_xuanzhong",
    [6] = "cn2-x1_AN_shuxing_xuanzhong",
} 

function AssemblePanel:InitComponent()
    this.compoundBtn = Util.GetGameObject(self.gameObject, "titleGo/compoundBtn")
    needHeros = {}
    for i = 1, 4 do
        needHeros[i] = Util.GetGameObject(self.gameObject, "titleGo/needHero" .. i)
    end
    for i = 1, 6 do
        tabs[i] = Util.GetGameObject(self.gameObject, "BgImage/Tabs/grid/Btn" .. i)
    end
    this.selectBtn = Util.GetGameObject(self.gameObject, "BgImage/Tabs/selectBtn")
    this.heroPre = Util.GetGameObject(self.gameObject, "heroPre")

    local scroll = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "scroll").transform,
            this.heroPre, false, Vector2.New(scroll.width,scroll.height), 1, 5, Vector2.New(5,5))---v2.x*2, -v2.y*2
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1

    --up compound Hero info
    this.compoundHero = Util.GetGameObject(self.gameObject, "titleGo/compoundHero/card/card")
    this.compoundHerolv = Util.GetGameObject(this.compoundHero,"lv/Text"):GetComponent("Text")
    this.compoundHeroproBg = Util.GetGameObject(this.compoundHero,"pro"):GetComponent("Image")
    this.compoundHeropro = Util.GetGameObject(this.compoundHero,"pro/Image"):GetComponent("Image")

    this.compoundHerostarGrid = Util.GetGameObject(this.compoundHero,"star")
    this.compoundHeroname = Util.GetGameObject(this.compoundHero,"name"):GetComponent("Text")
    this.compoundHerolive = Util.GetGameObject(this.compoundHero, "icon"):GetComponent("Image")
    this.compoundHeroframe = Util.GetGameObject(self.gameObject, "titleGo/compoundHero/frame")

    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowRight})

    --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition
end

function AssemblePanel:BindEvent()
    Util.AddClick(this.compoundBtn, function()
        this.Compound(curIndex)
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Assemble,this.helpPosition.x,this.helpPosition.y-100) 
    end)
end

function AssemblePanel:AddListener()
end

function AssemblePanel:RemoveListener()
end

local sortingOrder = 0
function AssemblePanel:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
    --this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
end

local data
function AssemblePanel:OnOpen(heroData)
    if heroData then
        data = heroData
    end
end
function AssemblePanel:OnShow()
    curIndex = 0
    sortingOrder = 0
    for i = 0,#tabs - 1 do
        local index = i
        Util.GetGameObject(tabs[i + 1], "Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum2(index))
        Util.AddOnceClick(tabs[i + 1], function()
            this.HeroCompoundBtnClick(tabs[i + 1],index)
        end)
    end
    this.HeroCompoundBtnClick(tabs[1],curIndex)
    this.HeadFrameView:OnShow()
    this.upView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.HeroReplace})

    if data then
        local heroDatas = this.GetHeroDatas(curIndex)
        for index, value in ipairs(heroDatas) do
            if value.config.Id == data.Id then
                this.SelectHeroShow(value)
                curSelectHeroConfig = value
            end
        end
    end
end

--英雄类型按钮点击事件
function this.HeroCompoundBtnClick(_btn,_curIndex)
    curIndex = _curIndex
    this.selectBtn:GetComponent("Image").sprite = Util.LoadSprite(selectBtnRes[_curIndex + 1])
    this.SetBtnSelect(_btn)
    curSelectHeroConfig = nil
    this.ShowCurrPosHeroCompound()
end

--显示当前阵营的英雄
function this.ShowCurrPosHeroCompound()
    local heroDatas = this.GetHeroDatas(curIndex)
    this.SelectHeroShow(nil)
    this.ScrollView:SetData(heroDatas, function (index, go)
        this.SingleHeroDataShow(go, heroDatas[index])
    end)
    this.ScrollView:ForeachItemGO(function(index, go)
        Timer.New(function()
            go.gameObject:SetActive(true)
            PlayUIAnim(go.gameObject)
        end, 0.001 * (index - 1)):Start()
    end)
end

--显示当前阵营的英雄
function this.ShowCurrPosHeroCompound2()
    local heroDatas = this.GetHeroDatas(curIndex)
    this.ScrollView:SetData(heroDatas, function (index, go)
        this.SingleHeroDataShow(go, heroDatas[index])
    end)
    this.SelectHeroShow(curSelectHeroConfig)
end

function this.GetHeroDatas(curIndex)
    local heroDatas = this.GetAllHeroCompoundData(curIndex)
    table.sort(heroDatas, function(a, b)
        local left,right = 0,0
        if LengthOfTable(a.haveHeroList2) == a.needNum then
            left = 1
        end
        if LengthOfTable(b.haveHeroList2) == b.needNum then
            right = 1
        end

        if left == right then
            if a.star == b.star then
                return a.config.PropertyName < b.config.PropertyName
            else
                return a.star > b.star
            end
        else
            return left > right
        end
    end)
    return heroDatas
end

--设置按钮选中
function this.SetBtnSelect(_parObj)
    this.selectBtn.transform:SetParent(_parObj.transform)
    this.selectBtn.transform.localScale = Vector3.one
    this.selectBtn.transform.localPosition = Vector3.zero
end

function this.ShowTitleData(curHeroCompoundData)
    if curHeroCompoundData then
        local  _star = curHeroCompoundData.star
        local heroData = curHeroCompoundData.haveHeroList[1][1]
        local heroConfig = heroData and heroData.heroConfig or curHeroCompoundData.config
        this.compoundHero:SetActive(true)
        this.compoundHeroframe:SetActive(true)

        this.compoundHeroframe:GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(nil,_star))
        this.compoundHeroproBg.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(nil,_star))
        SetHeroStars(this.compoundHerostarGrid, _star)

        this.compoundHerolive.sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
        this.compoundHeropro.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
        this.compoundHeroname.text = GetLanguageStrById(heroConfig.ReadingName)

        if heroData then--第一位是否有英雄
            this.compoundHerolv.text = heroData.lv
        else
            this.compoundHerolv.text = 1
        end
    else
        this.compoundHero:SetActive(false)
        this.compoundHeroframe:SetActive(false)
    end
end

local upStarConsumeMaterial = {}
local upStarMaterialIsAll = {}
local curSelectUpStarData
local curSelectUpStarGo
local upStarRankUpConfig
--更新英雄进阶数据
function this.UpdateHeroUpStarData(_curUpStarData)
    --进阶吞英雄条件
    if _curUpStarData then
        upStarConsumeMaterial = {}
        upStarMaterialIsAll = {}
        for i = 1, #_curUpStarData.upStarMaterialsData do
            local  upStarMaterialsData = _curUpStarData.upStarMaterialsData[i]
            local  curUpStarData = _curUpStarData.upStarData[i]
            local go = needHeros[i + 1]
            go:SetActive(true)
            upStarConsumeMaterial[i] = {}
            upStarMaterialIsAll[i] = false
            local proImage = Util.GetGameObject(go.transform, "iconbg/proImage")
            local icon = Util.GetGameObject(go.transform,"icon")
            local frame = Util.GetGameObject(go.transform,"frame")
            local addBtn = Util.GetGameObject(go.transform,"add")
            local num = Util.GetGameObject(go.transform,"lv/num")
            local starGrid = Util.GetGameObject(go.transform, "iconbg/starGrid")
            local proBg = Util.GetGameObject(go.transform, "proBg")

            Util.GetGameObject(go.transform, "nameText"):GetComponent("Text").text = this.GetNeedHeroName(upStarMaterialsData)
            proImage:SetActive(false)
            if upStarMaterialsData.Issame == 1 or upStarMaterialsData.IsId > 0 then
                icon:SetActive(true)
                proImage:SetActive(true)
                if upStarMaterialsData.Issame == 1 then
                    icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(_curUpStarData.config.Icon))
                    frame:GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(_curUpStarData.config.Quality, upStarMaterialsData.StarLimit))
                    proImage:GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(_curUpStarData.config.PropertyName))
                    proBg:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(_curUpStarData.config.Quantity, upStarMaterialsData.StarLimit))
                elseif upStarMaterialsData.IsId > 0 then
                    local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, upStarMaterialsData.IsId)
                    icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
                    frame:GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig.Quality, upStarMaterialsData.StarLimit))
                    proImage:GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
                    proBg:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfig.Quantity, upStarMaterialsData.StarLimit))
                end
            else
                if upStarMaterialsData.IsSameClan == 1 then
                    proImage:SetActive(true)
                    proImage:GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(_curUpStarData.config.PropertyName))
                end
                icon:GetComponent("Image").sprite = Util.LoadSprite(GetNoTargetHero(upStarMaterialsData.StarLimit))
                frame:GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(nil,upStarMaterialsData.StarLimit))
                proBg:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(nil, upStarMaterialsData.StarLimit))
            end
            num:GetComponent("Text").text = string.format("<color=#FF0000FF>%s/%s</color>",0,curUpStarData[4])
            Util.SetGray(icon, true)
            SetHeroStars(starGrid, upStarMaterialsData.StarLimit)
            Util.AddOnceClick(addBtn, function()
                if not curSelectHero then return end
                curSelectUpStarData = curUpStarData
                curSelectUpStarGo = go
                local curShowHeroListData = this.SetShowHeroListData(upStarConsumeMaterial,_curUpStarData.haveHeroList3[i + 1])
                
                --参数1 显示的herolist     2 3 升当前星的规则     4 打开RoleUpStarListPanel的界面
                UIManager.OpenPanel(UIName.RoleUpStarListPanel, curShowHeroListData, upStarMaterialsData, curUpStarData, this, upStarConsumeMaterial[i], curSelectHero.heroConfig or curSelectHero)
                --UIManager.OpenPanel(UIName.RoleUpStarListPanel,curShowHeroListData,nil,nil,this,nil,curSelectHero)
            end)
        end
        if #_curUpStarData.upStarMaterialsData + 1 < 4 then
            for i = #_curUpStarData.upStarMaterialsData + 2, 4 do
                local go = needHeros[i]
                go:SetActive(false)
            end
        end

        if curSelectHero then
            --自动选择进阶妖灵师材料
            this.AutoSelectUpStarHeroList(_curUpStarData)
        end
    else
        for i = 1, #needHeros do
            needHeros[i]:SetActive(false)
        end
    end
end

--分析设置升星界面显示的英雄list数据    如果当前升星材料的坑位的英雄数据与 以其他坑位有重合并且选择上的英雄不显示  如果是当前坑位显示的英雄显示对勾
--1  消耗的总消耗组  2  当前坑位可选择的所有英雄
function this.SetShowHeroListData(upStarConsumeMaterial, curHeroList, isFirstPos)
    local curEndShowHeroListData = {}
    for i = 1, #curHeroList do
        if curHeroList[i].dynamicId ~= curSelectHero.dynamicId then
            curHeroList[i].isSelect = 2
            table.insert(curEndShowHeroListData,curHeroList[i])
        elseif isFirstPos then
            curHeroList[i].isSelect = 1
            table.insert(curEndShowHeroListData,curHeroList[i])
        end
    end
    if isFirstPos then
        return curEndShowHeroListData
    else
        for j = 1, #upStarConsumeMaterial do
            if upStarConsumeMaterial[j] and #upStarConsumeMaterial[j] > 0 then
                for k = 1, #upStarConsumeMaterial[j] do
                    if j == curSelectUpStarData[2] then--curSelectUpStarData  当前坑位选择的英雄信息
                        for _, v in pairs(curEndShowHeroListData) do
                            if v.dynamicId == upStarConsumeMaterial[j][k] then
                                v.isSelect = 1
                            end
                        end
                    else
                        for i, v in pairs(curEndShowHeroListData) do
                            if v.dynamicId == upStarConsumeMaterial[j][k] then
                                curEndShowHeroListData[i] = nil
                            end
                        end
                    end
                end
            end
        end
    end
    local curList = {}
    for _, v in pairs(curEndShowHeroListData) do
        table.insert(curList,v)
    end
    return curList
end

--升星选择祭品后刷新界面
function this.AutoSelectUpStarHeroList(_curUpStarData)
    local  curUpStarData = _curUpStarData.upStarMaterialsData
    if curUpStarData and #curUpStarData > 0 then
        for i = 1, #curUpStarData do
            curSelectUpStarData = curUpStarData[i]
            local upStarHeroListData = _curUpStarData.haveHeroList3[i + 1]
            local curSelectHeroList = {}
            if curSelectUpStarData.Issame == 1
            or curSelectUpStarData.IsId > 0
            or (curSelectUpStarData.IsSameClan == 1 and curSelectUpStarData.StarLimit == 3 and ((curSelectHero.heroConfig and curSelectHero.heroConfig.Qualiy ~= 3) or (not curSelectHero.heroConfig and curSelectHero.Qualiy ~= 3))) then
                if LengthOfTable(upStarHeroListData) >= _curUpStarData.upStarData[i][4] then
                -- curSelectUpStarGo = needHeros[i + 1]
                    for j = 1, LengthOfTable(upStarHeroListData) do
                        if #curSelectHeroList < _curUpStarData.upStarData[i][4] then
                            if upStarHeroListData[j] and upStarHeroListData[j].dynamicId and upStarHeroListData[j].lockState == 0 and (curSelectHero.heroConfig and upStarHeroListData[j].dynamicId ~= curSelectHero.dynamicId) and upStarHeroListData[j].isFormation == ""  then
                                table.insert(curSelectHeroList,upStarHeroListData[j])
                            end
                        end
                    end
                    this.UpdateUpStarPosHeroData(curSelectHeroList, _curUpStarData.upStarData[i],needHeros[i + 1])
                end
            end
        end
    end
end

--刷新当前升星坑位英雄的信息
function this.UpdateUpStarPosHeroData(curSelectHeroList,_upStarData,go)
    local upStarData = _upStarData or curSelectUpStarData
    if upStarData == nil then
        return
    end

    local curGo = go or curSelectUpStarGo
    if LengthOfTable(curSelectHeroList) < upStarData[4] then
        upStarMaterialIsAll[upStarData[2]] = 2
        Util.GetGameObject(curGo.transform,"num"):GetComponent("Text").text = string.format("<color=#FF0000FF>%s/%s</color>", LengthOfTable(curSelectHeroList),upStarData[4])

        Util.SetGray(Util.GetGameObject(curGo.transform,"icon"),true)
    else
        upStarMaterialIsAll[upStarData[2]] = 1
        -- Util.GetGameObject(curGo.transform,"add/add"):SetActive(false)
        -- Util.GetGameObject(curSelectUpStarGo.transform,"mask"):SetActive(false)
        Util.GetGameObject(curGo.transform, "lv/num"):GetComponent("Text").text = string.format("<color=#00FF06>%s/%s</color>", LengthOfTable(curSelectHeroList),upStarData[4])
        Util.SetGray(Util.GetGameObject(curGo.transform, "icon"), false)
    end
    local curUpStarConsumeMaterial = {}
    for i, v in pairs(curSelectHeroList) do
        table.insert(curUpStarConsumeMaterial, v.dynamicId)
    end
    upStarConsumeMaterial[upStarData[2]] = curUpStarConsumeMaterial
end

--刷新当前升星坑位英雄的信息
function this.UpdateUpStarPosHeroData2(curSelectHeroList,id)    
    if LengthOfTable(curSelectHeroList) < 1 then
        curSelectHero = nil
        Util.GetGameObject(curSelectUpStarGo.transform,"num"):GetComponent("Text").text = string.format("<color=#FF0000FF>%s/%s</color>", LengthOfTable(curSelectHeroList),1)
    else
        for key, value in pairs(curSelectHeroList) do       
            curSelectHero = value
            --自动选择进阶妖灵师材料
            this.compoundHerolv.text = curSelectHero.lv
        end
        Util.GetGameObject(curSelectUpStarGo.transform,"lv/num"):GetComponent("Text").text = string.format("<color=#00FF06>%s/%s</color>", LengthOfTable(curSelectHeroList),id)
        Util.SetGray(Util.GetGameObject(curSelectUpStarGo.transform,"icon"),false)
    end
end

-----本体
--更新英雄进阶数据
function this.UpdateFirstHeroUpStarData(curHeroCompoundData)
    local go = needHeros[1]
    local proImage = Util.GetGameObject(go.transform, "iconbg/proImage")
    local icon = Util.GetGameObject(go.transform,"icon")
    local frame = Util.GetGameObject(go.transform,"frame")
    local addBtn = Util.GetGameObject(go.transform,"add")
    local num = Util.GetGameObject(go.transform,"lv/num")
    local starGrid = Util.GetGameObject(go.transform, "iconbg/starGrid")

    if curSelectHero or curHeroCompoundData then
        local heroConfig = curSelectHero and curSelectHero.heroConfig or curHeroCompoundData.config
        Util.GetGameObject(go.transform, "nameText"):GetComponent("Text").text = GetLanguageStrById(heroConfig.ReadingName)
        go:SetActive(true)
        proImage:SetActive(true)
        frame:GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig.Quality, heroConfig.Star))
        proImage:GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))

        SetHeroStars(starGrid, heroConfig.Star)
        if curSelectHero and curSelectHero.heroConfig then
            num:GetComponent("Text").text = string.format("<color=#00FF06>%s/%s</color>",1,1)
            icon:GetComponent("Image").sprite = Util.LoadSprite(curSelectHero.icon)
            Util.SetGray(icon, false)
        else
            icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
            num:GetComponent("Text").text = string.format("<color=#FF0000FF>%s/%s</color>",0,1)
            Util.SetGray(icon, true)
        end
        Util.AddOnceClick(addBtn, function()
            if not curSelectHero then return end
            curSelectUpStarData = nil
            curSelectUpStarGo = go
            local curShowHeroListData = this.SetShowHeroListData(upStarConsumeMaterial, curHeroCompoundData.haveHeroList3[1], true)
            --参数1 显示的herolist     2 3 升当前星的规则     4 打开RoleUpStarListPanel的界面
            -- UIManager.OpenPanel(UIName.RoleUpStarListPanel, curShowHeroListData, upStarMaterialsData, curUpStarData, this, upStarConsumeMaterial, curSelectHero.heroConfig or curSelectHero)
            UIManager.OpenPanel(UIName.RoleUpStarListPanel, curShowHeroListData, nil, curHeroCompoundData, this, {curSelectHero.dynamicId}, curSelectHero, nil, nil, true)
        end)
    else
        needHeros[1]:SetActive(false)
    end
end

--数据显示
function this.SingleHeroDataShow(_go, _heroData)
    local go = _go
    local heroData = _heroData
    Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.config.Quality,heroData.star))
    Util.GetGameObject(go.transform, "proBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.config.Quality,heroData.star))
    Util.GetGameObject(go.transform, "lv"):SetActive(false)-- :GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.config.Icon))
    Util.GetGameObject(go.transform, "posIcon"):SetActive(false)--:GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)
    Util.GetGameObject(go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.config.PropertyName))
    local formationMask = Util.GetGameObject(go.transform, "formationMask")
    
    formationMask:SetActive(false)
    local starGrid = Util.GetGameObject(go.transform, "star")
    SetHeroStars(starGrid, heroData.star)
    local progress = Util.GetGameObject(go.transform, "progressBg/Slider"):GetComponent("Slider")
    local progressText = Util.GetGameObject(go.transform, "progressBg/progressText"):GetComponent("Text")
    local name = Util.GetGameObject(go.transform, "name"):GetComponent("Text")
    progress.value = LengthOfTable(heroData.haveHeroList2)/heroData.needNum
    progressText.text = LengthOfTable(heroData.haveHeroList2).."/"..heroData.needNum
    local cardBtn = Util.GetGameObject(go.transform, "icon")
    local choosed = Util.GetGameObject(go.transform, "choosed")
    local choosedBg = Util.GetGameObject(go.transform, "choosedBg")
    name.text = GetLanguageStrById(heroData.config.ReadingName)
    choosed:SetActive(false)
    choosedBg:SetActive(false)
    if curSelectHeroConfig and curSelectHeroConfig.config and curSelectHeroConfig.config.Id == _heroData.config.Id then
        choosed:SetActive(true)
        choosedBg:SetActive(true)
        curSelectGO = choosed
        curSelectBg = choosedBg
    end
     Util.AddOnceClick(cardBtn, function()
        if curSelectHeroConfig and curSelectHeroConfig.config then
            if curSelectHeroConfig.config.Id == _heroData.config.Id then
                choosed:SetActive(false)
                choosedBg:SetActive(false)
                curSelectHeroConfig = nil
                curSelectGO = nil
                curSelectBg = nil
                this.SelectHeroShow(nil)
            else
                curSelectHeroConfig = heroData
                if curSelectGO then
                    curSelectGO:SetActive(false)
                    curSelectBg:SetActive(false)
                end
                choosed:SetActive(true)
                choosedBg:SetActive(true)
                curSelectGO = choosed
                curSelectBg = choosedBg
                this.SelectHeroShow(curSelectHeroConfig)
            end
        else
            curSelectHeroConfig = heroData
            choosed:SetActive(true)
            choosedBg:SetActive(true)
            curSelectGO = choosed
            curSelectBg = choosedBg
            this.SelectHeroShow(curSelectHeroConfig)
        end
    end)
end

--更换本体
function this.ChangeCurHero(heroData)
    for index, value in pairs(heroData) do
        curSelectHeroConfig.haveHeroList[1][1] = value
    end
    this.SelectHeroShow(curSelectHeroConfig)
end

function this.Compound()
    if not curSelectHero or (curSelectHero and not curSelectHero.heroConfig) then
        PopupTipPanel.ShowTipByLanguageId(11852)
        return
    end
    for k, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.HeroRankupConfig)) do
        if v.Star == curSelectHero.heroConfig.Star and v.LimitStar == curSelectHero.heroConfig.Star and v.OpenStar == curSelectHero.heroConfig.Star + 1 then
            upStarRankUpConfig = v 
        end
    end
    local isUpStarMaterialsHero = true
    for i = 1, #upStarMaterialIsAll do
        if upStarMaterialIsAll[i] == 2 or upStarMaterialIsAll[i] == false then
            isUpStarMaterialsHero = false
        end
    end
    if isUpStarMaterialsHero then
        NetManager.HeroUpStarEvent(curSelectHero.dynamicId,upStarConsumeMaterial ,function (msg)
            UIManager.OpenPanel(UIName.RoleUpStarSuccessPanel,curSelectHero, upStarRankUpConfig.Id, upStarRankUpConfig.OpenLevel,function ()
                local dropItemTabs = BagManager.GetTableByBackDropData(msg)
                if #dropItemTabs > 0 then
                    --BagManager.SetDropIsSHowEquipPrint(false)
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg, 1, function ()
                        this.DeleteUpStarMaterials()
                    end)
                else
                    this.DeleteUpStarMaterials()
                end
            end)
        end)
        -- 进阶音效
        PlaySoundWithoutClick(SoundConfig.Sound_Recruit3)
    else
        PopupTipPanel.ShowTipByLanguageId(11852)
    end
end

--扣除升星 消耗的材料  更新英雄数据
function this.DeleteUpStarMaterials()
    HeroManager.UpdateSingleHeroDatas(curSelectHero.dynamicId,curSelectHero.lv,curSelectHero.star+1,curSelectHero.breakId,upStarRankUpConfig.Id,true)
    HeroManager.UpdateSingleHeroSkillData(curSelectHero.dynamicId)
    --本地数据删除材料英雄
    for i = 1, #upStarConsumeMaterial do
        for j = 1, #upStarConsumeMaterial[i] do
        end
        HeroManager.DeleteHeroDatas(upStarConsumeMaterial[i])
    end
    --刷新界面
    this.ShowCurrPosHeroCompound2()
end

function AssemblePanel:OnClose()
    curNeedHero = {}
    curSelectHero = {}
    curSelectHeroConfig = {}
    curSelectGO = nil
    curSelectBg = nil
end

function AssemblePanel:OnDestroy()
    --SubUIManager.Close(this.BtView)
    SubUIManager.Close(this.upView)
    SubUIManager.Close(this.HeadFrameView)
end

local heroRankupGroup = ConfigManager.GetConfig(ConfigName.HeroRankupGroup)
local upSortHeroList,downSoryHeroList
local allCompoundHeroConFigData = {}
--获取英雄可合成数据（所有可以英雄四星升五星  五星升六星）
function this.GetAllHeroCompoundData(index)
    upSortHeroList,downSoryHeroList = HeroManager.ByCompoundHeroGetAllHeros()
    allCompoundHeroConFigData = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.HeroConfig)) do
        if (configInfo.AfkUse == 1 or configInfo.AfkUse == 3) and
            (configInfo.Star == 4 or configInfo.Star == 5) and
            (index == 0 or configInfo.PropertyName == index) then
            local curHeroCompoundData = {}
            curHeroCompoundData.star = configInfo.Star + 1
            curHeroCompoundData.config = configInfo
            curHeroCompoundData.haveHeroList = {}--可以选择的英雄数量 [1][2][3] 无重数据
            curHeroCompoundData.haveHeroList2 = {}--可以选择的英雄数量 记数量去重用 did = didData
            curHeroCompoundData.haveHeroList3 = {}--可以选择的英雄数量 [1][2][3] 重数据
            curHeroCompoundData.needNum = 1--需要英雄数量  第一位先加上
            curHeroCompoundData.haveHeroList[1] = {}
            curHeroCompoundData.haveHeroList3[1] = {}
            curHeroCompoundData.upStarData = {}
            curHeroCompoundData.upStarMaterialsData = {}
             --其后几位加数量
             if configInfo.RankupConsumeMaterial then
                for i = 1, #configInfo.RankupConsumeMaterial do
                    if configInfo.RankupConsumeMaterial[i][1] ==  curHeroCompoundData.star then
                        curHeroCompoundData.needNum = curHeroCompoundData.needNum + configInfo.RankupConsumeMaterial[i][4]
                        curHeroCompoundData.haveHeroList[configInfo.RankupConsumeMaterial[i][2] + 1] = {}
                        curHeroCompoundData.haveHeroList3[configInfo.RankupConsumeMaterial[i][2] + 1] = {}
                        curHeroCompoundData.upStarData[i] = configInfo.RankupConsumeMaterial[i]
                        table.insert(curHeroCompoundData.upStarData,configInfo.RankupConsumeMaterial[i])
                        table.insert(curHeroCompoundData.upStarMaterialsData,heroRankupGroup[configInfo.RankupConsumeMaterial[i][3]])
                    end
                end
            end
            for key, bagHeroValue in pairs(downSoryHeroList) do
                --第一位
                -- if LengthOfTable(curHeroCompoundData.haveHeroList2) >= curHeroCompoundData.needNum then return end
                if bagHeroValue.heroConfig.Id == configInfo.Id and ((bagHeroValue.heroConfig.Star == 4 and bagHeroValue.star == 4) or (bagHeroValue.heroConfig.Star == 5 and bagHeroValue.star == 5)) then
                    if #curHeroCompoundData.haveHeroList[1] < 1 then
                        table.insert(curHeroCompoundData.haveHeroList[1],bagHeroValue)
                        curHeroCompoundData.haveHeroList2[bagHeroValue.dynamicId] = bagHeroValue
                    end
                    table.insert(curHeroCompoundData.haveHeroList3[1],bagHeroValue)
                end
            end
            this.GetAllHeroCompoundData2(configInfo,curHeroCompoundData)
            if curSelectHeroConfig and curSelectHeroConfig.config and curSelectHeroConfig.config.Id == curHeroCompoundData.config.Id then
                curSelectHeroConfig = curHeroCompoundData
            end
            table.insert(allCompoundHeroConFigData,curHeroCompoundData)
        end
    end
    table.sort(allCompoundHeroConFigData, function(a,b) 
        local lengthA = LengthOfTable(a.haveHeroList2)
        local lengthB = LengthOfTable(b.haveHeroList2)
        if ((a.needNum == lengthA) and (b.needNum == lengthB)) or ((a.needNum ~= lengthA) and (b.needNum ~= lengthB)) then
            if a.config.Star ==  b.config.Star then
                return a.config.Id <  b.config.Id
            else
                return a.config.Star < b.config.Star 
            end
        else
            return a.needNum == lengthA and not b.needNum ~= lengthB
        end
    end)
    return allCompoundHeroConFigData
end

function this.GetAllHeroCompoundData2(configInfo,curHeroCompoundData,isGet)
    if isGet then
        for i = 2, #curHeroCompoundData.haveHeroList do
            curHeroCompoundData.haveHeroList[i] = {}
            curHeroCompoundData.haveHeroList3[i] = {}
        end
        curHeroCompoundData.haveHeroList2[curHeroCompoundData.haveHeroList[1][1].dynamicId] = curHeroCompoundData.haveHeroList[1][1]
    end
    for key, bagHeroValue in pairs(upSortHeroList) do
        --其后几位
        if configInfo.RankupConsumeMaterial then
            for i = 1, #configInfo.RankupConsumeMaterial do
                if configInfo.RankupConsumeMaterial[i][1] ==  curHeroCompoundData.star then
                        local curNeedHeroData = nil
                        local heroRankUpGroup = heroRankupGroup[configInfo.RankupConsumeMaterial[i][3]]
                        if heroRankUpGroup.Issame == 1 then --需要同名卡
                            if bagHeroValue.id == configInfo.Id then
                                if bagHeroValue.star == heroRankUpGroup.StarLimit then
                                    if heroRankUpGroup.IsSameClan == 1 then
                                        if bagHeroValue.property == configInfo.PropertyName then
                                            if heroRankUpGroup.IsId > 0 then
                                                if bagHeroValue.id == heroRankUpGroup.IsId then
                                                    curNeedHeroData = bagHeroValue
                                                end
                                            else
                                                curNeedHeroData = bagHeroValue
                                            end
                                        end
                                    else
                                        if heroRankUpGroup.IsId > 0 then
                                            if bagHeroValue.id == heroRankUpGroup.IsId then
                                                curNeedHeroData = bagHeroValue
                                            end
                                        else
                                            curNeedHeroData = bagHeroValue
                                        end
                                    end
                                end
                            end
                        else
                            if bagHeroValue.star == heroRankUpGroup.StarLimit then
                                if heroRankUpGroup.IsSameClan == 1 then
                                    if bagHeroValue.property == configInfo.PropertyName then
                                        if heroRankUpGroup.IsId > 0 then
                                            if bagHeroValue.id == heroRankUpGroup.IsId then
                                                curNeedHeroData = bagHeroValue
                                            end
                                        else
                                            curNeedHeroData = bagHeroValue
                                        end
                                    end
                                else
                                    if heroRankUpGroup.IsId > 0 then
                                        if bagHeroValue.id == heroRankUpGroup.IsId then
                                            curNeedHeroData = bagHeroValue
                                        end
                                    else
                                        curNeedHeroData = bagHeroValue
                                    end
                                end
                            end
                        end
                    if #curHeroCompoundData.haveHeroList[configInfo.RankupConsumeMaterial[i][2] + 1] < configInfo.RankupConsumeMaterial[i][4] then
                        if curNeedHeroData and not curHeroCompoundData.haveHeroList2[curNeedHeroData.dynamicId] then
                            table.insert(curHeroCompoundData.haveHeroList[configInfo.RankupConsumeMaterial[i][2] + 1],curNeedHeroData)
                            curHeroCompoundData.haveHeroList2[curNeedHeroData.dynamicId] = curNeedHeroData
                        end
                    end
                    if curNeedHeroData then
                        table.insert(curHeroCompoundData.haveHeroList3[configInfo.RankupConsumeMaterial[i][2] + 1],curNeedHeroData)
                    end
                end
            end
        end
    end
    if isGet then
        return curHeroCompoundData
    end
end

--点击获取数据
function this.SelectHeroShow(curHeroCompoundData)
    if curHeroCompoundData then
        curSelectHero = curHeroCompoundData.haveHeroList[1][1] or curHeroCompoundData.config
        this.ShowTitleData(curHeroCompoundData)
        this.UpdateFirstHeroUpStarData(curHeroCompoundData)
        this.UpdateHeroUpStarData(curHeroCompoundData)
    else
        curSelectHero = nil
        this.ShowTitleData(nil)
        this.UpdateFirstHeroUpStarData(nil)
        this.UpdateHeroUpStarData(nil)
    end
end

function this.GetNeedHeroName(heroRankUpGroup)
    if curSelectHero then
        local curConFig = curSelectHero.heroConfig and curSelectHero.heroConfig or curSelectHero
        if heroRankUpGroup.Issame == 1 then --需要同名卡
            return GetLanguageStrById(curConFig.ReadingName)
        end
        if heroRankUpGroup.IsId > 0 then --需要指定id
            return GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.HeroConfig,heroRankUpGroup.IsId).ReadingName)
        end
        if heroRankUpGroup.IsSameClan == 1 then --需要是否同系
            return string.format(GetLanguageStrById(12292),tostring( heroRankUpGroup.StarLimit))
        end
    else
        return ""
    end
end

return AssemblePanel