local RewardPreview = quick_class("RewardPreview")
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local data = {}
local listPre = {}
local curtimes = 0

function RewardPreview:ctor(gameObject, sortingOrder)
    self.gameObject = gameObject
    self:InitComponent()
    self:BindEvent()
    self:OnShow()

    gameObject:GetComponent("Canvas").sortingOrder = sortingOrder + 1
end

function RewardPreview:InitComponent()
    self.closeBtn = Util.GetGameObject(self.gameObject, "close")
    self.itemGrid = Util.GetGameObject(self.gameObject, "itemGrid")
    self.itemPre = Util.GetGameObject(self.gameObject, "itemprefab")
    self.curtimes = Util.GetGameObject(self.gameObject, "tip2/Text"):GetComponent("Text")
    self.slider = Util.GetGameObject(self.gameObject, "Slider"):GetComponent("Slider")
    self.pos = Util.GetGameObject(self.gameObject, "Slider/Fill Area/Fill/pos")
end

function RewardPreview:BindEvent()
    Util.AddClick(
        self.closeBtn.gameObject,
        function()
            self:OnHide()
        end
    )
end

local d1,d2
function RewardPreview:OnShow()
    self.gameObject:SetActive(true)
    -- local maxtimesId = lotterySetting[RecruitType.TimeLimitSingle].MaxTimes
    curtimes = OperatingManager.TimeLimitedTimes
    self:RefreshRewarid()
    self.curtimes.text = curtimes

    if curtimes <= d1 then
        self.slider.value = curtimes
    elseif curtimes > d1 and curtimes < d2 then
        self.slider.value = curtimes + d1
    else
        self.slider.value = curtimes + d1
    end
end

function RewardPreview:RefreshRewarid()
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    data = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", curActivityId)
    if not listPre then
        listPre = {}
    end

    self.slider.maxValue = data[#data].Values[1][1]
    d1 = data[1].Values[1][1]
    d2 = data[3].Values[1][1]

    for n, m in ipairs(data) do
        if m then
            if not listPre[n] then
                listPre[n] = newObjToParent(self.itemPre, self.itemGrid)
                listPre[n].gameObject:SetActive(true)
            end
            local o = SubUIManager.Open(SubUIConfig.ItemView, listPre[n].transform)
            o:OnOpen(false, {m.Reward[1][1], m.Reward[1][2]}, 0.65, true)
            o.gameObject:SetActive(true)
            Util.GetGameObject(listPre[n].gameObject, "progress"):GetComponent("Text").text = m.Values[1][1]
            if m.Values[1][1] <= d1 then
                self.slider.value = m.Values[1][1]
            elseif curtimes > d1 and curtimes < d2 then
                self.slider.value = m.Values[1][1] + d1
            else
                self.slider.value = m.Values[1][1] + d1
            end
            listPre[n].transform.position = self.pos.transform.position
            local posx = listPre[n].transform.localPosition.x - 79
            listPre[n].transform:GetComponent("RectTransform").anchoredPosition3D = Vector3.New(posx, 0, 0)
        end
    end
end

function RewardPreview:OnHide()
    self.gameObject:SetActive(false)
    data = {}
end

function RewardPreview:OnDestroy()
    listPre = nil
    data = nil
end

return RewardPreview