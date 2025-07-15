require("Base/Stack")
require("Modules/Map/Logic/TileMapController")
require("Modules/Map/Logic/TileMapView")
require("Modules/Guild/View/GuildMemberView")

local _GuildBuildConfig = {
    [GUILD_MAP_BUILD_TYPE.HOUSE] = {
        bgImg = "r_gonghui_qizhi",
        nameImg = "r_gonghui_dating",
        pos = Vector3.New(1300, -300, 0),
        namePos = Vector3.New(0, 13.4, 0),
        rpType = RedPointType.Guild_House,
        rpPos = Vector3.New(38, 136, 0),
    },
    [GUILD_MAP_BUILD_TYPE.LOGO] = { --图腾
        bgImg = "r_gonghui_qizhi",
        nameImg = "r_gonghui_tuteng",
        pos = Vector3.New(848, -300, 0),
        namePos = Vector3.New(0, 13.4, 0),
    },
    [GUILD_MAP_BUILD_TYPE.STORE] = {
        bgImg = "r_gonghui_qizhi",
        nameImg = "r_gonghui_shangdian",
        pos = Vector3.New(1398, -897, 0),
        namePos = Vector3.New(0, 13.4, 0),
        rpType = RedPointType.Guild_Shop,
        rpPos = Vector3.New(38, 136, 0),
    },
    -- [GUILD_MAP_BUILD_TYPE.DOOR] = { --公会战
    --     bgImg = "r_gonghui_qizhi",
    --     nameImg = "r_gonghui_zhao",
    --     pos = Vector3.New(1344, -1344, 0),
    --     namePos = Vector3.New(0, 13.4, 0),
    -- },
    [GUILD_MAP_BUILD_TYPE.LOGO_IMG] = {
        bgImg = "gh_tt_1",
        nameImg = nil,
        pos = Vector3.New(495, -750, 0),
    },
    -- [GUILD_MAP_BUILD_TYPE.BOSS] = { --试练
    --     bgImg = "r_gonghui_qizhi",
    --     pos = Vector3.New(1821, -164, 0),
    --     color = Color.New(0,0,0,0),
    --     nameImg = "r_gonghui_shouling",
    --     namePos = Vector3.New(0, -84, 0),
    --     rpType = RedPointType.Guild_Boss,
    --     rpPos = Vector3.New(75, -64, 0),
    --     liveName = "live2d_huyao",
    --     livePos = Vector3.New(0, -84, 0),
    --     liveScale = Vector3.New(0.15, 0.15, 0.15),
    -- },
    [GUILD_MAP_BUILD_TYPE.FETE] = { --祭祀
        bgImg = "r_gonghui_qizhi",
        nameImg = "r_gonghui_jisi",
        pos = Vector3.New(2428, -336, 0),
        namePos = Vector3.New(0, 13.4, 0),
        rpType = RedPointType.Guild_Fete,
        rpPos = Vector3.New(38, 136, 0),
    },
    [GUILD_MAP_BUILD_TYPE.TENPOS] = { --十绝阵
        bgImg = "r_gonghui_qizhi",
        nameImg = "r_gonghui_shijiezhen",
        pos = Vector3.New(687, -765, 0),
        namePos = Vector3.New(0, 13.4, 0),
        rpType = RedPointType.Guild_DeathPos,
        rpPos=Vector3.New(37.8,136.3,0)
    },
    [GUILD_MAP_BUILD_TYPE.SKILL] = { --技能
        bgImg = "r_gonghui_qizhi",
        nameImg = "r_gonghui_jineng",
        pos = Vector3.New(566, -158, 0),
        namePos = Vector3.New(0, 13.4, 0),
        rpType = RedPointType.Guild_Skill,
        rpPos = Vector3.New(53, 137, 0),
    },
    -- [GUILD_MAP_BUILD_TYPE.CARDELAY] = { --车迟斗法
    --     bgImg = "r_gonghui_qizhi",
    --     nameImg = "r_gonghui_chechidoufa",
    --     pos = Vector3.New(2626, -761, 0),
    --     namePos = Vector3.New(0, 13.4, 0),
    --     rpType = RedPointType.Guild_CarDeleay,
    --     rpPos = Vector3.New(53, 137, 0),
    -- },
    -- [GUILD_MAP_BUILD_TYPE.AID] = { --援助
    --     bgImg = "r_gonghui_qizhi",
    --     nameImg = "r_gonghui_yuanzhu",
    --     pos = Vector3.New(1979, -504, 0),
    --     namePos = Vector3.New(0, 13.4, 0),
    --     rpType = RedPointType.Guild_Aid,
    --     rpPos = Vector3.New(53, 137, 0),
    -- },
}

local this = {}

--公会地图数据解析
local function dataParse(str)
    local ss = string.split(str, "|")
    local t = {}
    for i=1, #ss do
        local item = ss[i]
        local pss = string.split(item, "#")
        local n = Map_UV2Pos(tonumber(pss[1]), tonumber(pss[2]))
        table.insert(t, n)
    end
    local newStr = "{"
    for i=1, #t do
        if i==#t then
            newStr = newStr .. tostring(t[i]) .. "}"
        else
            newStr = newStr .. tostring(t[i]) .. ","
        end
    end
    return newStr
end

local dataConfig = {
    [2] = {257,513,769,1025,1281,2049,2305,2561,2817,3073,5377,5633,5889,6145,6401,6657,7937,8193,8449,8705,8961,9217,9473,9729,9985,258,514,770,1026,1282,2050,2306,2562,2818,3074,5378,5634,5890,6146,6402,6658,7938,8194,8450,8706,8962,9218,9474,9730,9986,259,515,771,1027,1283,2051,2307,2563,2819,3075,5379,5635,5891,6147,6403,6659,7939,8195,8451,8707,8963,9219,9475,9731,9987,260,516,772,1028,1284,2052,2308,2564,2820,3076,5380,5636,5892,6404,6660,7940,8196,8452,8708,8964,9220,9476,9732,9988,261,517,773,1029,1285,5381,7941,8197,8453,8709,8965,9221,9477,9733,9989,262,518,774,1030,1286,5382,8966,9734,9990,263,519,775,1031,1287,5383,6663,6919,7431,7687,7943,9735,9991,264,520,776,1032,1288,1544,1800,2056,2312,2568,2824,3336,3592,3848,4872,5128,5384,6408,7176,8200,8456,265,521,777,1033,1289,2825,6153,8713,8969,266,522,778,1034,1290,2826,3850,4874,5898,8970,267,523,779,1035,1291,2827,3083,5899,8971,268,524,780,1036,1292,2828,5900,8972,269,525,781,1037,1293,2829,5901,8973,270,526,782,1038,1294,2830,3086,3854,4878,5902,7438,7694,8206,8462,8718,271,527,783,1039,1295,1551,1807,2063,2319,2575,2831,3855,4879,5903,6159,6415,7183,7439,7695,9231,272,528,784,1040,1296,1552,1808,2064,2320,2576,2832,3088,3344,3600,5904,6160,6416,7184,7440,7696,9232,273,529,785,1041,1297,1553,1809,2065,2321,2577,2833,3089,3345,3601,6161,7441,8465,8721,274,530,786,1042,1298,1554,1810,2066,2322,2578,2834,3090,3346,3602,8466,8722,275,4883,6419,8467,8723,276,3860,4884,6420,8468,8724,277,3861,4885,7189,8469,8725,278,3862,4886,5142,7190,8470,8726,279,535,791,1047,1303,1559,1815,2071,2327,2583,2839,3095,3351,3607,5143,5399,5655,5911,6167,6423,6679,6935,7191,7447,7703,7959,8215,8471,8727},
    [10] = {3329,3585,3841,4097,4353,4609,4865,5121,3330,3586,3842,4098,4354,4610,4866,5122,3331,3587,3843,4099,4355,4611,4867,5123,3332,3588,3844,4100,4356,4612,4868,5124,3333,3589,3845,4101,4357,4613,4869,5125,3334,3590,3846,4102,4614,4870,5126,3335,3591,3847,4871,5127},
    [20] = {1545,1801,2057,2313,2569,1546,1802,2058,2314,2570,1547,1803,2059,2315,2571,1548,1804,2060,2316,2572,1549,1805,2061,2317,2573,1550,1806,2062,2318,2574},
    [30] = {6664,6920,7432,7688,7944,6409,6665,6921,7177,7433,7689,7945,8201,8457,6154,6410,6666,6922,7178,7434,7690,7946,8202,8458,8714,6155,6411,6667,6923,7179,7435,7691,7947,8203,8459,8715,6156,6412,6668,6924,7180,7436,7692,7948,8204,8460,8716,6157,6413,6669,6925,7181,7437,7693,7949,8205,8461,8717,6158,6414,6670,6926,7182},
    [40] = {4372,4117,4373,4629,4118,4374,4630,3863,4119,4375,4631,4887},
}

local mapConfig = ConfigManager.GetConfigData(ConfigName.ChallengeMapConfig, 11)

local funcCanPass = function(data) return data.val < 1 end
local selfAgentView = {agent = nil, callList = Stack.New()}
local otherAgentViews = {}

local curTargetPos
local targetPos
local isWalking = true

local mapCtrl = "MapCtrl"
--local mapPointEventPool = {}
local flagEventPool = {}

local function clear(agentView)
    local call = agentView.callList
    if agentView.tweener then
        agentView.tweener:Kill()
    end
    call:Clear()
end

local function move(pathList, agentView, isSelf, finalU, finalV)
    local call = agentView.callList
    local agent = agentView.agent
    
    clear(agentView)
    
    --把最终回调最先入栈
    call:Push(function ()
        if isSelf then
            -- 避免连续点击时，多个动画异步运行，导致卡死的问题
            isWalking = true
        end
        agent:PlayerIdle()
    end)
   
    call:Push(function ()
        local len = #pathList
        if len < 1 then return end

        if agentView.tweener then
            agentView.tweener:Kill()
        end

        local Bezier = require("Base.Bezier")
        local plist = {}
        local pv3 = TileMapView.GetLiveTilePos(finalU, finalV)
    
        local startV2 = Vector2.New(agent.leader.transform.localPosition.x, agent.leader.transform.localPosition.y)
        local endV2 = Vector2.New(pv3.x, pv3.y)

        if len > 1 then
            for i=#pathList-1, 2, -1 do
                local data = pathList[i]
                pv3 = TileMapView.GetLiveTilePos(data.u, data.v)
                pv3.z = -data.v
                table.insert(plist, Vector2.New(pv3.x, pv3.y))
            end
        end

        --飞行子弹轨迹
        agentView.tweener = DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 0 end),
        DG.Tweening.Core.DOSetter_float(function (progress)
            if not isSelf then return end
            --该标记监听拖动，当正在处理栈事件时，镜头默认居中跟随，此时拖动界面可以打断镜头跟随
            if this.DragFlag then return end
            
            local lp = Bezier.GetUniformProcess(progress, startV2, endV2, plist)
            local v2 = Bezier.CalPos(lp, startV2, endV2, plist)
            local dir = Bezier.CalDir(lp, startV2, endV2, plist)
            agent:SetRoleDirAction(dir.x, dir.y)
            agent.leader.transform.localPosition = Vector3.New(v2.x, v2.y, agent.leader.transform.localPosition.z)
                                    
            local v3 = agent.leader.transform.localPosition -- 摄像头跟随
            v3.z = TileMapView.ViewCameraPos.z
            TileMapView.SetCameraPos(v3)
            TileMapView.UpdateBaseData()
        end), 1, #pathList*0.2):SetEase(Ease.Linear):OnComplete(function ()
            if call:Count() < 1 then
                if isSelf then
                    -- 避免连续点击时，多个动画异步运行，导致卡死的问题
                    isWalking = true
                end
                return
            end
            agent:RefreshPos(math.round(finalU), math.round(finalV))
            if isSelf then
                -- TileMapView.ClearPathTile(data.u, data.v)
                isWalking = true
            end
            call:Pop()()  
        end)

        -- local plist = {}  --TODO：dotween dopath方案
        -- table.insert(plist, agent.leader.transform.localPosition)
        -- for i=#pathList-1, 2, -1 do
        --     local data = pathList[i]
        --     table.insert(plist, TileMapView.GetLiveTilePos(data.u, data.v))
        -- end
        -- table.insert(plist, TileMapView.GetLiveTilePos(finalU, finalV))
        -- local lastV3 = agent.leader.transform.localPosition
        -- agentView.tweener = agent.leader.transform:DOLocalPath(plist, #pathList*0.2, DG.Tweening.PathType.CatmullRom):OnUpdate(function ()
        --     if not isSelf then return end
        --     --该标记监听拖动，当正在处理栈事件时，镜头默认居中跟随，此时拖动界面可以打断镜头跟随
        --     if this.DragFlag then return end

        --     local dir = agent.leader.transform.localPosition - lastV3
        --     agent:SetRoleDirAction(dir.x, dir.y)
        --     lastV3 = agent.leader.transform.localPosition
                                    
        --     local v3 = agent.leader.transform.localPosition -- 摄像头跟随
        --     v3.z = TileMapView.ViewCameraPos.z
        --     TileMapView.SetCameraPos(v3)
        --     TileMapView.UpdateBaseData()
        -- end):SetEase(Ease.Linear):OnComplete(function ()
        --     if call:Count() < 1 then
        --         if isSelf then
        --             -- 避免连续点击时，多个动画异步运行，导致卡死的问题
        --             isWalking = true
        --         end
        --         return
        --     end
        --     agent:RefreshPos(math.round(finalU), math.round(finalV))
        --     if isSelf then
        --         -- TileMapView.ClearPathTile(data.u, data.v)
        --         isWalking = true
        --     end
        --     call:Pop()()  
        -- end)

        if isSelf then
            isWalking = false
        end
    end)

    -- for i=1, #pathList do
    --     local data = pathList[i]
    --     local v3
    --     if i == 1 then
    --         v3 = TileMapView.GetLiveTilePos(finalU, finalV)
    --     else
    --         v3 = TileMapView.GetLiveTilePos(data.u, data.v)
    --     end
    --     v3.z = -data.v

    --     call:Push(function ()
    --         agent:SetRoleDirAction(data.u, data.v)
    --         -- 避免连续点击创建多个动画
    --         if agentView.tweener then
    --             agentView.tweener:Kill()
    --         end
    --         
    --         local time = 0.2
    --         -- 最后一步需要重新计算时间
    --         if i == 1 then
    --             local distance = math.distanceXY(agent.leader.transform.localPosition, v3)
    --             time = time*distance/0.64
    --         end
    --         agentView.tweener = agent.leader.transform:DOLocalMove(v3, time, false):OnUpdate(function()
    --             if not isSelf then return end
    --             --该标记监听拖动，当正在处理栈事件时，镜头默认居中跟随，此时拖动界面可以打断镜头跟随
    --             if this.DragFlag then return end
    --             -- 摄像头跟随
    --             local v3 = agent.leader.transform.localPosition
    --             v3.z = TileMapView.ViewCameraPos.z
    --             TileMapView.SetCameraPos(v3)
    --             TileMapView.UpdateBaseData()
    --         end):OnComplete(function ()
    --             if call:Count() < 1 then
    --                 if isSelf then
    --                     -- 避免连续点击时，多个动画异步运行，导致卡死的问题
    --                     isWalking = true
    --                 end
    --                 return
    --             end
    --             agent:RefreshPos(data.u, data.v)
    --             if isSelf then
    --                 TileMapView.ClearPathTile(data.u, data.v)
    --                 isWalking = true
    --             end
    --             call:Pop()()
    --         end):SetEase(Ease.Linear)

    --         if isSelf then
    --             isWalking = false
    --         end
    --     end)
    -- end

    if isSelf then
        call:Push(function ()
            local data = selfAgentView.agent.posData
            local v3 = TileMapView.GetLiveTilePos(data.u, data.v)
            v3.z = TileMapView.ViewCameraPos.z
            if TileMapView.ViewCameraPos ~= v3 then
                TileMapView.CameraTween(data.u, data.v, 0.5, function ()
                    TileMapView.ClearPathTile(data.u, data.v)
                    if call:Count() > 0 then
                        call:Pop()()
                    end
                end)
                this.DragFlag = false
            else
                TileMapView.ClearPathTile(data.u, data.v)
                if call:Count() > 0 then
                    call:Pop()()
                end
            end
        end)
    end

    if call:Count() > 0 then
        call:Pop()()
    end
end

local function update()
    -- 点击同一个点时不再请求行走，优化快速点击鬼畜效果
    -- if targetPos and curTargetPos and targetPos.u == curTargetPos.u and targetPos.v == curTargetPos.v then
    --     targetPos = nil
    --     return
    -- end
    -- 避免快速点击进入公会地图，人物还没创建完成，就触发点击事件的问题
    if not selfAgentView.agent then
        return
    end
    --
    if targetPos and isWalking then
        isWalking = false
        
        local posData = selfAgentView.agent.posData
        local pathList = TileMapView.ShowPath(posData.u, posData.v, targetPos.u, targetPos.v, funcCanPass)
        TileMapView.ClearPath()
        if pathList then
            table.reverse(pathList,1, #pathList)
            -- 重新构建数据，避免引用类型数据改变时导致数据异常的问题
            local list = {}
            for _, path in ipairs(pathList) do
                table.insert(list, {u = path.u, v = path.v})
            end
            -- 判断路径的最终点是否是目标点，不是不需要覆盖uv数据
            local len = #list
            if list[len].u == targetPos.u and list[len].v == targetPos.v then 
                list[#list].u = targetPos._u
                list[#list].v = targetPos._v
            end
            
            MyGuildManager.RequestWalk(list, function ()
                --table.reverse(pathList, 1, #pathList)
                --table.remove(pathList, #pathList)
                --move(pathList, selfAgentView, true)
                -- 避免连续点击时，服务器会出现不发送indication，导致卡死的问题
                --  isWalking = true
            end)
            -- 保存数据
            curTargetPos = targetPos
        -- 同一格子内的不同位置    
        elseif not pathList    -- 没有寻路路径
            and (posData._u ~= targetPos._u or posData._v ~= targetPos._v)  -- 当前位置和目标位置不是统一位置
            and posData.u == targetPos.u and posData.v == targetPos.v then   -- 在同一个单元格内
            pathList = {
                {u = posData.u, v = posData.v},
                {u = targetPos._u, v = targetPos._v},
            }
            MyGuildManager.RequestWalk(pathList, function ()
                -- isWalking = true
            end)
            -- 保存数据
            curTargetPos = targetPos
        else
            isWalking = true
            
        end
        targetPos = nil
    end
end 

function this.InitComponent(gameObject)
    this.DragCtrl = Util.GetGameObject(gameObject, "Ctrl")
    -- local test = dataParse("17#20|16#21|17#21|18#21|16#22|17#22|18#22|15#23|16#23|17#23|18#23|19#23")
    
end

function this.AddListener()
    UpdateBeat:Add(update, this)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.WalkUpdate, this.OnMove)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.KickOut, this.RemoveMem)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.MemberDataUpdate, this.OnPosUpdate)
end

function this.RemoveListener()
    UpdateBeat:Remove(update, this)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.WalkUpdate, this.OnMove)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.KickOut, this.RemoveMem)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.MemberDataUpdate, this.OnPosUpdate)
end

function this.Init()
    UIManager.camera.clearFlags = CameraClearFlags.Depth

    
    this.Ctrl = poolManager:LoadAsset(mapCtrl, PoolManager.AssetType.GameObject)
    this.Ctrl.name = mapCtrl
    this.Ctrl.transform:SetParent(UIManager.uiRoot.transform.parent)
    this.Ctrl.transform.position = Vector3.New(0, 0, -100)

    TileMapView.OnInit = this.OnInit
    TileMapView.fogSize = 2
    TileMapView.AwakeInit(this.Ctrl, 11, nil, Vector2.New(64, 64))
    TileMapView.isShowFog = false

    TileMapController.IsShieldDrag = function()
        --当栈中有逻辑，则拖动可以打断镜头跟随
        this.DragFlag = selfAgentView.callList:Count() > 1
        return false
    end
    TileMapController.OnClickTile = this.OnClickTile
    TileMapController.Init(this.Ctrl, this.DragCtrl)

    TileMapView.Init()

    -- 加载旗子
    this._BuildFlag = {}
    this._FlagRedpot = {}
    this._FlagLive = {}
    for buildType, config in pairs(_GuildBuildConfig) do
        local go = poolManager:LoadAsset("GuildBuildFlag", PoolManager.AssetType.GameObject)
        go.transform:SetParent(Util.GetTransform(this.Ctrl, "uiObj#"))
        go.name = "GuildBuildFlag"
        --go:GetComponent("Image").sprite = Util.LoadSprite(config.bgImg)
        go:GetComponent("Image").color = config.color or Color.New(1, 1, 1, 1)
        go:GetComponent("Image"):SetNativeSize()
        go:SetActive(true)
        go:GetComponent("RectTransform").anchoredPosition3D = config.pos
        go.transform.localScale = Vector3.one

        this._BuildFlag[buildType] = go

        local img = Util.GetGameObject(go, "Image")
        img:SetActive(config.nameImg ~= nil)
        if config.nameImg then
            img:GetComponent("Image").sprite = Util.LoadSprite(config.nameImg)
            -- img:GetComponent("Image"):SetNativeSize()
            img:GetComponent("RectTransform").anchoredPosition3D = config.namePos or Vector3.New(0,0,0)
        end

        local liveRoot = Util.GetGameObject(go, "liveRoot")
        if not this._FlagLive[buildType] then
            if config.liveName then
                this._FlagLive[buildType] = poolManager:LoadLive(config.liveName, liveRoot.transform, config.liveScale, config.livePos)
                local SkeletonGraphic = this._FlagLive[buildType]:GetComponent("SkeletonGraphic")
                local idle = function()
                    SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
                end
                SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
                SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
                poolManager:SetLiveClearCall(config.liveName, this._FlagLive[buildType], function()
                    SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
                end)
            end
        else
            this._FlagLive[buildType].transform:SetParent(liveRoot.transform)
            this._FlagLive[buildType].transform.anchoredPosition3D = config.livePos or Vector3.New(0,0,0)
            this._FlagLive[buildType].transform.localScale = config.liveScale or Vector3.one
        end


        local redpot = Util.GetGameObject(go, "redpot")
        redpot:SetActive(false)
        if config.rpType then
            BindRedPointObject(config.rpType, redpot)
            this._FlagRedpot[config.rpType] = redpot
        end
        if config.rpPos then
            redpot.transform.localPosition = config.rpPos
        end
    end

    for k,v in pairs(dataConfig) do
        for i=1, #v do --设置地图数据
            TileMapView.GetTileData(Map_Pos2UV(v[i])).val = k
        end
    end

    --mapPointEventPool = {}
    flagEventPool = {}
end

local typeState={} --旗子类型 状态容器（用于当有多个旗子需要设置状态的存储容器）
--设置旗子的显隐 type公会地图建筑类型 b bool （每次只能设置一个旗子）
function this.SetBuildFlagShow(type,b)
    for buildType, config in pairs(_GuildBuildConfig) do
        if type==buildType then
            table.insert(typeState,{type=type,b=b})
            this._BuildFlag[buildType].gameObject:SetActive(b)
        end
    end
end

-- 初始化玩家行走数据
function this.InitWalkData()
    local datas = MyGuildManager.GetMemWalkData()
    if datas then
        for k, v in pairs(datas) do
            
            
            
            if k == PlayerManager.uid then
                isWalking = true
                clear(selfAgentView)

                local gPos = MyGuildManager.GetMyPositionInGuild() -- 获取职位
                selfAgentView.agent = GuildMemberView.New(true, v.curPos, v.name, gPos, v.gender, this.Ctrl)
                TileMapController.LocateToUV(GuildMap_Pos2UV(v.curPos))
                if #v.path then
                    local pathList = {}
                    local finalU, finalV
                    for i=#v.path, 1,-1 do
                        local u1, v1, _u, _v = GuildMap_Pos2UV(v.path[i])
                        table.insert(pathList, TileMapView.GetMapData():GetMapData(u1, v1))
                        -- 最后一个点为最终位置
                        if i == #v.path then
                            finalU, finalV = _u, _v
                        end
                    end
                    move(pathList, selfAgentView, true, finalU, finalV)
                end
            else
                local gPos = MyGuildManager.GetMemInfo(v.uid).position
                otherAgentViews[k] = {
                    agent = GuildMemberView.New(false, v.curPos, v.name, gPos, v.gender, this.Ctrl),
                    callList = Stack.New(),
                }
                clear(otherAgentViews[k])
                if #v.path then
                    local pathList = {}
                    local finalU, finalV
                    for i=#v.path, 1,-1 do
                        local u, v, _u, _v = GuildMap_Pos2UV(v.path[i])
                        table.insert(pathList, TileMapView.GetMapData():GetMapData(u, v))
                        -- 最后一个点为最终位置
                        if i == #v.path then
                            finalU, finalV = _u, _v
                        end
                    end
                    move(pathList, otherAgentViews[k], false, finalU, finalV)
                end
            end
        end
    end
end


-- 增加一个标记点
function this.AddPointFunc(type, clickTipFunc)
    --mapPointEventPool[type * 10] = clickTipFunc
    flagEventPool[type] = clickTipFunc
end
-- 设置公会图腾
function this.SetGuildLogo(logoId)
    local logoImg = this._BuildFlag[GUILD_MAP_BUILD_TYPE.LOGO_IMG]
    if logoImg then
        logoImg:GetComponent("Image").sprite = Util.LoadSprite(GuildManager.GetLogoResName(logoId))
    end
end

function this.OnInit()
end

function this.SelfMove()
end

function this.OnClickTile(u, v, fuv)
    local _u = fuv.x
    local _v = -fuv.y
    if TileMapView.IsOutArea(u, v) then return end
    if this.CheckFlagClick(fuv) or not isWalking then return end
    -- local data = TileMapView.GetTileData(u, v)
    --if mapPointEventPool[data.val] then
    --    mapPointEventPool[data.val]()
    --    return
    --end
    targetPos = {u = u, v = v, _u = _u, _v = _v}
    local selfAgent = selfAgentView.agent
    if not selfAgent then return end    -- 避免快速点击进入公会地图，人物还没创建完成，就触发点击事件的问题
    local posData = selfAgent.posData
    -- 点击角色
    if u == posData.u and v == posData.v then
        selfAgent:OnClick()
        return
    end
end

-- 检测是否点到旗子上
function this.CheckFlagClick(fuv)
    local mousePos = TileMapView.GetLiveTilePos(fuv.x, -fuv.y) * 100
    for type, node in pairs(this._BuildFlag) do
        for i, v in pairs(typeState) do --旗子状态检查 当点击该旗子为未激活状态时 取消点击事件
            if v.type==type and v.b==false then
                return false
            end
        end
        local nPos = node.transform.anchoredPosition3D
        local nRect = node.transform.rect
        local nPivot = node.transform.pivot
        local left = nPos.x + nRect.width * (0 - nPivot.x)
        local right = nPos.x + nRect.width * (1 - nPivot.x)
        local bottom = nPos.y + nRect.height * (0 - nPivot.y)
        local top = nPos.y + nRect.height * (1 - nPivot.y)
        if mousePos.x >= left and mousePos.x <= right
            and mousePos.y >= bottom and mousePos.y <= top then
            if flagEventPool[type] then
                flagEventPool[type]()
                return true
            end
        end
    end
    return false
end

function this.OnMove(msg)
    local pathList = {}
    local finalU, finalV
    for i=#msg.path, 1,-1 do
        local u, v, _u, _v = GuildMap_Pos2UV(msg.path[i])
        table.insert(pathList, TileMapView.GetMapData():GetMapData(u, v))
        -- 最后一个点为最终位置
        if i == #msg.path then
            finalU, finalV = _u, _v
        end
    end
    local curU, curV = GuildMap_Pos2UV(msg.curPos)
    if msg.uid == PlayerManager.uid then
        selfAgentView.agent:RefreshPos(curU, curV)
        move(pathList, selfAgentView, true, finalU, finalV)
    else
        if not otherAgentViews[msg.uid] then
            otherAgentViews[msg.uid] = {
                agent = GuildMemberView.New(false, msg.curPos, msg.name, GUILD_GRANT.MEMBER, msg.gender, this.Ctrl),
                callList = Stack.New(),
            }
            clear(otherAgentViews[msg.uid])
        end
        otherAgentViews[msg.uid].agent:RefreshPos(curU, curV)
        move(pathList, otherAgentViews[msg.uid], false, finalU, finalV)
    end
end

-- 删除角色
function this.RemoveMem(uid)
    if otherAgentViews[uid] then
        clear(otherAgentViews[uid])
        otherAgentViews[uid].agent:Dispose()
        otherAgentViews[uid] = nil
    end
end
-- 角色改变刷新
function this.OnPosUpdate()
    local myPos = MyGuildManager.GetMyPositionInGuild()
    if myPos then
        selfAgentView.agent:SetGuildPos(myPos)
    end
    for uid, agentView in pairs(otherAgentViews) do
        local memData = MyGuildManager.GetMemInfo(uid)
        if memData then
            agentView.agent:SetGuildPos(memData.position)
        end
    end
end

function this.Dispose()
    -- UIManager.camera.clearFlags = CameraClearFlags.Skybox

    TileMapView.Exit()
    TileMapController.Exit()
    poolManager:UnLoadAsset(mapCtrl, this.Ctrl, PoolManager.AssetType.GameObject)
    this.Ctrl = nil
    targetPos = nil

    if selfAgentView.agent then
        clear(selfAgentView)
        selfAgentView.agent:Dispose()
    end
    for k, v in pairs(otherAgentViews) do
        clear(otherAgentViews[k])
        otherAgentViews[k].agent:Dispose()
        otherAgentViews[k] = nil
    end

    -- 解除红点
    if this._FlagRedpot then
        for rpType, redpot in pairs(this._FlagRedpot) do
            ClearRedPointObject(rpType, redpot)
        end
        this._FlagRedpot = nil
    end

    -- 回收旗子前先回收live2d
    for type, live in pairs(this._FlagLive) do
        poolManager:UnLoadLive(_GuildBuildConfig[type].liveName, live)
    end

    -- 旗子回收
    for _, flag in pairs(this._BuildFlag) do
        Util.AddOnceClick(flag, function()end)
        poolManager:UnLoadAsset("GuildBuildFlag", flag, PoolManager.AssetType.GameObject)
    end
    this._BuildFlag = {}
end

return this