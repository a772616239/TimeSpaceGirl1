local SettingInfo = quick_class("SettingInfo")
local this = SettingInfo

local dropDownList = {}

function SettingInfo:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    -- self:BindEvent()
end
--初始化组件（用于子类重写）
function SettingInfo:InitComponent(gameObject)
    --头像
    this.head = Util.GetGameObject(gameObject, "playerInfo/head")
    this.headpos = Util.GetGameObject(gameObject, "playerInfo/head/pos")
    this.headRedpot = Util.GetGameObject(gameObject, "playerInfo/head/redpot")

    this.name = Util.GetGameObject(gameObject, "playerInfo/name/Text"):GetComponent("Text")
    this.btnChangeName = Util.GetGameObject(gameObject, "playerInfo/name/Image/btn")

    this.uidText = Util.GetGameObject(gameObject, "playerInfo/uid/Text"):GetComponent("Text")--uid
    this.guildText = Util.GetGameObject(gameObject, "playerInfo/guild/Text"):GetComponent("Text")--公会
    this.gridText = Util.GetGameObject(gameObject, "playerInfo/grid/Text"):GetComponent("Text")--等级
    -- this.idText = Util.GetGameObject(gameObject, "playerInfo/id/Text"):GetComponent("Text")
    -- this.serverText = Util.GetGameObject(gameObject, "playerInfo/server/Text"):GetComponent("Text")

    --声音
    this.BGMSlider = Util.GetGameObject(gameObject, "setting/BGMSlider"):GetComponent("Slider")
    -- this.BGMSliderValue = Util.GetGameObject(gameObject, "setting/BGMSlider/count"):GetComponent("Text")
    this.SoundSlider = Util.GetGameObject(gameObject, "setting/SoundSlider"):GetComponent("Slider")
    -- this.SoundSliderValue = Util.GetGameObject(gameObject, "setting/SoundSlider/count"):GetComponent("Text")

    -- this.btnOneKeyCopy = Util.GetGameObject(gameObject, "setting/oneKeyCopy")
    this.btnChangeLogin = Util.GetGameObject(gameObject, "btn/changelogin")--切换账号
    this.btnCdKey = Util.GetGameObject(gameObject, "btn/cdkey")--兑换码
    this.btnCustomerService = Util.GetGameObject(gameObject, "btn/customerService")--客服中心
    this.btnRelation = Util.GetGameObject(gameObject, "btn/relation")--账号关联
    this.btnAccountCancellation = Util.GetGameObject(gameObject, "btn/accountCancellation")--账号注销
    -- this.submit = Util.GetGameObject(gameObject, "btn/submit")--上报战斗日志
    this.bind = Util.GetGameObject(gameObject, "btn/bind")--绑定
    this.community = Util.GetGameObject(gameObject, "btn/community")--社区

    --切换语言
    this.multiLanguageDropDown = Util.GetGameObject(gameObject,"setting/multiLanguage"):GetComponent("Dropdown")
    this.multiLanguageDropDownText = Util.GetGameObject(gameObject,"setting/multiLanguage/Label"):GetComponent("Text")
    if not Switch_MultiLanguage then
        this.multiLanguageDropDown.gameObject:SetActive(false)
    end

    --显隐VIP
    this.showVip = Util.GetGameObject(gameObject, "playerInfo/showVip/yes")
    this.noShowVip = Util.GetGameObject(gameObject, "playerInfo/showVip/no")
end

--绑定事件（用于子类重写）
function SettingInfo:BindEvent()
    if Switch_MultiLanguage then
        this.multiLanguageDropDown.onValueChanged:AddListener(
        function(value)
            local lanId
            for k, v in pairs(dropDownList) do
                if v == value then
                    lanId = k
                end
            end

            PlayerPrefs.SetInt("multi_language_temp", lanId)
            if lanId == GetCurLanguage() then
                return
            end

            local multiLanguageData = G_MultiLanguage[lanId]
            MsgPanel.ShowTwo(string.format(GetLanguageStrById(50332), multiLanguageData.Lang_Show),function()
                this.SetMultiLanguageUI(GetCurLanguage())
            end,function()
                local selectLan = PlayerPrefs.GetInt("multi_language_temp", 0)
                PlayerPrefs.SetInt("multi_language", selectLan)
                if LanguageID2LanID(selectLan) ~= 0 then
                    if LanguageID2LanID(selectLan) == 1 then
                        PlayerPrefs.SetInt("multi_language_ResOpen_en", 1)
                    elseif LanguageID2LanID(selectLan) == 2 then
                    end
                end
                Game.Logout()
            end,GetLanguageStrById(10719),GetLanguageStrById(10720),"",false,"")
        end)
    end
    --绑定
    Util.AddClick(this.bind, function()
        if AppConst.isSDKLogin then
            SDKMgr:Bind()
        end
    end)
    --社区
    Util.AddClick(this.community, function()
        if AppConst.isSDKLogin then
            SDKMgr:Community()
        end
    end)
    --客服中心
    Util.AddClick(this.btnCustomerService,function()
        if AppConst.isSDKLogin then
            SDKMgr:CustomerService()
        end
    end)
    --账户关联
    Util.AddClick(this.btnRelation,function()
        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Binding)
    end)
    --账号注销
    Util.AddClick(this.btnAccountCancellation,function()
        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Reconfirm, GetLanguageStrById(50238), GetLanguageStrById(50246), function ()
            if AppConst.isSDKLogin then
                SDKMgr:Cancellation()
            end
        end)
    end)
    -- Util.AddOnceClick(this.submit, function()
        --     BattleRecordManager.SubmitBattleRecord()
    -- end)
    
    --兑换码
    Util.AddClick(this.btnCdKey, function()
        UIManager.OpenPanel(UIName.CDKeyExchangePanel)
    end)

    Util.AddClick(this.head, function()
        UIManager.OpenPanel(UIName.HeadChangePopup)
    end)

    Util.AddClick(this.btnChangeName, function()
        UIManager.OpenPanel(UIName.CreateNamePopup)
    end)

    Util.AddSlider(this.BGMSlider.gameObject, function(go, value)
        SettingManager.SetSettingData(SETTING_TYPE.BGM_RATIO, value)
        -- this.BGMSliderValue.text = math.floor(value * 100)
    end)

    Util.AddSlider(this.SoundSlider.gameObject, function(go, value)
        SettingManager.SetSettingData(SETTING_TYPE.SOUND_RATIO, value)
        -- this.SoundSliderValue.text = math.floor(value * 100)
    end)
    --切换账号
    Util.AddClick(this.btnChangeLogin, function()
        MsgPanel.ShowTwo(GetLanguageStrById(11895), nil, function()
            if AppConst.isSDKLogin then
                SDKMgr:Logout()
            else
                Framework.Dispose()
                App.Instance:ReStart()
            end
        end)
    end)
    -- Util.AddClick(this.btnOneKeyCopy, function()
    --     if not UnityEngine.Application.isMobilePlatform then
    --         PopupTipPanel.ShowTipByLanguageId(11896)
    --         return
    --     end
    --     local str = GetLanguageStrById(11897) .. PlayerManager.serverInfo.name .. "\n" .. GetLanguageStrById(11898) .. PlayerManager.nickName ..
    --             "\n" .. GetLanguageStrById(11899) .. AppConst.OpenId .. "\n" .. GetLanguageStrById(11900) .. PlayerManager.uid
    --     AndroidDeviceInfo.Instance:SetCopyValue(str)
    --     PopupTipPanel.ShowTipByLanguageId(11901)
    -- end)
    Util.AddClick(this.showVip, function ()
        if PlayerManager.isShowVip then
            return
        end
        NetManager.SetVipShowRequest(true, function ()
            this:IsShowVip(true)
            PlayerManager.isShowVip = true
        end)
    end)
    Util.AddClick(this.noShowVip, function ()
        if not PlayerManager.isShowVip then
            return
        end
        NetManager.SetVipShowRequest(false, function ()
            this:IsShowVip(false)
            PlayerManager.isShowVip = false
        end)
    end)

    BindRedPointObject(RedPointType.Setting_Head, this.headRedpot)
end

--添加事件监听（用于子类重写）
function SettingInfo:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnHeadFrameChange, this.RefreshPlayerInfoShow)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnHeadChange, this.RefreshPlayerInfoShow)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnChangeName, this.RefreshPlayerInfoShow)
end

--移除事件监听（用于子类重写）
function SettingInfo:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnHeadFrameChange, this.RefreshPlayerInfoShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnHeadChange, this.RefreshPlayerInfoShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnChangeName, this.RefreshPlayerInfoShow)
end

--界面打开时调用（用于子类重写）
function SettingInfo:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SettingInfo:OnShow()
    this.RefreshPlayerInfoShow()
    this.BGMSlider.value = SettingManager.GetSettingData(SETTING_TYPE.BGM_RATIO)
    this.SoundSlider.value = SettingManager.GetSettingData(SETTING_TYPE.SOUND_RATIO)

    this.SetMultiLanguageUI()
    this:IsShowVip(PlayerManager.isShowVip)

    local channelConfig = GetChannerConfig()
    this.multiLanguageDropDown.gameObject:SetActive(channelConfig.Button_PlayerSet_Language)
    this.btnCdKey:SetActive(channelConfig.Button_PlayerSet_Exchange)
    this.btnRelation:SetActive(channelConfig.Button_PlayerSet_Relation)
    -- this.btnCustomerService:SetActive(channelConfig.Button_PlayerSet_Service)
    this.btnCustomerService:SetActive(false)
    this.btnAccountCancellation:SetActive(channelConfig.Button_PlayerSet_Cancellation)
    this.btnChangeLogin:SetActive(channelConfig.Button_switch)
end

function SettingInfo:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function SettingInfo:OnClose()
end

--界面销毁时调用（用于子类重写）
function SettingInfo:OnDestroy()
    --SubUIManager.Close(this.UpView)
    if this.playerHead then
        this.playerHead:Recycle()
        this.playerHead = nil
    end
    ClearRedPointObject(RedPointType.Setting_Head)
end

--刷新玩家信息
function this.RefreshPlayerInfoShow()
    if not this.playerHead then
        -- this.playerHead = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD, this.headpos)
        this.playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.headpos.transform)
    end
    this.playerHead:Reset()
    this.playerHead:SetHead(PlayerManager.head)
    this.playerHead:SetFrame(PlayerManager.frame)
    this.playerHead:SetScale(1)
    -- this.playerHead:SetLevel(PlayerManager.level)

    this.name.text = PlayerManager.nickName
    this.uidText.text = PlayerManager.uid
    local guildData = MyGuildManager.GetMyGuildInfo()
    this.guildText.text = guildData == nil and GetLanguageStrById(10094) or guildData.name
    this.gridText.text = PlayerManager.level

    -- this.exp.value = PlayerManager.exp / PlayerManager.userLevelData[PlayerManager.level].Exp
    -- this.expText.text = PlayerManager.exp .. "/" .. PlayerManager.userLevelData[PlayerManager.level].Exp
    -- this.idText.text = AppConst.OpenId or LoginManager.openId
    -- this.serverText.text = PlayerManager.serverInfo.name
end

--是否显示VIP
function SettingInfo:IsShowVip(isShow)
    Util.GetGameObject(this.showVip, "Image"):SetActive(isShow)
    Util.GetGameObject(this.noShowVip, "Image"):SetActive(not isShow)
    if isShow then
        Util.GetGameObject(this.showVip, "Text"):GetComponent("Text").color = UIColor.WHITE
        Util.GetGameObject(this.noShowVip, "Text"):GetComponent("Text").color = UIColor.GRAY
    else
        Util.GetGameObject(this.showVip, "Text"):GetComponent("Text").color = UIColor.GRAY
        Util.GetGameObject(this.noShowVip, "Text"):GetComponent("Text").color = UIColor.WHITE
    end
end

--设置切换语言
function SettingInfo.SetMultiLanguageUI(lanIdx)
    if not Switch_MultiLanguage then
        return
    end
    local flag = lanIdx or GetCurLanguage()
    local multiLanguageData = G_MultiLanguage[flag]
    this.multiLanguageDropDownText.text = multiLanguageData.Lang_Show

    -- if next(dropDownList) == nil then
        local idx = 0
        this.multiLanguageDropDown:ClearOptions()
        for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.MultiLanguage)) do
            local multiLanguageData = G_MultiLanguage[configInfo.Id]
            local option = UnityEngine.UI.Dropdown.OptionData.New()
            option.text = multiLanguageData.Lang_Show
            this.multiLanguageDropDown.options:Add(option)

            dropDownList[configInfo.Id] = idx
            idx = idx + 1
        end
    -- end

    this.multiLanguageDropDown.value = dropDownList[flag]
end

return SettingInfo