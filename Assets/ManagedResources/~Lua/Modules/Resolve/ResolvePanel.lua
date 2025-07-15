---献祭坛主面板---
require("Base/BasePanel")
ResolvePanel = Inherit(BasePanel)
local this = ResolvePanel
-- local isSha = false--筛选按钮状态
--Tab
local TabBox = require("Modules/Common/TabBox")
local _TabData={
                 [1] = {  default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
                     select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
                     name = GetLanguageStrById(12503),
                     title = "cn2-X1_renshichu_qiansanyeqian" },
                 [2] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
                    select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
                    name = GetLanguageStrById(12504),
                    title = "cn2-X1_renshichu_huishouyeqian" },
                }

local _TabSelectData = {[0] = GetPictureFont("cn2-X1_tongyong_zhenying_01"),
                      [1] = "cn2-X1_tongyong_zhenying_04",
                      [2] = "cn2-X1_tongyong_zhenying_02",
                      [3] = "cn2-X1_tongyong_zhenying_03",
                      [4] = "cn2-X1_tongyong_zhenying_06",
                      [5] = "cn2-X1_tongyong_zhenying_05",
                }
--子模块脚本
this.contents = {
    --遣散
    [1] = {view = require("Modules/Resolve/View/Resolve_Dismantle"), panelName = "Resolve_Dismantle"},
    --碎片回收
    [2] = {view = require("Modules/Resolve/View/Resolve_Debris"), panelName = "Resolve_Debris"},
}
--子模块预设
this.prefabs={}
--上一子模块索引
local curIndex=0
local heroEndBtns = {}
local tabSortType

function ResolvePanel:InitComponent()
    this.panel = Util.GetGameObject(self.gameObject, "Panel")
    this.backBtn = Util.GetGameObject(this.panel, "BackBtn")
    this.content = Util.GetGameObject(this.panel, "Content")
    this.itemListRoot = Util.GetGameObject(this.panel,"ItemListRoot")
    this.btnHeroGrid = Util.GetGameObject(this.panel, "endTabs/btnHeroGrid")
    this.endTabs = Util.GetGameObject(this.panel, "endTabs")
    this.endTabs:SetActive(false)
    --预设赋值
    for i=1,#this.contents do
        this.prefabs[i]=Util.GetGameObject(this.panel,this.contents[i].panelName)
    end


    this.selectHeroBtn = Util.GetGameObject(this.panel, "endTabs/selectBtn")
    for i = 1, 6 do
        heroEndBtns[i]=Util.GetGameObject(this.panel, "endTabs/btnHeroGrid/btnHeroGrid/Btn"..i-1)
    end
    for i = 1, #this.contents do
        this.contents[i].view:InitComponent(this.panel)
    end
end

function ResolvePanel:BindEvent()
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
    --返回按钮
    Util.AddClick(this.backBtn,function()
            self:ClosePanel()
    end)
    for i = 1, 6 do
        Util.AddClick( heroEndBtns[i], function()
            if tabSortType == i-1 then
                tabSortType = 0
                this.contents[curIndex].view.SortTypeClick(0)--全部
                this.selectHeroBtn:GetComponent("Image").sprite = Util.LoadSprite("cn2-x1_AN_shuxing_xuanzhong")
                this.EndTabBtnSelect()
            else
                tabSortType = i-1
                this.contents[curIndex].view.SortTypeClick(i-1)
                this.selectHeroBtn:GetComponent("Image").sprite = Util.LoadSprite("cn2-x1_AN_shuxing_xuanzhong")
                this.EndTabBtnSelect(heroEndBtns[i])
            end
            
        end)
    end
end

function ResolvePanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

function ResolvePanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

function ResolvePanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

function ResolvePanel:OnOpen(...)
    local args = {...}
    if args[1] then
        curIndex=args[1]
    else
        curIndex=1
    end
    tabSortType = 0
    this.EndTabBtnSelect()
end

function ResolvePanel:OnShow()
    this.upView = SubUIManager.Open(SubUIConfig.UpView, self.transform, {showType = UpViewOpenType.ShowLeft})
    this.tabBox = Util.GetGameObject(this.panel, "TabBox")
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData,curIndex)
    this.endTabs:SetActive(true)
end

function ResolvePanel:OnClose()
    SubUIManager.Close(this.upView)
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
end

function ResolvePanel:OnDestroy()
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

--切换视图
function this.SwitchView(index)
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, curIndex = curIndex, index
    for i = 1, #this.contents do
        if oldSelect ~= 0 then this.contents[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    --区分显示
    if index == 1 then
        this.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.HeroReturn})
    elseif index == 2 then
        this.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.HeartFireStone})
    elseif index == 3 then
        this.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.HeartFireStone})
    end

    --执行子模块初始化
    this.contents[index].view:OnShow(this.sortingOrder,this.itemListRoot)
    --刷新选择按钮
    tabSortType = 0
    this.EndTabBtnSelect()
    this.selectHeroBtn:GetComponent("Image").sprite = Util.LoadSprite("cn2-x1_AN_shuxing_xuanzhong")

end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab,"default")
    local select = Util.GetGameObject(tab,"select")
    Util.GetGameObject(tab,"select/title"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].title)
    Util.GetGameObject(tab,"default/Text"):GetComponent("Text").text = _TabData[index].name
    Util.GetGameObject(tab,"select/Text"):GetComponent("Text").text = _TabData[index].name

    default:SetActive(status == "default")
    select:SetActive(status == "select")
end

-- function this.RewardGridGoMov(isSha,fun)
--     if isSha then
--         this.endTabs:SetActive(true)
--         --this.btnHeroGrid.transform:DOAnchorPosY(-670, 0.5, false)
--         this.btnHeroGrid.transform:DOAnchorPosX(0, 0.5, false)
--         this.endTabs.transform:DOAnchorPosY(295, 0.5, false):OnComplete(function()
--             this.shaiBtn:GetComponent("Button").enabled = true
--             if fun then
--                 fun()
--             end
--         end)
--     else
--         --this.btnHeroGrid.transform:DOAnchorPosY(-766, 0.5, false)
--         this.btnHeroGrid.transform:DOAnchorPosX(1100, 0.5, false)
--         this.endTabs.transform:DOAnchorPosY(-38.64, 0.5, false):OnComplete(function()
--             this.shaiBtn:GetComponent("Button").enabled = true
--             this.endTabs:SetActive(false)
--             if fun then
--                 fun()
--             end
--         end)
--     end
-- end

--下部页签排序
function this.EndTabBtnSelect(_btn)
    if _btn then
        this.selectHeroBtn.transform:SetParent(_btn.transform)
        this.selectHeroBtn.transform.localScale = Vector3.one
        this.selectHeroBtn.transform.localPosition=Vector3.zero
    else
        this.selectHeroBtn.transform:SetParent(heroEndBtns[1].transform)
        this.selectHeroBtn.transform.localScale = Vector3.one
        this.selectHeroBtn.transform.localPosition=Vector3.zero
    end
end
return ResolvePanel