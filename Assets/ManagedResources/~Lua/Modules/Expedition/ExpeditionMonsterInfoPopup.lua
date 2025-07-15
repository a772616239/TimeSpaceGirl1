require("Base/BasePanel")
local ExpeditionMonsterInfoPopup = Inherit(BasePanel)
local this = ExpeditionMonsterInfoPopup
--子模块脚本
local contentScripts = {
    --招募
    [1] = {view = require("Modules/Expedition/View/ExpeditionMonsterInfo_Recruit"), panelName = "ExpeditionMonsterInfo_Recruit",type=EXPEDITON_POPUP_TYPE.Recruit},
    --商店
    [2] = {view = require("Modules/Expedition/View/ExpeditionMonsterInfo_Shop"), panelName = "ExpeditionMonsterInfo_Shop",type=EXPEDITON_POPUP_TYPE.Shop},
    -- 普通 精英 boss 贪婪
    [3]= {view=require("Modules/Expedition/View/ExpeditionMonsterInfo_Monster"),panelName="ExpeditionMonsterInfo_Monster",type=EXPEDITON_POPUP_TYPE.Monster},
    --试炼
    [4]= {view=require("Modules/Expedition/View/ExpeditionMonsterInfo_Trail"),panelName="ExpeditionMonsterInfo_Trail",type=EXPEDITON_POPUP_TYPE.Trail},
    --贪婪
    [5]= {view=require("Modules/Expedition/View/ExpeditionMonsterInfo_Greed"),panelName="ExpeditionMonsterInfo_Greed",type=EXPEDITON_POPUP_TYPE.Greed},
}
--子模块预设
local contentPrefabs={}
--打开弹窗索引
local index=0


--初始化组件（用于子类重写）
function ExpeditionMonsterInfoPopup:InitComponent()
    this.contents=Util.GetGameObject(this.gameObject,"Contents")
    this.BGImage1=Util.GetGameObject(this.gameObject,"Contents/BG/BGImage1")
    this.BGImage2=Util.GetGameObject(this.gameObject,"Contents/BG/BGImage2")
    --this.backBtn=Util.GetGameObject(this.contents,"BackBtn")
    --子模块脚本初始化
    for i = 1, #contentScripts do
        contentScripts[i].view:InitComponent(Util.GetGameObject(this.contents, contentScripts[i].panelName))
    end
    --预设赋值
    for i=1,#contentScripts do
        contentPrefabs[i]=Util.GetGameObject(this.contents,contentScripts[i].panelName)
    end



end

--绑定事件（用于子类重写）
function ExpeditionMonsterInfoPopup:BindEvent()
    for i = 1, #contentScripts do
        contentScripts[i].view:BindEvent()
    end
    --返回按钮
    --Util.AddClick(this.backBtn,function()
    --    self:ClosePanel()
    --end)
end

--添加事件监听（用于子类重写）
function ExpeditionMonsterInfoPopup:AddListener()
    for i = 1, #contentScripts do
        contentScripts[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function ExpeditionMonsterInfoPopup:RemoveListener()
    for i = 1, #contentScripts do
        contentScripts[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function ExpeditionMonsterInfoPopup:OnOpen(popupType,...)
    -- local args={...}
    -- popupType=args[1]
    --根据传入类型打开对应面板
    for i,v in pairs(contentScripts) do
        if popupType==v.type then
            index=i
            break
        end
    end
    for i=1,#contentPrefabs do
        contentPrefabs[i].gameObject:SetActive(false)
    end
    this.BGImage1:SetActive(index == 1 or index == 2)
    this.BGImage2:SetActive(index == 3 or index == 4 or index == 5)
    contentPrefabs[index].gameObject:SetActive(true)
    contentScripts[index].view:OnShow(this,...)--1、传入自己 2、传入不定参
end



--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ExpeditionMonsterInfoPopup:OnShow()

end



--界面关闭时调用（用于子类重写）
function ExpeditionMonsterInfoPopup:OnClose()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnClose()
    end
end

function ExpeditionMonsterInfoPopup:OnDestroy()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnDestroy()
    end
end

return ExpeditionMonsterInfoPopup