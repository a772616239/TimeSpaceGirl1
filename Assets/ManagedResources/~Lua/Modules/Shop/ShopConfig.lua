---
--- 商店界面相关配置
---     参数配置说明：
---     title:   商店标题资源文件名
---
---     liveName:   商店立绘/静态图资源文件名（默认为nil，不显示）
---     liveType:   资源类型   1 立绘   2 静态图  （默认为1）
---     livePos:    资源位置（默认为0，0）
---     liveScale:  资源缩放值（默认为1）
---
---     content:    商店提示文字内容（默认为nil，不显示）
---     contentPos: 商店提示文字位置（默认为0，0）
---
---     UpViewType  商店界面UpView显示类型
---     BgType      商店主界面背景类型（只作用于商店主界面）
---
---     IsHelp:     显隐帮助按钮 1 显示   2 隐藏
---     HelpType:   帮助类型

local ShopConfig = {
    [SHOP_TYPE.SOUL_CONTRACT_SHOP] = {
        scrollBg = "s_qihun_kuang",
        title = "r_shangdian_xianchen", titleBg = "s_shop_biaoti",
        liveName = "live2d_ui_h_52_xx_pf1", livePos = { 123, 214 }, liveScale = 0.25,
        UpViewType = PanelType.SoulContractShop,
        BgType = 1,
        IsHelp = 1,
        HelpType=HELP_TYPE.SoulContractShop,
    },
    [SHOP_TYPE.GENERAL_SHOP] = {
        scrollBg = "s_qihun_kuang",
        title = "s_qihun_biaoti_zahuo", titleBg = "s_shop_biaoti",
        --liveName = "live2d_npc_shop03", livePos = { -100, 214 }, liveScale = 0.8,
        liveName = "live2d_ui_h_52_xx_pf1", livePos = { 123, 214 }, liveScale = 0.25,
        UpViewType = PanelType.GeneralShop,
        BgType = 1,
        IsHelp = 1,
        HelpType=HELP_TYPE.GeneralShop,
    },
    [SHOP_TYPE.ROAM_SHOP] = {
        scrollBg = "s_qihun_kuang",
        title = "r_yunyou_yunyoushangdianzi", titleBg = "s_shop_biaoti",
        liveName = "live2d_npc_yunyou", liveType = 1, livePos = { -157, 338 }, liveScale = Vector3(-0.42, 0.42, 0.42),
        --content = "你的运气是真的不错呢！~我可不是天天都会出现的噢。", contentPos = { -200, 390 }
        UpViewType = PanelType.RoamShop,
        BgType = 2,
        IsHelp = 0,
    },
    [SHOP_TYPE.ARENA_SHOP] = {      -- 竞技场商店
        scrollBg = "s_qihun_kuang",
        title = "r_shangdian_zhusheng", titleBg = "s_shop_biaoti",
        --liveName = "live2d_c_mrzq_0010", livePos = { 86, 193 }, liveScale = 1,
        liveName = "live2d_ui_h_52_xx_pf1", livePos = { 123, 214 }, liveScale = 0.25,
        --content = "在竞技场中获得优胜的玩家，可以在这里购买丰厚的奖励嗷。", contentPos = { -230, 330 }
        UpViewType = PanelType.ArenaShop,
        BgType = 1,
        IsHelp = 1,
        HelpType=HELP_TYPE.ArenaShop,
    },
    [SHOP_TYPE.SOUL_STONE_SHOP] = {
        scrollBg = "s_qihun_kuang",
        title = "s_shop_hunjing", titleBg = "s_shop_biaoti",
        -- liveName = "live2d_c_tx_0011", livePos = { -50, 136 }, liveScale = 1,
        liveName = "live2d_ui_h_52_xx_pf1", livePos = { 123, 214 }, liveScale = 0.25,
        UpViewType = PanelType.SoulCrystal,
        BgType = 1,
        IsHelp = 0,
    },
    [SHOP_TYPE.SECRET_BOX_SHOP] = {
        scrollBg = "s_qihun_kuang",
        title = "s_shop_mibao", titleBg = "s_shop_biaoti",
        liveName = "live2d_mihe", liveType = 1, livePos = { 0, 196 }, liveScale = Vector3.one,
        UpViewType = PanelType.SecretBoxShop,
        BgType = 3,
        IsHelp = 1,
        HelpType = HELP_TYPE.SecretBoxShop,
    },
    [SHOP_TYPE.TRIAL_SHOP] = {
        scrollBg = "s_qihun_kuang",
        title = "s_shop_shilian", titleBg = "s_shop_biaoti",
        liveName = "live2d_npc_yunyou", liveType = 1, livePos = { -157, 338 }, liveScale = Vector3(-0.42, 0.42, 0.42),
        UpViewType = PanelType.TrialShop,
    },
    [SHOP_TYPE.ACTIVITY_SHOP] = {
        scrollBg = "s_qihun_kuang",
        title = "s_shop_duihuan", titleBg = "s_shop_biaoti",
        liveName = "live2d_npc_yunyou", liveType = 1, livePos = { -157, 338 }, liveScale = Vector3(-0.42, 0.42, 0.42),
        UpViewType = PanelType.ActivityShop,
        BgType = 2,
        IsHelp = 0,
    },
    [SHOP_TYPE.GUILD_SHOP] = {      --公会商店
        scrollBg = "s_qihun_kuang",
        title = "s_shop_gonghui", titleBg = "s_shop_biaoti",
        liveName = "live2d_npc_yunyou", liveType = 1, livePos = { -157, 338 }, liveScale = Vector3(-0.42, 0.42, 0.42),
        UpViewType = PanelType.GuildShop,
        BgType = 2,
        IsHelp = 1,
        HelpType = HELP_TYPE.GuildShop,
    },
    [SHOP_TYPE.ENDLESS_SHOP] = {
        scrollBg = "s_qihun_kuang",
        title = "s_shop_wujin", titleBg = "s_shop_biaoti",
        liveName = "live2d_npc_yunyou", liveType = 1, livePos = { -157, 338 }, liveScale = Vector3(-0.42, 0.42, 0.42),
        UpViewType = PanelType.EndLessShop,
        BgType = 2,
    },
    --[[
    [SHOP_TYPE.SOUL_PRINT_SHOP] = {    -- 魂印商店
        scrollBg = "s_qihun_kuang",
        title = "s_shop_hunyin", titleBg = "s_shop_biaoti",
        liveName = "live2d_npc_yunyou", liveType = 1, livePos = { -157, 338 }, liveScale = Vector3(-0.42, 0.42, 0.42),
        UpViewType = PanelType.SoulPrintShop,
        BgType = 2,
        IsHelp = 1,
        HelpType = HELP_TYPE.SoulPrintShop,
    },
    ]]
    [SHOP_TYPE.FRIEND_SHOP] = {    -- 友情商店
        scrollBg = "s_qihun_kuang",
        title = "r_shangdian_youqing", titleBg = "s_shop_biaoti",
        liveName = "live2d_ui_h_52_xx_pf1", livePos = { 123, 214 }, liveScale = 0.25,
        UpViewType = PanelType.FriendShop,
        BgType = 1,
        IsHelp = 1,
        HelpType = HELP_TYPE.FriendShop,
    },
    [SHOP_TYPE.CHOAS_SHOP] = {    -- 混沌商店
        scrollBg = "s_qihun_kuang",
        title = "r_shangdian_yuanshen", titleBg = "s_shop_biaoti",
        liveName = "live2d_ui_h_52_xx_pf1", livePos = { 123, 214 }, liveScale = 0.25,
        UpViewType = PanelType.ChoasShop,
        BgType = 1,
        IsHelp = 1,
        HelpType = HELP_TYPE.ChoasShop,
    },
    [SHOP_TYPE.TOP_MATCH_SHOP] = {    -- 巅峰赛商店商店
        scrollBg = "s_qihun_kuang",
        title = "s_shop_dainfeng", titleBg = "s_shop_biaoti",
        liveName = "live2d_ui_h_52_xx_pf1", livePos = { 123, 214 }, liveScale = 0.25,
        UpViewType = PanelType.TopMatchShop,
        BgType = 1,
        IsHelp = 1,
        HelpType = HELP_TYPE.TopMatchShop,
    },
}

return ShopConfig