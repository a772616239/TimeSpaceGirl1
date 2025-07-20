LoginManager = {};
local this = LoginManager
this.sign = "d13b3e8ef74bf72d8aafce3a1c8672a0"
this.openId = nil
this.token = nil
this.IsLogin = false
this.pt_pId = ""
this.pt_gId = ""

local LoginRoot_Url = VersionManager:GetVersionInfo("serverUrl")
-- local LoginRoot_PackageVersion = VersionManager:GetVersionInfo("sdkLodingUrl")
local Channel = VersionManager:GetVersionInfo("channel")
function this.Initialize()
    this.IsLogin = false
    this.GameName='DouDou'
    local defaultLoginWay=0
    if UnityEngine.Application.isMobilePlatform then
        defaultLoginWay=1
    else
        defaultLoginWay=0
    end
    this.CurLoginWay=PlayerPrefs.GetInt(this.GameName.."LoginWay",defaultLoginWay)
    this.CurAccount=PlayerPrefs.GetString(this.GameName.."Account",'')
    this.CurSession=PlayerPrefs.GetString(this.GameName.."Session",'')

    SDKMgr.onMessageCallback = function(msg)
        MsgPanel.ShowOne(msg)
    end

    this.isRegister = false

    SDKMgr.onRegisterCallback = function()
        this.isRegister = true
    end

    SDKMgr.onLoginCallback = function(loginResp)
        -- 获取登录信息
       
        local result = string.split(loginResp, "#")
        result[1] = tonumber(result[1]) 
        if result[1] == SDK_RESULT.SUCCESS then
            AppConst.SdkId = result[2]
            --AppConst.AppID = result[3] --第三个参数是签名
            AppConst.TokenStr = result[4]
            -- AppConst.SdkChannel = result[5]
            AppConst.SdkChannel = AppConst.ChannelType
            
            -- AppConst.SdkPackageName = AndroidDeviceInfo.Instance:GetPackageName()

            -- 发送登录成功事件
            this.RequestRegistSDK(AppConst.SdkId,AppConst.SdkChannel,result[3],AppConst.TokenStr,function ()
                Game.GlobalEvent:DispatchEvent(GameEvent.LoginSuccess.OnLoginSuccess,result[1])
            end)

        end
        
        
        -- 判断是否是注册并登录
        if this.isRegister then
            this.isRegister = false
            -- 登出之前的账号
            -- ThinkingAnalyticsManager.Logout()
            -- ThinkingAnalyticsManager.ClearSuperProperties()
            -- -- 开始
            -- ThinkingAnalyticsManager.SetSuperProperties({
            --     account = AppConst.isSDK and tostring(AppConst.OpenId) or "",
            --     Bundle_id = AppConst.isSDK and AppConst.SdkPackageName or "",
            --     xx_id = AppConst.isSDK and AppConst.SdkChannel or "",
            --     device_id = AppConst.isSDK and ThinkingAnalyticsManager.GetDeviceId() or ""
            -- })
            -- ThinkingAnalyticsManager.Track("create_account")
        end
        -- -- 发送登录成功事件
        -- this.RequestRegistSDK(AppConst.SdkId,AppConst.TokenStr,AppConst.AppID,AppConst.SdkChannel,function ()
        --     Game.GlobalEvent:DispatchEvent(GameEvent.LoginSuccess.OnLoginSuccess,result[1])
        -- end)
    end

    SDKMgr.onSwitchAccountCallback = function(resp)
        local result = string.split(resp, "#")
        if LoginManager.IsLogin and tonumber(result[1]) == SDK_RESULT.SUCCESS then
            -- ThinkingAnalyticsManager.Track("change_account")
            Framework.Dispose()
            App.Instance:ReStart()
        end
    end

    SDKMgr.onLogoutCallback = function(resp)
        local result = string.split(resp, "#")
        if LoginManager.IsLogin and tonumber(result[1]) == SDK_RESULT.SUCCESS then
            -- ThinkingAnalyticsManager.Track("quit_account")
            Framework.Dispose()
            App.Instance:ReStart()
        end
        -- 发送登出事件
        Game.GlobalEvent:DispatchEvent(GameEvent.LoginSuccess.OnLogout)
    end
end

function this.SaveLoginInfo(user, pw)
    --[[
    PlayerPrefs.SetInt(this.GameName.."LoginWay", this.CurLoginWay);
    PlayerPrefs.SetString(this.GameName.."Account", this.CurAccount);
    PlayerPrefs.SetString(this.GameName.."Session", this.CurSession);
    PlayerPrefs.Save();
    ]]--
    --sdkMgr:SaveSession(this.CurLoginWay)


end

local openIdkey = "openIdkey"
local openIdPw = "openIdPw"

function this.RequestRegist(name, pw, call)
    -- 

    local sign = Util.MD5Encrypt(string.format("%s%s%s", name,
            pw, this.sign))
    RequestPanel.Show(GetLanguageStrById(11115))
    networkMgr:SendGetHttp(LoginRoot_Url .. "tk/registerUser?userName=".. name .. "&password=".. pw .."&repeat=".. pw .. "&sign=" .. sign,
            function(str)
                RequestPanel.Hide()
                if str == nil then
                    return
                end
                
                local json = require 'cjson'
                local data = json.decode(str)
                
                local isEditor = AppConst and AppConst.Platform == "EDITOR"
                if data.code==0 then
                    if isEditor then
                        PopupTipPanel.ShowTip("账号注册成功！")
                    end
                    
                else if data.code==1 then
                     if isEditor then
                        PopupTipPanel.ShowTip("该账号已被注册，请更换账号！")
                    end
                    
                end
                if call then
                call(data.code)
                end
            end
               
            end,nil,nil,nil)
end
function this.RequestRegistSDK(uid, channel ,sdksign ,sdktoken, call)
    RequestPanel.Show(GetLanguageStrById(11117))
   
    local LoginRoot_PackageVersion = VersionManager:GetVersionInfo("sdkLodingUrl")
    Log(LoginRoot_PackageVersion.."/verify?userId=".. uid .. "&channel=".. channel .."&sdksign="..sdksign .."&sdktoken=" .. sdktoken)
    networkMgr:SendGetHttp(LoginRoot_PackageVersion.."/verify?userId=".. uid .. "&channel=".. channel .."&sdksign="..sdksign .."&sdktoken=" .. sdktoken,
            function(str)
                RequestPanel.Hide()
                if str == nil then
                    return
                end
               
                local json = require 'cjson'
                local data = json.decode(str)

                if data.errMessage then
                    MsgPanel.ShowOne(data.errMessage)
                    return
                end

                AppConst.OpenId=data.openId
                AppConst.MiTokenStr=data.token
                
                if data.code==1 then
                    PopupTipPanel.ShowTip(GetLanguageStrById(11116)..name.." "..data.msg)
                else
                    --PopupTipPanel.ShowTip("账号："..name.." "..data.msg)
                end
                if call then
                    call(data.code)
                end
            end,nil,nil,nil)
end

function this.RequestUser(name, pw, call)
    local sign = Util.MD5Encrypt(string.format("%s%s%s", name,
            pw, this.sign))

    RequestPanel.Show(GetLanguageStrById(11117))
    networkMgr:SendGetHttp(LoginRoot_Url .. "tk/userLogin?userName=".. name .. "&password=".. pw .. "&sign=" .. sign, function(str)
        RequestPanel.Hide()
        if str == nil then
            return
        end
        local json = require 'cjson'
        local data = json.decode(str)

        if data.code==0 then
            --PopupTipPanel.ShowTip(data.msg)
            this.openId = data.parms.openId
            this.token = data.parms.token
            --场景转换
        else
            PopupTipPanel.ShowTip("账号未注册，请先点击注册！")
        end
        if call then
            call(data.code)
        end
    end,nil,nil,nil)
end

--注销
function this.LogOut()
    this.CurLoginWay=-1
    this.CurAccount=''
    this.CurSession=''
    --sdkMgr:ClearSession()
    --[[
    PlayerPrefs.DeleteKey(this.GameName.."LoginWay")
    PlayerPrefs.DeleteKey(this.GameName.."Account")
    PlayerPrefs.DeleteKey(this.GameName.."Session")
    ]]--
    Framework.Dispose();
    --sdkMgr:LogOutTime(tostring(PlayerManager.player.id));
    App.Instance:ReStart();
end

return this