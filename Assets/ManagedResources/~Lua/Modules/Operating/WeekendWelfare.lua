local WeekendWelfare = quick_class("WeekendWelfare")

local bgSprite = {
    "cn2-X1_zhoumofuli_wupingdi_01",
    "cn2-X1_zhoumofuli_wupingdi_02",
}

function WeekendWelfare:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self.itemList = {}
end

-- 初始化组件
function WeekendWelfare:InitComponent(gameObject)
end

function WeekendWelfare:BindEvent()
end

function WeekendWelfare:AddEvent()
end

function WeekendWelfare:RemoveEvent()
end

function WeekendWelfare:OnShow(parentSorting, arg, pageIndex)
    self.gameObject:SetActive(true)
    CheckRedPointStatus(RedPointType.WeekendWelfare)
    local curWeek = GetSeverWeek()
    local activityId = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.WeekendWelfare).activityId
    local rewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", activityId)
    for index, v in ipairs(rewardConfig) do
        local go = Util.GetGameObject(self.gameObject, "gift"..index)
        if self.itemList[go] then
            for i = 1, #v.Reward do
                if not self.itemList[go][i] then
                    self.itemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "itemGrid").transform)
                end
                self.itemList[go][i].gameObject:SetActive(false)
            end
            for i = 1, #v.Reward do
                if self.itemList[go][i] then
                    self.itemList[go][i]:OnOpen(false, {v.Reward[i][1], v.Reward[i][2]}, 0.45)
                    self.itemList[go][i].gameObject:SetActive(true)
                end
            end
        else
            self.itemList[go] = {}
            for i = 1, #v.Reward do
                self.itemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "itemGrid").transform)
                self.itemList[go][i].gameObject:SetActive(false)
            end
            for i = 1, #v.Reward do
                self.itemList[go][i]:OnOpen(false, {v.Reward[i][1], v.Reward[i][2]}, 0.5)
                self.itemList[go][i].gameObject:SetActive(true)
            end
        end

        Util.GetGameObject(go, "mask"):SetActive(true)
        Util.GetGameObject(go, "received"):SetActive(false)
        Util.GetGameObject(go, "redpoint"):SetActive(false)
        Util.GetGameObject(go, "received"):SetActive(true)

        local receivedText = Util.GetGameObject(go, "received/Text"):GetComponent("Text")
        local misson = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.WeekendWelfare).mission[index]
        if v.Values[2][1] == curWeek then
            if misson.state == 0 then
                go:GetComponent("Image").sprite = Util.LoadSprite(bgSprite[2])
                Util.GetGameObject(go, "mask"):SetActive(false)
                Util.GetGameObject(go, "redpoint"):SetActive(true)
                Util.GetGameObject(go, "received"):SetActive(false)
            else
                go:GetComponent("Image").sprite = Util.LoadSprite(bgSprite[1])
                receivedText.text = GetLanguageStrById(50219) --已领取
                Util.GetGameObject(go, "received"):SetActive(true)
            end
        else
            if misson.state == 1 then
                receivedText.text = GetLanguageStrById(50219)
                Util.GetGameObject(go, "received"):SetActive(true)
            else
                if curWeek == 6 then
                    receivedText.text = GetLanguageStrById(50220)--未开启
                elseif curWeek == 0 then
                    if v.Values[2][1] == 6 then
                        receivedText.text = GetLanguageStrById(50221)--已过期
                    else
                        receivedText.text = GetLanguageStrById(50220)
                    end
                else
                    receivedText.text = GetLanguageStrById(50221)--已过期
                end
            end
            go:GetComponent("Image").sprite = Util.LoadSprite(bgSprite[1])
        end

        Util.AddOnceClick(go, function ()
            if v.Values[2][1] ~= curWeek or misson.state ~= 0 then
                return
            end
            NetManager.GetActivityRewardRequest(v.Id, activityId, function(drop)
                UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function()
                    self:OnShow()
                end)
            end)
        end)
    end
end

function WeekendWelfare:OnHide()
    self.gameObject:SetActive(false)
end

return WeekendWelfare