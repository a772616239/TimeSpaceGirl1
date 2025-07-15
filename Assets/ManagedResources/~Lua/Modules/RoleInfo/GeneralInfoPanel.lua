require("Base/BasePanel")
GeneralInfoPanel = Inherit(BasePanel)
local this = GeneralInfoPanel
local generalData = ConfigManager.GetConfig(ConfigName.GeneralConfig)
local itemData = ConfigManager.GetConfig(ConfigName.ItemConfig)
local heroData = ConfigManager.GetConfig(ConfigName.HeroConfig)
local backImage = "cn2-X1_icon_5xingyingxiongsuipian"
this.generalBtn = {}
this.lock = {}
this.generalID = nil
this.generalUpdata = nil
this.generalUpRank = nil
this.generalLockList = {}
this.select = 1

--初始化组件（用于子类重写）
function GeneralInfoPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.btnList = Util.GetGameObject(self.gameObject, "rolePanel/btnList")
    this.btnInfo = Util.GetGameObject(this.btnList, "btnInfo")
    this.btnAdvanced = Util.GetGameObject(this.btnList, "btnAdvanced")

    --解锁
    this.roleInfolockLayout = Util.GetGameObject(self.gameObject, "rolePanel/layout/roleInfolockLayout")
    this.unLockBtn = Util.GetGameObject(this.roleInfolockLayout, "unLockBtn")
    this.hero = Util.GetGameObject(this.roleInfolockLayout, "hero")
    this.generallocktext = Util.GetGameObject(this.roleInfolockLayout, "infoBg/infoRect/infoText"):GetComponent("Text")

    --升级
    this.roleInfoLayout = Util.GetGameObject(self.gameObject, "rolePanel/layout/roleInfoLayout")
    this.generaltext = Util.GetGameObject(this.roleInfoLayout, "infoBg/infoRect/infoText"):GetComponent("Text")
    this.upLvBtn = Util.GetGameObject(this.roleInfoLayout, "upLvBtn")
    this.expSlider = Util.GetGameObject(this.roleInfoLayout, "exp/Slider"):GetComponent("Slider")
    --升级属性
    this.atkPro = Util.GetGameObject(this.roleInfoLayout, "pro/atk/proValue"):GetComponent("Text")
    this.atkProChange = Util.GetGameObject(this.roleInfoLayout, "pro/atk/proValueChange"):GetComponent("Text")
    this.hpPro = Util.GetGameObject(this.roleInfoLayout, "pro/hp/proValue"):GetComponent("Text")
    this.hpProChange = Util.GetGameObject(this.roleInfoLayout, "pro/hp/proValueChange"):GetComponent("Text")
    this.LvPro = Util.GetGameObject(this.roleInfoLayout, "pro/lv/proValue"):GetComponent("Text")
    this.LvProMax = Util.GetGameObject(this.roleInfoLayout, "pro/lv/proValueMax"):GetComponent("Text")

    --进阶
    this.roleSkillLayout = Util.GetGameObject(self.gameObject, "rolePanel/layout/roleSkillLayout")
    this.upRankBtn = Util.GetGameObject(this.roleSkillLayout, "upRankBtn")--进阶
    this.upRankDataBtn = Util.GetGameObject(this.roleSkillLayout, "upRankDataBtn")--进阶预览
    --进阶属性
    this.upRankHpText = Util.GetGameObject(this.roleSkillLayout, "pro/hp/proValue"):GetComponent("Text")
    this.upRankHpChangeText = Util.GetGameObject(this.roleSkillLayout, "pro/hp/proValueChange"):GetComponent("Text")
    this.upRankAtkText = Util.GetGameObject(this.roleSkillLayout, "pro/atk/proValue"):GetComponent("Text")
    this.upRankAtkChangeText = Util.GetGameObject(this.roleSkillLayout, "pro/atk/proValueChange"):GetComponent("Text")
    this.upRankSpeedText = Util.GetGameObject(this.roleSkillLayout, "pro/speed/proValue"):GetComponent("Text")
    this.upRankSpeedChangeText = Util.GetGameObject(this.roleSkillLayout, "pro/speed/proValueChange"):GetComponent("Text")
    for i = 1, 5 do
        this.lock[i] = Util.GetGameObject(this.roleSkillLayout, "layout/item"..i.."/itemlock")
    end

    --属性
    this.pro = Util.GetGameObject(self.gameObject, "pro")
    this.generalLv = Util.GetGameObject(this.pro, "lv/proValue"):GetComponent("Text")
    this.atk = Util.GetGameObject(this.pro, "atk/proValue"):GetComponent("Text")
    this.hp = Util.GetGameObject(this.pro, "hp/proValue"):GetComponent("Text")
    this.speed = Util.GetGameObject(this.pro, "Speed/proValue"):GetComponent("Text")
    this.maxHp = Util.GetGameObject(this.pro, "PhyDef/proValue"):GetComponent("Text")
    this.ackPer = Util.GetGameObject(this.pro, "ActPef/proValue"):GetComponent("Text")

    this.generalName = Util.GetGameObject(self.gameObject, "rolePanel/info/nameAndPossLayout/heroName"):GetComponent("Text")
    this.generalPro = Util.GetGameObject(self.gameObject, "rolePanel/info/nameAndPossLayout/proImage"):GetComponent("Image")

    --帮助
    this.HelpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    --属性tab
    for i = 1, 5 do
        this.generalBtn[i] = Util.GetGameObject(self.gameObject, "btns/btn"..i)
    end
    
    this.btnSelects = {}
    for i = 1, 5 do
    this.btnSelects[i] = Util.GetGameObject(self.gameObject, "btns/btnSelect/btn"..i)
    end
    this.beams1 = {}
    for i = 1, 5 do
    this.beams1[i] = Util.GetGameObject(self.gameObject, "bg/beams1/beam"..i)
    end
    this.beams2 = {}
    for i = 1, 5 do
    this.beams2[i] = Util.GetGameObject(self.gameObject, "bg/beams2/beam"..i)
    end

    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
end

--绑定事件（用于子类重写）
function GeneralInfoPanel:BindEvent()
    Util.AddClick(this.btnInfo, function()
        this.select = 1
        this.SelectLayout(this.select)
    end)
    Util.AddClick(this.btnAdvanced, function()
        this.select = 2
        this.SelectLayout(this.select)
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    for i = 1, 5 do
        Util.AddClick(this.generalBtn[i], function()
            this.generalID = i
            this.SelectLayout(1)
            this.roleInfolockLayout:SetActive(false)
            this.SetUpdata()
        end)
    end
    Util.AddClick(this.unLockBtn, function()
        if GeneralManager.GetAllLock(this.generalID) then
            local generalDatelistNet = {}
            for key, value in pairs(this.generalLockList[this.generalID]) do
                table.insert(generalDatelistNet,value.dynamicId)
            end
            NetManager.GetGeneralActiveData(this.generalID,generalDatelistNet,function (data,itemdata)
                HeroManager.DeleteHeroDatas(generalDatelistNet)
                this.roleInfoLayout:SetActive(true)
                this.roleSkillLayout:SetActive(false)
                this.roleInfolockLayout:SetActive(false)
                this.SetUpdata()
                if itemdata.drop then
                    UIManager.OpenPanel(UIName.RewardItemPopup,itemdata.drop,1,function() end)
                end
            end)
        end
    end)
    Util.AddClick(this.upLvBtn, function()
        if GeneralManager.IsCanUpLevel(this.generalID) then
            local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            local config = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralLevelConfig, "GeneralId", this.generalID, "Lev", GeneralManager.GetAllGeneralDatas(this.generalID).level)
            if config and config.TotalExp == 0 then
                -- max
                PopupTipPanel.ShowTipByLanguageId(11961)
                return
            end
            NetManager.GetGeneralLevelUpRequest(this.generalID,function ()
                this.SetUpdata()
                FormationManager.FlutterPower(oldPower)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10073)
        end
    end)
    Util.AddClick(this.upRankBtn, function()
        if GeneralManager.IsCanAdvanced(this.generalID) then
            local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            NetManager.GetGeneralRankUpRequest(this.generalID,function ()
                this.SetUpdata()
                FormationManager.FlutterPower(oldPower)
            end)
        else
            local general = GeneralManager.GetAllGeneralDatas(this.generalID)
            local generalRankUpOld = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralStepConfig,"GeneralId",this.generalID,"StepLev",general.rankUpLevel+1)
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12737),generalRankUpOld.GeneralLev))
        end
    end)
    Util.AddClick(this.upRankDataBtn,function ()
        UIManager.OpenPanel(UIName.GenerlProInfoPopup,this.generalID)
    end)

    Util.AddClick(this.hero, function()
        local general = generalData[this.generalID]
        local heroData = {property = general.LockHero[3]}
        local upStarHeroListData = HeroManager.GetUpStarHeroListData(23,heroData)
        this.generalLockList[this.generalID] = {}
        local RankupData = {}
        RankupData[4] = generalData[this.generalID].LockHero[2]
        UIManager.OpenPanel(UIName.RoleUpStarListPanel, upStarHeroListData.heroList, nil, RankupData, this, this.generalLockList[this.generalID], nil, true, HeroElementDef[this.generalID])
    end)
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.GeneralInfo,this.helpPosition.x,this.helpPosition.y - 11) 
    end)
end
--添加事件监听（用于子类重写）
function GeneralInfoPanel:AddListener()
end

--移除事件监听（用于子类重写）
function GeneralInfoPanel:RemoveListener()
end

local viewType = {
    {14, 17002, 17012, 17011},
    {14, 17003, 17012, 17011},
    {14, 17001, 17012, 17011},
    {14, 17004, 17012, 17011},
    {14, 17005, 17012, 17011},
    {14, 17006, 17012, 17011}
}
--界面打开时调用（用于子类重写）
function GeneralInfoPanel:OnOpen()
    this.generalID = 1
    this.select = 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GeneralInfoPanel:OnShow()
    this.SelectLayout(this.select)
    this.SetUpdata()
end

--界面关闭时调用（用于子类重写）
function GeneralInfoPanel:OnClose()
    CheckRedPointStatus(RedPointType.General)
end

--界面销毁时调用（ 用于子类重写）
function GeneralInfoPanel:OnDestroy()
end

function this.SelectLayout(index)
    this.select = index
    this.roleInfoLayout:SetActive(index == 1)
    Util.GetGameObject(this.btnInfo, "selectBtn"):SetActive(index == 1)
    this.roleSkillLayout:SetActive(index == 2)
    Util.GetGameObject(this.btnAdvanced, "selectBtn"):SetActive(index == 2)
end

function this.SetUpdata()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = viewType[this.generalID]})
    this.generalLockList[this.generalID] = {}

    Util.GetGameObject(this.hero,"icon"):GetComponent("Image").sprite = Util.LoadSprite(backImage)
    for i = 1, 5 do
        this.lock[i].gameObject:SetActive(false)

        local state = false
        if GeneralManager.GetAllLock(i) then
            state = GeneralManager.IsCanUnlock(i) or GeneralManager.IsCanUpLevel(i) or GeneralManager.IsCanAdvanced(i)
        end
        Util.GetGameObject(this.generalBtn[i],"redpoint"):SetActive(state)
        Util.GetGameObject(this.btnSelects[i],"redpoint"):SetActive(state)

        this.beams1[i]:SetActive(i ~= this.generalID)
        this.beams2[i]:SetActive(i == this.generalID)
        this.generalBtn[i]:SetActive(i ~= this.generalID)
        this.btnSelects[i]:SetActive(i == this.generalID)
    end

    Util.GetGameObject(this.upLvBtn, "redPoint"):SetActive(GeneralManager.IsCanUpLevel(this.generalID))
    Util.GetGameObject(this.btnInfo, "redPoint"):SetActive(GeneralManager.IsCanUpLevel(this.generalID))
    Util.GetGameObject(this.upRankBtn, "redPoint"):SetActive(GeneralManager.IsCanAdvanced(this.generalID))
    Util.GetGameObject(this.btnAdvanced, "redPoint"):SetActive(GeneralManager.IsCanAdvanced(this.generalID))

    this.general = GeneralManager.GetAllGeneralDatas(this.generalID)
    this.SetInfo()

    if this.general == nil then
        this.roleInfolockLayout:SetActive(true)
        this.roleInfoLayout:SetActive(false)
        this.roleSkillLayout:SetActive(false)
    else
        this.generalUpdata = GeneralManager.UpgradeExpend(this.generalID, this.general.level).UpgradeExpend
        this.generalUpRank = GeneralManager.RankInfo(this.generalID, this.general.rankUpLevel)

        this.UpdateUpLevel()
        this.UnpdateUpClass()
    end
end

--基础信息
function this.SetInfo()
    this.generalName.text = GetLanguageStrById(generalData[this.generalID].Name)
    this.generalPro.sprite = this.generalBtn[this.generalID]:GetComponent("Image").sprite
    this.generaltext.text = GetLanguageStrById(generalData[this.generalID].Desc)
    if this.general == nil then
        for i = 1, 6 do
            Util.GetGameObject(this.pro.transform:GetChild(i-1).gameObject, "proValue"):GetComponent("Text").text = 0
        end
        this.generallocktext.text = GetLanguageStrById(generalData[this.generalID].LockDesc)
        this.UpdateUpStarPosHeroData(this.generalLockList[this.generalID])
    else
        this.generalLv.text = this.general.level
        this.atk.text = GeneralManager.GeneralAttLevel(this.generalID, this.general.level,1)
        this.hp.text = GeneralManager.GeneralAttLevel(this.generalID, this.general.level,2)
        this.speed.text = GeneralManager.GeneralOtherAtt(this.generalID,5)
        this.maxHp.text = GeneralManager.GeneralOtherAtt(this.generalID,62) .. "%"
        this.ackPer.text = GeneralManager.GeneralOtherAtt(this.generalID,61) .. "%"
    end

    this.btnList:SetActive(this.general ~= nil)
    this.roleInfolockLayout:SetActive(this.general == nil)
    this.roleInfoLayout:SetActive(this.select == 1 and this.general ~= nil)
    this.roleSkillLayout:SetActive(this.select == 2 and this.general ~= nil)
end

--升级
function this.UpdateUpLevel()
    Util.GetGameObject(this.roleInfoLayout,"upLv"):SetActive(this.general.level < GeneralManager.MaxLevel(this.generalID))
    this.atkPro.text = GeneralManager.GeneralAttLevel(this.generalID, this.general.level,1)
    this.hpPro.text = GeneralManager.GeneralAttLevel(this.generalID, this.general.level,2)
    if this.general.level >= GeneralManager.MaxLevel(this.generalID) then--满级
        this.hpProChange.text = GetLanguageStrById(11960)
        this.atkProChange.text = GetLanguageStrById(11960)
        this.upLvBtn:SetActive(false)
        this.expSlider.value = 1
    else
        this.UpItemData(this.roleInfoLayout, this.generalUpdata)
        this.upLvBtn:SetActive(true)
        this.atkProChange.text = GeneralManager.GeneralLevel(this.generalID,this.general.level + 1,1)
        this.hpProChange.text = GeneralManager.GeneralLevel(this.generalID,this.general.level + 1,2)
        local generalLvData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralLevelConfig,"GeneralId", this.generalID,"Lev", this.general.level)
        this.expSlider.value = this.general.exp/generalLvData.TotalExp
    end

    this.LvPro.text = this.general.level
    this.LvProMax.text = "/"..GeneralManager.MaxLevel(this.generalID)
end

--进阶
function this.UnpdateUpClass()
    local SetProTextShow = function (id, text1, text2)
        local str, upStr = "", ""
        if GeneralManager.GeneralOtherRankAtt(this.generalID, id, this.general.rankUpLevel) ~= 0 then
            str = GeneralManager.GeneralOtherAtt(this.generalID, id)
            upStr = tostring(GeneralManager.GeneralOtherRankAtt(this.generalID, id, this.general.rankUpLevel) + str)
        else
            str = GeneralManager.GeneralOtherAtt(this.generalID, id)
            upStr = str
        end
        if id ~= 5 then
            str = str .. "%"
            upStr = upStr .. "%"
        end
        text1.text = str
        text2.text = upStr
    end

    SetProTextShow(62, this.upRankHpText, this.upRankHpChangeText)
    SetProTextShow(61, this.upRankAtkText, this.upRankAtkChangeText)
    SetProTextShow(5, this.upRankSpeedText, this.upRankSpeedChangeText)
    this.upRankBtn:SetActive(this.general.rankUpLevel ~= 50)
    Util.GetGameObject(this.roleSkillLayout,"upLv"):SetActive(this.general.rankUpLevel ~= 50)

    local locknum = math.fmod(this.general.rankUpLevel, 5)
    if this.general.rankUpLevel == 50 then--满级
        locknum = 5
        this.upRankHpChangeText.text = GetLanguageStrById(11960)
        this.upRankAtkChangeText.text = GetLanguageStrById(11960)
        this.upRankSpeedChangeText.text = GetLanguageStrById(11960)
    else
        this.UpItemData(this.roleSkillLayout, this.generalUpRank)
    end
    for i = 1, locknum do
        this.lock[i].gameObject:SetActive(true)
    end
end

-- 刷新道具
function this.UpItemData(go, data)
    local SetItemTextShow = function (_id1, _id2, _text)
        local str = ""
        local num = BagManager.GetItemCountById(_id1)
        if num < _id2 then
            str = "<color=#FF0000FF>%s</color>"
        else 
            str = "<color=#FFFFFFFF>%s</color>"
        end
        _text.text = string.format(str,PrintWanNum3(num) .. "/" .. PrintWanNum3(_id2))
    end
    for i = 1, 2 do
        local item = itemData[data[i][1]]
        local frame = Util.GetGameObject(go, "upLv/item"..i):GetComponent("Image")
        local icon = Util.GetGameObject(go, "upLv/item"..i.."/icon"):GetComponent("Image")
        local num = Util.GetGameObject(go, "upLv/item"..i.."/Text"):GetComponent("Text")
        frame.sprite = Util.LoadSprite(GetQuantityImageByquality(item.Quantity))
        icon.sprite = Util.LoadSprite(GetResourcePath(item.ResourceID))
        SetItemTextShow(data[i][1], data[i][2], num)

        Util.AddOnceClick(icon.gameObject,function ()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,data[i][1])
        end)
    end
end

-- 解锁
function this.UpdateUpStarPosHeroData(curSelectHeroList)
    local Length = LengthOfTable(curSelectHeroList)
    this.generalLockList[this.generalID] = curSelectHeroList
    local num = Util.GetGameObject(this.hero,"num"):GetComponent("Text")
    local str = ""
    if LengthOfTable(this.generalLockList[this.generalID]) < generalData[this.generalID].LockHero[2] then
        str = "<color=#FF0000FF>%s/%s</color>"
    else
        str = "<color=#FFFFFFFF>%s/%s</color>"
    end
    num.text = string.format(str, Length, generalData[this.generalID].LockHero[2])
    local icon = Util.GetGameObject(this.hero,"icon"):GetComponent("Image")
    if LengthOfTable(this.generalLockList[this.generalID]) > 0 then
        local heroIconData = nil
        for key, value in pairs(curSelectHeroList) do
            heroIconData = heroData[value.heroBackData.heroId]
        end
        icon.sprite = Util.LoadSprite(GetResourcePath(heroIconData.Icon))
    else
        icon.sprite = Util.LoadSprite(backImage)
    end
end

return GeneralInfoPanel