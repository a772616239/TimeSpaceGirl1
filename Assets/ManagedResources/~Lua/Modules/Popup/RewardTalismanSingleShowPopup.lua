require("Base/BasePanel")
RewardTalismanSingleShowPopup = Inherit(BasePanel)
local type
local dId
local sId
local lv
local refineLv
local func
local itemConfig = {}
--初始化组件（用于子类重写）
function RewardTalismanSingleShowPopup:InitComponent()

    self.BackMask= Util.GetGameObject(self.transform, "BackMask")

    self.curEquipName=Util.GetGameObject(self.transform, "Content/bg/armorInfo/Text"):GetComponent("Text")
    self.curEquipDesc1= Util.GetGameObject(self.transform, "Content/info/infoText"):GetComponent("Text")
    self.curEquipFrame=Util.GetGameObject(self.transform, "Content/bg/armorInfo/frame"):GetComponent("Image")
    self.curEquipIcon=Util.GetGameObject(self.transform, "Content/bg/armorInfo/icon"):GetComponent("Image")
    self.proIcon=Util.GetGameObject(self.transform, "Content/bg/armorInfo/proIcon"):GetComponent("Image")
    self.qualityText=Util.GetGameObject(self.transform, "Content/bg/armorInfo/equipQuaText"):GetComponent("Text")
    self.powerNum1=Util.GetGameObject(self.transform, "Content/bg/armorInfo/powerNum"):GetComponent("Text")
    self.lv=Util.GetGameObject(self.transform, "Content/bg/armorInfo/lv"):GetComponent("Text")
    self.refineLv=Util.GetGameObject(self.transform, "Content/bg/armorInfo/refineLv"):GetComponent("Text")

    self.curMainProscroll=Util.GetGameObject(self.transform, "Content/mainProScroll")
    self.curMainProGrid=Util.GetGameObject(self.transform, "Content/mainProScroll/mainproGrid") --m5
    self.curotherProscroll=Util.GetGameObject(self.transform, "Content/otherProScroll")
    self.otherProPre=Util.GetGameObject(self.transform, "Content/proPre")
    self.otherProGrid=Util.GetGameObject(self.transform, "Content/otherProScroll/otherproGrid") --m5
    self.curCastInfo=Util.GetGameObject(self.transform, "Content/skillObject/skillInfo"):GetComponent("Text")
    self.castInfoObject=Util.GetGameObject(self.transform, "Content/skillObject")
    self.castInfoObject:SetActive(false)
    self.btnSure=Util.GetGameObject(self.transform, "Content/btnGrid/btnSure") --m5
    self.btnJump=Util.GetGameObject(self.transform, "Content/btnGrid/btnJump") --m5

    --装备获取途径
    --this.getTuPre=Util.GetGameObject(self.transform, "Content/bg/getTuPre")
    self.getTuGrid=Util.GetGameObject(self.transform, "Content/scroll/grid") --m5
end

--绑定事件（用于子类重写）
function RewardTalismanSingleShowPopup:BindEvent()

    Util.AddClick(self.BackMask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(self.btnJump, function()
        if itemConfig then
            JumpManager.GoJump(itemConfig.UseJump)
        end
    end)
    Util.AddClick(self.btnSure, function()
        local curResolveAllItemList={}
        table.insert(curResolveAllItemList,dId)
        local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "isTalismanShowSure")
        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
        local haveHighQuality=false
        local data = TalismanManager.GetSingleTalismanData(dId)
        local itemConfig = data.itemConfig
        if(itemConfig.Quantity>=4) then
            haveHighQuality=true
        end
        if (isPopUp ~= currentTime and haveHighQuality) then
            MsgPanel.ShowTwo(GetLanguageStrById(11596), nil, function(isShow)
                if (isShow) then
                    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                    RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "isTalismanShowSure", currentTime)
                end
                NetManager.UseAndPriceItemRequest(4,curResolveAllItemList,function (drop)
                    self:SendBackResolveReCallBack(drop)
                end)
            end, nil, nil, nil, true)
        else
            NetManager.UseAndPriceItemRequest(4,curResolveAllItemList,function (drop)
                self:SendBackResolveReCallBack(drop)
            end)
        end

    end)
end

--添加事件监听（用于子类重写）
function RewardTalismanSingleShowPopup:AddListener()

end

--移除事件监听（用于子类重写）
function RewardTalismanSingleShowPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RewardTalismanSingleShowPopup:OnOpen(_type,_did,_sId,_lv,_refineLv,_func)

    type = _type
    dId = _did
    sId = _sId
    lv = _lv
    refineLv = _refineLv
    func = _func
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RewardTalismanSingleShowPopup:OnShow()

    if type == 1 then
        self.btnSure:SetActive(true)
    else
        self.btnSure:SetActive(false)
    end
    self:OnShowPanelData()
end
function RewardTalismanSingleShowPopup:OnShowPanelData()
    local curEquipTreasureFigData = {}
    local curEquipTreasureStrongFigData = {}
    local curEquipTreasureSefineFigData = {}
    if type == 1 then
        self.powerNum1.text=EquipTreasureManager.CalculateWarForce(dId)
        local data = EquipTreasureManager.GetSingleTreasureByIdDyn(dId)
        itemConfig = data.itemConfig
        curEquipTreasureFigData = ConfigManager.GetConfigData(ConfigName.JewelConfig, data.id)
        curEquipTreasureStrongFigData,curEquipTreasureSefineFigData = self:GetStrongAndRefineConFig(curEquipTreasureFigData,data.lv,data.refineLv)
    else
        self.powerNum1.text=EquipTreasureManager.CalculateWarForceBySid(sId,lv,refineLv)
        itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig,sId)
        
        curEquipTreasureFigData = ConfigManager.GetConfigData(ConfigName.JewelConfig, sId)
        curEquipTreasureStrongFigData,curEquipTreasureSefineFigData = self:GetStrongAndRefineConFig(curEquipTreasureFigData,lv,refineLv)
    end
    self.curEquipDesc1.text=itemConfig.ItemDescribe
    self.qualityText.text=GetStringByEquipQua(itemConfig.Quantity,GetQuaStringByEquipQua(itemConfig.Quantity))
    self.curEquipName.text=GetStringByEquipQua(itemConfig.Quantity,itemConfig.Name)
    if lv>0 then
        self.lv.gameObject:SetActive(true)
        self.lv.text = curEquipTreasureStrongFigData.Level
    else
        self.lv.gameObject:SetActive(false)
    end
    if refineLv>0 then
        self.refineLv.gameObject:SetActive(true)
        self.refineLv.text = "+".. curEquipTreasureSefineFigData.Level
    else
        self.refineLv.gameObject:SetActive(false)
    end
    self.curEquipFrame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig.Quantity))
    self.curEquipIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
    self.proIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(itemConfig.PropertyName))
    self.btnJump:SetActive(itemConfig.UseJump and itemConfig.UseJump > 0 and BagManager.isBagPanel)
    --强化属性
    Util.ClearChild(self.curMainProGrid.transform)
    if #curEquipTreasureStrongFigData.Property>0 then --
        self.curMainProscroll:SetActive(true)
        for i = 1, #curEquipTreasureStrongFigData.Property do
            local go = newObject(self.otherProPre)
            go.transform:SetParent(self.curMainProGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            local proConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,curEquipTreasureStrongFigData.Property[i][1])
            if proConFig then
                Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text =proConFig.Info
                Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text = "+"..GetEquipPropertyFormatStr(proConFig.Style,curEquipTreasureStrongFigData.Property[i][2])
            end
        end
    else
        self.curMainProscroll:SetActive(false)
    end
    --精炼属性
    Util.ClearChild(self.otherProGrid.transform)
    if curEquipTreasureSefineFigData.Property and #curEquipTreasureSefineFigData.Property>0 then --
        self.curotherProscroll:SetActive(true)
        for i = 1, #curEquipTreasureSefineFigData.Property do
            local go = newObject(self.otherProPre)
            go.transform:SetParent(self.otherProGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            local proConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,curEquipTreasureSefineFigData.Property[i][1])
            if proConFig then
                Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text =proConFig.Info
                if curEquipTreasureSefineFigData.Property[i][2]==0 and proConFig.Style~=1 then
                    Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text = "+0%"
                else
                     Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text = "+"..GetEquipPropertyFormatStr(proConFig.Style,curEquipTreasureSefineFigData.Property[i][2])
                end
            end
        end
    else
        self.curotherProscroll:SetActive(false)
    end

    --装备获得途径
    Util.ClearChild(self.getTuGrid.transform)
    local curitemData = itemConfig
    if curitemData and curitemData.Jump then
        if curitemData.Jump and #curitemData.Jump>0 then
            for i = 1, #curitemData.Jump do
                SubUIManager.Open(SubUIConfig.JumpView, self.getTuGrid.transform, curitemData.Jump[i])
            end
        end
    end
end
--道具 和 装备分解 发送请求后 回调
function RewardTalismanSingleShowPopup:SendBackResolveReCallBack(drop)
    local isShowReward=false
    if drop.itemlist~=nil and #drop.itemlist>0 then
        for i = 1, #drop.itemlist do
            if drop.itemlist[i].itemNum>0 then
                isShowReward=true
                break
            end
        end
    end
    if isShowReward then
        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function ()
            BagManager.OnShowTipDropNumZero(drop)
        end)
    else
        BagManager.OnShowTipDropNumZero(drop)
    end
    EquipTreasureManager.RemoveTreasureByIdDyn(dId)
    self:ClosePanel()
end
--界面关闭时调用（用于子类重写）
function RewardTalismanSingleShowPopup:OnClose()

    if func then
        func()
    end
    func = nil
end

function RewardTalismanSingleShowPopup:GetStrongAndRefineConFig(curEuipTreaSureConfig,lv,rlv)
    local curEquipTreasureStrongFigData = {}
    local curEquipTreasureSefineFigData = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.JewelRankupConfig)) do
        --强化的属性
        if configInfo.PoolID == curEuipTreaSureConfig.LevelupPool and configInfo.Type == 1 and configInfo.Level == lv then
            curEquipTreasureStrongFigData = configInfo
        end
        --精炼的属性
        if configInfo.PoolID == curEuipTreaSureConfig.RankupPool and configInfo.Type == 2 and configInfo.Level == rlv then
            curEquipTreasureSefineFigData = configInfo
        end
    end
    return curEquipTreasureStrongFigData,curEquipTreasureSefineFigData
end

--界面销毁时调用（用于子类重写）
function RewardTalismanSingleShowPopup:OnDestroy()

end

return RewardTalismanSingleShowPopup