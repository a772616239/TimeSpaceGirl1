--[[
 * @ClassName QuestionnaireListItem
 * @Description 调查问卷Item
 * @Date 2019/9/4 14:39
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class QuestionnaireListItem
local QuestionnaireListItem = quick_class("QuestionnaireListItem")
local kMaxCharacter = 150
local InitValueForABCSIndex = 64
local QuestionAnswerType = {
    SingleChoice = 0,
    MultipleChoice = 1,
    InputBlanks = 2
}

function QuestionnaireListItem:ctor(prefab, parent)
    self.cloneObj = newObjToParent(prefab, parent.gameObject)

    self.title = Util.GetGameObject(self.cloneObj, "title"):GetComponent("Text")

    self.choosePart = Util.GetGameObject(self.cloneObj, "choosePart")
    self.choosePart:SetActive(false)

    self.inputPart = Util.GetGameObject(self.cloneObj, "inputPart")
    self.inputPart:SetActive(false)

end

function QuestionnaireListItem:Init()
    self.chooseList = {}
    self.answer = ""
end

function QuestionnaireListItem:SetValue(index, content)
    self.index = index
    self.answerType = content.answerType
    self:Init()
    if content.type ~= QuestionAnswerType.InputBlanks then
        local str = content.type == QuestionAnswerType.SingleChoice and "" or GetLanguageStrById(11684)
        local strV2 = str .. (content.answerType == 0 and "*" or "")
        self.title.text = index .. "、" .. content.content .. strV2
        for i = 1, #content.options do
            if content.options[i] == "" then
                return
            end
            local item = newObjToParent(self.choosePart, self.choosePart.transform.parent)
            local itemToggle = Util.GetGameObject(item, "Toggle"):GetComponent("Toggle")
            if content.type == QuestionAnswerType.MultipleChoice then
                itemToggle.group = nil
            end
            Util.GetGameObject(item, "Label"):GetComponent("Text").text = content.options[i]
            itemToggle.onValueChanged:AddListener(function(state)
                Util.GetGameObject(item, "Background/Checkmark/Image"):SetActive(state)
                self:OnValueChange(i, state)
            end)
        end
    else
        local str = content.answerType == 0 and "*" or ""
        self.title.text = index .. "." .. content.content .. str
        local item = newObjToParent(self.inputPart, self.inputPart.transform.parent)
        local itemInputFiled = Util.GetGameObject(item, "inputFiled"):GetComponent("InputField")
        itemInputFiled.characterLimit = kMaxCharacter
        local remainTips = Util.GetGameObject(item, "remain"):GetComponent("Text")
        remainTips.text = string.format("%s/%s", 0, kMaxCharacter)
        itemInputFiled.onValueChanged:AddListener(function()
            local length = string.utf8len(itemInputFiled.text)
            remainTips.text = string.format("%s/%s", length, kMaxCharacter)
            self.answer = self.index .. "&" .. itemInputFiled.text
        end)
    end

end

function QuestionnaireListItem:OnValueChange(i, state)
    self.answer = self.index .. "&"
    if state then
        table.insert(self.chooseList, i)
    else
        local existIndex = table.indexof(self.chooseList, i)
        if existIndex then
            table.remove(self.chooseList, existIndex)
        end
    end
    for _, idx in pairs(self.chooseList) do
        self.answer = self.answer .. string.char(InitValueForABCSIndex + idx)
    end
end

return QuestionnaireListItem