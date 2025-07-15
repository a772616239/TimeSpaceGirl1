require("Base/BasePanel")
JumpSelectPopup = Inherit(BasePanel)
local this = JumpSelectPopup
local JumpConfig = ConfigManager.GetConfig(ConfigName.JumpConfig)
local itemSid -- 道具id
local configData -- 表数据
local isHeroJump --是否是英雄跳转
local jumpSelectHeroData
local heroId

--初始化组件（用于子类重写）
function JumpSelectPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.transform, "BackMask")
    this.equipProGrid = Util.GetGameObject(self.transform, "bg/scroll/grid")
    this.equipProScroll = Util.GetGameObject(self.transform, "bg/scroll")
end

--绑定事件（用于子类重写）
function JumpSelectPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function JumpSelectPopup:AddListener()
end

--移除事件监听（用于子类重写）
function JumpSelectPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function JumpSelectPopup:OnOpen(_isHeroJump, _itemSid, _jumpSelectHeroData, _heroId)
    isHeroJump, itemSid, jumpSelectHeroData, heroId = _isHeroJump, _itemSid, _jumpSelectHeroData, _heroId
    if isHeroJump then
        configData = ConfigManager.GetConfigData(ConfigName.HeroRankupGroup, itemSid)
    else
        configData = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemSid)
    end
end

function JumpSelectPopup:OnShow()
    Util.ClearChild(this.equipProGrid.transform)
    if isHeroJump then
        this.HeroJump()
    else
        this.ItemJump()
    end
end

--界面关闭时调用（用于子类重写）
function JumpSelectPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function JumpSelectPopup:OnDestroy()
end

function this.ItemJump()
    if configData and configData.Jump then
        if configData.Jump and #configData.Jump > 0 then
            local jumpSortData = {}
            local isLevel = false
            for i = 1, #configData.Jump do--为关卡跳转做的排序数据
                local jumpData = {}
                jumpData.id = configData.Jump[i]
                jumpData.data = JumpConfig[configData.Jump[i]]
                if jumpData.data.Type == JumpType.Level then--关卡按钮特殊处理
                    isLevel = true
                end
                table.insert(jumpSortData,jumpData)
            end
            for i = 1, #jumpSortData do
                if jumpSortData[i].id > 0 then
                    if not RECHARGEABLE then--（是否开启充值）
                        if this.isRewardItemPop == true or configData.Id == 61 or configData.Id == 19 then
                            SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, jumpSortData[i].id,false)
                        else
                            SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, jumpSortData[i].id,true)
                        end
                    else
                        if this.isRewardItemPop == true then
                            SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, jumpSortData[i].id,false)
                        else
                            SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, jumpSortData[i].id,true)
                        end
                    end
                end
            end
        end
    end
end

function this.HeroJump()
    if configData.Jump == nil or (configData.Jump == -1 and (configData.Issame < 1 or configData.Issame > 1)) then
        PopupTipPanel.ShowTip(GetLanguageStrById(50169))
    end
    if configData and configData.Jump then
        for i, v in ipairs(configData.Jump) do
            if v == -1 then -- 道具
                configData = ConfigManager.GetConfigData(ConfigName.ItemConfig, heroId)
                this.ItemJump()
            elseif v == -2 then -- 异能实验室
                SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, jumpSelectHeroData.data, false, true)
            else
                SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, v, false, true)
            end
        end
    end
end

return JumpSelectPopup