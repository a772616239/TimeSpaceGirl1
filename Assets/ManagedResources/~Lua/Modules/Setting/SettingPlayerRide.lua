local SettingPlayerRide = quick_class("SettingPlayerRide")
local this = SettingPlayerRide
local playerRideConFig --= ConfigManager.GetAllConfigsDataByKey(ConfigName.ItemConfig, "ItemType", ItemType.Ride)
local proList = {}
local lvMaterialsList = {}
local rideList = {}
local curRideId = 0
local curRideLv = 0
local curRideItemConFig = {}--ItemConfig
local curRideConFig = {}--PlayerAppearance
local parentGo = nil
local rideLive
local rideLiveStr
local playerLiveView
local posAddIndex = 0
local posJianIndex = 0
local curIndex = 0
local curDataIndex = 0
local isLicckBtn = false
local isMaterial
function SettingPlayerRide:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function SettingPlayerRide:InitComponent(gameObject)

    parentGo = gameObject
    this.live2dRootParent = Util.GetGameObject(gameObject, "live2dRootParent")
    this.live2dRootParent2 = Util.GetGameObject(gameObject, "live2dRootParent2")
    this.name = Util.GetGameObject(gameObject, "name/Text"):GetComponent("Text")
    --this.lv = Util.GetGameObject(gameObject, "rideProInfo/Lv"):GetComponent("Text")
    this.getInfo = Util.GetGameObject(gameObject, "rideProInfo/getInfo"):GetComponent("Text")
    this.InfoEndInfo = Util.GetGameObject(gameObject, "rideProInfo/InfoEndInfo/Text"):GetComponent("Text")
    this.proListParent = Util.GetGameObject(gameObject, "rideProInfo/pro")
    proList = {}
    for i = 1, 3 do
        proList[i] = Util.GetGameObject(gameObject, "rideProInfo/pro/pro ("..i..")")
    end

    this.rightBtn = Util.GetGameObject(gameObject, "rightBtn")
    this.leftBtn = Util.GetGameObject(gameObject, "leftBtn")
    this.upLv = Util.GetGameObject(gameObject, "rideProInfo/upLv")
    this.upLvBtn = Util.GetGameObject(gameObject, "rideProInfo/upLvBtn")
    this.lvUpGo = Util.GetGameObject(gameObject, "rideProInfo/lvUpGo")
    this.noUpLvText = Util.GetGameObject(gameObject, "rideProInfo/noUpLvText")
    this.lvMaterialsListParent = Util.GetGameObject(gameObject, "rideProInfo/upLv/itemGrid")
    for i = 1, 2 do
        lvMaterialsList[i] = Util.GetGameObject(gameObject, "rideProInfo/upLv/itemGrid/itemPre ("..i..")")
    end

    this.setImage = Util.GetGameObject(gameObject, "setImage")
    this.grid = Util.GetGameObject(gameObject, "rect/grid")
    --rideList = {}
    --for i = 1, 5 do
    --    rideList[i] = Util.GetGameObject(gameObject, "rect/grid/itemPre ("..i..")")
    --end
    this.goToBtn = Util.GetGameObject(gameObject, "goToBtn")
    this.goToBtnText = Util.GetGameObject(gameObject, "goToBtn/Text"):GetComponent("Text")

    this.itemPre = Util.GetGameObject(self.gameObject, "itemPre")

end

--绑定事件（用于子类重写）
function SettingPlayerRide:BindEvent()

    Util.AddOnceClick(this.upLvBtn, function()
        this.UpLvFun()
    end)
    Util.AddOnceClick(this.rightBtn, function()
        if not isLicckBtn then
            isLicckBtn = true
            curIndex = curIndex - 1
            curDataIndex = curDataIndex + 1
            this.grid.transform:DOLocalMove(Vector3.New(curIndex*440,0,0), 0.3, false):OnComplete(function ()

                if curDataIndex > #playerRideConFig then
                    curDataIndex = 1
                end
                this.OnShowCurRideProData(playerRideConFig[curDataIndex].Id)
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
                    curDataIndex = #playerRideConFig
                end
                this.OnShowCurRideProData(playerRideConFig[curDataIndex].Id)
                posAddIndex = posAddIndex - 1
                posJianIndex = posJianIndex - 1
                local curGo = this.grid.transform:GetChild(#playerRideConFig - 1).transform
                curGo.transform:SetAsFirstSibling()
                curGo.transform.localPosition=Vector3.New(posJianIndex*440,0,0)
                isLicckBtn = false
            end):SetEase(Ease.Linear)
        end
    end)
end

--添加事件监听（用于子类重写）
function SettingPlayerRide:AddListener()

end

--移除事件监听（用于子类重写）
function SettingPlayerRide:RemoveListener()

end
--界面打开时调用（用于子类重写）
function SettingPlayerRide:OnOpen()
    playerRideConFig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ItemConfig, "ItemType", ItemType.Ride)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SettingPlayerRide:OnShow()

    Util.ClearChild(this.grid.transform)
    rideList = {}
    if #playerRideConFig < 5 then
        for i = 1, #playerRideConFig do
            table.insert(playerRideConFig,playerRideConFig[i])
        end
    end
    this.OnShowCurRideProData(PlayerManager.ride > 0 and PlayerManager.ride or playerRideConFig[1].Id)
    this.OnShowAllRideGrid()

    posAddIndex = #playerRideConFig
    posJianIndex = 1

    if playerLiveView == nil then
        playerLiveView = SubUIManager.Open(SubUIConfig.PlayerLiveView, this.live2dRootParent.transform)
    end
    playerLiveView:OnOpen()
end
--坐骑属性展示
function this.OnShowCurRideProData(rideId)
    curRideId = rideId
    curRideLv = PlayerManager.rideLevel > 0 and PlayerManager.rideLevel or 1
    curRideItemConFig = ConfigManager.GetConfigData(ConfigName.ItemConfig,curRideId)
    curRideConFig = ConfigManager.GetConfigData(ConfigName.PlayerAppearance,curRideId)
    if curRideConFig == nil then return end
    --this.live2dRootParent = Util.GetGameObject(gameObject, "live2dRootParent")--:GetComponent("Text")
    this.name.text = curRideItemConFig.Name
    --this.lv.text = curRideLv
    this.getInfo.text = curRideConFig.Description
    local keys = GameDataBase.SheetBase.GetKeys(ConfigManager.GetConfig(ConfigName.PlayerMountLevelUp))
    this.InfoEndInfo.text = GetLanguageStrById(11904)..PlayerManager.rideLevel.."/"..LengthOfTable(keys).."]"
    local curproInfoList = this.GetCurRideAllPro(curRideLv)
    local nextproInfoList = this.GetCurRideAllPro(curRideLv + 1)
    if rideLive then
        poolManager:UnLoadLive(rideLiveStr, rideLive, PoolManager.AssetType.GameObject)
        rideLive = nil
    end
    rideLiveStr = GetResourcePath(ConfigManager.GetConfigData(ConfigName.PlayerAppearance,curRideId).Live)
    rideLive = poolManager:LoadLive(rideLiveStr, this.live2dRootParent2.transform, Vector3.one, Vector3.zero)
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
        if curproInfoList[i].vale ~= nextproInfoList[i].vale then
            proList[i]:SetActive(true)
            Util.GetGameObject(proList[i], "proName"):GetComponent("Text").text = curproInfoList[i].name
            Util.GetGameObject(proList[i], "proValue"):GetComponent("Text").text = curproInfoList[i].vale
            if nextproInfoList and #nextproInfoList > 0 then
                Util.GetGameObject(proList[i], "nextProValue"):GetComponent("Text").text = nextproInfoList[i].vale
            else
                Util.GetGameObject(proList[i], "nextProValue"):GetComponent("Text").text = ""
            end
        end
    end
    --材料展示
    isMaterial = true
    local curPlayerMountLevelUp = ConfigManager.GetConfigData(ConfigName.PlayerMountLevelUp,curRideLv)
    for i = 1, math.max(#lvMaterialsList, #curPlayerMountLevelUp.Consume) do
        local go = lvMaterialsList[i]
        if not go then
            go=newObject(lvMaterialsList[1])
            go.transform:SetParent(this.lvMaterialsListParent.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition=Vector3.zero;
            go.gameObject.name = "itemPre (".. i ..")"
            lvMaterialsList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #curPlayerMountLevelUp.Consume do
        lvMaterialsList[i]:SetActive(true)
        local itemId = curPlayerMountLevelUp.Consume[i][1]
        local itemNeedVale = curPlayerMountLevelUp.Consume[i][2]
        local itemBagVale = BagManager.GetItemCountById(itemId)
        Util.GetGameObject(lvMaterialsList[i], "icon"):GetComponent("Image").sprite =
            Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId).ResourceID))
        if itemBagVale >= itemNeedVale then
            Util.GetGameObject(lvMaterialsList[i], "Text"):GetComponent("Text").text = "<color=#FFFFFF>"..PrintWanNum(itemBagVale).."/"..itemNeedVale.."</color>"
        else
            isMaterial = false
            Util.GetGameObject(lvMaterialsList[i], "Text"):GetComponent("Text").text = "<color=#FF0000>"..PrintWanNum(itemBagVale).."/"..itemNeedVale.."</color>"
        end
    end
    --满级显隐
    this.noUpLvText:SetActive( #nextproInfoList <= 0)
    this.upLvBtn:SetActive( #nextproInfoList > 0)
    this.upLv:SetActive( #nextproInfoList > 0)
    this.GoToBtnFun()
end
--当前级属所有性获取
function this.GetCurRideAllPro(lv)
    local proList = {}
    local curPlayerMountLevelUp = ConfigManager.GetConfigData(ConfigName.PlayerMountLevelUp,lv)
    if curPlayerMountLevelUp == nil then return {} end
    if curPlayerMountLevelUp.Property then
        for i = 1, #curPlayerMountLevelUp.Property do
            table.insert(proList,{name = ConfigManager.GetConfigData(ConfigName.PropertyConfig,curPlayerMountLevelUp.Property[i][1]).Info,
                                  vale = curPlayerMountLevelUp.Property[i][2]})
        end
    end
    if curPlayerMountLevelUp.MapSpeed > 0 then
        table.insert(proList,{name = GetLanguageStrById(11905),
                              vale = curPlayerMountLevelUp.MapSpeed})
    end
    if curPlayerMountLevelUp.MapView > 0 then
        table.insert(proList,{name = GetLanguageStrById(11906),
                              vale = curPlayerMountLevelUp.MapView})
    end
    return proList
end
--所有坐骑展示
function this.OnShowAllRideGrid()
    for i = 1, math.max(#rideList, #playerRideConFig) do
        local go = rideList[i]
        if not go then
            go=newObject(this.itemPre)
            go.transform:SetParent(this.grid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition=Vector3.zero;
            go.gameObject.name = "itemPre (".. i ..")"
            rideList[i] =  go
        --440 = 362 + 80
        rideList[i].transform.localPosition=Vector3.New(i*440,0,0)
        end
        go.gameObject:SetActive(false)
    end
    this.RefreshAllRideData()
    curIndex = -3
    this.grid.transform.localPosition=Vector3.New(curIndex*440)
    this.FirstSetGridPos(curIndex,curDataIndex)
end
function this.UpLvFun()
    --材料不够
    if not isMaterial then
        PopupTipPanel.ShowTipByLanguageId(11850)
        return
    end
    --未穿
    NetManager.RequestRideLvUp(function ()
        PopupTipPanel.ShowTipByLanguageId(11907)
        PlayerManager.SetPlayerRideLv(PlayerManager.rideLevel + 1)
        this.OnShowCurRideProData(curRideId)
        this.RefreshAllRideData()
        FormationManager.UserPowerChanged()
        this.GoToBtnFun()
    end)
end
function this.GoToBtnFun()
    local btnState = 0
    if BagManager.GetItemCountById(curRideId) > 0 then--获得
        this.goToBtnText.text = GetLanguageStrById(10220)
        btnState = 1
        if curRideId == PlayerManager.ride then--获得并使用
            this.goToBtnText.text = GetLanguageStrById(11908)
            btnState = 2
        end
    else--未获得
        this.goToBtnText.text = GetLanguageStrById(11909)
    end
    Util.AddOnceClick(this.goToBtn, function()
        if btnState == 0 then
            JumpManager.GoJump(ConfigManager.GetConfigData(ConfigName.ItemConfig,curRideId).Jump[1])
        elseif btnState == 1 then
            NetManager.RequestChangeModifyDecoration(3, curRideId, function ()
                PopupTipPanel.ShowTipByLanguageId(11891)
                PlayerManager.SetPlayerRide(curRideId)
                this.RefreshAllRideData()
                FormationManager.UserPowerChanged()
                this.GoToBtnFun()
                if playerLiveView then
                    playerLiveView:OnOpen()
                end
            end)
        elseif btnState == 2 then
            NetManager.RequestChangeModifyDecoration(3, 0, function ()
                PopupTipPanel.ShowTipByLanguageId(11910)
                PlayerManager.SetPlayerRide(0)
                this.RefreshAllRideData()
                FormationManager.UserPowerChanged()
                this.GoToBtnFun()
                if playerLiveView then
                    playerLiveView:OnOpen()
                end
            end)
        end
    end)
end
function this.RefreshAllRideData()

    for i = 1, #playerRideConFig do
        if curRideId == playerRideConFig[i].Id then
            curDataIndex = i
        end
        rideList[i]:SetActive(true)
        Util.GetGameObject(rideList[i], "iconMask/icon"):GetComponent("Image").sprite =
        Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.PlayerAppearance,playerRideConFig[i].Id).Painting))
        Util.GetGameObject(rideList[i], "lv/Text"):GetComponent("Text").text = curRideLv
        --Util.SetGray(rideList[i], not (BagManager.GetItemCountById(playerRideConFig[i].Id) > 0))
        Util.GetGameObject(rideList[i], "noGetImage"):SetActive(BagManager.GetItemCountById(curRideId) <= 0)
        Util.GetGameObject(rideList[i], "GetImage"):SetActive(playerRideConFig[i].Id ==  PlayerManager.ride)
       
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
                if dataIndex > #playerRideConFig then
                    dataIndex = dataIndex % #playerRideConFig
                end
                if dataIndex == 0 then
                    dataIndex = #playerRideConFig
                end
                this.OnShowCurRideProData(playerRideConFig[dataIndex].Id)
                posAddIndex = posAddIndex - 1
                posJianIndex = posJianIndex - 1
                local curGo = this.grid.transform:GetChild(#playerRideConFig - 1).transform
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
                if dataIndex > #playerRideConFig then
                    dataIndex = dataIndex % #playerRideConFig
                end
                if dataIndex == 0 then
                    dataIndex = #playerRideConFig
                end
                this.OnShowCurRideProData(playerRideConFig[dataIndex].Id)
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
function SettingPlayerRide:OnClose()

    parentGo = nil
    if rideLive then
        poolManager:UnLoadLive(rideLiveStr, rideLive, PoolManager.AssetType.GameObject)
        rideLive = nil
    end
    Util.ClearChild(this.grid.transform)
    rideList = {}
end

--界面销毁时调用（用于子类重写）
function SettingPlayerRide:OnDestroy()

    if playerLiveView then
        SubUIManager.Close(playerLiveView)
        playerLiveView = nil
    end
end

return SettingPlayerRide