GoodFriendManager = {};
local this = GoodFriendManager
local GameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local VipLevelConfig = ConfigManager.GetConfig(ConfigName.VipLevelConfig)
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local passiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local equipSign = ConfigManager.GetConfig(ConfigName.EquipSign)
local equipStarsConfig = ConfigManager.GetConfig(ConfigName.EquipStarsConfig)
--好友列表数据
this.friendAllData = {}
--申请好友数据
this.friendApplicationData = {}
--好友搜索推荐数据
this.friendSearchData = {}
--黑名单数据
this.blackFriendList = {}
--预览其他玩家已装备信息
this.equipDatas = {}

function this.CreateFriendData()
    return {
        --好友的id
        id = nil,
        --好友名字
        name = nil,
        --好友的等级
        lv = nil,
        --好友离线时间   0表示在线
        offLineTime = nil,
        --是否有友情点可以领取   0: 没有 1:有
        haveReward = nil,
        --是否赠送过友情点  0: 否 ,1:是
        isGive = nil,
        --新头像
        head = nil,
        --头像框
        frame = nil,
        --战斗力
        soulVal = nil,
        --chenghao
        chenghao = nil,
    }
end
function this.Initialize()
    --能够收取好友友情点的次数
    this.MaxEnergyGet = 0
    --收取好友友情点上限
    this.MaxEnergy = 0
    --好友上限数量
    this.goodFriendLimit = 0
    --黑名单上限
    this.blackFriendLimit = 0
end

function this.OnRefreshEnegryData()
    this.MaxEnergyGet = PrivilegeManager.GetPrivilegeRemainValue(GameSetting[1].MaxEnergyGet)
    this.MaxEngery = PrivilegeManager.GetPrivilegeNumber(GameSetting[1].MaxEnergyGet)
    Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
    CheckRedPointStatus(RedPointType.Friend_Reward)
end

--跨天刷新
function this.OnRefreshDataNextDay()
    this.MaxEnergyGet = PrivilegeManager.GetPrivilegeRemainValue(GameSetting[1].MaxEnergyGet)
    this.MaxEngery = PrivilegeManager.GetPrivilegeNumber(GameSetting[1].MaxEnergyGet)
    for i, v in pairs(this.friendAllData) do
        v.isGive = 0
        v.haveReward = 0
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
    CheckRedPointStatus(RedPointType.Friend_Reward)
end

--添加申请好友数据刷新
function this.OnFriendDataRefresh(type, msg)
    if (type == 1) then
        local friendData = this.CreateFriendData()
        friendData.id = msg.Friends.id
        friendData.name = msg.Friends.name
        friendData.lv = msg.Friends.lv
        friendData.offLineTime = msg.Friends.offLineTime
        friendData.haveReward = msg.Friends.haveReward
        friendData.isGive = msg.Friends.isGive
        friendData.head = msg.Friends.head
        friendData.frame = msg.Friends.frame
        friendData.soulVal = msg.Friends.soulVal
        --friendData.isHaveApplication=1
        this.friendAllData[friendData.id] = friendData

    end
    if (type == 3) then
        local friendData = this.CreateFriendData()
        friendData.id = msg.Friends.id
        friendData.name = msg.Friends.name
        friendData.lv = msg.Friends.lv
        friendData.offLineTime = msg.Friends.offLineTime
        friendData.haveReward = msg.Friends.haveReward
        friendData.isGive = msg.Friends.isGive
        friendData.head = msg.Friends.head
        friendData.frame = msg.Friends.frame
        friendData.soulVal = msg.Friends.soulVal
        --friendData.isHaveApplication=1
        this.friendApplicationData[friendData.id] = friendData
        --RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "redPointApplication",1)
    end
end




--获取好友信息
function this.GetFriendInfoRequest(type, msg)
    this.goodFriendLimit = tonumber(specialConfig[11].Value)
    this.blackFriendLimit = tonumber(specialConfig[30].Value)
    this.MaxEnergyGet = PrivilegeManager.GetPrivilegeRemainValue(GameSetting[1].MaxEnergyGet)
    this.MaxEnergy = PrivilegeManager.GetPrivilegeNumber(GameSetting[1].MaxEnergyGet)
    if (type == 1) then
        this.friendAllData = {}
        for i = 1, #msg.Friends do
            local friendData = this.CreateFriendData()
            friendData.id = msg.Friends[i].id
            friendData.name = msg.Friends[i].name
            friendData.lv = msg.Friends[i].lv
            friendData.offLineTime = msg.Friends[i].offLineTime
            friendData.haveReward = msg.Friends[i].haveReward
            friendData.isGive = msg.Friends[i].isGive
            friendData.head = msg.Friends[i].head
            friendData.frame = msg.Friends[i].frame
            friendData.soulVal = msg.Friends[i].soulVal

            friendData.chenghao = msg.Friends[i].titleId
            --friendData.isHaveApplication=1
            this.friendAllData[friendData.id] = friendData

        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
    elseif (type == 3) then
        this.friendApplicationData = {}
        for i = 1, #msg.Friends do
            local friendData = this.CreateFriendData()
            friendData.id = msg.Friends[i].id
            friendData.name = msg.Friends[i].name
            friendData.lv = msg.Friends[i].lv
            friendData.offLineTime = msg.Friends[i].offLineTime
            friendData.haveReward = msg.Friends[i].haveReward
            friendData.isGive = msg.Friends[i].isGive
            friendData.head = msg.Friends[i].head
            friendData.frame = msg.Friends[i].frame
            friendData.soulVal = msg.Friends[i].soulVal

            friendData.chenghao = msg.Friends[i].titleId
            --friendData.isHaveApplication=1
            this.friendApplicationData[friendData.id] = friendData
            --RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "redPointApplication",1)
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendApplication, this.friendApplicationData)
    elseif (type == 2) then
        this.friendSearchData = {}
        for i = 1, #msg.Friends do
            local friendData = this.CreateFriendData()
            friendData.id = msg.Friends[i].id
            friendData.name = msg.Friends[i].name
            friendData.lv = msg.Friends[i].lv
            friendData.offLineTime = msg.Friends[i].offLineTime
            friendData.haveReward = msg.Friends[i].haveReward
            friendData.isGive = msg.Friends[i].isGive
            friendData.isApplyed = msg.Friends[i].isApplyed
            friendData.head = msg.Friends[i].head
            friendData.frame = msg.Friends[i].frame
            friendData.soulVal = msg.Friends[i].soulVal

            friendData.chenghao = msg.Friends[i].titleId
            -- friendData.isHaveApplication=1s
            this.friendSearchData[friendData.id] = friendData
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendSearch, this.friendSearchData)
    elseif (type == 4) then
        this.blackFriendList = {}
        for i = 1, #msg.Friends do
            local friendData = this.CreateFriendData()
            friendData.id = msg.Friends[i].id
            friendData.name = msg.Friends[i].name
            friendData.lv = msg.Friends[i].lv
            friendData.offLineTime = msg.Friends[i].offLineTime
            friendData.haveReward = msg.Friends[i].haveReward
            friendData.isGive = msg.Friends[i].isGive
            friendData.head = msg.Friends[i].head
            friendData.frame = msg.Friends[i].frame
            friendData.soulVal = msg.Friends[i].soulVal

            friendData.chenghao = msg.Friends[i].titleId
            this.blackFriendList[friendData.id] = friendData
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnBlackFriend, this.blackFriendList)
    end
end

-- 更新好友数据
function this.UpdateFriendData(id, level, name, head, frame)
    if not this.friendAllData[id] then
        return
    end
    this.friendAllData[id].lv = level
    this.friendAllData[id].name = name
    this.friendAllData[id].head = head
    this.friendAllData[id].frame = frame
end

--刷新好友推荐
function this.RefreshRecommend(type)
    NetManager.RequestGetFriendInfo(type, function()
    end)
end

--申请好友请求
function this.InviteFriendRequest(inviteUids, func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GOODFRIEND) then
        PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GOODFRIEND))
        return
    end
    NetManager.RequestInviteFriend(inviteUids, function()
        if this.friendSearchData[inviteUids] then
            this.friendSearchData[inviteUids].isApplyed = 1
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendSearch, this.friendSearchData)
        if func then
            func()
        end
    end)
end
--申请为好友操作
function this.FriendInviteOperationRequest(type, friendId)
    --type 1:同意 2:拒绝 3:全部同意 4: 全部拒绝
    NetManager.RequestFriendInviteOperation(type, friendId, function()
        if type == 1 then
            this.friendAllData[friendId] = this.friendApplicationData[friendId]
            this.friendApplicationData[friendId] = nil
            --this.friendSearchData[friendId].isHaveApplication=2
            Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
            Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendApplication, this.friendApplicationData)
        end
        if type == 2 then
            this.friendApplicationData[friendId] = nil
            Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendApplication, this.friendApplicationData)
        end
        if type == 3 then
            -- 刷新好友列表和申请列表
            NetManager.RequestGetFriendInfo(1)
            NetManager.RequestGetFriendInfo(3)
        end
    end)
end
--赠送好友精力
function this.FriendGivePresentRequest(type, friendId)
    --type 1:赠送一个人 2 赠送全部好友
    NetManager.RequestFriendGivePresent(type, friendId, function()
        PopupTipPanel.ShowTipByLanguageId(10831)
        if (type == 1) then
            this.friendAllData[friendId].isGive = 1
            Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
        end
        if (type == 2) then
            for i, v in pairs(this.friendAllData) do
                v.isGive = 1
            end
            Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
        end
    end)
end
--删除好友
function this.DelFriendRequest(friendId)
    NetManager.RequestDelFriend(friendId, function()
        PopupTipPanel.ShowTipByLanguageId(10832)
        this.friendAllData[friendId] = nil
        --this.friendSearchData[friendId].isHaveApplication=1
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendDelete, friendId)
    end)
end
--领取一个人和所有人的精力值
function this.FriendTakeHeartRequest(type, friendId)
    NetManager.RequestFriendTakeHeart(type, friendId, function(msg)
        local getNums = 0
        if (type == 1) then
            PrivilegeManager.RefreshPrivilegeUsedTimes(GameSetting[1].MaxEnergyGet, 1)
            this.MaxEnergyGet = PrivilegeManager.GetPrivilegeRemainValue(GameSetting[1].MaxEnergyGet)
            this.MaxEnergy = PrivilegeManager.GetPrivilegeNumber(GameSetting[1].MaxEnergyGet)
            this.friendAllData[friendId].haveReward = 0
        end
        local friendIdList = msg.friendId
        if (type == 2) then
            for i, v in pairs(this.friendAllData) do
                for n, m in pairs(friendIdList) do
                    if (m == i) then
                        v.haveReward = 0
                        getNums = getNums + 1
                    end
                end
            end
            PrivilegeManager.RefreshPrivilegeUsedTimes(GameSetting[1].MaxEnergyGet, getNums)
            this.MaxEnergyGet = PrivilegeManager.GetPrivilegeRemainValue(GameSetting[1].MaxEnergyGet)
            this.MaxEnergy = PrivilegeManager.GetPrivilegeNumber(GameSetting[1].MaxEnergyGet)
            Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
        end
        local _drop = msg.drop
        UIManager.OpenPanel(UIName.RewardItemPopup, _drop, 1)
        Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
    end)
end
--根据名字查找好友
function this.FriendSearchRequest(name)
    NetManager.RequestFriendSearch(name, function(msg)
        this.friendSearchData = {}
        this.friendSearchData[msg.Friends.id] = msg.Friends
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendSearch, this.friendSearchData)
    end)
end
--刷新好友在线状态
function this.RefreshFriendStateRequest()
    NetManager.RequestRefreshFriendState(function(msg)
        for i, v in ipairs(msg.friendIds) do
            for m, n in pairs(this.friendAllData) do
                if (m == v) then
                    n.offLineTime = "0"
                end
            end
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, this.friendAllData)
    end)
end

-- 获取好友信息
function this.GetFriendInfo(friendId)
    return this.friendAllData[friendId]
end

-- 判断是否是我的好友
function this.IsMyFriend(friendId)
    for fid, _ in pairs(this.friendAllData) do
        if fid == friendId then
            return true
        end
    end
    return false
end

--检测好友收取友情点红点
function this.FriendRewardRedPointShow()
    local isShow = false
    for i, v in pairs(this.friendAllData) do
        if v.haveReward == 1 and this.MaxEnergyGet >= 1 then
            isShow = true

            break
        end
    end
    return isShow
end
--检测好友申请红点
function this.FriendApplicationRedPointShow()
    local isShow = false
    if (table.nums(this.friendApplicationData) > 0) then
        isShow = true

    end
    return isShow
end

---=================黑名单相关====================
-- 是否在黑名单中
function this.IsInBlackList(friendId)
    -- if not this.blackFriendList then
    --     return false
    -- end
    if #this.blackFriendList > 0 and this.blackFriendList[friendId] then
        return true
    end
    return false
end

-- 申请加入黑名单
function this.RequestAddToBlackList(uid, func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GOODFRIEND) then
        PopupTipPanel.ShowTipByLanguageId(10835)
        return
    end
    if uid == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10836)
        return
    end
    if this.IsInBlackList(uid) then
        PopupTipPanel.ShowTipByLanguageId(10837)
        return
    end
    NetManager.RequestOptBlackList(1, uid, function()
        if this.IsMyFriend(uid) then
            this.friendAllData[uid] = nil
            Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendDelete, uid)
        end

        NetManager.RequestGetFriendInfo(1)-- 刷新好友列表
        NetManager.RequestGetFriendInfo(2)-- 刷新推荐列表
        NetManager.RequestGetFriendInfo(3)-- 刷新申请列表
        NetManager.RequestGetFriendInfo(4, function()
            if func then
                func()
            end

        end)-- 刷新黑名单

    end)
end
-- 申请移除黑名单
function this.RequestDeleteFromBlackList(uid, func)
    if (table.nums(GoodFriendManager.blackFriendList) <= 0) then
        PopupTipPanel.ShowTipByLanguageId(10838)
    else
        local type = 0
        if (uid == 0) then
            type = 3
        else
            type = 2
        end
        NetManager.RequestOptBlackList(type, uid, function()
            NetManager.RequestGetFriendInfo(4)-- 刷新黑名单
            if func then
                func()
            end
        end)
    end
end

--刷新本地数据
function this.GetHeroDatas(_msgHeroData, force, specialEffects,guildSkill)
    local heroData = {}    
    heroData.soulPrintList = {}
    heroData.heroBackData = _msgHeroData
    heroData.dynamicId = _msgHeroData.id
    local _id = _msgHeroData.heroId
    heroData.id = _id
    heroData.star = _msgHeroData.star
    heroData.lv = _msgHeroData.level
    heroData.breakId = _msgHeroData.breakId
    heroData.upStarId = _msgHeroData.starBreakId
    --heroData.createTime=_msgHeroData.createTimelocal
    heroData.lockState = _msgHeroData.lockState
    heroData.createtype = _msgHeroData.createtype
    heroData.changeId = _msgHeroData.changeId--置换id
    --> 战法
    
    heroData.warWaySlot1Id = _msgHeroData.warWaySlot1 or 0
    heroData.warWaySlot2Id = _msgHeroData.warWaySlot2 or 0

    heroData.planList = {}            --< 作战方案
    for i = 1, #_msgHeroData.combatPlans do
        heroData.planList[i] = {planId = _msgHeroData.combatPlans[i].planId, position = _msgHeroData.combatPlans[i].position}   --< 后端的第三个参数confPlanId不用
    end
    heroData.medal=_msgHeroData.medal                       -- 勋章
    heroData.suitActive=_msgHeroData.suit                   -- 勋章套装激活

    this.SetHeroTalentData(heroData, _msgHeroData)

    local _configData = heroConfig[_id]
    heroData.heroConfig = heroConfig[_id]
    local actionPowerRormula = gameSetting[1].ActionPowerRormula
    heroData.actionPower = force
    heroData.equipIdList = _msgHeroData.equipIdList
    heroData.talismanList = _msgHeroData.especialEquipLevel
    heroData.jewels = _msgHeroData.jewels
    if (#_msgHeroData.soulPos >= 1) then
        local soulPrintList = {}
        for i, v in ipairs(_msgHeroData.soulPos) do
            local soulPrint = { equipId = v.equipId, position = v.position }
            table.insert(soulPrintList, soulPrint)
        end
        heroData.soulPrintList = soulPrintList
    end

    heroData.skillIdList = {}
    HeroManager.UpdateSkillIdList( heroData)
    heroData.passiveSkillList = {}--被动技
    HeroManager.UpdatePassiveHeroSkill(heroData)
    --if guildSkill then
    
    --end
    heroData.guildSkill = guildSkill
    heroData.hp = _configData.Hp
    heroData.attack = _configData.Attack
    heroData.pDef = _configData.PhysicalDefence
    heroData.mDef = _configData.MagicDefence
    heroData.speed = _configData.Speed
    heroData.allAddProVal = {}
    for i, v in ConfigPairs(propertyConfig) do
        heroData.allAddProVal[i] = 0
    end
    for i, v in pairs(specialEffects) do
        if v.propertyId and v.propertyValue then
            
            if propertyConfig[v.propertyId] then
                if propertyConfig[v.propertyId].Style == 1 then
                    heroData.allAddProVal[v.propertyId] = v.propertyValue
                elseif propertyConfig[v.propertyId].Style == 2 then
                    heroData.allAddProVal[v.propertyId] = v.propertyValue/100
                end
            else
                heroData.allAddProVal[v.propertyId] = v.propertyValue
            end
        end
    end
    heroData.live = GetResourcePath(_configData.Live)
    heroData.profession = _configData.Profession
    heroData.ProfessionResourceId = _configData.ProfessionResourceId
    if GetJobSpriteStrByJobNum(_configData.Profession) then
        heroData.professionIcon = GetJobSpriteStrByJobNum(_configData.Profession)
    else
        heroData.professionIcon = GetJobSpriteStrByJobNum(1)
    end
    heroData.name = _configData.ReadingName
    heroData.painting = GetResourcePath(_configData.Painting)
    heroData.icon = GetResourcePath(_configData.Icon)
    heroData.scale = _configData.Scale
    heroData.position = _configData.Position
    heroData.property = _configData.PropertyName

    heroData.AdjustUnLock = _msgHeroData.AdjustUnLock       --铸神等级字段
    heroData.partsData = {}
    this.FreshGodEquipLevel(heroData.AdjustUnLock,heroData)
    return heroData
end

--初始化铸神数据
function this.FreshGodEquipLevel(unlockData,heroData)
    if unlockData and #unlockData > 0 then
        for i = 1, #unlockData do
            --> isUnLock -1未解锁，0已解锁，>0已升级       actualLv 实际应用等级
            heroData.partsData[unlockData[i].position] = {position = unlockData[i].position, isUnLock = unlockData[i].isUnLock, actualLv = 0}
        end
        local partsData = heroData.partsData
        for i = 1, #partsData do
            partsData[i].actualLv = 0
        end
        for i = 1, #heroData.equipIdList do
            local equipId = heroData.equipIdList[i]
            local equipConfig = G_EquipConfig[tonumber(equipId)]
            if partsData[equipConfig.Position] then
                if partsData[equipConfig.Position].isUnLock > 0 then
                    if equipConfig.IfAdjust == 1 then
                        partsData[equipConfig.Position].actualLv = math.min(partsData[equipConfig.Position].isUnLock, equipConfig.Adjustlimit)
                    end
                end
            end
        end
    end
end

--初始化装备数据
function this.InitEquipData(_msgEquipList, heroData)
    for i = 1, #_msgEquipList do
        this.InitUpdateEquipData(_msgEquipList[i], heroData)
    end
end

function this.InitUpdateEquipData(_equipData, heroData)
    local equipdata = {}
    if(heroData.soulPrintList) then
        for i, v in pairs(heroData.soulPrintList) do
            if (v.did == _equipData.id) then
                equipdata.icon = GetResourcePath(itemConfig[_equipData.equipId].ResourceID)
                equipdata.Quality = this.GetSoulPrintQuality(_equipData.equipId, _equipData.exp)
                equipdata.id = _equipData.equipId
                this.equipDatas[_equipData.id] = equipdata
            end
        end
    end
    if(heroData.equipIdList) then
        for i, v in pairs(heroData.equipIdList) do
            if (tonumber(v) == _equipData.equipId) then
                equipdata.equipConfig = equipConfig[_equipData.equipId]
                if equipdata.equipConfig ~= nil then
                    equipdata.itemConfig = itemConfig[_equipData.equipId]
                    equipdata.did = _equipData.equipId
                    equipdata.id = equipdata.equipConfig.Id
                    if itemConfig[equipdata.id] then
                        equipdata.icon = GetResourcePath(itemConfig[equipdata.id].ResourceID)
                    else

                        return
                    end
                    equipdata.frame = GetQuantityImageByquality(equipdata.equipConfig.Quality)--ItemQuality[equipdata.equipConfig.Quality].icon
                    equipdata.num = 1
                    equipdata.position = equipdata.equipConfig.Position
                    local propList = {}
                    for index, prop in ipairs(equipdata.equipConfig.Property) do
                        propList[index] = {}
                        propList[index].propertyId = prop[1]
                        propList[index].propertyValue = prop[2]
                        propList[index].PropertyConfig = propertyConfig[prop[1]]
                    end
                    equipdata.mainAttribute = propList
                    equipdata.star = equipStarsConfig[equipdata.equipConfig.Star].Stars
                    equipdata.backData = _equipData
                    this.equipDatas[_equipData.equipId] = equipdata
                end
            end
        end
    end
    if(heroData.talismanList) then
        --for i, v in pairs(heroData.talismanList) do
        --    if (v == _equipData.id) then
        --        equipdata.icon = GetResourcePath(itemConfig[_equipData.equipId].ResourceID)
        --        equipdata.id = _equipData.equipId
        --        equipdata.star = _equipData.rebuildLevel
        --        this.equipDatas[_equipData.id] = equipdata
        --    end
        --end
    end
    --宝器
    if(heroData.jewels) then
        for i = 1, #heroData.jewels do
            if heroData.jewels[i] and heroData.jewels[i] == _equipData.id then
                this.InitSingleTreasureData(_equipData)
            end
        end
    end
end

--宝器
local jewelConfig = ConfigManager.GetConfig(ConfigName.JewelConfig)
local allTreasures = {}
--初始化单个宝物的数据
function this.InitSingleTreasureData(_singleData)
    if _singleData==nil then
        return
    end
    local single={}
    local staticId=_singleData.equipId
    local currJewel=jewelConfig[staticId]
    single.id=staticId
    single.idDyn=_singleData.id
    single.lv=_singleData.exp
    single.refineLv=_singleData.rebuildLevel
    single.maxLv=currJewel.Max[1]
    single.maxRefineLv=currJewel.Max[2]
    single.upHeroDid=""
    local quantity=currJewel.Level
    single.quantity=quantity
    single.frame=GetQuantityImageByquality(quantity)
    single.name=itemConfig[staticId].Name
    single.itemConfig=itemConfig[staticId]
    single.levelPool=currJewel.LevelupPool
    single.proIcon=GetProStrImageByProNum(currJewel.Race)
    single.refinePool=currJewel.RankupPool
    single.equipType=currJewel.Location
    if currJewel.Location==1 then
        single.type=GetLanguageStrById(10505)
    else
        single.type=GetLanguageStrById(10506)
    end
    single.icon=GetResourcePath(itemConfig[staticId].ResourceID)
    single.strongConfig=this.GetCurrTreasureLvConfig(1,currJewel.LevelupPool,_singleData.exp)
    single.refineConfig=this.GetCurrTreasureLvConfig(2,currJewel.RankupPool,_singleData.rebuildLevel)
    
    allTreasures[_singleData.id]=single
end

local jewerLevelUpConfig = ConfigManager.GetConfig(ConfigName.JewelRankupConfig)
--获取当前宝物升级数据
function this.GetCurrTreasureLvConfig(_type,_id,_lv)
    for _, configInfo in ConfigPairs(jewerLevelUpConfig) do
        if configInfo.Type==_type and configInfo.PoolID==_id and configInfo.Level==_lv then
            return configInfo
        end
    end
end
--根据动态id获取宝物
function this.GetSingleTreasureByIdDyn(_idDyn)
    if allTreasures==nil then
        return
    end
    return allTreasures[_idDyn]

end

--获取单个装备数据
function this.GetSingleEquipData(_equipid)
    _equipid = tonumber(_equipid)
    if this.equipDatas[_equipid] then
        return this.equipDatas[_equipid]
    end
end

--得到魂印品质
function this.GetSoulPrintQuality(equipId, exp)
    SoulPrintManager.UpSoulPrintLevel(equipId, exp)
    for m, n in ConfigPairs(equipSign) do
        if (n.Id == SoulPrintManager.GetSoulPrintId(equipId, SoulPrintManager.soulPrintLevel[equipId])) then
            return n.Quality

        end
    end

end

this.modelData = {} --< 其他玩家模块数据 1方案
--> 初始模块数据 other为true用 他人方案.eg
function this.InitModelData(msg, heroData)
    this.modelData = {}
    --> 英雄身上挂的数据 如果满足需求 此处不用添加
    --> msg 为 ViewHeroInfoResponse
    if not this.modelData[1] then
        this.modelData[1] = {}
    end
    if heroData.planList and #heroData.planList > 0 and msg.combatPlans and #msg.combatPlans > 0 then
        for i = 1, #heroData.planList do
            for j = 1, #msg.combatPlans do
                if heroData.planList[i].planId == msg.combatPlans[j].id then
                    this.modelData[1][msg.combatPlans[j].id] = msg.combatPlans[j]
                    break
                end
            end
        end
    end
end

--> 方案
function this.GetModelData_1(planId)
    if not this.modelData[1] then
        LogError("GetModelData_1 no init Error!")
        return nil
    end
    if this.modelData[1][planId] then
        return this.modelData[1][planId]
    else
        LogError("GetModelData_1 getOther plan Error!")
    end
    return nil
end

--> 设置天赋数据
function this.SetHeroTalentData(heroData, msg)
    heroData.talent = {}
    for k, v in ipairs(msg.positionSkills) do
        local a = {}
        a.skillId = v.skillId
        a.position = v.position
        heroData.talent[a.position] = a
    end
end

return this