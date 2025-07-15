 require("Base/BasePanel")
EndLessCarbonPanel = Inherit(BasePanel)
local this = EndLessCarbonPanel
local endLessConfig = ConfigManager.GetConfig(ConfigName.EndlessMapConfig)
local mapConfig = ConfigManager.GetConfig((ConfigName.ChallengeConfig))
local endlessDifficulty = ConfigManager.GetConfig((ConfigName.EndlessDifficulty))
local hadClikcBuy = false

local mapDataBg={
    [1]={
        bg=""
    },
}

--初始化组件（用于子类重写）
function EndLessCarbonPanel:InitComponent()
    EndLessMapManager.InitMapInfoData(0)
    this.btnBack = Util.GetGameObject(self.gameObject, "Bg/bg1/btnBack")
    -- 显示行动力
    this.curValue = Util.GetGameObject(self.gameObject, "stepRoot/bg/energyInfo"):GetComponent("Text")
    this.totalValue = Util.GetGameObject(self.gameObject, "stepRoot/bg/total"):GetComponent("Text")
    this.btnBuy = Util.GetGameObject(self.gameObject, "stepRoot/bg/add")

    -- 小地图
    this.miniMap = Util.GetGameObject(self.gameObject, "Bg/bg1/miniMap"):GetComponent("Image")
    this.miniMapName = Util.GetGameObject(this.miniMap.gameObject, "tBottom/main/mapName"):GetComponent("Text")
    this.worldLevel = Util.GetGameObject(this.miniMap.gameObject, "tBottom/left/worldLevel"):GetComponent("Text")
    this.worldMode = Util.GetGameObject(this.miniMap.gameObject, "tBottom/right/worldMode"):GetComponent("Text")

    -- 怪物组
    this.bossGrid = Util.GetGameObject(self.gameObject, "Bg/bg1/InfoRoot/bossList/grid")
    this.bossItemPre = Util.GetGameObject(self.gameObject, "Bg/bg1/InfoRoot/bossList/itemPre")

    -- 奖励预览
    this.rewwardGrid = Util.GetGameObject(self.gameObject, "Bg/bg1/InfoRoot/rewardList/grid")

    this.btnFight = Util.GetGameObject(self.gameObject, "Bg/bg1/InfoRoot/btnFight")

    this.btnMapInfo = Util.GetGameObject(self.gameObject, "Bg/bg1/miniMap/mapInfo")
    this.btnMapInfo:SetActive(false)
    --幫助
    -- this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    -- this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition

    -- 行动力刷新倒计时显示
    this.bgTime = Util.GetGameObject(self.gameObject, "stepRoot/bg/Bgtime")
    this.actCountTime = Util.GetGameObject(this.bgTime, "time"):GetComponent("Text")
    this.heroScroll=Util.GetGameObject(self.gameObject, "Bg/scrollpos")
    this.scrollPre=Util.GetGameObject(self.gameObject, "Bg/scrollpos/item")
    this.endlessPopup=Util.GetGameObject(self.gameObject, "endlessPopup")
    this.popupClose=Util.GetGameObject(this.endlessPopup, "btnClose")
    this.popupAtk=Util.GetGameObject(this.endlessPopup, "btnAtk")
    this.popupBack=Util.GetGameObject(this.endlessPopup, "btnBack")
    this.statePopup=Util.GetGameObject(self.gameObject, "statePopup")
    this.statePopupStart=Util.GetGameObject(this.statePopup, "btnAtk")
    this.statePopupClose=Util.GetGameObject(this.statePopup, "btnClose")

    this.rewardList = {}
    this.bossList = {}
    local height = this.heroScroll.transform.rect.height
    local width = this.heroScroll.transform.rect.width
    this.MapScrollFitterView = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.heroScroll.transform,
    this.scrollPre, Vector2.New(width, height), 1, this.scrollPre.transform.rect.height+10)
end

--绑定事件（用于子类重写）
function EndLessCarbonPanel:BindEvent()

    Util.AddClick(this.btnBack, function ()
        if UIManager.IsOpen(UIName.HelpPopup) then
            UIManager.ClosePanel(UIName.HelpPopup)
        end
        -- !!!! PS: 这里必须是主动打开副本选择界面，从地图中返回时，这个界面的上一级是地图界面，
        --  如果只是关闭自己，则会打开地图界面，不会打开副本选择界面，导致报错
        -- PlayerManager.carbonType = 1
        -- UIManager.OpenPanel(UIName.FightPointPassMainPanel)

        --检测到上一个面板打开之后，关闭自己
        -- CallBackOnPanelOpen(UIName.FightPointPassMainPanel, function()
        --     UIManager.ClosePanel(UIName.EndLessCarbonPanel)
        -- end)
        self:ClosePanel()
        CarbonManager.difficulty = 0
    end)
    Util.AddClick(this.statePopupStart, function ()
        NetManager.MapClearRequest(this.mapListData.mapid,MapManager.curCarbonType,function()
            NetManager.RequestAllHeroHp(function ()
                this.GetDataList()
                this.statePopup:SetActive(false)
                this.endlessPopup:SetActive(true)
            end)
        end)   
    end)
    Util.AddClick(this.statePopupClose, function ()
        this.statePopup:SetActive(false)
    end)
    -- Util.AddClick(this.btnFight, function ()
    --     this.EnterMap()
    -- end)


    Util.AddClick(this.btnBuy, function ()
        ---- 先同步位置再弹出购买界面
        --if not hadClikcBuy then
        --    hadClikcBuy = true
            UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = 1 })
        --end
    end)

    Util.AddClick(this.btnMapInfo, function ()
        --UIManager.OpenPanel(UIName.MinMapPopup)
    end)

    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.EndLessMap, this.helpPosition.x, this.helpPosition.y)
    end)
    Util.AddClick(this.popupClose, function()
        -- this.endlessPopup:SetActive(false)
        MsgPanel.ShowTwo(GetLanguageStrById(50350), function()
        end, function()
            NetManager.MapClearRequest(this.mapListData.mapid,MapManager.curCarbonType,function()
                NetManager.RequestAllHeroHp(function ()
                    this.GetDataList()
                    this.endlessPopup:SetActive(false) 
                end)
            end)   
        end, GetLanguageStrById(10719), GetLanguageStrById(10720), GetLanguageStrById(11351),false)
    end)
    Util.AddClick(this.popupBack, function()
        this.endlessPopup:SetActive(false)
    end)
    Util.AddClick(this.popupAtk, function()
        if this.mapListData~=nil then
            if this.mapListData.state~=2 then
                this.EnterMap(this.mapListData.mapid,true,this.mapListData)
                this.GetDataList()
            else
                this.EnterMap(this.mapListData.mapid,false,this.mapListData)
            end
        end
    end)
end

--添加事件监听（用于子类重写）
function EndLessCarbonPanel:AddListener()

    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.InitActPowerShow)
end

--移除事件监听（用于子类重写）
function EndLessCarbonPanel:RemoveListener()

    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.InitActPowerShow)
end

--界面打开时调用（用于子类重写）
function EndLessCarbonPanel:OnOpen(msg,...)
    -- 初始化组件
    this.InitCompShow()
    -- 请求获取队伍血量
    -- 设置静态表数据
    -- this.SetStaticData()
    -- this.RequestBlood(function ()
    --     this.InitActPowerShow()
    -- end)
    local dataList={}
    for index, value in ipairs(msg) do
        dataList[value.cfgId]=value
    end
--     local dataList={}
-- for index, value in ipairs(endlessDifficulty) do
--     table.insert(dataList,value)
-- end
    this.endlessPopup:SetActive(false)
    this.statePopup:SetActive(false)
    this.MapScrollFitterView:SetData(dataList, function(index, go)
        this.SetMapData(go, index,dataList)
    end,1)
    this.RequestBlood()
end
function this.GetDataList()
    NetManager.MapInfoListRequest(function (msg)
        local dataList={}
        for index, value in ipairs(msg.info) do
            dataList[value.cfgId]=value
        end
        this.MapScrollFitterView:SetData(dataList, function(index, go)
            this.SetMapData(go, index,dataList)
        end,1)
    end)
end
function this.SetMapData(go,index,dataList)
    go:SetActive(true)
    Util.GetGameObject(go, "name"):GetComponent("Text").text=GetLanguageStrById(endlessDifficulty[dataList[index].cfgId].Title)
    Util.GetGameObject(go, "bg"):GetComponent("Image").sprite=Util.LoadSprite(endlessDifficulty[dataList[index].cfgId].ListImage)
    Util.GetGameObject(go, "endLessRate"):GetComponent("Slider").value=dataList[index].passNum/dataList[index].monsterNum
    
    
    local mapbtn= Util.GetGameObject(go, "btn")
    local statePre={}
    local grayBtn=true;
    for i = 0, 3 do
        statePre[i]=Util.GetGameObject(go, "bg/state"..i)
        statePre[i]:SetActive(false)
    end
    if dataList[index].state==0 then
        mapbtn:SetActive(false)
        local mainLevelConfig=ConfigManager.GetConfigDataByKey(ConfigName.MainLevelConfig, "SortId", endlessDifficulty[dataList[index].cfgId].LevelUnlock)
        
        Util.GetGameObject(statePre[0], "titleText"):GetComponent("Text").text=GetLanguageStrById(mainLevelConfig.Name)..GetLanguageStrById(10584)
        Util.GetGameObject(go, "endLessRate"):SetActive(false)
    elseif dataList[index].state==1 then
        Util.GetGameObject(go, "endLessRate"):GetComponent("Slider").value=dataList[index].passNum/dataList[index].monsterNum
        Util.GetGameObject(go, "endLessRate"):SetActive(true)
        grayBtn=false;
    elseif dataList[index].state==2 then
        Util.GetGameObject(go, "endLessRate"):GetComponent("Slider").value=dataList[index].passNum/dataList[index].monsterNum
        Util.GetGameObject(go, "endLessRate"):SetActive(true)
        grayBtn=false;
    elseif dataList[index].state==3 then
        Util.GetGameObject(go, "endLessRate"):GetComponent("Slider").value=dataList[index].passNum/dataList[index].monsterNum
        mapbtn:SetActive(true)
        Util.GetGameObject(go, "endLessRate"):SetActive(true)
    end
    statePre[dataList[index].state]:SetActive(true)
    Util.AddOnceClick(mapbtn,function ()
        this.OpenPopupData(index,dataList,grayBtn)
    end)
end
function this.OpenPopupData(index,dataList,gray)
    local stateIndex=-1;
    for index, value in ipairs(dataList) do
        if value.state==2 then
            stateIndex=value.cfgId
        end
    end
    Log("1")
    if dataList[index].cfgId==stateIndex or stateIndex==-1  then
        this.endlessPopup:SetActive(true)
    else
        this.statePopup:SetActive(true)
        Util.GetGameObject(this.statePopup, "buttom/content"):GetComponent("Text").text=GetLanguageStrById(50280)
        Util.GetGameObject(this.statePopup, "buttom/content"):GetComponent("Text").text=string.format(GetLanguageStrById(50281),GetLanguageStrById(endlessDifficulty[dataList[stateIndex].cfgId].Title),GetLanguageStrById(endlessDifficulty[dataList[index].cfgId].Title))
    end
    local bg=Util.GetGameObject(this.endlessPopup, "BG/bg"):GetComponent("Image")
    local mapName=Util.GetGameObject(this.endlessPopup, "Name"):GetComponent("Text")
    local mapTitel=Util.GetGameObject(this.endlessPopup, "titleText"):GetComponent("Text")
    local dataSlider=Util.GetGameObject(this.endlessPopup, "BG/endLessRate"):GetComponent("Slider")
    local numText=Util.GetGameObject(this.endlessPopup, "numText"):GetComponent("Text")
    bg.sprite=Util.LoadSprite(endlessDifficulty[dataList[index].cfgId].InsideImage)
    mapName.text=GetLanguageStrById(endlessDifficulty[dataList[index].cfgId].Title)
    mapTitel.text=GetLanguageStrById(endlessDifficulty[dataList[index].cfgId].Desc)
    dataSlider.value=dataList[index].passNum/dataList[index].monsterNum
    Util.SetGray(Util.GetGameObject(this.endlessPopup, "btnClose"), gray)
    if gray then
        Util.GetGameObject(this.endlessPopup, "btnClose"):GetComponent("Button").enabled = false
    else
        Util.GetGameObject(this.endlessPopup, "btnClose"):GetComponent("Button").enabled = true
    end
    numText.text=GetLanguageStrById(50282)..dataList[index].passNum.."/"..dataList[index].monsterNum
    this.mapListData=dataList[index]
end

function EndLessCarbonPanel:OnSortingOrderChange()

end

function EndLessCarbonPanel:OnShow()
    this.InitActPowerShow()
    this.ShowCountTime()

    -- 界面打开时刷新队伍血量数据
    -- 刷新无尽副本编队数据
    EndLessMapManager.RrefreshFormation()
    hadClikcBuy = false
end

function this.InitActPowerShow()
    local curEnergy = 0
    curEnergy = BagManager.GetItemCountById(1)
    local color = curEnergy <= 5 and "FF0014FF" or "A0B2B2FF"
    local str = string.format("<color=#%s>%s</color>", color, tostring(GetLanguageStrById(curEnergy)))
    this.curValue.text = str
end


function this.RequestBlood(func)
    NetManager.RequestAllHeroHp(function ()
        if func then func() end
    end)
end

function this.EnterMap(mapId,newMap,data)
    CarbonManager.difficulty = CARBON_TYPE.ENDLESS
    CarbonManager.carbonType = CARBON_TYPE.ENDLESS
    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.ENDLESS)
    if not PlayerPrefs.HasKey("WuJin"..PlayerManager.uid) then
        PlayerPrefs.SetInt("WuJin"..PlayerManager.uid ,0)
    end
    EndLessMapManager.RrefreshFormationStart()
    local note = PlayerPrefs.GetInt("WuJin"..PlayerManager.uid)
    EndLessMapManager.InitMapInfoData(mapId)
    MapManager.curMapId = EndLessMapManager.openMapId
    EndLessMapManager.cfgId=data.cfgId
    if serData.endTime ~= note or newMap then
        -- TaskManager.ResetEndlessMissionState()
        EndLessMapManager.maxMosterNum=data.monsterNum
        EndLessMapManager.deadMosterNum=data.passNum
        MapManager.curCarbonType = CarBonTypeId.ENDLESS
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CARBON, mapId)
    else
        MapManager.curCarbonType = CarBonTypeId.ENDLESS
        EndLessMapManager.maxMosterNum=data.monsterNum
        EndLessMapManager.deadMosterNum=data.passNum
        NetManager.MapInfoRequest(mapId, function()
            CarbonManager.difficulty = CARBON_TYPE.ENDLESS
            CarbonManager.carbonType = CARBON_TYPE.ENDLESS
            MapManager.isReloadEnter = false
            SwitchPanel.OpenPanel(UIName.MapPanel)
            
        end,MapManager.curCarbonType)
    end
end

function this.InitCompShow()
    --生成6个boss预设
    for i = 1, 6 do
        if not this.bossList[i] then
            this.bossList[i] = newObjToParent(this.bossItemPre, this.bossGrid)
            this.bossList[i]:SetActive(false)
        end
    end

    -- 8个奖励预览
    for j = 1, 8 do
        if not this.rewardList[j] then
            this.rewardList[j] = SubUIManager.Open(SubUIConfig.ItemView, this.rewwardGrid.transform)
            this.rewardList[j].gameObject:SetActive(false)
        end
    end
end

function this.SetStaticData()
    local mapData = endLessConfig[EndLessMapManager.openMapId]
    if not mapData then
     
    end

    for i = 1, #mapData.RewardShow do
        local item = {}
        local itemId = mapData.RewardShow[i][1]
        item[#item + 1] = itemId
        item[#item + 1] = 0
        this.rewardList[i]:OnOpen(false, item, 1.05)
        this.rewardList[i].gameObject:SetActive(true)
    end

    -- 显示怪物
    for j = 1, #mapData.MonsterShow do
        local monsterId = mapData.MonsterShow[j]
        local mIcon, level = MonsterCampManager.GetIconByMonsterId(monsterId)

        local icon = Util.GetGameObject(this.bossList[j], "icon"):GetComponent("Image")
        local monsterLevel = Util.GetGameObject(this.bossList[j], "imgLv/lv"):GetComponent("Text")
        icon.sprite = mIcon
        monsterLevel.text = level

        this.bossList[j]:SetActive(true)
    end



    this.worldLevel.text = EndLessMapManager.worldLevel
    this.worldMode.text = MAP_MODE[mapConfig[EndLessMapManager.openMapId].DifficultType]
    this.miniMapName.text = mapData.Info
end

-- 行动力是否显示倒计时
function this.ShowCountTime()
    if this.timer then 
        this.timer:Stop()
    end
    this.timer = nil
    this.actCountTime.text = ""
    this.bgTime:SetActive(true) 
    local tempLeftTime = 0
    -- 启动倒计时
    this.timer = Timer.New(function ()
        local leftTime = AutoRecoverManager.GetRecoverTime(1)
        if leftTime >= tempLeftTime then
            this.InitActPowerShow()
            tempLeftTime = leftTime
        end
        if leftTime < 0 then
            leftTime = 0
        end
        this.actCountTime.text = string.format(GetLanguageStrById(23028), GetTimeMaoHaoStrBySeconds(math.floor(leftTime)))
    end, 1, -1, true)
    this.timer:Start()

    if this.timer1 then 
        this.timer1:Stop()
        this.timer1 = nil
    end
    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.ENDLESS)
    local freshData = serData.endTime - GetTimeStamp()
    -- local updateTime = function()
    --     this.text2.text = TimeToFelaxible(freshData).."后重置"
    -- end
    
    -- updateTime()
    
    this.timer1 = Timer.New(function ()
        freshData = freshData - 1
        if freshData < 0 then
            -- CheckRedPointStatus(RedPointType.EndlessPanel)
            this:ClosePanel()
        else
            -- updateTime()
        end  
    end, 1, -1, true)
    this.timer1:Start()
    
end


--界面关闭时调用（用于子类重写）
function EndLessCarbonPanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function EndLessCarbonPanel:OnDestroy()
    this.rewardList = {}
    this.bossList = {}
end

return EndLessCarbonPanel