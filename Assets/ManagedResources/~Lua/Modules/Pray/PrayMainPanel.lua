require("Base/BasePanel")
PrayMainPanel = Inherit(BasePanel)
local this = PrayMainPanel
local blessingConfig = ConfigManager.GetConfig(ConfigName.BlessingConfig)
--16个祈福奖励
local RewardParentGrid = {}
local RewardItemGrid = {}
--16个祈福奖励预览
local yunLanRewardParentGrid = {}
local yunLanRewardItemGrid = {}
--当前祈福完成的个数
local allGetFinishRewardNum = 0
local allGetRewardNum = 0

local blessingConFigData = {}
local itemId = 0
local itemNum = 0
local itemData = {}

--累计奖励
local extraRewardParentGrid = {}
local extraRewardItemGrid = {}
--是否在刷新时间范围内
local isRefresh = true


local orginLayer = 0
--初始化组件（用于子类重写）
function PrayMainPanel:InitComponent()


    orginLayer = 0
    self.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    self.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    self.bg = Util.GetGameObject(self.transform, "bg")
    screenAdapte(self.bg)

    self.tishiText = Util.GetGameObject(self.gameObject, "downGo/name/tishiText")
    self.tishiText2 = Util.GetGameObject(self.gameObject, "downGo/name/tishiText2")
    self.tishiText3 = Util.GetGameObject(self.gameObject, "downGo/name/tishiText3")
    self.tishiText2Text = Util.GetGameObject(self.gameObject, "downGo/name/tishiText2/tishiText1"):GetComponent("Text")
    self.tishiText2Image = Util.GetGameObject(self.gameObject, "downGo/name/tishiText2/itemImage"):GetComponent("Image")
    --self.refreshBtn = Util.GetGameObject(self.gameObject, "upGo/refreshBtn")
    self.yulanBtn = Util.GetGameObject(self.gameObject, "upGo/yulanBtn")
    self.extraRewardGo = Util.GetGameObject(self.gameObject, "upGo/extraRewardPre")
    self.extraRewardParent = Util.GetGameObject(self.gameObject, "upGo/extraRewardPre/parent")
    self.allPrayNum = Util.GetGameObject(self.gameObject, "upGo/extraRewardPre/getNumText"):GetComponent("Text")
    self.extraRewardExp = Util.GetGameObject(self.transform, "upGo/extraRewardPre/exp"):GetComponent("Slider")
    self.extraRewardExpText = Util.GetGameObject(self.gameObject, "upGo/extraRewardPre/exp/Text"):GetComponent("Text")
    self.extraRewardNameText = Util.GetGameObject(self.gameObject, "upGo/extraRewardPre/nameText"):GetComponent("Text")
    this.RewardGrid = Util.GetGameObject(self.gameObject, "downGo/RewardGrid")
    for i = 1, 16 do
        RewardParentGrid[i] = Util.GetGameObject(self.gameObject, "downGo/RewardGrid/ItemView ("..i..")")
        RewardItemGrid[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(RewardParentGrid[i].transform, "itemParent").transform)
        yunLanRewardParentGrid[i] = Util.GetGameObject(self.gameObject, "previewRewardLayout/RewardGrid/ItemView ("..i..")")
        yunLanRewardItemGrid[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(yunLanRewardParentGrid[i].transform, "itemParent").transform)
    end

    --奖励预览
    self.previewRewardLayout = Util.GetGameObject(self.gameObject, "previewRewardLayout")
    self.previewRewardLayout:SetActive(false)
    self.yulanMaskBtn = Util.GetGameObject(self.gameObject, "previewRewardLayout/maskBtn")
    --累计奖励预览
    self.extraRewardBtn = Util.GetGameObject(self.gameObject, "upGo/extraRewardPre/extraRewardBtn")
    self.extraRewardLayout = Util.GetGameObject(self.gameObject, "extraRewardLayout")
    self.extraRewardLayout:SetActive(false)
    self.extraMaskBtn = Util.GetGameObject(self.gameObject, "extraRewardLayout/maskBtn")
    for i = 1, 6 do
        extraRewardParentGrid[i] = Util.GetGameObject(self.gameObject, "extraRewardLayout/RewardRect/RewardGrid/ItemView ("..i..")")
        extraRewardItemGrid[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(extraRewardParentGrid[i].transform, "itemParent").transform)
    end
    --时间
    self.activeTimeText = Util.GetGameObject(self.gameObject, "upGo/name/time/timeImage/timeText"):GetComponent("Text")
    --self.activeRefreshTimeText = Util.GetGameObject(self.gameObject, "upGo/refreshTimeBg/refreshTimeText")
    self.refreshTimeBg = Util.GetGameObject(self.gameObject, "upGo/refreshTimeBg")

    self.effect = Util.GetGameObject(self.gameObject, "effect")
    effectAdapte(Util.GetGameObject(self.effect, "Partical/ziti mask (1)"))
end

--绑定事件（用于子类重写）
function PrayMainPanel:BindEvent()

    Util.AddClick(self.BtnBack, function()
        self:ClosePanel()
    end)
    --Util.AddClick(self.refreshBtn, function()
    --    self:RefreshBtnClick()
    --end)
    Util.AddClick(self.yulanMaskBtn, function()
        self.previewRewardLayout:SetActive(false)
    end)
    Util.AddClick(self.yulanBtn, function()
        for i = 1, #PrayManager.patyPreviewRewardData do
            if allGetRewardNum > 0 then
                local patyPreviewRewardData = PrayManager.patyPreviewRewardData[i]
                this:ShowSingleRewardData(false,yunLanRewardParentGrid[i],yunLanRewardItemGrid[i],patyPreviewRewardData,false)
            end
        end
        self.previewRewardLayout:SetActive(true)
    end)
    Util.AddClick(self.extraMaskBtn, function()
        self.extraRewardLayout:SetActive(false)
    end)
    Util.AddClick(self.extraRewardBtn, function()
        --累计奖励
        for i = 1, #PrayManager.extraRewardData do
            local patyRewardData = PrayManager.extraRewardData[i]
            this:ShowSingleExtraRewardData(false,extraRewardParentGrid[i],extraRewardItemGrid[i],patyRewardData)
        end
        self.extraRewardLayout:SetActive(true)
    end)
end

--添加事件监听（用于子类重写）
function PrayMainPanel:AddListener()

end

--移除事件监听（用于子类重写）
function PrayMainPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function PrayMainPanel:OnOpen(...)

end

local isPlayAinEnd = true
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PrayMainPanel:OnShow()

    isPlayAinEnd = true
    self.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.LightRing })
    blessingConFigData = blessingConfig[1].Cost
    this.ShowRewardDataList()
end
function PrayMainPanel:OnSortingOrderChange()
    -- 设置特效
    Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
    self.previewRewardLayout.transform:GetComponent("Canvas").sortingOrder = self.sortingOrder + 50
    self.extraRewardLayout.transform:GetComponent("Canvas").sortingOrder = self.sortingOrder + 50
end
--获取活动时间 和 刷新倒计时显示
function PrayMainPanel:SetRemainTime()
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.Pray)--Pray
    if activityInfo then
        if activityInfo.endTime ~= 0 then

            self.activeTimeText.text = GetLanguageStrById(10546)..self:TimeStampToDateStr2(activityInfo.startTime).."~"..self:TimeStampToDateStr2(activityInfo.endTime)
        end
    end
    --local privilegeId = blessingConfig[1].RefreshCd
    --local maxResreshNum = PrivilegeManager.GetPrivilegeNumber(privilegeId)
    
    --self:RemainTimeDown(PrayManager.lastRefreshTime+(maxResreshNum) - GetTimeStamp())
end
--刷新倒计时显示
function PrayMainPanel:RemainTimeDown(timeDown)
    if timeDown > 0 then
        self.refreshTimeBg:SetActive(true)
        self.activeRefreshTimeText:GetComponent("Text").text =   TimeStampToDateStr3(timeDown)
        isRefresh = false
        Util.SetGray(self.refreshBtn, true)
        if self.timer then
            self.timer:Stop()
            self.timer = nil
        end
        self.timer = Timer.New(function()
            self.activeRefreshTimeText:GetComponent("Text").text =   TimeStampToDateStr3(timeDown)
            if timeDown < 0 then
                isRefresh = true
                self.refreshTimeBg:SetActive(false)
                Util.SetGray(self.refreshBtn, false)
                self.timer:Stop()
                self.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        self.timer:Start()
    else
        isRefresh = true
        Util.SetGray(self.refreshBtn, false)
        self.refreshTimeBg:SetActive(false)
    end
end
--展示所有祈福奖励
function this.ShowRewardDataList()
    this:OnShowExtraRewar()
    this:SetRemainTime()
    for i = 1, #PrayManager.patyRewardData do
        local patyRewardData = PrayManager.patyRewardData[i]
        this:ShowSingleRewardData(false,RewardParentGrid[i],RewardItemGrid[i],patyRewardData,true)
        --if allGetRewardNum > 0 then
        --    local patyPreviewRewardData = PrayManager.patyPreviewRewardData[i]
        --    this:ShowSingleRewardData(false,yunLanRewardParentGrid[i],yunLanRewardItemGrid[i],patyPreviewRewardData,false)
        --end
    end
    --累计奖励
    --for i = 1, #PrayManager.extraRewardData do
    --    local patyRewardData = PrayManager.extraRewardData[i]
    --    this:ShowSingleExtraRewardData(false,extraRewardParentGrid[i],extraRewardItemGrid[i],patyRewardData)
    --end
end
--展示单个祈福奖励
function PrayMainPanel:ShowSingleRewardData(_isGet,_parentGo,_go,patyRewardData,isClick)
    local PreciousShow = 0
    if patyRewardData.rewardId > 0 then
        local BlessingRewardPoolData = ConfigManager.GetConfigData(ConfigName.BlessingRewardPool,patyRewardData.rewardId)
        if BlessingRewardPoolData then
            PreciousShow = BlessingRewardPoolData.PreciousShow
        end
    end
    local _reward = {patyRewardData.itemId,patyRewardData.num,PreciousShow}
    
    local _state = patyRewardData.state
    local itemParent = Util.GetGameObject(_parentGo.transform, "itemParent")
    local getBtn = Util.GetGameObject(_parentGo.transform, "getBtn")
    local wenhaoBtn
    local addImage
    if isClick then
        wenhaoBtn = Util.GetGameObject(_parentGo.transform, "wenhaoBtn")
        addImage = Util.GetGameObject(_parentGo.transform, "addImage")
        wenhaoBtn:SetActive(false)
        addImage:SetActive(false)
    end
    getBtn:SetActive(false)
    itemParent:SetActive(false)
    if _state == 0 then--0未保存无物品 1 未保存有物品 2 已选择 3 已祈福
        if isClick then
            addImage:SetActive(true)
        end
    elseif _state == 1 then
        itemParent:SetActive(true)
        if isClick then
            _go:OnOpen(_isGet,_reward,1)
        else
            _go:OnOpen(_isGet,_reward,1,true)
        end
    elseif _state == 2 then
        if isClick then
            wenhaoBtn:SetActive(true)
        else
            itemParent:SetActive(true)
            if isClick then
                _go:OnOpen(_isGet,_reward,1)
            else
                _go:OnOpen(_isGet,_reward,1,true)
            end
        end
    elseif _state == 3 then
        itemParent:SetActive(true)
        if isClick then
            _go:OnOpen(_isGet,_reward,1)
        else
            _go:OnOpen(_isGet,_reward,1,true)
        end
        getBtn:SetActive(true)
    end
    Util.AddOnceClick(addImage, function()
        if isPlayAinEnd == false then
            return
        end
        if isClick then
            UIManager.OpenPanel(UIName.PraySelectRewardPanel,this)
        end
    end)
    if isClick then
        Util.AddOnceClick(wenhaoBtn, function()
            if BagManager.GetItemCountById(itemData.Id) < itemNum then
                --PopupTipPanel.ShowTip("材料不足")
                --功能快捷购买
                UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.LightRing })
                return
            end
            if isPlayAinEnd == false then
                return
            end
            MsgPanel.ShowTwo(GetLanguageStrById(11668)..itemNum..GetLanguageStrById(10218)..itemData.Name, nil ,function ()
                NetManager.GetSinglePrayRewardRequest(patyRewardData.id, function (_msg)
                    isPlayAinEnd = false
                    PrayManager.SetPatySingleRewardData(patyRewardData.id,_msg.chooseRewardId)
                    PlayUIAnim(_parentGo)
                    Timer.New(function ()
                        this.ShowRewardDataList()
                    end, 0.2):Start()
                    Timer.New(function ()
                        UIManager.OpenPanel(UIName.PrayRewardItemPopup,_msg.reward,allGetFinishRewardNum,_msg.chooseRewardId,function()
                            self:CheckGetMaxReward()
                        end)
                        isPlayAinEnd = true
                    end, 0.4):Start()
                end)
            end)
        end)
    end
end
--检测祈福是否满16  满会自动刷新
function PrayMainPanel:CheckGetMaxReward()
    local allGetFinishRewardNums = 0
    for i = 1, #PrayManager.patyRewardData do
        if PrayManager.patyRewardData[i].state >= 3 then
            allGetFinishRewardNums = allGetFinishRewardNums + 1
        end
    end
   
    if allGetFinishRewardNums >= 16 then
        local isRefreshConFig = blessingConfig[1].IsRefresh
        if isRefreshConFig == 1 then
            MsgPanel.ShowOne(GetLanguageStrById(11669), function ()
                NetManager.InitPrayDataRequest(function (_msg)
                    PrayManager.ResetPatyRewardData(_msg)
                    this.ShowRewardDataList()
                end)
            end)
            return
        end
    end
end
--展示额外奖励
function PrayMainPanel:OnShowExtraRewar()
    --额外奖励赋值
    allGetFinishRewardNum = 0
    allGetRewardNum = 0
    for i = 1, #PrayManager.patyRewardData do
        if PrayManager.patyRewardData[i].state >= 3 then
            allGetFinishRewardNum = allGetFinishRewardNum + 1
        end
        if PrayManager.patyRewardData[i].state >= 2 then
            allGetRewardNum = allGetRewardNum + 1
        end
    end
    local curGetExtraRewarData = {}
    local upGetExtraRewarData = 0
    for i = 1, #PrayManager.extraRewardData do
        if allGetFinishRewardNum < PrayManager.extraRewardData[i].extraRewardCount then
            curGetExtraRewarData = PrayManager.extraRewardData[i]
            break
        end
    end
    for i = 1, #PrayManager.extraRewardData do
        if allGetFinishRewardNum >= PrayManager.extraRewardData[i].extraRewardCount then
            upGetExtraRewarData = PrayManager.extraRewardData[i].extraRewardCount
        end
    end
    --抽取消耗的材料赋值
    itemId = blessingConFigData[1][1]
    itemNum = CalculateCostCount(allGetFinishRewardNum + 1, blessingConFigData[2])
    itemData = ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId)
    self.tishiText3:SetActive(false)
    self.tishiText:SetActive(false)
    self.tishiText2:SetActive(false)
    
    self.allPrayNum.text = GetLanguageStrById(11670)..allGetFinishRewardNum
    if allGetRewardNum > 0 then
        self.yulanBtn:SetActive(true)
        self.tishiText:SetActive(false)
        if allGetFinishRewardNum >= 16 then
            self.tishiText3:SetActive(true)
        else
            self.tishiText2:SetActive(true)
            self.tishiText2Text.text = GetLanguageStrById(11671)..itemNum..GetLanguageStrById(10218)
            self.tishiText2Image.sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
        end
    else
        self.yulanBtn:SetActive(false)
        self.tishiText2:SetActive(false)
        self.tishiText3:SetActive(false)
        self.tishiText:SetActive(true)
    end
    if curGetExtraRewarData and curGetExtraRewarData.itemId then
        self.extraRewardGo:SetActive(true)
        Util.ClearChild(self.extraRewardParent.transform)
        SubUIManager.Open(SubUIConfig.ItemView, self.extraRewardParent.transform,false,{curGetExtraRewarData.itemId,curGetExtraRewarData.num},1,false)
        self.extraRewardNameText.text = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,curGetExtraRewarData.itemId).Name)
        self.extraRewardExp.value= (allGetFinishRewardNum)/(curGetExtraRewarData.extraRewardCount)
        self.extraRewardExpText.text =(allGetFinishRewardNum).."/"..(curGetExtraRewarData.extraRewardCount)
    else
        self.extraRewardGo:SetActive(false)
    end
end
--展示单个额外奖励
function PrayMainPanel:ShowSingleExtraRewardData(_isGet,_parentGo,_go,patyRewardData)
    local numText = Util.GetGameObject(_parentGo.transform, "numText/Text"):GetComponent("Text")
    local _reward = {patyRewardData.itemId,patyRewardData.num}
    _go:OnOpen(_isGet,_reward,1)
    numText.text = patyRewardData.extraRewardCount
end
--刷新按钮事件
function PrayMainPanel:RefreshBtnClick()

    local isRefreshConFig = blessingConfig[1].IsRefresh
    local privilegeId = blessingConfig[1].RefreshCd
    if isRefreshConFig == 0 then
        PopupTipPanel.ShowTipByLanguageId(11672)
        return
    end
    if isRefresh == false then
        PopupTipPanel.ShowTipByLanguageId(11673)
        return
    end
    MsgPanel.ShowTwo(GetLanguageStrById(11674), nil ,function ()
        NetManager.ResetAllPrayRewardRequest(function (_msg)
            PrayManager.ResetPatyRewardData(_msg)
            PrivilegeManager.RefreshPrivilegeUsedTimes(privilegeId, 1)
            this.ShowRewardDataList()
        end)
    end)
end
--界面关闭时调用（用于子类重写）
function PrayMainPanel:OnClose()

    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

-- 将时间戳转换为用于显示的日期字符串(年月日)
function PrayMainPanel:TimeStampToDateStr2(timestamp)
    local date = os.date("*t", timestamp)
    --local year = string.sub(date.year,3,4)
    return string.format(GetLanguageStrById(11675), date.year, date.month, date.day)
end
function this.ShowAnimationAndRefreshData()
    PlayUIAnim(this.RewardGrid)
    Timer.New(function ()
        this.ShowRewardDataList()
        PlayUIAnimBack(this.RewardGrid)
    end, 0.8):Start()
end
--界面销毁时调用（用于子类重写）
function PrayMainPanel:OnDestroy()

    SubUIManager.Close(self.UpView)
end

return PrayMainPanel