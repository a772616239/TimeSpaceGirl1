--[[
 * @Classname MathEx
 * @Description math extension
 * @Date 2019/5/18 9:36
 * @Created by MagicianJoker
--]]

--正无穷--
math.infinity = math.huge

--四舍五入--
function math.round(x)
    return math.floor(x + 0.5)
end

--[[
-- @brief  夹逼一个数，使其在提供的范围内
-- @param  v
-- @param  minValue      范围最小值
-- @param  maxValue      范围最大值
-- @return v
--]]
function math.clamp(v, minValue, maxValue)
    if v < minValue then
        return minValue
    end
    if v > maxValue then
        return maxValue
    end
    return v
end

--[[
-- @brief  计算两点距离
-- @param  p1      点1
-- @param  p2      点2
-- @return 两点距离
--]]
function math.distanceXY(p1, p2)
    local dis = math.sqrt(math.pow(p2.x-p1.x, 2)+math.pow(p2.y-p1.y, 2))
    return dis
end