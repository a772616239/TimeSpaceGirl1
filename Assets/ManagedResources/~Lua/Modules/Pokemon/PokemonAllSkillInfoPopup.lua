require("Base/BasePanel")
local PokemonAllSkillInfoPopup = Inherit(BasePanel)
local this = PokemonAllSkillInfoPopup
local pokemonSkillDataList = {}--数据
local pokemonSid = 0
local pokemonLv = 0
local pokemonStar = 0
--初始化组件（用于子类重写）
function PokemonAllSkillInfoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "BackMask")
   
    this.prefab = Util.GetGameObject(self.gameObject, "prefab")
    this.ScrollParentView = Util.GetGameObject(self.gameObject, "scrollRect")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.ScrollParentView.transform,
            this.prefab, Vector2.New(692.1, 868.2), 1, 1)
    -- this.ScrollView.moveTween.MomentumAmount = 1
    -- this.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function PokemonAllSkillInfoPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    
end

--添加事件监听（用于子类重写）
function PokemonAllSkillInfoPopup:AddListener()
end

--移除事件监听（用于子类重写）
function PokemonAllSkillInfoPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function PokemonAllSkillInfoPopup:OnOpen(_pokemonSid,_pokemonLv,_pokemonStar)
    pokemonSid = _pokemonSid
    pokemonLv = _pokemonLv
    pokemonStar = _pokemonStar
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PokemonAllSkillInfoPopup:OnShow()
    this.ShowPokemonList()
end

function this.ShowPokemonList()
    local allSkillIds = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,pokemonSid).SkillArray
    local curStarIndex = 1
    pokemonSkillDataList = {}
    for i = 1, #allSkillIds do
        table.insert(pokemonSkillDataList,{star = allSkillIds[i][1],conFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,allSkillIds[i][2])})
        
        if allSkillIds[i][1] == pokemonStar then 
            curStarIndex = allSkillIds[i][1] 
        end
    end
    this.ScrollView:SetData(pokemonSkillDataList, function(index, go)
        this.SingPokemonDataShow(go, pokemonSkillDataList[index])
    end)
    
    this.ScrollView:SetIndex((curStarIndex + 1)) 
end
--478A5F       B9AC97  string.format("<color=#FF0000FF>%s/%s</color>",PrintWanNum2(curMaterialBagNum),PrintWanNum2(upStarMaterialsData[i][2]))
function this.SingPokemonDataShow(go,data)
    local lvStr = string.format(GetLanguageStrById(23088), data.conFig.Level)
    local starStr = string.format(GetLanguageStrById(23089), data.star)
    local isCurStar = (data.star == pokemonStar)
    Util.GetGameObject(go, "lv"):GetComponent("Text").text = isCurStar and string.format("<color=#00FF06>%s</color>",lvStr..GetLanguageStrById(12470)) or string.format("<color=#B9AC97>%s</color>",lvStr)
    Util.GetGameObject(go, "lv/need"):GetComponent("Text").text = isCurStar and string.format("<color=#00FF06>%s</color>",starStr) or string.format("<color=#B9AC97>%s</color>",starStr)
    Util.GetGameObject(go, "info"):GetComponent("Text").text = isCurStar and string.format("<color=#00FF06>%s</color>",data.conFig.Desc) or string.format("<color=#B9AC97>%s</color>",data.conFig.Desc)
end

--界面关闭时调用（用于子类重写）
function PokemonAllSkillInfoPopup:OnClose()
   
end

--界面销毁时调用（用于子类重写）
function PokemonAllSkillInfoPopup:OnDestroy()
   
end

return PokemonAllSkillInfoPopup