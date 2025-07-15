--与   同为1，则为1

--或   有一个为1，则为1

--非   true为 false，其余为true

--异或 相同为0，不同为1

local function __10To2Array(num)
    local isSmallZero = num < 0 -- 是否小于0
    local isEven = num%2 == 0   -- 是否是偶数

    local ary = {}
    while num ~= 0 do
        local v = num % 2    --取得每一位(最右边)
        num = math.modf( num / 2)  --右移
        table.insert(ary, v)
    end
    -- 负数要特殊处理
    if isSmallZero then
        -- 奇数保持后一位不变，其余取反
        local startIndex = 2
        if isEven then
            -- 偶数保持后两位不变，其余取反
            startIndex = 3
        end
        --
        for i = startIndex, #ary do
            if ary[i] == 1 then ary[i] = 0
            elseif ary[i] == 0 then ary[i] = 1 end
        end
    end
    return ary
end


BitMath = {}

function BitMath.__andBit(left,right)    --与
    return (left == 1 and right == 1) and 1 or 0
end

function BitMath.__orBit(left, right)    --或
    return (left == 1 or right == 1) and 1 or 0
end

function BitMath.__xorBit(left, right)   --异或
    return (left + right) == 1 and 1 or 0
end

function BitMath.__base(left, right, op) --对每一位进行op运算，然后将值返回
    -- 将十进制数转换为二进制数组
    local lary = __10To2Array(left)
    local rary = __10To2Array(right)
    -- 计算最大长度
    local maxlen = #lary
    if #rary > maxlen then maxlen = #rary end
    -- 按位进行位计算
    local res = 0
    local shift = 1
    for i = 1, maxlen do
        local lv, rv = lary[i], rary[i]
        -- 位数不足的向前补充，负数补1，正数补0
        if not lv then lv = left < 0 and 1 or 0 end
        if not rv then rv = right < 0 and 1 or 0 end
        -- 计算数值
        res = shift * op(lv,rv) + res
        shift = shift * 2
    end
    return res
end

--- 与运算
function BitMath.andOp(left, right)
    return BitMath.__base(left, right, BitMath.__andBit)
end
--- 异或运算
function BitMath.xorOp(left, right)
    return BitMath.__base(left, right, BitMath.__xorBit)
end
--- 或运算
function BitMath.orOp(left, right)
    return BitMath.__base(left, right, BitMath.__orBit)
end
--- 取反
function BitMath.notOp(left)
    return left > 0 and -(left + 1) or -left - 1
end
--- left左移num位
function BitMath.lShiftOp(left, num)
    return left * (2 ^ num)
end
--- right右移num位
function BitMath.rShiftOp(left,num)
    return math.floor(left / (2 ^ num))
end