HeadManager = {}
local this = HeadManager

this._NewHeadList = {}

local _HeadConfig = {
    [ItemType.HeadFrame] = {prefKey = "PlayerNewFrame", rpType = RedPointType.HeadChange_Frame},
    [ItemType.Head] = {prefKey = "PlayerNewHead", rpType = RedPointType.HeadChange_Head},
}

function HeadManager.Initialize()

    this._MyHeadList = {}
    this._MyHeadFrameList = {}

    -- 注册事件
    Game.GlobalEvent:AddEvent(GameEvent.Bag.GetNewItem, this.OnNewItem)
end


function HeadManager.InitData()
    this._NewHeadList = {}
    -- 本地数据初始化
    for type, config in pairs(_HeadConfig) do
        local dataStr = PlayerPrefs.GetString(config.prefKey..PlayerManager.uid)
        if dataStr == "" then
            this._NewHeadList[type] = {}
        else
            this._NewHeadList[type] = string.split(dataStr, "|")
        end
    end
end

-- 获取新物品
function this.OnNewItem(itemId)
    local itemInfo = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemId)
    local type = itemInfo.ItemType

    -- 判断是否是头像相关的类型
    local config = _HeadConfig[type]
    if not config then return end

    if not this._NewHeadList then
        this._NewHeadList = {}
    end
    if not this._NewHeadList[type] then
        this._NewHeadList[type] = {}
    end
    -- 保存数据
    table.insert(this._NewHeadList[type], itemId)
    -- 检测红点
    if config.rpType then
        CheckRedPointStatus(config.rpType)
    end
    -- 本地保存数据
    local str = table.concat(this._NewHeadList[type], "|")
    PlayerPrefs.SetString(config.prefKey..PlayerManager.uid, str)
end

-- 获取头像
function HeadManager.GetHeadList()
    if #this._MyHeadList == 0 then
        local AllHeadList = ConfigManager.GetAllConfigsDataByKey(ConfigName.ItemConfig, "ItemType", ItemType.Head)
        local config = ConfigManager.GetConfigDataByKey(ConfigName.PlayerRole, "Role", NameManager.roleSex)
        for _, head in ipairs(AllHeadList) do
            if head.Name == GetLanguageStrById(11500) then
                if config.RolePic == head.Id then
                    table.insert(this._MyHeadList, head)
                end
            else
                table.insert(this._MyHeadList, head)
            end
        end
    end
    return this._MyHeadList
end

-- 获取头像框
function HeadManager.GetHeadFrameList()
    if #this._MyHeadFrameList == 0 then
        this._MyHeadFrameList = ConfigManager.GetAllConfigsDataByKey(ConfigName.ItemConfig, "ItemType", ItemType.HeadFrame)
        table.sort(this._MyHeadFrameList, function(a, b)
            return a.Id < b.Id
        end)
    end
    return this._MyHeadFrameList
end

-- 判断是否是新头像
function HeadManager.IsNewHead(id)
    -- 无数据
    if not this._NewHeadList then
        return false
    end
    -- 无类型数据
    local itemInfo = ConfigManager.GetConfigData(ConfigName.ItemConfig, id)
    if not this._NewHeadList[itemInfo.ItemType] then
        return false
    end
    -- 遍历查找
    for _, newFrameId in ipairs(this._NewHeadList[itemInfo.ItemType]) do
        if tonumber(newFrameId) == id then
            return true
        end
    end
    return false
end

-- 设置已经不是新头像了
function HeadManager.SetNotNewHeadAnyMore(id)
    if not this._NewHeadList then
        return
    end
    local itemInfo = ConfigManager.GetConfigData(ConfigName.ItemConfig, id)
    local type = itemInfo.ItemType
    if not this._NewHeadList[type] then
        return
    end

    local index = nil
    for i, newId in ipairs(this._NewHeadList[type]) do
        if tonumber(newId) == id then
            index = i
            break
        end
    end
    if not index then return end

    table.remove(this._NewHeadList[type], index)
    -- 检测红点
    local config = _HeadConfig[type]
    if config and config.rpType then
        CheckRedPointStatus(config.rpType)
    end
    -- 本地保存数据
    local str = table.concat(this._NewHeadList[type], "|")
    PlayerPrefs.SetString(config.prefKey..PlayerManager.uid, str)
end

-- 删除所有新头像数据，清空所有红点
function HeadManager.RemoveAllNewHead(type)
    if not this._NewHeadList[type] then
        return
    end
    if #this._NewHeadList[type] == 0 then
        return
    end
    this._NewHeadList[type] = {}
    -- 检测红点
    local config = _HeadConfig[type]
    if config and config.rpType then
        CheckRedPointStatus(config.rpType)
    end
    -- 本地保存数据
    local str = table.concat(this._NewHeadList[type], "|")
    PlayerPrefs.SetString(config.prefKey..PlayerManager.uid, str)
end


-- 头像框红点判断
function HeadManager.CheckHeadRedPot(rpType)
    local list = nil
    if rpType == RedPointType.HeadChange_Frame then
        list = this._NewHeadList[ItemType.HeadFrame]
    elseif rpType == RedPointType.HeadChange_Head then
        list = this._NewHeadList[ItemType.Head]
    end
    if list and #list > 0 then
        return true
    end
    return false
end


return HeadManager