local MsgParser = { inited = false }

local utf8 = require("BadWords/utf8")

local utf8Len = utf8.len
local utf8Sub = utf8.sub
local strSub = string.sub
local strLen = string.len
local strByte = string.byte
local strGsub = string.gsub

local _maskWord = '*'

local _tree = {}

local function _word2Tree(root, word)
	if strLen(word) == 0 then return end

	local function _byte2Tree(r, ch, tail)
		if tail then
            if type(r[ch]) == 'table' then
                r[ch].isTail = true
            else
                r[ch] = true
            end
		else
            if r[ch] == true then
                r[ch] = { isTail = true }
            else
			    r[ch] = r[ch] or {}
            end
		end
		return r[ch]
	end
	
	local tmpparent = root
	local len = utf8Len(word)
    for i=1, len do
    	if tmpparent == true then
    		tmpparent = { isTail = true }
    	end
    	tmpparent = _byte2Tree(tmpparent, utf8Sub(word, i, i), i==len)
    end
end

local function _detect(parent, word, idx)
    local len = utf8Len(word)
  
	local ch = utf8Sub(word, 1, 1)
	local child = parent[ch]
    
    if not child then
    elseif type(child) == 'table' then
        if len > 1 then
            if child.isTail then
	            return _detect(child, utf8Sub(word, 2), idx+1) or idx
            else
                return _detect(child, utf8Sub(word, 2), idx+1)
            end
        elseif len == 1 then
            if child.isTail == true then
                return idx
            end
        end
    elseif (child == true) then
    	return idx
    end
    return false
end

function MsgParser:init()
	if self.inited then return end

    local words = require("BadWords/SensitiveCfg")

	for _, word in pairs(words) do
		_word2Tree(_tree, word)
	end

	self.inited = true
    package.loaded["BadWords/SensitiveCfg"]  = nil
end

function MsgParser:getString(s)
	local word, idx, illegals, tmps
	local i = 1
	local len = utf8Len(s)

	while true do
    	word = utf8Sub(s, i)
    	idx = _detect(_tree, word, i)

    	if idx then
    		illegals = utf8Sub(s, i, idx)
    		tmps = ''
    		for j=1, utf8Len(illegals) do
    			tmps = tmps .. _maskWord
    		end
    		s = strGsub(s, illegals, tmps)
    		i = idx+1
    	else
    		i = i + 1
    	end
    	if i > len then
    		break
    	end
    end
    return s
end

MsgParser:init()

return MsgParser