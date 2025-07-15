Bit = {}

function Bit.__andBit(left, right)    --与
    return (left == 1 and right == 1) and 1 or 0
end

function Bit.__orBit(left, right)    --或
    return (left == 1 or right == 1) and 1 or 0
end

function Bit.__xorBit(left, right)   --异或
    return (left + right) == 1 and 1 or 0
end

function Bit.__notBit(left) --取反
    return left == 1 and 0 or 1
end

function Bit.__base(left, right, op) --对每一位进行op运算，然后将值返回
    if left < right then
        left, right = right, left
    end
    local res = 0
    local shift = 1
    while left ~= 0 do
        local ra = left % 2    --取得每一位(最右边)
        local rb = right % 2
        res = shift * op(ra,rb) + res
        shift = shift * 2
        left = math.modf( left / 2)  --右移
        right = math.modf( right / 2)
    end
    return res
end

function Bit.And(left, right)--与运算
    return Bit.__base(left, right, Bit.__andBit)
end

function Bit.Xor(left, right)--异或运算
    return Bit.__base(left, right, Bit.__xorBit)
end

function Bit.Or(left, right)--或运算
    return Bit.__base(left, right, Bit.__orBit)
end

function Bit.Not(left)--非运算(按位取反)
    local res = 0
    local shift = 1
    while left ~= 0 do
        local ra = left % 2    --取得每一位(最右边)
        res = shift * Bit.__notBit(ra) + res
        shift = shift * 2
        left = math.modf( left / 2)  --右移
    end
    return res
end

function Bit.LeftShift(left, num)  --left左移num位
    return left * (2 ^ num)
end

function Bit.RightShift(left, num)  --right右移num位
    return math.floor(left / (2 ^ num))
end
