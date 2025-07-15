AdjutantCurrentPanel = quick_class("AdjutantCurrentPanel")
local this = AdjutantCurrentPanel
local activityShowConfig
local globalActivityConfig
local activityRewardConfig
local isHaveAdjutant
local isEnough
local adjutantConfig = ConfigManager.GetConfig(ConfigName.AdjutantConfig)

--初始化组件（用于子类重写）
function AdjutantCurrentPanel:InitComponent(parent)
    this.gameObject = parent
    this.adjutantShop = Util.GetGameObject(this.gameObject,"adjutantShop")
    this.shop = Util.GetGameObject(this.gameObject,"shop")

    this.name = Util.GetGameObject(this.gameObject,"name/Text"):GetComponent("Text")
    this.RoleRoot = Util.GetGameObject(this.gameObject,"RoleRoot")
    this.getBtn = Util.GetGameObject(this.gameObject,"getBtn")
    this.costIcon = Util.GetGameObject(this.gameObject,"cost/icon"):GetComponent("Image")
    this.costNum = Util.GetGameObject(this.gameObject,"cost/num"):GetComponent("Text")
    this.time = Util.GetGameObject(this.gameObject,"time/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function AdjutantCurrentPanel:BindEvent()
    Util.AddClick(this.adjutantShop,function ()
        local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantCurrent)
        local data = ConfigManager.GetConfigData(ConfigName.GlobalActivity,activityId)
        local shopData = ConfigManager.GetConfigData(ConfigName.StoreTypeConfig,data.ShopId[1])
        UIManager.OpenPanel(UIName.MapShopPanel,shopData.StoreType)
    end)
    Util.AddClick(this.shop,function ()
        local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantCurrent)
        local data = ConfigManager.GetConfigData(ConfigName.GlobalActivity,activityId)
        local shopData = ConfigManager.GetConfigData(ConfigName.StoreTypeConfig,data.ShopId[2])
        UIManager.OpenPanel(UIName.MapShopPanel,shopData.StoreType)
    end)
    Util.AddClick(this.getBtn,function ()
        if isHaveAdjutant then
        else
            if isEnough then
                NetManager.GetActivityRewardRequest(activityRewardConfig.Id, globalActivityConfig.Id, function (msg)
                    UIManager.OpenPanel(UIName.RewardItemPopup,msg,1)
                    this:OnShow()
                end)
            else
                JumpManager.GoJump(activityRewardConfig.Jump[1])
            end
        end
    end)
end

--添加事件监听（用于子类重写）
function AdjutantCurrentPanel:AddListener()
end

--移除事件监听（用于子类重写）
function AdjutantCurrentPanel:RemoveListener()
end

function AdjutantCurrentPanel:OnShow(sortingOrder,parent)
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantCurrent)
    if activityId == nil then
        return
    end
    activityShowConfig = ConfigManager.GetConfigDataByKey(ConfigName.AcitvityShow,"ActivityId",activityId)
    globalActivityConfig = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity,"Id",activityId)
    this:ShowContent()
    --local info = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.AdjutantCurrent)
end

local buttonState = {
    [-1] = { sprite = "cn2-X1_xianquhuodong_huoqudaoju"},
    [0] = { sprite = "cn2-X1_xianquhuodong_duihuanxianqu"},
    [1] = { sprite = "cn2-X1_xianquhuodong_yiduihuan"},
}
function AdjutantCurrentPanel:ShowContent()
    if globalActivityConfig.ShopId[1] ~= 0 then
        this.adjutantShop:SetActive(true)
        if globalActivityConfig.ShopId[2] then
            this.shop:SetActive(true)
        else
            this.shop:SetActive(false)
        end
    else
        this.adjutantShop:SetActive(false)
        this.shop:SetActive(false)
    end

    local adjutantConfig = ConfigManager.GetConfigData(ConfigName.AdjutantConfig,activityShowConfig.Hero[1])
    this.name.text = GetLanguageStrById(adjutantConfig.Name)
    local info = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.AdjutantCurrent)
    local timeDown = info.endTime - PlayerManager.serverTime
    this.time.text = GetLanguageStrById(12321)..TimeToDH(timeDown)
    activityRewardConfig = ConfigManager.GetConfigDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",globalActivityConfig.Id)  
    isHaveAdjutant = BagManager.GetTotalItemNum(activityRewardConfig.Reward[1][1]) >= activityRewardConfig.Reward[1][2]
    local haveItemNum = BagManager.GetTotalItemNum(activityRewardConfig.Values[1][1])
    isEnough = haveItemNum >= activityRewardConfig.Values[1][2]
    if isHaveAdjutant then
        this.getBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(buttonState[1].sprite))
        this.costNum.text = haveItemNum
    else
        if isEnough then
            this.getBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(buttonState[0].sprite))
            this.costNum.text = string.format("<color=#24A363FF>%s</color>/%s",haveItemNum,activityRewardConfig.Values[1][2]) 
        else
            this.getBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(buttonState[-1].sprite))
            this.costNum.text = string.format("<color=#CE2323FF>%s</color>/%s",haveItemNum,activityRewardConfig.Values[1][2]) 
        end
    end
    local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig,activityRewardConfig.Values[1][1])
    this.costIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
    this:ShowRole()
end

function AdjutantCurrentPanel:ShowRole()
    local adjutantData = adjutantConfig[activityShowConfig.Hero[1]]
    if this.live ~= nil and this.data ~= nil then
        poolManager:UnLoadLive(this.data.Image, this.live)
        this.live = nil
        this.data = nil
    end
    this.data = adjutantData
    this.live = poolManager:LoadLive(this.data.Image, this.RoleRoot.transform,
            Vector3.one * this.data.Scale, Vector3.New(this.data.Pos[1], this.data.Pos[2], 0))
end

--界面关闭时调用（用于子类重写）
function AdjutantCurrentPanel:OnClose()
    if this.live ~= nil and this.data ~= nil then
        poolManager:UnLoadLive(this.data.Image, this.live)
        this.live = nil
        this.data = nil
    end
end

--界面销毁时调用（用于子类重写）
function AdjutantCurrentPanel:OnDestroy()

end

return AdjutantCurrentPanel