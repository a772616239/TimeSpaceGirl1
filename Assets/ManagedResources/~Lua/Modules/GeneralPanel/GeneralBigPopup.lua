----- 中号通用弹窗 -----
require("Base/BasePanel")
GeneralBigPopup = Inherit(BasePanel)
local this = GeneralBigPopup
local sorting = 0

--子模块脚本
local contentScripts = {
    --易经宝库
    [1] = {view = require("Modules/GeneralPanel/View/GeneralBigPopup_YiJingBaoKu"), panelName = "GeneralBigPopup_YiJingBaoKu",type=GENERAL_POPUP_TYPE.YiJingBaoKu},
    --易经宝库奖励预览
    [2] = {view = require("Modules/GeneralPanel/View/GeneralBigPopup_YiJingBaoKuRewardPreview"), panelName = "GeneralBigPopup_YiJingBaoKuRewardPreview",type=GENERAL_POPUP_TYPE.YiJingBaoKuRewardPreview},
}
--子模块预设
local contentPrefabs = {}
--打开弹窗类型
local popupType
--打开弹窗索引
local index = 0

--初始化组件（用于子类重写）
function GeneralBigPopup:InitComponent()
    this.contents = Util.GetGameObject(this.gameObject,"Contents")
    this.backBtn = Util.GetGameObject(this.contents,"BackBtn")
    -- this.BG = Util.GetGameObject(this.contents,"BG")
    this.Mask  =Util.GetGameObject(this.gameObject,"Mask")

    --子模块脚本初始化
    for i = 1, #contentScripts do
        contentScripts[i].view:InitComponent(Util.GetGameObject(this.contents, contentScripts[i].panelName))
    end
    --预设赋值
    for i=1,#contentScripts do
        contentPrefabs[i] = Util.GetGameObject(this.contents,contentScripts[i].panelName)
    end
end

--绑定事件（用于子类重写）
function GeneralBigPopup:BindEvent()
    for i = 1, #contentScripts do
        contentScripts[i].view:BindEvent()
    end
     --返回按钮
     Util.AddClick(this.backBtn,function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
        self:ClosePanel()
    end)
     Util.AddClick(this.Mask,function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
        self:ClosePanel()
    end)	
end

function GeneralBigPopup:AddListener()
    for i = 1, #contentScripts do
        contentScripts[i].view:AddListener()
    end
end

function GeneralBigPopup:RemoveListener()
    for i = 1, #contentScripts do
        contentScripts[i].view:RemoveListener()
    end
end

function GeneralBigPopup:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end
local onOpenArgs--临时接的参数 需要onshow刷新的调用
function GeneralBigPopup:OnOpen(popupType,...)
    onOpenArgs = ...
    --根据传入类型打开对应面板
    
    for i,v in pairs(contentScripts) do
        if popupType == v.type then
            index = i
            break
        end
    end
    for i = 1,#contentPrefabs do
        contentPrefabs[i].gameObject:SetActive(false)
    end
    this.Mask:SetActive(index ~= GENERAL_POPUP_TYPE.Onhook)
    -- this.BG:SetActive(index ~= GENERAL_POPUP_TYPE.Onhook)

    contentPrefabs[index].gameObject:SetActive(true)
    contentScripts[index].view:OnShow(this,...)--1、传入自己 2、传入不定参
end

function GeneralBigPopup:OnShow()
end

function GeneralBigPopup:OnClose()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnClose()
    end
end

function GeneralBigPopup:OnDestroy()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnDestroy()
    end
end

return GeneralBigPopup