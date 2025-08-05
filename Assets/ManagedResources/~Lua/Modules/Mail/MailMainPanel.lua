require("Base/BasePanel")
MailMainPanel = Inherit(BasePanel)
local this = MailMainPanel
local allMail
local openPanel
local allGetMail
local allDrop = {}
-- local isFirstOn = true--是否首次打开页面

local _MailSprite = {[0] = "cn2-x1_youjian_youjiantubiao_01", 
                    [1] = "cn2-x1_youjian_youjiantubiao_02", 
                    [2] = "cn2-x1_youjian_youjiantubiao_03", 
                    [3] = "cn2-x1_youjian_youjiantubiao_04"}

local _statusBg = {[0] = "cn2-X1_tongyong_wenziqipao_01",
                [1] = "cn2-X1_tongyong_wenziqipao_01"}

--初始化组件（用于子类重写）
function MailMainPanel:InitComponent()
    allGetMail = {}
    this.closeBtn = Util.GetGameObject(self.gameObject, "bg/closeBtn")
    this.mialNum = Util.GetGameObject(self.gameObject, "bg/mialNum"):GetComponent("Text")
    this.DeleMialText = Util.GetGameObject(self.gameObject, "bg/DeleMialText"):GetComponent("Text")
    this.mailPre = Util.GetGameObject(self.gameObject, "mailPre")
    this.GetAllMailBtn = Util.GetGameObject(self.gameObject, "GetAllMailBtn")
    this.DelReadMailBtn = Util.GetGameObject(self.gameObject, "DelReadMailBtn")
    this.ScrollBar = Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    this.Scroll = Util.GetGameObject(self.gameObject,"scroll")

    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.gameObject.transform,
            this.mailPre, this.ScrollBar, Vector2.New(w, h), 1, 1, Vector2.New(0,10))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(-5,12)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function MailMainPanel:BindEvent()
    Util.AddClick(this.closeBtn, function()
        self:ClosePanel()
        Game.GlobalEvent:DispatchEvent(GameEvent.MianGuide.RefreshGuide)
    end)
    Util.AddClick(this.GetAllMailBtn, function()
        allGetMail = {}
        for i = 1, #allMail do
            if allMail[i].state < 3 and allMail[i].mailItem ~= "" then
                table.insert(allGetMail,allMail[i].mailId)
            end
        end
        if allGetMail and #allGetMail > 0 then
            this.GetMailData3()
            NetManager.RequestVipLevelUp(function()end)
        else
            PopupTipPanel.ShowTipByLanguageId(11145)
        end
    end)
    Util.AddClick(this.DelReadMailBtn, function()
        local  DelMails = {}
        for i = 1, #allMail do
            if allMail[i].state >= 1 and allMail[i].mailItem == "" then--已读取 未领取 无附件
                table.insert(DelMails,allMail[i].mailId)
            elseif allMail[i].state >= 3 then--已领取
                table.insert(DelMails,allMail[i].mailId)
            end
        end
        if DelMails and #DelMails > 0 then
            this.DelMailData(DelMails)
        else
            PopupTipPanel.ShowTipByLanguageId(11146)
        end
    end)
end
function this.DelMailData(DelMails)
    if DelMails and #DelMails > 0 then
        NetManager.DelMailData(DelMails,function ()
            for i = 1, #DelMails do
                MailManager.DelSingleMial(DelMails[i])
            end
            this.UpdateMailData()
        end)
    end
end
function this.GetMailData(index)
    if index > 0 then
        NetManager.GetSingleMailRewardData({allGetMail[index]},function (_drop)
            MailManager.UpdataMialIsReadState(allGetMail[index],3)
            UIManager.OpenPanel(UIName.RewardItemPopup,_drop,1,function()
                if UIManager.IsOpen(UIName.PatFacePanel) then--如果弹星级成长礼 就会打断所有邮件的领取
                    this.UpdateMailData()
                else
                    this.GetMailData(index-1)
                end
            end)
        end)
    else
        this.UpdateMailData()
    end
end

function this.GetMailData3()
    NetManager.GetSingleMailRewardData(allGetMail,function (_drop)
        for index = 1, #allGetMail do
            MailManager.UpdataMialIsReadState(allGetMail[index],3)
        end
        UIManager.OpenPanel(UIName.RewardItemPopup,_drop,1)
        this.UpdateMailData()
    end)
end

--添加事件监听（用于子类重写）
function MailMainPanel:AddListener()

end

--移除事件监听（用于子类重写）
function MailMainPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MailMainPanel:OnOpen(...)
    local data = {...}
    openPanel = data[1]
end

function MailMainPanel:OnShow()
    -- isFirstOn = true
    allMail = {}
    NetManager.GetAllMailData(function ()
        this.OnShowMailListData(MailManager.mialDataList)
    end)
end
function this.CallBackOnShow()
    allMail = {}
    NetManager.GetAllMailData(function ()
        this.OnShowMailListData(MailManager.mialDataList)
    end)
end

local maildataCount = 0--数据数量
--设置英雄列表数据
function this.OnShowMailListData(_allMail)
    this.mailList = {}
    allMail = _allMail
    this:SortAllMail(allMail)
    maildataCount = #allMail
    this.mialNum.text = GetLanguageStrById(11147) .. maildataCount

    this.ScrollView:SetData(allMail, function (index, go)
        this.SingleMialDataShow(go, allMail[index])
        this.mailList[index] = go
    end)

    -- if isFirstOn then
        -- isFirstOn = false
        DelayCreation(this.mailList)
    -- end
end

function this.SingleMialDataShow(_go,_mailData)
    local mailImage = Util.GetGameObject(_go.transform, "mailImage"):GetComponent("Image")
    local StatusBg = Util.GetGameObject(_go.transform, "StatusBg"):GetComponent("Image")
    local Status = Util.GetGameObject(_go.transform, "Status"):GetComponent("Text")
	local getOk = Util.GetGameObject(_go.transform, "getOk")
    if _mailData.state == nil then
        _mailData.state = 0
    end
    --无附件
    if _mailData.mailItem == "" then
        if _mailData.state == 0 then--未读
            mailImage.sprite = Util.LoadSprite(_MailSprite[0])
            Status.text = GetLanguageStrById(12516)
            StatusBg.sprite = Util.LoadSprite(_statusBg[0])
			getOk :SetActive(false)
        elseif _mailData.state == 1 then--已读取
            -- LogError("已读无附件")
            mailImage.sprite = Util.LoadSprite(_MailSprite[3])
            Status.text = GetLanguageStrById(12517)
            StatusBg.sprite = Util.LoadSprite(_statusBg[1])
			getOk :SetActive(true)
        end
    else
        if _mailData.state == 0 then--未读
            mailImage.sprite = Util.LoadSprite(_MailSprite[1])
            Status.text = GetLanguageStrById(12516)
            StatusBg.sprite = Util.LoadSprite(_statusBg[0])
			getOk :SetActive(false)
        elseif _mailData.state == 1 then--已读取
            mailImage.sprite = Util.LoadSprite(_MailSprite[2])
            Status.text = GetLanguageStrById(12517)
            StatusBg.sprite = Util.LoadSprite(_statusBg[1])
			getOk :SetActive(false)
        elseif _mailData.state == 2 then--未领取
            mailImage.sprite = Util.LoadSprite(_MailSprite[2])
            Status.text = GetLanguageStrById(12518)
            StatusBg.sprite = Util.LoadSprite(_statusBg[1])
			getOk :SetActive(false)
        elseif _mailData.state == 3 then--已领取
            mailImage.sprite = Util.LoadSprite(_MailSprite[3])
            Status.text = GetLanguageStrById(50135)
            StatusBg.sprite = Util.LoadSprite(_statusBg[1])
			getOk :SetActive(true)
        end
    end
    Util.GetGameObject(_go.transform, "infoText"):GetComponent("Text").text = GetMailConfigDesc(_mailData.head,_mailData.mailparam)
    Util.GetGameObject(_go.transform, "sendText"):GetComponent("Text").text = GetTimeStrBySeconds(_mailData.sendTime)--GetLanguageStrById(11149).._mailData.sendName
    local mialBtn = Util.GetGameObject(_go.transform, "Imagebg")
    Util.AddOnceClick(mialBtn, function()
        if _mailData.state == 0 then--未读
            NetManager.ReadSingleMailData(_mailData.mailId,function ()
                MailManager.UpdataMialIsReadState(_mailData.mailId,1)

                this.UpdateMailData()
            end)
        end
        UIManager.OpenPanel(UIName.MainSingleInfoPanel,_mailData,this)
    end)
    Util.GetGameObject(_go.transform, "mialRedPoint"):SetActive( _mailData.state==0)
end
function this.UpdateMailData()
    this.OnShowMailListData(MailManager.mialDataList)
end
--界面关闭时调用（用于子类重写）
function MailMainPanel:OnClose()
    if openPanel then
        openPanel.RefreshRedPoint()
    end
    if IsNull (this.mailList) then
        return
    end 
    for index, value in ipairs(this.mailList) do
        value:SetActive(false)
    end
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

--界面销毁时调用（用于子类重写）
function MailMainPanel:OnDestroy()
    this.ScrollView = nil
end

function MailMainPanel:SortAllMail(allMail)
    table.sort(allMail, function(a,b)
        --return a.state < b.state
        if a.state == b.state then
            return a.sendTime > b.sendTime
        else
            return a.state < b.state
        end
    end)
end

return MailMainPanel