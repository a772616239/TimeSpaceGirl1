require("Base/BasePanel")
MainSingleInfoPanel = Inherit(BasePanel)
local mailData
local openPanel
local allGetMail = {}
local goList = {}
-- local hasGot = false
-- local activeNum = 0
--item容器
local itemGoList = {}
local _ItemList = {}
local rewardStr
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

--初始化组件（用于子类重写）
function MainSingleInfoPanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.gameObject, "bg/btnBack")
    self.BackMask = Util.GetGameObject(self.gameObject, "BackMask") --m5
    self.mialHead = Util.GetGameObject(self.gameObject, "bg/mialHead"):GetComponent("Text")
    self.mialId = Util.GetGameObject(self.gameObject, "bg/mialHead/id"):GetComponent("Text")
    self.mialTimeText = Util.GetGameObject(self.gameObject, "bg/mialTimeText"):GetComponent("Text")
    self.mialInfo = Util.GetGameObject(self.gameObject, "bg/mialInfo/mialInfoText"):GetComponent("Text")
    self.itemPre = Util.GetGameObject(self.gameObject, "itemPre")
    self.grid = Util.GetGameObject(self.gameObject, "bg/scroll/grid")
    self.btnSure = Util.GetGameObject(self.gameObject, "btn/btnSure")
    self.btnDel = Util.GetGameObject(self.gameObject, "btn/btnDel")
    self.root = Util.GetGameObject(self.gameObject, "bg/newScroll")
    self.time = Util.GetGameObject(self.gameObject,"bg/time"):GetComponent("Text")
    local v21 = Util.GetGameObject(self.gameObject, "bg/newScroll"):GetComponent("RectTransform").rect
    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "bg/newScroll").transform,
            self.itemPre, nil, Vector2.New(v21.width, v21.height), 2, 1, Vector2.New(40,0),0.8)
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1--height width  -v21.x*2, -v21.y*2
end

--绑定事件（用于子类重写）
function MainSingleInfoPanel:BindEvent()

    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.BackMask, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.btnSure, function()
        local getHeroNum = 0   --获得的英雄数量
        for i, v in ipairs(rewardStr) do
            if itemConfig[v[1]].ItemType == 1 then
                getHeroNum = getHeroNum + v[2]
            end
        end
        if getHeroNum ~= 0 then
            --判断英雄是否满
            NetManager.BackpackLimitRequest(function(msg)
                local heroNum = #HeroManager.GetAllHeroDatasAndZero()
                local limit = msg.backpackLimitCount
                --特殊判断空位必须多一格才能领取
                --[[
                                if heroNum + getHeroNum + 1 > limit then
                                PopupTipPanel.ShowTipByLanguageId(50263)
                                return
                            end
                ]]
               
                if heroNum + getHeroNum <= limit then
                    allGetMail = {}
                    table.insert(allGetMail,mailData.mailId)
                    IndicationManager.getRewardFromMail = true
                    NetManager.GetSingleMailRewardData(allGetMail,function (_drop)
                        UIManager.OpenPanel(UIName.RewardItemPopup,_drop,1,function()
                        end)
                        self:CallBackEvent()
                    end)
                else
                    PopupTipPanel.ShowTipByLanguageId(10671)
                end
            end)
        else
            allGetMail = {}
            table.insert(allGetMail,mailData.mailId)
            IndicationManager.getRewardFromMail = true
            NetManager.GetSingleMailRewardData(allGetMail,function (_drop)
                UIManager.OpenPanel(UIName.RewardItemPopup,_drop,1,function()
                end)
                NetManager.RequestVipLevelUp(function()end)
                self:CallBackEvent()
            end)
        end
    end)
    Util.AddClick(self.btnDel, function()
        if mailData.state >= 1 and mailData.mailItem == "" then--已读取 未领取 无附件
            NetManager.DelMailData({mailData.mailId},function ()
                MailManager.DelSingleMial(mailData.mailId)
            end)
        elseif mailData.state >= 3 then--已领取
            NetManager.DelMailData({mailData.mailId},function ()
                MailManager.DelSingleMial(mailData.mailId)
            end)
        end
        self.btnDel:SetActive(false)
        openPanel.CallBackOnShow()
        self:ClosePanel()
    end)
end
function MainSingleInfoPanel:CallBackEvent()
    if IndicationManager.canPopUpBagMaxMessage == false then
        for i = 1, #allGetMail do
            MailManager.UpdataMialIsReadState(allGetMail[i],3)
        end
        openPanel.UpdateMailData()
        self.btnSure:SetActive(false)
        self.btnDel:SetActive(true)

        local grid = Util.GetGameObject(self.ScrollView.gameObject,"grid")
        for i = 1, grid.transform.childCount do
            Util.GetGameObject(grid.transform:GetChild(i-1).gameObject,"Received"):SetActive(true)
            Util.GetGameObject(grid.transform:GetChild(i-1).gameObject,"Received").transform:SetAsLastSibling()
        end
    end
end
--添加事件监听（用于子类重写）
function MainSingleInfoPanel:AddListener()

end

--移除事件监听（用于子类重写）
function MainSingleInfoPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MainSingleInfoPanel:OnOpen(...)
    local data = {...}
    mailData = data[1]
    openPanel = data[2]
    -- hasGot = mailData.state >= 3

end
function MainSingleInfoPanel:OnShow()
    self:OnShowMailData(mailData)
end

local mailList = {}
local mailmaxNum = 500
local maildataCount = 0--数据数量

function TimeAgo(t)
    local _sec = t % 60
    local allMin = math.floor(t / 60)
    local _min = allMin % 60
    local _hour = math.floor(allMin / 60)

    if _hour > 0 then
        return string.format("%02d" .. GetLanguageStrById(50134), _hour), _hour
    elseif _min > 0 then
        return string.format("%02d" .. GetLanguageStrById(50131), _min), _min
    else
        return string.format("%02d" .. GetLanguageStrById(50132), _sec), _sec
    end
end

--设置邮件数据
function MainSingleInfoPanel:OnShowMailData(mailData)
    self.mialHead.text = GetMailConfigDesc(mailData.head,mailData.mailparam)
    self.mialId.text = GetLanguageStrById(50227).." "..mailData.mailId

    if mailData.effectiveTime == 0 then
        self.mialTimeText.text = ""
    else
        self.mialTimeText.text = GetTimeStrBySeconds(mailData.effectiveTime + mailData.sendTime)..GetLanguageStrById(11151)
    end
    self.time.text = TimeAgo(GetTimeStamp() - mailData.sendTime) .. GetLanguageStrById(50133)
    self.mialInfo.text = GetMailConfigDesc(mailData.content,mailData.mailparam)--string.gsub(mailData.content, "\\n", "\n")
    self.btnDel:SetActive(false)
    if mailData.state == 3 then
        self.btnSure:SetActive(false)
        self.btnDel:SetActive(true)
    else
        if mailData.mailItem == "" or mailData.mailItem == nil then
            maildataCount = 0
            self.btnSure:SetActive(false)
            self.btnDel:SetActive(true)
        else
            self.btnSure:SetActive(true)
        end
    end
    local itemList = string.split(mailData.mailItem,"|")
    --maildataCount = #itemList
    --

    --local haveCount = LengthOfTable(mailList)--已经拥有预设的数量
    --local needCreatCount =  ( maildataCount>mailmaxNum and mailmaxNum ) or maildataCount--需要加载预设的数量；
    --local trueCreatCount = needCreatCount - haveCount--实际应该加载预设的数量
    --if trueCreatCount > 0 then
    --    for i = 1, trueCreatCount do
    --        local go = newObjToParent(self.itemPre, self.grid)
    --        local view = SubUIManager.Open(SubUIConfig.ItemView, go.transform)
    --        table.insert(mailList, view)
    --        table.insert(goList, go)
    --        Util.GetGameObject(go, "Image").transform:SetAsLastSibling()
    --    end
    --end
    --haveCount = LengthOfTable(mailList)
    --for i = 1, haveCount do
    --    if i <= needCreatCount then
    --        if itemList and itemList[i] ~= "" then
    --            local rewardStr = string.split(itemList[i],"#")
    --            local itemData = {}
    --            table.insert(itemData,tonumber(rewardStr[1]))
    --            table.insert(itemData,tonumber(rewardStr[2]))
    --            mailList[i]:OnOpen(false,itemData,1)--,false,false,false,self.sortingOrder
    --            Util.GetGameObject(goList[i], "Image"):SetActive(hasGot)
    --            activeNum = activeNum + 1
    --            mailList[i].gameObject:SetActive(true)
    --        else
    --            mailList[i].gameObject:SetActive(false)
    --            Util.GetGameObject(goList[i], "Image"):SetActive(false)
    --        end
    --    else
    --        mailList[i].gameObject:SetActive(false)
    --        Util.GetGameObject(goList[i], "Image"):SetActive(false)
    --    end
    --end
    rewardStr = {}
    for i = 1, #itemList do
        if itemList[i] ~= "" then
            local singlerewardStr = string.split(itemList[i],"#")
            local itemData = {}
            table.insert(itemData,tonumber(singlerewardStr[1]))
            table.insert(itemData,tonumber(singlerewardStr[2]))
            table.insert(rewardStr,itemData)
        end
    end
    self.ScrollView:SetData(rewardStr, function (index, go)
        self:SingleMailDataShow(go, rewardStr[index])
    end)
end
function MainSingleInfoPanel:SingleMailDataShow(go, rewardStr)
    if not _ItemList[go] then
        _ItemList[go] = SubUIManager.Open(SubUIConfig.ItemView, go.transform)
    end
    _ItemList[go]:OnOpen(false,rewardStr,1,false,false,false,self.sortingOrder)
    if self.btnDel.gameObject.activeSelf then
        Util.GetGameObject(go,"Received"):SetActive(true)
        Util.GetGameObject(go,"Received").transform:SetAsLastSibling()
    else
        Util.GetGameObject(go,"Received"):SetActive(false)
    end
end

--界面关闭时调用（用于子类重写）
function MainSingleInfoPanel:OnClose()
    -- hasGot = false
    -- activeNum = 0
end

--界面销毁时调用（用于子类重写）
function MainSingleInfoPanel:OnDestroy()
    _ItemList = {}
    mailList = {}
    goList = {}
end

return MainSingleInfoPanel