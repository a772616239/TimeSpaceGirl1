require("Base/BasePanel")
MapFormationInfoPopup = Inherit(BasePanel)
local this = MapFormationInfoPopup
local heroListGo={}
local orginLayer = 0
local orginLayer2 = 0
--初始化组件（用于子类重写）
function MapFormationInfoPopup:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.btnTeamRoot = Util.GetGameObject(self.gameObject, "bg/roleGrid")
    this.combatNum = Util.GetGameObject(self.gameObject, "bg/Combat/powerNum"):GetComponent("Text")
    for i = 1, 6 do
        heroListGo[i] = SubUIManager.Open(SubUIConfig.RoleItemView, Util.GetGameObject(this.transform, "roleGrid").transform)
    end
    for i = 1,Util.GetGameObject(this.transform, "roleGrid").transform.childCount do
        Util.AddParticleSortLayer(Util.GetGameObject(this.transform, "roleGrid").transform:GetChild(i - 1).gameObject, self.sortingOrder - orginLayer2)
    end
    orginLayer2 = self.sortingOrder
    orginLayer = self.sortingOrder
end

function MapFormationInfoPopup:OnSortingOrderChange()
    for i = 1,Util.GetGameObject(this.transform, "roleGrid").transform.childCount do
        Util.AddParticleSortLayer(Util.GetGameObject(this.transform, "roleGrid").transform:GetChild(i - 1).gameObject, self.sortingOrder - orginLayer)
    end
    orginLayer = self.sortingOrder
end
--绑定事件（用于子类重写）
function MapFormationInfoPopup:BindEvent()

    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MapFormationInfoPopup:AddListener()

end

--移除事件监听（用于子类重写）
function MapFormationInfoPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MapFormationInfoPopup:OnOpen(...)
    this.RefreshFormation()
end

local powerNum = 0
-- 刷新编队显示
function this.RefreshFormation()
    local curFormation = MapManager.formationList
    powerNum = 0
    for i = 1, 6 do
        local heroData
        if curFormation[i] then
            heroData = HeroManager.GetSingleHeroData(curFormation[i].heroId)
            if not heroData then
               
                return
            end
            heroListGo[i]:OnOpen(curFormation[i].heroId,true,true,curFormation[i].allProVal[2] / curFormation[i].allProVal[3])
            local allPropValue = curFormation[i].allProVal

            heroListGo[i]:AddClick(function()
                UIManager.OpenPanel(UIName.MapRoleInfoPopup, heroData, allPropValue)
            end)
            if curFormation[i].allProVal[2] > 0 then
                this.CalculateAllHeroPower(heroData)
            end
            heroListGo[i].gameObject:SetActive(true)
            heroListGo[i].transform.localScale=Vector3.one*0.75
        else
            heroListGo[i].gameObject:SetActive(false)
        end
    end
    this.combatNum.text = powerNum

end

local allEquipAddProVal
function this.CalculateAllHeroPower(curHeroData)
    allEquipAddProVal = HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId, false)
    powerNum = powerNum + allEquipAddProVal[HeroProType.WarPower]
end

--界面关闭时调用（用于子类重写）
function MapFormationInfoPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function MapFormationInfoPopup:OnDestroy()

end

return MapFormationInfoPopup