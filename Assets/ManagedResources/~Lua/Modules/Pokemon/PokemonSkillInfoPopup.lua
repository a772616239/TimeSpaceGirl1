require("Base/BasePanel")
local PokemonSkillInfoPopup = Inherit(BasePanel)
local this = PokemonSkillInfoPopup
local pokemonSkillPreList = {}--预设
local pokemonSkillDataList = {}--数据
local pokemonSid = 0
local pokemonLv = 0
local pokemonStar = 0
--初始化组件（用于子类重写）
function PokemonSkillInfoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "Button")

    this.titleText = Util.GetGameObject(self.transform, "Content/Title/Text"):GetComponent("Text")
    this.skillIcon = Util.GetGameObject(self.transform, "Content/IconBG/Icon"):GetComponent("Image")
    this.skillLv = Util.GetGameObject(self.transform, "Content/IconBG/Level/Text"):GetComponent("Text")
    this.curSkillLv = Util.GetGameObject(self.transform, "Content/curInfo/lvText"):GetComponent("Text")
    this.curSkillInfo = Util.GetGameObject(self.transform, "Content/curInfo/Text (1)"):GetComponent("Text")

    for i = 1, 2 do
        pokemonSkillPreList[i] = Util.GetGameObject(self.transform, "Content/skillDesc (".. i ..")")
    end
end

--绑定事件（用于子类重写）
function PokemonSkillInfoPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function PokemonSkillInfoPopup:AddListener()
end

--移除事件监听（用于子类重写）
function PokemonSkillInfoPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function PokemonSkillInfoPopup:OnOpen(_pokemonSid,_pokemonLv,_pokemonStar)
    pokemonSid = _pokemonSid
    pokemonLv = _pokemonLv
    pokemonStar = _pokemonStar
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PokemonSkillInfoPopup:OnShow()
    this.ShowPokemonSkillList()
end

function this.ShowPokemonSkillList()
    pokemonSkillDataList = {}
    local curSkillId = PokemonManager.GetCurStarSkillId(pokemonSid,pokemonStar)
    local nextSkillId = PokemonManager.GetCurStarSkillId(pokemonSid,pokemonStar + 1)
    local curSkillConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,curSkillId)
    table.insert(pokemonSkillDataList,curSkillConFig)
    if nextSkillId then
        local nextSkillConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,nextSkillId)
        table.insert(pokemonSkillDataList,nextSkillConFig)
    end
    this.titleText.text = curSkillConFig.Name
    this.skillIcon.sprite = Util.LoadSprite(GetResourcePath(curSkillConFig.Icon))
    this.skillLv.text = curSkillConFig.Level
    this.curSkillLv.text = string.format(GetLanguageStrById(23088), curSkillConFig.Level)
    this.curSkillInfo.text = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,pokemonSid).SkillDesc

    for i = 1, #pokemonSkillPreList do
        if pokemonSkillDataList[i] then
            pokemonSkillPreList[i]:SetActive(true)
            this.ShowSinglePokemonSkillList(pokemonSkillPreList[i],pokemonSkillDataList[i],i)
        else
            pokemonSkillPreList[i]:SetActive(false)

        end
    end
end
function this.ShowSinglePokemonSkillList(go,data,index)
    Util.GetGameObject(go, "lvText"):GetComponent("Text").text = string.format(GetLanguageStrById(23088), data.Level)
    Util.GetGameObject(go, "Text (1)"):GetComponent("Text").text = data.Desc
    Util.AddOnceClick(Util.GetGameObject(go, "Text (1)"), function()
        UIManager.OpenPanel(UIName.PokemonAllSkillInfoPopup,pokemonSid,pokemonLv,pokemonStar)
    end)
end

--界面关闭时调用（用于子类重写）
function PokemonSkillInfoPopup:OnClose()
   
end

--界面销毁时调用（用于子类重写）
function PokemonSkillInfoPopup:OnDestroy()
  
end

return PokemonSkillInfoPopup