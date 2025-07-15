require("Base/BasePanel")
WorkShopArmorTwoPanel = Inherit(BasePanel)
local this=WorkShopArmorTwoPanel
local curWorkShopData
local curEquipData
local curEquipItemData
local openThisPanel
local type
local curSelectPosData--当前符文选择的数据
local selectAllPosData={}--所有选择的符文数据
local isMaterial
local mineralItemData--第一个材料
local meadNum

--需要的材料组
local materialGoList = {}
local materialNeedNumList = {}

this.skillConfig=ConfigManager.GetConfig(ConfigName.SkillConfig)
--初始化组件（用于子类重写）
function WorkShopArmorTwoPanel:InitComponent()

    this.equipName = Util.GetGameObject(self.transform, "Content/bg/Text"):GetComponent("Text")
    this.BtnBack = Util.GetGameObject(self.transform, "Content/bg/btnBack")
    this.icon = Util.GetGameObject(self.transform, "Content/bg/armorInfo/icon"):GetComponent("Image")
    this.frame = Util.GetGameObject(self.transform, "Content/bg/armorInfo/frame"):GetComponent("Image")

    this.equipType=Util.GetGameObject(self.transform, "Content/bg/armorInfo/grid/equipType"):GetComponent("Text")
    this.equipPos=Util.GetGameObject(self.transform, "Content/bg/armorInfo/grid/equipPos"):GetComponent("Text")
    this.equipRebuildLv=Util.GetGameObject(self.transform, "Content/bg/armorInfo/grid/equipRebuildLv")
    this.equipQuaText=Util.GetGameObject(self.transform, "Content/bg/armorInfo/equipQuaText"):GetComponent("Text")
    this.equipInfoText=Util.GetGameObject(self.transform, "Content/bg/armorInfo/equipInfoText"):GetComponent("Text")
    this.powerNum=Util.GetGameObject(self.transform, "Content/bg/armorInfo/powerNum"):GetComponent("Text")

    this.materialPre=Util.GetGameObject(self.transform, "Content/bg/materialPre")
    this.materialGrid=Util.GetGameObject(self.transform, "Content/bg/scroll/materialGrid")

    this.mainPro=Util.GetGameObject(self.transform, "Content/mainPro")
    this.mainProName=Util.GetGameObject(self.transform, "Content/mainPro/proName"):GetComponent("Text")
    this.mainProVale=Util.GetGameObject(self.transform, "Content/mainPro/proVale"):GetComponent("Text")
    this.otherPro=Util.GetGameObject(self.transform, "Content/otherPro")
    this.otherProGrid=Util.GetGameObject(self.transform, "Content/scroll/grid")
    --装备被动技能
    this.skillObject=Util.GetGameObject(self.transform, "Content/skillObject")
    this.skillInfo=Util.GetGameObject(self.transform, "Content/skillObject/skillInfo"):GetComponent("Text")
    this.tsText=Util.GetGameObject(self.transform, "Content/tishiText")
    --this.addExp=Util.GetGameObject(self.transform, "addExp"):GetComponent("Text")
    this.btnSure = Util.GetGameObject(self.transform, "Content/bg/btnSure")
    this.Slider= Util.GetGameObject(self.transform, "Content/bg/Slider")
    this.numText= Util.GetGameObject(self.transform, "Content/bg/Slider/numText"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function WorkShopArmorTwoPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnSure, function()
        isMaterial = this.GetMaterialIsHave()
        if isMaterial ==2 then
            PopupTipPanel.ShowTipByLanguageId(11880)
        else
            if meadNum>0 then
                NetManager.GetWorkShopEquipCreateRequest(curWorkShopData.Id,selectAllPosData,meadNum,function (_aomorData)
                    this.OpenNextPanelData(_aomorData)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(12026)
            end
        end
    end)
    Util.AddSlider(this.Slider, function(go, value)
        this.ShowMopUpInfoData(value)
    end)
end

--添加事件监听（用于子类重写）
function WorkShopArmorTwoPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopArmorTwoPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopArmorTwoPanel:OnOpen(...)

    isMaterial=2
    curSelectPosData={}
    local data={...}
    curWorkShopData=data[1]
    type=data[2]
    openThisPanel=data[3]

end
function WorkShopArmorTwoPanel:OnShow()
    this.tsText:SetActive(true)
    this.mainPro:SetActive(false)
    --this.skillObject:SetActive(false)
    curEquipItemData=ConfigManager.GetConfigData(ConfigName.ItemConfig, curWorkShopData.Id)
    curEquipData=ConfigManager.GetConfigData(ConfigName.EquipConfig, curWorkShopData.Id)
    this.equipQuaText.text=GetStringByEquipQua(curEquipData.Quality,GetQuaStringByEquipQua(curEquipData.Quality))
    this.equipName.text=GetStringByEquipQua(curEquipData.Quality,curEquipItemData.Name)
    this.icon.sprite=Util.LoadSprite(GetResourcePath(curEquipItemData.ResourceID))
    this.frame.sprite=Util.LoadSprite(GetQuantityImageByquality(curEquipData.Quality))
    this.equipInfoText.text=curWorkShopData.ShortDesc--curEquipItemData.ItemDescribe
    if curEquipData.IfClear==0 then
        this.equipRebuildLv:GetComponent("Text").text=GetLanguageStrById(11557)
    elseif curEquipData.IfClear==1 then
        this.equipRebuildLv:GetComponent("Text").text=GetLanguageStrById(12027)..curEquipData.InitialLevel
    end
    --this.powerNum.text=EquipManager.CalculateWarForce(equipData.id)
    if curEquipData.SkillPoolId and #curEquipData.SkillPoolId > 0 then
        local pollConfig = ConfigManager.GetConfigDataByKey(ConfigName.PassiveSkillLogicConfig, "PoolNum", curEquipData.SkillPoolId[1])
        local passiveCfg
        if pollConfig then
            passiveCfg =  ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, pollConfig.Id)
        end
        if passiveCfg then
            this.skillObject:SetActive(true)
            this.skillInfo.text=GetSkillConfigDesc(passiveCfg)
        else
            this.skillObject:SetActive(false)
        end
    else
        this.skillObject:SetActive(false)
    end
    this.equipType.text=GetLanguageStrById(11093)..GetEquipPosStrByEquipPosNum(curEquipData.Position)
    this.equipPos.text=string.format(GetLanguageStrById(11094),GetJobStrByJobNum(curEquipData.ProfessionLimit))
    --this.addExp.text="工坊经验值+"..curWorkShopData.Exp
    Util.ClearChild(this.materialGrid.transform)
    materialGoList = {}
    materialNeedNumList = {}
    --第一个材料
    mineralItemData=ConfigManager.GetConfigData(ConfigName.ItemConfig, curWorkShopData.Mineral[1])
    local go=newObject(this.materialPre)
    go.transform:SetParent(this.materialGrid.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition=Vector3.zero;
    go:SetActive(true)
    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite =Util.LoadSprite(GetResourcePath(mineralItemData.ResourceID))
    Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(mineralItemData.Quantity))
    Util.GetGameObject(go.transform, "add"):SetActive(false)
    Util.GetGameObject(go.transform, "name/Text"):GetComponent("Text").text = mineralItemData.Name
    table.insert(materialGoList,go)
    table.insert(materialNeedNumList ,curWorkShopData.Mineral[2])

    if BagManager.GetItemCountById(mineralItemData.Id)<curWorkShopData.Mineral[2] then
        Util.GetGameObject(go.transform, "numText"):GetComponent("Text").text = string.format("<color=#FF0000FF>%s/%s</color>",BagManager.GetItemCountById(mineralItemData.Id),curWorkShopData.Mineral[2])
    else
        Util.GetGameObject(go.transform, "numText"):GetComponent("Text").text = string.format("<color=#546D74FF>%s/%s</color>",BagManager.GetItemCountById(mineralItemData.Id),curWorkShopData.Mineral[2])
    end

    selectAllPosData={}
    for i = 1, curWorkShopData.RunesNum do
        selectAllPosData[i]=0
        local go=newObject(this.materialPre)
        go.transform:SetParent(this.materialGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition=Vector3.zero;
        go:SetActive(true)
        local addBtn=Util.GetGameObject(go.transform, "add")
        Util.GetGameObject(addBtn.transform, "add/add"):SetActive(true)
        Util.GetGameObject(go.transform, "icon"):SetActive(false)
        Util.GetGameObject(go.transform, "name/Text"):GetComponent("Text").text =GetLanguageStrById(12028)
        Util.GetGameObject(go.transform, "numText"):GetComponent("Text").text = GetLanguageStrById(12029)
        table.insert(materialGoList,go)
        table.insert(materialNeedNumList ,1)
        local quality = ConfigManager.GetConfigData(ConfigName.EquipConfig, curWorkShopData.Id).Quality
        Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(quality))
        Util.AddOnceClick(addBtn, function()
           
            if #BagManager.GetBagItemDataByQuDownAll(6,quality)>0 then
                UIManager.OpenPanel(UIName.WorkShopRuneListPanel,quality,this,nil)
                curSelectPosData.go=go
                curSelectPosData.index=i
            else
                PopupTipPanel.ShowTipByLanguageId(12030)
            end
        end)
    end
    this.SetSliderVal()
    this.UpdatePosFuwenData()
end
function this.UpdatePosFuwenData(_fuwenData)
    if _fuwenData==nil then
        --Util.ClearChild(this.otherProGrid.transform)
        return
    end
    --检测一下背包数量是否满足
    local linshiselectAllPosData={}
    for i = 1, #selectAllPosData do
        linshiselectAllPosData[i]=selectAllPosData[i]
    end
    linshiselectAllPosData[curSelectPosData.index]=_fuwenData.id
    local num=1
    for i = 1, #linshiselectAllPosData do
        if i+1<=#linshiselectAllPosData then
            if linshiselectAllPosData[i]==linshiselectAllPosData[i+1] then
                num=num+1
            end
        end
    end
    if BagManager.GetItemCountById(_fuwenData.id)<num then
        PopupTipPanel.ShowTipByLanguageId(11880)
        return
    end
    curSelectPosData.data=_fuwenData
    selectAllPosData[curSelectPosData.index]=_fuwenData.id
    if curSelectPosData.go then
        local addBtn=Util.GetGameObject(curSelectPosData.go.transform, "add")
        Util.GetGameObject(addBtn.transform, "add/add"):SetActive(false)
        Util.GetGameObject(curSelectPosData.go.transform, "icon"):SetActive(true)
        Util.GetGameObject(curSelectPosData.go.transform, "icon"):GetComponent("Image").sprite =Util.LoadSprite(GetResourcePath(_fuwenData.itemConfig.ResourceID))
        Util.GetGameObject(curSelectPosData.go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(_fuwenData.frame)
        Util.GetGameObject(curSelectPosData.go.transform, "name/Text"):GetComponent("Text").text =_fuwenData.itemConfig.Name
        Util.GetGameObject(curSelectPosData.go.transform, "numText"):GetComponent("Text").text = BagManager.GetItemCountById(_fuwenData.id).."/1"
    end
    this.UdataShowProList()
end
function this.UdataShowProList()
    this.tsText:SetActive(true)
    this.mainPro:SetActive(false)
    --this.skillObject:SetActive(false)
    for i = 1, #selectAllPosData do
        if selectAllPosData[i] >0 then
            this.tsText:SetActive(false)
            this.mainPro:SetActive(true)
            break
        end
    end
    Util.GetGameObject(this.mainPro, "proName"):GetComponent("Text").text=ConfigManager.GetConfigData(ConfigName.PropertyConfig, curEquipData.PropertyMin[1]).Info
    --基础值+基础值*工坊等级对应提高的百分百
    local addProVal = WorkShopManager.WorkShopData.LvAddMainIdAndVales[curEquipData.PropertyMin[1]]
    if addProVal then
        Util.GetGameObject(this.mainPro, "proVale"):GetComponent("Text").text=math.floor(curEquipData.PropertyMin[2]+(curEquipData.PropertyMin[2]*addProVal/100)).."-"..math.floor(curEquipData.PropertyMax[2]+(curEquipData.PropertyMax[2]*addProVal/100))
    else
        Util.GetGameObject(this.mainPro, "proVale"):GetComponent("Text").text=curEquipData.PropertyMin[2].."-"..curEquipData.PropertyMax[2]
    end
    --计算符文加的固定属性
    local otherProList={}
    local randomMinNum=0
    local randomMaxNum=0
    for i = 1, #selectAllPosData do
        if selectAllPosData[i] >0 then
            local reunesConfigData=ConfigManager.GetConfigData(ConfigName.RunesConfig, selectAllPosData[i])
            if reunesConfigData then
                if reunesConfigData.MainPool then
                    for k, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.RunesPoolConfig)) do
                        if v.PoolNum==reunesConfigData.MainPool then
                            if otherProList[i] then
                                otherProList[i].min=otherProList[i].min+v.Min
                                otherProList[i].max=otherProList[i].max+v.Max
                            else
                                local curOtherProData={}
                                curOtherProData.id=v.PropertyId
                                curOtherProData.min=v.Min
                                curOtherProData.max=v.Max
                                otherProList[i]=curOtherProData
                            end
                        end
                    end
                end
                ----计算符文加的随机属性
                if reunesConfigData.SecondNumMin and reunesConfigData.SecondNumMax then
                    randomMinNum=randomMinNum+reunesConfigData.SecondNumMin
                    randomMaxNum=randomMaxNum+reunesConfigData.SecondNumMax
                end
            end
        end
    end


    Util.ClearChild(this.otherProGrid.transform)
    for i, v in pairs(otherProList) do
        local go = newObject(this.otherPro)
        go.transform:SetParent(this.otherProGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)
        Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text = ConfigManager.GetConfigData(ConfigName.PropertyConfig, v.id).Info
        local proType=ConfigManager.GetConfigData(ConfigName.PropertyConfig, v.id).Style
        Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text = GetPropertyFormatStr(proType,v.min).."-"..GetPropertyFormatStr(proType,v.max)
    end
    if randomMaxNum>0 then
        local go = newObject(this.otherPro)
        go.transform:SetParent(this.otherProGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)
        Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text = GetLanguageStrById(12031)
        Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text = randomMinNum.."-"..randomMaxNum
    end
    this.SetSliderVal()
end
function this.OpenNextPanelData(_armorDataOrDrop)
local curArmorData
    if meadNum>1 then
        UIManager.OpenPanel(UIName.RewardItemPopup,_armorDataOrDrop,1)
        for i = 1, meadNum do
            
            --WorkShopManager.UpdataWorkShopLvAndExp(curWorkShopData.Exp)
        end
    else
        curArmorData=EquipManager.GetSingleEquipData(_armorDataOrDrop.id)--装备
        UIManager.OpenPanel(UIName.WorkShopMadeSuccessPanel,curArmorData)
    end
    --新增生成数据 已在netManager 處理
    --删除消耗数据
    --for i = 1, #selectAllPosData do
    --    BagManager.UpdateItemsNum(selectAllPosData[i],meadNum)
    --end
    --BagManager.UpdateItemsNum(mineralItemData.Id,curWorkShopData.Mineral[2]*meadNum)
    selectAllPosData={}
    this:ClosePanel()
end
function this.SetSliderVal()
    local num=ConfigManager.GetConfigData(ConfigName.GameSetting, 1).EquipCompoundLimit
    isMaterial = this.GetMaterialIsHave()
    if isMaterial ==2 then
        num=0
    else
        --检测符文数量
        local same=false--两个栏里是否一样
        for i = 1, #selectAllPosData do
            if i+1 <=#selectAllPosData then
                if selectAllPosData[i]==selectAllPosData[i+1] then
                    same=true
                end
            end
        end
        if same then
            if selectAllPosData[1] then
                if num> math.floor(BagManager.GetItemCountById(selectAllPosData[1])/2) then
                    num=math.floor(BagManager.GetItemCountById(selectAllPosData[1])/2)
                end
            end
        else
            for i = 1, #selectAllPosData do
                if num> BagManager.GetItemCountById(selectAllPosData[i]) then
                    num=BagManager.GetItemCountById(selectAllPosData[i])
                end
            end
        end
    end
--检测消耗材料
   local matialNum = math.floor(BagManager.GetItemCountById(mineralItemData.Id)/curWorkShopData.Mineral[2])
    if num>matialNum then
        num=matialNum
    end
    this.Slider:GetComponent("Slider").maxValue=num
    this.Slider:GetComponent("Slider").minValue=0
    local curNum=num>0 and 1 or 0
     this.ShowMopUpInfoData(curNum)
    this.Slider:GetComponent("Slider").value=curNum
end
function this.ShowMopUpInfoData(value)
    this.numText.text= value
    meadNum=value
    if materialNeedNumList and #materialNeedNumList > 0 and materialGoList and #materialGoList > 0 and value > 0 then
        local contentsList = {}
        for i = 1, #materialGoList do
            local textStr = Util.GetGameObject(materialGoList[i].transform, "numText"):GetComponent("Text").text
            table.insert(contentsList,string.split(textStr, "/")[1])
        end
        for i = 1, #materialGoList do
            if i == 1 then
                Util.GetGameObject(materialGoList[i].transform, "numText"):GetComponent("Text").text = contentsList[i].."/"..materialNeedNumList[i]*value.."</color>"
            else
                Util.GetGameObject(materialGoList[i].transform, "numText"):GetComponent("Text").text = contentsList[i].."/"..materialNeedNumList[i]*value
            end
        end
    end
end
--检测消耗的道具是否满足
function this.GetMaterialIsHave()
    if BagManager.GetItemCountById(mineralItemData.Id)<curWorkShopData.Mineral[2] then
        isMaterial=2
    else
        isMaterial=1
    end
    if isMaterial==1 then
        for i = 1, #selectAllPosData do
            if selectAllPosData[i]<=0 then
                isMaterial=2
            end
        end
    end
    return isMaterial
end
--界面关闭时调用（用于子类重写）
function WorkShopArmorTwoPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function WorkShopArmorTwoPanel:OnDestroy()

end
function WorkShopArmorTwoPanel:GetEquipSkillData(skillId)
    return this.skillConfig[skillId]
end
return WorkShopArmorTwoPanel