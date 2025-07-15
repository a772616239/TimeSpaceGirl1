require("Base/BasePanel")
CreateNamePopup = Inherit(BasePanel)
local this = CreateNamePopup
local boy = 1
local girl = 2

local boyLiveRes = "live2d_npc_map"
local girlLiveRes = "live2d_npc_map_nv"
local smallInfo = {[1] = {Pos = Vector3.New(-1, -81, 0), Scale = Vector3.New(0.25, 0.25, 0.25)},
                   [2] = {Pos = Vector3.New(-1, -81, 0), Scale = Vector3.New(0.125, 0.125, 0.125)},}

local bigInfo = {[1] = {Pos = Vector3.New(25, -3, 0), Scale = Vector3.New(0.3, 0.3, 0.3)},
                 [2] = {Pos = Vector3.New(100, 25, 0), Scale = Vector3.New(0.5, 0.5, 0.5)},}
local curLive
local lastChoose
local orginLayer = 0
local curSex = ROLE_SEX.BOY

--初始化组件（用于子类重写）
function CreateNamePopup:InitComponent()
    orginLayer = 0

    this.btnConfirm = Util.GetGameObject(self.gameObject, "Frame/btnConfirm")
    this.title = Util.GetGameObject(self.gameObject, "Frame/Title"):GetComponent("Text")
    this.textName = Util.GetGameObject(self.gameObject,"Frame/InputField"):GetComponent("InputField")
    this.btnRandName = Util.GetGameObject(self.gameObject, "Frame/randIcon")

    this.card = Util.GetGameObject(self.gameObject, "Frame/card")
    this.cardNum = Util.GetGameObject(self.gameObject, "Frame/card/num"):GetComponent("Text")
    this.btnAddCard = Util.GetGameObject(self.gameObject, "Frame/card/add")

    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.nameChangeRoot = Util.GetGameObject(self.gameObject, "Frame")
    this.createnameRoot = Util.GetGameObject(self.gameObject, "createName")


    --- 创建角色界面
    this.btnConfirmNew = Util.GetGameObject(self.gameObject, "createName/Frame/btnConfirm")
    this.textNameNew = Util.GetGameObject(self.gameObject, "createName/Frame/InputField"):GetComponent("InputField")
    this.btnRandNameNew = Util.GetGameObject(self.gameObject, "createName/Frame/randIcon")
    this.btnBoy = Util.GetGameObject(self.gameObject, "createName/boy")
    this.BoyCheck = Util.GetGameObject(self.gameObject,"createName/boy/check")
    this.btnBitch = Util.GetGameObject(self.gameObject, "createName/girl")
    this.GirlCheck = Util.GetGameObject(self.gameObject, "createName/girl/check")

    this.boyUnchecked = Util.GetGameObject(self.gameObject, "createName/boyUnchecked")
    this.boySelectIcon = Util.GetGameObject(self.gameObject, "createName/boySelectIcon")
    this.girlUnchecked = Util.GetGameObject(self.gameObject, "createName/girlUnchecked")
    this.girlSelectIcon = Util.GetGameObject(self.gameObject, "createName/girlSelectIcon")

    -- 性别区分
    this.roleLive = Util.GetGameObject(self.gameObject, "roleHill/roleLIve")
    -- this.boyLive = Util.GetGameObject(self.gameObject, "roleStand/boy")
    -- this.girlLive = Util.GetGameObject(self.gameObject, "roleStand/girl")
    -- this.Shadow = Util.GetGameObject(self.gameObject, "roleStand"):GetComponent("Image")
    -- this.Text = Util.GetGameObject(self.gameObject, "content"):GetComponent("Image")

    -- 特效
    -- this.boyEffect = Util.GetGameObject(self.gameObject, "createName/UI_effect_CreateNamePopup_change_man")
    -- this.bitchEffect = Util.GetGameObject(self.gameObject, "createName/UI_effect_CreateNamePopup_change_women")


    -- this.boyMask = Util.GetGameObject(this.boyEffect, "kuang_man")
    -- this.bitchMask = Util.GetGameObject(this.bitchEffect, "kuang_woman")

    -- effectAdapte(this.boyMask)
    -- effectAdapte(this.bitchMask)

end


function CreateNamePopup:OnSortingOrderChange()
    -- Util.AddParticleSortLayer(this.boyEffect, self.sortingOrder - orginLayer)
    -- Util.AddParticleSortLayer(this.bitchEffect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end


-- 计算字符串宽度 出计算字可以符宽度，用于显示使用
local function _NameWidth(str)
    local lenInByte = #str
    local width = 0
    local i = 1
    while (i <= lenInByte)
    do
        local curByte = string.byte(str, i)
        local byteCount = 1
        local len = 1
        if curByte > 0 and curByte <= 127 then
            byteCount = 1                                               --1字节字符
            len = 1
        elseif curByte >= 192 and curByte < 223 then
            byteCount = 2                                               --双字节字符
            len = 1
        elseif curByte >= 224 and curByte < 239 then
            byteCount = 3                                               --汉字
            len = 2
        elseif curByte >= 240 and curByte <= 247 then
            byteCount = 4                                               --4字节字符
            len = 2
        end

        i = i + byteCount                                              -- 重置下一字节的索引
        width = width + len                                             -- 字符的个数（长度）
    end
    return width
end
--绑定事件（用于子类重写）
function CreateNamePopup:BindEvent()

    Util.AddClick(this.btnConfirm, function()
        -- 修改昵称时要判断改名卡数量
        if not this.showType then
            local cardNum = BagManager.GetItemCountById(UpViewRechargeType.ChangeNameCard)
            if cardNum <= 0 then
                PopupTipPanel.ShowTipByLanguageId(11551)
                return
            end
        end

        if this.textName.text == nil or this.textName.text == "" then
            MsgPanel.ShowOne(GetLanguageStrById(11552))
            return
        end

        -- local len = _NameWidth(this.textName.text)
        -- if len < 2 or len > 12 then
        --     MsgPanel.ShowOne(GetLanguageStrById(11553))
        --    return
        -- end
        local len = _NameWidth(this.textName.text)
        local lan = GetLan()

        local lenMin
        local lenMax
        lenMin,lenMax = NameManager.GetNameLimit()
        -- if lan == 0 then
        --     lenMin = 2
        --     lenMax = 12
        -- elseif lan == 1 then
        --     lenMin = 4
        --     lenMax = 12
        -- elseif lan == 3 then
        --     lenMin = 1
        --     lenMax = 18
        -- end
        if len < lenMin or len > lenMax then
            MsgPanel.ShowOne(GetLanguageStrById(11553))
            return
        end

        --todo: 添加对非法字符的检测
        if CheckStrNumber(this.textName.text) then
             MsgPanel.ShowOne(GetLanguageStrById(23102))
             return
        end

        this.curName = this.textName.text
        local callBack = function()
            if this.options then
                -- self:ClosePanel()
                StoryManager.StoryJumpType(this.options[1], self)
            else
                PopupTipPanel.ShowTipByLanguageId(10845)
                Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnPlayNameChange)
                this:ClosePanel()
                --关闭提示窗
               -- RewardItemSingleShowPopup:ClosePanel()
            end
        end

        -- 类型3 为修改名称  类型1 为创建角色
        local type = this.showType == nil and 3 or 1
        NameManager.ChangeUserName(type, this.curName, nil, curSex, callBack)

    end)

    --角色起名
    Util.AddClick(this.btnConfirmNew, function()
        if this.textNameNew.text == nil or this.textNameNew.text == "" then
            MsgPanel.ShowOne(GetLanguageStrById(11552))
            return
        end

        local len = _NameWidth(this.textNameNew.text)
        local lan = GetLan()

        local lenMin
        local lenMax
        lenMin,lenMax = NameManager.GetNameLimit()

        --- 原来的多语言逻辑
        -- if lan == 0 then
        --     lenMin = 2
        --     lenMax = 12
        -- elseif lan == 1 then
        --     lenMin = 4
        --     lenMax = 12
        -- elseif lan == 3 then
        --     lenMin = 1
        --     lenMax = 18
        -- end
        -- LogError("lan "..lan.." lenMax"..lenMax.." lenMin"..lenMin.." language"..GetCurLanguage().." LEN"..len)



        if len < lenMin or len > lenMax then
            MsgPanel.ShowOne(GetLanguageStrById(11553))
            return
        end

        --todo: 添加对非法字符的检测
        if CheckStrNumber(this.textName.text) then
            MsgPanel.ShowOne(GetLanguageStrById(23102))
            return
        end

        this.curName = this.textName.text
        local callBack = function()
            if this.options then
                -- self:ClosePanel()
                StoryManager.StoryJumpType(this.options[1], self)
            else
                PopupTipPanel.ShowTipByLanguageId(10845)
                Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnPlayNameChange)
                this:ClosePanel()
                --关闭提示窗
                -- RewardItemSingleShowPopup:ClosePanel()
            end
        end

        this.curName = this.textNameNew.text
        local callBack = function()
            if this.options then
                CustomEventManager.GameCustomEvent("创建角色")
                self:ClosePanel()
                -- self:ClosePanel()
                CustomEventManager.GameCustomEvent("新手引导开始")
                StoryManager.StoryJumpType(this.options[1], self)
            end
        end

        -- 类型3 为修改名称  类型1 为创建角色
        local type = this.showType == nil and 3 or 1
        NameManager.ChangeUserName(type, this.curName, nil, curSex-1, callBack)
    end)

    -- 随机名称
    Util.AddClick(this.btnRandName, function()
        --local index = math.ceil(math.random(1, 6))
        NameManager.GetRandomNameData(curSex)
    end)

    Util.AddClick(this.btnRandNameNew, function()
        NameManager.GetRandomNameData(curSex)
    end)

    -- 购买改名卡
    Util.AddClick(this.btnAddCard, function()
        --功能快捷购买
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.ChangeNameCard })
    end)
    -- 关闭界面
    Util.AddClick(this.btnBack, function()
        --功能快捷购买
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    Util.AddClick(this.btnBoy, function ()
        this.FreshSex(boy)
    end)

    Util.AddClick(this.btnBitch, function ()
        this.FreshSex(girl)
    end)

    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.boyUnchecked, function ()
        this.FreshSex(boy)
    end)
    Util.AddClick(this.girlUnchecked, function ()
        this.FreshSex(girl)
    end)
end

-- 随机名称显示
function CreateNamePopup.OnRefreshName(randomName)
    this.textName.text = randomName or ""
    this.textNameNew.text = randomName or ""
end
--判断字符串中含有数字
 CheckStrNumber = function (str)
    local res = string.find(str, '[%d]+')
    if type(res) == "number" then
        return true
    end
    return false
end

-- 刷新性别显示
function this.FreshSex(sex)
    -- local standRes = sex == boy and boyLiveRes or girlLiveRes
    -- curSex = sex == boy and ROLE_SEX.BOY or ROLE_SEX.SLUT

    -- local shadowRes = sex == boy and "c_cjjs_heitou" or "c_cjjs_baitou"
    -- local textRes = sex == boy and "c_cjjs_heizi" or "c_cjjs_baizi"
    -- local boyIconRes = sex == boy and "c_cjjs_heitou_01" or "c_cjjs_heitou_02"
    -- local bitchIconRes = sex == boy and "c_cjjs_baitou_02" or "c_cjjs_baitou_01"
    -- this.boyEffect:SetActive(sex == boy)
    -- this.bitchEffect:SetActive(sex == girl)

    -- local index = sex == boy and 1 or 2
    -- 加载立绘资源
    -- this.LoadLiveBySex(standRes, index)

    -- this.Shadow.sprite = Util.LoadSprite(shadowRes)
    -- this.Text.sprite = Util.LoadSprite(textRes)
    -- this.btnBoy:GetComponent("Image").sprite = Util.LoadSprite(boyIconRes)
    -- this.btnBitch:GetComponent("Image").sprite = Util.LoadSprite(bitchIconRes)
       
    -- this.btnBoy:GetComponent("Image"):SetNativeSize()
    -- this.btnBitch:GetComponent("Image"):SetNativeSize()

    -- this.boyLive:SetActive(sex == boy)
    -- this.girlLive:SetActive(sex ~= boy)
    this.BoyCheck:SetActive(sex == boy)
    this.GirlCheck:SetActive(sex ~= boy)

    this.boyUnchecked:SetActive(sex ~= boy)
    this.boySelectIcon:SetActive(sex == boy)
    this.girlUnchecked:SetActive(sex == boy)
    this.girlSelectIcon:SetActive(sex ~= boy)
    curSex = sex

end

function this.LoadLiveBySex(standRes, index)
    if not curLive then
        curLive = poolManager:LoadLive(standRes, this.roleLive.transform,
                smallInfo[index].Scale, smallInfo[index].Pos)
    else
        poolManager:UnLoadLive(lastChoose, curLive)
        curLive = poolManager:LoadLive(standRes, this.roleLive.transform,
                smallInfo[index].Scale, smallInfo[index].Pos)
    end
    lastChoose = standRes
end

--添加事件监听（用于子类重写）
function CreateNamePopup:AddListener()

    Game.GlobalEvent:AddEvent(GameEvent.Event.PointTrigger, this.OnInfoChange)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnNameChange, this.OnRefreshName)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.RefreshShow)
end

--移除事件监听（用于子类重写）
function CreateNamePopup:RemoveListener()

    Game.GlobalEvent:RemoveEvent(GameEvent.Event.PointTrigger, this.OnInfoChange)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnNameChange, this.OnRefreshName)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.RefreshShow)
end

--界面打开时调用（用于子类重写）
function CreateNamePopup:OnOpen(...)

    local args = {...}
    this.showType = args[1]
    this.eventId = args[2]
    this.showValues = args[3]
    this.options = args[4]
    this.InitName()
    this.RefreshShow()
end

function CreateNamePopup:OnShow()
    
    NameManager.GetRandomNameData(curSex) --< 初始随名
end

--界面关闭时调用（用于子类重写）
function CreateNamePopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function CreateNamePopup:OnDestroy()

    if curLive then
        poolManager:UnLoadLive(lastChoose, curLive)
    end
end


-- 初始化名字显示
function this.InitName()
    this.textName.text = this.curName
    this.textNameNew.text = this.curName
    curSex = NameManager.roleSex

end

-- 刷新基础显示
function this.RefreshShow()
    if this.showType then
        this.createnameRoot:SetActive(true)
        this.nameChangeRoot:SetActive(false)
        this.mask:SetActive(false)

        this.FreshSex(boy)

    else  -- 修改名称
        this.createnameRoot:SetActive(false)
        this.nameChangeRoot:SetActive(true)
        this.mask:SetActive(true)

        this.cardNum.text = BagManager.GetItemCountById(UpViewRechargeType.ChangeNameCard)
    end
end

function this.OnInfoChange(_showType, _eventId, _showValues, _options)
    if this.eventId ~= _eventId then
        this.showType = _showType
        this.eventId = _eventId
        this.showValues = _showValues
        this.options = _options
    end
end

return CreateNamePopup