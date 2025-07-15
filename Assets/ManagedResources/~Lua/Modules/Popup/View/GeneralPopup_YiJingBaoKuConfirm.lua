----- YiJingBaoKuConfirm二次确认弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local BlessingConfig = ConfigManager.GetConfig(ConfigName.BlessingRewardPoolNew)
local curId 
local func
local finalReward

function this:InitComponent(gameObject)
    -- this.titleText = Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.tip = Util.GetGameObject(gameObject,"tip"):GetComponent("Text")
    this.root = Util.GetGameObject(gameObject, "Root")
    this.confirm = Util.GetGameObject(gameObject, "ConfirmBtn")
    this.cancel = Util.GetGameObject(gameObject, "CancelBtn")
end

function this:BindEvent()
    Util.AddClick(this.confirm,function()
        parent:ClosePanel()
        if func then
            func()
        end
    end)
    Util.AddClick(this.cancel,function()
        parent:ClosePanel()
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local _args = {...}
    func = _args[2]
    curId = _args[1]

    -- this.titleText.text = GetLanguageStrById(11351)
    this.tip.text = GetLanguageStrById(23105)

    if not finalReward then
        finalReward = SubUIManager.Open(SubUIConfig.ItemView,this.root.transform)
    end
    finalReward:OnOpen(false, BlessingConfig[curId].Reward, 0.65, true, false, false, sortingOrder)
    finalReward.transform.localPosition = Vector2.New(0,0)
end

function this:OnClose()
end

function this:OnDestroy()
    finalReward = nil
end

return this