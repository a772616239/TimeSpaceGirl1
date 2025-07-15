require("Base/BasePanel")
local SignInDays = Inherit(BasePanel)
local this = SignInDays

local orginLayer = 0
local ActRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ArtConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local ActivityRewardConfig
local ItemList = {}--奖励List
local ItemViewList = {}
local rewardData--后端数据
local curDay--当前天数

--初始化组件（用于子类重写）
function this:InitComponent()
    this.mask = Util.GetGameObject(this.gameObject, "mask")
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.grid = Util.GetGameObject(this.gameObject, "grid")
    this.itemPre = Util.GetGameObject(this.gameObject, "grid/itemPre")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.mask, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

function this:OnSortingOrderChange()
    orginLayer = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
end

-- 打开，重新打开时回调
function this:OnShow()
    this:Refresh()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    orginLayer = 0
    ItemList = {}
    ItemViewList = {}
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
end

function this:Refresh()
    rewardData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SignInDays)
    curDay = math.ceil((CalculateSecondsNowTo_N_OClock(24) +  GetTimeStamp() - rewardData.startTime)/86400)
    ActivityRewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId", rewardData.activityId)
    table.sort(rewardData.mission, function (a, b)
        return a.missionId < b.missionId
    end)
    this:SetAllReward()
end

function this:SetAllReward()
    for i = 1, #ActivityRewardConfig do
        local item = ItemList[i]
        if not item then
            item = newObject(this.itemPre)
            item.name = "itemPre_"..i
            item.transform:SetParent(this.grid.transform)
            item.transform.localScale = Vector3.one
            item.transform.localPosition = Vector3.zero
            ItemList[i] = item
        end
        item.gameObject:SetActive(true)
        this:SetSingleReward(item, i)
    end
end

local itemColor = {
    [1] = {--可领取
        Color.New(255/255,238/255,34/255,255/255),
        Color.New(233/255,155/255,19/255,255/255)
    },
    [2] = {--常态
        Color.New(163/255,124/255,228/255,255/255),
        Color.New(139/255,91/255,218/255,127/255)
    }
}

function this:SetSingleReward(item, i)
    local day = Util.GetGameObject(item, "frame/reward/days/Text"):GetComponent("Text")
    local dayImg = Util.GetGameObject(item, "frame/reward/days"):GetComponent("Image")
    local icon = Util.GetGameObject(item, "frame/reward/icon")
    local get = Util.GetGameObject(item, "getBtn")
    local redPoint = Util.GetGameObject(item, "redPoint")
    local received = Util.GetGameObject(item, "frame/reward/received")--已领取
    local mask = Util.GetGameObject(item, "frame/reward/mask")
    local bg = Util.GetGameObject(item, "Image"):GetComponent("Image")
    local expired = Util.GetGameObject(item, "frame/reward/expired")--已过期

    --暂时 白图 待修复
    expired:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_tongyong_yiguoqi"))

    --倒计时
    if i == curDay+1 then
        this:SetRemainTime(day, i)
        dayImg.enabled = false
        day.text = TimeToHMS(CalculateSecondsNowTo_N_OClock(24))
    else
        dayImg.enabled = true
        day.text = GetLanguageStrById(10021)
        dayImg.sprite = Util.LoadSprite("cn2-X1_baridenglu_tian_0" .. i)
    end

    if i == curDay then
        if rewardData.mission[i].state == 1 then--已领取
            dayImg.color = UIColor.WHITETOGRAY
            day.color = UIColor.WHITETOGRAY
            item:GetComponent("Image").color = itemColor[2][1]
            bg.color = itemColor[2][2]
        else--可领取
            item:GetComponent("Image").color = itemColor[1][1]
            bg.color = itemColor[1][2]
        end
    else
        dayImg.color = UIColor.WHITETOGRAY
        day.color = UIColor.WHITETOGRAY
        item:GetComponent("Image").color = itemColor[2][1]
        bg.color = itemColor[2][2]
    end

    --奖励的Icon
    if not ItemViewList[i] then
        ItemViewList[i] = SubUIManager.Open(SubUIConfig.ItemView,icon.transform)
    end
    ItemViewList[i]:OnOpen(false, ActivityRewardConfig[i].Reward[1], 1)

    expired:SetActive(rewardData.mission[i].state == 0 and curDay > i)
    mask:SetActive(rewardData.mission[i].state == 1 or curDay > i)
    received:SetActive(rewardData.mission[i].state == 1)
    get:SetActive(rewardData.mission[i].state == 0 and curDay == i)
    redPoint:SetActive(rewardData.mission[i].state == 0 and curDay == i)

    Util.AddOnceClick(get,function()
        if rewardData.mission[i].state ~= 0 then
            return
        end
        if curDay == i then
            NetManager.GetActivityRewardRequest(rewardData.mission[i].missionId, rewardData.activityId, function(drop)
                --获得英雄表现
                if drop.Hero ~= nil and #drop.Hero > 0 then
                    local itemDataList = {}
                    local itemDataStarList = {}
                    for i = 1, #drop.Hero do
                        local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", drop.Hero[i].heroId)
                        table.insert(itemDataList, heroData)
                        table.insert(itemDataStarList, drop.Hero[i].star)
                    end
                    UIManager.OpenPanel(UIName.PublicGetHeroPanel,itemDataList,itemDataStarList,function ()
                        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                            ActivityGiftManager.sevenDayGetRewardState[i] = 1
                            this:SetAllReward()
                            Game.GlobalEvent:DispatchEvent(GameEvent.EightDay.GetRewardSuccess)
                            CheckRedPointStatus(RedPointType.EightTheLogin_2)
                        end)
                    end)
                else
                    UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                        ActivityGiftManager.sevenDayGetRewardState[i] = 1
                        this:SetAllReward()
                        Game.GlobalEvent:DispatchEvent(GameEvent.EightDay.GetRewardSuccess)
                        CheckRedPointStatus(RedPointType.EightTheLogin_2)
                    end)
                end
            end)
        else
            if curDay < i then
                PopupTipPanel.ShowTipByLanguageId(10472)--未到领取时间
            elseif curDay > i then
                --过期
            end
        end
    end)
end

function this:SetRemainTime(day)
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    if not self.localTimer then
        self.localTimer = Timer.New(function ()
            local t = CalculateSecondsNowTo_N_OClock(24)
            if t-1 < 0 then
                Timer.New(function()
                    this:Refresh()
                end, 1, 1, true):Start()
            end
            day.text = TimeToHMS(t)
        end, 1, -1, true)
        self.localTimer:Start()
    end
end

return SignInDays