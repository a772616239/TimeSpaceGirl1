require("Base/BasePanel")
WorkShopArmorOnePanel = Inherit(BasePanel)
local this=WorkShopArmorOnePanel
local openThisPanel
local itemNu=0
local openPanelType
local btnType
local workShopDataId
local itemConfigData
local equipConfigData
local workShopData
local func
--初始化组件（用于子类重写）
function WorkShopArmorOnePanel:InitComponent()

    this.equipName = Util.GetGameObject(self.transform, "Content/bg/Text"):GetComponent("Text")
    this.BtnBack = Util.GetGameObject(self.transform, "Content/bg/btnBack")
    --蓝图详情
    this.icon = Util.GetGameObject(self.transform, "Content/bg/armorInfo/icon"):GetComponent("Image")
    this.frame = Util.GetGameObject(self.transform, "Content/bg/armorInfo/frame"):GetComponent("Image")
    this.equipType=Util.GetGameObject(self.transform, "Content/bg/armorInfo/grid/equipType"):GetComponent("Text")
    this.haveNum=Util.GetGameObject(self.transform, "Content/bg/armorInfo/grid/haveNum"):GetComponent("Text")
    this.equipQuaText=Util.GetGameObject(self.transform, "Content/bg/armorInfo/equipQuaText"):GetComponent("Text")
    this.equipInfoText=Util.GetGameObject(self.transform, "Content/bg/armorInfo/equipInfoText"):GetComponent("Text")
    --装备属性
    this.mainProName=Util.GetGameObject(self.transform, "Content/bg/mainPro/proName"):GetComponent("Text")
    this.mainProVale=Util.GetGameObject(self.transform, "Content/bg/mainPro/proVale"):GetComponent("Text")
    this.skillObject=Util.GetGameObject(self.transform, "Content/skillObject")
    this.skillInfo=Util.GetGameObject(self.transform, "Content/skillObject/skillInfo"):GetComponent("Text")
    --装备获取途径
    this.getTuPre=Util.GetGameObject(self.transform, "Content/bg/getTuPre")
    this.getTuGrid=Util.GetGameObject(self.transform, "Content/bg/scroll/grid")
    --解锁蓝图按钮
    this.btnSure = Util.GetGameObject(self.transform, "Content/bg/btnSure")
    this.btnSureText = Util.GetGameObject(self.transform, "Content/bg/btnSure/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function WorkShopArmorOnePanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.btnSure, function()
        if openPanelType==1 then
            if itemNu>0 then
                NetManager.GetWorkShopAvtiveLanTuRequest(workShopDataId,2,function()
                    --刷新工坊解锁蓝图数据
                    if openThisPanel then
                        openThisPanel.DeleteActiveLanTuData()
                    end
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10060)
            end
            self:ClosePanel()
        else
            if btnType ==1 then--背包解锁蓝图
                NetManager.GetWorkShopAvtiveLanTuRequest(workShopDataId, 2, function()
                    --刷新工坊解锁蓝图数据
                    this.DeleteActiveLanTuData()
                end)
            else--背包分解蓝图
                local _itemData = BagManager.bagDatas[itemConfigData.Id]
                UIManager.OpenPanel(UIName.BagResolveAnCompoundPanel, 3, _itemData, function()
                    if func then
                        func()
                    end
                end)
            end
        end
    end)
end

--添加事件监听（用于子类重写）
function WorkShopArmorOnePanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopArmorOnePanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopArmorOnePanel:OnOpen(...)

    --1 打开界面类型（1 工坊 2 背包 3 itemView）
    --2 解锁还是分解（1 解锁 2 分解 3 查看）
    --3 数据（WorkShop条目静态id）
    --4 打开的界面（）
    --5 回调
    local data={...}
    openPanelType=data[1]
    btnType=data[2]
    workShopDataId=data[3]
    openThisPanel=data[4]
    func=data[5]
    if btnType==1 then
        this.btnSureText.text=GetLanguageStrById(12024)
    elseif btnType==2 then
        this.btnSureText.text=GetLanguageStrById(10214)
    end
    this.btnSure:SetActive(btnType ~= 3)
    --装备基础信息
    equipConfigData=ConfigManager.GetConfigData(ConfigName.EquipConfig, workShopDataId)
    --工坊基础信息
    workShopData=ConfigManager.GetConfigData(ConfigName.WorkShopEquipmentConfig, workShopDataId)
    --蓝图基础信息
    itemConfigData=ConfigManager.GetConfigData(ConfigName.ItemConfig, workShopData.OpenRules[2])


    itemNu=0
    itemNu=BagManager.GetItemCountById(itemConfigData.Id)
    this.equipName.text=GetStringByEquipQua(itemConfigData.Quantity,itemConfigData.Name)
    this.equipQuaText.text=GetStringByEquipQua(itemConfigData.Quantity,GetQuaStringByEquipQua(itemConfigData.Quantity))
    this.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfigData.Quantity))
    this.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    this.equipInfoText.text=itemConfigData.ItemDescribe
    this.equipType.text=GetLanguageStrById(11594)
    this.haveNum.text=GetLanguageStrById(12025)..itemNu
    --装备属性
    this.mainProName.text=ConfigManager.GetConfigData(ConfigName.PropertyConfig, equipConfigData.PropertyMin[1]).Info
    this.mainProVale.text="【"..equipConfigData.PropertyMin[2].."-"..equipConfigData.PropertyMax[2].."】"


    if equipConfigData.SkillPoolId and #equipConfigData.SkillPoolId > 0 then
        local pollConfig = ConfigManager.GetConfigDataByKey(ConfigName.PassiveSkillLogicConfig, "PoolNum", equipConfigData.SkillPoolId[1])
        local passiveCfg
        if pollConfig then
            passiveCfg = ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, pollConfig.Id)
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

    --装备获得途径
    Util.ClearChild(this.getTuGrid.transform)
   local curitemData = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemConfigData.Id)
    if curitemData and curitemData.Jump then
        if curitemData.Jump and #curitemData.Jump>0 then
            for i = 1, #curitemData.Jump do
                SubUIManager.Open(SubUIConfig.JumpView, this.getTuGrid.transform, curitemData.Jump[i])
            end
        end
    end
end

--扣除解锁蓝图材料 并数据
function this.DeleteActiveLanTuData()
    PopupTipPanel.ShowTip(GetLanguageStrById(11593) .. GetLanguageStrById(itemConfigData.Name))
    if workShopDataId > 0 then
        WorkShopManager.UpdataWorkShopLanTuActiveState(2, workShopDataId, itemConfigData.Id)--
    end
    --if itemConfigData then
    --    BagManager.UpdateItemsNum(itemConfigData.Id, 1)
    --end
    if func then
        func()
    end
    this:ClosePanel()
end
--界面关闭时调用（用于子类重写）
function WorkShopArmorOnePanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function WorkShopArmorOnePanel:OnDestroy()

end

return WorkShopArmorOnePanel