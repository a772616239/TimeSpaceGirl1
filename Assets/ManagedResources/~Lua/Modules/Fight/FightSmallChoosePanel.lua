require("Base/BasePanel")
FightSmallChoosePanel = Inherit(BasePanel)
local smallListGo = {}
local mainLevelSettingConfig = ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)
local mainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local curSmallFightId = 0
local curMiddleFightId = 0
local difficultType = FightDifficultyState.SimpleLevel
local curDifficulSData = {}

local mapNpc = "live2d_npc_map"
local mapNpc2 = "live2d_npc_map_nv"
local npc, scale
--文字描述
local chaterInfoList = {}
--初始化组件（用于子类重写）
function FightSmallChoosePanel:InitComponent()

    self.bg = Util.GetGameObject(self.transform, "bg")
    screenAdapte(self.bg)
    --self.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
    self.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    self.worldBtn = Util.GetGameObject(self.transform, "worldBtn")
    self.curMapBg = Util.GetGameObject(self.gameObject, "curMap/curMapBg"):GetComponent("Image")
    for i=1, 20 do
        smallListGo[i] = Util.GetGameObject(self.gameObject, "curMap/curMapBg/mapAreaPre (".. i ..")")
    end
    self.selectMap = Util.GetGameObject(self.gameObject, "curMap/selectMap")

    npc = NameManager.roleSex == ROLE_SEX.BOY and mapNpc or mapNpc2
    scale = NameManager.roleSex == ROLE_SEX.BOY and Vector3.one or Vector3.one * 0.5

    self.liveNode = poolManager:LoadLive(npc, Util.GetTransform(self.selectMap, "pos"), scale, Vector3.zero)
    local SkeletonGraphic = self.liveNode:GetComponent("SkeletonGraphic")
    if SkeletonGraphic then
        SkeletonGraphic.AnimationState:SetAnimation(0, "move2", true)
        if FightPointPassManager.GetRoleDirection()==1 then
            SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, 180, 0)
        else
            SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, 0, 0)
        end
    end


    self.titleText = Util.GetGameObject(self.gameObject, "chapterInfo/titleText"):GetComponent("Text")
    for i = 1, 4 do
        chaterInfoList[i] = Util.GetGameObject(self.gameObject, "chapterInfo/Text1 (" .. i .. ")"):GetComponent("Text")
    end
end

--绑定事件（用于子类重写）
function FightSmallChoosePanel:BindEvent()

    Util.AddClick(self.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.worldBtn, function()
       UIManager.OpenPanel(UIName.FightMiddleChoosePanel,curSmallFightId,false)
    end)
end

--添加事件监听（用于子类重写）
function FightSmallChoosePanel:AddListener()

end

--移除事件监听（用于子类重写）
function FightSmallChoosePanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function FightSmallChoosePanel:OnOpen(smallFightId)

    curSmallFightId = smallFightId
    curMiddleFightId = math.floor(smallFightId/1000)
    difficultType = smallFightId%10

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FightSmallChoosePanel:OnShow()

    --self.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    self:OnShowPanelData()
    SoundManager.PlaySound(SoundConfig.Sound_LittleMap)
end

--初始化界面
function FightSmallChoosePanel:OnShowPanelData()
    if self.liveNode == nil then
        npc = NameManager.roleSex == ROLE_SEX.BOY and mapNpc or mapNpc2
        scale = NameManager.roleSex == ROLE_SEX.BOY and Vector3.one or Vector3.one * 0.5
        self.liveNode = poolManager:LoadLive(npc, Util.GetTransform(self.selectMap, "pos"), scale, Vector3.zero)
    end
    local SkeletonGraphic = self.liveNode:GetComponent("SkeletonGraphic")
    if SkeletonGraphic then
        SkeletonGraphic.AnimationState:SetAnimation(0, "move2", true)
        if FightPointPassManager.GetRoleDirection()==1 then
            SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, 180, 0)
        else
            SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, 0, 0)
        end
    end
    local curMiddleConFigData = mainLevelSettingConfig[curMiddleFightId]
    if curMiddleConFigData == nil then return end
    self.curMapBg.sprite = Util.LoadSprite(curMiddleConFigData.ChapterBg)
    self.curMapBg:SetNativeSize()
    self.curMapBg.transform.localScale = Vector3.one
    self.curMapBg.transform.localPosition = Vector3.New(curMiddleConFigData.ChapterBgPos[1],curMiddleConFigData.ChapterBgPos[2],0)

    curDifficulSData = {}
    if difficultType == FightDifficultyState.SimpleLevel then
        curDifficulSData = curMiddleConFigData.SimpleLevel
    elseif difficultType == FightDifficultyState.NrmalLevel then
        curDifficulSData = curMiddleConFigData.NormalLevel
    elseif difficultType == FightDifficultyState.DifficultyLevel then
        curDifficulSData = curMiddleConFigData.DifficultyLevel
    elseif difficultType == FightDifficultyState.HellLevel then
        curDifficulSData = curMiddleConFigData.HellLevel
    elseif difficultType == FightDifficultyState.NightmareLevel then
        curDifficulSData = curMiddleConFigData.NightmareLevel
    end
    for i = 1, math.max(#curDifficulSData, #smallListGo) do
        local go = smallListGo[i]
        if not go then
            go=newObject(smallListGo[1])
            go.transform:SetParent(Util.GetGameObject(self.gameObject, "curMap/curMapBg").transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition=Vector3.zero;
            go.gameObject.name = "mapAreaPre (".. i ..")"
            smallListGo[i] = go
        end
        go.gameObject:SetActive(false)
    end

    for i = 1, #curDifficulSData do
        self:SingleSmallFightShow(i)
    end

    --章节文字显示
    self.titleText.text = curMiddleConFigData.Name .."·"..NumToComplexFont[curMiddleFightId]
    local descs = string.split(curMiddleConFigData.info, "#")
    for i = 1, #chaterInfoList do
        chaterInfoList[i].text = descs[i] or ""
    end
end
function FightSmallChoosePanel:SingleSmallFightShow(indext)
    smallListGo[indext]:SetActive(true)
    local curSmallFightConFig = mainLevelConfig[curDifficulSData[indext]]
    smallListGo[indext]:GetComponent("RectTransform").anchoredPosition = Vector2.New(curSmallFightConFig.LevelPointPosition[1], curSmallFightConFig.LevelPointPosition[2])
    Util.GetGameObject(smallListGo[indext].transform, "icon"):SetActive((math.floor((curSmallFightConFig.Id%100)/10))%5 ~= 0)
    Util.GetGameObject(smallListGo[indext].transform, "icon2"):SetActive((math.floor((curSmallFightConFig.Id%100)/10))%5 == 0)
    if curSmallFightConFig.Id == curSmallFightId then
        self:SelectRenPos(smallListGo[indext])
    end
end
function FightSmallChoosePanel:SelectRenPos(_parent)
    self.selectMap.transform:SetParent(_parent.transform.parent)
    self.selectMap.transform.localPosition = _parent.transform.localPosition
    self.selectMap.transform.localScale = Vector3.one
    --self.selectMap.transform.localPosition = Vector3.zero
end
--界面关闭时调用（用于子类重写）
function FightSmallChoosePanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function FightSmallChoosePanel:OnDestroy()

    --SubUIManager.Close(self.UpView)
    smallListGo = {}
    if self.liveNode then
        poolManager:UnLoadLive(npc, self.liveNode, PoolManager.AssetType.GameObject)
        self.liveNode = nil
    end
end

return FightSmallChoosePanel