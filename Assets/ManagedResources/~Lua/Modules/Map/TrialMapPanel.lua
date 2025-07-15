TrialMapPanel = {}
local this = TrialMapPanel
local istrialMap = false
local MapPanel
local powerValue = 0
-- local ctrlView = require("Modules/Map/View/MapControllView")
local targetPos = Vector2.New(109, 289)
local orginLayer = 0
local heroList = {} --选择英雄预设容器
local trailConfig = ConfigManager.GetConfig(ConfigName.TrialConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local trialSetting = ConfigManager.GetConfig(ConfigName.TrialSetting)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local MonsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local MonsterGroupConfig = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local ArtConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local EventPointConfig = ConfigManager.GetConfig(ConfigName.EventPointConfig)
local oldChoosed = nil--上一个选中英雄
local monsterGroupId
local baoXiangId = 2000000
local buffName = 21

--> uv v对应tank相关图片   位置写死 如果怪位置不在这几处会出问题
local v_pic = {[1] = {"cn2-X1_shikongzhanchang_BOSS", "BOSS"},
               [3] = {"cn2-X1_shikongzhanchang_difangdengji", "No.4"},
               [5] = {"cn2-X1_shikongzhanchang_difangdengji", "No.3"},
               [7] = {"cn2-X1_shikongzhanchang_difangdengji", "No.2"},
               [9] = {"cn2-X1_shikongzhanchang_difangdengji", "No.1"},}

function TrialMapPanel:InitComponent(root, mapPanel)
    orginLayer = 0
    MapPanel = mapPanel
    -- 剩余复活次数
    this.leftLife = Util.GetGameObject(root, "leftDown/leftLifeRoot/leftTimes"):GetComponent("Text")
    this.leftLifeRoot = Util.GetGameObject(root, "leftDown/leftLifeRoot")
    -- 精气
    this.powerRoot = Util.GetGameObject(root, "leftDown/active")
    this.activeRedPoint = Util.GetGameObject(root, "leftDown/active/redPoint")
    this.levelNum = Util.GetGameObject(root, "leftUp/curLevel"):GetComponent("Text")
    this.powerPercent = Util.GetGameObject(root, "leftDown/active/value"):GetComponent("Text")
    this.powerPercentTotal = Util.GetGameObject(root, "leftDown/active/total"):GetComponent("Text")
    this.box = Util.GetGameObject(root, "leftDown/active/Image")
    this.sliderValue = Util.GetGameObject(root, "leftDown/active/progress"):GetComponent("Image")
    -- 显示时间
    this.timeRoot = Util.GetGameObject(root,"centerDown/timeRoot")
    this.mapTime = Util.GetGameObject(this.timeRoot, "Time"):GetComponent("Text")
    this.DragCtrl = Util.GetGameObject(root, "Ctrl")

    -- 初始化任务显示
    -- this.targetRoot = Util.GetGameObject(root, "TargetRoot/textShowRoot/missionRoot/MisPre1")
    -- this.targetText = Util.GetGameObject(this.targetRoot, "context"):GetComponent("Text")

    -- 炸弹
    this.btnBomb = Util.GetGameObject(root, "rightDown/btnBomb")
    this.bombNum = Util.GetGameObject(this.btnBomb, "num"):GetComponent("Text")

    this.buffShop = Util.GetGameObject(root, "rightDown/buff")
    this.buffNum = Util.GetGameObject(this.buffShop, "num"):GetComponent("Text")

    -- 试炼副本商店
    this.normalShop = Util.GetGameObject(root, "rightDown/shop")
    this.shopNum = Util.GetGameObject(this.normalShop, "num"):GetComponent("Text")


    --回春散
    this.btnXingYao = Util.GetGameObject(root,"rightDown/btnXingYao")
    this.xingYaoNum = Util.GetGameObject(this.btnXingYao,"num"):GetComponent("Text")

    this.effectRoot = Util.GetGameObject(root, "fireRoot")
    this.fire = Util.GetGameObject(this.effectRoot, "UI_effect_shilian_huo")
    this.guiji = Util.GetGameObject(this.effectRoot, "UI_effect_shilian_guiji")
    this.chufa = Util.GetGameObject(this.powerRoot, "UI_effect_shilian_chufa")

    -- 月卡福利炸弹提示
    this.bombTip = Util.GetGameObject(this.btnBomb, "bombTip")

    --选择英雄
    this.selectHero = Util.GetGameObject(root,"centerDown/selectHero")

    this.s_grid = Util.GetGameObject(this.selectHero,"grid")
    this.s_pre = Util.GetGameObject(this.s_grid,"pre")
    this.tankPre = Util.GetGameObject(root, "tankPre")

    -- this.upView = SubUIManager.Open(SubUIConfig.UpView, root.transform)
    -- this.BtView = SubUIManager.Open(SubUIConfig.BtView, root.transform)

    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, root.transform)
    this.PlayerHeadFrameView:OnShow(true)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, root.transform, { showType = UpViewOpenType.ShowRight})

    this.helpBtn = Util.GetGameObject(root,"helpBtn")
    this.helpPos = this.helpBtn:GetComponent("RectTransform").localPosition
    --boss召唤特效
    -- this.bossEffect = Util.GetGameObject(root, "UI_effect_shilian_tab")
    this.energyRoot = Util.GetGameObject(root, "stepROot")
    --武将遮挡区块
    this.Mask1 = Util.GetGameObject(root, "Scroll/main/Mask1")
    this.Mask2 = Util.GetGameObject(root, "Scroll/main/Mask2")
    this.Mask3 = Util.GetGameObject(root, "Scroll/main/Mask3")
    this.Mask4 = Util.GetGameObject(root, "Scroll/main/Mask4")
    this.rewardRedPoint = Util.GetGameObject(root,"leftCenter/btnReward/redPoint")
    BindRedPointObject(RedPointType.TrialReward, this.rewardRedPoint)

    this.main = Util.GetGameObject(root, "main").transform
end

function TrialMapPanel:BindEvent()
    --炸弹按钮
    Util.AddClick(this.btnBomb, function ()
        local num = 0
        for i = 1, this.main.childCount do
            local name = this.main:GetChild(i-1).gameObject.name
            if string.sub(name, 0, 9) == "mainPoint" then
                local pre = Util.GetGameObject(this.main, name.."/EventPoint/root/tankPre(Clone)")
                if pre then
                    num = num + 1
                end
            end
        end
        if num <= 0 then
            return
        end
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.TrialBomb)
    end)

    --回春散
    Util.AddClick(this.btnXingYao,function()
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.TrialXingYao)
    end)

    -- 打开补给点
    Util.AddClick(this.buffShop, function()
        -- 判断是否有保存的补给点
        if #FoodBuffManager.GetBuffPropList()<=0 then
            PopupTipPanel.ShowTipByLanguageId(11250)
            return
        end
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.TrialGain,0)
    end)

    -- 打开商店
    Util.AddClick(this.normalShop, function()
        if not ShopManager.IsActive(SHOP_TYPE.TRIAL_SHOP) then
            PopupTipPanel.ShowTipByLanguageId(10381)
            return
        end
        UIManager.OpenPanel(UIName.MapShopPanel, SHOP_TYPE.TRIAL_SHOP)
    end)

    --帮助按钮
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Expedition,this.helpPos.x,this.helpPos.y)
    end)
end

--添加事件监听（用于子类重写）
function TrialMapPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TrialMap.OnPowerValueChanged, this.OnPowerValueChange)
    -- Game.GlobalEvent:AddEvent(GameEvent.Bag.OnTempBagChanged, this.OnTempBagChanged)
    Game.GlobalEvent:AddEvent(GameEvent.FoodBuff.OnFoodBuffStateChanged, this.InitBuffInfo)
    Game.GlobalEvent:AddEvent(GameEvent.Map.ShowEnemyInfo, this.ShowEnemyInfo)
    Game.GlobalEvent:AddEvent(GameEvent.Map.PointUiClear, this.DisPoint)
    Game.GlobalEvent:AddEvent(GameEvent.Map.RefreshHeroHp, this.SetSelectHero)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.InitShopInfo)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.OnTempBagChanged, this.InitRightDown)
    Game.GlobalEvent:AddEvent(GameEvent.TrialMap.BtViewOut, this.BtViewOut)
    Game.GlobalEvent:AddEvent(GameEvent.TrialMap.UpdateBox, this.UpdateBox)
    Game.GlobalEvent:AddEvent(GameEvent.YiDuan.AutoGetBaoXiang,this.AutoGetReward)
end

--移除事件监听（用于子类重写）
function TrialMapPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TrialMap.OnPowerValueChanged, this.OnPowerValueChange)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Bag.OnTempBagChanged, this.OnTempBagChanged)
    Game.GlobalEvent:RemoveEvent(GameEvent.FoodBuff.OnFoodBuffStateChanged, this.InitBuffInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.ShowEnemyInfo, this.ShowEnemyInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.PointUiClear, this.DisPoint)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.RefreshHeroHp, this.SetSelectHero)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.InitShopInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.OnTempBagChanged, this.InitRightDown)
    Game.GlobalEvent:RemoveEvent(GameEvent.TrialMap.BtViewOut, this.BtViewOut)
    Game.GlobalEvent:RemoveEvent(GameEvent.TrialMap.UpdateBox, this.UpdateBox)
    Game.GlobalEvent:RemoveEvent(GameEvent.YiDuan.AutoGetBaoXiang,this.AutoGetReward)
end
local isFirst = true
--界面打开时调用（用于子类重写）
function TrialMapPanel:OnOpen()
    --this.upView.gameObject:SetActive(CarbonManager.difficulty == 2)
    this.powerRoot:SetActive(CarbonManager.difficulty == 2)
    this.btnBomb:SetActive(CarbonManager.difficulty == 2)
    -- 商店
    this.btnXingYao:SetActive(MapManager.curCarbonType==CarBonTypeId.TRIAL)
    -- MapPanel.Bg:SetActive(MapManager.curCarbonType==CarBonTypeId.TRIAL)
    MapPanel.main:SetActive(MapManager.curCarbonType == CarBonTypeId.TRIAL)
    this.buffShop:SetActive(CarbonManager.difficulty == CARBON_TYPE.TRIAL)
    this.normalShop:SetActive(CarbonManager.difficulty == CARBON_TYPE.TRIAL)
    this.energyRoot:SetActive(CarbonManager.difficulty == CARBON_TYPE.ENDLESS)
    --this.BtView.gameObject:SetActive(CarbonManager.difficulty == CARBON_TYPE.TRIAL)
    if CarbonManager.difficulty ~= 2 then return end

    this.InitShowState()

    -- 检测引导
    GuideManager.CheckCarbonGuild(CARBON_TYPE.TRIAL)
    -- PlayerPrefs.SetInt(PlayerManager.uid.."TrialIsOpen",1)
end

function TrialMapPanel:OnShow()
    if not PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.MapJump) then
        MapPanel.btnJump.gameObject:SetActive(false)
        MapPanel.btnAutoJian.gameObject:SetActive(false)
    else
        MapPanel.btnJump.gameObject:SetActive(true)
        MapPanel.btnAutoJian.gameObject:SetActive(true)
    end
end

function this.BtViewOut()
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.ClearCtrl,0)
end

function this.InitShowState()
    if CarbonManager.difficulty ~= 2 then return end
    istrialMap = CarbonManager.difficulty == 2
    if istrialMap then this.InitTrial() end

    this.helpBtn:SetActive(istrialMap)
    MapPanel.btnBag.gameObject:SetActive(false)
    MapPanel.btnTeam.gameObject:SetActive(false)
    -- MapPanel.btnSetting.gameObject:SetActive(true)
    MapPanel.btnRank.gameObject:SetActive(true)
    MapPanel.btnXingYao.gameObject:SetActive(MapManager.curCarbonType == CarBonTypeId.TRIAL)
    MapPanel.btnReward.gameObject:SetActive(true)
    -- MapPanel.warnRoot:SetActive(false)
    -- MapPanel.warn:SetActive(false)
    this.CheckTrialHeroInfo()
    this.InitTrialMission()
    this.UpdatePowerValue()
    -- this.UpdateDeadTimes()
    this.InitRightDown()
    -- this.InitBossInfo()
    this.powerRoot:SetActive(istrialMap)
    this.InitEffect()
    this.InitTip()
    this.TrialShowTime()
    MyPCall(function ()
        this.DisPoint()
    end)
end
local MapPointConfig = ConfigManager.GetConfig(ConfigName.MapPointConfig)
local buttonlis = {}

--开始给ui加入按键
function this.AddImagePre()
    for u = 1, MapManager.TrialMaxU do
        for v = 1, MapManager.TrialMaxV do
            if buttonlis[u] == nil then
                buttonlis[u] = {}
            end
            buttonlis[u][v] = nil
        end
    end
    this.Mask1:SetActive(false)
    this.Mask2:SetActive(false)
    this.Mask3:SetActive(false)
    this.Mask4:SetActive(false)

    for cellId, pointId in pairs(MapManager.mapPointList) do
        if pointId ~= 201003 and pointId ~= 0 and pointId ~= nil then
            local u, v = Map_Pos2UV(cellId)
            this.NewImageAdd(MapPanel.mainList[u][v], pointId, u, v)
        end
    end

    local function set(vb, ve, isActive)
        for u = 1, 5 do
            for v = vb, ve do
                local uv_p = Map_UV2Pos(u, v)
                if MapManager.mapPointList[uv_p] and buttonlis[u][v] then
                    MapManager.mapPointId = MapManager.mapPointList[uv_p]
                    local DataName =    MapPointConfig[MapManager.mapPointId]   
                    local data =
                        {
                            [1] = u,
                            [2] = v,
                            [3] = MapManager.mapPointId,
                            [4] = DataName.Icon,
                        }
                    local isAddTab = true  --用来判断宝箱
                    local isAddBuffTab = true
                    if isActive  then
                        for index, value in ipairs(MapManager.allOnClickEvent) do
                            if value[1] == data[1] and value[2] == data[2] and value[3] == data[3] then
                                isAddTab = false
                            end
                        end
                        for k, v in ipairs(MapManager.buffOnClickEvent) do
                            if v[1] == data[1] and v[2] == data[2] and v[3] == data[3]   then
                                isAddBuffTab = false
                            end
                        end
                    end
                    --添加宝箱表
                    if isAddTab and isActive  then
                        if MapManager.mapPointId == baoXiangId then
                            table.insert(MapManager.allOnClickEvent,data)
                        end
                    end
                    --添加buff
                    if isAddBuffTab and isActive  then
                        if data[4] == buffName then
                            table.insert(MapManager.buffOnClickEvent,data)
                        end
                    end
                    buttonlis[u][v]:SetActive(isActive)
                end
            end
        end
    end
    local pos = Map_UV2Pos(3, 3)
    if MapManager.mapPointList[pos] ~= nil then
        set(2, 4, false)
        this.Mask4:SetActive(true)
        buttonlis[3][3]:SetActive(true)
    else
        set(2, 4, true)
    end

    pos = Map_UV2Pos(3, 5)
    if MapManager.mapPointList[pos] ~= nil then
        set(5, 6, false)
        this.Mask3:SetActive(true)
        buttonlis[3][5]:SetActive(true)
    else
        set(5, 6, true)
    end

    pos = Map_UV2Pos(3, 7)
    if MapManager.mapPointList[pos] ~= nil then
        set(7, 8, false)
        this.Mask2:SetActive(true)
        buttonlis[3][7]:SetActive(true)
    else
        set(7, 8, true)
    end

    pos = Map_UV2Pos(3, 9)
    if MapManager.mapPointList[pos] ~= nil then
        set(9, 11, false)
        this.Mask1:SetActive(true)
        buttonlis[3][9]:SetActive(true)
    else
        set(9, 11, true)
    end

    this.InitShopInfo()
end

--添加怪和怪的按钮，添加图片
function this.NewImageAdd(mainpoint, imageid,u,v)
    local cell = MapPointConfig[imageid]
    local go = poolManager:LoadAsset("EventPoint", PoolManager.AssetType.GameObject)
    go.name = "EventPoint"
    go:SetActive(true)
    local live
    Util.GetGameObject(go, "shadow"):SetActive(true)
    local heroicon = Util.GetGameObject(go, "root/heroIcon")

    if cell.Style == 1 or cell.Style == 2 then
        local t = MonsterGroupConfig[EventPointConfig[imageid].Option[1]].Contents[1][1]         --< 此处取了怪物组 第一个怪
        local monsterId = MonsterConfig[t].MonsterId

        local heroroot = Util.GetGameObject(go, "root")
        local tankPre = newObjToParent(this.tankPre, heroroot)
        local bg = Util.GetGameObject(tankPre, "bg"):GetComponent("Image")
        local icon = Util.GetGameObject(tankPre, "icon"):GetComponent("Image")
        local titlebg = Util.GetGameObject(tankPre, "titlebg"):GetComponent("Image")
        local lv = Util.GetGameObject(tankPre, "titlebg/lv"):GetComponent("Text")

        bg.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig[monsterId].Quality, heroConfig[monsterId].Star))
        icon.sprite = Util.LoadSprite(GetResourcePath(heroConfig[monsterId].Icon))
        titlebg.sprite = Util.LoadSprite(v_pic[v][1])
        lv.text = v_pic[v][2]
        -- Log("imageid      "..imageid)
        -- Log("v  " ..v)
        -- Log("v_pic[v][2]             "..v_pic[v][2])
        -- Log("_________________________")
        local addBossID = true
        if v_pic[v][2] == "BOSS" then
            for index, value in ipairs(MapManager.BossId) do
                if value == imageid then
                    addBossID = false
                end
            end
            if addBossID then
                table.insert(MapManager.BossId,imageid)
            end
        end
        heroicon:SetActive(false)
    else
        heroicon:GetComponent("Image").sprite = Util.LoadSprite(MapFloatingConfig[cell.Icon].name)
        heroicon:SetActive(true)
    end

    go.transform:SetParent(MapPanel.mainList[u][v].transform)
    go.transform.localPosition = Vector3.zero
    go.transform.localScale = Vector3.one
    buttonlis[u][v] = go
    this.AddButtonLis(go,u,v,imageid)
end

function this.NewBoxSet(live, iconId, go)
    this.effectLive = poolManager:LoadAsset(MapFloatingConfig[iconId].name, PoolManager.AssetType.GameObject)
    this.effectLive.transform:SetParent(Util.GetTransform(go, "root"))
    if iconId == 8 then
        this.effectLive.transform.localScale = Vector3.one * 0.8
        this.effectLive.transform.localPosition = Vector3.zero

        local initRoot = Util.GetGameObject(this.effectLive, "idle1")
        local openRoot = Util.GetGameObject(this.effectLive, "open")

        -- 设置宝箱的位置大小
        initRoot.transform.localScale = MapFloatingConfig[iconId].scale
        openRoot.transform.localScale = MapFloatingConfig[iconId].scale
        initRoot.transform.localPosition = MapFloatingConfig[iconId].position
        openRoot.transform.localPosition = MapFloatingConfig[iconId].position
        initRoot:SetActive(true)
        openRoot:SetActive(false)
    else
        this.effectLive.transform.localScale = MapFloatingConfig[iconId].scale
        this.effectLive.transform.localPosition = MapFloatingConfig[iconId].position
    end
    
    return this.effectLive
end



--自动拾取宝箱
function this.AutoGetReward()
    for index, value in ipairs(MapManager.allOnClickEvent) do
        if  index  == 1 then
            Timer.New(function()
                local pos = Map_UV2Pos(value[1], value[2])
                MapManager.MapUpdateEvent2(pos,function ()
                end)
            end, 0.3):Start()
        elseif index  == 2 then
            Timer.New(function()
                local pos = Map_UV2Pos(value[1], value[2])
                MapManager.MapUpdateEvent2(pos,function ()
                end)
            end, 1):Start()
        elseif index  == 3 then
            Timer.New(function()
                local pos = Map_UV2Pos(value[1], value[2])
                MapManager.MapUpdateEvent2(pos,function ()
                end)
            end, 1.6):Start()
        elseif index  == 4 then
            Timer.New(function()
                local pos = Map_UV2Pos(value[1], value[2])
                MapManager.MapUpdateEvent2(pos,function ()
                end)
            end, 2.3):Start()
        end  
    end
    for k, v in ipairs(MapManager.buffOnClickEvent) do
        if  k  == 1 then
            Timer.New(function()
                local pos = Map_UV2Pos(v[1], v[2])
               MapManager.MapUpdateEvent2(pos,function () end)
            end,0.6):Start()
        elseif k  == 2 then
            Timer.New(function()
                local pos = Map_UV2Pos(v[1], v[2])
                MapManager.MapUpdateEvent2(pos,function ()end)
            end, 1.3):Start()
        elseif k  == 3 then
            Timer.New(function()
                local pos = Map_UV2Pos(v[1], v[2])
                MapManager.MapUpdateEvent2(pos,function ()end)
            end, 2):Start()
        elseif k  == 4 then
            Timer.New(function()
                local pos = Map_UV2Pos(v[1], v[2])
                MapManager.MapUpdateEvent2(pos,function ()end)
            end, 2.6):Start()
        end  
    end
    MapManager.allOnClickEvent = {}
    MapManager.buffOnClickEvent = {}
end
local pointHandleView = require("Modules/Map/View/PointHandleView")
--生成怪按钮触发事件
function this.AddButtonLis(go,u, v,id)
    local gobutton = Util.GetGameObject(go,"Event")
    Util.AddClick(gobutton,function()
        local pos = Map_UV2Pos(u, v)
        MapManager.MapUpdateEvent2(pos,function ()
        end)
    end)
end
function this.DisPoint()
    for key, value in pairs(buttonlis) do
        for k, v in pairs(value) do
            destroy(v)
        end
    end
    MapManager.allOnClickEvent={}
    MapManager.buffOnClickEvent={}
    if MapManager.curCarbonType == CarBonTypeId.TRIAL then
        this.AddImagePre()
        this.UpdateBox()
    end
end
function this.InitRightDown()
    this.RefreshBombNum()
    this.InitShopInfo()
    this.InitBuffInfo()
end

function this.InitEffect()
    this.guiji:SetActive(false)
    this.chufa:SetActive(false)
    this.fire:SetActive(false)
end

function this.InitTip()
    this.bombTip:SetActive(false)
    if MapTrialManager.firstEnter then

        -- 月卡蛋蛋福利
        if MapTrialManager.firstEnter and BagManager.GetTempBagCountById(43) >= 2 then
            this.bombTip:SetActive(true)
            local index = 0
            local timer
            timer = Timer.New(function()
                index = index + 1
                if index == 5 then
                    this.bombTip:SetActive(false)
                    timer:Stop()
                end
            end, 1, 5, true)
            timer:Start()
        end
    end
end

-- 刷新精气值
function this.UpdatePowerValue()
    if MapTrialManager.curTowerLevel>10000 then
        this.levelNum.text = string.format(GetLanguageStrById(12566), "?")
    else
        this.levelNum.text = string.format(GetLanguageStrById(12566), MapTrialManager.curTowerLevel)
    end

    powerValue = MapTrialManager.powerValue

    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.MaskState,0)
    -- -1时召唤boss
    if powerValue == -1 then
        -- 界面打开时删除所有小怪
        this.KillAllBitch()
        MapTrialManager.canMove = true
    end
end

function this.UpdateBox()
    local killCnt = MapTrialManager.killCount
    this.powerPercent.text = tostring(killCnt)
    local killCntMax = nil
    
    local killConfigTable = MapTrialManager.GetKillConfig()
    local max = killConfigTable[#killConfigTable].Count
    local canGet = false
    local getIdList = {}
    local maxId = 1
    for i = 1, #killConfigTable do
        if killCnt >= killConfigTable[i].Count and MapTrialManager.GetTrialRewardState(i) ~= 0 then
            canGet = true
            table.insert(getIdList, i)
        end
        if killCnt >= killConfigTable[i].Count then
            maxId = killConfigTable[i].Id + 1
        end
    end
    local nextKillConfig = ConfigManager.TryGetConfigData(ConfigName.TrialKillConfig, maxId)
    if nextKillConfig then
        killCntMax = nextKillConfig.Count
    else
        killCntMax = max
    end
    this.powerPercentTotal.text = tostring(killCntMax)

    this.activeRedPoint:SetActive(canGet)
    if canGet then
        Util.SetGray(this.box, false)
        Util.AddOnceClick(this.box, function()
            local drop = {}
            for i = 1, #getIdList do
                local id = getIdList[i]
                NetManager.RequestLevelReward(id, function(msg)
                    MapTrialManager.SetTrialRewardInfo(id) --本地记录已领奖励信息
                    table.insert(drop, msg.drop)
                    if i == #getIdList then
                        local addDrop = ServerDropAdd(unpack(drop, 1, table.maxn(drop)))
                        UIManager.OpenPanel(UIName.RewardItemPopup, addDrop, 1, function()
                            -- CheckRedPointStatus(RedPointType.TrialReward)
                            -- CheckRedPointStatus(RedPointType.Trial)

                            this.UpdateBox()
                        end)
                    end
                    
                end)
            end
        end)
    else
        Util.SetGray(this.box, true)
        Util.AddOnceClick(this.box, function()end)
    end
end

function this.PlayEffect()
    if MapTrialManager.powerValue == -1 or MapTrialManager.powerValue == 0 then
        this.UpdatePowerValue()
    else
        this.fire:SetActive(true)
        this.fire:GetComponent("RectTransform").anchoredPosition = MapTrialManager.rolePos
        this.guiji:GetComponent("RectTransform").anchoredPosition = MapTrialManager.rolePos
        local timer = Timer.New(function ()
            this.fire:SetActive(false)
            this.guiji:SetActive(true)

            -- 设置动画
            this.guiji:GetComponent("RectTransform"):DOAnchorPos(targetPos, 0.5, false):OnComplete(function ()
                this.chufa:SetActive(true)
                this.guiji:SetActive(false)
            end)
        end, 0.3):Start()

        Timer.New(function ()
            this.UpdatePowerValue()
            this.InitEffect()
        end, 1):Start()
    end
end


function this.OnPowerValueChange()
    if CarbonManager.difficulty ~= 2 then return end
    -- 先放特效在更新数值
    this.PlayEffect()
end

function this.OnSortingOrderChange()
    Util.AddParticleSortLayer(this.chufa, MapPanel.sortingOrder - orginLayer)
    orginLayer = MapPanel.sortingOrder
end

-- 初始化部buff显示
function this.InitBuffInfo()
    if CarbonManager.difficulty ~= 2 then return end
    -- 补给点数量显示
    local num = 0
    local buffList = FoodBuffManager.GetBuffPropList()
    if buffList then
        num = #buffList
    end
    this.buffNum.text = num
end

-- 初始化部商店显示
function this.InitShopInfo()
    local shopData = ShopManager.GetShopDataByType(SHOP_TYPE.TRIAL_SHOP)
    if not shopData or #shopData.storeItem <= 0 then
        this.shopNum.text = "0"
        return
    end
    -- 获取可购买的商品数量
    local itemNum = 0
    local hideShopsNum = MapManager.GetShopHideCount()
    for _, item in ipairs(shopData.storeItem) do
        if _ > #shopData.storeItem - hideShopsNum then  --< 隐藏商店 未打开的问题
            break
        end
        local limitCount = ShopManager.GetShopItemLimitBuyCount(item.id)
        if limitCount == -1 or limitCount - item.buyNum > 0 then
            itemNum = itemNum + 1
        end
    end
    this.shopNum.text = itemNum
end

-- 试炼副本任务初始化
function this.InitTrialMission()
    this.powerRoot:SetActive(istrialMap)
    this.mapTime.text = GetLanguageStrById(11255)
end

-- 刷新砸炸弹、回春散数量
function this.RefreshBombNum()
    -- 试炼副本才执行
    local bombNum = 0
    local yaoNum = 0
    if CarbonManager.difficulty ~= CARBON_TYPE.TRIAL then return end
    if BagManager.GetTotalItemNum(43) == 0 or not BagManager.GetTotalItemNum(43) then
        bombNum = 0
    else
        bombNum = BagManager.GetTotalItemNum(43)
    end
    this.bombNum.text = bombNum

    if BagManager.GetTotalItemNum(31) == 0 or not BagManager.GetTotalItemNum(31) then
        yaoNum = 0
    else
        yaoNum = BagManager.GetTotalItemNum(31)
    end
    this.xingYaoNum.text = yaoNum
end

-- 试炼副本的初始化
function this.InitTrial()
    this.DragCtrl:SetActive(false)
    MapTrialManager.isChangeLevel = false
    MapTrialManager.canMove = true
    MapManager.isRemoving = false
    MapManager.deadTime = 0
end

-- 试炼副本显示时间
function this.TrialShowTime()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    local serData = ActTimeCtrlManager.GetSerDataByTypeId(30)
    local freshTime = serData.endTime
    this.mapTime.text = TimeToHMS(freshTime - PlayerManager.serverTime)..GetLanguageStrById(11260)
    this.timer = Timer.New(function()
        if not this.timer or not this.mapTime then
            return
        end
        local t = freshTime - PlayerManager.serverTime
        if t <= 0 then
            t = 0
            MapTrialManager.ClearTrialRewardInfo() --清空奖励信息
            MapTrialManager.SetKillCount(0) --重置已杀小怪数量
        end
        this.mapTime.text = TimeToHMS(t)..GetLanguageStrById(11260)
    end, 1, -1, true)
    this.timer:Start()
end

-- 转换时间
function this.FormatTime(time)
    local str = ""
    local ten_minute = math.modf(time / 600)
    local minute = math.modf(time / 60) % 10
    local ten_second =  math.modf( time / 10) % 6
    local second = time % 10
    str = ten_minute  ..minute .. ":" .. ten_second .. second
    return str
end

--检查试炼阵容信息
function this.CheckTrialHeroInfo()
    MapTrialManager.isFirstIn = true
    if #MapManager.trialHeroInfo == 0 then
        UIManager.OpenPanel(UIName.FormationEditPopup,function(d)
            this.SetSelectHero(true,d,false)
        end)
    else
        this.SetSelectHero(false,nil,true) --true从入口进入副本 默认选择第一个Hero
    end
end

function TrialMapPanel:OnClose()
    oldChoosed = nil
    for key, value in pairs(buttonlis) do
        for k, v in pairs(value) do
            destroy(v)
        end
    end
    buttonlis = {}
    this.DisPoint()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function TrialMapPanel:OnDestroy()
    for key, value in pairs(buttonlis) do
        for k, v in pairs(value) do
            destroy(v)
        end
    end
    buttonlis = {}
    MapManager.BossId ={}
    ClearRedPointObject(RedPointType.TrialReward)
    SubUIManager.Close(this.UpView)
    heroList = {}
end

--设置选择英雄界面 isFirstIn你的第一次 isFirstData你第一次射的东西 isMainIn你每次
function this.SetSelectHero(isFirstIn,isFirstData,isMainIn)
    local itemId = trialSetting[1].HealingId[1]
    local itemNum = trialSetting[1].HealingId[2]
    this.selectHero:SetActive((true) and (MapManager.curCarbonType == CarBonTypeId.TRIAL))
    local d={}
    if isFirstIn then--若是第一次进 此时我必有该英雄 不用担心是已删除英雄 通过HeroDid去获取数据
        for n, did in ipairs(isFirstData) do
            local h = HeroManager.GetSingleHeroData(did)
            table.insert(MapManager.trialHeroInfo,{heroId=h.dynamicId,tmpId=h.id,star=h.star,heroHp=10000,level=h.lv})
        end
    end
    d = MapManager.trialHeroInfo
    for k = 1, this.s_grid.transform.childCount do
        this.s_grid.transform:GetChild(k-1).gameObject:SetActive(false)
    end
    local closeChoosed=function() --有开着选择的全关了
        for i, v in ipairs(heroList) do
            local c = Util.GetGameObject(v,"choosed").gameObject
            if c.activeSelf then
                c:SetActive(false)
            end
        end
    end
    for i, v in ipairs(d) do
        if MapTrialManager.selectHeroDid ~= "" then
            if MapTrialManager.selectHeroDid == v.heroId and v.heroHp <= 0 then
                MapTrialManager.selectHeroDid = ""
            end
        end
    end
    for i, v in ipairs(d) do
        local o = heroList[i]
        if not o then
            o = newObjToParent(this.s_pre,this.s_grid)
            o.name = "pre"..i
            heroList[i] = o
        end
        o.gameObject:SetActive(true)

        local frame = Util.GetGameObject(o,"frame"):GetComponent("Image")
        local icon = Util.GetGameObject(o,"icon"):GetComponent("Image")
        local pro = Util.GetGameObject(o,"proIcon"):GetComponent("Image")
        local lv = Util.GetGameObject(o,"lv/Text"):GetComponent("Text")
        local star = Util.GetGameObject(o,"star")
        local choosed = Util.GetGameObject(o,"choosed")
        local proBg = Util.GetGameObject(o,"proBg"):GetComponent("Image")
        local lvBg = Util.GetGameObject(o,"lv"):GetComponent("Image")
        local hpExp = Util.GetGameObject(o,"hpExp"):GetComponent("Slider")
        frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig[v.tmpId].Quality, v.star))
        icon.sprite = Util.LoadSprite(GetResourcePath(heroConfig[v.tmpId].Icon))
        pro.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig[v.tmpId].PropertyName))
        lv.text = v.level
        proBg.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfig[v.tmpId].Quality, v.star))
        lvBg.sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroConfig[v.tmpId].Quality, v.star))
        SetHeroStars(star, v.star)

        --选择
        if  isFirstIn then
            choosed:SetActive(i == 1)
            if i == 1 then
                MapTrialManager.selectHeroDid = v.heroId
            end
        elseif isMainIn then
            if MapTrialManager.selectHeroDid ~= "" then
                choosed:SetActive(MapTrialManager.selectHeroDid == v.heroId and v.heroHp > 0)
            else
                if v.heroHp > 0 then
                    choosed:SetActive(true)
                    MapTrialManager.selectHeroDid = v.heroId
                else
                    choosed:SetActive(false)
                    MapTrialManager.selectHeroDid = ""
                end
            end
        else
            choosed:SetActive(MapTrialManager.selectHeroDid == v.heroId)
        end

        --血量相关
        hpExp.value = v.heroHp/10000
        Util.SetGray(o,v.heroHp <= 0)--死啦

        Util.AddOnceClick(o,function()
                if v.heroHp > 0 then
                    closeChoosed()
                    choosed:SetActive(true)
                    MapTrialManager.selectHeroDid = v.heroId
                else
                    PopupTipPanel.ShowTipByLanguageId(11247)
                end
        end)
    end

    --刷新英雄选择面板时 检测血量 若有低于40%血量的英雄 给选择Hero加血
    --再遍历一次防止下面的return 打断上面for循环表现的正常赋值
    --这里只关于自动嗑药逻辑
    for k, v in ipairs(d) do
        --若存在该设置参数并为已勾选状态 =1 否则=0
        local t = (PlayerPrefs.HasKey(PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..2)
            and PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..2) == 1) and 1 or 0
        if t == 0 then return end
        if MapTrialManager.selectHeroDid == v.heroId then
            if v.heroHp <= 0 then
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11262),itemConfig[itemId].Name))
                return
            end
        end
        --若血量小于自动回复百分比 并且 有血量
        if v.heroHp/10000<trialSetting[1].HealingPercent/10000 and v.heroHp > 0 and v.heroId == MapTrialManager.selectHeroDid then
            if (itemNum - MapManager.addHpCount) <= 0 then
                -- PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11263),itemConfig[itemId].Name))
                return
            end
            if BagManager.GetItemCountById(itemId) <= 0 then
                -- PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11264),itemConfig[itemId].Name,itemConfig[itemId].Name))
                return
            end
            NetManager.UseAddHpItemRequest(MapTrialManager.selectHeroDid,function(msg)
                local curHeroHp = 0
                -- if v.heroId == MapTrialManager.selectHeroDid then
                --     curHeroHp = v.heroHp
                -- end
                -- curHeroHp = curHeroHp + 5000  --5000增加的血量也是要配表的
                -- if curHeroHp >= 10000 then
                --     curHeroHp = 10000
                -- end
                curHeroHp = msg.curHp
                MapTrialManager.SetHeroHp({curHeroHp},MapTrialManager.selectHeroDid,function()
                    PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11265),itemConfig[itemId].Name))
                end)
            end)
        end
    end
end

--显示敌人信息面板
function this.ShowEnemyInfo(_monsterGroupId,eventId,showValues)
    UIManager.OpenPanel(UIName.ShowEnemyInfoPanel,MapPanel,_monsterGroupId)
end

--杀死所有的小怪
function this.KillAllBitch()
    MapManager.isRemoving = true
    local pointData = trailConfig[MapTrialManager.curTowerLevel].MonsterPoint
    for i = 1, #pointData do
        local mapPointId = pointData[i][1]
        if mapPointId then
            MapManager.DeletePos(mapPointId)
        end
    end
    MapManager.isRemoving = false

    -- Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)

    NetManager.MapInfoRequestOnlyCell(MapManager.curCarbonType, function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
    end)
end

return TrialMapPanel