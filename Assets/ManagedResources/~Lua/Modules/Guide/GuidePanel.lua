require("Base/BasePanel")
GuidePanel = Inherit(BasePanel)
local this = GuidePanel
local GuideConfig = ConfigManager.GetConfig(ConfigName.GuideConfig)
local curId
local args
local audio
local orginLayer
--初始化组件（用于子类重写）
function this:InitComponent()
    orginLayer = 0
    self.mask = Util.GetGameObject(self.gameObject, "mask")
    self.dialogRoot = Util.GetGameObject(self.gameObject, "dialog")
    self.desc = Util.GetGameObject(self.dialogRoot, "Text"):GetComponent("Text")
    self.dialogTip = Util.GetGameObject(self.dialogRoot, "Tip")
    self.tipButtomRoot = Util.GetGameObject(self.gameObject, "tipButtom")
    self.tipButtomMat = self.tipButtomRoot:GetComponent("Image").material
    self.tipButtomMat:SetFloat("_ScaleX", Screen.width / Screen.height)
    self.tipButtomMat:SetFloat("_R", 0.1)
    self.button = Util.GetGameObject(self.tipButtomRoot, "button")
    self.upArrow = Util.GetGameObject(self.gameObject, "upArrow")

    self.buttonIcon = poolManager:LoadAsset("GuideEffect", PoolManager.AssetType.GameObject)
    self.buttonIcon.name = "icon"
    self.buttonIcon.transform:SetParent(self.tipButtomRoot.transform)
    self.buttonIcon.transform.localPosition = Vector3.zero
    self.buttonIcon.transform.localScale = Vector3.one
    self.buttonIcon.transform:SetAsFirstSibling()

    self.hand = Util.GetGameObject(self.buttonIcon, "GameObject")

    self.handPoint = Util.GetGameObject(self.buttonIcon, "GameObject")
    -- poolManager:LoadLive("live2d_c_yff_0048", self.dialogRoot.transform, Vector3.one * 0.36, Vector3.New(-313, 100))
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.button, this.NextGuide)
    Util.AddClick(this.mask, this.NextGuide)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

function this.SetArrowPosition(id, pos)
    -- this.SetPosition(this.button, pos)
    -- this.SetPosition(this.buttonIcon, pos)
    local v2 = RectTransformUtility.WorldToScreenPoint(UIManager.camera, this.button.transform.position)
    this.tipButtomMat:SetFloat("_X", v2.x / Screen.width)
    this.tipButtomMat:SetFloat("_Y", v2.y / Screen.height)

    this.ExecuteBehavior(GuideConfig[id].BehaviorType, GuideConfig[id].BehaviorArgs)
    this.handPoint:SetActive(true)
 --GuideConfig[id].BehaviorType ~= 13)
end

function this.SetPosition(targetGO, pos)
    local rect = targetGO:GetComponent("RectTransform")
    if pos[3] == 0 then --中心对齐
        rect.anchorMin = Vector2.New(0.5, 0.5)
        rect.anchorMax = Vector2.New(0.5, 0.5)
    elseif pos[3] == 1 then --上对齐
        rect.anchorMin = Vector2.New(0.5, 1)
        rect.anchorMax = Vector2.New(0.5, 1)
    elseif pos[3] == 2 then --下对齐
        rect.anchorMin = Vector2.New(0.5, 0)
        rect.anchorMax = Vector2.New(0.5, 0)
    elseif pos[3] == 3 then --左对齐
        rect.anchorMin = Vector2.New(0, 0.5)
        rect.anchorMax = Vector2.New(0, 0.5)
    elseif pos[3] == 4 then --右对齐
        rect.anchorMin = Vector2.New(1, 0.5)
        rect.anchorMax = Vector2.New(1, 0.5)
    elseif pos[3] == 5 then --左上对齐
        rect.anchorMin = Vector2.New(0, 1)
        rect.anchorMax = Vector2.New(0, 1)
    elseif pos[3] == 6 then --右上对齐
        rect.anchorMin = Vector2.New(1, 1)
        rect.anchorMax = Vector2.New(1, 1)
    elseif pos[3] == 7 then --左下对齐
        rect.anchorMin = Vector2.New(0, 0)
        rect.anchorMax = Vector2.New(0, 0)
    elseif pos[3] == 8 then --右下对齐
        rect.anchorMin = Vector2.New(1, 0)
        rect.anchorMax = Vector2.New(1, 0)
    end
    rect.anchoredPosition = Vector2.New(pos[1], pos[2])
end

function this.SetBtnGOPosition(v3)
    local pos = GuideConfig[this.id].ArrowPosition
    local targetPos = v3 + Vector3.New(pos[1], pos[2], 0) * 0.00375
    this.button:GetComponent("RectTransform").position = targetPos
    local v2 = RectTransformUtility.WorldToScreenPoint(UIManager.camera, targetPos)
    this.tipButtomMat:SetFloat("_X", v2.x / Screen.width)
    this.tipButtomMat:SetFloat("_Y", v2.y / Screen.height)

    -- 播放聚焦动画
    this:PlayFoucsAnim(targetPos)
end

--function this.SetBtnGOSizeData(v2)
--    this.button:GetComponent("RectTransform").sizeDelta = v2
--end

function this.ExecuteBehavior(beType, beArgs)
    if beType == 1 then --点击地图行走
        local _trigger = Util.GetEventTriggerListener(this.button)
        local endFunc
        _trigger.onPointerDown = _trigger.onPointerDown + TileMapController.OnPointerDown
        _trigger.onPointerUp = _trigger.onPointerUp + TileMapController.OnPointerUp
        endFunc = function()
            _trigger.onPointerDown = _trigger.onPointerDown - TileMapController.OnPointerDown
            _trigger.onPointerUp = _trigger.onPointerUp - TileMapController.OnPointerUp
            _trigger.onPointerUp = _trigger.onPointerUp - endFunc
        end
        _trigger.onPointerUp = _trigger.onPointerUp + endFunc
    elseif beType == 2 then --点击界面按钮
        --打开的界面需要设定角度
        if UIManager.IsOpen(UIName.CarbonTypePanelV2) then
            if string.find(beArgs, "CarbonTypePanelV2/Bg/ImageRot/Item") then
                local startIndex, endIndex = string.find(beArgs, "Item")
                if not endIndex then
                    LogError("未找到Item的位置")
                    return
                end

                local nextStartIndex = string.find(beArgs, "/", endIndex + 1)
                local pos =
                    string.sub(beArgs, endIndex + 1, nextStartIndex and nextStartIndex - 1 or string.len(beArgs))
                UIManager.GetOpenPanel(UIName.CarbonTypePanelV2).SetSelectPos(tonumber(pos))
            end
        end

        local isButton = true
        local go = Util.GetGameObject(UIManager.uiNode, beArgs)
        local btn = nil
        if go == nil then
            LogError("找不到游戏物体:" .. beArgs)
        else
            btn = go:GetComponent("Button")
            if btn == nil then
                btn = Util.GetEventTriggerListener(go)
                isButton = false
            end
        end
        this.button:GetComponent("Button").onClick:RemoveAllListeners()
        Util.AddClick(
            this.button,
            function()
                --> 特殊处理
                -- if RewardItemPopup then
                --
                --     RewardItemPopup:ClosePanel()
                -- end
                --    if UIManager.IsOpen(UIName.FightPointPassMainPanel) then
                --        FightPointPassMainPanel.BtView:SetBtnNewIcon(btn, false)
                --    elseif UIManager.IsOpen(UIName.CarbonTypePanel) then
                --        CarbonTypePanel.SetNewTextShow(btn, false)
                --    end
                local curGuideId = curId
                if btn ~= nil then
                    if isButton then
                        btn.onClick:Invoke() --该按钮事件有可能会触发下一步引导，因此需要监听变化
                    else
                        btn:OnPointerClick(nil)
                    end
                end
                if curGuideId == curId then
                    this.NextGuide()
                end
                this.button:GetComponent("Button").onClick:RemoveAllListeners()
                Util.AddClick(this.button, this.NextGuide)
            end
        )

        if btn ~= nil then
            if UIManager.IsOpen(UIName.MainPanel) and string.find(btn.transform.parent.name, "layer") ~= nil then --主界面的ui按钮位置可能会超框，所以做位移处理
                for k, v in pairs(MainPanel.operateIcon) do
                    if v.go == btn.gameObject then
                        MainPanel:MoveToPos(Vector2.New(v.pos, 0))
                        break
                    end
                end
            --elseif UIManager.IsOpen(UIName.FightPointPassMainPanel) then
            --    FightPointPassMainPanel.BtView:SetBtnNewIcon(btn, true)
            --elseif UIManager.IsOpen(UIName.CarbonTypePanel) then
            --    CarbonTypePanel.SetNewTextShow(btn, true)
            end

            this.SetBtnGOPosition(btn.gameObject:GetComponent("RectTransform").position)
        end
    elseif beType == 3 then --点击释放技能
        local _trigger = Util.GetEventTriggerListener(this.button)
        local endFunc
        _trigger.onPointerClick = _trigger.onPointerClick + args[1]._onPointerClick
        endFunc = function()
            _trigger.onPointerClick = _trigger.onPointerClick - args[1]._onPointerClick
            _trigger.onPointerClick = _trigger.onPointerClick - endFunc
            --BattlePanel.BtnPlay:GetComponent("Button").onClick:Invoke() --还原暂停
            BattleManager.ResumeBattle()
        end
        _trigger.onPointerClick = _trigger.onPointerClick + endFunc
        this.SetBtnGOPosition(args[1].RoleIconTran.position)
    elseif beType == 4 then --点击设置战斗自动
        if BattleManager.IsBattlePlaying() then
            BattleManager.PauseBattle()
        end
        local btn = Util.GetGameObject(UIManager.uiNode, beArgs):GetComponent("Button")
        this.button:GetComponent("Button").onClick:RemoveAllListeners()
        Util.AddClick(
            this.button,
            function()
                btn.onClick:Invoke()
                if curId == 19 then
                -- for i=1,5 do --TODO：自动设置完强制全部自动，以处理后续上阵的妖灵师默认自动，并且默认显示策略面板
                --     BattlePanel.RoleManualList[i].auto = true
                -- end
                -- BattlePanel.ShowManual = true
                end
                this.NextGuide()
                this.button:GetComponent("Button").onClick:RemoveAllListeners()
                BattleManager.ResumeBattle()
                Util.AddClick(this.button, this.NextGuide)
            end
        )
        this.SetBtnGOPosition(btn.gameObject:GetComponent("RectTransform").position)
    elseif beType == 5 then --镜头切到位置行走
        local button2 = newObjToParent(this.button, this.button.transform.parent)
        this.button:SetActive(false)
        button2.transform.position = this.button.transform.position

        this.dialogRoot:SetActive(false)
        this.tipButtomRoot:SetActive(false)

        local strs = string.split(beArgs, "#")
        local x = tonumber(strs[1])
        local y = tonumber(strs[2])

        TileMapView.CameraTween(
            x,
            y,
            0.5,
            function()
                local v2 =
                    RectTransformUtility.WorldToScreenPoint(TileMapView.GetCamera(), TileMapView.GetLiveTilePos(x, y))
                v2 = v2 / math.min(Screen.width / 1080, Screen.height / 1920)
                local pos = {v2.x, v2.y, 7}
                this.SetPosition(button2, pos)
                this.SetPosition(this.buttonIcon, pos)
                v2 = RectTransformUtility.WorldToScreenPoint(UIManager.camera, button2.transform.position)
                this.tipButtomMat:SetFloat("_X", v2.x / Screen.width)
                this.tipButtomMat:SetFloat("_Y", v2.y / Screen.height)

                button2:GetComponent("Button").onClick:RemoveAllListeners()

                this.dialogRoot:SetActive(true)
                this.tipButtomRoot:SetActive(true)
                Util.AddClick(
                    button2,
                    function()
                        TileMapController.OnLongClickShowPath(x, y)
                        TileMapController.OnLongClickTile()
                        this.NextGuide()
                        this.button:SetActive(true)
                        GameObject.DestroyImmediate(button2)
                    end
                )
            end
        )
    elseif beType == 6 then --滑动释放技能
        this.button:GetComponent("Button").onClick:RemoveAllListeners()
        local _trigger = Util.GetEventTriggerListener(this.button)
        local endFunc, dragFunc
        local isCanCast = false
        _trigger.onBeginDrag = _trigger.onBeginDrag + args[1]._onBeginDrag
        _trigger.onDrag = _trigger.onDrag + args[1]._onDrag
        _trigger.onEndDrag = _trigger.onEndDrag + args[1]._onEndDrag
        dragFunc = function()
            isCanCast = Vector2.Distance(args[1].RoleIconTran.anchoredPosition, Vector2.zero) > 150

            this.button:GetComponent("RectTransform").position = args[1].RoleIconTran.position
            this.buttonIcon:GetComponent("RectTransform").position = args[1].RoleIconTran.position
            local v2 = RectTransformUtility.WorldToScreenPoint(UIManager.camera, this.button.transform.position)
            this.tipButtomMat:SetFloat("_X", v2.x / Screen.width)
            this.tipButtomMat:SetFloat("_Y", v2.y / Screen.height)
            Util.GetGameObject(this.buttonIcon, "GameObject/Image"):SetActive(false)
            Util.GetGameObject(this.buttonIcon, "Image"):SetActive(false)
        end
        endFunc = function()
            if isCanCast then
                _trigger.onBeginDrag = _trigger.onBeginDrag - args[1]._onBeginDrag
                _trigger.onDrag = _trigger.onDrag - args[1]._onDrag
                _trigger.onEndDrag = _trigger.onEndDrag - args[1]._onEndDrag
                _trigger.onDrag = _trigger.onDrag - dragFunc
                _trigger.onEndDrag = _trigger.onEndDrag - endFunc
                BattleManager.ResumeBattle()
                this.upArrow:SetActive(false)
                this.NextGuide()
                Util.AddClick(this.button, this.NextGuide)
                Util.GetGameObject(this.buttonIcon, "GameObject/Image"):SetActive(true)
                Util.GetGameObject(this.buttonIcon, "Image"):SetActive(false)
            else
                Util.GetGameObject(this.buttonIcon, "GameObject/Image"):SetActive(false)
                Util.GetGameObject(this.buttonIcon, "Image"):SetActive(true)
            end
        end
        _trigger.onDrag = _trigger.onDrag + dragFunc
        _trigger.onEndDrag = _trigger.onEndDrag + endFunc

        this.SetBtnGOPosition(args[1].RoleIconTran.position)
        this.upArrow.transform.position = this.button.transform.position
        this.upArrow:SetActive(true)

        Util.GetGameObject(this.buttonIcon, "GameObject/Image"):SetActive(false)
        Util.GetGameObject(this.buttonIcon, "Image"):SetActive(true)
    elseif beType == 7 then --释放异妖技能
        this.button:GetComponent("Button").onClick:RemoveAllListeners()
        Util.AddClick(
            this.button,
            function()
                args[1]:GetComponent("Button").onClick:Invoke()
                this.NextGuide()
                BattleManager.ResumeBattle()
                this.button:GetComponent("Button").onClick:RemoveAllListeners()
                Util.AddClick(this.button, this.NextGuide)
            end
        )
    elseif beType == 8 then --长按连续升级操作
        this.button:GetComponent("Button").onClick:RemoveAllListeners()
        local _trigger = Util.GetEventTriggerListener(this.button)
        local startFunc
        local endFunc
        local timePressStarted
        _trigger.onPointerDown = _trigger.onPointerDown + RoleInfoPanel._onPointerDown
        startFunc = function()
            timePressStarted = Time.realtimeSinceStartup
        end
        _trigger.onPointerDown = _trigger.onPointerDown + startFunc

        _trigger.onPointerUp = _trigger.onPointerUp + RoleInfoPanel._onPointerUp
        endFunc = function()
            _trigger.onPointerDown = _trigger.onPointerDown - RoleInfoPanel._onPointerDown
            _trigger.onPointerDown = _trigger.onPointerDown - startFunc
            _trigger.onPointerUp = _trigger.onPointerUp - RoleInfoPanel._onPointerUp
            _trigger.onPointerUp = _trigger.onPointerUp - endFunc
            -- 长按时间小于4秒
            if Time.realtimeSinceStartup - timePressStarted <= 0.4 then
                RoleInfoPanel.timePressStarted = timePressStarted
                local btn = Util.GetGameObject(UIManager.uiNode, beArgs):GetComponent("Button")
                btn.onClick:Invoke()
            end

            this.NextGuide()
            this.button:GetComponent("Button").onClick:RemoveAllListeners()
            Util.AddClick(this.button, this.NextGuide)
        end
        _trigger.onPointerUp = _trigger.onPointerUp + endFunc
        this.SetBtnGOPosition(RoleInfoPanel.upLvTrigger.gameObject:GetComponent("RectTransform").position)
    elseif beType == 9 then --关联上阵成员界面对应名字的预设
        local item = RoleListPanel.GetRoleItemByName(beArgs)
        if item then
            local btn = Util.GetGameObject(item, "card"):GetComponent("Button")
            this.button:GetComponent("Button").onClick:RemoveAllListeners()
            Util.AddClick(
                this.button,
                function()
                    local curGuideId = curId
                    btn.onClick:Invoke() --该按钮事件有可能会触发下一步引导，因此需要监听变化
                    if curGuideId == curId then
                        this.NextGuide()
                    end
                    this.button:GetComponent("Button").onClick:RemoveAllListeners()
                    Util.AddClick(this.button, this.NextGuide)
                end
            )
            this.SetBtnGOPosition(item.gameObject:GetComponent("RectTransform").position)
        end
    elseif beType == 10 then --连续升级后突破
        local btn = RoleInfoPanel.upLvBtn:GetComponent("Button")
        this.button:GetComponent("Button").onClick:RemoveAllListeners()
        Util.AddClick(
            this.button,
            function()
                RoleInfoPanel:LvUpClick(true)
                this.NextGuide()
                this.button:GetComponent("Button").onClick:RemoveAllListeners()
                Util.AddClick(this.button, this.NextGuide)
            end
        )
        this.SetBtnGOPosition(btn.gameObject:GetComponent("RectTransform").position)
    elseif beType == 11 then --点击设置战斗2倍速
        local btn = Util.GetGameObject(UIManager.uiNode, beArgs):GetComponent("Button")
        this.button:GetComponent("Button").onClick:RemoveAllListeners()
        Util.AddClick(
            this.button,
            function()
                BattleManager.SetTimeScale(BATTLE_TIME_SCALE_TWO)
                this.NextGuide()
                this.button:GetComponent("Button").onClick:RemoveAllListeners()
                BattleManager.ResumeBattle()
                Util.AddClick(this.button, this.NextGuide)
            end
        )
        this.SetBtnGOPosition(btn.gameObject:GetComponent("RectTransform").position)
    elseif beType == 12 then --点击fixedNode下界面按钮
        this:SetSortingOrder(6000)
        local btn = Util.GetGameObject(UIManager.fixedNode, beArgs):GetComponent("Button")
        this.button:GetComponent("Button").onClick:RemoveAllListeners()
        Util.AddClick(
            this.button,
            function()
                local curGuideId = curId
                btn.onClick:Invoke() --该按钮事件有可能会触发下一步引导，因此需要监听变化
                if curGuideId == curId then
                    this.NextGuide()
                end
                this.button:GetComponent("Button").onClick:RemoveAllListeners()
                Util.AddClick(this.button, this.NextGuide)
            end
        )
        this.SetBtnGOPosition(btn.gameObject:GetComponent("RectTransform").position)
    elseif beType == 13 then --指示界面按钮提醒
        local btn = Util.GetGameObject(UIManager.uiNode, beArgs)
        this.button:GetComponent("Button").onClick:RemoveAllListeners()
        Util.AddClick(
            this.button,
            function()
                this.NextGuide()
                this.button:GetComponent("Button").onClick:RemoveAllListeners()
                Util.AddClick(this.button, this.NextGuide)
            end
        )
        this.SetBtnGOPosition(btn:GetComponent("RectTransform").position)
    elseif beType == 14 then -- 根据当前显示的界面id跳转下一个引导节点，如果当前界面没有显示则等待其显示
        this.dialogRoot:SetActive(false)
        this.mask:SetActive(false)
        this.tipButtomRoot:SetActive(false)
        this.gameObject:GetComponent("Image").raycastTarget = false

        -- 条件节点
        local conditions = {}
        local strs = string.split(beArgs, "|")
        for i, s in ipairs(strs) do
            local ss = string.split(s, "#")
            table.insert(conditions, {tonumber(ss[1]), tonumber(ss[2])})
        end

        -- 检测是否有在最上层的界面
        for _, c in ipairs(conditions) do
            local panel = c[1]
            local nextId = c[2]

            if UIManager.IsTopShow(panel) then
                this.NextGuide(nextId)
                return
            end
        end

        -- 当有符合条件的界面时
        local function OnFocus(id)
            if not UIManager.IsTopShow(id) then
                return
            end
            Timer.New(
                function()
                    for _, c in ipairs(conditions) do
                        local panel = c[1]
                        local nextId = c[2]
                        if id == panel and UIManager.IsTopShow(panel) then
                            this.NextGuide(nextId)
                            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, OnFocus)
                            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnFocus, OnFocus)
                            return
                        end
                    end
                end,
                0.2,
                1
            ):Start()
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, OnFocus)
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnFocus, OnFocus)
    elseif beType == 15 then
        this.dialogRoot:SetActive(false)
        this.mask:SetActive(false)
        this.tipButtomRoot:SetActive(false)

        local ss = string.split(beArgs, "#")
        local params = {}
        for i, s in ipairs(ss) do
            local p = tonumber(s)
            if p then
                params[i] = p
            else
                params[i] = s
            end
        end
        -- 先跳转引导
        -- this.NextGuide()
        -- 在跳转界面
        UIManager.OpenPanel(unpack(params))
    elseif beType == 16 then
        this.canvas.enabled = false
        this.dialogRoot:SetActive(false)
        this.mask:SetActive(false)
        this.tipButtomRoot:SetActive(false)
        local isSkip = false
        local function OnBtnClick(id, str)
            nextDelayTime = 0
            nextDelayChange = true
            isSkip = true
            -- 先跳转引导
            this.NextGuide()
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnBtnClicked, OnBtnClick)
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnBtnClicked, OnBtnClick)

        local function OnUpdateData(id)
            if isSkip then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnUpdateData, OnUpdateData)
                return
            end
            nextDelayTime = 0
            nextDelayChange = true
            -- 先跳转引导
            this.NextGuide()
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnUpdateData, OnUpdateData)
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnUpdateData, OnUpdateData)
    end
end

function this.ShowStory(nextId, OnFocus)
    if StoryMapManager.isShowStory ~= 0 then
        local isShowStory = 1
        if PlayerPrefs.HasKey("StoryMapPanel" .. StoryMapManager.isShowStory .. PlayerManager.uid) then
            isShowStory = PlayerPrefs.GetInt("StoryMapPanel" .. StoryMapManager.isShowStory .. PlayerManager.uid)
        end
        if isShowStory == 1 then
            this.gameObject:SetActive(false)
            local function onCloseStoryMapPanel()
                this.GameSetActive(nextId, OnFocus)
                Game.GlobalEvent:RemoveEvent(GameEvent.GuaJi.CloseStoryMapPanel, onCloseStoryMapPanel)
            end
            Game.GlobalEvent:AddEvent(GameEvent.GuaJi.CloseStoryMapPanel, onCloseStoryMapPanel)
            PlayerPrefs.SetInt("StoryMapPanel" .. StoryMapManager.isShowStory .. PlayerManager.uid, 0)
            StoryMapManager.InitData(StoryMapManager.isShowStory)
        else
            this.NextGuide(nextId)
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, OnFocus)
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnFocus, OnFocus)
        end
    else
        this.NextGuide(nextId)
        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, OnFocus)
        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnFocus, OnFocus)
    end
end

function this.GameSetActive(nextId, OnFocus)
    this.gameObject:SetActive(true)
    this.NextGuide(nextId)
    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, OnFocus)
    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnFocus, OnFocus)
end

function this.ShowGuide(id)
    if GuideConfig[id].ServerNext == -1 then
        --强制新手引导结束了
        CustomEventManager.GameCustomEvent("新手引导结束")
    end

    this.id = id
    this.gameObject:GetComponent("Image").raycastTarget = true
    if GuideConfig[id].Position then
        this.dialogRoot:SetActive(true)
        this.SetPosition(this.dialogRoot, GuideConfig[id].Position)
        if GuideConfig[id].ArrowPosition[3] ~= -1 then
            this.mask:SetActive(false)
            this.tipButtomRoot:SetActive(true)
            this.SetArrowPosition(id, GuideConfig[id].ArrowPosition)
            this.dialogTip:SetActive(false)
        else
            this.mask:SetActive(true)
            this.tipButtomRoot:SetActive(false)
            this.dialogTip:SetActive(true)
        end
    else
        this.dialogRoot:SetActive(false)
        if GuideConfig[id].ArrowPosition[3] ~= -1 then
            this.mask:SetActive(false)
            this.tipButtomRoot:SetActive(true)
            this.SetArrowPosition(id, GuideConfig[id].ArrowPosition)
        elseif GuideConfig[id].BehaviorType and GuideConfig[id].BehaviorType ~= 0 then
            this.ExecuteBehavior(GuideConfig[id].BehaviorType, GuideConfig[id].BehaviorArgs)
        else
            -- 直接进入下一步引导
            this.NextGuide()
            return
        end
    end

    if GuideConfig[id].Desc then
        local str = GuideConfig[id].Desc
        str = string.gsub(str, "{", "<color=#FFEDA1FF>")
        str = string.gsub(str, "}", "</color>")
        this.desc.text = GetLanguageStrById(str)
    end
    if GuideConfig[id].Audio and GuideConfig[id].Audio ~= "" then
        audio = SoundManager.PlaySound(GuideConfig[id].Audio)
    end
    PlayUIAnim(this.tipButtomRoot)
end

-- 下一个
function this.NextGuide(nextId)
    if audio then
        SoundManager.StopSound(audio)
    end
    GuideManager.SyncServer(curId)
    local next = type(nextId) == "number" and nextId or GuideConfig[curId].Next

    if next ~= 0 and GuideConfig[next].OpenType == 0 then --触发方式为0时，直接跳转
        GuideManager.ShowGuide(next)
    elseif next ~= 0 and GuideConfig[next].OpenType == 27 then
        GuideManager.ShowGuide(next)
    elseif next == 0 and GuideConfig[curId].BehaviorType == 14 then -- 分支节点特殊处理
        this.ExecuteBehavior(GuideConfig[curId].BehaviorType, GuideConfig[curId].BehaviorArgs)
    else
        this:ClosePanel()
    end
end
function this:OnSortingOrderChange()
    self.upArrow:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
    Util.AddParticleSortLayer(this.buttonIcon, this.sortingOrder - orginLayer)
    orginLayer = this.sortingOrder
end

--界面打开时调用（用于子类重写）
function this:OnOpen(id, func, ...)
    if not id then
        return
    end
    this.closeFunc = func
    curId = id
    args = {...}
    --if curId == 706 then
    --    Game.GlobalEvent:DispatchEvent(GameEvent.Guide.GuidePanelScrollViewPos)
    --end
    this.gameObject:GetComponent("Image").raycastTarget = true
    local delay = GuideConfig[id].DelayShow
    if delay > 0 then
        this.dialogRoot:SetActive(false)
        this.tipButtomRoot:SetActive(false)
        this.mask:SetActive(false)
        Timer.New(
            function()
                this.ShowGuide(id)
            end,
            delay
        ):Start()
    else
        this.ShowGuide(id)
    end
end

-- 播放动画
function this:PlayFoucsAnim(targetPos)
    local startPos = UIManager.camera:ScreenToWorldPoint(Vector2.New(Screen.width / 2, Screen.height / 2))
    this.buttonIcon:GetComponent("RectTransform").position = startPos
    if this.moveTween then
        this.moveTween:Kill()
    end
    this.tipButtomMat:SetFloat("_R", 1)
    this.dialogRoot:SetActive(false)
    this.moveTween =
        this.buttonIcon:GetComponent("RectTransform").transform:DOMove(targetPos, 0.35):OnComplete(
        function()
            if GuideConfig[this.id].Position then
                this.dialogRoot:SetActive(true)
            end

            if self.tween then
                self.tween:Kill()
            end
            self.tween =
                DoTween.To(
                DG.Tweening.Core.DOGetter_float(
                    function()
                        return 1
                    end
                ),
                DG.Tweening.Core.DOSetter_float(
                    function(progress)
                        self.tipButtomMat:SetFloat("_R", progress)
                    end
                ),
                0.1,
                0.2
            ):SetEase(Ease.Linear)
        end
    )
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if this.sortingOrder == 6300 then
        this:SetSortingOrder(6000)
    end
    --防止频繁修改mat文件造成冲突
    this.tipButtomMat:SetFloat("_X", 0.5)
    this.tipButtomMat:SetFloat("_Y", 0.5)
    this.tipButtomMat:SetFloat("_ScaleX", Screen.width / Screen.height)

    if this.closeFunc then
        this.closeFunc()
        this.closeFunc = nil
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

return GuidePanel
