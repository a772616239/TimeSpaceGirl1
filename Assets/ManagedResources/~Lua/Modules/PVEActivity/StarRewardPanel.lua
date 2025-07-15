require("Base/BasePanel")
local StarRewardPanel = Inherit(BasePanel)
local this = StarRewardPanel
local activityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
local activityId

function this:InitComponent()
   this.scroll = Util.GetGameObject(this.gameObject, "mask/scroll")
   this.item =  Util.GetGameObject(this.gameObject, "mask/item")
   local srollV2 = this.scroll:GetComponent("RectTransform").rect
   this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform, this.item, nil,
       Vector2.New(srollV2.width, srollV2.height), 1, 1, Vector2.New(0, 5))
   this.ScrollView.moveTween.MomentumAmount = 1
   this.ScrollView.moveTween.Strength = 2

   this.btnBack = Util.GetGameObject(this.gameObject, "mask/btnBack")
end

function this:BindEvent()
    Util.AddClick(this.btnBack, function()
        Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.PveStar)
        this:ClosePanel()
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnOpen(id)
    activityId = id
end

function this:OnShow()
    this.SetScroll()
end

function this:OnSortingOrderChange()
end

function this:OnClose()
end

function this:OnDestroy()
end

function this.SetScroll()
    -- CheckRedPointStatus(RedPointType.PVEStarReward)
    local datas = ActivityGiftManager.GetActivityTypeInfoList(ActivityTypeDef.PVEStarReward)
    local data
    for index, value in ipairs(datas) do
        if value.activityId == activityId then
            data = value.mission
        end
    end
    table.sort(data, function (a, b)
        return activityRewardConfig[a.missionId].Sort < activityRewardConfig[b.missionId].Sort
    end)
    this.ScrollView:SetData(data, function (index, go)
        this.SetItem(go, data[index])
    end)
end

function this.SetItem(go, data)
    local title = Util.GetGameObject(go, "title"):GetComponent("Text")
    local num = Util.GetGameObject(go, "num"):GetComponent("Text")
    local btn = Util.GetGameObject(go, "btn")
    local received = Util.GetGameObject(go, "received")
    local grid = Util.GetGameObject(go, "grid")
    local slider = Util.GetGameObject(go, "slider"):GetComponent("Image")
    local redpoint = Util.GetGameObject(go, "btn/redpoint")

    local config = activityRewardConfig[data.missionId]
    title.text = GetLanguageStrById(config.ContentsShow)
    local progress = data.progress
    if progress > config.Values[2][1] then progress = config.Values[2][1] end
    num.text = progress.."/"..config.Values[2][1]
    slider.fillAmount = data.progress/config.Values[2][1]
    received:SetActive(data.state == 1)

    if not this.itemList then
        this.itemList = {}
    end
    if this.itemList[go] then
        for i = 1, #this.itemList[go] do
            this.itemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #config.Reward do
            if this.itemList[go][i] then
                this.itemList[go][i]:OnOpen(false, {config.Reward[i][1],config.Reward[i][2]}, 0.65)
                this.itemList[go][i].gameObject:SetActive(true)
            end
        end
    else
        this.itemList[go] = {}
        for i = 1, #config.Reward do
            this.itemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            this.itemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #config.Reward do
            this.itemList[go][i]:OnOpen(false, {config.Reward[i][1], config.Reward[i][2]}, 0.65)
            this.itemList[go][i].gameObject:SetActive(true)
        end
    end

    Util.SetGray(btn, data.progress < config.Values[2][1])
    btn:SetActive(data.state == 0)
    redpoint:SetActive(data.progress >= config.Values[2][1])
    Util.AddOnceClick(btn, function ()
        NetManager.GetActivityRewardRequest(data.missionId, config.ActivityId, function(drop)
            UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function()
                this.SetScroll()
            end)
        end)
    end)
end

return this