require("Base/BasePanel")
RoleRankUpConfirmPopup = Inherit(BasePanel)
local this = RoleRankUpConfirmPopup
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local PassiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)

--初始化组件（用于子类重写）
function RoleRankUpConfirmPopup:InitComponent()
    this.btnBack = Util.GetGameObject(this.transform,"btnBack")
    this.rankUpBtn = Util.GetGameObject(this.transform,"BG/RankUpBtn")
    this.LvMax1 = Util.GetGameObject(this.transform,"BG/ProChange/LvMax/value1")
    this.LvMax2 = Util.GetGameObject(this.transform,"BG/ProChange/LvMax/value2")
    this.hpValue1 = Util.GetGameObject(this.transform,"BG/ProChange/Hp/value1")
    this.hpValue2 = Util.GetGameObject(this.transform,"BG/ProChange/Hp/value2")
    this.atkValue1 = Util.GetGameObject(this.transform,"BG/ProChange/Atk/value1")
    this.atkValue2 = Util.GetGameObject(this.transform,"BG/ProChange/Atk/value2")
    this.defValue1 = Util.GetGameObject(this.transform,"BG/ProChange/Def/value1")
    this.defValue2 = Util.GetGameObject(this.transform,"BG/ProChange/Def/value2")
    this.spdValue1 = Util.GetGameObject(this.transform,"BG/ProChange/Spd/value1")
    this.spdValue2 = Util.GetGameObject(this.transform,"BG/ProChange/Spd/value2")
    this.gold = Util.GetGameObject(this.transform,"BG/Cost/cost1/value"):GetComponent("Text")
    this.updata = Util.GetGameObject(this.transform,"BG/Cost/cost2/value"):GetComponent("Text")
    this.skill = Util.GetGameObject(this.transform,"BG/OpenSkill/skill")
    this.NoSkill = Util.GetGameObject(this.transform,"BG/OpenSkill/NoSkill")

    this.frame = Util.GetGameObject(this.transform,"BG/frame")
    this.icon = Util.GetGameObject(this.transform,"BG/frame/icon")
end

--绑定事件（用于子类重写）
function RoleRankUpConfirmPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RoleRankUpConfirmPopup:AddListener()
end

--移除事件监听（用于子类重写）
function RoleRankUpConfirmPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function RoleRankUpConfirmPopup:OnOpen(...)
    local args = {...}
    local curHeroData = args[1]
    local nextHeroBreak = args[2]
    local curHeroRankUpConfigOpenLevel = args[3]
    local costItemList = args[4]
    local fuc = args[5]
    this.skill:SetActive(false)
    this.NoSkill:SetActive(true)
    local allAddProVal = HeroManager.CalculateHeroAllProValList(1,curHeroData.dynamicId,false)
    local curLvAllAddProVal = HeroManager.CalculateHeroAllProValList(2,curHeroData.dynamicId,false,nextHeroBreak.Id,curHeroData.upStarId)
    local oldSkillList = HeroManager.GetSkillIdsByHeroRules(curHeroData.heroConfig.OpenSkillRules,curHeroData.star,curHeroData.breakId)

    local newSkillList = HeroManager.GetSkillIdsByHeroRules(curHeroData.heroConfig.OpenSkillRules,curHeroData.star,curHeroData.breakId+1)

    local oldOpenPassiveSkillRules = HeroManager.GetPassiveSkillIdsByHeroRules(curHeroData.heroConfig.OpenPassiveSkillRules,curHeroData.star,curHeroData.breakId)
    local newOpenPassiveSkillRules = HeroManager.GetPassiveSkillIdsByHeroRules(curHeroData.heroConfig.OpenPassiveSkillRules,curHeroData.star,curHeroData.breakId+1)
    this.LvMax1:GetComponent("Text").text = curHeroData.lv
    this.LvMax2:GetComponent("Text").text = curHeroRankUpConfigOpenLevel
    this.atkValue1:GetComponent("Text").text = allAddProVal[HeroProType.Attack]
    this.atkValue2:GetComponent("Text").text = curLvAllAddProVal[HeroProType.Attack]

    this.defValue1:GetComponent("Text").text = allAddProVal[HeroProType.PhysicalDefence]
    this.defValue2:GetComponent("Text").text = curLvAllAddProVal[HeroProType.PhysicalDefence]
    this.hpValue1:GetComponent("Text").text = allAddProVal[HeroProType.Hp]
    this.hpValue2:GetComponent("Text").text = curLvAllAddProVal[HeroProType.Hp]
    this.spdValue1:GetComponent("Text").text = allAddProVal[HeroProType.Speed]
    this.spdValue2:GetComponent("Text").text = curLvAllAddProVal[HeroProType.Speed]

    this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(nil,curHeroData.star))
    this.icon:GetComponent("Image").sprite = Util.LoadSprite(curHeroData.icon)
    for i = 1, #costItemList do
        if costItemList[i][1] ~= 14 then
            if BagManager.GetItemCountById(costItemList[i][1]) < costItemList[i][2] then
                this.updata.text = string.format("<color=#FF0000FF>%s/%s</color>",PrintWanNum2(BagManager.GetItemCountById(costItemList[i][1])),PrintWanNum2(costItemList[i][2]))
            else
                this.updata.text = string.format("<color=#FFFFFFFF>%s/%s</color>",PrintWanNum2(BagManager.GetItemCountById(costItemList[i][1])),PrintWanNum2(costItemList[i][2]))
            end
        else
            if BagManager.GetItemCountById(costItemList[i][1]) < costItemList[i][2] then
                this.gold.text = string.format("<color=#FF0000FF>%s</color>",costItemList[i][2])
            else
                this.gold.text = string.format("<color=#FFFFFFFF>%s</color>",costItemList[i][2])
            end
        end
    end
    for i = 1, #newSkillList do
        if oldSkillList[i] ~= nil then

        else
            this.skill:SetActive(true)
            this.NoSkill:SetActive(false)
            Util.GetGameObject(this.skill,"Icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(newSkillList[i].skillConfig.Icon))
            Util.GetGameObject(this.skill,"name"):GetComponent("Text").text = GetLanguageStrById(newSkillList[i].skillConfig.Name)
            
            Util.AddOnceClick(Util.GetGameObject(this.skill,"frame"), function()
                local lv
            if SkillLogicConfig[newSkillList[i].skillConfig.Id] ~= nil  then
                lv = SkillLogicConfig[newSkillList[i].skillConfig.Id].Level
            else
                lv = PassiveSkillLogicConfig[newSkillList[i].skillConfig.Id].Level
            end
            local skillLogicConfig_
            local isPassive
            local skillPos
            if skillLogicConfig_ == nil then
                skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.SkillLogicConfig,"Id",newSkillList[i].skillConfig.Id)
                isPassive = false
            end
            if skillLogicConfig_ == nil then
                skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.PassiveSkillLogicConfig,"Id",newSkillList[i].skillConfig.Id)
                isPassive = true
            end
           
            if isPassive then
                for j = 1, #curHeroData.heroConfig.OpenPassiveSkillRules do
                    if curHeroData.heroConfig.OpenPassiveSkillRules[j][2] == skillLogicConfig_.Group then
                        skillPos = curHeroData.heroConfig.OpenPassiveSkillRules[j][1]
                        break
                    end
                end
            else
                for j = 1, #curHeroData.heroConfig.OpenSkillRules do
                    if curHeroData.heroConfig.OpenSkillRules[j][2] == skillLogicConfig_.Group then
                        skillPos = curHeroData.heroConfig.OpenSkillRules[j][1]
                        break
                    end
                end
            end
                local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id,skillPos)
                local panel = UIManager.OpenPanel(UIName.SkillInfoPopup,newSkillList[i],1,10,maxLv,i,lv)
            end)
        end
    end
    for i = 1, #newOpenPassiveSkillRules do
        if oldOpenPassiveSkillRules[i] ~= nil then

        else
            this.skill:SetActive(true)
            this.NoSkill:SetActive(false)
            Util.GetGameObject(this.skill,"Icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(newOpenPassiveSkillRules[i].skillConfig.Icon))
            Util.GetGameObject(this.skill,"name"):GetComponent("Text").text = GetLanguageStrById(newOpenPassiveSkillRules[i].skillConfig.Name)
            Util.AddOnceClick(Util.GetGameObject(this.skill,"frame"), function()
                local lv
            if SkillLogicConfig[newOpenPassiveSkillRules[i].skillConfig.Id] ~= nil  then
                lv = SkillLogicConfig[newOpenPassiveSkillRules[i].skillConfig.Id].Level
            else
                lv = PassiveSkillLogicConfig[newOpenPassiveSkillRules[i].skillConfig.Id].Level
            end
            local skillLogicConfig_
            local isPassive
            local skillPos
            if skillLogicConfig_ == nil then
                skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.SkillLogicConfig,"Id",newOpenPassiveSkillRules[i].skillConfig.Id)
                isPassive = false
            end
            if skillLogicConfig_ == nil then
                skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.PassiveSkillLogicConfig,"Id",newOpenPassiveSkillRules[i].skillConfig.Id)
                isPassive = true
            end
           
            if isPassive then
                for j = 1, #curHeroData.heroConfig.OpenPassiveSkillRules do
                    if curHeroData.heroConfig.OpenPassiveSkillRules[j][2] == skillLogicConfig_.Group then
                        skillPos = curHeroData.heroConfig.OpenPassiveSkillRules[j][1]
                        break
                    end
                end
            else
                for j = 1, #curHeroData.heroConfig.OpenSkillRules do
                    if curHeroData.heroConfig.OpenSkillRules[j][2] == skillLogicConfig_.Group then
                        skillPos = curHeroData.heroConfig.OpenSkillRules[j][1]
                        break
                    end
                end
            end
                local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id,skillPos)
                local panel = UIManager.OpenPanel(UIName.SkillInfoPopup,newOpenPassiveSkillRules[i],1,10,maxLv,i,lv)
            end)
        end
    end
    Util.AddOnceClick(this.rankUpBtn, function()
        fuc()
        this:ClosePanel()
    end)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RoleRankUpConfirmPopup:OnShow()
    
end

--界面关闭时调用（用于子类重写）
function RoleRankUpConfirmPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function RoleRankUpConfirmPopup:OnDestroy()

end

return RoleRankUpConfirmPopup