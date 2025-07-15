require("Base/BasePanel")
ToTemUpLvPopup = Inherit(BasePanel)
local this = ToTemUpLvPopup
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local type=1
local isUplv=false

--初始化组件（用于子类重写）
function ToTemUpLvPopup:InitComponent()

    this.title=Util.GetGameObject(self.gameObject,"title")
    --升级
    this.lvDescribe=Util.GetGameObject(self.gameObject,"lvDescribe")
    this.frame=Util.GetGameObject(this.lvDescribe,"frame")
    this.icon=Util.GetGameObject(this.lvDescribe,"frame/icon")
    this.name=Util.GetGameObject(this.lvDescribe,"name/text")
    this.quality=Util.GetGameObject(this.lvDescribe,"quality/text")
    this.level=Util.GetGameObject(this.lvDescribe,"level/text")

    --升阶
    this.advanceDescribe=Util.GetGameObject(self.gameObject,"advanceDescribe")

    this.frameLeft=Util.GetGameObject(this.advanceDescribe,"frameLeft")
    this.iconLeft=Util.GetGameObject(this.frameLeft,"icon")
    this.nameLeft=Util.GetGameObject(this.frameLeft,"name/text")
    this.qualityLeft=Util.GetGameObject(this.frameLeft,"quality/text")

    this.frameRight=Util.GetGameObject(this.advanceDescribe,"frameRight")
    this.iconRight=Util.GetGameObject(this.frameRight,"icon")
    this.nameRight=Util.GetGameObject(this.frameRight,"name/text")
    this.qualityRight=Util.GetGameObject(this.frameRight,"quality/text")


    --属性
    this.properties=Util.GetGameObject(self.gameObject,"properties")
    this.propertiesList={}
    for i = 1, 2 do
        table.insert(this.propertiesList,Util.GetGameObject(this.properties,"icon"..i))
    end

    --技能
    this.skillResult=Util.GetGameObject(self.gameObject,"skillResult")
    this.skillResultList={}
    for i = 1, 3 do
        table.insert(this.skillResultList,Util.GetGameObject(this.skillResult,"skill"..i))
    end
   

    --消耗
    this.costIcons=Util.GetGameObject(self.gameObject,"costIcons")
    this.costIcon1=Util.GetGameObject(this.costIcons,"item1/icon")
    this.costNum1=Util.GetGameObject(this.costIcons,"item1/num")
    this.costIcon2=Util.GetGameObject(this.costIcons,"item2/icon")
    this.costNum2=Util.GetGameObject(this.costIcons,"item2/num")

    --按钮
    this.btn1=Util.GetGameObject(self.gameObject,"btn1")
    this.downBtn=Util.GetGameObject(self.gameObject,"downBtn")
    this.changeBtn=Util.GetGameObject(self.gameObject,"changeBtn")
    this.upLvJumpBtn=Util.GetGameObject(self.gameObject,"upLvJumpBtn")
    this.upLvJumpBtnText=Util.GetGameObject(self.gameObject,"upLvJumpBtn/text")

    this.btn2=Util.GetGameObject(self.gameObject,"btn2")
    this.closeBtn=Util.GetGameObject(self.gameObject,"closeBtn")
    this.resetBtn=Util.GetGameObject(self.gameObject,"resetBtn")
    this.upLvBtn=Util.GetGameObject(self.gameObject,"upLvBtn")
    this.upLvBtnText=Util.GetGameObject(self.gameObject,"upLvBtn/text")

    this.backBtn=Util.GetGameObject(self.gameObject,"backBtn")

    
 
end

--绑定事件（用于子类重写）
function ToTemUpLvPopup:BindEvent()
    --卸下
    Util.AddClick(this.downBtn,function()
        NetManager.TotemUnloadRequest(this.heroData.dynamicId,function()
            TotemManager.DownTutemDataByHeroId(this.heroData.dynamicId)
            PopupTipPanel.ShowTipByLanguageId(23065)
            RoleInfoPanel.ShowHeroEquip()
            self:ClosePanel()
        end)
    end)
    --更换
    Util.AddClick(this.changeBtn,function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.ToTemListPopup, this.heroData)
    end)
    --升级面板
    Util.AddClick(this.upLvJumpBtn,function()
        this.btn1:SetActive(false)
        this.btn2:SetActive(true)
        isUplv=true
        ToTemUpLvPopup.UpdateUIData()
        ToTemUpLvPopup.SetData(type)
    end)
    
  
   
    --关闭
    Util.AddClick(this.closeBtn,function()
        isUplv=false
        self:ClosePanel()
    end)
    --重置
    Util.AddClick(this.resetBtn,function()

        local totemData=TotemManager.GetOneTotemData(TotemManager.GetTotemIdById(this.totemId))
        if totemData.lv<=1 then 
            PopupTipPanel.ShowTipByLanguageId(12505)
            return
        end 
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.TotemReset,
        totemData.Totemconfig.ResetObtain,this.heroData,this.totemId,this)
       
    end)
    --升级or升阶
    Util.AddClick(this.upLvBtn,function()

        for i = 1, #this.totemData.Totemconfig.UpgradeCost do
            local itemConfig=ConfigManager.GetConfigData("ItemConfig",this.totemData.Totemconfig.UpgradeCost[i][1])
           
            if BagManager.GetItemCountById(this.totemData.Totemconfig.UpgradeCost[i][1])<this.totemData.Totemconfig.UpgradeCost[i][2] then
                
                
                
                
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343),GetLanguageStrById(itemConfig.Name)))
                return
            end
        end

        
        
        
        
        NetManager.TotemLevelRequest(this.totemId,function()
            if type==1 then
                PopupTipPanel.ShowTipByLanguageId(11907)
            else
                PopupTipPanel.ShowTipByLanguageId(23131)
            end
            
            TotemManager.TotemUpLevel(this.totemId,this.heroData.dynamicId)
            this.totemId=this.totemId+1

            if type==2 then
                RoleInfoPanel.ShowHeroEquip()
            end

            ToTemUpLvPopup.UpdateUIData()
            ToTemUpLvPopup.SetData(type)
            
            
        end)
    end)
    

    --关闭
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ToTemUpLvPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function ToTemUpLvPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
--图腾Id 英雄数据
function ToTemUpLvPopup:OnOpen(...)
    local args={...}
    this.totemId=args[1]
    this.heroData=args[2]
  
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ToTemUpLvPopup:OnShow()
    ToTemUpLvPopup.UpdateData()
end

function ToTemUpLvPopup:OnSortingOrderChange()

end


--界面关闭时调用（用于子类重写）
function ToTemUpLvPopup:OnClose()
    RoleInfoPanel:UpdatePanelData()
end

--界面销毁时调用（用于子类重写）
function ToTemUpLvPopup:OnDestroy()

end

function ToTemUpLvPopup.UpdateData()
    isUplv=false
    this.btn1:SetActive(true)
    this.btn2:SetActive(false)
    ToTemUpLvPopup.UpdateUIData()
    ToTemUpLvPopup.SetData(type)
end


--更新界面信息
function ToTemUpLvPopup.UpdateUIData()
    this.itemId=TotemManager.GetTotemIdById(this.totemId)
    this.totemData=TotemManager.GetOneTotemData(this.itemId)
    local nextData=TotemManager.GetTotemById(this.totemData.nextId)
    --满级
    if nextData==nil then
    end
    if  nextData~=nil and this.totemData.step~=nextData.Step then
        type=2--升阶
        this.title:GetComponent("Text").text=GetLanguageStrById(50338)
        this.upLvJumpBtnText:GetComponent("Text").text=GetLanguageStrById(10452)
        this.upLvBtnText:GetComponent("Text").text=GetLanguageStrById(10452)
    else
        type=1--升级
        this.title:GetComponent("Text").text=GetLanguageStrById(50339)
        this.upLvJumpBtnText:GetComponent("Text").text=GetLanguageStrById(22293)
        this.upLvBtnText:GetComponent("Text").text=GetLanguageStrById(22293)
    end

    --升级最大值
    if this.totemData.nextId==0 or  this.totemData.nextId==nil or isUplv==false then
        this.upLvBtn:SetActive(false)
        for i = 1, #this.propertiesList do
            local changeImage=Util.GetGameObject(this.propertiesList[i],"change")
            local changeText=Util.GetGameObject(this.propertiesList[i],"changeText")
            changeImage:SetActive(false)
            changeText:SetActive(false)
        end
    else
        this.upLvBtn:SetActive(true)
        for i = 1, #this.propertiesList do
            local changeImage=Util.GetGameObject(this.propertiesList[i],"change")
            local changeText=Util.GetGameObject(this.propertiesList[i],"changeText")
            changeImage:SetActive(true)
            changeText:SetActive(true)
        end
    end

    --头部
    if type==1 then
        this.frame:GetComponent("Image").sprite=Util.LoadSprite( this.totemData.frame)
        this.icon:GetComponent("Image").sprite=Util.LoadSprite(this.totemData.icon)
        this.name:GetComponent("Text").text=GetLanguageStrById(this.totemData.name)
        this.quality:GetComponent("Text").text=this.totemData.quality
        this.level:GetComponent("Text").text=this.totemData.lv
        Util.AddClick(this.frame,function()
            UIManager.OpenPanel(UIName.ToTemParticularsPopup,this.itemId,this.totemData)
        end)
    else
        
        this.frameLeft:GetComponent("Image").sprite=Util.LoadSprite( this.totemData.frame)
        this.iconLeft:GetComponent("Image").sprite=Util.LoadSprite(this.totemData.icon)
        this.nameLeft:GetComponent("Text").text=GetLanguageStrById(this.totemData.name)
        this.qualityLeft:GetComponent("Text").text=this.totemData.quality

        local itemConfig=ConfigManager.GetConfigData("ItemConfig",nextData.ItemId)
        this.frameRight:GetComponent("Image").sprite=Util.LoadSprite(GetQuantityImageByquality(nextData.Color))
        this.iconRight:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
        
        this.nameRight:GetComponent("Text").text=GetLanguageStrById(itemConfig.Name)
        this.qualityRight:GetComponent("Text").text=TotemManager.GetTotemQualityById(nextData.Step)

      
    end
            
end

function ToTemUpLvPopup.SetData(type)--type  1:升级  2:升阶
    
    this.lvDescribe:SetActive(type==1)
    this.advanceDescribe:SetActive(type==2)

  
    --属性
    local arr= this.totemData.Totemconfig.Attr
    for i = 1, #this.propertiesList do
        local icon=this.propertiesList[i]
        local nameValue=Util.GetGameObject(this.propertiesList[i],"nameValue")
        local value=Util.GetGameObject(this.propertiesList[i],"value")
        local changeImage=Util.GetGameObject(this.propertiesList[i],"change")
        local changeText=Util.GetGameObject(this.propertiesList[i],"changeText")
        local data=ConfigManager.GetConfigData("PropertyConfig",arr[i][1])
        icon:GetComponent("Image").sprite=Util.LoadSprite(data.Icon)
        nameValue:GetComponent("Text").text=GetLanguageStrById(data.Info)
       
        local nextData
        if this.totemData.nextId==0 or  this.totemData.nextId==nil then
            nextData= ConfigManager.GetConfigData("ExpeditionTotemConfig",this.totemData.id)
        else
            nextData= ConfigManager.GetConfigData("ExpeditionTotemConfig",this.totemData.id+1)
        end
        value:GetComponent("Text").text=GetProDataStr(nextData.Attr[i][1],this.totemData.attr[nextData.Attr[i][1]]) 
        changeText:GetComponent("Text").text=GetProDataStr(nextData.Attr[i][1],nextData.Attr[i][2]) 

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
        local willGet= Util.GetGameObject(this.skillResultList[i],"willGet")
        willGet:SetActive(i==this.totemData.step+1)
    end

    --消耗
    if this.totemData.nextId==0 or  this.totemData.nextId==nil or isUplv==false then
        this.costIcons:SetActive(false)
    else
        this.costIcons:SetActive(true)
        for i = 1, #this.totemData.Totemconfig.UpgradeCost do
            local itemConfig=ConfigManager.GetConfigData("ItemConfig",this.totemData.Totemconfig.UpgradeCost[i][1])
    
            local costIcon=Util.GetGameObject(this.costIcons,"item"..i.."/icon")
            local costNum=Util.GetGameObject(this.costIcons,"item"..i.."/num")
    
            costIcon:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
            costNum:GetComponent("Text").text=string.format("%s/%s",BagManager.GetItemCountById(this.totemData.Totemconfig.UpgradeCost[i][1]),this.totemData.Totemconfig.UpgradeCost[i][2])
        end
    end
    
    
end



return ToTemUpLvPopup