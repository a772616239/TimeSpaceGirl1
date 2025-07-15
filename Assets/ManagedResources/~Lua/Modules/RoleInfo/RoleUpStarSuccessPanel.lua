require("Base/BasePanel")
RoleUpStarSuccessPanel = Inherit(BasePanel)
local this=RoleUpStarSuccessPanel
this.skillConfig=ConfigManager.GetConfig(ConfigName.SkillConfig)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local callBack = nil
local skillShowProList={}
local SkillLogicConfig=ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local PassiveSkillLogicConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
--初始化组件（用于子类重写）
function RoleUpStarSuccessPanel:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "backBtn")
    this.live2dRoot=Util.GetGameObject(self.transform,"live2dRoot")

    this.curPros = Util.GetGameObject(self.transform,"proInfo/curPros")
    this.upLvMaskPanleProPower = Util.GetGameObject(this.curPros,"mainPro/curProVale"):GetComponent("Text")
    this.upLvMaskPanleProAtk = Util.GetGameObject(this.curPros,"otherPro1/curProVale"):GetComponent("Text")
    this.upLvMaskPanleProHp = Util.GetGameObject(this.curPros,"otherPro2/curProVale"):GetComponent("Text")
    this.upLvMaskPanleProDef = Util.GetGameObject(this.curPros,"otherPro3/curProVale"):GetComponent("Text")
    this.upLvMaskPanleProSpeed = Util.GetGameObject(this.curPros,"otherPro4/curProVale"):GetComponent("Text")

    this.nextPros = Util.GetGameObject(self.transform,"proInfo/nextPros")
    this.upLvMaskPanleNextProPower = Util.GetGameObject(this.nextPros,"mainPro/curProVale"):GetComponent("Text")
    this.upLvMaskPanleNextProAtk = Util.GetGameObject(this.nextPros,"otherPro1/curProVale"):GetComponent("Text")
    this.upLvMaskPanleNextProHp = Util.GetGameObject(this.nextPros,"otherPro2/curProVale"):GetComponent("Text")
    this.upLvMaskPanleNextProDef = Util.GetGameObject(this.nextPros,"otherPro3/curProVale"):GetComponent("Text")
    this.upLvMaskPanleNextProSpeed = Util.GetGameObject(this.nextPros,"otherPro4/curProVale"):GetComponent("Text")

    this.lvEndInfo=Util.GetGameObject(self.transform, "proInfo/lvEndText"):GetComponent("Text")

    this.skillTiShi = Util.GetGameObject(self.transform,"proInfo/skillTiShi"):GetComponent("Text")
    this.heroPre=Util.GetGameObject(self.transform,"HeroPre")
    this.currentHero=Util.GetGameObject(self.transform,"heroInfo/currentHero")
    this.nextHero=Util.GetGameObject(self.transform,"heroInfo/nextHero")

    for i = 1, 4 do
        skillShowProList[i]=Util.GetGameObject(self.transform, "skillGroup/Skill" .. i)
    end
end

--绑定事件（用于子类重写）
function RoleUpStarSuccessPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RoleUpStarSuccessPanel:AddListener()

end

--移除事件监听（用于子类重写）
function RoleUpStarSuccessPanel:RemoveListener()

end

function RoleUpStarSuccessPanel:OnSortingOrderChange()

end

--界面打开时调用（用于子类重写）
function RoleUpStarSuccessPanel:OnOpen(...)
    local args = {...}
    local curHeroData=args[1]
    local nextHeroUpStarId=args[2]
    callBack = args[4]

    --计算面板属性old
    local oldLvAllAddProVal = HeroManager.CalculateHeroAllProValList(1,curHeroData.dynamicId,false)
    this.upLvMaskPanleProPower.text = oldLvAllAddProVal[HeroProType.WarPower]
    this.upLvMaskPanleProAtk.text = oldLvAllAddProVal[HeroProType.Attack]
    this.upLvMaskPanleProHp.text = oldLvAllAddProVal[HeroProType.Hp]
    this.upLvMaskPanleProDef.text = oldLvAllAddProVal[HeroProType.PhysicalDefence]
    this.upLvMaskPanleProSpeed.text =   oldLvAllAddProVal[HeroProType.Speed]
    --计算面板属性cur
    local curLvAllAddProVal = HeroManager.CalculateHeroAllProValList(2,curHeroData.dynamicId,false,curHeroData.breakId,nextHeroUpStarId)
    this.upLvMaskPanleNextProPower.text = curLvAllAddProVal[HeroProType.WarPower]
    this.upLvMaskPanleNextProAtk.text = curLvAllAddProVal[HeroProType.Attack]
    this.upLvMaskPanleNextProHp.text = curLvAllAddProVal[HeroProType.Hp]
    this.upLvMaskPanleNextProDef.text = curLvAllAddProVal[HeroProType.PhysicalDefence]
    this.upLvMaskPanleNextProSpeed.text = curLvAllAddProVal[HeroProType.Speed]
    --技能
    this.skillTiShi.text = GetLanguageStrById(11874)
    local upskillIdList={}
    local upIndex=1
    local curIndex=1
    local curskillIdList={}
    if curHeroData.heroConfig.OpenSkillRules then
        for i = 1, #curHeroData.heroConfig.OpenSkillRules do
            if curHeroData.heroConfig.OpenSkillRules[i][1]==curHeroData.star then
                local skilldata={}

                skilldata.skillId=curHeroData.heroConfig.OpenSkillRules[i][2]
                skilldata.skillConfig=this.skillConfig[curHeroData.heroConfig.OpenSkillRules[i][2]]
                upskillIdList[upIndex]=skilldata
                upIndex=upIndex+1
            end
            if curHeroData.heroConfig.OpenSkillRules[i][1]==curHeroData.star+1 then
                local skilldata={}

                skilldata.skillId=curHeroData.heroConfig.OpenSkillRules[i][2]
                skilldata.skillConfig=this.skillConfig[curHeroData.heroConfig.OpenSkillRules[i][2]]
                curskillIdList[curIndex]=skilldata
                curIndex=curIndex+1
            end
        end
    end
    if curHeroData.heroConfig.OpenPassiveSkillRules then
        for i = 1, #curHeroData.heroConfig.OpenPassiveSkillRules do
            if curHeroData.heroConfig.OpenPassiveSkillRules[i][1]==curHeroData.star then
                local skilldata={}

                skilldata.skillId=curHeroData.heroConfig.OpenPassiveSkillRules[i][2]
                skilldata.skillConfig=passiveSkillConfig[curHeroData.heroConfig.OpenPassiveSkillRules[i][2]]
                upskillIdList[upIndex]=skilldata
                upIndex=upIndex+1
            end
            if curHeroData.heroConfig.OpenPassiveSkillRules[i][1]==curHeroData.star+1 then
                local skilldata={}

                skilldata.skillId=curHeroData.heroConfig.OpenPassiveSkillRules[i][2]
                skilldata.skillConfig=passiveSkillConfig[curHeroData.heroConfig.OpenPassiveSkillRules[i][2]]
                curskillIdList[curIndex]=skilldata
                curIndex=curIndex+1
            end
        end
    end

    --是否有新开的技能
    local openNewSkillCound = LengthOfTable(curskillIdList) - LengthOfTable(upskillIdList)
    if openNewSkillCound == 1 then
        this.skillTiShi.text = GetLanguageStrById(11879)
    elseif  openNewSkillCound == 2 then
        this.skillTiShi.text = GetLanguageStrById(11879)
    end
    if curHeroData.heroConfig.Quality == 5 and curHeroData.heroConfig.Natural >= 13 then
        if curHeroData.star + 1 >= 5 and curHeroData.star + 1 < 15 then
            HeroManager.DetectionOpenFiveStarActivity(curHeroData.star + 1)
        end
    end

    --升星坦克图标
    local heroListGo={}
    if not heroListGo[1] then
        local go = newObject(this.heroPre)
        go:SetActive(true)
        go.name = "TankCardCurrent" 
        go.transform:SetParent(this.currentHero.transform)
        go.transform.localScale = Vector3.one * 1.2
        go.transform.localPosition = Vector3.zero
        go:GetComponent("EmptyRaycast").raycastTarget = false
        heroListGo[1] = go
    end
    this.SetOneCardData(heroListGo[1], curHeroData,-1)
    if not heroListGo[2] then
        local go = newObject(this.heroPre)
        go:SetActive(true)
        go.name = "TankCardNext" 
        go.transform:SetParent(this.nextHero.transform)
        go.transform.localScale = Vector3.one * 1.2
        go.transform.localPosition = Vector3.zero
        go:GetComponent("EmptyRaycast").raycastTarget = false
        heroListGo[2] = go
    end
    this.SetOneCardData(heroListGo[2], curHeroData,curHeroData.star+1)
    
    local oldSkillList=HeroManager.GetSkillIdsByHeroRulesRole(curHeroData.heroConfig.OpenSkillRules,curHeroData.star,curHeroData.breakId)
    local oldOpenPassiveSkillRules=HeroManager.GetPassiveSkillIdsByHeroRuleslock(curHeroData.heroConfig.OpenPassiveSkillRules,curHeroData.star,curHeroData.breakId)
    for key, value in pairs(oldOpenPassiveSkillRules) do
        table.insert(oldSkillList, value)
    end

    local nextSkillList=HeroManager.GetSkillIdsByHeroRulesRole(curHeroData.heroConfig.OpenSkillRules,curHeroData.star+1,curHeroData.breakId)
    local nextOpenPassiveSkillRules=HeroManager.GetPassiveSkillIdsByHeroRuleslock(curHeroData.heroConfig.OpenPassiveSkillRules,curHeroData.star+1,curHeroData.breakId)
    for key, value in pairs(nextOpenPassiveSkillRules) do
        table.insert(nextSkillList, value)
    end

    local newSkillList={}
    for index, value in ipairs(nextSkillList) do
        local isSame = false
        for oldInex, oldValue in ipairs(oldSkillList) do
            if value.skillId == oldValue.skillId then
                isSame = true
                break
            end
        end
        if not isSame then
           table.insert(newSkillList,value)
        end
    end

    for i = 1, #skillShowProList do
        skillShowProList[i]:SetActive(false)
    end

    for i = 1, #newSkillList do
        if newSkillList[i] then
            skillShowProList[i]:SetActive(true)
            Util.GetGameObject(skillShowProList[i].transform,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(newSkillList[i].skillConfig.Icon))
            Util.GetGameObject(skillShowProList[i].transform,"skillNameTx"):GetComponent("Text").text = GetLanguageStrById(newSkillList[i].skillConfig.Name)          
            if SkillLogicConfig[newSkillList[i].skillConfig.Id] ~= nil  then
                Util.GetGameObject(skillShowProList[i].transform,"Lv/LvTx"):GetComponent("Text").text = SkillLogicConfig[newSkillList[i].skillConfig.Id].Level               
            else
                Util.GetGameObject(skillShowProList[i].transform,"Lv/LvTx"):GetComponent("Text").text = PassiveSkillLogicConfig[newSkillList[i].skillConfig.Id].Level             
            end
        end
    end
end

function RoleUpStarSuccessPanel:GetEquipSkillData(skillId)
    return this.skillConfig[skillId]
end

--界面关闭时调用（用于子类重写）
function RoleUpStarSuccessPanel:OnClose()
    if callBack then
        callBack()
        callBack = nil
    end
end
function this.SetOneCardData(_go, _heroData,star)
    local go =_go
    local heroData =_heroData
    local frame = Util.GetGameObject(go,"frame"):GetComponent("Image")
    local icon = Util.GetGameObject(go, "icon"):GetComponent("Image")
    local lv = Util.GetGameObject(go, "lv/Text"):GetComponent("Text")
    local pro = Util.GetGameObject(go, "proIcon"):GetComponent("Image")
    local starGrid = Util.GetGameObject(go, "star")
    local choosedObj = Util.GetGameObject(go, "choosed")
    local hpExp = Util.GetGameObject(go, "hpExp")
    frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality,star==-1 and heroData.star or star))
    icon.sprite = Util.LoadSprite(heroData.icon)
    lv.text = heroData.lv
    pro.sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    SetHeroStars(starGrid,star ==-1 and heroData.star or star)
    --血量显示
    hpExp:SetActive(false)
    choosedObj:SetActive(false)
end
--界面销毁时调用（用于子类重写）
function RoleUpStarSuccessPanel:OnDestroy()

end

return RoleUpStarSuccessPanel