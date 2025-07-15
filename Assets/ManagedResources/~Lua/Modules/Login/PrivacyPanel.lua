require("Base/BasePanel")
PrivacyPanel = Inherit(BasePanel)
local this = PrivacyPanel
-- local languageID = {
--     {GetLanguageStrById(91001562), GetLanguageStrById(91001565)},--用户协议
--     {GetLanguageStrById(91001563), GetLanguageStrById(91001566)},--隐私政策
--     {GetLanguageStrById(91001564), GetLanguageStrById(91001567)},--儿童个人信息保护指引
-- }

function this:InitComponent()
    this.btnRefuse = Util.GetGameObject(this.gameObject, "panel/btns/btnRefuse")--拒绝
    this.btnAgree = Util.GetGameObject(this.gameObject, "panel/btns/btnAgree")--同意
    this.btnBack = Util.GetGameObject(this.gameObject, "panel/btns/btnBack")--返回

    this.title = Util.GetGameObject(this.gameObject, "panel/Scroll View/Viewport/Content/title"):GetComponent("Text")

    this.txt = {}
    for i = 1, 3 do
        this.txt[i] = Util.GetGameObject(this.gameObject, "panel/Scroll View/Viewport/Content/Text"..i)
        -- this.txt[i]:GetComponent("Text").text = languageID[i][2]
        this.txt[i]:GetComponent("Text").text = GetLanguageStrById(GetChannerConfig().Text_PrivacyAgreement_id[i][2])
    end

    this.btns = {}
    for i = 1, 3 do
        this.btns[i] = Util.GetGameObject(this.gameObject, "panel/btns").transform:GetChild(i-1)
    end
end

function this:BindEvent()
    Util.AddClick(this.btnAgree, function ()
        -- PlayerPrefs.SetInt("IsAgreePrivacy", 1)
        -- Game.GlobalEvent:DispatchEvent(GameEvent.LoginSuccess.OnAgreePrivacy)
        self:ClosePanel()
        -- if this.func then
        --     this.func()
        -- end
    end)
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnRefuse, function ()
    --     PlayerPrefs.SetInt("IsAgreePrivacy", 0)
    --     Game.GlobalEvent:DispatchEvent(GameEvent.LoginSuccess.OnAgreePrivacy)
    --     self:ClosePanel()
        UIManager.OpenPanel(UIName.PermissionPanel, 2)
    end)

    for i = 1, #this.btns do
        Util.AddClick(this.btns[i].gameObject, function ()
            this.ChangeBtnState(i)
        end)
    end
end

function this:OnOpen(isShowBtnRefuse, func)
    this.ChangeBtnState(1)
    this.func = func
    this.btnRefuse:SetActive(not isShowBtnRefuse)
    this.btnBack:SetActive(isShowBtnRefuse)
    this.btnAgree:SetActive(not isShowBtnRefuse)
end

function this:OnClose()
end

function this.ChangeBtnState(i)
    for i = 1, #this.btns do
        Util.GetGameObject(this.btns[i], "Text"):GetComponent("Text").color = Color.New(0/255, 0/255, 0/255, 204/255)
        this.txt[i]:SetActive(false)
    end
    Util.GetGameObject(this.btns[i], "Text"):GetComponent("Text").color = Color.New(227/255, 78/255, 78/255, 204/255)
    this.title.text = GetLanguageStrById(GetChannerConfig().Text_PrivacyAgreement_id[i][1])
    -- this.title.text = languageID[i][1]
    this.txt[i]:SetActive(true)
end

return this