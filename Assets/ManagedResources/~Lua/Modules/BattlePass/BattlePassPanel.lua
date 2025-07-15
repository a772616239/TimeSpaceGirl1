require("Base/BasePanel")
local BattlePassPanel = Inherit(BasePanel)
local this = BattlePassPanel
local battlePassReward = ConfigManager.GetConfig(ConfigName.BattlePassReward)
local rechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local battlePassConfig = ConfigManager.GetConfig(ConfigName.BattlePassConfig)
local TabBox = require("Modules/Common/TabBox")

local curIndex = 1

this.contents = {
    [1] = {view = require("Modules/BattlePass/BattlePassPanel_FirstPanel"), panelName = "BattlePassPanel_FirstPanel"},
    [2] = {view = require("Modules/BattlePass/BattlePassPanel_Mission"), panelName = "BattlePassPanel_Mission"},
}

--初始化组件（用于子类重写）
function BattlePassPanel:InitComponent()
    this.tag = Util.GetGameObject(self.gameObject, "Panel/tag")
    this.dealBtn = Util.GetGameObject(this.tag, "detail/buyBtn")
    this.dealBtnPriceTxt = Util.GetGameObject(this.tag, "detail/buyBtn/PriceTxt"):GetComponent("Text")

    this.close = Util.GetGameObject(this.tag, "detail/close")

    this.itemGrid1 = Util.GetGameObject(this.tag, "detail/itemGrids/itemGrid1")
    this.itemGrid2 = Util.GetGameObject(this.tag, "detail/itemGrids/itemGrid2")
    this.itemPre = Util.GetGameObject(this.tag, "ItemView")
    this.itemPre2 = Util.GetGameObject(this.tag, "ItemView2")
    this.ScrollView1 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.itemGrid1.transform,
        this.itemPre, nil, Vector2.New(this.itemGrid1.transform.rect.width, this.itemGrid1.transform.rect.height), 2, 1, Vector2.New(5, 0))
    this.ScrollView2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.itemGrid2.transform,
        this.itemPre2, nil, Vector2.New(this.itemGrid2.transform.rect.width, this.itemGrid2.transform.rect.height), 1, 1, Vector2.New(0, 5))

    this.prefabs = {}
    for i = 1,#this.contents do
        this.prefabs[i] = Util.GetGameObject(self.gameObject,this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, "Panel/Content"))
    end
    this.tag:SetActive(false)

    this.backBtn = Util.GetGameObject(self.gameObject, "Panel/Content/BattlePassPanel_FirstPanel/backBtn")
    this.sortingOrder = self.sortingOrder
end

--绑定事件（用于子类重写）
function BattlePassPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.close, function()
        this.tag:SetActive(false)
    end)
    Util.AddOnceClick(this.dealBtn,function()
        local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(92001)
        if not isActive then
            if AppConst.isSDKLogin then
                PayManager.Pay({Id = battlePassConfig[1].BuyId}, function(id)
                    this.Opendetail()
                end)
            else
                NetManager.RequestBuyGiftGoods(battlePassConfig[1].BuyId,function(id)
                    this.Opendetail()
                end)
            end
        end
    end)
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

function BattlePassPanel.RefreshHelpBtn()
    if curIndex == 1 then
        this.HelpBtn:SetActive(true)
        Util.AddOnceClick(this.HelpBtn, function()
            UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.HeroExchange,this.helpPosition.x,this.helpPosition.y) 
        end)
    elseif curIndex == 2 then
        this.HelpBtn:SetActive(true)
        Util.AddOnceClick(this.HelpBtn, function()
            UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.HeroExchange2,this.helpPosition.x,this.helpPosition.y) 
        end)
    elseif curIndex == 3 then
        this.HelpBtn:SetActive(true)
    else
        this.HelpBtn:SetActive(false)
    end
end
function this.ReFreshUpSoul()
    local upSoul = this.GetBattlePassRewardList()
    local uplist = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,72001).BaseReward
    if not listSoulPre then
        listSoulPre = {}
    end
    this.ScrollView1:SetData(uplist,function (index,go)
        this.SetItemData2(go,uplist[index])
    end)
    if not listSoulUpPre then
        listSoulUpPre = {}
    end
    this.ScrollView2:SetData(upSoul,function (index,go)
        this.SetItemData(go,upSoul[index])
    end)
end
function this.SetItemData(go,data)
    go:SetActive(true)
    if not itemsGrid then
        itemsGrid = {}
    end
    if not itemsGrid[go] then
        itemsGrid[go] = {}
        for i = 1, 5, 1 do
            itemsGrid[go][i] = SubUIManager.Open(SubUIConfig.ItemView,Util.GetGameObject(go, "GameObject" .. i).transform)
        end
    end
    for i = 1, 5, 1 do
        itemsGrid[go][i].gameObject:SetActive(false)
        Util.GetGameObject(go, "GameObject" .. i):SetActive(false)
    end
    for i = 1, #data, 1 do
        itemsGrid[go][i].gameObject:SetActive(true)
        Util.GetGameObject(go, "GameObject" .. i):SetActive(true)
        itemsGrid[go][i]:OnOpen(false, data[i], 0.75, false)
    end
end
function this.SetItemData2(go,data)
    go:SetActive(true)
    if not itemsGrid then
        itemsGrid = {}
    end
    if not itemsGrid[go] then
        itemsGrid[go] = SubUIManager.Open(SubUIConfig.ItemView,Util.GetGameObject(go, "GameObject").transform)
    end
    itemsGrid[go]:OnOpen(false, data, 0.75, false)
end
function this.GetBattlePassRewardList()
    local battleList = {}
    local listIndex = {}
    local lslist = {}
    local setNewList = {}
    for index, value in ConfigPairs(battlePassReward) do
        local data = {Id = value.BattleReward[1],value = value.BattleReward[2]}
        table.insert(lslist,data)
    end
    for index, value in ipairs(lslist) do
        if setNewList[value.Id] then
            local lsnum = setNewList[value.Id][2] + value.value
            setNewList[value.Id][2] = lsnum
        else
            setNewList[value.Id] = {[1] = value.Id,[2] = value.value}
        end
    end
    for key, value in pairs(setNewList) do
        table.insert(listIndex,value)
    end
    local numIndex = 1
    local itemIndex = 1
    for key, value in pairs(listIndex) do
        if battleList[numIndex] then
            battleList[numIndex][itemIndex] = value
        else
            battleList[numIndex] = {}
            battleList[numIndex][itemIndex] = value
        end
        itemIndex = itemIndex + 1
        if itemIndex > 5 then
            itemIndex = 1
            numIndex = numIndex + 1
        end
    end
    return battleList
end

function this.Opendetail()
    this.tag:SetActive(true)
    local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(92001)
    local itemInfo = ShopManager.GetRechargeItemInfo(battlePassConfig[1].BuyId)
    this.dealBtnPriceTxt.text = MoneyUtil.GetMoney(itemInfo.Price)
    if isActive then
        Util.SetGray(this.dealBtn,true)
        this.dealBtn:GetComponent("Button").enabled = false
    else
        Util.SetGray(this.dealBtn,false)
        this.dealBtn:GetComponent("Button").enabled = true
    end
end
--添加事件监听（用于子类重写）
function BattlePassPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function BattlePassPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function BattlePassPanel:OnOpen(_curIndex)
    curIndex = _curIndex and _curIndex or 1
    this.ReFreshUpSoul()
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BattlePassPanel:OnShow()
    this.SwitchView(curIndex)
end

function BattlePassPanel:OnSortingOrderChange()
    this.tag:GetComponent("Canvas").sortingOrder = this.sortingOrder + 80
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
end

--切换视图
function this.SwitchView(index)
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, curIndex = curIndex, index
    for i = 1, #this.contents do
        if oldSelect ~= 0 then this.contents[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    --执行子模块初始化
    this.contents[index].view:OnShow(this,this.sortingOrder)
end

--界面关闭时调用（用于子类重写）
function BattlePassPanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
end

--界面销毁时调用（用于子类重写）
function BattlePassPanel:OnDestroy()
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

return BattlePassPanel