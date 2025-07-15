require("Base/BasePanel")
LaddersTypePanel = Inherit(BasePanel)
local this = LaddersTypePanel
local orginLayer = 0
local trigger = nil
local SpecialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local type = {
        [1] = {--跨服竞技场
            open = true,
            id = FUNCTION_OPEN_TYPE.laddersChallenge,
            bg = "cn2-X1_wuxianzhanzhen_02_zh",
            name = GetLanguageStrById(50167),
            resetTime = string.format("<color=#a6b6d8>%s</color>", GetLanguageStrById(SpecialConfig[58].Value)),
            tip = GetLanguageStrById(50304),
            spevialId = 153,
            redPointType = RedPointType.LaddersChallenge,
            r = 0,
        },
        [2] = {--混乱之治
            open = true,
            id = FUNCTION_OPEN_TYPE.ChaosZZ,
            bg = "cn2-X1_kuafu_rukou",
            name = GetLanguageStrById(16010080),
            resetTime = "",
            tip = "每周一0点~周五22点开启",
            spevialId = 551,  --奖励
            redPointType = -1,
            r = 0,
        },
        [3] = {--nil
            open = true,
            id = nil,
            bg = "cn2-X1_wuxianzhanzhen_02_zh",
            name = GetLanguageStrById(50167),
            resetTime = string.format("<color=#a6b6d8>%s</color>", GetLanguageStrById(SpecialConfig[58].Value)),
            tip = GetLanguageStrById(50304),
            spevialId = 153,
            redPointType = -1,
            r = 0,
        },
        [4] = {--nil
            open = true,
            id =nil,
            bg = "cn2-X1_wuxianzhanzhen_02_zh",
            name = GetLanguageStrById(50167),
            resetTime = string.format("<color=#a6b6d8>%s</color>", GetLanguageStrById(SpecialConfig[58].Value)),
            tip = GetLanguageStrById(50304),
            spevialId = 153,
            redPointType = -1,
            r = 0,
        },
        default =
        {
            id = -1,
        }
}
this.ItemViews = {}

--初始化组件（用于子类重写）
function LaddersTypePanel:InitComponent()
    orginLayer = 0

    this.Bg = Util.GetGameObject(self.gameObject,"Bg")
    this.backBtn = Util.GetGameObject(self.gameObject, "Bg/backBtn")
    -- this.title = Util.GetGameObject(self.gameObject,"Bg/Title/title"):GetComponent("Text")
    this.ImageRot = Util.GetGameObject(self.gameObject,"Bg/ImageRot")
    this.ImageMinRot = Util.GetGameObject(self.gameObject,"Bg/ImageMinRot")

    --列表
    this.rewardPre = Util.GetGameObject(self.gameObject, "Bg/rewardPre")
    local rect = Util.GetGameObject(self.gameObject, "Bg/rect")
    local v = rect:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, rect.transform,
            this.rewardPre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.NoviceItemList = {}--存储itemview 重复利用

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
end

--绑定事件（用于子类重写）
function LaddersTypePanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function LaddersTypePanel:AddListener()
end

--移除事件监听（用于子类重写）
function LaddersTypePanel:RemoveListener()
end

--副本类型 
function LaddersTypePanel:OnOpen()
    this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})

    -- fristZ = 0 -- 初始调整旋转位置
    -- rotstionAngle = 0 -- 旋转角度
    -- speed = 4 --旋转度倍数
    --this.ImageRot.transform.localEulerAngles = Vector3.New(0,0,fristZ)
    -- for i = 1, this.ImageRot.transform.childCount do
    --     local Index = Util.GetGameObject(this.ImageRot.transform:GetChild(i-1).gameObject,"Index")
    --     Index.transform:GetChild(0).name = i
    --     this.RefreshItem(this.ImageRot.transform:GetChild(i-1).gameObject,this.GetItem(i))
    -- end
    this.ScrollView:SetData(type, function (index, go)
        this.RefreshItem(go, type[index])
        -- allAchievement[index] = go
    end)
    -- if not trigger then
    --     trigger = Util.GetEventTriggerListener(this.Bg)
    --     trigger.onBeginDrag = trigger.onBeginDrag + this.OnBeginDrag
    --     trigger.onDrag = trigger.onDrag + this.OnDrag
    --     trigger.onEndDrag = trigger.onEndDrag + this.OnEndDrag
    -- end
end

--beginDragPosY = 0
--direction = 0 --单纯记录方向，单次只计算一个方向 1是上 -1是下
--isDrag = false
-- function this.OnBeginDrag(p,d)
-- end

-- function this.OnEndDrag(p,d)
--     isDrag = false
-- end

-- function this.OnDrag(p,d)
--     if d.delta.y > 0 then--向上划
--         if rotstionAngle == (this.GetItemCount() - 2)*40 then
--             return
--         end

--         rotstionAngle = rotstionAngle+1*speed
--         this.ImageRot.transform.localEulerAngles = Vector3.New(0,0,rotstionAngle)
--         this.ImageMinRot.transform.localEulerAngles = Vector3.New(0,0,-rotstionAngle)
--     elseif d.delta.y < 0 then--向下划
--         if rotstionAngle == 0 then
--             return
--         end

--         rotstionAngle = rotstionAngle-1*speed
--         this.ImageRot.transform.localEulerAngles = Vector3.New(0,0,rotstionAngle)
--         this.ImageMinRot.transform.localEulerAngles = Vector3.New(0,0,-rotstionAngle)
--     end
-- end

--界面打开时调用（用于子类重写）
function LaddersTypePanel:OnShow(...)
    this.HeadFrameView:OnShow()

    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)-- 音效

    CarbonManager.GetMissionLevelData()
end

function this.GetItem(index)
    if type[index] then
        return type[index]
    else
        return type.default
    end
end

function this.GetItemCount()
    local count = 0
    for i = 1, #type do
        if type[i] then
            count = count+1
        end
    end
    return count
end

function this.RefreshItem(go,data)
    local Icon = Util.GetGameObject(go,"Icon")
   -- local Name = Util.GetGameObject(go,"Icon/Name"):GetComponent("Text")
    local Desc = Util.GetGameObject(go,"Icon/Desc"):GetComponent("Text")
    local ResetTime = Util.GetGameObject(go,"Icon/ResetTime"):GetComponent("Text")
     if data.id == nil then
        local nilData = Util.GetGameObject(go,"nil")
        nilData:SetActive(true)
        return
     end
    if data.id ~= -1 then
        BindRedPointObject(data.redPointType,Util.GetGameObject(Icon, "RedPoint"))
        Icon.gameObject:SetActive(true)
        Icon:GetComponent("Image").sprite = Util.LoadSprite(data.bg)
       -- Icon:GetComponent("Image").alphaHitTestMinimumThreshold = 0.1
        --Name.text = data.name
        Desc.text = data.tip
        ResetTime.text = string.format(data.resetTime)

        Icon:GetComponent("Button").onClick:RemoveAllListeners()
        if data.open then
            Util.SetGray(Icon,false)
            Icon:GetComponent("Button").enabled = true
            Util.AddClick(Icon, function()
                this.BtnClick(data.id)
            end)
        else
            -- 要置灰 不能点击
            Util.SetGray(Icon,true)
            Icon:GetComponent("Button").enabled = false
        end

        Icon:GetComponent("Button").onClick:RemoveAllListeners()

        if ActTimeCtrlManager.SingleFuncState(data.id) == false then
            Util.SetGray(Icon,true)
        end

        local items = this.GetItems(data.spevialId)
        if this.ItemViews[go] then
            for i = 1, #items do
                this.ItemViews[go][i]:OnOpen(false, items[i], 0.5, nil, nil, nil, nil, nil)
                this.ItemViews[go][i].transform.rotation = Vector3.zero
            end
        else
            this.ItemViews[go] = {}
            for i = 1, #items do
                this.ItemViews[go][i]= SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go,"Icon/ItemGrid").transform)
                this.ItemViews[go][i]:OnOpen(false, items[i], 0.5, nil, nil, nil, nil, nil)
                this.ItemViews[go][i].transform.rotation = Vector3.zero
            end
        end

        Util.AddClick(Icon, function()
            this.BtnClick(data.id)
        end)
    else
        Icon.gameObject:SetActive(false)
    end
end

function this.BtnClick(id)
    if id == FUNCTION_OPEN_TYPE.laddersChallenge then
        local peakednessTime= LaddersArenaManager.GetLeftTime()-435600 
        
        if ActTimeCtrlManager.SingleFuncState(id)  then
            NetManager.WorldArenaUnLockRequest(function (msg)
                if msg.unLock and peakednessTime > 0 then
                    local _, myRankInfo = ArenaManager.GetRankInfo()
                    local myRank = myRankInfo.personInfo.rank
                    -- if myRank > 100 then
                    --     PopupTipPanel.ShowTip(GetLanguageStrById(50301))
                    --     return
                    -- end
                    if myRank == -1 then
                        NetManager.RequestArenaRankData(1, function()
                            local _, myRankInfo = ArenaManager.GetRankInfo()
                            local myRank = myRankInfo.personInfo.rank
                            -- if myRank == -1 then
                            --     PopupTipPanel.ShowTip(GetLanguageStrById(50301))
                            --     return
                            -- else
                                UIManager.OpenPanel(UIName.LaddersMainPanel)
                            -- end
                        end)
                    else
                        NetManager.RequestArenaRankData(1, function()
                            UIManager.OpenPanel(UIName.LaddersMainPanel)
                        end)
                    end
                else
                    PopupTipPanel.ShowTip(GetLanguageStrById(10175))
                end
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.laddersChallenge))
        end
    elseif id == FUNCTION_OPEN_TYPE.ChaosZZ  then   --混乱之治
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ChaosZZ) then
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ChaosZZ))
            return
        end
        if ActTimeCtrlManager.SingleFuncState(id) then
            NetManager.CampSimpleInfoGetReq(function (msg)
                if msg.camp ~= 0 then
                    NetManager.CampWarInfoGetReq(function (msg)
                        UIManager.OpenPanel(UIName.ChaosMainPanel, msg)
                    end)
                else
                    UIManager.OpenPanel(UIName.ChaosSelectCampPanel, msg)
                end
            end)
        else
            PopupTipPanel.ShowTip("混乱之治尚未开始")
        end
    end
end

function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.wind, self.sortingOrder - orginLayer)

    orginLayer = self.sortingOrder
end

function LaddersTypePanel.GetItems(index)
    local items = string.split(SpecialConfig[index].Value,"|")
    local itemList = {}
    for i = 1, #items do
        local item = string.split(items[i],"#")
        table.insert(itemList,{[1] = item[1],[2] = item[2]})
    end
    return itemList
end

--界面关闭时调用（用于子类重写）
function LaddersTypePanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function LaddersTypePanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    this.ItemViews = {}
    -- trigger.onBeginDrag = trigger.onBeginDrag - this.OnBeginDrag
    -- trigger.onDrag = trigger.onDrag - this.OnDrag
    -- trigger.onEndDrag = trigger.onEndDrag - this.OnEndDrag
    -- trigger = nil
end

return LaddersTypePanel