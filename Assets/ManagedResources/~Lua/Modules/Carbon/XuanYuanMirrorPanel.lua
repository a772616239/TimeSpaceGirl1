require("Base/BasePanel")
XuanYuanMirrorPanel = Inherit(BasePanel)
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local this = XuanYuanMirrorPanel
local hasFresh = false
local orginLayer = 0

local type = {
    [1] = {
        -- bg = "N1_btn_adengzhanyi_yingguo",
        name = GetLanguageStrById(23153),
        gameObject = "btnRoot/circle/root/ScrollView/Viewport/Content/jixie" ,
         },--m5
    [2]= {
        -- bg = "N1_btn_adengzhanyi_sulian",
        name = GetLanguageStrById(23150),
        gameObject = "btnRoot/circle/root/ScrollView/Viewport/Content/tishu" ,
    },
    [3]  = {
        -- bg = "N1_btn_adengzhanyi_faguo",
        name = GetLanguageStrById(23151),
        gameObject = "btnRoot/circle/root/ScrollView/Viewport/Content/mofa" ,
    },
    [4] = {
        -- bg = "N1_btn_adengzhanyi_meiguo",
        name = GetLanguageStrById(23152),
        gameObject = "btnRoot/circle/root/ScrollView/Viewport/Content/zhixu" ,
    },--m5
    [5] = {
        -- bg = "N1_btn_adengzhanyi_deguo",--m5
        name = GetLanguageStrById(23154),
        gameObject = "btnRoot/circle/root/ScrollView/Viewport/Content/hundun" ,
    },
    
}
local NumConvertWeek = {[1]=GetLanguageStrById(50138),[2]=GetLanguageStrById(50139),[3]=GetLanguageStrById(50140),[4]=GetLanguageStrById(50141),[5]=GetLanguageStrById(50142),[6]=GetLanguageStrById(50143),[7]=GetLanguageStrById(50137)}
--初始化组件（用于子类重写）
function this:InitComponent()
    this.btnHelp = Util.GetGameObject(self.gameObject, "btnRoot/btnhelp")      
    this.helpPosition = this.btnHelp:GetComponent("RectTransform").localPosition
    this.btnRank = Util.GetGameObject(self.gameObject, "btnRoot/btnRank")      
    this.btnClose = Util.GetGameObject(self.gameObject, "btnRoot/btnBack") 
    
    this.remainTimes = Util.GetGameObject(self.gameObject, "remainTimes") :GetComponent("Text")

    this.effect = Util.GetGameObject(self.gameObject, "CarbonTypePanel_effect")
    this.wind = Util.GetGameObject(self.gameObject, "CarbonTypePanel_effect/juneng_chenggong/GameObject")

    orginLayer = 0

    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
    -- this.BtView =SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    this.AnimRoot = Util.GetGameObject(self.gameObject, "btnRoot/circle/root")
end

local index = 1
--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.btnHelp, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.CarbonType,this.helpPosition.x,this.helpPosition.y) 
    end)
    Util.AddClick(this.btnRank, function()
        UIManager.OpenPanel(UIName.XuanYuanMirrorRankPopup)
    end)
    Util.AddClick(this.btnClose, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnXuanYuanFunctionChange, this.UpdateCarbonContent,1)
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.NextDayRefresh, this.UpdateCount)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.FunctionCtrl.OnXuanYuanFunctionChange, this.UpdateCarbonContent,1)
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.NextDayRefresh, this.UpdateCount)
end

function this:OnOpen()
    this.UpdateCarbonContent(0)
end

--界面打开时调用（用于子类重写）
function this:OnShow(...)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    -- this.BtView:OnOpen({sortOrder = self.sortingOrder,panelType = PanelTypeView.MainCity})
    
    -- 音效
    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)
    -- 播放动画

    this:PlayAni()
    this.PlayScaleAnim()
end

function this:GetOpenTime(id)
    local str = nil
    local isFunction = false
    local config = ConfigManager.GetConfigData(ConfigName.SpecialConfig,70) 
    if config then       
        for k,v in ipairs(string.split(GetLanguageStrById(config.Value),"|")) do 
            isFunction = false
            for n,m in ipairs(string.split(v,"#")) do 
                if tonumber(n) == 1 and tonumber(m) == id then 
                    isFunction = true
                else
                    if isFunction then
                        if str then
                            str = str.. " "..NumConvertWeek[tonumber(m)]
                        else
                            str = NumConvertWeek[tonumber(m)]
                        end
                    end
                end
            end
        end
    end  
    return str 
end



this.UpdateCarbonContent = function(...)
    if not type then
        return
    end
    -- local temp = {...}
    -- local temp = temp[1]
    --if index and index >= 0 then
        --Timer.New(function()
            local openFunctions = {}
            for k,v in pairs(type) do
                local go = Util.GetGameObject(this.gameObject, v.gameObject)
                -- go:GetComponent("Image").sprite = Util.LoadSprite(v.bg)         
                Util.GetGameObject(go, "tip/Text"):GetComponent("Text").text = v.name
                local state = XuanYuanMirrorManager.GetMirrorState(k) == 1

                if not state  then
                    local timeStr = this:GetOpenTime(k)
                    Util.GetGameObject(go, "tip/timeText"):GetComponent("Text").text = timeStr..GetLanguageStrById(10357)
                    Util.GetGameObject(go, "redPoint").gameObject:SetActive(false)
                else
                    openFunctions[k] = {}
                    openFunctions[k].timeComp = Util.GetGameObject(go, "tip/timeText"):GetComponent("Text")--Util.GetGameObject(go, "timeBg/Text"):GetComponent("Text")
                    if XuanYuanMirrorManager.CarbonRedCheck() then
                        Util.GetGameObject(go, "redPoint").gameObject:SetActive(true)
                    else
                        Util.GetGameObject(go, "redPoint").gameObject:SetActive(false)
                    end
                end
                Util.SetGray(go,not state)
                Util.AddOnceClick(go ,function()
                    if state then--false
                        UIManager.OpenPanel(UIName.XuanYuanMirrorPanelList,k) 
                    else
                        PopupTipPanel.ShowTip(type[k].name..GetLanguageStrById(12731))
                    end
                end)
                --透明穿透
                -- go:GetComponent("Image").alphaHitTestMinimumThreshold = 0.1
            end
            this:TimeCountDown(openFunctions)
            this.remainTimes.text = XuanYuanMirrorManager.GetTimeTip()
        --end, index):Start()
    --end
    
end

function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.wind, self.sortingOrder - orginLayer)
    -- this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
    orginLayer = self.sortingOrder
end

function this.UpdateCount()
    this.remainTimes.text = XuanYuanMirrorManager.GetTimeTip()
end


function this:PlayAni()
    -- 开门音效
    if not this.isPlayDoorAudio then
        this.isPlayDoorAudio = true
        Timer.New(function ()
            if this.isPlayDoorAudio then
                SoundManager.PlaySound(SoundConfig.Sound_Door)
            end
        end, 1.3):Start()
    end
end

function this.PlayScaleAnim()
    local isOpen = FunctionOpenMananger.GetRootState(PanelTypeView.Carbon)
    if isOpen then
        PlayUIAnim(this.AnimRoot)
    else
        PlayUIAnimBack(this.AnimRoot)
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    this.isPlayDoorAudio = false
    self.gameObject:SetActive(false)
    PlayerManager.carbonType = 2   

end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    SubUIManager.Close(this.UpView)
    -- SubUIManager.Close(this.BtView)
end

--刷新时间
function this:TimeCountDown(_openFunctions)
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    for k,v in pairs(_openFunctions) do
        v.remainTime = XuanYuanMirrorManager.GetMirrorEndTime(k) - PlayerManager.serverTime
        v.timeComp.text = TimeToHMS(v.remainTime)..GetLanguageStrById(12732)
    end
    self.timer = Timer.New(function()
        for k,v in pairs(_openFunctions) do
            v.remainTime = v.remainTime - 1
            if v.remainTime > 0 then
                v.timeComp.text = TimeToHMS(v.remainTime)..GetLanguageStrById(12732)
            else
                this:UpdateCarbonContent(1)
            end
        end
    end, 1, -1, true)
    self.timer:Start()
end

return XuanYuanMirrorPanel