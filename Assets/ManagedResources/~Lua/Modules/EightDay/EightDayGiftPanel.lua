require("Base/BasePanel")
local EightDayGiftPanel = Inherit(BasePanel)
local this = EightDayGiftPanel

local EightDayRewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", ActivityTypeDef.EightDayGift)
local ItemList = {}--奖励List
local ItemViewList = {}
local rewardData--后端数据
local curDay--当前天数

--初始化组件（用于子类重写）
function this:InitComponent()
    this.btnClose = Util.GetGameObject(this.gameObject,"mask")
    this.BtnBack = Util.GetGameObject(this.gameObject,"BtnBack")	
    this.btnPreview = Util.GetGameObject(this.gameObject,"panel/bg/btnPreview")
    this.show = Util.GetGameObject(this.gameObject,"panel/show")--根节点
    this.itemPre = Util.GetGameObject(this.gameObject,"panel/show/itemPre")--预设
    this.effect = Util.GetGameObject(this.gameObject,"panel/effect")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.btnClose,function()
        this:ClosePanel()
    end)
    Util.AddClick(this.BtnBack,function()
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
    ItemList = {}
    ItemViewList = {}
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
end

function this:Refresh()
    rewardData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.EightDayGift)
    curDay = math.ceil((CalculateSecondsNowTo_N_OClock(24) + GetTimeStamp() - PlayerManager.userCreateTime)/86400)
    if curDay > 8 then
        curDay = 8
    end
    this:SetAllReward()
end

function this:SetAllReward()
    for i = 1, #EightDayRewardConfig do
        local item = ItemList[i]
        if not item then
            item = newObject(this.itemPre)
            item.name = "itemPre_"..i
            item.transform:SetParent(this.show.transform)
            item.transform.localScale = Vector3.one
            item.transform.localPosition = Vector3.zero
            ItemList[i] = item
        end
        item.gameObject:SetActive(true)
        this:SetSingleReward(item, i)
    end
end

function this:SetSingleReward(item, i)
    local kuang = Util.GetGameObject(item, "kuang"):GetComponent("Image")
    local day = Util.GetGameObject(item, "kuang/reward/days/Text"):GetComponent("Text")
    local dayImg = Util.GetGameObject(item, "kuang/reward/days"):GetComponent("Image")
    local icon = Util.GetGameObject(item, "kuang/reward/icon")
    local get = Util.GetGameObject(item, "getBtn")
    local redPoint = Util.GetGameObject(item, "redPoint")
    local mask = Util.GetGameObject(item, "kuang/reward/mask")
    local transparency = Util.GetGameObject(item, "kuang/reward/transparency")
    local isCanGet = rewardData.mission[i].state--是否可领取

    if i == curDay then 
        item:GetComponent("Image").color = Color.New(255/255,238/255,34/255,255/255)
        Util.GetGameObject(item,"Image"):GetComponent("Image").color = Color.New(233/255,155/255,19/255,255/255)
    end

    day.text = TimeToHMS(CalculateSecondsNowTo_N_OClock(24))
    if i == curDay+1 then
       this:SetRemainTime(day,i)
       dayImg.enabled = false
    else
        dayImg.enabled = true
        day.text = --[[GetLanguageStrById(10311)..NumToSimplenessFont[i]..]]GetLanguageStrById(10021)
        dayImg.sprite = Util.LoadSprite("cn2-X1_baridenglu_tian_0" .. i)
    end

    --奖励的Icon
    if not ItemViewList[i] then
        local view = SubUIManager.Open(SubUIConfig.ItemView,icon.transform)
        ItemViewList[i] = view
    end
    ItemViewList[i]:OnOpen(false,EightDayRewardConfig[i].Reward[1],1,false)

    --2\3\8可领取的金框
    if i == 2 or i == 3 or i == 8 then
        kuang.enabled = true--isCanGet == 0 and curDay >= i
    end

    get:SetActive(isCanGet == 0 and curDay >= i)
    mask:SetActive(isCanGet == 1)

    if i <= curDay then
        if isCanGet == 1 then
            dayImg.color = Color.New(255/255,255/255,255/255,127/255)
            day.color = Color.New(255/255,255/255,255/255,127/255)
            Util.GetGameObject(item,"Image"):GetComponent("Image").color = Color.New(139/255,91/255,218/255,127/255)
            transparency:SetActive(true)
            item:GetComponent("Image").color = Color.New(163/255,124/255,228/255,255/255)
        else
            item:GetComponent("Image").color = Color.New(255/255,209/255,43/255,255/255)
            Util.GetGameObject(item,"Image"):GetComponent("Image").color = Color.New(233/255,155/255,19/255,255/255)
        end
    end

    redPoint:SetActive(false)
    if isCanGet == 0 then
        if curDay >= i then
            redPoint:SetActive(true)
        end
    end

    Util.AddOnceClick(get,function()
        if isCanGet ~= 0 then
            return
        end
        if curDay >= i then
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
                    UIManager.OpenPanel(UIName.PublicGetHeroPanel, itemDataList, itemDataStarList,function ()
                        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                            ActivityGiftManager.sevenDayGetRewardState[i] = 1
                            this:SetAllReward()
                            Game.GlobalEvent:DispatchEvent(GameEvent.EightDay.GetRewardSuccess)
                            CheckRedPointStatus(RedPointType.EightTheLogin)
                        end)
                    end)
                else
                    UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                        ActivityGiftManager.sevenDayGetRewardState[i] = 1
                        this:SetAllReward()
                        Game.GlobalEvent:DispatchEvent(GameEvent.EightDay.GetRewardSuccess)
                        CheckRedPointStatus(RedPointType.EightTheLogin)
                    end)
                end
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10472)
        end
    end)
end

function this:SetRemainTime(day, i)
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

return EightDayGiftPanel