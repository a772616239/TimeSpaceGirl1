require("Base/BasePanel")
XiaoYaoMapPanel = Inherit(BasePanel)
local this = XiaoYaoMapPanel
local cursortingOrder=0
local mapData={}
local curGridIndex=1
local allGridData={}
local allEffect={}
local isAuto=false    --是否开启自动游历
local isAutoRun=false   --是否在自动游历中
local priThread = nil
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local saiNum=1  --骰子数量
local eventTimer
local shopLeftTime=0
local heroNum=0
local rouleLeftTime=0
local rouleNum=0
local bossLeftTime=0
local bossNum=0
local isPlayMove=0
local targetBtn
local costNum   --每次摇骰子消耗道具数量
local saiziImage={"N1_img_zhanqi_01","N1_img_zhanqi_02","N1_img_zhanqi_03","N1_img_zhanqi_04","N1_img_zhanqi_05","N1_img_zhanqi_06"}
--初始化组件（用于子类重写）
function this:InitComponent()
    -- this.spLoader = SpriteLoader.New()
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
    this.mapName=Util.GetGameObject(self.gameObject,"mapTitle/mapName"):GetComponent("Text")
    this.mapProcess=Util.GetGameObject(self.gameObject,"mapTitle/mapProcess"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.shopBtn = Util.GetGameObject(self.gameObject, "btnGrid/shopBtn")
    this.shopTime=Util.GetGameObject(self.gameObject, "btnGrid/shopBtn/time"):GetComponent("Text")
    this.shopNum=Util.GetGameObject(self.gameObject, "btnGrid/shopBtn/num/Text"):GetComponent("Text")
    Util.GetGameObject(self.gameObject, "btnGrid/shopBtn/btnName"):GetComponent("Text").text=GetLanguageStrById(12002)
    this.shopRedPoint =Util.GetGameObject(self.gameObject, "btnGrid/shopBtn/redPoint")
    this.rouleBtn = Util.GetGameObject(self.gameObject, "btnGrid/rouleBtn")
    this.rouleTime=Util.GetGameObject(self.gameObject, "btnGrid/rouleBtn/time"):GetComponent("Text")
    this.rouleNum=Util.GetGameObject(self.gameObject, "btnGrid/rouleBtn/num/Text"):GetComponent("Text")
    Util.GetGameObject(self.gameObject, "btnGrid/rouleBtn/btnName"):GetComponent("Text").text=GetLanguageStrById(12004)
    this.rouleRedPoint = Util.GetGameObject(self.gameObject, "btnGrid/rouleBtn/redPoint")
    this.bossBtn = Util.GetGameObject(self.gameObject, "btnGrid/bossBtn")
    this.bossTime=Util.GetGameObject(self.gameObject, "btnGrid/bossBtn/time"):GetComponent("Text")
    this.bossNum=Util.GetGameObject(self.gameObject, "btnGrid/bossBtn/num/Text"):GetComponent("Text")
    Util.GetGameObject(self.gameObject, "btnGrid/bossBtn/btnName"):GetComponent("Text").text=GetLanguageStrById(12003)
    this.bossRedPoint = Util.GetGameObject(self.gameObject, "btnGrid/bossBtn/redPoint")
    this.previewBtn=Util.GetGameObject(self.gameObject, "previewBtn")
    this.autoBtn=Util.GetGameObject(self.gameObject, "auto")--自动游历按钮
    this.toggle=Util.GetGameObject(self.gameObject, "auto/toggle")--自动游历开关显示
    this.mapParent=Util.GetGameObject(self.gameObject,"mapParent")
    this.gridParent=Util.GetGameObject(self.gameObject,"mapParent/gridParent")
    this.grid=Util.GetGameObject(self.gameObject,"prefab/grid")
    --this.eventPoint=Util.GetGameObject(self.gameObject,"prefab/eventPoint")
    this.startBtn=Util.GetGameObject(self.gameObject,"startBtn") 
    this.isStart=Util.GetGameObject(self.gameObject,"isStart")  
    this.isStartImage=Util.GetGameObject(self.gameObject,"isStart/Image"):GetComponent("Image")
    this.TT=Util.GetGameObject(self.gameObject,"scroll/mapParent/TT")    
    this.TTPlayIcon=Util.GetGameObject(self.gameObject,"scroll/mapParent/TT/Image/Image"):GetComponent("Image")  
    this.mapY=this.mapParent.transform.localPosition.y    

    -- 逍遥点刷新倒计时显示
    this.bgTime = Util.GetGameObject(self.gameObject, "costProp/Bgtime")
    this.costIcon=Util.GetGameObject(self.gameObject, "costProp/icon"):GetComponent("Image")
    this.costInfo=Util.GetGameObject(self.gameObject, "costProp/energyInfo"):GetComponent("Text")
    this.addItmBtn = Util.GetGameObject(self.gameObject, "costProp/add")
    this.actCountTime = Util.GetGameObject(this.bgTime, "time"):GetComponent("Text")

    this.youliTag = Util.GetGameObject(self.gameObject, "mapParent/TT/youli")

     -- 事件触发特效
    --  this.moneyEffect = poolManager:LoadAsset("c_xy_0012_skeff_slidesk_ballistic", PoolManager.AssetType.GameObject)
    --  this.moneyEffect.transform:SetParent(this.transform)
    --  this.moneyEffect.transform.localScale = Vector3.one
    --  this.moneyEffect.transform.localPosition = Vector3.New(0, 0, 0)
    --  this.moneyEffect:SetActive(false)

     this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")   
     this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition  

     this.oneSaiZiEffect=Util.GetGameObject(self.gameObject, "saizi/EFFECT_UI_SHaiZi_DanZi")
     this.twoSaiZiEffect=Util.GetGameObject(self.gameObject, "saizi/EFFECT_UI_SHaiZi_ShuangZi")
    

end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.addItmBtn, function ()                
        -- UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.XiaoYaoYouItemExchange,1008)
        UIManager.OpenPanel(UIName.ShopBuyPopup, 7,90101)
    end)

    Util.AddClick(this.btnBack, function ()                
        if isAutoRun then
            MsgPanel.ShowTwo(GetLanguageStrById(12005), nil, function()
                self:ClosePanel()                
            end)
            return
        end
        self:ClosePanel()
    end)
    --商店点击
    Util.AddClick(this.shopBtn, function ()    
        PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(XiaoYaoManager.curMapId),tostring(1)),0)   
        XiaoYaoManager.CheckRedPoint2() 
        UIManager.OpenPanel(UIName.XiaoyaoHeroGetPopup)
    end)
    --转盘点击
    Util.AddClick(this.rouleBtn, function ()    
        PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(XiaoYaoManager.curMapId),tostring(2)),0)   
        XiaoYaoManager.CheckRedPoint2()     
        -- local grids={{index=3,gName="ccc"},{index=5,gName="eee"},{index=2,gName="bbb"},{index=4,gName="ddd"}}
        -- table.sort(grids,function(a,b)
        --     return a.index < b.index
        -- end)
        -- for i = 1, #grids do
        --     Log(grids[i].gName)
        -- end
        UIManager.OpenPanel(UIName.XiaoYaoLuckyTurnTablePopup)
    end)
    --boss点击事件
    Util.AddClick(this.bossBtn, function ()    
        PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(XiaoYaoManager.curMapId),tostring(3)),0)  
        XiaoYaoManager.CheckRedPoint2()      
       UIManager.OpenPanel(UIName.XiaoYaoLuckyBossPopup)
    end)
    --奖励预览
    Util.AddClick(this.previewBtn, function ()        
        UIManager.OpenPanel(UIName.XiaoYaoRewardPreviewPanel)
    end)

    --自动游历点击
    Util.AddClick(this.autoBtn, function ()        
        if isAuto then
            isAuto=false                        
        else
            isAuto=true            
        end
        XiaoYaoManager.isAutoYouli=isAuto
        this.toggle.gameObject:SetActive(isAuto)
    end)
    --开始游历
    Util.AddClick(this.startBtn,function()
        if costNum>BagManager.GetItemCountById(UpViewRechargeType.YunYouVle) then
            PopupTipPanel.ShowTip(GetLanguageStrById(12006))
            return
        end
        if curGridIndex>=#allGridData then            
            MsgPanel.ShowTwo(GetLanguageStrById(50345), nil, function()
                self:ClosePanel()
            end)
            return
        end
        if isAuto then
           this.isStart:SetActive(true)
           this.startBtn:SetActive(false)
           this.youliTag:SetActive(true)
           this.isStartImage.sprite=Util.LoadSprite("x_xiaoyaoyou_tingzhi_zh")
           isAutoRun=true
        end        
        this.btnBack:GetComponent("Button").enabled = false
        local curValue=BagManager.GetItemCountById(UpViewRechargeType.YunYouVle)
        local maxValue=PrivilegeManager.GetPrivilegeNumber(40)
        if curValue==maxValue then
            NetManager.DiceInfoRequest(3,function ()
        
            end)
        end
        XiaoYaoManager.StartXiaoYao()
    end)
     --开始游历
     Util.AddClick(this.isStart,function()
        if isAutoRun then
            this.isStartImage.sprite=Util.LoadSprite("x_xiaoyaoyou_kaishi_zh")
            isAutoRun=false
        else
            this.isStartImage.sprite=Util.LoadSprite("x_xiaoyaoyou_tingzhi_zh")
            isAutoRun=true
        end        
    end)
     --帮助按钮
     Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.XiaoYaoHelp,this.helpPosition.x,this.helpPosition.y)
    end)
end


--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.XiaoYao.StartXiaoYao, this.PlaySaiziAnim)
    Game.GlobalEvent:AddEvent(GameEvent.XiaoYao.RefreshEventShow, this.RefreshEventBtn)
    Game.GlobalEvent:AddEvent(GameEvent.XiaoYao.PlayEventEffect, this.PlayEffect)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.XiaoYao.StartXiaoYao, this.PlaySaiziAnim)
    Game.GlobalEvent:RemoveEvent(GameEvent.XiaoYao.RefreshEventShow, this.RefreshEventBtn)
    Game.GlobalEvent:RemoveEvent(GameEvent.XiaoYao.PlayEventEffect, this.PlayEffect)
end

---播放骰子动效
function this.PlaySaiziAnim(_data)
    this.startBtn:GetComponent("Button").enabled=false
    Log("当前骰子数："..#_data.pointes) 
    -- 骰子音效
    --SoundManager.PlaySound(SoundConfig.Sound_UI_ShaiZi)
    if #_data.pointes>1 then
        this.twoSaiZiEffect:SetActive(true)
    else
        this.oneSaiZiEffect:SetActive(true)
    end
    if priThread then
        coroutine.stop(priThread)
        priThread = nil
    end
    
    priThread = coroutine.start(function()   
        Log("当前点数aaaa：".._data.pointes[1]) 
        if #_data.pointes>1 then
            Util.GetGameObject(this.twoSaiZiEffect, "ShaiZi (1)/GameObject/shaizi_Zhong_Zuo"):GetComponent("Image").sprite=Util.LoadSprite(saiziImage[_data.pointes[1]])
            Util.GetGameObject(this.twoSaiZiEffect, "ShaiZi (1)/GameObject/shaizi_Zhong_You"):GetComponent("Image").sprite=Util.LoadSprite(saiziImage[_data.pointes[2]])
        else
            Util.GetGameObject(this.oneSaiZiEffect, "ShaiZi/GameObject/shaizi_Zhong"):GetComponent("Image").sprite=Util.LoadSprite(saiziImage[_data.pointes[1]])
        end             
        coroutine.wait(2) 
        this.oneSaiZiEffect:SetActive(false)   
        this.twoSaiZiEffect:SetActive(false)       
        this.RunMap(_data)     
    end)   
end

--开始跑图
function this.RunMap(_data)
    this.UpdateYunYouVleShow()    
    Log("开始跑图")
    local targetIndex=0
    for i = 1, #_data.pointes do       
        Log("当前点数：".._data.pointes[i]) 
        targetIndex=targetIndex+_data.pointes[i]        
    end       
    targetIndex=targetIndex+curGridIndex 
    Log("目标格子索引："..targetIndex)
    if targetIndex>#allGridData then
        targetIndex=#allGridData
    end
    this.MoveTT(targetIndex,_data)      
end

--主角移动
function this.MoveTT(targetIndex,_data)
    if isPlayMove==1 then
        return
    end
    this.SetTTDirection()  
    curGridIndex=curGridIndex+1   
    --LogGreen("curGridIndex:"..curGridIndex)  
    allEffect[curGridIndex].gameObject:SetActive(true)
    --allEffect[curGridIndex].gameObject:SetActive(false)
    this.TT.transform:DOAnchorPos(Vector3(allGridData[curGridIndex].x,allGridData[curGridIndex].y,0),0.3):OnUpdate(function()
        local curTimeStamp = GetTimeStamp()
        if curTimeStamp - this._PlayTimeStamp >= 0.3 then
            this._PlayTimeStamp = curTimeStamp
            SoundManager.PlaySound(SoundConfig.UI_Xyy_jiaobu)
            SoundManager.PlaySound(SoundConfig.UI_Xyy_jinbi)
        end
    end):OnComplete(function ()                   
        this.mapProcess.text=string.format(GetLanguageStrById(12008),(curGridIndex/#allGridData*100))
        this.MapMove(allGridData[curGridIndex].x,0.3)
        if curGridIndex==targetIndex then
            Log("待机动画")
            -- this.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) 
            -- this.liveNode:SetWalkDir(WALK_DIR.IDLE_FRONT)   
            this.startBtn:GetComponent("Button").enabled=true     
            this.btnBack:GetComponent("Button").enabled = true    
            this.EventTrigger(_data)
            if curGridIndex>=#allGridData then
                this.StopAuto()           
                this.youliTag:SetActive(false)
                this.isStart:SetActive(false)
                this.startBtn:SetActive(true)              
            end 
            if isAutoRun then
                if costNum>BagManager.GetItemCountById(UpViewRechargeType.YunYouVle) then
                    PopupTipPanel.ShowTip(GetLanguageStrById(12006))
                    this.youliTag:SetActive(false)
                    this.isStart:SetActive(false)
                    this.startBtn:SetActive(true)
                    isAutoRun=false
                    return
                end
                if priThread then
                    coroutine.stop(priThread)
                    priThread = nil
                end
                priThread = coroutine.start(function()            
                    coroutine.wait(1) 
                    XiaoYaoManager.StartXiaoYao()                    
                end)   
                this.btnBack:GetComponent("Button").enabled = true
            else
                this.youliTag:SetActive(false)
                this.isStart:SetActive(false)
                this.startBtn:SetActive(true)
                this.btnBack:GetComponent("Button").enabled = true
            end
        else
            this.MoveTT(targetIndex,_data)
        end   
    end):SetEase(Ease.Linear)
end

--取消自动游历
function this.StopAuto()
    isAutoRun=false
    this.youliTag:SetActive(false)
end
--事件触发处理
function this.EventTrigger(_data)
    
    Util.GetGameObject(this.gridParent.transform:GetChild(curGridIndex-1).gameObject,"eventPoint"):SetActive(false)    
    Log("触发事件类型为：".._data.pathType) 
    Log("游戏当前时间为："..PlayerManager.serverTime)
    Log("触发事件时间为：".._data.overTime)
    if _data.pathType==0 then  --普通节点
        --LogGreen("普通奖励："..#_data.drop)
    elseif _data.pathType==1 then --宝箱
        Log("获得一个宝箱！")
        -- PopupTipPanel.ShowTip(string.format(GetLanguageStrById(50346),itemConfig[_data.drop.itemlist.itemId].Name,_data.drop.itemlist.itemNum))
    elseif _data.pathType==2 then --双倍节点
        PopupTipPanel.ShowTip(GetLanguageStrById(50346))
    elseif _data.pathType==3 then --额外骰子节点
        PopupTipPanel.ShowTip(GetLanguageStrById(50347))
        saiNum=2
    elseif _data.pathType==4 then --东海寻仙节点    
        targetBtn=this.shopBtn
        PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(XiaoYaoManager.curMapId),tostring(1)),1)
        XiaoYaoManager.CheckRedPoint2()
        this.SetEventBtn(_data) 
    elseif _data.pathType==5 then --怪物节点
        targetBtn=this.bossBtn 
        PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(XiaoYaoManager.curMapId),tostring(3)),1)
        XiaoYaoManager.CheckRedPoint2()                   
        this.SetEventBtn(_data)      
    elseif _data.pathType==6 then --转盘
        targetBtn=this.rouleBtn  
        PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(XiaoYaoManager.curMapId),tostring(2)),1)
        XiaoYaoManager.CheckRedPoint2()
        this.SetEventBtn(_data)
    elseif _data.pathType==7 then --终极大奖
        UIManager.OpenPanel(UIName.XiaoYaoEventPanel,0,_data.drop)
    end      
    -- 除普通节点都播放提示音    
    -- if _data.pathType ~= 0 then
    --     SoundManager.PlaySound(SoundConfig.Sound_UI_TiShi)
    -- end
    if _data.drop.itemlist and #_data.drop.itemlist > 0 and _data.pathType~=7 then
        local content = {}
        for i = 1, #_data.drop.itemlist do            
            local itemdata = {}
            itemdata.configData = itemConfig[_data.drop.itemlist[i].itemId]
            itemdata.name = GetLanguageStrById(itemdata.configData.Name)
            itemdata.icon = Util.LoadSprite(GetResourcePath(itemdata.configData.ResourceID))
            itemdata.num = _data.drop.itemlist[i].itemNum
            table.insert(content, itemdata)
        end
        PopupText(content, 0.5, 2)
    end
end

function this.SetEventBtn(_data)
    this.RefreshEventBtn()  
    if isAutoRun then
        this.PlayEffect()
        if allGridData[curGridIndex].eventData  then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(50348),GetLanguageStrById(allGridData[curGridIndex].eventData.Desc)))
        end
    else
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(50348),GetLanguageStrById(allGridData[curGridIndex].eventData.Desc)))
        -- UIManager.OpenPanel(UIName.XiaoYaoEventPanel,_data.pathType,allGridData[curGridIndex].eventData)
    end             
end
function this.PlayEffect()
    -- this.moneyEffect.transform.position =this.TT.transform.position
    -- Util.ClearTrailRender(this.moneyEffect)
    -- this.moneyEffect:SetActive(true)
    -- this.moneyEffect:GetComponent("RectTransform"):DOMove(targetBtn.transform.position, 0.6, false):OnComplete(function ()
    --     -- 这些该死的延迟动画
    --     if isPlayMove==1 then return end
    --     if this.moneyEffect then
    --         this.moneyEffect:SetActive(false)
    --     end
    -- end)
    SoundManager.PlaySound(SoundConfig.Sound_FightArea_Gold)
end
--界面打开时调用（用于子类重写）
function this:OnOpen(_mapData)
    this.RefreshXiaoYaoPanel(_mapData)
    
end
function this.GetMapList()
    XiaoYaoManager.OpenXiaoYaoMapPanel(6001,function(_mapData)
        this.RefreshXiaoYaoPanel(_mapData)
    end)
end
function this.RefreshXiaoYaoPanel(_mapData)
    allEffect = {}
    mapData=_mapData
    this.InitShowEvent()
    --初始化地图
    for i = 1, #mapData.cell do    
        local x, y=Map_Pos2UV(mapData.cell[i].cellId)            
        allGridData[i]={}
        allGridData[i].x=x*128-64
        allGridData[i].y=-y*128+64        
        if mapData.cell[i].pointId>0 then
            allGridData[i].eventData = ConfigManager.GetConfigData(ConfigName.MapPointConfig,mapData.cell[i].pointId)
            if allGridData[i].eventData.Icon==30 then
                allGridData[i].rewardId =mapData.cell[i].rewardId
            end        
        end                
    end
    Log("当前地图格子数量"..this.gridParent.transform.childCount)
    local dataCount=#allGridData
    local createCount=#allGridData-this.gridParent.transform.childCount
    for i = 1,createCount do
        newObjToParent(this.grid, this.gridParent.transform)               
    end
    local gridCount=this.gridParent.transform.childCount
    for i = 1, gridCount do
        local obj=this.gridParent.transform:GetChild(i-1)
        allEffect[i] = Util.GetGameObject(obj.gameObject,"UI_Effect_XiaoYaoYao-ShiJianDian") 
        allEffect[i].gameObject:SetActive(false)
        if i<dataCount then
            obj.gameObject:SetActive(true)
            obj.transform:DOAnchorPos(Vector3(allGridData[i].x,allGridData[i].y,0),0) 
            local eventObj=Util.GetGameObject(obj.gameObject,"eventPoint")                 
            if allGridData[i].eventData then
                eventObj:SetActive(true)
                if allGridData[i].rewardId then                   
                    local rewardData=ConfigManager.GetConfigData(ConfigName.RewardGroup,allGridData[i].rewardId)
                    local itemConfig=ConfigManager.GetConfigData(ConfigName.ItemConfig,rewardData.ShowItem[1][1])
                    Util.GetGameObject(eventObj,"icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
                    Util.GetGameObject(eventObj,"name"):GetComponent("Text").text=SubString2(GetLanguageStrById(itemConfig.Name),7)
                else
                    Util.GetGameObject(eventObj,"icon"):GetComponent("Image").sprite=Util.LoadSprite(allGridData[i].eventData.EventPointBg)
                    Util.GetGameObject(eventObj,"name"):GetComponent("Text").text= SubString2(GetLanguageStrById(allGridData[i].eventData.Desc),7)
                end
            else
                eventObj:SetActive(false)
            end
        else
            obj.gameObject:SetActive(false)
        end
    end
    this.TTPlayIcon.sprite=GetPlayerHeadSprite(PlayerManager.head)
    curGridIndex=mapData.location
    this.LoadTT()    
    Log("当前位置索引："..curGridIndex)
    Log(allGridData[curGridIndex])
    this.TT.transform:DOAnchorPos(Vector3(allGridData[curGridIndex].x,allGridData[curGridIndex].y,0),0)
    this.TT.transform:SetAsLastSibling()
    this.MapMove(allGridData[curGridIndex].x,0)
    local mapConfig=ConfigManager.GetConfigDataByKey(ConfigName.FreeTravel,"MapID",XiaoYaoManager.curMapId)
    -- this.mapName.text= GetLanguageStrById(mapConfig.FreeTravelName)
    this.mapProcess.text=string.format(GetLanguageStrById(12008),(curGridIndex/#allGridData*100))
    local mapBg = mapConfig.MapImage
    costNum=mapConfig.Consume[2]
    Log("当前地图id："..XiaoYaoManager.curMapId)
    --实例化地图背景
    for i = 1, #mapBg do
        Log(mapBg[i])
        this.mapParent.transform:GetChild(i-1):GetComponent("Image").sprite=Util.LoadSprite(mapBg[i])
    end    
    LogGreen(#allEffect)
    for i = 1, #allEffect do
        Util.SetParticleSortLayer(allEffect[i], cursortingOrder+1)
    end 
end
local npc
local scale
---加载跑图角色
function this.LoadTT()
    -- local mapNpc = "live2d_npc_map"
    -- local mapNpc2 = "live2d_npc_map_nv" 
    -- npc = NameManager.roleSex == ROLE_SEX.BOY and mapNpc or mapNpc2
    -- scale = NameManager.roleSex == ROLE_SEX.BOY and Vector3.one * 0.25 or Vector3.one * 0.12
    -- if not this.liveNode then
    --     this.liveNode = poolManager:LoadLive(npc, this.TT.transform, scale, Vector3.New(0,-42.4,0))
    -- end   
    -- this.SkeletonGraphic = this.liveNode:GetComponent("SkeletonGraphic")
    -- if this.SkeletonGraphic then
    --     this.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)           
    -- end
    -- if this.liveNode then
    --     this.liveNode:OnClose()
    -- end
    -- this.liveNode = SubUIManager.Open(SubUIConfig.PlayerLiveView, this.TT.transform)
    -- this.liveNode:OnOpen(GetPlayerRoleSingleConFig().Scale13,Vector3.New(0,-30,0),WALK_DIR.IDLE_FRONT)
end
--设置跑图角色方向
function this.SetTTDirection()
    if not this.liveNode then                    
        return
    end
    local nexIndex=curGridIndex+1
    if nexIndex>#allGridData then
        -- this.SkeletonGraphic.AnimationState:SetAnimation(0, "touch", true)  
        -- this.liveNode:SetWalkDir(WALK_DIR.TOUCH)
        return
    end
    if allGridData[curGridIndex].y==allGridData[nexIndex].y then
        -- this.SkeletonGraphic.AnimationState:SetAnimation(0, "move2", true) 
        if allGridData[curGridIndex].x<allGridData[nexIndex].x  then            
            -- this.SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, 0, 0)   
            -- this.liveNode:SetWalkDir(WALK_DIR.RUN_RIGHT)  
        else
            -- this.SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, 180, 0)  
            -- this.liveNode:SetWalkDir(WALK_DIR.RUN_LEFT)   
        end  
    elseif allGridData[curGridIndex].x==allGridData[nexIndex].x then
        if allGridData[curGridIndex].y<allGridData[nexIndex].y  then            
            -- this.SkeletonGraphic.AnimationState:SetAnimation(0, "move3", true)     
            -- this.liveNode:SetWalkDir(WALK_DIR.RUN_UP)       
        else
            -- this.SkeletonGraphic.AnimationState:SetAnimation(0, "move", true)    
            -- this.liveNode:SetWalkDir(WALK_DIR.RUN_DOWN)         
        end        
    end    
end
--初始化地图事件显示
function this.InitShowEvent()    
    
    if mapData.diceNum>1 then  --骰子x2
        saiNum=mapData.diceNum
    end
    this.RefreshEventBtn()
    if not eventTimer then
        eventTimer=this.DownTime()
    end
end
--刷新界面事件入口按钮显示隐藏
function this.RefreshEventBtn()
    this.bossRedPoint:SetActive(XiaoYaoManager.CheckRedPoint(XiaoYaoManager.curMapId,3))
    --LogGreen("3:"..tostring(XiaoYaoManager.CheckRedPoint(XiaoYaoManager.curMapId,3)))
    this.rouleRedPoint:SetActive(XiaoYaoManager.CheckRedPoint(XiaoYaoManager.curMapId,2))  
    --LogGreen("2:"..tostring(XiaoYaoManager.CheckRedPoint(XiaoYaoManager.curMapId,2)))
    this.shopRedPoint:SetActive(XiaoYaoManager.CheckRedPoint(XiaoYaoManager.curMapId,1))
    --LogGreen("1"..tostring(XiaoYaoManager.CheckRedPoint(XiaoYaoManager.curMapId,1)))
    if XiaoYaoManager.luckyluckyTurnTableTimes > 0 and (XiaoYaoManager.luckyluckyTurnTableRemainTime - PlayerManager.serverTime > 0) then
        this.rouleBtn:SetActive(true)
    else
        this.rouleBtn:SetActive(false)
    end
    local temp = XiaoYaoManager.GetMonsterDatas()
    if temp and #temp > 0  then
        this.bossBtn:SetActive(true)
    else
        this.bossBtn:SetActive(false)
    end      
    local temp = XiaoYaoManager.GetHeroDatas()
    if temp and #temp > 0  then
        this.shopBtn:SetActive(true)
    else
        this.shopBtn:SetActive(false)
    end  
    heroNum,shopLeftTime=XiaoYaoManager.GetHeroDataTime()
    rouleNum,rouleLeftTime=XiaoYaoManager.luckyluckyTurnTableTimes,XiaoYaoManager.luckyluckyTurnTableRemainTime
    bossNum,bossLeftTime=XiaoYaoManager.GetMonsterDataReMainTimesAndTime()
    this.shopNum.text=tostring(heroNum)
    this.rouleNum.text=tostring(rouleNum)
    this.bossNum.text=tostring(bossNum)

    Log(string.format("boss个数：%d，boss时间：%d",bossNum,bossLeftTime))

    if not eventTimer then
        eventTimer=this.DownTime()
    end

end

--控制地图移动
function this.MapMove(curX,moveTime)   
    if curX>2700 and this.mapParent:GetComponent("RectTransform").localPosition.x<=-2200 then
       return
    end    
    if curX>540  then
        this.mapParent.transform:DOAnchorPos(Vector3(540-curX,this.mapY,0),moveTime)
    else
        this.mapParent.transform:DOAnchorPos(Vector3(0,this.mapY,0),moveTime)
    end
end

--刷新云游值显示栏信息
function this.UpdateYunYouVleShow()
    this.costInfo.text=string.format("%d/%d",BagManager.GetItemCountById(UpViewRechargeType.YunYouVle),PrivilegeManager.GetPrivilegeNumber(40))
end

-- 逍遥点是否显示倒计时
function this.ShowCountTime()
    this.costIcon.sprite=Util.LoadSprite(GetResourcePath(itemConfig[UpViewRechargeType.YunYouVle].ResourceID))
    local curValue=BagManager.GetItemCountById(UpViewRechargeType.YunYouVle)
    local maxValue=PrivilegeManager.GetPrivilegeNumber(40)
    this.costInfo.text=string.format("%d/%d",curValue,maxValue)
    this.bgTime:SetActive(curValue<maxValue)
    if this.timer then 
        this.timer:Stop()
    end
    this.timer = nil
    this.actCountTime.text = ""
    -- 启动倒计时
    this.timer = Timer.New(function ()
        local leftTime = AutoRecoverManager.GetRecoverTime(UpViewRechargeType.YunYouVle)
        local curValue=BagManager.GetItemCountById(UpViewRechargeType.YunYouVle)
        this.bgTime:SetActive(curValue<maxValue)
        this.UpdateYunYouVleShow()
        if curValue>=maxValue then
            -- 回复满了，在地图外面可以停止计时器
            this.actCountTime.text = ""
        else  
            this.actCountTime.text = GetTimeMaoHaoStrBySeconds(math.floor(leftTime))
        end
    end, 1, -1, true)
    this.timer:Start()
end

function this.DownTime()
    local _timer
    _timer = Timer.New(function ()
        local couTime = 0
        if this.shopBtn.activeSelf then
            couTime =shopLeftTime- PlayerManager.serverTime        
            if couTime<=0 then
                -- 倒计时结束
                this.shopBtn:SetActive(false)       
                PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(XiaoYaoManager.curMapId),tostring(1)),0)    
                XiaoYaoManager.CheckRedPoint2()         
            else
                this.shopTime.text = TimeToHMS(math.floor(couTime))
            end
        end

        if this.rouleBtn.activeSelf then
            couTime =rouleLeftTime- PlayerManager.serverTime        
            if couTime<=0 then
                -- 倒计时结束
                this.rouleBtn:SetActive(false)          
                PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(XiaoYaoManager.curMapId),tostring(2)),0)   
                XiaoYaoManager.CheckRedPoint2() 
            else
                this.rouleTime.text = TimeToHMS(math.floor(couTime))
            end
        end

        if this.bossBtn.activeSelf then
            couTime =bossLeftTime- PlayerManager.serverTime        
            if couTime<=0 then
                -- 倒计时结束
                this.bossBtn:SetActive(false)  
                PlayerPrefs.SetInt(string.format("%s#%s#%s",PlayerManager.uid,tostring(XiaoYaoManager.curMapId),tostring(3)),0)     
                XiaoYaoManager.CheckRedPoint2()     
            else            
                this.bossTime.text = TimeToHMS(math.floor(couTime))
            end
        end

    end, 1, -1, true)
    _timer:Start()
    return _timer
end

function this:OnShow()
     --显示资源条
    this._PlayTimeStamp = 0
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.MonsterCamp })        
    this.ShowCountTime()
    this.startBtn:SetActive(true)
    this.isStart:SetActive(false)
    isAutoRun=false
    isPlayMove=0
    this.startBtn:GetComponent("Button").enabled=true
    isAuto=XiaoYaoManager.isAutoYouli
    this.toggle.gameObject:SetActive(isAuto)
end

function this:OnSortingOrderChange()
    --LogGreen("self.sortingOrder:"..self.sortingOrder)
    -- Util.AddParticleSortLayer(this.moneyEffect, self.sortingOrder - cursortingOrder)
    for i = 1, #allEffect do
        Util.AddParticleSortLayer(allEffect[i], self.sortingOrder - cursortingOrder)
    end 
    cursortingOrder = self.sortingOrder 
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    this.rouleBtn:SetActive(false)
    this.bossBtn:SetActive(false)
    this.shopBtn:SetActive(false)
    this.StopAuto()
    isPlayMove=1
    -- if this.liveNode then
    --     poolManager:UnLoadLive(npc, this.liveNode)
    --     this.liveNode = nil
    -- end  
    -- if this.liveNode then
    --     this.liveNode:OnClose()
    -- end 
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    for i = 1, #allEffect do
       if allEffect[i] then
        allEffect[i].gameObject:SetActive(false)
       end
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy() 
    -- this.spLoader:Destroy()
    if eventTimer then
        eventTimer:Stop()
        eventTimer = nil
    end
    -- if this.liveNode then
    --     poolManager:UnLoadLive(npc, this.liveNode)
    --     this.liveNode = nil
    -- end 
    allEffect = {} 
end
return XiaoYaoMapPanel