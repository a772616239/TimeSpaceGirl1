----- 献祭弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local _args={}
local fun
--item容器
local itemList = {}
--传入选择英雄
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)

function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.num=Util.GetGameObject(gameObject,"Body/Num"):GetComponent("Text")
    this.numImage=Util.GetGameObject(gameObject,"Body/Num/Image"):GetComponent("Image")
    this.cancelBtn=Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn=Util.GetGameObject(gameObject,"ConfirmBtn")

    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        if fun then
            fun()
        end
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
    this.num.text = args[1]
    fun = args[3]
    this.titleText.text=GetLanguageStrById(11617)
    this.numImage.sprite = SetIcon(14)
    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,10,1,sortingOrder,false,args[2])
end

function this:OnClose()
end

function this:OnDestroy()
end

return this