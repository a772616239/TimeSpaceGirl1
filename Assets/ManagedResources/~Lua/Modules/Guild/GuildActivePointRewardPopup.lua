require("Base/BasePanel")
GuildActivePointRewardPopup = Inherit(BasePanel)
local this = GuildActivePointRewardPopup

--初始化组件（用于子类重写）
function GuildActivePointRewardPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "bg/btnClose")


    this.Scroll = Util.GetGameObject(self.gameObject, "bg/Scroll")
    this.TaskPre = Util.GetGameObject(self.gameObject, "bg/TaskPre")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.TaskPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 0))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.itemList = {}
end

--绑定事件（用于子类重写）
function GuildActivePointRewardPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildActivePointRewardPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function GuildActivePointRewardPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function GuildActivePointRewardPopup:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildActivePointRewardPopup:OnShow()
    local guildActiveData = {}
    for _, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.GuildActiveConfig)) do
        if v.Lv ~= 0 then
            table.insert(guildActiveData, v)
        end
    end
    table.sort(guildActiveData, function(a, b)
        return a.Lv < b.Lv
    end)


    this.data = guildActiveData
    this.scrollView:SetData(this.data, function(index, root)
        self:FillItem(root, this.data[index])
    end)
    this.scrollView:SetIndex(1)
end

function GuildActivePointRewardPopup:FillItem(go, data)
    local RewardGrid = Util.GetGameObject(go, "Grid/RewardGrid")

    if this.itemList[go] == nil then
        this.itemList[go] = {}
        for i = 1, 4 do     --< 目前最多支持四个item
            this.itemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, RewardGrid.transform)
        end
    end
    local itemData = data.Reward
    for i = 1, 4 do
        local ItemView = this.itemList[go][i]
        if i <= #itemData then
            ItemView.gameObject:SetActive(true)
            
            ItemView:OnOpen(false, {itemData[i][1], itemData[i][2]}, 1, nil, nil, nil, nil, data.cornerType)
        else
            ItemView.gameObject:SetActive(false)
        end
    end

    Util.GetGameObject(go, "Title"):GetComponent("Text").text = string.format(GetLanguageStrById(12538), data.Lv)
end

--界面关闭时调用（用于子类重写）
function GuildActivePointRewardPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function GuildActivePointRewardPopup:OnDestroy()
    this.itemList = {}
end

return GuildActivePointRewardPopup