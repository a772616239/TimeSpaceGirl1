require("Base/BasePanel")
MedalConversionPopup = Inherit(BasePanel)
local this = MedalConversionPopup
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
local MedalSuitConfig = ConfigManager.GetConfig(ConfigName.MedalSuitConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local curIndex--打开页签
local MedalConfigData
local TargetMedalConfigData
local targrtId --转化勋章ID

--初始化组件（用于子类重写）
function MedalConversionPopup:InitComponent()

    this.frameLeft = Util.GetGameObject(self.gameObject,"bg/couversion/frameLeft")
    this.frameLeftIcon = Util.GetGameObject(self.gameObject,"bg/couversion/frameLeft/icon")
    this.frameLeftStar = Util.GetGameObject(self.gameObject,"bg/couversion/frameLeft/star")
    this.frameRight = Util.GetGameObject(self.gameObject,"bg/couversion/frameRight")
    this.frameRightIcon = Util.GetGameObject(self.gameObject,"bg/couversion/frameRight/icon")
    this.frameRightStar = Util.GetGameObject(self.gameObject,"bg/couversion/frameRight/star")
    this.costIcons = Util.GetGameObject(self.gameObject,"costIcons")

    this.CancleBtn = Util.GetGameObject(self.gameObject,"CancleBtn")
    this.SureBtn = Util.GetGameObject(self.gameObject,"SureBtn")
    --this.backBtn=Util.GetGameObject(self.gameObject,"backBtn")
end

--绑定事件（用于子类重写）
function MedalConversionPopup:BindEvent()
    Util.AddClick(this.frameRight,function()
        UIManager.OpenPanel(UIName.MedalConversionTargetPopup,this,this.itemData,MedalConfigData.SiteType)
    end)
    Util.AddClick(this.CancleBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.SureBtn,function()
        for i = 1, #this.costList do
            if BagManager.GetItemCountById(this.costList[i][1]) < this.costList[i][2] then
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343),GetLanguageStrById(ItemConfig[this.costList[i][1]].Name)))
                return
           end
        end

        if targrtId then
            if this.heroId then
                 --更新主面板勋章
                MedalManager.ConversionMedal(this.itemData.idDyn,targrtId,this.heroId,this.itemData.position,true,function()
                    PopupTipPanel.ShowTipByLanguageId(23059)
                end)
            else
                MedalManager.ConversionMedal(this.itemData.idDyn,targrtId,nil,nil,false,function()
                    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
                    --this.bagpanel:SetItemData(MedalManager.GetAllMedalData()) 
                    PopupTipPanel.ShowTipByLanguageId(23060)
                end)
            end
            self:ClosePanel()
        else
            PopupTipPanel.ShowTipByLanguageId(23061)
        end
    end)
end

--添加事件监听（用于子类重写）
function MedalConversionPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalConversionPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
--1.勋章Id
function MedalConversionPopup:OnOpen(...)
    local args = {...}
    this.itemData = args[1]
    this.heroId = args[2]
    --this.bagpanel=args[3]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalConversionPopup:OnShow()
    this.costIcons:SetActive(false)
    MedalConfigData = this.itemData.medalConfig
    this.frameLeft:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(MedalConfigData.Quality))
    this.frameLeftIcon:GetComponent("Image").sprite = Util.LoadSprite(this.itemData.icon)
    this.frameRight:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
    this.frameRightIcon:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_zhenying_07")
    SetHeroStars(this.frameLeftStar,MedalConfigData.Star)
    Util.ClearChild(this.frameRightStar.transform)
end
function MedalConversionPopup:OnSortingOrderChange()
end


--界面关闭时调用（用于子类重写）
function MedalConversionPopup:OnClose()
    targrtId = nil
    this.frameRight:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
    this.frameRightIcon:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_zhenying_07")
    Util.ClearChild(this.frameRightStar.transform)
end

--界面销毁时调用（用于子类重写）
function MedalConversionPopup:OnDestroy()

end

function this:UpdateTargetData(id)
    targrtId = id
    TargetMedalConfigData=MedalConfig[targrtId]
    this.frameRight:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(TargetMedalConfigData.Quality))
    this.frameRightIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[targrtId].ResourceID))

    SetHeroStars(this.frameRightStar,TargetMedalConfigData.Star)
    if targrtId then
        this:ConversionCost()
    end
end

--TODO
function this:ConversionCost()
    this.costIcons:SetActive(true)

    this.costList = {}
    local cost = MedalConfigData.ChangeCost

    table.insert(this.costList,{cost[1],cost[2]})

    if targrtId then
        local MedalSuitConfigData = MedalSuitConfig[MedalConfigData.Suit]
        local costValue1 = MedalSuitConfigData.ChangeValue[2]
        local TargetMedalSuitConfigData = MedalSuitConfig[TargetMedalConfigData.Suit]
        local costValue2 = TargetMedalSuitConfigData.ChangeValue[2]

        --消耗积分
        if costValue1 - costValue2 < 0 then
            table.insert(this.costList,{MedalSuitConfigData.ChangeValue[1],costValue2 - costValue1})
        end
    end

    for i = 1, 2 do
        local costItem = Util.GetGameObject(this.costIcons,"item"..i)
        costItem:SetActive(false)
    end
    for i = 1, #this.costList do
        local costItem = Util.GetGameObject(this.costIcons,"item"..i)
        costItem:SetActive(true)
        costItem:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(ItemConfig[this.costList[i][1]].Quantity))
        Util.GetGameObject(costItem,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[this.costList[i][1]].ResourceID))
        Util.GetGameObject(costItem,"num"):GetComponent("Text").text = tostring(PrintWanNum(BagManager.GetItemCountById(this.costList[i][1]))).."/"..tostring(this.costList[i][2])
        Util.AddOnceClick(Util.GetGameObject(costItem,"icon"), function ()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, this.costList[i][1])
        end)
    end
end

return MedalConversionPopup