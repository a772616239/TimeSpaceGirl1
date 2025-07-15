require("Base/BasePanel")
PlotRewardPreviewPupop = Inherit(BasePanel)
local this = PlotRewardPreviewPupop
--local starConfig = ConfigManager.GetConfig(ConfigName.ChallengeStarBox)

--初始化组件（用于子类重写）
function PlotRewardPreviewPupop:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "Frame/btnBack")
    this.root = Util.GetGameObject(self.gameObject, "Frame/scrollView")
    this.item = Util.GetGameObject(self.gameObject, "item")
    this.itemView = {}
    local height = this.root.transform.rect.height
    local width = this.root.transform.rect.width
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.root.transform,
            this.item, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
end

--绑定事件（用于子类重写）
function PlotRewardPreviewPupop:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)

end

--添加事件监听（用于子类重写）
function PlotRewardPreviewPupop:AddListener()

end

--移除事件监听（用于子类重写）
function PlotRewardPreviewPupop:RemoveListener()

end

--界面打开时调用（用于子类重写）
function PlotRewardPreviewPupop:OnOpen(...)
end

function PlotRewardPreviewPupop:OnShow()
    if not this.scrollView then
        local height = this.root.transform.rect.height
        local width = this.root.transform.rect.width
        this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.root.transform,
                this.item, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
    end
    this.RewardList = {}
    local rewardList = ConfigManager.GetConfig(ConfigName.ChallengeStarBox)
    for id, data in ConfigPairs(rewardList) do
        table.insert(this.RewardList, data)
    end
    this.scrollView:SetData(this.RewardList, function(index, go)
        this.SetShow(go, this.RewardList[index])
    end)
end

-- 设置节点显示
function this.SetShow(node, data)
    -- 同时生成两个ItemView
    local normal = Util.GetGameObject(node, "normalReward")
    local extral = Util.GetGameObject(node, "extralReward")
    if not this.itemView[node] then
        this.itemView[node] = {}
    end
    if not this.itemView[node][1] then
        this.itemView[node][1] = SubUIManager.Open(SubUIConfig.ItemView, normal.transform)
    end
    if not this.itemView[node][2] then
        this.itemView[node][2] = SubUIManager.Open(SubUIConfig.ItemView, extral.transform)
    end
    this.itemView[node][1]:OnOpen(false, data.Reward[1], 0.9)
    this.itemView[node][2]:OnOpen(false, data.ExtraReward[1], 0.9)

    --
    local starNum = Util.GetGameObject(node, "starNum"):GetComponent("Text")
    local mask = Util.GetGameObject(node, "LockMask")
    -- 设置数据
    mask:SetActive(not PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.EXTRA_STAR_REWARD))
    starNum.text = data.StarNum

end
--界面关闭时调用（用于子类重写）
function PlotRewardPreviewPupop:OnClose()

end

--界面销毁时调用（用于子类重写）
function PlotRewardPreviewPupop:OnDestroy()
    this.itemView = {}
end

return PlotRewardPreviewPupop