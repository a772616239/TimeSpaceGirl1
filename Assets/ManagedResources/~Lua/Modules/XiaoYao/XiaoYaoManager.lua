XiaoYaoManager = {}
local this = XiaoYaoManager
this.allMapData={}
this.curMapId=0;
this.MonsterData={}
this.fightBossIndex = 0

this.HeroData={}
this.GetHeroIndex = 0

this.luckyTurnTableRewards={}
this.luckyluckyTurnTableTimes = 0
this.luckyluckyTurnTableRemainTime = 0
this.isAutoYouli=false   --逍遥游自动游历开关

this.first = true
--打开逍遥游地图列表界面
function this.Initialize()

end
function this.OpenMapList()
    this.first = false
    this.GetOpenMapData(function(_data)
        local XiaoYaoMapPanel = UIManager.GetOpenPanel(UIName.XiaoYaoMapPanel)
        if XiaoYaoMapPanel then
            -- XiaoYaoMapPanel:ClosePanel()
            XiaoYaoMapPanel.GetMapList()
        end
        -- UIManager.OpenPanel(UIName.XiaoYaoYouPanel,_data)
        -- UIManager.OpenPanel(UIName.FightPointPassMainPanel)
    end)
end

function this.GetOpenMapData(func)
    NetManager.JourneyGetInfoResponse(function (msg)
        local _data={}
        --LogGreen("#msg.infos:"..#msg.infos)
        for i = 1, #msg.infos do
            _data[msg.infos[i].mapId]={}
            _data[msg.infos[i].mapId].process=msg.infos[i].process
            _data[msg.infos[i].mapId].redPoint=msg.infos[i].redPoint
            _data[msg.infos[i].mapId].first=msg.infos[i].first
        end      
        this.allMapData=_data
        
        this.CheckRedPoint2()
        if func then
            func(_data)
        end
    end)
end

-- 判断地图是否首通
function this.IsFirstPass(mapId)
    if not this.allMapData or not this.allMapData[mapId] or this.allMapData[mapId].first ~= 1 then
        return false
    end
    return true
end

--打开逍遥游地图界面
function this.OpenXiaoYaoMap(mapId,func)
    NetManager.JourneyGetOneInfoResponse(mapId,function (msg)  
        this.curMapId=mapId
        local curMapData=msg     
        if curMapData.cell~=nil then
            table.sort(curMapData.cell,function(a,b)
                return a.cellIndex  < b.cellIndex 
            end)            
        end       
        this.fightBossIndex = 0
        this.GetHeroIndex = 0
        this.InitLuckyTurnTables(msg)
        this.InitMonsterData(msg.monsterInfo,1)
        this.InitHeroData(msg.goodsInfo,1)  
        UIManager.OpenPanel(UIName.XiaoYaoMapPanel,curMapData)    
        if func then
            func()
        end
    end)
end
--打开逍遥游地图界面
function this.OpenXiaoYaoMapPanel(mapId,func)
    NetManager.JourneyGetOneInfoResponse(mapId,function (msg)  
        this.curMapId=mapId
        local curMapData=msg     
        if curMapData.cell~=nil then
            table.sort(curMapData.cell,function(a,b)
                return a.cellIndex  < b.cellIndex 
            end)            
        end       
        this.fightBossIndex = 0
        this.GetHeroIndex = 0
        this.InitLuckyTurnTables(msg)
        this.InitMonsterData(msg.monsterInfo,1)
        this.InitHeroData(msg.goodsInfo,1)  
        UIManager.OpenPanel(UIName.XiaoYaoMapPanel,curMapData)    
        if func then
            func(curMapData)
        end
    end)
end

--掷骰子请求
function this.StartXiaoYao()    
    NetManager.JourneyDoResponse(this.curMapId,function (msg)       
        --0、普通节点 1、奖励节点 2、双倍节点 3、额外骰子节点 4、招募英雄节点 5、怪物节点 6,转盘
        if msg.pathType == 5 then
            this.InitMonsterData(msg.monster,2)              
        elseif msg.pathType == 6 then 
            this.InitLuckyTurnTables(msg) 
        elseif msg.pathType == 4 then
            this.InitHeroData(msg.goodsInfo,2)
        elseif msg.pathType == 0 then
        end        
        Game.GlobalEvent:DispatchEvent(GameEvent.XiaoYao.StartXiaoYao, msg)
    end)
end

function this.GetCostMaxValue()
    local vleTable=ConfigManager.GetConfigData(ConfigName.PrivilegeTypeConfig,39).Condition
    if VipManager.GetVipLevel()+1>#vleTable then
        return vleTable[#vleTable][2]
    else
        return vleTable[VipManager.GetVipLevel()+1][2]
    end
    
end

--初始化幸运转盘
function this.InitLuckyTurnTables(msg)
    this.luckyTurnTableRewards = {}
    if msg then
        if msg.randomItem and #msg.randomItem > 0 then
            for i = 1, #msg.randomItem do
                table.insert(this.luckyTurnTableRewards,msg.randomItem[i])
            end
        elseif msg.random and #msg.random > 0 then
            for i = 1, #msg.random do
                table.insert(this.luckyTurnTableRewards,msg.random[i])
            end
        elseif msg.nextRandom and  #msg.nextRandom > 0 then
            for i = 1, #msg.nextRandom do
                table.insert(this.luckyTurnTableRewards,msg.nextRandom[i])
            end
        end
        if msg.randomTime then
            this.luckyluckyTurnTableTimes = msg.randomNum
            this.luckyluckyTurnTableRemainTime = msg.randomTime
        elseif msg.overTime then
            this.luckyluckyTurnTableTimes = this.luckyluckyTurnTableTimes + 1
            this.luckyluckyTurnTableRemainTime = msg.overTime
        else
            this.luckyluckyTurnTableTimes = this.luckyluckyTurnTableTimes - 1
        end
    end
end

function this.UpdateLuckyTurnTables()
    this.luckyTurnTableRewards = {}
    this.luckyluckyTurnTableRemainTime = 0
    this.luckyluckyTurnTableTimes = 0
end

-- type 1初始化   2添加  hero
function this.InitHeroData(goodsInfo,type)
    if type == 1 then
        this.HeroData = {}
        for i = 1, #goodsInfo do
            local hero = {}
            hero.goodsId  = goodsInfo[i].goodsId  
            hero.goodsIndex  = goodsInfo[i].goodsIndex  
            hero.remainTime   = goodsInfo[i].remainTime   
            table.insert(this.HeroData,hero)
        end
    elseif type == 2 then
        local hero = {}
        hero.goodsId  = goodsInfo.goodsId  
        hero.goodsIndex  = goodsInfo.goodsIndex  
        hero.remainTime   = goodsInfo.remainTime  
        table.insert(this.HeroData,hero)
    end
    table.sort(this.HeroData,function(a,b)
        return a.goodsIndex > b.goodsIndex
    end)
 end

 function this.GetHeroDatas()
    if not this.HeroData or #this.HeroData < 1 then
        return nil
    end

    for i,v in ipairs(this.HeroData) do
        if v.remainTime - PlayerManager.serverTime < 1 then
            if v.goodsIndex == this.GetHeroIndex then
                this.GetHeroIndex = 0
            end
            table.remove(this.HeroData,i)
        end
    end

    table.sort(this.HeroData,function(a,b)
        return a.goodsIndex > b.goodsIndex
    end)
    return this.HeroData
 end

--刷新
function this.UpdateHeroData(id)
    for i,v in ipairs(this.HeroData) do
        if v.goodsIndex == id then
            table.remove(this.HeroData,i)
        end
    end
 end

--获取招募时间
 function this.GetHeroDataTime()
    if not this.HeroData or #this.HeroData < 1 then
        PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(this.curMapId),tostring(1)),0)
        this.CheckRedPoint2()
        return 0,0
    end
    for i,v in ipairs(this.HeroData) do
        if v.remainTime - GetTimeStamp() < 1 then
            if v.goodsIndex == this.GetHeroIndex then
                this.GetHeroIndex = 0
            end
            table.remove(this.HeroData,i)
        end   
    end
    table.sort(this.HeroData,function(a,b)
        return a.goodsIndex > b.goodsIndex
    end)
    local remainTime= GetTimeStamp()
    if this.HeroData[1] then
        remainTime=this.HeroData[1].remainTime
    end
    return #this.HeroData,remainTime
 end

-- type 1初始化   2添加  boss
function this.InitMonsterData(BackMonsterDatas,type)
    if type == 1 then
        this.MonsterData = {}
        for i = 1, #BackMonsterDatas do
            local monster = {}
            monster.monsterId = BackMonsterDatas[i].monsterId 
            monster.monsterIndex = BackMonsterDatas[i].monsterIndex 
            monster.monsterHp  = BackMonsterDatas[i].monsterHp  
            monster.remainTime  = BackMonsterDatas[i].remainTime  
            monster.attackNum = BackMonsterDatas[i].attackNum  
            monster.reward = BackMonsterDatas[i].rewardShow 
            table.insert(this.MonsterData,monster)
        end
    elseif type == 2 then
        local monster = {}
            monster.monsterId = BackMonsterDatas.monsterId 
            monster.monsterIndex = BackMonsterDatas.monsterIndex 
            monster.monsterHp  = BackMonsterDatas.monsterHp  
            monster.remainTime  = BackMonsterDatas.remainTime  
            monster.attackNum = BackMonsterDatas.attackNum  
            monster.reward = BackMonsterDatas.rewardShow 
            table.insert(this.MonsterData,monster)
    end
 end

--刷新
 function this.UpdateMonsterData(BackMonsterData,id)
    for i,v in ipairs(this.MonsterData) do
        if not BackMonsterData  and v.monsterIndex == id then
            table.remove(this.MonsterData,i)
            break
        elseif BackMonsterData and BackMonsterData.monsterIndex == v.monsterIndex then
            v.monsterHp = BackMonsterData.monsterHp
            v.attackNum = BackMonsterData.attackNum
            break
        end
    end
 end

 function this.GetMonsterDatas()
    if not this.MonsterData or #this.MonsterData < 1 then
        PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(this.curMapId),tostring(3)),0)
        this.CheckRedPoint2()
        return nil
    end
    for i,v in ipairs(this.MonsterData) do
        if v.remainTime - PlayerManager.serverTime < 1 or v.monsterHp <= 0 then
            if v.monsterIndex == this.fightBossIndex then
                this.fightBossIndex = 0
            end
            table.remove(this.MonsterData,i)
        end
    end
    table.sort(this.MonsterData,function(a,b)
        return a.monsterIndex > b.monsterIndex
    end)
    return this.MonsterData
 end

function this.SortMonster(MonsterData)
    table.sort(MonsterData,function(a,b) 
        if a.remainTime <= b.remainTime then
            return a.monsterIndex > b.monsterIndex
        else
            return a.remainTime > b.remainTime
        end
    end)
end
--boss 剩余时间
function this.GetMonsterDataReMainTimesAndTime()
    if not this.MonsterData or #this.MonsterData < 1 then
        return 0,0
    end
    local removeData = {}
    for i,v in ipairs(this.MonsterData) do
        if v.remainTime - PlayerManager.serverTime < 1 then
            table.remove(this.MonsterData,i)
        end
    end
    this.SortMonster(this.MonsterData)
    return #this.MonsterData,this.MonsterData[1].remainTime
 end
 this.fightBossOldIndex = 0
 --开始战斗
function this.ExecuteFightBattle(id,func)
    NetManager.StartXiaoyaoBossFightRequest(id,function(msg)
            local fightData = BattleManager.GetBattleServerData(msg,0)
            if func then
                func()
            end
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.XIAOYAOYOU,function(result)         
                Timer.New(function()
                    if result.result == 1 then
                        this.UpdateMonsterData(nil,id)   
                        this.fightBossIndex = 0
                        UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                            this.OpenXiaoYaoMap(XiaoYaoManager.curMapId,function()
                                UIManager.OpenPanel(UIName.XiaoYaoLuckyBossPopup)  
                            end)                        
                        end)   
                    else
                        -- this.UpdateMonsterData(msg.monster)   
                        -- this.OpenXiaoYaoMap(XiaoYaoManager.curMapId,function()
                        --     this.fightBossIndex = id
                        --     UIManager.OpenPanel(UIName.XiaoYaoLuckyBossPopup)
                        -- end)  
                        this.UpdateMonsterData(msg.monster) 
                        this.fightBossOldIndex = id  
                                             
                    end              
                end, 0.2):Start()              
            end)
    end)
end

-- 转盘请求
function this.GameOperate(func)
    -- 初始化数据
    NetManager.XiaoyaoyouTurnTableRequest(function(msg)
        this.InitLuckyTurnTables(msg) 
        if func then
            func(msg)
        end
    end)
end

function this.CheckRedPoint2()
    return this.CheckRedPoint()
end

--检测逍遥游红点
function this.CheckRedPoint(_mapId,_eventId)
    local eventId = _eventId and tonumber(_eventId) or 0
    local mapId = _mapId and tonumber(_mapId) or 0
    
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.XiaoYaoYou) then
        return false
    end
    if eventId and eventId > 0 and mapId and mapId > 0 then
        if PlayerPrefs.GetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(mapId),tostring(eventId))) == 1 then
            return true
        end
        return false
    elseif mapId and mapId > 0 then
        for i = 1 , 3 do
            if PlayerPrefs.GetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(mapId),tostring(i))) == 1 then 
                return true
            end
        end
        return false
    else 
        if BagManager.GetItemCountById(UpViewRechargeType.YunYouVle)>=PrivilegeManager.GetPrivilegeNumber(39) then
            return true
        end  
        for k, v in pairs(this.allMapData) do
            --LogGreen("v.redPoint:"..v.redPoint.."   k:"..k)
            for i = 1 , 3 do
                if v.redPoint == 1 then 
                    --LogGreen("k:"..k.."   i:"..i.."    true:"..PlayerPrefs.GetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(k),tostring(i))))
                    if PlayerPrefs.GetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(k),tostring(i))) == 1 then 
                        return true
                    end
                else     
                    if PlayerPrefs.GetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(k),tostring(i))) == 1 then 
                        PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(k),tostring(i)),0)
                    end                 
                end      
            end
        end
        return false
    end
    return false
end
return XiaoYaoManager