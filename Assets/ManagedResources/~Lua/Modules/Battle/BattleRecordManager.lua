BattleRecordManager = {}
local this = BattleRecordManager

local BattleRecordList = {}
local _RecordIdFlag = 0
local _CurRecordId = nil

function this.Initialize()
    --加载相关模块
    BattleRecordList = {}
    _RecordIdFlag = 0
    _CurRecordId = nil

end

local fightMaxRound, seed, battleType, fightData, optionData, bothNameStr
function this.SetBattleRecord(data, _optionData)
    this.isSubmit = true
    -- ID自增
    _RecordIdFlag = _RecordIdFlag + 1
    -- 保存记录
    local record = {
        fightMaxRound= data.maxRound,
        seed = data.fightSeed, 
        battleType = data.fightType, 
        fightData = data.fightData, 
        optionData = _optionData,
        result = -1,
    }
    BattleRecordList[_RecordIdFlag] = record
    -- 设置当前战斗
    _CurRecordId = _RecordIdFlag
    return _CurRecordId
end

-- 清除战斗记录数据
function this.ClearFightData()
    _CurRecordId = nil
end
-- 判断是否有战斗记录
function this.isHaveRecord(Id)
    -- 如果美有参数，判断当前记录是否存在
    if not Id then
        if _CurRecordId then
            Id = _CurRecordId 
        else -- 当前记录也不存在则没有记录
            return false
        end
    end
    -- 获取相应的记录
    if not BattleRecordList[Id] then
        return false
    end
    return true, BattleRecordList[Id]
end
-- 设置战斗双方名字（attackName|defendName）
function this.SetBattleBothNameStr(_bothNameStr, Id)
    local isRecord, record = this.isHaveRecord(Id)
    if isRecord then
        record.bothNameStr = _bothNameStr
    end
end
-- 获取战斗双方名字（attackName|defendName）
function this.GetBattleBothNameStr(Id)
    local isRecord, record = this.isHaveRecord(Id)
    if isRecord then
        return record.bothNameStr
    end
end


--客户端模拟跑战斗逻辑，生成战报数据
function this.GetBattleRecord(Id)
    local isRecord, record = this.isHaveRecord(Id)
    if not isRecord then
        return
    end
    local fightMaxRound = record.fightMaxRound
    local seed = record.seed
    local battleType = record.battleType
    local fightData = record.fightData
    local optionData = record.optionData

    local battleRecord = {}
    Random.SetSeed(seed)
    BattleLogic.Init(fightData, optionData, fightMaxRound)
    BattleLogic.Type = battleType

    BattleLogic.Event:AddEvent(BattleEventName.AddRole, function (role)
        local record = {}
        record.uid = role.uid
        record.roleId = role.roleData.roleId
        record.monsterId = role.roleData.monsterId
        record.roleLv = role:GetRoleData(RoleDataName.Level)
        record.camp = role.camp
        record.damage = 0
        record.heal = 0
        record.type = 0
        record.order = BattleLogic.CurOrder
        if not role.leader then
            role.Event:AddEvent(BattleEventName.RoleDamage, function (defRole, damage, bCrit, finalDmg)
                -- record.damage = record.damage + finalDmg
                record.damage = record.damage + damage  --< 统计也按爆出的伤害算
            end)
       
            role.Event:AddEvent(BattleEventName.RoleTreat, function (targetRole, treat)
                record.heal = record.heal + treat
            end)
        end
        battleRecord[role.uid] = record
    end)

    BattleLogic.StartOrder()
    BattleLogic.SetIsDebug(true)
    while not BattleLogic.IsEnd do
        BattleLogic.Update()
    end
    BattleLogic.SetIsDebug(false)

    record.result = BattleLogic.Result
    return battleRecord
end


function this.GetBattleRecordResult(Id)
    local isRecord, record = this.isHaveRecord(Id)
    if not isRecord then
        return 
    end
    if record.result ~= -1 then
        return record.result
    end

    local fightMaxRound= record.fightMaxRound
    local seed = record.seed
    local battleType = record.battleType
    local fightData = record.fightData
    local optionData = record.optionData

    Random.SetSeed(seed)
    BattleLogic.Init(fightData, optionData, fightMaxRound)
    BattleLogic.Type = battleType
    
    BattleLogic.StartOrder()
    while not BattleLogic.IsEnd do
        BattleLogic.Update()
    end

    record.result = BattleLogic.Result
    return record.result
end

-- 获取当前战斗记录中我方最佳英雄数据
function this.GetBattleBestData(Id)
    -- body
    local _MaxDamageData = nil
    local _MaxDamageValue = -1
    local _AllDamageValue = 0
    local battleRecord = this.GetBattleRecord(Id)
    for _, data in pairs(battleRecord) do
        -- 怪物只显示最后一层的怪物信息
        if data.camp == 0 then
            -- 计算最大值（不计算异妖的）
            if data.type == 0 and not data.leader then
                if data.damage > _MaxDamageValue then 
                    _MaxDamageData = data
                    _MaxDamageValue = data.damage 
                elseif data.damage == _MaxDamageValue then
                    -- 伤害相同如何判断最佳
                end
            end
            _AllDamageValue = _AllDamageValue + data.damage
        end
    end
    return _MaxDamageData, _AllDamageValue
end


-- 上报战斗日志
function this.SubmitBattleRecord()
    if not this.isSubmit then
        PopupTipPanel.ShowTipByLanguageId(12295)
        return 
    end
    local _, rcd = this.isHaveRecord()
    if rcd then 
        NetManager.GMEvent("//"..rcd.seed.."|"..rcd.fightMaxRound.."|"..BattleManager.PrintBattleTable(rcd.fightData))
    end
    this.isSubmit = false
    PopupTipPanel.ShowTipByLanguageId(12296)
end

------------------------ 状态同步 ------------------------
--需要缓存的类型
RecordType = {
    BattleLogic_Event = 1,
    BattleLogic_BuffMgr = 2,
    RoleManager = 3,
    SkillManager = 4,
    OutDataManager = 5,
    PassiveManager = 6,
    FightUnitManager = 7
}

RecordFrameType = {
    roundBegin = 1,
    roundEnd = 2,
    TrunRround = 3,
    PropChange = 4,
    All = 5
}

this.recorder = BattleDictionary.New()
this.RollDic = BattleDictionary.New()
this.RecordCaculate = {}
this.isCompareFrame = false

-- -- 初始化帧记录器
-- function this.InitFrameRecord()
--     this.Clear()

--     this.RecordCaculate = {}
--     this.recorder = BattleDictionary.New()
--     this.RollDic= BattleDictionary.New()

--     this.RollDic:Add(RecordType.BattleLogic_BuffMgr,RoleManager.RollBack)
--     this.RollDic:Add(RecordType.BattleLogic_Event,RoleManager.RollBack)
--     this.RollDic:Add(RecordType.FightUnitManager,RoleManager.RollBack)
--     this.RollDic:Add(RecordType.OutDataManager,RoleManager.RollBack)
--     this.RollDic:Add(RecordType.RoleManager,RoleManager.RollBack)
--     this.RollDic:Add(RecordType.SkillManager,RoleManager.RollBack)


--     this.isCompareFrame = true
-- end


-- -- 按回合记录状态减少数据量
-- function this.recordMoveBytype(_move,type)
--     -- LogError("recordRoundBytype:".._round)
--     local fram = this.Clone()
--     local frameDate = {
--         _clone = fram,
--         _type = type,
--         _num =_move,
--         _isframe = false,
--         _isRound = true
--     }    
--     this.recorder:Add(_move,frameDate)
-- end

-- --数据回滚到此回合状态
-- function this.RollBackMove(_round,type)   
--     local _frameDate = this.recorder:Get(_round)
--     -- LogError("R..............1")
--     if  _frameDate ~= nil then
--         local _getFrame = _frameDate._clone
--         -- LogError("R..............2")
--         if  _frameDate._type == type then
--             -- LogError("R..............3")
--             if this.RollDic:Get(type) ~= nil and _getFrame~=nil then 
--                 -- LogError("R..............4")
--                 -- LogError("RollBack _frame:".._round)
--                 local _FramRole = _getFrame:Get(RecordType.RoleManager)          
--                 -- this.RollDic:Get(type)(_getFrame)
--                 RoleManager.RollBack(_FramRole)
--             end
--         end
--     else
--         -- LogError("_round none snap ".._round)
--     end
-- end



-- -- 按回合记录状态减少数据量
-- function this.recordRoundBytype(_round,type)
--     -- LogError("recordRoundBytype:".._round)
--     local fram = this.Clone()
--     local frameDate = {
--         _clone = fram,
--         _type = type,
--         _num = _round,
--         _isframe = false,
--         _isRound = true
--     }    
--     this.recorder:Add(_round,frameDate)
-- end

-- --数据回滚到此回合状态
-- function this.RollBackRound(_round,type)   
--     local _frameDate =  this.recorder:Get(_round)
--     -- LogError("R..............1")
--     if  _frameDate ~= nil then
--         local _getFrame = _frameDate._clone
--         -- LogError("R..............2")
--         if  _frameDate._type == type then
--             -- LogError("R..............3")
--             if this.RollDic:Get(type) ~= nil and _getFrame~=nil then 
--                 -- LogError("R..............4")
--                 -- LogError("RollBack _frame:".._round)
--                 local _FramRole = _getFrame:Get(RecordType.RoleManager)          
--                 -- this.RollDic:Get(type)(_getFrame)
--                 RoleManager.RollBack(_FramRole)
--             end
--         end
--     else
--         -- LogError("_round none snap ".._round)
--     end
-- end

-- -- 镜像数据
-- function this.Clone()
--     local frame= BattleDictionary.New()
--     -- frame:Add(RecordType.BattleLogic_Event,"")  --todo
--     -- frame:Add(RecordType.BattleLogic_BuffMgr,"") --todo
--     frame:Add(RecordType.RoleManager,RoleManager.Clone()) -- 目前仅做状态同步    
--     -- frame:Add(RecordType.SkillManager,SkillManager.Clone()) --todo
--     -- frame:Add(RecordType.OutDataManager,OutDataManager.Clone()) --todo
--     -- frame:Add(RecordType.PassiveManager,PassiveManager.Clone()) --todo
--     -- frame:Add(RecordType.FightUnitManager,FightUnitManager.Clone()) --todo
--     local round = BattleLogic.GetCurRound()
--     -- LogError("clone .. round"..round)
--     return frame
-- end

-- --获取当前帧数据
-- function this.getFrame(_frame)
--     if not  this.recorder.Get(_frame) then
--        return this.recorder.Get(_frame)._clone
--     end
-- end

-- -- 目前只记录特定数据
-- function this.recordFrameBytype(_curFrame,type)
--     -- LogError("recordFrameBytype:".._curFrame)
--     local frameDate = {
--         _clone = this.Clone(),
--         _type = type,
--         _num = _curFrame,
--         _isframe = true,
--         _isRound = false
--     }    
--     this.recorder:Add(_curFrame,frameDate)
-- end

-- -- 目前只记录回合结束的帧状态
-- function this.recordFrame(curFrame)
--     -- LogError("recordFrame:"..curFrame)
--     local frameDate = this.Clone()  --dic
--     this.recorder:Add(curFrame,frameDate)
-- end

-- --数据回滚到此状态
-- function this.RollBack(_frame,type)
--     -- LogError("RollBack _frame:".._frame)
--     local _getFrame =  this.recorder:Get(_frame)
--     if not _getFrame then
--         local _frameDate =  this.recorder:Get(_frame)
--         if not _frameDate:Get(type) then
--             local _d = _frameDate:Get(type)
--             if  this.RollDic[type] ~= nil then 
--                 this.RollDic[type](_d)
--             end
--         end
--     end
-- end

-- --数据回滚到此状态
-- function this.RollBackFuc(_frame,type,func)
--     local _getFrame = this.recorder:Get(_frame)
--     if not _getFrame then
--         local _frameDate = this.recorder:Get(_frame)
--         if not _frameDate:Get(type) then
--             local _d = _frameDate:Get(type)
--             if func then func(_d) end
--         end
--     end
-- end

-- function this.getFrame(_frame,type)
--     if not this.recorder:Get(_frame) then
--         local _frameDate = this.recorder:Get(_frame)
--         if not _frameDate:Get(type) then
--             return _frameDate:Get(type)._clone
--         end
--     end
-- end

-- --清空数据
-- function this.Clear()
--     if this.recorder~=nil and this.recorder:Count() > 0 then this.recorder:Clear() end
--     if this.RollDic~=nil and this.RollDic:Count() > 0  then this.RollDic:Clear() end
--     this.isCompareFrame = false
-- end


------------------------ 状态同步 ------------------------
--需要缓存的类型
RecordType={
    BattleLogic_Event=1,
    BattleLogic_BuffMgr=2,
    RoleManager=3,
    SkillManager=4,
    OutDataManager=5,
    PassiveManager=6,
    FightUnitManager=7
}

RecordFrameType={    
    roundBegin=1,
    roundEnd=2,
    TrunRround=3,
    PropChange=4,
    All=5
}

this.recorder= BattleDictionary.New()
this.recorderOtherDate= BattleDictionary.New()
this.RollDic= BattleDictionary.New()
this.RecordCaculate={}
this.isCompareFrame = false
this.Lastresult = -1
-- 初始化帧记录器
function this.InitFrameRecord()
    this.Clear()

    this.RecordCaculate={}
    this.recorder = BattleDictionary.New()
    this.recorderOtherDate = BattleDictionary.New()
    this.RollDic= BattleDictionary.New()

    this.RollDic:Add(RecordType.BattleLogic_BuffMgr,RoleManager.RollBack)
    this.RollDic:Add(RecordType.BattleLogic_Event,RoleManager.RollBack)
    this.RollDic:Add(RecordType.FightUnitManager,RoleManager.RollBack)
    this.RollDic:Add(RecordType.OutDataManager,RoleManager.RollBack)
    this.RollDic:Add(RecordType.RoleManager,RoleManager.RollBack)
    this.RollDic:Add(RecordType.SkillManager,RoleManager.RollBack)


    this.isCompareFrame = true
end

function this.recordResult(result)
    this.Lastresult = result
end


-- 按回合记录状态减少数据量
function this.recordMoveBytype(_move,type)
    -- LogError("recordRoundBytype:".._round)
    local fram = this.Clone()
    local frameDate = {
        _clone= fram,
        _type=type,
        _num =_move,
        _isframe = false,
        _isRound = true
    }    
    this.recorder:Add(_move,frameDate)
end

--数据回滚到此回合状态
function this.RollBackMove(_round,type)   
    local _frameDate =  this.recorder:Get(_round)
    -- LogError("R..............1")
    if  _frameDate~=nil then
        local _getFrame = _frameDate._clone
        -- LogError("R..............2")
        if  _frameDate._type == type then
            -- LogError("R..............3")
            if this.RollDic:Get(type) ~= nil and _getFrame~=nil then 
                -- LogError("R..............4")
                -- LogError("RollBack _frame:".._round)
                local _FramRole= _getFrame:Get(RecordType.RoleManager)          
                -- this.RollDic:Get(type)(_getFrame)
                RoleManager.RollBack(_FramRole)
            end
        end
    else
        -- LogError("_round none snap ".._round)
    end
end



-- 按回合记录状态减少数据量
function this.recordRoundBytype(_round,type)
    -- LogError("recordRoundBytype:".._round)
    local fram = this.Clone()
    local frameDate = {
        _clone= fram,
        _type=type,
        _num =_round,
        _isframe = false,
        _isRound = true
    }    
    this.recorder:Add(_round,frameDate)
end

--数据回滚到此回合状态
function this.RollBackRound(_round,type)   
    local _frameDate =  this.recorder:Get(_round)
    -- LogError("R..............1")
    if  _frameDate~=nil then
        local _getFrame = _frameDate._clone
        -- LogError("R..............2")
        if  _frameDate._type == type then
            -- LogError("R..............3")
            if this.RollDic:Get(type) ~= nil and _getFrame~=nil then 
                -- LogError("R..............4")
                -- LogError("RollBack _frame:".._round)
                local _FramRole= _getFrame:Get(RecordType.RoleManager)          
                -- this.RollDic:Get(type)(_getFrame)
                RoleManager.RollBack(_FramRole)
            end
        end
    else
        -- LogError("_round none snap ".._round)
    end
end

-- 镜像数据
function this.Clone()
    local frame= BattleDictionary.New()
    -- frame:Add(RecordType.BattleLogic_Event,"")  --todo
    -- frame:Add(RecordType.BattleLogic_BuffMgr,"") --todo
    frame:Add(RecordType.RoleManager,RoleManager.Clone()) -- 目前仅做状态同步    
    -- frame:Add(RecordType.SkillManager,SkillManager.Clone()) --todo
    -- frame:Add(RecordType.OutDataManager,OutDataManager.Clone()) --todo
    -- frame:Add(RecordType.PassiveManager,PassiveManager.Clone()) --todo
    -- frame:Add(RecordType.FightUnitManager,FightUnitManager.Clone()) --todo
    -- local round =BattleLogic.GetCurRound()
    -- LogError("clone .. round"..round)
    return frame
end

--获取当前帧数据
function this.getFrame(_frame)
    if not  this.recorder.Get(_frame) then
       return  this.recorder.Get(_frame)._clone
    end
end

-- 目前只记录特定数据
function this.recordFrameBytype(_curFrame,type)
    -- LogError("recordFrameBytype:".._curFrame)
    local frameDate = {
        _clone=this.Clone(),
        _type=type,
        _num =_curFrame,
        _isframe = true,
        _isRound = false
    }    
    this.recorder:Add(_curFrame,frameDate)
end

-- 目前只记录回合结束的帧状态
function this.recordFrame(curFrame)
    -- LogError("recordFrame:"..curFrame)
    local frameDate = this.Clone()  --dic
    this.recorder:Add(curFrame,frameDate)
end

--数据回滚到此状态
function this.RollBack(_frame,type)
    -- LogError("RollBack _frame:".._frame)
    local _getFrame =  this.recorder:Get(_frame)
    if not _getFrame then
        local _frameDate =  this.recorder:Get(_frame)
        if not _frameDate:Get(type) then
            local _d = _frameDate:Get(type)
            if  this.RollDic[type] ~= nil then 
                this.RollDic[type](_d)
            end
        end
    end
end

--数据回滚到此状态
function this.RollBackFuc(_frame,type,func)
    local _getFrame = this.recorder:Get(_frame)
    if not _getFrame then
        local _frameDate = this.recorder:Get(_frame)
        if not _frameDate:Get(type) then
            local _d = _frameDate:Get(type)
            if func then func(_d) end
        end
    end
end

function this.getFrame(_frame,type)
    if not this.recorder:Get(_frame) then
        local _frameDate = this.recorder:Get(_frame)
        if not _frameDate:Get(type) then
            return _frameDate:Get(type)._clone
        end
    end
end

--清空数据
function this.Clear()
    this.Lastresult = -1
    if this.recorder~=nil and this.recorder:Count() >0 then this.recorder:Clear() end
    if this.recorderOtherDate~=nil and this.recorderOtherDate:Count() >0 then this.recorderOtherDate:Clear() end
    if this.RollDic~=nil and this.RollDic:Count() >0  then this.RollDic:Clear() end    
    this.isCompareFrame = false
end

------------------------ 状态同步 ------------------------

return this