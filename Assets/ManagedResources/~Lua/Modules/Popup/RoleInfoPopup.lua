--- 猎妖师详情弹窗（滚动条版本） ---
require("Base/BasePanel")
RoleInfoPopup = Inherit(BasePanel)
local this = RoleInfoPopup
local curHeroData
local triggerCallBack
local allSkillDatas = {}
local soulPrintPreList={}--魂印预设容器
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local heroRankupConfig=ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
local jewelConfig=ConfigManager.GetConfig(ConfigName.JewelConfig)
local SkillLogicConfig=ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local PassiveSkillLogicConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local WarWaySkillConfig=ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
local ArtResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

local choosedList
local pinjieImage={"N1_icon_tankxunzhang_weijihuo","N1_icon_tankxunzhang_jihuo"} --该死的品阶图片 1是未激活 2是激活 --m5
local SpriteName = "cn2-X1_zhushen_dengji_0"
local orginLayer2 = 0
local orginLayer = 0
--初始化组件（用于子类重写）
function RoleInfoPopup:InitComponent()

    this.BackMask = Util.GetGameObject(self.transform, "BackMask")
    this.content = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content"):GetComponent("RectTransform")
    --this.backBtn = Util.GetGameObject(self.transform, "Panel/BackBtn")

    this.roleInfo0 = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content/RoleInfo0")
    this.head = Util.GetGameObject(this.roleInfo0, "Head")
    this.head_Frame = Util.GetGameObject(this.roleInfo0, "Frame"):GetComponent("Image")
    this.head_Icon = Util.GetGameObject(this.head, "Icon"):GetComponent("Image")
    this.head_Pro=Util.GetGameObject(this.head,"Pro"):GetComponent("Image")
    this.head_Lv = Util.GetGameObject(this.head, "Lv/Text"):GetComponent("Text")
    this.head_Star = Util.GetGameObject(this.head, "Star")
    this.roleName = Util.GetGameObject(this.roleInfo0, "RoleName"):GetComponent("Text")
    this.power = Util.GetGameObject(this.roleInfo0, "Power/PowerValue"):GetComponent("Text")
    this.radar = Util.GetGameObject(this.roleInfo0, "ProRadarImage/Radar"):GetComponent("RadarChart")
    this.talentBtn=Util.GetGameObject(this.roleInfo0,"Other/TalentBtn")
    this.talentProgress=Util.GetGameObject(this.roleInfo0,"Other/TalentBtn/Progress"):GetComponent("Text")
    this.talismanBtn=Util.GetGameObject(this.roleInfo0,"Other/TalismanBtn")
    this.talismanIcon = Util.GetGameObject(this.roleInfo0, "Other/TalismanBtn/Icon")
    this.talismanLock = Util.GetGameObject(this.roleInfo0, "Other/TalismanBtn/lockImage")
    this.talismanlv=Util.GetGameObject(this.roleInfo0,"Other/TalismanBtn/LvText")
    this.talismanlvText = Util.GetGameObject(this.roleInfo0, "Other/TalismanBtn/LvText/Text"):GetComponent("Text")
    --品阶
    this.pinjieRoot=Util.GetGameObject(this.roleInfo0,"Pinjie")
    this.pinjieList=
    {
        Util.GetGameObject(this.roleInfo0,"Pre1"),
        Util.GetGameObject(this.roleInfo0,"Pre2"),
        Util.GetGameObject(this.roleInfo0,"Pre3"),
        Util.GetGameObject(this.roleInfo0,"Pre4"),
        Util.GetGameObject(this.roleInfo0,"Pre5"),
        Util.GetGameObject(this.roleInfo0,"Pre6"),
    }

    this.roleInfo1 = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content/RoleInfo1")
    this.atk = Util.GetGameObject(this.roleInfo1, "Pro/Atk/ProValue"):GetComponent("Text")
    this.hp = Util.GetGameObject(this.roleInfo1, "Pro/Hp/ProValue"):GetComponent("Text")
    this.phyDef = Util.GetGameObject(this.roleInfo1, "Pro/PhyDef/ProValue"):GetComponent("Text")
    this.speed = Util.GetGameObject(this.roleInfo1, "Pro/Speed/ProValue"):GetComponent("Text")
    this.magDef = Util.GetGameObject(this.roleInfo1, "Pro/MagDef/ProValue"):GetComponent("Text")
    this.posBgImage=Util.GetGameObject(this.roleInfo1,"Pos"):GetComponent("Image")
    this.posImage=Util.GetGameObject(this.roleInfo1,"Pos/PosImage"):GetComponent("Image")
    this.posText=Util.GetGameObject(this.roleInfo1,"Pos/PosText"):GetComponent("Text")
    this.proBtn=Util.GetGameObject(this.roleInfo1,"ProTitle/Btn")--基础属性
    
    --技能
    this.skillInfo = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content/SkillInfo")
    this.skillGrid = Util.GetGameObject(this.skillInfo, "Skill")
    this.skill1 = Util.GetGameObject(this.skillGrid, "Skill1")
    this.skill2 = Util.GetGameObject(this.skillGrid, "Skill2")
    this.skill3 = Util.GetGameObject(this.skillGrid, "Skill3")
    this.skill4 = Util.GetGameObject(this.skillGrid, "Skill4")
    this.selsectSkillImage = Util.GetGameObject(this.skillGrid, "SelsectSkillImage")

    --战法
    this.warWayInfo = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content/WarWayInfo")
    this.warWayContent = Util.GetGameObject(this.warWayInfo, "Content")
    this.warWayItem1 = Util.GetGameObject(this.warWayContent, "item1")
    this.warWayItem2 = Util.GetGameObject(this.warWayContent, "item2")

    --装备
    this.equipInfo = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content/EquipInfo")
    this.equipTitle=Util.GetGameObject(this.equipInfo,"BG/EquipTitle")
    this.babyTitle=Util.GetGameObject(this.equipInfo,"BG/BabyTitle")
    this.equipContent=Util.GetGameObject(this.equipInfo, "Content")

    --> 方案
    this.CombatPlanInfoGo = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content/CombatPlanInfo")

    --勋章
    this.medalInfo = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content/MedalInfo")

    --> 特性
    this.TalentInfoGo = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content/TalentInfo")

    -- this.selsectEquipImage = Util.GetGameObject(this.equipInfo, "SelsectEquipImage")
    --宝物
    -- this.babyGrid=Util.GetGameObject(this.grid, "BabyGrid")

    --魂印
    -- this.soulPrintInfo = Util.GetGameObject(self.transform, "Panel/Scroll View/Viewport/Content/SoulPrintInfo")
    -- this.soulPrintGrid = Util.GetGameObject(this.soulPrintInfo, "Grid")
    -- this.soulPrintPre=Util.GetGameObject(this.soulPrintGrid,"SoulPrintPre")
end

--绑定事件（用于子类重写）
function RoleInfoPopup:BindEvent()
    Util.AddClick(this.BackMask,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)

    Util.AddClick(this.talentBtn,function()
        UIManager.OpenPanel(UIName.RoleTalentPopup,curHeroData.heroConfig,curHeroData.breakId,curHeroData.upStarId)
    end)
    -- Util.AddClick(this.backBtn, function()
    --     PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    --     self:ClosePanel()
    -- end)
    -- Util.AddClick(this.skill1, function()
    --     if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
    --         Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --     end
    --     this:SetSkillSelectImage(this.skill1.transform, true)


    --     local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id, allSkillDatas[1].skillConfig.Type)
    --     local panel = UIManager.OpenPanel(UIName.SkillInfoPopup, allSkillDatas[1], 4, 10, maxLv, 1)
    --     --this.skillGrid:GetComponent("Canvas").overrideSorting=true
    --     --this.skillGrid:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
    --     triggerCallBack = function(panelType, p)
    --         if panelType == UIName.SkillInfoPopup and p == panel then
    --             --监听到SkillInfoPopup关闭，把层级设回去
    --             --this.skillGrid:GetComponent("Canvas").overrideSorting=false
    --             --this.skillGrid:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
    --             Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --             this:SetSkillSelectImage(self.transform, false)
    --         end
    --     end
    --     Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    -- end)
    -- Util.AddClick(this.skill2, function()
    --     if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
    --         Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --     end
    --     this:SetSkillSelectImage(this.skill2.transform, true)


    


    --     local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id, allSkillDatas[2].skillConfig.Type)
    --     local panel = UIManager.OpenPanel(UIName.SkillInfoPopup, allSkillDatas[2], 4, 10, maxLv, 2)
    --     --this.skillGrid:GetComponent("Canvas").overrideSorting=true
    --     --this.skillGrid:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
    --     triggerCallBack = function(panelType, p)
    --         if panelType == UIName.SkillInfoPopup and p == panel then
    --             --监听到SkillInfoPopup关闭，把层级设回去
    --             -- this.skillGrid:GetComponent("Canvas").overrideSorting=false
    --             --this.skillGrid:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
    --             Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --             this:SetSkillSelectImage(self.transform, false)
    --         end
    --     end
    --     Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    -- end)
    -- Util.AddClick(this.skill3, function()
    --     if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
    --         Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --     end
    --     this:SetSkillSelectImage(this.skill3.transform, true)


    --     local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id, allSkillDatas[3].skillConfig.Type)
    --     local panel = UIManager.OpenPanel(UIName.SkillInfoPopup, allSkillDatas[3], 4, 10, maxLv, 1)
    --     --this.skillGrid:GetComponent("Canvas").overrideSorting=true
    --     --this.skillGrid:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
    --     triggerCallBack = function(panelType, p)
    --         if panelType == UIName.SkillInfoPopup and p == panel then
    --             --监听到SkillInfoPopup关闭，把层级设回去
    --             --this.skillGrid:GetComponent("Canvas").overrideSorting=false
    --             --this.skillGrid:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
    --             Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --             this:SetSkillSelectImage(self.transform, false)
    --         end
    --     end
    --     Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    -- end)
    -- Util.AddClick(this.skill4, function()
    --     if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
    --         Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --     end
    --     this:SetSkillSelectImage(this.skill4.transform, true)


    --     local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id, allSkillDatas[4].skillConfig.Type)
    --     local panel = UIManager.OpenPanel(UIName.SkillInfoPopup, allSkillDatas[4], 4, 10, maxLv, 1)
    --     --this.skillGrid:GetComponent("Canvas").overrideSorting=true
    --     --this.skillGrid:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
    --     triggerCallBack = function(panelType, p)
    --         if panelType == UIName.SkillInfoPopup and p == panel then
    --             --监听到SkillInfoPopup关闭，把层级设回去
    --             --this.skillGrid:GetComponent("Canvas").overrideSorting=false
    --             --this.skillGrid:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
    --             Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --             this:SetSkillSelectImage(self.transform, false)
    --         end
    --     end
    --     Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    -- end)
end

--添加事件监听（用于子类重写）
function RoleInfoPopup:AddListener()

end

--移除事件监听（用于子类重写）
function RoleInfoPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RoleInfoPopup:OnOpen(...)
    -- this.selsectEquipImage:SetActive(false)
    this.selsectSkillImage:SetActive(false)
    local arg = { ... }
    curHeroData = arg[1]
    this.isOther = arg[2]

    choosedList = arg[3] or nil
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RoleInfoPopup:OnShow()
    this.content:DOAnchorPosY(566, 0)
    this.RoleInfo0()
    this.RoleInfo1()
    this.SkillInfo()
    this.WarWayInfo()
    this.EquipInfo()
    -- this.SoulPrintInfo()
    this.CombatPlanInfo()
    this.MedalInfo()
    this.TalentInfo()
end

--界面关闭时调用（用于子类重写）
function RoleInfoPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function RoleInfoPopup:OnDestroy()
    soulPrintPreList={}
    this.pinjieList={}
    soulPrintPreList={}
    orginLayer2=0
    orginLayer=0
end

--设置技能选中外框
function this:SetSkillSelectImage(_goTran, _type)
    --_goTran父级   _type==true  显示 =false 隐藏
    this.selsectSkillImage:SetActive(_type)
    --this.selsectSkillImage.transform:SetParent(_goTran)
    --this.selsectSkillImage.transform.localScale = Vector3.one
    --this.selsectSkillImage.transform.localPosition=Vector3.zero
    this.selsectSkillImage.transform.position = _goTran.position
end
--设置装备选中外框
function this:SetEquipSelectImage(_goTran, _type)
    --_goTran父级   _type==true  显示 =false 隐藏
    -- this.selsectEquipImage:SetActive(_type)
    -- this.selsectEquipImage.transform:SetParent(_goTran)
    -- this.selsectEquipImage.transform.localScale = Vector3.one
    -- this.selsectEquipImage.transform.localPosition = Vector3.zero
end

--RoleInfo0
function this.RoleInfo0()
    
    this.head_Frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(curHeroData.heroConfig.Quality, curHeroData.star))
    this.head_Icon.sprite = Util.LoadSprite(curHeroData.icon)
    this.head_Pro.sprite = Util.LoadSprite(GetProStrImageByProNum(curHeroData.heroConfig.PropertyName))
    this.head_Lv.text = curHeroData.lv
    SetHeroStars(this.head_Star, curHeroData.star)
    this.roleName.text = GetLanguageStrById(curHeroData.name)

    local allAddProVal = {}
    if this.isOther then
        this.power.text = curHeroData.actionPower
    else
        if choosedList then
            --local formationList = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_NORMAL)
            local allHeroTeamAddProVal = HeroManager.GetAllHeroTeamAddProVal(choosedList,curHeroData.dynamicId)
            allAddProVal = HeroManager.CalculateHeroAllProValList(1, curHeroData, false,nil,nil,true,allHeroTeamAddProVal)
        else
            allAddProVal = HeroManager.CalculateHeroAllProValList(1, curHeroData, false)
        end
        this.power.text = allAddProVal[HeroProType.WarPower]
    end

    this.radar:SetEdges({ curHeroData.heroConfig.AttackScale / 100, curHeroData.heroConfig.DefenseScale / 100, curHeroData.heroConfig.AssistScale / 100 })
    this.radar.color = Color.New(238 / 255, 211 / 255, 156 / 255, 102 / 255)
    --天赋
    this.talentBtn:SetActive(curHeroData.heroConfig.OpenPassiveSkillRules ~= nil)
    if curHeroData.heroConfig.OpenPassiveSkillRules then
        local openlists,compoundOpenNum,compoundNum = HeroManager.GetAllPassiveSkillIds(curHeroData.heroConfig,curHeroData.breakId,curHeroData.upStarId)
        this.talentProgress.text = #openlists - compoundOpenNum .."/"..#curHeroData.heroConfig.OpenPassiveSkillRules - compoundNum
    end
    --法宝
    -- this.TalismanInfo()

    --品阶
    local pId=0
    if curHeroData.breakId~=0 then
        pId= heroRankupConfig[curHeroData.breakId].Phase[2]
    end
    local hruConfig= ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.HeroRankupConfig,"Star",curHeroData.heroConfig.Star,"Show",1) --动态获取不同英雄最大突破等阶
    for i = 1, #hruConfig do --动态生成
        local item=this.pinjieList[i]
        -- if not item then
        --     item= newObjToParent(this.pinjiePre,this.pinjieRoot)
        --     item.name="Pre"..i
        --     this.pinjieList[i]=item
        -- end
        this.pinjieList[i]:GetComponent("Image").sprite=Util.LoadSprite(i<=pId and pinjieImage[2] or pinjieImage[1])
    end
    for n = 0, this.pinjieRoot.transform.childCount-1 do --超过品阶关闭显示
        this.pinjieRoot.transform:GetChild(n).gameObject:SetActive(n+1<=#hruConfig)
    end
end
--RoleInfo1
function this.RoleInfo1()
    --定位描述相关
    this.posBgImage.sprite=Util.LoadSprite(GetHeroPosBgStr(curHeroData.heroConfig.Profession))
    this.posImage.sprite=Util.LoadSprite(GetHeroPosStr(curHeroData.heroConfig.Profession))
    this.posText.text=curHeroData.heroConfig.HeroLocation

    --基础属性
    local allAddProVal = {}
    if (this.isOther) then
        --this.atk.text = curHeroData.attack
        --this.hp.text = curHeroData.hp
        --this.phyDef.text = curHeroData.pDef
        --this.magDef.text = curHeroData.mDef
        allAddProVal = curHeroData.allAddProVal
    else
        if choosedList then
            --local formationList = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_NORMAL)
            local allHeroTeamAddProVal = HeroManager.GetAllHeroTeamAddProVal(choosedList,curHeroData.dynamicId)
            allAddProVal = HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId, false,nil,nil,true,allHeroTeamAddProVal)
        else
            allAddProVal = HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId, false)
        end
    end
    this.atk.text = allAddProVal[HeroProType.Attack]
    this.hp.text = allAddProVal[HeroProType.Hp]
    this.phyDef.text = allAddProVal[HeroProType.PhysicalDefence]
    this.speed.text = allAddProVal[HeroProType.Speed]
    this.magDef.text = allAddProVal[HeroProType.MagicDefence]
    Util.AddOnceClick(this.proBtn,function()
        local guildSkill = nil
        if this.isOther then guildSkill = curHeroData.guildSkill end
        UIManager.OpenPanel(UIName.RoleProInfoPopup,allAddProVal,curHeroData.heroConfig,true,guildSkill)
    end)
end
function this.SkillInfo()
    -- local oldSkillList=HeroManager.GetSkillIdsByHeroRules(curHeroData.heroConfig.OpenSkillRules,curHeroData.star,curHeroData.breakId)
    -- local oldOpenPassiveSkillRules=HeroManager.GetPassiveSkillIdsByHeroRules(curHeroData.heroConfig.OpenPassiveSkillRules,curHeroData.star,curHeroData.breakId)
    local oldSkillList = HeroManager.GetSkillIdsByHeroRulesRole(curHeroData.heroConfig.OpenSkillRules,curHeroData.star,curHeroData.breakId, curHeroData)
    local oldOpenPassiveSkillRules = HeroManager.GetPassiveSkillIdsByHeroRuleslock(curHeroData.heroConfig.OpenPassiveSkillRules,curHeroData.star,curHeroData.breakId, curHeroData)
 
    for key, value in pairs(oldOpenPassiveSkillRules) do
        table.insert(oldSkillList, value)
    end

    table.sort(oldSkillList,function(a,b) 
        return a.skillConfig.Id < b.skillConfig.Id
    end)

    this.SetSkillInfo(oldSkillList[2],this.skill1,1)
    this.SetSkillInfo(oldSkillList[3],this.skill2,2)
    this.SetSkillInfo(oldSkillList[4],this.skill3,3)
    this.SetSkillInfo(oldSkillList[5],this.skill4,4)
end

function this.SetSkillInfo(skillData,skillGo,pos)
    if skillData and skillData.skillConfig and skillData.skillConfig.Name then
        skillGo:SetActive(true)
        -- local addLv=this.ShowAddLevel(pos) -- 铸神加技能等级
        Util.GetGameObject(skillGo.transform,"Icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillData.skillConfig.Icon))
        --Util.GetGameObject(skillGo.transform, "Text"):GetComponent("Text").text = skillData.skillConfig.Name--"lv." .. (skillData.skillId % 10)
        --Util.GetGameObject(skillGo.transform,"SkillTypeImage"):GetComponent("Image").sprite=Util.LoadSprite(GetSkillType(skillData))
        if SkillLogicConfig[skillData.skillConfig.Id]~=nil then
            Util.GetGameObject(skillGo.transform,"Lv/LvTx"):GetComponent("Text").text = SkillLogicConfig[skillData.skillConfig.Id].Level 
        else
            Util.GetGameObject(skillGo.transform,"Lv/LvTx"):GetComponent("Text").text = PassiveSkillLogicConfig[skillData.skillConfig.Id].Level 
        end

        if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
        end
        this:SetSkillSelectImage(skillGo.transform, true)

        Util.AddOnceClick(Util.GetGameObject(skillGo.transform,"Image"), function()
            local skillLogicConfig_
            local isPassive
            local skillPos
            if skillLogicConfig_==nil then
                skillLogicConfig_=ConfigManager.TryGetConfigDataByKey(ConfigName.SkillLogicConfig,"Id",skillData.skillConfig.Id)
                isPassive=false
            end
            if skillLogicConfig_==nil then
                skillLogicConfig_=ConfigManager.TryGetConfigDataByKey(ConfigName.PassiveSkillLogicConfig,"Id",skillData.skillConfig.Id)
                isPassive=true
            end
           
            if isPassive then
                for i=1, #curHeroData.heroConfig.OpenPassiveSkillRules do
                    if curHeroData.heroConfig.OpenPassiveSkillRules[i][2]==skillLogicConfig_.Group then
                        skillPos=curHeroData.heroConfig.OpenPassiveSkillRules[i][1]
                        break
                    end
                end
            else
                for i=1, #curHeroData.heroConfig.OpenSkillRules do
                    if curHeroData.heroConfig.OpenSkillRules[i][2]==skillLogicConfig_.Group then
                        skillPos=curHeroData.heroConfig.OpenSkillRules[i][1]
                        break
                    end
                end
            end
            local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id, skillPos)
            
            --显示铸神等级技能 获取铸神技能id

            if SkillLogicConfig[skillData.skillConfig.Id]~=nil then
               local panel = UIManager.OpenPanel(UIName.SkillInfoPopup, skillData, 4, 10, maxLv, 1,SkillLogicConfig[skillData.skillConfig.Id].Level)
            else
                local panel = UIManager.OpenPanel(UIName.SkillInfoPopup, skillData, 4, 10, maxLv, 1,PassiveSkillLogicConfig[skillData.skillConfig.Id].Level)
            end
            triggerCallBack = function(panelType, p)
                if panelType == UIName.SkillInfoPopup and p == panel then
                    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
                    this:SetSkillSelectImage(self.transform, false)
                end
            end
            Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
        end)
    else
        skillGo:SetActive(false)
    end
end

--战法
function this.WarWayInfo()
    this.SetWarWayItem(1,this.warWayItem1)
    this.SetWarWayItem(2,this.warWayItem2)
end

function this.SetWarWayItem(pos,warWayGo)
    local frame = Util.GetGameObject(warWayGo,"frame"):GetComponent("Image")
    local icon = Util.GetGameObject(warWayGo,"icon"):GetComponent("Image")

    local warWaySlotId = curHeroData[string.format("warWaySlot%dId", pos)]
    if warWaySlotId and warWaySlotId ~= 0 then
        icon.gameObject:SetActive(true)
        local warWayConfig = WarWaySkillConfig[warWaySlotId]
        icon.sprite = Util.LoadSprite(GetResourceStr(warWayConfig.Image))
        frame.sprite = Util.LoadSprite(GetQuantityImageByquality(warWayConfig.Level))

        Util.AddOnceClick(Util.GetGameObject(warWayGo,"frame"), function()
            UIManager.OpenPanel(UIName.CommonInfoPopup, CommonInfoType.WarWay, Util.GetGameObject(warWayGo,"frame"), warWayConfig.ID)
        end)
    else
        icon.gameObject:SetActive(false)
        frame.sprite = Util.LoadSprite(GetQuantityImageByquality(0))
    end
end

--装备
function this.EquipInfo()
    local curHeroEquipDatas = {}
    
    for i = 1, #curHeroData.equipIdList do
        local equipData = {}
        if (this.isOther) then
            equipData = GoodFriendManager.GetSingleEquipData(curHeroData.equipIdList[i])
        else
            equipData = EquipManager.GetSingleEquipData(curHeroData.equipIdList[i])
        end
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        end
    end
    for i = 1, this.equipContent.transform.childCount do
        local go = this.equipContent.transform:GetChild(i - 1).gameObject
        local curEquipData
        Util.GetGameObject(go.transform,"frame"):GetComponent("Image").sprite=Util.LoadSprite(GetQuantityImageByquality(1))
         -----------------装备铸神
        Util.GetGameObject(go, "AddLv"):SetActive(false)
        Util.GetGameObject(go, "AddLv"):GetComponent("Image").sprite = nil
        -----------------装备铸神 end
        if curHeroEquipDatas[i] then
            Util.GetGameObject(go.transform, "mask"):SetActive(false)
            Util.GetGameObject(go.transform, "icon"):SetActive(true)
            Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(curHeroEquipDatas[i].frame)
            Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(curHeroEquipDatas[i].icon)
            -----------------装备铸神
            local nowAddLevel=this.ShowAddLevel(i)
            if nowAddLevel > 0 then
                Util.GetGameObject(go, "AddLv"):SetActive(true)                
                Util.GetGameObject(go, "AddLv"):GetComponent("Image").sprite = Util.LoadSprite(SpriteName..nowAddLevel)
            else
                Util.GetGameObject(go, "AddLv"):SetActive(false)
                Util.GetGameObject(go, "AddLv"):GetComponent("Image").sprite = nil
            end
            -----------------装备铸神 end
            if curHeroEquipDatas[i].itemConfig.ItemBaseType == ItemBaseType.Equip then
                Util.GetGameObject(go.transform, "star"):SetActive(true)
                SetHeroStars(Util.GetGameObject(go.transform, "star"),curHeroEquipDatas[i].star)
            else
                Util.GetGameObject(go.transform, "star"):SetActive(false)
            end
            curEquipData = curHeroEquipDatas[i]
        else
            Util.GetGameObject(go.transform, "mask"):SetActive(true)
            Util.GetGameObject(go.transform, "star"):SetActive(false)
            Util.GetGameObject(go.transform, "icon"):SetActive(false)
        end
        local frameBtn = Util.GetGameObject(go.transform, "frame")
        Util.AddOnceClick(frameBtn, function()
            if curEquipData then
                if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
                    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
                end
                local panel = UIManager.OpenPanel(UIName.RewardEquipSingleShowPopup, curEquipData,function() end,false,false)
                triggerCallBack = function(panelType, p)
                    if panelType == UIName.RewardEquipSingleShowPopup and panel == p then
                        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
                    end
                end
                Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
            end
        end)
    end
end

function this.TalentInfo()
    for i = 1, 5 do
        local frame = Util.GetGameObject(this.TalentInfoGo, "Content/item" .. tostring(i) .. "/frame")
        local icon = Util.GetGameObject(this.TalentInfoGo, "Content/item" .. tostring(i) .. "/icon")
        icon:SetActive(false)
        frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(0))
        Util.AddOnceClick(frame, function()
        end)
        if curHeroData.talent and curHeroData.talent[i] then
            icon:SetActive(true)
            local skillid = curHeroData.talent[i].skillId
            local skillConfig = G_PassiveSkillConfig[skillid]

            icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
            frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(0))

            Util.AddOnceClick(frame, function()
                local skillConfig = G_PassiveSkillConfig[skillid]
                local skillData = {}
                skillData.skillId = skillid
                skillData.skillConfig = skillConfig       
                local panel = UIManager.OpenPanel(UIName.SkillInfoPopup, skillData, 1, nil, nil, 3, nil)
            end)
        end
    end
end

function this.CombatPlanInfo()
    for i = 1, 2 do
        local frame = Util.GetGameObject(this.CombatPlanInfoGo, "Content/item" .. tostring(i) .. "/frame")
        local icon = Util.GetGameObject(this.CombatPlanInfoGo, "Content/item" .. tostring(i) .. "/icon")
        icon:SetActive(false)
        frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(0))
        Util.AddOnceClick(frame, function()
            
        end)
        if curHeroData.planList and #curHeroData.planList > 0 then
            for j = 1, #curHeroData.planList do
                if curHeroData.planList[j].position == i then
                    icon:SetActive(true)

                    local planData
                    if this.isOther then
                        planData = GoodFriendManager.GetModelData_1(curHeroData.planList[j].planId)
                    else
                        planData = CombatPlanManager.GetPlanData(curHeroData.planList[j].planId)
                    end

                    local combatConfig = G_CombatPlanConfig[planData.combatPlanId]
                    if combatConfig.Quality ~= 6 then
                        quality = combatConfig.Quality + 1
                    else
                        quality = combatConfig.Quality
                    end
                    icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(combatConfig.Icon))
                    frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(quality))

                    Util.AddOnceClick(frame, function()
                        UIManager.OpenPanel(UIName.CombatPlanTipsPopup, 3, nil, nil, nil, nil, nil, planData)
                    end)
                    break
                end
            end
        end
    end
end

function this.MedalInfo()
    --勋章展示
    for i = 1, 4 do
        local frame = Util.GetGameObject(this.medalInfo, "Content/item" .. tostring(i) .. "/frame")
        local icon = Util.GetGameObject(this.medalInfo, "Content/item" .. tostring(i) .. "/icon")
        local text = Util.GetGameObject(this.medalInfo, "Content/item" .. tostring(i) .. "/icon/Text")
        icon:SetActive(false)
        frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(0))
        Util.AddOnceClick(frame, function()
            
        end)
        if curHeroData.medal and #curHeroData.medal > 0 then
            for j = 1, #curHeroData.medal do
                if curHeroData.medal[j].position == i then
                    icon:SetActive(true)

                    local medalData
                    if this.isOther then
                        medalData = curHeroData.medal[j]
                    else
                        medalData = MedalManager.GetOneMedalData(curHeroData.medal[j].id)
                    end
                    local MedalConfig = MedalConfig[medalData.medalId]
                    icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(ArtResourcesConfig[itemConfig[MedalConfig.Id].ResourceID]).Name)
                    frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(MedalConfig.Quality))
                    text:GetComponent("Text").text=MedalManager.GetQualityName(MedalConfig.Quality)
                    Util.AddOnceClick(frame, function()
                        UIManager.OpenPanel(UIName.MedalParticularsPopup,MedalConfig.Id,nil,false,nil,false,false)
                    end)
                    break
                end
            end
        end
    end

    local suit1 = Util.GetGameObject(this.medalInfo, "suit1")
    local suit2 = Util.GetGameObject(this.medalInfo, "suit2")
    suit2:SetActive(false)
    --套装激活
    if curHeroData.suitActive and #curHeroData.suitActive>0 then
        for i = 1, #curHeroData.suitActive do
            local suit = Util.GetGameObject(this.medalInfo, "suit"..i)
            suit:SetActive(true)
            local medalSuitData=MedalManager.GetMedalSuitInfoById(curHeroData.suitActive[i].suitId)
            local suitTypedata=MedalManager.GetMedalSuitInfoByType(medalSuitData.Type)
            suit:GetComponent("Text").text=string.format(GetLanguageStrById(23073),medalSuitData.Star,GetLanguageStrById(suitTypedata.Name),curHeroData.suitActive[i].num)
        end
    else
        suit1:SetActive(true)
        suit1:GetComponent("Text").text=GetLanguageStrById(23074)
    end
end

function this.OnSortingOrderChange()
    --特效层级重设
    for i=1,#soulPrintPreList do
        Util.AddParticleSortLayer(soulPrintPreList[i], this.sortingOrder- orginLayer)
    end   
    orginLayer = this.sortingOrder
end

--铸神等级
function this.ShowAddLevel(curPos)
    local AddLevel = 0
    local curData = curHeroData.partsData[curPos]
    if curData.isUnLock > curData.actualLv then
        AddLevel = curData.actualLv 
    else
        AddLevel = curData.isUnLock
    end
    if AddLevel < 0 then AddLevel = 0 end
    return  AddLevel 
end

function this.FreshGodEquipLevel(unlockData,heroData)
    heroData.partsData = {}
    if unlockData and #unlockData > 0 then
        for i = 1, #unlockData do
            --> isUnLock -1未解锁，0已解锁，>0已升级       actualLv 实际应用等级
            heroData.partsData[unlockData[i].position] = {position = unlockData[i].position, isUnLock = unlockData[i].isUnLock, actualLv = 0}
        end
        local partsData = heroData.partsData
        for i = 1, #partsData do
            partsData[i].actualLv = 0
        end
        for i = 1, #heroData.equipIdList do
            local equipId = heroData.equipIdList[i]
            local equipConfig = G_EquipConfig[tonumber(equipId)]
            if partsData[equipConfig.Position] then
                if partsData[equipConfig.Position].isUnLock > 0 then
                    if equipConfig.IfAdjust == 1 then
                        partsData[equipConfig.Position].actualLv = math.min(partsData[equipConfig.Position].isUnLock, equipConfig.Adjustlimit)
                    end
                end
            end
        end
    end
end

return RoleInfoPopup