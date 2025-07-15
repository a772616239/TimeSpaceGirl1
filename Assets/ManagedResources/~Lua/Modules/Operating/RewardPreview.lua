local RewardPreview = quick_class("RewardPreview")
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local data = {}
local listPre = {}
local curtimes = 0
local intervalDatas={}
function RewardPreview:ctor(gameObject)
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self:OnShow()
end

function RewardPreview:InitComponent(gameObject)
    self.closeBtn = Util.GetGameObject(self.gameObject, "close")
    self.itemGrid = Util.GetGameObject(self.gameObject, "itemGrid")
    self.itemPre = Util.GetGameObject(self.gameObject, "itemprefab")
    self.curtimes = Util.GetGameObject(self.gameObject, "tip1"):GetComponent("Text")
    self.sliderWidth = Util.GetGameObject(self.gameObject, "Background"):GetComponent("RectTransform").sizeDelta.x
    self.slider = Util.GetGameObject(self.gameObject, "Background/Fill"):GetComponent("Image")
end

function RewardPreview:BindEvent()
    Util.AddClick(
        self.closeBtn.gameObject,
        function()
            self:OnHide()
        end
    )
end

function RewardPreview:OnShow()
    self.gameObject:SetActive(true)
    local maxtimesId = lotterySetting[RecruitType.TimeLimitSingle].MaxTimes
    curtimes = OperatingManager.TimeLimitedTimes  
    self:RefreshRewarid()
    self.curtimes.text = GetLanguageStrById(12181) .. curtimes
    self.slider.fillAmount = self:CalculateInterval(curtimes)
end

function RewardPreview:RefreshRewarid()
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    data = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", curActivityId)
    local tmp = 0
    --间隔的总次数  比如：30 60 120 210 300  count=（60-30）+ （120 - 60）+ （210 - 120）+ （300 - 210）= 300 - 30 =270
    local count = 0
    -- for n,m in ipairs(data) do
    --     if n~=1 then
    --         count = count + m.Values[1][1]-tmp
    --     end
    --     tmp = m.Values[1][1]
    --     --self.slider.fillAmount = curtimes /  m.Values[1][1]
    -- end
    count = data[#data].Values[1][1]
    tmp = 0
    local position = 0
    local width = self.itemPre.transform:GetComponent("RectTransform").sizeDelta.x
    local interval = self.itemGrid.transform:GetComponent("RectTransform").sizeDelta.x - (width * #data)
    if (not listPre) then
        listPre = {}
    end
    local index = 1
    for n, m in ipairs(data) do       
        if m then
            if not listPre[n] then
                listPre[n] = newObjToParent(self.itemPre, self.itemGrid)
                listPre[n].gameObject:SetActive(true)
            end
            local o = SubUIManager.Open(SubUIConfig.ItemView, listPre[n].transform)
            o:OnOpen(false, {m.Reward[1][1], m.Reward[1][2]}, 1.1, true)
            o.gameObject:SetActive(true)
            Util.GetGameObject(listPre[n].gameObject, "progress"):GetComponent("Text").text = m.Values[1][1]
            local tempinterval = (m.Values[1][1] - tmp) / count * interval
            if n == 1 then
                position = tempinterval
            else
                position = tempinterval + width + position
            end
            
            listPre[n].transform:GetComponent("RectTransform").anchoredPosition3D = Vector3.New(position, 0, 0)
            
            intervalDatas[index] =tonumber(string.format("%.2f", (position + width / 2) / self.sliderWidth))
            index = index + 1 
            tmp = m.Values[1][1]
        end
    end
end

function RewardPreview:CalculateInterval(count)
    local width = self.itemPre.transform:GetComponent("RectTransform").sizeDelta.x  
    if not data or #data < 1 then
        local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
        data = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", curActivityId)
    end
    
    -- for n,m in ipairs(intervalDatas) do
    
    -- end
    local interval = 0           
    if count >= data[5].Values[1][1] then
        interval = intervalDatas[5] + (curtimes - data[5].Values[1][1]) * (1-intervalDatas[5])/(500-data[5].Values[1][1])
        if interval > 1 then
            interval = 1
        end
    elseif count >= data[4].Values[1][1] then
        interval = intervalDatas[4] +(count - data[4].Values[1][1]) * (intervalDatas[5] - intervalDatas[4]) / (data[5].Values[1][1] - data[4].Values[1][1])
    elseif count >= data[3].Values[1][1] then
        interval = intervalDatas[3] + (count - data[3].Values[1][1]) * (intervalDatas[4] - intervalDatas[3]) / (data[4].Values[1][1] - data[3].Values[1][1])
    elseif count >= data[2].Values[1][1] then
        interval = intervalDatas[2] + (count - data[2].Values[1][1]) * (intervalDatas[3] - intervalDatas[2]) / (data[3].Values[1][1] - data[2].Values[1][1])
    elseif count >= data[1].Values[1][1] then
        interval = intervalDatas[1] + (count - data[1].Values[1][1]) * (intervalDatas[2] - intervalDatas[1]) / (data[2].Values[1][1] - data[1].Values[1][1])
    else
        interval = count * intervalDatas[1] / data[1].Values[1][1]
    end
    return interval
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