require("Base/BasePanel")
HandBookEquipInfoPanel = Inherit(BasePanel)
local skillGos = {}
local curSuitProGo = {}
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
--初始化组件（用于子类重写）
function HandBookEquipInfoPanel:InitComponent()

    self.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    --装备详情
    -- self.equipName = Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/name/text"):GetComponent("Text")
    self.equipName = Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/text"):GetComponent("Text")
    self.icon = Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/icon"):GetComponent("Image")
    self.frame = Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/frame"):GetComponent("Image")
    self.equipType=Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/proGrid/equipTypeText"):GetComponent("Text")
    self.equipPos=Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/proGrid/equipPosText"):GetComponent("Text")
    --self.equipRebuildLv=Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/proGrid/equipLvText")
    self.equipQuaText=Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/qualityText"):GetComponent("Text")
    -- self.equipInfoText=Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/equipInfoText"):GetComponent("Text")
    self.equipInfoText=Util.GetGameObject(self.transform, "Content/bg/equipInfoText"):GetComponent("Text")
    --装备属性
    self.mainPro=Util.GetGameObject(self.transform, "Content/bg/mainPro")
    self.mainProName=Util.GetGameObject(self.transform, "Content/bg/mainPro/GameObject/curProName"):GetComponent("Text")
    -- self.mainProVale=Util.GetGameObject(self.transform, "Content/bg/mainPro/GameObject/curProVale"):GetComponent("Text")

    self.equipOtherProPre=Util.GetGameObject(self.transform, "Content/bg/proPre")
    -- self.equipProGrid = Util.GetGameObject(self.transform, "Content/bg/proRect/GameObject/proGrid")
    self.equipProGrid = Util.GetGameObject(self.transform, "Content/bg/proRect/proGrid")

    --装备被动技能
    self.skillGrid=Util.GetGameObject(self.transform, "Content/bg/skillGrid")
    self.skillObject=Util.GetGameObject(self.transform, "Content/bg/skillObject")
    for i = 1, 7 do
        skillGos[i] = Util.GetGameObject(self.transform, "Content/bg/skillGrid/skillGrid1 ("..i..")")
    end

end

--绑定事件（用于子类重写）
function HandBookEquipInfoPanel:BindEvent()

    Util.AddClick(self.BtnBack, function()
        --PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function HandBookEquipInfoPanel:AddListener()

end

--移除事件监听（用于子类重写）
function HandBookEquipInfoPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function HandBookEquipInfoPanel:OnOpen(equipSId)

    --装备基础信息
    local itemConfigData=ConfigManager.GetConfigData(ConfigName.ItemConfig, equipSId)
    local equipConfigData=ConfigManager.GetConfigData(ConfigName.EquipConfig, equipSId)
    self.equipQuaText.text=GetStringByEquipQua(equipConfigData.Quality,GetLanguageStrById(GetQuaStringByEquipQua(equipConfigData.Quality)))
    self.equipName.text=GetStringByEquipQua(equipConfigData.Quality,GetLanguageStrById(equipConfigData.Name))
    --if equipConfigData.IfClear==0 then
    --    self.equipRebuildLv:GetComponent("Text").text="不可重铸"
    --elseif equipConfigData.IfClear==1 then
    --    self.equipRebuildLv:GetComponent("Text").text="重铸等级："..equipConfigData.InitialLevel
    --end
    self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(equipConfigData.Quality))
    self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    self.equipInfoText.text=GetLanguageStrById(itemConfigData.ItemDescribe)
    self.equipType.text=GetLanguageStrById(11093)..GetEquipPosStrByEquipPosNum(equipConfigData.Position)
    self.equipPos.text=string.format(GetLanguageStrById(11094),GetJobStrByJobNum(equipConfigData.ProfessionLimit))
    EquipManager.SetEquipStarShow(Util.GetGameObject(self.transform, "Content/bg/equipInfo/GameObject/star"),itemConfigData.Id)
    --装备属性
    self.mainProName.text=GetLanguageStrById(11857)..": "..GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.PropertyConfig, equipConfigData.PropertyMin[1]).Info).." "..GetLanguageStrById(equipConfigData.Property[1][2])
    -- self.mainProVale.text=GetLanguageStrById(equipConfigData.Property[1][2])--"【"..equipConfigData.PropertyMin[2].."-"..equipConfigData.PropertyMax[2].."】"

    --套装属性
    if equipConfigData.SuiteID and equipConfigData.SuiteID > 0 then
        Util.GetGameObject(self.transform, "Content/bg/proRect"):SetActive(true)
        local curSuitConFig = ConfigManager.GetConfigData(ConfigName.EquipSuiteConfig,equipConfigData.SuiteID)
        if curSuitConFig then
            for i = 1, math.max(#curSuitConFig.SuiteValue, #curSuitProGo) do
                local go = curSuitProGo[i]
                if not go then
                    go = newObject(self.equipOtherProPre)
                    go.transform:SetParent(self.equipProGrid.transform)
                    go.transform.localScale = Vector3.one
                    go.transform.localPosition = Vector3.zero
                    curSuitProGo[i] = go
                end
                go.gameObject:SetActive(false)
            end
            for i = 1, #curSuitConFig.SuiteValue do
                local go = curSuitProGo[i]
                go.gameObject:SetActive(true)
                Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text = "<color=#B9AC97>" .. GetLanguageStrById(propertyConfig[curSuitConFig.SuiteValue[i][2]].Info) .."+ "..GetPropertyFormatStr(propertyConfig[curSuitConFig.SuiteValue[i][2]].Style,curSuitConFig.SuiteValue[i][3]) .. "</color>  <color=#B9AC97>(" .. curSuitConFig.SuiteValue[i][1] .. GetLanguageStrById(11095)
                -- Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text = "<color=#B9AC97>(" .. curSuitConFig.SuiteValue[i][1] .. GetLanguageStrById(11095)
            end
        end
    else
        Util.GetGameObject(self.transform, "Content/bg/proRect"):SetActive(false)
    end

    local passiveSkill = {}
    if  equipConfigData.SkillPoolId and  #equipConfigData.SkillPoolId > 0 then
        for i = 1, #equipConfigData.SkillPoolId do
            local curSkillId = equipConfigData.SkillPoolId[i]
            for i, v2 in ConfigPairs(ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)) do
                if v2.PoolNum == curSkillId then
                    table.insert(passiveSkill,ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig,v2.Id))
                end
            end
        end
        for i = 1, #skillGos do
            if i > #passiveSkill then
                skillGos[i]:SetActive(false)
            else
                skillGos[i]:SetActive(true)
                Util.GetGameObject(skillGos[i].transform, "skillInfoText"):GetComponent("Text").text = GetSkillConfigDesc(passiveSkill[i])
            end
        end
        self.skillGrid:SetActive(true)
        self.skillObject:SetActive(true)
    else
        self.skillGrid:SetActive(false)
        self.skillObject:SetActive(false)
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function HandBookEquipInfoPanel:OnShow()

end

--界面关闭时调用（用于子类重写）
function HandBookEquipInfoPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function HandBookEquipInfoPanel:OnDestroy()
    curSuitProGo = {}
end

return HandBookEquipInfoPanel