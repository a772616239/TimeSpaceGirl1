----- 献祭弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local _args={}
--item容器
local itemList = {}
--传入选择英雄
function this:InitComponent(gameObject)
    this.okBtn=Util.GetGameObject(gameObject,"okBtn")
    this.root = Util.GetGameObject(gameObject, "Root")
end

function this:BindEvent()
    Util.AddClick(this.okBtn,function()
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
    local args = {...}
    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,10,1.2,sortingOrder,false,ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).Reward)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this