--[[
 * @ClassName ServerListItem
 * @Description 服务器列表Item
 * @Date 2019/8/30 14:52
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class ServerListItem
local ServerListItem = quick_class("ServerListItem")

--local TipsBgIconDef = {
--    [1] = "r_yiyou",
--    [2] = "r_zuijin"
--}

function ServerListItem:ctor(prefab, parent)
    self.cloneObj = newObjToParent(prefab, parent)

    -- self.tipsBg = Util.GetGameObject(self.cloneObj, "tipsBg"):GetComponent("Image")
    -- self.tips = Util.GetGameObject(self.tipsBg.transform, "tips"):GetComponent("Text")

    -- self.serverArea = Util.GetGameObject(self.cloneObj, "serverArea"):GetComponent("Text")
    self.serverName = Util.GetGameObject(self.cloneObj, "serverName"):GetComponent("Text")
    self.serverState = Util.GetGameObject(self.cloneObj, "serverState"):GetComponent("Image")

    self.newServerFlag = Util.GetGameObject(self.cloneObj, "newServerFlag")

    --
    -- self.role = Util.GetGameObject(self.cloneObj, "roleBg")
    -- self.roleIcon = Util.GetGameObject(self.role.transform, "Head/icon"):GetComponent("Image")
    -- self.roleFrame = Util.GetGameObject(self.role.transform, "Head/frame"):GetComponent("Image")
    -- self.roleName = Util.GetGameObject(self.role.transform, "Head/name"):GetComponent("Text")
    -- self.roleLv = Util.GetGameObject(self.role.transform, "Head/lv"):GetComponent("Text")
    --
end

-- function ServerListItem:SetRoleInfor(context)
--         self.roleIcon.sprite = Util.LoadSprite("cn2-X1_icon_lala")
--         self.roleFrame.sprite = Util.LoadSprite("cn2-x1_headbg_tongyong_touxiangkuang01")
--         if context.lastServer then
--             self.roleName.text = context.lastServer.name
--             self.roleLv.text = "LV" .. context.lastServer.level
--         else
--             self.roleName.text = ""
--             self.roleLv.text = ""
--         end
        
-- end

function ServerListItem:SetValue(serverInfo, flag)
    self.serverName.text = serverInfo.name
    -- self.tipsBg.gameObject:SetActive(not not flag)
    self.newServerFlag:SetActive(serverInfo.isnew == 1)
    -- self.serverArea.text = tonumber(string.sub(serverInfo.server_id, 0, -5)) .. GetLanguageStrById(11120)
    self.serverState.sprite = Util.LoadSprite(ServerStateIconDef[serverInfo.state])
end

function ServerListItem:SetVisible(flag)
    self.cloneObj:SetActive(flag)
end

return ServerListItem