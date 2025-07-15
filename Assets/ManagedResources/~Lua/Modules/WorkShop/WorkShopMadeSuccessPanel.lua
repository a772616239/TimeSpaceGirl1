require("Base/BasePanel")
WorkShopMadeSuccessPanel = Inherit(BasePanel)
local this=WorkShopMadeSuccessPanel
this.skillConfig=ConfigManager.GetConfig(ConfigName.SkillConfig)
local curEquipData
--初始化组件（用于子类重写）
function WorkShopMadeSuccessPanel:InitComponent()

    this.equipName = Util.GetGameObject(self.transform, "Content/bg/name/Text"):GetComponent("Text")
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    --装备详情
    this.icon = Util.GetGameObject(self.transform, "Content/bg/armorInfo/icon"):GetComponent("Image")
    this.frame = Util.GetGameObject(self.transform, "Content/bg/armorInfo/frame"):GetComponent("Image")
    this.equipType=Util.GetGameObject(self.transform, "Content/bg/armorInfo/grid/equipType"):GetComponent("Text")
    this.equipPos=Util.GetGameObject(self.transform, "Content/bg/armorInfo/grid/equipPos"):GetComponent("Text")
    this.equipRebuildLv=Util.GetGameObject(self.transform, "Content/bg/armorInfo/grid/equipRebuildLv")
    this.equipQuaText=Util.GetGameObject(self.transform, "Content/bg/armorInfo/equipQuaText"):GetComponent("Text")
    this.equipInfoText=Util.GetGameObject(self.transform, "Content/bg/armorInfo/equipInfoText"):GetComponent("Text")
    this.powerNum=Util.GetGameObject(self.transform, "Content/bg/armorInfo/powerNum"):GetComponent("Text")
    --装备属性
    this.equipOtherProPre=Util.GetGameObject(self.transform, "Content/proPre")
    this.equipProGrid=Util.GetGameObject(self.transform, "Content/proRect/proGrid")
    this.mainPro=Util.GetGameObject(self.transform, "Content/bg/mainPro")
    this.mainProName=Util.GetGameObject(self.transform, "Content/bg/mainPro/proName"):GetComponent("Text")
    this.mainProVale=Util.GetGameObject(self.transform, "Content/bg/mainPro/proVale"):GetComponent("Text")
    --装备被动技能
    this.skillObject=Util.GetGameObject(self.transform, "Content/skillObject")
    this.skillInfo=Util.GetGameObject(self.transform, "Content/skillObject/skillInfo"):GetComponent("Text")
    this.expInfo=Util.GetGameObject(self.transform, "Content/bg/expInfo"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function WorkShopMadeSuccessPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function WorkShopMadeSuccessPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopMadeSuccessPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopMadeSuccessPanel:OnOpen(...)

    -- 播放音效
    SoundManager.PlaySound(SoundConfig.Sound_Reward)

    local args = {...}
    curEquipData=args[1]

end
function WorkShopMadeSuccessPanel:OnShow()
   
    this.expInfo.text=GetLanguageStrById(12033)..ConfigManager.GetConfigData(ConfigName.WorkShopEquipmentConfig, curEquipData.id).Exp
    this.equipQuaText.text=GetStringByEquipQua(curEquipData.equipConfig.Quality,GetQuaStringByEquipQua(curEquipData.equipConfig.Quality))
    this.equipName.text=GetStringByEquipQua(curEquipData.equipConfig.Quality,curEquipData.equipConfig.Name)
    -- if curEquipData.equipConfig.IfClear==0 then
    --     this.equipRebuildLv:GetComponent("Text").text=GetLanguageStrById(11557)
    -- elseif curEquipData.equipConfig.IfClear==1 then
    --     this.equipRebuildLv:GetComponent("Text").text=GetLanguageStrById(12027)..curEquipData.resetLv
    -- end
    this.equipRebuildLv:SetActive(false)
    this.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(curEquipData.equipConfig.Quality))
    this.icon.sprite = Util.LoadSprite(GetResourcePath(curEquipData.itemConfig.ResourceID))
    this.equipInfoText.text=curEquipData.itemConfig.ItemDescribe
    this.powerNum.text=EquipManager.CalculateWarForce(curEquipData.id)   
    this.skillObject:SetActive(false)
    this.equipType.text=GetLanguageStrById(11093)..GetEquipPosStrByEquipPosNum(curEquipData.equipConfig.Position)
    this.equipPos.text=string.format(GetLanguageStrById(11094),GetJobStrByJobNum(curEquipData.equipConfig.ProfessionLimit))
    --装备属性
    this.mainProName.text=ConfigManager.GetConfigData(ConfigName.PropertyConfig, curEquipData.mainAttribute.propertyId).Info
    this.mainProVale.text=curEquipData.mainAttribute.propertyValue
    --副属性
    --Util.ClearChild(this.equipProGrid.transform)
    --local equipCurAllPro={}
    -- if #curEquipData.secondAttribute >0 then
    --     Util.GetGameObject(self.transform, "Content/proRect"):SetActive(true)
    --     for i = 1, #curEquipData.secondAttribute do
    --         local curSecondAttribute={}
    --         curSecondAttribute.PropertyConfig=ConfigManager.GetConfigData(ConfigName.PropertyConfig, curEquipData.secondAttribute[i].propertyId)
    --         curSecondAttribute.propertyValue=curEquipData.secondAttribute[i].propertyValue
    --         table.insert(equipCurAllPro,curSecondAttribute)
    --     end
    --     for i = 1, #equipCurAllPro do
    --         local go = newObject(this.equipOtherProPre)
    --         go.transform:SetParent(this.equipProGrid.transform)
    --         go.transform.localScale = Vector3.one
    --         go.transform.localPosition = Vector3.zero
    --         go:SetActive(true)
    --         Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text = equipCurAllPro[i].PropertyConfig.Info
    --         Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text =  GetPropertyFormatStr(equipCurAllPro[i].PropertyConfig.Style,equipCurAllPro[i].propertyValue)

    --     end
    -- else
    Util.GetGameObject(self.transform, "Content/proRect"):SetActive(false)
    --end
end
function WorkShopMadeSuccessPanel:GetEquipSkillData(skillId)
    return this.skillConfig[skillId]
end

--界面关闭时调用（用于子类重写）
function WorkShopMadeSuccessPanel:OnClose()

    --if curEquipData then
    --    WorkShopManager.UpdataWorkShopLvAndExp(ConfigManager.GetConfigData(ConfigName.WorkShopEquipmentConfig, curEquipData.id).Exp)
    --end
end

--界面销毁时调用（用于子类重写）
function WorkShopMadeSuccessPanel:OnDestroy()

end

return WorkShopMadeSuccessPanel