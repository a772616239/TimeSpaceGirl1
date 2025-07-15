require("Base/BasePanel")
local ShowEnemyInfoPanel = Inherit(BasePanel)
local this = ShowEnemyInfoPanel
local monsterGroupId
local _LiveNode
local MapPanel

local trailConfig = ConfigManager.GetConfig(ConfigName.TrialConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local trialSetting = ConfigManager.GetConfig(ConfigName.TrialSetting)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local MonsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local MonsterGroupConfig = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

local herosList = {}
local isBattle

function this:InitComponent()
    this.root = self.gameObject
    this.btnBack = Util.GetGameObject(this.root,"EnemyInfo/btnBack")
    this.e_liveRoot = Util.GetGameObject(this.root,"EnemyInfo/liveRoot")
    this.e_heroIcon = Util.GetGameObject(this.root,"EnemyInfo/liveRoot/heroIcon")
    this.e_name = Util.GetGameObject(this.root,"EnemyInfo/name/text"):GetComponent("Text")
    this.e_level = Util.GetGameObject(this.root,"EnemyInfo/name/level"):GetComponent("Text")
    this.e_cancelBtn = Util.GetGameObject(this.root,"EnemyInfo/cancelBtn")
    this.e_fightBtn = Util.GetGameObject(this.root,"EnemyInfo/fightBtn")
    this.bottomBar = Util.GetGameObject(this.root,"EnemyInfo/bottomBar")
    this.heroGrid = Util.GetGameObject(this.root,"EnemyInfo/bottomBar/heroList")
    this.iconPre = Util.GetGameObject(this.root,"EnemyInfo/bottomBar/heroList/pre")
end

function this:BindEvent()
    Util.AddClick(this.e_cancelBtn,function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.MaskState,0)
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack,function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.MaskState,0)
        self:ClosePanel()
    end)

    Util.AddClick(this.e_fightBtn,this.fightbtnOnClick)
end
function this.fightbtnOnClick()
    if this.isAllDead then
        PopupTipPanel.ShowTipByLanguageId(11247)
        return
    end

    for i, v in ipairs(MapManager.trialHeroInfo) do
        if MapTrialManager.selectHeroDid == v.heroId or  MapTrialManager.selectHeroDid == "" then
            if v.heroHp <= 0 then
                PopupTipPanel.ShowTipByLanguageId(11247)
                return
            end
        end
    end
    if isBattle or BattleManager.IsInBackBattle() then
        PopupTipPanel.ShowTipByLanguageId(50014)
        return
    end
    isBattle = true
    if MapManager.curCarbonType == CarBonTypeId.ENDLESS then
        local curFormation = MapManager.formationList
        -- fightInfo   此处类型用的原有日常副本类型 后续todo
        BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.DAILY_CHALLENGE, monsterGroupId)
        NetManager.QuickFightRequest(function(msg)
            -- CarbonManager.InitQuickFightData(monsterGroupId, nil, msg)
            UIManager.OpenPanel(UIName.BattleStartPopup, function ()
                local fightData = BattleManager.GetBattleServerData(msg)
                UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.DAILY_CHALLENGE, function()
                    --更新精气值
                    MapTrialManager.powerValue = msg.essenceValue
                    --召唤Boss
                    if CarbonManager.difficulty == CARBON_TYPE.TRIAL and MapTrialManager.powerValue >= 100 then
                        MapTrialManager.isHaveBoss = true
                        MapTrialManager.UpdatePowerValue(0)
                    end
                    -- 延迟一秒刷新显示，避免战斗界面关闭时地图界面没有打开，无法监听删点事件，导致怪物点无法删除的问题
                    Timer.New(function()
                        -- 刷新数据
                        CarbonManager.InitQuickFightData(monsterGroupId, nil, msg)
                    end, 0.2):Start()
                end)
                this:ClosePanel()
            end)
        end)
    else
        --先保存编队
        local curFormation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_DREAMLAND)
        local choosedList = {}
        table.insert(choosedList, {heroId = MapTrialManager.selectHeroDid, position = 2})
        -- FormationManager.RefreshFormation(FormationTypeDef.FORMATION_DREAMLAND,choosedList,
        -- FormationManager.formationList[FormationTypeDef.FORMATION_DREAMLAND].teamPokemonInfos)

        -- 暂时不能上支援和副官 编队为1 后期todo
        FormationManager.RefreshFormation(FormationTypeDef.FORMATION_DREAMLAND, choosedList,"",
        {supportId = 0,
        adjutantId = 0},
        nil,
        1)

        -- fightInfo   此处类型用的原有日常副本类型 后续todo
        BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.DAILY_CHALLENGE, monsterGroupId)

        --请求战斗数据
        NetManager.QuickFightRequest(function(msg)
            --战斗赢了 击杀小怪数量+1（包括BOSS吗）
            if msg.result == 1 then
                MapTrialManager.SetKillCount(MapTrialManager.GetKilCount() + 1)
            elseif msg.result == 0 then
                MapTrialManager.SetHeroHp({0}, MapTrialManager.selectHeroDid)
            end
            --更新英雄HP  -- 服务器返回数据类型错误
            NetManager.MapInfoRequest(MapManager.curCarbonType, function(msg)
                MapManager.curAreaId = FormationTypeDef.FORMATION_DREAMLAND
                MapManager.trialHeroInfo = msg.infos
                local d = {}
                d = MapManager.trialHeroInfo
                for i, v in ipairs(d) do
                local o = herosList[i]
                local hpExp = Util.GetGameObject(o,"hpExp"):GetComponent("Slider")
                 --血量相关
                hpExp.value = v.heroHp/10000
                Util.SetGray(o,v.heroHp <= 0)--死啦
                this.SetSelectHero()
                Game.GlobalEvent:DispatchEvent(GameEvent.Map.RefreshHeroHp,false,nil,false)
                end
            end)

               if MapManager.curCarbonType == CarBonTypeId.TRIAL and MapManager.isJump then  --异端之战跳过战斗
                    local fightData = BattleManager.GetBattleServerData(msg)
                    --更新精气值
                    MapTrialManager.powerValue = msg.essenceValue

                    --召唤Boss
                    if CarbonManager.difficulty == CARBON_TYPE.TRIAL and MapTrialManager.powerValue >= 100 then
                        MapTrialManager.isHaveBoss = true
                        MapTrialManager.UpdatePowerValue(0)
                    end
                    -- 延迟一秒刷新显示，避免战斗界面关闭时地图界面没有打开，无法监听删点事件，导致怪物点无法删除的问题
                    Timer.New(function()
                        -- 刷新数据
                        CarbonManager.InitQuickFightData(monsterGroupId, nil, msg)
                    end, 0.2):Start()
            
                    this:ClosePanel()

                    NetManager.MapInfoRequest(MapManager.curCarbonType, function(msg)
                        MapManager.curAreaId = FormationTypeDef.FORMATION_DREAMLAND
                        MapManager.trialHeroInfo = msg.infos
                        local d = {}
                        d = MapManager.trialHeroInfo
                        for i, v in ipairs(d) do
                        local o = herosList[i]
                        local hpExp = Util.GetGameObject(o,"hpExp"):GetComponent("Slider")
                        --血量相关
                        hpExp.value = v.heroHp/10000
                        Util.SetGray(o,v.heroHp <= 0)--死啦
                        this.SetSelectHero()      
                        Game.GlobalEvent:DispatchEvent(GameEvent.Map.RefreshHeroHp,false,nil,false)              
                        end                       
                    end)
                
               else
                --正常战斗
                    UIManager.OpenPanel(UIName.BattleStartPopup, function ()
                        local fightData = BattleManager.GetBattleServerData(msg)
                        UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.DAILY_CHALLENGE, function()
                            --更新精气值
                            MapTrialManager.powerValue = msg.essenceValue
        
                            --召唤Boss
                            if CarbonManager.difficulty == CARBON_TYPE.TRIAL and MapTrialManager.powerValue >= 100 then
                                MapTrialManager.isHaveBoss = true
                                MapTrialManager.UpdatePowerValue(0)
                            end
                            -- 延迟一秒刷新显示，避免战斗界面关闭时地图界面没有打开，无法监听删点事件，导致怪物点无法删除的问题
                            Timer.New(function()
                                -- 刷新数据
                                CarbonManager.InitQuickFightData(monsterGroupId, nil, msg)
                            end, 0.2):Start()
        
                        end)
                        this:ClosePanel()
        
                        NetManager.MapInfoRequest(MapManager.curCarbonType, function(msg)
                            MapManager.curAreaId = FormationTypeDef.FORMATION_DREAMLAND
                            MapManager.trialHeroInfo = msg.infos
                            local d = {}
                            d = MapManager.trialHeroInfo
                            for i, v in ipairs(d) do
                            local o = herosList[i]
                            local hpExp = Util.GetGameObject(o,"hpExp"):GetComponent("Slider")
                            --血量相关
                            hpExp.value = v.heroHp/10000
                            Util.SetGray(o,v.heroHp <= 0)--死啦
                            this.SetSelectHero()      
                            Game.GlobalEvent:DispatchEvent(GameEvent.Map.RefreshHeroHp,false,nil,false)              
                            end                       
                        end)
                                        
                    end)
               end
           
        end)
    end
end
function this:OnOpen(...)
    MapPanel,monsterGroupId = ...
end

function this:OnShow()
    if  MapManager.curCarbonType == CarBonTypeId.TRIAL then
        if MapManager.isJump then
            local v =   Vector2.New(2000, 0)
            self.gameObject.transform.localPosition = v
            isBattle = false
            this.bottomBar:SetActive(MapManager.curCarbonType ~= CarBonTypeId.ENDLESS)
            this.SetSelectHero()
            this.fightbtnOnClick()
        else
            self.gameObject.transform.localPosition = Vector3.zero
            isBattle = false
            this.bottomBar:SetActive(MapManager.curCarbonType ~= CarBonTypeId.ENDLESS)
            this.SetSelectHero()
        end
    else
        self.gameObject.transform.localPosition = Vector3.zero
        isBattle = false
        this.bottomBar:SetActive(MapManager.curCarbonType ~= CarBonTypeId.ENDLESS)
        this.SetSelectHero()
    end
end

function this.SetSelectHero()
    local itemId = trialSetting[1].HealingId[1]
    local itemNum = trialSetting[1].HealingId[2]

    local t = MonsterGroupConfig[monsterGroupId].Contents[1][1]
    monsterId = MonsterConfig[t].MonsterId

    if this.hero then
        UnLoadHerolive(this.hero, this.liveObj)
        Util.ClearChild(this.e_heroIcon.transform)
        this.hero = nil
    end
    this.hero = ConfigManager.GetConfigData(ConfigName.HeroConfig,monsterId)

    this.liveObj = LoadHerolive(this.hero,this.e_heroIcon.transform)

    this.e_level.text = "lv."..MonsterConfig[t].Level
    this.e_name.text = GetLanguageStrById(MonsterConfig[t].ReadingName)

    local d = {}
    d = MapManager.trialHeroInfo
    for k = 1, this.heroGrid.transform.childCount do
        this.heroGrid.transform:GetChild(k-1).gameObject:SetActive(false)
    end
    local closeChoosed=function() --有开着选择的全关了
        for i, v in ipairs(herosList) do
            -- local c = Util.GetGameObject(v,"choosed").gameObject
            local bg=Util.GetGameObject(v,"select").gameObject
            if bg.activeSelf then
                -- c:SetActive(false)
                bg:SetActive(false)
            end
        end
    end

    this.isAllDead = true
    for index, value in ipairs(d) do
        local item = herosList[index]
        if  not item then
            item = newObjToParent(this.iconPre,this.heroGrid)
            item.name = "pre"..index
            herosList[index] = item
        end
        item.gameObject:SetActive(true)

        local frame = Util.GetGameObject(item,"frame"):GetComponent("Image")
        local icon = Util.GetGameObject(item,"icon"):GetComponent("Image")
        local pro = Util.GetGameObject(item,"proIcon"):GetComponent("Image")
        local lv = Util.GetGameObject(item,"lv/Text"):GetComponent("Text")
        local star = Util.GetGameObject(item,"star")
        local proBg = Util.GetGameObject(item,"proBg"):GetComponent("Image")
        local lvBg = Util.GetGameObject(item,"lv"):GetComponent("Image")

        local select = Util.GetGameObject(item,"select")
        local hpExp = Util.GetGameObject(item,"hpExp"):GetComponent("Slider")
        frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig[value.tmpId].Quality,value.star))
        icon.sprite = Util.LoadSprite(GetResourcePath(heroConfig[value.tmpId].Icon))
        pro.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig[value.tmpId].PropertyName))
        lv.text = value.level
        proBg.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfig[value.tmpId].Quality, value.star))
        lvBg.sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroConfig[value.tmpId].Quality, value.star))
        SetHeroStars(star, value.star)

        --选择
        select:SetActive(MapTrialManager.selectHeroDid==value.heroId)

        Util.AddOnceClick(item,function()
            if value.heroHp > 0 then
                closeChoosed()
                select:SetActive(true)
                MapTrialManager.selectHeroDid = value.heroId
                Game.GlobalEvent:DispatchEvent(GameEvent.Map.RefreshHeroHp,false,nil,false)
            else
                PopupTipPanel.ShowTipByLanguageId(11247)
            end
        end)

        --血量相关
        hpExp.value = value.heroHp/10000
        Util.SetGray(item,value.heroHp <= 0)--死啦
        if value.heroHp > 0 then
            this.isAllDead = false
        end
    end

    --刷新英雄选择面板时 检测血量 若有低于40%血量的英雄 给选择Hero加血
    --再遍历一次防止下面的return 打断上面for循环表现的正常赋值
    --这里只关于自动嗑药逻辑
    -- for k, v in ipairs(d) do
    --     --若存在该设置参数并为已勾选状态 =1 否则=0
    --     local t = (PlayerPrefs.HasKey(PlayerManager.uid .. "GeneralPopup_TrialSettingBtn" .. 2)
    --         and PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..2) == 1) and 1 or 0
    --     if t == 0 then return end
    --     if MapTrialManager.selectHeroDid == v.heroId then
    --         if v.heroHp <= 0 then
    --             PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11262),itemConfig[itemId].Name))
    --             return
    --         end
    --     end
    --     --若血量小于自动回复百分比 并且 有血量
    --     if v.heroHp/10000<trialSetting[1].HealingPercent/10000 and v.heroHp > 0 then
    --         if (itemNum - MapManager.addHpCount) <= 0 then
    --             PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11263),itemConfig[itemId].Name))
    --             return
    --         end
    --         if BagManager.GetItemCountById(itemId) <= 0 then
    --             PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11264),itemConfig[itemId].Name,itemConfig[itemId].Name))
    --             return
    --         end
    --         NetManager.UseAddHpItemRequest(MapTrialManager.selectHeroDid,function()
    --             local curHeroHp = 0
    --             if v.heroId == MapTrialManager.selectHeroDid then
    --                 curHeroHp = v.heroHp
    --             end
    --             curHeroHp = curHeroHp+5000  --5000增加的血量也是要配表的
    --             if curHeroHp >= 10000 then
    --                 curHeroHp = 10000
    --             end
    --             MapTrialManager.SetHeroHp({curHeroHp},MapTrialManager.selectHeroDid,function()
    --                 PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11265),itemConfig[itemId].Name))
    --             end)
    --         end)
    --     end
    -- end
end

function this:OnClose()
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
    if this.hero then
        UnLoadHerolive(this.hero, this.liveObj)
        Util.ClearChild(this.e_heroIcon.transform)
        this.hero = nil
    end
end

function this:OnDestroy()
    _LiveNode = {}
    herosList = {}

    if this.hero then
        UnLoadHerolive(this.hero, this.liveObj)
        Util.ClearChild(this.e_heroIcon.transform)
        this.hero = nil
    end
end

return this