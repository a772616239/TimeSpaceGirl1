----- 易经宝库奖励预览弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local curId = nil--当前已选择的物品的Id
local ActData = {}
local itemList = {}--克隆预制体列表
local itemIconList = {}--ItemView的List
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local BlessingConfig = ConfigManager.GetConfig(ConfigName.BlessingRewardPoolNew)
local _args
local func
local finalReward

function this:InitComponent(gameObject)
    -- this.titleText = Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    -- this.tip = Util.GetGameObject(gameObject,"tip"):GetComponent("Text")
    this.itemPre = Util.GetGameObject(gameObject, "itemPre")
    this.ConfirmBtn = Util.GetGameObject(gameObject, "ConfirmBtn")
    this.Scroll = Util.GetGameObject(gameObject, "Scroll")

    this.bigReward = Util.GetGameObject(gameObject, "finalReward")
    this.bigIcon = Util.GetGameObject(this.bigReward, "icon")
    this.bigNum = Util.GetGameObject(this.bigReward, "text"):GetComponent("Text")

    local rootHight = this.Scroll.transform.rect.height
    local width = this.Scroll.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 5, Vector2.New(5, 50))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

function this:BindEvent()

end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    
    itemList = {}
    parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    _args = {...}
    ActData = _args[1]
    func = _args[2]
    -- this.titleText.text = GetLanguageStrById(10859)
    -- this.tip.text = GetLanguageStrById(12429)
    --设置最终奖励
    if not finalReward then
        finalReward = SubUIManager.Open(SubUIConfig.ItemView,this.bigIcon.transform)
    end
    finalReward:OnOpen(false, BlessingConfig[ActData.selectId].Reward, 0.75, false, false, false, sortingOrder)

    --检查是否已经全部领完了
    local t1 = false
    for i = 1, #ActData.finalCardDatas do
        if ActData.selectId == ActData.finalCardDatas[i].rewardId then
            t1 = true
        end
    end
    if t1 then
        this.bigNum.text = "<color=red>0/1</color>"
    else
        this.bigNum.text = "1/1"
    end

    local leftRewardData = DynamicActivityManager.GetLeftRewardData()
    
    local tempData = {}
    for key, value in pairs(leftRewardData) do
        table.insert(tempData,value)
    end
    this.ScrollView:SetData(tempData, function(index, go)
        this:SetSingleData(index,go,leftRewardData[index + (ActData.curLevel-1)*10])
    end)

end

function this:SetSingleData(index,item,data)
    itemList[index] = item
    local icon = Util.GetGameObject(item,"icon")
    local num = Util.GetGameObject(item,"text"):GetComponent("Text")

    item:SetActive(true)
    if not itemIconList[item] then
        local view = SubUIManager.Open(SubUIConfig.ItemView, icon.transform)
        itemIconList[item] = view
    end
    itemIconList[item]:OnOpen(false,data.reward,0.75,false)

    if data.progress == 0 then
        num.text = "<color=red>"..data.progress.."/"..data.limit.."</color>"
    else
        num.text = data.progress.."/"..data.limit
    end
end

function this:OnClose()

end

function this:OnDestroy()
    itemIconList = {}
    finalReward = nil
end

return this