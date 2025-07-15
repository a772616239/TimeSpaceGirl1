----- 献祭弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
--item容器
local itemList = {}
--传入选择英雄
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local selectChip = {}
local isSendMassage = false
local myguildHelpInfo
local fun = nil
local upSelectChipId = 0
local isHaveLock = false
function this:InitComponent(gameObject)
    this.aidBtn=Util.GetGameObject(gameObject,"aidBtn")
    this.btnSelect=Util.GetGameObject(gameObject,"btnSelect")
    this.SelectImage=Util.GetGameObject(gameObject,"btnSelect/SelectImage")
    this.BodyText=Util.GetGameObject(gameObject,"Body/Text"):GetComponent("Text")
    for i = 1, 4 do
        itemList[i] = Util.GetGameObject(gameObject, "Root/frame (".. i ..")")
    end
end

function this:BindEvent()
    Util.AddClick(this.btnSelect,function()
        isSendMassage = not isSendMassage
        this.SelectImage:SetActive(isSendMassage)
    end)
    Util.AddClick(this.aidBtn,function()
        local aidChips = {}
        for i, v in pairs(selectChip) do
            if not v.lock then
                
                table.insert(aidChips,v.dataId)
            end
        end
        if aidChips and #aidChips > 0 then
            local itemId1 = nil
            local itemId2 = nil
            if not itemId1 and  aidChips[1] then
                itemId1 = aidChips[1]
            end
            if not itemId2 and  aidChips[2] then
                itemId2 = aidChips[2]
            end
            if not MyGuildManager.ShowGuildAidCdTime(false) then
                MyGuildManager.ShowGuildAidCdTime()
                return
            end
            
            NetManager.GuildSendHelpRequest(aidChips,isSendMassage,function(msg)
                --这块后端有问题  不管isSendMassage真与否 能发时msg.sendMessage都为ture
                if msg.sendMessage and isSendMassage then
                    ChatManager.RequestSendGuildAid(itemId1,itemId2,function()
                        PopupTipPanel.ShowTipByLanguageId(11008)
                        --MyGuildManager.SetGuildHelpCDTimeData()
                    end)
                else
                    --MyGuildManager.ShowGuildAidCdTime()
                end
                if fun then
                    fun()
                    fun = nil
                end
            end)
            parent:ClosePanel()
        else
            PopupTipPanel.ShowTipByLanguageId(11624)
        end
    end)
end
function this:AddListener()
end

function this:RemoveListener()
end
function this:OnShow(_parent,...)
    isSendMassage = false
    this.SelectImage:SetActive(isSendMassage)
    local args = {...}
    parent=_parent
    fun=args[1]
    sortingOrder = _parent.sortingOrder
    local items = ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).RecourseReward
    myguildHelpInfo = MyGuildManager.MyFeteInfo.guildHelpInfo
    selectChip = {}
    isHaveLock = false
    for i = 1, #items do
        if myguildHelpInfo and #myguildHelpInfo > 0 then
            for j = 1, #myguildHelpInfo do
                if myguildHelpInfo[j].type == items[i][2] then
                    selectChip[items[i][2]] = {dataId = items[i][2],lock = true}
                    isHaveLock = true
                end
            end
        end
    end
    this.ShowPanelData(items)
    this.BodyText.text = GetLanguageStrById(11625)
end
function this.ShowPanelData(items)
    for i = 1, #items do
        itemList[i]:GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(itemConfig[items[i][2]].Quantity))
        Util.GetGameObject(itemList[i], "Icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[items[i][2]].ResourceID))
        Util.GetGameObject(itemList[i], "chipImage"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroChipQuantityImageByquality(itemConfig[items[i][2]].Quantity))
        Util.GetGameObject(itemList[i], "lock"):SetActive(false)
        Util.GetGameObject(itemList[i], "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(itemConfig[items[i][2]].PropertyName))
        local choosed = Util.GetGameObject(itemList[i], "selectImage")
        choosed:SetActive(false)
        if selectChip[items[i][2]] then
            choosed:SetActive(true)
            if selectChip[items[i][2]].lock then
                Util.GetGameObject(itemList[i], "lock"):SetActive(true)
            else
                Util.GetGameObject(itemList[i], "lock"):SetActive(false)
            end
        end
        Util.AddOnceClick(Util.GetGameObject(itemList[i], "Icon"), function()
            if selectChip[items[i][2]] then
                if not selectChip[items[i][2]].lock then
                    selectChip[items[i][2]]=nil
                    this.ShowPanelData(items)
                    return
                else
                    return
                end
            else
                if LengthOfTable(selectChip) >= 2 then
                    for key, val in pairs(selectChip) do
                        if not val.lock and (key ~= upSelectChipId or isHaveLock) then
                            selectChip[key]=nil
                            selectChip[items[i][2]] = {dataId = items[i][2],lock = false}
                            upSelectChipId = items[i][2]
                            this.ShowPanelData(items)
                            return
                        end
                    end
                else
                    selectChip[items[i][2]] = {dataId = items[i][2],lock = false}
                    upSelectChipId = items[i][2]
                    this.ShowPanelData(items)
                end
            end
        end)
    end
end
function this:OnClose()
end

function this:OnDestroy()
end

return this