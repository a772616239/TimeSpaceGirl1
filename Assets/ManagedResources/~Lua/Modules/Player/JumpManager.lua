JumpManager = {};
local this = JumpManager
local JumpConfig = ConfigManager.GetConfig(ConfigName.JumpConfig)
function this.Initialize()

end

local jumpDic = {
    [JumpType.Lottery] = function(data)
       UIManager.OpenPanel(UIName.RecruitPanel)
    end,
    -- [JumpType.DifferDemons] = function()
    --     UIManager.OpenPanel(UIName.DiffMonsterPanel)
    -- end,
    [JumpType.Guild] = function()
        if not MyGuildManager.CheckGuildExitCdTime(true) then return end

        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
            if PlayerManager.familyId == 0 then
                UIManager.OpenPanel(UIName.GuildFindPopup)
            else
                -- 进入公会界面之前初始化一遍数据
                MyGuildManager.InitAllData(function()
                    UIManager.OpenPanel(UIName.GuildMainCityPanel)
                end)
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GUILD))
        end
    end,
    [JumpType.GuideBattle] = function()
        if not MyGuildManager.CheckGuildExitCdTime(true) then return end

        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
            if PlayerManager.familyId == 0 then
                UIManager.OpenPanel(UIName.GuildFindPopup)
            else
                if UIManager.IsOpen(UIName.GuildMainCityPanel) then
                    UIManager.OpenPanel(UIName.GuildBattlePanel)
                else
                    GuildBattleManager.InitData(function ()
                        MyGuildManager.InitAllData(function()
                            UIManager.OpenPanel(UIName.GuildMainCityPanel)
                            UIManager.OpenPanel(UIName.GuildBattlePanel)
                        end)
                    end)
                end
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GUILD))
        end
    end,
    -- [JumpType.WorkShop] = function()
    --     UIManager.OpenPanel(UIName.WorkShowTechnologPanel)
    -- end,
    -- [JumpType.Foods] = function()
    --     UIManager.OpenPanel(UIName.FoodShopMainPanel)
    -- end,
    -- [JumpType.Adventure] = function(data)
    --     local openPanle =  UIManager.OpenPanel(UIName.AdventureMainPanel)
    --     if openPanle and data and data[1] < 0 then
    --         --引导光圈 -1 时再极速探索显示按钮
    --         openPanle.ShowGuideGo()
    --     end
    -- end,
    [JumpType.Arena] = function(data)
        local arenaDefend = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_ARENA_DEFEND)
        if #arenaDefend.teamHeroInfos == 0 then
            -- LogColor("red","竞技防守编队为空")
            local formation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_NORMAL)
            local newFormation = {}
            for index = 1, #formation.teamHeroInfos do
                local teamInfo = formation.teamHeroInfos[index]
                local singleData = {}
                singleData.heroId = teamInfo.heroId
                singleData.position = index
                table.insert(newFormation, singleData)
            end
            
            FormationManager.RefreshFormation(FormationTypeDef.FORMATION_ARENA_DEFEND,newFormation,"",formation.teamPokemonInfos)
        end
        local openPanle =  UIManager.OpenPanel(UIName.ArenaMainPanel)
        if openPanle and data and data[1]  then
            --引导光圈 -1 时  第一个挑战
            if data[1] < 0 then
                openPanle.ShowGuideGo()
            end
        end
    end,
    [JumpType.AreaThumbsUp] = function ()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALLRANKING) then
            local types = {}
            local activiteIds = {}
            for i = 1, #RankKingList do
                if RankKingList[i].isRankingMainPanelShow then
                    table.insert(types,RankKingList[i].rankType)
                    table.insert(activiteIds,RankKingList[i].activiteId)
                end
            end
            NetManager.RankFirstRequest(types,activiteIds,function (msg)
                UIManager.OpenPanel(UIName.RankingListMainPanel,msg)
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ALLRANKING))
        end
    end,
    -- [JumpType.HanYuan] = function()
    --     PopupTipPanel.ShowTipByLanguageId(11501)
    -- end,
    -- [JumpType.WangHun] = function()
    --     PopupTipPanel.ShowTipByLanguageId(11501)
    -- end,
    [JumpType.DailyTasks] = function()
        UIManager.OpenPanel(UIName.MissionDailyPanel)
    end,
    -- [JumpType.WorldBoss] = function()
    --     PopupTipPanel.ShowTipByLanguageId(11501)
    -- end,
    [JumpType.Talking] = function()
        UIManager.OpenPanel(UIName.ChatPanel)
    end,
    [JumpType.LoginReward] = function(data)
       UIManager.OpenPanel(UIName.EightDayGiftPanel)
    end,
    [JumpType.OnlineReward] = function(data)
        if data then
            UIManager.OpenPanel(UIName.OnlineRewardPanel)
        end
    end,
    -- [JumpType.CommonChallenge] = function(data)
    --     local  jumpCarbonId = CarbonManager.NeedLockId(data[2],1)
    --     local openPanle
    --     if jumpCarbonId then
    --         if jumpCarbonId == data[2] or data[2] == -1 then
    --             CarbonManager.difficulty = data[1]
    --             openPanle = UIManager.OpenPanel(UIName.PlotCarbonPanel,jumpCarbonId)
    --             if openPanle then
    --                 openPanle.ShowGuideGo(jumpCarbonId)
    --             end
    --         else
    --             MsgPanel.ShowTwo(GetLanguageStrById(11502), nil, function ()
    --                 CarbonManager.difficulty = data[1]
    --                 openPanle =  UIManager.OpenPanel(UIName.PlotCarbonPanel,jumpCarbonId)
    --                 if openPanle then
    --                     openPanle.ShowGuideGo(jumpCarbonId)
    --                 end
    --             end)
    --         end
    --     else
    --         PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(JumpType.CommonChallenge))
    --     end
    -- end,
    -- [JumpType.HeroChallenge] = function(data)
    --     local  jumpCarbonId = CarbonManager.NeedLockId(data[2],3,math.floor(data[2]/10))
    --     local openPanle
    --     if jumpCarbonId then
    --         if jumpCarbonId == data[2] or data[2] == -1 then
    --             CarbonManager.difficulty = data[1]
    --             openPanle =  UIManager.OpenPanel(UIName.EliteCarbonPanel,jumpCarbonId)
    --             if openPanle then
    --                 openPanle.JumpChooseRefresh(jumpCarbonId)
    --                 openPanle.ShowGuideGo(jumpCarbonId)
    --             end
    --         else
    --             MsgPanel.ShowTwo(GetLanguageStrById(11502), nil, function ()
    --                 CarbonManager.difficulty = data[1]
    --                 openPanle =  UIManager.OpenPanel(UIName.EliteCarbonPanel,jumpCarbonId)
    --                 if openPanle then
    --                     openPanle.JumpChooseRefresh(jumpCarbonId)
    --                     openPanle.ShowGuideGo(jumpCarbonId)
    --                 end
    --             end)
    --         end
    --     else
    --         PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(JumpType.HeroChallenge))
    --     end
    -- end,
    [JumpType.ChapterReward] = function(data)
        if data then
            UIManager.OpenPanel(UIName.CourtesyDressPanel,ActivityTypeDef.ChapterAward)
        end
    end,
    -------------超市-------------
    [JumpType.Store] = function(data)
        local isActive, tips = ShopManager.IsActive(data[1])
        if not isActive then
            PopupTipPanel.ShowTip(tips or GetLanguageStrById(10528))
            return
        end
        UIManager.OpenPanel(UIName.MainShopPanel,data[1])
    end,
    [JumpType.EndlessShop] = function()
        local isActive, tips = ShopManager.IsActive(13)
        if not isActive then
            PopupTipPanel.ShowTip(tips or GetLanguageStrById(10574))
            this.isOpen = false
            return
        end
        UIManager.OpenPanel(UIName.MainShopPanel, 13)
    end,
    [JumpType.LaddersShop] = function()
        UIManager.OpenPanel(UIName.MainShopPanel, 64)
    end,
    [JumpType.RouletteShop] = function()
        UIManager.OpenPanel(UIName.MainShopPanel, 61)
    end,
    [JumpType.ChipShop] = function()
        if not ShopManager.IsActive(67) then
            PopupTipPanel.ShowTipByLanguageId(11926)
            return
        end
        UIManager.OpenPanel(UIName.MainShopPanel, 67)
    end,
    [JumpType.AdjutantShop] = function()
        UIManager.OpenPanel(UIName.MainShopPanel, 102)
    end,
    [JumpType.WorldbossShop] = function()
        UIManager.OpenPanel(UIName.MainShopPanel, 65)
    end,
    [JumpType.CampWarShop] = function()
        UIManager.OpenPanel(UIName.MainShopPanel, 79)
    end,	
    -------------END-------------
    [JumpType.BlackShop] = function(data)
        local isActive, tips = ShopManager.IsActive(data[1])
        if not isActive then
            PopupTipPanel.ShowTip(tips or GetLanguageStrById(10528))
            return
        end
        UIManager.OpenPanel(UIName.BlackShopPanel,data[1])
    end,
    -- [JumpType.DifferDemonsBox] = function(data)
    --     local openPanle =  UIManager.OpenPanel(UIName.SecretBoxPanel)
    --     if openPanle and data and data[1] then
    --         --引导光圈   单抽
    --         openPanle.ShowGuideGo()
    --     end
    -- end,
    [JumpType.MemberCamp] = function()
        HeroManager.heroListPanelSortID = 1
        HeroManager.heroListPanelProID = 0
       UIManager.OpenPanel(UIName.RoleListPanel)
    end,
    [JumpType.StoreHouse] = function(data)
        if data then
            local openPanle = UIManager.OpenPanel(UIName.BagPanel,data[1])
            if openPanle then
                --引导光圈   可合成碎片第一个
                openPanle.ShowGuideGo()
            end
        else
            UIManager.OpenPanel(UIName.BagPanel)
        end
    end,
    [JumpType.Resolve] = function(data)--遣散 2回收
        if data then
            if data[1] == 1 then
                UIManager.OpenPanel(UIName.ResolvePanel,data[2])
            elseif data[1] == 2 then
                UIManager.OpenPanel(UIName.HeroAndEquipResolvePanel,data[2])
            end
        end
    end,
    [JumpType.Friend] = function(data)
        UIManager.OpenPanel(UIName.GoodFriendMainPanel,nil,data[1])
    end,
    [JumpType.Level] = function(data)
        local openPanle
            openPanle = UIManager.OpenPanel(UIName.FightPointPassMainPanel)
        if openPanle then
            openPanle.ShowGuideGo(data[1])
        end
    end,
    -------------充值-------------
    [JumpType.recharge] = function(data)
        UIManager.OpenPanel(UIName.MainRechargePanel, data[1])
    end,
    [JumpType.RechargeStore] = function(data)
        UIManager.OpenPanel(UIName.MainRechargePanel, 1)
    end,
    -------------END-------------
    [JumpType.DatTask] = function(data)
        UIManager.OpenPanel(UIName.MissionDailyPanel)
    end,
    -- [JumpType.Talent] = function(data)
    --    local openPanle = UIManager.OpenPanel(UIName.TalentPanel,{})
    --    if openPanle then
    --        --引导光圈 注入按钮
    --        openPanle.ShowGuideGo()
    --    end
    -- end,
    [JumpType.Trial] = function(data)
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.TRIAL) then
            CarbonManager.difficulty = 2
            local trialDataConfig = ConfigManager.GetConfig(ConfigName.TrialConfig)

            MapManager.curCarbonType = CarBonTypeId.TRIAL
            NetManager.MapInfoRequest(MapManager.curCarbonType, function(msg)
                MapManager.isReloadEnter = false
                MapTrialManager.firstEnter = true
                MapManager.SetViewSize(20)--设置视野范围（明雷形式）
                MapManager.curAreaId = FormationTypeDef.FORMATION_DREAMLAND
                MapManager.trialHeroInfo = msg.infos
                -- SwitchPanel.OpenPanel(UIName.MapPanel)
                UIManager.OpenPanel(UIName.MapPanel)
            end)
        else
            if not ActTimeCtrlManager.IsQualifiled(id) then
                local config = ConfigManager.GetConfigData(ConfigName.GlobalSystemConfig,FUNCTION_OPEN_TYPE.TRIAL)
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12297),config.OpenRules[2]))
            else
                PopupTipPanel.ShowTipByLanguageId(12298)
            end
        end
    end,
    -------------------赞助-------------------
    [JumpType.BuyVigor] = function(data)
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.Energy })
    end,
    [JumpType.BuyGold] = function(data)
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.Gold })
    end,
    [JumpType.QuickPurchase] = function(data)
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = data[1] })
    end,
    [JumpType.EndlessXingDongliBuy] = function(data)
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = 1 })
    end,
    -------------------END-------------------
    [JumpType.ElementDrawCard] = function(data)
        UIManager.OpenPanel(UIName.CompoundHeroPanel)
    end,
    -- [JumpType.Pray] = function(data)
    --     if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.Pray)  then
    --         UIManager.OpenPanel(UIName.PrayMainPanel)
    --     else
    --         PopupTipPanel.ShowTipByLanguageId(11503)
    --     end
    -- end,
    [JumpType.Welfare] = function(data)
        UIManager.OpenPanel(UIName.OperatingPanel,{tabIndex = data[1],extraParam = data[2] })
    end,
    [JumpType.DailyFirstCharge] = function(data)
        UIManager.OpenPanel(UIName.DailyRechargePanel)
    end,
    -------------------限时活动-------------------
    [JumpType.Expert] = function(data)
        if data and data[1] then
            if data[1] == ExperType.ExChange then--限时兑换
                local LimitExchange = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LimitExchange)
                if LimitExchange then
                    if LimitExchange.endTime - GetTimeStamp() > 0 then
                        UIManager.OpenPanel(UIName.ExpertPanel,data[1])
                    else
                        PopupTipPanel.ShowTipByLanguageId(11503)
                    end
                else
                    PopupTipPanel.ShowTipByLanguageId(11503)
                end
            else
                UIManager.OpenPanel(UIName.ExpertPanel,data[1])
            end
        end
    end,
    [JumpType.LimitCollection] = function()
        UIManager.OpenPanel(UIName.ExpertPanel, ExperType.GiftBuy)
    end,
    -------------------END-------------------
    -- [JumpType.Privilege] = function(data)
    --     local openPanle = UIManager.OpenPanel(UIName.VipPanelV2)
    --     if  openPanle and data and data[1] < 0 then
    --         --引导光圈 -1  下边条目领取按钮
    --         openPanle.ShowGuideGo()
    --     end
    -- end,
    [JumpType.HeroUpLv] = function(data)
        if data and data[1] > 0 then
            local heroData = HeroManager.GetHeroDataByHeroSIdAndMinSortId(data[1])
            if heroData and heroData.id then
                local openPanle = UIManager.OpenPanel(UIName.RoleInfoPanel, heroData, HeroManager.GetAllHeroDatas(),true)
                if openPanle then
                    openPanle.ShowGuideGo(1)
                end
            end
        else
            local formationList = FormationManager.GetFormationByID(1)
            if formationList.teamHeroInfos[1] then
                local heroData = HeroManager.GetSingleHeroData(formationList.teamHeroInfos[1].heroId)
                local openPanle = UIManager.OpenPanel(UIName.RoleInfoPanel, heroData, HeroManager.GetAllHeroDatas(),true)
                if openPanle then
                    openPanle.ShowGuideGo(1)
                end
            end
        end
    end,
    [JumpType.HeroUpStar] = function(data)
        local heroData = HeroManager.GetHeroDataByHeroSIdAndMinSortId(data[1])
        if heroData and heroData.id then
            local openPanle = UIManager.OpenPanel(UIName.RoleInfoPanel, heroData, HeroManager.GetAllHeroDatas(),true)
            if openPanle then
                openPanle.JumpOnClickBtnUpStar()
                openPanle.ShowGuideGo(2)
            end
        end
    end,
    [JumpType.GiveMePower] = function()
        UIManager.OpenPanel(UIName.GiveMePowerPanel)
    end,
    -- [JumpType.EndlessFight] = function()
    --     UIManager.OpenPanel(UIName.EndLessCarbonPanel)
    -- end,
    -- [JumpType.SoulPrintAstrology] = function()
    --     UIManager.OpenPanel(UIName.SoulPrintAstrologyPanel)
    -- end,
    -- [JumpType.Alien] = function()
    --     UIManager.OpenPanel(UIName.AlienMainPanel)
    -- end,
    -- [JumpType.FiveStarActivity] = function()
    --     UIManager.OpenPanel(UIName.GrowGiftPopup)
    -- end,
    [JumpType.Setting] = function(data)
        UIManager.OpenPanelWithSound(UIName.SettingPanel, data[1])
    end,
    [JumpType.LuckyTurn] = function(data)
        UIManager.OpenPanelWithSound(UIName.LuckyTurnTablePanel, data[1])
    end,
    -- [JumpType.FindFairy] = function(data)
    --     UIManager.OpenPanel(UIName.FindFairyPanel,data[1])
    -- end,
    [JumpType.FindTreasure] = function()
        UIManager.OpenPanelWithSound(UIName.FindTreasureMainPanel)
    end,
    [JumpType.Achievement] = function()
        if ActTimeCtrlManager.SingleFuncState(JumpType.Achievement) then
            UIManager.OpenPanelWithSound(UIName.MissionDailyPanel,2)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.Achiecement))
        end
    end,
    -- [JumpType.Expedition] = function(data)
    --     if ActTimeCtrlManager.SingleFuncState(JumpType.Expedition) then
    --         UIManager.OpenPanel(UIName.ExpeditionMainPanel,true)
    --     else
    --         PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.EXPEDITION))
    --     end
    -- end,

    -- [JumpType.GuildAid] = function(data)
    --     if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
    --         if PlayerManager.familyId == 0 then
    --             UIManager.OpenPanel(UIName.GuildFindPopup)
    --         else
    --             if UIManager.IsOpen(UIName.GuildMainCityPanel) then
    --                 UIManager.OpenPanel(UIName.GuildAidMainPopup,data[1])
    --             else
    --                 MyGuildManager.InitAllData(function()
    --                     UIManager.OpenPanel(UIName.GuildMainCityPanel)
    --                     UIManager.OpenPanel(UIName.GuildAidMainPopup,data[1])
    --                 end)
    --             end
    --         end
    --     else
    --         PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GUILD))
    --     end
    -- end,
    [JumpType.GuildSkill] = function(data)
        if not MyGuildManager.CheckGuildExitCdTime(true) then return end

        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
            if PlayerManager.familyId == 0 then
                UIManager.OpenPanel(UIName.GuildFindPopup)
            else
                if UIManager.IsOpen(UIName.GuildMainCityPanel) then
                    local index = 1
                    if data then index = data[1] end
                    UIManager.OpenPanel(UIName.GuildSkillUpLvPopup,index)
                else
                    MyGuildManager.InitAllData(function()
                        UIManager.OpenPanel(UIName.GuildMainCityPanel)
                        local index = 1
                        if data then index = data[1] end
                        UIManager.OpenPanel(UIName.GuildSkillUpLvPopup,index)
                    end)
                end
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GUILD))
        end
    end,
    [JumpType.GuildFete] = function()
        if not MyGuildManager.CheckGuildExitCdTime(true) then return end

        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
            if PlayerManager.familyId == 0 then
                UIManager.OpenPanel(UIName.GuildFindPopup)
            else
                if UIManager.IsOpen(UIName.GuildMainCityPanel) then
                    UIManager.OpenPanel(UIName.GuildFetePopup)
                else
                    MyGuildManager.InitAllData(function()
                        UIManager.OpenPanel(UIName.GuildMainCityPanel)
                        UIManager.OpenPanel(UIName.GuildFetePopup)
                    end)
                end
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GUILD))
        end
    end,
    [JumpType.GuildTranscript] = function(data)
        if not MyGuildManager.CheckGuildExitCdTime(true) then return end
        -- 1主界面 2布阵
        if data and data[1] == 2 then
            if PlayerManager.familyId == 0 then
                UIManager.OpenPanel(UIName.GuildFindPopup)
            else
                if UIManager.IsOpen(UIName.GuildMainCityPanel) then
                    UIManager.OpenPanel(UIName.GuildTranscriptMainPopup)
                    this.ShowGuildTransriptFormation()
                else
                    -- 进入公会界面之前初始化一遍数据
                    MyGuildManager.InitAllData(function()
                        UIManager.OpenPanel(UIName.GuildMainCityPanel)
                        UIManager.OpenPanel(UIName.GuildTranscriptMainPopup)
                        this.ShowGuildTransriptFormation()
                    end)
                end
            end
        else
            if PlayerManager.familyId == 0 then
                UIManager.OpenPanel(UIName.GuildFindPopup)
            else
                if UIManager.IsOpen(UIName.GuildMainCityPanel) then
                    UIManager.OpenPanel(UIName.GuildTranscriptMainPopup)
                else
                    -- 进入公会界面之前初始化一遍数据
                    MyGuildManager.InitAllData(function()
                        UIManager.OpenPanel(UIName.GuildMainCityPanel)
                        UIManager.OpenPanel(UIName.GuildTranscriptMainPopup)
                    end)
                end
            end
        end
    end,
    [JumpType.GuildRedPackage] = function()
        if not MyGuildManager.CheckGuildExitCdTime(true) then return end

        if PlayerManager.familyId == 0 then
            UIManager.OpenPanel(UIName.GuildFindPopup)
        else
            if UIManager.IsOpen(UIName.GuildMainCityPanel) then
                UIManager.OpenPanel(UIName.RedPacketPanel)
            else
                -- 进入公会界面之前初始化一遍数据
                MyGuildManager.InitAllData(function()
                    UIManager.OpenPanel(UIName.GuildMainCityPanel)
                    UIManager.OpenPanel(UIName.RedPacketPanel)
                end)
            end
        end
    end,
    [JumpType.RingRefine] = function(data)
        UIManager.OpenPanel(UIName.CompoundPanel,2,true)
    end,
    [JumpType.Compound] = function(data)
        local index = 1
        if data then index = data[2] end
        UIManager.OpenPanel(UIName.CompoundPanel,index)
    end,
    [JumpType.MultipleChallenge] = function(data)
        CarbonManager.difficulty = data[1]
        UIManager.OpenPanel(UIName.DailyCarbonPanel, data[1])
     end,
    [JumpType.DailyCarbon_Gold] = function(data)
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.DAILYCHALLENGE_COIN) then
            local index = 1
            if data then index = data[2] end
            UIManager.OpenPanel(UIName.DailyCarbonPanel,index)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.DAILYCHALLENGE_COIN))
        end
    end,
    [JumpType.DailyCarbon_Exp] = function(data)
        local index = 1
        if data then index = data[2] end
        UIManager.OpenPanel(UIName.DailyCarbonPanel,index)
    end,
    [JumpType.DailyCarbon_Hero] = function(data)
        local index = 1
        if data then index = data[2] end
        UIManager.OpenPanel(UIName.DailyCarbonPanel,index)
    end,
    [JumpType.DailyCarbon_Transure] = function(data)
        local index = 1
        if data then index = data[2] end
        UIManager.OpenPanel(UIName.DailyCarbonPanel,index)
    end,
    [JumpType.DailyCarbon_SoulPrint] = function(data)
        local index = 1
        if data then index = data[2] end
        UIManager.OpenPanel(UIName.DailyCarbonPanel,index)
    end,
    [JumpType.MinskBattle] = function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MINSKBATTLE) then
            NetManager.CarChallengeProgressIndication(function()
                UIManager.OpenPanel(UIName.BattleOfMinskMainPanel)
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.MINSKBATTLE))
        end
    end,

    [JumpType.Hegemony] = function()
        UIManager.OpenPanel(UIName.HegemonyPanel)
    end,
    [JumpType.Support] = function()
        NetManager.GetSupportInfos(function()
            UIManager.OpenPanel(UIName.SupportPanel)
        end)
    end,
    [JumpType.Adjutant] = function()
        NetManager.GetAllAdjutantInfo(function()
            AdjutantManager.CheckUnlockAdjutant(function()
                UIManager.OpenPanel(UIName.AdjutantPanel)
            end)
        end)
    end,
    [JumpType.AircraftCarrier] = function()
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER) then
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER))
            return
        end
        AircraftCarrierManager.GetLeadData(function()
            AircraftCarrierManager.GetAllPlaneReq(function()
                UIManager.OpenPanel(UIName.LeadPanel)
            end)
        end)
    end,
    [JumpType.InvestigateCenter] = function()
        if FormationCenterManager.GetInvestigateLevel() > 0 then
            UIManager.OpenPanel(UIName.FormationCenterPanel)
        else
            UIManager.OpenPanel(UIName.FormationCenterActivePanel)
        end
    end,
    [JumpType.firstRecharge] = function(data)
        UIManager.OpenPanel(UIName.FirstRechargePanel)
    end,
    [JumpType.ZhiZunJiangShi] = function(data)
        UIManager.OpenPanel(UIName.SupremeHeroPopup)
    end,
    [JumpType.SurpriseBox] = function(data)
        local activityId = ActivityGiftManager.IsActivityTypeOpen(data[1])
        if activityId and activityId > 0 and ActivityGiftManager.IsQualifiled(data[1]) then
            UIManager.OpenPanel(UIName.SurpriseBoxPanel)
        else
            PopupTipPanel.ShowTipByLanguageId(10780)
            this.isOpen = false
        end
    end,
    [JumpType.AdjutantActivity] = function (data)
        UIManager.OpenPanel(UIName.AdjutantActivityPanel,data[1])
    end,
    [JumpType.CustomizeShop] = function()
        UIManager.OpenPanel(UIName.CustomSuppliesShopPanel, 12,SHOP_TYPE.CHOAS_SHOP)
    end,
    [JumpType.GrowthManual] = function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUNLONG) then
            UIManager.OpenPanel(UIName.GrowthManualPanel,2,1)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.SUNLONG))
        end
    end,
    [JumpType.AdvancedClimbTower] = function()
        local isVisible, isOpen = ClimbTowerManager.CheckEliteModeIsOpen()
        if isOpen then
            NetManager.VirtualElitBattleGetInfo(function()
                ClimbTowerManager.GetRankData(function()
                    UIManager.OpenPanel(UIName.ClimbTowerElitePanel)
                end, ClimbTowerManager.ClimbTowerType.Advance)
            end)
        else
            PopupTipPanel.ShowTip("模拟战400层之后开启")
        end
    end,
    [JumpType.BattlePassPanel] = function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.BattlePass) then
            UIManager.OpenPanel(UIName.BattlePassPanel)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.BattlePass))
        end
    end,
    [JumpType.HeroExchange] = function(data)
        local isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.HeroExchange)
        if isOpen then
            UIManager.OpenPanel(UIName.HeroExchangePanel,data[2])
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.HeroExchange))
        end
    end,
    [JumpType.laddersChallenge] = function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.laddersChallenge) == false then --如果未解锁
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.laddersChallenge))
            return
        end
        UIManager.OpenPanel(UIName.LaddersTypePanel)
    end,
    [JumpType.ArdenBattle] = function()
        if ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.PEOPLE_MIRROR) then
            CarbonManager.difficulty = 1
            UIManager.OpenPanel(UIName.XuanYuanMirrorPanel)
        else
            local config = ConfigManager.GetConfigData(ConfigName.GlobalSystemConfig,FUNCTION_OPEN_TYPE.PEOPLE_MIRROR)
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10340),config.OpenRules[2]))
        end
    end,
    [JumpType.AlameinBattle] = function()
        if ActTimeCtrlManager.SingleFuncState(JumpType.AlameinBattle) then
            AlameinWarManager.RequestMainData(function()
                UIManager.OpenPanel(UIName.AlameinWarPanel)
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(JumpType.AlameinBattle))
        end
    end,
    -- [JumpType.EndlessFight] = function()
    --     if ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.ENDLESS) then
    --         if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ENDLESS) then
    --             NetManager.MapInfoListRequest(function (msg)
    --                 local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.ENDLESS)
    --                 PlayerPrefs.SetInt("WuJin1"..PlayerManager.uid,serData.endTime)
    --                 CheckRedPointStatus(RedPointType.EndlessPanel)
    --                 MapManager.curCarbonType = CarBonTypeId.ENDLESS
    --                 MapManager.SetViewSize(3)--设置视野范围（明雷形式）
    --                 MapManager.isTimeOut = false 
    --                 UIManager.OpenPanel(UIName.EndLessCarbonPanel,msg.info)
    --             end)
    --         else
    --             PopupTipPanel.ShowTip(GetLanguageStrById(10281))
    --         end
    --     else
    --         PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ENDLESS))
    --     end
    -- end,
    -- [JumpType.xiaoyaoJump] = function(data,activityId)--活动学院
    --     for index, value in ipairs(activityId) do
    --         if ActivityGiftManager.GetActivityIdByZq(value) ~= nil then
    --             XiaoYaoManager.OpenXiaoYaoMap(6001)
    --             return
    --         end
    --     end
    --     PopupTipPanel.ShowTip(GetLanguageStrById(11503))
    -- end,
    [JumpType.Contract] = function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GENERAL) then
            UIManager.OpenPanel(UIName.GeneralInfoPanel)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GENERAL))
        end
    end,
    [JumpType.Laboratory] = function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ASSEMBLE) then
            UIManager.OpenPanel(UIName.AssemblePanel)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ASSEMBLE))
        end
    end,
    -------------------编队-------------------
    [JumpType.Team] = function()
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.MAIN)
    end,
    [JumpType.AllForMation] = function(data)
        if ActTimeCtrlManager.SingleFuncState(54) then
            -- UIManager.OpenPanel(UIName.FormationSetPanel)
            if data[1] == 1 then
                UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.SAVE_FORMATION)
            elseif data[1] == 101 then
                UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_DEFEND)
            else
                UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_ATTACK)
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(54))
        end
    end,
    [JumpType.TopMatch] = function(data)
        if data and data[1] == 2 then
            UIManager.OpenPanel(UIName.ArenaTopMatchPanel)
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_TOP_MATCH, function()
            end)
        else
            ArenaTopMatchManager.RequestTopMatchBaseInfo(function()
               UIManager.OpenPanel(UIName.ArenaTopMatchPanel)
            end )
        end
    end,
    [JumpType.ClimbTower] = function(data)
        -- 1主界面 2布阵
        if data and data[1] == 2 then
            NetManager.VirtualBattleGetInfo(function()
                ClimbTowerManager.GetRankData(function()
                    UIManager.OpenPanel(UIName.ClimbTowerPanel)
                    if ClimbTowerManager.GetCount(ClimbTowerManager.ClimbTowerType.Normal) > 0 then
                        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CLIMB_TOWER, ClimbTowerManager.fightId)
                        self:ClosePanel()
                    else        
                        PopupTipPanel.ShowTipByLanguageId(11048)
                    end
                end)
            end)
        else
            NetManager.VirtualBattleGetInfo(function()
                ClimbTowerManager.GetRankData(function()
                    UIManager.OpenPanel(UIName.ClimbTowerPanel)
                  
                end)
            end)
        end
    end,
    [JumpType.BlitzStrike] = function(data)
        -- 1主界面 2布阵
        if data and data[1] == 2 then
            NetManager.BlitzInfo(function(msg)
                CheckRedPointStatus(RedPointType.ForgottenCity)
                if BlitzStrikeManager.difficultyLevel == 0 then -- 未选择难度
                    UIManager.OpenPanel(UIName.BlitzStrikePanel)
                else
                    NetManager.BlitzTypeInfo(function()
                        UIManager.OpenPanel(UIName.BlitzStrikePanel)
                        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.BLITZ_STRIKE,BlitzStrikeManager.curFightId)
                    end)
                end
            end)
        else
            NetManager.BlitzInfo(function(msg)
                CheckRedPointStatus(RedPointType.ForgottenCity)
                if BlitzStrikeManager.difficultyLevel == 0 then -- 未选择难度
                    UIManager.OpenPanel(UIName.BlitzStrikePanel)
                else
                    NetManager.BlitzTypeInfo(function()
                        UIManager.OpenPanel(UIName.BlitzStrikePanel)
                    end)
                end
            end)
        end
    end,
    [JumpType.DefTraining] = function(data)
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MONSTER_COMING) then
            -- 1主界面 2布阵
            if data and data[1] == 2 then
                NetManager.DefTrainingGetInfo(function(msg)
                    NetManager.GetTankListFromFriendByModuleId(1, function(msg)--拉好友坦克数据
                        DefenseTrainingManager.SetFriendSupportHeroDatas(msg)
                        NetManager.GetTankInfoOfTeam(FormationTypeDef.DEFENSE_TRAINING, function()--拉剩余血量数据
                            UIManager.OpenPanel(UIName.DefenseTrainingPopup)
                            if DefenseTrainingManager.teamLock == 1 and DefenseTrainingManager.CheckIsAllDead() then
                                PopupTipPanel.ShowTipByLanguageId(12554)
                            else
                                UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.DefenseTraining, DefenseTrainingManager.curFightId)
                            end
                            SoundManager.PlaySound(SoundConfig.Sound_Ui_XiTongKaiQi)
                        end)
                    end)
                end)
            else
                NetManager.DefTrainingGetInfo(function(msg)
                    NetManager.GetTankListFromFriendByModuleId(1, function(msg) --拉好友坦克数据
                        DefenseTrainingManager.SetFriendSupportHeroDatas(msg)
                        NetManager.GetTankInfoOfTeam(FormationTypeDef.DEFENSE_TRAINING, function()--拉剩余血量数据
                            UIManager.OpenPanel(UIName.DefenseTrainingPopup)
                            SoundManager.PlaySound(SoundConfig.Sound_Ui_XiTongKaiQi)
                        end)
                    end)
                end)
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.MONSTER_COMING))
        end
    end,
    -------------------END-------------------
    -----------------------------------活动跳转-----------------------------------
    [JumpType.TimeLimiteCall] = function (data)
        this.JumpActivity(JumpType.ZhuTiHuoDong,data[1])
    end,
    [JumpType.QianKunBox] = function (data)
        this.JumpActivity(JumpType.ZhuTiHuoDong,data[1])
    end,
    [JumpType.Celebration] = function (data)
        this.JumpActivity(JumpType.ZhuTiHuoDong,data[1])
    end,
    [JumpType.YiJingBaoKu] = function (data)
        this.JumpActivity(JumpType.ZhuTiHuoDong,data[1])
    end,
    -- [JumpType.LingShouBaoGe] = function (data)
    --     this.JumpActivity(JumpType.ZhuTiHuoDong,data[1])
    -- end,
    -- [JumpType.XiangYaoDuoBao] = function (data)
    --     this.JumpActivity(JumpType.ZhuTiHuoDong,data[1])
    -- end,
    [JumpType.XianShiDuiHuan] = function (data)
        this.JumpActivity(JumpType.ZhuTiHuoDong,data[1])
    end,

    [JumpType.chaozhijijin] = function(data)
        this.JumpActivity(JumpType.chaozhijijin % 10000,data[1])
    end,
    [JumpType.ZhuTiHuoDong] = function (data)
        if #data > 1 then
            if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LimitUpHero) then
                this.JumpActivity(JumpType.ZhuTiHuoDong,data[1])
            elseif ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy) then
                this.JumpActivity(JumpType.ZhuTiHuoDong,data[2])
            else
                PopupTipPanel.ShowTipByLanguageId(10780)
                this.isOpen = false
            end
        else
            this.JumpActivity(JumpType.ZhuTiHuoDong,data[1])
        end
    end,
    [JumpType.QianKunShangDian] = function (data)
        this.JumpActivity(JumpType.QianKunShangDian,data[1])
    end,
    [JumpType.SheJiDaDianShangDian] = function (data)
        this.JumpActivity(JumpType.SheJiDaDianShangDian,data[1])
    end,
    -- [JumpType.XinJiangLaiXiShangDian] = function (data)
    --     this.JumpActivity(JumpType.XinJiangLaiXiShangDian,data[1])
    -- end,
    -- [JumpType.XingChenShangDian] = function (data)
    --     this.JumpActivity(JumpType.XingChenShangDian,data[1])
    -- end,
    [JumpType.ChaoFanRuSheng] = function(data)
        this.JumpActivity(ActivityTypeDef.ChaoFanRuSheng,data[1])
    end,
    [JumpType.zhenqibaoge] = function(data)
        this.JumpActivity(JumpType.zhenqibaoge,data[1])
    end,
    [JumpType.xianshishangshi] = function(data)
        this.JumpActivity(JumpType.xianshishangshi,data[1])
    end,
    [JumpType.ForgottenCity] = function ()
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.BLITZ_STRIKE)
    end,
}

function this.JumpActivity(data,skipfactor)
    local isOpen = DynamicActivityManager.IsActivityOpenByJumpIndex(data, skipfactor)
    if not isOpen then
        PopupTipPanel.ShowTipByLanguageId(10780)
        this.isOpen = false
        return
    end
    if isOpen == 1 then
        PopupTipPanel.ShowTipByLanguageId(10404)
        this.isOpen = false
        return
    end
    if DynamicActivityManager.curActivityType == data then
        DynamicActivityManager.RemoveUIList()
    end
    if UIManager.IsOpen(UIName.ActivityMainPanel) then
        UIManager.ClosePanel(UIName.ActivityMainPanel)
    end
    DynamicActivityManager.AddUIList(this.jumpId)
    UIManager.OpenPanel(UIName.ActivityMainPanel,data,skipfactor)
end

function this.CheckJump(_jumpId)
    local jumpSData = JumpConfig[_jumpId]
    if jumpSData.Type < 10000 then
        local b = jumpSData and  ActTimeCtrlManager.SingleFuncState(jumpSData.Type)
        if not b then
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(jumpSData.Type))
        end
        return b
    else
        return true
    end
end

function this.GoJumpWithoutTip(_jumpId)
    local jumpSData = JumpConfig[_jumpId]
    if jumpSData then
        jumpDic[jumpSData.Type](jumpSData.Skipfactor)
    end
end

function this.GoJump(_jumpId)
    -- LogError(_jumpId)
    local jumpSData = JumpConfig[_jumpId]
    -- LogError(jumpSData.Type)
    if jumpSData then
        if jumpSData.Type < 10000 then
            local serData = ActTimeCtrlManager.GetSerDataByTypeId(jumpSData.Type)
            if serData then
                if ActTimeCtrlManager.SingleFuncState(jumpSData.Type) then
                    jumpDic[jumpSData.Type](jumpSData.Skipfactor,jumpSData.ActiveID)
                else
                    PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(jumpSData.Type))
                end
            else
                jumpDic[jumpSData.Type](jumpSData.Skipfactor)
            end
        else
            jumpDic[jumpSData.Type](jumpSData.Skipfactor)
        end
    end
end

-- 跳转到指定
function this.GoJumpAppoint(type, data)
    jumpDic[type](data)
end

function this.ShowGuide(panelId, targetGO)
    local go = poolManager:LoadAsset("GuideEffect", PoolManager.AssetType.GameObject)
    go.transform:SetParent(targetGO.transform)
    go.transform.localPosition = Vector3.zero
    go.transform.localScale = Vector3.one
    go.transform:SetAsLastSibling()

    local layer = tonumber(go.name) or 0
    Util.AddParticleSortLayer(go,  UIManager.GetOpenPanel(panelId).sortingOrder - layer)
    go.name = tostring(UIManager.GetOpenPanel(panelId).sortingOrder)
    Util.GetGameObject(go, "GameObject"):SetActive(true)

    local update
    update = function()
        if Input.GetMouseButtonDown(0) then
            poolManager:UnLoadAsset("GuideEffect", go, PoolManager.AssetType.GameObject)
            UpdateBeat:Remove(update, this)
        end
    end
    UpdateBeat:Add(update, this)
end

function this.ShowGuildTransriptFormation()
    local guildCheckpointConfig = ConfigManager.GetConfig(ConfigName.GuildCheckpointConfig)
    local monsterData = guildCheckpointConfig[GuildTranscriptManager.GetCurBoss()].MonsterId
    if GuildTranscriptManager.GetCanBattleCount() <= 0 then --今日已无剩余次数！
        if GuildTranscriptManager.GetCanBuyBattleCount() <= 0 then
            PopupTipPanel.ShowTipByLanguageId(10342)
        else--是否花费XX钻石购买1次挑战次数并发起挑战？
            local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, GuildTranscriptManager.shopGoodId, 1)
            local itemName = ConfigManager.GetConfigData(ConfigName.ItemConfig,costId).Name
                if finalNum > BagManager.GetItemCountById(costId) then
                    PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11652),itemName) ) 
                    return
                end
            MsgPanel.ShowTwo(string.format( GetLanguageStrById(12721),finalNum,GetLanguageStrById(itemName)), nil, function()
                --买东西
                ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,GuildTranscriptManager.shopGoodId,1,function()
                    PopupTipPanel.ShowTipByLanguageId(12328) 
                    UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_TRANSCRIPT,monsterData)
                    PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM, 1)--更新特权
                    this.ShowEndNumInfo()
                end)
            end)
        end
    else
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_TRANSCRIPT,monsterData)
    end
end
return this