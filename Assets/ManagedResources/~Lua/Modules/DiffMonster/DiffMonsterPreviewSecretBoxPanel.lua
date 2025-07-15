---秘盒招募异妖预览
require("Base/BasePanel")
DiffMonsterPreviewSecretBoxPanel = Inherit(BasePanel)
local this=DiffMonsterPreviewSecretBoxPanel

this.liveName=nil
this.livePre=nil
local kInitLevel = 1
--初始化组件（用于子类重写）
function DiffMonsterPreviewSecretBoxPanel:InitComponent()
    this.backBtn=Util.GetGameObject(self.gameObject,"BackBtn")
    this.liveRoot=Util.GetGameObject(self.gameObject,"LiveRoot")
    this.intelligenceImage=Util.GetGameObject(self.gameObject,"IntelligenceBg"):GetComponent("Image")
    this.intelligenceValue = Util.GetGameObject(self.gameObject, "IntelligenceBg/Value"):GetComponent("Text")
    this.name=Util.GetGameObject(self.gameObject,"Name/Text"):GetComponent("Text")

    this.skillInfo = Util.GetGameObject(self.gameObject, "SkillInfo")
    this.skillIcon = Util.GetGameObject(self.skillInfo, "SkillBg/SkillIcon"):GetComponent("Image")
    this.skillName = Util.GetGameObject(self.skillInfo, "SkillNameBg/SkillName"):GetComponent("Text")
    this.skillDesc = Util.GetGameObject(self.skillInfo, "SkillDesc"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function DiffMonsterPreviewSecretBoxPanel:BindEvent()
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function DiffMonsterPreviewSecretBoxPanel:AddListener()

end

--移除事件监听（用于子类重写）
function DiffMonsterPreviewSecretBoxPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function DiffMonsterPreviewSecretBoxPanel:OnOpen(...)
    local itemdata={}
    table.insert(itemdata,SecretBoxManager.StarDifferDemonsId[1])
    local diffId = DiffMonsterManager.GetDiffMonsterByComponentId(itemdata[1])--获取异妖ID

    local scale=Vector3.New(PokemonEffectConfig[diffId].scale,PokemonEffectConfig[diffId].scale,PokemonEffectConfig[diffId].scale)
    this.liveName=PokemonEffectConfig[diffId].live
    this.livePre=poolManager:LoadLive(this.liveName,this.liveRoot.transform,scale,Vector3.New(0,0,0))

    local data=ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig,diffId)

    this.intelligenceImage.sprite=GetQuantityImage(data.Aptitude)
    this.intelligenceValue.text=data.Aptitude
    this.name.text=data.Name
    this:SetSkillInfo(diffId)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DiffMonsterPreviewSecretBoxPanel:OnShow()

end

--界面关闭时调用（用于子类重写）
function DiffMonsterPreviewSecretBoxPanel:OnClose()
    if this.liveName then
        poolManager:UnLoadLive(this.liveName, this.livePre)
        this.liveName=nil
        this.livePre=nil
    end
end

--界面销毁时调用（用于子类重写）
function DiffMonsterPreviewSecretBoxPanel:OnDestroy()

end

--设置技能信息
function this:SetSkillInfo(id)
    local pokemon= DiffMonsterManager.GetSinglePokemonData(id)
    local skillId = pokemon.pokemonUpLvConfigList[kInitLevel].configData.SkillId
    local skillConfig = ConfigManager.TryGetConfigData(ConfigName.SkillConfig, skillId)
    if skillConfig then
        this.skillIcon.sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
        this.skillName.text = GetLanguageStrById(skillConfig.Name)
        this.skillDesc.text = GetSkillConfigDesc(skillConfig)
    end
end

return DiffMonsterPreviewSecretBoxPanel