require("Base/BasePanel")
require("Modules/RoleInfo/RoleInfoPanel")
HandBookHeroInfoPanel = Inherit(BasePanel)
local this = HandBookHeroInfoPanel
local heroConFigData
local leftHeroData
local rightHeroData
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local heroLevelConfig = ConfigManager.GetConfig(ConfigName.HeroLevelConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local passiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local allAddProVal = {}
local isClickLeftOrRightBtn = true
local index = 0
local leftIndex = 0
local rightIndex = 0
local starType = 1
local type = 1
local pinjieImage = {"cn2-x1_TB_jieji_weijihuo","cn2-x1_TB_jieji"} --品阶图片 1是未激活 2是激活 --m5
local liveDeviation --立绘偏移
-- local utf8 = require("utf8")
--英雄定位
local ProfessionImage = {
    [1] = "cn2-X1_tongyong_yingxiongdingwei_01",
    [2] = "cn2-X1_tongyong_yingxiongdingwei_03",
    [3] = "cn2-X1_tongyong_yingxiongdingwei_02",
    [4] = "cn2-X1_tongyong_yingxiongdingwei_04",
}

--初始化组件（用于子类重写）
function HandBookHeroInfoPanel:InitComponent()

    self.btnBack = Util.GetGameObject(self.transform, "btnBack")
    self.curObj = Util.GetGameObject(self.transform, "curObj")
    self.leftObj = Util.GetGameObject(self.transform, "leftObj")
    self.rightObj = Util.GetGameObject(self.transform, "rightObj")
    self.leftBtn = Util.GetGameObject(self.transform, "leftBtn") 
    self.rightBtn = Util.GetGameObject(self.transform, "rightBtn")

    self.starGrid = Util.GetGameObject(self.transform, "info/starGrid")

    self.heroName = Util.GetGameObject(self.transform, "info/name/heroName"):GetComponent("Text")
    self.profession = Util.GetGameObject(self.transform, "info/name/proImage"):GetComponent("Image")

    self.roleInfoLayout = Util.GetGameObject(self.transform,"roleInfoLayout")
    self.roleStoryLayout = Util.GetGameObject(self.transform,"roleStoryLayout")
    this.recommend = Util.GetGameObject(self.transform, "recommend")

    --详情
    self.info = Util.GetGameObject(self.roleInfoLayout,"Info")
    self.atkPro = Util.GetGameObject(self.info,"pro/atk")
    self.hpPro = Util.GetGameObject(self.info,"pro/hp")
    self.phyDef = Util.GetGameObject(self.info,"pro/phyDef")
    self.Speed = Util.GetGameObject(self.info,"pro/Speed")
    self.lv = Util.GetGameObject(self.info,"pro/lv/proValue"):GetComponent("Text")
    self.lvMax = Util.GetGameObject(self.info,"pro/lv/proValueMax"):GetComponent("Text")
    self.posImage = Util.GetGameObject(self.info,"proIcon"):GetComponent("Image")
    self.posText = Util.GetGameObject(self.info,"proIcon/Text"):GetComponent("Text")
    self.pos = Util.GetGameObject(self.info,"pos"):GetComponent("Image")

    self.skillGrid = Util.GetGameObject(self.roleInfoLayout,"skill/skillGroup")
    self.allProButton = Util.GetGameObject(self.info,"helpBtn")
    this.btnList = Util.GetGameObject(self.transform, "btnList")

    --传记
    self.btnStory = Util.GetGameObject(self.transform, "btnList/btnStory")
    self.btnStoryRedpot = Util.GetGameObject(self.transform, "btnList/btnStory/redPoint")
    self.infoTextStory = Util.GetGameObject(self.transform,"roleStoryLayout/infoBg/infoRect/infoText"):GetComponent("Text")

    --领取
    this.reward = Util.GetGameObject(self.transform, "roleStoryLayout/reward")
    this.rewardBtn = Util.GetGameObject(self.transform, "roleStoryLayout/reward/rewardBtn")
    this.frame = Util.GetGameObject(self.transform, "roleStoryLayout/reward/frame")
    this.rewardTip = Util.GetGameObject(self.transform, "roleStoryLayout/reward/Tip")
    this.rewardRedPoint = Util.GetGameObject(self.transform, "roleStoryLayout/reward/redPoint")

    this.ItemView = SubUIManager.Open(SubUIConfig.ItemView, this.reward.transform)

    --详细信息
    self.btnInfo = Util.GetGameObject(self.transform, "btnList/btnInfo")
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    this.commentBtn = Util.GetGameObject(self.gameObject,"commentBtn")--定位按钮
    this.core = Util.GetGameObject(self.gameObject,"roleInfoLayout/core")

    this.btnComment = Util.GetGameObject(self.transform, "roleInfoLayout/CommentBtn")
end

--绑定事件（用于子类重写）
function HandBookHeroInfoPanel:BindEvent()
    Util.AddClick(self.allProButton, function()
        UIManager.OpenPanel(UIName.RoleProInfoPopup,allAddProVal,heroConFigData.heroConfig,false)
    end)
    Util.AddClick(self.btnStory, function()
        self:SetSelectBtn(self.btnStory, GetLanguageStrById(12670))
        self:OnShowHeroData(2,1)

        local tweenEndVer = Vector2.New(heroConFigData.heroConfig.Position[1],heroConFigData.heroConfig.Position[2])
        this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.3, false):SetEase(Ease.Linear)
        liveDeviation = 0
    end)
    Util.AddClick(self.btnInfo, function()
        self:SetSelectBtn(self.btnInfo, GetLanguageStrById(12512))
        self:OnShowHeroData(1,2)

        local tweenEndVer = Vector2.New(heroConFigData.heroConfig.Position[1] - 150,heroConFigData.heroConfig.Position[2])
        this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.3, false):SetEase(Ease.Linear)
        liveDeviation = -1
    end)
    Util.AddClick(this.leftBtn, function()
        self:LeftBtnOnClick()
    end)

    Util.AddClick(this.rightBtn, function()
        self:RightBtnOnClick()
    end)
    Util.AddClick(self.btnBack, function()
        self:ClosePanel(UIName.RolePosInfoPopup,heroConFigData.heroConfig)
    end)
    Util.AddClick(this.rewardBtn, function()
        NetManager.GetHandBookHero(heroConFigData.heroConfig.Id,function(msg)
            -- NetManager.PlayerInfoRequest(function()
                PlayerManager.ReceivedHandBookData(heroConFigData.heroConfig.Id,heroConFigData.star)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1)
                self:OnShowHeroData(2,1)
            -- end)
        end)
    end)
    Util.AddClick(this.commentBtn, function()
        NetManager.RequestEvaluateTank(heroConFigData.Id,1,1,function (msg)
            UIManager.OpenPanel(UIName.EvaluateTankPopup,msg,heroConFigData) 
        end)
    end)
    Util.AddClick(this.btnComment, function ()
        UIManager.OpenPanel(UIName.CommentPanel, heroConFigData.heroConfig)
    end)
end

local heroDatas = {}
local showType
--界面打开时调用（用于子类重写）   第一个参数  英雄数据   第二个参数 属性id 
function HandBookHeroInfoPanel:OnOpen(...)
    local temp = {...}
    heroDatas = {}
    heroConFigData = temp[1]
    heroDatas = PlayerManager.heroHandBookListData
    showType = temp[3]
    for n,m in ipairs(heroDatas) do
        if heroConFigData.heroConfig.Id == m.heroConfig.Id and heroConFigData.star == m.star then
            index = n
            break
        else
            index = 1
        end
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function HandBookHeroInfoPanel:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.HandBookHeroInfoPanel })
    isClickLeftOrRightBtn = true
    for i = 1, #heroDatas do
        if heroConFigData.heroConfig.Id == heroDatas[i].heroConfig.Id and heroConFigData.star == heroDatas[i].star then
            index = i
            break
        end
    end
    self:UpdateLiveList()

    this.leftLiveObj = LoadHerolive(leftHeroData.heroConfig,self.leftObj)
    this.leftLiveObj.gameObject:SetActive(false)
    this.rightLiveObj = LoadHerolive(rightHeroData.heroConfig,self.rightObj)
    this.rightLiveObj.gameObject:SetActive(false)
    this.curLiveObj = LoadHerolive(heroConFigData.heroConfig,self.curObj)
    this.curLiveObj.gameObject:SetActive(true)

    if heroConFigData.star > 5 then
        self:OnShowHeroData(1,2)
    else
        self:OnShowHeroData(1,1)
    end

    self:SetSelectBtn(self.btnInfo, GetLanguageStrById(12512))
    local tweenEndVer = Vector2.New(heroConFigData.heroConfig.Position[1] - 150,heroConFigData.heroConfig.Position[2])
    this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.3, false):SetEase(Ease.Linear)
    liveDeviation = -1
end

--展示英雄信息  第一个参数1 属性面板 2 故事面板     第二个参数 1初始  2 6星和10星 第三个参数  显示星级  
function HandBookHeroInfoPanel:OnShowHeroData(_type,_starType)
    type = _type
    self.roleInfoLayout:SetActive(_type == 1)
    self.roleStoryLayout:SetActive(_type == 2)
    SetHeroStars(self.starGrid, heroConFigData.star)
    self.heroName.text = GetLanguageStrById(heroConFigData.heroConfig.ReadingName)
    self.profession.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConFigData.heroConfig.PropertyName))
    -- for i = 1, 4, 1 do
    --     Util.GetGameObject(this.recommend, "Image"..i):GetComponent("Image").sprite=Util.LoadSprite("N1_img_tanke_mingjiahui")
    -- end
    -- if heroConFigData.HeroValue>0 then
    --     this.recommend:SetActive(true)
    --     for i = 1, heroConFigData.HeroValue, 1 do
    --         Util.GetGameObject(this.recommend, "Image"..i):GetComponent("Image").sprite=Util.LoadSprite("N1_img_tanke_mingjia")
    --     end
    -- else
    --     this.recommend:SetActive(false)
    -- end
    -- if _star == 1 then
    --     self.starbackimg:SetActive(false)
    -- else
    --     self.starbackimg:SetActive(true)
    --     self.starbackimg:GetComponent("Image").sprite = Util.LoadSprite(HeroStarBackground[_star])
    -- end
    this.core:SetActive(heroConFigData.heroConfig.HeroValue == 1)
    if heroConFigData.heroConfig.HeroSound then
        SoundManager.PlaySound(heroConFigData.heroConfig.HeroSound)
    end

    --定位描述相关
    self.pos.sprite = Util.LoadSprite(ProfessionImage[heroConFigData.heroConfig.Profession])
    self.posText.text = GetLanguageStrById(heroConFigData.heroConfig.HeroLocation)
    self.posImage.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConFigData.heroConfig.PropertyName))
    --计算面板属性
    allAddProVal = self:CalculateHeroAllProValList(_starType,heroConFigData.star)
    local heroMaxConfig = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.HeroRankupConfig, "Star", heroConFigData.heroConfig.Star, "OpenStar", heroConFigData.star)
    local triggerCallBack
    for i = 1, self.skillGrid.transform.childCount do
        self.skillGrid.transform:GetChild(i-1).gameObject:SetActive(false)
    end   
    local maxRankUpConfig = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.HeroRankupConfig,"Star",heroConFigData.heroConfig.Star,"JudgeClass",1,"Type",1)
    local maxRank
    if maxRankUpConfig then
        maxRank = maxRankUpConfig.Phase[2]
    end
    local skillList = HeroManager.GetSkillIdsByHeroRulesRole(heroConFigData.heroConfig.OpenSkillRules,heroConFigData.star,maxRank)
    local oldOpenPassiveSkillRules = HeroManager.GetPassiveSkillIdsByHeroRuleslock(heroConFigData.heroConfig.OpenPassiveSkillRules,heroConFigData.star,maxRank)
    for key, value in pairs(oldOpenPassiveSkillRules) do
        table.insert(skillList, value)
    end
    table.sort(skillList,function(a,b) 
        return a.skillConfig.Id < b.skillConfig.Id
    end)
    for i = 2, #skillList do
        if skillList[i] and skillList[i].skillConfig and skillList[i].skillConfig.Name then
            local go = Util.GetGameObject(self.skillGrid.transform,"Skill"..(i-1))
            local skillData = {}
            skillData.skillConfig = skillList[i].skillConfig
            local skillLogicConfig_
            local isPassive
            local skillPos
            if skillLogicConfig_ == nil then
                skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.SkillLogicConfig,"Id",skillList[i].skillConfig.Id)
                isPassive = false
            end
            if skillLogicConfig_ == nil then
                skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.PassiveSkillLogicConfig,"Id",skillList[i].skillConfig.Id)
                isPassive = true
            end
           
            local skillID
            if isPassive then
                for j = 1, #heroConFigData.heroConfig.OpenPassiveSkillRules do
                    if heroConFigData.heroConfig.OpenPassiveSkillRules[j][2] == skillLogicConfig_.Group then
                        skillPos = heroConFigData.heroConfig.OpenPassiveSkillRules[j][1]
                        skillID = heroConFigData.heroConfig.OpenPassiveSkillRules[j][2]
                        break
                    end
                end
            else
                for j = 1, #heroConFigData.heroConfig.OpenSkillRules do
                    if heroConFigData.heroConfig.OpenSkillRules[j][2] == skillLogicConfig_.Group then
                        skillPos = heroConFigData.heroConfig.OpenSkillRules[j][1]
                        skillID = heroConFigData.heroConfig.OpenSkillRules[j][2]
                        break
                    end
                end
            end
            local maxLv = HeroManager.GetHeroSkillMaxLevel(heroConFigData.heroConfig.Id, skillPos)

            go:SetActive(true)
            Util.GetGameObject(go.transform,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillList[i].skillConfig.Icon))
            Util.GetGameObject(go.transform,"skillName"):GetComponent("Text").text = GetLanguageStrById(skillList[i].skillConfig.Name)--GetLanguageStrById(10470).. 1(skillList[i].skillConfig.Id % 10)
            Util.GetGameObject(go.transform,"Lv/LvTx"):GetComponent("Text").text = maxLv
            Util.AddOnceClick(Util.GetGameObject(go.transform,"frame"), function()
                if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
                    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
                end
                local panel = UIManager.OpenPanel(UIName.SkillInfoPopup,skillData, 1, 10, maxLv, i, maxLv,nil, skillID * 10 + maxLv)
                triggerCallBack = function (panelType, p)
                    if panelType == UIName.SkillInfoPopup and panel == p then --监听到SkillInfoPopup关闭，把层级设回去
                        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
                    end
                end
                Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
            end)
        end
    end

    this.ItemView:OnOpen(false, {heroConFigData.heroConfig.OwnReward[1], heroConFigData.heroConfig.OwnReward[2]}, 0.7, nil, nil, nil, nil, nil)
    this.ItemView.transform:SetParent(this.frame.transform)
    if PlayerManager.heroHandBook[heroConFigData.heroConfig.Id] ~= nil then
        if PlayerManager.heroHandBook[heroConFigData.heroConfig.Id].status == 1 then
            this.rewardRedPoint:SetActive(false)
            this.rewardTip:SetActive(false)
            Util.GetGameObject(this.reward.transform,"yilingqu"):SetActive(true)
            self.btnStoryRedpot:SetActive(false)
            this.rewardBtn:GetComponent("Button").enabled = false
        else
            this.rewardRedPoint:SetActive(true)
            this.rewardTip:SetActive(true)
            Util.GetGameObject(this.reward.transform,"yilingqu"):SetActive(false)
            if _type == 1 then
                self.btnStoryRedpot:SetActive(true)
            else
                self.btnStoryRedpot:SetActive(false)
            end
            this.rewardBtn:GetComponent("Button").enabled = true
        end
    else
        this.rewardRedPoint:SetActive(false)
        this.rewardTip:SetActive(true)
        Util.GetGameObject(this.reward.transform,"yilingqu"):SetActive(false)
        if _type == 1 then
            -- self.btnStoryRedpot:SetActive(true)
        else
            self.btnStoryRedpot:SetActive(false)
        end
        this.rewardBtn:GetComponent("Button").enabled = false
    end

    --传记
    Util.GetGameObject(self.transform,"roleStoryLayout/infoBg/infoRect/infoText"):GetComponent("RectTransform").anchoredPosition = Vector2.New(-2, 0)
    local stroyStr = string.gsub(heroConFigData.heroConfig.HeroStory,"#","\n")
    
    -- self.infoTextStory.text = string.gsub(GetLanguageStrById(stroyStr),"\\u00A0","　　")--传记
    self.infoTextStory.text = this.decode_unicode_escapes(GetLanguageStrById(stroyStr))

    local hruConfig = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.HeroRankupConfig,"Star",heroConFigData.heroConfig.Star,"Show",1) --动态获取不同英雄最大突破等阶
    local maxBreakLevel = 0
    for i = 1, #hruConfig do --动态生成
        if hruConfig[i].Phase[2] >= maxBreakLevel then
            maxBreakLevel = hruConfig[i].Phase[2]
        end
    end

    this:ProShow(self.atkPro,allAddProVal,HeroProType.Attack)
    this:ProShow(self.hpPro,allAddProVal,HeroProType.Hp)
    this:ProShow(self.phyDef,allAddProVal,HeroProType.PhysicalDefence)
    this:ProShow(self.Speed,allAddProVal,HeroProType.Speed)
    if showType == 1 then
        self.lv.text = 1
        self.lvMax.text = "/"..heroMaxConfig[1].OpenLevel
    else
        self.lv.text = heroMaxConfig[#heroMaxConfig].OpenLevel
        self.lvMax.text = "/"..heroMaxConfig[#heroMaxConfig].OpenLevel
    end
end

function this.decode_unicode_escapes(raw)
    -- print("raw repr:", raw)

    -- gsub 会匹配 \\uXXXX，其中 XXXX 是 4 位十六进制
    local nbsp = string.char(0xC2, 0xA0)

    local decoded = raw:gsub("u{00A0}", nbsp)
    return decoded
end


function this:ProShow(go,allAddProVal,HeroProType,nextallAddProVal)
    local curProSConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,HeroProType)
    Util.GetGameObject(go,"proName"):GetComponent("Text").text = GetLanguageStrById(curProSConFig.Info)
    Util.GetGameObject(go,"proValue"):GetComponent("Text").text = allAddProVal[HeroProType]
    Util.GetGameObject(go,"Image"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(propertyConfig[HeroProType].PropertyIcon))
    if nextallAddProVal then
        Util.GetGameObject(go,"nextproValue"):GetComponent("Text").text = nextallAddProVal[HeroProType]
    end
end

--计算英雄属性   1 初始 2 指定星级    _starNum星级变化 
function HandBookHeroInfoPanel:CalculateHeroAllProValList(_starType,_starNum)
    local allAddProVal = {}
    for i, v in ConfigPairs(propertyConfig) do
        allAddProVal[i] = 0
    end
    local heroRankupConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroRankupConfig, "Star", heroConFigData.heroConfig.Star, "OpenStar", _starNum)
    local curLvNum = 1
    local breakId = 0
    local upStarId = 0
    if _starType == 2 then
        --等级
        curLvNum = heroRankupConfig.OpenLevel
        --解锁天赋
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.HeroRankupConfig)) do
            if v.OpenStar == _starNum and v.Star == heroConFigData.heroConfig.Star then
                if v.Type == 1 then
                    breakId = v.Id
                end
                if v.Type == 2 then
                    upStarId = v.Id
                end
            end
        end
        if breakId == 0 then
            breakId = 6
        end
    end
    allAddProVal[HeroProType.Attack] = HeroManager.CalculateProVal(heroConFigData.heroConfig.Attack, curLvNum, breakId,upStarId,HeroProType.Attack,heroConFigData.heroConfig)
    allAddProVal[HeroProType.Hp] = HeroManager.CalculateProVal(heroConFigData.heroConfig.Hp, curLvNum, breakId,upStarId,HeroProType.Hp,heroConFigData.heroConfig)
    allAddProVal[HeroProType.PhysicalDefence] = HeroManager.CalculateProVal(heroConFigData.heroConfig.PhysicalDefence, curLvNum, breakId,upStarId,HeroProType.PhysicalDefence,heroConFigData.heroConfig)
    allAddProVal[HeroProType.Speed] = HeroManager.CalculateProVal(heroConFigData.heroConfig.Speed, curLvNum, breakId,upStarId,HeroProType.Speed,heroConFigData.heroConfig)

    Util.AddOnceClick(this.talentBtn,function()
        UIManager.OpenPanel(UIName.RoleTalentPopup,heroConFigData.heroConfig,breakId,upStarId)
    end)
    if heroConFigData.heroConfig.OpenPassiveSkillRules then
        local openlists,compoundOpenNum,compoundNum = HeroManager.GetAllPassiveSkillIds(heroConFigData.heroConfig,breakId,upStarId)
    end
    return allAddProVal
end

-- --页签选中效果设置
function HandBookHeroInfoPanel:SetSelectBtn(_btn, btnText)
    for i = 1, this.btnList.transform.childCount do
        Util.GetGameObject(this.btnList.transform:GetChild(i-1),"Select"):SetActive(false)
        Util.GetGameObject(this.btnList.transform:GetChild(i-1),"Unchecked"):SetActive(true)
    end
    Util.GetGameObject(_btn,"Select"):SetActive(true)
    Util.GetGameObject(_btn,"Unchecked"):SetActive(false)
end

function HandBookHeroInfoPanel:UpdateLiveList()
    if index - 1 > 0 then
        leftIndex = index - 1
    else      
        leftIndex = #heroDatas
    end
    
    leftHeroData = heroDatas[leftIndex]  

    if index + 1 <= #heroDatas then
        rightIndex = index + 1
    else    
        rightIndex = 1  
    end  
    
    rightHeroData=heroDatas[rightIndex]
end

--右切换按钮点击
function HandBookHeroInfoPanel:RightBtnOnClick()
    if isClickLeftOrRightBtn == false then
        return
    end
    isClickLeftOrRightBtn = false
    self.rightBtn:GetComponent("Button").enabled = false
    local oldIndexConfigData = heroDatas[index]
    index = rightIndex
    heroConFigData = heroDatas[index]
    if this.leftLiveObj then
        UnLoadHerolive(leftHeroData.heroConfig,this.leftLiveObj)
        Util.ClearChild(self.leftObj.transform)
        this.leftLiveObj = nil
    end

    this.curLiveObj.transform:SetParent(self.leftObj.transform)
    local tweenEndVer = Vector2.New(oldIndexConfigData.heroConfig.Position[1],oldIndexConfigData.heroConfig.Position[2])
    this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.5, false):SetEase(Ease.Linear)
    this.rightLiveObj.transform:SetParent(self.curObj.transform)

    this.rightLiveObj.gameObject:SetActive(true)

    local tweenEndRightVer
    if liveDeviation == -1 then
        tweenEndRightVer = Vector2.New(rightHeroData.heroConfig.Position[1] - 150,rightHeroData.heroConfig.Position[2])
    else
        tweenEndRightVer = Vector2.New(rightHeroData.heroConfig.Position[1],rightHeroData.heroConfig.Position[2])
    end
    this.rightLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndRightVer, 0.5, false):OnComplete(function ()
        this:UpdateLiveList()
        this.leftLiveObj = this.curLiveObj
        this.leftLiveObj.gameObject:SetActive(false)
        this.curLiveObj = this.rightLiveObj
        this.curLiveObj.gameObject:SetActive(true)
        this.rightLiveObj = LoadHerolive(rightHeroData.heroConfig,self.rightObj)
        this.rightLiveObj.gameObject:SetActive(false)
        if heroConFigData.star > 5 then
            self:OnShowHeroData(type,2)
        else
            self:OnShowHeroData(type,1)
        end

        this.rightBtn:GetComponent("Button").enabled = true
        isClickLeftOrRightBtn = true
    end):SetEase(Ease.Linear)
     PlaySoundWithoutClick(SoundConfig.Sound_Switch)

end
--左切换按钮点击
function HandBookHeroInfoPanel:LeftBtnOnClick()
    if isClickLeftOrRightBtn == false then
        return
    end
    isClickLeftOrRightBtn = false
    self.leftBtn:GetComponent("Button").enabled = false
    local oldIndexConfigData = heroDatas[index]
    index = leftIndex
    heroConFigData = heroDatas[index]
    if this.rightLiveObj then
        UnLoadHerolive(rightHeroData.heroConfig,this.rightLiveObj)
        Util.ClearChild(self.rightObj.transform)
        this.rightLiveObj = nil
    end
    
    this.curLiveObj.transform:SetParent(self.rightObj.transform)
    local tweenEndVer = Vector2.New(oldIndexConfigData.heroConfig.Position[1],oldIndexConfigData.heroConfig.Position[2])
    this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.5, false):SetEase(Ease.Linear)
    this.leftLiveObj.transform:SetParent(self.curObj.transform)
    
    this.leftLiveObj.gameObject:SetActive(true)

    --立绘偏移动画
    local tweenEndLeftVer
    if liveDeviation == -1 then
        tweenEndLeftVer = Vector2.New(leftHeroData.heroConfig.Position[1] - 150,leftHeroData.heroConfig.Position[2])
    else
        tweenEndLeftVer = Vector2.New(leftHeroData.heroConfig.Position[1],leftHeroData.heroConfig.Position[2])
    end
    this.leftLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndLeftVer, 0.5, false):OnComplete(function ()
        this:UpdateLiveList()
        this.rightLiveObj = this.curLiveObj
        this.rightLiveObj.gameObject:SetActive(false)
        this.curLiveObj = this.leftLiveObj
        this.curLiveObj.gameObject:SetActive(true)
        this.leftLiveObj = LoadHerolive(leftHeroData.heroConfig,self.leftObj)
        this.leftLiveObj.gameObject:SetActive(false)
        
        if heroConFigData.star > 5 then
            self:OnShowHeroData(type,2)
        else
            self:OnShowHeroData(type,1)
        end

        this.leftBtn:GetComponent("Button").enabled = true
        isClickLeftOrRightBtn = true
    end):SetEase(Ease.Linear)
     PlaySoundWithoutClick(SoundConfig.Sound_Switch)
end

--手指滑动
local beginV3
local endV3
local distance
function HandBookHeroInfoPanel:OnBeginDrag(Pointgo, data)
    beginV3 = this.curLiveObj.transform.anchoredPosition
end
function HandBookHeroInfoPanel:OnDrag(Pointgo, data)
    distance = Vector2.Distance(beginV3,this.curLiveObj.transform.anchoredPosition)
end
function HandBookHeroInfoPanel:OnEndDrag(Pointgo, data)
    endV3 = this.curLiveObj.transform.anchoredPosition
    if distance > 250 and endV3.x < 0 then
        this:RightBtnOnClick()
    elseif distance > 250 and endV3.x > 0 then
        this:LeftBtnOnClick()
    else
        local tweenEndVer = Vector2.New(heroConFigData.heroConfig.position[1],heroConFigData.heroConfig.position[2])
        this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.5, false):SetEase(Ease.Linear)
    end
    distance = 0
end

--界面关闭时调用（用于子类重写）
function HandBookHeroInfoPanel:OnClose()
    if this.leftLiveObj then
        UnLoadHerolive(leftHeroData.heroConfig,this.leftLiveObj)
        Util.ClearChild(self.leftObj.transform)
        this.leftLiveObj = nil
    end
    if this.rightLiveObj then
        UnLoadHerolive(rightHeroData.heroConfig,this.rightLiveObj)
        Util.ClearChild(self.rightObj.transform)
        this.rightLiveObj = nil
    end
    if this.curLiveObj then
        UnLoadHerolive(heroConFigData.heroConfig,this.curLiveObj)
        Util.ClearChild(self.curObj.transform)
        this.curLiveObj = nil
    end

    this.leftBtn:GetComponent("Button").enabled = true
    this.rightBtn:GetComponent("Button").enabled = true
    liveDeviation = -1
end

function HandBookHeroInfoPanel:SortHeroNatural(heroList)
    table.sort(heroList, function(a, b)
        if a.Star == b.Star then
            if a.Natural == b.Natural then
                return a.Id < b.Id
            else
                return a.Natural > b.Natural
            end
        else
            return a.Star > b.Star
        end
    end)
end
--界面销毁时调用（用于子类重写）
function HandBookHeroInfoPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    this.playerHead = nil
end

return HandBookHeroInfoPanel