--[[
 * @ClassName ServerListSelectPanel
 * @Description 选服界面
 * @Date 2019/8/30 14:32
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
local ServerListItem = require("Modules/Login/ServerListItem")
---@class ServerListSelectPanel
local ServerListSelectPanel = quick_class("ServerListSelectPanel", BasePanel)

function ServerListSelectPanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.transform, "closeBtn")

    self.serverContent = Util.GetGameObject(self.transform, "serverList/mask/content")
    self.serverPrototype = Util.GetGameObject(self.serverContent, "serverItemPrefab")
    self.serverPrototype:SetActive(false)
    self.serverItemList = {}

    ---quick Login
    self.quickLoginPart = Util.GetGameObject(self.transform, "quickLogin")
    --newServerPart
    self.newServerPart = {
        serverItem = Util.GetGameObject(self.quickLoginPart, "serverItemNew"),
        -- areaBelong = Util.GetGameObject(self.quickLoginPart, "serverItemNew/serverArea"):GetComponent("Text"),
        serverName = Util.GetGameObject(self.quickLoginPart, "serverItemNew/serverName"):GetComponent("Text"),
        serverState = Util.GetGameObject(self.quickLoginPart, "serverItemNew/serverState"):GetComponent("Image"),
        newServerFlag = Util.GetGameObject(self.quickLoginPart, "serverItemNew/newServerFlag"),
    }
    self.newServerPart.serverItem:SetActive(false)
    self.serverInfoNew = nil
    --recentLogin
    self.recentLoginPart = {
        serverItem = Util.GetGameObject(self.quickLoginPart, "serverItemRecent"),
        -- areaBelong = Util.GetGameObject(self.quickLoginPart, "serverItemRecent/serverArea"):GetComponent("Text"),
        serverName = Util.GetGameObject(self.quickLoginPart, "serverItemRecent/serverName"):GetComponent("Text"),
        serverState = Util.GetGameObject(self.quickLoginPart, "serverItemRecent/serverState"):GetComponent("Image"),
        playerName = Util.GetGameObject(self.quickLoginPart, "serverItemRecent/playerName"):GetComponent("Text"),
        newServerFlag = Util.GetGameObject(self.quickLoginPart, "serverItemRecent/newServerFlag"),
        playerLv = Util.GetGameObject(self.quickLoginPart, "serverItemRecent/playerLv"):GetComponent("Text"),
    }
    self.recentLoginPart.serverItem:SetActive(false)

end

function ServerListSelectPanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)
end
--serverList,myServerList,lastServer
function ServerListSelectPanel:OnOpen(context)
    self.context = context
    self:SetServerList()
    self:SetServerNew()
    self:SetServerRecent()
end

function ServerListSelectPanel:OnClose()

end

function ServerListSelectPanel:SetServerList()
    if table.nums(self.serverItemList) > 0 then
        return
    end
    for idx, serverInfo in ipairs(self.context.serverList) do
        local serverItem = ServerListItem.create(self.serverPrototype, self.serverContent.transform)
        local index = table.indexof(self.context.myServerList, serverInfo.server_id)
        serverItem:SetValue(serverInfo, index)
        serverItem:SetVisible(true)
        serverItem.cloneObj:GetComponent("Button").onClick:AddListener(function()
            if serverInfo.state == ServerStateDef.Maintenance then
                PopupTipPanel.ShowTipByLanguageId(11132)
                return
            end
            if self.context.callback then
                self.context.callback(idx)
            end
            self:ClosePanel()
        end)
        table.insert(self.serverItemList, serverItem)
    end
end

function ServerListSelectPanel:SetServerNew()
    for i = 1, #self.context.serverList do
        if self.context.serverList[i].server_id == self.context.recommend then
            self.serverInfoNew = self.context.serverList[i]
            break
        end
    end
    self.newServerPart.serverItem:SetActive(not not self.context.recommend)
    if self.serverInfoNew then
        -- self.newServerPart.areaBelong.text = tonumber(string.sub(self.serverInfoNew.server_id, 0, -5)) .. GetLanguageStrById(11120)
        self.newServerPart.serverName.text = self.serverInfoNew.name
        self.newServerPart.serverState.sprite = Util.LoadSprite(ServerStateIconDef[self.serverInfoNew.state])
        self.newServerPart.newServerFlag:SetActive(self.serverInfoNew.isnew == 1)
        self:QuickSeverClicked(self.newServerPart.serverItem, self.serverInfoNew.server_id)
    end
end

function ServerListSelectPanel:SetServerRecent()
    self.recentLoginPart.serverItem:SetActive(not not self.context.lastServer)
    if self.context.lastServer then
        local serverInfo = self:GetServerInfo(self.context.lastServer.serverid)
        if serverInfo then
            -- self.recentLoginPart.areaBelong.text = tonumber(string.sub(self.context.lastServer.serverid, 0, -5)) .. GetLanguageStrById(11120)
            self.recentLoginPart.serverName.text = GetLanguageStrByStr(serverInfo.name)
            self.recentLoginPart.serverState.sprite = Util.LoadSprite(ServerStateIconDef[serverInfo.state])
            self.recentLoginPart.playerName.text = self.context.lastServer.name --.. "\t" .. self.context.lastServer.level .. GetLanguageStrById(10072)
            self.recentLoginPart.playerLv.text = "Lv" .. self.context.lastServer.level
            self.recentLoginPart.newServerFlag:SetActive(serverInfo.isnew == 1)
            self:QuickSeverClicked(self.recentLoginPart.serverItem, self.context.lastServer.serverid)
        else
            self.recentLoginPart.serverItem:SetActive(false)
        end
    end
end

function ServerListSelectPanel:QuickSeverClicked(gameObject, serverId)
    Util.AddOnceClick(gameObject, function()
        if self.context.callback then
            self.context.callback(self:GetServerIndex(serverId))
        end
        self:ClosePanel()
    end)
end

function ServerListSelectPanel:GetServerInfo(serverId)
    local _serverInfo
    for _, serverInfo in pairs(self.context.serverList) do
        if serverInfo.server_id == serverId then
            _serverInfo = serverInfo
            break
        end
    end
    return _serverInfo
end

function ServerListSelectPanel:GetServerIndex(serverId)
    return table.keyvalueindexof(self.context.serverList, "server_id", serverId)
end

return ServerListSelectPanel