require("Base/BasePanel")
SingleRecruitPanel = Inherit(BasePanel)
local this = SingleRecruitPanel
local heroConfigData = ConfigManager.GetConfig(ConfigName.HeroConfig)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local privilegeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local passiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local skillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local passiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local heroRankupConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
local isFirst = true--是否为第一次进入界面
local type--抽卡类型
local state --1单抽 2多抽
local index --十连抽索引
local isJump
local maxTimesId--特权id上限（今日召唤上限）
local _heroData  --一个或者一组
local _heroTable
local curHeroData  --当前的一个英雄
local curHeroStaticData --当前一个英雄的的表数据
local lastHeroStaticData --上一个英雄的的表数据(为卸载Live使用)
local _EffectColors = {}


--初始化组件（用于子类重写）
function SingleRecruitPanel:InitComponent()
    this.bg = Util.GetGameObject(self.gameObject, "bg")
    this.Mask = Util.GetGameObject(self.gameObject, "Mask")
    -- screenAdapte(self.bg)
    this.huode = Util.GetGameObject(this.bg, "choukaUI_huode/huode"):GetComponent("Animator")
    this.ColorChange = Util.GetGameObject(this.bg, "choukaUI_huode/ColorChange"):GetComponent("MeshRenderer")
    this.hero = Util.GetGameObject(this.bg, "choukaUI_huode/hero"):GetComponent("Animator")
    this.effect = Util.GetGameObject(this.bg, "choukaUI_huode/hero/effect")
    this.live2dRoot = Util.GetGameObject(this.bg, "choukaUI_huode/hero/move")
    this.UICanvas = Util.GetGameObject(this.bg, "choukaUI_huode/hero/UI"):GetComponent("Canvas")
    this.heroName = Util.GetGameObject(this.bg, "choukaUI_huode/hero/UI/title/Text"):GetComponent("Text")
    this.tipName = Util.GetGameObject(this.bg, "choukaUI_huode/hero/UI/title/Text/Image/Text"):GetComponent("Text")
    this.bottomTip = Util.GetGameObject(this.bg, "choukaUI_huode/botoom/Text")
    this.sureBtn = Util.GetGameObject(this.bg,"choukaUI_huode/sureBtn")
    this.againBtn = Util.GetGameObject(this.bg,"choukaUI_huode/againBtn")
    this.againIcon = Util.GetGameObject(this.againBtn,"Tip/juan")
    this.againNum = Util.GetGameObject(this.againBtn,"Tip/Text")
    this.infoskillGroup = Util.GetGameObject(this.bg,"choukaUI_huode/hero/UI/title/skillGroup")
    this.infoskillPre = Util.GetGameObject(this.bg,"choukaUI_huode/hero/UI/title/skillPre")
    this.starGrid = Util.GetGameObject(this.bg,"choukaUI_huode/hero/UI/title/star")
    this.proImage = Util.GetGameObject(this.bg,"choukaUI_huode/hero/UI/title/proImage"):GetComponent("Image")
    
    this._material = poolManager:LoadAsset("cn2-X1_UIChouKa_mat_032", PoolManager.AssetType.Other) 
    for i = 1, this.effect.transform.childCount do
        table.insert(_EffectColors,this.effect.transform:GetChild(i-1).gameObject)
    end

    this.jumpBtn = Util.GetGameObject(self.gameObject,"bg/choukaUI_huode/hero/UI/top/jumpBtn")
    this.core = Util.GetGameObject(self.gameObject,"bg/choukaUI_huode/hero/UI/top/core")
end

--绑定事件（用于子类重写）
function SingleRecruitPanel:BindEvent()
    Util.AddClick(this.sureBtn, function()
        this.CloseGetHero()
    end)

    Util.AddClick(this.againBtn, function()
        if state == 2 then
        else
            local d = RecruitManager.GetExpendData(type)
            
            if BagManager.GetItemCountById(d[1]) < d[2] then
                PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[d[1]].Name)..GetLanguageStrById(10492))
                return
            end
            if PrivilegeManager.GetPrivilegeUsedTimes(maxTimesId)+1 > privilegeConfig[maxTimesId].Condition[1][2] then
                PopupTipPanel.ShowTipByLanguageId(11760)
                return
            end
            RecruitManager.RecruitRequest(type,function(msg)
                PrivilegeManager.RefreshPrivilegeUsedTimes(maxTimesId,1)--记录抽卡次数
                for i = 1, #msg.drop.Hero do
                    curHeroData = msg.drop.Hero[i]
                    this.ShowGetHero()
                end       
                
                local d = RecruitManager.GetExpendData(type)

                this.againIcon:GetComponent("Image").sprite = Util.LoadSprite(artResourcesConfig[itemConfig[d[1]].ResourceID].Name)
                this.againNum:GetComponent("Text").text = "x"..d[2]

            end,maxTimesId)
        end
    end)
    Util.AddClick(this.bg, function()
        if state == 2 then
            if index > #_heroTable then
                this.CloseGetHero()
                UIManager.OpenPanel(UIName.TenRecruitPanel,_heroTable,type,isJump)
            else
                curHeroData = _heroTable[index]
                this.ShowGetHero()
            end
        else
            --直接关闭
            this.CloseGetHero()
        end
    end)

    Util.AddClick(this.jumpBtn, function ()
        this.CloseGetHero()
        UIManager.OpenPanel(UIName.TenRecruitPanel, _heroTable, type, isJump)
    end)
end

--添加事件监听（用于子类重写）
function SingleRecruitPanel:AddListener()
end

--移除事件监听（用于子类重写）
function SingleRecruitPanel:RemoveListener()
end

function SingleRecruitPanel:OnSortingOrderChange()
    --Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    this.UICanvas.sortingOrder = self.sortingOrder + 5
    this.jumpBtn:GetComponent("Canvas").sortingOrder = self.sortingOrder + 10
end

--界面打开时调用（用于子类重写）
function SingleRecruitPanel:OnOpen(...)
    -- SoundManager.PlaySound(SoundConfig.Sound_Recruit1)    
    _heroTable = {}
    local data = {...}
    type = data[2]
    state = data[3]
    isJump = data[4]
    if state == 2 then
        -- for k, v in ipairs(data[1]) do
        --     if heroConfigData[v.heroId].Star == 4 or heroConfigData[v.heroId].Star == 5 then
        --         table.insert(_heroTable,v)
        --     end
        -- end
        _heroTable = data[1] or {}
        curHeroData = _heroTable[1]
    else
        _heroData = data[1]
        curHeroData = _heroData
    end
    this.jumpBtn:SetActive(state == 2)

    local d = RecruitManager.GetExpendData(type)
    this.againIcon:GetComponent("Image").sprite = Util.LoadSprite(artResourcesConfig[itemConfig[d[1]].ResourceID].Name)
    this.againNum:GetComponent("Text").text = "x"..d[2]
end

function SingleRecruitPanel:OnShow()
    maxTimesId = lotterySetting[type].MaxTimes --特权上限ID
    index = 1
    isFirst = true
    this.ShowGetHero()
end

--获得英雄
function this.ShowGetHero()
    this.Mask:SetActive(true)
    curHeroStaticData = heroConfigData[curHeroData.heroId]        
    local tempTime = 0
    if not isFirst then
        this.hero:SetBool("play",true)
        tempTime = 0.3
    else
        this.ColorChange.material.color = GetColorByHeroQua(1)
        isFirst = false
    end

    Timer.New(function()           
        Timer.New(function()
            if not curHeroStaticData then
                return
            end

            this.hero.gameObject:SetActive(false)
            this.hero.gameObject:SetActive(true)
            this.core:SetActive(curHeroStaticData.HeroValue == 1)
            this.hero:SetBool("play",false)

            for i = 1,#_EffectColors do 
                _EffectColors[i]:SetActive(i == curHeroStaticData.Quality)
            end
            
            this.ColorChange.material:DOColor(GetColorByHeroQua(curHeroStaticData.Quality),0.4)
    
            if curHeroStaticData.Quality < 4 then
                SoundManager.PlaySound(SoundConfig.Sound_Recruit_GetHero_1)    
            elseif curHeroStaticData.Quality > 4 then
                SoundManager.PlaySound(SoundConfig.Sound_Recruit_GetHero_3)    
            else
                SoundManager.PlaySound(SoundConfig.Sound_Recruit_GetHero_2)    
            end

            if this.liveObj then
                UnLoadHerolive(lastHeroStaticData,this.liveObj)   
                Util.ClearChild(this.live2dRoot.transform)
            end
            lastHeroStaticData = curHeroStaticData
            if curHeroStaticData.HeroSound then
                SoundManager.PlaySound(curHeroStaticData.HeroSound)
            end
            this.liveObj = LoadHerolive(curHeroStaticData,this.live2dRoot.transform)                
            if curHeroStaticData.RoleImage ~= 0 and this.liveObj:GetComponent("SkeletonGraphic") then
                this.liveObj:GetComponent("SkeletonGraphic").material = this._material
                this.liveObj:GetComponent("SkeletonGraphic").color = GetColorByHeroEnterQua(curHeroStaticData.Quality) 
                this.liveObj:GetComponent("SkeletonGraphic"):DOFade(1,1.5)
            else
                this.liveObj:GetComponent("Image").material = this._material
                this.liveObj:GetComponent("Image").color = GetColorByHeroEnterQua(curHeroStaticData.Quality) 
                this.liveObj:GetComponent("Image"):DOFade(1,1.5)
            end

            if state == 2 then
                this.sureBtn:SetActive(false)
                this.againBtn:SetActive(false)
                this.bottomTip:SetActive(true)
            else
                this.sureBtn:SetActive(true)
                this.againBtn:SetActive(true)
                this.bottomTip:SetActive(false)
            end    

            this.heroName.text = GetLanguageStrById(curHeroStaticData.ReadingName)
            this.tipName.text = GetLanguageStrById(curHeroStaticData.HeroLocationDesc1)

            Util.ClearChild(this.infoskillGroup.transform)
            -- local skilList = {}
            if curHeroStaticData.OpenSkillRules then
                local skillCount1 = #curHeroStaticData.OpenSkillRules
                for i = 1, skillCount1 do
                    if curHeroStaticData.OpenSkillRules[i][1] ~= 0 then
                        local gameObject = newObject(this.infoskillPre)
                        gameObject.gameObject:SetActive(true)
                        gameObject.transform:SetParent(this.infoskillGroup.transform)
                        gameObject.transform.localScale = Vector3.one
                        local skillGonfigData = ConfigManager.GetConfigDataByDoubleKey("SkillLogicConfig","Group",curHeroStaticData.OpenSkillRules[i][2],"Level",1)
                        --local lv = skillLogicConfig[curHeroStaticData.OpenSkillRules[i][2]].Level
                        local resid = skillConfig[tonumber(skillGonfigData.Id)].Icon
                        Util.GetGameObject(gameObject, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(resid))
                        -- skilList[i]=gameObject
                    end
                end
            end
            
            if curHeroStaticData.OpenPassiveSkillRules then
                local skillCount2 = #curHeroStaticData.OpenPassiveSkillRules
                for i = 1, skillCount2 do
                    local gameObject = newObject(this.infoskillPre)
                    gameObject.gameObject:SetActive(true)
                    gameObject.transform:SetParent(this.infoskillGroup.transform)
                    gameObject.transform.localScale = Vector3.one
                    local skillGonfigData = ConfigManager.GetConfigDataByDoubleKey("PassiveSkillLogicConfig","Group",curHeroStaticData.OpenPassiveSkillRules[i][2],"Level",1)
                    local resid = passiveSkillConfig[tonumber(skillGonfigData.Id)].Icon
                    Util.GetGameObject(gameObject, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(resid))
                    -- skilList[i] = gameObject
                end
            end
            SetHeroStars(this.starGrid, curHeroData.star)
            this.proImage.sprite = Util.LoadSprite(GetProStrImageByProNum(curHeroStaticData.PropertyName))
        end,0.5):Start()
    
        Timer.New(function()
            index = index + 1
            this.Mask:SetActive(false)
        end,2):Start()
    end,tempTime):Start()
end

function this.CloseGetHero(backAction)
    this.huode:SetTrigger("out")
    this.hero.gameObject:SetActive(false)
    this.core:SetActive(false)
    -- Timer.New(function()
        -- isFirst = true
        this:ClosePanel()
        if backAction then
            backAction()
        end
    -- end,1.5):Start()
end

function SingleRecruitPanel:OnClose()
    -- this._material = nil
    -- PoolManager:UnLoadAsset("cn2-X1_UIChouKa_mat_032")

    isJump = false
    
    _heroData = nil
    -- _heroTable = {}
    index = 1
    if lastHeroStaticData then
        UnLoadHerolive(lastHeroStaticData,this.liveObj)
        lastHeroStaticData = nil
    end
    Util.ClearChild(this.live2dRoot.transform)
    this.liveObj = nil
    curHeroData = nil
    curHeroStaticData = nil
end

function SingleRecruitPanel:OnDestroy()
    this._material = nil
    _EffectColors = {}
end

return SingleRecruitPanel