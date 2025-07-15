---@class EightDayRewardItem
local EightDayRewardItem = quick_class("EightDayRewardItem")
local itemDayList={GetLanguageStrById(10005),GetLanguageStrById(10006),GetLanguageStrById(10007),GetLanguageStrById(10008),GetLanguageStrById(10009),GetLanguageStrById(10010),GetLanguageStrById(10011),GetLanguageStrById(10012)}
local Gift = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",ActivityTypeDef.EightDayGift)
-- local data
-- local giftData

---@param transform UnityEngine.Transform
function EightDayRewardItem:ctor(mainPanel, transform,iDay)

    self.data = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.EightDayGift)
    -- giftData = ActivityGiftManager.sevenDayGetRewardState

    self.mainPanel = mainPanel
    self.transform = transform
    self.iDay = iDay
    
    self.day = Util.GetGameObject(self.transform, "Content/Day"):GetComponent("Text")
    self.day.text=string.format(GetLanguageStrById(10473),itemDayList[self.iDay])--GetLanguageStrById(10311)..i..GetLanguageStrById(10021)
    self.reward = Util.GetGameObject(self.transform, "Content/Reward")
    self.receivedFlag = Util.GetGameObject(self.transform, "Content/receivedFlag")
    
    self.Btn = Util.GetGameObject(self.transform, "Btn"):GetComponent("Button")
    self.Btn.interactable = false
    --Util.SetGray(self.Btn.gameObject,true)--置灰

    self.Text1 = Util.GetGameObject(self.transform, "Btn/Text"):GetComponent("Text")
    self.redPoint = Util.GetGameObject(self.transform,"Btn/redPoint")
    
    local item=SubUIManager.Open(SubUIConfig.ItemView,self.reward.transform)
    local actData= ConfigManager.GetConfigDataByDoubleKey(ConfigName.ActivityRewardConfig,"Id",self.data.mission[iDay].missionId,"ActivityId",ActivityTypeDef.EightDayGift)
    item:OnOpen(false, {actData.Reward[1][1], actData.Reward[1][2]}, 0.8,false)--data.mission[iDay].missionId
    item:ResetNameColor(Vector4.New(50/255,50/255,50/255,1))
    item:ResetNameSize(Vector3.New(5,-100,0),Vector3.New(1.3,1.3,1))
    self:Refresh()
end

function EightDayRewardItem:OnBtnClicked(i)
    self.redPoint:SetActive(false)--红点
    self.receivedFlag:SetActive(true)--领取成功
    self.Btn.interactable = false--按钮是否可以点击
    Util.SetGray(self.Btn.gameObject,true)--置灰

    NetManager.GetActivityRewardRequest(self.data.mission[i].missionId, self.data.activityId, function(drop)
        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
            ActivityGiftManager.sevenDayGetRewardState[i] = 1
            self:Refresh()
            Game.GlobalEvent:DispatchEvent(GameEvent.EightDay.GetRewardSuccess)
        end)
    end)
end

function EightDayRewardItem:Refresh()
    local iDay = self.iDay
    local canRewardDay = self.data.mission[iDay].progress

    for i,v in pairs(self.data.mission) do 
        if v.missionId == iDay then
            self.Text1.text = Gift[iDay].ContentsShow
            if  canRewardDay >= iDay then--已经达成的天数
                local state = ActivityGiftManager.sevenDayGetRewardState[i]
                if state == 0 then--奖励未领取
                    self.redPoint:SetActive(true)
                    self.Btn.interactable = true
                    Util.AddOnceClick(self.Btn.gameObject, function()
                        self:OnBtnClicked(i)
                    end)

                elseif (state == 1) then--奖励已领取
                    self.redPoint:SetActive(false)
                    self.receivedFlag:SetActive(true)
                    Util.SetGray(self.Btn.gameObject,true)
                end
            end
        end
    end
end

return EightDayRewardItem