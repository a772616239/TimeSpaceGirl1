require("Base/BasePanel")
BattleEndPanel = Inherit(BasePanel)
local this = BattleEndPanel
local BattlePanel
local callBack
local selfsortingOrder = 0
local orginLayer2 = 0
--初始化组件（用于子类重写）
function BattleEndPanel:InitComponent()

    this.bg = Util.GetGameObject(self.gameObject, "btnBack")
    this.roleGrid = Util.GetGameObject(self.gameObject, "roleGrid")
    this.awardGrid = Util.GetGameObject(self.gameObject, "Bg/ItemRoot/grid")
    this.btnResult = Util.GetGameObject(self.gameObject, "btnResult")
end

--绑定事件（用于子类重写）
function BattleEndPanel:BindEvent()

    Util.AddClick(this.bg, function ()
        self:ClosePanel()
        if BattlePanel then
            BattlePanel:ClosePanel()
        end
    end)

    Util.AddClick(this.btnResult, function()
        UIManager.OpenPanel(UIName.DamageResultPanel, 1)
    end)
end

--添加事件监听（用于子类重写）
function BattleEndPanel:AddListener()

end

--移除事件监听（用于子类重写）
function BattleEndPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function BattleEndPanel:OnOpen(battlePanel, hpList, drop, func, isShowResult)

    selfsortingOrder = self.sortingOrder
    if battlePanel then
        BattlePanel = battlePanel
    end
    callBack = nil
    if func then
        callBack = func
    end
    this.RefreshTeamInfo(hpList)
    this.SetItemShow(drop)
    -- 判断是否显示战斗统计
    if isShowResult == nil then isShowResult = false end
    local haveRecord = BattleRecordManager.isHaveRecord()
    isShowResult = isShowResult and haveRecord
    this.btnResult:SetActive(isShowResult)
end

-- 显示队伍信息
function this.RefreshTeamInfo(hpList)
    local curFormation = MapManager.formationList
    ClearChild(this.roleGrid.transform)
    for i = 1, 5 do
        local heroData
        local go = SubUIManager.Open(SubUIConfig.RoleItemView, this.roleGrid.transform)
        if curFormation[i] then
            heroData = HeroManager.GetSingleHeroData(curFormation[i].heroId)
            if not heroData then
               
                return
            end
            local curHeroHp = hpList[i]

            go:OnOpen(curFormation[i].heroId, true, true, curHeroHp / curFormation[i].allProVal[3])
            local allPropValue = curFormation[i].allProVal
            go:AddClick(function()
                UIManager.OpenPanel(UIName.MapRoleInfoPopup, heroData, allPropValue)
            end)
            Util.SetGray(go.gameObject, curHeroHp <= 0 )
            go.gameObject:SetActive(true)
        else
            go.gameObject:SetActive(false)
        end
    end
    for i = 1, #this.roleGrid.transform.childCount do 
        Util.AddParticleSortLayer(this.roleGrid.transform:GetChild(i - 1).gameObject, self.sortingOrder - orginLayer2)
    end
    orginLayer2 = selfsortingOrder
    selfsortingOrder = self.sortingOrder
end

function this.OnSortingOrderChange()
    for i = 1, #this.roleGrid.transform.childCount do 
        Util.AddParticleSortLayer(this.roleGrid.transform:GetChild(i - 1).gameObject, self.sortingOrder - selfsortingOrder)
    end
    selfsortingOrder = self.sortingOrder
end
-- 根据物品列表数据显示物品
function  this.SetItemShow(drop)
    if drop==nil then return end
    local itemDataList = BagManager.GetItemListFromTempBag(drop)

    Util.ClearChild(this.awardGrid.transform)
    for i = 1, #itemDataList do

        local go = SubUIManager.Open(SubUIConfig.ItemView, this.awardGrid.transform)
        local item = itemDataList[i]
        go:OnOpen(true, item, 1, true, true,false,this.selfsortingOrder)

        if itemDataList[i].itemType==1 then
            Util.AddOnceClick(itemIcon, function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,itemDataList[i].backData.itemId)
            end)
        elseif itemDataList[i].itemType==2 then
            Util.AddOnceClick(itemIcon, function()
               
                UIManager.OpenPanel(UIName.RewardEquipSingleShowPopup,itemDataList[i].backData)
            end)
        elseif itemDataList[i].itemType==3 then
            Util.AddOnceClick(itemIcon, function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,itemDataList[i].backData)
            end)
        end
    end
end
--界面关闭时调用（用于子类重写）
function BattleEndPanel:OnClose()

    if callBack then callBack() end
end

--界面销毁时调用（用于子类重写）
function BattleEndPanel:OnDestroy()

end

return BattleEndPanel