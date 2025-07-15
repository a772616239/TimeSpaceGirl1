require("Base/BasePanel")
XiaoyaoHeroGetPopup = Inherit(BasePanel)
local this=XiaoyaoHeroGetPopup

local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local FreeTravelStore=ConfigManager.GetConfig(ConfigName.FreeTravelStore)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local artResourceConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)

local curHeroData = {}
local curIndex = 1
local heroData = {}
local pointPrefabs = {}
local allSkillDatas = {}
local costId = 0
local costNum = 0
local heroSData
--初始化组件（用于子类重写）
function XiaoyaoHeroGetPopup:InitComponent()
    -- this.spLoader = SpriteLoader.New()
    this.titleText = Util.GetGameObject(self.transform, "Panel/bg/title"):GetComponent("Text")
    this.BtnBack=Util.GetGameObject(self.transform, "Panel/bg/btnBack")
    this.remainTimes = Util.GetGameObject(self.transform, "Panel/remainTimes"):GetComponent("Text")

    this.liveRoot=Util.GetGameObject(self.transform, "Panel/liveRoot")
    this.liveImageRoot=Util.GetGameObject(self.transform, "Panel/liveRoot/posImage"):GetComponent("Image")
    this.heroName = Util.GetGameObject(self.transform, "Panel/RoleInfo/nameAndPossLayout/heroName"):GetComponent("Text")
    this.profession = Util.GetGameObject(self.transform, "Panel/RoleInfo/nameAndPossLayout/proImage/proImage"):GetComponent("Image")
    this.starGrid = Util.GetGameObject(self.transform, "Panel/RoleInfo/sartAndLvLayout")

    this.posBgImage = Util.GetGameObject(self.transform,"Panel/RoleInfo/pos"):GetComponent("Image")
    this.posImage=Util.GetGameObject(self.transform,"Panel/RoleInfo/pos/posImage"):GetComponent("Image")
    this.posText=Util.GetGameObject(self.transform,"Panel/RoleInfo/pos/posText"):GetComponent("Text")
   
    this.skillGrid=Util.GetGameObject(self.transform,"Panel/RoleInfo/skill")
    this.skillPre=Util.GetGameObject(self.transform,"Panel/RoleInfo/skill/sBg1")
   
    this.talismanBtn=Util.GetGameObject(self.transform,"Panel/RoleInfo/Other/TalismanBtn")
    this.talismanIcon=Util.GetGameObject(self.transform,"Panel/RoleInfo/Other/TalismanBtn/Icon"):GetComponent("Image")
    this.talentBtn=Util.GetGameObject(self.transform,"Panel/RoleInfo/Other/talentBtn")
    this.talentProgress=Util.GetGameObject(self.transform,"Panel/RoleInfo/Other/talentBtn/progress"):GetComponent("Text")

    this.costIcon=Util.GetGameObject(self.transform,"Panel/buyPanel/item/proImage/proImage"):GetComponent("Image")
    this.costNum=Util.GetGameObject(self.transform,"Panel/buyPanel/item/heroName"):GetComponent("Text")

    this.buyBtn = Util.GetGameObject(self.transform,"Panel/buyPanel/buy")

    this.pointGrid = Util.GetGameObject(self.transform,"Panel/buyPanel/grid")
    this.point = Util.GetGameObject(self.transform,"Panel/buyPanel/point")
    this.selectKuang = Util.GetGameObject(self.transform,"Panel/buyPanel/select")

    this.leftBtn= Util.GetGameObject(self.transform,"Panel/leftBtn")
    this.rightBtn = Util.GetGameObject(self.transform,"Panel/rightBtn")

    this.zhekouImage = Util.GetGameObject(self.transform,"Panel/buyPanel/Image"):GetComponent("Image")
end

local triggerCallBack
--绑定事件（用于子类重写）
function XiaoyaoHeroGetPopup:BindEvent()
    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.rightBtn, function()
        -- poolManager:UnLoadLive(this.testLiveGO.name, this.testLiveGO)
        this.testLiveGO = nil
        curIndex = curIndex + 1
        if curIndex > #heroData then
            curIndex = 1
        end
        curHeroData = heroData[curIndex]
        this:SetSelectHero(curHeroData)
    end)

    Util.AddClick(this.leftBtn, function()
        -- poolManager:UnLoadLive(this.testLiveGO.name, this.testLiveGO)
        this.testLiveGO = nil
        curIndex = curIndex - 1
        if curIndex < 1 then
            curIndex = #heroData
        end
        curHeroData = heroData[curIndex]
        this:SetSelectHero(curHeroData)
    end)

    Util.AddClick(this.buyBtn, function(msg)
        if BagManager.GetItemCountById(costId) < costNum then
            PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[costId].Name)..GetLanguageStrById(10657))
        else
        local rightAction = function() 
            NetManager.XiaoyaoyouGetHeroRequest(curHeroData.goodsIndex,function(msg)
                if  this.testLiveGO then
                    poolManager:UnLoadLive(this.testLiveGO.name, this.testLiveGO)
                    this.testLiveGO = nil
                end
                XiaoYaoManager.UpdateHeroData(curHeroData.goodsIndex)
                XiaoYaoManager.GetHeroIndex = 0
                this:OnShow()
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop,1)
            end)
        end
            --UIManager.OpenPanel(UIName.MsgPanel)
            MsgPanel.ShowTwo(GetLanguageStrById(11999)..GetLanguageStrById(50342)..costNum..GetLanguageStrById(itemConfig[costId].Name)..GetLanguageStrById(50343)..GetLanguageStrById(heroSData.ReadingName).."?", nil, rightAction, GetLanguageStrById(10719), GetLanguageStrById(10720), GetLanguageStrById(11351),false,"")          
        end
    end)
end
--添加事件监听（用于子类重写）
function XiaoyaoHeroGetPopup:AddListener()

end

--移除事件监听（用于子类重写）
function XiaoyaoHeroGetPopup:RemoveListener()

end
function this.CalculateHeroAllProValList(heroConFigData,_starNum,isCalculateStarVal)
    local allAddProVal = {}
    for i, v in ConfigPairs(propertyConfig) do
        allAddProVal[i] = 0
    end
    local heroRankupConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroRankupConfig, "Star", heroConFigData.Star, "LimitStar", _starNum)
    local curLvNum=1
    local breakId = 0
    local upStarId = 0
    if isCalculateStarVal then
        --等级
        curLvNum = heroRankupConfig.OpenLevel
        --解锁天赋
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.HeroRankupConfig)) do
            if v.OpenStar == _starNum and v.Star==heroConFigData.Star then
                if v.Type == 1 then
                    breakId = v.Id
                end
                if v.Type == 2 then
                    upStarId = v.Id
                end
            end
        end
        if breakId==0 then
            breakId=6
        end
    end
    allAddProVal[HeroProType.Attack]=HeroManager.CalculateProVal(heroConFigData.Attack, curLvNum, breakId,upStarId,HeroProType.Attack,heroConFigData)
    allAddProVal[HeroProType.Hp]=HeroManager.CalculateProVal(heroConFigData.Hp, curLvNum, breakId,upStarId,HeroProType.Hp,heroConFigData)
    allAddProVal[HeroProType.PhysicalDefence]=HeroManager.CalculateProVal(heroConFigData.PhysicalDefence, curLvNum, breakId,upStarId,HeroProType.PhysicalDefence,heroConFigData)
    allAddProVal[HeroProType.MagicDefence]=HeroManager.CalculateProVal(heroConFigData.MagicDefence, curLvNum, breakId,upStarId,HeroProType.Speed,heroConFigData)
    Util.AddOnceClick(this.talentBtn,function()
        UIManager.OpenPanel(UIName.RoleTalentPopup,heroConFigData,breakId,upStarId)
    end)
    if heroConFigData.OpenPassiveSkillRules then
        local openlists,compoundOpenNum,compoundNum = HeroManager.GetAllPassiveSkillIds(heroConFigData,breakId,upStarId)
        this.talentProgress.text = #openlists - compoundOpenNum .."/"..#heroConFigData.OpenPassiveSkillRules - compoundNum
    end
    return allAddProVal
end
--界面打开时调用（用于子类重写）
function XiaoyaoHeroGetPopup:OnOpen()
    this.titleText.text = GetLanguageStrById(12074)
end
function XiaoyaoHeroGetPopup:OnShow()
    curIndex = XiaoYaoManager.GetHeroIndex < 1 and 1 or XiaoYaoManager.GetHeroIndex
    heroData = XiaoYaoManager.GetHeroDatas()
    this.talentBtn:GetComponent("Image").sprite = Util.LoadSprite("r_hero_tianfu1_zh")
    if not heroData or #heroData < 1 then
        this:ClosePanel()
        return
    end

    curHeroData = heroData[curIndex]

    for i = 1 , #pointPrefabs do
        pointPrefabs[i].gameObject:SetActive(false)
    end
    for i = 1 , #heroData do
        if not pointPrefabs[i] then
            pointPrefabs[i] = newObjToParent(this.point,this.pointGrid)
        end
        pointPrefabs[i].gameObject:SetActive(true)
    end

    this:SetSelectHero(curHeroData)
end

function this:TimerDown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    local timeDown = curHeroData.remainTime - PlayerManager.serverTime
    local temp = 0
    this.remainTimes.text = GetLanguageStrById(11496)..TimeToHMS(timeDown)
    this.timer = Timer.New(function()
        if timeDown < 1 then
           XiaoYaoManager.GetHeroIndex = 0
           this:OnShow()         
           return 
        end
        for i = 1 , #heroData do
            temp = heroData[i].remainTime - PlayerManager.serverTime
            if temp < 1 then
                this:OnShow()
                return 
            end
        end
        timeDown = timeDown - 1
        this.remainTimes.text = GetLanguageStrById(11496)..TimeToHMS(timeDown)
    end, 1, -1, true)
    this.timer:Start()
end

function this:SetSelectHero(curHeroData)
    --LogGreen("curHeroData.goodsId  :"..curHeroData.goodsId)
    local heroSId = FreeTravelStore[curHeroData.goodsId].Goods[1]  
    heroSData = HeroConfig[heroSId]
    local heroStar = heroSData.Star
    -- allSkillDatas = HeroManager.GetCurHeroSidAndCurStarAllSkillDatas(heroSId,heroStar)   

    -- this.ShowHeroLive(heroSData)
    -- --星级
    -- -- SetHeroStars(this.spLoader, this.starGrid, heroSData.Star,1,Vector2.New(42.44,42.44),-7.28, Vector2.New(0.5,0.5), Vector3.New(0,0,-15))

    -- this.skillGrid:GetComponent("Canvas").sortingOrder = self.sortingOrder + 1
    -- local skillList = HeroManager.GetCurHeroSidAndCurStarAllSkillDatas2(heroSData.Id,heroSData.Star)
    -- local skillList = allSkillDatas



    local heroSData=ConfigManager.GetConfigData(ConfigName.HeroConfig, heroSId)
    local upStarRankUpConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroRankupConfig, "Star", heroSData.Star, "LimitStar", heroSData.Star)

    local oldSkillList=HeroManager.GetSkillIdsByHeroRulesRole(heroSData.OpenSkillRules,heroStar,upStarRankUpConfig.Phase[2])
    local oldOpenPassiveSkillRules=HeroManager.GetPassiveSkillIdsByHeroRuleslock(heroSData.OpenPassiveSkillRules,heroStar,upStarRankUpConfig.Phase[2])
    for key, value in pairs(oldOpenPassiveSkillRules) do
        table.insert(oldSkillList, value)
    end
    table.sort(oldSkillList,function(a,b) 
        return a.skillConfig.Id<b.skillConfig.Id
    end)

    for i = 1, this.skillGrid.transform.childCount do
        this.skillGrid.transform:GetChild(i-1).gameObject:SetActive(false)
    end
    for i = 2, #oldSkillList do
        if oldSkillList[i] and oldSkillList[i].skillConfig and oldSkillList[i].skillConfig.Name then
            local go = this.skillGrid.transform:GetChild(i-2).gameObject
            go:SetActive(true)
            Util.GetGameObject(go.transform,"s"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(oldSkillList[i].skillConfig.Icon))
            Util.GetGameObject(go.transform,"s/Text"):GetComponent("Text").text=SubString2(GetLanguageStrById(oldSkillList[i].skillConfig.Name),10)
            -- Util.GetGameObject(go.transform,"SkillTypeImage"):GetComponent("Image").sprite=Util.LoadSprite(GetSkillType(allSkillDatas[i]))
            Util.AddOnceClick(Util.GetGameObject(go.transform,"s"), function()
                local skillData = {}
                skillData.skillConfig = oldSkillList[i].skillConfig
                UIManager.OpenPanel(UIName.SkillInfoPopup,skillData,1,heroStar,1,i)
            end)
        end
    end
    --法宝
    this.talismanBtn.gameObject:SetActive(heroSData.EquipTalismana~=nil)
    if heroSData.EquipTalismana~=nil then
        this.talismanIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[heroSData.EquipTalismana[2]].ResourceID))
    end
    Util.AddOnceClick(this.talismanBtn.gameObject,function()
        UIManager.OpenPanel(UIName.TalismanInfoPopup,heroSData,1,1)
    end)
    this.selectKuang.transform:SetParent(pointPrefabs[curIndex].transform)
    this.selectKuang:GetComponent("RectTransform").localPosition = Vector3.zero
    this.ShowHeroBuyInfo(curHeroData)

    this.CalculateHeroAllProValList(heroSData,heroStar,heroStar ~= heroSData.Star)

    this:TimerDown()
end

function this.ShowHeroLive(_heroSConfigData)
    -- this.testLiveGO = poolManager:LoadLive(GetResourcePath(_heroSConfigData.Live), this.liveRoot.transform,
    --         Vector3.one * _heroSConfigData.Scale*0.7, Vector3.New(_heroSConfigData.PositionView[1], _heroSConfigData.PositionView[2], 0))
    this.liveImageRoot.sprite=Util.LoadSprite(GetResourcePath(_heroSConfigData.Painting))
    -- local SkeletonGraphic = this.testLiveGO:GetComponent("SkeletonGraphic")
    -- local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
    -- poolManager:SetLiveClearCall(GetResourcePath(_heroSConfigData.Live), this.testLiveGO, function ()
    --     SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
    -- end)
    
    this.posBgImage.sprite=Util.LoadSprite(GetHeroPosBgStr(_heroSConfigData.Profession))
    this.posImage.sprite=Util.LoadSprite(GetHeroPosStr(_heroSConfigData.Profession))
    this.posText.text=GetLanguageStrById(_heroSConfigData.HeroLocation)
	-- SetTextVerTial(this.posText,Vector3.New(83.4,0.5,0))
    this.heroName.text = GetLanguageStrById(_heroSConfigData.ReadingName)
  
    this.profession.sprite = Util.LoadSprite(GetProStrImageByProNum(_heroSConfigData.PropertyName))
end

function this.ShowHeroBuyInfo(_heroSConfigData)
    local heroBuyInfo = FreeTravelStore[curHeroData.goodsId]
    costId = heroBuyInfo.Cost[1]
    costNum = heroBuyInfo.Cost[2]
    this.costIcon.sprite = Util.LoadSprite(artResourceConfig[itemConfig[costId].ResourceID].Name) 
    if BagManager.GetItemCountById(costId) < costNum then
        this.costNum.text = "<color=#FF0000>" .. costNum .. "</color>"
    else
        this.costNum.text = "<color=#C8AD83>" .. costNum .. "</color>"
    end
    this.zhekouImage.sprite = Util.LoadSprite(heroBuyInfo.Discount)
end

--界面关闭时调用（用于子类重写）
function XiaoyaoHeroGetPopup:OnClose()
    Game.GlobalEvent:DispatchEvent(GameEvent.XiaoYao.RefreshEventShow)
    if  this.testLiveGO then
        poolManager:UnLoadLive(this.testLiveGO.name, this.testLiveGO)
        this.testLiveGO = nil
    end
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function XiaoyaoHeroGetPopup:OnDestroy()
    -- this.spLoader:Destroy()
    if  this.testLiveGO then
        poolManager:UnLoadLive(this.testLiveGO.name, this.testLiveGO)
        this.testLiveGO = nil
    end
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    pointPrefabs = {}
end

return XiaoyaoHeroGetPopup