require("Base/BasePanel")
PrayRewardItemPopup = Inherit(BasePanel)
local func
local itemListPrefab
local itemListPrefabParent
local isPopGetSSR = 0
local callList = Stack.New()
local isPlayerAniEnd = true
local chooseRewardId = 0
--初始化组件（用于子类重写）
function PrayRewardItemPopup:InitComponent()

    self.btnBack = Util.GetGameObject(self.gameObject, "backBtn")
    self.numText=Util.GetGameObject(self.gameObject, "numText"):GetComponent("Text")
    itemListPrefab = {}
    itemListPrefabParent = {}
    for i = 1, 2 do
        itemListPrefabParent[i] = Util.GetGameObject(self.gameObject, "Grid/itemPre ("..i..")")
        itemListPrefab[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(itemListPrefabParent[i].gameObject, "parent").transform)
    end
end

--绑定事件（用于子类重写）
function PrayRewardItemPopup:BindEvent()

    Util.AddClick(self.btnBack, function()
        if isPlayerAniEnd then
            self:ClosePanel()
        end
    end)
end

--添加事件监听（用于子类重写）
function PrayRewardItemPopup:AddListener()

end

--移除事件监听（用于子类重写）
function PrayRewardItemPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function PrayRewardItemPopup:OnOpen(_drop,_num,_chooseRewardId,_func)

    isPlayerAniEnd = true
    chooseRewardId = _chooseRewardId
    func = _func
    self:SetItemShow(_drop)
    self.numText.text = GetLanguageStrById(11676).._num..GetLanguageStrById(11677)
    SoundManager.PlaySound(SoundConfig.Sound_Reward)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PrayRewardItemPopup:OnShow()

end

local itemDataList
function PrayRewardItemPopup:OnSortingOrderChange()
    if not itemDataList then
        return
    end
    for i = 1, #itemListPrefab do
        local view = itemListPrefab[i]
        local curItemData=itemDataList[i]
        view:OnOpen(true,curItemData,1,true,false,false,self.sortingOrder)
    end
end
-- 根据物品列表数据显示物品
function  PrayRewardItemPopup:SetItemShow(drop)
    BagManager.OnShowTipDropNumZero(drop)
    if drop==nil then return end
    itemDataList=BagManager.GetTableByBackDropData(drop)

    --显示额外  真恶心
    local reward = {}
    if chooseRewardId > 0 and #itemDataList > 1 then
        local blessingRewardPool = ConfigManager.GetConfigData(ConfigName.BlessingRewardPool,chooseRewardId)
        if blessingRewardPool then
            reward.itemId = blessingRewardPool.Reward[1]
            reward.num = blessingRewardPool.Reward[2]
        end
        local isHave = false
        for i = 1, #itemDataList do
            if itemDataList[i].configData.Id == reward.itemId and itemDataList[i].num == reward.num then
                itemDataList[i].isShowPrecious = 0
            elseif isHave == false then
                isHave = true
                itemDataList[i].isShowPrecious = 3
            end
        end
        if isHave == false then
            itemDataList[1].isShowPrecious = 3
        end
    end
    --

    for i = 1, #itemListPrefabParent do
        local go = itemListPrefabParent[i]
        go.gameObject:SetActive(false)
    end
    isPopGetSSR = 0
    for i = 1, #itemDataList do
        local view = itemListPrefab[i]
        local curItemData=itemDataList[i]
        view:OnOpen(true,curItemData,1,true,false,false,self.sortingOrder)
        itemListPrefabParent[i].gameObject:SetActive(true)
        PlayUIAnim(itemListPrefabParent[i].gameObject)
        if curItemData.itemType==3 and curItemData.configData.Quality == 5  and curItemData.configData.Natural >= 13 then
            isPopGetSSR = curItemData.configData.Star
        end
    end


    --callList:Clear()
    --callList:Push(function ()
    --    isPlayerAniEnd = true
    --end)
    --for i = #itemDataList, 1, -1 do
    --    isPlayerAniEnd = false
    --    local view = itemListPrefab[i]
    --    local curItemData=itemDataList[i]
    --    view:OnOpen(true,curItemData,1,true,false,false,self.sortingOrder)
    --    callList:Push(function ()
    --        local func = function()
    --            itemListPrefabParent[i].gameObject:SetActive(true)
    --            PlayUIAnim(itemListPrefabParent[i].gameObject)
    --            Timer.New(function ()
    --                isPopGetSSR = false
    --                callList:Pop()()
    --            end, 0.2):Start()
    --        end
    --        if curItemData.configData and curItemData.itemType==3 and curItemData.configData.Natural >= 3 then
    --            isPopGetSSR = true
    --            UIManager.OpenPanel(UIName.DropGetSSRHeroShopPanel,curItemData.backData, func)
    --        else
    --            func()
    --        end
    --    end)
    --end
    --callList:Pop()()
end
--界面关闭时调用（用于子类重写）
function PrayRewardItemPopup:OnClose()

    if func then
        func()
        func = nil
    end
    if isPopGetSSR > 0 then
       
        HeroManager.DetectionOpenFiveStarActivity(isPopGetSSR)
    end
end

--界面销毁时调用（用于子类重写）
function PrayRewardItemPopup:OnDestroy()

    itemListPrefab = {}
end

return PrayRewardItemPopup