require("Base/BasePanel")
WorkShopMaterialsCompoundPanel = Inherit(BasePanel)
local this = WorkShopMaterialsCompoundPanel
local materialPotPutNum=0--材料每次产出数量
local maxMaterialPotPutNum=99999999--材料最多产出数量
local curData
--初始化组件（用于子类重写）
function WorkShopMaterialsCompoundPanel:InitComponent()

    this.matName= Util.GetGameObject(self.transform, "bg/Text"):GetComponent("Text")
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.materialPre= Util.GetGameObject(self.transform, "materialPre")
    this.Grid= Util.GetGameObject(self.transform, "scroll/grid")
    this.Slider= Util.GetGameObject(self.transform, "Slider")
    this.expNum= Util.GetGameObject(self.transform, "Slider/expNum"):GetComponent("Text")
    this.allExpNum= Util.GetGameObject(self.transform, "allExpNum"):GetComponent("Text")
    this.btnSure = Util.GetGameObject(self.transform, "btnSure")
end

--绑定事件（用于子类重写）
function WorkShopMaterialsCompoundPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddSlider(this.Slider, function(go, value)
        self:UpdatePanelData(value)
    end)
    Util.AddClick(this.btnSure, function()
        if materialPotPutNum<=0 then
            PopupTipPanel.ShowTipByLanguageId(11880)
            return
        end
        NetManager.GetWorkBaseRequest(curData.Id,materialPotPutNum,function()
            self:ClosePanel()
            self.DeleteWorkShopMaterials()
            end)
    end)
end

--添加事件监听（用于子类重写）
function WorkShopMaterialsCompoundPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopMaterialsCompoundPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopMaterialsCompoundPanel:OnOpen(...)

    local data={...}
    curData=data[1]
    maxMaterialPotPutNum=99999999
    this.matName.text=ConfigManager.GetConfigData(ConfigName.ItemConfig, curData.Id).Name
    Util.ClearChild(this.Grid.transform)
    for i = 1, #curData.Cost do
        local go=newObject(this.materialPre)
        go.transform:SetParent(this.Grid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition=Vector3.zero;
        go:SetActive(true)
        local itemConfigData= ConfigManager.GetConfigData(ConfigName.ItemConfig, curData.Cost[i][1])
        Util.GetGameObject(go.transform,"icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
        Util.GetGameObject(go.transform,"frame"):GetComponent("Image").sprite=Util.LoadSprite(GetQuantityImageByquality(itemConfigData.Quality))
        Util.GetGameObject(go.transform,"name/Text"):GetComponent("Text").text=GetLanguageStrById(itemConfigData.Name)
        Util.GetGameObject(go.transform,"numText"):GetComponent("Text").text=BagManager.GetItemCountById(curData.Cost[i][1]).."/"..curData.Cost[i][2]
        --Util.AddClick(go, function()
        --    this:OnClickTabBtn(_proTypeId,i)
        --end)
        local curOutPutNum=BagManager.GetItemCountById(curData.Cost[i][1])/curData.Cost[i][2]
        curOutPutNum=math.floor(curOutPutNum)
        if curOutPutNum <maxMaterialPotPutNum then
            maxMaterialPotPutNum=curOutPutNum
        end
    end

    materialPotPutNum=1
    this.Slider:GetComponent("Slider").value=materialPotPutNum
    materialPotPutNum= materialPotPutNum>=maxMaterialPotPutNum and maxMaterialPotPutNum or materialPotPutNum
    this.Slider:GetComponent("Slider").maxValue=maxMaterialPotPutNum
    this.Slider:GetComponent("Slider").minValue=0
    self:UpdatePanelData(materialPotPutNum)
end
function WorkShopMaterialsCompoundPanel:UpdatePanelData(value)--curData
    materialPotPutNum=value
    this.expNum.text= value*curData.Num
    this.allExpNum.text=GetLanguageStrById(12033)..curData.Exp*value
end

--界面关闭时调用（用于子类重写）
function WorkShopMaterialsCompoundPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function WorkShopMaterialsCompoundPanel:OnDestroy()

end
--扣除升星 消耗的材料  更新英雄数据
function WorkShopMaterialsCompoundPanel:DeleteWorkShopMaterials()
    --打开基础工坊成功界面
    local awardData={}
    local curItemConfigData= ConfigManager.GetConfigData(ConfigName.ItemConfig, curData.Id)
    awardData.name=curItemConfigData.Name
    awardData.icon=GetResourcePath(curItemConfigData.ResourceID)
    awardData.frame=GetQuantityImageByquality(curItemConfigData.Quality)
    awardData.expNum=curData.Exp*materialPotPutNum
    awardData.num=materialPotPutNum*curData.Num
    UIManager.OpenPanel(UIName.WorkShopAwardPanel,awardData)
    --新增生成数据
    --local itemData={}
    --itemData.itemId=curData.Id
    --itemData.itemNum=materialPotPutNum*curData.Num
    --BagManager.UpdateBagData(itemData)
    --删除消耗数据
    --for i = 1, #curData.Cost do
    --    BagManager.UpdateItemsNum(curData.Cost[i][1],curData.Cost[i][2]*materialPotPutNum)
    --end
    --更新工坊等级经验
    --WorkShopManager.UpdataWorkShopLvAndExp(curData.Exp*materialPotPutNum)
end
return WorkShopMaterialsCompoundPanel