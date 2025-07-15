require("Base/BasePanel")
RoleReturnPanel = Inherit(BasePanel)

local needGrid = {}
local needItemViewGrid = {}

local returnGrid = {}
local returnItemViewGrid = {}
local curHeroData
--local heroDatas
local isUpZhen

local isReturnMaterials=true--回溯材料是否充足
--初始化组件（用于子类重写）
function RoleReturnPanel:InitComponent()

    self.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    self.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    self.returnBtn = Util.GetGameObject(self.gameObject, "returnBtn")
    self.helpPosition=self.helpBtn:GetComponent("RectTransform").localPosition
    self.bg = Util.GetGameObject(self.gameObject, "bg")
    self.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})
    screenAdapte(self.bg)
    self.heroGo = Util.GetGameObject(self.gameObject, "needGo/bg/itemGrid/itemParent")
    for i = 1, 3 do
        needGrid[i] = Util.GetGameObject(self.gameObject, "needGo/bg/itemGrid/itemParent ("..i..")")
        needItemViewGrid[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(needGrid[i].transform, "itemParent").transform)
        returnGrid[i] = Util.GetGameObject(self.gameObject, "returnGo/bg/itemGrid/itemParent ("..i..")")
        returnItemViewGrid[i] = SubUIManager.Open(SubUIConfig.ItemView, returnGrid[i].transform)
    end
end

--绑定事件（用于子类重写）
function RoleReturnPanel:BindEvent()

    Util.AddClick(self.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.HeroReturn,self.helpPosition.x,self.helpPosition.y)
    end)
    Util.AddClick(self.returnBtn, function()
        if isUpZhen then
            PopupTipPanel.ShowTipByLanguageId(11862)
            return
        end
        if isReturnMaterials == false then
            PopupTipPanel.ShowTipByLanguageId(10455)
            return
        end
        MsgPanel.ShowTwo(GetLanguageStrById(11863), nil, function()
            NetManager.HeroRetureEvent(curHeroData.dynamicId,function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
                    self:DeleteReturnrMaterials()
                end)
            end)
        end, nil, nil, nil)--, true
    end)
end

--添加事件监听（用于子类重写）
function RoleReturnPanel:AddListener()

end

--移除事件监听（用于子类重写）
function RoleReturnPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RoleReturnPanel:OnOpen(_curHeroData,_isUpZhen)

    curHeroData,isUpZhen = _curHeroData,_isUpZhen
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RoleReturnPanel:OnShow()

    isReturnMaterials = true
    self.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.HeroReturn })
    if curHeroData then
        self:OnShowPanelData()
    end
end
function RoleReturnPanel:OnShowCallBackData(_curHeroData,_isUpZhen)
    curHeroData,isUpZhen = _curHeroData,_isUpZhen
    isReturnMaterials = true
    if curHeroData then
        self:OnShowPanelData()
    end
end
function RoleReturnPanel:OnShowPanelData()
    local returnConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroReturn,"HeroId", curHeroData.id,
            "Star", curHeroData.star)
    if returnConFig == nil then return end
    --需要素材
    local needItemList = {}
    --table.insert(needItemList,{curHeroData.id,1})
    self:OnShowHeroData()
    for i = 1, #returnConFig.ReturnConsume do
        table.insert(needItemList,returnConFig.ReturnConsume[i])
    end
    for i = 1, #needGrid do
        if #needItemList >= i then
            needGrid[i]:SetActive(true)
            needItemViewGrid[i]:OnOpen(false,{needItemList[i][1],0},1.1)
            local bagAllNum = BagManager.GetItemCountById(needItemList[i][1])
            Util.GetGameObject(needGrid[i], "Image/Text"):GetComponent("Text").text = string.format("%s/%s",PrintWanNum(bagAllNum) , PrintWanNum(needItemList[i][2]))
            Util.GetGameObject(needGrid[i], "Image/Text"):GetComponent("Text").color = UIColor.YELLOW
            if bagAllNum < needItemList[i][2] then
                isReturnMaterials = false
                Util.GetGameObject(needGrid[i], "Image/Text"):GetComponent("Text").color = UIColor.NOT_ENOUGH_RED
            end
        else
            needGrid[i]:SetActive(false)
        end
    end
    --返还素材
    for i = 1, #returnGrid do
        if #returnConFig.ReturnHero >= i then
            returnGrid[i]:SetActive(true)
            returnItemViewGrid[i]:OnOpen(false,{returnConFig.ReturnHero[i][1],0},1.1)
            Util.GetGameObject(returnGrid[i], "Image/Text"):GetComponent("Text").text = returnConFig.ReturnHero[i][2]
        else
            returnGrid[i]:SetActive(false)
        end
    end
end
--第一个回溯要求是英雄 与itemView不同特殊处理
function RoleReturnPanel:OnShowHeroData()
    --curHeroData
    --self.heroGo
    Util.GetGameObject(self.heroGo, "hero/frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(curHeroData.heroConfig.Quality,curHeroData.star))
    Util.GetGameObject(self.heroGo, "hero/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(curHeroData.heroConfig.Icon))
    Util.GetGameObject(self.heroGo, "hero/proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(curHeroData.heroConfig.PropertyName))
    Util.GetGameObject(self.heroGo, "hero/lv/Text"):GetComponent("Text").text = curHeroData.lv
    Util.GetGameObject(self.heroGo, "hero/posIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(curHeroData.heroConfig.Profession))
    SetHeroStars(Util.GetGameObject(self.heroGo, "hero/star"), curHeroData.star)
    Util.AddOnceClick(Util.GetGameObject(self.heroGo, "cilck"), function()
        UIManager.OpenPanel(UIName.RoleReturnListPanel,curHeroData,self)
    end)
end
--扣除升星 消耗的材料  更新英雄数据
function RoleReturnPanel:DeleteReturnrMaterials()
    HeroManager.DeleteHeroDatas({curHeroData.dynamicId})
    -->
    -- UIManager.OpenPanel(UIName.RoleListPanel)
end
--界面关闭时调用（用于子类重写）
function RoleReturnPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function RoleReturnPanel:OnDestroy()

    SubUIManager.Close(self.UpView)
end

return RoleReturnPanel