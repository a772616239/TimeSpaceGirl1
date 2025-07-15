----- 神将置换 -----
local this = {}
local sortingOrder = 0
local tabs = {}
local curIndex = 0
local curSelectHero = {}
local curSelectHeroConfig = {}
local heroSelectBtn = {}
local heroDatas
local t
local replaceItemIdConfig = ConfigManager.GetConfigData(ConfigName.SpecialConfig,68)
local replaceCostConfig = ConfigManager.GetConfigData(ConfigName.SpecialConfig,69)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local btnBack
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

local selectBtnRes = {
    [1] = GetPictureFont("cn2-X1_tongyong_zhenying_01"),
    [2] = "cn2-X1_tongyong_zhenying_04",
    [3] = "cn2-X1_tongyong_zhenying_02",
    [4] = "cn2-X1_tongyong_zhenying_03",
    [5] = "cn2-X1_tongyong_zhenying_06",
    [6] = "cn2-X1_tongyong_zhenying_05",
}
function this:InitComponent(gameObject)
    this.gameObject = gameObject
    this.heroPre = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/item")
    this.replaceBtn = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/content/cost")
    this.saveBtn = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/replaceBg/btns/saveBtn")
    this.cancelBtn = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/replaceBg/btns/cancelBtn")
    this.bgCenter = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/bg/bgCenter")
    this.segmentation = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/bg")
    for i = 1, 6 do
        tabs[i] = Util.GetGameObject(this.segmentation, "Tabs/bgCenter/Grid/Btn" .. i)
    end
    this.selectBtn = Util.GetGameObject(this.segmentation, "Tabs/SelectBtn")
    this.selectBtn:SetActive(true)
    this.ScrollBar = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/Scrollbar"):GetComponent("Scrollbar")

    local parent = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/scroll")
    local v2  = parent:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,parent.transform,
    this.heroPre, this.ScrollBar, Vector2.New(-v2.x*2, v2.height), 1, 4, Vector2.New(10,10))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1

    --need -> replaceHero Info
    this.needHero = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/heros/needHero")
    this.lihuiPos = Util.GetGameObject(this.needHero.transform,"lihui")
    this.replaceHero = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/heros/replacedHero")
    this.newlihuiPos = Util.GetGameObject(this.replaceHero.transform,"lihui")


    this.curHero = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/replaceBg/cur")
    this.newHero = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/replaceBg/new")

    -- this.needBg = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/bg/top/heroPlace1") -- m5
    this.replaceBg = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/replaceBg")

    this.text = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/content/Text")
    this.cost = Util.GetGameObject(gameObject, "CompoundHeroPanel_Replace/content/cost")
    this.costImage = Util.GetGameObject(this.cost, "Image"):GetComponent("Image")
    this.costText = Util.GetGameObject(this.cost,"Text"):GetComponent("Text")
    this.btns = Util.GetGameObject(gameObject,"CompoundHeroPanel_Replace/replaceBg/btns")
    this.btns2 = Util.GetGameObject(gameObject,"CompoundHeroPanel_Replace/bg/Image (1)/btns2")
    this.btnBack = Util.GetGameObject(gameObject,"btnBack")
end

function this:BindEvent()
    --置换
    Util.AddClick(this.replaceBtn,function()
        if not curSelectHero.id then
            PopupTipPanel.ShowTipByLanguageId(12315)
        elseif curSelectHero.id and (t > BagManager.GetTotalItemNum(tonumber(replaceItemIdConfig.Value))) then
            PopupTipPanel.ShowTipByLanguageId(10455)
        else
            NetManager.SaveHeroChangeRequest(curSelectHero.dynamicId,function (msg)
                HeroManager.ResetHeroChangeId(curSelectHero.dynamicId,msg.heroTempId)--改变英雄changeId

                -- this.replaceHero:SetActive(true)
                this.cancelBtn:SetActive(true)
                -- this.replaceBtn:SetActive(false)
                this.saveBtn:SetActive(true)
                -- this.needBg:SetActive(false)
                this.replaceBg:SetActive(true)
                -- this.text:SetActive(false)
                -- this.cost:SetActive(false)

                this.ShowCostInfo()
                -- this.btns:SetActive(true)
                this.btnBack:SetActive(false)
                this.btns2:SetActive(false)

                local value = this.RebuildData(msg.heroTempId,curSelectHero)
                --print(value)
                --Util.GetGameObject(this.newHero,"icon"):GetComponent("Image").sprite = Util.LoadSprite(curSelectHero.painting)
                this.SetHero(this.newHero,value)
                this.replaceBtn:SetActive(false)

                Util.ClearChild(this.newlihuiPos.transform)
                LoadHerolive(HeroConfig[value.id],this.newlihuiPos)
            end)
        end
    end)
    --取消
    Util.AddClick(this.cancelBtn,function()
        NetManager.CancelHeroChangeRequest(curSelectHero.dynamicId,function (msg)
            HeroManager.ResetHeroChangeId(curSelectHero.dynamicId)--改变英雄changeId

            -- this.replaceHero:SetActive(false)
            -- this.needHero:SetActive(true)
            this.cancelBtn:SetActive(false)
            -- this.replaceBtn:SetActive(true)
            this.saveBtn:SetActive(false)
            -- this.needBg:SetActive(false)
            this.replaceBg:SetActive(false)
            -- this.text:SetActive(false)
            -- this.cost:SetActive(true)
            -- this.btns:SetActive(false)
            this.btnBack:SetActive(true)
            this.btns2:SetActive(true)

            this.ShowCostInfo()
            this.replaceBtn:SetActive(true)

            Util.ClearChild(this.newlihuiPos.transform)
        end)
    end)
    --保存置换
    Util.AddClick(this.saveBtn,function()
        NetManager.DoHeroChangeRequest(curSelectHero.dynamicId,function (msg)
            Util.ClearChild(this.lihuiPos.transform)
            Util.ClearChild(this.newlihuiPos.transform)
            
            this.ShowCostInfo()
            HeroManager.DeleteHeroDatas({curSelectHero.dynamicId})
            for i = 1, #msg.drop.Hero do
                HeroManager.UpdateHeroDatas(msg.drop.Hero[i])
                ExpeditionManager.InitHeroHpValue(msg.drop.Hero[i].id)
            end
            
            curSelectHero = HeroManager.GetSingleHeroData(msg.drop.Hero[1].id)
            this.ShowCurrPosHeroReplace(curIndex)
            this.replaceBg:SetActive(false)
            this.saveBtn:SetActive(false)
            this.btnBack:SetActive(true)
            this.replaceBtn:SetActive(false)
            this.cancelBtn:SetActive(false)
            this.btns2:SetActive(true)
            this.replaceBtn:SetActive(true)
        end)
    end)

end

--通过Id 重新组成数据
function this.RebuildData(id,curHero)
    local herodata = {}
    herodata.id = HeroConfig[id].Id
    herodata.name = GetLanguageStrById(HeroConfig[id].ReadingName)
    herodata.live = GetResourcePath(HeroConfig[id].Live)
    herodata.star = HeroConfig[id].Star
    herodata.lv = curHero.lv
    herodata.quality = HeroConfig[id].Quality
    herodata.profession = HeroConfig[id].Profession
    herodata.scale = HeroConfig[id].Scale
    herodata.position = HeroConfig[id].Position
    herodata.property = HeroConfig[id].PropertyName
    herodata.painting = GetResourcePath(HeroConfig[herodata.id].Painting)

    return herodata
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end

function this:OnShow(...)
    curIndex = 0
    sortingOrder = 0
    for i = 0,#tabs - 1 do
        local index=i
        Util.GetGameObject(tabs[i + 1], "Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(index))
        Util.AddOnceClick(tabs[i + 1], function()
            curSelectHero = {}
            if index == curIndex then
                curIndex = 0
                this.HeroReplaceBtnClick(tabs[1],curIndex)
            else
                this.HeroReplaceBtnClick(tabs[i + 1],index)
            end
        end)
    end
    this.HeroReplaceBtnClick(tabs[1],curIndex)
end

--英雄类型按钮点击事件
function this.HeroReplaceBtnClick(_btn,_curIndex)
    curIndex = _curIndex
    this.selectBtn:GetComponent("Image").sprite=Util.LoadSprite(selectBtnRes[_curIndex+1])
    this.SetBtnSelect(_btn)
    this.ShowCurrPosHeroReplace(_curIndex)
end

--显示当前阵营的英雄
function this.ShowCurrPosHeroReplace(_curIndex)
    heroDatas = this.GetHeroDataByPosition(_curIndex)
    -- local itemList = {}
    this.ScrollView:SetData(heroDatas, function (index, go)
        this.SingleHeroDataShow(go, heroDatas[index])
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

--通过职业筛选英雄
function this.GetHeroDataByPosition(_position)
    local heros = {}
    local index = 1
    for i, v in pairs(HeroManager.ByReplaceHeroGetAllHeros()) do
        if HeroConfig[v.id].PropertyName~=4 and HeroConfig[v.id].PropertyName~=5 then
        if HeroConfig[v.id].PropertyName == _position or _position == 0 then --0 全职业
            heros[index] = v
            index = index + 1
        end
    end
    end
    return heros
end

local oldChoose
--数据显示
function this.SingleHeroDataShow(_go,_heroData)
    local go = _go
    local heroData = _heroData

    Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(HeroConfig[heroData.id].Quality,heroData.star))
    -- Util.GetGameObject(go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go.transform, "LvText"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.icon)
    Util.GetGameObject(go.transform, "posIcon"):SetActive(false)
    Util.GetGameObject(go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(HeroConfig[heroData.id].PropertyName))
    Util.GetGameObject(go.transform, "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(HeroConfig[heroData.id].Quality,heroData.star))
    Util.GetGameObject(go.transform, "Text"):GetComponent("Text").text = GetLanguageStrById(heroData.name)

    local formationMask = Util.GetGameObject(go.transform, "formationMask")
    -- local formationImage = Util.GetGameObject(go.transform, "formationMask/formationImage/upImage"):GetComponent("Image")
    if heroData.isFormation ~= "" then
    --if LengthOfTable(heroData.formationList) ~= 0 then
        formationMask:SetActive(true)
        --formationImage.sprite = Util.LoadSprite("t_tongyong-yishangzheng")
    elseif heroData.lockState == 1 then
        formationMask:SetActive(true)
        --formationImage.sprite = Util.LoadSprite("r_hero_suodi_yisuoding")
    else
        formationMask:SetActive(false)
    end

    local starGrid = Util.GetGameObject(go.transform, "star")
    SetHeroStars(starGrid, heroData.star)
    local cardBtn = Util.GetGameObject(go.transform, "icon")
    local choosed = Util.GetGameObject(go.transform, "mask")
    choosed:SetActive(false)
    if curSelectHero.dynamicId == heroData.dynamicId then
        choosed:SetActive(true)
        oldChoose = choosed
    end
    this.replaceBtn:SetActive(true)
    this.cancelBtn:SetActive(false)
    this.saveBtn:SetActive(false)
    -- this.needBg:SetActive(true)
    -- this.replaceBg:SetActive(true)
    this.text:SetActive(true)
    this.cost:SetActive(false)

    Util.ClearChild(this.lihuiPos.transform)
    Util.ClearChild(this.newlihuiPos.transform)

    if curSelectHero.id then
        -- local spinePrefabName = GetResourcePath(HeroConfig[curSelectHero.id].RoleImage)
        -- poolManager:LoadLive(spinePrefabName,this.lihuiPos.transform,Vector3.New(0.8,0.8,1), Vector3.New(-50, -400, 0))
        LoadHerolive(HeroConfig[curSelectHero.id],this.lihuiPos)

        this.SetHero(this.curHero,curSelectHero)
        this.ShowCostInfo()
        -- this.needHero:SetActive(true)
        -- this.replaceHero:SetActive(false)
        -- this.needBg:SetActive(false)
        -- this.replaceBg:SetActive(true)
        this.text:SetActive(false)
        this.cost:SetActive(true)

    end

    Util.AddOnceClick(cardBtn, function()
        if heroData.dynamicId == curSelectHero.dynamicId then
            choosed:SetActive(false)
            oldChoose = nil
            curSelectHero = {}

            Util.ClearChild(this.lihuiPos.transform)
            Util.ClearChild(this.newlihuiPos.transform)

            -- this.needHero:SetActive(false)
            -- this.replaceHero:SetActive(false)
            this.cancelBtn:SetActive(false)
            this.saveBtn:SetActive(false)
            this.replaceBtn:SetActive(true)
            -- this.needBg:SetActive(true)
            -- this.replaceBg:SetActive(true)
            this.text:SetActive(true)
            this.cost:SetActive(false)

        else
            Util.ClearChild(this.lihuiPos.transform)
            Util.ClearChild(this.newlihuiPos.transform)
            
            choosed:SetActive(true)
            if oldChoose then
                oldChoose:SetActive(false)
            end
            oldChoose = choosed
            curSelectHero = heroData

            -- local spinePrefabName = GetResourcePath(HeroConfig[curSelectHero.id].RoleImage)
            -- poolManager:LoadLive(spinePrefabName,this.lihuiPos.transform,Vector3.New(0.8,0.8,1), Vector3.New(-50, -400, 0))
            LoadHerolive(HeroConfig[curSelectHero.id],this.lihuiPos)
            
            this.ShowCostInfo()
            -- this.needHero:SetActive(true)
            -- this.replaceHero:SetActive(false)
            -- this.needBg:SetActive(false)
            -- this.replaceBg:SetActive(true)
            this.text:SetActive(false)
            this.cost:SetActive(true)

            local data = this.RebuildData(curSelectHero.id,curSelectHero)
            this.SetHero(this.curHero,data)
            --如果已经有了置换Id
            if curSelectHero.changeId ~= 0 then

                this.cancelBtn:SetActive(true)
                this.replaceBtn:SetActive(false)
                this.saveBtn:SetActive(true)
                -- this.replaceHero:SetActive(true)
                -- this.needBg:SetActive(false)
                this.replaceBg:SetActive(true)
                this.text:SetActive(false)
                this.cost:SetActive(false)

                local data = this.RebuildData(curSelectHero.changeId,curSelectHero)
                this.SetHero(this.newHero,data)

                LoadHerolive(HeroConfig[data.id],this.newlihuiPos)
            else

                this.cancelBtn:SetActive(false)
                this.replaceBtn:SetActive(true)
                this.saveBtn:SetActive(false)
                -- this.replaceHero:SetActive(false)
                -- this.needBg:SetActive(false)
                -- this.replaceBg:SetActive(true)
                this.text:SetActive(false)
                this.cost:SetActive(true)

            end
        end
    end)

    Util.AddOnceClick(formationMask, function()
        if heroData.isFormation ~= "" then
            local teamIdList = HeroManager.GetAllFormationByHeroId(heroData.dynamicId)
            local name = ""
            for k,v in pairs(teamIdList)do
                local formationName=FormationManager.MakeAEmptyTeam(v)
                if k==#teamIdList then
                    name=name..formationName.teamName
                 else
                    name=name..formationName.teamName.."、"
                 end
            end
            -- 复位角色的状态
            MsgPanel.ShowTwo(string.format(GetLanguageStrById(22704),name), nil, function()
                for i = 1,#teamIdList do
                    local teamId = HeroManager.GetFormationByHeroId(heroData.dynamicId)
                    local formationName = FormationManager.MakeAEmptyTeam(teamId)
                    if teamId then
                        local teamData = FormationManager.GetFormationByID(teamId)
                        if LengthOfTable(teamData.teamHeroInfos) <= 1 then
                            PopupTipPanel.ShowTip(GetLanguageStrById(23118))
                            -- return
                        else
                            for k,v in pairs(teamData.teamHeroInfos)do
                                if v.heroId == heroData.dynamicId then
                                    table.removebyvalue(teamData.teamHeroInfos,v)
                                    break
                                end
                            end
                            FormationManager.RefreshFormation(teamId, teamData.teamHeroInfos, teamData.substitute,
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
            return
        end
    end)

    Util.AddLongPressClick(cardBtn, function()
        UIManager.OpenPanel(UIName.RoleInfoPopup, heroData)
    end, 0.5)
end

--刷新中间按钮和显示
function this.refresh()
    -- body
end

--设置两个英雄，左右不确定
function this.SetHero(go,heroData)
    local di = Util.GetGameObject(go,"di"):GetComponent("Image")
    local frame = Util.GetGameObject(go,"frame"):GetComponent("Image")
    local icon = Util.GetGameObject(go,"icon"):GetComponent("Image")
    local lv = Util.GetGameObject(go,"lv"):GetComponent("Text")
    local pro = Util.GetGameObject(go,"pro"):GetComponent("Image")
    local starGrid = Util.GetGameObject(go,"starGrid")  
    local name = Util.GetGameObject(go,"name"):GetComponent("Text")
    local roleConfig = ConfigManager.GetConfigData(ConfigName.RoleConfig, heroData.id)
    local scale = roleConfig.play_liveScale
    local livePos = Vector3.New(roleConfig.offset[1], roleConfig.offset[2], 0)
    SetHeroStars(starGrid,heroData.star)
    lv.text = heroData.lv
    pro.sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.property))
    di:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityBgImageByquality(nil,heroData.star))
    if heroData.star <= 5 then
        -- di:GetComponent("Image").sprite = Util.LoadSprite(X1GetHeroCardBgStarBgImage[heroData.star])
        frame:GetComponent("Image").sprite = Util.LoadSprite(X1GetHeroCardFrameStarByImage[heroData.star])  
    else
        -- di:GetComponent("Image").sprite = Util.LoadSprite(X1GetHeroCardBgStarBgImage[10])
        frame:GetComponent("Image").sprite = Util.LoadSprite(X1GetHeroCardFrameStarByImage[10])
    end
    icon.sprite = Util.LoadSprite(heroData.painting)  
    name.text = GetLanguageStrById(heroData.name)
    
    -- Util.AddClick(frame.gameObject, function()
    --     UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroData.id, heroData.star)
    -- end)
end

--设置阵营按钮选中
function this.SetBtnSelect(_parObj)
    this.selectBtn.transform:SetParent(_parObj.transform)
    this.selectBtn.transform.localScale = Vector3.one
    this.selectBtn.transform.localPosition = Vector3.zero
end

function this.ShowCostInfo()
    if replaceItemIdConfig then
        this.costImage:GetComponent("Image").sprite = SetIcon(tonumber(replaceItemIdConfig.Value))
    end
    
    if curSelectHero and replaceCostConfig then
        local getCostByStar = string.split(replaceCostConfig.Value,"|")
        if curSelectHero.star == 4 then
            t = tonumber(string.split(getCostByStar[1],"#")[2])
        elseif curSelectHero.star == 5 then
            t = tonumber(string.split(getCostByStar[2],"#")[2])
        end
        this.costText.text = "x" .. t
        if t>BagManager.GetTotalItemNum(tonumber(replaceItemIdConfig.Value)) then
            this.costText.text = "x" .. "<color=red>"..t.."</color>"
        end
    end
end

function this:OnClose()
    curSelectHero = {}
    curSelectHeroConfig = {}
    -- this.replaceHero:SetActive(false)
    -- this.needHero:SetActive(false)
    oldChoose = nil
    this.replaceBg:SetActive(false)
    this.btns:SetActive(true)
    this.btnBack:SetActive(true)

end

function this:OnDestroy()
    
end

return this