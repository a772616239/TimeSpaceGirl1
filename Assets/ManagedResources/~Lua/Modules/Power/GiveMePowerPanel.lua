--- 界面专用对象池
local TempPool = {}
function TempPool:Init()
    if not self.MomNode then
        self.MomNode = {}
        self.NodeList = {}
        self.UsedIndex = {}
    end
end
function TempPool:Register(type, node)
    self.MomNode[type] = node
end
function TempPool:GetNode(type, parent)
    if not type or not parent then

        return
    end
    if not self.NodeList[type] then
        self.NodeList[type] = {}
        self.UsedIndex[type] = 0
    end
    if self.UsedIndex[type] >= #self.NodeList[type] then
        local mom = self.MomNode[type]
        if not mom then

            return
        end
        self.UsedIndex[type] = self.UsedIndex[type] + 1
        local node = newObjToParent(mom, parent)
        table.insert(self.NodeList[type], node)
        node.transform.localPosition = Vector3.New(0 ,0,0)
        return node
    end
    self.UsedIndex[type] = self.UsedIndex[type] + 1
    local node = self.NodeList[type][self.UsedIndex[type]]
    node.transform:SetParent(parent.transform)
    node.transform.localPosition = Vector3.New(0 ,0,0)
    node:SetActive(true)
    
    
    return node
end
function TempPool:Recycle(type)
    local nodeList = self.NodeList[type] or {}
    for _, node in ipairs(nodeList) do
        node:SetActive(false)
    end
    self.UsedIndex[type] = 0
end
function TempPool:RecycleAll()
    
    
    if not self.NodeList then
        return
    end
    for type, _ in pairs(self.NodeList) do
        self:Recycle(type)
    end
end
function TempPool:Destroy()
    self.MomNode = nil
    self.NodeList = nil
    self.UsedIndex = nil
end

-- 按钮开闭状态改变
local _BtnStatus = {
    open = {img = "s_slbz_1anniuongse", text = GetLanguageStrById(11661), textColor = Color.New(132/255,81/255,62/255,1)},
    close = {img = "s_slbz_1anniuhuangse", text = GetLanguageStrById(11662), textColor = Color.New(139/255,104/255,11/255,1)}
}
local function _SetBtnStatus(btn, status)
    local status = _BtnStatus[status]
    if not status then return end
    -- btn:GetComponent("Image").sprite = Util.LoadSprite(status.img)
    local txt = Util.GetGameObject(btn, "Text"):GetComponent("Text")
    txt.text = status.text
    -- txt.color = status.textColor
end


--- 界面逻辑
require("Base/BasePanel")
local GiveMePowerPanel = Inherit(BasePanel)
local this = GiveMePowerPanel

-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabSprite = { default = "cn2-X1_tongyong_anniuxiao", select = "cn2-X1_tongyong_anniuxiao" }
local _TabFontColor = { default = Color.New(165 / 255, 165 / 255, 165 / 255, 1),
                         select = Color.New(90 / 255, 53 / 255, 12 / 255, 1) }
local _TabColor = { default = Color.New(165 / 255, 165 / 255, 165 / 255, 1),
                    select = Color.New(255 / 255, 209 / 255, 43 / 255, 1) }

local _TabData = {
    [1] = { name = GetLanguageStrById(11665) },
    [2] = { name = GetLanguageStrById(11664) },
    [3] = { name = GetLanguageStrById(11663) },
    [4] = { name = GetLanguageStrById(11666) },
}

-- 评分进度条
local _HeroGradeProgress = {}

--初始化组件（用于子类重写）
function GiveMePowerPanel:InitComponent()
    this.btnBack = Util.GetGameObject(this.transform, "btnBack")
    this.tabbox = Util.GetGameObject(this.transform, "tabbox")

    this.heroPanel = Util.GetGameObject(this.transform, "content/hero")
    this.forceValue = Util.GetGameObject(this.heroPanel, "powerBtn/value"):GetComponent("Text")

    this.groupBox = Util.GetGameObject(this.heroPanel, "demons")
    this.heroChoose = Util.GetGameObject(this.heroPanel, "demons/choose")
    this.btnAddHero = Util.GetGameObject(this.heroPanel, "demons/add")
    -- this.btnMyGroup = Util.GetGameObject(this.heroPanel, "orggroup")

    this.curHeroName = Util.GetGameObject(this.heroPanel, "curHero/name"):GetComponent("Text")
    this.curHeroProgress = Util.GetGameObject(this.heroPanel, "curHero/progress"):GetComponent("Slider")
    this.curHeroGrade = Util.GetGameObject(this.heroPanel, "curHero/progress/Text"):GetComponent("Text")

    this.heroScrollRoot = Util.GetGameObject(this.heroPanel, "scrollRoot")
    this.heroScrollItem = Util.GetGameObject(this.heroPanel, "scrollRoot/item")

    this.otherPanel = Util.GetGameObject(this.transform, "content/other")
    this.resItem1 = Util.GetGameObject(this.otherPanel, "ResItem1")
    this.resItem2 = Util.GetGameObject(this.otherPanel, "ResItem2")
    this.rmdItem = Util.GetGameObject(this.otherPanel, "rmdItem")
    this.qaItem1 = Util.GetGameObject(this.otherPanel, "qaItem1")
    this.qaItem2 = Util.GetGameObject(this.otherPanel, "qaItem2")

    this.scrollRoot = Util.GetGameObject(this.otherPanel, "scroll")

    -- this.BtView =SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)

    -- this.UpView = SubUIManager.Open(SubUIConfig.UpView, this.transform, { showType = UpViewOpenType.ShowLeft })
end

--绑定事件（用于子类重写）
function GiveMePowerPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        
        self:ClosePanel()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    -- Util.AddClick(this.btnMyGroup, function()
    --     --UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.MAIN)
    --     --JumpManager.GoJump(1013)
    --     UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.MAIN)
    -- end)
    Util.AddClick(this.btnAddHero, function()
        JumpManager.GoJump(1023)
    end)

    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)

    -- 初始化对象池
    TempPool:Init()
    --TempPool:Register("res1", this.resItem1)
    TempPool:Register("res2", this.resItem2)
    TempPool:Register("rmd", this.rmdItem)
    --TempPool:Register("qa1", this.qaItem1)
    TempPool:Register("qa2", this.qaItem2)
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "name")
    local tabimg = Util.GetGameObject(tab,"img")
    tabimg:GetComponent("Image").sprite = Util.LoadSprite(_TabSprite[status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    -- tabLab:GetComponent("Text").color = _TabFontColor[status]
    tabimg:GetComponent("Image").color = _TabColor[status]
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    -- 设置显示
    this._CurIndex = index
    this.heroPanel:SetActive(index == 3)
    this.otherPanel:SetActive(index ~= 3)
    if index == 3 then
        this.RefreshHeroPanelShow()
    elseif index ~= 3 then
        this.RefreshOtherPanelShow(index)
    end
end

--- 刷新我要变强界面
-- 刷新英雄列表显示
function this.RefreshHeroPanelShow()
    --
    local power = 0
    local formationData = FormationManager.GetFormationByID(FormationManager.curFormationIndex)
    for i = 1, 5 do
        local go = this.groupBox.transform:GetChild(i-1).gameObject
        if formationData.teamHeroInfos[i] then
            go:SetActive(true)
            local heroDId = formationData.teamHeroInfos[i].heroId
            local allEquipAddProVal = HeroManager.CalculateHeroAllProValList(1, heroDId, false)
            power = power + allEquipAddProVal[HeroProType.WarPower]
            local heroData = HeroManager.GetSingleHeroData(heroDId)
            this.SingleHeroDataShow(go, heroData, i)

            if i == 1 then
                this.ChooseHero(go, heroData, i)
            end
        else
            go:SetActive(false)
        end
    end

    local heroNum = #formationData.teamHeroInfos
    this.btnAddHero:SetActive(heroNum < 5)
    if heroNum < 5 then
        local pos = this.groupBox.transform:GetChild(heroNum).transform.localPosition
        this.btnAddHero.transform.localPosition = pos
    end
    this.forceValue.text = power
end

-- 刷新成长选项
function this.RefreshHeroGrowList()
    -- 刷新列表显示
    if not this.HeroScrollView then
        local height = this.heroScrollRoot.transform.rect.height
        local width = this.heroScrollRoot.transform.rect.width
        this.HeroScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.heroScrollRoot.transform,
                this.heroScrollItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0, 10))
        this.HeroScrollView.moveTween.Strength = 1
    end
    -- 设置我要变强界面数据显示
    local _HeroStrongerData = UKnowNothingToThePowerManager.GetHeroPowerList(this.CurHeroTId)
    this.HeroScrollView:SetData(_HeroStrongerData, function(index, go)
        local data = _HeroStrongerData[index]
        local title = Util.GetGameObject(go, "content/title"):GetComponent("Text")
        local content = Util.GetGameObject(go, "content/content"):GetComponent("Text")
        local progress = Util.GetGameObject(go, "content/progress"):GetComponent("Slider")
        local progressText = Util.GetGameObject(go, "content/progress/Text"):GetComponent("Text")
        local btnGo = Util.GetGameObject(go, "content/dealBtn")
        title.text = GetLanguageStrById(data.DescFirst)
        content.text = GetLanguageStrById(data.DescSecond)

        local dId = data.Id
        _HeroGradeProgress[go] = {
            id = dId,
            progress = progress,
            progressText = progressText
        }
        local _HeroGrade = UKnowNothingToThePowerManager.GetHeroGrade(this.CurHeroDId)
        local value = 0
        local str = "0/0"
        if _HeroGrade and _HeroGrade[dId] then
            local curScore = _HeroGrade[dId].curScore
            local maxScore = _HeroGrade[dId].maxScore
            value = curScore/maxScore
            str = string.format("%d/%d", curScore, maxScore)
        end
        progress.value = value
        progressText.text = str

        btnGo:SetActive(data.Jump ~= 0)
        Util.AddOnceClick(btnGo, function()
            if data.Jump < 0 then
                local heroData = HeroManager.GetSingleHeroData(this.CurHeroDId)
                local openPanle = UIManager.OpenPanel(UIName.RoleInfoPanel, heroData, HeroManager.GetAllHeroDatas(),true)
                if openPanle then
                    openPanle.ShowGuideGo(data.Jump)
                end
            elseif data.Jump > 0 then
                JumpManager.GoJump(data.Jump)
            end
        end)
    end)
    this.HeroScrollView:SetIndex(1)
end


-- 节点数据匹配
function this.SingleHeroDataShow(go, heroData, index)
    Util.GetGameObject(go, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality, heroData.star))
    Util.GetGameObject(go, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    -- Util.GetGameObject(go, "posIcon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)
    Util.GetGameObject(go, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    -- Util.GetGameObject(go, "heroStage"):SetActive(false)
    Util.GetGameObject(go, "Name"):GetComponent("Text").text = GetLanguageStrById(heroData.heroConfig.ReadingName)
    Util.GetGameObject(go, "lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroData.heroConfig.Quality))
    Util.GetGameObject(go, "proBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.heroConfig.Quality))
    --Util.GetGameObject(go, "heroStage"):GetComponent("Image").sprite = Util.LoadSprite(HeroStageSprite[heroData.heroConfig.HeroStage])
    local starGrid = Util.GetGameObject(go, "star")
    SetHeroStars(starGrid, heroData.star)
    -- Click On
    Util.AddOnceClick(go, function()
        this.ChooseHero(go, heroData, index)
        if this.HeroScrollView then
            this.HeroScrollView:SetIndex(1)
        end
    end)
    Util.AddLongPressClick(go, function()
        UIManager.OpenPanel(UIName.RoleInfoPopup, heroData)
    end, 0.5)
end

-- 选中英雄
function this.ChooseHero(go, heroData, index)
    if this._CurHeroIndex == index then return end
    this._CurHeroIndex = index
    this.heroChoose.transform:SetParent(go.transform)
    this.count=go.transform.childCount
    this.heroChoose.transform:SetSiblingIndex(0)
    this.heroChoose.transform.localPosition = Vector3.New(-110,0,0)
    this.curHeroName.text = GetLanguageStrById(heroData.name)

    this.CurHeroDId = heroData.dynamicId
    this.CurHeroTId = heroData.id
    this.RefreshGrade(heroData.dynamicId)
    this.RefreshHeroGrowList()
end

-- 刷新评分
function this.RefreshGrade(dId)
    -- 评分
    local _HeroGrade = UKnowNothingToThePowerManager.GetHeroGrade(dId)
    this.curHeroProgress.value = _HeroGrade.tCurScore/_HeroGrade.tMaxScore
    this.curHeroGrade.text = string.format("%d/%d", _HeroGrade.tCurScore, _HeroGrade.tMaxScore)
    --for _, data in pairs(_HeroGradeProgress) do
    --    local id  = data.id
    --    local progress  = data.progress
    --    local progressText  = data.progressText
    --    local value = 0
    --    local str = "0/0"
    --    if _HeroGrade and _HeroGrade[id] then
    --        local curScore = _HeroGrade[id].curScore
    --        local maxScore = _HeroGrade[id].maxScore
    --        value = curScore/maxScore
    --        str = string.format("%d/%d", curScore, maxScore)
    --    end
    --    progress.value = value
    --    progressText.text = str
    --end
end

-- 刷新其他界面
function this.RefreshOtherPanelShow(index)
    -- 回收所有节点
    TempPool:RecycleAll()

    if this.ResScrollView then
        this.ResScrollView.gameObject:SetActive(index == 2)
    end
    if this.RmdScrollView then
        this.RmdScrollView.gameObject:SetActive(index == 1)
    end
    if this.QAScrollView then
        this.QAScrollView.gameObject:SetActive(index == 4)
    end

    this._CurResIndex = nil
    this._CurRmdIndex = nil
    this._CurQAIndex = nil
    -- 刷新显示
    if index == 2 then
        this.ShowResPanel()
    elseif index == 1 then
        this.ShowRmdPanel()
    elseif index == 4 then
        this.ShowQAPanel()
    end
end

-- 显示资源获取方式界面
this._CurResIndex = nil
function this.ShowResPanel(index)
    if not this.ResScrollView then
        local rootWidth = this.scrollRoot.transform.rect.width
        local rootHight = this.scrollRoot.transform.rect.height
        local sv = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.scrollRoot.transform,
                this.resItem1, Vector2.New(rootWidth, rootHight), 1, 10)
        sv.moveTween.Strength = 1
        -- 保存
        this.ResScrollView = sv
    end
    local dataList = UKnowNothingToThePowerManager.GetResGetParentList()
    this.ResScrollView:SetData(dataList, function(dataIndex, node)
        local data = dataList[dataIndex]
        local itemBg = Util.GetGameObject(node, "content/itembg"):GetComponent("Image")
        local itemIcon = Util.GetGameObject(node, "content/icon"):GetComponent("Image")
        local title = Util.GetGameObject(node, "content/title"):GetComponent("Text")
        local content = Util.GetGameObject(node, "content/content"):GetComponent("Text")
        local dealBtn = Util.GetGameObject(node, "content/dealBtn")
        local childBox = Util.GetGameObject(node, "childbox")
        local itemId = data.ItemId
        local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig,data.ItemId)
        if itemConfig.ItemBaseType == ItemBaseType.SoulPrint then--魂印特殊显示
            Util.GetGameObject(node, "content/icon"):SetActive(false)
            Util.GetGameObject(node, "content/circleFrameBg"):SetActive(true)
            Util.GetGameObject(node, "content/circleFrameBg"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig.Quantity].circleBg2)
            Util.GetGameObject(node,"content/circleFrameBg/Icon"):GetComponent("Image").sprite=SetIcon(itemId)
            Util.GetGameObject(node,"content/circleFrameBg/circleFrame"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig.Quantity].circle)
        else

            Util.GetGameObject(node, "content/icon"):SetActive(true)
            Util.GetGameObject(node, "content/circleFrameBg"):SetActive(false)
        end
        itemBg.sprite = SetFrame(itemId)
        itemIcon.sprite = SetIcon(itemId)
        title.text = data.Title
        content.text = data.Content

        if this._CurResIndex == dataIndex then
            childBox:SetActive(true)
            -- 回收数据
            TempPool:Recycle("res2")
            local cDataList = UKnowNothingToThePowerManager.GetResGetChildList(itemId)
            for _, cdata in ipairs(cDataList) do
                local cNode = TempPool:GetNode("res2", childBox)
                local cItemBg = Util.GetGameObject(cNode, "itembg"):GetComponent("Image")
                local cItemIcon = Util.GetGameObject(cNode, "icon"):GetComponent("Image")
                local cTitle = Util.GetGameObject(cNode, "title"):GetComponent("Text")
                local cContent = Util.GetGameObject(cNode, "content"):GetComponent("Text")
                local cDealBtn = Util.GetGameObject(cNode, "dealBtn")
                if itemConfig.ItemBaseType == ItemBaseType.SoulPrint then--魂印特殊显示
                    Util.GetGameObject(cNode, "icon"):SetActive(false)
                    Util.GetGameObject(cNode, "circleFrameBg"):SetActive(true)
                    Util.GetGameObject(cNode, "circleFrameBg"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig.Quantity].circleBg2)
                    Util.GetGameObject(cNode,"circleFrameBg/Icon"):GetComponent("Image").sprite=SetIcon(itemId)
                    Util.GetGameObject(cNode,"circleFrameBg/circleFrame"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig.Quantity].circle)
                else

                    Util.GetGameObject(cNode, "icon"):SetActive(true)
                    Util.GetGameObject(cNode, "circleFrameBg"):SetActive(false)
                end
                cItemBg.sprite = SetFrame(itemId)
                cItemIcon.sprite = SetIcon(itemId)
                cTitle.text = cdata.Title
                cContent.text = cdata.Content
                cDealBtn:SetActive(cdata.Jump ~= 0)
                Util.AddOnceClick(cDealBtn, function()
                    JumpManager.GoJump(cdata.Jump)
                end)
            end
            _SetBtnStatus(dealBtn, "open")
            LayoutUtility.GetPreferredHeight(childBox.transform)
        else
            childBox:SetActive(false)
            _SetBtnStatus(dealBtn, "close")
        end

        Util.AddOnceClick(dealBtn, function()
            if this._CurResIndex == dataIndex then
                this._CurResIndex = nil
            else
                this._CurResIndex = dataIndex
            end
            this.ShowResPanel(dataIndex)
        end)
    end)

    -- 判断是否跳转
    if index then
        this.ResScrollView:SetIndex(index)
    end

end


-- 刷新推荐界面显示
this._CurRmdIndex = nil
function this.ShowRmdPanel(index)

    if not this.RmdScrollView then
        local rootWidth = this.scrollRoot.transform.rect.width
        local rootHight = this.scrollRoot.transform.rect.height
        local sv = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.scrollRoot.transform,
                this.rmdItem, Vector2.New(rootWidth, rootHight), 1, 10)
        -- 保存
        this.RmdScrollView = sv
    end
    local dataList = UKnowNothingToThePowerManager.GetRmdList()
    this.RmdScrollView:SetData(dataList, function(dataIndex, node)
        local data = dataList[dataIndex]
        local title = Util.GetGameObject(node, "content/title"):GetComponent("Text")
        local heroBox = Util.GetGameObject(node, "content/demons")
        local dealBtn = Util.GetGameObject(node, "content/dealBtn")
        local childBox = Util.GetGameObject(node, "childbox")
        local childName = Util.GetGameObject(childBox, "name"):GetComponent("Text")
        local childContent = Util.GetGameObject(childBox, "content"):GetComponent("Text")
        title.text = GetLanguageStrById(data.DescFirst)
        local strList = string.split(GetLanguageStrById(data.DescSecond), "#")
        childName.text = strList[1]   -- 空格用于调整文字的起始位置
        childContent.text = strList[2]   -- 全角空格可以避免自动换行
        for index, heroId in ipairs(data.ItemId) do
            local heroData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroId)
            local node = heroBox.transform:GetChild(index - 1).gameObject
            Util.GetGameObject(node, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.Quality))
            Util.GetGameObject(node, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.Icon))
            -- Util.GetGameObject(node, "posIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(heroData.Profession))
            Util.GetGameObject(node, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.PropertyName))
            -- Util.GetGameObject(node, "heroStage"):SetActive(false)
            Util.GetGameObject(node, "Name"):GetComponent("Text").text = GetLanguageStrById(heroData.ReadingName)
            --Util.GetGameObject(node, "heroStage"):GetComponent("Image").sprite =  Util.LoadSprite(HeroStageSprite[heroData.HeroStage])
            Util.GetGameObject(node, "proBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.Quality))
            Util.AddOnceClick(node, function()
                UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroId, heroData.Star)
            end)
        end
        if this._CurRmdIndex == dataIndex then
            childBox:SetActive(true)
            _SetBtnStatus(dealBtn, "open")
            LayoutUtility.GetPreferredHeight(childBox.transform)
        else
            childBox:SetActive(false)
            _SetBtnStatus(dealBtn, "close")
        end

        Util.AddOnceClick(dealBtn, function()
            if this._CurRmdIndex == dataIndex then
                this._CurRmdIndex = nil
            else
                this._CurRmdIndex = dataIndex
            end
            this.ShowRmdPanel(dataIndex)
        end)
    end)

    -- 判断是否跳转
    if index then
        this.RmdScrollView:SetIndex(index)
    end
end

this._CurQAIndex = nil
function this.ShowQAPanel(index)
    if not this.QAScrollView then
        local rootWidth = this.scrollRoot.transform.rect.width
        local rootHight = this.scrollRoot.transform.rect.height
        local sv = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.scrollRoot.transform,
                this.qaItem1, Vector2.New(rootWidth, rootHight), 1, 10)
        -- 保存
        this.QAScrollView = sv
    end

    local QAList = UKnowNothingToThePowerManager.GetQAList()
    this.QAScrollView:SetData(QAList, function(dataIndex, node)
        local data = QAList[dataIndex]
        local title = Util.GetGameObject(node, "content/title"):GetComponent("Text")
        local dealBtn = Util.GetGameObject(node, "content/dealBtn")
        local childBox = Util.GetGameObject(node, "childbox")
        title.text = GetLanguageStrById(data.DescFirst)
        childBox:SetActive(false)
        _SetBtnStatus(dealBtn, "close")

        if this._CurQAIndex == dataIndex then
            childBox:SetActive(true)
            -- 回收数据
            TempPool:Recycle("qa2")
            local qaList = UKnowNothingToThePowerManager.GetQADetailList(data.Id)
            for _, qa in ipairs(qaList) do
                local qaNode = TempPool:GetNode("qa2", childBox)
                local qaTitle = Util.GetGameObject(qaNode, "title"):GetComponent("Text")
                local qaContent = Util.GetGameObject(qaNode, "content"):GetComponent("Text")
                qaTitle.text = qa.q
                qaContent.text = qa.a
            end
            _SetBtnStatus(dealBtn, "open")
            LayoutUtility.GetPreferredHeight(childBox.transform)
        end
        Util.AddOnceClick(dealBtn, function()
            if this._CurQAIndex == dataIndex then
                this._CurQAIndex = nil
            else
                this._CurQAIndex = dataIndex
            end
            this.ShowQAPanel(dataIndex)
        end)
    end)
    -- 判断是否跳转
    if index then
        this.QAScrollView:SetIndex(index)
    end
end

--添加事件监听（用于子类重写）
function GiveMePowerPanel:AddListener()
    --Game.GlobalEvent:AddEvent(GameEvent.HeroGrade.OnHeroGradeChange, this.RefreshGrade)
end

--移除事件监听（用于子类重写）
function GiveMePowerPanel:RemoveListener()
    --Game.GlobalEvent:RemoveEvent(GameEvent.HeroGrade.OnHeroGradeChange, this.RefreshGrade)
end

--界面打开时调用（用于子类重写）
function GiveMePowerPanel:OnOpen(...)
    -- 检测任务
    UKnowNothingToThePowerManager.CheckTask()
    --
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(1)
    end

    -- this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GiveMePowerPanel:OnShow()
    -- this.BtView:OnOpen({sortOrder = self.sortingOrder,panelType = PanelTypeView.MainCity})
    if this.TabCtrl and this._CurIndex == 1 then
        this.TabCtrl:ChangeTab(this._CurIndex)
    end
end

--界面关闭时调用（用于子类重写）
function GiveMePowerPanel:OnClose()
    this._CurHeroIndex = nil
    UKnowNothingToThePowerManager.ClearHeroGrade()

    this._CurResIndex = nil
    this._CurRmdIndex = nil
    this._CurQAIndex = nil
end

--界面销毁时调用（用于子类重写）
function GiveMePowerPanel:OnDestroy()
    -- 销毁对象池
    TempPool:Destroy()
    --
    this.HeroScrollView = nil
    this.ResScrollView = nil
    this.RmdScrollView = nil
    this.QAScrollView = nil

    _HeroGradeProgress = {}
    -- SubUIManager.Close(this.BtView)
    -- SubUIManager.Close(this.UpView)
end

return GiveMePowerPanel