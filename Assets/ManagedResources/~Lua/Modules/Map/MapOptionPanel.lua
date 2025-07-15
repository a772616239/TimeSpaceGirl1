require("Base/BasePanel")
MapOptionPanel = Inherit(BasePanel)
local this = MapOptionPanel
local addOptConfig = ConfigManager.GetConfig(ConfigName.OptionAddCondition)
local ItemData = ConfigManager.GetConfig(ConfigName.ItemConfig)
local mapEventPointConfig = ConfigManager.GetConfig(ConfigName.MapPointConfig)
local ctrlView = require("Modules/Map/View/MapControllView")
-- 是否有附加条件判定
local ifAdd = {}
local eventConfig = ConfigManager.GetConfig(ConfigName.EventPointConfig)
local optionConfig = ConfigManager.GetConfig(ConfigName.OptionConfig)
local artResConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local lastLive2DId = 0
local nextOptId = 0
local jumpId = 0

-- 接受更新的数据
local panleType
-- 当前触发事件的ID
local eventId
local showValues
local options
local lastStr = ""

local isFirstOpen = false
-- 记录特效的结果
local lastSceneEffect
local preEffPar = ""
-- 选择界面的按钮个数
local btnNum = 0
local orginLayer = 10

-- 4个按钮的初始位置
local InitPos =
{
    [1] = Vector3.New(1093, 314, 0),
    [2] = Vector3.New(1093, 85.3, 0),
    [3] = Vector3.New(1093, -132.6, 0),
    [4] = Vector3.New(1093, -350.5, 0),
}

-- 第一次点击不能点击继续，等文字完了才能下一步
local showDone = false
-- 上个选项的内容完了才能继续
local lastOptionDone = false
--初始化组件（用于子类重写）
function MapOptionPanel:InitComponent()
    orginLayer = 10
    this.btn = {}
    this.btnInfo = {}
    this.addInfo = {}
    -- 初始化4个按钮
    for i = 1, 4 do
        this.btn[i] = Util.GetGameObject(self.gameObject, string.format("OptionRoot/btnRoot/btn%s", i))
        this.btnInfo[i] = Util.GetGameObject(this.btn[i], "Text"):GetComponent("Text")
        this.addInfo[i] = Util.GetGameObject(this.btn[i], "addInfo"):GetComponent("Text")
    end
    -- 选择按钮的父节点
    this.btnRoot = Util.GetGameObject(self.gameObject, "OptionRoot/btnRoot")

    -- 背景显示
    this.bg = Util.GetGameObject(self.gameObject, "bg"):GetComponent("Image")
    -- 文字显示
    this.context = Util.GetGameObject(self.gameObject, "TextMask/context"):GetComponent("Text")
    --
    this.btnNext = Util.GetGameObject(self.gameObject, "goOnButton/Click")
    this.nextRoot = Util.GetGameObject(self.gameObject, "goOnButton")

    -- 选择框显示
    this.textMask = Util.GetGameObject(self.gameObject, "OptionRoot/bgImageTiao")
    -- 名字底框btnContinue
    this.nameFrame = Util.GetGameObject(self.gameObject, "TextMask/Image")
    this.mask = Util.GetGameObject(self.gameObject, "Mask")

    -- 处理对话
    this.right2dRoot = Util.GetGameObject(self.gameObject, "DialogueRoot/rightLive2d")
    -- 左切入
    this.left2dRoot = Util.GetGameObject(self.gameObject, "DialogueRoot/leftLive2d")
    this.RoleName = Util.GetGameObject(self.gameObject, "TextMask/Name"):GetComponent("Text")
    --跳过按钮
    this.btnJump = Util.GetGameObject(self.gameObject, "btnContinue/btnGo")
    this.jumpRoot = Util.GetGameObject(self.gameObject, "btnContinue")
    this.dialogueRoot = Util.GetGameObject(self.gameObject, "DialogueRoot")
    this.optionRoot = Util.GetGameObject(self.gameObject, "OptionRoot")
    -- 显示名字下框
    this.imgGap = Util.GetGameObject(self.gameObject, "TextMask/Image")
    --画风不对的乱入图片
    this.mottoImg = Util.GetGameObject(self.gameObject, "mottoImg")
    -- 对话是突然自我的特效
    this.effectRoot = Util.GetGameObject(self.gameObject, "effectRoot")
    -- 非常好看的场景特效
    this.scenceEffect = Util.GetGameObject(self.gameObject, "scenceEffect")


end

--绑定事件（用于子类重写）
function MapOptionPanel:BindEvent()

    Util.AddClick(this.btnNext, function ()
        if not showDone then return end
        if MissionManager.CanGoNext then
            MissionManager.CanGoNext = false
            OptionBehaviourManager.JumpEventPoint(eventId, nextOptId, self)
        end
    end)

    Util.AddClick(this.btnJump, function ()
        if jumpId and jumpId ~= 0 then
            if MissionManager.CanGoNext then
                MissionManager.CanGoNext = false
                OptionBehaviourManager.JumpEventPoint(eventId, jumpId, self)
            end
        end
    end)
end

--添加事件监听（用于子类重写）
function MapOptionPanel:AddListener()

    Game.GlobalEvent:AddEvent(GameEvent.Event.PointTrigger, this.OnInfoChange)
end

--移除事件监听（用于子类重写）
function MapOptionPanel:RemoveListener()

    Game.GlobalEvent:RemoveEvent(GameEvent.Event.PointTrigger, this.OnInfoChange)
end

--界面打开时调用（用于子类重写）
function MapOptionPanel:OnOpen(...)
   
    --this.HideJumpBtn()
    isFirstOpen = true
    local data = {...}
    if data then
        panleType = data[1]
        eventId = data[2]
        showValues = data[3]
        if not showValues then return end
        options = data[4]


        -- 根据panelType 决定处理方式
        if not panleType then return end
        local isOptionPanel = panleType == 4

        this.PanelInit(isOptionPanel)
        if isFirstOpen then
            this.SetBg()
        end

        if panleType == 3 then
            nextOptId = options[1]
            jumpId = options[2]
            this.RefreshPanel()
        elseif panleType == 4 then
            -- 初始化动画
            this.InitAnimi()
        end
    else

        return
    end
end

function this.OnInfoChange(_showType, _eventId, _showValues, _options)
    PlayUIAnimBack(this.btnRoot)
    isFirstOpen = false
    if eventId ~= _eventId then
        panleType = _showType
        eventId = _eventId
        showValues = _showValues
        if not showValues then return end
        options = _options

        local isOptionPanel = panleType == 4

        this.PanelInit(isOptionPanel)

        if isOptionPanel then
            -- 初始化动画
            this.InitAnimi()
        else
            nextOptId = options[1]
            jumpId = options[2]
            this.RefreshPanel()
        end
    end
end

-- 新手引导隐藏跳过
function this.HideJumpBtn()
    --if GuideManager.IsInMainGuide() then
    
    --    this.jumpRoot:SetActive(false)
    --else
    
    --    this.jumpRoot:SetActive(true)
    --end
end


-- 设置面板显示的初始状态
function this.PanelInit(isOptionPanel)
    this.dialogueRoot:SetActive(not isOptionPanel)
    this.optionRoot:SetActive(isOptionPanel)
    this.btnNext:SetActive(not isOptionPanel)
    this.nextRoot:SetActive(not isOptionPanel)
    this.jumpRoot:SetActive(not isOptionPanel)
    this.nameFrame:SetActive(not isOptionPanel)
    if not isOptionPanel then
        this.ReSetLive2d()
        this.ResetBtnState()
    end
end

--  设置背景图
function this.SetBg()
    local id = MapManager.mapPointId
   
    local resPath = mapEventPointConfig[id].EventPointBg
    if not resPath then return end
    this.bg.sprite = Util.LoadSprite(resPath)
end

-- /////////////////// 对话界面 ////////////////////////
-- 打开面板的时候刷新一次数据
function this.RefreshPanel()
    -- 判断是否是一次性界面
    if not jumpId or jumpId ==  0  or GuideManager.IsInMainGuide() then
        this.jumpRoot:SetActive(false)
    else
        this.jumpRoot:SetActive(true)
    end
    --this.HideJumpBtn()

    local live2dId = tonumber(showValues[1])
    local showStr = GetLanguageStrById(showValues[2])
    local data = eventConfig[eventId]
    local live2dDir = data.ShowDir
    local isDark = data.Isdark == 1
    if isFirstOpen then lastLive2DId = 0 end

    this.AsideSpeak(isDark)
    MapOptionPanel:SetScenceEffect(eventId)
    showDone = false
    -- 对话文字
    if showValues[2] then
        showStr = string.gsub(GetLanguageStrById(showValues[2]), "\\n", "\n")
        showStr = string.gsub(showStr, GetLanguageStrById(11220), NameManager.roleName)
        ShowText(this.context, showStr, this.GetDuration(#showStr), function()
            lastStr = showStr
            local timer = Timer.New(function ()
                showDone = true
            end, 0.1, false, true)
            timer:Start()
        end)
    end
    this.ShowLive2d(live2dId, live2dDir)
    MissionManager.CanGoNext = true
end

function this.GetDuration(strLen)
    if strLen <= 120 then
        return 2
    elseif strLen > 120 and strLen <= 180 then
        return 1.8
    elseif strLen > 180 and strLen <= 240 then
        return 1.5
    else
        return 1.3
    end
end

-- 显示立绘
function this.ShowLive2d(resId, live2dDir)
    if not resId then
        return 
    end
    if resId == 0 then
        this.imgGap:SetActive(false)
        this.RoleName.text = ""
        this.ReSetLive2d()
        lastLive2DId = 0
        return
    else
        this.imgGap:SetActive(true)
    end


    local data = artResConfig[resId]
    local roleSex = NameManager.roleSex

    local resPath = ""
    local live2dRoot
    if data then
        local roleName = ""
        roleName = data.Desc
        if resId == 8001 then  --- 主角专用字段
            resPath = roleSex == ROLE_SEX.BOY and StoryManager.boyRes or StoryManager.bitchRes 
        else
            resPath = data.Name
        end

        this.roleRes = resPath
       
        if live2dDir == 1 then
            live2dRoot = this.right2dRoot
        else
            live2dRoot = this.left2dRoot
        end
        this.RoleName.text = string.gsub(roleName, GetLanguageStrById(11225), NameManager.roleName)
    end

    -- ================== 设置立绘的表现
    local setId = eventConfig[eventId].DialogueViewId
    StoryManager.InitEffect()
    ClearChild(this.effectRoot)
    this.mottoImg:SetActive(resId == 999)
    if lastLive2DId ~= resId and resId ~= 999 then -- 动态加载一次立绘
        this.ReSetLive2d()
        if setId and setId ~= 0 then -- 优化版立绘表现
            this.roleLive = StoryManager.InitLive2dState(setId, resPath, live2dRoot, this.effectRoot, true, this)
        else                         -- 老古董立绘表现
            this.LoadLive2D(data, resPath, live2dRoot)
        end

    elseif resId ~= 0 and resId == 999 then -- 显示图片
        if setId then
           StoryManager.InitImgState(setId, this.mottoImg, this.effectRoot, this)
        end
    elseif lastLive2DId == resId and resId ~= 999 then -- 使用上次的立绘，老是加载累死我啦
        this.roleLive = StoryManager.InitLive2dState(setId, resPath, live2dRoot, this.effectRoot, false, this)
    end
    

    -- ===================== End Set
    lastLive2DId = resId
end

-- 旁白
function this.AsideSpeak(isDark)
    this.mask:SetActive(isDark)
    if isDark then
        this.RoleName.text = ""
        this.ReSetLive2d()
		-- (this.effectRoClearChildot)
        ClearChild(this.effectRoot)
        ClearChild(this.scenceEffect)
        StoryManager.InitEffect()
    end
end

-- 动态加载立绘
function this.LoadLive2D(data, resPath, live2dRoot)
    PlayUIAnim(live2dRoot)
    if not resPath or resPath == "" then
        return 
    end
    this.roleLive = poolManager:LoadLive(resPath, live2dRoot.transform, Vector3.one * data.Scale, Vector3(data.Position[1], data.Position[2], 0))
end

-- 清除立绘
function this.ReSetLive2d()
    if this.roleLive then 
        poolManager:UnLoadLive(this.roleRes, this.roleLive)
        this.roleRes = nil
        this.roleLive = nil
    end

    Util.ClearChild(this.left2dRoot.transform)
    Util.ClearChild(this.right2dRoot.transform)
end

-- 设置场景特效
function MapOptionPanel:SetScenceEffect(eventId)
    local effectStr = eventConfig[eventId].scenceEffec

    if not effectStr then 
        ClearChild(this.scenceEffect)  
        StoryManager.InitEffect()
        return 
    end

    local str = string.split(effectStr, "#")
    local isUse = tonumber(str[1]) == 1
    if not isUse then 
        ClearChild(this.scenceEffect) 
        StoryManager.InitEffect()
        preEffPar = ""  
        return 
    end


    if effectStr ~= preEffPar then 
        ClearChild(this.scenceEffect)  
        StoryManager.InitEffect()
    end
    local resPath = str[2]

    -- 下次需要打开同样的特效，不用重新加载
    if effectStr ~= preEffPar then
        local go = StoryManager.LoadEffect(this.scenceEffect, resPath)
        lastSceneEffect = go
        Util.AddParticleSortLayer(this.scenceEffect, self.sortingOrder + orginLayer)
        orginLayer = self.sortingOrder
    end
    preEffPar = effectStr
end
-- /////////////////// 选择界面 ///////////////////////////////////////////////////////////////////
function this.InitAnimi()
    -- 设置文字内容
    this.SetConext()
    ClearChild(this.effectRoot)
    -- 选择界面直接设置萌嘿
    this.AsideSpeak(true)
    ClearChild(this.scenceEffect)
    StoryManager.InitEffect()

    PlayUIAnim(this.optionRoot, function ()
        this.nextRoot:SetActive(false)
        lastOptionDone = true
        -- 初始化数据
        this.InitData()
        PlayUIAnim(this.btnRoot)
    end)
end

function this.InitOptionBtn()
    for i = 1, 4 do
        this.btn[i]:SetActive(false)
    end
end

-- 实例化按钮数量
function this.InitData()
    for i = 1, #options do
        ifAdd[i] = false
    end

    -- 先隐藏所有按钮
    this.InitOptionBtn()

    this.textMask:SetActive(true)
    this.btnRoot:SetActive(true)
    this.RoleName.text = ""

    -- 显示按钮
    btnNum = #options
    for i = 1, #options do
        this.SetBtnState(i, options[i])
        local addId = optionConfig[options[i]].AddConditionID
        -- 点击跳转
        Util.AddOnceClick(this.btn[i], function ()
            if lastOptionDone then
                lastOptionDone = false
                if ifAdd[i] then
                   
                    MapManager.AddContionType(addId, eventId, options[i], this, function ()
                        lastOptionDone = true
                    end)
                else
                    OptionBehaviourManager.JumpEventPoint(eventId, options[i], this, function ()
                        lastOptionDone = true
                    end)
                end

                -- 试炼副本前往下一层
                this.IsSetMask(options[i])

            end
        end)
    end
end

function this.IsSetMask(optionId)
    if CarbonManager.difficulty == CARBON_TYPE.TRIAL then
        local str = optionConfig[optionId].Info
        local jumpType = optionConfig[optionId].JumpType
        if str == GetLanguageStrById(11227) and jumpType == 4 then
            ctrlView.SetCtrlState(true)
        end
    end
end

-- 设置按钮的所有显示
function this.SetBtnState(index, optionId)
    -- 显示按钮文字内容
    this.btn[index]:SetActive(true)
    local btnString = optionConfig[optionId].Info
    btnString = string.gsub(btnString, GetLanguageStrById(11220), NameManager.roleName)
    this.btnInfo[index].text = GetLanguageStrById(btnString)

    -- 试炼副本的最后一个选择
    if MapTrialManager.IsFinalLevel() and btnNum == 1 then
        this.btnInfo[index].text = GetLanguageStrById(11228)
    end

    -- 设置附加文字内容
    local addId = optionConfig[optionId].AddConditionID
    local btnShowType = optionConfig[optionId].ShowType

    -- 设置附加显示文字
    this.SetAddStr(addId, index, btnShowType)
end

function this.SetAddStr(addId, index, btnShowType)
    -- 设置按钮附加文字内容
    if addId and addId > 0 then
        local showAddString = addId ~= 0
        ifAdd[index] = showAddString
        this.addInfo[index].gameObject:SetActive(showAddString)

        local stringAdd = addOptConfig[addId].Info

        -- 设置按钮显示状态
        this.SetBtnShow(this.btn[index], addId, btnShowType)

        if not addOptConfig[addId].Info or addOptConfig[addId].Info == "" then

            this.addInfo[index].text = ""
            this.addInfo[index].gameObject:SetActive(false)
            return
        end

        -- 如果需要显示数字
        if stringAdd then
            local type = addOptConfig[addId].Type
            local values = addOptConfig[addId].Values
            if type == 2 or type == 5 then -- 显示道具数量
                local colorStr = ""
                if not values or #values == 0 then return end
                for i, v in pairs(values) do
                    local id = v[1]
                    local itemNeed = v[2]
                    local itemHave = BagManager.GetTotalItemNum(id)
                    local name = ItemData[id].Name
                    local color
                    --if type == 2 then
                        color = itemHave >= itemNeed and "#FFFFFFFF" or "#FF0000FF"
                    --elseif type == 5 then
                    --    color = itemHave < itemNeed and "#FFFFFFFF" or "#FF0000FF"
                    --end
                    colorStr = colorStr .. string.format(" %s: <color=%s>%s</color>/%d ", name, color, itemHave, itemNeed)
                end
                this.addInfo[index].text= colorStr
            elseif type == 9 then -- 显示行动力， 有点特殊
                local curEnergy = EndLessMapManager.leftEnergy
                local energyNeed = EndLessMapManager.EnergyCostEnterMap(values[1][1])
                local color = curEnergy >= energyNeed and "#FFFFFFFF" or "#FF0000FF"
                local str = string.format("<color=%s>%s</color>/%d ", color, tostring(curEnergy), energyNeed)
                this.addInfo[index].text= str
            else
                this.addInfo[index].text= stringAdd
            end
        else
            this.addInfo[index].text = ""
            this.addInfo[index].gameObject:SetActive(false)
        end
    else
        this.addInfo[index].text = ""
        this.addInfo[index].gameObject:SetActive(false)
    end
end

--  设置按钮是否显示
function this.SetBtnShow(btn, addId, btnShowType)
    --  根据显示类型判断当前按钮显示状态
    local showBtn = false
    local secondResult = nil
    showBtn, secondResult = MapManager.IsShowOptionBtn(addId, btnShowType)
    if secondResult == nil then
        btn:SetActive(showBtn)
    else
        if secondResult == false and not showBtn then
            btn:SetActive(false)
        else
            btn:SetActive(showBtn)
        end
    end
end

function this.SetConext()
    local showStr = ""
    if not showValues[2] then
        showValues[2] = ""
    end
    showStr = string.gsub(GetLanguageStrById(showValues[2]), "\\n", "\n")
    showStr = string.gsub(showStr, GetLanguageStrById(11220), NameManager.roleName)
    this.context.text = showStr
end

-- 按钮显示初始化
function this.ResetBtnState(callBack)
    this.btnRoot:SetActive(false)
    for i = 1, 4 do
        this.btn[i].transform.localPosition = InitPos[i]
    end
end

--界面关闭时调用（用于子类重写）
function MapOptionPanel:OnClose()
    this.ResetBtnState()
    PlayUIAnimBack(this.optionRoot)
    PlayUIAnimBack(this.btnRoot)
    ClearChild(this.effectRoot)
    ClearChild(this.scenceEffect)
    this.ReSetLive2d()
end

--界面销毁时调用（用于子类重写）
function MapOptionPanel:OnDestroy()

end

return MapOptionPanel