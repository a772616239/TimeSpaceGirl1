local Expert_UpLv = quick_class("Expert_UpLv")
local this = Expert_UpLv
local itemList = {}--优化itemView使用
local activityRewardConfig
local activeData
local activityId = 43
local expertRewardGrid = {}

function Expert_UpLv:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function Expert_UpLv:InitComponent(gameObject)
    this.timeGo = Util.GetGameObject(gameObject, "timeText")
    this.time = Util.GetGameObject(gameObject, "timeText"):GetComponent("Text")

    this.grid =  Util.GetGameObject(gameObject, "rect/rect/grid")
    this.rewardPre = Util.GetGameObject(gameObject, "rect/rect/grid/rewardPre")
end

--绑定事件（用于子类重写）
function Expert_UpLv:BindEvent()
end

--添加事件监听（用于子类重写）
function Expert_UpLv:AddListener()
end

--移除事件监听（用于子类重写）
function Expert_UpLv:RemoveListener()
end

local sortingOrder = 0
--界面打开时调用（用于子类重写）
function Expert_UpLv:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function Expert_UpLv:OnShow(index,_sortingOrder)
    activityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
    sortingOrder = _sortingOrder
    ActivityGiftManager.RefreshAcitvityData({activityId},function ()
        this:OnShowData()
    end)
end

function Expert_UpLv:OnSortingOrderChange(cursortingOrder)
    for i, v in pairs(itemList) do
        for j = 1, #v do
            v[j]:SetEffectLayer(cursortingOrder)
        end
    end
end

function Expert_UpLv:OnShowData()
    -- local globalActive = ConfigManager.GetConfigData(ConfigName.GlobalActivity,ActivityGiftManager.GetOpenExpertIdByActivityType(ActivityTypeDef.UpLvAct))
    activeData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.UpLvAct)
    PatFaceManager.RemainTimeDown2(this.timeGo, this.time, activeData.endTime - GetTimeStamp(), GetLanguageStrById(12547))
    table.sort(activeData.mission, function(a,b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return a.state < b.state
        end
    end)

    for i = 1, math.max(#activeData.mission, #expertRewardGrid) do
        local go = expertRewardGrid[i]
        if not go then
            go = newObject(this.rewardPre)
            go.transform:SetParent(this.grid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go.gameObject.name = i
            expertRewardGrid[i] = go
        end
        go.gameObject:SetActive(false)
    end

    for i = 1, #activeData.mission do
        this.SingleItemDataShow(expertRewardGrid[i], activeData.mission[i])
    end
end

function this.SingleItemDataShow(go,data)
    go:SetActive(true)

    local curConfigData = activityRewardConfig[data.missionId]
    if not itemList[go.name] then
        itemList[go.name] = {}
    end
    for i = 1, #curConfigData.Reward do
        if itemList[go.name][i] then
            itemList[go.name][i]:OnOpen(false, curConfigData.Reward[i], 0.55,false,false,false,sortingOrder)
        else
            itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "content").transform)
            itemList[go.name][i]:OnOpen(false, curConfigData.Reward[i], 0.55,false,false,false,sortingOrder)
        end
    end

    Util.GetGameObject(go, "title/Text"):GetComponent("Text").text =  GetLanguageStrById(10533).."<color=#FFD12B><size=38><b>"..curConfigData.Values[2][1].."</b></size></color>"..GetLanguageStrById(10534)..activeData.value .."/"..curConfigData.Values[2][1] ..")"
    local slider = Util.GetGameObject(go, "title/slider/Image"):GetComponent("Image")
    local btn = Util.GetGameObject(go, "btn")
    local redpoint = Util.GetGameObject(go, "btn/redPoint")
    local finished = Util.GetGameObject(go, "finished")
    Util.GetGameObject(go, "time"):GetComponent("Text").text = GetLanguageStrById(10055) .. data.progress .. GetLanguageStrById(10056)

    Util.SetGray(btn, not (data.state == 0) or not (activeData.value >= curConfigData.Values[2][1]))
    redpoint:SetActive(data.state == 0 and activeData.value >= curConfigData.Values[2][1])
    finished:SetActive(data.state == 1)
    slider.fillAmount = activeData.value / curConfigData.Values[2][1]

    Util.GetGameObject(btn, "Text"):GetComponent("Text").text = UIBtnText.get
    btn:SetActive(data.state ~= 1)
    if data.state == 0 then
        btn:GetComponent("Image").color = UIColorNew.YELLOW
    end

    Util.AddOnceClick(btn, function()
        NetManager.GetActivityRewardRequest(data.missionId, activityId, function(drop)
            UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function()
                this:OnShowData()
            end)
        end)
    end)
end

--界面关闭时调用（用于子类重写）
function Expert_UpLv:OnClose()

end

--界面销毁时调用（用于子类重写）
function Expert_UpLv:OnDestroy()

    sortingOrder = 0
end

return Expert_UpLv