require("Base/BasePanel")
EquipInfoPopup = Inherit(BasePanel)
local this = EquipInfoPopup
this.skillConfig=ConfigManager.GetConfig(ConfigName.SkillConfig)
--初始化组件（用于子类重写）
function this:InitComponent()

    this.panel=Util.GetGameObject(self.transform,"Panel"):GetComponent("RectTransform")
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.equipName = Util.GetGameObject( this.panel, "image/title"):GetComponent("Text")
    this.frame = Util.GetGameObject( this.panel, "equip/frame"):GetComponent("Image")
    this.icon = Util.GetGameObject( this.panel, "equip/icon"):GetComponent("Image")
    this.equipEffect=Util.GetGameObject( this.panel, "effect/text"):GetComponent("Text")
    this.equipType=Util.GetGameObject( this.panel, "desc/type"):GetComponent("Text")
    this.equipRebuildAble=Util.GetGameObject( this.panel, "desc/rebuildAble"):GetComponent("Text")
    this.equipRebuildLv=Util.GetGameObject( this.panel, "desc/rebuildLv")
    this.equipPro=Util.GetGameObject( this.panel, "desc/pro"):GetComponent("Text")
    this.equipProPre=Util.GetGameObject( this.panel, "equipProPre")
    this.equipProGrid=Util.GetGameObject( this.panel, "equipProGrid")
end

--绑定事件（用于子类重写）
function this:BindEvent()

    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()

end

--移除事件监听（用于子类重写）
function this:RemoveListener()

end
function this:OnShow()
end
--界面打开时调用（用于子类重写）
function this:OnOpen(...)

    local args = {...}
    local curEquipData=args[1]
    local pos_Y=args[2]
    this.panel:DOAnchorPosY(pos_Y-100,0)
    this.equipName.text=curEquipData.equipConfig.Name
    this.frame.sprite = Util.LoadSprite(curEquipData.frame)
    this.icon.sprite = Util.LoadSprite(curEquipData.icon)
    if curEquipData.skillId and curEquipData.skillId > 0 then
        local cfg = ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig,curEquipData.skillId)
        this.equipEffect.text=GetSkillConfigDesc(cfg)
    else
        this.equipEffect.text=""
    end
    this.equipType.text=string.format(GetLanguageStrById(11555),GetEquipPosStrByEquipPosNum(curEquipData.equipConfig.Position))
    if curEquipData.equipConfig.IfClear==0 then
        this.equipRebuildAble.text=GetLanguageStrById(11556)
        this.equipRebuildLv:GetComponent("Text").text=GetLanguageStrById(11557)
    elseif curEquipData.equipConfig.IfClear==1 then
        this.equipRebuildAble.text=GetLanguageStrById(11558)
        this.equipRebuildLv:GetComponent("Text").text=string.format(GetLanguageStrById(11559),curEquipData.resetLv)--工坊等级
    end
    this.equipPro.text=string.format(GetLanguageStrById(11560),GetJobStrByJobNum(curEquipData.equipConfig.ProfessionLimit))
    Util.ClearChild(this.equipProGrid.transform)
    local equipAllPro = curEquipData.mainAttribute
    --for i = 1, #curEquipData.secondAttribute do
        --        table.insert(equipAllPro,curEquipData.secondAttribute[i])
        
    --end
    --装备
    for i = 1, #equipAllPro do
        local go = newObject(this.equipProPre)
        go.transform:SetParent(this.equipProGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)
        
        Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text = equipAllPro[i].PropertyConfig.Info
        if equipAllPro[i].PropertyConfig.Style==1 then--绝对值
            Util.GetGameObject(go.transform, "proVal"):GetComponent("Text").text =  equipAllPro[i].propertyValue
        elseif equipAllPro[i].PropertyConfig.Style==2 then--百分百
            Util.GetGameObject(go.transform, "proVal"):GetComponent("Text").text =  tostring(equipAllPro[i].propertyValue/100).."%"
        end
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()

end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()

end

function EquipInfoPopup:GetEquipSkillData(skillId)
    return this.skillConfig[skillId]
end
return EquipInfoPopup;