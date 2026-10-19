#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修正 RankingSingleListPanel 前三名（firstHead / secondHead / thirdHead）国家小旗：

1. 抽出 SetHeadFlag(index, data) 作为**唯一**写入点，缺数据/公会榜时隐藏而不是不管；
2. SetHeadsInfo 复用它（原来只有 6 个榜单走这条路径）；
3. 英雄战力榜 SetHeadsHeroInfo 从来**没写过旗** ⇒ 保留上一屏的旧旗（国籍不对），补上；
4. 英雄榜「我的排名」行同理，补 RefreshMyRankFlag；
5. 竞技场 SetArenaInfo 的二/三名传的是 ArenaEnemy 包装（没有 uid/country/name/level），
   改成 personInfo —— 顺带修掉 "LV." .. nil 的隐式报错（被 xpcall 吞掉）。

幂等：重复执行不会重复插入。保留原文件 CRLF 行尾。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TARGET = os.path.join(ROOT, "Assets/ManagedResources/~Lua/Modules/Ranking/RankingSingleListPanel.lua")

HELPERS = '''--[[
 * 前三名立绘区的国家小旗
 *
 * ⚠️ 小旗是挂在立绘节点（firstHead/secondHead/thirdHead）上的**长驻**节点，
 *   不会随名次数据自动清空。只要某条渲染路径漏写它，画面就会保留上一次
 *   （别的榜单 / 上一次打开）画上去的国旗 —— 头像和名字换了、旗子还是旧的，
 *   看起来正是「前三国籍不对」。所以：
 *     · 显示前三名的每条路径都必须显式调用 SetHeadFlag；
 *     · 没有这个名次、或公会榜（展示公会名，没有玩家国籍）→ 隐藏，而不是不管。
--]]
local function HeadGoOf(index)
    if index == 1 then return this.firsthead end
    if index == 2 then return this.secondhead end
    if index == 3 then return this.thirdhead end
    return nil
end

local function HideHeadFlag(index)
    local headRoot = HeadGoOf(index)
    if headRoot == nil or IsNull(headRoot) then
        return
    end
    local flagGo = Util.GetGameObject(headRoot, "countryFlag")
    if flagGo ~= nil and not IsNull(flagGo) then
        flagGo:SetActive(false)
    end
end

--- 给第 index 名画国旗；data 必须是**这个名次对应的那个玩家**的记录
function this.SetHeadFlag(index, data)
    if sData and (sData.rankType == RANK_TYPE.GUILD_FORCE_RANK
            or sData.rankType == RANK_TYPE.CELEBRATION_GUILD) then
        HideHeadFlag(index)
        return
    end
    if data == nil then
        HideHeadFlag(index)
        return
    end
    local headRoot = HeadGoOf(index)
    if headRoot == nil or IsNull(headRoot) then
        return
    end
    CountryFlagUtil.ApplyTo(headRoot, data.uid, data.country)
end

'''

OLD_HEADS = '''--设置前三名背景头像
function this.SetHeadsInfo(data,root,index,name,level)
    -- 前三名立绘区的国家小旗
    local headRoot = (index == 1 and this.firsthead) or (index == 2 and this.secondhead) or this.thirdhead
    if headRoot then
        CountryFlagUtil.ApplyTo(headRoot, data.uid, data.country)
    end
'''

NEW_HEADS = '''--设置前三名背景头像
function this.SetHeadsInfo(data,root,index,name,level)
    -- 前三名立绘区的国家小旗（与列表行走同一套口径，见 SetHeadFlag）
    this.SetHeadFlag(index, data)
    -- 名次数据缺名字/等级时不要拼出 nil（arena 曾因此静默中断整条渲染）
    name = name or ""
    level = level or 0
'''

HERO_SIG = '''function this.SetHeadsHeroInfo(data,root,index,name,level)   
'''

HERO_SIG_NEW = '''function this.SetHeadsHeroInfo(data,root,index,name,level)   
    -- 英雄榜的前三立绘走的是 HeroHead，但小旗是同一批节点 ⇒ 同样必须显式刷
    this.SetHeadFlag(index, data)
'''

OLD_HERO_MY = '''    local length = args[4]+OffsetTop+1        -- 未设缓存列表为当前最大长度
    this.TextTopEnd.text = topEndName
'''

NEW_HERO_MY = '''    local length = args[4]+OffsetTop+1        -- 未设缓存列表为当前最大长度
    this.TextTopEnd.text = topEndName
    -- 英雄榜不走 SetNotRollingInfo，「我的排名」行的旗要自己刷，否则留着上一屏的
    this.RefreshMyRankFlag()
'''

OLD_ARENA = '''    this.SetHeadsInfo(arenaData[1].personInfo,this.firstHeadinfoGo,1,arenaData[1].personInfo.name,arenaData[1].personInfo.level)   
    if #arenaData >= 2 then
        this.SetHeadsInfo(arenaData[2],this.secondHeadinfoGo,2,arenaData[2].name,arenaData[2].level)
    end
    if #arenaData >= 3 then
        this.SetHeadsInfo(arenaData[3],this.thirdHeadinfoGo,3,arenaData[3].name,arenaData[3].level)
    end
'''

NEW_ARENA = '''    -- ⚠️ rankInfos 的元素是 ArenaEnemy（只有 personInfo/team/title），
    --    玩家本身在 personInfo 里；早先二/三名传了包装对象 ⇒ uid/country 为 nil，
    --    国旗只能是问号旗，name/level 也是 nil（"LV." .. nil 会被 xpcall 吞掉）
    this.SetHeadsInfo(arenaData[1].personInfo,this.firstHeadinfoGo,1,arenaData[1].personInfo.name,arenaData[1].personInfo.level)   
    if #arenaData >= 2 then
        local info = arenaData[2].personInfo or arenaData[2]
        this.SetHeadsInfo(info,this.secondHeadinfoGo,2,info.name,info.level)
    end
    if #arenaData >= 3 then
        local info = arenaData[3].personInfo or arenaData[3]
        this.SetHeadsInfo(info,this.thirdHeadinfoGo,3,info.name,info.level)
    end
'''


def main():
    with io.open(TARGET, "rb") as f:
        raw = f.read()
    text = raw.decode("utf-8").replace("\r\n", "\n")
    before = text

    def sub(old, new, label):
        nonlocal text
        if new.strip() and new in text:
            print("  = 已是新的：%s" % label)
            return
        n = text.count(old)
        if n != 1:
            print("  ✗ 锚点命中 %d 次（应为 1）：%s" % (n, label))
            sys.exit(1)
        text = text.replace(old, new, 1)
        print("  + %s" % label)

    if "function this.SetHeadFlag(index, data)" not in text:
        sub(OLD_HEADS, HELPERS + NEW_HEADS, "抽 SetHeadFlag + SetHeadsInfo 复用")
    else:
        print("  = SetHeadFlag 已存在")
        sub(OLD_HEADS, NEW_HEADS, "SetHeadsInfo 复用 SetHeadFlag")

    sub(HERO_SIG, HERO_SIG_NEW, "英雄榜前三补国旗")
    sub(OLD_HERO_MY, NEW_HERO_MY, "英雄榜「我的排名」补国旗")
    sub(OLD_ARENA, NEW_ARENA, "竞技场二/三名改用 personInfo")

    if text == before:
        print("没有改动")
        return

    with io.open(TARGET, "wb") as f:
        f.write(text.replace("\n", "\r\n").encode("utf-8"))
    print("完成：已写回（CRLF 保持）")


if __name__ == "__main__":
    main()
