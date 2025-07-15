----- 送神弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local _args={}
--传入选择英雄计算返回奖励数据列表
local dropList = {}
--item容器
local itemList = {}
local fun
--传入选择英雄
local selectHeroData
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)

function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.bodyText=Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
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
    sortingOrder =_parent.sortingOrder
    local args = {...}
    dropList = args[1]
    selectHeroData=args[2]
    fun=args[3]
    --this.titleText.text=GetLanguageStrById(11643)
    this.titleText.text=GetLanguageStrById(12504)
    --返还比
    local num=tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,35).Value)/100
    this.bodyText.text=string.format( GetLanguageStrById(11644),num,"%")

    local data={}
    for i, v in pairs(dropList) do
        data[i]={v[1],v[2]}
    end
    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,10,1,sortingOrder,false,data)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this