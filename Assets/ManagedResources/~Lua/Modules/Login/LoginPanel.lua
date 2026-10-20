require("Base/BasePanel")

LoginPanel = Inherit(BasePanel)
local this = LoginPanel
-- this.LoginWay = { Account = 0, WeChat = 1 }

local IsSDKLogin = AppConst.isSDK and AppConst.isSDKLogin

local openIdkey = "openIdkey"
local openIdPw = "openIdPw"
local lastLoginPlatform = "lastLoginPlatform"
local lastServerIndex = "lastServerIndex"
local defaultOpenIdkey = GetLanguageStrById(11118)
local defaultOpenIdPw = ""
local LoginRoot_Url = VersionManager:GetVersionInfo("serverUrl")
local LoginRoot_SubChannel = VersionManager:GetVersionInfo("subChannel")
local LoginRoot_Channel = VersionManager:GetVersionInfo("channel")
local LoginRoot_Version = VersionManager:GetVersionInfo("version")
local LoginRoot_PackageVersion = VersionManager:GetVersionInfo("packageVersion")
local orginLayer
local timeStamp = Time.realtimeSinceStartup
local timeSign = Util.MD5Encrypt(string.format("%s%s", timeStamp, LoginManager.sign))
local userIdnum = 0
--初始化组件（用于子类重写）
function this:InitComponent()
    orginLayer = 0

    this.sdkAgainLogin = Util.GetGameObject(self.transform, "GameStartsPanel/sdkAgainLogin")

    this.loginPart = Util.GetGameObject(self.transform, "GameStartsPanel/effect")
    this.tip = Util.GetGameObject(this.loginPart, "tip/Text")
    this.userIDButton = Util.GetGameObject(this.loginPart, "IdButton")
    this.userOpenIdBtn = Util.GetGameObject(this.loginPart, "OpenIdBtn")
    this.userIDText = Util.GetGameObject(this.loginPart, "OpenIdBtn/userID"):GetComponent("InputField")
    this.userOpenIdBtn:SetActive(false)

    --开始游戏
    this.btnLoginPart = Util.GetGameObject(this.loginPart, "gameStarts")
    this.btnLogin = Util.GetGameObject(this.btnLoginPart, "btn")
    this.googlebtn = Util.GetGameObject(this.btnLoginPart, "googlebtn")
    this.guestBtn = Util.GetGameObject(this.btnLoginPart, "guestBtn")

    --this.dropDownPart = Util.GetGameObject(this.loginPart, "quyuxuanzhe")
    --this.dropDown = Util.GetGameObject(this.dropDownPart, "Dropdown"):GetComponent("Dropdown")

    -- this.inputField = Util.GetGameObject(this.loginPart, "InputField"):GetComponent("InputField")
    -- this.UserBtn = Util.GetGameObject(this.loginPart, "userBtn")
    -- this.UserBtnText = Util.GetGameObject(this.loginPart, "userBtn/Text"):GetComponent("Text")

    this.btnAgreement = Util.GetGameObject(this.loginPart, "btns/btnAgreement") --协议
    this.btnNotice = Util.GetGameObject(this.loginPart, "btns/btnNotice") --公告
    this.btnUser = Util.GetGameObject(this.loginPart, "btns/btnUser") --切换账号
    this.btnCustomerService = Util.GetGameObject(this.loginPart, "btns/btnCustomerService") --客服
    this.btnCountryRank = Util.GetGameObject(this.loginPart, "btns/btnCountryRank") -- 国家排行
    this.LoginPanel_Btn1 = Util.GetGameObject(this.loginPart, "btns/LoginPanel_Btn1") --使用条款
    this.LoginPanel_Btn2 = Util.GetGameObject(this.loginPart, "btns/LoginPanel_Btn2") --个人信息
    -- this.Partical = Util.GetGameObject(self.transform, "BG/Partical")
    ---selectServerPart
    this.serverSelectPart = Util.GetGameObject(this.loginPart, "gameStarts/changeServer/serverSelect")
    this.serverImage = Util.GetGameObject(this.serverSelectPart, "Image"):GetComponent("Image")
    this.serverMes = Util.GetGameObject(this.serverSelectPart, "serverMes"):GetComponent("Text")
    this.changeServerBtn = Util.GetGameObject(this.loginPart, "gameStarts/changeServer")

    this.sdkLoginBtn = Util.GetGameObject(this.loginPart, "loginBtn")
    this.ToggleText = Util.GetGameObject(this.loginPart, "loginBtn/Toggle Text")
    this.AgeTip = Util.GetGameObject(this.loginPart, "ageTip")
    this.SetLoginPart(false)
    this.Partical = Util.GetGameObject(this.loginPart, "Partical")

    this.versionText = Util.GetGameObject(this.loginPart, "version"):GetComponent("Text")
    this.versionText.text = GetLanguageStrById(11119) .. LoginRoot_Version

    this.declaration = Util.GetGameObject(this.loginPart, "declaration")

    -- this.btnAgreement = Util.GetGameObject(this.declaration, "btnAgreement")--同意协议
    -- this.btnAgreementTxt = Util.GetGameObject(this.declaration, "btnAgreement/Text")
    this.EditionDepartment = Util.GetGameObject(this.declaration, "EditionDepartment"):GetComponent("Text")
    this.txtSc = this.ToggleText:GetComponent("SuperTextMesh")
    this.txtSc.text = GetLanguageStrById(50385)
    CustomEventManager.CustomEvent(101,"version"..LoginRoot_Version)
    
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(
        this.sdkAgainLogin,
        function()
            if AppConst.ChannelType == "None" then
                return
            end
            if GetChannerConfig().PrivacyAgreement then
                if PlayerPrefs.GetInt("IsAgreePrivacy") == 0 then
                    UIManager.OpenPanel(
                        UIName.PermissionPanel,
                        function()
                            SDKMgr:Login()
                        end
                    )
                else
                    SDKMgr:Login()
                end
            else
                SDKMgr:Login()
            end
        end
    )

    Util.AddClick(this.btnLogin, this.OnGooglePlayGamesLogin)
    Util.AddClick(this.googlebtn, this.OnGoogleLogin)
    Util.AddClick(this.guestBtn, this.OnGuestLogin)
    Util.AddClick(
        this.btnUser,
        function()
            local user = PlayerPrefs.GetString(openIdkey, defaultOpenIdkey)
            local userPw = PlayerPrefs.GetString(openIdPw, defaultOpenIdPw)
            UIManager.OpenPanel(
                UIName.LoginPopup,
                user,
                userPw,
                function(str, pw)
                    -- this.UserBtnText.text = str
                    PlayerPrefs.SetString(openIdkey, str)
                    PlayerPrefs.SetString(openIdPw, pw)
                end
            )
        end
    )
    Util.AddClick(
        this.btnNotice,
        function()
            -- RequestPanel.Show(GetLanguageStrById(11128))
            networkMgr:SendGetHttp(
                LoginRoot_Url .. "tk/getNotice?timestamp=" .. timeStamp .. "&sign=" .. timeSign,
                function(str)
                    UIManager.OpenPanel(UIName.NoticePopup, str)
                end,
                nil,
                nil,
                nil
            )
        end
    )
    Util.AddClick(
        this.LoginPanel_Btn1,
        function()
            UnityEngine.Application.OpenURL(
                "https://doc-hosting.flycricket.io/chao-shi-kong-mei-shao-nu-er-ci-yuan-xiu-xian-fang-zhi-privacy-policy/785135bb-e220-4582-95e2-3a65e7488fb0/privacy"
            )
            if IsSDKLogin then
                SDKMgr:LoginPanel_Btn1()
            end
        end
    )
    Util.AddClick(
        this.LoginPanel_Btn2,
        function()
            if IsSDKLogin then
                SDKMgr:LoginPanel_Btn2()
            end
        end
    )

    -- Util.AddClick(this.UserBtn, function()
    --     local user = PlayerPrefs.GetString(openIdkey, defaultOpenIdkey)
    --     local userPw = PlayerPrefs.GetString(openIdPw, defaultOpenIdPw)
    --     UIManager.OpenPanel(UIName.LoginPopup, user, userPw, function(str, pw)
    --         -- this.UserBtnText.text = str
    --         PlayerPrefs.SetString(openIdkey, str)
    --         PlayerPrefs.SetString(openIdPw, pw)
    --     end)
    -- end)
    Util.AddClick(
        this.userIDButton,
        function()
            userIdnum = userIdnum + 1
            if userIdnum > 10 then
                this.userOpenIdBtn:SetActive(true)
                this.userIDText.text = AppConst.OpenId
            end
        end
    )
    Util.AddClick(
        this.userOpenIdBtn,
        function()
            userIdnum = 0
            this.userOpenIdBtn:SetActive(false)
        end
    )
    Util.AddClick(
        this.changeServerBtn,
        this.OpenSelectList
    )

    --SDK 登录
    Util.AddClick(
        this.sdkLoginBtn,
        function()
            this.sdkLoginBtn:SetActive(false)
            this.Partical:SetActive(false)
            this.SDKLogin()
        end
    )

    Util.AddClick(
        this.AgeTip,
        function()
            UIManager.OpenPanel(
                UIName.GeneralPopup,
                GENERAL_POPUP_TYPE.Txt,
                GetLanguageStrById(50211),
                GetLanguageStrById(50210)
            )
        end
    )

    Util.AddClick(
        this.btnAgreement,
        function()
            -- if PlayerPrefs.GetInt("IsAgreePrivacy") == 0 then
            --     PlayerPrefs.SetInt("IsAgreePrivacy", 1)
            -- else
            --     PlayerPrefs.SetInt("IsAgreePrivacy", 0)
            -- end
            -- this.ChangeAgreePrivacy()
            UIManager.OpenPanel(UIName.PrivacyPanel)
        end
    )

    -- Util.AddClick(this.btnAgreementTxt, function ()
    --     UIManager.OpenPanel(UIName.PrivacyPanel)
    -- end)

    Util.AddClick(
        this.btnCustomerService,
        function()
            UIManager.OpenPanel(UIName.CustomerServicePanel)
        end
    )

    -- 国家排行入口（启动页可见；还没选过国家时由面板自己弹选择窗）
    if this.btnCountryRank and not IsNull(this.btnCountryRank) then
        Util.AddClick(
            this.btnCountryRank,
            function()
                UIManager.OpenPanel(UIName.CountryRankPanel)
            end
        )
    end
end
        function this.OpenSelectList()
            if not this.serverList then
                return
            end
            UIManager.OpenPanel(
                UIName.ServerListSelectPanel,
                {
                    serverList = this.serverList,
                    myServerList = this.myServerList,
                    lastServer = this.lastServer,
                    recommend = this.recommend,
                    callback = function(index)
                        local list = this.serverList[index]
                        PlayerPrefs.SetInt(lastServerIndex, index)
                        PlayerPrefs.SetString("lastServerName", this.serverList[index].name)
                        PlayerManager.serverInfo = list
                        LoginManager.SocketAddress = list.ip
                        LoginManager.SocketPort = tonumber(list.port) or 0
                        LoginManager.ServerId = list.server_id
                        LoginManager.state = list.state
                        -- local severArea = tonumber(string.sub(list.server_id, 0, -5))
                        this.serverImage.sprite = Util.LoadSprite(ServerStateIconDef[list.state])
                        this.serverMes.text = GetServerName(PlayerManager.serverInfo)
                    end
                }
            )
        end
--添加事件监听（用于子类重写）

function this:AddListener()
    Game.GlobalEvent:AddEvent(Protocal.Connect, this.OnConnect)
    Game.GlobalEvent:AddEvent(Protocal.Disconnect, this.OnDisconnect)
    Game.GlobalEvent:AddEvent(GameEvent.LoginSuccess.OnLoginSuccess, this.RefreshLoginStatus)
    Game.GlobalEvent:AddEvent(GameEvent.LoginSuccess.OnLogout, this.OnLogout)
    Game.GlobalEvent:AddEvent(GameEvent.NoticePanel.OnOpen,this.OnOpenNoticePanel)
    Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, this.triggerCallBack)
    -- Game.GlobalEvent:AddEvent(GameEvent.LoginSuccess.OnAgreePrivacy, this.ChangeAgreePrivacy)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(Protocal.Connect, this.OnConnect)
    Game.GlobalEvent:RemoveEvent(Protocal.Disconnect, this.OnDisconnect)
    Game.GlobalEvent:RemoveEvent(GameEvent.LoginSuccess.OnLoginSuccess, this.RefreshLoginStatus)
    Game.GlobalEvent:RemoveEvent(GameEvent.LoginSuccess.OnLogout, this.OnLogout)
    Game.GlobalEvent:RemoveEvent(GameEvent.NoticePanel.OnOpen,this.OnOpenNoticePanel)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.LoginSuccess.OnAgreePrivacy, this.ChangeAgreePrivacy)
end

function this.OnOpenNoticePanel()
    this.Partical.gameObject:SetActive(not this.Partical.gameObject.activeSelf)

end

function this:OnLogout()
    if IsSDKLogin then
        this.SetLoginPart(false)
        this.sdkLoginBtn:SetActive(false)
        -- this.inputField.gameObject:SetActive(false)
        -- this.UserBtn:SetActive(false)
        this.btnUser:SetActive(false)
        this.btnNotice.transform.position = this.btnUser.transform.position
        this.SDKLogin()
    else
        this.sdkLoginBtn:SetActive(false)

        local userId = PlayerPrefs.GetString(openIdkey, defaultOpenIdkey)
        -- this.UserBtn:SetActive(true)
        this.btnUser:SetActive(true)
        -- this.inputField.gameObject:SetActive(false)
        -- this.UserBtnText.text = userId

        -- RequestPanel.Show(GetLanguageStrById(11121))
        this.SetLoginPart(true)
        -- 获取服务器列表
        this.RequestServerList(userId, this.OnReceiveServerList)
    end
end

function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.gameObject, self.sortingOrder - orginLayer)
    orginLayer = this.sortingOrder
end

--改变同意隐私协议状态
-- function this.ChangeAgreePrivacy()
--     if not GetChannerConfig().PrivacyAgreement then
--         this.btnAgreement:SetActive(false)
--         return
--     end
--     Util.GetGameObject(this.btnAgreement, "Image"):SetActive(PlayerPrefs.GetInt("IsAgreePrivacy") == 1)
-- end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
    if AppConst.Code ~= "" then
        MsgPanel.ShowOne(
            AppConst.Code,
            function()
                Framework.Dispose()
                App.Instance:ReStart()
            end
        )

        AppConst.Code = ""
    end
    if GetChannerConfig().Text_VersionNumber then
        this.EditionDepartment.text = GetLanguageStrById(GetChannerConfig().Text_VersionNumber_ID)
    else
        this.EditionDepartment.text = ""
    end
    this.btnCustomerService:SetActive(GetChannerConfig().Button_Logon_CustomerService)
    this.btnAgreement:SetActive(GetChannerConfig().PrivacyAgreement)
    if GetChannerConfig().Bg_Logon then
        Util.GetGameObject(this.gameObject, "None"):SetActive(false)
        Util.GetGameObject(this.gameObject, "BG/" .. GetChannerConfig().Bg_Logon):SetActive(true)
    else
        Util.GetGameObject(this.gameObject, "None"):SetActive(true)
    end

    if IsSDKLogin then
        this.SetLoginPart(false)
        this.sdkLoginBtn:SetActive(false)
        -- this.inputField.gameObject:SetActive(false)
        -- this.UserBtn:SetActive(false)
        this.btnUser:SetActive(false)
        this.btnNotice.transform.position = this.btnUser.transform.position
        this.SDKLogin()
    else
        this.sdkLoginBtn:SetActive(false)

        local userId = PlayerPrefs.GetString(openIdkey, defaultOpenIdkey)
        -- this.UserBtn:SetActive(true)
        this.btnUser:SetActive(false)
        -- this.inputField.gameObject:SetActive(false)
        -- this.UserBtnText.text = userId

        -- RequestPanel.Show(GetLanguageStrById(11121))
        this.SetLoginPart(true)
        -- 获取服务器列表
        this.RequestServerList(userId, this.OnReceiveServerList)
    end
    this.LoginPlatform = PlayerPrefs.GetInt(lastLoginPlatform, 0)
    if this.LoginPlatform  ~= 0 then
        this.sdkLoginBtn:SetActive(true)
        this.btnLoginPart.gameObject:SetActive(false)
        -- this.serverSelectPart.gameObject:SetActive(false)
    end

    local tran = this.tip:GetComponent("RectTransform")
    local offsetX = (LayoutUtility.GetPreferredWidth(tran) + Screen.width) / 2
    tran.anchoredPosition = Vector2.New(offsetX, 0)
    tran:DOAnchorPosX(-offsetX, 30, false):SetEase(Ease.Linear):SetLoops(-1)

    SoundManager.PlayMusic(SoundConfig.BGM_Login)
    SoundManager.PlayAmbient(SoundConfig.Ambient_Login)
    

    local channelConfig = GetChannerConfig()
    this.LoginPanel_Btn1:SetActive(false)
    -- this.LoginPanel_Btn2:SetActive(channelConfig.Button_Logon_information)
    this.LoginPanel_Btn2:SetActive(false)

    -- this.AgeTip:SetActive(channelConfig.Button_Logon_AgeTips)
    this.AgeTip:SetActive(false)
    this.declaration:SetActive(channelConfig.Button_Logon_HealthyTips)
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    this.SetLoginPart(false)
    SoundManager.PauseAmbient()
end

-- 请求获取服务器列表
function this.RequestServerList(userId, callback)
    -- RequestPanel.Show(GetLanguageStrById(11121))
    Log("RequestServerList userId:" .. userId)
    Log(
        string.format(
            "%stk/getServerList?openId=%s&channel=%s&plat=android&sub_channel=%s&server_version=%s",
            LoginRoot_Url,
            userId,
            LoginRoot_Channel,
            LoginRoot_SubChannel,
            LoginRoot_Version
        )
    )

    networkMgr:SendGetHttp(
        string.format(
            "%stk/getServerList?openId=%s&channel=%s&plat=android&sub_channel=%s&server_version=%s",
            LoginRoot_Url,
            userId,
            LoginRoot_Channel,
            LoginRoot_SubChannel,
            LoginRoot_Version
        ),
        callback,
        nil,
        nil,
        nil
    )
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

this.isWaiting = false
function this.SDKLogin()
    local func = function()
        if not this.isWaiting then
            this.isWaiting = true
            Timer.New(
                function()
                    -- SDKMgr:Login()
                    this.OnLoginClick()
                    this.isWaiting = false
                    CustomEventManager.GameCustomEvent("登录页面弹出")
                end,
                1,
                1
            ):Start()
        end
    end
    if GetChannerConfig().PrivacyAgreement then
        if PlayerPrefs.GetInt("IsAgreePrivacy") == 0 then
            -- UIManager.OpenPanel(UIName.PrivacyPanel, func)
            UIManager.OpenPanel(UIName.PermissionPanel, nil, func)
        else
            func()
        end
    else
        func()
    end
end

function this.RefreshLoginStatus(result)
    if result == SDK_RESULT.SUCCESS then
        CustomEventManager.GameCustomEvent("登录成功")
        -- RequestPanel.Show(GetLanguageStrById(11121))
        this.SetLoginPart(true)
        this.RequestServerList(AppConst.OpenId, this.OnReceiveServerList)
    else
        this.sdkLoginBtn:SetActive(true)
    end
end

-- function this.RefreshLoginStatusLocal(openid)
--     this.RequestServerList(openid, this.OnReceiveServerList)
-- end

function this.SetSDKExtensionParams(params)
    if not params or params == "" then
        return
    end
    local json = require "cjson"
    local context = json.decode(params)
    BindPhoneNumberManager.SetPtToken(context.token)
    LoginManager.pt_pId = context.pid
    LoginManager.pt_gId = context.gid
end

--收到公告
function this.OnReceiveAnnouncement(str)
    if str == nil then
        return
    end
    pcall(
        function()
            local json = require "cqueryAllies"
            local data = json.decode(str)
            if data.content ~= nil and data.content ~= "" then
                UIManager.OpenPanel(UIName.GongGaoPanel, data.content)
            end
        end
    )
end

-- Define triggerCallBack to avoid undefined global variable error
function this.triggerCallBack(panelType, panel)
    -- Add your callback logic here if needed
    -- Log("LoginPanel triggerCallBack: " .. panelType)
     if panelType == UIName.NoticePopup then
          local name = PlayerPrefs.GetString("isfirstSelectServerName")
            Log("isfirstSelectServerName:" .. name)
            if not name or name == "" then
                      this.OpenSelectList()
                    PlayerPrefs.SetString("isfirstSelectServerName","true")
            end

      end
end

--获取服务器列表地址
function this.OnReceiveServerList(str)
    Log("OnReceiveServerList" .. str)
    -- 获取服务器列表成功后，默认开启公告
    -- RequestPanel.Show(GetLanguageStrById(11128))
    networkMgr:SendGetHttp(
        LoginRoot_Url .. "tk/getNotice?timestamp=" .. timeStamp .. "&sign=" .. timeSign,
        function(str)
            UIManager.OpenPanel(UIName.NoticePopup, str)
        end,
        nil,
        nil,
        nil
    )

    if str == nil then
        return
    end
    if str ~= nil and str ~= "" then
        MyPCall(
            function()
                local json = require "cjson"
                local data = json.decode(str)

                ---selectServerPart

                this.SetServerList(data)
              
            end
        )
    end
end

function this.SetServerList(data)
    this.CacheLoginData(data)

    local lastIndex = PlayerPrefs.GetInt(lastServerIndex, 1)

    if AppConst.isOpenGM then
        local name = PlayerPrefs.GetString("lastServerName")
        if not name then
            lastIndex = 1
            PlayerPrefs.SetString("lastServerName", this.serverList[1].name)
        end
        for i = 1, #this.serverList do
            if this.serverList[i].name == name then
                lastIndex = i
                break
            end
        end
    else
        if this.lastServer then --有最近登录显示最近登录，没有显示推荐，否则显示第一个服
            for i = 1, #this.serverList do
                if this.serverList[i].server_id == this.lastServer.serverid then
                    lastIndex = i
                    break
                end
            end
        else
            if this.recommend then
                if this.myServerList then
                    local levelLs = 0
                    local severRecomend = 0
                    for i = 1, #this.myServerList do
                        if this.serverList[i].level > levelLs then
                            levelLs = this.serverList[i].level
                            severRecomend = this.serverList[i].server_id
                        end
                    end
                    for i = 1, #this.serverList do
                        if this.serverList[i].server_id == severRecomend then
                            lastIndex = i
                            break
                        end
                    end
                else
                    for i = 1, #this.serverList do
                        if this.serverList[i].server_id == this.recommend then
                            lastIndex = i
                            break
                        end
                    end
                end
            end
        end
        if not this.serverList[lastIndex] then
            lastIndex = 1
            PlayerPrefs.SetInt(lastServerIndex, 1)
        end
    end

    PlayerManager.serverInfo = this.serverList[lastIndex]
    LoginManager.SocketAddress = this.serverList[lastIndex].ip
    LoginManager.SocketPort = tonumber(this.serverList[lastIndex].port) or 0
    LoginManager.ServerId = this.serverList[lastIndex].server_id
    LoginManager.state = this.serverList[lastIndex].state

    -- local severArea = tonumber(string.sub(this.serverList[lastIndex].server_id, 0, -5))
    this.serverImage.sprite = Util.LoadSprite(ServerStateIconDef[LoginManager.state])
    this.serverMes.text = GetServerName(PlayerManager.serverInfo)

    RequestPanel.Hide()
end

function this.CacheLoginData(data)
    this.serverList = {}
    if data.serverList then
        for i = 1, #data.serverList do
            this.serverList[i] = data.serverList[i]
        end
    end
    table.sort(
        this.serverList,
        function(a, b)
            if a.isnew == b.isnew then
                return a.server_id < b.server_id
            else
                return a.isnew > b.isnew
            end
        end
    )
    this.myServerList = {}
    if data.myServerList then
        for i = 1, #data.myServerList do
            this.myServerList[i] = data.myServerList[i]
        end
    end
    this.lastServer = data.lastServer
    this.recommend = data.recommend
end

--用户id登录
function this.OnReceiveLogin(str)
    RequestPanel.Hide()
    if str == nil then
        return
    end
    if str == "fail" then
        if IsSDKLogin then
            Framework.Dispose()
            App.Instance:ReStart()
        end
        return
    end
    if str ~= nil and str ~= "" then
        MyPCall(
            function()
                local json = require "cjson"
                local data = json.decode(str)
                if data.uid and data.token and not LoginManager.IsLogin then
                    --GM「以UID重登」：用服务端签发的 uid#token 覆盖本次登录身份（一次性，用完即删）
                    local gmUid = PlayerPrefs.GetString(LoginManager.GM_SWITCH_UID_KEY, "")
                    local gmToken = PlayerPrefs.GetString(LoginManager.GM_SWITCH_TOKEN_KEY, "")
                    local gmTime = tonumber(PlayerPrefs.GetString(LoginManager.GM_SWITCH_TIME_KEY, "0")) or 0
                    local switchUid = tonumber(gmUid)
                    local switchToken = tonumber(gmToken)
                    local notExpired = (os.time() - gmTime) <= LoginManager.GM_SWITCH_TTL
                    if switchUid and switchToken and switchUid > 0 and notExpired then
                        PlayerPrefs.DeleteKey(LoginManager.GM_SWITCH_UID_KEY)
                        PlayerPrefs.DeleteKey(LoginManager.GM_SWITCH_TOKEN_KEY)
                        PlayerPrefs.DeleteKey(LoginManager.GM_SWITCH_TIME_KEY)
                        PlayerPrefs.Save()
                        AppConst.UserId = switchUid
                        AppConst.Token = switchToken
                        PopupTipPanel.ShowTip("GM重登：当前身份UID " .. switchUid)
                        Log(string.format("GM switch login: server uid=%s token=%s -> switch uid=%s", tostring(data.uid), tostring(data.token), tostring(switchUid)))
                    else
                        if gmUid ~= "" or gmToken ~= "" then
                            --标记已过期：清掉，避免以后误用
                            PlayerPrefs.DeleteKey(LoginManager.GM_SWITCH_UID_KEY)
                            PlayerPrefs.DeleteKey(LoginManager.GM_SWITCH_TOKEN_KEY)
                            PlayerPrefs.DeleteKey(LoginManager.GM_SWITCH_TIME_KEY)
                            PlayerPrefs.Save()
                        end
                        AppConst.UserId = data.uid
                        AppConst.Token = data.token
                    end
                    local openId = AppConst.isSDKLogin and AppConst.OpenId or PlayerPrefs.GetString(openIdkey)
                    NetManager.LoginRequest(
                        openId,
                        function()
                            if not LoginManager.IsLogin then
                                LoginManager.IsLogin = true
                                this.ExecuteLoading()
                            end
                        end
                    )
                end
            end
        )
    end
end

-- 检测是否可以注册
function this.CheckIsCanRegister()
    if this.serverList and #this.serverList > 0 then
        local serverData
        for i = 1, #this.serverList do
            if this.serverList[i].server_id == LoginManager.ServerId then
                serverData = this.serverList[i]
                break
            end
        end

        if serverData and serverData.isbanreg and serverData.isbanreg == 1 then
            local isHaveUser = false
            for i = 1, #this.myServerList do
                if serverData.server_id == this.myServerList[i].serverid then
                    isHaveUser = true
                end
            end
            if isHaveUser then
                return true
            else
                return false
            end
        else
            return true
        end
    end
    return true
end

function this.LogTime(v)
end

--登录进主界面之前需要依次请求玩家数据
function this.ExecuteLoading()
    -- 步骤清单：串行步骤一步一个 RTT（欧洲连亚洲服实测 288ms/步），
    -- 纯展示、彼此无依赖的请求合并成"并行分组"一次发出，只等最慢的那个回包。
    -- 分组约束（加新组前必须确认）：
    --   1) 组内成员之间没有数据依赖，也不依赖组外尚未完成的步骤；
    --   2) 各自期待的回包协议号互不相同（C# 侧 callbacks 以回包 msgId 为 key，
    --      同号并发会让后注册的那个回调被丢弃 ⇒ 该成员永远不回调）；
    --   3) 都是纯展示数据，晚到或缺失不会阻断进游戏。
    local requestList = {}

    -- 单步：发请求，等回调再走下一步
    local function addStep(name, fire)
        table.insert(requestList, function()
            fire(LoadingPanel.OnStep)
            return name
        end)
    end

    -- 并行分组：组内请求同时发出，全部回包（或看门狗超时）后只推进一格
    local function addGroup(name, list)
        table.insert(requestList, { groupName = name, members = list })
    end

    -- 组内成员：fire(cb) 里发一个请求，回包时调用 cb（只会被计一次）
    local function member(name, fire)
        return { name = name, fire = fire }
    end

    addStep("PlayerInfoRequest", function(cb) NetManager.PlayerInfoRequest(cb) end)
    addGroup("基础数据", {
        member("RequestMission", function(cb) NetManager.RequestMission(cb) end),
        member("ItemInfoRequest", function(cb) NetManager.ItemInfoRequest(0, cb) end),
        member("AllEquipRequest", function(cb) NetManager.AllEquipRequest(0, cb) end),
        member("RequestAllPlanData", function(cb) CombatPlanManager.RequestAllPlanData(cb) end),
        member("MedalGetAllRequest", function(cb) NetManager.MedalGetAllRequest(cb) end),
    })
    addStep("HeroInfoRequest", function(cb) NetManager.HeroInfoRequest(0, cb) end)
    addStep("TeamInfoRequest", function(cb) NetManager.TeamInfoRequest(cb) end)
    addGroup("邮件/战绩/活动/竞技场/商店/聊天", {
        member("GetAllMailData", function(cb) NetManager.GetAllMailData(cb) end),
        member("GetAllFightDataRequest", function(cb) NetManager.GetAllFightDataRequest(cb) end),
        member("GetActivityAllRewardRequest", function(cb) NetManager.GetActivityAllRewardRequest(cb) end),
        member("RequestBaseArenaData", function(cb) NetManager.RequestBaseArenaData(cb) end),
        member("ShopManager.InitData", function(cb) ShopManager.InitData(cb) end),
        member("ChatManager.InitData", function(cb) ChatManager.InitData(cb) end),
    })
    addStep("RequestArenaRankData", function(cb) NetManager.RequestArenaRankData(1, cb) end)
    addStep("GetAllFunState", function(cb) NetManager.GetAllFunState(cb) end)
    addStep("RequestGetFriendInfo1", function(cb) NetManager.RequestGetFriendInfo(1, cb) end)
    addStep("RequestGetFriendInfo3", function(cb) NetManager.RequestGetFriendInfo(3, cb) end)
    addStep("FriendChatManager.InitData", function(cb) FriendChatManager.InitData(cb) end)
    addStep("MyGuildManager.InitBaseData", function(cb) MyGuildManager.InitBaseData(cb) end)
    addStep("GuildFightManager.InitBaseData", function(cb) GuildFightManager.InitBaseData(cb) end)
    addStep("GetAllGuildSkillData", function(cb) NetManager.GetAllGuildSkillData(cb) end)
    addStep("InitFightPointLevelInfo", function(cb) NetManager.InitFightPointLevelInfo(cb) end)
    addStep("GuildHelpGetAllRequest", function(cb) NetManager.GuildHelpGetAllRequest(cb) end)
    addStep("GuideBattlePanel.InitData", function(cb) GuildBattleManager.InitData(cb) end)
    addGroup("排行榜首/守护/爬塔/阿登/支援/明斯克/神眷者", {
        member("RankFirstRequest", function(cb) NetManager.RankFirstRequest({3, 22, 20, 4, 21}, {0, 0, 0, 0, 20}, cb) end),
        member("GetAllAdjutantInfo", function(cb) NetManager.GetAllAdjutantInfo(cb) end),
        member("VirtualBattleGetInfo", function(cb) NetManager.VirtualBattleGetInfo(cb) end),
        member("GetSituationInfoRequest", function(cb) NetManager.GetSituationInfoRequest(cb) end),
        member("GetServerData", function(cb) SupportManager.GetServerData(cb) end),
        member("GuildCarDelayManager.InitBaseData", function(cb) GuildCarDelayManager.InitBaseData(cb) end),
        member("ReqCVInfo", function(cb) AircraftCarrierManager.GetLeadData(cb) end),
    })
    addStep("GetAllPlaneReq", function(cb) AircraftCarrierManager.GetAllPlaneReq(cb) end)
    addGroup("展示数据(训练/称号/巅峰/梦魇/阵容/跨服/全服/心愿/战令)", {
        member("DefTrainingGetInfo", function(cb) NetManager.DefTrainingGetInfo(cb) end),
        member("chenghaoRequest", function(cb) NetManager.chenghaoRequest(cb) end),
        member("ArenaTopMatchRequest", function(cb) ArenaTopMatchManager.RequestTopMatchBaseInfo(cb) end),
        member("WorldBossRequest", function(cb) NetManager.CarChallengeProgressIndication(cb) end),
        member("LineupRecommendRequest", function(cb) PlayerManager.RefreshreceivedList(cb) end),
        member("GetWorldArenaInfoRequest", function(cb) NetManager.GetWorldArenaInfoRequest(false, false, cb) end),
        member("InitRankingRewardList", function(cb) RankingManager.InitRankingRewardList(cb) end),
        member("InitWish", function(cb) CardActivityManager.InitWish(cb) end),
        member("GetAllWarOrderData", function(cb) OperatingManager.GetAllWarOrderData(cb) end),
    })

    table.insert(
        requestList,
        function()
            -- 登录请求最终接口，所有请求放在此接口之前
            if AppConst.isGuide then
                if GuideManager.GetCurId(GuideType.Force) == 1 and PlayerManager.nickName == tostring(PlayerManager.uid) then
                    -- local func = function ()
                    --     -- StoryManager.EventTrigger(300007)
                    --     StoryManager.EventTrigger(100001)
                    -- end
                    -- UIManager.OpenPanel(UIName.VideoPanel,"cn2-X1_video_Scene01_01",func)
                    --UIManager.OpenPanel(UIName.BackGroundInfoPanel,GetLanguageStrById(22551),func)
                    --StoryManager.EventTrigger(300007)
                    --创号阶段先进入剧情对话，进入假战斗，然后对话起名，最后进入主界面
                    local exBattle = function()
                        PatFaceManager.isLogin = true
                        UIManager.OpenPanelAsync(
                            UIName.MainPanel,
                            function()
                                UIManager.OpenPanel(UIName.FightPointPassMainPanel)
                                LoadingPanel.End()
                            end
                        )
                    end
                    StoryManager.EventTrigger(100001, exBattle)
                else
                    PatFaceManager.isLogin = true
                    UIManager.OpenPanelAsync(
                        UIName.MainPanel,
                        function()
                            if GuideManager.GetCurId(GuideType.Force) ~= -1 then
                                UIManager.OpenPanel(UIName.FightPointPassMainPanel)
                            end
                            LoadingPanel.End()
                        end
                    )
                end
            else
                UIManager.OpenPanelAsync(
                    UIName.MainPanel,
                    function()
                        if RoomManager.RoomAddress == nil or RoomManager.RoomAddress == "" then
                            RoomManager.IsMatch = 0
                        elseif RoomManager.RoomAddress == "1" then
                            RoomManager.IsMatch = 1
                            UIManager.OpenPanel(UIName.GMPanel)
                            PopupTipPanel.ShowTipByLanguageId(11122)
                        else
                            if RoomManager.CurRoomType == 1 then
                                RoomManager.RoomReGetGameRequest(RoomManager.RoomAddress)
                            end
                        end
                        LoadingPanel.End()
                    end
                )
            end
            -- 登录成功刷新红点数据
            -- 预加载巅峰战红点所需数据
            ArenaTopMatchManager.RequestTopMatchBaseInfo()
            ArenaTopMatchManager.RequestRankData(1)
            ArenaTopMatchManager.RequestTodayAlreadyLikeUids_TopMatch()
            RedpotManager.CheckAllRedPointStatus()
            -- 检查新字状态
            FunctionOpenMananger.InitCheck()
            this.SubmitGameData()
            DataCenterManager.CommitBootStatus()
        end
    )

    --
    for _, func in ipairs(requestList) do
        LoadingPanel.AddStep(func)
    end
    LoadingPanel.Start()
    this:ClosePanel()
end

this.isLoginClick = false
this.LoginPlatform = 0
function this.OnGooglePlayGamesLogin()
    this.LoginPlatform = 2
    this.OnLoginClick()
end
function this.OnGoogleLogin()
    this.LoginPlatform = 1
    this.OnLoginClick()
end
function this.OnGuestLogin()
    this.LoginPlatform = 3
    this.OnLoginClick()
end
function this.OnLoginClick()
    Log("OnLoginClick")
    -- if GetChannerConfig().PrivacyAgreement then
    --     if PlayerPrefs.GetInt("IsAgreePrivacy") == 0 then
    --         PopupTipPanel.ShowTipByLanguageId(91001568)
    --         UIManager.OpenPanel(UIName.PrivacyPanel)
    --         return
    --     end
    -- end
    if not this.CheckIsCanRegister() then
        PopupTipPanel.ShowTipByLanguageId(22901)
        return
    end

    if LoginManager.state == 0 or LoginManager.state == 1 then
        local function reServerCallback(str)
            if str == nil then
                return
            end
            if str ~= nil and str ~= "" then
                MyPCall(
                    function()
                        local json = require "cjson"
                        local data = json.decode(str)
                        ---selectServerPart
                        this.SetServerList(data)
                        -- 还是不可进状态则请求
                        if LoginManager.state == 0 or LoginManager.state == 1 then
                            PopupTipPanel.ShowTipByLanguageId(11132)
                            RequestPanel.Hide()
                        else
                            -- 连接socket
                            this.RequestSocketLogin()
                        end
                    end
                )
            end
        end
        -- 判断获取服务器的id
        if IsSDKLogin then
            this.RequestServerList(AppConst.OpenId, reServerCallback)
        else
            local userId = PlayerPrefs.GetString(openIdkey, defaultOpenIdkey)
            this.RequestServerList(userId, reServerCallback)
        end
        return
    end
   
    if not IsSDKLogin then
        local user = PlayerPrefs.GetString(openIdkey, defaultOpenIdkey)
        local userPw = PlayerPrefs.GetString(openIdPw, defaultOpenIdPw)
        local lastPlt = PlayerPrefs.GetInt(lastLoginPlatform, 0)
        Log("OnLoginClick user"..user)
        if user == defaultOpenIdkey or userPw == defaultOpenIdPw or lastPlt ~= this.LoginPlatform then
            -- UIManager.OpenPanel(UIName.RegistPopup, function(str, pw)
            --     this.UserBtnText.text = str
            --     PlayerPrefs.SetString(openIdkey, str)
            --     PlayerPrefs.SetString(openIdPw, pw)
            -- end)
            -- UIManager.OpenPanel(UIName.LoginPopup, nil, nil, function(str, pw)
            --     -- this.UserBtnText.text = str
            --     PlayerPrefs.SetString(openIdkey, str)
            --     PlayerPrefs.SetString(openIdPw, pw)
            -- end)

            Log(
                "LoginPlatform:" ..
                    this.LoginPlatform .. " user:" .. user .. " userPw:" .. userPw .. " lastPlt:" .. lastPlt
            )

            ggSignMgr:LoginByPlatformType(
                this.LoginPlatform,
                function(data)
                    if data.IsSucc then
                        LoginManager.RequestRegist(
                            data.PlatformId,
                            data.Pw,
                            function(code)
                                if code == 0 or code==1 then
                                    PlayerPrefs.SetString(openIdkey, data.PlatformId)
                                    PlayerPrefs.SetString(openIdPw, data.Pw)
                                    PlayerPrefs.SetInt(lastLoginPlatform, this.LoginPlatform)
                                    -- 连接socket
                                    this.OnLoginClick()
                                end
                            end
                        )
                        -- LoginManager.RequestRegistSDK(
                        --     data.PlatformId,
                        --     "google",
                        --     LoginManager.sign,
                        --     data.Pw,
                        --     function()
                        --         Game.GlobalEvent:DispatchEvent(GameEvent.LoginSuccess.OnLoginSuccess, result[1])
                        --     end
                        -- )
                    end
                end
            )
        else
            LoginManager.RequestUser(
                user,
                userPw,
                function(code)
                    if code ~= 0 then
                        -- UIManager.OpenPanel(UIName.LoginPopup, user, userPw, function(str, pw)
                        --     -- this.UserBtnText.text = str
                        --     PlayerPrefs.SetString(openIdkey, str)
                        --     PlayerPrefs.SetString(openIdPw, pw)
                        -- end)
                        ggSignMgr:LoginByPlatformType(
                            this.LoginPlatform,
                            function(data)
                                if data.IsSucc then
                                    LoginManager.RequestRegist(
                                        data.PlatformId,
                                        data.Pw,
                                        function(code)
                                            if code == 0 then
                                                PlayerPrefs.SetString(openIdkey, data.PlatformId)
                                                PlayerPrefs.SetString(openIdPw, data.Pw)
                                                PlayerPrefs.SetInt(lastLoginPlatform, this.LoginPlatform)
                                                -- 连接socket
                                                this.RequestSocketLogin()
                                            end
                                        end
                                    )
                                end
                            end
                        )
                    else
                        --this.loginMask:SetActive(true)
                        --Timer.New(function()
                        --UIManager.OpenPanel(UIName.NoticePopup)
                        -- this.loginMask:SetActive(false)
                        --end, 2.5, 1):Start()
                        if code == 2 then
                            if LoginManager.IsOpenAddiction then
                                --> 1关闭开启notice
                                UIManager.OpenPanel(UIName.IdSurePopup, 1)
                                LoginManager.IsShowPayAddiction = true
                            else
                                -- UIManager.OpenPanel(UIName.NoticePopup)
                            end
                        else
                            -- UIManager.OpenPanel(UIName.NoticePopup)
                            if LoginManager.IsOpenAddiction then
                                -->
                                if tonumber(msg) < 18 then
                                    LoginManager.IsShowPayAddiction = true
                                end
                            end
                            -- 连接socket
                            this.RequestSocketLogin()
                        end
                    end
                end
            )
        end
    else
        -- this.loginMask:SetActive(true)
        -- Timer.New(function()
        --     UIManager.OpenPanel(UIName.NoticePopup)
        --     this.loginMask:SetActive(false)
        -- end, 2.5, 1):Start()
    end
end

-- 请求连接socket
function this.RequestSocketLogin()
    if not LoginManager.SocketAddress or LoginManager.SocketAddress == "" then
        LogError("RequestSocketLogin failed: SocketAddress is nil or empty")
        PopupTipPanel.ShowTipByLanguageId(11132)
        RequestPanel.Hide()
        return
    end
    if not LoginManager.SocketPort then
        LogError("RequestSocketLogin failed: SocketPort is nil")
        PopupTipPanel.ShowTipByLanguageId(11132)
        RequestPanel.Hide()
        return
    end
    -- RequestPanel.Show(GetLanguageStrById(11124))
    SocketManager.Disconnect(SocketType.LOGIN)
    SocketManager.AddNetwork(SocketType.LOGIN, LoginManager.SocketAddress, LoginManager.SocketPort)
    SocketManager.TryConnect(SocketType.LOGIN)
end

function this.OnConnect(network)
    RequestPanel.Hide()
    if network.type ~= SocketType.LOGIN then
        return
    end
    -- RequestPanel.Show(GetLanguageStrById(11125))
    if IsSDKLogin then
        Log(
            LoginRoot_Url ..
                "tk/getUserInfo?openId=" ..
                    AppConst.OpenId ..
                        "&serverId=" ..
                            LoginManager.ServerId ..
                                "&token=" ..
                                    AppConst.MiTokenStr ..
                                        "&platform=" ..
                                            1 ..
                                                "&sub_channel=" ..
                                                    LoginRoot_SubChannel ..
                                                        "&pid=" ..
                                                            AppConst.SdkChannel .. --LoginManager.pt_pId
                                                                "&gid=" ..
                                                                    AppConst.SdkPackageName .. --LoginManager.pt_gId
                                                                        "&version=" .. LoginRoot_PackageVersion
        )
        networkMgr:SendGetHttp(
            LoginRoot_Url ..
                "tk/getUserInfo?openId=" ..
                    AppConst.OpenId ..
                        "&serverId=" ..
                            LoginManager.ServerId ..
                                "&token=" ..
                                    AppConst.MiTokenStr ..
                                        "&platform=" ..
                                            1 ..
                                                "&sub_channel=" ..
                                                    LoginRoot_SubChannel ..
                                                        "&pid=" ..
                                                            AppConst.SdkChannel .. --LoginManager.pt_pId
                                                                "&gid=" ..
                                                                    AppConst.SdkPackageName .. --LoginManager.pt_gId
                                                                        "&version=" .. LoginRoot_PackageVersion,
            this.OnReceiveLogin,
            nil,
            nil,
            nil
        )
    else
        Log(
            LoginRoot_Url ..
                "tk/getUserInfo?openId=" ..
                    LoginManager.openId ..
                        "&serverId=" ..
                            LoginManager.ServerId ..
                                "&token=" ..
                                    LoginManager.token ..
                                        "&platform=4" ..
                                            "&sub_channel=" ..
                                                LoginRoot_SubChannel .. "&version=" .. LoginRoot_PackageVersion
        )

        networkMgr:SendGetHttp(
            LoginRoot_Url ..
                "tk/getUserInfo?openId=" ..
                    LoginManager.openId ..
                        "&serverId=" ..
                            LoginManager.ServerId ..
                                "&token=" ..
                                    LoginManager.token ..
                                        "&platform=4" ..
                                            "&sub_channel=" ..
                                                LoginRoot_SubChannel .. "&version=" .. LoginRoot_PackageVersion,
            this.OnReceiveLogin,
            nil,
            nil,
            nil
        )
    end
end

function this.OnDisconnect(network)
    RequestPanel.Hide()
    PopupTipPanel.ShowTipByLanguageId(11126)
end

function this.SetLoginPart(flag)
    this.loginPart:SetActive(flag)
end

function this.SubmitGameData()
    CustomEventManager.GameCustomEvent("进入服务器")
    local isNewRole = PlayerPrefs.GetString(tostring(PlayerManager.uid), "")
    if isNewRole == "" then
        PlayerPrefs.SetString(tostring(PlayerManager.uid), tostring(PlayerManager.uid))
        SubmitExtraData({type = SDKSubMitType.TYPE_CREATE_ROLE})
    end
    SubmitExtraData({type = SDKSubMitType.TYPE_ENTER_GAME})
end

return LoginPanel
