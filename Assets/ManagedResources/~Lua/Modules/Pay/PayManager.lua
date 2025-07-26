--[[
 * @ClassName PayManager
 * @Description 支付管理系统
 * @Date 2019/6/25 20:14
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
PayManager = {}
local this = PayManager
local LoginRoot_PayUrl = VersionManager:GetVersionInfo("payUrl")
--初始化
function this.Initialize()
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.onSdkPayResult)
    this.isCanPay = true
end
this.EventTrigger = {}
function this.onSdkPayResult(id)
    LogRed("收到sdk支付成功回调，商品id = "..id)
    if this.EventTrigger[id] then
        this.EventTrigger[id](id)
        this.EventTrigger[id] = nil
    end
end
----- 请求支付
----- @param context
---- {
----   Id,     -- required, 商品ID
----   BuyNum, -- optional, 购买个数(默认1）
---- }
function this.Pay(context,func)
    if not GetChannerConfig().Recharge_SDK_open then
        PopupTipPanel.ShowTipByLanguageId(10414)
        return
    end
    if not this.isCanPay then
        PopupTipPanel.ShowTipByLanguageId(91001609)
        return
    else
        this.isCanPay = false
        if not this.payCDTimer then
            local cd = 1
            this.payCDTimer = Timer.New(function ()
                if cd <= 0 then
                    this.payCDTimer:Stop()
                    this.payCDTimer = nil
                    this.isCanPay = true
                end
                cd = cd - 1
            end, 0.5, -1, true)
            this.payCDTimer:Start()
        end
    end
    local payFunc = function ()
        if not func then
            func = function() end
        end
        this.EventTrigger[context.Id] = func

        local rechargeConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, context.Id)
        if rechargeConfig~=nil then
            Log("充值结果回调 ret1 = "..context.Id.."rechargeConfig.Price = "..rechargeConfig.Price)

            iapMgr:BuyItem1(context.Id,rechargeConfig.Price,function (ret1)

            if ret1.IsSucc then   
                NetManager.RequestBuyGiftGoods(context.Id,function()
                    
                end)
            end
        end)
        end

        local payData = table.clone(context)
        payData.Name = rechargeConfig.Name
        payData.Desc = rechargeConfig.Desc 
        local multiLanguage = ConfigManager.GetConfigData(ConfigName.MultiLanguage,GetCurLanguage())
        local exchangeRate = ConfigManager.GetConfigDataByKey(ConfigName.ExchangeRate, "Price_1", rechargeConfig.Price)
        payData.Price = exchangeRate[multiLanguage.Exchange]
        payData.CurrencyType = multiLanguage.CurrencyCode
        payData.Type = rechargeConfig.Type
        payData.ShowType = rechargeConfig.ShowType
        local channelRechargeIdConfig = ConfigManager.GetConfigData(ConfigName.ChannelRechargeIdConfig, context.Id)
        payData.RechargeId = channelRechargeIdConfig[AppConst.ChannelType]
        this.RequestPay(payData)
    end

    if GetChannerConfig().IsRefund_tips then
        if ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, context.Id).IsRefund == 1 then
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Currency, GetLanguageStrById(50250), function (msg)
                payFunc()
            end)
        else
            payFunc()
        end
    else
        payFunc()
    end
end

function this.RequestPay(context)
    SDKMgr.onPayCallback = function(payResp)
        NetManager.RequestVipLevelUp(function()end)
        local str = string.split(payResp, "#")
        local result = tonumber(str[1])
        local orderId = str[2]
        if result == SDK_RESULT.SUCCESS then
            DataCenterManager.CommitPayStatus(
                    "IN_GAME_"..context.Type,
                    SDKMgr:GetPayOrderID(),
                    "VALID",
                    tostring(context.Price)
            )
        elseif result == SDK_RESULT.FAILED then
            DataCenterManager.CommitPayStatus(
                    "IN_GAME_"..context.Type,
                    SDKMgr:GetPayOrderID(),
                    "INVALID",
                    tostring(context.Price)
            )
        else
        end
    end
    if context.Price == 0 then
        NetManager.RequestBuyZeroGiftGoods(context.Id)
        return
    end

    -- Log(LoginRoot_PayUrl.."/pay/CreatOrder?openid="..AppConst.OpenId.."&uid="..AppConst.UserId.."&region="..PlayerManager.serverInfo.server_id.."&channel="..AppConst.SdkChannel.."&pay_item="..context.Id.."&price="..(context.Price*100))

    -- networkMgr:SendGetHttp(LoginRoot_PayUrl.."/pay/CreatOrder?openid="..AppConst.OpenId.."&uid="..AppConst.UserId.."&region="..PlayerManager.serverInfo.server_id.."&channel="..AppConst.SdkChannel.."&pay_item="..context.Id.."&price="..(context.Price*100),

    -- Log(LoginRoot_PayUrl.."/pay/CreatOrder?openid=".."1111".."&uid="..AppConst.UserId.."&region="..PlayerManager.serverInfo.server_id.."&pay_item="..context.Id.."&price="..(context.Price*100))

    -- networkMgr:SendGetHttp(LoginRoot_PayUrl.."/pay/CreatOrder?openid=".."1111".."&uid="..AppConst.UserId.."&region="..PlayerManager.serverInfo.server_id.."&pay_item="..context.Id.."&price="..(context.Price*100),
        
    -- function(msg)

    --         local json = require 'cjson'
    --         local data = json.decode(msg)

    --         if data.errCode then
    --             local errorCfg = ConfigManager.TryGetConfigData(ConfigName.ErrorCodeHint, data.errCode)
    --             PopupTipPanel.ShowTip(GetLanguageStrById(errorCfg.Desc))
    --         else
    --             local params = SDK.SDKPayArgs.New()
    --             params.rechargeId = context.RechargeId
    --             params.showType = context.ShowType
    --             params.productId = context.Id
    --             params.productName = GetLanguageStrById(context.Name) or ""
    --             params.productDesc = GetLanguageStrById(context.Desc) or ""
    --             params.price = tostring(context.Price)
    --             params.currencyType = context.CurrencyType
    --             -- 以分为单位
    --             params.ratio = 1
    --             params.buyNum = context.BuyNum or 1
    --             params.coinNum = BagManager.GetItemCountById(16)
    --             -- 服务器相关
    --             params.zoneId = PlayerManager.serverInfo.server_id
    --             params.serverID = PlayerManager.serverInfo.server_id
    --             params.serverName = PlayerManager.serverInfo.name
    --             params.accounted = ""
    --             -- 角色相关
    --             params.roleID = tostring(PlayerManager.uid)
    --             params.roleName = PlayerManager.nickName
    --             params.roleLevel = PlayerManager.level
    --             params.vip = tostring(VipManager.GetVipLevel())
    --             params.guildID = PlayerManager.familyId
    --             -- 其他
    --             if UnityEngine.Application.platform == UnityEngine.RuntimePlatform.IPhonePlayer then
    --                 params.payNotifyUrl = LoginRoot_PayUrl.."/pay/quickIosNotify"
    --             else
    --                 params.payNotifyUrl = LoginRoot_PayUrl.."/pay/quickNotify"
    --             end
    
    --             params.orderID=data.orderId
    --             params.extension = string.format('{"extension":"%s"}',string.format("%s_%s_%s_%s", PlayerManager.uid, context.Id, VersionManager:GetVersionInfo("subChannel"),data.orderId))--tostring(context.Id)
    --             -- string.format("%s_%s_%s_%s_%s_%s",
    --             -- AppConst.OpenId,context.Id,context.Price,PlayerManager.uid,
    --             -- PlayerManager.serverInfo.server_id,PlayerManager.serverInfo.name)
    --             SDKMgr:Pay(params)
    --         end
    --     end,nil,nil,nil)
    
    -- 
    -- ThinkingAnalyticsManager.Track("create_order", {
    --     goods_id = context.Id,
    --     goods_name = context.Name,
    --     order_money_amount = context.Price,
    --     Bundle_id = AppConst.SdkPackageName,
    -- })
end

return this