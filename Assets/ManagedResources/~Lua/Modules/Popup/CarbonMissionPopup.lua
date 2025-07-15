require("Base/BasePanel")
local ctrlView = require("Modules/Map/View/MapControllView")
CarbonMissionPopup = Inherit(BasePanel)
local this = CarbonMissionPopup
local carBonMissionData = ConfigManager.GetConfig(ConfigName.ChallengeMissionConfig)
-- 文字预设
local textPre = {}
-- 图标预设
local listIconPre = {}
local isStartExplore = false
local started = false
local orginLayer
--初始化组件（用于子类重写）
function CarbonMissionPopup:InitComponent()

    orginLayer = 10
    this.effect = Util.GetGameObject(self.gameObject, "effect")
    this.cloudEffect = Util.GetGameObject(self.gameObject, "effect/EFFECT")
    screenAdapte(this.effect)

    this.btnConfirm = Util.GetGameObject(self.gameObject, "btnConfirm")
    this.missionPre = Util.GetGameObject(self.gameObject, "TextPre")
    this.grid = Util.GetGameObject(self.gameObject, "grid")

    -- 初始化个文字预设
    listIconPre[1] = Util.GetGameObject(self.gameObject, "effect/image/renwuliebiao")
    listIconPre[2] = Util.GetGameObject(self.gameObject, "effect/image/renwuliebiao_1")
    listIconPre[3]= Util.GetGameObject(self.gameObject, "effect/image/renwuliebiao_2")
    listIconPre[4] = Util.GetGameObject(self.gameObject, "effect/image/renwuliebiao_3")
    listIconPre[5] = Util.GetGameObject(self.gameObject, "effect/image/renwuliebiao_4")

    textPre[1] = Util.GetGameObject(listIconPre[1], "Text1"):GetComponent("Text")
    textPre[2] = Util.GetGameObject(listIconPre[2], "Text2"):GetComponent("Text")
    textPre[3] = Util.GetGameObject(listIconPre[3], "Text3"):GetComponent("Text")
    textPre[4] = Util.GetGameObject(listIconPre[4], "Text4"):GetComponent("Text")
    textPre[5] = Util.GetGameObject(listIconPre[5], "Text5"):GetComponent("Text")

    -- 信纸
    this.letterAni = Util.GetGameObject(self.gameObject, "effect"):GetComponent("Animator")
    this.exploreAni = Util.GetGameObject(self.gameObject, "disappear"):GetComponent("Animator")
    this.explreGo = Util.GetGameObject(self.gameObject, "disappear")
    this.upCloud = Util.GetGameObject(self.gameObject, "effect/UI_effect_TanSuo_TanSuoYunDuo/image/Shang")
    this.downCloud = Util.GetGameObject(self.gameObject, "effect/UI_effect_TanSuo_TanSuoYunDuo/image/Xia")

    this.shang = Util.GetGameObject(self.gameObject, "disappear/yun/Shang")
    this.Xia = Util.GetGameObject(self.gameObject, "disappear/yun/Xia")
end

--绑定事件（用于子类重写）
function CarbonMissionPopup:BindEvent()

    Util.AddClick(this.btnConfirm, function ()
        -- 点击后依次播放动画
        this.BtnCallBack(isStartExplore)
    end)
end

function this.BtnCallBack(start)
    if start then
        this.StartMission(1.8)
    else
        this.SetStartAni(1)
    end
    this.letterAni:SetBool("isEnd", not start)
end

-- 播放开始探索
function this.SetStartAni(timeScale)
    this.shang:GetComponent("RectTransform").anchoredPosition = Vector2.New(-22,643)
    this.Xia:GetComponent("RectTransform").anchoredPosition = Vector2.New(18,-802)
    Timer.New(function()
        this.explreGo:SetActive(true)
        isStartExplore = true
        this.upCloud:SetActive(false)
        this.downCloud:SetActive(false)
    end, timeScale):Start()
end

-- 开始任务
function this.StartMission(timeScale)
    this.exploreAni:SetTrigger("close")
    Timer.New(function()
        this:ClosePanel()
        this.StartExplore()
    end, timeScale):Start()
end

-- 开始地图探索
function this.StartExplore()
    if not started then
        started = true
        NetManager.CarbonMissionStartRequest(function(msg)
            local mission = MissionManager.carBonMission

            if msg.leftTime > 0 then --开启任务
                -- 刷新任务
                Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnMissionAdd, mission)
            else
                MapManager.isOpen = false
            end
        end)
    end
end

--添加事件监听（用于子类重写）
function CarbonMissionPopup:AddListener()

end

--移除事件监听（用于子类重写）
function CarbonMissionPopup:RemoveListener()

end

function CarbonMissionPopup:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.cloudEffect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function CarbonMissionPopup:OnOpen(_mapPanel)

    --mapPanel = _mapPanel
    started = false
    this.InitMission()
    isStartExplore = false
end

function this.InitMission()
    for i = 1, 5 do
        listIconPre[i]:SetActive(false)
    end

    local data = carBonMissionData[MissionManager.carBonMission.id]
    if data then
        local contexts = string.split(data.Target, "#")
        for i = 1, #contexts do
            local str = ""
            str = contexts[i] or contexts[i]
            textPre[i].text = str
            listIconPre[i]:SetActive(true)
            textPre[i].gameObject:SetActive(true)

        end
    end
end

--界面关闭时调用（用于子类重写）
function CarbonMissionPopup:OnClose()

    this.effect.transform:SetParent(self.transform)
    this.explreGo:SetActive(false)
    this.upCloud:SetActive(true)
    this.downCloud:SetActive(true)

    -- 检测引导
    GuideManager.CheckCarbonGuild(CARBON_TYPE.NORMAL)
end

--界面销毁时调用（用于子类重写）
function CarbonMissionPopup:OnDestroy()

end

return CarbonMissionPopup