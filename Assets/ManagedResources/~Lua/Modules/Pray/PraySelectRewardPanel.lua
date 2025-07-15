require("Base/BasePanel")
PraySelectRewardPanel = Inherit(BasePanel)
local chuanShuoGridList = {}
local zhiZunGridList = {}
local chuanShuoItemVList = {}
local zhiZunItemVList = {}

local selectItemData = {}
local openPanel
local curchaunShuoSelectNum = 0
local curzhiZunSelectNum = 0
--初始化组件（用于子类重写）
function PraySelectRewardPanel:InitComponent()

    self.btnBack = Util.GetGameObject(self.transform, "btnBack")
    self.btnSure = Util.GetGameObject(self.transform, "btnSure")
    self.itemPre = Util.GetGameObject(self.transform, "itemPre")
    self.chuanShuoGrid = Util.GetGameObject(self.transform, "grid/chuanShuoGrid")
    self.zhiZunGrid = Util.GetGameObject(self.transform, "grid/zhiZunGrid")
    self.chuanShuoNum = Util.GetGameObject(self.transform, "grid/chuanShuoNum/selectNumText"):GetComponent("Text")
    self.zhiZunNum = Util.GetGameObject(self.transform, "grid/zhiZunNum/selectNumText"):GetComponent("Text")
    chuanShuoGridList = {}
    zhiZunGridList = {}
    for i = 1, 6 do
       chuanShuoGridList[i] = Util.GetGameObject(self.transform, "grid/chuanShuoGrid/itemPre ("..i..")")
        chuanShuoItemVList[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(chuanShuoGridList[i].transform, "parent").transform)
        zhiZunGridList[i] = Util.GetGameObject(self.transform, "grid/zhiZunGrid/itemPre ("..i..")")
        zhiZunItemVList[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(zhiZunGridList[i].transform, "parent").transform)
    end
end

--绑定事件（用于子类重写）
function PraySelectRewardPanel:BindEvent()

    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.btnSure, function()
        if LengthOfTable(selectItemData) < 16 - ConfigManager.GetConfigData(ConfigName.BlessingConfig,1).RandomNum then
            PopupTipPanel.ShowTipByLanguageId(11679)
        else
            if openPanel then
                --更新本地数据
                local selectRewardIds = {}
                for i, v in pairs(selectItemData) do
                    table.insert(selectRewardIds,v.rewardId)
                end
                NetManager.SavePraySelectRewardRequest(selectRewardIds, function ()
                    PrayManager.SetPatyRewardData(selectItemData)
                    openPanel.ShowAnimationAndRefreshData()
                    self:ClosePanel()
                end)
            end
        end
    end)
end

--添加事件监听（用于子类重写）
function PraySelectRewardPanel:AddListener()

end

--移除事件监听（用于子类重写）
function PraySelectRewardPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function PraySelectRewardPanel:OnOpen(_openPanel)

    openPanel = _openPanel
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PraySelectRewardPanel:OnShow()

    selectItemData = {}
    self:OnShowItemFun()
end
--展示
function PraySelectRewardPanel:OnShowItemFun()
    curchaunShuoSelectNum = ConfigManager.GetConfigData(ConfigName.BlessingConfig,1).LegendChooseNum
    curzhiZunSelectNum = ConfigManager.GetConfigData(ConfigName.BlessingConfig,1).SupremePoolIdChooseNum
    self.chuanShuoNum.text = GetLanguageStrById(11680)..curchaunShuoSelectNum..GetLanguageStrById(10218)
    self.zhiZunNum.text = GetLanguageStrById(11680)..curzhiZunSelectNum..GetLanguageStrById(10218)
    --传说
    if PrayManager.legendReward and #PrayManager.legendReward > 0 then
        for i = 1, #PrayManager.legendReward do
            self:OnShowSingleItemData(chuanShuoGridList[i],chuanShuoItemVList[i],PrayManager.legendReward[i])
        end
    end
    --至尊
    if PrayManager.supremeReward and #PrayManager.supremeReward > 0 then
        for i = 1, #PrayManager.supremeReward do
            self:OnShowSingleItemData(zhiZunGridList[i],zhiZunItemVList[i],PrayManager.supremeReward[i])
        end
    end

end
function PraySelectRewardPanel:OnShowSingleItemData(_parent,_go,_reward)
    local PreciousShow = 0
    if _reward.rewardId > 0 then
        local BlessingRewardPoolData = ConfigManager.GetConfigData(ConfigName.BlessingRewardPool,_reward.rewardId)
        if BlessingRewardPoolData then
            PreciousShow = BlessingRewardPoolData.PreciousShow
        end
    end
    local reward = {_reward.itemId,_reward.num,PreciousShow}
    _go:OnOpen(false,reward,1.2,true)
    local choosed =Util.GetGameObject(_parent.transform, "choosed")
    choosed:SetActive(false)
    if selectItemData[_reward.rewardId] then
        choosed:SetActive(true)
    end
    local cardclickBtn = Util.GetGameObject(_parent.transform, "click")
    Util.AddLongPressClick(cardclickBtn, function()
        _go:OnBtnCkickEvent(_reward.itemId)
        end, 0.5)
    Util.AddOnceClick(cardclickBtn, function()
        if selectItemData[_reward.rewardId] then
            choosed:SetActive(false)
            selectItemData[_reward.rewardId] = nil
            --this.UpdataPanelRewardAndSelectText()
            return
        end
        if  LengthOfTable(selectItemData) >= 16 - ConfigManager.GetConfigData(ConfigName.BlessingConfig,1).RandomNum then
            PopupTipPanel.ShowTipByLanguageId(11681)
            return
        end
        if _reward.type == 3 then --传说
            local curChuanShuoNum = 0
            for i, v in pairs(selectItemData) do
                if v.type == 3 then
                    curChuanShuoNum = curChuanShuoNum+1
                end
            end
            if curChuanShuoNum >= curchaunShuoSelectNum then
                PopupTipPanel.ShowTip(GetLanguageStrById(11682)..curchaunShuoSelectNum..GetLanguageStrById(10218))
                return
            end
        elseif _reward.type == 4 then--至尊
            local curZhiZunNum = 0
            for i, v in pairs(selectItemData) do
                if v.type == 4 then
                    curZhiZunNum = curZhiZunNum+1
                end
            end
            if curZhiZunNum >= curzhiZunSelectNum then
                PopupTipPanel.ShowTip(GetLanguageStrById(11683)..curzhiZunSelectNum..GetLanguageStrById(10218))
                return
            end
        end
        selectItemData[_reward.rewardId]=_reward
        choosed:SetActive(true)
        --this.UpdataPanelRewardAndSelectText()
    end)

end
--界面关闭时调用（用于子类重写）
function PraySelectRewardPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function PraySelectRewardPanel:OnDestroy()

end

return PraySelectRewardPanel