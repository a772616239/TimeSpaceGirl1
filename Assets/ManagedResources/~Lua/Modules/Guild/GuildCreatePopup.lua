require("Base/BasePanel")
local GuildCreatePopup = Inherit(BasePanel)
local this = GuildCreatePopup

--初始化组件（用于子类重写）
function GuildCreatePopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnClose")
    this.btnCreate = Util.GetGameObject(self.transform, "tipImage/btnCreate")
    this.inputName = Util.GetGameObject(self.transform, "tipImage/name"):GetComponent("InputField")
    this.inputAnnounce = Util.GetGameObject(self.transform, "tipImage/content"):GetComponent("InputField")

    this.costTip = Util.GetGameObject(self.transform, "tipImage/costTips"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function GuildCreatePopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    -- 搜索
    Util.AddClick(this.btnCreate, function()

    
        local name = this.inputName.text
        local announce = this.inputAnnounce.text
        if name == "" then
            PopupTipPanel.ShowTipByLanguageId(10851)
            return
        end

        local config = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1)
        local minLen, maxLen = config.NameSize[1], config.NameSize[2]
        local len = StringWidth(name)
        if len < minLen or len > maxLen then
            PopupTipPanel.ShowTipByLanguageId(10852)
            return
        end

        local cost = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).CreatCost
        CostConfirmPopup.Show(cost[1][1], cost[1][2], GetLanguageStrById(10853), nil, function()
            local haveNum = BagManager.GetItemCountById(cost[1][1])
            if haveNum < cost[1][2] then
                PopupTipPanel.ShowTipByLanguageId(10854)
                return
            end
            GuildManager.RequestCreateGuild(name, announce, function()
                this:ClosePanel()
                if this.successFunc then this.successFunc() end
                UIManager.OpenPanel(UIName.GuildMainCityPanel)
                PopupTipPanel.ShowTipByLanguageId(10855)
            end)
        end)
    end)
end

--添加事件监听（用于子类重写）
function GuildCreatePopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildCreatePopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildCreatePopup:OnOpen(successFunc)
    local defaultAnnounce = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).DefaultDeclaration
    this.inputName.text = ""
    this.inputAnnounce.text = GetLanguageStrById(defaultAnnounce)
    this.successFunc = successFunc

    -- 创建消耗
    local cost = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).CreatCost
    local costName = ConfigManager.GetConfigData(ConfigName.ItemConfig, cost[1][1]).Name
    -- this.costTip.text = string.format(GetLanguageStrById(10856), cost[1][2], costName)
    this.costTip.text = cost[1][2]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildCreatePopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function GuildCreatePopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildCreatePopup:OnDestroy()
end

return GuildCreatePopup