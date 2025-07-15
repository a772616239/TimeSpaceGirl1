require("Base/BasePanel")
RewardEquipSingleShowPopup2 = Inherit(BasePanel)
local this=RewardEquipSingleShowPopup2
local curSuitProGo = {}
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
--初始化组件（用于子类重写）
function RewardEquipSingleShowPopup2:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    --装备详情
    this.equipName = Util.GetGameObject(self.transform, "Content/bg/equipInfo/name/text"):GetComponent("Text")
    this.icon = Util.GetGameObject(self.transform, "Content/bg/equipInfo/icon"):GetComponent("Image")
    this.frame = Util.GetGameObject(self.transform, "Content/bg/equipInfo/frame"):GetComponent("Image")
    this.equipType=Util.GetGameObject(self.transform, "Content/bg/equipInfo/proGrid/equipTypeText"):GetComponent("Text")
    this.star=Util.GetGameObject(self.transform, "Content/bg/armorInfo/star")
    -- this.equipPos=Util.GetGameObject(self.transform, "Content/bg/equipInfo/proGrid/equipPosText"):GetComponent("Text")--装备关闭职业限定
    this.equipRebuildLv=Util.GetGameObject(self.transform, "Content/bg/equipInfo/proGrid/equipLvText")
    this.equipRebuildLv:SetActive(false)
    this.equipQuaText=Util.GetGameObject(self.transform, "Content/bg/equipInfo/qualityText"):GetComponent("Text")
    this.equipInfoText=Util.GetGameObject(self.transform, "Content/bg/equipInfo/equipInfoText"):GetComponent("Text")
    --装备属性
    this.mainPro=Util.GetGameObject(self.transform, "Content/bg/mainPro")
    this.mainProName=Util.GetGameObject(self.transform, "Content/bg/mainPro/bg/curProName"):GetComponent("Text")
    this.mainProVale=Util.GetGameObject(self.transform, "Content/bg/mainPro/bg/curProName/curProVale"):GetComponent("Text")

    this.equipOtherProPre = Util.GetGameObject(self.transform, "Content/bg/proPre")
    this.equipProGrid = Util.GetGameObject(self.transform, "Content/bg/proRect/proGrid")
    --装备被动技能
    this.skillObject=Util.GetGameObject(self.transform, "Content/bg/castInfoObject")
    this.skillInfo=Util.GetGameObject(self.transform, "Content/bg/castInfoObject/castInfo"):GetComponent("Text")
    this.skillObject:SetActive(false)
end

--绑定事件（用于子类重写）
function RewardEquipSingleShowPopup2:BindEvent()

    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RewardEquipSingleShowPopup2:AddListener()

end

--移除事件监听（用于子类重写）
function RewardEquipSingleShowPopup2:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RewardEquipSingleShowPopup2:OnOpen(equipSId)

    --装备基础信息
    local itemConfigData=ConfigManager.GetConfigData(ConfigName.ItemConfig, equipSId)
    local equipConfigData=ConfigManager.GetConfigData(ConfigName.EquipConfig, equipSId)
    this.equipQuaText.text=GetStringByEquipQua(equipConfigData.Quality,GetQuaStringByEquipQua(equipConfigData.Quality))
    this.equipName.text=GetStringByEquipQua(equipConfigData.Quality,equipConfigData.Name)
    this.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(equipConfigData.Quality))
    this.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    this.equipInfoText.text=itemConfigData.ItemDescribe
    EquipManager.SetEquipStarShow(this.star,equipConfigData.Id)
    this.equipType.text=GetLanguageStrById(11093)..GetEquipPosStrByEquipPosNum(equipConfigData.Position)
    --装备属性
    this.mainProName.text=ConfigManager.GetConfigData(ConfigName.PropertyConfig, equipConfigData.PropertyMin[1]).Info
    this.mainProVale.text="【"..equipConfigData.PropertyMin[2].."-"..equipConfigData.PropertyMax[2].."】"
    --套装属性
    if equipConfigData.SuiteID and equipConfigData.SuiteID > 0 then
        Util.GetGameObject(self.transform, "Content/bg/proRect"):SetActive(true)
        local curSuitConFig = ConfigManager.GetConfigData(ConfigName.EquipSuiteConfig,equipConfigData.SuiteID)
        if curSuitConFig then
            for i = 1, math.max(#curSuitConFig.SuiteValue, #curSuitProGo) do
                local go = curSuitProGo[i]
                if not go then
                    go = newObject(this.equipOtherProPre)
                    go.transform:SetParent(this.equipProGrid.transform)
                    go.transform.localScale = Vector3.one
                    go.transform.localPosition = Vector3.zero
                    curSuitProGo[i] = go
                end
                go.gameObject:SetActive(false)
            end
            for i = 1, #curSuitConFig.SuiteValue do
                local go = curSuitProGo[i]
                go.gameObject:SetActive(true)
                Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text = "<color=#B9AC97>" .. GetLanguageStrById(propertyConfig[curSuitConFig.SuiteValue[i][2]].Info) .."+ "..GetPropertyFormatStr(propertyConfig[curSuitConFig.SuiteValue[i][2]].Style,curSuitConFig.SuiteValue[i][3]) .. "</color>"
                Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text = "<color=#B9AC97>(" .. curSuitConFig.SuiteValue[i][1] .. GetLanguageStrById(11095)
            end
        end
    else
        Util.GetGameObject(self.transform, "Content/bg/proRect"):SetActive(false)
    end
end

--界面关闭时调用（用于子类重写）
function RewardEquipSingleShowPopup2:OnClose()

end

--界面销毁时调用（用于子类重写）
function RewardEquipSingleShowPopup2:OnDestroy()
    curSuitProGo = {}
end

return RewardEquipSingleShowPopup2