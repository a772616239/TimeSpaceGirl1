require("Base/BasePanel")
LaddersKingPanel = Inherit(BasePanel)
local this = LaddersKingPanel
local agreeSprite = {
    GetPictureFont("cn2-X1_jingjichang_dianzan"),
    GetPictureFont("cn2-X1_jingjichang_yizan")
}

--初始化组件（用于子类重写）
function LaddersKingPanel:InitComponent()
    this.backBtn = Util.GetGameObject(this.gameObject, "Bg")
end

--绑定事件（用于子类重写）
function LaddersKingPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function LaddersKingPanel:AddListener()
end

--移除事件监听（用于子类重写）
function LaddersKingPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function LaddersKingPanel:OnOpen()
    this.RefreshRankData()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LaddersKingPanel:OnShow()
end

function LaddersKingPanel:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function LaddersKingPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function LaddersKingPanel:OnDestroy()
end

--刷新排行信息
function LaddersKingPanel.RefreshRankData()
    NetManager.GetWorldArenaRankInfoRequest(true, function (msg)
        local dataList = msg.arenaInfo.arenaEnemys
        for i = 1, 3 do
            local item = Util.GetGameObject(this.gameObject, "rank" .. i)
            if dataList[i] then
                Util.GetGameObject(item, "name"):SetActive(true)
                Util.GetGameObject(item, "frame"):SetActive(true)
                Util.GetGameObject(item, "agreeBtn"):SetActive(true)
                this.SetData(item, dataList[i])
            else
                Util.GetGameObject(item, "name"):SetActive(false)
                Util.GetGameObject(item, "frame"):SetActive(false)
                Util.GetGameObject(item, "agreeBtn"):SetActive(false)
            end
        end
    end)
end

function LaddersKingPanel.SetData(go, data)
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    local lv = Util.GetGameObject(go, "lv"):GetComponent("Text")
    local agreeBtn = Util.GetGameObject(go, "agreeBtn")
    local agree = Util.GetGameObject(go, "agreeBtn/Text"):GetComponent("Text")
    local frame = Util.GetGameObject(go, "frame"):GetComponent("Image")
    local icon = Util.GetGameObject(go, "frame/icon"):GetComponent("Image")
    lv.text = "Lv." .. data.personInfo.level
    agree.text = data.worshipTime
    frame.sprite = GetPlayerHeadFrameSprite(data.personInfo.headFrame)
    icon.sprite = GetPlayerHeadSprite(data.personInfo.head)
    
    if data.personInfo.servername ~= nil and data.personInfo.servername ~= "" then
        if data.personInfo.uid < 10000 then
            name.text = string.format("[%s]%s",data.personInfo.servername, GetLanguageStrById(tonumber(data.personInfo.name))) 
        else
            name.text = string.format("[%s]%s",data.personInfo.servername, data.personInfo.name)
        end
    else
        if data.personInfo.uid < 10000 then
            name.text = GetLanguageStrById(tonumber(data.personInfo.name))
        else
            name.text = data.personInfo.name
        end
    end

    if data.personInfo.servername ~= nil and data.personInfo.servername ~= "" then
        if data.personInfo.uid < 10000 then
            name.text = string.format("[%s]%s",data.personInfo.servername, GetLanguageStrById(tonumber(data.personInfo.name))) 
        else
            name.text = string.format("[%s]%s",data.personInfo.servername, data.personInfo.name)
        end
    else
        if data.personInfo.uid < 10000 then
            name.text = GetLanguageStrById(tonumber(data.personInfo.name))
        else
            name.text = data.personInfo.name
        end
    end

    if data.hadProud then
        agreeBtn:GetComponent("Image").sprite = Util.LoadSprite(agreeSprite[2])
    else
        agreeBtn:GetComponent("Image").sprite = Util.LoadSprite(agreeSprite[1])
    end
    Util.SetGray(agreeBtn, data.hadProud)

    Util.AddOnceClick(agreeBtn, function ()
        if data.hadProud then
            return
        end
        NetManager.GetWorldArenaProudRequest(data.personInfo.uid, data.personInfo.rank, function (msg)
            if msg.err == -1 then
                this.RefreshRankData()
                PopupTipPanel.ShowTip(GetLanguageStrById(50174))--排名发生变化
            elseif msg.err == 1 then
                PopupTipPanel.ShowTip(GetLanguageStrById(50175))--今天已经给他点过赞了
            elseif msg.err == 2 then
                PopupTipPanel.ShowTip(GetLanguageStrById(50176))--每日点赞数量达到上限
            else
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function()
                    agree.text = msg.worshipTime
                    agreeBtn:GetComponent("Image").sprite = Util.LoadSprite(agreeSprite[2])
                    Util.SetGray(agreeBtn, true)
                    Game.GlobalEvent:DispatchEvent(GameEvent.Ladders.RefreshItem)
                end)
            end
        end)
    end)
end

return LaddersKingPanel