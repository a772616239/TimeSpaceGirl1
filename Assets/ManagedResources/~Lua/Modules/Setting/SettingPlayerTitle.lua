local SettingPlayerTitle = quick_class("SettingPlayerTitle")
local this = SettingPlayerTitle
local playerTitleConFig --= ConfigManager.GetAllConfigsDataByKey(ConfigName.ItemConfig, "ItemType", ItemType.Title)
local proList = {}
local titleList = {}
local curTitleId = 0
local curTitleItemConFig = {}--ItemConfig
local curTitleConFig = {}--PlayerAppearance
local parentGo = nil
local titleLive
local titleLiveStr
local playerLiveView--view
local posAddIndex = 0
local posJianIndex = 0
local curIndex = 0
local curDataIndex = 0
local isLicckBtn = false
function SettingPlayerTitle:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function SettingPlayerTitle:InitComponent(gameObject)

    parentGo = gameObject
    this.live2dRootParent = Util.GetGameObject(gameObject, "live2dRootParent")
    this.live2dRootParent2 = Util.GetGameObject(gameObject, "live2dRootParent2")
    this.name = Util.GetGameObject(gameObject, "name/Text"):GetComponent("Text")
    this.getInfo = Util.GetGameObject(gameObject, "titleProInfo/getInfo"):GetComponent("Text")
    this.proListParent = Util.GetGameObject(gameObject, "titleProInfo/pro")
    proList = {}
    for i = 1, 3 do
        proList[i] = Util.GetGameObject(gameObject, "titleProInfo/pro/pro ("..i..")")
    end

    this.setImage = Util.GetGameObject(gameObject, "setImage")
    this.grid = Util.GetGameObject(gameObject, "rect/grid")
    this.rect = Util.GetGameObject(gameObject, "rect")
    titleList = {}
    --for i = 1, #playerTitleConFig do
    --    titleList[i] = Util.GetGameObject(gameObject, "rect/grid/itemPre ("..i..")")
    --end
    this.goToBtn = Util.GetGameObject(gameObject, "goToBtn")
    this.goToBtnText = Util.GetGameObject(gameObject, "goToBtn/Text"):GetComponent("Text")
    this.Info = Util.GetGameObject(gameObject, "titleProInfo/Info"):GetComponent("Text")
    this.InfoText = Util.GetGameObject(gameObject, "titleProInfo/InfoImage/Text"):GetComponent("Text")
    this.rightBtn = Util.GetGameObject(gameObject, "rightBtn")
    this.leftBtn = Util.GetGameObject(gameObject, "leftBtn")


    this.ItemView = Util.GetGameObject(self.gameObject, "itemPre")
end
--绑定事件（用于子类重写）
function SettingPlayerTitle:BindEvent()

    Util.AddOnceClick(this.rightBtn, function()
        if not isLicckBtn then
            isLicckBtn = true
            curIndex = curIndex - 1
            curDataIndex = curDataIndex + 1
            this.grid.transform:DOLocalMove(Vector3.New(curIndex*440,0,0), 0.3, false):OnComplete(function ()

                if curDataIndex > #playerTitleConFig then
                    curDataIndex = 1
                end
                this.OnShowCurTitleProData(playerTitleConFig[curDataIndex].Id)
                local curGo = this.grid.transform:GetChild(0).transform
                curGo.transform:SetAsLastSibling()
                posAddIndex = posAddIndex + 1
                posJianIndex = posJianIndex + 1
                curGo.transform.localPosition=Vector3.New(posAddIndex*440,0,0)
                isLicckBtn = false
            end):SetEase(Ease.Linear)
        end
    end)
    Util.AddOnceClick(this.leftBtn, function()
        if not isLicckBtn then
            isLicckBtn = true
            curIndex = curIndex + 1
            curDataIndex = curDataIndex - 1
            this.grid.transform:DOLocalMove(Vector3.New(curIndex*440,0,0), 0.3, false):OnComplete(function ()

                if curDataIndex < 1 then
                    curDataIndex = #playerTitleConFig
                end
                this.OnShowCurTitleProData(playerTitleConFig[curDataIndex].Id)
                posAddIndex = posAddIndex - 1
                posJianIndex = posJianIndex - 1
                local curGo = this.grid.transform:GetChild(#playerTitleConFig - 1).transform
                curGo.transform:SetAsFirstSibling()
                curGo.transform.localPosition=Vector3.New(posJianIndex*440,0,0)
                isLicckBtn = false
            end):SetEase(Ease.Linear)
        end
    end)
end

--添加事件监听（用于子类重写）
function SettingPlayerTitle:AddListener()

end

--移除事件监听（用于子类重写）
function SettingPlayerTitle:RemoveListener()

end
--界面打开时调用（用于子类重写）
function SettingPlayerTitle:OnOpen()
    playerTitleConFig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ItemConfig, "ItemType", ItemType.Title)
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SettingPlayerTitle:OnShow()


    Util.ClearChild(this.grid.transform)
    titleList = {}
    if #playerTitleConFig < 5 then
        for i = 1, #playerTitleConFig do
            table.insert(playerTitleConFig,playerTitleConFig[i])
        end
    end
    this.OnShowCurTitleProData(PlayerManager.designation > 0 and PlayerManager.designation or playerTitleConFig[1].Id)
    this.OnShowAllTitleGrid()
    posAddIndex = #playerTitleConFig
    posJianIndex = 1
    if playerLiveView == nil then
        playerLiveView = SubUIManager.Open(SubUIConfig.PlayerLiveView, this.live2dRootParent.transform)
    end
    playerLiveView:OnOpen()
end
--坐骑属性展示
function this.OnShowCurTitleProData(titleId)
    curTitleId = titleId 
    curTitleItemConFig = ConfigManager.GetConfigData(ConfigName.ItemConfig,curTitleId)
    curTitleConFig = ConfigManager.GetConfigData(ConfigName.PlayerAppearance,curTitleId)
    if curTitleConFig == nil then return end
    this.name.text = curTitleItemConFig.Name
    this.getInfo.text = curTitleConFig.Description
    this.Info.text = curTitleItemConFig.ItemDescribe
    this.InfoText.text = curTitleItemConFig.Name
    local curproInfoList = this.GetCurTitleAllPro()
    --属性展示
    for i = 1, math.max(#proList, #curproInfoList) do
        local go = proList[i]
        if not go then
            go=newObject(proList[1])
            go.transform:SetParent(this.proListParent.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition=Vector3.zero;
            go.gameObject.name = "pro (".. i ..")"
            proList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #curproInfoList do
        proList[i]:SetActive(true)
        Util.GetGameObject(proList[i], "proName"):GetComponent("Text").text = curproInfoList[i].name..":"
        Util.GetGameObject(proList[i], "proValue"):GetComponent("Text").text = "+"..curproInfoList[i].vale
    end
    if titleLive then
        poolManager:UnLoadLive(titleLiveStr, titleLive, PoolManager.AssetType.GameObject)
        titleLive = nil
    end
        titleLiveStr = GetResourcePath(ConfigManager.GetConfigData(ConfigName.PlayerAppearance,curTitleId).Live)
        titleLive = poolManager:LoadLive(titleLiveStr, this.live2dRootParent2.transform, Vector3.one, Vector3.zero)
    --满级显隐
    this.GoToBtnFun()
end
--当前级属所有性获取
function this.GetCurTitleAllPro()
    local proList = {}
    local curPlayerMountLevelUp = curTitleConFig.Property
    if curPlayerMountLevelUp then
        for i = 1, #curPlayerMountLevelUp do
            table.insert(proList,{name = ConfigManager.GetConfigData(ConfigName.PropertyConfig,curPlayerMountLevelUp[i][1]).Info,
                                  vale = curPlayerMountLevelUp[i][2]})
        end
    end
    return proList
end
--所有坐骑展示
function this.OnShowAllTitleGrid()
    for i = 1, math.max(#titleList, #playerTitleConFig) do
        local go = titleList[i]
        if not go then
            go=newObject(this.ItemView)
            go.transform:SetParent(this.grid.transform)
            go.transform.localScale = Vector3.one
            go.gameObject.name = "itemPre (".. i ..")"
            titleList[i] = go
            --440 = 362 + 80
            titleList[i].transform.localPosition=Vector3.New(i*440,0,0)
        end
        go.gameObject:SetActive(false)
    end
    this.RefreshAllTitleData()
    curIndex = -3
    this.grid.transform.localPosition=Vector3.New(curIndex*440)
    this.FirstSetGridPos(curIndex,curDataIndex)
end
function this.GoToBtnFun()
    local btnState = 0
    if BagManager.GetItemCountById(curTitleId) > 0 then--获得
        this.goToBtnText.text = GetLanguageStrById(10220)
        btnState = 1
        if curTitleId == PlayerManager.designation then--获得并使用
            this.goToBtnText.text = GetLanguageStrById(11908)
            btnState = 2
        end
    else--未获得
        this.goToBtnText.text = GetLanguageStrById(11909)
    end
    Util.AddOnceClick(this.goToBtn, function()
        if btnState == 0 then
            JumpManager.GoJump(ConfigManager.GetConfigData(ConfigName.ItemConfig,curTitleId).Jump[1])
        elseif btnState == 1 then
            NetManager.RequestChangeModifyDecoration(2, curTitleId, function ()
                PopupTipPanel.ShowTipByLanguageId(11891)
                PlayerManager.SetPlayerDesignation(curTitleId)
                this.RefreshAllTitleData()
                FormationManager.UserPowerChanged()
                this.GoToBtnFun()
                if playerLiveView then
                    playerLiveView:OnOpen()
                end
            end)
        elseif btnState == 2 then
            NetManager.RequestChangeModifyDecoration(2, 0, function ()
                PopupTipPanel.ShowTipByLanguageId(11910)
                PlayerManager.SetPlayerDesignation(0)
                this.RefreshAllTitleData()
                FormationManager.UserPowerChanged()
                this.GoToBtnFun()
                if playerLiveView then
                    playerLiveView:OnOpen()
                end
            end)
        end
    end)
end
function this.RefreshAllTitleData()
    for i = 1, #playerTitleConFig do
        if curTitleId == playerTitleConFig[i].Id then
            curDataIndex = i
        end
        --titleList[i].transform.localPosition=Vector3.New(i*440,0,0)
        titleList[i]:SetActive(true)
        Util.GetGameObject( titleList[i], "name"):GetComponent("Text").text = playerTitleConFig[i].Name
        Util.GetGameObject( titleList[i], "iconMask/icon"):GetComponent("Image").sprite =
        Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.PlayerAppearance,playerTitleConFig[i].Id).Painting))
        Util.GetGameObject( titleList[i], "noGetImage"):SetActive(BagManager.GetItemCountById(playerTitleConFig[i].Id) <= 0)
        Util.GetGameObject( titleList[i], "GetImage"):SetActive(playerTitleConFig[i].Id ==  PlayerManager.designation)
    end
end
function this.FirstSetGridPos(_curIndex,curSelectIndex)
   
    local num = math.abs(curSelectIndex) - math.abs(_curIndex)
   
    if num < 0 then
        num = math.abs(num)
        for i = _curIndex+1, _curIndex+num do
            curIndex = i
            this.grid.transform:DOLocalMove(Vector3.New(curIndex*440,0,0), 0.01, false):OnComplete(function ()

                local dataIndex = math.abs(curIndex)
                if dataIndex > #playerTitleConFig then
                    dataIndex = dataIndex % #playerTitleConFig
                end
                if dataIndex == 0 then
                    dataIndex = #playerTitleConFig
                end
                this.OnShowCurTitleProData(playerTitleConFig[dataIndex].Id)
                posAddIndex = posAddIndex - 1
                posJianIndex = posJianIndex - 1
                local curGo = this.grid.transform:GetChild(#playerTitleConFig - 1).transform
                curGo.transform:SetAsFirstSibling()
                curGo.transform.localPosition=Vector3.New(posJianIndex*440,0,0)
            end):SetEase(Ease.Linear)
        end
    elseif num > 0 then
        num = math.abs(num)
        for i = _curIndex-1,  _curIndex-num,-1  do
            curIndex = i
            this.grid.transform:DOLocalMove(Vector3.New(curIndex*440,0,0), 0.01 , false):OnComplete(function ()

                local dataIndex = math.abs(curIndex)
                if dataIndex > #playerTitleConFig then
                    dataIndex = dataIndex % #playerTitleConFig
                end
                if dataIndex == 0 then
                    dataIndex = #playerTitleConFig
                end
                this.OnShowCurTitleProData(playerTitleConFig[dataIndex].Id)
                local curGo = this.grid.transform:GetChild(0).transform
                curGo.transform:SetAsLastSibling()
                posAddIndex = posAddIndex + 1
                posJianIndex = posJianIndex + 1
                curGo.transform.localPosition=Vector3.New(posAddIndex*440,0,0)
            end):SetEase(Ease.Linear)
        end
    end
end
--界面关闭时调用（用于子类重写）
function SettingPlayerTitle:OnClose()

    parentGo = nil
    if titleLive then
        poolManager:UnLoadLive(titleLiveStr, titleLive, PoolManager.AssetType.GameObject)
        titleLive = nil
    end
    Util.ClearChild(this.grid.transform)
    titleList = {}
end

--界面销毁时调用（用于子类重写）
function SettingPlayerTitle:OnDestroy()

    if playerLiveView then
        SubUIManager.Close(playerLiveView)
        playerLiveView = nil
    end
end

return SettingPlayerTitle