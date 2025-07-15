local selectaBtnIamage = {
    [0] = "cn2-x1_AN_shuxing_xuanzhong",
    [1] = "cn2-x1_AN_shuxing_xuanzhong",
    [2] = "cn2-x1_AN_shuxing_xuanzhong",
    [3] = "cn2-x1_AN_shuxing_xuanzhong",
    [4] = "cn2-x1_AN_shuxing_xuanzhong",
    [5] = "cn2-x1_AN_shuxing_xuanzhong",
    --[6] = "N1_img_tongyong_dingjishuzi5",
    }

require("Base/BasePanel")
FindTreasureDispatchPanel = Inherit(BasePanel)
local curSelectHeroList={}
local tabs = {}
local selectHeroGrid = {}
local conditionGrid = {}
local proId = ProIdConst.All
local conFigData
local missionData
local allHeroData--显示英雄数据
local curSortHeroList--一键选择英雄数据
local needState
local conditionHeros = {}
local timer = Timer.New()
local curAllHeros = {}
local isMaterial = true
local curPanelHerosSortNum = 1
--初始化组件（用于子类重写）
function FindTreasureDispatchPanel:InitComponent()
    -- self.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    self.MaskBack = Util.GetGameObject(self.transform, "maskBack")
    self.btnSure = Util.GetGameObject(self.transform, "btnSure")
    self.btnAutoSure = Util.GetGameObject(self.transform, "btnAutoSure")

    self.cardPre = Util.GetGameObject(self.gameObject, "item")
    self.Scrollbar = Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    -- local v = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    local rect = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "scroll").transform,
            self.cardPre, self.Scrollbar, Vector2.New(rect.width,rect.height), 1, 5, Vector2.New(5, 5))---v.x*2, -v.y
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1

    -- self.selectBtn = Util.GetGameObject(self.gameObject, "Tabs/selectBtn")
    for i = 0, 6 do
        tabs[i] = Util.GetGameObject(self.transform, "Tabs/grid/Btn" .. i)
    end

    for i = 1, 5 do
        selectHeroGrid[i] = Util.GetGameObject(self.transform, "selectHeroGrid/item" .. i)
    end

    for i = 1, 5 do
        conditionGrid[i] = Util.GetGameObject(self.transform, "conditionGrid/condition" .. i)
    end

    self.matreiaObj = Util.GetGameObject(self.gameObject, "matreialTimeInfoBg/matreiaObj")
    self.matreiaImage = Util.GetGameObject(self.gameObject, "matreialTimeInfoBg/matreiaObj/matreiaImage"):GetComponent("Image")
    self.matreiaText = Util.GetGameObject(self.gameObject, "matreialTimeInfoBg/matreiaObj/bgImage/numText"):GetComponent("Text")
    self.timeText = Util.GetGameObject(self.gameObject, "matreialTimeInfoBg/timeObj/bgImage/numText"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function FindTreasureDispatchPanel:BindEvent()
    Util.AddClick(self.MaskBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.matreiaObj, function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, FindTreasureManager.materialItemId)
    end)
    Util.AddClick(self.btnSure, function()
        if not isMaterial then
            PopupTipPanel.ShowTip(GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,FindTreasureManager.materialItemId).Name)..GetLanguageStrById(10655))
            return
        end
        for i = 1, #needState do
            if needState[i] < 1 then
                PopupTipPanel.ShowTipByLanguageId(10656)
                return
            end
        end
        local curSelectHeroIdsTab = {}
        for k, v in pairs(curSelectHeroList) do
            table.insert(curSelectHeroIdsTab,k)
        end
        NetManager.FindTreasureMissingRoomSendHeroRequest(missionData.missionId,curSelectHeroIdsTab,function()
            TaskManager.RefreshFindTreasureHerosData(missionData.missionId,curSelectHeroIdsTab,conFigData.WasteTime)
            Game.GlobalEvent:DispatchEvent(GameEvent.FindTreasure.RefreshFindTreasure,true)
            self:ClosePanel()
        end)
    end)
    Util.AddClick(self.btnAutoSure, function()
        self:AutoSelectHero()
        self:OnShowPanelData(curAllHeros)
    end)
    for i = 0, 6 do
        Util.AddClick(tabs[i], function()
            if i == proId then
                proId = ProIdConst.All
            else
                proId = i
            end
            self:GetCurSortHeroListData()
        end)
    end
end

--添加事件监听（用于子类重写）
function FindTreasureDispatchPanel:AddListener()

end

--移除事件监听（用于子类重写）
function FindTreasureDispatchPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function FindTreasureDispatchPanel:OnOpen(_missionData)
    missionData =_missionData
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FindTreasureDispatchPanel:OnShow()
    curPanelHerosSortNum = 1
    curSelectHeroList = {}
    curAllHeros = {}
    isMaterial = true
    conFigData = ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(missionData.missionId%10000))
    allHeroData = HeroManager.GetFingTreasureAllHeroDatas()
    curSortHeroList = HeroManager.GetFingTreasureAllHeroDatas()
    self:SortHeroDatas(allHeroData)
    self:SortHeroDatas2(curSortHeroList)
    self:OnShowPanelData(allHeroData)
    proId = ProIdConst.All
    self:SetSelectBtn()
    -- self.selectBtn.transform.localPosition = Vector2.New(-307,0)

    --显示选择的英雄
    self:ShowSelectHeroData()
    --显示条件
    self:ShowNeedConditionData()
    --赋值所有符合条件的英雄
    self:GetConditionHeros()
    
    self.matreiaImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,FindTreasureManager.materialItemId).ResourceID))
    self.matreiaText.text = BagManager.GetItemCountById(FindTreasureManager.materialItemId) .. "/"..conFigData.TakeItem[2]
    self.timeText.text = self:TimeStampToDateString(conFigData.WasteTime)
    if BagManager.GetItemCountById(FindTreasureManager.materialItemId) < conFigData.TakeItem[2]  then isMaterial = false end
end

function FindTreasureDispatchPanel:OnShowPanelData(_allHeroData)
    curAllHeros = _allHeroData
    self.ScrollView:SetData(_allHeroData, function (index, go)
        self:OnShowSingleCardData(go, _allHeroData[index])
    end)

end
function FindTreasureDispatchPanel:OnShowSingleCardData(go,heroData)--isSelect 1选择  2 没选择
    local choosed = Util.GetGameObject(go.transform, "choosed")
    choosed:SetActive(false)
    if curSelectHeroList[heroData.dynamicId] then
        heroData.sortId = curPanelHerosSortNum
        curPanelHerosSortNum = curPanelHerosSortNum + 1
        curSelectHeroList[heroData.dynamicId] = heroData
        choosed:SetActive(true)
    end
   self:OnShowCardData(go,heroData,1)
end

function FindTreasureDispatchPanel:ShowNeedConditionData(type)
    needState = self:DetectionSelectHeros()
    for i = 1, #conditionGrid do--curSelectHeroList
        if #conFigData.Condition >= i then
            conditionGrid[i]:SetActive(true)
            local starIcon  = Util.GetGameObject(conditionGrid[i], "starIcon")
            local proIcon  = Util.GetGameObject(conditionGrid[i], "proIcon")
            starIcon:SetActive(conFigData.Condition[i][1] == FindTreasureNeedType.Star)
            proIcon:SetActive(conFigData.Condition[i][1] == FindTreasureNeedType.Pro)
            -- proIcon.transform.localScale = Vector3.one
            -- if conFigData.Condition[i][1] == FindTreasureNeedType.Pro then
            --     proIcon.transform.localScale = Vector3.New(1.5, 1.5, 1)
            -- end
            Util.SetGray(conditionGrid[i], needState[i] < 1)
            local tipsStr = ""
            if conFigData.Condition[i][1] == FindTreasureNeedType.Star then
                tipsStr = GetLanguageStrById(10657)..conFigData.Condition[i][2]..GetLanguageStrById(10658)
                Util.GetGameObject(conditionGrid[i], "starIcon/Text"):GetComponent("Text").text = self:GetHeroStarImage(conFigData.Condition[i][2],1)
            elseif conFigData.Condition[i][1] == FindTreasureNeedType.Pro then
                tipsStr = GetLanguageStrById(10657)..HeroElementDef[conFigData.Condition[i][2]]..GetLanguageStrById(10659)
                proIcon:GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(conFigData.Condition[i][2]))
            end
            Util.AddOnceClick(conditionGrid[i], function()
                PopupTipPanel.ShowTip(tipsStr)
            end)
        else
            conditionGrid[i]:SetActive(false)
        end
    end
end

function FindTreasureDispatchPanel:ShowSelectHeroData()
    local curSelectHeroSortList = {}
    for i, v in pairs(curSelectHeroList) do
        table.insert(curSelectHeroSortList,v)
    end
    table.sort(curSelectHeroSortList, function(a, b)
        return a.sortId < b.sortId
    end)
    for i = 1, #selectHeroGrid do--curSelectHeroList
        if conFigData.NeedCard >= i then
            selectHeroGrid[i]:SetActive(true)
            if LengthOfTable(curSelectHeroSortList) >= i then--conFigData.NeedCard
                Util.GetGameObject(selectHeroGrid[i], "GameObject"):SetActive(true)
                if curSelectHeroSortList[i] then
                    self:OnShowCardData(Util.GetGameObject(selectHeroGrid[i], "GameObject"),curSelectHeroSortList[i],2)
                end
            else
                Util.GetGameObject(selectHeroGrid[i], "GameObject"):SetActive(false)
            end
        else
            selectHeroGrid[i]:SetActive(false)
        end
    end
end

function FindTreasureDispatchPanel:OnShowCardData(go,heroData,type)
    go:SetActive(true)
    Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    -- Util.GetGameObject(go.transform, "posIcon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)
    Util.GetGameObject(go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    -- Util.GetGameObject(go.transform, "heroStage"):GetComponent("Image").sprite = Util.LoadSprite(HeroStageSprite[heroData.heroConfig.HeroStage])
    -- Util.GetGameObject(go.transform, "heroStage"):SetActive(false)
    Util.GetGameObject(go.transform, "posIcon"):SetActive(false)
    Util.GetGameObject(go.transform, "heroStage"):SetActive(false)
    local starGrid = Util.GetGameObject(go.transform, "star")
    SetHeroStars(starGrid, heroData.star, 1)
    local cardBtn = Util.GetGameObject(go.transform, "icon")
    local choosed = Util.GetGameObject(go.transform, "choosed")
    local choosedBg = Util.GetGameObject(go.transform, "choosedBg")
    Util.AddOnceClick(cardBtn, function()
        if curSelectHeroList[heroData.dynamicId] then
            choosed:SetActive(false)
            choosedBg:SetActive(false)
            curSelectHeroList[heroData.dynamicId] = nil
            --监测方法
            if type == 2 then
                self:OnShowPanelData(curAllHeros)
            end
            self:ShowNeedConditionData()
            self:ShowSelectHeroData()
            return
        end
        if LengthOfTable(curSelectHeroList)>=conFigData.NeedCard then
            PopupTipPanel.ShowTipByLanguageId(10660)
            return
        end
        heroData .sortId = curPanelHerosSortNum
        curPanelHerosSortNum = curPanelHerosSortNum + 1
        curSelectHeroList[heroData.dynamicId] = heroData
        choosed:SetActive(true)
        choosedBg:SetActive(true)
        --监测方法
        self:ShowNeedConditionData()
        self:ShowSelectHeroData()
    end)
end

--组合当前选项数据
function FindTreasureDispatchPanel:GetCurSortHeroListData()
    local heros = {}
    self:SetSelectBtn()
    if proId ~= ProIdConst.All then
        heros = self:GetCurProHeros(proId)
        curSortHeroList = self:GetCurProHeros(proId)
    else
        heros = allHeroData
        curSortHeroList = HeroManager.GetFingTreasureAllHeroDatas()
    end
    self:OnShowPanelData(heros)
end
function FindTreasureDispatchPanel:HeroSortData(heroData)
    table.sort(heroData, function(a, b)
        if a.id == b.id then
            if a.lv == b.lv then
                return a.id > b.id
            else
                return a.lv < b.lv
            end
        else
            return a.id > b.id
        end
    end)
end
function FindTreasureDispatchPanel:SetSelectBtn()
    -- self.selectBtn.transform.position = tabs[proId].transform.position
    -- self.selectBtn:GetComponent("Image").sprite = Util.LoadSprite(selectaBtnIamage[proId])
    for index, value in ipairs(tabs) do
        Util.GetGameObject(value, "selectBtn"):SetActive(false)
    end
    Util.GetGameObject(tabs[0], "selectBtn"):SetActive(false)
    Util.GetGameObject(tabs[proId], "selectBtn"):SetActive(true)
end
--一键派遣
function FindTreasureDispatchPanel:AutoSelectHero()
--思路  按条件顺序选择 没选择一个英雄检测其他条件是否有满足的 满足跳过 不管能不能派遣都显示
    --allHeroData
    curSelectHeroList = {}
    local conditionTabs = {}
    for i = 1, #conFigData.Condition do
        conditionTabs[i] = 0
    end
    for i = 1, #conditionHeros do
        if #conditionHeros[i] > 0 then
            local jixu = self:AutoSelectState(conditionTabs)
            if jixu <= 0  then needState = conditionTabs return end
            if i > jixu then jixu = i end
            if #conditionHeros[jixu] <= 0  then  return end
            
            --curSelectHeroList[conditionHeros[i][1].dynamicId] = conditionHeros[i][1]
            local curSelectSingleHero = self:AutoSelectHeroId(conditionHeros[jixu])
            curSelectSingleHero.sortId = curPanelHerosSortNum--排序
            curPanelHerosSortNum = curPanelHerosSortNum + 1--排序
            curSelectHeroList[curSelectSingleHero.dynamicId] = curSelectSingleHero
            for k = 1, #conFigData.Condition do
                if conFigData.Condition[k][1] == FindTreasureNeedType.Star then
                    for j, v in pairs(curSelectHeroList) do
                        if v.star >= conFigData.Condition[k][2] then
                            conditionTabs[i] = 1
                        end
                    end
                elseif conFigData.Condition[k][1] == FindTreasureNeedType.Pro then
                    for j, v in pairs(curSelectHeroList) do
                        if v.heroConfig.PropertyName == conFigData.Condition[k][2] then
                            conditionTabs[i] = 1
                        end
                    end
                end
            end
            --监测方法
            self:ShowNeedConditionData()
            self:ShowSelectHeroData()
        end
    end
end

function FindTreasureDispatchPanel:AutoSelectState(conditionTabs)
    for i = 1, #conditionTabs do
        if conditionTabs[i] < 1 then
           return i
        end
    end
    return 0
end

function FindTreasureDispatchPanel:AutoSelectHeroId(conditionSingleHeros)
    local heroData = conditionSingleHeros[1]
    local endfeheNeedNum = 0
    for i = 1, #conditionSingleHeros do
        local feheNeedNum = 0
        for j = 1, #conFigData.Condition do
            if conFigData.Condition[j][1] == FindTreasureNeedType.Star then
                if conditionSingleHeros[i].star >= conFigData.Condition[j][2] then
                    feheNeedNum = feheNeedNum + 1
                end
            elseif conFigData.Condition[j][1] == FindTreasureNeedType.Pro then
                if conditionSingleHeros[i].heroConfig.PropertyName == conFigData.Condition[j][2] then
                    feheNeedNum = feheNeedNum + 1
                end
            end
        end
        if endfeheNeedNum < feheNeedNum then
            endfeheNeedNum = feheNeedNum
            heroData = conditionSingleHeros[i]
        end
    end
    return heroData
end

function FindTreasureDispatchPanel:GetCurProHeros(_property)
    local heros = {}
    local index = 1
    for i, v in pairs(allHeroData) do
        if v.property == _property then
                heros[index] = v
                index = index + 1
        end
    end
    return heros
end

--检测选择的英雄是否满足条件
function FindTreasureDispatchPanel:DetectionSelectHeros()
    local conditionTabs = {}
    for i = 1, #conFigData.Condition do
        conditionTabs[i] = 0
        if conFigData.Condition[i][1] == FindTreasureNeedType.Star then
            for j, v in pairs(curSelectHeroList) do
                if v.star >= conFigData.Condition[i][2] then
                    conditionTabs[i] = 1
                end
            end
        elseif conFigData.Condition[i][1] == FindTreasureNeedType.Pro then
            for j, v in pairs(curSelectHeroList) do
                if v.heroConfig.PropertyName == conFigData.Condition[i][2] then
                    conditionTabs[i] = 1
                end
            end
        end
    end
    return conditionTabs
end
--
function FindTreasureDispatchPanel:GetConditionHeros()
    conditionHeros = {}
    for i = 1, #conFigData.Condition do
        local curConditionHeros = {}
        for k, v in pairs(curSortHeroList) do
            if conFigData.Condition[i][1] == FindTreasureNeedType.Star then
                if v.star >= conFigData.Condition[i][2] then
                    table.insert(curConditionHeros,v)
                end
            elseif conFigData.Condition[i][1] == FindTreasureNeedType.Pro then
                if v.heroConfig.PropertyName == conFigData.Condition[i][2] then
                    table.insert(curConditionHeros,v)
                end
            end
        end
        conditionHeros[i] = curConditionHeros
    end
end
--英雄排序
function FindTreasureDispatchPanel:SortHeroDatas(_heroDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if a.star == b.star then
            if a.heroConfig.Natural ==b.heroConfig.Natural then
                if a.lv == b.lv then
                    return a.heroConfig.Id < b.heroConfig.Id
                else
                    return a.lv > b.lv
                end
            else
                return a.heroConfig.Natural > b.heroConfig.Natural
            end
        else
            return a.star > b.star
        end
    end)
end
function FindTreasureDispatchPanel:SortHeroDatas2(_heroDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if a.star == b.star then
            if a.heroConfig.Natural ==b.heroConfig.Natural then
                if a.lv == b.lv then
                    return a.heroConfig.Id > b.heroConfig.Id
                else
                    return a.lv < b.lv
                end
            else
                return a.heroConfig.Natural < b.heroConfig.Natural
            end
        else
            return a.star < b.star
        end
    end)
end
function FindTreasureDispatchPanel:GetHeroStarImage(star,type)
    if type == 1 then
        -- if star < 6 then
            return star
        -- elseif star > 5 then
        --     return star%5
        -- end
    else
        -- if star < 6 then
            return "ui_1xing"
        -- elseif star > 5 and star < 11 then
        --     return "ui_1yue"
        -- elseif star > 10 then
        --     return "ui_1un"
        -- end
    end
end
function FindTreasureDispatchPanel:TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format("%02d:%02d:%02d", hour, minute, sec)
end
--界面关闭时调用（用于子类重写）
function FindTreasureDispatchPanel:OnClose()
    if timer then
        timer:Stop()
        timer = nil
    end
    curAllHeros = {}
end

--界面销毁时调用（用于子类重写）
function FindTreasureDispatchPanel:OnDestroy()

end

return FindTreasureDispatchPanel