----- 法宝面板 -----
require("Base/BasePanel")
RoleTalismanPanelV2 = Inherit(BasePanel)
local this=RoleTalismanPanelV2
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local propertyConfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local artResourcesConfig=ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

local index
local curHeroData --当前英雄数据
local heroListData = {}--全部英雄数据

local curTalismanConFig --当前法宝表数据
local nextTalismanConFig --EquipTalismana下一等级表数据

local maxLv=0 --法宝最大进阶等级
local curLv=0 --当前法宝等级
local orginLayer
--属性容器
local proList = {}


function RoleTalismanPanelV2:InitComponent()
    orginLayer =0
    this.effect = Util.GetGameObject(this.gameObject,"Effect")--背景特效
    this.backBtn= Util.GetGameObject(this.gameObject, "BackBtn/Btn")
    this.advanceBtn=Util.GetGameObject(this.gameObject,"AdvanceBtn")--进阶按钮
    this.leftBtn = Util.GetGameObject(this.gameObject, "LeftBtn")
    this.rightBtn = Util.GetGameObject(this.gameObject, "RightBtn")
    this.helpBtn= Util.GetGameObject(this.transform, "HelpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition

    this.force = Util.GetGameObject(this.gameObject, "PowerBtn/Value"):GetComponent("Text")--战力
    this.heroIcon=Util.GetGameObject(this.gameObject,"TalismanRoot/HeroHead/mask/icon"):GetComponent("Image") --m5

    this.talismanImage = Util.GetGameObject(this.gameObject, "TalismanRoot/TalismanImage")
    this.talismanIcon = Util.GetGameObject(this.gameObject, "TalismanRoot/TalismanImage/Icon"):GetComponent("Image")
    this.talismanName = Util.GetGameObject(this.gameObject, "TalismanRoot/TalismanImage/Name/Text"):GetComponent("Text")

    --滚动条
    this.content=Util.GetGameObject(this.gameObject,"ScrollView/Viewport/Content"):GetComponent("RectTransform")

    this.basics=Util.GetGameObject(this.gameObject,"ScrollView/Viewport/Content/Basics")
    --属性预设
    this.proPre=Util.GetGameObject(this.basics,"Root/ProPre")
    --属性列表父物体
    this.proRoot=Util.GetGameObject(this.basics,"Root")

    this.core=Util.GetGameObject(this.gameObject,"ScrollView/Viewport/Content/Core")
    this.coreText=Util.GetGameObject(this.core,"Mask/Text"):GetComponent("Text")

    this.dower=Util.GetGameObject(this.gameObject,"ScrollView/Viewport/Content/Dower")
    this.dowerText=Util.GetGameObject(this.dower,"Mask/Text"):GetComponent("Text")
end

function RoleTalismanPanelV2:BindEvent()
    --返回按钮
    Util.AddClick(this.backBtn, function()
        local teamHero=FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_NORMAL)
        --PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        if RoleInfoPanel.RefreshHeroDatas then
            RoleInfoPanel:RefreshHeroDatas(curHeroData,HeroManager.GetAllHeroDatas(),teamHero[curHeroData.dynamicId]~=nil)
        end
        self:ClosePanel()
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.NewTalisman,this.helpPosition.x,this.helpPosition.y)
    end)
    --左右按钮
    Util.AddClick(this.leftBtn, function()
        this.LeftBtnOnClick()
    end)
    Util.AddClick(this.rightBtn, function()
        this.RightBtnOnClick()
    end)
    --进阶按钮
    Util.AddClick(this.advanceBtn, function()
        if curHeroData.talismanList<maxLv then
            UIManager.OpenPanel(UIName.TalismanInfoPanel,curHeroData,heroListData)
        end
    end)
end

function RoleTalismanPanelV2:AddListener()
end

function RoleTalismanPanelV2:RemoveListener()
end

function RoleTalismanPanelV2:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

function RoleTalismanPanelV2:OnOpen(_curHeroData,_heroListData)
    curHeroData=_curHeroData
    heroListData = {}
    if _heroListData then
        for i = 1, #_heroListData do
            if TalismanManager.GetCurHeroIsOpenTalisman(_heroListData[i]) then
                table.insert(heroListData,_heroListData[i])
            end
        end
    else
       local curheroListData=HeroManager.GetAllHeroDatas()
        for i = 1, #curheroListData do
            if TalismanManager.GetCurHeroIsOpenTalisman(curheroListData[i]) then
                table.insert(heroListData,curheroListData[i])
            end
        end
    end
end

function RoleTalismanPanelV2:OnShow()
    for i = 1, #heroListData do
        if curHeroData == heroListData[i] then
            index = i
        end
    end
    --已激活法宝的Hero为1时 隐藏左右按钮
    this.leftBtn.gameObject:SetActive(#heroListData>1)
    this.rightBtn.gameObject:SetActive(#heroListData>1)

    this.OnShowHeroAndTalisman()
end
function RoleTalismanPanelV2:OnClose()
end
function RoleTalismanPanelV2:OnDestroy()
    proList={}
end


--右切换按钮点击
function this.RightBtnOnClick()
    index = (index + 1 <= #heroListData and index + 1 or 1)
    curHeroData = heroListData[index]
    this.OnShowHeroAndTalisman()
end
--左切换按钮点击
function this.LeftBtnOnClick()
    index = (index - 1 > 0 and index - 1 or #heroListData)
    curHeroData = heroListData[index]
    this.OnShowHeroAndTalisman()
end

--刷新界面
function this.OnShowHeroAndTalisman()
    this.content:DOAnchorPosY(0, 0)
    local data = ConfigManager.GetConfigData(ConfigName.HeroConfig,curHeroData.id).EquipTalismana--当前法宝数据 data[1]星级 data[2]法宝ID
    --获取法宝最大等级
    TalismanManager.GetStartAndEndStar()
    maxLv=TalismanManager.AllTalismanEndStar[data[2]]
    --获取当前法宝等级
    curLv=HeroManager.GetTalismanLv(curHeroData.dynamicId)
    --当前法宝数据
    curTalismanConFig= ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana,"TalismanaId",data[2],"Level",curLv)

    --到达顶阶按钮效果
    this.advanceBtn:GetComponent("Button").interactable=curLv<maxLv
    if curLv>=maxLv then
        Util.GetGameObject(this.advanceBtn,"Text"):GetComponent("Text").text=GetLanguageStrById(11866)
    else
        Util.GetGameObject(this.advanceBtn,"Text"):GetComponent("Text").text=GetLanguageStrById(11845)
    end

    this.heroIcon.sprite = Util.LoadSprite(GetResourcePath(curHeroData.heroConfig.Icon))--英雄头像
    this.heroIcon.gameObject:GetComponent("RectTransform").localScale=Vector3.one --m5
    this.force.text = TalismanManager.CalculateWarForceBase(curTalismanConFig,0)--法宝战力
    this.talismanIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[data[2]].ResourceID))
    -- this.talismanImage:GetComponent("Image").sprite = Util.LoadSprite(TalismanBubble[itemConfig[data[2]].Quantity]) --m5 去掉此图
    this.talismanName.text = string.format( "%s <color=#FE5022><size=42>+%s</size></color>",GetLanguageStrById(itemConfig[data[2]].Name),curLv)

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
        local item= proList[i]
        if not item then
            item= newObjToParent(this.proPre,this.proRoot)
            item.name="ProPre"..i
            proList[i]=item
        end
        --local proName=proList[i]:GetComponent("Text")  m5
        local proImage=Util.GetGameObject(proList[i],"Image"):GetComponent("Image")
        local proSName = Util.GetGameObject(proList[i],"ShuName"):GetComponent("Text") --m5
        local proNum = Util.GetGameObject(proList[i],"num"):GetComponent("Text")  --m5

        local skillId=curTalismanConFig.Property[i][1]
        local curValue=curTalismanConFig.Property[i][2]
        --proName.text= " "..propertyConfig[skillId].Info.."<size=32>"..curValue.."</size>"  m5
        proSName.text = propertyConfig[skillId].Info.."+"  --m5
        proNum.text = curValue  --m5
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
        if curLv>=dowerData[n].Level then --如果已激活 显示绿色
            strTable[n]= string.format( GetLanguageStrById(11613), "<color=#66FF00>",passiveSkillConfig[dowerData[n].OpenSkillRules[1]].Desc,dowerData[n].Level,"</color>\n")
        else    --否则就正常显示
            strTable[n]=string.format( GetLanguageStrById(11614),passiveSkillConfig[dowerData[n].OpenSkillRules[1]].Desc,dowerData[n].Level,"\n")
        end
        if dowerData[n].Level==25 then --特性显示
            strTable[n]=string.gsub(strTable[n],"·","")
            local str=GetLanguageStrById(11615)..strTable[n]
            strTable[n]=string.gsub(str," ","　") --unity text中的单词过长 避免自动添加空格并换行 将那个空格替换
        end
    end

    local str=string.sub(table.concat(strTable),1,-2)--将表里字符串拼接 --去除最后\n
    this.dowerText.text=str
end
return RoleTalismanPanelV2