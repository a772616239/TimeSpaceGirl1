require("Base/BasePanel")
ExpeditionMainPanel = Inherit(BasePanel)
local this = ExpeditionMainPanel
local nodeGrid = {}
local nodeItemGrid = {}
local timer = Timer.New()
local npc = ""
local GetCurNodeInfo = {}--当前操作层数据
local SkeletonGraphic--动画组件
local isPlayerMove = false--是否在播放人物行走动画
local isAllHaveAttack = false--是否有状态不一致情况   说明不是失败过  就是未领取圣物状态
local nodeGoTable = {}
local timer2 = Timer.New()
local liveNodeList = {}
local targetPosGoAndData
local UI_effect_ExpeditionReward = nil
local curexpeditionNodeConfigIcon = nil
local expeditionLeveTable = {
    [-1] = {numStr = GetLanguageStrById(10006),nodDi1 = "m5_img_shenrudiying-dizuo-01",nodDi2 = "m5_img_shenrudiying-dizuo-liangmian"}, --m5
    [1] = {numStr = GetLanguageStrById(10005),nodDi1 = "m5_img_shenrudiying-dizuo-01",nodDi2 = "m5_img_shenrudiying-dizuo-liangmian"}, --m5
    [2] = {numStr = GetLanguageStrById(10006),nodDi1 = "m5_img_shenrudiying-dizuo-01",nodDi2 = "m5_img_shenrudiying-dizuo-liangmian"}, --m5
    [3] = {numStr = GetLanguageStrById(10007),nodDi1 = "m5_img_shenrudiying-dizuo-01",nodDi2 = "m5_img_shenrudiying-dizuo-liangmian"}, --m5
    [4] = {numStr = GetLanguageStrById(10007),nodDi1 = "m5_img_shenrudiying-dizuo-02",nodDi2 = "d_danaotiangong_xuanzhongguang_02"},
}
local layListGrid = {}
local cursortingOrder = 0
local cursortingOrder2 = 0
local expeditionNodeConfig = ConfigManager.GetConfig(ConfigName.ExpeditionNodeConfig)
local AllLayNodeList = {}
local shotTiemeLevel = {}--临时层级
--初始化组件（用于子类重写）
function ExpeditionMainPanel:InitComponent()
    cursortingOrder = 0
    self.parent = Util.GetGameObject(self.gameObject, "parent")
    self.gridMask = Util.GetGameObject(self.gameObject, "rect/grid/mask")
    self.gridMaskImage = Util.GetGameObject(self.gameObject, "rect/grid/mask/Image"):GetComponent("RectTransform")
    self.bg1 = Util.GetGameObject(self.gameObject, "bg/bg (1)")
    self.bg2 = Util.GetGameObject(self.gameObject, "bg/bg (2)")
    self.backBtn = Util.GetGameObject(self.parent, "lowGO/btnBack")
    self.Btn1 = Util.GetGameObject(self.parent, "lowGO/Btn1")
    self.Btn2 = Util.GetGameObject(self.parent, "lowGO/Btn2")
    self.Btn3 = Util.GetGameObject(self.parent, "lowGO/Btn3")
    self.Btn4 = Util.GetGameObject(self.parent, "upLeftGo/Btn4")
    self.Btn4Image = Util.GetGameObject(self.parent, "upLeftGo/Image")
    self.Btn5 = Util.GetGameObject(self.parent, "lowGO/Btn5")
    self.helpBtn = Util.GetGameObject(self.parent, "upLeftGo/helpBtn")
    self.redPoint = Util.GetGameObject(self.parent, "upLeftGo/Btn4/redPoint")
    self.helpPos = Util.GetGameObject(self.parent, "upLeftGo/helpBtn"):GetComponent("RectTransform").localPosition
    self.titleImageText = Util.GetGameObject(self.parent, "titleImage/titleImage (1)"):GetComponent("Text")
    self.timeTextGo = Util.GetGameObject(self.parent, "titleImage/timeText")
    self.timeText = Util.GetGameObject(self.parent, "titleImage/timeText"):GetComponent("Text")
    nodeGrid = {}
    nodeItemGrid = {}
    for i = 1, 1 do
        nodeGrid[i] = Util.GetGameObject(self.gameObject, "rect/grid/singlePre ("..i..")")
        local nodeGridItemsGri = {}
        for j = 1, 3 do
            nodeGridItemsGri[j] = Util.GetGameObject(nodeGrid[i], "itemList/item ("..j..")")
        end
        nodeItemGrid[i] = nodeGridItemsGri
    end
    npc = NameManager.roleSex == ROLE_SEX.BOY and "live2d_npc_map" or "live2d_npc_map_nv"
    local scale = NameManager.roleSex == ROLE_SEX.BOY and Vector3.one*0.2 or Vector3.one * 0.12
    self.liveNode = poolManager:LoadLive(npc, Util.GetTransform(self.parent, "playerLive"), scale, Vector3.zero)
    SkeletonGraphic = self.liveNode:GetComponent("SkeletonGraphic")
    if SkeletonGraphic then
        SkeletonGraphic.AnimationState:SetAnimation(0, "move2", true)
        SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, 0, 0)
    end
    self.singlePre = Util.GetGameObject(self.transform, "singlePre")
    self.grid = Util.GetGameObject(self.transform, "rect/grid")
    self.Holy = Util.GetGameObject(self.gameObject, "bg/Holy")
    self.UI_Effect_ChuanSongMen = Util.GetGameObject(self.gameObject, "bg/UI_Effect_ChuanSongMen")
    self.UI_Effect_ChuanSongMen_LanSe = Util.GetGameObject(self.gameObject, "bg/UI_Effect_ChuanSongMen/UI_Effect_ChuanSongMen_LanSe")
    self.UI_Effect_ChuanSongMen_JinSe = Util.GetGameObject(self.gameObject, "bg/UI_Effect_ChuanSongMen/UI_Effect_ChuanSongMen_JinSe")
    self.UI_Effect_ChuanSongMen_LanSeBtn = Util.GetGameObject(self.gameObject, "bg/UI_Effect_ChuanSongMen/UI_Effect_ChuanSongMen_LanSe/click")
    self.UI_Effect_ChuanSongMen_JinSeBtn = Util.GetGameObject(self.gameObject, "bg/UI_Effect_ChuanSongMen/UI_Effect_ChuanSongMen_JinSe/click")
end

--绑定事件（用于子类重写）
function ExpeditionMainPanel:BindEvent()
    Util.AddClick(self.backBtn, function()
        if isPlayerMove == false then
            ExpeditionManager.SetExpeditionPanelIsOpen(0)
            
            self:ClosePanel()
        end
    end)
    Util.AddClick(self.Btn1, function()
        UIManager.OpenPanel(UIName.ExpeditionHeroListResurgencePopup)
    end)
    Util.AddClick(self.Btn2, function()
        UIManager.OpenPanel(UIName.ExpeditionHeroListInfoPopup)
    end)
    Util.AddClick(self.Btn3, function()
        UIManager.OpenPanel(UIName.ExpeditionHalidomPanel)
    end)
    Util.AddClick(self.Btn4, function()
        if isPlayerMove == false then
            UIManager.OpenPanel(UIName.TreasureOfHeavenPanel)
        end
    end)
    Util.AddClick(self.Btn5, function()
        if isPlayerMove == false then
            JumpManager.GoJump(20005)
        end
    end)
    Util.AddClick(self.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Expedition,self.helpPos.x,self.helpPos.y)
    end)
    Util.AddClick(self.UI_Effect_ChuanSongMen_LanSeBtn, function()
        
        if #shotTiemeLevel > 1 then
            MsgPanel.ShowTwo(GetLanguageStrById(10496), function()
            end, function()
                ExpeditionManager.expeditionLeve = shotTiemeLevel[1]
                self:RefreshManagerData()
            end)
        else
            ExpeditionManager.expeditionLeve = shotTiemeLevel[1]
            self:RefreshManagerData()
        end
        
    end)
    Util.AddClick(self.UI_Effect_ChuanSongMen_JinSeBtn, function()
        
        if #shotTiemeLevel > 1 then
            MsgPanel.ShowTwo(GetLanguageStrById(10497), function()
            end, function()
                ExpeditionManager.expeditionLeve = shotTiemeLevel[2]
                self:RefreshManagerData()
            end)
        else
            ExpeditionManager.expeditionLeve = shotTiemeLevel[1]
            self:RefreshManagerData()
        end
        
    end)
    BindRedPointObject(RedPointType.Expedition_Treasure, self.redPoint)
end

--添加事件监听（用于子类重写）
function ExpeditionMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Expedition.RefreshPlayAniMainPanel, self.PlayerMoveFun, self)
    Game.GlobalEvent:AddEvent(GameEvent.Expedition.RefreshMainPanel, self.OnShowNodeData, self)
end

--移除事件监听（用于子类重写）
function ExpeditionMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Expedition.RefreshPlayAniMainPanel, self.PlayerMoveFun, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Expedition.RefreshMainPanel, self.OnShowNodeData, self)
end

--界面打开时调用（用于子类重写）
function ExpeditionMainPanel:OnOpen()
    ExpeditionManager.SetExpeditionPanelIsOpen(1)
    
    if ExpeditionManager.ExpeditionState == 3 then
        ExpeditionManager.SetExpeditionState(1)
    end
    self:OnShowNodeData(true)
    if ExpeditionManager.GetActivityStarOpenRedPoint() then
        PlayerPrefs.SetInt(PlayerManager.uid.."Expedition", 1)
    end
end
function ExpeditionMainPanel:OnSortingOrderChange()
    self.gridMask:GetComponent("Canvas").sortingOrder = self.sortingOrder + 1
    self.parent:GetComponent("Canvas").sortingOrder = self.sortingOrder + 20

    self.UI_Effect_ChuanSongMen_LanSeBtn:GetComponent("Canvas").sortingOrder = self.sortingOrder + 10
    self.UI_Effect_ChuanSongMen_JinSeBtn:GetComponent("Canvas").sortingOrder = self.sortingOrder + 10
    Util.AddParticleSortLayer(self.UI_Effect_ChuanSongMen_LanSe, self.sortingOrder - cursortingOrder )
    Util.AddParticleSortLayer(self.UI_Effect_ChuanSongMen_JinSe, self.sortingOrder - cursortingOrder )
    cursortingOrder = self.sortingOrder
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ExpeditionMainPanel:OnShow()
    -- 音效
    ExpeditionManager.SetExpeditionPanelIsOpen(1)
    ExpeditionManager.RefreshPanelShowByState()--检测是否是间隔阶段
    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)
    local endTime = 0
    endTime = ExpeditionManager.startTime + tonumber(ConfigManager.GetConfigData(ConfigName.GlobalSystemConfig,JumpType.Expedition).SeasonEnd) - GetTimeStamp() +
            ConfigManager.GetConfigData(ConfigName.GlobalSystemConfig,JumpType.Expedition).SeasonInterval * 60
    self:RemainTimeDown(self.timeTextGo,self.timeText,endTime)
end
--实例化层数信息
function ExpeditionMainPanel:OnShowNodeData(isMoveGrid)
    isPlayerMove = false
    isAllHaveAttack = false
    nodeGoTable = {}
    self.titleImageText.text = GetLanguageStrById(10498)..expeditionLeveTable[ExpeditionManager.expeditionLeve].numStr..GetLanguageStrById(10319)
    self.bg1:SetActive(ExpeditionManager.expeditionLeve ~= 4)
    self.bg2:SetActive(ExpeditionManager.expeditionLeve == 4)
    ExpeditionManager.ExpeditionRrefreshFormation()--刷新编队
    ExpeditionManager.GetActivityIsShowRedPoint(false,"1")--刷新红点
    --self.mask:SetActive(isPlayerMove)
    self.UI_Effect_ChuanSongMen:SetActive(false)
    self.Holy.transform:SetParent(self.transform)
    self.Holy:SetActive(false)
    --节点
    AllLayNodeList = ExpeditionManager.GetAllLayNodeList()--所有层所有节点信息
    if AllLayNodeList == nil then return end
    local curAllLayNodeList = {}
    for i = #AllLayNodeList, 1, -1 do--从下到上显示  所以倒序
        table.insert(curAllLayNodeList,AllLayNodeList[i])
    end
    GetCurNodeInfo = ExpeditionManager.GetCurNodeInfo()
    self.gridMaskImage.sizeDelta = Vector2.New(0,(3000/#curAllLayNodeList)*(#curAllLayNodeList - (GetCurNodeInfo.lay + 1)))
    for i = 1, math.max(#curAllLayNodeList, #layListGrid) do
        local go = layListGrid[i]
        if not go then
            go = newObject(self.singlePre)
            go.transform:SetParent(self.grid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            layListGrid[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #AllLayNodeList do
        ExpeditionMainPanel:SingleLayNodeShow(layListGrid[i],curAllLayNodeList[i])
        layListGrid[i]:SetActive(true)
    end
    if isMoveGrid then
        local gridH = 2746--self.grid:GetComponent("RectTransform").sizeDelta.y
        local rectH = 1656--self.grid.transform.parent:GetComponent("RectTransform").sizeDelta.y
        local endH = gridH - rectH
        local curlay = GetCurNodeInfo.lay
        if curlay <= 6 then
            local y = endH / 6
            y = endH - (curlay - 1) * y
            self.grid:GetComponent("RectTransform").anchoredPosition = Vector3.New(0,y,0)
        end
    end
    
    if not RECHARGEABLE then--（是否开启充值）
        self.Btn4:SetActive(false)
        self.Btn4Image:SetActive(false)
    end
end

--实例化每层信息
function ExpeditionMainPanel:SingleLayNodeShow(go,layNodeListData)
    nodeGoTable[go.name] = {data = layNodeListData,goData = go}
    local nodeGo = go
    --卸载加载的立绘
    if liveNodeList[go] then
        for i = 1, #liveNodeList[go] do
            local item = liveNodeList[go][i]
            if item then
                poolManager:UnLoadLive(item.name, item.go, PoolManager.AssetType.GameObject)
            end
        end
    end
    liveNodeList[go] = {}
    --判断是否有未打赢过 和 未获取圣物的状态
    local isAttack = false
    for j = 1, 3 do
        Util.GetGameObject(nodeGo, "itemList/item ("..j..")"):SetActive(false)
        if  #layNodeListData >= j then
            if  (layNodeListData[j].state == ExpeditionNodeState.NoPass or layNodeListData[j].state == ExpeditionNodeState.NoGetEquip) and GetCurNodeInfo.lay == layNodeListData[j].lay then
                isAttack = true
                isAllHaveAttack = true
            end
        end
    end
    if self.liveNode then
        self.liveNode:SetActive(true)--玩家形象立绘
    end
    if layNodeListData[1].lay == #AllLayNodeList then--最后奖励节点
        Util.GetGameObject(nodeGo, "itemList"):GetComponent("RectTransform").anchoredPosition = Vector3.New(2,140,0)
    end
    for i = 1, #layNodeListData do--每个节点显示
        Util.GetGameObject(nodeGo, "itemList/item ("..i..")"):SetActive(true)
        Util.GetGameObject(nodeGo, "itemList/item ("..i..")/parent"):SetActive(true)
        Util.GetGameObject(nodeGo, "itemList/item ("..i..")/parent/pedestalImage"):GetComponent("Image"):DOFade(1, 0):SetEase(Ease.Linear)
        Util.GetGameObject(nodeGo, "itemList/item ("..i..")/parent/okAttackImage"):GetComponent("Image"):DOFade(1, 0):SetEase(Ease.Linear)
        Util.GetGameObject(nodeGo, "itemList/item ("..i..")/parent").transform.localPosition = Vector3.zero--Vector3.New(115.75,0,0)--91.65,
        local curItemGo = Util.GetGameObject(nodeGo, "itemList/item ("..i..")/parent")
        self:SingleNodeInfoIconShow(curItemGo,layNodeListData[i],isAttack)
        ---实例化动画---
        local goImage = Util.GetGameObject(curItemGo, "goParent/Image")
        goImage:SetActive(false)
        local curexpeditionNodeConfig = expeditionNodeConfig[layNodeListData[i].type]
        if GetCurNodeInfo.lay <= layNodeListData[i].lay and layNodeListData[i].lay ~= 1 and curexpeditionNodeConfig then
            if curexpeditionNodeConfig.AniOrImage == 1 then
                liveNodeList[go][i] = self:InitLiveSet(layNodeListData[i].type, Util.GetGameObject(curItemGo, "goParent"))
            elseif curexpeditionNodeConfig.AniOrImage == 2 then
                goImage:SetActive(true)
                goImage:GetComponent("Image").sprite =  Util.LoadSprite(curexpeditionNodeConfig.Icon)
                goImage:GetComponent("Image"):SetNativeSize()
                -- 设置图片大小位置
                goImage:GetComponent("RectTransform").anchoredPosition = Vector2.New(curexpeditionNodeConfig.Position[1],curexpeditionNodeConfig.Position[2])
                goImage.transform.localScale = Vector3.one * curexpeditionNodeConfig.Scale
            elseif curexpeditionNodeConfig.AniOrImage == 3 then
                local configData = ConfigManager.GetConfigData(ConfigName.ExpeditionNodeConfig,ExpeditionNodeType.Reward)
                if UI_effect_ExpeditionReward and curexpeditionNodeConfigIcon then
                    poolManager:UnLoadAsset(curexpeditionNodeConfig.Icon, UI_effect_ExpeditionReward, PoolManager.AssetType.GameObject)
                    UI_effect_ExpeditionReward = nil
                    curexpeditionNodeConfigIcon = nil
                end
                UI_effect_ExpeditionReward = poolManager:LoadAsset(curexpeditionNodeConfig.Icon, PoolManager.AssetType.GameObject)
                curexpeditionNodeConfigIcon = curexpeditionNodeConfig.Icon
                UI_effect_ExpeditionReward.transform:SetParent(Util.GetGameObject(curItemGo, "goParent").transform)
                UI_effect_ExpeditionReward.transform.localPosition = Vector3.New(configData.Position[1], configData.Position[2],0)
                UI_effect_ExpeditionReward.transform.localScale = Vector3.one * configData.Scale
                Util.AddParticleSortLayer(UI_effect_ExpeditionReward, self.sortingOrder - cursortingOrder2 + 10)
                UI_effect_ExpeditionReward:SetActive(true)
                cursortingOrder2 = self.sortingOrder
                self.UI_Effect_ChuanSongMen.transform:SetParent(Util.GetGameObject(curItemGo, "goParent").transform)
                self.UI_Effect_ChuanSongMen.transform.localPosition = Vector3.New(0, -80,0)
                self.UI_Effect_ChuanSongMen.transform.localScale = Vector3.one
            end
        end
        --------------
        Util.GetGameObject(curItemGo, "infoIcon"):SetActive(true)
        local pedestalImage = Util.GetGameObject(curItemGo, "pedestalImage")
        local goParent = Util.GetGameObject(curItemGo, "goParent")
        local halidomParent = Util.GetGameObject(curItemGo, "halidomParent")
        pedestalImage:GetComponent("Image").sprite = Util.LoadSprite(expeditionLeveTable[ExpeditionManager.expeditionLeve].nodDi1)
        local  okAttackDi = Util.GetGameObject(curItemGo, "okAttackDi")
        okAttackDi:GetComponent("Image").sprite = Util.LoadSprite(expeditionLeveTable[ExpeditionManager.expeditionLeve].nodDi2)
        local okAttackImage = Util.GetGameObject(curItemGo, "okAttackImage")
        okAttackImage:SetActive((layNodeListData[i].state == ExpeditionNodeState.NoPass or layNodeListData[i].state == ExpeditionNodeState.NoGetEquip) and layNodeListData[i].type ~= ExpeditionNodeType.Reward)
        okAttackDi:SetActive(layNodeListData[i].state == ExpeditionNodeState.NoPass or layNodeListData[i].state == ExpeditionNodeState.NoGetEquip)
        Util.GetGameObject(curItemGo, "click"):SetActive(true)
        local clickbtn = Util.GetGameObject(curItemGo, "click")
        local pos = Util.GetGameObject(curItemGo, "pos")--节点位置  人物动画用
        --pos.transform.localPosition = Vector3.New(0,-10,0)
        pedestalImage:SetActive(true)
        goParent:SetActive(true)
        halidomParent:SetActive(true)
        clickbtn:SetActive(true)
        if layNodeListData[i].lay < GetCurNodeInfo.lay then
            goParent:SetActive(false)
            halidomParent:SetActive(false)
            okAttackImage:SetActive(false)
            okAttackDi:SetActive(false)
            Util.GetGameObject(curItemGo, "click"):SetActive(false)
            Util.GetGameObject(curItemGo, "infoIcon"):SetActive(false)
            if layNodeListData[i].state == ExpeditionNodeState.Over then--未打但已通过
                pedestalImage:SetActive(false)
            end
        elseif layNodeListData[i].lay == GetCurNodeInfo.lay then
            if layNodeListData[i].state == ExpeditionNodeState.No then--未打过
            elseif layNodeListData[i].state == ExpeditionNodeState.NoPass then--打未通过
            elseif layNodeListData[i].state == ExpeditionNodeState.NoGetEquip then--未领取圣物
            elseif layNodeListData[i].state == ExpeditionNodeState.Finish then--已打过
                self:PlayerMovePosFun(pos,nodeGo,curItemGo)
                goParent:SetActive(false)
            elseif layNodeListData[i].state == ExpeditionNodeState.Over then--未打但已通过
                goParent:SetActive(false)
                halidomParent:SetActive(false)
                okAttackImage:SetActive(false)
                okAttackDi:SetActive(false)
                Util.GetGameObject(curItemGo, "click"):SetActive(false)
                pedestalImage:SetActive(false)
                Util.GetGameObject(curItemGo, "infoIcon"):SetActive(false)
            end
        elseif layNodeListData[i].lay > GetCurNodeInfo.lay then
            if layNodeListData[i].state == ExpeditionNodeState.No then--打未通过
                if layNodeListData[i].lay >= GetCurNodeInfo.lay + 3 then
                    if layNodeListData[i].type == ExpeditionNodeType.Jy or layNodeListData[i].type == ExpeditionNodeType.Common then
                        goParent:SetActive(false)
                        clickbtn:SetActive(false)
                    end
                end
            elseif layNodeListData[i].state == ExpeditionNodeState.NoPass then--打未通过
            elseif layNodeListData[i].state == ExpeditionNodeState.NoGetEquip then--未领取圣物
                if layNodeListData[i].type == ExpeditionNodeType.Reward then
                    if UI_effect_ExpeditionReward then
                        UI_effect_ExpeditionReward:SetActive(false)
                    end
                    if ExpeditionManager.expeditionLeve == -1 then
                        shotTiemeLevel = {3,4}
                        self.UI_Effect_ChuanSongMen:SetActive(true)
                        self.UI_Effect_ChuanSongMen_LanSe:SetActive(true)
                        self.UI_Effect_ChuanSongMen_JinSe:SetActive(true)
                    else
                        shotTiemeLevel = {ExpeditionManager.expeditionLeve + 1}
                        self.UI_Effect_ChuanSongMen:SetActive(true)
                        self.UI_Effect_ChuanSongMen_LanSe:SetActive(true)
                        self.UI_Effect_ChuanSongMen_JinSe:SetActive(false)
                    end
                else
                    goParent:SetActive(false)
                    self.Holy.transform:SetParent(halidomParent.transform)
                    local configData = ConfigManager.GetConfigData(ConfigName.ExpeditionNodeConfig,ExpeditionNodeType.Halidom)
                    self.Holy.transform.localPosition=Vector3.New(configData.Position[1], configData.Position[2],0)
                    self.Holy.transform.localScale = Vector3.one * configData.Scale
                    self.Holy:SetActive(true)
                end
            elseif layNodeListData[i].state == ExpeditionNodeState.Over then--未打但已通过
                pedestalImage:SetActive(false)
            end
        end
        Util.AddOnceClick(clickbtn, function()
            if isPlayerMove  then return end
            ExpeditionManager.curAttackNodeInfo = layNodeListData[i]
            --当前操作的节点对象
            targetPosGoAndData = {pos = pos,layGo = nodeGo,layAllData = layNodeListData,curNodeData = layNodeListData[i]}
            if layNodeListData[i].state == ExpeditionNodeState.No then
                if layNodeListData[i].type == ExpeditionNodeType.Boss or layNodeListData[i].type == ExpeditionNodeType.Jy or layNodeListData[i].type == ExpeditionNodeType.Common  then
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Monster,layNodeListData[i],1)
                elseif layNodeListData[i].type == ExpeditionNodeType.Reply or layNodeListData[i].type == ExpeditionNodeType.Resurgence then--回复节点  复活节点
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.ExpeditionReply,layNodeListData[i].type,layNodeListData[i].state)
                elseif layNodeListData[i].type == ExpeditionNodeType.Recruit then--招募节点
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Recruit,layNodeListData[i],1)
                elseif layNodeListData[i].type == ExpeditionNodeType.Shop then--商店节点
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Shop,layNodeListData[i],1)
                elseif layNodeListData[i].type == ExpeditionNodeType.Trail then--试炼节点
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Trail,layNodeListData[i],1)
                elseif layNodeListData[i].type == ExpeditionNodeType.Greed then--贪婪节点
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Greed,layNodeListData[i],1)
                elseif layNodeListData[i].type == ExpeditionNodeType.Reward then--最后奖励节点
                    PopupTipPanel.ShowTipByLanguageId(10499)
                end
            elseif layNodeListData[i].state == ExpeditionNodeState.NoPass then
                if layNodeListData[i].type == ExpeditionNodeType.Boss or layNodeListData[i].type == ExpeditionNodeType.Jy or layNodeListData[i].type == ExpeditionNodeType.Common  then
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Monster,layNodeListData[i],2)
                elseif layNodeListData[i].type == ExpeditionNodeType.Halidom then--圣物节点
                    UIManager.OpenPanel(UIName.ExpeditionSelectHalidomPanel,false)
                elseif layNodeListData[i].type == ExpeditionNodeType.Reply then--回复节点
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.ExpeditionReply,layNodeListData[i].type,layNodeListData[i].state,
                            function ()
                                NetManager.ReCoverExpeditionHeroRequest(layNodeListData[i].sortId,function (msg)
                                    ExpeditionManager.UpdateHeroHpValue(msg.heroInfo)
                                    self:PlayerMoveFun()
                                    PopupTipPanel.ShowTipByLanguageId(10500)
                                end)
                            end)
                elseif layNodeListData[i].type == ExpeditionNodeType.Resurgence then--复活节点
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.ExpeditionReply,layNodeListData[i].type,layNodeListData[i].state,
                            function ()
                                local  cueSelectHeroDid = self:HeroResurgence()
                                local GetHerosHaveIsDie = ExpeditionManager.GetHerosHaveIsDie()
                                NetManager.ReliveExpeditionHeroRequest(cueSelectHeroDid,layNodeListData[i].sortId,function()
                                    if GetHerosHaveIsDie then
                                        PopupTipPanel.ShowTipByLanguageId(10501)
                                    else
                                        PopupTipPanel.ShowTipByLanguageId(12197)
                                    end
                                    self:PlayerMoveFun()
                                end)
                            end)
                elseif layNodeListData[i].type == ExpeditionNodeType.Recruit then--招募节点
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Recruit,layNodeListData[i],2,function ()
                        self:PlayerMoveFun()
                    end)
                elseif layNodeListData[i].type == ExpeditionNodeType.Shop then--商店节点
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Shop,layNodeListData[i],2,function ()
                        self:PlayerMoveFun()
                    end)

                elseif layNodeListData[i].type == ExpeditionNodeType.Trail then--试炼节点
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Trail,layNodeListData[i],2)
                elseif layNodeListData[i].type == ExpeditionNodeType.Greed then--贪婪节点
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Greed,layNodeListData[i],2)
                elseif layNodeListData[i].type == ExpeditionNodeType.Reward then--最后奖励节点
                    NetManager.TakeExpeditionBoxRewardRequest( layNodeListData[i].sortId,function (msg)
                        --加积分
                        NetManager.TreasureOfHeavenScoreRequest()
                        local compShowType = nil
                        if #msg.leve < 1 then
                            compShowType = 5
                        end
                        UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
                            if UI_effect_ExpeditionReward then
                                UI_effect_ExpeditionReward:SetActive(false)
                            end
                            shotTiemeLevel = msg.leve
                            if #msg.leve > 1 then
                                ExpeditionManager.RefreshCurExpeditionLeve(-1)
                                self.UI_Effect_ChuanSongMen:SetActive(true)
                                self.UI_Effect_ChuanSongMen_LanSe:SetActive(true)
                                self.UI_Effect_ChuanSongMen_JinSe:SetActive(true)
                            elseif #msg.leve == 1 then
                                
                                self.UI_Effect_ChuanSongMen:SetActive(true)
                                self.UI_Effect_ChuanSongMen_LanSe:SetActive(true)
                                self.UI_Effect_ChuanSongMen_JinSe:SetActive(false)
                            else
                                --PopupTipPanel.ShowTip("已通关本次大闹天宫！")
                                self:PlayerMoveFun()
                            end
                        end,compShowType)
                    end)
                end
            elseif layNodeListData[i].state == ExpeditionNodeState.NoGetEquip then
                if layNodeListData[i].type ~= ExpeditionNodeType.Reward then
                    UIManager.OpenPanel(UIName.ExpeditionSelectHalidomPanel,false)
                end
            elseif layNodeListData[i].state == ExpeditionNodeState.Finish then
                --PopupTipPanel.ShowTip("已完成！")
            elseif layNodeListData[i].state == ExpeditionNodeState.Over then
                PopupTipPanel.ShowTipByLanguageId(10502)
            end
        end)
    end
end
--刷新倒计时显示
function ExpeditionMainPanel:RemainTimeDown(_timeTextExpertgo,_timeTextExpert,timeDown)
    if timeDown > 0 then
        _timeTextExpertgo:SetActive(true)
        _timeTextExpert.text =   GetLanguageStrById(10028)..self:TimeStampToDateString(timeDown)
        if timer then
            timer:Stop()
            timer = nil
        end
        timer = Timer.New(function()
            _timeTextExpert.text =   GetLanguageStrById(10028)..self:TimeStampToDateString(timeDown)
            if timeDown < 0 then
                _timeTextExpertgo:SetActive(false)
                timer:Stop()
                timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        timer:Start()
    else
        _timeTextExpertgo:SetActive(false)
    end
end

function ExpeditionMainPanel:TimeStampToDateString(second)
    --local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(10503), hour, minute, sec)
end
--界面关闭时调用（用于子类重写）
function ExpeditionMainPanel:OnClose()
    self.timeText.text = ""
    if timer then
        timer:Stop()
        timer = nil
    end
    if timer2 then
        timer2:Stop()
        timer2 = nil
    end
end

--界面销毁时调用（用于子类重写）
function ExpeditionMainPanel:OnDestroy()

    if self.liveNode then
        poolManager:UnLoadLive(npc, self.liveNode, PoolManager.AssetType.GameObject)
        self.liveNode = nil
    end
    layListGrid = {}
    if UI_effect_ExpeditionReward and curexpeditionNodeConfigIcon then
        poolManager:UnLoadAsset(curexpeditionNodeConfigIcon, UI_effect_ExpeditionReward, PoolManager.AssetType.GameObject)
        UI_effect_ExpeditionReward = nil
        curexpeditionNodeConfigIcon = nil
    end
    ClearRedPointObject(RedPointType.Expedition_Treasure)
end
--实例化节点立绘
function ExpeditionMainPanel:InitLiveSet(iconId, go)
    local configData = ConfigManager.GetConfigData(ConfigName.ExpeditionNodeConfig,iconId)
    local live2d = poolManager:LoadLive(configData.Icon, Util.GetTransform(go, "goParent"),
            Vector3.one * configData.Scale, Vector3.New(configData.Position[1], configData.Position[2],0))
    return {name=configData.Icon, go=live2d}
end
-- 设置文本透明度
function  ExpeditionMainPanel:SetCurAlpha(text, a)
    local color = text.color
    color.a = a
    text.color = color
end
function ExpeditionMainPanel:PlayerMovePosFun(nodeGo,curItemGo)
    self.liveNode.transform:SetParent(nodeGo.transform)
    self.liveNode.transform.localPosition = Vector3.zero
    SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
end
function ExpeditionMainPanel:SingleNodeInfoIconShow(nodeGo,layNodeData)
    local infoIcon = Util.GetGameObject(nodeGo, "infoIcon")
    local warPowerGo = Util.GetGameObject(infoIcon, "warPowerGo")
    local powerText = Util.GetGameObject(warPowerGo, "powerText"):GetComponent("Text")
    local textIconGo = Util.GetGameObject(infoIcon, "textIconGo")
    infoIcon :SetActive(false)
    warPowerGo:SetActive(false)
    textIconGo:SetActive(false)
    if layNodeData.lay < GetCurNodeInfo.lay + 3 and layNodeData.lay > GetCurNodeInfo.lay and (layNodeData.state == ExpeditionNodeState.No or layNodeData.state == ExpeditionNodeState.NoPass) then
        if layNodeData.type == ExpeditionNodeType.Jy or layNodeData.type == ExpeditionNodeType.Common then
            warPowerGo:SetActive(true)
            powerText.text = layNodeData.bossTeaminfo.totalForce
        end
    end
    if layNodeData.type == ExpeditionNodeType.Boss and (layNodeData.state == ExpeditionNodeState.No or layNodeData.state == ExpeditionNodeState.NoPass) then
        warPowerGo:SetActive(true)
        powerText.text = layNodeData.bossTeaminfo.totalForce
    end

end

function ExpeditionMainPanel:PlayerMoveFun()
    isPlayerMove = true
    if not targetPosGoAndData.pos then return end
    targetPosGoAndData.pos:SetActive(true)
    self.liveNode.transform:SetParent(targetPosGoAndData.pos.transform)
    local oldPos = self.liveNode.transform.localPosition
    local targetPos = targetPosGoAndData.pos.transform.localPosition - Vector3.New(0,69,0)
    if oldPos.x - targetPos.x > 0 then
        SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, 180, 0)
    else
        SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, 0, 0)
    end
    --self.mask:SetActive(isPlayerMove)
    SkeletonGraphic.AnimationState:SetAnimation(0, "move2", true)
    local timeNum = math.abs(oldPos.y - targetPos.y)/350--350/1s
    --玩家行走
    self.liveNode.transform:DOLocalMove(targetPos, timeNum, false):OnStart(function ()
    end):OnComplete(function ()
        
        SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
        --隐藏该层级所有形象
        --播放下落动画
        for i = 1, #targetPosGoAndData.layAllData do
            Util.GetGameObject(targetPosGoAndData.layGo, "itemList/item ("..i..")/parent/goParent"):SetActive(false)
            Util.GetGameObject(targetPosGoAndData.layGo, "itemList/item ("..i..")/parent/okAttackImage"):SetActive(false)
            Util.GetGameObject(targetPosGoAndData.layGo, "itemList/item ("..i..")/parent/infoIcon"):SetActive(false)
            Util.GetGameObject(targetPosGoAndData.layGo, "itemList/item ("..i..")/parent/okAttackDi"):SetActive(false)
            if targetPosGoAndData.layAllData[i].sortId ~= targetPosGoAndData.curNodeData.sortId then
                local curNodParent = Util.GetGameObject(targetPosGoAndData.layGo, "itemList/item ("..i..")/parent")
                targetPos = curNodParent.transform.localPosition - Vector3.New(0,300,0)
                curNodParent.transform:DOLocalMove(targetPos, 0.8, false):SetEase(Ease.Linear)
                Util.GetGameObject(curNodParent, "pedestalImage"):GetComponent("Image"):DOFade(0, 0.8):SetEase(Ease.Linear)
                Util.GetGameObject(curNodParent, "okAttackImage"):GetComponent("Image"):DOFade(0, 0.8):SetEase(Ease.Linear)
            end
        end
        if timer2 then
            timer2:Stop()
            timer2 = nil
        end
        timer2 = Timer.New(function()
            for i = 1, #targetPosGoAndData.layAllData do
                if targetPosGoAndData.layAllData[i].sortId ~= targetPosGoAndData.curNodeData.sortId then
                    Util.GetGameObject(targetPosGoAndData.layGo, "itemList/item ("..i..")/parent"):SetActive(false)
                end
            end
            if targetPosGoAndData.curNodeData.type == ExpeditionNodeType.Shop then
                NetManager.StoreNodeRequest(targetPosGoAndData.curNodeData.sortId,function ()
                    UIManager.OpenPanel(UIName.ExpeditionMonsterInfoPopup,EXPEDITON_POPUP_TYPE.Shop,targetPosGoAndData.curNodeData,3,function ()
                        self:OnShowNodeData()
                    end)
                end)
            else
                self:OnShowNodeData()
            end
            isPlayerMove = false
        end, 0.8)
        timer2:Start()
    end):SetEase(Ease.Linear)
end
function ExpeditionMainPanel:SelfUpdataPanelShow()
    self.Holy.transform:SetParent(self.transform)
    self.Holy:SetActive(false)
    local AllLayNodeList = ExpeditionManager.GetAllLayNodeList()
    if AllLayNodeList == nil then return end
    local curAllLayNodeList = {}
    for i = #AllLayNodeList, 1, -1 do
        table.insert(curAllLayNodeList,AllLayNodeList[i])
    end
    GetCurNodeInfo = ExpeditionManager.GetCurNodeInfo()
    isAllHaveAttack = false
    local curNodeGo
    for i, v in pairs(nodeGoTable) do
        if v.data[1].lay == GetCurNodeInfo.lay then
            curNodeGo = v.goData
        end
    end
    if curNodeGo then
        self:SingleLayNodeShow(curNodeGo,curAllLayNodeList[15 - GetCurNodeInfo.lay + 1],GetCurNodeInfo.lay)
    end
end
function ExpeditionMainPanel:RefreshManagerData()
    NetManager.GetExpeditionRequest(ExpeditionManager.expeditionLeve,function ()
        self:OnShowNodeData()
    end)
end
function ExpeditionMainPanel:HeroResurgence()
    local heroDid = ""
    local roleDidDatas = {}
    local roleHurtDatas = {}
    local _roleDatas = HeroManager.GetAllHeroDatas(1)
    for i = 1, #_roleDatas do
        local heroHp = 0
        if ExpeditionManager.heroInfo[_roleDatas[i].dynamicId] then
            heroHp = ExpeditionManager.heroInfo[_roleDatas[i].dynamicId].remainHp
            if heroHp <= 0 then
                table.insert(roleDidDatas,_roleDatas[i])
            elseif heroHp < 1 then
                table.insert(roleHurtDatas,_roleDatas[i])
            end
        end
    end
    local  cuSelectHeroIndex = 0
    if roleDidDatas and #roleDidDatas > 0 then
        cuSelectHeroIndex = math.random(1,#roleDidDatas)
        heroDid = roleDidDatas[cuSelectHeroIndex].dynamicId
    elseif roleHurtDatas and #roleHurtDatas > 0 then
        cuSelectHeroIndex = math.random(1,#roleHurtDatas)
        heroDid = roleHurtDatas[cuSelectHeroIndex].dynamicId
    else
        heroDid = _roleDatas[1].dynamicId
    end
    return heroDid
end
return ExpeditionMainPanel