local SettingPlayerSkin = quick_class("SettingPlayerSkin")
local this = SettingPlayerSkin
local playerSkinConFig --= ConfigManager.GetAllConfigsDataByKey(ConfigName.ItemConfig, "ItemType", ItemType.Skin)
local proList = {}
local skinList = {}
local curSkinId = 0
local curSkinItemConFig = {}--ItemConfig
local curSkinConFig = {}--PlayerAppearance
local parentGo = nil
local skinLive
local skinLiveStr
local playerLiveView--view
local posAddIndex = 0
local posJianIndex = 0
local curIndex = 0
local curDataIndex = 0
local isLicckBtn = false
function SettingPlayerSkin:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function SettingPlayerSkin:InitComponent(gameObject)

    parentGo = gameObject
    this.live2dRootParent = Util.GetGameObject(gameObject, "live2dRootParent")
    this.live2dRootParent2 = Util.GetGameObject(gameObject, "live2dRootParent2")
    this.name = Util.GetGameObject(gameObject, "name/Text"):GetComponent("Text")
    this.getInfo = Util.GetGameObject(gameObject, "skinProInfo/getInfo"):GetComponent("Text")
    this.proListParent = Util.GetGameObject(gameObject, "skinProInfo/pro")
    proList = {}
    for i = 1, 3 do
        proList[i] = Util.GetGameObject(gameObject, "skinProInfo/pro/pro ("..i..")")
    end

    this.setImage = Util.GetGameObject(gameObject, "setImage")
    this.grid = Util.GetGameObject(gameObject, "rect/grid")
    skinList = {}
    --for i = 1, 5 do
    --    skinList[i] = Util.GetGameObject(gameObject, "rect/grid/itemPre ("..i..")")
    --end
    this.goToBtn = Util.GetGameObject(gameObject, "goToBtn")
    this.goToBtnText = Util.GetGameObject(gameObject, "goToBtn/Text"):GetComponent("Text")
    this.Info = Util.GetGameObject(gameObject, "skinProInfo/Info"):GetComponent("Text")

    this.rightBtn = Util.GetGameObject(gameObject, "rightBtn")
    this.leftBtn = Util.GetGameObject(gameObject, "leftBtn")
    this.itemPre = Util.GetGameObject(self.gameObject, "itemPre")
end

--绑定事件（用于子类重写）
function SettingPlayerSkin:BindEvent()

    --Util.AddClick(this.cdKey, function()
    --    UIManager.OpenPanel(UIName.CDKeyExchangePanel)
    --end)
    Util.AddOnceClick(this.rightBtn, function()
        if not isLicckBtn then
            isLicckBtn = true
            curIndex = curIndex - 1
            curDataIndex = curDataIndex + 1
            this.grid.transform:DOLocalMove(Vector3.New(curIndex*440,0,0), 0.3, false):OnComplete(function ()

                if curDataIndex > #playerSkinConFig then
                    curDataIndex = 1
                end
                this.OnShowCurSkinProData(playerSkinConFig[curDataIndex].Id)
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
                    curDataIndex = #playerSkinConFig
                end
                this.OnShowCurSkinProData(playerSkinConFig[curDataIndex].Id)
                posAddIndex = posAddIndex - 1
                posJianIndex = posJianIndex - 1
                local curGo = this.grid.transform:GetChild(#playerSkinConFig - 1).transform
                curGo.transform:SetAsFirstSibling()
                curGo.transform.localPosition=Vector3.New(posJianIndex*440,0,0)
                isLicckBtn = false
            end):SetEase(Ease.Linear)
        end
    end)
end

--添加事件监听（用于子类重写）
function SettingPlayerSkin:AddListener()

end

--移除事件监听（用于子类重写）
function SettingPlayerSkin:RemoveListener()

end
--界面打开时调用（用于子类重写）
function SettingPlayerSkin:OnOpen()
    playerSkinConFig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ItemConfig, "ItemType", ItemType.Skin)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SettingPlayerSkin:OnShow()

    Util.ClearChild(this.grid.transform)
    skinList = {}
    if #playerSkinConFig < 5 then
        for i = 1, #playerSkinConFig do
            table.insert(playerSkinConFig,playerSkinConFig[i])
        end
    end
    this.OnShowCurSkinProData(PlayerManager.skin > 0 and PlayerManager.skin or playerSkinConFig[1].Id)
    this.OnShowAllSkinGrid()
    posAddIndex = #playerSkinConFig
    posJianIndex = 1
    if playerLiveView == nil then
        playerLiveView = SubUIManager.Open(SubUIConfig.PlayerLiveView, this.live2dRootParent.transform)
    end
    playerLiveView:OnOpen()
end
--坐骑属性展示
function this.OnShowCurSkinProData(skinId)
    curSkinId = skinId > 0 and skinId or playerSkinConFig[1].Id
    curSkinItemConFig = ConfigManager.GetConfigData(ConfigName.ItemConfig,curSkinId)
    curSkinConFig = ConfigManager.GetConfigData(ConfigName.PlayerAppearance,curSkinId)
    if curSkinConFig == nil then return end
    --this.live2dRootParent = Util.GetGameObject(gameObject, "live2dRootParent")--:GetComponent("Text")
    this.name.text = curSkinItemConFig.Name
    this.getInfo.text = curSkinConFig.Description
    this.Info.text = curSkinItemConFig.ItemDescribe
    local curproInfoList = this.GetCurSkinAllPro()
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
    if skinLive then
        poolManager:UnLoadLive(skinLiveStr, skinLive, PoolManager.AssetType.GameObject)
        skinLive = nil
    end
    skinLiveStr = GetResourcePath(ConfigManager.GetConfigData(ConfigName.PlayerAppearance,curSkinId).Live)
    skinLive = poolManager:LoadLive(skinLiveStr, this.live2dRootParent2.transform, Vector3.one, Vector3.zero)
    --满级显隐
    this.GoToBtnFun()
end
--当前级属所有性获取
function this.GetCurSkinAllPro()
    local proList = {}
    local curPlayerMountLevelUp = curSkinConFig.Property
    if curPlayerMountLevelUp then
        for i = 1, #curPlayerMountLevelUp do
            table.insert(proList,{name = ConfigManager.GetConfigData(ConfigName.PropertyConfig,curPlayerMountLevelUp[i][1]).Info,
                                  vale = curPlayerMountLevelUp[i][2]})
        end
    end
    return proList
end
--所有坐骑展示
function this.OnShowAllSkinGrid()
    for i = 1, math.max(#skinList, #playerSkinConFig) do
        local go = skinList[i]
        if not go then
            go=newObject(this.itemPre)
            go.transform:SetParent(this.grid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition=Vector3.zero;
            go.gameObject.name = "itemPre (".. i ..")"
            skinList[i] = go --440 = 362 + 80
            skinList[i].transform.localPosition=Vector3.New(i*440,0,0)
        end
        go.gameObject:SetActive(false)
    end
    this.RefreshAllSkinData()
    curIndex = -3
    this.grid.transform.localPosition=Vector3.New(curIndex*440)
    this.FirstSetGridPos(curIndex,curDataIndex)
end
function this.GoToBtnFun()
    local btnState = 0
    if BagManager.GetItemCountById(curSkinId) > 0 then--获得
        this.goToBtnText.text = GetLanguageStrById(10220)
        btnState = 1
        if curSkinId == PlayerManager.skin then--获得并使用
            this.goToBtnText.text = GetLanguageStrById(11908)
            btnState = 2
        end
    else--未获得
        this.goToBtnText.text = GetLanguageStrById(11909)
    end
    Util.AddOnceClick(this.goToBtn, function()
        if btnState == 0 then
            JumpManager.GoJump(ConfigManager.GetConfigData(ConfigName.ItemConfig,curSkinId).Jump[1])
        elseif btnState == 1 then
            NetManager.RequestChangeModifyDecoration(4, curSkinId, function ()
                PopupTipPanel.ShowTipByLanguageId(11891)
                PlayerManager.SetPlayerSkin(curSkinId)
                this.RefreshAllSkinData()
                FormationManager.UserPowerChanged()
                this.GoToBtnFun()
                if playerLiveView then
                    playerLiveView:OnOpen()
                end
            end)
        elseif btnState == 2 then
            NetManager.RequestChangeModifyDecoration(4, 0, function ()
                PopupTipPanel.ShowTipByLanguageId(11910)
                PlayerManager.SetPlayerSkin(0)
                this.RefreshAllSkinData()
                FormationManager.UserPowerChanged()
                this.GoToBtnFun()
                if playerLiveView then
                    playerLiveView:OnOpen()
                end
            end)
        end
    end)
end
function this.RefreshAllSkinData()
    for i = 1, #playerSkinConFig do
        if curSkinId == playerSkinConFig[i].Id then
            curDataIndex = i
        end
        skinList[i]:SetActive(true)
        Util.GetGameObject(skinList[i], "iconMask/icon"):GetComponent("Image").sprite =
        Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.PlayerAppearance,playerSkinConFig[i].Id).Painting))
        --Util.SetGray(skinList[i], not (BagManager.GetItemCountById(playerSkinConFig[i].Id) > 0))
        Util.GetGameObject(skinList[i], "noGetImage"):SetActive(BagManager.GetItemCountById(playerSkinConFig[i].Id) <= 0)
        Util.GetGameObject(skinList[i], "GetImage"):SetActive(playerSkinConFig[i].Id ==  PlayerManager.skin)
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
                if dataIndex > #playerSkinConFig then
                    dataIndex = dataIndex % #playerSkinConFig
                end
                if dataIndex == 0 then
                    dataIndex = #playerSkinConFig
                end
                this.OnShowCurSkinProData(playerSkinConFig[dataIndex].Id)
                posAddIndex = posAddIndex - 1
                posJianIndex = posJianIndex - 1
                local curGo = this.grid.transform:GetChild(#playerSkinConFig - 1).transform
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
                if dataIndex > #playerSkinConFig then
                    dataIndex = dataIndex % #playerSkinConFig
                end
                if dataIndex == 0 then
                    dataIndex = #playerSkinConFig
                end
                this.OnShowCurSkinProData(playerSkinConFig[dataIndex].Id)
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
function SettingPlayerSkin:OnClose()

    parentGo = nil
    if skinLive then
        poolManager:UnLoadLive(skinLiveStr, skinLive, PoolManager.AssetType.GameObject)
        skinLive = nil
    end
    Util.ClearChild(this.grid.transform)
    skinList = {}
end

--界面销毁时调用（用于子类重写）
function SettingPlayerSkin:OnDestroy()

    if playerLiveView then
        SubUIManager.Close(playerLiveView)
        playerLiveView = nil
    end
end

return SettingPlayerSkin