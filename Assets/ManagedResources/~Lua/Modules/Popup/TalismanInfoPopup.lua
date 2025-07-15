----- 通用弹窗 -----
require("Base/BasePanel")
TalismanInfoPopup = Inherit(BasePanel)
local this=TalismanInfoPopup
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local propertyConfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)
local artResourcesConfig=ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

local curHeroData--当前英雄数据
local curHeroConfig
local proList = {}--属性容器
local Type=0
local TypeLv=0


function TalismanInfoPopup:InitComponent()
    this.backBtn=Util.GetGameObject(this.gameObject,"Panel/BackBtn")
    this.BackMask=Util.GetGameObject(this.gameObject,"BackMask")
    this.title=Util.GetGameObject(this.gameObject,"Panel/Title"):GetComponent("Text")

    --滚动条
    this.content=Util.GetGameObject(this.gameObject,"Panel/ScrollView/Viewport/Content"):GetComponent("RectTransform")

    this.core=Util.GetGameObject(this.gameObject,"Panel/ScrollView/Viewport/Content/Core")
    this.coreText=Util.GetGameObject(this.core,"Info"):GetComponent("Text")
    this.talismanIcon = Util.GetGameObject(this.core, "TalismanRoot/Icon"):GetComponent("Image")
    this.power=Util.GetGameObject(this.core,"TalismanRoot/Power/Value"):GetComponent("Text")

    this.basics=Util.GetGameObject(this.gameObject,"Panel/ScrollView/Viewport/Content/Basics")
    --属性预设
    this.proPre=Util.GetGameObject(this.basics,"Root/ProPre")
    --属性列表父物体
    this.proRoot=Util.GetGameObject(this.basics,"Root")

    this.dower=Util.GetGameObject(this.gameObject,"Panel/ScrollView/Viewport/Content/Dower")
    this.dowerText=Util.GetGameObject(this.dower,"Mask/Text"):GetComponent("Text")
end

function TalismanInfoPopup:BindEvent()
     --返回按钮
     Util.AddClick(this.backBtn,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)Util.AddClick(this.BackMask,function()
        self:ClosePanel()
    end)
end

function TalismanInfoPopup:AddListener()

end

function TalismanInfoPopup:RemoveListener()

end

function TalismanInfoPopup:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

function TalismanInfoPopup:OnOpen(...)
    local args={...}
    curHeroData=args[1]
    if args[2] then
        Type=1
        curHeroConfig=args[1]
        TypeLv=args[3]
    end
end

function TalismanInfoPopup:OnShow()
    this.Show()
end

function TalismanInfoPopup:OnClose()
end

function TalismanInfoPopup:OnDestroy()
    proList={}
end


--显示
function this.Show()
    this.content:DOAnchorPosY(0, 0)
    local data={}
    local curLv--获取当前法宝等级
    if Type==1 then
        data = ConfigManager.GetConfigData(ConfigName.HeroConfig,curHeroConfig.Id).EquipTalismana--当前法宝数据 data[1]星级 data[2]法宝ID
        curLv=TypeLv
    else
        data = ConfigManager.GetConfigData(ConfigName.HeroConfig,curHeroData.id).EquipTalismana--当前法宝数据 data[1]星级 data[2]法宝ID
        curLv=HeroManager.GetTalismanLv(curHeroData.dynamicId)
    end

    --当前法宝数据
    local curTalismanConFig= ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana,"TalismanaId",data[2],"Level",curLv)

    --标题
    this.title.text= string.format( "%s <color=#FE5022><size=50>+%s</size></color>",GetLanguageStrById(itemConfig[data[2]].Name),curLv)
    this.talismanIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[data[2]].ResourceID))
    this.power.text = TalismanManager.CalculateWarForceBase(curTalismanConFig,0)--法宝战力
    --显示核心特性(25级解锁)
    local skillLv= ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana,"TalismanaId",data[2],"Level",25).OpenSkillRules[1]
    if skillLv then
        if curLv<25 then
            this.coreText.text=string.format( GetLanguageStrById(11611),passiveSkillConfig[skillLv].Desc,25)
        else
            this.coreText.text=string.format( "%s【%s】",passiveSkillConfig[skillLv].Desc,GetLanguageStrById(11612))
        end
    end

    --显示基础属性
    for i=1,#curTalismanConFig.Property do
        if not proList[i] then
            proList[i]= newObjToParent(this.proPre,this.proRoot)
            proList[i].name="ProPre"..i
        end
        local proName=proList[i]:GetComponent("Text")
        local proImage=Util.GetGameObject(proList[i],"Image"):GetComponent("Image")

        local skillId=curTalismanConFig.Property[i][1]
        local curValue=curTalismanConFig.Property[i][2]
        proName.text= "	   "..propertyConfig[skillId].Info.."+<size=40>"..curValue.."</size>"
        proImage.sprite=Util.LoadSprite(artResourcesConfig[propertyConfig[skillId].PropertyIcon].Name)
        Util.GetGameObject(proImage.gameObject,"Image"):GetComponent("Image"):SetNativeSize()
    end

    --显示法宝天赋
    --筛选出符合要求的数据
    local dowerAllData={}--当前法宝全部天赋数据(天赋可能为空)
    dowerAllData= ConfigManager.GetAllConfigsDataByKey(ConfigName.EquipTalismana,"TalismanaId",data[2])
    local dowerData={}--当前法宝全部技能数据（天赋不为空）
    for i=1,#dowerAllData do
        if dowerAllData[i].OpenSkillRules then
            table.insert( dowerData, dowerAllData[i])
        end
    end
    table.sort(dowerData, function(a,b) return a.OpenSkillRules[1]<b.OpenSkillRules[1] end)
    --赋值到表现
    local strTable={}
    for n=1,#dowerData do
        if curLv>=dowerData[n].Level then
            strTable[n]= string.format( GetLanguageStrById(11613), "<color=#66FF00>",passiveSkillConfig[dowerData[n].OpenSkillRules[1]].Desc,dowerData[n].Level,"</color>\n")
        else
            strTable[n]=string.format( GetLanguageStrById(11614),passiveSkillConfig[dowerData[n].OpenSkillRules[1]].Desc,dowerData[n].Level,"\n")
        end

        if dowerData[n].Level==25 then
            strTable[n]=string.gsub(strTable[n],"·","")
            strTable[n]=GetLanguageStrById(11615)..strTable[n]
        end
    end
    local str=table.concat(strTable)--将表里字符串拼接
                                                      --看这下面 是全角空格哦~
    this.dowerText.text=string.sub(string.gsub(str," ","　"),1,-2)--去除最后\n
end

return TalismanInfoPopup