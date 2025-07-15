local isLog = false
local function __DebugLog(str)
    if isLog then
       
    end
end

-- 红点状态
local _data = {}
-- 红点树关系结构数据
local _parentIndex = {}
local _childNum = {}
local _childIndex = {}
-- 红点检测方法
local _checkFunc = {}
-- 服务器保存的红点信息
local _serverRedData = {}


-- 向父级检测设置红点值
local function _doSetRedValue(node, value)
    if _data[node] ~= value then
        _data[node] = value
        -- __DebugLog(GetLanguageStrById(11521).. node .. ",   value == ".. value)
        --如果有父级，更新父级
        local _parent = _parentIndex[node]
        if _parent then
            local index = _childIndex[node]
            local _parentValue = 0

            --- BitMath.lShiftOp(1, (index - 1))  后为：： 1，2，4，8 .。。 既：0001   0010   0100  1000。。。
            local _IndexBitValue = BitMath.lShiftOp(1, (index - 1))

            if value > 0 then
                --- 父结点值为：或运算，将相应二进制位置上的  0  置为  1
                _parentValue = BitMath.orOp(_data[_parent], _IndexBitValue)
            else
                --- BitMath.notOp(_IndexBitValue)   取反运算，值为： 1110  1101  1011  0111 .。。
                --- 父节点值为：与运算，将相应二进制位置上的  1  置为  0
                _parentValue = BitMath.andOp(_data[_parent], BitMath.notOp(_IndexBitValue))
            end

            -- 向上一层级递归
            _doSetRedValue(_parent, _parentValue)
        end

    end

end


local RedPointData = {}

function RedPointData:SetParent(child, parent)
    -- 不能相反
    if _parentIndex[parent] == child then

        return
    end
    -- 一个子节点只能有一个父节点
    if _parentIndex[child] then
        
        return
    end
    -- 设置子节点对应的父节点
    _parentIndex[child] = parent
    -- 记录父节点对应的子节点数量
    if not _childNum[parent] then _childNum[parent] = 0 end
    _childNum[parent] = _childNum[parent] + 1
    -- 记录子节点在父节点中的位置
    _childIndex[child] = _childNum[parent]
    -- 设置数据
    if not _data[child] then _data[child] = 0 end
    if not _data[parent] then _data[parent] = 0 end
end

-- 获取红点的父节点
function RedPointData:GetRedParent(node)
    return _parentIndex[node]
end


-- 对叶子节点设置红点状态
function RedPointData:SetRedValue(node, value)
    if _childNum[node] and _childNum[node] > 0 then

        return false
    end
    -- 设置红点数值
    _doSetRedValue(node, value)
    return true
end

-- 获取红点状态
function RedPointData:GetRedValue(node)
    return _data[node]
end

-- 注册红点检测方法
function RedPointData:AddCheckFunc(node, func, openType)
    if _childNum[node] and _childNum[node] > 0 then
        
        return
    end
    if _checkFunc[node] then
        
        return
    end
    if not RedPointData:GetServerRed(node) and not func then
        
        return
    end
    -- __DebugLog(GetLanguageStrById(11523).. node .. GetLanguageStrById(11529))
    _checkFunc[node] = {
        func = func,
        openType = openType
    }
end

-- 删除检测方法
function RedPointData:RemoveCheckFunc(node)
    _checkFunc[node] = nil
end

-- 检测红点，成功返回true，失败返回 false
function RedPointData:CheckRedPoint(node)
    local value = nil
    -- 判断是否解锁
    if _checkFunc[node] and _checkFunc[node].openType then
        local isOpen = ActTimeCtrlManager.SingleFuncState(_checkFunc[node].openType)
        if not isOpen then value = 0 end
    end

    if not value then
        -- 判断是否是服务器红点
        if RedPointData:GetServerRed(node) then
            value = RedPointData:GetServerRed(node)
        -- 判断是否注册了检测方法
        elseif _checkFunc[node] and _checkFunc[node].func then
            value = _checkFunc[node].func(node) and 1 or 0
        -- 都没有提示，出错
        else

            return false
        end
    end
    -- 数据正确性检测
    if not value then

        return false
    end
    -- 判断红点状态是否改变
    if value == RedPointData:GetRedValue(node) then
        -- __DebugLog(GetLanguageStrById(11523).. node .. ", value = ".. value ..GetLanguageStrById(11532))
        return false
    end
    -- 设置红点值
    RedPointData:SetRedValue(node, value)
    return true
end

-- 获取红点检测方法list
function RedPointData:GetCheckList()
    return _checkFunc
end


---------服务器红点相关-----------------
-- 设置服务器红点数据
function RedPointData:SetServerRedData(list)
    _serverRedData = list

    -- debug用
    __DebugLog("++++++++++++++++")
    __DebugLog("++++++++++++++++")
    __DebugLog("++++++++++++++++")
    for rpType, value in ipairs(list) do
        -- __DebugLog(GetLanguageStrById(11533)..rpType..", value == "..value)
    end
    __DebugLog("++++++++++++++++")
    __DebugLog("++++++++++++++++")
    __DebugLog("++++++++++++++++")
end
function RedPointData:GetServerRedData()
    return _serverRedData
end
-- 更新服务器红点状态
function RedPointData:SetServerRed(node, value)
    if not _serverRedData[node] then

        return false
    end
    _serverRedData[node] = value
    return true
end
-- 获取服务器红点值
function RedPointData:GetServerRed(node)
    if not _serverRedData[node] then
        return
    end
    return _serverRedData[node]
end


return RedPointData