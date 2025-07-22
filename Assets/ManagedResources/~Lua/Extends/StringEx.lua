--[[
 * @Classname StringEx
 * @Description String extension
 * @Date 2019/5/18 9:38
 * @Created by MagicianJoker
--]]

--function string.split(input, delimiter)
--    input = tostring(input)
--    delimiter = tostring(delimiter)
--    if (delimiter=='') then return false end
--    local pos,arr = 0, {}
--    -- for each divider found
--    for st,sp in function() return string.find(input, delimiter, pos, true) end do
--        table.insert(arr, string.sub(input, pos, st - 1))
--        pos = sp + 1
--    end
--    table.insert(arr, string.sub(input, pos))
--    return arr

--判断字符串sSource是否以sTemplate结束
function endWith(sSource, sTemplate)
    if not sSource or not sTemplate then
        return false
    else
        if #sSource < #sTemplate then
            return false
        else
            local _subStr = string.sub(sSource, #sSource - #sTemplate + 1, #sSource)
            if _subStr == sTemplate then
                return true
            else
                return false
            end
        end
    end
end

function string.contains(str, substr)
    if #substr > #str then return false end
    for i = 1, #str - #substr + 1 do
        if string.sub(str, i, i + #substr - 1) == substr then
            return true
        end
    end
    return false
end

--判断字符串sSource是否以sTemplate开始
function startWith(sSource, sTemplate)
    if not sSource or not sTemplate then
        return false
    else
        local _, _endPos = string.find(sSource, sTemplate)
        if not _endPos and _endPos == #sSource then
            return true
        else
            return false
        end
    end
end

function startswith2(str, prefix)
    return string.find(str, prefix, 1, true) == 1
end

-- 计算字符串宽度 可以计算出字符宽度，用于显示使用
function StringWidth(str)
    local lenInByte = #str
    local width = 0
    local i = 1
    while (i <= lenInByte)
    do
        local curByte = string.byte(str, i)
        local byteCount = 1
        if curByte > 0 and curByte <= 127 then
            byteCount = 1                                               --1字节字符
        elseif curByte >= 192 and curByte < 223 then
            byteCount = 2                                               --双字节字符
        elseif curByte >= 224 and curByte < 239 then
            byteCount = 3                                               --汉字
        elseif curByte >= 240 and curByte <= 247 then
            byteCount = 4                                               --4字节字符
        end

        local char = string.sub(str, i, i + byteCount - 1)

        i = i + byteCount                                              -- 重置下一字节的索引
        width = width + 1                                             -- 字符的个数（长度）
    end
    return width
end

-- 截取字符串宽度 可以计算出字符宽度，用于显示使用
function SubString(str, subWidth)
    local lenInByte = #str
    local width = 0
    local i = 1
    local subStr = ""

    while (i <= lenInByte)
    do
        local curByte = string.byte(str, i)
        local byteCount = 1
        if curByte > 0 and curByte <= 127 then
            byteCount = 1                                               --1字节字符
        elseif curByte >= 192 and curByte < 223 then
            byteCount = 2                                               --双字节字符
        elseif curByte >= 224 and curByte < 239 then
            byteCount = 3                                               --汉字
        elseif curByte >= 240 and curByte <= 247 then
            byteCount = 4                                               --4字节字符
        end

        local char = string.sub(str, i, i + byteCount - 1)
        subStr = subStr .. char
        i = i + byteCount                                              -- 重置下一字节的索引
        width = width + 1                                             -- 字符的个数（长度）
        if width == subWidth then
            break
        end
    end
    return subStr
end

function string.utf8len(input)
    local len  = string.len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end