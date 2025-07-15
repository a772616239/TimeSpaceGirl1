----- 献祭弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local fun
local itemList = {}
local oldLevelId = 0
local curLevelId = 0
--传入选择英雄
local itemConfig =  ConfigManager.GetConfig(ConfigName.ItemConfig)
this.timer = Timer.New()
function this:InitComponent(gameObject)
    this.backBtn = Util.GetGameObject(gameObject,"bg/backBtn")
    this.Root = Util.GetGameObject(gameObject,"Root")
    this.proPre = Util.GetGameObject(gameObject,"proPre")
    itemList = {}
end

function this:BindEvent()
    Util.AddClick(this.backBtn,function()
        parent:ClosePanel()
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    FightPointPassManager.SetIsOpenRewardUpTip(false)
    parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local _args = {...}
    fun = _args[1]
    
    oldLevelId = FightPointPassManager.lastPassFightId
    curLevelId = FightPointPassManager.curOpenFight
    local oldLevelConFig = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,oldLevelId)
    local curLevelConFig = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,curLevelId)
    --itemList
    if curLevelConFig then
        for i = 1, math.max(#itemList, #curLevelConFig.RewardShowMin) do
            local go = itemList[i]
            if not go then
                go = newObject(this.proPre)
                go.transform:SetParent(this.Root.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero
                itemList[i] = go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #curLevelConFig.RewardShowMin do
            local go = itemList[i]
            local oldsinglePro = oldLevelConFig.RewardShowMin[i]
            local cursinglePro = curLevelConFig.RewardShowMin[i]
            go.gameObject:SetActive(true)
            local oldAddValue = FightPointPassManager.GetItemVipValue(oldsinglePro[1])
            if oldAddValue - 1 <= 0 then
                Util.GetGameObject(go, "proValue"):GetComponent("Text").text = oldsinglePro[2].."<size=28>"..GetLanguageStrById(11634).."</size>"
            else
                Util.GetGameObject(go, "proValue"):GetComponent("Text").text = oldsinglePro[2]*oldAddValue.."<size=28>"..GetLanguageStrById(11634).."</size>"
            end

            Util.GetGameObject(go,"Image"):GetComponent("Image").sprite = SetIcon(cursinglePro[1])
            Util.GetGameObject(go, "proName"):GetComponent("Text").text = GetLanguageStrById(itemConfig[cursinglePro[1]].Name)

            local curAddValue = FightPointPassManager.GetItemVipValue(cursinglePro[1])
            local nextproValue = Util.GetGameObject(go, "nextproValue"):GetComponent("Text")
            if cursinglePro[2] - oldsinglePro[2] > 0 then
                if curAddValue - 1 <= 0 then
                    nextproValue.text = "<color=#FFD12B>"..cursinglePro[2].."</color><size=28>"..GetLanguageStrById(11634).."</size>"
                else
                    nextproValue.text = "<color=#FFD12B>"..cursinglePro[2]*curAddValue.."</color><size=28>"..GetLanguageStrById(11634).."</size>"
                end
            else
                if curAddValue - 1 <= 0 then
                    nextproValue.text = cursinglePro[2].."<size=28>"..GetLanguageStrById(11634).."</size>"
                else
                    nextproValue.text = cursinglePro[2]*curAddValue.."<size=28>"..GetLanguageStrById(11634).."</size>"
                end
            end
        end
    end
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.timer = Timer.New(function()
        parent:ClosePanel()
    end,2):Start()
end

function this:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function this:OnDestroy()
    itemList = {}
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

return this