require("Base/BasePanel")
local HeadChangePopup = Inherit(BasePanel)
local this = HeadChangePopup
local TitleConfig = ConfigManager.GetConfig(ConfigName.TitleConfig)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
-- 获取头像框数据, 并排序
local _HeadFrameList = {}
local _HeadList = {}
local _DesignationList = {}

this.alreadyHaveTitle = {}
local TimerList = {}

-- 头像对象管理
local _PlayerHeadList = {}

-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabData = {
    [1] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong", lock = "", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name = GetLanguageStrById(11888) , rpType = RedPointType.HeadChange_Head},
    [2] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", lock = "", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name = GetLanguageStrById(11889) , rpType = RedPointType.HeadChange_Frame},
    [3] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", lock = "", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name = GetLanguageStrById(22711) , rpType = nil}}

local SELECT_TYPE = {
    HEAD = 1, -- 头像
    FRAME = 2, -- 头像框
    TITLE = 3, --称号
}
this.ChallengeId = 0--交互称号ID
this.JumpId = 0--跳转ID

--初始化组件（用于子类重写）
function HeadChangePopup:InitComponent()
    -- 获取节点
    this.btnBack = Util.GetGameObject(this.transform, "btnBack")

    -- 更换
    this.btnConfirm = Util.GetGameObject(this.transform, "confirm")
    this.btnConfirmText = Util.GetGameObject(this.transform, "confirm/Text"):GetComponent("Text")

    -- 选择
    this.selectPos = Util.GetGameObject(this.transform, "select")
    this.select = Util.GetGameObject(this.transform, "select/select")
    this.using = Util.GetGameObject(this.transform, "select/using")
    this.selectBg = Util.GetGameObject(this.transform, "select/selectBg")

    -- 预制
    this.headPre = Util.GetGameObject(this.transform, "headPre")
    this.titlePre = Util.GetGameObject(this.transform, "titlePre")

    this.scroll = Util.GetGameObject(this.transform, "scroll")
    local height = this.scroll.transform.rect.height
    local width = this.scroll.transform.rect.width
    -- 头像/头像框
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.headPre, nil, Vector2.New(width, height), 1, 5, Vector2.New(5,5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.scrollTitle = Util.GetGameObject(this.transform, "scrollTitle")
    local heightTitle = this.scrollTitle.transform.rect.height
    local widthTitle = this.scrollTitle.transform.rect.width
    -- 称号
    this.scrollViewTitle = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollTitle.transform,
            this.titlePre, nil, Vector2.New(widthTitle, heightTitle), 1, 1, Vector2.New(0,5))
    this.scrollViewTitle.moveTween.MomentumAmount = 1
    this.scrollViewTitle.moveTween.Strength = 2

    this.tabbox = Util.GetGameObject(this.transform, "top")

    -- 头像/头像框信息
    this.content = Util.GetGameObject(this.transform, "content")
    this.frame = Util.GetGameObject(this.content, "frame"):GetComponent("Image")
    this.icon = Util.GetGameObject(this.content, "icon"):GetComponent("Image")
    this.name = Util.GetGameObject(this.content, "name"):GetComponent("Text")
    this.desc = Util.GetGameObject(this.content, "desc"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function HeadChangePopup:BindEvent()
    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetTabIsLockCheck(this.TabIsLockCheck)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)

    -- 绑定红点
    local tabList = this.TabCtrl:GetTabList()
    for index = 1, #tabList do
        local tab = tabList[index]
        local redpot = Util.GetGameObject(tab, "redpot")
        if _TabData[index].rpType then
            BindRedPointObject(_TabData[index].rpType, redpot)
        else
            redpot:SetActive(false)
        end
    end

    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        -- 清除当前打开的类型界面全部红点
        if this.CurSelectType then
            if this.CurSelectType == SELECT_TYPE.FRAME then
                HeadManager.RemoveAllNewHead(ItemType.HeadFrame)
            elseif this.CurSelectType == SELECT_TYPE.HEAD then
                HeadManager.RemoveAllNewHead(ItemType.Head)
            end
        end
        this:ClosePanel()
    end)

    -- 确认点击确认按钮
    Util.AddClick(this.btnConfirm, function()
        -- 请求更换头像框
        if this.CurSelectType == SELECT_TYPE.FRAME then
            local frameId = _HeadFrameList[this.CurSelectIndex].Id
            local num = BagManager.GetItemCountById(frameId)
            if num <= 0 then
                PopupTipPanel.ShowTipByLanguageId(11890)
                return
            end
            NetManager.RequestChangeModifyDecoration(0, frameId, function ()
                PopupTipPanel.ShowTipByLanguageId(11891)
                PlayerManager.frame = frameId
                Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnHeadFrameChange)
                this.RefreshCurShow()
            end)
        elseif this.CurSelectType == SELECT_TYPE.HEAD then
            local headId = _HeadList[this.CurSelectIndex].Id
            local num = BagManager.GetItemCountById(headId)
            if num <= 0 then
                PopupTipPanel.ShowTipByLanguageId(11892)
                return
            end
            NetManager.RequestChangeModifyDecoration(1, headId, function ()
                PopupTipPanel.ShowTipByLanguageId(11891)
                PlayerManager.head = headId
                Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnHeadChange)
                this.RefreshCurShow()
            end)
        elseif this.CurSelectType == SELECT_TYPE.TITLE then
            if this.ChallengeId ~= 0 then
                NetManager.RequestChangeModifyDecoration(2,this.ChallengeId,function() 
                    --PlayerManager.designation此时这个值是已经改变后的数值
                    if  PlayerManager.designation == 0 then
                        PopupTipPanel.ShowTipByLanguageId(23124)
                    else
                        PopupTipPanel.ShowTipByLanguageId(23125)
                    end
                    this.btnConfirmText.text = GetLanguageStrById(22404)

                    this.RefreshTitleShowEvevt()
                end)
            else
                if this.JumpId == 0 then
                    PopupTipPanel.ShowTipByLanguageId(23126)
                else
                    JumpManager.GoJump(TitleConfig[this.JumpId].JumpId)
                end
            end
        end
    end)

end

--添加事件监听（用于子类重写）
function HeadChangePopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Title.RefreshTitleShowEvevt, this.RefreshTitleShowEvevt)

end

--移除事件监听（用于子类重写）
function HeadChangePopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Title.RefreshTitleShowEvevt, this.RefreshTitleShowEvevt)
end

--界面打开时调用（用于子类重写）
function HeadChangePopup:OnOpen(...)

    _HeadList = HeadManager.GetHeadList()
    _HeadFrameList = HeadManager.GetHeadFrameList()

    if this.TabCtrl then
        this.TabCtrl:ChangeTab(1)
    end

    _DesignationList = {}
    for k,v in ConfigPairs(TitleConfig) do
        table.insert(_DesignationList,v)
    end  
end

function this.RefreshTitleShowEvevt()
    NetManager.chenghaoRequest(function (msg)
        this.RefreshTitleShow(msg)
    end)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function HeadChangePopup:OnShow()
    --称号
    this.RefreshTitleShowEvevt()
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab, "default")
    local select = Util.GetGameObject(tab, "select")
    Util.GetGameObject(tab,"Img"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    default:GetComponent("Text").text = _TabData[index].name
    select:GetComponent("Text").text = _TabData[index].name
    default:SetActive(status == "default")
    select:SetActive(status == "select")
end
-- tab可用性检测
function this.TabIsLockCheck(index)
    return false
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    -- 切换页签时清除上一个页签的所有红点数据
    if lastIndex and index ~= lastIndex then
        if lastIndex == SELECT_TYPE.FRAME then
            HeadManager.RemoveAllNewHead(ItemType.HeadFrame)
        elseif lastIndex == SELECT_TYPE.HEAD then
            HeadManager.RemoveAllNewHead(ItemType.Head)
        end
    end

    this.btnConfirmText.text = GetLanguageStrById(22404)

    this.CurSelectType = index
    this.CurSelectIndex = 1
    -- 构建数据
    local datalist = {}
    local curId = nil

    local function sortlist()
        -- 排序
        table.sort(datalist, function(a, b)
            -- 使用中的头像在最前面
            if curId == a.Id then return true end
            if curId == b.Id then return false end
            -- 拥有的头像往前放
            local anum = BagManager.GetItemCountById(a.Id)
            local bnum = BagManager.GetItemCountById(b.Id)
            if anum > 0 and bnum <= 0 then return true end
            if anum <= 0 and bnum > 0 then return false end
            -- 按id排序
            return a.Id < b.Id
        end)
    end
    if index == SELECT_TYPE.FRAME then
        local tempHeadFrameList = {}
        --检测FrameAndTitleShow
        for i=1, #_HeadFrameList do 
            if _HeadFrameList[i].FrameAndTitleShow == 1 then
                local num = BagManager.GetItemCountById(_HeadFrameList[i].Id)
                if num > 0 then
                    table.insert(tempHeadFrameList,_HeadFrameList[i])
                end
            else
                table.insert(tempHeadFrameList,_HeadFrameList[i])
            end
        end
        _HeadFrameList = tempHeadFrameList 
        datalist = _HeadFrameList
        sortlist()
        curId = PlayerManager.frame
        this.content:SetActive(true)
        this.scroll:SetActive(true)
        this.scrollTitle:SetActive(false)
        this.scrollView:SetData(datalist, function(index, go)
            this.HeadFrameItemAdapter(go, datalist[index], index)
        end)
        this.scrollView:SetIndex(1)
    elseif index == SELECT_TYPE.HEAD then
        datalist = _HeadList
        sortlist()
        curId = PlayerManager.head
        this.content:SetActive(true)
        this.scroll:SetActive(true)
        this.scrollTitle:SetActive(false)
        this.scrollView:SetData(datalist, function(index, go)
            this.HeadFrameItemAdapter(go, datalist[index], index)
        end)
        this.scrollView:SetIndex(1)
    else
        this.content:SetActive(false)
        this.scroll:SetActive(false)
        this.scrollTitle:SetActive(true)

        local tempDesignationList = {}
        for i=1, #_DesignationList do 
            local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig, _DesignationList[i].ConditionItem)
            if itemConfig.FrameAndTitleShow == 1 then
                local isUnlock = false
                if this.alreadyHaveTitle[_DesignationList[i].Id] then
                    local v = this.alreadyHaveTitle[_DesignationList[i].Id]
                    if _DesignationList[i].Id == v.tid then
                        if _DesignationList[i].Time == 0 then
                            isUnlock = true
                        else
                            if v.insertDateTime/1000+ _DesignationList[i].Time-PlayerManager.serverTime > 0 then
                                isUnlock = true
                            end     
                        end
                    end
                end
                if isUnlock then
                    table.insert(tempDesignationList,_DesignationList[i])  
                end
            else
                table.insert(tempDesignationList,_DesignationList[i])       
            end
        end
        _DesignationList = tempDesignationList
        this.scrollViewTitle:SetData(_DesignationList, function(index, go)
            this.SetDesignationData(go, _DesignationList[index],index)
        end)
        this.scrollViewTitle:SetIndex(1)
    end
end

local chooseId = 0
--称号基本信息
function this.RefreshTitleShow(msg)
    this.ChallengeId = 0

    this.alreadyHaveTitle = {}
    for i = 1,#msg.titleList do
        this.alreadyHaveTitle[msg.titleList[i].tid] = msg.titleList[i]
    end

    chooseId = 0
    this.scrollViewTitle:SetData(_DesignationList, function(index, go)
        this.SetDesignationData(go, _DesignationList[index],index)
    end)
    this.scrollViewTitle:SetIndex(1)
end

function this.RefreshCurShow()
    local datalist = {}
    if this.CurSelectType == SELECT_TYPE.FRAME then
        datalist = _HeadFrameList
    elseif this.CurSelectType == SELECT_TYPE.HEAD then
        datalist = _HeadList
    end
    this.scrollView:SetData(datalist, function(index, go)
        this.HeadFrameItemAdapter(go, datalist[index], index)
    end)
end

function this.HeadFrameItemAdapter(item, data, index)
    local root = Util.GetGameObject(item, "root")
    local name = Util.GetGameObject(item, "name"):GetComponent("Text")
    local redpot = Util.GetGameObject(item, "redpot")

    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, root.transform)
    end
    _PlayerHeadList[item]:Reset()
    _PlayerHeadList[item]:SetScale(0.7)

    if this.CurSelectType == SELECT_TYPE.HEAD then
        local frameId = data.Id
        name.text = GetLanguageStrById(data.Name)
        _PlayerHeadList[item]:SetHead(frameId)
        _PlayerHeadList[item]:SetFrame(PlayerManager.frame)

        if frameId == PlayerManager.head then
            this:SetUsing(_PlayerHeadList[item].gameObject)
        else
            this:RecycleUsing(_PlayerHeadList[item].gameObject)
        end

        local num = BagManager.GetItemCountById(frameId)
        _PlayerHeadList[item]:SetGray(num <= 0)

        redpot:SetActive(num > 0 and HeadManager.IsNewHead(frameId))

        Util.AddOnceClick(item, function()
            this.SelectItem(index, item)
        end)
    elseif this.CurSelectType == SELECT_TYPE.FRAME then
        local headId = data.Id
        name.text = GetLanguageStrById(data.Name)
        _PlayerHeadList[item]:SetHead(PlayerManager.head)
        _PlayerHeadList[item]:SetFrame(headId)
        if headId == PlayerManager.frame then
            this:SetUsing(_PlayerHeadList[item].gameObject)
        else
            this:RecycleUsing(_PlayerHeadList[item].gameObject)
        end

        local num = BagManager.GetItemCountById(headId)
        _PlayerHeadList[item]:SetGray(num <= 0)

        redpot:SetActive(num > 0 and HeadManager.IsNewHead(headId))

        Util.AddOnceClick(item, function()
            this.SelectItem(index, item)
        end)
    end

    -- 判断选中框的显示
    if this.CurSelectIndex == index then
        this.SelectItem(index, item)
    else
        local selectBg = Util.GetGameObject(item, "bg/selectBg")
        local select = Util.GetGameObject(item, "selectPos/select")
        if select then 
            select:SetActive(false)
        end
        if selectBg then
            selectBg:SetActive(false)
        end
    end
end

local old = nil

function this.SetDesignationData(item, data,index)
    item:SetActive(true)
    local seclect = Util.GetGameObject(item, "seclect")
    local titleImage = Util.GetGameObject(item, "titleImage")
    local lock = Util.GetGameObject(item, "titleImage/state")
    local tip = Util.GetGameObject(item, "infomation/tip/value")
    local wear = Util.GetGameObject(item, "wear")

    seclect.gameObject:SetActive(false)
    wear.gameObject:SetActive(false)
    titleImage:GetComponent("Image").sprite = Util.LoadSprite(ConfigManager.GetConfigData("ArtResourcesConfig",data.TitleImage).Name)

    for i = 1, #data.Attr do
        Util.GetGameObject(item, "infomation/arr"..i.."/icon"):GetComponent("Image").sprite = Util.LoadSprite(PropertyConfig[data.Attr[i][1]].Icon)
        Util.GetGameObject(item, "infomation/arr"..i.."/title"):GetComponent("Text").text = GetLanguageStrById(PropertyConfig[data.Attr[i][1]].Info) .. ":"
        Util.GetGameObject(item, "infomation/arr"..i.."/value"):GetComponent("Text").text = "+" .. GetPropertyFormatStr(PropertyConfig[data.Attr[i][1]].Style,data.Attr[i][2])
    end
    
    tip:GetComponent("Text").text = GetLanguageStrById(data.ConditionDes)

    if TimerList[item] then
        TimerList[item]:Stop()
        TimerList[item] = nil
    end

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    local isActive = false
    if this.alreadyHaveTitle[data.Id] then
        local v = this.alreadyHaveTitle[data.Id]
        if data.Id == v.tid then
            isActive = true
            if data.Time ~= 0 then
                local endtime = v.insertDateTime/1000+data.Time-PlayerManager.serverTime
                if endtime > 0 then
                    lock:SetActive(false)
                    TimerList[item] = Timer.New(function ()
                        if endtime <= 0 then
                            lock:SetActive(true)
                            TimerList[item]:Stop()
                            this.RefreshTitleShowEvevt()
                        else
                            endtime = endtime - 1
                        end
                    end, 1, -1, true)
                    TimerList[item]:Start()
                else
                    lock:SetActive(true)
                end
            else
                lock:SetActive(false)
            end
            if v.curUseTitileId == true then
                wear.gameObject:SetActive(true)
            end
        end
    else
        lock:SetActive(true)
    end
    if chooseId == index then
        seclect.gameObject:SetActive(true)
    end

    Util.AddOnceClick(item, function()
        if lock.activeSelf == true then
            return
        end

        chooseId = index

        if not IsNull(old) then
            old:SetActive(false)
            old = nil
        end

        seclect:SetActive(true)
        old = seclect

        if isActive == true then
           this.ChallengeId = data.Id
        else
            this.ChallengeId = 0
            this.JumpId = data.Id
        end
        if this.ChallengeId == PlayerManager.designation and PlayerManager.designation ~= 0 then
            this.btnConfirmText.text = GetLanguageStrById(11908)
        else
            this.btnConfirmText.text = GetLanguageStrById(22404)
        end
    end)
end

-- 设置选中的头像
function this.SelectItem(index, item)
    -- 保存选中的index
    this.CurSelectIndex = index

    -- 显示选中图标
    this.selectBg:SetActive(true)
    this.selectBg.transform:SetParent(Util.GetGameObject(item, "bg").transform)
    this.selectBg.transform.localPosition = Vector3.zero

    this.select:SetActive(true)
    this.select.transform:SetParent(Util.GetGameObject(item, "selectPos").transform)
    this.select.transform.localPosition = Vector3.zero
    this.select.transform.localScale = Vector3.one

    -- 设置content显示
    local data = nil
    if this.CurSelectType == SELECT_TYPE.FRAME then
        data = _HeadFrameList[index]
        this.frame.sprite = GetPlayerHeadFrameSprite(data.Id)
        this.icon.sprite = GetPlayerHeadSprite(PlayerManager.head)
    elseif this.CurSelectType == SELECT_TYPE.HEAD then
        data = _HeadList[index]
        this.frame.sprite = GetPlayerHeadFrameSprite(PlayerManager.frame)
        this.icon.sprite = GetPlayerHeadSprite(data.Id)
    else
    end
    if not data then return end

    this.name.text = GetLanguageStrById(data.Name)
    this.desc.text = GetLanguageStrById(data.ItemDescribe)

    -- 红点
    if HeadManager.IsNewHead(data.Id) then
        HeadManager.SetNotNewHeadAnyMore(data.Id)
        Util.GetGameObject(item, "redpot"):SetActive(false)
    end
end

-- 设置使用中的状态
function HeadChangePopup:SetUsing(node)
    this.using.transform:SetParent(node.transform)
    this.using.transform.localPosition = Vector3.zero
    this.using.transform.localScale = Vector3.one
    this.using:SetActive(true)
end
function HeadChangePopup:RecycleUsing(node)
    -- 如果node中包含using就回收
    if node then
        local using = Util.GetGameObject(node, "using")
        if not using then return end
    end
    this.using.transform:SetParent(this.selectPos.transform)
    this.using.transform.localPosition = Vector3.zero
    this.using:SetActive(false)
end

--界面关闭时调用（用于子类重写）
function HeadChangePopup:OnClose()
    _HeadFrameList = {}
    _HeadList = {}
end

--界面销毁时调用（用于子类重写）
function HeadChangePopup:OnDestroy()
    this:RecycleUsing()
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}

    this.ScrollView = nil

    for key,value in pairs(TimerList) do
        if value then
            value:Stop()
            value=nil
        end
    end

    -- 清除红点绑定
    for _, v in ipairs(_TabData) do
        if v.rpType then
            ClearRedPointObject(v.rpType)
        end
    end
end

return HeadChangePopup