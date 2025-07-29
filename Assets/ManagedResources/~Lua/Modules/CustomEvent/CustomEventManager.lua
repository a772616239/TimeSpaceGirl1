CustomEventManager = {}
local this = CustomEventManager

function CustomEventManager.Initialize()
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnPlayerLvChange, this.hanldeOnPlayerLvChange)
    Game.GlobalEvent:AddEvent(GameEvent.Mission.OnOpenFight, this.handleOnOpenFight)
    Game.GlobalEvent:AddEvent(GameEvent.Vip.OnVipRankChanged,this.handlenVipRankChanged)
    Game.GlobalEvent:AddEvent(GameEvent.Friend.OnFriendList, this.handleOnFriendList)
    Game.GlobalEvent:AddEvent(GameEvent.CustomEvent.OnUpdateHeroDatas,this.handleOnUpdateHeroDatas)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.DataUpdate,this.hanleDataUpdate)
    Game.GlobalEvent:AddEvent(GameEvent.CustomEvent.OnPowerChange,this.handleOnPowerChange)
    Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, this.handleOnOpen)
end

--通用流程
function CustomEventManager.GameCustomEvent(param)
    this.CustomEvent(0,param)
end

--支付
function CustomEventManager.PayCustomEvent(param)
    this.CustomEvent(99,"支付"..param)
end

--功能解锁，因为解锁之与等级和关卡相关检测升级界面显示正好
function CustomEventManager.hanleOnOpen(panelType)
    if panelType == UIName.FightEndLvUpPanel then
        --检测功能解锁 
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)) do
            if v.OpenRules then
                if v.OpenRules[1] == 2 and PlayerManager.level >= v.OpenRules[2] and v.IsOpen == 1 then--等级解锁
                    this.CustomEvent(1,"功能解锁"..v.Id)
                end
            end
        end
    end
end

--关卡解锁
function CustomEventManager.handleOnOpenFight(fightId)
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)) do
        if v.OpenRules then
            if v.OpenRules[1] == 1 and fightId == v.OpenRules[2] and v.IsOpen == 1 then--1关卡开启
                this.CustomEvent(1,"关卡解锁"..v.Id)
            end
        end
    end
end

--获得新的好友
function CustomEventManager.handleOnFriendList()
    count = 0
    for i, v in pairs(GoodFriendManager.friendAllData) do
        count = count+1
    end
    this.CustomEvent(2,"获得新的好友"..count)
end

--获得新的英雄
function CustomEventManager.handleOnUpdateHeroDatas()
    count = 0
    for i, v in pairs(HeroManager.GetAllHeroDatas()) do
        count = count+1
    end
    this.CustomEvent(3,"获得新的英雄"..count)
end

--玩家升级
function CustomEventManager.hanldeOnPlayerLvChange()
    this.CustomEvent(4,"玩家升级"..PlayerManager.level)
end


--Vip等级改变
function CustomEventManager.handlenVipRankChanged()
    this.CustomEvent(5,"Vip等级改变"..VipManager.GetVipLevel())
end

--战力变化
function CustomEventManager.handleOnPowerChange(maxPower)
    this.CustomEvent(6,"战力变化"..maxPower)
end

--加入公会
function CustomEventManager.hanleDataUpdate()
    this.CustomEvent(7,"加入公会")
end

--0.通用流程，部分在C#里实现
--1.解锁功能
--2.好友聊表数据变化
--3.获得英雄时触发 英雄数量
--4.玩家升级
--5.vip等级提升
--6.战斗力提升
--7.加入公会
--99.充值相关，大部分在Sdk里实现
function this.CustomEvent(type,param)
    if AppConst.isSDKLogin then
        SDKMgr:CustomEvent(type,tostring(param))
    end
end

return this