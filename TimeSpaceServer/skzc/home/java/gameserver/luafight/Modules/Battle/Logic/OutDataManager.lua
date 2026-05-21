--战斗外数据管理、
OutDataManager = {}
local this = OutDataManager

local function _Split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

local datalist = {}
-- 分割字符串为2维数组
local function _SplitToDic(dataStr)
    local ar2 = {}
    if not dataStr or dataStr == "" then return ar2 end
    local strs = _Split(dataStr, "|")
    for i, s in ipairs(strs) do
        local ss = _Split(s, "#")
        local key = tonumber(ss[1])
        local value = tonumber(ss[2])
        ar2[key] = value
    end
    return ar2
end
-- 初始化
function this.Init(fightData)
    datalist[0] = _SplitToDic(fightData.playerData.outData)
    for i = 1, #fightData.enemyData do
        if not datalist[1] then
            datalist[1] = {}
        end
        datalist[1][i] = _SplitToDic(fightData.enemyData[i].outData)
    end
end

-- 获取战斗外数据
function this.GetOutData(camp, id)
    if camp == 0 then
        return datalist[camp][id]
    else
        return datalist[camp][BattleLogic.CurOrder][id]
    end
end

return this