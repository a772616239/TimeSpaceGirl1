DeathPosManager = {};
local this = DeathPosManager
local guildSetting=ConfigManager.GetConfig(ConfigName.GuildSetting)
this.status=0 --十绝阵阶段状态 0未开启 1挑战阶段 2领奖阶段
this.allowchallange = 0--是否中途加入公会
local rewardData={} --全部宝箱奖励数据（未翻牌）
local myRewardData={} --全部宝箱奖励数据（已翻牌）
local doRewardData={} --其他玩家点击领取奖励推送数据（单组数据）
local guildInfoData={} --公会信息数据
this.drop=nil --十绝阵挑战奖励掉落
this.damage=0--十绝阵挑战本次伤害
this.historyMax=0 --十绝阵挑战历史最高伤害
this.maxBattleTime=0 --最大挑战次数
this.battleTime=0 --剩余挑战次数
this.rewardTimeTip=""


function this.Initialize()
    this.maxBattleTime=guildSetting[1].ChallengeMaxTime
end


--登陆初始化
function this.InitData(func)
    if not PlayerManager.familyId or PlayerManager.familyId == 0 then
        if func then func() end
        return
    end
    NetManager.GetDeathPathStatusResponse(function(msg)
        this.allowchallange=msg.allowchallange
        this.status=msg.status
        if this.status==DeathPosStatus.Fight then --请求剩余挑战次数
            NetManager.GetDeathPathInfoResponse(function(msg1)
                this.battleTime= this.maxBattleTime-msg1.challengeCount
                if func then func() end
            end)
        elseif this.status==DeathPosStatus.Reward then --请求奖励宝箱数据
            NetManager.GetAllDeathPathRewardInfoResponse(function(msg2)
                rewardData=msg2.info
                for i = 1, #rewardData do
                    local isHave = false
                    for j=1, #rewardData do
                        if rewardData[j].position>0 and rewardData[j].position==i then
                            isHave = true
                            table.insert(myRewardData,rewardData[j])
                        end
                    end
                    if not isHave then
                        table.insert(myRewardData,{uid=0,username = "",position=i})
                    end
                end
                CheckRedPointStatus(RedPointType.Guild_DeathPos)
                if func then func() end
            end)
        else
            if func then func() end
        end
    end)
end


--推送设置奖励翻牌数据
function this.SetDoRewardIndication(data)
    doRewardData=data
end
--获取奖励翻牌数据（单一）
function this.GetDoRewardData()
    return doRewardData
end

--设置奖励数据（未翻牌）
function this.SetRewardData(v)
    rewardData=v
end

--获取奖励数据（未翻牌）
function this.GetRewardData()
    return rewardData
end

-- --设置奖励数据（已翻牌）
function this.SetMyRewardData(v)
    myRewardData=v
end
-- --获取奖励数据（已翻牌）
-- function this.GetMyRewardData()
--     return myRewardData
-- end


--设置公会信息数据 data msg.infos
function this.SetGuildInfoData(data)
    guildInfoData=data
end
--推送设置公会信息数据 data msg.changeInfo
function this.SetGuildInfoIndication(data)
    for i, v in ipairs(guildInfoData) do
        if data.pathId==v.pathId then
            guildInfoData[i]=data
        else
            table.insert(guildInfoData,data)
        end
    end
end
--获取公会信息修改数据
function this.GetGuildInfoData()
    return guildInfoData
end

--获取是否参与十绝阵
function this.GetIsTakeIn()
    local isTakeIn=false
     for j = 1, #rewardData do
        if rewardData[j].uid==PlayerManager.uid then
            isTakeIn=true
            break
        else
            isTakeIn=false
        end
    end
    return isTakeIn
end

--是否领取过奖励
function this.GetIsGeted(d)
    local isGet=false
    for i, v in ipairs(d) do
        if v.uid==PlayerManager.uid then
            isGet=true
            break
        else
            isGet=false
        end
    end
    return isGet
end

--伤害位数转换
function this.ChangeDamageForm(_damage)
    local damage = _damage
    if damage/100000000 >= 1 then
        return tostring(string.format(GetLanguageStrById(12100), math.floor(damage/1000000)/100))
    end
    if damage/100000 >= 1 then
        return tostring(math.floor(damage/10000))..GetLanguageStrById(10042)
    end
    return damage
end

--红点检测
function this.CheckDeathPosRedPoint()
    local b=false
    if this.battleTime>0 then --若有剩余挑战次数
        b=true
    end
    --领奖状态
    if this.status==DeathPosStatus.Reward then
        if this.GetIsTakeIn()==false then --没参与十绝阵 你显示什么红点
            b=false
            return b
        end
        if this.GetIsGeted(myRewardData) then --参与了 领取了 不显示；没领 显示
            b=false
        else
            b=true
        end
    end
    return b
end



return this