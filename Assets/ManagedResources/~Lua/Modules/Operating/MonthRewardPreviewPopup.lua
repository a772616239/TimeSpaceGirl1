require("Base/BasePanel")
MonthRewardPreviewPopup = Inherit(BasePanel)
local this = MonthRewardPreviewPopup

--初始化组件（用于子类重写）
function MonthRewardPreviewPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.rect = Util.GetGameObject(self.gameObject, "bg/Rect")
    this.itemRoot = Util.GetGameObject(self.gameObject, "bg/imtePre")
    this.grid = Util.GetGameObject(self.gameObject, "bg/Rect/grid")
    self.rewardList = {}
end

--绑定事件（用于子类重写）
function MonthRewardPreviewPopup:BindEvent()
    Util.AddClick(
        this.btnBack,
        function()
            self:ClosePanel()
        end
    )
end

--添加事件监听（用于子类重写）
function MonthRewardPreviewPopup:AddListener()
end

--移除事件监听（用于子类重写）
function MonthRewardPreviewPopup:RemoveListener()
end

function MonthRewardPreviewPopup:OnOpen(type, goodType)
    local data = OperatingManager.GetPanelShowReward(type, true,false)
    local getDays = OperatingManager.GetRewardDay(goodType)
    
    for i = 1, #data do
        if not this.rewardList[i] then
            this.rewardList[i] = {}
            this.rewardList[i].go = newObjToParent(this.itemRoot, this.grid)
            this.rewardList[i].item = SubUIManager.Open(SubUIConfig.ItemView, this.rewardList[i].go.transform)
            this.rewardList[i].doneImg = Util.GetGameObject(this.rewardList[i].go, "done")
            this.rewardList[i].day = Util.GetGameObject(this.rewardList[i].go, "Text"):GetComponent("Text")
        end

        this.rewardList[i].doneImg:SetActive(i <= getDays)
        this.rewardList[i].doneImg.gameObject.transform:SetAsLastSibling()
        this.rewardList[i].day.text = GetLanguageStrById(10311) .. i .. GetLanguageStrById(10021)
        this.SetData(this.rewardList[i], data[i])
    end
end

function this.SetData(go, data)
    go.item:OnOpen(false, {data.reward[1][1], data.reward[1][2]}, 0.75)
end

--界面打开时调用（用于子类重写）
function MonthRewardPreviewPopup:OnShow(...)
end

function this:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function MonthRewardPreviewPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function MonthRewardPreviewPopup:OnDestroy()
end

return MonthRewardPreviewPopup