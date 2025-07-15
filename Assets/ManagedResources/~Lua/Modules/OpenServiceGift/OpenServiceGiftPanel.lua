require("Base/BasePanel")
OpenServiceGiftPanel = Inherit(BasePanel)
local this = OpenServiceGiftPanel
local itemList = {}

function OpenServiceGiftPanel:InitComponent()
    this.btnMask = Util.GetGameObject(this.gameObject, "mask")
    this.pre = Util.GetGameObject(this.gameObject, "bg/pre")
    this.grid = Util.GetGameObject(this.gameObject, "bg/grid")
    this.btnGet = Util.GetGameObject(this.gameObject, "btnGet")
    this.btnGetTxt = Util.GetGameObject(this.gameObject, "btnGet/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function OpenServiceGiftPanel:BindEvent()
    Util.AddClick(this.btnMask, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function OpenServiceGiftPanel:AddListener()
end

--移除事件监听（用于子类重写）
function OpenServiceGiftPanel:RemoveListener()
end

function OpenServiceGiftPanel:OnSortingOrderChange()
end

--界面打开时调用（用于子类重写）
function OpenServiceGiftPanel:OnOpen(...)
end

-- 打开，重新打开时回调
function OpenServiceGiftPanel:OnShow()
    local rewardConfig = ConfigManager.GetConfigDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", FUNCTION_OPEN_TYPE.OpenServiceGift)
    if rewardConfig and #rewardConfig.Reward > 0 then
        for i = 1, #rewardConfig.Reward do
            if not itemList[i] then
                local bg = newObjToParent(this.pre, this.grid.transform)
                itemList[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(bg, "pos").transform)
            end
            itemList[i]:OnOpen(false, rewardConfig.Reward[i], 0.75)
        end
    end

    local data = ActivityGiftManager.GetActivityTypeInfo(FUNCTION_OPEN_TYPE.OpenServiceGift)
    Util.SetGray(this.btnGet, data.mission[1].state == 1)
    this.btnGetTxt.text = GetLanguageStrById(10022)--领取
    Util.AddOnceClick(this.btnGet, function()
        if data then
            if data.mission[1].state == 0 then
                NetManager.GetActivityRewardRequest(data.mission[1].missionId, FUNCTION_OPEN_TYPE.OpenServiceGift, function(drop)
                    UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
                    self:ClosePanel()
                    Game.GlobalEvent:DispatchEvent(GameEvent.Main.ActivityRefresh)
                end)
            end
        end
    end)
end

--界面关闭时调用（用于子类重写）
function OpenServiceGiftPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function OpenServiceGiftPanel:OnDestroy()
    itemList = {}
end

return OpenServiceGiftPanel