--[[
 * @ClassName RewardPreviewPopupPanel
 * @Description 奖励预览界面
 * @Date 2019/8/7 10:39
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class RewardPreviewPopupPanel


--奖励预览小弹窗
--该弹窗用于制作两键位互相点击时 不受弹窗层级遮挡影响 需要重新设置位置 防止与按键重叠 层级穿透
--SetPostion(Vector2) 设置小弹窗的位置
-- RewardPreviewPopupPanel = {}

require("Base/BasePanel")
local RewardPreviewPopupPanel = Inherit(BasePanel)
local this = RewardPreviewPopupPanel
this.id=100
function RewardPreviewPopupPanel:InitComponent()
    self.frame = Util.GetGameObject(self.transform, "frame")
    self.title = Util.GetGameObject(self.transform, "frame/bg/titlebg/title"):GetComponent("Text")
    self.bg=Util.GetGameObject(self.transform,"frame/bg")
    self.rewardList = {}
    self.rewardContent = Util.GetGameObject(self.transform, "frame/bg/rewardList/content")
end

function RewardPreviewPopupPanel:BindEvent()
    Util.AddClick(self.frame, function()
        self:ClosePanel()
    end)
end

--{title,reward}
function RewardPreviewPopupPanel:OnOpen(context)
    self.context = context
end

function RewardPreviewPopupPanel:OnShow()
    self.title.text = self.context.title and self.context.title or GetLanguageStrById(10859)
    self:SetRewardList(self.context.reward)
end

function RewardPreviewPopupPanel:OnClose()

end

function RewardPreviewPopupPanel:OnDestroy()
    self.rewardList = {}
end

function RewardPreviewPopupPanel:SetRewardList(rewardData)
    for _, rewardInfo in ipairs(rewardData) do
        if not self.rewardList[_] then
            self.rewardList[_]= SubUIManager.Open(SubUIConfig.ItemView, self.rewardContent.transform)
        end
        self.rewardList[_]:OnOpen(false, rewardInfo, 0.7)
    end
end

--设置位置
function RewardPreviewPopupPanel:SetPosition(v2)
    self.bg.transform:DOAnchorPos(v2,0)
end

return RewardPreviewPopupPanel