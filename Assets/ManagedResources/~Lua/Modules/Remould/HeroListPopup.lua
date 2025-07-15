require("Base/BasePanel")
local HeroListPopup = Inherit(BasePanel)
local this = HeroListPopup

local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local curSelectGO
local isShowGou = false
local selectHeroData={}
local selectData
local oldChoosed
--初始化组件（用于子类重写）
function HeroListPopup:InitComponent()
    this.itemPre = Util.GetGameObject(self.gameObject, "item")
    this.OkBtn = Util.GetGameObject(self.gameObject, "bg/btnSure")
    this.BackBtn = Util.GetGameObject(self.gameObject, "BackBtn")
	this.BtnBack = Util.GetGameObject(self.gameObject, "BtnBack")
    this.selectTxt = Util.GetGameObject(self.gameObject,"bg/numText"):GetComponent("Text")

    --this.Scrollbar= Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    local rect = Util.GetGameObject(self.gameObject, "bg/scroll"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,Util.GetGameObject(self.gameObject, "bg/scroll").transform,
            this.itemPre, nil, Vector2.New(rect.width, rect.height), 1, 5, Vector2.New(5,5))
    -- this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    -- this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function HeroListPopup:BindEvent()
    Util.AddClick(this.OkBtn, function()
        if this.panelName == panelName[2] then
            --this.normalVack:setData(selectHeroData,this.HeroExchangeConfigData)
            this.normalVack:setData(selectData,selectHeroData)
        else
            this.normalVack:setData(selectData,selectHeroData)
        end
       
        -- --关掉界面之前清空数据
        -- selectHeroData = {}
        -- selectData = nil
        -- oldChoosed = nil
        self:ClosePanel()
    end)
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function HeroListPopup:AddListener()
end

--移除事件监听（用于子类重写）
function HeroListPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function HeroListPopup:OnOpen(_backType,_normalVack,_panelName,_selectAlready)--回溯类型(普通 高级) 面板数据  面板名字 选中的改装数据
    this.backType = _backType
    this.normalVack = _normalVack
    this.panelName = _panelName
    this.selectAlready = _selectAlready

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function HeroListPopup:OnShow()
    if this.panelName == panelName[2] then
        this.OnSHowData2(this.selectAlready)
    else
        this.OnShowData(this.backType)
    end

end
--普通回溯&高级回溯
function this.OnShowData(backType)
    local data = HeroManager.GetAllHeroDataMsinusUpWar1(0,backType)

    this.ScrollView:SetData(data, function (index, go)
        this.SingleItemDataShow(go, data[index])
    end)
end
--单位改装
function this.OnSHowData2(selectAlready)
    local selectAlready = selectAlready
    this.HeroExchangeConfigData = ConfigManager.GetConfigDataByDoubleKey("HeroExchangeConfig", "Star", selectAlready.star, "Country", selectAlready.property)

    this.maxSelectNum = this.HeroExchangeConfigData.NeedNumber
    this.selectTxt.text = GetLanguageStrById(11775) .. LengthOfTable(selectHeroData).." / "..this.maxSelectNum
    local data=HeroManager.GetAllHeroDataMsinusUpWar2(0,this.HeroExchangeConfigData.Id)
    this.ScrollView:SetData(data, function (index, go)
        this.SingleItemDataShow(go, data[index])
    end)
end
function this.SingleItemDataShow(_go,heroData)

    local heroConfig = HeroConfig[heroData.id]
    Util.GetGameObject(_go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv
    -- Util.GetGameObject(_go.transform, "Name"):GetComponent("Text").text = GetLanguageStrById(heroConfig.ReadingName)
    Util.GetGameObject(_go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
    Util.GetGameObject(_go.transform, "proBG"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    local starGrid = Util.GetGameObject(_go.transform, "star")
    SetHeroStars(starGrid, heroData.star)

    local choosed = Util.GetGameObject(_go.transform, "choosed")
    local FormationId = HeroManager.GetFormationByHeroId(heroData.dynamicId)
    local formationMask = Util.GetGameObject(_go.transform, "formationMask")
    formationMask:SetActive(FormationId ~= nil)
    -- local lockMask = Util.GetGameObject(_go.transform, "lockMask")
    -- lockMask:SetActive(heroData.lockState == 1)
    choosed:SetActive(false)
    local cardclickBtn = Util.GetGameObject(_go.transform, "icon")
    if this.panelName == panelName[2] then
        --this.maxSelectNum = this.HeroExchangeConfigData.NeedNumber
        this.selectTxt.text = GetLanguageStrById(11775)..LengthOfTable(selectHeroData).."/"..this.maxSelectNum
    end
    --local maxSelectNum = this.HeroExchangeConfigData.NeedNumber or 1
   
    if selectHeroData[heroData.dynamicId] then
        choosed:SetActive(true)
    end
    
    Util.AddOnceClick(cardclickBtn, function()
        if this.panelName == panelName[2] then
            --TODO选择一样的坦克
            if selectHeroData[heroData.dynamicId] then
                choosed:SetActive(false)
                selectHeroData[heroData.dynamicId] = nil
                if LengthOfTable(selectHeroData) <= 0 then
                   selectData = nil
                end
                this.selectTxt.text = GetLanguageStrById(11775)..LengthOfTable(selectHeroData).."/"..this.maxSelectNum
                --this.noSelectBtn.gameObject:SetActive(LengthOfTable(selectHeroData)>0)
                return
            end
            if LengthOfTable(selectHeroData) >= this.maxSelectNum then
               PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12211),this.maxSelectNum))
               return
            end
            if LengthOfTable(selectHeroData) > 0 then
                local data
                for k,v in pairs(selectHeroData)do
                    data=v
                end
                if  heroData.property == data.property and heroData.id == data.id then
                    selectHeroData[heroData.dynamicId] = heroData
                    selectData = selectHeroData[heroData.dynamicId]
                    choosed:SetActive(true)
                    this.selectTxt.text = GetLanguageStrById(11775)..LengthOfTable(selectHeroData).."/"..this.maxSelectNum
                    return
                else
                    PopupTipPanel.ShowTipByLanguageId(50121)
                    return
                end
            end

            selectHeroData[heroData.dynamicId] = heroData
            selectData = selectHeroData[heroData.dynamicId]
            choosed:SetActive(true)
            this.selectTxt.text = GetLanguageStrById(11775)..LengthOfTable(selectHeroData).."/"..this.maxSelectNum
            --this.noSelectBtn.gameObject:SetActive(LengthOfTable(selectHeroData)>0)
        else
           this.selectTxt.text = GetLanguageStrById(12651)
           if selectHeroData[heroData.dynamicId] then
            --    choosed:SetActive(false)
            --    selectHeroData[heroData.dynamicId] = nil
               if oldChoosed then
                  oldChoosed.gameObject:SetActive(false)
                  oldChoosed = nil
                  selectData = nil
                  --selectHeroData[heroData.dynamicId] = nil
                  --table.remove(selectHeroData)
                  selectHeroData={}
               end
               return
           end
           if oldChoosed then
              oldChoosed.gameObject:SetActive(false)
              --selectHeroData[heroData.dynamicId] = nil
              --table.remove(selectHeroData)
              selectHeroData = {}
            end
     
            selectHeroData[heroData.dynamicId]=heroData
            selectData = selectHeroData[heroData.dynamicId]
            choosed:SetActive(true)
            oldChoosed=  choosed
        end
    end)
    --英雄下阵(TODO)
    Util.AddOnceClick(formationMask, function()
        if FormationId ~= nil then
            local teamIdList = HeroManager.GetAllFormationByHeroId(heroData.dynamicId)
            local name = ""
            for k,v in pairs(teamIdList)do
                local formationName=FormationManager.MakeAEmptyTeam(v)
                if k == #teamIdList then
                    name = name..formationName.teamName
                else
                    name = name..formationName.teamName.."、"
                end
            end
            -- 复位角色的状态
            MsgPanel.ShowTwo(string.format(GetLanguageStrById(22704),name), nil, function()
                for i = 1,#teamIdList do
                    local teamId  =HeroManager.GetFormationByHeroId(heroData.dynamicId)
                    local formationName = FormationManager.MakeAEmptyTeam(teamId)
                    if teamId then
                        local teamData = FormationManager.GetFormationByID(teamId)
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
            return
        end
    end)
end

--界面关闭时调用（用于子类重写）
function HeroListPopup:OnClose()
    this.selectTxt.text = GetLanguageStrById(12654)
    --关掉界面之前清空数据
    selectHeroData = {}
    selectData = nil
    oldChoosed = nil
end

--界面销毁时调用（用于子类重写）
function HeroListPopup:OnDestroy()
end

function HeroListPopup:get()
    return selectHeroData
end

return HeroListPopup