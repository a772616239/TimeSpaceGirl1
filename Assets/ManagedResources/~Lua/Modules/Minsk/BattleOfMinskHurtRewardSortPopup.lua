require("Base/BasePanel")
BattleOfMinskHurtRewardSortPopup = Inherit(BasePanel)
local this = BattleOfMinskHurtRewardSortPopup
local rewardList = {}
local itemList = {}
local sorting = 0

--初始化组件（用于子类重写）
function BattleOfMinskHurtRewardSortPopup:InitComponent()
    this.rewardPre = Util.GetGameObject(self.gameObject, "ItemPre")
    local v2 = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "scroll").transform,
            this.rewardPre, nil, Vector2.New(v2.width, v2.height), 1, 1, Vector2.New(0,10  ))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
end

--绑定事件（用于子类重写）
function BattleOfMinskHurtRewardSortPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function BattleOfMinskHurtRewardSortPopup:AddListener()
end

--移除事件监听（用于子类重写）
function BattleOfMinskHurtRewardSortPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BattleOfMinskHurtRewardSortPopup:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BattleOfMinskHurtRewardSortPopup:OnShow()
    this.ShowCurIndexRewardData()

end
function BattleOfMinskHurtRewardSortPopup:OnSortingOrderChange()
    sorting = self.sortingOrder
end

--显示奖励
function this.ShowCurIndexRewardData()
    rewardList = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.WorldHurtRewardConfig)) do
        table.insert(rewardList,configInfo)
    end
    local length = #rewardList+1
    this.ScrollView:SetData(rewardList, function (index, go)
        this.SingleRewardDataShow(go, rewardList[length-index],length-index)
    end)
end
function this.SingleRewardDataShow(go, rewardConfig, index)
    this.itemGrid = Util.GetGameObject(go, "itemGrid")
    this.hurt = Util.GetGameObject(go, "hurt"):GetComponent("Text")
    local num = rewardConfig.Hurt/100000000
    this.hurt.text = string.format(GetLanguageStrById(12100), num)

    if not itemList[go.name] then
        itemList[go.name] = {}
    end
    for i = 1, #itemList[go.name] do
        itemList[go.name][i].gameObject:SetActive(false)
    end
    for i = 1, #rewardConfig.HurtAward do
        if itemList[go.name][i] then
            itemList[go.name][i]:OnOpen(false, rewardConfig.HurtAward[i], 0.65, false, false, false, sorting)
        else
            itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, this.itemGrid.transform)
            itemList[go.name][i]:OnOpen(false, rewardConfig.HurtAward[i], 0.65, false, false, false, sorting)
        end
        itemList[go.name][i].gameObject:SetActive(true)
    end
 
end
--界面关闭时调用（用于子类重写）
function BattleOfMinskHurtRewardSortPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function BattleOfMinskHurtRewardSortPopup:OnDestroy()
    itemList = {}
end

return BattleOfMinskHurtRewardSortPopup