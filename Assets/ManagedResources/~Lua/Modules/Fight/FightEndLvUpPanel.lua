require("Base/BasePanel")
FightEndLvUpPanel = Inherit(BasePanel)
local this=FightEndLvUpPanel
local oldLevel
local curLevel
local callBack
local orginLayer
local SkeletonGraphic
local idleFunc = function()
    -- SkeletonGraphic.AnimationState:SetAnimation(0, "idle2", true)
end
--初始化组件（用于子类重写）
function FightEndLvUpPanel:InitComponent()

    orginLayer = 0
    this.maskBtn = Util.GetGameObject(self.transform, "maskBtn")
    this.nameText = Util.GetGameObject(self.transform, "bg/nameImage/nameText"):GetComponent("Text")
    this.lvNum = Util.GetGameObject(self.transform, "bg/lvNum/Text"):GetComponent("Text")

    this.curLvOpenFun = Util.GetGameObject(self.transform, "bg/openFun/curLvOpenFun")
    this.curLvOpenFun:SetActive(false)
    this.curopenListPre = Util.GetGameObject(self.transform, "bg/openFun/curLvOpenFun/openList/viewPort/content")
    this.itemPro = Util.GetGameObject(self.transform, "bg/openFun/curLvOpenFun/openList/viewPort/itemPro")
    this.itemPro.gameObject:SetActive(false)
    this.nextLvOpenFun = Util.GetGameObject(self.transform, "bg/openFun/nextLvOpenFun")
    this.nextLvOpenFun:SetActive(false)
    this.nextopenListPre = Util.GetGameObject(self.transform, "bg/openFun/nextLvOpenFun/openList/viewPort/content")

    this.roleEffect=Util.GetGameObject(self.transform, "bg/npc")

    -- SkeletonGraphic = this.roleEffect:GetComponent("SkeletonGraphic")
    -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idleFunc
end

local NpcAnimDef = {
    idle1 = {name="idle1", y=0},
    idle2 = {name="idle2", y=0},
}

--绑定事件（用于子类重写）
function FightEndLvUpPanel:BindEvent()

    Util.AddClick(this.maskBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function FightEndLvUpPanel:AddListener()

end

--移除事件监听（用于子类重写）
function FightEndLvUpPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function FightEndLvUpPanel:OnOpen(...)

    SoundManager.PlaySound(SoundConfig.Sound_UpLevel)

    local data={...}
    if #data < 1 then
        return
    end
    oldLevel=data[1]
    curLevel=data[2]
    callBack = data[3]
    Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnLevelChange)
    Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.PatFaceSend,FacePanelType.UpgradePac)
    this.ShowPanelData()
    SubmitExtraData({type = SDKSubMitType.TYPE_LEVEL_UP})
    --TalentManager.SetLevelEffect()
end

function FightEndLvUpPanel:OnShow()
    -- local SkeletonGraphic = this.roleEffect:GetComponent("SkeletonGraphic")
    -- SkeletonGraphic.AnimationState:SetAnimation(0, "idle1", false)
end

function FightEndLvUpPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.gameObject, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end
function  this.ShowPanelData()
    this.nameText.text=PlayerManager.nickName
    this.lvNum.text = curLevel
    this.ShowPlayerAndLevelPassOpenFun()
end
function this.ShowPlayerAndLevelPassOpenFun()
    local openFunDataList = FightManager.GetPlayerAndLevelPassOpenFun(curLevel)
    if openFunDataList and #openFunDataList > 0 then
        this.curLvOpenFun:SetActive(true)
        Util.ClearChild(this.curopenListPre.transform)
        for i = 1, #openFunDataList do
            local go = newObjToParent(this.itemPro.gameObject, this.curopenListPre.gameObject)
            Util.GetGameObject(go, "name"):GetComponent("Text").text = GetLanguageStrById(openFunDataList[i].Name)
            -- Util.GetGameObject(go, "frame"):GetComponent("Image").sprite =
            -- Util.LoadSprite(GetQuantityImageByquality(1))
            Util.GetGameObject(go, "icon"):GetComponent("Image").sprite =
            Util.LoadSprite(GetResourcePath(openFunDataList[i].OpenShow))
            -- Util.GetGameObject(go, "icon"):GetComponent("Image"):SetNativeSize()
            -- local iconTextImage =  Util.GetGameObject(go, "icon/iconTextImage")
            -- if openFunDataList[i].scriptshow and openFunDataList[i].scriptshow > 0 then
            --     iconTextImage:SetActive(true)
            --     iconTextImage:GetComponent("Image").sprite =
            --     Util.LoadSprite(GetResourcePath(openFunDataList[i].scriptshow))
            -- else
            --     iconTextImage:SetActive(false)
            -- end --m5
        end
    else
        this.curLvOpenFun:SetActive(false)
    end

    local needLv , nextFunDataList = FightManager.GetNextPlayerAndLevelPassOpenFun(curLevel)
    if nextFunDataList and #nextFunDataList > 0 then
        this.nextLvOpenFun:SetActive(true)
        Util.GetGameObject(this.nextLvOpenFun, "openLock/Text"):GetComponent("Text").text =GetLanguageStrById(10470)..needLv..GetLanguageStrById(10570)-- needLv..级
        Util.ClearChild(this.nextopenListPre.transform)
        for i = 1, #nextFunDataList do
            local go = newObjToParent(this.itemPro.gameObject, this.nextopenListPre.gameObject)
            Util.GetGameObject(go, "name"):GetComponent("Text").text = GetLanguageStrById(nextFunDataList[i].Name)
            -- Util.GetGameObject(go, "frame"):GetComponent("Image").sprite =
            -- Util.LoadSprite(GetQuantityImageByquality(1))
            Util.GetGameObject(go, "icon"):GetComponent("Image").sprite =
            Util.LoadSprite(GetResourcePath(nextFunDataList[i].OpenShow))
            -- Util.GetGameObject(go, "icon"):GetComponent("Image"):SetNativeSize()
            -- local iconTextImage =  Util.GetGameObject(go, "icon/iconTextImage")
            -- if nextFunDataList[i].scriptshow and nextFunDataList[i].scriptshow > 0 then
            --     iconTextImage:SetActive(true)
            --     iconTextImage:GetComponent("Image").sprite =
            --     Util.LoadSprite(GetResourcePath(nextFunDataList[i].scriptshow))
            -- else
            --     iconTextImage:SetActive(false)
            -- end --m5
        end
    else
        this.nextLvOpenFun:SetActive(false)
    end
end
--界面关闭时调用（用于子类重写）
function FightEndLvUpPanel:OnClose()

    if callBack then
        callBack()
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.PatFaceSend, FacePanelType.UpgradePac)
end

--界面销毁时调用（用于子类重写）
function FightEndLvUpPanel:OnDestroy()

    -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idleFunc  --m5
end

return FightEndLvUpPanel