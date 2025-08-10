-- Lua中的继承
function Inherit(tbParent, tbChild)
    if not tbParent then
        local o = tbChild or {}
        setmetatable(o, { __index = o })
        return o
    else
        local tb = tbChild or {}
        tbParent.__index = tbParent
        --local super_mt = getmetatable(tbParent)
        setmetatable(tb, tbParent)
        tb.super = setmetatable({}, tbParent)
        return tb
    end
end

--> 多继承
function InheritMulti(tbChild, ...)
    local super = function(k, list)
        for i, v in ipairs(list) do
            local ret = v[k]
            if ret then return ret end
        end
    end
    local args = {...}
    if #args < 1 then
        local o = tbChild or {}
        setmetatable(o, { __index = o })
        return o
    else
        local tb = tbChild or {}
        setmetatable(tb, {__index = function(t, k) return super(k, args) end})
        return tb
    end
end

function RandomList(arr)
    if not arr or #arr <= 1 then
        return
    end
    local index
    for i = #arr, 1, -1 do
        index = math.random(1, i)
        arr[i], arr[index] = arr[index], arr[i]
    end
end

--查找对象--
function find(str)
    return GameObject.Find(str)
end

function destroy(obj)
    GameObject.DestroyImmediate(obj)
end

function newObject(prefab)
    return GameObject.Instantiate(prefab)
end

--适配
function screenAdapte(go)
    --if Screen.width > 1080 or Screen.height > 1920 then
    --    local scale = math.max(Screen.width / 1080, Screen.height / 1920)
    --    go.transform.localScale = Vector3.one * scale
    --end
end

function effectAdapte(go)
    local scale = Screen.width / Screen.height / 1080 * 1920
    --local scale = Screen.width / 1080
    --local scale = 1920 / Screen.height
    
    local v3 = go.transform.localScale
    if scale <= 1 then
        Util.SetParticleScale(go, scale)
    end
    go.transform.localScale = v3
end

--创建面板--
function createPanel(name)
    PanelManager:CreatePanel(name)
end

function child(str)
    return transform:FindChild(str)
end

function subGet(childNode, typeName)
    return child(childNode):GetComponent(typeName)
end

function findPanel(str)
    local obj = find(str)
    if obj == nil then
        error(str .. " is null")
        return nil
    end
    return obj:GetComponent("BaseLua")
end

function ReloadFile(file_path)
    package.loaded[file_path] = nil    -- 消除载入记录
    return require(file_path)               -- 重新加载lua文件
end

function UnLoadLuaFiles(config)
    for i, v in ipairs(config) do
        package.loaded[v] = nil
        package.preload[v] = nil
    end
end

function LoadLuaFiles(config)
    for i, v in ipairs(config) do
        require(v)
    end
end

--播放指定音效，在同一时刻点击音效不播放
function PlaySoundWithoutClick(sound)
    SoundManager.PlaySound(sound)
    Framework.PlayClickSoundThisTime = false
end

-- 连续弹出文字
-- 1 -- 使用正常Tip
-- 2 -- 使用带颜色的
function PopupText(strTable, delayTime, type)
    local index = 1
    local timer
    timer = Timer.New(function()
        if index == #strTable + 1 then
            timer:Stop()
        else
            if type == 1 then
                PopupTipPanel.ShowTip(strTable[index])
            elseif type == 2 then
                PopupTipPanel.ShowColorTip(strTable[index].name, strTable[index].icon, strTable[index].num)
            end
            index = index + 1
        end
    end, delayTime, #strTable * delayTime * 2)
    timer:Start()
end

function Util_SetHeadImage(url, image, isSelf)
    if image == nil then
        return
    end

    if url == nil then
        Util_SetToDefaultHeadImage(image)
        return
    end

    if url == "" or url == "/0" then
        Util_SetToDefaultHeadImage(image)
        return
    end

    imageDownloadMgr:SetImage_Image(url, image, isSelf)
end

function Util_SetToDefaultHeadImage(image)
    if image == nil then
        return
    end

    local bundleName = "normal_asset"
    local assetName = "Avatar"

    local sprite = Util.LoadSprite("Platform", assetName)
    image.sprite = sprite
end

function TextHelper_Get24HourTimeStr(time)
    if time < 10 then
        return "0" .. time
    else
        return time
    end
end

function PrintWanNum(num)
    if num >= 100000000 then
        return string.format(GetLanguageStrById(12100), string.format("%.1f", num / 100000000))
    elseif num >= 1000000 then
        return tostring(math.floor(num / 10000)) .. GetLanguageStrById(10042)
    else
        return tostring(num)
    end
end
function PrintWanNum2(num)
    if num >= 100000000 then
        return string.format(GetLanguageStrById(12100), string.format("%.1f", num / 100000000))
    elseif num >= 100000 then
        return tostring(math.floor(num / 10000)) .. GetLanguageStrById(10042)
    else
        return tostring(num)
    end
end
function PrintWanNum3(num)
    if num >= 100000000 then
        return string.format(GetLanguageStrById(12100), string.format("%.2f", num / 100000000))
    elseif num >= 100000 then
        return string.format("%.2f",num / 10000) .. GetLanguageStrById(10042)
    else
        return tostring(num)
    end
end
function PrintWanNum5(num,num2)
    if num >= 100000000 then
        return string.format(GetLanguageStrById(12100), string.format("%.2f", num / 100000000)) .."/"..string.format(GetLanguageStrById(12100), string.format("%.2f", num2 / 100000000))
    elseif num >= 100000 then
        return string.format("%.2f",num / 10000) .. GetLanguageStrById(10042).."/"..string.format("%.2f", num2 / 10000) .. GetLanguageStrById(10042)
    else
        return tostring(num).."/"..tostring(num2)
    end
end
function PrintWanNum4(num)
    if num >= 10000 then
        return tostring(math.floor(num / 10000)) .. GetLanguageStrById(10042)
    else
        return tostring(num)
    end
end

function PrintWanNum6(num)
    if num >= 1000000000 then
        return string.format("%.2f",num / 1000000000) .. GetLanguageStrById(23166)
    elseif num >= 1000000 then
        return string.format("%.2f",num / 1000000) .. GetLanguageStrById(23165)
    elseif num >= 10000 then
        return string.format("%.1f",num / 10000) .. GetLanguageStrById(10042)
    else
        return tostring(num)
    end
end

function PrintPowerNum(num)
    if num >= 100000000 then
        return string.format(GetLanguageStrById(12100), string.format("%.1f", num / 100000000))
    elseif num >= 1000000 then
        return tostring(math.floor(num / 10000)) .. GetLanguageStrById(10042)
    else
        return tostring(num)
    end
end

--判断两个时间在同一天
function Util_Check_insameday(time1, time2)
    local date1 = os.date("*t", time1)
    local date2 = os.date("*t", time2)
    if date1.year == date2.year and date1.month == date2.month and date1.day == date2.day then
        return true
    end
    return false
end

--判断两个时间在同一个月
function Util_Check_insamemonth(time1, time2)
    local date1 = os.date("*t", time1)
    local date2 = os.date("*t", time2)
    if date1.year == date2.year and date1.month == date2.month then
        return true
    end
    return false
end

--判断两个时间在同一星期
function Util_Check_insameweek(time1, time2)
    local week_second = 7 * 24 * 3600
    local time_zero = os.time { year = 2015, month = 1, day = 5, hour = 0, min = 0, sec = 0 }
    local time1_tran = time1 - time_zero
    local time2_tran = time2 - time_zero
    local week1 = math.floor(time1_tran / week_second)
    local week2 = math.floor(time2_tran / week_second)

    if week1 == week2 then
        return true
    end
    return false
end
--秒转换成文字对应时间
function GetTimeStrBySeconds(_seconds)
    return os.date(GetLanguageStrById(10779), _seconds)
end
--秒转换成文字对应时间 只有分秒
function GetTimeMaoHaoStrBySeconds(_seconds)
    return os.date("%M:%S", _seconds)
end

--当前时间转换成周几
function GetTimeWeekBySeconds(servertime)
    local cruWeek = os.date("*t", servertime).wday - 1
    if cruWeek == 0 then
        GetLanguageStrById(50137)
    elseif cruWeek == 1 then
        GetLanguageStrById(50138)
    elseif cruWeek == 2 then
        GetLanguageStrById(50139)
    elseif cruWeek == 3 then
        GetLanguageStrById(50140)
    elseif cruWeek == 4 then
        GetLanguageStrById(50141)
    elseif cruWeek == 5 then
        GetLanguageStrById(50142)
    elseif cruWeek == 6 then
        GetLanguageStrById(50143)
    end
end

function PrintTable(root)
    local cache = { [root] = "." }
    local function _dump(t, space, name)
        if type(t) == "table" then
            local temp = {}
            for k, v in pairs(t) do
                local key = tostring(k)
                if cache[v] then
                    tinsert(temp, "+" .. key .. " {" .. cache[v] .. "}")
                elseif type(v) == "table" then
                    local new_key = name .. "." .. key
                    cache[v] = new_key
                    tinsert(temp, "+" .. key .. _dump(v, space .. (next(t, k) and "|" or " ") .. srep(" ", #key), new_key))
                else
                    tinsert(temp, "+" .. key .. " [" .. tostring(v) .. "]")
                end
            end
            return tconcat(temp, "\n" .. space)
        end
    end
    print(_dump(root, "", ""))
end

local isPcall = true
--用于查找错误用
function MyPCall(func)
    if not isPcall then
        func()
        return
    end
    local flag, msg = pcall(func)
    if not flag then
        Util.LogError(msg)
    end
end

function PlayUIAnims(gameObject, callback)
    local anims = gameObject:GetComponentsInChildren(typeof(PlayFlyAnim))
    if anims.Length > 0 then
        for i = 0, anims.Length - 1 do
            anims[i]:PlayAnim(false, callback)
        end
    end
end

function PlayUIAnimBacks(gameObject, callback)
    local anims = gameObject:GetComponentsInChildren(typeof(PlayFlyAnim))
    if anims.Length > 0 then
        for i = 0, anims.Length - 1 do
            anims[i]:PlayHideAnim(callback)
        end
    end
end

function PlayUIAnim(gameObject, callback)
    local anim = gameObject:GetComponent(typeof(PlayFlyAnim))
    if anim then
        anim:PlayAnim(false, callback)
    end
end

function PlayUIAnimBack(gameObject, callback)
    --local anim = gameObject:GetComponent(typeof(PlayFlyAnim))
    local anim = gameObject:GetComponent("PlayFlyAnim")
    if anim then
        anim:PlayHideAnim(callback)
    end
end

--地图uv坐标
function Map_UV2Pos(u, v)
    return u * 256 + v
end
--地图uv坐标
function Map_Pos2UV(pos)
    return math.floor(pos / 256), pos % 256
end

-- 公会地图坐标精细化处理
function GuildMap_UV2Pos(u, v)
    -- return u * 256 + v
    local _u = math.floor(u *100)
    local _v = math.floor(v *100)
    return _u * 25600 + _v
end
function GuildMap_Pos2UV(pos)
    -- return math.floor(pos / 256), pos % 256
    local _u = math.floor(pos/25600)/100
    local _v = pos%25600/100
    return math.round(_u), math.round(_v), _u, _v
end

--把英雄星级父对象和星级传过来  type 1  第6-11个预设   type 2  第12-16个预设 prefabAligment 1 左对齐 2 居中 默认居中
--> _scale 为spacing
function SetHeroStars(starGrid, star, scale)
    scale = scale or 1
    local starPre
    if Util.GetGameObject(starGrid, "starGridMiddle") then
        starPre = Util.GetGameObject(starGrid, "starGridMiddle")
    else
        local prefab = resMgr:LoadAsset("starGridMiddle")
        starPre = GameObject.Instantiate(prefab, Vector3.zero, Quaternion.identity, starGrid.transform)
        starPre:SetActive(true)
        starPre.name = "starGridMiddle"
        starPre:GetComponent("RectTransform").anchoredPosition = Vector3.zero
        starPre:GetComponent("RectTransform").localScale = Vector3.one * scale
        -- starPre.transform:SetAsFirstSibling()
    end

    local starIcon = Util.GetGameObject(starPre,"starIcon"):GetComponent("Image")
    starIcon.sprite = Util.LoadSprite("cn2-X1_tongyong_xingji_"..star)
end

function SetHeroBg(bg, frame, quality, star)
    if star <= 5 then
        bg:GetComponent("Image").sprite = Util.LoadSprite(X1GetHeroCardBgStarBgImage[star])
        frame:GetComponent("Image").sprite = Util.LoadSprite(X1GetHeroCardFrameStarByImage[star])
    else
        bg:GetComponent("Image").sprite = Util.LoadSprite(X1GetHeroCardBgStarBgImage[10])
        frame:GetComponent("Image").sprite = Util.LoadSprite(X1GetHeroCardFrameStarByImage[10])
    end
end

--把英雄星级父对象和星级传过来
local star2index = {
    [1] = {3},
    [2] = {2, 4},
    [3] = {2, 3, 4},
    [4] = {1, 2, 4, 5},
    [5] = {1, 2, 3, 4, 5}
}
function SetCardStars(starGrid, star)
    for i = 1, 15 do
        starGrid.transform:GetChild(i - 1).gameObject:SetActive(false)
    end
    if star < 6 then
        for _, i in ipairs(star2index[star]) do
            starGrid.transform:GetChild(i - 1).gameObject:SetActive(true)
        end
    elseif star > 5 and star < 10 then
        for _, i in ipairs(star2index[star-5]) do
            starGrid.transform:GetChild(5 + i - 1).gameObject:SetActive(true)
        end
    elseif star > 9 then
        starGrid.transform:GetChild(star).gameObject:SetActive(true)
    end
end
-- 在给定节点下加载预设, 返回实例化的预设
function newObjToParent(prefab, parent)
    local go = newObject(prefab)
    go.transform:SetParent(parent.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero
    go:SetActive(true)
    return go
end

-- 清除节点下所有的子节点
function ClearChild(parent)
    Util.ClearChild(parent.transform)
end

-- 加载一个商店使用的item
function AddShopItem(parent, itemId, shopType)
    local item = SubUIManager.Open(SubUIConfig.ShopItemView, parent.transform)
    item:OnOpen(itemId, shopType)
    return item
end

-- 根据ID返回物品的Icon，配置数据在artResourceConfig中
function SetIcon(id)
    if not id or id == 0 then
        return
    end

    local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
    local icon = nil
    local resId = itemConfig[id].ResourceID
    if not resId then
        return
    end
    local resPath = GetResourcePath(resId)
    if not resPath then
        return
    end
    icon = Util.LoadSprite(resPath)
    return icon
end

function SetFrame(id)
    if not id or id == 0 then
        return
    end

    local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
    local icon = nil
    local resId = itemConfig[id].Quantity
    if not resId then
        return
    end
    icon = Util.LoadSprite(GetQuantityImageByquality(resId))
    return icon
end

--属性表ID转换表
function GetProIndexByProId(proId)
    local proIndex = 0
    if proId == 1 then
        -- 最大生命
        proIndex = 3
    elseif proId == 2 then
        -- 攻击力
        proIndex = 4
    elseif proId == 3 then
        -- 护甲
        proIndex = 5
    elseif proId == 4 then
        -- 魔抗
        proIndex = 6
    elseif proId == 5 then
        -- 速度
        proIndex = 7
    elseif proId == 6 or proId == 67 or proId == 68 then
        -- 当前生命值
        proIndex = 2
    elseif proId == 51 then
        -- 伤害加成
        proIndex = 8
    elseif proId == 52 then
        -- 伤害减免
        proIndex = 9
    elseif proId == 53 then
        -- 效果命中
        proIndex = 10
    elseif proId == 54 then
        -- 效果抵抗
        proIndex = 11
    elseif proId == 55 then
        -- 暴击率
        proIndex = 12
    elseif proId == 56 then
        -- 暴伤
        proIndex = 13
    elseif proId == 57 then
        -- 回复率
        proIndex = 14
    elseif proId == 101 then
        -- 火焰伤害
        proIndex = 15
    elseif proId == 102 then
        -- 狂风伤害
        proIndex = 16
    elseif proId == 103 then
        -- 碧水伤害
        proIndex = 17
    elseif proId == 104 then
        -- 大地伤害
        proIndex = 18
    elseif proId == 105 then
        -- 神圣伤害
    elseif proId == 106 then
        -- 黑暗伤害
    elseif proId == 107 then
        -- 火焰抗性
    elseif proId == 108 then
        -- 狂风抗性
    elseif proId == 109 then
        -- 碧水抗性
    elseif proId == 110 then
        -- 大地抗性
    elseif proId == 111 then
        -- 神圣抗性
    elseif proId == 112 then
        -- 黑暗抗性
    end

    return proIndex
end

--逐渐显示对应文字内容，若在此期间点击屏幕，则立刻显示完文字内容
function ShowText(go, str, duration, callBack)
    local text = go:GetComponent("Text")
    text.text = ""
    local tween = text:DOText(str, duration)
    local isClick = false
    tween:OnUpdate(function()
        if Input.GetMouseButtonDown(0) then
            isClick = true
        end
        if isClick then
            if tween then
                tween:Kill()
                go:GetComponent("Text").text = str
                if callBack then
                    callBack()
                end
            end
        end
    end)
    tween:OnComplete(callBack)
end

-- 将秒转换成分：秒格式返回
function SetTimeFormation(seconds)

    local str = ""
    local ten_minute = math.modf(seconds / 600)
    local minute = math.modf(seconds / 60) % 10
    local ten_second = math.modf(seconds / 10) % 6
    local second = seconds % 10
    str = ten_minute .. minute .. " : " .. ten_second .. second
    return str
end

function Dump(data, showMetatable, lastCount)
    if type(data) == "table" then
        --Format
        local count = lastCount or 0
        count = count + 1

        local B2 = ""
        for i = 1, count do
            B2 = B2 .. "   "
        end
       
        --Metatable
        if showMetatable then
            local blank = "  "
            for i = 1, count do
                blank = blank .. "   "
            end
            local mt = getmetatable(data)
           

            Dump(mt, showMetatable, count)
        end
        --Key
        for key, value in pairs(data) do
            local blank = "      "
            for i = 1, count do
                blank = blank .. "   "
            end
            if type(key) == "string" then
               

            elseif type(key) == "number" then
               
            else
               
            end
            Dump(value, showMetatable, count)
        end
        --Format
        local B0 = "    "
        for i = 1, lastCount or 0 do
            B0 = B0 .. "   "
        end
       
    end
    --Format
    if not lastCount then
       
    end
end

function GetStr(data)
    local str = ""
    if type(data) ~= "table" then
        --Value
        if type(data) == "string" then
            str = ("\"" .. data .. "\"")
        elseif data == nil then
            str = "nil"
        else
            str = (string.format("%s", data))
        end
    end
    return str
end

---获得未指定的英雄头像名字
---@param quality any
---@return string
function GetNoTargetHero(quality)
    if quality == 3 then
        return "cn2-X1_icon_3xingyingxiongsuipian"
    elseif quality == 4 then
        return "cn2-X1_icon_4xingyingxiongsuipian"
    elseif quality == 5 then
        return "cn2-X1_icon_5xingyingxiongsuipian"
    else
        return "cn2-X1_icon_6xingyingxiongsuipian"
    end
end

--通过item稀有度读取背景框
function GetQuantityImageByquality(quality,star)
    if star  then--and star > 5
        if star == 1 then
            return "cn2-X1_tongyong_daojukuang_01"
        elseif star == 2 then
            return "cn2-X1_tongyong_daojukuang_02"
        elseif star == 3 then
            return "cn2-X1_tongyong_daojukuang_03"
        elseif star == 4 then
            return "cn2-X1_tongyong_daojukuang_04"
        elseif star == 5 then
            return "cn2-X1_tongyong_daojukuang_05"
        elseif star >= 6 and star <= 10 then
            return "cn2-X1_tongyong_daojukuang_06"
        elseif star > 10 then
            return "cn2-X1_tongyong_daojukuang_06"
        end
     else
         if quality == 0 or quality == 1 then
             return "cn2-X1_tongyong_daojukuang_01"
         elseif quality == 2 then
             return "cn2-X1_tongyong_daojukuang_02"
         elseif quality == 3 then
             return "cn2-X1_tongyong_daojukuang_03"
         elseif quality == 4 then
             return "cn2-X1_tongyong_daojukuang_04"
         elseif quality == 5 then
             return "cn2-X1_tongyong_daojukuang_05"
         elseif quality == 6 then
             return "cn2-X1_tongyong_daojukuang_06"
         elseif quality >= 7 then
             return "cn2-X1_tongyong_daojukuang_06"
         end
     end
end

--通过item稀有度读取底板
function GetQuantityBgImageByquality(quality,star)
    if star  then--and star > 5
        if star == 1 then
            return "cn2-X1_tongyong_yingxiongkuangdiban_01"
        elseif star == 2 then
            return "cn2-X1_tongyong_yingxiongkuangdiban_02"
        elseif star == 3 then
            return "cn2-X1_tongyong_yingxiongkuangdiban_03"
        elseif star == 4 then
            return "cn2-X1_tongyong_yingxiongkuangdiban_04"
        elseif star == 5 then
            return "cn2-X1_tongyong_yingxiongkuangdiban_05"
        elseif star >= 6 and star <= 10 then
            return "cn2-X1_tongyong_yingxiongkuangdiban_06"
        elseif star > 10 then
            return "cn2-X1_tongyong_yingxiongkuangdiban_06"
        end
     else
         if quality == 0 or quality == 1 then
             return "cn2-X1_tongyong_yingxiongkuangdiban_01"
         elseif quality == 2 then
             return "cn2-X1_tongyong_yingxiongkuangdiban_02"
         elseif quality == 3 then
             return "cn2-X1_tongyong_yingxiongkuangdiban_03"
         elseif quality == 4 then
             return "cn2-X1_tongyong_yingxiongkuangdiban_04"
         elseif quality == 5 then
             return "cn2-X1_tongyong_yingxiongkuangdiban_05"
         elseif quality == 6 then
             return "cn2-X1_tongyong_yingxiongkuangdiban_06"
         elseif quality >= 7 then
             return "cn2-X1_tongyong_yingxiongkuangdiban_06"
         end
     end
end

--通过item稀有度读取pro底板
function GetQuantityProBgImageByquality(quality,star)
    if star then--and star > 5
        if star == 1 then
            return "cn2-X1_tongyong_daojukuang_zhenying_01"
        elseif star == 2 then
            return "cn2-X1_tongyong_daojukuang_zhenying_02"
        elseif star == 3 then
            return "cn2-X1_tongyong_daojukuang_zhenying_03"
        elseif star == 4 then
            return "cn2-X1_tongyong_daojukuang_zhenying_04"
        elseif star == 5 then
            return "cn2-X1_tongyong_daojukuang_zhenying_05"
        elseif star >= 6 and star <= 10 then
            return "cn2-X1_tongyong_daojukuang_zhenying_06"
        elseif star > 10 then
            return "cn2-X1_tongyong_daojukuang_zhenying_06"
        end
     else
         if quality == 0 or quality == 1 then
             return "cn2-X1_tongyong_daojukuang_zhenying_01"
         elseif quality == 2 then
             return "cn2-X1_tongyong_daojukuang_zhenying_02"
         elseif quality == 3 then
             return "cn2-X1_tongyong_daojukuang_zhenying_03"
         elseif quality == 4 then
             return "cn2-X1_tongyong_daojukuang_zhenying_04"
         elseif quality == 5 then
             return "cn2-X1_tongyong_daojukuang_zhenying_05"
         elseif quality == 6 then
             return "cn2-X1_tongyong_daojukuang_zhenying_06"
         elseif quality >= 7 then
             return "cn2-X1_tongyong_daojukuang_zhenying_06"
         end
     end
end

--> 六边形背景
function GetQuantityImageByqualityHexagon(quality, star)
    if star then--and star > 5
        if star == 1 then
            return "cn2-X1_tongyong_daojukuang_dengji_01"
        elseif star == 2 then
            return "cn2-X1_tongyong_daojukuang_dengji_02"
        elseif star == 3 then
            return "cn2-X1_tongyong_daojukuang_dengji_03"
        elseif star == 4 then
            return "cn2-X1_tongyong_daojukuang_dengji_04"
        elseif star == 5 then
            return "cn2-X1_tongyong_daojukuang_dengji_05"
        elseif star >= 6 and star <= 10 then
            return "cn2-X1_tongyong_daojukuang_dengji_06"
        elseif star > 10 then
            return "cn2-X1_tongyong_daojukuang_dengji_06"
        end
    else
         if quality == 0 or quality == 1 then
             return "cn2-X1_tongyong_daojukuang_dengji_01"
         elseif quality == 2 then
             return "cn2-X1_tongyong_daojukuang_dengji_02"
         elseif quality == 3 then
             return "cn2-X1_tongyong_daojukuang_dengji_03"
         elseif quality == 4 then
             return "cn2-X1_tongyong_daojukuang_dengji_04"
         elseif quality == 5 then
             return "cn2-X1_tongyong_daojukuang_dengji_05"
         elseif quality == 6 then
             return "cn2-X1_tongyong_daojukuang_dengji_06"
         elseif quality >= 7 then
             return "cn2-X1_tongyong_daojukuang_dengji_06"
         end
     end
end

function GetCardFrame(star)
    if star then
        if star == 1 then
            return "cn2-X1_tongyong_yingxiongkuang_01"
        elseif star == 2 then
            return "cn2-X1_tongyong_yingxiongkuang_02"
        elseif star == 3 then
            return "cn2-X1_tongyong_yingxiongkuang_03"
        elseif star == 4 then
            return "cn2-X1_tongyong_yingxiongkuang_04"
        elseif star == 5 then
            return "cn2-X1_tongyong_yingxiongkuang_05"
        elseif star > 5 then
            return "cn2-X1_tongyong_yingxiongkuang_06"
        end
    end
end

--通过item品质读取tips背景color n1
function GetQuantityTipsColorByQuality(quality)
    if quality == 1 then
        return "N1_tipsbg_beibao_lvse"
    elseif quality == 2 then
        return "N1_tipsbg_beibao_lvse"
    elseif quality == 3 then
        return "N1_tipsbg_beibao_lanse"
    elseif quality == 4 then
        return "N1_tipsbg_beibao_zise"
    elseif quality == 5 then
        return "N1_tipsbg_beibao_chengse"
    elseif quality >= 6 then
        return "N1_tipsbg_beibao_hongse"
    else
        return "N1_tipsbg_beibao_lvse"
    end
end

--通过item稀有度读取背景框
function GetQuantityImageByqualityPoint(quality)
    if quality == 1 then
        return "r_hunyin_zise"
    elseif quality == 2 then
        return "r_hunyin_zise"
    elseif quality == 3 then
        return "r_hunyin_zise"
    elseif quality == 4 then
        return "r_hunyin_zise"
    elseif quality == 5 then
        return "r_hunyin_chengse"
    elseif quality == 6 then
        return "r_hunyin_hongse"
    elseif quality == 7 then
        return "r_hunyin_caise"
    else
        return "r_hunyin_caise"
    end
end

--通过item稀有度读取背景框
function GetQuantityStrByquality(quality)
    if quality == 1 then
        return GetLanguageStrById(10198)
    elseif quality == 2 then
        return GetLanguageStrById(10197)
    elseif quality == 3 then
        return GetLanguageStrById(10196)
    elseif quality == 4 then
        return GetLanguageStrById(10195)
    elseif quality == 5 then
        return GetLanguageStrById(10194)
    elseif quality == 6 then
        return GetLanguageStrById(10193)
    elseif quality == 7 then
        return GetLanguageStrById(10192)
    else
        return GetLanguageStrById(10198)
    end
end

--通过Hero稀有度读取碎片遮罩(小)
function GetHeroChipQuantityImageByquality(quality)
    -- if quality == 1 then
    --     return "PieceMask_white"
    -- elseif quality == 2 then
    --     return "PieceMask_green"
    -- elseif quality == 3 then
    --     return "PieceMask_blue"
    -- elseif quality == 4 then
    --     return "PieceMask_purple"
    -- elseif quality == 5 then
    --     return "PieceMask_goden"
    -- elseif quality >= 6 then
    --     return "PieceMask_red"
    -- end
    return "cn2-X1_tongyong_daojukuang_suipian"
end

--通过Hero稀有度读取背景框(小)
function GetHeroQuantityImageByquality(quality,star)
    if star then--and star > 5
       if star == 1 then
            return "cn2-X1_tongyong_daojukuang_01"
        elseif star == 2 then
            return "cn2-X1_tongyong_daojukuang_02"
        elseif star == 3 then
            return "cn2-X1_tongyong_daojukuang_03"
        elseif star == 4 then
            return "cn2-X1_tongyong_daojukuang_04"
        elseif star == 5 then
            return "cn2-X1_tongyong_daojukuang_05"
        elseif star >= 6 and star <=10 then
            return "cn2-X1_tongyong_daojukuang_06"
        elseif star > 10 then
            return "cn2-X1_tongyong_daojukuang_06"
        end
    else
        if quality == 0 or quality == 1 then
            return "cn2-X1_tongyong_daojukuang_01"
        elseif quality == 2 then
            return "cn2-X1_tongyong_daojukuang_02"
        elseif quality == 3 then
            return "cn2-X1_tongyong_daojukuang_03"
        elseif quality == 4 then
            return "cn2-X1_tongyong_daojukuang_04"
        elseif quality == 5 then
            return "cn2-X1_tongyong_daojukuang_05"
        elseif quality == 6 then
            return "cn2-X1_tongyong_daojukuang_06"
        elseif quality >= 7 then
            return "cn2-X1_tongyong_daojukuang_01"
        end
    end
end

--通过Hero稀有度读取背景框(卡库)外框
function GetHeroCardQuantityWaiImageByquality(quality)
    if quality <= 3 then
        return "r_hero_lankuang"
    elseif quality == 4 then
        return "r_hero_zikuang"
    elseif quality == 5 then
        return "r_hero_huangkuang"
    elseif quality > 5 then
        return "r_hero_huangkuang"
    end
end
-- --通过Hero或异妖稀有度读取资质框
-- function GetQuantityImage(quality)
--     local sprite
--     if quality < 11 then
--         sprite = Util.LoadSprite(AptitudeQualityFrame[1])
--     elseif quality >= 11 and quality < 13 then
--         sprite = Util.LoadSprite(AptitudeQualityFrame[2])
--     elseif quality >= 13 and quality < 15 then
--         sprite = Util.LoadSprite(AptitudeQualityFrame[3])
--     elseif quality >= 15 and quality < 17 then
--         sprite = Util.LoadSprite(AptitudeQualityFrame[4])
--     elseif quality >= 17 and quality < 19 then
--         sprite = Util.LoadSprite(AptitudeQualityFrame[5])
--     end
--     return sprite
-- end

--通过装备位置获得装备位置类型字符串
function GetEquipPosStrByEquipPosNum(_index)
    if _index == 1 then
        return GetLanguageStrById(10427)
    elseif _index == 2 then
        return GetLanguageStrById(12104)
    elseif _index == 3 then
        return GetLanguageStrById(10429)
    elseif _index == 4 then
        return GetLanguageStrById(12105)
    elseif _index == 5 then
        return GetLanguageStrById(22321)
    elseif _index == 6 then
        return GetLanguageStrById(22321)
    end
end

--通过职业获取职业字符串
function GetJobStrByJobNum(_index)
    if _index == 0 then
        return GetLanguageStrById(12108)
    elseif _index == 1 then
        return GetLanguageStrById(12038)
    elseif _index == 2 then
        return GetLanguageStrById(12039)
    elseif _index == 3 then
        return GetLanguageStrById(12040)
    elseif _index == 4 then
        return GetLanguageStrById(12041)
    elseif _index == 5 then
        return GetLanguageStrById(12042)
    end
end

--通过职业获取职业字符串
function GetJobSpriteStrByJobNum(_index)
    if _index == 1 then
        return "cn2-X1_tongyong_yingxiongdingwei_01"
    elseif _index == 2 then
        return "cn2-X1_tongyong_yingxiongdingwei_03"
    elseif _index == 3 then
        return "cn2-X1_tongyong_yingxiongdingwei_02"
    elseif _index == 4 then
        return "cn2-X1_tongyong_yingxiongdingwei_04"
    elseif _index == 5 then
        return "N1_icon_tongyong_deguo"
    elseif _index == 6 then
        return "N1_icon_tongyong_deguo"
    else
        return "N1_icon_tongyong_deguo"
    end
end

--角色定位ID 获取角色定位背景图片
function GetHeroPosBgStr(_i)
    if _i == 1 then
        return "r_hero_roudundi"
    elseif _i == 2 then
        return "r_hero_shuchudi"
    elseif _i == 3 then
        return "r_hero_kongzhidi"
    elseif _i == 4 then
        return "r_hero_fuzhudi"
    end
end

--根据角色定位Id 获取角色定位图
function GetHeroPosStr(_i)
    if _i == 1 then
        return "r_hero_roudunbiao"
    elseif _i == 2 then
        return "r_hero_shuchubiao"
    elseif _i == 3 then
        return "r_hero_konghzibiao"
    elseif _i == 4 then
        return "r_hero_fuzhubiao"
    end
end

--获取技能类型 data 当前技能数据
function GetSkillType(data)
    local SkillIconType={"N1_iconbg_tongyong_baise","N1_iconbg_tongyong_baise","N1_iconbg_tongyong_baise"}
    if data.skillConfig.Type == SkillType.Pu then
        return SkillIconType[SkillType.Pu]--普技
    elseif data.skillConfig.Type == SkillType.Jue then
        return SkillIconType[SkillType.Jue]--绝技
    elseif data.skillConfig.Type == SkillType.Bei then
        return SkillIconType[SkillType.Bei]--被动技
    end
end

-- --通过角色属性获取角色属性图标
-- function GetProStrImageByProNum(_index)
--     if _index == 1 then
--         return "N1_groupicon_tongyongweixuanzhong_yingguo" 
--     elseif _index == 2 then
--         return "N1_groupicon_tongyongweixuanzhong_sulian" 
--     elseif _index == 3 then
--         return "N1_groupicon_tongyongweixuanzhong_faguo" 
--     elseif _index == 4 then
--         return "N1_groupicon_tongyongweixuanzhong_meiguo" 
--     elseif _index == 5 then
--         return "N1_groupicon_tongyongweixuanzhong_deguo" 
--     else
--         return "N1_groupicon_tongyongweixuanzhong_quanbu" 
--     end
-- end

--通过角色属性获取角色属性图标
function GetProStrImageByProNum(_index)
    if _index == 1 then
        return "cn2-X1_tongyong_zhenying_04"
    elseif _index == 2 then
        return "cn2-X1_tongyong_zhenying_02"
    elseif _index == 3 then
        return "cn2-X1_tongyong_zhenying_03"
    elseif _index == 4 then
        return "cn2-X1_tongyong_zhenying_06"
    elseif _index == 5 then
        return "cn2-X1_tongyong_zhenying_05"
    elseif _index == 6 then
        return "cn2-X1_tongyong_zhenying_07"
    else
        return GetPictureFont("cn2-X1_tongyong_zhenying_01")
    end
end

--通过角色属性获取角色属性图标
function GetProStrImageByProNum2(_index)
    if _index == 1 then
        return "cn2-X1_tongyong_zhenying_04"
    elseif _index == 2 then
        return "cn2-X1_tongyong_zhenying_02"
    elseif _index == 3 then
        return "cn2-X1_tongyong_zhenying_03"
    elseif _index == 4 then
        return "cn2-X1_tongyong_zhenying_06"
    elseif _index == 5 then
        return "cn2-X1_tongyong_zhenying_05"
    elseif _index == 6 then
        return "cn2-X1_tongyong_zhenying_07"
    else
        return GetPictureFont("cn2-X1_tongyong_zhenying_01")
    end
end

--通过角色属性获取角色属性图标
function GetBigProStrImageByProNum(_index)
    if _index == 1 then
        return "cn2-X1_tongyong_zhenying_04"
    elseif _index == 2 then
        return "cn2-X1_tongyong_zhenying_02"
    elseif _index == 3 then
        return "cn2-X1_tongyong_zhenying_03"
    elseif _index == 4 then
        return "cn2-X1_tongyong_zhenying_06"
    elseif _index == 5 then
        return "cn2-X1_tongyong_zhenying_05"
    elseif _index == 5 then
        return "cn2-X1_tongyong_zhenying_07"
    else
        return GetPictureFont("cn2-X1_tongyong_zhenying_01")
    end
end

--通过装备位置获得装备位置类型字符串
function GetQuaStringByEquipQua(_Qua)
    --
    if _Qua == 1 then
        return GetLanguageStrById(12109)
    elseif _Qua == 2 then
        return GetLanguageStrById(12110)
    elseif _Qua == 3 then
        return GetLanguageStrById(12111)
    elseif _Qua == 4 then
        return GetLanguageStrById(12112)
    elseif _Qua == 5 then
        return GetLanguageStrById(12113)
    elseif _Qua == 6 then
        return GetLanguageStrById(12114)
    elseif _Qua == 7 then
        return GetLanguageStrById(12115)
    end
end

--通过item稀有度获取改颜色的文字
function GetStringByEquipQua(_Qua, _Str)
    if _Qua == 1 then
        return string.format("<color=#d1c3afFF>%s</color>", _Str)
    elseif _Qua == 2 then
        return string.format("<color=#9FFF88FF>%s</color>", _Str)
    elseif _Qua == 3 then
        return string.format("<color=#88E4FFFF>%s</color>", _Str)
    elseif _Qua == 4 then
        return string.format("<color=#F088FFFF>%s</color>", _Str)
    elseif _Qua == 5 then
        return string.format("<color=#FFBA88FF>%s</color>", _Str)
    elseif _Qua == 6 then
        return string.format("<color=#FF6868FF>%s</color>", _Str)
    else
        return string.format("<color=#FFEDA1FF>%s</color>", _Str)
    end
end

--冒险通过区域序号取得区域名称美术字图标
function GetAreaNameIconByAreaNumer(index)
    if index == 1 then
        return "r_guaji_qiyuanzhidi"
    elseif index == 2 then
        return "r_guaji_yiwangzhilu"
    elseif index == 3 then
        return "r_guaji_houhuizhishi"
    elseif index == 4 then
        return "r_guaji_zuifashengdian"
    elseif index == 5 then
        return "r_guaji_qidaoshengsuo"
    elseif index == 6 then
        return "r_guaji_youjieyehuo"
    elseif index == 7 then
        return "r_guaji_wushengmishi"
    elseif index == 8 then
        return "r_guaji_wanshenghuanghun"
    end

end

--根据英雄品质获取抽卡英雄颜色
function GetColorByHeroQua(_Qua)
    if _Qua == 1 then
        return Color.New(152/255,99/255,103/255,1)
    elseif _Qua == 2 then
        return Color.New(166/255,238/255,165/255,1)
    elseif _Qua == 3 then
        return Color.New(23/255,158/255,255/255,1)
    elseif _Qua == 4 then
        return Color.New(209/255,112/255,255/255,1)
    elseif _Qua == 5 then
        return Color.New(255/255,156/255,42/255,1)
    elseif _Qua == 6 then
        return Color.New(255/255,73/255,73/255,1)
    elseif _Qua >= 7 then
        return Color.New(255/255,73/255,73/255,1)
    end
end

--根据英雄品质获取抽卡英雄进入时颜色
function GetColorByHeroEnterQua(_Qua)
    if _Qua == 1 then
        return Color.New(150/255,143/255,154/255,0)
    elseif _Qua == 2 then
        return Color.New(166/255,238/255,165/255,0)
    elseif _Qua == 3 then
        return Color.New(16/255,58/255,255/255,0)
    elseif _Qua == 4 then
        return Color.New(209/255,112/255,255/255,0)
    elseif _Qua == 5 then
        return Color.New(255/255,156/255,42/255,0)
    elseif _Qua == 6 then
        return Color.New(255/255,73/255,73/255,0)
    elseif _Qua == 7 then
        return Color.New(255/255,73/255,73/255,0)
    end
end

--- N钟，N时，N天
function GetLeftTimeStrByDeltaTime(deltaTime)
    if deltaTime > 86400 then
        return math.floor(deltaTime / 86400) .. GetLanguageStrById(10021)
    end
    if deltaTime > 3600 then
        return math.floor(deltaTime / 3600) .. GetLanguageStrById(12116)
    end
    if deltaTime > 60 then
        return math.floor(deltaTime / 60) .. GetLanguageStrById(12117)
    end
    return math.floor(deltaTime)..GetLanguageStrById(10364)
end
function GetLeftTimeStrByDeltaTime2(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = math.floor(second % 60)
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    if second > 86400 then
        return day .. GetLanguageStrById(10021)..hour ..GetLanguageStrById(10993)
    end
    if second > 3600 then
        return hour..GetLanguageStrById(10993)..minute .. GetLanguageStrById(12117)
    end
    return minute .. GetLanguageStrById(12117) .. sec .. GetLanguageStrById(10364)
end
--- 获取经历的时间字符串
--- 刚刚，N分钟前，N小时前，N天前
function GetDeltaTimeStrByDeltaTime(deltaTime)
    if deltaTime > 86400 then
        return math.floor(deltaTime / 86400) .. GetLanguageStrById(10827)
    end
    if deltaTime > 3600 then
        return math.floor(deltaTime / 3600) .. GetLanguageStrById(10826)
    end
    if deltaTime > 60 then
        return math.floor(deltaTime / 60) .. GetLanguageStrById(10825)
    end
    return GetLanguageStrById(10824)
end
function GetDeltaTimeStr(timestamp)
    local curTimeStemp = GetTimeStamp()
    local deltaTime = curTimeStemp - timestamp
    return GetDeltaTimeStrByDeltaTime(deltaTime)
end
--- 计算公式 a*x^3 + b*x^2 + c*x +d
---     1、   CalculateCostCount(x, a, b, c, d)
---     2、   CalculateCostCount(x, array)
---             array  为按顺序存储a, b, c, d值的数组
---
function CalculateCostCount(x, ...)
    if not x then
        return
    end
    local args = { ... }
    if type(args[1]) == "table" then
        args = args[1]
    end
    if type(args[1]) ~= "number" then
        return
    end

    local a = args[1]
    local b = args[2]
    local c = args[3]
    local d = args[4]
    local cost = math.pow(x, 3) * a + math.pow(x, 2) * b + x * c + d
    return cost
end

--获取服务器当前星期几
function GetSeverWeek()
    local severTime = GetTimeStamp()  -- 获取时间戳（假设是秒级）
    
    -- 创建 1970-01-01 起始时间（不使用 DateTimeKind）
    local epoch = System.DateTime(1970, 1, 1, 0, 0, 0)
    
    -- 添加时间戳得到 UTC 时间
    local utcTime = epoch:AddSeconds(severTime)
    
    -- 转换为本地时间后获取星期
    return utcTime:ToLocalTime().DayOfWeek:ToInt()
end

--- 获取当前时间戳
function GetTimeStamp()
    return PlayerManager.serverTime
end

--- 获取当前时间到一天中某时的剩余时间（24小时制）
function CalculateSecondsNowTo_N_OClock(n)
    local curTimeStemp = GetTimeStamp()
    --- 标准时间戳从1970年1月1日8点开始，加上八个小时的秒数，使其从0点开始
    --- 8*60*60 = 28800
    --- 24*60*60 = 86400

    local now = os.time()
    local timeZone = os.difftime(now, os.time(os.date("!*t", now)))

    local todayPassSeconds = (curTimeStemp + timeZone) % 86400
    local targetSeconds = n * 3600 --- 60*60 = 3600
    if todayPassSeconds <= targetSeconds then
        return targetSeconds - todayPassSeconds
    else
        -- 如果已经过去了，则计算到第二天这个时间点需要的秒数
        return targetSeconds + 86400 - todayPassSeconds
    end
end

function TimeToFelaxible(second)--大于一天用多少天多少小时，小于一天用00：00：00
    if second <= 86400 then
        if not second or second < 0 then
            return "00:00:00"
        end
        local _sec = second % 60
        local allMin = math.floor(second / 60)
        local _min = allMin % 60
        local _hour = math.floor(allMin / 60)
        return string.format("%02d:%02d:%02d", _hour, _min, _sec), _hour, _min, _sec
    elseif second > 86400 then
        local day = math.floor(second / (24 * 3600))
        local minute = math.floor(second / 60) % 60
        local sec = second % 60
        local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
        return string.format(GetLanguageStrById(12278),day, hour)
    end

end

--- 将一段时间转换为天时分秒
function TimeToDHMS(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(10548),day, hour, minute, sec)
end

--- 将一段时间转换为天时
function TimeToDH(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(12278),day, hour)
end

--- 将一段时间转换为时
function TimeToH(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(11751), hour)
end
--- 将一段时间转换为时分秒
-- function TimeToHMS(t)
--     if not t or t < 0 then
--         return "00:00:00"
--     end
--     local _sec = t % 60
--     local allMin = math.floor(t / 60)
--     local _min = allMin % 60
--     local _hour = math.floor(allMin / 60)
--     return string.format("%02d:%02d:%02d", _hour, _min, _sec), _hour, _min, _sec
-- end
function TimeToHMS(t)
    if not t or t < 0 then
        return "<color=#FF0000>00:00:00</color>"
    end
    local _sec = t % 60
    local allMin = math.floor(t / 60)
    local _min = allMin % 60
    local _hour = math.floor(allMin / 60)
    local timeStr = string.format("%02d:%02d:%02d", _hour, _min, _sec)

    -- 少于30分钟时变红
    if t <= 1800 then
        return string.format("<color=#FF0000>%s</color>", timeStr), _hour, _min, _sec
    else
        return timeStr, _hour, _min, _sec
    end
end

--- 将一段时间转换为分秒
function TimeToMS(t)
    if not t or t < 0 then
        return "00:00"
    end
    local _sec = t % 60
    local _min = math.floor(t / 60)
    return string.format("%02d:%02d", _min, _sec)
end

-- 将一段时间转换为年月日时分秒
function TimeToYMDHMS(t)
    if not t or t < 0 then
        return 0
    end
    return os.date("%Y年%m月%d日 %H:%M:%S", t)
end

--- 将一段时间转换为时分
function TimeToHM(t)
    if not t or t < 0 then
        return "00:00"
    end
    local allMin = math.floor(t / 60)
    local _min = allMin % 60
    local _hour = math.floor(allMin / 60)
    return string.format("%02d:%02d", _hour, _min)
end

--- 获取今天某时间点时间戳
function Today_N_OClockTimeStamp(n)
    local currentTime = math.floor(GetTimeStamp())
    local tab = os.date("*t", currentTime)
    tab.hour = n
    tab.min = 0
    tab.sec = 0
    local N_TimeStamp = os.time(tab)
    return N_TimeStamp
end

----- 时效类时间(服务器按照每天凌晨的0点为起始的一天)
function GetTimePass(timeValue)
    local tab = os.date("*t", timeValue)
    tab.hour = 0
    tab.min = 0
    tab.sec = 0

    local tab2 = os.date("*t", timeValue)
    tab2.hour = 24
    tab2.min = 0
    tab2.sec = 0
    local timeStartSum = os.time(tab2)
    --0点
    local forwardDay
    local zeroTimeStamp = os.time(tab)
    if timeValue > zeroTimeStamp and timeValue < timeStartSum then
        forwardDay = 1
    else
        forwardDay = 0
    end
    local dayPass = math.ceil((GetTimeStamp() - timeStartSum) / 86400)
    return (dayPass + forwardDay) > 3 and 3 or (dayPass + forwardDay)
end

---时间格式化接口
function GetTimeShow(data)
    local year = math.floor(os.date("%Y", data))
    local month = math.floor(os.date("%m", data))
    local day = math.floor(os.date("%d", data))
    local time = year .. "." .. month .. "." .. day
    return time
end

--转换年月日
function GetYearMonthDay(data)
    local year = math.floor(os.date("%Y", data))
    local month = math.floor(os.date("%m", data))
    local day = math.floor(os.date("%d", data))
    return year, month, day
end

--获取两个日期之间的间隔天数
function GetDataToDataBetweenDays(time1, time2)
    local year, month, day = GetYearMonthDay(time1)
    local dtDay1 = System.DateTime.New(year, month, day)
    local year2, month2, day2 = GetYearMonthDay(time2)
    local dtDay2 = System.DateTime.New(year2, month2, day2)
    local time = System.TimeSpan.New(dtDay1.Ticks - dtDay2.Ticks).Days
    return time
end

---obj必须是userdata(c#对象)
function IsNull(obj)
    return obj == nil or tolua.isnull(obj) 
end

------- 红点相关 ----------
-- 绑定红点物体
function BindRedPointObject(rpType, rpObj)
    RedpotManager.BindObject(rpType, rpObj)
end

-- 清除红点上绑定的所有物体
function ClearRedPointObject(rpType, rpObj)
    RedpotManager.ClearObject(rpType, rpObj)
end

-- 强制改变红点状态（不建议使用）
function ChangeRedPointStatus(rpType, state)
    RedpotManager.SetRedPointStatus(rpType, state)
end

-- 重置服务器红点状态到隐藏状态
function ResetServerRedPointStatus(rpType)
    RedpotManager.SetServerRedPointStatus(rpType, RedPointStatus.Hide)
end

-- 检测红点显示
function CheckRedPointStatus(rpType)
    RedpotManager.CheckRedPointStatus(rpType)
end

-------------------------
--统用属性展示
function GetPropertyFormatStr(type, value)
    if type == 1 then
        return value
    else
        if value % 100 == 0 then
            return string.format("%d%%", value / 100)
        else
            return string.format("%.2f%%", value / 100)
        end
    end
end
--统用属性展示
function GetPropertyFormatStrOne(type, value)
    if type == 1 then
        return value
    else
        if value % 100 == 0 then
            return string.format("%d%%", value / 100)
        else
            return string.format("%.1f%%", value / 100)
        end
    end
end
--装备专属属性展示
function GetEquipPropertyFormatStr(type, value)
    if type == 1 then
        return value
    else
        if value / 100 > 1 then
            return string.format("%d%%", value / 100)
        else
            return string.format("%d%%", 1)
        end
    end
end
-- 将秒转换成显示使用的时间
function FormatSecond(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)

    return string.format(GetLanguageStrById(12118), day, hour, minute, sec)
end

-- 将时间戳转换为用于显示的日期字符串
function TimeStampToDateStr(timestamp)
    local date = os.date("*t", timestamp)
    local cdate = os.date("*t", GetTimeStamp())
    if date.year == cdate.year and date.month == cdate.month and date.day == cdate.day then
        return string.format("%02d:%02d", date.hour, date.min)
    end
    return string.format(GetLanguageStrById(12119), date.year, date.month, date.day, date.hour, date.min)
end
-- 将时间戳转换为用于显示的日期字符串(时分秒)
function TimeStampToDateStr3(second)
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - sec - minute * 60) / 3600)

    return string.format("%02d:%02d:%02d", hour, minute, sec)
end

--- 根据id获取资源
function GetResourcePath(id)
    local data = ConfigManager.TryGetConfigData(ConfigName.ArtResourcesConfig, id)
    --> 无资源返回固定资源 找表问题
    if data == nil or data.Name == nil or data.Name == "" then
        return "N1_btn_tongyong_guanbi"
    else
        return data.Name
    end
    -- return ConfigManager.TryGetConfigData(ConfigName.ArtResourcesConfig, id).Name
end

--> 获取资源名 错误返回X
function GetResourceStr(str)
    if str == nil or str == "" then
        return "N1_btn_tongyong_guanbi"
    end
    return str
end

--- 获取玩家头像资源
function GetPlayerHeadSprite(headId)
    if headId == 0 then
        if PlayerManager.sex then
           headId = 71000
        else
           headId = 70999
        end
     end
    local head = ConfigManager.GetConfigData(ConfigName.ItemConfig, headId)
    return Util.LoadSprite(GetResourcePath(head.ResourceID))
end

--- 获取玩家头像框资源
function GetPlayerHeadFrameSprite(frameId)
    if frameId == 0 then frameId = 80000 end
    local frame = ConfigManager.GetConfigData(ConfigName.ItemConfig, frameId)
    return Util.LoadSprite(GetResourcePath(frame.ResourceID))
end

--是否弹出快捷购买面板
function PopQuickPurchasePanel(type, needNum)
    local ownNumber = BagManager.GetItemCountById(type)
    if ownNumber >= needNum then
        return false
    else
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = type })
        return true
    end
end

----- SDK数据上报
----- @param context
---- {
----   type,   -- required, 调用时机
---- }
function SubmitExtraData(context)
    if not AppConst.isSDKLogin then
        return
    end
    -- local params = SDK.SDKSubmitExtraDataArgs.New()
    -- params.dataType = context.type
    -- params.serverID = tonumber(PlayerManager.serverInfo.server_id)
    -- params.serverName = PlayerManager.serverInfo.name
    -- params.zoneID = PlayerManager.serverInfo.server_id
    -- params.zoneName = PlayerManager.serverInfo.name
    -- params.roleID = tostring(PlayerManager.uid)
    -- params.roleName = PlayerManager.nickName
    -- params.roleLevel = tostring(PlayerManager.level)
    -- params.guildID = PlayerManager.familyId
    -- params.Vip = tostring(VipManager.GetVipLevel())
    -- params.moneyNum = BagManager.GetItemCountById(16)
    -- params.roleCreateTime = DateUtils.GetDateTime(PlayerManager.userCreateTime)
    -- params.roleLevelUpTime = context.roleLevelUpTime and DateUtils.GetDateTime(context.roleLevelUpTime) or ""
    -- SDKMgr:SubmitExtraData(params)
end

function ShowConfirmPanel(context)
    UIManager.OpenPanel(UIName.CommonConfirmPanel, context)
end

-- 检测某一面板关闭再抛相应的事件
function CallBackOnPanelClose(uiPanel, func)
    if UIManager.IsOpen(uiPanel) then
        local triggerCallBack
        triggerCallBack = function (panelType, panel)
            if panelType == uiPanel then
                if func then func() end
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    else
        if func then func() end
    end
end

-- 检测某一面板打开再抛相应的事件
function CallBackOnPanelOpen(uiPanel, func)
    if not UIManager.IsOpen(uiPanel) then
        local triggerCallBack
        triggerCallBack = function (panelType, panel)
            if panelType == uiPanel then
                if func then func() end
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, triggerCallBack)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, triggerCallBack)
    else
        if func then func() end
    end
end

-- 通过地图坐标设置物体在UI平面的位置
function SetObjPosByUV(pos)
    local u, v = Map_Pos2UV(pos)
    local v2 = RectTransformUtility.WorldToScreenPoint(TileMapView.GetCamera(), TileMapView.GetLiveTilePos(u, v))
    v2 = v2 / math.min(Screen.width/1080, Screen.height/1920)
    v2.x = v2.x - (Screen.width - UIManager.width) / 2
    v2.y = v2.y - (Screen.height - UIManager.height) / 2
    return v2

end

--获取技能描述    notColor不加颜色
--arrayType desc v c 维数
function GetSkillConfigDesc(cfg, notColor, arrayType)
    local arrayType = arrayType or 2    -- 暂时默认2维
    if arrayType == 1 then
        if cfg.DescColor then
            local ss = {}
            for i = 1, #cfg.DescColor do
                local str
                if cfg.DescColor[i] == 1 then
                    if notColor then
                        str = cfg.DescValue[i]
                    else
                        str = string.format("<color=#FF5D07FF>%s</color>", cfg.DescValue[i])
                    end
                elseif cfg.DescColor[i] == 2 then
                    if notColor then
                        str = cfg.DescValue[i]
                    else
                        str = string.format("<color=#E06328FF>%s</color>", cfg.DescValue[1][i])
                    end
                else
                    str = cfg.DescValue[i]
                end
                ss[i] = str
            end
            return string.format(GetLanguageStrById(cfg.Desc), unpack(ss))
        end
        return GetLanguageStrById(cfg.Desc)
    elseif arrayType == 2 then
        if cfg.DescColor[1] then
            local ss = {}
            for i = 1, #cfg.DescColor[1] do
                local str
                if cfg.DescColor[1][i] == 1 then
                    if notColor then
                        str = cfg.DescValue[1][i]
                    else
                        str = string.format("<color=#5FE027FF>%s</color>", cfg.DescValue[1][i])
                    end
                elseif cfg.DescColor[1][i] == 2 then
                    if notColor then
                        str = cfg.DescValue[1][i]
                    else
                        str = string.format("<color=#E06328FF>%s</color>", cfg.DescValue[1][i])
                    end
                else
                    str = cfg.DescValue[1][i]
                end
                ss[i] = str
            end
            return string.format(GetLanguageStrById(cfg.Desc[1]), unpack(ss))
        end
    elseif arrayType == 3 then  --英雄技能描述做特殊处理
        if not cfg.DescValue then
            return GetLanguageStrById(cfg.Desc[1])
        end
        if cfg.DescColor[1] then
            local ss = {}
            for i = 1, #cfg.DescColor do
                local str
                if cfg.DescColor[i] == 1 then
                    if notColor then
                        str = cfg.DescValue[i]
                    else
                        str = string.format("<color=#FF5D07FF>%s</color>", cfg.DescValue[i])
                    end
                elseif cfg.DescColor[i] == 2 then
                    if notColor then
                        str = cfg.DescValue[i]
                    else
                        str = string.format("<color=#E06328FF>%s</color>", cfg.DescValue[i])
                    end
                else
                    str = cfg.DescValue[1][i]
                end
                ss[i] = str
            end
            return string.format(GetLanguageStrById(cfg.Desc[1]), unpack(ss))
        end
        return GetLanguageStrById(cfg.Desc)
    end
    return "GetSkillConfigDesc Error!!"
end

--后台传输多语言数据合并    
function GetMailConfigDesc(cfg, mailparam)--cfg插入内容，mailparam插入数组
    if #mailparam > 0 then
        local ss = {}
        for i = 1, #mailparam do
            local lsparam = string.find(mailparam[i], "|0")
            if lsparam == nil then
                ss[i] = GetLanguageStrById(mailparam[i])
            else
                local s = "";
                local len = string.len(mailparam[i])
                s = string.sub(mailparam[i],3,len)
                ss[i] = GetLanguageStrById(s)
            end
        end

        return string.format(GetLanguageStrById(cfg), unpack(ss))
    else
        string.format(GetLanguageStrById(cfg), mailparam)
    end
    return GetLanguageStrById(cfg)
    
end
-- 设置排名所需要的数字框
function SetRankNumFrame(rankNum)
    local rankNumRes = {
        [1] = "cn2-X1_tongyong_diyi",
        [2] = "cn2-X1_tongyong_dier",
        [3] = "cn2-X1_tongyong_disan",
        [4] = "cn2-X1_jingjichang_shujudiban_06",
    }

    local resPath = rankNum > 3 and rankNumRes[4] or rankNumRes[rankNum]
    local icon = Util.LoadSprite(resPath)
    return icon
end

--- 本方法适用滚动条中 生成item的使用 （主要适用每条滚动条item数量不定的滚动条中）
--- itemview重设复用 1根节点 2生成到父节点 3item容器 4容器上限 5缩放 6层级 7根据数据类型生成 8不定参数据...
--- type=true 针对表数据为一维数据  type=false 针对表数据为二维数据
function ResetItemView(root,rewardRoot,itemList,max,scale,sortingOrder,type,...)
    local args = {...}
    local data1 = args[1]
    local data2 = args[2]

    if itemList[root] then -- 存在
        for i = 1, max do
            itemList[root][i].gameObject:SetActive(false)
        end
        if type then
            itemList[root][1]:OnOpen(false, {data1,data2},scale,false,false,false,sortingOrder)
            itemList[root][1].gameObject:SetActive(true)
        else
            for i = 1, #data1 do
                if itemList[root][i] then
                    itemList[root][i]:OnOpen(false, {data1[i][1],data1[i][2]},scale,false,false,false,sortingOrder)
                    itemList[root][i]:Reset({data1[i][1],data1[i][2]},ItemType.Hero,{false,true,true,true})
                    itemList[root][i].gameObject:SetActive(true)
                end
            end
        end
    else -- 不存在 新建
        itemList[root]={}
        for i = 1, max do
            itemList[root][i] = SubUIManager.Open(SubUIConfig.ItemView, rewardRoot)
            itemList[root][i].gameObject:SetActive(false)
        end
        if type then
            itemList[root][1]:OnOpen(false, {data1,data2},scale,false,false,false,sortingOrder)
            itemList[root][1].gameObject:SetActive(true)
        else
            for i = 1, #data1 do
                itemList[root][i]:OnOpen(false, {data1[i][1],data1[i][2]},scale,false,false,false,sortingOrder)
                itemList[root][i]:Reset({data1[i][1],data1[i][2]},ItemType.Hero,{false,true,true,true})
                itemList[root][i].gameObject:SetActive(true)
            end
        end
    end
end

--只有英文截取长度
function SubString2(inputstr,num)
    if GetLan() == 0 then
        return inputstr
    end
    if not inputstr or inputstr == "" then
        return ""
    end
    local num = num and num or 0
    local str = ""
    local lenInByte = #inputstr
    local width = 0
    local i = 1
    while (i <= lenInByte)
    do
        local curByte = string.byte(inputstr, i)
        local byteCount = 1
        if curByte > 0 and curByte <= 127 then
            byteCount = 1                                           --1字节字符
        elseif curByte >= 192 and curByte < 223 then
            byteCount = 2                                           --双字节字符
        elseif curByte >= 224 and curByte < 239 then
            byteCount = 3                                           --汉字
        elseif curByte >= 240 and curByte <= 247 then
            byteCount = 4                                           --4字节字符
        end
        local char = string.sub(inputstr, i, i+byteCount-1)
        -- print(char)
        str = str..char
        i = i + byteCount                                 -- 重置下一字节的索引
        width = width + 1                                 -- 字符的个数（长度）
        if width == num then
            if lenInByte > num then
                str = str .. "..."
            end
            return str
        end
    end
    if lenInByte > num then
        str = str .. "..."
    end
    return str
end
--> 连接live 
function ConnectTankName(fabName, isDown)
    local strNameConnect = "up"
    if isDown then
        strNameConnect = "down"
    end
    return tostring(fabName) .. "_" .. strNameConnect
end

--> item pic tips
function ItemImageTips(itemid, imageGo)
    local btn = imageGo:GetComponent(typeof(UnityEngine.UI.Button))
    if not btn then
        imageGo:AddComponent(typeof(UnityEngine.UI.Button))
    end
    Util.AddOnceClick(imageGo, function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemid)
    end)
end

function GetProDataStr(id, value)
    local style = G_PropertyConfig[id].Style
    local str = ""
    if style == 1 then               --< 绝对值
        str = GetPropertyFormatStr(1, value)
    elseif style == 2 then           --< 百分比
        str = GetPropertyFormatStr(2, value)
    end
    return str
end

--> 获取数量填充颜色
function GetNumUnenoughColor(a, b, showa, showb)
    local str = ""
    local ka = showa and showa or a
    local kb = showb and showb or b
    if tonumber(a) < tonumber(b) then
        str = string.format("<color=#FF0000FF>%s</color>", tostring(ka)) .. "/" .. tostring(kb)
    else
        str = ka .. "/" .. kb
    end
    return str
end

--> 设置formationbuff 团队效果 icon     节点结构需一致
function SetFormationBuffIcon(Image, elementList)
    local iconStr, numArray, isGray = FormationManager.GetElementPicNum(elementList)

    Image:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(iconStr))
    local buffnums = {}
    for i = 1, 3 do
        local buff = Util.GetGameObject(Image, tostring(i) .. "_buff")
        table.insert(buffnums, buff)
    end

    Util.SetGray(Image, isGray)

    for i = 1, #buffnums do
        buffnums[i]:SetActive(false)
    end

    if not isGray then
        local root = buffnums[#numArray]
        if root then
            root:SetActive(true)
            for i = 1, 3 do
                if i <= #numArray then
                    local num = Util.GetGameObject(root, "num" .. tostring(i))
                    num:GetComponent("Text").text = numArray[i]
                end
            end
        end
    end
end

--本地文本显示统一调用此接口
--查找不以Log开头或不以--开头的包括在双引号内中文的正则表达式:^((?!--|Log.*).)*".*[一-龠]+.*"
function GetLanguageStrById(zhStr)
    if zhStr == nil then
        return zhStr
    end
    local t = type(zhStr)
    local languageID = 0
    if t == "string" then
        languageID = tonumber(zhStr)
    else
        languageID = zhStr
    end

    if languageDic then
        if languageDic[languageID] then
            if GetLan() == 0 then
                return languageDic[languageID].zh
            elseif GetLan() == 1 then
                return languageDic[languageID].en
            elseif GetLan() == 2 then
                -- LogRed("GetLanguageStrById: " .. zhStr.."--jp"..languageDic[languageID].jp)
                return languageDic[languageID].jp
            elseif GetLan() == 3 then
                return languageDic[languageID].kr
            else
                return languageDic[languageID].zh
            end
        else
            LogRed("在language表内未找到 id："..zhStr)
            return tostring(zhStr)
        end
    end
    return zhStr
end

local originLanguage
-- 0:中文   1：英文
function GetCurLanguage()
    -- LogRed("GetCurLanguage")
    -- LogRed(AppConst.originLan)
    if not originLanguage then
        originLanguage = PlayerPrefs.GetInt("multi_language", AppConst.originLan)
    end
    return originLanguage
end

--> 多语言选项ID 转 语言种类ID  10001 2 3 位代表语言  4 5 位代表多语言选项id
function LanguageID2LanID(languageid)
    local lanid = 0
    if languageid then
        lanid = tonumber(math.floor(languageid / 100) % 100)
    end
    return lanid
end

function GetLan()
    return LanguageID2LanID(GetCurLanguage())
end

function GetLanguageStrByStr(zhStr)
    local lang= GetLan()
    if languageDicStr then
        if languageDicStr[zhStr] then
            if lang == 0 then
                return languageDicStr[zhStr].zh
            elseif lang == 1 then
                return languageDicStr[zhStr].en
            elseif lang == 2 then
                return languageDicStr[zhStr].jp
            elseif lang == 3 then
                return languageDicStr[zhStr].kr
            else
                return languageDicStr[zhStr].zh
            end
        else
            LogRed("languageDicStr no find Str: " .. zhStr)
            return tostring(zhStr)
        end
    end
    return zhStr
end

function HasLanguageStrKey(zhStr)
    if languageDicStr then
        if languageDicStr[zhStr] then
            return true
        end
    end
    return false
end

function GetMonsterGroupFirstEnemy(_monsterGroupId)
    for i = 1, #G_MonsterGroup[_monsterGroupId].Contents[1] do
        if G_MonsterGroup[_monsterGroupId].Contents[1][i] ~= 0 then
            return G_MonsterGroup[_monsterGroupId].Contents[1][i]
        end
    end
    LogError("GetMonsterGroupFirstEnemy Error!!!")
    return nil
end

function ServerDropAdd(...)
    local newDrop = {}
    local args = {...}
    for i = 1, #args do
        local drop = args[i]
        if drop.itemlist ~= nil and #drop.itemlist > 0 then
            for j = 1, #drop.itemlist do
                if newDrop.itemlist == nil then
                    newDrop.itemlist = {}
                end
                table.insert(newDrop.itemlist, drop.itemlist[j])
            end
        end
        if drop.equipId ~= nil and #drop.equipId > 0 then
            for j = 1, #drop.equipId do
                if newDrop.equipId == nil then
                    newDrop.equipId = {}
                end
                table.insert(newDrop.equipId, drop.equipId[j])
            end
        end
        if drop.Hero ~= nil and #drop.Hero > 0 then
            for j = 1, #drop.Hero do
                if newDrop.Hero == nil then
                    newDrop.Hero = {}
                end
                table.insert(newDrop.Hero, drop.Hero[j])
            end
        end
        if drop.soulEquip ~= nil and #drop.soulEquip > 0 then
            for j = 1, #drop.soulEquip do
                if newDrop.soulEquip == nil then
                    newDrop.soulEquip = {}
                end
                table.insert(newDrop.soulEquip, drop.soulEquip[j])
            end
        end
    end

    return newDrop
end

--> 合属性
function F_DoubleTableProCompound(allProVal, addProVal)
    if addProVal and LengthOfTable(addProVal) > 0 then
        for k, v in pairs(addProVal) do
            if v > 0 then
                if allProVal[k] then
                    allProVal[k] = allProVal[k] + v
                else
                    allProVal[k] = v
                end
            end
        end
    end
end

function SecTorPlayAnimByScroll(scroll,_scale)
    local scale = 0.05
    if _scale then
        scale = _scale
    end
    scroll:ForeachItemGO(function (index, go)
        Timer.New(function ()
            go.gameObject:SetActive(true)
            PlayUIAnim(go.gameObject)
        end, scale*(index-1)):Start()
    end)
end

-- 加载立绘
function LoadHerolive(_heroConfig, _objPoint)
    local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
    if _heroConfig==nil then
        return nil
    end
    if _heroConfig.RoleImage ~= 0 then
        --动态加载立绘
        local liveName = artResourcesConfig[_heroConfig.RoleImage].Name
        if liveName == "lihui_baiqi" then liveName = "lihui_baiqi_01" end
        local testLive = poolManager:LoadLive(liveName, _objPoint.transform, Vector3.one * _heroConfig.Scale, Vector3.New(_heroConfig.Position[1], _heroConfig.Position[2], 0))
        local SkeletonGraphic = testLive:GetComponent("SkeletonGraphic")
        return testLive
    else
        --静态加载立绘
        local roleStaticImg = poolManager:LoadAsset("TestImg", PoolManager.AssetType.GameObject) 
        roleStaticImg.transform:SetParent(_objPoint.transform)
        roleStaticImg.transform.localScale = Vector3.one * _heroConfig.Scale
        roleStaticImg.transform.localPosition = Vector3.New(_heroConfig.Position[1], _heroConfig.Position[2], 0)
        roleStaticImg.name = "TestImg"
        roleStaticImg:GetComponent("Image").sprite = Util.LoadSprite(artResourcesConfig[_heroConfig.BigIcon].Name)
        roleStaticImg:GetComponent("Image").raycastTarget = false
        return roleStaticImg
    end
end
--卸载立绘
function UnLoadHerolive(_heroConfig,_obj)
    local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
    if _heroConfig.RoleImage ~= 0 then
        poolManager:UnLoadLive(artResourcesConfig[_heroConfig.RoleImage].Name, _obj)
    else 
        poolManager:UnLoadAsset("TestImg", _obj, PoolManager.AssetType.gameObject)
    end
end

--延迟显示List里的item
function DelayCreation(list,maxIndex)
    if list == nil then return end
    if #list == 0 then return end
    for i = 1, #list do
        if list[i] then
            if list[i].activeSelf then
                list[i]:SetActive(false)
            end
        end
    end

    local time = 0.01
    local _index = 1
    local _timer
    if not maxIndex then
        maxIndex = #list
    end

    _timer = Timer.New(function ()
        if _index == maxIndex + 1 then
            if _timer then
                _timer:Stop()
            end
        end
        if list[_index] then
            list[_index]:SetActive(true)
            Timer.New(function ()
                _index = _index + 1
            end,time):Start()
        end
    end,time,maxIndex + 1):Start()
end

--刷新战力
function RefreshPower(_oldPower, _newPower)
    local oldPower = _oldPower
    local newPower
    if oldPower == 0 then
        return
    end
    if _newPower then
        newPower = _newPower
    else
        newPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
    end
    if oldPower ~= newPower then
        UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2,{oldValue = oldPower, newValue = newPower})
        Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnPowerChange)
    end
end

--获取图片字
function GetPictureFont(str)
    if GetLan() == 0 then
        return str .. "_zh"
    elseif GetLan() == 1 then
        return str .. "_en"
    elseif GetLan() == 2 then
        return str .. "_jp"
    elseif GetLan() == 3 then
        return str .. "_kr"
    else
        return str .. "_zh"
    end
end

--设置机器人名字
function SetRobotName(uid, name)
    if uid < 100000 then
        return GetLanguageStrById(tonumber(name))
    else
        return name
    end
end

--获取渠道配置文件
function GetChannerConfig()
    local channelConfig = ConfigManager.GetConfigDataByKey(ConfigName.ChannelConfig, "ListID", AppConst.ChannelType)
    -- LogError(AppConst.ChannelType..
    -- "\n使用条款、个人信息:"..tostring(channelConfig.Button_Logon_information)..
    -- "\n16+适龄标:"..tostring(channelConfig.Button_Logon_AgeTips)..
    -- "\n抵制不良游戏宣言:"..tostring(channelConfig.Button_Logon_HealthyTips)..
    -- "\n切换语言:"..tostring(channelConfig.Button_PlayerSet_Language)..
    -- "\n账号关联:"..tostring(channelConfig.Button_PlayerSet_Relation)..
    -- "\n注销账号:"..tostring(channelConfig.Button_PlayerSet_Cancellation)..
    -- "\n充值走邮件:"..tostring(channelConfig.Rechargemode_Mail)..
    -- "\n是否可以充值:"..tostring(channelConfig.Recharge_SDK_open)..
    -- "\n咨询:"..tostring(channelConfig.Button_Logon_consulting)..
    -- "\n聊天健康提示:"..tostring(channelConfig.Chat_health_tips)..
    -- "\n不支持退款提示:"..tostring(channelConfig.IsRefund_tips)..
    -- "\n隐私协议:"..tostring(channelConfig.PrivacyAgreement)..
    -- "\n版号:"..tostring(channelConfig.Text_VersionNumber)..
    -- "\n切换账号:"..tostring(channelConfig.Button_switch)..
    -- "\n客服:"..tostring(channelConfig.Button_Logon_CustomerService)..
    -- "\n版号文本id:"..tostring(channelConfig.Text_VersionNumber_ID)..
    -- "\n登录页背景预制:"..tostring(channelConfig.Bg_Logon)
    -- )
    return channelConfig
end