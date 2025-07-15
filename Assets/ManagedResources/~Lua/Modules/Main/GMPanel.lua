require("Base/BasePanel")
GMPanel = Inherit(BasePanel)
local this = MainPanel
local GMType = {
    AddItem = 1,--添加道具
    AddCard = 2,--添加卡牌
    SendMail = 3,--发送邮件
    AddHeroForStar = 4,--添加指定星级英雄
    OpenMap = 5,--开启到指定关卡
    PlayerUpLevel = 7,--玩家升级
    OpenAllMap = 8,--通关所有关卡
    OpenMapForValue = 9,--开启对应关卡
    UpVipLv = 11,--升级vip 
    ResetPlayerName = 12,--修改玩家名字
    FinishTask = 20,--完成任务
    TowerOfGod = 25,--神之塔
    SupportActiveAll = 28,--一键激活全部守护
    SimulationFight = 29,--模拟战斗
    HeterodoxWar = 30,--异端之战
    AbyssTrial = 31,--深渊试炼
    FogBattle = 32,--迷雾之战

    --与后端命令无关
    Guide = 997,--引导
    TestBattle = 998,--测试战斗
    Jump = 999,--跳转

    --按钮
    GetFiveHero = 1001,--五个12星英雄
    MaxLv = 1002,--角色升级
    GetMoney = 1003,--获得20E
    Artifact = 1004,--所有守护解锁
    PassFight = 1005,--通关所有关
    Adjutant = 1006,--所有先驱解锁
    GetAllHero = 1007,--获得所有英雄
    Fight100 = 1008,--通关100关
}
local GmLeft = {
    [1] = {parfab = "name", GMType = GMType.ResetPlayerName},
    [2] = {parfab = "playerLevel", GMType = GMType.PlayerUpLevel},
    [3] = {parfab = "vipLevel", GMType = GMType.UpVipLv},
    [4] = {parfab = "item", GMType = GMType.AddItem},
    [5] = {parfab = "hero", GMType = GMType.AddHeroForStar},
    [6] = {parfab = "task", GMType = GMType.FinishTask},
    [7] = {parfab = "threadLevel", GMType = GMType.OpenMapForValue},
    [8] = {parfab = "tower", GMType = GMType.TowerOfGod},
    [9] = {parfab = "HeterodoxWar", GMType = GMType.HeterodoxWar},
    [10] = {parfab = "AbyssTrial", GMType = GMType.AbyssTrial},
    [11] = {parfab = "FogBattle", GMType = GMType.FogBattle},
    [12] = {parfab = "jump", GMType = GMType.Jump},
    [13] = {parfab = "mail", GMType = GMType.SendMail},
    [14] = {parfab = "fakeBattle", GMType = GMType.TestBattle},
    [15] = {parfab = "guide", GMType = GMType.Guide},
}
local GmBtn = {
    [1] = {parfab = "btnGenerateFiveHero", GMType = GMType.GetFiveHero},
    [2] = {parfab = "btnMaxLv", GMType = GMType.MaxLv},
    [3] = {parfab = "btnGetMoney", GMType = GMType.GetMoney},
    [4] = {parfab = "btnArtifact", GMType = GMType.Artifact},
    [5] = {parfab = "btnFightPass", GMType = GMType.PassFight},
    [6] = {parfab = "btnAdjutant", GMType = GMType.Adjutant},
    [7] = {parfab = "btnGetAll15StarHero", GMType = GMType.GetAllHero},
    [8] = {parfab = "btnFight100", GMType = GMType.Fight100},
}

--初始化组件（用于子类重写）
function GMPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.close = Util.GetGameObject(self.transform, "close")

    this.GmList = {}
    this.content = Util.GetGameObject(self.gameObject, "Scroll/Viewport/Content/ProcessCtrl")
    for key, value in pairs(GmLeft) do
        this.GmList[#this.GmList+1] = {
            parfab = value.parfab,
            btn = Util.GetGameObject(this.content, value.parfab.."/Button"),
            type = value.GMType
        }
    end

    this.GmBtnList = {}
    this.btnGrid = Util.GetGameObject(self.gameObject, "Scroll/Viewport/Content/btns")
    for key, value in pairs(GmBtn) do
        this.GmBtnList[#this.GmBtnList+1] = {
            btn = Util.GetGameObject(this.btnGrid, value.parfab),
            type = value.GMType
        }
    end

    --时间
    this.timeCtrl = Util.GetGameObject(self.transform, "Scroll/Viewport/Content/TimeCtrl")
    this.serverNowTimeText = Util.GetGameObject(this.timeCtrl, "serverNowTime"):GetComponent("Text")--当前时间
    this.serverOpenTimeText = Util.GetGameObject(this.timeCtrl, "serverOpenTime"):GetComponent("Text")--开服时间
    this.serverCreateRoleTimeText = Util.GetGameObject(this.timeCtrl, "serverCreateRoleTime"):GetComponent("Text")--创角时间
end

--绑定事件（用于子类重写）
function GMPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.close, function()
        self:ClosePanel()
    end)

    for i = 1,#this.GmList do
        Util.AddOnceClick(this.GmList[i].btn, function()
            local txt = Util.GetGameObject(this.content, this.GmList[i].parfab.."/InputField/Text"):GetComponent("Text").text
            if not txt or txt == "" then
                return
            end
            local type = this.GmList[i].type
            local value1 = txt
            local value2 = 0
            local func = nil
            if type == GMType.UpVipLv then
                value2 = txt
                func = VipManager.SetVipLevel(tonumber(txt))
            elseif type == GMType.OpenMapForValue then
                value2 = txt
            elseif type == GMType.FinishTask then
                value1 = 0
                value2 = txt
            elseif type == GMType.SendMail then
                local txt2 = Util.GetGameObject(this.content, "mail/InputField2/Text"):GetComponent("Text").text
                value2 = txt2
            elseif type == GMType.Jump then
                JumpManager.GoJump(tonumber(txt))
                return
            elseif type == GMType.TestBattle then
                local strs = string.split(txt, "#")
                local left_id = tonumber(strs[1])
                local right_id = tonumber(strs[2])
                local round = tonumber(strs[3])
                local testFightData = BattleManager.GetBattleServerDataEVE(left_id,right_id,round)
                UIManager.OpenPanel(UIName.BattleStartPopup, function ()
                    UIManager.OpenPanel(UIName.BattlePanel, testFightData, BATTLE_TYPE.Test)
                end)
                return
            elseif type == GMType.Guide then
                local strs = string.split(txt, "#")
                if tonumber(strs[1]) == 1 then
                    NetManager.SaveGuideDataRequest(tonumber(strs[1]), tonumber(strs[2]))
                elseif tonumber(strs[1]) == 2 then
                    GuideManager.OnFunctionOpen(tonumber(strs[2]))
                end
                return
            end
            local str = string.format("%s#%s#%s", type, value1, value2)
            NetManager.GMEvent(str, func)
        end)
    end

    for i = 1,#this.GmBtnList do
        Util.AddOnceClick(this.GmBtnList[i].btn, function()
            local type = this.GmBtnList[i].type
            if type == GMType.GetFiveHero then
                local heroList = {10001, 10002, 10003, 10004, 10005}
                for i = 1, #heroList do
                    NetManager.GMEvent(string.format("%s#%s#%s", GMType.AddHeroForStar, heroList[i], 10))
                end
            elseif type == GMType.MaxLv then
                NetManager.GMEvent(string.format("%s#%s#%s", GMType.PlayerUpLevel, 100, 0))
            elseif type == GMType.GetMoney then
                local moneyList = {3, 4, 14, 16}
                for i = 1, #moneyList do
                    NetManager.GMEvent(string.format("%s#%s#%s", GMType.AddItem, moneyList[i], 2000000000))
                end
            elseif type == GMType.Artifact then
                NetManager.GMEvent(string.format("%s#%s#%s", GMType.SupportActiveAll, 0, 10))
            elseif type == GMType.PassFight then
                NetManager.GMEvent(string.format("%s#%s#%s", GMType.OpenAllMap, 1, 1))
                Util.GetGameObject(this.GmBtnList[i].btn, "Text"):GetComponent("Text").text = "已通关所有关卡"
            elseif type == GMType.Adjutant then
                local AdjutantList = {120001, 120002}
                for i = 1, #AdjutantList do
                    NetManager.GMEvent(string.format("%s#%s#%s", GMType.AddItem, AdjutantList[i], 1))
                end
            elseif type == GMType.GetAllHero then
                local heroConfig = ConfigManager.GetAllConfigsData(ConfigName.HeroConfig)
                for i = 1, #heroConfig do
                    if heroConfig[i].Quality == 5 then
                        NetManager.GMEvent(string.format("%s#%s#%s", GMType.AddHeroForStar, heroConfig[i].Id, 13))
                    end
                end
                PopupTipPanel.ShowTip("获得所有可13星英雄完毕")
            elseif type == GMType.Fight100 then
                NetManager.GMEvent(string.format("%s#%s#%s", GMType.OpenMapForValue, 6011, 6011))
                PopupTipPanel.ShowTip("通关100关")
            end
        end)
    end
end

--添加事件监听（用于子类重写）
function GMPanel:AddListener()
end

--移除事件监听（用于子类重写）
function GMPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GMPanel:OnOpen(...)
    NetManager.GMEvent("10#1#0", function(msg)
        this.serverNowTimeText.text = msg.info
    end)
    NetManager.GMEvent("10#2#0", function(msg)
        this.serverOpenTimeText.text = msg.info
    end)
    NetManager.GMEvent("10#3#0", function(msg)
        this.serverCreateRoleTimeText.text = msg.info
    end)
end

--界面关闭时调用（用于子类重写）
function GMPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function GMPanel:OnDestroy()
end

return GMPanel