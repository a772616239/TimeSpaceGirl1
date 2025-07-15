GameDataBase = {}

local floor = math.floor
local pairs = pairs
local type = type
local setmetatable = setmetatable

local function readonlyMT(t,k,v)
 
end

local function setDefaultTable(rT, dT)
  for i=1, #rT do
    if type(rT[i]) == "table" then
      setDefaultTable(rT[i], dT)
    else
      rT[i] = dT[rT[i]]
    end
  end
end

local function createTable(curD, index, val, parent)
  if curD == #index then
    parent[index[curD]] = val
  else
    parent[index[curD]] = parent[index[curD]] or {}
    createTable(curD+1, index, val, parent[index[curD]])
  end
end

local decode = {}
local function decodeList(encodeList)
  if not encodeList or #encodeList < 1 then
    return encodeList
  end

  local dCount = 0
  local off,count,idx,n,n2,f

  for i=1, #encodeList do
    n = encodeList[i]
    off = floor(n)

    if off == n or off < 2 then
      dCount = dCount + 1
      decode[dCount] = n
    else
      n2, count, f = n, 0, 1
      while n2 - floor(n2) > 1e-5 do
        n2 = floor(n2 * 1000000 + 0.5) / 100000
        count = count + floor(n2) % 10 * f
        f = f * 10
      end
      idx = dCount
      if count == 1 then
        count = off
      end
      for j=1, count do
        dCount = dCount + 1
        decode[dCount] = decode[idx-off+j]
      end
    end
  end
  dCount = 0
  for i=1, #decode do
    n = decode[i]
    off = floor(n)
    if off == n then
      dCount = dCount + 1
      encodeList[dCount] = decode[i]
    else
      if n < 0 then
        n = -n
        off = floor(n)
      end
      n2, count, f = n, 0, 1
      while n2 - floor(n2) > 1e-5 do
        n2 = floor(n2 * 1000000 + 0.5) / 100000
        count = count + floor(n2) % 10 * f
        f = f * 10
      end
      for j=1, count do
        dCount = dCount + 1
        encodeList[dCount] = off
      end
    end
  end
  for i=1,#decode do
    decode[i] = nil
  end
  local flag = encodeList[1]
  for i=2, #encodeList do
    flag = flag + encodeList[i]
    encodeList[i] = flag
  end
  return encodeList
end

GameDataBase.SheetRefBase = {}
GameDataBase.SheetRefBase.__newindex = readonlyMT
GameDataBase.SheetRefBase.__index = function(t,k)
  if t.m_refTB[k] then
    return t.m_refTB[k]
  end
  local l_rt
  for i, v in pairs(t.m_refData) do
    if v[k] then
      l_rt = l_rt or {}
      createTable(1, i, t.m_DT[v[k]], l_rt)
    end
  end
  t.m_refTB[k] = l_rt
  return l_rt
end

GameDataBase.SheetLineBase = {}
GameDataBase.SheetLineBase.__newindex = readonlyMT
GameDataBase.SheetLineBase.__index = function(t,k)
  local index = t.m_fIds[k]
  if index then
    return t.val[index]
  end
end

GameDataBase.SheetBase = {}
GameDataBase.SheetBase.__newindex = readonlyMT
GameDataBase.SheetBase.__index = function(t,k)
  local index = t.__ids[k]
  if index then
    local line = t.__lines[index]
    if not line then
      line = {val={k}}
      for i=1, #t.__fields-1 do
        if t.__defaults[i] then
          if t.__refPoss[i] and t.__refPoss[i][index] then
            line.val[i+1] = t.__refPoss[i][index]
          else
            line.val[i+1] = t.__defaults[i]
          end
        else
          line.val[i+1] = t.__refs[i][index]
        end
        if type(line.val[i+1]) == "number" then
          line.val[i+1] = t.__values[line.val[i+1]]
        end
      end
      line.m_fIds = t.__fIds
      setmetatable(line, GameDataBase.SheetLineBase)
      t.__lines[index] = line
    end
    return line
  end
end

function GameDataBase.SheetBase.GetCount(t)
  return t.__count
end

function GameDataBase.SheetBase.Init(t)
  t.__indexs = decodeList(t.__indexs)
  t.__values = decodeList(t.__values)
  if t.__exVals then
    local count = #t.__values
    for i=1,t.__exVals[1] do
      t.__values[i+count] = t.__exVals[i+1]
    end
    t.__exVals = nil
  end

  t.__fIds = {}
  for i=1, #t.__fields do
    t.__fIds[t.__fields[i]] = i
  end

  t.__ids = {}
  t.__lines = {}
  for i=1,t.__count do
    t.__ids[t.__indexs[i]] = i
  end
  local ids = {}
  local refs = {}
  for i=1, #t.__fields-1 do
    local idList = decodeList(t.__refPoss[i])
    if t.__refs[i] and type(t.__refs[i][1]) == "table" then
      local rTs = { m_refData = {}, m_refTB = {}}
      for j=1, #t.__refs[i] do
        local data = decodeList(t.__refs[i][j][2])
        local data_pos = decodeList(t.__refs[i][j][3])
        if idList then
          local dic = {}
          if data_pos then
            if #data_pos == #data then
              for k=1, #data do
                dic[idList[data_pos[k]]] = data[k]
              end
            else
              local dIdx,dIdx2 = 1,0
              for k=1, #data_pos+#data do
                if k==data_pos[dIdx] then
                  dIdx = dIdx + 1
                else
                  dIdx2 = dIdx2 + 1
                  dic[idList[k]] = data[dIdx2]
                end
              end
            end
          else
            for k=1, #data do
              dic[idList[k]] = data[k]
            end
          end
          data = dic
        else
          if data_pos then
            local dic = {}
            if #data_pos == #data then
              for k=1, #data do
                dic[data_pos[k]] = data[k]
              end
            else
              local dIdx,dIdx2 = 1,0
              for k=1, #data_pos+#data do
                if k==data_pos[dIdx] then
                  dIdx = dIdx + 1
                else
                  dIdx2 = dIdx2 + 1
                  dic[k] = data[dIdx2]
                end
              end
            end
            data = dic
          end
        end
        rTs.m_refData[t.__refs[i][j][1]] = data
      end
      rTs.m_DT = t.__values
      setmetatable(rTs, GameDataBase.SheetRefBase)
      refs[i] = rTs
    else
      refs[i] = decodeList(t.__refs[i])
    end
    if t.__defaults[i] and type(t.__defaults[i]) == "table" then
      setDefaultTable(t.__defaults[i], t.__values)
    end
    if t.__defaults[i] and idList then
      local tDic = {}
      if type(t.__refs[i][1]) == "table" then
        for j=1, #idList do
          tDic[idList[j]] = refs[i][idList[j]]
        end
      else
        for j=1, #idList do
          tDic[idList[j]] = refs[i][j]
        end
      end
      ids[i] = tDic
    end
  end
  t.__refPoss = ids
  t.__refs = refs
  setmetatable(t,GameDataBase.SheetBase)
end

function GameDataBase.SheetBase.GetKeys(t)
  return t.__indexs
end



