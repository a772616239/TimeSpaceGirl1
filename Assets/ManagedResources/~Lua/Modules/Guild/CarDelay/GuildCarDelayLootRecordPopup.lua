require("Base/BasePanel")
GuildCarDelayLootRecordPopup = Inherit(BasePanel)
local this = GuildCarDelayLootRecordPopup
local carChallengeItem--后端数据
local allLootRecordData = {}
local recordPerList = {}
local titleText = {}
--初始化组件（用于子类重写）
function GuildCarDelayLootRecordPopup:InitComponent()
    this.BackBtn = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.emptyObj = Util.GetGameObject(self.gameObject, "bg/emptyObj")
    this.rect = Util.GetGameObject(self.gameObject, "bg/rect")
    for i = 1, 3 do
        recordPerList[i] = Util.GetGameObject(self.gameObject, "bg/rect/grid/ver/recordPer (".. i ..")")
        titleText[i] = {}
        titleText[i][1] = Util.GetGameObject(self.gameObject, "bg/rect/grid/ver/recordPer (".. i ..")/Mask/recordTex (1)")
    end
end

--绑定事件（用于子类重写）
function GuildCarDelayLootRecordPopup:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildCarDelayLootRecordPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildCarDelayLootRecordPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildCarDelayLootRecordPopup:OnOpen(msg)
    carChallengeItem = msg
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildCarDelayLootRecordPopup:OnShow()
    local curallLootRecordData = {}
    
    --table.sort(carChallengeItem.carChallengeItem, function(a,b) return a.time > b.time end)
    for i = 1, #carChallengeItem.carChallengeItem do
        if carChallengeItem.carChallengeItem[i] and carChallengeItem.carChallengeItem[i].content ~= "" then
            local timeStr = os.date("%Y%m%d",carChallengeItem.carChallengeItem[i].time)
            if not curallLootRecordData[timeStr]  then
                curallLootRecordData[timeStr] = {}
                table.insert(curallLootRecordData[timeStr],carChallengeItem.carChallengeItem[i])
            else
                table.insert(curallLootRecordData[timeStr],carChallengeItem.carChallengeItem[i])
            end
        end
    end
    local isShowEmptyObj = true
    allLootRecordData = {}
    for i, v in pairs(curallLootRecordData) do
        table.insert(allLootRecordData,v)
    end

    for i = 1, #recordPerList do
        if allLootRecordData[i] and  #allLootRecordData[i] > 0 then
            Util.GetGameObject(recordPerList[i], "titleImage/titleImage/titleText"):GetComponent("Text").text = this.TimeStampToDateString(allLootRecordData[i][1].time,2)
            for k = 1, #titleText[i] do
                titleText[i][k]:SetActive(false)
            end
            for j = 1, #allLootRecordData[i] do
                if titleText[i][j] then
                    titleText[i][j]:GetComponent("Text").text = allLootRecordData[i][j].content
                    Util.GetGameObject(titleText[i][j], "Image/Text"):GetComponent("Text").text = "["..this.TimeStampToDateString(allLootRecordData[i][j].time,1).."]"
                else
                   local go=newObject(titleText[i][1])
                    go.transform:SetParent(Util.GetGameObject(recordPerList[i], "Mask").transform)
                    go.transform.localScale = Vector3.one
                    go.transform.localPosition = Vector3.zero
                    titleText[i][j] = go
                    titleText[i][j]:GetComponent("Text").text = allLootRecordData[i][j].content
                    Util.GetGameObject(titleText[i][j], "Image/Text"):GetComponent("Text").text = "["..this.TimeStampToDateString(allLootRecordData[i][j].time,1).."]"
                end
                titleText[i][j]:SetActive(true)
                Util.AddOnceClick(titleText[i][j], function()
                    UIManager.OpenPanel(UIName.PlayerInfoPopup, allLootRecordData[i][j].uid)
                end)
            end
            isShowEmptyObj = false
            recordPerList[i]:SetActive(true)
        else
            recordPerList[i]:SetActive(false)
        end
    end
    this.emptyObj:SetActive(isShowEmptyObj)
end

function this.TimeStampToDateString(second,type)
    if type == 1 then
        return os.date("%H:%M:%S", second)
    elseif type == 2 then
        --if second - GetTimeStamp() then
        local curtimeStr = os.date(GetLanguageStrById(11030), GetTimeStamp())
        local secondtimeStr = os.date(GetLanguageStrById(11030), second)
        if curtimeStr == secondtimeStr then
            return GetLanguageStrById(11031)
        else
            return secondtimeStr
        end
    end
end

--界面关闭时调用（用于子类重写）
function GuildCarDelayLootRecordPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildCarDelayLootRecordPopup:OnDestroy()
end

return GuildCarDelayLootRecordPopup