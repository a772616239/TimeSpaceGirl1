UIManager = {}
local this = UIManager
--监听ui事件的对象
this.eventSystem = nil
--正常UI面板节点
this.uiNode = nil
--固定层级面板节点
this.maxNode = nil
--UI的配置信息
this.configs = {}
--桟式UI列表
this.stackList = {}
--固定层级UI列表
this.fixedList= {}
--已经打开过的UI
this.openedList= {}
--窗口之间的层级间隔
this.space = 100

--> 屏蔽界面开关
this.shieldSwitch = true

UIManager.UIHeight = 1920
UIManager.UIWidth = 1080 

local UIConfig
local unpack = unpack
local standard = 16 / 9
local DELAY_TIME = 15 --超过延迟时间，界面被销毁
local delayDestoryList = {}
local function update()
    for k,v in pairs(delayDestoryList) do
        if v.delayTime < Time.realtimeSinceStartup then
            this.DestroyPanel(v.panel)
            this.openedList[k] = nil
            delayDestoryList[k] = nil
        end
    end
end

UIType = {
    --[[
    全屏面板
    打开：自动关闭桟中的所有全屏窗口，并将当前窗口提到桟顶
    关闭：自动打开上一个全屏窗口
    --]]
    FullType = 1,
    --[[
    弹出框类型面板
    打开：打开当前面板
    关闭：关闭当前面板
    --]]
    Popup = 2,
    --固定层级面板
    --[[
    弹出框类型面板
    打开：打开当前面板
    关闭：关闭当前面板
    --]]
    Fixed = 3
}

function UIManager.Initialize()
    UIConfig = ConfigManager.GetConfig(ConfigName.UIConfig)

    local prefab = resMgr:LoadAsset("UIRoot")
    local gameObj = GameObject.Instantiate(prefab)
    gameObj.name = "UIRoot"
    this.eventSystem = GameObject.Find("EventSystem")
    this.uiRoot = gameObj
    this.uiNode = gameObj.transform:Find("UIRoot/UINode")
    this.fixedNode = gameObj.transform:Find("UIRoot/FixedNode")
    this.screenMask1 = gameObj.transform:Find("UIRoot/ScreenMask1").gameObject
    this.screenMask2 = gameObj.transform:Find("UIRoot/ScreenMask2").gameObject
    -- this.camera = gameObj.transform:Find("UICamera"):GetComponent("Camera")
    this.camera = gameObj.transform:Find("UIRoot/UICameraRoot/UICamera"):GetComponent("Camera")
    this.cameraRoot = gameObj.transform:Find("UIRoot/UICameraRoot")
    this.Adapter()
    this.InitCommonPanels()
    UpdateBeat:Add(update, this)
end

function UIManager.InitCommonPanels()
    require("Modules/Message/MsgPanel")
    require("Modules/Message/RequestPanel")
    require("Modules/Message/LoadingPanel")
    require("Modules/Message/PopupTipPanel")
    require("Modules/Message/SwitchPanel")
    require("Modules/Message/NotEnoughPopup")
    require("Modules/Popup/CostConfirmPopup")
    require("Modules/Message/HorseRaceLampView")
    require("Modules/Message/MissionDailyTipPanel")
    UIManager.OpenPanelWithNoSound(UIName.HorseRaceLampView)
end

function UIManager.Adapter()
    local notchHeight = 0
    --if AppConst.isSDK then
        notchHeight = NotchScreenUtil.Instance:GetNotchHeight()
       
        if notchHeight == -1 then
            --TODO: 这里再配置一套小众的手机的屏幕高度
            notchHeight = 0
        end
    --end
    UIManager.Offset = {
        Top = notchHeight,
        Bottom = 0,
        Left = 0,
        Right = 0,
    }

    -- 屏幕大小
    UIManager.width = Screen.width 
    UIManager.height = Screen.height 
    -- ui实际大小
    UIManager.realHeigt = Screen.height - UIManager.Offset.Top - UIManager.Offset.Bottom 
    UIManager.realWidth = Screen.width - UIManager.Offset.Left - UIManager.Offset.Right 

    --根据设备号设置不适配【ps:如华为P10就会做适配反而出问题】
    if UnityEngine.SystemInfo.deviceModel == "HUAWEI VTR-AL00" then
        this.screenMask1:SetActive(false)
        this.screenMask2:SetActive(false)
    
        UIManager.height = Screen.height
        UIManager.width = Screen.width
    else
        local n = Screen.height / Screen.width
        if n > standard then
            local rectTransform = this.uiNode.gameObject:GetComponent("RectTransform")
            rectTransform.offsetMin = Vector2.New(rectTransform.offsetMin.x, rectTransform.offsetMin.y + UIManager.Offset.Bottom)
            rectTransform.offsetMax = Vector2.New(rectTransform.offsetMax.x, rectTransform.offsetMax.y - UIManager.Offset.Top)
    
            rectTransform = this.screenMask1:GetComponent("RectTransform")
            rectTransform.anchorMin = Vector2.New(0, 1)
            rectTransform.anchorMax = Vector2.New(1, 1)
            rectTransform.offsetMin = Vector2.New(0, 0)
            rectTransform.offsetMax = Vector2.New(0, 0)
            rectTransform.pivot = Vector2.New(0.5, 1)
            rectTransform.sizeDelta = Vector2.New(0, UIManager.Offset.Top)
    
            rectTransform = this.screenMask2:GetComponent("RectTransform")
            rectTransform.anchorMin = Vector2.New(0, 0)
            rectTransform.anchorMax = Vector2.New(1, 0)
            rectTransform.offsetMin = Vector2.New(0, 0)
            rectTransform.offsetMax = Vector2.New(0, 0)
            rectTransform.pivot = Vector2.New(0.5, 0)
            rectTransform.sizeDelta = Vector2.New(0, UIManager.Offset.Bottom)
        elseif n < standard then
            local w = 1920 / Screen.height * Screen.width
            local f = (w-1080) / 2
            local rectTransform = this.uiNode.gameObject:GetComponent("RectTransform")
            rectTransform.offsetMin = Vector2.New(rectTransform.offsetMin.x + f, rectTransform.offsetMin.y)
            rectTransform.offsetMax = Vector2.New(rectTransform.offsetMax.x - f, rectTransform.offsetMax.y)
    
            rectTransform = this.fixedNode.gameObject:GetComponent("RectTransform")
            rectTransform.offsetMin = Vector2.New(rectTransform.offsetMin.x + f, rectTransform.offsetMin.y)
            rectTransform.offsetMax = Vector2.New(rectTransform.offsetMax.x - f, rectTransform.offsetMax.y)
    
            rectTransform = this.screenMask1:GetComponent("RectTransform")
            rectTransform.anchorMin = Vector2.New(0, 0)
            rectTransform.anchorMax = Vector2.New(0, 1)
            rectTransform.offsetMin = Vector2.New(0, 0)
            rectTransform.offsetMax = Vector2.New(0, 0)
            rectTransform.sizeDelta = Vector2.New(f*2, 0)
    
            rectTransform = this.screenMask2:GetComponent("RectTransform")
            rectTransform.anchorMin = Vector2.New(1, 0)
            rectTransform.anchorMax = Vector2.New(1, 1)
            rectTransform.offsetMin = Vector2.New(0, 0)
            rectTransform.offsetMax = Vector2.New(0, 0)
            rectTransform.sizeDelta = Vector2.New(f*2, 0)
    
            UIManager.width = Screen.width - f*2
            UIManager.height = Screen.height
        else
            this.screenMask1:SetActive(false)
            this.screenMask2:SetActive(false)
    
            UIManager.height = Screen.height
            UIManager.width = Screen.width
        end   
    end

    -- local n = Screen.height / Screen.width
    -- if n > standard then
    --     local f = (n-standard)*Screen.width / 2
    --     local rectTransform = this.uiNode.gameObject:GetComponent("RectTransform")
    --     rectTransform.offsetMin = Vector2.New(rectTransform.offsetMin.x, rectTransform.offsetMin.y + f)
    --     rectTransform.offsetMax = Vector2.New(rectTransform.offsetMax.x, rectTransform.offsetMax.y - f)

    --     rectTransform = this.fixedNode.gameObject:GetComponent("RectTransform")
    --     rectTransform.offsetMin = Vector2.New(rectTransform.offsetMin.x, rectTransform.offsetMin.y + f)
    --     rectTransform.offsetMax = Vector2.New(rectTransform.offsetMax.x, rectTransform.offsetMax.y - f)

    --     rectTransform = this.screenMask1:GetComponent("RectTransform")
    --     rectTransform.anchorMin = Vector2.New(0, 1)
    --     rectTransform.anchorMax = Vector2.New(1, 1)
    --     rectTransform.offsetMin = Vector2.New(0, 0)
    --     rectTransform.offsetMax = Vector2.New(0, 0)
    --     rectTransform.sizeDelta = Vector2.New(0, f*2)

    --     rectTransform = this.screenMask2:GetComponent("RectTransform")
    --     rectTransform.anchorMin = Vector2.New(0, 0)
    --     rectTransform.anchorMax = Vector2.New(1, 0)
    --     rectTransform.offsetMin = Vector2.New(0, 0)
    --     rectTransform.offsetMax = Vector2.New(0, 0)
    --     rectTransform.sizeDelta = Vector2.New(0, f*2)

    --     UIManager.width = Screen.width
    --     UIManager.height = Screen.height - f*2
    -- elseif n < standard then
    --     local w = 1920 / Screen.height * Screen.width
    --     local f = (w-1080) / 2
    --     local rectTransform = this.uiNode.gameObject:GetComponent("RectTransform")
    --     rectTransform.offsetMin = Vector2.New(rectTransform.offsetMin.x + f, rectTransform.offsetMin.y)
    --     rectTransform.offsetMax = Vector2.New(rectTransform.offsetMax.x - f, rectTransform.offsetMax.y)

    --     rectTransform = this.fixedNode.gameObject:GetComponent("RectTransform")
    --     rectTransform.offsetMin = Vector2.New(rectTransform.offsetMin.x + f, rectTransform.offsetMin.y)
    --     rectTransform.offsetMax = Vector2.New(rectTransform.offsetMax.x - f, rectTransform.offsetMax.y)

    --     rectTransform = this.screenMask1:GetComponent("RectTransform")
    --     rectTransform.anchorMin = Vector2.New(0, 0)
    --     rectTransform.anchorMax = Vector2.New(0, 1)
    --     rectTransform.offsetMin = Vector2.New(0, 0)
    --     rectTransform.offsetMax = Vector2.New(0, 0)
    --     rectTransform.sizeDelta = Vector2.New(f*2, 0)

    --     rectTransform = this.screenMask2:GetComponent("RectTransform")
    --     rectTransform.anchorMin = Vector2.New(1, 0)
    --     rectTransform.anchorMax = Vector2.New(1, 1)
    --     rectTransform.offsetMin = Vector2.New(0, 0)
    --     rectTransform.offsetMax = Vector2.New(0, 0)
    --     rectTransform.sizeDelta = Vector2.New(f*2, 0)

    --     UIManager.width = Screen.width - f*2
    --     UIManager.height = Screen.height
    -- else
    --     this.screenMask1:SetActive(false)
    --     this.screenMask2:SetActive(false)

    --     UIManager.height = Screen.height
    --     UIManager.width = Screen.width
    -- end
end


function UIManager.ChangeTo2D()
    this.camera.orthographic = true
end

function UIManager.ChangeTo3D()
    this.camera.orthographic = false
end

--打开UI时间统计
--Key=UIID Value={时间(秒),时间(秒)}
local OpenUITimeStatistics = {}
function UIManager.AddUseTime(id, useTime)
    if not OpenUITimeStatistics[id] then
        OpenUITimeStatistics[id] = 
        {
            --记录每次
        }
    end

    table.insert(OpenUITimeStatistics[id], useTime)
end

function UIManager.PrintUseTime()
    local text = "打开界面用时统计\r\n"
    for key, value in pairs(OpenUITimeStatistics) do
        local uiConfig = UIConfig[key]
        if uiConfig.assetName ~= "RequestPanel" then
            for key2, value2 in pairs(value) do
                text = text .. uiConfig.assetName .. "\t" .. value2 .. "\r\n"
            end
        end
    end

    LogRed(text)
end

--打开面板
function UIManager.OpenPanel(id, ...)
    if this.shieldSwitch then
        -- if id == UIName.RewardItemSingleShowPopup then return end
        -- if id == UIName.RewardEquipSingleShowPopup then return end
    end
    local startTime = System.DateTime.Now
    local panel = UIManager.GetPanel(id, true, function ()
        
        -- PlaySoundWithoutClick(SoundConfig.Sound_INTERFACE_Button_Clickdialogue)

    end, ...)
    -- PlaySoundWithoutClick(SoundConfig.Sound_INTERFACE_Button_Clickdialogue)
    local useTime = (System.DateTime.Now - startTime).TotalSeconds
    UIManager.AddUseTime(id, useTime)
    return panel
end

function UIManager.OpenPanelWithNoSound(id, ...)
    if this.shieldSwitch then
        -- if id == UIName.RewardItemSingleShowPopup then return end
        -- if id == UIName.RewardEquipSingleShowPopup then return end
    end
    local startTime = System.DateTime.Now
    local panel = UIManager.GetPanel(id, true, nil, ...)
    local useTime = (System.DateTime.Now - startTime).TotalSeconds
    UIManager.AddUseTime(id, useTime)
    return panel
end

function UIManager.OpenPanelWithSound(id, ...)
    if this.shieldSwitch then
        -- if id == UIName.RewardItemSingleShowPopup then return end
        -- if id == UIName.RewardEquipSingleShowPopup then return end
    end
    local startTime = System.DateTime.Now
    -- PlaySoundWithoutClick()
    local panel = UIManager.GetPanelWithSound(id, true, nil, true,...)
    local useTime = (System.DateTime.Now - startTime).TotalSeconds
    UIManager.AddUseTime(id, useTime)
    
    return panel
end

--异步打开面板
function UIManager.OpenPanelAsync(id, func, ...)
    local startTime = System.DateTime.Now
    local finishAction = function (panel)
        local useTime = (System.DateTime.Now - startTime).TotalSeconds
        UIManager.AddUseTime(id, useTime)
        -- PlaySoundWithoutClick(SoundConfig.Sound_INTERFACE_Button_Clickdialogue)

        if func then
            func(panel)
        end
    end

    UIManager.GetPanel(id, false, finishAction, ...)
end

local SetSortingOrder = function(uiConfig, panel, isStackPanel, ...)
    if isStackPanel then
        if uiConfig.type == UIType.FullType then
            for i = 1, #this.stackList do
                if this.stackList[i] and this.stackList[i].isOpened then
                    this.stackList[i].gameObject:SetActive(false)
                    this.stackList[i]:CloseUI()
                end
            end
        else
            --上一个打开的窗口若是全屏窗口，则失去焦点
            for i = #this.stackList, 1,-1 do
                if this.stackList[i] and  this.stackList[i].isOpened then
                    if this.stackList[i].uiConfig.type == UIType.FullType then
                        this.stackList[i]:LoseFocus()
                    end
                    break
                end
            end
        end

        this.stackList[#this.stackList+1] = panel
        for i = 1, #this.stackList do
            this.stackList[i].transform:SetAsLastSibling()
            this.stackList[i]:SetSortingOrder(i * this.space)
        end
    else
        this.fixedList[#this.fixedList+1] = panel
        panel:SetSortingOrder(uiConfig.sortingOrder)
    end
    panel.gameObject:SetActive(true)
    panel:OpenUI(false, ...)
    panel.openNum = panel.openNum + 1
    delayDestoryList[panel.uiConfig.id] = nil
end
function UIManager.GetPanelWithSound(id, isSync, func,isWithPopSound ,...)
    local uiConfig = UIConfig[id]
    if not id then
        LogError("UIManager====>没有id:")
        return
    end

    if uiConfig == nil then
        LogError("UIManager====>没有找到UI的配置信息:"..id)
        return
    end
    local panel
    local isStackPanel = uiConfig.type == UIType.FullType or uiConfig.type == UIType.Popup
    local list = isStackPanel and this.stackList or this.fixedList
    for i = 1, #list do
        if list[i].uiConfig.id == uiConfig.id then
            panel = list[i]
            --如果找到了，从桟中移除
            table.remove(list, i)
            break
        end
    end
    if uiConfig.type == UIType.Popup then
        PlaySoundWithoutClick(SoundConfig.Sound_INTERFACE_Button_Clickdialogue)
    end
    
    if isWithPopSound then
        Log("UIManager====>assetName:"..uiConfig.assetName)
        if uiConfig.type == UIType.FullType and uiConfig.assetName ~=UIName.RewardItemPopup and uiConfig.assetName ~=UIName.WorkShopCastSuccessPanel and uiConfig.assetName ~=UIName.WorkShopMadeSuccessPanel then
            Log("")

            PlaySoundWithoutClick(SoundConfig.Sound_INTERFACE_Skill_Clickskill)
        end
    end

    local args = {...}
    local action = function(panel)
        local needTrans = false
        if not panel then --在缓存里面找一找
            panel = this.openedList[uiConfig.id]
        end
        if not panel then
            panel = reimport("Modules/"..uiConfig.script)
            this.openedList[uiConfig.id] = panel
            needTrans = true
            panel.uiConfig = uiConfig
            if isSync then
                local gameObject = this.CreatePanel(uiConfig, isStackPanel and this.uiNode or this.fixedNode)
                panel:CreateUI(gameObject)
                --> MultiLanguage
                --this.MultiLanguageCheck(gameObject)
            else
                this.CreatePanelAsync(uiConfig, isStackPanel and this.uiNode or this.fixedNode, function (gameObject)
                    panel:CreateUI(gameObject)
                    --> MultiLanguage
                    --this.MultiLanguageCheck(gameObject)
                    SetSortingOrder(uiConfig, panel, isStackPanel,unpack(args, 1, table.maxn(args)))
                    if func then
                        func(panel)
                        --> MultiLanguage
                        this.MultiLanguageCheck(panel.gameObject)
                    end
                    
                end)
            end
        end
        if isSync then
            SetSortingOrder(uiConfig, panel, isStackPanel,unpack(args, 1, table.maxn(args)))
            if needTrans then
                --> MultiLanguage
                this.MultiLanguageCheck(panel.gameObject)
            end
            return panel
        else
            if panel.gameObject then
                SetSortingOrder(uiConfig, panel, isStackPanel,unpack(args, 1, table.maxn(args)))
            end
        end
        
    end
    
    if isStackPanel and uiConfig.type == UIType.FullType then --如果栈界面有需要播放关闭动画的界面，则新打开的界面需要等到关闭动画播放完成以后
        local closeNum = 0
        local closeTotal = 0
        for i = 1, #this.stackList do
            if this.stackList[i].isOpened and this.stackList[i].OnCloseBefore then
                closeTotal = closeTotal + 1
                this.stackList[i]:OnCloseBefore(function()
                    closeNum = closeNum + 1
                    if closeNum == closeTotal then
                        this.eventSystem:SetActive(true)
                        return action(panel)
                    end
                end)
            end
        end
        if closeTotal == 0 then
            return action(panel)
        else
            this.eventSystem:SetActive(false)
        end
    else
        return action(panel)
    end
end
function UIManager.GetPanel(id, isSync, func, ...)
    local uiConfig = UIConfig[id]
    if not id then
        LogError("UIManager====>没有id:")
        return
    end

    if uiConfig == nil then
        LogError("UIManager====>没有找到UI的配置信息:"..id)
        return
    end
    local panel
    local isStackPanel = uiConfig.type == UIType.FullType or uiConfig.type == UIType.Popup
    local list = isStackPanel and this.stackList or this.fixedList
    for i = 1, #list do
        if list[i].uiConfig.id == uiConfig.id then
            panel = list[i]
            --如果找到了，从桟中移除
            table.remove(list, i)
            break
        end
    end
    if uiConfig.type == UIType.Popup then
        PlaySoundWithoutClick(SoundConfig.Sound_INTERFACE_Button_Clickdialogue)
    end

    local args = {...}
    local action = function(panel)
        local needTrans = false
        if not panel then --在缓存里面找一找
            panel = this.openedList[uiConfig.id]
        end
        if not panel then
            panel = reimport("Modules/"..uiConfig.script)
            this.openedList[uiConfig.id] = panel
            needTrans = true
            panel.uiConfig = uiConfig
            if isSync then
                local gameObject = this.CreatePanel(uiConfig, isStackPanel and this.uiNode or this.fixedNode)
                panel:CreateUI(gameObject)
                --> MultiLanguage
                --this.MultiLanguageCheck(gameObject)
            else
                this.CreatePanelAsync(uiConfig, isStackPanel and this.uiNode or this.fixedNode, function (gameObject)
                    panel:CreateUI(gameObject)
                    --> MultiLanguage
                    --this.MultiLanguageCheck(gameObject)
                    SetSortingOrder(uiConfig, panel, isStackPanel,unpack(args, 1, table.maxn(args)))
                    if func then
                        func(panel)
                        --> MultiLanguage
                        this.MultiLanguageCheck(panel.gameObject)
                    end
                    
                end)
            end
        end
        if isSync then
            SetSortingOrder(uiConfig, panel, isStackPanel,unpack(args, 1, table.maxn(args)))
            if needTrans then
                --> MultiLanguage
                this.MultiLanguageCheck(panel.gameObject)
            end
            return panel
        else
            if panel.gameObject then
                SetSortingOrder(uiConfig, panel, isStackPanel,unpack(args, 1, table.maxn(args)))
            end
        end
        
    end
    
    if isStackPanel and uiConfig.type == UIType.FullType then --如果栈界面有需要播放关闭动画的界面，则新打开的界面需要等到关闭动画播放完成以后
        local closeNum = 0
        local closeTotal = 0
        for i = 1, #this.stackList do
            if this.stackList[i].isOpened and this.stackList[i].OnCloseBefore then
                closeTotal = closeTotal + 1
                this.stackList[i]:OnCloseBefore(function()
                    closeNum = closeNum + 1
                    if closeNum == closeTotal then
                        this.eventSystem:SetActive(true)
                        return action(panel)
                    end
                end)
            end
        end
        if closeTotal == 0 then
            return action(panel)
        else
            this.eventSystem:SetActive(false)
        end
    else
        return action(panel)
    end
end

--界面是否已经打开过
function UIManager.IsOpen(id)
    local uiConfig = UIConfig[id]
    if uiConfig == nil then return end
    local list
    if uiConfig.type == UIType.FullType or uiConfig.type == UIType.Popup then
        list = this.stackList
    else
        list = this.fixedList
    end

    for i = 1,#list do
        if list[i].uiConfig.id == id and list[i].isOpened then
            return true
        end
    end
    return false
end

-- 判断界面是否显示在最上层
function UIManager.IsTopShow(id)
    local uiConfig = UIConfig[id]
    if uiConfig == nil then return end
    local list
    if uiConfig.type == UIType.FullType or uiConfig.type == UIType.Popup then
        list = this.stackList
    else
        list = this.fixedList
    end

    local len = #list
    if list[len].uiConfig.id == id and list[len].isOpened then
        return true
    end
    return false
end

--获取已经打开的面板
function UIManager.GetOpenPanel(id)
    local uiConfig = UIConfig[id]
    if uiConfig == nil then return end
    local list
    if uiConfig.type == UIType.FullType or uiConfig.type == UIType.Popup then
        list = this.stackList
    else
        list = this.fixedList
    end

    for i = 1,#list do
        if list[i].uiConfig.id == id then
            return list[i]
        end
    end
    return nil
end

--关闭面板
function UIManager.ClosePanel(id,isDestroy)
    if not id then
        return
    end
    local uiConfig = UIConfig[id]
    if uiConfig == nil then
        return
    end

    isDestroy = isDestroy or uiConfig.noDestory == 0
    if uiConfig.type == UIType.FullType or uiConfig.type == UIType.Popup then
        this.CloseStackPanel(uiConfig,isDestroy)
    else
        this.CloseFixedPanel(uiConfig,isDestroy)
    end
end

function UIManager.CloseFixedPanel(uiConfig,isDestroy)
    if #this.fixedList == 0 then return end
    local panel
    for i = 1, #this.fixedList do
        if this.fixedList[i].uiConfig.id == uiConfig.id then
            panel = this.fixedList[i]
            table.remove(this.fixedList,i)
            break
        end
    end

    if panel == nil then return end
    local closeAction = function()
        if panel.isOpened then
            panel.gameObject:SetActive(false)
            panel:CloseUI()
        end
    
        if isDestroy then
            this.DelayDestroyPanel(panel)
        end
        this.eventSystem:SetActive(true)
    end
    if panel.OnCloseBefore then
        this.eventSystem:SetActive(false)
        panel:OnCloseBefore(closeAction)
    else
        closeAction()
    end
end

local NoReOpenFilterList = {

}

--关掉桟式面板
function UIManager.CloseStackPanel(uiConfig,isDestroy)
    if #this.stackList == 0 then return end
    local panel = nil
    for i = 1, #this.stackList do
        if this.stackList[i].uiConfig.id == uiConfig.id then
            panel = this.stackList[i]
            table.remove(this.stackList,i)
            break
        end
    end
    if not panel then return end
    local closeAction = function()
        --> battlePanelBehind
        if panel.uiConfig.name == "BattlePanel" and not panel.gameObject.activeSelf then
            return
        end

        if panel.isOpened then
            panel.gameObject:SetActive(false)
            panel:CloseUI()
        end
        --如果是全屏窗口，向后回退到一个全屏窗口为止
        if uiConfig.type == UIType.FullType then
            -- 找到上一个全屏窗口的位置
            local startIndex
            for i = #this.stackList, 1,-1 do
                local panel = this.stackList[i]
                if panel.uiConfig.type == UIType.FullType then
                    startIndex = i
                    break
                end
            end
            for i = startIndex, #this.stackList do
                local panel = this.stackList[i]
                --> no reopen
                local noReOpen = false
                for i = 1, #NoReOpenFilterList do
                    if NoReOpenFilterList[i] == panel.uiConfig.name then
                        noReOpen = true
                        break
                    end
                end
                if noReOpen then
                else
                    panel.gameObject:SetActive(true)
                    panel:OpenUI(true)
                end
            end
        else
            --回退的第一个打开的窗口若是全屏窗口，则被唤醒
            for i = #this.stackList, 1,-1 do
                if this.stackList[i].isOpened then
                    if this.stackList[i].uiConfig.type == UIType.FullType or this.stackList[i].uiConfig.type == UIType.Popup then
                        this.stackList[i]:Focus()
                    end
                    break
                end
            end
        end
        if isDestroy then
            this.DelayDestroyPanel(panel)
        end
        this.eventSystem:SetActive(true)
    end
    if panel.OnCloseBefore then
        this.eventSystem:SetActive(false)
        panel:OnCloseBefore(closeAction)
    else
        closeAction()
    end
end

--加载面板
function UIManager.CreatePanel(uiConfig, parent)
    local prefab = resMgr:LoadAsset(uiConfig.assetName)
    if prefab == nil then
        LogError("资源创建失败！！ 没有找到对应的资源！！ key:"..uiConfig.id..",assetName:"..uiConfig.assetName)
        resMgr:UnLoadAsset(uiConfig.assetName)
        return
    end
    local gameObject = GameObject.Instantiate(prefab)
    gameObject.name = prefab.name
    local transform = gameObject.transform
    transform:SetParent(parent)
    transform.localScale = Vector3.one
    local recTransform = transform:GetComponent("RectTransform")
    recTransform.anchoredPosition3D = Vector3.New(0, 0, 0)
    recTransform.sizeDelta = Vector2.New(0, 0)
    transform.localRotation = Quaternion.identity
    return gameObject
end

--异步加载面板
function UIManager.CreatePanelAsync(uiConfig, parent, func)
    resMgr:LoadAssetAsync(uiConfig.assetName, function(name, prefab)
        if prefab == nil then
            LogError("资源创建失败！！ 没有找到对应的资源！！ key:"..uiConfig.id..",assetName:"..uiConfig.assetName)
            resMgr:UnLoadAsset(uiConfig.assetName)
            return
        end
        local gameObject = GameObject.Instantiate(prefab)
        gameObject.name = prefab.name
        local transform = gameObject.transform
        transform:SetParent(parent)
        transform.localScale = Vector3.one
        local recTransform = transform:GetComponent("RectTransform")
        recTransform.anchoredPosition3D = Vector3.New(0, 0, 0)
        recTransform.sizeDelta = Vector2.New(0, 0)
        transform.localRotation = Quaternion.identity

        if func then
            func(gameObject)
        end
    end)
end

--关闭所有面板
function UIManager.CloseAll(isDestroy)
    local panel = nil
    while(#this.stackList ~= 0)
    do
        panel = this.stackList[1]
        if not IsNull(panel.gameObject) then
            panel.gameObject:SetActive(false)
            panel:CloseUI()
            if isDestroy then
                this.DestroyPanel(panel)
            end
        end

        table.remove(this.stackList,1)
    end

    while(#this.fixedList ~= 0)
        do
        panel = this.fixedList[1]
        if not IsNull(panel.gameObject) then
            panel.gameObject:SetActive(false)
            panel:CloseUI()
            if isDestroy then
                this.DestroyPanel(panel)
            end
        end
        table.remove(this.fixedList,1)
    end

    this.openedList = {}
    delayDestoryList = {}
end

--延时销毁界面，避免频繁的GC开销
function UIManager.DelayDestroyPanel(panel)
    local item = delayDestoryList[panel.uiConfig.id]
    if not item then
        item = { delayTime = 0, panel = panel }
        delayDestoryList[panel.uiConfig.id] = item
    end
    item.delayTime = Time.realtimeSinceStartup + DELAY_TIME * panel.openNum
end

function UIManager.DestroyPanel(panel)
    panel:DestroyUI()
    GameObject.Destroy(panel.gameObject)
    resMgr:UnLoadAsset(panel.uiConfig.assetName)
end

--获取UI配置
function UIManager.GetConfig(key)
    return UIConfig[key]
end

--根据配置关闭游戏的所有面板
function UIManager.CloseAllGamePanel(uiConfig)
    for i, v in pairs(uiConfig) do
        UIManager.ClosePanel(v.id,true)
    end
end

function UIManager.GetLocalPositionToTarget(parent,target)
    local screenPos = this.camera:WorldToScreenPoint (target.transform.position)
    local flag,targetPos = RectTransformUtility.ScreenPointToLocalPointInRectangle (parent.transform,screenPos,this.camera,nil)
    return targetPos
end

--> MultiLanguage
local ExceptPrefabList = {
    "GMPanel"
}

function UIManager.MultiLanguageCheck(gameObject)
    if not Switch_MultiLanguage then
        return
    end
    --> filter
    if table.indexof(ExceptPrefabList, gameObject.name) then
        return 
    end
    if GetLan() ~= 0 then
        local textArr = gameObject:GetComponentsInChildren(typeof(UnityEngine.UI.Text), true)
        local validCntTxt = 0
        for i = 0, textArr.Length - 1 do
            local textStr = textArr[i].text
            if HasLanguageStrKey(textStr) then
                validCntTxt = validCntTxt + 1
                textArr[i].text = GetLanguageStrByStr(textStr)
            end
            local curLan = GetCurLanguage()
            local data = G_MultiLanguage[curLan]
            if data.Font and textArr[i].font and textArr[i].font.name == "OPPOSans-M-2" and data.Font ~= "OPPOSans-M-2" then
                textArr[i].font = poolManager:LoadAsset(data.Font, PoolManager.AssetType.Other)
            end
        end
        local imageArr = gameObject:GetComponentsInChildren(typeof(UnityEngine.UI.Image), true)
        local validCntImg = 0
        for i = 0, imageArr.Length - 1 do
            if imageArr[i].sprite then
                local imgStr = imageArr[i].sprite.name
                if string.sub(imgStr, -3) == "_zh" then
                    validCntImg = validCntImg + 1
                    imageArr[i].sprite = Util.LoadSprite(imgStr)
                    Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.UpdateMultiUI)
                end
            end
        end
    end
end

function UIManager.Dispose()
    UIManager.CloseAll(true)
    GameObject.DestroyImmediate(this.uiRoot)
end

-- 参数: timeScale 震动时长 dx, dy震动偏移量
local isShaking = false
function UIManager.ShakeCamera(timeScale, dx, dy, callBack)
    if isShaking then return end
    isShaking = true

    if this.cameraRoot == nil then
        return
    end

    if not timeScale or timeScale == 0 then
        timeScale = 0.2
    end
    if not dx or not dy or dy == 0 and dx == 0 then
        dx = 100
        dy = 100
    end
    this.cameraRoot:GetComponent("RectTransform"):DOShakeAnchorPos(timeScale, Vector2.New(dx, dy),
                        500, 90, true, true):OnComplete(function ()
        if callBack then callBack() end
        isShaking = false
    end)
end

function UIManager.GetCamera()
    return this.camera
end

return UIManager