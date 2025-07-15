require("Base/BasePanel")
GuildLogPopup = Inherit(BasePanel)
local this = GuildLogPopup

--初始化组件（用于子类重写）
function GuildLogPopup:InitComponent()
    this.maskImage = Util.GetGameObject(self.gameObject, "maskImage")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    this.logScrollRoot = Util.GetGameObject(self.gameObject, "log/bg/scrollpos")
    this.logItem = Util.GetGameObject(self.gameObject, "log/bg/scrollpos/log")
end

--绑定事件（用于子类重写）
function GuildLogPopup:BindEvent()
    Util.AddClick(this.maskImage, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildLogPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function GuildLogPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function GuildLogPopup:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildLogPopup:OnShow()
    if this.itemList then
        for index, value in ipairs(this.itemList) do
            if value.activeSelf then
                value:SetActive(false)
            end
        end
    end
    self:RefreshLogShow()
end

-- 刷新公会日志
function GuildLogPopup:RefreshLogShow()
    MyGuildManager.RequestMyGuildLog(function()
        if not this.logScrollView then
            local height = this.logScrollRoot.transform.rect.height
            local width = this.logScrollRoot.transform.rect.width
            this.logScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.logScrollRoot.transform,
                    this.logItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,10))
            this.logScrollView.moveTween.Strength = 2
        end
        -- 设置数据
        this.itemList = {}
        local logs = MyGuildManager.GetMyGuildLog()
        this.logScrollView:SetData(logs, function(index, go)
            this:LogItemAdapter(go, logs[index])
            this.itemList[index] = go
        end)
        DelayCreation(this.itemList)
        local len = #logs
        if len >= 10 then
            this.logScrollView:SetIndex(len)
        end
    end)
end
-- 成员信息节点数据匹配
function GuildLogPopup:LogItemAdapter(item, data)
    local nameText = Util.GetGameObject(item, "name")
    local statusText = Util.GetGameObject(item, "state")
    nameText:GetComponent("Text").text = GetMailConfigDesc(data.info,data.guildparam)
    statusText:GetComponent("Text").text = GetDeltaTimeStr(data.time)
end

--界面关闭时调用（用于子类重写）
function GuildLogPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function GuildLogPopup:OnDestroy()
    this.logScrollView = nil
    this.itemList = nil
end

return GuildLogPopup