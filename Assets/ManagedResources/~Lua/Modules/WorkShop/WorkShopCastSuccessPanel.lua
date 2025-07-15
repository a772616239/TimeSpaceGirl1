require("Base/BasePanel")
WorkShopCastSuccessPanel = Inherit(BasePanel)
local this=WorkShopCastSuccessPanel
local curEquipData
local nextEquipData
local openThisPanel
--初始化组件（用于子类重写）
function WorkShopCastSuccessPanel:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.equipName = Util.GetGameObject(self.transform, "name/Text"):GetComponent("Text")
    this.frame = Util.GetGameObject(self.transform, "armorInfo/frame"):GetComponent("Image")
    this.icon = Util.GetGameObject(self.transform, "armorInfo/icon"):GetComponent("Image")
    this.equipType=Util.GetGameObject(self.transform, "armorInfo/grid/equipType"):GetComponent("Text")
    this.equipPos=Util.GetGameObject(self.transform, "armorInfo/grid/equipPos"):GetComponent("Text")
    this.equipRebuildLv=Util.GetGameObject(self.transform, "armorInfo/grid/equipRebuildLv")
    this.equipQuaText=Util.GetGameObject(self.transform, "armorInfo/equipQuaText"):GetComponent("Text")
    this.equipInfoText=Util.GetGameObject(self.transform, "armorInfo/equipInfoText"):GetComponent("Text")
    this.powerNum=Util.GetGameObject(self.transform, "armorInfo/powerNum"):GetComponent("Text")
    this.desc=Util.GetGameObject(self.transform, "armorInfo/equipInfoText"):GetComponent("Text")

    this.equipMianCurNameText=Util.GetGameObject(self.transform, "mainPro/curProName"):GetComponent("Text")
    this.equipMianCurValText=Util.GetGameObject(self.transform, "mainPro/curProVale"):GetComponent("Text")
    this.equipMianNextNameText=Util.GetGameObject(self.transform, "mainPro/nextProName"):GetComponent("Text")
    this.equipMianNextValText=Util.GetGameObject(self.transform, "mainPro/nextProVale"):GetComponent("Text")

    this.equipOtherProPre=Util.GetGameObject(self.transform, "otherPro")
    this.equipProGrid=Util.GetGameObject(self.transform, "scroll/grid")
    this.btnDel = Util.GetGameObject(self.transform, "btnDel")
    this.btnSure = Util.GetGameObject(self.transform, "btnSure")
end

--绑定事件（用于子类重写）
function WorkShopCastSuccessPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnDel, function()
        NetManager.GetWorkShopEquipRebuildSureRequest(0,function ()
            self:ClosePanel()
            openThisPanel.UpdateEquipPosHeroData(1, EquipManager.GetSingleEquipData(nextEquipData.id))
            WorkShopManager.unDetermined={}
        end)
    end)
    Util.AddClick(this.btnSure, function()
        NetManager.GetWorkShopEquipRebuildSureRequest(1,function ()
            self:ClosePanel()
            local oldCurEquipUpHeroDid=curEquipData.upHeroDid
            EquipManager.UpdateEquipData(nextEquipData)
            if oldCurEquipUpHeroDid~="0" then
                EquipManager.SetEquipUpHeroDid(nextEquipData.id,oldCurEquipUpHeroDid)
            end
            openThisPanel.UpdateEquipPosHeroData(1, EquipManager.GetSingleEquipData(nextEquipData.id))
            WorkShopManager.unDetermined={}
        end)
    end)
end

--添加事件监听（用于子类重写）
function WorkShopCastSuccessPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopCastSuccessPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopCastSuccessPanel:OnOpen(...)

    -- 播放音效
    SoundManager.PlaySound(SoundConfig.Sound_Reward)

    local args = {...}
    curEquipData=args[1]
    nextEquipData=args[2]--EquipManager.GetSingleEquipData(curEquipData.id)
    openThisPanel=args[3]
end
function WorkShopCastSuccessPanel:OnShow()

    this.OnShowCurPanelData(curEquipData,nextEquipData)
end
function this.OnShowCurPanelData(curEquipData,nextEquipData)
    --this.expInfo.text="工坊经验值+"..ConfigManager.GetConfigData(ConfigName.WorkShopRebuildConfig, curEquipData.equipConfig.Quality-1).Exp
    this.equipQuaText.text=GetStringByEquipQua(curEquipData.equipConfig.Quality,GetQuaStringByEquipQua(curEquipData.equipConfig.Quality))
    this.equipName.text=GetStringByEquipQua(curEquipData.equipConfig.Quality,curEquipData.equipConfig.Name)
    if curEquipData.equipConfig.IfClear==0 then
        this.equipRebuildLv:GetComponent("Text").text=GetLanguageStrById(11557)
    elseif curEquipData.equipConfig.IfClear==1 then
        this.equipRebuildLv:GetComponent("Text").text=GetLanguageStrById(12027)..curEquipData.resetLv
    end
    this.equipType.text=GetLanguageStrById(11093)..GetEquipPosStrByEquipPosNum(curEquipData.equipConfig.Position)
    this.equipPos.text=string.format(GetLanguageStrById(11094),GetJobStrByJobNum(curEquipData.equipConfig.ProfessionLimit))
    this.powerNum.text=EquipManager.CalculateWarForce(curEquipData.did)
    this.desc.text=ConfigManager.GetConfigData(ConfigName.ItemConfig, curEquipData.equipConfig.Id).ItemDescribe
    this.frame.sprite = Util.LoadSprite(curEquipData.frame)
    this.icon.sprite = Util.LoadSprite(curEquipData.icon)
    --主属性
    this.equipMianCurNameText.text=curEquipData.mainAttribute.PropertyConfig.Info
    this.equipMianCurValText.text=curEquipData.mainAttribute.propertyValue
    this.equipMianNextNameText.text=ConfigManager.GetConfigData(ConfigName.PropertyConfig, nextEquipData.mainAttribute.propertyId).Info
    if nextEquipData.mainAttribute.propertyValue>curEquipData.mainAttribute.propertyValue then
        this.equipMianNextValText.text=string.format("<color=#529864FF>%s</color>",nextEquipData.mainAttribute.propertyValue)
    elseif nextEquipData.mainAttribute.propertyValue==curEquipData.mainAttribute.propertyValue then
        this.equipMianNextValText.text=string.format("<color=#FCEBCAFF>%s</color>",nextEquipData.mainAttribute.propertyValue)
    else
        this.equipMianNextValText.text=string.format("<color=#FF6E6BFF>%s</color>",nextEquipData.mainAttribute.propertyValue)
    end
    --副属性
    Util.ClearChild(this.equipProGrid.transform)
    local equipCurAllPro={}
    --for i = 1, #curEquipData.secondAttribute do
    --    table.insert(equipCurAllPro,curEquipData.secondAttribute[i])
    --end
    local equipNextAllPro={}
    --for i = 1, #nextEquipData.secondAttribute do
    --    table.insert(equipNextAllPro,nextEquipData.secondAttribute[i])
    --end
    for i = 1, #equipCurAllPro do
        local go = newObject(this.equipOtherProPre)
        go.transform:SetParent(this.equipProGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)
        
        Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text = equipCurAllPro[i].PropertyConfig.Info
        Util.GetGameObject(go.transform, "nextProName"):GetComponent("Text").text = ConfigManager.GetConfigData(ConfigName.PropertyConfig, equipNextAllPro[i].propertyId).Info--equipNextAllPro[i].PropertyConfig.Info
        if equipCurAllPro[i].PropertyConfig.Style==1 then--绝对值
            Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text =  equipCurAllPro[i].propertyValue
            if  equipNextAllPro[i].propertyValue>equipCurAllPro[i].propertyValue then
                Util.GetGameObject(go.transform, "nextProVale"):GetComponent("Text").text=string.format("<color=#529864FF>%s</color>", equipNextAllPro[i].propertyValue)
            elseif equipNextAllPro[i].propertyValue==equipCurAllPro[i].propertyValue then
                Util.GetGameObject(go.transform, "nextProVale"):GetComponent("Text").text=string.format("<color=#FCEBCAFF>%s</color>", equipNextAllPro[i].propertyValue)
            else
                Util.GetGameObject(go.transform, "nextProVale"):GetComponent("Text").text=string.format("<color=#FF6E6BFF>%s</color>", equipNextAllPro[i].propertyValue)
            end
        elseif equipCurAllPro[i].PropertyConfig.Style==2 then--百分百
            Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text =  GetPropertyFormatStr(2,equipCurAllPro[i].propertyValue)
            if  equipNextAllPro[i].propertyValue>equipCurAllPro[i].propertyValue then
                Util.GetGameObject(go.transform, "nextProVale"):GetComponent("Text").text=string.format("<color=#fcb24eFF>%s</color>",GetPropertyFormatStr(2, equipNextAllPro[i].propertyValue) )
            elseif equipNextAllPro[i].propertyValue==equipCurAllPro[i].propertyValue then
                Util.GetGameObject(go.transform, "nextProVale"):GetComponent("Text").text=string.format("<color=#FCEBCAFF>%s</color>", GetPropertyFormatStr(2,equipNextAllPro[i].propertyValue))
            else
                Util.GetGameObject(go.transform, "nextProVale"):GetComponent("Text").text=string.format("<color=#FF6E6BFF>%s</color>", GetPropertyFormatStr(2,equipNextAllPro[i].propertyValue))
            end
        end
    end
end
--界面关闭时调用（用于子类重写）
function WorkShopCastSuccessPanel:OnClose()

    openThisPanel.DeleteEquipRebuildData(nextEquipData)
end

--界面销毁时调用（用于子类重写）
function WorkShopCastSuccessPanel:OnDestroy()

end

return WorkShopCastSuccessPanel