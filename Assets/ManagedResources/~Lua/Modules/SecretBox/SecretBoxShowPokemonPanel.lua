require("Base/BasePanel")
SecretBoxShowPokemonPanel = Inherit(BasePanel)
local this = SecretBoxShowPokemonPanel
local comonpent3 = {}
local comonpent4 = {}
local orginLayer
--初始化组件（用于子类重写）
function SecretBoxShowPokemonPanel:InitComponent()

    orginLayer = 10
    this.btnBack = Util.GetGameObject(self.gameObject, "GameObject/click")
    this.itemAnimEffect1 = Util.GetGameObject(self.gameObject, "itemAnimEffect1")
    this.item = Util.GetGameObject(self.gameObject, "itemAnimEffect1/image/Kuang/item/icon")
    this.pokemonComonpentName = Util.GetGameObject(self.gameObject, "itemAnimEffect1/image/Kuang/item/itemName/naemText"):GetComponent("Text")
    this.pokemonName = Util.GetGameObject(self.gameObject, "GameObject/pokemonNameImage/pokemonName"):GetComponent("Text")
    this.pokemonCommand3 = Util.GetGameObject(self.gameObject, "GameObject/pokemonCommand3")
    this.pokemonCommand4 = Util.GetGameObject(self.gameObject, "GameObject/pokemonCommand4")
    this.maskList = {}
    this.itemViewAll = {}
    for i = 1, 3 do
        comonpent3[i] = Util.GetGameObject(self.gameObject, "GameObject/pokemonCommand3/item" .. i)
    end
    for i = 1, 4 do
        comonpent4[i] = Util.GetGameObject(self.gameObject, "grid/item" .. i)
        this.maskList[i] = Util.GetGameObject(self.gameObject, "grid/mask" .. i)
        this.itemViewAll[i] = SubUIManager.Open(SubUIConfig.ItemView, comonpent4[i].transform)
    end
end

--绑定事件（用于子类重写）
function SecretBoxShowPokemonPanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function SecretBoxShowPokemonPanel:AddListener()

end

--移除事件监听（用于子类重写）
function SecretBoxShowPokemonPanel:RemoveListener()

end

local callBack
function SecretBoxShowPokemonPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.itemAnimEffect1, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder

    -- 修改itemview层级
    if this.ItemView then
        this.ItemView:OnOpen(false, this.reward, 0.8, false, false, false, self.sortingOrder)
    end
end
--界面打开时调用（用于子类重写）
function SecretBoxShowPokemonPanel:OnOpen(pokemonComonpentId, func)

    this.itemAnimEffect1:SetActive(false)
    this.ShoePanelData(pokemonComonpentId)
    callBack = func
end
function this.ShoePanelData(_pokemonComonpentId)
    this.itemAnimEffect1:SetActive(true)
    local pokemonData = DiffMonsterManager.GetPokemonDataByComonpentId(_pokemonComonpentId)
    local pokemonItemData = ConfigManager.GetConfigData(ConfigName.ItemConfig, _pokemonComonpentId)
    if pokemonData and pokemonItemData then
        Util.ClearChild(this.item.transform)
        this.ItemView = SubUIManager.Open(SubUIConfig.ItemView, this.item.transform)
        this.reward = {}
        this.reward[1] = _pokemonComonpentId
        this.reward[2] = 1
       
        this.ItemView:OnOpen(false, this.reward,0.8, false, false, false, this.sortingOrder)
        this.pokemonComonpentName.text = pokemonItemData.Name
        this.pokemonName.text = pokemonData.pokemonConfig.Name
        if (#pokemonData.pokemoncomonpentList >= 4) then
            for i, v in pairs(pokemonData.pokemoncomonpentList) do
                this.itemViewAll[i].gameObject:SetActive(true)
                this.itemViewAll[i]:OnOpen(false, { v.id, 0 }, 1.15, false, false, false, this.sortingOrder)
                if _pokemonComonpentId == v.id then
                    this.maskList[i]:SetActive(false)
                else
                    this.maskList[i]:SetActive(true)
                end
            end
        else
            for i, v in pairs(pokemonData.pokemoncomonpentList) do
                this.itemViewAll[i].gameObject:SetActive(true)
                this.itemViewAll[i]:OnOpen(false, { v.id, 0 }, 1.15, false, false, false, this.sortingOrder)
                if _pokemonComonpentId == v.id then
                    this.maskList[i]:SetActive(false)
                else
                    this.maskList[i]:SetActive(true)
                end
            end
            this.itemViewAll[4].gameObject:SetActive(false)
        end
        --if #pokemonData.pokemoncomonpentList<=3 then
        --    this.pokemonCommand3:SetActive(true)
        --    this.pokemonCommand4:SetActive(false)
        --    for i = 1, #pokemonData.pokemoncomonpentList do
        --        local pokemoncomonpentData=ConfigManager.GetConfigData(ConfigName.ItemConfig, pokemonData.pokemoncomonpentList[i].id)
        --        if _pokemonComonpentId==pokemonData.pokemoncomonpentList[i].id then
        --            Util.GetGameObject(comonpent3[i], "mask"):SetActive(false)
        --        else
        --            Util.GetGameObject(comonpent3[i], "mask"):SetActive(true)
        --        end
        --        Util.GetGameObject(comonpent3[i], "icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(pokemoncomonpentData.ResourceID))
        --    end
        --else
        --    this.pokemonCommand3:SetActive(false)
        --    this.pokemonCommand4:SetActive(true)
        --    for i = 1, #pokemonData.pokemoncomonpentList do
        --        local pokemoncomonpentData=ConfigManager.GetConfigData(ConfigName.ItemConfig, pokemonData.pokemoncomonpentList[i].id)
        --        if _pokemonComonpentId==pokemonData.pokemoncomonpentList[i].id then
        --            Util.GetGameObject(comonpent4[i], "mask"):SetActive(false)
        --            this.maskList[i]:SetActive(false)
        --        else
        --            Util.GetGameObject(comonpent4[i], "mask"):SetActive(true)
        --            this.maskList[i]:SetActive(true)
        --        end
        --        Util.GetGameObject(comonpent4[i], "icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(pokemoncomonpentData.ResourceID))
        --    end
        --end
    end
end
--界面关闭时调用（用于子类重写）
function SecretBoxShowPokemonPanel:OnClose()

    if callBack then
        callBack()
    end
end

--界面销毁时调用（用于子类重写）
function SecretBoxShowPokemonPanel:OnDestroy()


    this.ItemView = nil
end

return SecretBoxShowPokemonPanel