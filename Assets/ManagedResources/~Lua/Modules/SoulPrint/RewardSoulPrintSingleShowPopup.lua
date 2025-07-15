require("Base/BasePanel")
RewardSoulPrintSingleShowPopup = Inherit(BasePanel)
local type
local sId
local dataItem
local func
local dataShow = {}
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
--初始化组件（用于子类重写）
function RewardSoulPrintSingleShowPopup:InitComponent()

    self.btnBack = Util.GetGameObject(self.transform, "Content/bg/btnBack")
    self.curEquipName = Util.GetGameObject(self.transform, "Content/bg/Text"):GetComponent("Text")
    self.curEquipDesc1 = Util.GetGameObject(self.transform, "Content/bg/armorInfo/infoText"):GetComponent("Text")
    self.curEquipFrame = Util.GetGameObject(self.transform, "Content/bg/armorInfo/frame"):GetComponent("Image")
    self.curEquipIcon = Util.GetGameObject(self.transform, "Content/bg/armorInfo/icon"):GetComponent("Image")
    self.qualityText = Util.GetGameObject(self.transform, "Content/bg/armorInfo/equipQuaText"):GetComponent("Text")
    self.powerNum1 = Util.GetGameObject(self.transform, "Content/bg/armorInfo/powerNum"):GetComponent("Text")
    self.level = Util.GetGameObject(self.transform, "Content/bg/armorInfo/resetLv"):GetComponent("Text")
    self.curMainProscroll = Util.GetGameObject(self.transform, "Content/mainProScroll")
    self.curMainProGrid = Util.GetGameObject(self.transform, "Content/mainProScroll/proGrid")
    self.otherProPre = Util.GetGameObject(self.transform, "Content/proPre")
    self.btnSure = Util.GetGameObject(self.transform, "Content/bg/btnSure")
    self.getTuGrid = Util.GetGameObject(self.transform, "Content/bg/scroll/grid")
    self.skillObject = Util.GetGameObject(self.transform, "Content/skillObject")
    self.skillInfo = Util.GetGameObject(self.transform, "Content/skillObject/skillInfo")
end

--绑定事件（用于子类重写）
function RewardSoulPrintSingleShowPopup:BindEvent()

    Util.AddClick(self.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(self.btnSure, function()
        local curResolveAllItemList = {}
        table.insert(curResolveAllItemList, sId)
        local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "isSoulPrintShowSure")
        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
        local haveHighQuality=false
        if(SoulPrintManager.soulPrintData[sId].quality>=4) then
            haveHighQuality=true
        end
        if (isPopUp ~= currentTime and haveHighQuality) then
            MsgPanel.ShowTwo(GetLanguageStrById(11941), nil, function(isShow)
                if (isShow) then
                    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                    RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "isSoulPrintShowSure", currentTime)
                end
                NetManager.UseAndPriceItemRequest(5, curResolveAllItemList, function(drop)
                    self:SendBackResolveReCallBack(drop)
                end)
            end, nil, nil, nil, true)
        else
            NetManager.UseAndPriceItemRequest(5, curResolveAllItemList, function(drop)
                self:SendBackResolveReCallBack(drop)
            end)
        end
    end)
end

--添加事件监听（用于子类重写）
function RewardSoulPrintSingleShowPopup:AddListener()

end

--移除事件监听（用于子类重写）
function RewardSoulPrintSingleShowPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RewardSoulPrintSingleShowPopup:OnOpen(_type, _sId, _func)
    type = _type
    sId = _sId
    func = _func
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RewardSoulPrintSingleShowPopup:OnShow()
    dataShow = BagManager.bagDatas[sId]
    if type == 1 then
        --for i, v in pairs(SoulPrintManager.GetBagShowData(SoulPrintManager.soulPrintData)) do
        --    if (v.did == dId) then
        --        dataShow = v
        --    end
        --end
        self.btnSure:SetActive(true)
    elseif type == 0 then
        --for i, v in pairs(SoulPrintManager.GetBagShowData(SoulPrintManager.soulPrintDataAll)) do
        --    if (v.did == dId) then
        --        dataShow = v
        --    end
        --end
        self.btnSure:SetActive(false)
    elseif type == 2 then
        --dataShow = SoulPrintManager.GetStaticBagShowData(dId, 1)
        self.btnSure:SetActive(false)
    end
    self.btnSure:SetActive(false)
    self:OnShowPanelData()
end
function RewardSoulPrintSingleShowPopup:OnShowPanelData()
    self.curEquipName.text = GetLanguageStrById(GetStringByEquipQua(dataShow.quality, dataShow.itemConfig.Name))
    self.curEquipDesc1.text = GetLanguageStrById(11942)
    self.curEquipFrame.sprite = Util.LoadSprite(GetQuantityImageByquality(dataShow.quality))
    self.curEquipIcon.sprite = Util.LoadSprite(dataShow.icon)
    self.qualityText.text = GetStringByEquipQua(dataShow.quality, GetQuaStringByEquipQua(dataShow.quality))
    --self.level.text = "+" .. dataShow.level
    if (type == 2) then
        self.powerNum1.text = SoulPrintManager.CalculateStaticSoulPrintAddVal(sId)
    else
        self.powerNum1.text = SoulPrintManager.CalculateSoulPrintAddVal(sId)
    end
    --主属性
    Util.ClearChild(self.curMainProGrid.transform)
    if equipConfig[dataShow.id].Property and #equipConfig[dataShow.id].Property > 0 then
        self.curMainProscroll:SetActive(true)
        for i = 1, #equipConfig[dataShow.id].Property do
            if equipConfig[dataShow.id].Property[i] and equipConfig[dataShow.id].Property[i][1] then
                local go = newObject(self.otherProPre)
                go.transform:SetParent(self.curMainProGrid.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero
                go:SetActive(true)
                local proConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, equipConfig[dataShow.id].Property[i][1])
                if proConFig then
                    Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text = proConFig.Info
                    Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text = "+" .. GetEquipPropertyFormatStr(proConFig.Style, equipConfig[dataShow.id].Property[i][2])
                end
            end
        end
    else
        self.curMainProscroll:SetActive(false)
    end

    --装备获得途径
    Util.ClearChild(self.getTuGrid.transform)
    local itemConfig = dataShow.itemConfig
    local curitemData = itemConfig
    if curitemData and curitemData.Jump then
        if curitemData.Jump and #curitemData.Jump > 0 then
            for i = 1, #curitemData.Jump do
                SubUIManager.Open(SubUIConfig.JumpView, self.getTuGrid.transform, curitemData.Jump[i])
            end
        end
    end

    local isShow = equipConfig[dataShow.id] and equipConfig[dataShow.id].PassiveSkill and true
    self.skillObject:SetActive(isShow)
    if isShow then
        local txt = ""
        for index, pid in ipairs(equipConfig[dataShow.id].PassiveSkill) do
            if index > 1 then
                txt = txt .. "，"
            end
            txt = txt .. ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, pid).Desc
        end
        self.skillInfo:GetComponent("Text").text = txt
    end
end
--道具 和 装备分解 发送请求后 回调
function RewardSoulPrintSingleShowPopup:SendBackResolveReCallBack(drop)
    local isShowReward = false
    if drop.itemlist ~= nil and #drop.itemlist > 0 then
        for i = 1, #drop.itemlist do
            if drop.itemlist[i].itemNum > 0 then
                isShowReward = true
                break
            end
        end
    end
    if isShowReward then
        UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function()
            BagManager.OnShowTipDropNumZero(drop)
        end)
    else
        BagManager.OnShowTipDropNumZero(drop)
    end
    SoulPrintManager.RemoveSoulPrint({ sId })
    if func then
        func()
        func = nil
    end
    self:ClosePanel()
end

--界面关闭时调用（用于子类重写）
function RewardSoulPrintSingleShowPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function RewardSoulPrintSingleShowPopup:OnDestroy()

end

return RewardSoulPrintSingleShowPopup