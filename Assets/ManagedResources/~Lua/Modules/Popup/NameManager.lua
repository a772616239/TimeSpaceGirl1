local RandomName = ConfigManager.GetConfig(ConfigName.RandomName)
local LanguageType = ConfigManager.GetConfig(ConfigName.MultiLanguage)
local this = {
    roleName = "",
    roleSex = ROLE_SEX.BOY
}

local function readonly(t,k,v)
   
end

local function indexer(t,k)
    if not this[k] then
       
    end
    return this[k]
end

function this.Initialize()
end

function this.SetRoleName(name)
    this.roleName = name
end
function this.SetRoleSex(sex)
    this.roleSex = sex
end

--玩家最小最大字符数
function this.GetNameLimit()
    local curLan =GetCurLanguage()
    local _min = LanguageType[curLan].NameLimit[1]
    -- LogError("name min".._min)
    if _min == nil or _min==0 then
        _min =2
    end

    local _max = LanguageType[curLan].NameLimit[2]
    -- LogError("name max".._max)
    if _max == nil or _max==0 then
        _max = 12
    end
    return _min,_max
end

--玩家工会最小最大字符数
function this.GetGuildNameLimit()
    local curLan =GetCurLanguage()
    local _min = LanguageType[curLan].GuildNameLimit[1]
    -- LogError("GetGuildNameLimit min".._min)
    if _min == nil or _min==0 then
        _min =2
    end

    local _max = LanguageType[curLan].GuildNameLimit[2]
    -- LogError("GetGuildNameLimit max".._max)
    if _max == nil or _max==0 then
        _max = 12
    end
    return _min,_max
end


function this.GetLocalRandomName()
    local random1 = math.random(1, RandomName.__count)
    local random2 = math.random(1, RandomName.__count)
    return RandomName[random1].Sur_name .. RandomName[random2].Name
end

--得到任意名字数据
function this.GetRandomNameData(sex)
    NetManager.GetRandomNameRequest(sex, function(randomsurname, randomname)
        local lan = GetCurLanguage()
        local surname
        local name
        if lan == 10001 then
            surname = G_RandomName[randomsurname].Sur_name
            name = G_RandomName[randomname].Name
        elseif lan == 10101 then
            surname = G_RandomName[randomsurname].Sur_name_en
            name = G_RandomName[randomname].Name_en
        elseif lan == 10201 then
            surname = G_RandomName[randomsurname].Sur_name_jp
            name = G_RandomName[randomname].Name_jp
        -- elseif lan == 3 then
        --     surname = G_RandomName[randomsurname].Sur_name_kr
        --     name = G_RandomName[randomname].Name_kr
        else
            surname = G_RandomName[randomsurname].Sur_name
            name = G_RandomName[randomname].Name
        end
        
        Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnNameChange, surname .. name)
    end)
end

--更改玩家姓名
function this.ChangeUserName(type, name, teamPosId, sex, callBack)
    NetManager.ChangeUserNameRequest(type, name, teamPosId, sex, function()
        this.roleSex = sex
        this.roleName = name
        PlayerManager.nickName = name

        -- 打点静态数据修改
        -- ThinkingAnalyticsManager.SetSuperProperties({
        --     role_name = PlayerManager.nickName,
        -- })
        -- 创建角色时保存一下头像数据
        if type == 1 then
            local config = ConfigManager.GetConfigDataByKey(ConfigName.PlayerRole, "Role", sex)
            PlayerManager.head = config.RolePic
        end

        Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnChangeName)
        if callBack then callBack() end
    end)
end

NameManager = {}
setmetatable(NameManager, { __index = indexer, __newindex = readonly })
return NameManager