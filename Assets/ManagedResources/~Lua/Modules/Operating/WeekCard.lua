local WeekCard = quick_class("WeekCard")
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local daySprite = {
    "cn2-X1_fuli_zhoukajiangli_01",
    "cn2-X1_fuli_zhoukajiangli_02",
    "cn2-X1_fuli_zhoukajiangli_03",
}
function WeekCard:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()

    self.itemList = {}
end

-- 初始化组件
function WeekCard:InitComponent(gameObject)
    self.btnBuy = Util.GetGameObject(gameObject, "btnBuy")
    self.time = Util.GetGameObject(gameObject, "time/Text"):GetComponent("Text")

    self.dayItemList = {}
    for i = 1, 7 do
        self.dayItemList[i] = Util.GetGameObject(gameObject, "itemGrid/day"..i)
    end
    self.reward = Util.GetGameObject(gameObject, "tip/value"):GetComponent("Text")
    --Util.GetGameObject(gameObject, "Text"):GetComponent("Text")
end

function WeekCard:BindEvent()
    Util.AddClick(self.btnBuy, function ()
        if self.isCanBuy then
            local state = OperatingManager.GetLeftBuyTime(GoodsTypeDef.NewWeekCard, self.rechargConfig.Id)
            if not GetChannerConfig().Rechargemode_Mail then
                if not (state > 0) then
                    PopupTipPanel.ShowTipByLanguageId(50235)
                    return
                end
            end
             if AppConst.isSDKLogin then
                 PayManager.Pay({ Id = self.rechargConfig.Id }, function()
                     FirstRechargeManager.RefreshAccumRechargeValue(self.rechargConfig.Id)
                     self:OnShow()
                 end)
             else
                 NetManager.RequestBuyGiftGoods(self.rechargConfig.Id, function()
                     FirstRechargeManager.RefreshAccumRechargeValue(self.rechargConfig.Id)
                     self:OnShow()
                 end)
             end
        else
            NetManager.GetActivityRewardRequest(0, self.activityId, function(drop)
                UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function()
                    self:OnShow()
                end)
            end)
        end
    end)
end

function WeekCard:AddEvent()
end

function WeekCard:RemoveEvent()
end

function WeekCard:OnShow(parentSorting, arg, pageIndex)
    self.gameObject:SetActive(true)
    if PlayerPrefs.GetInt(PlayerManager.uid .. "WeekCardFirstOpen") ~= 1 then
        PlayerPrefs.SetInt(PlayerManager.uid .. "WeekCardFirstOpen", 1)
    end

    CheckRedPointStatus(RedPointType.WeekCard)

    local data = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.WeekCard)
    local activityConfig = GlobalActivity[data.activityId]
    self.activityId = data.activityId
    self.rechargConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, activityConfig.CanBuyRechargeId[1])

    self.reward.text = self.rechargConfig.RewardShow[1][2]
    local time = 0--已经累计的时间
    PatFaceManager.RemainTimeDown2(self.time.gameObject, self.time, data.endTime - GetTimeStamp())
    if data.value > 0 then
        self.isCanBuy = false--是否已经购买

        time = math.ceil((GetTimeStamp() - data.startTime) / (24 * 3600)) --向上取整 1.2 天 算 2天
        if time < 1 then
            time = 1
        end
        -- self.reward.text = ""
        Util.SetGray(self.btnBuy, true)
        Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text").text = UIBtnText.geted
    else
        self.isCanBuy = true

        --激活立得
        -- local str = GetLanguageStrById(50352) .. ":"
        -- for i = 1, #self.rechargConfig.RewardShow do
        --     str = str .. GetLanguageStrById(itemConfig[self.rechargConfig.RewardShow[i][1]].Name) .. "x" .. self.rechargConfig.RewardShow[i][2]
        --     if i ~= #self.rechargConfig.RewardShow then
        --         str = str .. "+"
        --     end
        -- end
        -- self.reward.text = str

        Util.SetGray(self.btnBuy, false)
        Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text").text = MoneyUtil.GetMoney(self.rechargConfig.Price)
    end

    local rewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", self.activityId)
    table.sort(rewardConfig,function(a, b) 
        return a.Id < b.Id
    end)

    for i = 1, #rewardConfig do
        Util.GetGameObject(self.dayItemList[i], "received"):SetActive(false)
        if not self.itemList[i] then
            self.itemList[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(self.dayItemList[i], "pos").transform)
        end
        self.itemList[i]:OnOpen(false, {rewardConfig[i].Reward[1][1], rewardConfig[i].Reward[1][2]}, 0.75)
        self.itemList[i].gameObject:SetActive(true)

        table.sort(data.mission,function(a, b) 
            return a.missionId < b.missionId
        end)

        for j = 1, #data.mission do
            -- LogError(j.." missid:".. data.mission[j].missionId.." mission state:"..data.mission[j].state.." startTime"..self:getTimeStamp(data.startTime).." oridataTime:"..data.startTime)
            if data.mission[j].missionId == rewardConfig[i].Id then
                if rewardConfig[i].Values[2][1] <= time then
                    if data.mission[j].state == 0 then
                        Util.SetGray(self.btnBuy, false)
                        Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text").text = UIBtnText.get
                        self.dayItemList[i]:GetComponent("Image").sprite = Util.LoadSprite(daySprite[2])
                    else
                        self.dayItemList[i]:GetComponent("Image").sprite = Util.LoadSprite(daySprite[3])
                        Util.GetGameObject(self.dayItemList[i], "received"):SetActive(true)
                    end
                else
                    self.dayItemList[i]:GetComponent("Image").sprite = Util.LoadSprite(daySprite[1])
                end
            end
        end
    end
end

function WeekCard:OnHide()
    self.gameObject:SetActive(false)
end

-- 时间戳转化
function WeekCard:getTimeStamp(t)
    return os.date("%Y-%m-%d %H:%M:%S",t)
end

return WeekCard