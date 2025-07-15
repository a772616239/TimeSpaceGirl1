require("Base/BasePanel")
ToTemParticularsPopup = Inherit(BasePanel)
local this = ToTemParticularsPopup
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)

--初始化组件（用于子类重写）
function ToTemParticularsPopup:InitComponent()

    this.mask=Util.GetGameObject(self.gameObject,"mask")
    --头描述
    this.describe=Util.GetGameObject(self.gameObject,"describe")
    this.frame=Util.GetGameObject(this.describe,"frame")
    this.icon=Util.GetGameObject(this.describe,"frame/icon")
    this.name=Util.GetGameObject(this.describe,"name")
    this.quality=Util.GetGameObject(this.describe,"quality/text")
    this.type=Util.GetGameObject(this.describe,"type/text")
    this.level=Util.GetGameObject(this.describe,"level/text")
    --属性
    this.properties=Util.GetGameObject(self.gameObject,"properties")
    this.propertiesList={}
    for i = 1, 2 do
        table.insert(this.propertiesList,Util.GetGameObject(this.properties,"icon"..i))
    end
    --技能
    this.skill=Util.GetGameObject(self.gameObject,"skill")
    this.skillResultList={}
    for i = 1, 3 do
        table.insert(this.skillResultList,Util.GetGameObject(this.skill,"skill"..i))
    end
 
end

--绑定事件（用于子类重写）
function ToTemParticularsPopup:BindEvent()
    Util.AddClick(this.mask,function()
        self:ClosePanel()
    end)
    
end

--添加事件监听（用于子类重写）
function ToTemParticularsPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function ToTemParticularsPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function ToTemParticularsPopup:OnOpen(...)
    local args={...}
    this.itemId= args[1]
    this.totemData= args[2]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ToTemParticularsPopup:OnShow()
   
    ToTemParticularsPopup:SetData()
end
function ToTemParticularsPopup:OnSortingOrderChange()
end


--界面关闭时调用（用于子类重写）
function ToTemParticularsPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function ToTemParticularsPopup:OnDestroy()

end
function ToTemParticularsPopup:SetData()
    this.frame:GetComponent("Image").sprite=Util.LoadSprite( this.totemData.frame)
    this.icon:GetComponent("Image").sprite=Util.LoadSprite(this.totemData.icon)
    this.name:GetComponent("Text").text=GetLanguageStrById(this.totemData.name)
    this.quality:GetComponent("Text").text=this.totemData.quality
    this.level:GetComponent("Text").text=this.totemData.lv
    this.type:GetComponent("Text").text=this.totemData.itemConfig.ItemTypeDes

    --属性
    local arr= this.totemData.Totemconfig.Attr
    for i = 1, #this.propertiesList do
        local icon=this.propertiesList[i]
        local value=Util.GetGameObject(this.propertiesList[i],"value")
        local data=ConfigManager.GetConfigData("PropertyConfig",arr[i][1])
        icon:GetComponent("Image").sprite=Util.LoadSprite(data.Icon)
        value:GetComponent("Text").text=GetLanguageStrById(data.Info).."    "..GetProDataStr(arr[i][1],arr[i][2]) 

    end

    --技能
    local itemlist=ConfigManager.GetAllConfigsDataByKey("ExpeditionTotemTypeConfig","ItemId",this.itemId)
    for i = 1, #itemlist do
        local str=""
        if i<=this.totemData.step then
            str="<color=#0f0>%s</color>"
        else
            str="<color=#e0e0a0>%s</color>"
        end 
        local skillId= itemlist[i].SkillId
        local skill= Util.GetGameObject(this.skillResultList[i],"value")
        -- skill:GetComponent("Text").text=string.format(str,11) --GetSkillConfigDesc(skillConfig[skillId])--string.format(GetLanguageStrById(skillConfig[skillId].Desc[1])) --Todo
        skill:GetComponent("Text").text=string.format(str,GetLanguageStrById(GetSkillConfigDesc(skillConfig[skillId])))
        local hintLightImage= Util.GetGameObject(this.skillResultList[i],"hintLight/hintLightImage")
        hintLightImage:SetActive(i<=this.totemData.step)
    end

end


return ToTemParticularsPopup