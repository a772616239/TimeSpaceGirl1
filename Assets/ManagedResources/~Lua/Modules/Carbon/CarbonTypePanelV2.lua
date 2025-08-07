require("Base/BasePanel")
CarbonTypePanelV2 = Inherit(BasePanel)
local this = CarbonTypePanelV2
local orginLayer = 0
local trigger = nil
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local isDraging=false
local type = {
    [1] = {
        [2] = {--物资收集
            open = true,
            id = FUNCTION_OPEN_TYPE.DAILYCHALLENGE_COIN,
            bg = "cn2-X1_fubenrukou_01",
            name = GetLanguageStrById(50159),
            resetTime = string.format("<color=#a6b6d8>%s</color>",specialConfig[58].Value),
            tip = GetLanguageStrById(specialConfig[59].Value),
            redPointType = RedPointType.HeroExplore,
            r = 0,
        },
        [3] = {--深渊试炼
            open = true,
            id = FUNCTION_OPEN_TYPE.MONSTER_COMING,
            bg = "cn2-X1_fubenrukou_02",
            name = GetLanguageStrById(50212),
            resetTime = string.format("<color=#6eaeae>%s</color>",specialConfig[115].Value),
            tip = GetLanguageStrById(23141),
            redPointType = RedPointType.EpicExplore,
            r = 20,
        },
        [4] = {--遗忘之城
            open = true,
            id = FUNCTION_OPEN_TYPE.BLITZ_STRIKE,
            bg = "cn2-X1_fubenrukou_03",
            name = GetLanguageStrById(50213),
            resetTime = string.format("<color=#c296c9>%s</color>",specialConfig[117].Value),
            tip = GetLanguageStrById(23021),
            redPointType = RedPointType.ForgottenCity,
            r = 60,
        },
        [5] = {--破碎王座
            open = true,
            id = FUNCTION_OPEN_TYPE.Hegemony,
            bg = "cn2-X1_fubenrukou_04",
            name = GetLanguageStrById(50214),
            resetTime = string.format("<color=#c78787>%s</color>",specialConfig[119].Value),
            tip = GetLanguageStrById(23022),
            redPointType = RedPointType.LegendExplore,
            r = 80,
        },
        default =
        {
            id = -1,
        }
    },
    [2] = {
        [2] = {--异端之战
            open = true,
            id = FUNCTION_OPEN_TYPE.TRIAL,
            bg = "cn2-X1_shikongzhanchang_guanqia1",
            name = GetLanguageStrById(50215),
            resetTime = string.format("<color=#242424>%s</color>",specialConfig[66].Value),
            tip = GetLanguageStrById(specialConfig[67].Value),
            redPointType = RedPointType.BattleOfHeresy,
            r = 0,
        },
        [3] = {--腐化之战
            open = true,
            id = FUNCTION_OPEN_TYPE.PEOPLE_MIRROR,
            bg = "cn2-X1_shikongzhanchang_guanqia2", 
            name = GetLanguageStrById(50216),
            resetTime = string.format("<color=#242424>%s</color>",GetLanguageStrById(specialConfig[75].Value)),
            tip = GetLanguageStrById(specialConfig[76].Value),
            redPointType = RedPointType.WarOfCorruption,
            r = 20,
        },
        [4] = {--梦魇入侵
            open = true,
            id = FUNCTION_OPEN_TYPE.MINSKBATTLE,
            bg = "cn2-X1_shikongzhanchang_guanqia3",
            name = GetLanguageStrById(50217),
            resetTime = string.format("<color=#242424>%s</color>",specialConfig[122].Value),
            tip = GetLanguageStrById(specialConfig[122].Value),
            --tip = "",--GetLanguageStrById(23142),
            redPointType = RedPointType.NightmareInvasion,
            r = 60,
        },
        [5] = {--迷雾之战
            open = true,
            id = FUNCTION_OPEN_TYPE.ALAMEIN_WAR,
            bg = "cn2-X1_shikongzhanchang_guanqia4",
            name = GetLanguageStrById(50218),
            resetTime = string.format("<color=#242424>%s</color>", specialConfig[122].Value),
            tip = GetLanguageStrById(specialConfig[84].Value),
            redPointType = RedPointType.BattleOfFog,
            r = 80,
        },
        -- [6] = {--无尽
        --     open = true,
        --     id = FUNCTION_OPEN_TYPE.ENDLESS,
        --     bg = "m5_img_zhanyi_wujinlilian_ditu",
        --     name = GetLanguageStrById(),
        --     resetTime = string.format("<color=#DB9A9A>%s</color>",specialConfig[83].Value),
        --     -- tip = string.format("<color=#DB9A9A>%s</color>",specialConfig[84].Value),
        --     tip = specialConfig[84].Value,
        --     redPointType = RedPointType.EndLess
        -- },
        default =
        {
            id = -1,
        }
    }
}
local carbonType = 0
local carbons = {}

--初始化组件（用于子类重写）
function CarbonTypePanelV2:InitComponent()
    orginLayer = 0

    this.Bg = Util.GetGameObject(self.gameObject,"Bg")
    this.backBtn = Util.GetGameObject(self.gameObject, "Bg/backBtn")
    this.title = Util.GetGameObject(self.gameObject,"Bg/Title/title"):GetComponent("Text")
    this.ImageRot = Util.GetGameObject(self.gameObject,"Bg/ImageRot")
    this.ImageMinRot = Util.GetGameObject(self.gameObject,"Bg/ImageMinRot")

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
end

local index = 1
--绑定事件（用于子类重写）
function CarbonTypePanelV2:BindEvent()
    Util.AddClick(
        this.backBtn,
        function()
            this:ClosePanel()
        end
    )

    for k,v in ipairs(carbons) do
        local data 
        if not type[PlayerManager.carbonType][k] then
            data = type[PlayerManager.carbonType].default
        else
            data = type[PlayerManager.carbonType][k]
        end
        if data.redPointType ~= -1 then
            BindRedPointObject(data.redPointType,Util.GetGameObject(v, "RedPoint"))
        end
    end
    UpdateBeat:Add(this.update, this)

end

local lastPos=Vector3.zero
local isMoving = false
function this.update()
        if Input.GetMouseButtonUp(0) then
            SoundManager.StopMusic()
        end
        Log("CarbonTypePanelV2 update")
        if Input.GetMouseButton(0) then

            Log("CarbonTypePanelV2 GetMouseButton")
            local v2 = Input.mousePosition
            if isDraging then
              
                local abX= math.abs( lastPos.x -v2.x)
                local abY= math.abs( lastPos.y -v2.y)
                  Log("CarbonTypePanelV2 isDraging abX"..abX.."abY:"..abY)
                if abX>=1 or
                    abY>=1
                then
                    isMoving=true
                    SoundManager.PlayMusic(SoundConfig.Sound_INTERFACE_Mainmenu_OpenMission,false)
                else
                    isMoving=false
                    SoundManager.StopMusic()
                end

            end
            lastPos=v2
        end

end


--添加事件监听（用于子类重写）
function CarbonTypePanelV2:AddListener()
end

--移除事件监听（用于子类重写）
function CarbonTypePanelV2:RemoveListener()
end

--副本类型  1 综合   2  万象
function CarbonTypePanelV2:OnOpen()
    carbonType = PlayerManager.carbonType 

    if carbonType == 1 then
        -- 清除一下选得副本类型
        CarbonManager.difficulty = 0    
        this.BtView.gameObject:SetActive(true) 
        NetManager.BlitzInfo(function(msg)
            CheckRedPointStatus(RedPointType.ForgottenCity)
        end)
        this.BtView:OnOpen({sortOrder = self.sortingOrder, panelType = PanelTypeView.Carbon})  
        this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    elseif carbonType == 2 then
        this.BtView.gameObject:SetActive(false)
        this.BtView:OnOpen({sortOrder = self.sortingOrder, panelType = PanelTypeView.MainCity})  
        this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
    else
         -- 清除一下选得副本类型
         CarbonManager.difficulty = 0
         this.BtView.gameObject:SetActive(true)  
         this.BtView:OnOpen({sortOrder = self.sortingOrder, panelType = PanelTypeView.Carbon})  
         this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    end


    fristZ = 0 -- 初始调整旋转位置
    RotstionAngle = 0 -- 旋转角度
    speed = 4 --旋转度倍数
    this.ImageRot.transform.localEulerAngles = Vector3.New(0,0,fristZ)
    for i = 1, this.ImageRot.transform.childCount do
        local Index = Util.GetGameObject(this.ImageRot.transform:GetChild(i-1).gameObject,"Index")
        Index.transform:GetChild(0).name = i
        this.RefreshItem(this.ImageRot.transform:GetChild(i-1).gameObject,this.GetItem(i))
    end
    
    if not trigger then
        trigger = Util.GetEventTriggerListener(this.Bg)
        trigger.onBeginDrag = trigger.onBeginDrag + this.OnBeginDrag
        trigger.onDrag = trigger.onDrag + this.OnDrag
        trigger.onEndDrag = trigger.onEndDrag + this.OnEndDrag
    end
end

function this.GetItem(index)
    if type[carbonType][index] then
        return type[carbonType][index]
    else
        return type[carbonType].default
    end
end

function this.GetItemCount()
    local count = 0
    for i = 1, #type[carbonType] do
        if type[carbonType][i] then
            count = count+1
        end
    end
    return count
end


--beginDragPosY = 0
--direction = 0 --单纯记录方向，单次只计算一个方向 1是上 -1是下
--isDrag = false
function this.OnBeginDrag(p,d)
    Log("OnBeginDrag")
    SoundManager.StopMusic()
    SoundManager.PlayMusic(SoundConfig.Sound_INTERFACE_Mainmenu_OpenMission,false)
    isDraging=true
end

function this.OnEndDrag(p,d)
        isDrag = false
        Log("OnEndDrag")
        SoundManager.StopMusic()
    isDraging=false

end

function this.OnDrag(p,d)
    Log("OnDrag y:".. tostring(d.delta.y))
    isDraging=true
    -- if d.delta.y<3 and d.delta.y>-3 then
    --     SoundManager.StopMusic()
    --     Log("OnDrag StopMusic:".. tostring(d.delta.y))
    -- else
    --     isDraging=true
    -- end
      SoundManager.PlayMusic(SoundConfig.Sound_INTERFACE_Mainmenu_OpenMission)
    if d.delta.y > 0 then--向上划
        if RotstionAngle == (this.GetItemCount() - 2)*40 then
            SoundManager.StopMusic()
            return
        end
        if isDraging then
              
        end


        RotstionAngle = RotstionAngle+1*speed
        this.ImageRot.transform.localEulerAngles = Vector3.New(0,0,RotstionAngle)
        this.ImageMinRot.transform.localEulerAngles = Vector3.New(0,0,-RotstionAngle)
    elseif d.delta.y < 0 then--向下划
        if RotstionAngle == 0 then
            SoundManager.StopMusic()
            return
        end
        
        -- if isDraging then
        --         SoundManager.PlayMusic(SoundConfig.Sound_INTERFACE_Mainmenu_OpenMission)
        -- end

        RotstionAngle = RotstionAngle-1*speed
        this.ImageRot.transform.localEulerAngles = Vector3.New(0,0,RotstionAngle)
        this.ImageMinRot.transform.localEulerAngles = Vector3.New(0,0,-RotstionAngle)
    else
        SoundManager.StopMusic()
        Log("OnDrag0")
    end
end

function this.RefreshItem(go,data)
    local Icon = Util.GetGameObject(go,"Icon")
    local Name = Util.GetGameObject(go,"Icon/Name"):GetComponent("Text")
    local Desc = Util.GetGameObject(go,"Icon/Desc"):GetComponent("Text")
    local ResetTime = Util.GetGameObject(go,"Icon/ResetTime"):GetComponent("Text")

    if data.id ~= -1 then
        BindRedPointObject(data.redPointType, Util.GetGameObject(Icon, "RedPoint"))
        Icon.gameObject:SetActive(true)
        Icon:GetComponent("Image").sprite = Util.LoadSprite(data.bg)
        -- Icon:GetComponent("Image").alphaHitTestMinimumThreshold = 0.1
        Name.text = data.name
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

        Util.AddClick(Icon, function()
            this.BtnClick(data.id)
        end)
    else
        Icon.gameObject:SetActive(false)
    end
end

--界面打开时调用（用于子类重写）
function CarbonTypePanelV2:OnShow(...)
    this.HeadFrameView:OnShow()
    carbonType = PlayerManager.carbonType 
    
    if carbonType == 1 then
        this.backBtn.gameObject:SetActive(false)
        this.title.text = GetLanguageStrById(23143)
    elseif carbonType == 2 then
        this.backBtn.gameObject:SetActive(true)
        this.title.text = GetLanguageStrById(23025)
    else
        this.backBtn.gameObject:SetActive(false)
    end

    -- 音效
    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)

    CarbonManager.GetMissionLevelData()

    CheckRedPointStatus(RedPointType.LegendExplore)
end

function this.BtnClick(id)
    if id == FUNCTION_OPEN_TYPE.DAILYCHALLENGE_COIN then
        JumpManager.GoJump(67001)
    elseif id == FUNCTION_OPEN_TYPE.MONSTER_COMING then
        JumpManager.GoJump(1011)
    elseif id == FUNCTION_OPEN_TYPE.EXPEDITION then
        -- if ActTimeCtrlManager.SingleFuncState(id) then
        --     if #ExpeditionManager.nodeInfo <= 0 then
        --         if ExpeditionManager.expeditionLeve == -1 then
        --             NetManager.GetExpeditionRequest(
        --                 2,
        --                 function()
        --                     JumpManager.GoJump(64001)
        --                 end
        --             )
        --         else
        --             NetManager.GetExpeditionRequest(
        --                 ExpeditionManager.expeditionLeve,
        --                 function()
        --                     JumpManager.GoJump(64001)
        --                 end
        --             )
        --         end
        --     else
        --         JumpManager.GoJump(64001)
        --     end
        -- else
        --     if ExpeditionManager.ExpeditionState == 2 then
        --         PopupTipPanel.ShowTipByLanguageId(12195)
        --     else
        --         PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.EXPEDITION))
        --     end
        -- end
    elseif id == FUNCTION_OPEN_TYPE.MINSKBATTLE then
        JumpManager.GoJump(76001)
    elseif id == FUNCTION_OPEN_TYPE.TRIAL then
        JumpManager.GoJump(30001)
    elseif id == FUNCTION_OPEN_TYPE.PEOPLE_MIRROR then
        JumpManager.GoJump(21500)
    elseif id == FUNCTION_OPEN_TYPE.ALAMEIN_WAR then
        JumpManager.GoJump(21700)
    elseif id == FUNCTION_OPEN_TYPE.Hegemony then
        JumpManager.GoJump(8301)
    elseif id == FUNCTION_OPEN_TYPE.BLITZ_STRIKE then
        JumpManager.GoJump(8101)
    end
    PlaySoundWithoutClick(SoundConfig.Sound_Click_Iron)
end

function this:OnSortingOrderChange()
    orginLayer = self.sortingOrder
    if carbonType == 1 then
        this.BtView.gameObject:SetActive(true)
        this.BtView:SetOrderStatus({sortOrder = self.sortingOrder})
    elseif carbonType == 2 then    
        this.BtView.gameObject:SetActive(false)
        this.BtView.gameObject:SetActive(true)
    else
    end
end

--界面关闭时调用（用于子类重写）
function CarbonTypePanelV2:OnClose()
    carbonType = 0
    UpdateBeat:Remove(this.update, this)

end

--界面销毁时调用（用于子类重写）
function CarbonTypePanelV2:OnDestroy()
    if this.BtView then
        SubUIManager.Close(this.BtView)
    end
    SubUIManager.Close(this.HeadFrameView)
    carbons = {}

    trigger.onBeginDrag = trigger.onBeginDrag - this.OnBeginDrag
    trigger.onDrag = trigger.onDrag - this.OnDrag
    trigger.onEndDrag = trigger.onEndDrag - this.OnEndDrag
    trigger = nil
end

function this.SetSelectPos(pos)
    if type[PlayerManager.carbonType][pos] then
        RotstionAngle = type[PlayerManager.carbonType][pos].r
        this.ImageRot.transform.localEulerAngles = Vector3.New(0, 0, RotstionAngle)
        this.ImageMinRot.transform.localEulerAngles = Vector3.New(0, 0, -RotstionAngle)
    else
        LogRed("未找到Pos:" .. tostring(pos))
    end
end

return CarbonTypePanelV2