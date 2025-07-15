require("Base/BasePanel")
MapRoleInfoPopup = Inherit(BasePanel)
local this = MapRoleInfoPopup
--初始化组件（用于子类重写）
function MapRoleInfoPopup:InitComponent()

    self.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.heroName = Util.GetGameObject(self.transform, "RoleName"):GetComponent("Text")
    this.pos = Util.GetGameObject(self.transform, "PropImg2"):GetComponent("Image")
    this.pro = Util.GetGameObject(self.transform, "PropImg1"):GetComponent("Image")
    this.lv = Util.GetGameObject(self.transform, "RoleLevel"):GetComponent("Text")
    this.starPre = Util.GetGameObject(self.transform, "StarPre")
    this.starGrid= Util.GetGameObject(self.transform, "StarsRoot")

    this.atk = Util.GetGameObject(self.transform, "RoleInfo/pro/atk/proValue"):GetComponent("Text")
    this.hp = Util.GetGameObject(self.transform, "RoleInfo/pro/hp/proValue"):GetComponent("Text")
    this.phyDef = Util.GetGameObject(self.transform, "RoleInfo/pro/phyDef/proValue"):GetComponent("Text")
    this.magDef = Util.GetGameObject(self.transform, "RoleInfo/pro/magDef/proValue"):GetComponent("Text")
    this.speed = Util.GetGameObject(self.transform, "RoleInfo/pro/speed/proValue"):GetComponent("Text")
    this.skillGrid=Util.GetGameObject(self.transform, "RoleInfo/skill")
    this.power=Util.GetGameObject(self.transform, "RoleInfo/powerNum"):GetComponent("Text")
    --this.xingDongExp=Util.GetGameObject(self.transform, "xingDongExp/expCurNum"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function MapRoleInfoPopup:BindEvent()

    Util.AddClick(self.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MapRoleInfoPopup:AddListener()

end

--移除事件监听（用于子类重写）
function MapRoleInfoPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MapRoleInfoPopup:OnOpen(...)

    local arg = { ... }
    local curHeroData = arg[1]
    local allPropValue = arg[2]
    --this.profession.sprite = Util.LoadSprite(GetResourcePath(curHeroData.ProfessionResourceId))
    -- 角色属性图标
    this.pos.sprite = Util.LoadSprite(curHeroData.professionIcon)
    this.pro.sprite = Util.LoadSprite(GetProStrImageByProNum(curHeroData.heroConfig.PropertyName))
    this.lv.text =string.format(GetLanguageStrById(11571),curHeroData.lv)
    this.heroName.text = curHeroData.name

    SetHeroStars(this.starGrid, curHeroData.star)

    --计算面板属性
    --this.xingDongExp.text = curHeroData.actionPower
    --local allAddProVal=HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId)
    --this.atk.text=allAddProVal[HeroProType.Attack]
    --this.hp.text=allAddProVal[HeroProType.Hp]
    --this.phyDef.text=allAddProVal[HeroProType.PhysicalDefence]
    --this.magDef.text=allAddProVal[HeroProType.MagicDefence]
    --this.speed.text= allAddProVal[HeroProType.Speed]
    --计算战斗力   生命*0.7+（护甲+魔抗）*5+攻击*10+（暴击率+命中效果+效果抵抗率）*5+（属性攻击率+属性防御率）*30
    --this.power.text ="战斗力："..allAddProVal[HeroProType.WarPower]
    --显示队伍的属性数据
    local allAddProVal=HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId,false)
    --计算战斗力   生命*0.7+（护甲+魔抗）*5+攻击*10+（暴击率+命中效果+效果抵抗率）*5+（属性攻击率+属性防御率）*30
    this.power.text =GetLanguageStrById(10105)..allAddProVal[HeroProType.WarPower]

    -- 计算属性
    local propList = FoodBuffManager.CalBuffPropValue(allPropValue)
    this.atk.text = propList[4]
    this.hp.text = propList[2]
    this.phyDef.text = propList[5]
    this.magDef.text = propList[6]
    this.speed.text = propList[7]

    --技能
   local allSkillDatas = HeroManager.GetCurHeroSidAndCurStarAllSkillDatas(curHeroData.id,curHeroData.star)
    for i = 1, this.skillGrid.transform.childCount do
        local go= this.skillGrid.transform:GetChild(i-1).gameObject
        if #allSkillDatas>=i then
            if  allSkillDatas[i] and allSkillDatas[i].skillConfig and  allSkillDatas[i].skillConfig.Name then
                go:SetActive(true)
                go.transform:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(allSkillDatas[i].skillConfig.Icon))
                Util.GetGameObject(go.transform,"Text"):GetComponent("Text").text="lv."..(allSkillDatas[i].skillId % 10)
            else
                go:SetActive(false)
            end
            local skillLogicConfig_
            local isPassive
            local skillPos
            if skillLogicConfig_==nil then
                skillLogicConfig_=ConfigManager.TryGetConfigDataByKey(ConfigName.SkillLogicConfig,"Id",allSkillDatas[i].skillConfig.Id)
                isPassive=false
            end
            if skillLogicConfig_==nil then
                skillLogicConfig_=ConfigManager.TryGetConfigDataByKey(ConfigName.PassiveSkillLogicConfig,"Id",allSkillDatas[i].skillConfig.Id)
                isPassive=true
            end
           
            if isPassive then
                for j=1, #curHeroData.heroConfig.OpenPassiveSkillRules do
                    if curHeroData.heroConfig.OpenPassiveSkillRules[j][2]==skillLogicConfig_.Group then
                        skillPos=curHeroData.heroConfig.OpenPassiveSkillRules[j][1]
                        break
                    end
                end
            else
                for j=1, #curHeroData.heroConfig.OpenSkillRules do
                    if curHeroData.heroConfig.OpenSkillRules[j][2]==skillLogicConfig_.Group then
                        skillPos=curHeroData.heroConfig.OpenSkillRules[j][1]
                        break
                    end
                end
            end
            Util.AddClick(go, function()
                local maxLv= HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id, skillPos)
                UIManager.OpenPanel(UIName.SkillInfoPopup,allSkillDatas[i],2,10,maxLv,i)
            end)
        else
            go:SetActive(false)
        end
    end
end
--界面关闭时调用（用于子类重写）
function MapRoleInfoPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function MapRoleInfoPopup:OnDestroy()

end

return MapRoleInfoPopup