--[[
 * @ClassName DemonPartsActiveSuccessPanel
 * @Description 异妖部件激活成功界面
 * @Date 2019/5/13 14:58
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]

require("Base/BasePanel")

---@class DemonPartsActiveSuccessPanel
DemonPartsActiveSuccessPanel = Inherit(BasePanel)

function DemonPartsActiveSuccessPanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.transform, "frame")

    self.propContent = Util.GetGameObject(self.transform, "frame/bg/propList")
    self.propItem = Util.GetGameObject(self.propContent, "propItem")
    self.propItem.gameObject:SetActive(false)

    self.propList = {}

end

function DemonPartsActiveSuccessPanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)
end

--{ pokemon = pokemon, index == i }
function DemonPartsActiveSuccessPanel:OnOpen(context)
    local componentInfo = context.pokemon.pokemoncomonpentList[context.index]
    local nextLv = componentInfo.level
    local allProVal = componentInfo.upLvMateriaConfiglList[nextLv].BaseAttribute
    for i = 1, #allProVal do
        local go = newObjToParent(self.propItem, self.propContent)
        Util.GetGameObject(go, "backGround").gameObject:SetActive(i % 2 == 1)
        Util.GetGameObject(go, "curProName"):GetComponent("Text").text = ConfigManager.GetConfigData(ConfigName.PropertyConfig, allProVal[i][1]).Info
        Util.GetGameObject(go, "curProValue"):GetComponent("Text").text = "+" .. GetPropertyFormatStrOne(ConfigManager.GetConfigData(ConfigName.PropertyConfig, allProVal[i][1]).Style, allProVal[i][2])

        table.insert(self.propList, go)
    end
end

function DemonPartsActiveSuccessPanel:OnClose()
    table.walk(self.propList, function(propItem)
        destroy(propItem.gameObject)
    end)
    self.propList = {}
end

return DemonPartsActiveSuccessPanel