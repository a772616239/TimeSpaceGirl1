--[[
 * @ClassName DataCenterManager
 * @Description 数据中心管理
 * @Date 2019/7/3 10:48
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
DataCenterManager = {}
local this = DataCenterManager
local json = require 'cjson'

local GameCenterUrl = "https://gskuld.receiver.extranet.kt007.com:8081/skuld/game/common/"
local MD5Key = "0A008C48E74E8A399F1F80DBED71161C"
local GID = "lj_jl_8qdcs" --"lj_jl_7qdsc" --"jl_test"

--初始化
function this.Initialize()

end

function this.SubMitToServer(context)
    
    -- networkMgr:SendHttpPost_Raw_Lua(GameCenterUrl, context, this.BackRespond, nil)
end

--设备启动事件
function this.CommitBootStatus()
    if not AppConst.isSDK then
        return
    end
    local bootData = {}
    bootData.gid = GID
    bootData.time = math.floor(GetTimeStamp())
    bootData.sign = Util.MD5Encrypt(string.format("%s%s%s",MD5Key,
            bootData.gid, bootData.time))
    bootData.jsonStr = {}
    bootData.jsonStr.param_data = {
        app_id_s = GID,
        data_unix = math.floor(GetTimeStamp()),
        category_s = "event_app",
        channel_s = "1",
        platform_s = "ADR",
    }
    bootData.jsonStr.param_environment = {
        idfa_s = "",
        imei_s = AndroidDeviceInfo.Instance:GetIMEICode(),
        network_s = AndroidDeviceInfo.Instance:GetNetworkType(),
        dpi_s = AndroidDeviceInfo.Instance:GetScreenRatio(),
        os_version_s = AndroidDeviceInfo.Instance:GetSystemVersion(),
        operator_s = AndroidDeviceInfo.Instance:GetOperatorName(),
        brand_s = AndroidDeviceInfo.Instance:GetDeviceModel(),
        brand_type_s = AndroidDeviceInfo.Instance:GetDeviceBrand(),
        device_id_s = AndroidDeviceInfo.Instance:GetDeviceID()
    }
    bootData.jsonStr.param_event = {
        event_s = { "booting_0" }
    }
    local data = json.encode(bootData)
    this.SubMitToServer(data)
end

function this.CommitClickStatus(clickFirst, clickSecond)
    if not AppConst.isSDK then
        return
    end
    local bootData = {}
    bootData.gid = GID
    bootData.time = math.floor(GetTimeStamp())
    bootData.sign = Util.MD5Encrypt(string.format("%s%s%s", MD5Key,
            bootData.gid, bootData.time))
    bootData.jsonStr = {}
    bootData.jsonStr.param_data = {
        app_id_s = GID,
        data_unix = math.floor(GetTimeStamp()),
        category_s = "event_user",
        channel_s = "1",
        platform_s = "ADR",
    }
    bootData.jsonStr.param_environment = {
        network_s = AndroidDeviceInfo.Instance:GetNetworkType(),
        dpi_s = AndroidDeviceInfo.Instance:GetScreenRatio(),
        os_version_s = AndroidDeviceInfo.Instance:GetSystemVersion(),
        operator_s = AndroidDeviceInfo.Instance:GetOperatorName(),
        brand_s = AndroidDeviceInfo.Instance:GetDeviceModel(),
        brand_type_s = AndroidDeviceInfo.Instance:GetDeviceBrand(),
        device_id_s = AndroidDeviceInfo.Instance:GetDeviceID()
    }
    bootData.jsonStr.param_user = {
        user_id_s = AppConst.OpenId,
        account_id_s = PlayerManager.uid
    }
    bootData.jsonStr.param_event = {
        event_s = {
            "track_2",
            clickFirst,
            clickSecond
        }
    }
    local data = json.encode(bootData)
    this.SubMitToServer(data)
end

--角色充值事件
function this.CommitPayStatus(rechargeType,payOrderId,validState, price)
    if not AppConst.isSDK then
        return
    end
    local bootData = {}
    bootData.gid = GID
    bootData.time = math.floor(GetTimeStamp())
    bootData.sign = Util.MD5Encrypt(string.format("%s%s%s", MD5Key,
            bootData.gid, bootData.time))
    bootData.jsonStr = {}
    bootData.jsonStr.param_data = {
        app_id_s = GID,
        data_unix = math.floor(GetTimeStamp()),
        category_s = "event_role",
        channel_s = "1",
        platform_s = "ADR",
        region_s = PlayerManager.serverInfo.server_id,
        server_s = PlayerManager.serverInfo.server_id
    }
    bootData.jsonStr.param_environment = {
        ip_s = AndroidDeviceInfo.Instance:GetLocalIpAddress(),
        device_id_s = AndroidDeviceInfo.Instance:GetDeviceID()
    }
    bootData.jsonStr.param_user = {
        user_id_s = AppConst.OpenId,
        account_id_s = PlayerManager.uid
    }
    bootData.jsonStr.param_role = {
        role_id_s = PlayerManager.uid,
        role_name_s = PlayerManager.nickName,
        level_i = PlayerManager.level,
        vip_level_i = VipManager.GetVipLevel()
    }
    bootData.jsonStr.param_event = {
        event_s = {
            "sdkpay_3_d",
            rechargeType,
            payOrderId,
            validState,
            price
        }
    }
    local data = json.encode(bootData)
    this.SubMitToServer(data)
end

function this.BackRespond(str)
    str = json.decode(str)
    if str.ok then

    end
end

return this