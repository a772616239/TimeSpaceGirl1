local bezier ={}
local log = math.log
local exp = math.exp
local round = math.round
local abs = math.abs
local tmpList = {}
local tmpIndex = 0

local function calCombineNum(n, m)
    if m > n then return 0 end
    if m > n / 2 then m = n - m end
    if m == 0 then  return 1 end
    if m == 1  then return n end

    local s1 = 0
    for i=m+1, n do
        s1 = s1 + log(i)
    end

    local s2 = 0
    for i = 2, n-m do
        s2 = s2 + log(i)
    end
    return round(exp(s1-s2))
end

local function calPos(progress, startV2, endV2, tbProV2)
    local v = Vector2.New(0, 0)
    tmpIndex = 1
    tmpList[tmpIndex] = startV2
    for i=1, #tbProV2 do
        tmpIndex = tmpIndex + 1
        tmpList[tmpIndex] = tbProV2[i]
    end
    tmpIndex = tmpIndex + 1
    tmpList[tmpIndex] = endV2
    local n = tmpIndex-1
    for i=0, n do
        local tmp = calCombineNum(n,i) * ((1-progress) ^ (n-i)) * (progress ^ i)
        v.x = v.x + tmp * tmpList[i+1].x
        v.y = v.y + tmp * tmpList[i+1].y
    end
    return v
end

local function calDir(progress, startV2, endV2, tbProV2)
    local v = Vector2.New(0, 0)
    tmpIndex = 1
    tmpList[tmpIndex] = startV2
    for i=1, #tbProV2 do
        tmpIndex = tmpIndex + 1
        tmpList[tmpIndex] = tbProV2[i]
    end
    tmpIndex = tmpIndex + 1
    tmpList[tmpIndex] = endV2
    local n = tmpIndex-1
    for i=0, n do
        local tmp = (i-n*progress)/progress/(1-progress) * calCombineNum(n,i) * ((1-progress) ^ (n-i)) * (progress ^ i)
        v.x = v.x + tmp * tmpList[i+1].x
        v.y = v.y + tmp * tmpList[i+1].y
    end
    return v
end

local function calPathLen(progress, startV2, endV2, tbProV2)
    local a = progress * 0.5
    local l = 0
    l = l + 0.56888888888889 * calDir(a, startV2, endV2, tbProV2).magnitude
    l = l + 0.47862867049937 * calDir(0.46150689894317 * a, startV2, endV2, tbProV2).magnitude
    l = l + 0.47862867049937 * calDir(1.53846931010568 * a, startV2, endV2, tbProV2).magnitude
    l = l + 0.23692688505619 * calDir(0.093820154061336 * a, startV2, endV2, tbProV2).magnitude
    l = l + 0.23692688505619 * calDir(1.906179845938664 * a, startV2, endV2, tbProV2).magnitude
    return l * a
end

function bezier.CalPos(progress, startV2, endV2, tbProV2)
    return calPos(progress, startV2, endV2, tbProV2)
end
function bezier.CalDir(progress, startV2, endV2, tbProV2)
    return calDir(progress, startV2, endV2, tbProV2)
end
function bezier.CalPathLen(progress, startV2, endV2, tbProV2)
    return calPathLen(progress, startV2, endV2, tbProV2)
end
function bezier.GetUniformProcess(progress, startV2, endV2, tbProV2)
    local progress2 = progress
    local l = progress * calPathLen(1, startV2, endV2, tbProV2)
    local lower = 0
    local upper = 1
    local tCandidate
    local df
    local f = calPathLen(progress2, startV2, endV2, tbProV2) - l
    while abs(f) > 10e-6 do
        df = calDir(progress2, startV2, endV2, tbProV2).magnitude
        tCandidate = progress2 - f / df

        if f > 0 then
            upper = progress2
        else
            lower = progress2
        end

        if tCandidate <= lower then
            progress2 = 0.5 * (upper + lower)
        else
            progress2 = tCandidate
        end
        f = calPathLen(progress2, startV2, endV2, tbProV2) - l
    end
    return progress2
end
return bezier