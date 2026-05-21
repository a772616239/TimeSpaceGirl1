Random = {}

local floor = math.floor
local seed = 0

local function random()
    local r = seed
    local m = 123459876
    if r < m then
        r, m = m, r
    end
    local res = 0
    local shift = 1
    local b
    while r ~= 0 do
        b = (r % 2 + m % 2) == 1 and 1 or 0
        res = shift * b + res
        shift = shift * 2
        r = floor( r * 0.5)
        m = floor( m * 0.5)
    end
    local k = floor(res / 127773)
    r = 16807 * (res - k * 127773) - 2836 * k
    if r < 0 then
        r = r + 2147483647
    end
    seed = r
    return r
end
function Random.SetSeed(sd)
    seed = sd
end

function Random.GetSeed()
    return seed
end

--随机0-1
function Random.Range01()
    local var = random() / 2147483647
    BattleLogManager.Log(
        "random", 
        "seed", seed)
    return var
end

--随机v1-v2
function Random.Range(v1, v2)
    if v2 > v1 then
        return Random.Range01()*(v2-v1)+v1
    elseif v1 > v2 then
        return Random.Range01()*(v1-v2)+v2
    else
        return v1
    end
end

--随机v1-v2 返回整数
function Random.RangeInt(v1, v2)
    if v2 > v1 then
        return floor(Random.Range01()*(v2-v1) + 0.5)+v1
    elseif v1 > v2 then
        return floor(Random.Range01()*(v1-v2) + 0.5)+v2
    else
        return v1
    end
end

function Random.RandomList(arr)
    if not arr or #arr <= 1 then
        return
    end
    local index
    for i = #arr, 1, -1 do
        index = Random.RangeInt(1, i)
        arr[i], arr[index] = arr[index], arr[i]
    end
end