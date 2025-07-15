require("Base/BasePanel")
PokemonListPanel = Inherit(BasePanel)
local this = PokemonListPanel
local curIndex = 1
local curUpZhenPokemonData
local upZhenIndex
this.contents = {
    [1] = {view = require("Modules/Pokemon/view/PokemonListPanel_UpWar"), panelName = "PokemonListPanel_UpWar"},
    [2] = {view = require("Modules/Pokemon/view/PokemonListPanel_List"), panelName = "PokemonListPanel_List"},
    [3] = {view = require("Modules/Pokemon/view/PokemonListPanel_Fetter"), panelName = "PokemonListPanel_Fetter"},
}
--初始化组件（用于子类重写）
function PokemonListPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    --预设赋值
    this.prefabs = {}
    for i=1,#this.contents do
        this.prefabs[i]=Util.GetGameObject(self.gameObject,"layout/"..this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, "layout"))
    end
end

--绑定事件（用于子类重写）
function PokemonListPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function PokemonListPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function PokemonListPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function PokemonListPanel:OnOpen(_curIndex,_curUpZhenPokemonData,_upZhenIndex)--_curUpZhenPokemonData,_upZhenIndex  只有上阵才会传
    curIndex = _curIndex and _curIndex or 1
    curUpZhenPokemonData = _curUpZhenPokemonData
    upZhenIndex = _upZhenIndex
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PokemonListPanel:OnShow()
    this.ShowSShowwitchView(curIndex)
end

function PokemonListPanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
    for i = 1, #this.contents do
        this.contents[i].view:OnSortingOrderChange(self.sortingOrder)
    end
end


--切换视图
function this.ShowSShowwitchView(index)
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, curIndex = curIndex, index
    for i = 1, #this.contents do
        if oldSelect~=0 then this.contents[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    --执行子模块初始化
    this.contents[index].view:OnShow(this,curUpZhenPokemonData,upZhenIndex)
end

--界面关闭时调用（用于子类重写）
function PokemonListPanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
end

--界面销毁时调用（用于子类重写）
function PokemonListPanel:OnDestroy()
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

return PokemonListPanel