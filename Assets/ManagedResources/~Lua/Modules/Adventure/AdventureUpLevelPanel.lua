require("Base/BasePanel")
AdventureUpLevelPanel = Inherit(BasePanel)
local this = AdventureUpLevelPanel
local RewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local areaId
--初始化组件（用于子类重写）
function AdventureUpLevelPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "top/btnBack")
    this.reward1 = Util.GetGameObject(self.gameObject, "top/center/bgImage/reward1")
    this.reward2 = Util.GetGameObject(self.gameObject, "top/center/bgImage/reward2")
    this.reward3 = Util.GetGameObject(self.gameObject, "top/center/bgImage/reward3")
    this.reward4 = Util.GetGameObject(self.gameObject, "top/center/bgImage/reward4")
    this.reward1Num = Util.GetGameObject(self.gameObject, "top/center/bgImage/getRewardNumber1"):GetComponent("Text")
    this.reward2Num = Util.GetGameObject(self.gameObject, "top/center/bgImage/getRewardNumber2"):GetComponent("Text")
    this.reward3Num = Util.GetGameObject(self.gameObject, "top/center/bgImage/getRewardNumber3"):GetComponent("Text")
    this.reward4Num = Util.GetGameObject(self.gameObject, "top/center/bgImage/getRewardNumber4"):GetComponent("Text")
    this.rewardItem = Util.GetGameObject(self.gameObject, "top/center/rewardItem")
    --this.enemyItem=Util.GetGameObject(self.gameObject, "center/enemyItem")
    this.costItem = Util.GetGameObject(self.gameObject, "top/bottom/costItem")
    this.addRewardItemGrid = Util.GetGameObject(self.gameObject, "top/center/addRewardScrollRect/addRewardItemGrid")
    --this.addEnemyItemGrid=Util.GetGameObject(self.gameObject, "center/addEnemyItemGrid")
    this.advancedRequirementsItemGrid = Util.GetGameObject(self.gameObject, "top/bottom/advancedRequirementsItemGrid")
    this.secrectTerritoryLevel = Util.GetGameObject(self.gameObject, "top/secrectTerritoryLevel"):GetComponent("Text")
    this.lastLevel = Util.GetGameObject(self.gameObject, "top/center/lastLevel"):GetComponent("Text")
    this.nextLevel = Util.GetGameObject(self.gameObject, "top/center/nextLevel"):GetComponent("Text")
    this.upLevelBtn = Util.GetGameObject(self.gameObject, "top/bottom/upLevelBtn")
    this.costItemNumber = Util.GetGameObject(self.gameObject, "top/bottom/costItemNumber"):GetComponent("Text")
    this.addRewardItemGrid:GetComponent("RectTransform").localPosition = Vector2.New(1366.15, -3.8147e-06)
end

--更新升级页面数据
function AdventureUpLevelPanel:OnRefreshUpLevelData(areaId)
    this.addRewardItemGrid:GetComponent("RectTransform").localPosition = Vector2.New(1366.15, -3.8147e-06)
    this.secrectTerritoryLevel.text = AdventureManager.Data[areaId].areaName
    this.lastLevel.text = AdventureManager.Data[areaId].areaName .. AdventureManager.Data[areaId].areaLevel .. GetLanguageStrById(10072)
    this.nextLevel.text = AdventureManager.Data[areaId].areaName .. AdventureManager.Data[areaId].areaLevel + 1 .. GetLanguageStrById(10072)
    Util.ClearChild(this.advancedRequirementsItemGrid.transform)
    Util.ClearChild(this.addRewardItemGrid.transform)
    Util.ClearChild(this.reward1.transform)
    Util.ClearChild(this.reward2.transform)
    Util.ClearChild(this.reward3.transform)
    Util.ClearChild(this.reward4.transform)
    local itemdata = {}
    table.insert(itemdata, RewardGroup[AdventureManager.Data[areaId].baseRewardGroup[1][AdventureManager.Data[areaId].areaLevel]].ShowItem[1][1])
    table.insert(itemdata, 0)
    local view = SubUIManager.Open(SubUIConfig.ItemView, this.reward1.transform)
    view:OnOpen(false, itemdata, 0.97)
    this.reward1Num.text = "×" .. RewardGroup[AdventureManager.Data[areaId].baseRewardGroup[1][AdventureManager.Data[areaId].areaLevel]].ShowItem[1][2] .. "/m"
    itemdata = {}
    table.insert(itemdata, RewardGroup[AdventureManager.Data[areaId].baseRewardGroup[1][AdventureManager.Data[areaId].areaLevel]].ShowItem[2][1])
    table.insert(itemdata, 0)
    local view = SubUIManager.Open(SubUIConfig.ItemView, this.reward2.transform)
    view:OnOpen(false, itemdata, 0.97)
    this.reward2Num.text = "×" .. RewardGroup[AdventureManager.Data[areaId].baseRewardGroup[1][AdventureManager.Data[areaId].areaLevel]].ShowItem[2][2] .. "/m"
    itemdata = {}
    table.insert(itemdata, RewardGroup[AdventureManager.Data[areaId].baseRewardGroup[1][AdventureManager.Data[areaId].areaLevel + 1]].ShowItem[1][1])
    table.insert(itemdata, 0)
    local view = SubUIManager.Open(SubUIConfig.ItemView, this.reward3.transform)
    view:OnOpen(false, itemdata, 0.97)
    this.reward3Num.text = "×" .. RewardGroup[AdventureManager.Data[areaId].baseRewardGroup[1][AdventureManager.Data[areaId].areaLevel + 1]].ShowItem[1][2] .. "/m"
    itemdata = {}
    table.insert(itemdata, RewardGroup[AdventureManager.Data[areaId].baseRewardGroup[1][AdventureManager.Data[areaId].areaLevel + 1]].ShowItem[2][1])
    table.insert(itemdata, 0)
    local view = SubUIManager.Open(SubUIConfig.ItemView, this.reward4.transform)
    view:OnOpen(false, itemdata, 0.97)
    this.reward4Num.text = "×" .. RewardGroup[AdventureManager.Data[areaId].baseRewardGroup[1][AdventureManager.Data[areaId].areaLevel + 1]].ShowItem[2][2] .. "/m"

    if (AdventureManager.Data[areaId].rewardAddShow[1][AdventureManager.Data[areaId].areaLevel][1] ~= 0) then
        for j = 1, #AdventureManager.Data[areaId].rewardAddShow[1][AdventureManager.Data[areaId].areaLevel] do
            local itemdata = {}
            table.insert(itemdata, AdventureManager.Data[areaId].rewardAddShow[1][AdventureManager.Data[areaId].areaLevel][j])
            table.insert(itemdata, 0)
            local view = SubUIManager.Open(SubUIConfig.ItemView, this.addRewardItemGrid.transform)
            view:OnOpen(false, itemdata, 0.97)
        end
    end
    --for j =1,#AdventureManager.Data[areaId].upGradeConsume[1][AdventureManager.Data[areaId].areaLevel] do
    local itemdata = {}
    this.itemId = AdventureManager.Data[areaId].upGradeConsume[1][AdventureManager.Data[areaId].areaLevel][1]
    table.insert(itemdata, this.itemId)
    table.insert(itemdata, 0)
    this.itemNumber = AdventureManager.Data[areaId].upGradeConsume[1][AdventureManager.Data[areaId].areaLevel][2]
    if (BagManager.GetItemCountById(this.itemId) > this.itemNumber) then
        this.costItemNumber.text = "<color=#C5BA8F>" .. PrintWanNum(BagManager.GetItemCountById(this.itemId)) .. "</color>" .. "/" .. PrintWanNum(this.itemNumber)
    else
        this.costItemNumber.text = "<color=#C66366>" .. PrintWanNum(BagManager.GetItemCountById(this.itemId)) .. "</color>" .. "/" .. PrintWanNum(this.itemNumber)
    end
    local view = SubUIManager.Open(SubUIConfig.ItemView, this.advancedRequirementsItemGrid.transform)
    view:OnOpen(false, itemdata, 0.97)
    --end
end

--绑定事件（用于子类重写）
function AdventureUpLevelPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)

    Util.AddClick(this.upLevelBtn, function()
        if (BagManager.GetItemCountById(this.itemId) >= this.itemNumber) then
            AdventureManager.GetAdventurnUpLevelRequest(areaId)
        else
            PopupTipPanel.ShowTipByLanguageId(10073)
        end
        self:ClosePanel()
    end)
end
--添加事件监听（用于子类重写）
function AdventureUpLevelPanel:AddListener()

end

--移除事件监听（用于子类重写）
function AdventureUpLevelPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function AdventureUpLevelPanel:OnOpen(...)
    local args = { ... }
    areaId = args[1]
    this:OnRefreshUpLevelData(areaId)
end

--界面关闭时调用（用于子类重写）
function AdventureUpLevelPanel:OnClose()


end

--界面销毁时调用（用于子类重写）
function AdventureUpLevelPanel:OnDestroy()

end

return AdventureUpLevelPanel