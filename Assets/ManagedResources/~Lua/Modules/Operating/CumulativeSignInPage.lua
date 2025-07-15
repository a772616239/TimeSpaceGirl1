--[[
 * @ClassName CumulativeSignInPage
 * @Description 累计签到
 * @Date 2019/8/1 20:07
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class CumulativeSignInPage
local CumulativeSignInPage = quick_class("CumulativeSignInPage")
--最大天数
local kMaxDay = 31
--已领取 再领一次
local receiveImage = {[1] = "cn2-x1_TB_duihao", [2] = GetPictureFont("cn2-X1_tongyong_zailingyici")}
--本地标记可领取次数
local receiveNum = 0
--今日是否充值标记 1未充值 2已充值
local rechargeNum = 0
--是否首次打开页面
local isFirstOn = true

function CumulativeSignInPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject

    self.signInContent = Util.GetGameObject(self.gameObject, "signList/viewPort/content")
    self.signInItem = Util.GetGameObject(self.signInContent, "signInItem")
    self.signInItem:SetActive(false)
    self.signInList = {}
    self.signInRewardList = {}
end

local sortingOrder = 0
function CumulativeSignInPage:OnShow(_sortingOrder)
    isFirstOn = true
    sortingOrder = _sortingOrder
    Game.GlobalEvent:AddEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, self.RefreshPanel, self)
    self.gameObject:SetActive(true)
    self:RefreshPanel()
end

function CumulativeSignInPage:OnHide()
    self.gameObject:SetActive(false)
    Game.GlobalEvent:RemoveEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, self.RefreshPanel, self)
end

function CumulativeSignInPage:RefreshPanel()
    self.SignData = OperatingManager.GetSignInData()
    if table.nums(self.signInList) <= 0 then
        self:CreateSignList()
    end
    self:RefreshSignList()

    if isFirstOn then
        isFirstOn = false
        DelayCreation(self.signInList)
    end
end

function CumulativeSignInPage:OnSortingOrderChange(cursortingOrder)
    if self.signInRewardList then
        for i = 1, #self.signInRewardList do
            self.signInRewardList[i]:SetEffectLayer(cursortingOrder)
        end
    end
end

--创建List
function CumulativeSignInPage:CreateSignList()
    local time = os.date("*t", GetTimeStamp())
    local y = time.year
    local m = time.month
    if m == 1 or m == 3 or m == 5 or m == 7 or m == 8 or m == 10 or m == 12 then
        kMaxDay = 31
    elseif m == 4 or m == 6 or m == 9 or m == 11 then
        kMaxDay = 30
    elseif m == 2 and (y % 400 == 0 or (y % 4 == 0 and y % 100 ~= 0)) then
        kMaxDay = 29
    else
        kMaxDay = 28
    end

    for i = 1, kMaxDay do
        self.signInList[i] = newObjToParent(self.signInItem, self.signInContent)
        self.signInList[i].gameObject.name = "signInReward_"..i
        self.signInRewardList[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(self.signInList[i], "rewardPos").transform)
    end
    table.walk(self.signInList, function(signInItem)
        signInItem:SetActive(false)
    end)
end

--刷新List
function CumulativeSignInPage:RefreshSignList()
    receiveNum = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.DAY_SIGN_IN)
    rechargeNum = PrivilegeManager.GetPrivilegeNumber(PRIVILEGE_TYPE.DAY_SIGN_IN)
    CheckRedPointStatus(RedPointType.CumulativeSignIn)

    table.walk(self.signInList, function(signInItem)
        signInItem:SetActive(false)
    end)

    --控制添加点击事件
    -- local _month = 1--math.floor(os.date("%m", GetTimeStamp())) 
    local signInConfigs = ConfigManager.GetConfig(ConfigName.SignInConfig)--, "Month", _month)
    local i = 0
    for _, signInfo in ConfigPairs(signInConfigs) do
        i = i + 1
        local day = i
        if day <= kMaxDay then
            Util.AddOnceClick(Util.GetGameObject(self.signInList[i], "receiveBtn"), function()
                self:OnSignInClicked(signInfo.Id, day)
            end)
            self.signInRewardList[i]:OnOpen(false, signInfo.reward, 1, false, false, false, sortingOrder)
            self.signInList[i]:SetActive(true)
        end
    end

    -- local dayIndexEnd
    -- if self.SignData.state == 0 then--可领取
    --     dayIndexEnd = self.SignData.days
    -- else
    --     dayIndexEnd = self.SignData.days + 1
    -- end
    -- dayIndexEnd = dayIndexEnd >= kMaxDay and kMaxDay or dayIndexEnd

    ------------------以前------------------
    for i, signInItem in ipairs(self.signInList) do
        if i < self.SignData.days then
            self:SetIcon(1, self.signInList[i])--默认已过去的天数都赋值已领取图片
        end
        Util.GetGameObject(signInItem, "received"):SetActive(i < self.SignData.days)--已过天数显示已领取
        Util.GetGameObject(signInItem, "receiveBtn"):SetActive(i < self.SignData.days)--已过天数开启按钮点击事件
    end

    ------------------今天------------------
    -- --当已第一次签到设置图片                       已领取未充值                                已充值已领取
    -- if self.SignData.state == 1 and ((receiveNum == 0 and rechargeNum == 1) or (receiveNum == 1 and rechargeNum == 2)) then
    --     self:SetIcon(2, self.signInList[self.SignData.days])
    --     Util.GetGameObject(self.signInList[self.SignData.days], "redPoint"):SetActive(self:CheckRedPoint())--红点显隐
    --     Util.GetGameObject(self.signInList[self.SignData.days], "receiveBtn"):SetActive(self:CheckIsReceive())--该奖励按钮是否可点击
    -- else
    -- end
    if self.SignData.state == 1 then
        if receiveNum == 0 and rechargeNum == 1 then
            self:SetIcon(2, self.signInList[self.SignData.days])
        elseif receiveNum == 0 and rechargeNum == 2 then
            self:SetIcon(1, self.signInList[self.SignData.days])

        end
        Util.GetGameObject(self.signInList[self.SignData.days], "received"):SetActive(true)
    end
    for i = 1, #self.signInList do
        if i < self.SignData.days then
            Util.GetGameObject(self.signInList[i], "redPoint"):SetActive(false)
        end 
    end
    Util.GetGameObject(self.signInList[self.SignData.days], "redPoint"):SetActive(self:CheckRedPoint())--红点显隐
    Util.GetGameObject(self.signInList[self.SignData.days], "receiveBtn"):SetActive(self:CheckIsReceive())--该奖励按钮是否可点击

    -- if dayIndexEnd >= 25 then
    --     self.signInContent.transform.anchoredPosition3D = Vector3(0, 150, 0)
    -- end
end

--点击事件
function CumulativeSignInPage:OnSignInClicked(Id, index)
    if index < self.SignData.days then
        PopupTipPanel.ShowTipByLanguageId(10350)
    elseif index == self.SignData.days then
        if receiveNum > 0 then
            NetManager.RequestSignIn(Id, function(respond)
                PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.DAY_SIGN_IN,1)--本地刷新下次数
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1)
                OperatingManager.SetSignInData({
                    days = index,
                    state = 1
                })
                self.SignData.state = 1
                -- Util.GetGameObject(self.signInList[index], "redPoint"):SetActive(false)
                self:RefreshSignList()
            end)
        elseif receiveNum == 0 and rechargeNum == 1 then--已领取未充值 
            MsgPanel.ShowTwo(GetLanguageStrById(11446), function()end, function()
                -- JumpManager.GoJump(27001)
                if not ShopManager.SetMainRechargeJump() then
                    JumpManager.GoJump(36008)
                else
                    JumpManager.GoJump(36006)
                end
            end, GetLanguageStrById(10719), GetLanguageStrById(10023),nil, false)
        else
            PopupTipPanel.ShowTipByLanguageId(10350)--已领取
        end
    else
        PopupTipPanel.ShowTipByLanguageId(11447)--未达到签到天数
    end
end

--检查是否可领取 当未第一次签到 或 第一次签到后 （未充值 本地领取次数为0）或（已充值 今天有领取次数）
function CumulativeSignInPage:CheckIsReceive()
    return self.SignData.state == 0 or (self.SignData.state == 1 and ((receiveNum == 0 and rechargeNum == 1) or (receiveNum == 1 and rechargeNum == 2)))
end

--检测红点
function CumulativeSignInPage:CheckRedPoint()
    return self.SignData.state == 0 or receiveNum > 0
end

--设置图片转换 index 1已领取 2再领一次
function CumulativeSignInPage:SetIcon(index, root)
    Util.GetGameObject(root, "received"):GetComponent("Image").sprite = Util.LoadSprite(receiveImage[index])
end

return CumulativeSignInPage