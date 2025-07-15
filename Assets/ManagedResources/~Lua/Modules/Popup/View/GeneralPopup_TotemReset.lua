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
--传入选择英雄
local totemId
local selectHeroData
local par
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)

function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.bodyText=Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.cancelBtn=Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn=Util.GetGameObject(gameObject,"ConfirmBtn")

    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root/scroll")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
       
        NetManager.TotemResetRequest(totemId,function(msg)
            parent:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10383)

            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
                TotemManager.TotemResetLevel(totemId,selectHeroData.dynamicId,par)
                par.UpdateData()

                RoleInfoPanel.ShowHeroEquip()
                
            end)

        end)
     
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder =_parent.sortingOrder-1
    local args = {...}
    dropList = args[1]
    selectHeroData=args[2]
    totemId=args[3]
    par=args[4]

    this.titleText.text=GetLanguageStrById(11645)
    --返还比
    this.bodyText.text=GetLanguageStrById(50327)

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