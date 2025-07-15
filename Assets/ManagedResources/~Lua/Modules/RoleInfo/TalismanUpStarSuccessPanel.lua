----- 进阶成功面板 -----
require("Base/BasePanel")
TalismanUpStarSuccessPanel = Inherit(BasePanel)
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local propertyConfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local curHeroData={} --当前英雄数据
local curTalismanData = {}--当前法宝数据
local maxLv=0 --法宝最大进阶等级
local curLv=0 --当前法宝等级
local isMaxStar = false --默认不是最大进阶等级
local callBack1
local callBack2
--属性容器
local proList = {}
local orginLayer = 20

function TalismanUpStarSuccessPanel:InitComponent()
    orginLayer = 20
    self.BtnBack = Util.GetGameObject(self.transform, "backBtn")
    self.mask = Util.GetGameObject(self.transform, "mask")
    self.icon = Util.GetGameObject(self.transform, "icon"):GetComponent("Image")

    self.heroName = Util.GetGameObject(self.transform, "heroInfo/nameAndPossLayout/heroName"):GetComponent("Text")
    self.UI_Effect_chouka=Util.GetGameObject(self.transform, "UI_Effect_chouka")

    --基础属性
    self.basics=Util.GetGameObject(self.gameObject,"Info/Panel/Basics")
    self.proRoot=Util.GetGameObject(self.basics,"Root")
    self.proPre=Util.GetGameObject(self.basics,"Root/Pre")

    --特性提升
    self.speciality=Util.GetGameObject(self.gameObject,"Info/Panel/Speciality")
    self.specialityText=Util.GetGameObject(self.speciality,"Text"):GetComponent("Text")
end

function TalismanUpStarSuccessPanel:BindEvent()
    Util.AddClick(self.BtnBack, function()
        --未达顶级 返回进阶
        if callBack1 and not isMaxStar then
            callBack1()
        end
        --已达顶级 返回法宝详情
        if callBack2 and isMaxStar then
            callBack2()
        end
        self:ClosePanel()
    end)
end

function TalismanUpStarSuccessPanel:AddListener()
end

function TalismanUpStarSuccessPanel:RemoveListener()
end

function TalismanUpStarSuccessPanel:OnOpen(...)
    local args={...}
    curHeroData=args[1]
    callBack1=args[2]
    callBack2=args[3]
end

function TalismanUpStarSuccessPanel:OnShow()
    self:ShowProAndSkillData()
end

function TalismanUpStarSuccessPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.UI_Effect_chouka, self.sortingOrder - orginLayer)
    self.mask:GetComponent("Canvas").overrideSorting = true
    self.mask:GetComponent("Canvas").sortingOrder = self.sortingOrder - 30
    orginLayer = self.sortingOrder
end

function TalismanUpStarSuccessPanel:ShowProAndSkillData()
    self.speciality:SetActive(false)
    local data={}   --英雄表下法宝属性
    data=ConfigManager.GetConfigData(ConfigName.HeroConfig,curHeroData.id).EquipTalismana--当前法宝数据 data[1]星级 data[2]法宝ID
    --获取法宝最大等级
    TalismanManager.GetStartAndEndStar()
    maxLv=TalismanManager.AllTalismanEndStar[data[2]]
    --获取当前法宝等级(-1的作用是当打开进阶成功时 英雄已经升级了 应该-1与进阶前保持一致)
    curLv=HeroManager.GetTalismanLv(curHeroData.dynamicId)-1
    if curLv<1 then curLv=1 end
    --获取当前等级与下一等级表数据
    local nextLv=0
    if curLv<= maxLv then nextLv=curLv+1 end
    isMaxStar = (curLv+1) >= maxLv
    curTalismanData= ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana,"TalismanaId",data[2],"Level",curLv)
    local nextTalismanConFig={}
    if not isMaxStar then
        nextTalismanConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId",  data[2], "Level", nextLv)
    end

    --法宝图面 名称 等级
    self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[data[2]].ResourceID))
    self.heroName.text =  string.format( "%s +%s",GetLanguageStrById(itemConfig[data[2]].Name),curHeroData.talismanList)

    --显示基础属性
    for i=1,#curTalismanData.Property do
        local item= proList[i]
        if not item then
            item= newObjToParent(self.proPre,self.proRoot)
            item.name="ProPre"..i
            proList[i]=item
        end
        local curName=Util.GetGameObject(proList[i],"CurName"):GetComponent("Text")
        local curValue=Util.GetGameObject(proList[i],"CurValue"):GetComponent("Text")
        local nextName=Util.GetGameObject(proList[i],"NextName"):GetComponent("Text")
        local nextValue=Util.GetGameObject(proList[i],"NextValue"):GetComponent("Text")

        curName.text=propertyConfig[curTalismanData.Property[i][1]].Info
        curValue.text=curTalismanData.Property[i][2]
        if not isMaxStar then
            nextName.text=propertyConfig[nextTalismanConFig.Property[i][1]].Info
            nextValue.text=nextTalismanConFig.Property[i][2]
        end
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
        if (curLv+1)==dowerData[n].Level then
            self.speciality:SetActive(true)
            self.specialityText.text=passiveSkillConfig[dowerData[n].OpenSkillRules[1]].Desc
            return
        end
    end

end

function TalismanUpStarSuccessPanel:OnClose()
    callBack = nil
    self.speciality:SetActive(false)
end

function TalismanUpStarSuccessPanel:OnDestroy()
    proList={}
end

return TalismanUpStarSuccessPanel