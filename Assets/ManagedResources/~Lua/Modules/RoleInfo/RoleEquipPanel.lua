require("Base/BasePanel")
local spcialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
RoleEquipPanel = Inherit(BasePanel)
--local SortTypeConst = {
--    Natural = 1,--品阶    ur+ -->  r       6  --> 1
--    Lv = 2
--}
local PosIdConst = {
    All = 0,
    --全部
    WuQi = 1,
    --武器
    ZhanFu = 2,
    --战服
    TouShi = 3,
    --头饰
    ZhanXue = 4,
    --战靴
    Hun = 5,
    --魂宝
    Ling = 6
    --灵宝
}
local this = RoleEquipPanel
--当前英雄穿的装备
local curHeroEquipDatas = {}
--当前英雄
local curHeroData

local heroListData
local curSelectEquipData
local index
local indexBtnNum = 0
local typeTab = {GetLanguageStrById(10427), GetLanguageStrById(10428), GetLanguageStrById(10429), GetLanguageStrById(10430), GetLanguageStrById(10505), GetLanguageStrById(10506)}
local tabs = {}
local openThisPanel
local effectList = {}
local orginLayer1
local orginLayer
local isUpZhen = false
local teamHero = {}
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local jewerConfigs = ConfigManager.GetConfig(ConfigName.JewelConfig)
local currPageIndex = 0
local curEquipTreasureDatas = {}
local isCanUpEquipTreasure = false
--初始化组件（用于子类重写）RoleEquipChangePopup
function RoleEquipPanel:InitComponent()
    orginLayer = 10
    orginLayer1 = {0, 0, 0, 0, 0, 0}
    this.bg2 = Util.GetGameObject(self.transform, "bg2")
    screenAdapte(this.bg2)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, {showType = UpViewOpenType.ShowLeft})
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    --英雄
    this.heroBg = Util.GetGameObject(self.transform, "bg/heroInfo/bg"):GetComponent("Image")
    this.heroLv = Util.GetGameObject(self.transform, "bg/heroInfo/lv/Text"):GetComponent("Text")
    this.heroIcon = Util.GetGameObject(self.transform, "bg/heroInfo/icon"):GetComponent("Image")
    Util.GetGameObject(self.transform, "bg/heroInfo/pos"):SetActive(false)
    --this.heroPosIcon = Util.GetGameObject(self.transform, "bg/heroInfo/pos/icon"):GetComponent("Image")
    this.heroProIcon = Util.GetGameObject(self.transform, "bg/heroInfo/pro/Image"):GetComponent("Image")
    --this.heroStage = Util.GetGameObject(self.transform, "bg/heroInfo/heroStage"):GetComponent("Image")
    Util.GetGameObject(self.transform, "bg/heroInfo/heroStage"):SetActive(false)
    this.heroStarGrid = Util.GetGameObject(self.transform, "bg/heroInfo/star")
    this.heroStarPre = Util.GetGameObject(self.transform, "bg/heroInfo/starPre")
    --英雄身上的装备
    this.equipGrid = Util.GetGameObject(self.transform, "bg/equipInfo")

    local scale = (Screen.width / Screen.height / 1080 * 1920 + 1) / 2
    if scale < 1 then
        for i = 1, this.equipGrid.transform.childCount do
            Util.SetParticleScale(Util.GetGameObject(this.equipGrid.transform:GetChild(i - 1), "effect"), scale)
        end
    end
    --装备list
    this.effect = Util.GetGameObject(self.transform, "bg/effect")
    for i = 0, 6 do
        tabs[i] = Util.GetGameObject(self.transform, "Tabs/Btn" .. i)
        effectList[i] = Util.GetGameObject(self.transform, "bg/equipInfo/equip" .. i .. "/effect")
    end
    this.selectBtn = Util.GetGameObject(self.gameObject, "selectBtn")
    this.btnPrant = Util.GetGameObject(self.gameObject, "Tabs")
    this.equipPre = Util.GetGameObject(self.gameObject, "equipPre")
    this.grid = Util.GetGameObject(self.gameObject, "scroll/grid")
    this.selsectSkillImage = Util.GetGameObject(self.gameObject, "selsectSkillImage")

    this.ShaiXuanBtn = Util.GetGameObject(self.gameObject, "ShaiXuanBtn")
    this.ShaiXuanBtn:SetActive(false)
    this.ShaiXuanBtnLv = Util.GetGameObject(self.gameObject, "ShaiXuanBtn/Lv")
    this.ShaiXuanBtnQu = Util.GetGameObject(self.gameObject, "ShaiXuanBtn/Qu")
    this.leftBtn = Util.GetGameObject(self.transform, "leftBtn/GameObject")
    this.rightBtn = Util.GetGameObject(self.transform, "rightBtn/GameObject")
    this.allEquipUp = Util.GetGameObject(self.transform, "allEquipUp")
    this.allEquipDown = Util.GetGameObject(self.transform, "allEquipDown")
    this.allEquipUpRedPoint = Util.GetGameObject(self.transform, "allEquipUp/redPoint")

    this.ScrollBar = Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    local v2 = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    this.ScrollView =
        SubUIManager.Open(
        SubUIConfig.ScrollCycleView,
        Util.GetGameObject(self.transform, "scroll").transform,
        this.equipPre,
        this.ScrollBar,
        Vector2.New(-v2.x * 2, -v2.y * 2),
        1,
        5,
        Vector2.New(50, 15)
    )
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1

    this.force = Util.GetGameObject(self.transform, "powerBtn/value"):GetComponent("Text")
    this.itemNumText = Util.GetGameObject(self.transform, "itemNumText"):GetComponent("Text")
    this.upLvEffect = Util.GetGameObject(self.transform, "powerBtn/effect")
    this.equipTreasureBtn = Util.GetGameObject(self.transform, "equipTreasureBtn")
    this.treasure1 = Util.GetGameObject(self.transform, "bg/equipInfo/equip5")
    this.treasure2 = Util.GetGameObject(self.transform, "bg/equipInfo/equip6")
    this.treasurePage1 = Util.GetGameObject(self.transform, "Tabs/Btn5")
    this.treasurePage2 = Util.GetGameObject(self.transform, "Tabs/Btn6")
    this.emptyObj = Util.GetGameObject(self.transform, "emptyObj")
    this.emptyObj.gameObject:SetActive(false)
end

--绑定事件（用于子类重写）
function RoleEquipPanel:BindEvent()
    Util.AddClick(
        this.btnBack,
        function()
            PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
            if openThisPanel.RefreshHeroDatas then
                openThisPanel:RefreshHeroDatas(curHeroData, HeroManager.heroSortedDatas)
            end
            self:ClosePanel()
        end
    )
    Util.AddClick(
        this.leftBtn,
        function()
            this:LeftBtnOnClick()
        end
    )

    Util.AddClick(
        this.rightBtn,
        function()
            this:RightBtnOnClick()
        end
    )
    Util.AddOnceClick(
        this.allEquipUp,
        function()
            this:AllEquipUpBtnOnClick()
        end
    )

    Util.AddOnceClick(
        this.allEquipDown,
        function()
            this:AllEquipDownBtnOnClick()
        end
    )
    for i = 0, 6 do
        Util.AddClick(
            tabs[i],
            function()
                if i == indexBtnNum then
                    indexBtnNum = PosIdConst.All
                    this:OnClickAllBtn()
                else
                    indexBtnNum = i
                    this:OnClickTabBtn(indexBtnNum)
                end
            end
        )
    end
    Util.AddClick(
        this.equipTreasureBtn,
        function()
            if LengthOfTable(curEquipTreasureDatas) < 2 then
                PopupTipPanel.ShowTipByLanguageId(11825)
                return
            end
            UIManager.OpenPanel(UIName.EquipTreasureResonancePanel, curHeroData)
        end
    )
end

--添加事件监听（用于子类重写）
function RoleEquipPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Treasure.TreasureLvUp, this.CurrEquipDataChange)
end

--移除事件监听（用于子类重写）
function RoleEquipPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Treasure.TreasureLvUp, this.CurrEquipDataChange)
end

function this.CurrEquipDataChange()
    this.ShowHeroEquip()
    if indexBtnNum == PosIdConst.All then
        this:OnClickAllBtn()
    else
        this:OnClickTabBtn(indexBtnNum)
    end
end

--界面打开时调用（用于子类重写）
function RoleEquipPanel:OnOpen(...)
    local data = {...}
    if data[1] then
        curHeroData = data[1]
        HeroManager.roleEquipPanelCurHeroData = data[1]
    else
        curHeroData = HeroManager.roleEquipPanelCurHeroData
    end
    if data[2] then
        heroListData = data[2]
        HeroManager.roleEquipPanelHeroListData = data[2]
    else
        heroListData = HeroManager.GetAllHeroDatas()
    end
    openThisPanel = data[3]
    isUpZhen = data[4]
end
function RoleEquipPanel:OnShow()
    for i = 1, #heroListData do
        if curHeroData == heroListData[i] then
            index = i
        end
    end
    for i = 1, 6 do
        if (effectList[i] ~= nil) then
            effectList[i]:SetActive(false)
        end
    end
    indexBtnNum = PosIdConst.All
    teamHero = FormationManager.GetAllFormationHeroId()
    this.ShowHeroEquip(true)
    this:OnClickAllBtn()
    this.UpView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main})
end

function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, this.sortingOrder - orginLayer)
    orginLayer = this.sortingOrder
end

--右切换按钮点击
function this:RightBtnOnClick()
    index = (index + 1 <= #heroListData and index + 1 or 1)
    curHeroData = heroListData[index]
    this.ShowHeroEquip()
    if indexBtnNum == PosIdConst.All then
        this:OnClickAllBtn()
    else
        this:OnClickTabBtn(indexBtnNum)
    end
end
--左切换按钮点击
function this:LeftBtnOnClick()
    index = (index - 1 > 0 and index - 1 or #heroListData)
    curHeroData = heroListData[index]
    this.ShowHeroEquip()
    if indexBtnNum == PosIdConst.All then
        this:OnClickAllBtn()
    else
        this:OnClickTabBtn(indexBtnNum)
    end
end

--一键装备
function this:AllEquipUpBtnOnClick()
    local allEquipIds = {}
    local allTreasureIds = {}

    --计算英雄身上的所有装备位的装备
    local curHeroEquipDatas = {}
    for k, v in ipairs(curHeroData.equipIdList) do
        local equipData = EquipManager.GetSingleHeroSingleEquipData(v, curHeroData.dynamicId)
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        else

        end
    end

    --宝物数据
    for k, v in ipairs(curHeroData.jewels) do
        local equipData = EquipTreasureManager.GetSingleTreasureByIdDyn(v)
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipType + 4] = equipData
        end
    end

    local equipEffectPos = {}
    local treasureEffectPos = {}
    for i = 1, 6 do
        local curPosEquip = {}
        local index = i
        if index == 5 or index == 6 and isCanUpEquipTreasure then
            curPosEquip =
                EquipTreasureManager.GetTreasureDataByPos(
                index,
                curHeroData.dynamicId,
                curHeroData.heroConfig.PropertyName
            )
        else
            --获取到所有未装备的装备
            curPosEquip = BagManager.GetEquipDataByEquipPosition(curHeroData.heroConfig.Profession, index)
        end

        --计算每个位置可装备的装备战力 取战力最大的装备
        if curPosEquip and #curPosEquip > 0 then
            local equiData = {}
            local indexMaxPower = 0
            if curHeroEquipDatas[index] then
                equiData = curHeroEquipDatas[index]
                if curHeroEquipDatas[index].idDyn then
                    indexMaxPower = EquipTreasureManager.CalculateWarForce(curHeroEquipDatas[index].idDyn)
                else
                    indexMaxPower = EquipManager.CalculateWarForce(curHeroEquipDatas[index].id)
                end
            end
            for i = 1, #curPosEquip do
                local addPower = 0
                local curEquip = curPosEquip[i]
                if curEquip then
                    if curEquip.idDyn then
                        addPower = EquipTreasureManager.CalculateWarForce(curEquip.idDyn)
                    else
                        addPower = EquipManager.CalculateWarForce(curEquip.id)
                    end
                end
                if addPower >= indexMaxPower then
                    indexMaxPower = addPower
                    equiData = curEquip
                end
            end
            if equiData.idDyn and isCanUpEquipTreasure and ((curHeroEquipDatas[index] and equiData.idDyn ~= curHeroEquipDatas[index].idDyn) or (not curHeroEquipDatas[index])) then
                table.insert(allTreasureIds, equiData.idDyn)
            else
                if not curHeroEquipDatas[index] or tonumber(equiData.id) ~= tonumber(curHeroEquipDatas[index].id) then
                    table.insert(allEquipIds, tostring(equiData.id))
                end
            end
            --特效
            if curHeroEquipDatas[equiData.position] then
                if equiData.idDyn then
                    if equiData.idDyn ~= curHeroEquipDatas[equiData.position].idDyn then
                        table.insert(treasureEffectPos, i)
                    end
                else
                    if equiData.id ~= curHeroEquipDatas[equiData.position].id then
                        table.insert(equipEffectPos, i)
                    end
                end
            else
                --table.insert(showEffectPos,i)
            end
        end
    end
    if (allEquipIds and #allEquipIds > 0) or (isCanUpEquipTreasure and allTreasureIds and #allTreasureIds > 0) then
        --isCanUpEquipTreasure
        if allEquipIds and #allEquipIds > 0 then
            -- for i = 1, #allEquipIds do
            
            -- end
            --穿装备协议
            NetManager.EquipWearRequest(
                curHeroData.dynamicId,
                allEquipIds,
                1,
                function()
                    this.UpdateEquipPosHeroData(1, 4, allEquipIds)
                    --特效播放
                    if equipEffectPos then
                        for i = 1, #equipEffectPos do
                            effectList[equipEffectPos[i]]:SetActive(false)
                            effectList[equipEffectPos[i]]:SetActive(true)
                        end
                    end
                end
            )
        end
        --穿戴宝物
        if allTreasureIds and #allTreasureIds > 0 then
            --for i = 1, #allEquipIds do
            
            --end
            --穿装备协议
            NetManager.EquipWearRequest(
                curHeroData.dynamicId,
                allTreasureIds,
                2,
                function()
                    this.UpdateEquipPosHeroData(2, 4, allTreasureIds)
                    --特效播放
                    for i, v in pairs(treasureEffectPos) do
                        effectList[v]:SetActive(false)
                        effectList[v]:SetActive(true)
                    end
                end
            )
        end
    else
        if not allEquipIds or #allEquipIds < 1  then
            PopupTipPanel.ShowTipByLanguageId(11826)
        else
            PopupTipPanel.ShowTipByLanguageId(11827)
        end
    end
    PlaySoundWithoutClick(SoundConfig.Sound_Wear)
    this.ShowHeroEquip()
end

--一键卸下
function this:AllEquipDownBtnOnClick()
    if
        (curHeroData.equipIdList and #curHeroData.equipIdList > 0) or
            (curHeroData.jewels and #curHeroData.jewels > 0 and isCanUpEquipTreasure)
     then
        if curHeroData.equipIdList and #curHeroData.equipIdList > 0 then
            
            
            
            NetManager.EquipUnLoadOptRequest(
                curHeroData.dynamicId,
                curHeroData.equipIdList,
                1,
                function()
                    this.UpdateEquipPosHeroData(1, 5, curHeroData.equipIdList)
                end
            )
        end
        --寶物
        if curHeroData.jewels and #curHeroData.jewels > 0 then
            -- 一键卸下音效
            NetManager.EquipUnLoadOptRequest(
                curHeroData.dynamicId,
                curHeroData.jewels,
                2,
                function()
                    this.UpdateEquipPosHeroData(2, 5, curHeroData.jewels)
                end
            )
        end
    else
        PopupTipPanel.ShowTipByLanguageId(11828)
    end
    PlaySoundWithoutClick(SoundConfig.Sound_TakeOff)
    this.ShowHeroEquip()
    -- this:OnClickTabBtn(indexBtnNum)
end

function this.ShowHeroEquip()
    --装备
    if curHeroData and spcialConfig then
        local config = spcialConfig[40]
        if config then
            local limits = string.split(config.Value, "|")
            if limits then
                local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, curHeroData.id)
                local lvs = string.split(limits[1], "#")
                local stars = string.split(limits[2], "#")
                if
                    PlayerManager.level >= tonumber(lvs[2]) and heroConfig ~= nil and
                        heroConfig.MaxRank >= tonumber(stars[2])
                 then
                    isCanUpEquipTreasure = true
                    this.equipTreasureBtn.gameObject:SetActive(true)
                    this.treasure1.gameObject:SetActive(true)
                    this.treasure2.gameObject:SetActive(true)
                    this.treasurePage1.gameObject:SetActive(true)
                    this.treasurePage2.gameObject:SetActive(true)
                else
                    isCanUpEquipTreasure = false
                    this.equipTreasureBtn.gameObject:SetActive(false)
                    this.treasure1.gameObject:SetActive(false)
                    this.treasure2.gameObject:SetActive(false)
                    this.treasurePage1.gameObject:SetActive(false)
                    this.treasurePage2.gameObject:SetActive(false)
                end
            end
        end
    end
    this.heroBg.sprite = Util.LoadSprite(GetHeroCardQuantityImage[curHeroData.heroConfig.Quality])
    this.heroLv.text = curHeroData.lv
    this.heroIcon.sprite = Util.LoadSprite(curHeroData.painting)
    --this.heroPosIcon.sprite = Util.LoadSprite(curHeroData.professionIcon)
    this.heroProIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(curHeroData.heroConfig.PropertyName))
    --this.heroStage.sprite = Util.LoadSprite(HeroStageSprite[curHeroData.heroConfig.HeroStage])
    SetHeroStars(this.heroStarGrid, curHeroData.star)
    --装备的数据
    curHeroEquipDatas = {}
    for i = 1, #curHeroData.equipIdList do
        local equipData = EquipManager.GetSingleHeroSingleEquipData(curHeroData.equipIdList[i], curHeroData.dynamicId)
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        end
    end
    --宝器的数据
    curEquipTreasureDatas = {}
    
    for i = 1, #curHeroData.jewels do
        local treasureData = EquipTreasureManager.GetSingleEquipTreasreData(curHeroData.jewels[i])
        if treasureData ~= nil then
            local id = treasureData.id
            local pos = jewerConfigs[id].Location + 4
            curEquipTreasureDatas[pos] = treasureData
        end
    end
    --this.equipTreasureBtn:SetActive(LengthOfTable(curEquipTreasureDatas) >= 2)
    for i = 1, this.equipGrid.transform.childCount do
        local go = this.equipGrid.transform:GetChild(i - 1).gameObject
        local effect = Util.GetGameObject(go.transform, "effect")
        screenAdapte(effect)
        Util.AddParticleSortLayer(effect, this.sortingOrder - orginLayer1[i])
        orginLayer1[i] = this.sortingOrder
        effectList[i] = effect
        local lvObj = Util.GetGameObject(go.transform, "lv")
        local refineObj = Util.GetGameObject(go.transform, "refine")
        if curHeroEquipDatas[i] then
            Util.GetGameObject(go.transform, "frame"):SetActive(true)
            Util.GetGameObject(go.transform, "mask"):SetActive(false)
            --Util.GetGameObject(go.transform,"proIcon"):SetActive(false)
            Util.GetGameObject(go.transform, "frame/icon"):GetComponent("Image").sprite =
                Util.LoadSprite(curHeroEquipDatas[i].icon)
            Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite =
                Util.LoadSprite(curHeroEquipDatas[i].frame)
            --Util.GetGameObject(go.transform,"proIcon"):GetComponent("Image").sprite=Util.LoadSprite(curHeroEquipDatas[i].frame)
            if lvObj then
                lvObj:SetActive(false)
            end
            if refineObj then
                refineObj:SetActive(false)
            end
            EquipManager.SetEquipStarShow(
                Util.GetGameObject(go.transform, "frame/star"),
                curHeroEquipDatas[i].itemConfig.Id
            )
        elseif curEquipTreasureDatas[i] then
            Util.GetGameObject(go.transform, "frame"):SetActive(true)
            Util.GetGameObject(go.transform, "mask"):SetActive(false)
            --Util.GetGameObject(go.transform,"proIcon"):SetActive(true)
            Util.GetGameObject(go.transform, "frame/icon"):GetComponent("Image").sprite =
                Util.LoadSprite(curEquipTreasureDatas[i].icon)
            Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite =
                Util.LoadSprite(curEquipTreasureDatas[i].frame)
            --Util.GetGameObject(go.transform,"proIcon"):GetComponent("Image").sprite=Util.LoadSprite(GetProStrImageByProNum(curEquipTreasureDatas[i].itemConfig.PropertyName))
            Util.GetGameObject(go.transform, "frame/star"):SetActive(false)
            Util.GetGameObject(go.transform, "num").gameObject:SetActive(false)
            if curEquipTreasureDatas[i].lv > 0 and lvObj then
                lvObj:GetComponent("Text").text = curEquipTreasureDatas[i].lv
                lvObj:SetActive(true)
            else
                lvObj:SetActive(false)
            end
            if curEquipTreasureDatas[i].refineLv > 0 then
                refineObj:GetComponent("Text").text = "+" .. curEquipTreasureDatas[i].refineLv
                refineObj:SetActive(true)
            else
                refineObj:SetActive(false)
            end
        else
            Util.GetGameObject(go.transform, "frame"):SetActive(false)
            Util.GetGameObject(go.transform, "mask"):SetActive(true)
            if Util.GetGameObject(go.transform, "num") then
                Util.GetGameObject(go.transform, "num").gameObject:SetActive(false)
            end
            if lvObj then
                lvObj:SetActive(false)
            end
            if refineObj then
                refineObj:SetActive(false)
            end
        end
        local iconBtn = Util.GetGameObject(go.transform, "icon")
        Util.AddOnceClick(
            iconBtn,
            function()
                if curHeroEquipDatas[i] then
                    curSelectEquipData = curHeroEquipDatas[i]
                    UIManager.OpenPanel(UIName.RoleEquipChangePopup, this, 2, curHeroData, curHeroEquipDatas[i])
                elseif curEquipTreasureDatas[i] then
                    if itemConfig[curEquipTreasureDatas[i].id].ItemType == ItemType.EquipTreasure then
                        local pos = 0
                        local jewerConfig =
                            ConfigManager.TryGetConfigData(ConfigName.JewelConfig, curEquipTreasureDatas[i].id)
                        if jewerConfig then
                            if jewerConfig.Location == 1 then
                                pos = 5
                            elseif jewerConfig.Location == 2 then
                                pos = 6
                            end
                            UIManager.OpenPanel(
                                UIName.RoleEquipTreasureChangePopup,
                                this,
                                2,
                                curHeroData,
                                curEquipTreasureDatas[i],
                                nil,
                                pos
                            )
                        end
                    end
                end
            end
        )
    end
    local allAddProVal = HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId, false)
    this.force.text = allAddProVal[HeroProType.WarPower]
end

function this:SetSelectBtn()
    this.selectBtn:SetActive(indexBtnNum ~= PosIdConst.All)
    if indexBtnNum ~= PosIdConst.All then
        this.selectBtn.transform:SetParent(tabs[indexBtnNum].transform)
        this.selectBtn.transform.localPosition = Vector3(0, 0, 0) 
        --this.selectBtn.transform.localScale = Vector3.one
        --this.selectBtn:GetComponent("Image"):SetNativeSize()
        Util.GetGameObject(this.selectBtn.transform, "Text"):GetComponent("Text").text = typeTab[indexBtnNum]
    end
end

--点击全部按钮
function this:OnClickAllBtn()
    this:SetSelectBtn()
    local itemData = BagManager.GetEquipDataByEquipPosition(curHeroData.heroConfig.Profession)
    this:SortEquipDatas(itemData)
    local count = 0
        for i=1,#itemData do
            count = count + itemData[i].num
        end
    --加上宝器数据
    local curAllEquipTreasure = EquipTreasureManager.GetAllTreasures(curHeroData.heroConfig.PropertyName)
    --宝器排序
    for i = 1, #curAllEquipTreasure do
        table.insert(itemData, curAllEquipTreasure[i])
    end
    this.itemNumText.text = GetLanguageStrById(10188) .. count + LengthOfTable(curAllEquipTreasure)
    this:SetItemData(itemData)
end

--点击装备按钮
function this:OnClickTabBtn(_index)
    this:SetSelectBtn()
    if _index < 5 then
        local allEquip = BagManager.GetEquipDataByEquipPosition(curHeroData.heroConfig.Profession, _index)
        this:SortEquipDatas(allEquip)
        local count = 0
        for i=1,#allEquip do
            count = count + allEquip[i].num
        end
        this.itemNumText.text = GetLanguageStrById(10188) .. count
        this:SetItemData(allEquip)
    else
        local allEquipTreasure
        allEquipTreasure =
            EquipTreasureManager.GetAllTreasuresByLocation(_index - 4, curHeroData.heroConfig.PropertyName)
        table.sort(
            allEquipTreasure,
            function(a, b)
                if a.refineLv == b.refineLv then
                    if a.lv == b.lv then
                        return a.id > b.id
                    else
                        return a.lv > b.lv
                    end
                else
                    return a.refineLv > b.refineLv
                end
            end
        )
        this.itemNumText.text = GetLanguageStrById(10188) .. LengthOfTable(allEquipTreasure)
        this:SetItemData(allEquipTreasure)      
    end
end

--设置背包列表数据
local curHeroCanUpEquipTabs = {}
function this:SetItemData(_itemDatas) 
    if LengthOfTable(_itemDatas) == 0 then
        this.emptyObj.gameObject:SetActive(true)
    else
        this.emptyObj.gameObject:SetActive(false)
    end
    --this:SortEquipDatas(_itemDatas)
    --做装备叠加特殊组拼数据
    -- local equips = {}
    -- for i = 1, #_itemDatas do
    --     --table.insert(equips,v)
    --     if equips[_itemDatas[i].id] then
    --         equips[_itemDatas[i].id].num = equips[_itemDatas[i].id].num + 1
    --     else
    --         equips[_itemDatas[i].id] = _itemDatas[i]
    --         equips[_itemDatas[i].id].num = 1
    --     end
    -- end
    -- local showList = {}
    -- for i, v in pairs(equips) do
    --     table.insert(showList, v)
    -- end
    this.ScrollView:SetData(
        _itemDatas,
        function(index, go)
            this.SingleItemDataShow(go, _itemDatas[index])
        end
    )
end
function this.SingleItemDataShow(_go, _itemData)
    if not itemConfig[_itemData.id] then
        return
    end
    local frame = Util.GetGameObject(_go.transform, "frame"):GetComponent("Image")
    local icon = Util.GetGameObject(_go.transform, "icon"):GetComponent("Image")
    local name = Util.GetGameObject(_go.transform, "name"):GetComponent("Text")
    local star = Util.GetGameObject(_go.transform, "star")
    local proIcon = Util.GetGameObject(_go.transform, "proIcon")
    local jewerConfig = ConfigManager.TryGetConfigData(ConfigName.JewelConfig, _itemData.id)
    local pos = 0
    if jewerConfig then
        Util.GetGameObject(_go.transform, "num").gameObject:SetActive(false)
        if jewerConfig.Location == 1 then
            pos = 5
        else
            if jewerConfig.Location == 2 then
                pos = 6
            end
        end
    else
        Util.GetGameObject(_go.transform, "num").gameObject:SetActive(true)
        Util.GetGameObject(_go.transform, "num"):GetComponent("Text").text = _itemData.num
    end
    local lvObj = Util.GetGameObject(_go.transform, "lv"):GetComponent("Text")
    local refineObj = Util.GetGameObject(_go.transform, "refine"):GetComponent("Text")
    if itemConfig[_itemData.id].ItemType == ItemType.EquipTreasure then
        icon.sprite = Util.LoadSprite(_itemData.icon)
        frame.sprite = Util.LoadSprite(_itemData.frame)
        proIcon:SetActive(true)
        proIcon:GetComponent("Image").sprite =
            Util.LoadSprite(GetProStrImageByProNum(_itemData.itemConfig.PropertyName))
        name.text = GetLanguageStrById(itemConfig[_itemData.id].Name)
        star:SetActive(false)
        Util.GetGameObject(_go.transform, "redPoint"):SetActive(false)
        lvObj.text = _itemData.lv
        if _itemData.lv > 0 then
            lvObj.gameObject:SetActive(true)
        else
            lvObj.gameObject:SetActive(false)
        end
        refineObj.text = "+" .. _itemData.refineLv
        if _itemData.refineLv > 0 then
            refineObj.gameObject:SetActive(true)
        else
            refineObj.gameObject:SetActive(false)
        end
        -- 0.查看属性  1.穿戴 2.卸下  3.交换
        --宝物界面
        Util.AddOnceClick(
            Util.GetGameObject(_go.transform, "icon"),
            function()
                if curEquipTreasureDatas[pos] then
                    UIManager.OpenPanel(
                        UIName.RoleEquipTreasureChangePopup,
                        this,
                        3,
                        curHeroData,
                        curEquipTreasureDatas[pos],
                        _itemData,
                        pos
                    )
                else
                    UIManager.OpenPanel(UIName.RoleEquipTreasureChangePopup, this, 1, curHeroData, _itemData, nil, pos)
                end
            end
        )
    else
        frame.sprite = Util.LoadSprite(_itemData.frame)
        icon.sprite = Util.LoadSprite(_itemData.icon)
        lvObj.gameObject:SetActive(false)
        refineObj.gameObject:SetActive(false)
        proIcon:SetActive(false)
        name.text = _itemData.itemConfig.Name
        star:SetActive(true)
        EquipManager.SetEquipStarShow(star, _itemData.itemConfig.Id)
        local redPoint = Util.GetGameObject(_go.transform, "redPoint")
        if curHeroCanUpEquipTabs and #curHeroCanUpEquipTabs > 0 then
            local isShow = false
            for i = 1, #curHeroCanUpEquipTabs do
                if curHeroCanUpEquipTabs[i] == _itemData.id then
                    isShow = true
                end
            end
            if isShow then
                redPoint:SetActive(true)
            else
                redPoint:SetActive(false)
            end
        else
            redPoint:SetActive(false)
        end
        Util.GetGameObject(_go.transform, "num"):GetComponent("Text").text = _itemData.num
        Util.AddOnceClick(
            Util.GetGameObject(_go.transform, "icon"),
            function()
                if curHeroEquipDatas[equipConfig[_itemData.id].Position] then
                    local nextEquipData = EquipManager.GetSingleEquipData(_itemData.id)
                    UIManager.OpenPanel(
                        UIName.RoleEquipChangePopup,
                        this,
                        3,
                        curHeroData,
                        curHeroEquipDatas[equipConfig[_itemData.id].Position],
                        nextEquipData,
                        equipConfig[_itemData.id].Position
                    )
                else
                    UIManager.OpenPanel(
                        UIName.RoleEquipChangePopup,
                        this,
                        1,
                        curHeroData,
                        _itemData,
                        equipConfig[_itemData.id].Position
                    )
                end
            end
        )
    end
end
--刷新当前英雄装备坑位的信息
function this.UpdateEquipPosHeroData(_equipOrTreasure, _type, _selectEquipDataList, _oldSelectEquip, position) --type
    --1 穿单件装备  2 卸单件装备 3 替换单件装备 4 一键穿装备  5一键脱装备
    if _type == 1 then
        effectList[position]:SetActive(false)
        effectList[position]:SetActive(true)
        if _equipOrTreasure == 1 then
            curSelectEquipData = _selectEquipDataList[1]
            --装备绑英雄
            EquipManager.SetEquipUpHeroDid(curSelectEquipData.id, curHeroData.dynamicId)
            --英雄加装备
            table.insert(curHeroData.equipIdList, curSelectEquipData.id)
            HeroManager.SetHeroEquipIdList(curHeroData.dynamicId, curHeroData.equipIdList)
        else
            curEquipTreasureDatas = _selectEquipDataList[1]
            --装备绑英雄
            EquipTreasureManager.SetEquipTreasureUpHeroDid(curEquipTreasureDatas.idDyn, curHeroData.dynamicId)
            --英雄加装备
            table.insert(curHeroData.jewels, curEquipTreasureDatas.idDyn)
        end
    elseif _type == 2 then
        if _equipOrTreasure == 1 then
            --装备解绑英雄
            curSelectEquipData = _selectEquipDataList[1]
            EquipManager.DeleteSingleEquip(curSelectEquipData.id, curHeroData.dynamicId)
            for i = 1, #curHeroData.equipIdList do
                if tonumber(curHeroData.equipIdList[i]) == tonumber(curSelectEquipData.id) then
                    --英雄删除装备
                    table.remove(curHeroData.equipIdList, i)
                    break
                end
            end
            HeroManager.SetHeroEquipIdList(curHeroData.dynamicId, curHeroData.equipIdList)
        else
            curEquipTreasureDatas = _selectEquipDataList[1]
            EquipTreasureManager.SetEquipTreasureUpHeroDid(curEquipTreasureDatas.idDyn, "")
            for i = 1, #curHeroData.jewels do
                if curHeroData.jewels[i] == curEquipTreasureDatas.idDyn then
                    --英雄删除装备
                    table.remove(curHeroData.jewels, i)
                    break
                end
            end
        end
    elseif _type == 3 then
        effectList[position]:SetActive(false)
        effectList[position]:SetActive(true)
        if _equipOrTreasure == 1 then
            curSelectEquipData = _selectEquipDataList[1]
            EquipManager.SetEquipUpHeroDid(curSelectEquipData.id, curHeroData.dynamicId)
            --穿
            if _oldSelectEquip and tonumber(_oldSelectEquip.id) ~= tonumber(curSelectEquipData.id) then
                EquipManager.DeleteSingleEquip(_oldSelectEquip.id, curHeroData.dynamicId)
            end

            --英雄替换新选择装备
            if curHeroEquipDatas[curSelectEquipData.equipConfig.Position] then
                for i = 1, #curHeroData.equipIdList do
                    if
                        tonumber(curHeroData.equipIdList[i]) ==
                            tonumber(curHeroEquipDatas[curSelectEquipData.equipConfig.Position].id)
                     then
                        curHeroData.equipIdList[i] = curSelectEquipData.id
                        break
                    end
                end
            end
            HeroManager.SetHeroEquipIdList(curHeroData.dynamicId, curHeroData.equipIdList)
        else
            curEquipTreasureDatas = _selectEquipDataList[1]
            --新装备绑英雄
            EquipTreasureManager.SetEquipTreasureUpHeroDid(curEquipTreasureDatas.idDyn, curHeroData.dynamicId)
            if _oldSelectEquip then
                --被替换装备解绑英雄
                EquipTreasureManager.SetEquipTreasureUpHeroDid(_oldSelectEquip.idDyn, "")
            end
            --英雄替换新选择装备
            for i = 1, #curHeroData.jewels do
                if curHeroData.jewels[i] == _oldSelectEquip.idDyn then
                    curHeroData.jewels[i] = curEquipTreasureDatas.idDyn
                end
            end
        end
    elseif _type == 4 then
        --一键穿  把身上装备解绑英雄id
        if _equipOrTreasure == 1 then
            -- for i=1,#_selectEquipDataList do
            --     local temp = EquipManager.GetSingleHeroSingleEquipData(_selectEquipDataList[i],curHeroData.dynamicId)
            --     if not temp then
            
            --     end
            -- end
            --宝物
            for n, m in ipairs(_selectEquipDataList) do
                local isadd = true
                for i = 1, #curHeroData.equipIdList do
                    if equipConfig[tonumber(curHeroData.equipIdList[i])].Position == equipConfig[tonumber(m)].Position then
                        EquipManager.DeleteSingleEquip(curHeroData.equipIdList[i], curHeroData.dynamicId)
                        curHeroData.equipIdList[i] = m
                        HeroManager.GetHeroEquipIdList1(curHeroData.dynamicId, m)
                        isadd = false
                        break
                    end
                end
                if isadd then
                    table.insert(curHeroData.equipIdList, m)
                end
            end
            EquipManager.UpdateEquipData(_selectEquipDataList, curHeroData.dynamicId)
        else
            for k, v in ipairs(curHeroData.jewels) do
                EquipTreasureManager.SetTreasureUpOrDown(v, "0")
            end
            curHeroData.jewels = {}
            for i = 1, #_selectEquipDataList do
                --把选择的装备绑上英雄
                EquipTreasureManager.SetTreasureUpOrDown(_selectEquipDataList[i], curHeroData.dynamicId)
                --穿
                --再把英雄装备list 清空并添加上新选择的装备
                table.insert(curHeroData.jewels, _selectEquipDataList[i])
            end
        end
    elseif _type == 5 then
        --一键脱  把身上装备英雄id置为“0”   再把英雄装备list清空
        if _equipOrTreasure == 1 then
            if _selectEquipDataList then
                for i = 1, #_selectEquipDataList do
                    EquipManager.DeleteSingleEquip(_selectEquipDataList[i], curHeroData.dynamicId)
                end
            end
            curHeroData.equipIdList = {}
            HeroManager.SetHeroEquipIdList(curHeroData.dynamicId, {})
            curHeroData.equipIdList = {}
        else
            if _selectEquipDataList then
                for i = 1, #_selectEquipDataList do
                    EquipTreasureManager.SetTreasureUpOrDown(_selectEquipDataList[i], "")
                end
                curHeroData.jewels = {}
            end
        end
    end
    --刷新界面
    this.ShowHeroEquip()
    --上阵刷新红点
    this.allEquipUpRedPoint:SetActive(#HeroManager.GetHeroIsUpEquip(curHeroData.dynamicId) > 0 and isUpZhen)
    --刷新当前英雄可穿装备
    if indexBtnNum == PosIdConst.All then
        this:OnClickAllBtn()
    else
        this:OnClickTabBtn(indexBtnNum)
    end
    --对比战力并更新战力值 播放战力变更动画
    HeroManager.CompareWarPower(curHeroData.dynamicId)
end

--选择图片设置父级
function this.SelectImageSetParent(_objPoint)
    this.selsectSkillImage:SetActive(false)
    this.selsectSkillImage.transform:SetParent(_objPoint.transform)
    this.selsectSkillImage.transform.localScale = Vector3.one
    this.selsectSkillImage.transform.localPosition = Vector3.zero
end
--界面关闭时调用（用于子类重写）
function RoleEquipPanel:OnClose()
end
function this:AddRedPointVale(_equipDatas)
    for j = 1, #_equipDatas do
        _equipDatas[j].isRedPointShow = 1
        for i = 1, #curHeroCanUpEquipTabs do
            if curHeroCanUpEquipTabs[i] == _equipDatas[j].id then
                _equipDatas[j].isRedPointShow = 2
            end
        end
    end
end

function this:SortEquipDatas(_equipDatas)
    if teamHero[curHeroData.dynamicId] then
        isUpZhen = true
        this.allEquipUpRedPoint:SetActive(#HeroManager.GetHeroIsUpEquip(curHeroData.dynamicId) > 0)
        curHeroCanUpEquipTabs = HeroManager.GetHeroIsUpEquip(curHeroData.dynamicId)
    else
        isUpZhen = false
        this.allEquipUpRedPoint:SetActive(false)
        curHeroCanUpEquipTabs = {}
    end
    this:AddRedPointVale(_equipDatas)
    table.sort(
        _equipDatas,
        function(a, b)
            if a.isRedPointShow == b.isRedPointShow then
                if a.itemConfig.Quantity == b.itemConfig.Quantity then
                    if equipConfig[a.id].Position == equipConfig[b.id].Position then
                        return a.id > b.id
                    else
                        return equipConfig[a.id].Position < equipConfig[b.id].Position
                    end
                else
                    return a.itemConfig.Quantity > b.itemConfig.Quantity
                end
            else
                return a.isRedPointShow > b.isRedPointShow
            end
        end
    )
end

-- --做装备叠加特殊组拼数据
-- function this:EquipDJDatas(_itemDatas)
--      local equips = {}
--      for i = 1, #_itemDatas do
--          if equips[_itemDatas[i].id] then
--              equips[_itemDatas[i].id].num = equips[_itemDatas[i].id].num + 1
--          else
--              equips[_itemDatas[i].id] = _itemDatas[i]
--              equips[_itemDatas[i].id].num = 1
--          end
--      end
--      local showList = {}
--      for i, v in pairs(equips) do
--          table.insert(showList, v)
--      end
--     return showList
-- end

--界面销毁时调用（用于子类重写）
function RoleEquipPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    this.ScrollView = nil
end
return RoleEquipPanel